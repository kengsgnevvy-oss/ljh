extends Node

# Global autoload singleton for ULTRANOKIA
# Stores persistent game state across scenes

# Player stats
var player_health: int = 100
var player_max_health: int = 100
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

func _ready() -> void:
    reset_game()

func reset_game() -> void:
    player_health = player_max_health
    player_ammo = player_max_ammo
    player_score = 0
    player_style = 0.0
    style_rank = 0
    enemies_alive = 0
    enemies_killed = 0
    is_paused = false
    is_game_over = false
    current_level = 1

func add_score(points: int) -> void:
    player_score += points

func take_damage(amount: int) -> void:
    player_health = max(0, player_health - amount)
    if player_health <= 0:
        is_game_over = true

func heal(amount: int) -> void:
    player_health = min(player_health + amount, player_max_health)

func add_style(amount: float) -> void:
    player_style = min(player_style + amount, 5.0)
    style_rank = int(player_style)

func notify_kill(is_glory_kill: bool = false) -> void:
    enemies_alive = max(0, enemies_alive - 1)
    enemies_killed += 1
    if is_glory_kill:
        add_style(0.5)
    else:
        add_style(0.3)

func get_style_letter() -> String:
    match int(player_style):
        0: return "D"
        1: return "C"
        2: return "B"
        3: return "A"
        4: return "S"
        _: return "U"


# Loading screen signals
signal loading_screen_requested
signal loading_screen_hidden

func emit_loading_screen() -> void:
    loading_screen_requested.emit()

func hide_loading_screen() -> void:
    loading_screen_hidden.emit()
