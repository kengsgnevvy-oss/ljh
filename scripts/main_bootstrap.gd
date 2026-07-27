extends Node

# Bootstrap script for main scene
# Triggers loading of the first level via LevelManager

func _ready() -> void:
	# Wait one frame for everything to initialize, then load the first level
	await get_tree().process_frame
	if LevelManager:
		LevelManager.load_level(0)
	else:
		push_error("MainBootstrap: LevelManager autoload not found!")
