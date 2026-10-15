extends RefCounted

## Monta a apresentação das estatísticas e medalhas ao final de uma partida.
func populate(
	container: VBoxContainer,
	match_seconds: float,
	bombs_dropped: int,
	blocks_broken: int,
	powerups_collected: int,
	enemies_defeated: int,
	is_campaign: bool,
	golden_choices: int,
	blue_choices: int
) -> void:
	var total_seconds: int = int(match_seconds)
	var time_str: String = "%02d:%02d" % [int(total_seconds / 60), total_seconds % 60]
	container.add_child(HSeparator.new())

	var header := Label.new()
	header.text = tr("STATS_TITLE")
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	container.add_child(header)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var stats: Array[Array] = [
		[tr("STATS_TIME"), time_str],
		[tr("STATS_BOMBS"), str(bombs_dropped)],
		[tr("STATS_BLOCKS"), str(blocks_broken)],
		[tr("STATS_ITEMS"), str(powerups_collected)]
	]
	if is_campaign:
		stats.append([tr("STATS_ENEMIES"), str(enemies_defeated)])
		stats.append([tr("STATS_PORTALS"), "%d / %d" % [golden_choices, blue_choices]])
	for pair in stats:
		var key_label := Label.new()
		key_label.text = pair[0]
		key_label.add_theme_font_size_override("font_size", 12)
		key_label.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95))
		var value_label := Label.new()
		value_label.text = pair[1]
		value_label.add_theme_font_size_override("font_size", 12)
		value_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
		grid.add_child(key_label)
		grid.add_child(value_label)
	container.add_child(grid)

	var badges: Array[Dictionary] = []
	if blocks_broken >= 15:
		badges.append({"title": tr("BADGE_WALL_BREAKER"), "color": Color(1.0, 0.75, 0.3)})
	if bombs_dropped >= 20:
		badges.append({"title": tr("BADGE_BOMB_MASTER"), "color": Color(1.0, 0.45, 0.35)})
	if powerups_collected >= 6:
		badges.append({"title": tr("BADGE_COLLECTOR"), "color": Color(0.4, 0.95, 0.6)})
	if match_seconds < 75.0 and bombs_dropped >= 5:
		badges.append({"title": tr("BADGE_SPEEDSTER"), "color": Color(0.35, 0.85, 1.0)})
	elif match_seconds >= 120.0:
		badges.append({"title": tr("BADGE_SURVIVOR"), "color": Color(0.85, 0.6, 1.0)})
	if is_campaign and enemies_defeated >= 5:
		badges.append({"title": tr("BADGE_EXTERMINATOR"), "color": Color(1.0, 0.5, 0.8)})
	if badges.is_empty():
		return

	container.add_child(HSeparator.new())
	var badge_header := Label.new()
	badge_header.text = tr("BADGE_TITLES")
	badge_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_header.add_theme_font_size_override("font_size", 13)
	badge_header.add_theme_color_override("font_color", Color(0.5, 1.0, 0.7))
	container.add_child(badge_header)
	var badge_box := HFlowContainer.new()
	badge_box.alignment = FlowContainer.ALIGNMENT_CENTER
	badge_box.add_theme_constant_override("h_separation", 10)
	badge_box.add_theme_constant_override("v_separation", 6)
	badge_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for badge in badges:
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.16, 0.24, 0.85)
		style.border_color = badge.color
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		panel.add_theme_stylebox_override("panel", style)
		var badge_label := Label.new()
		badge_label.text = badge.title
		badge_label.add_theme_font_size_override("font_size", 11)
		badge_label.add_theme_color_override("font_color", badge.color)
		panel.add_child(badge_label)
		badge_box.add_child(panel)
	container.add_child(badge_box)
