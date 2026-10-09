extends Node

## Gerenciador de Áudio Procedural (Autoload / Singleton).
## Gera efeitos sonoros sintetizados em tempo real via código (PCM AudioStreamWAV)
## sem depender de arquivos externos de áudio, funcionando em qualquer plataforma.
## Suporta fácil substituição por arquivos .wav/.ogg em assets/audio/ no futuro.

var players_pool: Array[AudioStreamPlayer] = []
const POOL_SIZE: int = 8

# Caches de efeitos sonoros gerados
var sfx_bomb_drop: AudioStreamWAV
var sfx_explosion: AudioStreamWAV
var sfx_powerup: AudioStreamWAV
var sfx_death: AudioStreamWAV
var sfx_click: AudioStreamWAV
var sfx_block_break: AudioStreamWAV
var sfx_hover: AudioStreamWAV
var sfx_menu_open: AudioStreamWAV
var sfx_menu_back: AudioStreamWAV

# Música de fundo
var menu_music_stream: AudioStreamWAV
var music_player: AudioStreamPlayer
var pitch_rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pitch_rng.randomize()
	
	# Canal dedicado para música de fundo
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	music_player.volume_db = -12.0
	add_child(music_player)
	
	# Cria pool de canais de áudio para permitir múltiplos sons simultâneos sem corte
	for i in range(POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		players_pool.append(player)
	
	_generate_all_sfx()

## Sintetiza todos os efeitos sonoros clássicos em formato PCM 16-bit 44.1kHz
func _generate_all_sfx() -> void:
	sfx_bomb_drop = _create_thud_sfx()
	sfx_explosion = _create_explosion_sfx()
	sfx_powerup = _create_powerup_sfx()
	sfx_death = _create_death_sfx()
	sfx_click = _create_click_sfx()
	sfx_block_break = _create_block_break_sfx()
	sfx_hover = _create_hover_sfx()
	sfx_menu_open = _create_menu_open_sfx()
	sfx_menu_back = _create_menu_back_sfx()
	menu_music_stream = _create_ambient_music()

func play_bomb_drop() -> void:
	_play_stream(sfx_bomb_drop, -4.0)

func play_explosion() -> void:
	_play_stream(sfx_explosion, 0.0)

func play_powerup() -> void:
	_play_stream(sfx_powerup, -3.0)

func play_death() -> void:
	_play_stream(sfx_death, -2.0)

func play_click() -> void:
	_play_stream(sfx_click, -6.0)

func play_button_click() -> void:
	_play_stream(sfx_click, -5.0)

func play_button_hover() -> void:
	_play_stream(sfx_hover, -10.0)

func play_menu_open() -> void:
	_play_stream(sfx_menu_open, -6.0)

func play_menu_back() -> void:
	_play_stream(sfx_menu_back, -7.0)

func play_menu_music() -> void:
	if not music_player.playing and menu_music_stream:
		music_player.stream = menu_music_stream
		music_player.play()

func stop_menu_music() -> void:
	if music_player.playing:
		music_player.stop()

func set_music_volume(volume_db: float) -> void:
	music_player.volume_db = volume_db

func play_block_break() -> void:
	_play_stream(sfx_block_break, -4.5)

func _play_stream(stream: AudioStream, volume_db: float = 0.0) -> void:
	if not stream:
		return
	
	var pitch: float = 1.0
	if GameState.is_enhanced() and GameState.sfx_pitch_variation:
		pitch = pitch_rng.randf_range(0.94, 1.06)
	
	for p in players_pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return
	
	# Se todos os canais estiverem ocupados, reutiliza o primeiro
	players_pool[0].stream = stream
	players_pool[0].volume_db = volume_db
	players_pool[0].pitch_scale = pitch
	players_pool[0].play()

# ----------------- GERADORES DE ONDAS SINTETIZADAS -----------------

## Som de colocar bomba: impacto surdo / pop grave
func _create_thud_sfx() -> AudioStreamWAV:
	var sample_rate: int = 44100
	var duration: float = 0.12
	var samples_count: int = int(sample_rate * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples_count * 2)
	
	for i in range(samples_count):
		var t: float = float(i) / sample_rate
		var progress: float = float(i) / samples_count
		var freq: float = lerp(160.0, 50.0, progress)
		var envelope: float = (1.0 - progress) * (1.0 - progress)
		var val: float = sin(t * freq * TAU) * envelope * 0.7
		var sample_16: int = clampi(int(val * 32767.0), -32768, 32767)
		
		data.encode_s16(i * 2, sample_16)
	
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	return wav

## Som de explosão: ruído branco turbulento com estrondo grave e decaimento
func _create_explosion_sfx() -> AudioStreamWAV:
	var sample_rate: int = 44100
	var duration: float = 0.55
	var samples_count: int = int(sample_rate * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples_count * 2)
	
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	
	var last_noise: float = 0.0
	for i in range(samples_count):
		var t: float = float(i) / sample_rate
		var progress: float = float(i) / samples_count
		var envelope: float = pow(1.0 - progress, 2.2)
		
		# Filtro passa-baixa simples sobre ruído branco
		var white_noise: float = rng.randf_range(-1.0, 1.0)
		last_noise = lerp(last_noise, white_noise, 0.22)
		
		# Componente de sub-grave para impacto
		var rumble: float = sin(t * 55.0 * TAU) * 0.4
		var val: float = (last_noise * 0.7 + rumble) * envelope
		var sample_16: int = clampi(int(val * 32767.0), -32768, 32767)
		
		data.encode_s16(i * 2, sample_16)
	
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	return wav

## Som de power-up: arpeggio retrô ascendente estilo 8-bit
func _create_powerup_sfx() -> AudioStreamWAV:
	var sample_rate: int = 44100
	var duration: float = 0.24
	var samples_count: int = int(sample_rate * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples_count * 2)
	
	var notes: Array[float] = [392.0, 523.25, 659.25, 783.99, 1046.5] # G4, C5, E5, G5, C6
	
	for i in range(samples_count):
		var progress: float = float(i) / samples_count
		var note_idx: int = clampi(int(progress * notes.size()), 0, notes.size() - 1)
		var freq: float = notes[note_idx]
		var t: float = float(i) / sample_rate
		
		var envelope: float = 1.0 - (progress * 0.4)
		# Onda quadrada suave (retrô arcade)
		var sq: float = 1.0 if sin(t * freq * TAU) > 0.0 else -1.0
		var val: float = sq * 0.35 * envelope
		var sample_16: int = clampi(int(val * 32767.0), -32768, 32767)
		
		data.encode_s16(i * 2, sample_16)
	
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	return wav

## Som de eliminação: glissando descendente
func _create_death_sfx() -> AudioStreamWAV:
	var sample_rate: int = 44100
	var duration: float = 0.45
	var samples_count: int = int(sample_rate * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples_count * 2)
	
	for i in range(samples_count):
		var t: float = float(i) / sample_rate
		var progress: float = float(i) / samples_count
		var freq: float = lerp(580.0, 90.0, pow(progress, 0.7))
		var envelope: float = (1.0 - progress)
		var saw: float = (fposmod(t * freq, 1.0) * 2.0 - 1.0)
		var val: float = saw * 0.3 * envelope
		var sample_16: int = clampi(int(val * 32767.0), -32768, 32767)
		
		data.encode_s16(i * 2, sample_16)
	
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	return wav

## Som de clique de interface
func _create_click_sfx() -> AudioStreamWAV:
	var sample_rate: int = 44100
	var duration: float = 0.04
	var samples_count: int = int(sample_rate * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples_count * 2)
	
	for i in range(samples_count):
		var t: float = float(i) / sample_rate
		var progress: float = float(i) / samples_count
		var envelope: float = 1.0 - progress
		var val: float = sin(t * 1100.0 * TAU) * 0.4 * envelope
		var sample_16: int = clampi(int(val * 32767.0), -32768, 32767)
		
		data.encode_s16(i * 2, sample_16)
	
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	return wav

## Som de estalo seco de quebra de bloco
func _create_block_break_sfx() -> AudioStreamWAV:
	var sample_rate: int = 44100
	var duration: float = 0.12
	var samples_count: int = int(sample_rate * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples_count * 2)
	
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 99
	
	for i in range(samples_count):
		var t: float = float(i) / sample_rate
		var progress: float = float(i) / samples_count
		var envelope: float = pow(1.0 - progress, 2.5)
		var noise: float = rng.randf_range(-1.0, 1.0)
		var crack: float = sin(t * 320.0 * TAU) * 0.5
		var val: float = (noise * 0.65 + crack) * envelope * 0.5
		var sample_16: int = clampi(int(val * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, sample_16)
	
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	return wav

## Som suave de foco / hover nos botões
func _create_hover_sfx() -> AudioStreamWAV:
	var sample_rate: int = 44100
	var duration: float = 0.04
	var samples_count: int = int(sample_rate * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples_count * 2)
	
	for i in range(samples_count):
		var t: float = float(i) / sample_rate
		var progress: float = float(i) / samples_count
		var envelope: float = sin(progress * PI)
		var freq: float = lerp(1200.0, 1600.0, progress)
		var val: float = sin(t * freq * TAU) * 0.25 * envelope
		var sample_16: int = clampi(int(val * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, sample_16)
		
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	return wav

## Som de abertura de tela/modal
func _create_menu_open_sfx() -> AudioStreamWAV:
	var sample_rate: int = 44100
	var duration: float = 0.16
	var samples_count: int = int(sample_rate * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples_count * 2)
	
	for i in range(samples_count):
		var t: float = float(i) / sample_rate
		var progress: float = float(i) / samples_count
		var envelope: float = (1.0 - progress) * (1.0 - progress)
		var freq: float = lerp(420.0, 920.0, progress)
		var val: float = (sin(t * freq * TAU) + 0.3 * sin(t * freq * 1.5 * TAU)) * 0.35 * envelope
		var sample_16: int = clampi(int(val * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, sample_16)
		
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	return wav

## Som de fechamento / voltar
func _create_menu_back_sfx() -> AudioStreamWAV:
	var sample_rate: int = 44100
	var duration: float = 0.14
	var samples_count: int = int(sample_rate * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples_count * 2)
	
	for i in range(samples_count):
		var t: float = float(i) / sample_rate
		var progress: float = float(i) / samples_count
		var envelope: float = 1.0 - progress
		var freq: float = lerp(850.0, 360.0, progress)
		var val: float = sin(t * freq * TAU) * 0.35 * envelope
		var sample_16: int = clampi(int(val * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, sample_16)
		
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	return wav

## Trilha ambiente sintetizada em loop para o menu
func _create_ambient_music() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 4.0
	var samples_count: int = int(sample_rate * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples_count * 2)
	
	# Acordes Dm (D, F, A) e Bb com subgrave pulsante
	var notes: Array[float] = [146.83, 174.61, 220.0, 73.42] # D3, F3, A3, D2
	for i in range(samples_count):
		var t: float = float(i) / sample_rate
		var val: float = 0.0
		# Osciladores senoidais suaves
		for n_idx in range(notes.size()):
			var f: float = notes[n_idx]
			var lfo: float = 1.0 + 0.15 * sin(t * 1.5 + float(n_idx))
			val += sin(t * f * TAU) * 0.12 * lfo
		# Tremolo suave e loop seamless
		var loop_env: float = sin((float(i) / float(samples_count)) * PI)
		val *= (0.7 + 0.3 * loop_env)
		var sample_16: int = clampi(int(val * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, sample_16)
		
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = samples_count
	return wav


