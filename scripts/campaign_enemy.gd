class_name CampaignEnemy
extends CharacterBody2D

signal defeated(enemy: CampaignEnemy)

enum Archetype { WANDERER, HUNTER, CHARGER, BOSS }

const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
const VERTICAL_DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN]
const HORIZONTAL_DIRECTIONS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT]
const ENEMY_COLORS: Array[Color] = [
	Color(0.84, 0.25, 0.28),
	Color(0.65, 0.31, 0.86),
	Color(0.18, 0.66, 0.72),
	Color(0.91, 0.54, 0.16)
]
const HURT_INVULNERABILITY: float = 0.42

var target_player: Player
var arena_grid: ArenaGrid
var archetype: int = Archetype.WANDERER
var body_color: Color = ENEMY_COLORS[0]
var accent_color: Color = Color.WHITE
var move_speed: float = 82.0
var direction: Vector2 = Vector2.DOWN
var direction_timer: float = 0.0
var animation_time: float = 0.0
var is_alive: bool = true
var max_health: int = 1
var health: int = 1
var hurt_invulnerability: float = 0.0
var danger_refresh: float = 0.0
var escape_refresh: float = 0.0
var imminent_danger: Dictionary = {}
var is_winding_up: bool = false
var windup_remaining: float = 0.0
var is_charging: bool = false
var charge_remaining: float = 0.0
var charge_cooldown: float = 0.0
var charge_direction: Vector2 = Vector2.ZERO
var stuck_time: float = 0.0
var queued_direction: Vector2 = Vector2.ZERO
var is_chasing: bool = false
var last_decision_cell: Vector2i = Vector2i(-999, -999)

# Identificação da Fase e Mecânicas Específicas de Chefes (Fases 5, 10 e 12)
var stage_index: int = 0
var boss_stomp_timer: float = 5.0
var boss_illusion_spawned: bool = false
var boss_enraged: bool = false
var boss_time_bomb_timer: float = 4.0
var freeze_timer: float = 0.0

@onready var appearance: Node2D = $Appearance

func setup(target: Player, stage_idx: int, grid: ArenaGrid, selected_archetype: int = Archetype.WANDERER) -> void:
	target_player = target
	stage_index = stage_idx
	arena_grid = grid
	archetype = clampi(selected_archetype, Archetype.WANDERER, Archetype.BOSS)
	var stage_level: float = float(mini(stage_index, 9))
	body_color = ENEMY_COLORS[posmod(stage_index + int(archetype), ENEMY_COLORS.size())]
	accent_color = body_color.lightened(0.36)
	match archetype:
		Archetype.WANDERER:
			move_speed = 58.0 + stage_level * 2.0
			max_health = 1
		Archetype.HUNTER:
			move_speed = 72.0 + stage_level * 3.0
			max_health = 1
		Archetype.CHARGER:
			move_speed = 66.0 + stage_level * 2.5
			max_health = 1
		Archetype.BOSS:
			# Balanceamento individual e marcante por fase de chefe
			if stage_index == 4:
				# Fase 5: Golem das Ruínas (Terremoto / Queda de Blocos)
				move_speed = 60.0
				max_health = 4
				body_color = Color(0.82, 0.48, 0.25)
			elif stage_index == 9:
				# Fase 10: Espectro Dimensional (Teleporte e Cópia Ilusória)
				move_speed = 74.0
				max_health = 5
				body_color = Color(0.68, 0.25, 0.88)
			elif stage_index == 11:
				# Fase 12: Cronos, o Lorde Temporal (Minas Temporais e Fúria)
				move_speed = 78.0
				max_health = 6
				body_color = Color(0.96, 0.78, 0.22)
			else:
				move_speed = 62.0 + stage_level * 2.0
				max_health = 4
			accent_color = body_color.lightened(0.36)
	health = max_health
	if archetype == Archetype.BOSS:
		var shape: CircleShape2D = $CollisionShape2D.shape.duplicate() as CircleShape2D
		shape.radius = 23.0
		$CollisionShape2D.shape = shape

func _ready() -> void:
	add_to_group("enemies")
	last_decision_cell = Vector2i(-999, -999)
	direction = Vector2.ZERO
	if arena_grid:
		var current_cell: Vector2i = arena_grid.world_to_grid(global_position)
		global_position = arena_grid.grid_to_world(current_cell)
		last_decision_cell = current_cell
		_choose_wander_direction()
	_update_appearance()

func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	var frame_start_position: Vector2 = global_position
	animation_time += delta
	direction_timer -= delta
	hurt_invulnerability = maxf(0.0, hurt_invulnerability - delta)
	charge_cooldown = maxf(0.0, charge_cooldown - delta)
	if freeze_timer > 0.0:
		freeze_timer = maxf(0.0, freeze_timer - delta)
		velocity = Vector2.ZERO
		modulate = Color(0.4, 0.8, 1.4, 1.0)
		if freeze_timer <= 0.0:
			modulate = Color.WHITE
		_update_appearance()
		return
	danger_refresh -= delta
	escape_refresh -= delta
	if danger_refresh <= 0.0:
		imminent_danger = _collect_imminent_danger()
		danger_refresh = 0.12

	var player_is_valid: bool = is_instance_valid(target_player) and target_player.is_alive
	var current_cell: Vector2i = arena_grid.world_to_grid(global_position) if arena_grid else Vector2i.ZERO
	var forward_step: Vector2i = Vector2i(roundi(direction.x), roundi(direction.y))
	var next_cell: Vector2i = current_cell + forward_step if arena_grid else current_cell
	var path_is_dangerous: bool = imminent_danger.has(current_cell) or (direction != Vector2.ZERO and imminent_danger.has(next_cell))
	if path_is_dangerous:
		if is_charging or is_winding_up:
			is_charging = false
			is_winding_up = false
			charge_remaining = 0.0
			windup_remaining = 0.0
			charge_cooldown = 0.8
		if escape_refresh <= 0.0:
			_choose_escape_direction()
			escape_refresh = 0.25

	if (archetype == Archetype.CHARGER or archetype == Archetype.BOSS) and player_is_valid:
		_update_charger(delta)
	else:
		_update_regular_movement(player_is_valid)
	
	if archetype == Archetype.BOSS:
		_update_boss_mechanics(delta)
	if velocity.length_squared() > 1.0 and global_position.distance_squared_to(frame_start_position) < 0.5:
		stuck_time += delta
		if stuck_time >= 0.35:
			_recover_from_stuck()
			is_charging = false
			is_winding_up = false
			charge_cooldown = maxf(charge_cooldown, 0.8)
			direction_timer = 0.0
			queued_direction = Vector2.ZERO
			last_decision_cell = Vector2i(-999, -999)
			velocity = Vector2.ZERO
			stuck_time = 0.0
			_select_next_direction(player_is_valid)
	else:
		stuck_time = 0.0

	var contact_distance: float = 43.0 if archetype == Archetype.BOSS else 35.0
	if player_is_valid and global_position.distance_to(target_player.global_position) < contact_distance:
		target_player.die()
	_update_appearance()

func _update_appearance() -> void:
	appearance.call("show_enemy_state", self)

func _update_regular_movement(player_is_valid: bool) -> void:
	if arena_grid == null:
		return

	var current_cell: Vector2i = arena_grid.world_to_grid(global_position)
	var cell_center: Vector2 = arena_grid.grid_to_world(current_cell)

	# Se estiver sem direção ou parado, seleciona direção imediatamente para nunca ficar congelado
	if direction == Vector2.ZERO:
		last_decision_cell = current_cell
		global_position = cell_center
		_select_next_direction(player_is_valid)

	# Verifica se alcançou ou passou do centro da casa no eixo do movimento
	var reached_center: bool = false
	if direction == Vector2.ZERO:
		reached_center = true
	elif direction.x > 0.0:
		reached_center = global_position.x >= cell_center.x
	elif direction.x < 0.0:
		reached_center = global_position.x <= cell_center.x
	elif direction.y > 0.0:
		reached_center = global_position.y >= cell_center.y
	elif direction.y < 0.0:
		reached_center = global_position.y <= cell_center.y

	if reached_center and current_cell != last_decision_cell:
		last_decision_cell = current_cell
		# Alinha com precisão ao centro da célula ao tomar decisão na intersecção
		global_position = cell_center

		# Avalia opções a partir da casa atual
		var forward_step: Vector2i = Vector2i(roundi(direction.x), roundi(direction.y))
		var forward_cell: Vector2i = current_cell + forward_step
		var forward_open: bool = forward_step != Vector2i.ZERO and arena_grid.is_walkable(forward_cell) and not imminent_danger.has(forward_cell)

		var perp_dirs: Array[Vector2i] = VERTICAL_DIRECTIONS if forward_step.x != 0 else HORIZONTAL_DIRECTIONS
		var perp_open: Array[Vector2i] = []
		for p in perp_dirs:
			var side_cell: Vector2i = current_cell + p
			if arena_grid.is_walkable(side_cell) and not imminent_danger.has(side_cell):
				perp_open.append(p)

		# Cruzamento: há curvas perpendiculares OU o caminho em frente está bloqueado/perigoso OU está perseguindo
		var is_intersection: bool = not perp_open.is_empty() or not forward_open
		if is_intersection or is_chasing:
			_select_next_direction(player_is_valid)

	_move_aligned(move_speed)

	# Colisão frontal: só considera bloqueado se bater de frente num obstáculo
	if get_slide_collision_count() > 0 and direction != Vector2.ZERO:
		for i in range(get_slide_collision_count()):
			var col: KinematicCollision2D = get_slide_collision(i)
			if col.get_normal().dot(direction) < -0.5:
				last_decision_cell = Vector2i(-999, -999)
				_recover_from_stuck()
				_select_next_direction(player_is_valid)
				break

func _select_next_direction(player_is_valid: bool) -> void:
	if arena_grid:
		var current_cell: Vector2i = arena_grid.world_to_grid(global_position)
		if imminent_danger.has(current_cell):
			_choose_escape_direction()
			return

	if player_is_valid:
		var dist: float = global_position.distance_to(target_player.global_position)
		var can_chase: bool = false
		if archetype == Archetype.HUNTER:
			can_chase = dist <= (720.0 if is_chasing else 640.0)
		elif archetype == Archetype.WANDERER:
			# Perseguição consistente com histerese (260px entrada, 320px saída) para evitar alternâncias rápidas
			can_chase = dist <= (320.0 if is_chasing else 260.0)
		elif archetype == Archetype.CHARGER or archetype == Archetype.BOSS:
			can_chase = dist <= (520.0 if is_chasing else 440.0)

		if can_chase:
			var chase_dir: Vector2 = _get_chase_direction()
			if chase_dir != Vector2.ZERO:
				is_chasing = true
				direction = chase_dir
				return

	is_chasing = false
	_choose_wander_direction()

func _get_chase_direction() -> Vector2:
	if arena_grid == null or not is_instance_valid(target_player):
		return Vector2.ZERO
	var start_cell: Vector2i = arena_grid.world_to_grid(global_position)
	if imminent_danger.has(start_cell):
		return Vector2.ZERO
	var goal_cell: Vector2i = arena_grid.world_to_grid(target_player.global_position)
	if start_cell == goal_cell:
		var diff: Vector2 = target_player.global_position - global_position
		if absf(diff.x) > absf(diff.y) and absf(diff.x) > 1.0:
			return Vector2(sign(diff.x), 0.0)
		elif absf(diff.y) > 1.0:
			return Vector2(0.0, sign(diff.y))
		return direction

	var goals: Array[Vector2i] = []
	if not imminent_danger.has(goal_cell):
		goals.append(goal_cell)
	else:
		for step in DIRECTIONS:
			var safe_neighbor: Vector2i = goal_cell + step
			if arena_grid.is_walkable(safe_neighbor) and not imminent_danger.has(safe_neighbor):
				goals.append(safe_neighbor)
	if goals.is_empty():
		return Vector2.ZERO
	return _find_path_direction(start_cell, goals, false)

func _choose_wander_direction() -> void:
	if arena_grid == null:
		direction = Vector2.ZERO
		return
	var current_cell: Vector2i = arena_grid.world_to_grid(global_position)
	if imminent_danger.has(current_cell):
		_choose_escape_direction()
		return

	var all_safe_steps: Array[Vector2i] = []
	for step in DIRECTIONS:
		var neighbor: Vector2i = current_cell + step
		if arena_grid.is_walkable(neighbor) and not imminent_danger.has(neighbor):
			all_safe_steps.append(step)

	if all_safe_steps.is_empty():
		_choose_escape_direction()
		return

	var forward_step: Vector2i = Vector2i(roundi(direction.x), roundi(direction.y)) if direction != Vector2.ZERO else Vector2i.ZERO
	var reverse_step: Vector2i = -forward_step if forward_step != Vector2i.ZERO else Vector2i.ZERO

	var forward_open: bool = all_safe_steps.has(forward_step)
	var perp_steps: Array[Vector2i] = []
	for step in all_safe_steps:
		if step != forward_step and step != reverse_step:
			perp_steps.append(step)

	if forward_open and not perp_steps.is_empty():
		# Em cruzamentos: 60% chance de manter em frente, 40% de virar em bifurcações para explorar o mapa
		if randf() < 0.6:
			direction = Vector2(forward_step)
		else:
			direction = Vector2(perp_steps.pick_random())
	elif forward_open:
		direction = Vector2(forward_step)
	elif not perp_steps.is_empty():
		direction = Vector2(perp_steps.pick_random())
	elif all_safe_steps.has(reverse_step):
		# Fim de linha (beco sem saída): inverte marcha
		direction = Vector2(reverse_step)
	else:
		direction = Vector2(all_safe_steps.pick_random())

## Move na direção da grade e mantém alinhamento contínuo ao centro do corredor.
## Garante avanço sem interrupções nem snags nas quinas dos blocos.
func _move_aligned(speed: float) -> void:
	if arena_grid == null or direction == Vector2.ZERO:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var current_cell: Vector2i = arena_grid.world_to_grid(global_position)
	var cell_center: Vector2 = arena_grid.grid_to_world(current_cell)

	if absf(direction.x) > 0.0:
		velocity.x = sign(direction.x) * speed
		var diff_y: float = cell_center.y - global_position.y
		if absf(diff_y) > 0.5:
			velocity.y = clampf(diff_y * 12.0, -speed * 0.45, speed * 0.45)
		else:
			velocity.y = 0.0
	else:
		velocity.y = sign(direction.y) * speed
		var diff_x: float = cell_center.x - global_position.x
		if absf(diff_x) > 0.5:
			velocity.x = clampf(diff_x * 12.0, -speed * 0.45, speed * 0.45)
		else:
			velocity.x = 0.0

	move_and_slide()

## Reposiciona o inimigo no centro livre mais próximo após uma colisão persistente.
func _recover_from_stuck() -> void:
	if arena_grid == null:
		return
	var center_cell: Vector2i = arena_grid.world_to_grid(global_position)
	var best_position: Vector2 = global_position
	var best_distance: float = INF
	for x_offset in range(-1, 2):
		for y_offset in range(-1, 2):
			var candidate_cell: Vector2i = center_cell + Vector2i(x_offset, y_offset)
			if not arena_grid.is_walkable(candidate_cell):
				continue
			var candidate_position: Vector2 = arena_grid.grid_to_world(candidate_cell)
			var candidate_distance: float = global_position.distance_squared_to(candidate_position)
			if candidate_distance < best_distance:
				best_distance = candidate_distance
				best_position = candidate_position
	if best_distance < INF:
		global_position = best_position

func _update_charger(delta: float) -> void:
	if is_charging:
		charge_remaining -= delta
		var speed_factor: float = 2.15 if archetype == Archetype.BOSS else 1.8
		direction = charge_direction
		_move_aligned(move_speed * speed_factor)

		# Cronos Enfurecido (Fase 12) demole blocos destrutíveis em sua carga
		if archetype == Archetype.BOSS and stage_index == 11 and boss_enraged and arena_grid:
			var charge_cell: Vector2i = arena_grid.world_to_grid(global_position)
			var forward_c: Vector2i = charge_cell + Vector2i(roundi(charge_direction.x), roundi(charge_direction.y))
			if arena_grid.is_in_bounds(forward_c) and arena_grid.get_cell_type(forward_c) == GameState.CellType.BLOCK_DESTRUCTIBLE:
				arena_grid.destroy_block_at(forward_c, false)
				AudioManager.play_block_break()

		if get_slide_collision_count() > 0 or charge_remaining <= 0.0:
			is_charging = false
			charge_cooldown = 3.2 if archetype == Archetype.BOSS else 2.6
			direction_timer = 0.35
			last_decision_cell = Vector2i(-999, -999)
			_choose_wander_direction()
		return
	if is_winding_up:
		windup_remaining -= delta
		velocity = Vector2.ZERO
		if windup_remaining <= 0.0:
			is_winding_up = false
			is_charging = true
			charge_remaining = 0.78 if archetype == Archetype.BOSS else 0.62
			charge_cooldown = 3.2 if archetype == Archetype.BOSS else 2.6
			direction = charge_direction
		return
	if charge_cooldown <= 0.0 and _try_start_charge():
		is_winding_up = true
		windup_remaining = 0.72 if archetype == Archetype.BOSS else 0.48
		direction = charge_direction
		queued_direction = Vector2.ZERO
		last_decision_cell = Vector2i(-999, -999)
		AudioManager.play_enemy_alert()
		return
	_update_regular_movement(true)

func _try_start_charge() -> bool:
	if not is_instance_valid(target_player):
		return false
	var offset: Vector2 = target_player.global_position - global_position
	var candidate_direction: Vector2i = Vector2i.ZERO
	if absf(offset.x) < 8.0 and absf(offset.y) >= 110.0 and absf(offset.y) <= 350.0:
		candidate_direction = Vector2i(0, int(sign(offset.y)))
	elif absf(offset.y) < 8.0 and absf(offset.x) >= 110.0 and absf(offset.x) <= 350.0:
		candidate_direction = Vector2i(int(sign(offset.x)), 0)
	else:
		return false
	var cell: Vector2i = arena_grid.world_to_grid(global_position)
	var target_cell: Vector2i = arena_grid.world_to_grid(target_player.global_position)
	var cursor: Vector2i = cell + candidate_direction
	while cursor != target_cell:
		if not arena_grid.is_in_bounds(cursor) or arena_grid.get_cell_type(cursor) != GameState.CellType.EMPTY or arena_grid.has_bomb_at(cursor) or imminent_danger.has(cursor):
			return false
		cursor += candidate_direction
	charge_direction = Vector2(candidate_direction)
	return true

func _choose_direction() -> void:
	_choose_wander_direction()

func _choose_chase_direction() -> void:
	var chase_dir: Vector2 = _get_chase_direction()
	if chase_dir != Vector2.ZERO:
		direction = chase_dir
		is_chasing = true
	else:
		is_chasing = false
		_choose_wander_direction()

func _choose_escape_direction() -> void:
	if arena_grid == null:
		return
	var start_cell: Vector2i = arena_grid.world_to_grid(global_position)
	var queue: Array[Vector2i] = [start_cell]
	var came_from: Dictionary = {start_cell: start_cell}
	var safe_target: Vector2i = Vector2i(-999, -999)

	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell != start_cell and not imminent_danger.has(cell):
			safe_target = cell
			break

		for step in DIRECTIONS:
			var next_cell: Vector2i = cell + step
			if came_from.has(next_cell) or not arena_grid.is_in_bounds(next_cell):
				continue
			# Pode atravessar células sob ameaça para alcançar a saída segura, mas não paredes ou bombas
			if arena_grid.get_cell_type(next_cell) != GameState.CellType.EMPTY:
				continue
			if arena_grid.has_bomb_at(next_cell):
				continue
			came_from[next_cell] = cell
			queue.append(next_cell)

	if safe_target != Vector2i(-999, -999):
		var step_back: Vector2i = safe_target
		while came_from[step_back] != start_cell:
			step_back = came_from[step_back]
		direction = Vector2(step_back - start_cell)
		is_chasing = false
		last_decision_cell = start_cell
	else:
		# Beco sem saída: afasta-se da bomba mais próxima sem alternar direções repetidamente
		var best_dist: int = -1
		var best_step: Vector2i = Vector2i.ZERO
		for step in DIRECTIONS:
			var candidate: Vector2i = start_cell + step
			if not arena_grid.is_in_bounds(candidate):
				continue
			if arena_grid.get_cell_type(candidate) != GameState.CellType.EMPTY or arena_grid.has_bomb_at(candidate):
				continue
			var min_bomb_dist: int = 1 << 30
			for bomb_cell_variant in arena_grid.active_bombs.keys():
				var b_cell: Vector2i = bomb_cell_variant
				min_bomb_dist = mini(min_bomb_dist, absi(candidate.x - b_cell.x) + absi(candidate.y - b_cell.y))
			if min_bomb_dist > best_dist:
				best_dist = min_bomb_dist
				best_step = step

		if best_step != Vector2i.ZERO:
			direction = Vector2(best_step)
		else:
			direction = Vector2.ZERO
		is_chasing = false
		last_decision_cell = start_cell

func _find_path_direction(start_cell: Vector2i, goals: Array[Vector2i], allow_danger: bool) -> Vector2:
	if goals.is_empty():
		return Vector2.ZERO
	if goals.has(start_cell):
		if is_instance_valid(target_player):
			var diff: Vector2 = target_player.global_position - global_position
			if absf(diff.x) > absf(diff.y) and absf(diff.x) > 1.0:
				return Vector2(sign(diff.x), 0.0)
			elif absf(diff.y) > 1.0:
				return Vector2(0.0, sign(diff.y))
		return direction
	var pending: Array[Vector2i] = [start_cell]
	var came_from: Dictionary = {start_cell: start_cell}
	var found_cell: Vector2i = Vector2i(-1, -1)
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_front()
		if goals.has(cell):
			found_cell = cell
			break
		for step in DIRECTIONS:
			var next_cell: Vector2i = cell + step
			if came_from.has(next_cell) or not arena_grid.is_walkable(next_cell):
				continue
			if not allow_danger and imminent_danger.has(next_cell):
				continue
			came_from[next_cell] = cell
			pending.append(next_cell)
	if found_cell == Vector2i(-1, -1):
		return Vector2.ZERO
	var first_step: Vector2i = found_cell
	while came_from[first_step] != start_cell:
		first_step = came_from[first_step]
	return Vector2(first_step - start_cell).normalized()

func _collect_imminent_danger() -> Dictionary:
	var danger: Dictionary = {}
	if arena_grid == null:
		return danger
	for bomb_cell_variant in arena_grid.active_bombs.keys():
		var bomb_cell: Vector2i = bomb_cell_variant
		var bomb: Bomb = arena_grid.get_bomb_at(bomb_cell)
		if not is_instance_valid(bomb) or bomb.is_detonated:
			continue
		danger[bomb_cell] = true
		var bomb_range: int = bomb.bomb_range
		for step in DIRECTIONS:
			for distance in range(1, bomb_range + 1):
				var flame_cell: Vector2i = bomb_cell + step * distance
				if not arena_grid.is_in_bounds(flame_cell):
					break
				var cell_type: GameState.CellType = arena_grid.get_cell_type(flame_cell)
				if cell_type == GameState.CellType.WALL_INDESTRUCTIBLE:
					break
				danger[flame_cell] = true
				if cell_type == GameState.CellType.BLOCK_DESTRUCTIBLE:
					break
	if arena_grid.explosions_container:
		for exp_child in arena_grid.explosions_container.get_children():
			if exp_child is Explosion:
				danger[exp_child.grid_position] = true
	return danger

func take_bomb_hit() -> void:
	if not is_alive or hurt_invulnerability > 0.0:
		return
	health -= 1
	hurt_invulnerability = HURT_INVULNERABILITY
	queued_direction = Vector2.ZERO
	if health <= 0:
		die()
	else:
		if archetype == Archetype.BOSS:
			_on_boss_damaged()
		velocity = -direction * 110.0
		var flash_strength: float = clampf(GameState.impact_flash_intensity, 0.0, 1.0)
		if GameState.reduced_flashes_enabled:
			flash_strength *= 0.35
		if flash_strength > 0.0:
			modulate = Color(1.0 + flash_strength * 0.8, 1.0 + flash_strength * 0.6, 1.0 + flash_strength * 0.35, 1.0)
			var flash: Tween = create_tween()
			flash.tween_property(self, "modulate", Color.WHITE, GameState.impact_flash_duration)
	_update_appearance()

func freeze_enemy(duration: float = 3.0) -> void:
	if not is_alive:
		return
	freeze_timer = duration
	velocity = Vector2.ZERO
	modulate = Color(0.4, 0.8, 1.4, 1.0)
	_update_appearance()

# ----------------- HABILIDADES EXCLUSIVAS DE CHEFES -----------------

func _update_boss_mechanics(delta: float) -> void:
	if stage_index == 4:
		# Chefe 1 (Fase 5): Golem - Pisotão Sísmico Periódico
		boss_stomp_timer -= delta
		if boss_stomp_timer <= 0.0:
			boss_stomp_timer = 5.5
			_boss_perform_stomp()
	elif stage_index == 11:
		# Chefe 3 (Fase 12): Cronos - Minas Temporais Periódicas
		boss_time_bomb_timer -= delta
		if boss_time_bomb_timer <= 0.0:
			boss_time_bomb_timer = 3.8 if boss_enraged else 5.2
			_boss_drop_time_mine()

func _on_boss_damaged() -> void:
	if stage_index == 4:
		# Golem: Pisotão reativo imediato quebrando blocos ao redor
		_boss_perform_stomp()
	elif stage_index == 9:
		# Espectro: Teletransporte reativo para escapar de armadilhas
		_boss_teleport_away()
		if health <= 2 and not boss_illusion_spawned:
			_boss_spawn_illusion()
	elif stage_index == 11:
		# Cronos: Entra em Fúria com metade da vida
		if health <= 3 and not boss_enraged:
			_boss_trigger_enrage()

## Fase 5: Salto acrobático e Terremoto do Sapo Gigante que treme a tela e destrói blocos adjacentes
func _boss_perform_stomp() -> void:
	if arena_grid == null:
		return
	is_winding_up = true
	var jump_tween: Tween = create_tween()
	jump_tween.tween_property(self, "position:y", position.y - 34.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	jump_tween.tween_property(self, "position:y", position.y, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	jump_tween.tween_callback(func():
		is_winding_up = false
		get_tree().call_group("game_orchestrator", "add_screen_shake", 0.55)
		AudioManager.play_bump()
		var current_cell: Vector2i = arena_grid.world_to_grid(global_position)
		for d in DIRECTIONS:
			var target_c: Vector2i = current_cell + d
			if arena_grid.is_in_bounds(target_c) and arena_grid.get_cell_type(target_c) == GameState.CellType.BLOCK_DESTRUCTIBLE:
				arena_grid.destroy_block_at(target_c, false)
		for diag in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var target_d: Vector2i = current_cell + diag
			if arena_grid.is_in_bounds(target_d) and arena_grid.get_cell_type(target_d) == GameState.CellType.BLOCK_DESTRUCTIBLE:
				arena_grid.destroy_block_at(target_d, false)
		var stomp_tween: Tween = create_tween()
		stomp_tween.tween_property(self, "scale", Vector2(1.35, 0.70), 0.08)
		stomp_tween.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	)

## Fase 10: Teletransporte para uma célula segura distante do jogador
func _boss_teleport_away() -> void:
	if arena_grid == null or not is_instance_valid(target_player):
		return
	var player_cell: Vector2i = arena_grid.world_to_grid(target_player.global_position)
	var candidates: Array[Vector2i] = []
	for x in range(1, ArenaGrid.WIDTH - 1):
		for y in range(1, ArenaGrid.HEIGHT - 1):
			var cell := Vector2i(x, y)
			if arena_grid.is_walkable(cell) and not imminent_danger.has(cell):
				var dist: int = absi(cell.x - player_cell.x) + absi(cell.y - player_cell.y)
				if dist >= 4:
					candidates.append(cell)
	if candidates.is_empty():
		return
	var dest_cell: Vector2i = candidates.pick_random()
	var dest_pos: Vector2 = arena_grid.grid_to_world(dest_cell)
	AudioManager.play_enemy_alert()
	var tp_tween: Tween = create_tween()
	tp_tween.tween_property(self, "scale", Vector2(0.1, 1.8), 0.10)
	tp_tween.tween_property(self, "modulate:a", 0.0, 0.08)
	tp_tween.tween_callback(func():
		global_position = dest_pos
		last_decision_cell = dest_cell
		direction = Vector2.ZERO
		_choose_wander_direction()
	)
	tp_tween.tween_property(self, "scale", Vector2.ONE, 0.14)
	tp_tween.parallel().tween_property(self, "modulate:a", 1.0, 0.14)

## Fase 10: Invoca um lacaio ilusório para proteger o chefe
func _boss_spawn_illusion() -> void:
	boss_illusion_spawned = true
	if arena_grid == null or get_parent() == null:
		return
	var current_cell: Vector2i = arena_grid.world_to_grid(global_position)
	var spawn_cell: Vector2i = Vector2i(-1, -1)
	for d in DIRECTIONS:
		var c: Vector2i = current_cell + d
		if arena_grid.is_walkable(c):
			spawn_cell = c
			break
	if spawn_cell == Vector2i(-1, -1):
		return
	var enemy_scene: PackedScene = load("res://scenes/campaign_enemy.tscn")
	var minion: CampaignEnemy = enemy_scene.instantiate() as CampaignEnemy
	minion.setup(target_player, stage_index, arena_grid, Archetype.WANDERER)
	minion.modulate = Color(0.65, 0.85, 1.3, 0.85)
	minion.global_position = arena_grid.grid_to_world(spawn_cell)
	get_parent().add_child(minion)

## Fase 12: Planta minas temporais de fusível acelerado
func _boss_drop_time_mine() -> void:
	if arena_grid == null:
		return
	var current_cell: Vector2i = arena_grid.world_to_grid(global_position)
	if not arena_grid.is_in_bounds(current_cell) or arena_grid.has_bomb_at(current_cell):
		return
	if arena_grid.get_cell_type(current_cell) != GameState.CellType.EMPTY:
		return
	var mine: Bomb = arena_grid.place_bomb(current_cell, self as CharacterBody2D)
	if mine:
		mine.bomb_range = 2
		mine.fuse_time = 1.6
		if mine.fuse_timer:
			mine.fuse_timer.start(1.6)
		mine.exploded.connect(func(b: Bomb, c: Vector2i, r: int):
			arena_grid.unregister_bomb(c)
			var game = get_tree().get_first_node_in_group("game_orchestrator")
			if game and game.get("bomb_system"):
				game.bomb_system.call("resolve_explosion", b, c, r)
		)
		AudioManager.play_bomb_drop()

## Fase 12: Cronos entra em Fúria Temporal
func _boss_trigger_enrage() -> void:
	boss_enraged = true
	move_speed *= 1.35
	charge_cooldown = 1.4
	get_tree().call_group("game_orchestrator", "add_screen_shake", 0.55)
	AudioManager.play_enemy_alert()
	modulate = Color(1.4, 0.45, 0.35)


func die() -> void:
	if not is_alive:
		return
	is_alive = false
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	defeated.emit(self)

	if appearance and appearance.has_node("EnemySprite"):
		var sprite: Sprite2D = appearance.get_node("EnemySprite") as Sprite2D
		var tween: Tween = create_tween()
		var frame_count: int = BomberAssets.ENEMY_DEATH_FRAMES.size()
		for f in range(frame_count):
			tween.tween_callback(func():
				if is_instance_valid(sprite):
					BomberAssets.configure_enemy_death(sprite, f)
			)
			tween.tween_interval(0.06)
		tween.parallel().tween_property(self, "modulate:a", 0.0, float(frame_count) * 0.06)
		tween.chain().tween_callback(queue_free)
	else:
		var tween: Tween = create_tween()
		tween.tween_property(self, "scale", Vector2.ZERO, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_callback(queue_free)
