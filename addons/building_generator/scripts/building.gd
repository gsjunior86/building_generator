@tool
extends Node3D

class_name Building

var is_ready = true

## Number of floors of the building (minimum 1). Changing it adds floors
## to or removes floors from every child Facade.
@export var floors: int = 1:
	set(value):
		value = max(1,value)
		if is_ready:
			if value > floors:
				_manage_child_facade_floors(value, true)
			elif value < floors:
				print('delete')
				_manage_child_facade_floors(abs(floors-value), false)
		floors = value

@export_group("Visibility Range")

@export_range(0,1000) var begin: int = 150
@export_range(0,1000) var begin_margin: int = 5

@export_range(0,1000) var end: int = 150
@export_range(0,1000) var end_margin: int = 5

## Bakes the building into a static, export-friendly copy added next to
## this node: one MultiMeshInstance3D per distinct model (with visibility
## range fading), an LOD box mesh, and a StaticBody3D collision box, all
## derived from the combined bounds of the facades.
func export_mesh() -> void:
	
	var building_node = Node3D.new()
	get_parent().add_child(building_node)
	building_node.name = self.name
	building_node.global_transform = global_transform
	building_node.global_scale(self.scale)
	
	
	var facades: Array[Facade] = []
	for child in get_children(true):
		if child is Facade:
			facades.append(child as Facade)
	
	var distinct_objects: Dictionary[String,Array] = {}
	for facade in facades:
		for mesh in facade.get_children(true):
			var key = (mesh as MeshInstance3D).get_meta("model")
			if not distinct_objects.has(key):
				distinct_objects[key] = []
			distinct_objects[key].append(mesh)
			for item in mesh.get_children():
				var key_item = (item as MeshInstance3D).get_meta("model")	
				if not distinct_objects.has(key_item):
					distinct_objects[key_item] = []
				distinct_objects[key_item].append(item)
	for key in distinct_objects.keys():
		print(key)
		var node_group = distinct_objects[key]
		
		var multimesh = MultiMesh.new()
		multimesh.mesh = node_group[0].mesh
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.instance_count = node_group.size()
		
		for i in range(node_group.size()):
			var transform = building_node.global_transform.affine_inverse() * node_group[i].global_transform
			multimesh.set_instance_transform(i, transform)
		
		var multimesh_instance = MultiMeshInstance3D.new()
		multimesh_instance.multimesh = multimesh
		multimesh_instance.visibility_range_end = end
		multimesh_instance.visibility_range_end_margin = end_margin
		multimesh_instance.visibility_range_fade_mode = 1
		multimesh_instance.name = "Multimesh_" + key
		building_node.add_child(multimesh_instance)
		if Engine.is_editor_hint():
			multimesh_instance.owner = get_tree().edited_scene_root	
	
	var utils = Utils.new()
	var aabb: AABB = utils.calculate_spatial_bounds(self,true)
	
	# add the LOD box
	var lod_box = MeshInstance3D.new()
	building_node.add_child(lod_box)
	lod_box.name = "lod_box"
	var lod_box_array_mesh = BoxMesh.new()
	lod_box_array_mesh.size = aabb.size
	lod_box.mesh = lod_box_array_mesh
	lod_box.position = aabb.get_center()
	lod_box.visibility_range_begin = begin
	lod_box.visibility_range_begin_margin = begin_margin
	lod_box.visibility_range_fade_mode = 1
	
	#add the collision shade
	var static_body = StaticBody3D.new()
	building_node.add_child(static_body)
	static_body.name = 'staticBody3d'
	var collision_shape = CollisionShape3D.new()
	static_body.add_child(collision_shape)
	collision_shape.name ='collision'
	var box_shape_collision = BoxShape3D.new()
	box_shape_collision.size = aabb.size
	collision_shape.position = aabb.get_center()
	collision_shape.shape = box_shape_collision	
	

	
	if Engine.is_editor_hint():
		collision_shape.owner = get_tree().edited_scene_root
		static_body.owner = get_tree().edited_scene_root
		lod_box.owner = get_tree().edited_scene_root
		building_node.owner = get_tree().edited_scene_root	

## Adds floors to ([param add] = true) or removes floors from every child
## Facade. Called when the building's [member floors] value changes.
func _manage_child_facade_floors(value: int, add: bool) -> void:
	for i in get_child_count():
		if get_child(i) is Facade:
			var facade = get_child(i) as Facade
			if add: 
				facade.add_floors(value)
			else:
				facade.remove_floor(value)
			
			

## Reserved lifecycle hooks; currently unused.
func _enter_tree() -> void:
	pass

## Reserved lifecycle hook; currently unused.
func _exit_tree() -> void:
	pass
