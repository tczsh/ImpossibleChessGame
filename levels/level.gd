class_name Level
extends RefCounted
## Base class for the 36 levels.
##
## Each level is a separate script in res://levels/ named "<row><col><name>.gd"
## (e.g. "00开局.gd") that derives from this class. `row`/`col` are filled in by
## BoardSelector from the file name; `level_name` and `referee()` are per level.
##
## Move flow: a drag release calls ChessBoard.request_move(), storing a Move on
## the board under a mutex; quitting the level posts a Move with action EXIT.
## The referee thread's waitmove() polls for that Move, breaks out on EXIT, and
## otherwise judges it inline then confirms it via
## board.call_main_thread("apply_move"/"reject_move") — a blocking main-thread
## call that waits for the board to finish before the referee proceeds.

## The square this level lives on (set by BoardSelector from the file name).
var row: int = -1
var col: int = -1

## The level's display name, shown in the select screen. Override per level.
var level_name: String = "未命名"

## The level's description, shown by the HUD "说明" button. Override per level in
## its _init() (like level_name) to describe its rules / goal.
var description: String = "暂无说明"

## The board this level plays on (set by BoardSelector when it starts).
static var board: ChessBoard = null


## The level's referee logic. Runs on a worker thread: block in waitmove() until
## a move is requested, judge it inline, then confirm or reject the move on the
## main thread. The default allows every move (debug free-play); levels override
## _is_move_allowed() (or the whole referee()) to impose their own rules. Must
## not touch the scene tree directly.
func referee() -> void:
	while true:
		var m := waitmove()
		if m.action == Move.Action.EXIT:
			break
		_judge_and_apply(m)


## Block the referee thread until a Move is requested. Polls the board's shared
## pending move (set by request_move() and cleared by take_move()), checking for
## a change each interval. The loop only returns once a Move arrives; a Move with
## the EXIT action is how the level is told to quit.
func waitmove() -> Move:
	while true:
		var m := board.take_move()
		if m != null:
			return m
		OS.delay_msec(10)
	return Move.new()

## Judge one move and commit or reject it on the main thread, blocking until
## the board actually applies/rejects it before returning.
func _judge_and_apply(m: Move) -> void:
	if board == null:
		return
	if _is_move_allowed(m):
		board.call_main_thread("apply_move", [m])
	else:
		board.call_main_thread("reject_move", [m])


## Whether the move `m` is allowed. Default: the move is allowed only when its
## destination footprint is free of other pieces and stays in-bounds (a pure
## feasibility check via ChessBoard.can_occupy). Override this (or the whole
## referee()) in a level to impose extra rules; call super._is_move_allowed(m) to
## keep the feasibility check.
func _is_move_allowed(m: Move) -> bool:
	var piece := board.get_piece(m.from)
	if piece == null:
		return false
	return board.can_occupy(piece, m.to)


## Send a domino remaining-count dictionary to the HUD. Safe to call from the
## referee thread: it routes through ChessBoard.call_main_thread(), so the UI
## updates on the main thread. Keys are domino names, values are remaining counts.
func set_domino_counts(counts: Dictionary) -> void:
	if board != null:
		board.call_main_thread("set_domino_counts", [counts])


## 放置棋子（骨牌或普通棋子）时循环使用的颜色（展示更多颜色）。
## 不能用 `const`：跨类的枚举成员（ChessPiece.PieceColor.RED）在 const 数组里不是
## 常量表达式，Godot 会报 "isn't a constant expression"，所以改为运行时求值的 typed var。
var _palette: Array[ChessPiece.PieceColor] = [
	ChessPiece.PieceColor.GREEN,
	ChessPiece.PieceColor.BLUE,
	ChessPiece.PieceColor.YELLOW,
	ChessPiece.PieceColor.ORANGE,
	ChessPiece.PieceColor.PURPLE,
	ChessPiece.PieceColor.CYAN,
	ChessPiece.PieceColor.PINK,
]

## 各种棋子（骨牌或普通棋子）类型及其剩余数量。键是棋子名称（如 "骨牌"、"皇后"），值
## 是该类型还剩多少张。子类在 referee() 开始时用 `domino_counts = {"骨牌": TOTAL}`
## 之类的写法初始化它，之后一律通过 update_domino_count() 修改并刷新 HUD，不要直接
## 改这个字典。
var domino_counts: Dictionary = {}

## 已经放下的骨牌张数（仅用于循环取色）。
var _placed := 0


## 更新 `name` 类棋子（骨牌或普通棋子）的剩余数量：在当前值上加上 `delta`（放置传
## -1、删除传 +1），并把最新字典刷新到 HUD。这是修改棋子数量的唯一入口（线程安全，
## 内部走 set_domino_counts）。
func update_domino_count(name: String, delta: int) -> void:
	domino_counts[name] = int(domino_counts.get(name, 0)) + delta
	set_domino_counts(domino_counts)


## 尝试在 `cell` 放置一个棋子（骨牌或普通棋子），成功后 `name` 类剩余数量减一并刷新
## HUD。`piece_type` 为 NONE 时放置骨牌（`shape` 默认是 1×2 横排骨牌 "**"，自动挑选
## 可安放的朝向）；否则放置该类型的普通棋子（占单个格子）。颜色按 _placed 循环取色。
## 子类在 referee() 里处理放置按键时调用。
func _place_at(
	cell: Vector2i,
	name: String = "骨牌",
	shape: String = "**",
	piece_type: ChessPiece.PieceType = ChessPiece.PieceType.NONE
) -> void:
	if int(domino_counts.get(name, 0)) <= 0:
		print("%s 已用完" % name)
		return
	var color: ChessPiece.PieceColor = _palette[_placed % _palette.size()]
	if piece_type != ChessPiece.PieceType.NONE:
		if not board.in_bounds(cell) or not board.is_empty(cell):
			print("无法在 (%d,%d) 放置棋子（越界或已被占用）" % [cell.x, cell.y])
			return
		board.call_main_thread("add_piece", [piece_type, color, cell])
	else:
		var dir := ChessUtils.domino_choose_direction(shape, cell, ChessUtils.SIZE, board)
		if dir == ChessPiece.Direction.NONE:
			print("无法在 (%d,%d) 放置骨牌" % [cell.x, cell.y])
			return
		board.call_main_thread("place_domino", [shape, color, cell, dir])
	_placed += 1
	update_domino_count(name, -1)
	print("已在 (%d,%d) 放置，剩余 %d 张" % [cell.x, cell.y, int(domino_counts[name])])


## 尝试删除鼠标所指格子上的棋子（骨牌或普通棋子）：只删除可拖动的棋子，不删阻挡
## 棋子（不可拖动的），成功后退回一张 `name` 类棋子并刷新 HUD。
func _remove_at(cell: Vector2i, name: String = "骨牌") -> void:
	var piece := board.get_piece(cell)
	if piece == null:
		print("(%d,%d) 处没有棋子" % [cell.x, cell.y])
		return
	if not piece.draggable:
		print("(%d,%d) 处是阻挡棋子，不能删除" % [cell.x, cell.y])
		return
	board.call_main_thread("remove", [cell])
	update_domino_count(name, +1)
	print("已删除 (%d,%d) 的棋子，剩余 %d 张" % [cell.x, cell.y, int(domino_counts[name])])
