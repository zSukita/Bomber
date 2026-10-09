class_name Lobby
extends Control

## Tela de Lobby e Menu Principal do Bombástico.
## Gerencia Modo Campanha Solo, Batalhas Multiplayer (Host/Join com abas limpas),
## customização de apelido e cor do traje com preview em tempo real,
## e sala de espera estruturada e moderna.

# Contêineres Principais
@onready var main_panel: PanelContainer = $CenterContainer/MainPanel
@onready var connection_panel: Control = $CenterContainer/MainPanel/Margin/ContentVBox/ConnectionSection
@onready var room_panel: Control = $CenterContainer/MainPanel/Margin/ContentVBox/RoomSection

# Cards da Seção de Conexão
@onready var profile_card: PanelContainer = $CenterContainer/MainPanel/Margin/ContentVBox/ConnectionSection/LeftColumn/ProfileCard
@onready var campaign_card: PanelContainer = $CenterContainer/MainPanel/Margin/ContentVBox/ConnectionSection/LeftColumn/CampaignCard
@onready var multiplayer_card: PanelContainer = $CenterContainer/MainPanel/Margin/ContentVBox/ConnectionSection/RightColumn/MultiplayerCard

# Perfil do Jogador
@onready var portrait_box: CenterContainer = $CenterContainer/MainPanel/Margin/ContentVBox/ConnectionSection/LeftColumn/ProfileCard/Margin/VBox/ProfileRow/PortraitBox
@onready var name_input: LineEdit = $CenterContainer/MainPanel/Margin/ContentVBox/ConnectionSection/LeftColumn/ProfileCard/Margin/VBox/ProfileRow/NameInput
@onready var colors_box: HBoxContainer = $CenterContainer/MainPanel/Margin/ContentVBox/ConnectionSection/LeftColumn/ProfileCard/Margin/VBox/ColorSelectionRow/ColorsBox

# Campanha Solo
@onready var campaign_btn: Button = $CenterContainer/MainPanel/Margin/ContentVBox/ConnectionSection/LeftColumn/CampaignCard/Margin/VBox/CampaignButton

# Multiplayer - Abas e Painéis
@onready var tab_host_btn: Button = $CenterContainer/MainPanel/Margin/ContentVBox/ConnectionSection/RightColumn/MultiplayerCard/Margin/VBox/TabButtons/TabHostButton
@onready var tab_join_btn: Button = $CenterContainer/MainPanel/Margin/ContentVBox/ConnectionSection/RightColumn/MultiplayerCard/Margin/VBox/TabButtons/TabJoinButton
@onready var host_panel: VBoxContainer = $CenterContainer/MainPanel/Margin/ContentVBox/ConnectionSection/RightColumn/MultiplayerCard/Margin/VBox/HostPanel
@onready var join_panel: VBoxContainer = $CenterContainer/MainPanel/Margin/ContentVBox/ConnectionSection/RightColumn/MultiplayerCard/Margin/VBox/JoinPanel

# Host Controls
@onready var host_port_input: LineEdit = $CenterContainer/MainPanel/Margin/ContentVBox/ConnectionSection/RightColumn/MultiplayerCard/Margin/VBox/HostPanel/PortRow/PortInput
@onready var host_btn: Button = $CenterContainer/MainPanel/Margin/ContentVBox/ConnectionSection/RightColumn/MultiplayerCard/Margin/VBox/HostPanel/HostButton

# Join Controls
@onready var join_ip_input: LineEdit = $CenterContainer/MainPanel/Margin/ContentVBox/ConnectionSection/RightColumn/MultiplayerCard/Margin/VBox/JoinPanel/IPRow/IPInput
@onready var join_port_input: LineEdit = $CenterContainer/MainPanel/Margin/ContentVBox/ConnectionSection/RightColumn/MultiplayerCard/Margin/VBox/JoinPanel/JoinPortRow/JoinPortInput
@onready var join_btn: Button = $CenterContainer/MainPanel/Margin/ContentVBox/ConnectionSection/RightColumn/MultiplayerCard/Margin/VBox/JoinPanel/JoinButton

# Sala de Espera (Room)
@onready var room_title: Label = $CenterContainer/MainPanel/Margin/ContentVBox/RoomSection/RoomHeader/RoomTitle
@onready var player_list_container: VBoxContainer = $CenterContainer/MainPanel/Margin/ContentVBox/RoomSection/PlayerList
@onready var map_option: OptionButton = $CenterContainer/MainPanel/Margin/ContentVBox/RoomSection/MapChoiceRow/MapOption
@onready var leave_btn: Button = $CenterContainer/MainPanel/Margin/ContentVBox/RoomSection/ActionRow/LeaveButton
@onready var ready_btn: Button = $CenterContainer/MainPanel/Margin/ContentVBox/RoomSection/ActionRow/ReadyButton
@onready var start_btn: Button = $CenterContainer/MainPanel/Margin/ContentVBox/RoomSection/ActionRow/StartButton

# Header e Footer
@onready var back_to_menu_btn: Button = $HeaderBar/HBox/BackToMenuBtn
@onready var mode_toggle_btn: Button = $HeaderBar/HBox/ModeToggleBtn
@onready var status_label: Label = $FooterBar/StatusLabel

# Variáveis internas do Perfil
var user_portrait: CharacterPortrait
var color_swatch_buttons: Array[Button] = []
var selected_color_index: int = 0

func _ready() -> void:
	_setup_profile_avatar()
	_setup_color_swatches()
	_apply_menu_style()
	_setup_tabs()
	_setup_mode_toggle()
	
	back_to_menu_btn.pressed.connect(_on_back_to_menu_pressed)
	
	# Sinais de rede
	NetworkManager.lobby_updated.connect(_update_lobby_ui)
	NetworkManager.status_message.connect(_on_status_message)
	NetworkManager.map_selection_updated.connect(_on_map_selection_updated)
	
	# Opções de Mapa
	map_option.clear()
	map_option.add_item("ALEATÓRIO (RECOMENDADO)", -1)
	for map_index in range(GameState.MAP_NAMES.size()):
		map_option.add_item(GameState.MAP_NAMES[map_index], map_index)
	map_option.item_selected.connect(_on_map_option_selected)
	
	# Botões de Ação
	campaign_btn.pressed.connect(_on_campaign_pressed)
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	ready_btn.pressed.connect(_on_ready_pressed)
	start_btn.pressed.connect(_on_start_pressed)
	leave_btn.pressed.connect(_on_leave_pressed)
	
	# Sincroniza apelido inicial padrão
	name_input.text = "Jogador_%d" % randi_range(100, 999)
	name_input.text_changed.connect(_on_name_changed)
	
	_show_connection_view()
	_update_lobby_ui()
	
	var all_args: PackedStringArray = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if "--run-test" in all_args:
		call_deferred("_run_self_test")

func _run_self_test() -> void:
	print("--- INICIANDO AUTO-TESTE DO NOVO LOBBY ---")
	assert(main_panel != null, "main_panel nulo")
	assert(profile_card != null, "profile_card nulo")
	assert(campaign_card != null, "campaign_card nulo")
	assert(multiplayer_card != null, "multiplayer_card nulo")
	assert(host_panel.visible == true, "host_panel deve iniciar visível")
	assert(join_panel.visible == false, "join_panel deve iniciar invisível")
	assert(user_portrait != null, "user_portrait nulo")
	assert(color_swatch_buttons.size() == 4, "esperado 4 botões de cores")
	
	print("[Lobby Test] Testando seleção de cor 2 (Verde)...")
	_select_player_color(2)
	assert(selected_color_index == 2, "cor 2 não selecionada")
	assert(NetworkManager.preferred_color_index == 2, "cor no NetworkManager não sincronizada")
	
	print("[Lobby Test] Testando troca de aba para Join...")
	_switch_mp_tab(false)
	assert(host_panel.visible == false, "host_panel deve estar oculto")
	assert(join_panel.visible == true, "join_panel deve estar visível")
	
	print("[Lobby Test] Testando alternância de F10 modo melhorado...")
	var initial_mode: bool = GameState.is_enhanced()
	GameState.toggle_enhanced_mode()
	assert(GameState.is_enhanced() != initial_mode, "modo não alternou")
	_update_mode_button_state()
	print("[Lobby Test] Texto do botão após toggle: ", mode_toggle_btn.text)
	if GameState.is_enhanced() != initial_mode:
		GameState.toggle_enhanced_mode()
	
	print("--- AUTO-TESTE DO LOBBY CONCLUÍDO COM 100% DE SUCESSO! ---")
	get_tree().quit(0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F10:
			GameState.toggle_enhanced_mode()
			_update_mode_button_state()

# ----------------- PERFIL E CUSTOMIZAÇÃO DE CORES -----------------

func _setup_profile_avatar() -> void:
	user_portrait = CharacterPortrait.new()
	user_portrait.custom_minimum_size = Vector2(48, 48)
	user_portrait.player_color = Player.PLAYER_COLORS[selected_color_index]
	portrait_box.add_child(user_portrait)

func _setup_color_swatches() -> void:
	for child in colors_box.get_children():
		child.queue_free()
	color_swatch_buttons.clear()
	
	for i in range(Player.PLAYER_COLORS.size()):
		var col: Color = Player.PLAYER_COLORS[i]
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(28, 28)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.tooltip_text = "Cor %d" % (i + 1)
		
		var idx: int = i
		btn.pressed.connect(func():
			_select_player_color(idx)
		)
		colors_box.add_child(btn)
		color_swatch_buttons.append(btn)
	
	_update_color_swatches_ui()

func _select_player_color(idx: int) -> void:
	AudioManager.play_click()
	selected_color_index = idx
	NetworkManager.preferred_color_index = idx
	if user_portrait:
		user_portrait.player_color = Player.PLAYER_COLORS[selected_color_index]
		user_portrait.queue_redraw()
	_update_color_swatches_ui()

func _update_color_swatches_ui() -> void:
	for i in range(color_swatch_buttons.size()):
		var btn: Button = color_swatch_buttons[i]
		var col: Color = Player.PLAYER_COLORS[i]
		var is_selected: bool = (i == selected_color_index)
		
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = col
		style.set_corner_radius_all(14)
		if is_selected:
			style.border_color = Color.WHITE
			style.set_border_width_all(3)
			style.shadow_color = col.lightened(0.2)
			style.shadow_size = 4
		else:
			style.border_color = Color(0.15, 0.2, 0.28, 0.8)
			style.set_border_width_all(1)
		
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)

func _on_name_changed(new_text: String) -> void:
	var clean: String = new_text.strip_edges()
	NetworkManager.local_player_name = clean if not clean.is_empty() else "Jogador"

# ----------------- ABAS MULTIPLAYER (HOST vs JOIN) -----------------

func _setup_tabs() -> void:
	tab_host_btn.pressed.connect(func():
		AudioManager.play_click()
		_switch_mp_tab(true)
	)
	tab_join_btn.pressed.connect(func():
		AudioManager.play_click()
		_switch_mp_tab(false)
	)
	_switch_mp_tab(true)

func _switch_mp_tab(show_host: bool) -> void:
	host_panel.visible = show_host
	join_panel.visible = not show_host
	
	var active_style: StyleBoxFlat = StyleBoxFlat.new()
	active_style.bg_color = Color(0.14, 0.24, 0.38, 0.95)
	active_style.border_color = Color(0.35, 0.65, 0.95, 0.9)
	active_style.set_border_width_all(1)
	active_style.border_width_bottom = 3
	active_style.set_corner_radius_all(8)
	
	var inactive_style: StyleBoxFlat = StyleBoxFlat.new()
	inactive_style.bg_color = Color(0.06, 0.09, 0.14, 0.6)
	inactive_style.border_color = Color(0.18, 0.25, 0.35, 0.4)
	inactive_style.set_border_width_all(1)
	inactive_style.set_corner_radius_all(8)
	
	if show_host:
		tab_host_btn.add_theme_stylebox_override("normal", active_style)
		tab_host_btn.add_theme_color_override("font_color", Color(0.9, 0.96, 1.0))
		tab_join_btn.add_theme_stylebox_override("normal", inactive_style)
		tab_join_btn.add_theme_color_override("font_color", Color(0.55, 0.65, 0.78))
	else:
		tab_join_btn.add_theme_stylebox_override("normal", active_style)
		tab_join_btn.add_theme_color_override("font_color", Color(0.9, 0.96, 1.0))
		tab_host_btn.add_theme_stylebox_override("normal", inactive_style)
		tab_host_btn.add_theme_color_override("font_color", Color(0.55, 0.65, 0.78))

# ----------------- BOTÃO MODO MELHORADO (HEADER) -----------------

func _setup_mode_toggle() -> void:
	mode_toggle_btn.pressed.connect(func():
		AudioManager.play_click()
		GameState.toggle_enhanced_mode()
		_update_mode_button_state()
	)
	GameState.enhanced_mode_toggled.connect(func(_is_enhanced: bool):
		_update_mode_button_state()
	)
	_update_mode_button_state()

func _update_mode_button_state() -> void:
	if not mode_toggle_btn:
		return
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	if GameState.is_enhanced():
		mode_toggle_btn.text = "⚡ MODO MELHORADO [F10]"
		style.bg_color = Color(0.1, 0.35, 0.28, 0.85)
		style.border_color = Color(0.3, 0.95, 0.68, 0.8)
		style.set_border_width_all(1)
		mode_toggle_btn.modulate = Color(0.9, 1.0, 0.95)
	else:
		mode_toggle_btn.text = "⚙️ MODO BASE [F10]"
		style.bg_color = Color(0.12, 0.16, 0.22, 0.7)
		style.border_color = Color(0.3, 0.38, 0.5, 0.6)
		style.set_border_width_all(1)
		mode_toggle_btn.modulate = Color(0.85, 0.88, 0.92)
	mode_toggle_btn.add_theme_stylebox_override("normal", style)
	mode_toggle_btn.add_theme_stylebox_override("hover", style)
	mode_toggle_btn.add_theme_stylebox_override("pressed", style)

# ----------------- DESIGN & ESTILIZAÇÃO DO MENU -----------------

func _apply_menu_style() -> void:
	# Painel Central com Glassmorphism elegante
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.065, 0.09, 0.14, 0.95)
	panel_style.border_color = Color(0.25, 0.38, 0.55, 0.85)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(18)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	panel_style.shadow_size = 24
	main_panel.add_theme_stylebox_override("panel", panel_style)
	
	# Estilo para os 3 Cards de Conteúdo
	_style_card(profile_card, Color(0.08, 0.11, 0.17, 0.9), Color(0.25, 0.42, 0.62, 0.6))
	_style_card(campaign_card, Color(0.09, 0.11, 0.16, 0.9), Color(0.78, 0.52, 0.2, 0.75))
	_style_card(multiplayer_card, Color(0.08, 0.11, 0.17, 0.9), Color(0.2, 0.55, 0.75, 0.75))
	
	# Estilos dos Botões de Ação Principais
	_style_button(campaign_btn, Color(0.72, 0.42, 0.14), Color(0.92, 0.58, 0.22), true)
	_style_button(host_btn, Color(0.14, 0.48, 0.82), Color(0.24, 0.65, 0.98), true)
	_style_button(join_btn, Color(0.12, 0.58, 0.48), Color(0.22, 0.76, 0.64), true)
	_style_button(ready_btn, Color(0.14, 0.56, 0.4), Color(0.24, 0.76, 0.54), true)
	_style_button(start_btn, Color(0.78, 0.36, 0.14), Color(0.96, 0.54, 0.22), true)
	_style_button(leave_btn, Color(0.22, 0.26, 0.35), Color(0.38, 0.44, 0.56), false)
	
	# Estilização dos campos LineEdit
	for input in [name_input, host_port_input, join_ip_input, join_port_input]:
		var input_style: StyleBoxFlat = StyleBoxFlat.new()
		input_style.bg_color = Color(0.04, 0.06, 0.1, 0.9)
		input_style.border_color = Color(0.2, 0.3, 0.44, 0.8)
		input_style.set_border_width_all(1)
		input_style.set_corner_radius_all(8)
		input_style.content_margin_left = 12
		input_style.content_margin_right = 12
		input.add_theme_stylebox_override("normal", input_style)
		input.add_theme_stylebox_override("focus", input_style)
	
	# Estilo do Seletor de Mapa
	var opt_style: StyleBoxFlat = StyleBoxFlat.new()
	opt_style.bg_color = Color(0.04, 0.06, 0.1, 0.9)
	opt_style.border_color = Color(0.2, 0.3, 0.44, 0.8)
	opt_style.set_border_width_all(1)
	opt_style.set_corner_radius_all(8)
	opt_style.content_margin_left = 12
	opt_style.content_margin_right = 12
	map_option.add_theme_stylebox_override("normal", opt_style)

func _style_card(card: PanelContainer, bg: Color, border: Color) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	card.add_theme_stylebox_override("panel", style)

func _style_button(button: Button, color: Color, hover_color: Color, is_bold: bool) -> void:
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(10)
	normal.shadow_color = Color(0, 0, 0, 0.3)
	normal.shadow_size = 4
	
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = hover_color
	hover.shadow_size = 6
	
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = color.darkened(0.2)
	pressed.shadow_size = 1
	
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(0.98, 0.99, 1.0))
	button.add_theme_font_size_override("font_size", 14 if not is_bold else 15)

# ----------------- VISIBILIDADE DE TELAS -----------------

func _show_connection_view() -> void:
	connection_panel.visible = true
	room_panel.visible = false
	status_label.text = "Pronto para conectar ou criar sala."
	status_label.modulate = Color(0.75, 0.85, 0.98)

func _show_room_view() -> void:
	connection_panel.visible = false
	room_panel.visible = true

# ----------------- HANDLERS DE AÇÕES -----------------

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

func _on_host_pressed() -> void:
	AudioManager.play_click()
	var player_name: String = name_input.text.strip_edges()
	NetworkManager.local_player_name = player_name if not player_name.is_empty() else "Host"
	NetworkManager.preferred_color_index = selected_color_index
	var port: int = int(host_port_input.text) if host_port_input.text.is_valid_int() else NetworkManager.DEFAULT_PORT
	
	var err: Error = NetworkManager.create_server(port)
	if err == OK:
		_show_room_view()
		NetworkManager.set_selected_map_style(-1)
		GameState.game_mode = GameState.GameMode.BATTLE

func _on_join_pressed() -> void:
	AudioManager.play_click()
	GameState.game_mode = GameState.GameMode.BATTLE
	var player_name: String = name_input.text.strip_edges()
	NetworkManager.local_player_name = player_name if not player_name.is_empty() else "Cliente"
	NetworkManager.preferred_color_index = selected_color_index
	var ip: String = join_ip_input.text.strip_edges()
	var port: int = int(join_port_input.text) if join_port_input.text.is_valid_int() else NetworkManager.DEFAULT_PORT
	
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

func _on_back_to_menu_pressed() -> void:
	AudioManager.play_click()
	if multiplayer.has_multiplayer_peer():
		NetworkManager.disconnect_from_server()
	TransitionManager.change_scene("res://scenes/main_menu.tscn")

# ----------------- SINCRONIZAÇÃO DA SALA DE ESPERA -----------------

func _update_lobby_ui() -> void:
	if NetworkManager.peer == null or NetworkManager.players.is_empty():
		_show_connection_view()
		return
	
	_show_room_view()
	
	var is_host: bool = multiplayer.is_server()
	room_title.text = "SALA DE ESPERA   ·   %d/4 JOGADORES CONECTADOS" % NetworkManager.players.size()
	
	# Limpa slots anteriores
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
			_create_empty_slot(slot + 1)
	
	# Atualiza botão de "Pronto"
	if NetworkManager.players.has(my_id):
		var am_ready: bool = NetworkManager.players[my_id].get("is_ready", false)
		ready_btn.text = "CANCELAR PRONTO" if am_ready else "ESTOU PRONTO"
		ready_btn.modulate = Color(1.0, 0.72, 0.72) if am_ready else Color.WHITE
	
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
	card.custom_minimum_size = Vector2(0, 58)
	
	var card_style: StyleBoxFlat = StyleBoxFlat.new()
	card_style.bg_color = Color(0.08, 0.12, 0.18, 0.95)
	card_style.border_color = accent
	card_style.border_width_left = 5
	card_style.set_corner_radius_all(10)
	card_style.shadow_color = Color(0, 0, 0, 0.25)
	card_style.shadow_size = 4
	card.add_theme_stylebox_override("panel", card_style)
	
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Retrato
	var portrait: CharacterPortrait = CharacterPortrait.new()
	portrait.custom_minimum_size = Vector2(44, 46)
	portrait.player_color = accent
	row.add_child(portrait)
	
	# Informações de Nome e Cargo
	var details: VBoxContainer = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var name_label: Label = Label.new()
	var name_str: String = player_info.get("name", "Jogador")
	name_label.text = "%s%s" % [name_str, "  (VOCÊ)" if is_you else ""]
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	
	var role_label: Label = Label.new()
	role_label.text = "LÍDER DA SALA (HOST)" if peer_id == 1 else "DESAFIANTE %d" % (color_idx + 1)
	role_label.add_theme_font_size_override("font_size", 11)
	role_label.add_theme_color_override("font_color", Color(0.55, 0.68, 0.85))
	
	details.add_child(name_label)
	details.add_child(role_label)
	row.add_child(details)
	
	# Indicador de Pronto
	var is_player_ready: bool = bool(player_info.get("is_ready", false))
	var badge: Label = Label.new()
	badge.text = "PRONTO  ✓" if is_player_ready else "AGUARDANDO..."
	badge.add_theme_font_size_override("font_size", 12)
	badge.add_theme_color_override("font_color", Color(0.35, 0.95, 0.65) if is_player_ready else Color(0.96, 0.72, 0.35))
	row.add_child(badge)
	
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	margin.add_child(row)
	card.add_child(margin)
	
	player_list_container.add_child(card)

func _create_empty_slot(slot_number: int) -> void:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 58)
	
	var card_style: StyleBoxFlat = StyleBoxFlat.new()
	card_style.bg_color = Color(0.05, 0.075, 0.12, 0.6)
	card_style.border_color = Color(0.16, 0.22, 0.32, 0.5)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(10)
	card.add_theme_stylebox_override("panel", card_style)
	
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var portrait: CharacterPortrait = CharacterPortrait.new()
	portrait.custom_minimum_size = Vector2(44, 46)
	portrait.player_color = Color(0.24, 0.3, 0.38)
	row.add_child(portrait)
	
	var slot_label: Label = Label.new()
	slot_label.text = "VAGA #%d DISPONÍVEL" % slot_number
	slot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_label.add_theme_font_size_override("font_size", 13)
	slot_label.add_theme_color_override("font_color", Color(0.42, 0.52, 0.65))
	row.add_child(slot_label)
	
	var wait_label: Label = Label.new()
	wait_label.text = "Livre"
	wait_label.add_theme_font_size_override("font_size", 11)
	wait_label.add_theme_color_override("font_color", Color(0.35, 0.45, 0.55))
	row.add_child(wait_label)
	
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	margin.add_child(row)
	card.add_child(margin)
	
	player_list_container.add_child(card)

func _on_status_message(text: String, is_error: bool) -> void:
	status_label.text = text
	status_label.modulate = Color(1.0, 0.4, 0.4) if is_error else Color(0.6, 1.0, 0.8)
