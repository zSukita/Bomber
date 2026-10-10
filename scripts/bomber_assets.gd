class_name BomberAssets
extends RefCounted

## Gerenciador e configurador central de todos os sprites e assets oficiais e livres do Bombástico.

const CHARACTER_NAMES: Array[String] = [
	"Robô Beta", "Robô Alfa", "Robô Tático", "Ninja Bomb",
	"Ninja Fogo", "Samurai Azul", "Samurai Rubro", "Cavaleiro"
]

const CHARACTER_TEXTURES: Array[String] = [
	"res://assets/legal/characters/character_0.png",
	"res://assets/legal/characters/character_1.png",
	"res://assets/legal/characters/character_2.png",
	"res://assets/legal/characters/character_3.png",
	"res://assets/legal/characters/character_4.png",
	"res://assets/legal/characters/character_5.png",
	"res://assets/legal/characters/character_6.png",
	"res://assets/legal/characters/character_7.png"
]

const CHARACTER_KEY_COLORS: Array[Color] = [
	Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE,
	Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE
]

# Texturas legais de fases, itens, efeitos e inimigos
const WALL_TEXTURE: String = "res://assets/legal/tiles/tileset.png"
const BOMB_TEXTURE: String = "res://assets/legal/bomb.png"
const EXPLOSION_TEXTURE: String = "res://assets/legal/explosion.png"
const ITEMS_TEXTURE: String = "res://assets/legal/items.png"
const PUFF_TEXTURE: String = "res://assets/legal/puff.png"
const PIXEL_FONT: String = "res://assets/legal/fonts/pixel_font.ttf"

const ENEMY_TEXTURES: Dictionary = {
	CampaignEnemy.Archetype.WANDERER: "res://assets/legal/enemies/enemy_0.png",
	CampaignEnemy.Archetype.HUNTER: "res://assets/legal/enemies/enemy_1.png",
	CampaignEnemy.Archetype.CHARGER: "res://assets/legal/enemies/enemy_2.png",
	CampaignEnemy.Archetype.BOSS: "res://assets/legal/enemies/enemy_3.png"
}

const WALL_REGION := Rect2(0, 0, 16, 16)
const BLOCK_REGION := Rect2(16, 0, 16, 16)

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

# Quadros da bomba normal pulsando (3 quadros 16x16)
const BOMB_FRAMES: Array[Rect2] = [
	Rect2(0, 0, 16, 16),
	Rect2(16, 0, 16, 16),
	Rect2(32, 0, 16, 16)
]

# Regiões dos Power-Ups (16x16)
const POWERUP_REGIONS: Dictionary = {
	GameState.PowerUpType.BOMB: Rect2(0, 0, 16, 16),
	GameState.PowerUpType.RANGE: Rect2(16, 0, 16, 16),
	GameState.PowerUpType.SPEED: Rect2(32, 0, 16, 16),
	GameState.PowerUpType.HEART: Rect2(48, 0, 16, 16)
}

# Efeito de fumaça / destruição de item
const PUFF_FRAMES: Array[Rect2] = [
	Rect2(0, 0, 32, 32),
	Rect2(32, 0, 32, 32),
	Rect2(64, 0, 32, 32),
	Rect2(96, 0, 32, 32),
	Rect2(128, 0, 32, 32),
	Rect2(160, 0, 32, 32)
]

# Efeito de morte do inimigo
const ENEMY_DEATH_FRAMES: Array[Rect2] = [
	Rect2(0, 0, 32, 32),
	Rect2(32, 0, 32, 32),
	Rect2(64, 0, 32, 32),
	Rect2(96, 0, 32, 32),
	Rect2(128, 0, 32, 32),
	Rect2(160, 0, 32, 32)
]

static func set_key_shader(sprite: Sprite2D, _key_color: Color) -> void:
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.material = null

static func configure_character_sprite(sprite: Sprite2D, character_index: int, frame: int = 0, direction_row: int = 0, flip_horizontal: bool = false) -> void:
	var index := posmod(character_index, CHARACTER_TEXTURES.size())
	sprite.texture = load(CHARACTER_TEXTURES[index]) as Texture2D
	sprite.region_enabled = true
	var clamped_frame := clampi(frame, 0, 3)
	var clamped_row := clampi(direction_row, 0, 2)
	sprite.region_rect = Rect2(clamped_frame * 16, clamped_row * 16, 16, 16)
	sprite.position = Vector2(0, -18)
	sprite.scale = Vector2.ONE * 3.8
	sprite.flip_h = direction_row == 2 and flip_horizontal
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.material = null

static func configure_bomb_sprite(sprite: Sprite2D, frame: int = 0) -> void:
	sprite.texture = load(BOMB_TEXTURE) as Texture2D
	sprite.region_enabled = true
	var idx := posmod(frame, BOMB_FRAMES.size())
	sprite.region_rect = BOMB_FRAMES[idx]
	sprite.position = Vector2(0, -14)
	sprite.scale = Vector2.ONE * 3.5
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.material = null

static func configure_explosion_sprite(sprite: Sprite2D, segment: int, anim_frame: int = 0) -> void:
	sprite.texture = load(EXPLOSION_TEXTURE) as Texture2D
	sprite.region_enabled = true
	var frame_idx := clampi(anim_frame, 0, 3)
	var seg_idx := clampi(segment, 0, 6)
	sprite.region_rect = Rect2(frame_idx * 16, seg_idx * 16, 16, 16)
	sprite.scale = Vector2.ONE * 4.0
	sprite.position = Vector2.ZERO
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.material = null

static func configure_powerup_sprite(sprite: Sprite2D, type: GameState.PowerUpType) -> void:
	sprite.texture = load(ITEMS_TEXTURE) as Texture2D
	sprite.region_enabled = true
	var rect: Rect2 = POWERUP_REGIONS.get(type, Rect2(0, 0, 16, 16))
	sprite.region_rect = rect
	sprite.scale = Vector2.ONE * 3.0
	sprite.position = Vector2.ZERO
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.material = null

static func configure_powerup_puff(sprite: Sprite2D, frame: int) -> void:
	sprite.texture = load(PUFF_TEXTURE) as Texture2D
	sprite.region_enabled = true
	var idx := clampi(frame, 0, PUFF_FRAMES.size() - 1)
	sprite.region_rect = PUFF_FRAMES[idx]
	sprite.scale = Vector2.ONE * 1.8
	sprite.position = Vector2.ZERO
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.material = null

static func configure_enemy_sprite(sprite: Sprite2D, archetype: int, frame: int = 0, flip_horizontal: bool = false) -> void:
	var tex_path: String = ENEMY_TEXTURES.get(archetype, ENEMY_TEXTURES[CampaignEnemy.Archetype.WANDERER])
	sprite.texture = load(tex_path) as Texture2D
	sprite.region_enabled = true
	var frame_idx := clampi(frame, 0, 3)
	if archetype == CampaignEnemy.Archetype.BOSS:
		sprite.region_rect = Rect2(frame_idx * 50, 0, 50, 50)
		sprite.scale = Vector2.ONE * 2.2
		sprite.position = Vector2(0, -36)
	else:
		sprite.region_rect = Rect2(frame_idx * 16, 0, 16, 16)
		sprite.scale = Vector2.ONE * 3.2
		sprite.position = Vector2(0, -18)
	sprite.flip_h = flip_horizontal
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.material = null

static func configure_enemy_death(sprite: Sprite2D, frame: int) -> void:
	sprite.texture = load(PUFF_TEXTURE) as Texture2D
	sprite.region_enabled = true
	var idx := clampi(frame, 0, ENEMY_DEATH_FRAMES.size() - 1)
	sprite.region_rect = ENEMY_DEATH_FRAMES[idx]
	sprite.scale = Vector2.ONE * 2.0
	sprite.position = Vector2(0, -12)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.material = null

static func configure_wall_sprite(sprite: Sprite2D, region: Rect2) -> void:
	sprite.texture = load(WALL_TEXTURE) as Texture2D
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.scale = Vector2.ONE * 4.0
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.material = null
