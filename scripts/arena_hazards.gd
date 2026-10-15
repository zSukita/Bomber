class_name ArenaHazards
extends Node2D

## Gerenciador de Elementos e Perigos Dinâmicos da Arena.
## Suporta:
## - Esteiras rolantes (Usina Eletrizante - Estilo 5): empurram jogadores e bombas.
## - Blocos e lajes desabantes (Ruínas do Deserto - Estilo 6): aviso de tremor e queda de escombros.
## - Fissuras de magma / Vents vulcânicos (Vulcão Ardente - Estilo 7): áreas perigosas temporárias com aviso prévio.

const TILE_SIZE: float = 64.0
const CONVEYOR_SPEED: float = 72.0

enum HazardEvent {
	VENT_WARNING = 0,
	VENT_ERUPT = 1,
	VENT_COOLDOWN = 2,
	RUBBLE_WARNING = 3,
	RUBBLE_COLLAPSE = 4
}

enum VentState {
	DORMANT = 0,
	WARNING = 1,
	ERUPTING = 2,
	COOLDOWN = 3
}

enum RubbleState {
	INACTIVE = 0,
	WARNING = 1,
	COLLAPSED = 2
}

var grid: ArenaGrid
var map_style: int = 0
var map_seed: int = 0
var animation_time: float = 0.0

# Esteiras: Vector2i -> Vector2 (direção de empuxo)
var conveyors: Dictionary = {}
var bomb_conveyor_dwell: Dictionary = {} # Bomb -> float

# Vents de Magma (Estilo 7): Lista de Dictionaries
var magma_vents: Array[Dictionary] = []

# Ruínas Desabantes (Estilo 6): Lista de Dictionaries
var rubble_hazards: Array[Dictionary] = []
var rubble_cycle_timer: float = 9.0

func _ready() -> void:
	z_index = -1 # Acima do piso (FloorRenderer z_index -2), abaixo de jogadores e bombas

func clear_hazards() -> void:
	conveyors.clear()
	bomb_conveyor_dwell.clear()
	magma_vents.clear()
	rubble_hazards.clear()
	rubble_cycle_timer = 9.0
	queue_redraw()

func setup(arena_grid: ArenaGrid, style: int, seed_value: int) -> void:
	grid = arena_grid
	map_style = posmod(style, ArenaMapStyles.NAMES.size())
	map_seed = seed_value
	clear_hazards()

	match map_style:
		5: # Usina Eletrizante: Esteiras Rolantes
			_setup_conveyors()
		6: # Ruínas do Deserto: Blocos e Escombros Desabantes
			_setup_rubble_hazards()
		7: # Vulcão Ardente: Fissuras de Magma / Vents Vulcânicos
			_setup_magma_vents()

	queue_redraw()

# ----------------- CONFIGURAÇÃO DE ESTEIRAS (ESTILO 5) -----------------

func _setup_conveyors() -> void:
	conveyors.clear()
	# Cria esteiras em dois corredores estratégicos (linha 3 e linha 9)
	# evitando áreas de spawn e pilares
	for x in range(3, 12):
		if x != 7: # Deixa o cruzamento central livre para manobras
			var cell_top := Vector2i(x, 3)
			if _is_cell_valid_for_conveyor(cell_top):
				conveyors[cell_top] = Vector2.RIGHT

			var cell_bottom := Vector2i(x, 9)
			if _is_cell_valid_for_conveyor(cell_bottom):
				conveyors[cell_bottom] = Vector2.LEFT

	# Conectores verticais curtos nas colunas 5 e 9 (linhas 5 a 7)
	for y in range(5, 8):
		var cell_left := Vector2i(4, y)
		if _is_cell_valid_for_conveyor(cell_left):
			conveyors[cell_left] = Vector2.DOWN
		var cell_right := Vector2i(10, y)
		if _is_cell_valid_for_conveyor(cell_right):
			conveyors[cell_right] = Vector2.UP

func _is_cell_valid_for_conveyor(cell: Vector2i) -> bool:
	if not grid:
		return false
	if cell in ArenaMapGenerator.RESERVED_TILES:
		return false
	if ArenaMapStyles.is_pillar(cell, map_style):
		return false
	return true

func get_conveyor_direction(cell: Vector2i) -> Vector2:
	return conveyors.get(cell, Vector2.ZERO)

func get_conveyor_drift(world_pos: Vector2) -> Vector2:
	if not grid or conveyors.is_empty():
		return Vector2.ZERO
	var cell: Vector2i = grid.world_to_grid(world_pos)
	if conveyors.has(cell):
		return conveyors[cell] * CONVEYOR_SPEED
	return Vector2.ZERO

# ----------------- CONFIGURAÇÃO DE VENTS DE MAGMA (ESTILO 7) -----------------

func _setup_magma_vents() -> void:
	magma_vents.clear()
	# 4 vents simétricos em posições abertas da arena vulcânica
	var vent_cells: Array[Vector2i] = [
		Vector2i(3, 4),
		Vector2i(11, 4),
		Vector2i(3, 8),
		Vector2i(11, 8)
	]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = map_seed + 777

	for i in range(vent_cells.size()):
		var cell: Vector2i = vent_cells[i]
		# Escalonamento suave para que os vents não entrem em erupção todos ao mesmo tempo
		var initial_delay: float = float(i) * 2.2 + rng.randf_range(0.0, 1.5)
		magma_vents.append({
			"cell": cell,
			"state": VentState.DORMANT,
			"timer": 6.5 + initial_delay,
			"warning_duration": 2.0,
			"erupt_duration": 1.8,
			"dormant_duration": 8.0,
			"cooldown_duration": 1.2
		})

# ----------------- CONFIGURAÇÃO DE RUÍNAS DESABANTES (ESTILO 6) -----------------

func _setup_rubble_hazards() -> void:
	rubble_hazards.clear()
	rubble_cycle_timer = 9.0

func _pick_rubble_target_cells() -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	if not grid:
		return candidates
	for x in range(3, ArenaGrid.WIDTH - 3):
		for y in range(3, ArenaGrid.HEIGHT - 3):
			var cell := Vector2i(x, y)
			if cell in ArenaMapGenerator.RESERVED_TILES:
				continue
			if ArenaMapStyles.is_pillar(cell, map_style):
				continue
			candidates.append(cell)
	candidates.shuffle()
	var selected: Array[Vector2i] = []
	if not candidates.is_empty():
		selected.append(candidates[0])
	if candidates.size() > 1:
		selected.append(candidates[1])
	return selected

# ----------------- ATUALIZAÇÃO FÍSICA E EVENTOS -----------------

func _physics_process(delta: float) -> void:
	animation_time += delta
	if not grid:
		return

	# Apenas o servidor (ou modo local sem peer) avança a lógica de dano e ciclo dos perigos
	var is_server_authority: bool = not multiplayer.has_multiplayer_peer() or multiplayer.is_server()

	if is_server_authority:
		if not conveyors.is_empty():
			_process_conveyor_bombs(delta)
		if not magma_vents.is_empty():
			_process_magma_vents(delta)
		if map_style == 6:
			_process_rubble_hazards(delta)

	queue_redraw()

func _process_conveyor_bombs(delta: float) -> void:
	if not grid:
		return
	var bombs: Array[Node] = get_tree().get_nodes_in_group("bombs")
	for b in bombs:
		var bomb := b as Bomb
		if not is_instance_valid(bomb) or bomb.is_detonated or bomb.is_sliding:
			bomb_conveyor_dwell.erase(bomb)
			continue

		var cell: Vector2i = bomb.grid_position
		if conveyors.has(cell):
			var dwell: float = bomb_conveyor_dwell.get(bomb, 0.0) + delta
			bomb_conveyor_dwell[bomb] = dwell
			if dwell >= 0.40: # Pequena folga para o jogador sair ao colocar
				var dir: Vector2 = conveyors[cell]
				var dir_i: Vector2i = Vector2i(roundi(dir.x), roundi(dir.y))
				var next_cell: Vector2i = cell + dir_i
				if grid.is_in_bounds(next_cell) and grid.get_cell_type(next_cell) == GameState.CellType.EMPTY and not grid.has_bomb_at(next_cell):
					bomb.kick(dir)
					_sync_conveyor_bomb_kick(cell, dir)
					bomb_conveyor_dwell[bomb] = 0.0
		else:
			bomb_conveyor_dwell.erase(bomb)

func _process_magma_vents(delta: float) -> void:
	for vent in magma_vents:
		vent["timer"] -= delta
		var state: int = vent["state"]
		var cell: Vector2i = vent["cell"]

		match state:
			VentState.DORMANT:
				if vent["timer"] <= 0.0:
					vent["state"] = VentState.WARNING
					vent["timer"] = vent["warning_duration"]
					_emit_hazard_event(HazardEvent.VENT_WARNING, cell)
			VentState.WARNING:
				if vent["timer"] <= 0.0:
					vent["state"] = VentState.ERUPTING
					vent["timer"] = vent["erupt_duration"]
					_emit_hazard_event(HazardEvent.VENT_ERUPT, cell)
					_apply_vent_damage(cell)
			VentState.ERUPTING:
				_apply_vent_damage(cell)
				if vent["timer"] <= 0.0:
					vent["state"] = VentState.COOLDOWN
					vent["timer"] = vent["cooldown_duration"]
					_emit_hazard_event(HazardEvent.VENT_COOLDOWN, cell)
			VentState.COOLDOWN:
				if vent["timer"] <= 0.0:
					vent["state"] = VentState.DORMANT
					vent["timer"] = vent["dormant_duration"]

func _apply_vent_damage(cell: Vector2i) -> void:
	if not grid:
		return
	# Detona bombas sobre o respiradouro
	if grid.has_bomb_at(cell):
		var bomb: Bomb = grid.get_bomb_at(cell)
		if is_instance_valid(bomb) and not bomb.is_detonated:
			bomb.detonate()

	# Aplica dano a jogadores no tile
	var players: Array[Node] = get_tree().get_nodes_in_group("players")
	for p in players:
		if is_instance_valid(p) and p.get("is_alive") == true:
			var p_cell: Vector2i = grid.world_to_grid(p.global_position)
			if p_cell == cell:
				if p.has_method("die"):
					p.die()

	# Aplica dano a inimigos no tile
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and e.get("is_alive") == true:
			var e_cell: Vector2i = grid.world_to_grid(e.global_position)
			if e_cell == cell:
				if e.has_method("take_bomb_hit"):
					e.take_bomb_hit()

func _process_rubble_hazards(delta: float) -> void:
	# Atualiza perigos de escombros ativos
	for i in range(rubble_hazards.size() - 1, -1, -1):
		var rub: Dictionary = rubble_hazards[i]
		rub["timer"] -= delta
		if rub["state"] == RubbleState.WARNING and rub["timer"] <= 0.0:
			rub["state"] = RubbleState.COLLAPSED
			var cell: Vector2i = rub["cell"]
			_trigger_rubble_collapse(cell)
			rubble_hazards.remove_at(i)

	# Temporizador do próximo ciclo de desabamento
	rubble_cycle_timer -= delta
	if rubble_cycle_timer <= 0.0:
		rubble_cycle_timer = 11.5
		var target_cells: Array[Vector2i] = _pick_rubble_target_cells()
		for cell in target_cells:
			rubble_hazards.append({
				"cell": cell,
				"state": RubbleState.WARNING,
				"timer": 2.0
			})
			_emit_hazard_event(HazardEvent.RUBBLE_WARNING, cell)

func _trigger_rubble_collapse(cell: Vector2i) -> void:
	if not grid:
		return
	_emit_hazard_event(HazardEvent.RUBBLE_COLLAPSE, cell)
	AudioManager.play_bump()
	get_tree().call_group("game_orchestrator", "add_screen_shake", 0.45)

	# Se a célula for um bloco existente, desmorona
	if grid.get_cell_type(cell) == GameState.CellType.BLOCK_DESTRUCTIBLE:
		grid.destroy_block_at(cell, true)
	elif grid.get_cell_type(cell) == GameState.CellType.EMPTY:
		# Cria um novo bloco de escombros de ruína no local
		grid._spawn_block(cell)

	# Detona bomba se houver
	if grid.has_bomb_at(cell):
		var bomb: Bomb = grid.get_bomb_at(cell)
		if is_instance_valid(bomb):
			bomb.detonate()

	# Causa dano se jogador for pego diretamente sob o desabamento
	var players: Array[Node] = get_tree().get_nodes_in_group("players")
	for p in players:
		if is_instance_valid(p) and p.get("is_alive") == true:
			var p_cell: Vector2i = grid.world_to_grid(p.global_position)
			if p_cell == cell:
				if p.has_method("die"):
					p.die()

# ----------------- SINCRONIZAÇÃO MULTIPLAYER -----------------

func _emit_hazard_event(event_type: int, cell: Vector2i) -> void:
	_play_local_hazard_fx(event_type, cell)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		var game = get_tree().get_first_node_in_group("game_orchestrator")
		if game and game.has_method("broadcast_hazard_event"):
			game.call("broadcast_hazard_event", event_type, cell)

func _sync_conveyor_bomb_kick(cell: Vector2i, direction: Vector2) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	var players: Array[Node] = get_tree().get_nodes_in_group("players")
	for node in players:
		if node is Player and is_instance_valid(node):
			node.sync_kick_bomb.rpc(cell, direction)
			return

func apply_remote_event(event_type: int, cell: Vector2i) -> void:
	_play_local_hazard_fx(event_type, cell)
	match event_type:
		HazardEvent.VENT_WARNING:
			_set_remote_vent_state(cell, VentState.WARNING)
		HazardEvent.VENT_ERUPT:
			_set_remote_vent_state(cell, VentState.ERUPTING)
		HazardEvent.VENT_COOLDOWN:
			_set_remote_vent_state(cell, VentState.COOLDOWN)
		HazardEvent.RUBBLE_WARNING:
			rubble_hazards.append({"cell": cell, "state": RubbleState.WARNING, "timer": 2.0})
		HazardEvent.RUBBLE_COLLAPSE:
			for i in range(rubble_hazards.size() - 1, -1, -1):
				if rubble_hazards[i]["cell"] == cell:
					rubble_hazards.remove_at(i)
			# Mirror the arena geometry on clients. Damage and bomb detonation remain
			# server-authoritative; the corresponding RPCs replicate those outcomes.
			if grid.get_cell_type(cell) == GameState.CellType.BLOCK_DESTRUCTIBLE:
				grid.destroy_block_at(cell, true)
			elif grid.get_cell_type(cell) == GameState.CellType.EMPTY:
				grid._spawn_block(cell)

func _set_remote_vent_state(cell: Vector2i, state: int) -> void:
	for vent in magma_vents:
		if vent["cell"] == cell:
			vent["state"] = state
			return

func _play_local_hazard_fx(event_type: int, _cell: Vector2i) -> void:
	match event_type:
		HazardEvent.VENT_WARNING:
			AudioManager.play_enemy_alert()
		HazardEvent.VENT_ERUPT:
			AudioManager.play_explosion()
			get_tree().call_group("game_orchestrator", "add_screen_shake", 0.35)
		HazardEvent.RUBBLE_WARNING:
			AudioManager.play_bump()
		HazardEvent.RUBBLE_COLLAPSE:
			AudioManager.play_bump()
			get_tree().call_group("game_orchestrator", "add_screen_shake", 0.4)

# ----------------- RENDERIZAÇÃO VISUAL -----------------

func _draw() -> void:
	if not grid:
		return
	var is_enhanced: bool = GameState.is_enhanced()
	var reduced_flashes: bool = GameState.reduced_flashes_enabled

	# 1. Desenha Esteiras (Estilo 5)
	if not conveyors.is_empty():
		_draw_conveyors(is_enhanced)

	# 2. Desenha Ruínas Desabantes (Estilo 6)
	if not rubble_hazards.is_empty():
		_draw_rubble_warnings(reduced_flashes, is_enhanced)

	# 3. Desenha Vents de Magma (Estilo 7)
	if not magma_vents.is_empty():
		_draw_magma_vents(reduced_flashes, is_enhanced)

func _draw_conveyors(is_enhanced: bool) -> void:
	var scroll_phase: float = fmod(animation_time * 2.2, 1.0)
	for cell_variant in conveyors.keys():
		var cell: Vector2i = cell_variant
		var dir: Vector2 = conveyors[cell]
		var center: Vector2 = grid.grid_to_world(cell)
		var top_left: Vector2 = center - Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)

		# Fundo metálico da esteira com bordas industriais
		var base_color: Color = Color("232733") if is_enhanced else Color("32384a")
		draw_rect(Rect2(top_left + Vector2(2, 2), Vector2(TILE_SIZE - 4, TILE_SIZE - 4)), base_color)
		draw_rect(Rect2(top_left + Vector2(2, 2), Vector2(TILE_SIZE - 4, TILE_SIZE - 4)), Color("ffd54f"), false, 1.5)

		# Rolos industriais animados (chevrons direcionais)
		var arrow_color: Color = Color("ffe082") if is_enhanced else Color("fff176")
		for i in range(3):
			var offset_frac: float = fmod(float(i) / 3.0 + scroll_phase, 1.0)
			var pt_center: Vector2 = center + dir * ((offset_frac - 0.5) * (TILE_SIZE - 12.0))
			var perp: Vector2 = Vector2(-dir.y, dir.x) * 12.0
			var p1: Vector2 = pt_center - perp - dir * 5.0
			var p2: Vector2 = pt_center
			var p3: Vector2 = pt_center + perp - dir * 5.0
			draw_line(p1, p2, arrow_color, 2.5)
			draw_line(p2, p3, arrow_color, 2.5)

func _draw_rubble_warnings(reduced_flashes: bool, is_enhanced: bool) -> void:
	for rub in rubble_hazards:
		var cell: Vector2i = rub["cell"]
		var center: Vector2 = grid.grid_to_world(cell)
		var pulse: float = 0.55 if reduced_flashes else (sin(animation_time * 12.0) * 0.35 + 0.65)

		# Indicador de perigo de queda: quadrado com ranhuras e fendas
		var warn_rect := Rect2(center.x - 28.0, center.y - 28.0, 56.0, 56.0)
		draw_rect(warn_rect, Color(0.95, 0.45, 0.15, 0.28 * pulse))
		draw_rect(warn_rect, Color(1.0, 0.65, 0.2, 0.85 * pulse), false, 2.0)

		# Ícone de fenda sísmica / exclamação de aviso
		draw_line(center + Vector2(-16, -12), center + Vector2(2, 4), Color(1.0, 0.85, 0.4, pulse), 2.0)
		draw_line(center + Vector2(2, 4), center + Vector2(16, 14), Color(1.0, 0.85, 0.4, pulse), 2.0)
		draw_circle(center + Vector2(0, -6), 4.0, Color("ffd54f"))
		draw_circle(center + Vector2(0, 8), 2.5, Color("ffd54f"))

		if is_enhanced:
			# Partículas de poeira e pequenos seixos caindo
			for p in range(4):
				var seed_p: float = animation_time * 2.0 + float(p) * 1.57
				var grain_pos: Vector2 = center + Vector2(sin(seed_p) * 18.0, fmod(seed_p * 22.0, 24.0) - 12.0)
				draw_rect(Rect2(grain_pos, Vector2(3.0, 3.0)), Color("f7d59c"))

func _draw_magma_vents(reduced_flashes: bool, is_enhanced: bool) -> void:
	for vent in magma_vents:
		var cell: Vector2i = vent["cell"]
		var state: int = vent["state"]
		var center: Vector2 = grid.grid_to_world(cell)

		# Base da grelha de rocha vulcânica
		draw_circle(center, 22.0, Color("201117"))
		draw_arc(center, 22.0, 0.0, TAU, 16, Color("4a2228"), 2.0)
		draw_line(center + Vector2(-15, 0), center + Vector2(15, 0), Color("3d1c21"), 2.0)
		draw_line(center + Vector2(0, -15), center + Vector2(0, 15), Color("3d1c21"), 2.0)

		match state:
			VentState.DORMANT:
				# Pequeno brilho avermelhado no fundo
				draw_circle(center, 7.0, Color(0.8, 0.2, 0.1, 0.4))
			VentState.WARNING:
				# Pulso de alerta pré-erupção (2.0s de aviso para o jogador reagir)
				var pulse: float = 0.6 if reduced_flashes else (sin(animation_time * 14.0) * 0.35 + 0.65)
				draw_circle(center, 26.0 * pulse, Color(1.0, 0.35, 0.1, 0.35))
				draw_arc(center, 26.0, 0.0, TAU, 18, Color(1.0, 0.5, 0.1, pulse), 2.5)
				# Ícone central de calor
				draw_circle(center, 10.0, Color(1.0, 0.7, 0.2, pulse))
			VentState.ERUPTING:
				# Coluna de fogo / erupção de lava
				var flame_pulse: float = 0.8 if reduced_flashes else (sin(animation_time * 24.0) * 0.2 + 0.8)
				draw_circle(center, 28.0 * flame_pulse, Color(1.0, 0.25, 0.1, 0.75))
				draw_circle(center, 18.0 * flame_pulse, Color(1.0, 0.75, 0.2, 0.9))
				draw_circle(center, 8.0, Color.WHITE)
				if is_enhanced:
					# Chamas estilizadas saindo da grade
					for ang_idx in range(6):
						var ang: float = float(ang_idx) * TAU / 6.0 + animation_time * 4.0
						var flame_pt: Vector2 = center + Vector2(cos(ang), sin(ang)) * 24.0
						draw_rect(Rect2(flame_pt.x - 3, flame_pt.y - 3, 6, 6), Color("ffa726"))
			VentState.COOLDOWN:
				# Fumaça residual e resfriamento
				draw_circle(center, 14.0, Color(0.4, 0.3, 0.35, 0.5))
