extends Level
## 关卡 (5,1)


func _init() -> void:
	level_name = "关卡 (5,1)"


func referee() -> void:
	print(level_name)
	super.referee()
