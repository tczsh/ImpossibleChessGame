class_name Move
extends RefCounted
## A single chess move: the source square and destination square (both as
## row, col) plus the action it represents. This is the one shared type passed
## through every move-related function in ChessBoard and Level.


## What this Move asks for: a normal board move, or quitting the level.
enum Action { NONE,MOVE, EXIT, KEY }


## The source square, as a Vector2i(row, col).
var from: Vector2i = Vector2i(-1, -1)
## The destination square, as a Vector2i(row, col).
var to: Vector2i = Vector2i(-1, -1)
## Which action this Move represents (default: a normal move).
var action: Action = Action.MOVE
## The direction the piece should face after this move. NONE = no change (keep
## the piece's current facing); a player-rotated domino carries its new facing
## here so the board can record it. See ChessPiece.Direction.
var direction: ChessPiece.Direction = ChessPiece.Direction.NONE
## The key that was pressed. Only meaningful for Action.KEY.
var key: Key = KEY_NONE
## The board cell under the mouse when the key was pressed (may be out of bounds
## when the cursor was off the board). Only meaningful for Action.KEY.
var mouse_cell: Vector2i = Vector2i(-1, -1)


func _init(
	src: Vector2i = Vector2i(-1, -1),
	dst: Vector2i = Vector2i(-1, -1),
	act: Action = Action.MOVE,
	dir: ChessPiece.Direction = ChessPiece.Direction.NONE,
	keycode: Key = KEY_NONE,
	cell: Vector2i = Vector2i(-1, -1)
) -> void:
	from = src
	to = dst
	action = act
	direction = dir
	key = keycode
	mouse_cell = cell
