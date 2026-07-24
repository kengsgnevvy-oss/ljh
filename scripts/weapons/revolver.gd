extends "res://scripts/weapons/weapon_base.gd"
# REVOLVER — "Hellbringer"
# Precision hand-cannon with fan-fire alt mode

func _setup_weapon() -> void:
    weapon_name = "Hellbringer"
    weapon_slot = 1
    damage = 35.0
    fire_rate = 0.4
    max_ammo = 6
    current_ammo = max_ammo
    reload_time = 1.2
    auto_fire = false
    spread = 0.5  # very accurate
    weapon_range = 200.0
    alt_fire_ammo_cost = 3


# Primary: single accurate shot (hitscan)
func _do_fire() -> void:
    _do_hitscan(damage, false)


# Alt-fire: Fan-fire — 3 rapid shots with high spread
func _do_alt_fire() -> void:
    for i in range(3):
        var fan_spread: float = spread * 3.0
        _do_hitscan(damage * 0.8, false)
        await get_tree().create_timer(0.05).timeout
