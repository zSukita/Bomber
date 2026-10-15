class_name InGameHUD
extends Control

## HUD Principal da Partida (Interface de Jogo).
## Exibe:
## - Cronômetro regressivo da rodada (sincronizado pelo servidor)
## - Número da rodada atual e meta da melhor de 3 / Fase da campanha
## - Cartões de status dos jogadores (Cor, Nome, Vivo/Morto, Vidas, Bombas, Fogo e Velocidade)
## - Indicador de objetivos da campanha (Inimigos restantes e portais)
## - Barra de dicas de controle elegante no rodapé

@onready var timer_label: Label = %TimerLabel if has_node("%TimerLabel") else get_node_or_null("TopBar/BarLayout/CenterBox/TimerLabel")
@onready var round_label: Label = %RoundLabel if has_node("%RoundLabel") else get_node_or_null("TopBar/BarLayout/CenterBox/RoundLabel")
@onready var map_label: Label = %MapLabel if has_node("%MapLabel") else get_node_or_null("TopBar/BarLayout/CenterBox/MapLabel")
@onready var campaign_label: Label = %CampaignLabel if has_node("%CampaignLabel") else get_node_or_null("TopBar/BarLayout/CenterBox/CampaignLabel")
@onready var campaign_help: Label = %CampaignHelp if has_node("%CampaignHelp") else get_node_or_null("CampaignHelp")
@onready var players_card_container: HBoxContainer = %PlayerCards if has_node("%PlayerCards") else get_node_or_null("TopBar/BarLayout/LeftBox/PlayerCards")
@onready var pause_panel: CenterContainer = %PauseOverlay if has_node("%PauseOverlay") else get_node_or_null("PauseOverlay")
@onready var settings_modal: SettingsModal = %SettingsModal if has_node("%SettingsModal") else get_node_or_null("SettingsModal")
@onready var enemy_badge: PanelContainer = %EnemyBadge if has_node("%EnemyBadge") else null
@onready var enemy_label: Label = %EnemyLabel if has_node("%EnemyLabel") else null
@onready var pause_btn: Button = %PauseButton if has_node("%PauseButton") else null
@onready var right_box: HBoxContainer = %RightBox if has_node("%RightBox") else null

signal leave_match_requested

var player_card_nodes: Dictionary = {} # peer_id -> PanelContainer
var mode_toggle_btn: Button
var toast_label: Label
var toast_tween: Tween
var current_enemy_count: int = -1

func update_pause_status(is_online: bool) -> void:
	var title: Label = $PauseOverlay/Panel/Margin/VBox/PauseTitle
	var note: Label = $PauseOverlay/Panel/Margin/VBox/PauseNote
	title.text = tr("HUD_PAUSE_LOCAL") if is_online else tr("PAUSE")
	note.text = tr("HUD_PAUSE_ONLINE_NOTE") if is_online else tr("HUD_PAUSE_NOTE")

func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	pause_panel.visible = false
	var resume_btn: Button = $PauseOverlay/Panel/Margin/VBox/ResumeButton
	var settings_btn: Button = $PauseOverlay/Panel/Margin/VBox/SettingsButton
	var exit_btn: Button = $PauseOverlay/Panel/Margin/VBox/ExitButton
	
	resume_btn.pressed.connect(func():
		AudioManager.play_click()
		get_tree().paused = false
		GameState.local_pause_menu_open = false
		pause_panel.visible = false
	)
	settings_btn.pressed.connect(func():
		AudioManager.play_click()
		if settings_modal:
			settings_modal.open()
	)
	exit_btn.pressed.connect(func():
		AudioManager.play_click()
		get_tree().paused = false
		GameState.local_pause_menu_open = false
		leave_match_requested.emit()
	)

	if pause_btn:
		pause_btn.pressed.connect(func():
			AudioManager.play_click()
			toggle_pause_menu()
		)

	_setup_mode_toggle_ui()
	GameState.enhanced_mode_toggled.connect(func(is_enhanced: bool) -> void:
		_update_mode_button_visual(is_enhanced)
	)

func _setup_mode_toggle_ui() -> void:
	mode_toggle_btn = Button.new()
	mode_toggle_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	mode_toggle_btn.custom_minimum_size = Vector2(130, 28)
	mode_toggle_btn.pressed.connect(func():
		AudioManager.play_click()
		var is_now_enhanced: bool = GameState.toggle_enhanced_mode()
		notify_mode_switch(is_now_enhanced)
	)
	if right_box:
		right_box.add_child(mode_toggle_btn)
		if pause_btn and pause_btn.get_parent() == right_box:
			right_box.move_child(mode_toggle_btn, max(0, right_box.get_child_count() - 2))
	elif has_node("TopBar/TopPanel/Margin/BarLayout"):
		$TopBar/TopPanel/Margin/BarLayout.add_child(mode_toggle_btn)
	elif has_node("TopBar/BarLayout"):
		$TopBar/BarLayout.add_child(mode_toggle_btn)
	_update_mode_button_visual(GameState.is_enhanced())

	toast_label = Label.new()
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 13)
	toast_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	toast_label.add_theme_constant_override("shadow_offset_x", 1)
	toast_label.add_theme_constant_override("shadow_offset_y", 1)
	toast_label.position = Vector2(0, 72)
	toast_label.size = Vector2(960, 26)
	toast_label.modulate.a = 0.0
	add_child(toast_label)

func _update_mode_button_visual(is_enhanced: bool) -> void:
	if not mode_toggle_btn:
		return
	if is_enhanced:
		mode_toggle_btn.text = tr("HUD_ENHANCED")
		mode_toggle_btn.modulate = Color(0.65, 1.0, 0.8)
	else:
		mode_toggle_btn.text = tr("HUD_BASE")
		mode_toggle_btn.modulate = Color(0.85, 0.85, 0.85)

func notify_mode_switch(is_enhanced: bool) -> void:
	_update_mode_button_visual(is_enhanced)
	if not toast_label:
		return
	if toast_tween and toast_tween.is_valid():
		toast_tween.kill()

	if is_enhanced:
		toast_label.text = tr("HUD_ENHANCED_TOAST")
		toast_label.add_theme_color_override("font_color", Color("a8f5b8"))
	else:
		toast_label.text = tr("HUD_BASE_TOAST")
		toast_label.add_theme_color_override("font_color", Color("f0e6b6"))

	toast_label.position.y = 66
	toast_tween = create_tween()
	toast_tween.tween_property(toast_label, "modulate:a", 1.0, 0.18)
	toast_tween.parallel().tween_property(toast_label, "position:y", 72.0, 0.18)
	toast_tween.tween_interval(2.2)
	toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.35)

func trigger_screen_shake(amount: float = 8.0) -> void:
	if not GameState.is_enhanced() or GameState.screen_shake_intensity <= 0.0:
		return
	var tw: Tween = create_tween()
	var offset_x: float = (randf() - 0.5) * amount * GameState.screen_shake_intensity
	var offset_y: float = (randf() - 0.5) * amount * GameState.screen_shake_intensity
	tw.tween_property(self, "position", Vector2(offset_x, offset_y), 0.04)
	tw.tween_property(self, "position", Vector2.ZERO, 0.08)

## Inicializa os cartões dos jogadores conectados
func setup_players(players_data: Dictionary) -> void:
	if not is_node_ready():
		await ready
	
	if not players_card_container:
		return
		
	for child in players_card_container.get_children():
		child.queue_free()
	player_card_nodes.clear()
	
	for peer_id in players_data:
		var p_info: Dictionary = players_data[peer_id]
		var color_idx: int = p_info.get("color_index", 0)
		var p_color: Color = Player.PLAYER_COLORS[color_idx % Player.PLAYER_COLORS.size()]
		var p_name: String = p_info.get("name", "Jogador")
		
		var card: PanelContainer = PanelContainer.new()
		card.custom_minimum_size = Vector2(148, 44)
		
		var card_style: StyleBoxFlat = StyleBoxFlat.new()
		card_style.bg_color = Color(0.08, 0.11, 0.17, 0.85)
		card_style.border_color = p_color.lerp(Color.WHITE, 0.35)
		card_style.border_width_left = 3
		card_style.border_width_top = 1
		card_style.border_width_right = 1
		card_style.border_width_bottom = 1
		card_style.corner_radius_top_left = 6
		card_style.corner_radius_top_right = 6
		card_style.corner_radius_bottom_left = 6
		card_style.corner_radius_bottom_right = 6
		card.add_theme_stylebox_override("panel", card_style)
		
		var margin: MarginContainer = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 6)
		margin.add_theme_constant_override("margin_right", 6)
		margin.add_theme_constant_override("margin_top", 3)
		margin.add_theme_constant_override("margin_bottom", 3)
		card.add_child(margin)
		
		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		margin.add_child(vbox)
		
		# Linha de Cabeçalho: Bolinha de cor + Nome + Status Vivo
		var header_hbox: HBoxContainer = HBoxContainer.new()
		
		var swatch: ColorRect = ColorRect.new()
		swatch.custom_minimum_size = Vector2(10, 10)
		swatch.color = p_color
		header_hbox.add_child(swatch)
		
		var name_lbl: Label = Label.new()
		name_lbl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		name_lbl.text = p_name
		name_lbl.name = "NameLbl"
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_hbox.add_child(name_lbl)
		
		var status_lbl: Label = Label.new()
		status_lbl.text = "❤️"
		status_lbl.name = "StatusLbl"
		status_lbl.add_theme_font_size_override("font_size", 11)
		header_hbox.add_child(status_lbl)
		
		vbox.add_child(header_hbox)
		
		# Linha de Atributos: Bombas, Fogo, Velocidade
		var stats_lbl: Label = Label.new()
		stats_lbl.name = "StatsLbl"
		stats_lbl.text = "💣1  🔥2  ⚡1.0"
		stats_lbl.add_theme_font_size_override("font_size", 10)
		stats_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
		vbox.add_child(stats_lbl)
		
		players_card_container.add_child(card)
		player_card_nodes[peer_id] = card

## Atualiza os atributos exibidos no cartão de um jogador específico
func update_player_card(peer_id: int, is_alive: bool, max_bombs: int, bomb_range: int, speed_mult: float, has_heart: bool = false, has_kick: bool = false, has_pierce: bool = false, has_remote: bool = false, skull_curse: int = -1, mount_type: int = 0, has_ice: bool = false, has_thunder: bool = false) -> void:
	if not player_card_nodes.has(peer_id):
		return
	var card: PanelContainer = player_card_nodes[peer_id]
	var status_lbl: Label = card.find_child("StatusLbl", true, false)
	var stats_lbl: Label = card.find_child("StatsLbl", true, false)
	
	if status_lbl:
		status_lbl.text = "❤️" if is_alive else "💀"
	
	if stats_lbl:
		if is_alive:
			var heart_str: String = " ♥" if has_heart else ""
			var kick_str: String = " 🥾" if has_kick else ""
			var pierce_str: String = " 🏹" if has_pierce else ""
			var remote_str: String = " 📡" if has_remote else ""
			var curse_str: String = " ☠️" if skull_curse >= 0 else ""
			var ice_str: String = " ❄️" if has_ice else ""
			var thunder_str: String = " ⚡" if has_thunder else ""
			var mount_str: String = ""
			if mount_type == GameState.MountType.GREEN:
				mount_str = " 🦖(V)"
			elif mount_type == GameState.MountType.BLUE:
				mount_str = " 🦖(A)"
			elif mount_type == GameState.MountType.YELLOW:
				mount_str = " 🦖(D)"
			stats_lbl.text = "💣%d 🔥%d ⚡%.1f%s%s%s%s%s%s%s%s" % [max_bombs, bomb_range, speed_mult, heart_str, kick_str, pierce_str, remote_str, curse_str, ice_str, thunder_str, mount_str]
			stats_lbl.modulate = Color.WHITE if skull_curse < 0 else Color(1.3, 0.6, 1.4)
			if GameState.is_enhanced():
				stats_lbl.pivot_offset = stats_lbl.size * 0.5
				var pop_tween: Tween = stats_lbl.create_tween()
				pop_tween.tween_property(stats_lbl, "scale", Vector2(1.15, 1.15), 0.08)
				pop_tween.tween_property(stats_lbl, "scale", Vector2.ONE, 0.12)
			else:
				stats_lbl.scale = Vector2.ONE
		else:
			stats_lbl.text = tr("HUD_ELIMINATED")
			stats_lbl.modulate = Color(0.9, 0.3, 0.3)
			stats_lbl.scale = Vector2.ONE

## Atualiza o cronômetro central da rodada
func update_timer_display(seconds_left: int) -> void:
	if not timer_label:
		return
	var mins: int = int(float(seconds_left) / 60.0)
	var secs: int = seconds_left % 60
	timer_label.text = "%02d:%02d" % [mins, secs]
	
	if seconds_left <= 30:
		timer_label.modulate = Color(1.0, 0.28, 0.28)
		if GameState.is_enhanced() and seconds_left > 0 and seconds_left % 2 == 0:
			var tw: Tween = create_tween()
			tw.tween_property(timer_label, "scale", Vector2(1.1, 1.1), 0.08)
			tw.tween_property(timer_label, "scale", Vector2.ONE, 0.12)
	else:
		timer_label.modulate = Color.WHITE
		timer_label.scale = Vector2.ONE

## Atualiza o texto da rodada
func update_round_info(round_num: int, wins_required: int) -> void:
	if not round_label:
		return
	if GameState.game_mode == GameState.GameMode.CAMPAIGN:
		round_label.text = tr("HUD_ROUND_STAGE") % [round_num, GameState.MAP_NAMES.size()]
	else:
		round_label.text = tr("HUD_ROUND_MATCH") % [round_num, (wins_required * 2) - 1]

func update_map_name(map_name: String) -> void:
	if map_label:
		map_label.text = GameState.tr(map_name).to_upper()

func update_campaign_info(stage_number: int, stage_count: int, lives: int, should_show: bool = true) -> void:
	if campaign_label:
		campaign_label.visible = false
	if round_label:
		if should_show:
			round_label.text = tr("HUD_CAMPAIGN_STAGE") % [stage_number, stage_count, lives]
			round_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.38))
		else:
			round_label.remove_theme_color_override("font_color")
	if enemy_badge:
		enemy_badge.visible = should_show
	if campaign_help:
		campaign_help.visible = should_show
		campaign_help.text = tr("HUD_CAMPAIGN_HELP")

func update_campaign_objective(text: String) -> void:
	var regex: RegEx = RegEx.new()
	regex.compile(r"(\d+)")
	var match_result: RegExMatch = regex.search(text)
	var count: int = int(match_result.get_string(1)) if match_result else -1
	current_enemy_count = count

	if enemy_badge and enemy_label:
		enemy_badge.visible = true
		if count > 0:
			enemy_label.text = tr("HUD_ENEMIES_COUNT") % count
			enemy_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
			if campaign_help and campaign_help.visible:
				campaign_help.text = tr("HUD_CAMPAIGN_HELP")
		elif count == 0:
			enemy_label.text = tr("HUD_PORTAL_OPEN")
			enemy_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
			if campaign_help and campaign_help.visible:
				campaign_help.text = tr("GAME_PORTAL_HINT")
		else:
			enemy_label.text = ""
	elif campaign_help and campaign_help.visible:
		campaign_help.text = text

func set_campaign_help_visible(should_show: bool) -> void:
	if campaign_help:
		campaign_help.visible = should_show
	if enemy_badge:
		enemy_badge.visible = should_show and GameState.game_mode == GameState.GameMode.CAMPAIGN

## Abre/Fecha o menu de pausa
func toggle_pause_menu() -> void:
	if pause_panel:
		pause_panel.visible = not pause_panel.visible
