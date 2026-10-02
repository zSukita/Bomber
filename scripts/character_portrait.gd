class_name CharacterPortrait
extends Control

@export var player_color: Color = Color(0.25, 0.65, 1.0)

func _draw() -> void:
	var center_x: float = size.x * 0.5
	var center_y: float = size.y * 0.56
	var scale_factor: float = minf(size.x / 48.0, size.y / 48.0)
	var color: Color = player_color
	# Sombra e botas
	draw_set_transform(Vector2(center_x, center_y), 0.0, Vector2.ONE * scale_factor)
	_draw_portrait_ellipse(Vector2(0, 18), Vector2(14, 4), Color(0.015, 0.025, 0.04, 0.65))
	draw_circle(Vector2(-6, 12), 4.0, Color(0.82, 0.24, 0.32))
	draw_circle(Vector2(6, 12), 4.0, Color(0.82, 0.24, 0.32))
	# Macacão com volume e emblema
	draw_circle(Vector2(0, 4), 12.0, color.darkened(0.3))
	draw_circle(Vector2(0, 2), 11.0, color)
	draw_circle(Vector2(-3, -2), 3.0, color.lightened(0.28))
	draw_circle(Vector2(0, 4), 3.0, Color(1.0, 0.84, 0.28))
	draw_circle(Vector2(0, 4), 1.35, Color(0.12, 0.17, 0.25))
	# Capacete, faixa de equipe, visor e antena
	draw_circle(Vector2(0, -10), 15.0, Color(0.69, 0.76, 0.85))
	draw_circle(Vector2(0, -11), 14.0, Color(0.96, 0.98, 1.0))
	draw_arc(Vector2(0, -11), 12.0, deg_to_rad(205), deg_to_rad(335), 18, color, 3.0)
	draw_circle(Vector2(0, -9), 8.5, Color(0.12, 0.17, 0.25))
	draw_circle(Vector2(-3.2, -9), 1.3, Color.WHITE)
	draw_circle(Vector2(3.2, -9), 1.3, Color.WHITE)
	draw_line(Vector2(0, -25), Vector2(1, -30), Color(0.78, 0.84, 0.92), 2.0)
	draw_circle(Vector2(1, -32), 3.2, color.lightened(0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_portrait_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(24):
		var angle: float = TAU * float(i) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
