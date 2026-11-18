extends Node3D


func _ready() -> void:
	var efectos := Vfx3D.new()
	add_child(efectos)
	efectos.fuego_fijo(Vector3.UP * 0.12, false, 0.73)
