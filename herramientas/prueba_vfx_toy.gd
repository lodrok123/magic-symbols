extends SceneTree

## PRUEBA de los cinco efectos de fuego «toy» (1/11, docs/PRUEBA3_VFX_TOY_2026-11-01.md §3). Sin ventana:
##   godot --headless --path . --script res://herramientas/prueba_vfx_toy.gd
## Para BolaFuegoToy, MuroFuegoToy, PilarFuegoToy, BarreraFuegoToy (y ImpactoBolaToy, que la bola instancia al chocar) comprueba:
##   1. la escena existe, carga, su raíz lleva EfectoToy (contrato EfectoVfx3D: preparar / lanzar / morir / impactar) y «Anim» con nacer, vivir y morir
##   2. presupuesto: ≤ 1 luz y ≤ 300 partículas (suma de `amount`)
##   3. los DIEZ mandos del raíz existen, en castellano, con rango (hint_range), y los mismos diez están en el lab con el mismo rango
##   4. los mandos mandan: altura, ancho, tono, chispas, halo y luz llegan a los materiales, las partículas y la luz de ESA instancia (no de las demás)
##   5. `preparar` escala el raíz al volumen (tamaño de referencia → escala 1; doble → 2) y `lanzar(vida)` libera el nodo en vida + dura_morir + 0,2 s
##   6. estilo (por el código de los shaders): rampa continua, sin tiempo cuantizado, sin contorno, sin umbral duro (discard), borde blando (blandura ≥ 0,15),
##      colores cálidos: ningún rojo oscuro (verde ≥ 0,35 en los tres colores de fuego) y la versión azul solo por el mando `tono`
##   7. las capturas del diseño existen en docs/capturas/comparativa_vfx/godot_toy/ (11 PNG + un GIF por efecto) y diez_muros tiene su fps
##   8. el lab compila, tiene F1 a F6, y las cinco modificaciones de Pablo se hacen con un mando o un parámetro (comprobado aquí con los mandos)
## NO comprueba (necesita ventana y GPU): que los shaders COMPILEN de verdad (se ve porque salen en las capturas), el aspecto, ni el fps.
## Imprime FALLOS: n al final.

const MAX_LUCES: int = 1
const MAX_PARTICULAS: int = 300
const DIR: String = "res://presentacion/vfx/toy/"
const CAPTURAS: String = "res://docs/capturas/comparativa_vfx/godot_toy/"
const ESCENAS: Dictionary = {
	"BolaFuegoToy": Vector3(0.8, 0.8, 0.8), "MuroFuegoToy": Vector3(6.9, 1.5, 0.3), "PilarFuegoToy": Vector3(1.0, 4.0, 1.0),
	"BarreraFuegoToy": Vector3(3.0, 3.0, 3.0), "ImpactoBolaToy": Vector3(1.0, 1.0, 1.0)}
const MANDOS: PackedStringArray = ["altura", "chisporroteo", "blandura", "ondulacion", "velocidad", "brillo", "halo", "tono", "chispas", "luz"]
const PNG: PackedStringArray = ["bola_cerca", "bola_juego", "bola_vuelo", "bola_impacto", "muro_cerca", "muro_juego", "pilar_cerca", "pilar_juego", "barrera_cerca", "barrera_juego", "diez_muros"]
const GIF: PackedStringArray = ["bola_3s", "bola_vuelo_3s", "muro_3s", "pilar_3s", "barrera_3s"]
const SHADERS: PackedStringArray = ["llama_toy.gdshader", "halo_toy.gdshader", "barrera_toy.gdshader", "barrera_toy_trasera.gdshader"]

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
	for nombre in ESCENAS:
		print("== " + nombre)
		await _escena(nombre, ESCENAS[nombre])
	await _mandos_mandan()
	_estilo()
	_capturas()
	_lab()
	await _modificaciones()
	print("FALLOS: %d" % _fallos)
	quit(0 if _fallos == 0 else 1)


func _cargar(nombre: String) -> Node3D:
	var ruta: String = DIR + nombre + ".tscn"
	if not ResourceLoader.exists(ruta):
		return null
	var ps: PackedScene = load(ruta) as PackedScene
	return ps.instantiate() as Node3D if ps != null else null


func _escena(nombre: String, tam_ref: Vector3) -> void:
	var e: Node3D = _cargar(nombre)
	_ok("existe y carga", e != null)
	if e == null:
		return
	_ok("raíz EfectoToy con preparar / lanzar / morir / impactar", e is EfectoToy and e.has_method("preparar") and e.has_method("lanzar") and e.has_method("morir") and e.has_method("impactar"))
	_raiz.add_child(e)
	await process_frame
	var ap: AnimationPlayer = e.get_node_or_null("Anim") as AnimationPlayer
	_ok("Anim con nacer, vivir y morir", ap != null and ap.has_animation("nacer") and ap.has_animation("vivir") and ap.has_animation("morir"))
	var luces: int = 0
	var part: int = 0
	for n in e.find_children("*", "", true, false):
		if n is Light3D:
			luces += 1
		elif n is GPUParticles3D:
			part += (n as GPUParticles3D).amount
	_ok("presupuesto: luces %d ≤ %d" % [luces, MAX_LUCES], luces <= MAX_LUCES)
	_ok("presupuesto: partículas %d ≤ %d" % [part, MAX_PARTICULAS], part <= MAX_PARTICULAS)
	_ok("hay al menos una luz y chispas (pocas)", luces == 1 and part >= 4 and part <= 40, "luces %d partículas %d" % [luces, part])
	# preparar: tamaño de referencia -> escala 1 ; doble de largo -> 2
	var casilla: float = float(e.get("casilla"))
	e.call("preparar", {"x": tam_ref.x / (2.0 * casilla), "y": tam_ref.y / (2.0 * casilla), "z": tam_ref.z / (2.0 * casilla)}, Vector3.ZERO, "fuego")
	_ok("preparar con el tamaño de referencia deja escala 1", absf(e.scale.x - 1.0) < 0.02 and absf(e.scale.y - 1.0) < 0.02, str(e.scale))
	e.scale = Vector3.ONE
	e.call("preparar", {"x": 2.0 * tam_ref.x / (2.0 * casilla), "y": tam_ref.y / (2.0 * casilla), "z": tam_ref.z / (2.0 * casilla)}, Vector3.ZERO, "fuego")
	_ok("preparar con el doble de largo deja escala 2 en X", absf(e.scale.x - 2.0) < 0.02, str(e.scale))
	e.queue_free()
	await process_frame
	# lanzar(vida) libera el nodo
	var f: Node3D = _cargar(nombre)
	_raiz.add_child(f)
	await process_frame
	var vida: float = 0.8
	var espera: float = vida + float(f.get("dura_morir")) + 0.2
	f.call("lanzar", vida)
	var t0: int = Time.get_ticks_msec()
	while is_instance_valid(f) and float(Time.get_ticks_msec() - t0) / 1000.0 < espera + 0.5:
		await process_frame
	var t: float = float(Time.get_ticks_msec() - t0) / 1000.0
	_ok("lanzar(%.1f) se libera solo a los %.2f s (esperado ≤ %.2f)" % [vida, t, espera], not is_instance_valid(f) and t <= espera + 0.05, "tarda %.2f" % t)


func _rangos(e: Object) -> Dictionary:
	var r: Dictionary = {}
	for p in e.get_property_list():
		if p["name"] in MANDOS and int(p["hint"]) == PROPERTY_HINT_RANGE:
			var partes: PackedStringArray = String(p["hint_string"]).split(",")
			r[p["name"]] = [float(partes[0]), float(partes[1])]
	return r


func _mandos_mandan() -> void:
	print("== los diez mandos")
	var a: Node3D = _cargar("MuroFuegoToy")
	var b: Node3D = _cargar("MuroFuegoToy")
	_raiz.add_child(a)
	_raiz.add_child(b)
	await process_frame
	var r: Dictionary = _rangos(a)
	_ok("diez mandos con rango en el raíz", r.size() == 10, str(r.keys()))
	a.set("altura", 2.0)
	a.set("chisporroteo", 0.0)
	a.set("tono", 1.0)
	a.set("blandura", 0.4)
	var m_a: ShaderMaterial = _primer_material(a, "llama_toy.gdshader")
	var m_b: ShaderMaterial = _primer_material(b, "llama_toy.gdshader")
	_ok("altura llega al material de la instancia", m_a != null and absf(float(m_a.get_shader_parameter("altura")) - 2.0) < 0.001)
	_ok("chisporroteo, tono y blandura llegan", m_a != null and absf(float(m_a.get_shader_parameter("chisporroteo"))) < 0.001 and absf(float(m_a.get_shader_parameter("tono")) - 1.0) < 0.001
		and absf(float(m_a.get_shader_parameter("blandura")) - 0.4) < 0.001)
	_ok("las demás instancias no cambian (materiales propios)", m_b != null and m_a != m_b and absf(float(m_b.get_shader_parameter("altura")) - 1.0) < 0.001)
	a.set("chispas", 0.5)
	var gp: GPUParticles3D = a.find_child("Chispas", true, false) as GPUParticles3D
	_ok("chispas 0,5 pone la mitad de partículas", gp != null and absf(gp.amount_ratio - 0.5) < 0.001)
	a.set("luz", 2.0)
	var l: OmniLight3D = a.find_child("Luz", true, false) as OmniLight3D
	await process_frame
	await process_frame
	var l2: OmniLight3D = b.find_child("Luz", true, false) as OmniLight3D
	_ok("luz 2 sube la energía de esa luz (y no la de la otra)", l != null and l2 != null and l.light_energy > 1.4 * l2.light_energy, "%.2f frente a %.2f" % [l.light_energy, l2.light_energy])
	var h_a: ShaderMaterial = _primer_material(a, "halo_toy.gdshader")
	a.set("halo", 0.0)
	_ok("halo 0 apaga el resplandor", h_a != null and absf(float(h_a.get_shader_parameter("brillo"))) < 0.001)
	a.queue_free()
	b.queue_free()
	await process_frame


func _primer_material(e: Node, shader: String) -> ShaderMaterial:
	for n in e.find_children("*", "GeometryInstance3D", true, false):
		var m: ShaderMaterial = (n as GeometryInstance3D).material_override as ShaderMaterial
		if m != null and m.shader != null and (m.shader.resource_path.get_file() == shader or (shader == "llama_toy.gdshader" and m.shader.resource_path.get_file().begins_with("fuego_lelu"))):
			return m
	return null


func _estilo() -> void:
	print("== estilo (código de los shaders)")
	var todo: String = ""
	for s in SHADERS:
		var ruta: String = DIR + s
		_ok("carga " + s, ResourceLoader.exists(ruta) and load(ruta) is Shader)
		var cod: String = FileAccess.get_file_as_string(ruta)
		_ok(s + ": unshaded", cod.contains("unshaded"))
		todo += cod
	var inc: String = FileAccess.get_file_as_string(DIR + "barrera_toy.gdshaderinc")
	todo += inc
	var llama: String = FileAccess.get_file_as_string(DIR + "llama_toy.gdshader")
	_ok("sin tiempo cuantizado (ningún floor(TIME ...))", not todo.contains("floor(TIME"))
	var re_c: RegEx = RegEx.new()
	re_c.compile("uniform[^;]*(contorno|outline|borde_oscuro)")
	_ok("sin contorno (ningún uniform de contorno)", re_c.search(todo.to_lower()) == null)
	_ok("sin umbral duro (ningún discard salvo el del suelo de la barrera)", llama.count("discard") == 0 and inc.count("discard") == 1)
	var bl: float = _defecto(llama, "blandura")
	_ok("borde blando: blandura por defecto %.2f ≥ 0,15" % bl, bl >= 0.15)
	_ok("rampa continua: mix + smoothstep, sin step() ni escalones", llama.contains("smoothstep") and llama.contains("mix(") and not llama.contains(" step("))
	# colores de fuego: los tres vec3 de la rampa (naranja, amarillo, blanco) antes de la versión azul
	var re: RegEx = RegEx.new()
	re.compile("c_(rojo|naranja|amarillo|blanco)\\s*=\\s*mix\\(vec3\\(([0-9.]+),\\s*([0-9.]+),\\s*([0-9.]+)\\)")
	var vistos: int = 0
	var oscuros: bool = false
	for ms in re.search_all(llama):
		vistos += 1
		var rr: float = float(ms.get_string(2))
		var gg: float = float(ms.get_string(3))
		if rr < 0.85 or (ms.get_string(1) != "rojo" and gg < 0.3):
			oscuros = true
	_ok("cuatro colores de la rampa (rojo-anaranjado #D9...: r ≥ 0,85; naranja, amarillo y blanco con g ≥ 0,3), ninguno rojo oscuro", vistos == 4 and not oscuros, "vistos %d" % vistos)
	# ronda 3: fuego por texturas (Le Lu)
	var lelu: String = FileAccess.get_file_as_string(DIR + "fuego_lelu.gdshaderinc")
	_ok("ronda 3: fuego_lelu con smoothstep(umbral, umbral + blandura), rampa 1D, gradiente vertical y vértices desplazados", lelu.contains("smoothstep(umbral, umbral + blandura, f)") and lelu.contains("rampa") and lelu.contains("pow(vg, pot_grad)") and lelu.contains("textureLod(ruido_v"))
	_ok("ronda 3: sin discard y sin contorno", not lelu.contains("discard") and not lelu.contains("contorno"))
	for t in ["T_FirePanningCyl45.png", "T_PerlinNoise_Tiled.png", "T_CloudNoise_Tiled.png", "T_Noise1_tiled.png", "readme.txt"]:
		_ok("textura de Le Lu " + t, ResourceLoader.exists("res://assets/vfx/lelu_noise/" + t) or FileAccess.file_exists("res://assets/vfx/lelu_noise/" + t))
	for n in ["BolaFuegoToy_r2", "MuroFuegoToy_r2", "PilarFuegoToy_r2", "BarreraFuegoToy_r2"]:
		_ok("escena de la ronda 2 guardada: " + n, _cargar(n) != null)
	_ok("el azul solo entra por el mando tono", llama.contains("mix(vec3(1.0, 0.30") and llama.contains("tono"))


func _defecto(codigo: String, nombre: String) -> float:
	var re: RegEx = RegEx.new()
	re.compile("uniform float " + nombre + "[^=]*=\\s*([0-9.]+)")
	var m: RegExMatch = re.search(codigo)
	return float(m.get_string(1)) if m != null else -1.0


func _capturas() -> void:
	print("== capturas")
	for n in PNG:
		var ruta: String = CAPTURAS + n + ".png"
		_ok("existe " + n + ".png", FileAccess.file_exists(ruta) and FileAccess.get_file_as_bytes(ruta).size() > 20000)
	for n in GIF:
		var ruta: String = CAPTURAS + n + ".gif"
		_ok("existe " + n + ".gif (3 s)", FileAccess.file_exists(ruta) and FileAccess.get_file_as_bytes(ruta).size() > 100000)
	var f: String = FileAccess.get_file_as_string(CAPTURAS + "diez_muros_fps.txt")
	_ok("diez_muros_fps.txt con el fps a 1920×1080", f.contains("fps") and f.contains("1920"))
	_ok("NOTAS.md con las notas por efecto", FileAccess.get_file_as_string(CAPTURAS + "NOTAS.md").contains("Nota propia"))


func _lab() -> void:
	print("== lab")
	var lab: GDScript = load("res://laboratorios/lab_vfx_comparativa_3d.gd") as GDScript
	_ok("el lab compila", lab != null and lab.can_instantiate())
	if lab == null:
		return
	var cod: String = lab.source_code
	for k in ["KEY_F1", "KEY_F2", "KEY_F3", "KEY_F4", "KEY_F5", "KEY_F6"]:
		_ok("tecla " + k, cod.contains(k + ":"))
	var consts: Dictionary = lab.get_script_constant_map()
	var mandos: Array = consts.get("MANDOS_TOY", [])
	_ok("MANDOS_TOY tiene los diez mandos", mandos.size() == 10)
	var e: Node3D = _cargar("BolaFuegoToy")
	var r: Dictionary = _rangos(e)
	e.free()
	for m in mandos:
		var n: String = m[0]
		var ok: bool = r.has(n) and absf(float(r[n][0]) - float(m[1])) < 0.001 and absf(float(r[n][1]) - float(m[2])) < 0.001
		_ok("mando %s: mismo rango en el lab y en el inspector" % n, ok, "lab %s-%s inspector %s" % [m[1], m[2], str(r.get(n))])


## Las cinco modificaciones de Pablo con mandos o parámetros: (1) azul = tono 1; (2) llama el doble de alta = altura 2; (3) mitad de chispas = chispas 0,5;
## (4) barrera el doble de grande = escala 2 del raíz (preparar); (5) pilar que dura 1 s y se apaga = lanzar(1.0).
func _modificaciones() -> void:
	print("== las cinco modificaciones")
	var p: Node3D = _cargar("PilarFuegoToy")
	_raiz.add_child(p)
	await process_frame
	p.set("tono", 1.0)
	p.set("altura", 2.0)
	p.set("chispas", 0.5)
	var m: ShaderMaterial = _primer_material(p, "llama_toy.gdshader")
	_ok("(1) fuego azul: tono 1", m != null and float(m.get_shader_parameter("tono")) == 1.0)
	_ok("(2) llama el doble de alta: altura 2", m != null and float(m.get_shader_parameter("altura")) == 2.0)
	_ok("(3) mitad de chispas: chispas 0,5", (p.find_child("Chispas", true, false) as GPUParticles3D).amount_ratio == 0.5)
	p.call("lanzar", 1.0)
	var t0: int = Time.get_ticks_msec()
	while is_instance_valid(p) and float(Time.get_ticks_msec() - t0) < 3000.0:
		await process_frame
	var t: float = float(Time.get_ticks_msec() - t0) / 1000.0
	_ok("(5) pilar que dura 1 s y se apaga: lanzar(1.0) lo libera a los %.2f s" % t, not is_instance_valid(p) and t < 1.9)
	var b: Node3D = _cargar("BarreraFuegoToy")
	_raiz.add_child(b)
	await process_frame
	b.scale = Vector3(2, 2, 2)
	_ok("(4) barrera el doble de grande: escala 2 en el raíz", b.scale == Vector3(2, 2, 2))
	b.queue_free()
