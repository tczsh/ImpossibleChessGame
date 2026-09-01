class_name Level_05
extends Level
## 关卡 (0,5)


func _init() -> void:
	level_name = "关卡 (0,5)"


func referee() -> void:
	print(level_name)
	super.referee()
