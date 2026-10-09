class_name CampaignEnemyAppearance
extends Node2D

## Monstros de campanha em pixel art, mantendo as quatro silhuetas da IA.
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

const INK := Color("252139")

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
	queue_redraw()

func _draw() -> void:
	if not is_alive:
		return
	var bob := int(round(sin(animation_time * 5.0))) * 4.0
	var large := archetype == CampaignEnemy.Archetype.BOSS
	var width := 40.0 if large else 32.0
	draw_rect(Rect2(-width * 0.4, 12, width * 0.8, 4), Color(0, 0, 0, 0.35))
	match archetype:
		CampaignEnemy.Archetype.WANDERER:
			_draw_blob(bob)
		CampaignEnemy.Archetype.HUNTER:
			_draw_bat(bob)
		CampaignEnemy.Archetype.CHARGER:
			_draw_charger(bob)
		CampaignEnemy.Archetype.BOSS:
			_draw_boss(bob)
	var charge_vector := charge_direction.normalized()
	if charge_vector == Vector2.ZERO:
		charge_vector = Vector2.DOWN
	if is_winding_up:
		if GameState.is_enhanced():
			# Telegrafo visual legível de alcance: linha pontilhada de perigo ao longo do vetor de ataque
			var pulse_strength: float = 0.08 if GameState.reduced_flashes_enabled else 0.4
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
		if GameState.is_enhanced():
			# Rastro visual e linha de velocidade na investida ativa
			draw_rect(Rect2(-charge_vector.x * 20 - 4, -charge_vector.y * 20 - 4, 8, 8), Color("ffe46b"))
			draw_rect(Rect2(-charge_vector.x * 32 - 3, -charge_vector.y * 32 - 3, 6, 6), Color("ffaa33"))
		else:
			draw_rect(Rect2(-charge_vector.x * 18 - 4, -charge_vector.y * 18 - 4, 8, 8), Color("ffe46b"))
	if max_health > 1:
		draw_rect(Rect2(-20, -36, 40, 8), INK)
		draw_rect(Rect2(-16, -32, 32, 4), Color("493147"))
		draw_rect(Rect2(-16, -32, 32.0 * float(health) / float(max_health), 4), Color("ff534d"))


func _draw_blob(bob: float) -> void:
	_px(-16, -4 + bob, 8, 8, INK)
	_px(8, -4 + bob, 8, 8, INK)
	_px(-12, -12 + bob, 24, 28, INK)
	_px(-16, -4 + bob, 4, 12, INK)
	_px(12, -4 + bob, 4, 12, INK)
	_px(-12, -8 + bob, 24, 24, body_color.darkened(0.2))
	_px(-8, -12 + bob, 16, 24, body_color)
	_px(-8, -8 + bob, 16, 4, accent_color)
	_draw_face(bob, false)

func _draw_bat(bob: float) -> void:
	_px(-24, -8 + bob, 12, 8, INK)
	_px(12, -8 + bob, 12, 8, INK)
	_px(-20, -12 + bob, 12, 4, body_color.darkened(0.18))
	_px(8, -12 + bob, 12, 4, body_color.darkened(0.18))
	_px(-16, -8 + bob, 32, 20, INK)
	_px(-12, -12 + bob, 24, 20, body_color.darkened(0.2))
	_px(-8, -12 + bob, 16, 16, body_color)
	_px(-8, 4 + bob, 16, 4, accent_color)
	_draw_face(bob, false)

func _draw_charger(bob: float) -> void:
	_px(-20, -12 + bob, 40, 24, INK)
	_px(-16, -16 + bob, 32, 24, body_color.darkened(0.22))
	_px(-12, -16 + bob, 24, 20, body_color)
	_px(-12, 4 + bob, 24, 4, accent_color)
	var d := direction.normalized()
	if d == Vector2.ZERO:
		d = Vector2.DOWN
	var tip := d * 28.0
	draw_rect(Rect2(tip.x - 4, tip.y - 4 + bob, 8, 8), INK)
	draw_rect(Rect2(tip.x - 4, tip.y - 4 + bob, 4, 4), accent_color.lightened(0.2))
	_draw_face(bob, false)

func _draw_boss(bob: float) -> void:
	_px(-24, -8 + bob, 48, 28, INK)
	_px(-20, -16 + bob, 40, 36, body_color.darkened(0.24))
	_px(-16, -20 + bob, 32, 36, body_color)
	_px(-20, -20 + bob, 8, 8, INK)
	_px(-4, -24 + bob, 8, 12, INK)
	_px(12, -20 + bob, 8, 8, INK)
	_px(-16, -20 + bob, 4, 8, accent_color)
	_px(-4, -24 + bob, 4, 8, accent_color)
	_px(12, -20 + bob, 4, 8, accent_color)
	_px(-12, -4 + bob, 24, 8, accent_color.darkened(0.2))
	_draw_face(bob, true)

func _draw_face(bob: float, boss: bool) -> void:
	if boss:
		_px(-12, -8 + bob, 8, 8, Color("fff1ba"))
		_px(4, -8 + bob, 8, 8, Color("fff1ba"))
		_px(-8, -8 + bob, 4, 8, INK)
		_px(8, -8 + bob, 4, 8, INK)
		_px(-4, 4 + bob, 8, 4, INK)
	else:
		_px(-8, -4 + bob, 8, 8, Color("fff1ba"))
		_px(4, -4 + bob, 8, 8, Color("fff1ba"))
		_px(-4, -4 + bob, 4, 8, INK)
		_px(8, -4 + bob, 4, 8, INK)

func _px(x: float, y: float, width: float, height: float, color: Color) -> void:
	draw_rect(Rect2(x, y, width, height), color)
