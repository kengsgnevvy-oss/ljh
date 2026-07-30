extends "res://scripts/enemies/enemy_base.gd"
class_name EnemyFlier

# ============================================================
# Flier Demon — Fast aerial harasser
# ============================================================

func _setup_enemy() -> void:
	health = 50
	max_health = 50
	speed = 10.0
	damage = 8
	attack_range = 3.0
	detection_range = 30.0
	attack_cooldown = 0.8
	score_value = 125
	can_fly = true

func _ready() -> void:
	super._ready()
	# Position higher
	global_position.y += 4.0
