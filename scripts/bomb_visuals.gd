class_name BombVisuals
extends Node2D

## Renderizador procedural de alta qualidade para as bombas de Bombástico.
## Esfera metálica brilhante, gargalo dourado, pavio curvado e faíscas animadas.

var spark_timer: float = 0.0

func _ready() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	spark_timer += delta * 18.0
	queue_redraw()

func _draw() -> void:
	# 1. Sombra circular suave no chão
	_draw_ellipse(Vector2(0, 16), 18.0, 6.0, Color(0, 0, 0, 0.4))
	
	# 2. Corpo esférico metálico da bomba
	var bomb_center: Vector2 = Vector2(0, 0)
	
	# Borda escura de contorno
	draw_circle(bomb_center, 21.0, Color(0.06, 0.06, 0.08))
	# Corpo principal escuro
	draw_circle(bomb_center, 20.0, Color(0.14, 0.15, 0.18))
	
	# Brilho de profundidade/curvatura (lado superior esquerdo)
	_draw_ellipse(bomb_center + Vector2(-5, -5), 9.0, 6.0, Color(0.28, 0.30, 0.36, 0.7))
	# Ponto especular brilhante
	draw_circle(bomb_center + Vector2(-7, -7), 3.2, Color(0.9, 0.92, 0.98, 0.85))
	draw_circle(bomb_center + Vector2(-8, -8), 1.4, Color(1.0, 1.0, 1.0, 0.95))
	
	# 3. Gargalo de metal dourado
	draw_rect(Rect2(-6, -24, 12, 5), Color(0.72, 0.58, 0.25))
	draw_rect(Rect2(-5, -23, 10, 2), Color(0.95, 0.80, 0.40))
	draw_rect(Rect2(-6, -20, 12, 2), Color(0.45, 0.35, 0.15))
	
	# 4. Pavio curvado
	var fuse_points: PackedVector2Array = PackedVector2Array([
		Vector2(0, -24),
		Vector2(2, -28),
		Vector2(-1, -33),
		Vector2(3, -37)
	])
	draw_polyline(fuse_points, Color(0.80, 0.62, 0.38), 2.5)
	
	# 5. Faísca crepitante no topo do pavio
	var spark_origin: Vector2 = Vector2(3, -37)
	var spark_pulse: float = sin(spark_timer) * 0.5 + 0.5
	var outer_radius: float = 4.5 + spark_pulse * 2.0
	
	# Halo laranja brilhante
	draw_circle(spark_origin, outer_radius, Color(1.0, 0.45, 0.1, 0.6))
	# Núcleo amarelo
	draw_circle(spark_origin, 3.0, Color(1.0, 0.85, 0.2))
	# Ponto central incandescente
	draw_circle(spark_origin, 1.4, Color.WHITE)
	
	# Faíscas pontuais animadas
	var spark_count: int = 4
	for i in range(spark_count):
		var angle: float = (spark_timer * 1.5) + (i * TAU / spark_count)
		var dist: float = 5.0 + (sin(spark_timer * 3.0 + i) * 2.5)
		var p: Vector2 = spark_origin + Vector2(cos(angle) * dist, sin(angle) * dist)
		draw_circle(p, 1.2, Color(1.0, 0.75, 0.1, 0.85))

func _draw_ellipse(center: Vector2, rx: float, ry: float, color: Color, num_points: int = 24) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(num_points):
		var angle: float = (i / float(num_points)) * TAU
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	draw_colored_polygon(points, color)
