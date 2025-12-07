extends Resource

class_name ModelConfig

var sub_configs: Dictionary[String, ItemConfig] = {}
var path: String = "res://addons/building_generator/config/misc.json"

func load_config(model_key: String) -> ModelConfig:
	# Load JSON file
	var file = FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())

	if not data.has(model_key):
		return null

	var model_data = data[model_key]

	# Create ModelConfig instance
	var model_config := ModelConfig.new()

	# Iterate over each sub-object
	for sub_name in model_data.keys():
		var sub_dict = model_data[sub_name]
		var item_config := ItemConfig.new()
		
		for pos_dict in sub_dict["positions"]:
			var pos := Position3.new()
			pos.x = pos_dict["x"]
			pos.y = pos_dict["y"]
			pos.z = pos_dict["z"]
			item_config.positions.append(pos)

		model_config.sub_configs[sub_name] = item_config

	return model_config
