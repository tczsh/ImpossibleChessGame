class_name Level_55sorting
extends Level
## 关卡 (6,6)：欧拉 36 军官问题。
##
## 用棋子的“种类”和“颜色”分别充当军官的“军衔”和“军团”：6 种棋子 × 6 种颜色 = 36 名
## 军官，每个 (种类, 颜色) 组合恰好一名。目标是把它们排成 6×6，使每一行、每一列都恰好
## 各含一种军衔、各含一种军团 —— 即求 6 阶正交拉丁方（Graeco-Latin square）。
## 欧拉 36 军官问题已被证明无解（1901 年 Tarry），故本关不写胜利判定。


## 6 种兵种（军衔），对应 6 种棋子种类。
var _ranks: Array[ChessPiece.PieceType] = [
	ChessPiece.PieceType.KING,
	ChessPiece.PieceType.QUEEN,
	ChessPiece.PieceType.ROOK,
	ChessPiece.PieceType.BISHOP,
	ChessPiece.PieceType.KNIGHT,
	ChessPiece.PieceType.PAWN,
]

## 6 种军团，对应 6 种棋子颜色。
var _regiments: Array[ChessPiece.PieceColor] = [
	ChessPiece.PieceColor.WHITE,
	ChessPiece.PieceColor.GREEN,
	ChessPiece.PieceColor.BLUE,
	ChessPiece.PieceColor.YELLOW,
	ChessPiece.PieceColor.BLACK,
	ChessPiece.PieceColor.PURPLE,
]


func _init() -> void:
	level_name = "排列"
	description = "排列棋盘上的棋子，让每行列各种棋子种类和颜色都只出现一次\
	\n直接拖动棋子进行交换"


func referee() -> void:
	for r in 6:
		for c in 6:
			board.call_main_thread("add_piece", [_ranks[c], _regiments[r], Vector2i(r, c)])
	_mark_bad_line()
	while true:
		var m := waitmove()
		if m.action == Move.Action.EXIT:
			break
		match m.action:
			Move.Action.MOVE:
				# 目标格已有棋子：交换两个军官；否则按常规移动判定。
				if board.get_piece(m.to) != null:
					_swap(m.from, m.to)
				else:
					_judge_and_apply(m)
				_mark_bad_line()


## 交换 `from` 与 `to` 两个格子上的棋子（两者都必须非空），带过渡动画。交给棋盘的
## swap_pieces() 在主线路上完成：释放足迹 → 互换标记 → move_to 滑动到对方格子。
func _swap(from: Vector2i, to: Vector2i) -> void:
	board.call_main_thread("swap_pieces", [from, to])


## 检查第 `idx` 行（is_row=true）或第 `idx` 列（is_row=false）的 6 个棋子，是否“每种
## 兵种、每种军团都恰好出现一次”。有重复（或空）即不符合要求。
func _line_ok(idx: int, is_row: bool) -> bool:
	var types := {}
	var colors := {}
	for k in 6:
		var cell := Vector2i(idx, k) if is_row else Vector2i(k, idx)
		var p := board.get_piece(cell)
		if p == null:
			return false
		if types.has(p.type) or colors.has(p.color):
			return false
		types[p.type] = true
		colors[p.color] = true
	return true


## 找到第一个不符合要求的行或列，用红色水平切面（Y 轴法向）标记它；只标记一个。全部
## 符合则清空标记（6 阶正交拉丁方无解，故通常总会标记到）。
func _mark_bad_line() -> void:
	board.call_main_thread("clear_mesh")
	var y := 0.01  
	var half := ChessBoard.GRID_SIZE / 2.0
	var span := ChessBoard.GRID_SIZE * 3.0
	for r in 6:
		if not _line_ok(r, true):
			var xc := ChessBoard.GRID_SIZE * (r - 2.5)
			var a := Vector3(xc - half, y, -span)
			var b := Vector3(xc + half, y, span)
			board.call_main_thread("show_cut_plane", [a, b, Color(1, 0.2, 0.2, 0.6)])
			return
	for c in 6:
		if not _line_ok(c, false):
			var zc := ChessBoard.GRID_SIZE * (c - 2.5)
			var a := Vector3(-span, y, zc - half)
			var b := Vector3(span, y, zc + half)
			board.call_main_thread("show_cut_plane", [a, b, Color(1, 0.2, 0.2, 0.6)])
			return
