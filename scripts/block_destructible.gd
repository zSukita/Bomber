class_name BlockDestructible
extends StaticBody2D

## Sinal disparado quando o bloco é destruído.
signal destroyed(grid_pos: Vector2i)

## Coordenada do bloco na grade lógica.
var grid_position: Vector2i = Vector2i.ZERO

func _ready() -> void:
	$ColorRect.visible = false
	var sprite := Sprite2D.new()
	sprite.name = "StageBlockSprite"
	add_child(sprite)
	BomberAssets.configure_wall_sprite(sprite, BomberAssets.BLOCK_REGION)

## Executa a animação de destruição com rotação e estilhaçamento visual
func destroy() -> void:
	destroyed.emit(grid_position)
	$CollisionShape2D.set_deferred("disabled", true)
	var visual_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	visual_rng.seed = int(get_instance_id())
	
	if GameState.is_enhanced() and GameState.directional_debris_enabled and get_parent():
		_spawn_debris(visual_rng)

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "rotation", deg_to_rad(visual_rng.randf_range(-40.0, 40.0)), 0.22)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.22)
	tween.chain().tween_callback(queue_free)

func _spawn_debris(debris_rng: RandomNumberGenerator) -> void:
	var parent_node: Node = get_parent()
	var base_col: Color = $ColorRect.color * modulate
	var mortar_col: Color = base_col.darkened(0.3)
	var effect_intensity: float = clampf(GameState.visual_effects_intensity, 0.0, 1.0)
	
	for i in range(roundi(5.0 * effect_intensity)):
		var debris: ColorRect = ColorRect.new()
		debris.add_to_group("enhanced_visual_effects")
		var d_size := debris_rng.randf_range(4.0, 8.0) * effect_intensity
		debris.size = Vector2(d_size, d_size)
		debris.color = base_col if i % 2 == 0 else mortar_col
		debris.position = global_position + Vector2(debris_rng.randf_range(-16.0, 16.0), debris_rng.randf_range(-16.0, 16.0))
		debris.z_index = 4
		parent_node.add_child(debris)
		
		var fly_dir := Vector2(debris_rng.randf_range(-1.0, 1.0), debris_rng.randf_range(-1.2, 0.3)).normalized()
		var target_pos := debris.position + fly_dir * debris_rng.randf_range(28.0, 52.0) * effect_intensity
		
		var d_tween: Tween = debris.create_tween()
		d_tween.set_parallel(true)
		d_tween.tween_property(debris, "position", target_pos, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		d_tween.tween_property(debris, "rotation", debris_rng.randf_range(-3.0, 3.0), 0.28)
		d_tween.tween_property(debris, "modulate:a", 0.0, 0.28).set_delay(0.12)
		d_tween.chain().tween_callback(debris.queue_free)
