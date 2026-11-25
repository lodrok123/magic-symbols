extends Node3D

## GALERÍA DE ANIMACIONES UAL (25/11, Pablo: «mete todas las animaciones en bucle en una escena navegable para que pueda moverme y revisarlas todas de una vez»).
## Todas las animaciones de la Universal Animation Library 1 y 2 de Quaternius (CC0; arte/ual/ual1_standard_mixamo.glb y ual2_standard_mixamo.glb, huesos renombrados con
## tools/ual_a_mixamo.py), cada una en una jugadora_base montada como el juego (Pj3D.cargar: ropa por defecto, proporciones) y EN BUCLE, a la vez, en una cuadrícula.
## Encima de cada una, un cartel con el nombre original del clip, la librería y lo que dura. Se traducen con el MISMO retarget que el juego (ClipsFamilia._traer_de, con
## los dedos alineados: ClipsFamilia.DEDOS_ALINEAR), una sola vez, y las jugadoras comparten las animaciones. Sin reflejar: tal cual vienen (en el juego, los cuatro
## del conjuro van reflejados para lanzar con la derecha).
## Fuera solo A_TPose (la pose en T de las dos librerías). Los clips que se desplazan (voltereta, muerte, golpes que echan atrás) vuelven a su sitio al repetirse.
## El juego no carga nada de aquí. No modifica ningún archivo.
## Teclas: WASD mover · Q/E bajar/subir · clic derecho + arrastrar mirar · rueda velocidad · Mayús rápido · Tab / Mayús+Tab siguiente / anterior clip ·
##         Espacio pausa · V velocidad de las animaciones · M maniquí de Quaternius al lado (el clip original) · H ocultar la ayuda
## Abrir: laboratorios/LabGaleriaUAL3D.tscn y F6.

const ID: String = "jugadora_base"
const ALTO: float = 1.0                       ## u de juego (el alto de la jugadora en el juego)
const LIBRERIAS: Array = [
	## [etiqueta, ruta, clip de referencia (de pie, pies en el suelo: fija la altura de los pies), prefijo del nombre en la jugadora]
	["UAL 1", "res://arte/ual/ual1_standard_mixamo.glb", "Idle", "ual1_"],
	["UAL 2", "res://arte/ual/ual2_standard_mixamo.glb", "Idle_FoldArms", "ual2_"],
]
const FUERA: PackedStringArray = ["A_TPose"]
const COLUMNAS: int = 8
const SEP_X: float = 1.8                      ## u entre jugadoras de una fila
const SEP_Z: float = 2.6                      ## u entre filas (las filas se alejan hacia +Z; todas miran hacia −Z, hacia donde se llega)
const HUECO_LIBRERIA: float = 2.0             ## u de más entre la última fila de UAL 1 y la primera de UAL 2
const LADO_MANIQUI: float = 0.65              ## u a la derecha de cada jugadora donde va su maniquí (M)
const ALTO_CARTEL: float = 1.3
const VEL_MOVER: float = 3.0                  ## u/s de la cámara (la rueda la cambia; Mayús ×3)
const SENS_RATON: float = 0.005
const VELOCIDADES: Array = [1.0, 0.5, 0.25]
const TAM_LETRA: int = 10

var _clips: Array = []                        ## [{nombre (en la jugadora), origen, lib (índice), dur, pos: Vector3, pj: Pj3D, ap, maniqui: Node3D}]
var _cam: Camera3D = null
var _yaw: float = 0.0
var _pitch: float = -0.35
var _vel_mover: float = VEL_MOVER
var _vel_anim: int = 0
var _pausa: bool = false
var _maniquies: bool = false
var _sel: int = -1
var _ayuda: Label = null
var _info: Label = null


func _ready() -> void:
	_montar_escena()
	_montar_galeria()
	_montar_interfaz()
	# Delante de la primera fila, en el centro, mirando hacia +Z (las filas se alejan).
	_cam.position = Vector3((COLUMNAS - 1) * SEP_X * 0.5, 3.0, -4.5)
	_yaw = PI
	_aplicar_mirada()


# ---------- escena ----------

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
	_cam = Camera3D.new()
	_cam.fov = 50.0
	add_child(_cam)
	_cam.current = true


func _suelo(ancho: float, fondo: float, centro: Vector3) -> void:
	var suelo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(ancho, fondo)
	suelo.mesh = pm
	suelo.position = centro
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode unshaded;\nvarying vec3 p_mundo;\nvoid vertex(){ p_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }\nvoid fragment(){\n\tvec2 p = p_mundo.xz * 4.0;\n\tvec2 g = abs(fract(p - 0.5) - 0.5) / fwidth(p);\n\tfloat l = 1.0 - min(min(g.x, g.y), 1.0);\n\tALBEDO = mix(vec3(0.16, 0.18, 0.21), vec3(0.32, 0.35, 0.4), l);\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	suelo.material_override = mat
	add_child(suelo)


# ---------- galería ----------

func _montar_galeria() -> void:
	# 1) Una jugadora de referencia: con ella se traducen los clips (las demás comparten las animaciones).
	var ref: Pj3D = _nueva_jugadora()
	var sk_ref: Skeleton3D = ref.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var traducidos: Dictionary = {}           # nombre en la jugadora -> Animation
	var z: float = 0.0
	var primera: bool = true
	for li in range(LIBRERIAS.size()):
		var lib: Array = LIBRERIAS[li]
		var ruta: String = String(lib[1])
		if not ResourceLoader.exists(ruta):
			push_warning("LabGaleriaUAL3D: falta %s (tools/ual_a_mixamo.py)" % ruta)
			continue
		var nombres: Array = _clips_del_glb(ruta)
		var pedidos: Dictionary = {}
		for n in nombres:
			pedidos[String(lib[3]) + String(n)] = String(n)
		var res: Dictionary = {}
		var f: Dictionary = {"ruta": ruta, "referencia": String(lib[2]), "alinear_extra": ClipsFamilia.DEDOS_ALINEAR, "clips": pedidos}
		ClipsFamilia._traer_de(f, ref._modelo, sk_ref, res, ClipsFamilia.alinear_de(ID))
		if not primera:
			z += HUECO_LIBRERIA
		primera = false
		var col: int = 0
		for n in nombres:
			var nombre: String = String(lib[3]) + String(n)
			if not res.has(nombre):
				continue
			var an: Animation = res[nombre]
			an.loop_mode = Animation.LOOP_LINEAR
			traducidos[nombre] = an
			_clips.append({"nombre": nombre, "origen": String(n), "lib": li, "dur": an.length, "pos": Vector3(col * SEP_X, 0.0, z), "maniqui": null})
			col += 1
			if col >= COLUMNAS:
				col = 0
				z += SEP_Z
		if col != 0:
			z += SEP_Z
	# 2) Una jugadora por clip (la de referencia hace de primera), con su clip en bucle y su cartel.
	for i in range(_clips.size()):
		var c: Dictionary = _clips[i]
		var pj: Pj3D = ref if i == 0 else _nueva_jugadora()
		pj.position = c["pos"]
		pj.rotation.y = PI                        # de cara a la cámara (que llega desde −Z)
		var ap: AnimationPlayer = pj._ap
		var lib_ap: AnimationLibrary = ap.get_animation_library("")
		if not lib_ap.has_animation(String(c["nombre"])):
			lib_ap.add_animation(String(c["nombre"]), traducidos[c["nombre"]] as Animation)
		ap.play(String(c["nombre"]))
		c["pj"] = pj
		c["ap"] = ap
		_cartel(c)
	if _clips.is_empty():
		ref.queue_free()
	var ancho: float = COLUMNAS * SEP_X + 6.0
	_suelo(ancho, z + 6.0, Vector3((COLUMNAS - 1) * SEP_X * 0.5, 0.0, z * 0.5))


func _nueva_jugadora() -> Pj3D:
	var pj := Pj3D.new()
	add_child(pj)
	pj.cargar(ID)
	pj.set_alto(ALTO)
	if pj._arbol != null:
		pj._arbol.active = false              # el árbol manda sobre el reproductor: aquí cada una lleva su clip a mano
	if pj._ap != null:
		pj._ap.active = true
	return pj


## Los clips de un GLB (sin los de FUERA), por orden alfabético.
func _clips_del_glb(ruta: String) -> Array:
	var nodo: Node = (load(ruta) as PackedScene).instantiate()
	var aps: Array[Node] = nodo.find_children("*", "AnimationPlayer", true, false)
	var lista: Array = []
	if not aps.is_empty():
		for n in (aps[0] as AnimationPlayer).get_animation_list():
			if not FUERA.has(String(n)):
				lista.append(String(n))
	nodo.free()
	lista.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a).naturalnocasecmp_to(String(b)) < 0)
	return lista


func _cartel(c: Dictionary) -> void:
	var l := Label3D.new()
	l.text = "%s\n%s · %s s" % [c["origen"], (LIBRERIAS[int(c["lib"])] as Array)[0], String.num(float(c["dur"]), 2).replace(".", ",")]
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 32
	l.outline_size = 8
	l.pixel_size = 0.0022
	l.position = (c["pos"] as Vector3) + Vector3(0.0, ALTO_CARTEL, 0.0)
	add_child(l)


# ---------- maniquíes (M) ----------

## El maniquí de Quaternius al lado de cada jugadora, con el clip ORIGINAL. Se crean la primera vez que se piden.
func poner_maniquies(on: bool) -> void:
	_maniquies = on
	for c in _clips:
		if on and c["maniqui"] == null:
			c["maniqui"] = _nuevo_maniqui(c)
		if c["maniqui"] != null:
			(c["maniqui"] as Node3D).visible = on
	_sincronizar()


func _nuevo_maniqui(c: Dictionary) -> Node3D:
	var ruta: String = String((LIBRERIAS[int(c["lib"])] as Array)[1])
	var m: Node3D = (load(ruta) as PackedScene).instantiate() as Node3D
	add_child(m)
	var sk: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	# Misma altura de cabeza que la jugadora (el maniquí mide ~1,8 m; ella, ALTO).
	var pj: Pj3D = c["pj"]
	var sk_pj: Skeleton3D = pj.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var cab_pj: float = (sk_pj.global_transform * sk_pj.get_bone_global_rest(sk_pj.find_bone("mixamorig_Head")).origin).y - pj.global_position.y
	var cab_m: float = (sk.global_transform * sk.get_bone_global_rest(sk.find_bone("mixamorig_Head")).origin).y - m.global_position.y
	if cab_m > 0.001:
		m.scale = Vector3.ONE * (cab_pj / cab_m)
	m.position = (c["pos"] as Vector3) + Vector3(LADO_MANIQUI, 0.0, 0.0)
	m.rotation.y = PI
	var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	ap.get_animation(String(c["origen"])).loop_mode = Animation.LOOP_LINEAR
	ap.play(String(c["origen"]))
	c["ap_m"] = ap
	return m


# ---------- reproducción ----------

## Todas desde el principio a la vez, con la velocidad y la pausa de ahora.
func _sincronizar() -> void:
	for c in _clips:
		for clave in ["ap", "ap_m"]:
			var ap: AnimationPlayer = c.get(clave) as AnimationPlayer
			if ap == null:
				continue
			ap.speed_scale = 0.0 if _pausa else float(VELOCIDADES[_vel_anim])
			ap.seek(0.0, true)


func poner_pausa(p: bool) -> void:
	_pausa = p
	for c in _clips:
		for clave in ["ap", "ap_m"]:
			var ap: AnimationPlayer = c.get(clave) as AnimationPlayer
			if ap != null:
				ap.speed_scale = 0.0 if _pausa else float(VELOCIDADES[_vel_anim])


func clips() -> Array:
	return _clips


# ---------- cámara ----------

func _aplicar_mirada() -> void:
	_cam.rotation = Vector3(_pitch, _yaw, 0.0)


## Lleva la cámara delante del clip `i` (mirando a la jugadora y su maniquí).
func ir_a(i: int) -> void:
	if _clips.is_empty():
		return
	_sel = wrapi(i, 0, _clips.size())
	var p: Vector3 = (_clips[_sel] as Dictionary)["pos"]
	var foco: Vector3 = p + Vector3(LADO_MANIQUI * 0.5 if _maniquies else 0.0, 0.55, 0.0)
	_cam.position = foco + Vector3(0.5, 0.6, -1.9)
	_cam.look_at(foco, Vector3.UP)
	_yaw = _cam.rotation.y
	_pitch = _cam.rotation.x


func _process(delta: float) -> void:
	var d := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		d.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		d.z += 1.0
	if Input.is_key_pressed(KEY_A):
		d.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		d.x += 1.0
	var sube: float = (1.0 if Input.is_key_pressed(KEY_E) else 0.0) - (1.0 if Input.is_key_pressed(KEY_Q) else 0.0)
	var v: float = _vel_mover * (3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	if d != Vector3.ZERO:
		# adelante/atrás y a los lados en el plano del suelo (mirar hacia abajo no hunde la cámara)
		var b: Basis = Basis(Vector3.UP, _yaw)
		_cam.position += (b * d.normalized()) * v * delta
	_cam.position.y = maxf(_cam.position.y + sube * v * delta, 0.2)
	if _info != null:
		var txt: String = "%d clips · %d FPS · velocidad %s%s" % [_clips.size(), Engine.get_frames_per_second(), String.num(float(VELOCIDADES[_vel_anim])).replace(".", ","), " · PAUSA" if _pausa else ""]
		if _sel >= 0:
			var c: Dictionary = _clips[_sel]
			txt += "\n→ %s (%s)" % [c["origen"], (LIBRERIAS[int(c["lib"])] as Array)[0]]
		_info.text = txt


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion and ((ev as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
		_yaw -= (ev as InputEventMouseMotion).relative.x * SENS_RATON
		_pitch = clampf(_pitch - (ev as InputEventMouseMotion).relative.y * SENS_RATON, -1.4, 1.2)
		_aplicar_mirada()
	elif ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		var b: MouseButton = (ev as InputEventMouseButton).button_index
		if b == MOUSE_BUTTON_WHEEL_UP:
			_vel_mover = minf(_vel_mover * 1.25, 30.0)
		elif b == MOUSE_BUTTON_WHEEL_DOWN:
			_vel_mover = maxf(_vel_mover / 1.25, 0.3)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		match (ev as InputEventKey).keycode:
			KEY_TAB:
				ir_a(_sel - 1 if (ev as InputEventKey).shift_pressed else _sel + 1)
			KEY_SPACE:
				poner_pausa(not _pausa)
			KEY_V:
				_vel_anim = (_vel_anim + 1) % VELOCIDADES.size()
				poner_pausa(_pausa)
			KEY_M:
				poner_maniquies(not _maniquies)
			KEY_H:
				_ayuda.visible = not _ayuda.visible
			_:
				return
		get_viewport().set_input_as_handled()


# ---------- interfaz (pequeña) ----------

func _montar_interfaz() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)
	var tema := Theme.new()
	tema.default_font_size = TAM_LETRA
	var panel := PanelContainer.new()
	panel.theme = tema
	panel.offset_left = 6.0
	panel.offset_top = 6.0
	capa.add_child(panel)
	var caja := VBoxContainer.new()
	panel.add_child(caja)
	var titulo := Label.new()
	titulo.text = "GALERÍA UAL · todas en bucle (no modifica archivos)"
	titulo.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	caja.add_child(titulo)
	_info = Label.new()
	caja.add_child(_info)
	_ayuda = Label.new()
	_ayuda.text = "WASD mover · Q/E bajar/subir · clic dcho + arrastrar mirar · rueda velocidad · Mayús rápido\nTab / Mayús+Tab siguiente / anterior · Espacio pausa · V velocidad · M maniquí al lado · H ayuda"
	caja.add_child(_ayuda)
