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

func add_item_as_children(model_name: String, facade: Facade, delete: bool = false):	
	var model_variants = _get_variations_for_model(model_name)
	var rng = RandomNumberGenerator.new()
	for child in facade.get_children():
		var rnd_var = rng.randi_range(0, model_variants.size()-1)
		var variant = model_variants[rnd_var]
		
		var rnd_pos = rng.randi_range(0, positions.size()-1)
		var pos = positions[rnd_pos]
		
		var vc3pos = Vector3(pos.x,pos.y,pos.z)
	
		if !delete && child.get_node_or_null(model_name) == null:
			var mesh: MeshInstance3D = MeshInstance3D.new()
			mesh.name = model_name
			mesh.mesh = load(variant) as ArrayMesh
			mesh.position = vc3pos
			child.add_child(mesh)
			if Engine.is_editor_hint():
					mesh.owner = facade.get_tree().edited_scene_root
		elif delete:
			var node = child.get_node_or_null(model_name)
			child.remove_child(node)
	notify_property_list_changed()
	
	pass
