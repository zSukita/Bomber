class_name CharacterPortrait
extends Control

## Exibe o retrato do personagem selecionado com transparência e escala corretas.
@export var player_color: Color = Color(0.25, 0.65, 1.0):
	set(val):
		player_color = val
		queue_redraw()

@export_range(0, 7) var character_index: int = 0:
	set(val):
		character_index = val
		if character_sprite:
			set_character(character_index)

var character_sprite: Sprite2D

func _ready() -> void:
	character_sprite = Sprite2D.new()
	character_sprite.name = "CharacterSprite"
	add_child(character_sprite)
	set_character(character_index)
	queue_redraw()

func set_character(index: int) -> void:
	character_index = posmod(index, BomberAssets.CHARACTER_TEXTURES.size())
	if character_sprite:
		BomberAssets.configure_character_sprite(character_sprite, character_index, 0, 0, false)
		var center_x: float = size.x * 0.5 if size.x > 0 else 24.0
		var center_y: float = size.y * 0.5 + 8.0 if size.y > 0 else 32.0
		character_sprite.position = Vector2(center_x, center_y)
		character_sprite.scale = Vector2.ONE * 1.8

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and character_sprite:
		var center_x: float = size.x * 0.5 if size.x > 0 else 24.0
		var center_y: float = size.y * 0.5 + 8.0 if size.y > 0 else 32.0
		character_sprite.position = Vector2(center_x, center_y)

func _draw() -> void:
	# Borda / anel com a cor do jogador
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.44
	draw_arc(center, radius, 0.0, TAU, 24, Color(player_color.r, player_color.g, player_color.b, 0.6), 2.0)
