class_name Level_04
extends Level
## 关卡 (0,4)
##
## 从 (0,0) 出发，每一步走到相邻格（上下左右一格），走遍 6×6 棋盘全部 36 格、每格
## 恰好一次，最后停在 (5,5)。走过的格子用 show_cut_plane 标成淡蓝色方块。
##
## 这是“走遍所有格子”的哈密顿路径问题：起点 (0,0) 与终点 (5,5) 同色（行+列之和同为
## 偶数），而每走一步都会落到异色格上，走完 36 格需要 35 步，最后必然落在异色格，
## 永远到不了同色的 (5,5)——所以这是不可能完成的任务，本关不写胜利判定。


## 走过的格子（Vector2i -> true）。必须在 referee() 开头 clear()，因为关卡对象会被
## BoardSelector 复用（replay 时重新跑 referee()）。
var _visited: Dictionary = {}

## 当前棋子所在的格子。
var _current: Vector2i = Vector2i(0, 0)


func _init() -> void:
	level_name = "巡游"
	description = "从 (0,0) 出发，每次拖动棋子走到相邻一格（上下左右），走遍全部 36 格、每格恰好一次，最后到达 (5,5)."


func referee() -> void:
	print(level_name)
	# 关卡对象会被复用，每次开局清空上一次的路径记录。
	_visited.clear()
	_current = Vector2i(0, 0)

	# 在起点放一枚白兵作为“玩家”，并标出起点。
	board.call_main_thread("add_piece", [ChessPiece.PieceType.PAWN, ChessPiece.PieceColor.WHITE, _current])
	_visited[_current] = true
	var cl:=Color(0.629, 0.108, 0.133, 1)
	_mark_cell(_current, cl)
	# 用一个不同颜色的方块标出终点 (5,5)，提示目标位置。
	_mark_cell(Vector2i(5, 5), Color(0.3, 0.9, 0.4, 0.35))

	while true:
		var m := waitmove()
		if m.action == Move.Action.EXIT:
			break
		if m.action == Move.Action.MOVE:
			# 合法条件：一格相邻（上下左右）、目标格尚未走过、目标格可落子（界内且为空）。
			if ChessUtils.ORTHOGONAL.has(m.to - m.from) \
					and not _visited.has(m.to) \
					and not _visited.has(Vector2i(5,5))\
					and board.can_occupy(board.get_piece(m.from), m.to):
				board.call_main_thread("apply_move", [m])
				_current = m.to
				_visited[_current] = true
				_mark_cell(_current, cl)
			else:
				board.call_main_thread("reject_move", [m])


## 用 show_cut_plane 在 `cell` 上方铺一个半透明方块（略小于格子，避免相邻方块粘连）。
func _mark_cell(cell: Vector2i, color: Color) -> void:
	var center := board.get_chess_position(cell)
	var half := ChessBoard.GRID_SIZE * 0.5-0.001
	var h := 0.005
	var a := center + Vector3(-half, h, -half)
	var b := center + Vector3(half, h, half)
	board.call_main_thread("show_cut_plane", [a, b, color])
