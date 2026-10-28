extends SceneTree
## PRUEBA del rig del chamán goblin (arte/modelos/goblin_chaman_rig.glb, salida de tools/autorig_chaman.py), su bastón y sus clips generados (jugador/animaciones_chaman.gd) y la runa del suelo.
## Sin ventana:   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_rig_chaman.gd
## Cómo se VE se mira en docs/capturas/chaman_rig/ (herramientas/captura_rig_chaman.gd y captura_chaman_ritual.gd).

const ID: String = "goblin_chaman"
const ALTO_JUEGO: float = 0.85
const HUESOS: int = 66
const PUNTA_SUELO_MAX: float = 0.08           ## u de juego: la punta del bastón al barrer
const PUNTA_IMPACTO_MAX: float = 0.02         ## u de juego: la punta al clavar
const COINCIDE_MAX: float = 0.012             ## u del modelo: la punta del bastón montado vs la que calcula el clip

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
	# --- el GLB y su esqueleto ---
	var glb: Node3D = (load("res://arte/modelos/goblin_chaman_rig.glb") as PackedScene).instantiate()
	root.add_child(glb)
	var sk_g: Skeleton3D = glb.find_children("*", "Skeleton3D", true, false)[0]
	var marim: Node3D = (load("res://arte/modelos/marimanta.glb") as PackedScene).instantiate()
	root.add_child(marim)
	var sk_m: Skeleton3D = marim.find_children("*", "Skeleton3D", true, false)[0]
	_ok(sk_g.get_bone_count() == HUESOS, "%d huesos (%d)" % [HUESOS, sk_g.get_bone_count()])
	var faltan: Array = []
	for i in sk_m.get_bone_count():
		if sk_g.find_bone(sk_m.get_bone_name(i)) < 0:
			faltan.append(sk_m.get_bone_name(i))
	_ok(faltan.is_empty(), "mismos nombres de hueso que Marimanta (faltan %s)" % str(faltan))
	var dif_jerarquia: int = 0
	for i in sk_m.get_bone_count():
		var j: int = sk_g.find_bone(sk_m.get_bone_name(i))
		if j >= 0:
			var pm: int = sk_m.get_bone_parent(i)
			var pg: int = sk_g.get_bone_parent(j)
			if (pm < 0) != (pg < 0) or (pm >= 0 and sk_m.get_bone_name(pm) != sk_g.get_bone_name(pg)):
				dif_jerarquia += 1
	_ok(dif_jerarquia == 0, "misma jerarquía que Marimanta (%d diferencias)" % dif_jerarquia)
	# las bases de hueso de reposo son las de Marimanta (los clips se traducen casi sin diferencia)
	var peor_base: float = 0.0
	for i in sk_m.get_bone_count():
		var j: int = sk_g.find_bone(sk_m.get_bone_name(i))
		var a: Quaternion = sk_m.get_bone_global_rest(i).basis.get_rotation_quaternion()
		var b: Quaternion = sk_g.get_bone_global_rest(j).basis.get_rotation_quaternion()
		peor_base = maxf(peor_base, rad_to_deg(a.angle_to(b)))
	_ok(peor_base < 1.0, "las orientaciones de hueso en reposo son las de Marimanta (peor %.3f°)" % peor_base)
	# pesos: ≤ 4 influencias y normalizados
	var mal_pesos: int = 0
	var mas_de_4: int = 0
	var verts: int = 0
	for mi in glb.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var arr: Array = mesh.surface_get_arrays(s)
			var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var n: int = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			var por: int = w.size() / maxi(n, 1)
			verts += n
			mas_de_4 += 1 if por > 4 else 0
			for v in n:
				var t: float = 0.0
				for k in range(mini(por, 4)):
					t += w[v * por + k]
				if absf(t - 1.0) > 0.02:
					mal_pesos += 1
	_ok(verts > 0 and mas_de_4 == 0, "pesos: como mucho 4 influencias por vértice (%d vértices)" % verts)
	_ok(mal_pesos == 0, "pesos normalizados (suman 1 ±0,02): %d vértices fuera" % mal_pesos)
	glb.queue_free()
	marim.queue_free()

	# --- Pj3D: modelo, equipo y clips ---
	var mundo := Node3D.new()
	root.add_child(mundo)
	var p := Pj3D.new()
	mundo.add_child(p)
	_ok(p.cargar(ID), "el chamán carga como Pj3D")
	p.set_alto(ALTO_JUEGO)
	await process_frame
	_ok(absf(p.alto_modelo() * p.scale.y - ALTO_JUEGO) < ALTO_JUEGO * 0.05, "altura en el juego %.3f (0,85)" % (p.alto_modelo() * p.scale.y))
	var bas: BastonChaman3D = p.baston()
	_ok(bas != null and bas.orbe != null, "el bastón está montado en la mano derecha, con el orbe aparte")
	_ok(bas != null and bas.get_parent() is BoneAttachment3D and (bas.get_parent() as BoneAttachment3D).bone_name.ends_with("RightHand"), "colgado de RightHand")
	if bas != null:
		bas.teñir(Color(0.35, 1, 0.45), 2.0)
		_ok(bas.energia_orbe == 2.0 and (bas.orbe.material_override as StandardMaterial3D).emission_enabled, "el orbe se tiñe de verde y brilla")
		bas.apagar()
		_ok(bas.energia_orbe == 0.0, "y se apaga")
	var ap: AnimationPlayer = p._ap
	for c in ["Idle_02", "Elderly_Shaky_Walk_inplace", "Talk_with_Left_Hand_on_Hip", "Scheming_Hand_Rub", "Running", "Walking"]:
		_ok(ap != null and ap.has_animation(c), "clip de Marimanta «%s»" % c)
	for r in ["idle", "walk", "talk", "pensar", "run", "hit", "death", "drown", "empujado", "levantarse", "trazar", "clavar", "lanzar"]:
		_ok(p.clip_de(r) != "" and p.duracion(r) > 0.0, "rol %s -> %s (%.2f s)" % [r, p.clip_de(r), p.duracion(r)])
	_ok(p.validar().is_empty(), "Pj3D.validar() sin avisos %s" % str(p.validar()))
	_ok(absf(p.duracion("trazar") - AnimacionesChaman.DUR_TRAZAR) < 0.05 and absf(p.duracion("clavar") - AnimacionesChaman.DUR_CLAVAR) < 0.05, "trazar %.2f s, clavar %.2f s" % [p.duracion("trazar"), p.duracion("clavar")])
	_ok(Pj3D.instante_clip_de("goblin_chaman", "clavar") == AnimacionesChaman.INSTANTE_CLAVAR, "INSTANTE_CLAVAR = %.2f s" % AnimacionesChaman.INSTANTE_CLAVAR)
	_ok(p.grafo == ArbolAnimPj.GRAFO_HEROE, "grafo")
	p.grafo = ArbolAnimPj.GRAFO_REDUCIDO
	for r in ["trazar", "clavar", "lanzar", "idle", "walk"]:
		p.animacion_actual = ""
		p.jugar(r)
		await process_frame
		_ok(p._arbol != null and p._arbol.estado == Pj3D.estado_de(r), "el grafo reducido admite «%s»" % r)

	# --- clips generados: la punta del bastón ---
	var sk: Skeleton3D = p.find_children("*", "Skeleton3D", true, false)[0]
	var cl: Dictionary = AnimacionesChaman.construir(sk, "")
	var escala: float = p.scale.y
	var maxy: float = 0.0
	var peor_pedida: float = 0.0
	var n_barridos: int = 0
	var u: float = 0.0
	while u < 0.9999:
		var punta: Vector3 = AnimacionesChaman.punta_de_clip(sk, cl["trazar"], u * AnimacionesChaman.DUR_TRAZAR)
		var pedida: Vector3 = AnimacionesChaman.punta_pedida(u)
		var baja: bool = float(TrazosRitual.punta(u)["baja"]) > 0.99
		if baja:
			n_barridos += 1
			maxy = maxf(maxy, punta.y * escala)
			peor_pedida = maxf(peor_pedida, (punta - pedida).length())
		u += 1.0 / 75.0
	_ok(n_barridos > 20, "trazar: %d fotogramas de barrido" % n_barridos)
	var rho_min: float = 9.0
	var rho_max: float = 0.0
	for k in range(76):
		var pz: float = AnimacionesChaman.punta_pedida(float(k) / 75.0).z
		rho_min = minf(rho_min, pz)
		rho_max = maxf(rho_max, pz)
	_ok(rho_max * escala >= 0.5, "trazar: el sello que dibuja la punta mide %.2f u de radio en el juego (objetivo ≥ 0,5)" % (rho_max * escala))
	_ok(rho_min > 0.25, "trazar: la punta nunca pasa a menos de %.2f del cuerpo" % rho_min)
	_ok(maxy < PUNTA_SUELO_MAX, "trazar: la punta roza el suelo en los barridos (máx %.3f u de juego < %.2f)" % [maxy, PUNTA_SUELO_MAX])
	_ok(peor_pedida < COINCIDE_MAX, "trazar: la punta pasa por los trazos de la runa (desvío máx %.4f u del modelo)" % peor_pedida)
	var miny: float = 9.0
	for k in range(76):
		miny = minf(miny, AnimacionesChaman.punta_de_clip(sk, cl["trazar"], float(k) / 30.0).y)
	_ok(miny > -0.01, "trazar: la punta no atraviesa el suelo (mín %.4f)" % miny)
	var y_imp: float = AnimacionesChaman.punta_de_clip(sk, cl["clavar"], AnimacionesChaman.INSTANTE_CLAVAR).y * escala
	var y_arriba: float = AnimacionesChaman.punta_de_clip(sk, cl["clavar"], AnimacionesChaman.T_CLAVAR_ALZADO).y * escala
	_ok(y_imp < PUNTA_IMPACTO_MAX, "clavar: toca el suelo en INSTANTE_CLAVAR (%.4f u)" % y_imp)
	_ok(y_arriba > y_imp + 0.02, "clavar: arriba la punta está en el aire (%.3f u) y baja hasta el suelo (%.3f)" % [y_arriba, y_imp])
	var orbe_arriba: float = AnimacionesChaman.orbe_de_clip(sk, cl["clavar"], AnimacionesChaman.T_CLAVAR_ALZADO).y * escala
	_ok(orbe_arriba > 0.55 * ALTO_JUEGO, "clavar: el orbe sube a %.2f u (hat 0,85)" % orbe_arriba)
	var o_ini: Vector3 = AnimacionesChaman.orbe_de_clip(sk, cl["lanzar"], 0.30)
	var o_fin: Vector3 = AnimacionesChaman.orbe_de_clip(sk, cl["lanzar"], AnimacionesChaman.INSTANTE_LANZAR)
	_ok(o_fin.z > o_ini.z + 0.15, "lanzar: el orbe pasa de atrás (z %.2f) a delante (z %.2f) al soltar" % [o_ini.z, o_fin.z])
	# el bastón MONTADO (pieza de Equipo3D agarrada) coincide con la punta que calcula el clip (con el grafo completo: `pose_fija` no entra en el reducido)
	p.grafo = ArbolAnimPj.GRAFO_HEROE
	p.agarrar_baston(true, 0.0)
	p.pose_fija("trazar", 0.4)
	for i in 8:
		await process_frame
	var peor_montado: float = 0.0
	for par in [["trazar", 0.4], ["trazar", 1.1], ["trazar", 1.8], ["clavar", 0.3], ["clavar", 0.62], ["lanzar", 0.55]]:
		p.pose_fija(String(par[0]), float(par[1]))
		for i in 3:
			await process_frame
		var calc: Vector3 = AnimacionesChaman.punta_de_clip(sk, p._ap.get_animation(p.clip_de(String(par[0]))), float(par[1]))
		var real: Vector3 = sk.global_transform.affine_inverse() * bas.punta_global()
		peor_montado = maxf(peor_montado, (calc - real).length())
	_ok(peor_montado < 0.01, "el bastón montado en la mano coincide con la punta calculada (desvío máx %.4f)" % peor_montado)
	var dedos_d: Dictionary = {}
	for par in [["trazar", 1.0], ["clavar", 0.62]]:
		p.pose_fija(String(par[0]), float(par[1]))
		for i in 3:
			await process_frame
		var rig := AnimacionesChaman._Rig.new(sk)
		var est: Dictionary = (AnimacionesChaman._estado_trazar_t(float(par[1])) if par[0] == "trazar" else AnimacionesChaman._estado_clavar(float(par[1])))
		var res: Dictionary = rig.resolver(est)[3]
		dedos_d[par[0]] = maxf(res["res_d"], res["res_i"])
	_ok(float(dedos_d["trazar"]) < 0.02 and float(dedos_d["clavar"]) < 0.05, "las dos manos alcanzan el bastón (desvío trazar %.3f, clavar %.3f u del modelo)" % [dedos_d["trazar"], dedos_d["clavar"]])
	# pies clavados al trazar: el pie no se mueve respecto a su reposo
	var pie_ok: bool = true
	for k in range(0, 76, 10):
		var f: Array = AnimacionesChaman._Rig.new(sk).fk_clip(cl["trazar"], float(k) / 30.0)
		var ix: int = sk.find_bone("mixamorig_RightFoot")
		if ((f[1] as Array)[ix] as Vector3).distance_to(sk.get_bone_global_rest(ix).origin) > 0.004:
			pie_ok = false
	_ok(pie_ok, "trazar: los pies no se mueven (IK de piernas)")

	# --- RunaSuelo3D ---
	_ok(TrazosRitual.trazos().size() == 2 and (TrazosRitual.trazos()[1] as Dictionary)["nombre"] == "rombo", "los trazos son el sello y el ROMBO (el gesto de la barrera)")
	var rombo: PackedVector2Array = (TrazosRitual.trazos()[1] as Dictionary)["puntos"]
	var esquinas: int = 0
	for q in rombo:
		if absf(absf(q.x) - TrazosRitual.RADIO_ROMBO) < 0.06 and absf(q.y) < 0.1 or absf(absf(q.y) - TrazosRitual.RADIO_ROMBO) < 0.06 and absf(q.x) < 0.1:
			esquinas += 1
	_ok(rombo.size() >= 5 and esquinas >= 3, "el rombo viene del gesto de la biblioteca (%d puntos, %d en las esquinas)" % [rombo.size(), esquinas])
	var runa := RunaSuelo3D.crear(mundo, Vector3(3, 0, 3), 0.0)
	var visto: Array = [0, 0, 0.0]
	runa.activada.connect(func() -> void: visto[0] += 1)
	runa.cancelada.connect(func() -> void: visto[1] += 1)
	runa.onda_avanza.connect(func(r: float) -> void: visto[2] = maxf(visto[2], r))
	runa.progreso(0.2)
	await process_frame
	_ok(runa.u_dibujado == 0.2 and not runa.completa(), "a 0,2 la runa está a medias (sello)")
	runa.progreso(0.5)
	_ok(not runa.completa(), "a 0,5 el rombo va por la mitad")
	runa.progreso(1.0)
	_ok(runa.completa(), "a 1,0 la runa está completa (sello y rombo)")
	runa.punta_mundo(Vector3(3.3, 0, 3.0), true)
	runa.punta_mundo(Vector3(3.3, 0, 3.4), true)
	runa.punta_mundo(Vector3(3.3, 0.03, 3.5), false)
	runa.punta_mundo(Vector3(3.0, 0, 3.5), true)
	_ok(runa.trazos.size() == 2 and (runa.trazos[0] as PackedVector3Array).size() == 2, "la línea la escribe la punta: un trazo por cada vez que baja al suelo")
	runa.activar()
	for i in 20:
		await process_frame
	_ok(visto[0] == 1 and runa.estado == "activa", "activar emite `activada` y arranca la onda")
	_ok(runa.escala_dibujo > 2.0, "al activar el dibujo se AMPLÍA hacia el sello grande (×%.1f)" % runa.escala_dibujo)
	_ok(visto[2] > 2.0 * Terreno3D.casilla, "la onda crece más allá de 2 casillas (%.1f u de %.1f)" % [visto[2], RunaSuelo3D.ONDA_CASILLAS * Terreno3D.casilla])
	for i in 60:
		await process_frame
	_ok(not is_instance_valid(runa) or runa.is_queued_for_deletion(), "tras la onda la runa se desvanece y se borra")
	var runa2 := RunaSuelo3D.crear(mundo, Vector3(-3, 0, 3), 0.0)
	runa2.cancelada.connect(func() -> void: visto[1] += 1)
	runa2.progreso(0.5)
	runa2.cancelar()
	await process_frame
	_ok(visto[1] == 1 and runa2.estado == "cancelada", "cancelar emite `cancelada`")
	runa2.activar()
	_ok(visto[0] == 1, "una runa cancelada ya no se activa")
	for i in 40:
		await process_frame
	_ok(not is_instance_valid(runa2) or runa2.is_queued_for_deletion(), "la runa cancelada se apaga y se borra")
	# --- el ritual completo ---
	var ritual := ChamanRitual.iniciar(p, mundo)
	_ok(ritual != null, "ChamanRitual arranca sobre el Pj3D")
	var act: Array = [false, false]
	ritual.activado.connect(func() -> void: act[0] = true)
	ritual.terminado.connect(func() -> void: act[1] = true)
	var t: float = 0.0
	while t < 6.0 and not act[1]:
		await process_frame
		t += 1.0 / 30.0
	_ok(act[0] and act[1], "ritual: trazar -> clavar -> activar -> terminado (%.2f s)" % t)
	_ok(absf(t - (AnimacionesChaman.DUR_TRAZAR + AnimacionesChaman.DUR_CLAVAR + ChamanRitual.DESCANSO_FIN)) < 0.2, "dura trazar + clavar + descanso")
	var r2 := ChamanRitual.iniciar(p, mundo)
	var rota: Array = [false]
	r2.interrumpido.connect(func() -> void: rota[0] = true)
	for i in 30:
		await process_frame
	r2.interrumpir()
	_ok(rota[0] and bas.energia_orbe == 0.0, "interrumpir: runa rota, orbe apagado")
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)
