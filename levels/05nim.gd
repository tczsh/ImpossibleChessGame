class_name Level_05
extends Level
## 关卡 (0,5)：尼姆博弈（NIM）
##
## 6 堆棋子，数量为 1、2、3、3、5、6。玩家与电脑轮流，每步从一堆中拿走若干颗棋子，
## 拿最后一颗者胜。电脑按最优策略应子（每次把各堆异或和拨回 0），初始异或和 1^2^3^3^5^6
## 正好为 0，因此先手玩家必输。
##
## 操作（单方向）：棋子不可拖动。鼠标指向某堆中的一颗棋子，按 U 清空这颗棋子及其之前
## （其上）的棋子——即从该堆顶部往下砍到这颗为止。堆始终底对齐在 0 行，越砍越矮。


## 六堆棋子的初始数量。
const INITIAL_PILES := [1, 2, 3, 3, 5, 6]

## 每堆棋子的颜色（按堆索引取用）。
var _pile_colors := [
	ChessPiece.PieceColor.GREEN,
	ChessPiece.PieceColor.BLUE,
	ChessPiece.PieceColor.YELLOW,
	ChessPiece.PieceColor.ORANGE,
	ChessPiece.PieceColor.PURPLE,
	ChessPiece.PieceColor.CYAN,
]

## 各堆当前数量（裁判线程持有，与棋盘同步）。
var _piles := []


func _init() -> void:
	level_name = "取子"
	description = "6 堆棋子.玩家与电脑轮流，每步从一堆中拿走任意正数颗棋子，轮到一方时无法操作时输。\
\n鼠标指向某堆中的一颗棋子，按 U 清空这颗棋子及其之前的棋子（该堆从顶部往下砍到这颗）."


## 从第 j 堆顶部往下拿走 count 颗棋子（行号 _piles[j]-count .. _piles[j]-1），并同步 _piles。
## 玩家与电脑轮流调用：玩家的 count = 该堆当前数 - 所指行号，电脑的 count = 该堆当前数 - 目标数。
func _remove_top(j: int, count: int) -> void:
	for r in range(int(_piles[j]) - count, int(_piles[j])):
		board.call_main_thread("remove", [Vector2i(r, j)])
	_piles[j] = int(_piles[j]) - count


func referee() -> void:
	_piles = INITIAL_PILES.duplicate()

	# 铺盘：第 j 堆在第 j 列，从 0 行往上叠 _piles[j] 颗，随后把棋子设为不可拖动。
	for j in 6:
		for r in int(_piles[j]):
			board.call_main_thread("add_piece", [
				ChessPiece.PieceType.PAWN,
				_pile_colors[j],
				Vector2i(r, j),
			])
	for r in 6:
		for c in 6:
			var p := board.get_piece(Vector2i(r, c))
			if p != null:
				p.draggable = false

	# 初始 HUD。
	var counts := {}
	for j in 6:
		counts["堆%d" % (j + 1)] = _piles[j]
	set_domino_counts(counts)
	print(level_name)

	while true:
		var m := waitmove()
		if m.action == Move.Action.EXIT:
			return

		# 玩家回合：仅响应"按 U 清空所指棋子及其之前（其上）的棋子"。
		if m.action != Move.Action.KEY or m.key != KEY_U:
			continue
		var cell := m.mouse_cell
		var j := cell.y
		var r := cell.x
		if board.get_piece(cell) == null:
			continue
		_remove_top(j, int(_piles[j]) - r)

		# 刷新 HUD；玩家拿完最后一颗则玩家胜（对最优电脑不会发生，仅兜底）。
		var c2 := {}
		for jj in 6:
			c2["堆%d" % (jj + 1)] = _piles[jj]
		set_domino_counts(c2)
		var empty := true
		for n in _piles:
			if int(n) > 0:
				empty = false
		if empty:
			print("[NIM] 你赢了")
			board.call_main_thread("show_result", ["你赢了"])
			break

		# 电脑回合（先停顿一下让玩家看清）。
		OS.delay_msec(500)
		var nm := ChessUtils.nim_move(_piles)
		if int(nm[0]) != -1:
			_remove_top(int(nm[0]), int(nm[1]))
		# 刷新 HUD；电脑拿完最后一颗则电脑胜。
		var c3 := {}
		for jj in 6:
			c3["堆%d" % (jj + 1)] = _piles[jj]
		set_domino_counts(c3)
		var empty2 := true
		for n in _piles:
			if int(n) > 0:
				empty2 = false
		if empty2:
			print("[NIM] 你输了")
			board.call_main_thread("show_result", ["你输了"])
			break
		board.call_main_thread("take_move")
	while true:
		var m := waitmove()
		if m.action == Move.Action.EXIT:
			return
