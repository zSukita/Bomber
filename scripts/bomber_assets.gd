class_name BomberAssets
extends RefCounted

## Gerenciador e configurador central de todos os sprites e assets de Super Bomberman 3.

const CHARACTER_NAMES: Array[String] = [
	"Bomberman", "Barbarian Bomber", "Bomber Chen", "Bomber the Kid",
	"Cossack Bomber", "Louie", "Mexican Bomber", "Pretty Bomber"
]

const CHARACTER_TEXTURES: Array[String] = [
	"res://assets/super_bomberman_3/characters/SNES - Super Bomberman 3 - Playable Characters - Bomberman.png",
	"res://assets/super_bomberman_3/characters/SNES - Super Bomberman 3 - Playable Characters - Barbarian Bomber _ Bomber Uhho.png",
	"res://assets/super_bomberman_3/characters/SNES - Super Bomberman 3 - Playable Characters - Bomber Chen _ Bomber Chun.png",
	"res://assets/super_bomberman_3/characters/SNES - Super Bomberman 3 - Playable Characters - Bomber the Kid _ Bomber Kid.png",
	"res://assets/super_bomberman_3/characters/SNES - Super Bomberman 3 - Playable Characters - Cossack Bomber _ Bomber Cossack.png",
	"res://assets/super_bomberman_3/characters/SNES - Super Bomberman 3 - Playable Characters - Louies.png",
	"res://assets/super_bomberman_3/characters/SNES - Super Bomberman 3 - Playable Characters - Mexican Bomber.png",
	"res://assets/super_bomberman_3/characters/SNES - Super Bomberman 3 - Playable Characters - Pretty Bomber.png"
]

const CHARACTER_KEY_COLORS: Array[Color] = [
	Color8(0, 162, 232), Color8(0, 162, 232), Color8(0, 162, 232), Color8(0, 162, 232),
	Color8(0, 162, 232), Color8(34, 177, 76), Color8(0, 162, 232), Color8(27, 89, 153)
]

# Configurações de layout de spritesheet por personagem:
# [origin_x, origin_y, stride_x, stride_y, width, height]
const CHARACTER_LAYOUTS: Array[Array] = [
	[5, 8, 17, 25, 17, 24],   # 0: Bomberman
	[3, 3, 21, 28, 20, 27],   # 1: Barbarian Bomber
	[2, 2, 17, 24, 16, 23],   # 2: Bomber Chen
	[2, 3, 17, 28, 17, 27],   # 3: Bomber the Kid
	[4, 3, 13, 23, 14, 22],   # 4: Cossack Bomber
	[5, 9, 20, 34, 18, 29],   # 5: Louie
	[4, 3, 17, 33, 17, 32],   # 6: Mexican Bomber
	[2, 22, 33, 33, 31, 33]   # 7: Pretty Bomber
]

# Texturas de fases, itens, efeitos e inimigos
const WALL_TEXTURE: String = "res://assets/super_bomberman_3/battle_stages/SNES - Super Bomberman 3 - Battle Stages - Battle Stage 01_ BlockBuster.png"
const EFFECTS_TEXTURE: String = "res://assets/super_bomberman_3/effects/SNES - Super Bomberman 3 - Miscellaneous - Items & Effects.png"
const ENEMIES_TEXTURE: String = "res://assets/super_bomberman_3/enemies/SNES - Super Bomberman 3 - Enemies & Bosses - Enemies.png"

const WALL_REGION := Rect2(0, 0, 16, 16)
const BLOCK_REGION := Rect2(32, 32, 16, 16)

# Tipos de segmentos de explosão
enum ExplosionSegment {
	CENTER = 0,
	BEAM_HORIZONTAL = 1,
	BEAM_VERTICAL = 2,
	TIP_UP = 3,
	TIP_DOWN = 4,
	TIP_LEFT = 5,
	TIP_RIGHT = 6
}

# 4 Cruzes de animação de fogo (Cross 0, 1, 2, 3)
const EXPLOSION_CROSS_CENTERS: Array[int] = [293, 415, 538, 656]

# Quadros da bomba normal pulsando (3 quadros 16x16 autênticos limpos de bordas)
const BOMB_FRAMES: Array[Rect2] = [
	Rect2(3, 6, 18, 18),
	Rect2(20, 6, 17, 18),
	Rect2(37, 6, 16, 18)
]

# Regiões dos Power-Ups (16x16)
const POWERUP_REGIONS: Dictionary = {
	GameState.PowerUpType.BOMB: Rect2(88, 86, 16, 16),
	GameState.PowerUpType.RANGE: Rect2(48, 86, 16, 16),
	GameState.PowerUpType.SPEED: Rect2(29, 86, 16, 16),
	GameState.PowerUpType.HEART: Rect2(88, 105, 16, 16)
}

# Efeito de fumaça / destruição de item e inimigo
const PUFF_FRAMES: Array[Rect2] = [
	Rect2(16, 187, 12, 12),
	Rect2(34, 184, 16, 16),
	Rect2(58, 183, 16, 16),
	Rect2(78, 183, 16, 16),
	Rect2(98, 183, 16, 16),
	Rect2(119, 183, 16, 16)
]

# Inimigos de Campanha (4 arquétipos com 4 quadros cada com recorte perfeito sem sangramento)
const ENEMY_ANIMATIONS: Dictionary = {
	CampaignEnemy.Archetype.WANDERER: [
		Rect2(5, 30, 23, 26),
		Rect2(30, 30, 26, 26),
		Rect2(59, 30, 26, 26),
		Rect2(88, 30, 24, 26)
	],
	CampaignEnemy.Archetype.HUNTER: [
		Rect2(11, 359, 18, 43),
		Rect2(30, 359, 20, 43),
		Rect2(50, 359, 21, 43),
		Rect2(76, 359, 36, 43)
	],
	CampaignEnemy.Archetype.CHARGER: [
		Rect2(433, 491, 26, 26),
		Rect2(460, 491, 26, 26),
		Rect2(487, 491, 26, 26),
		Rect2(460, 491, 26, 26)
	],
	CampaignEnemy.Archetype.BOSS: [
		Rect2(7, 130, 33, 71),
		Rect2(41, 130, 32, 71),
		Rect2(73, 130, 33, 71),
		Rect2(106, 130, 30, 71)
	]
}

# Efeito de morte do inimigo (puff clássico da folha de inimigos)
const ENEMY_DEATH_FRAMES: Array[Rect2] = [
	Rect2(293, 725, 17, 18),
	Rect2(310, 725, 18, 18),
	Rect2(329, 725, 17, 18),
	Rect2(346, 725, 18, 18),
	Rect2(365, 725, 18, 18)
]

static func set_key_shader(sprite: Sprite2D, key_color: Color) -> void:
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if sprite.material is ShaderMaterial:
		(sprite.material as ShaderMaterial).set_shader_parameter("key_color", key_color)
		(sprite.material as ShaderMaterial).set_shader_parameter("key_tolerance", 0.08)
		return
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/sprite_key.gdshader") as Shader
	material.set_shader_parameter("key_color", key_color)
	material.set_shader_parameter("key_tolerance", 0.08)
	sprite.material = material

static func configure_character_sprite(sprite: Sprite2D, character_index: int, frame: int = 0, direction_row: int = 0, flip_horizontal: bool = false) -> void:
	var index := posmod(character_index, CHARACTER_TEXTURES.size())
	var layout: Array = CHARACTER_LAYOUTS[index]
	var origin_x: int = layout[0]
	var origin_y: int = layout[1]
	var stride_x: int = layout[2]
	var stride_y: int = layout[3]
	var frame_w: int = layout[4]
	var frame_h: int = layout[5]

	sprite.texture = load(CHARACTER_TEXTURES[index]) as Texture2D
	sprite.region_enabled = true
	var clamped_frame := clampi(frame, 0, 3)
	var clamped_row := clampi(direction_row, 0, 2)
	sprite.region_rect = Rect2(origin_x + clamped_frame * stride_x, origin_y + clamped_row * stride_y, frame_w, frame_h)
	sprite.position = Vector2(0, -24)
	sprite.scale = Vector2.ONE * 3.2
	sprite.flip_h = direction_row == 2 and flip_horizontal
	set_key_shader(sprite, CHARACTER_KEY_COLORS[index])

static func configure_bomb_sprite(sprite: Sprite2D, frame: int = 0) -> void:
	sprite.texture = load(EFFECTS_TEXTURE) as Texture2D
	sprite.region_enabled = true
	var idx := posmod(frame, BOMB_FRAMES.size())
	sprite.region_rect = BOMB_FRAMES[idx]
	sprite.position = Vector2(0, -13)
	sprite.scale = Vector2.ONE * 3.0
	set_key_shader(sprite, Color8(112, 136, 88))

static func configure_explosion_sprite(sprite: Sprite2D, segment: int, anim_frame: int = 0) -> void:
	sprite.texture = load(EFFECTS_TEXTURE) as Texture2D
	sprite.region_enabled = true
	var frame_idx := posmod(anim_frame, EXPLOSION_CROSS_CENTERS.size())
	var cx: int = EXPLOSION_CROSS_CENTERS[frame_idx]

	var rect: Rect2
	match segment:
		ExplosionSegment.CENTER:
			rect = Rect2(cx, 72, 16, 16)
		ExplosionSegment.BEAM_HORIZONTAL:
			rect = Rect2(cx - 26, 72, 16, 16)
		ExplosionSegment.BEAM_VERTICAL:
			rect = Rect2(cx, 49, 16, 16)
		ExplosionSegment.TIP_UP:
			rect = Rect2(cx, 26, 16, 16)
		ExplosionSegment.TIP_DOWN:
			rect = Rect2(cx, 118, 16, 16)
		ExplosionSegment.TIP_LEFT:
			rect = Rect2(cx - 51, 72, 16, 16)
		ExplosionSegment.TIP_RIGHT:
			rect = Rect2(cx + 45, 72, 16, 16)
		_:
			rect = Rect2(cx, 72, 16, 16)

	sprite.region_rect = rect
	sprite.scale = Vector2.ONE * 4.0
	sprite.position = Vector2.ZERO
	set_key_shader(sprite, Color8(112, 136, 88))

static func configure_powerup_sprite(sprite: Sprite2D, type: GameState.PowerUpType) -> void:
	sprite.texture = load(EFFECTS_TEXTURE) as Texture2D
	sprite.region_enabled = true
	var rect: Rect2 = POWERUP_REGIONS.get(type, Rect2(88, 86, 16, 16))
	sprite.region_rect = rect
	sprite.scale = Vector2.ONE * 3.0
	sprite.position = Vector2.ZERO
	set_key_shader(sprite, Color8(112, 136, 88))

static func configure_powerup_puff(sprite: Sprite2D, frame: int) -> void:
	sprite.texture = load(EFFECTS_TEXTURE) as Texture2D
	sprite.region_enabled = true
	var idx := clampi(frame, 0, PUFF_FRAMES.size() - 1)
	sprite.region_rect = PUFF_FRAMES[idx]
	sprite.scale = Vector2.ONE * 3.0
	sprite.position = Vector2.ZERO
	set_key_shader(sprite, Color8(112, 136, 88))

static func configure_enemy_sprite(sprite: Sprite2D, archetype: int, frame: int = 0, flip_horizontal: bool = false) -> void:
	sprite.texture = load(ENEMIES_TEXTURE) as Texture2D
	sprite.region_enabled = true
	var anim_list: Array = ENEMY_ANIMATIONS.get(archetype, ENEMY_ANIMATIONS[CampaignEnemy.Archetype.WANDERER])
	var idx := posmod(frame, anim_list.size())
	sprite.region_rect = anim_list[idx]
	match archetype:
		CampaignEnemy.Archetype.BOSS:
			sprite.scale = Vector2.ONE * 2.0
			sprite.position = Vector2(0, -56)
		CampaignEnemy.Archetype.HUNTER:
			sprite.scale = Vector2.ONE * 2.0
			sprite.position = Vector2(0, -28)
		CampaignEnemy.Archetype.CHARGER:
			sprite.scale = Vector2.ONE * 2.6
			sprite.position = Vector2(0, -20)
		_: # WANDERER
			sprite.scale = Vector2.ONE * 2.6
			sprite.position = Vector2(0, -20)
	sprite.flip_h = flip_horizontal
	set_key_shader(sprite, Color8(112, 136, 88))

static func configure_enemy_death(sprite: Sprite2D, frame: int) -> void:
	sprite.texture = load(ENEMIES_TEXTURE) as Texture2D
	sprite.region_enabled = true
	var idx := clampi(frame, 0, ENEMY_DEATH_FRAMES.size() - 1)
	sprite.region_rect = ENEMY_DEATH_FRAMES[idx]
	sprite.scale = Vector2.ONE * 3.0
	sprite.position = Vector2(0, -12)
	set_key_shader(sprite, Color8(112, 136, 88))

static func configure_wall_sprite(sprite: Sprite2D, region: Rect2) -> void:
	sprite.texture = load(WALL_TEXTURE) as Texture2D
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.scale = Vector2.ONE * 4.0
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
