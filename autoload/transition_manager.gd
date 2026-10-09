extends CanvasLayer

## Gerenciador de Transições Suaves entre Cenas (Autoload / Singleton).
## Executa fade para preto, efeito de escala cinematográfico e fade-in
## ao alternar entre menus e gameplay.

signal transition_started(target_scene: String)
signal scene_changed(target_scene: String)
signal transition_finished()

var overlay: ColorRect
var is_transitioning: bool = false

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	overlay = ColorRect.new()
	overlay.color = Color(0.02, 0.03, 0.06, 0.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

## Realiza a transição suave de tela
func change_scene(target_scene_path: String, duration: float = 0.35) -> void:
	if is_transitioning:
		return
	
	is_transitioning = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	transition_started.emit(target_scene_path)
	
	# Animação de fade-out (escurece)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(overlay, "color:a", 1.0, duration)
	
	await tween.finished
	
	# Troca a cena no SceneTree
	var err: Error = get_tree().change_scene_to_file(target_scene_path)
	if err != OK:
		printerr("[TransitionManager] Erro ao carregar cena: ", target_scene_path)
	
	scene_changed.emit(target_scene_path)
	await get_tree().process_frame
	
	# Animação de fade-in (clareia na nova cena)
	var tween_in: Tween = create_tween()
	tween_in.set_trans(Tween.TRANS_CUBIC)
	tween_in.set_ease(Tween.EASE_IN)
	tween_in.tween_property(overlay, "color:a", 0.0, duration * 0.9)
	
	await tween_in.finished
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_transitioning = false
	transition_finished.emit()

## Fade suave para fechar o jogo
func fade_out_and_quit(duration: float = 0.45) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(overlay, "color:a", 1.0, duration)
	
	await tween.finished
	get_tree().quit()
