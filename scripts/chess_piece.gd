class_name ChessPiece
extends Area3D
## Data record for a single chess piece, plus the *reverse marker* back to the
## square of the board it currently occupies.
##
## The board owns the forward half of the link: each of its cells holds a
## reference to the piece sitting on it (see ChessBoard.Cell). The piece owns
## the reverse half: `board`, `row`, and `col` point back at that cell, so a
## piece always knows where it is without scanning the board. Keep the two
## halves in sync through ChessBoard.place() / remove() / move() — never
## mutate `board`, `row`, or `col` directly.
##
## On creation the piece also instantiates the 3D model matching its type
## (scaled down with MODEL_SCALE to fit a board square) and tints it with its
## color, so game code needs no per-piece scene wiring.

## Kinds of pieces that can occupy a square. NONE is the empty-square value.
enum PieceType { NONE, KING, QUEEN, ROOK, BISHOP, KNIGHT, PAWN }

## Which player owns the piece (or, for dominoes, a decorative tint).
enum PieceColor { WHITE, BLACK, RED, GREEN, BLUE, YELLOW, ORANGE, PURPLE, CYAN, PINK }

## Which way a piece faces / extends from its primary cell. NONE for ordinary
## pieces with no orientation (or before a direction is assigned).
enum Direction { NONE, NORTH, EAST, SOUTH, WEST }

## Clockwise order of the four facings, used to advance/retreat on rotation.
const DIR_CYCLE := [Direction.NORTH, Direction.EAST, Direction.SOUTH, Direction.WEST]

## Scale applied to the imported models so they fit on the board squares.
const MODEL_SCALE := 0.004

## The model scene per piece type (the imported glTF under assets/<type>/).
const MODELS := {
	PieceType.KING: preload("res://assets/king/scene.gltf"),
	PieceType.QUEEN: preload("res://assets/queen/scene.gltf"),
	PieceType.ROOK: preload("res://assets/rook/scene.gltf"),
	PieceType.BISHOP: preload("res://assets/bishop/scene.gltf"),
	PieceType.KNIGHT: preload("res://assets/knight/scene.gltf"),
	PieceType.PAWN: preload("res://assets/pawn/scene.gltf"),
}

## Base tint per color. White keeps the imported ivory tone; black is charcoal.
const COLORS := {
	PieceColor.WHITE: Color(0.855, 0.847, 0.776),
	PieceColor.BLACK: Color(0.15, 0.15, 0.16),
	PieceColor.RED: Color(0.78, 0.24, 0.24),
	PieceColor.GREEN: Color(0.28, 0.62, 0.34),
	PieceColor.BLUE: Color(0.28, 0.44, 0.78),
	PieceColor.YELLOW: Color(0.88, 0.76, 0.28),
	PieceColor.ORANGE: Color(0.88, 0.5, 0.2),
	PieceColor.PURPLE: Color(0.58, 0.34, 0.72),
	PieceColor.CYAN: Color(0.3, 0.68, 0.68),
	PieceColor.PINK: Color(0.86, 0.5, 0.62),
}

## What kind of piece this is.
var type: PieceType = PieceType.NONE
## Which player owns it.
var color: PieceColor = PieceColor.WHITE
## Which way this piece faces, or the direction its footprint extends from its
## primary cell. NONE for ordinary pieces and until a direction is assigned.
var direction: Direction = Direction.NONE

## --- Reverse marker -----------------------------------------------------
## `board` is a static reference to the single board scene's root node; the
## board assigns it to itself in ChessBoard._ready(). `row` and `col` are this
## piece's square on that board, or -1 while the piece is off the board.
static var board: ChessBoard = null
var row: int = -1
var col: int = -1

## True while this piece is being dragged by the player (see the drag handling
## below). Purely a state flag for the drag effect.
var isdragged: bool = false
## True when the player may pick this piece up and drag it. Set false on pieces
## the level controls itself (e.g. an AI opponent's piece) so a click on them is
## ignored. Distinct from `isdragged`, which only records that a drag is in
## progress.
var draggable: bool = true
## Saved facing at drag start, so a rotation preview can be undone when the drag
## is dropped back on its own square or rejected.
var _drag_dir: Direction = Direction.NONE
## Screen-space (2D) offset from the cursor to the piece's projected origin,
## captured at drag start. On each motion we subtract it from the cursor position
## *before* projecting back onto the board, so the grabbed spot stays glued under
## the cursor even under the camera's perspective projection.
var _grab_offset: Vector2 = Vector2.ZERO


func _init(
	piece_type: PieceType = PieceType.NONE,
	piece_color: PieceColor = PieceColor.WHITE
) -> void:
	type = piece_type
	color = piece_color
	_setup_model()
	_setup_picking()

## Instantiate and attach this piece's model, scaled to fit, and tint it.
func _setup_model() -> void:
	var model_scene: PackedScene = MODELS.get(type)
	if model_scene == null:
		return
	var model := model_scene.instantiate() as Node3D
	if model == null:
		return
	model.scale = Vector3(MODEL_SCALE, MODEL_SCALE, MODEL_SCALE)
	add_child(model)
	_apply_color(model, COLORS.get(color, COLORS[PieceColor.WHITE]))


## Recursively tint every MeshInstance3D under `node` with `tint`.
func _apply_color(node: Node, tint: Color) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = tint
			mat.metallic = 0.0
			mat.roughness = 0.4
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			child.material_override = mat
		_apply_color(child, tint)


## Re-tint this piece (and its whole model subtree) with `new_color`, in place.
## Used by the queen-coloring level to repaint an already-placed piece without
## moving or recreating it. Runs on the main thread.
func recolor(new_color: PieceColor) -> void:
	color = new_color
	_apply_color(self, COLORS.get(color, COLORS[PieceColor.WHITE]))


var _move_tween: Tween = null


## Smoothly slide this piece to the `target` world position over `duration`
## seconds, killing any in-flight movement first.
func move_to(target: Vector3, duration: float = 0.25) -> void:
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.set_trans(Tween.TRANS_SINE)
	_move_tween.set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_property(self, "position", target, duration)


## True when this piece is currently placed on a board.
func is_placed() -> bool:
	return board != null and row >= 0 and col >= 0


## The piece's coordinates as a (row, col) vector, or (-1, -1) when unplaced.
func pos() -> Vector2i:
	if is_placed():
		return Vector2i(row, col)
	return Vector2i(-1, -1)


## The (row, col) offsets this piece occupies relative to its primary cell
## (its `row` / `col`) for its *current* direction. An ordinary piece is a single
## square: [(0, 0)]. A Domino overrides this to return every filled cell of its
## shape, rotated by its `direction` — so ChessBoard.can_occupy() respects the
## facing when judging a placement or move.
func covered_offsets() -> Array:
	return covered_offsets_for_direction(direction)


## The (row, col) offsets this piece would occupy for a specific facing. Base
## pieces are single squares with no orientation, so any facing yields the same
## single offset. A Domino overrides this to rotate its shape by `dir`.
func covered_offsets_for_direction(_dir: Direction) -> Array:
	return [Vector2i(0, 0)]


## Advance (`clockwise` true) or retreat the facing one 90° step. NONE steps into
## EAST / WEST respectively. The base implementation only updates `direction`; a
## Domino overrides this to also rotate its footprint and rebuild its model.
func rotate_direction(clockwise: bool) -> void:
	var idx := DIR_CYCLE.find(direction)
	if idx == -1:
		direction = Direction.EAST if clockwise else Direction.WEST
	else:
		var step := 1 if clockwise else -1
		direction = DIR_CYCLE[(idx + step + DIR_CYCLE.size()) % DIR_CYCLE.size()]


## Undo any rotation applied during the drag, restoring the pre-drag facing (and
## shape). Called when a drag is dropped back on its own square or rejected.
func cancel_rotation() -> void:
	if direction == _drag_dir:
		return
	direction = _drag_dir
	_on_rotation_canceled()


## Hook for subclasses to snapshot their own drag state (e.g. a Domino's grid).
func _on_drag_start() -> void:
	pass


## Hook for subclasses to rebuild their shape after a rotation is canceled.
func _on_rotation_canceled() -> void:
	pass


# --- Dragging (ray-picked via Area3D) -------------------------------------

## Arm input ray-picking and build a collision shape that follows the piece's
## visual model, so the piece is grabbed by clicking its actual model rather than
## a fixed cell-sized box. Called once from _init().
func _setup_picking() -> void:
	input_ray_pickable = true
	input_event.connect(_on_input_event)
	_refresh_pick_shape()


## (Re)build the pick collision shape from the piece's current model bounding
## box. Called once from _setup_picking() and again whenever the model changes
## (a Domino rebuilds its model on rotation).
func _refresh_pick_shape() -> void:
	var aabb := _model_local_aabb()
	var size := aabb.size
	var center := aabb.get_center()
	if size == Vector3.ZERO:
		size = Vector3(0.11, 0.18, 0.11)
		center = Vector3(0, 0.09, 0)
	# Guarantee a minimum extent so thin or flat models stay easy to grab.
	size.x = maxf(size.x, 0.06)
	size.y = maxf(size.y, 0.08)
	size.z = maxf(size.z, 0.06)
	var pick := get_node_or_null("PickShape") as CollisionShape3D
	if pick == null:
		pick = CollisionShape3D.new()
		pick.name = "PickShape"
		add_child(pick)
	var box := BoxShape3D.new()
	box.size = size
	pick.shape = box
	pick.position = center


## Axis-aligned bounding box, in this piece's local space, enclosing every
## MeshInstance3D in the model subtree. Starts at the children so the piece's own
## transform (its board position) is not included.
func _model_local_aabb() -> AABB:
	var result := AABB()
	for child in get_children():
		result = result.merge(_collect_local_aabb(child, Transform3D.IDENTITY))
	return result


## Recurse `node`, returning its subtree's meshes' AABB transformed into the
## piece's local space.
func _collect_local_aabb(node: Node, parent_xform: Transform3D) -> AABB:
	var xform := parent_xform
	var n3d := node as Node3D
	if n3d != null:
		xform = parent_xform * n3d.transform
	var result := AABB()
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh != null and mesh.get_aabb().size != Vector3.ZERO:
			result = result.merge(_transform_aabb(mesh.get_aabb(), xform))
	for child in node.get_children():
		result = result.merge(_collect_local_aabb(child, xform))
	return result


## Enclose the 8 corners of `aabb` after `xform` (correct under any transform).
func _transform_aabb(aabb: AABB, xform: Transform3D) -> AABB:
	var out := AABB()
	for p in [
		aabb.position,
		Vector3(aabb.end.x, aabb.position.y, aabb.position.z),
		Vector3(aabb.position.x, aabb.end.y, aabb.position.z),
		Vector3(aabb.position.x, aabb.position.y, aabb.end.z),
		Vector3(aabb.end.x, aabb.end.y, aabb.position.z),
		Vector3(aabb.end.x, aabb.position.y, aabb.end.z),
		Vector3(aabb.position.x, aabb.end.y, aabb.end.z),
		aabb.end,
	]:
		out = out.expand(xform * p)
	return out


## Godot's input ray picks this Area3D and reports events here. A left press
## while a level is running picks the piece up and starts a drag.
func _on_input_event(
	_camera: Node,
	event: InputEvent,
	_event_position: Vector3,
	_normal: Vector3,
	_shape_idx: int
) -> void:
	if isdragged:
		return
	if not draggable:
		return
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and board != null \
			and board.play_enabled:
		_start_drag((event as InputEventMouseButton).position)


## Pick the piece up: flag it dragged and cancel any in-flight slide tween.
## `mouse_pos` is the cursor's viewport position at the moment of the click.
func _start_drag(mouse_pos: Vector2) -> void:
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	isdragged = true
	_drag_dir = direction
	_on_drag_start()
	# Capture the cursor's screen-space offset from the piece's projected origin,
	# so the grabbed spot follows the cursor instead of the piece snapping its
	# center under the mouse.
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		_grab_offset = mouse_pos - camera.unproject_position(global_position)
	else:
		_grab_offset = Vector2.ZERO


## While dragging, follow the mouse and end the drag on left release. Uses
## _input (not _unhandled_input) so a release still lands even over the UI.
## A / D rotate the piece 90° (counterclockwise / clockwise) while it is dragged.
func _input(event: InputEvent) -> void:
	if not isdragged:
		return
	if event is InputEventMouseMotion:
		global_position = board.drag_position(event.position - _grab_offset)
	elif event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		_end_drag(event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_A:
			rotate_direction(false)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_D:
			rotate_direction(true)
			get_viewport().set_input_as_handled()


## Drop the piece: request a move to the cell under the cursor, or snap it back
## when the release is off-board. Releasing on the piece's own square commits an
## in-place rotation (if the player rotated it during the drag) instead of undoing
## it, so a domino can be turned 90° without leaving its square.
func _end_drag(screen_pos: Vector2) -> void:
	isdragged = false
	var from := pos()
	var drop_plane := board.project_to_board(screen_pos - _grab_offset)
	var to := board.world_to_cell(drop_plane)
	if not board.in_bounds(to):
		cancel_rotation()
		move_to(board.get_chess_position(from))
		return
	if to == from:
		# Dropped back on its own square: if the piece was rotated during the
		# drag, keep the new facing by committing it as a same-square move;
		# otherwise just snap it back home.
		if direction != _drag_dir:
			board.request_move(Move.new(from, to, Move.Action.MOVE, direction))
		else:
			move_to(board.get_chess_position(from))
		return
	global_position = drop_plane
	board.request_move(Move.new(from, to, Move.Action.MOVE, direction))
