class_name MatchClock
extends RefCounted

## Relógio independente da interface e das regras de vitória.
var seconds_remaining: float = 0.0
var last_reported_second: int = -1

func start(duration_seconds: float) -> void:
	seconds_remaining = maxf(0.0, duration_seconds)
	last_reported_second = -1

## Retorna o novo segundo inteiro, ou -1 quando não há atualização visual.
func advance(delta: float) -> int:
	if seconds_remaining <= 0.0:
		return -1
	seconds_remaining = maxf(0.0, seconds_remaining - delta)
	var current_second: int = int(seconds_remaining)
	if current_second == last_reported_second:
		return -1
	last_reported_second = current_second
	return current_second

func is_expired() -> bool:
	return seconds_remaining <= 0.0
