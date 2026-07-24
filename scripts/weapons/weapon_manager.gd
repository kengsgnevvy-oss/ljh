extends Node3D

# ============================================================
# ULTRANOKIA Weapon Manager
# Handles weapon inventory, switching, and delegation
# ============================================================

# --- Weapon Slots ---
var weapons: Array = []
var active_index: int = -1
var active_weapon: Node3D = null

# --- Weapon Scenes ---
var weapon_scenes: Dictionary = {
	1: "res://scenes/weapons/revolver.tscn",
	2: "res://scenes/weapons/shotgun.tscn",
	3: "res://scenes/weapons/machinegun.tscn",
	4: "res://scenes/weapons/plasmagun.tscn",
	5: "res://scenes/weapons/railgun.tscn",
	6: "res://scenes/weapons/grenade_launcher.tscn",
}

# --- Switching ---
var is_switching: bool = false
var switch_duration: float = 0.15

# --- References ---
var player_node: Node3D = null
var camera: Camera3D = null


func _ready() -> void:
	player_node = get_parent()
	if player_node and player_node.has_node("Camera3D"):
		camera = player_node.get_node("Camera3D")
	
	call_deferred("_init_default_weapons")


func _init_default_weapons() -> void:
	add_weapon_by_slot(1)
	add_weapon_by_slot(2)
	_switch_to(0)


# ============================================================
# WEAPON MANAGEMENT
# ============================================================
func add_weapon_by_slot(slot: int) -> void:
	if not weapon_scenes.has(slot):
		return
	
	for w in weapons:
		if w.get("weapon_slot") == slot:
			return
	
	var path: String = weapon_scenes[slot]
	var scene: PackedScene = load(path)
	var weapon: Node3D = scene.instantiate()
	
	# Set slot explicitly before adding to tree
	weapon.set("weapon_slot", slot)
	weapon.set("weapon_manager", self)
	add_child(weapon)
	weapon.set("visible", false)
	weapons.append(weapon)
	
	# Sort by weapon_slot
	_sort_weapons()


func _sort_weapons() -> void:
	weapons.sort_custom(_compare_weapon_slots)


func _compare_weapon_slots(a: Node3D, b: Node3D) -> bool:
	var slot_a: int = a.get("weapon_slot") if a else 0
	var slot_b: int = b.get("weapon_slot") if b else 0
	return slot_a < slot_b


func add_weapon(weapon: Node3D) -> void:
	if weapon == null:
		return
	weapon.set("weapon_manager", self)
	add_child(weapon)
	weapon.set("visible", false)
	weapons.append(weapon)
	_sort_weapons()


func _switch_to(index: int) -> void:
	if index < 0 or index >= weapons.size():
		return
	if index == active_index:
		return
	
	is_switching = true
	
	var old_weapon: Node3D = active_weapon
	var new_weapon: Node3D = weapons[index]
	
	# Cancel beam on old plasma gun
	if old_weapon and old_weapon.has_method("_stop_beam"):
		old_weapon._stop_beam()
	
	active_index = index
	active_weapon = new_weapon
	
	# Animate switch
	if old_weapon:
		old_weapon.set("visible", true)
		var old_tween: Tween = create_tween()
		old_tween.tween_property(old_weapon, "position:y", -0.5, switch_duration * 0.7)
		old_tween.tween_callback(func():
			old_weapon.set("visible", false)
			old_weapon.position.y = 0.0
		)
	
	new_weapon.set("visible", true)
	new_weapon.position.y = -0.3
	var new_tween: Tween = create_tween()
	new_tween.tween_property(new_weapon, "position:y", 0.0, switch_duration * 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	new_tween.tween_callback(func():
		is_switching = false
	)


func switch_to_slot(slot: int) -> void:
	for i in range(weapons.size()):
		if weapons[i].get("weapon_slot") == slot:
			_switch_to(i)
			return


func cycle_next() -> void:
	if weapons.is_empty():
		return
	var next_idx: int = (active_index + 1) % weapons.size()
	_switch_to(next_idx)


func cycle_prev() -> void:
	if weapons.is_empty():
		return
	var prev_idx: int = (active_index - 1 + weapons.size()) % weapons.size()
	_switch_to(prev_idx)


func switch_to(index: int) -> void:
	_switch_to(index)


# ============================================================
# FIRING DELEGATION
# ============================================================
func fire_current() -> void:
	if is_switching or not active_weapon:
		return
	if active_weapon.has_method("fire"):
		active_weapon.fire()


func alt_fire_current() -> void:
	if is_switching or not active_weapon:
		return
	if active_weapon.has_method("alt_fire"):
		active_weapon.alt_fire()


func reload_current() -> void:
	if is_switching or not active_weapon:
		return
	if active_weapon.has_method("reload"):
		active_weapon.reload()


# Detonate sticky grenades
func detonate_stickies() -> void:
	if active_weapon and active_weapon.has_method("detonate_all_stickies"):
		active_weapon.detonate_all_stickies()


# ============================================================
# INPUT HANDLING
# ============================================================
func _process(_delta: float) -> void:
	for i in range(1, 7):
		if Input.is_action_just_pressed("weapon_" + str(i)):
			switch_to_slot(i)
	
	if Input.is_action_just_pressed("weapon_next"):
		cycle_next()
	elif Input.is_action_just_pressed("weapon_prev"):
		cycle_prev()
	
	# Alt-fire sticky detonation check
	if Input.is_action_just_pressed("alt_fire"):
		if active_weapon and active_weapon.has_method("detonate_all_stickies"):
			var gl: Node3D = active_weapon
			var stickies = gl.get("sticky_grenades")
			if stickies and stickies.size() > 0:
				gl.detonate_all_stickies()
				return
		alt_fire_current()


# ============================================================
# UTILITY
# ============================================================
func get_active_weapon() -> Node3D:
	return active_weapon


func get_weapon_by_slot(slot: int) -> Node3D:
	for w in weapons:
		if w.get("weapon_slot") == slot:
			return w
	return null


func has_weapon(slot: int) -> bool:
	return get_weapon_by_slot(slot) != null


func shake_camera(amount: float) -> void:
	if camera and camera.has_method("apply_recoil"):
		camera.apply_recoil(amount)
	elif camera:
		var orig_pos: Vector3 = camera.position
		var t: Tween = create_tween()
		t.tween_property(camera, "position:x", orig_pos.x + randf_range(-amount, amount), 0.02)
		t.tween_property(camera, "position:x", orig_pos.x, 0.02)
		t.tween_property(camera, "position:y", orig_pos.y + randf_range(-amount, amount * 0.5), 0.02)
		t.tween_property(camera, "position:y", orig_pos.y, 0.02)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("reload"):
		reload_current()
