class_name Level_22covering
extends Level
## 关卡 (2,2)


func _init() -> void:
	level_name = "覆盖"
	description = "用9张丁字形的4骨牌覆盖全棋盘\
	\nY 在鼠标所指格子放置骨牌，U 删除骨牌；拖动骨牌可移动（拖拽中 A/D 旋转）。"

func referee() -> void:
	domino_counts = {"骨牌": 9}
	set_domino_counts(domino_counts)
	while true:
		var m := waitmove()
		if m.action == Move.Action.EXIT:
			break
		match m.action:
			Move.Action.KEY:
				match m.key:
					KEY_Y:
						_place_at(m.mouse_cell,"骨牌"," */***")
						
					KEY_U:
						_remove_at(m.mouse_cell)
						
			Move.Action.MOVE:
				_judge_and_apply(m)
