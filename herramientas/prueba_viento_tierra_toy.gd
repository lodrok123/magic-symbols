extends SceneTree

## PRUEBA del viento y la tierra «toy» (6/11/2026; a imagen de prueba_hielo_toy.gd). Sin ventana (los class_name son nuevos: antes, `--headless --import`):
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_viento_tierra_toy.gd
## Comprueba, con VientoToy / ImpactoVientoToy, TierraToy / ImpactoTierraToy y el humo toon (humo_toy.gd):
##   1. ESTILO: los shaders nuevos no son aditivos ni emisivos; el humo toon es blend_mix, unshaded y de borde duro (discard); la roca es opaca, con la textura de las rocas del mapa
##      (rocas_albedo.png) y la luz de la escena (NO unshaded; mate, sin especular), y las figuras usan las mallas piedra_est_* / roca_est_* del mapa (6/11 tarde: «la piedra del mundo»)
##   2. HUMO TOON: una bocanada NACE pequeña, CRECE (~×2,5), se EROSIONA al final (erosion sube con la edad) y MUERE en su vida; deriva en curva
##   3. FIGURAS: las dos clases se crean y las 5 figuras y `desde_hechizo` no fallan; sin luces ni GPUParticles3D; piezas esperadas (cintas, hojas, bloques, roca...)
##   4. TIERRA: los bloques SUBEN del suelo con anticipación, sobrepaso y asentamiento (`subida`), sueltan polvo y fragmentos al asentarse y se HUNDEN al morir
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
	for s in ["humo_toon.gdshader", "tierra_roca.gdshader"]:
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
					del_mapa = del_mapa and (String((b as Dictionary)["malla"]).begins_with("roca_est_") or String((b as Dictionary)["malla"]).begins_with("piedra_est_"))
				for mi in mms:
					inst += (mi as MultiMeshInstance3D).multimesh.instance_count
					del_mapa = del_mapa and (mi as MultiMeshInstance3D).multimesh.mesh is ArrayMesh and ((mi as MultiMeshInstance3D).material_override as ShaderMaterial).get_shader_parameter("albedo_tex") is Texture2D
				_ok("[tierra %s] %d rocas del mapa (%s) en %d MultiMesh (≤ 5, uno por tipo; ≤ 24 rocas) y polvo + terrones en reserva" % [f[0], n, ", ".join(mallas.keys()), mms.size()],
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
