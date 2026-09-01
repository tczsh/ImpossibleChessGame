class_name Level_13
extends Level
## 关卡 (1,3)


func _init() -> void:
	level_name = "关卡 (1,3)"


func referee() -> void:
	print(level_name)
	super.referee()
