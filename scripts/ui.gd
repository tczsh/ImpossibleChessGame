class_name GameUI
extends CanvasLayer
## Floating overlay UI with Exit / Replay / Test / 说明 (Info) buttons.
##
## The four TextureButtons (and the debug LineEdit) are direct children of this
## CanvasLayer in chess_board.tscn. Each button is textured by an AtlasTexture cut
## out of assets/UI.png; tweak those `region` rects and the nodes' offsets in the
## editor to line everything up with your sprite sheet.
##
## In debug builds (OS.is_debug_build) the "CommandInput" LineEdit is shown and
## wired to a small text console: add / remove / move pieces by command.


@onready var exit_button: TextureButton = $ExitButton
@onready var replay_button: TextureButton = $ReplayButton
@onready var test_button: TextureButton = $TestButton
@onready var command_input: LineEdit = $CommandInput
@onready var info_button: TextureButton = $InfoButton

## The panel (and its label) that shows the current level's description when the
## static "说明" button is toggled.
static var description_panel: PanelContainer = null
static var description_label: Label = null

## The panel (and its list) that shows the current level's domino remaining
## counts. The level thread pushes a {name: count} dictionary via
## ChessBoard.set_domino_counts(); set_domino_counts() renders one row per entry.
var domino_panel: PanelContainer = null
var domino_list: VBoxContainer = null

## Hover/press feedback for the UI buttons (no extra textures needed).
const BUTTON_HOVER_SCALE := Vector2(1.08, 1.08)
const BUTTON_PRESS_MODULATE := Color(0.7, 0.7, 0.7, 1.0)


func _ready() -> void:
	exit_button.pressed.connect(_on_exit_pressed)
	replay_button.pressed.connect(_on_replay_pressed)
	test_button.pressed.connect(_on_test_pressed)
	info_button.pressed.connect(_on_info_pressed)

	_setup_button_fx()
	_setup_info_panel()
	_setup_domino_panel()

	# The debug command box is only shown in debug builds.
	if _is_debug_enabled():
		command_input.text_submitted.connect(_on_command_submitted)
	else:
		command_input.visible = false


## Connect hover/press feedback to the buttons.
func _setup_button_fx() -> void:
	for button in [exit_button, replay_button, test_button, info_button]:
		button.pivot_offset = button.size / 2.0
		button.mouse_entered.connect(_on_button_hover.bind(button, true))
		button.mouse_exited.connect(_on_button_hover.bind(button, false))
		button.button_down.connect(_on_button_press.bind(button, true))
		button.button_up.connect(_on_button_press.bind(button, false))


func _on_button_hover(button: Control, hovering: bool) -> void:
	button.scale = BUTTON_HOVER_SCALE if hovering else Vector2.ONE


func _on_button_press(button: Control, pressed: bool) -> void:
	button.self_modulate = BUTTON_PRESS_MODULATE if pressed else Color.WHITE


func _on_exit_pressed() -> void:
	var board := _board()
	if board == null:
		return
	# End the current level and hide its name in the HUD.
	
	var selector := board.board_selector
	$CommandInput.visible=0
	if selector != null:
		selector.stop_level()

func _on_replay_pressed() -> void:
	var board := _board()
	if board == null:
		return
	# Replay the current level if one is selected.
	var selector := board.board_selector
	if selector != null:
		selector.replay()


func _on_test_pressed() -> void:
	# Debug free-play: run a bare Level whose default referee allows every move.
	var board := _board()
	if board == null:
		return
	var selector := board.board_selector	
	$CommandInput.visible=1
	if selector != null:
		selector.start_debug_play()


## Create the (initially hidden) description panel that the static "说明" button
## toggles. The button itself lives in chess_board.tscn as a TextureButton.
func _setup_info_panel() -> void:
	description_panel = PanelContainer.new()
	description_panel.visible = false
	description_panel.position = Vector2(176, 96)
	description_panel.custom_minimum_size = Vector2(700, 0)
	add_child(description_panel)

	description_label = Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_panel.add_child(description_label)


## Create the (initially hidden) domino remaining-count panel. Rows are added
## dynamically by set_domino_counts() as the level thread updates the counts.
func _setup_domino_panel() -> void:
	domino_panel = PanelContainer.new()
	domino_panel.visible = false
	domino_panel.position = Vector2(16, 72)
	add_child(domino_panel)

	domino_list = VBoxContainer.new()
	domino_panel.add_child(domino_list)


## Rebuild the domino remaining-count list from a {name: count} dictionary.
## Passed by the level referee thread (through ChessBoard.set_domino_counts) to
## keep the HUD in sync with how many of each domino are left. Empty hides the
## panel.
func set_domino_counts(counts: Dictionary) -> void:
	if domino_list == null:
		return
	for child in domino_list.get_children():
		domino_list.remove_child(child)
		child.queue_free()
	if counts.is_empty():
		domino_panel.visible = false
		return
	for domino_name in counts.keys():
		var label := Label.new()
		label.text = "%s × %d" % [domino_name, int(counts[domino_name])]
		domino_list.add_child(label)
	domino_panel.visible = true


## Toggle the description panel, showing the current level's description (or a
## hint when no level is running).
func _on_info_pressed() -> void:
	var text := ""
	var board := _board()
	if board != null and board.board_selector != null:
		text = board.board_selector.current_description()
	if text.is_empty():
		text = "欢迎游玩不可能的6*6游戏\n从棋盘对角线选择一个关卡开始"
	description_label.text = text
	description_panel.visible = not description_panel.visible


## Whether the debug command box should be available. Override this if you use
## a different notion of "debug mode".
func _is_debug_enabled() -> bool:
	return OS.is_debug_build()


## Find the ChessBoard by walking up the tree (the UI is a child of the board
## scene's root, which carries the ChessBoard script).
func _board() -> ChessBoard:
	var node: Node = self
	while node != null:
		if node is ChessBoard:
			return node
		node = node.get_parent()
	return null


# --- Debug command console ------------------------------------------------

func _on_command_submitted(text: String) -> void:
	var trimmed := text.strip_edges()
	command_input.clear()
	if trimmed.is_empty():
		return
	_run_command(trimmed)


func _run_command(text: String) -> void:
	var parts := text.split(" ", false)
	var cmd := parts[0].to_lower()
	match cmd:
		"help":
			_print_help()
		"add":
			_cmd_add(parts)
		"remove", "del", "delete", "rm":
			_cmd_remove(parts)
		"move", "mv":
			_cmd_move(parts)
		"domino", "dm":
			_cmd_domino(parts)
		_:
			printerr("[GameUI] 未知指令: %s （输入 help 查看帮助）" % cmd)


func _print_help() -> void:
	print("[GameUI] 可用指令：")
	print("  add <类型> <颜色> <行> <列>   添加棋子")
	print("    类型: king/queen/rook/bishop/knight/pawn（或 k/q/r/b/n/p）")
	print("    颜色: white/black（或 w/b）")
	print("  remove <行> <列>             移除棋子")
	print("  move <行1> <列1> <行2> <列2> 移动棋子")
	print("  domino <形状> <颜色> <行> <列>  生成骨牌")
	print("    形状: * 实心, . 空, / 换行（如 **/**）")
	print("  坐标范围 0-5，顺序为 行(row) 列(col)")


func _cmd_add(parts: PackedStringArray) -> void:
	if parts.size() != 5:
		printerr("[GameUI] add 用法: add <类型> <颜色> <行> <列>")
		return
	var type := _parse_type(parts[1])
	if type == ChessPiece.PieceType.NONE:
		printerr("[GameUI] 未知棋子类型: %s" % parts[1])
		return
	if not _is_color(parts[2]):
		printerr("[GameUI] 未知颜色: %s" % parts[2])
		return
	var color := _parse_color(parts[2])
	var row := parts[3].to_int()
	var col := parts[4].to_int()
	var board := _board()
	if board == null:
		printerr("[GameUI] 找不到棋盘")
		return
	var piece := board.add_piece(type, color, Vector2i(row, col))
	if piece == null:
		printerr("[GameUI] 无法在 (%d,%d) 添加棋子（越界或已占用）" % [row, col])
		return
	print("[GameUI] 已添加 %s %s 到 (%d,%d)" % [parts[2], parts[1], row, col])


func _cmd_remove(parts: PackedStringArray) -> void:
	if parts.size() != 3:
		printerr("[GameUI] remove 用法: remove <行> <列>")
		return
	var row := parts[1].to_int()
	var col := parts[2].to_int()
	var board := _board()
	if board == null:
		printerr("[GameUI] 找不到棋盘")
		return
	if board.remove(Vector2i(row, col)):
		print("[GameUI] 已移除 (%d,%d) 的棋子" % [row, col])
	else:
		printerr("[GameUI] (%d,%d) 没有棋子（或越界）" % [row, col])


func _cmd_move(parts: PackedStringArray) -> void:
	if parts.size() != 5:
		printerr("[GameUI] move 用法: move <行1> <列1> <行2> <列2>")
		return
	var from_row := parts[1].to_int()
	var from_col := parts[2].to_int()
	var to_row := parts[3].to_int()
	var to_col := parts[4].to_int()
	var board := _board()
	if board == null:
		printerr("[GameUI] 找不到棋盘")
		return
	if board.move(Move.new(Vector2i(from_row, from_col), Vector2i(to_row, to_col))):
		print("[GameUI] 已从 (%d,%d) 移动到 (%d,%d)" % [from_row, from_col, to_row, to_col])
	else:
		printerr("[GameUI] 移动失败（源为空 / 越界 / 目标已占用）")


func _cmd_domino(parts: PackedStringArray) -> void:
	if parts.size() != 5:
		printerr("[GameUI] domino 用法: domino <形状> <颜色> <行> <列>")
		return
	var shape := parts[1]
	if not _is_color(parts[2]):
		printerr("[GameUI] 未知颜色: %s" % parts[2])
		return
	var color := _parse_color(parts[2])
	var row := parts[3].to_int()
	var col := parts[4].to_int()
	var board := _board()
	if board == null:
		printerr("[GameUI] 找不到棋盘")
		return
	var domino := Domino.new(shape, color)
	board.add_child(domino)
	if not board.place(domino, Vector2i(row, col)):
		domino.queue_free()
		printerr("[GameUI] 无法在 (%d,%d) 生成骨牌（越界或与已有棋子重叠）" % [row, col])
		return
	print("[GameUI] 已生成骨牌 %s（%s）到 (%d,%d)" % [parts[2], shape, row, col])


func _parse_type(s: String) -> ChessPiece.PieceType:
	match s.to_lower():
		"king", "k":
			return ChessPiece.PieceType.KING
		"queen", "q":
			return ChessPiece.PieceType.QUEEN
		"rook", "r":
			return ChessPiece.PieceType.ROOK
		"bishop", "b":
			return ChessPiece.PieceType.BISHOP
		"knight", "n":
			return ChessPiece.PieceType.KNIGHT
		"pawn", "p":
			return ChessPiece.PieceType.PAWN
		_:
			return ChessPiece.PieceType.NONE


func _is_color(s: String) -> bool:
	return s.to_lower() in ["white", "w", "black", "b"]


func _parse_color(s: String) -> ChessPiece.PieceColor:
	match s.to_lower():
		"black", "b":
			return ChessPiece.PieceColor.BLACK
		_:
			return ChessPiece.PieceColor.WHITE
