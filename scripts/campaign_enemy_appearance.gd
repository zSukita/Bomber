class_name CampaignEnemyAppearance
extends Node2D

## Monstros de campanha de Super Bomberman 3 com sprites autênticos, animações e telegrafos táticos.
var archetype: int = CampaignEnemy.Archetype.WANDERER
var body_color: Color = Color.WHITE
var accent_color: Color = Color.WHITE
var animation_time: float = 0.0
var is_alive: bool = true
var is_winding_up: bool = false
var is_charging: bool = false
var charge_direction: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.DOWN
var health: int = 1
var max_health: int = 1

var enemy_sprite: Sprite2D
var facing_h_flip: bool = false
const INK := Color("252139")

var is_boss_vulnerable: bool = false
var boss_state: int = 0
var boss_danger_cells: Array[Vector2i] = []
var boss_leap_height: float = 0.0
var boss_phase_two: bool = false
var stage_index: int = 0
var arena_grid: ArenaGrid

func _ready() -> void:
	enemy_sprite = Sprite2D.new()
	enemy_sprite.name = "EnemySprite"
	add_child(enemy_sprite)
	queue_redraw()

func show_enemy_state(enemy: CampaignEnemy) -> void:
	archetype = enemy.archetype
	body_color = enemy.body_color
	accent_color = enemy.accent_color
	animation_time = enemy.animation_time
	is_alive = enemy.is_alive
	is_winding_up = enemy.is_winding_up
	is_charging = enemy.is_charging
	charge_direction = enemy.charge_direction
	direction = enemy.direction
	health = enemy.health
	max_health = enemy.max_health

	is_boss_vulnerable = enemy.is_boss_vulnerable
	boss_state = enemy.boss_state
	boss_danger_cells = enemy.boss_danger_cells.duplicate()
	boss_leap_height = enemy.boss_leap_height
	boss_phase_two = enemy.boss_phase_two
	stage_index = enemy.stage_index
	arena_grid = enemy.arena_grid

	if not enemy_sprite:
		enemy_sprite = Sprite2D.new()
		enemy_sprite.name = "EnemySprite"
		add_child(enemy_sprite)

	if is_alive:
		enemy_sprite.visible = true
		enemy_sprite.position.y = -boss_leap_height
		var frame_idx: int = int(animation_time * 6.0)
		if direction.x < 0:
			facing_h_flip = true
		elif direction.x > 0:
			facing_h_flip = false
		var is_action: bool = is_winding_up or is_charging or is_boss_vulnerable
		BomberAssets.configure_enemy_sprite(enemy_sprite, archetype, frame_idx, facing_h_flip, enemy.stage_index, is_action, direction)
	queue_redraw()

func _draw() -> void:
	if not is_alive:
		return
	var large := archetype == CampaignEnemy.Archetype.BOSS
	var shadow_rx: float = 24.0 if large else 14.0
	var shadow_ry: float = 8.0 if large else 5.0
	_draw_ellipse(Vector2(0, 14), Vector2(shadow_rx, shadow_ry), Color(0.02, 0.03, 0.06, 0.45))

	var reduced_flashes: bool = GameState.reduced_flashes_enabled
	var is_enhanced: bool = GameState.is_enhanced()

	# Telegrafos específicos de Chefes (Fases 5, 10 e 12)
	if large:
		if boss_state == CampaignEnemy.BossState.TELEGRAPH and not boss_danger_cells.is_empty() and arena_grid:
			_draw_boss_attack_telegraph(reduced_flashes, is_enhanced)
		elif is_boss_vulnerable:
			_draw_boss_vulnerability_indicator(reduced_flashes, is_enhanced)

		if boss_phase_two and is_enhanced:
			# Partículas de fúria / aura ao redor do chefe enfurecido
			_draw_boss_enraged_aura()
	else:
		# Inimigos comuns: Chargers
		var charge_vector := charge_direction.normalized()
		if charge_vector == Vector2.ZERO:
			charge_vector = Vector2.DOWN
		if is_winding_up:
			if is_enhanced:
				var pulse_strength: float = 0.08 if reduced_flashes else 0.4
				var pulse: float = sin(animation_time * 16.0) * pulse_strength + (1.0 - pulse_strength)
				var alert_color: Color = Color(1.0, 0.25, 0.2, pulse)
				for dist: float in [28.0, 56.0, 84.0, 112.0]:
					var pt: Vector2 = charge_vector * dist
					draw_rect(Rect2(pt.x - 4, pt.y - 4, 8, 8), alert_color)
					draw_rect(Rect2(pt.x - 2, pt.y - 2, 4, 4), Color.WHITE)
			else:
				var marker := charge_vector * 36.0
				draw_rect(Rect2(marker.x - 4, marker.y - 4, 8, 8), Color("ff5b3d"))
		elif is_charging:
			if is_enhanced:
				draw_rect(Rect2(-charge_vector.x * 20 - 4, -charge_vector.y * 20 - 4, 8, 8), Color("ffe46b"))
				draw_rect(Rect2(-charge_vector.x * 32 - 3, -charge_vector.y * 32 - 3, 6, 6), Color("ffaa33"))
			else:
				draw_rect(Rect2(-charge_vector.x * 18 - 4, -charge_vector.y * 18 - 4, 8, 8), Color("ffe46b"))

	if max_health > 1:
		var bar_y: float = -38.0 if large else -28.0
		bar_y -= boss_leap_height
		var bar_w: float = 46.0 if large else 32.0
		var bar_h: float = 8.0 if large else 5.0
		var bar_x: float = -bar_w * 0.5
		
		# Borda e fundo escuro
		draw_rect(Rect2(bar_x - 1.0, bar_y - 1.0, bar_w + 2.0, bar_h + 2.0), Color("121019"))
		draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color("26131c"))
		
		# Pips/segmentos individuais de vida
		var seg_gap: float = 2.0
		var seg_w: float = (bar_w - (max_health - 1) * seg_gap) / float(max_health)
		for s in range(max_health):
			var seg_x: float = bar_x + float(s) * (seg_w + seg_gap)
			var is_filled: bool = s < health
			if is_filled:
				var hp_col: Color = Color("ff4336")
				if health == 1 and is_enhanced:
					var pulse: float = sin(animation_time * 12.0) * 0.25 + 0.75
					hp_col = Color(1.0, 0.25 * pulse, 0.2 * pulse)
				draw_rect(Rect2(seg_x, bar_y + 1.0, seg_w, bar_h - 2.0), hp_col)
				# Realce superior para aspecto tridimensional retrô
				draw_rect(Rect2(seg_x, bar_y + 1.0, seg_w, 1.5), Color("ffa199"))
			else:
				draw_rect(Rect2(seg_x, bar_y + 1.0, seg_w, bar_h - 2.0), Color("381d24"))
		
		# Marcador "BOSS" sutil acima da barra no modo melhorado
		if large and is_enhanced:
			draw_rect(Rect2(-5.0, bar_y - 4.0, 10.0, 2.0), Color("ffd54f"))

func _draw_boss_attack_telegraph(reduced_flashes: bool, is_enhanced: bool) -> void:
	var pulse: float = 0.6 if reduced_flashes else (sin(animation_time * 16.0) * 0.35 + 0.65)
	
	for cell in boss_danger_cells:
		var cell_world: Vector2 = arena_grid.grid_to_world(cell)
		var local_pos: Vector2 = to_local(cell_world)
		var cell_rect := Rect2(local_pos.x - 28.0, local_pos.y - 28.0, 56.0, 56.0)

		if stage_index == 4:
			# Golem: Fendas e impacto de rocha (Laranja / Terroso)
			draw_rect(cell_rect, Color(0.95, 0.45, 0.15, 0.32 * pulse))
			draw_rect(cell_rect, Color(1.0, 0.65, 0.2, 0.9 * pulse), false, 2.0)
			draw_line(local_pos + Vector2(-12, -8), local_pos + Vector2(12, 8), Color(1.0, 0.8, 0.3, pulse), 2.0)
			draw_line(local_pos + Vector2(-8, 12), local_pos + Vector2(8, -12), Color(1.0, 0.8, 0.3, pulse), 2.0)
		elif stage_index == 9:
			# Espectro: Runa astral roxa / Fenda cósmica
			draw_rect(cell_rect, Color(0.65, 0.2, 0.9, 0.30 * pulse))
			draw_arc(local_pos, 22.0, 0.0, TAU, 16, Color(0.85, 0.45, 1.0, pulse), 2.5)
			draw_arc(local_pos, 12.0, 0.0, TAU, 12, Color(0.95, 0.65, 1.0, pulse * 0.7), 1.5)
		elif stage_index == 11:
			# Cronos: Mira de raio temporal dourada com numerais de relógio
			draw_rect(cell_rect, Color(1.0, 0.85, 0.2, 0.35 * pulse))
			draw_rect(cell_rect, Color(1.0, 0.95, 0.4, 0.9 * pulse), false, 2.0)
			draw_circle(local_pos, 5.0, Color("ffd54f"))
			if is_enhanced:
				draw_line(local_pos + Vector2(-6, 0), local_pos + Vector2(6, 0), Color.WHITE, 1.5)
				draw_line(local_pos + Vector2(0, -6), local_pos + Vector2(0, 6), Color.WHITE, 1.5)

func _draw_boss_vulnerability_indicator(reduced_flashes: bool, _is_enhanced: bool) -> void:
	var pulse: float = 0.7 if reduced_flashes else (sin(animation_time * 12.0) * 0.25 + 0.75)
	
	# Contorno pulsante dourado indicando guarda aberta para bombas
	draw_arc(Vector2(0, -6), 28.0, 0.0, TAU, 18, Color(1.0, 0.9, 0.3, pulse), 2.5)
	draw_arc(Vector2(0, -6), 32.0, 0.0, TAU, 18, Color(1.0, 1.0, 0.6, pulse * 0.4), 1.0)

	# 3 estrelas de tontura girando sobre a cabeça do chefe
	for i in range(3):
		var star_ang: float = animation_time * 5.0 + float(i) * TAU / 3.0
		var star_center: Vector2 = Vector2(cos(star_ang) * 24.0, -42.0 + sin(star_ang) * 6.0)
		_draw_star(star_center, 5.0, 2.5, Color("fff176"))

func _draw_boss_enraged_aura() -> void:
	for i in range(4):
		var ang: float = animation_time * 3.5 + float(i) * TAU / 4.0
		var ember_pos: Vector2 = Vector2(cos(ang) * 26.0, -10.0 + sin(ang) * 20.0)
		var aura_col: Color = Color("ffa726") if stage_index == 4 else (Color("e040fb") if stage_index == 9 else Color("ffd54f"))
		draw_rect(Rect2(ember_pos.x - 2, ember_pos.y - 2, 4, 4), aura_col)

func _draw_star(center: Vector2, r_out: float, r_in: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(8):
		var ang: float = float(i) * TAU / 8.0 - PI * 0.5
		var r: float = r_out if i % 2 == 0 else r_in
		pts.append(center + Vector2(cos(ang), sin(ang)) * r)
	draw_colored_polygon(pts, color)

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(16):
		var angle: float = TAU * float(i) / 16.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)

