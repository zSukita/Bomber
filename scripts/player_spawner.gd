class_name PlayerSpawner
extends RefCounted

## Constrói e configura instâncias de jogador para uma arena.
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

func spawn(container: Node2D, grid: ArenaGrid, peer_id: int, player_name: String, color_index: int, authoritative: bool, bomb_requested: Callable, died: Callable, powerup_changed: Callable) -> Player:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.name = str(peer_id)
	player.peer_id = peer_id
	player.player_name = player_name
	player.player_index = color_index
	container.add_child(player)

	var spawn_position: Vector2 = grid.get_spawn_world_pos(color_index)
	player.global_position = spawn_position
	player.target_sync_position = spawn_position
	player.set_player_color(color_index)
	player.update_name_display(player_name)
	if authoritative:
		player.bomb_drop_requested.connect(bomb_requested)
		player.died.connect(died)
		player.powerup_changed.connect(powerup_changed)
	return player
