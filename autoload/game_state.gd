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

## Ativa ou desativa todo o conjunto de melhorias visuais, de impacto e de jogabilidade
var enhanced_mode: bool = true

## Intensidade do tremor de tela (0.0 a 2.0)
var screen_shake_intensity: float = 1.0

## Micro-pausa (freeze-frame) em impactos relevantes
var hitstop_enabled: bool = true
var hitstop_duration: float = 0.045

## Efeitos direcionais de estilhaços e detritos
var directional_debris_enabled: bool = true

## Partículas de ambiente contextualizadas e nuvens em movimento
var ambient_particles_enabled: bool = true
var ambient_clouds_enabled: bool = true
var ambient_wind_enabled: bool = true

## Squash & stretch nas passadas e animações do personagem
var character_squash_stretch: bool = true

## Assistência sutil de contorno de quinas ao virar corredores
var corner_slide_assistance: bool = true

## Buffer de comandos para soltura de bombas
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
		enhanced_mode_toggled.emit(enhanced_mode)

