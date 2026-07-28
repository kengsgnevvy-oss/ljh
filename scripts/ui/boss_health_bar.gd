extends CanvasLayer

# ============================================================
# ULTRANOKIA Boss Health Bar
# Top-screen bar showing boss name and HP
# Appears on boss encounter, disappears on boss defeat
# ============================================================

@onready var boss_name_label: Label = $BossBarContainer/BossNameLabel
@onready var health_bar: TextureProgressBar = $BossBarContainer/HealthBar
@onready var health_percent_label: Label = $BossBarContainer/HealthPercentLabel
@onready var bar_container: Control = $BossBarContainer

var _tracked_boss: Node = null


func _ready() -> void:
	bar_container.visible = false
	Global.ui_boss_encounter_started.connect(_on_boss_encounter_started)
	Global.ui_boss_encounter_ended.connect(_on_boss_encounter_ended)


func _process(_delta: float) -> void:
	if _tracked_boss == null:
		# Try to find boss in the scene
		var bosses: Array = get_tree().get_nodes_in_group("boss")
		if not bosses.is_empty():
			for b in bosses:
				if b.has_method("get_boss_health_percent") and not b.get("is_dead"):
					_tracked_boss = b
					_show_bar(b)
					break
	
	if _tracked_boss and is_instance_valid(_tracked_boss):
		var percent: float = 0.0
		if _tracked_boss.has_method("get_boss_health_percent"):
			percent = _tracked_boss.get_boss_health_percent()
		
		health_bar.value = percent * 100.0
		health_percent_label.text = str(int(percent * 100)) + "%"
		
		if percent <= 0.0:
			_hide_bar()
			_tracked_boss = null
	else:
		if bar_container.visible:
			_hide_bar()
			_tracked_boss = null


func _on_boss_encounter_started(boss_name: String) -> void:
	_show_bar_named(boss_name)


func _on_boss_encounter_ended() -> void:
	_hide_bar()


func _show_bar(boss: Node) -> void:
	var boss_name: String = "UNKNOWN"
	if "boss_name" in boss:
		boss_name = boss.get("boss_name")
	
	boss_name_label.text = boss_name.to_upper()
	health_bar.value = 100.0
	health_percent_label.text = "100%"
	bar_container.visible = true
	
	# Slide-in animation
	bar_container.modulate.a = 0
	var tween: Tween = create_tween()
	tween.tween_property(bar_container, "modulate:a", 1.0, 0.3)


func _show_bar_named(boss_name: String) -> void:
	boss_name_label.text = boss_name.to_upper()
	health_bar.value = 100.0
	health_percent_label.text = "100%"
	bar_container.visible = true
	
	bar_container.modulate.a = 0
	var tween: Tween = create_tween()
	tween.tween_property(bar_container, "modulate:a", 1.0, 0.3)


func _hide_bar() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(bar_container, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): bar_container.visible = false)
