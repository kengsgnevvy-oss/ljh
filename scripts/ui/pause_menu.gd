extends CanvasLayer

# ============================================================
# ULTRANOKIA Pause Menu
# Overlays the game when ESC is pressed
# ============================================================

@onready var resume_btn: Button = $Background/CenterContainer/VBoxContainer/ResumeBtn
@onready var restart_btn: Button = $Background/CenterContainer/VBoxContainer/RestartBtn
@onready var settings_btn: Button = $Background/CenterContainer/VBoxContainer/SettingsBtn
@onready var quit_btn: Button = $Background/CenterContainer/VBoxContainer/QuitToMenuBtn
@onready var bg_rect: ColorRect = $Background


func _ready() -> void:
	# Freeze game
	get_tree().paused = true
	Global.is_paused = true
	
	# Button connections
	resume_btn.pressed.connect(_on_resume)
	restart_btn.pressed.connect(_on_restart)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit_to_menu)
	
	_style_button(resume_btn)
	_style_button(restart_btn)
	_style_button(settings_btn)
	_style_button(quit_btn)
	
	# Fade-in animation
	bg_rect.modulate.a = 0
	var tween: Tween = create_tween()
	tween.tween_property(bg_rect, "modulate:a", 0.85, 0.2)
	
	# Focus first button
	resume_btn.grab_focus()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_on_resume()


func _on_resume() -> void:
	get_tree().paused = false
	Global.is_paused = false
	queue_free()


func _on_restart() -> void:
	get_tree().paused = false
	Global.is_paused = false
	queue_free()
	
	if LevelManager:
		LevelManager.restart_level()


func _on_settings() -> void:
	print("Settings not yet implemented")


func _on_quit_to_menu() -> void:
	get_tree().paused = false
	Global.is_paused = false
	queue_free()
	
	# Clear level and go to menu
	if LevelManager and LevelManager.current_scene:
		LevelManager.current_scene.queue_free()
		LevelManager.current_scene = null
	
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _style_button(btn: Button) -> void:
	var style_normal: StyleBoxFlat = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.08, 0.01, 0.01, 0.9)
	style_normal.border_color = Color(1.0, 0.1, 0.1, 0.7)
	style_normal.border_width_left = 2
	style_normal.border_width_right = 2
	style_normal.border_width_top = 0
	style_normal.border_width_bottom = 2
	style_normal.content_margin_left = 30
	style_normal.content_margin_right = 30
	style_normal.content_margin_top = 12
	style_normal.content_margin_bottom = 12
	
	var style_hover: StyleBoxFlat = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.25, 0.03, 0.03, 1.0)
	style_hover.border_color = Color(1.0, 0.25, 0.25, 1.0)
	style_hover.border_width_left = 2
	style_hover.border_width_right = 2
	style_hover.border_width_top = 0
	style_hover.border_width_bottom = 2
	style_hover.content_margin_left = 30
	style_hover.content_margin_right = 30
	style_hover.content_margin_top = 12
	style_hover.content_margin_bottom = 12
	
	var style_pressed: StyleBoxFlat = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.4, 0.06, 0.06, 1.0)
	style_pressed.border_color = Color(1.0, 0.4, 0.4, 1.0)
	style_pressed.border_width_left = 2
	style_pressed.border_width_right = 2
	style_pressed.border_width_top = 0
	style_pressed.border_width_bottom = 2
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_color_override("font_color", Color(1.0, 0.8, 0.8))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.9))
	btn.add_theme_font_size_override("font_size", 26)
