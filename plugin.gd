@tool
extends EditorPlugin

var export_building = preload("res://addons/building_generator/scripts/export_ui.gd").new()

func _enter_tree():
	add_custom_type("Building", "Node3D",
	 preload("res://addons/building_generator/scripts/building.gd"), preload("building.png"))
	add_custom_type("Facade", "Node3D",
	 preload("res://addons/building_generator/scripts/facade.gd"), preload("facade.png"))
	add_inspector_plugin(export_building)
	


func _exit_tree():
	remove_custom_type("Facade")
	remove_custom_type("Building")
	remove_inspector_plugin(export_building)
