extends CanvasLayer

# ============================================================
# ULTRANOKIA Cutscene Player
# Simple text-based cutscene system
# ============================================================

signal cutscene_finished

@onready var text_label: Label = $CenterContainer/TextLabel
@onready var bg_rect: ColorRect = $Background
@onready var skip_label: Label = $SkipLabel

var _current_tween: Tween = null
var _is_playing: bool = false
var _skip_pressed: bool = false


func _ready() -> void:
    bg_rect.visible = false
    text_label.visible = false
    skip_label.visible = false


func _input(event: InputEvent) -> void:
    if _is_playing and (event.is_action_pressed("shoot") or event.is_action_pressed("jump") or event.is_action_pressed("pause")):
        _skip_pressed = true
        _skip_cutscene()


func play_text(text: String, duration: float = 4.0) -> void:
    _is_playing = true
    _skip_pressed = false
    
    bg_rect.visible = true
    text_label.visible = true
    skip_label.visible = true
    text_label.text = text
    
    # Fade in
    bg_rect.modulate.a = 0
    text_label.modulate.a = 0
    
    var tween: Tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(bg_rect, "modulate:a", 0.85, 0.5)
    tween.tween_property(text_label, "modulate:a", 1.0, 0.5)
    
    # Wait then fade out
    tween.chain().tween_interval(duration * 0.7)
    tween.tween_callback(_start_fade_out.bind(duration * 0.3))


func play_sequence(texts: Array, durations: Array = []) -> void:
    _is_playing = true
    _skip_pressed = false
    _play_next_in_sequence(texts, durations, 0)


func _play_next_in_sequence(texts: Array, durations: Array, index: int) -> void:
    if _skip_pressed or index >= texts.size():
        _finish_cutscene()
        return
    
    var dur: float = 3.0
    if index < durations.size():
        dur = durations[index]
    
    bg_rect.visible = true
    text_label.visible = true
    skip_label.visible = true
    text_label.text = texts[index]
    
    bg_rect.modulate.a = 0
    text_label.modulate.a = 0
    
    var tween: Tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(bg_rect, "modulate:a", 0.85, 0.3)
    tween.tween_property(text_label, "modulate:a", 1.0, 0.3)
    
    tween.chain().tween_interval(dur * 0.7)
    tween.tween_callback(_start_fade_out.bind(dur * 0.3))
    tween.tween_callback(_play_next_in_sequence.bind(texts, durations, index + 1))


func _start_fade_out(fade_duration: float) -> void:
    var tween_out: Tween = create_tween()
    tween_out.set_parallel(true)
    tween_out.tween_property(bg_rect, "modulate:a", 0.0, fade_duration)
    tween_out.tween_property(text_label, "modulate:a", 0.0, fade_duration)
    tween_out.chain().tween_callback(func():
        bg_rect.visible = false
        text_label.visible = false
        skip_label.visible = false
    )


func _skip_cutscene() -> void:
    if _current_tween:
        _current_tween.kill()
    _finish_cutscene()


func _finish_cutscene() -> void:
    _is_playing = false
    bg_rect.visible = false
    text_label.visible = false
    skip_label.visible = false
    bg_rect.modulate.a = 0
    text_label.modulate.a = 0
    cutscene_finished.emit()


func is_playing() -> bool:
    return _is_playing


func await_finish() -> void:
    if not _is_playing:
        return
    await cutscene_finished
