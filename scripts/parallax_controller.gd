class_name ParallaxController
extends Node

## Controlador de Parallax 2.5D por rastreamento do mouse.
## Move sutilmente as camadas de cenário, personagem e partículas
## para conferir profundidade e sensação de produção AAA.

@export var far_layer: CanvasItem
@export var mid_layer: CanvasItem
@export var character_layer: CanvasItem
@export var particles_layer: CanvasItem

@export var enabled: bool = true
@export var smooth_speed: float = 4.0

var current_offset: Vector2 = Vector2.ZERO
var target_offset: Vector2 = Vector2.ZERO

var far_base_pos: Vector2
var mid_base_pos: Vector2
var char_base_pos: Vector2
var particles_base_pos: Vector2

func _ready() -> void:
	# Armazena as posições originais de cada camada
	if far_layer: far_base_pos = far_layer.position
	if mid_layer: mid_base_pos = mid_layer.position
	if character_layer: char_base_pos = character_layer.position
	if particles_layer: particles_base_pos = particles_layer.position

func _process(delta: float) -> void:
	if not enabled:
		return
		
	var vp: Viewport = far_layer.get_viewport() if far_layer else null
	if not vp:
		return
		
	var vp_size: Vector2 = vp.get_visible_rect().size
	if vp_size.x <= 0 or vp_size.y <= 0:
		return
		
	var mouse_pos: Vector2 = vp.get_mouse_position()
	# Normaliza entre -1.0 e 1.0 a partir do centro da tela
	var norm_x: float = clampf((mouse_pos.x / vp_size.x - 0.5) * 2.0, -1.0, 1.0)
	var norm_y: float = clampf((mouse_pos.y / vp_size.y - 0.5) * 2.0, -1.0, 1.0)
	
	target_offset = Vector2(norm_x, norm_y)
	current_offset = current_offset.lerp(target_offset, delta * smooth_speed)
	
	# Aplica deslocamentos com diferentes intensidades de profundidade
	if far_layer:
		far_layer.position = far_base_pos + current_offset * Vector2(7.0, 4.0)
	if mid_layer:
		mid_layer.position = mid_base_pos + current_offset * Vector2(14.0, 8.0)
	if character_layer:
		character_layer.position = char_base_pos + current_offset * Vector2(24.0, 14.0)
	if particles_layer:
		particles_layer.position = particles_base_pos + current_offset * Vector2(36.0, 20.0)
