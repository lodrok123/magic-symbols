extends SceneTree
## PRUEBA mínima del laboratorio de la jugadora (laboratorios/LabJugadora3D.tscn, 24/10): carga, el personaje es jugadora_base vestida como el juego, hay clips con su
## fuente, la escala de la cabeza cambia el hueso Head y vuelve a 1, y las medidas del clip salen. Sin ventana:
##   godot --headless --path . --script res://herramientas/prueba_lab_jugadora.gd

const CLIPS_MIN: int = 30                 ## 22 de la elfa + 5 de Meshy + 3 casts a una mano
const PRENDAS: Array = ["tunica", "capa", "capucha"]

var _fallos: int = 0
var _sk: Skeleton3D = null
var _cab: int = -1
var _capucha: MeshInstance3D = null
var _rec_esc: float = -1.0
var _rec_cima: float = 0.0


func _ok(c: bool, m: String) -> void:
	if c:
		print("OK    ", m)
	else:
		_fallos += 1
		print("FALLO ", m)


func _initialize() -> void:
	Estado.nuevo()
	await process_frame
	var lab: Node = (load("res://laboratorios/LabJugadora3D.tscn") as PackedScene).instantiate()
	root.add_child(lab)
	for _i in 4:
		await process_frame
	var pj: Pj3D = lab.jugadora()
	_ok(pj != null and pj.id == "jugadora_base", "el lab monta a jugadora_base (%s)" % (pj.id if pj != null else "-"))
	var puestas: Array[String] = pj.ropa_puesta()
	_ok(puestas.size() == PRENDAS.size(), "con la ropa por defecto como el juego (%s)" % [puestas])
	_ok(pj.rol_visual == "jugadora", "rol visual de jugadora (rim): %s" % pj.rol_visual)
	var clips: Array = lab.clips()
	_ok(clips.size() >= CLIPS_MIN, "%d clips en la lista (mínimo %d)" % [clips.size(), CLIPS_MIN])
	var sin_fuente: Array = []
	for c in clips:
		if (c["fuente"] as Dictionary).is_empty():
			sin_fuente.append(c["nombre"])
	_ok(sin_fuente.is_empty(), "todos los clips tienen fuente conocida (sin: %s)" % [sin_fuente])
	_ok(lab.elegir_clip_por_nombre("Walking") and lab.clip_actual() == "Walking", "se elige el clip Walking")
	_ok(lab.hay_fuente() and lab.fuente_con_malla(), "Walking: fuente con malla (chibi_elf)")
	_ok(lab.elegir_clip_por_nombre("saludo") and lab.hay_fuente() and not lab.fuente_con_malla(), "saludo: fuente de Meshy sin malla (solo esqueleto)")
	var txt: String = lab.texto_medidas()
	_ok(txt.contains("PEORES SALTOS") and txt.contains("FUENTE"), "el panel de medidas trae los saltos de giro del nuevo y de la fuente")
	# La escala de la cabeza cambia el hueso Head (y por ProporcionChibi la escala de su pose) y vuelve a 1.
	await process_frame
	var sk: Skeleton3D = pj.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var cab: int = sk.find_bone("mixamorig_Head")
	lab.elegir_clip_por_nombre("Idle")
	# El esqueleto restaura las poses tras los modificadores: lo que hace ProporcionChibi se lee en su señal `modification_processed`.
	_sk = sk
	_cab = cab
	_capucha = Ropa3D.puesta(pj, "capucha")
	pj.proporcion.modification_processed.connect(_al_modificar)
	lab._poner_cabeza(1.0)
	await process_frame
	await process_frame
	var e1: float = _rec_esc
	var alturas1: float = lab.alturas_de_cabeza()
	lab._poner_cabeza(0.8)
	await process_frame
	await process_frame
	var e08: float = _rec_esc
	var alturas08: float = lab.alturas_de_cabeza()
	_ok(absf(e1 - 1.0) < 0.001, "cabeza 1,0: el hueso Head a escala %.3f" % e1)
	_ok(absf(e08 - 0.8) < 0.001, "cabeza 0,8: el hueso Head a escala %.3f" % e08)
	_ok(alturas08 > alturas1 + 0.2, "con la cabeza más pequeña hay más alturas de cabeza (%.2f → %.2f)" % [alturas1, alturas08])
	_ok(absf(pj.alto_modelo() * pj.scale.y - 1.0) < 0.01, "el personaje sigue midiendo 1,0 u con la cabeza a 0,8 (%.3f)" % (pj.alto_modelo() * pj.scale.y))
	lab._poner_cabeza(1.0)
	await process_frame
	await process_frame
	_ok(absf(_rec_esc - 1.0) < 0.001, "vuelve a 1,0 (%.3f)" % _rec_esc)
	var del_juego: Variant = Pj3D.PROPORCIONES.get("jugadora_base", null)
	_ok(del_juego != null and absf(float((del_juego as Array)[0]) - lab.escala_cabeza_juego()) < 0.001, "la escala de la cabeza del juego (Pj3D.PROPORCIONES) es la que toma el lab como «valor del juego» (%s)" % [del_juego])
	# La capucha va entera al hueso Head (100 % del peso): con la cabeza a 0,6 su punto más alto baja con ella.
	_ok(_capucha != null, "la capucha está puesta")
	if _capucha != null:
		var cima1: float = _rec_cima
		lab._poner_cabeza(0.6)
		await process_frame
		await process_frame
		var cima06: float = _rec_cima
		_ok(cima06 < cima1 - 0.0005, "la capucha sigue a la cabeza: su punto más alto baja de %.4f a %.4f (espacio del esqueleto)" % [cima1, cima06])
		lab._poner_cabeza(1.0)
	print("RESULTADO lab_jugadora · FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


## Se llama justo después de que ProporcionChibi escriba la pose: guarda la escala del hueso Head y la cima de la capucha de ese momento.
func _al_modificar() -> void:
	_rec_esc = _sk.get_bone_pose_scale(_cab).y
	_rec_cima = _cima(_capucha, _sk)


## Punto más alto (espacio del esqueleto) de una prenda pesada por completo al hueso Head, con la pose actual del esqueleto.
func _cima(mi: MeshInstance3D, sk: Skeleton3D) -> float:
	var skin: Skin = mi.skin
	var b: int = -1
	for i in range(skin.get_bind_count()):
		if skin.get_bind_name(i) == "mixamorig_Head":
			b = i
	if b < 0:
		return NAN
	var xf: Transform3D = sk.get_bone_global_pose(sk.find_bone("mixamorig_Head")) * skin.get_bind_pose(b)
	var m: float = -INF
	for v in (mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
		m = maxf(m, (xf * v).y)
	return m
