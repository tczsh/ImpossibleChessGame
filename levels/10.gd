extends Level
## 关卡 (1,0)


func _init() -> void:
	level_name = "关卡 (1,0)"


func referee() -> void:
	print(level_name)
	super.referee()
