extends CanvasLayer

# ============================================================
# ULTRANOKIA Main Menu
# Hell-tech themed main menu with animated background
# ============================================================

@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var new_game_btn: Button = $CenterContainer/VBoxContainer/NewGameBtn
@onready var continue_btn: Button = $CenterContainer/VBoxContainer/ContinueBtn
@onready var settings_btn: Button = $CenterContainer/VBoxContainer/SettingsBtn
@onready var quit_btn: Button = $CenterContainer/VBoxContainer/QuitBtn
@onready var ambient_player: AudioStreamPlayer = $AmbientPlayer


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	new_game_btn.pressed.connect(_on_new_game)
	continue_btn.pressed.connect(_on_continue)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)
	
	_style_button(new_game_btn)
	_style_button(continue_btn)
	_style_button(settings_btn)
	_style_button(quit_btn)
	
	# Title glitch/pulse animation via tween
	_start_title_animation()
	
	if ambient_player:
		ambient_player.play()
	
	continue_btn.disabled = not _has_save()


func _start_title_animation() -> void:
	var tween: Tween = create_tween()
	tween.set_loops()
	tween.tween_property(title_label, "modulate:a", 0.7, 1.5).from(1.0)
	tween.tween_property(title_label, "modulate:a", 1.0, 1.5)
	
	# Slight color shift
	var tween2: Tween = create_tween()
	tween2.set_loops()
	tween2.tween_property(title_label, "theme_override_colors/font_color", Color(1, 0.15, 0.15, 1), 0.8).from(Color(1, 0.05, 0.05, 1))
	tween2.tween_property(title_label, "theme_override_colors/font_color", Color(1, 0.05, 0.05, 1), 0.8)


func _style_button(btn: Button) -> void:
	var style_normal: StyleBoxFlat = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.15, 0.02, 0.02, 0.9)
	style_normal.border_color = Color(1.0, 0.15, 0.15, 0.8)
	style_normal.border_width_left = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.content_margin_left = 30
	style_normal.content_margin_right = 30
	style_normal.content_margin_top = 12
	style_normal.content_margin_bottom = 12
	
	var style_hover: StyleBoxFlat = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.3, 0.05, 0.05, 1.0)
	style_hover.border_color = Color(1.0, 0.3, 0.3, 1.0)
	style_hover.border_width_left = 2
	style_hover.border_width_right = 2
	style_hover.border_width_bottom = 2
	style_hover.content_margin_left = 30
	style_hover.content_margin_right = 30
	style_hover.content_margin_top = 12
	style_hover.content_margin_bottom = 12
	
	var style_pressed: StyleBoxFlat = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.5, 0.08, 0.08, 1.0)
	style_pressed.border_color = Color(1.0, 0.5, 0.5, 1.0)
	style_pressed.border_width_left = 2
	style_pressed.border_width_right = 2
	style_pressed.border_width_bottom = 2
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.8))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.9))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
	btn.add_theme_font_size_override("font_size", 28)


func _on_new_game() -> void:
	Global.reset_game()
	queue_free()
	if LevelManager:
		LevelManager.load_level(0)


func _on_continue() -> void:
	queue_free()
	if LevelManager:
		var idx: int = max(0, Global.current_level - 1)
		LevelManager.load_level(idx)


func _on_settings() -> void:
	print("Settings not yet implemented")


func _on_quit() -> void:
	get_tree().quit()


func _has_save() -> bool:
	return Global.current_level > 1
