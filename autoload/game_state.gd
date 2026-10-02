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

const MAP_NAMES: Array[String] = [
	"Prado Brilhante",
	"Cratera Vulcânica",
	"Geleira Azul",
	"Dunas do Crepúsculo",
	"Fortaleza Central",
	"Corredores Cruzados",
	"Ilhas Gêmeas",
	"Labirinto de Cristal",
	"Ruínas Antigas",
	"Pátio das Chamas"
]

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
