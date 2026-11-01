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
	await _parametrico()
	await _pulido()
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


# ---------------------------------------------------------------- FuegoToy (fuego paramétrico) ----------------------------------------------------------------

func _ft(fig: int, x: float, y: float, z: float, vuela: bool = false) -> FuegoToy:
	var e: FuegoToy = FuegoToy.new()
	e.definir(fig, x, y, z, vuela)
	_raiz.add_child(e)
	return e


func _aabb(e: Node, nodo: String) -> AABB:
	var mi: MeshInstance3D = e.find_child(nodo, true, false) as MeshInstance3D
	return mi.mesh.get_aabb() if mi != null and mi.mesh != null else AABB()


func _param(e: Node, nodo: String, nombre: String) -> Variant:
	var mi: MeshInstance3D = e.find_child(nodo, true, false) as MeshInstance3D
	if mi == null or not (mi.material_override is ShaderMaterial):
		return null
	return (mi.material_override as ShaderMaterial).get_shader_parameter(nombre)


func _cerca(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


## FuegoToy: un solo efecto con ejes que produce las cuatro figuras. Comprueba la geometría contra los semiejes, que reproduce las escenas validadas con el tamaño de la prueba 3,
## que alargar un muro no estira la textura, que `desde_hechizo` elige la figura, y que las cinco modificaciones de Pablo y el presupuesto valen aquí también.
func _parametrico() -> void:
	print("== FuegoToy (paramétrico)")
	var F = FuegoToy.Figura
	# 1. contrato y mandos
	var e0: FuegoToy = _ft(F.MURO, 3.45, 1.5, 0.3)
	await process_frame
	_ok("FuegoToy es un EfectoToy con el contrato (preparar / lanzar / morir / impactar) y Anim", e0 is EfectoToy and e0.has_method("preparar") and e0.has_method("lanzar")
		and e0.has_method("morir") and e0.has_method("impactar") and (e0.get_node("Anim") as AnimationPlayer).has_animation("morir"))
	_ok("FuegoToy hereda los diez mandos con rango", _rangos(e0).size() == 10)
	e0.queue_free()
	await process_frame
	# 2. geometría = semiejes, con el tamaño de la prueba 3 y con otros
	var casos: Array = [
		[F.MURO, 3.45, 1.5, 0.3, "Banda"], [F.MURO, 6.0, 0.8, 0.3, "Banda"], [F.MURO, 1.5, 1.5, 0.3, "Banda"], [F.PILAR, 0.5, 4.0, 0.5, "Exterior"],
		[F.PILAR, 0.3, 6.0, 0.3, "Exterior"], [F.PILAR, 1.0, 1.5, 1.0, "Exterior"], [F.PILAR, 0.6, 3.0, 0.3, "Exterior"], [F.BARRERA, 1.5, 1.5, 1.5, "Cascara"],
		[F.BARRERA, 1.5, 0.8, 1.5, "Cascara"], [F.BARRERA, 2.5, 2.0, 1.2, "Cascara"]]
	for c in casos:
		var e: FuegoToy = _ft(c[0], c[1], c[2], c[3])
		await process_frame
		var bb: AABB = _aabb(e, c[4])
		var esp_y: float = float(c[2]) * (2.0 if c[0] == F.BARRERA else 1.0)
		var ok: bool = _cerca(bb.size.x, 2.0 * float(c[1]), 0.02 * float(c[1]) + 0.01) and _cerca(bb.size.y, esp_y, 0.01 * esp_y + 0.01) and _cerca(bb.size.z, 2.0 * float(c[3]), 0.02 * float(c[3]) + 0.01)
		_ok("malla %s de %s: AABB %s ≈ (2x, y, 2z) = (%.2f, %.2f, %.2f)" % [c[4], ["bola", "muro", "pilar", "barrera"][c[0]], str(bb.size), 2.0 * float(c[1]), esp_y, 2.0 * float(c[3])], ok)
		e.queue_free()
		await process_frame
	# la bola: radio máx(x, z), y alto por escala Y del quad
	var b1: FuegoToy = _ft(F.BOLA, 0.4, 0.8, 0.4)
	var b2: FuegoToy = _ft(F.BOLA, 0.6, 0.3, 0.2)
	await process_frame
	var ll: MeshInstance3D = b1.find_child("Llama", true, false) as MeshInstance3D
	_ok("bola 0,4·0,8·0,4: quad de 2,4 m (radio 0,4) y escala Y 2 (elipsoide alta)", ll != null and _cerca((ll.mesh as QuadMesh).size.x, 2.4, 0.01) and _cerca(ll.scale.y, 2.0, 0.01))
	var ll2: MeshInstance3D = b2.find_child("Llama", true, false) as MeshInstance3D
	_ok("bola 0,6·0,3·0,2: radio = máx(x, z) = 0,6 (quad de 3,6 m) y escala Y 0,5", ll2 != null and _cerca((ll2.mesh as QuadMesh).size.x, 3.6, 0.01) and _cerca(ll2.scale.y, 0.5, 0.01))
	b1.queue_free()
	b2.queue_free()
	await process_frame
	# 3. con el tamaño de la prueba 3 sale lo mismo que las escenas validadas (mallas y repeticiones de textura)
	var pares: Array = [["MuroFuegoToy", F.MURO, 3.45, 1.5, 0.3, ["Banda", "Interior"]], ["PilarFuegoToy", F.PILAR, 0.5, 4.0, 0.5, ["Exterior", "Nucleo"]],
		["BarreraFuegoToy", F.BARRERA, 1.5, 1.5, 1.5, ["Cascara"]]]
	for p in pares:
		var v: Node3D = _cargar(p[0])
		_raiz.add_child(v)
		var e: FuegoToy = _ft(p[1], p[2], p[3], p[4])
		await process_frame
		for nodo in p[5]:
			var a1: AABB = _aabb(v, nodo)
			var a2: AABB = _aabb(e, nodo)
			_ok("%s/%s: malla de FuegoToy ≈ la validada (%s frente a %s)" % [p[0], nodo, str(a2.size), str(a1.size)], a1.size.distance_to(a2.size) < 0.02 * a1.size.length())
			for u in ["repeticion", "rep_ruido"]:
				var r1: Vector2 = _param(v, nodo, u)
				var r2: Vector2 = _param(e, nodo, u)
				_ok("%s/%s: %s = %s (validada %s)" % [p[0], nodo, u, str(r2), str(r1)], absf(r1.x - r2.x) < 0.001 and absf(r1.y - r2.y) < 0.06)
		v.queue_free()
		e.queue_free()
		await process_frame
	# 4. un muro más largo NO estira la textura: más repeticiones, y los metros de contorno por repetición se quedan en ~2,9
	var m3: FuegoToy = _ft(F.MURO, 1.5, 1.5, 0.3)
	var m12: FuegoToy = _ft(F.MURO, 6.0, 1.5, 0.3)
	await process_frame
	var r3: Vector2 = _param(m3, "Banda", "repeticion")
	var r12: Vector2 = _param(m12, "Banda", "repeticion")
	_ok("muro de 3 m (%.0f repeticiones) y de 12 m (%.0f): el largo cambia el nº de repeticiones" % [r3.x, r12.x], r12.x > r3.x + 2.0)
	var mpr3: float = FuegoToyMallas.largo_contorno(1.5, 0.3, 6.0) / r3.x
	var mpr12: float = FuegoToyMallas.largo_contorno(6.0, 0.3, 6.0) / r12.x
	_ok("metros de contorno por repetición: 3 m → %.2f, 12 m → %.2f (validado 2,90): no se estira" % [mpr3, mpr12], absf(mpr3 - 2.9) < 0.9 and absf(mpr12 - 2.9) < 0.9 and absf(mpr12 / mpr3 - 1.0) < 0.35)
	m3.queue_free()
	m12.queue_free()
	await process_frame
	# 5. reconstruir en vivo: cambiar un eje rehace la malla y conserva los mandos
	var viv: FuegoToy = _ft(F.PILAR, 0.5, 4.0, 0.5)
	await process_frame
	viv.set("tono", 1.0)
	viv.semieje_y = 2.0
	viv.semieje_x = 1.0
	await process_frame
	await process_frame
	var bv: AABB = _aabb(viv, "Exterior")
	_ok("cambiar los ejes en vivo rehace la malla (alto 2, ancho 2: %s)" % str(bv.size), _cerca(bv.size.y, 2.0, 0.02) and _cerca(bv.size.x, 2.0, 0.04))
	_ok("... y conserva los mandos (tono 1)", _cerca(float((_primer_material(viv, "llama_toy.gdshader") as ShaderMaterial).get_shader_parameter("tono")), 1.0, 0.001))
	viv.figura = F.MURO
	await process_frame
	await process_frame
	_ok("cambiar de figura en vivo (pilar → muro) también", viv.find_child("Banda", true, false) != null and viv.find_child("Exterior", true, false) == null)
	viv.queue_free()
	await process_frame
	# 6. desde_hechizo
	var casilla: float = 2.3
	var casos_h: Array = [
		["muro", Vector3(1.5, 0.652, 0.13), 0.0, 0.0, F.MURO], ["pilar", Vector3(0.2, 1.7, 0.2), 0.0, 0.0, F.PILAR], ["bola", Vector3(0.3, 0.3, 0.3), 0.0, 0.0, F.BOLA],
		["barrera (cúpula)", Vector3(0.65, 0.65, 0.65), 0.0, 1.5, F.BARRERA], ["barrera alargada", Vector3(1.2, 0.5, 0.2), 0.0, 1.5, F.MURO], ["flecha (viaja)", Vector3(0.3, 0.3, 0.3), 8.0, 0.0, F.BOLA]]
	for c in casos_h:
		var h: Hechizo = Hechizo.new()
		h.semieje_x = c[1].x
		h.semieje_y = c[1].y
		h.semieje_z = c[1].z
		h.velocidad = c[2]
		h.solidez = c[3]
		var d: Dictionary = FuegoToy.describir(h, casilla)
		_ok("desde_hechizo %s → figura %s (nombre derivado «%s»)" % [c[0], ["BOLA", "MURO", "PILAR", "BARRERA"][d["figura"]], d["nombre"]], d["figura"] == c[4])
		var e: FuegoToy = FuegoToy.new()
		e.desde_hechizo(h)
		_raiz.add_child(e)
		await process_frame
		var esp: Vector3 = h.semiejes_vuelo * casilla if c[2] > 0.0 else h.semiejes * casilla
		var largo: float = maxf(esp.x, esp.z)
		var corto: float = minf(esp.x, esp.z)
		var xx: float = e.semieje_x if e.figura != F.MURO else e.semieje_x
		var ok_t: bool = _cerca(e.semieje_y, esp.y, 0.01)
		if e.figura == F.MURO:
			ok_t = ok_t and _cerca(e.semieje_x, largo, 0.01) and _cerca(e.semieje_z, corto, 0.01)
		else:
			ok_t = ok_t and _cerca(e.semieje_x, esp.x, 0.01) and _cerca(e.semieje_z, esp.z, 0.01)
		_ok("   tamaño en metros = semiejes × %.1f (flecha: × Hechizo.ESCALA_PROYECTIL): %s" % [casilla, str(e.semiejes())], ok_t and xx > 0.0)
		_ok("   viaja = %s" % str(e.viaja), e.viaja == (c[2] > 0.0))
		e.queue_free()
		await process_frame
	var haz: Hechizo = Hechizo.new()
	haz.glifos = {"linea_x": 1}
	haz.estado_materia = "plasma"
	var dh: Dictionary = FuegoToy.describir(haz, casilla)
	_ok("un haz (ᛁ línea) → figura HAZ, largo = alcance del haz (x %.2f m), radio = HAZ_ANCHO / 2 (z %.2f m)" % [dh["x"], dh["z"]], dh["figura"] == F.HAZ and _cerca(float(dh["x"]), haz.alcance_haz * casilla * 0.5, 0.01) and _cerca(float(dh["z"]), Hechizo.HAZ_ANCHO * casilla * 0.5, 0.01) and not dh["viaja"])
	var hz: FuegoToy = FuegoToy.new()
	hz.desde_hechizo(haz)
	_raiz.add_child(hz)
	await process_frame
	var bh: AABB = _aabb(hz, "Exterior")
	_ok("HAZ desde_hechizo: tubo de %.2f m de largo y %.2f de diámetro (AABB %s)" % [hz.semieje_x * 2.0, hz.semieje_z * 2.0, str(bh.size)], _cerca(bh.size.y, hz.semieje_x * 2.0, 0.02) and _cerca(bh.size.x, hz.semieje_z * 2.0, 0.02))
	hz.queue_free()
	await process_frame
	# preparar con el volumen de un hechizo (casillas) no escala el nodo: rehace la geometría en metros
	var pr: FuegoToy = _ft(F.MURO, 1.0, 1.0, 1.0)
	await process_frame
	pr.preparar({"x": 1.5, "y": 0.652, "z": 0.13}, Vector3.ZERO, "fuego")
	await process_frame
	_ok("preparar({x: 1,5 casillas}) → semieje_x 3,45 m y escala 1", _cerca(pr.semieje_x, 3.45, 0.01) and pr.scale == Vector3.ONE)
	pr.queue_free()
	await process_frame
	# 7. las cinco modificaciones de Pablo siguen funcionando en FuegoToy
	print("== las cinco modificaciones en FuegoToy")
	var pil: FuegoToy = _ft(F.PILAR, 0.5, 4.0, 0.5)
	await process_frame
	pil.set("tono", 1.0)
	pil.set("altura", 2.0)
	pil.set("chispas", 0.5)
	var mm: ShaderMaterial = _primer_material(pil, "llama_toy.gdshader")
	_ok("(1) fuego azul: tono 1", mm != null and float(mm.get_shader_parameter("tono")) == 1.0)
	_ok("(2) llama el doble de alta: altura 2", mm != null and float(mm.get_shader_parameter("altura")) == 2.0)
	_ok("(3) mitad de chispas: chispas 0,5", (pil.find_child("Chispas", true, false) as GPUParticles3D).amount_ratio == 0.5)
	pil.call("lanzar", 1.0)
	var t0: int = Time.get_ticks_msec()
	while is_instance_valid(pil) and float(Time.get_ticks_msec() - t0) < 3000.0:
		await process_frame
	var tt: float = float(Time.get_ticks_msec() - t0) / 1000.0
	_ok("(5) pilar que dura 1 s y se apaga: lanzar(1.0) lo libera a los %.2f s" % tt, not is_instance_valid(pil) and tt < 1.9)
	var bar: FuegoToy = _ft(F.BARRERA, 1.5, 1.5, 1.5)
	await process_frame
	bar.scale = Vector3(2, 2, 2)
	_ok("(4) barrera el doble de grande: escala 2 del raíz, o semiejes 3", bar.scale == Vector3(2, 2, 2))
	bar.definir(F.BARRERA, 3.0, 3.0, 3.0)
	await process_frame
	_ok("(4) ... o semiejes 3: malla de 6 m", _cerca(_aabb(bar, "Cascara").size.x, 6.0, 0.1))
	bar.queue_free()
	# proyectil: la bola en vuelo emite cola y jirones, la estática no
	var bv1: FuegoToy = _ft(F.BOLA, 0.4, 0.4, 0.4, true)
	var be: FuegoToy = _ft(F.BOLA, 0.4, 0.4, 0.4, false)
	await process_frame
	await process_frame
	var jv: GPUParticles3D = bv1.find_child("Jirones", true, false) as GPUParticles3D
	var je: GPUParticles3D = be.find_child("Jirones", true, false) as GPUParticles3D
	_ok("bola viaja: Jirones y ChispasEstela emiten; estática: no", jv != null and je != null and jv.emitting and not je.emitting and (bv1.find_child("ChispasEstela", true, false) as GPUParticles3D).emitting)
	_ok("bola viaja: destello de 4 puntas visible; estática: oculto", (bv1.find_child("Estrella", true, false) as Node3D).visible and not (be.find_child("Estrella", true, false) as Node3D).visible)
	bv1.queue_free()
	be.queue_free()
	await process_frame
	# 8. presupuesto en los extremos: ≤ 1 luz y ≤ 300 partículas
	var ext: Array = [[F.BOLA, 3.0, 2.0, 3.0, true], [F.BOLA, 0.1, 0.1, 0.1, false], [F.MURO, 6.9, 2.0, 0.5, false], [F.MURO, 8.0, 4.6, 3.0, false], [F.PILAR, 3.0, 4.6, 3.0, false],
		[F.PILAR, 0.1, 6.0, 0.1, false], [F.BARRERA, 6.9, 4.6, 6.9, false], [F.BARRERA, 0.3, 0.3, 0.3, false]]
	for c in ext:
		var e: FuegoToy = _ft(c[0], c[1], c[2], c[3], c[4])
		await process_frame
		var luces: int = 0
		var part: int = 0
		for n in e.find_children("*", "", true, false):
			if n is Light3D:
				luces += 1
			elif n is GPUParticles3D:
				part += (n as GPUParticles3D).amount
		_ok("presupuesto %s %.1f·%.1f·%.1f%s: %d luz y %d partículas" % [["bola", "muro", "pilar", "barrera"][c[0]], c[1], c[2], c[3], " en vuelo" if c[4] else "", luces, part], luces <= MAX_LUCES and part <= MAX_PARTICULAS)
		e.queue_free()
		await process_frame
	# 9. el lab tiene las teclas nuevas
	var lab_cod: String = (load("res://laboratorios/lab_vfx_comparativa_3d.gd") as GDScript).source_code
	for k in ["KEY_F7", "KEY_F8", "KEY_F9", "KEY_U", "KEY_J", "KEY_I", "KEY_K", "KEY_O", "KEY_L", "KEY_V"]:
		_ok("lab: tecla " + k, lab_cod.contains(k + ":"))


## Ronda de pulido: pilares gordos llenos (capas intermedias), mínimo de repeticiones en la barrera pequeña y haz (LINEAL).
func _pulido() -> void:
	print("== FuegoToy: pulido (pilar grande, barrera pequeña, haz)")
	var F = FuegoToy.Figura
	var val: Node3D = _cargar("PilarFuegoToy")
	_raiz.add_child(val)
	var p05: FuegoToy = _ft(F.PILAR, 0.5, 4.0, 0.5)
	var p12: FuegoToy = _ft(F.PILAR, 1.2, 4.6, 1.2)
	var p10: FuegoToy = _ft(F.PILAR, 1.0, 1.5, 1.0)
	await process_frame
	_ok("pilar 0,5·4 (el validado) sigue con 2 capas, sin capas añadidas", p05.find_child("Capa0", true, false) == null and p05.find_children("*", "MeshInstance3D", true, false).size() == val.find_children("*", "MeshInstance3D", true, false).size())
	var n12: int = 0
	for n in p12.get_children()[0].get_children():
		if String(n.name).begins_with("Capa"):
			n12 += 1
	_ok("pilar grande 1,2·4,6·1,2: capas intermedias entre exterior y núcleo (%d)" % n12, n12 >= 2)
	_ok("pilar gordo 1·1,5·1 también tiene capas intermedias", p10.find_child("Capa0", true, false) != null)
	for e in [val, p05, p12, p10]:
		e.queue_free()
	await process_frame
	var b05: FuegoToy = _ft(F.BARRERA, 0.5, 0.5, 0.5)
	var b15: FuegoToy = _ft(F.BARRERA, 1.5, 1.5, 1.5)
	var b30: FuegoToy = _ft(F.BARRERA, 3.0, 3.0, 3.0)
	await process_frame
	var r05: Vector2 = _param(b05, "Cascara", "repeticion")
	var r15: Vector2 = _param(b15, "Cascara", "repeticion")
	var r30: Vector2 = _param(b30, "Cascara", "repeticion")
	_ok("barrera r 0,5: al menos 3 repeticiones por vuelta (%s)" % str(r05), r05.x >= 3.0 and r05.y >= 1.0)
	_ok("barrera 1,5 sigue en (3; 1,4) y la de 3 en (6; 2,8): %s y %s" % [str(r15), str(r30)], _cerca(r15.x, 3.0, 0.001) and _cerca(r15.y, 1.4, 0.01) and _cerca(r30.x, 6.0, 0.001) and _cerca(r30.y, 2.8, 0.03))
	for e in [b05, b15, b30]:
		e.queue_free()
	await process_frame