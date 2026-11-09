extends SceneTree

## PRUEBA del viento y la tierra «toy» (6/11/2026; a imagen de prueba_hielo_toy.gd). Sin ventana (los class_name son nuevos: antes, `--headless --import`):
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_viento_tierra_toy.gd
## Comprueba, con VientoToy / ImpactoVientoToy, TierraToy / ImpactoTierraToy y el humo toon (humo_toy.gd):
##   1. ESTILO: los shaders nuevos no son aditivos ni emisivos; el humo toon es blend_mix, unshaded y de borde duro (discard); la roca es opaca, con la textura de las rocas del mapa
##      (rocas_albedo.png) y la luz de la escena (NO unshaded; mate, sin especular), y las figuras usan las mallas piedra_est_* / roca_est_* del mapa (6/11 tarde: «la piedra del mundo»)
##   2. HUMO TOON: una bocanada NACE pequeña, CRECE (~×2,5), se EROSIONA al final (erosion sube con la edad) y MUERE en su vida; deriva en curva
##   3. FIGURAS: las dos clases se crean y las 5 figuras y `desde_hechizo` no fallan; sin luces ni GPUParticles3D; piezas esperadas (cintas, hojas, bloques, roca...)
##   4. TIERRA: los bloques SUBEN del suelo con anticipación, sobrepaso y asentamiento (`subida`), sueltan polvo y fragmentos al asentarse y se HUNDEN al morir; la BARRERA cierra la
##      cúpula con losas de techo y un destello; el HAZ (6/11 noche) brota PÚAS en secuencia de la mano a la punta, de menor a mayor, con lajas y grietas que existen y se van, y se hunde al revés
##   5. CARGA: progreso 0 → 1 sin bajar la escala; convergencia; `soltar` sin salto; `cancelar_carga` libera
##   6. IMPACTOS: `impactar_en` crea el impacto y se libera solo; variantes GOLPE / FIN / REBOTE / AREA; piedras en el hemisferio de la normal que caen; soplo de jirones; sin destello
##   7. API: rebotar, terminar_sin_choque, finalizar; describir / desde_hechizo = los del fuego
##   8. PRESUPUESTO: 0 luces, 0 GPUParticles3D, ≤ 300 instancias de MultiMesh, 0 aditivos, 0 errores de consola
##   9. LAB: Z cicla por viento y tierra; G / B / N / F7 / F9 crean el elemento activo
## Imprime FALLOS: n.

const HumoToy = preload("res://presentacion/vfx/toy/humo_toy.gd")
const MAX_PARTICULAS: int = 300
const FIGURAS: Array = [["BOLA", 0, Vector3(0.4, 0.4, 0.4)], ["MURO", 1, Vector3(3.45, 1.5, 0.3)], ["PILAR", 2, Vector3(0.5, 4.0, 0.5)], ["BARRERA", 3, Vector3(1.5, 1.5, 1.5)], ["HAZ", 4, Vector3(1.5, 0.5, 0.15)]]


class Contador extends Logger:
	var errores: PackedStringArray = []

	func _log_error(_funcion: String, _archivo: String, _linea: int, codigo: String, mensaje: String, _de_editor: bool, _tipo: int, _pila: Array[ScriptBacktrace]) -> void:
		errores.append("%s %s" % [codigo, mensaje])

	func _log_message(_mensaje: String, _es_error: bool) -> void:
		pass


var _fallos: int = 0
var _raiz: Node3D = null
var _max_luces: int = 0
var _max_gpu: int = 0
var _max_part: int = 0
var _aditivos: int = 0
var _log: Contador = null


func _initialize() -> void:
	# Las aserciones de humo y convergencia usan el toy clásico.
	VientoToy.prueba_corrientes = false
	_log = Contador.new()
	OS.add_logger(_log)
	_correr()


func _ok(nombre: String, cond: bool, detalle: String = "") -> void:
	if cond:
		print("  OK   " + nombre)
	else:
		_fallos += 1
		print("  FALLO " + nombre + ("  (" + detalle + ")" if detalle != "" else ""))


func _correr() -> void:
	await process_frame
	_raiz = Node3D.new()
	root.add_child(_raiz)
	_estilo()
	await _humo()
	for cl in ["viento", "tierra"]:
		await _figuras(cl)
		await _carga(cl)
		await _impactos(cl)
		await _api(cl)
	await _tierra_sube()
	await _tierra_haz()
	await _tierra_cupula_y_aviso()
	await _lab()
	print("máximo visto: %d luces, %d GPUParticles3D, %d partículas (MultiMesh), %d materiales aditivos" % [_max_luces, _max_gpu, _max_part, _aditivos])
	_ok("presupuesto: 0 luces, 0 GPUParticles3D, ≤ %d partículas, 0 aditivos" % MAX_PARTICULAS, _max_luces == 0 and _max_gpu == 0 and _max_part <= MAX_PARTICULAS and _aditivos == 0)
	_ok("sin errores de consola (%d)" % _log.errores.size(), _log.errores.is_empty(), "\n    ".join(_log.errores))
	print("FALLOS: %d" % _fallos)
	quit(0 if _fallos == 0 else 1)


## Espera `seg` s de tiempo SIMULADO (con --fixed-fps 30 en headless el reloj de pared va mucho más deprisa que el del juego).
func _esperar(seg: float) -> void:
	var t: float = 0.0
	while t < seg:
		await process_frame
		t += root.get_process_delta_time()
		_medir()


func _medir() -> void:
	var luces: int = 0
	var gpu: int = 0
	var part: int = 0
	var adit: int = 0
	for n in _raiz.find_children("*", "", true, false):
		if n is Light3D and (n as Light3D).is_visible_in_tree():
			luces += 1
		elif n is GPUParticles3D:
			gpu += (n as GPUParticles3D).amount
		elif n is MultiMeshInstance3D:
			part += (n as MultiMeshInstance3D).multimesh.instance_count
		if n is GeometryInstance3D:
			var m: ShaderMaterial = (n as GeometryInstance3D).material_override as ShaderMaterial
			while m != null:
				if m.shader != null and m.shader.code.find("blend_add") >= 0:
					adit += 1
				m = m.next_pass as ShaderMaterial
	_max_luces = maxi(_max_luces, luces)
	_max_gpu = maxi(_max_gpu, gpu)
	_max_part = maxi(_max_part, part)
	_aditivos = maxi(_aditivos, adit)


func _nueva(cl: String) -> Node3D:
	var e: Node3D = VientoToy.new() if cl == "viento" else TierraToy.new()
	_raiz.add_child(e)
	return e


func _escala(e: Node3D) -> float:
	return (e.get_node("Cuerpo") as Node3D).scale.x


func _hay_impacto() -> bool:
	for h in _raiz.get_children():
		if h is ImpactoVientoToy or h is ImpactoTierraToy:
			return true
	return false


func _limpiar_impactos() -> void:
	for h in _raiz.get_children():
		if h is ImpactoVientoToy or h is ImpactoTierraToy:
			h.free()


# ------------------------------------------------------------------ 1. estilo ------------------------------------------------------------------

func _estilo() -> void:
	print("== shaders")
	var codigos: Dictionary = {}
	for s in ["humo_toon.gdshader", "tierra_roca.gdshader", "tierra_grietas.gdshader", "tierra_anillo.gdshader"]:
		var txt: String = FileAccess.get_file_as_string("res://presentacion/vfx/toy/" + s)
		var cuerpo: PackedStringArray = PackedStringArray()
		for l in txt.split("\n"):
			if not l.strip_edges().begins_with("//"):
				cuerpo.append(l)
		codigos[s] = "\n".join(cuerpo)
	var humo: String = codigos["humo_toon.gdshader"]
	_ok("humo_toon: sin blend_add, sin EMISSION, unshaded", humo.find("blend_add") < 0 and humo.find("EMISSION") < 0 and humo.find("unshaded") >= 0)
	_ok("humo_toon: borde duro (discard, ALPHA = 1.0), dos tonos (color_claro / color_sombra), color viejo y erosión por edad", humo.find("discard") >= 0 and humo.find("ALPHA = 1.0") >= 0
		and humo.find("color_sombra") >= 0 and humo.find("color_viejo") >= 0 and humo.find("erosion") >= 0)
	var roca: String = codigos["tierra_roca.gdshader"]
	_ok("tierra_roca: sin blend_add, sin EMISSION, con la LUZ de la escena (no unshaded), mate (ROUGHNESS = 1.0) y sin especular", roca.find("blend_add") < 0 and roca.find("EMISSION") < 0
		and roca.find("unshaded") < 0 and roca.find("ROUGHNESS = 1.0") >= 0 and roca.find("specular_disabled") >= 0)
	_ok("tierra_roca: opaca (no escribe ALPHA) y pinta la TEXTURA de las rocas del mapa (albedo_tex) con un velo (tinte), no color plano", roca.find("ALPHA =") < 0 and roca.find("albedo_tex") >= 0
		and roca.find("texture(albedo_tex, UV)") >= 0 and roca.find("tinte") >= 0)
	_ok("tierra_roca: modo `plano` (color plano pardo para púas y lajas)", roca.find("uniform float plano") >= 0 and roca.find("color_plano") >= 0)
	for s2 in ["tierra_grietas.gdshader", "tierra_anillo.gdshader"]:
		var c2: String = codigos[s2]
		_ok("%s: sin blend_add, sin EMISSION, unshaded, borde duro (discard)" % s2, c2.find("blend_add") < 0 and c2.find("EMISSION") < 0 and c2.find("unshaded") >= 0 and c2.find("discard") >= 0)
	var pua: Mesh = TierraToy.malla_roca("pua_0")
	var laja: Mesh = TierraToy.malla_roca("laja_0")
	# 7/11: las púas ya no son conos generados a mano (≤ 120 vértices) sino las rocas stone5 / stone6 / stone4 del pack de LeLu (arte/rocas_lelu: 426 / 588 / 620 vértices), normalizadas a base en y = 0,
	# alto 1 y radio <= 0,5; por eso el tope POR MALLA es 700. Lo que de verdad acota el coste es el total del haz (comprobación «un HAZ completo» más abajo).
	var v_pua: Array = []
	var puas_ok: bool = true
	for k in 3:
		var mp: Mesh = TierraToy.malla_roca("pua_%d" % k)
		v_pua.append((mp.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
		puas_ok = puas_ok and mp is ArrayMesh and absf(mp.get_aabb().position.y) < 0.001 and absf(mp.get_aabb().size.y - 1.0) < 0.01 and int(v_pua[k]) <= 700 and mp.get_aabb().size.x <= 1.001 and mp.get_aabb().size.z <= 1.001
	_ok("las púas son las rocas stone5 / stone6 / stone4 del pack (pua_0..2: %s vértices, tope 700 por malla), normalizadas (base en y = 0, alto 1, ancho <= 1) y las lajas son mallas propias (laja_0 %d), cacheadas" % [str(v_pua), (laja.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()],
		pua is ArrayMesh and laja is ArrayMesh and puas_ok
		and laja.get_aabb().size.y < 0.2 and TierraToy.malla_roca("pua_0") == pua and TierraToy.es_plana("pua_2") and TierraToy.es_plana("laja_1") and not TierraToy.es_plana("roca_est_1"))
	_ok("las rocas del mapa existen (piedra_est_0..4, roca_est_0..4 y rocas_albedo.png)", ResourceLoader.exists(TierraToy.TEX_ALBEDO) and range(5).all(func(i: int) -> bool: return ResourceLoader.exists(TierraToy.RUTA_ROCA % ("piedra_est_%d" % i)) and ResourceLoader.exists(TierraToy.RUTA_ROCA % ("roca_est_%d" % i))))
	var mb: Mesh = TierraToy.malla_roca("piedra_est_0")
	_ok("malla_roca carga la piedra_est_0 del GLB (%d vértices, base en y = 0, %.2f m de lado) y la cachea" % [(mb.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), TierraToy.lado_malla(mb)],
		mb is ArrayMesh and absf(mb.get_aabb().position.y) < 0.01 and TierraToy.lado_malla(mb) > 0.5 and TierraToy.malla_roca("piedra_est_0") == mb)
	_ok("el ruido del humo existe (T_CloudNoise_Tiled.png)", ResourceLoader.exists(HumoToy.TEX_RUIDO))


# ------------------------------------------------------------------ 2. humo toon ------------------------------------------------------------------

func _humo() -> void:
	print("== humo toon (humo_toy.gd)")
	var h: Node3D = HumoToy.new()
	_raiz.add_child(h)
	h.call("montar", 12, {"tam_ini": 0.2, "tam_fin": 0.5, "vida": 1.0, "deriva": Vector3(0, 1.0, 0), "erosion": 0.8, "curva": 1.5})
	await process_frame
	_ok("capacidad 12, ninguna viva", int(h.call("capacidad")) == 12 and int(h.call("vivas")) == 0)
	var hueco: int = h.call("emitir", Vector3(0, 0, 0), Vector3(1, 0, 0), 1.0, 1.0)
	h.call("avanzar", 0.0)
	var e0: Array = h.call("estados")
	_ok("nace: 1 viva, pequeña (%.2f m ≈ tam_ini 0,20) y sin erosión" % float((e0[0] as Dictionary)["tam"]), hueco >= 0 and e0.size() == 1 and absf(float((e0[0] as Dictionary)["tam"]) - 0.2) < 0.02 and float((e0[0] as Dictionary)["erosion"]) == 0.0)
	# (en headless el MultiMesh no guarda datos de instancia: el tamaño y la edad se miden con `estados()`)
	# a medio camino crece; la trayectoria se curva (la velocidad gira) y deriva hacia arriba
	var v0: Vector3 = (e0[0] as Dictionary)["vel"]
	for k in 15:
		h.call("avanzar", 1.0 / 30.0)
	var e1: Dictionary = (h.call("estados") as Array)[0]
	var v1: Vector3 = e1["vel"]
	_ok("a 0,5 s crece (%.2f m) y aún no se erosiona (%.2f)" % [e1["tam"], e1["erosion"]], float(e1["tam"]) > 0.35 and float(e1["erosion"]) < 0.1)
	_ok("deriva en curva: la velocidad ha girado (%.1f°) y sube (vy %.2f)" % [rad_to_deg(Vector2(v0.x, v0.z).angle_to(Vector2(v1.x, v1.z))), v1.y], absf(Vector2(v0.x, v0.z).angle_to(Vector2(v1.x, v1.z))) > 0.2 and v1.y > 0.2)
	for k in 12:
		h.call("avanzar", 1.0 / 30.0)
	var e2: Dictionary = (h.call("estados") as Array)[0]
	_ok("a 0,9 s está casi del todo crecida (%.2f ≈ 0,5: ×2,5) y erosionada (%.2f)" % [e2["tam"], e2["erosion"]], float(e2["tam"]) > 0.47 and float(e2["erosion"]) > 0.5)
	for k in 6:
		h.call("avanzar", 1.0 / 30.0)
	_ok("muere en su vida (1 s): 0 vivas", int(h.call("vivas")) == 0)
	# reserva llena: no roba
	for k in 14:
		h.call("emitir", Vector3.ZERO, Vector3.ZERO)
	_ok("la reserva se llena (12) y la 13.ª se pierde (emitir = -1)", int(h.call("vivas")) == 12 and int(h.call("emitir", Vector3.ZERO, Vector3.ZERO)) == -1)
	h.queue_free()
	await process_frame


# ------------------------------------------------------------------ 3. figuras ------------------------------------------------------------------

func _figuras(cl: String) -> void:
	print("== %s: figuras" % cl)
	for f in FIGURAS:
		var e: Node3D = _nueva(cl)
		await process_frame
		var s: Vector3 = f[2]
		e.call("definir", int(f[1]), s.x, s.y, s.z, false)
		await process_frame
		e.call("lanzar", -1.0)
		await _esperar(0.8)
		_ok("[%s %s] sin luces ni GPUParticles3D" % [cl, f[0]], e.find_children("*", "Light3D", true, false).is_empty() and e.find_children("*", "GPUParticles3D", true, false).is_empty())
		if cl == "viento":
			var humo: Node = e.find_child(["Nucleo", "Cortina", "Torbellino", "Anillo", "Chorro"][int(f[1])], true, false)
			var cintas: int = 0
			for c in (e.get_node("Cuerpo") as Node).get_children():
				if c is MeshInstance3D:
					cintas += 1
			var vivas: int = int(humo.call("vivas")) if humo != null else -1
			_ok("[viento %s] jirones de humo toon (%d vivas de %d), hojas y %d cintas" % [f[0], vivas, int(humo.call("capacidad")) if humo != null else 0, cintas],
				humo != null and (vivas >= 3 or int(f[1]) == 3) and e.find_child("Hojas", true, false) != null and (cintas >= 2 or int(f[1]) in [1, 4]))   # el anillo de la barrera se coloca por fórmula (no emite)
			if int(f[1]) == 0:
				_ok("[viento BOLA] quieta no hay estela", not (e.find_child("Estela", true, false) as Node3D).visible)
		else:
			var bl: MultiMeshInstance3D = e.find_child("Bloques", true, false) as MultiMeshInstance3D
			if int(f[1]) == 0:
				var roca: MeshInstance3D = e.find_child("Roca", true, false) as MeshInstance3D
				_ok("[tierra BOLA] la roca es la piedra_est_0 del mapa con el material de roca (textura rocas_albedo)", roca != null and roca.mesh == TierraToy.malla_roca("piedra_est_0")
					and (roca.material_override as ShaderMaterial).shader.resource_path.ends_with("tierra_roca.gdshader") and (roca.material_override as ShaderMaterial).get_shader_parameter("albedo_tex") is Texture2D)
			else:
				var bloques: Array = e.get("_bloques")
				var n: int = bloques.size()
				var mms: Array = e.get("_bloques_mms")
				var mallas: Dictionary = {}
				var inst: int = 0
				var del_mapa: bool = true
				for b in bloques:
					mallas[String((b as Dictionary)["malla"])] = true
					var idm: String = String((b as Dictionary)["malla"])
					del_mapa = del_mapa and (idm.begins_with("roca_est_") or idm.begins_with("piedra_est_") or (int(f[1]) == 4 and TierraToy.es_plana(idm)))      # el haz: púas y lajas propias
				for mi in mms:
					inst += (mi as MultiMeshInstance3D).multimesh.instance_count
					del_mapa = del_mapa and (mi as MultiMeshInstance3D).multimesh.mesh is ArrayMesh and ((mi as MultiMeshInstance3D).material_override as ShaderMaterial).get_shader_parameter("albedo_tex") is Texture2D
				_ok("[tierra %s] %d piezas (%s) en %d MultiMesh (≤ 5, uno por tipo; ≤ 24 piezas) y polvo + terrones en reserva" % [f[0], n, ", ".join(mallas.keys()), mms.size()],
					bl != null and n >= 3 and n <= 24 and inst == n and mms.size() == mallas.size() and mms.size() <= 5 and del_mapa and e.find_child("Polvo", true, false) != null and e.find_child("Terrones", true, false) != null)
				var terr: MultiMeshInstance3D = e.find_child("Terrones", true, false).get_child(0) as MultiMeshInstance3D
				_ok("[tierra %s] los terrones son la piedra_est_1 del mapa" % f[0], terr != null and terr.multimesh.mesh == TierraToy.malla_roca("piedra_est_1"))
		e.queue_free()
		await process_frame
	# desde_hechizo: la misma regla que el fuego
	var hz: Hechizo = Hechizo.new()
	hz.semieje_x = 1.5
	hz.semieje_y = 0.3
	hz.semieje_z = 0.13
	var d: Node3D = _nueva(cl)
	await process_frame
	var df: Dictionary = FuegoToy.describir(hz, float(d.get("casilla")))
	d.call("desde_hechizo", hz)
	await process_frame
	_ok("[%s] desde_hechizo = la figura y los semiejes del fuego (muro %.2f m)" % [cl, df["x"]], int(d.get("figura")) == int(df["figura"]) and is_equal_approx(float(d.get("semieje_x")), float(df["x"])) and (d.call("describir", hz) as Dictionary)["figura"] == df["figura"])
	d.queue_free()
	await process_frame


# ------------------------------------------------------------------ 4. tierra: subir y hundirse ------------------------------------------------------------------

func _tierra_sube() -> void:
	print("== tierra: subir con anticipación, sobrepaso y asentamiento; hundirse al morir")
	_ok("subida(0) = −1 (bajo tierra), subida(0,62) ≈ +0,1 (sobrepaso), subida(1) = 0 (asentado)", absf(TierraToy.subida(0.0) + 1.0) < 0.001 and TierraToy.subida(0.62) > 0.08 and absf(TierraToy.subida(1.0)) < 0.001)
	var e: TierraToy = _nueva("tierra") as TierraToy
	await process_frame
	e.definir(TierraToy.Figura.MURO, 3.45, 1.5, 0.3, false)
	await process_frame
	e.sube = 0.1
	e._avanzar_bloques(0.0)
	var bajo: bool = true
	var ys: Array = e.alturas_actuales()
	for j in ys.size():
		bajo = bajo and float(ys[j]) <= -0.5 * float((e._bloques[j] as Dictionary)["h"])        # las piedras del pie son bajas: se mide contra el alto de cada roca
	_ok("con sube = 0,1 (anticipación) todas las rocas siguen bajo tierra (y ≤ −½ de su alto)", bajo and ys.size() >= 3)
	e.sube = 1.0
	e._avanzar_bloques(0.0)
	var arriba: bool = true
	for y2 in e.alturas_actuales():
		arriba = arriba and absf(float(y2)) < 0.001
	_ok("con sube = 1 todos están en su sitio (y = 0)", arriba)
	var maxy: float = -9.0
	for sb in [0.3, 0.45, 0.55, 0.65, 0.75]:
		e.sube = sb
		e._avanzar_bloques(0.0)
		for y3 in e.alturas_actuales():
			maxy = maxf(maxy, float(y3))
	_ok("por el camino algún bloque se pasa de su sitio (sobrepaso máx %.2f m > 0)" % maxy, maxy > 0.03)
	e.queue_free()
	await process_frame
	# nacer de verdad: polvo en la anticipación y polvo + fragmentos al asentarse
	var m: TierraToy = _nueva("tierra") as TierraToy
	await process_frame
	m.definir(TierraToy.Figura.MURO, 3.45, 1.5, 0.3, false)
	await process_frame
	m.sube = 0.0
	m.lanzar(-1.0)
	await _esperar(0.08)
	var polvo: Node = m.find_child("Polvo", true, false)
	var p_ant: int = int(polvo.call("vivas"))
	await _esperar(0.7)
	var terr: Node = m.find_child("Terrones", true, false)
	_ok("nacer: polvo en la anticipación (%d bocanadas a los 0,08 s) y fragmentos al asentarse (%d terrones)" % [p_ant, int(terr.call("vivas"))], p_ant >= 1 and int(terr.call("vivas")) >= 2 and m.get("_asentado"))
	m.morir()
	await _esperar(0.35)
	var hundiendo: bool = false
	var polvo_h: int = 0
	if is_instance_valid(m):
		for y4 in m.alturas_actuales():
			hundiendo = hundiendo or float(y4) < -0.05
		var pv: Node = m.find_child("Polvo", true, false)
		polvo_h = int(pv.call("vivas")) if pv != null else 0
	_ok("morir: los bloques se HUNDEN (y < 0) con polvo (%d)" % polvo_h, hundiendo and polvo_h >= 1)
	await _esperar(0.6)
	_ok("…y la figura se libera sola", not is_instance_valid(m))
	await _esperar(2.2)


# ------------------------------------------------------------------ 4b. tierra: el haz de púas en secuencia ------------------------------------------------------------------

func _tierra_haz() -> void:
	print("== tierra: HAZ = grietas + púas que brotan en secuencia de la mano a la punta, de menor a mayor, con lajas; se hunden al revés y las grietas se van")
	var e: TierraToy = _nueva("tierra") as TierraToy
	await process_frame
	e.definir(TierraToy.Figura.HAZ, 1.5, 0.5, 0.15, false)
	await process_frame
	var puas: Array = []
	var lajas: Array = []
	for b in e._bloques:
		var bd: Dictionary = b
		if String(bd["malla"]).begins_with("pua_"):
			puas.append(bd)
		elif String(bd["malla"]).begins_with("laja_"):
			lajas.append(bd)
	var t_n: float = e._t_nacer_haz()
	_ok("púas (%d) + lajas (%d) ≤ 24 piezas, ≤ 5 MultiMesh (%d), 1-2 lajas por púa, y hay un quad «Grietas» y ninguna roca del mapa" % [puas.size(), lajas.size(), e._bloques_mms.size()],
		puas.size() >= 4 and lajas.size() >= puas.size() and puas.size() + lajas.size() <= 24 and puas.size() + lajas.size() == e._bloques.size() and e._bloques_mms.size() <= 5 and e.find_child("Grietas", true, false) != null)
	var mats_planos: bool = true
	for mi in e._bloques_mms:
		mats_planos = mats_planos and float(((mi as MultiMeshInstance3D).material_override as ShaderMaterial).get_shader_parameter("plano")) > 0.99
	_ok("las púas y las lajas se pintan con color PLANO pardo (plano = 1), no con la textura", mats_planos)
	# 7/11: coste de un HAZ completo = suma, por MultiMesh, de instancias × vértices de su malla; con las púas del pack (426-620 vértices) 14 púas dan ~7.550, el margen es corto a propósito
	var vert_haz: int = 0
	for mi in e._bloques_mms:
		var mmh: MultiMesh = (mi as MultiMeshInstance3D).multimesh
		vert_haz += mmh.instance_count * (mmh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	_ok("un HAZ completo no pasa de 9.000 vértices sumando todas sus instancias (mide %d en %d MultiMesh)" % [vert_haz, e._bloques_mms.size()], vert_haz > 0 and vert_haz <= 9000)
	# secuencia: de la mano (z = 0) a la punta (z = -largo): retraso creciente con paso de 0,04-0,06 s; alturas crecientes
	var orden_ok: bool = true
	var pasos_ok: bool = true
	var crecen: int = 0
	var paso_min: float = 9.0
	var paso_max: float = 0.0
	for i in range(1, puas.size()):
		var a: Dictionary = puas[i - 1]
		var b: Dictionary = puas[i]
		orden_ok = orden_ok and (b["pos"] as Vector3).z < (a["pos"] as Vector3).z and float(b["retraso"]) > float(a["retraso"])
		var paso: float = (float(b["retraso"]) - float(a["retraso"])) * t_n
		paso_min = minf(paso_min, paso)
		paso_max = maxf(paso_max, paso)
		pasos_ok = pasos_ok and paso >= 0.035 and paso <= 0.065
		if float(b["h"]) > float(a["h"]):
			crecen += 1
	_ok("brotan EN SECUENCIA de la mano a la punta (paso %.3f-%.3f s, nacer dura %.2f s)" % [paso_min, paso_max, t_n], orden_ok and pasos_ok and t_n > 0.3 and t_n < 1.2)
	_ok("de MENOR a MAYOR: la última mide %.2f y la primera %.2f (crecen %d de %d pasos)" % [float(puas[puas.size() - 1]["h"]), float(puas[0]["h"]), crecen, puas.size() - 1], float(puas[puas.size() - 1]["h"]) > float(puas[0]["h"]) * 1.4 and crecen >= (puas.size() - 1) * 0.7)
	# a medio nacer: las primeras fuera, las últimas aún bajo tierra; las grietas ya corren por delante
	e.sube = 0.45
	e._avanzar_bloques(0.0)
	var ys: Array = e.alturas_actuales()
	var primera_fuera: bool = float(ys[e._bloques.find(puas[0])]) > -0.1 * float(puas[0]["h"])
	var ultima_dentro: bool = float(ys[e._bloques.find(puas[puas.size() - 1])]) <= -0.9 * float(puas[puas.size() - 1]["h"])
	var g1: Dictionary = e.estado_grietas()
	_ok("a mitad (sube 0,45): la primera púa fuera, la última aún bajo tierra; las grietas van por delante (avance %.2f) y se ven (vida %.2f)" % [g1["avance"], g1["vida"]], primera_fuera and ultima_dentro and float(g1["avance"]) > 0.45 and float(g1["vida"]) > 0.9)
	e.sube = 1.0
	e._avanzar_bloques(0.0)
	var todas: bool = true
	for y in e.alturas_actuales():
		todas = todas and absf(float(y)) < 0.001
	var g2: Dictionary = e.estado_grietas()
	_ok("con sube = 1 todas en su sitio y las grietas llegan a la punta (avance %.2f)" % g2["avance"], todas and float(g2["avance"]) >= 0.99)
	# se hunden en orden inverso: la punta antes que la mano; las grietas se desvanecen
	e.hunde = 0.35
	e._avanzar_bloques(0.0)
	var ys2: Array = e.alturas_actuales()
	var y_mano: float = float(ys2[e._bloques.find(puas[0])])
	var y_punta: float = float(ys2[e._bloques.find(puas[puas.size() - 1])])
	var g3: Dictionary = e.estado_grietas()
	_ok("con hunde = 0,35 la punta ya baja (%.2f m) y la mano aún no (%.2f m); las grietas se van (vida %.2f)" % [y_punta, y_mano, g3["vida"]], y_punta < -0.05 and y_mano > -0.01 and float(g3["vida"]) < 0.9)
	e.hunde = 1.0
	e._avanzar_bloques(0.0)
	var g4: Dictionary = e.estado_grietas()
	var hundidas: bool = true
	var ys4: Array = e.alturas_actuales()
	for j4 in ys4.size():
		hundidas = hundidas and float(ys4[j4]) < -0.99 * float((e._bloques[j4] as Dictionary)["h"])
	_ok("con hunde = 1 todas bajo tierra (y < −su alto) y las grietas apagadas (vida %.2f)" % g4["vida"], hundidas and float(g4["vida"]) < 0.02)
	e.queue_free()
	await process_frame
	# de verdad: nacer y mirar que las púas salgan una a una con cascotes y polvo
	var m: TierraToy = _nueva("tierra") as TierraToy
	await process_frame
	m.definir(TierraToy.Figura.HAZ, 1.5, 0.5, 0.15, false)
	await process_frame
	m.lanzar(-1.0)
	await _esperar(0.2)
	var fuera_02: int = 0
	var ys3: Array = m.alturas_actuales()
	for j in ys3.size():
		if String((m._bloques[j] as Dictionary)["malla"]).begins_with("pua_") and float(ys3[j]) > -0.5 * float((m._bloques[j] as Dictionary)["h"]):
			fuera_02 += 1
	await _esperar(0.3)
	var terr: Node = m.find_child("Terrones", true, false)
	var polvo: Node = m.find_child("Polvo", true, false)
	_ok("nacer de verdad: a los 0,2 s solo asoman las primeras púas (%d de %d) y a los 0,5 s hay cascotes (%d) y polvo (%d)" % [fuera_02, puas.size(), int(terr.call("vivas")), int(polvo.call("vivas"))],
		fuera_02 >= 1 and fuera_02 < puas.size() and int(terr.call("vivas")) >= 2 and int(polvo.call("vivas")) >= 2)
	await _esperar(0.4)
	m.morir()
	await _esperar(1.2)
	_ok("…y el haz se libera solo al hundirse", not is_instance_valid(m))
	await _esperar(2.2)


# ------------------------------------------------------------------ 4c. tierra: cúpula de la barrera y anillo de aviso de la carga ------------------------------------------------------------------

func _tierra_cupula_y_aviso() -> void:
	print("== tierra: BARRERA = corona cerrada arriba (cúpula) con destello al cerrarse; CARGA = anillo de aviso que gira bajo los pies")
	var e: TierraToy = _nueva("tierra") as TierraToy
	await process_frame
	e.definir(TierraToy.Figura.BARRERA, 1.5, 1.5, 1.5, false)
	await process_frame
	var techo: Array = []
	for b in e._bloques:
		if bool((b as Dictionary).get("techo", false)):
			techo.append(b)
	var techo_alto: bool = true
	var techo_tarde: bool = true
	for t in techo:
		techo_alto = techo_alto and ((t as Dictionary)["pos"] as Vector3).y > 0.6 * 1.5 and ((t as Dictionary)["pos"] as Vector3).length() < 1.5
		for b2 in e._bloques:
			if not bool((b2 as Dictionary).get("techo", false)):
				techo_tarde = techo_tarde and float((t as Dictionary)["retraso"]) > float((b2 as Dictionary)["retraso"])
	_ok("la corona lleva %d losas de TECHO sobre el centro (y > 0,9 m) que suben las últimas; %d piezas ≤ 24; hay un disco «Brillo» sin luz" % [techo.size(), e._bloques.size()],
		techo.size() >= 2 and techo.size() <= 3 and techo_alto and techo_tarde and e._bloques.size() <= 24 and e.find_child("Brillo", true, false) != null and e.find_children("*", "Light3D", true, false).is_empty())
	e.sube = 0.1
	e._avanzar_bloques(0.0)
	var bajo: bool = true
	var ys: Array = e.alturas_actuales()
	for j in ys.size():
		var b3: Dictionary = e._bloques[j]
		bajo = bajo and float(ys[j]) + (b3["pos"] as Vector3).y <= -0.5 * float(b3["h"])
	_ok("con sube = 0,1 también las losas del techo están bajo tierra (suben desde el suelo)", bajo)
	e.lanzar(-1.0)
	await _esperar(0.3)
	var br0: Dictionary = e.estado_brillo()
	await _esperar(0.45)
	var br1: Dictionary = e.estado_brillo()
	await _esperar(0.5)
	var br2: Dictionary = e.estado_brillo()
	_ok("al cerrarse la cúpula (≈0,6 s) el brillo interior se enciende tenue (antes %.2f, al cerrar %.2f ≤ 0,35) y se apaga en 0,4 s (después %.2f)" % [br0["alfa"], br1["alfa"], br2["alfa"]],
		float(br0["alfa"]) < 0.01 and float(br1["alfa"]) > 0.03 and float(br1["alfa"]) <= 0.35 and float(br2["alfa"]) < 0.01 and float(br2["cerrada_hace"]) > 0.4)
	e.queue_free()
	await process_frame
	# carga: anillo de aviso
	var c: TierraToy = _nueva("tierra") as TierraToy
	await process_frame
	c.global_position = Vector3(0, 1, 0)
	c.empezar_carga(0.8, 0.4)
	await _esperar(0.3)
	var av0: Dictionary = c.estado_aviso()
	await _esperar(0.2)
	var av1: Dictionary = c.estado_aviso()
	var aviso: MultiMeshInstance3D = c.find_child("Aviso", true, false) as MultiMeshInstance3D
	_ok("en la carga hay un anillo «Aviso» de %d piedrecitas (radio %.2f m) que GIRA a ras de suelo bajo los pies (%.2f → %.2f rad en 0,2 s)" % [int(av1["n"]), av1["radio"], av0["ang"], av1["ang"]],
		aviso != null and aviso.multimesh.instance_count == TierraToy.N_AVISO and bool(av1["vivo"]) and float(av1["ang"]) > float(av0["ang"]) + 0.3 and float(av1["radio"]) > 0.5)
	c.soltar(Vector3(0, 0, -1))
	await process_frame
	_ok("al soltar el aviso se retira (oculto)", not is_instance_valid(aviso) or not aviso.visible)
	c.queue_free()
	await _esperar(0.8)


# ------------------------------------------------------------------ 5. carga ------------------------------------------------------------------

func _carga(cl: String) -> void:
	print("== %s: carga" % cl)
	var e: Node3D = _nueva(cl)
	await process_frame
	e.global_position = Vector3(0, 1, 0)
	e.call("empezar_carga", 0.8, 0.4)
	var s0: float = _escala(e)
	_ok("[%s] nace pequeña: escala %.3f ≈ carga_tam_inicial" % [cl, s0], absf(s0 - float(e.get("carga_tam_inicial"))) < 0.06 and bool(e.call("esta_cargando")) and float(e.call("progreso_carga")) < 0.15)
	var prev: float = s0
	var baja: bool = false
	var conv_ok: int = 0
	var conv_tot: int = 0
	var t0: float = 0.0
	while t0 < 0.7:
		await process_frame
		t0 += root.get_process_delta_time()
		_medir()
		var s: float = _escala(e)
		if s < prev - 0.002:
			baja = true
		prev = s
		for g in e.call("estado_carga"):
			var gd: Dictionary = g
			var p: Vector3 = gd["pos"]
			var v: Vector3 = gd["vel"]
			if p.length() > 0.05 and v.length() > 0.05:
				conv_tot += 1
				if v.normalized().dot(p.normalized()) < 0.0:
					conv_ok += 1
	_ok("[%s] crece sin bajar (escala %.2f) y el progreso llega a 1 (%.2f)" % [cl, prev, e.call("progreso_carga")], not baja and prev > 0.7 and float(e.call("progreso_carga")) > 0.85)
	_ok("[%s] lo que rodea la mano CONVERGE (%d de %d hacia dentro)" % [cl, conv_ok, conv_tot], conv_tot > 5 and float(conv_ok) / float(conv_tot) > 0.9)
	e.call("cancelar_carga")
	await _esperar(0.45)
	_ok("[%s] cancelar_carga la libera sola" % cl, not is_instance_valid(e))
	for etapa in ["llena", "a medias"]:
		var f: Node3D = _nueva(cl)
		await process_frame
		f.global_position = Vector3(0, 1, 0)
		f.call("empezar_carga", 0.6, 0.4)
		await _esperar(0.7 if etapa == "llena" else 0.25)
		var id: int = f.get_instance_id()
		var antes: float = _escala(f)
		f.call("soltar", Vector3(0, 0, -1))
		var salto: float = 0.0
		var pr: float = antes
		var t1: float = 0.0
		while t1 < 0.4:
			await process_frame
			t1 += root.get_process_delta_time()
			_medir()
			salto = maxf(salto, absf(_escala(f) - pr))
			pr = _escala(f)
		var tope: float = 0.02 + (1.0 - antes) * 1.6 * root.get_process_delta_time() / 0.14            # lo que avanza un fotograma en lo más rápido de la curva (0,14 s de asentamiento)
		_ok("[%s %s] soltar: mismo nodo, proyectil, sin salto (máx %.3f por fotograma ≤ %.3f, de %.2f a %.2f)" % [cl, etapa, salto, tope, antes, pr], f.get_instance_id() == id and bool(f.get("proyectil")) and salto < tope and absf(pr - 1.0) < 0.02)
		f.queue_free()
		await process_frame


# ------------------------------------------------------------------ 6. impactos ------------------------------------------------------------------

func _impactos(cl: String) -> void:
	print("== %s: impactos" % cl)
	var casos: Array = [["GOLPE pared", 0, Vector3(0, 0, 1)], ["GOLPE suelo", 0, Vector3.UP], ["FIN", 1, Vector3.UP], ["REBOTE", 2, Vector3(1, 0, 0)], ["AREA", 3, Vector3.UP]]
	for c in casos:
		var radio: float = 1.8 if int(c[1]) == 3 else 0.4
		var imp: Node3D = ImpactoVientoToy.crear(int(c[1]) as ImpactoVientoToy.Variante, c[2], radio) if cl == "viento" else ImpactoTierraToy.crear(int(c[1]) as ImpactoTierraToy.Variante, c[2], radio)
		_raiz.add_child(imp)
		imp.global_position = Vector3(0, 1, 0)
		await process_frame
		var rc: Array = imp.call("recuento")
		_ok("[%s %s] sin destello ni luz; %d + %d piezas" % [cl, c[0], rc[0], rc[1]], imp.find_child("Destello", true, false) == null and imp.find_children("*", "Light3D", true, false).is_empty() and int(rc[0]) >= 5)
		if cl == "tierra" and int(c[1]) != 1:
			var bajo: int = 0
			var cae: int = 0
			var tot: int = 0
			var a: Array = imp.call("piedras_estado", 0.1)
			var b: Array = imp.call("piedras_estado", 0.3)
			for i in a.size():
				var ga: Dictionary = a[i]
				var gb: Dictionary = b[i]
				if float(ga["altura"]) < -0.006 or float(gb["altura"]) < -0.006:
					bajo += 1
				if bool(ga["vivo"]) and bool(gb["vivo"]):
					tot += 1
					if float(gb["vy"]) < float(ga["vy"]) - 0.5 or float(gb["vy"]) == 0.0:
						cae += 1
			_ok("[tierra %s] las piedras salen en el hemisferio de la normal (0 por debajo: %d) y CAEN (%d de %d)" % [c[0], bajo, cae, tot], bajo == 0 and tot > 0 and cae == tot)
			var pv: Node = imp.find_child("Polvo", true, false)
			_ok("[tierra %s] nube de polvo toon pardo (%d bocanadas)" % [c[0], int(pv.call("vivas"))], pv != null and int(pv.call("vivas")) >= 4)
			if int(c[1]) == 0:
				# GOLPE: anillo que se abre (0 → 1 en 0,15 s) y se va (≈0,6 s), púas que asoman en el centro y se retiran
				imp.call("avanzar_a", 0.02)
				var an0: Dictionary = imp.call("anillo_estado")
				var p0: Array = imp.call("puas_estado", 0.0)
				imp.call("avanzar_a", 0.16)
				var an1: Dictionary = imp.call("anillo_estado")
				var p1: Array = imp.call("puas_estado", 0.25)
				imp.call("avanzar_a", 1.15)
				var an2: Dictionary = imp.call("anillo_estado")
				var p2: Array = imp.call("puas_estado", 0.85)
				_ok("[tierra %s] ANILLO en la superficie (radio %.2f m): apertura %.2f → %.2f (0,15 s) y vida %.2f → %.2f (1,15 s)" % [c[0], an1.get("radio", 0.0), an0.get("apertura", -1.0), an1.get("apertura", -1.0), an1.get("vida", -1.0), an2.get("vida", -1.0)],
					bool(an0["hay"]) and float(an0["apertura"]) < 0.3 and float(an1["apertura"]) > 0.99 and float(an1["vida"]) > 0.99 and float(an2["vida"]) < 0.05 and float(an1["radio"]) > 0.4)
				_ok("[tierra %s] %d púas que ASOMAN (0 → %.2f m a 0,25 s) y se RETIRAN (%.2f m a 0,85 s); el polvo + cascotes no suben de la cuenta (%d + %d)" % [c[0], p1.size(), p1[0], p2[0], rc[0], rc[1]],
					p0.size() == 3 and float(p0[0]) < 0.001 and float(p1[0]) > 0.3 and float(p2[0]) < 0.001 and int(rc[0]) <= 12 and int(rc[1]) <= 14 and imp.find_child("Puas", true, false) != null)
			elif int(c[1]) == 3:
				# AREA: cascotes en ESPIRAL baja (velocidad sobre todo tangente) y la nube con el centro más claro
				var esp: int = 0
				var tot2: int = 0
				for g in imp.call("piedras_estado", 0.02):
					var gd: Dictionary = g
					var p: Vector3 = (gd["pos"] as Vector3) - imp.global_position
					var pr: Vector2 = Vector2(p.x, p.z).normalized()
					var vd: Vector3 = gd["dir"]
					var vh: Vector2 = Vector2(vd.x, vd.z)
					if vh.length() > 0.01 and pr.length() > 0.01:
						tot2 += 1
						if absf(vh.normalized().cross(pr)) > 0.5:
							esp += 1
				var pc: Node = imp.find_child("PolvoCentro", true, false)
				_ok("[tierra AREA] los cascotes salen en ESPIRAL (%d de %d con más tangente que radial) y la nube lleva un centro más claro (%d bocanadas)" % [esp, tot2, int(pc.call("vivas")) if pc != null else -1],
					tot2 >= 10 and esp >= tot2 * 0.8 and pc != null and int(pc.call("vivas")) >= 4 and (pc.get_child(0) as MultiMeshInstance3D).material_override.get_shader_parameter("color_claro").r > TierraToy.POLVO_CLARO.r)
		elif cl == "viento":
			var est: Dictionary = imp.call("estado")
			var humo: Array = est["humo"]
			var radial: int = 0
			for g in humo:
				var gd: Dictionary = g
				var p: Vector3 = gd["pos"]
				var v: Vector3 = gd["vel"]
				if Vector2(p.x, p.z).length() < 0.001 or Vector2(v.x, v.z).normalized().dot(Vector2(p.x, p.z).normalized()) > 0.5:
					radial += 1
			_ok("[viento %s] soplo de %d jirones toon (%d radiales) y %d hojas" % [c[0], humo.size(), radial, (est["hojas"] as Array).size()], humo.size() >= 5 and radial >= humo.size() - 1 and ((est["hojas"] as Array).size() >= 4 or int(c[1]) == 1))
		var t1: float = 0.0
		while is_instance_valid(imp) and t1 < 2.6:
			await process_frame
			t1 += root.get_process_delta_time()
			_medir()
		_ok("[%s %s] se libera solo" % [cl, c[0]], not is_instance_valid(imp))


# ------------------------------------------------------------------ 7. API ------------------------------------------------------------------

func _api(cl: String) -> void:
	print("== %s: impactar_en / rebotar / terminar_sin_choque / finalizar" % cl)
	var e: Node3D = _nueva(cl)
	await process_frame
	e.global_position = Vector3(0, 1, 0)
	e.call("definir", 0, 0.4, 0.4, 0.4, true)
	await _esperar(0.3)
	if cl == "viento":
		var est: Node3D = e.find_child("Estela", true, false)
		_ok("[viento] en vuelo la estela de jirones se ve y suelta bocanadas (%d)" % int(est.call("vivas")), est.visible and int(est.call("vivas")) >= 2)
	else:
		var te: Node = e.find_child("Terrones", true, false)
		_ok("[tierra] en vuelo suelta terrones (%d) y polvo (%d)" % [int(te.call("vivas")), int(e.find_child("Polvo", true, false).call("vivas"))], int(te.call("vivas")) >= 1 and int(e.find_child("Polvo", true, false).call("vivas")) >= 1)
	var imp: Node3D = e.call("impactar_en", Vector3(0, 1, -2), Vector3(0, 0, 1))
	_ok("[%s] impactar_en devuelve y deja un impacto" % cl, imp != null and _hay_impacto())
	await _esperar(0.6)
	_ok("[%s] impactar_en libera la bola" % cl, not is_instance_valid(e))
	_limpiar_impactos()
	await process_frame
	var r: Node3D = _nueva(cl)
	await process_frame
	r.global_position = Vector3(0, 1, 0)
	r.look_at(Vector3(0, 1, -5), Vector3.UP)
	r.call("definir", 0, 0.4, 0.4, 0.4, true)
	await process_frame
	var nd: Vector3 = r.call("rebotar", Vector3(0, 1, -2), Vector3(0, 0, 1))
	_ok("[%s] rebotar: sigue viva, hay impacto, devuelve la reflejada y mira hacia ella" % cl, is_instance_valid(r) and _hay_impacto() and nd.distance_to(Vector3(0, 0, 1)) < 0.01 and (-r.global_transform.basis.z).distance_to(nd) < 0.01)
	await _esperar(0.9)
	_limpiar_impactos()
	r.queue_free()
	await process_frame
	var f: Node3D = _nueva(cl)
	await process_frame
	f.global_position = Vector3(0, 1, 0)
	f.call("empezar_carga", 0.1, 0.4)
	await _esperar(0.2)
	f.call("soltar", Vector3(0, 0, -1))
	await _esperar(0.2)
	f.call("terminar_sin_choque")
	_ok("[%s] terminar_sin_choque deja un impacto FIN" % cl, _hay_impacto())
	await _esperar(1.7)
	_ok("[%s] terminar_sin_choque libera la bola" % cl, not is_instance_valid(f))
	_limpiar_impactos()
	var h: Node3D = _nueva(cl)
	await process_frame
	h.global_position = Vector3(0, 1, 0)
	h.call("finalizar", "suelo", Vector3(0, 0, 0), Vector3.UP)
	_ok("[%s] finalizar('suelo') = impacto" % cl, _hay_impacto())
	await _esperar(0.6)
	_ok("[%s] finalizar('suelo') libera la bola" % cl, not is_instance_valid(h))
	_limpiar_impactos()
	var h2: Node3D = _nueva(cl)
	await process_frame
	h2.call("finalizar", "alcance")
	await _esperar(1.7)
	_ok("[%s] finalizar('alcance') = fin sin choque y libera" % cl, not is_instance_valid(h2))
	_limpiar_impactos()
	await _esperar(2.1)


# ------------------------------------------------------------------ 9. lab ------------------------------------------------------------------

func _lab() -> void:
	print("== lab: Z cicla por viento y tierra")
	var lab: Node3D = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	var orden: Array = []
	var n: int = (lab.get("ELEMENTOS_TOY") as PackedStringArray).size()
	for i in n:
		lab.call("alternar_elemento")
		orden.append(String(lab.get("elemento")))
	_ok("Z pasa por viento y tierra y vuelve al fuego (%s)" % str(orden), orden.has("viento") and orden.has("tierra") and orden[n - 1] == "fuego")
	for cl in ["viento", "tierra"]:
		lab.call("poner_elemento", cl)
		var e: Node3D = lab.call("carga_completa")
		var ip: Node3D = lab.call("impacto_pared")
		var isu: Node3D = lab.call("impacto_suelo")
		var fp: Node3D = lab.call("fuego_param", 2)
		var hz: Node3D = lab.call("fuego_hechizo", 0)
		var pa: Node3D = lab.call("explosion_area")
		var bien: bool
		if cl == "viento":
			bien = e is VientoToy and ip is ImpactoVientoToy and isu is ImpactoVientoToy and fp is VientoToy and hz is VientoToy and pa is ImpactoVientoToy and int(pa.get("variante")) == 3
		else:
			bien = e is TierraToy and ip is ImpactoTierraToy and isu is ImpactoTierraToy and fp is TierraToy and hz is TierraToy and pa is ImpactoTierraToy and int(pa.get("variante")) == 3
		_ok("[%s] G, B, N, F7, F9 y P crean el elemento activo (rótulo: %s)" % [cl, String(lab.call("_texto_param")).substr(1, 20)], bien and String(lab.call("_texto_param")).find(cl.to_upper() + " PARAMETRICO") >= 0)
		lab.call("limpiar")
		await process_frame
	lab.queue_free()
	await process_frame
