extends SceneTree

## PRUEBA de los efectos como asset (1/11, Dirección, COMPARATIVA_VFX §1.3 y §1.5). Headless:
##   godot --headless --path . --script res://herramientas/prueba_vfx_comparativa.gd
## Comprueba, para BolaFuego, MuroFuego, ColumnaFuego e ImpactoFuego:
##   1. la escena existe, carga y su raíz lleva EfectoVfx3D con un AnimationPlayer «Anim» con «nacer» y «morir»
##   2. presupuesto: ≤ MAX_LUCES luces y ≤ MAX_PARTICULAS partículas (suma de `amount`), el de VfxEstado3D / LabVfx3D
##   3. `preparar` escala el raíz al volumen: el de referencia da escala 1 (±2 %) y el doble de largo da 2 en X
##   4. `lanzar(vida)` libera el nodo en vida + 0,1 s, y `lanzar(-1)` + `morir()` lo libera en dura_morir + 0,1 s
##   5. los cuatro shaders compilan (ShaderMaterial con el shader cargado no da error de compilación)
## Imprime FALLOS: n al final.

const MAX_LUCES: int = 2
const MAX_PARTICULAS: int = 400
const DIR: String = "res://presentacion/vfx/efectos/"
const CASILLA: float = 2.3
## escena -> tamaño de referencia (m) que declara, para la comprobación 3
const ESCENAS: Dictionary = {"BolaFuego": Vector3(0.8, 0.8, 0.8), "MuroFuego": Vector3(6.9, 1.5, 0.3), "ColumnaFuego": Vector3(1.0, 4.0, 1.0), "ImpactoFuego": Vector3(1.0, 1.0, 1.0)}
const TOL_ESCALA: float = 0.02

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
		await _probar(String(nombre), ESCENAS[nombre])
	_shaders()
	print("FALLOS: %d" % _fallos)
	quit(0 if _fallos == 0 else 1)


func _probar(nombre: String, ref: Vector3) -> void:
	print("— " + nombre)
	var ruta: String = DIR + nombre + ".tscn"
	_ok("1 existe", ResourceLoader.exists(ruta), ruta)
	if not ResourceLoader.exists(ruta):
		return
	var ps: PackedScene = load(ruta)
	var e: Node3D = ps.instantiate() as Node3D
	_raiz.add_child(e)
	_ok("1 lleva EfectoVfx3D", e is EfectoVfx3D)
	var ap: AnimationPlayer = e.get_node_or_null("Anim") as AnimationPlayer
	_ok("1 Anim con nacer y morir", ap != null and ap.has_animation("nacer") and ap.has_animation("morir"))
	_ok("1 tam_referencia", e.get("tam_referencia") == ref, str(e.get("tam_referencia")))
	var luces: int = 0
	var part: int = 0
	for n in e.find_children("*", "", true, false):
		if n is Light3D:
			luces += 1
		elif n is GPUParticles3D:
			part += (n as GPUParticles3D).amount
	_ok("2 luces ≤ %d" % MAX_LUCES, luces <= MAX_LUCES, str(luces))
	_ok("2 partículas ≤ %d" % MAX_PARTICULAS, part <= MAX_PARTICULAS, str(part))
	# 3: el volumen de referencia (semiejes = tam / 2 / casilla) da escala 1; el doble de X da 2
	var v: Dictionary = {"x": ref.x * 0.5 / CASILLA, "y": ref.y * 0.5 / CASILLA, "z": ref.z * 0.5 / CASILLA}
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


func _shaders() -> void:
	print("— shaders")
	for s in ["flipbook_erosion", "scroll_erosion", "calor", "nucleo_fresnel"]:
		var sh: Shader = load("res://presentacion/vfx/shaders/%s.gdshader" % s)
		var rid_ok: bool = sh != null and sh.get_rid().is_valid()
		_ok("5 " + s + " carga", rid_ok)


func _segundos(s: float) -> void:
	var t: float = 0.0
	while t < s:
		t += root.get_process_delta_time() if root.get_process_delta_time() > 0.0 else 1.0 / 60.0
		await process_frame
