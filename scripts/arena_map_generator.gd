class_name ArenaMapGenerator
extends RefCounted

## Produz o layout lógico da arena sem instanciar ou desenhar nós.
const WIDTH: int = 15
const HEIGHT: int = 13
const MAP_NAMES: Array[String] = GameState.MAP_NAMES

const RESERVED_TILES: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 1),
	Vector2i(13, 1), Vector2i(13, 2), Vector2i(12, 1),
	Vector2i(1, 11), Vector2i(1, 10), Vector2i(2, 11),
	Vector2i(13, 11), Vector2i(13, 10), Vector2i(12, 11)
]

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Retorna somente os dados do mapa; ArenaGrid instancia os elementos visuais.
func generate(map_seed: int, map_style_override: int, block_density: float) -> ArenaMapLayout:
	var map_style: int
	if map_seed >= 0:
		rng.seed = map_seed
		map_style = posmod(map_style_override, MAP_NAMES.size()) if map_style_override >= 0 else posmod(map_seed, MAP_NAMES.size())
	else:
		rng.randomize()
		map_style = rng.randi_range(0, MAP_NAMES.size() - 1)

	var layout: ArenaMapLayout = ArenaMapLayout.new()
	layout.style = map_style
	for x in range(WIDTH):
		for y in range(HEIGHT):
			var cell := Vector2i(x, y)
			if x == 0 or x == WIDTH - 1 or y == 0 or y == HEIGHT - 1:
				layout.wall_cells.append(cell)
				continue
			if x % 2 == 0 and y % 2 == 0 or _is_style_pillar(cell, map_style):
				layout.wall_cells.append(cell)
				continue
			if cell in RESERVED_TILES:
				continue
			if _should_spawn_block(cell, map_style, block_density):
				layout.block_cells.append(cell)
	layout.rng_state = rng.state
	return layout

func _is_style_pillar(cell: Vector2i, map_style: int) -> bool:
	return ArenaMapStyles.is_pillar(cell, map_style)

func _should_spawn_block(cell: Vector2i, map_style: int, block_density: float) -> bool:
	return ArenaMapStyles.should_spawn_block(cell, map_style, block_density, rng.randf())
