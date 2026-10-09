class_name TacticalButton
extends Button

## Botão tático futurista de jogo comercial.
## Apresenta cantos chanfrados (hexágono/corte tático), borda em neon glow,
## ícone estilizado, texto principal em destaque, legenda secundária,
## e animações táteis suaves de escala com Tween e áudio integrado.

@export var primary_text: String = "CONTINUAR"
@export var secondary_text: String = "RETOMAR SUA JORNADA"
@export var icon_symbol: String = "▶"
@export var is_accent_gold: bool = false
@export var chamfer_size: float = 14.0

var is_hovered: bool = false
var is_active_pressed: bool = false
var glow_intensity: float = 0.0

var scale_tween: Tween
var glow_tween: Tween

func _ready() -> void:
	custom_minimum_size = Vector2(340, 68)
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	flat = true
	clip_contents = false
	pivot_offset = custom_minimum_size * 0.5
	
	# Oculta texto padrão do Button nativo para renderizar via _draw com layout tático
	text = ""
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5

func _on_mouse_entered() -> void:
	is_hovered = true
	AudioManager.play_button_hover()
	_animate_state(1.03, 1.0)

func _on_mouse_exited() -> void:
	is_hovered = false
	if not has_focus():
		_animate_state(1.0, 0.0)

func _on_button_down() -> void:
	is_active_pressed = true
	AudioManager.play_button_click()
	_animate_scale(0.97)

func _on_button_up() -> void:
	is_active_pressed = false
	_animate_scale(1.03 if is_hovered or has_focus() else 1.0)

func _on_focus_entered() -> void:
	is_hovered = true
	AudioManager.play_button_hover()
	_animate_state(1.03, 1.0)

func _on_focus_exited() -> void:
	if not is_hovered:
		_animate_state(1.0, 0.0)

func _animate_state(target_scale: float, target_glow: float) -> void:
	_animate_scale(target_scale)
	if glow_tween and glow_tween.is_valid():
		glow_tween.kill()
	glow_tween = create_tween()
	glow_tween.set_trans(Tween.TRANS_CUBIC)
	glow_tween.set_ease(Tween.EASE_OUT)
	glow_tween.tween_property(self, "glow_intensity", target_glow, 0.22)
	glow_tween.tween_callback(queue_redraw)

func _animate_scale(target_s: float) -> void:
	if scale_tween and scale_tween.is_valid():
		scale_tween.kill()
	scale_tween = create_tween()
	scale_tween.set_trans(Tween.TRANS_BACK if target_s > 1.0 else Tween.TRANS_QUAD)
	scale_tween.set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(self, "scale", Vector2.ONE * target_s, 0.18)

func _process(_delta: float) -> void:
	if glow_tween and glow_tween.is_valid():
		queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var c: float = chamfer_size
	
	# Paleta de Cores Táticas
	var border_color: Color
	var bg_color: Color
	var glow_color: Color
	var text_pri_color: Color
	var text_sec_color: Color
	var icon_color: Color
	
	if is_accent_gold:
		# Botão Principal (Dourado / Âmbar / Laranja incandescente)
		border_color = Color("ff9900")
		glow_color = Color("ff7700")
		bg_color = Color(0.24, 0.11, 0.02, 0.88 + glow_intensity * 0.1)
		text_pri_color = Color("ffffff")
		text_sec_color = Color("ffcb85")
		icon_color = Color("ffaa00")
	else:
		# Botões Secundários (Azul Neon / Ciano Cibernético)
		border_color = Color("00d4ff")
		glow_color = Color("0088cc")
		bg_color = Color(0.04, 0.10, 0.18, 0.82 + glow_intensity * 0.12)
		text_pri_color = Color("ffffff")
		text_sec_color = Color("85dfff")
		icon_color = Color("00e5ff")
		
	# Polígono com cantos chanfrados (Estilo tático retro-futurista)
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(c, 0.0),
		Vector2(w - c, 0.0),
		Vector2(w, c),
		Vector2(w, h - c),
		Vector2(w - c, h),
		Vector2(c, h),
		Vector2(0.0, h - c),
		Vector2(0.0, c)
	])
	
	# 1. Sombra e Glow externo
	if glow_intensity > 0.01 or has_focus():
		var glow_points: PackedVector2Array = PackedVector2Array()
		var expand: float = 4.0 + glow_intensity * 5.0
		for p: Vector2 in points:
			var dir: Vector2 = (p - size * 0.5).normalized()
			glow_points.append(p + dir * expand)
		var g_col: Color = glow_color
		g_col.a = 0.35 * (glow_intensity + (0.25 if has_focus() else 0.0))
		draw_colored_polygon(glow_points, g_col)
	
	# 2. Preenchimento de Fundo
	draw_colored_polygon(points, bg_color)
	
	# 3. Traçado da Borda Neon
	var loop_points: PackedVector2Array = points.duplicate()
	loop_points.append(points[0])
	var stroke_width: float = 2.0 + (1.2 if is_hovered else 0.0)
	draw_polyline(loop_points, border_color, stroke_width, true)
	
	# 4. Detalhe tático na ponta chanfrada esquerda
	draw_line(Vector2(0.0, c), Vector2(c, 0.0), Color.WHITE, stroke_width + 1.0)
	
	# 5. Ícone do Botão
	var font_icon: Font = ThemeDB.fallback_font
	var icon_size: int = 24
	var icon_pos: Vector2 = Vector2(26.0, h * 0.5 + 8.0)
	draw_string(font_icon, icon_pos, icon_symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, icon_size, icon_color)
	
	# 6. Texto Principal
	var font_main: Font = ThemeDB.fallback_font
	var main_size: int = 17
	var text_x: float = 64.0
	var pri_y: float = h * 0.44 + 4.0
	draw_string(font_main, Vector2(text_x, pri_y), primary_text, HORIZONTAL_ALIGNMENT_LEFT, -1, main_size, text_pri_color)
	
	# 7. Texto Secundário (Legenda Tática)
	var sec_size: int = 10
	var sec_y: float = h * 0.76 + 2.0
	draw_string(font_main, Vector2(text_x, sec_y), secondary_text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, sec_size, text_sec_color)
	
	# 8. Borda de foco para Teclado/Controle
	if has_focus():
		draw_rect(Rect2(-4, -4, w + 8, h + 8), Color(1.0, 1.0, 1.0, 0.7), false, 1.5)
