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
const SEP_TINTA_PX: float = 6.0
const CRECIMIENTO_BARRA_PX: float = 0.8       ## px extra por cada punto de capacidad ganado
const LADO_CIRCULO_PX: float = 120.0
const MARGEN_CIRCULO_PX: float = 14.0
const T_AVISO_TINTA_S: float = 0.35
const T_FLOTA_S: float = 1.3                    ## s que dura el «+20» flotando junto a la barra de tinta
const ROTULOS_GOLPE: Dictionary = {GolpeCuerpo.TIPO_TINTA_GOLPE: "", GolpeCuerpo.TIPO_TINTA_GOLPE_ESCUDO: "¡Escudo roto!"}    ## C5: rótulos de la tinta del golpe F ("" = solo el «+5»)
const T_SUBE_PX: float = 16.0                 ## px que sube mientras se desvanece
const COLOR_VIDA_ALTA: Color = Color("a44738")
const COLOR_VIDA_MEDIA: Color = Color("9c5423")
const COLOR_VIDA_BAJA: Color = Color("951e2a")
const COLOR_TINTA_BAJA: Color = Color(1.0, 0.3, 0.25)
const COLOR_TINTA_SIN: Color = Color(0.5, 0.5, 0.55)
const COLOR_ESCUDO: Color = Color(1.0, 0.85, 0.4)
const COLOR_REGEN: Color = Color(0.8, 0.55, 1.0)
## GAMEFEEL M (31/10). Con `Sensacion3D.ACTIVA = false` el destello, el temblor, el giro y el pulso de vida no se hacen; los sonidos sí.
static var DB_NO_PUEDES: float = -14.0         ## un consumible que no se puede usar
static var T_DESTELLO_S: float = 0.2           ## destello del círculo al equipar
static var T_TEMBLOR_S: float = 0.15           ## temblor del círculo al rechazar
static var T_GIRO_S: float = 0.15              ## el icono gira 180° al cambiar de consumible con R
## E3 (6/11): AVISO DE VIDA BAJA. Fallo que evita: con 20 de 100 de vida la barra solo se ponía roja, y en pleno combate nadie mira la barra. Mientras la vida esté por debajo de
## `Sensacion3D.VIDA_BAJA` (25 %) hay un borde rojo tenue en la pantalla y la barra de vida late; se apaga solo al curar. El latido SONORO ya existe (`DirectorSensacion`, lote 4): aquí no hay sonido.
static var ALFA_BORDE_VIDA_BAJA: float = 0.28  ## opacidad máxima del borde rojo (la viñeta del golpe llega a 0,5–0,65, así que se distingue de ella)
static var T_LATIDO_VIDA_BAJA_S: float = 1.2   ## s entre latido y latido del borde y de la barra (nunca más rápido)
static var COLOR_BORDE_VIDA_BAJA: Color = Color(0.85, 0.05, 0.05)

var jugador: Node = null
var consumibles: Consumibles = Consumibles.new()
var _vida: BarraHud
var _tinta: BarraHud
var _frascos: Frascos
var _circulo: Circulo
var _t_aviso: float = 0.0
var _vida_vista: float = -1.0
var aviso_vida_baja: bool = false              ## E3: la vida está por debajo de Sensacion3D.VIDA_BAJA (la prueba lo lee)
var _borde_vida: ColorRect = null              ## E3: el borde rojo (la misma viñeta del golpe, a otra intensidad)
var _t_latido_vida: float = 0.0


func _ready() -> void:
	layer = 9
	add_to_group("hud_eow")
	var raiz := Control.new()
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(raiz)
	_borde_vida = ColorRect.new()                 # E3: primero, para que quede DETRÁS de las barras
	_borde_vida.name = "BordeVidaBaja"
	_borde_vida.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_borde_vida.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = Sensacion3D.CODIGO_VINETA
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("color", COLOR_BORDE_VIDA_BAJA)
	mat.set_shader_parameter("fuerza", 0.0)
	_borde_vida.material = mat
	_borde_vida.visible = false
	raiz.add_child(_borde_vida)
	var y0: float = Jugador3D.Y_BARRAS
	_vida = BarraHud.new()
	_vida.position = Vector2(X_PX, y0)
	_vida.poner_ancho(ANCHO_PX)
	raiz.add_child(_vida)
	_frascos = Frascos.new()
	_frascos.position = Vector2(X_PX, y0 + SEP_FILA_PX)
	raiz.add_child(_frascos)
	_tinta = BarraHud.new()
	_tinta.position = Vector2(X_PX + ANCHO_FRASCOS_PX + SEP_TINTA_PX, y0 + SEP_FILA_PX)
	_tinta.poner_ancho(ANCHO_PX - ANCHO_FRASCOS_PX - SEP_TINTA_PX)
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
	consumibles.rechazado.connect(_al_rechazar)
	Estado.i().cambiado.connect(consumibles.al_cambiar_mochila)
	var t: Tinta = _tinta_jugador()
	if t != null:
		t.frasco_gastado.connect(_al_gastar_frasco)
		t.frasco_recargado.connect(_al_recargar_frasco)
		t.insuficiente.connect(func(_f: String, _c: float, _h: float) -> void: _t_aviso = T_AVISO_TINTA_S)
		t.reaccion_premiada.connect(_al_premiar_reaccion)
	consumibles.al_cambiar_mochila()          # equipa el primero que haya (con la mochila como esté al montar)
	actualizar()
	_vida.peso_dano = true                    # gamefeel U8: desde ahora, perder vida deja franja fantasma y flash (la tinta no: baja a cada hechizo)


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
	_latido_vida_baja(delta)


## E3: mientras `aviso_vida_baja`, el borde rojo sube de golpe en cada latido y baja despacio (un latido cada T_LATIDO_VIDA_BAJA_S) y la barra de vida da su pulso a la vez. Apagado, nada.
func _latido_vida_baja(delta: float) -> void:
	if _borde_vida == null:
		return
	if not aviso_vida_baja:
		_t_latido_vida = 0.0
		return
	var antes: float = _t_latido_vida
	_t_latido_vida = fmod(_t_latido_vida + delta, maxf(T_LATIDO_VIDA_BAJA_S, 0.1))
	if _t_latido_vida < antes and _vida != null:
		_vida.pulso()                                # dio la vuelta: empieza un latido nuevo
	var fase: float = _t_latido_vida / maxf(T_LATIDO_VIDA_BAJA_S, 0.1)
	var k: float = 0.45 + 0.55 * exp(-4.0 * fase)
	(_borde_vida.material as ShaderMaterial).set_shader_parameter("fuerza", ALFA_BORDE_VIDA_BAJA * k)


## Pone las barras y los frascos como están ahora (lo llama `_process`; público para las pruebas y las capturas).
func actualizar() -> void:
	if _vida == null or jugador == null:
		return
	var vmax: float = maxf(Estado.i().vida_max, 1.0)
	_vida.poner_ancho(_ancho_barra(ANCHO_PX, vmax - Estado.VIDA_BASE))
	var v: float = float(jugador.get("vida"))
	var fr: float = clampf(v / vmax, 0.0, 1.0)
	aviso_vida_baja = Sensacion3D.ACTIVA and v > 0.0 and fr < Sensacion3D.VIDA_BAJA and not bool(jugador.get("muerto"))
	if _borde_vida != null:
		_borde_vida.visible = aviso_vida_baja
	_vida.poner_fraccion(fr)
	_vida.poner_color(COLOR_VIDA_ALTA if fr > 0.5 else (COLOR_VIDA_MEDIA if fr > 0.25 else COLOR_VIDA_BAJA))
	_vida.poner_rotulo("Vida %d/%d" % [int(round(v)), int(vmax)])
	var t: Tinta = _tinta_jugador()
	if t == null:
		return
	_tinta.poner_ancho(_ancho_barra(ANCHO_PX - ANCHO_FRASCOS_PX - SEP_TINTA_PX, t.maxima - Tinta.MAXIMA_INICIAL))
	_tinta.poner_fraccion(t.fraccion())
	var col: Color = t.color().darkened(0.25)
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


## La capacidad amplía la barra hacia la derecha sin mover el origen ni los frascos.
func _ancho_barra(ancho_base: float, capacidad_extra: float) -> float:
	var espacio_extra: float = maxf(0.0, get_viewport().get_visible_rect().size.x * 0.5 - X_PX - ANCHO_PX)
	return ancho_base + clampf(capacidad_extra * CRECIMIENTO_BARRA_PX, 0.0, espacio_extra)


## C2 (28/10): «¡Hundido! +20» junto a la barra de tinta: sube unos píxeles y se desvanece (sutil, ~1,3 s) con un tintineo suave.
func _al_premiar_reaccion(tipo: String, cantidad: float) -> void:
	if _tinta == null or not is_instance_valid(_tinta):
		return
	var l := Label.new()
	# C5 (6/11): el golpe F que acierta también entra por aquí; su rótulo es solo «+5» (o «¡Escudo roto! +10»), no el nombre de una reacción. Sin esto saldría «golpe +5».
	var rotulo: String = String(ROTULOS_GOLPE[tipo]) if ROTULOS_GOLPE.has(tipo) else String(Tinta.REACCIONES_PREMIADAS.get(tipo, tipo))
	l.text = ("%s +%d" % [rotulo, int(round(cantidad))]).strip_edges() if rotulo != "" else "+%d" % int(round(cantidad))
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = _tinta.position + Vector2(_tinta.size.x + 8.0, -6.0)
	_tinta.get_parent().add_child(l)
	var tw: Tween = l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - T_SUBE_PX, T_FLOTA_S)
	tw.tween_property(l, "modulate:a", 0.0, T_FLOTA_S).set_delay(T_FLOTA_S * 0.4)
	tw.chain().tween_callback(l.queue_free)
	if jugador is Node3D:
		Sfx.play(jugador as Node3D, "logro_pista")


func _al_gastar_frasco() -> void:
	_frascos.destello(_tinta_jugador().frascos)       # el frasco que acaba de vaciarse (su índice = los que quedan llenos)
	_avisar("Frasco de tinta gastado (quedan %d)" % _tinta_jugador().frascos, Color(0.6, 0.8, 1.0))


## Gamefeel U8: un frasco vacío se acaba de llenar (tónico de tinta): el frasco destella del color de la tinta. Sin `Sensacion3D.ACTIVA`, nada.
func _al_recargar_frasco(indice: int) -> void:
	if _frascos != null and Sensacion3D.ACTIVA:
		_frascos.destello_recarga(indice)


## M4: un consumible que no se pudo usar (vida llena, sin unidades...): `no_puedes` suave y el círculo tiembla.
func _al_rechazar(_motivo: String) -> void:
	Sfx.play_ui("no_puedes_ui", DB_NO_PUEDES)
	if _circulo != null:
		_circulo.temblar()


## M3: el menú acaba de equipar un consumible: el círculo destella 0,2 s.
func destello_equipado() -> void:
	if _circulo != null:
		_circulo.destello()


## M4: la poción terminó de hacer efecto: la barra de vida recibe un pulso (franja clara por delante del relleno).
func pulso_vida() -> void:
	if _vida != null and Sensacion3D.ACTIVA:
		_vida.pulso()


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
		Sfx.play_ui("no_puedes_ui", DB_NO_PUEDES)
		if _circulo != null:
			_circulo.temblar()
	else:
		_avisar("Equipado: %s (%d)" % [Objetos.nombre(id), consumibles.cantidad(id)], Objetos.color(id).lightened(0.35))
		Sfx.play_ui("ui_tick")                      # M4: R cambia de consumible: tic y el icono gira 180°
		if _circulo != null:
			_circulo.girar()
	return id


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or k.alt_pressed or k.ctrl_pressed or k.meta_pressed:
		return
	if k.is_action("usar_consumible"):
		if libre() and not (jugador != null and jugador.has_method("lleva_carga") and bool(jugador.call("lleva_carga"))):      # 4/11: Q con un objeto en brazos lo suelta (CargarObjeto3D), no bebe
			get_viewport().set_input_as_handled()
			consumibles.usar_equipado()
	elif k.is_action("cambiar_consumible"):
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
	var _recarga: bool = false                  ## el destello en curso es de recarga (halo de color) y no de vaciado (halo blanco)

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
		_recarga = false
		set_process(true)
		queue_redraw()

	## Gamefeel U8: el frasco `indice` se acaba de llenar: halo del color de la tinta que se encoge hacia el frasco.
	func destello_recarga(indice: int) -> void:
		_i_destello = indice
		_t_destello = T_DESTELLO_S
		_recarga = true
		set_process(true)
		queue_redraw()

	func destello_activo() -> bool:
		return _t_destello > 0.0

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
			var halo: Color = color.lightened(0.5) if _recarga else Color(1, 1, 1)
			draw_circle(Vector2(cx, cy), r + 3.0 + (4.0 * pop if _recarga else 0.0), Color(halo.r, halo.g, halo.b, (0.6 if _recarga else 0.45) * pop))


## --- El círculo del consumible equipado ---
class Circulo extends Control:
	const RADIO_PX: float = 38.0
	const RADIO_ICONO_PX: float = 22.0
	var consumibles: Consumibles = null
	## Efectos de la tarea M (31/10): cada uno con su Tween (las pruebas miran que esté vivo). Corren aunque el árbol esté en pausa (se equipa desde el menú).
	var fx_destello: float = 0.0:                 ## 1 → 0 al equipar
		set(v):
			fx_destello = v
			queue_redraw()
	var fx_tembl: float = 0.0:                    ## px de desplazamiento horizontal mientras tiembla
		set(v):
			fx_tembl = v
			queue_redraw()
	var fx_giro: float = 0.0:                     ## rad de giro del icono (0 → π al pulsar R)
		set(v):
			fx_giro = v
			queue_redraw()
	var tween_destello: Tween = null
	var tween_tembl: Tween = null
	var tween_giro: Tween = null

	func _init() -> void:
		custom_minimum_size = Vector2(HudEoW.LADO_CIRCULO_PX, HudEoW.LADO_CIRCULO_PX + 18.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _nuevo_tween(viejo: Tween) -> Tween:
		if viejo != null and viejo.is_valid():
			viejo.kill()
		return create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	func destello() -> void:
		if not Sensacion3D.ACTIVA:
			return
		fx_destello = 1.0
		tween_destello = _nuevo_tween(tween_destello)
		tween_destello.tween_property(self, "fx_destello", 0.0, HudEoW.T_DESTELLO_S)

	func temblar() -> void:
		if not Sensacion3D.ACTIVA:
			return
		tween_tembl = _nuevo_tween(tween_tembl)
		tween_tembl.tween_method(func(t: float) -> void: fx_tembl = sin(t * TAU * 3.0) * 6.0 * (1.0 - t), 0.0, 1.0, HudEoW.T_TEMBLOR_S)
		tween_tembl.tween_callback(func() -> void: fx_tembl = 0.0)

	func girar() -> void:
		if not Sensacion3D.ACTIVA:
			return
		fx_giro = -PI                                 # el icono nuevo aparece boca abajo y gira 180° hasta quedar derecho
		tween_giro = _nuevo_tween(tween_giro)
		tween_giro.tween_property(self, "fx_giro", 0.0, HudEoW.T_GIRO_S).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	func _process(_delta: float) -> void:
		if consumibles != null and (consumibles.escudo_activo() or consumibles.regen_activa()):
			queue_redraw()                                              # el anillo de tiempo se mueve; sin efectos activos no gasta redibujados

	func _draw() -> void:
		if consumibles == null:
			return
		var f: Font = TemaInterfaz.fuente()
		var c := Vector2(size.x - RADIO_PX - 14.0, RADIO_PX + 12.0)
		if fx_tembl != 0.0:
			draw_set_transform(Vector2(fx_tembl, 0.0), 0.0, Vector2.ONE)
		var id: String = consumibles.equipado()
		var n: int = consumibles.cantidad(id) if id != "" else 0
		# Sombra, pergamino y marco cálido con filete interior.
		draw_circle(c + Vector2(0, 3), RADIO_PX + 3.0, Color(0, 0, 0, 0.5))
		draw_circle(c, RADIO_PX + 2.0, TemaInterfaz.BORDE_CALIDO_OSCURO)
		draw_circle(c, RADIO_PX, TemaInterfaz.PERGAMINO_HUD)
		draw_arc(c, RADIO_PX - 1.0, 0.0, TAU, 48, TemaInterfaz.BORDE_CALIDO, 3.0, true)
		draw_arc(c, RADIO_PX - 5.0, 0.0, TAU, 48, Color(TemaInterfaz.BORDE_CALIDO, 0.25), 1.2, true)
		# El icono (apagado si no queda ninguno).
		if id != "":
			if fx_giro != 0.0:
				draw_set_transform(c + Vector2(fx_tembl, 0.0), fx_giro, Vector2.ONE)          # el icono gira sobre el centro del círculo
				Objetos.dibujar(self, id, Vector2(0, -2), RADIO_ICONO_PX)
				draw_set_transform(Vector2(fx_tembl, 0.0), 0.0, Vector2.ONE)
			else:
				Objetos.dibujar(self, id, c + Vector2(0, -2), RADIO_ICONO_PX)
			if n <= 0:
				draw_circle(c, RADIO_PX - 2.0, Color(0.05, 0.05, 0.08, 0.62))
		else:
			draw_string(f, c + Vector2(-8, 8), "—", HORIZONTAL_ALIGNMENT_CENTER, 16.0, 26, TemaInterfaz.TINTA_PERGAMINO)
		if fx_destello > 0.0:
			draw_circle(c, RADIO_PX, Color(1.0, 0.95, 0.7, 0.5 * fx_destello))
			draw_arc(c, RADIO_PX + 3.0, 0.0, TAU, 48, Color(1.0, 0.9, 0.5, fx_destello), 4.0, true)
		# Anillo de tiempo del bálsamo o de la infusión.
		var anillo: Array = _anillo()
		if anillo[0] > 0.0:
			draw_arc(c, RADIO_PX + 6.0, -PI * 0.5, -PI * 0.5 + TAU * float(anillo[0]), 40, Color(0, 0, 0, 0.6), 6.0, true)
			draw_arc(c, RADIO_PX + 6.0, -PI * 0.5, -PI * 0.5 + TAU * float(anillo[0]), 40, anillo[1] as Color, 3.5, true)
		# La cantidad: una chapa abajo a la derecha.
		if id != "":
			var p := c + Vector2(RADIO_PX * 0.72, RADIO_PX * 0.66)
			draw_circle(p, 13.0, TemaInterfaz.BORDE_CALIDO_OSCURO)
			draw_circle(p, 11.5, TemaInterfaz.PERGAMINO_HUD)
			draw_arc(p, 11.5, 0.0, TAU, 20, TemaInterfaz.BORDE_CALIDO, 1.6, true)
			draw_string(f, p + Vector2(-13.0, 6.0), str(n), HORIZONTAL_ALIGNMENT_CENTER, 26.0, 16, TemaInterfaz.TINTA_PERGAMINO if n > 0 else HudEoW.COLOR_VIDA_BAJA)
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
		caja.bg_color = TemaInterfaz.PERGAMINO_DIALOGO
		caja.border_color = TemaInterfaz.BORDE_CALIDO
		caja.set_border_width_all(2)
		caja.set_corner_radius_all(int(lado * 0.28))
		caja.anti_aliasing = true
		var r := Rect2(p - Vector2(lado, lado) * 0.5, Vector2(lado, lado))
		caja.draw(get_canvas_item(), r)
		var cuerpo: int = int(lado * 0.62)
		draw_string(f, Vector2(r.position.x, r.position.y + lado * 0.5 + cuerpo * 0.36), letra, HORIZONTAL_ALIGNMENT_CENTER, lado, cuerpo, TemaInterfaz.TINTA_PERGAMINO)
