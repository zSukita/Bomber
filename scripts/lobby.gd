class_name Lobby
extends Control

## Tela de Lobby e Gerenciamento de Conexão Multiplayer.
## Permite criar sala (Host), entrar por IP/Porta (Cliente),
## visualizar os jogadores conectados, cores atribuídas e iniciar a partida.

@onready var main_panel: PanelContainer = $CenterContainer/MainPanel
@onready var connection_panel: Control = $CenterContainer/MainPanel/Margin/ContentVBox/ConnectionSection
@onready var room_panel: Control = $CenterContainer/MainPanel/Margin/ContentVBox/RoomSection

@onready var name_input: LineEdit = $CenterContainer/MainPanel/Margin/ContentVBox/ConnectionSection/NameInput
@onready var ip_input: LineEdit = $CenterContainer/MainPanel/Margin/ContentVBox/ConnectionSection/IPInput
@onready var port_input: LineEdit = $CenterContainer/MainPanel/Margin/ContentVBox/ConnectionSection/PortInput

@onready var host_btn: Button = $CenterContainer/MainPanel/Margin/ContentVBox/ConnectionSection/HostButton
@onready var join_btn: Button = $CenterContainer/MainPanel/Margin/ContentVBox/ConnectionSection/JoinButton
@onready var campaign_btn: Button = $CenterContainer/MainPanel/Margin/ContentVBox/ConnectionSection/CampaignButton

@onready var room_title: Label = $CenterContainer/MainPanel/Margin/ContentVBox/RoomSection/RoomTitle
@onready var player_list_container: VBoxContainer = $CenterContainer/MainPanel/Margin/ContentVBox/RoomSection/PlayerList
@onready var map_option: OptionButton = $CenterContainer/MainPanel/Margin/ContentVBox/RoomSection/MapChoiceRow/MapOption
@onready var ready_btn: Button = $CenterContainer/MainPanel/Margin/ContentVBox/RoomSection/ReadyButton
@onready var start_btn: Button = $CenterContainer/MainPanel/Margin/ContentVBox/RoomSection/StartButton
@onready var leave_btn: Button = $CenterContainer/MainPanel/Margin/ContentVBox/RoomSection/LeaveButton

@onready var status_label: Label = $StatusLabel

func _ready() -> void:
	_apply_menu_style()
	# Conexão de sinais do NetworkManager
	NetworkManager.lobby_updated.connect(_update_lobby_ui)
	NetworkManager.status_message.connect(_on_status_message)
	NetworkManager.map_selection_updated.connect(_on_map_selection_updated)
	map_option.add_item("ALEATÓRIO", -1)
	for map_index in range(GameState.MAP_NAMES.size()):
		map_option.add_item(GameState.MAP_NAMES[map_index], map_index)
	map_option.item_selected.connect(_on_map_option_selected)
	
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	campaign_btn.pressed.connect(_on_campaign_pressed)
	ready_btn.pressed.connect(_on_ready_pressed)
	start_btn.pressed.connect(_on_start_pressed)
	leave_btn.pressed.connect(_on_leave_pressed)
	
	name_input.text = "Jogador_%d" % randi_range(100, 999)
	_show_connection_view()
	_update_lobby_ui()
	_setup_lobby_mode_button()

var mode_button: Button

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F10:
			GameState.toggle_enhanced_mode()
			_update_lobby_mode_button()

func _setup_lobby_mode_button() -> void:
	mode_button = Button.new()
	mode_button.position = Vector2(960 - 204, 16)
	mode_button.size = Vector2(188, 34)
	mode_button.pressed.connect(func():
		AudioManager.play_click()
		GameState.toggle_enhanced_mode()
		_update_lobby_mode_button()
	)
	add_child(mode_button)
	GameState.enhanced_mode_toggled.connect(func(_is_enhanced: bool):
		_update_lobby_mode_button()
	)
	_update_lobby_mode_button()

func _update_lobby_mode_button() -> void:
	if not mode_button:
		return
	if GameState.is_enhanced():
		mode_button.text = "⚡ [F10] MODO MELHORADO"
		mode_button.modulate = Color(0.65, 1.0, 0.8)
	else:
		mode_button.text = "⚙️ [F10] MODO BASE"
		mode_button.modulate = Color(0.85, 0.85, 0.85)


func _apply_menu_style() -> void:
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.075, 0.105, 0.16, 0.98)
	panel_style.border_color = Color(0.24, 0.37, 0.54, 0.85)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(20)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	panel_style.shadow_size = 18
	main_panel.add_theme_stylebox_override("panel", panel_style)
	
	_style_button(host_btn, Color(0.12, 0.48, 0.77), Color(0.22, 0.68, 0.98))
	_style_button(join_btn, Color(0.13, 0.58, 0.47), Color(0.24, 0.78, 0.65))
	_style_button(campaign_btn, Color(0.62, 0.36, 0.12), Color(0.9, 0.58, 0.2))
	_style_button(ready_btn, Color(0.13, 0.54, 0.38), Color(0.24, 0.78, 0.52))
	_style_button(start_btn, Color(0.75, 0.34, 0.12), Color(0.98, 0.56, 0.23))
	_style_button(leave_btn, Color(0.19, 0.23, 0.32), Color(0.38, 0.46, 0.60))
	var option_style: StyleBoxFlat = StyleBoxFlat.new()
	option_style.bg_color = Color(0.035, 0.055, 0.09)
	option_style.border_color = Color(0.22, 0.31, 0.43)
	option_style.set_border_width_all(1)
	option_style.set_corner_radius_all(8)
	map_option.add_theme_stylebox_override("normal", option_style)
	for input in [name_input, ip_input, port_input]:
		var input_style: StyleBoxFlat = StyleBoxFlat.new()
		input_style.bg_color = Color(0.035, 0.055, 0.09)
		input_style.border_color = Color(0.22, 0.31, 0.43)
		input_style.set_border_width_all(1)
		input_style.set_corner_radius_all(8)
		input_style.content_margin_left = 12
		input_style.content_margin_right = 12
		input.add_theme_stylebox_override("normal", input_style)
		input.add_theme_stylebox_override("focus", input_style)
		input.custom_minimum_size.y = 40

func _style_button(button: Button, color: Color, hover_color: Color) -> void:
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(9)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = hover_color
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = color.darkened(0.18)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0))
	button.add_theme_font_size_override("font_size", 15)

func _show_connection_view() -> void:
	connection_panel.visible = true
	room_panel.visible = false
	status_label.text = "Pronto para conectar ou criar sala."

func _show_room_view() -> void:
	connection_panel.visible = false
	room_panel.visible = true

func _on_host_pressed() -> void:
	AudioManager.play_click()
	var player_name: String = name_input.text.strip_edges()
	NetworkManager.local_player_name = player_name if not player_name.is_empty() else "Host"
	var port: int = int(port_input.text) if port_input.text.is_valid_int() else NetworkManager.DEFAULT_PORT
	
	var err: Error = NetworkManager.create_server(port)
	if err == OK:
		_show_room_view()
		NetworkManager.set_selected_map_style(-1)
		GameState.game_mode = GameState.GameMode.BATTLE

func _on_campaign_pressed() -> void:
	AudioManager.play_click()
	if multiplayer.has_multiplayer_peer():
		NetworkManager.disconnect_from_server()
	GameState.game_mode = GameState.GameMode.CAMPAIGN
	GameState.campaign_stage_index = 0
	GameState.campaign_lives = 5
	GameState.campaign_seed = randi()
	GameState.campaign_visited_stages.clear()
	GameState.campaign_heart_stages.clear()
	GameState.campaign_golden_choices = 0
	GameState.campaign_blue_choices = 0
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_join_pressed() -> void:
	AudioManager.play_click()
	GameState.game_mode = GameState.GameMode.BATTLE
	var player_name: String = name_input.text.strip_edges()
	NetworkManager.local_player_name = player_name if not player_name.is_empty() else "Cliente"
	var ip: String = ip_input.text.strip_edges()
	var port: int = int(port_input.text) if port_input.text.is_valid_int() else NetworkManager.DEFAULT_PORT
	
	var err: Error = NetworkManager.join_server(ip, port)
	if err == OK:
		_show_room_view()

func _on_ready_pressed() -> void:
	AudioManager.play_click()
	NetworkManager.toggle_ready()

func _on_start_pressed() -> void:
	AudioManager.play_click()
	NetworkManager.start_game()

func _on_leave_pressed() -> void:
	AudioManager.play_click()
	NetworkManager.disconnect_from_server()
	_show_connection_view()

func _update_lobby_ui() -> void:
	if not multiplayer.has_multiplayer_peer():
		_show_connection_view()
		return
	
	_show_room_view()
	
	var is_host: bool = multiplayer.is_server()
	room_title.text = "SALA DE ESPERA   ·   %d/4 JOGADORES" % NetworkManager.players.size()
	
	# Limpa a lista e monta quatro espaços fixos para deixar as vagas claras.
	for child in player_list_container.get_children():
		child.queue_free()
	
	var my_id: int = multiplayer.get_unique_id()
	var player_ids: Array = NetworkManager.players.keys()
	player_ids.sort()
	for slot in range(4):
		if slot < player_ids.size():
			var peer_id: int = int(player_ids[slot])
			_create_player_card(peer_id, NetworkManager.players[peer_id], peer_id == my_id)
		else:
			_create_empty_slot()
	
	# Atualiza texto do botão "Estou Pronto"
	if NetworkManager.players.has(my_id):
		var am_ready: bool = NetworkManager.players[my_id].get("is_ready", false)
		ready_btn.text = "CANCELAR PRONTO" if am_ready else "ESTOU PRONTO"
		ready_btn.modulate = Color(1.0, 0.72, 0.72) if am_ready else Color.WHITE
	
	# O botão Iniciar Partida só é visível ao Host e habilitado quando todos estão prontos
	start_btn.visible = is_host
	start_btn.disabled = not NetworkManager.can_start_game()
	map_option.disabled = not is_host
	map_option.select(NetworkManager.selected_map_style + 1)

func _on_map_option_selected(item_index: int) -> void:
	AudioManager.play_click()
	NetworkManager.set_selected_map_style(map_option.get_item_id(item_index))

func _on_map_selection_updated(_map_index: int) -> void:
	if is_node_ready() and multiplayer.has_multiplayer_peer():
		map_option.select(NetworkManager.selected_map_style + 1)

func _create_player_card(peer_id: int, player_info: Dictionary, is_you: bool) -> void:
	var color_idx: int = int(player_info.get("color_index", 0)) % Player.PLAYER_COLORS.size()
	var accent: Color = Player.PLAYER_COLORS[color_idx]
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 62)
	var card_style: StyleBoxFlat = StyleBoxFlat.new()
	card_style.bg_color = Color(0.095, 0.135, 0.195)
	card_style.border_color = accent.darkened(0.15)
	card_style.border_width_left = 4
	card_style.set_corner_radius_all(10)
	card.add_theme_stylebox_override("panel", card_style)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var portrait: CharacterPortrait = CharacterPortrait.new()
	portrait.custom_minimum_size = Vector2(42, 46)
	portrait.player_color = accent
	row.add_child(portrait)
	var details: VBoxContainer = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.alignment = BoxContainer.ALIGNMENT_CENTER
	var name_label: Label = Label.new()
	var role_text: String = "HOST" if peer_id == 1 else "JOGADOR %d" % (color_idx + 1)
	name_label.text = "%s%s" % [player_info.get("name", "Jogador"), "  ·  VOCÊ" if is_you else ""]
	name_label.add_theme_font_size_override("font_size", 15)
	var role_label: Label = Label.new()
	role_label.text = role_text
	role_label.add_theme_font_size_override("font_size", 10)
	role_label.add_theme_color_override("font_color", Color(0.61, 0.7, 0.82))
	details.add_child(name_label)
	details.add_child(role_label)
	row.add_child(details)
	var is_player_ready: bool = bool(player_info.get("is_ready", false))
	var badge: Label = Label.new()
	badge.text = "PRONTO  ✓" if is_player_ready else "AGUARDANDO"
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", Color(0.42, 0.95, 0.68) if is_player_ready else Color(0.96, 0.76, 0.42))
	row.add_child(badge)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_child(row)
	card.add_child(margin)
	player_list_container.add_child(card)

func _create_empty_slot() -> void:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 62)
	var card_style: StyleBoxFlat = StyleBoxFlat.new()
	card_style.bg_color = Color(0.065, 0.095, 0.145, 0.7)
	card_style.border_color = Color(0.17, 0.23, 0.32)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(10)
	card.add_theme_stylebox_override("panel", card_style)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var portrait: CharacterPortrait = CharacterPortrait.new()
	portrait.custom_minimum_size = Vector2(42, 46)
	portrait.player_color = Color(0.29, 0.35, 0.43)
	row.add_child(portrait)
	var slot_label: Label = Label.new()
	slot_label.text = "VAGA DISPONÍVEL"
	slot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_label.add_theme_font_size_override("font_size", 13)
	slot_label.add_theme_color_override("font_color", Color(0.5, 0.59, 0.7))
	row.add_child(slot_label)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_child(row)
	card.add_child(margin)
	player_list_container.add_child(card)

func _on_status_message(text: String, is_error: bool) -> void:
	status_label.text = text
	status_label.modulate = Color(1.0, 0.3, 0.3) if is_error else Color(0.8, 1.0, 0.8)
