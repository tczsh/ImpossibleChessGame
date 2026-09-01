class_name Domino
extends ChessPiece
## A chess piece whose shape is a flat grid of filled / empty cells (a polyomino,
## commonly a domino), described by a string of '*' (filled) and ' ' (empty)
## where rows are separated by '/'. Each '*' becomes one cube sized to a full
## board square; the shape is anchored at its (0, 0) cell, so a domino of N
## filled cells covers N board squares. Every cube rests on the board plane (y=0).
##
## Example shapes ('*' = filled, ' ' or '.' = empty, '/' = new row):
##   "*"        -> a single cube
##   "**"       -> a horizontal 2-cube domino
##   "*/*"      -> a vertical 2-cube domino
##   "**/**"    -> a 2x2 square
##   "***/* */" -> an L-shape (the space marks the empty cell)
##
## The model is generated procedurally (one BoxMesh per filled cell), so no
## imported scene is needed — unlike ChessPiece, which instantiates a glTF model
## selected by PieceType. The base ChessPiece._init() is invoked explicitly (via
## super) so its pick/drag collision shape and input wiring are installed; the
## piece type stays NONE, so a Domino is identified by `is Domino` rather than a
## PieceType.
##
## Orientation: the `shape` string is the *base* (unrotated) shape, and the
## inherited `direction` field is the single source of truth for how it is
## rotated. `covered_offsets()` derives the footprint from `shape` + `direction`,
## so ChessBoard.can_occupy() always judges the domino's current facing. Rotating
## with A / D changes `direction`, resets (rebuilds) the model to the new
## orientation, and spins it smoothly into place.

## World size of one filled cell's X/Z footprint. Set to the board's grid size so
## each filled cell lines up exactly with one board square.
const CELL_SIZE := ChessBoard.GRID_SIZE
## Height of one cell cube above the board plane.
const CELL_HEIGHT := 0.06
## The recessed center's footprint as a fraction of CELL_SIZE.
const RECESS_INSET := 0.72
## The recessed center's height as a fraction of CELL_HEIGHT.
const RECESS_HEIGHT := 0.5
## The recessed center's top as a fraction of CELL_HEIGHT (below the rim top).
const RECESS_TOP := 0.72
## How much to darken the recessed center's color.
const RECESS_DARKEN := 0.35

## How long the rotation spin animation takes, in seconds.
const SPIN_DURATION := 0.15

## The base shape string this domino was built from. Not mutated by rotation —
## orientation lives in `direction` instead.
var shape: String = "*"

## Tween animating the model's spin while the shape rotates, so a fast second
## rotation cancels the first instead of stacking.
var _spin_tween: Tween = null


func _init(
	shape_string: String = "*",
	piece_color: ChessPiece.PieceColor = ChessPiece.PieceColor.WHITE
) -> void:
	# GDScript does not call the parent _init() automatically once we override
	# it, so run the base piece setup explicitly: this sets type (NONE) + color
	# and installs the pick/drag collision shape and input wiring.
	super._init(ChessPiece.PieceType.NONE, piece_color)
	shape = shape_string
	_build_model()
	_refresh_pick_shape()


## Parse a shape string into the list of filled (row, col) offsets relative to
## the anchor cell (0, 0). The result is re-anchored so (0, 0) is always a filled
## cell: the topmost-then-leftmost filled cell becomes (0, 0), dropping any empty
## leading rows/columns. This matters because ChessBoard anchors every piece at its
## (0, 0) cell — a shape with a leading empty cell (e.g. " */***", a T whose stem
## sits over the middle of its bar) would otherwise leave the anchor empty, and
## ChessBoard.covered_cells() would wrongly mark that empty square as occupied.
## A static mirror of the model's layout, so callers can evaluate a shape without
## instantiating a Domino (see ChessUtils.domino_can_place).
static func shape_offsets(shape_string: String) -> Array:
	var offs: Array = []
	var lines := shape_string.split("/")
	var rows := lines.size()
	var cols := 0
	for line in lines:
		cols = maxi(cols, line.length())
	for r in rows:
		var line := lines[r]
		for c in cols:
			if c < line.length() and line[c] == "*":
				offs.append(Vector2i(r, c))
	# Re-anchor so the anchor (0, 0) is guaranteed to be a filled cell.
	if not offs.is_empty():
		var min_row: int = (offs[0] as Vector2i).x
		for off: Vector2i in offs:
			min_row = mini(min_row, off.x)
		var min_col: int = 0x7FFFFFFF
		for off: Vector2i in offs:
			if off.x == min_row:
				min_col = mini(min_col, off.y)
		var shift := Vector2i(min_row, min_col)
		for i in offs.size():
			offs[i] = (offs[i] as Vector2i) - shift
	return offs


## How many 90° clockwise steps a facing is from the base orientation. The base
## shape "**" is written horizontally and already points EAST, so EAST (and NONE)
## take 0 turns, and SOUTH/WEST/NORTH take 1/2/3 clockwise quarter turns. This
## makes each facing extend the domino from its anchor cell in that compass
## direction — the anchor stays put and the far cell lands up/down/left/right of
## it rather than the whole shape being re-anchored to a bounding-box corner.
static func direction_turns(dir: ChessPiece.Direction) -> int:
	match dir:
		ChessPiece.Direction.SOUTH:
			return 1
		ChessPiece.Direction.WEST:
			return 2
		ChessPiece.Direction.NORTH:
			return 3
		_:
			return 0  # NONE, EAST


## Rotate a list of (row, col) offsets 90° clockwise around the anchor cell
## (0, 0), keeping the anchor fixed. Unlike a bounding-box rotation, this does NOT
## re-anchor the result to the top-left, so offsets may go negative — that is what
## lets a facing extend the piece up or left of its anchor. The order of the
## returned offsets is unspecified (footprint and model building don't care).
static func rotate_offsets_cw(offsets: Array) -> Array:
	var out: Array = []
	for off: Vector2i in offsets:
		out.append(Vector2i(off.y, -off.x))
	return out


## The (row, col) offset of every filled cell for a given shape + facing, relative
## to the primary cell (0, 0). Static mirror of covered_offsets_for_direction so
## callers can evaluate a shape without a Domino instance (see ChessUtils).
static func shape_offsets_for_direction(shape_string: String, dir: ChessPiece.Direction) -> Array:
	var offs: Array = shape_offsets(shape_string)
	for _turn in direction_turns(dir):
		offs = rotate_offsets_cw(offs)
	return offs


## The (row, col) offset of every filled cell for a given facing, relative to the
## primary cell (0, 0). The base `shape` is rotated by `dir`'s quarter-turn count.
func covered_offsets_for_direction(dir: ChessPiece.Direction) -> Array:
	return shape_offsets_for_direction(shape, dir)


## The (row, col) offset of every filled cell for the domino's *current*
## direction. ChessBoard.can_occupy() calls this, so the direction is respected
## whenever a placement or move is judged.
func covered_offsets() -> Array:
	return covered_offsets_for_direction(direction)


## Build each filled cell as a two-part tile: a full-size outer cube (the rim)
## plus a smaller, darker, lower "recess" cube on top, so every cell reads as an
## indented tile. Cell (r, c) extends r rows and c columns from the (0, 0) anchor;
## row maps to world X and column to world Z, matching ChessBoard's row->X /
## col->Z layout, so place() drops each cell onto consecutive board squares.
func _build_model() -> void:
	var root := Node3D.new()
	root.name = "DominoModel"
	add_child(root)

	var base: Color = COLORS.get(color, COLORS[ChessPiece.PieceColor.WHITE])
	var outer_mat := _cell_material(base, false)
	var inner_mat := _cell_material(base, true)

	for off: Vector2i in covered_offsets():
		var cell := Node3D.new()
		cell.position = Vector3(off.x * CELL_SIZE, 0, off.y * CELL_SIZE)
		cell.add_child(_make_cube(
			outer_mat,
			Vector3(CELL_SIZE, CELL_HEIGHT, CELL_SIZE),
			Vector3(0, CELL_HEIGHT * 0.5, 0)
		))
		cell.add_child(_make_cube(
			inner_mat,
			Vector3(CELL_SIZE * RECESS_INSET, CELL_HEIGHT * RECESS_HEIGHT, CELL_SIZE * RECESS_INSET),
			Vector3(0, CELL_HEIGHT * (RECESS_TOP - RECESS_HEIGHT * 0.5), 0)
		))
		root.add_child(cell)


## A single BoxMesh cube with `mat`, sized `box_size` and centered at `at`.
func _make_cube(mat: StandardMaterial3D, box_size: Vector3, at: Vector3) -> MeshInstance3D:
	var cube := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	cube.mesh = box
	cube.material_override = mat
	cube.position = at
	return cube


## A flat material tinted from `base`; the recessed center is darkened so it
## reads as an indentation inside the cell's rim.
func _cell_material(base: Color, recess: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base.darkened(RECESS_DARKEN) if recess else base
	mat.metallic = 0.0
	mat.roughness = 0.4
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


## Rebuild the model from the current orientation, freeing any previous model
## node first so this is safe to call repeatedly (e.g. after each rotation).
func _rebuild_model() -> void:
	var old := get_node_or_null("DominoModel")
	if old != null:
		remove_child(old)
		old.queue_free()
	_build_model()
	_refresh_pick_shape()


## Rotate the shape 90° in place: advance/retreat the facing (base), then reset
## the shape — rebuild the model to match the new orientation — and spin it
## smoothly into place.
func rotate_direction(clockwise: bool) -> void:
	super.rotate_direction(clockwise)
	_rebuild_model()
	_animate_rotation(clockwise)


## Set the facing directly (no spin animation), rebuilding the model to match.
## Used when placing a domino already oriented a certain way (e.g. the placing
## level's R-key rotation).
func set_direction(dir: ChessPiece.Direction) -> void:
	if direction == dir:
		return
	direction = dir
	_rebuild_model()


## Spin the rebuilt model from ±90° back to 0 so the rotation reads as a smooth
## turn instead of an instant snap. The model is already built in its final
## orientation; starting it rotated by the opposite delta and tweening to zero
## makes the whole domino appear to swing into place rather than teleport.
func _animate_rotation(clockwise: bool) -> void:
	var model := get_node_or_null("DominoModel") as Node3D
	if model == null:
		return
	if _spin_tween != null and _spin_tween.is_valid():
		_spin_tween.kill()
	# Clockwise (D) starts the final shape pre-rotated -90° and unwinds to 0, so
	# it visibly swings clockwise; counterclockwise (A) does the mirror.
	var delta := -90.0 if clockwise else 90.0
	model.rotation_degrees.y = delta
	_spin_tween = create_tween()
	_spin_tween.set_trans(Tween.TRANS_SINE)
	_spin_tween.set_ease(Tween.EASE_IN_OUT)
	_spin_tween.tween_property(model, "rotation_degrees:y", 0.0, SPIN_DURATION)


## Restore the model after a rotation is canceled. The base class has already put
## `direction` back to its pre-drag facing, so we just rebuild the shape to match.
func _on_rotation_canceled() -> void:
	_rebuild_model()
