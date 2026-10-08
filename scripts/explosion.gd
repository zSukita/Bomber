class_name Explosion
extends Area2D

## Representa um segmento da explosão (fogo) na grade.
## Causa dano/eliminação a qualquer jogador que tocar na área durante a vida útil.

@export var duration: float = 0.45
var grid_position: Vector2i = Vector2i.ZERO

@onready var visual_core: ColorRect = $Visuals/Core
@onready var visual_outer: ColorRect = $Visuals/Outer

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	for body in get_overlapping_bodies():
		_handle_hit(body)
	
	_animate_and_fade()

func _animate_and_fade() -> void:
	scale = Vector2(0.3, 0.3)
	modulate.a = 1.0
	
	if GameState.is_enhanced():
		_spawn_fire_sparks()

	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(duration * 0.4)
	tween.parallel().tween_property(self, "modulate:a", 0.0, duration * 0.5)
	tween.parallel().tween_property(self, "scale", Vector2(1.15, 1.15), duration * 0.5)
	tween.chain().tween_callback(queue_free)

func _spawn_fire_sparks() -> void:
	for i in range(3):
		var spark: ColorRect = ColorRect.new()
		spark.size = Vector2(4.0, 4.0)
		spark.color = Color("fff39c") if i % 2 == 0 else Color("ff7e29")
		spark.position = Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
		add_child(spark)
		
		var spark_dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		var spark_tween: Tween = spark.create_tween()
		spark_tween.set_parallel(true)
		spark_tween.tween_property(spark, "position", spark.position + spark_dir * randf_range(16.0, 28.0), duration * 0.45)
		spark_tween.tween_property(spark, "scale", Vector2.ZERO, duration * 0.45)
		spark_tween.chain().tween_callback(spark.queue_free)

func _on_body_entered(body: Node2D) -> void:
	_handle_hit(body)

func _handle_hit(body: Node2D) -> void:
	# Em rede, apenas o servidor calcula o dano; clientes só reproduzem o efeito.
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if body is Player and body.is_alive:
		_apply_hitstop(body)
		body.die()
	elif body is CampaignEnemy and body.is_alive:
		_apply_hitstop(body)
		body.take_bomb_hit()

func _apply_hitstop(target: Node2D) -> void:
	if not GameState.is_enhanced() or not GameState.hitstop_enabled:
		return
	var prev_mod: Color = target.modulate
	target.modulate = Color(2.4, 2.4, 2.4, 1.0)
	var timer: SceneTreeTimer = get_tree().create_timer(GameState.hitstop_duration)
	timer.timeout.connect(func():
		if is_instance_valid(target):
			target.modulate = prev_mod
	)

