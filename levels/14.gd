class_name Level_14
extends Level
## 关卡 (1,4)


func _init() -> void:
	level_name = "关卡 (1,4)"


func referee() -> void:
	print(level_name)
	super.referee()
