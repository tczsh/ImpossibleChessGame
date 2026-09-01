extends Level
## 关卡 (2,3)


func _init() -> void:
	level_name = "关卡 (2,3)"


func referee() -> void:
	print(level_name)
	super.referee()
