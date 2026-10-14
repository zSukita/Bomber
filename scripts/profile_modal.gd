class_name ProfileModal
extends Control

## Modal de perfil local do jogador no Bombástico.

signal closed

@onready var panel: PanelContainer = $CenterContainer/Panel
@onready var name_edit: LineEdit = $CenterContainer/Panel/Margin/VBox/ProfileRow/NameColumn/NameInput
@onready var close_btn: Button = $CenterContainer/Panel/Margin/VBox/CloseButton
@onready var modal_avatar_frame: PanelContainer = $CenterContainer/Panel/Margin/VBox/ProfileRow/ModalAvatarFrame
@onready var modal_avatar_rect: TextureRect = $CenterContainer/Panel/Margin/VBox/ProfileRow/ModalAvatarFrame/ModalAvatarRect

var avatar_shader_mat: ShaderMaterial

func _ready() -> void:
	visible = false
	modulate.a = 0.0
	close_btn.pressed.connect(close)
	name_edit.text_changed.connect(_on_name_changed)
	
	var shader := load("res://shaders/suit_tint.gdshader") as Shader
	if shader:
		avatar_shader_mat = ShaderMaterial.new()
		avatar_shader_mat.shader = shader
		avatar_shader_mat.set_shader_parameter("tint_strength", 0.88)
		modal_avatar_rect.material = avatar_shader_mat

func open() -> void:
	AudioManager.play_menu_open()
	name_edit.text = NetworkManager.local_player_name
	
	var suit_idx: int = NetworkManager.preferred_color_index
	if avatar_shader_mat:
		avatar_shader_mat.set_shader_parameter("color_index", suit_idx)
	if modal_avatar_frame:
		var suit_col: Color = Player.PLAYER_COLORS[suit_idx]
		var a_style: StyleBoxFlat = StyleBoxFlat.new()
		a_style.bg_color = Color(0.03, 0.06, 0.11, 0.95)
		a_style.border_color = suit_col
		a_style.set_border_width_all(2)
		a_style.set_corner_radius_all(8)
		a_style.shadow_color = suit_col * Color(1, 1, 1, 0.45)
		a_style.shadow_size = 6
		modal_avatar_frame.add_theme_stylebox_override("panel", a_style)
		
	visible = true
	name_edit.grab_focus()
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
		GameState.save_user_preferences()
