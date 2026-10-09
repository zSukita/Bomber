extends Node

## Gerenciador global de estado do jogo e definições compartilhadas (Singleton).
## Centraliza enums compartilhados para evitar dependências circulares de tipo no GDScript.

enum GameStatus {
	LOBBY,
	IN_GAME,
	ROUND_OVER,
	MATCH_OVER
}

enum GameMode {
	BATTLE,
	CAMPAIGN
}

enum CellType {
	EMPTY = 0,
	WALL_INDESTRUCTIBLE = 1,
	BLOCK_DESTRUCTIBLE = 2
}

enum PowerUpType {
	BOMB = 0,
	RANGE = 1,
	SPEED = 2,
	HEART = 3
}

const MAP_NAMES: Array[String] = ArenaMapStyles.NAMES

var current_status: GameStatus = GameStatus.LOBBY
var current_round: int = 1
var max_rounds: int = 3
var game_mode: GameMode = GameMode.BATTLE
var campaign_stage_index: int = 0
var campaign_lives: int = 5
var campaign_seed: int = 0
var campaign_visited_stages: Array[int] = []
var campaign_heart_stages: Array[int] = []
var campaign_golden_choices: int = 0
var campaign_blue_choices: int = 0
var local_pause_menu_open: bool = false

# ----------------- CONFIGURAÇÕES DO MODO MELHORADO -----------------
signal enhanced_mode_toggled(is_enhanced: bool)

## Alterna apenas a apresentação visual para comparação com o modo base.
var enhanced_mode: bool = true

## Intensidade do tremor da câmera (0.0 a 1.0).
var screen_shake_intensity: float = 1.0

## Intensidade dos efeitos decorativos (0.0 a 1.0).
var visual_effects_intensity: float = 1.0

## Reduz pulsos luminosos repetidos sem ocultar avisos de combate.
var reduced_flashes_enabled: bool = false

## Brilho e duração do flash de confirmação de dano (segundos).
var impact_flash_intensity: float = 0.75
var impact_flash_duration: float = 0.10

## Efeitos direcionais de estilhaços e detritos
var directional_debris_enabled: bool = true

## Partículas de ambiente contextualizadas e nuvens em movimento
var ambient_particles_enabled: bool = true
var ambient_clouds_enabled: bool = true
var ambient_wind_enabled: bool = true

## Squash & stretch nas passadas e animações do personagem
var character_squash_stretch: bool = true

## Assistência de movimento, aplicada igualmente nos modos gráficos.
var corner_slide_assistance: bool = true

## Buffer de comando, aplicado igualmente nos modos gráficos.
var input_buffering_enabled: bool = true
var input_buffer_window: float = 0.15

## Variação de pitch e ambiência nos efeitos sonoros
var sfx_pitch_variation: bool = true

func is_enhanced() -> bool:
	return enhanced_mode

func toggle_enhanced_mode() -> bool:
	set_enhanced_mode(not enhanced_mode)
	return enhanced_mode

func set_enhanced_mode(enabled: bool) -> void:
	if enhanced_mode != enabled:
		enhanced_mode = enabled
		if not enabled and is_inside_tree():
			get_tree().call_group("enhanced_visual_effects", "queue_free")
		enhanced_mode_toggled.emit(enhanced_mode)

