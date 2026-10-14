class_name CampaignEnemy
extends CharacterBody2D

signal defeated(enemy: CampaignEnemy)

enum Archetype { WANDERER, HUNTER, CHARGER, BOSS }

const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
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

@onready var appearance: Node2D = $Appearance

func setup(target: Player, stage_index: int, grid: ArenaGrid, selected_archetype: int = Archetype.WANDERER) -> void:
	target_player = target
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
			move_speed = 62.0 + stage_level * 2.0
			max_health = 4
	health = max_health
	if archetype == Archetype.BOSS:
		var shape: CircleShape2D = $CollisionShape2D.shape.duplicate() as CircleShape2D
		shape.radius = 23.0
		$CollisionShape2D.shape = shape

func _ready() -> void:
	add_to_group("enemies")
	_choose_direction()
	if arena_grid:
		last_decision_cell = arena_grid.world_to_grid(global_position)
	_update_appearance()

func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	var frame_start_position: Vector2 = global_position
	animation_time += delta
	direction_timer -= delta
	hurt_invulnerability = maxf(0.0, hurt_invulnerability - delta)
	charge_cooldown = maxf(0.0, charge_cooldown - delta)
	danger_refresh -= delta
	escape_refresh -= delta
	if danger_refresh <= 0.0:
		imminent_danger = _collect_imminent_danger()
		danger_refresh = 0.12

	var player_is_valid: bool = is_instance_valid(target_player) and target_player.is_alive
	var current_cell: Vector2i = arena_grid.world_to_grid(global_position) if arena_grid else Vector2i.ZERO
	var next_cell: Vector2i = arena_grid.world_to_grid(global_position + direction * 30.0) if arena_grid else current_cell
	var path_is_dangerous: bool = imminent_danger.has(current_cell) or imminent_danger.has(next_cell)
	if path_is_dangerous:
		if is_charging or is_winding_up:
			is_charging = false
			is_winding_up = false
			charge_remaining = 0.0
			windup_remaining = 0.0
			charge_cooldown = 0.8
		if escape_refresh <= 0.0:
			queued_direction = Vector2.ZERO
			last_decision_cell = Vector2i(-999, -999)
			_choose_escape_direction()
			escape_refresh = 0.12

	if (archetype == Archetype.CHARGER or archetype == Archetype.BOSS) and player_is_valid:
		_update_charger(delta)
	else:
		_update_regular_movement(player_is_valid)
	if velocity.length_squared() > 1.0 and global_position.distance_squared_to(frame_start_position) < 1.0:
		stuck_time += delta
		if stuck_time >= 0.4:
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
	if arena_grid != null:
		var current_cell: Vector2i = arena_grid.world_to_grid(global_position)
		var cell_center: Vector2 = arena_grid.grid_to_world(current_cell)

		# Se estiver sem direção ou parado, seleciona direção imediatamente para nunca ficar congelado
		if direction == Vector2.ZERO:
			_select_next_direction(player_is_valid)
			last_decision_cell = current_cell

		# Verifica se o monstro está no centro da casa
		var is_at_center: bool = false
		if direction == Vector2.ZERO:
			is_at_center = true
		elif absf(direction.x) > 0.0:
			is_at_center = absf(cell_center.x - global_position.x) <= 4.0 and absf(cell_center.y - global_position.y) <= 6.0
		else:
			is_at_center = absf(cell_center.y - global_position.y) <= 4.0 and absf(cell_center.x - global_position.x) <= 6.0

		if is_at_center and current_cell != last_decision_cell:
			last_decision_cell = current_cell

			# Avalia opções a partir da casa atual
			var forward_step: Vector2i = Vector2i(direction)
			var forward_cell: Vector2i = current_cell + forward_step
			var forward_open: bool = direction != Vector2.ZERO and arena_grid.is_walkable(forward_cell) and not imminent_danger.has(forward_cell)

			var has_perp_turn: bool = false
			var perp_dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN] if forward_step.x != 0 else [Vector2i.LEFT, Vector2i.RIGHT]
			for p in perp_dirs:
				var side_cell: Vector2i = current_cell + p
				if arena_grid.is_walkable(side_cell) and not imminent_danger.has(side_cell):
					has_perp_turn = true
					break

			# Cruzamento: há curvas perpendiculares OU o caminho em frente está bloqueado/perigoso
			var is_intersection: bool = has_perp_turn or not forward_open

			if is_intersection:
				var old_dir: Vector2 = direction
				_select_next_direction(player_is_valid)
				if direction != old_dir:
					if absf(direction.x) > 0.0:
						global_position.y = cell_center.y
					else:
						global_position.x = cell_center.x
			else:
				# Corredor reto sem curvas: mantém a direção para não mudar de rota no meio do corredor.
				# Apenas se estiver perseguindo e o jogador ficou para trás no mesmo corredor, inverte a marcha.
				if is_chasing and player_is_valid:
					var chase_dir: Vector2 = _get_chase_direction()
					if chase_dir != Vector2.ZERO and chase_dir == -direction:
						direction = -direction
						if absf(direction.x) > 0.0:
							global_position.y = cell_center.y
						else:
							global_position.x = cell_center.x

	_move_aligned(move_speed)
	if get_slide_collision_count() > 0:
		last_decision_cell = Vector2i(-999, -999)
		_select_next_direction(player_is_valid)

func _select_next_direction(player_is_valid: bool) -> void:
	if player_is_valid:
		var dist: float = global_position.distance_to(target_player.global_position)
		var can_chase: bool = false
		if archetype == Archetype.HUNTER:
			can_chase = dist <= (720.0 if is_chasing else 640.0)
		elif archetype == Archetype.WANDERER:
			# Perseguição consistente com histerese (240px entrada, 300px saída) para evitar alternâncias rápidas
			can_chase = dist <= (300.0 if is_chasing else 240.0)

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
	var all_safe_steps: Array[Vector2i] = []
	for step in DIRECTIONS:
		var neighbor: Vector2i = current_cell + step
		if arena_grid.is_walkable(neighbor) and not imminent_danger.has(neighbor):
			all_safe_steps.append(step)

	if all_safe_steps.is_empty():
		direction = Vector2.ZERO
		return

	var forward_step: Vector2i = Vector2i(direction) if direction != Vector2.ZERO else Vector2i.ZERO
	var reverse_step: Vector2i = -forward_step if forward_step != Vector2i.ZERO else Vector2i.ZERO

	var forward_open: bool = all_safe_steps.has(forward_step)
	var perp_steps: Array[Vector2i] = []
	for step in all_safe_steps:
		if step != forward_step and step != reverse_step:
			perp_steps.append(step)

	if forward_open and not perp_steps.is_empty():
		# Em cruzamentos: 55% de manter em frente para circular naturalmente o mapa, 45% de virar em bifurcações
		if randf() < 0.55:
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

## Corrige o eixo perpendicular antes de seguir a direção da grade.
## Isso impede que a troca de direção corte a quina entre dois blocos.
func _move_aligned(speed: float) -> void:
	if arena_grid == null or direction == Vector2.ZERO:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var current_cell: Vector2i = arena_grid.world_to_grid(global_position)
	var cell_center: Vector2 = arena_grid.grid_to_world(current_cell)
	if absf(direction.x) > 0.0:
		var vertical_error: float = cell_center.y - global_position.y
		if absf(vertical_error) > 2.0:
			velocity = Vector2(0.0, sign(vertical_error) * speed)
		else:
			velocity = Vector2(sign(direction.x) * speed, 0.0)
	else:
		var horizontal_error: float = cell_center.x - global_position.x
		if absf(horizontal_error) > 2.0:
			velocity = Vector2(sign(horizontal_error) * speed, 0.0)
		else:
			velocity = Vector2(0.0, sign(direction.y) * speed)
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
		_choose_direction()
		return
	var start_cell: Vector2i = arena_grid.world_to_grid(global_position)
	var pending: Array[Vector2i] = [start_cell]
	var came_from: Dictionary = {start_cell: start_cell}
	var distance_from_start: Dictionary = {start_cell: 0}
	var first_step: Dictionary = {}
	var best_direction: Vector2 = Vector2.ZERO
	var best_safety: int = -1
	var best_path_length: int = 1 << 30
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_front()
		var path_length: int = distance_from_start[cell]
		if cell != start_cell and not imminent_danger.has(cell):
			var nearest_danger: int = 1 << 30
			for danger_cell_variant in imminent_danger.keys():
				var danger_cell: Vector2i = danger_cell_variant
				nearest_danger = mini(nearest_danger, absi(cell.x - danger_cell.x) + absi(cell.y - danger_cell.y))
			if nearest_danger > best_safety or (nearest_danger == best_safety and path_length < best_path_length):
				best_safety = nearest_danger
				best_path_length = path_length
				best_direction = first_step[cell]
		for step in DIRECTIONS:
			var next_cell: Vector2i = cell + step
			if came_from.has(next_cell) or not arena_grid.is_walkable(next_cell) or imminent_danger.has(next_cell):
				continue
			came_from[next_cell] = cell
			distance_from_start[next_cell] = path_length + 1
			first_step[next_cell] = Vector2(step) if cell == start_cell else first_step[cell]
			pending.append(next_cell)
	if best_direction != Vector2.ZERO:
		direction = best_direction
		direction_timer = 0.12
		is_chasing = false
		last_decision_cell = Vector2i(-999, -999)
	else:
		var fallback_directions: Array[Vector2i] = []
		var fallback_safety: int = -1
		for step in DIRECTIONS:
			var next_cell: Vector2i = start_cell + step
			if not arena_grid.is_walkable(next_cell):
				continue
			var nearest_danger: int = 1 << 30
			for danger_cell_variant in imminent_danger.keys():
				var danger_cell: Vector2i = danger_cell_variant
				nearest_danger = mini(nearest_danger, absi(next_cell.x - danger_cell.x) + absi(next_cell.y - danger_cell.y))
			if nearest_danger > fallback_safety:
				fallback_safety = nearest_danger
				fallback_directions.clear()
				fallback_directions.append(step)
			elif nearest_danger == fallback_safety:
				fallback_directions.append(step)
		direction = Vector2(fallback_directions.pick_random()) if not fallback_directions.is_empty() else Vector2.ZERO
		direction_timer = 0.12
		is_chasing = false
		last_decision_cell = Vector2i(-999, -999)

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
		velocity = -direction * 110.0
		var flash_strength: float = clampf(GameState.impact_flash_intensity, 0.0, 1.0)
		if GameState.reduced_flashes_enabled:
			flash_strength *= 0.35
		if flash_strength > 0.0:
			modulate = Color(1.0 + flash_strength * 0.8, 1.0 + flash_strength * 0.6, 1.0 + flash_strength * 0.35, 1.0)
			var flash: Tween = create_tween()
			flash.tween_property(self, "modulate", Color.WHITE, GameState.impact_flash_duration)
	_update_appearance()

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
