class_name MainMenu
extends Control

## Cena do Menu Principal Comercial do Bombástico.
## Layout tático retrô-moderno com profundidade 2.5D, Parallax pelo mouse,
## botões táteis chanfrados com glow, avatar e seletor de traje dinâmico,
## card de novidades com paginação, modals e áudio sintetizado.

# Camadas e Elementos Visuais
@onready var background_rect: TextureRect = $Background/ParallaxFar/BgTexture
@onready var character_node: Node2D = $CharacterRoot/Character
@onready var logo_rect: TextureRect = $UI/TopLeftLogo/LogoTexture

# Botões Principais
@onready var continue_btn: Button = $UI/MainButtons/ContinueButton
@onready var new_campaign_btn: Button = $UI/MainButtons/NewCampaignButton
@onready var multiplayer_btn: Button = $UI/MainButtons/MultiplayerButton

# Painel do Jogador
@onready var player_panel: PanelContainer = $UI/PlayerPanel
@onready var player_name_label: Label = $UI/PlayerPanel/Margin/VBox/ProfileRow/InfoVBox/NameLabel
@onready var color_swatches_box: HBoxContainer = $UI/PlayerPanel/Margin/VBox/SuitColorsBox/SwatchesRow

# Botões Topo e Rodapé
@onready var how_to_play_top_btn: Button = $UI/TopButtons/HowToPlayTopBtn
@onready var settings_top_btn: Button = $UI/TopButtons/SettingsTopBtn
@onready var profile_top_btn: Button = $UI/TopButtons/ProfileTopBtn
@onready var footer_exit_btn: Button = $UI/Footer/HBox/FooterExitBtn

# Card de Novidades
@onready var news_panel: PanelContainer = $UI/NewsPanel
@onready var news_title: Label = $UI/NewsPanel/Margin/VBox/NewsTitle
@onready var news_desc: Label = $UI/NewsPanel/Margin/VBox/NewsDesc
@onready var dots_label: Label = $UI/NewsPanel/Margin/VBox/DotsLabel

# Modais
@onready var settings_modal: Control = $SettingsModal
@onready var profile_modal: Control = $ProfileModal
@onready var how_to_play_modal: Control = $HowToPlayModal

# Controlador de Parallax
@onready var parallax_ctrl: Node = $ParallaxManager

var current_news_page: int = 0
var news_timer: float = 0.0
var color_buttons: Array[Button] = []
var selected_suit_idx: int = 0

const NEWS_PAGES: Array[Dictionary] = [
	{
		"title": "Campanha com rotas",
		"desc": "Explore doze mundos e escolha portais para definir seu final.",
		"dots": "●  ○  ○"
	},
	{
		"title": "Arena para quatro",
		"desc": "Partidas pela rede com até quatro jogadores, usando IP e porta.",
		"dots": "○  ●  ○"
	},
	{
		"title": "Servidor dedicado Linux",
		"desc": "Exporte um servidor dedicado para hospedar partidas de arena.",
		"dots": "○  ○  ●"
	}
]

var _intro_finished: bool = false
var _base_char_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	_apply_tactical_styles()
	_setup_player_data()
	_set_continue_available(GameState.has_campaign_save())
	_setup_suit_color_buttons()
	_setup_interactions()
	GameState.user_preferences_loaded.connect(_refresh_player_identity)
	settings_modal.closed.connect(_on_settings_closed)
	profile_modal.closed.connect(_on_profile_closed)
	(continue_btn if not continue_btn.disabled else new_campaign_btn).grab_focus()
	
	# Responsividade do herói central
	_update_character_layout()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# Música desativada para manter o lobby tranquilo
	AudioManager.stop_menu_music()
	
	# Executa animação de entrada cinemática
	_play_intro_animation()
	
	# Suporte a flag de teste automatizado
	var all_args: PackedStringArray = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if "--run-test" in all_args:
		call_deferred("_run_menu_self_test")
	elif "--run-screenshot" in all_args:
		call_deferred("_run_menu_screenshot")

func _on_viewport_size_changed() -> void:
	_update_character_layout()

func _update_character_layout() -> void:
	if not character_node:
		return
	var vp_size: Vector2 = get_viewport_rect().size
	_base_char_pos = Vector2(vp_size.x * 0.505, vp_size.y * 0.565)
	if _intro_finished:
		character_node.position = _base_char_pos
	var target_scale: float = clampf(vp_size.y / 920.0, 0.40, 0.68)
	var sprite: Sprite2D = character_node.get_node_or_null("Sprite")
	if sprite:
		sprite.scale = Vector2.ONE * target_scale

func _run_menu_screenshot() -> void:
	await get_tree().create_timer(0.9).timeout
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://main_menu_live.png")
	print("[SCREENSHOT] Salvo res://main_menu_live.png com dimensões: ", img.get_size())
	get_tree().quit(0)

func _process(delta: float) -> void:
	# Ciclo suave do card de novidades a cada 6 segundos
	news_timer += delta
	if news_timer >= 6.0:
		news_timer = 0.0
		_cycle_news()

# ----------------- INTRO CINEMÁTICA COM TWEENS -----------------

func _play_intro_animation() -> void:
	# Estado inicial invisível com deslocamento suave
	background_rect.modulate.a = 0.0
	logo_rect.modulate.a = 0.0
	logo_rect.position.y -= 30.0
	
	character_node.modulate.a = 0.0
	character_node.position = _base_char_pos + Vector2(0, 40.0)
	
	for btn in [continue_btn, new_campaign_btn, multiplayer_btn]:
		btn.modulate.a = 0.0
		btn.position.x -= 45.0
		
	player_panel.modulate.a = 0.0
	player_panel.position.x += 40.0
	
	news_panel.modulate.a = 0.0
	news_panel.position.y += 30.0
	
	# Tween sequencial
	var intro: Tween = create_tween()
	intro.set_parallel(true)
	intro.set_trans(Tween.TRANS_CUBIC)
	intro.set_ease(Tween.EASE_OUT)
	
	# 1. Fundo surge
	intro.tween_property(background_rect, "modulate:a", 1.0, 0.45)
	
	# 2. Logo desce
	intro.tween_property(logo_rect, "modulate:a", 1.0, 0.55).set_delay(0.1)
	intro.tween_property(logo_rect, "position:y", logo_rect.position.y + 30.0, 0.55).set_delay(0.1)
	
	# 3. Personagem surge de baixo
	intro.tween_property(character_node, "modulate:a", 1.0, 0.6).set_delay(0.2)
	intro.tween_property(character_node, "position:y", _base_char_pos.y, 0.6).set_delay(0.2)
	intro.finished.connect(func(): _intro_finished = true)
	
	# 4. Botões principais entram em cascata
	var delay_step: float = 0.28
	for btn: Button in [continue_btn, new_campaign_btn, multiplayer_btn]:
		intro.tween_property(btn, "modulate:a", 1.0, 0.45).set_delay(delay_step)
		intro.tween_property(btn, "position:x", btn.position.x + 45.0, 0.45).set_delay(delay_step)
		delay_step += 0.12
		
	# 5. Painéis laterais
	intro.tween_property(player_panel, "modulate:a", 1.0, 0.5).set_delay(0.4)
	intro.tween_property(player_panel, "position:x", player_panel.position.x - 40.0, 0.5).set_delay(0.4)
	
	intro.tween_property(news_panel, "modulate:a", 1.0, 0.5).set_delay(0.5)
	intro.tween_property(news_panel, "position:y", news_panel.position.y - 30.0, 0.5).set_delay(0.5)

# ----------------- CONFIGURAÇÃO DE DADOS E CORES -----------------

func _setup_player_data() -> void:
	player_name_label.text = NetworkManager.local_player_name.to_upper()

func _set_continue_available(available: bool) -> void:
	continue_btn.disabled = not available
	continue_btn.modulate = Color.WHITE if available else Color(0.48, 0.52, 0.58, 1.0)

func _refresh_player_identity() -> void:
	player_name_label.text = NetworkManager.local_player_name.to_upper()
	_select_suit_color(NetworkManager.preferred_color_index, false)

func _setup_suit_color_buttons() -> void:
	for child in color_swatches_box.get_children():
		child.queue_free()
	color_buttons.clear()
	
	for i in range(Player.PLAYER_COLORS.size()):
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(26, 26)
		btn.focus_mode = Control.FOCUS_ALL
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		var idx: int = i
		btn.pressed.connect(func():
			_select_suit_color(idx)
		)
		color_swatches_box.add_child(btn)
		color_buttons.append(btn)
		
	_select_suit_color(NetworkManager.preferred_color_index, false)

func _select_suit_color(idx: int, persist: bool = true) -> void:
	AudioManager.play_button_hover()
	selected_suit_idx = idx
	NetworkManager.preferred_color_index = idx
	if persist:
		GameState.save_user_preferences()
	
	if character_node:
		character_node.set_suit_color(idx)
		
	for i in range(color_buttons.size()):
		var btn: Button = color_buttons[i]
		var col: Color = Player.PLAYER_COLORS[i]
		var is_selected: bool = (i == selected_suit_idx)
		
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = col
		style.set_corner_radius_all(13)
		if is_selected:
			style.border_color = Color.WHITE
			style.set_border_width_all(3)
			style.shadow_color = col.lightened(0.3)
			style.shadow_size = 4
		else:
			style.border_color = Color(0.12, 0.18, 0.28, 0.8)
			style.set_border_width_all(1)
			
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)

func _cycle_news() -> void:
	current_news_page = (current_news_page + 1) % NEWS_PAGES.size()
	var page: Dictionary = NEWS_PAGES[current_news_page]
	
	var tween: Tween = create_tween()
	tween.tween_property(news_title, "modulate:a", 0.0, 0.15)
	await tween.finished
	
	news_title.text = page["title"]
	news_desc.text = page["desc"]
	dots_label.text = page["dots"]
	
	var tween_in: Tween = create_tween()
	tween_in.tween_property(news_title, "modulate:a", 1.0, 0.2)

# ----------------- INTERAÇÕES DOS BOTÕES -----------------

func _setup_interactions() -> void:
	continue_btn.pressed.connect(_on_continue_pressed)
	new_campaign_btn.pressed.connect(_on_new_campaign_pressed)
	multiplayer_btn.pressed.connect(_on_multiplayer_pressed)
	
	how_to_play_top_btn.pressed.connect(how_to_play_modal.open)
	settings_top_btn.pressed.connect(settings_modal.open)
	profile_top_btn.pressed.connect(profile_modal.open)
	profile_modal.closed.connect(_refresh_player_identity)
	how_to_play_modal.closed.connect(_on_how_to_play_closed)
	footer_exit_btn.pressed.connect(_on_exit_pressed)

func _on_how_to_play_closed() -> void:
	how_to_play_top_btn.grab_focus()

func _on_settings_closed() -> void:
	settings_top_btn.grab_focus()

func _on_profile_closed() -> void:
	profile_top_btn.grab_focus()

func _on_continue_pressed() -> void:
	if not GameState.load_campaign_progress():
		_set_continue_available(false)
		return
	GameState.game_mode = GameState.GameMode.CAMPAIGN
	TransitionManager.change_scene("res://scenes/game.tscn")

func _on_new_campaign_pressed() -> void:
	GameState.game_mode = GameState.GameMode.CAMPAIGN
	GameState.campaign_heart_stages.clear()
	GameState.start_new_campaign()
	_set_continue_available(true)
	TransitionManager.change_scene("res://scenes/game.tscn")

func _on_multiplayer_pressed() -> void:
	# Abre a sala/lobby de multiplayer
	TransitionManager.change_scene("res://scenes/lobby.tscn")

func _on_exit_pressed() -> void:
	AudioManager.play_button_click()
	TransitionManager.fade_out_and_quit()

# ----------------- DESIGN DE PAINÉIS TÁTICOS -----------------

func _apply_tactical_styles() -> void:
	# Estilo tático com cantos chanfrados para o Painel do Jogador
	var p_style: StyleBoxFlat = StyleBoxFlat.new()
	p_style.bg_color = Color(0.045, 0.08, 0.14, 0.88)
	p_style.border_color = Color("00d4ff")
	p_style.set_border_width_all(1)
	p_style.set_corner_radius_all(10)
	p_style.shadow_color = Color("0088cc") * Color(1, 1, 1, 0.22)
	p_style.shadow_size = 12
	player_panel.add_theme_stylebox_override("panel", p_style)
	
	# Estilo para o Card de Novidades
	var n_style: StyleBoxFlat = StyleBoxFlat.new()
	n_style.bg_color = Color(0.045, 0.08, 0.14, 0.88)
	n_style.border_color = Color("0088cc")
	n_style.set_border_width_all(1)
	n_style.set_corner_radius_all(10)
	n_style.shadow_color = Color(0, 0, 0, 0.4)
	n_style.shadow_size = 8
	news_panel.add_theme_stylebox_override("panel", n_style)
	
	# Estilo dos botões de topo (quadrados com borda neon)
	for btn: Button in [settings_top_btn, profile_top_btn]:
		var s: StyleBoxFlat = StyleBoxFlat.new()
		s.bg_color = Color(0.05, 0.10, 0.18, 0.85)
		s.border_color = Color("00d4ff")
		s.set_border_width_all(1)
		s.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", s)
		var sh: StyleBoxFlat = s.duplicate() as StyleBoxFlat
		sh.bg_color = Color(0.12, 0.22, 0.38, 0.95)
		sh.shadow_color = Color("00d4ff") * Color(1, 1, 1, 0.4)
		sh.shadow_size = 6
		btn.add_theme_stylebox_override("hover", sh)

# ----------------- AUTO-TESTE VIA CLI -----------------

func _run_menu_self_test() -> void:
	print("--- INICIANDO TESTE DO NOVO MAIN MENU COMERCIAL ---")
	assert(character_node != null, "Character não encontrado")
	assert(continue_btn != null, "ContinueButton não encontrado")
	assert(new_campaign_btn != null, "NewCampaignButton não encontrado")
	assert(multiplayer_btn != null, "MultiplayerButton não encontrado")
	assert(player_panel != null, "PlayerPanel não encontrado")
	assert(color_buttons.size() == 4, "Esperado 4 botões de traje")
	
	print("[Menu Test] Testando troca de cor do traje para 1 (Vermelho)...")
	_select_suit_color(1)
	assert(selected_suit_idx == 1, "Índice de traje não atualizado")
	assert(NetworkManager.preferred_color_index == 1, "Cor não replicada para NetworkManager")
	
	print("[Menu Test] Testando ciclo do card de novidades...")
	_cycle_news()
	assert(current_news_page == 1, "Página de novidades não avançou")
	
	print("--- TESTE DO MAIN MENU CONCLUÍDO COM 100% DE SUCESSO! ---")
	get_tree().quit(0)
