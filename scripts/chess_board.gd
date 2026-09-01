class_name ChessBoard
extends Node3D
## A 6x6 chess board whose grid records, per square, both the piece type and a
## reference to the piece occupying it.
##
## Meant to be attached to the board scene's root node (chess_board.tscn), so
## the board's game state lives on the scene node itself.
##
## `_cells` is a SIZE x SIZE grid of Cell objects, indexed `_cells[row][col]`.
## Each Cell stores the piece type *and* the piece reference side by side, so a
## caller can read either without chasing the piece object. Each piece carries
## the reverse marker back to its cell (see ChessPiece); place(), remove(), and
## move() keep the two directions of that link in sync.

const SIZE := 6
const GRID_SIZE:=0.14
## Height a dragged piece floats above the board surface while following the mouse.
const DRAG_HEIGHT := 0.05
## Half-extent of the 6x6 board, used to clamp a dragged piece to the board.
const BOARD_HALF := SIZE * GRID_SIZE / 2.0
## Height of an inverted-triangle cell marker above the board plane.
const MARKER_HEIGHT := 0.4
## Half-extent of an inverted-triangle cell marker's triangle.
const MARKER_HALF := 0.05
## One square of the board. Records the piece type together with a reference to
## the piece itself. When empty, `piece` is null and `type` is PieceType.NONE.
class Cell extends RefCounted:
	var type: ChessPiece.PieceType = ChessPiece.PieceType.NONE
	var piece: ChessPiece = null
	## Which direction the occupying piece faces (mirrored from the piece).
	var direction: ChessPiece.Direction = ChessPiece.Direction.NONE
	## True when this is the primary/anchor cell the piece was placed on; false
	## for cells merely covered by a multi-cell piece's footprint (a domino).
	var is_primary: bool = false

	func is_empty() -> bool:
		return piece == null

	## True when this cell is covered by a piece but is not its primary cell
	## (e.g. a square under a domino's footprint but not its anchor).
	func is_covered() -> bool:
		return piece != null and not is_primary

	## Clear the reference without freeing the piece (used when the piece moves
	## to another square).
	func release() -> void:
		type = ChessPiece.PieceType.NONE
		piece = null
		direction = ChessPiece.Direction.NONE
		is_primary = false

	func clear() -> void:
		type = ChessPiece.PieceType.NONE
		if piece != null:
			piece.queue_free()
		piece = null
		direction = ChessPiece.Direction.NONE
		is_primary = false


## The move currently awaiting judgment, shared between the main thread (a drag
## release writes it via request_move()) and the level's referee thread (polls it
## via take_move()). `_pending_move == null` means no move is pending; guarded by
## `move_mutex`.
var _pending_move: Move = null
var move_mutex := Mutex.new()


## Record a move request (main thread): overwrite the pending move under
## `move_mutex`. The referee thread picks it up by polling take_move().
func request_move(m: Move) -> void:
	move_mutex.lock()
	_pending_move = m
	move_mutex.unlock()


## Fetch and clear the pending move (referee thread). Returns a Move, or null
## when no move is pending.
func take_move() -> Move:
	move_mutex.lock()
	var m := _pending_move
	_pending_move = null
	move_mutex.unlock()
	return m


## The SIZE x SIZE grid of cells, indexed `_cells[row][col]`.
var _cells: Array = []

## Board-bound level selection: loads the 36 levels, launches referee threads,
## and lays the clickable select squares over the board.
var board_selector: BoardSelector = null

## True while a level (or debug free-play) is running — enables piece dragging.
## Set by BoardSelector when a level starts/stops.
var play_enabled := false



func _init() -> void:
	for r in SIZE:
		var row_cells: Array = []
		for c in SIZE:
			row_cells.append(Cell.new())
		_cells.append(row_cells)


func _ready() -> void:
	# Register this board as the single, shared board the pieces point back to.
	ChessPiece.board = self
	# Set up level selection: load levels + lay the select squares on the board.
	board_selector = BoardSelector.new()
	add_child(board_selector)


## True when `cell` (row, col) lies inside the 6x6 grid.
func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < SIZE and cell.y >= 0 and cell.y < SIZE


## True when the square is empty (or out of bounds).
func is_empty(cell: Vector2i) -> bool:
	return not in_bounds(cell) or _cell(cell).is_empty()


## The piece type recorded on the square, or PieceType.NONE when empty / out of
## bounds.
func get_type(cell: Vector2i) -> ChessPiece.PieceType:
	if not in_bounds(cell):
		return ChessPiece.PieceType.NONE
	return _cell(cell).type


## The piece occupying the square, or null when empty / out of bounds.
func get_piece(cell: Vector2i) -> ChessPiece:
	if not in_bounds(cell):
		return null
	return _cell(cell).piece

## The world-space origin of square `cell` (row, col), on the board plane (y=0).
func get_chess_position(cell: Vector2i) -> Vector3:
	return Vector3(GRID_SIZE*(cell.x-2.5),0,GRID_SIZE*(cell.y-2.5))


## The absolute (row, col) squares `piece` occupies when anchored at `cell`.
## Index 0 is always the primary cell; the rest are the cells its footprint
## covers. Uses ChessPiece.covered_offsets(), which a Domino overrides to rotate
## its shape by its `direction` — so pass `direction` to judge a specific facing,
## or leave it null to use the piece's current facing.
func covered_cells(
	piece: ChessPiece, cell: Vector2i,
	direction: ChessPiece.Direction = ChessPiece.Direction.NONE
) -> Array:
	var offs: Array
	if direction == ChessPiece.Direction.NONE:
		offs = piece.covered_offsets()
	else:
		offs = piece.covered_offsets_for_direction(direction)
	var cells: Array = [cell]
	for off: Vector2i in offs:
		var v := cell + off
		if v != cell:
			cells.append(v)
	return cells


## Whether `piece`'s footprint, anchored at `cell`, can occupy the board:
## every covered cell is in-bounds and either empty or already part of this same
## piece's own footprint. The "own footprint" exception lets a multi-cell piece
## shift by one square (its new shape may overlap its old cells, which move()
## frees first). This is the single overlap / feasibility check shared by place(),
## move(), and the level referee.
##
## A Domino's footprint is oriented by its `direction` (its covered_offsets()
## applies that rotation), so the direction is respected here. Pass `direction`
## to judge a specific facing instead of the piece's current one.
func can_occupy(
	piece: ChessPiece, cell: Vector2i,
	direction: ChessPiece.Direction = ChessPiece.Direction.NONE
) -> bool:
	if piece == null:
		return _cell(cell).is_empty()
	for v: Vector2i in covered_cells(piece, cell, direction):
		if not in_bounds(v):
			return false
		var target := _cell(v)
		if not target.is_empty() and target.piece != piece:
			return false
	return true


## Write `piece` into every square of its footprint anchored at `cell`: the
## anchor is primary, the rest are covered. Does not touch the piece's reverse
## marker or position (callers do that).
func _mark_piece(piece: ChessPiece, cell: Vector2i) -> void:
	var cells := covered_cells(piece, cell)
	for i in cells.size():
		var v: Vector2i = cells[i]
		var c := _cell(v)
		c.type = piece.type
		c.piece = piece
		c.direction = piece.direction
		c.is_primary = i == 0


## Release every square currently occupied by `piece` (any cell whose `piece`
## matches), without freeing it. Used before a piece moves so its old footprint
## is cleared regardless of its (possibly rotated) shape.
func release_piece(piece: ChessPiece) -> void:
	for r in SIZE:
		for c in SIZE:
			var cell := _cell(Vector2i(r, c))
			if cell.piece == piece:
				cell.release()
## Place `piece` on an empty square: record its type and reference in the cell,
## then set the piece's reverse marker to point back here. Returns false if the
## square is out of bounds or already occupied.
func place(piece: ChessPiece, cell: Vector2i) -> bool:
	if piece == null or not in_bounds(cell):
		return false
	# A newly-placed piece has no own cells yet, so any occupied cell blocks it.
	if not can_occupy(piece, cell):
		return false
	_mark_piece(piece, cell)
	ChessPiece.board = self
	piece.row = cell.x
	piece.col = cell.y
	piece.position = get_chess_position(cell)
	dump_occupancy()
	return true


## Remove whatever occupies the square and clear its reverse marker. Returns
## false when the square is out of bounds or already empty.
func remove(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return false
	var c := _cell(cell)
	if c.is_empty():
		return false
	var piece := c.piece
	release_piece(piece)
	piece.row = -1
	piece.col = -1
	piece.queue_free()
	dump_occupancy()
	return true


## Move a piece per `m` (source -> destination). Returns false if the source is
## empty or the destination is out of bounds / occupied. The piece's reverse
## marker is repointed to the destination.
func move(m: Move) -> bool:
	if not in_bounds(m.from) or not in_bounds(m.to):
		return false
	var src := _cell(m.from)
	if src.is_empty():
		return false
	var piece := src.piece
	# Adopt the requested facing (a player-rotated piece already carries it).
	if m.direction != ChessPiece.Direction.NONE:
		piece.direction = m.direction
	# The destination footprint must be free of other pieces and in-bounds; the
	# piece's own old cells are ignored since release_piece() frees them first.
	if not can_occupy(piece, m.to):
		return false
	# Release the old footprint, then mark the new one.
	release_piece(piece)
	_mark_piece(piece, m.to)
	piece.row = m.to.x
	piece.col = m.to.y
	piece.move_to(get_chess_position(m.to))
	dump_occupancy()
	return true


## Move the piece at `m.from` onto `m.to`, removing whatever piece occupies the
## target first (a capture). Unlike move(), the target square may be occupied.
## Returns false if the move is a no-op, either square is out of bounds, or the
## source is empty.
func capture(m: Move) -> bool:
	if m.from == m.to:
		return false
	if not in_bounds(m.from) or not in_bounds(m.to):
		return false
	if _cell(m.from).is_empty():
		return false
	# Free the victim (if any) so the capturer can take its square.
	if not _cell(m.to).is_empty():
		remove(m.to)
	return move(m)


## Swap the pieces on `a` and `b` (both must be occupied), sliding each into the
## other's square with the standard move animation. Unlike move(), the destination
## is occupied; both pieces are preserved. Used by the 36-officers level to
## rearrange pieces on a full board. Returns false on a no-op or empty cell.
func swap_pieces(a: Vector2i, b: Vector2i) -> bool:
	if a == b or not in_bounds(a) or not in_bounds(b):
		return false
	var pa := _cell(a).piece
	var pb := _cell(b).piece
	if pa == null or pb == null:
		return false
	# Release both footprints, then re-mark each piece on the other's square.
	release_piece(pa)
	release_piece(pb)
	_mark_piece(pa, b)
	_mark_piece(pb, a)
	pa.row = b.x
	pa.col = b.y
	pb.row = a.x
	pb.col = a.y
	# Slide each into place (animated on the main thread).
	pa.move_to(get_chess_position(b))
	pb.move_to(get_chess_position(a))
	dump_occupancy()
	return true


## Empty the whole board and free every piece. Each multi-cell piece is freed
## exactly once, even though its footprint spans several squares.
func clear_all() -> void:
	clear_mesh()
	clear_markers()
	GameUI.description_panel.visible=0
	var pieces: Array = []
	for r in SIZE:
		for c in SIZE:
			var cell := _cell(Vector2i(r, c))
			if cell.piece != null and not pieces.has(cell.piece):
				pieces.append(cell.piece)
	for r in SIZE:
		for c in SIZE:
			_cell(Vector2i(r, c)).release()
	for p in pieces:
		p.queue_free()


## Create a piece node of the given type/color, add it as a child of the board,
## and place it on the square. Returns the new piece, or null if the square is
## out of bounds or already occupied.
func add_piece(
	type: ChessPiece.PieceType,
	color: ChessPiece.PieceColor,
	cell: Vector2i
) -> ChessPiece:
	if not in_bounds(cell) or not is_empty(cell):
		return null
	var piece := ChessPiece.new(type, color)
	call_deferred("add_child",piece)
	place(piece, cell)
	return piece


## Create a Domino from `shape`, add it as a child of the board, and place it at
## `cell`, facing `direction` (NONE = base orientation). The domino is left
## draggable so the player can pick it up and move it. Returns the new Domino, or
## null if the footprint is out of bounds or already occupied. Runs on the main
## thread (call via call_main_thread from a level referee).
func place_domino(
	shape: String,
	color: ChessPiece.PieceColor = ChessPiece.PieceColor.WHITE,
	cell: Vector2i = Vector2i(-1, -1),
	direction: ChessPiece.Direction = ChessPiece.Direction.NONE
) -> Domino:
	if not in_bounds(cell):
		return null
	var domino := Domino.new(shape, color)
	add_child(domino)
	if direction != ChessPiece.Direction.NONE:
		domino.set_direction(direction)
	if not place(domino, cell):
		domino.queue_free()
		return null
	return domino


## Place a non-draggable black pawn at `cell` as a blocker — a "removed" square
## no piece may occupy. Returns true on success. Runs on the main thread.
func place_blocker(cell: Vector2i) -> bool:
	var piece := add_piece(ChessPiece.PieceType.PAWN, ChessPiece.PieceColor.BLACK, cell)
	if piece == null:
		return false
	piece.draggable = false
	return true


## Fill every square with a queen tinted `color`, all non-draggable. Used by the
## queen-coloring level to start from a full board of unpainted queens. Runs on
## the main thread (call via call_main_thread from a level referee).
func fill_queens(color: ChessPiece.PieceColor = ChessPiece.PieceColor.WHITE) -> void:
	for r in SIZE:
		for c in SIZE:
			var q := add_piece(ChessPiece.PieceType.QUEEN, color, Vector2i(r, c))
			if q != null:
				q.draggable = false


## Recolor the piece occupying `cell` to `color`, returning true on success.
## Runs on the main thread (call via call_main_thread from a level referee).
func recolor(cell: Vector2i, color: ChessPiece.PieceColor) -> bool:
	var piece := get_piece(cell)
	if piece == null:
		return false
	piece.recolor(color)
	return true


## Create a semi-transparent rectangle spanning world points `a` and `b` (two
## opposite corners of an axis-aligned plane — constant X, Y, or Z) as a "cut line"
## visual for the cutting level. The quad is unlit and double-sided so it reads as
## a flat overlay from either side. Runs on the main thread (call via call_main_thread).
var cutls:Array[MeshInstance3D]=[]
func show_cut_plane(a: Vector3, b: Vector3, color: Color = Color(1, 0.3, 0.3, 0.35)) -> void:
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	mesh.mesh = quad
	var dx := absf(a.x - b.x)
	var dy := absf(a.y - b.y)
	var dz := absf(a.z - b.z)
	if dy <= dx and dy <= dz:
		# Constant Y: rotate -90° about X so the quad lies in the X-Z plane,
		# facing +Y (a horizontal cut plane).
		quad.size = Vector2(dx, dz)
		mesh.rotation_degrees = Vector3(-90, 0, 0)
	elif dx > dz:
		# Constant Z: the quad already lies in the X-Y plane, facing +Z.
		quad.size = Vector2(dx, dy)
	else:
		# Constant X: rotate -90° about Y so the quad lies in the Y-Z plane.
		quad.size = Vector2(dz, dy)
		mesh.rotation_degrees = Vector3(0, -90, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = mat
	mesh.position = (a + b) / 2.0
	cutls.append(mesh)
	add_child(mesh)
func clear_mesh():
	for i in cutls:
		i.queue_free()
	cutls.clear()


## Inverted-triangle markers floating above cells, keyed by cell for per-cell
## removal (see add_marker / remove_marker / clear_markers).
var _markers: Dictionary = {}


## Add an inverted-triangle marker floating above `cell`. Returns false when the
## cell is out of bounds or already marked. Runs on the main thread (call via
## call_main_thread from a level referee).
func add_marker(cell: Vector2i, color: Color = Color(1.0, 0.25, 0.25, 1.0)) -> bool:
	if not in_bounds(cell) or _markers.has(cell):
		return false
	var marker := _make_marker(color)
	marker.position = get_chess_position(cell) + Vector3(0.0, MARKER_HEIGHT, 0.0)
	add_child(marker)
	_markers[cell] = marker
	return true


## Remove the marker above `cell` (if any). Returns false when none was present.
func remove_marker(cell: Vector2i) -> bool:
	var marker: MeshInstance3D = _markers.get(cell)
	if marker == null:
		return false
	_markers.erase(cell)
	marker.queue_free()
	return true


## Remove all cell markers at once.
func clear_markers() -> void:
	for marker: MeshInstance3D in _markers.values():
		marker.queue_free()
	_markers.clear()


## Build one inverted-triangle marker mesh: a flat triangle lying in the local
## X-Y plane whose apex points toward -Y (down on screen), tinted `color`, unlit
## and double-sided. The material is a billboard, so the triangle always turns to
## face the camera while its up axis stays aligned with the world, keeping the tip
## pointing downward from every camera angle.
func _make_marker(color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var triangle := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(0.0, -MARKER_HALF, 0.0),
		Vector3(-MARKER_HALF, MARKER_HALF, 0.0),
		Vector3(MARKER_HALF, MARKER_HALF, 0.0),
	])
	triangle.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.mesh = triangle
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material_override = mat
	return mesh
# --- Piece dragging (input handled by ChessPiece via ray-picking) ----------

## Project the cursor at `screen_pos` down onto the board plane (y = 0). The
## dragged ChessPiece calls this to follow the mouse and compute its drop cell.
func project_to_board(screen_pos: Vector2) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.ZERO
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return Vector3.ZERO
	return from + dir * (-from.y / dir.y)


## Convert a world position on the board plane back to a (row, col) cell.
func world_to_cell(pos: Vector3) -> Vector2i:
	return Vector2i(roundi(pos.x / GRID_SIZE + 2.5), roundi(pos.z / GRID_SIZE + 2.5))


## The board cell under the cursor, resolved by ray-picking pieces first and
## falling back to the board plane. Pieces rise above the board, so under a
## perspective camera the board-plane projection of the cursor lands behind a
## tall piece's actual square — a key-press action (place / remove / recolor) over
## a piece would target the wrong cell. Preferring the hit piece's own square keeps
## the hovered piece's cell correct; when the cursor is over an empty square there
## is no piece hit, so we fall back to the board plane as before.
func mouse_cell() -> Vector2i:
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d()
	if camera == null:
		return Vector2i(-1, -1)
	var mouse_pos := viewport.get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var dir := camera.project_ray_normal(mouse_pos)
	# Ray-pick pieces (Area3D) first: if the cursor is over a placed piece, use
	# that piece's own square.
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 1000.0)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var piece := hit.get("collider") as ChessPiece
		if piece != null and piece.is_placed():
			return piece.pos()
	# No piece under the cursor: fall back to the board plane.
	return world_to_cell(project_to_board(mouse_pos))


## Forward key presses to the running level as a Move with Action.KEY. A level's
## referee can read `m.key` (the pressed key) and `m.mouse_cell` (the square under
## the cursor) to react to keyboard input. Only fires while play_enabled and when
## the event is unhandled, so typing in the debug command box is not forwarded.
func _unhandled_input(event: InputEvent) -> void:
	if not play_enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var cell := mouse_cell()
		request_move(Move.new(
			Vector2i(-1, -1),
			Vector2i(-1, -1),
			Move.Action.KEY,
			ChessPiece.Direction.NONE,
			(event as InputEventKey).keycode,
			cell
		))


## The lifted position a dragged piece should sit at under `screen_pos`, clamped
## to the board and raised to DRAG_HEIGHT.
func drag_position(screen_pos: Vector2) -> Vector3:
	var p := project_to_board(screen_pos)
	p.x = clampf(p.x, -BOARD_HALF, BOARD_HALF)
	p.z = clampf(p.z, -BOARD_HALF, BOARD_HALF)
	p.y = DRAG_HEIGHT
	return p


## Run `method` (a ChessBoard method) on the main thread and block the calling
## thread until it returns. `call_deferred()` only queues the call for the next
## idle frame, so a worker thread (the level referee) would otherwise keep going
## before the board actually changed. Use this from the referee instead of
## call_deferred(). Safe to call from the main thread too (runs inline).
var _main_call_sem := Semaphore.new()


func call_main_thread(method: StringName, args: Array = []) -> void:
	if Thread.is_main_thread():
		callv(method, args)
		return
	call_deferred("_call_main_then_post", method, args)
	_main_call_sem.wait()


func _call_main_then_post(method: StringName, args: Array) -> void:
	callv(method, args)
	_main_call_sem.post()


## Commit a referee-approved move. Called from the level's referee thread via
## call_main_thread(), so it always runs on the main thread.
func apply_move(m: Move) -> void:
	if not move(m):
		reject_move(m)

## Undo a rejected move by rolling back any rotation and sliding the piece back
## to its origin square.
func reject_move(m: Move) -> void:
	var piece := get_piece(m.from)
	if piece != null:
		piece.cancel_rotation()
		piece.move_to(get_chess_position(m.from))


## Update the domino remaining-count list in the HUD. Called from the level
## referee thread via call_main_thread(); routes the dictionary to the UI.
func set_domino_counts(counts: Dictionary) -> void:
	var ui := get_node_or_null("UI")
	if ui != null:
		ui.set_domino_counts(counts)


## The single-character label for a cell's occupant: '.' when empty, else the
## piece type's initial ('D' for a Domino, 'P' for a pawn blocker, and so on).
static func _piece_char(cell: Cell) -> String:
	if cell.is_empty():
		return "."
	if cell.piece is Domino:
		return "D"
	match cell.type:
		ChessPiece.PieceType.KING:
			return "K"
		ChessPiece.PieceType.QUEEN:
			return "Q"
		ChessPiece.PieceType.ROOK:
			return "R"
		ChessPiece.PieceType.BISHOP:
			return "B"
		ChessPiece.PieceType.KNIGHT:
			return "N"
		ChessPiece.PieceType.PAWN:
			return "P"
		_:
			return "?"


## Print the board's occupancy grid to the console, one token per cell: '.' for
## empty, else the piece type's initial ('D' domino, 'P' pawn, …) with a '*' on
## its primary (anchor) cell and a blank on a merely-covered cell. Rows print
## bottom-to-top so the console reads the same way the board is seen on screen.
## Called after each placement / move / removal for debugging.
func dump_occupancy() -> void:
	for r in range(SIZE - 1, -1, -1):
		var row := "  "
		for c in SIZE:
			var cell := _cell(Vector2i(r, c))
			if cell.is_empty():
				row += " . "
			else:
				row += "%s%s " % [_piece_char(cell), ("*" if cell.is_primary else " ")]
		print("[Board] " + row)
	print("-------------------------------------------------------------")


func _cell(cell: Vector2i) -> Cell:
	return _cells[cell.x][cell.y]
