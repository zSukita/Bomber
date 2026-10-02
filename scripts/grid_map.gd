class_name ArenaGrid
extends Node2D

## Gerenciador da Grade da Arena (15x13 tiles).
## Responsável pela geração procedural de paredes e blocos,
## gerenciamento espacial de bombas, explosões e power-ups.

const CellType = GameState.CellType

const WIDTH: int = 15
const HEIGHT: int = 13
const TILE_SIZE: int = 64
const MAP_NAMES: Array[String] = GameState.MAP_NAMES

# Densidade de blocos destrutíveis nas posições válidas
@export_range(0.0, 1.0) var block_density: float = 0.85

# Chance de gerar um power-up ao destruir um bloco (0.0 a 1.0)
@export_range(0.0, 1.0) var powerup_drop_chance: float = 0.40

# Cenas pré-carregadas
const WALL_SCENE: PackedScene = preload("res://scenes/wall_indestructible.tscn")
const BLOCK_SCENE: PackedScene = preload("res://scenes/block_destructible.tscn")
const BOMB_SCENE: PackedScene = preload("res://scenes/bomb.tscn")
const EXPLOSION_SCENE: PackedScene = preload("res://scenes/explosion.tscn")
const POWERUP_SCENE: PackedScene = preload("res://scenes/power_up.tscn")

# Posições de spawn para até 4 jogadores
const SPAWN_TILES: Array[Vector2i] = [
	Vector2i(1, 1),    # Jogador 1: Superior Esquerdo
	Vector2i(13, 1),   # Jogador 2: Superior Direito
	Vector2i(1, 11),   # Jogador 3: Inferior Esquerdo
	Vector2i(13, 11)   # Jogador 4: Inferior Direito
]

# Células reservadas nos cantos
const RESERVED_TILES: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 1),
	Vector2i(13, 1), Vector2i(13, 2), Vector2i(12, 1),
	Vector2i(1, 11), Vector2i(1, 10), Vector2i(2, 11),
	Vector2i(13, 11), Vector2i(13, 10), Vector2i(12, 11)
]

# Estruturas em memória para busca rápida O(1)
var grid_state: Dictionary = {}
var destructible_blocks: Dictionary = {}
var active_bombs: Dictionary = {}
var active_powerups: Dictionary = {}
var map_style: int = 0

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var floor_node: Node2D = $Floor
@onready var walls_container: Node2D = $WallsContainer
@onready var blocks_container: Node2D = $BlocksContainer
@onready var powerups_container: Node2D = $PowerupsContainer
@onready var bombs_container: Node2D = $BombsContainer
@onready var explosions_container: Node2D = $ExplosionsContainer

func _ready() -> void:
	rng.randomize()

## Limpa todos os elementos existentes na arena.
func clear_map() -> void:
	grid_state.clear()
	destructible_blocks.clear()
	active_bombs.clear()
	active_powerups.clear()
	
	for child in walls_container.get_children():
		child.queue_free()
	for child in blocks_container.get_children():
		child.queue_free()
	for child in powerups_container.get_children():
		child.queue_free()
	for child in bombs_container.get_children():
		child.queue_free()
	for child in explosions_container.get_children():
		child.queue_free()

## Gera o mapa completo com suporte a seed determinística.
func generate_map(map_seed: int = -1, map_style_override: int = -1) -> void:
	clear_map()
	
	if map_seed >= 0:
		rng.seed = map_seed
		map_style = posmod(map_style_override, MAP_NAMES.size()) if map_style_override >= 0 else posmod(map_seed, MAP_NAMES.size())
	else:
		rng.randomize()
		map_style = rng.randi_range(0, MAP_NAMES.size() - 1)
	floor_node.call("set_theme", map_style)
	
	for x in range(WIDTH):
		for y in range(HEIGHT):
			var cell: Vector2i = Vector2i(x, y)
			
			if x == 0 or x == WIDTH - 1 or y == 0 or y == HEIGHT - 1:
				_spawn_wall(cell)
				continue
			
			if x % 2 == 0 and y % 2 == 0:
				_spawn_wall(cell)
				continue
			
			if _is_style_pillar(cell):
				_spawn_wall(cell)
				continue
			
			if cell in RESERVED_TILES:
				grid_state[cell] = CellType.EMPTY
				continue
			
			if _should_spawn_block(cell):
				_spawn_block(cell)
			else:
				grid_state[cell] = CellType.EMPTY

func _is_style_pillar(cell: Vector2i) -> bool:
	match map_style:
		1:
			return cell in [Vector2i(4, 3), Vector2i(10, 3), Vector2i(4, 9), Vector2i(10, 9), Vector2i(7, 6)]
		2:
			return cell in [Vector2i(3, 4), Vector2i(3, 5), Vector2i(11, 7), Vector2i(11, 8)]
		3:
			return cell in [Vector2i(6, 3), Vector2i(8, 3), Vector2i(6, 9), Vector2i(8, 9), Vector2i(7, 4), Vector2i(7, 8)]
		4:
			return cell in [Vector2i(7, 4), Vector2i(7, 8), Vector2i(5, 6), Vector2i(9, 6), Vector2i(6, 5), Vector2i(8, 5), Vector2i(6, 7), Vector2i(8, 7)]
		5:
			return cell in [Vector2i(4, 3), Vector2i(5, 3), Vector2i(9, 3), Vector2i(10, 3), Vector2i(4, 9), Vector2i(5, 9), Vector2i(9, 9), Vector2i(10, 9)]
		6:
			return cell in [Vector2i(4, 3), Vector2i(10, 3), Vector2i(4, 9), Vector2i(10, 9), Vector2i(6, 4), Vector2i(8, 4), Vector2i(6, 8), Vector2i(8, 8)]
		7:
			return cell in [Vector2i(3, 4), Vector2i(4, 4), Vector2i(10, 8), Vector2i(11, 8), Vector2i(10, 4), Vector2i(11, 4), Vector2i(3, 8), Vector2i(4, 8)]
		8:
			return cell in [Vector2i(5, 3), Vector2i(9, 3), Vector2i(5, 9), Vector2i(9, 9), Vector2i(7, 4), Vector2i(7, 8), Vector2i(4, 6), Vector2i(10, 6)]
		9:
			return cell in [Vector2i(7, 3), Vector2i(7, 9), Vector2i(5, 6), Vector2i(9, 6), Vector2i(6, 5), Vector2i(8, 5), Vector2i(6, 7), Vector2i(8, 7), Vector2i(4, 6), Vector2i(10, 6)]
	return false

func _should_spawn_block(cell: Vector2i) -> bool:
	var roll: float = rng.randf()
	match map_style:
		0: # Prado equilibrado
			return roll <= block_density * 0.78
		1: # Vulcão: corredores irregulares e áreas de rocha
			return roll <= block_density * 0.66 and (cell.x + cell.y) % 3 != 0
		2: # Geleira: arena mais aberta e rápida
			return roll <= block_density * 0.48
		3: # Dunas: faixas de cobertura alternadas
			return roll <= block_density * 0.72 and (cell.x * 2 + cell.y) % 5 != 0
		4: # Fortaleza: muita cobertura junto à cidadela
			return roll <= block_density * 0.82
		5: # Corredores: trilhas abertas cruzando a arena
			return roll <= block_density * 0.76 and cell.x % 4 != 1 and cell.y % 4 != 1
		6: # Ilhas: quatro zonas compactas e caminhos centrais
			return roll <= block_density * 0.84 and (cell.x < 6 or cell.x > 8 or cell.y < 5 or cell.y > 7)
		7: # Cristal: campo simétrico e mais aberto
			return roll <= block_density * 0.55
		8: # Ruínas: blocos em bolsões alternados
			return roll <= block_density * 0.8 and (cell.x + cell.y) % 4 != 0
		9: # Chamas: bordas densas e centro livre
			return roll <= block_density * 0.86 and (cell.x < 5 or cell.x > 9 or cell.y < 4 or cell.y > 8)
	return false

func get_map_name() -> String:
	return MAP_NAMES[map_style]

func _spawn_wall(cell: Vector2i) -> void:
	var wall: Node2D = WALL_SCENE.instantiate() as Node2D
	wall.position = grid_to_world(cell)
	wall.set("grid_position", cell)
	wall.modulate = _wall_tint()
	walls_container.add_child(wall)
	grid_state[cell] = CellType.WALL_INDESTRUCTIBLE

func _spawn_block(cell: Vector2i) -> void:
	var block: Node2D = BLOCK_SCENE.instantiate() as Node2D
	block.position = grid_to_world(cell)
	block.set("grid_position", cell)
	block.modulate = _block_tint()
	if block.has_signal("destroyed"):
		block.connect("destroyed", _on_block_destroyed)
	blocks_container.add_child(block)
	
	grid_state[cell] = CellType.BLOCK_DESTRUCTIBLE
	destructible_blocks[cell] = block

func _wall_tint() -> Color:
	match map_style:
		1: return Color(1.0, 0.66, 0.58)
		2: return Color(0.72, 0.94, 1.0)
		3: return Color(1.0, 0.83, 0.61)
		4: return Color(0.88, 0.83, 0.72)
		5: return Color(0.72, 0.9, 0.96)
		6: return Color(0.77, 0.93, 0.8)
		7: return Color(0.84, 0.84, 1.0)
		8: return Color(0.95, 0.82, 0.67)
		9: return Color(1.0, 0.72, 0.62)
	return Color.WHITE

func _block_tint() -> Color:
	match map_style:
		1: return Color(1.0, 0.7, 0.52)
		2: return Color(0.78, 0.95, 1.0)
		3: return Color(1.0, 0.88, 0.62)
		4: return Color(0.88, 0.77, 0.58)
		5: return Color(0.62, 0.85, 0.94)
		6: return Color(0.69, 0.92, 0.75)
		7: return Color(0.82, 0.75, 1.0)
		8: return Color(0.91, 0.75, 0.57)
		9: return Color(1.0, 0.62, 0.44)
	return Color.WHITE

func _on_block_destroyed(cell: Vector2i) -> void:
	grid_state[cell] = CellType.EMPTY
	destructible_blocks.erase(cell)

## Destroi o bloco e tem chance de sortear um Power-up na célula
func destroy_block_at(cell: Vector2i, can_drop_powerup: bool = true) -> bool:
	if destructible_blocks.has(cell):
		var block: Node2D = destructible_blocks[cell]
		grid_state[cell] = CellType.EMPTY
		destructible_blocks.erase(cell)
		if block and is_instance_valid(block) and block.has_method("destroy"):
			block.destroy()
		
		# Sorteia Power-up se aplicável
		if can_drop_powerup and rng.randf() <= powerup_drop_chance:
			var random_type: int = [GameState.PowerUpType.BOMB, GameState.PowerUpType.RANGE, GameState.PowerUpType.SPEED].pick_random()
			spawn_powerup(cell, random_type)
		
		return true
	return false

# ----------------- GERENCIAMENTO DE POWER-UPS -----------------

## Instancia um power-up na célula especificada
func spawn_powerup(cell: Vector2i, power_type: int) -> Area2D:
	if not is_in_bounds(cell) or has_powerup_at(cell):
		return null
	
	var p_up: Area2D = POWERUP_SCENE.instantiate() as Area2D
	p_up.position = grid_to_world(cell)
	p_up.set("grid_position", cell)
	p_up.set("type", power_type)
	
	if p_up.has_signal("destroyed_by_fire"):
		p_up.connect("destroyed_by_fire", func(_cell: Vector2i): unregister_powerup(cell))
	
	active_powerups[cell] = p_up
	powerups_container.add_child(p_up)
	return p_up

func has_powerup_at(cell: Vector2i) -> bool:
	return active_powerups.has(cell)

func get_powerup_at(cell: Vector2i) -> Area2D:
	return active_powerups.get(cell, null)

func unregister_powerup(cell: Vector2i) -> void:
	active_powerups.erase(cell)

# ----------------- GERENCIAMENTO DE BOMBAS E EXPLOSÕES -----------------

func has_bomb_at(cell: Vector2i) -> bool:
	return active_bombs.has(cell)

func get_bomb_at(cell: Vector2i) -> StaticBody2D:
	return active_bombs.get(cell, null)

func place_bomb(cell: Vector2i, player: CharacterBody2D) -> StaticBody2D:
	if not is_in_bounds(cell) or has_bomb_at(cell):
		return null
	if get_cell_type(cell) != CellType.EMPTY:
		return null
	
	var bomb: StaticBody2D = BOMB_SCENE.instantiate() as StaticBody2D
	bomb.position = grid_to_world(cell)
	bomb.set("grid_position", cell)
	bomb.set("bomb_range", player.get("bomb_range"))
	bomb.set("owner_player", player)
	
	active_bombs[cell] = bomb
	bombs_container.add_child(bomb)
	return bomb

func unregister_bomb(cell: Vector2i) -> void:
	active_bombs.erase(cell)

func spawn_explosion_segment(cell: Vector2i) -> Area2D:
	var explosion: Area2D = EXPLOSION_SCENE.instantiate() as Area2D
	explosion.position = grid_to_world(cell)
	explosion.set("grid_position", cell)
	explosions_container.add_child(explosion)
	return explosion

# ----------------- UTILITÁRIOS DE COORDENADAS -----------------

func grid_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		cell.x * TILE_SIZE + (TILE_SIZE / 2.0),
		cell.y * TILE_SIZE + (TILE_SIZE / 2.0)
	)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / TILE_SIZE)),
		int(floor(world_pos.y / TILE_SIZE))
	)

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < WIDTH and cell.y >= 0 and cell.y < HEIGHT

func get_cell_type(cell: Vector2i) -> GameState.CellType:
	if not is_in_bounds(cell):
		return CellType.WALL_INDESTRUCTIBLE
	return grid_state.get(cell, CellType.EMPTY)

func is_walkable(cell: Vector2i) -> bool:
	if not is_in_bounds(cell):
		return false
	return get_cell_type(cell) == CellType.EMPTY and not has_bomb_at(cell)

func get_spawn_world_pos(player_index: int) -> Vector2:
	var index_clamped: int = clampi(player_index, 0, SPAWN_TILES.size() - 1)
	return grid_to_world(SPAWN_TILES[index_clamped])
