class_name ArenaMapStyles
extends RefCounted

## Catálogo central de nomes, padrões e cores dos mapas da arena.
enum BlockPattern { FULL, SUM_MOD_3, XY_MOD_5, CORRIDORS, OUTER_ZONES, SUM_MOD_4, EDGES, RING, CHECKER, CROSS, RAILS, ISLANDS, HORIZONTAL }

const NAMES: Array[String] = [
	"Arena Clássica", "Carrossel de Fogo", "Costa Tropical", "Labirinto Oculto",
	"Tundra Congelada", "Usina Eletrizante", "Ruínas do Deserto", "Vulcão Ardente",
	"Girocrusader", "Pântano Tóxico", "Templo Estelar", "Coliseu Bombástico"
]

const PREVIEWS: Array[String] = [
	"res://assets/legal/previews/stage_01.png",
	"res://assets/legal/previews/stage_02.png",
	"res://assets/legal/previews/stage_03.png",
	"res://assets/legal/previews/stage_04.png",
	"res://assets/legal/previews/stage_05.png",
	"res://assets/legal/previews/stage_06.png",
	"res://assets/legal/previews/stage_07.png",
	"res://assets/legal/previews/stage_08.png",
	"res://assets/legal/previews/stage_09.png",
	"res://assets/legal/previews/stage_10.png",
	"res://assets/legal/previews/stage_11.png",
	"res://assets/legal/previews/stage_12.png"
]

const PILLARS: Array[Array] = [
	[],
	[Vector2i(6, 4), Vector2i(8, 4), Vector2i(6, 8), Vector2i(8, 8)],
	[Vector2i(3, 5), Vector2i(4, 5), Vector2i(10, 7), Vector2i(11, 7), Vector2i(7, 3), Vector2i(7, 9)],
	[Vector2i(4, 3), Vector2i(10, 3), Vector2i(4, 9), Vector2i(10, 9), Vector2i(7, 6)],
	[Vector2i(5, 4), Vector2i(9, 4), Vector2i(5, 8), Vector2i(9, 8)],
	[Vector2i(4, 6), Vector2i(10, 6), Vector2i(7, 4), Vector2i(7, 8)],
	[Vector2i(3, 3), Vector2i(11, 3), Vector2i(3, 9), Vector2i(11, 9)],
	[Vector2i(5, 3), Vector2i(9, 3), Vector2i(5, 9), Vector2i(9, 9), Vector2i(5, 6), Vector2i(9, 6)],
	[Vector2i(4, 4), Vector2i(10, 4), Vector2i(4, 8), Vector2i(10, 8)],
	[Vector2i(4, 3), Vector2i(10, 3), Vector2i(4, 9), Vector2i(10, 9), Vector2i(7, 4), Vector2i(7, 8)],
	[],
	[]
]

const BLOCK_DENSITY_SCALE: Array[float] = [0.96, 0.86, 0.78, 0.9, 0.8, 0.78, 0.8, 0.88, 0.78, 0.82, 0.96, 0.9]
const BLOCK_PATTERN: Array[int] = [BlockPattern.FULL, BlockPattern.RING, BlockPattern.HORIZONTAL, BlockPattern.CHECKER, BlockPattern.CORRIDORS, BlockPattern.CROSS, BlockPattern.OUTER_ZONES, BlockPattern.RAILS, BlockPattern.SUM_MOD_4, BlockPattern.ISLANDS, BlockPattern.FULL, BlockPattern.CHECKER]

const WALL_TINTS: Array[Color] = [
	Color.WHITE, Color(1.0, 0.66, 0.58), Color(0.72, 0.94, 1.0), Color(1.0, 0.83, 0.61),
	Color(0.88, 0.83, 0.72), Color(0.72, 0.9, 0.96), Color(0.77, 0.93, 0.8), Color(0.84, 0.84, 1.0),
	Color(0.95, 0.82, 0.67), Color(1.0, 0.72, 0.62), Color(0.84, 0.84, 1.0), Color(0.72, 0.94, 1.0)
]
const BLOCK_TINTS: Array[Color] = [
	Color.WHITE, Color(1.0, 0.7, 0.52), Color(0.78, 0.95, 1.0), Color(1.0, 0.88, 0.62),
	Color(0.88, 0.77, 0.58), Color(0.62, 0.85, 0.94), Color(0.69, 0.92, 0.75), Color(0.82, 0.75, 1.0),
	Color(0.91, 0.75, 0.57), Color(1.0, 0.62, 0.44), Color(1.0, 0.86, 0.42), Color(0.72, 0.9, 1.0)
]

static func is_pillar(cell: Vector2i, map_style: int) -> bool:
	return cell in PILLARS[clampi(map_style, 0, PILLARS.size() - 1)]

static func wall_tint(map_style: int) -> Color:
	return WALL_TINTS[clampi(map_style, 0, WALL_TINTS.size() - 1)]

static func block_tint(map_style: int) -> Color:
	return BLOCK_TINTS[clampi(map_style, 0, BLOCK_TINTS.size() - 1)]

static func should_spawn_block(cell: Vector2i, map_style: int, block_density: float, roll: float) -> bool:
	var style: int = clampi(map_style, 0, NAMES.size() - 1)
	if roll > block_density * BLOCK_DENSITY_SCALE[style]:
		return false
	match BLOCK_PATTERN[style]:
		BlockPattern.SUM_MOD_3:
			return (cell.x + cell.y) % 3 != 0
		BlockPattern.XY_MOD_5:
			return (cell.x * 2 + cell.y) % 5 != 0
		BlockPattern.CORRIDORS:
			return cell.x % 4 != 1 and cell.y % 4 != 1
		BlockPattern.OUTER_ZONES:
			return cell.x < 6 or cell.x > 8 or cell.y < 5 or cell.y > 7
		BlockPattern.SUM_MOD_4:
			return (cell.x + cell.y) % 4 != 0
		BlockPattern.EDGES:
			return cell.x < 5 or cell.x > 9 or cell.y < 4 or cell.y > 8
		BlockPattern.RING:
			var ring_radius: int = maxi(absi(cell.x - 7), absi(cell.y - 6))
			return ring_radius == 2 or ring_radius == 4
		BlockPattern.CHECKER:
			return (cell.x + cell.y) % 2 == 0
		BlockPattern.CROSS:
			return cell.x % 4 != 1 and cell.y % 4 != 1
		BlockPattern.RAILS:
			return cell.x % 4 != 2 and cell.y % 4 != 2
		BlockPattern.ISLANDS:
			return (cell.x < 5 or cell.x > 9) and (cell.y < 4 or cell.y > 8) or (cell.x in range(5, 10) and cell.y in range(4, 9) and (cell.x + cell.y) % 3 == 0)
		BlockPattern.HORIZONTAL:
			return cell.y % 4 != 0
	return true
