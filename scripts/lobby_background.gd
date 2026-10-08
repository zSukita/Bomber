class_name LobbyBackground
extends Control

## Fundo dinâmico com atmosfera arcade para o menu principal do Bombástico.
## Inclui gradiente de vinheta suave, grade sutil de ladrilhos e partículas de brasas/faíscas.

class Spark:
	var pos: Vector2
	var speed: float
	var size: float
	var alpha: float
	var sway: float
	var hue_shift: float

var sparks: Array[Spark] = []
const MAX_SPARKS: int = 32
var time_accum: float = 0.0

func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_init_sparks()

func _init_sparks() -> void:
	sparks.clear()
	for i in range(MAX_SPARKS):
		var s := Spark.new()
		_reset_spark(s, true)
		sparks.append(s)

func _reset_spark(s: Spark, random_y: bool = false) -> void:
	var w: float = maxf(size.x, 960.0)
	var h: float = maxf(size.y, 832.0)
	s.pos = Vector2(randf_range(0.0, w), randf_range(0.0, h) if random_y else h + 20.0)
	s.speed = randf_range(25.0, 55.0)
	s.size = randf_range(2.0, 4.0)
	s.alpha = randf_range(0.2, 0.65)
	s.sway = randf_range(1.0, 3.0)
	s.hue_shift = randf()

func _process(delta: float) -> void:
	time_accum += delta
	var w: float = maxf(size.x, 960.0)
	for s in sparks:
		s.pos.y -= s.speed * delta
		s.pos.x += sin(time_accum * s.sway + s.hue_shift * TAU) * 12.0 * delta
		if s.pos.y < -20.0:
			_reset_spark(s, false)
			s.pos.x = randf_range(0.0, w)
	queue_redraw()

func _draw() -> void:
	var rect_area: Rect2 = get_rect()
	
	# 1. Fundo base em degradê escuro obsidiana / navy
	draw_rect(rect_area, Color("080c14"))
	
	# 2. Brilho central radial estilizado
	var center := rect_area.get_center()
	var radius := maxf(rect_area.size.x, rect_area.size.y) * 0.65
	draw_circle(center, radius, Color(0.12, 0.18, 0.28, 0.35))
	draw_circle(center, radius * 0.55, Color(0.16, 0.26, 0.42, 0.25))

	# 3. Grade geométrica sutil no fundo (remete à arena de combate)
	var grid_col := Color(0.2, 0.32, 0.48, 0.06)
	var step := 64.0
	var offset_y := fposmod(time_accum * 8.0, step)
	var start_x := 0.0
	while start_x <= rect_area.size.x:
		draw_line(Vector2(start_x, 0.0), Vector2(start_x, rect_area.size.y), grid_col, 1.0)
		start_x += step
	var start_y := offset_y
	while start_y <= rect_area.size.y:
		draw_line(Vector2(0.0, start_y), Vector2(rect_area.size.x, start_y), grid_col, 1.0)
		start_y += step

	# 4. Brasas e faíscas incandescentes
	for s in sparks:
		var col: Color = Color("ffaa3b") if s.hue_shift > 0.4 else Color("ff6438")
		col.a = s.alpha
		draw_rect(Rect2(s.pos.x, s.pos.y, s.size, s.size), col)
