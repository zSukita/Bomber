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
	
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(duration * 0.4)
	tween.parallel().tween_property(self, "modulate:a", 0.0, duration * 0.5)
	tween.parallel().tween_property(self, "scale", Vector2(1.15, 1.15), duration * 0.5)
	tween.chain().tween_callback(queue_free)

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
