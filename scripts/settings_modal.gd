class_name SettingsModal
extends Control

## Modal tático de Configurações do jogo Bombástico.
## Controle de volume de áudio, tela cheia e modo gráfico melhorado.

signal closed

@onready var panel: PanelContainer = $CenterContainer/Panel
@onready var master_slider: HSlider = $CenterContainer/Panel/Margin/VBox/AudioSection/MasterRow/MasterSlider
@onready var music_slider: HSlider = $CenterContainer/Panel/Margin/VBox/AudioSection/MusicRow/MusicSlider
@onready var sfx_slider: HSlider = $CenterContainer/Panel/Margin/VBox/AudioSection/SFXRow/SFXSlider
@onready var fullscreen_check: CheckBox = $CenterContainer/Panel/Margin/VBox/VideoSection/FullscreenCheck
@onready var enhanced_check: CheckBox = $CenterContainer/Panel/Margin/VBox/VideoSection/EnhancedCheck
@onready var shake_slider: HSlider = $CenterContainer/Panel/Margin/VBox/VideoSection/ShakeRow/ShakeSlider
@onready var effects_slider: HSlider = $CenterContainer/Panel/Margin/VBox/VideoSection/EffectsRow/EffectsSlider
@onready var reduced_flashes_check: CheckBox = $CenterContainer/Panel/Margin/VBox/VideoSection/ReducedFlashesCheck
@onready var close_btn: Button = $CenterContainer/Panel/Margin/VBox/CloseButton

func _ready() -> void:
	visible = false
	modulate.a = 0.0
	
	close_btn.pressed.connect(close)
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
	GameState.enhanced_mode_toggled.connect(_sync_enhanced_check)
	GameState.user_preferences_loaded.connect(_sync_controls_from_active_settings)
	_sync_controls_from_active_settings()

func open() -> void:
	AudioManager.play_menu_open()
	_sync_controls_from_active_settings()
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
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	await tween.finished
	visible = false
	closed.emit()

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
