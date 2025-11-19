@tool
extends Node3D

@export_group("General Properties")



var mesh: ArrayMesh:
	set(value):
		if(get_child_count() == 0):
			var mesh_path = selected_model_path.path_join(model).path_join(model + ".res")  # or .tres, .obj, etc.
			if ResourceLoader.exists(mesh_path):
				mesh = load(mesh_path).duplicate(true) as ArrayMesh
			else:
				push_warning("Mesh not found at: " + mesh_path)
				mesh = null
		else:
			mesh = value
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

@export_enum("Brazil","Russia") var country: String = "Brazil":
	set(value):
		country = value
		style = ""
		notify_property_list_changed()
	
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
	return ret


static var name_format = "column_{0}_floor_{1}"
var is_ready = false



func _enter_tree():
	if not tree_entered.is_connected(initialize):
		tree_entered.connect(initialize)
	
func _ready() -> void:
	if get_child_count() == 0:
		print(floors)
		add_floors(floors)
	is_ready = true	#initialize with one column and floor
		
		
func _has_children(name: String) -> bool:
	for child in get_children():
		if child.name == name:
			return true
	return false;

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
	for floor in range(floors, floor_count+1):
		for col in columns:
			var name = name_format.format([col,floor])
			var floor3D = MeshInstance3D.new()
			floor3D.name = name
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
	for col in range(columns, col_count):
		for floor in floors:
			var name = name_format.format([columns,floor+1])
			var floor3D = MeshInstance3D.new()
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
			child = instance3d
		

	
func initialize():
	print('initialization')
