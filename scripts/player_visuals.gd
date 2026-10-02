class_name PlayerVisuals
extends Node2D

## Renderizador procedural de alta qualidade do personagem estilo Bomberman clássico.
## Desenha o mascote com capacete esférico branco, visor expressivo com olhos animados,
## luvas e botas com ciclo de caminhada, cinto com fivela dourada e antena com bobble brilhante.

@export var player_color: Color = Color(0.25, 0.65, 1.0)
var facing_direction: Vector2 = Vector2.DOWN
var is_moving: bool = false
var walk_time: float = 0.0
var is_alive: bool = true

func _ready() -> void:
	queue_redraw()

func set_skin_color(color: Color) -> void:
	player_color = color
	queue_redraw()

func update_state(direction: Vector2, moving: bool, alive: bool) -> void:
	if direction != Vector2.ZERO:
		# Normaliza para os 4 eixos principais
		if abs(direction.x) > abs(direction.y):
			facing_direction = Vector2(sign(direction.x), 0)
		else:
			facing_direction = Vector2(0, sign(direction.y))
	is_moving = moving
	is_alive = alive

func _process(delta: float) -> void:
	if not is_alive:
		return
	
	if is_moving:
		walk_time += delta * 14.0
	else:
		walk_time += delta * 3.0
	
	queue_redraw()

func _draw() -> void:
	if not is_alive:
		return
	
	var idle_bounce: float = sin(walk_time * 2.0) * 1.2 if not is_moving else 0.0
	var walk_cycle: float = sin(walk_time) if is_moving else 0.0
	var body_tilt: float = sin(walk_time * 0.5) * 0.06 if is_moving else 0.0
	
	# 1. Sombra no chão
	_draw_ellipse(Vector2(0, 16), 16.0, 6.0, Color(0, 0, 0, 0.35))
	
	# 2. Botas / Pés
	_draw_boots(walk_cycle, idle_bounce)
	
	# 3. Corpo / Traje na cor da equipe
	_draw_body(idle_bounce, body_tilt)
	
	# 4. Luvas / Mãos brancas
	_draw_gloves(walk_cycle, idle_bounce)
	
	# 5. Capacete esférico clássico
	_draw_helmet(idle_bounce, body_tilt)
	
	# 6. Rosto / Visor com olhos animados
	_draw_face(idle_bounce, body_tilt)
	
	# 7. Antena no topo da cabeça
	_draw_antenna(idle_bounce, walk_cycle)

func _draw_boots(walk_cycle: float, idle_bounce: float) -> void:
	var boot_main: Color = Color(0.92, 0.25, 0.38)
	var boot_dark: Color = Color(0.65, 0.12, 0.22)
	
	if facing_direction == Vector2.UP:
		var l_pos: Vector2 = Vector2(-8, 12 + (walk_cycle * 3.5 if is_moving else 0.0))
		var r_pos: Vector2 = Vector2(8, 12 - (walk_cycle * 3.5 if is_moving else 0.0))
		_draw_ellipse(l_pos, 5.0, 3.5, boot_dark)
		_draw_ellipse(r_pos, 5.0, 3.5, boot_dark)
	elif facing_direction == Vector2.LEFT:
		var front_pos: Vector2 = Vector2(-7, 14 + (walk_cycle * 4.0 if is_moving else 0.0))
		var back_pos: Vector2 = Vector2(6, 12 - (walk_cycle * 4.0 if is_moving else 0.0))
		_draw_ellipse(back_pos, 5.0, 3.5, boot_dark)
		_draw_ellipse(front_pos, 5.5, 4.0, boot_main)
		_draw_ellipse(front_pos + Vector2(0, 1.5), 5.5, 1.8, boot_dark)
	elif facing_direction == Vector2.RIGHT:
		var front_pos: Vector2 = Vector2(7, 14 + (walk_cycle * 4.0 if is_moving else 0.0))
		var back_pos: Vector2 = Vector2(-6, 12 - (walk_cycle * 4.0 if is_moving else 0.0))
		_draw_ellipse(back_pos, 5.0, 3.5, boot_dark)
		_draw_ellipse(front_pos, 5.5, 4.0, boot_main)
		_draw_ellipse(front_pos + Vector2(0, 1.5), 5.5, 1.8, boot_dark)
	else: # DOWN / FRONT
		var l_pos: Vector2 = Vector2(-8, 14 + (walk_cycle * 3.5 if is_moving else 0.0) + idle_bounce)
		var r_pos: Vector2 = Vector2(8, 14 - (walk_cycle * 3.5 if is_moving else 0.0) + idle_bounce)
		_draw_ellipse(l_pos, 5.5, 4.0, boot_main)
		_draw_ellipse(l_pos + Vector2(0, 1.8), 5.5, 1.8, boot_dark)
		_draw_ellipse(r_pos, 5.5, 4.0, boot_main)
		_draw_ellipse(r_pos + Vector2(0, 1.8), 5.5, 1.8, boot_dark)

func _draw_body(idle_bounce: float, _tilt: float) -> void:
	var body_center: Vector2 = Vector2(0, 4 + idle_bounce)
	
	# Ombreiras e traje com volume
	_draw_ellipse(body_center + Vector2(-8, -3), 5.0, 4.0, player_color.lightened(0.2))
	_draw_ellipse(body_center + Vector2(8, -3), 5.0, 4.0, player_color.lightened(0.2))
	_draw_ellipse(body_center, 12.0, 9.5, player_color)
	# Sombra de profundidade inferior
	_draw_ellipse(body_center + Vector2(0, 2.5), 11.0, 6.5, player_color.darkened(0.28))
	# Painel central do traje e pequenos rebites
	_draw_ellipse(body_center + Vector2(0, -2.0), 5.5, 4.0, player_color.lightened(0.16))
	draw_circle(body_center + Vector2(-7.5, -3.0), 1.0, Color(0.93, 0.97, 1.0, 0.8))
	draw_circle(body_center + Vector2(7.5, -3.0), 1.0, Color(0.93, 0.97, 1.0, 0.8))
	
	# Cinto preto
	draw_line(body_center + Vector2(-10, 2.5), body_center + Vector2(10, 2.5), Color(0.12, 0.14, 0.18), 3.2)
	
	# Fivela dourada (visível na frente e nas laterais)
	if facing_direction != Vector2.UP:
		var buckle_x: float = 0.0
		if facing_direction == Vector2.LEFT:
			buckle_x = -4.0
		elif facing_direction == Vector2.RIGHT:
			buckle_x = 4.0
		
		draw_rect(Rect2(buckle_x - 3.2, body_center.y + 1.0, 6.4, 3.2), Color(1.0, 0.84, 0.15))
		draw_rect(Rect2(buckle_x - 1.5, body_center.y + 1.8, 3.0, 1.6), Color(0.60, 0.45, 0.05))

func _draw_gloves(walk_cycle: float, idle_bounce: float) -> void:
	var glove_col: Color = Color(0.98, 0.98, 1.0)
	var glove_shd: Color = Color(0.80, 0.83, 0.88)
	var cuff_col: Color = player_color.darkened(0.12)
	
	if facing_direction == Vector2.UP:
		var l_hand: Vector2 = Vector2(-14, 2 - (walk_cycle * 3.5 if is_moving else 0.0))
		var r_hand: Vector2 = Vector2(14, 2 + (walk_cycle * 3.5 if is_moving else 0.0))
		draw_circle(l_hand, 5.2, glove_shd)
		draw_circle(l_hand + Vector2(0, -0.6), 4.6, glove_col)
		draw_circle(r_hand, 5.2, glove_shd)
		draw_circle(r_hand + Vector2(0, -0.6), 4.6, glove_col)
		draw_line(l_hand + Vector2(2, 0), l_hand + Vector2(5, 0), cuff_col, 2.0)
		draw_line(r_hand - Vector2(5, 0), r_hand - Vector2(2, 0), cuff_col, 2.0)
	elif facing_direction == Vector2.LEFT:
		var front_hand: Vector2 = Vector2(-12, 4 + (walk_cycle * 4.5 if is_moving else 0.0))
		var back_hand: Vector2 = Vector2(9, 2 - (walk_cycle * 4.5 if is_moving else 0.0))
		draw_circle(back_hand, 4.8, glove_shd)
		draw_circle(front_hand, 5.4, glove_shd)
		draw_circle(front_hand + Vector2(-0.5, -0.5), 4.8, glove_col)
	elif facing_direction == Vector2.RIGHT:
		var front_hand: Vector2 = Vector2(12, 4 + (walk_cycle * 4.5 if is_moving else 0.0))
		var back_hand: Vector2 = Vector2(-9, 2 - (walk_cycle * 4.5 if is_moving else 0.0))
		draw_circle(back_hand, 4.8, glove_shd)
		draw_circle(front_hand, 5.4, glove_shd)
		draw_circle(front_hand + Vector2(0.5, -0.5), 4.8, glove_col)
	else: # DOWN / FRONT
		var l_hand: Vector2 = Vector2(-15, 4 - (walk_cycle * 4.0 if is_moving else 0.0) + idle_bounce)
		var r_hand: Vector2 = Vector2(15, 4 + (walk_cycle * 4.0 if is_moving else 0.0) + idle_bounce)
		draw_circle(l_hand, 5.4, glove_shd)
		draw_circle(l_hand + Vector2(0, -0.8), 4.8, glove_col)
		draw_circle(r_hand, 5.4, glove_shd)
		draw_circle(r_hand + Vector2(0, -0.8), 4.8, glove_col)

func _draw_helmet(idle_bounce: float, _tilt: float) -> void:
	var head_center: Vector2 = Vector2(0, -10 + idle_bounce)
	
	# Sombra na base do capacete
	draw_circle(head_center + Vector2(0, 1.2), 16.5, Color(0.78, 0.82, 0.88))
	# Cúpula principal do capacete
	draw_circle(head_center, 16.0, Color(0.98, 0.99, 1.0))
	
	# Brilho de reflexo specular no topo esquerdo
	_draw_ellipse(head_center + Vector2(-6, -8), 4.5, 2.5, Color(1, 1, 1, 0.75))
	draw_circle(head_center + Vector2(-4, -9), 1.5, Color(1, 1, 1, 0.95))
	# Faixa de identificação da equipe e rebites laterais
	draw_arc(head_center, 14.2, deg_to_rad(218), deg_to_rad(322), 18, player_color, 2.6)
	draw_circle(head_center + Vector2(-13, -1), 1.1, player_color.darkened(0.15))
	draw_circle(head_center + Vector2(13, -1), 1.1, player_color.darkened(0.15))

func _draw_face(idle_bounce: float, _tilt: float) -> void:
	var head_center: Vector2 = Vector2(0, -10 + idle_bounce)
	var face_tone: Color = Color(1.0, 0.88, 0.80)
	var frame_col: Color = Color(0.18, 0.20, 0.25)
	var eye_col: Color = Color(0.08, 0.08, 0.12)
	
	if facing_direction == Vector2.UP:
		# Vista traseira do capacete: costura sutil
		draw_arc(head_center + Vector2(0, 4), 9.0, deg_to_rad(200), deg_to_rad(340), 12, Color(0.82, 0.85, 0.90), 1.6)
		return
	
	if facing_direction == Vector2.LEFT:
		# Moldura e abertura do visor voltado para a esquerda
		_draw_ellipse(head_center + Vector2(-4.2, 1.8), 9.6, 7.2, frame_col)
		_draw_ellipse(head_center + Vector2(-4.2, 1.8), 8.2, 5.8, face_tone)
		
		# Bochecha rosada
		_draw_ellipse(head_center + Vector2(-8.0, 4.2), 1.6, 1.0, Color(1.0, 0.45, 0.50, 0.4))
		
		# Olhos ovais olhando para a esquerda
		_draw_ellipse(head_center + Vector2(-7.8, 1.4), 1.4, 3.8, eye_col)
		_draw_ellipse(head_center + Vector2(-2.5, 1.4), 1.8, 4.2, eye_col)
		
		# Brilho branco nos olhos
		draw_circle(head_center + Vector2(-8.0, -0.4), 0.7, Color.WHITE)
		draw_circle(head_center + Vector2(-2.8, -0.6), 0.9, Color.WHITE)
		
	elif facing_direction == Vector2.RIGHT:
		# Moldura e abertura do visor voltado para a direita
		_draw_ellipse(head_center + Vector2(4.2, 1.8), 9.6, 7.2, frame_col)
		_draw_ellipse(head_center + Vector2(4.2, 1.8), 8.2, 5.8, face_tone)
		
		# Bochecha rosada
		_draw_ellipse(head_center + Vector2(8.0, 4.2), 1.6, 1.0, Color(1.0, 0.45, 0.50, 0.4))
		
		# Olhos ovais olhando para a direita
		_draw_ellipse(head_center + Vector2(2.5, 1.4), 1.8, 4.2, eye_col)
		_draw_ellipse(head_center + Vector2(7.8, 1.4), 1.4, 3.8, eye_col)
		
		# Brilho branco nos olhos
		draw_circle(head_center + Vector2(2.2, -0.6), 0.9, Color.WHITE)
		draw_circle(head_center + Vector2(7.6, -0.4), 0.7, Color.WHITE)
		
	else: # DOWN / FRONT
		# Moldura e abertura frontal
		_draw_ellipse(head_center + Vector2(0, 1.8), 10.6, 7.5, frame_col)
		_draw_ellipse(head_center + Vector2(0, 1.8), 9.2, 6.2, face_tone)
		
		# Bochechas rosadas
		_draw_ellipse(head_center + Vector2(-6.2, 4.5), 1.8, 1.0, Color(1.0, 0.45, 0.50, 0.45))
		_draw_ellipse(head_center + Vector2(6.2, 4.5), 1.8, 1.0, Color(1.0, 0.45, 0.50, 0.45))
		
		# Olhos cartoon verticais expressivos
		_draw_ellipse(head_center + Vector2(-3.8, 1.4), 1.8, 4.2, eye_col)
		_draw_ellipse(head_center + Vector2(3.8, 1.4), 1.8, 4.2, eye_col)
		
		# Brilho nos olhos
		draw_circle(head_center + Vector2(-4.2, -0.6), 0.9, Color.WHITE)
		draw_circle(head_center + Vector2(3.4, -0.6), 0.9, Color.WHITE)

func _draw_antenna(idle_bounce: float, walk_cycle: float) -> void:
	var head_center: Vector2 = Vector2(0, -10 + idle_bounce)
	var base_stem: Vector2 = head_center + Vector2(0, -15)
	var sway: float = (-walk_cycle * 2.2) if is_moving else (sin(walk_time * 2.5) * 0.7)
	var tip: Vector2 = base_stem + Vector2(sway, -8.0)
	
	# Haste metálica
	draw_line(base_stem, tip, Color(0.78, 0.80, 0.85), 2.5)
	
	# Esfera da antena com efeito tridimensional
	var ball_center: Vector2 = tip + Vector2(0, -4.5)
	draw_circle(ball_center, 5.5, player_color.lightened(0.12))
	var antenna_shadow: Color = player_color.darkened(0.35)
	antenna_shadow.a = 0.5
	draw_circle(ball_center + Vector2(0, 1.0), 3.5, antenna_shadow)
	draw_circle(ball_center + Vector2(-1.5, -1.5), 1.6, Color(1, 1, 1, 0.9))

func _draw_ellipse(center: Vector2, rx: float, ry: float, color: Color, num_points: int = 24) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(num_points):
		var angle: float = (i / float(num_points)) * TAU
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	draw_colored_polygon(points, color)
