extends EnemyBase
class_name EnemySoldier

# ============================================================
# Soldier Demon — Standard frontline grunt
# ============================================================

func _setup_enemy() -> void:
	health = 80
	max_health = 80
	speed = 6.0
	damage = 15
	attack_range = 2.0
	detection_range = 20.0
	attack_cooldown = 1.0
	score_value = 100
