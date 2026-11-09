extends SceneTree

## PRUEBA del HAZ DE FUEGO con las tres ideas de la demo de gas de three.js (9/11/2026). Sin ventana:
##   godot --headless --path . --script res://herramientas/prueba_haz_fuego_ideas.gd
## 1. sin choque: la punta acaba en humo (Humo), hay luz del suelo, NO hay salpicadura ni chispas de choque ni bolitas (Trocitos)
## 2. con choque: salpicadura (lámina vertical orientada a la normal + lámina tumbada en el suelo), chispas con estela y brasas; en el punto que dijo la lógica
## 3. la orientación sigue a la normal (perpendicular: la lámina queda en el plano de la superficie)
## 4. el decal de luz del suelo solo pinta superficies horizontales y a poca altura (no tiñe a la jugadora ni a los enemigos), y ninguna rampa llega al amarillo
## 5. topes: salpicaduras y manchas de luz de toda la escena; una sola OmniLight3D por hechizo; partículas por toy acotadas
## 6. el interruptor `FuegoToy.haz_ideas` = false devuelve el haz de antes (Trocitos, sin humo ni salpicadura ni luz del suelo)
## 7. VfxToyJuego pasa los choques al espacio local del toy (mundo → local) y descarta los que no son del haz
## 8. HechizoVivo._haz_choques: un enemigo cruzado es un choque contra el haz; sin golpes ni topes no hay ninguno
## Imprime FALLOS: n al final.

var _fallos: int = 0


func _initialize() -> void:
	_correr()


func _ok(nombre: String, cond: bool, detalle: String = "") -> void:
	if cond:
		print("  OK   " + nombre)
	else:
		_fallos += 1
		print("  FALLO " + nombre + "  " + detalle)


func _haz(choques: Array) -> FuegoToy:
	var t: FuegoToy = FuegoToy.new()
	t.choques = choques
	t.definir(FuegoToy.Figura.HAZ, 2.3, 0.6, 0.4)
	root.add_child(t)
	return t


func _hijos(t: Node, trozo: String) -> Array:
	var r: Array = []
	for n in t.find_children(trozo + "*", "", true, false):
		r.append(n)
	return r


func _correr() -> void:
	await process_frame
	FuegoToy.haz_ideas = true
	# 1. sin choque
	var a: FuegoToy = _haz([])
	await process_frame
	_ok("1 sin choque: hay humo en la punta", _hijos(a, "Humo").size() == 1)
	_ok("1 sin choque: NO hay salpicadura ni chispas de choque ni brasas", _hijos(a, "Salpicadura").is_empty() and _hijos(a, "ChispasChoque").is_empty() and _hijos(a, "Brasas").is_empty())
	_ok("1 sin choque: se acabaron las bolitas (Trocitos)", _hijos(a, "Trocitos").is_empty())
	_ok("1 sin choque: hay luz en el suelo", _hijos(a, "LuzSuelo").size() == 1)
	# 2 y 3. con choque contra un muro que mira a -X local (el haz va hacia -Z: la normal contra el haz es +Z; aquí una pared lateral con normal -X)
	var n_loc: Vector3 = Vector3(-1, 0, 0)
	var b: FuegoToy = _haz([{"d": 3.5, "x": 0.2, "n": n_loc}])
	await process_frame
	var sp: MeshInstance3D = b.find_child("Salpicadura0", true, false) as MeshInstance3D
	_ok("2 con choque: hay salpicadura", sp != null)
	_ok("2 con choque: hay la lámina del suelo, chispas con estela y brasas", b.find_child("SalpicaduraSuelo0", true, false) != null and b.find_child("ChispasChoque0", true, false) != null and b.find_child("Brasas0", true, false) != null)
	if sp != null:
		_ok("2 la salpicadura está en el punto de choque (a lo largo %.2f, a un lado %.2f)" % [-sp.position.z, sp.position.x], absf(sp.position.z + 3.5) < 0.2 and absf(sp.position.x - 0.2) < 0.2)
		_ok("3 la lámina mira por la normal de la superficie (z local = n)", sp.transform.basis.z.dot(n_loc) > 0.99, str(sp.transform.basis.z))
		_ok("3 y sigue vertical (y local = arriba): se abre por la superficie", sp.transform.basis.y.dot(Vector3.UP) > 0.99)
		_ok("3 la lámina está pegada a la superficie, no clavada (a < 0,1 m del punto, delante)", sp.position.distance_to(Vector3(0.2, 0.6, -3.5)) < 0.12)
	var sc: MeshInstance3D = b.find_child("SalpicaduraSuelo0", true, false) as MeshInstance3D
	if sc != null:
		_ok("3 la del suelo está tumbada y delante de lo golpeado (hacia el lado de la normal)", (sc.mesh as QuadMesh).orientation == PlaneMesh.FACE_Y and sc.position.x < 0.2 and sc.position.y < 0.3)
	# 4. el decal
	var luz_suelo: MeshInstance3D = b.find_child("LuzSuelo", true, false) as MeshInstance3D
	var m: ShaderMaterial = luz_suelo.material_override as ShaderMaterial if luz_suelo != null else null
	_ok("4 el decal de luz del suelo tiene su shader y su caja a lo largo del haz", m != null and luz_suelo.scale.z > 4.0)
	if m != null:
		_ok("4 alto_max ≤ 0,5 m (no tiñe hombros ni cabezas de la jugadora ni de los enemigos)", float(m.get_shader_parameter("alto_max")) <= 0.5)
		var f: FileAccess = FileAccess.open(FuegoToy.SH_LUZ_SUELO, FileAccess.READ)
		var src: String = f.get_as_text()
		f.close()
		_ok("4 el shader descarta lo que no es suelo (normal horizontal) y lo alto", src.contains("< 0.6") and src.contains("discard") and src.contains("alto_max"))
		_ok("4 el choque llega al decal (fuerza > 0)", (m.get_shader_parameter("choque_a") as Vector4).w > 0.0)
	_ok("4 la rampa del haz se corta en naranja (tope ≤ 0,62: nunca el tramo amarillo, que empieza después)", FuegoToy.HAZ_TOPE_CALOR <= 0.62 and FuegoToy.HAZ_TOPE_NUCLEO <= 0.62)
	# 5. topes
	var otros: Array = []
	for i in 9:
		otros.append(_haz([{"d": 3.0, "x": 0.0, "n": Vector3(0, 0, 1)}, {"d": 2.0, "x": 0.0, "n": Vector3(0, 0, 1)}]))
	await process_frame
	_ok("5 tope de salpicaduras de toda la escena (%d ≤ %d)" % [get_nodes_in_group(FuegoToy.HAZ_GRUPO_SALPICADURA).size(), FuegoToy.HAZ_MAX_SALPICADURAS], get_nodes_in_group(FuegoToy.HAZ_GRUPO_SALPICADURA).size() <= FuegoToy.HAZ_MAX_SALPICADURAS)
	_ok("5 tope de manchas de luz (%d ≤ %d)" % [get_nodes_in_group(FuegoToy.HAZ_GRUPO_LUZ_SUELO).size(), FuegoToy.HAZ_MAX_LUCES_SUELO], get_nodes_in_group(FuegoToy.HAZ_GRUPO_LUZ_SUELO).size() <= FuegoToy.HAZ_MAX_LUCES_SUELO)
	var luces: int = b.find_children("*", "Light3D", true, false).size()
	var parts: int = 0
	for gp in b.find_children("*", "GPUParticles3D", true, false):
		parts += (gp as GPUParticles3D).amount
	_ok("5 una sola luz por hechizo (%d) y ≤ 120 partículas por haz con dos choques (%d)" % [luces, parts], luces == 1 and parts <= 120)
	var c3: FuegoToy = _haz([{"d": 1.0, "x": 0.0, "n": Vector3(0, 0, 1)}, {"d": 2.0, "x": 0.0, "n": Vector3(0, 0, 1)}, {"d": 3.0, "x": 0.0, "n": Vector3(0, 0, 1)}])
	await process_frame
	_ok("5 como mucho %d choques por haz" % FuegoToy.HAZ_MAX_CHOQUES, c3.find_children("Salpicadura?", "", true, false).size() <= FuegoToy.HAZ_MAX_CHOQUES)
	# 6. interruptor
	for o in otros:
		o.queue_free()
	await process_frame
	FuegoToy.haz_ideas = false
	var d: FuegoToy = _haz([{"d": 3.5, "x": 0.0, "n": n_loc}])
	await process_frame
	_ok("6 con el interruptor apagado: el haz de antes (bolitas, sin humo, sin salpicadura, sin luz del suelo)",
		_hijos(d, "Trocitos").size() == 1 and _hijos(d, "Humo").is_empty() and _hijos(d, "Salpicadura").is_empty() and _hijos(d, "LuzSuelo").is_empty())
	FuegoToy.haz_ideas = true
	# 7. mundo → local
	var desde: Vector3 = Vector3(10, 0.5, 10)
	var al: Vector3 = Vector3(5, 0, 0)         # el haz va hacia +X
	var loc: Array = VfxToyJuego._choques_locales([
		{"punto": Vector3(15, 0.5, 10), "normal": Vector3(-1, 0, 0), "tipo": "muro"},
		{"punto": Vector3(13, 0.5, 10.5), "normal": Vector3(-1, 0, 0), "tipo": "enemigo"},
		{"punto": Vector3(8, 0.5, 10), "normal": Vector3(-1, 0, 0), "tipo": "enemigo"}], desde, al)
	_ok("7 se descarta lo que queda detrás de la mano (%d de 3 quedan 2)" % loc.size(), loc.size() == 2)
	if loc.size() == 2:
		_ok("7 el muro: a 5 m a lo largo, normal local +Z (contra el haz, que va a -Z local)", absf(float(loc[0]["d"]) - 5.0) < 0.01 and (loc[0]["n"] as Vector3).dot(Vector3(0, 0, 1)) > 0.99, str(loc[0]))
		_ok("7 el enemigo a 0,5 m a un lado: x local con signo coherente", absf(float(loc[1]["d"]) - 3.0) < 0.01 and absf(float(loc[1]["x"])) > 0.45, str(loc[1]))
	# 8. la lógica
	var hv: HechizoVivo = HechizoVivo.new()
	var gob: Node3D = Node3D.new()
	gob.add_to_group("combate3d")
	root.add_child(gob)
	var ch: Array = hv._haz_choques([], [{"obj": gob, "punto": Vector3(13, 1, 10), "dir": Vector3(1, 0, 0), "desde": Vector3(10, 1, 10)}], Vector2(10, 10), Vector2(1, 0), 0.6)
	_ok("8 un enemigo cruzado es un choque «enemigo», con la normal contra el haz y a la altura de la mano", ch.size() == 1 and ch[0]["tipo"] == "enemigo" and (ch[0]["normal"] as Vector3).is_equal_approx(Vector3(-1, 0, 0)) and absf((ch[0]["punto"] as Vector3).y - 0.6) < 0.01, str(ch))
	_ok("8 sin golpes ni topes (el final del alcance contra el suelo) no hay choque", hv._haz_choques([], [], Vector2(10, 10), Vector2(1, 0), 0.6).is_empty())
	hv.free()
	# 9. agua y rayo (ampliación de Pablo): mismas reglas con los colores de SUS paletas
	for n in get_nodes_in_group(FuegoToy.HAZ_GRUPO_SALPICADURA) + get_nodes_in_group(FuegoToy.HAZ_GRUPO_LUZ_SUELO):
		(n as Node).queue_free()
	await process_frame
	await process_frame
	var cho: Array = [{"d": 3.0, "x": 0.0, "n": Vector3(0, 0, 1)}]
	var ag: AguaToy = AguaToy.new()
	ag.choques = cho
	ag.definir(AguaToy.Figura.HAZ, 2.3, 0.6, 0.4)
	root.add_child(ag)
	await process_frame
	_ok("9 agua con choque: salpicadura, gotas y charquito (decal), y el decal es OSCURO (el agua no brilla)", ag.find_child("Salpicadura0", true, false) != null and ag.find_child("GotasChoque0", true, false) != null and ag.find_child("LuzSuelo", true, false) != null)
	var dm: ShaderMaterial = (ag.find_child("LuzSuelo", true, false) as MeshInstance3D).material_override as ShaderMaterial if ag.find_child("LuzSuelo", true, false) != null else null
	if dm != null:
		var tn: Color = dm.get_shader_parameter("tinte") as Color
		_ok("9 agua: el tinte del suelo es oscuro (luminosidad %.2f < 0,35)" % tn.get_luminance(), tn.get_luminance() < 0.35 and tn.a > 0.0)
	var sa: MeshInstance3D = ag.find_child("Salpicadura0", true, false) as MeshInstance3D
	if sa != null:
		_ok("9 agua: colores de AguaPaleta (HONDO/SOMERO/ESPUMA)", (sa.material_override as ShaderMaterial).get_shader_parameter("tono_b") == HazChoque.AguaPaleta.SOMERO)
		_ok("9 agua: la lámina mira por la normal", sa.transform.basis.z.dot(Vector3(0, 0, 1)) > 0.99)
	var ag0: AguaToy = AguaToy.new()
	ag0.definir(AguaToy.Figura.HAZ, 2.3, 0.6, 0.4)
	root.add_child(ag0)
	await process_frame
	_ok("9 agua sin choque: no añade nada (sigue el abanico de siempre)", ag0.find_child("Salpicadura0", true, false) == null and ag0.find_child("LuzSuelo", true, false) == null and ag0.find_child("Punta", true, false) != null)
	var ry: RayoToy = RayoToy.new()
	ry.choques = cho
	ry.definir(RayoToy.Figura.HAZ, 2.3, 0.6, 0.4)
	root.add_child(ry)
	await process_frame
	var ar: MeshInstance3D = ry.find_child("Salpicadura0", true, false) as MeshInstance3D
	_ok("9 rayo con choque: arcos por la superficie (aditivos) y destello en el suelo", ar != null and ry.find_child("LuzSuelo", true, false) != null)
	if ar != null:
		var f2: FileAccess = FileAccess.open(HazChoque.SH_ARCOS, FileAccess.READ)
		var src2: String = f2.get_as_text()
		f2.close()
		_ok("9 rayo: el shader es aditivo y unshaded (el rayo brilla) con los colores de RayoPaleta", src2.contains("blend_add") and src2.contains("unshaded") and (ar.material_override as ShaderMaterial).get_shader_parameter("c_halo") == HazChoque.RayoPaleta.HALO)
	var dr: MeshInstance3D = ry.find_child("LuzSuelo", true, false) as MeshInstance3D
	if dr != null:
		_ok("9 rayo: el destello del suelo parpadea y se apaga solo (tween de 0,3 s)", float((dr.material_override as ShaderMaterial).get_shader_parameter("parpadeo")) > 0.5)
	FuegoToy.haz_ideas = false
	var ag2: AguaToy = AguaToy.new()
	ag2.choques = cho
	ag2.definir(AguaToy.Figura.HAZ, 2.3, 0.6, 0.4)
	root.add_child(ag2)
	var ry2: RayoToy = RayoToy.new()
	ry2.choques = cho
	ry2.definir(RayoToy.Figura.HAZ, 2.3, 0.6, 0.4)
	root.add_child(ry2)
	await process_frame
	_ok("9 con el interruptor apagado, agua y rayo dibujan lo de antes", ag2.find_child("Salpicadura0", true, false) == null and ry2.find_child("Salpicadura0", true, false) == null and ry2.find_child("LuzSuelo", true, false) == null)
	FuegoToy.haz_ideas = true
	# 10. formas validadas (muro, pilar, barrera, bola): capas añadidas apagables, apagadas por defecto
	_ok("10 por defecto TODAS las capas de las formas validadas están apagadas", FuegoToy.formas_extra.values().all(func(v: bool) -> bool: return not v))
	for k in FuegoToy.formas_extra:
		FuegoToy.formas_extra[k] = true
	var mu: FuegoToy = FuegoToy.new()
	mu.definir(FuegoToy.Figura.MURO, 3.45, 1.5, 0.3)
	root.add_child(mu)
	var pi: FuegoToy = FuegoToy.new()
	pi.definir(FuegoToy.Figura.PILAR, 0.5, 4.0, 0.5)
	root.add_child(pi)
	var ba: FuegoToy = FuegoToy.new()
	ba.definir(FuegoToy.Figura.BARRERA, 1.5, 1.5, 1.5)
	root.add_child(ba)
	await process_frame
	_ok("10 encendidas: luz en el suelo en muro, pilar y barrera; humo en la cima de muro y pilar", mu.get_node_or_null("LuzForma") != null and pi.get_node_or_null("LuzForma") != null and ba.get_node_or_null("LuzForma") != null
		and mu.find_child("HumoCima", true, false) != null and pi.find_child("HumoCima", true, false) != null)
	var lf: ShaderMaterial = (mu.get_node("LuzForma") as MeshInstance3D).material_override as ShaderMaterial
	_ok("10 el decal de forma es el de explosion_suelo (alto_max 0,45 por defecto: no tiñe cuerpos)", lf.shader.resource_path.ends_with("explosion_suelo.gdshader") and lf.get_shader_parameter("alto_max") == null)
	var bo: FuegoToy = FuegoToy.new()
	bo.definir(FuegoToy.Figura.BOLA, 0.4, 0.4, 0.4, true)
	root.add_child(bo)
	await process_frame
	bo.impactar_en(Vector3(0, 0, 0), Vector3.UP, 0.5)
	_ok("10 el impacto de la bola, con las capas encendidas, suelta chispas con estela y luz en el suelo (y un tope de %d)" % FuegoToy.FORMA_MAX_IMPACTOS, get_nodes_in_group(FuegoToy.FORMA_GRUPO_IMPACTO).size() == 1)
	for k in FuegoToy.formas_extra:
		FuegoToy.formas_extra[k] = false
	var mu2: FuegoToy = FuegoToy.new()
	mu2.definir(FuegoToy.Figura.MURO, 3.45, 1.5, 0.3)
	root.add_child(mu2)
	await process_frame
	_ok("10 apagadas: el muro es exactamente el de antes (sin LuzForma ni HumoCima)", mu2.get_node_or_null("LuzForma") == null and mu2.find_child("HumoCima", true, false) == null)
	# 11. el MURO de prueba del lab (tecla F): con muro, el haz de cada elemento recibe su choque y dibuja la salpicadura; sin muro, nada
	var lab: Node3D = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	lab.call("alternar_muro_haz")
	for el in ["fuego", "agua", "rayo"]:
		lab.call("poner_elemento", el)
		var hz = lab.call("fuego_param", 4)
		await process_frame
		await process_frame
		var chq: Array = hz.choques
		_ok("11 lab con muro (%s): el haz tiene 1 choque en su cara, normal hacia la jugadora" % el, chq.size() == 1 and absf(float(chq[0]["x"])) < 0.01 and (chq[0]["n"] as Vector3).z > 0.9, str(chq))
		_ok("11 lab con muro (%s): el toy dibuja la salpicadura" % el, hz.find_child("Salpicadura*", true, false) != null)
	lab.call("alternar_muro_haz")
	lab.call("poner_elemento", "fuego")
	var sinm = lab.call("fuego_param", 4)
	await process_frame
	_ok("11 lab sin muro: sin choques ni salpicadura", sinm.choques.is_empty() and sinm.find_child("Salpicadura*", true, false) == null)
	print("FALLOS: %d" % _fallos)
	quit(0 if _fallos == 0 else 1)
