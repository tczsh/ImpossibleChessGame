class_name Level_01placing
extends Level
## 关卡 (0,1)
##
## 示例：棋盘 (0,0) 与 (5,5) 两角被“挖去”（占据），用 17 张 1×2 骨牌覆盖其余 34 格。
## 对角两格同色，而每张 1×2 骨牌必然覆盖一黑一白，因此这是不可能完成的任务——
## 本关不写胜利判定。玩家按 R 旋转骨牌方向，按空格在鼠标所指格子放置骨牌；放下的
## 骨牌可以拖动（拖拽中按 A/D 旋转）。


## 总共要用的骨牌张数（17 张 1×2，共覆盖 34 格）。
const TOTAL := 17


func _init() -> void:

	level_name = "放置"
	description = "棋盘 (0,0) 与 (5,5) 两角已被占据。用 17 张 1×2 骨牌覆盖其余全部格子。\nY键在鼠标所指格子放置骨牌（自动选择朝向），U 删除骨牌；拖动骨牌可移动（拖拽中 A/D 旋转）。"


func referee() -> void:
	# 用基类的字典管理骨牌类型与剩余数量，并显示到 HUD。
	domino_counts = {"骨牌": TOTAL}
	set_domino_counts(domino_counts)
	# 占据两个对角（“被移除”的格子），做成不可拖动的棋子。
	board.call_main_thread("place_blocker", [Vector2i(0, 0)])
	board.call_main_thread("place_blocker", [Vector2i(5, 5)])

	print(level_name)

	while true:
		var m := waitmove()
		if m.action == Move.Action.EXIT:
			break
		match m.action:
			Move.Action.KEY:
				match m.key:
					KEY_Y:
						_place_at(m.mouse_cell)
					KEY_U:
						_remove_at(m.mouse_cell)
			Move.Action.MOVE:
				_judge_and_apply(m)
