extends Node3D

## LABORATORIO DE POSTURA DEL GRANDMASTER (11/10, Pablo: «métele el grandmaster al lab para corregirle posturas»).
## Una escena vacía con SOLO el grandmaster en bucle y un panel para corregir su postura en vivo, sin tocar el modelo:
##  · Elegir clip (idle, walking, running, hechizos...), velocidad; pausar y arrastrar el fotograma.
##  · Elegir un hueso de la lista y sumarle un giro fijo (X/Y/Z en grados). Se suma a TODAS las claves del clip, así la corrección
##    es la misma en todo el ciclo (p. ej. bajar un hombro, enderezar la cabeza, cerrar los codos).
##  · «Solo este clip» desmarcado = el giro vale para todos los clips (lo normal en una corrección de postura);
##    marcado = solo para el clip que estás viendo (para arreglar un gesto concreto).
##  · Ver el esqueleto dibujado encima (amarillo = hueso elegido).
## El giro es una rotación en el espacio del hueso padre, multiplicada ANTES de la animación (q_nueva = giro · q_clip), igual que en el
## laboratorio del gato. El panel escribe abajo los números; no modifica ningún archivo: pásaselos a Claude.
##
## Teclas: 1 lateral · 2 frente · 3 desde arriba · 4 3/4 · Espacio pausa · S esqueleto · rueda = zoom · arrastrar = orbitar
## Abrir: poc_25d/LabGrandmaster3D.tscn y F6 (no necesita ningún nivel).

const GLB: String = "res://poc_25d/grandmaster.glb"
const ALTO: float = 1.7           ## altura natural medida del modelo; aquí se deja a tamaño real para ver bien las proporciones
const COLOR_RESTO: Color = Color(0.95, 0.95, 0.95)
const COLOR_SEL: Color = Color(1.0, 0.85, 0.1)

var _modelo: Node3D = null
var _sk: Skeleton3D = null
var _ap: AnimationPlayer = null
var _cam: Camera3D = null
var _im: ImmediateMesh = null

var _yaw: float = 0.0
var _pitch: float = 0.15
var _dist: float = 4.2
var _foco: Vector3 = Vector3(0.0, 0.85, 0.0)

var _clip: String = ""
var _orig: Dictionary = {}          ## clip -> {pista(int): Array[Quaternion]} con las claves ORIGINALES del GLB (nunca se pierden)
var _giro_todos: Dictionary = {}    ## hueso -> Vector3 (grados), vale para todos los clips
var _giro_clip: Dictionary = {}     ## clip -> {hueso -> Vector3}, solo para ese clip
var _sel: String = ""

var _lista: ItemList = null
var _sl_giro: Array[HSlider] = []
var _lbl: Dictionary = {}
var _sl_vel: HSlider = null
var _sl_tiempo: HSlider = null
var _chk_esq: CheckBox = null
var _chk_pausa: CheckBox = null
var _chk_clip: CheckBox = null
var _txt: TextEdit = null
var _opt_clip: OptionButton = null
var _ocupado: bool = false


func _ready() -> void:
	_montar_escena()
	if not _cargar():
		return
	_montar_interfaz()
	_elegir_clip("idle" if _ap.has_animation("idle") else String(_ap.get_animation_list()[0]))
	_camara_preset(0)
	_refrescar_texto()


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
	_cam = Camera3D.new()
	_cam.fov = 35.0
	_cam.h_offset = -0.7       # desplaza la vista a la derecha para que el panel no tape al personaje
	add_child(_cam)
	_im = ImmediateMesh.new()
	var lineas := MeshInstance3D.new()
	lineas.mesh = _im
	var ml := StandardMaterial3D.new()
	ml.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ml.vertex_color_use_as_albedo = true
	ml.no_depth_test = true
	ml.render_priority = 10
	lineas.material_override = ml
	lineas.top_level = true
	add_child(lineas)


func _cargar() -> bool:
	if not ResourceLoader.exists(GLB):
		push_warning("LabGrandmaster3D: falta " + GLB)
		return false
	_modelo = (load(GLB) as PackedScene).instantiate() as Node3D
	add_child(_modelo)
	var sks: Array[Node] = _modelo.find_children("*", "Skeleton3D", true, false)
	var aps: Array[Node] = _modelo.find_children("*", "AnimationPlayer", true, false)
	if sks.is_empty() or aps.is_empty():
		push_warning("LabGrandmaster3D: el GLB no trae esqueleto o animaciones")
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
	var capa := CanvasLayer.new()
	add_child(capa)
	# 11/10: el panel es más alto que muchas pantallas y tapaba el resultado y el botón de copiar. Ahora ocupa el alto de la ventana
	# (menos la línea de ayuda de abajo) y lleva barra de desplazamiento propia.
	var panel := PanelContainer.new()
	panel.anchor_bottom = 1.0
	panel.offset_left = 8.0
	panel.offset_top = 8.0
	panel.offset_right = 356.0
	panel.offset_bottom = -34.0
	capa.add_child(panel)
	var desplazable := ScrollContainer.new()
	desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(desplazable)
	var caja := VBoxContainer.new()
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desplazable.add_child(caja)

	var t := Label.new()
	t.text = "POSTURA DEL GRANDMASTER (no modifica archivos)"
	caja.add_child(t)

	_opt_clip = OptionButton.new()
	for n in _ap.get_animation_list():
		_opt_clip.add_item(String(n))
	_opt_clip.item_selected.connect(func(i: int) -> void: _elegir_clip(_opt_clip.get_item_text(i)))
	caja.add_child(_opt_clip)

	_sl_vel = _slider(caja, "velocidad", 0.0, 2.0, 1.0, "vel")
	_sl_vel.value_changed.connect(func(v: float) -> void:
		if not _ocupado and not _chk_pausa.button_pressed:
			_ap.speed_scale = v
		_etiqueta("vel", v))
	_sl_tiempo = _slider(caja, "fotograma", 0.0, 1.0, 0.0, "t")
	_sl_tiempo.value_changed.connect(func(v: float) -> void:
		if _ocupado or _ap.current_animation == "":
			return
		_chk_pausa.button_pressed = true
		_ap.seek(v * _ap.current_animation_length, true)
		_etiqueta("t", v))

	_chk_pausa = CheckBox.new()
	_chk_pausa.text = "Pausa (Espacio)"
	_chk_pausa.toggled.connect(func(p: bool) -> void: _ap.speed_scale = 0.0 if p else _sl_vel.value)
	caja.add_child(_chk_pausa)
	_chk_esq = CheckBox.new()
	_chk_esq.text = "Ver esqueleto (S)"
	_chk_esq.button_pressed = true
	caja.add_child(_chk_esq)
	_chk_clip = CheckBox.new()
	_chk_clip.text = "Solo este clip (si no, vale para todos)"
	_chk_clip.toggled.connect(func(_p: bool) -> void:
		if _sel != "":
			_elegir_hueso(_sel))
	caja.add_child(_chk_clip)

	caja.add_child(_titulo("Hueso (clic en la lista) + giro fijo en grados"))
	_lista = ItemList.new()
	_lista.custom_minimum_size = Vector2(0.0, 170.0)
	for b in range(_sk.get_bone_count()):
		var nombre: String = _sk.get_bone_name(b)
		var prof: int = 0
		var p: int = _sk.get_bone_parent(b)
		while p >= 0:
			prof += 1
			p = _sk.get_bone_parent(p)
		_lista.add_item("  ".repeat(mini(prof, 8)) + nombre)
		_lista.set_item_metadata(b, nombre)
	_lista.item_selected.connect(func(i: int) -> void: _elegir_hueso(String(_lista.get_item_metadata(i))))
	caja.add_child(_lista)
	for i in range(3):
		var eje: String = ["X", "Y", "Z"][i]
		var s2: HSlider = _slider(caja, "giro " + eje, -90.0, 90.0, 0.0, "g" + str(i))
		s2.step = 0.5
		_sl_giro.append(s2)
		var idx: int = i
		s2.value_changed.connect(func(v: float) -> void:
			_etiqueta("g" + str(idx), v)
			if _ocupado or _sel == "":
				return
			var d: Dictionary = _dic_giro(true)
			var gv: Vector3 = d.get(_sel, Vector3.ZERO)
			gv[idx] = v
			if gv == Vector3.ZERO:
				d.erase(_sel)
			else:
				d[_sel] = gv
			_aplicar()
			_refrescar_texto())
	var fila := HBoxContainer.new()
	caja.add_child(fila)
	var b_rest := Button.new()
	b_rest.text = "Reiniciar hueso"
	b_rest.pressed.connect(func() -> void:
		if _sel != "":
			_giro_todos.erase(_sel)
			for c in _giro_clip.keys():
				(_giro_clip[c] as Dictionary).erase(_sel)
			_elegir_hueso(_sel)
			_aplicar()
			_refrescar_texto())
	fila.add_child(b_rest)
	var b_todo := Button.new()
	b_todo.text = "Reiniciar todo"
	b_todo.pressed.connect(func() -> void:
		_giro_todos.clear()
		_giro_clip.clear()
		if _sel != "":
			_elegir_hueso(_sel)
		_aplicar()
		_refrescar_texto())
	fila.add_child(b_todo)

	caja.add_child(_titulo("Resultado (se actualiza solo)"))
	_txt = TextEdit.new()
	_txt.editable = false
	_txt.custom_minimum_size = Vector2(0.0, 110.0)
	caja.add_child(_txt)
	var b_cop := Button.new()
	b_cop.text = "Copiar resultado al portapapeles"
	b_cop.pressed.connect(func() -> void: DisplayServer.clipboard_set(_txt.text))
	caja.add_child(b_cop)

	var ayuda := Label.new()
	ayuda.text = "1 lateral · 2 frente · 3 arriba · 4 3/4 · rueda zoom · arrastrar orbita"
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
	l.custom_minimum_size = Vector2(90.0, 0.0)
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
	_lbl[clave] = v
	return s


func _etiqueta(clave: String, v: float) -> void:
	var l: Label = _lbl.get(clave, null)
	if l != null:
		l.text = "%.2f" % v


## Diccionario donde se guarda el giro según la casilla «solo este clip» (crea el del clip si hace falta).
func _dic_giro(crear: bool) -> Dictionary:
	if _chk_clip != null and _chk_clip.button_pressed:
		if crear and not _giro_clip.has(_clip):
			_giro_clip[_clip] = {}
		return _giro_clip.get(_clip, {})
	return _giro_todos


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
	if _sel != "":
		_elegir_hueso(_sel)
	_refrescar_texto()


## Guarda las claves originales de rotación del clip, una sola vez: las del recurso se reescriben en cada cambio de slider.
func _guardar_originales(clip: String) -> void:
	if _orig.has(clip):
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
	_orig[clip] = d


func _giro_efectivo(clip: String, hueso: String) -> Vector3:
	var g: Vector3 = _giro_todos.get(hueso, Vector3.ZERO)
	if _giro_clip.has(clip):
		g += (_giro_clip[clip] as Dictionary).get(hueso, Vector3.ZERO)
	return g


## Recalcula las claves del clip actual desde las originales: q = giro · q_original.
func _aplicar() -> void:
	if _clip == "" or not _orig.has(_clip):
		return
	var an: Animation = _ap.get_animation(_clip)
	var d: Dictionary = _orig[_clip]
	for t in d.keys():
		var hueso: String = str(an.track_get_path(t)).get_slice(":", 1)
		var gv: Vector3 = _giro_efectivo(_clip, hueso)
		var extra := Quaternion.IDENTITY
		if gv != Vector3.ZERO:
			extra = Quaternion.from_euler(Vector3(deg_to_rad(gv.x), deg_to_rad(gv.y), deg_to_rad(gv.z)))
		var qs: Array = d[t]
		for i in range(qs.size()):
			an.track_set_key_value(t, i, extra * (qs[i] as Quaternion))


## Los clips que no se están viendo conservan el giro de la última vez que se mostraron; al cambiar de clip se recalculan solos
## en `_elegir_clip` (que llama a `_aplicar`), así que no hace falta tocarlos aquí.

func _elegir_hueso(nombre: String) -> void:
	_sel = nombre
	var gv: Vector3 = _dic_giro(false).get(nombre, Vector3.ZERO)
	_ocupado = true
	for i in range(3):
		_sl_giro[i].value = gv[i]
		_etiqueta("g" + str(i), gv[i])
	_ocupado = false


func _refrescar_texto() -> void:
	if _txt == null:
		return
	var s: String = "clip visto: %s\n" % _clip
	if _giro_todos.is_empty():
		s += "giros para todos los clips: ninguno"
	else:
		s += "giros para todos los clips (grados X, Y, Z):"
		for h in _giro_todos.keys():
			var g: Vector3 = _giro_todos[h]
			s += "\n  %s: %.1f, %.1f, %.1f" % [h, g.x, g.y, g.z]
	for c in _giro_clip.keys():
		var dd: Dictionary = _giro_clip[c]
		if dd.is_empty():
			continue
		s += "\nsolo en %s:" % c
		for h in dd.keys():
			var g2: Vector3 = dd[h]
			s += "\n  %s: %.1f, %.1f, %.1f" % [h, g2.x, g2.y, g2.z]
	_txt.text = s


# ---------- cámara y dibujo ----------

func _process(_d: float) -> void:
	if _ap != null and _ap.current_animation != "" and not _chk_pausa.button_pressed:
		_ocupado = true
		_sl_tiempo.value = _ap.current_animation_position / maxf(_ap.current_animation_length, 0.001)
		_etiqueta("t", _sl_tiempo.value)
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
	if _chk_esq == null or not _chk_esq.button_pressed:
		return
	_im.surface_begin(Mesh.PRIMITIVE_LINES)
	for b in range(_sk.get_bone_count()):
		var p: int = _sk.get_bone_parent(b)
		if p < 0:
			continue
		var col: Color = COLOR_SEL if _sk.get_bone_name(b) == _sel else COLOR_RESTO
		var a: Vector3 = _sk.global_transform * _sk.get_bone_global_pose(p).origin
		var c: Vector3 = _sk.global_transform * _sk.get_bone_global_pose(b).origin
		_im.surface_set_color(col)
		_im.surface_add_vertex(a)
		_im.surface_set_color(col)
		_im.surface_add_vertex(c)
	_im.surface_end()


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_yaw -= ev.relative.x * 0.01
		_pitch = clampf(_pitch + ev.relative.y * 0.01, -0.2, 1.5)
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(_dist * 0.9, 1.0)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(_dist * 1.1, 10.0)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
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
