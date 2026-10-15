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
	bomb.is_pierce = player.has_pierce if "has_pierce" in player else false
	bomb.is_remote = player.has_remote if "has_remote" in player else false
	if "has_ice_bomb" in player and player.has_ice_bomb:
		bomb.element_type = 1
	elif "has_thunder_bomb" in player and player.has_thunder_bomb:
		bomb.element_type = 2
	player.active_bombs += 1
	bomb.exploded.connect(resolve_explosion)
	AudioManager.play_bomb_drop()
	if multiplayer.has_multiplayer_peer():
		game.sync_spawn_bomb.rpc(cell, player.peer_id, player.bomb_range, bomb.is_pierce, bomb.is_remote, bomb.element_type)
	game._refresh_player_hud(player.peer_id)

func detonate_remote_bombs(player: CharacterBody2D) -> void:
	var bombs: Array[Node] = game.get_tree().get_nodes_in_group("bombs")
	for b in bombs:
		if b is Bomb and is_instance_valid(b) and b.owner_player == player and not b.is_detonated:
			b.detonate()

func spawn_bomb_replica(cell: Vector2i, owner_peer_id: int, bomb_range: int, is_pierce: bool = false, is_remote: bool = false, element_type: int = 0) -> void:
	var player: Player = game.spawned_players.get(owner_peer_id, null)
	if player == null:
		return
	var bomb: Bomb = game.grid_map.place_bomb(cell, player)
	if bomb == null:
		return
	bomb.bomb_range = bomb_range
	bomb.is_pierce = is_pierce
	bomb.is_remote = is_remote
	bomb.element_type = element_type
	player.active_bombs += 1
	game._refresh_player_hud(owner_peer_id)
	AudioManager.play_bomb_drop()

func resolve_explosion(bomb: Bomb, center_cell: Vector2i, flame_range: int) -> void:
	if not is_instance_valid(bomb):
		return
	var is_pierce: bool = bomb.is_pierce
	var elem_type: int = bomb.element_type
	if elem_type == 2: # THUNDER BOMB: relâmpago percorre até o fim do mapa
		flame_range = 14
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
	_check_players_in_cell(center_cell, hit_players, elem_type)

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
				var powerup_type: int = game._roll_powerup_drop_type(target_cell)
				game.grid_map.destroy_block_at(target_cell, false)
				if powerup_type >= 0:
					dropped_powerups.append({"cell": target_cell, "type": powerup_type})
					game.grid_map.spawn_powerup(target_cell, powerup_type)
				flame_cells.append(target_cell)
				if not is_pierce and elem_type != 2:
					break
				continue
			if cell_type == GameState.CellType.EMPTY:
				flame_cells.append(target_cell)
				if game.grid_map.has_powerup_at(target_cell):
					burned_powerups.append(target_cell)
					var powerup: PowerUp = game.grid_map.get_powerup_at(target_cell)
					if powerup:
						powerup.destroy_by_fire()
				_check_players_in_cell(target_cell, hit_players, elem_type)
				var chained_bomb: Bomb = game.grid_map.get_bomb_at(target_cell)
				if is_instance_valid(chained_bomb):
					chained_bomb.detonate()

	_spawn_explosion_rays(center_cell, flame_cells)
	AudioManager.play_explosion()
	if not destroyed_blocks.is_empty() and GameState.is_enhanced():
		AudioManager.play_block_break()
	game.add_screen_shake(0.45 if elem_type == 2 else 0.35)
	for peer_id in hit_players:
		if game.spawned_players.has(peer_id):
			if elem_type == 1:
				game.spawned_players[peer_id].freeze_player(2.5)
			else:
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
	
	# Coleta de itens por bots no modo batalha
	for bot in game.spawned_bots:
		if not is_instance_valid(bot) or not bot.is_alive:
			continue
		var b_cell: Vector2i = game.grid_map.world_to_grid(bot.global_position)
		var b_pu: PowerUp = game.grid_map.get_powerup_at(b_cell)
		if b_pu != null and not b_pu.is_collected:
			var b_type: int = b_pu.type
			b_pu.is_collected = true
			b_pu.collision_shape.set_deferred("disabled", true)
			bot.apply_power_up(b_type)
			game.grid_map.unregister_powerup(b_cell)
			b_pu.queue_free()
			AudioManager.play_powerup()

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

func _check_players_in_cell(cell: Vector2i, hit_list: Array[int], elem_type: int = 0) -> void:
	for peer_id in game.spawned_players:
		var player: Player = game.spawned_players[peer_id]
		if player.is_alive and game.grid_map.world_to_grid(player.global_position) == cell and not hit_list.has(peer_id):
			hit_list.append(peer_id)
	for bot in game.spawned_bots:
		if is_instance_valid(bot) and bot.is_alive and game.grid_map.world_to_grid(bot.global_position) == cell:
			if elem_type == 1 and bot.has_method("freeze_player"):
				bot.freeze_player(2.5)
			else:
				bot.die()
	var enemies = game.get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and ("is_alive" in enemy) and enemy.is_alive and game.grid_map.world_to_grid(enemy.global_position) == cell:
			if elem_type == 1 and enemy.has_method("freeze_enemy"):
				enemy.freeze_enemy(3.0)
			elif enemy.has_method("take_bomb_hit"):
				enemy.take_bomb_hit()

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
