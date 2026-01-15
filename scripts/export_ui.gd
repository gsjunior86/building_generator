# inspector_plugin.gd
@tool
extends EditorInspectorPlugin

func _can_handle(object):
	return object is Building

func _parse_begin(object):
	var btn = Button.new()
	btn.text = "Export"
	btn.tooltip_text = "Export this building as MultiMeshInstance 3D"
	btn.pressed.connect(func():
		object.export_mesh()
	)

	var sep := HSeparator.new()
	add_custom_control(btn)
	add_custom_control(sep)
