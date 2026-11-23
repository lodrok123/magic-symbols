extends Control

## LAS TRES PÁGINAS Y LA VOLTERETA, SIEMPRE A LA VISTA.
##
## El libro enseña las pestañas de las páginas, pero solo cuando está abierto, y
## la recarga corre con el libro CERRADO. Esto las repite abajo en el centro:
## de qué elemento es cada página, cuál está seleccionada, y cuánto le queda de
## recarga (un barrido oscuro que se va vaciando). A la derecha, la voltereta.
##
## Es solo interfaz: lee del Spellcaster y del jugador, no decide nada.

const RADIO: float = 12.0
const SEPARACION: float = 55.0
const TINTA: Color = Color(0.96, 0.94, 0.88, 0.95)
const TINTA_SUAVE: Color = Color(0.96, 0.94, 0.88, 0.55)
const VELO: Color = Color(0.0, 0.0, 0.0, 0.6)

var _pestana: StyleBoxFlat
var _pestana_activa: StyleBoxFlat

## El destello de la runa al conjurar (Fase 14.5): la página que se lanza brilla un instante. Lo pide el Lanzador3D.
var _destello_i: int = -1
var _destello_hasta: int = 0
var _destello_dur: float = 0.25


## 28/10 (gamefeel, `Sensacion3D.no_puedes`): la página que NO se puede lanzar (recarga, tinta, ahora no) tiembla de lado y se rodea de rojo un instante.
var _temblor_i: int = -1
var _temblor_hasta: int = 0
var _temblor_dur: float = 0.3
const TEMBLOR_PX: float = 4.0
const ROJO_NO: Color = Color(1.0, 0.3, 0.25)


func temblar(indice: int, dur: float = 0.3) -> void:
	_temblor_i = indice
	_temblor_dur = maxf(dur, 0.05)
	_temblor_hasta = Time.get_ticks_msec() + int(_temblor_dur * 1000.0)


## C1 (6/11/2026) · SOBRECARGA: mientras se mantiene 1/2/3 en el lanzamiento rápido, la página que se carga dibuja un arco que se llena (`fraccion` 0..1 de T_SOBRECARGA); cuando ya está lista
## (`lista`) el círculo late en dorado hasta que se suelta. `indice` -1 lo apaga. Fallo que evita: el cambio a los 0,8 s no se veía en la barra de páginas, que es donde mira quien mantiene la tecla.
const COLOR_SOBRECARGA: Color = Color(1.0, 0.82, 0.25)
const LATIDO_SOBRECARGA_PX: float = 3.0            ## px que respira el aro dorado cuando está lista
const VEL_LATIDO_SOBRECARGA: float = 0.018         ## rad por ms del latido (≈ 3 latidos por segundo)
var _sobre_i: int = -1
var _sobre_f: float = 0.0
var _sobre_lista: bool = false


## H16 (22/11, sesión HECHIZOS): el NOMBRE de la página activa («Flecha de fuego», o el que puso la jugadora), encima de las pestañas. Al cambiar de página sale en grande
## `T_NOMBRE_GRANDE` s y se reduce; no se enseñan los tres a la vez (llenarían la pantalla en combate). Lo lee de `Grimorio.nombre_pagina`.
const T_NOMBRE_GRANDE: float = 1.2
const T_NOMBRE_ENCOGE: float = 0.25
const TAM_NOMBRE_GRANDE: int = 22
const TAM_NOMBRE: int = 14
const ALTO_NOMBRE: float = 30.0                   ## px por encima del centro de las pestañas
var _nombre_pagina_vista: int = -1
var _nombre_texto_visto: String = ""
var _nombre_desde_ms: int = 0
var ultimo_nombre: String = ""                    ## lo último que pintó (para las pruebas)
var ultimo_tam_nombre: int = 0


## El tamaño del nombre `t` segundos después de cambiar de página: grande, y luego se reduce en `T_NOMBRE_ENCOGE` s.
static func tam_nombre(t: float) -> int:
	if t <= T_NOMBRE_GRANDE:
		return TAM_NOMBRE_GRANDE
	var k: float = clampf((t - T_NOMBRE_GRANDE) / T_NOMBRE_ENCOGE, 0.0, 1.0)
	return int(round(lerpf(float(TAM_NOMBRE_GRANDE), float(TAM_NOMBRE), k)))


func sobrecarga(indice: int, fraccion: float = 0.0, lista: bool = false) -> void:
	_sobre_i = indice
	_sobre_f = clampf(fraccion, 0.0, 1.0)
	_sobre_lista = lista and indice >= 0


func destello(indice: int, dur: float = 0.25) -> void:
	_destello_i = indice
	_destello_dur = maxf(dur, 0.05)
	_destello_hasta = Time.get_ticks_msec() + int(_destello_dur * 1000.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pestana = TemaInterfaz.caja_panel(TemaInterfaz.PERGAMINO_HUD, TemaInterfaz.BORDE_CALIDO_OSCURO, 1)
	_pestana.set_corner_radius_all(8)
	_pestana.shadow_size = 3
	_pestana_activa = _pestana.duplicate() as StyleBoxFlat
	_pestana_activa.set_border_width_all(2)


func _process(_delta: float) -> void:
	var dialogo := get_tree().get_first_node_in_group("dialogo_pergamino") as Control
	modulate.a = 0.4 if dialogo != null and dialogo.is_visible_in_tree() else 1.0
	queue_redraw()


func _draw() -> void:
	var caster = get_tree().get_first_node_in_group("spellcaster")
	if caster == null:
		return

	var total: int = Repertoire.pages_available(caster.PAGES)
	var lanzador := caster as Lanzador3D
	var de_combate: bool = lanzador != null and not lanzador.libro_abierto() and not lanzador.fichas_combate.is_empty()
	var y: float = size.y - 49.0
	var x0: float = size.x * 0.5 - float(total - 1) * 0.5 * SEPARACION

	for i in range(total):
		var centro := Vector2(x0 + float(i) * SEPARACION, y)
		var k_no: float = 0.0
		if i == _temblor_i:
			k_no = clampf(float(_temblor_hasta - Time.get_ticks_msec()) / 1000.0 / _temblor_dur, 0.0, 1.0)
			centro.x += sin(float(Time.get_ticks_msec()) * 0.09) * TEMBLOR_PX * k_no
		var activa: bool = i == caster.page
		var radio: float = RADIO * (1.15 if activa else 1.0)

		var pestana := _pestana_activa if activa else _pestana
		pestana.draw(get_canvas_item(), Rect2(centro - Vector2(23.0, 17.0), Vector2(46.0, 52.0)))
		var datos: RuneData = caster.page_element_data(i)
		var preparada: bool = caster.page_ready(i)
		if de_combate and i < lanzador.fichas_combate.size():
			datos = lanzador.rune_database.get(lanzador.fichas_combate[i]["element"])
			preparada = datos != null
		if datos != null:
			var tinte: Color = datos.color
			if not preparada:
				tinte.a = 0.35
			draw_circle(centro, radio, tinte)
			if datos.glyph != null:
				var lado := Vector2.ONE * radio * 1.35
				draw_texture_rect(datos.glyph, Rect2(centro - lado * 0.5, lado), false, Color("33251a"))
		else:
			draw_circle(centro, radio, Color(0.3, 0.3, 0.34, 0.5))
			# Libro avanzado: dos sellos opuestos (fuego + agua, tierra + viento) se anulan: la página sale apagada con una cruz roja, no como «vacía».
			if caster.has_method("pagina_anulada") and caster.pagina_anulada(i):
				draw_line(centro + Vector2(-radio, -radio) * 0.6, centro + Vector2(radio, radio) * 0.6, ROJO_NO, 2.5, true)
				draw_line(centro + Vector2(-radio, radio) * 0.6, centro + Vector2(radio, -radio) * 0.6, ROJO_NO, 2.5, true)

		# La recarga: un barrido oscuro sobre la parte que falta.
		var resto: float = caster.page_cooldown_fraction(i)
		if resto > 0.0:
			draw_arc(centro, radio * 0.5, -PI * 0.5, -PI * 0.5 + TAU * resto, 24, VELO, radio, true)

		draw_arc(centro, radio, 0.0, TAU, 24, TINTA if activa else TINTA_SUAVE,
			2.5 if activa else 1.5, true)
		if k_no > 0.0:
			draw_arc(centro, radio + 2.0, 0.0, TAU, 24, Color(ROJO_NO, k_no), 3.0, true)
		if i == _sobre_i:
			var latido: float = LATIDO_SOBRECARGA_PX * (0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * VEL_LATIDO_SOBRECARGA)) if _sobre_lista else 0.0
			draw_arc(centro, radio + 5.0 + latido, -PI * 0.5, -PI * 0.5 + TAU * (1.0 if _sobre_lista else _sobre_f), 32, COLOR_SOBRECARGA if _sobre_lista else TINTA, 3.0, true)
		if i == _destello_i:
			var queda: float = float(_destello_hasta - Time.get_ticks_msec()) / 1000.0
			if queda > 0.0:
				var k: float = clampf(queda / _destello_dur, 0.0, 1.0)
				draw_circle(centro, radio * (1.0 + 0.6 * (1.0 - k)), Color(1.0, 0.97, 0.85, 0.55 * k))
				draw_arc(centro, radio * (1.2 + 0.8 * (1.0 - k)), 0.0, TAU, 32, Color(1.0, 0.97, 0.85, k), 3.0, true)
		_texto(centro + Vector2(0.0, 28.0), Controles.texto_teclas("pagina_%d" % (i + 1)), TemaInterfaz.TINTA_PERGAMINO, 42.0)

	# H16: el nombre de la página activa, encima de las pestañas.
	_dibujar_nombre(caster, Vector2(size.x * 0.5, y - ALTO_NOMBRE))
	_dibujar_pista(Vector2(size.x * 0.5, y - ALTO_PISTA))

	# La voltereta.
	var jugador = get_tree().get_first_node_in_group("player")
	if jugador != null and jugador.has_method("roll_cooldown_fraction"):
		var c := Vector2(x0 + float(total) * SEPARACION + 14.0, y)
		var listo: float = jugador.roll_cooldown_fraction()
		draw_circle(c, RADIO * 0.8, Color(0.05, 0.05, 0.08, 0.65))
		draw_circle(c, RADIO * 0.7, Color(0.62, 0.78, 0.95, 0.9 if listo <= 0.0 else 0.35))
		if listo > 0.0:
			draw_arc(c, RADIO * 0.35, -PI * 0.5, -PI * 0.5 + TAU * listo, 24, VELO, RADIO * 0.7, true)
		_texto(c + Vector2(0.0, 22.0 + RADIO * 0.5), Controles.texto_teclas("voltereta"), TINTA)


func _dibujar_nombre(caster: Node, pos: Vector2) -> void:
	var nombre: String = String(caster.call("nombre_pagina", int(caster.get("page")))) if caster.has_method("nombre_pagina") else ""
	var pagina: int = int(caster.get("page"))
	if pagina != _nombre_pagina_vista or nombre != _nombre_texto_visto:
		# Cambió de página (o de receta, o la renombró): vuelve a salir en grande.
		_nombre_pagina_vista = pagina
		_nombre_texto_visto = nombre
		_nombre_desde_ms = Time.get_ticks_msec()
	ultimo_nombre = nombre
	if nombre == "":
		ultimo_tam_nombre = 0
		return
	var tam: int = tam_nombre(float(Time.get_ticks_msec() - _nombre_desde_ms) / 1000.0)
	ultimo_tam_nombre = tam
	# Con contorno oscuro: se lee sobre la hierba, la nieve o el agua.
	var fuente: Font = TemaInterfaz.fuente()
	var ancho: float = fuente.get_string_size(nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	var p: Vector2 = pos - Vector2(ancho * 0.5, 0.0)
	draw_string_outline(fuente, p, nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 4, Color(0.13, 0.09, 0.06, 0.85))
	draw_string(fuente, p, nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, TINTA)



## H6 (23/11): la PISTA de uso inmediato (`PistaGlifo`), una píldora encima del nombre de la página: «[runa] Pulsa 2». Solo existe mientras haya una pista sin cumplir.
const TAM_PISTA: int = 15
const ALTO_PISTA: float = 64.0                    ## px por encima del centro de las pestañas (el nombre ocupa hasta ALTO_NOMBRE + su tamaño grande)
var ultima_pista: String = ""                     ## lo último que pintó (para las pruebas)


func _dibujar_pista(pos: Vector2) -> void:
	ultima_pista = ""
	var pista := get_tree().get_first_node_in_group(PistaGlifo.GRUPO) as PistaGlifo
	if pista == null or pista.cumplido:
		return
	var texto: String = pista.texto_hud()
	if texto == "":
		return
	ultima_pista = texto
	var fuente: Font = TemaInterfaz.fuente()
	var ancho_t: float = fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_PISTA).x
	var lado_runa: float = 22.0
	var total: float = lado_runa + 8.0 + ancho_t
	var latido: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.004)
	var col: Color = pista.color()
	var caja := Rect2(pos + Vector2(-total * 0.5 - 12.0, -TAM_PISTA - 8.0), Vector2(total + 24.0, TAM_PISTA + 16.0))
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.10, 0.07, 0.05, 0.72)
	estilo.border_color = Color(col, 0.55 + 0.35 * latido)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(12)
	estilo.draw(get_canvas_item(), caja)
	var x0: float = pos.x - total * 0.5
	var tex: Texture2D = pista.textura()
	if tex != null:
		draw_texture_rect(tex, Rect2(Vector2(x0, pos.y - lado_runa * 0.5 - 5.0), Vector2.ONE * lado_runa), false, Color(col.lightened(0.35), 1.0))
	draw_string(fuente, Vector2(x0 + lado_runa + 8.0, pos.y), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_PISTA, TINTA)

func _texto(pos: Vector2, texto: String, color: Color, ancho_max: float = -1.0) -> void:
	var fuente: Font = TemaInterfaz.fuente()
	var ancho: float = fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	if ancho_max > 0.0:
		ancho = minf(ancho, ancho_max)
	draw_string(fuente, pos - Vector2(ancho * 0.5, 0.0), texto,
		HORIZONTAL_ALIGNMENT_LEFT, ancho, 14, color)
