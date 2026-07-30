extends "res://scripts/enemies/enemy_base.gd"
class_name EnemyHeavy

# ============================================================
# Heavy Demon — Big, slow, devastating
# ============================================================

func _setup_enemy() -> void:
	health = 250
	max_health = 250
	speed = 3.0
	damage = 35
	attack_range = 2.5
	detection_range = 18.0
	attack_cooldown = 2.0
	score_value = 250
