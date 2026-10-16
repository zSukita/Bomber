class_name Player
extends CharacterBody2D

## Representa o jogador no jogo Bombástico.
## Arquitetura Servidor-Autoritativo:
## - Clientes capturam comandos locais e enviam via RPC para o Servidor.
## - Servidor executa a física de colisão (move_and_slide) e replica o estado.
## - Clientes usam interpolação suave (lerp) na posição recebida do servidor.

signal bomb_drop_requested(player: Player, world_pos: Vector2)
signal died(player: Player)
signal powerup_changed(player: Player)

const PLAYER_COLORS: Array[Color] = [
	Color(0.25, 0.65, 1.0, 1.0),   # Jogador 1: Azul Celeste
	Color(0.95, 0.3, 0.25, 1.0),   # Jogador 2: Vermelho Carmesim
	Color(0.3, 0.85, 0.4, 1.0),    # Jogador 3: Verde Esmeralda
	Color(1.0, 0.82, 0.15, 1.0)    # Jogador 4: Amarelo Ouro
]

# Configurações de Rede e Identidade
var peer_id: int = 1
var player_name: String = "Jogador"
var player_index: int = 0
var target_sync_position: Vector2 = Vector2.ZERO

# Configurações de Movimento
@export var base_speed: float = 150.0
var speed_multiplier: float = 1.0
var current_direction: Vector2 = Vector2.ZERO
var facing_direction: Vector2 = Vector2.DOWN

# Atributos de Partida
var is_alive: bool = true
var max_bombs: int = 1
var active_bombs: int = 0
var last_bomb_request_msec: int = -10000
var bomb_range: int = 2
var has_heart: bool = false
var has_kick: bool = false
var has_pierce: bool = false
var has_remote: bool = false
var has_ice_bomb: bool = false
var has_thunder_bomb: bool = false
var freeze_timer: float = 0.0
var current_mount: int = GameState.MountType.NONE
var mount_ability_cooldown: float = 0.0
var is_dashing: bool = false
var dash_remaining: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
var is_jumping: bool = false
var current_emote_index: int = 1
var emote_cooldown: float = 0.0
var panic_emote_cooldown: float = 0.0
var skull_curse: int = -1 # -1: sem maldição, 0: lentidão, 1: diarreia de bombas, 2: hiper velocidade
var skull_timer: float = 0.0
var diarrhea_timer: float = 0.0
var invulnerability_seconds: float = 0.0
var bomb_buffer_timer: float = 0.0

# Nós visuais internos
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visuals_root: Node2D = $Visuals
@onready var name_label: Label = $Visuals/NameLabel

func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	target_sync_position = global_position
	set_player_color(player_index)
	update_name_display(player_name)

## Retorna verdadeiro se esta instância corresponde ao jogador desta máquina local
func is_local_player() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return true
	return peer_id == multiplayer.get_unique_id()

func set_player_color(index: int) -> void:
	player_index = index
	var color: Color = PLAYER_COLORS[index % PLAYER_COLORS.size()]
	if visuals_root and visuals_root.has_method("set_skin_color"):
		visuals_root.set_skin_color(color)

func set_player_character(index: int) -> void:
	if visuals_root and visuals_root.has_method("set_character"):
		visuals_root.set_character(index)

func update_name_display(new_name: String) -> void:
	player_name = new_name
	if name_label:
		name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		name_label.text = new_name

func _physics_process(delta: float) -> void:
	_update_name_label_visibility()
	if invulnerability_seconds > 0.0:
		invulnerability_seconds = maxf(0.0, invulnerability_seconds - delta)
		if GameState.reduced_flashes_enabled:
			visuals_root.modulate.a = 0.72
		else:
			visuals_root.modulate.a = 0.48 if int(invulnerability_seconds * 12.0) % 2 == 0 else 1.0
	elif visuals_root and visuals_root.modulate.a != 1.0 and is_alive:
		visuals_root.modulate.a = 1.0
	if not is_alive:
		velocity = Vector2.ZERO
		return
	if freeze_timer > 0.0:
		freeze_timer = maxf(0.0, freeze_timer - delta)
		if freeze_timer <= 0.0 and visuals_root and is_alive:
			visuals_root.modulate = Color.WHITE
	if mount_ability_cooldown > 0.0:
		mount_ability_cooldown = maxf(0.0, mount_ability_cooldown - delta)
	if emote_cooldown > 0.0:
		emote_cooldown = maxf(0.0, emote_cooldown - delta)
	if panic_emote_cooldown > 0.0:
		panic_emote_cooldown = maxf(0.0, panic_emote_cooldown - delta)
	elif is_local_player() and not is_dashing and not is_jumping:
		var grid_map: ArenaGrid = get_tree().get_first_node_in_group("grid_map") as ArenaGrid
		if grid_map:
			var cur_c: Vector2i = grid_map.world_to_grid(global_position)
			for d in [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var check_c: Vector2i = cur_c + d
				if grid_map.has_bomb_at(check_c):
					var b: Bomb = grid_map.get_bomb_at(check_c)
					if b and is_instance_valid(b) and b.fuse_timer and b.fuse_timer.time_left <= 0.9:
						panic_emote_cooldown = 3.5
						show_local_emote(14)
						break
	if is_jumping:
		velocity = Vector2.ZERO
		return
	if is_dashing:
		dash_remaining -= delta
		velocity = dash_direction * (base_speed * 3.2)
		move_and_slide()
		if get_slide_collision_count() > 0:
			is_dashing = false
		if dash_remaining <= 0.0:
			is_dashing = false
		_check_bomb_kicking()
		if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
			sync_position.rpc(global_position, facing_direction)
		_update_facing_visual()
		return
	if GameState.local_pause_menu_open and is_local_player():
		current_direction = Vector2.ZERO
		if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
			send_input.rpc_id(1, Vector2.ZERO)
		_update_facing_visual()
		return
	
	# Buffer curto de soltura de bomba, igual nos dois modos gráficos.
	if bomb_buffer_timer > 0.0:
		bomb_buffer_timer -= delta
		if active_bombs < max_bombs:
			request_drop_bomb()

	# CASO 1: Servidor Autorizado (ou Modo Offline)
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		if is_local_player():
			_capture_local_input()
		
		# Processa maldição do Crânio
		if skull_timer > 0.0:
			skull_timer -= delta
			if skull_curse == 1: # Diarreia de bombas
				diarrhea_timer -= delta
				if diarrhea_timer <= 0.0:
					diarrhea_timer = 1.3
					if active_bombs < max_bombs:
						request_drop_bomb()
			if skull_timer <= 0.0:
				clear_curse()
			else:
				# Transmite a maldição por proximidade para outros jogadores
				for other in get_tree().get_nodes_in_group("players"):
					if other != self and is_instance_valid(other) and other.is_alive and ("skull_curse" in other):
						if global_position.distance_to(other.global_position) < 36.0 and other.skull_curse < 0:
							other.apply_curse(skull_curse, skull_timer)
							clear_curse()
							break

		# O servidor simula o movimento autoritativo e aplica a assistência de quina.
		var effective_speed: float = base_speed * speed_multiplier
		if current_mount != GameState.MountType.NONE:
			effective_speed *= 1.15
		if freeze_timer > 0.0:
			effective_speed *= 0.25
		elif skull_curse == 0:
			effective_speed *= 0.55
		elif skull_curse == 2:
			effective_speed *= 1.75
		
		var move_dir: Vector2 = _apply_corner_slide(current_direction)
		var grid: ArenaGrid = get_tree().get_first_node_in_group("grid_map") as ArenaGrid
		var conveyor_vel: Vector2 = grid.get_conveyor_drift(global_position) if grid else Vector2.ZERO
		if grid and ArenaMapStyles.is_ice_map(grid.map_style):
			velocity = velocity.lerp(move_dir * effective_speed + conveyor_vel, clampf(delta * 4.5, 0.0, 1.0))
		else:
			velocity = move_dir * effective_speed + conveyor_vel
		move_and_slide()
		
		if has_kick:
			_check_bomb_kicking()
		
		# Sincroniza a posição autorizada para todos os clientes
		if multiplayer.has_multiplayer_peer():
			sync_position.rpc(global_position, facing_direction)
		
		_update_facing_visual()
	
	# CASO 2: Cliente Conectado
	else:
		if is_local_player():
			_capture_local_input()
			send_input.rpc_id(1, current_direction)
			
			# Predição de movimento local imediata para resposta sem latência
			var effective_speed: float = base_speed * speed_multiplier
			if current_mount != GameState.MountType.NONE:
				effective_speed *= 1.15
			if freeze_timer > 0.0:
				effective_speed *= 0.25
			elif skull_curse == 0:
				effective_speed *= 0.55
			elif skull_curse == 2:
				effective_speed *= 1.75
			
			var client_grid: ArenaGrid = get_tree().get_first_node_in_group("grid_map") as ArenaGrid
			var client_conveyor: Vector2 = client_grid.get_conveyor_drift(global_position) if client_grid else Vector2.ZERO
			if client_grid and ArenaMapStyles.is_ice_map(client_grid.map_style):
				velocity = velocity.lerp(current_direction * effective_speed + client_conveyor, clampf(delta * 4.5, 0.0, 1.0))
			else:
				velocity = current_direction * effective_speed + client_conveyor
			move_and_slide()
			
			# Reconciliação suave com a posição confirmada pelo servidor
			if target_sync_position != Vector2.ZERO:
				var dist: float = global_position.distance_to(target_sync_position)
				if dist > 64.0:
					global_position = global_position.lerp(target_sync_position, clampf(28.0 * delta, 0.0, 1.0))
				elif dist > 1.0:
					global_position = global_position.lerp(target_sync_position, clampf(8.0 * delta, 0.0, 1.0))
		else:
			# Para os outros jogadores conectados: interpolação suave direta
			if target_sync_position != Vector2.ZERO:
				global_position = global_position.lerp(target_sync_position, clampf(22.0 * delta, 0.0, 1.0))
		
		_update_facing_visual()

func _update_name_label_visibility() -> void:
	if not name_label:
		return
	var label_rect: Rect2 = name_label.get_global_rect()
	# A HUD cobre toda a faixa superior; esconder o nome evita texto duplicado no ponto de spawn.
	name_label.visible = label_rect.end.y <= 0.0 or label_rect.position.y >= 80.0

## Assistência geométrica suave de contorno de quinas ao virar corredores (corner-slip)
func _apply_corner_slide(dir: Vector2) -> Vector2:
	if not GameState.corner_slide_assistance or dir == Vector2.ZERO:
		return dir
	var input_len: float = dir.length()
	var adjusted: Vector2 = dir
	# Movimento horizontal cardinal: alinha suave e gradualmente ao centro Y do corredor
	if absf(dir.x) > 0.0 and absf(dir.y) <= 0.05:
		var tile_y := int(floor(global_position.y / 64.0))
		var center_y := float(tile_y * 64 + 32)
		var diff_y := center_y - global_position.y
		if absf(diff_y) > 0.5 and absf(diff_y) <= 16.0:
			var t: float = clampf((absf(diff_y) - 0.5) / 15.5, 0.0, 1.0)
			adjusted.y = sign(diff_y) * (t * 0.22)
			adjusted = adjusted.normalized() * input_len
	# Movimento vertical cardinal: alinha suave e gradualmente ao centro X da coluna
	elif absf(dir.y) > 0.0 and absf(dir.x) <= 0.05:
		var tile_x := int(floor(global_position.x / 64.0))
		var center_x := float(tile_x * 64 + 32)
		var diff_x := center_x - global_position.x
		if absf(diff_x) > 0.5 and absf(diff_x) <= 16.0:
			var t: float = clampf((absf(diff_x) - 0.5) / 15.5, 0.0, 1.0)
			adjusted.x = sign(diff_x) * (t * 0.22)
			adjusted = adjusted.normalized() * input_len
	return adjusted

## Captura input local (suporte total a teclado e joystick/gamepad)
func _capture_local_input() -> void:
	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down", 0.25)
	
	current_direction = input_vector
	
	if input_vector != Vector2.ZERO:
		if abs(input_vector.x) > abs(input_vector.y):
			facing_direction = Vector2(sign(input_vector.x), 0)
		else:
			facing_direction = Vector2(0, sign(input_vector.y))
	
	if Input.is_action_just_pressed("drop_bomb"):
		request_drop_bomb()
	if Input.is_action_just_pressed("mount_ability"):
		request_mount_ability()
	if Input.is_action_just_pressed("trigger_emote"):
		trigger_next_emote()

## Solicita soltura de bomba (com suporte a buffer de comando no Modo Melhorado)
func request_drop_bomb() -> void:
	if not is_alive:
		return
	if active_bombs >= max_bombs:
		if has_remote and active_bombs > 0:
			request_detonate_remote()
			return
		if GameState.input_buffering_enabled:
			bomb_buffer_timer = GameState.input_buffer_window
		return
	
	bomb_buffer_timer = 0.0
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		server_drop_bomb.rpc_id(1)
	else:
		bomb_drop_requested.emit(self, global_position)


# ----------------- RPCS DE SINCRONIZAÇÃO DE REDE -----------------

## Cliente envia seu vetor de direção ao servidor
@rpc("any_peer", "unreliable")
func send_input(dir: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != peer_id or not is_alive or not dir.is_finite():
		return
	
	# O servidor não confia na normalização feita pelo cliente.
	current_direction = dir.limit_length(1.0)
	if current_direction != Vector2.ZERO:
		if abs(current_direction.x) > abs(current_direction.y):
			facing_direction = Vector2(sign(current_direction.x), 0)
		else:
			facing_direction = Vector2(0, sign(current_direction.y))

## Servidor replica a posição e orientação oficiais para todos os clientes
@rpc("authority", "unreliable")
func sync_position(pos: Vector2, facing: Vector2) -> void:
	target_sync_position = pos
	facing_direction = facing

## Cliente solicita soltura de bomba no servidor
@rpc("any_peer", "call_local", "reliable")
func server_drop_bomb() -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	var now_msec: int = Time.get_ticks_msec()
	if sender_id == peer_id and is_alive and active_bombs < max_bombs and now_msec - last_bomb_request_msec >= 120:
		last_bomb_request_msec = now_msec
		# A posição usada para a bomba é a calculada pelo servidor.
		bomb_drop_requested.emit(self, global_position)

## Cliente solicita chute de bomba no servidor
@rpc("any_peer", "call_local", "reliable")
func server_kick_bomb(bomb_cell: Vector2i, kick_dir: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != peer_id or not is_alive or not has_kick or not kick_dir.is_finite():
		return
	var grid_map: ArenaGrid = get_tree().get_first_node_in_group("grid_map") as ArenaGrid
	if grid_map and grid_map.is_in_bounds(bomb_cell):
		var player_cell: Vector2i = grid_map.world_to_grid(global_position)
		if absi(player_cell.x - bomb_cell.x) + absi(player_cell.y - bomb_cell.y) > 1:
			return
		if absf(kick_dir.length() - 1.0) > 0.01 or (absf(kick_dir.x) > 0.01 and absf(kick_dir.y) > 0.01):
			return
		if grid_map.has_bomb_at(bomb_cell):
			var b: Bomb = grid_map.get_bomb_at(bomb_cell)
			if is_instance_valid(b) and not b.is_sliding:
				b.kick(kick_dir)
				sync_kick_bomb.rpc(bomb_cell, kick_dir)

## Servidor replica o chute de bomba para todos os clientes
@rpc("authority", "call_local", "reliable")
func sync_kick_bomb(bomb_cell: Vector2i, kick_dir: Vector2) -> void:
	var grid_map: ArenaGrid = get_tree().get_first_node_in_group("grid_map") as ArenaGrid
	if grid_map and grid_map.has_bomb_at(bomb_cell):
		var b: Bomb = grid_map.get_bomb_at(bomb_cell)
		if is_instance_valid(b) and not b.is_sliding:
			b.kick(kick_dir)

func _check_bomb_kicking() -> void:
	if not is_alive or not has_kick:
		return
	for i in range(get_slide_collision_count()):
		var col: KinematicCollision2D = get_slide_collision(i)
		var collider: Object = col.get_collider()
		if collider is Bomb:
			var bomb := collider as Bomb
			if not bomb.is_sliding:
				var push_dir: Vector2 = facing_direction
				if push_dir == Vector2.ZERO:
					push_dir = current_direction
				if push_dir != Vector2.ZERO:
					var to_bomb: Vector2 = bomb.global_position - global_position
					if to_bomb.normalized().dot(push_dir.normalized()) > 0.35:
						var kick_dir: Vector2 = Vector2.ZERO
						if abs(push_dir.x) > abs(push_dir.y):
							kick_dir = Vector2(sign(push_dir.x), 0)
						else:
							kick_dir = Vector2(0, sign(push_dir.y))
						
						if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
							server_kick_bomb.rpc_id(1, bomb.grid_position, kick_dir)
						else:
							bomb.kick(kick_dir)
							if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
								sync_kick_bomb.rpc(bomb.grid_position, kick_dir)

# ----------------- CICLO DE VIDA E POWER-UPS -----------------

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
			apply_curse(randi_range(0, 2), 12.0)
		GameState.PowerUpType.MOUNT_EGG:
			var candidates: Array[int] = [
				GameState.MountType.GREEN,
				GameState.MountType.BLUE,
				GameState.MountType.YELLOW
			]
			var next_mount: int = candidates.pick_random()
			set_mount(next_mount)
		GameState.PowerUpType.ICE_BOMB:
			has_ice_bomb = true
			has_thunder_bomb = false
		GameState.PowerUpType.THUNDER_BOMB:
			has_thunder_bomb = true
			has_ice_bomb = false
	powerup_changed.emit(self)
	
	var flash_tween: Tween = create_tween()
	flash_tween.tween_property(visuals_root, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.1)
	flash_tween.tween_property(visuals_root, "modulate", Color(1.0, 1.0, 1.0, 1.0) if skull_curse < 0 else Color(1.3, 0.6, 1.4, 1.0), 0.1)

func freeze_player(duration: float = 2.2) -> void:
	if not is_alive or invulnerability_seconds > 0.0:
		return
	if freeze_timer > 0.0:
		die()
		return
	freeze_timer = duration
	AudioManager.play_bump()
	if visuals_root:
		var freeze_tween: Tween = create_tween()
		freeze_tween.tween_property(visuals_root, "modulate", Color(0.35, 0.75, 1.6, 1.0), 0.1)

func set_mount(mount_type: int) -> void:
	current_mount = mount_type
	if visuals_root and visuals_root.has_method("set_mount"):
		visuals_root.set_mount(mount_type)
	powerup_changed.emit(self)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_mount.rpc(mount_type)

@rpc("authority", "call_local", "reliable")
func sync_mount(mount_type: int) -> void:
	current_mount = mount_type
	if visuals_root and visuals_root.has_method("set_mount"):
		visuals_root.set_mount(mount_type)
	powerup_changed.emit(self)

func apply_curse(curse_type: int, duration: float = 12.0) -> void:
	skull_curse = curse_type
	skull_timer = duration
	diarrhea_timer = 1.0
	AudioManager.play_enemy_alert()
	if visuals_root:
		visuals_root.modulate = Color(1.3, 0.6, 1.4, 1.0)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_curse.rpc(skull_curse, skull_timer)

func clear_curse() -> void:
	skull_curse = -1
	skull_timer = 0.0
	if visuals_root:
		visuals_root.modulate = Color.WHITE
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_curse.rpc(-1, 0.0)

@rpc("authority", "call_local", "reliable")
func sync_curse(curse_type: int, duration: float) -> void:
	skull_curse = curse_type
	skull_timer = duration
	if visuals_root:
		visuals_root.modulate = Color(1.3, 0.6, 1.4, 1.0) if skull_curse >= 0 else Color.WHITE

func request_detonate_remote() -> void:
	if not is_alive or not has_remote or active_bombs == 0:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		server_detonate_remote.rpc_id(1)
	else:
		var game_node: Node = get_tree().get_first_node_in_group("game_orchestrator")
		if game_node and game_node.bomb_system:
			game_node.bomb_system.call("detonate_remote_bombs", self)

@rpc("any_peer", "call_local", "reliable")
func server_detonate_remote() -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != peer_id or not is_alive or not has_remote:
		return
	var game_node: Node = get_tree().get_first_node_in_group("game_orchestrator")
	if game_node and game_node.bomb_system:
		game_node.bomb_system.call("detonate_remote_bombs", self)

func die() -> void:
	if not is_alive:
		return
	if invulnerability_seconds > 0.0:
		return
	if current_mount != GameState.MountType.NONE:
		dismount_sacrifice()
		return
	if has_heart:
		has_heart = false
		invulnerability_seconds = 1.5
		AudioManager.play_powerup()
		powerup_changed.emit(self)
		return
	
	# Se estiver em rede e formos o servidor, replica a eliminação para todos
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_death.rpc()
	else:
		_execute_death_effects()

func dismount_sacrifice() -> void:
	current_mount = GameState.MountType.NONE
	invulnerability_seconds = 2.0
	AudioManager.play_powerup()
	if visuals_root and visuals_root.has_method("set_mount"):
		visuals_root.set_mount(GameState.MountType.NONE)
	_spawn_dismount_puff()
	powerup_changed.emit(self)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_mount.rpc(GameState.MountType.NONE)

func _spawn_dismount_puff() -> void:
	var puff_sprite := Sprite2D.new()
	add_child(puff_sprite)
	puff_sprite.position = Vector2(0, -10)
	var p_tween: Tween = create_tween()
	for f in range(4):
		p_tween.tween_callback(func():
			if is_instance_valid(puff_sprite):
				BomberAssets.configure_powerup_puff(puff_sprite, f)
		)
		p_tween.tween_interval(0.06)
	p_tween.chain().tween_callback(puff_sprite.queue_free)

@rpc("authority", "call_local", "reliable")
func sync_death() -> void:
	_execute_death_effects()

func _execute_death_effects() -> void:
	is_alive = false
	collision_shape.set_deferred("disabled", true)
	AudioManager.play_death()
	
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(visuals_root, "rotation", deg_to_rad(360.0), 0.5)
	tween.tween_property(visuals_root, "scale", Vector2(0.2, 0.2), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(visuals_root, "modulate:a", 0.0, 0.5)
	
	died.emit(self)

func respawn(at_position: Vector2, preserve_upgrades: bool = false) -> void:
	global_position = at_position
	target_sync_position = at_position
	is_alive = true
	# O mapa remove as bombas ao trocar de fase; não deixe o contador preso.
	active_bombs = 0
	last_bomb_request_msec = -10000
	if not preserve_upgrades:
		max_bombs = 1
		bomb_range = 2
		speed_multiplier = 1.0
		has_heart = false
		has_kick = false
		has_pierce = false
		has_remote = false
		has_ice_bomb = false
		has_thunder_bomb = false
		set_mount(GameState.MountType.NONE)
	else:
		if visuals_root and visuals_root.has_method("set_mount"):
			visuals_root.set_mount(current_mount)
	clear_curse()
	invulnerability_seconds = 1.5 if GameState.game_mode == GameState.GameMode.CAMPAIGN else 0.0
	collision_shape.set_deferred("disabled", false)
	visuals_root.rotation = 0.0
	visuals_root.scale = Vector2.ONE
	visuals_root.modulate = Color.WHITE
	_update_facing_visual()

func _update_facing_visual() -> void:
	if visuals_root and visuals_root.has_method("update_state"):
		var is_moving: bool = (velocity.length() > 5.0) or (current_direction != Vector2.ZERO)
		if multiplayer.has_multiplayer_peer() and not multiplayer.is_server() and not is_local_player():
			is_moving = global_position.distance_to(target_sync_position) > 2.0
		visuals_root.update_state(facing_direction, is_moving, is_alive)

# ----------------- HABILIDADES ATIVAS DAS MONTARIAS (SUPER BOMBERMAN LOUÍES) -----------------

## Solicita uso da habilidade ativa da montaria atual
func request_mount_ability() -> void:
	if not is_alive or current_mount == GameState.MountType.NONE or mount_ability_cooldown > 0.0 or is_dashing or is_jumping:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		server_mount_ability.rpc_id(1)
	else:
		_execute_mount_ability()

@rpc("any_peer", "call_local", "reliable")
func server_mount_ability() -> void:
	if not multiplayer.is_server() or not is_alive or current_mount == GameState.MountType.NONE:
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == peer_id and mount_ability_cooldown <= 0.0 and not is_dashing and not is_jumping:
		_execute_mount_ability()
		if multiplayer.has_multiplayer_peer():
			client_trigger_mount_ability.rpc(current_mount, facing_direction)

@rpc("authority", "call_local", "reliable")
func client_trigger_mount_ability(m_type: int, f_dir: Vector2) -> void:
	if not multiplayer.is_server():
		facing_direction = f_dir
		_perform_mount_fx(m_type, f_dir)

func _execute_mount_ability() -> void:
	match current_mount:
		GameState.MountType.GREEN:
			# Dino Verde: Arrancada / Dash veloz que empurra e chuta bombas
			mount_ability_cooldown = 1.8
			is_dashing = true
			dash_remaining = 0.28
			dash_direction = facing_direction if facing_direction != Vector2.ZERO else Vector2.DOWN
			AudioManager.play_kick()
			_perform_mount_fx(current_mount, dash_direction)
		GameState.MountType.BLUE:
			# Dino Azul: Salto ágil sobre 1 obstáculo (bomba, bloco ou vão)
			var grid_map: ArenaGrid = get_tree().get_first_node_in_group("grid_map") as ArenaGrid
			if not grid_map:
				return
			var cur_c: Vector2i = grid_map.world_to_grid(global_position)
			var f_dir_i: Vector2i = Vector2i(int(round(facing_direction.x)), int(round(facing_direction.y)))
			if f_dir_i == Vector2i.ZERO:
				f_dir_i = Vector2i.DOWN
			var target_c: Vector2i = cur_c + f_dir_i * 2
			if grid_map.is_in_bounds(target_c) and grid_map.is_walkable(target_c) and not grid_map.has_bomb_at(target_c):
				mount_ability_cooldown = 2.0
				is_jumping = true
				AudioManager.play_powerup()
				var target_pos: Vector2 = grid_map.grid_to_world(target_c)
				var jump_tween: Tween = create_tween()
				jump_tween.tween_property(self, "global_position", target_pos, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				var height_tween: Tween = create_tween()
				height_tween.tween_property(visuals_root, "position:y", -36.0, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				height_tween.tween_property(visuals_root, "position:y", 0.0, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				jump_tween.tween_callback(func():
					is_jumping = false
					AudioManager.play_bump()
				)
				_perform_mount_fx(current_mount, facing_direction)
			else:
				AudioManager.play_bump()
		GameState.MountType.YELLOW:
			# Dino Amarelo: Coice de bloco mole (destrói imediatamente) ou chute violento de bomba
			var grid_map: ArenaGrid = get_tree().get_first_node_in_group("grid_map") as ArenaGrid
			if not grid_map:
				return
			var cur_c: Vector2i = grid_map.world_to_grid(global_position)
			var f_dir_i: Vector2i = Vector2i(int(round(facing_direction.x)), int(round(facing_direction.y)))
			if f_dir_i == Vector2i.ZERO:
				f_dir_i = Vector2i.DOWN
			var front_c: Vector2i = cur_c + f_dir_i
			if grid_map.is_in_bounds(front_c):
				if grid_map.has_bomb_at(front_c):
					mount_ability_cooldown = 1.2
					var bomb: Bomb = grid_map.get_bomb_at(front_c)
					if bomb and is_instance_valid(bomb):
						bomb.kick(Vector2(f_dir_i))
						AudioManager.play_kick()
				elif grid_map.get_cell_type(front_c) == GameState.CellType.BLOCK_DESTRUCTIBLE:
					mount_ability_cooldown = 1.4
					grid_map.destroy_block_at(front_c, true)
					AudioManager.play_block_break()
					get_tree().call_group("game_orchestrator", "add_screen_shake", 0.35)
				else:
					AudioManager.play_bump()
			_perform_mount_fx(current_mount, facing_direction)

func _perform_mount_fx(_m_type: int, _dir: Vector2) -> void:
	if not visuals_root:
		return
	var fx_tween: Tween = create_tween()
	fx_tween.tween_property(visuals_root, "scale", Vector2(1.22, 0.82), 0.08)
	fx_tween.tween_property(visuals_root, "scale", Vector2.ONE, 0.12)

# ----------------- SISTEMA DE EMOTES E REAÇÕES RÁPIDAS -----------------

func trigger_next_emote() -> void:
	if not is_alive or emote_cooldown > 0.0:
		return
	emote_cooldown = 0.8
	# Ciclo de emotes expressivos:
	# 1 (Exclamação), 3 (Interrogação), 7 (Coração), 14 (Suor), 20 (Risada), 24 (Ideia)
	const EMOTE_CYCLE: Array[int] = [1, 3, 7, 14, 20, 24]
	var next_id: int = EMOTE_CYCLE[posmod(current_emote_index, EMOTE_CYCLE.size())]
	current_emote_index += 1
	if multiplayer.has_multiplayer_peer():
		rpc("sync_show_emote", next_id)
	else:
		show_local_emote(next_id)

@rpc("call_local", "any_peer", "reliable")
func sync_show_emote(emote_id: int) -> void:
	show_local_emote(emote_id)

func show_local_emote(emote_id: int) -> void:
	if visuals_root and visuals_root.has_method("show_emote"):
		visuals_root.show_emote(emote_id)
		AudioManager.play_powerup()
