class_name MenuCharacter
extends Node2D

## Personagem tático central do menu de Bombástico.
## Gerencia animação idle de respiração/oscilação, sombra no chão,
## partículas do pavio da bomba acesa e tingimento de cor do traje em tempo real.

@onready var sprite: Sprite2D = $Sprite
@onready var shadow: Node2D = $Shadow

var time_accum: float = 0.0
var base_position: Vector2
var shader_material: ShaderMaterial

# Partículas de faísca do pavio da bomba
class FuseSpark:
	var pos: Vector2
	var vel: Vector2
	var life: float
	var max_life: float
	var size: float
	var color: Color

var fuse_sparks: Array[FuseSpark] = []
var spark_spawn_timer: float = 0.0

func _ready() -> void:
	base_position = position
	_setup_shader()
	set_process(true)

func _setup_shader() -> void:
	var shader: Shader = load("res://shaders/suit_tint.gdshader")
	if shader and sprite:
		shader_material = ShaderMaterial.new()
		shader_material.shader = shader
		sprite.material = shader_material

func set_suit_color(color_idx: int) -> void:
	if shader_material:
		shader_material.set_shader_parameter("color_index", color_idx)

func _process(delta: float) -> void:
	time_accum += delta
	
	if sprite:
		sprite.scale = Vector2.ONE
		sprite.position = Vector2.ZERO
		
	if shadow:
		shadow.scale = Vector2.ONE
		shadow.modulate.a = 0.7
	
	_update_sparks(delta)
	queue_redraw()

func _update_sparks(delta: float) -> void:
	spark_spawn_timer += delta
	if spark_spawn_timer >= 0.04:
		spark_spawn_timer = 0.0
		_spawn_fuse_spark()
		
	var i: int = fuse_sparks.size() - 1
	while i >= 0:
		var s: FuseSpark = fuse_sparks[i]
		s.life -= delta
		if s.life <= 0.0:
			fuse_sparks.remove_at(i)
		else:
			s.pos += s.vel * delta
			s.vel.y += 65.0 * delta # Gravidade leve
		i -= 1

func _spawn_fuse_spark() -> void:
	# Posição do pavio aceso na mão do personagem (relativo à escala do sprite)
	var fuse_origin: Vector2 = Vector2(148.0, -56.0) + (sprite.position if sprite else Vector2.ZERO)
	var s: FuseSpark = FuseSpark.new()
	s.pos = fuse_origin + Vector2(randf_range(-4, 4), randf_range(-4, 4))
	var angle: float = randf_range(-PI * 0.85, -PI * 0.15)
	var speed: float = randf_range(40.0, 110.0)
	s.vel = Vector2(cos(angle), sin(angle)) * speed
	s.max_life = randf_range(0.25, 0.55)
	s.life = s.max_life
	s.size = randf_range(2.0, 4.5)
	s.color = Color("ffcc00") if randf() > 0.4 else Color("ff4400")
	fuse_sparks.append(s)

func _draw() -> void:
	# Desenha faíscas incandescentes do pavio
	for s: FuseSpark in fuse_sparks:
		var alpha: float = s.life / s.max_life
		var c: Color = s.color
		c.a = alpha
		draw_rect(Rect2(s.pos.x - s.size * 0.5, s.pos.y - s.size * 0.5, s.size, s.size), c)
		# Halo de brilho suave
		var halo: Color = Color("ffaa00", alpha * 0.35)
		draw_circle(s.pos, s.size * 1.8, halo)
