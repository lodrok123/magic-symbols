class_name NaturalezaManchas
extends Node3D

## MANCHAS POR CPU (5/11/2026, naturaleza «toy»): una reserva de manchas blandas de cartel (naturaleza_blob.gdshader) que viven en el MUNDO (top_level). Sirven de ESTELA de la bola
## (una mancha por trecho recorrido que se encoge y se apaga: la cadena sigue el arco), de destellos del impacto, de chispas que suben (brasas del escudo quemado) y de motas.
## Cada mancha: posición, velocidad (con gravedad opcional), tamaño que va de `tam0` a `tam1`, color que va de `col0` a `col1`, opacidad que sube y baja. Las pruebas leen `estados()`.

var _mi: MultiMeshInstance3D = null
var _s: Array = []
var _cursor: int = 0


static func crear_mm(nombre: String, cantidad: int, nucleo: float = 0.45, blandura: float = 0.35) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	mm.mesh = q
	mm.instance_count = cantidad
	var m := ShaderMaterial.new()
	m.shader = load("res://presentacion/vfx/toy/naturaleza_blob.gdshader") as Shader
	m.set_shader_parameter("nucleo", nucleo)
	m.set_shader_parameter("blandura", blandura)
	var inst := MultiMeshInstance3D.new()
	inst.name = nombre
	inst.multimesh = mm
	inst.material_override = m
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.extra_cull_margin = 4.0
	for i in cantidad:
		ocultar(mm, i)
	return inst


static func ocultar(mm: MultiMesh, i: int) -> void:
	mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3(0, -1000, 0)))


func montar(n: int, nucleo: float = 0.45, blandura: float = 0.35) -> void:
	top_level = true
	transform = Transform3D.IDENTITY                 # (top_level conserva la posición global que tuviera: vuelta al origen del mundo)
	_mi = crear_mm("Manchas", n, nucleo, blandura)
	add_child(_mi)
	_s.clear()
	for i in n:
		_s.append({"vivo": false})
	_cursor = 0


func capacidad() -> int:
	return _s.size()


func vivas() -> int:
	var k: int = 0
	for d in _s:
		if bool(d["vivo"]):
			k += 1
	return k


## Una mancha en `pos` (mundo). `alfa` es la opacidad máxima; sube en el primer 15 % de la vida y baja hasta cero al final.
func emitir(pos: Vector3, vel: Vector3, vida: float, tam0: float, tam1: float, col0: Color, col1: Color, alfa: float = 0.8, gravedad: float = 0.0) -> int:
	if _s.is_empty():
		return -1
	var hueco: int = -1
	for k in _s.size():
		var j: int = (_cursor + k) % _s.size()
		if not bool((_s[j] as Dictionary)["vivo"]):
			hueco = j
			break
	if hueco < 0:
		return -1
	_cursor = (hueco + 1) % _s.size()
	_s[hueco] = {"vivo": true, "pos": pos, "vel": vel, "edad": 0.0, "vida": maxf(vida, 0.05), "tam0": tam0, "tam1": tam1, "col0": col0, "col1": col1, "alfa": alfa, "g": gravedad}
	return hueco


func vaciar() -> void:
	for i in _s.size():
		_s[i] = {"vivo": false}
	if _mi != null:
		for i in _s.size():
			ocultar(_mi.multimesh, i)


func _process(delta: float) -> void:
	avanzar(delta)


func avanzar(delta: float) -> void:
	if _mi == null:
		return
	var mm: MultiMesh = _mi.multimesh
	for i in _s.size():
		var d: Dictionary = _s[i]
		if not bool(d["vivo"]):
			continue
		d["edad"] = float(d["edad"]) + delta
		var u: float = float(d["edad"]) / float(d["vida"])
		if u >= 1.0:
			d["vivo"] = false
			ocultar(mm, i)
			continue
		var v: Vector3 = d["vel"]
		v.y -= float(d["g"]) * delta
		d["vel"] = v
		d["pos"] = (d["pos"] as Vector3) + v * delta
		var tam: float = lerpf(float(d["tam0"]), float(d["tam1"]), u)
		var col: Color = (d["col0"] as Color).lerp(d["col1"], u)
		col.a = float(d["alfa"]) * smoothstep(0.0, 0.15, u) * (1.0 - smoothstep(0.35, 1.0, u))
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(tam, tam, tam)), d["pos"]))
		mm.set_instance_color(i, col.srgb_to_linear())


func estados() -> Array:
	var res: Array = []
	for d in _s:
		if bool((d as Dictionary)["vivo"]):
			res.append({"pos": d["pos"], "edad": d["edad"], "vida": d["vida"], "tam0": d["tam0"], "tam1": d["tam1"], "col0": d["col0"]})
	return res
