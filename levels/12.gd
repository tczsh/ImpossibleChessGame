extends Level
## 关卡 (1,2)


func _init() -> void:
	level_name = "关卡 (1,2)"


func referee() -> void:
	print(level_name)
	super.referee()
