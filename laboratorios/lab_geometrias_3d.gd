class_name LabGeometrias3D
extends Node

## LABORATORIO DE GEOMETRÍAS (29/10, Juego; rehecho el 30/10, Pablo: «se tiene que poder ver a simple vista todas las interacciones de 1 glifo diferente, el
## resto hago yo con el panel»). Sobre `laboratorios/LabGeometrias3D.tscn` (la maqueta PruebaTest2 con nivel = "LabGeometrias"); este nodo cuelga de ella como
## «Reglas», igual que LabRecetas3D. Mapa: mundo/datos_nivel/mapas/LabGeometrias.txt (24 × 27, abierto, con la pared del carril del rebote).
##
## QUINCE CARRILES en dos columnas: el hechizo BASE (lo que pongas en el panel) y, en cada uno de los otros catorce, la base + UN glifo de cada tipo de
## Sigils.GLIFOS. Espacio los lanza TODOS A LA VEZ con el mismo elemento. El plan de pruebas de Pablo: pon una propiedad en el panel (p. ej. ᛁ), mira cómo
## reacciona con cada glifo suelto, súmale más de esa propiedad para ver la progresión y pasa a la siguiente.
## Los glifos que solo actúan si el hechizo VIAJA (ᚢ rebote, ᚦ perforar, ᛃ retorno, ᚨ buscar) llevan ᛇ de base en su carril (lo dice el cartel).
## DIANAS: cada carril tiene su goblin quieto (Combate3D.quieto: no ve, no ataca, recibe golpes, estados y empuje) a DIST_DIANA casillas; perforar lleva tres
## en fila, buscar una desviada del eje y rebote la tiene DETRÁS (el proyectil choca con la pared de delante y vuelve). Se reponen nuevas y sanas en cada
## lanzamiento y con Retroceso, así cada tanda empieza igual. Sin botín de oro.
## Lo que nace donde apuntas (`en_punto`: la barrera, la tierra y el hielo quietos) sale CASILLAS_APUNTADAS por delante del principio del carril, justo antes de la diana.
## Se lanza con `Lanzador3D.lanzar_receta`: no gasta tinta ni espera recarga.
## TECLAS (las de la maqueta siguen: WASD, +/- zoom…):
##   Espacio lanza los quince · Tab siguiente elemento · Numpad 1–9 y «.» suman al panel (con Mayús, restan; el orden es el de Sigils.GLIFOS)
##   Numpad 0 vacía el panel · Numpad Intro repite solo cada T_AUTO s · Retroceso borra lo que queda en la sala y repone las dianas · L/./, cámara lenta y paso a paso

const NIVEL_MAPA: String = "LabGeometrias"
const X_COLUMNA: Array = [2, 13]                ## columna donde empieza cada carril, por columna (oeste, este)
const DIR: Vector3 = Vector3.RIGHT              ## todos hacia el este
const DIST_DIANA: int = 2                       ## casillas de la diana por delante del principio del carril (la flecha de 1 ᛇ llega a 2)
const CASILLAS_APUNTADAS: float = 1.0           ## lo que nace donde apuntas: una casilla antes de la diana (encima, un sólido no podría nacer: la casilla está ocupada)
const T_AUTO: float = 3.0
const ZOOM: float = 40.0                        ## tamaño de cámara para ver la sala entera
## Por carril: nombre (sin runas: la fuente de los carteles 3D no las tiene), columna (0 oeste · 1 este), fila, los glifos que pone el carril (además del panel), dianas (casillas relativas al principio del carril;
## sin la clave, una a DIST_DIANA) y la nota del cartel.
const CARRILES: Array = [
	{"nombre": "Base", "col": 0, "fila": 2, "glifos": {}, "nota": "solo el panel"},
	{"nombre": "Línea X (ancho)", "col": 0, "fila": 5, "glifos": {"linea_x": 1}},
	{"nombre": "Línea Z (fondo)", "col": 0, "fila": 8, "glifos": {"linea_z": 1}},
	{"nombre": "Altura", "col": 0, "fila": 11, "glifos": {"altura": 1}},
	{"nombre": "Flecha", "col": 0, "fila": 14, "glifos": {"flecha": 1}},
	{"nombre": "Barrera", "col": 0, "fila": 17, "glifos": {"barrera": 1}},
	{"nombre": "Repetición", "col": 0, "fila": 20, "glifos": {"repeticion": 1}},
	{"nombre": "Rebote", "col": 0, "fila": 23, "glifos": {"rebote": 1, "flecha": 1}, "dianas": [Vector2i(-1, 0)], "nota": "lleva flecha · pared delante, diana detrás"},
	{"nombre": "Crecer", "col": 1, "fila": 2, "glifos": {"pulso": 1}},
	{"nombre": "Permanencia", "col": 1, "fila": 5, "glifos": {"permanencia": 1}},
	{"nombre": "Pulso", "col": 1, "fila": 8, "glifos": {"raido": 1}},
	{"nombre": "Perforar", "col": 1, "fila": 11, "glifos": {"perforar": 1, "flecha": 1}, "dianas": [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)], "nota": "lleva flecha · tres dianas"},
	{"nombre": "Retorno", "col": 1, "fila": 14, "glifos": {"retorno": 1, "flecha": 1}, "nota": "lleva flecha"},
	{"nombre": "Buscar", "col": 1, "fila": 17, "glifos": {"buscar": 1, "flecha": 1}, "dianas": [Vector2i(DIST_DIANA, 1)], "nota": "lleva flecha · diana fuera del eje"},
	{"nombre": "Retardo", "col": 1, "fila": 20, "glifos": {"retardo": 1}},
]
const TECLAS_MODIFICADOR: Array = [KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_7, KEY_KP_8, KEY_KP_9, KEY_KP_PERIOD]

var m: Variant = null                           ## la maqueta (PruebaTest2)
var _jug: Jugador3D = null
var _l: Lanzador3D = null
var tiempo: TiempoLab3D = null

var elemento: String = "fire"
var modificadores: Dictionary = {}              ## el PANEL: glifo -> veces (solo los > 0), el hechizo base que se suma a todos los carriles
var auto: bool = false
var lanzadas: int = 0                           ## tandas de quince
var dianas: Array = []                          ## {carril, celda, combate: Combate3D}: las de la tanda actual
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
	reponer_dianas()
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

## Los glifos del carril `i`: el panel más el glifo propio del carril (y la ᛇ de base de los que solo actúan al viajar).
func glifos_de(i: int) -> Dictionary:
	var g: Dictionary = ((CARRILES[i] as Dictionary)["glifos"] as Dictionary).duplicate()
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


## Casilla donde empieza el carril `i`.
func celda_de(i: int) -> Vector2i:
	var cr: Dictionary = CARRILES[i]
	return Vector2i(int(X_COLUMNA[int(cr["col"])]), int(cr["fila"]))


## Casillas de las dianas del carril `i`.
func celdas_diana(i: int) -> Array:
	var c0: Vector2i = celda_de(i)
	var res: Array = []
	for d in (CARRILES[i] as Dictionary).get("dianas", [Vector2i(DIST_DIANA, 0)]):
		res.append(c0 + (d as Vector2i))
	return res


## Punto (a la altura de los pies) donde empieza el carril `i`.
func inicio_de(i: int) -> Vector3:
	var c: Vector2i = celda_de(i)
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


## Lanza los quince carriles a la vez, con dianas nuevas. Devuelve cuántos salieron (n > 0).
func lanzar_todos() -> int:
	var rune: RuneData = runa()
	if rune == null:
		return 0
	reponer_dianas()
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
		ultimas.append({"nombre": String((CARRILES[i] as Dictionary)["nombre"]), "glifos": glifos_de(i), "n": n, "nombre_receta": String(g["nombre"]),
			"semiejes": Vector3(float(g["x"]), float(g["y"]), float(g["z"])), "coste": snappedf(r.tamano_relativo(), 0.01),
			"aviso": Lanzador3D.GeometriaV2.aviso_materia(g, rune)})
	lanzadas += 1
	_jug.call("lanzar_clip", Objetos.elemento_de(rune), "x_mano")
	PlayLog.event("lab_geometrias", {"elemento": elemento, "modificadores": modificadores.duplicate(), "salieron": salieron})
	_refrescar()
	return salieron


## Deja la sala como al abrir (la sala no tiene agua propia): hechizos vivos, bloques de tierra, zonas y solideces V2, hielo, agua y estados del suelo.
## Lo mismo que `LabHechizos3D.limpiar_sala`; sin esto lo que deja un elemento (un charco, un bloque) hace que el siguiente no nazca en su carril.
## Repone también las dianas. Devuelve cuántas cosas quitó.
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
	reponer_dianas()
	return n


## Quita las dianas que haya (vivas, muertas o a medio morir) y pone una nueva y sana en cada casilla de `celdas_diana`: goblins quietos, sin oro.
## Devuelve cuántas puso.
func reponer_dianas() -> int:
	var lista: Variant = (m as Object).get("_goblins")
	for d in dianas:
		var cb: Variant = (d as Dictionary)["combate"]
		if is_instance_valid(cb):
			var pj: Pj3D = (cb as Combate3D).pj
			if lista is Array:
				(lista as Array).erase(pj)
			if is_instance_valid(pj):
				pj.queue_free()
			(cb as Combate3D).remove_from_group("combate3d")
			(cb as Node).queue_free()
	dianas.clear()
	for i in range(CARRILES.size()):
		for c in celdas_diana(i):
			var pj: Pj3D = m.call("_personaje", m.PJ_GOBLIN, m.call("_pos_marca", c, m.ALTO))
			if pj == null:
				continue
			pj.rotation.y = PI                    # de cara al hechizo (llega desde el oeste)
			if lista is Array:
				(lista as Array).append(pj)
			var cb: Combate3D = Combate3D.equipar(pj, m, _jug, _l)
			cb.quieto = true
			cb.oro = 0
			dianas.append({"carril": i, "celda": c, "combate": cb})
	return dianas.size()


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
	var cr: Dictionary = CARRILES[i]
	var t: String = String(cr["nombre"])
	if cr.has("nota"):
		t += "  (%s)" % String(cr["nota"])
	t += "\n%.2f × %.2f × %.2f" % [float(g["x"]), float(g["y"]), float(g["z"])]
	var propio: String = valor_propio(i, r)
	if propio != "":
		t += "\n" + propio
	if i < ultimas.size() and int((ultimas[i] as Dictionary)["n"]) <= 0:
		var aviso: String = String((ultimas[i] as Dictionary).get("aviso", ""))
		t += "\nRECHAZADO" + (": " + aviso if aviso != "" else " (no nace aquí)")
	return t


## Lo que el glifo propio del carril pone en el hechizo (los campos de sus modificadores en Sigils.GLIFOS, con el panel ya sumado): «perfora 1 · …».
func valor_propio(i: int, r: Lanzador3D.Receta3D = null) -> String:
	if r == null:
		r = receta_de(i)
	var rune: RuneData = runa()
	var hz: Hechizo = r.hechizo(rune) if rune != null else null
	if hz == null:
		return ""
	var partes: PackedStringArray = []
	var propios: Dictionary = (CARRILES[i] as Dictionary)["glifos"]
	for glifo in propios:
		if glifo == "flecha" and propios.size() > 1:
			continue                              # la ᛇ de base de rebote, perforar, retorno y buscar: el cartel enseña lo del glifo del carril
		for mod in (Sigils.GLIFOS[glifo] as Dictionary)["modificadores"]:
			var campo: String = String((mod as Dictionary)["campo"])
			var v: Variant = hz.get(campo)
			if campo.begins_with("semiejes."):
				v = hz.semiejes[["x", "y", "z"].find(campo.substr(9))]
			var txt: String = str(v)
			if v is float:
				txt = String.num(snappedf(float(v), 0.01))
			partes.append("%s %s" % [campo.replace("semiejes.", "eje "), txt])
	return " · ".join(partes)


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
	titulo.text = "GEOMETRÍAS · hechizo base (todos)"
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
	return "LAB DE GEOMETRÍAS · %s · base: %s\nEspacio lanza los 15 (base + 1 glifo cada uno) · Tab elemento · Numpad 1–9/. suma a la base (Mayús resta) · 0 vacía · Intro repite · Retroceso borra y repone dianas" % [
		String(LabRecetas3D.NOMBRE_ELEMENTO.get(elemento, elemento)), ", ".join(mods) if not mods.is_empty() else "ninguno"]


func _refrescar() -> void:
	for nombre in _panel_cuentas:
		(_panel_cuentas[nombre] as Label).text = str(int(modificadores.get(nombre, 0)))
	for i in range(_carteles.size()):
		(_carteles[i] as Label3D).text = _texto_cartel(i)
	if _hud != null:
		_hud.text = texto_hud()
