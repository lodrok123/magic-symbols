extends SceneTree
## PRUEBA de la Santa Compaña (9/11): la procesión son varios iguales seguidos y cada uno porta UNA cosa, así que los dos
## comparten GLB (santa_compana_rig.glb, rigado con tools/autorig_fantasma.py) y solo cambian en la pieza y en el ANDAR.
## Sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_santa_compana.gd
## Cómo se VEN se mira en docs/capturas/santa_compana_cruz|vela/ (herramientas/captura_clips_fantasma.gd).
##
## Lo que fija esta prueba, y por qué: el andar propio de cada portador se llamaba «walk», pero Pj3D.SINONIMOS busca el rol
## walk como ["walking", "walk"] EN ESE ORDEN, así que el juego cogía el «Walking» genérico de la elfa y los andares de la
## procesión no se usaban nunca. No fallaba nada: simplemente andaban mal, y solo se vio mirando. Por eso se comprueba a qué
## clip resuelve el rol, no solo que el clip exista.

const ALTO: float = 0.85
## id -> la pieza que porta y cuánto dura su andar. La duración distingue el clip propio del «Walking» de la elfa (1,04 s):
## si el rol volviera a resolver al de la elfa, la duración lo canta.
const PORTADORES: Dictionary = {
	"santa_compana_cruz": {"pieza": "cruz_santa", "dura": 1.08},     # Spear_Walk: anda con la mano cerrada sobre el mango
	"santa_compana_vela": {"pieza": "vela_santa", "dura": 2.96},     # Unsteady_Walk: se tambalea, de ánima
}
## Tolerancia de la duración. Estrecha a propósito: el Spear_Walk de la cruz dura 1,08 s y el Walking de la elfa 1,04, así que
## con una tolerancia ancha la duración no distinguiría un clip del otro. Quien de verdad separa los dos es la medida de las
## piernas de más abajo: el de la elfa junta los pies a 0,045 y ninguno de estos baja de 0,067.
const TOL_DURA: float = 0.02
## Piernas al andar (medido con herramientas/medidas_piernas_clip.gd, en el espacio del esqueleto). En reposo los pies están
## a 0,196 y las rodillas a 0,151. El Walking de la elfa los juntaba a 0,045: con la túnica ancha, las piernas se solapan y
## parecen cruzadas. Se exige que no se crucen NUNCA y que no se estrechen por debajo de este mínimo.
const SEP_PIES_MIN: float = 0.06
const MUESTRAS: int = 16

var _fallos: int = 0


func _ok(c: bool, m: String) -> void:
	if c:
		print("OK    ", m)
	else:
		_fallos += 1
		print("FALLO ", m)


func _initialize() -> void:
	Estado.nuevo()
	await process_frame
	var mundo := Node3D.new()
	root.add_child(mundo)
	var andares: Array = []
	for id in PORTADORES:
		var esperado: Dictionary = PORTADORES[id]
		var p := Pj3D.new()
		mundo.add_child(p)
		_ok(p.cargar(String(id)), "%s carga" % id)
		p.set_alto(ALTO)
		await process_frame
		var ap: AnimationPlayer = p._ap
		if ap == null:
			_ok(false, "%s: sin AnimationPlayer" % id)
			continue

		# 1) el andar: el rol `walk` tiene que dar el clip propio del portador, NO el de la elfa.
		var clip: String = p.clip_de("walk")
		var dura: float = p.duracion("walk")
		_ok(clip != "", "%s: el rol «walk» resuelve a algo (%s)" % [id, clip])
		_ok(absf(dura - float(esperado["dura"])) <= TOL_DURA,
			"%s: anda con SU clip (%s, %.2f s; el esperado %.2f s)" % [id, clip, dura, float(esperado["dura"])])
		andares.append(dura)

		# 2) la pieza: cada uno porta UNA cosa, la suya.
		var piezas: Array[String] = []
		for n in p.find_children("*", "Node3D", true, false):
			if (n as Node3D).has_meta("equipo_id"):
				piezas.append(String((n as Node3D).get_meta("equipo_id")))
		_ok(piezas.size() == 1 and piezas[0] == String(esperado["pieza"]),
			"%s: porta solo «%s» (lleva %s)" % [id, esperado["pieza"], piezas])

		# 3) las piernas: ni se cruzan ni andan sobre una línea.
		var sks: Array[Node] = p.find_children("*", "Skeleton3D", true, false)
		if sks.is_empty() or clip == "":
			p.queue_free()
			continue
		var r: Dictionary = _piernas(p, sks[0] as Skeleton3D, ap, clip, dura)
		_ok(int(r["cruces"]) == 0,
			"%s: las piernas no se cruzan en ningún fotograma (%d de %d)" % [id, int(r["cruces"]), MUESTRAS + 1])
		_ok(float(r["sep_min"]) >= SEP_PIES_MIN,
			"%s: los pies no andan sobre una línea (separación mínima %.3f ≥ %.3f)" % [id, float(r["sep_min"]), SEP_PIES_MIN])
		p.queue_free()

	# 4) los dos de la procesión andan DISTINTO: junto con la pieza, es lo único que los diferencia.
	_ok(andares.size() == 2 and absf(float(andares[0]) - float(andares[1])) > TOL_DURA,
		"los dos portadores andan distinto (%s)" % [andares])

	print("RESULTADO santa_compana · FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


## Separación lateral mínima de los pies y cuántos fotogramas cruzan el eje del cuerpo, a lo largo del clip.
func _piernas(p: Pj3D, sk: Skeleton3D, ap: AnimationPlayer, clip: String, largo: float) -> Dictionary:
	var i_izq: int = _hueso(sk, "LeftFoot")
	var i_der: int = _hueso(sk, "RightFoot")
	var i_cad: int = _hueso(sk, "Hips")
	if i_izq < 0 or i_der < 0:
		return {"cruces": 0, "sep_min": INF}
	var s_izq: float = signf(sk.get_bone_global_rest(i_izq).origin.x)
	var cruces: int = 0
	var sep_min: float = INF
	if p._arbol != null:
		p._arbol.active = false      # el árbol manda sobre el reproductor: se apaga para mirar el clip a pelo
	ap.active = true
	for k in range(MUESTRAS + 1):
		ap.play(clip)
		ap.seek(largo * float(k) / float(MUESTRAS), true)
		sk.force_update_all_bone_transforms()
		var pi: Vector3 = sk.get_bone_global_pose(i_izq).origin
		var pd: Vector3 = sk.get_bone_global_pose(i_der).origin
		var cx: float = sk.get_bone_global_pose(i_cad).origin.x if i_cad >= 0 else 0.0
		if (pi.x - cx) * s_izq < 0.0 or (pd.x - cx) * s_izq > 0.0:
			cruces += 1
		sep_min = minf(sep_min, absf(pi.x - pd.x))
	return {"cruces": cruces, "sep_min": sep_min}


func _hueso(sk: Skeleton3D, fin: String) -> int:
	for b in sk.get_bone_count():
		var n := String(sk.get_bone_name(b))
		if n == fin or n.ends_with("_" + fin) or n.ends_with(":" + fin):
			return b
	return -1
