@tool
extends Node3D

@export_group("General Properties")
static var height = 3

var mesh: ArrayMesh:
	set(value):
		mesh = value
		notify_property_list_changed()

var models_path:= "res://addons/building_generator/models/{0}"
@export var floors: int = 1:
	set(value):
		if is_ready:
			if value > floors:
				add_floors(value)
			elif value < floors:
				remove_floor(abs(get_child_count() - value))
		floors = value


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
		mesh =  load(selected_model_path + "/" + model + "/" + model + ".res") as ArrayMesh
		update_instances()
		notify_property_list_changed()
var selected_model_path: String = ""
	
func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	# --- Exported enum for style (only visible when Brazil is selected) ---
	if country != "None":
		var style_options := _get_styles_for_country(country)
		if style_options.size() > 0:
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
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_EDITOR_INSTANTIATE_OBJECT
		})

	return props
	
func set_mesh(value: ArrayMesh):
	mesh = value

func get_mesh() -> ArrayMesh:
	return mesh

	

func _get_styles_for_country(country_name: String) -> Array[String]:
	var dir = DirAccess.open(models_path.format([country_name]))
	var ret :Array[String] = []
	if dir:
		for d in dir.get_directories():
			ret.append(d)
	return ret

func _get_model_for_styles(country_name: String, style: String) -> Array[String]:
	var formatted_base_country = models_path.format([country_name])
	var dir = DirAccess.open(formatted_base_country + "/{0}".format([style]))
	selected_model_path = dir.get_current_dir()
	var ret :Array[String] = []
	if dir:
		for d in dir.get_directories():
			#model_path = dir.get_current_dir() + "/" + d + "/" + d + ".res"
			ret.append(d)
	return ret


static var name_format = "column_{0}_floor_{1}"
var is_ready = false
@onready
var mesh_reference = "res://addons/building_generator/" + \
"models/Brazil/art_deco/balcony_01/balcony_01.res"



func _enter_tree():
	tree_entered.connect(initialize)
	
func _ready() -> void:
	if get_child_count() == 0:
		add_floors((floors-1) * height)
	is_ready = true	#initialize with one column and floor
		
		
func _has_children(name: String) -> bool:
	for child in get_children():
		if child.name == name:
			return true
	return false;

func remove_floor(n: int):
	var childrens = get_children()
	childrens.reverse()
	var count = 0
	for child in childrens:
		if count < n:
			remove_child(child)
			count+=1
			
func add_floors(n: int):
	var offset = n - get_child_count()
	var last_index = get_child_count() + 1
	for i in offset:
		var name = name_format.format([1,last_index])
		var floor3D = MeshInstance3D.new()
		floor3D.name = name
		floor3D.set_mesh(load(mesh_reference))
		floor3D.position = Vector3(0,(last_index-1) * height,0)
		add_child(floor3D)
		if Engine.is_editor_hint():
			floor3D.owner = get_tree().edited_scene_root
		notify_property_list_changed()
		last_index+=1
		
func update_instances():
	var childrens = get_children()
	for child in childrens:
		if child is MeshInstance3D:
			var instance3d = child as MeshInstance3D
			instance3d.set_mesh(mesh)
			child = instance3d
		

	
func initialize():
	print('initialization')
