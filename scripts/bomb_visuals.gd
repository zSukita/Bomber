class_name BombVisuals
extends Node2D

## Bomba de Super Bomberman 3 animada com quadros autênticos, sombra e faíscas.
var bomb_sprite: Sprite2D
var anim_timer: float = 0.0
var spark_timer: float = 0.0
var current_frame: int = 0

func _ready() -> void:
	bomb_sprite = Sprite2D.new()
	bomb_sprite.name = "BombSprite"
	add_child(bomb_sprite)
	BomberAssets.configure_bomb_sprite(bomb_sprite, 0)
	queue_redraw()

func _process(delta: float) -> void:
	anim_timer += delta * 6.0
	var next_frame: int = int(anim_timer) % 3
	if next_frame != current_frame:
		current_frame = next_frame
		if bomb_sprite:
			BomberAssets.configure_bomb_sprite(bomb_sprite, current_frame)
	spark_timer += delta * 15.0
	queue_redraw()

func _draw() -> void:
	# Sombra suave sob a bomba
	draw_ellipse_shadow(Vector2(0, 14), Vector2(16, 5), Color(0, 0, 0, 0.45))
	
	if GameState.is_enhanced():
		var glow_alpha: float = sin(spark_timer * 1.5) * 0.15 + 0.25
		draw_circle(Vector2(0, -22), 12.0, Color(1.0, 0.65, 0.15, glow_alpha))
		var spark_off_x: float = sin(spark_timer * 2.3) * 5.0
		var spark_off_y: float = -26.0 - absf(cos(spark_timer * 1.8)) * 6.0
		draw_rect(Rect2(spark_off_x - 1, spark_off_y - 1, 3, 3), Color("fff7bd"))

func draw_ellipse_shadow(center: Vector2, radii: Vector2, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(16):
		var angle: float = TAU * float(i) / 16.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
