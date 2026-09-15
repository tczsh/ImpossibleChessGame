class_name Level_03
extends Level
## 关卡 (0,3)


func _init() -> void:
		level_name = "留一"
		description = "棋盘上放满棋子，先按U删去一颗任意一颗棋子，然后每一次控制一颗棋子跳过另一颗相邻的棋子，并吃掉它。最后留下一颗棋子即为胜利"


func referee() -> void:
	print(level_name)
	for r in 6:
		for c in 6:
			board.call_main_thread("add_piece", [ChessPiece.PieceType.PAWN,ChessPiece.PieceColor.WHITE, Vector2i(r, c)])
	for r in 6:
		for c in 6:
			board._cell(Vector2i(r,c)).piece.draggable=0
	while true:
		var m := waitmove()
		if m.action == Move.Action.EXIT:
			return
		if m.action==Move.Action.KEY and m.key==KEY_U and board.get_piece(m.mouse_cell)!=null:
			board.call_main_thread("remove", [m.mouse_cell])
			break
	for r in 6:
		for c in 6:
			if board.get_piece(Vector2i(r,c))!=null:
				board._cell(Vector2i(r,c)).piece.draggable=1
	while true:
		var m := waitmove()
		if m.action == Move.Action.EXIT:
			return
		if m.action==Move.Action.MOVE:
			var ism:=false
			var dx=m.from-m.to
			var mid=m.from+m.to
			mid.x/=2
			mid.y/=2
			if dx.abs() in [Vector2i(0,2),Vector2i(2,0)]:
				if board.get_piece(m.to)==null and board.get_piece(mid)!=null:
					ism=true
			if ism:
				board.call_main_thread("apply_move", [m])
				board.call_main_thread("remove", [mid])
				pass
			else:board.call_main_thread("reject_move", [m])
	
