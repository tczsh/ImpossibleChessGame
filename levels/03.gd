class_name Level_03
extends Level
## 关卡 (0,3)


func _init() -> void:
	level_name = "关卡 (0,3)"


func referee() -> void:
	print(level_name)
	super.referee()
