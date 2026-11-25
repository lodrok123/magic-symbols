extends SceneTree
const PARTES = preload("res://presentacion/partes_colmena_3d.gd")
var fallos: int = 0
func comprobar(b: bool,t: String) -> void:
	print("OK " if b else "FALLO ",t)
	if not b: fallos += 1
func contar(n: Node3D) -> int:
	var total: int = 0
	for mi in n.find_children("*","MeshInstance3D",true,false): total += mi.mesh.get_faces().size()/3
	return total
func _initialize() -> void: call_deferred("correr")
func correr() -> void:
	var original: Node3D = load("res://arte/piezas/colmena.tscn").instantiate()
	root.add_child(original)
	var partes: Node3D = PARTES.crear(original)
	root.add_child(partes)
	var rama: Node3D = partes.get_node("soporte")
	var panal: Node3D = partes.get_node("panal")
	comprobar(contar(partes)==contar(original),"Todos los triángulos originales, sin cortes ni tapones")
	comprobar(contar(rama)==1018,"Rama real completa: 1018 triángulos")
	comprobar(contar(panal)>contar(rama),"Cera e insectos quedan en la parte que se retira")
	var caja: AABB = Pieza3D._caja(rama,Transform3D.IDENTITY)
	comprobar(caja.position.y < 0.50,"Punta curva recuperada bajo el corte antiguo")
	var todo: AABB = Pieza3D._caja(partes,Transform3D.IDENTITY)
	var antes: AABB = Pieza3D._caja(original,Transform3D.IDENTITY)
	comprobar(todo.position.is_equal_approx(antes.position) and todo.size.is_equal_approx(antes.size),"Colmena completa conserva volumen y posición")
	for mi in rama.get_children():
		var mat: StandardMaterial3D = mi.get_active_material(0)
		comprobar(mat.albedo_texture != null and mat.albedo_color.b > mat.albedo_color.r,"Madera con textura original y menos naranja")
	partes.free()
	original.free()
	print("TOTAL DE FALLOS: ",fallos)
	quit(1 if fallos else 0)
