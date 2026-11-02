extends SceneTree

## PRUEBA del muro de fuego toon (1/11, Dirección, docs/PRUEBA2_VFX_TOON_2026-11-01.md §1 y §2.8). Headless:
##   godot --headless --path . --script res://herramientas/prueba_vfx_toon.gd
## Comprueba, para MuroFuegoToon (presentacion/vfx/toon/):
##   1. la escena existe, carga, su raíz lleva EfectoVfx3D con «Anim» con nacer, vivir y morir
##   2. presupuesto: ≤ MAX_LUCES luz y ≤ MAX_PARTICULAS partículas (suma de `amount`)
##   3. `preparar` escala el raíz al volumen: el de referencia da escala 1 y el doble de largo da 2 en X
##   4. `lanzar(vida)` libera el nodo en vida + dura_morir + 0,1 s y `lanzar(-1)` + `morir()` lo libera en dura_morir + 0,1 s
##   5. los tres shaders (fuego_toon, humo_toon, chispa_toon) cargan, son unshaded, y fuego_toon expone los diez mandos con rango y `suavidad` ≤ 0,03
##   6. todo a 12 fps: el shader cuantiza el tiempo con floor(TIME * fps) y fps vale 12; las partículas llevan fixed_fps 12 sin interpolar; la luz
##      titila en escalones (claves cada 1/12 s, interpolación del vecino más cercano); el humo nace en la punta de la llama (no del suelo)
##   7. la paleta: en `muro_cerca_solo_llama.png` (la llama sobre negro, sacada por herramientas/captura_vfx_toon.gd) hay ≤ MAX_COLORES colores distintos
##      al cuantizar a 5 bits por canal (sin contar el negro del fondo). Si falta la captura, falla: hay que sacarla antes.
##   8. el lab compila (script cargable) y tiene la tecla 5 y los diez mandos
## NO comprueba (necesita ventana y GPU): que los shaders COMPILEN de verdad, el fps, ni que la captura sea de la versión actual de la escena.
## Imprime FALLOS: n al final.

const MAX_LUCES: int = 1
const MAX_PARTICULAS: int = 300
const MAX_COLORES: int = 8
const FPS_TOON: int = 12
const MAX_SUAVIDAD: float = 0.03
const BITS_PALETA: int = 5
const DIR: String = "res://presentacion/vfx/toon/"
const CAPTURA_LLAMA: String = "res://docs/capturas/comparativa_vfx/godot_toon/muro_cerca_solo_llama.png"
const CASILLA: float = 2.3
const REF: Vector3 = Vector3(6.9, 1.5, 0.3)
const TOL_ESCALA: float = 0.02
const MANDOS: PackedStringArray = ["fps", "umbral", "altura_llama", "desplazamiento", "contorno", "rampa", "velocidad", "escala_ruido", "brillo", "erosion"]
const SHADERS: PackedStringArray = ["fuego_toon", "humo_toon", "chispa_toon"]

var _fallos: int = 0
var _raiz: Node3D = null


func _initialize() -> void:
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
	await _escena()
	_presupuesto_extra()
	_shaders()
	_cuantizado()
	_paleta()
	_lab()
	print("FALLOS: %d" % _fallos)
	quit(0 if _fallos == 0 else 1)


func _cargar_escena() -> PackedScene:
	return load(DIR + "MuroFuegoToon.tscn") as PackedScene


func _escena() -> void:
	print("— MuroFuegoToon")
	var ruta: String = DIR + "MuroFuegoToon.tscn"
	_ok("1 existe", ResourceLoader.exists(ruta), ruta)
	if not ResourceLoader.exists(ruta):
		return
	var ps: PackedScene = _cargar_escena()
	var e: Node3D = ps.instantiate() as Node3D
	_raiz.add_child(e)
	_ok("1 lleva EfectoVfx3D", e is EfectoVfx3D)
	var ap: AnimationPlayer = e.get_node_or_null("Anim") as AnimationPlayer
	_ok("1 Anim con nacer, vivir y morir", ap != null and ap.has_animation("nacer") and ap.has_animation("vivir") and ap.has_animation("morir"))
	_ok("1 tam_referencia", e.get("tam_referencia") == REF, str(e.get("tam_referencia")))
	var luces: int = 0
	var part: int = 0
	for n in e.find_children("*", "", true, false):
		if n is Light3D:
			luces += 1
		elif n is GPUParticles3D:
			part += (n as GPUParticles3D).amount
	_ok("2 luces ≤ %d" % MAX_LUCES, luces <= MAX_LUCES and luces >= 1, str(luces))
	_ok("2 partículas ≤ %d" % MAX_PARTICULAS, part <= MAX_PARTICULAS, str(part))
	# 6: partículas a 12 fps sin interpolar, humo en la punta, luz en escalones
	for n in e.find_children("*", "GPUParticles3D", true, false):
		var gp: GPUParticles3D = n
		_ok("6 %s: fixed_fps %d sin interpolar" % [gp.name, FPS_TOON], gp.fixed_fps == FPS_TOON and not gp.interpolate, "%d %s" % [gp.fixed_fps, str(gp.interpolate)])
	var humo: Node3D = e.get_node_or_null("Cuerpo/Humo") as Node3D
	_ok("6 el humo nace en la punta (y ≥ 40 % del alto: las lenguas llegan a ~1 m)", humo != null and humo.position.y >= 0.4 * REF.y, str(humo.position.y) if humo != null else "sin humo")
	if ap != null and ap.has_animation("vivir"):
		var a: Animation = ap.get_animation("vivir")
		var bien: bool = a.get_track_count() > 0 and a.length > 0.0
		var pasos: int = 0
		for t in a.get_track_count():
			if String(a.track_get_path(t)).ends_with("light_energy"):
				bien = bien and a.track_get_interpolation_type(t) == Animation.INTERPOLATION_NEAREST
				pasos = a.track_get_key_count(t)
				for k in range(1, pasos):
					bien = bien and absf((a.track_get_key_time(t, k) - a.track_get_key_time(t, k - 1)) - 1.0 / float(FPS_TOON)) < 0.001
		_ok("6 la luz titila en escalones de 1/%d s (%d claves, vecino más cercano)" % [FPS_TOON, pasos], bien and pasos >= FPS_TOON)
	for p in ["Cinta0", "Cinta1", "Cinta2", "Cinta3", "Cinta4", "Cinta5", "Base"]:
		var gi: GeometryInstance3D = e.get_node_or_null("Cuerpo/" + p) as GeometryInstance3D
		var m: ShaderMaterial = gi.material_override as ShaderMaterial if gi != null else null
		_ok("6 %s: fps del shader = %d y rampa de 5 escalones constantes" % [p, FPS_TOON], m != null and int(m.get_shader_parameter("fps")) == FPS_TOON and _rampa_constante(m.get_shader_parameter("rampa")))
	var n_lenguas: int = 0
	for p in ["LenguasSueltas"]:
		var gp: GPUParticles3D = e.get_node_or_null("Cuerpo/" + p) as GPUParticles3D
		n_lenguas += gp.amount if gp != null else 0
	_ok("6 lenguas sueltas ≤ 30 (%d) sobre la cinta de 6 planos" % n_lenguas, n_lenguas >= 1 and n_lenguas <= 30)
	# 3: escalado
	var v: Dictionary = {"x": REF.x * 0.5 / CASILLA, "y": REF.y * 0.5 / CASILLA, "z": REF.z * 0.5 / CASILLA}
	e.call("preparar", v, Vector3(0, 0, -1), "fuego")
	_ok("3 escala 1 con el volumen de referencia", (e.scale - Vector3.ONE).length() <= TOL_ESCALA * 3.0, str(e.scale))
	var v2: Dictionary = {"x": v["x"] * 2.0, "y": v["y"], "z": v["z"]}
	e.call("preparar", v2, Vector3(0, 0, -1), "fuego")
	_ok("3 escala X 2 con el doble de X", absf(e.scale.x - 2.0) <= TOL_ESCALA * 2.0 and absf(e.scale.y - 1.0) <= TOL_ESCALA, str(e.scale))
	# 4: vida
	var dura_morir: float = float(e.get("dura_morir"))
	e.call("lanzar", 1.0)
	await _segundos(1.0 + 0.1 + dura_morir)
	_ok("4 lanzar(1) libera en 1 s + morir", not is_instance_valid(e), "sigue vivo")
	if is_instance_valid(e):
		e.queue_free()
	var e2: Node3D = ps.instantiate() as Node3D
	_raiz.add_child(e2)
	e2.call("lanzar", -1.0)
	await _segundos(0.3)
	_ok("4 lanzar(-1) sigue vivo a los 0,3 s", is_instance_valid(e2))
	if is_instance_valid(e2):
		e2.call("morir")
		await _segundos(dura_morir + 0.15)
		_ok("4 morir() libera en dura_morir", not is_instance_valid(e2), "sigue vivo")
		if is_instance_valid(e2):
			e2.queue_free()


## Columna, bola e impacto (opcionales): cargan, llevan EfectoVfx3D con nacer y morir, una luz y ≤ 300 partículas, y todas sus partículas a 12 fps.
func _presupuesto_extra() -> void:
	for nombre in ["ColumnaFuegoToon", "BolaFuegoToon", "ImpactoFuegoToon"]:
		print("— " + nombre)
		var ps: PackedScene = load(DIR + nombre + ".tscn") as PackedScene
		_ok("1 existe y carga", ps != null)
		if ps == null:
			continue
		var e: Node3D = ps.instantiate() as Node3D
		_raiz.add_child(e)
		var ap: AnimationPlayer = e.get_node_or_null("Anim") as AnimationPlayer
		_ok("1 EfectoVfx3D con nacer y morir", e is EfectoVfx3D and ap != null and ap.has_animation("nacer") and ap.has_animation("morir"))
		var luces: int = 0
		var part: int = 0
		var a_12: bool = true
		for n in e.find_children("*", "", true, false):
			if n is Light3D:
				luces += 1
			elif n is GPUParticles3D:
				part += (n as GPUParticles3D).amount
				a_12 = a_12 and (n as GPUParticles3D).fixed_fps == FPS_TOON and not (n as GPUParticles3D).interpolate
		_ok("2 luces = 1", luces == 1, str(luces))
		_ok("2 partículas ≤ %d" % MAX_PARTICULAS, part <= MAX_PARTICULAS, str(part))
		_ok("6 partículas a %d fps sin interpolar" % FPS_TOON, a_12)
		e.queue_free()


## Valor por defecto de un uniform float leído del código del shader (en headless el servidor de render no lo da): «uniform float nombre ... = 0.01;». 99 si no se encuentra.
func _defecto(sh: Shader, nombre: String) -> float:
	if sh == null:
		return 99.0
	var re: RegEx = RegEx.new()
	re.compile("uniform\\s+float\\s+" + nombre + "\\b[^=;]*=\\s*([-0-9.]+)\\s*;")
	var m: RegExMatch = re.search(sh.code)
	return float(m.get_string(1)) if m != null else 99.0


func _rampa_constante(t: Variant) -> bool:
	var g: GradientTexture1D = t as GradientTexture1D
	return g != null and g.gradient != null and g.gradient.interpolation_mode == Gradient.GRADIENT_INTERPOLATE_CONSTANT and g.gradient.get_point_count() == 5


func _shaders() -> void:
	print("— shaders")
	for s in SHADERS:
		var sh: Shader = load(DIR + s + ".gdshader") as Shader
		_ok("5 " + s + " carga", sh != null and sh.get_rid().is_valid())
		if sh == null:
			continue
		_ok("5 " + s + " es unshaded (sin luz ni sombra)", sh.code.contains("unshaded"))
	var fuego: Shader = load(DIR + "fuego_toon.gdshader") as Shader
	if fuego == null:
		return
	var uni: Dictionary = {}
	for u in fuego.get_shader_uniform_list():
		uni[String(u["name"])] = u
	for m in MANDOS:
		_ok("5 mando «%s» en el inspector" % m, uni.has(m))
	var rangos: int = 0
	for m in MANDOS:
		if m == "rampa":
			continue
		if uni.has(m) and String((uni[m] as Dictionary).get("hint_string", "")).split(",").size() >= 2:
			rangos += 1
	_ok("5 los nueve mandos numéricos tienen rango (hint_range)", rangos == MANDOS.size() - 1, str(rangos))
	var sua: Dictionary = uni.get("suavidad", {})
	var tope: float = float(String(sua.get("hint_string", "99,99")).split(",")[1]) if sua.has("hint_string") else 99.0
	_ok("5 suavidad ≤ %.2f (borde duro): tope del rango %.3f" % [MAX_SUAVIDAD, tope], tope <= MAX_SUAVIDAD + 0.0001)
	var por_defecto: float = _defecto(fuego, "suavidad")
	_ok("5 suavidad por defecto ≤ %.2f (%.3f)" % [MAX_SUAVIDAD, por_defecto], por_defecto <= MAX_SUAVIDAD + 0.0001)


## 6: el tiempo del shader está cuantizado (se lee en el código; si alguien lo cambia, esto avisa).
func _cuantizado() -> void:
	print("— cuantizado a 12 fps")
	var fuego: Shader = load(DIR + "fuego_toon.gdshader") as Shader
	_ok("6 fuego_toon usa floor(TIME * fps) / fps", fuego != null and fuego.code.contains("floor(TIME * fps) / fps"))
	var fps_defecto: float = _defecto(fuego, "fps")
	_ok("6 fps por defecto = %d" % FPS_TOON, int(fps_defecto) == FPS_TOON, str(fps_defecto))
	_ok("6 fuego_toon descarta (alfa 0/1, sin mezcla)", fuego != null and fuego.code.contains("discard"))


## 7: colores de la llama en la captura, a 5 bits por canal, sin el negro del fondo.
func _paleta() -> void:
	print("— paleta")
	var ruta: String = ProjectSettings.globalize_path(CAPTURA_LLAMA)
	_ok("7 existe " + CAPTURA_LLAMA.get_file(), FileAccess.file_exists(ruta), ruta)
	if not FileAccess.file_exists(ruta):
		return
	var img: Image = Image.load_from_file(ruta)
	_ok("7 la captura se lee", img != null and img.get_width() > 0)
	if img == null:
		return
	var colores: Dictionary = {}
	var pintados: int = 0
	var desplaza: int = 8 - BITS_PALETA
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			var r: int = int(round(c.r * 255.0))
			var g: int = int(round(c.g * 255.0))
			var b: int = int(round(c.b * 255.0))
			if r + g + b < 12:
				continue
			pintados += 1
			var k: int = ((r >> desplaza) << (2 * BITS_PALETA)) | ((g >> desplaza) << BITS_PALETA) | (b >> desplaza)
			colores[k] = int(colores.get(k, 0)) + 1
	var lista: Array = colores.keys()
	lista.sort_custom(func(a, b): return colores[a] > colores[b])
	var txt: String = ""
	for k in lista.slice(0, 12):
		var mask: int = (1 << BITS_PALETA) - 1
		txt += " #%02X%02X%02X(%d)" % [((int(k) >> (2 * BITS_PALETA)) & mask) << desplaza, ((int(k) >> BITS_PALETA) & mask) << desplaza, (int(k) & mask) << desplaza, colores[k]]
	print("  colores a %d bits: %d (en %d píxeles pintados):%s" % [BITS_PALETA, colores.size(), pintados, txt])
	_ok("7 la captura tiene llama (> 1000 píxeles)", pintados > 1000, str(pintados))
	_ok("7 colores distintos a %d bits ≤ %d" % [BITS_PALETA, MAX_COLORES], colores.size() <= MAX_COLORES, str(colores.size()))


## 8: el lab compila y ofrece la tecla 5 y los diez mandos.
func _lab() -> void:
	print("— lab")
	var s: GDScript = load("res://laboratorios/lab_vfx_comparativa_3d.gd") as GDScript
	_ok("8 el lab compila", s != null and s.can_instantiate())
	if s == null:
		return
	_ok("8 tiene la tecla 5 (KEY_5) y muro_toon", s.source_code.contains("KEY_5: efecto(\"muro_toon\")"))
	var mandos: Variant = s.get_script_constant_map().get("MANDOS_TOON", [])
	_ok("8 MANDOS_TOON tiene los diez", mandos is Array and (mandos as Array).size() == MANDOS.size(), str(mandos.size()) if mandos is Array else "no es Array")
	if mandos is Array:
		var nombres: PackedStringArray = PackedStringArray()
		for d in mandos:
			nombres.append(String(d[0]))
		_ok("8 los nombres de los mandos del lab son los del shader", Array(nombres) == Array(MANDOS), str(nombres))


func _segundos(s: float) -> void:
	var t: float = 0.0
	while t < s:
		t += root.get_process_delta_time() if root.get_process_delta_time() > 0.0 else 1.0 / 60.0
		await process_frame
