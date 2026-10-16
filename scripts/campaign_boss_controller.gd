extends RefCounted

## Encapsula o ciclo de estados e os padrões de ataque dos chefes da campanha.
var enemy: Node

func setup(owner: Node) -> void:
	enemy = owner

func update(delta: float, player_is_valid: bool) -> void:
	match enemy.boss_state:
		CampaignEnemy.BossState.PATROL:
			enemy._update_regular_movement(player_is_valid)
			enemy.boss_attack_cooldown -= delta
			if enemy.boss_attack_cooldown <= 0.0 and player_is_valid:
				_start_next_boss_attack()

		CampaignEnemy.BossState.TELEGRAPH:
			enemy.velocity = Vector2.ZERO
			enemy.is_winding_up = true
			enemy.is_boss_vulnerable = false
			enemy.boss_state_timer -= delta
			if enemy.boss_state_timer <= 0.0:
				_execute_boss_attack()

		CampaignEnemy.BossState.ATTACKING:
			enemy.velocity = Vector2.ZERO
			enemy.is_winding_up = false
			enemy.is_boss_vulnerable = false
			enemy.boss_state_timer -= delta
			if enemy.boss_state_timer <= 0.0:
				transition_to_vulnerable()

		CampaignEnemy.BossState.VULNERABLE:
			enemy.velocity = Vector2.ZERO
			enemy.is_winding_up = false
			enemy.is_boss_vulnerable = true
			enemy.boss_state_timer -= delta
			if enemy.boss_state_timer <= 0.0:
				# Recuperação: volta a patrulhar
				enemy.boss_state = CampaignEnemy.BossState.PATROL
				enemy.is_boss_vulnerable = false
				enemy.boss_danger_cells.clear()
				enemy.boss_attack_cooldown = 2.8 if enemy.boss_phase_two else 3.6
				enemy.last_decision_cell = Vector2i(-999, -999)
				enemy._select_next_direction(player_is_valid)

func _start_next_boss_attack() -> void:
	if not is_instance_valid(enemy.target_player) or not enemy.arena_grid:
		return
	enemy.boss_attack_id = (enemy.boss_attack_id + 1) % 3

	if enemy.stage_index == 4:
		# Chefe 1: Golem das Ruínas
		if enemy.boss_attack_id == 0:
			_golem_start_seismic_slam()
		elif enemy.boss_attack_id == 1:
			_golem_start_fissure_punch()
		else:
			_golem_start_quake_wave()
	elif enemy.stage_index == 9:
		# Chefe 2: Espectro Dimensional
		if enemy.boss_attack_id == 0:
			_espectro_start_dimensional_rifts()
		elif enemy.boss_attack_id == 1:
			_espectro_start_blink_pulse()
		else:
			_espectro_start_rift_ring()
	elif enemy.stage_index == 11:
		# Chefe 3: Cronos, o Lorde Temporal
		if enemy.boss_attack_id == 0:
			start_time_mine()
		elif enemy.boss_attack_id == 1:
			_cronos_start_chrono_ray()
		else:
			_cronos_start_mine_cluster()
	else:
		# Fallback para outros estágios caso chefe genérico
		_golem_start_fissure_punch()

func _execute_boss_attack() -> void:
	if enemy.stage_index == 4:
		if enemy.boss_attack_id == 0:
			_golem_execute_slam()
		elif enemy.boss_attack_id == 1:
			_golem_execute_punch()
		else:
			_golem_execute_quake_wave()
	elif enemy.stage_index == 9:
		if enemy.boss_attack_id == 0:
			_espectro_execute_rifts()
		elif enemy.boss_attack_id == 1:
			_espectro_execute_blink()
		else:
			_espectro_execute_rift_ring()
	elif enemy.stage_index == 11:
		if enemy.boss_attack_id == 0:
			_cronos_execute_mine()
		elif enemy.boss_attack_id == 1:
			_cronos_execute_ray()
		else:
			_cronos_execute_mine_cluster()
	else:
		_golem_execute_punch()

func transition_to_vulnerable() -> void:
	enemy.boss_state = CampaignEnemy.BossState.VULNERABLE
	enemy.is_boss_vulnerable = true
	enemy.is_winding_up = false
	enemy.boss_leap_height = 0.0

	# Tempo de vulnerabilidade generoso para contra-ataque do jogador
	if enemy.stage_index == 4:
		enemy.boss_state_timer = 1.4 if enemy.boss_phase_two else 1.8
	elif enemy.stage_index == 9:
		enemy.boss_state_timer = 1.3 if enemy.boss_phase_two else 1.7
	elif enemy.stage_index == 11:
		enemy.boss_state_timer = 1.4 if enemy.boss_phase_two else 1.8
	else:
		enemy.boss_state_timer = 1.5

func on_damaged() -> void:
	if not enemy.boss_phase_two and enemy.health <= int(ceil(float(enemy.max_health) * 0.5)):
		enemy.boss_phase_two = true
		enemy.get_tree().call_group("game_orchestrator", "add_screen_shake", 0.55)
		AudioManager.play_enemy_alert()

		if enemy.stage_index == 4:
			# Golem: Fúria Sísmica (mais veloz e avermelhado)
			enemy.move_speed = 72.0
			enemy.modulate = Color(1.3, 0.6, 0.35)
		elif enemy.stage_index == 9:
			# Espectro: Invocação de cópia ilusória e pulso astral
			enemy.move_speed = 82.0
			enemy.modulate = Color(0.9, 0.45, 1.4)
			if not enemy.boss_illusion_spawned:
				_boss_spawn_illusion()
		elif enemy.stage_index == 11:
			# Cronos: Fúria Temporal acelerada
			_boss_trigger_enrage()

# ==================== CHEFE 1: GOLEM DAS RUÍNAS (FASE 5) ====================

func _golem_start_seismic_slam() -> void:
	enemy.boss_state = CampaignEnemy.BossState.TELEGRAPH
	enemy.boss_state_timer = 1.1 if enemy.boss_phase_two else 1.4
	enemy.is_winding_up = true
	enemy.is_boss_vulnerable = false

	var p_cell: Vector2i = enemy.arena_grid.world_to_grid(enemy.target_player.global_position)
	enemy.boss_target_cell = Vector2i(clampi(p_cell.x, 2, ArenaGrid.WIDTH - 3), clampi(p_cell.y, 2, ArenaGrid.HEIGHT - 3))

	# Área de perigo em cruz 3x3 no ponto de impacto
	enemy.boss_danger_cells = [
		enemy.boss_target_cell,
		enemy.boss_target_cell + Vector2i.UP,
		enemy.boss_target_cell + Vector2i.DOWN,
		enemy.boss_target_cell + Vector2i.LEFT,
		enemy.boss_target_cell + Vector2i.RIGHT
	]

	# Salto no ar (eleva a altura visual)
	var leap_tween: Tween = enemy.create_tween()
	leap_tween.tween_property(enemy, "boss_leap_height", 46.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	AudioManager.play_enemy_alert()

func _golem_execute_slam() -> void:
	enemy.boss_state = CampaignEnemy.BossState.ATTACKING
	enemy.boss_state_timer = 0.28
	enemy.boss_leap_height = 0.0
	enemy.global_position = enemy.arena_grid.grid_to_world(enemy.boss_target_cell)

	enemy.get_tree().call_group("game_orchestrator", "add_screen_shake", 0.6)
	AudioManager.play_bump()

	for cell in enemy.boss_danger_cells:
		if enemy.arena_grid.is_in_bounds(cell):
			if enemy.arena_grid.get_cell_type(cell) == GameState.CellType.BLOCK_DESTRUCTIBLE:
				enemy.arena_grid.destroy_block_at(cell, false)
			if is_instance_valid(enemy.target_player) and enemy.arena_grid.world_to_grid(enemy.target_player.global_position) == cell:
				enemy.target_player.die()

func _golem_start_fissure_punch() -> void:
	enemy.boss_state = CampaignEnemy.BossState.TELEGRAPH
	enemy.boss_state_timer = 1.0 if enemy.boss_phase_two else 1.3
	enemy.is_winding_up = true
	enemy.is_boss_vulnerable = false

	var diff: Vector2 = enemy.target_player.global_position - enemy.global_position
	if absf(diff.x) > absf(diff.y):
		enemy.boss_telegraph_dir = Vector2(sign(diff.x), 0.0)
	else:
		enemy.boss_telegraph_dir = Vector2(0.0, sign(diff.y))
	enemy.direction = enemy.boss_telegraph_dir

	var c_cell: Vector2i = enemy.arena_grid.world_to_grid(enemy.global_position)
	var step: Vector2i = Vector2i(roundi(enemy.boss_telegraph_dir.x), roundi(enemy.boss_telegraph_dir.y))
	enemy.boss_danger_cells.clear()
	for dist in range(1, 4):
		var target_c: Vector2i = c_cell + step * dist
		if enemy.arena_grid.is_in_bounds(target_c) and enemy.arena_grid.get_cell_type(target_c) != GameState.CellType.WALL_INDESTRUCTIBLE:
			enemy.boss_danger_cells.append(target_c)

	AudioManager.play_enemy_alert()

func _golem_execute_punch() -> void:
	enemy.boss_state = CampaignEnemy.BossState.ATTACKING
	enemy.boss_state_timer = 0.25
	enemy.get_tree().call_group("game_orchestrator", "add_screen_shake", 0.45)
	AudioManager.play_bump()

	for cell in enemy.boss_danger_cells:
		if enemy.arena_grid.is_in_bounds(cell):
			if enemy.arena_grid.get_cell_type(cell) == GameState.CellType.BLOCK_DESTRUCTIBLE:
				enemy.arena_grid.destroy_block_at(cell, false)
			if is_instance_valid(enemy.target_player) and enemy.arena_grid.world_to_grid(enemy.target_player.global_position) == cell:
				enemy.target_player.die()

func _golem_start_quake_wave() -> void:
	enemy.boss_state = CampaignEnemy.BossState.TELEGRAPH
	enemy.boss_state_timer = 1.2 if enemy.boss_phase_two else 1.5
	enemy.is_winding_up = true
	enemy.is_boss_vulnerable = false
	var player_cell: Vector2i = enemy.arena_grid.world_to_grid(enemy.target_player.global_position)
	var boss_cell: Vector2i = enemy.arena_grid.world_to_grid(enemy.global_position)
	var horizontal: bool = absi(player_cell.x - boss_cell.x) >= absi(player_cell.y - boss_cell.y)
	enemy.boss_danger_cells.clear()
	if horizontal:
		for x in range(1, ArenaGrid.WIDTH - 1):
			enemy.boss_danger_cells.append(Vector2i(x, player_cell.y))
	else:
		for y in range(1, ArenaGrid.HEIGHT - 1):
			enemy.boss_danger_cells.append(Vector2i(player_cell.x, y))
	AudioManager.play_enemy_alert()

func _golem_execute_quake_wave() -> void:
	enemy.boss_state = CampaignEnemy.BossState.ATTACKING
	enemy.boss_state_timer = 0.35
	AudioManager.play_bump()
	enemy.get_tree().call_group("game_orchestrator", "add_screen_shake", 0.55)
	for cell in enemy.boss_danger_cells:
		if is_instance_valid(enemy.target_player) and enemy.arena_grid.world_to_grid(enemy.target_player.global_position) == cell:
			enemy.target_player.die()

# ==================== CHEFE 2: ESPECTRO DIMENSIONAL (FASE 10) ====================

func _espectro_start_dimensional_rifts() -> void:
	enemy.boss_state = CampaignEnemy.BossState.TELEGRAPH
	enemy.boss_state_timer = 1.2 if enemy.boss_phase_two else 1.5
	enemy.is_winding_up = true
	enemy.is_boss_vulnerable = false

	enemy.boss_danger_cells.clear()
	var p_cell: Vector2i = enemy.arena_grid.world_to_grid(enemy.target_player.global_position)
	enemy.boss_danger_cells.append(p_cell)

	# Adiciona 1 ou 2 fendas adicionais nas proximidades do jogador
	var count: int = 3 if enemy.boss_phase_two else 2
	for step in CampaignEnemy.DIRECTIONS:
		if enemy.boss_danger_cells.size() >= count:
			break
		var cand: Vector2i = p_cell + step * 2
		if enemy.arena_grid.is_in_bounds(cand) and enemy.arena_grid.get_cell_type(cand) != GameState.CellType.WALL_INDESTRUCTIBLE:
			enemy.boss_danger_cells.append(cand)

	AudioManager.play_enemy_alert()

func _espectro_execute_rifts() -> void:
	enemy.boss_state = CampaignEnemy.BossState.ATTACKING
	enemy.boss_state_timer = 0.35
	AudioManager.play_explosion()
	enemy.get_tree().call_group("game_orchestrator", "add_screen_shake", 0.4)

	for cell in enemy.boss_danger_cells:
		if is_instance_valid(enemy.target_player) and enemy.arena_grid.world_to_grid(enemy.target_player.global_position) == cell:
			enemy.target_player.die()

func _espectro_start_blink_pulse() -> void:
	enemy.boss_state = CampaignEnemy.BossState.TELEGRAPH
	enemy.boss_state_timer = 1.0 if enemy.boss_phase_two else 1.3
	enemy.is_winding_up = true
	enemy.is_boss_vulnerable = false

	var player_cell: Vector2i = enemy.arena_grid.world_to_grid(enemy.target_player.global_position)
	var candidates: Array[Vector2i] = []
	for x in range(2, ArenaGrid.WIDTH - 2):
		for y in range(2, ArenaGrid.HEIGHT - 2):
			var cell := Vector2i(x, y)
			if enemy.arena_grid.is_walkable(cell) and not enemy.imminent_danger.has(cell):
				var dist: int = absi(cell.x - player_cell.x) + absi(cell.y - player_cell.y)
				if dist >= 4:
					candidates.append(cell)

	if candidates.is_empty():
		candidates.append(player_cell + Vector2i(2, 0))

	enemy.boss_target_cell = candidates.pick_random()
	enemy.boss_danger_cells = [
		enemy.boss_target_cell,
		enemy.boss_target_cell + Vector2i.UP,
		enemy.boss_target_cell + Vector2i.DOWN,
		enemy.boss_target_cell + Vector2i.LEFT,
		enemy.boss_target_cell + Vector2i.RIGHT
	]

	# Desvanece enquanto canaliza o teleporte
	var fade_tween: Tween = enemy.create_tween()
	fade_tween.tween_property(enemy, "modulate:a", 0.25, 0.2)
	AudioManager.play_enemy_alert()

func _espectro_execute_blink() -> void:
	enemy.boss_state = CampaignEnemy.BossState.ATTACKING
	enemy.boss_state_timer = 0.3
	enemy.global_position = enemy.arena_grid.grid_to_world(enemy.boss_target_cell)
	enemy.modulate.a = 1.0
	AudioManager.play_enemy_alert()

	for cell in enemy.boss_danger_cells:
		if is_instance_valid(enemy.target_player) and enemy.arena_grid.world_to_grid(enemy.target_player.global_position) == cell:
			enemy.target_player.die()

func _espectro_start_rift_ring() -> void:
	enemy.boss_state = CampaignEnemy.BossState.TELEGRAPH
	enemy.boss_state_timer = 1.0 if enemy.boss_phase_two else 1.35
	enemy.is_winding_up = true
	enemy.is_boss_vulnerable = false
	var p_cell: Vector2i = enemy.arena_grid.world_to_grid(enemy.target_player.global_position)
	enemy.boss_danger_cells.clear()
	for offset in [Vector2i(2, 2), Vector2i(2, -2), Vector2i(-2, 2), Vector2i(-2, -2)]:
		var target_cell: Vector2i = p_cell + offset
		if enemy.arena_grid.is_in_bounds(target_cell) and enemy.arena_grid.get_cell_type(target_cell) != GameState.CellType.WALL_INDESTRUCTIBLE:
			enemy.boss_danger_cells.append(target_cell)
	if enemy.boss_phase_two:
		enemy.boss_danger_cells.append(p_cell)
	AudioManager.play_enemy_alert()

func _espectro_execute_rift_ring() -> void:
	enemy.boss_state = CampaignEnemy.BossState.ATTACKING
	enemy.boss_state_timer = 0.35
	AudioManager.play_explosion()
	enemy.get_tree().call_group("game_orchestrator", "add_screen_shake", 0.4)
	for cell in enemy.boss_danger_cells:
		if is_instance_valid(enemy.target_player) and enemy.arena_grid.world_to_grid(enemy.target_player.global_position) == cell:
			enemy.target_player.die()

func _boss_spawn_illusion() -> void:
	enemy.boss_illusion_spawned = true
	if enemy.arena_grid == null or enemy.get_parent() == null:
		return
	var current_cell: Vector2i = enemy.arena_grid.world_to_grid(enemy.global_position)
	var spawn_cell: Vector2i = Vector2i(-1, -1)
	for d in CampaignEnemy.DIRECTIONS:
		var c: Vector2i = current_cell + d
		if enemy.arena_grid.is_walkable(c):
			spawn_cell = c
			break
	if spawn_cell == Vector2i(-1, -1):
		return
	var enemy_scene: PackedScene = load("res://scenes/campaign_enemy.tscn")
	var minion: CampaignEnemy = enemy_scene.instantiate() as CampaignEnemy
	minion.setup(enemy.target_player, enemy.stage_index, enemy.arena_grid, CampaignEnemy.Archetype.WANDERER)
	minion.modulate = Color(0.65, 0.85, 1.3, 0.75)
	minion.global_position = enemy.arena_grid.grid_to_world(spawn_cell)
	enemy.get_parent().add_child(minion)

# ==================== CHEFE 3: CRONOS, O LORDE TEMPORAL (FASE 12) ====================

func start_time_mine() -> void:
	if not enemy.arena_grid:
		return
	var c_cell: Vector2i = enemy.arena_grid.world_to_grid(enemy.global_position)
	var drop_cell: Vector2i = c_cell
	for d in CampaignEnemy.DIRECTIONS:
		var cand: Vector2i = c_cell + d
		if enemy.arena_grid.is_in_bounds(cand) and enemy.arena_grid.get_cell_type(cand) == GameState.CellType.EMPTY and not enemy.arena_grid.has_bomb_at(cand):
			drop_cell = cand
			break

	var mine: Bomb = enemy.arena_grid.place_bomb(drop_cell, enemy as CharacterBody2D)
	if mine:
		mine.bomb_range = 3
		mine.fuse_time = 2.0
		if mine.fuse_timer:
			mine.fuse_timer.start(2.0)
		mine.exploded.connect(func(b: Bomb, c: Vector2i, r: int):
			enemy.arena_grid.unregister_bomb(c)
			var game = enemy.get_tree().get_first_node_in_group("game_orchestrator")
			if game and game.get("bomb_system"):
				game.bomb_system.call("resolve_explosion", b, c, r)
		)
		AudioManager.play_bomb_drop()

	# Entra imediatamente em vulnerabilidade enquanto a mina faz a contagem
	enemy.boss_state = CampaignEnemy.BossState.VULNERABLE
	enemy.boss_state_timer = 1.4 if enemy.boss_phase_two else 1.7
	enemy.is_boss_vulnerable = true
	enemy.is_winding_up = false

func _cronos_start_mine_cluster() -> void:
	enemy.boss_state = CampaignEnemy.BossState.TELEGRAPH
	enemy.boss_state_timer = 1.15 if enemy.boss_phase_two else 1.45
	enemy.is_winding_up = true
	enemy.is_boss_vulnerable = false
	var boss_cell: Vector2i = enemy.arena_grid.world_to_grid(enemy.global_position)
	enemy.boss_danger_cells.clear()
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var cell: Vector2i = boss_cell + offset
		if not enemy.arena_grid.is_in_bounds(cell) or enemy.arena_grid.get_cell_type(cell) != GameState.CellType.EMPTY or enemy.arena_grid.has_bomb_at(cell):
			continue
		enemy.boss_danger_cells.append(cell)
		if enemy.boss_danger_cells.size() >= (3 if enemy.boss_phase_two else 2):
			break
	AudioManager.play_enemy_alert()

func _cronos_execute_mine_cluster() -> void:
	var placed: int = 0
	for cell in enemy.boss_danger_cells:
		if enemy.arena_grid.get_cell_type(cell) != GameState.CellType.EMPTY or enemy.arena_grid.has_bomb_at(cell):
			continue
		var mine: Bomb = enemy.arena_grid.place_bomb(cell, enemy as CharacterBody2D)
		if mine == null:
			continue
		mine.bomb_range = 2
		mine.fuse_time = 2.2
		if mine.fuse_timer:
			mine.fuse_timer.start(2.2)
		mine.exploded.connect(func(b: Bomb, c: Vector2i, r: int):
			enemy.arena_grid.unregister_bomb(c)
			var game = enemy.get_tree().get_first_node_in_group("game_orchestrator")
			if game and game.get("bomb_system"):
				game.bomb_system.call("resolve_explosion", b, c, r)
		)
		placed += 1
		if placed >= (3 if enemy.boss_phase_two else 2):
			break
	if placed > 0:
		AudioManager.play_bomb_drop()
	enemy.boss_state = CampaignEnemy.BossState.ATTACKING
	enemy.boss_state_timer = 0.25
	enemy.is_winding_up = false
	enemy.is_boss_vulnerable = false

func _cronos_execute_mine() -> void:
	# A mina temporal é detonada pelo próprio timer/sistema de bombas
	transition_to_vulnerable()

func _cronos_start_chrono_ray() -> void:
	enemy.boss_state = CampaignEnemy.BossState.TELEGRAPH
	enemy.boss_state_timer = 1.1 if enemy.boss_phase_two else 1.4
	enemy.is_winding_up = true
	enemy.is_boss_vulnerable = false

	var diff: Vector2 = enemy.target_player.global_position - enemy.global_position
	if absf(diff.x) > absf(diff.y):
		enemy.boss_telegraph_dir = Vector2(sign(diff.x), 0.0)
	else:
		enemy.boss_telegraph_dir = Vector2(0.0, sign(diff.y))
	enemy.direction = enemy.boss_telegraph_dir

	var c_cell: Vector2i = enemy.arena_grid.world_to_grid(enemy.global_position)
	var step: Vector2i = Vector2i(roundi(enemy.boss_telegraph_dir.x), roundi(enemy.boss_telegraph_dir.y))
	enemy.boss_danger_cells.clear()
	for dist in range(1, 9):
		var target_c: Vector2i = c_cell + step * dist
		if not enemy.arena_grid.is_in_bounds(target_c) or enemy.arena_grid.get_cell_type(target_c) == GameState.CellType.WALL_INDESTRUCTIBLE:
			break
		enemy.boss_danger_cells.append(target_c)

	AudioManager.play_enemy_alert()

func _cronos_execute_ray() -> void:
	enemy.boss_state = CampaignEnemy.BossState.ATTACKING
	enemy.boss_state_timer = 0.35
	AudioManager.play_explosion()
	enemy.get_tree().call_group("game_orchestrator", "add_screen_shake", 0.4)

	for cell in enemy.boss_danger_cells:
		if is_instance_valid(enemy.target_player) and enemy.arena_grid.world_to_grid(enemy.target_player.global_position) == cell:
			enemy.target_player.die()

func _boss_trigger_enrage() -> void:
	enemy.boss_enraged = true
	enemy.boss_phase_two = true
	enemy.move_speed = 90.0
	enemy.get_tree().call_group("game_orchestrator", "add_screen_shake", 0.55)
	AudioManager.play_enemy_alert()
	enemy.modulate = Color(1.4, 0.45, 0.35)


