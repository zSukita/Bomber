class_name MatchRoundController
extends RefCounted

## Mantém o estado da rodada e o relógio sem depender de cenas ou da interface.
var is_active: bool = false
var round_number: int = 1
var alive_players: Array[int] = []
var clock: MatchClock = MatchClock.new()

func begin(round_index: int, player_ids: Array, duration_seconds: float) -> void:
	round_number = maxi(1, round_index)
	alive_players.clear()
	for peer_id in player_ids:
		alive_players.append(int(peer_id))
	is_active = true
	clock.start(duration_seconds)

func end() -> void:
	is_active = false

func mark_player_out(peer_id: int) -> bool:
	if not alive_players.has(peer_id):
		return false
	alive_players.erase(peer_id)
	return true

func winner_peer_id() -> int:
	return alive_players[0] if alive_players.size() == 1 else 0

func should_end(spawned_player_count: int, online: bool) -> bool:
	if spawned_player_count >= 2 and alive_players.size() <= 1:
		return true
	if online and spawned_player_count <= 1:
		return true
	return spawned_player_count == 1 and alive_players.is_empty()
