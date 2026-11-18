class_name MenuPestanas
extends CanvasLayer

## EL MENÚ CON PESTAÑAS (24/10, Juego; referencia: el menú de Echoes of Wisdom con Inventario, Grimorio, Síntesis, Mapa, Misiones y Ajustes).
## Se abre con I (en Inventario) o con J (en Misiones); Esc o la misma tecla lo cierra. Q / E (y AvPág / RePág, o el clic) cambian de pestaña: son el L1 / R1 del mando.
## Pausa el mundo mientras está abierto, como la mochila y el diario a los que sustituye (los reanuda al cerrar y en `_exit_tree`).
##
## PESTAÑAS. Funcionales: INVENTARIO, VESTUARIO (12/11), MISIONES y ESTADÍSTICAS. Las otras cuatro (Grimorio, Síntesis, Mapa, Ajustes) salen visibles con un «Próximamente» ilustrado.
##   · Vestuario (12/11, encargo de Pablo): una carta por atuendo (`Atuendos`: el de viaje verde, el uniforme de Monte Sumicio y el del lobo) con su icono
##     (`arte/iconos/<id>.png`), sus prendas y si lo tienes y lo llevas. ←→ (o el ratón) eligen; Enter (o un segundo clic) te lo pone: quita lo puesto y pone
##     sus prendas en la jugadora (`Atuendos.poner`). Los que no tienes salen velados y dicen quién los vende. Enter sobre un atuendo en Inventario hace lo mismo.
##   · Inventario: rejilla de 5 × 4 = 20 huecos (los que aún no tienes, bloqueados) con el marco de la calidad de cada objeto (`MarcoCalidad`), contador,
##     y a la derecha el panel de detalle (icono grande, nombre, tipo y calidad, descripción y «Usos conocidos», de `Objetos.usos`). Elegir: flechas o ratón
##     (pasar por encima elige; un segundo clic o Enter actúa). Enter sobre un consumible lo EQUIPA (Q lo usa fuera del menú); Enter sobre el que ya está
##     equipado cierra el menú y lo usa. Los huecos son los de `BolsaUI.Hueco` y el orden el de `BolsaUI.ordenar` (categoría y nombre): la lógica de la
##     mochila no cambia, solo cambia dónde se mira.
##   · Misiones: la lista y la ficha de `DiarioMisiones` (`montar_en`), con ↑↓ para elegir y Enter para seguir la misión.
## LA BOLSA ANTIGUA (`BolsaUI`, la de forma de saco) ya no se monta en el juego: este menú abre en Inventario y hace su trabajo. La clase se conserva
## porque este menú reutiliza sus huecos y sus utilidades de dibujo, y para su prueba (`prueba_bolsa`).
## Para las pruebas: `abrir(pestana)`, `cerrar()`, `cambiar_pestana(i)`, `mover(dir)`, `accion()`, `detalle()`, `elegido()`, `pestana`, `abierta`.

const ANCHO: float = 860.0
const ALTO: float = 540.0
const CUERPO_POS: Vector2 = Vector2(48.0, 156.0)
const CUERPO_TAM: Vector2 = Vector2(764.0, 322.0)
const COLUMNAS: int = 6
const FILAS: int = 4                               ## 6 × 4 = Estado.CAPACIDAD_MAX (24 desde el 14/11)
const TAM_HUECO: float = 56.0
const SEP_HUECO: float = 6.0
const ANCHO_DETALLE: float = 392.0
const ALPHA_VELO: float = 0.45
const T_ABRIR_S: float = 0.22
const T_CERRAR_S: float = 0.16
const SUBIDA_PX: float = 34.0
const DORADO: Color = Color("c9962b")
const TINTA: Color = Color("4e3a26")
const TINTA_SUAVE: Color = Color(0.31, 0.23, 0.15, 0.62)
const INDICE_INVENTARIO: int = 0
const INDICE_VESTUARIO: int = 1                    ## 12/11: los atuendos (Atuendos), tras Inventario; las demás corren una
const INDICE_MAPA: int = 4                         ## 13/11: el mapa que se dibuja andando (PaginaMapa, Cartografia)
const INDICE_MISIONES: int = 5
const INDICE_ESTADISTICAS: int = 6                 ## 2/11 (tercera tanda A3): tras Misiones; Ajustes pasa a la 7

## id, nombre, subtítulo bajo el título, y (solo las que aún no funcionan) lo que dirá su «Próximamente».
const PESTANAS: Array = [
	{"id": "inventario", "nombre": "Inventario", "sub": "Tus objetos y consumibles"},
	{"id": "vestuario", "nombre": "Vestuario", "sub": "Tus atuendos: elige qué te pones"},
	{"id": "grimorio", "nombre": "Grimorio", "sub": "Los hechizos que dominas", "prox": "Aquí repasarás tus recetas de runas y las páginas de tu libro."},
	{"id": "sintesis", "nombre": "Síntesis", "sub": "Combina materiales", "prox": "Aquí mezclarás los materiales que recojas para preparar tónicos y pigmentos."},
	{"id": "mapa", "nombre": "Mapa", "sub": "Por dónde has pasado"},
	{"id": "misiones", "nombre": "Misiones", "sub": "Tu diario de misiones"},
	{"id": "estadisticas", "nombre": "Estadísticas", "sub": "Lo que llevas hecho"},
	{"id": "ajustes", "nombre": "Ajustes", "sub": "Sonido, controles y pantalla", "prox": "Aquí ajustarás el sonido, los controles y la pantalla."},
]

## GAMEFEEL M (31/10): sonidos y movimiento de la mochila. Todo lo afinable aquí; `Sensacion3D.ACTIVA = false` apaga los pops, deslizamientos y destellos pero NO los sonidos.
static var DB_NO_PUEDES: float = -14.0          ## Enter sobre un material o un objeto clave
static var DB_PAGINA: float = -14.0             ## cambiar de pestaña
static var T_ANILLO_S: float = 0.08             ## el aro dorado se desliza de un hueco al otro
static var T_PAGINA_S: float = 0.12             ## el contenido de la pestaña entra desde un lado
static var DESPLAZ_PAGINA_PX: float = 12.0
static var T_FUNDIDO_ICONO_S: float = 0.1       ## el icono del detalle funde al cambiar de objeto
static var T_BRILLO_NUEVO_S: float = 0.4        ## el hueco del objeto recién llegado brilla
static var T_ORO_S: float = 0.3                 ## el contador de oro cuenta hacia el valor nuevo
static var POP_ORO: float = 1.2                 ## escala inicial del pop del contador

var abierta: bool = false
var pestana: int = INDICE_INVENTARIO
var _anillo: Anillo = null                       ## el aro dorado del hueco elegido (un control aparte por encima de la rejilla)
var _anillo_colocado: bool = false
var _tw_anillo: Tween = null
var _tw_pagina: Tween = null
var _tw_oro: Tween = null
var _oro_valor: int = 0
var _cuentas: Dictionary = {}                    ## id -> cantidad en la mochila tras el último refresco (para ver qué objeto es nuevo)
var _velo: ColorRect
var _marco: Control
var _fondo: Control
var _barra: Control
var _cuerpo: Control
var _pag_inv: Control
var _pag_vest: PaginaVestuario                     ## 12/11: la pestaña Vestuario (atuendos)
var _pag_mis: Control
var _pag_mapa: PaginaMapa                          ## 13/11: la pestaña Mapa
var _pag_est: Control                              ## A3: la pestaña Estadísticas (dos columnas: la partida y este nivel)
var _col_total: GridContainer
var _col_nivel: GridContainer
var _pie_est: Label
var _pag_prox: Control
var _rejilla: Control
var _huecos: Array = []
var _detalle: Control
var _pie_huecos: Label
var _oro: Label
var _sel: int = -1                                 ## índice de pila elegida (0 = la primera), -1 = ninguna
var _pilas: Array = []
var _diario: DiarioMisiones = null
var _tween: Tween = null
var _pausado_por_mi: bool = false
var _consumibles: Consumibles = Consumibles.new() ## solo para equipar (lo que cambia es `Estado`, y el HUD lo oye)


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_velo = ColorRect.new()
	_velo.color = Color(0, 0, 0, 0)
	_velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_velo.visible = false
	add_child(_velo)
	_marco = Control.new()
	_marco.theme = TemaInterfaz.tema()
	_marco.size = Vector2(ANCHO, ALTO)
	_marco.visible = false
	_marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marco)
	_fondo = Fondo.new()
	_fondo.menu = self
	_fondo.size = Vector2(ANCHO, ALTO)
	_marco.add_child(_fondo)
	_barra = BarraPestanas.new()
	_barra.menu = self
	_barra.position = Vector2(48.0, 86.0)
	_barra.size = Vector2(ANCHO - 96.0, 62.0)
	_marco.add_child(_barra)
	_cuerpo = Control.new()
	_cuerpo.position = CUERPO_POS
	_cuerpo.size = CUERPO_TAM
	_cuerpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marco.add_child(_cuerpo)
	_construir_inventario()
	_construir_vestuario()
	_construir_misiones()
	_construir_estadisticas()
	_pag_mapa = PaginaMapa.new()
	_pag_mapa.menu = self
	_pag_mapa.size = CUERPO_TAM
	_pag_mapa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cuerpo.add_child(_pag_mapa)
	_construir_proximamente()
	get_viewport().size_changed.connect(_colocar)
	Estado.i().cambiado.connect(_al_cambiar_mochila)
	_mostrar_pagina()


func _exit_tree() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if _pausado_por_mi and is_inside_tree():
		get_tree().paused = false
	var e: Estado = Estado.i()
	if e.cambiado.is_connected(_al_cambiar_mochila):
		e.cambiado.disconnect(_al_cambiar_mochila)
	if _diario != null and is_instance_valid(_diario):
		_diario.free()                              # no está en el árbol: no lo libera nadie más
		_diario = null


## --- Construcción de las páginas ---

func _construir_inventario() -> void:
	_pag_inv = Control.new()
	_pag_inv.size = CUERPO_TAM
	_pag_inv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cuerpo.add_child(_pag_inv)
	_rejilla = Control.new()
	_rejilla.size = Vector2(float(COLUMNAS) * (TAM_HUECO + SEP_HUECO) - SEP_HUECO, float(FILAS) * (TAM_HUECO + SEP_HUECO) - SEP_HUECO)
	_rejilla.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pag_inv.add_child(_rejilla)
	# Bajo la rejilla: cuántos huecos se usan, y el oro (moneda + cifra) a la derecha.
	_pie_huecos = BolsaUI._etiqueta(14)
	_pie_huecos.position = Vector2(2.0, _rejilla.size.y + 12.0)
	_pag_inv.add_child(_pie_huecos)
	var moneda := BolsaUI.Moneda.new()
	moneda.position = Vector2(_rejilla.size.x - 96.0, _rejilla.size.y + 8.0)
	_pag_inv.add_child(moneda)
	_oro = BolsaUI._etiqueta(20)
	_oro.position = Vector2(_rejilla.size.x - 58.0, _rejilla.size.y + 5.0)
	_oro.tooltip_text = "Oro"
	_pag_inv.add_child(_oro)
	_detalle = Detalle.new()
	_detalle.menu = self
	_detalle.position = Vector2(CUERPO_TAM.x - ANCHO_DETALLE, 0.0)
	_detalle.size = Vector2(ANCHO_DETALLE, CUERPO_TAM.y)
	_pag_inv.add_child(_detalle)


func _construir_vestuario() -> void:
	_pag_vest = PaginaVestuario.new()
	_pag_vest.menu = self
	_pag_vest.size = CUERPO_TAM
	_cuerpo.add_child(_pag_vest)


func _construir_misiones() -> void:
	_pag_mis = Control.new()
	_pag_mis.size = CUERPO_TAM
	_pag_mis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cuerpo.add_child(_pag_mis)
	var marcas := Control.new()                     # la raya que separa la lista de la ficha
	marcas.size = CUERPO_TAM
	marcas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marcas.draw.connect(func() -> void:
		var x: float = DiarioMisiones.ANCHO_LISTA + 14.0
		marcas.draw_line(Vector2(x, 0.0), Vector2(x, CUERPO_TAM.y), TINTA_SUAVE, 1.5))
	_pag_mis.add_child(marcas)
	_diario = DiarioMisiones.new()
	_diario.montar_en(_pag_mis, CUERPO_TAM)


## A3: dos columnas en el tema del pergamino: «Tu partida» (`Estadisticas.total`) y «Este nivel» (`Estadisticas.por_nivel`), y debajo el desglose por tipo de enemigo y elemento.
func _construir_estadisticas() -> void:
	_pag_est = Control.new()
	_pag_est.size = CUERPO_TAM
	_pag_est.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cuerpo.add_child(_pag_est)
	var marcas := Control.new()                     # la raya que separa las dos columnas
	marcas.size = CUERPO_TAM
	marcas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marcas.draw.connect(func() -> void: marcas.draw_line(Vector2(CUERPO_TAM.x * 0.5, 0.0), Vector2(CUERPO_TAM.x * 0.5, CUERPO_TAM.y - 70.0), TINTA_SUAVE, 1.5))
	_pag_est.add_child(marcas)
	for k in range(2):
		var x: float = 6.0 if k == 0 else CUERPO_TAM.x * 0.5 + 24.0
		var titulo: Label = BolsaUI._etiqueta(20)
		titulo.text = "Tu partida" if k == 0 else "Este nivel"
		titulo.position = Vector2(x, 0.0)
		_pag_est.add_child(titulo)
		var rejilla := GridContainer.new()
		rejilla.columns = 2
		rejilla.add_theme_constant_override("h_separation", 24)
		rejilla.add_theme_constant_override("v_separation", 8)
		rejilla.position = Vector2(x, 38.0)
		rejilla.custom_minimum_size = Vector2(CUERPO_TAM.x * 0.5 - 40.0, 0.0)
		_pag_est.add_child(rejilla)
		if k == 0:
			_col_total = rejilla
		else:
			_col_nivel = rejilla
	_pie_est = BolsaUI._etiqueta(14)
	_pie_est.position = Vector2(6.0, CUERPO_TAM.y - 62.0)
	_pie_est.size = Vector2(CUERPO_TAM.x - 12.0, 56.0)
	_pie_est.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pag_est.add_child(_pie_est)
	_refrescar_estadisticas()


## Las cifras de la pestaña: {"total": [[etiqueta, valor], …], "nivel": […]}. Es lo que se dibuja (y lo que miran las pruebas).
func estadisticas_filas() -> Dictionary:
	var n: Dictionary = Estadisticas.por_nivel.duplicate(true)
	n["segundos"] = Estadisticas.segundos_nivel()
	return {"total": Estadisticas.filas(Estadisticas.a_dic()), "nivel": Estadisticas.filas(n)}


func _refrescar_estadisticas() -> void:
	if _col_total == null:
		return
	var f: Dictionary = estadisticas_filas()
	for par in [[_col_total, f["total"]], [_col_nivel, f["nivel"]]]:
		var rejilla: GridContainer = par[0]
		for h in rejilla.get_children():
			rejilla.remove_child(h)
			h.queue_free()
		for fila in (par[1] as Array):
			var a: Label = BolsaUI._etiqueta(16)
			a.text = String(fila[0])
			a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rejilla.add_child(a)
			var b: Label = BolsaUI._etiqueta(16)
			b.text = String(fila[1])
			b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			rejilla.add_child(b)
	var partes: PackedStringArray = []
	var en: Dictionary = Estadisticas.total["enemigos"]
	if not en.is_empty():
		var l: PackedStringArray = []
		for k in en.keys():
			l.append("%s %d" % [String(k), int(en[k])])
		partes.append("Vencidos: " + ", ".join(l))
	var he: Dictionary = Estadisticas.total["hechizos"]
	if not he.is_empty():
		var l2: PackedStringArray = []
		for k in he.keys():
			l2.append("%s %d" % [String(k), int(he[k])])
		partes.append("Hechizos: " + ", ".join(l2))
	_pie_est.text = "\n".join(partes) if not partes.is_empty() else "Aún no has contado nada: sal a pelear."


func _construir_proximamente() -> void:
	_pag_prox = Proximamente.new()
	_pag_prox.menu = self
	_pag_prox.size = CUERPO_TAM
	_pag_prox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cuerpo.add_child(_pag_prox)


## --- Datos (y lo que usan las pruebas) ---

func pestana_id() -> String:
	return String((PESTANAS[pestana] as Dictionary)["id"])


func funcional(i: int) -> bool:
	return i == INDICE_INVENTARIO or i == INDICE_VESTUARIO or i == INDICE_MISIONES or i == INDICE_ESTADISTICAS or i == INDICE_MAPA


## Vestuario (12/11): el atuendo elegido en la pestaña ("" si no hay).
func atuendo_elegido() -> String:
	return _pag_vest.id_elegido() if _pag_vest != null else ""


## Vestuario (12/11): se pone el atuendo `id` en la jugadora del árbol (Atuendos.poner: quita lo puesto y pone sus prendas). false (y «no puedes») si no se
## tiene, no hay jugadora o alguna prenda no carga.
func ponerse_atuendo(id: String) -> bool:
	var pj: Node = Atuendos.pj_de(get_tree()) if is_inside_tree() else null
	if pj == null or not Atuendos.tiene(id) or not Atuendos.poner(pj, id):
		Sfx.play_ui("no_puedes_ui", DB_NO_PUEDES)
		if _pag_vest != null:
			_pag_vest.queue_redraw()
		return false
	Sfx.play_ui("ui_equipar")
	if _pag_vest != null:
		_pag_vest.queue_redraw()
	return true


## Las pilas de la mochila en el orden del menú: [[id, cantidad], ...].
func pilas() -> Array:
	return _pilas


func elegido() -> int:
	return _sel


func hueco(i: int) -> BolsaUI.Hueco:
	return _huecos[i] as BolsaUI.Hueco if i >= 0 and i < _huecos.size() else null


## Lo que enseña el panel de detalle del objeto elegido: {id, nombre, calidad, tipo, desc, usos, cantidad, equipado}. {} si no hay ninguno.
func detalle() -> Dictionary:
	if _sel < 0 or _sel >= _pilas.size():
		return {}
	var id: String = String(_pilas[_sel][0])
	var cal: String = MarcoCalidad.normalizar(BolsaUI.calidad_de(id))
	return {"id": id, "nombre": Objetos.nombre(id), "calidad": cal, "tipo": tipo_texto(id), "desc": Objetos.descripcion(id), "usos": Objetos.usos(id),
		"cantidad": Estado.i().cuenta(id), "equipado": Objetos.es_consumible(id) and _consumibles.equipado() == id}


## «Material común», «Consumible», «Objeto clave»… (como el «Material común» de la referencia).
static func tipo_texto(id: String) -> String:
	var cal: String = MarcoCalidad.normalizar(BolsaUI.calidad_de(id))
	var nombre_cal: String = String((Objetos.CALIDADES[cal] as Dictionary)["nombre"]).to_lower()
	match Objetos.categoria(id):
		"pociones":
			return "Consumible" if cal == Objetos.CALIDAD_COMUN else "Consumible %s" % nombre_cal
		"clave":
			return "Objeto clave"
	return "Material %s" % nombre_cal


## Un color para el texto de calidad que se lea sobre pergamino.
static func color_tipo(cal: String) -> Color:
	match MarcoCalidad.normalizar(cal):
		Objetos.CALIDAD_EPICO:
			return Color(0.45, 0.18, 0.74)
		Objetos.CALIDAD_LEGENDARIO:
			return Color(0.66, 0.42, 0.04)
	return TINTA_SUAVE


func pista() -> String:
	match pestana:
		INDICE_INVENTARIO:
			return "[Q/E] pestaña   [↑↓←→] elegir   [Enter] equipar / usar   [I / Esc] cerrar"
		INDICE_VESTUARIO:
			return "[Q/E] pestaña   [←→] elegir   [Enter] ponerse   [I / Esc] cerrar"
		INDICE_MISIONES:
			return "[Q/E] pestaña   [↑↓] elegir   [Enter] seguir   [J / Esc] cerrar"
		INDICE_ESTADISTICAS:
			return "[Q/E] pestaña   [I / Esc] cerrar"
	return "[Q/E] pestaña   [I / Esc] cerrar"


## --- Abrir, cerrar, cambiar de pestaña ---

func alternar() -> void:
	if abierta:
		cerrar()
	else:
		abrir()


func abrir(p_pestana: int = INDICE_INVENTARIO) -> void:
	if abierta:
		cambiar_pestana(p_pestana)
		return
	if is_inside_tree() and get_tree().paused:
		return                                      # con otra pantalla que ya pausa (el libro, un cofre) no se abre encima
	if _libro_abierto():
		return                                      # M6: el libro no pausa (solo ralentiza el tiempo): con él abierto tampoco se abre la mochila encima
	abierta = true
	pestana = clampi(p_pestana, 0, PESTANAS.size() - 1)
	_refrescar(false)                               # al abrir no se anima nada (ni «objeto nuevo» por lo que llegó con el menú cerrado)
	_mostrar_pagina()
	if is_inside_tree():
		get_tree().paused = true
		_pausado_por_mi = true
		Sfx.play_ui("libro_abre" if pestana == INDICE_MISIONES else "bolsa")      # M1: la J abre el diario de misiones como un libro
	_animar(true)
	var h: BolsaUI.Hueco = hueco(_sel) if pestana == INDICE_INVENTARIO else null
	if h != null and h.id != "":
		h.pop()                                     # M1: el hueco elegido entra con un pop


func cerrar() -> void:
	if not abierta:
		return
	var era_misiones: bool = pestana == INDICE_MISIONES
	abierta = false
	if _pausado_por_mi and is_inside_tree():
		get_tree().paused = false
	_pausado_por_mi = false
	if is_inside_tree():
		if era_misiones:
			Sfx.play_ui("libro_cierra")
		else:
			Sfx.play_ui("bolsa", INF, 0.85)
	_animar(false)


## ¿Está abierto el libro de hechizos? (lo dice el lanzador; sin él, por ejemplo en las pruebas sueltas, no).
func _libro_abierto() -> bool:
	if not is_inside_tree():
		return false
	var lanz: Node = get_tree().get_first_node_in_group("spellcaster")
	return lanz != null and lanz.has_method("libro_abierto") and bool(lanz.call("libro_abierto"))


func cambiar_pestana(i: int) -> void:
	var n: int = PESTANAS.size()
	var antes: int = pestana
	pestana = ((i % n) + n) % n
	_mostrar_pagina()
	if pestana != antes and abierta and is_inside_tree():
		Sfx.play_ui("pagina", DB_PAGINA)            # M2
		_entrada_pagina(1.0 if pestana > antes else -1.0)


## M2: el contenido de la pestaña nueva entra desde `DESPLAZ_PAGINA_PX` px al lado de donde viene (`dir` > 0: llega por la derecha).
func _entrada_pagina(dir: float) -> void:
	if _tw_pagina != null and _tw_pagina.is_valid():
		_tw_pagina.kill()
	_cuerpo.position = CUERPO_POS
	_cuerpo.modulate.a = 1.0
	if not Sensacion3D.ACTIVA:
		return
	_cuerpo.position.x = CUERPO_POS.x + DESPLAZ_PAGINA_PX * dir
	_cuerpo.modulate.a = 0.4
	_tw_pagina = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	_tw_pagina.tween_property(_cuerpo, "position:x", CUERPO_POS.x, T_PAGINA_S).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tw_pagina.tween_property(_cuerpo, "modulate:a", 1.0, T_PAGINA_S)


func siguiente_pestana(paso: int) -> void:
	cambiar_pestana(pestana + paso)


func _mostrar_pagina() -> void:
	if _pag_inv == null:
		return
	_pag_inv.visible = pestana == INDICE_INVENTARIO
	if _pag_vest != null:
		_pag_vest.visible = pestana == INDICE_VESTUARIO
		if _pag_vest.visible:
			_pag_vest.queue_redraw()
	_pag_mis.visible = pestana == INDICE_MISIONES
	if _pag_mapa != null:
		_pag_mapa.visible = pestana == INDICE_MAPA
		if _pag_mapa.visible:
			_pag_mapa.queue_redraw()
	if _pag_est != null:
		_pag_est.visible = pestana == INDICE_ESTADISTICAS
		if _pag_est.visible:
			_refrescar_estadisticas()
	_pag_prox.visible = not funcional(pestana)
	_fondo.queue_redraw()
	_barra.queue_redraw()
	_pag_prox.queue_redraw()


func _colocar() -> Vector2:
	if _marco == null:
		return Vector2.ZERO
	var vista: Vector2 = get_viewport().get_visible_rect().size
	var escala: float = minf(1.0, minf((vista.x - 16.0) / ANCHO, (vista.y - 16.0) / ALTO))
	_marco.scale = Vector2(escala, escala)
	_marco.pivot_offset = Vector2.ZERO
	var reposo: Vector2 = ((vista - Vector2(ANCHO, ALTO) * escala) * 0.5).round()
	if abierta and (_tween == null or not _tween.is_running()):
		_marco.position = reposo
	return reposo


func _animar(abre: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var reposo: Vector2 = _colocar()
	_tween = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	if abre:
		_marco.visible = true
		_velo.visible = true
		_velo.mouse_filter = Control.MOUSE_FILTER_STOP
		_marco.mouse_filter = Control.MOUSE_FILTER_PASS
		_marco.position = reposo + Vector2(0.0, SUBIDA_PX)
		_marco.modulate.a = 0.0
		_velo.color.a = 0.0
		_tween.tween_property(_marco, "position", reposo, T_ABRIR_S).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_marco, "modulate:a", 1.0, T_ABRIR_S * 0.7)
		_tween.tween_property(_velo, "color:a", ALPHA_VELO, T_ABRIR_S)
	else:
		_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tween.tween_property(_marco, "position", reposo + Vector2(0.0, SUBIDA_PX), T_CERRAR_S).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		_tween.tween_property(_marco, "modulate:a", 0.0, T_CERRAR_S)
		_tween.tween_property(_velo, "color:a", 0.0, T_CERRAR_S)
		_tween.chain().tween_callback(_ocultar)


func _ocultar() -> void:
	if abierta:
		return
	_marco.visible = false
	_velo.visible = false


## --- Teclado ---

func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or k.alt_pressed or k.ctrl_pressed or k.meta_pressed:
		return
	if k.is_action("mochila"):
		get_viewport().set_input_as_handled()
		if abierta and pestana != INDICE_INVENTARIO:
			cambiar_pestana(INDICE_INVENTARIO)
		else:
			alternar()
	elif k.is_action("misiones"):
		get_viewport().set_input_as_handled()
		if abierta and pestana != INDICE_MISIONES:
			cambiar_pestana(INDICE_MISIONES)
		elif abierta:
			cerrar()
		else:
			abrir(INDICE_MISIONES)
	elif not abierta:
		return
	elif k.is_action("pausa"):
		get_viewport().set_input_as_handled()
		cerrar()
	elif k.is_action("pestana_anterior") or k.keycode == KEY_PAGEUP:
		get_viewport().set_input_as_handled()
		siguiente_pestana(-1)
	elif k.is_action("pestana_siguiente") or k.keycode == KEY_PAGEDOWN:
		get_viewport().set_input_as_handled()
		siguiente_pestana(1)
	elif k.keycode == KEY_UP:
		get_viewport().set_input_as_handled()
		mover(Vector2.UP)
	elif k.keycode == KEY_DOWN:
		get_viewport().set_input_as_handled()
		mover(Vector2.DOWN)
	elif k.keycode == KEY_LEFT:
		get_viewport().set_input_as_handled()
		mover(Vector2.LEFT)
	elif k.keycode == KEY_RIGHT:
		get_viewport().set_input_as_handled()
		mover(Vector2.RIGHT)
	elif k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER or k.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		accion()


## Flechas: en Inventario mueven la elección por la rejilla (solo entre objetos que hay); en Misiones ↑↓ cambian de misión.
func mover(dir: Vector2) -> void:
	if pestana == INDICE_VESTUARIO:
		if dir.x != 0.0 and _pag_vest != null:
			_pag_vest.mover(1 if dir.x > 0.0 else -1)
		return
	if pestana == INDICE_MISIONES:
		if dir.y != 0.0 and _diario != null:
			_diario.mover(1 if dir.y > 0.0 else -1)
		return
	if pestana != INDICE_INVENTARIO or _pilas.is_empty():
		return
	if _sel < 0:
		_elegir(0)
		return
	var f: int = _sel / COLUMNAS
	var c: int = _sel % COLUMNAS
	var destino: int = _sel
	if dir.x < 0.0 and c > 0:
		destino = _sel - 1
	elif dir.x > 0.0 and c < COLUMNAS - 1 and _sel + 1 < _pilas.size():
		destino = _sel + 1
	elif dir.y < 0.0 and f > 0:
		destino = _sel - COLUMNAS
	elif dir.y > 0.0 and _sel + COLUMNAS < _pilas.size():
		destino = _sel + COLUMNAS
	elif dir.y > 0.0 and f < (_pilas.size() - 1) / COLUMNAS:
		destino = _pilas.size() - 1                 # la fila de abajo está a medias: baja al último
	_elegir(destino)


## Enter / Espacio / segundo clic: en Inventario, equipa el consumible elegido (o, si ya es el equipado, cierra el menú y lo usa); en Misiones sigue la misión.
func accion() -> void:
	if pestana == INDICE_VESTUARIO:
		if _pag_vest != null:
			_pag_vest.ponerse()
		return
	if pestana == INDICE_MISIONES:
		if _diario != null:
			_diario.alternar_seguida()
		return
	var d: Dictionary = detalle()
	if d.is_empty():
		return
	if Atuendos.es_atuendo(String(d["id"])):
		# 12/11: un atuendo de la mochila se pone desde aquí también (lo mismo que en Vestuario).
		if ponerse_atuendo(String(d["id"])):
			var ha: BolsaUI.Hueco = hueco(_sel)
			if ha != null:
				ha.pop()
		return
	if not Objetos.es_consumible(String(d["id"])):
		# M3: un material o un objeto clave no se equipa: «no puedes» y el hueco tiembla.
		Sfx.play_ui("no_puedes_ui", DB_NO_PUEDES)
		var hm: BolsaUI.Hueco = hueco(_sel)
		if hm != null:
			hm.temblar()
		return
	var hud: Node = get_tree().get_first_node_in_group("hud_eow") if is_inside_tree() else null
	if bool(d["equipado"]):
		cerrar()
		if hud != null and hud.has_method("usar_equipado"):
			hud.call_deferred("usar_equipado")      # con el árbol ya reanudado (el menú pausaba)
	else:
		if _consumibles.equipar(String(d["id"])):   # (esto emite Estado.cambiado: el refresco actualiza los mismos huecos, no los recrea)
			Sfx.play_ui("ui_equipar")
			var he: BolsaUI.Hueco = hueco(_sel)
			if he != null:
				he.pop()
			if hud != null and hud.has_method("destello_equipado"):
				hud.call("destello_equipado")


## --- Inventario ---

func _al_cambiar_mochila() -> void:
	if abierta:
		_refrescar()


## M3: los 20 huecos se crean UNA vez (`_crear_huecos`) y aquí solo se les cambia el objeto, la cantidad y el bloqueo: así un hueco puede animarse (pop, brillo, temblor)
## sin que el siguiente refresco lo destruya. `animar` = false al abrir el menú (nada de lo que llegó con él cerrado cuenta como nuevo).
func _refrescar(animar: bool = true) -> void:
	if _rejilla == null:
		return
	var e: Estado = Estado.i()
	_poner_oro(e.oro, animar)
	_pie_huecos.text = "%d/%d huecos" % [e.huecos_usados(), e.capacidad]
	var id_elegido: String = String(_pilas[_sel][0]) if _sel >= 0 and _sel < _pilas.size() else ""
	_pilas = BolsaUI.ordenar(e.items)
	if _huecos.is_empty():
		_crear_huecos()
	for i in range(_huecos.size()):
		var h: BolsaUI.Hueco = _huecos[i]
		h.bloqueado = i >= e.capacidad
		if i < _pilas.size() and not h.bloqueado:
			h.id = String(_pilas[i][0])
			h.cantidad = int(_pilas[i][1])
			h.cura = Objetos.cura(h.id)
		else:
			h.id = ""
			h.cantidad = 0
			h.cura = false
		h.tooltip_text = "Hueco bloqueado: el alquimista puede ampliar la mochila" if h.bloqueado else ""
		h.refrescar_datos()
	# La elección sigue en su objeto si aún está; si no, en el primero (o en ninguno).
	var nuevo: int = -1
	if id_elegido != "":
		for i in range(_pilas.size()):
			if String(_pilas[i][0]) == id_elegido:
				nuevo = i
				break
	if nuevo < 0 and not _pilas.is_empty():
		nuevo = clampi(_sel, 0, _pilas.size() - 1) if _sel >= 0 else 0
	if not animar:
		_anillo_colocado = false                        # al abrir el aro aparece donde toca, sin deslizarse desde donde se quedó
	_elegir(nuevo, false)
	# M5: el objeto que ha llegado con el menú abierto (id nuevo o más cantidad que antes) hace pop y brilla en su hueco.
	if animar:
		for id in e.items.keys():
			if int(e.items[id]) > int(_cuentas.get(id, 0)):
				for i in range(_pilas.size() - 1, -1, -1):
					if String(_pilas[i][0]) == String(id) and i < _huecos.size() and not (_huecos[i] as BolsaUI.Hueco).bloqueado:
						(_huecos[i] as BolsaUI.Hueco).pop()
						(_huecos[i] as BolsaUI.Hueco).brillar(T_BRILLO_NUEVO_S)
						break
	_cuentas = e.items.duplicate()


## Los 20 huecos y el aro dorado que se desliza por encima (M2).
func _crear_huecos() -> void:
	for i in range(COLUMNAS * FILAS):
		var h := BolsaUI.Hueco.new()
		h.tam = TAM_HUECO
		h.indice = i
		h.sin_aro = true
		h.pulsado = func(_id: String) -> void: _clic(i)
		h.al_pasar = _elegir
		h.size = Vector2(TAM_HUECO, TAM_HUECO)
		h.position = Vector2(float(i % COLUMNAS), float(i / COLUMNAS)) * (TAM_HUECO + SEP_HUECO)
		_rejilla.add_child(h)
		_huecos.append(h)
	_anillo = Anillo.new()
	_anillo.size = Vector2(TAM_HUECO, TAM_HUECO)
	_anillo.visible = false
	_rejilla.add_child(_anillo)                         # el último hijo: se pinta por encima de los huecos


## M5: el contador de oro cuenta hacia el valor nuevo en `T_ORO_S` s y hace pop; `moneda` al subir (el sonido suena aunque la sensación esté apagada).
func _poner_oro(valor: int, animar: bool) -> void:
	if _tw_oro != null and _tw_oro.is_valid():
		_tw_oro.kill()
	var desde: int = _oro_valor
	_oro_valor = valor
	if not animar or valor == desde:
		_oro.text = str(valor)
		return
	if valor > desde:
		Sfx.play_ui("moneda")
	if not Sensacion3D.ACTIVA:
		_oro.text = str(valor)
		return
	_oro.pivot_offset = _oro.size * 0.5
	_oro.scale = Vector2.ONE * POP_ORO
	_tw_oro = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	_tw_oro.tween_method(func(v: float) -> void: _oro.text = str(int(round(v))), float(desde), float(valor), T_ORO_S)
	_tw_oro.tween_property(_oro, "scale", Vector2.ONE, T_ORO_S).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw_oro.chain().tween_callback(func() -> void: _oro.text = str(valor))


func _clic(i: int) -> void:
	if i == _sel:
		accion()
	else:
		_elegir(i)


## Elige el hueco `i` (flechas, ratón o refresco). `sonar` = false cuando lo hace el refresco: el tic es solo para cuando el jugador cambia de hueco (M2).
func _elegir(i: int, sonar: bool = true) -> void:
	if i >= _pilas.size():
		i = _sel
	var cambia: bool = i != _sel
	_sel = i
	for k in range(_huecos.size()):
		var h: BolsaUI.Hueco = _huecos[k]
		var ahora: bool = k == _sel and h.id != ""
		if h.elegido != ahora:
			h.elegido = ahora
			h.queue_redraw()
	_mover_anillo()
	if cambia and sonar and abierta:
		Sfx.play_ui("ui_tick")
	if _detalle != null:
		_detalle.mostrar(detalle())


## El aro dorado va al hueco elegido: se desliza en `T_ANILLO_S` s desde donde estaba (de golpe la primera vez, o con la sensación apagada).
func _mover_anillo() -> void:
	if _anillo == null:
		return
	var h: BolsaUI.Hueco = hueco(_sel)
	var ver: bool = h != null and h.id != ""
	if _tw_anillo != null and _tw_anillo.is_valid():
		_tw_anillo.kill()
	_anillo.visible = ver
	if not ver:
		_anillo_colocado = false
		return
	if _anillo_colocado and Sensacion3D.ACTIVA and not _anillo.position.is_equal_approx(h.position):
		_tw_anillo = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_tw_anillo.tween_property(_anillo, "position", h.position, T_ANILLO_S).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_anillo.position = h.position
	_anillo_colocado = true


## --- Piezas de dibujo ---

## El aro dorado del hueco elegido (M2): un control suelto sobre la rejilla, para poder deslizarlo de un hueco al siguiente.
class Anillo extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_polyline(BolsaUI.camino(r.grow(-0.5), clampf(size.x * 0.14, 5.0, 10.0)), BolsaUI.COLOR_ELEGIDO, 3.0, true)


## LA PÁGINA DEL VESTUARIO (12/11): una carta por atuendo (`Atuendos.ids`, en el orden de la tabla), centradas. Cada carta: el icono grande del atuendo
## (`arte/iconos/<id>.png` por `Objetos.dibujar`; velado si no se tiene), el nombre, sus prendas (los nombres de ropa.json) y, abajo, «Puesto» (verde),
## «Lo tienes» o «No lo tienes · lo vende la librera». La elegida va en ámbar, como las filas de la tienda. Un clic elige; otro sobre la elegida, se lo pone.
class PaginaVestuario extends Control:
	const CARTA: Vector2 = Vector2(228.0, 300.0)
	const SEP: float = 24.0
	const RADIO_ICONO: float = 46.0
	const AMBAR: Color = Color("f2c97a")
	const AMBAR_BORDE: Color = Color("c9963f")
	const FILA: Color = Color("f6eedb")
	const VERDE: Color = Color("4f7a34")
	var menu: MenuPestanas
	var sel: int = 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func ids() -> Array:
		return Atuendos.ids()

	func id_elegido() -> String:
		var l: Array = ids()
		return String(l[sel]) if sel >= 0 and sel < l.size() else ""

	func mover(d: int) -> void:
		var n: int = ids().size()
		if n == 0:
			return
		var nuevo: int = clampi(sel + d, 0, n - 1)
		if nuevo != sel:
			sel = nuevo
			Sfx.play_ui("ui_tick")
			queue_redraw()

	func ponerse() -> bool:
		return menu.ponerse_atuendo(id_elegido()) if menu != null else false

	func rect_carta(i: int, n: int) -> Rect2:
		var ancho: float = float(n) * CARTA.x + float(n - 1) * SEP
		var x0: float = (size.x - ancho) * 0.5
		return Rect2(Vector2(x0 + float(i) * (CARTA.x + SEP), (size.y - CARTA.y) * 0.5), CARTA)

	func _gui_input(ev: InputEvent) -> void:
		var mb := ev as InputEventMouseButton
		if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var l: Array = ids()
		for i in l.size():
			if rect_carta(i, l.size()).has_point(mb.position):
				accept_event()
				if i == sel:
					ponerse()
				else:
					sel = i
					Sfx.play_ui("ui_tick")
					queue_redraw()
				return

	func _draw() -> void:
		var f: Font = TemaInterfaz.fuente()
		var l: Array = ids()
		if l.is_empty():
			draw_string(f, Vector2(0.0, 40.0), "No hay atuendos", HORIZONTAL_ALIGNMENT_CENTER, size.x, 17, MenuPestanas.TINTA_SUAVE)
			return
		var pj: Node = Atuendos.pj_de(get_tree()) if is_inside_tree() else null
		var puesto: String = Atuendos.puesto(pj)
		for i in l.size():
			var id: String = String(l[i])
			var r: Rect2 = rect_carta(i, l.size())
			var tiene: bool = Atuendos.tiene(id)
			var es_sel: bool = i == sel
			BolsaUI._caja(AMBAR if es_sel else FILA, AMBAR_BORDE if es_sel else BolsaUI.LINEA, 2 if es_sel else 1, 12).draw(get_canvas_item(), r)
			var cx: float = r.position.x + r.size.x * 0.5
			var imagen: Texture2D = Objetos.icono(id, 160.0)       # la jugadora vestida, sin el aro de calidad (es una imagen, no un icono)
			if imagen != null:
				draw_texture_rect(imagen, Rect2(Vector2(cx - 80.0, r.position.y + 14.0), Vector2(160.0, 160.0)), false)
			else:
				Objetos.dibujar(self, id, Vector2(cx, r.position.y + 96.0), RADIO_ICONO)
			if not tiene:
				# velado: no se tiene
				draw_rect(Rect2(r.position + Vector2(6.0, 6.0), Vector2(r.size.x - 12.0, 176.0)), Color(FILA, 0.62), true)
			draw_string(f, Vector2(r.position.x, r.position.y + 198.0), Objetos.nombre(id), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, MenuPestanas.TINTA)
			var y: float = r.position.y + 222.0
			for p in Atuendos.prendas(id):
				var nombre: String = String(Ropa3D.datos_de(String(p)).get("nombre", p))
				draw_string(f, Vector2(r.position.x + 18.0, y), "· " + nombre, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 36.0, 13, MenuPestanas.TINTA_SUAVE)
				y += 17.0
			var estado: String
			var col: Color
			if id == puesto:
				estado = "Puesto"
				col = VERDE
			elif tiene:
				estado = "Lo tienes"
				col = MenuPestanas.TINTA
			else:
				var v: String = Atuendos.vendedor(id)
				estado = "No lo tienes" + ("  ·  lo vende la %s" % String(TiendaUI.NOMBRES.get(v, v)).to_lower() if v != "" else "")
				col = MenuPestanas.TINTA_SUAVE
			draw_string(f, Vector2(r.position.x, r.end.y - 14.0), estado, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, col)


## El marco del menú: cuero con costura, interior de pergamino, y el título de la pestaña.
class Fondo extends Control:
	var menu: MenuPestanas

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		BolsaUI._caja(BolsaUI.CUERO, BolsaUI.CUERO_SOMBRA, 3, 24).draw(get_canvas_item(), r)
		BolsaUI._caja(BolsaUI.PERGAMINO, BolsaUI.LINEA, 2, 14).draw(get_canvas_item(), r.grow(-20.0))
		BolsaUI.discontinuo(self, BolsaUI.camino(r.grow(-8.0), 18.0), BolsaUI.COSTURA, 2.0, 7.0, 5.0)
		if menu == null:
			return
		var f: Font = TemaInterfaz.fuente()
		var p: Dictionary = MenuPestanas.PESTANAS[menu.pestana]
		draw_string(f, Vector2(48.0, 62.0), String(p["nombre"]), HORIZONTAL_ALIGNMENT_LEFT, size.x - 96.0, 30, MenuPestanas.TINTA)
		draw_string(f, Vector2(50.0, 80.0), String(p["sub"]), HORIZONTAL_ALIGNMENT_LEFT, size.x - 96.0, 14, MenuPestanas.TINTA_SUAVE)
		draw_string(f, Vector2(0.0, size.y - 34.0), menu.pista(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, MenuPestanas.TINTA_SUAVE)


## La fila de pestañas: icono y nombre de cada una, la elegida levantada con filete dorado, y las plaquitas Q / E de los extremos (los L1 / R1).
class BarraPestanas extends Control:
	const MARGEN_PX: float = 38.0
	var menu: MenuPestanas
	var _encima: int = -1

	func _init() -> void:
		mouse_exited.connect(func() -> void:
			_encima = -1
			queue_redraw())

	func _ancho_pestana() -> float:
		return (size.x - MARGEN_PX * 2.0) / float(MenuPestanas.PESTANAS.size())

	func _indice_en(x: float) -> int:
		var i: int = int((x - MARGEN_PX) / _ancho_pestana())
		return i if x >= MARGEN_PX and i < MenuPestanas.PESTANAS.size() else -1

	func _draw() -> void:
		if menu == null:
			return
		var f: Font = TemaInterfaz.fuente()
		var w: float = _ancho_pestana()
		draw_line(Vector2(0.0, size.y - 1.0), Vector2(size.x, size.y - 1.0), BolsaUI.LINEA, 1.5)
		_plaquita(f, Vector2(15.0, size.y * 0.5 - 4.0), "Q")
		_plaquita(f, Vector2(size.x - 15.0, size.y * 0.5 - 4.0), "E")
		for i in range(MenuPestanas.PESTANAS.size()):
			var r := Rect2(Vector2(MARGEN_PX + float(i) * w + 3.0, 2.0), Vector2(w - 6.0, size.y - 3.0))
			var elegida: bool = i == menu.pestana
			if elegida:
				var caja := BolsaUI._caja(BolsaUI.PERGAMINO_CLARO, MenuPestanas.DORADO, 3, 11)
				caja.shadow_color = Color(0.9, 0.7, 0.2, 0.35)
				caja.shadow_size = 6
				caja.draw(get_canvas_item(), r)
			elif i == _encima:
				BolsaUI._caja(Color(BolsaUI.PERGAMINO_CLARO, 0.6), Color(BolsaUI.LINEA, 0.5), 1, 11).draw(get_canvas_item(), r)
			var col: Color = MenuPestanas.TINTA if elegida else Color(0.31, 0.23, 0.15, 0.78 if menu.funcional(i) else 0.5)
			MenuPestanas.icono(self, String((MenuPestanas.PESTANAS[i] as Dictionary)["id"]), Vector2(r.position.x + w * 0.5 - 3.0, r.position.y + 21.0), 11.0, col,
				BolsaUI.PERGAMINO_CLARO if elegida else BolsaUI.PERGAMINO)
			draw_string(f, Vector2(r.position.x, r.position.y + 50.0), String((MenuPestanas.PESTANAS[i] as Dictionary)["nombre"]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, col)

	func _plaquita(f: Font, c: Vector2, letra: String) -> void:
		var caja := BolsaUI._caja(BolsaUI.CUERO, BolsaUI.CUERO_SOMBRA, 2, 8)
		var r := Rect2(c - Vector2(14.0, 11.0), Vector2(28.0, 22.0))
		caja.draw(get_canvas_item(), r)
		draw_string(f, Vector2(r.position.x, r.position.y + 17.0), letra, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, BolsaUI.PERGAMINO)

	func _gui_input(event: InputEvent) -> void:
		var mm := event as InputEventMouseMotion
		if mm != null:
			var j: int = _indice_en(mm.position.x)
			if j != _encima:
				_encima = j
				queue_redraw()
			return
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and menu != null:
			var i: int = _indice_en(mb.position.x)
			if i >= 0:
				menu.cambiar_pestana(i)
			elif mb.position.x < MARGEN_PX:
				menu.siguiente_pestana(-1)
			else:
				menu.siguiente_pestana(1)


## El panel de detalle del Inventario: icono grande con marco, nombre, tipo y calidad, descripción y «Usos conocidos».
class Detalle extends Control:
	const LADO_ICONO_PX: float = 88.0
	var menu: MenuPestanas
	var _icono: Control
	var _nombre: Label
	var _tipo: Label
	var _desc: Label
	var _titulo_usos: Label
	var _usos: Label
	var _pista: Label
	var _vacio: Label
	var _id_mostrado: String = ""
	var _tw_icono: Tween = null
	var _y_linea: float = 214.0                  ## B4: dónde cae la línea sobre «Usos conocidos» (baja si la descripción ocupa más de dos líneas)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ancho: float = size.x - 36.0
		_icono = IconoGrande.new()
		_icono.size = Vector2(LADO_ICONO_PX, LADO_ICONO_PX)
		_icono.position = Vector2((size.x - LADO_ICONO_PX) * 0.5, 12.0)
		add_child(_icono)
		_nombre = _texto(ancho, 24, 108.0)
		_nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tipo = _texto(ancho, 14, 138.0)
		_tipo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_desc = _texto(ancho, 15, 172.0)
		_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_titulo_usos = _texto(ancho, 15, 222.0)
		_titulo_usos.text = "Usos conocidos"
		_usos = _texto(ancho, 14, 246.0)
		_usos.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_pista = _texto(ancho, 13, size.y - 26.0)
		_pista.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_vacio = _texto(ancho, 16, size.y * 0.5 - 20.0)
		_vacio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_vacio.text = "Tu mochila está vacía.\nRecoge materiales por el mundo."
		_vacio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mostrar(menu.detalle() if menu != null else {})

	func _texto(ancho: float, cuerpo: int, y: float) -> Label:
		var l: Label = BolsaUI._etiqueta(cuerpo)
		l.position = Vector2(18.0, y)
		l.size = Vector2(ancho, 24.0)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		return l

	func mostrar(d: Dictionary) -> void:
		if _icono == null:
			return
		var hay: bool = not d.is_empty()
		for n in [_icono, _nombre, _tipo, _desc, _titulo_usos, _usos, _pista]:
			(n as CanvasItem).visible = hay
		_vacio.visible = not hay
		queue_redraw()
		if not hay:
			_id_mostrado = ""
			return
		if String(d["id"]) != _id_mostrado:
			_id_mostrado = String(d["id"])
			if _tw_icono != null and _tw_icono.is_valid():
				_tw_icono.kill()
			_icono.modulate.a = 1.0
			if Sensacion3D.ACTIVA and is_inside_tree() and menu != null and menu.abierta:
				_icono.modulate.a = 0.0                # M2: el icono del detalle funde al cambiar de objeto
				_tw_icono = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
				_tw_icono.tween_property(_icono, "modulate:a", 1.0, MenuPestanas.T_FUNDIDO_ICONO_S)
		_icono.set("id", String(d["id"]))
		_icono.set("calidad", String(d["calidad"]))
		_icono.queue_redraw()
		_nombre.text = String(d["nombre"])
		_tipo.text = String(d["tipo"]) + ("  ·  Equipado" if bool(d["equipado"]) else "")
		_tipo.add_theme_color_override("font_color", MenuPestanas.color_tipo(String(d["calidad"])))
		_desc.text = String(d["desc"])
		_desc.size.y = 24.0
		# B4: las descripciones nuevas son de 1-2 frases y ocupan más de una línea: «Usos conocidos» y su línea bajan lo que haga falta.
		var alto_desc: float = maxf(_desc.get_minimum_size().y, 24.0)
		_y_linea = maxf(214.0, _desc.position.y + alto_desc + 10.0)
		_titulo_usos.position.y = _y_linea + 8.0
		_usos.position.y = _y_linea + 32.0
		var usos: Array = d["usos"]
		if usos.is_empty():
			_usos.text = "Aún no se le conoce ningún uso."
			_usos.add_theme_color_override("font_color", MenuPestanas.TINTA_SUAVE)
		else:
			var lineas: PackedStringArray = []
			for u in usos:
				lineas.append("◆  " + String(u))
			_usos.text = "\n".join(lineas)
			_usos.add_theme_color_override("font_color", MenuPestanas.TINTA)
		_usos.size.y = 24.0
		if Objetos.es_consumible(String(d["id"])):
			_pista.text = "Equipado: Q lo usa  ·  [Enter] usar ahora" if bool(d["equipado"]) else "[Enter] equipar (Q lo usará)"
		else:
			_pista.text = ""

	func _draw() -> void:
		BolsaUI._caja(BolsaUI.PERGAMINO_CLARO, BolsaUI.LINEA, 2, 12).draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
		if _icono != null and _icono.visible:
			draw_line(Vector2(24.0, _y_linea), Vector2(size.x - 24.0, _y_linea), Color(BolsaUI.LINEA, 0.55), 1.5)


## El icono del objeto en grande: placa oscura redondeada, el icono dibujado a tamaño y el marco de su calidad (y el brillo animado de épico y legendario).
class IconoGrande extends Control:
	var id: String = ""
	var calidad: String = Objetos.CALIDAD_COMUN

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		if MarcoCalidad.anima(calidad) and visible:
			queue_redraw()

	func _draw() -> void:
		if id == "":
			return
		var r := Rect2(Vector2.ZERO, size)
		var placa := StyleBoxFlat.new()
		placa.bg_color = Color(0.07, 0.06, 0.11, 0.95)
		placa.set_corner_radius_all(int(MarcoCalidad.RADIO_PX) + 2)
		placa.anti_aliasing = true
		placa.draw(get_canvas_item(), r.grow(-MarcoCalidad.INSET))
		Objetos.dibujar(self, id, size * 0.5 + Vector2(0.0, -2.0), size.x * 0.27)
		MarcoCalidad.dibujar(self, r, calidad)


## «Próximamente» de las pestañas que aún no funcionan: el icono grande y apagado, un rótulo y lo que traerá.
class Proximamente extends Control:
	var menu: MenuPestanas

	func _draw() -> void:
		if menu == null or menu.funcional(menu.pestana):
			return
		var d: Dictionary = MenuPestanas.PESTANAS[menu.pestana]
		var f: Font = TemaInterfaz.fuente()
		var c := Vector2(size.x * 0.5, size.y * 0.36)
		# Medallón: dos aros y un filete discontinuo alrededor del icono.
		draw_circle(c, 70.0, Color(BolsaUI.PERGAMINO_CLARO, 0.9))
		draw_arc(c, 70.0, 0.0, TAU, 48, Color(MenuPestanas.DORADO, 0.8), 3.0, true)
		draw_arc(c, 62.0, 0.0, TAU, 48, Color(BolsaUI.LINEA, 0.55), 1.5, true)
		MenuPestanas.icono(self, String(d["id"]), c, 36.0, Color(0.31, 0.23, 0.15, 0.6), BolsaUI.PERGAMINO_CLARO)
		draw_string(f, Vector2(0.0, c.y + 112.0), "Próximamente", HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, MenuPestanas.DORADO.darkened(0.15))
		draw_string(f, Vector2(80.0, c.y + 142.0), String(d.get("prox", "")), HORIZONTAL_ALIGNMENT_CENTER, size.x - 160.0, 15, MenuPestanas.TINTA)


## Icono de pestaña dibujado en código (`tipo` = id de la pestaña), centrado en `p`, de radio `r`. `fondo` es el color del papel (para los huecos del dibujo).
static func icono(c: CanvasItem, tipo: String, p: Vector2, r: float, col: Color, fondo: Color) -> void:
	match tipo:
		"inventario":
			c.draw_circle(p + Vector2(0.0, r * 0.25), r * 0.78, col)
			c.draw_rect(Rect2(p + Vector2(-r * 0.3, -r * 0.8), Vector2(r * 0.6, r * 0.5)), col)
			c.draw_line(p + Vector2(-r * 0.45, -r * 0.5), p + Vector2(r * 0.45, -r * 0.5), fondo, maxf(1.0, r * 0.14), true)
			c.draw_arc(p + Vector2(0.0, r * 0.3), r * 0.36, PI * 0.15, PI * 0.85, 8, fondo, maxf(1.0, r * 0.14), true)
		"grimorio":
			var izq := PackedVector2Array([p + Vector2(-r, -r * 0.55), p + Vector2(-r * 0.06, -r * 0.3), p + Vector2(-r * 0.06, r * 0.75), p + Vector2(-r, r * 0.5)])
			var der := PackedVector2Array([p + Vector2(r, -r * 0.55), p + Vector2(r * 0.06, -r * 0.3), p + Vector2(r * 0.06, r * 0.75), p + Vector2(r, r * 0.5)])
			c.draw_colored_polygon(izq, col)
			c.draw_colored_polygon(der, col)
			for k in range(3):
				var yy: float = -r * 0.05 + float(k) * r * 0.26
				c.draw_line(p + Vector2(-r * 0.78, yy - r * 0.08), p + Vector2(-r * 0.3, yy + r * 0.04), fondo, maxf(1.0, r * 0.1), true)
				c.draw_line(p + Vector2(r * 0.78, yy - r * 0.08), p + Vector2(r * 0.3, yy + r * 0.04), fondo, maxf(1.0, r * 0.1), true)
		"sintesis":
			var matraz := PackedVector2Array([p + Vector2(-r * 0.22, -r * 0.85), p + Vector2(r * 0.22, -r * 0.85), p + Vector2(r * 0.22, -r * 0.2),
				p + Vector2(r * 0.85, r * 0.75), p + Vector2(-r * 0.85, r * 0.75), p + Vector2(-r * 0.22, -r * 0.2)])
			c.draw_colored_polygon(matraz, col)
			c.draw_line(p + Vector2(-r * 0.4, r * 0.2), p + Vector2(r * 0.4, r * 0.2), fondo, maxf(1.0, r * 0.12), true)
			c.draw_circle(p + Vector2(-r * 0.12, r * 0.45), r * 0.1, fondo)
			c.draw_circle(p + Vector2(r * 0.22, r * 0.38), r * 0.07, fondo)
		"mapa":
			var hoja := PackedVector2Array([p + Vector2(-r, -r * 0.6), p + Vector2(-r * 0.33, -r * 0.4), p + Vector2(r * 0.33, -r * 0.6), p + Vector2(r, -r * 0.4),
				p + Vector2(r, r * 0.6), p + Vector2(r * 0.33, r * 0.4), p + Vector2(-r * 0.33, r * 0.6), p + Vector2(-r, r * 0.4)])
			c.draw_colored_polygon(hoja, col)
			c.draw_line(p + Vector2(-r * 0.33, -r * 0.4), p + Vector2(-r * 0.33, r * 0.6), fondo, maxf(1.0, r * 0.1), true)
			c.draw_line(p + Vector2(r * 0.33, -r * 0.6), p + Vector2(r * 0.33, r * 0.4), fondo, maxf(1.0, r * 0.1), true)
			c.draw_circle(p + Vector2(r * 0.6, -r * 0.05), r * 0.14, fondo)
		"misiones":
			c.draw_rect(Rect2(p + Vector2(-r * 0.65, -r * 0.9), Vector2(r * 1.3, r * 1.8)), col)
			for k in range(3):
				c.draw_line(p + Vector2(-r * 0.4, -r * 0.45 + float(k) * r * 0.45), p + Vector2(r * 0.4, -r * 0.45 + float(k) * r * 0.45), fondo, maxf(1.0, r * 0.12), true)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(r * 0.3, -r * 0.9), p + Vector2(r * 0.65, -r * 0.55), p + Vector2(r * 0.3, -r * 0.55)]), fondo)
		"estadisticas":
			for k in range(3):                       # tres barras de alturas distintas sobre una línea base
				var alto: float = r * (0.7 + 0.55 * float(k))
				c.draw_rect(Rect2(p + Vector2(-r * 0.85 + float(k) * r * 0.62, r * 0.8 - alto), Vector2(r * 0.46, alto)), col)
			c.draw_line(p + Vector2(-r, r * 0.85), p + Vector2(r, r * 0.85), col, maxf(1.0, r * 0.14), true)
		"ajustes":
			var dientes := PackedVector2Array()
			for k in range(16):
				var a: float = TAU * float(k) / 16.0
				var rr: float = r if (k / 2) % 2 == 0 else r * 0.74
				dientes.append(p + Vector2(cos(a), sin(a)) * rr)
			c.draw_colored_polygon(dientes, col)
			c.draw_circle(p, r * 0.34, fondo)
