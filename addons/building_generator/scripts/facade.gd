@tool
extends Node3D

class_name Facade

@export_group("General Properties")
var mesh: ArrayMesh:
	set(value):
		var mesh_path: String = selected_model_path.path_join(model).path_join(model + ".res")  # or .tres, .obj, etc.
		if ResourceLoader.exists(mesh_path):
			mesh = duplicate_mesh_with_materials(load(mesh_path).duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as ArrayMesh)
		else:
			push_warning("Mesh not found at: " + mesh_path)
			mesh = null
		notify_property_list_changed()


var models_path:= "res://addons/building_generator/models/{0}"
@export var floors: int = 1:
	set(value):
		value = max(1,value)
		if is_ready:
			if value > floors:
				add_floors(value)
			elif value < floors:
				remove_floor(abs(floors - value))
		floors = value
@export var columns: int = 1:
	set(value):
		value = max(1,value)
		if is_ready:
			if value > columns:
				add_columns(value)
				pass
			elif value < columns:
				remove_columns(abs(columns - value))
		columns = value

@export_enum("Brazil","Russia","Germany") var country: String = "Brazil":
	set(value):
		country = value
		style = ""
		notify_property_list_changed()
		


var misc: Dictionary = {} as Dictionary[String, bool]
var misc_config: MiscConfig = null
var is_building_parent: bool = true

func _set(property: StringName, value) -> bool:
	if Engine.is_editor_hint():
		var key = property.trim_prefix("misc_items/")
		if(value == null):
			return false		
		if property.begins_with("misc_items/") && ((misc != null && misc.is_empty()) || (!misc.has(key) || misc[key] == false)):
			misc[key] = value
			if(misc_config != null):
				misc_config.sub_configs[key].add_item_as_children(key, self)
			return true
		elif property.begins_with("misc_items/") && (misc_config != null && misc.has(key)):
			misc[key] = value
			misc_config.sub_configs[key].add_item_as_children(key, self,true)
			return false
	
	
	return false

func _get(property: StringName):
	var prop := String(property)
	if prop.begins_with("misc_items/"):
		var key := prop.get_slice("/", 1)
		return misc.get(key)
	return null
	
var style: String = "":
	set(value):
		#if value:
			#var formatted_base_country = models_path.format([country])
			#dir = DirAccess.open(formatted_base_country + "/{0}".format([value]))
		style = value
		notify_property_list_changed()
		
var model: String = "":
	set(value):
		model = value
		if country and style and model:
			var formatted_base_country = models_path.format([country])
			var dir_path = formatted_base_country.path_join(style)
			if DirAccess.dir_exists_absolute(dir_path):
				var dir = DirAccess.open(dir_path)
				selected_model_path = dir.get_current_dir()
				
				# Try to load mesh with better error handling
				var mesh_path = selected_model_path.path_join(model).path_join(model + ".res")
				if ResourceLoader.exists(mesh_path):
					var loaded_mesh = load(mesh_path)
					if loaded_mesh is ArrayMesh:
						self.mesh = loaded_mesh
					else:
						push_warning("Loaded resource is not an ArrayMesh: " + mesh_path)
				else:
					push_warning("Mesh file not found: " + mesh_path)
			else:
				push_warning("Style directory not found: " + dir_path)
		
		update_instances()
		notify_property_list_changed()
var selected_model_path: String = ""

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	# --- Exported enum for style (only visible when Brazil is selected) ---
	if is_ready:
		if country != "None":
			var style_options := _get_styles_for_country(country)
			if style_options.size() > 0:
				if style == "":
					style = style_options.get(0)
				var styles_hint_string := ",".join(style_options)\
					 if style_options.size() > 0 else "None"
				props.append({
						"name": "style",
						"type": TYPE_STRING,
						"hint": PROPERTY_HINT_ENUM,
						"hint_string": styles_hint_string,
						"usage": PROPERTY_USAGE_DEFAULT
					})
			
		
		
		if style != "":
			var models_options := _get_model_for_styles(country, style)
			if models_options.size() > 0:
				if model == "":
					self.model = models_options.get(0)
				var model_hint_string := ",".join(models_options)
				props.append({
					"name": "model",
					"type": TYPE_STRING,
					"hint": PROPERTY_HINT_ENUM,
					"hint_string": model_hint_string,
					"usage": PROPERTY_USAGE_DEFAULT
				})
				
		if model != "":
			props.append({
				"name": "mesh",
				"type": TYPE_OBJECT,
				"hint": PROPERTY_HINT_RESOURCE_TYPE,
				"hint_string": "ArrayMesh",
				#"usage": PROPERTY_USAGE_DEFAULT
				"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
			})
			
			
		if model !="" and style != "" and country != "None":
			misc_config = MiscConfig.new().load_config(country + "/" + style + "/" + model)
			
			if misc_config != null:
				for item in misc_config.sub_configs.keys():
					props.append({
							"name": "misc_items/" + item,
							"type": TYPE_BOOL,
							"usage": PROPERTY_USAGE_DEFAULT
						})
				

	return props
	

func _get_styles_for_country(country_name: String) -> Array[String]:
	var dir = DirAccess.open(models_path.format([country_name]))
	var ret :Array[String] = []
	if dir:
		for d in dir.get_directories():
			ret.append(d)
	return ret

func _get_model_for_styles(country_name: String, style: String) -> Array[String]:
	var formatted_base_country = models_path.format([country_name])
	var dir_path = formatted_base_country.path_join(style)
	
	if not DirAccess.dir_exists_absolute(dir_path):
		push_warning("Directory does not exist: " + dir_path)
		return []
		
	var dir = DirAccess.open(dir_path)
	var ret: Array[String] = []
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir() and not file_name.begins_with("."):
				ret.append(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
		ret.sort()
	return ret


static var name_format = "column_{0}_floor_{1}"
var is_ready = true



func _enter_tree():
	if not tree_entered.is_connected(initialize):
		tree_entered.connect(initialize)
	
func _ready() -> void:
	if get_child_count() == 0:
		add_floors(floors)
		
		
func _has_children(name: String) -> bool:
	for child in get_children():
		if child.name == name:
			return true
	return false;


func duplicate_mesh_with_materials(original_mesh: Mesh) -> Mesh:
	var unique_mesh: ArrayMesh = original_mesh.duplicate(true) # deep copy

	# Ensure every surface material is unique
	for surface in range(unique_mesh.get_surface_count()):
		var mat := unique_mesh.surface_get_material(surface)
		if mat:
			unique_mesh.surface_set_material(surface, mat.duplicate())
	return unique_mesh


func remove_floor(n: int):
	var offset = abs(floors - n)
	var fl = floors
	for column in columns:
		for floor in fl:
			if floor+1 > offset:
				var name = name_format.format([column,floor+1])
				remove_child(get_node(name))
	notify_property_list_changed()

func remove_columns(n: int):
	var offset = abs(columns - n)
	var fl = floors
	for column in columns:
		for floor in fl:
			if column >= offset:
				var name = name_format.format([column,floor+1])
				remove_child(get_node(name))
	notify_property_list_changed()			
		
	
	#for child in childrens:
		#if count < n:
			#remove_child(child)
			#count+=1
			
func add_floors(floor_count: int):
	if get_child_count() == 0:
		floor_count = 1
	if !mesh == null:
		for floor in range(floors, floor_count+1):
			for col in columns:
				var name = name_format.format([col,floor])
				var floor3D = MeshInstance3D.new()
				floor3D.name = name
				floor3D.set_meta("model",country+"/"+style+"/"+model)
				floor3D.set_mesh(mesh)
				var height = floor3D.mesh.get_aabb().size.y
				var width =  floor3D.mesh.get_aabb().size.z
				floor3D.position = Vector3(0,(floor-1) * height,col * width)
				var node = get_node_or_null(name)
				if node == null:
					add_child(floor3D)
					if Engine.is_editor_hint():
						floor3D.owner = get_tree().edited_scene_root
		
	notify_property_list_changed()
		
func add_columns(col_count: int):
	if !mesh == null:
		for col in range(columns, col_count):
			for floor in floors:
				var name = name_format.format([columns,floor+1])
				var floor3D = MeshInstance3D.new()
				floor3D.set_meta("model",country+"/"+style+"/"+model)
				floor3D.name = name
				floor3D.set_mesh(mesh)
				var height = floor3D.mesh.get_aabb().size.y
				var width =  floor3D.mesh.get_aabb().size.z
				floor3D.position = Vector3(0,floor * height,col * width)
				add_child(floor3D)
				if Engine.is_editor_hint():
					floor3D.owner = get_tree().edited_scene_root
				notify_property_list_changed()
	
		
func update_instances():
	var childrens = get_children()
	for child in childrens:
		if child is MeshInstance3D:
			var instance3d = child as MeshInstance3D
			instance3d.set_mesh(mesh)
			instance3d.set_meta("model",country+"/"+style+"/"+model)
			child = instance3d
			

func _get_configuration_warnings():
	var warnings = PackedStringArray()
	is_ready = true
	if not is_instance_valid(get_parent()) or not (get_parent() is Building):
		is_ready = false
		remove_floor(1)
		warnings.append("This node must be a child of a Building node.")
	request_ready()
	return warnings
		
func initialize():
	pass
