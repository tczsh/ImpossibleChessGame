extends Level
## 关卡 (4,4)：限制放置 6 个车（车）。放满 6 个后触发判定；判定处为示例占位，直接
## 写 pass（无胜负逻辑）。


func _init() -> void:
	level_name = "错位"
	description = "放置 6 个皇后：使得找不出三个皇后：它们要么互相能吃，要么互相不能吃\
	\nY 在鼠标所指格子放置棋子，U 删除棋子。"
	_palette = [ChessPiece.PieceColor.BLACK]

func iseat(a:ChessPiece,b:ChessPiece)->int:
	var pa := a.pos()
	var pb := b.pos()
	var dr := pb.x - pa.x
	var dc := pb.y - pa.y
	# 既不同行、不同列，也不同对角线：不相吃。
	if dr != 0 and dc != 0 and absi(dr) != absi(dc):
		return 0
	# 沿行/列/对角线从 a 一步步走向 b，途中任何一格有棋子即被阻挡，不相吃。
	var sr := signi(dr)
	var sc := signi(dc)
	var r := pa.x + sr
	var c := pa.y + sc
	while r != pb.x or c != pb.y:
		if board.get_piece(Vector2i(r, c)) != null:
			return 0
		r += sr
		c += sc
	return 1
func referee() -> void:
	domino_counts = {"皇后": 6}
	set_domino_counts(domino_counts)
	while true:
		var m := waitmove()
		if m.action == Move.Action.EXIT:
			break
		match m.action:
			Move.Action.KEY:
				match m.key:
					KEY_Y:
						_place_at(m.mouse_cell, "皇后","*",ChessPiece.PieceType.QUEEN)
						
					KEY_U:
						_remove_at(m.mouse_cell, "皇后")
			Move.Action.MOVE:
				_judge_and_apply(m)
		board.call_main_thread("clear_markers")
		if domino_counts["皇后"] == 0:
			var qw:Array=[]
			for i in range(6):
				for j in range(6):
					var s=board._cell(Vector2i(i,j)).piece
					if s!=null:
						qw.push_back(s)
			var f=[0,0,0,0,0,0]
			var h1
			var h2
			var h3
			for i in range(6):
				f[i]=1
				for j in range(6):
					if f[j]:continue
					f[j]=1
					for k in range(6):
						if f[k]:continue
						var h=iseat(qw[i],qw[j])+iseat(qw[j],qw[k])+iseat(qw[k],qw[i])
						if h==0 or h==3:
							h1=qw[i].pos()
							h2=qw[j].pos()
							h3=qw[k].pos()
					f[j]=0
				f[i]=0	
			board.call_main_thread("add_marker",[h1])
			board.call_main_thread("add_marker",[h2])
			board.call_main_thread("add_marker",[h3])
			pass
