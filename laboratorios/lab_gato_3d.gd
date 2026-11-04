extends Node3D

## LABORATORIO DEL RIG DEL GATO (11/10, Pablo: «un entorno para ajustar el rig del gato, no uses nivelbosque»).
## Una escena vacía con SOLO el gato en bucle de animación y un panel para tocar el esqueleto en vivo:
##  · Elegir clip (walk / idle) y velocidad; pausar y arrastrar el fotograma.
##  · Tres grupos de huesos con su propio «factor de zancada»: 1 = el clip tal cual lo exportó Meshy, 0 = la postura media del ciclo
##    (sin movimiento). Es la misma cuenta que hace `Pj3D._acortar_paso()` (cada hueso gira solo `factor` de lo que se aleja de su
##    postura media), pero con un factor distinto para delanteras, traseras y «resto» (columna, cola, cabeza).
##  · Elegir cualquier hueso de la lista y sumarle un giro fijo (X/Y/Z en grados) a todo el clip: sirve para subir una pata,
##    bajar la cola o enderezar la cabeza sin tocar el modelo.
##  · Ver el esqueleto dibujado encima (azul = delanteras, verde = traseras, blanco = resto, amarillo = hueso elegido).
## El panel escribe abajo los números resultantes. No modifica ningún archivo: pégaselos a Claude (o a `PASO_CORTO` de pj_3d.gd).
##
## 13/10: también sirve para el LOBERNO (selector «Modelo» arriba, o tecla M). Con el lobo todo empieza neutro (factores 1, sin vaivén ni
## retraso de cola): se ven sus clips tal cual los exportó Meshy, y los mismos controles sirven para afinarlo si hace falta.
## 
## Teclas: M loberno/lince/canouro · 1 lateral · 2 frente · 3 desde arriba · 4 3/4 · Espacio pausa · S esqueleto · H humo negro en las patas (canouro) · Z zarpazo (clip + garras) · rueda = zoom · arrastrar = orbitar
## Abrir: laboratorios/LabGato3D.tscn y F6 (no necesita el nivel del bosque).
##
## 4/11 · MODO MARCHA (encargo de Pablo: «ponlos en el laboratorio gato»). Enseña la marcha nueva de los animales (presentacion/marcha_cuadrupedo_3d.gd,
## MarchaCuadrupedo3D) con el loberno (lobo) y el canouro (hiena) MOVIÉNDOSE de verdad sobre un suelo plano grande, enganchada igual que en el juego
## (`Combate3D`: patrullar, perseguir, atacar, `conducta`, `paso_suave`, `actualizar`, `animar_andar`, `al_atacar`). El lince no tiene perfil: sigue como antes.
## Teclas del modo marcha: N entra/sale (o el botón del panel) · P patrulla (ida y vuelta entre dos puntos) · C persigue a la presa · Q parado ·
##   B alterna MarchaCuadrupedo3D.MARCHA_ANIMAL en vivo (antes = clip walk/run sin capa y giro en seco; después = la marcha) · M cambia de animal ·
##   1-4 cámaras (siguen al animal) · S, H, Z como siempre · clic izquierdo o arrastrar = mueve la PRESA por el suelo · botón derecho arrastrar = orbitar · rueda = zoom.
## En pantalla: modelo, MARCHA sí/no, modo y estado de conducta, clip y su velocidad, velocidad real u/s, pendiente del lomo y giro de la cabeza.

## 17/10 (encargo del Juego): solo quedan los tres enemigos en uso. El gato, el loberno v1/meshy y el lince_gato se quitaron con sus GLB.
## Con el gato fuera, todos los modelos usan PERFIL_LOBERNO (`_cambiar_modelo` lo aplica a todo id distinto de «gato»); el canouro viene retargeteado al rig del lobo.
const MODELOS: Dictionary = {"loberno": "res://arte/modelos/emberheart.glb",
	"lince": "res://arte/modelos/lince.glb",
	"canouro": "res://arte/modelos/canouro.glb"}
const ALTO: float = 1.0            ## el gato se escala a esta altura (en el nivel mide 0,55; aquí más grande para verlo bien)
const DELANTERAS: Array = ["Bone_030", "Bone_029", "Bone_028", "Bone_027", "Bone_035", "Bone_034", "Bone_033", "Bone_032"]
const TRASERAS: Array = ["Bone_009", "Bone_008", "Bone_007", "Bone_006", "Bone_014", "Bone_013", "Bone_012", "Bone_011"]
const COLOR_DEL: Color = Color(0.35, 0.65, 1.0)
const COLOR_TRAS: Color = Color(0.35, 1.0, 0.45)
const COLOR_RESTO: Color = Color(0.95, 0.95, 0.95)
const COLOR_SEL: Color = Color(1.0, 0.85, 0.1)

var _modelo: Node3D = null
var _sk: Skeleton3D = null
var _ap: AnimationPlayer = null
var _cam: Camera3D = null
var _lineas: MeshInstance3D = null
var _im: ImmediateMesh = null

var _yaw: float = 0.0
var _pitch: float = 0.15
var _dist: float = 2.6
var _foco: Vector3 = Vector3(0.0, 0.45, 0.0)

var _clip: String = ""
var _orig: Dictionary = {}          ## «modelo/clip» -> {pista(int): Array[Quaternion]} con las claves ORIGINALES del GLB (nunca se pierden)
## 11/10: arranca con los valores que Pablo dejó en el juego (Pj3D.PASO_CORTO y VEL_CLIP_PJ).
const FACTOR_INICIAL: Dictionary = {"del": 0.30, "tras": 0.14, "resto": 0.50}
const VEL_INICIAL: float = 0.27
var _factor: Dictionary = FACTOR_INICIAL.duplicate()
## Factor propio de algunos huesos (pisa al del grupo). Por defecto las articulaciones de las patas (codo/rodilla, corvejón y muñeca):
## con el factor tan bajo de las patas se quedaban rígidas; así doblan un poco al andar. Mismo valor que Pj3D.PASO_CORTO.
## Cuello (Bone_025) y cabeza (Bone_024) a 0,25: el tutorial de Rusty Animator pide la cabeza estable mientras el cuerpo se mueve.
const RODILLAS: Dictionary = {"Bone_029": 0.35, "Bone_034": 0.35, "Bone_028": 0.35, "Bone_033": 0.35,
	"Bone_008": 0.35, "Bone_013": 0.35, "Bone_007": 0.35, "Bone_012": 0.35, "Bone_025": 0.25, "Bone_024": 0.25}
var _fh: Dictionary = RODILLAS.duplicate()
## Cola de la base a la punta. Cada hueso va `_retraso_cola` (fracción del ciclo) más tarde que el anterior: el «overlap» del tutorial
## (cada controlador de la cola 1 fotograma más tarde; en su ciclo de 32 fotogramas eso es 1/32 ≈ 0,03 del ciclo).
const COLA: Array = ["Bone_023", "Bone_022", "Bone_021", "Bone_020", "Bone_019", "Bone_018", "Bone_017", "Bone_016", "Bone_015"]
const RETRASO_INICIAL: float = 0.03
var _retraso_cola: float = RETRASO_INICIAL
## Perfil de cada modelo: qué huesos son delanteros/traseros/cola y con qué valores arranca. El gato usa las constantes de arriba; el
## loberno (huesos con nombre: FrontUpperLeg.L...) arranca sin tocar nada.
const PERFIL_LOBERNO: Dictionary = {
	"del": ["FrontShoulder.L", "FrontUpperLeg.L", "FrontLowerLeg.L", "FrontShoulder.R", "FrontUpperLeg.R", "FrontLowerLeg.R",
		"IKFrontLeg.L", "FF.L", "IKFrontLeg.R", "FF.R"],
	"tras": ["BackShoulder.L", "BackLeg.L", "BackUpperLeg.L", "BackLowerLeg.L", "BackShoulder.R", "BackLeg.R", "BackUpperLeg.R",
		"BackLowerLeg.R", "IKBackLeg.L", "FFB.L", "IKBackLeg.R", "FFB.R"],
	"cola": ["Tail1", "Tail2", "Tail3", "Tail4", "Tail5", "Tail6", "Tail7", "Tail8"],
	"factor": {"del": 1.0, "tras": 1.0, "resto": 1.0}, "vel": 1.0, "dist": 3.4, "clip": "Walk",
}
var _humo: Node3D = null         ## humo negro de las patas del canouro (VfxCanouro3D); cuelga de `_modelo`, así que se libera con él
var _id: String = ""            ## vacío hasta que `_ready` llama a `_cambiar_modelo` (es quien aplica el perfil del modelo)
var _del: Array = DELANTERAS
var _tras: Array = TRASERAS
var _cola: Array = COLA
var _extra_del: Array = ["Bone_026", "Bone_031"]
var _extra_tras: Array = ["Bone_005", "Bone_010"]
var _factor0: Dictionary = FACTOR_INICIAL
var _fh0: Dictionary = RODILLAS
var _vaiven0: Dictionary = VAIVEN_INICIAL
var _retraso0: float = RETRASO_INICIAL
var _vel0: float = VEL_INICIAL
var _capa: CanvasLayer = null
var _sl_retraso: HSlider = null
var _sl_fh: HSlider = null
## Vaivén: giro X extra (grados) que va y viene una vez por ciclo, sumado al clip. Pablo (11/10): «más exagerado el movimiento de la
## rodilla, que haya un vaivén en el hueso 28 y 32». La fase de cada pata es el momento en que su pie está más alto (medido en el clip
## walk: pata 030-026 y trasera 014-010 a 0,25 del ciclo; pata 035-031 y trasera 009-005 a 0,72), así la articulación se dobla más
## justo cuando la pata va por el aire. Amplitud negativa = dobla hacia el otro lado.
## 11/10, vídeos de referencia (gato realista, con y sin huesos): al levantar la pata delantera la muñeca se dobla mucho (la mano casi
## se pliega), el codo algo, y el corvejón trasero también. Comparando con su esqueleto, en el nuestro el codo es 028/033 (a la altura
## del pecho) y la muñeca 027/032 (casi en el suelo); ver ANATOMIA.
const VAIVEN_INICIAL: Dictionary = {"Bone_027": 35.0, "Bone_032": 35.0, "Bone_028": 15.0, "Bone_033": 15.0,
	"Bone_007": 25.0, "Bone_012": 25.0}
## Qué es cada hueso, por su altura y su cadena (medido en el esqueleto en reposo, gato de 1,0 de alto). La articulación de un hueso
## está en su origen: girar Bone_028 dobla el codo. Las dos patas de cada par son las dos cadenas; no indico lado.
const ANATOMIA: Dictionary = {
	"Bone_030": "hombro", "Bone_035": "hombro", "Bone_029": "brazo", "Bone_034": "brazo", "Bone_028": "codo", "Bone_033": "codo",
	"Bone_027": "muñeca", "Bone_032": "muñeca", "Bone_026": "dedos", "Bone_031": "dedos",
	"Bone_009": "cadera", "Bone_014": "cadera", "Bone_008": "rodilla", "Bone_013": "rodilla", "Bone_007": "corvejón",
	"Bone_012": "corvejón", "Bone_006": "pie", "Bone_011": "pie", "Bone_005": "dedos", "Bone_010": "dedos",
	"Bone_000": "raíz", "Bone_001": "pelvis", "Bone_004": "columna", "Bone_003": "columna", "Bone_002": "pecho",
	"Bone_025": "cuello", "Bone_024": "cabeza", "Bone_023": "cola 1 (base)", "Bone_022": "cola 2", "Bone_021": "cola 3",
	"Bone_020": "cola 4", "Bone_019": "cola 5", "Bone_018": "cola 6", "Bone_017": "cola 7", "Bone_016": "cola 8", "Bone_015": "cola 9 (punta)"}
const FASE_PATA: Dictionary = {"Bone_030": 0.25, "Bone_029": 0.25, "Bone_028": 0.25, "Bone_027": 0.25,
	"Bone_014": 0.25, "Bone_013": 0.25, "Bone_012": 0.25, "Bone_011": 0.25,
	"Bone_035": 0.72, "Bone_034": 0.72, "Bone_033": 0.72, "Bone_032": 0.72,
	"Bone_009": 0.72, "Bone_008": 0.72, "Bone_007": 0.72, "Bone_006": 0.72}
## Eje del vaivén (en el espacio del hueso padre, como «giro X/Y/Z»), elegido para que un valor POSITIVO DOBLE la articulación.
## Medido sumando +30° en cada eje y viendo cuánto se abre el ángulo de la articulación (11/10): las dos patas de cada par tienen los
## ejes en espejo y algunas mezclan X y Z, por eso no basta con «X». Un hueso que no esté aquí usa X.
const EJE_FLEX: Dictionary = {
	"Bone_028": Vector3(-29.1, 0.0, 9.1), "Bone_033": Vector3(-17.5, 0.0, 21.1), "Bone_032": Vector3(-2.4, 0.0, 28.4),
	"Bone_007": Vector3(-28.9, 0.0, 9.0), "Bone_012": Vector3(-29.6, 0.0, 3.1),
	"Bone_008": Vector3(25.1, 0.0, -13.8), "Bone_013": Vector3(28.9, 0.0, -0.9),
	"Bone_027": Vector3(-24.2, 0.0, 17.1), "Bone_006": Vector3(-16.0, 0.0, 23.5), "Bone_011": Vector3(-29.5, 0.0, -2.8)}
var _vaiven: Dictionary = VAIVEN_INICIAL.duplicate()
var _sl_vaiven: HSlider = null
var _giro: Dictionary = {}          ## hueso -> Vector3 (grados) sumado a todo el clip
var _sel: String = ""

# Modo marcha (4/11)
const MARCHA_SUELO: float = 60.0               ## lado del suelo plano del modo marcha (u)
const MARCHA_ALTO: Dictionary = {"loberno": 0.75, "canouro": 0.55}   ## alto de juego de cada animal (el de ALTO_PJ / prueba_test2)
const MARCHA_PATRULLA: float = 4.0             ## la patrulla va de casa-4 a casa+4 en X (en el juego son 2; aquí más para verla)
const MARCHA_DIST: float = 5.5                ## distancia de cámara en el modo marcha
var _marcha_on: bool = false                   ## N: modo marcha pedido (solo se ve si el modelo tiene perfil)
var _mpj: Pj3D = null                          ## el animal del modo marcha (un Pj3D de verdad, como en el juego)
var _mm: MarchaCuadrupedo3D = null             ## su capa de marcha
var _m_modo: String = "quieto"                 ## quieto | patrulla | persigue
var _presa_pos: Vector3 = Vector3(4.0, 0.0, 0.0)
var _presa: Node3D = null
var _suelo_chico: MeshInstance3D = null
var _suelo_marcha: MeshInstance3D = null
var _capa_marcha: CanvasLayer = null
var _rotulo: Label = null
var _btn_marcha: Button = null
var _m_casa: Vector3 = Vector3.ZERO
var _m_dir: float = 1.0
var _m_mirada: Vector3 = Vector3.RIGHT
var _m_v_avance: float = 0.0
var _m_clip_modo: String = ""
var _m_ataque: float = 0.0
var _m_carga: float = 0.0
var _m_descanso: float = 0.0
var _m_en_rango: bool = false
var _m_v_real: float = 0.0
var _m_moviendo: int = 0
var _dist_rig: float = 3.4

# Interfaz
var _lista: ItemList = null
var _sl_giro: Array[HSlider] = []
var _lbl_giro: Array[Label] = []
var _sl_fact: Dictionary = {}
var _lbl_fact: Dictionary = {}
var _sl_vel: HSlider = null
var _sl_tiempo: HSlider = null
var _chk_esq: CheckBox = null
var _chk_pausa: CheckBox = null
var _txt: TextEdit = null
var _opt_clip: OptionButton = null
var _ocupado: bool = false         ## evita bucles al poner valores a los sliders por código


func _ready() -> void:
	_montar_escena()
	# Sin modelo «por defecto»: el estado inicial (_del, _tras, _cola, factores) es el del gato y ya no hay gato. `_cambiar_modelo` aplica el
	# perfil del lobo, carga el GLB, monta la interfaz, elige el clip y coloca la cámara y el texto.
	_cambiar_modelo("canouro")


## El clip con el que arranca cada modelo (el gato anda en «walk», el lobo en «Walk»; si no existe, el primero).
func _clip_inicial() -> String:
	for n in _ap.get_animation_list():
		if String(n).to_lower() == "walk":
			return String(n)
	return String(_ap.get_animation_list()[0])


## Cambia de modelo sin recargar la escena: quita el actual y el panel, carga el otro con su perfil y vuelve a montar la interfaz.
## Los clips del recurso importado se tocan en memoria, así que `_orig` (clave modelo/clip) guarda las claves originales de cada uno.
func _cambiar_modelo(id: String) -> void:
	if id == _id or not MODELOS.has(id):
		return
	_id = id
	if _modelo != null:
		_modelo.queue_free()
		_modelo = null
		_humo = null
	if _capa != null:
		_capa.queue_free()
		_capa = null
	_giro.clear()
	_sel = ""
	_clip = ""
	if id != "gato":          # loberno y loberno_meshy comparten esqueleto (51 huesos «Wolf»)
		var p: Dictionary = PERFIL_LOBERNO
		_del = p["del"]
		_tras = p["tras"]
		_cola = p["cola"]
		_extra_del = []
		_extra_tras = []
		_factor0 = p["factor"]
		_fh0 = {}
		_vaiven0 = {}
		_retraso0 = 0.0
		_vel0 = float(p["vel"])
		_dist = float(p["dist"])
	else:
		_del = DELANTERAS
		_tras = TRASERAS
		_cola = COLA
		_extra_del = ["Bone_026", "Bone_031"]
		_extra_tras = ["Bone_005", "Bone_010"]
		_factor0 = FACTOR_INICIAL
		_fh0 = RODILLAS
		_vaiven0 = VAIVEN_INICIAL
		_retraso0 = RETRASO_INICIAL
		_vel0 = VEL_INICIAL
		_dist = 2.6
	_factor = _factor0.duplicate()
	_fh = _fh0.duplicate()
	_vaiven = _vaiven0.duplicate()
	_retraso_cola = _retraso0
	if not _cargar_gato():
		return
	_montar_interfaz()
	_elegir_clip(_clip_inicial())
	_camara_preset(0)
	_refrescar_texto()
	_aplicar_modo_marcha()


func _montar_escena() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.22, 0.26)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sol.light_energy = 1.1
	add_child(sol)
	# Suelo con cuadrícula de 0,25 para medir cuánto se adelanta cada pata.
	var suelo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8.0, 8.0)
	suelo.mesh = pm
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode unshaded;\nvoid fragment(){\n\tvec2 p = (UV - 0.5) * 8.0;\n\tvec2 g = abs(fract(p * 4.0 - 0.5) - 0.5) / fwidth(p * 4.0);\n\tfloat l = 1.0 - min(min(g.x, g.y), 1.0);\n\tfloat eje = step(abs(p.x), 0.004) + step(abs(p.y), 0.004);\n\tALBEDO = mix(vec3(0.16, 0.18, 0.21), vec3(0.32, 0.35, 0.4), l);\n\tALBEDO = mix(ALBEDO, vec3(0.8, 0.3, 0.3), clamp(eje, 0.0, 1.0) * 0.6);\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	suelo.material_override = mat
	add_child(suelo)
	_suelo_chico = suelo
	_montar_escena_marcha()
	_cam = Camera3D.new()
	_cam.fov = 35.0
	_cam.h_offset = -0.55       # desplaza la vista a la derecha para que el panel no tape al gato
	add_child(_cam)
	_im = ImmediateMesh.new()
	_lineas = MeshInstance3D.new()
	_lineas.mesh = _im
	var ml := StandardMaterial3D.new()
	ml.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ml.vertex_color_use_as_albedo = true
	ml.no_depth_test = true
	ml.render_priority = 10
	_lineas.material_override = ml
	_lineas.top_level = true
	add_child(_lineas)


func _cargar_gato() -> bool:
	var glb: String = String(MODELOS[_id])
	if not ResourceLoader.exists(glb):
		push_warning("LabGato3D: falta " + glb)
		return false
	_modelo = (load(glb) as PackedScene).instantiate() as Node3D
	add_child(_modelo)
	var sks: Array[Node] = _modelo.find_children("*", "Skeleton3D", true, false)
	var aps: Array[Node] = _modelo.find_children("*", "AnimationPlayer", true, false)
	if sks.is_empty() or aps.is_empty():
		push_warning("LabGato3D: el GLB no trae esqueleto o animaciones")
		return false
	_sk = sks[0] as Skeleton3D
	_ap = aps[0] as AnimationPlayer
	for n in _ap.get_animation_list():
		_ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	# Escala a ALTO y apoya los pies en y = 0, midiendo con la malla (igual que Pj3D._apoyar_en_el_suelo).
	var caja := AABB()
	var primera: bool = true
	for m in _modelo.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m as MeshInstance3D
		var a: AABB = (_modelo.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		caja = a if primera else caja.merge(a)
		primera = false
	if not primera and caja.size.y > 0.0001:
		var k: float = ALTO / caja.size.y
		_modelo.scale = Vector3.ONE * k
		_modelo.position = Vector3(-(caja.position.x + caja.size.x * 0.5) * k, -caja.position.y * k, -(caja.position.z + caja.size.z * 0.5) * k)
	return true


func _montar_interfaz() -> void:
	_sl_giro.clear()
	_lbl_giro.clear()
	_sl_fact.clear()
	_lbl_fact.clear()
	var capa := CanvasLayer.new()
	_capa = capa
	add_child(capa)
	var panel := PanelContainer.new()
	panel.position = Vector2(8.0, 8.0)
	panel.custom_minimum_size = Vector2(330.0, 0.0)
	capa.add_child(panel)
	var caja := VBoxContainer.new()
	panel.add_child(caja)

	var t := Label.new()
	t.text = "RIG DEL %s (no modifica archivos)" % _id.to_upper()
	caja.add_child(t)
	var b_marcha := Button.new()
	b_marcha.text = "Modo marcha (N): el animal anda de verdad"
	b_marcha.pressed.connect(_alternar_modo_marcha)
	caja.add_child(b_marcha)
	var opt_modelo := OptionButton.new()
	var i_modelo: int = 0
	for k in MODELOS.keys():
		opt_modelo.add_item(String(k))
		if String(k) == _id:
			opt_modelo.select(i_modelo)
		i_modelo += 1
	opt_modelo.item_selected.connect(func(i: int) -> void: _cambiar_modelo(opt_modelo.get_item_text(i)))
	caja.add_child(opt_modelo)

	_opt_clip = OptionButton.new()
	for n in _ap.get_animation_list():
		_opt_clip.add_item(String(n))
	_opt_clip.item_selected.connect(func(i: int) -> void: _elegir_clip(_opt_clip.get_item_text(i)))
	caja.add_child(_opt_clip)

	_sl_vel = _slider(caja, "velocidad", 0.0, 2.0, _vel0, "")
	_sl_vel.value_changed.connect(func(v: float) -> void:
		if not _ocupado:
			_ap.speed_scale = v
		_poner_etiqueta("vel", v))
	_sl_tiempo = _slider(caja, "fotograma", 0.0, 1.0, 0.0, "t")
	_sl_tiempo.value_changed.connect(func(v: float) -> void:
		if _ocupado or _ap.current_animation == "":
			return
		_chk_pausa.button_pressed = true
		_ap.seek(v * _ap.current_animation_length, true)
		_poner_etiqueta("t", v))

	_chk_pausa = CheckBox.new()
	_chk_pausa.text = "Pausa (Espacio)"
	_chk_pausa.toggled.connect(func(p: bool) -> void: _ap.speed_scale = 0.0 if p else _sl_vel.value)
	caja.add_child(_chk_pausa)
	_chk_esq = CheckBox.new()
	_chk_esq.text = "Ver esqueleto (S)"
	_chk_esq.button_pressed = true
	caja.add_child(_chk_esq)

	caja.add_child(_titulo("Factor de zancada (1 = clip original, 0 = quieto)"))
	for g in [["del", "delanteras"], ["tras", "traseras"], ["resto", "resto del cuerpo"]]:
		var clave: String = g[0]
		var s: HSlider = _slider(caja, g[1], 0.0, 1.5, float(_factor[clave]), clave)
		_sl_fact[clave] = s
		s.value_changed.connect(func(v: float) -> void:
			_factor[clave] = v
			_poner_etiqueta(clave, v)
			if not _ocupado:
				_aplicar()
				_refrescar_texto())
	_sl_retraso = _slider(caja, "retraso cola", 0.0, 0.08, _retraso_cola, "rc")
	_sl_retraso.step = 0.005
	_sl_retraso.value_changed.connect(func(v: float) -> void:
		_retraso_cola = v
		_poner_etiqueta("rc", v)
		if not _ocupado:
			_aplicar()
			_refrescar_texto())

	caja.add_child(_titulo("Hueso (clic en la lista) + giro fijo en grados"))
	_lista = ItemList.new()
	_lista.custom_minimum_size = Vector2(0.0, 110.0)
	for b in range(_sk.get_bone_count()):
		var nombre: String = _sk.get_bone_name(b)
		var etiqueta: String = nombre
		if _del.has(nombre) or _extra_del.has(nombre):
			etiqueta += "  delantera · " + String(ANATOMIA.get(nombre, ""))
		elif _tras.has(nombre) or _extra_tras.has(nombre):
			etiqueta += "  trasera · " + String(ANATOMIA.get(nombre, ""))
		elif ANATOMIA.has(nombre):
			etiqueta += "  " + String(ANATOMIA[nombre])
		_lista.add_item(etiqueta)
		_lista.set_item_metadata(b, nombre)
	_lista.item_selected.connect(func(i: int) -> void: _elegir_hueso(String(_lista.get_item_metadata(i))))
	caja.add_child(_lista)
	_sl_vaiven = _slider(caja, "vaivén (°, + dobla)", -60.0, 60.0, 0.0, "vv")
	_sl_vaiven.step = 1.0
	_sl_vaiven.value_changed.connect(func(v: float) -> void:
		_poner_etiqueta("vv", v)
		if _ocupado or _sel == "":
			return
		if is_zero_approx(v):
			_vaiven.erase(_sel)
		else:
			_vaiven[_sel] = v
		_aplicar()
		_refrescar_texto())
	_sl_fh = _slider(caja, "factor hueso", 0.0, 1.5, 1.0, "fh")
	_sl_fh.value_changed.connect(func(v: float) -> void:
		_poner_etiqueta("fh", v)
		if _ocupado or _sel == "":
			return
		_fh[_sel] = v
		_aplicar()
		_refrescar_texto())
	for i in range(3):
		var eje: String = ["X", "Y", "Z"][i]
		var s2: HSlider = _slider(caja, "giro " + eje, -60.0, 60.0, 0.0, "g" + str(i))
		s2.step = 0.5
		_sl_giro.append(s2)
		var idx: int = i
		s2.value_changed.connect(func(v: float) -> void:
			_poner_etiqueta("g" + str(idx), v)
			if _ocupado or _sel == "":
				return
			var gv: Vector3 = _giro.get(_sel, Vector3.ZERO)
			gv[idx] = v
			if gv == Vector3.ZERO:
				_giro.erase(_sel)
			else:
				_giro[_sel] = gv
			_aplicar()
			_refrescar_texto())
	var fila := HBoxContainer.new()
	caja.add_child(fila)
	var b_rest := Button.new()
	b_rest.text = "Reiniciar hueso"
	b_rest.pressed.connect(func() -> void:
		if _sel != "":
			_giro.erase(_sel)
			_fh.erase(_sel)
			_vaiven.erase(_sel)
			_elegir_hueso(_sel)
			_aplicar()
			_refrescar_texto())
	fila.add_child(b_rest)
	var b_todo := Button.new()
	b_todo.text = "Reiniciar todo"
	b_todo.pressed.connect(_reiniciar_todo)
	fila.add_child(b_todo)

	caja.add_child(_titulo("Resultado (se actualiza solo)"))
	_txt = TextEdit.new()
	_txt.editable = false
	_txt.custom_minimum_size = Vector2(0.0, 100.0)
	caja.add_child(_txt)
	var b_cop := Button.new()
	b_cop.text = "Copiar resultado al portapapeles"
	b_cop.pressed.connect(func() -> void: DisplayServer.clipboard_set(_txt.text))
	caja.add_child(b_cop)

	var ayuda := Label.new()
	ayuda.text = "1 lateral · 2 frente · 3 arriba · 4 3/4 · rueda zoom · arrastrar orbita"
	ayuda.position = Vector2(8.0, 0.0)
	ayuda.anchor_top = 1.0
	ayuda.anchor_bottom = 1.0
	ayuda.offset_top = -28.0
	ayuda.offset_left = 8.0
	capa.add_child(ayuda)


func _titulo(texto: String) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	return l


func _slider(padre: Control, nombre: String, mn: float, mx: float, ini: float, clave: String) -> HSlider:
	var f := HBoxContainer.new()
	padre.add_child(f)
	var l := Label.new()
	l.text = nombre
	l.custom_minimum_size = Vector2(100.0, 0.0)
	f.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = 0.01
	s.value = ini
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(120.0, 0.0)
	f.add_child(s)
	var v := Label.new()
	v.text = "%.2f" % ini
	v.custom_minimum_size = Vector2(46.0, 0.0)
	f.add_child(v)
	_lbl_fact[clave if clave != "" else "vel"] = v
	return s


func _poner_etiqueta(clave: String, v: float) -> void:
	var l: Label = _lbl_fact.get(clave if clave != "" else "vel", null)
	if l != null:
		l.text = "%.2f" % v


# ---------- animación ----------

func _elegir_clip(nombre: String) -> void:
	_clip = nombre
	for i in range(_opt_clip.item_count):
		if _opt_clip.get_item_text(i) == nombre:
			_opt_clip.select(i)
	_guardar_originales(nombre)
	_ap.play(nombre)
	_ap.speed_scale = 0.0 if _chk_pausa.button_pressed else _sl_vel.value
	_aplicar()
	_refrescar_texto()


## Guarda las claves originales de las pistas de rotación del clip, una sola vez. Las claves del recurso importado se
## reescriben en cada cambio de slider, así que sin esta copia no se podría volver atrás.
func _guardar_originales(clip: String) -> void:
	if _orig.has(_id + "/" + clip):
		return
	var an: Animation = _ap.get_animation(clip)
	var d: Dictionary = {}
	for t in range(an.get_track_count()):
		if an.track_get_type(t) != Animation.TYPE_ROTATION_3D or an.track_get_key_count(t) < 1:
			continue
		var qs: Array = []
		for i in range(an.track_get_key_count(t)):
			qs.append(an.track_get_key_value(t, i))
		d[t] = qs
	_orig[_id + "/" + clip] = d


func _grupo_de(hueso: String) -> String:
	if _del.has(hueso):
		return "del"
	if _tras.has(hueso):
		return "tras"
	return "resto"


## Recalcula todas las claves del clip actual desde las originales: media.slerp(original, factor) y luego el giro fijo del hueso.
func _aplicar() -> void:
	if _clip == "" or not _orig.has(_id + "/" + _clip):
		return
	var an: Animation = _ap.get_animation(_clip)
	var d: Dictionary = _orig[_id + "/" + _clip]
	for t in d.keys():
		var hueso: String = str(an.track_get_path(t)).get_slice(":", 1)
		var k: float = float(_fh.get(hueso, _factor[_grupo_de(hueso)]))
		var qs: Array = d[t]
		var q0: Quaternion = qs[0]
		var suma := Vector4.ZERO
		for q in qs:
			var qq: Quaternion = q
			if qq.dot(q0) < 0.0:
				qq = Quaternion(-qq.x, -qq.y, -qq.z, -qq.w)      # mismo giro en el otro hemisferio: para promediar bien
			suma += Vector4(qq.x, qq.y, qq.z, qq.w)
		var media: Quaternion = Quaternion(suma.x, suma.y, suma.z, suma.w).normalized()
		var gv: Vector3 = _giro.get(hueso, Vector3.ZERO)
		var extra := Quaternion.IDENTITY
		if gv != Vector3.ZERO:
			extra = Quaternion.from_euler(Vector3(deg_to_rad(gv.x), deg_to_rad(gv.y), deg_to_rad(gv.z)))
		var vals: Array = []
		for i in range(qs.size()):
			var q2: Quaternion = qs[i]
			vals.append((extra * media.slerp(q2, k)) if qs.size() > 1 else (extra * q2))
		if _vaiven.has(hueso) and qs.size() > 1:
			var amp: float = deg_to_rad(float(_vaiven[hueso]))
			var fase: float = float(FASE_PATA.get(hueso, 0.0))
			for i in range(qs.size()):
				var ph: float = TAU * (an.track_get_key_time(t, i) / an.length - fase)
				vals[i] = Quaternion((EJE_FLEX.get(hueso, Vector3.RIGHT) as Vector3).normalized(), amp * cos(ph)) * (vals[i] as Quaternion)
		var ic: int = _cola.find(hueso)
		var retraso: float = _retraso_cola * float(ic + 1) * an.length if ic >= 0 else 0.0
		for i in range(qs.size()):
			var nuevo: Quaternion = vals[i]
			if retraso > 0.0 and qs.size() > 1:
				nuevo = _muestrear(an, t, vals, an.track_get_key_time(t, i) - retraso)
			an.track_set_key_value(t, i, nuevo)


## Valor de la pista `t` (con los valores `vals` en sus claves) en el instante `tiempo`, dando la vuelta al ciclo: así la cola puede
## ir por detrás del cuerpo sin cortes al repetir el bucle.
func _muestrear(an: Animation, t: int, vals: Array, tiempo: float) -> Quaternion:
	var L: float = an.length
	tiempo = fposmod(tiempo, L)
	var n: int = vals.size()
	for i in range(n):
		var t0: float = an.track_get_key_time(t, i)
		var j: int = (i + 1) % n
		var t1: float = an.track_get_key_time(t, j) if j > 0 else an.track_get_key_time(t, 0) + L
		var tt: float = tiempo if tiempo >= t0 else tiempo + L
		if tt >= t0 and tt <= t1:
			var f: float = (tt - t0) / maxf(t1 - t0, 0.00001)
			return (vals[i] as Quaternion).slerp(vals[j], f)
	return vals[0]


func _elegir_hueso(nombre: String) -> void:
	_sel = nombre
	var gv: Vector3 = _giro.get(nombre, Vector3.ZERO)
	_ocupado = true
	var vv: float = float(_vaiven.get(nombre, 0.0))
	_sl_vaiven.value = vv
	_poner_etiqueta("vv", vv)
	var kh: float = float(_fh.get(nombre, _factor[_grupo_de(nombre)]))
	_sl_fh.value = kh
	_poner_etiqueta("fh", kh)
	for i in range(3):
		_sl_giro[i].value = gv[i]
		_poner_etiqueta("g" + str(i), gv[i])
	_ocupado = false


func _reiniciar_todo() -> void:
	_giro.clear()
	_fh = _fh0.duplicate()
	_ocupado = true
	_factor = _factor0.duplicate()
	for c in _factor.keys():
		(_sl_fact[c] as HSlider).value = float(_factor[c])
		_poner_etiqueta(c, float(_factor[c]))
	_retraso_cola = _retraso0
	_vaiven = _vaiven0.duplicate()
	_sl_retraso.value = _retraso_cola
	_poner_etiqueta("rc", _retraso_cola)
	_ocupado = false
	if _sel != "":
		_elegir_hueso(_sel)
	_aplicar()
	_refrescar_texto()


func _refrescar_texto() -> void:
	if _txt == null:
		return
	var s: String = "clip: %s\n" % _clip
	s += "factor delanteras: %.2f\nfactor traseras: %.2f\nfactor resto: %.2f\n" % [_factor["del"], _factor["tras"], _factor["resto"]]
	s += "velocidad: %.2f   retraso cola: %.3f del ciclo por hueso\n" % [_sl_vel.value, _retraso_cola]
	if not _fh.is_empty():
		s += "factor propio por hueso:"
		for h in _fh.keys():
			s += " %s=%.2f" % [h, float(_fh[h])]
		s += "\n"
	if not _vaiven.is_empty():
		s += "vaivén (grados, + dobla):"
		for h in _vaiven.keys():
			s += " %s=%.0f" % [h, float(_vaiven[h])]
		s += "\n"
	if _giro.is_empty():
		s += "giros fijos: ninguno"
	else:
		s += "giros fijos (grados X, Y, Z):"
		for h in _giro.keys():
			var g: Vector3 = _giro[h]
			s += "\n  %s: %.1f, %.1f, %.1f" % [h, g.x, g.y, g.z]
	_txt.text = s


# ---------- cámara y dibujo ----------

func _process(_d: float) -> void:
	if _marcha_activa():
		_paso_marcha(_d)
	if _ap != null and _ap.current_animation != "" and not _chk_pausa.button_pressed:
		_ocupado = true
		_sl_tiempo.value = _ap.current_animation_position / maxf(_ap.current_animation_length, 0.001)
		_poner_etiqueta("t", _sl_tiempo.value)
		_ocupado = false
	_colocar_camara()
	_dibujar_esqueleto()


func _colocar_camara() -> void:
	var dir := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
	_cam.position = _foco + dir * _dist
	_cam.look_at(_foco, Vector3.UP if absf(_pitch) < 1.5 else Vector3.FORWARD)


func _camara_preset(i: int) -> void:
	match i:
		0:
			_yaw = PI * 0.5
			_pitch = 0.05
		1:
			_yaw = 0.0
			_pitch = 0.1
		2:
			_yaw = PI * 0.5
			_pitch = 1.5
		3:
			_yaw = PI * 0.25
			_pitch = 0.5


func _dibujar_esqueleto() -> void:
	_im.clear_surfaces()
	if _chk_esq == null or not _chk_esq.button_pressed or _marcha_activa():
		return
	_im.surface_begin(Mesh.PRIMITIVE_LINES)
	for b in range(_sk.get_bone_count()):
		var p: int = _sk.get_bone_parent(b)
		if p < 0:
			continue
		var nombre: String = _sk.get_bone_name(b)
		# El loberno trae huesos de control (IK, polos, FF) colgados de la raíz: no son del cuerpo y solo dibujan rayas largas.
		if nombre.begins_with("IK") or nombre.begins_with("Pole") or nombre.begins_with("FF"):
			continue
		var col: Color = COLOR_RESTO
		match _grupo_de(nombre):
			"del":
				col = COLOR_DEL
			"tras":
				col = COLOR_TRAS
		if nombre == _sel:
			col = COLOR_SEL
		var a: Vector3 = _sk.global_transform * _sk.get_bone_global_pose(p).origin
		var c: Vector3 = _sk.global_transform * _sk.get_bone_global_pose(b).origin
		_im.surface_set_color(col)
		_im.surface_add_vertex(a)
		_im.surface_set_color(col)
		_im.surface_add_vertex(c)
	_im.surface_end()


func _unhandled_input(ev: InputEvent) -> void:
	var en_marcha: bool = _marcha_activa()
	# En el modo marcha el botón izquierdo mueve la PRESA y el derecho orbita; fuera de él, el izquierdo orbita como siempre.
	var boton_orbita: int = MOUSE_BUTTON_MASK_RIGHT if en_marcha else MOUSE_BUTTON_MASK_LEFT
	if ev is InputEventMouseMotion and (ev.button_mask & boton_orbita) != 0:
		_yaw -= ev.relative.x * 0.01
		_pitch = clampf(_pitch + ev.relative.y * 0.01, -0.2, 1.5)
	elif ev is InputEventMouseMotion and en_marcha and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_presa_al_raton(ev.position)
	elif ev is InputEventMouseButton and ev.pressed and en_marcha and ev.button_index == MOUSE_BUTTON_LEFT:
		_presa_al_raton(ev.position)
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(_dist * 0.9, 0.8)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(_dist * 1.1, 8.0)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_N:
				_alternar_modo_marcha()
			KEY_P:
				marcha_modo("patrulla")
			KEY_C:
				marcha_modo("persigue")
			KEY_Q:
				marcha_modo("quieto")
			KEY_B:
				alternar_marcha_animal()
			KEY_1:
				_camara_preset(0)
			KEY_2:
				_camara_preset(1)
			KEY_3:
				_camara_preset(2)
			KEY_4:
				_camara_preset(3)
			KEY_SPACE:
				_chk_pausa.button_pressed = not _chk_pausa.button_pressed
			KEY_S:
				_chk_esq.button_pressed = not _chk_esq.button_pressed
			KEY_H:
				# Humo negro de los pies. Se enciende/apaga; solo tiene sentido con el canouro, pero el rig del lobo lo admite igual.
				if _humo == null and _modelo != null:
					_humo = VfxCanouro3D.humo_patas(_modelo, 1.0)
				elif _humo != null:
					_humo.queue_free()
					_humo = null
			KEY_Z:
				# Clip «Zarpazo» (si el modelo lo trae) y las garras sobre un «jugador» imaginario 1 m por delante del morro (el modelo mira
				# a +Z). El tajo se dibuja entre ~0,33 y ~0,47 s del clip (golpe en 0,40) y con el ángulo REAL del barrido de la pata visto
				# desde la cámara: gira la cámara (arrastrar) y pulsa Z de nuevo para ver que sigue coincidiendo. El lab repite el clip en
				# bucle, pero las garras solo salen una vez por pulsación.
				if _ap != null and _ap.has_animation("Zarpazo"):
					_elegir_clip("Zarpazo")
					_ap.seek(0.0, true)
					await get_tree().create_timer((VfxCanouro3D.T_GOLPE_ZARPAZO - 0.07) / maxf(_ap.speed_scale, 0.05), false).timeout
				var dir: Vector3 = _modelo.global_transform.basis.orthonormalized() * VfxCanouro3D.DIR_ZARPAZO_LOCAL
				VfxCanouro3D.zarpazo(self, Vector3(0.0, 0.5, 1.0), dir, 1.0)
			KEY_M:
				_cambiar_modelo(String(MODELOS.keys()[(MODELOS.keys().find(_id) + 1) % MODELOS.size()]))


# ---------- MODO MARCHA (4/11) ----------
# Reproduce lo que hace `Combate3D` con la marcha del animal (enemigos/combate_3d.gd: `_patrullar`, `_ia` persigue, `_atacar`, `_animar`, `_actualizar_marcha`)
# sin montar un nivel: el mismo Pj3D, la misma capa MarchaCuadrupedo3D y las mismas llamadas, en el mismo orden (IA → actualizar → animar).

## Hay modo marcha a la vista: pedido con N y el modelo tiene perfil (el lince no).
func _marcha_activa() -> bool:
	return _marcha_on and MarchaCuadrupedo3D.tiene_perfil(_id)


func _montar_escena_marcha() -> void:
	# Suelo grande con cuadrícula de 0,5 u (en coordenadas del mundo, para ver cuánto avanza)
	_suelo_marcha = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(MARCHA_SUELO, MARCHA_SUELO)
	_suelo_marcha.mesh = pm
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode unshaded;\nvarying vec2 wp;\nvoid vertex(){\n\twp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;\n}\nvoid fragment(){\n\tvec2 g = abs(fract(wp * 2.0 - 0.5) - 0.5) / fwidth(wp * 2.0);\n\tfloat l = 1.0 - min(min(g.x, g.y), 1.0);\n\tvec2 g2 = abs(fract(wp * 0.2 - 0.5) - 0.5) / fwidth(wp * 0.2);\n\tfloat l2 = 1.0 - min(min(g2.x, g2.y), 1.0);\n\tALBEDO = mix(vec3(0.17, 0.2, 0.17), vec3(0.3, 0.36, 0.3), l * 0.7 + l2 * 0.6);\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_suelo_marcha.material_override = mat
	_suelo_marcha.visible = false
	add_child(_suelo_marcha)
	# La presa: un maniquí (cápsula + cabeza) con sombra redonda en el suelo. Lo mueve el ratón.
	_presa = Node3D.new()
	_presa.visible = false
	add_child(_presa)
	var mat_p := StandardMaterial3D.new()
	mat_p.albedo_color = Color(0.95, 0.6, 0.2)
	var cuerpo := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.16
	cap.height = 0.8
	cuerpo.mesh = cap
	cuerpo.material_override = mat_p
	cuerpo.position = Vector3(0.0, 0.4, 0.0)
	_presa.add_child(cuerpo)
	var cabeza := MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = 0.13
	esf.height = 0.26
	cabeza.mesh = esf
	cabeza.material_override = mat_p
	cabeza.position = Vector3(0.0, 0.93, 0.0)
	_presa.add_child(cabeza)
	var sombra := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.32
	cil.bottom_radius = 0.32
	cil.height = 0.004
	sombra.mesh = cil
	var mat_s := StandardMaterial3D.new()
	mat_s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_s.albedo_color = Color(0.0, 0.0, 0.0, 0.45)
	mat_s.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sombra.material_override = mat_s
	sombra.position = Vector3(0.0, 0.01, 0.0)
	_presa.add_child(sombra)
	# Rótulo y botón del modo marcha
	_capa_marcha = CanvasLayer.new()
	_capa_marcha.visible = false
	add_child(_capa_marcha)
	var panel := PanelContainer.new()
	panel.position = Vector2(8.0, 8.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa_marcha.add_child(panel)
	var caja := VBoxContainer.new()
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(caja)
	_rotulo = Label.new()
	_rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(_rotulo)
	var ayuda := Label.new()
	ayuda.text = "N volver al rig · P patrulla · C persigue · Q parado · B marcha sí/no · M animal · 1-4 cámara\nclic izq. / arrastrar = mover la presa · botón der. = orbitar · rueda = zoom"
	ayuda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ayuda.modulate = Color(0.8, 0.85, 0.9)
	caja.add_child(ayuda)
	_btn_marcha = Button.new()
	_btn_marcha.text = "Volver al rig (N)"
	_btn_marcha.pressed.connect(_alternar_modo_marcha)
	caja.add_child(_btn_marcha)


## N / botón: alterna entre el modo de antes (clip en bucle quieto + panel de huesos) y el modo marcha.
func _alternar_modo_marcha() -> void:
	_marcha_on = not _marcha_on
	if _marcha_on:
		_dist_rig = _dist
	else:
		_dist = _dist_rig
	_aplicar_modo_marcha()


## Deja la escena como pide `_marcha_on` y el modelo actual: quita o monta el animal de la marcha y enseña u oculta el rig, el panel y el suelo.
func _aplicar_modo_marcha() -> void:
	_quitar_marcha()
	var activa: bool = _marcha_activa()
	if _capa != null:
		_capa.visible = not activa
	if _modelo != null:
		_modelo.visible = not activa
	if _suelo_chico != null:
		_suelo_chico.visible = not activa
	if _suelo_marcha != null:
		_suelo_marcha.visible = activa
	if _presa != null:
		_presa.visible = activa
	if _capa_marcha != null:
		_capa_marcha.visible = _marcha_on
	if _cam != null:
		_cam.h_offset = 0.0 if _marcha_on else -0.55
	if not _marcha_on:
		return
	_dist = MARCHA_DIST
	if not activa:
		_rotulo.text = "MODO MARCHA — el %s no tiene perfil de marcha: se ve como antes (M para cambiar de animal)" % _id
		return
	var pj := Pj3D.new()
	add_child(pj)
	if not pj.cargar(_id):
		pj.queue_free()
		_rotulo.text = "MODO MARCHA — no se pudo cargar %s" % _id
		return
	pj.grafo = ArbolAnimPj.GRAFO_REDUCIDO
	pj.set_alto(float(MARCHA_ALTO.get(_id, 0.7)))
	_m_casa = Vector3(-1.0, 0.0, 0.0)
	pj.position = _m_casa
	pj.mirar(Vector3.RIGHT, 1.0)                  # de cara a +X (con delta 1 gira de golpe)
	_mpj = pj
	_mm = MarchaCuadrupedo3D.para(pj)             # la capa se cuelga del esqueleto, como hace Combate3D en `_ready`
	if _mm != null:
		_mm.rumbo = pj.rotation.y
	_m_modo = "quieto"                            # cada animal nuevo empieza parado: P patrulla, C persigue
	_m_dir = 1.0
	_m_mirada = Vector3.RIGHT
	_m_ataque = 0.0
	_m_carga = 0.0
	_m_descanso = 0.0
	_m_en_rango = false
	_m_v_real = 0.0
	_m_moviendo = 0
	_presa_pos = Vector3(3.5, 0.0, 0.0)
	_presa.position = _presa_pos
	_foco = _m_casa + Vector3(0.0, 0.35, 0.0)
	pj.jugar("idle")
	_sincronizar_capa()


func _quitar_marcha() -> void:
	if _mpj != null and is_instance_valid(_mpj):
		_mpj.queue_free()
	_mpj = null
	_mm = null


## «quieto» | «patrulla» | «persigue»
func marcha_modo(m: String) -> void:
	if not _marcha_activa() or _mpj == null:
		return
	_m_modo = m
	if m == "patrulla":
		_m_casa = Vector3(_mpj.position.x, 0.0, _mpj.position.z)     # patrulla en X alrededor de donde esté
		_m_dir = 1.0 if _presa_pos.x >= _mpj.position.x else -1.0


## B: MARCHA_ANIMAL en vivo. Apagado, el animal va como antes (clip walk/run a ×1, sin capa, giro en seco).
func alternar_marcha_animal() -> void:
	MarchaCuadrupedo3D.MARCHA_ANIMAL = not MarchaCuadrupedo3D.MARCHA_ANIMAL
	_sincronizar_capa()


## La capa solo corre con MARCHA_ANIMAL: apagada, se desactiva (no hace ni una llamada) y se le quita la escala de patas que deja puesta.
func _sincronizar_capa() -> void:
	if _mm == null or _mpj == null:
		return
	var on: bool = MarchaCuadrupedo3D.MARCHA_ANIMAL
	if on and not _mm.active:
		_mm.rumbo = _mpj.rotation.y
		_mpj.animacion_actual = ""
	elif not on and _mm.active:
		_mm._soltar()
		_mpj.animacion_actual = ""
	_mm.active = on


func _presa_al_raton(p: Vector2) -> void:
	if _cam == null:
		return
	var o: Vector3 = _cam.project_ray_origin(p)
	var n: Vector3 = _cam.project_ray_normal(p)
	if absf(n.y) < 0.001:
		return
	var t: float = -o.y / n.y
	if t <= 0.0:
		return
	var q: Vector3 = o + n * t
	var m: float = MARCHA_SUELO * 0.5 - 1.0
	_presa_pos = Vector3(clampf(q.x, -m, m), 0.0, clampf(q.z, -m, m))


## Un fotograma del animal: la IA de Combate3D (patrullar / perseguir / atacar), luego `actualizar` de la capa y luego `_animar`.
func _paso_marcha(delta: float) -> void:
	if _mpj == null or not is_instance_valid(_mpj):
		return
	var pj: Pj3D = _mpj
	var nueva: bool = _mm != null and MarchaCuadrupedo3D.MARCHA_ANIMAL
	var pos0: Vector3 = pj.position
	_presa.position = _presa_pos
	var persigue: bool = _m_modo == "persigue"
	var moviendo: int = 0
	_m_v_avance = 0.0
	_m_clip_modo = ""
	_m_descanso = maxf(0.0, _m_descanso - delta)
	if _m_ataque > 0.0:
		_m_ataque -= delta                                 # atacando: ni se mueve ni gira
		if _m_ataque <= 0.0 and nueva:
			_mm.al_acabar_ataque()
	elif persigue:
		var d: Vector3 = _presa_pos - pj.position
		d.y = 0.0
		if d.length() > 0.05:
			_m_mirada = d.normalized()
		var rango: float = Combate3D.RANGO_ATAQUE
		if d.length() <= rango:
			_m_en_rango = true
		elif d.length() > rango * Combate3D.HISTERESIS_RANGO:
			_m_en_rango = false
		if nueva and _mm.retirada > 0.0:
			_m_en_rango = false                            # la hiena se retira tras morder
		if _m_en_rango:
			if _m_descanso <= 0.0:
				_m_carga += delta
				if _m_carga >= Combate3D.PREPARAR_GOLPE:
					_m_carga = 0.0
					_atacar_marcha(pj, nueva)
		elif d.length() > 0.3:
			_m_carga = 0.0
			moviendo = 2
			_m_v_avance = _v_base("run", nueva)
			var dir_p: Vector3 = d.normalized()
			var atras: bool = false
			if nueva:
				var cond: Dictionary = _mm.conducta(d.length(), dir_p, delta)
				dir_p = cond["dir"]
				_m_v_avance *= float(cond["v"])
				moviendo = int(cond["moviendo"])
				_m_clip_modo = String(cond["modo"])
				atras = bool(cond["atras"])
			var paso_p: Vector3 = dir_p * _m_v_avance * delta
			if nueva:
				paso_p = _mm.paso_suave(paso_p, delta, atras)
			pj.position += paso_p
	elif _m_modo == "patrulla":
		moviendo = 1
		_m_mirada = Vector3(_m_dir, 0.0, 0.0)
		_m_v_avance = _v_base("walk", nueva)
		var paso := Vector3(_m_dir * _m_v_avance * delta, 0.0, 0.0)
		if nueva:
			paso = _mm.paso_suave(paso, delta)
		pj.position += paso
		var dx: float = pj.position.x - _m_casa.x
		if nueva:
			var fuera: bool = absf(dx) >= MARCHA_PATRULLA - 0.6 and dx * _m_dir > 0.0
			if fuera and _mm.permitir_vuelta():
				_m_dir *= -1.0
		elif absf(dx) >= MARCHA_PATRULLA:
			_m_dir *= -1.0
	_m_moviendo = moviendo
	if nueva:
		_mm.actualizar(delta, pj, _m_mirada, _presa_pos, persigue, _m_v_avance if moviendo > 0 else 0.0)
	# _animar
	if _m_ataque <= 0.0:
		pj.set_velocidad_animacion(1.0)
		if nueva and moviendo > 0:
			_mm.animar_andar(_m_v_avance, _m_clip_modo)
			if _m_mirada.length() > 0.01:
				pj.mirar(_mm.rumbo_vec(), 0.05)
		else:
			if moviendo == 0:
				pj.jugar("idle")
			else:
				pj.jugar("run" if moviendo == 2 else "walk")
			if _m_mirada.length() > 0.01 and (moviendo > 0 or persigue):
				pj.mirar(_mm.rumbo_vec() if nueva else _m_mirada, 0.05)
	# Cámara que sigue al animal y rótulo
	var real: float = (pj.position - pos0).length() / maxf(delta, 0.0001)
	_m_v_real = lerpf(_m_v_real, real, clampf(delta / 0.25, 0.0, 1.0))
	# La cámara sigue al animal; persiguiendo se corre hacia el punto medio con la presa (hasta 3 u) para que se vean los dos
	var objetivo_foco: Vector3 = pj.position + Vector3(0.0, 0.3, 0.0)
	if persigue:
		var hacia: Vector3 = _presa_pos - pj.position
		hacia.y = 0.0
		objetivo_foco += hacia.limit_length(6.0) * 0.5
	_foco = _foco.lerp(objetivo_foco, clampf(1.0 - exp(-6.0 * delta), 0.0, 1.0))
	_actualizar_rotulo()


func _v_base(clip: String, nueva: bool) -> float:
	if nueva:
		return _mm.v_base(clip)
	return Combate3D.VEL_PERSEGUIR if clip == "run" else Combate3D.VEL_PATRULLA


## `Combate3D._iniciar_ataque` sin golpe: el clip entero, avisa a la capa (retirada de la hiena) y deja el descanso.
func _atacar_marcha(pj: Pj3D, nueva: bool) -> void:
	var dur: float = pj.duracion("attack")
	if dur <= 0.0:
		dur = 0.6
	_m_ataque = dur / maxf(pj.ritmo, 0.01)
	_m_descanso = Combate3D.DESCANSO_GOLPE
	if nueva:
		_mm.al_atacar()
	pj.animacion_actual = ""
	pj.set_velocidad_animacion(1.0)
	pj.jugar("attack", true)


func _actualizar_rotulo() -> void:
	if _rotulo == null:
		return
	var s: String = "MODELO: %s    MARCHA: %s    modo: %s\n" % [_id, "SÍ" if MarchaCuadrupedo3D.MARCHA_ANIMAL else "NO", _m_modo]
	var est: String = _mm.estado_conducta() if _mm != null and _mm.active else ""      # sin capa no hay conducta (el estado quedaría viejo)
	s += "conducta: %s\n" % (est if est != "" else "—")
	s += "clip: %s    vel. del clip: ×%.2f\n" % [_mpj.clip_actual(), _mpj.velocidad_animacion()]
	s += "velocidad real: %.2f u/s    pedida: %.2f\n" % [_m_v_real, _m_v_avance]
	if _mm != null and _mm.active:
		s += "pendiente del lomo: %.1f°    giro de la cabeza: %.1f°" % [_mm.pendiente_lomo(), _mm.yaw_cabeza()]
	else:
		s += "pendiente del lomo: —    giro de la cabeza: —   (sin capa)"
	_rotulo.text = s
