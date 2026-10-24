class_name HudEoW
extends CanvasLayer

## EL HUD AL ESTILO ECHOES OF WISDOM (24/10, Juego; prototipo de Pablo con tres láminas de referencia: «Consumible equipado», «Cargas y recarga» y el menú).
## Sustituye a las dos barras de ColorRect que pintaba `Jugador3D._actualizar_hud`:
##   · arriba a la izquierda (desde `Jugador3D.Y_BARRAS`): la VIDA como `BarraHud`; debajo, los FRASCOS DE RESERVA de tinta (3, llenos o vacíos) junto a la
##     BARRA de tinta (la que se gasta al lanzar). Reglas de los frascos en `nucleo/tinta.gd` («FRASCOS DE RESERVA»);
##   · abajo a la derecha: el CÍRCULO del consumible equipado, con su icono, la cantidad, la tecla (Q usa) y la tecla de cambio (R); un anillo muestra
##     cuánto le queda al bálsamo o a la infusión cuando están activos.
## Lógica: nada propio. Los consumibles son `Consumibles` (nucleo/consumibles.gd; este nodo solo le pasa el tiempo y las teclas Q y R); la tinta es la del
## jugador (`jugador.tinta`). El jugador lo monta en `_construir_hud` y le pregunta `consumibles.absorber()` en `recibir_dano` (el bálsamo).
## El nodo `jugador` se lee por propiedades (`vida`, `muerto`, `tinta`, `bloqueado`, `mundo`, `lanz`), así que las pruebas le pasan un Node de mentira.
## Q/R solo valen con el juego en marcha (no con el menú ni el libro abiertos) y se ignoran si el jugador está muerto o bloqueado.

const X_PX: float = 14.0
const ANCHO_PX: float = 262.0
const SEP_FILA_PX: float = 36.0                ## de la barra de vida a la fila de frascos + tinta
const ANCHO_FRASCOS_PX: float = 96.0
const LADO_CIRCULO_PX: float = 120.0
const MARGEN_CIRCULO_PX: float = 14.0
const T_AVISO_TINTA_S: float = 0.35
const COLOR_VIDA_ALTA: Color = Color(0.35, 0.85, 0.4)
const COLOR_VIDA_MEDIA: Color = Color(1.0, 0.8, 0.25)
const COLOR_VIDA_BAJA: Color = Color(1.0, 0.3, 0.25)
const COLOR_TINTA_BAJA: Color = Color(1.0, 0.3, 0.25)
const COLOR_TINTA_SIN: Color = Color(0.5, 0.5, 0.55)
const COLOR_ESCUDO: Color = Color(1.0, 0.85, 0.4)
const COLOR_REGEN: Color = Color(0.8, 0.55, 1.0)

var jugador: Node = null
var consumibles: Consumibles = Consumibles.new()
var _vida: BarraHud
var _tinta: BarraHud
var _frascos: Frascos
var _circulo: Circulo
var _t_aviso: float = 0.0
var _vida_vista: float = -1.0


func _ready() -> void:
	layer = 9
	add_to_group("hud_eow")
	var raiz := Control.new()
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(raiz)
	var y0: float = Jugador3D.Y_BARRAS
	_vida = BarraHud.new()
	_vida.position = Vector2(X_PX, y0)
	_vida.poner_ancho(ANCHO_PX)
	raiz.add_child(_vida)
	_frascos = Frascos.new()
	_frascos.position = Vector2(X_PX, y0 + SEP_FILA_PX)
	raiz.add_child(_frascos)
	_tinta = BarraHud.new()
	_tinta.position = Vector2(X_PX + ANCHO_FRASCOS_PX + 6.0, y0 + SEP_FILA_PX)
	_tinta.poner_ancho(ANCHO_PX - ANCHO_FRASCOS_PX - 6.0)
	raiz.add_child(_tinta)
	_circulo = Circulo.new()
	_circulo.consumibles = consumibles
	_circulo.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_circulo.offset_left = -(LADO_CIRCULO_PX + MARGEN_CIRCULO_PX)
	_circulo.offset_top = -(LADO_CIRCULO_PX + MARGEN_CIRCULO_PX + 18.0)
	_circulo.offset_right = -MARGEN_CIRCULO_PX
	_circulo.offset_bottom = -MARGEN_CIRCULO_PX
	raiz.add_child(_circulo)

	consumibles.jugador = jugador
	consumibles.aviso.connect(_avisar)
	consumibles.cambiado.connect(_circulo.queue_redraw)
	Estado.i().cambiado.connect(consumibles.al_cambiar_mochila)
	var t: Tinta = _tinta_jugador()
	if t != null:
		t.frasco_gastado.connect(_al_gastar_frasco)
		t.insuficiente.connect(func(_f: String, _c: float, _h: float) -> void: _t_aviso = T_AVISO_TINTA_S)
	consumibles.al_cambiar_mochila()          # equipa el primero que haya (con la mochila como esté al montar)
	actualizar()


func _exit_tree() -> void:
	var e: Estado = Estado.i()
	if e.cambiado.is_connected(consumibles.al_cambiar_mochila):
		e.cambiado.disconnect(consumibles.al_cambiar_mochila)


func _tinta_jugador() -> Tinta:
	return jugador.get("tinta") as Tinta if jugador != null else null


func _process(delta: float) -> void:
	_t_aviso = maxf(0.0, _t_aviso - delta)
	consumibles.actualizar(delta)
	actualizar()


## Pone las barras y los frascos como están ahora (lo llama `_process`; público para las pruebas y las capturas).
func actualizar() -> void:
	if _vida == null or jugador == null:
		return
	var vmax: float = maxf(Estado.i().vida_max, 1.0)
	var v: float = float(jugador.get("vida"))
	var fr: float = clampf(v / vmax, 0.0, 1.0)
	_vida.poner_fraccion(fr)
	_vida.poner_color(COLOR_VIDA_ALTA if fr > 0.5 else (COLOR_VIDA_MEDIA if fr > 0.25 else COLOR_VIDA_BAJA))
	_vida.poner_rotulo("Vida %d/%d" % [int(round(v)), int(vmax)])
	var t: Tinta = _tinta_jugador()
	if t == null:
		return
	_tinta.poner_fraccion(t.fraccion())
	var col: Color = t.color()
	var est: String = t.estado()
	if est == "baja":
		col = COLOR_TINTA_BAJA
	elif est == "sin_tinta":
		col = COLOR_TINTA_SIN
	if _t_aviso > 0.0:
		col = col.lerp(Color(1.0, 0.15, 0.1), 0.7)
	_tinta.poner_color(col)
	var texto: String = "Tinta %d/%d" % [int(round(t.actual)), int(t.maxima)]
	if t.tiempo_pigmento() > 0.0:
		texto += " · %s %d s" % [t.nombre_pigmento(), int(ceil(t.tiempo_pigmento()))]
	_tinta.poner_rotulo(texto)
	_frascos.poner(t.frascos, Tinta.FRASCOS_MAX, t.color())


func _al_gastar_frasco() -> void:
	_frascos.destello(_tinta_jugador().frascos)       # el frasco que acaba de vaciarse (su índice = los que quedan llenos)
	_avisar("Frasco de tinta gastado (quedan %d)" % _tinta_jugador().frascos, Color(0.6, 0.8, 1.0))


func _avisar(texto: String, color: Color) -> void:
	var lanz: Variant = jugador.get("lanz") if jugador != null else null
	if lanz != null and (lanz as Object).has_method("avisar"):
		(lanz as Object).call("avisar", texto, color)


## ¿Se puede usar un consumible ahora? (juego en marcha, jugador vivo y con el control; ni libro ni menú abiertos).
func libre() -> bool:
	if jugador == null or not is_inside_tree() or get_tree().paused:
		return false
	if bool(jugador.get("muerto")) or bool(jugador.get("bloqueado")):
		return false
	var mundo: Object = jugador.get("mundo") as Object
	if mundo != null and mundo.get("_velo") != null:
		return false
	var lanz: Object = jugador.get("lanz") as Object
	return not (lanz != null and lanz.has_method("libro_abierto") and bool(lanz.call("libro_abierto")))


## Q: usa el equipado. Lo llama la tecla y el menú (Enter sobre el consumible ya equipado).
func usar_equipado() -> bool:
	return libre() and consumibles.usar_equipado()


## R: pasa al siguiente consumible que tengas y lo dice.
func cambiar_equipado() -> String:
	if not libre():
		return consumibles.equipado()
	var id: String = consumibles.siguiente()
	if id == "":
		_avisar("No tienes ningún consumible", Consumibles.COLOR_NO)
	else:
		_avisar("Equipado: %s (%d)" % [Objetos.nombre(id), consumibles.cantidad(id)], Objetos.color(id).lightened(0.35))
	return id


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or k.alt_pressed or k.ctrl_pressed or k.meta_pressed:
		return
	if k.keycode == KEY_Q:
		if libre():
			get_viewport().set_input_as_handled()
			consumibles.usar_equipado()
	elif k.keycode == KEY_R:
		if libre():
			get_viewport().set_input_as_handled()
			cambiar_equipado()


## --- Los frascos de reserva: n botellas, llenas del color de la tinta o vacías ---
class Frascos extends Control:
	const LADO_PX: float = 30.0
	const SEP_PX: float = 2.0
	const ALTO_PX: float = 34.0
	const T_DESTELLO_S: float = 0.55
	const VIDRIO: Color = Color(0.86, 0.80, 0.68, 0.92)
	const VIDRIO_VACIO: Color = Color(0.08, 0.07, 0.11, 0.78)
	const CORCHO: Color = Color(0.55, 0.36, 0.20)
	var llenos: int = 3
	var total: int = 3
	var color: Color = Color(0.30, 0.55, 1.0)
	var _t_destello: float = 0.0
	var _i_destello: int = -1

	func _init() -> void:
		custom_minimum_size = Vector2(HudEoW.ANCHO_FRASCOS_PX, ALTO_PX)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func poner(p_llenos: int, p_total: int, p_color: Color) -> void:
		if p_llenos != llenos or p_total != total or not p_color.is_equal_approx(color):
			llenos = p_llenos
			total = p_total
			color = p_color
			queue_redraw()

	func destello(indice: int) -> void:
		_i_destello = indice
		_t_destello = T_DESTELLO_S
		set_process(true)
		queue_redraw()

	func _process(delta: float) -> void:
		_t_destello = maxf(0.0, _t_destello - delta)
		queue_redraw()
		if _t_destello <= 0.0:
			set_process(false)

	func _draw() -> void:
		for i in range(total):
			_botella(i, i < llenos)

	func _botella(i: int, lleno: bool) -> void:
		var cx: float = LADO_PX * 0.5 + float(i) * (LADO_PX + SEP_PX)
		var pop: float = 0.0
		if i == _i_destello and _t_destello > 0.0:
			pop = _t_destello / T_DESTELLO_S                       # 1 al vaciarse, 0 al acabar
		var cy: float = 22.0
		var r: float = 10.5 + pop * 2.5
		# Sombra y cuerpo de vidrio.
		draw_circle(Vector2(cx, cy + 1.5), r + 1.5, Color(0, 0, 0, 0.45))
		draw_circle(Vector2(cx, cy), r + 1.0, TemaInterfaz.BORDE_CALIDO_OSCURO)
		draw_circle(Vector2(cx, cy), r, VIDRIO if lleno else VIDRIO_VACIO)
		if lleno:
			draw_circle(Vector2(cx, cy + 0.5), r - 2.0, color.darkened(0.3))
			draw_circle(Vector2(cx, cy + 1.0), r - 3.2, color)
			draw_circle(Vector2(cx - 3.2, cy - 3.0), 2.2, Color(1, 1, 1, 0.7))
		else:
			draw_arc(Vector2(cx, cy), r - 1.0, 0.0, TAU, 20, Color(1, 1, 1, 0.16), 1.2, true)
			draw_circle(Vector2(cx - 3.2, cy - 3.0), 1.6, Color(1, 1, 1, 0.14))
		# Cuello y corcho.
		var cuello := Rect2(Vector2(cx - 3.8, 5.0), Vector2(7.6, 9.0))
		draw_rect(cuello, TemaInterfaz.BORDE_CALIDO_OSCURO)
		draw_rect(cuello.grow(-1.0), VIDRIO if lleno else VIDRIO_VACIO)
		draw_rect(Rect2(Vector2(cx - 4.8, 1.0), Vector2(9.6, 5.0)), CORCHO)
		draw_rect(Rect2(Vector2(cx - 4.8, 1.0), Vector2(9.6, 5.0)), TemaInterfaz.BORDE_CALIDO_OSCURO, false, 1.0)
		if pop > 0.0:
			draw_circle(Vector2(cx, cy), r + 3.0, Color(1, 1, 1, 0.45 * pop))


## --- El círculo del consumible equipado ---
class Circulo extends Control:
	const RADIO_PX: float = 38.0
	const RADIO_ICONO_PX: float = 22.0
	var consumibles: Consumibles = null

	func _init() -> void:
		custom_minimum_size = Vector2(HudEoW.LADO_CIRCULO_PX, HudEoW.LADO_CIRCULO_PX + 18.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		if consumibles != null and (consumibles.escudo_activo() or consumibles.regen_activa()):
			queue_redraw()                                              # el anillo de tiempo se mueve; sin efectos activos no gasta redibujados

	func _draw() -> void:
		if consumibles == null:
			return
		var f: Font = TemaInterfaz.fuente()
		var c := Vector2(size.x - RADIO_PX - 14.0, RADIO_PX + 12.0)
		var id: String = consumibles.equipado()
		var n: int = consumibles.cantidad(id) if id != "" else 0
		# Sombra, fondo oscuro y marco dorado con filete interior (como el resto de marcos de la interfaz).
		draw_circle(c + Vector2(0, 3), RADIO_PX + 3.0, Color(0, 0, 0, 0.5))
		draw_circle(c, RADIO_PX + 2.0, TemaInterfaz.BORDE_CALIDO_OSCURO)
		draw_circle(c, RADIO_PX, Color(0.07, 0.06, 0.11, 0.94))
		draw_arc(c, RADIO_PX - 1.0, 0.0, TAU, 48, TemaInterfaz.BORDE_CALIDO, 3.0, true)
		draw_arc(c, RADIO_PX - 5.0, 0.0, TAU, 48, Color(TemaInterfaz.BORDE_CALIDO, 0.25), 1.2, true)
		# El icono (apagado si no queda ninguno).
		if id != "":
			Objetos.dibujar(self, id, c + Vector2(0, -2), RADIO_ICONO_PX)
			if n <= 0:
				draw_circle(c, RADIO_PX - 2.0, Color(0.05, 0.05, 0.08, 0.62))
		else:
			draw_string(f, c + Vector2(-8, 8), "—", HORIZONTAL_ALIGNMENT_CENTER, 16.0, 26, Color(1, 1, 1, 0.35))
		# Anillo de tiempo del bálsamo o de la infusión.
		var anillo: Array = _anillo()
		if anillo[0] > 0.0:
			draw_arc(c, RADIO_PX + 6.0, -PI * 0.5, -PI * 0.5 + TAU * float(anillo[0]), 40, Color(0, 0, 0, 0.6), 6.0, true)
			draw_arc(c, RADIO_PX + 6.0, -PI * 0.5, -PI * 0.5 + TAU * float(anillo[0]), 40, anillo[1] as Color, 3.5, true)
		# La cantidad: una chapa abajo a la derecha.
		if id != "":
			var p := c + Vector2(RADIO_PX * 0.72, RADIO_PX * 0.66)
			draw_circle(p, 13.0, TemaInterfaz.BORDE_CALIDO_OSCURO)
			draw_circle(p, 11.5, Color(0.07, 0.06, 0.11, 0.97))
			draw_arc(p, 11.5, 0.0, TAU, 20, TemaInterfaz.BORDE_CALIDO, 1.6, true)
			draw_string(f, p + Vector2(-13.0, 6.0), str(n), HORIZONTAL_ALIGNMENT_CENTER, 26.0, 16, TemaInterfaz.TEXTO if n > 0 else Color(1.0, 0.5, 0.45))
		# Las teclas: Q (usar) a la izquierda y R (siguiente) arriba a la derecha.
		_tecla(f, c + Vector2(-RADIO_PX - 6.0, -4.0), "Q", 24.0)
		_tecla(f, c + Vector2(RADIO_PX * 0.8, -RADIO_PX * 0.95), "R", 20.0)
		# El nombre, debajo, con contorno.
		var nombre: String = Objetos.nombre(id) if id != "" else "Sin consumible"
		var y: float = c.y + RADIO_PX + 20.0
		draw_string_outline(f, Vector2(0.0, y), nombre, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, TemaInterfaz.CONTORNO_PX, TemaInterfaz.CONTORNO)
		draw_string(f, Vector2(0.0, y), nombre, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, TemaInterfaz.TEXTO)

	## [fracción que queda (0 = nada que pintar), color] del efecto activo.
	func _anillo() -> Array:
		if consumibles.escudo_activo():
			return [consumibles.escudo_t / maxf(float(Objetos.efecto("balsamo_protector").get("dura", 20.0)), 0.1), HudEoW.COLOR_ESCUDO]
		if consumibles.regen_activa():
			return [consumibles.regen_t / maxf(float(Objetos.efecto("infusion_brezo").get("dura", 12.0)), 0.1), HudEoW.COLOR_REGEN]
		return [0.0, Color.WHITE]

	## Una placa pequeña con la letra de la tecla, centrada en `p`.
	func _tecla(f: Font, p: Vector2, letra: String, lado: float) -> void:
		var caja := StyleBoxFlat.new()
		caja.bg_color = Color(0.07, 0.06, 0.11, 0.95)
		caja.border_color = TemaInterfaz.BORDE_CALIDO
		caja.set_border_width_all(2)
		caja.set_corner_radius_all(int(lado * 0.28))
		caja.anti_aliasing = true
		var r := Rect2(p - Vector2(lado, lado) * 0.5, Vector2(lado, lado))
		caja.draw(get_canvas_item(), r)
		var cuerpo: int = int(lado * 0.62)
		draw_string(f, Vector2(r.position.x, r.position.y + lado * 0.5 + cuerpo * 0.36), letra, HORIZONTAL_ALIGNMENT_CENTER, lado, cuerpo, TemaInterfaz.TEXTO)
