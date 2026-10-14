class_name SuddenDeath
extends RefCounted

## Gerencia a Morte Súbita no Modo Batalha.
## Quando faltam TRIGGER_SECONDS segundos, paredes começam a cair
## em espiral do canto para o centro, eliminando jogadores encurralados
## e forçando um confronto final.

const TRIGGER_SECONDS: int = 45
const DROP_INTERVAL: float = 0.55  # segundos entre cada parede caída

## Células na ordem de espiral (borda → centro) para o mapa 15×13
## Geradas em _build_spiral_order() no início da rodada.
var spiral_cells: Array[Vector2i] = []
var spiral_index: int = 0
var drop_timer: float = 0.0
var is_active: bool = false
var has_triggered: bool = false

## Referência ao ArenaGrid para spawnar paredes e verificar células
var grid: ArenaGrid

func reset() -> void:
	spiral_index = 0
	drop_timer = 0.0
	is_active = false
	has_triggered = false
	spiral_cells.clear()

## Inicializa e pré-calcula a ordem de espiral ao começar uma rodada.
func start(arena_grid: ArenaGrid) -> void:
	grid = arena_grid
	reset()
	spiral_cells = _build_spiral_order()

## Avança o relógio. Retorna true quando o Morte Súbita é ativado pela primeira vez.
func advance(seconds_left: int, delta: float) -> bool:
	var just_triggered: bool = false
	if not has_triggered and seconds_left <= TRIGGER_SECONDS and seconds_left > 0:
		has_triggered = true
		is_active = true
		just_triggered = true

	if is_active and spiral_index < spiral_cells.size():
		drop_timer -= delta
		if drop_timer <= 0.0:
			drop_timer = DROP_INTERVAL
			_drop_next_wall()

	return just_triggered

## Converte uma célula em parede indestrutível (esmagando bombs, powerups e blocos).
func _drop_next_wall() -> void:
	if grid == null or spiral_index >= spiral_cells.size():
		return

	# Pula células que já são paredes
	while spiral_index < spiral_cells.size():
		var cell: Vector2i = spiral_cells[spiral_index]
		spiral_index += 1
		var cell_type: GameState.CellType = grid.get_cell_type(cell)

		# Destrói blocos e powerups antes de converter
		if cell_type == GameState.CellType.BLOCK_DESTRUCTIBLE:
			grid.destroy_block_at(cell, false)
		elif cell_type == GameState.CellType.WALL_INDESTRUCTIBLE:
			continue  # já é parede, próxima

		# Detona bombs que estiverem na célula
		if grid.has_bomb_at(cell):
			var bomb: Bomb = grid.get_bomb_at(cell)
			if is_instance_valid(bomb):
				bomb.detonate()

		# Remove powerup se houver
		if grid.has_powerup_at(cell):
			var pu: PowerUp = grid.get_powerup_at(cell)
			if pu:
				pu.destroy_by_fire()

		# Instancia a parede com animação de queda
		_spawn_falling_wall(cell)
		break

## Instancia uma WallIndestructible com efeito visual de queda.
func _spawn_falling_wall(cell: Vector2i) -> void:
	if grid == null:
		return
	var wall_scene: PackedScene = preload("res://scenes/wall_indestructible.tscn")
	var wall: WallIndestructible = wall_scene.instantiate() as WallIndestructible
	wall.position = grid.grid_to_world(cell)
	wall.grid_position = cell
	# Tint avermelhado para diferenciar paredes de Morte Súbita
	wall.modulate = Color(1.25, 0.55, 0.45)
	grid.walls_container.add_child(wall)
	grid.grid_state[cell] = GameState.CellType.WALL_INDESTRUCTIBLE

	# Animação: escala de 0 → 1 com bounce
	wall.scale = Vector2(0.1, 0.1)
	var tween: Tween = wall.create_tween()
	tween.tween_property(wall, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Gera a lista de células em espiral: começa pelas colunas/linhas externas
## e avança camada por camada em direção ao centro (ignorando as bordas já fixas do mapa).
func _build_spiral_order() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	# As linhas 0, H-1 e colunas 0, W-1 já são paredes fixas do gerador — começamos da camada 1.
	var left: int = 1
	var right: int = ArenaGrid.WIDTH - 2
	var top: int = 1
	var bottom: int = ArenaGrid.HEIGHT - 2

	while left <= right and top <= bottom:
		# Topo
		for x in range(left, right + 1):
			result.append(Vector2i(x, top))
		# Direita
		for y in range(top + 1, bottom + 1):
			result.append(Vector2i(right, y))
		# Base (direita → esquerda)
		if top < bottom:
			for x in range(right - 1, left - 1, -1):
				result.append(Vector2i(x, bottom))
		# Esquerda (subindo)
		if left < right:
			for y in range(bottom - 1, top, -1):
				result.append(Vector2i(left, y))
		left += 1
		right -= 1
		top += 1
		bottom -= 1

	return result
