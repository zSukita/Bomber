class_name ArenaMapStyles
extends RefCounted

## Catálogo central de nomes, padrões e cores dos mapas da arena.
enum BlockPattern { FULL, SUM_MOD_3, XY_MOD_5, CORRIDORS, OUTER_ZONES, SUM_MOD_4, EDGES }

const NAMES: Array[String] = [
	"Prado Brilhante", "Cratera Vulcânica", "Geleira Azul", "Dunas do Crepúsculo",
	"Fortaleza Central", "Corredores Cruzados", "Ilhas Gêmeas", "Labirinto de Cristal",
	"Ruínas Antigas", "Pátio das Chamas"
]

const PILLARS: Array[Array] = [
	[],
	[Vector2i(4, 3), Vector2i(10, 3), Vector2i(4, 9), Vector2i(10, 9), Vector2i(7, 6)],
	[Vector2i(3, 4), Vector2i(3, 5), Vector2i(11, 7), Vector2i(11, 8)],
	[Vector2i(6, 3), Vector2i(8, 3), Vector2i(6, 9), Vector2i(8, 9), Vector2i(7, 4), Vector2i(7, 8)],
	[Vector2i(7, 4), Vector2i(7, 8), Vector2i(5, 6), Vector2i(9, 6), Vector2i(6, 5), Vector2i(8, 5), Vector2i(6, 7), Vector2i(8, 7)],
	[Vector2i(4, 3), Vector2i(5, 3), Vector2i(9, 3), Vector2i(10, 3), Vector2i(4, 9), Vector2i(5, 9), Vector2i(9, 9), Vector2i(10, 9)],
	[Vector2i(4, 3), Vector2i(10, 3), Vector2i(4, 9), Vector2i(10, 9), Vector2i(6, 4), Vector2i(8, 4), Vector2i(6, 8), Vector2i(8, 8)],
	[Vector2i(3, 4), Vector2i(4, 4), Vector2i(10, 8), Vector2i(11, 8), Vector2i(10, 4), Vector2i(11, 4), Vector2i(3, 8), Vector2i(4, 8)],
	[Vector2i(5, 3), Vector2i(9, 3), Vector2i(5, 9), Vector2i(9, 9), Vector2i(7, 4), Vector2i(7, 8), Vector2i(4, 6), Vector2i(10, 6)],
	[Vector2i(7, 3), Vector2i(7, 9), Vector2i(5, 6), Vector2i(9, 6), Vector2i(6, 5), Vector2i(8, 5), Vector2i(6, 7), Vector2i(8, 7), Vector2i(4, 6), Vector2i(10, 6)]
]

const BLOCK_DENSITY_SCALE: Array[float] = [0.78, 0.66, 0.48, 0.72, 0.82, 0.76, 0.84, 0.55, 0.8, 0.86]
const BLOCK_PATTERN: Array[int] = [BlockPattern.FULL, BlockPattern.SUM_MOD_3, BlockPattern.FULL, BlockPattern.XY_MOD_5, BlockPattern.FULL, BlockPattern.CORRIDORS, BlockPattern.OUTER_ZONES, BlockPattern.FULL, BlockPattern.SUM_MOD_4, BlockPattern.EDGES]

const WALL_TINTS: Array[Color] = [
	Color.WHITE, Color(1.0, 0.66, 0.58), Color(0.72, 0.94, 1.0), Color(1.0, 0.83, 0.61),
	Color(0.88, 0.83, 0.72), Color(0.72, 0.9, 0.96), Color(0.77, 0.93, 0.8), Color(0.84, 0.84, 1.0),
	Color(0.95, 0.82, 0.67), Color(1.0, 0.72, 0.62)
]
const BLOCK_TINTS: Array[Color] = [
	Color.WHITE, Color(1.0, 0.7, 0.52), Color(0.78, 0.95, 1.0), Color(1.0, 0.88, 0.62),
	Color(0.88, 0.77, 0.58), Color(0.62, 0.85, 0.94), Color(0.69, 0.92, 0.75), Color(0.82, 0.75, 1.0),
	Color(0.91, 0.75, 0.57), Color(1.0, 0.62, 0.44)
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
	return true
