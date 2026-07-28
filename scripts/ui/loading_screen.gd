extends CanvasLayer

# ============================================================
# ULTRANOKIA Loading Screen
# Dark screen with title and pulsing progress bar
# ============================================================

@onready var level_name_label: Label = $CenterContainer/VBoxContainer/LevelName
@onready var loading_label: Label = $CenterContainer/VBoxContainer/LoadingLabel
@onready var progress_bar: ProgressBar = $CenterContainer/VBoxContainer/ProgressBar
@onready var bg_rect: ColorRect = $Background

var _active: bool = false
var _pulse_time: float = 0.0


func _ready() -> void:
	hide()
	Global.loading_screen_requested.connect(_show_loading)
	Global.loading_screen_hidden.connect(_hide_loading)


func _process(delta: float) -> void:
	if not _active:
		return
	
	# Pulsing progress bar
	_pulse_time += delta * 3.0
	progress_bar.value = (sin(_pulse_time) * 0.5 + 0.5) * 100.0


func _show_loading() -> void:
	_active = true
	show()
	
	# Get level name from LevelManager
	var level_name: String = "UNKNOWN LEVEL"
	if LevelManager:
		level_name = LevelManager.get_level_name()
	
	level_name_label.text = level_name
	loading_label.text = "LOADING..."
	
	_pulse_time = 0.0


func _hide_loading() -> void:
	_active = false
	hide()


func show_with_message(level_name: String, duration: float = -1.0) -> void:
	_active = true
	show()
	level_name_label.text = level_name
	loading_label.text = "LOADING..."
	_pulse_time = 0.0
	
	if duration > 0:
		var timer: SceneTreeTimer = get_tree().create_timer(duration)
		timer.timeout.connect(_hide_loading)
