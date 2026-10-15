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
	HEART = 3,
	KICK = 4,
	PIERCE = 5,
	REMOTE = 6,
	SKULL = 7,
	MOUNT_EGG = 8,
	ICE_BOMB = 9,
	THUNDER_BOMB = 10
}

enum MountType {
	NONE = 0,
	GREEN = 1,
	BLUE = 2,
	YELLOW = 3
}

const MAP_NAMES: Array[String] = ArenaMapStyles.NAMES
const CAMPAIGN_SAVE_PATH: String = "user://campaign_progress.cfg"
const CAMPAIGN_SAVE_VERSION: int = 1

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
var campaign_max_bombs: int = 1
var campaign_bomb_range: int = 2
var campaign_speed_multiplier: float = 1.0
var campaign_has_heart: bool = false
var campaign_has_kick: bool = false
var campaign_progress_initialized: bool = false
var local_pause_menu_open: bool = false
var preferred_character_index: int = 0

enum BotDifficulty {
	EASY = 0,
	MEDIUM = 1,
	HARD = 2
}
var bot_difficulty: BotDifficulty = BotDifficulty.MEDIUM
var battle_bot_count: int = 3

# ----------------- CONFIGURAÇÕES DE TECLAS (INPUT REMAPPER) -----------------
const DEFAULT_KEYBINDINGS: Dictionary = {
	"move_up": [KEY_UP, KEY_W],
	"move_down": [KEY_DOWN, KEY_S],
	"move_left": [KEY_LEFT, KEY_A],
	"move_right": [KEY_RIGHT, KEY_D],
	"drop_bomb": [KEY_SPACE, KEY_ENTER],
	"pause_game": [KEY_ESCAPE, KEY_P]
}

var custom_keybindings: Dictionary = {}
signal keybindings_updated

# ----------------- CONFIGURAÇÕES DO MODO MELHORADO -----------------
signal enhanced_mode_toggled(is_enhanced: bool)
signal user_preferences_loaded

const USER_SETTINGS_PATH: String = "user://user_settings.cfg"
const DEFAULT_MASTER_VOLUME: float = 85.0
const DEFAULT_MUSIC_VOLUME: float = 75.0
const DEFAULT_SFX_VOLUME: float = 90.0

var master_volume_percent: float = DEFAULT_MASTER_VOLUME
var music_volume_percent: float = DEFAULT_MUSIC_VOLUME
var sfx_volume_percent: float = DEFAULT_SFX_VOLUME
var fullscreen_enabled: bool = false

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

## Idioma do jogo (pt, en, es)
var current_locale: String = "pt"
const SUPPORTED_LOCALES: PackedStringArray = ["pt", "en", "es"]

signal locale_changed(new_locale: String)

func _ready() -> void:
	_setup_translations()
	call_deferred("_load_user_preferences")

func _setup_translations() -> void:
	if not FileAccess.file_exists("res://assets/translations.csv"):
		return
	var file := FileAccess.open("res://assets/translations.csv", FileAccess.READ)
	if not file:
		return
	var header := file.get_csv_line()
	if header.size() < 2:
		return
	
	var translations: Dictionary = {}
	for i in range(1, header.size()):
		var loc: String = header[i].strip_edges()
		var tr := Translation.new()
		tr.locale = loc
		translations[i] = tr
	
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.is_empty() or row[0].strip_edges().is_empty():
			continue
		var key: String = row[0].strip_edges()
		for target_column in range(1, mini(row.size(), header.size())):
			if not translations.has(target_column):
				continue
			var target_translation: Translation = translations[target_column]
			target_translation.add_message(key, row[target_column])
			# Support both explicit stable keys (tr("BTN_HOST")) and Godot's
			# automatic translation of Control text properties (source phrase).
			for source_column in range(1, mini(row.size(), header.size())):
				var source_phrase: String = row[source_column].strip_edges()
				if not source_phrase.is_empty():
					target_translation.add_message(source_phrase, row[target_column])
	
	for i in translations:
		TranslationServer.add_translation(translations[i])

func set_game_locale(new_locale: String) -> void:
	var normalized_locale: String = new_locale.to_lower().split("_")[0]
	if not normalized_locale in SUPPORTED_LOCALES:
		normalized_locale = "pt"
	current_locale = normalized_locale
	TranslationServer.set_locale(current_locale)
	locale_changed.emit(current_locale)
	save_user_preferences()

func _load_user_preferences() -> void:
	var settings := ConfigFile.new()
	var loaded_enhanced_mode: bool = enhanced_mode
	var had_saved_settings: bool = false
	if settings.load(USER_SETTINGS_PATH) == OK:
		had_saved_settings = true
		var name_value := str(settings.get_value("profile", "player_name", "Jogador")).strip_edges()
		if not name_value.is_empty():
			NetworkManager.local_player_name = name_value
		NetworkManager.preferred_color_index = clampi(int(settings.get_value("profile", "color_index", 0)), 0, Player.PLAYER_COLORS.size() - 1)
		preferred_character_index = clampi(int(settings.get_value("profile", "character_index", 0)), 0, BomberAssets.CHARACTER_NAMES.size() - 1)
		NetworkManager.preferred_character_index = preferred_character_index
		var saved_locale: String = str(settings.get_value("general", "locale", "pt")).to_lower().split("_")[0]
		current_locale = saved_locale if saved_locale in SUPPORTED_LOCALES else "pt"
		master_volume_percent = clampf(float(settings.get_value("audio", "master", DEFAULT_MASTER_VOLUME)), 0.0, 100.0)
		music_volume_percent = clampf(float(settings.get_value("audio", "music", DEFAULT_MUSIC_VOLUME)), 0.0, 100.0)
		sfx_volume_percent = clampf(float(settings.get_value("audio", "sfx", DEFAULT_SFX_VOLUME)), 0.0, 100.0)
		fullscreen_enabled = bool(settings.get_value("video", "fullscreen", false))
		loaded_enhanced_mode = bool(settings.get_value("video", "enhanced", enhanced_mode))
		screen_shake_intensity = clampf(float(settings.get_value("video", "screen_shake", screen_shake_intensity)), 0.0, 1.0)
		visual_effects_intensity = clampf(float(settings.get_value("video", "visual_effects", visual_effects_intensity)), 0.0, 1.0)
		reduced_flashes_enabled = bool(settings.get_value("video", "reduced_flashes", reduced_flashes_enabled))
		battle_bot_count = clampi(int(settings.get_value("gameplay", "battle_bot_count", 1)), 0, 3)
		bot_difficulty = clampi(int(settings.get_value("gameplay", "bot_difficulty", BotDifficulty.MEDIUM)), 0, 2) as BotDifficulty
		custom_keybindings.clear()
		for action in DEFAULT_KEYBINDINGS.keys():
			if settings.has_section_key("keybindings", action):
				var saved_val: Variant = settings.get_value("keybindings", action)
				if saved_val is Array and not saved_val.is_empty():
					custom_keybindings[action] = saved_val
	apply_keybindings_to_input_map()
	TranslationServer.set_locale(current_locale)
	if had_saved_settings and enhanced_mode != loaded_enhanced_mode:
		enhanced_mode = loaded_enhanced_mode
		if not enhanced_mode and is_inside_tree():
			get_tree().call_group("enhanced_visual_effects", "queue_free")
		enhanced_mode_toggled.emit(enhanced_mode)
	var master_bus_idx: int = AudioServer.get_bus_index("Master")
	var master_linear: float = master_volume_percent / 100.0
	AudioServer.set_bus_volume_db(master_bus_idx, linear_to_db(master_linear) if master_linear > 0.0 else -80.0)
	AudioManager.set_music_volume(music_volume_percent / 100.0)
	AudioManager.set_sfx_volume(sfx_volume_percent / 100.0)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen_enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	user_preferences_loaded.emit()

func save_user_preferences() -> bool:
	var settings := ConfigFile.new()
	settings.set_value("general", "locale", current_locale)
	settings.set_value("profile", "player_name", NetworkManager.local_player_name)
	settings.set_value("profile", "color_index", NetworkManager.preferred_color_index)
	settings.set_value("profile", "character_index", NetworkManager.preferred_character_index)
	settings.set_value("audio", "master", master_volume_percent)
	settings.set_value("audio", "music", music_volume_percent)
	settings.set_value("audio", "sfx", sfx_volume_percent)
	settings.set_value("video", "fullscreen", fullscreen_enabled)
	settings.set_value("video", "enhanced", enhanced_mode)
	settings.set_value("video", "screen_shake", screen_shake_intensity)
	settings.set_value("video", "visual_effects", visual_effects_intensity)
	settings.set_value("video", "reduced_flashes", reduced_flashes_enabled)
	settings.set_value("gameplay", "battle_bot_count", battle_bot_count)
	settings.set_value("gameplay", "bot_difficulty", bot_difficulty)
	for action in custom_keybindings:
		settings.set_value("keybindings", action, custom_keybindings[action])
	return settings.save(USER_SETTINGS_PATH) == OK

func apply_keybindings_to_input_map() -> void:
	for action in DEFAULT_KEYBINDINGS.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		
		# Limpa eventos de teclado anteriores para reatribuição limpa
		var old_events: Array[InputEvent] = InputMap.action_get_events(action)
		for ev in old_events:
			if ev is InputEventKey:
				InputMap.action_erase_event(action, ev)
		
		var keycodes: Array = custom_keybindings.get(action, DEFAULT_KEYBINDINGS[action])
		for code in keycodes:
			var int_code := int(code)
			var key_event := InputEventKey.new()
			key_event.physical_keycode = int_code as Key
			key_event.keycode = int_code as Key
			InputMap.action_add_event(action, key_event)
	
	_ensure_joypad_inputs()
	keybindings_updated.emit()

## Garante suporte total a controles/joysticks (D-Pad, Analógico Esquerdo, Botões A/X/B/RB e Start/Back)
func _ensure_joypad_inputs() -> void:
	var joy_configs: Dictionary = {
		"move_up": [
			{"type": "button", "index": JOY_BUTTON_DPAD_UP},
			{"type": "motion", "axis": JOY_AXIS_LEFT_Y, "value": -1.0}
		],
		"move_down": [
			{"type": "button", "index": JOY_BUTTON_DPAD_DOWN},
			{"type": "motion", "axis": JOY_AXIS_LEFT_Y, "value": 1.0}
		],
		"move_left": [
			{"type": "button", "index": JOY_BUTTON_DPAD_LEFT},
			{"type": "motion", "axis": JOY_AXIS_LEFT_X, "value": -1.0}
		],
		"move_right": [
			{"type": "button", "index": JOY_BUTTON_DPAD_RIGHT},
			{"type": "motion", "axis": JOY_AXIS_LEFT_X, "value": 1.0}
		],
		"drop_bomb": [
			{"type": "button", "index": JOY_BUTTON_A},
			{"type": "button", "index": JOY_BUTTON_X},
			{"type": "button", "index": JOY_BUTTON_B},
			{"type": "button", "index": JOY_BUTTON_RIGHT_SHOULDER}
		],
		"pause_game": [
			{"type": "button", "index": JOY_BUTTON_START},
			{"type": "button", "index": JOY_BUTTON_BACK}
		]
	}
	
	for action in joy_configs:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var current_events: Array[InputEvent] = InputMap.action_get_events(action)
		for entry: Dictionary in joy_configs[action]:
			if entry["type"] == "button":
				var b_idx: int = entry["index"]
				var has_btn: bool = false
				for ev in current_events:
					if ev is InputEventJoypadButton and ev.button_index == b_idx:
						has_btn = true
						break
				if not has_btn:
					var joy_btn := InputEventJoypadButton.new()
					joy_btn.device = -1
					joy_btn.button_index = b_idx as JoyButton
					InputMap.action_add_event(action, joy_btn)
			elif entry["type"] == "motion":
				var a_idx: int = entry["axis"]
				var a_val: float = entry["value"]
				var has_mot: bool = false
				for ev in current_events:
					if ev is InputEventJoypadMotion and ev.axis == a_idx and is_equal_approx(ev.axis_value, a_val):
						has_mot = true
						break
				if not has_mot:
					var joy_mot := InputEventJoypadMotion.new()
					joy_mot.device = -1
					joy_mot.axis = a_idx as JoyAxis
					joy_mot.axis_value = a_val
					InputMap.action_add_event(action, joy_mot)

func rebind_action(action: String, new_keycode: int) -> void:
	if not DEFAULT_KEYBINDINGS.has(action):
		return
	custom_keybindings[action] = [new_keycode]
	apply_keybindings_to_input_map()
	save_user_preferences()

func reset_default_keybindings() -> void:
	custom_keybindings.clear()
	apply_keybindings_to_input_map()
	save_user_preferences()

func get_action_display_name(action: String) -> String:
	match action:
		"move_up": return "Mover para Cima"
		"move_down": return "Mover para Baixo"
		"move_left": return "Mover para a Esquerda"
		"move_right": return "Mover para a Direita"
		"drop_bomb": return "Soltar Bomba"
		"pause_game": return "Pausar Jogo"
		_: return action.capitalize()

func get_action_key_text(action: String) -> String:
	if not InputMap.has_action(action):
		return "Nenhuma"
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	var names: Array[String] = []
	for ev in events:
		if ev is InputEventKey:
			var code: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
			var name_str: String = OS.get_keycode_string(code as Key)
			match code:
				KEY_UP: name_str = tr("KEY_ARROW_UP")
				KEY_DOWN: name_str = tr("KEY_ARROW_DOWN")
				KEY_LEFT: name_str = tr("KEY_ARROW_LEFT")
				KEY_RIGHT: name_str = tr("KEY_ARROW_RIGHT")
				KEY_SPACE: name_str = tr("KEY_SPACE")
				KEY_ESCAPE: name_str = tr("KEY_ESCAPE")
				KEY_ENTER: name_str = "Enter"
			if not names.has(name_str):
				names.append(name_str)
	return " / ".join(names) if not names.is_empty() else "Nenhuma"

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
		save_user_preferences()

func start_new_campaign() -> void:
	campaign_stage_index = 0
	campaign_lives = 5
	campaign_seed = randi()
	if campaign_seed == 0:
		campaign_seed = 1
	campaign_visited_stages.clear()
	campaign_visited_stages.append(0)
	campaign_heart_stages.clear()
	campaign_golden_choices = 0
	campaign_blue_choices = 0
	reset_campaign_upgrades()
	campaign_progress_initialized = true
	save_campaign_progress()

func has_campaign_save() -> bool:
	var save := ConfigFile.new()
	if save.load(CAMPAIGN_SAVE_PATH) != OK:
		return false
	return int(save.get_value("campaign", "version", 0)) == CAMPAIGN_SAVE_VERSION \
		and int(save.get_value("campaign", "stage_index", -1)) >= 0 \
		and int(save.get_value("campaign", "stage_index", -1)) < MAP_NAMES.size() \
		and int(save.get_value("campaign", "lives", 0)) > 0 \
		and int(save.get_value("campaign", "seed", 0)) != 0

func load_campaign_progress() -> bool:
	var save := ConfigFile.new()
	if save.load(CAMPAIGN_SAVE_PATH) != OK:
		return false
	if int(save.get_value("campaign", "version", 0)) != CAMPAIGN_SAVE_VERSION:
		return false
	var stage_index := int(save.get_value("campaign", "stage_index", -1))
	var lives := int(save.get_value("campaign", "lives", 0))
	var seed_value := int(save.get_value("campaign", "seed", 0))
	if stage_index < 0 or stage_index >= MAP_NAMES.size() or lives <= 0 or seed_value == 0:
		return false
	campaign_stage_index = stage_index
	campaign_lives = clampi(lives, 1, 9)
	campaign_seed = seed_value
	campaign_visited_stages = _validated_stage_list(save.get_value("campaign", "visited_stages", [stage_index]))
	if not campaign_visited_stages.has(stage_index):
		campaign_visited_stages.append(stage_index)
	campaign_heart_stages = _validated_stage_list(save.get_value("campaign", "heart_stages", []))
	campaign_golden_choices = maxi(0, int(save.get_value("campaign", "golden_choices", 0)))
	campaign_blue_choices = maxi(0, int(save.get_value("campaign", "blue_choices", 0)))
	campaign_max_bombs = clampi(int(save.get_value("player", "max_bombs", 1)), 1, 8)
	campaign_bomb_range = clampi(int(save.get_value("player", "bomb_range", 2)), 1, 8)
	campaign_speed_multiplier = clampf(float(save.get_value("player", "speed_multiplier", 1.0)), 1.0, 1.8)
	campaign_has_heart = bool(save.get_value("player", "has_heart", false))
	campaign_has_kick = bool(save.get_value("player", "has_kick", false))
	campaign_progress_initialized = true
	return true

func save_campaign_progress() -> bool:
	if not campaign_progress_initialized or campaign_lives <= 0:
		return false
	var save := ConfigFile.new()
	save.set_value("campaign", "version", CAMPAIGN_SAVE_VERSION)
	save.set_value("campaign", "stage_index", clampi(campaign_stage_index, 0, MAP_NAMES.size() - 1))
	save.set_value("campaign", "lives", clampi(campaign_lives, 1, 9))
	save.set_value("campaign", "seed", campaign_seed)
	save.set_value("campaign", "visited_stages", campaign_visited_stages)
	save.set_value("campaign", "heart_stages", campaign_heart_stages)
	save.set_value("campaign", "golden_choices", campaign_golden_choices)
	save.set_value("campaign", "blue_choices", campaign_blue_choices)
	save.set_value("player", "max_bombs", campaign_max_bombs)
	save.set_value("player", "bomb_range", campaign_bomb_range)
	save.set_value("player", "speed_multiplier", campaign_speed_multiplier)
	save.set_value("player", "has_heart", campaign_has_heart)
	save.set_value("player", "has_kick", campaign_has_kick)
	return save.save(CAMPAIGN_SAVE_PATH) == OK

func clear_campaign_progress() -> void:
	var absolute_path := ProjectSettings.globalize_path(CAMPAIGN_SAVE_PATH)
	if FileAccess.file_exists(CAMPAIGN_SAVE_PATH):
		DirAccess.remove_absolute(absolute_path)
	campaign_progress_initialized = false

func reset_campaign_upgrades() -> void:
	campaign_max_bombs = 1
	campaign_bomb_range = 2
	campaign_speed_multiplier = 1.0
	campaign_has_heart = false
	campaign_has_kick = false

func _validated_stage_list(value: Variant) -> Array[int]:
	var stages: Array[int] = []
	if value is Array:
		for item in value:
			var stage := int(item)
			if stage >= 0 and stage < MAP_NAMES.size() and not stages.has(stage):
				stages.append(stage)
	return stages
