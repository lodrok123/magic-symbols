class_name LibroRojo
extends Control

## LIBRO ROJO · LIBRO DE PRUEBA (22/11, sesión HECHIZOS; docs/PROPUESTA_LIBRO_ROJO_Y_TRANSICIONES_2026-11-22.md, §17 y PLAN_HECHIZOS §6.5).
## Pablo: «implementa un libro de prueba para probar». Es un libro SEPARADO: no sustituye a `spellbook.gd` ni toca los libros «bosque» y «avanzado». Se abre con L en
## `laboratorios/LabLibroRojo.tscn` y escribe en las MISMAS páginas del lanzador (`Grimorio`): el reconocimiento (`add_gesture`), el guardado y lo que se lanza con 1/2/3 son
## los de siempre, el mismo `Hechizo`.
##   · Página IZQUIERDA: una sola zona para trazar. Dice qué círculo y qué hueco se rellena, enseña la GUÍA tenue de la familia que se espera y, si se elige un símbolo
##     en el catálogo, su gesto animado para practicar (sin inscribirlo).
##   · Página DERECHA: el conjuro entero. Doble contorno = una manifestación. A: un sello y su corona (3 → 6 huecos). B: dos sellos en el MISMO contorno (la combinación del
##     libro avanzado: `element2`, `CombosSellos`), con su transición de ~0,75 s. C (anidación, H12): principal e hijo con contornos propios y una condición; EDITABLE
##     (sello y glifos del hijo, condición, 6 glifos en total, mover glifos de un círculo a otro), pero el hijo NO se lanza todavía (H12 es para después de la demo).
##   · Elegir un hueco → dibujar a la izquierda → la tinta lo escribe trazo a trazo. Si no se reconoce, el trazo SE QUEDA para corregirlo (clic derecho lo borra).
##   · El trazo se RECTIFICA a la escala de la zona antes de reconocerlo (`GestureRectify`, como el libro de siempre con su círculo): sin eso, una runa dibujada pequeña
##     en esta zona grande se reconocía 12 de 72 veces; rectificada, 72 de 72 (medido el 22/11). Cada intento se apunta en `PlayLog` («libro_rojo_trazo»).
##   · Catálogo en una pestaña (no tapa el conjuro) con la CAPACIDAD a la vista. Orden de los glifos «dibujo» u «huecos» (H4, §17.1). Nombre (H16) y coste (H9).

signal escrito(destino: String, simbolo: String)      ## se aceptó un trazo y la tinta empezó a escribirlo (pruebas)
signal rechazado(destino: String, aviso: String)      ## el trazo no se reconoció: se queda en la página izquierda

const PAUSA_GESTO: float = 0.75                ## s sin dibujar que cierran el gesto (como el libro de siempre)
const T_ESCRITURA: float = 0.55                ## s que tarda la tinta en escribir un símbolo
const T_COMBINAR: float = 0.75                 ## s de la transición de un sello a dos sellos combinados (§7: 0,6–0,9)
const T_PRACTICA: float = 1.6                  ## s de la animación de práctica de un símbolo del catálogo (en bucle)
const MIN_DIST_PUNTO: float = 4.0
## Rectificador a la escala de la ZONA. Medido el 22/11 (de 45 a 220 px, con temblor de 3 px): tolerancia 1,0 → 268/270 (solo ᛒ suelo falla alguna vez);
## 0,6 → 261–264. El tamaño de forma no cambia nada entre 0,3 y 1,0.
static var ESCALA_RECTIFICADO: float = 1.0     ## × el radio de la zona: tolerancia al temblor
static var ESCALA_FORMA: float = 1.0           ## × el radio de la zona: tamaño de las formas (tramo mínimo y cierre)
const CONDICIONES: Array = [["al_impactar", "al impactar"], ["al_acabar", "al acabar"], ["a_la_vez", "a la vez"]]

## LA LÁMINA (22/11, la trajo Pablo: «añade este libro»): cuero rojo, esquinas de bronce con rubíes, lomo dorado y dos páginas de pergamino vacías, con transparencia.
## Todo se coloca en COORDENADAS DE LÁMINA (px de la imagen, 1513 × 926), como en las láminas del libro de siempre: para mover algo, se cambian estos números.
## Medido sobre los píxeles (pergamino): izquierda x 97–722, y 53–824 · derecha x 782–1409, y 56–824 · lomo x 722–782. Las de abajo llevan margen para no pisar las
## esquinas redondeadas ni los bordes ondulados.
const LAMINA: String = "res://art/ui/grimorio_rojo.png"
const LAMINA_TAM: Vector2 = Vector2(1513.0, 926.0)
const PAGINA_IZQ_LAM: Rect2 = Rect2(115.0, 75.0, 590.0, 730.0)
const PAGINA_DER_LAM: Rect2 = Rect2(800.0, 75.0, 590.0, 730.0)
const PESTANA_IZQ_LAM: Rect2 = Rect2(0.0, 365.0, 75.0, 135.0)       ## la pestaña roja del lateral izquierdo: el selector de páginas 1/2/3
const CIERRE_DER_LAM: Rect2 = Rect2(1405.0, 340.0, 108.0, 200.0)    ## el cierre del lateral derecho: abre el catálogo
const SOMBRA_CAPAS: int = 6                                          ## la sombra suave bajo el libro (la lámina no la trae)

## LA HOJA DE CATÁLOGO (22/11, Pablo: «vamos a probar así»; inspirada en el libro de runas de Mystralia, adaptada). Se pasa sobre la página IZQUIERDA (el conjuro
## sigue a la vista). Familias en huecos FIJOS, con candado lo que aún no se tiene (se ve cuánto falta): los sellos aparte (como sus gemas) y los glifos por lo que
## HACEN en nuestras reglas (P9, B9a): FORMA (cómo se mueve o crece; no sube el daño) y POTENCIA (lo que sube el daño). Las CONDICIONES (los dos círculos, H12/H15)
## salen bloqueadas: se ve que hay más. Abajo, la FICHA del elegido (H8): nombre, una frase, con qué vale y su trazo animado, con «Practicar».
## Consulta y práctica, nunca inscripción: aquí se dibuja.
const FAMILIA_SELLOS: Array = ["fuego", "agua", "tierra", "viento", "rayo", "hielo"]
const FAMILIA_FORMA: Array = ["flecha", "linea", "altura", "pulso", "permanencia", "rebote", "buscar", "repeticion", "retorno"]
const FAMILIA_POTENCIA: Array = ["barrera", "raido", "perforar", "suelo", "retardo"]
const FAMILIA_CONDICIONES: Array = ["al impactar", "al acabar", "a la vez", "al rebotar"]
## Los textos de la ficha (frase, con qué vale, verbo) viven en `FichasGlifo` (23/11): son PROVISIONALES y los decide Pablo. Aquí solo van estos dos envoltorios.
## `ficha_de` devuelve [frase (una sola, la misma de la lámina), con qué vale].
static func ficha_de(id: String) -> Array:
	return [FichasGlifo.frase(id), FichasGlifo.bases(id)]


## El nombre-verbo de una runa (las notas y el catálogo); un id sin ficha se devuelve igual.
static func verbo_de(id: String) -> String:
	return FichasGlifo.verbo(id)


## LAS NOTAS DEL PERSONAJE (5.ª vuelta, 22/11, boceto de Pablo): hojas sueltas a la IZQUIERDA del libro (fuera de él: no tapan ni el trazado ni el conjuro), con las
## pestañas Sellos · Unión · Glifos. Son «inteligentes»: la hoja de delante es la del destino elegido (núcleo → Sellos, hueco → Glifos, enlace → Unión) y solo apunta
## lo que el personaje CONOCE (y «N por descubrir» al pie). Mientras se dibuja, se apagan las runas que ya no pueden salir y se marca la que va ganando (✓); el último
## intento fallido queda TACHADO junto a la runa que parecía. Un clic en una nota abre el CUADERNO (la página extendida) en esa runa.
## Los nombres son VERBOS de lo que hace cada runa (el boceto de Pablo), no el nombre del hechizo: los hechizos guardados se BAUTIZAN (H16).
const UNION: Array = [["al impactar", "El segundo círculo nace donde choca el primero."], ["al acabar", "Nace cuando el primero se acaba."],
	["a la vez", "Salen los dos casi juntos (≈ 0,17 s)."], ["combinar", "Dos sellos en el mismo núcleo: un solo hechizo (magma, naturaleza…)."]]
const NOTAS_ANCHO_K: float = 0.205             ## parte del ancho de pantalla para las notas (el libro se aparta a la derecha)
const T_PRACTICA_CUADERNO: float = 0.75        ## pausa que cierra el gesto en el recuadro de práctica del cuaderno

const CUERO: Color = Color(0.42, 0.06, 0.07)
const CUERO_CLARO: Color = Color(0.58, 0.12, 0.11)
const PERGAMINO: Color = Color(0.96, 0.91, 0.79)
const PERGAMINO_SOMBRA: Color = Color(0.86, 0.79, 0.64)
const TINTA: Color = Color(0.17, 0.10, 0.07)
const TINTA_GUIA: Color = Color(0.17, 0.10, 0.07, 0.22)
const TINTA_HUMEDA: Color = Color(0.08, 0.04, 0.03)
const BRONCE: Color = Color(0.72, 0.52, 0.25)
const RUBI: Color = Color(0.70, 0.08, 0.12)
const SELECCION: Color = Color(0.70, 0.08, 0.12, 0.85)
const RECHAZO: Color = Color(0.55, 0.45, 0.40, 0.9)

var abierto: bool = false
## Destinos: "nucleo", "nucleo2" (el segundo sello: combinar), "hueco:<i>"; en la anidación, además, "hijo_nucleo", "hijo_hueco:<i>" y "condicion".
var destino: String = "nucleo"
var orden_por_huecos: bool = false             ## false = orden de dibujo (hoy) · true = orden de la corona
var catalogo_abierto: bool = false
var ver_anidacion: bool = false                ## estructura C (editable, no se lanza)
var aviso: String = ""
var practica: String = ""                      ## símbolo elegido en el catálogo para practicar ("" = ninguno)
var practica_es_elemento: bool = false

var _trazos: Array = []                        ## [PackedVector2Array] del gesto en curso (pantalla)
var _trazo: PackedVector2Array = PackedVector2Array()
var _dibujando: bool = false
var _cuenta: float = 0.0
var _trazo_rechazado: bool = false
var _escritura: Dictionary = {}                ## {destino, simbolo, polis, t}
var _t_combinar: float = -1.0                  ## 0..T_COMBINAR mientras se separan los dos alojamientos
var _t_practica: float = 0.0
var _libro_previo: String = ""                 ## el `Repertoire.libro` de antes de combinar (se devuelve al separar o al cerrar)
var _botones: Dictionary = {}                  ## nombre -> Rect2 (los pinta `_draw` y los mira `_gui_input`)
var ultimo_intento: Dictionary = {}            ## lo último apuntado en PlayLog (pruebas)
var sel_catalogo: String = "flecha"            ## el símbolo cuya ficha se enseña en la hoja de catálogo
var recientes: Array = []                      ## los últimos símbolos escritos o practicados (la chuleta mínima de la zona de trazado), como mucho 4
## 5.ª vuelta: el cuaderno (la página extendida; se abre con `catalogo_abierto`) y las notas.
var cuaderno_tab: String = "glifos"            ## "sellos", "union" o "glifos"
var ultimo_rechazo: Dictionary = {}            ## {parece, trazos}: el último trazo no reconocido, que las notas enseñan tachado
var prac_resultado: String = ""                ## lo que dijo el reconocedor en el recuadro de práctica del cuaderno
var prac_ok: bool = false
var _prac_trazos: Array = []
var _prac_trazo: PackedVector2Array = PackedVector2Array()
var _prac_dibujando: bool = false
var _prac_cuenta: float = 0.0
var _cand_clave: String = ""                   ## caché de las notas en vivo: qué trazos se miraron la última vez
var _cand_vivos: Dictionary = {}               ## id -> true si aún puede salir con lo dibujado
var _cand_lider: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func caster() -> Grimorio:
	return get_tree().get_first_node_in_group("spellcaster") as Grimorio if is_inside_tree() else null


# ---------------------------------------------------------------------------------------------------------------------
#  Abrir y cerrar
# ---------------------------------------------------------------------------------------------------------------------

func abrir() -> void:
	if abierto:
		return
	abierto = true
	visible = true
	_libro_previo = Repertoire.libro
	if _pagina_tiene_dos_sellos():
		Repertoire.libro = "avanzado"            # una página combinada guardada se lee como combinada
	get_tree().paused = true
	Sfx.play_ui("libro_abre")
	queue_redraw()


func cerrar() -> void:
	if not abierto:
		return
	abierto = false
	visible = false
	_trazos.clear()
	_trazo = PackedVector2Array()
	_dibujando = false
	catalogo_abierto = false
	get_tree().paused = false
	Sfx.play_ui("libro_cierra")


func _input(ev: InputEvent) -> void:
	if ev is InputEventKey and (ev as InputEventKey).pressed and not (ev as InputEventKey).echo:
		var k: Key = (ev as InputEventKey).keycode
		if k == KEY_L:
			if abierto:
				cerrar()
			else:
				abrir()
			get_viewport().set_input_as_handled()
		elif abierto and k == KEY_ESCAPE:
			cerrar()
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------------------------------------------------
#  Geometría
# ---------------------------------------------------------------------------------------------------------------------

var _tex_lamina: Texture2D = null


func lamina() -> Texture2D:
	if _tex_lamina == null and ResourceLoader.exists(LAMINA):
		_tex_lamina = load(LAMINA) as Texture2D
	return _tex_lamina


## El libro en pantalla, con la PROPORCIÓN de la lámina (1513 / 926 ≈ 1,63, más ancha que la del libro de siempre): se escala igual en X y en Y, sin deformarse.
func libro_rect() -> Rect2:
	var prop: float = LAMINA_TAM.x / LAMINA_TAM.y
	var x0: float = size.x * NOTAS_ANCHO_K                  # 5.ª vuelta: a la izquierda van las notas del personaje
	var disponible: float = size.x - x0 - size.x * 0.01
	var bw: float = minf(disponible, size.y * 0.94 * prop)
	var bh: float = bw / prop
	return Rect2(Vector2(x0 + (disponible - bw) * 0.5, (size.y - bh) * 0.5), Vector2(bw, bh))


## El rectángulo de las notas: el hueco a la izquierda del libro.
func notas_rect() -> Rect2:
	var b: Rect2 = libro_rect()
	return Rect2(Vector2(size.x * 0.008, b.position.y + b.size.y * 0.04), Vector2(b.position.x - size.x * 0.008 - 4.0, b.size.y * 0.92))


## La hoja de las notas que toca según el destino: núcleo → sellos, hueco → glifos, enlace (condición) → unión.
func tab_notas() -> String:
	if destino == "condicion":
		return "union"
	return "sellos" if familia_esperada() == "sello" else "glifos"


## Lo que el personaje tiene apuntado en una hoja: los símbolos conocidos de esa familia, en el orden de la familia.
func ids_de_tab(tab: String) -> Array:
	var salida: Array = []
	var fuente: Array = FAMILIA_SELLOS if tab == "sellos" else (FAMILIA_FORMA + FAMILIA_POTENCIA if tab == "glifos" else [])
	for id in fuente:
		if conocido(String(id)):
			salida.append(String(id))
	return salida


func por_descubrir(tab: String) -> int:
	var fuente: Array = FAMILIA_SELLOS if tab == "sellos" else (FAMILIA_FORMA + FAMILIA_POTENCIA if tab == "glifos" else [])
	return fuente.size() - ids_de_tab(tab).size()


## Un rectángulo de la lámina (px de la imagen) en pantalla.
func de_lamina(r: Rect2) -> Rect2:
	var b: Rect2 = libro_rect()
	var k: float = b.size.x / LAMINA_TAM.x
	return Rect2(b.position + r.position * k, r.size * k)


func pagina_izq() -> Rect2:
	return de_lamina(PAGINA_IZQ_LAM)


func pagina_der() -> Rect2:
	return de_lamina(PAGINA_DER_LAM)


func zona_trazado() -> Dictionary:
	var l: Rect2 = pagina_izq()
	return {"centro": l.get_center() + Vector2(0.0, -l.size.y * 0.02), "radio": minf(l.size.x, l.size.y) * 0.33}


func centro_conjuro() -> Vector2:
	var r: Rect2 = pagina_der()
	return r.get_center() + Vector2(0.0, -r.size.y * 0.03)


func radio_conjuro() -> float:
	var r: Rect2 = pagina_der()
	return minf(r.size.x, r.size.y) * 0.32


func pos_hueco(i: int) -> Vector2:
	return centro_conjuro() + Grimorio.dir_corona(i) * radio_conjuro() * 0.70


func radio_hueco() -> float:
	return radio_conjuro() * 0.15


func radio_nucleo() -> float:
	return radio_conjuro() * 0.30


## Dónde va cada alojamiento de sello: uno en el centro (A) o dos lado a lado (B), con la transición `_t_combinar`.
func pos_sellos() -> Array:
	var c: Vector2 = centro_conjuro()
	if not _pagina_tiene_dos_sellos() and _t_combinar < 0.0:
		return [c]
	var k: float = 1.0 if _t_combinar < 0.0 else smoothstep(0.0, 1.0, clampf(_t_combinar / T_COMBINAR, 0.0, 1.0))
	var sep: float = radio_nucleo() * 0.62 * k
	return [c - Vector2(sep, 0.0), c + Vector2(sep, 0.0)]


func pos_marca_combinar() -> Vector2:
	return centro_conjuro() + Vector2(radio_nucleo() * 0.82, -radio_nucleo() * 0.82)


## Anidación: el principal arriba a la izquierda y el hijo abajo a la derecha.
func centro_principal() -> Vector2:
	var r: Rect2 = pagina_der()
	return r.position + Vector2(r.size.x * 0.33, r.size.y * 0.36)


func centro_hijo() -> Vector2:
	var r: Rect2 = pagina_der()
	return r.position + Vector2(r.size.x * 0.68, r.size.y * 0.66)


func radio_anidado() -> float:
	return radio_conjuro() * 0.66


func pos_hueco_anidado(hijo: bool, i: int) -> Vector2:
	return (centro_hijo() if hijo else centro_principal()) + Grimorio.dir_corona(i) * radio_anidado() * 0.70


func pos_condicion() -> Vector2:
	var a: Vector2 = centro_principal()
	var b: Vector2 = centro_hijo()
	return a.lerp(b, 0.5)


# ---------------------------------------------------------------------------------------------------------------------
#  Página (del lanzador)
# ---------------------------------------------------------------------------------------------------------------------

func _ficha() -> Dictionary:
	var c: Grimorio = caster()
	if c == null or c.pages.is_empty():
		return {}
	return c.pages[c.page]


func _pagina_tiene_dos_sellos() -> bool:
	var f: Dictionary = _ficha()
	return not f.is_empty() and int(f.get("element2", Runes.Type.NONE)) != Runes.Type.NONE


## El glifo de cada hueco abierto: [{i, nombre}] con nombre "" si está vacío. Un glifo cuyo sector no es de la corona (una página del libro «bosque») ocupa el primer hueco libre.
func glifos_en_huecos() -> Array:
	var n: int = Grimorio.huecos_abiertos()
	var salida: Array = []
	for i in range(n):
		salida.append({"i": i, "nombre": ""})
	var f: Dictionary = _ficha()
	if f.is_empty():
		return salida
	var sueltos: Array = []
	for comp in (f["components"] as Array):
		var sig: Array = comp["sigils"]
		if sig.is_empty():
			continue
		var puesto: bool = false
		for i in range(n):
			if (comp["direction"] as Vector2).is_equal_approx(Grimorio.dir_corona(i)) and String(salida[i]["nombre"]) == "":
				salida[i]["nombre"] = String(sig[0])
				puesto = true
				break
		if not puesto:
			sueltos.append(String(sig[0]))
	for s in sueltos:
		for i in range(n):
			if String(salida[i]["nombre"]) == "":
				salida[i]["nombre"] = s
				break
	return salida


func n_glifos_principal() -> int:
	var n: int = 0
	for g in glifos_en_huecos():
		if String(g["nombre"]) != "":
			n += 1
	return n


# --- Anidación: el hijo vive en la página (`hijo` = {elemento, glifos[6]}, `condicion`), lo guarda el Grimorio como `nombre` y `elemento2` ---

func hijo() -> Dictionary:
	var f: Dictionary = _ficha()
	if f.is_empty():
		return {}
	if not (f.get("hijo") is Dictionary):
		f["hijo"] = {"elemento": "", "glifos": ["", "", "", "", "", ""]}
	var h: Dictionary = f["hijo"]
	if not (h.get("glifos") is Array) or (h["glifos"] as Array).size() < Grimorio.CORONA_ANGULOS.size():
		var gs: Array = ["", "", "", "", "", ""]
		for k in range(mini((h.get("glifos", []) as Array).size(), gs.size())):
			gs[k] = String(h["glifos"][k])
		h["glifos"] = gs
	return h


func n_glifos_hijo() -> int:
	var n: int = 0
	for g in (hijo().get("glifos", []) as Array):
		if String(g) != "":
			n += 1
	return n


## El tope compartido de la anidación: 6 glifos EN TOTAL entre principal e hijo (los huecos que tenga la página).
func tope_total() -> int:
	return Grimorio.huecos_abiertos()


func n_glifos_total() -> int:
	return n_glifos_principal() + n_glifos_hijo()


func condicion() -> String:
	var f: Dictionary = _ficha()
	return String(f.get("condicion", "al_impactar")) if not f.is_empty() else "al_impactar"


func texto_condicion(id: String = "") -> String:
	var c: String = condicion() if id == "" else id
	for par in CONDICIONES:
		if String(par[0]) == c:
			return String(par[1])
	return c


func siguiente_condicion() -> void:
	var f: Dictionary = _ficha()
	if f.is_empty():
		return
	var i: int = 0
	for k in range(CONDICIONES.size()):
		if String(CONDICIONES[k][0]) == condicion():
			i = k
	f["condicion"] = String(CONDICIONES[(i + 1) % CONDICIONES.size()][0])
	_guardar_pagina()


func _guardar_pagina() -> void:
	var c: Grimorio = caster()
	if c != null:
		c.volcar_paginas()
	queue_redraw()


func _foto_pagina() -> String:
	var f: Dictionary = _ficha()
	return "" if f.is_empty() else "%s|%s|%s" % [str(f["element"]), str(f.get("element2", 0)), str(f["components"])]


func sector_de_destino() -> Vector2:
	if destino.begins_with("hueco:"):
		return Grimorio.dir_corona(int(destino.substr(6)))
	return Vector2.ZERO


func elegir_destino(d: String) -> void:
	destino = d
	_trazos.clear()
	_trazo_rechazado = false
	aviso = ""
	queue_redraw()


func es_destino_hijo() -> bool:
	return destino.begins_with("hijo_")


## Lo que se espera dibujar: «sello» en los núcleos, «glifo» en los huecos, «» en la condición (se elige con clic, no se dibuja).
func familia_esperada() -> String:
	if destino == "condicion":
		return ""
	return "glifo" if destino.begins_with("hueco:") or destino.begins_with("hijo_hueco:") else "sello"


## Qué círculo y qué hueco se rellena, para la cabecera de la página izquierda.
func texto_destino() -> String:
	var circulo: String = ""
	if ver_anidacion:
		circulo = "Hijo · " if es_destino_hijo() else "Principal · "
	match destino:
		"nucleo":
			return circulo + "sello"
		"nucleo2":
			return "Segundo sello (se combina)"
		"hijo_nucleo":
			return circulo + "sello"
		"condicion":
			return "Condición: %s (clic en el rombo para cambiarla)" % texto_condicion()
	if destino.begins_with("hijo_hueco:"):
		return circulo + "hueco %d" % (int(destino.substr(11)) + 1)
	if destino.begins_with("hueco:"):
		return circulo + "hueco %d" % (int(destino.substr(6)) + 1)
	return destino


# ---------------------------------------------------------------------------------------------------------------------
#  El gesto: se dibuja a la izquierda, se rectifica a la escala de la zona y se reconoce
# ---------------------------------------------------------------------------------------------------------------------

## El gesto como lo vería el reconocedor: rectificado a la escala de la ZONA (como el libro de siempre con su círculo), si el trazo recto está activo.
func preparar_trazos(trazos: Array) -> Array:
	if not Estado.i().trazo_recto:
		return trazos
	var rz: float = float(zona_trazado()["radio"])
	var salida: Array = []
	for t in GestureRectify.rectificar_gesto(trazos, rz * ESCALA_RECTIFICADO, rz * ESCALA_FORMA):
		if (t as PackedVector2Array).size() >= 2:
			salida.append(t)
	return salida if not salida.is_empty() else trazos


## Cierra el gesto en curso. Devuelve true si se aceptó. Público para las pruebas: `trazos` sustituye a lo dibujado.
func cerrar_gesto(trazos: Array = []) -> bool:
	var c: Grimorio = caster()
	var crudos: Array = trazos if not trazos.is_empty() else _trazos.duplicate()
	_cuenta = 0.0
	if c == null or crudos.is_empty() or familia_esperada() == "":
		return false
	var enviar: Array = preparar_trazos(crudos)
	var lectura: Dictionary = _leer(enviar)
	if es_destino_hijo():
		return _cerrar_gesto_hijo(crudos, enviar, lectura)
	# Anidación: el tope es de 6 glifos EN TOTAL entre los dos círculos.
	if ver_anidacion and familia_esperada() == "glifo" and n_glifos_total() >= tope_total():
		return _rechazar(crudos, "Ya hay %d glifos en total: quita o mueve uno" % tope_total(), lectura)
	var combinar: bool = destino == "nucleo2"
	var libro_antes: String = Repertoire.libro
	if combinar:
		Repertoire.libro = "avanzado"            # el segundo sello va a `element2`, con la lógica de combinación de siempre
	elif destino == "nucleo" and not _pagina_tiene_dos_sellos() and Repertoire.libro == "avanzado" and _libro_previo != "avanzado":
		Repertoire.libro = _libro_previo         # un sello solo: el libro de siempre (no se crea un segundo sello por accidente)
	var antes: String = _foto_pagina()
	c.add_gesture(enviar, sector_de_destino())
	var despues: String = _foto_pagina()
	if despues == antes:
		if combinar and not _pagina_tiene_dos_sellos():
			Repertoire.libro = libro_antes
		return _rechazar(crudos, c.feedback_text if c.feedback_text != "" else "No reconocido: corrígelo o bórralo (clic derecho)", lectura)
	if orden_por_huecos:
		reordenar_por_huecos()
	var simbolo: String = _simbolo_en_destino()
	if combinar:
		_t_combinar = 0.0
		Sfx.play_ui("pagina")
	_aceptar(simbolo, lectura)
	if destino.begins_with("hueco:"):
		_siguiente_hueco_libre()
	return true


## El hijo de la anidación: no hay página del lanzador para él, así que se reconoce aquí, con el mismo reconocedor (`TrazosRectos`), la raya ᛁ y los mismos filtros
## (runa activa). No se lanza todavía.
func _cerrar_gesto_hijo(crudos: Array, enviar: Array, lectura: Dictionary) -> bool:
	var h: Dictionary = hijo()
	if destino == "hijo_nucleo":
		if not bool(lectura.get("accepted", false)):
			return _rechazar(crudos, "No reconocido · se parece a: %s" % String(lectura.get("name", "?")), lectura)
		var e: String = String(lectura["name"])
		if not Repertoire.element_active(e):
			return _rechazar(crudos, "Aún no conoces el sello de %s" % e, lectura)
		h["elemento"] = e
		_guardar_pagina()
		_aceptar(e, lectura)
		return true
	var i: int = int(destino.substr(11))
	if String((h["glifos"] as Array)[i]) == "" and n_glifos_total() >= tope_total():
		return _rechazar(crudos, "Ya hay %d glifos en total: quita o mueve uno" % tope_total(), lectura)
	var g: String = ""
	if enviar.size() == 1 and _es_raya(enviar[0]):
		if Repertoire.sigil_active("linea"):
			var t: PackedVector2Array = enviar[0]
			g = Sigils.orientacion_linea(t[0], t[t.size() - 1])
	elif bool(lectura.get("accepted", false)) and Repertoire.sigil_active(String(lectura["name"])):
		g = String(lectura["name"])
	if g == "":
		return _rechazar(crudos, "No reconocido · se parece a: %s" % String(lectura.get("name", "?")), lectura)
	(h["glifos"] as Array)[i] = g
	_guardar_pagina()
	_aceptar(g, lectura)
	_siguiente_hueco_libre()
	return true


static func _es_raya(t: PackedVector2Array) -> bool:
	if t.size() < 2:
		return false
	var largo: float = 0.0
	for j in range(1, t.size()):
		largo += t[j].distance_to(t[j - 1])
	var punta: float = t[0].distance_to(t[t.size() - 1])
	return punta >= 1.0 and largo / punta <= 1.15


## Lo que el reconocedor de trazos rectos lee del gesto (para el PlayLog y el hijo): contra los sellos o los glifos según el destino.
func _leer(enviar: Array) -> Dictionary:
	var voc: Dictionary = TrazosRectos.ELEMENTOS if familia_esperada() == "sello" else TrazosRectos.SELLOS
	return TrazosRectos.reconocer(enviar, voc)


## La chuleta mínima: los últimos 4 símbolos escritos o practicados (el más reciente primero). Se guarda el id del repertorio (linea_x → linea).
func anotar_reciente(simbolo: String) -> void:
	if simbolo == "":
		return
	var id: String = simbolo if GestureLibrary.ELEMENTS.has(simbolo) else Sigils.repertorio_de(simbolo)
	recientes.erase(id)
	recientes.push_front(id)
	while recientes.size() > 4:
		recientes.pop_back()


## ¿Se tiene ya este símbolo? (sello o glifo activo; `altura` también vale como `levitacion`).
static func conocido(id: String) -> bool:
	if FAMILIA_SELLOS.has(id) or GestureLibrary.ELEMENTS.has(id):
		return Repertoire.element_active(id)
	return Repertoire.sigil_active(id) or (id == "altura" and Repertoire.sigil_active("levitacion"))


func _aceptar(simbolo: String, lectura: Dictionary) -> void:
	anotar_reciente(simbolo)
	_trazos.clear()
	_trazo_rechazado = false
	aviso = ""
	_apuntar(true, simbolo, lectura)
	_empezar_escritura(simbolo)
	escrito.emit(destino, simbolo)
	queue_redraw()


## NOTAS EN VIVO: con lo dibujado hasta ahora (también el trazo a medias), qué runas de la hoja pueden salir todavía (`TrazosRectos.puede_completarse`) y cuál
## va ganando (`reconocer`). Se recalcula solo si cambian los trazos. Sin nada dibujado, todas siguen vivas y no hay líder.
func actualizar_candidatos() -> void:
	var trazos: Array = [] if _trazo_rechazado else _trazos.duplicate()       # un intento ya rechazado no cuenta: está tachado en las notas
	if _trazo.size() >= 2:
		trazos.append(_trazo)
	var n: int = 0
	for t in trazos:
		n += (t as PackedVector2Array).size()
	var clave: String = "%s|%d|%d|%s" % [tab_notas(), trazos.size(), n, str(_trazo_rechazado)]
	if clave == _cand_clave:
		return
	_cand_clave = clave
	_cand_vivos.clear()
	_cand_lider = ""
	var ids: Array = ids_de_tab(tab_notas())
	if trazos.is_empty() or tab_notas() == "union":
		for id in ids:
			_cand_vivos[id] = true
		return
	var preparados: Array = preparar_trazos(trazos)
	var es_sello: bool = tab_notas() == "sellos"
	var voc: Dictionary = TrazosRectos.ELEMENTOS if es_sello else TrazosRectos.SELLOS
	for id in ids:
		if id == "linea":
			_cand_vivos[id] = preparados.size() == 1 and _es_raya(preparados[0])
			continue
		var t: String = TrazosRectos.texto_guia(String(id), es_sello)
		_cand_vivos[id] = t != "" and puede_ser(preparados, t)
	if not es_sello and preparados.size() == 1 and _es_raya(preparados[0]) and ids.has("linea"):
		_cand_lider = "linea"
		return
	var r: Dictionary = TrazosRectos.reconocer(preparados, voc)
	if bool(r.get("accepted", false)) and ids.has(String(r["name"])):
		_cand_lider = String(r["name"])


## ¿Puede lo dibujado hasta ahora acabar siendo la runa de `texto`? Cada trazo terminado tiene que caber en un trazo distinto de la plantilla, y el último (quizá
## a medias) en el PRINCIPIO de otro: con la tolerancia del reconocedor, en cualquier sentido y, si la figura es cerrada, empezando por cualquier esquina.
## (`TrazosRectos.puede_completarse` no sirve aquí: mira si faltan trazos enteros, no si un trazo a medias puede acabar bien.)
static func puede_ser(trazos: Array, texto: String) -> bool:
	var leidas: Array = TrazosRectos.secuencias(trazos)
	var plantilla: Array = TrazosRectos.texto_a_gesto(texto)
	if leidas.is_empty() or leidas.size() > plantilla.size():
		return leidas.is_empty()
	return _encaja(leidas, 0, plantilla, [])


static func _encaja(leidas: Array, k: int, plantilla: Array, usados: Array) -> bool:
	if k >= leidas.size():
		return true
	var ultimo: bool = k == leidas.size() - 1
	for j in range(plantilla.size()):
		if usados.has(j):
			continue
		if _prefijo_de(leidas[k], plantilla[j], not ultimo) and _encaja(leidas, k + 1, plantilla, usados + [j]):
			return true
	return false


## ¿La secuencia leída es el principio (o, con `entera`, la totalidad) de `sec`, en algún sentido o giro? Direcciones en pasos de 45°, con la tolerancia del reconocedor.
static func _prefijo_de(leida: Array, sec: Array, entera: bool) -> bool:
	if leida.is_empty():
		return true
	var variantes: Array = []
	for base in [sec, TrazosRectos.invertir(sec)]:
		for g in range((base as Array).size()):
			var rot: Array = (base as Array).slice(g) + (base as Array).slice(0, g)        # una figura cerrada puede empezar por cualquier esquina
			variantes.append(rot)
	for v in variantes:
		if leida.size() > (v as Array).size() or (entera and leida.size() != (v as Array).size()):
			continue
		var bien: bool = true
		for i in range(leida.size()):
			var d: int = absi(int(leida[i]) - int(v[i])) % TrazosRectos.PASOS
			if mini(d, TrazosRectos.PASOS - d) > TrazosRectos.TOLERANCIA:
				bien = false
				break
		if bien:
			return true
	return false


func candidato_vivo(id: String) -> bool:
	return bool(_cand_vivos.get(id, true))


func candidato_lider() -> String:
	return _cand_lider


func _rechazar(crudos: Array, texto: String, lectura: Dictionary) -> bool:
	ultimo_rechazo = {"parece": String(lectura.get("name", "")), "trazos": crudos.duplicate(), "tab": tab_notas()}
	_trazo_rechazado = true
	_trazos = crudos
	aviso = texto
	_apuntar(false, "", lectura)
	rechazado.emit(destino, aviso)
	queue_redraw()
	return false


## Cada intento a `PlayLog` («libro_rojo_trazo»): qué se esperaba, qué se leyó, si entró, la desviación y la secuencia, para que Pablo diga cuáles fallan.
func _apuntar(aceptado: bool, simbolo: String, lectura: Dictionary) -> void:
	ultimo_intento = {"destino": destino, "espera": familia_esperada(), "aceptado": aceptado, "escrito": simbolo,
		"leido": String(lectura.get("name", "")), "rival": String(lectura.get("second_name", "")),
		"desviacion": lectura.get("desviacion", -1), "secuencia": String(lectura.get("secuencia", "")), "aviso": aviso}
	PlayLog.event("libro_rojo_trazo", ultimo_intento)


## Lo que ahora hay escrito en el destino: el nombre del elemento (núcleos) o del glifo (hueco).
func _simbolo_en_destino() -> String:
	var c: Grimorio = caster()
	var f: Dictionary = _ficha()
	if c == null or f.is_empty():
		return ""
	if destino == "nucleo":
		return c._gesture_name_of(f["element"])
	if destino == "nucleo2":
		return c._gesture_name_of(f["element2"])
	var i: int = int(destino.substr(6))
	for g in glifos_en_huecos():
		if int(g["i"]) == i:
			return String(g["nombre"])
	return ""


func _siguiente_hueco_libre() -> void:
	if es_destino_hijo():
		var gs: Array = hijo()["glifos"]
		for k in range(Grimorio.huecos_abiertos()):
			if String(gs[k]) == "":
				destino = "hijo_hueco:%d" % k
				return
		return
	for g in glifos_en_huecos():
		if String(g["nombre"]) == "":
			destino = "hueco:%d" % int(g["i"])
			return


## §17.1 · ORDEN DE LOS HUECOS: los glifos de la página pasan al orden de la corona (de arriba en el sentido del reloj). Lo que se lanza lee ese orden (ráfaga, disparador).
func reordenar_por_huecos() -> void:
	var c: Grimorio = caster()
	var f: Dictionary = _ficha()
	if c == null or f.is_empty():
		return
	var comps: Array = f["components"]
	comps.sort_custom(func(a, b) -> bool: return _indice_corona(a["direction"]) < _indice_corona(b["direction"]))
	c.resumen_pagina(c.page)                    # la clave cambió: rehace el Hechizo y guarda la página


static func _indice_corona(dir: Vector2) -> int:
	for i in range(Grimorio.CORONA_ANGULOS.size()):
		if dir.is_equal_approx(Grimorio.dir_corona(i)):
			return i
	return 99


func cambiar_orden(por_huecos: bool) -> void:
	orden_por_huecos = por_huecos
	if por_huecos:
		reordenar_por_huecos()
	queue_redraw()


## Deja la página con un solo sello (quita el segundo y vuelve al libro de antes).
func separar_sellos() -> void:
	var f: Dictionary = _ficha()
	if f.is_empty():
		return
	f["element2"] = Runes.Type.NONE
	f["element2_q"] = 1.0
	Repertoire.libro = _libro_previo if _libro_previo != "avanzado" else "bosque"
	_t_combinar = -1.0
	var c: Grimorio = caster()
	if c != null:
		c.resumen_pagina(c.page)
	if destino == "nucleo2":
		destino = "nucleo"
	queue_redraw()


## §10 · MOVER un glifo de un círculo a otro (anidación): el del hueco elegido pasa al primer hueco libre del otro círculo. El total no cambia.
## Devuelve true si se movió.
func mover_glifo_al_otro_circulo() -> bool:
	var c: Grimorio = caster()
	if c == null or not ver_anidacion:
		return false
	var h: Dictionary = hijo()
	var gs: Array = h["glifos"]
	if destino.begins_with("hueco:"):
		var i: int = int(destino.substr(6))
		var nombre: String = ""
		for g in glifos_en_huecos():
			if int(g["i"]) == i:
				nombre = String(g["nombre"])
		if nombre == "":
			return false
		for k in range(Grimorio.huecos_abiertos()):
			if String(gs[k]) == "":
				c.quitar_glifo_hueco(i)
				gs[k] = nombre
				destino = "hijo_hueco:%d" % k
				_guardar_pagina()
				return true
		return false
	if destino.begins_with("hijo_hueco:"):
		var k2: int = int(destino.substr(11))
		var nombre2: String = String(gs[k2])
		if nombre2 == "":
			return false
		for g in glifos_en_huecos():
			if String(g["nombre"]) == "":
				var antes: String = _foto_pagina()
				c.add_sigil(Grimorio.dir_corona(int(g["i"])), nombre2)
				if _foto_pagina() == antes:
					return false
				gs[k2] = ""
				destino = "hueco:%d" % int(g["i"])
				_guardar_pagina()
				return true
	return false


# ---------------------------------------------------------------------------------------------------------------------
#  Tinta: el símbolo se escribe trazo a trazo
# ---------------------------------------------------------------------------------------------------------------------

## Polilíneas (en [-0,5, 0,5]²) de un símbolo: la GUÍA de `TrazosRectos` (la misma del libro de siempre), centrada en el origen. [] si no tiene trazo.
static func polilineas(nombre: String) -> Array:
	var texto: String = TrazosRectos.texto_guia(nombre, GestureLibrary.ELEMENTS.has(nombre))
	if texto == "":
		texto = "R" if nombre == "linea_x" else ("D" if nombre == "linea_z" else "")
	if texto == "":
		return []
	var salida: Array = []
	for linea in TrazosRectos.guia_polilineas(texto):
		var n := PackedVector2Array()
		for q in (linea as PackedVector2Array):
			n.append(q - Vector2(0.5, 0.5))
		salida.append(n)
	return salida


func _textura_de(nombre: String) -> Texture2D:
	var c: Grimorio = caster()
	if c != null and GestureLibrary.ELEMENTS.has(nombre):
		var tipo: Variant = Grimorio.GESTURE_TO_RUNE.get(nombre)
		var rd: RuneData = c.rune_database.get(tipo) as RuneData if tipo != null else null
		return rd.glyph if rd != null else null
	return Sigils.GLYPHS.get(Sigils.repertorio_de(nombre)) as Texture2D


func _pos_y_radio_de(d: String) -> Array:
	if d == "nucleo" or d == "nucleo2":
		if ver_anidacion:
			return [centro_principal(), radio_anidado() * 0.38]
		var ps: Array = pos_sellos()
		var idx: int = 1 if d == "nucleo2" and ps.size() > 1 else 0
		return [ps[idx], radio_nucleo() * (0.62 if ps.size() > 1 else 0.85)]
	if d == "hijo_nucleo":
		return [centro_hijo(), radio_anidado() * 0.38]
	if d.begins_with("hijo_hueco:"):
		return [pos_hueco_anidado(true, int(d.substr(11))), radio_anidado() * 0.16]
	if ver_anidacion:
		return [pos_hueco_anidado(false, int(d.substr(6))), radio_anidado() * 0.16]
	return [pos_hueco(int(d.substr(6))), radio_hueco()]


func _empezar_escritura(simbolo: String) -> void:
	_escritura = {"destino": destino, "simbolo": simbolo, "polis": polilineas(simbolo), "t": 0.0}
	Sfx.play_ui("trazo")


func escribiendo() -> bool:
	return not _escritura.is_empty()


func _process(delta: float) -> void:
	if not abierto:
		return
	if _cuenta > 0.0:
		_cuenta -= delta
		if _cuenta <= 0.0 and not _dibujando and not _trazos.is_empty() and not _trazo_rechazado:
			cerrar_gesto()
	if not _escritura.is_empty():
		_escritura["t"] = float(_escritura["t"]) + delta
		if float(_escritura["t"]) >= T_ESCRITURA:
			_escritura = {}
	if _t_combinar >= 0.0:
		_t_combinar += delta
		if _t_combinar >= T_COMBINAR + 0.35:
			_t_combinar = -1.0
	_t_practica = fmod(_t_practica + delta, T_PRACTICA + 0.5)
	if _prac_cuenta > 0.0:
		_prac_cuenta -= delta
		if _prac_cuenta <= 0.0 and not _prac_dibujando and not _prac_trazos.is_empty():
			evaluar_practica()
	queue_redraw()


# ---------------------------------------------------------------------------------------------------------------------
#  Ratón
# ---------------------------------------------------------------------------------------------------------------------

func _gui_input(ev: InputEvent) -> void:
	if not abierto:
		return
	if catalogo_abierto:
		_gui_cuaderno(ev)
		return
	if ev is InputEventMouseButton:
		var mb: InputEventMouseButton = ev
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if _clic(mb.position):
				accept_event()
				return
			var z: Dictionary = zona_trazado()
			if not catalogo_abierto and familia_esperada() != "" and mb.position.distance_to(z["centro"]) <= float(z["radio"]):
				if _trazo_rechazado:
					_trazos.clear()                  # empezar a dibujar tras un rechazo: se corrige desde cero
					_trazo_rechazado = false
					aviso = ""
				_dibujando = true
				_trazo = PackedVector2Array([mb.position])
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and _dibujando:
			_dibujando = false
			if _trazo.size() >= 2:
				_trazos.append(_trazo)
				_cuenta = PAUSA_GESTO
				Sfx.play_ui("trazo")
			_trazo = PackedVector2Array()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_clic_derecho(mb.position)
			accept_event()
	elif ev is InputEventMouseMotion and _dibujando:
		var p: Vector2 = (ev as InputEventMouseMotion).position
		if _trazo.is_empty() or _trazo[_trazo.size() - 1].distance_to(p) >= MIN_DIST_PUNTO:
			_trazo.append(p)
		accept_event()


## Botones, pestañas y alojamientos. Devuelve true si el clic era de alguno.
func _clic(p: Vector2) -> bool:
	for nombre in _botones:
		if (_botones[nombre] as Rect2).has_point(p):
			_pulsar(String(nombre))
			return true
	if ver_anidacion:
		return _clic_anidacion(p)
	if _pagina_tiene_dos_sellos():
		var ps: Array = pos_sellos()
		for k in range(ps.size()):
			if p.distance_to(ps[k]) <= radio_nucleo() * 0.62:
				elegir_destino("nucleo" if k == 0 else "nucleo2")
				return true
	elif p.distance_to(centro_conjuro()) <= radio_nucleo():
		elegir_destino("nucleo")
		return true
	if not _pagina_tiene_dos_sellos() and int(_ficha().get("element", Runes.Type.NONE)) != Runes.Type.NONE and p.distance_to(pos_marca_combinar()) <= radio_conjuro() * 0.09:
		elegir_destino("nucleo2")
		return true
	for g in glifos_en_huecos():
		if p.distance_to(pos_hueco(int(g["i"]))) <= radio_hueco() * 1.15:
			elegir_destino("hueco:%d" % int(g["i"]))
			return true
	return false


func _clic_anidacion(p: Vector2) -> bool:
	var rn: float = radio_anidado() * 0.38
	if p.distance_to(centro_principal()) <= rn:
		elegir_destino("nucleo")
		return true
	if p.distance_to(centro_hijo()) <= rn:
		elegir_destino("hijo_nucleo")
		return true
	if p.distance_to(pos_condicion()) <= 22.0:
		elegir_destino("condicion")
		siguiente_condicion()
		return true
	var rh: float = radio_anidado() * 0.16 * 1.2
	for i in range(Grimorio.huecos_abiertos()):
		if p.distance_to(pos_hueco_anidado(false, i)) <= rh:
			elegir_destino("hueco:%d" % i)
			return true
		if p.distance_to(pos_hueco_anidado(true, i)) <= rh:
			elegir_destino("hijo_hueco:%d" % i)
			return true
	return false


func _clic_derecho(p: Vector2) -> void:
	var z: Dictionary = zona_trazado()
	if p.distance_to(z["centro"]) <= float(z["radio"]):
		_trazos.clear()
		_trazo_rechazado = false
		aviso = ""
		queue_redraw()
		return
	var c: Grimorio = caster()
	if c == null:
		return
	if ver_anidacion:
		var rh: float = radio_anidado() * 0.16 * 1.2
		for i in range(Grimorio.huecos_abiertos()):
			if p.distance_to(pos_hueco_anidado(false, i)) <= rh:
				c.quitar_glifo_hueco(i)
				queue_redraw()
				return
			if p.distance_to(pos_hueco_anidado(true, i)) <= rh:
				(hijo()["glifos"] as Array)[i] = ""
				_guardar_pagina()
				return
		if p.distance_to(centro_hijo()) <= radio_anidado() * 0.38:
			hijo()["elemento"] = ""
			_guardar_pagina()
		return
	for g in glifos_en_huecos():
		if p.distance_to(pos_hueco(int(g["i"]))) <= radio_hueco() * 1.15:
			c.quitar_glifo_hueco(int(g["i"]))
			queue_redraw()
			return
	if _pagina_tiene_dos_sellos() and (pos_sellos()[1] as Vector2).distance_to(p) <= radio_nucleo() * 0.62:
		separar_sellos()


func _pulsar(nombre: String) -> void:
	var c: Grimorio = caster()
	match nombre:
		"catalogo":
			if catalogo_abierto:
				catalogo_abierto = false
			else:
				abrir_cuaderno("", tab_notas())
		"cerrar_cuaderno":
			catalogo_abierto = false
		"orden":
			cambiar_orden(not orden_por_huecos)
		"anidacion":
			ver_anidacion = not ver_anidacion
			elegir_destino("nucleo")
		"vaciar":
			if c != null:
				c.clear_sequence()
				if _pagina_tiene_dos_sellos():
					separar_sellos()
				var f: Dictionary = _ficha()
				f.erase("hijo")
				f.erase("condicion")
				_guardar_pagina()
			elegir_destino("nucleo")
		"separar":
			separar_sellos()
		"mover":
			if not mover_glifo_al_otro_circulo():
				aviso = "Elige un glifo escrito; en el otro círculo tiene que haber un hueco libre"
		"sin_practica":
			practica = ""
		_:
			if nombre.begins_with("pagina:") and c != null:
				c.select_page(int(nombre.substr(7)))
				if _pagina_tiene_dos_sellos():
					Repertoire.libro = "avanzado"
				elif Repertoire.libro == "avanzado" and _libro_previo != "avanzado":
					Repertoire.libro = _libro_previo
				elegir_destino("nucleo")
			elif nombre.begins_with("practica:"):
				practicar(nombre.substr(9))
			elif nombre.begins_with("cat:"):
				sel_catalogo = nombre.substr(4)            # elige la ficha (no inscribe ni cierra)
				_prac_trazos.clear()
				prac_resultado = ""
				_t_practica = 0.0
			elif nombre.begins_with("tabc:"):
				if catalogo_abierto:
					cuaderno_tab = nombre.substr(5)
				else:
					abrir_cuaderno("", nombre.substr(5))
			elif nombre.begins_with("nota:"):
				abrir_cuaderno(nombre.substr(5))
			elif nombre == "practicar_sel" and conocido(sel_catalogo):
				practicar(sel_catalogo)
	queue_redraw()


## Ayuda al dibujo: enseña animado el gesto de `nombre` en la zona de trazado, para practicar. No lo inscribe.
func practicar(nombre: String) -> void:
	practica = nombre
	practica_es_elemento = GestureLibrary.ELEMENTS.has(nombre)
	_t_practica = 0.0
	catalogo_abierto = false
	anotar_reciente(nombre)
	queue_redraw()


# ---------------------------------------------------------------------------------------------------------------------
#  Dibujo
# ---------------------------------------------------------------------------------------------------------------------

func _draw() -> void:
	if not abierto:
		return
	_botones.clear()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.55))
	var b: Rect2 = libro_rect()
	var tex: Texture2D = lamina()
	if tex != null:
		# Sombra suave bajo el libro (la lámina no la trae): capas que se abren hacia abajo y se desvanecen.
		var k: float = b.size.x / LAMINA_TAM.x
		var cuerpo: Rect2 = Rect2(b.position + Vector2(30.0, 20.0) * k, b.size - Vector2(60.0, 30.0) * k)
		for i in range(SOMBRA_CAPAS):
			var abre: float = float(i + 1) * 5.0
			draw_rect(Rect2(cuerpo.position + Vector2(-abre, abre * 0.6 + 6.0), cuerpo.size + Vector2(abre * 2.0, abre * 0.8)), Color(0.0, 0.0, 0.0, 0.07))
		draw_texture_rect(tex, b, false)
	else:
		# Sin lámina: la tapa de cuero dibujada por código (la 1.ª vuelta).
		draw_rect(b.grow(10.0), CUERO)
		draw_rect(b.grow(10.0), CUERO_CLARO, false, 3.0)
		for esquina in [b.position, Vector2(b.end.x, b.position.y), b.end, Vector2(b.position.x, b.end.y)]:
			draw_circle(esquina, 9.0, BRONCE)
			draw_circle(esquina, 5.0, RUBI)
		for pag in [pagina_izq(), pagina_der()]:
			draw_rect((pag as Rect2).grow(6.0), PERGAMINO_SOMBRA)
			draw_rect(pag, PERGAMINO)
	_dibujar_pestanas_pagina()
	_dibujar_trazado()
	if ver_anidacion:
		_dibujar_anidacion()
	else:
		_dibujar_conjuro()
	_dibujar_pestana_catalogo()
	_dibujar_botones()
	_dibujar_notas()                         # 5.ª vuelta: las notas del personaje, a la izquierda del libro
	if catalogo_abierto:
		_dibujar_cuaderno()                  # el cuaderno de runas, a doble página encima


## Texto centrado (o no) que NUNCA se sale de `ancho_max`: baja el tamaño hasta que cabe (con un suelo de 11 px).
func _texto(pos: Vector2, t: String, tam: int, col: Color = TINTA, centrado: bool = true, ancho_max: float = -1.0) -> void:
	var f: Font = TemaInterfaz.fuente()
	var tam_real: int = tam
	if ancho_max > 0.0:
		while tam_real > 11 and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam_real).x > ancho_max:
			tam_real -= 1
	var ancho: float = f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam_real).x
	draw_string(f, pos - Vector2(ancho * 0.5 if centrado else 0.0, 0.0), t, HORIZONTAL_ALIGNMENT_LEFT, ancho_max if ancho_max > 0.0 else -1.0, tam_real, col)


func _doble_contorno(c: Vector2, r: float, col: Color = TINTA, grosor: float = 2.0) -> void:
	draw_arc(c, r, 0.0, TAU, 96, col, grosor, true)
	draw_arc(c, r * 0.93, 0.0, TAU, 96, col, grosor * 0.6, true)


func _boton(nombre: String, r: Rect2, texto: String, activo: bool = false) -> void:
	_botones[nombre] = r
	draw_rect(r, Color(PERGAMINO_SOMBRA, 0.9) if not activo else Color(RUBI, 0.2))
	draw_rect(r, SELECCION if activo else Color(TINTA, 0.5), false, 1.5)
	_texto(Vector2(r.get_center().x, r.get_center().y + 6.0), texto, 15, TINTA, true, r.size.x - 8.0)


## Las páginas 1/2/3 en la PESTAÑA ROJA del lateral izquierdo de la lámina (sin tapar las esquinas de bronce): una sobre otra.
func _dibujar_pestanas_pagina() -> void:
	var c: Grimorio = caster()
	if c == null:
		return
	var tab: Rect2 = de_lamina(PESTANA_IZQ_LAM)
	var total: int = Repertoire.pages_available(Grimorio.PAGES)
	var alto: float = minf(tab.size.y / float(maxi(total, 1)), 30.0)
	var y0: float = tab.get_center().y - alto * float(total) * 0.5
	var ancho: float = maxf(tab.size.x * 0.9, 26.0)
	for i in range(total):
		var r := Rect2(Vector2(tab.get_center().x - ancho * 0.5, y0 + float(i) * alto), Vector2(ancho, alto - 3.0))
		_boton_pestana("pagina:%d" % i, r, str(i + 1), i == c.page)


## Una pestaña sobre el cuero: tinta clara, sin la caja de pergamino de los botones de prueba.
func _boton_pestana(nombre: String, r: Rect2, texto: String, activo: bool) -> void:
	_botones[nombre] = r
	draw_rect(r, Color(0.98, 0.9, 0.75, 0.30) if activo else Color(0.0, 0.0, 0.0, 0.18))
	if activo:
		draw_rect(r, Color(1.0, 0.92, 0.7, 0.9), false, 1.5)
	_texto(Vector2(r.get_center().x, r.get_center().y + 5.0), texto, 14, Color(1.0, 0.94, 0.82) if activo else Color(1.0, 0.94, 0.82, 0.7), true, r.size.x - 2.0)


func _dibujar_trazado() -> void:
	var l: Rect2 = pagina_izq()
	var z: Dictionary = zona_trazado()
	var cz: Vector2 = z["centro"]
	var rz: float = z["radio"]
	# Una sola guía muy tenue: sin marco grueso.
	draw_arc(cz, rz, 0.0, TAU, 96, TINTA_GUIA, 1.5, true)
	draw_line(cz - Vector2(rz, 0.0), cz + Vector2(rz, 0.0), Color(TINTA_GUIA, 0.10), 1.0)
	draw_line(cz - Vector2(0.0, rz), cz + Vector2(0.0, rz), Color(TINTA_GUIA, 0.10), 1.0)
	var fam: String = familia_esperada()
	var titulo: String = texto_destino() if fam == "" else "%s · dibuja un %s" % [texto_destino(), fam]
	_texto(Vector2(l.get_center().x, l.position.y + 40.0), titulo, 18, TINTA, true, l.size.x - 40.0)
	# AYUDA AL DIBUJO: el gesto de práctica (del catálogo), animado; si no, el del símbolo que ya hay en el destino, tenue.
	var guia: String = ""
	var guia_elem: bool = false
	if practica != "":
		guia = practica
		guia_elem = practica_es_elemento
	else:
		var actual: String = _simbolo_actual_de(destino)
		if actual != "":
			guia = Sigils.repertorio_de(actual) if not GestureLibrary.ELEMENTS.has(actual) else actual
			guia_elem = GestureLibrary.ELEMENTS.has(actual)
	if guia != "":
		var texto_g: String = TrazosRectos.texto_guia(guia, guia_elem)
		if texto_g != "":
			var caja := Rect2(cz - Vector2(rz, rz) * 0.8, Vector2(rz, rz) * 1.6)
			if practica != "":
				_guia_animada(texto_g, caja, clampf(_t_practica / T_PRACTICA, 0.0, 1.0))
				_texto(Vector2(cz.x, cz.y - rz - 6.0), "Practica: %s" % _nombre_simbolo(practica), 14, Color(TINTA, 0.6), true, l.size.x - 40.0)
			else:
				TrazosRectos.dibujar_guia(self, texto_g, caja, Color(TINTA, 0.10), 2.0)
	# La chuleta MÍNIMA: solo los últimos símbolos de la familia esperada que se han escrito o practicado (la referencia completa está en la hoja de catálogo).
	# (5.ª vuelta: la chuleta va en las notas del personaje, fuera del libro; la zona de trazado queda limpia.)
	var col: Color = RECHAZO if _trazo_rechazado else TINTA
	for t in _trazos:
		if (t as PackedVector2Array).size() >= 2:
			draw_polyline(t, col, 3.0, true)
	if _trazo.size() >= 2:
		draw_polyline(_trazo, TINTA, 3.0, true)
	# El aviso, justo bajo la zona y siempre por encima de los botones de prueba.
	var y_aviso: float = minf(cz.y + rz + 24.0, l.end.y - 56.0)
	if aviso != "":
		_texto(Vector2(l.get_center().x, y_aviso), aviso, 16, RUBI, true, l.size.x - 40.0)
	elif _cuenta > 0.0 and not _trazos.is_empty():
		_texto(Vector2(l.get_center().x, y_aviso), "…", 18)


func _simbolo_actual_de(d: String) -> String:
	var c: Grimorio = caster()
	var f: Dictionary = _ficha()
	if c == null or f.is_empty():
		return ""
	match d:
		"nucleo":
			return c._gesture_name_of(f["element"])
		"nucleo2":
			return c._gesture_name_of(f["element2"])
		"hijo_nucleo":
			return String(hijo().get("elemento", ""))
	if d.begins_with("hijo_hueco:"):
		return String((hijo()["glifos"] as Array)[int(d.substr(11))])
	if d.begins_with("hueco:"):
		var i: int = int(d.substr(6))
		for g in glifos_en_huecos():
			if int(g["i"]) == i:
				return String(g["nombre"])
	return ""


func _nombre_simbolo(n: String) -> String:
	return n.capitalize() if GestureLibrary.ELEMENTS.has(n) else Sigils.nombre_visible(n)


## La guía de un gesto dibujándose (práctica): cada trazo con su punto de inicio y la punta que avanza.
func _guia_animada(texto: String, caja: Rect2, k: float) -> void:
	var lado: float = minf(caja.size.x, caja.size.y) * 0.78
	var origen: Vector2 = caja.get_center() - Vector2(lado, lado) * 0.5
	var lineas: Array = TrazosRectos.guia_polilineas(texto)
	var total: float = 0.0
	for linea in lineas:
		for j in range(1, (linea as PackedVector2Array).size()):
			total += (linea[j] - linea[j - 1]).length()
	var hasta: float = total * k
	TrazosRectos.dibujar_guia(self, texto, caja, Color(TINTA, 0.10), 2.0)
	for linea in lineas:
		var l: PackedVector2Array = linea
		var pts := PackedVector2Array([origen + l[0] * lado])
		draw_circle(pts[0], 4.0, Color(RUBI, 0.6))
		for j in range(1, l.size()):
			if hasta <= 0.0:
				break
			var seg: float = (l[j] - l[j - 1]).length()
			pts.append(origen + l[j - 1].lerp(l[j], clampf(hasta / seg, 0.0, 1.0)) * lado)
			hasta -= seg
		if pts.size() >= 2:
			draw_polyline(pts, Color(RUBI, 0.55), 3.0, true)
			draw_circle(pts[pts.size() - 1], 4.5, Color(RUBI, 0.8))
		if hasta <= 0.0:
			break


## Los recientes de la familia `fam` (como mucho 4), en pequeño; si no hay ninguno, un recordatorio de dónde está la hoja de catálogo.
func _dibujar_recientes(fam: String, caja: Rect2) -> void:
	var lista: Array = []
	for id in recientes:
		if (fam == "sello") == FAMILIA_SELLOS.has(String(id)) and TrazosRectos.texto_guia(String(id), fam == "sello") != "":
			lista.append(String(id))
	if lista.is_empty():
		_texto(Vector2(caja.get_center().x, caja.get_center().y + 5.0), "Todas las runas: catálogo (cierre derecho)", 12, Color(TINTA, 0.40), true, caja.size.x)
		return
	var paso: float = minf(caja.size.x / 4.0, 52.0)
	var x0: float = caja.get_center().x - paso * float(lista.size()) * 0.5
	for k in range(lista.size()):
		var celda := Rect2(Vector2(x0 + paso * float(k), caja.position.y), Vector2(paso, caja.size.y))
		TrazosRectos.dibujar_guia(self, TrazosRectos.texto_guia(String(lista[k]), fam == "sello"), celda, Color(TINTA, 0.40), 1.3)


func _dibujar_chuleta(fam: String, caja: Rect2) -> void:
	var lista: PackedStringArray = Repertoire.active_elements() if fam == "sello" else Repertoire.active_sigils()
	var n: int = 0
	for nombre in lista:
		if TrazosRectos.texto_guia(nombre, fam == "sello") != "":
			n += 1
	if n == 0:
		return
	var paso: float = minf(caja.size.x / float(n), 44.0)
	var x0: float = caja.get_center().x - paso * float(n) * 0.5
	var k: int = 0
	for nombre in lista:
		var t: String = TrazosRectos.texto_guia(nombre, fam == "sello")
		if t == "":
			continue
		TrazosRectos.dibujar_guia(self, t, Rect2(Vector2(x0 + paso * float(k), caja.position.y), Vector2(paso, caja.size.y)), Color(TINTA, 0.35), 1.2)
		k += 1


func _dibujar_conjuro() -> void:
	var c: Grimorio = caster()
	if c == null:
		return
	var r: Rect2 = pagina_der()
	var cc: Vector2 = centro_conjuro()
	var rc: float = radio_conjuro()
	# Cabecera: el nombre del hechizo (H16).
	var nombre: String = String(c.call("nombre_pagina", c.page)) if c.has_method("nombre_pagina") else ""
	_texto(Vector2(r.get_center().x, r.position.y + 44.0), nombre if nombre != "" else "Página %d vacía" % (c.page + 1), 22, TINTA, true, r.size.x - 40.0)
	# El doble contorno: una manifestación. Pulso al acabar de combinar.
	var pulso: float = 0.0
	if _t_combinar >= T_COMBINAR:
		pulso = 1.0 - clampf((_t_combinar - T_COMBINAR) / 0.35, 0.0, 1.0)
	_doble_contorno(cc, rc, Color(TINTA.lerp(RUBI, pulso), 1.0), 2.0 + 2.0 * pulso)
	# Los huecos de la corona (los abiertos).
	for g in glifos_en_huecos():
		var i: int = int(g["i"])
		_hueco(pos_hueco(i), radio_hueco(), "hueco:%d" % i, String(g["nombre"]))
		if orden_por_huecos:
			_texto(pos_hueco(i) + Vector2(radio_hueco() * 0.95, -radio_hueco() * 0.75), str(i + 1), 12, Color(TINTA, 0.55))
	# El núcleo: uno o dos alojamientos de sello.
	var f: Dictionary = _ficha()
	var ps: Array = pos_sellos()
	if ps.size() == 1:
		var e1: String = c._gesture_name_of(f["element"]) if not f.is_empty() else ""
		_alojamiento(cc, radio_nucleo(), "nucleo", e1)
		if e1 != "":
			# La marca para combinar un segundo sello (estructura B).
			var mc: Vector2 = pos_marca_combinar()
			var selc: bool = destino == "nucleo2"
			draw_circle(mc, rc * 0.075, PERGAMINO)
			draw_arc(mc, rc * 0.075, 0.0, TAU, 32, SELECCION if selc else Color(TINTA, 0.6), 1.6, true)
			draw_line(mc - Vector2(rc * 0.04, 0.0), mc + Vector2(rc * 0.04, 0.0), Color(TINTA, 0.7), 1.6)
			draw_line(mc - Vector2(0.0, rc * 0.04), mc + Vector2(0.0, rc * 0.04), Color(TINTA, 0.7), 1.6)
	else:
		# Estructura B: dos alojamientos en el MISMO contorno y una conexión interior sencilla.
		var rn: float = radio_nucleo() * 0.62
		draw_line(ps[0] + Vector2(rn, 0.0), ps[1] - Vector2(rn, 0.0), TINTA, 1.6)
		for k in range(2):
			var dk: String = "nucleo" if k == 0 else "nucleo2"
			var ek: String = c._gesture_name_of(f["element"] if k == 0 else f["element2"]) if not f.is_empty() else ""
			_alojamiento(ps[k], rn, dk, ek)
		var par: Dictionary = c.rune_de_ficha(f) if not f.is_empty() else {}
		if String(par.get("estado", "")) == CombosSellos.SE_ANULAN:
			var rx: float = rc * 0.18
			draw_line(cc + Vector2(-rx, -rx), cc + Vector2(rx, rx), RUBI, 3.0, true)       # se anulan: la cruz, como en el HUD
			draw_line(cc + Vector2(-rx, rx), cc + Vector2(rx, -rx), RUBI, 3.0, true)
		if String(par.get("nombre", "")) != "":
			_texto(Vector2(cc.x, cc.y + radio_nucleo() + 26.0), String(par["nombre"]), 16, Color(TINTA, 0.8))
	_dibujar_escritura()
	_dibujar_coste(Vector2(r.get_center().x, cc.y + rc + 40.0), r.size.x * 0.55)


func _hueco(p: Vector2, radio: float, d: String, nombre: String) -> void:
	var sel: bool = destino == d
	draw_circle(p, radio, Color(PERGAMINO_SOMBRA, 0.35))
	draw_arc(p, radio, 0.0, TAU, 48, SELECCION if sel else Color(TINTA, 0.45), 2.5 if sel else 1.2, true)
	if sel:
		draw_arc(p, radio * 1.18, 0.0, TAU, 48, Color(SELECCION, 0.5), 1.2, true)       # doble borde: no depende solo del color
	if nombre != "":
		_simbolo(nombre, p, radio * 0.62, d)


func _alojamiento(p: Vector2, radio: float, d: String, nombre: String) -> void:
	var sel: bool = destino == d
	draw_circle(p, radio, Color(PERGAMINO_SOMBRA, 0.4))
	draw_arc(p, radio, 0.0, TAU, 64, SELECCION if sel else TINTA, 2.5 if sel else 1.6, true)
	if sel:
		draw_arc(p, radio * 1.1, 0.0, TAU, 64, Color(SELECCION, 0.5), 1.2, true)
	if nombre != "":
		_simbolo(nombre, p, radio * 0.62, d)


## Un símbolo ya escrito (o escribiéndose): mientras la tinta lo escribe, sus trazos a medias; después, la runa de la lámina.
func _simbolo(nombre: String, p: Vector2, radio: float, d: String) -> void:
	if not _escritura.is_empty() and String(_escritura["destino"]) == d:
		return                                   # lo pinta `_dibujar_escritura`
	var tex: Texture2D = _textura_de(nombre)
	if tex != null:
		var lado := Vector2.ONE * radio * 2.0
		draw_texture_rect(tex, Rect2(p - lado * 0.5, lado), false, TINTA)
		return
	for poli in polilineas(nombre):
		var pts := PackedVector2Array()
		for q in poli:
			pts.append(p + (q as Vector2) * radio * 1.6)
		draw_polyline(pts, TINTA, 3.0, true)


func _dibujar_escritura() -> void:
	if _escritura.is_empty():
		return
	var pr: Array = _pos_y_radio_de(String(_escritura["destino"]))
	var p: Vector2 = pr[0]
	var radio: float = float(pr[1]) * 0.62
	var polis: Array = _escritura["polis"]
	var k: float = clampf(float(_escritura["t"]) / T_ESCRITURA, 0.0, 1.0)
	if polis.is_empty():
		var tex: Texture2D = _textura_de(String(_escritura["simbolo"]))
		if tex != null:
			var lado := Vector2.ONE * radio * 2.0
			draw_texture_rect(tex, Rect2(p - lado * 0.5, lado), false, Color(TINTA, k))
		return
	var total: float = 0.0
	for poli in polis:
		for j in range(1, (poli as PackedVector2Array).size()):
			total += (poli[j] - poli[j - 1]).length()
	var hasta: float = total * k
	var punta: Vector2 = p
	for poli in polis:
		var pts := PackedVector2Array([p + (poli[0] as Vector2) * radio * 1.6])
		for j in range(1, (poli as PackedVector2Array).size()):
			var seg: float = (poli[j] - poli[j - 1]).length()
			if hasta <= 0.0:
				break
			var q: Vector2 = poli[j - 1].lerp(poli[j], clampf(hasta / seg, 0.0, 1.0))
			pts.append(p + q * radio * 1.6)
			punta = pts[pts.size() - 1]
			hasta -= seg
		if pts.size() >= 2:
			draw_polyline(pts, TINTA_HUMEDA, 3.4, true)
		if hasta <= 0.0:
			break
	if k < 1.0:
		draw_circle(punta, 4.0, TINTA_HUMEDA)     # la punta de tinta: una pequeña acumulación oscura que avanza


func _dibujar_coste(centro: Vector2, ancho: float) -> void:
	var c: Grimorio = caster()
	if c == null:
		return
	var res: Dictionary = c.resumen_pagina(c.page)
	if res.is_empty() or bool(res.get("vacia", true)):
		return
	var coste: float = float(res.get("tinta_prevista", 0.0))
	var t: Tinta = c.get("tinta") as Tinta
	var hay: float = t.actual if t != null else Tinta.MAXIMA_INICIAL
	var tope: float = maxf(Tinta.MAXIMA_INICIAL, hay)
	var r := Rect2(centro - Vector2(ancho * 0.5, 0.0), Vector2(ancho, 10.0))
	draw_rect(r, Color(TINTA, 0.10))
	draw_rect(Rect2(r.position, Vector2(ancho * clampf(coste / tope, 0.0, 1.0), r.size.y)), Color(RUBI, 0.75) if coste > hay else Color(TINTA, 0.65))
	draw_line(Vector2(r.position.x + ancho * clampf(hay / tope, 0.0, 1.0), r.position.y - 3.0), Vector2(r.position.x + ancho * clampf(hay / tope, 0.0, 1.0), r.end.y + 3.0), RUBI, 2.0)
	_texto(Vector2(centro.x, r.end.y + 20.0), "tinta %d de %d" % [int(ceil(coste)), int(hay)], 14, Color(TINTA, 0.8))


## El catálogo se abre con el CIERRE del lateral derecho de la lámina. La capacidad se ve siempre, en pequeño, al pie de la página derecha.
## LAS NOTAS DEL PERSONAJE, a la izquierda del libro: tres hojas apiladas (Sellos · Unión · Glifos) y delante la del destino elegido.
func _dibujar_notas() -> void:
	var r: Rect2 = notas_rect()
	if r.size.x < 80.0:
		return
	actualizar_candidatos()
	var tabs: Array = [["sellos", "Sellos"], ["union", "Unión"], ["glifos", "Glifos"]]
	var delante: String = tab_notas()
	# Las hojas de detrás asoman arriba con su pestaña (clic = abre el cuaderno por esa pestaña).
	var k: int = 0
	for t in tabs:
		if String(t[0]) == delante:
			continue
		var hoja := Rect2(r.position + Vector2(6.0 + float(k) * 14.0, float(k) * 30.0), Vector2(r.size.x - 20.0, 60.0))
		draw_rect(hoja, PERGAMINO_SOMBRA)
		draw_rect(hoja, Color(TINTA, 0.25), false, 1.0)
		_texto(Vector2(hoja.position.x + 12.0, hoja.position.y + 22.0), String(t[1]), 15, Color(TINTA, 0.7), false, hoja.size.x - 20.0)
		_botones["tabc:%s" % String(t[0])] = Rect2(hoja.position, Vector2(hoja.size.x, 28.0))
		k += 1
	# La hoja de delante.
	var f := Rect2(r.position + Vector2(0.0, 62.0), r.size - Vector2(0.0, 62.0))
	draw_rect(f.grow(2.0), Color(0.0, 0.0, 0.0, 0.18))
	draw_rect(f, PERGAMINO)
	draw_rect(f, Color(TINTA, 0.30), false, 1.0)
	var titulo: String = {"sellos": "Sellos", "union": "Unión", "glifos": "Glifos"}[delante]
	_texto(Vector2(f.get_center().x, f.position.y + 34.0), titulo, 24, TINTA, true, f.size.x - 20.0)
	draw_line(Vector2(f.position.x + 20.0, f.position.y + 44.0), Vector2(f.end.x - 20.0, f.position.y + 44.0), Color(TINTA, 0.5), 1.0)
	var y: float = f.position.y + 56.0
	if delante == "union":
		for u in UNION:
			_texto(Vector2(f.position.x + 14.0, y + 14.0), String(u[0]), 16, TINTA, false, f.size.x - 24.0)
			_texto(Vector2(f.position.x + 14.0, y + 32.0), String(u[1]), 11, Color(TINTA, 0.65), false, f.size.x - 24.0)
			y += 48.0
		return
	var ids: Array = ids_de_tab(delante)
	var alto: float = clampf((f.end.y - 30.0 - y) / maxf(float(ids.size()), 1.0), 20.0, 40.0)
	for id in ids:
		var vivo: bool = candidato_vivo(String(id))
		var lider: bool = candidato_lider() == String(id)
		var col: Color = Color(TINTA, 1.0 if vivo else 0.22)
		var caja := Rect2(Vector2(f.position.x + 10.0, y + 2.0), Vector2(alto - 4.0, alto - 4.0))
		var t: String = TrazosRectos.texto_guia(String(id), delante == "sellos")
		if t != "":
			TrazosRectos.dibujar_guia(self, t, caja, col, 1.4)          # con el punto de inicio y la flecha: cómo se dibuja
		_texto(Vector2(caja.end.x + 8.0, y + alto * 0.5 + 5.0), verbo_de(id), 15, col, false, f.size.x - alto - 40.0)
		if lider:
			_texto(Vector2(f.end.x - 18.0, y + alto * 0.5 + 6.0), "✓", 18, RUBI)
			draw_line(Vector2(caja.end.x + 8.0, y + alto - 4.0), Vector2(f.end.x - 26.0, y + alto - 4.0), Color(RUBI, 0.6), 1.2)
		# El último intento fallido, TACHADO junto a la runa que parecía.
		if ultimo_rechazo.get("tab", "") == delante and String(ultimo_rechazo.get("parece", "")) == String(id):
			_tachon(Rect2(Vector2(f.end.x - alto - 6.0, y + 2.0), Vector2(alto - 6.0, alto - 6.0)), ultimo_rechazo.get("trazos", []))
		_botones["nota:%s" % String(id)] = Rect2(Vector2(f.position.x, y), Vector2(f.size.x, alto))
		y += alto
	var faltan: int = por_descubrir(delante)
	if faltan > 0:
		_texto(Vector2(f.get_center().x, f.end.y - 12.0), "%d por descubrir" % faltan, 12, Color(TINTA, 0.5), true, f.size.x - 20.0)


## Un trazo en miniatura dentro de `caja`, tachado con una X: el intento que no se reconoció.
func _tachon(caja: Rect2, trazos: Array) -> void:
	var todo := Rect2()
	var primero: bool = true
	for t in trazos:
		for p in (t as PackedVector2Array):
			todo = Rect2(p, Vector2.ZERO) if primero else todo.expand(p)
			primero = false
	if primero:
		return
	var lado: float = maxf(todo.size.x, todo.size.y)
	if lado < 0.001:
		return
	for t in trazos:
		var pts := PackedVector2Array()
		for p in (t as PackedVector2Array):
			pts.append(caja.position + (p - todo.position) / lado * caja.size.x)
		if pts.size() >= 2:
			draw_polyline(pts, Color(TINTA, 0.45), 1.2, true)
	draw_line(caja.position, caja.end, Color(RUBI, 0.6), 1.4)
	draw_line(Vector2(caja.end.x, caja.position.y), Vector2(caja.position.x, caja.end.y), Color(RUBI, 0.6), 1.4)


## EL CUADERNO: la página extendida de runas, a doble página sobre el libro (mientras se consulta no se compone). Índice a la izquierda, por pestañas, y a la derecha
## la runa elegida: su verbo, cómo se dibuja (animado, con el punto de inicio y el sentido), cuántos trazos, una frase, con qué vale, y un RECUADRO DE PRÁCTICA:
## se dibuja ahí y el reconocedor contesta sin tocar el conjuro.
func cuaderno_rect() -> Rect2:
	return libro_rect().grow(-libro_rect().size.y * 0.03)


func caja_practica() -> Rect2:
	var c: Rect2 = cuaderno_rect()
	var mitad: float = c.size.x * 0.5
	var lado: float = minf(c.size.y * 0.40, mitad * 0.55)
	return Rect2(Vector2(c.position.x + mitad + mitad * 0.5 - lado * 0.5, c.end.y - lado - 30.0), Vector2(lado, lado))


func _dibujar_cuaderno() -> void:
	var c: Rect2 = cuaderno_rect()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.35))
	draw_rect(c.grow(4.0), Color(0.0, 0.0, 0.0, 0.25))
	draw_rect(c, PERGAMINO)
	draw_rect(c, Color(TINTA, 0.35), false, 1.5)
	var mitad: float = c.size.x * 0.5
	draw_line(Vector2(c.position.x + mitad, c.position.y + 12.0), Vector2(c.position.x + mitad, c.end.y - 12.0), Color(TINTA, 0.25), 1.0)
	_texto(Vector2(c.position.x + mitad * 0.5, c.position.y + 36.0), "Cuaderno de runas", 22, TINTA, true, mitad - 30.0)
	_texto(Vector2(c.position.x + mitad * 0.5, c.position.y + 56.0), texto_capacidad(), 12, Color(TINTA, 0.55), true, mitad - 30.0)
	# Pestañas.
	var tabs: Array = [["sellos", "Sellos"], ["union", "Unión"], ["glifos", "Glifos"]]
	for k in range(tabs.size()):
		var rr := Rect2(Vector2(c.position.x + 20.0 + float(k) * ((mitad - 40.0) / 3.0), c.position.y + 66.0), Vector2((mitad - 40.0) / 3.0 - 6.0, 26.0))
		_boton("tabc:%s" % String(tabs[k][0]), rr, String(tabs[k][1]), cuaderno_tab == String(tabs[k][0]))
	_boton("cerrar_cuaderno", Rect2(Vector2(c.end.x - 110.0, c.position.y + 14.0), Vector2(96.0, 26.0)), "Cerrar")
	# Índice.
	var y: float = c.position.y + 104.0
	if cuaderno_tab == "union":
		for u in UNION:
			_texto(Vector2(c.position.x + 24.0, y + 16.0), String(u[0]), 16, TINTA, false, mitad - 40.0)
			_texto(Vector2(c.position.x + 24.0, y + 34.0), String(u[1]), 12, Color(TINTA, 0.65), false, mitad - 40.0)
			y += 52.0
		_texto(Vector2(c.position.x + mitad * 1.5, c.get_center().y), "La unión se escribe en el conjuro, no se dibuja.", 14, Color(TINTA, 0.6), true, mitad - 40.0)
		return
	var ids: Array = ids_de_tab(cuaderno_tab)
	var alto: float = clampf((c.end.y - 40.0 - y) / maxf(float(ids.size()), 1.0), 22.0, 40.0)
	for id in ids:
		var sel: bool = sel_catalogo == String(id)
		var caja := Rect2(Vector2(c.position.x + 24.0, y + 2.0), Vector2(alto - 4.0, alto - 4.0))
		if sel:
			draw_rect(Rect2(Vector2(c.position.x + 16.0, y), Vector2(mitad - 32.0, alto)), Color(RUBI, 0.10))
		TrazosRectos.dibujar_guia(self, TrazosRectos.texto_guia(String(id), cuaderno_tab == "sellos"), caja, TINTA, 1.3)
		_texto(Vector2(caja.end.x + 10.0, y + alto * 0.5 + 5.0), verbo_de(id), 15, TINTA, false, mitad - alto - 60.0)
		_botones["cat:%s" % String(id)] = Rect2(Vector2(c.position.x + 16.0, y), Vector2(mitad - 32.0, alto))
		y += alto
	var faltan: int = por_descubrir(cuaderno_tab)
	if faltan > 0:
		_texto(Vector2(c.position.x + mitad * 0.5, c.end.y - 16.0), "%d por descubrir" % faltan, 12, Color(TINTA, 0.5), true, mitad - 30.0)
	# La runa elegida.
	if not conocido(sel_catalogo) or not ids.has(sel_catalogo):
		if not ids.is_empty():
			sel_catalogo = String(ids[0])
		else:
			return
	var x: float = c.position.x + mitad + 24.0
	var es_sello: bool = cuaderno_tab == "sellos"
	var t: String = TrazosRectos.texto_guia(sel_catalogo, es_sello)
	_texto(Vector2(x, c.position.y + 44.0), verbo_de(sel_catalogo), 26, TINTA, false, mitad - 140.0)
	var futhark: String = String((GestureLibrary.BIBLIA.get(sel_catalogo, {}) as Dictionary).get("futhark", ""))
	var n_trazos: int = 1 if t == "" else t.split("|").size()
	_texto(Vector2(x, c.position.y + 68.0), "%s · %d %s" % [futhark if futhark != "" else _nombre_simbolo(sel_catalogo), n_trazos, "trazo" if n_trazos == 1 else "trazos"], 13, Color(TINTA, 0.6), false, mitad - 40.0)
	var lado: float = minf(c.size.y * 0.30, mitad * 0.42)
	if t != "":
		_guia_animada(t, Rect2(Vector2(x, c.position.y + 82.0), Vector2(lado, lado)), clampf(_t_practica / T_PRACTICA, 0.0, 1.0))
	var fi: Array = ficha_de(sel_catalogo)
	var xt: float = x + lado + 16.0
	_texto(Vector2(xt, c.position.y + 104.0), String(fi[0]), 14, TINTA, false, c.end.x - xt - 20.0)
	if String(fi[1]) != "":
		_texto(Vector2(xt, c.position.y + 126.0), "Vale con: %s" % String(fi[1]), 12, Color(TINTA, 0.65), false, c.end.x - xt - 20.0)
	_boton("practicar_sel", Rect2(Vector2(xt, c.position.y + 142.0), Vector2(150.0, 26.0)), "▶ Practicar en el libro")
	# El recuadro de práctica.
	var p: Rect2 = caja_practica()
	draw_rect(p, Color(PERGAMINO_SOMBRA, 0.35))
	draw_rect(p, Color(TINTA, 0.35), false, 1.0)
	_texto(Vector2(p.get_center().x, p.position.y - 8.0), "Practica aquí: dibuja «%s»" % verbo_de(sel_catalogo), 13, Color(TINTA, 0.7), true, p.size.x + 80.0)
	for tr in _prac_trazos:
		if (tr as PackedVector2Array).size() >= 2:
			draw_polyline(tr, TINTA, 3.0, true)
	if _prac_trazo.size() >= 2:
		draw_polyline(_prac_trazo, TINTA, 3.0, true)
	if prac_resultado != "":
		_texto(Vector2(p.get_center().x, p.end.y + 20.0), prac_resultado, 15, Color(0.15, 0.45, 0.15) if prac_ok else RUBI, true, p.size.x + 120.0)


## Cierra el gesto del recuadro de práctica: lo rectifica a la escala del recuadro y lo reconoce contra la familia de la pestaña. No toca el conjuro.
## Público para las pruebas (`trazos` sustituye a lo dibujado). Devuelve true si salió la runa que se practica.
func evaluar_practica(trazos: Array = []) -> bool:
	var crudos: Array = trazos if not trazos.is_empty() else _prac_trazos.duplicate()
	_prac_cuenta = 0.0
	if crudos.is_empty():
		return false
	var rz: float = caja_practica().size.x * 0.5
	var prep: Array = GestureRectify.rectificar_gesto(crudos, rz * ESCALA_RECTIFICADO, rz * ESCALA_FORMA) if Estado.i().trazo_recto else crudos
	var leido: String = ""
	var es_sello: bool = cuaderno_tab == "sellos"
	if not es_sello and prep.size() == 1 and _es_raya(prep[0]):
		leido = "linea"
	else:
		var r: Dictionary = TrazosRectos.reconocer(prep, TrazosRectos.ELEMENTOS if es_sello else TrazosRectos.SELLOS)
		if bool(r.get("accepted", false)):
			leido = String(r["name"])
		else:
			leido = "?" + String(r.get("name", ""))
	prac_ok = leido == sel_catalogo
	if prac_ok:
		prac_resultado = "¡Bien! Eso es «%s»." % verbo_de(leido)
	elif leido.begins_with("?"):
		prac_resultado = "No lo reconozco (se parece a «%s»)." % verbo_de(leido.substr(1))
	else:
		prac_resultado = "Eso es «%s», no «%s»." % [verbo_de(leido), verbo_de(sel_catalogo)]
	PlayLog.event("libro_rojo_practica", {"practica": sel_catalogo, "leido": leido, "ok": prac_ok})
	_prac_trazos.clear()
	queue_redraw()
	return prac_ok


func _gui_cuaderno(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb: InputEventMouseButton = ev
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			for nombre in _botones:
				if (_botones[nombre] as Rect2).has_point(mb.position) and (String(nombre).begins_with("cat:") or String(nombre).begins_with("tabc:") or nombre == "cerrar_cuaderno" or nombre == "practicar_sel" or nombre == "catalogo"):
					_pulsar(String(nombre))
					return
			if caja_practica().has_point(mb.position) and cuaderno_tab != "union":
				if not prac_resultado.is_empty() and _prac_trazos.is_empty():
					prac_resultado = ""
				_prac_dibujando = true
				_prac_trazo = PackedVector2Array([mb.position])
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and _prac_dibujando:
			_prac_dibujando = false
			if _prac_trazo.size() >= 2:
				_prac_trazos.append(_prac_trazo)
				_prac_cuenta = T_PRACTICA_CUADERNO
			_prac_trazo = PackedVector2Array()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_prac_trazos.clear()
			prac_resultado = ""
	elif ev is InputEventMouseMotion and _prac_dibujando:
		var p: Vector2 = (ev as InputEventMouseMotion).position
		if _prac_trazo.is_empty() or _prac_trazo[_prac_trazo.size() - 1].distance_to(p) >= MIN_DIST_PUNTO:
			_prac_trazo.append(p)
	accept_event()
	queue_redraw()


## Abre el cuaderno en una runa (o en su pestaña).
func abrir_cuaderno(id: String = "", tab: String = "") -> void:
	catalogo_abierto = true
	if id != "":
		sel_catalogo = id
		cuaderno_tab = "sellos" if FAMILIA_SELLOS.has(id) else "glifos"
	elif tab != "":
		cuaderno_tab = tab
	_prac_trazos.clear()
	prac_resultado = ""
	_t_practica = 0.0
	queue_redraw()


func _dibujar_pestana_catalogo() -> void:
	var cierre: Rect2 = de_lamina(CIERRE_DER_LAM)
	_botones["catalogo"] = cierre
	if catalogo_abierto:
		draw_arc(cierre.get_center(), minf(cierre.size.x, cierre.size.y) * 0.32, 0.0, TAU, 32, Color(1.0, 0.92, 0.7, 0.9), 2.0, true)
	var r: Rect2 = pagina_der()
	_texto(Vector2(r.get_center().x, r.end.y - 14.0), "Catálogo (cierre derecho) · %s" % texto_capacidad(), 13, Color(TINTA, 0.65), true, r.size.x - 30.0)


func texto_capacidad() -> String:
	var cap_s: String = str(Repertoire.max_elementos) if Repertoire.max_elementos > 0 else "∞"
	var cap_g: String = str(Repertoire.max_glifos) if Repertoire.max_glifos > 0 else "∞"
	return "sellos %d/%s · glifos %d/%s" % [Repertoire.active_elements().size(), cap_s, Repertoire.active_sigils().size(), cap_g]


## LA HOJA DE CATÁLOGO, sobre la página izquierda (ver FAMILIA_* y FICHAS): sellos aparte, FORMA, POTENCIA y CONDICIONES (bloqueadas), en huecos fijos con candado
## lo que aún no se tiene, y la FICHA del elegido al pie, con su trazo animado y «Practicar». Clic en un símbolo = su ficha; «Practicar» = su gesto en la zona de trazado.
func _dibujar_catalogo() -> void:
	var l: Rect2 = pagina_izq()
	var x0: float = l.position.x + 18.0
	var ancho: float = l.size.x - 36.0
	var y: float = l.position.y + 26.0
	_texto(Vector2(l.get_center().x, y), "Catálogo · %s" % texto_capacidad(), 16, TINTA, true, ancho)
	y += 16.0
	var r: float = clampf(ancho / 9.0 * 0.40, 12.0, 20.0)        # radio de un hueco: caben 9 en una fila
	var paso: float = ancho / 9.0
	y = _fila_familia("SELLOS", "", FAMILIA_SELLOS, x0, y, paso, r)
	y = _fila_familia("FORMA", "cómo se mueve o crece · no sube el daño", FAMILIA_FORMA, x0, y, paso, r)
	y = _fila_familia("POTENCIA", "lo que sube el daño", FAMILIA_POTENCIA, x0, y, paso, r)
	# Condiciones: la página de dos círculos (H12, H15), aún bloqueadas.
	_texto(Vector2(x0, y + 12.0), "CONDICIONES · dos círculos", 13, TINTA, false, ancho)
	var cx: float = x0
	var ch: float = 22.0
	for cnd in FAMILIA_CONDICIONES:
		var w: float = (ancho - 12.0) / float(FAMILIA_CONDICIONES.size())
		var rr := Rect2(Vector2(cx, y + 20.0), Vector2(w - 4.0, ch))
		draw_rect(rr, Color(TINTA, 0.06))
		draw_rect(rr, Color(TINTA, 0.25), false, 1.0)
		_candado(Vector2(rr.position.x + 10.0, rr.get_center().y), 4.0)
		_texto(Vector2(rr.get_center().x + 6.0, rr.get_center().y + 5.0), String(cnd), 11, Color(TINTA, 0.45), true, rr.size.x - 20.0)
		cx += w
	y += 20.0 + ch + 12.0
	# La ficha del elegido, fija al pie (no flota: no tapa nada).
	_dibujar_ficha(Rect2(Vector2(x0, y), Vector2(ancho, l.end.y - 14.0 - y)))


## Una familia: su rótulo y sus huecos fijos (hasta 9 por fila). Lo conocido con su runa (clic = ficha); lo que falta, con candado. Devuelve la y de debajo.
func _fila_familia(titulo: String, nota: String, ids: Array, x0: float, y: float, paso: float, r: float) -> float:
	_texto(Vector2(x0, y + 12.0), titulo + ("" if nota == "" else "  · " + nota), 13, TINTA, false, paso * 9.0)
	var cy: float = y + 22.0 + r
	for k in range(ids.size()):
		var id: String = String(ids[k])
		var p := Vector2(x0 + paso * (float(k) + 0.5), cy)
		var sel: bool = sel_catalogo == id
		var tiene: bool = conocido(id)
		draw_circle(p, r, Color(PERGAMINO_SOMBRA, 0.35) if tiene else Color(TINTA, 0.06))
		draw_arc(p, r, 0.0, TAU, 32, SELECCION if sel else Color(TINTA, 0.40 if tiene else 0.20), 2.0 if sel else 1.0, true)
		_botones["cat:%s" % id] = Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0)
		if tiene:
			var tex: Texture2D = _textura_de(id)
			if tex != null:
				draw_texture_rect(tex, Rect2(p - Vector2(r, r) * 0.68, Vector2(r, r) * 1.36), false, TINTA)
			else:
				var t: String = TrazosRectos.texto_guia(id, FAMILIA_SELLOS.has(id))
				if t != "":
					TrazosRectos.dibujar_guia(self, t, Rect2(p - Vector2(r, r) * 0.8, Vector2(r, r) * 1.6), TINTA, 1.4)
		else:
			_candado(p, r * 0.45)
	return cy + r + 8.0


func _candado(p: Vector2, s: float) -> void:
	var col := Color(TINTA, 0.35)
	draw_rect(Rect2(p + Vector2(-s, -s * 0.1), Vector2(s * 2.0, s * 1.3)), col)
	draw_arc(p + Vector2(0.0, -s * 0.1), s * 0.65, PI, TAU, 12, col, 1.6, true)


## La ficha (H8): nombre, una frase, con qué vale y el trazo animado; «Practicar» lo lleva a la zona de trazado. Lo que aún no se tiene, bloqueado.
func _dibujar_ficha(caja: Rect2) -> void:
	if caja.size.y < 40.0:
		return
	draw_rect(caja, Color(PERGAMINO_SOMBRA, 0.30))
	draw_rect(caja, Color(TINTA, 0.30), false, 1.0)
	var id: String = sel_catalogo
	var tiene: bool = conocido(id)
	var lado: float = minf(caja.size.y - 16.0, caja.size.x * 0.32)
	var caja_trazo := Rect2(Vector2(caja.end.x - lado - 8.0, caja.position.y + 8.0), Vector2(lado, lado))
	var ancho_txt: float = caja.size.x - lado - 28.0
	var x: float = caja.position.x + 10.0
	var nombre: String = _nombre_simbolo(id)
	var futhark: String = String(GestureLibrary.BIBLIA.get(id, {}).get("futhark", "")) if GestureLibrary.BIBLIA.has(id) else ""
	_texto(Vector2(x, caja.position.y + 22.0), ("%s %s" % [futhark, nombre]).strip_edges() + ("" if tiene else "  · bloqueado"), 16, TINTA, false, ancho_txt)
	var f: Array = ficha_de(id)
	_texto(Vector2(x, caja.position.y + 44.0), String(f[0]) if tiene else "Aún no lo tienes.", 13, Color(TINTA, 0.85), false, ancho_txt)
	if tiene and String(f[1]) != "":
		_texto(Vector2(x, caja.position.y + 64.0), "Vale con: %s" % String(f[1]), 12, Color(TINTA, 0.65), false, ancho_txt)
	var t: String = TrazosRectos.texto_guia(id, FAMILIA_SELLOS.has(id))
	if tiene and t != "":
		_guia_animada(t, caja_trazo, clampf(_t_practica / T_PRACTICA, 0.0, 1.0))
		_boton("practicar_sel", Rect2(Vector2(x, caja.end.y - 34.0), Vector2(110.0, 26.0)), "▶ Practicar")


## Estructura C (anidación, H12): principal arriba a la izquierda, hijo abajo a la derecha, cada uno con su doble contorno, y un enlace con la condición y su dirección.
## EDITABLE (sellos, glifos, condición, mover glifos; 6 glifos en total), pero NO se lanza todavía.
func _dibujar_anidacion() -> void:
	var c: Grimorio = caster()
	var r: Rect2 = pagina_der()
	var rc: float = radio_anidado()
	var p1: Vector2 = centro_principal()
	var p2: Vector2 = centro_hijo()
	_texto(Vector2(r.get_center().x, r.position.y + 44.0), "Anidación · %d/%d glifos en total (no se lanza aún)" % [n_glifos_total(), tope_total()], 18, TINTA, true, r.size.x - 40.0)
	_doble_contorno(p1, rc)
	_doble_contorno(p2, rc)
	# El enlace (sin envolvente común) con su condición y una marca de dirección.
	var a: Vector2 = p1 + (p2 - p1).normalized() * rc
	var bfin: Vector2 = p2 - (p2 - p1).normalized() * rc
	draw_line(a, bfin, TINTA, 2.0, true)
	var m: Vector2 = pos_condicion()
	var selc: bool = destino == "condicion"
	var rombo := PackedVector2Array([m + Vector2(0, -16), m + Vector2(16, 0), m + Vector2(0, 16), m + Vector2(-16, 0), m + Vector2(0, -16)])
	draw_colored_polygon(rombo, PERGAMINO)
	draw_polyline(rombo, SELECCION if selc else TINTA, 2.5 if selc else 2.0, true)
	draw_circle(m, 4.0, TINTA)
	var flecha: Vector2 = a.lerp(bfin, 0.80)
	var d: Vector2 = (bfin - a).normalized()
	var lado: Vector2 = Vector2(-d.y, d.x)
	draw_line(flecha, flecha - d * 10.0 + lado * 6.0, TINTA, 2.0, true)
	draw_line(flecha, flecha - d * 10.0 - lado * 6.0, TINTA, 2.0, true)
	_texto(m + Vector2(30.0, -10.0), texto_condicion(), 14, TINTA, false)
	if c == null:
		return
	var f: Dictionary = _ficha()
	# Principal: lo que hay en la página del lanzador.
	_alojamiento(p1, rc * 0.38, "nucleo", c._gesture_name_of(f["element"]) if not f.is_empty() else "")
	var gs: Array = glifos_en_huecos()
	for g in gs:
		_hueco(pos_hueco_anidado(false, int(g["i"])), rc * 0.16, "hueco:%d" % int(g["i"]), String(g["nombre"]))
	# Hijo: su sello y sus glifos (en la página, `hijo`).
	var h: Dictionary = hijo()
	_alojamiento(p2, rc * 0.38, "hijo_nucleo", String(h.get("elemento", "")))
	for k in range(Grimorio.huecos_abiertos()):
		_hueco(pos_hueco_anidado(true, k), rc * 0.16, "hijo_hueco:%d" % k, String((h["glifos"] as Array)[k]))
	_dibujar_escritura()


func _dibujar_botones() -> void:
	if catalogo_abierto:
		return                                   # el catálogo usa toda la página izquierda (sus filas de abajo quedaban bajo los botones)
	var l: Rect2 = pagina_izq()
	var y: float = l.end.y - 46.0
	var x: float = l.position.x + 18.0
	var w: float = (l.size.x - 36.0 - 30.0) / 4.0
	# Etiquetas cortas: con las notas a la izquierda el libro es más estrecho y las largas se cortaban («Orden: dibuj»).
	_boton("orden", Rect2(Vector2(x, y), Vector2(w, 32.0)), "Huecos" if orden_por_huecos else "Dibujo", orden_por_huecos)
	_boton("anidacion", Rect2(Vector2(x + (w + 10.0), y), Vector2(w, 32.0)), "Anidar", ver_anidacion)
	_boton("vaciar", Rect2(Vector2(x + (w + 10.0) * 2.0, y), Vector2(w, 32.0)), "Vaciar")
	if ver_anidacion:
		_boton("mover", Rect2(Vector2(x + (w + 10.0) * 3.0, y), Vector2(w, 32.0)), "Mover")
	elif _pagina_tiene_dos_sellos():
		_boton("separar", Rect2(Vector2(x + (w + 10.0) * 3.0, y), Vector2(w, 32.0)), "Separar")
	_texto(Vector2(x, y - 6.0), "Orden de los glifos:", 11, Color(TINTA, 0.55), false, w * 2.0)
	if practica != "":
		_boton("sin_practica", Rect2(Vector2(l.end.x - 140.0, l.position.y + 56.0), Vector2(120.0, 28.0)), "Quitar práctica")
