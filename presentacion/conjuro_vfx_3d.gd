class_name ConjuroVfx3D
extends Node3D

## VFX DEL CONJURO (Fase 14.5, T6b, Pipeline). Dibuja lo que el Juego deja como «sustituto» en `Lanzador3D`: la VOLUTA que va del libro a la mano
## y la FORMA que crece en la mano antes del disparo, con el aspecto de cada elemento (fuego, agua, viento, rayo, hielo, tierra, tiempo).
##
## Por qué escucha una señal y no toca el Lanzador: los tiempos (`RETARDO_CONJURO`, `conjuro_escala`) son del Juego y Pablo los afina allí.
## Este nodo solo lee `conjuro_fase(fase, elemento, posicion)` y `tiempos_conjuro(elemento)` (públicos, diario 104) y dibuja
## EN ESOS TIEMPOS, así que cambiar un tiempo no obliga a retocar nada aquí.
##   «runa»    → no dibuja (el destello de la página lo pone el HUD); guarda la posición de la mano (ahí llegará la voluta).
##   «voluta»  → un núcleo con cola de motas viaja del libro (`posicion`) a la mano, en arco, durante `tiempos[1]`.
##   «forma»   → en la mano crece el núcleo del elemento + una luz, durante `tiempos[2]`.
##   «disparo» → un destello breve y se retira lo que quede (el hechizo lo dibuja `Vfx3D`, no este nodo).
##
## Uso (lo hace la maqueta tras `Jugador3D.montar`):   ConjuroVfx3D.conectar(lanzador, mundo)
## Mientras el Juego no ofrezca `conjuro_vfx_propio` (ver diario 107) el Lanzador sigue dibujando además su hilo y su esfera de prueba:
## se ven las dos cosas a la vez, no es un fallo de este nodo.

## Por elemento: color principal, color de las motas, gravedad de las motas (+ sube, − cae), cuántas, a qué velocidad, y la malla del núcleo.
## Los colores principales son los de los `*_rune.tres` (los de `docs/ARTE.md` §1).
const PERFIL: Dictionary = {
	"fuego":  {"color": Color(0.95, 0.33, 0.12), "mota": Color(1.0, 0.82, 0.38), "grav": 1.6,  "n": 26, "vel": 0.35, "nucleo": "esfera"},
	"agua":   {"color": Color(0.16, 0.62, 0.98), "mota": Color(0.70, 0.90, 1.0),  "grav": -2.2, "n": 22, "vel": 0.25, "nucleo": "esfera"},
	"viento": {"color": Color(0.56, 0.83, 0.42), "mota": Color(0.88, 1.0, 0.80),  "grav": 0.0,  "n": 30, "vel": 0.90, "nucleo": "pequeno"},
	"rayo":   {"color": Color(0.95, 0.78, 0.24), "mota": Color(1.0, 0.98, 0.70),  "grav": 0.0,  "n": 14, "vel": 1.10, "nucleo": "chispa"},
	"hielo":  {"color": Color(0.37, 0.81, 0.96), "mota": Color(0.90, 0.98, 1.0),  "grav": -0.6, "n": 18, "vel": 0.20, "nucleo": "cristal"},
	"tierra": {"color": Color(0.78, 0.53, 0.35), "mota": Color(0.55, 0.36, 0.22), "grav": -3.0, "n": 14, "vel": 0.30, "nucleo": "roca"},
	"tiempo": {"color": Color(0.72, 0.58, 0.98), "mota": Color(0.95, 0.88, 1.0),  "grav": 0.2,  "n": 20, "vel": 0.25, "nucleo": "anillo"},
}
const RADIO_VOLUTA: float = 0.09          ## núcleo que viaja (u)
const RADIO_FORMA: float = 0.25           ## núcleo en la mano: el mismo de la bola del Lanzador (RADIO_BOLA)
const ALTO_ARCO: float = 0.25             ## cuánto sube la voluta a mitad de camino (como el hilo del Juego)

var _lanzador: Object = null
var _mano: Vector3 = Vector3.ZERO
var _vivos: Array[Node] = []


## Crea el nodo, lo cuelga de `padre` y lo conecta al Lanzador. Devuelve null si no hay señal a la que engancharse.
static func conectar(lanzador: Object, padre: Node) -> ConjuroVfx3D:
	if lanzador == null or not lanzador.has_signal("conjuro_fase") or padre == null:
		return null
	var c := ConjuroVfx3D.new()
	c.name = "ConjuroVfx3D"
	padre.add_child(c)
	c._lanzador = lanzador
	lanzador.connect("conjuro_fase", Callable(c, "_al_fase"))
	return c


func _al_fase(fase: String, elemento: String, posicion: Vector3) -> void:
	var t: Array = [0.1, 0.25, 0.1]
	if _lanzador != null and _lanzador.has_method("tiempos_conjuro"):
		t = _lanzador.call("tiempos_conjuro", elemento)
	match fase:
		"runa":
			_mano = posicion
		"voluta":
			voluta(elemento, posicion, _mano, float(t[1]))
		"forma":
			_mano = posicion
			forma(elemento, posicion, float(t[2]))
		"disparo":
			destello(elemento, posicion)
			limpiar()


## La voluta: núcleo con cola que va de `desde` a `hasta` en `dura` s por un arco. Se retira sola al llegar.
func voluta(elemento: String, desde: Vector3, hasta: Vector3, dura: float) -> Node3D:
	var p: Dictionary = _perfil(elemento)
	var cab := Node3D.new()
	add_child(cab)
	cab.global_position = desde
	_vivos.append(cab)
	var nucleo: MeshInstance3D = _nucleo(p, RADIO_VOLUTA)
	cab.add_child(nucleo)
	cab.add_child(_motas(p, 0.5))
	var medio: Vector3 = (desde + hasta) * 0.5 + Vector3(0.0, ALTO_ARCO, 0.0)
	dura = maxf(dura, 0.05)
	var tw := cab.create_tween()
	tw.tween_method(func(k: float) -> void:
		# Bézier cuadrática: el mismo arco que el hilo del Juego, con un balanceo lateral que da vida a la voluta.
		var a: Vector3 = desde.lerp(medio, k)
		var b: Vector3 = medio.lerp(hasta, k)
		var q: Vector3 = a.lerp(b, k)
		var lado: Vector3 = (hasta - desde).cross(Vector3.UP).normalized()
		cab.global_position = q + lado * sin(k * TAU * 2.0) * 0.05 * (1.0 - k), 0.0, 1.0, dura)
	tw.tween_callback(func() -> void:
		var gp := cab.get_node_or_null("Motas") as GPUParticles3D
		if gp != null:
			gp.emitting = false      # deja de emitir pero las motas ya soltadas acaban su vida
		nucleo.visible = false)
	tw.tween_interval(0.8)
	tw.tween_callback(cab.queue_free)
	return cab


## La forma en la mano: el núcleo del elemento crece de 0,2 a 1 en `dura` s (rebote al final) con una luz del color del elemento.
func forma(elemento: String, pos: Vector3, dura: float) -> Node3D:
	var p: Dictionary = _perfil(elemento)
	var raiz := Node3D.new()
	add_child(raiz)
	raiz.global_position = pos
	_vivos.append(raiz)
	var nucleo: MeshInstance3D = _nucleo(p, RADIO_FORMA)
	raiz.add_child(nucleo)
	nucleo.scale = Vector3.ONE * 0.2
	raiz.add_child(_motas(p, 0.8))
	var luz := OmniLight3D.new()
	luz.light_color = p["color"]
	luz.omni_range = 2.2
	luz.light_energy = 0.0
	luz.shadow_enabled = false
	raiz.add_child(luz)
	dura = maxf(dura, 0.05)
	var tw := raiz.create_tween().set_parallel(true)
	tw.tween_property(nucleo, "scale", Vector3.ONE, dura).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(luz, "light_energy", 1.4, dura)
	if nucleo.has_meta("gira"):
		tw.tween_property(nucleo, "rotation:y", TAU, dura + 0.3)
	return raiz


## Destello del disparo: un anillo de luz que crece y se apaga en 0,2 s.
func destello(elemento: String, pos: Vector3) -> void:
	var p: Dictionary = _perfil(elemento)
	var m := MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = RADIO_FORMA
	esf.height = RADIO_FORMA * 2.0
	m.mesh = esf
	var mat := _material(Color(p["color"]).lerp(Color.WHITE, 0.5), 3.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.global_position = pos
	var tw := m.create_tween().set_parallel(true)
	tw.tween_property(m, "scale", Vector3.ONE * 2.2, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.2)
	tw.chain().tween_callback(m.queue_free)


## Retira lo que quede del conjuro (la forma en la mano). La cola de la voluta se apaga sola.
func limpiar() -> void:
	for n in _vivos:
		if is_instance_valid(n):
			n.queue_free()
	_vivos.clear()


func _perfil(elemento: String) -> Dictionary:
	return PERFIL.get(elemento, PERFIL["fuego"])


func _material(color: Color, energia: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energia
	return m


## El núcleo según el elemento: esfera (fuego, agua), punto pequeño (viento), chispa alargada (rayo), cristal (hielo), roca (tierra), anillo (tiempo).
func _nucleo(p: Dictionary, radio: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var color: Color = p["color"]
	match String(p["nucleo"]):
		"pequeno":
			var s := SphereMesh.new(); s.radius = radio * 0.6; s.height = radio * 1.2; m.mesh = s
		"chispa":
			var c := CylinderMesh.new(); c.top_radius = 0.0; c.bottom_radius = radio * 0.5; c.height = radio * 1.8; c.radial_segments = 5
			m.mesh = c; m.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		"cristal":
			var c := CylinderMesh.new(); c.top_radius = 0.0; c.bottom_radius = radio * 0.8; c.height = radio * 2.2; c.radial_segments = 6
			m.mesh = c; m.set_meta("gira", true)
		"roca":
			var s := SphereMesh.new(); s.radius = radio; s.height = radio * 2.0; s.radial_segments = 6; s.rings = 3; m.mesh = s
			m.set_meta("gira", true)
		"anillo":
			var t := TorusMesh.new(); t.inner_radius = radio * 0.65; t.outer_radius = radio; m.mesh = t
			m.rotation_degrees = Vector3(70.0, 0.0, 0.0); m.set_meta("gira", true)
		_:
			var s := SphereMesh.new(); s.radius = radio; s.height = radio * 2.0; m.mesh = s
	var fuera: StandardMaterial3D = _material(Color(color, 0.72), 2.2)
	fuera.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA     # translúcido: deja ver el corazón de dentro
	m.material_override = fuera
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Corazón más claro (calor / brillo) y halo blando: sin ellos el núcleo se lee como un disco plano de un solo color.
	var dentro := MeshInstance3D.new()
	dentro.mesh = m.mesh
	dentro.scale = Vector3.ONE * 0.55
	dentro.material_override = _material(color.lerp(Color.WHITE, 0.75), 3.0)
	dentro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(dentro)
	var halo := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * radio * 5.0
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hm.albedo_texture = VfxKit3D.mancha()
	hm.albedo_color = Color(color, 0.55)
	hm.no_depth_test = false
	q.material = hm
	halo.mesh = q
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(halo)
	return m


## Cola de motas del color del elemento (puntos blandos que se apagan). `escala` = tamaño relativo.
func _motas(p: Dictionary, escala: float) -> GPUParticles3D:
	var gp := GPUParticles3D.new()
	gp.name = "Motas"
	gp.amount = int(p["n"])
	gp.lifetime = 0.45
	gp.local_coords = false          # la cola se queda atrás cuando el núcleo se mueve
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gp.visibility_aabb = AABB(Vector3(-4, -3, -4), Vector3(8, 6, 8))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = float(p["vel"]) * 0.4
	pm.initial_velocity_max = float(p["vel"])
	pm.gravity = Vector3(0.0, float(p["grav"]), 0.0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.06
	pm.scale_min = 0.5 * escala
	pm.scale_max = 1.0 * escala
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var mota: Color = p["mota"]
	var col: Color = p["color"]
	g.colors = PackedColorArray([Color(mota, 1.0), Color(col, 0.8), Color(col, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	gp.process_material = pm
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	sm.albedo_texture = VfxKit3D.mancha()
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	q.material = sm
	gp.draw_pass_1 = q
	gp.emitting = true
	return gp
