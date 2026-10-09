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
	
	enhanced_check.button_pressed = GameState.is_enhanced()

func open() -> void:
	AudioManager.play_menu_open()
	visible = true
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
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value / 100.0))

func _on_music_changed(value: float) -> void:
	var vol_db: float = linear_to_db(value / 100.0)
	AudioManager.set_music_volume(vol_db)

func _on_sfx_changed(value: float) -> void:
	AudioManager.play_click()

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	AudioManager.play_click()
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_enhanced_toggled(toggled_on: bool) -> void:
	AudioManager.play_click()
	if toggled_on != GameState.is_enhanced():
		GameState.toggle_enhanced_mode()
