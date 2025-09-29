@tool
extends Node3D

@export_group("General Properties")

#@export var materials: Array[BaseMaterial3D] =[]

var next_move = 0
@export var floors: int = 1:
	set(value):
		floors = value
		add_instance()
#@export_tool_button("Add", "Callable") var add = add_instance

func _enter_tree():
	tree_entered.connect(initialize)
	
	
func add_instance():
	var instance3D = MeshInstance3D.new()
	instance3D.set_mesh(load("res://addons/building_generator/models/brazil/copacabana/window_01/window_01.res"))
	#materials.resize(instance3D.get_surface_override_material_count())
	instance3D.position = Vector3(0,next_move,0)
	add_child(instance3D)
	if Engine.is_editor_hint():
		instance3D.owner = get_tree().edited_scene_root
	
	next_move+= 3
	notify_property_list_changed()
	print("Instance added: ", instance3D)
	

	
func initialize():
	print('initialization')
