extends "res://scripts/weapons/weapon_base.gd"
# SHOTGUN — "Demon's Maw"
# Close-range pellet spread with charged slug alt-fire

var slug_charge_time: float = 0.0
var slug_max_charge: float = 0.8
var is_charging_slug: bool = false


func _setup_weapon() -> void:
    weapon_name = "Demon's Maw"
    weapon_slot = 2
    damage = 8.0  # per pellet
    fire_rate = 0.8
    max_ammo = 8
    current_ammo = max_ammo
    reload_time = 2.0  # shell-by-shell feel
    auto_fire = false
    spread = 15.0  # wide cone
    weapon_range = 50.0
    alt_fire_ammo_cost = 2


# Primary: 8-pellet buckshot
func _do_fire() -> void:
    for i in range(8):
        _do_hitscan(damage, false)


# Alt-fire: Charged Slug — hold to charge, release to fire
func _do_alt_fire() -> void:
    # Single powerful hitscan slug
    _do_hitscan(80.0, true)  # 80 damage, penetrating


func _process(delta: float) -> void:
    super(delta)
    
    # Charged slug hold mechanic
    if Input.is_action_pressed("alt_fire") and can_alt_fire() and not is_charging_slug:
        is_charging_slug = true
        slug_charge_time = 0.0
    
    if is_charging_slug:
        slug_charge_time += delta
        if not Input.is_action_pressed("alt_fire") or slug_charge_time >= slug_max_charge:
            is_charging_slug = false
            # The actual shot happens via alt_fire() call from manager
