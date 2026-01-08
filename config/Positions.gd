extends Resource

class_name Position3

@export var x: float
@export var y: float
@export var z: float

func to_vector3() -> Vector3:
	return Vector3(x, y, z)
