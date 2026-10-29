class_name LabRecetas3D
extends Node

## LABORATORIO DE RECETAS V2 (R4, 17/10, Juego). Sobre `laboratorios/LabRecetas3D.tscn`; mismo armazón que el de puzles de agua/fuego: la escena es la
## maqueta (PruebaTest2, con el jugador, el Lanzador3D y el agua) y este nodo cuelga de ella como «Reglas», espera un fotograma y llama a `iniciar`.
## Mapa: mundo/datos_nivel/mapas/LabRecetas.txt (sala abierta de 28 × 17: dianas D, tres goblins quietos W/A, setos z y braseros T, dos barriles y
## un estanque ~). Según docs/GLIFOS_RECETA.md §3 F4 sirve para ver una receta y lanzarla, y para barrer combinaciones buscando casos raros.
##
## QUÉ SE VE (todo con la receta que marcan los contadores, antes de lanzar):
##   · el ELIPSOIDE en alambre (tres aros: el de planta, el de frente y el de costado), con sus semiejes en casillas,
##   · las CASILLAS que ocupa (contorno en el suelo; en verde lo ya lanzado, la unión de todas las tandas de la señal `hechizo_v2`),
##   · el COSTE (relativo y en tinta), el NOMBRE DERIVADO (x_mano · alto · abajo), el ESTADO de la materia del elemento y las propiedades.
## TECLAS (la maqueta tiene las suyas; las de este lab se atienden antes y no llegan a ella):
##   Espacio lanza hacia donde mira el jugador (aquí NO salta: Jugador3D.salto_activo = false) · B barrido · Tab siguiente elemento
##   Numpad 1–8 suman un glifo (con Mayús, restan) · Numpad 0 limpia · R recarga · L cámara lenta · . paso a paso · , sigue (TiempoLab3D)
##   y el panel de la derecha hace lo mismo con el ratón (un contador +/− por glifo de Sigils.GLIFOS y el selector de elemento).
##   (Los dígitos 1–3 son del libro, que lanza páginas, y F1–F6 de la maqueta: por eso el teclado numérico.)
## BARRIDO (B): cada PERIODO_BARRIDO s elige una receta al azar (glifos, elemento, casilla de salida y dirección), la lanza y la vigila VENTANA_S s.
##   Anota en PlayLog `receta_rara` si NO HIZO NADA VISIBLE (no salió ninguna casilla, o durante la ventana no apareció ni un nodo nuevo en el árbol:
##   es un indicador, no una prueba) o si LANZARLA tardó más de UMBRAL_MS ms (lo que cuesta `lanzar_receta`, medido con reloj de pared).
##   Además `barrido_inicio` (con la SEMILLA: la misma semilla repite el mismo barrido) y `barrido_fin` (totales). Se lanza con `lanzar_receta`,
##   así que no gasta tinta ni espera recarga.

const NIVEL_MAPA: String = "LabRecetas"
const ELEMENTOS: Array = ["fire", "water", "earth", "ice", "lightning", "wind"]       # 20/10: sin «time» (cinemática, no se lanza)
const NOMBRE_ELEMENTO: Dictionary = {"fire": "fuego", "water": "agua", "earth": "tierra", "ice": "hielo", "lightning": "rayo", "wind": "viento"}
const CASILLAS_APUNTADAS_LAB: float = 3.0     ## casillas por delante de la jugadora a las que «apunta» el laboratorio (no tiene ratón) lo que nace donde apuntas (`en_punto`)
const PERIODO_BARRIDO: float = 2.0
const VENTANA_S: float = 0.8                  ## segundos de juego que se vigila una receta lanzada
const UMBRAL_MS: float = 16.0                 ## un fotograma a 60 fps
const MAX_GLIFOS_BARRIDO: int = 10
const PROB_GLIFO_BARRIDO: float = 0.4
const SEGMENTOS: int = 40
const T_HUD: float = 0.1
const T_LANZADO: float = 3.0                  ## cuánto se queda pintado en verde lo ya lanzado
## Casillas de salida del barrido (todas libres en LabRecetas.txt) y las ocho direcciones.
const SALIDAS: Array = [Vector2i(4, 8), Vector2i(4, 4), Vector2i(4, 12), Vector2i(8, 6), Vector2i(8, 10), Vector2i(12, 8), Vector2i(12, 4), Vector2i(12, 12)]
const COLOR_ALAMBRE: Color = Color(1.0, 0.85, 0.2)
const COLOR_CASILLA: Color = Color(0.3, 0.8, 1.0)
const COLOR_LANZADO: Color = Color(0.4, 1.0, 0.4)

var m: Variant = null                          ## la maqueta (PruebaTest2); sin tipo, como en los otros labs
var _jug: Jugador3D = null
var _l: Lanzador3D = null
var _puzle_nodo: Puzle3D = null
var tiempo: TiempoLab3D = null

var contadores: Dictionary = {}                ## glifo -> veces (solo los > 0)
var elemento: String = "fire"
var ultimo: Dictionary = {}                    ## la última receta lanzada: {glifos, elemento, dir, n, ms, estado, celdas, nodos_pico, motivos}
var raras: Array = []                          ## lo anotado como `receta_rara` en esta sesión (para el HUD y las pruebas)
var lanzadas: int = 0

var barrido: bool = false
var semilla: int = 0
var rondas: int = 0
var rondas_max: int = 0                        ## 0 = sin tope (lo pone la prueba)
var _rng := RandomNumberGenerator.new()
var _t_barrido: float = 0.0
var _obs: Dictionary = {}                      ## la receta que se está vigilando
var _t_hud: float = 0.0
var _firma: String = ""
var _lanzado_celdas: Array = []
var _t_lanzado: float = 0.0

var _marcas: Node3D = null
var _alambre: MeshInstance3D = null
var _casillas: MeshInstance3D = null
var _lanzado: MeshInstance3D = null
var _hud: Label = null
var _panel_cuentas: Dictionary = {}            ## glifo -> Label del contador
var _caja_glifos: Control = null                ## el panel de glifos entero (LabHechizos3D lo esconde con su interfaz compacta)
var _selector: OptionButton = null
var _boton_barrido: Button = null
var _avisos: Array = []


func _ready() -> void:
	call_deferred("_arrancar")


func _arrancar() -> void:
	if get_parent() != null:
		iniciar(get_parent())


## Entrada pública: `mundo` es la maqueta ya montada.
func iniciar(mundo: Variant) -> void:
	m = mundo
	for n in (m as Node).get_children():
		if n is Jugador3D:
			_jug = n
	_l = get_tree().get_first_node_in_group("spellcaster") as Lanzador3D
	if _jug == null or _l == null:
		push_error("LabRecetas3D: la escena necesita el Jugador3D y el Lanzador3D de la maqueta")
		return
	_jug.salto_activo = false
	_l.hechizo_v2.connect(_al_hechizo)
	_puzle_nodo = Puzle3D.new()
	_puzle_nodo.name = "Puzles"
	add_child(_puzle_nodo)
	_puzle_nodo.iniciar(m, nivel_mapa())
	_avisos.append_array(_puzle_nodo.avisos)
	quietar_goblins()
	tiempo = TiempoLab3D.new()
	add_child(tiempo)
	_montar_marcas()
	_montar_panel()
	_montar_hud()
	_refrescar(true)
	set_process(true)


## Nombre del mapa de la sala (mundo/datos_nivel/mapas/<nombre>.txt). LabHechizos3D lo cambia.
func nivel_mapa() -> String:
	return NIVEL_MAPA


## Los goblins del lab son dianas con vida: no ven, no persiguen, no atacan (Combate3D.quieto), pero reciben golpes y empuje.
func quietar_goblins() -> int:
	var n: int = 0
	for c in get_tree().get_nodes_in_group("combate3d"):
		if c is Combate3D:
			(c as Combate3D).quieto = true
			n += 1
	return n


# ---------------------------------------------------------------------------------------------------------------------
#  La receta
# ---------------------------------------------------------------------------------------------------------------------

## Cuántos glifos de este tipo hacen falta para llegar al tope de su propiedad (más no cambia nada). El panel deja uno de más, para ver la saturación.
static func glifos_hasta_tope(nombre: String) -> int:
	return Sigils.glifos_hasta_tope(nombre)


func receta_de(cont: Dictionary) -> Lanzador3D.Receta3D:
	var r := Lanzador3D.Receta3D.new(Vector2.RIGHT)
	for nombre in Sigils.GLIFOS:
		for _i in range(int(cont.get(nombre, 0))):
			r.apply(String(nombre))
	return r


func receta() -> Lanzador3D.Receta3D:
	return receta_de(contadores)


func runa() -> RuneData:
	return load("res://nucleo/%s_rune.tres" % elemento) as RuneData


func sumar(glifo: String, delta: int) -> void:
	if not Sigils.GLIFOS.has(glifo):
		return
	var n: int = clampi(int(contadores.get(glifo, 0)) + delta, 0, glifos_hasta_tope(glifo) + 1)
	if n == 0:
		contadores.erase(glifo)
	else:
		contadores[glifo] = n
	_refrescar(true)


func limpiar() -> void:
	contadores.clear()
	_refrescar(true)


func siguiente_elemento() -> void:
	poner_elemento(ELEMENTOS[(ELEMENTOS.find(elemento) + 1) % ELEMENTOS.size()])


func poner_elemento(e: String) -> void:
	if ELEMENTOS.has(e):
		elemento = e
		if _selector != null:
			_selector.select(ELEMENTOS.find(e))
		_refrescar(true)


## Hacia dónde mira el jugador, en el plano (la dirección con la que lanzaría).
func direccion() -> Vector3:
	var d: Variant = _jug.get("_mirada") if _jug != null else null
	var v: Vector3 = d if d is Vector3 else Vector3.RIGHT
	v.y = 0.0
	return v.normalized() if v.length() > 0.001 else Vector3.RIGHT


## Lanza la receta de los contadores con el elemento elegido, hacia donde mira el jugador. Devuelve la ficha de lo medido (también en `ultimo`).
func lanzar() -> Dictionary:
	return _lanzar(receta(), contadores.duplicate(), elemento, direccion())


## De dónde nace lo que se lanza: de la jugadora, salvo lo que nace donde apuntas (`en_punto`: la barrera y todo sólido quieto, ESPEC §1.2), que el laboratorio, sin ratón,
## pone `CASILLAS_APUNTADAS_LAB` por delante de ella. Sin esto un bloque de tierra nacería en la casilla de la jugadora y `construir_tierra` lo rechazaría («encima del jugador»).
func origen_de(r: Lanzador3D.Receta3D, rune: RuneData, dir: Vector3) -> Vector3:
	var hz: Hechizo = r.hechizo(rune)
	if hz != null and hz.en_punto:
		return _jug.position + dir * Terreno3D.casilla * minf(CASILLAS_APUNTADAS_LAB, Lanzador3D.ALCANCE_ORIGEN)
	return _jug.position


func _lanzar(r: Lanzador3D.Receta3D, cont: Dictionary, elem: String, dir: Vector3) -> Dictionary:
	var rune: RuneData = load("res://nucleo/%s_rune.tres" % elem) as RuneData
	var g: Dictionary = r.geo()
	_jug.mirar_hacia(dir)
	_jug.call("lanzar_clip", Objetos.elemento_de(rune), r.forma_vfx())
	var origen: Vector3 = origen_de(r, rune, dir)
	var nodos0: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_lanzado_celdas = []
	var t0: int = Time.get_ticks_usec()
	var n: int = _l.lanzar_receta(r, rune, origen, dir)
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	lanzadas += 1
	ultimo = {"glifos": cont.duplicate(), "elemento": elem, "dir": dir, "n": n, "ms": ms, "estado": rune.estado,
		"celdas": _lanzado_celdas.size(), "nodos_pico": 0, "motivos": [], "aviso": Lanzador3D.GeometriaV2.aviso_materia(g, rune),
		"nombre": String(g["nombre"]), "coste": r.tamano_relativo()}
	_obs = {"ficha": ultimo, "nodos0": nodos0, "t": 0.0, "ultimo_us": Time.get_ticks_usec(), "frame_max_ms": 0.0}
	return ultimo


func _al_hechizo(_estado: String, _el: String, g: Dictionary, _o: Vector3, _d: Vector3, _p: Dictionary) -> void:
	_lanzado_celdas = (g["celdas"] as Array).duplicate()
	_t_lanzado = T_LANZADO
	_pintar_celdas(_lanzado, _lanzado_celdas, COLOR_LANZADO, 0.09)


## Cierra la vigilancia de la última receta: decide si fue «rara» y la anota.
func _cerrar_observacion() -> void:
	var ficha: Dictionary = _obs["ficha"]
	var motivos: Array = []
	if int(ficha["n"]) <= 0:
		motivos.append("rechazada" if String(ficha["aviso"]) != "" else "sin_casillas")
	elif int(ficha["nodos_pico"]) <= 0:
		motivos.append("sin_efecto_visible")
	if float(ficha["ms"]) > UMBRAL_MS:
		motivos.append("lenta")
	ficha["motivos"] = motivos
	ficha["frame_max_ms"] = snappedf(float(_obs["frame_max_ms"]), 0.1)
	if not motivos.is_empty():
		var dato: Dictionary = {"glifos": ficha["glifos"], "elemento": ficha["elemento"], "estado": ficha["estado"], "nombre": ficha["nombre"],
			"motivos": motivos, "ms": snappedf(float(ficha["ms"]), 0.01), "casillas": ficha["celdas"], "nodos_pico": ficha["nodos_pico"],
			"coste": snappedf(float(ficha["coste"]), 0.01), "semilla": semilla if barrido else 0, "ronda": rondas, "frame_max_ms": ficha["frame_max_ms"]}
		PlayLog.event("receta_rara", dato)
		raras.append(dato)
	_obs = {}


# ---------------------------------------------------------------------------------------------------------------------
#  Barrido
# ---------------------------------------------------------------------------------------------------------------------

func alternar_barrido() -> void:
	if barrido:
		parar_barrido()
	else:
		iniciar_barrido(0, int(Time.get_ticks_msec()) & 0x7fffffff)


## `semilla_nueva` fija el azar (la misma semilla repite el mismo barrido); `max_rondas` 0 = hasta que se pare con B.
func iniciar_barrido(max_rondas: int = 0, semilla_nueva: int = 1) -> void:
	barrido = true
	semilla = semilla_nueva
	_rng.seed = semilla
	rondas = 0
	rondas_max = max_rondas
	_t_barrido = PERIODO_BARRIDO            # la primera, enseguida
	raras.clear()
	PlayLog.event("barrido_inicio", {"semilla": semilla, "periodo": PERIODO_BARRIDO, "umbral_ms": UMBRAL_MS, "max_rondas": max_rondas})
	_actualizar_boton_barrido()


func parar_barrido() -> void:
	if not barrido:
		return
	barrido = false
	PlayLog.event("barrido_fin", {"semilla": semilla, "rondas": rondas, "raras": raras.size()})
	_actualizar_boton_barrido()


## Una receta al azar: cada glifo entra con PROB_GLIFO_BARRIDO y de 1 a su tope + 1 veces (así sale también la saturación), con un máximo de
## MAX_GLIFOS_BARRIDO en total; elemento, casilla de salida y dirección también al azar.
func receta_al_azar() -> Dictionary:
	var cont: Dictionary = {}
	var total: int = 0
	for nombre in Sigils.GLIFOS:
		if _rng.randf() >= PROB_GLIFO_BARRIDO:
			continue
		var n: int = mini(_rng.randi_range(1, glifos_hasta_tope(String(nombre)) + 1), MAX_GLIFOS_BARRIDO - total)
		if n > 0:
			cont[nombre] = n
			total += n
	var ang: float = float(_rng.randi_range(0, 7)) * PI / 4.0
	return {"glifos": cont, "elemento": String(ELEMENTOS[_rng.randi_range(0, ELEMENTOS.size() - 1)]),
		"salida": SALIDAS[_rng.randi_range(0, SALIDAS.size() - 1)], "dir": Vector3(cos(ang), 0.0, sin(ang))}


func _ronda_barrido() -> void:
	var r: Dictionary = receta_al_azar()
	rondas += 1
	colocar_jugador(r["salida"] as Vector2i)
	contadores = (r["glifos"] as Dictionary).duplicate()
	elemento = String(r["elemento"])
	if _selector != null:
		_selector.select(ELEMENTOS.find(elemento))
	_jug.mirar_hacia(r["dir"] as Vector3)
	_refrescar(true)
	_lanzar(receta(), contadores.duplicate(), elemento, r["dir"] as Vector3)


## Teletransporte del jugador a una casilla (lo mismo que hacen los otros labs).
func colocar_jugador(c: Vector2i) -> void:
	if _jug == null:
		return
	var p: Vector3 = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
	if _jug.pj != null:
		_jug.pj.position = p
	_jug.position = p


# ---------------------------------------------------------------------------------------------------------------------
#  Cada fotograma
# ---------------------------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _obs.is_empty():
		var ahora: int = Time.get_ticks_usec()
		_obs["frame_max_ms"] = maxf(float(_obs["frame_max_ms"]), float(ahora - int(_obs["ultimo_us"])) / 1000.0)
		_obs["ultimo_us"] = ahora
		var ficha: Dictionary = _obs["ficha"]
		ficha["nodos_pico"] = maxi(int(ficha["nodos_pico"]), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) - int(_obs["nodos0"]))
		_obs["t"] = float(_obs["t"]) + delta
		if float(_obs["t"]) >= VENTANA_S:
			_cerrar_observacion()
	if barrido and _obs.is_empty():
		_t_barrido += delta
		if _t_barrido >= PERIODO_BARRIDO:
			_t_barrido = 0.0
			_ronda_barrido()
		if rondas_max > 0 and rondas >= rondas_max and _obs.is_empty():
			parar_barrido()
	if _t_lanzado > 0.0:
		_t_lanzado -= delta
		if _t_lanzado <= 0.0:
			_pintar_celdas(_lanzado, [], COLOR_LANZADO, 0.09)
	_refrescar(false)
	_t_hud -= delta
	if _t_hud <= 0.0:
		_t_hud = T_HUD
		_refrescar_hud()


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or m == null:
		return
	var k: InputEventKey = ev as InputEventKey
	if not k.pressed or k.echo:
		return
	var atendida: bool = true
	var numpad: Array = [KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_7, KEY_KP_8]
	var glifos: Array = Sigils.GLIFOS.keys()
	if k.keycode == KEY_SPACE:
		lanzar()
	elif k.keycode == KEY_B:
		alternar_barrido()
	elif k.keycode == KEY_TAB:
		siguiente_elemento()
	elif k.keycode == KEY_KP_0:
		limpiar()
	elif numpad.has(k.keycode) and numpad.find(k.keycode) < glifos.size():
		sumar(String(glifos[numpad.find(k.keycode)]), -1 if k.shift_pressed else 1)
	elif k.keycode == KEY_R:
		get_tree().reload_current_scene()
	else:
		atendida = false
	if atendida:
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------------------------------------------------
#  Lo que se dibuja en el mundo: elipsoide y casillas
# ---------------------------------------------------------------------------------------------------------------------

func _montar_marcas() -> void:
	_marcas = Node3D.new()
	_marcas.name = "MarcasReceta"
	(m as Node).add_child(_marcas)
	_alambre = _malla_lineas()
	_casillas = _malla_lineas()
	_lanzado = _malla_lineas()
	_marcas.add_child(_alambre)
	_marcas.add_child(_casillas)
	_marcas.add_child(_lanzado)


func _malla_lineas() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	mat.render_priority = 10
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Solo repinta cuando algo cambió (casilla del jugador, dirección, contadores o elemento) o si se pide con `forzar`.
func _refrescar(forzar: bool) -> void:
	if _jug == null or _alambre == null:
		return
	var d: Vector3 = direccion()
	var firma: String = "%s|%s|%s|%s|%s" % [Terreno3D.celda_de(_jug.position), snappedf(d.x, 0.01) + snappedf(d.z, 0.01), contadores, elemento, _firma_extra()]
	if not forzar and firma == _firma:
		return
	_firma = firma
	var g: Dictionary = _geo_previa()
	_pintar_elipsoide(g, d)
	var o2 := Vector2(_jug.position.x, _jug.position.z)
	_pintar_celdas(_casillas, Lanzador3D.GeometriaV2.celdas(g, o2, Vector2(d.x, d.z), Terreno3D.casilla), COLOR_CASILLA, 0.04)


## La geometría que se dibuja en la previsualización (alambre y casillas). Aquí, la de la receta; LabHechizos3D la saca del Hechizo con lo tocado en la tabla.
func _geo_previa() -> Dictionary:
	return receta().geo()


## Algo más que haga repintar la previsualización cuando cambie (lo tocado a mano en LabHechizos3D).
func _firma_extra() -> String:
	return ""


## Tres aros del elipsoide: planta (ejes x y z), frente (x y y) y costado (z y y). Centro adelantado como en `GeometriaV2.celdas` y a media altura de los niveles.
func _pintar_elipsoide(g: Dictionary, d: Vector3) -> void:
	var im: ImmediateMesh = _alambre.mesh as ImmediateMesh
	im.clear_surfaces()
	var cas: float = Terreno3D.casilla
	var sx: float = float(g["x"]) * cas
	var sz: float = float(g["z"]) * cas
	var niveles: int = Lanzador3D.GeometriaV2.niveles(g)
	var sy: float = float(niveles) * Terreno3D.ALTO_NIVEL * 0.5
	var celda: Vector2i = Terreno3D.celda_de(_jug.position)
	var pies: float = Terreno3D.y_pies(celda)
	var adelanto: float = Lanzador3D.GeometriaV2.adelanto(g) * cas
	var centro: Vector3 = Vector3(_jug.position.x, pies + sy, _jug.position.z) + d * adelanto
	var perp: Vector3 = Vector3(-d.z, 0.0, d.x)
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_set_color(COLOR_ALAMBRE)
	for aro in range(3):
		for i in range(SEGMENTOS):
			var a0: float = TAU * float(i) / float(SEGMENTOS)
			var a1: float = TAU * float(i + 1) / float(SEGMENTOS)
			im.surface_add_vertex(centro + _punto_aro(aro, a0, perp, d, sx, sy, sz))
			im.surface_add_vertex(centro + _punto_aro(aro, a1, perp, d, sx, sy, sz))
	im.surface_end()


static func _punto_aro(aro: int, a: float, perp: Vector3, d: Vector3, sx: float, sy: float, sz: float) -> Vector3:
	match aro:
		0:
			return perp * (cos(a) * sx) + d * (sin(a) * sz)
		1:
			return perp * (cos(a) * sx) + Vector3.UP * (sin(a) * sy)
	return d * (cos(a) * sz) + Vector3.UP * (sin(a) * sy)


## Contorno en el suelo de cada casilla de la lista.
func _pintar_celdas(malla: MeshInstance3D, celdas: Array, color: Color, alto: float) -> void:
	if malla == null:
		return
	var im: ImmediateMesh = malla.mesh as ImmediateMesh
	im.clear_surfaces()
	if celdas.is_empty():
		return
	var h: float = Terreno3D.casilla * 0.5 - 0.06
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_set_color(color)
	for c in celdas:
		var cc: Vector2i = c as Vector2i
		var p: Vector3 = Terreno3D.centro_de(cc, Terreno3D.y_pies(cc) + alto)
		var esq: Array = [p + Vector3(-h, 0, -h), p + Vector3(h, 0, -h), p + Vector3(h, 0, h), p + Vector3(-h, 0, h)]
		for i in range(4):
			im.surface_add_vertex(esq[i])
			im.surface_add_vertex(esq[(i + 1) % 4])
	im.surface_end()


# ---------------------------------------------------------------------------------------------------------------------
#  Panel y HUD
# ---------------------------------------------------------------------------------------------------------------------

func _montar_panel() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 6
	add_child(capa)
	var caja := PanelContainer.new()
	caja.anchor_left = 1.0
	caja.anchor_right = 1.0
	caja.offset_left = -270.0
	caja.offset_right = -10.0
	caja.offset_top = 10.0
	capa.add_child(caja)
	_caja_glifos = caja
	var v := VBoxContainer.new()
	caja.add_child(v)
	var titulo := Label.new()
	titulo.text = "RECETA V2 · glifos"
	v.add_child(titulo)
	for nombre in Sigils.GLIFOS:
		var fila := HBoxContainer.new()
		v.add_child(fila)
		var et := Label.new()
		et.text = Sigils.nombre_visible(String(nombre))               # lo que ve el jugador: ᚷ «crecer», ᚱ «pulso» (el id interno es «pulso» / «raido»)
		et.custom_minimum_size = Vector2(110.0, 0.0)
		et.tooltip_text = "tope en %d glifos (el panel deja uno de más para ver la saturación)" % glifos_hasta_tope(String(nombre))
		fila.add_child(et)
		fila.add_child(_boton("−", func() -> void: sumar(String(nombre), -1)))
		var cuenta := Label.new()
		cuenta.text = "0"
		cuenta.custom_minimum_size = Vector2(28.0, 0.0)
		cuenta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fila.add_child(cuenta)
		_panel_cuentas[nombre] = cuenta
		fila.add_child(_boton("+", func() -> void: sumar(String(nombre), 1)))
	_selector = OptionButton.new()
	_selector.focus_mode = Control.FOCUS_NONE
	for e in ELEMENTOS:
		_selector.add_item(String(NOMBRE_ELEMENTO[e]))
	_selector.select(ELEMENTOS.find(elemento))
	_selector.item_selected.connect(func(i: int) -> void: poner_elemento(String(ELEMENTOS[i])))
	v.add_child(_selector)
	var acciones := HBoxContainer.new()
	v.add_child(acciones)
	acciones.add_child(_boton("Lanzar (Espacio)", func() -> void: lanzar()))
	acciones.add_child(_boton("Limpiar", func() -> void: limpiar()))
	_boton_barrido = _boton("Barrido (B)", func() -> void: alternar_barrido())
	v.add_child(_boton_barrido)


## Los botones NO toman el foco: si lo tomaran, Espacio los «pulsaría» en vez de lanzar.
func _boton(texto: String, accion: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(accion)
	return b


func _actualizar_boton_barrido() -> void:
	if _boton_barrido != null:
		_boton_barrido.text = "Barrido (B): ACTIVO" if barrido else "Barrido (B)"


func _montar_hud() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 6
	add_child(capa)
	_hud = Label.new()
	_hud.position = Vector2(12.0, 150.0)
	_hud.add_theme_font_size_override("font_size", 15)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 6)
	capa.add_child(_hud)


## El texto del HUD (separado para que las pruebas lo lean sin pintar).
func texto_hud() -> String:
	var r: Lanzador3D.Receta3D = receta()
	var g: Dictionary = r.geo()
	var rune: RuneData = runa()
	var props: Dictionary = g["props"]
	var rel: float = r.tamano_relativo()
	var cas: int = Lanzador3D.GeometriaV2.celdas(g, Vector2(_jug.position.x, _jug.position.z), Vector2(direccion().x, direccion().z), Terreno3D.casilla).size()
	var lineas: PackedStringArray = []
	lineas.append("RECETA %s · %s" % [NOMBRE_ELEMENTO[elemento], _glifos_texto()])
	lineas.append("Elipsoide (semiejes, casillas): x %.2f · y %.2f · z %.2f   → %d casillas, %d nivel(es)" % [float(g["x"]), float(g["y"]), float(g["z"]), cas, Lanzador3D.GeometriaV2.niveles(g)])
	lineas.append("Coste: %.1f de tinta (potencia %s, %d glifos)   ·   daño %s (%d ofensivos)   ·   tamaño relativo %.2f   ·   recarga %.1f s" % [r.coste_tinta(), Dano.nombre_nivel(r.n_glifos()), r.n_glifos(), Dano.nombre_nivel_dano(r.n_glifos_dano()), r.n_glifos_dano(), rel, r.cooldown])
	lineas.append("Nombre derivado: %s  (vfx: %s)" % [String(g["nombre"]), r.forma_vfx()])
	lineas.append("Estado: %s%s" % [rune.estado, ("   ·   ⚠ " + Lanzador3D.GeometriaV2.aviso_materia(g, rune)) if Lanzador3D.GeometriaV2.aviso_materia(g, rune) != "" else ""])
	lineas.append("Propiedades: %s" % (str(props) if not props.is_empty() else "ninguna"))
	if not r.ignorados.is_empty():
		lineas.append("Aún sin uso: %s" % ", ".join(r.ignorados))
	lineas.append("")
	lineas.append("Lanzadas: %d · raras: %d%s" % [lanzadas, raras.size(), (" · última: %s %.2f ms, %d casillas, +%d nodos" % [str(ultimo.get("nombre", "")), float(ultimo.get("ms", 0.0)), int(ultimo.get("celdas", 0)), int(ultimo.get("nodos_pico", 0))]) if not ultimo.is_empty() else ""])
	if barrido:
		lineas.append("BARRIDO ACTIVO · ronda %d%s · semilla %d · cada %.0f s" % [rondas, ("/%d" % rondas_max) if rondas_max > 0 else "", semilla, PERIODO_BARRIDO])
	if not raras.is_empty():
		var u: Dictionary = raras.back()
		lineas.append("Última rara: %s %s → %s (%.2f ms)" % [NOMBRE_ELEMENTO.get(u["elemento"], u["elemento"]), str(u["glifos"]), ", ".join(PackedStringArray(u["motivos"])), float(u["ms"])])
	lineas.append(tiempo.texto() if tiempo != null else "")
	lineas.append("Espacio lanza · B barrido · Tab elemento · Numpad 1-8 glifos (Mayús resta) · Numpad 0 limpia · R recarga")
	for a in _avisos:
		lineas.append("AVISO " + String(a))
	return "\n".join(lineas)


func _glifos_texto() -> String:
	if contadores.is_empty():
		return "sin glifos (esfera base)"
	var partes: PackedStringArray = []
	for nombre in Sigils.GLIFOS:
		if contadores.has(nombre):
			partes.append("%s×%d" % [Sigils.nombre_visible(String(nombre)), int(contadores[nombre])])
	return " ".join(partes)


func _refrescar_hud() -> void:
	if _hud == null or _jug == null:
		return
	_hud.text = texto_hud()
	for nombre in _panel_cuentas:
		(_panel_cuentas[nombre] as Label).text = str(int(contadores.get(nombre, 0)))
