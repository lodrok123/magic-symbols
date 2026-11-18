class_name TiendaUI
extends CanvasLayer

## LA PANTALLA DE TIENDA (11/11, Juego, encargo de Pablo con su maqueta del alquimista). Se abre sola cuando una tienda avisa (`Tiendas.i().tienda_abierta`:
## el alquimista y la librera al hablar con ellos) y enseña lo que vende AHORA (`Tiendas.oferta`): solo lo desbloqueado y con existencias.
##
## ASPECTO: el del menú de la mochila (`MenuPestanas`): cuero con costura, interior de pergamino y tinta marrón. Arriba, el nombre de la tienda y el oro;
## a la izquierda, la lista (icono, nombre y precio con su moneda; la fila elegida en ámbar); a la derecha, el detalle del elegido (icono grande, nombre,
## descripción de `Objetos.descripcion` y «Quedan N»); abajo, la cantidad (− n +), el total, el botón Comprar y «Esc · Salir». Debajo, una línea que dice
## (12/11, Pablo: «una pequeña imagen del producto a la derecha de la lista tipo Breath of the Wild»): los ATUENDOS (`Atuendos`) llevan en el detalle su
## imagen de producto, la jugadora vestida con él (`arte/iconos/atuendo_*.png`, de `herramientas/captura_iconos_atuendos.gd`), más grande que un icono.
## por qué no se puede comprar (te falta oro, la mochila está llena, se ha agotado) o qué se compró.
##
## CONTROLES: ↑↓ (o W S, o la rueda) eligen, ← → (o A D) cambian la cantidad, Enter o Espacio compran, Esc cierra. Con el ratón: clic en una fila la elige
## (un segundo clic la compra), clic en − + y en Comprar. Pausa el mundo mientras está abierta, como el menú. La compra la hace `Tiendas.comprar`: aquí no hay
## reglas, solo se enseñan.

const ANCHO: float = 840.0
const ALTO: float = 500.0
const MARGEN: float = 44.0
const LISTA_X: float = 44.0
const LISTA_ANCHO: float = 420.0
const LISTA_Y: float = 104.0
const FILA_ALTO: float = 50.0
const FILA_SEP: float = 8.0
const FILAS_VISIBLES: int = 5
const DETALLE_X: float = 484.0
const DETALLE_ANCHO: float = 312.0
const BARRA_Y: float = 402.0
const BARRA_ALTO: float = 46.0
const AMBAR: Color = Color("f2c97a")
const AMBAR_BORDE: Color = Color("c9963f")
const FILA: Color = Color("f6eedb")
const BOTON: Color = Color("c66a43")
const BOTON_APAGADO: Color = Color("c8b9a0")
const ROJO: Color = Color("a5402c")
const VERDE: Color = Color("4f7a34")
const NOMBRES: Dictionary = {"alquimista": "Alquimista", "librera": "Librera", "sumicio": "Tienda de Monte Sumicio"}
const CANTIDAD_MAX: int = 20
const MOTIVOS: Dictionary = {
	"oro": "Te faltan %d de oro",
	"sitio": "No cabe en la mochila",
	"agotado": "No quedan tantas",
	"bloqueado": "Todavía no lo vende",
	"no_vende": "Eso no se vende aquí",
}

var abierta: bool = false
## 14/11: modo VENDER (Tab o clic en la pestaña «Vender»): la lista es lo que lleva la jugadora y el botón vende (`Tiendas.vender`).
var vendiendo: bool = false
var tienda: String = ""
var elegido: int = 0
var cantidad: int = 1
var mensaje: String = ""
var mensaje_bien: bool = true
var _oferta: Array = []
var _scroll: int = 0
var _velo: ColorRect
var _panel: Lamina
var _tween: Tween = null
var _pausado_por_mi: bool = false


func _ready() -> void:
	layer = 31
	process_mode = Node.PROCESS_MODE_ALWAYS
	_velo = ColorRect.new()
	_velo.color = Color(0, 0, 0, 0.45)
	_velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_velo.mouse_filter = Control.MOUSE_FILTER_STOP
	_velo.visible = false
	add_child(_velo)
	_panel = Lamina.new()
	_panel.ui = self
	_panel.size = Vector2(ANCHO, ALTO)
	_panel.visible = false
	add_child(_panel)
	get_viewport().size_changed.connect(_colocar)
	Tiendas.i().tienda_abierta.connect(abrir)
	Estado.i().cambiado.connect(_refrescar)


func _exit_tree() -> void:
	if Tiendas.i().tienda_abierta.is_connected(abrir):
		Tiendas.i().tienda_abierta.disconnect(abrir)
	if Estado.i().cambiado.is_connected(_refrescar):
		Estado.i().cambiado.disconnect(_refrescar)
	if _pausado_por_mi and is_inside_tree():
		get_tree().paused = false


func _colocar() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_panel.position = ((vp - _panel.size) * 0.5).round()
	_panel.pivot_offset = _panel.size * 0.5


## Abre la tienda `id` (lo llama la señal de `Tiendas`; también las pruebas).
func abrir(id: String) -> void:
	tienda = id
	elegido = 0
	cantidad = 1
	_scroll = 0
	mensaje = ""
	vendiendo = false
	_oferta = Tiendas.oferta(tienda)
	if abierta:
		_panel.queue_redraw()
		return
	abierta = true
	_colocar()
	_velo.visible = true
	_panel.visible = true
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.94, 0.94)
	if is_inside_tree() and not get_tree().paused:
		get_tree().paused = true
		_pausado_por_mi = true
	_animar(true)
	Sfx.play_ui("libro_abre")
	_panel.queue_redraw()


func cerrar() -> void:
	if not abierta:
		return
	abierta = false
	_velo.visible = false
	if _pausado_por_mi and is_inside_tree():
		get_tree().paused = false
	_pausado_por_mi = false
	Sfx.play_ui("libro_cierra")
	_animar(false)


func _animar(abre: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not is_inside_tree():
		_panel.visible = abre
		_panel.modulate.a = 1.0 if abre else 0.0
		_panel.scale = Vector2.ONE
		return
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_ignore_time_scale(true)
	_tween.set_parallel(true)
	_tween.tween_property(_panel, "modulate:a", 1.0 if abre else 0.0, 0.18)
	_tween.tween_property(_panel, "scale", Vector2.ONE if abre else Vector2(0.96, 0.96), 0.18).set_trans(Tween.TRANS_BACK if abre else Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if not abre:
		_tween.chain().tween_callback(func() -> void: _panel.visible = false)


## El elegido (su fila de `oferta`) o {} si la tienda está vacía.
func fila_elegida() -> Dictionary:
	return _oferta[elegido] if elegido >= 0 and elegido < _oferta.size() else {}


func elegir(i: int) -> void:
	if _oferta.is_empty():
		return
	var antes: int = elegido
	elegido = clampi(i, 0, _oferta.size() - 1)
	if elegido < _scroll:
		_scroll = elegido
	elif elegido >= _scroll + FILAS_VISIBLES:
		_scroll = elegido - FILAS_VISIBLES + 1
	if elegido != antes:
		cantidad = 1
		mensaje = ""
		Sfx.play_ui("ui_tick")
	_panel.queue_redraw()


func cambiar_cantidad(d: int) -> void:
	var f: Dictionary = fila_elegida()
	if f.is_empty():
		return
	var tope: int = CANTIDAD_MAX if int(f["quedan"]) < 0 else int(f["quedan"])
	var nueva: int = clampi(cantidad + d, 1, maxi(tope, 1))
	if nueva != cantidad:
		cantidad = nueva
		mensaje = ""
		Sfx.play_ui("ui_tick")
	_panel.queue_redraw()


## Cambia entre comprar y vender.
func cambiar_modo(vender_: bool) -> void:
	if vendiendo == vender_:
		return
	vendiendo = vender_
	elegido = 0
	cantidad = 1
	_scroll = 0
	mensaje = ""
	Sfx.play_ui("ui_tick")
	_refrescar()


## Vende `cantidad` del elegido (modo vender).
func vender() -> bool:
	var f: Dictionary = fila_elegida()
	if f.is_empty():
		return false
	var o: String = String(f["objeto"])
	var n: int = mini(cantidad, Estado.i().cuenta(o))
	var precio: int = Tiendas.precio_venta(o) * n
	if not Tiendas.vender(tienda, o, n):
		mensaje = "No se puede vender"
		mensaje_bien = false
		Sfx.play_ui("no_puedes_ui")
		_panel.queue_redraw()
		return false
	mensaje = "Has vendido %s%s por %d de oro" % [Objetos.nombre(o), "" if n == 1 else " ×%d" % n, precio]
	mensaje_bien = true
	Sfx.play_ui("moneda")
	_refrescar()
	return true


## Compra (o vende, en modo vender) `cantidad` del elegido. Devuelve si se hizo; si no, el motivo queda en `mensaje`.
func comprar() -> bool:
	if vendiendo:
		return vender()
	var f: Dictionary = fila_elegida()
	if f.is_empty():
		return false
	var o: String = String(f["objeto"])
	var p: Dictionary = Tiendas.puede(tienda, o, cantidad)
	if not bool(p["ok"]):
		var texto: String = String(MOTIVOS.get(String(p["motivo"]), "No se puede"))
		mensaje = texto % int(p["oro_falta"]) if texto.contains("%d") else texto
		mensaje_bien = false
		Sfx.play_ui("no_puedes_ui")
		_panel.queue_redraw()
		return false
	var nombre: String = String(Objetos.DATOS.get(o, {}).get("nombre", o))
	Tiendas.comprar(tienda, o, cantidad)
	mensaje = "Has comprado %s%s" % [nombre, "" if cantidad == 1 else " ×%d" % cantidad]
	mensaje_bien = true
	Sfx.play_ui("moneda")
	_refrescar()
	return true


## La oferta puede cambiar (se agotó algo, se ganó una flag): se vuelve a pedir conservando el elegido si sigue.
func _refrescar() -> void:
	if not abierta:
		return
	var id_antes: String = String(fila_elegida().get("objeto", ""))
	_oferta = Tiendas.vendibles() if vendiendo else Tiendas.oferta(tienda)
	elegido = 0
	for k in range(_oferta.size()):
		if String(_oferta[k]["objeto"]) == id_antes:
			elegido = k
	elegido = clampi(elegido, 0, maxi(_oferta.size() - 1, 0))
	var f: Dictionary = fila_elegida()
	if not f.is_empty() and int(f["quedan"]) >= 0:
		cantidad = clampi(cantidad, 1, maxi(int(f["quedan"]), 1))
	_scroll = clampi(_scroll, 0, maxi(_oferta.size() - FILAS_VISIBLES, 0))
	_panel.queue_redraw()


func oferta() -> Array:
	return _oferta


func _input(event: InputEvent) -> void:
	if not abierta:
		return
	if event is InputEventKey and (event as InputEventKey).pressed:
		var k: Key = (event as InputEventKey).keycode
		match k:
			KEY_UP, KEY_W:
				elegir(elegido - 1)
			KEY_DOWN, KEY_S:
				elegir(elegido + 1)
			KEY_LEFT, KEY_A:
				cambiar_cantidad(-1)
			KEY_RIGHT, KEY_D:
				cambiar_cantidad(1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if not (event as InputEventKey).echo:
					comprar()
			KEY_TAB, KEY_Q:
				if not (event as InputEventKey).echo:
					cambiar_modo(not vendiendo)
			KEY_ESCAPE, KEY_E, KEY_I:
				if not (event as InputEventKey).echo:
					cerrar()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var b: InputEventMouseButton = event as InputEventMouseButton
		var local: Vector2 = _panel.get_global_transform_with_canvas().affine_inverse() * b.position
		if b.button_index == MOUSE_BUTTON_WHEEL_UP:
			elegir(elegido - 1)
		elif b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			elegir(elegido + 1)
		elif b.button_index == MOUSE_BUTTON_LEFT:
			_clic(local)
		get_viewport().set_input_as_handled()


func _clic(p: Vector2) -> void:
	if _rect_pestana(false).has_point(p):
		cambiar_modo(false)
		return
	if _rect_pestana(true).has_point(p):
		cambiar_modo(true)
		return
	for v in range(FILAS_VISIBLES):
		var i: int = _scroll + v
		if i < _oferta.size() and _rect_fila(v).has_point(p):
			if i == elegido:
				comprar()
			else:
				elegir(i)
			return
	if _rect_menos().has_point(p):
		cambiar_cantidad(-1)
	elif _rect_mas().has_point(p):
		cambiar_cantidad(1)
	elif _rect_comprar().has_point(p):
		comprar()
	elif _rect_salir().has_point(p):
		cerrar()


## Las dos pestañas de la cabecera, a la derecha del nombre de la tienda: «Comprar» y «Vender».
static func _rect_pestana(vender_: bool) -> Rect2:
	return Rect2(LISTA_X + 390.0 + (124.0 if vender_ else 0.0), 46.0, 116.0, 36.0)


static func _rect_fila(v: int) -> Rect2:
	return Rect2(LISTA_X, LISTA_Y + float(v) * (FILA_ALTO + FILA_SEP), LISTA_ANCHO, FILA_ALTO)


static func _rect_cantidad() -> Rect2:
	return Rect2(LISTA_X, BARRA_Y, 150.0, BARRA_ALTO)


static func _rect_menos() -> Rect2:
	return Rect2(LISTA_X, BARRA_Y, 46.0, BARRA_ALTO)


static func _rect_mas() -> Rect2:
	return Rect2(LISTA_X + 104.0, BARRA_Y, 46.0, BARRA_ALTO)


static func _rect_comprar() -> Rect2:
	return Rect2(DETALLE_X + 10.0, BARRA_Y, 170.0, BARRA_ALTO)


static func _rect_salir() -> Rect2:
	return Rect2(DETALLE_X + 196.0, BARRA_Y, DETALLE_ANCHO - 196.0, BARRA_ALTO)


## --- El dibujo ---------------------------------------------------------------------------------------------------------------------------------------

class Lamina extends Control:
	var ui: TiendaUI

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _caja(r: Rect2, fondo: Color, borde: Color, ancho: int, radio: int) -> void:
		BolsaUI._caja(fondo, borde, ancho, radio).draw(get_canvas_item(), r)

	func _icono(id: String, centro: Vector2, lado: float) -> void:
		var t: Texture2D = BolsaUI.tex("objeto_" + id)
		if t != null:
			draw_texture_rect(t, Rect2(centro - Vector2(lado, lado) * 0.5, Vector2(lado, lado)), false)
		else:
			Objetos.dibujar(self, id, centro, lado * 0.38)

	func _moneda(centro: Vector2, lado: float) -> void:
		var arte: Texture2D = BolsaUI.tex("mochila_moneda")
		if arte != null:
			var k: float = lado / maxf(arte.get_size().y, 1.0)
			draw_texture_rect(arte, Rect2(centro - arte.get_size() * k * 0.5, arte.get_size() * k), false)
		else:
			Objetos.dibujar(self, "oro", centro, lado * 0.42)

	func _draw() -> void:
		if ui == null:
			return
		var f: Font = TemaInterfaz.fuente()
		var r := Rect2(Vector2.ZERO, size)
		# Cuero, pergamino y costura, como el menú de la mochila.
		_caja(r, BolsaUI.CUERO, BolsaUI.CUERO_SOMBRA, 3, 24)
		_caja(r.grow(-20.0), BolsaUI.PERGAMINO, BolsaUI.LINEA, 2, 14)
		BolsaUI.discontinuo(self, BolsaUI.camino(r.grow(-8.0), 18.0), BolsaUI.COSTURA, 2.0, 7.0, 5.0)
		# Cabecera: el nombre de la tienda y el oro.
		draw_string(f, Vector2(TiendaUI.MARGEN, 74.0), String(TiendaUI.NOMBRES.get(ui.tienda, ui.tienda.capitalize())), HORIZONTAL_ALIGNMENT_LEFT, 380.0, 28, MenuPestanas.TINTA)
		# Pestañas Comprar | Vender (Tab).
		for v in [false, true]:
			var rp: Rect2 = TiendaUI._rect_pestana(v)
			var activa: bool = ui.vendiendo == v
			_caja(rp, TiendaUI.AMBAR if activa else TiendaUI.FILA, TiendaUI.AMBAR_BORDE if activa else BolsaUI.LINEA, 2 if activa else 1, 9)
			draw_string(f, rp.position + Vector2(0.0, 25.0), "Vender" if v else "Comprar", HORIZONTAL_ALIGNMENT_CENTER, rp.size.x, 17, MenuPestanas.TINTA)
		draw_string(f, Vector2(TiendaUI._rect_pestana(false).position.x, 40.0), "Tab", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MenuPestanas.TINTA_SUAVE)
		var oro_txt: String = str(Estado.i().oro)
		var w_oro: float = f.get_string_size(oro_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		_moneda(Vector2(size.x - TiendaUI.MARGEN - w_oro - 24.0, 64.0), 30.0)
		draw_string(f, Vector2(size.x - TiendaUI.MARGEN - w_oro, 74.0), oro_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, MenuPestanas.TINTA)
		draw_line(Vector2(TiendaUI.MARGEN, 90.0), Vector2(size.x - TiendaUI.MARGEN, 90.0), BolsaUI.LINEA, 1.5)
		_draw_lista(f)
		_draw_detalle(f)
		_draw_barra(f)
		if ui.mensaje != "":
			draw_string(f, Vector2(0.0, size.y - 32.0), ui.mensaje, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, TiendaUI.VERDE if ui.mensaje_bien else TiendaUI.ROJO)

	func _draw_lista(f: Font) -> void:
		var oferta: Array = ui.oferta()
		if oferta.is_empty():
			draw_string(f, Vector2(TiendaUI.LISTA_X, TiendaUI.LISTA_Y + 30.0), "No llevas nada que se pueda vender" if ui.vendiendo else "No le queda nada que vender", HORIZONTAL_ALIGNMENT_LEFT, TiendaUI.LISTA_ANCHO, 17, MenuPestanas.TINTA_SUAVE)
			return
		for v in range(TiendaUI.FILAS_VISIBLES):
			var i: int = ui._scroll + v
			if i >= oferta.size():
				break
			var o: Dictionary = oferta[i]
			var id: String = String(o["objeto"])
			var fr: Rect2 = TiendaUI._rect_fila(v)
			var sel: bool = i == ui.elegido
			_caja(fr, TiendaUI.AMBAR if sel else TiendaUI.FILA, TiendaUI.AMBAR_BORDE if sel else BolsaUI.LINEA, 2 if sel else 1, 10)
			_icono(id, fr.position + Vector2(34.0, fr.size.y * 0.5), 40.0)
			draw_string(f, fr.position + Vector2(68.0, 32.0), String(Objetos.DATOS.get(id, {}).get("nombre", id)), HORIZONTAL_ALIGNMENT_LEFT, fr.size.x - 170.0, 18, MenuPestanas.TINTA)
			var precio: String = str(int(o["precio"]))
			var wp: float = f.get_string_size(precio, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			draw_string(f, fr.position + Vector2(fr.size.x - 18.0 - wp, 32.0), precio, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, MenuPestanas.TINTA)
			_moneda(fr.position + Vector2(fr.size.x - 34.0 - wp, fr.size.y * 0.5), 20.0)
		# Hay más arriba o abajo: unas flechitas.
		if ui._scroll > 0:
			draw_string(f, Vector2(TiendaUI.LISTA_X + TiendaUI.LISTA_ANCHO * 0.5 - 6.0, TiendaUI.LISTA_Y - 4.0), "▲", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MenuPestanas.TINTA_SUAVE)
		if ui._scroll + TiendaUI.FILAS_VISIBLES < oferta.size():
			var y: float = TiendaUI._rect_fila(TiendaUI.FILAS_VISIBLES - 1).end.y + 13.0
			draw_string(f, Vector2(TiendaUI.LISTA_X + TiendaUI.LISTA_ANCHO * 0.5 - 6.0, y), "▼", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MenuPestanas.TINTA_SUAVE)

	func _draw_detalle(f: Font) -> void:
		var dr := Rect2(TiendaUI.DETALLE_X, TiendaUI.LISTA_Y, TiendaUI.DETALLE_ANCHO, float(TiendaUI.FILAS_VISIBLES) * (TiendaUI.FILA_ALTO + TiendaUI.FILA_SEP) - TiendaUI.FILA_SEP)
		_caja(dr, BolsaUI.PERGAMINO_CLARO, BolsaUI.LINEA, 1, 12)
		var o: Dictionary = ui.fila_elegida()
		if o.is_empty():
			return
		var id: String = String(o["objeto"])
		var cx: float = dr.position.x + dr.size.x * 0.5
		var producto: bool = Atuendos.es_atuendo(id)        # 12/11: la imagen del producto (la jugadora vestida), grande y sin aro de calidad
		var imagen: Texture2D = Objetos.icono(id, 150.0) if producto else null
		if imagen != null:
			draw_texture_rect(imagen, Rect2(Vector2(cx - 75.0, dr.position.y + 8.0), Vector2(150.0, 150.0)), false)
		else:
			_icono(id, Vector2(cx, dr.position.y + (82.0 if producto else 66.0)), 150.0 if producto else 104.0)
		draw_string(f, Vector2(dr.position.x, dr.position.y + (170.0 if producto else 148.0)), String(Objetos.DATOS.get(id, {}).get("nombre", id)), HORIZONTAL_ALIGNMENT_CENTER, dr.size.x, 22, MenuPestanas.TINTA)
		var desc: String = Objetos.descripcion(id)
		draw_multiline_string(f, Vector2(dr.position.x + 18.0, dr.position.y + (192.0 if producto else 174.0)), desc, HORIZONTAL_ALIGNMENT_CENTER, dr.size.x - 36.0, 14, 3 if producto else 4, MenuPestanas.TINTA_SUAVE)
		var y_linea: float = dr.end.y - 44.0
		draw_line(Vector2(dr.position.x + 24.0, y_linea), Vector2(dr.end.x - 24.0, y_linea), BolsaUI.LINEA, 1.0)
		var q: int = int(o["quedan"])
		var tienes: int = Estado.i().cuenta(id)
		var pie: String = ("Quedan %d" % q if q >= 0 else "Sin límite") + ("  ·  Tienes %d" % tienes if tienes > 0 else "")
		if ui.vendiendo:
			pie = "Tienes %d  ·  Te pagan %d por unidad" % [tienes, int(o["precio"])]
		draw_string(f, Vector2(dr.position.x, dr.end.y - 16.0), pie, HORIZONTAL_ALIGNMENT_CENTER, dr.size.x, 16, MenuPestanas.TINTA)

	func _draw_barra(f: Font) -> void:
		var o: Dictionary = ui.fila_elegida()
		# Cantidad: − n +
		var rc: Rect2 = TiendaUI._rect_cantidad()
		_caja(rc, TiendaUI.FILA, BolsaUI.LINEA, 1, 10)
		draw_string(f, TiendaUI._rect_menos().position + Vector2(0.0, 31.0), "−", HORIZONTAL_ALIGNMENT_CENTER, 46.0, 24, MenuPestanas.TINTA)
		draw_string(f, TiendaUI._rect_mas().position + Vector2(0.0, 31.0), "+", HORIZONTAL_ALIGNMENT_CENTER, 46.0, 24, MenuPestanas.TINTA)
		draw_string(f, rc.position + Vector2(46.0, 31.0), str(ui.cantidad), HORIZONTAL_ALIGNMENT_CENTER, 58.0, 20, MenuPestanas.TINTA)
		# Total.
		var total: int = int(o.get("precio", 0)) * ui.cantidad
		var x_total: float = rc.end.x + 40.0
		draw_line(Vector2(rc.end.x + 18.0, rc.position.y + 8.0), Vector2(rc.end.x + 18.0, rc.end.y - 8.0), BolsaUI.LINEA, 1.0)
		_moneda(Vector2(x_total + 12.0, rc.position.y + rc.size.y * 0.5), 24.0)
		var falta: bool = total > Estado.i().oro and not ui.vendiendo
		draw_string(f, Vector2(x_total + 32.0, rc.position.y + 31.0), ("+%d" % total) if ui.vendiendo else str(total), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, TiendaUI.ROJO if falta else (TiendaUI.VERDE if ui.vendiendo else MenuPestanas.TINTA))
		# Comprar / Vender.
		var rb: Rect2 = TiendaUI._rect_comprar()
		var se_puede: bool = false
		if not o.is_empty():
			se_puede = Estado.i().cuenta(String(o["objeto"])) >= ui.cantidad if ui.vendiendo else bool(Tiendas.puede(ui.tienda, String(o["objeto"]), ui.cantidad)["ok"])
		_caja(rb, TiendaUI.BOTON if se_puede else TiendaUI.BOTON_APAGADO, BolsaUI.CUERO_SOMBRA, 2, 10)
		draw_string(f, rb.position + Vector2(0.0, 31.0), "Vender" if ui.vendiendo else "Comprar", HORIZONTAL_ALIGNMENT_CENTER, rb.size.x, 20, Color.WHITE if se_puede else Color(1, 1, 1, 0.8))
		# Salir.
		var rs: Rect2 = TiendaUI._rect_salir()
		draw_line(Vector2(rs.position.x - 8.0, rs.position.y + 8.0), Vector2(rs.position.x - 8.0, rs.end.y - 8.0), BolsaUI.LINEA, 1.0)
		draw_string(f, rs.position + Vector2(0.0, 30.0), "Esc · Salir", HORIZONTAL_ALIGNMENT_CENTER, rs.size.x, 15, MenuPestanas.TINTA_SUAVE)
