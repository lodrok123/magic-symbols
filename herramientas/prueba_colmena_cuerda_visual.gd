extends SceneTree
var fallos: int = 0
class Soporte extends Node:
	var caidas: int = 0
	func tender() -> void: caidas += 1
func comprobar(b: bool,t: String) -> void:
	print("OK " if b else "FALLO ",t)
	if not b: fallos += 1
func _initialize() -> void: call_deferred("correr")
func correr() -> void:
	Terreno3D.cargar_datos(PackedStringArray(["....","....","....","...."]),{})
	Terreno3D.alto_suelo = 0.0
	Flags.nuevo()
	var original: Node3D = (load("res://arte/piezas/colmena.tscn") as PackedScene).instantiate()
	root.add_child(original)
	var caja: AABB = Pieza3D._caja(original,Transform3D.IDENTITY)
	var c := Colmena3D.new()
	c.name = "colmena_qa"
	c.nivel = "qa_visual"
	root.add_child(c)
	var partida: AABB = Pieza3D._caja(c._visual,Transform3D.IDENTITY)
	comprobar(partida.position.is_equal_approx(caja.position) and partida.size.is_equal_approx(caja.size),"Separar conserva las dimensiones del asset real")
	comprobar(c._panal != null and not c._panal.get_children().is_empty(),"El modelo real tiene panal identificable")
	for mi in c._panal.find_children("*","MeshInstance3D",true,false):
		comprobar(mi.material_override == null and mi.get_active_material(0) is ShaderMaterial,"El panal dibuja el shader de combustión y no un override anterior")
	comprobar(not c._visual.get_node("soporte").get_children().is_empty(),"El soporte queda separado")
	var botin: Array = c.caer_panal()
	comprobar(c.estado == "vacia" and not botin.is_empty() and c.caer_panal().is_empty(),"El viento da panal una sola vez")
	await create_timer(0.42).timeout
	comprobar(not c._panal.visible and c._visual.get_node("soporte").visible,"Tras caer desaparece el panal y queda el soporte")
	var escala: Vector3 = c._visual.scale
	c.free()
	var recarga := Colmena3D.new()
	recarga.name = "colmena_qa"
	recarga.nivel = "qa_visual"
	root.add_child(recarga)
	comprobar(recarga.estado == "vacia" and not recarga._panal.visible and recarga._visual.scale == escala,"Recargar conserva la misma representación vacía sin reducir escala")
	recarga.free()
	c = Colmena3D.new()
	c.name = "cera_qa"
	c.nivel = "qa_visual"
	root.add_child(c)
	var rama_antes: Node3D = c._visual.get_node("soporte")
	var mesh_rama: Mesh = rama_antes.get_child(0).mesh
	var material_rama: Material = rama_antes.get_child(0).get_active_material(0)
	comprobar(c.arder() and c._panal.visible and c.soltado.is_empty(),"El fuego empieza sobre el panal visible sin recompensa")
	c.set_process(false)
	c._process(0.45)
	comprobar(c._panal.visible and c._combustion.progreso > 0.0 and c._nube != null,"Cera en combustión y nube activa simultáneamente")
	c._process(0.5)
	comprobar(not c._panal.visible and c._visual.get_node("soporte").visible,"Consumir cera conserva el soporte")
	comprobar(mesh_rama.get_faces().size()/3 == 1018 and rama_antes.get_child(0).mesh == mesh_rama and rama_antes.get_child(0).get_active_material(0) == material_rama,"Cera consumida conserva la rama completa de madera sin quemarla")
	c._process(Colmena3D.T_NUBE)
	comprobar(c.estado == "quemada" and c._nube == null,"El veneno termina con su contrato original")
	c.free()
	var quemada := Colmena3D.new()
	quemada.name = "cera_qa"
	quemada.nivel = "qa_visual"
	root.add_child(quemada)
	comprobar(not quemada._panal.visible and quemada._visual.get_node("soporte").visible and quemada._visual.get_node("soporte").get_child(0).mesh.get_faces().size()/3 == 1018,"Recargar cera consumida mantiene solo la rama completa")
	quemada.free()
	original.free()
	for modelos in [true,false]:
		PiezaFuego3D.usar_modelos = modelos
		var cuerda := Cuerda3D.new()
		var sostiene := Soporte.new()
		root.add_child(sostiene)
		cuerda.sostiene = sostiene
		root.add_child(cuerda)
		var capa: int = cuerda.collision_layer
		comprobar(not cuerda._combustion.materiales.is_empty(),"Materiales de cuerda compatibles; modelos="+str(modelos))
		var fibras: Array[Node] = cuerda.get_node("fibras").find_children("*","MeshInstance3D",true,false)
		comprobar(fibras.all(func(n: MeshInstance3D)->bool:return n.get_active_material(0) is ShaderMaterial),"Las fibras dibujan realmente el material del frente")
		comprobar(not cuerda.get_node("poste").is_ancestor_of(cuerda._combustion),"Combustión fuera del soporte")
		cuerda.arder()
		cuerda.set_process(false)
		cuerda._process(0.4)
		comprobar(cuerda._combustion.progreso > 0.3 and cuerda.collision_layer == capa,"Frente activo sin cambiar acierto")
		var dano: float = cuerda._combustion.progreso
		cuerda._apagar()
		comprobar(cuerda._combustion.progreso == dano and not cuerda._combustion.ardiendo and sostiene.caidas == 0,"Agua conserva chamuscado y no suelta el soporte")
		cuerda._escarchar()
		cuerda.arder()
		cuerda.set_process(false)
		cuerda._process(1.2)
		comprobar(not cuerda.rota_ya and sostiene.caidas == 0,"La escarcha sigue retrasando la rotura")
		cuerda._process(Reactivo3D.ESCARCHA_S)
		comprobar(cuerda.rota_ya and sostiene.caidas == 1 and cuerda.collision_layer == 0,"Acabada la escarcha se rompe y suelta una sola vez")
		comprobar(not cuerda._combustion.ardiendo,"No quedan focos activos tras la rotura")
		cuerda.free()
		sostiene.free()
	PiezaFuego3D.usar_modelos = true
	print("TOTAL DE FALLOS: ",fallos)
	quit(1 if fallos else 0)
