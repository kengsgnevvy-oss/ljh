extends EnemyBase
class_name EnemySummoner

# ============================================================
# Summoner Demon — Stays back, spawns Imp minions
# ============================================================

var summon_timer: float = 0.0
var summon_interval: float = 5.0
var imp_scene: PackedScene = null
var max_imps: int = 4
var active_imps: Array = []

func _setup_enemy() -> void:
    health = 120
    max_health = 120
    speed = 4.0
    damage = 10
    attack_range = 3.0
    detection_range = 25.0
    attack_cooldown = 1.5
    score_value = 200
    summon_interval = 5.0

func _physics_process(delta: float) -> void:
    if is_dead:
        return
    
    if not player:
        player = get_tree().get_first_node_in_group("player")
        if not player:
            return
    
    # Clean up dead imps
    active_imps = active_imps.filter(func(imp): return is_instance_valid(imp))
    
    var distance_to_player := global_position.distance_to(player.global_position)
    
    if distance_to_player > detection_range:
        _idle_behavior(delta)
        return
    
    # Face player
    var look_dir := (player.global_position - global_position)
    look_dir.y = 0
    if look_dir.length() > 0.01:
        look_at(global_position - look_dir.normalized(), Vector3.UP, true)
    
    # Keep distance from player — retreat
    if distance_to_player < 8.0:
        var away := (global_position - player.global_position).normalized()
        away.y = 0
        velocity.x = away.x * speed
        velocity.z = away.z * speed
    elif distance_to_player > 15.0:
        var toward := (player.global_position - global_position).normalized()
        toward.y = 0
        velocity.x = toward.x * speed
        velocity.z = toward.z * speed
    else:
        velocity.x = move_toward(velocity.x, 0, speed * delta)
        velocity.z = move_toward(velocity.z, 0, speed * delta)
    
    velocity.y -= 30.0 * delta
    
    # Summon imps
    summon_timer -= delta
    if summon_timer <= 0.0 and active_imps.size() < max_imps:
        _summon_imp()
        summon_timer = summon_interval
    
    # Melee attack if cornered
    if distance_to_player <= attack_range:
        attack_timer -= delta
        if attack_timer <= 0.0:
            _do_attack()
    
    _process_flash(delta)
    move_and_slide()


func _summon_imp() -> void:
    var imp := CharacterBody3D.new()
    imp.name = "ImpMinion"
    
    # Collision
    var col := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(0.5, 0.5, 0.5)
    col.shape = box
    imp.add_child(col)
    
    # Mesh — small red box
    var mesh := MeshInstance3D.new()
    var box_mesh := BoxMesh.new()
    box_mesh.size = Vector3(0.5, 0.5, 0.5)
    mesh.mesh = box_mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(1.0, 0.15, 0.15, 1.0)
    mat.emission_enabled = true
    mat.emission = Color(0.5, 0, 0, 1)
    mesh.set_surface_override_material(0, mat)
    imp.add_child(mesh)
    
    # Spawn near summoner
    var offset := Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
    imp.global_position = global_position + offset
    imp.add_to_group("enemy")
    
    # Simple AI script for imp
    var script := GDScript.new()
    script.source_code = """extends CharacterBody3D
var player: Node3D = null
var speed: float = 8.0
var damage: int = 5
var health: int = 20
var is_dead: bool = false

func _ready():
    add_to_group("enemy")
    player = get_tree().get_first_node_in_group("player")
    Global.enemies_alive += 1

func _physics_process(delta):
    if is_dead or not player:
        return
    var dir = (player.global_position - global_position).normalized()
    dir.y = 0
    velocity.x = dir.x * speed
    velocity.z = dir.z * speed
    velocity.y -= 30.0 * delta
    move_and_slide()
    
    if global_position.distance_to(player.global_position) < 1.5:
        if player.has_method("take_damage"):
            player.take_damage(damage)

func take_damage(amount, _source = null):
    health -= amount
    if health <= 0:
        die()

func die(_glory = false):
    if is_dead: return
    is_dead = true
    Global.notify_kill(false)
    Global.add_score(25)
    queue_free()

func get_health_percent():
    return float(health) / 20.0
"""
    script.reload()
    imp.set_script(script)
    
    get_tree().root.add_child(imp)
    active_imps.append(imp)


func die(is_glory_kill: bool = false) -> void:
    # Kill all active imps when summoner dies
    for imp in active_imps:
        if is_instance_valid(imp):
            imp.queue_free()
    active_imps.clear()
    super.die(is_glory_kill)
