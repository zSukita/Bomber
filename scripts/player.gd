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
@export var base_speed: float = 220.0
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
var invulnerability_seconds: float = 0.0
var bomb_buffer_timer: float = 0.0

# Nós visuais internos
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visuals_root: Node2D = $Visuals
@onready var name_label: Label = $Visuals/NameLabel

func _ready() -> void:
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

func update_name_display(new_name: String) -> void:
	player_name = new_name
	if name_label:
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
		
		# O servidor simula o movimento autoritativo e aplica a assistência de quina.
		var effective_speed: float = base_speed * speed_multiplier
		var move_dir: Vector2 = _apply_corner_slide(current_direction)
		velocity = move_dir * effective_speed
		move_and_slide()
		
		# Sincroniza a posição autorizada para todos os clientes
		if multiplayer.has_multiplayer_peer():
			sync_position.rpc(global_position, facing_direction)
		
		_update_facing_visual()
	
	# CASO 2: Cliente Conectado
	else:
		if is_local_player():
			_capture_local_input()
			# O servidor aplica a assistência uma única vez, na posição autoritativa.
			send_input.rpc_id(1, current_direction)
		
		# Interpolação suave em direção à posição autoritativa confirmada pelo servidor
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
	var adjusted: Vector2 = dir
	# Movimento horizontal puro: alinha suavemente ao centro Y do corredor se estiver quase na quina
	if dir.y == 0.0 and dir.x != 0.0:
		var tile_y := int(floor(global_position.y / 64.0))
		var center_y := float(tile_y * 64 + 32)
		var diff_y := center_y - global_position.y
		if abs(diff_y) > 2.0 and abs(diff_y) <= 15.0:
			adjusted.y = sign(diff_y) * 0.45
			adjusted = adjusted.normalized()
	# Movimento vertical puro: alinha suavemente ao centro X da coluna se estiver quase na quina
	elif dir.x == 0.0 and dir.y != 0.0:
		var tile_x := int(floor(global_position.x / 64.0))
		var center_x := float(tile_x * 64 + 32)
		var diff_x := center_x - global_position.x
		if abs(diff_x) > 2.0 and abs(diff_x) <= 15.0:
			adjusted.x = sign(diff_x) * 0.45
			adjusted = adjusted.normalized()
	return adjusted

## Captura teclado apenas se for o jogador local
func _capture_local_input() -> void:
	var input_vector: Vector2 = Vector2.ZERO
	
	if Input.is_action_pressed("move_left"):
		input_vector.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_vector.x += 1.0
	if Input.is_action_pressed("move_up"):
		input_vector.y -= 1.0
	if Input.is_action_pressed("move_down"):
		input_vector.y += 1.0
	
	if input_vector.x != 0.0 and input_vector.y != 0.0:
		input_vector = input_vector.normalized()
	
	current_direction = input_vector
	
	if input_vector != Vector2.ZERO:
		if abs(input_vector.x) > abs(input_vector.y):
			facing_direction = Vector2(sign(input_vector.x), 0)
		else:
			facing_direction = Vector2(0, sign(input_vector.y))
	
	if Input.is_action_just_pressed("drop_bomb"):
		request_drop_bomb()

## Solicita soltura de bomba (com suporte a buffer de comando no Modo Melhorado)
func request_drop_bomb() -> void:
	if not is_alive:
		return
	if active_bombs >= max_bombs:
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
			speed_multiplier = minf(speed_multiplier + 0.18, 2.2)
		GameState.PowerUpType.HEART:
			has_heart = true
	powerup_changed.emit(self)
	
	var flash_tween: Tween = create_tween()
	flash_tween.tween_property(visuals_root, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.1)
	flash_tween.tween_property(visuals_root, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)

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
	
	# Se estiver em rede e formos o servidor, replica a eliminação para todos
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_death.rpc()
	else:
		_execute_death_effects()

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
