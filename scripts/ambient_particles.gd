class_name AmbientParticles
extends Control

## Sistema de partículas ambientais e atmosfera para o menu principal.
## Simula brasas incandescentes de tochas, faíscas de explosivos e poeira luar.

class Ember:
	var pos: Vector2
	var speed: float
	var size: float
	var alpha: float
	var sway: float
	var is_moon_dust: bool

var embers: Array[Ember] = []
const MAX_EMBERS: int = 40
var time_accum: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rng.seed = int(get_instance_id())
	_init_embers()
	GameState.enhanced_mode_toggled.connect(_on_enhanced_mode_toggled)
	visible = GameState.is_enhanced()
	set_process(visible)

func _on_enhanced_mode_toggled(is_enhanced: bool) -> void:
	visible = is_enhanced
	set_process(is_enhanced)
	if is_enhanced:
		queue_redraw()

func _init_embers() -> void:
	embers.clear()
	for i in range(MAX_EMBERS):
		var e: Ember = Ember.new()
		_reset_ember(e, true)
		embers.append(e)

func _reset_ember(e: Ember, random_y: bool = false) -> void:
	var w: float = maxf(size.x, 960.0)
	var h: float = maxf(size.y, 832.0)
	e.pos = Vector2(rng.randf_range(0.0, w), rng.randf_range(0.0, h) if random_y else h + 15.0)
	e.speed = rng.randf_range(30.0, 75.0)
	e.size = rng.randf_range(2.0, 4.5)
	e.alpha = rng.randf_range(0.25, 0.75)
	e.sway = rng.randf_range(1.2, 2.8)
	e.is_moon_dust = (rng.randf() < 0.28) # 28% poeira azul lunar, 72% brasas de fogo

func _process(delta: float) -> void:
	time_accum += delta
	var w: float = maxf(size.x, 960.0)
	for e in embers:
		e.pos.y -= e.speed * delta
		e.pos.x += sin(time_accum * e.sway + float(e.get_instance_id() % 10)) * 14.0 * delta
		if e.pos.y < -20.0:
			_reset_ember(e, false)
			e.pos.x = rng.randf_range(0.0, w)
	queue_redraw()

func _draw() -> void:
	for e: Ember in embers:
		var col: Color
		if e.is_moon_dust:
			col = Color("55c5ff")
		else:
			col = Color("ff9922") if e.size > 3.0 else Color("ff4411")
		col.a = e.alpha * (0.8 + 0.2 * sin(time_accum * 4.0)) * GameState.visual_effects_intensity
		draw_rect(Rect2(e.pos.x, e.pos.y, e.size, e.size), col)
		# Halo suave
		var halo: Color = col
		halo.a *= 0.3
		draw_circle(e.pos + Vector2(e.size * 0.5, e.size * 0.5), e.size * 1.5, halo)
