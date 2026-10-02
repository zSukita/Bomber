class_name PowerUp
extends Area2D

## Representa um item coletável (Power-up) no jogo Bombástico.
## Tipos definidos em GameState.PowerUpType:
## - BOMB (+1 capacidade de bombas simultâneas)
## - RANGE (+1 alcance do fogo das explosões)
## - SPEED (+velocidade de movimento do jogador)

signal destroyed_by_fire(cell: Vector2i)

@export var type: GameState.PowerUpType = GameState.PowerUpType.BOMB
var grid_position: Vector2i = Vector2i.ZERO

@onready var visual_root: Node2D = $Visuals
@onready var background_rect: ColorRect = $Visuals/Background
@onready var icon_label: Label = $Visuals/IconLabel
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var is_collected: bool = false
var float_tween: Tween

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	_setup_visual()
	_start_floating_animation()

func _setup_visual() -> void:
	match type:
		GameState.PowerUpType.BOMB:
			background_rect.color = Color(0.2, 0.22, 0.3, 1.0)
			icon_label.text = "💣+"
			icon_label.modulate = Color(0.9, 0.9, 1.0)
		GameState.PowerUpType.RANGE:
			background_rect.color = Color(0.85, 0.45, 0.1, 1.0)
			icon_label.text = "🔥+"
			icon_label.modulate = Color(1.0, 0.95, 0.4)
		GameState.PowerUpType.SPEED:
			background_rect.color = Color(0.1, 0.6, 0.75, 1.0)
			icon_label.text = "⚡+"
			icon_label.modulate = Color(0.7, 1.0, 1.0)
		GameState.PowerUpType.HEART:
			background_rect.color = Color(0.72, 0.18, 0.33, 1.0)
			icon_label.text = "♥"
			icon_label.modulate = Color(1.0, 0.88, 0.92)

func _start_floating_animation() -> void:
	float_tween = create_tween().set_loops()
	float_tween.tween_property(visual_root, "position:y", -4.0, 0.4).set_trans(Tween.TRANS_SINE)
	float_tween.tween_property(visual_root, "position:y", 4.0, 0.4).set_trans(Tween.TRANS_SINE)

func _on_area_entered(area: Area2D) -> void:
	# Só o servidor decide se fogo remove o item; os clientes recebem a RPC.
	if is_collected or (multiplayer.has_multiplayer_peer() and not multiplayer.is_server()):
		return
	if area.is_in_group("explosions"):
		destroy_by_fire()

func destroy_by_fire() -> void:
	if is_collected:
		return
	is_collected = true
	collision_shape.set_deferred("disabled", true)
	if float_tween and float_tween.is_valid():
		float_tween.kill()
	
	destroyed_by_fire.emit(grid_position)
	
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual_root, "scale", Vector2.ZERO, 0.2)
	tween.tween_property(self, "modulate", Color(0.2, 0.2, 0.2, 0.0), 0.2)
	tween.chain().tween_callback(queue_free)
