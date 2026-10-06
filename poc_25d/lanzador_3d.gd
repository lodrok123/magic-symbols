class_name Lanzador3D
extends "res://spellcaster.gd"

## LANZADOR DE HECHIZOS EN 3D (Test 3). Dueño: Juego.
##
## Sustituye a spellcaster.gd en la maqueta 3D. HEREDA de él (el grimorio, el reconocedor $P, las tres páginas,
## la recarga y el aviso de fallos son los mismos) y cambia solo dos cosas:
##   1. Las REGLAS DEL LIBRO: un glifo por sector (el segundo se rechaza con aviso) y una receta por página
##      (con ratón, todos los glifos de la página se funden en un hechizo). `pilar` y `retardo` no están activos.
##   2. QUÉ SALE al lanzar: ya no hay Area2D ni Spell; la receta (SpellRecipe, sin tocarla) se lee en CASILLAS y se
##      materializa en 3D con el modo lanzar (4.1b), la tierra y el hielo que caducan (4.1c) y la altura (4.4).
##
## CONTRATO on_spell_hit (publicado en docs/DIARIO.md, 2026-10-06):
##
##   func on_spell_hit(rune_data: RuneData, direccion: Vector3) -> void
##
## Lo implementa cualquier nodo que quiera reaccionar a un hechizo: un Area3D en la capa CAPA_REACTIVO. Se decide por
## las etiquetas de `rune_data.tags`, nunca por `rune_type`. `direccion` es horizontal y unitaria (y = 0), o ZERO si el
## hechizo está quieto. Opcionales (si faltan se asume lo de siempre):
##   spell_reacts(rune_data, direccion) -> bool     ¿cambia algo de verdad? (falta = sí)
##   spell_passes_through() -> bool                 superficie: reacciona pero no detiene
##   spell_flies_over(rune_data, cargado) -> bool   deja pasar a algunos (el agua al viento)
##   carried_element() -> RuneData                  lo que el viento puede llevarse (una llama)
##   bloquea_proyectiles(proyectil) -> bool         (zona en CAPA_BLOQUEO) ¿para a este proyectil?
##   refleja_a(proyectil) -> bool                   (zona en CAPA_BLOQUEO) ¿lo devuelve?
##   push(direccion: Vector3, fuerza: float)        viento y atracción empujan a quien lo tenga
##   nivel_altura() -> int                          niveles que ocupa. Falta = 1 (un objeto de pie). 0 = a ras (fogata, charco,
##                                                  placa, puente): reacciona a lo que pasa POR ENCIMA o lo toca, pero no lo detiene;
##                                                  lo que vuela a un nivel más alto que el objeto (levitación) lo salta.
##
## DÓNDE ESTÁ EL SUELO: no es un Area3D. Cada hechizo marca el suelo llamando a Vfx3D.lanzar(elemento, origen, destino)
## UNA vez por casilla; el impacto del Vfx3D llega a PruebaTest2._al_impactar (ESTADOS_SUELO.md). Por eso aquí NO se
## llama nunca a _al_impactar a mano: un agua dos veces sobre la misma casilla la helaría.

## --- Capas de física del Test 3 ---
const CAPA_HECHIZO: int = 1 << 7     ## capa 8
const CAPA_REACTIVO: int = 1 << 8    ## capa 9: lo que implementa on_spell_hit
const CAPA_BLOQUEO: int = 1 << 9     ## capa 10: zonas que paran proyectiles

## Alto de un nivel, en unidades. Es el ALTO de prueba_test2.gd (S * 0,45); configurar() lo lee de allí.
const ALTO_NIVEL: float = 2.3 * 0.45

## --- Modo lanzar (§0b) ---
const RALENTIZADO: float = 0.7              ## Engine.time_scale mientras se apunta
const ALCANCE_ORIGEN: float = 3.0           ## casillas: lo más lejos de ti que puede nacer un hechizo
const PEGARSE_AL_JUGADOR: float = 0.8       ## casillas: señalar tan cerca de ti es nacer en ti
const ARRASTRE_MINIMO: float = 0.45         ## casillas: menos que esto es un clic, no un arrastre
const TIEMPO_MAX_MODO: float = 12.0         ## segundos de reloj: pasado esto se cancela solo

## --- Lo que sale ---
const ALCANCE_FLECHA: float = 8.0           ## casillas
const ALCANCE_HAZ: float = 8.0              ## casillas (rayo)
const VEL_MURO: float = 1.72                ## casillas/s (Sigils.WALL_SPEED 110 px / 64)
const VEL_ONDA: float = 1.48                ## casillas/s (Sigils.PULSE_SPEED 95 px / 64)
const RADIO_GOLPE: float = 0.42             ## casillas: radio de cada manifestación quieta
const FUERZA_EMPUJE: float = 2600.0         ## la del 2D; Combate3D la reduce a su escala

## --- Tierra e hielo con duración (§0b) ---
const MAX_TIERRA_APILADA: int = 2           ## bloques de tierra uno encima de otro
const MAX_NIVELES_TIERRA: int = 8           ## tope de bloques vivos a la vez (FIFO)
const DURACION_TIERRA: float = 25.0         ## segundos
const DURACION_HIELO: float = 20.0          ## segundos, salvo casillas en `hielo_permanente`
const AVISO_CADUCA: float = 3.0             ## segundos finales en que parpadea

## --- El repertorio del Test 3: los seis elementos, nueve sellos (sin `pilar` ni `retardo`) ---
const HUECOS_POR_PAGINA: int = 6
const ELEMENTOS_TEST3: PackedStringArray = ["fuego", "agua", "viento", "tierra", "rayo", "hielo"]
const SELLOS_TEST3: PackedStringArray = ["flecha", "barrera", "levitacion", "repeticion", "amplificar", "rebote",
	"pulso", "atraccion", "espejo"]

## DÓNDE golpeó el último hechizo (mundo) y a qué nivel; on_spell_hit no lleva posición. Vector3.INF = ninguna.
static var ultimo_impacto: Vector3 = Vector3.INF
static var ultimo_nivel: int = 0

## --- El mundo (lo fija configurar()) ---
static var mundo_s: Node3D = null
static var casilla: float = 2.3             ## S de prueba_test2.gd
static var alto_suelo: float = 2.3 * 0.45   ## ALTO: y de la cara de arriba de una casilla de tierra
static var alto_agua: float = 2.3 * 0.45 * 0.6

## Niveles de cada casilla por encima del suelo (tierra apilada, columnas, cornisas). Vector2i -> int.
static var alturas: Dictionary = {}
## Alturas FIJAS que pone el nivel (una cornisa de un nivel): Vector2i -> int. No caducan.
static var permanentes: Dictionary = {}
## Casillas cuyo hielo no caduca (el nivel lo marca): Vector2i -> true.
static var hielo_permanente: Dictionary = {}

## --- Lo que Lanzador3D necesita saber del resto (lo pone Jugador3D.montar) ---
var mundo: Node3D = null
var fx: Vfx3D = null
var jugador: Node3D = null              ## Jugador3D
var camara: Camera3D = null
var altura: int = 0                     ## nivel del hechizo que pregunta a una barrera (bloquea_proyectiles lo lee)

var capa_ui: CanvasLayer = null
var libro: Control = null
var _aviso: Label = null
var _guia: Label = null

## --- Modo lanzar ---
var modo_lanzar: bool = false
var _preparado: Dictionary = {}
var _ms_modo: int = 0
var _fijado: bool = false
var _origen_fijo: Vector3 = Vector3.ZERO
var _origen_vivo: Vector3 = Vector3.ZERO
var _punto_vivo: Vector3 = Vector3.ZERO
var _marca_origen: MeshInstance3D = null
var _marca_flecha: MeshInstance3D = null
var _marca_alcance: MeshInstance3D = null
var _ts_antes: float = 1.0

## --- Lo vivo ---
var _campos: Array = []                 ## Campo: muros, corros, ondas, tierra...
var _bloques: Array = []                ## tierra construida: {celda, niveles, nodos, resta}
var _columnas: Array = []               ## alturas temporales de columnas: {celda, niveles, resta, nodo}
var _hielo: Dictionary = {}             ## Vector2i -> {resta, agua}
var _t_hielo: float = 0.0
var _huecos_usados: Array = [{}, {}, {}]    ## por página: clave del sector -> nombre del glifo
var manifestaciones_vivas: int = 0

signal lanzado(elemento: String, forma: String, manifestaciones: int)
signal modo_cambiado(activo: bool)


## =====================================================================================================
##  Configuración y utilidades de casilla (estáticas: las usan también Jugador3D y Combate3D)
## =====================================================================================================

static func configurar(p_mundo: Node3D) -> void:
	mundo_s = p_mundo
	var k: Dictionary = p_mundo.get_script().get_script_constant_map()
	casilla = float(k.get("S", casilla))
	alto_suelo = float(k.get("ALTO", alto_suelo))
	alto_agua = float(k.get("ALTO_AGUA", alto_agua))
	alturas.clear()
	permanentes.clear()


static func celda_de(p: Vector3) -> Vector2i:
	return Vector2i(int(floorf(p.x / casilla)), int(floorf(p.z / casilla)))


static func centro_de(c: Vector2i, y: float = 0.0) -> Vector3:
	return Vector3((float(c.x) + 0.5) * casilla, y, (float(c.y) + 0.5) * casilla)


static func en_mapa(c: Vector2i) -> bool:
	return mundo_s != null and c.x >= 0 and c.y >= 0 and c.x < int(mundo_s.get("_lado")) and c.y < int(mundo_s.get("_lado"))


static func letra_de(c: Vector2i) -> String:
	return String(mundo_s.call("_letra", c))


## Agua de verdad: ni puente ni hielo encima.
static func es_agua(c: Vector2i) -> bool:
	if mundo_s == null:
		return false
	var l: String = letra_de(c)
	return l == "~" and not (mundo_s.get("_helada") as Dictionary).has(c)


static func altura_en(c: Vector2i) -> int:
	return int(alturas.get(c, 0))


static func fijar_altura(c: Vector2i, niveles: int) -> void:
	## Para el nivel: una cornisa. No caduca. Pasar 0 la quita.
	if niveles <= 0:
		permanentes.erase(c)
		alturas.erase(c)
	else:
		permanentes[c] = niveles
		alturas[c] = maxi(int(alturas.get(c, 0)), niveles)


## y de los pies de quien está en la casilla `c`: el suelo, más sus niveles; el agua y el puente, más bajo.
static func y_pies(c: Vector2i) -> float:
	var n: int = altura_en(c)
	if n > 0:
		return alto_suelo + float(n) * ALTO_NIVEL
	var l: String = letra_de(c)
	if l == "b" or (mundo_s.get("_helada") as Dictionary).has(c):
		return alto_agua + 0.12
	if l == "~":
		return alto_agua
	return alto_suelo


## Lo sólido para un hechizo que vuela a nivel `nivel`: el mapa (árboles, muros, objetos) o una torre de tierra.
static func celda_solida(c: Vector2i, nivel: int) -> bool:
	if not en_mapa(c):
		return true
	var l: String = letra_de(c)
	if l != "~" and (mundo_s.get("_bloqueadas") as Dictionary).has(c):
		return true
	return altura_en(c) >= 1 + nivel


## ¿Puede ESTAR alguien de pie en `c`? Lo usan el jugador y los goblins. `nivel` es en el que está;
## `sube` si puede subir uno (saltando); `max_nivel` lo más alto donde se puede estar; `nada` si puede entrar en agua.
static func pisable(c: Vector2i, nivel: int, sube: bool, max_nivel: int, nada: bool) -> bool:
	if not en_mapa(c):
		return false
	var l: String = letra_de(c)
	var bloqueadas: Dictionary = mundo_s.get("_bloqueadas")
	if l == "~":
		if (mundo_s.get("_helada") as Dictionary).has(c):
			pass                                     # hielo: se pisa
		else:
			return nada                              # agua: solo nadando
	elif bloqueadas.has(c):
		return false
	var hf: Dictionary = mundo_s.get("_hf")
	if hf.has(c) and int((hf[c] as Dictionary)["fase"]) == 1 and float((hf[c] as Dictionary)["v"]) > 0.5:
		return false                                 # hierba crecida: sólida (Fase.CRECIDA = 1)
	var n: int = altura_en(c)
	if n > max_nivel:
		return false
	return n <= nivel + (1 if sube else 0)


## ¿Se ven dos puntos? Las casillas sólidas del mapa y las torres de tierra cortan la vista.
static func linea_libre(a: Vector3, b: Vector3) -> bool:
	var d: Vector3 = b - a
	d.y = 0.0
	var largo: float = d.length()
	if largo < 0.01:
		return true
	var paso: float = casilla * 0.25
	var u: Vector3 = d / largo
	var previa: Vector2i = celda_de(a)
	var rec: float = paso
	while rec < largo:
		var c: Vector2i = celda_de(a + u * rec)
		if c != previa:
			var l: String = letra_de(c)
			if not en_mapa(c) or (l != "~" and (mundo_s.get("_bloqueadas") as Dictionary).has(c)) or altura_en(c) >= 1:
				return false
			previa = c
		rec += paso
	return true


## Nombre de elemento (el de Vfx3D) de una runa.
static func elemento_de(rune: RuneData) -> String:
	return Objetos.elemento_de(rune)


## =====================================================================================================
##  Arranque
## =====================================================================================================

func _ready() -> void:
	super._ready()
	add_to_group("player")      # el libro busca ahí un nodo 2D desde el que sonar (Sfx)
	Repertoire.aim_with_mouse = true
	Repertoire.max_sigils_per_page = HUECOS_POR_PAGINA
	Repertoire.set_active(ELEMENTOS_TEST3, SELLOS_TEST3)


## El libro y las pestañas de página, en una capa propia. Lo llama Jugador3D.montar() tras poner `mundo`.
func construir_interfaz() -> void:
	capa_ui = CanvasLayer.new()
	capa_ui.layer = 10
	capa_ui.name = "InterfazLanzador"
	add_child(capa_ui)

	var paginas := Control.new()
	paginas.set_script(load("res://page_hud.gd"))
	capa_ui.add_child(paginas)
	paginas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	libro = Control.new()
	libro.process_mode = Node.PROCESS_MODE_ALWAYS
	libro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	libro.set_script(load("res://spellbook.gd"))
	capa_ui.add_child(libro)
	libro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_aviso = Label.new()
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.add_theme_font_size_override("font_size", 24)
	_aviso.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_aviso.add_theme_constant_override("outline_size", 6)
	_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aviso.modulate.a = 0.0
	capa_ui.add_child(_aviso)
	_aviso.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_aviso.offset_top = 90.0
	_aviso.offset_bottom = 130.0

	_guia = Label.new()
	_guia.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_guia.add_theme_font_size_override("font_size", 18)
	_guia.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_guia.add_theme_constant_override("outline_size", 5)
	_guia.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guia.visible = false
	capa_ui.add_child(_guia)
	_guia.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_guia.offset_top = -120.0
	_guia.offset_bottom = -90.0
	_guia.offset_left = -420.0
	_guia.offset_right = 420.0


## Aviso en pantalla (se apaga solo). Lo usan también Jugador3D y Combate3D.
func avisar(texto: String, color: Color = Color(1, 0.9, 0.6)) -> void:
	if _aviso == null:
		return
	_aviso.text = texto
	_aviso.add_theme_color_override("font_color", color)
	_aviso.modulate.a = 1.0
	var tw: Tween = _aviso.create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(_aviso, "modulate:a", 0.0, 0.5)


## =====================================================================================================
##  Las reglas del libro (4.1)
## =====================================================================================================

## Un glifo por sector. Va aquí y no en el libro porque por esta función entran los dos caminos ($P y atajo de raya).
func add_sigil(sector: Vector2, sigil_name: String, calidad: float = 1.0) -> void:
	if Repertoire.sigil_active(sigil_name):
		for c in current_components:
			if (c["direction"] as Vector2).is_equal_approx(sector) and not (c["sigils"] as Array).is_empty():
				Sfx.play(self, "sello_no")
				_feedback("Hueco ocupado: ya hay '%s'" % String((c["sigils"] as Array)[0]))
				PlayLog.event("fallo", {"tipo": "hueco_ocupado", "nuevo": sigil_name,
					"ocupado": String((c["sigils"] as Array)[0])})
				PlayLog3D.gesto("rechazado", sigil_name)
				return
	super.add_sigil(sector, sigil_name, calidad)


## Cuenta cada gesto como reconocido, rechazado o confundido para la tabla de PlayLog3D (4.5).
func add_gesture(strokes: Array, sector: Vector2) -> void:
	var antes_sellos: int = sigils_used()
	var antes_elemento: Runes.Type = current_element
	var antes_aviso: int = feedback_until
	super.add_gesture(strokes, sector)
	var cambio: bool = sigils_used() != antes_sellos or current_element != antes_elemento
	if cambio:
		PlayLog3D.gesto("reconocido", "elemento" if sector == Vector2.ZERO else "glifo")
	elif feedback_until != antes_aviso:
		if feedback_text.contains("se parece a"):
			PlayLog3D.gesto("confundido", feedback_text)
		elif not feedback_text.begins_with("Hueco ocupado"):
			PlayLog3D.gesto("rechazado", feedback_text)


## =====================================================================================================
##  Lanzar una página: modo lanzar (4.1b)
## =====================================================================================================

## Al cerrar el libro se lanza la página en la que estabas. El libro fijó el sitio al abrir; aquí no hace falta:
## el hechizo se apunta DESPUÉS, en el modo lanzar.
func cast_current() -> void:
	cast_page(page)


func remember_aim() -> void:
	pass


func cast_page(indice: int) -> void:
	if indice < 0 or indice >= PAGES:
		return
	if modo_lanzar:
		_cancelar_modo()
	if jugador != null and not bool(jugador.call("puede_lanzar")):
		_feedback("Ahora no puedes lanzar")
		Sfx.play(self, "sello_no")
		return

	var ficha: Dictionary = pages[indice]
	var element_data: RuneData = rune_database.get(ficha["element"])
	var componentes: Array = ficha["components"]
	if element_data == null:
		_feedback("La página %d no tiene elemento" % (indice + 1))
		return
	if not Repertoire.element_active(_gesture_name_of(ficha["element"])):
		_feedback("Ese elemento ya no está activo")
		return
	if componentes.is_empty():
		_feedback("A la página %d le falta algún glifo" % (indice + 1))
		return
	if cooldown_left[indice] > 0.0:
		Sfx.play(self, "sello_no")
		_feedback("Recargando (%.1f s)" % cooldown_left[indice])
		PlayLog.event("cast_bloqueado", {"pagina": indice + 1, "queda": snappedf(cooldown_left[indice], 0.1)})
		return

	# UNA RECETA POR PÁGINA: los glifos de todos los sectores se funden en un solo hechizo.
	var fusion: Dictionary = {"sigils": [], "quality": []}
	for c in componentes:
		(fusion["sigils"] as Array).append_array(c["sigils"])
		(fusion["quality"] as Array).append_array(c.get("quality", []))
	for s in fusion["sigils"]:
		if not Repertoire.sigil_active(s):
			_feedback("Un glifo de la página ya no está activo")
			return

	var calidad: float = float(ficha.get("element_q", 1.0))
	for q in fusion["quality"]:
		calidad = minf(calidad, float(q))

	var receta := Receta3D.new(Vector2.RIGHT)
	for s in fusion["sigils"]:
		receta.apply(s)
	receta.calidad = calidad

	_preparado = {"indice": indice, "receta": receta, "rune": element_data, "calidad": calidad,
		"glifos": (fusion["sigils"] as Array).duplicate(),
		"elemento_nombre": _gesture_name_of(ficha["element"])}
	_entrar_modo_lanzar()


func _entrar_modo_lanzar() -> void:
	modo_lanzar = true
	_fijado = false
	_ms_modo = Time.get_ticks_msec()
	_ts_antes = Engine.time_scale
	Engine.time_scale = RALENTIZADO
	var rune: RuneData = _preparado["rune"]
	var forma: String = (_preparado["receta"] as Receta3D).forma()
	if jugador != null:
		jugador.call("bloquear", true)
		jugador.call("apuntar_lanzar", Objetos.elemento_de(rune), forma, RALENTIZADO)
	_crear_marcadores(rune.color)
	if _guia != null:
		_guia.text = "Apunta con el ratón · arrastra para dirigir · suelta para lanzar · clic derecho o Esc cancela"
		_guia.visible = true
	modo_cambiado.emit(true)
	PlayLog.event("modo_lanzar", {"pagina": int(_preparado["indice"]) + 1, "forma": forma})


func _salir_modo() -> void:
	modo_lanzar = false
	_fijado = false
	Engine.time_scale = 1.0 if _ts_antes <= 0.0 else _ts_antes
	if _guia != null:
		_guia.visible = false
	for m in [_marca_origen, _marca_flecha, _marca_alcance]:
		if m != null and is_instance_valid(m):
			(m as Node).queue_free()
	_marca_origen = null
	_marca_flecha = null
	_marca_alcance = null
	if jugador != null:
		jugador.call("bloquear", false)
		jugador.call("terminar_apuntar")
	modo_cambiado.emit(false)


func _cancelar_modo() -> void:
	if not modo_lanzar:
		return
	_salir_modo()
	_preparado = {}
	PlayLog.event("modo_lanzar_cancelado")


func _unhandled_input(ev: InputEvent) -> void:
	if not modo_lanzar:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_ESCAPE:
		_cancelar_modo()
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseButton:
		var mb: InputEventMouseButton = ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_cancelar_modo()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_actualizar_puntero(mb.position)
				_fijado = true
				_origen_fijo = _origen_vivo
			elif _fijado:
				_actualizar_puntero(mb.position)
				_soltar()
			get_viewport().set_input_as_handled()
	elif ev is InputEventMouseMotion:
		_actualizar_puntero((ev as InputEventMouseMotion).position)


## Rayo cámara → plano del suelo (a la altura de los pies del jugador).
func punto_en_suelo(pos_pantalla: Vector2) -> Vector3:
	if camara == null or jugador == null:
		return Vector3.ZERO
	var o: Vector3 = camara.project_ray_origin(pos_pantalla)
	var d: Vector3 = camara.project_ray_normal(pos_pantalla)
	var y: float = float(jugador.call("y_pies_actual"))
	if absf(d.y) < 0.0001:
		return Vector3(o.x, y, o.z)
	var t: float = (y - o.y) / d.y
	return o + d * t


func _actualizar_puntero(pos_pantalla: Vector2) -> void:
	_punto_vivo = punto_en_suelo(pos_pantalla)
	var yo: Vector3 = (jugador as Node3D).position
	var hacia: Vector3 = _punto_vivo - yo
	hacia.y = 0.0
	var tope: float = ALCANCE_ORIGEN * casilla
	if hacia.length() > tope:
		hacia = hacia.normalized() * tope            # más lejos, se queda en el borde
	if hacia.length() < PEGARSE_AL_JUGADOR * casilla:
		hacia = Vector3.ZERO                         # tan cerca de ti es nacer en ti
	_origen_vivo = yo + hacia
	_origen_vivo.y = yo.y


## Dirección con la que sale ahora: el arrastre desde el origen fijado; sin arrastre, de ti hacia el origen.
func _direccion_actual() -> Vector3:
	var yo: Vector3 = (jugador as Node3D).position
	if _fijado:
		var arr: Vector3 = _punto_vivo - _origen_fijo
		arr.y = 0.0
		if arr.length() >= ARRASTRE_MINIMO * casilla:
			return arr.normalized()
	var de_ti: Vector3 = (_origen_fijo if _fijado else _origen_vivo) - yo
	de_ti.y = 0.0
	if de_ti.length() > 0.2:
		return de_ti.normalized()
	var al_puntero: Vector3 = _punto_vivo - yo         # nace en ti: sale hacia donde señala el ratón
	al_puntero.y = 0.0
	if al_puntero.length() > 0.2:
		return al_puntero.normalized()
	var m: Vector3 = jugador.call("mirada")
	return m if m.length() > 0.01 else Vector3(0, 0, 1)


func _process(delta: float) -> void:
	super._process(delta)
	_avanzar_caducidades(delta)
	if modo_lanzar:
		if Time.get_ticks_msec() - _ms_modo > int(TIEMPO_MAX_MODO * 1000.0):
			avisar("Lanzamiento cancelado")
			_cancelar_modo()
			return
		_pintar_marcadores()
		if jugador != null:
			jugador.call("mirar_hacia", _direccion_actual())


func _soltar() -> void:
	var origen: Vector3 = _origen_fijo if _fijado else _origen_vivo
	var dir: Vector3 = _direccion_actual()
	var datos: Dictionary = _preparado
	_salir_modo()
	_preparado = {}
	if datos.is_empty():
		return
	lanzar_ahora(datos, origen, dir)


## Lo que pasa al soltar: animación, hechizo, recarga y registro. Público para las pruebas.
func lanzar_ahora(datos: Dictionary, origen: Vector3, dir: Vector3) -> void:
	var receta: Receta3D = datos["receta"]
	var rune: RuneData = datos["rune"]
	var indice: int = int(datos["indice"])
	var elemento: String = Objetos.elemento_de(rune)
	var forma: String = receta.forma()
	if jugador != null:
		jugador.call("mirar_hacia", dir)
		jugador.call("lanzar_clip", elemento, forma)

	var n: int = _materializar(receta, rune, origen, dir)

	cooldown_total[indice] = receta.cooldown
	cooldown_left[indice] = receta.cooldown
	PlayLog.event("cast", {"pagina": indice + 1, "elemento": datos["elemento_nombre"], "glifos": datos["glifos"],
		"calidad": snappedf(float(datos["calidad"]), 0.01), "recarga": receta.cooldown, "forma": forma,
		"origen": [snappedf(origen.x, 0.1), snappedf(origen.z, 0.1)], "manifestaciones": n})
	PlayLog3D.manifestaciones(n, forma, elemento)
	lanzado.emit(elemento, forma, n)


## --- Marcadores del modo lanzar ---

func _crear_marcadores(color: Color) -> void:
	_marca_origen = _anillo(0.22 * casilla, 0.34 * casilla, color)
	_marca_alcance = _anillo(ALCANCE_ORIGEN * casilla - 0.09, ALCANCE_ORIGEN * casilla, Color(color, 0.55))
	var flecha := BoxMesh.new()
	flecha.size = Vector3(0.12, 0.05, 1.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flecha.material = m
	_marca_flecha = MeshInstance3D.new()
	_marca_flecha.mesh = flecha
	_marca_flecha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mundo.add_child(_marca_flecha)


func _anillo(r_int: float, r_ext: float, color: Color) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = r_int
	t.outer_radius = r_ext
	t.rings = 32
	t.ring_segments = 4
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	t.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = t
	mi.scale = Vector3(1.0, 0.05, 1.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mundo.add_child(mi)
	return mi


func _pintar_marcadores() -> void:
	if _marca_origen == null:
		return
	var yo: Vector3 = (jugador as Node3D).position
	var o: Vector3 = _origen_fijo if _fijado else _origen_vivo
	_marca_origen.position = o + Vector3(0, 0.08, 0)
	_marca_alcance.position = yo + Vector3(0, 0.06, 0)
	var d: Vector3 = _direccion_actual()
	var largo: float = 1.1 * casilla
	_marca_flecha.position = o + d * largo * 0.5 + Vector3(0, 0.1, 0)
	_marca_flecha.scale = Vector3(1, 1, largo)
	_marca_flecha.rotation = Vector3(0, atan2(d.x, d.z), 0)


## =====================================================================================================
##  Materializar la receta en 3D
## =====================================================================================================

## Devuelve cuántas manifestaciones salen en total. La primera ola sale ya; las siguientes (repetición en onda)
## salen cada Sigils.WAVE_GAP segundos sin bloquear al lanzador.
func _materializar(receta: Receta3D, rune: RuneData, origen: Vector3, dir: Vector3) -> int:
	var elemento: String = Objetos.elemento_de(rune)
	var data: RuneData = receta.potenciada(rune)
	var olas: int = mini(receta.copies, 3) if receta.expande() else 1
	var primera: int = _una_ola(receta, data, elemento, origen, dir)
	for o in range(1, olas):
		_ola_diferida(float(o) * Sigils.WAVE_GAP, receta, data, elemento, origen, dir)
	return mini(primera * olas, Sigils.MAX_MANIFESTATIONS * olas)


func _ola_diferida(espera: float, receta: Receta3D, data: RuneData, elemento: String, origen: Vector3,
		dir: Vector3) -> void:
	await get_tree().create_timer(espera, false).timeout
	if is_inside_tree():
		_una_ola(receta, data, elemento, origen, dir)


func _una_ola(receta: Receta3D, data: RuneData, elemento: String, origen: Vector3, dir: Vector3) -> int:
	var giro: float = Vector2(dir.x, dir.z).angle() - Vector2.RIGHT.angle()
	var nivel: int = receta.height
	if receta.es_volador():
		return _lanzar_volador(receta, data, elemento, origen, dir, nivel)
	return _crear_campo(receta, data, elemento, origen, giro, receta.manifestaciones(), nivel)


## Una flecha (o un haz): se resuelve al lanzar con un barrido, y los efectos llegan cuando llega el dibujo.
func _lanzar_volador(receta: Receta3D, rune: RuneData, elemento: String, origen: Vector3, dir: Vector3,
		nivel: int) -> int:
	var dirs: Array = []
	var bases: Array = [dir]
	if receta.mirror:
		bases.append(-dir)
	if receta.copies <= 1:
		dirs = bases
	else:
		var abanico: float = deg_to_rad(22.0)
		for b in bases:
			for i in range(receta.copies):
				dirs.append((b as Vector3).rotated(Vector3.UP, (float(i) - float(receta.copies - 1) * 0.5) * abanico))
	var factor: float = Sigils.quality_factor(receta.calidad)
	var alcance: float = (ALCANCE_HAZ if rune.beam else ALCANCE_FLECHA) * casilla * factor
	if receta.reach > 1:
		alcance *= 1.0 + 0.25 * float(receta.reach - 1)
	var n: int = 0
	for d in dirs:
		if n >= Sigils.MAX_MANIFESTATIONS:
			break
		_barrido(receta, rune, elemento, origen, d as Vector3, alcance, nivel)
		n += 1
	return n


func _barrido(receta: Receta3D, rune: RuneData, elemento: String, origen: Vector3, dir: Vector3, alcance: float,
		nivel: int) -> void:
	var y_vuelo: float = y_pies(celda_de(origen)) + ALTO_NIVEL * 0.5 * float(1 + nivel)
	var inicio := Vector3(origen.x, y_vuelo, origen.z)
	var res: Dictionary = trazar(inicio, dir, alcance, nivel, rune, receta.lifetime > 0.0, receta.bounces, receta.pull)
	var t: float = 0.0
	for tramo in res["tramos"]:
		var a: Vector3 = tramo["desde"]
		var b: Vector3 = tramo["hasta"]
		var pie_a: Vector3 = Vector3(a.x, y_pies(celda_de(a)), a.z)
		var pie_b: Vector3 = Vector3(b.x, y_pies(celda_de(b)), b.z)
		var el: String = String(tramo.get("elemento", elemento))
		if Vfx3D.ELEMENTOS.has(el):
			_visual_en(t, el, pie_a, pie_b)
		var viaje: float = _tiempo_de_viaje(el, a.distance_to(b))
		for g in tramo["golpes"]:
			var obj: Node = g["obj"]
			var dist_g: float = float(g["dist"])
			var dir_g: Vector3 = tramo["dir"]
			var rune_g: RuneData = tramo.get("rune", rune)
			_despues(t + _tiempo_de_viaje(el, dist_g), _golpear.bind(obj, rune_g, dir_g, g["punto"], nivel, receta.pull,
				(tramo["desde"] as Vector3)))
		t += viaje


func _tiempo_de_viaje(elemento: String, distancia: float) -> float:
	match elemento:
		"tierra":
			return 0.25
		"rayo":
			return 0.2
	var v: float = fx.velocidad if fx != null else 7.0
	return maxf(0.15, distancia / maxf(v, 0.1))


func _visual_en(retraso: float, elemento: String, pie_a: Vector3, pie_b: Vector3) -> void:
	if fx == null:
		return
	if retraso <= 0.001:
		_visual(elemento, pie_a, pie_b)
	else:
		_despues(retraso, _visual.bind(elemento, pie_a, pie_b))


func _visual(elemento: String, pie_a: Vector3, pie_b: Vector3) -> void:
	if fx != null and is_instance_valid(fx):
		fx.lanzar(elemento, pie_a, pie_b)


func _despues(t: float, f: Callable) -> void:
	if t <= 0.001:
		f.call()
		return
	get_tree().create_timer(t, false).timeout.connect(f)


## BARRIDO: del origen en línea recta hasta `alcance`. Corta en una casilla sólida (que sea alta para este nivel),
## en una barrera o en lo primero que reacciona y detiene. Lo que atraviesa se anota como golpe. Con rebotes la
## trayectoria se parte en tramos. Devuelve {tramos: [{desde, hasta, dir, golpes, rune?, elemento?}], fin}.
func trazar(origen: Vector3, dir: Vector3, alcance: float, nivel: int, rune: RuneData, atraviesa: bool,
		rebotes: int, atrae: bool) -> Dictionary:
	var espacio: PhysicsDirectSpaceState3D = mundo.get_world_3d().direct_space_state
	var tramos: Array = []
	var pos: Vector3 = origen
	var d: Vector3 = Vector3(dir.x, 0.0, dir.z).normalized()
	var restante: float = alcance
	var ya: Dictionary = {}
	var cargado: bool = false
	var rune_act: RuneData = rune
	altura = nivel

	while restante > 0.05:
		# 1) La primera casilla sólida del camino.
		var dist_celda: float = restante
		var normal := Vector3.ZERO
		var paso: float = casilla * 0.1
		var previa: Vector2i = celda_de(pos)
		var rec: float = paso
		var choca_celda: bool = false
		var celda_sola: bool = false                     # lo que corta es una casilla sólida (no una barrera)
		while rec <= restante:
			var q: Vector3 = pos + d * rec
			var cq: Vector2i = celda_de(q)
			if cq != previa:
				if celda_solida(cq, nivel):
					dist_celda = maxf(rec - paso * 0.5, 0.0)
					var dx: int = cq.x - previa.x
					var dz: int = cq.y - previa.y
					normal = Vector3(-float(dx), 0.0, 0.0) if absi(dx) >= absi(dz) else Vector3(0.0, 0.0, -float(dz))
					choca_celda = true
					celda_sola = true
					break
				previa = cq
			if _barrera_en(q, nivel):
				dist_celda = rec
				normal = -d
				choca_celda = true
				break
			rec += paso

		# 2) Las zonas y objetos que el rayo atraviesa hasta ahí (y la casilla sólida que los contiene).
		var limite: float = minf(restante, dist_celda + casilla * 1.42) if choca_celda else restante
		var golpes: Array = []
		var parada: float = dist_celda
		var alcance_golpes: float = dist_celda + (casilla * 1.05 if celda_sola else 0.0)   # un objeto DENTRO de la casilla sólida
		var rebota_zona: bool = false
		var hits: Array = _rayo_areas(espacio, pos, d, limite)
		var cortado: bool = choca_celda
		for h in hits:
			var obj: Node = h["obj"]
			if ya.has(obj):
				continue
			if float(h["dist"]) > alcance_golpes:
				break
			ya[obj] = true
			if obj.has_method("bloquea_proyectiles") and bool(obj.call("bloquea_proyectiles", self)):
				parada = float(h["dist"])
				normal = -d
				rebota_zona = (obj.has_method("refleja_a") and bool(obj.call("refleja_a", self))) or rebotes > 0
				cortado = true
				choca_celda = false
				break
			var nv: int = int(obj.call("nivel_altura")) if obj.has_method("nivel_altura") else 1
			if nv < nivel:
				continue                                # vuela por encima (levitación más alta que el objeto)
			var a_ras: bool = nv < 1 + nivel            # objeto a ras: reacciona pero no frena
			if rune_act.tags.has("viento") and not cargado and obj.has_method("carried_element"):
				var llevado: RuneData = obj.call("carried_element")
				if llevado != null:
					rune_act = llevado
					cargado = true
			golpes.append({"obj": obj, "dist": float(h["dist"]), "punto": pos + d * float(h["dist"])})
			var reacciona: bool = true
			if obj.has_method("spell_reacts"):
				reacciona = bool(obj.call("spell_reacts", rune_act, d))
			var cruza: bool = a_ras or (obj.has_method("spell_passes_through") and bool(obj.call("spell_passes_through"))) \
				or (obj.has_method("spell_flies_over") and bool(obj.call("spell_flies_over", rune_act, cargado)))
			if reacciona and not cruza and not atraviesa:
				parada = float(h["dist"])
				cortado = true
				choca_celda = false
				break

		var fin: Vector3 = pos + d * parada
		var tramo: Dictionary = {"desde": pos, "hasta": fin, "dir": d, "golpes": golpes, "rune": rune_act,
			"elemento": Objetos.elemento_de(rune_act)}
		tramos.append(tramo)
		restante -= parada
		if cortado and (choca_celda or rebota_zona) and rebotes > 0 and normal != Vector3.ZERO and restante > 0.3:
			d = d.bounce(normal.normalized())
			d.y = 0.0
			d = d.normalized()
			pos = fin + d * 0.05
			rebotes -= 1
			continue
		pos = fin
		break

	return {"tramos": tramos, "fin": pos}


## ¿Hay una barrera VIVA (de las nuestras: corro, muro) en este punto, a un nivel que la salta o no?
func _barrera_en(p: Vector3, nivel: int) -> bool:
	for c in _campos:
		if is_instance_valid(c) and (c as Campo).bloquea_a(p, nivel):
			return true
	return false


## Todo lo que el rayo cruza en las capas reactiva y de bloqueo, ordenado por distancia.
func _rayo_areas(espacio: PhysicsDirectSpaceState3D, pos: Vector3, d: Vector3, largo: float) -> Array:
	var res: Array = []
	var excluir: Array[RID] = []
	var fin: Vector3 = pos + d * largo
	for i in range(24):
		var q := PhysicsRayQueryParameters3D.create(pos, fin, CAPA_REACTIVO | CAPA_BLOQUEO)
		q.collide_with_areas = true
		q.collide_with_bodies = false
		q.hit_from_inside = true
		q.exclude = excluir
		var r: Dictionary = espacio.intersect_ray(q)
		if r.is_empty():
			break
		excluir.append(r["rid"])
		var obj: Object = r["collider"]
		if obj is Node:
			res.append({"obj": obj, "dist": pos.distance_to(r["position"] as Vector3)})
	res.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["dist"]) < float(b["dist"]))
	return res


## Aplica un hechizo a un objeto, por el contrato: empuje, viento que se lleva, spell_reacts, on_spell_hit.
func _golpear(obj: Node, rune: RuneData, dir: Vector3, punto: Vector3, nivel: int, atrae: bool, desde: Vector3) -> bool:
	if obj == null or not is_instance_valid(obj) or rune == null:
		return false
	var es_viento: bool = rune.tags.has("viento")
	if (es_viento or atrae) and obj.has_method("push"):
		if atrae:
			var hacia: Vector3 = desde - (obj as Node3D).global_position
			hacia.y = 0.0
			if hacia.length() > 0.01:
				obj.call("push", hacia.normalized(), FUERZA_EMPUJE * (1.0 if es_viento else 0.7))
		else:
			var emp: Vector3 = dir
			if emp.length() < 0.01:
				emp = (obj as Node3D).global_position - punto
				emp.y = 0.0
				emp = emp.normalized()
			obj.call("push", emp, FUERZA_EMPUJE)
	if not obj.has_method("on_spell_hit"):
		return false
	var reacciona: bool = true
	if obj.has_method("spell_reacts"):
		reacciona = bool(obj.call("spell_reacts", rune, dir))
	ultimo_impacto = punto
	ultimo_nivel = nivel
	obj.call("on_spell_hit", rune, dir)
	ultimo_impacto = Vector3.INF
	ultimo_nivel = 0
	return reacciona


## =====================================================================================================
##  Campos: lo que se queda (muros, corros, ondas, tierra, columnas) (4.1, 4.4)
## =====================================================================================================

func _crear_campo(receta: Receta3D, rune: RuneData, elemento: String, origen: Vector3, giro: float, manifest: Array,
		nivel: int) -> int:
	var factor: float = Sigils.quality_factor(receta.calidad)
	var muro: bool = receta.es_barrera_movil()
	var sigue: bool = receta.sigue()
	var onda: bool = receta.expande()
	var campo := Campo.new()
	campo.lanz = self
	campo.rune = rune
	campo.elemento = elemento
	campo.nivel = nivel
	campo.bloquea = receta.blocks
	campo.refleja = receta.blocks and receta.bounces > 0
	campo.atrae = receta.pull
	campo.atraviesa = receta.lifetime > 0.0
	campo.viaja = muro
	campo.vida = receta.vida()
	campo.altura_barrera = receta.height

	# Centroide de cada dirección (una onda se abre desde el centro de lo suyo).
	var suma := Vector2.ZERO
	for m in manifest:
		suma += (m["p"] as Vector2)
	var centro2: Vector2 = suma / float(maxi(manifest.size(), 1))

	var origen2 := Vector2(origen.x, origen.z)
	var y_base: float = y_pies(celda_de(origen))
	var cuenta: int = 0
	for m in manifest:
		var rel: Vector2 = (m["p"] as Vector2).rotated(giro) * casilla
		var p2: Vector2 = origen2 + rel
		var dir2: Vector2 = (m["dir"] as Vector2).rotated(giro)
		var nivel_m: int = int(m.get("nivel", 0))
		var elev: float = float(m.get("elev", 0.0))
		var punto := Vector3(p2.x, y_base + ALTO_NIVEL * (0.5 + float(nivel_m) + elev), p2.y)
		var v := Vector3.ZERO
		if muro:
			v = Vector3(dir2.x, 0.0, dir2.y).normalized() * VEL_MURO * casilla
		elif onda:
			var rad: Vector2 = ((m["p"] as Vector2) - centro2).rotated(giro)
			if rad.length() < 0.001:
				rad = dir2
			v = Vector3(rad.x, 0.0, rad.y).normalized() * VEL_ONDA * casilla
		campo.puntos.append(punto)
		campo.vel.append(v)
		campo.dirs.append(Vector3(dir2.x, 0.0, dir2.y).normalized() if (muro or not receta.es_quieto()) else Vector3.ZERO)
		campo.niveles.append(nivel_m)
		campo.vivos.append(true)
		campo.rel.append(punto - (jugador as Node3D).position)
		cuenta += 1
	if sigue:
		campo.sigue = jugador as Node3D
	mundo.add_child(campo)
	_campos.append(campo)
	_visual_campo(receta, elemento, origen, campo, muro, receta.blocks and receta.height > 0 and receta.spread and not onda)
	campo.iniciar()
	manifestaciones_vivas += cuenta
	campo.tree_exited.connect(func() -> void:
		manifestaciones_vivas = maxi(0, manifestaciones_vivas - cuenta)
		_campos.erase(campo))

	# Lo que construye: tierra quieta (un bloque por casilla) y columna (barrera + levitación).
	var columna: bool = receta.blocks and receta.height > 0 and receta.spread and not onda
	if columna:
		_levantar_columna(campo, receta.vida(), mini(receta.height + 1, 2), rune.color)
	elif rune.tags.has("tierra") and receta.es_quieto() and not muro:
		var celdas: Dictionary = {}
		for pt in campo.puntos:
			celdas[celda_de(pt as Vector3)] = true
		for c in celdas:
			construir_tierra(c as Vector2i)
	return cuenta


## Marca el suelo de una casilla: es EL impacto del hechizo en ella (PruebaTest2._al_impactar, ESTADOS_SUELO.md). Las
## formas de Vfx3D.lanzar_forma son solo visuales y no emiten `impacto`, así que una casilla se marca aquí, una vez.
func marcar_celda(elemento: String, c: Vector2i) -> void:
	if mundo != null and en_mapa(c) and mundo.has_method("_al_impactar"):
		if _agua_o_hielo_en_altura(elemento, c):
			return
		var punto: Vector3 = centro_de(c, y_pies(c))
		mundo.call("_al_impactar", elemento, punto)
		al_impactar(elemento, punto)     # el hielo de un muro o corro tambien caduca a los 20 s (L3)


## H4 (DISENO_FUTURO §0b): agua, hielo y charcos SOLO existen a nivel 0. Una casilla con tierra o con una columna
## encima (altura >= 1) no recibe ese estado del suelo: el hechizo golpea el bloque, no el suelo de debajo.
func _agua_o_hielo_en_altura(elemento: String, c: Vector2i) -> bool:
	if (elemento == "agua" or elemento == "hielo") and altura_en(c) >= 1:
		PlayLog.event("estado_en_altura_rechazado", {"elemento": elemento, "celda": [c.x, c.y], "nivel": altura_en(c)})
		return true
	return false


## Todo impacto de Vfx3D pasa por aqui ANTES de llegar al suelo de PruebaTest2 (Jugador3D.montar la conecta en lugar
## de PruebaTest2._al_impactar): filtra H4 y despues deja que el mundo y `al_impactar` hagan lo de siempre.
func impacto_filtrado(elemento: String, punto: Vector3) -> void:
	if not _agua_o_hielo_en_altura(elemento, celda_de(punto)):
		if mundo != null and mundo.has_method("_al_impactar"):
			mundo.call("_al_impactar", elemento, punto)
	al_impactar(elemento, punto)


## El dibujo de lo que se queda: UNA llamada a Vfx3D.lanzar_forma por hechizo (columna: una por casilla).
func _visual_campo(receta: Receta3D, elemento: String, origen: Vector3, campo: Node3D, muro: bool, columna: bool) -> void:
	var c3: Campo = campo as Campo
	if fx == null or not Vfx3D.ELEMENTOS.has(elemento) or c3.puntos.is_empty():
		return
	var centro := Vector3.ZERO
	for p in c3.puntos:
		centro += p as Vector3
	centro /= float(c3.puntos.size())
	var radio: float = 0.0
	for p in c3.puntos:
		radio = maxf(radio, Vector2((p as Vector3).x - centro.x, (p as Vector3).z - centro.z).length())
	var pie_o := Vector3(origen.x, y_pies(celda_de(origen)), origen.z)
	var pie_c := Vector3(centro.x, y_pies(celda_de(centro)), centro.z)
	var dura: float = receta.vida()
	if muro:
		var d: Vector3 = (c3.dirs[0] as Vector3) if not c3.dirs.is_empty() else Vector3(0, 0, 1)
		fx.lanzar_forma("muro", elemento, pie_c - d * 1.0, pie_c, {"radio": clampf(radio, 0.6, 3.0), "dura": 0.9})
	elif columna:
		pass                                   # lo dibuja _levantar_columna casilla a casilla
	else:
		fx.lanzar_forma("corro", elemento, pie_o, pie_c, {"radio": clampf(radio, 0.6, 3.5), "dura": minf(dura, 3.0)})


## Un bloque de tierra en la casilla. Se apila hasta MAX_TIERRA_APILADA, caduca a los 25 s y hay un tope de
## MAX_NIVELES_TIERRA vivos a la vez (el más viejo se deshace antes). No se construye sobre agua, sobre algo
## sólido ni encima de alguien.
func construir_tierra(c: Vector2i) -> bool:
	if not en_mapa(c) or es_agua(c):
		return false
	var l: String = letra_de(c)
	if l == "~" or l == "b":
		return false
	if (mundo.get("_bloqueadas") as Dictionary).has(c) or permanentes.has(c):
		return false
	if jugador != null and bool(jugador.call("ocupa", c)):
		return false
	for g in get_tree().get_nodes_in_group("combate3d"):
		if is_instance_valid(g) and celda_de((g as Node3D).position) == c:
			return false
	var entrada: Dictionary = {}
	for b in _bloques:
		if (b["celda"] as Vector2i) == c:
			entrada = b
	if entrada.is_empty():
		entrada = {"celda": c, "niveles": 0, "nodos": [], "resta": DURACION_TIERRA}
		_bloques.append(entrada)
	elif int(entrada["niveles"]) >= MAX_TIERRA_APILADA:
		entrada["resta"] = DURACION_TIERRA
		return false
	entrada["niveles"] = int(entrada["niveles"]) + 1
	entrada["resta"] = DURACION_TIERRA
	var n: int = int(entrada["niveles"])
	var bloque := Area3D.new()              # Area3D: así la placa de peso (grupo "peso") lo nota
	bloque.name = "BloqueTierra"
	bloque.collision_layer = 1
	bloque.collision_mask = 0
	bloque.monitoring = false
	bloque.add_to_group("peso")
	var cs := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = Vector3(casilla * 0.8, ALTO_NIVEL * 0.9, casilla * 0.8)
	cs.shape = forma
	bloque.add_child(cs)
	var caja := BoxMesh.new()
	caja.size = Vector3(casilla * 0.94, ALTO_NIVEL, casilla * 0.94)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.37, 0.24)
	mat.roughness = 1.0
	caja.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = caja
	bloque.add_child(mi)
	var centro: Vector3 = centro_de(c, alto_suelo + ALTO_NIVEL * (float(n) - 0.5))
	bloque.position = centro - Vector3(0, ALTO_NIVEL * 0.6, 0)
	mundo.add_child(bloque)
	(entrada["nodos"] as Array).append(bloque)
	var tw: Tween = bloque.create_tween()
	tw.tween_property(bloque, "position", centro, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_recalcular(c)
	_aplicar_tope_tierra()
	return true


func _niveles_de_tierra() -> int:
	var n: int = 0
	for b in _bloques:
		n += int(b["niveles"])
	return n


## El tope: si hay más de MAX_NIVELES_TIERRA bloques vivos, se deshace la entrada más antigua entera.
func _aplicar_tope_tierra() -> void:
	while _niveles_de_tierra() > MAX_NIVELES_TIERRA and _bloques.size() > 1:
		var peor: Dictionary = _bloques[0]
		for b in _bloques:
			if float(b["resta"]) < float(peor["resta"]):
				peor = b
		_deshacer_bloque(peor)


func _deshacer_bloque(b: Dictionary) -> void:
	for n in (b["nodos"] as Array):
		if is_instance_valid(n):
			var mi: Node3D = n as Node3D
			var tw: Tween = mi.create_tween()
			tw.tween_property(mi, "scale", Vector3(1.0, 0.02, 1.0), 0.2)
			tw.tween_callback(mi.queue_free)
	_bloques.erase(b)
	_recalcular(b["celda"] as Vector2i)


## Columna de barrera + levitación: sólida, subible (hasta 2 niveles) y bloquea proyectiles. Dura lo que el campo.
func _levantar_columna(campo: Node3D, duracion: float, niveles: int, color: Color) -> void:
	var celdas: Dictionary = {}
	for pt in (campo as Campo).puntos:
		var c: Vector2i = celda_de(pt as Vector3)
		if not en_mapa(c) or es_agua(c) or (mundo.get("_bloqueadas") as Dictionary).has(c) \
				or jugador != null and bool(jugador.call("ocupa", c)):
			continue
		celdas[c] = true
	for c in celdas:
		var caja := BoxMesh.new()
		caja.size = Vector3(casilla * 0.9, ALTO_NIVEL * float(niveles), casilla * 0.9)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(color.lightened(0.3), 0.55)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.4
		caja.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = caja
		mi.name = "ColumnaBarrera"
		mi.position = centro_de(c as Vector2i, alto_suelo + ALTO_NIVEL * float(niveles) * 0.5)
		mundo.add_child(mi)
		_columnas.append({"celda": c, "niveles": niveles, "resta": duracion, "nodo": mi})
		if fx != null and Vfx3D.ELEMENTOS.has(Objetos.elemento_de(campo_rune(campo))):
			var pie_c := Vector3(centro_de(c as Vector2i).x, y_pies(c as Vector2i), centro_de(c as Vector2i).z)
			fx.lanzar_forma("columna", Objetos.elemento_de(campo_rune(campo)), pie_c, pie_c, {"dura": minf(duracion, 3.0)})
		_recalcular(c as Vector2i)


func campo_rune(campo: Node3D) -> RuneData:
	return (campo as Campo).rune


## alturas[c] = lo más alto entre lo permanente, la tierra y las columnas de esa casilla.
func _recalcular(c: Vector2i) -> void:
	var n: int = int(permanentes.get(c, 0))
	for b in _bloques:
		if (b["celda"] as Vector2i) == c:
			n = maxi(n, int(b["niveles"]))
	for k in _columnas:
		if (k["celda"] as Vector2i) == c:
			n = maxi(n, int(k["niveles"]))
	if n <= 0:
		alturas.erase(c)
	else:
		alturas[c] = n


## =====================================================================================================
##  Lo que caduca: tierra (25 s), columnas e hielo (20 s) (4.1c)
## =====================================================================================================

func _avanzar_caducidades(delta: float) -> void:
	for b in _bloques.duplicate():
		b["resta"] = float(b["resta"]) - delta
		var aviso: bool = float(b["resta"]) < AVISO_CADUCA
		for n in (b["nodos"] as Array):
			if is_instance_valid(n):
				(n as Node3D).visible = not aviso or int(float(b["resta"]) * 6.0) % 2 == 0
		if float(b["resta"]) <= 0.0:
			_deshacer_bloque(b)
	for k in _columnas.duplicate():
		k["resta"] = float(k["resta"]) - delta
		if float(k["resta"]) <= 0.0:
			if is_instance_valid(k["nodo"]):
				(k["nodo"] as Node).queue_free()
			_columnas.erase(k)
			_recalcular(k["celda"] as Vector2i)
	_t_hielo += delta
	if _t_hielo >= 0.25:
		var dt: float = _t_hielo
		_t_hielo = 0.0
		for c in _hielo.keys():
			var e: Dictionary = _hielo[c]
			if not _casilla_helada(c as Vector2i):
				_hielo.erase(c)               # otro lo deshizo (fuego): ya no hay nada que caducar
				continue
			if hielo_permanente.has(c):
				continue
			e["resta"] = float(e["resta"]) - dt
			if float(e["resta"]) <= 0.0:
				_derretir(c as Vector2i, bool(e["agua"]))
				_hielo.erase(c)


func _casilla_helada(c: Vector2i) -> bool:
	var img: Image = mundo.get("_img_estado")
	return img != null and en_mapa(c) and img.get_pixel(c.x, c.y).b >= 0.5


## Cada impacto de hielo o de agua puede haber helado una casilla: si es así, se apunta cuándo se deshace.
## Va DESPUÉS del manejador de PruebaTest2 (se conecta más tarde), así que el estado ya está escrito.
func al_impactar(elemento: String, punto: Vector3) -> void:
	if elemento != "hielo" and elemento != "agua":
		return
	var c: Vector2i = celda_de(punto)
	if not en_mapa(c) or not _casilla_helada(c):
		return
	if _hielo.has(c):
		if elemento == "hielo":
			(_hielo[c] as Dictionary)["resta"] = DURACION_HIELO     # otro hielo encima renueva los 20 s
		return
	_hielo[c] = {"resta": DURACION_HIELO, "agua": letra_de(c) == "~"}
	PlayLog.event("hielo", {"celda": [c.x, c.y], "agua": letra_de(c) == "~"})


## El hielo se deshace: el agua vuelve a ser agua (y se vuelve a bloquear para quien camina) y el suelo
## neutro se queda mojado. Quien estuviera encima cae al agua (Jugador3D lo ve solo).
func _derretir(c: Vector2i, era_agua: bool) -> void:
	mundo.call("_poner_canal", c, 2, 0.0)
	if era_agua:
		(mundo.get("_helada") as Dictionary).erase(c)
		(mundo.get("_bloqueadas") as Dictionary)[c] = true
	else:
		mundo.call("_poner_canal", c, 1, 1.0)
	if fx != null:
		fx.vapor(centro_de(c, alto_agua if era_agua else alto_suelo))
	PlayLog.event("hielo_deshecho", {"celda": [c.x, c.y]})


func marcas_de_hielo() -> int:
	return _hielo.size()


func bloques_de_tierra() -> int:
	return _niveles_de_tierra()


## =====================================================================================================
##  Deshacer y vaciar: los huecos se liberan con el libro
## =====================================================================================================

func clear_sequence() -> void:
	super.clear_sequence()


## =====================================================================================================
##  Receta en 3D: lee SpellRecipe sin tocarla
## =====================================================================================================

class Receta3D extends SpellRecipe:
	## Nombre de la forma, para la animación de lanzar y la matriz de VFX del Pipeline (4.6, 4.6b).
	func forma() -> String:
		if es_volador():
			return "proyectil"
		if es_barrera_movil():
			return "muro"
		if expande():
			return "onda"
		if spread and height > 0:
			return "columna"
		if spread:
			return "corro"
		if sigue():
			return "flotante"
		return "punto"

	func es_volador() -> bool:
		return _es_volador()

	func es_barrera_movil() -> bool:
		return _es_barrera_movil()

	func es_quieto() -> bool:
		return _es_quieto()

	func sigue() -> bool:
		return _sigue()

	func expande() -> bool:
		return _expande()

	## Cuánto vive lo que se queda (segundos de juego). Las mismas cuentas que SpellRecipe._construir.
	func vida() -> float:
		var factor: float = Sigils.quality_factor(calidad)
		var v: float = (Sigils.BASE_LIFETIME + lifetime) * factor
		if _es_barrera_movil():
			v = Sigils.WALL_LIFETIME * factor
		elif _sigue():
			v = Sigils.FOLLOW_LIFETIME * factor
		elif _es_chorro():
			v = (Sigils.BASE_LIFETIME + lifetime + Sigils.jet_hold(reach)) * factor
		return v

	## El elemento con el daño potenciado (sin tocar el .tres compartido).
	func potenciada(element: RuneData) -> RuneData:
		return _powered(element)

	## Las manifestaciones en CASILLAS relativas al origen y con la dirección del eje +X como "delante":
	## [{p: Vector2, dir: Vector2, nivel: int, elev: float}]. SpellRecipe apila la altura restando a Y en 2D; aquí se
	## deshace para que `nivel` y `elev` sean niveles de verdad.
	func manifestaciones() -> Array:
		var res: Array = []
		var volador: bool = _es_volador()
		var apilado: bool = height > 0 and spread and not _expande()
		var sube: float = float(height) * (0.5 if volador else 1.0)
		for d in _fan():
			var puntos: Array = _points(d)
			for i in range(puntos.size()):
				var p: Vector2 = puntos[i]
				var nivel: int = 0
				var elev: float = 0.0
				if apilado:
					nivel = i % (height + 1)
					p.y += LEVEL * float(nivel)
				elif height > 0:
					p.y += LEVEL * sube
					elev = sube
				res.append({"p": p / TILE, "dir": d, "nivel": nivel, "elev": elev})
		if res.size() > Sigils.MAX_MANIFESTATIONS:
			res.resize(Sigils.MAX_MANIFESTATIONS)
		return res


## =====================================================================================================
##  Campo: un conjunto de puntos del mismo hechizo que viven un rato
## =====================================================================================================

class Campo extends Node3D:
	var lanz: Lanzador3D = null
	var rune: RuneData = null
	var elemento: String = ""
	var nivel: int = 0
	var bloquea: bool = false
	var refleja: bool = false
	var atrae: bool = false
	var atraviesa: bool = false
	var viaja: bool = false
	var altura_barrera: int = 0
	var vida: float = 1.0
	var sigue: Node3D = null

	var puntos: Array = []          ## Vector3
	var vel: Array = []             ## Vector3
	var dirs: Array = []            ## Vector3 (ZERO si quieto)
	var niveles: Array = []         ## int: piso de la columna
	var vivos: Array = []           ## bool
	var rel: Array = []             ## Vector3 respecto al jugador (para lo que te sigue)

	var _t: float = 0.0
	var _golpeados: Dictionary = {}
	var _celdas: Dictionary = {}
	var _forma: SphereShape3D = null

	func iniciar() -> void:
		_forma = SphereShape3D.new()
		_forma.radius = Lanzador3D.RADIO_GOLPE * Lanzador3D.casilla
		name = "Campo_" + elemento
		for i in range(puntos.size()):
			_marcar_suelo(puntos[i] as Vector3)

	## ¿Esta barrera frena a algo que vuela por `p` a nivel `n`? Lo que levita más alto que ella pasa por encima.
	func bloquea_a(p: Vector3, n: int) -> bool:
		if not bloquea or n > altura_barrera:
			return false
		var r2: float = pow(Lanzador3D.RADIO_GOLPE * Lanzador3D.casilla * 1.15, 2.0)
		for i in range(puntos.size()):
			if bool(vivos[i]):
				var q: Vector3 = puntos[i]
				if (q.x - p.x) * (q.x - p.x) + (q.z - p.z) * (q.z - p.z) <= r2:
					return true
		return false

	func _marcar_suelo(p: Vector3) -> void:
		var c: Vector2i = Lanzador3D.celda_de(p)
		if _celdas.has(c) or not Lanzador3D.en_mapa(c):
			return
		_celdas[c] = true
		lanz.marcar_celda(elemento, c)

	func _physics_process(delta: float) -> void:
		_t += delta
		if _t >= vida:
			queue_free()
			return
		var espacio: PhysicsDirectSpaceState3D = lanz.mundo.get_world_3d().direct_space_state
		var algun_vivo: bool = false
		for i in range(puntos.size()):
			if not bool(vivos[i]):
				continue
			var p: Vector3 = puntos[i]
			if sigue != null and is_instance_valid(sigue):
				p = sigue.position + (rel[i] as Vector3) + Vector3(0, sin(_t * 4.0 + float(i)) * 0.08, 0)
			else:
				p += (vel[i] as Vector3) * delta
			var c: Vector2i = Lanzador3D.celda_de(p)
			if viaja or (vel[i] as Vector3) != Vector3.ZERO:
				if Lanzador3D.celda_solida(c, nivel):
					vivos[i] = false              # un muro que avanza se detiene contra lo sólido
					continue
			puntos[i] = p
			algun_vivo = true
			_marcar_suelo(p)
			_golpear(espacio, p, dirs[i] as Vector3)
		if not algun_vivo:
			queue_free()

	func _golpear(espacio: PhysicsDirectSpaceState3D, p: Vector3, dir: Vector3) -> void:
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = _forma
		q.transform = Transform3D(Basis.IDENTITY, p)
		q.collision_mask = Lanzador3D.CAPA_REACTIVO
		q.collide_with_areas = true
		q.collide_with_bodies = false
		for r in espacio.intersect_shape(q, 16):
			var obj: Object = r["collider"]
			if not (obj is Node) or _golpeados.has(obj):
				continue
			var nv: int = int((obj as Node).call("nivel_altura")) if (obj as Node).has_method("nivel_altura") else 1
			if nv < nivel and not atrae:
				continue
			_golpeados[obj] = true
			lanz._golpear(obj as Node, rune, dir, p, nivel, atrae, p)
