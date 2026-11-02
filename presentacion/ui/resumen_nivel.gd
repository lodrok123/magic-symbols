class_name ResumenNivel
extends CanvasLayer

## EL RESUMEN DE NIVEL (2/11, gamefeel tercera tanda A4). Al cambiar de nivel (`Niveles._viaje`, antes del fundido de salida) sale una tarjeta centrada `T_RESUMEN` s con el nombre del nivel y las cifras
## de `Estadisticas.por_nivel` (tiempo, enemigos, cofres, oro, daño recibido). Entra con fundido y escala en `T_ENTRADA` s, suena `logro_pista` al aparecer y cualquier tecla (o clic) la quita.
## Cuelga de la RAÍZ (capa 101, sobre el fundido a negro) para sobrevivir al cambio de escena; no pausa nada y no se come la tecla que la salta. Si el nivel no registró nada
## (laboratorios) `mostrar` no hace nada y devuelve null. `Sensacion3D.ACTIVA = false`: aparece y desaparece de golpe (el sonido queda).
## Para las pruebas: `mostrar`, `saltar()`, `activo`, `filas()`, `visible_ahora()`, `segundos_vista`.

const NOMBRE: String = "ResumenNivel"

static var T_RESUMEN: float = 3.0              ## s que se queda (contados desde que aparece)
static var T_ENTRADA: float = 0.2              ## s de la entrada (fundido y escala)
static var T_SALIDA: float = 0.2               ## s de la salida
static var ESCALA_ENTRADA: float = 0.94
static var GRACIA_S: float = 0.25              ## los primeros s no se salta (la tecla que provocó el viaje no debe quitarla)
static var DB_SONIDO: float = INF              ## INF = el del catálogo

static var activo: ResumenNivel = null

var datos: Dictionary = {}
var segundos_vista: float = 0.0
var cerrandose: bool = false
var _panel: PanelContainer
var _centro: CenterContainer
var _filas: Array = []
var _tw: Tween = null


## Enseña la tarjeta. null (y nada en pantalla) si `datos` no tiene actividad o no hay árbol.
static func mostrar(arbol: SceneTree, nivel: String, p_datos: Dictionary) -> ResumenNivel:
	if arbol == null or not Estadisticas.hay_actividad(p_datos):
		return null
	if activo != null and is_instance_valid(activo):
		activo.free()
	var r := ResumenNivel.new()
	r.name = NOMBRE
	r.datos = p_datos
	r._construir(nivel)
	arbol.root.add_child(r)
	activo = r
	r._aparecer()
	return r


func _construir(nivel: String) -> void:
	layer = 101
	process_mode = Node.PROCESS_MODE_ALWAYS
	_centro = CenterContainer.new()
	_centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_centro.theme = TemaInterfaz.tema()
	add_child(_centro)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(400.0, 0.0)
	_centro.add_child(_panel)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)
	_panel.add_child(caja)
	var titulo := Label.new()
	titulo.text = nivel.replace("_", " ")
	titulo.add_theme_font_size_override("font_size", 26)
	titulo.add_theme_color_override("font_color", TemaInterfaz.BORDE_CALIDO)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(titulo)
	var sub := Label.new()
	sub.text = "Nivel dejado atrás"
	sub.add_theme_font_size_override("font_size", TemaInterfaz.TAM_FUENTE_PEQUENO)
	sub.add_theme_color_override("font_color", TemaInterfaz.TEXTO_SUAVE)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(sub)
	for f in filas():
		var h := HBoxContainer.new()
		var a := Label.new()
		a.text = String(f[0])
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(a)
		var b := Label.new()
		b.text = String(f[1])
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(b)
		caja.add_child(h)
	var pie := Label.new()
	pie.text = "[cualquier tecla] seguir"
	pie.add_theme_font_size_override("font_size", TemaInterfaz.TAM_FUENTE_PEQUENO)
	pie.add_theme_color_override("font_color", TemaInterfaz.TEXTO_SUAVE)
	pie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(pie)


## Las cifras que enseña: tiempo, enemigos, cofres, oro y daño recibido (las del documento), [[etiqueta, valor], …].
func filas() -> Array:
	return [
		["Tiempo", Estadisticas.texto_tiempo(float(datos.get("segundos", 0.0)))],
		["Enemigos vencidos", str(Estadisticas.total_enemigos(datos))],
		["Cofres abiertos", str(int(datos.get("cofres", 0)))],
		["Oro ganado", str(int(datos.get("oro_ganado", 0)))],
		["Daño recibido", str(int(round(float(datos.get("dano_recibido", 0.0)))))],
	]


func _aparecer() -> void:
	Sfx.play_ui("logro_pista", DB_SONIDO)
	if not Sensacion3D.ACTIVA:
		return
	_panel.pivot_offset = _panel.size * 0.5
	_panel.modulate.a = 0.0
	_panel.scale = Vector2.ONE * ESCALA_ENTRADA
	_tw = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	_tw.tween_property(_panel, "modulate:a", 1.0, T_ENTRADA)
	_tw.tween_property(_panel, "scale", Vector2.ONE, T_ENTRADA).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if cerrandose:
		return
	segundos_vista += delta
	if segundos_vista >= T_RESUMEN:
		saltar(true)


func _input(event: InputEvent) -> void:
	if cerrandose or segundos_vista < GRACIA_S:
		return
	var k := event as InputEventKey
	var m := event as InputEventMouseButton
	if (k != null and k.pressed and not k.echo) or (m != null and m.pressed):
		saltar()


## Quita la tarjeta (con fundido si la sensación está activa). `fin_de_tiempo` solo cambia a quién se le atribuye.
func saltar(_fin_de_tiempo: bool = false) -> void:
	if cerrandose:
		return
	cerrandose = true
	if _tw != null and _tw.is_valid():
		_tw.kill()
	if not Sensacion3D.ACTIVA or not is_inside_tree():
		_liberar()
		return
	_tw = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tw.tween_property(_panel, "modulate:a", 0.0, T_SALIDA)
	_tw.tween_callback(_liberar)


func _liberar() -> void:
	if activo == self:
		activo = null
	if is_inside_tree():
		queue_free()
	else:
		free()


func visible_ahora() -> bool:
	return is_inside_tree() and not cerrandose


func _exit_tree() -> void:
	if activo == self:
		activo = null
