extends SceneTree
## Titan3D (14/10): el titán procedural se construye, es del tamaño pensado, lleva su pueblo y su castillo, y es repetible con la
## misma semilla. Sin ventana. Lo escribe el Juego.
##   godot --headless --path . --script res://herramientas/prueba_titan.gd

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _caja_total(t: Titan3D) -> AABB:
	var total := AABB()
	var primero: bool = true
	for mi in t.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = (mi as MeshInstance3D).transform * (mi as MeshInstance3D).get_aabb()
		var p: Node = mi.get_parent()
		while p != null and p != t:
			a = (p as Node3D).transform * a
			p = p.get_parent()
		total = a if primero else total.merge(a)
		primero = false
	return total


func _initialize() -> void:
	await process_frame
	var t := Titan3D.new()
	t.semilla = 7
	root.add_child(t)
	await process_frame
	var piezas: int = 0
	for mi in t.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).mesh is ArrayMesh:
			piezas += 1
	_ok("1 se construye con todas sus piezas de roca", piezas >= 30, "%d bloques" % piezas)
	var caja: AABB = _caja_total(t)
	_ok("2 mide lo previsto: ~105 u de largo, 55-85 u de alto", caja.size.z > 85.0 and caja.size.z < 130.0 and caja.size.y > 55.0 and caja.size.y < 85.0,
			"largo %.0f, alto %.0f, ancho %.0f" % [caja.size.z, caja.size.y, caja.size.x])
	_ok("3 los pies caen en el valle (z>0) y la cabeza al fondo (z<-65)", caja.end.z > 15.0 and caja.position.z < -65.0, "z de %.0f a %.0f" % [caja.position.z, caja.end.z])
	_ok("4 tiene castillo, árboles, casas y tejados", t.find_child("Castillo_cuerpo", true, false) != null and t.find_child("Arboles", true, false) != null
			and t.find_child("Casas", true, false) != null and t.find_child("Tejados", true, false) != null)
	var casas: MultiMeshInstance3D = t.find_child("Casas", true, false)
	_ok("5 las casas son las que dice CASAS", casas != null and casas.multimesh.instance_count > 20, "%d" % (casas.multimesh.instance_count if casas != null else 0))
	_ok("6 es un decorado: ninguna colisión", t.find_children("*", "CollisionObject3D", true, false).is_empty())
	# La columna (referencia de Pablo): de la cadera a la cabeza sube y se inclina hacia atrás 15-40° respecto a la vertical.
	var cad: Vector3 = t.find_child("cadera", true, false).position
	var cab: Vector3 = t.find_child("cabeza", true, false).position
	var inc: float = rad_to_deg(atan2(cad.z - cab.z, cab.y - cad.y))
	_ok("3b la columna sube y se inclina hacia atrás 15-40°", cab.y > cad.y + 30.0 and inc > 15.0 and inc < 40.0, "%.0f°" % inc)
	# Misma semilla, mismo titán; otra, otro.
	var v1: PackedVector3Array = ((t.find_child("pecho", true, false) as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var t2 := Titan3D.new()
	t2.semilla = 7
	root.add_child(t2)
	var t3 := Titan3D.new()
	t3.semilla = 8
	root.add_child(t3)
	await process_frame
	var v2: PackedVector3Array = ((t2.find_child("pecho", true, false) as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var v3: PackedVector3Array = ((t3.find_child("pecho", true, false) as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	_ok("7 la misma semilla da la misma roca", v1 == v2)
	_ok("7 otra semilla, otra roca", v1 != v3)
	# La malla es sólida: normales unitarias y colores en los vértices.
	var arrays: Array = ((t.find_child("pecho", true, false) as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)
	var nor: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var malas: int = 0
	for n in nor:
		if absf(n.length() - 1.0) > 0.01:
			malas += 1
	_ok("8 todas las normales son unitarias y hay color por vértice", malas == 0 and (arrays[Mesh.ARRAY_COLOR] as PackedColorArray).size() == nor.size(), "%d malas" % malas)
	# Reconstruir no acumula nodos.
	var antes: int = t.get_child_count()
	t.construir()
	await process_frame
	await process_frame
	_ok("9 construir() de nuevo no deja nodos de más", t.get_child_count() == antes, "%d -> %d" % [antes, t.get_child_count()])
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)
