class_name ArenaAmbience
extends Node2D

## Sistema de Ambientaçao Dinâmica e Coerente para a Arena.
## Adiciona partículas ambientais contextualizadas ao tema, vento compartilhado,
## sombras suaves de nuvens em movimento e cintilações ambientais.
## Totalmente desacoplado: quando o Modo Melhorado está desativado, o nó desliga.

const ARENA_WIDTH: float = 960.0
const ARENA_HEIGHT: float = 832.0

var map_style: int = 0
var time_elapsed: float = 0.0

# Vento compartilhado
var wind_vector: Vector2 = Vector2(25.0, 8.0)
var wind_base_speed: float = 30.0

# Pool de partículas ambientais (pixel art puro)
class AmbientParticle:
	var position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var size: Vector2 = Vector2(3.0, 3.0)
	var color: Color = Color.WHITE
	var life: float = 0.0
	var max_life: float = 4.0
	var rotation: float = 0.0
	var rot_speed: float = 0.0

var particles: Array[AmbientParticle] = []
const MAX_PARTICLES: int = 36

# Sombras de nuvens
class CloudShadow:
	var position: Vector2 = Vector2.ZERO
	var size: Vector2 = Vector2(160.0, 90.0)
	var speed_mult: float = 1.0

var clouds: Array[CloudShadow] = []

func _ready() -> void:
	z_index = 5 # Acima do piso e blocos, abaixo da HUD
	_setup_clouds()
	_init_particles()
	GameState.enhanced_mode_toggled.connect(_on_enhanced_mode_toggled)
	visible = GameState.is_enhanced()
	set_process(visible)

func set_theme(style_index: int) -> void:
	map_style = style_index
	_reconfigure_particles()
	queue_redraw()

func _on_enhanced_mode_toggled(is_enhanced: bool) -> void:
	visible = is_enhanced
	set_process(is_enhanced)
	if is_enhanced:
		queue_redraw()

func _setup_clouds() -> void:
	clouds.clear()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	for i in range(4):
		var cloud: CloudShadow = CloudShadow.new()
		cloud.position = Vector2(rng.randf_range(0.0, ARENA_WIDTH), rng.randf_range(0.0, ARENA_HEIGHT))
		cloud.size = Vector2(rng.randf_range(160.0, 260.0), rng.randf_range(90.0, 150.0))
		cloud.speed_mult = rng.randf_range(0.7, 1.3)
		clouds.append(cloud)

func _init_particles() -> void:
	particles.clear()
	for i in range(MAX_PARTICLES):
		var p: AmbientParticle = AmbientParticle.new()
		_respawn_particle(p, true)
		particles.append(p)

func _respawn_particle(p: AmbientParticle, random_initial_pos: bool = false) -> void:
	if random_initial_pos:
		p.position = Vector2(randf_range(0.0, ARENA_WIDTH), randf_range(0.0, ARENA_HEIGHT))
	else:
		# Surge de acordo com a direção do vento
		if wind_vector.x >= 0.0:
			p.position.x = -20.0
		else:
			p.position.x = ARENA_WIDTH + 20.0
		p.position.y = randf_range(-40.0, ARENA_HEIGHT + 40.0)

	p.life = randf_range(0.0, 1.0) if random_initial_pos else 0.0
	p.max_life = randf_range(4.0, 8.0)
	p.rotation = randf_range(0.0, TAU)
	p.rot_speed = randf_range(-1.5, 1.5)

	# Cores e comportamentos contextuais por estilo de mapa (0 a 9)
	match map_style:
		0, 6: # Prado Brilhante / Ilhas Gêmeas (folhas verdes, pólen dourado)
			p.color = Color("8cd669") if randf() > 0.35 else Color("f7e26b")
			p.size = Vector2(4.0, 4.0) if randf() > 0.5 else Vector2(3.0, 2.0)
			p.velocity = wind_vector + Vector2(randf_range(-10.0, 10.0), randf_range(10.0, 24.0))
		1, 9: # Cratera Vulcânica / Pátio das Chamas (brasas, cinzas quentes)
			p.color = Color("ff6c3b") if randf() > 0.4 else Color("ffd152")
			p.size = Vector2(3.0, 3.0) if randf() > 0.6 else Vector2(2.0, 2.0)
			p.velocity = Vector2(wind_vector.x * 0.4 + randf_range(-8.0, 8.0), randf_range(-35.0, -15.0))
		2, 7: # Geleira Azul / Labirinto de Cristal (cristais de gelo, geada)
			p.color = Color("d9f3ff") if randf() > 0.3 else Color("8de1f7")
			p.size = Vector2(2.0, 2.0) if randf() > 0.5 else Vector2(3.0, 3.0)
			p.velocity = wind_vector * 0.7 + Vector2(randf_range(-15.0, 15.0), randf_range(15.0, 30.0))
		3, 8: # Dunas do Crepúsculo / Ruínas Antigas (grãos de poeira e areia)
			p.color = Color("f3cf88") if randf() > 0.5 else Color("d6ad66")
			p.size = Vector2(3.0, 2.0)
			p.velocity = wind_vector * 1.3 + Vector2(randf_range(-8.0, 8.0), randf_range(-5.0, 10.0))
		_: # Fortaleza Central / Corredores (poeira atmosférica suave de masmorra)
			p.color = Color(0.85, 0.9, 0.95, 0.65)
			p.size = Vector2(2.0, 2.0)
			p.velocity = wind_vector * 0.5 + Vector2(randf_range(-6.0, 6.0), randf_range(-8.0, 8.0))

func _reconfigure_particles() -> void:
	for p in particles:
		_respawn_particle(p, true)

func _process(delta: float) -> void:
	if not GameState.is_enhanced():
		return

	time_elapsed += delta

	# Vento dinâmico com oscilação suave
	var wind_angle: float = sin(time_elapsed * 0.4) * 0.3 + 0.1
	var current_strength: float = wind_base_speed + cos(time_elapsed * 0.7) * 8.0
	wind_vector = Vector2(cos(wind_angle), sin(wind_angle)) * current_strength

	# Atualiza sombras de nuvens
	if GameState.ambient_clouds_enabled:
		for cloud in clouds:
			cloud.position += wind_vector * (0.45 * cloud.speed_mult) * delta
			if cloud.position.x > ARENA_WIDTH + 150.0:
				cloud.position.x = -150.0
				cloud.position.y = randf_range(0.0, ARENA_HEIGHT)
			elif cloud.position.x < -160.0:
				cloud.position.x = ARENA_WIDTH + 140.0

	# Atualiza partículas
	if GameState.ambient_particles_enabled:
		for p in particles:
			p.life += delta
			p.position += p.velocity * delta
			p.rotation += p.rot_speed * delta
			if p.life >= p.max_life or p.position.x < -40.0 or p.position.x > ARENA_WIDTH + 40.0 or p.position.y < -50.0 or p.position.y > ARENA_HEIGHT + 50.0:
				_respawn_particle(p, false)

	queue_redraw()

func _draw() -> void:
	if not GameState.is_enhanced():
		return

	# 1. Desenha sombras de nuvens em movimento (suaves, não interferem no jogo)
	if GameState.ambient_clouds_enabled:
		var cloud_color: Color = Color(0.02, 0.04, 0.08, 0.09)
		for cloud in clouds:
			# Desenha formato arredondado estilizado em pixel
			draw_set_transform(cloud.position, 0.0, Vector2.ONE)
			_draw_cloud_shape(cloud.size, cloud_color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 2. Desenha partículas ambientais estilizadas
	if GameState.ambient_particles_enabled:
		for p in particles:
			var alpha: float = sin((p.life / p.max_life) * PI) * 0.75
			var c: Color = p.color
			c.a = clampf(alpha, 0.0, 1.0)
			
			draw_set_transform(p.position, p.rotation, Vector2.ONE)
			draw_rect(Rect2(-p.size * 0.5, p.size), c)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_cloud_shape(size: Vector2, color: Color) -> void:
	# Forma suave de nuvem com 3 círculos sobrepostos
	var r_center: float = size.y * 0.45
	var r_side: float = size.y * 0.35
	draw_circle(Vector2.ZERO, r_center, color)
	draw_circle(Vector2(-size.x * 0.28, 4.0), r_side, color)
	draw_circle(Vector2(size.x * 0.28, -2.0), r_side * 0.9, color)
