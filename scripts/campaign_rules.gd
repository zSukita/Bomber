class_name CampaignRules
extends RefCounted

## Constantes de balanceamento e progressão do modo campanha.
const STAGE_TIME_LIMIT: int = 180
const POWERUP_DROP_CHANCE: float = 0.32
const GUARANTEED_HEART_BLOCK_COUNT: int = 8
const STAGE_SEED_STEP: int = 7919
const ENEMIES_PER_STAGE: Array[int] = [4, 4, 5, 5, 6, 6, 7, 7, 8, 8]
const BOSS_STAGES: Array[int] = [4, 9]
const STORY_ROUTES: Array[Array] = [
	[1, 2], [3, 4], [4, 5], [6, 7], [7, 8],
	[6, 8], [9], [9], [9], []
]
const PORTAL_CANDIDATE_CELLS: Array[Vector2i] = [
	Vector2i(7, 6), Vector2i(7, 5), Vector2i(7, 7), Vector2i(6, 6), Vector2i(8, 6),
	Vector2i(6, 5), Vector2i(8, 5), Vector2i(6, 7), Vector2i(8, 7), Vector2i(7, 4),
	Vector2i(7, 8), Vector2i(5, 6), Vector2i(9, 6)
]
