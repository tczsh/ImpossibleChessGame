extends Level
## 关卡 (0,0)
const TOTAL := 18

func _init() -> void:
	level_name = "剪切"
	description = "将棋盘用1*2的骨牌填满，使得沿着棋盘每一条格子边线直剪过去，都会剪到至少一张骨牌。\
	\nY 在鼠标所指格子放置骨牌，U 删除骨牌；拖动骨牌可移动（拖拽中 A/D 旋转）。"



func referee() -> void:
	# 用基类的字典管理骨牌类型与剩余数量，并显示到 HUD。
	domino_counts = {"骨牌": TOTAL}
	set_domino_counts(domino_counts)
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
						if domino_counts["骨牌"]==0:
							var tt:=0.3
							for i in range(0,5):
								var tb:=true
								for j in range(0,6):
									if board._cell(Vector2i(i,j)).piece==board._cell(Vector2i(i+1,j)).piece:
										tb=false
								if tb:
									print(i)
									var h1:=Vector3((i-2)*0.140,tt,-0.140*3)
									var h2:=Vector3((i-2)*0.140,-tt,0.140*3)
									board.call_main_thread("show_cut_plane", [h1, h2])
							for j in range(0,5):
								var tb:=true
								for i in range(0,6):
									if board._cell(Vector2i(i,j)).piece==board._cell(Vector2i(i,j+1)).piece:
										tb=false
								if tb:
									print(j)
									var h1:=Vector3(-0.140*3,tt,(j-2)*0.140)
									var h2:=Vector3(0.140*3,-tt,(j-2)*0.140)
									board.call_main_thread("show_cut_plane", [h1, h2])
					KEY_U:
						_remove_at(m.mouse_cell)
						board.call_main_thread("clear_mesh")
			Move.Action.MOVE:
				_judge_and_apply(m)
