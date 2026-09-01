class_name Level_02chasing
extends Level
## 关卡 (0,2)


func _init() -> void:
	level_name = "追逐"
	description = "黑色的兵可以吃掉白色的兵，双方轮流操作，每次向四个方向走一个单位，玩家持黑棋，电脑持白棋。"


func referee() -> void:
	# 随机摆放：黑兵（玩家）与白兵（电脑）各占一个空位，且落在不同色格上。
	var black := ChessUtils.random_cell()
	board.add_piece(ChessPiece.PieceType.PAWN, ChessPiece.PieceColor.BLACK, black)
	var white_cell := ChessUtils.random_cell()
	if ChessUtils.odd(black - white_cell):
		white_cell = ChessUtils.random_move(white_cell, ChessUtils.ORTHOGONAL)
	var white := board.add_piece(ChessPiece.PieceType.PAWN, ChessPiece.PieceColor.WHITE, white_cell)
	white.draggable = false
	print(level_name)

	while true:
		var m := waitmove()
		if m.action == Move.Action.EXIT:
			break
		if ChessUtils.is_valid_move(m.from,m.to,ChessUtils.ORTHOGONAL):
			board.call_main_thread("apply_move", [m])
			var t:=ChessUtils.random_move_piece(white, ChessUtils.ORTHOGONAL)
			print(t)
			board.call_main_thread("move", [Move.new(white.pos(),t, Move.Action.MOVE)])
			continue
		else:board.call_main_thread("reject_move", [m])
		
