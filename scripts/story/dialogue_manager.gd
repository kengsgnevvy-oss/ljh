extends Node

# ============================================================
# ULTRANOKIA Dialogue Manager (Autoload)
# Manages story cutscenes, intros, outros, ending, credits
# ============================================================

signal game_intro_finished
signal level_intro_finished(level_index: int)
signal level_outro_finished(level_index: int)
signal ending_finished

var _cutscene_player: CanvasLayer = null
var _cutscene_data: RefCounted = null

# Track if we've shown the game intro (only once per session)
var _game_intro_shown: bool = false
var _is_playing: bool = false


func _ready() -> void:
	_cutscene_data = preload("res://scripts/story/cutscene_data.gd").new()
	# CutscenePlayer is instantiated by main_bootstrap; find it in the tree
	call_deferred("_find_cutscene_player")


func _find_cutscene_player() -> void:
	var tree := get_tree()
	if tree:
		_cutscene_player = tree.root.find_child("CutscenePlayer", true, false) as CanvasLayer


# --- Public API ---

## Show a single dialogue text with optional duration
func show_dialogue(text: String, duration: float = 4.0) -> void:
	if not _ensure_player():
		return
	_is_playing = true
	_cutscene_player.play_text(text, duration)
	await _cutscene_player.await_finish()
	_is_playing = false


## Show a sequence of dialogue texts
func show_dialogue_sequence(texts: PackedStringArray, durations: Array = []) -> void:
	if not _ensure_player():
		return
	_is_playing = true
	var text_arr: Array = []
	for t in texts:
		text_arr.append(t)
	_cutscene_player.play_sequence(text_arr, durations)
	await _cutscene_player.await_finish()
	_is_playing = false


## Get intro text for a level (1-indexed level number)
func get_level_intro(level_num: int) -> String:
	var idx := level_num - 1
	if idx >= 0 and idx < _cutscene_data.LEVEL_INTROS.size():
		return _cutscene_data.LEVEL_INTROS[idx]
	return ""


## Get outro text for a level (1-indexed level number)
func get_level_outro(level_num: int) -> String:
	var idx := level_num - 1
	if idx >= 0 and idx < _cutscene_data.LEVEL_OUTROS.size():
		return _cutscene_data.LEVEL_OUTROS[idx]
	return ""


## Get level name
func get_level_name(level_num: int) -> String:
	var idx := level_num - 1
	if idx >= 0 and idx < _cutscene_data.LEVEL_NAMES.size():
		return _cutscene_data.LEVEL_NAMES[idx]
	return "UNKNOWN"


# --- Flow Methods ---

## Play the full game intro sequence (before Level 1)
func play_game_intro() -> void:
	if _game_intro_shown:
		game_intro_finished.emit()
		return
	
	_is_playing = true
	_game_intro_shown = true
	
	await show_dialogue_sequence(_cutscene_data.GAME_INTRO)
	
	# Brief pause after intro
	await get_tree().create_timer(1.0).timeout
	
	_is_playing = false
	game_intro_finished.emit()


## Play the outro for a completed level, then intro for the next
func play_level_transition(completed_level_index: int) -> void:
	_is_playing = true
	
	# Show outro for completed level
	var level_num := completed_level_index + 1
	var outro_text := get_level_outro(level_num)
	if outro_text != "":
		await show_dialogue(outro_text, 4.5)
		level_outro_finished.emit(completed_level_index)
		await get_tree().create_timer(1.5).timeout
	
	# Show intro for next level
	var next_level_num := level_num + 1
	var intro_text := get_level_intro(next_level_num)
	if intro_text != "":
		await show_dialogue(intro_text, 4.5)
		level_intro_finished.emit(completed_level_index + 1)
		await get_tree().create_timer(1.0).timeout
	
	_is_playing = false


## Play the ending sequence + credits
func play_ending() -> void:
	_is_playing = true
	
	# Play ending cutscene
	await show_dialogue_sequence(_cutscene_data.ENDING_SEQUENCE)
	await get_tree().create_timer(2.0).timeout
	
	# Play credits
	var credit_arr: Array = []
	for c in _cutscene_data.CREDITS:
		credit_arr.append(c)
	
	var credit_durations: Array = []
	for _i in _cutscene_data.CREDITS.size():
		credit_durations.append(2.0)
	
	if _ensure_player():
		_cutscene_player.play_sequence(credit_arr, credit_durations)
		await _cutscene_player.await_finish()
	
	_is_playing = false
	ending_finished.emit()


## Check if dialogue is currently playing
func is_playing() -> bool:
	return _is_playing


# --- Internal ---

## Make sure we have a reference to the cutscene player
func _ensure_player() -> bool:
	if _cutscene_player and is_instance_valid(_cutscene_player):
		return true
	_find_cutscene_player()
	return _cutscene_player != null and is_instance_valid(_cutscene_player)
