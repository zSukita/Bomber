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

const DEFAULT_PORT: int = 8910
const MAX_PLAYERS: int = 4

# Dicionário de jogadores: chave = peer_id (int), valor = Dictionary com dados
# { "name": String, "color_index": int, "is_ready": bool, "score": int }
var players: Dictionary = {}

var local_player_name: String = "Jogador"
var is_game_active: bool = false
var is_dedicated_server: bool = false
var current_match_seed: int = 0
var selected_map_style: int = -1
var scores: Dictionary = {} # peer_id -> int (vitórias)
var peer: ENetMultiplayerPeer = null

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	_check_cli_arguments()

## Detecta parâmetros de linha de comando para Servidor Dedicado Headless
func _check_cli_arguments() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	var all_args: Array[String] = []
	for a in args: all_args.append(a)
	for a in user_args: all_args.append(a)
	
	var is_headless: bool = DisplayServer.get_name() == "headless"
	if is_headless or "--server" in all_args or "--dedicated" in all_args:
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
		status_message.emit("Falha ao criar servidor na porta %d!" % port, true)
		return error
	
	multiplayer.multiplayer_peer = peer
	players.clear()
	
	# Se for Listen Server (jogador jogando como host), adiciona o Peer 1 como jogador
	if not dedicated:
		var host_info: Dictionary = {
			"name": local_player_name,
			"color_index": 0,
			"is_ready": true,
			"score": 0
		}
		players[1] = host_info
		status_message.emit("Servidor criado com sucesso na porta %d!" % port, false)
	else:
		print("[Rede] Servidor dedicado criado na porta %d." % port)
	
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
		status_message.emit("Falha ao inicializar conexão com %s:%d" % [target_ip, port], true)
		return error
	
	multiplayer.multiplayer_peer = peer
	status_message.emit("Conectando a %s:%d..." % [target_ip, port], false)
	return OK

func disconnect_from_server() -> void:
	if peer != null:
		peer.close()
		peer = null
	
	multiplayer.multiplayer_peer = null
	players.clear()
	is_game_active = false
	selected_map_style = -1
	status_message.emit("Desconectado da sala.", false)
	lobby_updated.emit()

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
	status_message.emit("Conectado ao servidor! ID: %d" % my_id, false)
	
	var info: Dictionary = {
		"name": local_player_name,
		"color_index": 0,
		"is_ready": false,
		"score": 0
	}
	register_player.rpc_id(1, info)

func _on_connection_failed() -> void:
	status_message.emit("Não foi possível conectar ao servidor. Verifique o IP e a Porta.", true)
	disconnect_from_server()

func _on_server_disconnected() -> void:
	status_message.emit("O servidor encerrou a conexão.", true)
	disconnect_from_server()
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

# ----------------- RPCS DE SINCRONIZAÇÃO DE LOBBY -----------------

@rpc("any_peer", "reliable")
func register_player(info: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	
	var sender_id: int = multiplayer.get_remote_sender_id()
	if players.has(sender_id) or players.size() >= MAX_PLAYERS:
		return
	var safe_name: String = str(info.get("name", "Jogador")).strip_edges().substr(0, 20)
	info["name"] = safe_name if not safe_name.is_empty() else "Jogador"
	info["is_ready"] = false
	info["score"] = 0
	
	# Distribui cores disponíveis (0 a 3)
	var used_colors: Array = []
	for p_id in players:
		used_colors.append(players[p_id].get("color_index", 0))
	
	var assigned_color: int = 0
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
	if not multiplayer.is_server():
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
	if not multiplayer.is_server() or not can_start_game():
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
	for id in players:
		scores[id] = 0
	game_started.emit(map_seed)
	get_tree().change_scene_to_file("res://scenes/game.tscn")
