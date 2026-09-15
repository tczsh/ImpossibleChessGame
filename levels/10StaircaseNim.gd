class_name Level_10
extends Level
## 关卡 (1,0)：阶梯 Nim（银币游戏 / Staircase Nim）
##
## 5 枚棋子分布在一条螺旋"路"（road）上。玩家与电脑轮流，把一枚棋子沿路向前
## （从前往后，即沿 road 数组下标增大的方向）移动任意格，但不能越过（或落到）前方
## 另一枚棋子。谁先无路可走谁输。
##
## 这是"银币游戏"，等价于 Nim：把棋子从前往后两两配对 (0,1)、(2,3)、…，每对的间隔
## 是一堆石子；奇数枚时最后一枚与远端墙（road 末端）配对。初始间隔为 [4,5,1]，异或
## 和 0，先手（玩家）必输；电脑每次把某堆拨回使异或和为 0。
##
## 操作：拖动一枚棋子沿路向前走（只能走到前方棋子之前的空格）。

## 5 枚棋子在 road 中的初始下标（间隔 [6,3,5]，异或 0，先手必输）。
const COIN_INDICES := [0, 7, 12, 16, 17]

## 各枚棋子的颜色（按 COIN_INDICES 顺序）。
var _coin_colors := [
	ChessPiece.PieceColor.GREEN,
	ChessPiece.PieceColor.BLUE,
	ChessPiece.PieceColor.YELLOW,
	ChessPiece.PieceColor.ORANGE,
	ChessPiece.PieceColor.PURPLE,
]

## 螺旋路径（从前往后），由 _init 构建。
var road: Array = []

## cell -> road 下标。
var _index_of: Dictionary = {}

## 当前各枚棋子在 road 中的下标（升序），由 referee 维护。
var _coin_indices: Array = []


func _init() -> void:
	level_name = "轮盘"
	description = "5 枚棋子沿一条螺旋路从前往后行走：每步拖动一枚棋子向前（沿路朝中心）移动任意格，不能越过或落到前方棋子位置。谁先无路可走谁输。"
	for i in 6:
		road.append(Vector2i(0, i))
	for i in range(1, 6):
		road.append(Vector2i(i, 5))
	for i in range(4, -1, -1):
		road.append(Vector2i(5, i))
	for i in range(4, 1, -1):
		road.append(Vector2i(i, 0))
	for i in range(1, 4):
		road.append(Vector2i(2, i))
	road.append(Vector2i(3, 3))
	for i in road.size():
		_index_of[road[i]] = i


## 行走棋子函数：把 road[from_idx] 处的棋子走到 road[to_idx]。调用前已保证 from 处有
## 棋子、to 处为空且中间无棋子；内部走 board.move 在主线程动画走棋，并同步 _coin_indices。
func _walk_piece(from_idx: int, to_idx: int) -> void:
	var from_cell: Vector2i = road[from_idx]
	var to_cell: Vector2i = road[to_idx]
	board.call_main_thread("move", [Move.new(from_cell, to_cell)])
	var p: int = _coin_indices.find(from_idx)
	if p != -1:
		_coin_indices[p] = to_idx
	_coin_indices.sort()


func referee() -> void:
	_coin_indices = COIN_INDICES.duplicate()
	print(level_name)
	board.call_main_thread("place_domino", ["*****/    */ ** */ ****", ChessPiece.PieceColor.RED, Vector2i(1,0), ChessPiece.Direction.EAST])
	board.get_piece(Vector2i(1,0)).draggable=0
	# 铺盘：在 road 上放 5 枚棋子并着色。
	for j in COIN_INDICES.size():
		board.call_main_thread("add_piece", [
			ChessPiece.PieceType.PAWN,
			_coin_colors[j],
			road[COIN_INDICES[j]],
		])

	while true:
		# —— 玩家回合：无路可走即输 ——
		if _coin_indices==[18, 19, 20, 21, 22]:
			print("[StaircaseNim] 你输了")
			board.call_main_thread("show_result", ["你输了"])
			break

		var m := waitmove()
		if m.action == Move.Action.EXIT:
			return
		if m.action != Move.Action.MOVE:
			continue

		# 校验玩家拖动：from 是棋子、to 在路上、向前（下标增大）、不越过/落到前方棋子。
		var from_idx: int = _index_of.get(m.from, -1)
		var to_idx: int = _index_of.get(m.to, -1)
		if from_idx == -1 or to_idx == -1 or not _coin_indices.has(from_idx) or to_idx <= from_idx:
			board.call_main_thread("reject_move", [m])
			continue
		var next_idx: int = road.size()
		for ci in _coin_indices:
			if int(ci) > from_idx:
				next_idx = int(ci)
				break
		if to_idx >= next_idx:
			board.call_main_thread("reject_move", [m])
			continue

		_walk_piece(from_idx, to_idx)

		# —— 电脑回合：无路可走则电脑输（最优应子下不会发生） ——
		# 最优应子：从前往后两两配对 (0,1)、(2,3)、…，每堆 = 该对间隔；奇数枚时最后一枚
		# 与远端墙（road 末端）配对。用 Nim 决策把各堆异或和拨回 0。
		OS.delay_msec(400)
		var heaps: Array = []
		var heap_owner: Array = []  # 每堆对应的"左棋子"下标：减小该堆 = 把该左棋子前移。
		for j in range(0, _coin_indices.size(), 2):
			var left: int = int(_coin_indices[j])
			if j + 1 < _coin_indices.size():
				heaps.append(int(_coin_indices[j + 1]) - left - 1)
			else:
				heaps.append(int(road.size()) - 1 - left)
			heap_owner.append(left)
		var nm := ChessUtils.nim_move(heaps)
		if int(nm[0]) != -1:
			var owner: int = int(heap_owner[int(nm[0])])
			_walk_piece(owner, owner + int(nm[1]))

	# 游戏结束后仍等待 EXIT，避免 stop_level 投递的 EXIT 残留到下一关。
	while true:
		var m := waitmove()
		if m.action == Move.Action.EXIT:
			return
