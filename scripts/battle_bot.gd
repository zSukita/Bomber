class_name BattleBot
extends CharacterBody2D

## IA para o Modo Batalha — reutiliza a lógica de pathfinding e evasão
## de CampaignEnemy, mas com a interface de Player (solta bombas, coleta itens).

signal bomb_drop_requested(bot: BattleBot, world_pos: Vector2)
signal died(bot: BattleBot)
signal powerup_changed(bot: BattleBot)

const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
const VERTICAL_DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN]
const HORIZONTAL_DIRECTIONS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT]
const HURT_INVULNERABILITY: float = 0.0  # Bots morrem instantaneamente como jogadores

# --- Identidade (compatível com a interface do Player) ---
var peer_id: int = -1          # ID negativo = bot (nunca conflita com peers reais)
var player_name: String = "Bot"
var player_index: int = 0
var target_sync_position: Vector2 = Vector2.ZERO  # compatibilidade de interface

# --- Atributos de partida (espelha Player) ---
var is_alive: bool = true
var max_bombs: int = 1
var active_bombs: int = 0
var bomb_range: int = 2
var has_heart: bool = false
var has_kick: bool = false
var has_pierce: bool = false
var has_remote: bool = false
var skull_curse: int = -1
var skull_timer: float = 0.0
var invulnerability_seconds: float = 0.0
var bomb_buffer_timer: float = 0.0
var speed_multiplier: float = 1.0
var base_speed: float = 130.0
var facing_direction: Vector2 = Vector2.DOWN
var current_direction: Vector2 = Vector2.ZERO

# --- IA ---
var arena_grid: ArenaGrid
var target_player: Player               # alvo principal de perseguição
var all_players: Array[Player] = []     # lista completa para evitar perseguir somente um

var direction: Vector2 = Vector2.DOWN
var direction_timer: float = 0.0
var animation_time: float = 0.0
var last_decision_cell: Vector2i = Vector2i(-999, -999)
var is_chasing: bool = false
var imminent_danger: Dictionary = {}
var danger_refresh: float = 0.0
var bomb_cooldown: float = 1.5        # tempo entre bombas do bot
var bomb_timer: float = 0.0
var stuck_time: float = 0.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visuals_root: Node2D = $Visuals
@onready var name_label: Label = $Visuals/NameLabel

var difficulty: int = 1 # 0: EASY, 1: MEDIUM, 2: HARD

func setup(grid: ArenaGrid, players: Array[Player], bot_peer_id: int, color_idx: int, char_idx: int, p_name: String, diff: int = -1) -> void:
	arena_grid = grid
	all_players = players
	peer_id = bot_peer_id
	player_index = color_idx
	player_name = p_name
	difficulty = diff if diff >= 0 else int(GameState.bot_difficulty)
	match difficulty:
		0: # EASY
			base_speed = 115.0
			bomb_cooldown = 2.4
		1: # MEDIUM
			base_speed = 132.0
			bomb_cooldown = 1.5
		2: # HARD
			base_speed = 148.0
			bomb_cooldown = 0.95
	speed_multiplier = 1.0

func _ready() -> void:
	add_to_group("players")
	add_to_group("bots")
	target_sync_position = global_position
	if visuals_root and visuals_root.has_method("set_skin_color"):
		visuals_root.set_skin_color(Player.PLAYER_COLORS[player_index % Player.PLAYER_COLORS.size()])
	if name_label:
		name_label.text = player_name
	_pick_target()
	_choose_wander_direction()

# ---- Interface compatível com Player (exigida por game.gd) ----
func is_local_player() -> bool:
	return false

func on_bomb_exploded() -> void:
	active_bombs = maxi(0, active_bombs - 1)

func apply_power_up(type: int) -> void:
	match type:
		GameState.PowerUpType.BOMB:
			max_bombs = mini(max_bombs + 1, 8)
		GameState.PowerUpType.RANGE:
			bomb_range = mini(bomb_range + 1, 8)
		GameState.PowerUpType.SPEED:
			speed_multiplier = minf(speed_multiplier + 0.10, 1.8)
		GameState.PowerUpType.HEART:
			has_heart = true
		GameState.PowerUpType.KICK:
			has_kick = true
		GameState.PowerUpType.PIERCE:
			has_pierce = true
		GameState.PowerUpType.REMOTE:
			has_remote = true
		GameState.PowerUpType.SKULL:
			skull_curse = randi_range(0, 2)
			skull_timer = 10.0
	powerup_changed.emit(self)

func respawn(at_position: Vector2, preserve_upgrades: bool = false) -> void:
	global_position = at_position
	target_sync_position = at_position
	is_alive = true
	active_bombs = 0
	if not preserve_upgrades:
		max_bombs = 1
		bomb_range = 2
		speed_multiplier = 1.0
		has_heart = false
		has_kick = false
		has_pierce = false
		has_remote = false
	skull_curse = -1
	skull_timer = 0.0
	invulnerability_seconds = 0.0
	collision_shape.set_deferred("disabled", false)
	if visuals_root:
		visuals_root.rotation = 0.0
		visuals_root.scale = Vector2.ONE
		visuals_root.modulate = Color.WHITE

func update_name_display(new_name: String) -> void:
	player_name = new_name
	if name_label:
		name_label.text = new_name

func set_player_color(index: int) -> void:
	player_index = index
	var color: Color = Player.PLAYER_COLORS[index % Player.PLAYER_COLORS.size()]
	if visuals_root and visuals_root.has_method("set_skin_color"):
		visuals_root.set_skin_color(color)

func set_player_character(index: int) -> void:
	if visuals_root and visuals_root.has_method("set_character"):
		visuals_root.set_character(index)

func die() -> void:
	if not is_alive:
		return
	if invulnerability_seconds > 0.0:
		return
	if has_heart:
		has_heart = false
		invulnerability_seconds = 1.5
		AudioManager.play_powerup()
		powerup_changed.emit(self)
		return
	is_alive = false
	collision_shape.set_deferred("disabled", true)
	AudioManager.play_death()
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(visuals_root, "rotation", deg_to_rad(360.0), 0.5)
	tween.tween_property(visuals_root, "scale", Vector2(0.2, 0.2), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(visuals_root, "modulate:a", 0.0, 0.5)
	died.emit(self)

# ---- Física / IA ----

func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	animation_time += delta
	if invulnerability_seconds > 0.0:
		invulnerability_seconds = maxf(0.0, invulnerability_seconds - delta)

	danger_refresh -= delta
	if danger_refresh <= 0.0:
		imminent_danger = _collect_imminent_danger()
		danger_refresh = 0.15

	bomb_timer = maxf(0.0, bomb_timer - delta)

	_pick_target()
	_update_movement()
	_try_drop_bomb()
	if has_kick:
		_check_bot_kick()

	if visuals_root and visuals_root.has_method("update_state"):
		var is_moving: bool = velocity.length() > 5.0
		visuals_root.update_state(facing_direction, is_moving, is_alive)

func _check_bot_kick() -> void:
	for i in range(get_slide_collision_count()):
		var col: KinematicCollision2D = get_slide_collision(i)
		var collider: Object = col.get_collider()
		if collider is Bomb and not collider.is_sliding:
			var push_dir: Vector2 = facing_direction if facing_direction != Vector2.ZERO else direction
			if push_dir != Vector2.ZERO:
				collider.kick(push_dir)
				AudioManager.play_kick()

## Escolhe o jogador humano mais próximo como alvo (evita perseguir bots).
func _pick_target() -> void:
	var best_dist: float = INF
	var best: Player = null
	for p in all_players:
		if not is_instance_valid(p) or not p.is_alive:
			continue
		var d: float = global_position.distance_to(p.global_position)
		if d < best_dist:
			best_dist = d
			best = p
	target_player = best

func _update_movement() -> void:
	if arena_grid == null:
		return
	var current_cell: Vector2i = arena_grid.world_to_grid(global_position)
	var cell_center: Vector2 = arena_grid.grid_to_world(current_cell)

	# Foge imediatamente de perigo
	if imminent_danger.has(current_cell):
		_choose_escape_direction()
		_move_aligned(base_speed * speed_multiplier)
		return

	if direction == Vector2.ZERO:
		last_decision_cell = current_cell
		global_position = cell_center
		_select_next_direction()

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
		global_position = cell_center
		var forward_step: Vector2i = Vector2i(roundi(direction.x), roundi(direction.y))
		var forward_cell: Vector2i = current_cell + forward_step
		var forward_open: bool = forward_step != Vector2i.ZERO and arena_grid.is_walkable(forward_cell) and not imminent_danger.has(forward_cell)
		var perp_dirs: Array[Vector2i] = VERTICAL_DIRECTIONS if forward_step.x != 0 else HORIZONTAL_DIRECTIONS
		var has_perp: bool = false
		for p in perp_dirs:
			if arena_grid.is_walkable(current_cell + p) and not imminent_danger.has(current_cell + p):
				has_perp = true
				break
		if has_perp or not forward_open:
			_select_next_direction()

	_move_aligned(base_speed * speed_multiplier)

	# Detecção de travamento
	if velocity.length_squared() > 1.0 and global_position.distance_squared_to(cell_center) < 0.5:
		stuck_time += get_physics_process_delta_time()
		if stuck_time >= 0.4:
			stuck_time = 0.0
			last_decision_cell = Vector2i(-999, -999)
			_select_next_direction()
	else:
		stuck_time = 0.0

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
		velocity.y = clampf(diff_y * 12.0, -speed * 0.45, speed * 0.45) if absf(diff_y) > 0.5 else 0.0
	else:
		velocity.y = sign(direction.y) * speed
		var diff_x: float = cell_center.x - global_position.x
		velocity.x = clampf(diff_x * 12.0, -speed * 0.45, speed * 0.45) if absf(diff_x) > 0.5 else 0.0
	var conveyor_vel: Vector2 = arena_grid.get_conveyor_drift(global_position) if arena_grid else Vector2.ZERO
	if arena_grid and ArenaMapStyles.is_ice_map(arena_grid.map_style):
		velocity = velocity.lerp(velocity + conveyor_vel, clampf(get_physics_process_delta_time() * 4.5, 0.0, 1.0))
	else:
		velocity += conveyor_vel
	if direction.x != 0.0:
		facing_direction = Vector2(sign(direction.x), 0.0)
	else:
		facing_direction = Vector2(0.0, sign(direction.y))
	current_direction = direction
	move_and_slide()

func _select_next_direction() -> void:
	if arena_grid == null:
		return
	var current_cell: Vector2i = arena_grid.world_to_grid(global_position)
	if imminent_danger.has(current_cell):
		_choose_escape_direction()
		return

	if is_instance_valid(target_player) and target_player.is_alive:
		var dist: float = global_position.distance_to(target_player.global_position)
		if dist <= (640.0 if is_chasing else 480.0):
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
	var goals: Array[Vector2i] = []
	if not imminent_danger.has(goal_cell):
		goals.append(goal_cell)
	else:
		for step in DIRECTIONS:
			var neighbor: Vector2i = goal_cell + step
			if arena_grid.is_walkable(neighbor) and not imminent_danger.has(neighbor):
				goals.append(neighbor)
	if goals.is_empty():
		return Vector2.ZERO
	return _find_path_direction(start_cell, goals)

func _choose_wander_direction() -> void:
	if arena_grid == null:
		direction = Vector2.ZERO
		return
	var current_cell: Vector2i = arena_grid.world_to_grid(global_position)
	var all_safe: Array[Vector2i] = []
	for step in DIRECTIONS:
		var neighbor: Vector2i = current_cell + step
		if arena_grid.is_walkable(neighbor) and not imminent_danger.has(neighbor):
			all_safe.append(step)
	if all_safe.is_empty():
		_choose_escape_direction()
		return
	var forward_step: Vector2i = Vector2i(roundi(direction.x), roundi(direction.y)) if direction != Vector2.ZERO else Vector2i.ZERO
	var reverse_step: Vector2i = -forward_step if forward_step != Vector2i.ZERO else Vector2i.ZERO
	var forward_open: bool = all_safe.has(forward_step)
	var perp_steps: Array[Vector2i] = []
	for s in all_safe:
		if s != forward_step and s != reverse_step:
			perp_steps.append(s)
	if forward_open and not perp_steps.is_empty():
		direction = Vector2(forward_step if randf() < 0.65 else perp_steps.pick_random())
	elif forward_open:
		direction = Vector2(forward_step)
	elif not perp_steps.is_empty():
		direction = Vector2(perp_steps.pick_random())
	elif all_safe.has(reverse_step):
		direction = Vector2(reverse_step)
	else:
		direction = Vector2(all_safe.pick_random())

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

func _find_path_direction(start_cell: Vector2i, goals: Array[Vector2i]) -> Vector2:
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
			if imminent_danger.has(next_cell):
				continue
			came_from[next_cell] = cell
			pending.append(next_cell)
	if found_cell == Vector2i(-1, -1):
		return Vector2.ZERO
	var first_step: Vector2i = found_cell
	while came_from[first_step] != start_cell:
		first_step = came_from[first_step]
	return Vector2(first_step - start_cell).normalized()

## Decide se e quando soltar uma bomba.
func _try_drop_bomb() -> void:
	if bomb_timer > 0.0 or active_bombs >= max_bombs or not is_alive:
		return
	if arena_grid == null:
		return
	var current_cell: Vector2i = arena_grid.world_to_grid(global_position)
	# Não planta bomba se a célula atual já é perigosa
	if imminent_danger.has(current_cell):
		return
	# Planta se o alvo estiver no mesmo corredor e perto
	if is_instance_valid(target_player) and target_player.is_alive:
		var tc: Vector2i = arena_grid.world_to_grid(target_player.global_position)
		var in_line: bool = tc.x == current_cell.x or tc.y == current_cell.y
		var dist: int = absi(tc.x - current_cell.x) + absi(tc.y - current_cell.y)
		if in_line and dist <= bomb_range + 1:
			# Verifica se há rota de escape após plantar
			if _has_escape_after_bomb(current_cell):
				bomb_drop_requested.emit(self, global_position)
				bomb_timer = bomb_cooldown
				return
	# Planta aleatoriamente perto de blocos para abrir o mapa
	var near_block: bool = false
	for step in DIRECTIONS:
		if arena_grid.get_cell_type(current_cell + step) == GameState.CellType.BLOCK_DESTRUCTIBLE:
			near_block = true
			break
	if near_block and randf() < 0.04 and _has_escape_after_bomb(current_cell):
		bomb_drop_requested.emit(self, global_position)
		bomb_timer = bomb_cooldown

## Verifica se existe pelo menos uma rota de fuga segura se plantar uma bomba aqui.
func _has_escape_after_bomb(bomb_cell: Vector2i) -> bool:
	if arena_grid == null:
		return false
	var fake_danger: Dictionary = imminent_danger.duplicate()
	fake_danger[bomb_cell] = true
	for step in DIRECTIONS:
		for dist in range(1, bomb_range + 1):
			var flame_cell: Vector2i = bomb_cell + step * dist
			if not arena_grid.is_in_bounds(flame_cell):
				break
			var ct: GameState.CellType = arena_grid.get_cell_type(flame_cell)
			if ct == GameState.CellType.WALL_INDESTRUCTIBLE:
				break
			fake_danger[flame_cell] = true
			if ct == GameState.CellType.BLOCK_DESTRUCTIBLE:
				break
	var current_cell: Vector2i = arena_grid.world_to_grid(global_position)
	for step in DIRECTIONS:
		var neighbor: Vector2i = current_cell + step
		if arena_grid.is_walkable(neighbor) and not fake_danger.has(neighbor):
			return true
	return false

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
		var b_range: int = bomb.bomb_range
		for step in DIRECTIONS:
			for distance in range(1, b_range + 1):
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
