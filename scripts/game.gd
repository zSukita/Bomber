class_name Game
extends Node2D

## Orquestrador do Jogo (Servidor Autoritativo, HUD, Áudio e Efeitos Visuais).
## Gerencia:
## - HUD em tempo real com cartões de status e cronômetro
## - Efeitos sonoros procedurais sincronizados
## - Screen shake (tremor de tela com decaimento suave) nas explosões
## - Melhor de 3 rodadas e fluxo completo de retorno ao lobby

const TIME_PORTAL_SCENE: PackedScene = preload("res://scenes/time_portal.tscn")
const BOT_SCENE: PackedScene = preload("res://scenes/battle_bot.tscn")
const MATCH_SUMMARY_BUILDER_SCRIPT: Script = preload("res://scripts/match_summary_builder.gd")
const WINS_REQUIRED: int = 2 # Melhor de 3 rodadas (primeiro a 2 vitórias)
const ROUND_TIME_LIMIT: int = 150 # 2 minutos e 30 segundos por rodada

@onready var grid_map: ArenaGrid = $GridMap
@onready var bomb_system: Node = $BombSystem
@onready var camera: Camera2D = $Camera2D
@onready var players_container: Node2D = $PlayersContainer
@onready var enemies_container: Node2D = $EnemiesContainer
@onready var portals_container: Node2D = $PortalsContainer

# Interface e HUD
@onready var hud: InGameHUD = $CanvasLayer/HUD
@onready var spectator_banner: Label = $CanvasLayer/SpectatorBanner
@onready var round_overlay: CenterContainer = $CanvasLayer/RoundOverlay
@onready var round_title: Label = $CanvasLayer/RoundOverlay/Panel/Margin/VBox/RoundTitle
@onready var winner_label: Label = $CanvasLayer/RoundOverlay/Panel/Margin/VBox/WinnerLabel
@onready var score_list_vbox: VBoxContainer = $CanvasLayer/RoundOverlay/Panel/Margin/VBox/ScoreList
@onready var next_round_label: Label = $CanvasLayer/RoundOverlay/Panel/Margin/VBox/NextRoundLabel

var match_round: MatchRoundController = MatchRoundController.new()
var match_summary_builder: RefCounted = MATCH_SUMMARY_BUILDER_SCRIPT.new()
var spawned_players: Dictionary = {} # int -> Player
var alive_players: Array[int]:
	get:
		return match_round.alive_players
	set(value):
		match_round.alive_players = value
var is_round_active: bool:
	get:
		return match_round.is_active
	set(value):
		match_round.is_active = value
var current_round: int:
	get:
		return match_round.round_number
	set(value):
		match_round.round_number = value
var campaign_enemy_spawner: CampaignEnemySpawner = CampaignEnemySpawner.new()
var player_spawner: PlayerSpawner = PlayerSpawner.new()
var campaign_enemies: Array[CampaignEnemy] = []
var campaign_portals: Array[TimePortal] = []
var is_campaign_choosing_portal: bool = false
var campaign_blocks_broken: int = 0
var campaign_heart_spawned: bool = false

# Bots de IA (Modo Batalha) e Morte Súbita
var spawned_bots: Array[BattleBot] = []
var sudden_death: SuddenDeath = SuddenDeath.new()
var sudden_death_banner_shown: bool = false

# Estatísticas da Partida / Campanha
var stat_bombs_dropped: int = 0
var stat_blocks_broken: int = 0
var stat_enemies_defeated: int = 0
var stat_powerups_collected: int = 0
var stat_match_seconds: float = 0.0

# Screen Shake (Impacto de Câmera)
var shake_trauma: float = 0.0
var shake_time: float = 0.0
var shake_rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	add_to_group("game_orchestrator")
	shake_rng.randomize()
	bomb_system.call("configure", self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	# A raiz e a interface continuam recebendo o comando de retomar; a arena
	# e seus descendentes continuam sujeitos à pausa da SceneTree.
	for gameplay_node in [grid_map, players_container, enemies_container, portals_container, camera]:
		gameplay_node.process_mode = Node.PROCESS_MODE_PAUSABLE
	GameState.local_pause_menu_open = false
	_configure_controller_inputs()
	NetworkManager.player_left.connect(_on_player_disconnected)
	hud.leave_match_requested.connect(_on_leave_requested)
	
	if NetworkManager.is_game_active and multiplayer.has_multiplayer_peer():
		_init_multiplayer_match()
	elif GameState.game_mode == GameState.GameMode.CAMPAIGN:
		_init_campaign_match()
	else:
		_init_singleplayer_match()

func _process(delta: float) -> void:
	# Decaimento suave do screen shake na câmera
	if shake_trauma > 0.0 and camera:
		shake_trauma = maxf(0.0, shake_trauma - delta * 2.2)
		var intensity: float = clampf(GameState.screen_shake_intensity, 0.0, 1.0)
		if GameState.is_enhanced():
			shake_time += delta
			var trauma: float = pow(shake_trauma, 1.5)
			var amplitude: float = trauma * 10.0 * intensity
			var offset_x: float = (sin(shake_time * 23.0 + 0.4) * 0.7 + sin(shake_time * 37.0 + 2.1) * 0.3) * amplitude
			var offset_y: float = (sin(shake_time * 19.0 + 1.3) * 0.65 + sin(shake_time * 31.0 + 0.5) * 0.35) * amplitude
			camera.offset = Vector2(offset_x, offset_y)
			camera.rotation = sin(shake_time * 17.0 + 0.8) * amplitude * 0.0006
		else:
			# Mantém o tremor legado do modo Base, mas usa um RNG próprio para não afetar as regras.
			var amplitude: float = shake_trauma * 14.0 * intensity
			camera.offset = Vector2(shake_rng.randf_range(-1.0, 1.0), shake_rng.randf_range(-1.0, 1.0)) * amplitude
			camera.rotation = 0.0
	elif camera and (camera.offset != Vector2.ZERO or camera.rotation != 0.0):
		camera.offset = Vector2.ZERO
		camera.rotation = 0.0

## Adiciona impacto à tela (0.0 a 1.0)
func add_screen_shake(amount: float = 0.35) -> void:
	shake_trauma = clampf(shake_trauma + amount, 0.0, 1.0)

# ----------------- INICIALIZAÇÃO DA PARTIDA -----------------

func _init_multiplayer_match() -> void:
	grid_map.generate_map(NetworkManager.current_match_seed)
	hud.update_map_name(grid_map.get_map_name())
	hud.update_campaign_info(0, GameState.MAP_NAMES.size(), 0, false)
	
	for peer_id in NetworkManager.players:
		var p_info: Dictionary = NetworkManager.players[peer_id]
		var color_idx: int = p_info.get("color_index", 0)
		var p_name: String = p_info.get("name", "Jogador")
		var character_idx: int = p_info.get("character_index", 0)
		_spawn_player_instance(peer_id, p_name, color_idx, character_idx)
	
	hud.setup_players(NetworkManager.players)
	hud.update_round_info(1, WINS_REQUIRED)
	
	if multiplayer.is_server():
		_start_round_server(1)
	else:
		is_round_active = true
	
	_refresh_all_hud_cards()
	AudioManager.play_battle_music(grid_map.map_style if grid_map else 0)

func _init_singleplayer_match() -> void:
	grid_map.generate_map()
	hud.update_map_name(grid_map.get_map_name())
	_spawn_player_instance(1, "Jogador 1", 0, GameState.preferred_character_index)

	var all_peer_ids: Array[int] = [1]
	var mock_players: Dictionary = {
		1: {"name": "Jogador 1", "color_index": 0, "is_ready": true}
	}

	# Spawna bots de IA se configurados
	var bot_count: int = clampi(GameState.battle_bot_count, 0, 3)
	_spawn_bots(bot_count, mock_players, all_peer_ids)

	match_round.begin(1, all_peer_ids, ROUND_TIME_LIMIT)
	hud.setup_players(mock_players)
	hud.update_round_info(1, WINS_REQUIRED)
	_refresh_all_hud_cards()
	hud.update_campaign_info(0, GameState.MAP_NAMES.size(), 0, false)
	# Reinicia a Morte Súbita
	sudden_death_banner_shown = false
	sudden_death.start(grid_map)
	AudioManager.play_battle_music(grid_map.map_style if grid_map else 0)

func _init_campaign_match() -> void:
	is_campaign_choosing_portal = false
	if not GameState.campaign_progress_initialized:
		GameState.start_new_campaign()
	GameState.campaign_lives = clampi(GameState.campaign_lives, 1, 9)
	if not GameState.campaign_visited_stages.has(GameState.campaign_stage_index):
		GameState.campaign_visited_stages.append(GameState.campaign_stage_index)
	campaign_blocks_broken = 0
	campaign_heart_spawned = GameState.campaign_heart_stages.has(GameState.campaign_stage_index)
	grid_map.powerup_drop_chance = CampaignRules.POWERUP_DROP_CHANCE
	grid_map.generate_map(GameState.campaign_seed + GameState.campaign_stage_index * CampaignRules.STAGE_SEED_STEP, GameState.campaign_stage_index)
	var p_name: String = NetworkManager.local_player_name if not NetworkManager.local_player_name.is_empty() else "Jogador 1"
	var player: Player = _spawn_player_instance(1, p_name, 0, GameState.preferred_character_index)
	_apply_campaign_player_progress(player)
	player.invulnerability_seconds = 2.5
	spawned_players[1] = player
	match_round.begin(1, [1], CampaignRules.STAGE_TIME_LIMIT)
	hud.setup_players({1: {"name": p_name, "color_index": 0}})
	hud.update_round_info(1, 1)
	hud.update_campaign_info(1, GameState.MAP_NAMES.size(), GameState.campaign_lives)
	hud.update_timer_display(CampaignRules.STAGE_TIME_LIMIT)
	_spawn_campaign_enemies(player)
	_refresh_all_hud_cards()
	_save_campaign_player_progress(player)
	AudioManager.play_battle_music(grid_map.map_style if grid_map else 0, CampaignRules.BOSS_STAGES.has(GameState.campaign_stage_index))

func _spawn_campaign_enemies(player: Player) -> void:
	campaign_enemies = campaign_enemy_spawner.spawn(
		grid_map,
		enemies_container,
		player,
		GameState.campaign_stage_index,
		_on_campaign_enemy_defeated
	)
	_update_campaign_objective()

func _update_campaign_objective() -> void:
	hud.update_campaign_objective(
		tr("GAME_CAMPAIGN_OBJECTIVE") % campaign_enemies.size()
	)

func _start_campaign_stage(stage_index: int, preserve_upgrades: bool) -> void:
	is_round_active = false
	is_campaign_choosing_portal = false
	_clear_campaign_entities()
	GameState.campaign_stage_index = clampi(stage_index, 0, GameState.MAP_NAMES.size() - 1)
	campaign_blocks_broken = 0
	campaign_heart_spawned = GameState.campaign_heart_stages.has(GameState.campaign_stage_index)
	grid_map.powerup_drop_chance = CampaignRules.POWERUP_DROP_CHANCE
	var stage_seed: int = GameState.campaign_seed + GameState.campaign_stage_index * CampaignRules.STAGE_SEED_STEP
	grid_map.generate_map(stage_seed, GameState.campaign_stage_index)
	hud.update_map_name(grid_map.get_map_name())
	var player: Player = spawned_players.get(1, null)
	if player == null or not is_instance_valid(player):
		var p_name: String = NetworkManager.local_player_name if not NetworkManager.local_player_name.is_empty() else "Jogador 1"
		player = _spawn_player_instance(1, p_name, 0, GameState.preferred_character_index)
		spawned_players[1] = player
	player.respawn(grid_map.get_spawn_world_pos(0), preserve_upgrades)
	player.current_direction = Vector2.ZERO
	player.invulnerability_seconds = 1.5
	if not GameState.campaign_visited_stages.has(GameState.campaign_stage_index):
		GameState.campaign_visited_stages.append(GameState.campaign_stage_index)
	match_round.begin(GameState.campaign_stage_index + 1, [1], CampaignRules.STAGE_TIME_LIMIT)
	hud.update_campaign_info(GameState.campaign_stage_index + 1, GameState.MAP_NAMES.size(), GameState.campaign_lives)
	hud.update_timer_display(CampaignRules.STAGE_TIME_LIMIT)
	hud.update_round_info(GameState.campaign_stage_index + 1, 1)
	round_overlay.visible = false
	spectator_banner.visible = false
	_spawn_campaign_enemies(player)
	_refresh_all_hud_cards()
	_save_campaign_player_progress(player)
	GameState.save_campaign_progress()
	AudioManager.play_battle_music(grid_map.map_style if grid_map else 0, CampaignRules.BOSS_STAGES.has(GameState.campaign_stage_index))

func _apply_campaign_player_progress(player: Player) -> void:
	player.max_bombs = GameState.campaign_max_bombs
	player.bomb_range = GameState.campaign_bomb_range
	player.speed_multiplier = GameState.campaign_speed_multiplier
	player.has_heart = GameState.campaign_has_heart
	player.has_kick = GameState.campaign_has_kick

func _save_campaign_player_progress(player: Player) -> void:
	GameState.campaign_max_bombs = player.max_bombs
	GameState.campaign_bomb_range = player.bomb_range
	GameState.campaign_speed_multiplier = player.speed_multiplier
	GameState.campaign_has_heart = player.has_heart
	GameState.campaign_has_kick = player.has_kick
	GameState.save_campaign_progress()

func _clear_campaign_entities() -> void:
	for enemy in campaign_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	campaign_enemies.clear()
	for portal in campaign_portals:
		if is_instance_valid(portal):
			portal.queue_free()
	campaign_portals.clear()

func _on_campaign_enemy_defeated(enemy: CampaignEnemy) -> void:
	stat_enemies_defeated += 1
	campaign_enemies.erase(enemy)
	_update_campaign_objective()
	if campaign_enemies.is_empty() and GameState.game_mode == GameState.GameMode.CAMPAIGN:
		AudioManager.play_stage_clear_jingle()
		if GameState.campaign_stage_index == GameState.MAP_NAMES.size() - 1:
			_show_campaign_ending()
		else:
			is_campaign_choosing_portal = true
			call_deferred("_open_campaign_portals")

func _open_campaign_portals() -> void:
	if GameState.game_mode != GameState.GameMode.CAMPAIGN or not is_campaign_choosing_portal:
		return
	var current_stage: int = GameState.campaign_stage_index
	var new_stage_options: Array[int] = []	
	for stage_id in CampaignRules.STORY_ROUTES[current_stage]:
		if not GameState.campaign_visited_stages.has(stage_id):
			new_stage_options.append(stage_id)
	if new_stage_options.is_empty():
		for stage_id in range(GameState.MAP_NAMES.size()):
			if not GameState.campaign_visited_stages.has(stage_id):
				new_stage_options.append(stage_id)
	var golden_target: int = new_stage_options.pick_random() if not new_stage_options.is_empty() else (current_stage + 1) % GameState.MAP_NAMES.size()
	var visited_options: Array[int] = []
	for stage_id in GameState.campaign_visited_stages:
		if stage_id != current_stage:
			visited_options.append(stage_id)
	if visited_options.is_empty():
		visited_options.append(current_stage)
	var blue_target: int = visited_options.pick_random()
	
	var portal_cells: Array[Vector2i] = []
	var candidates: Array[Vector2i] = CampaignRules.PORTAL_CANDIDATE_CELLS
	for i in range(2):
		for cell in candidates:
			if cell in portal_cells or grid_map.get_cell_type(cell) == GameState.CellType.WALL_INDESTRUCTIBLE:
				continue
			if grid_map.get_cell_type(cell) == GameState.CellType.BLOCK_DESTRUCTIBLE:
				grid_map.destroy_block_at(cell, false)
			if grid_map.has_powerup_at(cell):
				continue
			portal_cells.append(cell)
			var portal: TimePortal = TIME_PORTAL_SCENE.instantiate() as TimePortal
			portal.golden_portal = i == 0
			portal.target_stage = golden_target if i == 0 else blue_target
			portal.selected.connect(_on_campaign_portal_selected)
			portals_container.add_child(portal)
			portal.global_position = grid_map.grid_to_world(cell)
			campaign_portals.append(portal)
			break
	
	spectator_banner.text = tr("GAME_PORTAL_HINT")
	spectator_banner.modulate = Color(1.0, 0.83, 0.4)
	spectator_banner.visible = true
	hud.set_campaign_help_visible(false)

func _on_campaign_portal_selected(portal: TimePortal) -> void:
	if GameState.game_mode != GameState.GameMode.CAMPAIGN or not is_campaign_choosing_portal or not campaign_portals.has(portal):
		return
	is_round_active = false
	is_campaign_choosing_portal = false
	spectator_banner.visible = false
	var target: int = portal.target_stage
	if portal.golden_portal:
		GameState.campaign_golden_choices += 1
	else:
		GameState.campaign_blue_choices += 1
	GameState.campaign_stage_index = target
	if not GameState.campaign_visited_stages.has(target):
		GameState.campaign_visited_stages.append(target)
	GameState.save_campaign_progress()
	call_deferred("_start_campaign_stage", target, true)

func _campaign_lose_life(reason: String) -> void:
	if GameState.game_mode != GameState.GameMode.CAMPAIGN or not is_round_active:
		return
	is_round_active = false
	_trigger_decisive_slowmo()
	is_campaign_choosing_portal = false
	AudioManager.play_game_over_jingle()
	GameState.campaign_lives = maxi(0, GameState.campaign_lives - 1)
	GameState.reset_campaign_upgrades()
	if GameState.campaign_lives > 0:
		GameState.save_campaign_progress()
	else:
		GameState.clear_campaign_progress()
	hud.update_campaign_info(GameState.campaign_stage_index + 1, GameState.MAP_NAMES.size(), GameState.campaign_lives)
	round_overlay.visible = true
	round_title.text = tr("GAME_LIFE_LOST")
	round_title.modulate = Color(1.0, 0.48, 0.42)
	winner_label.text = reason
	winner_label.modulate = Color(1.0, 0.8, 0.72)
	for child in score_list_vbox.get_children():
		child.queue_free()
	if GameState.campaign_lives <= 0:
		_populate_match_stats(score_list_vbox)
		next_round_label.text = tr("GAME_OVER_RETURN")
		get_tree().create_timer(6.0).timeout.connect(_return_to_main_menu)
	else:
		next_round_label.text = tr("GAME_REMAINING_LIVES") % GameState.campaign_lives
		get_tree().create_timer(1.8).timeout.connect(_restart_campaign_stage)

func _restart_campaign_stage() -> void:
	Engine.time_scale = 1.0
	if GameState.game_mode == GameState.GameMode.CAMPAIGN:
		_start_campaign_stage(GameState.campaign_stage_index, false)

func _show_campaign_ending() -> void:
	is_round_active = false
	is_campaign_choosing_portal = false
	GameState.clear_campaign_progress()
	var good_ending: bool = GameState.campaign_golden_choices >= GameState.campaign_blue_choices
	round_overlay.visible = true
	round_title.text = tr("GAME_GOOD_ENDING") if good_ending else tr("GAME_DARK_ENDING")
	round_title.modulate = Color(1.0, 0.83, 0.35) if good_ending else Color(0.65, 0.57, 1.0)
	winner_label.text = tr("GAME_GOOD_ENDING_DESC") if good_ending else tr("GAME_DARK_ENDING_DESC")
	winner_label.modulate = Color.WHITE
	for child in score_list_vbox.get_children():
		child.queue_free()
	var route_label: Label = Label.new()
	route_label.text = tr("GAME_VISITED_WORLDS") % [GameState.campaign_visited_stages.size(), GameState.MAP_NAMES.size()]
	route_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_list_vbox.add_child(route_label)
	_populate_match_stats(score_list_vbox)
	next_round_label.text = tr("GAME_NEXT_CAMPAIGN")
	get_tree().create_timer(8.0).timeout.connect(_return_to_main_menu)

func _return_to_main_menu() -> void:
	Engine.time_scale = 1.0
	GameState.game_mode = GameState.GameMode.BATTLE
	NetworkManager.is_game_active = false
	TransitionManager.change_scene("res://scenes/main_menu.tscn")

func _spawn_player_instance(peer_id: int, p_name: String, color_index: int, character_index: int = 0) -> Player:
	var is_authoritative: bool = not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
	var player: Player = player_spawner.spawn(
		players_container,
		grid_map,
		peer_id,
		p_name,
		color_index,
		is_authoritative,
		_on_player_bomb_drop_requested,
		_on_player_died,
		_on_player_powerup_changed,
		character_index
	)
	spawned_players[peer_id] = player
	return player

func _on_player_powerup_changed(player: Player) -> void:
	stat_powerups_collected += 1
	_refresh_player_hud(player.peer_id)
	if GameState.game_mode == GameState.GameMode.CAMPAIGN and player.peer_id == 1:
		_save_campaign_player_progress(player)

# ----------------- BOTS DE IA (MODO BATALHA) -----------------

const BOT_NAMES: Array[String] = ["Bot-Alfa", "Bot-Beta", "Bot-Gama"]
const BOT_PEER_ID_OFFSET: int = -100  # IDs negativos nunca conflitam com peers reais

func _spawn_bots(count: int, mock_players: Dictionary, peer_ids: Array[int]) -> void:
	# Limpa bots anteriores, se houver
	for old_bot in spawned_bots:
		if is_instance_valid(old_bot):
			old_bot.queue_free()
	spawned_bots.clear()

	# Coleta jogadores humanos para que os bots os persigam
	var human_players: Array[Player] = []
	for player_value: Variant in spawned_players.values():
		var human_player: Player = player_value as Player
		if is_instance_valid(human_player):
			human_players.append(human_player)

	for i in range(count):
		var bot_index: int = 1 + i  # índice de spawn: 1, 2, 3 (0 = jogador humano)
		var bot_peer_id: int = BOT_PEER_ID_OFFSET - i
		var bot_name: String = BOT_NAMES[i % BOT_NAMES.size()]
		var bot_color: int = (1 + i) % Player.PLAYER_COLORS.size()

		var bot: BattleBot = BOT_SCENE.instantiate() as BattleBot
		bot.setup(grid_map, human_players, bot_peer_id, bot_color, 0, bot_name, int(GameState.bot_difficulty))
		bot.global_position = grid_map.get_spawn_world_pos(bot_index)
		bot.bomb_drop_requested.connect(_on_bot_bomb_drop_requested)
		bot.died.connect(_on_bot_died)
		bot.powerup_changed.connect(_on_bot_powerup_changed)
		players_container.add_child(bot)
		spawned_bots.append(bot)

		# Registra no mock_players para aparecer no HUD
		mock_players[bot_peer_id] = {"name": bot_name, "color_index": bot_color, "is_ready": true}
		peer_ids.append(bot_peer_id)

	# Atualiza a referência de all_players dos bots para incluir todos os humanos
	for bot in spawned_bots:
		bot.all_players = human_players

func _on_bot_bomb_drop_requested(bot: BattleBot, _world_pos: Vector2) -> void:
	if not is_round_active or not bot.is_alive or bot.active_bombs >= bot.max_bombs:
		return
	var cell: Vector2i = grid_map.world_to_grid(bot.global_position)
	if not grid_map.is_in_bounds(cell) or grid_map.has_bomb_at(cell) or grid_map.get_cell_type(cell) != GameState.CellType.EMPTY:
		return
	var bomb: Bomb = grid_map.place_bomb(cell, bot as CharacterBody2D)
	if bomb == null:
		return
	bomb.is_pierce = bot.has_pierce
	bomb.is_remote = bot.has_remote
	bot.active_bombs += 1
	bomb.exploded.connect(func(b: Bomb, c: Vector2i, r: int): bot.on_bomb_exploded(); grid_map.unregister_bomb(c); bomb_system.call("resolve_explosion", b, c, r))
	AudioManager.play_bomb_drop()

func _on_bot_died(bot: BattleBot) -> void:
	match_round.mark_player_out(bot.peer_id)
	_check_round_end_condition()
	_refresh_all_hud_cards()

func _on_bot_powerup_changed(_bot: BattleBot) -> void:
	stat_powerups_collected += 1
	_refresh_all_hud_cards()



# ----------------- CRONÔMETRO DE RODADA (SERVIDOR) -----------------

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	if not is_round_active:
		return
	
	if is_round_active and not is_campaign_choosing_portal:
		stat_match_seconds += delta
	
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		if not is_campaign_choosing_portal:
			var current_sec: int = match_round.clock.advance(delta)
			if current_sec >= 0:
				hud.update_timer_display(current_sec)
				if current_sec <= 30 and current_sec > 0:
					AudioManager.play_tension_music()
				if multiplayer.has_multiplayer_peer():
					sync_round_timer.rpc(current_sec)
				# Morte Súbita — só no Modo Batalha
				if GameState.game_mode == GameState.GameMode.BATTLE:
					var triggered: bool = sudden_death.advance(current_sec, delta)
					if triggered and not sudden_death_banner_shown:
						sudden_death_banner_shown = true
						AudioManager.play_sudden_death_alert()
						spectator_banner.text = tr("GAME_SUDDEN_DEATH")
						spectator_banner.modulate = Color(1.0, 0.35, 0.25)
						spectator_banner.visible = true
						get_tree().create_timer(3.5).timeout.connect(func(): if spectator_banner: spectator_banner.visible = spawned_players.values().all(func(p): return not p.is_alive))
			if match_round.clock.is_expired():
				if GameState.game_mode == GameState.GameMode.CAMPAIGN:
					_campaign_lose_life(tr("GAME_CAMPAIGN_TIMEOUT"))
				else:
					_end_round_by_timeout()
				return
		bomb_system.call("check_powerup_pickups")

@rpc("authority", "call_remote", "unreliable")
func sync_round_timer(seconds_left: int) -> void:
	hud.update_timer_display(seconds_left)
	if seconds_left <= 30 and seconds_left > 0:
		AudioManager.play_tension_music()

func _end_round_by_timeout() -> void:
	print("[Rodada] Tempo esgotado!")
	_end_round_server()

# ----------------- BOMBAS E EXPLOSÕES -----------------

func _on_player_bomb_drop_requested(player: Player, _world_pos: Vector2) -> void:
	stat_bombs_dropped += 1
	bomb_system.call("drop_bomb", player)

@rpc("authority", "call_remote", "reliable")
func sync_spawn_bomb(cell: Vector2i, owner_peer_id: int, b_range: int, is_pierce: bool = false, is_remote: bool = false, element_type: int = 0) -> void:
	bomb_system.call("spawn_bomb_replica", cell, owner_peer_id, b_range, is_pierce, is_remote, element_type)

func _roll_powerup_drop_type(cell: Vector2i = Vector2i(-1, -1)) -> int:
	stat_blocks_broken += 1
	var is_campaign: bool = GameState.game_mode == GameState.GameMode.CAMPAIGN
	if is_campaign:
		campaign_blocks_broken += 1
	
	if cell != Vector2i(-1, -1) and grid_map:
		var p_type: int = grid_map.pop_hidden_powerup(cell)
		if is_campaign and p_type == GameState.PowerUpType.HEART:
			campaign_heart_spawned = true
			if not GameState.campaign_heart_stages.has(GameState.campaign_stage_index):
				GameState.campaign_heart_stages.append(GameState.campaign_stage_index)
		return p_type
	
	return -1

@rpc("authority", "call_remote", "reliable")
func sync_explosion(center: Vector2i, flame_cells: Array, destroyed_blocks: Array, dropped_powerups: Array, burned_powerups: Array, owner_peer_id: int) -> void:
	bomb_system.call("apply_explosion_replica", center, flame_cells, destroyed_blocks, dropped_powerups, burned_powerups, owner_peer_id)
# ----------------- POWER-UPS E HUD -----------------

@rpc("authority", "call_remote", "reliable")
func sync_powerup_collected(cell: Vector2i, collector_id: int, p_type: int) -> void:
	bomb_system.call("apply_powerup_collected", cell, collector_id, p_type)

func broadcast_hazard_event(hazard_type: int, cell: Vector2i) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_hazard_event.rpc(hazard_type, cell)

@rpc("authority", "call_remote", "reliable")
func sync_hazard_event(hazard_type: int, cell: Vector2i) -> void:
	if grid_map and grid_map.hazards_node:
		grid_map.hazards_node.apply_remote_event(hazard_type, cell)

func _refresh_player_hud(peer_id: int) -> void:
	var p = spawned_players.get(peer_id, null)
	if p:
		var has_pierce_val: bool = p.has_pierce if "has_pierce" in p else false
		var has_remote_val: bool = p.has_remote if "has_remote" in p else false
		var curse_val: int = p.skull_curse if "skull_curse" in p else -1
		var mount_val: int = p.current_mount if "current_mount" in p else 0
		var ice_val: bool = p.has_ice_bomb if "has_ice_bomb" in p else false
		var thunder_val: bool = p.has_thunder_bomb if "has_thunder_bomb" in p else false
		hud.update_player_card(peer_id, p.is_alive, p.max_bombs, p.bomb_range, p.speed_multiplier, p.has_heart, p.has_kick, has_pierce_val, has_remote_val, curse_val, mount_val, ice_val, thunder_val)

func _refresh_all_hud_cards() -> void:
	for id in spawned_players:
		_refresh_player_hud(id)
	if GameState.game_mode == GameState.GameMode.CAMPAIGN:
		spectator_banner.visible = false
		return
	
	var my_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var me: Player = spawned_players.get(my_id, null)
	if me:
		spectator_banner.visible = not me.is_alive

# ----------------- FIM DE RODADA E MELHOR DE 3 -----------------

func _on_player_died(player: Player) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if GameState.game_mode == GameState.GameMode.CAMPAIGN:
		_campaign_lose_life(tr("GAME_CAMPAIGN_HIT"))
		return
	
	var p_id: int = player.peer_id
	if match_round.mark_player_out(p_id):
		_check_round_end_condition()
	
	_refresh_all_hud_cards()

func _check_round_end_condition() -> void:
	if not is_round_active:
		return
	
	var online_authority: bool = multiplayer.has_multiplayer_peer() and multiplayer.is_server()
	if match_round.should_end(spawned_players.size(), online_authority):
		_end_round_server()

func _end_round_server() -> void:
	match_round.end()
	var winner_id: int = match_round.winner_peer_id()
	if winner_id != 0:
		NetworkManager.scores[winner_id] = NetworkManager.scores.get(winner_id, 0) + 1
	
	if multiplayer.has_multiplayer_peer():
		sync_round_end.rpc(winner_id, NetworkManager.scores)
	else:
		sync_round_end(winner_id, {1: 0})

@rpc("authority", "call_local", "reliable")
func sync_round_end(winner_id: int, updated_scores: Dictionary) -> void:
	match_round.end()
	_trigger_decisive_slowmo()
	NetworkManager.scores = updated_scores
	round_overlay.visible = true
	spectator_banner.visible = false
	round_title.text = tr("GAME_ROUND_TITLE") % current_round
	
	if winner_id == 0:
		AudioManager.stop_music()
		winner_label.text = tr("DRAW")
		winner_label.modulate = Color(1.0, 0.4, 0.4)
	else:
		AudioManager.play_victory_jingle()
		var w_name: String = spawned_players[winner_id].player_name if spawned_players.has(winner_id) else "Jogador %d" % winner_id
		winner_label.text = tr("GAME_ROUND_WINNER") % w_name
		winner_label.modulate = Color(1.0, 0.85, 0.3)
	
	for child in score_list_vbox.get_children():
		child.queue_free()
	
	var has_match_winner: bool = false
	var match_winner_name: String = ""
	
	for p_id in NetworkManager.players:
		var p_name: String = NetworkManager.players[p_id].get("name", "Jogador")
		var wins: int = NetworkManager.scores.get(p_id, 0)
		var lbl: Label = Label.new()
		lbl.text = tr("GAME_SCORE_LINE") % [p_name, wins, WINS_REQUIRED]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_list_vbox.add_child(lbl)
		
		if wins >= WINS_REQUIRED:
			has_match_winner = true
			match_winner_name = p_name
	
	if has_match_winner:
		_populate_match_stats(score_list_vbox)
		AudioManager.play_victory_theme()
		round_title.text = tr("MATCH_OVER")
		winner_label.text = tr("GAME_CHAMPION") % match_winner_name
		next_round_label.text = tr("GAME_RETURN_5")
		if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
			get_tree().create_timer(5.0).timeout.connect(_on_leave_requested)
	else:
		next_round_label.text = tr("GAME_NEXT_ROUND")
		if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
			get_tree().create_timer(3.5).timeout.connect(_advance_to_next_round_server)

func _advance_to_next_round_server() -> void:
	current_round += 1
	var next_seed: int = randi()
	while posmod(next_seed, ArenaGrid.MAP_NAMES.size()) == grid_map.map_style:
		next_seed = randi()
	if multiplayer.has_multiplayer_peer():
		sync_start_new_round.rpc(next_seed, current_round)
	else:
		sync_start_new_round(next_seed, current_round)

@rpc("authority", "call_local", "reliable")
func sync_start_new_round(next_seed: int, round_num: int) -> void:
	Engine.time_scale = 1.0
	current_round = round_num
	round_overlay.visible = false
	spectator_banner.visible = false
	match_round.clock.start(ROUND_TIME_LIMIT)
	
	grid_map.generate_map(next_seed)
	hud.update_map_name(grid_map.get_map_name())
	alive_players.clear()
	
	for peer_id in spawned_players:
		var p: Player = spawned_players[peer_id]
		var spawn_pos: Vector2 = grid_map.get_spawn_world_pos(p.player_index)
		p.respawn(spawn_pos)
		alive_players.append(peer_id)
	# Repositiona bots no novo mapa
	for bot in spawned_bots:
		if is_instance_valid(bot):
			bot.arena_grid = grid_map
			var bot_pos: Vector2 = grid_map.get_spawn_world_pos(bot.player_index)
			bot.respawn(bot_pos)
			alive_players.append(bot.peer_id)
	
	# Reinicia Morte Súbita para a nova rodada
	sudden_death_banner_shown = false
	sudden_death.start(grid_map)

	match_round.begin(round_num, alive_players, ROUND_TIME_LIMIT)
	hud.update_round_info(current_round, WINS_REQUIRED)
	hud.update_timer_display(ROUND_TIME_LIMIT)
	_refresh_all_hud_cards()
	AudioManager.play_battle_music(grid_map.map_style if grid_map else 0)

func _start_round_server(round_num: int) -> void:
	alive_players.clear()
	for id in spawned_players:
		alive_players.append(id)
	match_round.begin(round_num, alive_players, ROUND_TIME_LIMIT)

func _on_player_disconnected(peer_id: int) -> void:
	if spawned_players.has(peer_id):
		var p: Player = spawned_players[peer_id]
		spawned_players.erase(peer_id)
		alive_players.erase(peer_id)
		if is_instance_valid(p):
			p.queue_free()
	
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and spawned_players.is_empty():
		# Mantém o servidor dedicado disponível para uma nova sala após todos saírem.
		is_round_active = false
		NetworkManager.is_game_active = false
		NetworkManager.scores.clear()
		TransitionManager.change_scene("res://scenes/main_menu.tscn")
		return
	
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and is_round_active:
		_check_round_end_condition()
	
	_refresh_all_hud_cards()

func _on_leave_requested() -> void:
	Engine.time_scale = 1.0
	AudioManager.stop_music()
	get_tree().paused = false
	if not NetworkManager.is_dedicated_server:
		NetworkManager.disconnect_from_server()
	GameState.game_mode = GameState.GameMode.BATTLE
	TransitionManager.change_scene("res://scenes/main_menu.tscn")

func _trigger_decisive_slowmo() -> void:
	Engine.time_scale = 0.35
	if hud and hud.has_method("trigger_screen_shake"):
		hud.trigger_screen_shake(10.0)
	var tween: Tween = create_tween()
	tween.tween_property(Engine, "time_scale", 1.0, 0.65).set_delay(0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		var is_now_enhanced: bool = GameState.toggle_enhanced_mode()
		if hud and hud.has_method("notify_mode_switch"):
			hud.notify_mode_switch(is_now_enhanced)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("pause_game"):
		if event is InputEventKey and event.echo:
			return
		var opening: bool = not hud.pause_panel.visible
		hud.pause_panel.visible = opening
		if opening:
			hud.get_node("PauseOverlay/Panel/Margin/VBox/ResumeButton").grab_focus()
		else:
			get_viewport().gui_release_focus()
		var online: bool = multiplayer.has_multiplayer_peer()
		GameState.local_pause_menu_open = opening and online
		hud.update_pause_status(online)
		# Em rede a pausa é local; no modo solo ela congela a partida inteira.
		get_tree().paused = opening and not online
		get_viewport().set_input_as_handled()

func _configure_controller_inputs() -> void:
	GameState.apply_keybindings_to_input_map()

func _populate_match_stats(container: VBoxContainer) -> void:
	match_summary_builder.populate(
		container,
		stat_match_seconds,
		stat_bombs_dropped,
		stat_blocks_broken,
		stat_powerups_collected,
		stat_enemies_defeated,
		GameState.game_mode == GameState.GameMode.CAMPAIGN,
		GameState.campaign_golden_choices,
		GameState.campaign_blue_choices
	)
