class_name HazGasJuego
extends Node

## EL HAZ DE GAS TOON EN EL JUEGO (9/11/2026; Pablo: «¿cómo podemos implementarlo en cualquier situación, es decir cuando choque con un sólido?»). El dibujo del haz de fuego
## (ᚲ + ᛁ…) y del chorro del dragón con la SIMULACIÓN de gas del port de la demo (laboratorios/haz_gas/, HazGas en modo_juego + toon) contra los sólidos REALES del nivel.
## «La lógica decide, el VFX representa»: este nodo solo DIBUJA lo que HechizoVivo ya ha calculado (desde, hasta, largo, choques) y no toca daño, alcance ni ticks.
##
## CAMPO DE SÓLIDOS (`primitivas`): en coordenadas del dominio, la lista de primitivas que solido.glsl convierte en distancia con signo:
##   · las CASILLAS del nivel que caen en el dominio (la misma regla que la lógica, Terreno3D): bloqueadas (muros, rocas, árboles, hielo gordo, fuera del mapa) = caja de toda la
##     altura; con altura (cornisas, escalones, tierra apilada) = caja hasta y_pies(c). El suelo de la casilla de la mano es el suelo del dominio (cerrado).
##   · lo DINÁMICO: enemigos (grupo «combate3d»: su CapsuleShape3D) como cápsulas, bloques empujables (grupo «empujable»: su BoxShape3D) como cajas, y el TOPE de la lógica que la
##     rejilla no explica (una barrera ᛜ) como una caja fina en el punto del choque. Lo dinámico se vuelve a mirar cada fotograma y, si algo se ha movido, se rehace el campo.
## DOMINIO: HazGas.derivar_haz con la entrada del Hechizo real (largo = alcance, ancho y eje de FuegoToy.describir / la altura real de la mano) y el obstáculo «campo» a la
## distancia del primer TOPE (o «nada» si el haz acaba al aire). Caja orientada al haz, desde la mano hasta pasado el tope con margen para la masa y el humo.
## MOVIMIENTO: el haz de la lógica es FIJO desde que se lanza (origen y dirección de ese instante: no sigue a la jugadora mientras dura, ~0,9 s), así que el dominio tampoco se mueve:
## dibujo y daño coinciden. Un haz NUEVO que sale casi del mismo sitio y en la misma dirección (el dragón cada 0,8 s, o la jugadora quieta repitiendo) REUTILIZA el dominio vivo:
## la masa sigue y no parpadea. Si no coincide, nace otro dominio y el viejo se apaga solo.
## TOPE: MAX_INSTANCIAS a la vez; si se llega, `haz` devuelve null y quien llama dibuja el FuegoToy de siempre.

const AJUSTE: String = "magic_symbols/vfx_haz_gas"
## 10/11: el haz de AGUA (AguaToy HAZ) con el mismo gas en MODO AGUA (HazGas.PARAMS_AGUA: sin combustión, con peso; dibujo con los tonos del AguaToy). Ajuste aparte.
## El tope MAX_INSTANCIAS es de los dos elementos JUNTOS.
const AJUSTE_AGUA: String = "magic_symbols/vfx_haz_gas_agua"
const AGUA_DEFECTO: bool = true
## 11/11: los haces de VIENTO y de RAYO con el mismo gas (HazGas.PARAMS_VIENTO: bruma en hélice y polvo; HazGas.PARAMS_RAYO: aire cargado + trazo y arcos). Cada uno con
## su ajuste, APAGADOS de serie hasta que Pablo los vea. El tope MAX_INSTANCIAS es de todos los elementos juntos.
const AJUSTE_VIENTO: String = "magic_symbols/vfx_haz_gas_viento"
const AJUSTE_RAYO: String = "magic_symbols/vfx_haz_gas_rayo"
const AJUSTES_ELEMENTO: Dictionary = {"viento": [AJUSTE_VIENTO, false], "rayo": [AJUSTE_RAYO, false]}
const MAX_INSTANCIAS: int = 2
const APAGADO_S: float = 2.5                   ## s que la masa tarda en deshacerse tras el último haz (se libera después)
const REUSO_DIST_CAS: float = 0.35             ## casillas: un haz nuevo reutiliza el dominio si sale a menos de esto del anterior...
const REUSO_ANG_DEG: float = 10.0              ## ...y apunta a menos de estos grados...
const REUSO_TOPE_CAS: float = 0.5              ## ...y su tope está a menos de esto
const ALTO_BLOQUEADA_CAS: float = 1.5          ## altura (casillas) de la caja de una casilla bloqueada (la lógica la toma como sólida a todas las alturas)

var creados: int = 0
var reusados: int = 0
var rechazados: int = 0
var _mundo: Node3D = null
var _gases: Array = []                         ## [{g: HazGas, desde: Vector3, dir: Vector3, d_tope: float, fin_haz: int ms, fin_todo: int ms, est: PackedFloat32Array, firma: int, tope: Dictionary}]
var _cam: Camera3D = null
var _comp_previo: Compositor = null
var _comp: Compositor = null
var _n_efectos: int = -1


## ¿Se puede usar? Ajuste `magic_symbols/vfx_haz_gas` (fuego, true por defecto) o `magic_symbols/vfx_haz_gas_agua` (agua, AGUA_DEFECTO), y un RenderingDevice
## (Forward+ / Mobile; no Compatibility ni --headless).
static func disponible(elemento: String = "fuego") -> bool:
	if AJUSTES_ELEMENTO.has(elemento):
		if not bool(ProjectSettings.get_setting(AJUSTES_ELEMENTO[elemento][0], AJUSTES_ELEMENTO[elemento][1])):
			return false
	elif elemento == "agua":
		if not bool(ProjectSettings.get_setting(AJUSTE_AGUA, AGUA_DEFECTO)):
			return false
	elif not bool(ProjectSettings.get_setting(AJUSTE, true)):
		return false
	if RenderingServer.get_rendering_device() == null:
		return false
	return String(ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus")) != "gl_compatibility"


static var _precompilado: bool = false


static func conectar(mundo: Node3D) -> HazGasJuego:
	var n := HazGasJuego.new()
	n.name = "HazGasJuego"
	n._mundo = mundo
	mundo.add_child(n)
	if not _precompilado:
		HazGasSolver.precompilar()                  # el primer haz no da tirón: los shaders se compilan al cargar el nivel
		_precompilado = true
	return n


func vivos() -> int:
	return _gases.size()


func gases() -> Array:
	return _gases.map(func(e: Dictionary) -> HazGas: return e["g"])


## Dibuja un haz con gas. Devuelve el HazGas (nuevo o reutilizado) o null si no puede (tope de instancias): entonces se dibuja el toy de siempre (FuegoToy / AguaToy).
## `elemento`: «fuego» o «agua» (HazGas en modo agua). Un dominio vivo solo se reutiliza para un haz del MISMO elemento.
func haz(h: Hechizo, hz: Dictionary, suelo: float, vida: float, elemento: String = "fuego") -> HazGas:
	var desde: Vector3 = hz["desde"] as Vector3
	var hasta: Vector3 = hz["hasta"] as Vector3
	var dir: Vector3 = Vector3(hasta.x - desde.x, 0.0, hasta.z - desde.z)
	if dir.length() < 0.01:
		return null
	dir = dir.normalized()
	var tope: Dictionary = tope_de(hz, desde, dir)
	var d_tope: float = float(tope.get("d", -1.0))
	var ahora: int = Time.get_ticks_msec()
	var cas: float = Terreno3D.casilla
	for e in _gases:
		var g0: HazGas = e["g"]
		if not is_instance_valid(g0) or String(e.get("elemento", "fuego")) != elemento:
			continue
		if (e["desde"] as Vector3).distance_to(desde) < REUSO_DIST_CAS * cas and rad_to_deg((e["dir"] as Vector3).angle_to(dir)) < REUSO_ANG_DEG \
				and absf(float(e["d_tope"]) - d_tope) < REUSO_TOPE_CAS * cas:
			e["fin_haz"] = ahora + int(maxf(vida, 0.3) * 1000.0)
			e["fin_todo"] = int(e["fin_haz"]) + int(APAGADO_S * 1000.0)
			g0.chorro(true)
			reusados += 1
			return g0
	if _gases.size() >= MAX_INSTANCIAS:
		rechazados += 1
		return null
	var g := HazGas.new()
	g.name = "HazGas%d" % creados
	g.modo_juego = true
	g.toon = true
	g.elemento = elemento
	g.haz_cfg = cfg_de(h, hz, suelo, tope)
	_mundo.add_child(g)                              # _ready: configurar_haz (dominio, rejilla, solver)
	if not g.listo():
		g.queue_free()
		rechazados += 1
		return null
	g.colocar(desde, dir, suelo)
	var e2: Dictionary = {"g": g, "desde": desde, "dir": dir, "d_tope": d_tope, "fin_haz": ahora + int(maxf(vida, 0.3) * 1000.0), "tope": tope, "suelo": suelo, "elemento": elemento}
	e2["fin_todo"] = int(e2["fin_haz"]) + int(APAGADO_S * 1000.0)
	e2["est"] = primitivas_estaticas(g, tope, dir, suelo)
	e2["firma"] = -1
	_gases.append(e2)
	_actualizar_dinamicas(e2, true)
	creados += 1
	return g


## El primer tope de la lógica (choques tipo «muro»: casilla sólida o barrera): {d (m a lo largo, en el plano), punto, normal}. Vacío si el haz acaba al aire.
static func tope_de(hz: Dictionary, desde: Vector3, dir: Vector3) -> Dictionary:
	for ch in (hz.get("choques", []) as Array):
		if String((ch as Dictionary).get("tipo", "")) == "muro":
			var p: Vector3 = (ch as Dictionary)["punto"]
			return {"d": Vector3(p.x - desde.x, 0.0, p.z - desde.z).dot(dir), "punto": p, "normal": (ch as Dictionary)["normal"]}
	return {}


## La entrada de HazGas.derivar_haz desde el Hechizo real y lo que dice la lógica.
static func cfg_de(h: Hechizo, hz: Dictionary, suelo: float, tope: Dictionary) -> Dictionary:
	var cas: float = Terreno3D.casilla
	var desde: Vector3 = hz["desde"] as Vector3
	var d: Dictionary = FuegoToy.describir(h, cas) if h != null else {"x": float(hz.get("largo", 3.0)) * 0.5, "z": Hechizo.HAZ_ANCHO * cas * 0.5}
	var alcance: float = maxf(float(d["x"]) * 2.0, float(hz.get("largo", 0.0)))
	var c: Dictionary = {"largo": maxf(alcance, 0.5), "ancho": float(d["z"]), "alto": maxf(desde.y - suelo, 0.2), "juego": true, "tam": cas * 0.5}
	if tope.is_empty():
		c["obstaculo"] = "nada"
		c["dist"] = alcance
	else:
		c["obstaculo"] = "campo"
		c["dist"] = maxf(float(tope["d"]), 0.1)
		var p: Vector3 = tope["punto"]
		var dir: Vector3 = Vector3((hz["hasta"] as Vector3).x - desde.x, 0.0, (hz["hasta"] as Vector3).z - desde.z).normalized()
		var cel: Vector2i = Terreno3D.celda_de(p + dir * cas * 0.3)
		var alto: float = ALTO_BLOQUEADA_CAS * cas
		if Terreno3D.en_mapa(cel) and Terreno3D.altura_en(cel) > 0 and not Terreno3D.bloqueada(cel):
			alto = Terreno3D.y_pies(cel) - suelo
		c["alto_solido"] = maxf(alto, 0.3)
	return c


## Las primitivas que no se mueven: casillas del nivel en el dominio y el tope que la rejilla no explica (barrera). En coordenadas del dominio.
static func primitivas_estaticas(g: HazGas, tope: Dictionary, dir: Vector3, suelo: float) -> PackedFloat32Array:
	var r: PackedFloat32Array = PackedFloat32Array()
	var cas: float = Terreno3D.casilla
	var xf: Transform3D = g.global_transform
	var inv: Transform3D = xf.affine_inverse()
	var lo: Vector3 = g.mundo_lo
	var hi: Vector3 = g.mundo_lo + g.mundo_tam
	var mn: Vector3 = Vector3(INF, INF, INF)
	var mx: Vector3 = -mn
	for i in 8:
		var q: Vector3 = xf * Vector3(lo.x if i & 1 == 0 else hi.x, lo.y if i & 2 == 0 else hi.y, lo.z if i & 4 == 0 else hi.z)
		mn = mn.min(q)
		mx = mx.max(q)
	var c0: Vector2i = Terreno3D.celda_de(mn)
	var c1: Vector2i = Terreno3D.celda_de(mx)
	var alto_b: float = ALTO_BLOQUEADA_CAS * cas
	for cz in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var c: Vector2i = Vector2i(cx, cz)
			var y1: float
			if not Terreno3D.en_mapa(c) or Terreno3D.bloqueada(c) or Terreno3D.cubre_hielo(c):
				y1 = suelo + alto_b
			else:
				y1 = Terreno3D.y_pies(c)
				if y1 <= suelo + 0.05:
					continue                           # a ras (o más bajo: agua, foso): el suelo del dominio ya está cerrado
			var y0: float = suelo - cas
			var cen: Vector3 = Vector3((cx + 0.5) * cas, (y0 + y1) * 0.5, (cz + 0.5) * cas)
			_caja(r, inv, cen, Vector3(cas * 0.5, (y1 - y0) * 0.5, cas * 0.5), Vector3.RIGHT, Vector3.BACK)
	if not tope.is_empty():
		var p: Vector3 = tope["punto"]
		var cel: Vector2i = Terreno3D.celda_de(p + dir * cas * 0.3)
		if Terreno3D.en_mapa(cel) and not Terreno3D.celda_solida(cel, 0):
			# el haz se paró contra algo que no es una casilla (una barrera ᛜ): una pared fina en el punto del choque
			var perp: Vector3 = dir.cross(Vector3.UP).normalized()
			_caja(r, inv, Vector3(p.x, suelo + 0.6 * cas * 0.5, p.z) + dir * cas * 0.1, Vector3(cas * 0.1, 0.6 * cas * 0.5 + cas * 0.5, cas * 0.6), dir, perp)
	return r


## Lo que se mueve: enemigos (cápsulas) y bloques empujables (cajas) dentro del dominio.
static func primitivas_dinamicas(g: HazGas, mundo: Node) -> PackedFloat32Array:
	var r: PackedFloat32Array = PackedFloat32Array()
	if mundo == null or not mundo.is_inside_tree():
		return r
	var inv: Transform3D = g.global_transform.affine_inverse()
	var lo: Vector3 = g.mundo_lo - Vector3.ONE
	var hi: Vector3 = g.mundo_lo + g.mundo_tam + Vector3.ONE
	for n in mundo.get_tree().get_nodes_in_group("combate3d"):
		if not (n is Node3D) or not (n as Node3D).is_inside_tree():
			continue
		var radio: float = Combate3D.RADIO_CUERPO_ENEMIGO
		var alto: float = 1.0
		var centro: Vector3 = (n as Node3D).global_position + Vector3(0, 0.5, 0)
		var col: Variant = n.get("_col")
		if col is CollisionShape3D and is_instance_valid(col) and (col as CollisionShape3D).shape is CapsuleShape3D:
			var cs: CapsuleShape3D = (col as CollisionShape3D).shape as CapsuleShape3D
			radio = cs.radius * (col as Node3D).global_basis.get_scale().x
			alto = cs.height * (col as Node3D).global_basis.get_scale().y
			centro = (col as Node3D).global_position
		var cd: Vector3 = inv * centro
		if cd.x < lo.x or cd.x > hi.x or cd.z < lo.z or cd.z > hi.z:
			continue
		var media: float = maxf(alto * 0.5 - radio, 0.0)
		var a: Vector3 = inv * (centro - Vector3(0, media, 0))
		var b: Vector3 = inv * (centro + Vector3(0, media, 0))
		r.append_array([a.x, a.y, a.z, 1.0, b.x, b.y, b.z, radio / g.metros_por_unidad, 0, 0, 0, 0])
	for n in mundo.get_tree().get_nodes_in_group("empujable"):
		if not (n is Node3D):
			continue
		var caja: CollisionShape3D = null
		for k in (n as Node).find_children("*", "CollisionShape3D", true, false):
			if (k as CollisionShape3D).shape is BoxShape3D:
				caja = k
				break
		var cen: Vector3 = (n as Node3D).global_position + Vector3(0, Terreno3D.casilla * 0.25, 0)
		var semi: Vector3 = Vector3.ONE * Terreno3D.casilla * 0.25
		var bas: Basis = (n as Node3D).global_basis.orthonormalized()
		if caja != null:
			cen = caja.global_position
			semi = (caja.shape as BoxShape3D).size * 0.5 * caja.global_basis.get_scale()
			bas = caja.global_basis.orthonormalized()
		var cd2: Vector3 = inv * cen
		if cd2.x < lo.x or cd2.x > hi.x or cd2.z < lo.z or cd2.z > hi.z:
			continue
		_caja(r, inv, cen, semi, bas.x, bas.z)
	return r


## Una caja de mundo (centro, semiejes en sus ejes ex / ez horizontales) en coordenadas del dominio: 12 floats (ver solido.glsl).
static func _caja(r: PackedFloat32Array, inv: Transform3D, cen: Vector3, semi: Vector3, ex: Vector3, ez: Vector3) -> void:
	var s: float = 1.0 / inv.basis.get_scale().x                # metros por unidad (escala uniforme)
	var c: Vector3 = inv * cen
	var exd: Vector3 = (inv.basis * Vector3(ex.x, 0.0, ex.z)).normalized()
	var ezd: Vector3 = (inv.basis * Vector3(ez.x, 0.0, ez.z)).normalized()
	r.append_array([c.x, c.y, c.z, 0.0, semi.x / s, semi.y / s, semi.z / s, 0.0, exd.x, exd.z, ezd.x, ezd.z])


func _actualizar_dinamicas(e: Dictionary, forzar: bool) -> void:
	var g: HazGas = e["g"]
	var din: PackedFloat32Array = primitivas_dinamicas(g, _mundo)
	var firma: int = 0
	for i in din.size():
		firma = (firma * 31 + int(round(din[i] * 20.0))) & 0x7FFFFFFF
	if not forzar and firma == int(e["firma"]):
		return
	e["firma"] = firma
	var todo: PackedFloat32Array = (e["est"] as PackedFloat32Array).duplicate()
	todo.append_array(din)
	g.prims_dom = todo
	g.rehacer_solido()


func _process(_delta: float) -> void:
	var ahora: int = Time.get_ticks_msec()
	var quedan: Array = []
	for e in _gases:
		var g: HazGas = e["g"]
		if not is_instance_valid(g):
			continue
		if ahora >= int(e["fin_todo"]):
			g.queue_free()
			continue
		if ahora >= int(e["fin_haz"]) and float(g.params["beamOn"]) > 0.5:
			g.chorro(false)
		_actualizar_dinamicas(e, false)
		quedan.append(e)
	_gases = quedan
	_poner_compositor()


## Los efectos de raymarch de los gases vivos en la cámara actual (un solo Compositor; los efectos que ya tuviera la cámara se conservan detrás).
func _poner_compositor() -> void:
	var vp: Viewport = get_viewport()
	var cam: Camera3D = vp.get_camera_3d() if vp != null else null
	var efectos: Array[CompositorEffect] = []
	for e in _gases:
		var g: HazGas = e["g"]
		if is_instance_valid(g) and g.efecto != null:
			efectos.append(g.efecto)
	if cam != _cam:
		_soltar_camara()
		_cam = cam
		_comp_previo = cam.compositor if cam != null else null
		_n_efectos = -1
	if _cam == null or not is_instance_valid(_cam):
		return
	if efectos.size() == _n_efectos and _cam.compositor == _comp:
		return
	_n_efectos = efectos.size()
	if efectos.is_empty():
		_cam.compositor = _comp_previo
		return
	_comp = Compositor.new()
	var todos: Array[CompositorEffect] = efectos.duplicate()
	if _comp_previo != null:
		todos.append_array(_comp_previo.compositor_effects)
	_comp.compositor_effects = todos
	_cam.compositor = _comp


func _soltar_camara() -> void:
	if _cam != null and is_instance_valid(_cam) and _cam.compositor == _comp:
		_cam.compositor = _comp_previo
	_cam = null


func _exit_tree() -> void:
	_soltar_camara()


## El AguaToy HAZ que acompaña al gas de agua: no tiene luz propia, así que no se ve nada de él (el chorro, la lámina, el abanico y las gotas los dibuja el gas).
## Sigue vivo (su vida y su «morir» de siempre) para que VfxToyJuego lo cuente y lo retire igual que sin gas.
static func ocultar_toy(t: Node3D) -> void:
	t.visible = false


## El RayoToy HAZ que acompaña al gas de rayo: se queda con sus luces (el destello); el trazo, los arcos y las chispas los dibuja el gas.
static func solo_luces(t: Node3D) -> void:
	for n in t.find_children("*", "", true, false):
		if n is GeometryInstance3D:
			(n as GeometryInstance3D).visible = false


## El FuegoToy HAZ que acompaña al gas: se queda SOLO con su luz (la mancha del suelo, `luz_suelo_haz`, y su OmniLight «Luz», con su vida y su latido de siempre);
## el chorro, las láminas, la salpicadura y las chispas de las láminas los dibuja el gas.
static func solo_luz(t: Node3D) -> void:
	for n in t.find_children("*", "", true, false):
		if n is GPUParticles3D:
			(n as GPUParticles3D).emitting = false
			(n as GPUParticles3D).visible = false
		elif n is GeometryInstance3D and not (n as Node).is_in_group(FuegoToy.HAZ_GRUPO_LUZ_SUELO):
			(n as GeometryInstance3D).visible = false
