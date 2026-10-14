class_name HowToPlayModal
extends Control

## Modal explicativo "Como Jogar" (Itens, Inimigos, Controles e Portais).

signal closed

@onready var panel: PanelContainer = $CenterContainer/Panel
@onready var close_btn: Button = $CenterContainer/Panel/Margin/VBox/CloseButton
@onready var tab_controls_btn: Button = $CenterContainer/Panel/Margin/VBox/TabsHBox/ControlsTabBtn
@onready var tab_items_btn: Button = $CenterContainer/Panel/Margin/VBox/TabsHBox/ItemsTabBtn
@onready var tab_enemies_btn: Button = $CenterContainer/Panel/Margin/VBox/TabsHBox/EnemiesTabBtn
@onready var tab_portals_btn: Button = $CenterContainer/Panel/Margin/VBox/TabsHBox/PortalsTabBtn

@onready var controls_view: VBoxContainer = $CenterContainer/Panel/Margin/VBox/ContentScroll/ControlsView
@onready var items_view: VBoxContainer = $CenterContainer/Panel/Margin/VBox/ContentScroll/ItemsView
@onready var enemies_view: VBoxContainer = $CenterContainer/Panel/Margin/VBox/ContentScroll/EnemiesView
@onready var portals_view: VBoxContainer = $CenterContainer/Panel/Margin/VBox/ContentScroll/PortalsView

var active_tab: int = 0

func _ready() -> void:
	visible = false
	modulate.a = 0.0
	close_btn.pressed.connect(close)
	tab_controls_btn.pressed.connect(func(): _switch_tab(0))
	tab_items_btn.pressed.connect(func(): _switch_tab(1))
	tab_enemies_btn.pressed.connect(func(): _switch_tab(2))
	tab_portals_btn.pressed.connect(func(): _switch_tab(3))
	_switch_tab(0)

func open() -> void:
	AudioManager.play_menu_open()
	_switch_tab(0)
	visible = true
	close_btn.grab_focus()
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

func _switch_tab(idx: int) -> void:
	AudioManager.play_click()
	active_tab = idx
	controls_view.visible = idx == 0
	items_view.visible = idx == 1
	enemies_view.visible = idx == 2
	portals_view.visible = idx == 3
	
	_style_tab_btn(tab_controls_btn, idx == 0)
	_style_tab_btn(tab_items_btn, idx == 1)
	_style_tab_btn(tab_enemies_btn, idx == 2)
	_style_tab_btn(tab_portals_btn, idx == 3)

func _style_tab_btn(btn: Button, is_active: bool) -> void:
	btn.modulate = Color(1.0, 0.9, 0.4) if is_active else Color(0.7, 0.75, 0.85)
