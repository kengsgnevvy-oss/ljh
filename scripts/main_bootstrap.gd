extends Node

# Bootstrap script for main scene
# Loads UI and triggers first level via LevelManager

var _hud: CanvasLayer = null
var _loading_screen: CanvasLayer = null
var _boss_health_bar: CanvasLayer = null
var _cutscene_player: CanvasLayer = null
var _pause_menu: CanvasLayer = null
var _current_menu: CanvasLayer = null

var _pending_new_game: bool = false


func _ready() -> void:
	_preload_ui_scenes()
	
	# Connect to DialogueManager signals
	if DialogueManager:
		DialogueManager.game_intro_finished.connect(_on_game_intro_finished)
		DialogueManager.ending_finished.connect(_on_ending_finished)
	
	# Show main menu first
	_show_main_menu()
	
	# Listen for level loads
	if LevelManager:
		LevelManager.level_loaded.connect(_on_level_loaded)
	
	process_mode = Node.PROCESS_MODE_ALWAYS


func _preload_ui_scenes() -> void:
	# HUD
	var hud_scene: PackedScene = load("res://scenes/ui/hud.tscn")
	_hud = hud_scene.instantiate()
	_hud.name = "HUD"
	_hud.visible = false
	get_tree().root.add_child(_hud)
	
	# Loading Screen
	var load_scene: PackedScene = load("res://scenes/ui/loading_screen.tscn")
	_loading_screen = load_scene.instantiate()
	_loading_screen.name = "LoadingScreen"
	get_tree().root.add_child(_loading_screen)
	
	# Boss Health Bar
	var boss_scene: PackedScene = load("res://scenes/ui/boss_health_bar.tscn")
	_boss_health_bar = boss_scene.instantiate()
	_boss_health_bar.name = "BossHealthBar"
	get_tree().root.add_child(_boss_health_bar)
	
	# Cutscene Player
	var cutscene_scene: PackedScene = load("res://scenes/ui/cutscene_screen.tscn")
	_cutscene_player = cutscene_scene.instantiate()
	_cutscene_player.name = "CutscenePlayer"
	get_tree().root.add_child(_cutscene_player)


func _show_main_menu() -> void:
	if _current_menu:
		_current_menu.queue_free()
		_current_menu = null
	
	if _hud:
		_hud.visible = false
	
	var menu_scene: PackedScene = load("res://scenes/ui/main_menu.tscn")
	_current_menu = menu_scene.instantiate()
	_current_menu.name = "MainMenu"
	get_tree().root.add_child(_current_menu)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _current_menu and _current_menu.name == "MainMenu":
			return
		if _pause_menu and is_instance_valid(_pause_menu):
			return
		_show_pause_menu()


func _show_pause_menu() -> void:
	_pause_menu = load("res://scenes/ui/pause_menu.tscn").instantiate()
	_pause_menu.name = "PauseMenu"
	get_tree().root.add_child(_pause_menu)


func request_new_game() -> void:
	# Called from main menu when "New Game" is pressed
	Global.reset_game()
	_pending_new_game = true
	
	if _current_menu:
		_current_menu.queue_free()
		_current_menu = null
	
	if DialogueManager:
		# Play the game intro — when it finishes, _on_game_intro_finished fires
		DialogueManager.play_game_intro()
	else:
		# Fallback if DialogueManager not available
		if LevelManager:
			LevelManager.load_level(0)


func _on_game_intro_finished() -> void:
	if not _pending_new_game:
		return
	_pending_new_game = false
	
	if LevelManager:
		LevelManager.load_level(0)


func _on_ending_finished() -> void:
	# Return to main menu after ending/credits
	_show_main_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _on_level_loaded(_level_index: int) -> void:
	if _current_menu:
		_current_menu.queue_free()
		_current_menu = null
	
	if _hud:
		_hud.visible = true
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
