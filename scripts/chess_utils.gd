class_name ChessUtils
extends RefCounted
## 两个走子辅助函数 + 供它们使用的预设行走列表常量。
##
## 下面的常量是常见棋子的移动方式列表，每一项都是 Vector2i(dr, dc) 偏移。调用两个
## 函数时把这些常量作为 `pattern` 参数传入：
##
##     var to := ChessUtils.random_move(cell, ChessUtils.KNIGHT, SIZE, board)
##     if ChessUtils.is_valid_move(cell, cell + Vector2i(-1, 0), ChessUtils.ADJACENT, SIZE, board):
##         ...
##
## 坐标为 Vector2i(row, col)，与 ChessBoard 一致（row -> 世界 X，col -> 世界 Z）。传入
## `board` 时目标格还必须为空（未被占用）；不传则只做几何与边界判定。

## 棋盘边长（与 ChessBoard.SIZE 保持同步）。
const SIZE := 6


# --- 行走列表常量 (preset movement lists) -----------------------------------

## 车 — 四个直线方向。
const ORTHOGONAL := [
	Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1),
]

## 象 — 四个斜线方向。
const DIAGONAL := [
	Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1),
]

## 王 / 后 — 八个相邻方向。
const ADJACENT := [
	Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1),
	Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1),
]

## 马 — 八个 L 形跳跃。
const KNIGHT := [
	Vector2i(-2, -1), Vector2i(-2, 1), Vector2i(-1, -2), Vector2i(-1, 2),
	Vector2i(1, -2), Vector2i(1, 2), Vector2i(2, -1), Vector2i(2, 1),
]
static func odd(t:Vector2i)->bool:
	return (t.x+t.y)%2

# --- 判断 (validation) ------------------------------------------------------

## 判定从 `cell` 走到 `to` 这一步是否合法：位移 `to - cell` 必须在 `pattern`（行走
## 列表常量）中、目标格在界内，且（传入 `board` 时）目标格未被占用。
static func is_valid_move(
	cell: Vector2i, to: Vector2i, pattern: Array, size: int = SIZE,
	board: ChessBoard = Level.board
) -> bool:
	if not pattern.has(to - cell):
		return false
	if to.x < 0 or to.x >= size or to.y < 0 or to.y >= size:
		return false
	if board != null and not board.is_empty(to):
		return false
	return true


# --- 随机选取 (random selection) -------------------------------------------

## 从 `pattern`（行走列表常量）中随机选一个落在界内（且传入 `board` 时未被占用）的
## 目标返回。无合法目标时返回原格 `cell`，保证结果始终是合法方格。
static func random_move(
	cell: Vector2i, pattern: Array, size: int = SIZE, board: ChessBoard = Level.board
) -> Vector2i:
	var options: Array = []
	for off: Vector2i in pattern:
		if is_valid_move(cell, cell + off, pattern, size, board):
			options.append(cell + off)
	if options.is_empty():
		print("err")
		return Vector2i(-1,-1)
	return options[randi() % options.size()]


## 随机返回一个空位（传入 `board` 时）。无空位时返回 Vector2i(-1, -1)。
static func random_cell(board: ChessBoard = Level.board)->Vector2i:
	while 1:
		var r:=randi()%SIZE
		var c:=randi()%SIZE
		if board.is_empty(Vector2i(r,c)):return Vector2i(r,c)
	return Vector2i(-1,-1)


# --- 棋子版本 (piece-based) -------------------------------------------------

## 判定 `piece` 走到 `to` 这一步是否合法：以棋子的 (row, col) 为起点，其余同
## is_valid_move（位移需在 `pattern` 中、目标格在界内、未被占用）。`to` 是
## 绝对目标格，不是相对偏移。
static func is_valid_move_piece(
	piece: ChessPiece, to: Vector2i, pattern: Array, size: int = SIZE,
	board: ChessBoard = Level.board
) -> bool:
	if piece == null:
		return false
	return is_valid_move(piece.pos(), to, pattern, size, board)


## 为 `piece` 从 `pattern` 中随机选一个合法目标格（以棋子的 (row, col) 为起点），
## 其余同 random_move。棋子为 null 时返回 Vector2i(-1, -1)。
static func random_move_piece(
	piece: ChessPiece, pattern: Array, size: int = SIZE, board: ChessBoard = Level.board
) -> Vector2i:
	if piece == null:
		return Vector2i(-1, -1)
	return random_move(piece.pos(), pattern, size, board)


# --- 骨牌 (domino) -----------------------------------------------------------

## 判断形状字符串 `shape` 描述的骨牌能否以 `direction` 朝向把锚点格放在 `cell`：
## 所有实心格都在界内且未被占用。用 Domino.shape_offsets_for_direction 解析形状，
## 无需创建 Domino 实例。shape 格式与 Domino 一致（'*' 实心、' ' 或 '.' 空、'/'
## 换行，如 "**/* "）。direction 为 NONE 时按基础朝向判定。
static func domino_can_place(
	shape: String, cell: Vector2i, size: int = SIZE,
	board: ChessBoard = Level.board,
	direction: ChessPiece.Direction = ChessPiece.Direction.NONE
) -> bool:
	if board == null:
		return false
	for off: Vector2i in Domino.shape_offsets_for_direction(shape, direction):
		var v := cell + off
		if v.x < 0 or v.x >= size or v.y < 0 or v.y >= size:
			return false
		if not board.is_empty(v):
			return false
	return true


## 判断形状字符串 `shape` 的骨牌在当前棋盘上是否至少存在一个可安放的锚点格（即
## 玩家还能落下这块骨牌）。用作关卡里“是否还有合法放置”的判断。
static func domino_has_placement(
	shape: String, size: int = SIZE, board: ChessBoard = Level.board
) -> bool:
	if board == null:
		return false
	for r in size:
		for c in size:
			if domino_can_place(shape, Vector2i(r, c), size, board):
				return true
	return false


## 为 `shape` 骨牌在 `cell` 锚点自动挑选一个可安放的朝向：按 N/E/S/W 顺序尝试，返回
## 第一个所有实心格都在界内且未被占用的朝向；四个朝向都不行时返回 NONE（表示无法
## 安放）。用 domino_can_place 判定，无需创建 Domino 实例。
static func domino_choose_direction(
	shape: String, cell: Vector2i, size: int = SIZE,
	board: ChessBoard = Level.board
) -> ChessPiece.Direction:
	for dir: ChessPiece.Direction in ChessPiece.DIR_CYCLE:
		if domino_can_place(shape, cell, size, board, dir):
			return dir
	return ChessPiece.Direction.NONE
