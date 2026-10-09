class_name FloorRenderer
extends Node2D

## Piso de arena em mosaico com cores e pequenos detalhes de pixel art.
const WIDTH: int = 15
const HEIGHT: int = 13
const TILE_SIZE: int = 64

const FLOOR_PALETTES: Array[Array] = [
	[Color("777d81"), Color("555a5e"), Color("bec3c6")],
	[Color("b07b50"), Color("805641"), Color("f5c26f")],
	[Color("54b9d5"), Color("2485a5"), Color("b9e7e8")],
	[Color("9eaab0"), Color("69777f"), Color("e1d7bf")],
	[Color("a2d9ed"), Color("5ca9cc"), Color("effcff")],
	[Color("252b7f"), Color("171c56"), Color("7387f0")],
	[Color("c99824"), Color("8f6816"), Color("f1d45a")],
	[Color("8a7724"), Color("5b511b"), Color("dcc455")],
	[Color("79bfed"), Color("418dca"), Color("d9f3ff")],
	[Color("318ea0"), Color("196772"), Color("87cf79")],
	[Color("939ba8"), Color("566073"), Color("f4d94f")],
	[Color("78a9ed"), Color("477dca"), Color("fff063")]
]

var theme_index: int = 0

func _ready() -> void:
	GameState.enhanced_mode_toggled.connect(func(_is_enhanced: bool) -> void:
		queue_redraw()
	)

func set_theme(index: int) -> void:
	theme_index = posmod(index, FLOOR_PALETTES.size())
	queue_redraw()

func _draw() -> void:
	var palette: Array = FLOOR_PALETTES[theme_index]
	var base: Color = palette[0]
	var shade: Color = palette[1]
	var highlight: Color = palette[2]
	var is_enhanced: bool = GameState.is_enhanced()

	for x in range(WIDTH):
		for y in range(HEIGHT):
			var p := Vector2(x * TILE_SIZE, y * TILE_SIZE)
			var tile_seed := x * 41 + y * 67 + theme_index * 29
			# Variação sutil entre células, sem tabuleiro xadrez.
			var tile_color: Color = base.lightened(0.035) if tile_seed % 3 == 0 else base

			if is_enhanced:
				# Suave vinheta perimetral nas bordas da arena para sensação de profundidade
				var dist_from_edge: float = minf(minf(x, WIDTH - 1 - x), minf(y, HEIGHT - 1 - y))
				if dist_from_edge == 0:
					tile_color = tile_color.darkened(0.08)
				elif dist_from_edge == 1:
					tile_color = tile_color.darkened(0.03)

				# Detalhes térmicos em mapas de fogo ou micro-reflexos em gelo/cristal
				if theme_index in [1, 9] and tile_seed % 7 == 0: # Vulcânico / Chamas
					tile_color = tile_color.lerp(Color("ff6438"), 0.12)
				elif theme_index in [2, 7] and tile_seed % 5 == 0: # Gelo / Cristal
					tile_color = tile_color.lerp(Color("e8fcff"), 0.15)

			draw_rect(Rect2(p, Vector2(TILE_SIZE, TILE_SIZE)), tile_color)
			draw_rect(Rect2(p, Vector2(TILE_SIZE, TILE_SIZE)), Color(shade, 0.12), false, 1.0)
			_draw_grain(p, tile_seed, shade, highlight)
			_draw_stage_pattern(p, tile_seed, shade, highlight)

func _draw_stage_pattern(position: Vector2, seed_value: int, shade: Color, highlight: Color) -> void:
	var center: Vector2 = position + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)
	match theme_index:
		0:
			if seed_value % 3 == 0:
				draw_line(position + Vector2(12, 16), position + Vector2(26, 16), highlight.darkened(0.2), 2.0)
				draw_circle(position + Vector2(48, 46), 2.0, shade.lightened(0.12))
		1:
			if seed_value % 3 == 0:
				draw_arc(center, 18.0, 0.0, TAU, 16, highlight.darkened(0.22), 3.0)
				draw_circle(center, 5.0, shade.lightened(0.2))
		2:
			for wave in range(3):
				var wave_y: float = float(18 + wave * 14 + posmod(seed_value + wave * 7, 5))
				draw_line(position + Vector2(8, wave_y), position + Vector2(56, wave_y - 3), highlight.darkened(0.2), 3.0)
		3:
			draw_rect(Rect2(position + Vector2(10, 13), Vector2(44, 14)), shade.darkened(0.12))
			draw_rect(Rect2(position + Vector2(14, 17), Vector2(36, 6)), highlight.darkened(0.3))
			draw_circle(position + Vector2(13, 47), 3.0, highlight)
			draw_circle(position + Vector2(51, 47), 3.0, highlight)
		4:
			for streak in range(3):
				var streak_x: float = float(12 + streak * 16 + posmod(seed_value, 6))
				draw_line(position + Vector2(streak_x, 12), position + Vector2(streak_x - 5, 52), highlight.darkened(0.12), 2.0)
		5:
			var arrow_y: float = center.y + float(posmod(seed_value, 3) - 1) * 5.0
			draw_line(center + Vector2(-19, arrow_y - center.y), center + Vector2(15, arrow_y - center.y), highlight, 4.0)
			draw_line(center + Vector2(5, arrow_y - center.y - 9), center + Vector2(16, arrow_y - center.y), highlight, 4.0)
			draw_line(center + Vector2(5, arrow_y - center.y + 9), center + Vector2(16, arrow_y - center.y), highlight, 4.0)
		6:
			if seed_value % 3 == 0:
				draw_arc(center, float(10 + posmod(seed_value, 8)), 0.4, 5.3, 18, highlight.darkened(0.22), 3.0)
				draw_circle(center, 3.0, shade.lightened(0.15))
		7:
			draw_line(position + Vector2(12, 8), position + Vector2(12, 56), shade.darkened(0.3), 3.0)
			draw_line(position + Vector2(28, 8), position + Vector2(28, 56), shade.darkened(0.3), 3.0)
			draw_line(position + Vector2(44, 8), position + Vector2(44, 56), shade.darkened(0.3), 3.0)
			for sleeper in range(3):
				draw_rect(Rect2(position + Vector2(8 + sleeper * 16, 20), Vector2(40, 4)), highlight.darkened(0.18))
		8:
			if seed_value % 2 == 0:
				draw_line(center + Vector2(-20, 8), center + Vector2(20, -8), highlight.darkened(0.12), 5.0)
				draw_circle(center + Vector2(0, 13), 6.0, shade.darkened(0.2))
			else:
				draw_arc(center, 17.0, 0.0, PI, 16, highlight.darkened(0.18), 3.0)
		9:
			if seed_value % 3 == 0:
				draw_colored_polygon(_ellipse_points(center, Vector2(15, 9)), highlight.darkened(0.28))
				draw_circle(center, 3.0, shade.lightened(0.2))
		10:
			var star_color: Color = Color("fff0a1") if seed_value % 2 == 0 else highlight
			draw_colored_polygon(_star_points(center, 14.0, 6.0), star_color)
		11:
			var balloon_color: Color = Color("ffd95a") if seed_value % 2 == 0 else Color("fff0a1")
			draw_circle(center + Vector2(0, -3), 10.0, balloon_color)
			draw_line(center + Vector2(0, 7), center + Vector2(2, 20), highlight.darkened(0.2), 2.0)

func _star_points(center: Vector2, outer_radius: float, inner_radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point_index in range(10):
		var angle: float = -PI * 0.5 + float(point_index) * PI / 5.0
		var radius: float = outer_radius if point_index % 2 == 0 else inner_radius
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _ellipse_points(center: Vector2, radii: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point_index in range(20):
		var angle: float = TAU * float(point_index) / 20.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points

func _draw_grain(p: Vector2, seed_value: int, shade: Color, highlight: Color) -> void:
	# Padrões curtos em blocos, como a textura pontilhada dos cenários de 16 bits.
	var x1 := 8 + posmod(seed_value * 7, 40)
	var y1 := 8 + posmod(seed_value * 11, 40)
	var detail_color := shade.darkened(0.06) if seed_value % 2 == 0 else highlight.darkened(0.16)
	draw_rect(Rect2(p + Vector2(x1, y1), Vector2(8, 4)), detail_color)
	if seed_value % 3 == 0:
		draw_rect(Rect2(p + Vector2(x1 + 8, y1 + 4), Vector2(4, 4)), detail_color)
	if seed_value % 5 == 0:
		var x2 := 8 + posmod(seed_value * 13, 40)
		var y2 := 8 + posmod(seed_value * 17, 40)
		draw_rect(Rect2(p + Vector2(x2, y2), Vector2(4, 4)), highlight.darkened(0.12))
