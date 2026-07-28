extends Node

# ============================================================
# ULTRANOKIA Level Manager (Autoload)
# Manages level loading, transitions, and progress
# ============================================================

signal level_loaded(level_index: int)
signal level_completed(level_index: int)
signal all_levels_completed()

var current_level: int = 0
var levels: Array[PackedScene] = []
var current_scene: Node = null
var _loading: bool = false

const LEVEL_PATHS: Array[String] = [
	"res://scenes/levels/level_1_techno_hell.tscn",
	"res://scenes/levels/level_2_cyber_catacombs.tscn",
	"res://scenes/levels/level_3_hell_forge.tscn",
	"res://scenes/levels/level_4_tower_of_sins.tscn",
	"res://scenes/levels/level_5_shattered_city.tscn",
	"res://scenes/levels/level_6_throne_room.tscn",
	"res://scenes/levels/level_7_final_battle.tscn",
]


func _ready() -> void:
	_preload_levels()


func _preload_levels() -> void:
	levels.clear()
	for path in LEVEL_PATHS:
		var scene := load(path) as PackedScene
		if scene:
			levels.append(scene)
		else:
			push_error("LevelManager: Failed to load level: " + path)


func load_level(index: int) -> void:
	if _loading:
		return
	if index < 0 or index >= levels.size():
		push_error("LevelManager: Invalid level index: " + str(index))
		return

	_loading = true
	_clear_current_level()

	var scene := levels[index]
	if not scene:
		push_error("LevelManager: Level scene is null for index: " + str(index))
		_loading = false
		return

	current_scene = scene.instantiate()
	get_tree().root.add_child(current_scene)
	current_level = index

	Global.current_level = index + 1

	# Spawn the player if available
	_spawn_player()

	_loading = false
	level_loaded.emit(index)


func next_level() -> void:
	var next_index := current_level + 1
	if next_index >= levels.size():
		all_levels_completed.emit()
		return

	# Show transition dialogue: outro of current level, intro of next
	if DialogueManager:
		await DialogueManager.play_level_transition(current_level)

	# Show loading screen via Global
	Global.emit_loading_screen()

	# Brief delay for loading screen to appear
	await get_tree().create_timer(0.5).timeout

	load_level(next_index)

	# Hide loading screen
	await get_tree().create_timer(0.3).timeout
	Global.hide_loading_screen()


func complete_level() -> void:
	level_completed.emit(current_level)

	# Find the exit portal in the current scene and activate it
	if current_scene:
		var portal := current_scene.find_child("ExitPortal", true, false)
		if portal:
			if portal.has_method("activate"):
				portal.activate()
			else:
				# Make portal visible and interactive
				portal.visible = true
				if portal is Area3D:
					portal.monitoring = true
					portal.monitorable = true
		else:
			# No exit portal found, check if this is the last level
			if is_last_level():
				await get_tree().create_timer(2.0).timeout
				_trigger_game_ending()
			else:
				await get_tree().create_timer(2.0).timeout
				next_level()


func _trigger_game_ending() -> void:
	all_levels_completed.emit()
	if DialogueManager:
		await DialogueManager.play_ending()
	# After ending and credits, return to main menu
	if Global:
		Global.emit_loading_screen()
		await get_tree().create_timer(0.5).timeout
		Global.hide_loading_screen()
	
	_clear_current_level()
	
	# Show main menu
	var menu_scene := load("res://scenes/ui/main_menu.tscn") as PackedScene
	if menu_scene:
		var menu := menu_scene.instantiate()
		menu.name = "MainMenu"
		get_tree().root.add_child(menu)
		
		# Hide HUD
		var hud := get_tree().root.find_child("HUD", true, false)
		if hud:
			hud.visible = false


func _clear_current_level() -> void:
	if current_scene and is_instance_valid(current_scene):
		current_scene.queue_free()
		current_scene = null


func _spawn_player() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	if not player_scene:
		return

	# Find player spawn point in the level
	var spawn_pos := Vector3(0, 2, 0)
	if current_scene:
		var spawn_marker := current_scene.find_child("PlayerSpawn", true, false)
		if spawn_marker:
			spawn_pos = spawn_marker.global_position

	# Check if player already exists
	var existing_player := get_tree().get_first_node_in_group("player")
	if existing_player:
		existing_player.global_position = spawn_pos
		return

	var player := player_scene.instantiate()
	player.global_position = spawn_pos
	get_tree().root.add_child(player)


func get_level_name(index: int = -1) -> String:
	var idx := index if index >= 0 else current_level
	match idx:
		0: return "TECHNO HELL"
		1: return "CYBER CATACOMBS"
		2: return "HELL FORGE"
		3: return "TOWER OF SINS"
		4: return "SHATTERED CITY"
		5: return "THRONE ROOM"
		6: return "FINAL BATTLE"
		_: return "UNKNOWN"


func restart_level() -> void:
	load_level(current_level)


func is_last_level() -> bool:
	return current_level >= levels.size() - 1
