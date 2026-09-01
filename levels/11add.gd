extends Level
## 关卡 (1,1)


func _init() -> void:
	level_name = "增加"
	description = "在棋盘上放置11张1*2的骨牌，使得棋盘上无法再放下一块1*2的骨牌\
	\nY 在鼠标所指格子放置骨牌，U 删除骨牌；拖动骨牌可移动（拖拽中 A/D 旋转）。"


func referee() -> void:
	domino_counts = {"骨牌": 11}
	print(level_name)
	set_domino_counts(domino_counts)
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
		board.call_main_thread("clear_mesh")
		if domino_counts["骨牌"]==0:
			var h1
			var h2
			for i in range(0,5):
				for j in range(0,6):
					if board._cell(Vector2i(i,j)).piece==null and \
					board._cell(Vector2i(i+1,j)).piece==null:
						h1=Vector3(0.14*(i-3),0.01,0.14*(j-3))
						h2=Vector3(0.14*(i-1),0.01,0.14*(j-2))
			for j in range(0,5):
				for i in range(0,6):
					if board._cell(Vector2i(i,j)).piece==null and \
					board._cell(Vector2i(i,j+1)).piece==null:
						h1=Vector3(0.14*(i-3),0.01,0.14*(j-3))
						h2=Vector3(0.14*(i-2),0.01,0.14*(j-1))
			board.call_main_thread("show_cut_plane", [h1, h2,Color(1, 0.3, 0.3, 0.7)])
