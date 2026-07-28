extends Node

# Global autoload singleton for ULTRANOKIA
# Stores persistent game state across scenes

# Player stats
var player_health: int = 100
var player_max_health: int = 100
var player_armor: int = 0
var player_max_armor: int = 100
var player_ammo: int = 30
var player_max_ammo: int = 30
var player_score: int = 0

# Style system
var player_style: float = 0.0
var style_rank: int = 0

# Enemy tracking
var enemies_alive: int = 0
var enemies_killed: int = 0

# Game state
var is_paused: bool = false
var is_game_over: bool = false
var current_level: int = 1

# UI state
var in_boss_fight: bool = false
var current_boss_name: String = ""
var current_boss_node: Node = null

func _ready() -> void:
    reset_game()

func reset_game() -> void:
    player_health = player_max_health
    player_armor = 0
    player_ammo = player_max_ammo
    player_score = 0
    player_style = 0.0
    style_rank = 0
    enemies_alive = 0
    enemies_killed = 0
    is_paused = false
    is_game_over = false
    current_level = 1
    in_boss_fight = false
    current_boss_name = ""
    current_boss_node = null

func add_score(points: int) -> void:
    player_score += points

func take_damage(amount: int) -> void:
    # Armor absorbs damage first
    var remaining: int = amount
    if player_armor > 0:
        var armor_absorb: int = min(player_armor, amount)
        player_armor -= armor_absorb
        remaining -= armor_absorb
    
    if remaining > 0:
        player_health = max(0, player_health - remaining)
    
    if player_health <= 0:
        is_game_over = true
    
    ui_player_damaged.emit(amount)

func add_armor(amount: int) -> void:
    player_armor = min(player_armor + amount, player_max_armor)

func heal(amount: int) -> void:
    player_health = min(player_health + amount, player_max_health)

func add_style(amount: float) -> void:
    var old_rank: int = int(player_style)
    player_style = min(player_style + amount, 5.0)
    style_rank = int(player_style)
    if int(player_style) != old_rank:
        ui_style_rank_changed.emit(get_style_letter())

func notify_kill(is_glory_kill: bool = false) -> void:
    enemies_alive = max(0, enemies_alive - 1)
    enemies_killed += 1
    var style_bonus: float = 0.5 if is_glory_kill else 0.3
    add_style(style_bonus)
    ui_player_kill.emit(int(style_bonus * 100), is_glory_kill)

func get_style_letter() -> String:
    match int(player_style):
        0: return "D"
        1: return "C"
        2: return "B"
        3: return "A"
        4: return "S"
        _: return "U"

# --- Boss tracking ---
func register_boss(boss_node: Node) -> void:
    in_boss_fight = true
    current_boss_node = boss_node
    if boss_node.has_method("get") or "boss_name" in boss_node:
        current_boss_name = boss_node.get("boss_name") if "boss_name" in boss_node else "UNKNOWN"
    ui_boss_encounter_started.emit(current_boss_name)

func unregister_boss() -> void:
    in_boss_fight = false
    current_boss_node = null
    current_boss_name = ""
    ui_boss_encounter_ended.emit()

# Screen shake signal
signal screen_shake_requested(intensity: float, duration: float)

func apply_screen_shake(intensity: float, duration: float) -> void:
    screen_shake_requested.emit(intensity, duration)

# Loading screen signals
signal loading_screen_requested
signal loading_screen_hidden

# UI signals
signal ui_player_damaged(amount: int)
signal ui_style_rank_changed(new_rank: String)
signal ui_player_kill(style_points: int, is_glory: bool)
signal ui_boss_encounter_started(boss_name: String)
signal ui_boss_encounter_ended

func emit_loading_screen() -> void:
    loading_screen_requested.emit()

func hide_loading_screen() -> void:
    loading_screen_hidden.emit()
