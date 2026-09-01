extends Level
## 关卡 (2,4)


func _init() -> void:
	level_name = "关卡 (2,4)"


func referee() -> void:
	print(level_name)
	super.referee()
