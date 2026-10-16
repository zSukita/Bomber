extends Node

## Suíte de integração das mecânicas principais. Executar com:
## Godot --headless --path . --scene res://tests/mechanics_test.tscn

const GAME_SCENE: PackedScene = preload("res://scenes/game.tscn")

var checks: int = 0
var failures: int = 0
var game: Game
var player: Player

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	print("[MECANICAS] Iniciando testes de integração...")
	_test_match_rules()
	_test_character_sprite_directions()
	_test_arena_ambience_themes()
	await _prepare_game()
	if game == null or player == null:
		_finish()
		return
	_test_map_generation()
	_test_player_powerups()
	await _test_mounts()
	await _test_bomb_placement_and_capacity()
	await _test_normal_explosion_and_wall()
	await _test_piercing_and_thunder_explosions()
	await _test_remote_bomb()
	await _test_bomb_kick()
	await _test_chain_reaction_and_ice()
	await _test_heart_protection()
	await _test_powerup_pickup()
	await _test_campaign_enemy_spawning()
	_test_arena_hazards()
	await _test_boss_patterns()
	_test_sudden_death()
	game.queue_free()
	# Encerra e solta os streams criados pelos cenários, para o teste não
	# deixar o player global de áudio segurando decodificadores OGG no quit.
	AudioManager.stop_music()
	AudioManager.music_player.stream = null
	for audio_player in AudioManager.players_pool:
		audio_player.stop()
		audio_player.stream = null
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_finish()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("[OK] ", message)
	else:
		failures += 1
		push_error("[FALHA] " + message)

func _finish() -> void:
	print("[MECANICAS] Resultado: %d verificações, %d falhas." % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _test_match_rules() -> void:
	var round: MatchRoundController = MatchRoundController.new()
	round.begin(0, [1, 2], 3.0)
	_check(round.is_active and round.round_number == 1, "início de rodada normaliza número e ativa partida")
	_check(round.mark_player_out(2) and round.winner_peer_id() == 1, "eliminação registra vencedor restante")
	_check(not round.mark_player_out(2), "eliminação duplicada não altera o estado")
	_check(round.should_end(2, false), "rodada encerra quando sobra um jogador")
	var clock: MatchClock = MatchClock.new()
	clock.start(2.0)
	_check(clock.advance(0.5) == 1, "relógio atualiza segundo restante")
	clock.advance(2.0)
	_check(clock.is_expired(), "relógio encerra ao chegar a zero")

func _test_character_sprite_directions() -> void:
	var sprite: Sprite2D = Sprite2D.new()
	BomberAssets.configure_character_sprite(sprite, 0, 0, 0, false)
	_check(sprite.region_rect == Rect2(0, 0, 16, 16), "sprite usa a coluna de frente ao olhar para baixo")
	BomberAssets.configure_character_sprite(sprite, 0, 0, 1, false)
	_check(sprite.region_rect == Rect2(16, 0, 16, 16), "sprite usa a coluna correta ao olhar para cima")
	BomberAssets.configure_character_sprite(sprite, 0, 0, 2, false)
	_check(sprite.region_rect == Rect2(32, 0, 16, 16), "sprite usa a coluna lateral esquerda")
	BomberAssets.configure_character_sprite(sprite, 0, 0, 2, true)
	_check(sprite.region_rect == Rect2(48, 0, 16, 16), "sprite usa a coluna lateral direita sem girar")
	BomberAssets.configure_character_sprite(sprite, 0, 2, 0, false)
	_check(sprite.region_rect == Rect2(0, 32, 16, 16), "animação percorre as linhas do spritesheet")
	sprite.free()

func _test_arena_ambience_themes() -> void:
	var ambience: ArenaAmbience = ArenaAmbience.new()
	add_child(ambience)
	var pool_size: int = ambience.particles.size()
	var expected_palette: Dictionary = {
		0: [Color("8cd669"), Color("f7e26b")],
		1: [Color("ff6c3b"), Color("ffd152")],
		2: [Color("b9f4ec"), Color("79c9dc")],
		3: [Color("aab3ad"), Color("d2c6a7")],
		4: [Color("d9f3ff"), Color("8de1f7")],
		5: [Color("70e9ff"), Color("c4f7ff")],
		6: [Color("f3cf88"), Color("d6ad66")],
		7: [Color("ff6c3b"), Color("ffd152")],
		8: [Color("f4dba4"), Color("d5e4e8")],
		9: [Color("a9e46f"), Color("d0ef83")],
		10: [Color("b9b5ff"), Color("f3e9a4")],
		11: [Color("ffd477"), Color("e7b881")]
	}
	var themes_match: bool = pool_size == ArenaAmbience.MAX_PARTICLES
	for style: int in expected_palette:
		ambience.set_theme(style)
		var allowed_colors: Array = expected_palette[style]
		for particle: ArenaAmbience.AmbientParticle in ambience.particles:
			if not allowed_colors.has(particle.color):
				themes_match = false
				break
		if ambience.particles.size() != pool_size:
			themes_match = false
	_check(themes_match, "temas ambientais usam paletas próprias sem aumentar o pool de partículas")
	ambience.free()

func _prepare_game() -> void:
	GameState.game_mode = GameState.GameMode.BATTLE
	GameState.battle_bot_count = 2
	NetworkManager.is_game_active = false
	game = GAME_SCENE.instantiate() as Game
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	player = game.spawned_players.get(1) as Player
	_check(player != null and game.is_round_active, "partida de batalha inicia com jogador e rodada ativos")
	_check(game.spawned_bots.size() == 2, "batalha local cria a quantidade configurada de bots")
	if player:
		player.invulnerability_seconds = 999.0
		player.global_position = game.grid_map.grid_to_world(Vector2i(7, 6))
		game.spawned_bots.clear()
		for bot in game.get_tree().get_nodes_in_group("battle_bots"):
			bot.queue_free()
		game.alive_players = [1]

func _test_map_generation() -> void:
	var grid: ArenaGrid = game.grid_map
	_check(ArenaGrid.WIDTH == 15 and ArenaGrid.HEIGHT == 13, "arena mantém dimensões previstas")
	_check(grid.world_to_grid(grid.grid_to_world(Vector2i(4, 8))) == Vector2i(4, 8), "conversão grade/mundo é reversível")
	_check(not grid.is_in_bounds(Vector2i(-1, 0)), "limite externo da arena é reconhecido")
	var styles: int = ArenaMapStyles.NAMES.size()
	var all_styles_valid: bool = styles > 0
	for style in range(styles):
		grid.generate_map(17321, style)
		var first_state: Dictionary = grid.grid_state.duplicate()
		var first_items: Dictionary = grid.hidden_powerups.duplicate()
		grid.generate_map(17321, style)
		if first_state != grid.grid_state or first_items != grid.hidden_powerups:
			all_styles_valid = false
		for spawn_cell in ArenaGrid.SPAWN_TILES:
			if grid.get_cell_type(spawn_cell) != GameState.CellType.EMPTY:
				all_styles_valid = false
	_check(all_styles_valid, "todos os mapas geram layouts determinísticos e spawns livres")
	_check(grid.get_cell_type(Vector2i(0, 0)) == GameState.CellType.WALL_INDESTRUCTIBLE, "cantos da arena recebem parede fixa")

func _test_player_powerups() -> void:
	player.max_bombs = 1
	player.bomb_range = 2
	player.speed_multiplier = 1.0
	player.apply_power_up(GameState.PowerUpType.BOMB)
	player.apply_power_up(GameState.PowerUpType.RANGE)
	player.apply_power_up(GameState.PowerUpType.SPEED)
	_check(player.max_bombs == 2 and player.bomb_range == 3 and is_equal_approx(player.speed_multiplier, 1.1), "bomba, alcance e velocidade evoluem")
	player.apply_power_up(GameState.PowerUpType.HEART)
	player.apply_power_up(GameState.PowerUpType.KICK)
	player.apply_power_up(GameState.PowerUpType.PIERCE)
	player.apply_power_up(GameState.PowerUpType.REMOTE)
	_check(player.has_heart and player.has_kick and player.has_pierce and player.has_remote, "habilidades passivas são ativadas pelos itens")
	player.apply_power_up(GameState.PowerUpType.ICE_BOMB)
	_check(player.has_ice_bomb and not player.has_thunder_bomb, "bomba de gelo substitui elemento anterior")
	player.apply_power_up(GameState.PowerUpType.THUNDER_BOMB)
	_check(player.has_thunder_bomb and not player.has_ice_bomb, "bomba de trovão substitui elemento anterior")
	player.max_bombs = 8
	player.bomb_range = 8
	player.speed_multiplier = 1.8
	player.apply_power_up(GameState.PowerUpType.BOMB)
	player.apply_power_up(GameState.PowerUpType.RANGE)
	player.apply_power_up(GameState.PowerUpType.SPEED)
	_check(player.max_bombs == 8 and player.bomb_range == 8 and is_equal_approx(player.speed_multiplier, 1.8), "atributos respeitam seus limites máximos")
	player.max_bombs = 1
	player.bomb_range = 2
	player.speed_multiplier = 1.0
	player.has_pierce = false
	player.has_remote = false
	player.has_ice_bomb = false
	player.has_thunder_bomb = false
	player.set_mount(GameState.MountType.NONE)

func _reset_arena(cell: Vector2i = Vector2i(7, 6)) -> void:
	game.grid_map.clear_map()
	player.global_position = game.grid_map.grid_to_world(cell)
	player.active_bombs = 0
	player.is_alive = true
	player.invulnerability_seconds = 999.0
	player.has_pierce = false
	player.has_remote = false
	player.has_ice_bomb = false
	player.has_thunder_bomb = false
	player.set_mount(GameState.MountType.NONE)
	player.mount_ability_cooldown = 0.0
	player.is_dashing = false
	player.is_jumping = false
	player.max_bombs = 1
	player.bomb_range = 2
	game.is_round_active = true

func _test_mounts() -> void:
	_reset_arena(Vector2i(5, 5))
	player.apply_power_up(GameState.PowerUpType.MOUNT_EGG)
	_check(player.current_mount in [GameState.MountType.GREEN, GameState.MountType.BLUE, GameState.MountType.YELLOW], "ovo concede uma das três montarias disponíveis")
	for mount_type in [GameState.MountType.GREEN, GameState.MountType.BLUE, GameState.MountType.YELLOW]:
		player.set_mount(mount_type)
		_check(player.current_mount == mount_type and player.visuals_root.current_mount == mount_type, "montaria %d atualiza estado e visual" % mount_type)

	player.set_mount(GameState.MountType.GREEN)
	player.facing_direction = Vector2.RIGHT
	player.request_mount_ability()
	_check(player.is_dashing and player.dash_direction == Vector2.RIGHT and player.mount_ability_cooldown > 0.0, "montaria verde ativa arrancada na direção encarada")
	var green_cooldown: float = player.mount_ability_cooldown
	player.request_mount_ability()
	_check(is_equal_approx(player.mount_ability_cooldown, green_cooldown), "habilidade verde respeita tempo de recarga")
	player.is_dashing = false
	player.mount_ability_cooldown = 0.0

	_reset_arena(Vector2i(5, 5))
	game.grid_map._spawn_block(Vector2i(6, 5))
	player.set_mount(GameState.MountType.BLUE)
	player.facing_direction = Vector2.RIGHT
	player.request_mount_ability()
	_check(player.is_jumping, "montaria azul inicia salto quando há espaço após o obstáculo")
	await get_tree().create_timer(0.35).timeout
	_check(game.grid_map.world_to_grid(player.global_position) == Vector2i(7, 5) and not player.is_jumping, "salto azul atravessa um bloco e termina duas células adiante")

	_reset_arena(Vector2i(5, 5))
	game.grid_map._spawn_wall(Vector2i(7, 5))
	player.set_mount(GameState.MountType.BLUE)
	player.facing_direction = Vector2.RIGHT
	player.request_mount_ability()
	_check(not player.is_jumping and player.mount_ability_cooldown == 0.0, "montaria azul não salta se a célula de chegada estiver bloqueada")

	_reset_arena(Vector2i(5, 5))
	game.grid_map._spawn_block(Vector2i(6, 5))
	player.set_mount(GameState.MountType.YELLOW)
	player.facing_direction = Vector2.RIGHT
	player.request_mount_ability()
	_check(game.grid_map.get_cell_type(Vector2i(6, 5)) == GameState.CellType.EMPTY and player.mount_ability_cooldown > 0.0, "montaria amarela destrói bloco à frente")

	_reset_arena(Vector2i(5, 5))
	var kicked_bomb: Bomb = game.grid_map.place_bomb(Vector2i(6, 5), player)
	kicked_bomb.fuse_timer.stop()
	game.grid_map._spawn_wall(Vector2i(8, 5))
	player.set_mount(GameState.MountType.YELLOW)
	player.facing_direction = Vector2.RIGHT
	player.request_mount_ability()
	_check(kicked_bomb.is_sliding and kicked_bomb.slide_direction == Vector2.RIGHT, "montaria amarela chuta bomba à frente")
	for _step in range(40):
		kicked_bomb._physics_process(0.05)
	_check(not kicked_bomb.is_sliding and kicked_bomb.grid_position == Vector2i(7, 5), "bomba chutada pela montaria para diante de parede")
	kicked_bomb.detonate()

	_reset_arena()
	player.set_mount(GameState.MountType.GREEN)
	player.invulnerability_seconds = 0.0
	player.die()
	_check(player.is_alive and player.current_mount == GameState.MountType.NONE and player.invulnerability_seconds > 0.0, "montaria absorve um golpe e é sacrificada")
	player.invulnerability_seconds = 999.0

func _test_bomb_placement_and_capacity() -> void:
	_reset_arena()
	game.bomb_system.drop_bomb(player)
	var bomb: Bomb = game.grid_map.get_bomb_at(Vector2i(7, 6))
	_check(is_instance_valid(bomb) and player.active_bombs == 1, "bomba ocupa célula vazia e contabiliza capacidade")
	game.bomb_system.drop_bomb(player)
	_check(game.grid_map.active_bombs.size() == 1, "não permite duas bombas na mesma célula")
	player.global_position = game.grid_map.grid_to_world(Vector2i(9, 6))
	game.bomb_system.drop_bomb(player)
	_check(game.grid_map.active_bombs.size() == 1, "limite de bombas ativas é respeitado")
	if is_instance_valid(bomb):
		bomb.detonate()
	await get_tree().process_frame
	_check(player.active_bombs == 0, "detonação libera capacidade da bomba")

func _test_normal_explosion_and_wall() -> void:
	_reset_arena()
	var center: Vector2i = Vector2i(7, 6)
	game.grid_map._spawn_block(Vector2i(8, 6))
	game.grid_map._spawn_block(Vector2i(9, 6))
	game.bomb_system.drop_bomb(player)
	var bomb: Bomb = game.grid_map.get_bomb_at(center)
	bomb.detonate()
	await get_tree().process_frame
	_check(game.grid_map.get_cell_type(Vector2i(8, 6)) == GameState.CellType.EMPTY, "explosão normal destrói o primeiro bloco")
	_check(game.grid_map.get_cell_type(Vector2i(9, 6)) == GameState.CellType.BLOCK_DESTRUCTIBLE, "explosão normal para no primeiro bloco")
	_reset_arena()
	game.grid_map._spawn_wall(Vector2i(8, 6))
	game.grid_map._spawn_block(Vector2i(9, 6))
	game.bomb_system.drop_bomb(player)
	bomb = game.grid_map.get_bomb_at(center)
	bomb.detonate()
	await get_tree().process_frame
	_check(game.grid_map.get_cell_type(Vector2i(9, 6)) == GameState.CellType.BLOCK_DESTRUCTIBLE, "parede indestrutível bloqueia a explosão")

func _test_piercing_and_thunder_explosions() -> void:
	var center: Vector2i = Vector2i(7, 6)
	_reset_arena()
	player.has_pierce = true
	game.grid_map._spawn_block(Vector2i(8, 6))
	game.grid_map._spawn_block(Vector2i(9, 6))
	game.bomb_system.drop_bomb(player)
	var bomb: Bomb = game.grid_map.get_bomb_at(center)
	bomb.detonate()
	await get_tree().process_frame
	_check(game.grid_map.get_cell_type(Vector2i(8, 6)) == GameState.CellType.EMPTY and game.grid_map.get_cell_type(Vector2i(9, 6)) == GameState.CellType.EMPTY, "bomba perfurante atravessa e destrói blocos em sequência")
	_reset_arena()
	player.has_thunder_bomb = true
	game.grid_map._spawn_block(Vector2i(8, 6))
	game.grid_map._spawn_block(Vector2i(11, 6))
	game.grid_map._spawn_block(Vector2i(12, 6))
	game.bomb_system.drop_bomb(player)
	bomb = game.grid_map.get_bomb_at(center)
	bomb.detonate()
	await get_tree().process_frame
	_check(game.grid_map.get_cell_type(Vector2i(11, 6)) == GameState.CellType.EMPTY, "raio de trovão alcança além do alcance normal")
	_check(game.grid_map.get_cell_type(Vector2i(12, 6)) == GameState.CellType.EMPTY, "raio de trovão atravessa blocos no caminho")

func _test_remote_bomb() -> void:
	_reset_arena()
	player.has_remote = true
	game.bomb_system.drop_bomb(player)
	var bomb: Bomb = game.grid_map.get_bomb_at(Vector2i(7, 6))
	await get_tree().process_frame
	_check(is_instance_valid(bomb) and bomb.is_remote and bomb.fuse_timer.is_stopped(), "bomba remota aguarda comando sem pavio ativo")
	game.bomb_system.detonate_remote_bombs(player)
	await get_tree().process_frame
	_check(not game.grid_map.has_bomb_at(Vector2i(7, 6)) and player.active_bombs == 0, "comando remoto detona bomba e libera espaço")

func _test_bomb_kick() -> void:
	_reset_arena(Vector2i(5, 5))
	var bomb: Bomb = game.grid_map.place_bomb(Vector2i(5, 5), player)
	bomb.is_remote = true
	bomb.fuse_timer.stop()
	game.grid_map._spawn_wall(Vector2i(8, 5))
	bomb.kick(Vector2.RIGHT)
	for _step in range(40):
		bomb._physics_process(0.05)
	_check(not bomb.is_sliding and bomb.grid_position == Vector2i(7, 5), "bomba chutada desliza e para antes do obstáculo")
	_check(game.grid_map.get_bomb_at(Vector2i(7, 5)) == bomb, "grade acompanha bomba chutada")
	bomb.detonate()

func _test_chain_reaction_and_ice() -> void:
	_reset_arena()
	var center: Vector2i = Vector2i(7, 6)
	var first: Bomb = game.grid_map.place_bomb(center, player)
	var chained: Bomb = game.grid_map.place_bomb(Vector2i(9, 6), player)
	first.exploded.connect(game.bomb_system.resolve_explosion)
	chained.exploded.connect(game.bomb_system.resolve_explosion)
	first.detonate()
	await get_tree().process_frame
	_check(not game.grid_map.has_bomb_at(center) and not game.grid_map.has_bomb_at(Vector2i(9, 6)), "explosão aciona bomba em reação em cadeia")

	_reset_arena()
	var target: Player = load("res://scenes/player.tscn").instantiate() as Player
	target.peer_id = 2
	game.players_container.add_child(target)
	target.global_position = game.grid_map.grid_to_world(Vector2i(8, 6))
	target.invulnerability_seconds = 0.0
	game.spawned_players[2] = target
	game.alive_players.append(2)
	player.has_ice_bomb = true
	game.bomb_system.drop_bomb(player)
	var ice_bomb: Bomb = game.grid_map.get_bomb_at(center)
	ice_bomb.detonate()
	await get_tree().process_frame
	_check(target.freeze_timer > 0.0 and target.is_alive, "bomba de gelo congela jogador atingido sem eliminá-lo")
	game.spawned_players.erase(2)
	game.alive_players.erase(2)
	target.queue_free()

func _test_heart_protection() -> void:
	_reset_arena()
	player.invulnerability_seconds = 0.0
	player.has_heart = true
	game.bomb_system.drop_bomb(player)
	var bomb: Bomb = game.grid_map.get_bomb_at(Vector2i(7, 6))
	bomb.detonate()
	await get_tree().process_frame
	_check(player.is_alive and not player.has_heart and player.invulnerability_seconds > 0.0, "coração absorve uma explosão e concede invulnerabilidade")
	player.invulnerability_seconds = 999.0

func _test_powerup_pickup() -> void:
	_reset_arena()
	var cell: Vector2i = Vector2i(7, 6)
	var powerup: PowerUp = game.grid_map.spawn_powerup(cell, GameState.PowerUpType.RANGE)
	await get_tree().process_frame
	game.bomb_system.check_powerup_pickups()
	_check(player.bomb_range == 3, "jogador coleta e recebe melhoria de alcance")
	_check(not game.grid_map.has_powerup_at(cell), "item coletado é removido da arena")
	if is_instance_valid(powerup):
		powerup.queue_free()

func _test_campaign_enemy_spawning() -> void:
	_reset_arena(Vector2i(1, 1))
	var all_stages_valid: bool = true
	var boss_stages_valid: bool = true
	for stage_index in range(CampaignRules.ENEMIES_PER_STAGE.size()):
		var enemies: Array[CampaignEnemy] = game.campaign_enemy_spawner.spawn(
			game.grid_map, game.enemies_container, player, stage_index, Callable(self, "_noop_enemy_defeated")
		)
		var has_boss: bool = false
		var unique_cells: Dictionary = {}
		for enemy in enemies:
			has_boss = has_boss or enemy.archetype == CampaignEnemy.Archetype.BOSS
			var cell: Vector2i = game.grid_map.world_to_grid(enemy.global_position)
			all_stages_valid = all_stages_valid and game.grid_map.is_in_bounds(cell) and game.grid_map.get_cell_type(cell) == GameState.CellType.EMPTY and not unique_cells.has(cell)
			unique_cells[cell] = true
		all_stages_valid = all_stages_valid and enemies.size() == CampaignRules.ENEMIES_PER_STAGE[stage_index]
		if stage_index in CampaignRules.BOSS_STAGES:
			boss_stages_valid = boss_stages_valid and has_boss
		else:
			boss_stages_valid = boss_stages_valid and not has_boss
		for enemy in enemies:
			enemy.queue_free()
		await get_tree().process_frame
	_check(all_stages_valid, "12 fases geram a quantidade prevista de inimigos em posições únicas e válidas")
	_check(boss_stages_valid, "chefes aparecem apenas nas três fases designadas")

func _test_sudden_death() -> void:
	_reset_arena()
	var sudden_death: SuddenDeath = SuddenDeath.new()
	sudden_death.start(game.grid_map)
	_check(sudden_death.spiral_cells.size() == 143 and sudden_death.spiral_cells[0] == Vector2i(1, 1), "morte súbita prepara espiral completa da arena")
	_check(sudden_death.advance(45, 0.01), "morte súbita ativa aos 45 segundos")
	_check(game.grid_map.get_cell_type(Vector2i(1, 1)) == GameState.CellType.WALL_INDESTRUCTIBLE, "primeira parede da morte súbita cai na borda")
	_check(not sudden_death.advance(44, 0.1), "aviso de ativação ocorre somente uma vez")
	_check(sudden_death.spiral_index == 1, "próxima parede respeita o intervalo")
	sudden_death.advance(44, 0.5)
	_check(sudden_death.spiral_index == 2, "paredes seguintes avançam após o intervalo")

func _test_arena_hazards() -> void:
	# Teste de esteiras no Estilo 5 (Usina Eletrizante)
	game.grid_map.generate_map(42, 5)
	_check(game.grid_map.hazards_node != null, "arena inicializa o nó gerenciador de perigos")
	var has_conveyors: bool = game.grid_map.hazards_node.conveyors.size() > 0
	_check(has_conveyors, "estilo Usina Eletrizante gera esteiras rolantes")
	if has_conveyors:
		var first_cell: Vector2i = game.grid_map.hazards_node.conveyors.keys()[0]
		var drift: Vector2 = game.grid_map.get_conveyor_drift(game.grid_map.grid_to_world(first_cell))
		_check(drift != Vector2.ZERO, "esteira rolante aplica força de arraste contínua")
		_check(game.grid_map.is_cell_conveyor(first_cell), "célula de esteira é detectada corretamente")

	# Teste de vents no Estilo 7 (Vulcão Ardente)
	game.grid_map.generate_map(42, 7)
	var has_vents: bool = game.grid_map.hazards_node.magma_vents.size() > 0
	_check(has_vents, "estilo Vulcão Ardente gera pontos de fissuras de magma")

	# Desabamento altera a grade para que o aviso e o resultado sejam reproduzíveis.
	game.grid_map.generate_map(42, 6)
	var rubble_cell := Vector2i(-1, -1)
	for x in range(3, ArenaGrid.WIDTH - 3):
		for y in range(3, ArenaGrid.HEIGHT - 3):
			var candidate := Vector2i(x, y)
			if candidate not in ArenaMapGenerator.RESERVED_TILES and not ArenaMapStyles.is_pillar(candidate, 6) and game.grid_map.get_cell_type(candidate) == GameState.CellType.EMPTY:
				rubble_cell = candidate
				break
		if rubble_cell != Vector2i(-1, -1):
			break
	if rubble_cell != Vector2i(-1, -1):
		game.grid_map.hazards_node._trigger_rubble_collapse(rubble_cell)
		_check(game.grid_map.get_cell_type(rubble_cell) == GameState.CellType.BLOCK_DESTRUCTIBLE, "desabamento cria escombros na célula anunciada")
	else:
		_check(false, "ruínas oferecem célula livre para o teste de desabamento")

func _test_boss_patterns() -> void:
	_reset_arena()
	var boss_scene: PackedScene = preload("res://scenes/campaign_enemy.tscn")
	var golem: CampaignEnemy = boss_scene.instantiate() as CampaignEnemy
	game.enemies_container.add_child(golem)
	golem.setup(player, 4, game.grid_map, CampaignEnemy.Archetype.BOSS)
	_check(golem.archetype == CampaignEnemy.Archetype.BOSS and golem.max_health == 4, "chefe Golem possui 4 pontos de vida iniciais")

	# Teste de escalonamento para Fase 2 com <= 50% vida
	golem.health = 2
	golem._on_boss_damaged()
	_check(golem.boss_phase_two, "chefe Golem entra previsivelmente na Fase 2 com 50% de HP")

	# Teste de janela de vulnerabilidade pós-ataque
	golem._transition_to_vulnerable()
	_check(golem.is_boss_vulnerable and golem.boss_state == CampaignEnemy.BossState.VULNERABLE, "chefe entra em estado de vulnerabilidade pós-ataque para contra-ataques")
	golem.queue_free()
	await get_tree().process_frame

	# Mina do Cronos pertence ao chefe, mas ainda deve usar o sistema de explosão
	# sem ser tratada como se seu dono fosse um jogador.
	var cronos: CampaignEnemy = boss_scene.instantiate() as CampaignEnemy
	game.enemies_container.add_child(cronos)
	cronos.setup(player, 11, game.grid_map, CampaignEnemy.Archetype.BOSS)
	cronos.global_position = game.grid_map.grid_to_world(Vector2i(7, 6))
	cronos._cronos_start_time_mine()
	var mine_cell := Vector2i(-1, -1)
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var candidate: Vector2i = game.grid_map.world_to_grid(cronos.global_position) + direction
		if game.grid_map.has_bomb_at(candidate):
			mine_cell = candidate
			break
	var temporal_mine: Bomb = game.grid_map.get_bomb_at(mine_cell) if mine_cell != Vector2i(-1, -1) else null
	_check(is_instance_valid(temporal_mine), "Cronos cria a mina temporal na arena")
	if is_instance_valid(temporal_mine):
		temporal_mine.detonate()
		await get_tree().process_frame
		_check(not game.grid_map.has_bomb_at(mine_cell), "mina de chefe detona pelo sistema compartilhado sem erro de proprietário")
	cronos.queue_free()
	await get_tree().process_frame

func _noop_enemy_defeated(_enemy: CampaignEnemy) -> void:
	pass
