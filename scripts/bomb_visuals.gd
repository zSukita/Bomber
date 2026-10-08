class_name BombVisuals
extends Node2D

## Bomba redonda em pixel art com pavio e brilho animados.
var spark_timer: float = 0.0

func _ready() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	spark_timer += delta * 15.0
	queue_redraw()

func _draw() -> void:
	var pulse := int(round(sin(spark_timer) * 2.0))
	# Sombra e pavio.
	draw_rect(Rect2(-16, 15, 32, 4), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(-4, -24, 8, 8), Color("d1a64b"))
	draw_rect(Rect2(-4, -28, 8, 4), Color("f1d17a"))
	draw_rect(Rect2(-4, -36, 4, 8), Color("e8d6aa"))
	draw_rect(Rect2(0, -40, 4, 4), Color("fff0ad"))
	draw_rect(Rect2(4, -36, 4, 4), Color("ff9b36"))
	draw_rect(Rect2(-4, -32, 4, 4), Color("ff9b36"))
	# Silhueta escalonada da esfera.
	_px(-8, -24, 16, 4, Color("171727"))
	_px(-16, -20, 32, 4, Color("171727"))
	_px(-20, -16, 40, 24, Color("171727"))
	_px(-16, 8, 32, 8, Color("171727"))
	_px(-8, 16, 16, 4, Color("171727"))
	# Corpo de metal escuro, com reflexos em blocos.
	_px(-8, -20, 16, 4, Color("38394a"))
	_px(-16, -16, 32, 4, Color("38394a"))
	_px(-16, -12, 32, 16, Color("292a3a"))
	_px(-12, 4, 24, 8, Color("202131"))
	_px(-8, -16, 8, 4, Color("85899b"))
	_px(-12, -12, 4, 4, Color("686d82"))
	# Reflexo pisca com o pavio.
	_px(12, -16, 4, 4, Color("585b70"))
	_px(-8, -8, 4, 4, Color("414356"))
	_px(-4, -36 - pulse, 4, 4, Color("fff9d1"))

	# No Modo Melhorado, halo sutil de calor e micro faíscas do pavio
	if GameState.is_enhanced():
		var glow_alpha: float = sin(spark_timer * 1.5) * 0.15 + 0.25
		draw_circle(Vector2(0, -36), 14.0, Color(1.0, 0.65, 0.15, glow_alpha))
		# Faíscas que saltam do pavio
		var spark_off_x: float = sin(spark_timer * 2.3) * 6.0
		var spark_off_y: float = -42.0 - absf(cos(spark_timer * 1.8)) * 8.0
		_px(spark_off_x, spark_off_y, 2, 2, Color("fff7bd"))

func _px(x: float, y: float, width: float, height: float, color: Color) -> void:
	draw_rect(Rect2(x, y, width, height), color)

