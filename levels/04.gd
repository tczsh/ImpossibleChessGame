class_name Level_04
extends Level
## 关卡 (0,4)


func _init() -> void:
	level_name = "关卡 (0,4)"


func referee() -> void:
	print(level_name)
	super.referee()
