class_name InGameHUD
extends Control

## HUD Principal da Partida (Interface de Jogo).
## Exibe:
## - Cronômetro regressivo da rodada (sincronizado pelo servidor)
## - Número da rodada atual e meta da melhor de 3
## - Cartões de status dos jogadores (Cor, Nome, Vivo/Morto, Bombas, Fogo e Velocidade)

@onready var timer_label: Label = $TopBar/BarLayout/CenterBox/TimerLabel
@onready var round_label: Label = $TopBar/BarLayout/CenterBox/RoundLabel
@onready var map_label: Label = $TopBar/BarLayout/CenterBox/MapLabel
@onready var campaign_label: Label = $TopBar/BarLayout/CenterBox/CampaignLabel
@onready var campaign_help: Label = $CampaignHelp
@onready var players_card_container: HBoxContainer = $TopBar/BarLayout/LeftBox/PlayerCards
@onready var pause_panel: CenterContainer = $PauseOverlay

signal leave_match_requested

var player_card_nodes: Dictionary = {} # peer_id -> PanelContainer
var mode_toggle_btn: Button
var toast_label: Label
var toast_tween: Tween

func update_pause_status(is_online: bool) -> void:
	var title: Label = $PauseOverlay/Panel/Margin/VBox/PauseTitle
	var note: Label = $PauseOverlay/Panel/Margin/VBox/PauseNote
	title.text = "⏸ PAUSA LOCAL" if is_online else "⏸ JOGO PAUSADO"
	note.text = "A partida online continua para os outros jogadores." if is_online else "Cronômetro e inimigos estão pausados."

func _ready() -> void:
	pause_panel.visible = false
	var resume_btn: Button = $PauseOverlay/Panel/Margin/VBox/ResumeButton
	var exit_btn: Button = $PauseOverlay/Panel/Margin/VBox/ExitButton
	
	resume_btn.pressed.connect(func():
		AudioManager.play_click()
		get_tree().paused = false
		GameState.local_pause_menu_open = false
		pause_panel.visible = false
	)
	exit_btn.pressed.connect(func():
		AudioManager.play_click()
		get_tree().paused = false
		GameState.local_pause_menu_open = false
		leave_match_requested.emit()
	)

	_setup_mode_toggle_ui()
	GameState.enhanced_mode_toggled.connect(func(is_enhanced: bool) -> void:
		_update_mode_button_visual(is_enhanced)
	)

func _setup_mode_toggle_ui() -> void:
	mode_toggle_btn = Button.new()
	mode_toggle_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	mode_toggle_btn.custom_minimum_size = Vector2(155, 32)
	mode_toggle_btn.pressed.connect(func():
		AudioManager.play_click()
		var is_now_enhanced: bool = GameState.toggle_enhanced_mode()
		notify_mode_switch(is_now_enhanced)
	)
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
		mode_toggle_btn.text = "MELHORADO [F10]"
		mode_toggle_btn.modulate = Color(0.65, 1.0, 0.8)
	else:
		mode_toggle_btn.text = "BASE [F10]"
		mode_toggle_btn.modulate = Color(0.85, 0.85, 0.85)

func notify_mode_switch(is_enhanced: bool) -> void:
	_update_mode_button_visual(is_enhanced)
	if not toast_label:
		return
	if toast_tween and toast_tween.is_valid():
		toast_tween.kill()

	if is_enhanced:
		toast_label.text = "✨ MODO MELHORADO: Vento, partículas temáticas, faíscas e sinais visuais ativos"
		toast_label.add_theme_color_override("font_color", Color("a8f5b8"))
	else:
		toast_label.text = "⚙️ MODO BASE: apresentação visual original restaurada; controles inalterados"
		toast_label.add_theme_color_override("font_color", Color("f0e6b6"))

	toast_label.position.y = 66
	toast_tween = create_tween()
	toast_tween.tween_property(toast_label, "modulate:a", 1.0, 0.18)
	toast_tween.parallel().tween_property(toast_label, "position:y", 72.0, 0.18)
	toast_tween.tween_interval(2.2)
	toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.35)


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
		card.custom_minimum_size = Vector2(140, 48)
		
		var margin: MarginContainer = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 6)
		margin.add_theme_constant_override("margin_right", 6)
		margin.add_theme_constant_override("margin_top", 4)
		margin.add_theme_constant_override("margin_bottom", 4)
		card.add_child(margin)
		
		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		margin.add_child(vbox)
		
		# Linha de Cabeçalho: Bolinha de cor + Nome + Status Vivo
		var header_hbox: HBoxContainer = HBoxContainer.new()
		
		var swatch: ColorRect = ColorRect.new()
		swatch.custom_minimum_size = Vector2(12, 12)
		swatch.color = p_color
		header_hbox.add_child(swatch)
		
		var name_lbl: Label = Label.new()
		name_lbl.text = p_name
		name_lbl.name = "NameLbl"
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_hbox.add_child(name_lbl)
		
		var status_lbl: Label = Label.new()
		status_lbl.text = "❤️"
		status_lbl.name = "StatusLbl"
		status_lbl.add_theme_font_size_override("font_size", 12)
		header_hbox.add_child(status_lbl)
		
		vbox.add_child(header_hbox)
		
		# Linha de Atributos: Bombas, Fogo, Velocidade
		var stats_lbl: Label = Label.new()
		stats_lbl.name = "StatsLbl"
		stats_lbl.text = "💣1  🔥2  ⚡1.0"
		stats_lbl.add_theme_font_size_override("font_size", 11)
		stats_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
		vbox.add_child(stats_lbl)
		
		players_card_container.add_child(card)
		player_card_nodes[peer_id] = card

## Atualiza os atributos exibidos no cartão de um jogador específico
func update_player_card(peer_id: int, is_alive: bool, max_bombs: int, bomb_range: int, speed_mult: float, has_heart: bool = false) -> void:
	if not player_card_nodes.has(peer_id):
		return
	var card: PanelContainer = player_card_nodes[peer_id]
	var status_lbl: Label = card.find_child("StatusLbl", true, false)
	var stats_lbl: Label = card.find_child("StatsLbl", true, false)
	
	if status_lbl:
		status_lbl.text = "❤️" if is_alive else "💀"
	
	if stats_lbl:
		if is_alive:
			stats_lbl.text = "💣%d  🔥%d  ⚡%.1fx%s" % [max_bombs, bomb_range, speed_mult, "  ♥" if has_heart else ""]
			stats_lbl.modulate = Color.WHITE
			if GameState.is_enhanced():
				stats_lbl.pivot_offset = stats_lbl.size * 0.5
				var pop_tween: Tween = stats_lbl.create_tween()
				pop_tween.tween_property(stats_lbl, "scale", Vector2(1.15, 1.15), 0.08)
				pop_tween.tween_property(stats_lbl, "scale", Vector2.ONE, 0.12)
			else:
				stats_lbl.scale = Vector2.ONE
		else:
			stats_lbl.text = "ELIMINADO"
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
		timer_label.modulate = Color(1.0, 0.3, 0.3)
	else:
		timer_label.modulate = Color.WHITE

## Atualiza o texto da rodada
func update_round_info(round_num: int, wins_required: int) -> void:
	if not round_label:
		return
	if GameState.game_mode == GameState.GameMode.CAMPAIGN:
		round_label.text = "FASE %d DE %d" % [round_num, GameState.MAP_NAMES.size()]
	else:
		round_label.text = "RODADA %d (Melhor de %d)" % [round_num, (wins_required * 2) - 1]

func update_map_name(map_name: String) -> void:
	if map_label:
		map_label.text = map_name.to_upper()

func update_campaign_info(stage_number: int, stage_count: int, lives: int, should_show: bool = true) -> void:
	if campaign_label:
		campaign_label.visible = should_show
		campaign_label.text = "FASE %d/%d   ·   VIDAS %d" % [stage_number, stage_count, lives]
	if campaign_help:
		campaign_help.visible = should_show
		campaign_help.text = "DERROTE TODOS OS INIMIGOS  ·  WASD/SETAS/ANALÓGICO  ·  ESPAÇO/A BOMBA"

func update_campaign_objective(text: String) -> void:
	if campaign_help and campaign_help.visible:
		campaign_help.text = text

func set_campaign_help_visible(should_show: bool) -> void:
	if campaign_help:
		campaign_help.visible = should_show

## Abre/Fecha o menu de pausa
func toggle_pause_menu() -> void:
	if pause_panel:
		pause_panel.visible = not pause_panel.visible
