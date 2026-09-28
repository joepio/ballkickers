extends SceneTree
func _initialize() -> void:
	var image := Image.new()
	var error := image.load_svg_from_string(FileAccess.get_file_as_string("res://assets/icon.svg"))
	if error == OK: error = image.save_png("res://assets/icon.png")
	quit(error)
