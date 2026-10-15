class_name SettingsModal
extends Control

## Modal tático de Configurações do jogo Bombástico.
## Controle de volume de áudio, gráficos, tela cheia e remapeamento completo de teclas.

signal closed

@onready var panel: PanelContainer = $CenterContainer/Panel
@onready var tab_audio_video_btn: Button = $CenterContainer/Panel/Margin/VBox/TabBar/TabAudioVideoBtn
@onready var tab_controls_btn: Button = $CenterContainer/Panel/Margin/VBox/TabBar/TabControlsBtn
@onready var audio_video_view: VBoxContainer = $CenterContainer/Panel/Margin/VBox/AudioVideoView
@onready var controls_view: VBoxContainer = $CenterContainer/Panel/Margin/VBox/ControlsView

# Controles de Áudio e Vídeo
@onready var master_slider: HSlider = $CenterContainer/Panel/Margin/VBox/AudioVideoView/AudioSection/MasterRow/MasterSlider
@onready var music_slider: HSlider = $CenterContainer/Panel/Margin/VBox/AudioVideoView/AudioSection/MusicRow/MusicSlider
@onready var sfx_slider: HSlider = $CenterContainer/Panel/Margin/VBox/AudioVideoView/AudioSection/SFXRow/SFXSlider
@onready var language_option: OptionButton = $CenterContainer/Panel/Margin/VBox/AudioVideoView/LanguageRow/LanguageOption
@onready var bot_difficulty_option: OptionButton = $CenterContainer/Panel/Margin/VBox/AudioVideoView/BotDifficultyRow/BotDifficultyOption
@onready var fullscreen_check: CheckBox = $CenterContainer/Panel/Margin/VBox/AudioVideoView/VideoSection/FullscreenCheck
@onready var enhanced_check: CheckBox = $CenterContainer/Panel/Margin/VBox/AudioVideoView/VideoSection/EnhancedCheck
@onready var shake_slider: HSlider = $CenterContainer/Panel/Margin/VBox/AudioVideoView/VideoSection/ShakeRow/ShakeSlider
@onready var effects_slider: HSlider = $CenterContainer/Panel/Margin/VBox/AudioVideoView/VideoSection/EffectsRow/EffectsSlider
@onready var reduced_flashes_check: CheckBox = $CenterContainer/Panel/Margin/VBox/AudioVideoView/VideoSection/ReducedFlashesCheck

# Botões de Remapeamento de Teclas
@onready var btn_move_up: Button = $CenterContainer/Panel/Margin/VBox/ControlsView/MoveUpRow/Btn
@onready var btn_move_down: Button = $CenterContainer/Panel/Margin/VBox/ControlsView/MoveDownRow/Btn
@onready var btn_move_left: Button = $CenterContainer/Panel/Margin/VBox/ControlsView/MoveLeftRow/Btn
@onready var btn_move_right: Button = $CenterContainer/Panel/Margin/VBox/ControlsView/MoveRightRow/Btn
@onready var btn_drop_bomb: Button = $CenterContainer/Panel/Margin/VBox/ControlsView/DropBombRow/Btn
@onready var btn_pause: Button = $CenterContainer/Panel/Margin/VBox/ControlsView/PauseRow/Btn
@onready var btn_reset_controls: Button = $CenterContainer/Panel/Margin/VBox/ControlsView/ResetControlsBtn

@onready var close_btn: Button = $CenterContainer/Panel/Margin/VBox/CloseButton
@onready var gamepad_info_card: PanelContainer = $CenterContainer/Panel/Margin/VBox/ControlsView/GamepadInfoCard

var listening_action: String = ""
var active_tab_index: int = 0

func _ready() -> void:
	visible = false
	modulate.a = 0.0
	
	if gamepad_info_card:
		var g_style := StyleBoxFlat.new()
		g_style.bg_color = Color(0.04, 0.08, 0.15, 0.8)
		g_style.border_color = Color("00d4ff") * Color(1, 1, 1, 0.5)
		g_style.set_border_width_all(1)
		g_style.set_corner_radius_all(6)
		gamepad_info_card.add_theme_stylebox_override("panel", g_style)
	
	close_btn.pressed.connect(close)
	tab_audio_video_btn.pressed.connect(func(): _switch_tab(0))
	tab_controls_btn.pressed.connect(func(): _switch_tab(1))
	
	# Idioma
	if language_option:
		language_option.clear()
		language_option.add_item("🇧🇷 Português (Brasil)", 0)
		language_option.add_item("🇺🇸 English", 1)
		language_option.add_item("🇪🇸 Español", 2)
		match GameState.current_locale:
			"en": language_option.selected = 1
			"es": language_option.selected = 2
			_: language_option.selected = 0
		language_option.item_selected.connect(_on_language_selected)
	
	# Dificuldade do Bot
	if bot_difficulty_option:
		bot_difficulty_option.clear()
		bot_difficulty_option.add_item("Fácil", GameState.BotDifficulty.EASY)
		bot_difficulty_option.add_item("Médio", GameState.BotDifficulty.MEDIUM)
		bot_difficulty_option.add_item("Difícil (Mestre)", GameState.BotDifficulty.HARD)
		bot_difficulty_option.selected = int(GameState.bot_difficulty)
		bot_difficulty_option.item_selected.connect(_on_bot_difficulty_selected)
	
	# Áudio e Vídeo
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	master_slider.value_changed.connect(_on_master_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	enhanced_check.toggled.connect(_on_enhanced_toggled)
	shake_slider.value_changed.connect(_on_shake_changed)
	effects_slider.value_changed.connect(_on_effects_changed)
	reduced_flashes_check.toggled.connect(_on_reduced_flashes_toggled)
	
	shake_slider.value = GameState.screen_shake_intensity * 100.0
	effects_slider.value = GameState.visual_effects_intensity * 100.0
	reduced_flashes_check.button_pressed = GameState.reduced_flashes_enabled
	enhanced_check.set_pressed_no_signal(GameState.is_enhanced())
	
	# Controles
	btn_move_up.pressed.connect(func(): _start_listening("move_up", btn_move_up))
	btn_move_down.pressed.connect(func(): _start_listening("move_down", btn_move_down))
	btn_move_left.pressed.connect(func(): _start_listening("move_left", btn_move_left))
	btn_move_right.pressed.connect(func(): _start_listening("move_right", btn_move_right))
	btn_drop_bomb.pressed.connect(func(): _start_listening("drop_bomb", btn_drop_bomb))
	btn_pause.pressed.connect(func(): _start_listening("pause_game", btn_pause))
	btn_reset_controls.pressed.connect(_on_reset_controls_pressed)
	
	GameState.enhanced_mode_toggled.connect(_sync_enhanced_check)
	GameState.user_preferences_loaded.connect(_sync_controls_from_active_settings)
	GameState.keybindings_updated.connect(_update_keybind_buttons)
	
	_switch_tab(0)
	_sync_controls_from_active_settings()
	_update_keybind_buttons()

func open() -> void:
	AudioManager.play_menu_open()
	_switch_tab(0)
	_sync_controls_from_active_settings()
	_update_keybind_buttons()
	visible = true
	master_slider.grab_focus()
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.22)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.22).from(Vector2(0.9, 0.9))

func close() -> void:
	AudioManager.play_menu_back()
	listening_action = ""
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	await tween.finished
	visible = false
	closed.emit()

func _switch_tab(idx: int) -> void:
	AudioManager.play_click()
	listening_action = ""
	active_tab_index = idx
	audio_video_view.visible = idx == 0
	controls_view.visible = idx == 1
	
	tab_audio_video_btn.modulate = Color(1.2, 1.2, 1.2) if idx == 0 else Color(0.7, 0.7, 0.7)
	tab_controls_btn.modulate = Color(1.2, 1.2, 1.2) if idx == 1 else Color(0.7, 0.7, 0.7)
	_update_keybind_buttons()

func _input(event: InputEvent) -> void:
	if not visible or listening_action.is_empty():
		return
	
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		
		# Cancela o remapeamento se pressionar ESC em outra ação
		if code == KEY_ESCAPE and listening_action != "pause_game":
			listening_action = ""
			AudioManager.play_click()
			_update_keybind_buttons()
			get_viewport().set_input_as_handled()
			return
		
		GameState.rebind_action(listening_action, code)
		AudioManager.play_powerup()
		listening_action = ""
		_update_keybind_buttons()
		get_viewport().set_input_as_handled()

func _start_listening(action: String, button: Button) -> void:
	AudioManager.play_click()
	listening_action = action
	_update_keybind_buttons()
	button.text = "[ Pressione uma tecla... ]"
	button.modulate = Color(1.0, 0.9, 0.3)

func _update_keybind_buttons() -> void:
	if not is_node_ready():
		return
	
	var button_map: Dictionary = {
		"move_up": btn_move_up,
		"move_down": btn_move_down,
		"move_left": btn_move_left,
		"move_right": btn_move_right,
		"drop_bomb": btn_drop_bomb,
		"pause_game": btn_pause
	}
	
	for action in button_map:
		var btn: Button = button_map[action]
		if not is_instance_valid(btn):
			continue
		if listening_action == action:
			btn.text = "[ Pressione uma tecla... ]"
			btn.modulate = Color(1.0, 0.9, 0.3)
		else:
			btn.text = GameState.get_action_key_text(action)
			btn.modulate = Color.WHITE

func _on_reset_controls_pressed() -> void:
	AudioManager.play_click()
	listening_action = ""
	GameState.reset_default_keybindings()
	_update_keybind_buttons()

func _on_master_changed(value: float) -> void:
	var bus_idx: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_linear(bus_idx, value / 100.0)
	GameState.master_volume_percent = value
	GameState.save_user_preferences()

func _on_music_changed(value: float) -> void:
	AudioManager.set_music_volume(value / 100.0)
	GameState.music_volume_percent = value
	GameState.save_user_preferences()

func _on_sfx_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value / 100.0)
	GameState.sfx_volume_percent = value
	GameState.save_user_preferences()
	AudioManager.play_click()

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	AudioManager.play_click()
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	GameState.fullscreen_enabled = toggled_on
	GameState.save_user_preferences()

func _on_enhanced_toggled(toggled_on: bool) -> void:
	AudioManager.play_click()
	if toggled_on != GameState.is_enhanced():
		GameState.set_enhanced_mode(toggled_on)
	GameState.save_user_preferences()

func _sync_enhanced_check(is_enhanced: bool) -> void:
	if is_instance_valid(enhanced_check):
		enhanced_check.set_pressed_no_signal(is_enhanced)

func _on_language_selected(idx: int) -> void:
	AudioManager.play_click()
	match idx:
		1: GameState.set_game_locale("en")
		2: GameState.set_game_locale("es")
		_: GameState.set_game_locale("pt")

func _on_bot_difficulty_selected(idx: int) -> void:
	AudioManager.play_click()
	GameState.bot_difficulty = idx as GameState.BotDifficulty
	GameState.save_user_preferences()

func _on_shake_changed(value: float) -> void:
	GameState.screen_shake_intensity = clampf(value / 100.0, 0.0, 1.0)
	GameState.save_user_preferences()

func _on_effects_changed(value: float) -> void:
	GameState.visual_effects_intensity = clampf(value / 100.0, 0.0, 1.0)
	GameState.save_user_preferences()

func _on_reduced_flashes_toggled(enabled: bool) -> void:
	GameState.reduced_flashes_enabled = enabled
	GameState.save_user_preferences()

func _sync_controls_from_active_settings() -> void:
	if not is_node_ready():
		return
	if language_option:
		match GameState.current_locale:
			"en": language_option.selected = 1
			"es": language_option.selected = 2
			_: language_option.selected = 0
	if bot_difficulty_option:
		bot_difficulty_option.selected = int(GameState.bot_difficulty)
	master_slider.set_value_no_signal(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Master")) * 100.0)
	music_slider.set_value_no_signal(AudioManager.music_volume_scale * 100.0)
	sfx_slider.set_value_no_signal(AudioManager.sfx_volume_scale * 100.0)
	if DisplayServer.get_name() != "headless":
		fullscreen_check.set_pressed_no_signal(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		fullscreen_check.set_pressed_no_signal(GameState.fullscreen_enabled)
	enhanced_check.set_pressed_no_signal(GameState.is_enhanced())
	shake_slider.set_value_no_signal(GameState.screen_shake_intensity * 100.0)
	effects_slider.set_value_no_signal(GameState.visual_effects_intensity * 100.0)
	reduced_flashes_check.set_pressed_no_signal(GameState.reduced_flashes_enabled)
