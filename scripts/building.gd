@tool
extends Node3D

class_name Building

var dock

func export_mesh() -> void:
	
	var building_node = Node3D.new()
	get_parent().add_child(building_node)
	building_node.name = self.name
	
	
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
	
	for key in distinct_objects.keys():
		print(key)
		var node_group = distinct_objects[key]
		
		var multimesh = MultiMesh.new()
		multimesh.mesh = node_group[0].mesh
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.instance_count = node_group.size()
		
		for i in range(node_group.size()):
			var transform = node_group[i].global_transform
			multimesh.set_instance_transform(i, transform)
		
		var multimesh_instance = MultiMeshInstance3D.new()
		multimesh_instance.multimesh = multimesh
		multimesh_instance.name = "Multimesh_" + key
		building_node.add_child(multimesh_instance)
		if Engine.is_editor_hint():
			multimesh_instance.owner = get_tree().edited_scene_root	
	
	
	if Engine.is_editor_hint():
		building_node.owner = get_tree().edited_scene_root	
	

func _enter_tree() -> void:
	pass

func _exit_tree() -> void:
	pass
