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
	# `en_mano`: si la pieza se mide por su distancia a la mano (ver PIEZA_MANO_MAX).
	"santa_compana_cruz": {"pieza": "cruz_santa", "dura": 1.08, "en_mano": false},   # Spear_Walk: la mano cerrada sobre el mango
	"santa_compana_vela": {"pieza": "vela_santa", "dura": 2.96, "en_mano": true},    # Unsteady_Walk: se tambalea, de ánima
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
## La pieza que portan tiene que ir en la mano en TODOS los clips que el juego les pide, no solo en el idle: la cruz cuelga de
## un PiezaApoyada3D y la vela de un PiezaVertical3D, y los dos se recolocan con `skeleton_updated`, DESPUÉS de la pose.
## Medido con herramientas/medidas_clips_portador.gd (fracción del alto del personaje) en los 23 clips.
## OJO al medir esto: si se fuerza la pose con force_update_all_bone_transforms en vez de dejar correr el fotograma, se mide la
## pieza ANTES de que siga a la mano y parece que se le escapa en casi todos los clips (me pasó).
const ROLES_DEL_JUEGO: Array[String] = ["idle", "walk", "run", "hit", "death"]
## Solo para la VELA: su origen está en la palmatoria, que va en la mano, y se queda entre 0,04 y 0,11 de ella. La cruz NO se
## mide así: su origen es el pie del bastón y está a 0,7 de la mano POR DISEÑO, y además PiezaApoyada3D la suelta y la planta
## en el suelo cuando la mano se va lejos (igual que el bastón de Marimanta, que tiene su propia prueba para eso).
const PIEZA_MANO_MAX: float = 0.15
## Para los dos: lo más cerca que puede pasar la pieza de la cabeza sin meterse en la capucha. Lo peor medido es 0,20 (la vela
## en la esquiva) y 0,31 (la cruz en el golpe al suelo); en las capturas la vela parece taparle la cara en el cast, pero es la
## perspectiva de la cámara, no un cruce.
const PIEZA_CABEZA_MIN: float = 0.12
## La cruz respecto a la palma (u de mundo): el eje del palo a 0,022 por delante (Equipo3D.CRUZ_APOYO["palma"]), con algo de holgura
## porque la pieza suaviza su seguimiento. Negativo sería por el dorso de la mano.
const CRUZ_DELANTE_MIN: float = 0.020     ## como poco, casi el radio del mango (0,029): menos y el palo atraviesa la palma
const CRUZ_DELANTE_MAX: float = 0.055

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
		var sk: Skeleton3D = sks[0] as Skeleton3D
		var r: Dictionary = _piernas(p, sk, ap, clip, dura)
		_ok(int(r["cruces"]) == 0,
			"%s: las piernas no se cruzan en ningún fotograma (%d de %d)" % [id, int(r["cruces"]), MUESTRAS + 1])
		_ok(float(r["sep_min"]) >= SEP_PIES_MIN,
			"%s: los pies no andan sobre una línea (separación mínima %.3f ≥ %.3f)" % [id, float(r["sep_min"]), SEP_PIES_MIN])

		# 4) la pieza, en los clips que el juego les pide: en la mano y fuera de la capucha.
		await _pieza_en_clips(p, sk, ap, bool(esperado["en_mano"]), String(id))
		p.queue_free()

	# 6) la CRUZ va DELANTE DE LA PALMA (10/11, Pablo: «queda por detrás de la mano, cósela delante de la palma»). Se mide en el
	# esqueleto, como herramientas/medidas_palma_pieza.gd: distancia del eje del palo al plano de la palma, positiva hacia donde mira.
	# Antes daba −0,020 en reposo (por el dorso) y al andar el palo ni seguía a la mano.
	await _cruz_en_la_palma(mundo)

	# 7) el FANTASMA tiene clips y anda como un zombi (10/11): se metió en el laboratorio sin fuente de clips y cargaba con cero,
	# clavado en reposo sin que nada fallara. Su andar es el tambaleante, el mismo clip que el portador de la vela.
	var f := Pj3D.new()
	mundo.add_child(f)
	_ok(f.cargar("fantasma_elfo_rig"), "fantasma_elfo_rig carga")
	await process_frame
	_ok(f.lista_clips().size() >= 20, "fantasma: tiene clips (%d)" % f.lista_clips().size())
	_ok(absf(f.duracion("walk") - float(PORTADORES["santa_compana_vela"]["dura"])) <= TOL_DURA,
		"fantasma: anda con el tambaleante (%s, %.2f s)" % [f.clip_de("walk"), f.duracion("walk")])
	f.queue_free()

	# 5) los dos de la procesión andan DISTINTO: junto con la pieza, es lo único que los diferencia.
	_ok(andares.size() == 2 and absf(float(andares[0]) - float(andares[1])) > TOL_DURA,
		"los dos portadores andan distinto (%s)" % [andares])

	print("RESULTADO santa_compana · FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


## La pieza que porta, a lo largo de cada clip que el juego le pide: que no se le escape de la mano (solo donde tiene sentido
## medirlo, ver PIEZA_MANO_MAX) y que no se le meta en la capucha. Se deja correr el fotograma: las piezas se recolocan con
## `skeleton_updated`, así que forzar la pose a mano mediría la pieza antes de que siga a la mano.
func _pieza_en_clips(p: Pj3D, sk: Skeleton3D, ap: AnimationPlayer, en_mano: bool, id: String) -> void:
	var pieza: Node3D = null
	for n in p.find_children("*", "Node3D", true, false):
		if (n as Node3D).has_meta("equipo_id"):
			pieza = n as Node3D
	var i_cab: int = sk.find_bone("mixamorig_Head")
	var i_mano: int = sk.find_bone("mixamorig_RightHand")
	if pieza == null or i_cab < 0 or i_mano < 0:
		_ok(false, "%s: no se encuentra la pieza o los huesos para medirla" % id)
		return
	var alto: float = p.alto_modelo() * p.scale.y
	if p._arbol != null:
		p._arbol.active = false
	ap.active = true
	for rol in ROLES_DEL_JUEGO:
		var clip: String = p.clip_de(rol)
		if clip == "":
			continue
		var largo: float = p.duracion(rol)
		var mano: float = 0.0
		var cabeza: float = INF
		for k in range(MUESTRAS + 1):
			ap.play(clip)
			ap.seek(largo * float(k) / float(MUESTRAS), true)
			await process_frame
			await process_frame
			var m: Vector3 = sk.global_transform * sk.get_bone_global_pose(i_mano).origin
			var c: Vector3 = sk.global_transform * sk.get_bone_global_pose(i_cab).origin
			mano = maxf(mano, pieza.global_position.distance_to(m) / alto)
			cabeza = minf(cabeza, pieza.global_position.distance_to(c) / alto)
		if en_mano:
			_ok(mano <= PIEZA_MANO_MAX,
				"%s · %s (%s): la pieza no se le escapa de la mano (máx %.3f ≤ %.3f)" % [id, rol, clip, mano, PIEZA_MANO_MAX])
		_ok(cabeza >= PIEZA_CABEZA_MIN,
			"%s · %s (%s): la pieza no se le mete en la capucha (mín %.3f ≥ %.3f)" % [id, rol, clip, cabeza, PIEZA_CABEZA_MIN])


func _cruz_en_la_palma(mundo: Node3D) -> void:
	var p := Pj3D.new()
	mundo.add_child(p)
	p.cargar("santa_compana_cruz")
	p.set_alto(ALTO)
	await process_frame
	var sk: Skeleton3D = (p.find_children("*", "Skeleton3D", true, false)[0]) as Skeleton3D
	var ap: AnimationPlayer = p._ap
	var pieza: Node3D = null
	for n in p.find_children("*", "Node3D", true, false):
		if (n as Node3D).has_meta("equipo_id"):
			pieza = n as Node3D
	if p._arbol != null:
		p._arbol.active = false
	ap.active = true
	var eje: Vector3 = (load("res://herramientas/medidas_palma_pieza.gd") as GDScript)._eje_mango(pieza)
	var i_w: int = sk.find_bone("mixamorig_RightHand")
	var i_m: int = sk.find_bone("mixamorig_RightHandMiddle1")
	var i_i: int = sk.find_bone("mixamorig_RightHandIndex1")
	var i_p: int = sk.find_bone("mixamorig_RightHandPinky1")
	var leido: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	var leer := func() -> void:
		leido[0] = sk.global_transform * sk.get_bone_global_pose(i_w).origin
		leido[1] = sk.global_transform * sk.get_bone_global_pose(i_m).origin
		leido[2] = sk.global_transform * sk.get_bone_global_pose(i_i).origin
		leido[3] = sk.global_transform * sk.get_bone_global_pose(i_p).origin
	sk.skeleton_updated.connect(leer)
	for rol in ["idle", "walk", "run"]:
		var clip: String = p.clip_de(rol)
		var largo: float = p.duracion(rol)
		var peor: float = INF
		var mejor: float = -INF
		for k in range(6):
			ap.play(clip)
			ap.seek(largo * float(k) / 6.0, true)
			for i in 30:            # la pieza apoyada suaviza su posición: se le deja asentar
				await process_frame
			# La mano se lee DENTRO de `skeleton_updated` (ver `leer`): ManoEmpuna3D gira la muñeca como modificador del esqueleto y esa
			# pose solo existe mientras se actualiza. Leída aquí fuera sería la muñeca sin girar, y la prueba mediría contra una mano que
			# no es la que se dibuja (así falló al correr: +0,010 cuando el palo estaba bien puesto).
			var w: Vector3 = leido[0]
			var m: Vector3 = leido[1]
			var a: Vector3 = leido[2] - w
			var b: Vector3 = leido[3] - w
			var normal: Vector3 = a.cross(b).normalized()
			# el punto de la mano donde va el palo es el de Equipo3D.CRUZ_APOYO (`palma_hacia_dedos`)
			var centro: Vector3 = w.lerp(m, float(Equipo3D.CRUZ_APOYO.get("palma_hacia_dedos", 0.5)))
			var arriba: Vector3 = pieza.global_basis.y.normalized()
			# el eje del MANGO medido en la malla, no el origen del GLB (que no está en el mango: medir sobre el origen daba por buena
			# una cruz que en la foto quedaba detrás de la mano)
			var o: Vector3 = pieza.global_transform * eje
			var palo: Vector3 = o + arriba * ((centro.y - o.y) / maxf(arriba.y, 0.001))
			var delante: float = (palo - centro).dot(normal)
			peor = minf(peor, delante)
			mejor = maxf(mejor, delante)
		_ok(peor >= CRUZ_DELANTE_MIN and mejor <= CRUZ_DELANTE_MAX,
			"cruz · %s (%s): el palo va por delante de la palma (entre %+.3f y %+.3f; debe estar entre %+.3f y %+.3f)" % [
				rol, clip, peor, mejor, CRUZ_DELANTE_MIN, CRUZ_DELANTE_MAX])
	p.queue_free()


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
