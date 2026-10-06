class_name PlayLog3D
extends Node

## MEDICIONES DEL TEST 3 (4.5). Dueño: Juego.
##
## Qué mide, sin tocar PlayLog (el del 2D, que se usa tal cual: volcado a user://playtest_logs):
##   - gestos reconocidos / rechazados / confundidos (los cuenta Lanzador3D al entrar por add_gesture y add_sigil)
##   - manifestaciones por hechizo y las vivas a la vez (máximo)
##   - milisegundos por fotograma (media, p95 y peor de los últimos 300), VRAM, llamadas de dibujo
##   - casillas vivas (estado del suelo + tierra + hielo) y nodos
##   - errores y avisos de la consola (se capturan con un Logger y se apuntan en el diario)
##
## Panel F12: lo enseña y lo esconde. Al cerrar el juego escribe una línea "resumen_3d" en el diario, que es
## lo que se pega en la tabla de medición de DISENO_FUTURO.md §0.
##
## Se usa desde cualquier sitio con las funciones estáticas:  PlayLog3D.gesto("rechazado", "hueco ocupado")

const VENTANA: int = 300
const MAX_ERRORES_VISTOS: int = 6

static var gestos: Dictionary = {"reconocido": 0, "rechazado": 0, "confundido": 0}
static var detalle_gestos: Dictionary = {}          ## "clase|texto" -> veces
static var lanzamientos: int = 0
static var manifestaciones_total: int = 0
static var manifestaciones_max: int = 0
static var por_forma: Dictionary = {}               ## forma -> veces
static var por_elemento: Dictionary = {}            ## elemento -> veces
static var errores_total: int = 0
static var avisos_total: int = 0
static var instancia: PlayLog3D = null

var lanz: Node = null            ## Lanzador3D (para las manifestaciones vivas y las casillas)
var mundo: Node = null           ## PruebaTest2

var _ms: PackedFloat32Array = PackedFloat32Array()
var _i: int = 0
var _panel: Label = null
var _capa: CanvasLayer = null
var _captura: Captura = null
var _t_panel: float = 0.0
var _t_vivas: float = 0.0
var _vivas_max: int = 0
var _vram_max: float = 0.0
var _resumen_hecho: bool = false


## --- Registro (estático) ---

static func gesto(clase: String, texto: String = "") -> void:
	gestos[clase] = int(gestos.get(clase, 0)) + 1
	var k: String = "%s|%s" % [clase, texto.left(60)]
	detalle_gestos[k] = int(detalle_gestos.get(k, 0)) + 1
	PlayLog.event("gesto_3d", {"clase": clase, "detalle": texto.left(80)})


static func manifestaciones(n: int, forma: String, elemento: String) -> void:
	lanzamientos += 1
	manifestaciones_total += n
	manifestaciones_max = maxi(manifestaciones_max, n)
	por_forma[forma] = int(por_forma.get(forma, 0)) + 1
	por_elemento[elemento] = int(por_elemento.get(elemento, 0)) + 1


static func reiniciar() -> void:
	gestos = {"reconocido": 0, "rechazado": 0, "confundido": 0}
	detalle_gestos.clear()
	lanzamientos = 0
	manifestaciones_total = 0
	manifestaciones_max = 0
	por_forma.clear()
	por_elemento.clear()
	errores_total = 0
	avisos_total = 0


## Pone el medidor en el árbol. Lo llama Jugador3D.montar().
static func montar(p_mundo: Node, p_lanz: Node) -> PlayLog3D:
	reiniciar()
	var p := PlayLog3D.new()
	p.name = "PlayLog3D"
	p.mundo = p_mundo
	p.lanz = p_lanz
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p_mundo.add_child(p)
	return p


func _ready() -> void:
	instancia = self
	_ms.resize(VENTANA)
	_captura = Captura.new()
	OS.add_logger(_captura)
	_capa = CanvasLayer.new()
	_capa.layer = 30
	add_child(_capa)
	_panel = Label.new()
	_panel.position = Vector2(12.0, 150.0)
	_panel.add_theme_font_size_override("font_size", 14)
	_panel.add_theme_color_override("font_outline_color", Color.BLACK)
	_panel.add_theme_constant_override("outline_size", 6)
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa.add_child(_panel)
	get_tree().set_auto_accept_quit(false)
	PlayLog.event("medicion_3d_activa", {"ventana": VENTANA})


func _exit_tree() -> void:
	if _captura != null:
		OS.remove_logger(_captura)
		_captura = null
	if instancia == self:
		instancia = null


func _notification(que: int) -> void:
	if que == NOTIFICATION_WM_CLOSE_REQUEST:
		escribir_resumen()
		get_tree().quit()


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_F12:
		_panel.visible = not _panel.visible
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# Milisegundos de RELOJ por fotograma (no de juego): con el modo lanzar a 0,7 el delta ya viene escalado.
	var real: float = delta / maxf(Engine.time_scale, 0.01) * 1000.0
	_ms[_i % VENTANA] = real
	_i += 1
	_t_vivas += delta
	if _t_vivas >= 0.5:
		_t_vivas = 0.0
		_vivas_max = maxi(_vivas_max, casillas_vivas())
		_vram_max = maxf(_vram_max, float(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)) / 1048576.0)
		_volcar_errores()
	_t_panel += delta
	if _panel.visible and _t_panel >= 0.25:
		_t_panel = 0.0
		_panel.text = texto_panel()


## --- Lo que se mide ---

func estadisticas_ms() -> Dictionary:
	var n: int = mini(_i, VENTANA)
	if n == 0:
		return {"media": 0.0, "p95": 0.0, "max": 0.0, "fps": 0.0}
	var v: Array = []
	var suma: float = 0.0
	for k in range(n):
		v.append(_ms[k])
		suma += _ms[k]
	v.sort()
	var media: float = suma / float(n)
	return {"media": media, "p95": float(v[mini(int(float(n) * 0.95), n - 1)]), "max": float(v[n - 1]),
		"fps": 1000.0 / maxf(media, 0.001)}


## Casillas que el sistema tiene "vivas": estado del suelo (hierba que cambia, pisadas), tierra, hielo y columnas.
func casillas_vivas() -> int:
	var n: int = 0
	if mundo != null:
		n += (mundo.get("_hf") as Dictionary).size() + (mundo.get("_pisadas") as Dictionary).size()
	if lanz != null:
		n += int(lanz.call("marcas_de_hielo")) + int(lanz.call("bloques_de_tierra"))
	return n


func manifestaciones_vivas() -> int:
	return int(lanz.get("manifestaciones_vivas")) if lanz != null else 0


func texto_panel() -> String:
	var e: Dictionary = estadisticas_ms()
	var l: String = "MEDICIÓN (F12)\n"
	l += "fotograma: %.1f ms media · %.1f p95 · %.1f peor (%d FPS)\n" % [e["media"], e["p95"], e["max"], int(e["fps"])]
	l += "dibujo: %d llamadas · %d k prim. · VRAM %d MB (máx %d)\n" % [
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0),
		int(float(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)) / 1048576.0), int(_vram_max)]
	l += "nodos %d · casillas vivas %d (máx %d) · manifestaciones vivas %d\n" % [
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), casillas_vivas(), _vivas_max,
		manifestaciones_vivas()]
	l += "gestos: %d reconocidos · %d rechazados · %d confundidos\n" % [
		gestos["reconocido"], gestos["rechazado"], gestos["confundido"]]
	l += "hechizos: %d · manifestaciones %d (máx %d en uno)\n" % [lanzamientos, manifestaciones_total,
		manifestaciones_max]
	l += "consola: %d errores · %d avisos" % [errores_total, avisos_total]
	if _captura != null:
		var vistos: Array = _captura.ultimos(MAX_ERRORES_VISTOS)
		for v in vistos:
			l += "\n  ! " + String(v).left(110)
	return l


func resumen() -> Dictionary:
	var e: Dictionary = estadisticas_ms()
	var gtot: int = int(gestos["reconocido"]) + int(gestos["rechazado"]) + int(gestos["confundido"])
	return {
		"ms_media": snappedf(float(e["media"]), 0.01), "ms_p95": snappedf(float(e["p95"]), 0.01),
		"ms_peor": snappedf(float(e["max"]), 0.01), "fps_medio": int(e["fps"]),
		"vram_max_mb": int(_vram_max), "casillas_vivas_max": _vivas_max,
		"gestos": gestos.duplicate(), "gestos_total": gtot,
		"tasa_reconocido": snappedf(float(gestos["reconocido"]) / float(maxi(gtot, 1)), 0.01),
		"hechizos": lanzamientos, "manifestaciones": manifestaciones_total,
		"manifestaciones_max": manifestaciones_max, "por_forma": por_forma.duplicate(),
		"por_elemento": por_elemento.duplicate(), "errores": errores_total, "avisos": avisos_total,
	}


## La línea que se pega en la tabla de DISENO_FUTURO.md §0.
func escribir_resumen() -> void:
	if _resumen_hecho:
		return
	_resumen_hecho = true
	_volcar_errores()
	PlayLog.event("resumen_3d", resumen())
	PlayLog.volcar()


## Lo que la consola dijo desde la última vez, al diario.
func _volcar_errores() -> void:
	if _captura == null:
		return
	for r in _captura.vaciar():
		var d: Dictionary = r
		if bool(d["error"]):
			errores_total += 1
		else:
			avisos_total += 1
		PlayLog.event("consola", {"tipo": "error" if bool(d["error"]) else "aviso", "texto": String(d["texto"]).left(200),
			"donde": String(d["donde"])})


## Captura los errores y avisos del motor y de los scripts (Logger, Godot 4.5+).
class Captura extends Logger:
	var _mutex := Mutex.new()
	var _nuevos: Array = []
	var _historial: Array = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array) -> void:
		var texto: String = rationale if rationale != "" else code
		var es_error: bool = error_type != Logger.ERROR_TYPE_WARNING
		_mutex.lock()
		var reg: Dictionary = {"error": es_error, "texto": texto, "donde": "%s:%d %s" % [file.get_file(), line, function]}
		_nuevos.append(reg)
		_historial.append("%s (%s:%d)" % [texto, file.get_file(), line])
		if _historial.size() > 40:
			_historial.pop_front()
		_mutex.unlock()

	func vaciar() -> Array:
		_mutex.lock()
		var r: Array = _nuevos
		_nuevos = []
		_mutex.unlock()
		return r

	func ultimos(n: int) -> Array:
		_mutex.lock()
		var r: Array = _historial.slice(maxi(0, _historial.size() - n))
		_mutex.unlock()
		return r
