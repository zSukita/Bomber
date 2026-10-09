class_name WallIndestructible
extends StaticBody2D

## Representa uma parede indestrutível fixa no mapa.
var grid_position: Vector2i = Vector2i.ZERO

func _ready() -> void:
	$ColorRect.visible = false
	var sprite := Sprite2D.new()
	sprite.name = "StageWallSprite"
	add_child(sprite)
	BomberAssets.configure_wall_sprite(sprite, BomberAssets.WALL_REGION)
