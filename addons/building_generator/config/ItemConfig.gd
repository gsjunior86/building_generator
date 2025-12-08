extends Resource

class_name ItemConfig

var positions: Array[Position3] = []

func _get_variations_for_model(model: String) -> Array[String]:
	var model_path = MiscConfig.misc_models_path + model + "/"
	var model_variants: Array[String] = []
	var dir = DirAccess.open(model_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.get_extension() == 'res':
				model_variants.append(model_path + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	return model_variants

func add_item_as_children(model: String, facade: Facade):	
	var model_variants = _get_variations_for_model(model)
	print(model_variants)
	pass
