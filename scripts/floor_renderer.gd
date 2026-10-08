class_name FloorRenderer
extends Node2D

## Piso de arena em mosaico com cores e pequenos detalhes de pixel art.
const WIDTH: int = 15
const HEIGHT: int = 13
const TILE_SIZE: int = 64

const FLOOR_PALETTES: Array[Array] = [
	[Color("83c76b"), Color("72b85e"), Color("b3dc7b")],
	[Color("554b52"), Color("443b47"), Color("e5824e")],
	[Color("80c6c8"), Color("63aeb7"), Color("d5f0d1")],
	[Color("d2a85e"), Color("bc914d"), Color("f2d17e")],
	[Color("74808b"), Color("626c79"), Color("d5d5bd")],
	[Color("528e91"), Color("427879"), Color("a1cda7")],
	[Color("77ad72"), Color("649965"), Color("d0d58a")],
	[Color("718ab2"), Color("5b7197"), Color("c8d9f2")],
	[Color("a98b69"), Color("927455"), Color("d7c092")],
	[Color("98594d"), Color("79413f"), Color("f0a359")]
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
			# Contorno escuro e friso claro de 4 px: leitura nítida no zoom do jogo.
			draw_rect(Rect2(p, Vector2(TILE_SIZE, TILE_SIZE)), shade.darkened(0.08), false, 4.0)
			draw_rect(Rect2(p + Vector2(4, 4), Vector2(56, 56)), highlight.darkened(0.24), false, 2.0)
			_draw_grain(p, tile_seed, shade, highlight)

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
