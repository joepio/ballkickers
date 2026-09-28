extends SceneTree
func _initialize() -> void:
	var image := Image.new()
	assert(image.load_svg_from_string(FileAccess.get_file_as_string("res://assets/cover.svg")) == OK)
	assert(image.save_png("res://assets/cover.png") == OK)
	assert(image.load("res://assets/gameplay.jpg") == OK)
	assert(image.save_png("res://assets/gameplay.png") == OK)
	quit()
