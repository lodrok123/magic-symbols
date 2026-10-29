class_name LabGeometrias3D
extends Node

## LABORATORIO DE GEOMETRÍAS (29/10, Juego; Pablo: «un laboratorio de vfx con un hechizo con distintas geometrías para revisarlas todas juntas, y que se
## puedan añadir glifos para modificar»). Sobre `laboratorios/LabGeometrias3D.tscn` (la maqueta PruebaTest2 con nivel = "LabGeometrias"); este nodo
## cuelga de ella como «Reglas», igual que LabRecetas3D. Mapa: mundo/datos_nivel/mapas/LabGeometrias.txt (20 × 27, abierto).
##
## OCHO CARRILES, de oeste a este, cada uno con una GEOMETRÍA (los glifos de forma de `CARRILES`): esfera, ancha, larga, alta, flecha, flecha ancha, muro y
## muro largo. Espacio los lanza TODOS A LA VEZ con el mismo elemento, así se comparan los VFX uno al lado del otro. Los MODIFICADORES (el panel, o el
## teclado numérico) se suman a la geometría de cada carril: con +2 repetición, las ocho salen con tres copias. Cada carril lleva su cartel con el nombre,
## el nombre derivado de la receta (x_mano · alto · abajo…) y su coste; «rechazado» si el juego no lo deja nacer (p. ej. un sólido demasiado alto).
## Lo que nace donde apuntas (la barrera, `en_punto`) sale CASILLAS_APUNTADAS por delante del principio del carril.
## Se lanza con `Lanzador3D.lanzar_receta`: no gasta tinta ni espera recarga.
## TECLAS (las de la maqueta siguen: WASD, +/- zoom…):
##   Espacio lanza los ocho · Tab siguiente elemento · Numpad 1–9 y «.» suman un modificador (con Mayús, restan; el orden es el de Sigils.GLIFOS)
##   Numpad 0 quita los modificadores · Numpad Intro repite solo cada T_AUTO s · Retroceso borra lo que queda en la sala · L/./, cámara lenta y paso a paso

const NIVEL_MAPA: String = "LabGeometrias"
const X_CARRIL: int = 2                         ## columna donde empieza cada carril
const DIR: Vector3 = Vector3.RIGHT              ## todos hacia el este
const CASILLAS_APUNTADAS: float = 3.0
const T_AUTO: float = 3.0
const ZOOM: float = 38.0                        ## tamaño de cámara para ver la sala entera
## [nombre, fila, glifos de la geometría]
const CARRILES: Array = [
	["Esfera", 2, {}],
	["Ancha", 5, {"linea_x": 2}],
	["Larga", 8, {"linea_z": 2}],
	["Alta", 11, {"altura": 3}],
	["Flecha", 15, {"flecha": 1}],
	["Flecha ancha", 18, {"flecha": 1, "linea_x": 1}],
	["Muro", 21, {"barrera": 1, "linea_x": 2, "altura": 2}],
	["Muro largo", 24, {"barrera": 1, "linea_z": 2, "altura": 1}],
]
const TECLAS_MODIFICADOR: Array = [KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_7, KEY_KP_8, KEY_KP_9, KEY_KP_PERIOD]

var m: Variant = null                           ## la maqueta (PruebaTest2)
var _jug: Jugador3D = null
var _l: Lanzador3D = null
var tiempo: TiempoLab3D = null

var elemento: String = "fire"
var modificadores: Dictionary = {}              ## glifo -> veces (solo los > 0): se suman a todos los carriles
var auto: bool = false
var lanzadas: int = 0                           ## tandas de ocho
var ultimas: Array = []                         ## por carril: {nombre, glifos, n, nombre_receta, coste}

var _t_auto: float = 0.0
var _carteles: Array = []
var _hud: Label = null
var _panel_cuentas: Dictionary = {}
var _selector: OptionButton = null
var _boton_auto: Button = null


func _ready() -> void:
	call_deferred("_arrancar")


func _arrancar() -> void:
	if get_parent() != null:
		iniciar(get_parent())


func iniciar(mundo: Variant) -> void:
	m = mundo
	for n in (m as Node).get_children():
		if n is Jugador3D:
			_jug = n
	_l = get_tree().get_first_node_in_group("spellcaster") as Lanzador3D
	if _jug == null or _l == null:
		push_error("LabGeometrias3D: la escena necesita el Jugador3D y el Lanzador3D de la maqueta")
		return
	_jug.salto_activo = false
	tiempo = TiempoLab3D.new()
	add_child(tiempo)
	_poner_zoom()
	_montar_carteles()
	_montar_panel()
	_montar_hud()
	_refrescar()
	set_process(true)


func _poner_zoom() -> void:
	if m == null or not (m as Object).get("_tam_camara") is float:
		return
	(m as Object).set("_tam_camara", ZOOM)
	var cam: Variant = (m as Object).get("_camara")
	if cam is Camera3D:
		(cam as Camera3D).size = ZOOM


# ---------------------------------------------------------------------------------------------------------------------
#  Las recetas
# ---------------------------------------------------------------------------------------------------------------------

## Los glifos del carril `i`: los de su geometría más los modificadores.
func glifos_de(i: int) -> Dictionary:
	var g: Dictionary = (CARRILES[i][2] as Dictionary).duplicate()
	for k in modificadores:
		g[k] = int(g.get(k, 0)) + int(modificadores[k])
	return g


func receta_de(i: int) -> Lanzador3D.Receta3D:
	var r := Lanzador3D.Receta3D.new(Vector2.RIGHT)
	var g: Dictionary = glifos_de(i)
	for nombre in Sigils.GLIFOS:
		for _k in range(int(g.get(nombre, 0))):
			r.apply(String(nombre))
	return r


func runa() -> RuneData:
	return load("res://nucleo/%s_rune.tres" % elemento) as RuneData


## Casilla y punto (a la altura de los pies) donde empieza el carril `i`.
func inicio_de(i: int) -> Vector3:
	var c := Vector2i(X_CARRIL, int(CARRILES[i][1]))
	return Vector3((float(c.x) + 0.5) * Terreno3D.casilla, Terreno3D.y_pies(c), (float(c.y) + 0.5) * Terreno3D.casilla)


func sumar(glifo: String, delta: int) -> void:
	if not Sigils.GLIFOS.has(glifo):
		return
	var n: int = clampi(int(modificadores.get(glifo, 0)) + delta, 0, LabRecetas3D.glifos_hasta_tope(glifo) + 1)
	if n == 0:
		modificadores.erase(glifo)
	else:
		modificadores[glifo] = n
	_refrescar()


func limpiar() -> void:
	modificadores.clear()
	_refrescar()


func siguiente_elemento() -> void:
	var lista: Array = LabRecetas3D.ELEMENTOS
	poner_elemento(String(lista[(lista.find(elemento) + 1) % lista.size()]))


func poner_elemento(e: String) -> void:
	if LabRecetas3D.ELEMENTOS.has(e):
		elemento = e
		if _selector != null:
			_selector.select(LabRecetas3D.ELEMENTOS.find(e))
		_refrescar()


## Lanza los ocho carriles a la vez. Devuelve cuántos salieron (n > 0).
func lanzar_todos() -> int:
	var rune: RuneData = runa()
	if rune == null:
		return 0
	ultimas.clear()
	var salieron: int = 0
	for i in range(CARRILES.size()):
		var r: Lanzador3D.Receta3D = receta_de(i)
		var origen: Vector3 = inicio_de(i)
		var hz: Hechizo = r.hechizo(rune)
		if hz != null and hz.en_punto:
			origen += DIR * Terreno3D.casilla * minf(CASILLAS_APUNTADAS, Lanzador3D.ALCANCE_ORIGEN)
		var n: int = _l.lanzar_receta(r, rune, origen, DIR)
		if n > 0:
			salieron += 1
		var g: Dictionary = r.geo()
		ultimas.append({"nombre": String(CARRILES[i][0]), "glifos": glifos_de(i), "n": n, "nombre_receta": String(g["nombre"]),
			"semiejes": Vector3(float(g["x"]), float(g["y"]), float(g["z"])), "coste": snappedf(r.tamano_relativo(), 0.01),
			"aviso": Lanzador3D.GeometriaV2.aviso_materia(g, rune)})
	lanzadas += 1
	_jug.call("lanzar_clip", Objetos.elemento_de(rune), "x_mano")
	PlayLog.event("lab_geometrias", {"elemento": elemento, "modificadores": modificadores.duplicate(), "salieron": salieron})
	_refrescar()
	return salieron


## Deja la sala como al abrir (la sala no tiene agua propia): hechizos vivos, bloques de tierra, zonas y solideces V2, hielo, agua y estados del suelo.
## Lo mismo que `LabHechizos3D.limpiar_sala`; sin esto lo que deja un elemento (un charco, un bloque) hace que el siguiente no nazca en su carril.
## Devuelve cuántas cosas quitó.
func borrar_sala() -> int:
	var n: int = 0
	for h in (m as Node).find_children("*", "HechizoVivo", true, false):
		(h as Node).queue_free()
		n += 1
	for bl in _l._bloques.duplicate():
		_l._deshacer_bloque(bl)
		n += 1
	for lista in [_l._zonas_v2, _l._solideces_v2]:
		for z in (lista as Array).duplicate():
			if is_instance_valid(z):
				(z as Node).queue_free()
				n += 1
		(lista as Array).clear()
	var sim: AguaSim3D = Terreno3D.agua_sim
	if sim != null:
		var cas: float = Terreno3D.casilla
		for _pasada in range(5):                 # `quitar` alcanza un círculo y el agua se reparte al moverse: se repite hasta que no quede
			var movido: bool = false
			for y in range(Terreno3D.mapa.size()):
				for x in range(Terreno3D.mapa[y].length()):
					var c := Vector2i(x, y)
					if sim.caudal_en(c) > 0.0:
						sim.apagar_fuente(c)
					if sim.casilla_helada(c):
						sim.derretir(Terreno3D.centro_de(c, 0.0), cas * 0.5)
					var hondo: float = sim.profundidad_casilla(c)
					if hondo < 0.0008:
						continue
					movido = true
					sim.quitar(Terreno3D.centro_de(c, 0.0), hondo * cas * cas, cas * 0.75)
			if not movido:
				break
	var est: EstadosSuelo3D = Terreno3D.estados
	if est != null:
		for e in EstadosSuelo3D.TODOS:
			for c in est.celdas(String(e)):
				if est.poner(c as Vector2i, String(e), false):
					n += 1
	return n


func alternar_auto() -> void:
	auto = not auto
	_t_auto = 0.0
	if _boton_auto != null:
		_boton_auto.text = "Repetir solo: %s (Intro)" % ("sí" if auto else "no")


func _process(delta: float) -> void:
	if not auto:
		return
	_t_auto += delta
	if _t_auto >= T_AUTO:
		_t_auto = 0.0
		borrar_sala()
		lanzar_todos()


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or m == null:
		return
	var k: InputEventKey = ev as InputEventKey
	if not k.pressed or k.echo:
		return
	var atendida: bool = true
	var glifos: Array = Sigils.GLIFOS.keys()
	var i: int = TECLAS_MODIFICADOR.find(k.keycode)
	if k.keycode == KEY_SPACE:
		lanzar_todos()
	elif k.keycode == KEY_TAB:
		siguiente_elemento()
	elif k.keycode == KEY_KP_0:
		limpiar()
	elif k.keycode == KEY_KP_ENTER:
		alternar_auto()
	elif k.keycode == KEY_BACKSPACE:
		borrar_sala()
	elif i >= 0 and i < glifos.size():
		sumar(String(glifos[i]), -1 if k.shift_pressed else 1)
	else:
		atendida = false
	if atendida:
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------------------------------------------------
#  Carteles, panel y HUD
# ---------------------------------------------------------------------------------------------------------------------

func _montar_carteles() -> void:
	for i in range(CARRILES.size()):
		var e := Label3D.new()
		e.name = "Cartel_%d" % i
		e.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		e.font_size = 44
		e.outline_size = 14
		e.pixel_size = 0.016
		e.no_depth_test = true
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		(m as Node).add_child(e)
		e.global_position = inicio_de(i) + Vector3(-0.4 * Terreno3D.casilla, 0.2, -1.1 * Terreno3D.casilla)   # encima del carril (al norte), sin tapar lo que sale
		_carteles.append(e)


func _texto_cartel(i: int) -> String:
	var r: Lanzador3D.Receta3D = receta_de(i)
	var g: Dictionary = r.geo()
	var t: String = "%s\n%.2f × %.2f × %.2f · coste %.2f" % [String(CARRILES[i][0]), float(g["x"]), float(g["y"]), float(g["z"]), r.tamano_relativo()]
	if i < ultimas.size() and int((ultimas[i] as Dictionary)["n"]) <= 0:
		var aviso: String = String((ultimas[i] as Dictionary).get("aviso", ""))
		t += "\nRECHAZADO" + (": " + aviso if aviso != "" else " (no nace aquí)")
	return t


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
	var v := VBoxContainer.new()
	caja.add_child(v)
	var titulo := Label.new()
	titulo.text = "GEOMETRÍAS · modificadores"
	v.add_child(titulo)
	for nombre in Sigils.GLIFOS:
		var fila := HBoxContainer.new()
		v.add_child(fila)
		var et := Label.new()
		et.text = Sigils.nombre_visible(String(nombre))
		et.custom_minimum_size = Vector2(110.0, 0.0)
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
	for e in LabRecetas3D.ELEMENTOS:
		_selector.add_item(String(LabRecetas3D.NOMBRE_ELEMENTO[e]))
	_selector.select(LabRecetas3D.ELEMENTOS.find(elemento))
	_selector.item_selected.connect(func(i: int) -> void: poner_elemento(String(LabRecetas3D.ELEMENTOS[i])))
	v.add_child(_selector)
	var acciones := HBoxContainer.new()
	v.add_child(acciones)
	acciones.add_child(_boton("Lanzar (Espacio)", func() -> void: lanzar_todos()))
	acciones.add_child(_boton("Quitar", func() -> void: limpiar()))
	v.add_child(_boton("Borrar sala (Retroceso)", func() -> void: borrar_sala()))
	_boton_auto = _boton("Repetir solo: no (Intro)", func() -> void: alternar_auto())
	v.add_child(_boton_auto)


## Los botones NO toman el foco: si lo tomaran, Espacio los «pulsaría» en vez de lanzar.
func _boton(texto: String, accion: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(accion)
	return b


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


func texto_hud() -> String:
	var mods: PackedStringArray = []
	for k in modificadores:
		mods.append("%s ×%d" % [Sigils.nombre_visible(String(k)), int(modificadores[k])])
	return "LAB DE GEOMETRÍAS · %s · modificadores: %s\nEspacio lanza los 8 · Tab elemento · Numpad 1–9/. suma (Mayús resta) · 0 quita · Intro repite · Retroceso borra" % [
		String(LabRecetas3D.NOMBRE_ELEMENTO.get(elemento, elemento)), ", ".join(mods) if not mods.is_empty() else "ninguno"]


func _refrescar() -> void:
	for nombre in _panel_cuentas:
		(_panel_cuentas[nombre] as Label).text = str(int(modificadores.get(nombre, 0)))
	for i in range(_carteles.size()):
		(_carteles[i] as Label3D).text = _texto_cartel(i)
	if _hud != null:
		_hud.text = texto_hud()
