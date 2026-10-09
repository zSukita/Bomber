class_name Explosion
extends Area2D

## Representa um segmento da explosão (fogo) na grade.
## Causa dano/eliminação a qualquer jogador ou inimigo que tocar na área durante a vida útil.

@export var duration: float = 0.45
var grid_position: Vector2i = Vector2i.ZERO
var segment_type: int = BomberAssets.ExplosionSegment.CENTER

@onready var visual_root: Node2D = $Visuals
@onready var flame_sprite: Sprite2D = $Visuals/FlameSprite

var elapsed_time: float = 0.0
var current_anim_frame: int = -1

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_update_flame_frame(0)
	
	for body in get_overlapping_bodies():
		_handle_hit(body)
	
	_animate_and_fade()

func set_segment_type(type: int) -> void:
	segment_type = type
	if flame_sprite:
		_update_flame_frame(current_anim_frame if current_anim_frame >= 0 else 0)

func _process(delta: float) -> void:
	elapsed_time += delta
	# Anima através dos 4 quadros da cruz de fogo (0, 1, 2, 3)
	var frame_idx: int = clampi(int((elapsed_time / duration) * 4.0), 0, 3)
	if frame_idx != current_anim_frame:
		_update_flame_frame(frame_idx)

func _update_flame_frame(frame: int) -> void:
	current_anim_frame = frame
	if flame_sprite:
		BomberAssets.configure_explosion_sprite(flame_sprite, segment_type, current_anim_frame)

func _animate_and_fade() -> void:
	scale = Vector2(0.6, 0.6)
	modulate.a = 1.0
	
	if GameState.is_enhanced():
		_spawn_fire_sparks()

	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(duration * 0.45)
	tween.parallel().tween_property(self, "modulate:a", 0.0, duration * 0.45)
	tween.chain().tween_callback(queue_free)

func _spawn_fire_sparks() -> void:
	var effect_intensity: float = clampf(GameState.visual_effects_intensity, 0.0, 1.0)
	var spark_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	spark_rng.seed = int(get_instance_id())
	for i in range(roundi(3.0 * effect_intensity)):
		var spark: ColorRect = ColorRect.new()
		spark.add_to_group("enhanced_visual_effects")
		spark.size = Vector2(4.0, 4.0)
		spark.color = Color("fff39c") if i % 2 == 0 else Color("ff7e29")
		spark.position = Vector2(spark_rng.randf_range(-12.0, 12.0), spark_rng.randf_range(-12.0, 12.0))
		add_child(spark)
		
		var spark_dir := Vector2(spark_rng.randf_range(-1.0, 1.0), spark_rng.randf_range(-1.0, 1.0)).normalized()
		var travel_distance: float = spark_rng.randf_range(16.0, 28.0) * effect_intensity
		var spark_tween: Tween = spark.create_tween()
		spark_tween.set_parallel(true)
		spark_tween.tween_property(spark, "position", spark.position + spark_dir * travel_distance, duration * 0.45)
		spark_tween.tween_property(spark, "scale", Vector2.ZERO, duration * 0.45)
		spark_tween.chain().tween_callback(spark.queue_free)

func _on_body_entered(body: Node2D) -> void:
	_handle_hit(body)

func _handle_hit(body: Node2D) -> void:
	# Em rede, apenas o servidor calcula o dano; clientes só reproduzem o efeito.
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if body is Player and body.is_alive:
		body.die()
	elif body is CampaignEnemy and body.is_alive:
		body.take_bomb_hit()
