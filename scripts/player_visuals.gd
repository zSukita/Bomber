class_name PlayerVisuals
extends Node2D

## Visual autêntico dos personagens de Super Bomberman 3 com controle de animação, direção e equipe.
@export var player_color: Color = Color(0.25, 0.65, 1.0)
var facing_direction: Vector2 = Vector2.DOWN
var is_moving: bool = false
var walk_time: float = 0.0
var is_alive: bool = true
var character_index: int = 0
var character_sprite: Sprite2D
var sprite_frame: int = -1
var sprite_row: int = -1
var sprite_flip: bool = false

func _ready() -> void:
	character_sprite = Sprite2D.new()
	character_sprite.name = "CharacterSprite"
	character_sprite.z_index = 0
	add_child(character_sprite)
	set_character(character_index)
	queue_redraw()

func set_skin_color(color: Color) -> void:
	player_color = color
	queue_redraw()

func set_character(index: int) -> void:
	character_index = posmod(index, BomberAssets.CHARACTER_TEXTURES.size())
	if character_sprite:
		BomberAssets.configure_character_sprite(character_sprite, character_index, 0, _direction_row(), facing_direction == Vector2.LEFT)
		sprite_frame = 0
		sprite_row = _direction_row()
		sprite_flip = facing_direction == Vector2.LEFT

func update_state(direction: Vector2, moving: bool, alive: bool) -> void:
	if direction != Vector2.ZERO:
		if abs(direction.x) > abs(direction.y):
			facing_direction = Vector2(sign(direction.x), 0)
		else:
			facing_direction = Vector2(0, sign(direction.y))
	is_moving = moving
	is_alive = alive
	if character_sprite and alive:
		character_sprite.visible = true

func _process(delta: float) -> void:
	if not is_alive:
		return
	walk_time += delta * (12.0 if is_moving else 3.0)
	if character_sprite:
		var next_frame: int = int(walk_time / 0.14) % 4 if is_moving else 0
		var next_row: int = _direction_row()
		var next_flip: bool = facing_direction == Vector2.LEFT
		if next_frame != sprite_frame or next_row != sprite_row or next_flip != sprite_flip:
			BomberAssets.configure_character_sprite(character_sprite, character_index, next_frame, next_row, next_flip)
			sprite_frame = next_frame
			sprite_row = next_row
			sprite_flip = next_flip
	queue_redraw()

func _direction_row() -> int:
	if facing_direction == Vector2.UP:
		return 1
	if facing_direction == Vector2.LEFT or facing_direction == Vector2.RIGHT:
		return 2
	return 0

func _draw() -> void:
	# Sombra suave sob os pés
	_draw_ellipse(Vector2(0, 10), Vector2(14, 5), Color(0.02, 0.03, 0.06, 0.45))
	# Indicador circular de equipe / cor do jogador
	draw_arc(Vector2(0, 10), 19.0, 0.0, TAU, 24, Color(player_color.r, player_color.g, player_color.b, 0.85), 2.5)

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(16):
		var angle: float = TAU * float(i) / 16.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
