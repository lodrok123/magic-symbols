extends SceneTree
## PRUEBA DEL RAYO A LA ALTURA DE LA REFERENCIA EN VÍDEO (5/11/2026, rama claude/vfx-rayo-ref). Sin ventana. Comprueba lo que se añadió al RayoToy: el SELLO del pilar y de la zona, el pilar que CAE del cielo hasta el
## suelo y se ramifica, el HAZ recto de la mano al final con hélices a su alrededor, el MURO de arcos verticales sobre una línea en el suelo, la ESTELA recta de la bola, la MARCA DE GRIETAS del impacto, el ESTADO ELECTRIFICADO
## (en una entidad y en el agua del suelo, con el reloj oficial de 2 s) y que el rayo está encendido de serie. Imprime FALLOS: n.

var _fallos: int = 0
var _raiz: Node3D = null


func _initialize() -> void:
	_correr()


func _ok(nombre: String, bien: bool) -> void:
	print(("  OK    " if bien else "  FALLO ") + nombre)
	if not bien:
		_fallos += 1


func _correr() -> void:
	_raiz = Node3D.new()
	root.add_child(_raiz)
	await process_frame
	_ok("0 el rayo está encendido de serie (project.godot: fuego,agua,rayo)", VfxToyJuego.elementos_activos().has("rayo") and VfxToyJuego.ELEMENTOS_DEFECTO.contains("rayo"))
	# ---- PILAR: cae del cielo, sello, raíces
	var p: RayoToy = RayoToy.new()
	_raiz.add_child(p)
	p.definir(RayoToy.Figura.PILAR, 0.3, 4.0, 0.3, false)
	await process_frame
	p.lanzar(-1.0)
	p.crece = 0.3
	p._redibujar(true)
	var ymin3: float = 99.0
	for s in p.trazos_actuales():
		if float(s["alfa"]) < 0.05:
			continue
		ymin3 = minf(ymin3, minf((s["a"] as Vector3).y, (s["b"] as Vector3).y))
	p.crece = 1.0
	p._redibujar(true)
	var ymin: float = 99.0
	var ymax: float = -99.0
	var raices: int = 0
	for s in p.trazos_actuales():
		if float(s["alfa"]) < 0.05:
			continue
		var a: Vector3 = s["a"]
		var b: Vector3 = s["b"]
		ymin = minf(ymin, minf(a.y, b.y))
		ymax = maxf(ymax, maxf(a.y, b.y))
		if maxf(a.y, b.y) < 0.2 and maxf(a.length(), b.length()) > 0.3:
			raices += 1
	_ok("[PILAR] cae: con crece 0,3 no ha llegado abajo (y mín %.2f) y con 1,0 toca el suelo (y mín %.2f, cima %.2f)" % [ymin3, ymin, ymax], ymin3 > 1.0 and ymin < 0.2 and ymax > 3.5)
	_ok("[PILAR] se ramifica al tocar el suelo: %d tramos de raíz a ras de tierra" % raices, raices >= 5)
	_ok("[PILAR] lleva sello circular en el suelo (radio %.2f m)" % p.radio_sello(), p.sello() != null and p.radio_sello() >= 0.9 and is_equal_approx(p.sello().position.y, 0.0))
	p.queue_free()
	# ---- ZONA: sello y descargas que caen
	var z: RayoToy = RayoToy.new()
	_raiz.add_child(z)
	z.definir(RayoToy.Figura.BOLA, 1.2, 1.2, 1.2, false)
	z.area_al_impactar = true
	await process_frame
	z.lanzar(-1.0)
	var cae: int = 0
	for i in 40:
		z._redibujar(true)
		for s in z.trazos_actuales():
			if absf((s["a"] as Vector3).y - (s["b"] as Vector3).y) > 0.25 and maxf((s["a"] as Vector3).y, (s["b"] as Vector3).y) > 1.5:
				cae += 1
				break
	_ok("[AREA] zona con sello (radio %.2f) y descargas que caen del cielo (%d de 40 redibujos)" % [z.radio_sello(), cae], z.sello() != null and z.radio_sello() >= 1.2 and cae >= 8)
	z.queue_free()
	# ---- HAZ: recto de la mano al final, con hélices
	var h: RayoToy = RayoToy.new()
	_raiz.add_child(h)
	h.definir(RayoToy.Figura.HAZ, 1.5, 0.9, 0.15, false)
	await process_frame
	h.lanzar(-1.0)
	h.crece = 1.0
	h._redibujar(true)
	var tubo: Dictionary = {}
	var zmin: float = 0.0
	var fuera: float = 0.0
	for s in h.trazos_actuales():
		var a: Vector3 = s["a"]
		var b: Vector3 = s["b"]
		zmin = minf(zmin, minf(a.z, b.z))
		fuera = maxf(fuera, maxf(absf(a.x), absf(b.x)))
		if absf(a.x) < 0.001 and absf(b.x) < 0.001 and absf(a.z - b.z) > 2.9 and tubo.is_empty():
			tubo = s
	_ok("[HAZ] tubo recto de la mano (z 0) al final (z %.2f) y largo %.2f" % [float(tubo["b"].z) if not tubo.is_empty() else 0.0, 3.0], not tubo.is_empty() and absf(float(tubo["a"].z)) < 0.01 and absf(float(tubo["b"].z) + 3.0) < 0.01)
	_ok("[HAZ] hélices que se enroscan alrededor (desvío lateral máx %.2f m)" % fuera, fuera > 0.05 and fuera < 0.6)
	var bril_ext: int = 0
	for b2 in h.brillos_actuales():
		if absf(float(b2["pos"].z)) < 0.01 or absf(float(b2["pos"].z) + 3.0) < 0.01:
			bril_ext += 1
	_ok("[HAZ] destellos en los dos extremos (%d)" % bril_ext, bril_ext >= 2)
	h.queue_free()
	# ---- MURO: línea brillante recta en el suelo y arcos verticales densos
	var m: RayoToy = RayoToy.new()
	_raiz.add_child(m)
	m.definir(RayoToy.Figura.MURO, 1.0, 1.0, 0.1, false)
	await process_frame
	m.lanzar(-1.0)
	m.crece = 1.0
	m._redibujar(true)
	var linea: bool = false
	var verticales: int = 0
	for s in m.trazos_actuales():
		var a: Vector3 = s["a"]
		var b: Vector3 = s["b"]
		if a.y < 0.1 and b.y < 0.1 and absf(a.x - b.x) > 1.8:
			linea = true
		if b.y - a.y > 0.1 and absf(a.x - b.x) < 0.2:
			verticales += 1
	_ok("[MURO] línea brillante recta en el suelo y arcos verticales densos (%d tramos que suben)" % verticales, linea and verticales >= 15)
	m.queue_free()
	# ---- BOLA: estela recta y fina
	var b3: RayoToy = RayoToy.new()
	_raiz.add_child(b3)
	b3.definir(RayoToy.Figura.BOLA, 0.4, 0.4, 0.4, true)
	await process_frame
	b3.lanzar(-1.0)
	await create_timer(0.4).timeout
	var desv: float = 0.0
	var largo: float = 0.0
	for s in b3.trazos_actuales():
		var a: Vector3 = s["a"]
		var b: Vector3 = s["b"]
		if a.z > 0.95 and b.z > 0.95:
			desv = maxf(desv, maxf(maxf(absf(a.x), absf(a.y)), maxf(absf(b.x), absf(b.y))))
			largo = maxf(largo, maxf(a.z, b.z))
	_ok("[BOLA] estela recta y fina detrás (largo hasta z %.2f, desvío máx %.2f m)" % [largo, desv], largo > 0.9 and desv < 0.14)
	b3.queue_free()
	# ---- IMPACTO: marca de grietas
	var imp: ImpactoRayoToy = ImpactoRayoToy.crear(ImpactoRayoToy.Variante.GOLPE, Vector3.UP, 0.3)
	_raiz.add_child(imp)
	await process_frame
	imp.avanzar_a(0.3)
	var gr: MultiMeshInstance3D = imp.find_child("Grietas", true, false) as MultiMeshInstance3D
	var vis: int = 0
	if gr != null:
		for i in gr.multimesh.instance_count:
			if gr.multimesh.get_instance_transform(i).basis.get_scale().length() > 0.0001:
				vis += 1
	_ok("[IMPACTO] deja una marca de grietas en el suelo (%d tramos) y dura menos de 1 s (%.2f s)" % [vis, imp.duracion()], vis >= 30 and imp.duracion() <= 1.0)
	imp.queue_free()
	# ---- ESTADO ELECTRIFICADO
	var mundo: Mundo3D = Mundo3D.new()
	_raiz.add_child(mundo)
	await process_frame
	var tj: VfxToyJuego = VfxToyJuego.conectar(null, _raiz)
	_ok("[ESTADO] VfxToyJuego se engancha", tj != null)
	var cuerpo: Node3D = Node3D.new()
	_raiz.add_child(cuerpo)
	mundo.emit_signal("reaccion", "electrocutado", Vector3.ZERO, cuerpo)
	await process_frame
	var est: EstadoRayoToy = cuerpo.get_node_or_null("EstadoElectrificado") as EstadoRayoToy
	_ok("[ESTADO] una descarga pinta el estado electrificado colgado de la entidad", est != null and tj.electrocutados == 1)
	if est != null:
		var picos: int = 0
		var dentro: bool = true
		for i in 30:
			est._redibujar()
			if est.huecos_encendidos() > 0:
				picos += 1
			for s in est.trazos_actuales():
				if maxf((s["a"] as Vector3).y, (s["b"] as Vector3).y) > est.alto + 0.01:
					dentro = false
		_ok("[ESTADO] los arcos recorren la piel (%d de 30 redibujos con arcos) y no se salen del cuerpo" % picos, picos >= 15 and dentro)
		var antes: int = tj.electrocutados
		mundo.emit_signal("reaccion", "electrocutado", Vector3.ZERO, cuerpo)
		_ok("[ESTADO] una descarga nueva lo renueva, no apila otro", tj.electrocutados == antes and cuerpo.find_children("EstadoElectrificado*", "", false, false).size() == 1)
		est.dur = 0.2
		est.renovar(0.2)
		await create_timer(0.6).timeout
		_ok("[ESTADO] dura poco y se libera solo (reloj de la entidad %.1f s)" % VfxToyJuego.T_ENTIDAD_ELECTRICA, not is_instance_valid(est) or est.is_queued_for_deletion())
	var c: Vector2i = Vector2i(3, 3)
	Terreno3D.estados.limpiar()
	Terreno3D.estados.mantener(c, EstadosSuelo3D.ELECTRIFICADA)
	await process_frame
	var ea: EstadoRayoToy = tj.agua_electrica().get(c) as EstadoRayoToy
	_ok("[AGUA] la casilla electrificada se pinta con chispas intermitentes por la superficie", ea != null and ea.modo == EstadoRayoToy.Modo.SUPERFICIE)
	if ea != null:
		var min_h: int = 99
		var max_h: int = 0
		for i in 40:
			ea._redibujar()
			min_h = mini(min_h, ea.huecos_encendidos())
			max_h = maxi(max_h, ea.huecos_encendidos())
		_ok("[AGUA] es intermitente (de %d a %d arcos encendidos a la vez) y está a ras de superficie" % [min_h, max_h], min_h < max_h)
		Terreno3D.estados.avanzar(2.1)       # el reloj oficial: 2 s
		await process_frame
		_ok("[AGUA] al caducar el estado (2 s) se apaga el dibujo", not tj.agua_electrica().has(c) and ea.esta_apagando())
	Terreno3D.estados.limpiar()
	print("FALLOS: %d" % _fallos)
	quit(0 if _fallos == 0 else 1)
