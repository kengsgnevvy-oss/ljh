extends CanvasLayer

# ============================================================
# ULTRANOKIA HUD
# Aggressive red-black style — Ultrakill/Doom inspired
# All animations via Tween, no AnimationPlayer dependency
# ============================================================

# --- Health ---
@onready var health_bar: TextureProgressBar = $HealthContainer/HealthBar
@onready var health_label: Label = $HealthContainer/HealthLabel

# --- Armor ---
@onready var armor_bar: TextureProgressBar = $ArmorContainer/ArmorBar
@onready var armor_label: Label = $ArmorContainer/ArmorLabel

# --- Ammo ---
@onready var ammo_current_label: Label = $AmmoContainer/AmmoCurrent
@onready var ammo_max_label: Label = $AmmoContainer/AmmoMax
@onready var weapon_name_label: Label = $AmmoContainer/WeaponName

# --- Style Meter ---
@onready var style_label: Label = $StyleContainer/StyleLetter
@onready var style_bar: TextureProgressBar = $StyleContainer/StyleBar

# --- Crosshair ---
@onready var crosshair_top: ColorRect = $Crosshair/Top
@onready var crosshair_bottom: ColorRect = $Crosshair/Bottom
@onready var crosshair_left: ColorRect = $Crosshair/Left
@onready var crosshair_right: ColorRect = $Crosshair/Right

# --- Damage Vignette ---
@onready var damage_vignette: ColorRect = $DamageVignette

# --- Floating Messages ---
@onready var message_container: Control = $MessageContainer

var prev_health: int = 100
var prev_armor: int = 0
var prev_style_letter: String = "D"
var _low_health_tween: Tween = null


func _ready() -> void:
	Global.ui_player_damaged.connect(_on_player_damaged)
	Global.ui_style_rank_changed.connect(_on_style_changed)
	Global.ui_player_kill.connect(_on_player_kill)
	
	_update_health()
	_update_armor()
	_update_ammo()
	_update_style()
	
	prev_health = Global.player_health
	prev_armor = Global.player_armor
	prev_style_letter = Global.get_style_letter()


func _process(_delta: float) -> void:
	if Global.player_health != prev_health:
		_update_health()
		prev_health = Global.player_health
	
	if Global.player_armor != prev_armor:
		_update_armor()
		prev_armor = Global.player_armor
	
	var current_style: String = Global.get_style_letter()
	if current_style != prev_style_letter:
		_update_style()
		prev_style_letter = current_style
	
	_update_ammo()


# ============================================================
# HEALTH
# ============================================================
func _update_health() -> void:
	var hp: int = Global.player_health
	var max_hp: int = Global.player_max_health
	var percent: float = float(hp) / float(max_hp) * 100.0
	
	health_bar.value = percent
	health_label.text = str(hp)
	
	if hp < 30:
		_start_low_health_pulse()
	else:
		_stop_low_health_pulse()


func _start_low_health_pulse() -> void:
	if _low_health_tween and _low_health_tween.is_running():
		return
	
	_low_health_tween = create_tween()
	_low_health_tween.set_loops()
	_low_health_tween.tween_property(health_bar, "tint_progress", Color(1, 0.55, 0.55, 1), 0.5).from(Color(1, 0.15, 0.15, 1))
	_low_health_tween.tween_property(health_bar, "tint_progress", Color(1, 0.15, 0.15, 1), 0.5).from(Color(1, 0.55, 0.55, 1))


func _stop_low_health_pulse() -> void:
	if _low_health_tween:
		_low_health_tween.kill()
		_low_health_tween = null
	health_bar.tint_progress = Color(1, 0.15, 0.15, 1)


# ============================================================
# ARMOR
# ============================================================
func _update_armor() -> void:
	var armor: int = Global.player_armor
	var max_armor: int = Global.player_max_armor
	var percent: float = float(armor) / float(max_armor) * 100.0
	
	armor_bar.value = percent
	armor_label.text = str(armor)
	armor_bar.visible = armor > 0
	armor_label.visible = armor > 0


# ============================================================
# AMMO
# ============================================================
func _update_ammo() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var wm: Node = null
	if player.has_node("Camera3D/WeaponHolder"):
		wm = player.get_node("Camera3D/WeaponHolder")
	
	if not wm:
		ammo_current_label.text = "--"
		ammo_max_label.text = "--"
		weapon_name_label.text = ""
		return
	
	var weapon: Node = null
	if wm.has_method("get_active_weapon"):
		weapon = wm.get_active_weapon()
	
	if weapon:
		var current: int = weapon.get("current_ammo") if "current_ammo" in weapon else 0
		var max_ammo: int = weapon.get("max_ammo") if "max_ammo" in weapon else 0
		var wname: String = weapon.get("weapon_name") if "weapon_name" in weapon else ""
		
		ammo_current_label.text = str(current)
		ammo_max_label.text = "/ " + str(max_ammo)
		weapon_name_label.text = wname.to_upper()
	else:
		ammo_current_label.text = "--"
		ammo_max_label.text = "/ --"
		weapon_name_label.text = ""


# ============================================================
# STYLE METER
# ============================================================
func _update_style() -> void:
	var letter: String = Global.get_style_letter()
	var percent: float = (Global.player_style - floor(Global.player_style)) * 100.0
	
	style_label.text = letter
	style_bar.value = percent
	
	var rank_color: Color
	match letter:
		"D": rank_color = Color(0.6, 0.6, 0.6)
		"C": rank_color = Color(0.3, 0.7, 1.0)
		"B": rank_color = Color(1.0, 0.7, 0.2)
		"A": rank_color = Color(1.0, 0.3, 0.1)
		"S": rank_color = Color(1.0, 0.9, 0.0)
		"U": rank_color = Color(1.0, 0.0, 1.0)
	
	style_label.add_theme_color_override("font_color", rank_color)


func _on_style_changed(_new_rank: String) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(style_label, "scale", Vector2(1.5, 1.5), 0.15)
	tween.tween_property(style_label, "scale", Vector2(1.0, 1.0), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


# ============================================================
# DAMAGE VIGNETTE
# ============================================================
func _on_player_damaged(amount: int) -> void:
	var tween: Tween = create_tween()
	damage_vignette.modulate.a = min(0.6, amount * 0.025)
	tween.tween_property(damage_vignette, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_OUT)


# ============================================================
# KILL MESSAGES
# ============================================================
func _on_player_kill(style_points: int, is_glory: bool) -> void:
	var msg: String
	var color: Color
	if is_glory:
		msg = "GLORY KILL  +" + str(style_points) + " STYLE"
		color = Color(1.0, 0.3, 0.1)
	else:
		msg = "KILL  +" + str(style_points) + " STYLE"
		color = Color(1.0, 0.8, 0.1)
	
	_spawn_floating_message(msg, color)


func _spawn_floating_message(text: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	
	# Shadow for readability
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	
	message_container.add_child(label)
	
	var tween: Tween = create_tween()
	tween.tween_property(label, "position:y", -60.0, 1.5).as_relative()
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.2).from_current().set_delay(0.3)
	tween.tween_callback(func(): label.queue_free())
