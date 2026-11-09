extends "res://presentacion/vfx/toy/viento_corrientes.gd"

var ancla: Node3D
var dimensiones: Vector2
var desfase_y: float
var _restante: float
var _levitando: float
var _tiempo: float


func renovar(duracion: float, levita: bool) -> void:
	_restante = maxf(_restante, duracion)
	if levita:
		_levitando = duracion


func _process(delta: float) -> void:
	_restante -= delta
	if _restante <= 0.0 or not is_instance_valid(ancla) or get_parent().get("muerto") == true:
		queue_free()
		return
	global_position = ancla.global_position + Vector3.UP * desfase_y
	_tiempo += delta
	_levitando = maxf(_levitando - delta, 0.0)
	var opacidad: float = smoothstep(0.0, 0.08, _tiempo) * smoothstep(0.0, 0.24, _restante)
	dibujar(&"AURA", Vector3(dimensiones.y, dimensiones.x, dimensiones.y), _tiempo, opacidad, 1.0,
		smoothstep(0.0, 0.20, _levitando))
