class_name Level_35
extends Level
## 关卡 (3,5)


func _init() -> void:
	level_name = "关卡 (3,5)"


func referee() -> void:
	print(level_name)
	super.referee()
