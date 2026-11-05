extends SceneTree
## PRUEBA del equipo del goblin arquero (5/11, diario 389): arco en la mano izquierda, flecha en la derecha (solo al disparar) y carcaj a la espalda.
## Sin ventana:  godot --headless --path . --script res://herramientas/prueba_arquero_equipo.gd
## Comprueba con Pj3D real: (1) las tres piezas cuelgan de sus huesos; (2) con el árbol de animación en marcha, la flecha solo se ve en «attack»
## (estado «atacar»; Pj3D.EQUIPO_SOLO_EN) y con el árbol apagado se ve siempre; (3) apuntando (ArcheryShot a 3 s) la caja del arco está centrada en la mano izquierda y es
## vertical, la flecha va de la mano derecha hasta pasado el arco (horizontal) y el carcaj queda detrás de la cadera (−Z) y por debajo del cuello.

const ID: String = "goblin_archer_chibi"
const ALTO: float = 0.85
var _fallos: int = 0


func _ok(c: bool, m: String) -> void:
	if c:
		print("OK    ", m)
	else:
		_fallos += 1
		print("FALLO ", m)


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var pj := Pj3D.new()
	root.add_child(pj)
	pj.cargar(ID)
	pj.set_alto(ALTO)
	for _i in 3:
		await process_frame
	var piezas: Dictionary = {}
	for p in pj._equipo:
		piezas[String(p.get_meta("equipo_id", ""))] = p
	for n in ["arco", "flecha", "carcaj"]:
		_ok(piezas.has(n), "el arquero lleva la pieza «%s»" % n)
	if _fallos > 0:
		_fin()
		return
	var sk: Skeleton3D = pj.find_children("*", "Skeleton3D", true, false)[0]
	_ok((piezas["arco"] as Node).get_parent().bone_name.ends_with("LeftHand"), "el arco cuelga de la mano izquierda")
	_ok((piezas["flecha"] as Node).get_parent().bone_name.ends_with("RightHand"), "la flecha cuelga de la mano derecha")
	_ok((piezas["carcaj"] as Node).get_parent().bone_name.ends_with("Spine2"), "el carcaj cuelga de Spine2")
	# ---- (2) visibilidad de la flecha ----
	_ok(pj._arbol != null and pj._arbol.active, "el árbol de animación está en marcha de serie")
	pj.jugar("idle")
	for _i in 3:
		await process_frame
	_ok(not (piezas["flecha"] as Node3D).visible, "en idle la flecha NO se ve (estado %s)" % pj.estado_anim())
	_ok((piezas["arco"] as Node3D).visible and (piezas["carcaj"] as Node3D).visible, "el arco y el carcaj se ven siempre")
	pj.jugar("attack", true)
	for _i in 3:
		await process_frame
	_ok(pj.estado_anim() == "atacar" and (piezas["flecha"] as Node3D).visible, "al disparar la flecha se ve (estado %s)" % pj.estado_anim())
	pj._arbol.active = false
	pj._ap.active = true
	pj._ap.play("Idle")
	for _i in 3:
		await process_frame
	_ok((piezas["flecha"] as Node3D).visible, "con el árbol apagado (laboratorios) la flecha se ve siempre")
	# ---- (3) apuntando ----
	pj._ap.play("ArcheryShot")
	pj._ap.seek(3.0, true)
	pj._ap.pause()
	for _i in 3:
		await process_frame
	var izq: Vector3 = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("mixamorig_LeftHand"))).origin
	var der: Vector3 = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("mixamorig_RightHand"))).origin
	var cadera: Vector3 = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("mixamorig_Hips"))).origin
	var cuello: Vector3 = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("mixamorig_Neck"))).origin
	var arco: AABB = _caja(piezas["arco"])
	var flecha: AABB = _caja(piezas["flecha"])
	var carcaj: AABB = _caja(piezas["carcaj"])
	var tiro: Vector3 = (izq - der).normalized()
	print("  mano izq %s der %s | arco centro %s tam %s | flecha centro %s tam %s | carcaj centro %s tam %s" % [izq, der, arco.get_center(), arco.size, flecha.get_center(), flecha.size, carcaj.get_center(), carcaj.size])
	_ok(arco.get_center().distance_to(izq) < 0.06 * ALTO, "el arco está centrado en la mano izquierda (a %.3f u)" % arco.get_center().distance_to(izq))
	_ok(arco.size.y > arco.size.x and arco.size.y > arco.size.z, "el arco apuntando es vertical (%.2f de alto)" % arco.size.y)
	# 5/11 (Pablo): la CUERDA mira al cuerpo: la madera (el grueso de la caja, que curva desde la empuñadura hacia las puntas) queda por delante de la mano.
	_ok((arco.get_center() - izq).dot(tiro) > 0.01, "la madera del arco queda por delante de la mano (cuerda hacia el cuerpo): %.3f u" % (arco.get_center() - izq).dot(tiro))
	_ok(flecha.size.y < 0.15 * ALTO, "la flecha apuntando va horizontal (%.3f de alto)" % flecha.size.y)
	var cola: float = (flecha.get_center() - tiro * flecha.size.length() * 0.5).distance_to(der)
	_ok(cola < 0.08 * ALTO, "la nocla de la flecha está en la mano derecha (a %.3f u)" % cola)
	_ok((flecha.get_center() + tiro * flecha.size.length() * 0.5 - der).dot(tiro) > (izq - der).dot(tiro), "la punta de la flecha pasa del arco")
	_ok(carcaj.get_center().z < cadera.z - 0.05 * ALTO, "el carcaj queda detrás de la espalda (z %.3f, cadera %.3f)" % [carcaj.get_center().z, cadera.z])
	_ok(carcaj.get_center().y < cuello.y and carcaj.get_center().y > cadera.y, "el carcaj va entre la cadera y el cuello (y %.3f)" % carcaj.get_center().y)
	_fin()


func _caja(n: Node) -> AABB:
	var res := AABB()
	var primero: bool = true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var c: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		res = c if primero else res.merge(c)
		primero = false
	return res


func _fin() -> void:
	print("RESULTADO arquero_equipo · FALLOS: ", _fallos)
	quit(1 if _fallos > 0 else 0)
