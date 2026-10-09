class_name BombSystem
extends Node

## Regras de colocação, propagação e coleta relacionadas às bombas.
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var game: Game

func configure(owner_game: Game) -> void:
	game = owner_game

func drop_bomb(player: Player) -> void:
	if not game.is_round_active or not player.is_alive or player.active_bombs >= player.max_bombs:
		return
	var cell: Vector2i = game.grid_map.world_to_grid(player.global_position)
	if not game.grid_map.is_in_bounds(cell) or game.grid_map.has_bomb_at(cell) or game.grid_map.get_cell_type(cell) != GameState.CellType.EMPTY:
		return
	var bomb: Bomb = game.grid_map.place_bomb(cell, player)
	if bomb == null:
		return
	player.active_bombs += 1
	bomb.exploded.connect(resolve_explosion)
	AudioManager.play_bomb_drop()
	if multiplayer.has_multiplayer_peer():
		game.sync_spawn_bomb.rpc(cell, player.peer_id, player.bomb_range)
	game._refresh_player_hud(player.peer_id)

func spawn_bomb_replica(cell: Vector2i, owner_peer_id: int, bomb_range: int) -> void:
	var player: Player = game.spawned_players.get(owner_peer_id, null)
	if player == null:
		return
	var bomb: Bomb = game.grid_map.place_bomb(cell, player)
	if bomb == null:
		return
	bomb.bomb_range = bomb_range
	player.active_bombs += 1
	game._refresh_player_hud(owner_peer_id)
	AudioManager.play_bomb_drop()

func resolve_explosion(bomb: Bomb, center_cell: Vector2i, flame_range: int) -> void:
	if not is_instance_valid(bomb):
		return
	var owner_player: Player = bomb.owner_player
	if is_instance_valid(owner_player):
		owner_player.on_bomb_exploded()
		game._refresh_player_hud(owner_player.peer_id)
	game.grid_map.unregister_bomb(center_cell)

	var flame_cells: Array[Vector2i] = []
	var destroyed_blocks: Array[Vector2i] = []
	var dropped_powerups: Array[Dictionary] = []
	var burned_powerups: Array[Vector2i] = []
	var hit_players: Array[int] = []
	_check_players_in_cell(center_cell, hit_players)

	for direction in DIRECTIONS:
		for step in range(1, flame_range + 1):
			var target_cell: Vector2i = center_cell + direction * step
			if not game.grid_map.is_in_bounds(target_cell):
				break
			var cell_type: GameState.CellType = game.grid_map.get_cell_type(target_cell)
			if cell_type == GameState.CellType.WALL_INDESTRUCTIBLE:
				break
			if cell_type == GameState.CellType.BLOCK_DESTRUCTIBLE:
				destroyed_blocks.append(target_cell)
				game.grid_map.destroy_block_at(target_cell, false)
				var powerup_type: int = game._roll_powerup_drop_type()
				if powerup_type >= 0:
					dropped_powerups.append({"cell": target_cell, "type": powerup_type})
					game.grid_map.spawn_powerup(target_cell, powerup_type)
				break
			if cell_type == GameState.CellType.EMPTY:
				flame_cells.append(target_cell)
				if game.grid_map.has_powerup_at(target_cell):
					burned_powerups.append(target_cell)
					var powerup: PowerUp = game.grid_map.get_powerup_at(target_cell)
					if powerup:
						powerup.destroy_by_fire()
				_check_players_in_cell(target_cell, hit_players)
				var chained_bomb: Bomb = game.grid_map.get_bomb_at(target_cell)
				if is_instance_valid(chained_bomb):
					chained_bomb.detonate()

	_spawn_explosion_rays(center_cell, flame_cells)
	AudioManager.play_explosion()
	if not destroyed_blocks.is_empty() and GameState.is_enhanced():
		AudioManager.play_block_break()
	game.add_screen_shake(0.35)
	for peer_id in hit_players:
		if game.spawned_players.has(peer_id):
			game.spawned_players[peer_id].die()
	if multiplayer.has_multiplayer_peer():
		game.sync_explosion.rpc(
			center_cell,
			flame_cells,
			destroyed_blocks,
			dropped_powerups,
			burned_powerups,
			owner_player.peer_id if is_instance_valid(owner_player) else 0
		)
	game._refresh_all_hud_cards()

func apply_explosion_replica(center: Vector2i, flame_cells: Array, destroyed_blocks: Array, dropped_powerups: Array, burned_powerups: Array, owner_peer_id: int) -> void:
	var replica_bomb: Bomb = game.grid_map.get_bomb_at(center)
	game.grid_map.unregister_bomb(center)
	if is_instance_valid(replica_bomb):
		replica_bomb.remove_replica()
	var owner_player: Player = game.spawned_players.get(owner_peer_id, null)
	if owner_player:
		owner_player.on_bomb_exploded()
		game._refresh_player_hud(owner_peer_id)
	_spawn_explosion_rays(center, flame_cells)
	for block_cell in destroyed_blocks:
		game.grid_map.destroy_block_at(block_cell, false)
	for powerup_info in dropped_powerups:
		var cell: Vector2i = powerup_info["cell"]
		var powerup_type: int = int(powerup_info["type"])
		game.grid_map.spawn_powerup(cell, powerup_type)
	for burn_cell in burned_powerups:
		var powerup: PowerUp = game.grid_map.get_powerup_at(burn_cell)
		if powerup:
			powerup.destroy_by_fire()
	AudioManager.play_explosion()
	if not destroyed_blocks.is_empty() and GameState.is_enhanced():
		AudioManager.play_block_break()
	game.add_screen_shake(0.35)
	game._refresh_all_hud_cards()

func check_powerup_pickups() -> void:
	for peer_id in game.alive_players:
		var player: Player = game.spawned_players.get(peer_id, null)
		if player == null or not player.is_alive:
			continue
		var cell: Vector2i = game.grid_map.world_to_grid(player.global_position)
		var powerup: PowerUp = game.grid_map.get_powerup_at(cell)
		if powerup == null or powerup.is_collected:
			continue
		var powerup_type: int = powerup.type
		powerup.is_collected = true
		powerup.collision_shape.set_deferred("disabled", true)
		player.apply_power_up(powerup_type)
		game.grid_map.unregister_powerup(cell)
		powerup.queue_free()
		AudioManager.play_powerup()
		if multiplayer.has_multiplayer_peer():
			game.sync_powerup_collected.rpc(cell, peer_id, powerup_type)
		game._refresh_player_hud(peer_id)

func apply_powerup_collected(cell: Vector2i, collector_id: int, powerup_type: int) -> void:
	var powerup: PowerUp = game.grid_map.get_powerup_at(cell)
	if powerup:
		game.grid_map.unregister_powerup(cell)
		powerup.is_collected = true
		powerup.queue_free()
	var player: Player = game.spawned_players.get(collector_id, null)
	if player:
		player.apply_power_up(powerup_type)
		AudioManager.play_powerup()
		game._refresh_player_hud(collector_id)

func _check_players_in_cell(cell: Vector2i, hit_list: Array[int]) -> void:
	for peer_id in game.spawned_players:
		var player: Player = game.spawned_players[peer_id]
		if player.is_alive and game.grid_map.world_to_grid(player.global_position) == cell and not hit_list.has(peer_id):
			hit_list.append(peer_id)

func _spawn_explosion_rays(center_cell: Vector2i, flame_cells: Array) -> void:
	game.grid_map.spawn_explosion_segment(center_cell, BomberAssets.ExplosionSegment.CENTER)
	for cell_item in flame_cells:
		var cell: Vector2i = cell_item as Vector2i
		var diff: Vector2i = cell - center_cell
		var dir := Vector2i(sign(diff.x), sign(diff.y))
		var is_tip: bool = not (cell + dir in flame_cells)
		var seg_type: int
		if dir.x != 0:
			if is_tip:
				seg_type = BomberAssets.ExplosionSegment.TIP_RIGHT if dir.x > 0 else BomberAssets.ExplosionSegment.TIP_LEFT
			else:
				seg_type = BomberAssets.ExplosionSegment.BEAM_HORIZONTAL
		else:
			if is_tip:
				seg_type = BomberAssets.ExplosionSegment.TIP_DOWN if dir.y > 0 else BomberAssets.ExplosionSegment.TIP_UP
			else:
				seg_type = BomberAssets.ExplosionSegment.BEAM_VERTICAL
		game.grid_map.spawn_explosion_segment(cell, seg_type)
