class_name FloorRenderer
extends Node2D

## Renderiza o piso xadrez da arena em 15x13 tiles de 64x64 pixels.

const WIDTH: int = 15
const HEIGHT: int = 13
const TILE_SIZE: int = 64

const FLOOR_PALETTES: Array[Array] = [
	[Color("4c9a55"), Color("438b4c"), Color("9bd17e")],
	[Color("493b4a"), Color("392e3e"), Color("ee8051")],
	[Color("5798ad"), Color("47869e"), Color("b9ecf5")],
	[Color("bd8c52"), Color("a97946"), Color("f0c477")],
	[Color("555d6f"), Color("414858"), Color("e4bb70")],
	[Color("426d78"), Color("365a68"), Color("85c6cf")],
	[Color("4c8a7e"), Color("3e766d"), Color("c9d893")],
	[Color("6578a1"), Color("53658b"), Color("c4b8f0")],
	[Color("9a785f"), Color("80634f"), Color("d6b58a")],
	[Color("824d4c"), Color("683b40"), Color("f29a55")]
]

var theme_index: int = 0

func set_theme(index: int) -> void:
	theme_index = posmod(index, FLOOR_PALETTES.size())
	queue_redraw()

func _draw() -> void:
	var palette: Array = FLOOR_PALETTES[theme_index]
	var light: Color = palette[0]
	var dark: Color = palette[1]
	var accent: Color = palette[2]
	for x in range(WIDTH):
		for y in range(HEIGHT):
			var rect: Rect2 = Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			var color: Color = light if (x + y) % 2 == 0 else dark
			draw_rect(rect, color, true)
			# Borda interna e reflexos discretos dão volume sem poluir o tabuleiro.
			draw_rect(rect.grow(-2.0), _color_with_alpha(accent.darkened(0.35), 0.22), false, 1.0)
			draw_line(rect.position + Vector2(5, 4), rect.position + Vector2(TILE_SIZE - 6, 4), _color_with_alpha(Color.WHITE, 0.08), 1.0)
			draw_line(rect.position + Vector2(4, 5), rect.position + Vector2(4, TILE_SIZE - 6), _color_with_alpha(Color.WHITE, 0.06), 1.0)
			draw_line(rect.position + Vector2(6, TILE_SIZE - 4), rect.position + Vector2(TILE_SIZE - 5, TILE_SIZE - 4), _color_with_alpha(Color.BLACK, 0.10), 1.0)
			_draw_theme_detail(x, y, rect, accent)

func _draw_theme_detail(x: int, y: int, rect: Rect2, accent: Color) -> void:
	var seed_value: int = x * 17 + y * 31 + theme_index * 13
	match theme_index:
		0: # Prado: pequenos tufos nas bordas do piso.
			if seed_value % 5 == 0:
				var p: Vector2 = rect.position + Vector2(12 + seed_value % 24, 45)
				draw_line(p, p + Vector2(-3, -5), _color_with_alpha(accent, 0.55), 1.5)
				draw_line(p, p + Vector2(2, -7), _color_with_alpha(accent, 0.55), 1.5)
		1: # Vulcão: fissuras quentes no basalto.
			if seed_value % 7 == 0:
				var p: Vector2 = rect.position + Vector2(18, 19)
				draw_line(p, p + Vector2(8, 7), _color_with_alpha(accent, 0.34), 2.0)
				draw_line(p + Vector2(8, 7), p + Vector2(15, 4), _color_with_alpha(accent, 0.28), 1.5)
		2: # Geleira: reflexos frios em losango.
			if seed_value % 4 == 0:
				var c: Vector2 = rect.position + Vector2(47, 16)
				draw_line(c + Vector2(-4, 0), c, _color_with_alpha(accent, 0.32), 1.5)
				draw_line(c, c + Vector2(0, 6), _color_with_alpha(accent, 0.32), 1.5)
		3: # Dunas: trilhas suaves de areia.
			if seed_value % 6 == 0:
				var p: Vector2 = rect.position + Vector2(12, 48)
				draw_arc(p, 12.0, deg_to_rad(205), deg_to_rad(330), 12, _color_with_alpha(accent, 0.28), 1.5)
		4: # Fortaleza: pequenas marcas de metal nas pedras.
			if seed_value % 8 == 0:
				var p: Vector2 = rect.position + Vector2(48, 48)
				draw_circle(p, 2.0, _color_with_alpha(accent, 0.35))
		5: # Corredores: linhas de sinalização azul.
			if seed_value % 7 == 0:
				var p: Vector2 = rect.position + Vector2(12, 32)
				draw_line(p, p + Vector2(18, 0), _color_with_alpha(accent, 0.32), 2.0)
		6: # Ilhas: ondas de água rasas.
			if seed_value % 6 == 0:
				var p: Vector2 = rect.position + Vector2(24, 34)
				draw_arc(p, 10.0, deg_to_rad(195), deg_to_rad(335), 12, _color_with_alpha(accent, 0.3), 1.5)
		7: # Cristal: pequenos reflexos em losango.
			if seed_value % 5 == 0:
				var p: Vector2 = rect.position + Vector2(42, 22)
				draw_line(p + Vector2(-4, 0), p, _color_with_alpha(accent, 0.4), 1.5)
				draw_line(p, p + Vector2(0, 6), _color_with_alpha(accent, 0.4), 1.5)
		8: # Ruínas: riscos gastos na pedra antiga.
			if seed_value % 7 == 0:
				var p: Vector2 = rect.position + Vector2(18, 20)
				draw_line(p, p + Vector2(6, 7), _color_with_alpha(accent, 0.3), 1.5)
		9: # Chamas: fissuras de lava.
			if seed_value % 8 == 0:
				var p: Vector2 = rect.position + Vector2(36, 20)
				draw_line(p, p + Vector2(-4, 7), _color_with_alpha(accent, 0.38), 2.0)
				draw_line(p + Vector2(-4, 7), p + Vector2(3, 13), _color_with_alpha(accent, 0.3), 1.5)

func _color_with_alpha(color: Color, alpha: float) -> Color:
	var result: Color = color
	result.a = alpha
	return result
