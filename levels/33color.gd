class_name Level_33color
extends Level
## 关卡 (3,3) 皇后染色
##
## 6×6 棋盘铺满 36 个皇后，把每个皇后染成 6 种颜色之一，使同种颜色的皇后互不相吃。
## 这是 6×6 皇后图的 6-染色问题，需要 7 种颜色，因此 6 色必然失败——本关不写胜利判定。


## 可用的 6 种颜色，对应数字键 1-6。
const QUEEN_COLORS := [
	ChessPiece.PieceColor.WHITE,
	ChessPiece.PieceColor.GREEN,
	ChessPiece.PieceColor.BLUE,
	ChessPiece.PieceColor.YELLOW,
	ChessPiece.PieceColor.ORANGE,
	ChessPiece.PieceColor.PURPLE,
]


func _init() -> void:
	level_name = "染色"
	description = "6×6 棋盘铺满 36 个皇后，把每个皇后染成 6 种颜色之一，使同种颜色的皇后在可以越过棋子的意义下互不相吃（不在同行、同列、同对角线）。\
\n数字键 1-6（白/绿/蓝/黄/橙/紫）给鼠标所指格子的皇后上色。"


func referee() -> void:
	print(level_name)
	# 铺满 36 个皇后（初始全部白色，不可拖动）。
	board.call_main_thread("fill_queens", [ChessPiece.PieceColor.WHITE])
	while true:		
		board.call_main_thread("clear_markers")
		var h1
		var h2
		for i in range(0,6):
			for j in range(0,6):
				for i1 in range(0,6):
					for j1 in range(0,6):
						if i==i1 and j==j1:continue
						if i==i1 or j==j1 or i-j==i1-j1 or i+j==i1+j1:
							if board._cell(Vector2i(i,j)).piece.color==\
								board._cell(Vector2i(i1,j1)).piece.color:
									h1=Vector2i(i,j)
									h2=Vector2i(i1,j1)
		board.call_main_thread("add_marker",[h1])
		board.call_main_thread("add_marker",[h2])
		var m := waitmove()
		if m.action == Move.Action.EXIT:
			break
		if m.action == Move.Action.KEY:
			var idx := _color_index(m.key)
			if idx >= 0:
				board.call_main_thread("recolor", [m.mouse_cell, QUEEN_COLORS[idx]])

## 数字键 1-6 对应的颜色索引；非染色键返回 -1。
func _color_index(key: Key) -> int:
	match key:
		KEY_1:
			return 0
		KEY_2:
			return 1
		KEY_3:
			return 2
		KEY_4:
			return 3
		KEY_5:
			return 4
		KEY_6:
			return 5
		_:
			return -1
