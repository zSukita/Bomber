class_name CampaignEnemySpawner
extends RefCounted

## Responsável por escolher posições alcançáveis e instanciar os inimigos da fase.
const ENEMY_SCENE: PackedScene = preload("res://scenes/campaign_enemy.tscn")
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

func spawn(grid: ArenaGrid, container: Node2D, player: Player, stage_index: int, defeated_callback: Callable) -> Array[CampaignEnemy]:
	var spawned: Array[CampaignEnemy] = []
	var possible_cells: Array[Vector2i] = []
	var player_cell: Vector2i = grid.world_to_grid(player.global_position)
	var came_from: Dictionary = _build_reachable_paths(grid, player_cell)
	for x in range(1, ArenaGrid.WIDTH - 1):
		for y in range(1, ArenaGrid.HEIGHT - 1):
			var cell := Vector2i(x, y)
			var distance_from_player: int = absi(x - player_cell.x) + absi(y - player_cell.y)
			if grid.get_cell_type(cell) == GameState.CellType.EMPTY and distance_from_player >= 5 and came_from.has(cell):
				possible_cells.append(cell)

	var enemy_count: int = CampaignRules.ENEMIES_PER_STAGE[stage_index]
	if possible_cells.size() < enemy_count:
		for x in range(1, ArenaGrid.WIDTH - 1):
			for y in range(1, ArenaGrid.HEIGHT - 1):
				var cell := Vector2i(x, y)
				var distance_from_player: int = absi(x - player_cell.x) + absi(y - player_cell.y)
				if grid.get_cell_type(cell) == GameState.CellType.EMPTY and distance_from_player >= 4 and not possible_cells.has(cell) and came_from.has(cell):
					possible_cells.append(cell)

	for i in range(enemy_count):
		if possible_cells.is_empty():
			break
		var best_score: int = -1
		var best_cells: Array[Vector2i] = []
		for candidate in possible_cells:
			var nearest_distance: int = absi(candidate.x - player_cell.x) + absi(candidate.y - player_cell.y)
			for existing_enemy in spawned:
				var existing_cell: Vector2i = grid.world_to_grid(existing_enemy.global_position)
				nearest_distance = mini(nearest_distance, absi(candidate.x - existing_cell.x) + absi(candidate.y - existing_cell.y))
			if nearest_distance > best_score:
				best_score = nearest_distance
				best_cells.clear()
				best_cells.append(candidate)
			elif nearest_distance == best_score:
				best_cells.append(candidate)

		var cell: Vector2i = best_cells.pick_random()
		possible_cells.erase(cell)
		for route_cell in _reconstruct_route(came_from, player_cell, cell):
			if grid.get_cell_type(route_cell) == GameState.CellType.BLOCK_DESTRUCTIBLE:
				grid.destroy_block_at(route_cell, false)

		var archetype: int = CampaignEnemy.Archetype.WANDERER
		var boss_stage: bool = stage_index in CampaignRules.BOSS_STAGES
		if boss_stage and i == 0:
			archetype = CampaignEnemy.Archetype.BOSS
		elif stage_index >= 2 and i == enemy_count - 1:
			archetype = CampaignEnemy.Archetype.CHARGER
		elif stage_index >= 1 and i % 2 == 1:
			archetype = CampaignEnemy.Archetype.HUNTER

		var enemy: CampaignEnemy = ENEMY_SCENE.instantiate() as CampaignEnemy
		enemy.setup(player, stage_index, grid, archetype)
		enemy.defeated.connect(defeated_callback)
		enemy.global_position = grid.grid_to_world(cell)
		container.add_child(enemy)
		spawned.append(enemy)
	return spawned

func _build_reachable_paths(grid: ArenaGrid, start_cell: Vector2i) -> Dictionary:
	var pending: Array[Vector2i] = [start_cell]
	var came_from: Dictionary = {start_cell: start_cell}
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_front()
		for step in DIRECTIONS:
			var next_cell: Vector2i = cell + step
			if came_from.has(next_cell) or not grid.is_in_bounds(next_cell):
				continue
			if grid.get_cell_type(next_cell) == GameState.CellType.WALL_INDESTRUCTIBLE:
				continue
			came_from[next_cell] = cell
			pending.append(next_cell)
	return came_from

func _reconstruct_route(came_from: Dictionary, start_cell: Vector2i, goal_cell: Vector2i) -> Array[Vector2i]:
	var route: Array[Vector2i] = []
	if not came_from.has(goal_cell):
		return route
	var cursor: Vector2i = goal_cell
	while cursor != start_cell:
		route.append(cursor)
		cursor = came_from[cursor]
	route.reverse()
	return route
