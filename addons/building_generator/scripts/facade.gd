@tool
extends Node3D

class_name Facade

@export_group("General Properties")
## Mesh used by every floor/column instance of this facade.
## Loaded from the selected model's .res file and deep-duplicated so each
## facade owns its mesh and materials (see duplicate_mesh_with_materials()).
var mesh: ArrayMesh:
	set(value):
		var mesh_path: String = selected_model_path.path_join(model).path_join(model + ".res")  # or .tres, .obj, etc.
		if ResourceLoader.exists(mesh_path):
			mesh = duplicate_mesh_with_materials(load(mesh_path).duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as ArrayMesh)
		else:
			push_warning("Mesh not found at: " + mesh_path)
			mesh = null
		_apply_material_overrides()
		notify_property_list_changed()


## Mesh used by the floor-1 instances when a model from the style's
## optional "_ground" folder is selected (see [member ground_model]).
## Loaded and deep-duplicated like [member mesh]. Clears silently when no
## ground model is selected.
var ground_mesh: ArrayMesh:
	set(value):
		var mesh_path: String = selected_ground_model_path.path_join(ground_model).path_join(ground_model + ".res")  # or .tres, .obj, etc.
		if ResourceLoader.exists(mesh_path):
			ground_mesh = duplicate_mesh_with_materials(load(mesh_path).duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as ArrayMesh)
		else:
			if ground_model != "":
				push_warning("Ground mesh not found at: " + mesh_path)
			ground_mesh = null
		_apply_material_overrides()
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
## Number of columns in the facade grid (minimum 1). Increasing it calls
## add_columns(), decreasing it calls remove_columns(); afterwards the
## following facades are re-laid out via update_facades().
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
		if is_ready:
			update_facades()

## Country whose style set this facade uses. Changing it resets
## [member style] so a new style can be picked from that country's directory.
@export_enum("Brazil","Russia","Germany") var country: String = "Brazil":
	set(value):
		country = value
		style = ""
		notify_property_list_changed()
		


var misc: Dictionary = {} as Dictionary[String, bool]
## Per-surface material overrides (surface name → Material), applied to
## the facade's shared mesh and therefore to every floor/column instance.
## Editable in the inspector via the dynamic "materials/<surface>" slots.
var mesh_materials: Dictionary = {} as Dictionary[String, Material]
## Per-surface material overrides for the ground-floor mesh (surface
## name → Material). Editable via the dynamic "floor_materials/<surface>"
## slots, shown after the mesh materials.
var floor_materials: Dictionary = {} as Dictionary[String, Material]
var misc_config: MiscConfig = null
var is_building_parent: bool = true

## Handles the dynamic inspector properties.
## For "materials/<surface>": stores the override in [member materials] and
## applies it to the shared mesh; clearing the slot reloads the mesh to
## restore the original material.
## For "misc_items/<name>": toggling one on stores it in [member misc] and
## adds that item as a child of every column mesh; toggling it off removes
## it again (see ItemConfig.add_item_as_children).
func _set(property: StringName, value) -> bool:
	if Engine.is_editor_hint():
		if property.begins_with("mesh_materials/"):
			var surface_name := property.trim_prefix("mesh_materials/")
			if value == null:
				mesh_materials.erase(surface_name)
				# The mesh setter reloads the mesh from the model file,
				# restoring the original material before re-applying overrides
				if selected_model_path != "":
					self.mesh = mesh
			else:
				mesh_materials[surface_name] = value
				_apply_material_overrides()
			return true
		if property.begins_with("floor_materials/"):
			var surface_name := property.trim_prefix("floor_materials/")
			if value == null:
				floor_materials.erase(surface_name)
				if selected_ground_model_path != "":
					self.ground_mesh = ground_mesh
			else:
				floor_materials[surface_name] = value
				_apply_material_overrides()
			return true
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

## Returns the current value of a dynamic property: the stored override
## (or the mesh's current surface material) for "materials/<surface>",
## the toggle state for "misc_items/<name>", or null otherwise.
func _get(property: StringName):
	var prop := String(property)
	if prop.begins_with("mesh_materials/"):
		var surface_name := prop.get_slice("/", 1)
		if mesh_materials.has(surface_name):
			return mesh_materials[surface_name]
		if mesh != null:
			for i in mesh.get_surface_count():
				if mesh.surface_get_name(i) == surface_name:
					return mesh.surface_get_material(i)
		return null
	if prop.begins_with("floor_materials/"):
		var surface_name := prop.get_slice("/", 1)
		if floor_materials.has(surface_name):
			return floor_materials[surface_name]
		if ground_mesh != null:
			for i in ground_mesh.get_surface_count():
				if ground_mesh.surface_get_name(i) == surface_name:
					return ground_mesh.surface_get_material(i)
		return null
	if prop.begins_with("misc_items/"):
		var key := prop.get_slice("/", 1)
		return misc.get(key)
	return null
	
## Style within the selected [member country] (e.g. "art_deco").
## Listed as an enum by _get_property_list(); cleared when country changes.
var style: String = "":
	set(value):
		#if value:
			#var formatted_base_country = models_path.format([country])
			#dir = DirAccess.open(formatted_base_country + "/{0}".format([value]))
		style = value
		notify_property_list_changed()
		
## Model within the selected [member style]. Setting it resolves the
## model's .res file, loads it into [member mesh], then refreshes every
## floor/column instance via update_instances().
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

## Ground-floor model from the style's optional "_ground" folder. The
## ground floor is an extra floor below floor 1 (instances named floor_0)
## and follows the column count. Selecting "<Nothing>" removes it again.
var ground_model: String = "":
	set(value):
		ground_model = value
		if ground_model == "" or ground_model == "Nothing":
			ground_mesh = null
			remove_ground_instances()
		elif country and style:
			var dir_path = models_path.format([country]).path_join(style).path_join("_ground")
			if DirAccess.dir_exists_absolute(dir_path):
				var dir = DirAccess.open(dir_path)
				selected_ground_model_path = dir.get_current_dir()
				
				# Try to load mesh with better error handling
				var mesh_path = selected_ground_model_path.path_join(ground_model).path_join(ground_model + ".res")
				if ResourceLoader.exists(mesh_path):
					var loaded_mesh = load(mesh_path)
					if loaded_mesh is ArrayMesh:
						self.ground_mesh = loaded_mesh
					else:
						push_warning("Loaded resource is not an ArrayMesh: " + mesh_path)
				else:
					push_warning("Mesh file not found: " + mesh_path)
			# While the scene is loading, the saved children don't exist yet;
			# _ready() calls add_ground_instances() instead
			if is_inside_tree():
				add_ground_instances()
		
		update_instances()
		notify_property_list_changed()
var selected_ground_model_path: String = ""

## Builds the dynamic inspector properties: the style enum for the chosen
## country, the model enum for the chosen style, a read-only mesh preview,
## one "mesh_materials/<surface>" material slot per mesh surface, the
## ground_model enum plus "floor_materials/<surface>" slots when the style
## has a "_ground" folder, and one "misc_items/<name>" toggle per misc
## item the model supports.
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
			
		if mesh != null:
			for i in mesh.get_surface_count():
				var surface_name := mesh.surface_get_name(i)
				if surface_name == "":
					surface_name = "surface_" + str(i)
				props.append({
					"name": "mesh_materials/" + surface_name,
					"type": TYPE_OBJECT,
					"hint": PROPERTY_HINT_RESOURCE_TYPE,
					"hint_string": "Material",
					"usage": PROPERTY_USAGE_DEFAULT
				})
				
		if style != "":
			var ground_models_options := _get_model_for_styles(country, style, true)
			if ground_models_options.size() > 0:
				ground_models_options.push_front("Nothing")
				if ground_model == "" or not ground_models_options.has(ground_model):
					self.ground_model = "Nothing"
				var model_hint_string := ",".join(ground_models_options)
				props.append({
					"name": "ground_model",
					"type": TYPE_STRING,
					"hint": PROPERTY_HINT_ENUM,
					"hint_string": model_hint_string,
					"usage": PROPERTY_USAGE_DEFAULT
				})
			elif ground_model != "":
				# The selected style has no "_ground" folder
				self.ground_model = ""
			
		if ground_mesh != null:
			props.append({
				"name": "ground_mesh",
				"type": TYPE_OBJECT,
				"hint": PROPERTY_HINT_RESOURCE_TYPE,
				"hint_string": "ArrayMesh",
				"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
			})
			for i in ground_mesh.get_surface_count():
				var surface_name := ground_mesh.surface_get_name(i)
				if surface_name == "":
					surface_name = "surface_" + str(i)
				props.append({
					"name": "floor_materials/" + surface_name,
					"type": TYPE_OBJECT,
					"hint": PROPERTY_HINT_RESOURCE_TYPE,
					"hint_string": "Material",
					"usage": PROPERTY_USAGE_DEFAULT
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
	

## Returns the names of the style directories available under the given
## country, or an empty list if the country directory can't be opened.
func _get_styles_for_country(country_name: String) -> Array[String]:
	var dir = DirAccess.open(models_path.format([country_name]))
	var ret :Array[String] = []
	if dir:
		for d in dir.get_directories():
			ret.append(d)
	return ret

## Returns the sorted names of the model directories available under the
## given country/style pair, or under its "_ground" subfolder when
## [param ground] is true. Directories starting with "_" are only listed
## in ground mode. A missing "_ground" folder is normal and
## returns an empty list silently; a missing model folder warns.
func _get_model_for_styles(country_name: String, style: String, ground: bool = false) -> Array[String]:
	var formatted_base_country = models_path.format([country_name])
	var dir_path = formatted_base_country.path_join(style).path_join("_ground") if ground else formatted_base_country.path_join(style) 
	if not DirAccess.dir_exists_absolute(dir_path):
		if not ground:
			push_warning("Directory does not exist: " + dir_path)
		return []
		
	var dir = DirAccess.open(dir_path)
	var ret: Array[String] = []
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir() and not file_name.begins_with(".") and (ground or not file_name.begins_with("_")):
				ret.append(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
		ret.sort()
	return ret


static var name_format = "column_{0}_floor_{1}"
var is_ready = true



## Connects the tree_entered signal to initialize() the first time this
## node enters the tree.
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
	add_ground_instances()
	var my_index := get_index()
	if not is_new or my_index == 0:
		return
	var lastFacade: Facade = get_parent().get_child(my_index - 1) as Facade
	if lastFacade == null:
		return
	self.position = Vector3(self.position.x, self.position.y, lastFacade.get_end_z() - get_start_z())
		
		
## Returns true if a direct child with the given name exists.
func _has_children(name: String) -> bool:
	for child in get_children():
		if child.name == name:
			return true
	return false;


## Deep-duplicates a mesh and each of its surface materials, so edits to
## one facade's mesh or materials never affect other facades built from
## the same source resource.
func duplicate_mesh_with_materials(original_mesh: Mesh) -> Mesh:
	var unique_mesh: ArrayMesh = original_mesh.duplicate(true) # deep copy

	# Ensure every surface material is unique
	for surface in range(unique_mesh.get_surface_count()):
		var mat := unique_mesh.surface_get_material(surface)
		if mat:
			unique_mesh.surface_set_material(surface, mat.duplicate())
	return unique_mesh

## Applies the stored material overrides to both meshes, matching surfaces
## by name: [member mesh_materials] to [member mesh] and
## [member floor_materials] to [member ground_mesh].
func _apply_material_overrides() -> void:
	_apply_materials_to(mesh, mesh_materials)
	_apply_materials_to(ground_mesh, floor_materials)

## Applies the given material overrides (surface name → Material) to the
## target mesh. Overrides whose surface doesn't exist in the mesh
## (e.g. after a model swap) are ignored.
func _apply_materials_to(target: ArrayMesh, overrides: Dictionary) -> void:
	if target == null:
		return
	for i in target.get_surface_count():
		var surface_name := target.surface_get_name(i)
		if overrides.has(surface_name):
			target.surface_set_material(i, overrides[surface_name])

## Returns the mesh used by the given floor: the ground mesh for floor 0
## when one is selected, the main mesh otherwise (floors are 1-based).
func _mesh_for_floor(floor_num: int) -> ArrayMesh:
	return ground_mesh if floor_num == 0 and ground_mesh != null else mesh

## Returns the model path stored as metadata on each instance, used by
## Building.export_mesh() to group instances by model.
func _model_path_for_floor(floor_num: int) -> String:
	if floor_num == 0 and ground_mesh != null:
		return country + "/" + style + "/_ground/" + ground_model
	return country + "/" + style + "/" + model

## Returns the Y position of the given floor. The optional ground floor
## (floor 0) sits at 0; regular floors stack on top of it, so with a
## ground floor present, floor 1 starts at the ground mesh's height.
func _floor_y(floor_num: int) -> float:
	if floor_num <= 0:
		return 0.0
	var base := ground_mesh.get_aabb().size.y if ground_mesh != null else 0.0
	return base + (floor_num - 1) * mesh.get_aabb().size.y


## Removes the top [param n] floors from every column of the grid.
## Called by Building when its floor count decreases.
func remove_floor(n: int):
	var fl = (get_parent() as Building).floors
	var offset = abs(fl - n)
	for column in columns:
		for floor in fl:
			if floor+1 > offset:
				var name = name_format.format([column,floor+1])
				remove_child(get_node(name))
	notify_property_list_changed()

## Removes the last [param n] columns (across every floor) from the grid,
## including their ground-floor instances.
func remove_columns(n: int):
	var fl = (get_parent() as Building).floors
	var offset = abs(columns - n)
	for column in columns:
		for floor in fl:
			if column >= offset:
				var name = name_format.format([column,floor+1])
				remove_child(get_node(name))
	remove_ground_instances(offset)
	notify_property_list_changed()			
		
	
	#for child in childrens:
		#if count < n:
			#remove_child(child)
			#count+=1
			
## Adds mesh instances up to [param floor_count] floors — starting at
## floor 1 on the first build, or at the building's current floor count
## when floors are added later. Floor 1 uses the ground mesh when one is
## selected (see [member ground_model]). Instances are named with
## name_format and positioned by mesh size; ones that already exist
## (e.g. restored from a saved scene) are left untouched.
func add_floors(floor_count: int, first_time: bool = false):
	#if get_child_count() == 0:
		#floor_count = 1
	if !mesh == null:
		for floor in range(1 if first_time else (get_parent() as Building).floors, floor_count+1):
			var floor_mesh := _mesh_for_floor(floor)
			var width := floor_mesh.get_aabb().size.z
			for col in columns:
				var name = name_format.format([col,floor])
				var floor3D = MeshInstance3D.new()
				floor3D.name = name
				floor3D.set_meta("model", _model_path_for_floor(floor))
				floor3D.set_mesh(floor_mesh)
				floor3D.position = Vector3(0, _floor_y(floor), col * width)
				var node = get_node_or_null(name)
				if node == null:
					add_child(floor3D)
					#add_child(floor3D, false, Node.INTERNAL_MODE_BACK)
					if Engine.is_editor_hint():
						floor3D.owner = get_tree().edited_scene_root
		
	notify_property_list_changed()
		
## Adds columns from the current column count up to [param col_count],
## creating one mesh instance per floor in each new column. Floor-1
## instances use the ground mesh when one is selected.
func add_columns(col_count: int):
	if !mesh == null:
		for col in range(columns, col_count):
			for floor in (get_parent() as Building).floors:
				var floor_num := floor + 1
				var floor_mesh := _mesh_for_floor(floor_num)
				var width := floor_mesh.get_aabb().size.z
				var name = name_format.format([col,floor_num])
				var floor3D = MeshInstance3D.new()
				floor3D.set_meta("model", _model_path_for_floor(floor_num))
				floor3D.name = name
				floor3D.set_mesh(floor_mesh)
				floor3D.position = Vector3(0, _floor_y(floor_num), col * width)
				add_child(floor3D)
				#add_child(floor3D, false, Node.INTERNAL_MODE_BACK)
				if Engine.is_editor_hint():
					floor3D.owner = get_tree().edited_scene_root
				notify_property_list_changed()
		add_ground_instances()
	
## Adds one ground-floor instance (floor 0) per column, skipping ones that
## already exist (e.g. restored from a saved scene). Called when a ground
## model is selected and after columns are added, so the ground floor
## always follows the column count.
func add_ground_instances():
	if ground_mesh == null:
		return
	var width := ground_mesh.get_aabb().size.z
	for col in columns:
		var name = name_format.format([col, 0])
		if get_node_or_null(name) != null:
			continue
		var floor3D = MeshInstance3D.new()
		floor3D.name = name
		floor3D.set_meta("model", _model_path_for_floor(0))
		floor3D.set_mesh(ground_mesh)
		floor3D.position = Vector3(0, 0, col * width)
		add_child(floor3D)
		if Engine.is_editor_hint():
			floor3D.owner = get_tree().edited_scene_root

## Removes the ground-floor (floor 0) instances, optionally only from
## [param from_col] upwards (used when columns are removed).
func remove_ground_instances(from_col: int = 0):
	for col in range(from_col, columns):
		var node = get_node_or_null(name_format.format([col, 0]))
		if node != null:
			remove_child(node)
	notify_property_list_changed()
	
		
## Swaps the mesh of every floor/column instance and recomputes each
## instance's grid position using the new mesh's size. When a ground mesh
## is selected, the ground (floor 0) instances use it and the regular
## floors stack on top of its height.
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
	for floor in range(0 if ground_mesh != null else 1, building.floors + 1):
		var floor_mesh := _mesh_for_floor(floor)
		var width := floor_mesh.get_aabb().size.z
		for col in columns:
			var node := get_node_or_null(name_format.format([col, floor])) as MeshInstance3D
			if node == null:
				continue
			node.set_mesh(floor_mesh)
			node.set_meta("model", _model_path_for_floor(floor))
			node.position = Vector3(0, _floor_y(floor), col * width)
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
## facade's last column. Both the top floor and the ground floor (when
## present) are considered, since their meshes may differ in width.
## Falls back to the facade's own position when the grid or mesh isn't
## available yet (e.g. while a scene is still loading).
func get_end_z() -> float:
	var building := get_parent() as Building
	if building == null:
		return position.z
	var end_z := position.z
	var floors_to_check := [0, building.floors] if ground_mesh != null else [building.floors]
	for floor_num in floors_to_check:
		var last_mesh := get_node_or_null(name_format.format([columns - 1, floor_num])) as MeshInstance3D
		if last_mesh != null and last_mesh.mesh != null:
			end_z = max(end_z, position.z + last_mesh.position.z + last_mesh.mesh.get_aabb().end.z)
	return end_z

## Returns the Z coordinate, in local space, where this facade's mesh
## geometry begins. Zero when the mesh origin sits at its edge; otherwise
## this offset is subtracted when positioning so facades stay flush.
func get_start_z() -> float:
	return mesh.get_aabb().position.z if mesh != null else 0.0
	
			
			

## Shows an editor warning when this node is not a child of a Building,
## in which case its floors are stripped and it is marked as not ready.
func _get_configuration_warnings():
	var warnings = PackedStringArray()
	is_ready = true
	if not is_instance_valid(get_parent()) or not (get_parent() is Building):
		is_ready = false
		remove_floor(1)
		warnings.append("This node must be a child of a Building node.")
	request_ready()
	return warnings
		
## Callback connected to tree_entered; currently a no-op kept as an
## extension point.
func initialize():
	pass
