class_name CampaignEnemyAppearance
extends Node2D

## Desenha o inimigo a partir do estado fornecido pelo controlador de IA.
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
	var bob: float = sin(animation_time * 5.5) * 1.7
	var body_radius: float = 23.0 if archetype == CampaignEnemy.Archetype.BOSS else 16.0
	draw_circle(Vector2(0, 12), body_radius, Color(0.0, 0.0, 0.0, 0.3))
	match archetype:
		CampaignEnemy.Archetype.WANDERER:
			_draw_wanderer(bob)
		CampaignEnemy.Archetype.HUNTER:
			_draw_hunter(bob)
		CampaignEnemy.Archetype.CHARGER:
			_draw_charger(bob)
		CampaignEnemy.Archetype.BOSS:
			_draw_boss(bob)
	_draw_face(bob)
	if is_winding_up:
		draw_line(charge_direction * 22.0, charge_direction * 70.0, Color(1.0, 0.28, 0.08, 0.82), 5.0, true)
	elif is_charging:
		draw_line(-charge_direction * 28.0, charge_direction * 28.0, Color(1.0, 0.92, 0.42, 0.9), 6.0, true)
	if max_health > 1:
		draw_rect(Rect2(-20.0, -34.0, 40.0, 5.0), Color(0.12, 0.1, 0.16, 0.9))
		var fill_rect: Rect2 = Rect2(-19.0, -33.0, 38.0 * float(health) / float(max_health), 3.0)
		draw_rect(fill_rect, Color(1.0, 0.28, 0.22))

func _draw_wanderer(bob: float) -> void:
	var points := PackedVector2Array([Vector2(-10, -8 + bob), Vector2(-17, -21 + bob), Vector2(-4, -14 + bob)])
	draw_colored_polygon(points, body_color.darkened(0.18))
	points = PackedVector2Array([Vector2(5, -13 + bob), Vector2(15, -22 + bob), Vector2(13, -4 + bob)])
	draw_colored_polygon(points, body_color.darkened(0.18))
	draw_circle(Vector2(0, 2 + bob), 16.0, body_color.darkened(0.25))
	draw_circle(Vector2(0, bob), 14.0, body_color)
	draw_circle(Vector2(-5, -5 + bob), 4.0, accent_color)

func _draw_hunter(bob: float) -> void:
	var wing_color: Color = body_color.darkened(0.12)
	var left_wing := PackedVector2Array([Vector2(-8, -4 + bob), Vector2(-23, -16 + bob), Vector2(-19, 5 + bob)])
	var right_wing := PackedVector2Array([Vector2(8, -4 + bob), Vector2(23, -16 + bob), Vector2(19, 5 + bob)])
	draw_colored_polygon(left_wing, wing_color)
	draw_colored_polygon(right_wing, wing_color)
	draw_circle(Vector2(0, 2 + bob), 14.0, body_color.darkened(0.22))
	draw_circle(Vector2(0, bob), 12.0, body_color)
	draw_arc(Vector2(0, bob), 9.0, deg_to_rad(195), deg_to_rad(345), 12, accent_color, 2.0, true)

func _draw_charger(bob: float) -> void:
	draw_circle(Vector2(0, 1 + bob), 18.0, body_color.darkened(0.32))
	draw_circle(Vector2(0, -2 + bob), 15.0, body_color)
	draw_arc(Vector2(0, -2 + bob), 12.5, deg_to_rad(195), deg_to_rad(345), 16, accent_color, 3.0, true)
	var horn_direction: Vector2 = direction.normalized()
	if horn_direction == Vector2.ZERO:
		horn_direction = Vector2.DOWN
	var side: Vector2 = Vector2(-horn_direction.y, horn_direction.x)
	draw_colored_polygon(PackedVector2Array([
		horn_direction * 9.0 + side * 7.0 + Vector2(0, bob),
		horn_direction * 28.0 + Vector2(0, bob),
		horn_direction * 9.0 - side * 7.0 + Vector2(0, bob)
	]), accent_color)

func _draw_boss(bob: float) -> void:
	draw_circle(Vector2(0, 2 + bob), 24.0, body_color.darkened(0.32))
	draw_circle(Vector2(0, bob), 21.0, body_color)
	for side in [-1.0, 0.0, 1.0]:
		var crown_points := PackedVector2Array([
			Vector2(side * 12.0 - 5.0, -13.0 + bob),
			Vector2(side * 12.0, -27.0 + bob),
			Vector2(side * 12.0 + 5.0, -13.0 + bob)
		])
		draw_colored_polygon(crown_points, accent_color)
	draw_arc(Vector2(0, bob), 17.0, deg_to_rad(200), deg_to_rad(340), 18, accent_color, 2.5, true)

func _draw_face(bob: float) -> void:
	var eye_y: float = -2.0 + bob
	var eye_radius: float = 3.0 if archetype != CampaignEnemy.Archetype.BOSS else 3.4
	var eye_color: Color = Color(1.0, 0.96, 0.8)
	if archetype == CampaignEnemy.Archetype.BOSS:
		for x in [-9.0, 0.0, 9.0]:
			draw_circle(Vector2(x, eye_y), eye_radius, eye_color)
			draw_circle(Vector2(x + 0.8, eye_y + 0.6), 1.4, Color(0.12, 0.08, 0.13))
	else:
		draw_circle(Vector2(-5.0, eye_y), eye_radius, eye_color)
		draw_circle(Vector2(5.0, eye_y), eye_radius, eye_color)
		draw_circle(Vector2(-4.2, eye_y + 0.7), 1.4, Color(0.12, 0.08, 0.13))
		draw_circle(Vector2(5.8, eye_y + 0.7), 1.4, Color(0.12, 0.08, 0.13))
	if archetype == CampaignEnemy.Archetype.WANDERER or archetype == CampaignEnemy.Archetype.BOSS:
		draw_arc(Vector2(0, 4 + bob), 5.0, deg_to_rad(20), deg_to_rad(160), 8, Color(0.16, 0.08, 0.12), 1.8)
