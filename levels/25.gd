class_name Level_25
extends Level
## 关卡 (2,5)


func _init() -> void:
	level_name = "关卡 (2,5)"


func referee() -> void:
	print(level_name)
	super.referee()
