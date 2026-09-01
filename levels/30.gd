class_name Level_30
extends Level
## 关卡 (3,0)


func _init() -> void:
	level_name = "关卡 (3,0)"


func referee() -> void:
	print(level_name)
	super.referee()
