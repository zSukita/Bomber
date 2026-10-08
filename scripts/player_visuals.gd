class_name PlayerVisuals
extends Node2D

## Bomber pixelado, desenhado em blocos de 4 px para combinar com a escala da arena.
@export var player_color: Color = Color(0.25, 0.65, 1.0)
var facing_direction: Vector2 = Vector2.DOWN
var is_moving: bool = false
var walk_time: float = 0.0
var is_alive: bool = true

const PIXEL := 4.0
const OUTLINE := Color("25233b")
const HELMET := Color("f8f4e8")
const HELMET_SHADE := Color("c8d1d7")
const SKIN := Color("ffd4a1")

func _ready() -> void:
	queue_redraw()

func set_skin_color(color: Color) -> void:
	player_color = color
	queue_redraw()

func update_state(direction: Vector2, moving: bool, alive: bool) -> void:
	if direction != Vector2.ZERO:
		if abs(direction.x) > abs(direction.y):
			facing_direction = Vector2(sign(direction.x), 0)
		else:
			facing_direction = Vector2(0, sign(direction.y))
	is_moving = moving
	is_alive = alive

func _process(delta: float) -> void:
	if not is_alive:
		return
	walk_time += delta * (12.0 if is_moving else 3.0)
	queue_redraw()

func _draw() -> void:
	if not is_alive:
		return

	var is_enhanced: bool = GameState.is_enhanced() and GameState.character_squash_stretch
	if is_enhanced and is_moving:
		var squash_factor := sin(walk_time * 2.0) * 0.05
		draw_set_transform(Vector2(0, 12), 0.0, Vector2(1.0 - squash_factor, 1.0 + squash_factor))
		draw_set_transform(Vector2(0, 0), 0.0, Vector2(1.0 - squash_factor, 1.0 + squash_factor))

	var step := int(round(sin(walk_time))) * PIXEL if is_moving else 0.0
	var bob := -PIXEL if is_moving and abs(sin(walk_time)) > 0.65 else 0.0
	# Sombra em pixels sob o personagem.
	_px(-12, 12, 24, 4, Color(0.04, 0.06, 0.1, 0.38))
	# Botas vermelhas, alternando a passada.
	_px(-12, 8 + step, 8, 8, OUTLINE)
	_px(4, 8 - step, 8, 8, OUTLINE)
	_px(-8, 8 + step, 8, 4, Color("e33e37"))
	_px(4, 8 - step, 8, 4, Color("e33e37"))
	# Corpo e braços: silhueta contornada e traje na cor do jogador.
	_px(-12, -8 + bob, 24, 20, OUTLINE)
	_px(-16, -4 + bob, 8, 12, OUTLINE)
	_px(8, -4 + bob, 8, 12, OUTLINE)
	_px(-8, -8 + bob, 16, 16, player_color.darkened(0.2))
	_px(-8, -8 + bob, 16, 12, player_color)
	_px(-16, -4 + bob, 8, 8, HELMET)
	_px(8, -4 + bob, 8, 8, HELMET)
	# Capacete branco em degraus, com visor frontal/lateral conforme direção.
	_px(-12, -28 + bob, 24, 8, OUTLINE)
	_px(-16, -24 + bob, 32, 16, OUTLINE)
	_px(-12, -32 + bob, 24, 8, OUTLINE)
	_px(-8, -28 + bob, 16, 4, HELMET)
	_px(-12, -24 + bob, 24, 12, HELMET)
	_px(-12, -12 + bob, 24, 4, HELMET_SHADE)
	_px(-8, -28 + bob, 8, 4, Color.WHITE)
	# Visor de pele e olhos; vistas traseira e laterais são legíveis em jogo.
	if facing_direction == Vector2.UP:
		_px(-4, -20 + bob, 8, 4, HELMET_SHADE)
	else:
		var visor_x := -8.0 if facing_direction == Vector2.LEFT else (0.0 if facing_direction == Vector2.RIGHT else -8.0)
		_px(visor_x - 4, -20 + bob, 16, 8, OUTLINE)
		_px(visor_x, -20 + bob, 12, 4, SKIN)
		_px(visor_x, -16 + bob, 12, 4, Color("f3bb88"))
		if facing_direction == Vector2.DOWN:
			_px(-4, -20 + bob, 4, 8, Color("211f35"))
			_px(4, -20 + bob, 4, 8, Color("211f35"))
			_px(-4, -20 + bob, 4, 4, Color.WHITE)
			_px(4, -20 + bob, 4, 4, Color.WHITE)
		else:
			_px(visor_x + 4, -20 + bob, 4, 8, Color("211f35"))
			_px(visor_x + 4, -20 + bob, 4, 4, Color.WHITE)
	# Antenna with tiny jewel.
	var sway := int(round(sin(walk_time * 0.7))) * PIXEL if is_moving else 0.0
	_px(-2 + sway, -36 + bob, 4, 8, OUTLINE)
	_px(-2 + sway, -40 + bob, 4, 4, Color("ffc83d"))
	_px(-2 + sway, -40 + bob, 4, 2, Color("fff1a1"))

	if is_enhanced:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _px(x: float, y: float, width: float, height: float, color: Color) -> void:
	draw_rect(Rect2(x, y, width, height), color)

