@tool
extends EditorPlugin

func _enter_tree():
	add_custom_type("Building", "Node3D",
	 preload("res://addons/building_generator/building.gd"), preload("icon.svg"))
	# Initialization of the plugin goes here.
	pass


func _exit_tree():
	remove_custom_type("Building")
	pass
