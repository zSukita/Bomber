class_name TimePortal
extends Area2D

signal selected(portal: TimePortal)

@export var golden_portal: bool = true
var target_stage: int = 0
var pulse_time: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _process(delta: float) -> void:
	pulse_time += delta
	queue_redraw()

func _draw() -> void:
	var portal_color: Color = Color(1.0, 0.73, 0.2) if golden_portal else Color(0.48, 0.43, 1.0)
	var pulse: float = sin(pulse_time * 3.2) * 2.0
	draw_circle(Vector2.ZERO, 27.0 + pulse, Color(portal_color.r, portal_color.g, portal_color.b, 0.12))
	draw_arc(Vector2.ZERO, 20.0 + pulse, 0.0, TAU, 40, portal_color, 4.0, true)
	draw_arc(Vector2.ZERO, 12.0 - pulse * 0.35, 0.0, TAU, 32, portal_color.lightened(0.28), 2.0, true)
	draw_circle(Vector2.ZERO, 5.5, Color(portal_color.r, portal_color.g, portal_color.b, 0.38))

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("players") and body.get("is_alive") == true:
		selected.emit(self)
