class_name PlayerVisuals
extends Node2D

## Visual autêntico dos personagens de Super Bomberman 3 com controle de animação, direção e equipe.
@export var player_color: Color = Color(0.25, 0.65, 1.0)
var facing_direction: Vector2 = Vector2.DOWN
var is_moving: bool = false
var walk_time: float = 0.0
var is_alive: bool = true
var character_index: int = 0
var character_sprite: Sprite2D
var mount_sprite: Sprite2D
var current_mount: int = GameState.MountType.NONE
var sprite_frame: int = -1
var sprite_row: int = -1
var sprite_flip: bool = false
var emote_sprite: Sprite2D
var emote_tween: Tween

func _ready() -> void:
	mount_sprite = Sprite2D.new()
	mount_sprite.name = "MountSprite"
	mount_sprite.z_index = -1
	mount_sprite.visible = false
	add_child(mount_sprite)

	character_sprite = Sprite2D.new()
	character_sprite.name = "CharacterSprite"
	character_sprite.z_index = 0
	add_child(character_sprite)

	emote_sprite = Sprite2D.new()
	emote_sprite.name = "EmoteBubble"
	emote_sprite.z_index = 10
	emote_sprite.visible = false
	emote_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(emote_sprite)

	set_character(character_index)
	set_mount(current_mount)
	queue_redraw()

func set_skin_color(color: Color) -> void:
	player_color = color
	queue_redraw()

func set_character(index: int) -> void:
	character_index = posmod(index, BomberAssets.CHARACTER_TEXTURES.size())
	if character_sprite:
		BomberAssets.configure_character_sprite(character_sprite, character_index, 0, _direction_row(), facing_direction.x > 0)
		if current_mount != GameState.MountType.NONE:
			character_sprite.position = Vector2(0, -28)
		sprite_frame = 0
		sprite_row = _direction_row()
		sprite_flip = facing_direction.x > 0

func set_mount(type: int) -> void:
	current_mount = type
	if not mount_sprite:
		return
	if current_mount == GameState.MountType.NONE:
		mount_sprite.visible = false
		if character_sprite:
			character_sprite.position = Vector2(0, -18)
	else:
		mount_sprite.visible = true
		if character_sprite:
			character_sprite.position = Vector2(0, -28)
		_update_mount_visual()
	queue_redraw()

func _update_mount_visual() -> void:
	if not mount_sprite or current_mount == GameState.MountType.NONE:
		return
	var frame: int = int(walk_time * 8.0) % 4 if is_moving else 0
	var dir_col: int = _mount_direction_col()
	BomberAssets.configure_mount_sprite(mount_sprite, current_mount, frame, dir_col)

func _mount_direction_col() -> int:
	if facing_direction == Vector2.UP:
		return 1
	if facing_direction == Vector2.LEFT:
		return 2
	if facing_direction == Vector2.RIGHT:
		return 3
	return 0

func update_state(direction: Vector2, moving: bool, alive: bool) -> void:
	if direction != Vector2.ZERO:
		if abs(direction.x) > abs(direction.y):
			facing_direction = Vector2(sign(direction.x), 0)
		else:
			facing_direction = Vector2(0, sign(direction.y))
	is_moving = moving
	is_alive = alive
	if character_sprite and alive:
		character_sprite.visible = true

func _process(delta: float) -> void:
	if not is_alive:
		return
	if is_moving:
		walk_time += delta
	else:
		walk_time = 0.0
	if character_sprite:
		var next_frame: int = int(walk_time * 8.0) % 4 if is_moving else 0
		var next_row: int = _direction_row()
		var next_flip: bool = facing_direction.x > 0
		if next_frame != sprite_frame or next_row != sprite_row or next_flip != sprite_flip:
			BomberAssets.configure_character_sprite(character_sprite, character_index, next_frame, next_row, next_flip)
			if current_mount != GameState.MountType.NONE:
				character_sprite.position = Vector2(0, -28)
			sprite_frame = next_frame
			sprite_row = next_row
			sprite_flip = next_flip
	if current_mount != GameState.MountType.NONE:
		_update_mount_visual()
	queue_redraw()

func _direction_row() -> int:
	if facing_direction == Vector2.UP:
		return 1
	if facing_direction == Vector2.LEFT or facing_direction == Vector2.RIGHT:
		return 2
	return 0

func _draw() -> void:
	# Sombra suave sob os pés (ligeiramente maior quando montado)
	var shadow_radii := Vector2(20, 8) if current_mount != GameState.MountType.NONE else Vector2(16, 6)
	var circle_radius := 24.0 if current_mount != GameState.MountType.NONE else 20.0
	_draw_ellipse(Vector2(0, 14), shadow_radii, Color(0.02, 0.03, 0.06, 0.45))
	# Indicador circular de equipe / cor do jogador
	draw_arc(Vector2(0, 14), circle_radius, 0.0, TAU, 24, Color(player_color.r, player_color.g, player_color.b, 0.85), 2.5)

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(16):
		var angle: float = TAU * float(i) / 16.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)

func show_emote(emote_index: int) -> void:
	if not emote_sprite:
		return
	var idx := clampi(emote_index, 1, 30)
	var path := "res://assets/legal/emotes/emote%d.png" % idx
	if not ResourceLoader.exists(path):
		return
	emote_sprite.texture = load(path) as Texture2D
	emote_sprite.visible = true
	var base_y: float = -54.0 if current_mount != GameState.MountType.NONE else -42.0
	emote_sprite.position = Vector2(0, base_y)
	emote_sprite.scale = Vector2(0.2, 0.2)
	emote_sprite.modulate.a = 1.0
	
	if emote_tween and emote_tween.is_valid():
		emote_tween.kill()
	
	emote_tween = create_tween()
	# Pop bounce: surge rapidamente com efeito mola
	emote_tween.tween_property(emote_sprite, "scale", Vector2.ONE * 2.8, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Flutuação suave para cima
	emote_tween.parallel().tween_property(emote_sprite, "position:y", base_y - 8.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	emote_tween.tween_interval(1.8)
	emote_tween.parallel().tween_property(emote_sprite, "modulate:a", 0.0, 0.3)
	emote_tween.chain().tween_callback(func():
		emote_sprite.visible = false
	)
