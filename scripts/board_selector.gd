class_name BoardSelector
extends Node3D
## Board-bound level selection and level management, merged into one node.
##
## The 36 clickable squares are laid over the board (one per level). Each square
## shows its level name; hovering an unlocked square highlights it; clicking an
## unlocked square starts the level.
##
## This node also owns the level system: it loads the 36 levels from
## res://levels/ and launches each level's referee thread on demand. Level files
## are named "<row><col><name>.gd" (the two leading digits are the square's row
## and column); each derives from Level. Starting a level spins up a Thread
## running that level's `referee()` — an infinite loop that runs until
## stop_level() asks it to stop. While a level runs, its name is shown in the
## UI's "levelname" Label.
##
## WARNING: referee() runs on a worker thread and must not touch the scene tree.
## Talk to the main thread via a Mutex + shared buffer, or call_deferred.

const SIZE := 6
const SQUARE := 0.14
## Lift of the select squares above the board surface so they render on top of
## the board (and any pieces) instead of z-fighting with them.
const Y_OFFSET := 0.001
const LEVEL_DIR := "res://levels"

## Hover highlight tint — the only time a square is tinted (no dark overlay).
const HOVER_COLOR := Color(0.95, 0.62, 0.16, 0.85)
## Fully transparent square tint (invisible until hovered).
const CLEAR_COLOR := Color(0.0, 0.0, 0.0, 0.0)
## Name label color for unlocked squares.
const NAME_COLOR := Color(1.0, 1.0, 1.0, 1.0)

## Level unlock configuration: a SIZE x SIZE grid, `true` = unlocked at start,
## `false` = locked. Rows index the board top to bottom, columns left to right.
## Edit this to set the initial lock state.
const LEVEL_UNLOCKED := [
	[true,  false, false, false, false, false],
	[false, true, false, false, false, false],
	[false, false, true, false, false, false],
	[false, false, false, true, false, false],
	[false, false, false, false, true, false],
	[false, false, false, false, false, true],
]

var _board: ChessBoard = null
## Vector2i(row, col) -> Level, filled by _load_levels() scanning LEVEL_DIR.
var _levels: Dictionary = {}
var _active_thread: Thread = null
var _current: Vector2i = Vector2i(-1, -1)


func _ready() -> void:
	_board = get_parent()
	position.y = Y_OFFSET
	_load_levels()
	_build_squares()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_stop_thread()


# --- Level loading ---------------------------------------------------------

func _load_levels() -> void:
	var dir := DirAccess.open(LEVEL_DIR)
	Level.board = _board
	if dir == null:
		push_error("[BoardSelector] 无法打开关卡目录: %s" % LEVEL_DIR)
		return
	for file in dir.get_files():
		if not file.ends_with(".gd") or file == "level.gd" or file.begins_with("_"):
			continue
		var base := file.get_basename()
		if base.length() < 2 or not base[0].is_valid_int() or not base[1].is_valid_int():
			continue
		var row := base[0].to_int()
		var col := base[1].to_int()
		if row < 0 or row >= SIZE or col < 0 or col >= SIZE:
			continue
		var script := load(LEVEL_DIR + "/" + file) as GDScript
		if script == null:
			continue
		var level := script.new() as Level
		if level == null:
			continue
		level.row = row
		level.col = col
		_levels[Vector2i(row, col)] = level


# --- Level running / threading --------------------------------------------

## Stop the current level and return to the select screen.
func stop_level() -> void:
	_stop_thread()
	_board.clear_all()
	_current = Vector2i(-1, -1)
	_board.get_node("UI/levelname").visible = false
	var ui := _board.get_node_or_null("UI")
	if ui != null:
		ui.set_domino_counts({})
	visible = true
	_board.play_enabled = false


## Re-launch the currently selected level's referee thread.
func replay() -> void:
	if _current.x < 0:
		return
	_stop_thread()
	_board.clear_all()
	_start_level(_current)


## Start the level at (row, col) (called by clicking a square): launch its
## referee thread and show its name in the HUD's "levelname" Label.
func _start_level(cell: Vector2i) -> void:
	GameUI.description_panel.visible=0
	var level: Level = _levels.get(cell)
	if level == null or (_active_thread != null and _active_thread.is_alive()):
		return
	_current = cell
	_active_thread = Thread.new()
	_active_thread.start(Callable(level, "referee"))
	print("[BoardSelector] 启动关卡 (%d, %d) - %s" % [cell.x, cell.y, level.level_name])
	_board.get_node("UI/levelname").text = level.level_name
	_board.get_node("UI/levelname").visible = true
	_board.play_enabled = true
	visible = false


## Ask the current level thread to stop by posting a Move with the EXIT action,
## then join it and release it.
func _stop_thread() -> void:
	if _active_thread != null and _active_thread.is_started():
		_board.request_move(Move.new(Vector2i(-1, -1), Vector2i(-1, -1), Move.Action.EXIT))
		_active_thread.wait_to_finish()
	_active_thread = null


## The description of the currently running level, or "" when none is running
## (select screen or debug free-play).
func current_description() -> String:
	var level: Level = _levels.get(_current)
	return level.description if level != null else ""


## Start debug free-play: run a bare Level whose default referee allows every
## move, so the player can drag pieces anywhere without level rules.
func start_debug_play() -> void:
	_stop_thread()
	_current = Vector2i(-1, -1)
	var level := Level.new()
	level.level_name = "调试模式"
	level.board = _board
	_active_thread = Thread.new()
	_active_thread.start(Callable(level, "referee"))
	_board.get_node("UI/levelname").text = level.level_name
	_board.get_node("UI/levelname").visible = true
	_board.play_enabled = true
	visible = false


# --- Selection squares -----------------------------------------------------

func _build_squares() -> void:
	for r in SIZE:
		for c in SIZE:
			if LEVEL_UNLOCKED[r][c]:
				add_child(_make_square(Vector2i(r, c)))


func _make_square(cell: Vector2i) -> Area3D:
	var area := Area3D.new()
	area.name = "Square_%d%d" % [cell.x, cell.y]
	area.position = _board.get_chess_position(Vector2i(cell.y, cell.x))

	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var box := BoxShape3D.new()
	box.size = Vector3(SQUARE, 0.01, SQUARE)
	shape.shape = box
	area.add_child(shape)

	# Highlight overlay: invisible until hovered (no dark covering layer).
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var quad := QuadMesh.new()
	quad.size = Vector2(SQUARE, SQUARE)
	mesh.mesh = quad
	mesh.rotation_degrees = Vector3(-90, 0, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = CLEAR_COLOR
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = mat
	area.add_child(mesh)

	# Name label: hidden until hovered (only shown while pointing at a square).
	var label := Label3D.new()
	label.name = "Name"
	var level: Level = _levels.get(cell)
	label.text = level.level_name if level != null else ""
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 14
	label.position = Vector3(0, 0.015, 0)
	label.modulate = NAME_COLOR
	label.visible = false
	area.add_child(label)

	area.mouse_entered.connect(_on_square_hover.bind(area, true))
	area.mouse_exited.connect(_on_square_hover.bind(area, false))
	area.input_event.connect(_on_square_input.bind(cell))
	return area


func _on_square_hover(area: Area3D, hovering: bool) -> void:
	var label := area.get_node("Name") as Label3D
	label.visible = hovering
	var mesh := area.get_node("Mesh") as MeshInstance3D
	var mat := mesh.material_override as StandardMaterial3D
	mat.albedo_color = HOVER_COLOR if hovering else CLEAR_COLOR


func _on_square_input(
	camera: Node,
	event: InputEvent,
	event_position: Vector3,
	normal: Vector3,
	shape_idx: int,
	cell: Vector2i
) -> void:
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_start_level(cell)
