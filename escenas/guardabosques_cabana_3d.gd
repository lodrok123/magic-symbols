extends Node
## LA GUARDABOSQUES DE LA CABAÑA (26/11/2026). Nodo hijo de la maqueta en los niveles de bosque que el generador de mapas exporta con `cabana`
## (herramientas/generador_mapas/exportador_mapa.gd lo añade solo): la guardabosques es la letra `m` del plano (la maqueta crea el Pj3D y el gato); este nodo
## hace que se vuelva hacia ti, te salude al acercarte y hable con la tecla de interactuar (E), con las mismas distancias que la de Bosque 02 (escenas/bosque_02_3d.gd).
## No da nada ni vende: solo pistas (el premio de los claros de alrededor es de los puzles). Su línea de saludo se dice una vez (flag global).
## Es de EXTERIOR: la cabaña no tiene interior.

const ALCANCE_E: float = 2.7             ## unidades: hablar (la casilla mide 2,3)
const RADIO_SALUDO: float = 9.2          ## u (4 casillas): saluda la primera vez que te acercas tanto
const RADIO_ATENCION: float = 2.7
const HISTERESIS_ATENCION: float = 0.8
const T_HABLA: float = 2.5
const T_BUSCAR_MAX: float = 12.0         ## s que espera a que la maqueta haya montado a la guardabosques antes de rendirse
const F_SALUDO: String = "bosquecabana.guardabosques.saludo"
const F_HABLADO: String = "bosquecabana.guardabosques.hablado"
const NOMBRE: String = "Guardabosques"
const DIALOGO: Array = [
	"Bienvenida a mi cabaña. Hace años que nadie sube hasta aquí sin perder el aliento.",
	"Los claros de alrededor guardan viejos mecanismos del bosque. A quien los resuelve, el bosque le devuelve algo.",
	"Si un puzle se te atasca, rodéalo y mira qué piezas lo componen: casi nunca hace falta más de dos sellos.",
	"Los braseros se encienden con fuego, los cauces se llenan con agua y la tierra sostiene lo que el agua se llevaría.",
	"Cuando acabes, vuelve por el camino del río: el bosque de abajo está más tranquilo desde que pasaste.",
]

var m: Variant = null                       ## la maqueta (PruebaTest2); sin tipo: se le llaman métodos suyos
var celda: Vector2i = Vector2i(-1, -1)      ## la casilla de la letra `m`
var pj: Pj3D = null
var _aviso: Label = null
var _t_aviso: float = 0.0
var _t_habla: float = 0.0
var _t_buscar: float = 0.0
var _lineas: int = 0
var _atento: bool = false
var _saludo: bool = false
var dijo: String = ""                       ## lo último que dijo (las pruebas)


func _ready() -> void:
	call_deferred("_arrancar")


func _arrancar() -> void:
	m = get_parent()
	if m == null:
		return
	_montar_aviso()
	set_process(true)
	set_process_unhandled_input(true)


func _montar_aviso() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 6
	add_child(capa)
	_aviso = Label.new()
	_aviso.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_aviso.position = Vector2(-300.0, -120.0)
	_aviso.custom_minimum_size = Vector2(600.0, 0.0)
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.add_theme_font_size_override("font_size", 22)
	_aviso.add_theme_color_override("font_outline_color", Color.BLACK)
	_aviso.add_theme_constant_override("outline_size", 8)
	capa.add_child(_aviso)


## La casilla de la letra `m` en el plano de la maqueta ((-1, -1) si no hay).
func _celda_de_la_m() -> Vector2i:
	var mapa: Variant = (m as Object).get("_mapa") if m != null else null
	if mapa is PackedStringArray:
		for y in range((mapa as PackedStringArray).size()):
			var x: int = String((mapa as PackedStringArray)[y]).find("m")
			if x >= 0:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## El Pj3D más cercano a esa casilla que no es la jugadora ni un enemigo.
func _buscar_pj() -> Pj3D:
	if celda.x < 0:
		celda = _celda_de_la_m()
		if celda.x < 0:
			return null
	var centro: Vector3 = m.call("_centro_celda", celda, 0.0)
	var goblins: Array = m.get("_goblins") if m.get("_goblins") != null else []
	var mejor: float = 4.0
	var res: Pj3D = null
	for n in (m as Node).find_children("*", "Pj3D", true, false):
		if n is Jugador3D or goblins.has(n):
			continue
		var d: Vector3 = (n as Pj3D).position - centro
		d.y = 0.0
		if d.length() < mejor:
			mejor = d.length()
			res = n as Pj3D
	return res


static func _dist(a: Vector3, b: Vector3) -> float:
	var d: Vector3 = a - b
	d.y = 0.0
	return d.length()


func _process(delta: float) -> void:
	if m == null:
		return
	_t_aviso = maxf(_t_aviso - delta, 0.0)
	if _t_aviso <= 0.0 and _aviso != null and _aviso.text != "":
		_aviso.text = ""
	var jugador: Pj3D = m.get("_jugador") as Pj3D
	if jugador == null:
		return
	if pj == null or not is_instance_valid(pj):
		_t_buscar += delta
		if _t_buscar <= T_BUSCAR_MAX:
			pj = _buscar_pj()
		return
	if _t_habla > 0.0:
		_t_habla -= delta
		pj.mirar(jugador.position - pj.position, delta)
		if _t_habla <= 0.0:
			pj.animacion_actual = ""
			pj.jugar("idle")
		return
	var d: float = _dist(jugador.position, pj.position)
	_atento = d <= RADIO_ATENCION + (HISTERESIS_ATENCION if _atento else 0.0)
	if _atento:
		pj.mirar(jugador.position - pj.position, delta)
	if not _saludo and not Flags.i().tiene(F_SALUDO) and d <= RADIO_SALUDO:
		_saludo = true
		Flags.i().poner(F_SALUDO)
		_decir("%s: «%s»" % [NOMBRE, String(DIALOGO[0])], 6.0)
		pj.mirar(jugador.position - pj.position, 1.0)


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or m == null or m.get("_jugador") == null or pj == null or not is_instance_valid(pj):
		return
	var k: InputEventKey = ev as InputEventKey
	if not k.pressed or k.echo or not k.is_action("interactuar"):
		return
	var yo: Vector3 = (m.get("_jugador") as Pj3D).position
	if _dist(pj.position, yo) <= ALCANCE_E:
		hablar(yo)


## Habla (también lo llaman las pruebas). Devuelve el texto dicho.
func hablar(yo: Vector3) -> String:
	if pj == null or not is_instance_valid(pj):
		return ""
	var texto: String = String(DIALOGO[_lineas % DIALOGO.size()])
	_lineas += 1
	Flags.i().poner(F_HABLADO)
	_decir("%s: «%s»" % [NOMBRE, texto], 6.0)
	pj.mirar(yo - pj.position, 1.0)
	pj.animacion_actual = ""
	pj.jugar("talk")
	Sfx3D.play(pj, "conversacion_voz")
	_t_habla = T_HABLA
	return texto


func _decir(texto: String, seg: float) -> void:
	dijo = texto
	if _aviso != null:
		_aviso.text = texto
	_t_aviso = seg
