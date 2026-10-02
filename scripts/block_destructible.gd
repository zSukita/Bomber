class_name BlockDestructible
extends StaticBody2D

## Sinal disparado quando o bloco é destruído.
signal destroyed(grid_pos: Vector2i)

## Coordenada do bloco na grade lógica.
var grid_position: Vector2i = Vector2i.ZERO

## Executa a animação de destruição com rotação e estilhaçamento visual
func destroy() -> void:
	destroyed.emit(grid_position)
	$CollisionShape2D.set_deferred("disabled", true)
	
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "rotation", deg_to_rad(randf_range(-40.0, 40.0)), 0.22)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.22)
	tween.chain().tween_callback(queue_free)
