class_name PowerUp
extends Area2D

## Representa um item coletável (Power-up) no jogo Bombástico.
## Utiliza os sprites clássicos de Super Bomberman 3 (Bomba, Fogo/Range, Patins/Speed, Coração).

signal destroyed_by_fire(cell: Vector2i)

@export var type: GameState.PowerUpType = GameState.PowerUpType.BOMB
var grid_position: Vector2i = Vector2i.ZERO

@onready var visual_root: Node2D = $Visuals
@onready var item_sprite: Sprite2D = $Visuals/ItemSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var is_collected: bool = false
var float_tween: Tween

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	_setup_visual()
	_start_floating_animation()

func _setup_visual() -> void:
	if not item_sprite:
		item_sprite = Sprite2D.new()
		item_sprite.name = "ItemSprite"
		visual_root.add_child(item_sprite)
	BomberAssets.configure_powerup_sprite(item_sprite, type)

func _start_floating_animation() -> void:
	float_tween = create_tween().set_loops()
	float_tween.tween_property(visual_root, "position:y", -4.0, 0.45).set_trans(Tween.TRANS_SINE)
	float_tween.tween_property(visual_root, "position:y", 4.0, 0.45).set_trans(Tween.TRANS_SINE)

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
	
	# Animação de fumacinha/destruição autêntica do sprite sheet
	if item_sprite:
		var puff_tween: Tween = create_tween()
		for f in range(4):
			puff_tween.tween_callback(func():
				if is_instance_valid(item_sprite):
					BomberAssets.configure_powerup_puff(item_sprite, f)
			)
			puff_tween.tween_interval(0.06)
		puff_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.24)
		puff_tween.chain().tween_callback(queue_free)
	else:
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(visual_root, "scale", Vector2.ZERO, 0.2)
		tween.tween_property(self, "modulate", Color(0.2, 0.2, 0.2, 0.0), 0.2)
		tween.chain().tween_callback(queue_free)
