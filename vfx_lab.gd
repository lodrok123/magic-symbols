extends Node2D

## LABORATORIO DE VFX.
##
## Una sola pantalla para juzgar la gramática visual de los hechizos sin
## jugar el nivel. Lanza los hechizos REALES (SpellRecipe -> SpellFactory ->
## spell.gd), no una copia: lo que se ve aquí es lo que se verá en el juego.
##
## La rejilla es 4 elementos (columnas) x 2 sellos (filas). Leerla es la
## prueba en sí:
##   - Misma FILA  = mismo sello  -> debe tener la MISMA forma de estar en
##                                   el mundo, cambie el elemento.
##   - Misma COLUMNA = mismo elemento -> debe tener el MISMO material,
##                                   cambie el sello.
## Si dos celdas de la misma fila no se parecen en la forma, o dos de la
## misma columna no se parecen en el material, el lenguaje está roto.
##
## TECLAS
##   ESPACIO  lanzar ahora           L  bucle automático on/off
##   S        silueta (todo blanco)  G  escala de grises
##   T        cámara lenta
##   B        cambiar fondo          C  modo prueba a ciegas
##   P        siguiente página de combinaciones (ver PAGINAS)
##   E        cambia el juego de elementos: los cuatro de siempre / hielo y tierra
##   Solo en modo ciego:  N siguiente combinación   V revelar la respuesta
##   F9       ir a VfxLabMundo.tscn: cada ELEMENTO aislado en su bahía con las cosas del
##            mundo con las que reacciona (hielo, hierba, barrera de fuego, plantas...)
##
## Se lanza desde _process y no desde _ready porque SpellFactory cuelga los
## hechizos de current_scene, y esa todavía no existe mientras la escena
## principal acaba de nacer.

## Dos juegos de CUATRO columnas (con más, las celdas serían demasiado estrechas
## para ver un muro avanzar). El segundo lleva hielo y tierra junto a dos de
## referencia, para compararlos con algo ya conocido.
const JUEGOS_ELEMENTOS: Array = [
	[
		{"nombre": "FUEGO", "ruta": "res://fire_rune.tres"},
		{"nombre": "AGUA", "ruta": "res://water_rune.tres"},
		{"nombre": "VIENTO", "ruta": "res://wind_rune.tres"},
		{"nombre": "RAYO", "ruta": "res://lightning_rune.tres"},
	],
	[
		{"nombre": "HIELO", "ruta": "res://ice_rune.tres"},
		{"nombre": "TIERRA", "ruta": "res://earth_rune.tres"},
		{"nombre": "FUEGO", "ruta": "res://fire_rune.tres"},
		{"nombre": "AGUA", "ruta": "res://water_rune.tres"},
	],
]

## Cada FILA es una combinación de glifos (se aplican en orden a UNA receta).
## Se agrupan en páginas para que la rejilla siga siendo legible.
##
## Una fila es {"g": glifos, "esc": escenario}. El escenario monta lo que la
## combinación necesita para VERSE (algo contra lo que chocar, un arquero que
## dispara, un bloque de agua...):
##   (vacío)       lo normal: flecha con blanco a la derecha, lo demás en el centro
##   vaiven        el lanzador se mueve de un lado a otro (para ver cómo le SIGUEN)
##   arquero       un arquero falso dispara flechas contra el lanzador
##   muro_bajo     una barrera baja entre el lanzador y el blanco
##   agua          un bloque de agua en mitad del camino de un muro de fuego
##   blanco_cerca  un blanco pegado al lanzador (para ver tirones y ondas)
##   dos_lados     un blanco a cada lado (para ver el espejo)
const PAGINAS: Array = [
	{"titulo": "BASE", "nota": "", "filas": [
		{"g": ["flecha"]}, {"g": ["barrera"]}]},
	{"titulo": "LEVITACIÓN", "nota": "Solo: flota y te sigue (el lanzador se mueve)", "filas": [
		{"g": ["levitacion"], "esc": "vaiven"}, {"g": ["flecha", "levitacion"]}, {"g": ["barrera", "levitacion"]}]},
	{"titulo": "REPETICIÓN", "nota": "", "filas": [
		{"g": ["flecha", "repeticion"]}, {"g": ["barrera", "repeticion"]}, {"g": ["barrera", "flecha", "repeticion"]}]},
	{"titulo": "REBOTE · RETARDO", "nota": "Rebote: la flecha vuelve al golpear. Con barrera, la barrera REFLEJA lo que dispara el arquero", "filas": [
		{"g": ["flecha", "rebote"]}, {"g": ["barrera", "rebote"], "esc": "arquero"},
		{"g": ["retardo", "flecha"]}, {"g": ["retardo", "barrera"]}]},
	{"titulo": "PULSO", "nota": "El área nace en ti y se abre; con repetición, tres ondas seguidas", "filas": [
		{"g": ["pulso"], "esc": "blanco_cerca"}, {"g": ["pulso", "repeticion"], "esc": "blanco_cerca"},
		{"g": ["barrera", "pulso"], "esc": "blanco_cerca"}]},
	{"titulo": "ATRACCIÓN · ESPEJO", "nota": "Atracción tira del blanco (hacia ti si viaja, al centro si se queda)", "filas": [
		{"g": ["flecha", "atraccion"]}, {"g": ["barrera", "atraccion"], "esc": "blanco_cerca"},
		{"g": ["flecha", "espejo"], "esc": "dos_lados"}, {"g": ["flecha", "espejo", "repeticion"], "esc": "dos_lados"}]},
	{"titulo": "INTERACCIONES", "nota": "Barreras frenan al arquero · lo elevado pasa por encima de lo bajo · el agua apaga el fuego", "filas": [
		{"g": ["barrera"], "esc": "arquero"}, {"g": ["barrera", "levitacion"], "esc": "arquero"},
		{"g": ["flecha"], "esc": "muro_bajo"}, {"g": ["flecha", "levitacion"], "esc": "muro_bajo"},
		{"g": ["barrera", "flecha"], "esc": "agua"}]},
	{"titulo": "TRIPLES", "nota": "Tres glifos a la vez (límite 3 por página en el juego)", "filas": [
		{"g": ["flecha", "levitacion", "repeticion"]}, {"g": ["barrera", "levitacion", "repeticion"]},
		{"g": ["barrera", "flecha", "espejo"], "esc": "dos_lados"}, {"g": ["barrera", "pulso", "atraccion"], "esc": "blanco_cerca"}]},
]

const ARROW_SCENE: PackedScene = preload("res://Arrow.tscn")
const FIGURA := preload("res://export_godot/demo/figura_estatica.gd")

## Oscuro, medio y algo parecido al suelo del juego. Un efecto que solo se
## lee sobre negro no vale.
const FONDOS: Array = [
	Color(0.09, 0.08, 0.08),
	Color(0.30, 0.26, 0.22),
	Color(0.34, 0.40, 0.27),
]

const CICLO: float = 2.4
const LENTA: float = 0.25
const CABECERA: float = 46.0
const PIE: float = 44.0


## El punto desde el que se lanza. Un círculo, a propósito: que no se
## parezca a un personaje para no distraer del hechizo.
class Caster extends Node2D:
	## Para ver cómo SIGUE lo que levita: si vaiven > 0, el lanzador va de un lado a otro.
	var vaiven: float = 0.0
	var base: Vector2 = Vector2.ZERO
	var con_figura: bool = false
	var _t: float = 0.0

	func _process(delta: float) -> void:
		if vaiven > 0.0:
			_t += delta
			position = base + Vector2(sin(_t * 1.6) * vaiven, 0.0)

	func _draw() -> void:
		if con_figura:
			return
		draw_circle(Vector2.ZERO, 9.0, Color(0.85, 0.80, 0.95, 0.9))
		draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.5), 1.5, true)


## Algo contra lo que chocar, para ver también el IMPACTO de la flecha. Usa
## el mismo contrato que el resto del mundo (on_spell_hit), sin que el
## hechizo sepa que esto es un blanco de pruebas.
class Blanco extends Area2D:
	func _init() -> void:
		var forma := CollisionShape2D.new()
		var circulo := CircleShape2D.new()
		circulo.radius = 18.0
		forma.shape = circulo
		add_child(forma)

	func _draw() -> void:
		var c := Color(1.0, 1.0, 1.0, 0.45)
		draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 24, c, 2.0, true)
		draw_line(Vector2(-8.0, 0.0), Vector2(8.0, 0.0), c, 2.0)
		draw_line(Vector2(0.0, -8.0), Vector2(0.0, 8.0), c, 2.0)

	func on_spell_hit(_runa: RuneData, _direccion: Vector2) -> void:
		pass

	## Para ver la ATRACCIÓN: el blanco se desplaza hacia donde le tiran y luego vuelve.
	var _casa: Vector2 = Vector2.ZERO
	var _casa_fijada: bool = false

	func push(direccion: Vector2, fuerza: float) -> void:
		if not _casa_fijada:
			_casa = position
			_casa_fijada = true
		var t := create_tween()
		t.tween_property(self, "position", _casa + direccion * fuerza * 0.3, 0.15)
		t.tween_interval(0.5)
		t.tween_property(self, "position", _casa, 0.4)


## Un arquero de pega: solo existe para que le disparen flechas devueltas y se vea.
class ArqueroFalso extends Area2D:
	func _init() -> void:
		var forma := CollisionShape2D.new()
		var circulo := CircleShape2D.new()
		circulo.radius = 14.0
		forma.shape = circulo
		add_child(forma)

	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(-12, 12), Vector2(12, 12), Vector2(0, -14)]),
				Color(0.8, 0.25, 0.25, 0.85))

	func receive_damage(_cantidad: float, _elevacion: int = 0) -> void:
		var t := create_tween()
		t.tween_property(self, "scale", Vector2(1.5, 1.5), 0.08)
		t.tween_property(self, "scale", Vector2.ONE, 0.2)


## Un bloque de agua de pega: está en el grupo que mira el muro de fuego.
class AguaFalsa extends Area2D:
	func _init() -> void:
		add_to_group("water_blocks")
		var forma := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(36.0, 120.0)
		forma.shape = rect
		add_child(forma)

	func _draw() -> void:
		draw_rect(Rect2(Vector2(-18, -60), Vector2(36, 120)), Color(0.25, 0.5, 0.9, 0.55))
		draw_rect(Rect2(Vector2(-18, -60), Vector2(36, 120)), Color(0.6, 0.8, 1.0, 0.9), false, 2.0)

	func on_spell_hit(_runa: RuneData, _direccion: Vector2) -> void:
		pass


var _runas: Array = []
var _celdas: Array = []      # {caster, glifos, runa, esc, ...}
var _blancos: Array = []
var _etiquetas: Array = []

var _rejilla: Node2D
var _hud: CanvasLayer
var _pagina: int = 0
var _juego: int = 0
var _elementos: Array = []
var _filas: Array = []
var _escena_ciega: Node2D
var _caster_ciego: Caster
var _blanco_ciego: Blanco
var _capa_grises: CanvasLayer
var _texto_ciego: Label
var _ancho: float = 0.0
var _alto: float = 0.0

var _bucle: bool = true
var _reloj: float = CICLO   # arranca lleno: el primer lanzamiento es inmediato
var _lenta: bool = false
var _fondo: int = 1
var _ciego: bool = false
var _orden: Array = []
var _paso: int = -1

## --- Personajes de verdad en lugar del circulo (tecla K) ---
## -1 = circulo; 0..n-1 = personaje de export_godot. Se quedan quietos: respiran y, al lanzar, hacen su animacion.
const ALTURA_PECHO: float = 62.0   # de los pies al origen del hechizo (el circulo), a escala 1.0
var _pjs: Array = []
var _pj: int = -1
var _escala_pj: float = 1.0

## --- Modo grabación ---
## Se activa con el argumento `--grabar` (tras el `--` de la línea de
## comandos, ver tools/grabar_laboratorio.bat). Lleva solo el guion: color,
## luego silueta, luego cámara lenta, y cierra Godot al acabar. Así el vídeo
## sale igual cada vez y dos versiones del efecto se pueden comparar.
const GRAB_SILUETA: float = 7.2
const GRAB_LENTA: float = 14.4
const GRAB_FIN: float = 21.0

var _ayuda: Label
var _estado: Label
var _nota: Label
var _grabando: bool = false
var _fase: int = 0
var _t_grab: float = 0.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(FONDOS[_fondo])

	_cargar_elementos()
	_pjs = FIGURA.listar()

	var tam: Vector2 = get_viewport_rect().size
	_ancho = tam.x / float(_elementos.size())
	_filas = PAGINAS[_pagina]["filas"]
	_alto = (tam.y - CABECERA - PIE) / float(_filas.size())

	_crear_grises(tam)

	var hud := CanvasLayer.new()
	hud.layer = 20
	add_child(hud)
	_hud = hud

	_rejilla = Node2D.new()
	add_child(_rejilla)
	_escena_ciega = Node2D.new()
	add_child(_escena_ciega)

	_construir_rejilla(hud)
	_construir_ciego(hud, tam)
	_refrescar_modo()

	_grabando = OS.get_cmdline_user_args().has("--grabar")
	if _grabando:
		_ayuda.visible = false   # el vídeo no necesita la chuleta de teclas


func _exit_tree() -> void:
	# La cámara lenta es global: si se sale con ella puesta, el juego real
	# arrancaría a cámara lenta la próxima vez.
	Engine.time_scale = 1.0
	SpellForm.silhouette = false


## --- Montaje ---

func _cargar_elementos() -> void:
	_elementos = JUEGOS_ELEMENTOS[_juego]
	_runas.clear()
	for e in _elementos:
		_runas.append(load(e["ruta"]))


func _construir_rejilla(hud: CanvasLayer) -> void:
	for i in range(_elementos.size()):
		for j in range(_filas.size()):
			var fila: Dictionary = _filas[j]
			var glifos: Array = fila["g"]
			var esc: String = fila.get("esc", "")
			var origen := Vector2(_ancho * float(i), CABECERA + _alto * float(j))
			var centro_y: float = origen.y + _alto * 0.5
			var vuela: bool = glifos.has("flecha")
			var centrado: bool = (not vuela) or esc == "dos_lados"

			var caster := Caster.new()
			# La flecha sale del lado izquierdo para tener recorrido; lo que te rodea
			# (o sale hacia los dos lados) se pone en el centro de la celda.
			caster.position = Vector2(origen.x + _ancho * 0.5, centro_y) if centrado \
					else Vector2(origen.x + 48.0, centro_y)
			_rejilla.add_child(caster)
			caster.base = caster.position
			if _pj >= 0 and _pj < _pjs.size():
				var fig: Node2D = FIGURA.new()
				if fig.cargar(_pjs[_pj]):
					fig.set_escala(_escala_pj)
					fig.position = Vector2(0.0, ALTURA_PECHO * _escala_pj)
					fig.mirar("S" if centrado else "E")
					caster.add_child(fig)
					caster.con_figura = true
			if esc == "vaiven":
				caster.vaiven = _ancho * 0.25

			var celda := {"caster": caster, "glifos": glifos, "runa": _runas[i], "esc": esc}

			# --- El escenario de la celda ---
			if esc == "dos_lados":
				_poner_blanco(Vector2(origen.x + 44.0, centro_y))
				_poner_blanco(Vector2(origen.x + _ancho - 44.0, centro_y))
			elif esc == "blanco_cerca":
				_poner_blanco(caster.position + Vector2(105.0, 0.0))
			elif esc == "arquero":
				var arq := ArqueroFalso.new()
				arq.position = Vector2(origen.x + _ancho - 34.0, centro_y)
				_rejilla.add_child(arq)
				_blancos.append(arq)
				celda["arquero"] = arq
			elif esc == "agua":
				var agua := AguaFalsa.new()
				agua.position = Vector2(origen.x + _ancho * 0.55, centro_y)
				_rejilla.add_child(agua)
				_blancos.append(agua)
			elif vuela:
				_poner_blanco(Vector2(origen.x + _ancho - 44.0, centro_y))
				if esc == "muro_bajo":
					# Quien levanta la barrera baja es un lanzador invisible a mitad de camino.
					var ayudante := Caster.new()
					ayudante.position = Vector2(origen.x + _ancho * 0.5, centro_y)
					ayudante.modulate.a = 0.0
					_rejilla.add_child(ayudante)
					celda["ayudante"] = ayudante

			var etiqueta := _etiqueta(hud, "%s · %s" % [_elementos[i]["nombre"], _nombre_fila(glifos)],
					origen + Vector2(8.0, 4.0))
			_etiquetas.append(etiqueta)
			_celdas.append(celda)


func _poner_blanco(pos: Vector2) -> void:
	var blanco := Blanco.new()
	blanco.position = pos
	_rejilla.add_child(blanco)
	_blancos.append(blanco)


func _nombre_fila(glifos: Array) -> String:
	return " + ".join(glifos.map(func(g): return String(g).to_upper()))


## Cambia de página o de juego de elementos: borra lo de la rejilla actual y la
## monta de nuevo.
func _reconstruir() -> void:
	_filas = PAGINAS[_pagina]["filas"]
	for hijo in _rejilla.get_children():
		hijo.queue_free()
	for l in _etiquetas:
		l.queue_free()
	_etiquetas.clear()
	_blancos.clear()
	_celdas.clear()
	_alto = (get_viewport_rect().size.y - CABECERA - PIE) / float(_filas.size())
	_construir_rejilla(_hud)
	_orden.clear()
	_paso = -1
	_reloj = CICLO
	_refrescar_modo()


func _cambiar_pagina() -> void:
	_pagina = (_pagina + 1) % PAGINAS.size()
	_reconstruir()


func _cambiar_juego() -> void:
	_juego = (_juego + 1) % JUEGOS_ELEMENTOS.size()
	_cargar_elementos()
	_reconstruir()


func _construir_ciego(hud: CanvasLayer, tam: Vector2) -> void:
	_caster_ciego = Caster.new()
	_caster_ciego.position = Vector2(tam.x * 0.3, tam.y * 0.5)
	_escena_ciega.add_child(_caster_ciego)

	_blanco_ciego = Blanco.new()
	_blanco_ciego.position = Vector2(tam.x * 0.75, tam.y * 0.5)
	_escena_ciega.add_child(_blanco_ciego)

	_texto_ciego = _etiqueta(hud, "", Vector2(16.0, 10.0))
	_estado = _etiqueta(hud, "", Vector2(tam.x - 470.0, 10.0))
	_nota = _etiqueta(hud, "", Vector2(16.0, tam.y - PIE - 4.0))

	_ayuda = _etiqueta(hud, "ESPACIO lanzar · L bucle · S silueta · G grises · T lenta · B fondo · C prueba a ciegas (N siguiente, V revelar) · P página · E elementos · K personaje · [ ] tamaño personaje",
			Vector2(8.0, tam.y - PIE + 12.0))


func _etiqueta(padre: CanvasLayer, texto: String, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = texto
	l.position = pos
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.85))
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	padre.add_child(l)
	return l


## Escala de grises sobre lo que hay en pantalla. Es LA prueba de que la
## forma se lee sin el color: si en gris una flecha y una barrera no se
## distinguen, el sello no está resuelto, por bonito que se vea a color.
func _crear_grises(tam: Vector2) -> void:
	_capa_grises = CanvasLayer.new()
	_capa_grises.layer = 10

	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\n" \
		+ "uniform sampler2D pantalla : hint_screen_texture, filter_linear_mipmap;\n" \
		+ "void fragment() {\n" \
		+ "\tvec3 c = texture(pantalla, SCREEN_UV).rgb;\n" \
		+ "\tfloat g = dot(c, vec3(0.299, 0.587, 0.114));\n" \
		+ "\tCOLOR = vec4(vec3(g), 1.0);\n" \
		+ "}\n"
	var material := ShaderMaterial.new()
	material.shader = shader

	var rect := ColorRect.new()
	rect.size = tam
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = material
	_capa_grises.add_child(rect)
	_capa_grises.visible = false
	add_child(_capa_grises)


## --- Bucle ---

func _process(delta: float) -> void:
	if _grabando:
		_avanzar_grabacion(delta)

	if _ciego or not _bucle:
		return
	_reloj += delta
	if _reloj >= CICLO:
		_reloj = 0.0
		_lanzar_rejilla()


## El guion del vídeo. El tiempo se cuenta SIN la cámara lenta (delta ya
## viene multiplicado por time_scale), o la parte lenta duraría cuatro
## veces lo previsto y el resto del guion se desfasaría.
func _avanzar_grabacion(delta: float) -> void:
	_t_grab += delta / maxf(Engine.time_scale, 0.001)

	if _fase == 0 and _t_grab >= GRAB_SILUETA:
		_fase = 1
		SpellForm.silhouette = true
		_refrescar_estado()
	elif _fase == 1 and _t_grab >= GRAB_LENTA:
		_fase = 2
		SpellForm.silhouette = false
		_refrescar_estado()
		_lenta = true
		Engine.time_scale = LENTA
		_reloj = CICLO   # que la parte lenta empiece con un lanzamiento
	elif _fase == 2 and _t_grab >= GRAB_FIN:
		get_tree().quit()


func _draw() -> void:
	if _ciego:
		return
	var c := Color(1.0, 1.0, 1.0, 0.12)
	var fin_y: float = CABECERA + _alto * float(_filas.size())
	for i in range(1, _elementos.size()):
		draw_line(Vector2(_ancho * float(i), CABECERA), Vector2(_ancho * float(i), fin_y), c, 1.0)
	for j in range(1, _filas.size()):
		draw_line(Vector2(0.0, CABECERA + _alto * float(j)),
				Vector2(_ancho * float(_elementos.size()), CABECERA + _alto * float(j)), c, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return

	match k.keycode:
		KEY_SPACE:
			if _ciego:
				_lanzar_ciego()
			else:
				_reloj = 0.0
				_lanzar_rejilla()
		KEY_L:
			_bucle = not _bucle
		KEY_F9:
			# El laboratorio del MUNDO: cada elemento aislado contra lo que reacciona.
			get_tree().call_deferred("change_scene_to_file", "res://VfxLabMundo.tscn")
		KEY_S:
			SpellForm.silhouette = not SpellForm.silhouette
			_refrescar_estado()
		KEY_G:
			_capa_grises.visible = not _capa_grises.visible
		KEY_T:
			_lenta = not _lenta
			Engine.time_scale = LENTA if _lenta else 1.0
		KEY_B:
			_fondo = (_fondo + 1) % FONDOS.size()
			RenderingServer.set_default_clear_color(FONDOS[_fondo])
		KEY_P:
			_cambiar_pagina()
		KEY_E:
			_cambiar_juego()
		KEY_K:
			_cambiar_personaje()
		KEY_BRACKETLEFT:
			_cambiar_escala(1.0 / 1.1)
		KEY_BRACKETRIGHT:
			_cambiar_escala(1.1)
		KEY_C:
			_ciego = not _ciego
			_refrescar_modo()
			if _ciego:
				_siguiente_ciego()
		KEY_N:
			if _ciego:
				_siguiente_ciego()
		KEY_V:
			if _ciego:
				_revelar()


func _refrescar_modo() -> void:
	_rejilla.visible = not _ciego
	_escena_ciega.visible = _ciego
	_texto_ciego.visible = _ciego
	for l in _etiquetas:
		l.visible = not _ciego
	# Esconder un Area2D no la apaga: hay que quitarle la colisión, o una
	# flecha de la prueba a ciegas chocaría con un blanco invisible.
	for b in _blancos:
		b.set_deferred("monitorable", not _ciego)
	_blanco_ciego.set_deferred("monitorable", _ciego)
	queue_redraw()
	_refrescar_estado()


func _refrescar_estado() -> void:
	var quien: String = "círculo" if _pj < 0 or _pj >= _pjs.size() else String(_pjs[_pj]["id"])
	_estado.text = "PÁG %d/%d %s · ELEM %d/%d · PJ %s x%.2f%s" % [_pagina + 1, PAGINAS.size(),
			PAGINAS[_pagina]["titulo"], _juego + 1, JUEGOS_ELEMENTOS.size(), quien, _escala_pj,
			" · SILUETA" if SpellForm.silhouette else ""]
	if is_instance_valid(_nota):
		_nota.text = String(PAGINAS[_pagina]["nota"])


## --- Lanzar ---

func _lanzar(caster: Node2D, glifos: Array, runa: RuneData) -> void:
	var receta := SpellRecipe.new(Vector2.RIGHT)
	for g in glifos:
		receta.apply(g)
	receta.build(caster, runa)


func _lanzar_rejilla() -> void:
	for c in _celdas:
		_lanzar_celda(c)


## Lanza una celda con su escenario: lo que haga falta para que la combinación se vea.
func _lanzar_celda(c: Dictionary) -> void:
	match c["esc"]:
		"arquero":
			_disparar_enemiga(c["arquero"], c["caster"].global_position)
		"muro_bajo":
			# La barrera baja (sin levitación) se levanta a mitad de camino un instante antes.
			_lanzar(c["ayudante"], ["barrera"], c["runa"])
	_animar_lanzador(c["caster"])
	_lanzar(c["caster"], c["glifos"], c["runa"])


## Si el lanzador es un personaje, que haga su animacion de lanzar.
func _animar_lanzador(caster: Node2D) -> void:
	for h in caster.get_children():
		if h.has_method("una_vez"):
			h.una_vez()


func _cambiar_personaje() -> void:
	if _pjs.is_empty():
		return
	_pj += 1
	if _pj >= _pjs.size():
		_pj = -1
	_reconstruir()


func _cambiar_escala(f: float) -> void:
	_escala_pj = clampf(_escala_pj * f, 0.4, 2.5)
	_reconstruir()


## Una flecha ENEMIGA de las de verdad (Arrow.tscn), hacia el lanzador.
func _disparar_enemiga(desde: Node2D, hacia: Vector2) -> void:
	var flecha: Node2D = ARROW_SCENE.instantiate()
	flecha.direction = (hacia - desde.global_position).normalized()
	flecha.damage = 0.0
	get_tree().current_scene.add_child(flecha)
	flecha.global_position = desde.global_position + flecha.direction * 22.0


## --- Prueba a ciegas ---
##
## Para medir el criterio de cierre (identificar elemento Y sello en 7 de
## 8 clips): sin etiquetas, sin posición que delate la combinación, en
## orden aleatorio y sin repetir hasta agotar las ocho. El evaluador apunta
## lo que dice la persona; V enseña la respuesta.

func _combinacion(k: int) -> Array:
	var n: int = _elementos.size()
	var elemento: int = k % n
	var sello: int = floori(float(k) / float(n))
	return [elemento, sello]


func _siguiente_ciego() -> void:
	if _orden.is_empty() or _paso >= _orden.size() - 1:
		_orden = range(_elementos.size() * _filas.size())
		_orden.shuffle()
		_paso = -1
	_paso += 1
	_texto_ciego.text = "PRUEBA A CIEGAS  %d / %d\n¿Qué elemento y qué sello?   (ESPACIO repite · V revela · N siguiente)" \
			% [_paso + 1, _orden.size()]
	_lanzar_ciego()


func _lanzar_ciego() -> void:
	if _paso < 0:
		return
	var comb: Array = _combinacion(_orden[_paso])
	_lanzar(_caster_ciego, _filas[comb[1]]["g"], _runas[comb[0]])


func _revelar() -> void:
	if _paso < 0:
		return
	var comb: Array = _combinacion(_orden[_paso])
	_texto_ciego.text += "\n→ %s · %s" % [_elementos[comb[0]]["nombre"], _nombre_fila(_filas[comb[1]]["g"])]
