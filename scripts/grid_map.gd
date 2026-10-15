class_name ArenaGrid
extends Node2D

## Gerenciador da Grade da Arena (15x13 tiles).
## Responsável pela geração procedural de paredes e blocos,
## gerenciamento espacial de bombas, explosões e power-ups.

const CellType = GameState.CellType

const WIDTH: int = 15
const HEIGHT: int = 13
const TILE_SIZE: int = 64
const MAP_NAMES: Array[String] = ArenaMapStyles.NAMES

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

# Estruturas em memória para busca rápida O(1)
var grid_state: Dictionary = {} # Vector2i -> GameState.CellType
var destructible_blocks: Dictionary = {} # Vector2i -> BlockDestructible
var active_bombs: Dictionary = {} # Vector2i -> Bomb
var active_powerups: Dictionary = {} # Vector2i -> PowerUp
## Armazena os power-ups pré-alocados dentro dos blocos (modelo clássico de Super Bomberman 3)
var hidden_powerups: Dictionary = {} # Vector2i -> int
var map_style: int = 0

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var map_generator: ArenaMapGenerator = ArenaMapGenerator.new()
var ambience_node: ArenaAmbience
var hazards_node: ArenaHazards

@onready var floor_node: Node2D = $Floor
@onready var walls_container: Node2D = $WallsContainer
@onready var blocks_container: Node2D = $BlocksContainer
@onready var powerups_container: Node2D = $PowerupsContainer
@onready var bombs_container: Node2D = $BombsContainer
@onready var explosions_container: Node2D = $ExplosionsContainer

func _ready() -> void:
	add_to_group("grid_map")
	rng.randomize()
	floor_node.z_index = -2
	ambience_node = ArenaAmbience.new()
	ambience_node.name = "Ambience"
	add_child(ambience_node)
	hazards_node = ArenaHazards.new()
	hazards_node.name = "Hazards"
	add_child(hazards_node)

## Limpa todos os elementos existentes na arena.
func clear_map() -> void:
	grid_state.clear()
	destructible_blocks.clear()
	active_bombs.clear()
	active_powerups.clear()
	hidden_powerups.clear()
	if hazards_node:
		hazards_node.clear_hazards()
	
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

## Gera o mapa completo com suporte a seed determinística e cesta fixa de itens (SB3).
func generate_map(map_seed: int = -1, map_style_override: int = -1) -> void:
	clear_map()
	var layout: ArenaMapLayout = map_generator.generate(map_seed, map_style_override, block_density)
	map_style = layout.style
	rng.state = layout.rng_state
	floor_node.call("set_theme", map_style)
	if ambience_node:
		ambience_node.set_theme(map_style)
	if hazards_node:
		hazards_node.setup(self, map_style, map_seed)
	for cell in layout.wall_cells:
		_spawn_wall(cell)
	for cell in layout.block_cells:
		_spawn_block(cell)
	
	_distribute_sb3_items(layout.block_cells)

## Distribui a cesta clássica de itens de Super Bomberman 3 nos blocos destruíveis
func _distribute_sb3_items(block_cells: Array[Vector2i]) -> void:
	hidden_powerups.clear()
	if block_cells.is_empty():
		return
	
	var candidates: Array[Vector2i] = block_cells.duplicate()
	_shuffle_array_deterministic(candidates)
	
	var item_bag: Array[int] = []
	var is_campaign: bool = (GameState.game_mode == GameState.GameMode.CAMPAIGN)
	
	if is_campaign:
		# Modo Campanha: 5 a 6 itens por fase (progressão contínua entre fases)
		item_bag.append(GameState.PowerUpType.BOMB)
		item_bag.append(GameState.PowerUpType.BOMB)
		item_bag.append(GameState.PowerUpType.RANGE)
		item_bag.append(GameState.PowerUpType.RANGE)
		item_bag.append(GameState.PowerUpType.SPEED)
		
		# Coração garantido na fase caso não tenha sido gerado anteriormente
		if not GameState.campaign_heart_stages.has(GameState.campaign_stage_index):
			item_bag.append(GameState.PowerUpType.HEART)
		
		# Item tático rotativo baseado no estágio
		var stage_idx: int = GameState.campaign_stage_index
		if CampaignRules.BOSS_STAGES.has(stage_idx):
			item_bag.append(GameState.PowerUpType.BOMB)
			item_bag.append(GameState.PowerUpType.HEART)
		else:
			match stage_idx % 3:
				0: item_bag.append(GameState.PowerUpType.KICK)
				1: item_bag.append(GameState.PowerUpType.PIERCE)
				2: item_bag.append(GameState.PowerUpType.REMOTE)
		if stage_idx % 2 == 1:
			item_bag.append(GameState.PowerUpType.MOUNT_EGG)
			item_bag.append(GameState.PowerUpType.ICE_BOMB if (stage_idx % 4 == 1) else GameState.PowerUpType.THUNDER_BOMB)
	else:
		# Modo Batalha: Cesta clássica equilibrada de Super Bomberman 3 (~18 itens por arena)
		# Proporções: ~30% Bomba, ~22% Fogo, ~12% Patins, especiais raros, 1 Caveira, 1 Ovo, 1 Gelo e 1 Trovão
		for _i in range(5):
			item_bag.append(GameState.PowerUpType.BOMB)
		for _i in range(4):
			item_bag.append(GameState.PowerUpType.RANGE)
		for _i in range(2):
			item_bag.append(GameState.PowerUpType.SPEED)
		
		item_bag.append(GameState.PowerUpType.KICK)
		item_bag.append(GameState.PowerUpType.PIERCE)
		item_bag.append(GameState.PowerUpType.REMOTE)
		item_bag.append(GameState.PowerUpType.SKULL)
		item_bag.append(GameState.PowerUpType.MOUNT_EGG)
		item_bag.append(GameState.PowerUpType.ICE_BOMB)
		item_bag.append(GameState.PowerUpType.THUNDER_BOMB)
	
	# Distribui a cesta nas células sorteadas
	for item_type in item_bag:
		if candidates.is_empty():
			break
		var cell: Vector2i = candidates.pop_back()
		hidden_powerups[cell] = item_type

func _shuffle_array_deterministic(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var temp = arr[i]
		arr[i] = arr[j]
		arr[j] = temp

## Consulta e remove o item oculto da célula (se houver)
func pop_hidden_powerup(cell: Vector2i) -> int:
	if hidden_powerups.has(cell):
		var p_type: int = hidden_powerups[cell]
		hidden_powerups.erase(cell)
		return p_type
	return -1

func get_map_name() -> String:
	return MAP_NAMES[map_style]

func _spawn_wall(cell: Vector2i) -> void:
	var wall: WallIndestructible = WALL_SCENE.instantiate() as WallIndestructible
	wall.position = grid_to_world(cell)
	wall.grid_position = cell
	wall.modulate = _wall_tint()
	walls_container.add_child(wall)
	grid_state[cell] = CellType.WALL_INDESTRUCTIBLE

func _spawn_block(cell: Vector2i) -> void:
	var block: BlockDestructible = BLOCK_SCENE.instantiate() as BlockDestructible
	block.position = grid_to_world(cell)
	block.grid_position = cell
	block.modulate = _block_tint()
	block.destroyed.connect(_on_block_destroyed)
	blocks_container.add_child(block)
	
	grid_state[cell] = CellType.BLOCK_DESTRUCTIBLE
	destructible_blocks[cell] = block

func _wall_tint() -> Color:
	return ArenaMapStyles.wall_tint(map_style)

func _block_tint() -> Color:
	return ArenaMapStyles.block_tint(map_style)

func _on_block_destroyed(cell: Vector2i) -> void:
	grid_state[cell] = CellType.EMPTY
	destructible_blocks.erase(cell)

## Destroi o bloco e tem chance de revelar um Power-up pré-alocado na célula
func destroy_block_at(cell: Vector2i, can_drop_powerup: bool = true) -> bool:
	if destructible_blocks.has(cell):
		var block: Node2D = destructible_blocks[cell]
		grid_state[cell] = CellType.EMPTY
		destructible_blocks.erase(cell)
		if block and is_instance_valid(block) and block.has_method("destroy"):
			block.destroy()
		
		# Revela item da cesta do Super Bomberman 3
		if can_drop_powerup:
			var item_type: int = pop_hidden_powerup(cell)
			if item_type >= 0:
				spawn_powerup(cell, item_type)
		else:
			hidden_powerups.erase(cell)
		
		return true
	return false

# ----------------- GERENCIAMENTO DE POWER-UPS -----------------

## Instancia um power-up na célula especificada
func spawn_powerup(cell: Vector2i, power_type: int) -> PowerUp:
	if not is_in_bounds(cell) or has_powerup_at(cell):
		return null
	
	var p_up: PowerUp = POWERUP_SCENE.instantiate() as PowerUp
	p_up.position = grid_to_world(cell)
	p_up.grid_position = cell
	p_up.type = power_type as GameState.PowerUpType
	p_up.destroyed_by_fire.connect(func(_cell: Vector2i): unregister_powerup(cell))
	
	active_powerups[cell] = p_up
	powerups_container.add_child(p_up)
	return p_up

func has_powerup_at(cell: Vector2i) -> bool:
	return active_powerups.has(cell)

func get_powerup_at(cell: Vector2i) -> PowerUp:
	return active_powerups.get(cell) as PowerUp

func unregister_powerup(cell: Vector2i) -> void:
	active_powerups.erase(cell)

# ----------------- GERENCIAMENTO DE BOMBAS E EXPLOSÕES -----------------

func has_bomb_at(cell: Vector2i) -> bool:
	return active_bombs.has(cell)

func get_bomb_at(cell: Vector2i) -> Bomb:
	return active_bombs.get(cell) as Bomb

func place_bomb(cell: Vector2i, player: CharacterBody2D) -> Bomb:
	if not is_in_bounds(cell) or has_bomb_at(cell):
		return null
	if get_cell_type(cell) != CellType.EMPTY:
		return null
	
	var bomb: Bomb = BOMB_SCENE.instantiate() as Bomb
	bomb.position = grid_to_world(cell)
	bomb.grid_position = cell
	var b_range: int = 2
	if "bomb_range" in player and player.get("bomb_range") != null:
		b_range = int(player.get("bomb_range"))
	bomb.bomb_range = b_range
	bomb.owner_player = player
	bomb.grid_map = self
	
	active_bombs[cell] = bomb
	bombs_container.add_child(bomb)
	return bomb

func unregister_bomb(cell: Vector2i) -> void:
	active_bombs.erase(cell)

func spawn_explosion_segment(cell: Vector2i, segment_type: int = BomberAssets.ExplosionSegment.CENTER) -> Area2D:
	var explosion: Area2D = EXPLOSION_SCENE.instantiate() as Area2D
	explosion.position = grid_to_world(cell)
	var exp_node := explosion as Explosion
	if exp_node:
		exp_node.grid_position = cell
		exp_node.set_segment_type(segment_type)
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

func get_conveyor_drift(world_pos: Vector2) -> Vector2:
	if hazards_node:
		return hazards_node.get_conveyor_drift(world_pos)
	return Vector2.ZERO

func is_cell_conveyor(cell: Vector2i) -> bool:
	if hazards_node:
		return hazards_node.conveyors.has(cell)
	return false

