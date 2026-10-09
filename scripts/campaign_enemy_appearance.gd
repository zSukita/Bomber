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
const INK := Color("252139")

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

	if not enemy_sprite:
		enemy_sprite = Sprite2D.new()
		enemy_sprite.name = "EnemySprite"
		add_child(enemy_sprite)

	if is_alive:
		enemy_sprite.visible = true
		var frame_idx: int = clampi(int(animation_time * 6.0) % 4, 0, 3)
		var flip_h: bool = direction.x > 0
		BomberAssets.configure_enemy_sprite(enemy_sprite, archetype, frame_idx, flip_h)
	queue_redraw()

func _draw() -> void:
	if not is_alive:
		return
	var large := archetype == CampaignEnemy.Archetype.BOSS
	var shadow_rx: float = 24.0 if large else 14.0
	var shadow_ry: float = 8.0 if large else 5.0
	_draw_ellipse(Vector2(0, 14), Vector2(shadow_rx, shadow_ry), Color(0.02, 0.03, 0.06, 0.45))

	var charge_vector := charge_direction.normalized()
	if charge_vector == Vector2.ZERO:
		charge_vector = Vector2.DOWN
	if is_winding_up:
		if GameState.is_enhanced():
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
			draw_rect(Rect2(-charge_vector.x * 20 - 4, -charge_vector.y * 20 - 4, 8, 8), Color("ffe46b"))
			draw_rect(Rect2(-charge_vector.x * 32 - 3, -charge_vector.y * 32 - 3, 6, 6), Color("ffaa33"))
		else:
			draw_rect(Rect2(-charge_vector.x * 18 - 4, -charge_vector.y * 18 - 4, 8, 8), Color("ffe46b"))

	if max_health > 1:
		var bar_y: float = -120.0 if large else -42.0
		draw_rect(Rect2(-20, bar_y, 40, 8), INK)
		draw_rect(Rect2(-16, bar_y + 4, 32, 4), Color("493147"))
		draw_rect(Rect2(-16, bar_y + 4, 32.0 * float(health) / float(max_health), 4), Color("ff534d"))

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(16):
		var angle: float = TAU * float(i) / 16.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
