extends CanvasLayer

## Global screen-transition overlay: covers the screen with an effect, lets the
## caller swap whatever is underneath, then uncovers. A service rather than a
## game-state slice (the odd one out in autoloads/) because GameRoot, the Hub
## and the pause menu all need it, and it has to draw above PauseMenu's
## layer 50. Runs while the tree is paused so the Esc menu can transition too.
##
## Adding an effect = one .gdshader in shaders/transitions/ (taking a `progress`
## uniform where 0 is fully clear and 1 is fully opaque) + one Effect entry.

enum Effect { FADE, WIPE, DISSOLVE, PIXELATE, SWIRL }

const DUR_MENU := 0.18
const DUR_ROOM := 0.16
const DUR_TRAVEL := 0.4
const DUR_BATTLE := 0.35

const _SHADERS := {
	Effect.FADE: preload("res://shaders/transitions/fade.gdshader"),
	Effect.WIPE: preload("res://shaders/transitions/wipe.gdshader"),
	Effect.DISSOLVE: preload("res://shaders/transitions/dissolve.gdshader"),
	Effect.PIXELATE: preload("res://shaders/transitions/pixelate.gdshader"),
	Effect.SWIRL: preload("res://shaders/transitions/swirl.gdshader"),
}

## True from the moment a cover starts until an uncover reaches fully clear.
## Callers that poll input every frame (dungeon movement) must check this;
## GUI input is blocked automatically.
var is_busy: bool = false

var _rect: ColorRect
var _mat: ShaderMaterial
var _tween: Tween
var _effect: int = -1

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS

	_mat = ShaderMaterial.new()

	_rect = ColorRect.new()
	_rect.name = "Overlay"
	# Anchored, never sized: stretch mode is canvas_items/expand, so the
	# visible area can be wider than the 1920x1080 base viewport.
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.color = Color.WHITE  # the shader writes COLOR outright
	_rect.material = _mat
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_rect.process_mode = Node.PROCESS_MODE_ALWAYS
	_rect.visible = false
	add_child(_rect)

	_apply_effect(Effect.FADE, 0.0, false)

# ------------------------------------------------------------------ public API

## Drive the screen from clear to fully covered. No-ops if already covered, so
## a caller can cover the screen itself and then trigger something that also
## calls play() without paying for the transition twice.
func cover(effect: int = Effect.FADE, duration: float = DUR_MENU) -> void:
	await _run(effect, 1.0, duration)

## Drive the screen from covered back to clear. No-ops if already clear.
func uncover(effect: int = Effect.FADE, duration: float = DUR_MENU) -> void:
	await _run(effect, 0.0, duration)

## cover -> midpoint.call() -> uncover. Pass uncover_effect to come back out
## with a different effect than you went in with.
func play(midpoint: Callable, effect: int = Effect.FADE, duration: float = DUR_MENU, uncover_effect: int = -1) -> void:
	await cover(effect, duration)
	if midpoint.is_valid():
		midpoint.call()
	await uncover(uncover_effect if uncover_effect >= 0 else effect, duration)

## Current coverage, 0.0 (clear) to 1.0 (fully covered).
func get_progress() -> float:
	if _mat == null:
		return 0.0
	return float(_mat.get_shader_parameter("progress"))

# --------------------------------------------------------------------- internal

func _run(effect: int, target: float, duration: float) -> void:
	# A transition arriving mid-flight takes over from wherever the last one
	# got to rather than restarting or double-tweening.
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

	var from := get_progress()
	var uncovering := target < from

	if is_equal_approx(from, target):
		_apply_effect(effect, target, uncovering)
		_set_covered(target > 0.0)
		return

	_apply_effect(effect, from, uncovering)
	_set_covered(true)

	_tween = create_tween()
	# The Esc menu pauses the tree while transitioning, so the tween needs to be
	# exempt from pause on top of the node's PROCESS_MODE_ALWAYS.
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(_mat, "shader_parameter/progress", target, duration * absf(target - from))
	await _tween.finished

	_mat.set_shader_parameter("progress", target)
	_set_covered(target > 0.0)

func _apply_effect(effect: int, progress: float, uncovering: bool) -> void:
	if effect != _effect:
		_effect = effect
		# Assigning a new shader resets every uniform to its declared default,
		# so progress and any per-effect uniforms must be re-applied after.
		_mat.shader = _SHADERS[effect]
	_mat.set_shader_parameter("progress", progress)
	if effect == Effect.WIPE:
		# On the way out the swipe continues off the far side instead of
		# retreating the way it came, so the pair reads as one motion.
		_mat.set_shader_parameter("exit_far_side", uncovering)

func _set_covered(covered: bool) -> void:
	_rect.visible = covered
	is_busy = covered
	# Blocks stray clicks and Enter-on-a-focused-button while the screen is
	# covered; the overlay's mouse_filter alone would not catch keyboard
	# activation of an already-focused button underneath.
	get_viewport().gui_disable_input = covered
