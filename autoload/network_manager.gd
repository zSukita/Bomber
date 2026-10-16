extends Node

## Gerenciador de Rede (Autoload / Singleton).
## Gerencia conexões ENetMultiplayerPeer, registro de jogadores,
## estado da sala/lobby e transição para a partida com sincronização de mapa.
## Suporta Listen Server (jogador como host) e Dedicated Server Headless (--headless / --server).

signal lobby_updated
signal game_started(map_seed: int)
signal player_left(peer_id: int)
signal status_message(text: String, is_error: bool)
signal map_selection_updated(map_index: int)
signal server_discovered(server_info: Dictionary)

const DEFAULT_PORT: int = 8910
const BROADCAST_PORT: int = 8912
const MAX_PLAYERS: int = 4

# Dicionário de jogadores: chave = peer_id (int), valor = Dictionary com dados
# { "name": String, "color_index": int, "is_ready": bool, "score": int }
var players: Dictionary = {}

var local_player_name: String = "Jogador"
var player_name: String:
	get:
		return local_player_name
	set(value):
		local_player_name = value
var preferred_color_index: int = 0
var preferred_character_index: int = 0
var is_game_active: bool = false
var is_dedicated_server: bool = false
var current_match_seed: int = 0
var selected_map_style: int = -1
var scores: Dictionary = {} # peer_id -> int (vitórias)
var peer: ENetMultiplayerPeer = null
var pending_status_message: String = ""
var pending_status_is_error: bool = false

# Descoberta de Servidores na Rede Local (LAN Broadcast)
var udp_broadcaster: PacketPeerUDP = null
var udp_listener: PacketPeerUDP = null
var broadcast_timer: float = 0.0
var discovered_servers: Dictionary = {} # "ip:port" -> Dictionary
var is_discovering: bool = false

# Suporte a UPnP automático para facilitar conexões pela Internet sem abrir portas manualmente no roteador
var upnp_thread: Thread = null
var upnp_mapped_port: int = 0
var upnp_external_ip: String = ""

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	_check_cli_arguments()

func _physics_process(delta: float) -> void:
	# Envia sinalizador UDP para a rede local se formos o servidor e a partida ainda não começou
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and not is_game_active:
		broadcast_timer -= delta
		if broadcast_timer <= 0.0:
			broadcast_timer = 1.0
			_send_lan_broadcast()
	
	# Escuta pacotes de broadcast na porta LAN se estivermos na aba de busca
	if is_discovering and udp_listener and udp_listener.is_bound():
		while udp_listener.get_available_packet_count() > 0:
			var packet: PackedByteArray = udp_listener.get_packet()
			var sender_ip: String = udp_listener.get_packet_ip()
			var text: String = packet.get_string_from_utf8()
			var json = JSON.parse_string(text)
			if json is Dictionary and json.get("game") == "BOMBASTICO":
				var s_port: int = int(json.get("port", DEFAULT_PORT))
				var s_key: String = "%s:%d" % [sender_ip, s_port]
				var s_info: Dictionary = {
					"key": s_key,
					"ip": sender_ip,
					"port": s_port,
					"name": str(json.get("name", "Servidor")),
					"players": int(json.get("players", 1)),
					"max_players": int(json.get("max_players", MAX_PLAYERS)),
					"last_seen": Time.get_ticks_msec()
				}
				discovered_servers[s_key] = s_info
				server_discovered.emit(s_info)
		_prune_discovered_servers()

func _prune_discovered_servers() -> void:
	var now_msec: int = Time.get_ticks_msec()
	for server_key in discovered_servers.keys():
		var server_info: Dictionary = discovered_servers[server_key]
		if now_msec - int(server_info.get("last_seen", 0)) > 5000:
			discovered_servers.erase(server_key)
			server_discovered.emit({"key": server_key, "expired": true})

func _send_lan_broadcast() -> void:
	if udp_broadcaster == null:
		udp_broadcaster = PacketPeerUDP.new()
		udp_broadcaster.set_broadcast_enabled(true)
	var data: Dictionary = {
		"game": "BOMBASTICO",
		"name": local_player_name if not is_dedicated_server else "Servidor Dedicado",
		"port": DEFAULT_PORT,
		"players": players.size(),
		"max_players": MAX_PLAYERS
	}
	var msg: String = JSON.stringify(data)
	udp_broadcaster.set_dest_address("255.255.255.255", BROADCAST_PORT)
	udp_broadcaster.put_packet(msg.to_utf8_buffer())

func start_lan_discovery() -> void:
	is_discovering = true
	discovered_servers.clear()
	if udp_listener == null:
		udp_listener = PacketPeerUDP.new()
	if not udp_listener.is_bound():
		var err := udp_listener.bind(BROADCAST_PORT)
		if err != OK:
			print("[Rede] Porta de broadcast LAN já em uso ou indisponível: ", err)

func stop_lan_discovery() -> void:
	is_discovering = false
	if udp_listener and udp_listener.is_bound():
		udp_listener.close()

## Detecta parâmetros de linha de comando para Servidor Dedicado Headless
func _check_cli_arguments() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	var all_args: Array[String] = []
	for a in args: all_args.append(a)
	for a in user_args: all_args.append(a)
	
	var is_headless: bool = DisplayServer.get_name() == "headless"
	if ("--server" in all_args or "--dedicated" in all_args) or (is_headless and not "--run-test" in all_args and not "--editor" in all_args):
		is_dedicated_server = true
		var port: int = DEFAULT_PORT
		for arg in all_args:
			if arg.begins_with("--port="):
				port = int(arg.trim_prefix("--port="))
		
		print("=====================================================")
		print("[BOMBÁSTICO] MODO SERVIDOR DEDICADO HEADLESS ATIVADO")
		print("[BOMBÁSTICO] Porta configurada: ", port)
		print("=====================================================")
		call_deferred("_start_dedicated_server", port)

func _start_dedicated_server(port: int) -> void:
	var err: Error = create_server(port, true)
	if err == OK:
		print("[BOMBÁSTICO DEDICADO] Aguardando conexões de jogadores...")
	else:
		printerr("[BOMBÁSTICO DEDICADO] Erro ao iniciar na porta ", port)

## Inicia uma sala como Servidor (Listen Server ou Servidor Dedicado)
func create_server(port: int = DEFAULT_PORT, dedicated: bool = false) -> Error:
	is_dedicated_server = dedicated
	selected_map_style = -1
	peer = ENetMultiplayerPeer.new()
	# O limite do ENet conta apenas clientes; o host local ocupa uma das vagas
	# visíveis quando não estamos em modo dedicado.
	var max_remote_clients: int = MAX_PLAYERS if dedicated else MAX_PLAYERS - 1
	var error: Error = peer.create_server(port, max_remote_clients)
	if error != OK:
		status_message.emit(tr("NET_CREATE_FAIL") % port, true)
		return error
	
	multiplayer.multiplayer_peer = peer
	players.clear()
	
	# Se for Listen Server (jogador jogando como host), adiciona o Peer 1 como jogador
	if not dedicated:
		var host_info: Dictionary = {
			"name": local_player_name,
			"color_index": preferred_color_index,
			"character_index": preferred_character_index,
			"is_ready": true,
			"score": 0
		}
		players[1] = host_info
		status_message.emit(tr("NET_CREATE_OK") % port, false)
	else:
		print("[Rede] Servidor dedicado criado na porta %d." % port)
	
	_setup_upnp_async(port)
	lobby_updated.emit()
	return OK

## Conecta a um servidor existente como Cliente
func join_server(ip: String, port: int = DEFAULT_PORT) -> Error:
	var target_ip: String = ip.strip_edges()
	if target_ip.is_empty():
		target_ip = "127.0.0.1"
	
	peer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_client(target_ip, port)
	if error != OK:
		status_message.emit(tr("NET_CLIENT_INIT_FAIL") % [target_ip, port], true)
		return error
	
	multiplayer.multiplayer_peer = peer
	status_message.emit(tr("NET_CONNECTING") % [target_ip, port], false)
	return OK

func disconnect_from_server(show_status_message: bool = true) -> void:
	if peer != null:
		peer.close()
		peer = null
	
	if udp_broadcaster:
		udp_broadcaster.close()
		udp_broadcaster = null
	stop_lan_discovery()
	_cleanup_upnp()
	
	multiplayer.multiplayer_peer = null
	players.clear()
	scores.clear()
	is_game_active = false
	selected_map_style = -1
	if show_status_message:
		status_message.emit(tr("NET_DISCONNECTED"), false)
	lobby_updated.emit()

func _exit_tree() -> void:
	_cleanup_upnp()

# ----------------- SUPORTE A UPNP ASSÍNCRONO -----------------

func _setup_upnp_async(port: int) -> void:
	if upnp_thread and upnp_thread.is_started():
		# Nunca pare a thread principal esperando pela descoberta do roteador.
		# Se ela já terminou, basta coletar o resultado antes de reutilizar a variável.
		if upnp_thread.is_alive():
			return
		upnp_thread.wait_to_finish()
	upnp_thread = Thread.new()
	upnp_thread.start(_upnp_worker.bind(port))

func _upnp_worker(port: int) -> void:
	var upnp := UPNP.new()
	var discover_result: int = upnp.discover(1500, 2, "InternetGatewayDevice")
	if discover_result != UPNP.UPNP_RESULT_SUCCESS:
		discover_result = upnp.discover()
	
	if discover_result == UPNP.UPNP_RESULT_SUCCESS:
		var gateway: UPNPDevice = upnp.get_gateway()
		if gateway and gateway.is_valid_gateway():
			var map_udp: int = upnp.add_port_mapping(port, port, "Bombastico", "UDP")
			if map_udp == UPNP.UPNP_RESULT_SUCCESS:
				var ext_ip: String = upnp.query_external_address()
				call_deferred("_on_upnp_success", ext_ip, port)
				return
			else:
				call_deferred("_on_upnp_failed", "Código %d" % map_udp)
				return
	call_deferred("_on_upnp_failed", "Roteador sem suporte a UPnP ativo")

func _on_upnp_success(ext_ip: String, port: int) -> void:
	upnp_external_ip = ext_ip
	upnp_mapped_port = port
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		_cleanup_upnp()
		return
	print("[Rede] UPnP mapeado com sucesso! IP Externo: %s:%d" % [ext_ip, port])
	status_message.emit(tr("NET_UPNP_OK") % [ext_ip, port], false)

func _on_upnp_failed(reason: String) -> void:
	print("[Rede] UPnP não disponível: %s (conexão LAN/VPN local continua normal)" % reason)

func _cleanup_upnp() -> void:
	if upnp_thread and upnp_thread.is_started():
		# Se a descoberta ainda estiver em andamento, o callback de sucesso fará a
		# limpeza assim que a thread terminar. Isso evita congelar a interface.
		if upnp_thread.is_alive():
			return
		upnp_thread.wait_to_finish()
		upnp_thread = null
	if upnp_mapped_port > 0:
		var port_to_remove: int = upnp_mapped_port
		upnp_mapped_port = 0
		upnp_external_ip = ""
		# Executa remoção rápida do mapeamento no roteador
		var upnp := UPNP.new()
		if upnp.discover(500, 2, "InternetGatewayDevice") == UPNP.UPNP_RESULT_SUCCESS:
			upnp.delete_port_mapping(port_to_remove, "UDP")

# ----------------- CALLBACKS DE CONEXÃO MULTIPLAYER -----------------

func _on_peer_connected(id: int) -> void:
	print("[Rede] Peer conectado: ", id)

func _on_peer_disconnected(id: int) -> void:
	print("[Rede] Peer desconectado: ", id)
	if players.has(id):
		players.erase(id)
		player_left.emit(id)
		lobby_updated.emit()
		
		if multiplayer.is_server():
			sync_lobby.rpc(players)

func _on_connected_to_server() -> void:
	var my_id: int = multiplayer.get_unique_id()
	status_message.emit(tr("NET_CONNECTED") % my_id, false)
	
	var info: Dictionary = {
		"name": local_player_name,
		"color_index": preferred_color_index,
		"character_index": preferred_character_index,
		"is_ready": false,
		"score": 0
	}
	register_player.rpc_id(1, info)

func _on_connection_failed() -> void:
	disconnect_from_server(false)
	status_message.emit(tr("NET_CONNECT_FAIL"), true)

func _on_server_disconnected() -> void:
	disconnect_from_server(false)
	pending_status_message = tr("NET_CONNECTION_LOST")
	pending_status_is_error = true
	TransitionManager.change_scene("res://scenes/lobby.tscn")

# ----------------- RPCS DE SINCRONIZAÇÃO DE LOBBY -----------------

@rpc("any_peer", "reliable")
func register_player(info: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	
	var sender_id: int = multiplayer.get_remote_sender_id()
	if is_game_active:
		connection_rejected.rpc_id(sender_id, tr("NET_MATCH_STARTED_REJECT"))
		return
	if players.has(sender_id):
		connection_rejected.rpc_id(sender_id, tr("NET_ALREADY_REGISTERED"))
		return
	if players.size() >= MAX_PLAYERS:
		connection_rejected.rpc_id(sender_id, tr("NET_ROOM_FULL"))
		return
	var safe_name: String = str(info.get("name", "Jogador")).strip_edges().substr(0, 20)
	info["name"] = safe_name if not safe_name.is_empty() else "Jogador"
	info["is_ready"] = false
	info["score"] = 0
	info["character_index"] = clampi(int(info.get("character_index", 0)), 0, BomberAssets.CHARACTER_NAMES.size() - 1)
	
	# Distribui cores disponíveis (0 a 3), respeitando a preferida caso esteja livre
	var used_colors: Array = []
	for p_id in players:
		used_colors.append(players[p_id].get("color_index", 0))
	
	var req_color: int = int(info.get("color_index", 0))
	var assigned_color: int = req_color
	if req_color in used_colors or req_color < 0 or req_color >= MAX_PLAYERS:
		for c in range(MAX_PLAYERS):
			if not (c in used_colors):
				assigned_color = c
				break
	
	info["color_index"] = assigned_color
	players[sender_id] = info
	
	sync_lobby.rpc(players)
	sync_map_selection.rpc_id(sender_id, selected_map_style)
	lobby_updated.emit()
	
	print("[Lobby] Jogador cadastrado: %s (ID: %d, Cor: %d)" % [info["name"], sender_id, assigned_color])

@rpc("authority", "call_remote", "reliable")
func connection_rejected(reason: String) -> void:
	disconnect_from_server(false)
	status_message.emit(tr(reason), true)

@rpc("authority", "reliable")
func sync_lobby(lobby_data: Dictionary) -> void:
	players = lobby_data
	lobby_updated.emit()

func toggle_ready() -> void:
	var my_id: int = multiplayer.get_unique_id()
	if players.has(my_id):
		var new_state: bool = not players[my_id]["is_ready"]
		set_ready_state.rpc_id(1, new_state)

@rpc("any_peer", "reliable")
func set_ready_state(is_ready: bool) -> void:
	if not multiplayer.is_server() or is_game_active:
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if players.has(sender_id):
		players[sender_id]["is_ready"] = is_ready
		sync_lobby.rpc(players)
		lobby_updated.emit()
		
		# Em servidor dedicado headless, inicia automaticamente se todos estiverem prontos (mínimo 2 jogadores)
		if is_dedicated_server and players.size() >= 2 and can_start_game():
			print("[BOMBÁSTICO DEDICADO] Todos os jogadores prontos! Iniciando partida...")
			start_game()

func can_start_game() -> bool:
	if not multiplayer.is_server() or players.size() < 2 or players.size() > MAX_PLAYERS:
		return false
	
	for id in players:
		if not players[id].get("is_ready", false):
			return false
	return true

func start_game() -> void:
	if not multiplayer.is_server() or is_game_active or not can_start_game():
		return
	
	var map_seed: int = randi()
	if selected_map_style >= 0:
		map_seed += posmod(selected_map_style - posmod(map_seed, GameState.MAP_NAMES.size()), GameState.MAP_NAMES.size())
	notify_start_game.rpc(map_seed)

func set_selected_map_style(map_index: int) -> void:
	if not multiplayer.is_server():
		return
	selected_map_style = clampi(map_index, -1, GameState.MAP_NAMES.size() - 1)
	map_selection_updated.emit(selected_map_style)
	sync_map_selection.rpc(selected_map_style)

@rpc("authority", "call_remote", "reliable")
func sync_map_selection(map_index: int) -> void:
	selected_map_style = clampi(map_index, -1, GameState.MAP_NAMES.size() - 1)
	map_selection_updated.emit(selected_map_style)

@rpc("authority", "call_local", "reliable")
func notify_start_game(map_seed: int) -> void:
	is_game_active = true
	current_match_seed = map_seed
	scores.clear()
	for id in players:
		scores[id] = 0
	game_started.emit(map_seed)
	get_tree().change_scene_to_file("res://scenes/game.tscn")
