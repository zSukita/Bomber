class_name ProfileModal
extends Control

## Modal de Perfil e Estatísticas do Jogador no Bombástico.

signal closed

@onready var panel: PanelContainer = $CenterContainer/Panel
@onready var name_edit: LineEdit = $CenterContainer/Panel/Margin/VBox/NameRow/NameInput
@onready var wins_label: Label = $CenterContainer/Panel/Margin/VBox/StatsGrid/WinsValue
@onready var kills_label: Label = $CenterContainer/Panel/Margin/VBox/StatsGrid/KillsValue
@onready var matches_label: Label = $CenterContainer/Panel/Margin/VBox/StatsGrid/MatchesValue
@onready var winrate_label: Label = $CenterContainer/Panel/Margin/VBox/StatsGrid/WinRateValue
@onready var close_btn: Button = $CenterContainer/Panel/Margin/VBox/CloseButton

func _ready() -> void:
	visible = false
	modulate.a = 0.0
	close_btn.pressed.connect(close)
	name_edit.text_changed.connect(_on_name_changed)

func open() -> void:
	AudioManager.play_menu_open()
	name_edit.text = NetworkManager.local_player_name
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

func _on_name_changed(new_text: String) -> void:
	var clean: String = new_text.strip_edges()
	if not clean.is_empty():
		NetworkManager.local_player_name = clean
