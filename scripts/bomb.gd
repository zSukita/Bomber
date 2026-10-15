class_name Bomb
extends StaticBody2D

## Representa a bomba no jogo Bombástico.
## Gerencia o pavio (tempo até detonação), pulsação visual,
## reação em cadeia e colisão inteligente (permite que o jogador saia de cima dela antes de bloquear).

signal exploded(bomb_node: Bomb, cell: Vector2i, range: int)

@export var fuse_time: float = 2.5
var bomb_range: int = 2
var grid_position: Vector2i = Vector2i.ZERO
var owner_player: CharacterBody2D

var is_detonated: bool = false
var is_sliding: bool = false
var is_pierce: bool = false
var is_remote: bool = false
var element_type: int = 0 # 0: NORMAL, 1: ICE, 2: THUNDER
var slide_direction: Vector2 = Vector2.ZERO
var slide_speed: float = 380.0
var grid_map: ArenaGrid
var overlapping_players: Array[CharacterBody2D] = []

@onready var fuse_timer: Timer = $FuseTimer
@onready var exit_detector: Area2D = $ExitDetector
@onready var visual_root: Node2D = $Visuals
var pulse_tween: Tween

func _ready() -> void:
	if not grid_map:
		grid_map = get_tree().get_first_node_in_group("grid_map") as ArenaGrid
	fuse_timer.wait_time = fuse_time
	fuse_timer.timeout.connect(_on_fuse_timeout)
	if not is_remote:
		fuse_timer.start()
	else:
		visual_root.modulate = Color(1.25, 0.5, 0.5, 1.0)
	if is_pierce:
		visual_root.modulate = Color(1.3, 1.2, 0.4, 1.0)
	if element_type == 1:
		visual_root.modulate = Color(0.4, 0.9, 1.6, 1.0)
	elif element_type == 2:
		visual_root.modulate = Color(1.4, 1.4, 0.3, 1.0)
	
	if exit_detector:
		exit_detector.body_exited.connect(_on_body_exited_exit_detector)
	
	_setup_collision_exceptions()
	_start_pulse_animation()

## Configura as exceções de colisão com os jogadores que estão no tile da bomba no momento da criação
func _setup_collision_exceptions() -> void:
	# 1. Se o dono da bomba foi definido, adiciona exceção imediatamente
	if is_instance_valid(owner_player):
		_add_player_exception(owner_player)
	
	# 2. Verifica se qualquer outro jogador está pisando no mesmo ladrilho
	var players: Array[Node] = get_tree().get_nodes_in_group("players")
	for node in players:
		if node is CharacterBody2D and is_instance_valid(node):
			if global_position.distance_to(node.global_position) < 40.0:
				_add_player_exception(node)

func _add_player_exception(player: CharacterBody2D) -> void:
	if not is_instance_valid(player) or player in overlapping_players:
		return
	overlapping_players.append(player)
	player.add_collision_exception_with(self)
	add_collision_exception_with(player)

func _remove_player_exception(player: CharacterBody2D) -> void:
	if is_instance_valid(player):
		player.remove_collision_exception_with(self)
		remove_collision_exception_with(player)
	overlapping_players.erase(player)

func _physics_process(delta: float) -> void:
	if not overlapping_players.is_empty():
		# Monitora a distância de cada jogador sobre a bomba.
		# Quando o jogador se afasta do centro da bomba (sai do ladrilho da bomba),
		# remove a exceção para que a bomba se torne um obstáculo sólido intransponível.
		for i in range(overlapping_players.size() - 1, -1, -1):
			var player: CharacterBody2D = overlapping_players[i]
			if not is_instance_valid(player):
				overlapping_players.remove_at(i)
				continue
			
			var dist: float = global_position.distance_to(player.global_position)
			if dist > 34.0:
				_remove_player_exception(player)

	if is_sliding and not is_detonated:
		var move_step: Vector2 = slide_direction * slide_speed * delta
		global_position += move_step
		
		if grid_map:
			var curr_cell: Vector2i = grid_map.world_to_grid(global_position)
			if curr_cell != grid_position:
				if grid_map.has_bomb_at(grid_position) and grid_map.get_bomb_at(grid_position) == self:
					grid_map.unregister_bomb(grid_position)
				grid_position = curr_cell
				grid_map.active_bombs[grid_position] = self
			
			var next_cell: Vector2i = grid_position + Vector2i(int(slide_direction.x), int(slide_direction.y))
			var cell_center: Vector2 = grid_map.grid_to_world(grid_position)
			
			var to_center: Vector2 = cell_center - global_position
			var passed_center: bool = to_center.dot(slide_direction) <= 0.0
			
			if passed_center and _is_cell_blocked_for_sliding(next_cell):
				is_sliding = false
				global_position = cell_center
				AudioManager.play_bump()

## Chuta a bomba na direção ortogonal indicada
func kick(dir: Vector2) -> void:
	if is_detonated or is_sliding:
		return
	if abs(dir.x) > abs(dir.y):
		slide_direction = Vector2(sign(dir.x), 0)
	else:
		slide_direction = Vector2(0, sign(dir.y))
	
	if slide_direction == Vector2.ZERO:
		return
	
	if grid_map:
		var next_cell: Vector2i = grid_position + Vector2i(int(slide_direction.x), int(slide_direction.y))
		if _is_cell_blocked_for_sliding(next_cell):
			AudioManager.play_bump()
			return
	
	is_sliding = true
	AudioManager.play_kick()
	_clear_all_exceptions()

func _is_cell_blocked_for_sliding(cell: Vector2i) -> bool:
	if not grid_map:
		return true
	if not grid_map.is_in_bounds(cell):
		return true
	var cell_type: GameState.CellType = grid_map.get_cell_type(cell)
	if cell_type != GameState.CellType.EMPTY:
		return true
	if grid_map.has_bomb_at(cell) and grid_map.get_bomb_at(cell) != self:
		return true
	var players: Array[Node] = get_tree().get_nodes_in_group("players")
	for p in players:
		if p is CharacterBody2D and is_instance_valid(p) and p.get("is_alive") == true:
			var p_cell: Vector2i = grid_map.world_to_grid(p.global_position)
			if p_cell == cell:
				return true
	var enemies: Array[Node] = get_tree().get_nodes_in_group("campaign_enemies")
	for e in enemies:
		if is_instance_valid(e) and e.get("is_alive") == true:
			var e_cell: Vector2i = grid_map.world_to_grid(e.global_position)
			if e_cell == cell:
				return true
	return false

func _process(_delta: float) -> void:
	if is_detonated or not fuse_timer:
		return
	
	# Efeito visual de contagem regressiva crítica nos últimos 0.8s
	var time_left: float = fuse_timer.time_left
	if time_left < 0.8:
		var flash: float = sin((0.8 - time_left) * 28.0) * 0.5 + 0.5
		var flash_strength: float = 0.9 if not GameState.reduced_flashes_enabled else 0.22
		visual_root.modulate = Color(1.0 + flash * flash_strength, 1.0 - flash * flash_strength * 0.44, 1.0 - flash * flash_strength * 0.44, 1.0)

## Quando um jogador sai fisicamente da área da bomba detectada pelo ExitDetector
func _on_body_exited_exit_detector(body: Node2D) -> void:
	if body is CharacterBody2D and body in overlapping_players:
		_remove_player_exception(body)

## Animação rítmica de pulso da bomba
func _start_pulse_animation() -> void:
	pulse_tween = create_tween().set_loops()
	pulse_tween.tween_property(visual_root, "scale", Vector2(1.12, 1.12), 0.25).set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(visual_root, "scale", Vector2(0.96, 0.96), 0.25).set_trans(Tween.TRANS_SINE)

func _on_fuse_timeout() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		# A réplica visual aguarda o evento autoritativo do servidor.
		return
	detonate()

func _clear_all_exceptions() -> void:
	for player in overlapping_players:
		if is_instance_valid(player):
			player.remove_collision_exception_with(self)
			remove_collision_exception_with(player)
	overlapping_players.clear()

## Detona a bomba (pelo timer ou por reação em cadeia)
func detonate() -> void:
	if is_detonated:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	is_detonated = true
	
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()
	
	fuse_timer.stop()
	_clear_all_exceptions()
	
	exploded.emit(self, grid_position, bomb_range)
	queue_free()

func remove_replica() -> void:
	is_detonated = true
	if fuse_timer:
		fuse_timer.stop()
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()
	queue_free()

func _exit_tree() -> void:
	_clear_all_exceptions()
