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
#@export var floors: int = 1:
	#set(value):
		#value = max(1,value)
		#if is_ready:
			#if value > (get_parent() as Building).floors:
				#add_floors(value)
			#elif value < (get_parent() as Building).floors:
				#print('removing...')
				#remove_floor(abs((get_parent() as Building).floors - value))
		#floors = value
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
	
## Builds the floor/column grid and, for a freshly added facade only,
## positions it flush against the previous facade along Z.
## Facades loaded from a saved scene already have their children and a
## saved position, so the offset is skipped for them; otherwise every
## scene reload would keep accumulating a new offset on top of the saved one.
func _ready() -> void:
	var is_new := get_child_count() == 0
	add_floors((get_parent() as Building).floors, true)
	var my_index := get_index()
	if not is_new or my_index == 0:
		return
	var lastFacade: Facade = get_parent().get_child(my_index - 1) as Facade
	if lastFacade == null:
		return
	self.position = Vector3(self.position.x, self.position.y, lastFacade.get_end_z() - get_start_z())
		
		
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
	var fl = (get_parent() as Building).floors
	var offset = abs(fl - n)
	for column in columns:
		for floor in fl:
			if floor+1 > offset:
				var name = name_format.format([column,floor+1])
				remove_child(get_node(name))
	notify_property_list_changed()

func remove_columns(n: int):
	var fl = (get_parent() as Building).floors
	var offset = abs(columns - n)
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
			
func add_floors(floor_count: int, first_time: bool = false):
	#if get_child_count() == 0:
		#floor_count = 1
	if !mesh == null:
		for floor in range(1 if first_time else (get_parent() as Building).floors, floor_count+1):
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
					#add_child(floor3D, false, Node.INTERNAL_MODE_BACK)
					if Engine.is_editor_hint():
						floor3D.owner = get_tree().edited_scene_root
		
	notify_property_list_changed()
		
func add_columns(col_count: int):
	if !mesh == null:
		for col in range(columns, col_count):
			for floor in (get_parent() as Building).floors:
				var name = name_format.format([columns,floor+1])
				var floor3D = MeshInstance3D.new()
				floor3D.set_meta("model",country+"/"+style+"/"+model)
				floor3D.name = name
				floor3D.set_mesh(mesh)
				var height = floor3D.mesh.get_aabb().size.y
				var width =  floor3D.mesh.get_aabb().size.z
				floor3D.position = Vector3(0,floor * height,col * width)
				add_child(floor3D)
				#add_child(floor3D, false, Node.INTERNAL_MODE_BACK)
				if Engine.is_editor_hint():
					floor3D.owner = get_tree().edited_scene_root
				notify_property_list_changed()
	
		
## Swaps the mesh of every floor/column instance and recomputes each
## instance's grid position using the new mesh's size.
## The repositioning is needed because instance positions are derived from
## the mesh width/height: without it, picking a wider or narrower mesh
## would leave gaps or overlaps inside this facade. Finishes by calling
## update_facades() so the following facades stay flush against this one.
func update_instances():
	if mesh == null:
		return
	var building := get_parent() as Building
	if building == null:
		return
	var height: float = mesh.get_aabb().size.y
	var width: float = mesh.get_aabb().size.z
	for floor in range(1, building.floors + 1):
		for col in columns:
			var node := get_node_or_null(name_format.format([col, floor])) as MeshInstance3D
			if node == null:
				continue
			node.set_mesh(mesh)
			node.set_meta("model", country + "/" + style + "/" + model)
			node.position = Vector3(0, (floor - 1) * height, col * width)
	update_facades()
	
## Re-lays out every facade that comes after this one in the parent
## Building, placing each flush against its predecessor's far edge.
## This is a full re-layout rather than shifting facades by the width
## difference, so it stays correct no matter what changed (mesh size,
## column count, child order) and running it twice is a no-op.
func update_facades() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var prev: Facade = self
	for i in range(get_index() + 1, parent.get_child_count()):
		var next := parent.get_child(i) as Facade
		if next == null:
			continue
		next.position = Vector3(next.position.x, next.position.y, prev.get_end_z() - next.get_start_z())
		prev = next

## Returns the Z coordinate, in parent space, of the far edge of this
## facade's last column. Falls back to the facade's own position when the
## grid or mesh isn't available yet (e.g. while a scene is still loading).
func get_end_z() -> float:
	var building := get_parent() as Building
	if building == null:
		return position.z
	var last_index := columns * building.floors - 1
	if get_child_count() <= last_index:
		return position.z
	var last_mesh := get_child(last_index) as MeshInstance3D
	if last_mesh == null or last_mesh.mesh == null:
		return position.z
	return position.z + last_mesh.position.z + last_mesh.mesh.get_aabb().end.z

## Returns the Z coordinate, in local space, where this facade's mesh
## geometry begins. Zero when the mesh origin sits at its edge; otherwise
## this offset is subtracted when positioning so facades stay flush.
func get_start_z() -> float:
	return mesh.get_aabb().position.z if mesh != null else 0.0
	
			
			

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
