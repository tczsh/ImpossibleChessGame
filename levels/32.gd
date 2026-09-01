extends Level
## 关卡 (3,2)


func _init() -> void:
	level_name = "关卡 (3,2)"


func referee() -> void:
	print(level_name)
	super.referee()
