class_name Logros3D
extends RefCounted
## RESPUESTA POSITIVA AL JUGADOR (PLAN_EOW_VISUAL §4, Juego, 21/10). Hasta hoy un puzle resuelto abría una puerta y nada más. La lógica (las piezas de `escenas/puzle.gd`)
## avisa de QUÉ ha logrado el jugador con un NOMBRE del catálogo cerrado `Mundo3D.LOGROS` (señal `Mundo3D.logro(nombre, punto, nodo)`); esta TABLA decide qué se ve y qué
## suena. Es el mismo patrón que las reacciones de A4 (`ReaccionesVfx3D`): el Juego no sabe qué partículas ni qué jingle sale, se cambia UNA fila sin tocar la lógica.
##
## PLANTILLA COMÚN. Todas las filas tienen los mismos campos (los de `CAMPOS`); un logro que no pone alguno usa el neutro (0, "" o false):
##   sfx      nombre de `Sfx.CATALOGO` (el jingle; "" = mudo)         sfx2   segundo sonido a la vez (p. ej. «puerta_abre»), "" = ninguno
##   motas    cuántas motas doradas saltan en el punto (0 = ninguna)   anillo radio (u) del aro de luz que se abre en el suelo (0 = ninguno)
##   luz      energía del fogonazo de luz (0 = ninguno)                color  tinte del aro y de la luz (las motas son siempre doradas: `VfxKit3D.oro_motas`)
##   texto    rótulo del HUD, arriba y centrado ("" = ninguno)         texto_dura  s que se queda el rótulo
##   hitstop  pausa de impacto en s (0 = ninguna; 0,06–0,10 es lo que pide el plan)
##   zoom     acercamiento de la cámara (fracción: 0,1 = 10 % más cerca; 0 = ninguno), que sube, se mantiene y vuelve
##
## HITSTOP: `Engine.time_scale` baja a ESCALA_HITSTOP durante `hitstop` s REALES (el temporizador ignora la escala del tiempo) y se RESTAURA al valor que tenía. Si llega otro
## mientras dura, se alarga sin perder el valor original. `restaurar_tiempo()` lo deja siempre como estaba (la prueba y quien salga de la escena lo pueden llamar).
## ZOOM: la cámara de la maqueta es ortogonal y se mueve sola cada fotograma; solo se anima su `size` (o el `fov` si fuera en perspectiva), sin tocar el código de la
## maqueta. Si el jugador cambia el zoom a mano justo durante el acercamiento, al terminar vuelve al valor de antes (son ~0,8 s).
## RADIAL (bloque 2 EoW, 23/10): fuerza 0..1 del desenfoque radial con aberración que sale del punto del logro (`PulsoPantalla3D`); 0 = nada.
##
## ENGANCHE: `Logros3D.conectar(mundo3d, padre_fx)` al montar el nivel, como `ReaccionesVfx3D.conectar`. Sin Mundo3D (o sin la señal) no hay nada que enganchar y devuelve false.
## Un nombre que no esté en la tabla no hace nada (ni error).

const CAMPOS: Array = ["sfx", "sfx2", "motas", "anillo", "luz", "color", "texto", "texto_dura", "hitstop", "zoom", "radial"]

# --- Ajustes (constantes a la vista, para afinar escuchando y viendo) ---
const ORO: Color = Color(1.0, 0.82, 0.35)
const CELESTE: Color = Color(0.55, 0.85, 1.0)
const BLANCO_CALIDO: Color = Color(1.0, 0.95, 0.8)
const ESCALA_HITSTOP: float = 0.02               ## time_scale durante la pausa de impacto (casi parado; 0 puede dar problemas al motor)
const VIDA_MOTAS: float = 1.1                    ## s que viven las motas doradas
const TAM_MOTAS: float = 0.16
const VEL_MOTAS: float = 3.2
const DURA_ANILLO: float = 0.8
const ALTO_ANILLO: float = 0.8                   ## u por debajo del punto (que llega 1 u sobre la base de la pieza): el aro se abre casi a ras de suelo
const DURA_LUZ: float = 0.55
const ALCANCE_LUZ: float = 4.5
const ZOOM_ENTRA: float = 0.25                   ## s del acercamiento
const ZOOM_MANTIENE: float = 0.25
const ZOOM_SALE: float = 0.5
const FUENTE_TEXTO: int = 34
const T_TEXTO_ENTRA: float = 0.2                 ## s del fundido de entrada del rótulo (el de salida es el último medio segundo)
const CAPA_TEXTO: int = 8

## LA TABLA: logro -> respuesta. Una fila por nombre de `Mundo3D.LOGROS` (la prueba lo exige).
const TABLA: Dictionary = {
	# Suave: un tono de «pista» y un pulso pequeño. Sin texto: no debe interrumpir.
	"paso_puzle":       {"sfx": "logro_pista", "motas": 5, "anillo": 0.9, "color": CELESTE},
	# Lo que más veces se verá: acierto claro pero breve.
	"puzle_resuelto":   {"sfx": "logro_acierto", "motas": 22, "anillo": 1.9, "luz": 1.6, "color": ORO, "texto": "¡Puzle resuelto!", "texto_dura": 2.2, "radial": 0.2},
	# Sala cerrada: pausa de impacto al caer el último enemigo y un pequeño acercamiento.
	"sala_limpia":      {"sfx": "logro_acierto", "motas": 18, "anillo": 2.8, "luz": 1.2, "color": BLANCO_CALIDO, "texto": "Sala despejada", "texto_dura": 2.2, "hitstop": 0.08, "zoom": 0.10, "radial": 0.5},
	"cofre_aparece":    {"sfx": "logro_brillo", "motas": 16, "anillo": 1.3, "luz": 1.2, "color": ORO},
	"cofre_abierto":    {"sfx": "logro_fanfarria", "motas": 36, "anillo": 2.3, "luz": 2.2, "color": ORO, "texto": "¡Cofre abierto!", "texto_dura": 2.4, "radial": 0.3},
	# Una puerta de sala que se abre: su sonido de siempre y un polvillo de luz; el texto lo da «sala_limpia», que ocurre en el mismo instante.
	"puerta_abierta":   {"sfx": "puerta_abre", "motas": 8, "anillo": 1.5, "color": BLANCO_CALIDO},
	# Lo emitirá el nivel (pedestal final); la fila ya está lista.
	"nivel_completado": {"sfx": "logro_fanfarria", "sfx2": "logro_acierto", "motas": 64, "anillo": 4.2, "luz": 3.0, "color": ORO, "texto": "¡Nivel completado!", "texto_dura": 3.5, "hitstop": 0.10, "zoom": 0.15, "radial": 0.8},
}

static var _fx: Node3D = null
static var _capa: CanvasLayer = null
static var _rotulo: Label = null
static var _tw_texto: Tween = null
static var _hitstop_activo: bool = false
static var _escala_previa: float = 1.0
static var _hitstop_id: int = 0
static var _zoom_tw: Tween = null
static var _zoom_cam: Camera3D = null
static var _zoom_base: float = 0.0
## Cuántas veces se ha ejecutado cada logro desde que arrancó el juego (para las pruebas y el HUD de los laboratorios).
static var total: Dictionary = {}


## La fila de un logro con los campos que falten rellenados con el neutro. {} si no está en la tabla.
static func resolver(nombre: String) -> Dictionary:
	if not TABLA.has(nombre):
		return {}
	var f: Dictionary = {"sfx": "", "sfx2": "", "motas": 0, "anillo": 0.0, "luz": 0.0, "color": ORO, "texto": "", "texto_dura": 2.0, "hitstop": 0.0, "zoom": 0.0, "radial": 0.0}
	f.merge(TABLA[nombre], true)
	return f


## Se engancha a `Mundo3D.logro(nombre, punto, nodo)` si existe. `padre_fx` = dónde cuelgan las partículas, la luz y el rótulo del HUD.
static func conectar(mundo: Object, padre_fx: Node3D) -> bool:
	if mundo == null or not mundo.has_signal("logro"):
		return false
	_fx = padre_fx
	var f := Callable(Logros3D, "_al_logro")
	if not mundo.is_connected("logro", f):
		mundo.connect("logro", f)
	return true


static func _al_logro(nombre: String, punto: Vector3, nodo: Node = null) -> void:
	reproducir(nombre, punto, nodo, _fx)


## Hace la respuesta: sonido, destello, rótulo, hitstop y zoom. Devuelve la fila resuelta más lo que se ha hecho de verdad
## (`hizo_texto`, `hizo_hitstop`, `hizo_zoom`, `hizo_sfx`, `hizo_vfx`); {} si el logro no está en la tabla.
static func reproducir(nombre: String, punto: Vector3, nodo: Node = null, padre_fx: Node3D = null) -> Dictionary:
	var fila: Dictionary = resolver(nombre)
	if fila.is_empty():
		return {}
	total[nombre] = int(total.get(nombre, 0)) + 1
	var padre: Node3D = padre_fx
	if padre == null or not is_instance_valid(padre) or not padre.is_inside_tree():
		padre = (nodo.get_parent() as Node3D) if nodo != null and is_instance_valid(nodo) and nodo.get_parent() is Node3D else (nodo as Node3D)
	fila["hizo_sfx"] = false
	fila["hizo_vfx"] = false
	fila["hizo_texto"] = false
	fila["hizo_hitstop"] = false
	fila["hizo_zoom"] = false
	fila["hizo_radial"] = false
	if padre == null or not is_instance_valid(padre) or not padre.is_inside_tree():
		return fila                                                     # sin árbol no hay dónde sonar ni dibujar: se devuelve la fila y ya
	var color: Color = fila["color"]
	var origen: Node = nodo if nodo is Node3D and is_instance_valid(nodo) and nodo.is_inside_tree() else padre
	for clave in ["sfx", "sfx2"]:
		if String(fila[clave]) != "":
			Sfx.play(origen, String(fila[clave]))
			fila["hizo_sfx"] = true
	if int(fila["motas"]) > 0:
		VfxKit3D.oro_motas(padre, punto, int(fila["motas"]), VIDA_MOTAS, TAM_MOTAS, VEL_MOTAS, false, false, 0.25, Vector3.UP, 70.0)
		fila["hizo_vfx"] = true
	if float(fila["anillo"]) > 0.0:
		_anillo(padre, punto - Vector3(0.0, ALTO_ANILLO, 0.0), float(fila["anillo"]), DURA_ANILLO, color)
		fila["hizo_vfx"] = true
	if float(fila["luz"]) > 0.0:
		_luz(padre, punto, float(fila["luz"]), color)
		fila["hizo_vfx"] = true
	var arbol: SceneTree = padre.get_tree()
	if String(fila["texto"]) != "":
		_texto(padre, String(fila["texto"]), color, float(fila["texto_dura"]))
		fila["hizo_texto"] = true
	if float(fila["hitstop"]) > 0.0:
		hitstop(arbol, float(fila["hitstop"]))
		fila["hizo_hitstop"] = true
	if float(fila["zoom"]) > 0.0:
		fila["hizo_zoom"] = zoom(arbol, float(fila["zoom"]))
	if float(fila["radial"]) > 0.0:
		PulsoPantalla3D.lanzar_en(arbol, punto, float(fila["radial"]))       # bloque 2 EoW: desenfoque radial desde el punto del logro
		fila["hizo_radial"] = true
	return fila


# ---------------------------------------------------------------------------------------------------------------------
#  Piezas de la respuesta
# ---------------------------------------------------------------------------------------------------------------------

## Aro de luz plano que se abre y se desvanece (textura de aro de `VfxKit3D`, aditiva y algo por encima de 1 para que el bloom la recoja).
static func _anillo(padre: Node3D, pos: Vector3, radio: float, dura: float, color: Color) -> void:
	var q := QuadMesh.new()
	q.size = Vector2(2.0, 2.0)
	q.orientation = PlaneMesh.FACE_Y
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	sm.albedo_texture = VfxKit3D.aro()
	sm.albedo_color = Color(color.r * 1.5, color.g * 1.5, color.b * 1.5, 1.0)
	q.material = sm
	var m := MeshInstance3D.new()
	m.mesh = q
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = pos
	m.scale = Vector3.ONE * radio * 0.15
	padre.add_child(m)
	var tw: Tween = m.create_tween()
	tw.tween_property(m, "scale", Vector3.ONE * radio, dura).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(sm, "albedo_color:a", 0.0, dura)
	tw.tween_callback(m.queue_free)


## Fogonazo de luz que se apaga solo.
static func _luz(padre: Node3D, pos: Vector3, energia: float, color: Color) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energia
	l.omni_range = ALCANCE_LUZ
	l.shadow_enabled = false
	l.position = pos
	padre.add_child(l)
	var tw: Tween = l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, DURA_LUZ)
	tw.tween_callback(l.queue_free)


## Rótulo del HUD (arriba y centrado). Uno solo a la vez: el nuevo sustituye al anterior. Cuelga de una CanvasLayer propia, hija de `padre`.
static func _texto(padre: Node3D, texto: String, color: Color, dura: float) -> void:
	if _capa == null or not is_instance_valid(_capa) or not _capa.is_inside_tree():
		_capa = CanvasLayer.new()
		_capa.layer = CAPA_TEXTO
		_capa.name = "LogrosHud"
		padre.add_child(_capa)
		_rotulo = Label.new()
		_rotulo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		_rotulo.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_rotulo.offset_top = 70.0
		_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rotulo.add_theme_font_size_override("font_size", FUENTE_TEXTO)
		_rotulo.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.0))
		_rotulo.add_theme_constant_override("outline_size", 10)
		_capa.add_child(_rotulo)
	if _tw_texto != null and _tw_texto.is_valid():
		_tw_texto.kill()
	_rotulo.text = texto
	_rotulo.add_theme_color_override("font_color", color.lightened(0.25))
	_rotulo.modulate = Color(1, 1, 1, 0)
	_tw_texto = _rotulo.create_tween().set_ignore_time_scale(true)            # el hitstop no debe congelar el fundido
	_tw_texto.tween_property(_rotulo, "modulate:a", 1.0, T_TEXTO_ENTRA)
	_tw_texto.tween_interval(maxf(dura - T_TEXTO_ENTRA - 0.5, 0.0))
	_tw_texto.tween_property(_rotulo, "modulate:a", 0.0, 0.5)


## El texto que se muestra ahora (vacío si no hay rótulo o está apagado). Para las pruebas.
static func texto_visible() -> String:
	if _rotulo == null or not is_instance_valid(_rotulo) or _rotulo.modulate.a <= 0.01:
		return ""
	return _rotulo.text


## PAUSA DE IMPACTO: baja `Engine.time_scale` a ESCALA_HITSTOP durante `dur` s reales y lo restaura. Alargable; ver la cabecera.
static func hitstop(arbol: SceneTree, dur: float) -> void:
	if arbol == null or dur <= 0.0:
		return
	if not _hitstop_activo:
		_escala_previa = Engine.time_scale
		_hitstop_activo = true
	Engine.time_scale = ESCALA_HITSTOP
	_hitstop_id += 1
	# create_timer(tiempo, procesar_en_pausa, procesar_en_fisica, ignorar_escala_del_tiempo): la escala casi 0 no debe alargar la propia pausa.
	arbol.create_timer(dur, true, false, true).timeout.connect(_fin_hitstop.bind(_hitstop_id))


static func _fin_hitstop(id: int) -> void:
	if id == _hitstop_id:                                       # un hitstop posterior alarga el anterior: solo el último temporizador restaura
		restaurar_tiempo()


## Deja `Engine.time_scale` como estaba antes del hitstop (idempotente).
static func restaurar_tiempo() -> void:
	if _hitstop_activo:
		Engine.time_scale = _escala_previa
		_hitstop_activo = false
	_hitstop_id += 1                                            # y anula los temporizadores pendientes


static func hitstop_activo() -> bool:
	return _hitstop_activo


## Acercamiento de la cámara: `cantidad` = fracción (0,1 = 10 % más cerca). Sube, se mantiene y vuelve. false si no hay cámara.
static func zoom(arbol: SceneTree, cantidad: float) -> bool:
	if arbol == null or arbol.root == null:
		return false
	var cam: Camera3D = arbol.root.get_camera_3d()
	if cam == null:
		return false
	var prop: String = "size" if cam.projection == Camera3D.PROJECTION_ORTHOGONAL else "fov"
	if _zoom_tw != null and _zoom_tw.is_valid() and _zoom_cam == cam:
		_zoom_tw.kill()                                         # ya había uno en marcha: se conserva el valor ORIGINAL, no el acercado
	else:
		_zoom_base = float(cam.get(prop))
	_zoom_cam = cam
	_zoom_tw = cam.create_tween().set_ignore_time_scale(true)
	_zoom_tw.tween_property(cam, prop, _zoom_base * (1.0 - cantidad), ZOOM_ENTRA).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_zoom_tw.tween_interval(ZOOM_MANTIENE)
	_zoom_tw.tween_property(cam, prop, _zoom_base, ZOOM_SALE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return true
