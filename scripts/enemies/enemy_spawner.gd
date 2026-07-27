extends Node3D
class_name EnemySpawner

# ============================================================
# ULTRANOKIA Enemy Spawner
# Spawns enemies at predefined spawn points around the arena
# ============================================================

@export var enemy_scenes: Array[PackedScene] = []
@export var spawn_count: int = 10
@export var spawn_radius: float = 20.0
@export var spawn_delay: float = 0.3
@export var auto_spawn: bool = true

var spawned: int = 0
var spawn_timer: float = 0.0


func _ready() -> void:
	if auto_spawn and enemy_scenes.size() > 0:
		spawn_timer = 0.0


func _process(delta: float) -> void:
	if not auto_spawn or spawned >= spawn_count or enemy_scenes.size() == 0:
		return
	
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_one()
		spawn_timer = spawn_delay


func _spawn_one() -> void:
	var scene := enemy_scenes.pick_random()
	if not scene:
		return
	
	var enemy := scene.instantiate()
	
	# Random position around spawner
	var angle := randf_range(0, TAU)
	var dist := randf_range(2.0, spawn_radius)
	var pos := global_position + Vector3(
		cos(angle) * dist,
		1.0,  # Spawn slightly above ground
		sin(angle) * dist
	)
	
	enemy.global_position = pos
	get_tree().root.add_child(enemy)
	spawned += 1


func spawn_wave(amount: int = -1) -> void:
	var count := amount if amount > 0 else spawn_count
	for i in range(count):
		_spawn_one()
		await get_tree().create_timer(spawn_delay).timeout


func spawn_at_position(scene: PackedScene, position: Vector3) -> Node3D:
	var enemy := scene.instantiate()
	enemy.global_position = position
	get_tree().root.add_child(enemy)
	return enemy
