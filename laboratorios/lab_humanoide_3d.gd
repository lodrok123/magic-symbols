extends Node3D

## LABORATORIO ESTÁNDAR DE HUMANOIDES (11/10, Pablo: «un laboratorio estándar para los personajes: uno para humanoides y otro para animales»).
## Sale de LabGrandmaster3D y de LabGato3D, pero sirve para cualquier personaje con esqueleto Mixamo (todos los humanoides del juego:
## elfa, goblins, alquimista, librero, guardabosques, grandmaster...). Solo el personaje en bucle y un panel para tocar su animación en vivo:
##  · Elegir personaje y clip; velocidad; pausar y arrastrar el fotograma.
##  · FACTOR DE ZANCADA por grupo (piernas / brazos / resto del cuerpo) y por clip: 1 = el clip tal cual lo exportó Meshy, 0 = la postura
##    media del ciclo (sin movimiento), >1 = más amplio. Es la cuenta de Pj3D._acortar_paso() del gato (media.slerp(original, factor)).
##    Los grupos se deducen del esqueleto: lo que cuelga de un UpLeg es «piernas», de un Shoulder «brazos», lo demás «resto».
##  · Un giro fijo X/Y/Z por hueso (q = giro · q_clip) para todos los clips o solo el visto: es la corrección de postura de siempre.
##  · MEDIDOR DE PATINAJE: mide en vivo a qué velocidad se mueven los pies mientras están apoyados y lo compara con la velocidad a la que
##    el juego mueve al personaje (presets: patrulla 1,0 · andar 1,6 · perseguir 2,4 · correr 3,0). Si el suelo va más rápido que el pie, patina.
##    «Ajustar velocidad» pone la velocidad del clip para que coincidan.
## No modifica ningún archivo: el panel escribe los números; pásaselos a Claude (van a Pj3D.CORRECCION_POSTURA / futuros factores).
##
## Teclas: 1 lateral · 2 frente · 3 desde arriba · 4 3/4 · Espacio pausa · S esqueleto · rueda = zoom · arrastrar = orbitar
## Abrir: poc_25d/LabHumanoide3D.tscn y F6 (o LabGrandmaster3D.tscn, que arranca con el grandmaster).

## Personajes humanoides y su alto en el juego (igual que ALTO_PJ de prueba_test2.gd, para que las velocidades sean las del juego).
const PERSONAJES: Dictionary = {
	"chibi_elf": 1.0, "alchemist_elf": 0.95, "bookseller_chibi": 0.95, "goblin_warrior_chibi": 0.85, "goblin_archer_chibi": 0.85,
	"ranger_human": 1.1, "grandmaster": 1.0, "woodland_wanderer": 1.0, "woodland_wanderer_v1": 1.0, "woodland_wanderer_orig": 1.0}
const COLOR_PIERNAS: Color = Color(0.35, 1.0, 0.45)
const COLOR_BRAZOS: Color = Color(0.35, 0.65, 1.0)
const COLOR_RESTO: Color = Color(0.95, 0.95, 0.95)
const COLOR_SEL: Color = Color(1.0, 0.85, 0.1)
const GRUPOS: Array = [["piernas", "piernas"], ["brazos", "brazos"], ["resto", "resto del cuerpo"]]
const PRESETS_SUELO: Array = [["patrulla 1,0", 1.0], ["andar 1,6", 1.6], ["perseguir 2,4", 2.4], ["correr 3,0", 3.0]]
const VENTANA_S: float = 1.6       ## segundos de muestras de pies que usa el medidor

@export var personaje_inicial: String = "chibi_elf"

var _id: String = ""
var _modelo: Node3D = null
var _sk: Skeleton3D = null
var _ap: AnimationPlayer = null
var _cam: Camera3D = null
var _im: ImmediateMesh = null
var _alto: float = 1.0

var _yaw: float = 0.0
var _pitch: float = 0.15
var _dist: float = 3.2
var _foco: Vector3 = Vector3(0.0, 0.5, 0.0)

var _clip: String = ""
var _orig: Dictionary = {}          ## "id|clip" -> {pista: Array[Quaternion]} claves ORIGINALES del GLB (nunca se pierden)
var _grupo_hueso: Dictionary = {}   ## hueso -> "piernas" | "brazos" | "resto" (del personaje actual)
var _est: Dictionary = {}           ## id -> {"todos": {hueso: Vector3}, "clip": {clip: {hueso: Vector3}}, "fac": {clip: {grupo: float}}}
var _sel: String = ""
var _pies: Array[int] = []          ## índices de huesos de los pies (ToeBase; si no hay, Foot) para el medidor
var _muestras: Array = []           ## [{t, y: [..], p: [Vector2..]}] de la ventana del medidor
var _t_real: float = 0.0
var _t_medida: float = 0.0
var _vel_pie: float = 0.0           ## u/s con el clip a la velocidad actual
var _vel_pie_1: float = 0.0         ## u/s con el clip a velocidad 1

var _lista: ItemList = null
var _sl_giro: Array[HSlider] = []
var _lbl: Dictionary = {}
var _sl_fac: Dictionary = {}
var _sl_vel: HSlider = null
var _sl_suelo: HSlider = null
var _sl_tiempo: HSlider = null
var _lbl_medida: Label = null
var _chk_esq: CheckBox = null
var _chk_pausa: CheckBox = null
var _chk_clip: CheckBox = null
var _txt: TextEdit = null
var _opt_clip: OptionButton = null
var _opt_pj: OptionButton = null
var _ocupado: bool = false
## Comparación (12/10): un segundo personaje al lado, con el mismo clip y el mismo fotograma, solo para mirar (no se edita).
var _id2: String = ""
var _modelo2: Node3D = null
var _ap2: AnimationPlayer = null
var _opt_cmp: OptionButton = null


func _ready() -> void:
	_montar_escena()
	_montar_interfaz()
	_elegir_personaje(personaje_inicial if PERSONAJES.has(personaje_inicial) else "chibi_elf")
	_camara_preset(0)


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


## Carga el GLB del personaje, lo escala a su alto del juego y le pone los pies en y = 0 (como Pj3D._apoyar_en_el_suelo).
func _elegir_personaje(id: String) -> void:
	if _modelo != null:
		_modelo.queue_free()
		_modelo = null
	_id = id
	_alto = float(PERSONAJES[id])
	var ruta: String = "res://arte/modelos/%s.glb" % Pj3D.glb_de(id)   # glb_de: igual que el juego (woodland_wanderer = la versión suavizada)
	if not ResourceLoader.exists(ruta):
		push_warning("LabHumanoide3D: falta " + ruta)
		return
	_modelo = (load(ruta) as PackedScene).instantiate() as Node3D
	add_child(_modelo)
	var sks: Array[Node] = _modelo.find_children("*", "Skeleton3D", true, false)
	var aps: Array[Node] = _modelo.find_children("*", "AnimationPlayer", true, false)
	if sks.is_empty() or aps.is_empty():
		push_warning("LabHumanoide3D: el GLB no trae esqueleto o animaciones")
		return
	_sk = sks[0] as Skeleton3D
	_ap = aps[0] as AnimationPlayer
	for n in _ap.get_animation_list():
		_ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	var caja := AABB()
	var primera: bool = true
	for m in _modelo.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m as MeshInstance3D
		var a: AABB = (_modelo.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		caja = a if primera else caja.merge(a)
		primera = false
	if not primera and caja.size.y > 0.0001:
		var k: float = _alto / caja.size.y
		_modelo.scale = Vector3.ONE * k
		_modelo.position = Vector3(-(caja.position.x + caja.size.x * 0.5) * k, -caja.position.y * k, -(caja.position.z + caja.size.z * 0.5) * k)
	_foco = Vector3(0.0, _alto * 0.5, 0.0)
	_dist = _alto * 2.6 + 0.8
	_deducir_grupos()
	_buscar_pies()
	if not _est.has(id):
		_est[id] = {"todos": {}, "clip": {}, "fac": {}}
		# Arranca con la corrección que ya está en el juego, para seguir ajustando desde ahí.
		if Pj3D.CORRECCION_POSTURA.has(id):
			var gs: Dictionary = Pj3D.CORRECCION_POSTURA[id]
			for h in gs.keys():
				(_est[id]["todos"] as Dictionary)[h] = gs[h]
	_sel = ""
	_ocupado = true
	_sl_vel.value = 1.0
	_etiqueta("vel", 1.0)
	_ocupado = false
	_reiniciar_medida()
	_rellenar_interfaz_personaje()
	var inicial: String = "walking" if _ap.has_animation("walking") else ("Walking" if _ap.has_animation("Walking") else String(_ap.get_animation_list()[0]))
	_elegir_clip(inicial)


## Piernas = todo lo que cuelga de un UpLeg; brazos = todo lo que cuelga de un Shoulder; el resto, «resto». Vale para huesos extra
## (túnica, capa, armas) que cuelgan de esos huesos.
func _deducir_grupos() -> void:
	_grupo_hueso.clear()
	for b in range(_sk.get_bone_count()):
		var g: String = "resto"
		var p: int = b
		while p >= 0:
			var n: String = _sk.get_bone_name(p)
			if n.ends_with("UpLeg"):
				g = "piernas"
				break
			if n.ends_with("Shoulder"):
				g = "brazos"
				break
			p = _sk.get_bone_parent(p)
		_grupo_hueso[_sk.get_bone_name(b)] = g


func _buscar_pies() -> void:
	_pies.clear()
	for n in ["mixamorig_LeftToeBase", "mixamorig_RightToeBase"]:
		var i: int = _sk.find_bone(n)
		if i >= 0:
			_pies.append(i)
	if _pies.is_empty():
		for n in ["mixamorig_LeftFoot", "mixamorig_RightFoot"]:
			var i: int = _sk.find_bone(n)
			if i >= 0:
				_pies.append(i)


func _montar_interfaz() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)
	# El panel ocupa el alto de la ventana (menos la línea de ayuda) y lleva barra de desplazamiento propia.
	var panel := PanelContainer.new()
	panel.anchor_bottom = 1.0
	panel.offset_left = 8.0
	panel.offset_top = 8.0
	panel.offset_right = 376.0
	panel.offset_bottom = -34.0
	capa.add_child(panel)
	var desplazable := ScrollContainer.new()
	desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(desplazable)
	var caja := VBoxContainer.new()
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desplazable.add_child(caja)

	var t := Label.new()
	t.text = "LAB HUMANOIDES (no modifica archivos)"
	caja.add_child(t)
	_opt_pj = OptionButton.new()
	for id in PERSONAJES.keys():
		_opt_pj.add_item(String(id))
	_opt_pj.item_selected.connect(func(i: int) -> void: _elegir_personaje(_opt_pj.get_item_text(i)))
	caja.add_child(_opt_pj)
	var l_cmp := Label.new()
	l_cmp.text = "Comparar con (a la derecha, mismo clip y fotograma):"
	caja.add_child(l_cmp)
	_opt_cmp = OptionButton.new()
	_opt_cmp.add_item("(ninguno)")
	for id2 in PERSONAJES.keys():
		_opt_cmp.add_item(String(id2))
	_opt_cmp.item_selected.connect(func(i: int) -> void: _elegir_comparacion("" if i == 0 else _opt_cmp.get_item_text(i)))
	caja.add_child(_opt_cmp)
	_opt_clip = OptionButton.new()
	_opt_clip.item_selected.connect(func(i: int) -> void: _elegir_clip(_opt_clip.get_item_text(i)))
	caja.add_child(_opt_clip)

	_sl_vel = _slider(caja, "velocidad clip", 0.1, 3.0, 1.0, "vel")
	_sl_vel.value_changed.connect(func(v: float) -> void:
		if not _ocupado and not _chk_pausa.button_pressed and _ap != null:
			_ap.speed_scale = v
		_etiqueta("vel", v)
		_reiniciar_medida()
		_refrescar_texto())
	_sl_tiempo = _slider(caja, "fotograma", 0.0, 1.0, 0.0, "t")
	_sl_tiempo.value_changed.connect(func(v: float) -> void:
		if _ocupado or _ap == null or _ap.current_animation == "":
			return
		_chk_pausa.button_pressed = true
		_ap.seek(v * _ap.current_animation_length, true)
		_etiqueta("t", v))

	_chk_pausa = CheckBox.new()
	_chk_pausa.text = "Pausa (Espacio)"
	_chk_pausa.toggled.connect(func(p: bool) -> void:
		if _ap != null:
			_ap.speed_scale = 0.0 if p else _sl_vel.value
		_reiniciar_medida())
	caja.add_child(_chk_pausa)
	_chk_esq = CheckBox.new()
	_chk_esq.text = "Ver esqueleto (S): verde piernas · azul brazos"
	_chk_esq.button_pressed = true
	caja.add_child(_chk_esq)

	caja.add_child(_titulo("Factor de zancada de ESTE clip (1 = original, 0 = quieto)"))
	for g in GRUPOS:
		var clave: String = g[0]
		var s: HSlider = _slider(caja, g[1], 0.0, 1.5, 1.0, "f_" + clave)
		_sl_fac[clave] = s
		s.value_changed.connect(func(v: float) -> void:
			_etiqueta("f_" + clave, v)
			if _ocupado or _clip == "":
				return
			var fc: Dictionary = _est[_id]["fac"]
			if not fc.has(_clip):
				fc[_clip] = {}
			if is_equal_approx(v, 1.0):
				(fc[_clip] as Dictionary).erase(clave)
			else:
				(fc[_clip] as Dictionary)[clave] = v
			_aplicar()
			_reiniciar_medida()
			_refrescar_texto())

	caja.add_child(_titulo("Patinaje: velocidad del suelo en el juego (u/s)"))
	_sl_suelo = _slider(caja, "suelo", 0.2, 4.0, 1.6, "suelo")
	_sl_suelo.value_changed.connect(func(v: float) -> void:
		_etiqueta("suelo", v)
		_refrescar_medida())
	var fila_p := HBoxContainer.new()
	caja.add_child(fila_p)
	for pr in PRESETS_SUELO:
		var b := Button.new()
		b.text = String(pr[0])
		var val: float = float(pr[1])
		b.pressed.connect(func() -> void: _sl_suelo.value = val)
		fila_p.add_child(b)
	_lbl_medida = Label.new()
	_lbl_medida.text = "midiendo..."
	_lbl_medida.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_medida.custom_minimum_size = Vector2(340.0, 0.0)
	caja.add_child(_lbl_medida)
	var b_aj := Button.new()
	b_aj.text = "Ajustar velocidad del clip al suelo"
	b_aj.pressed.connect(_ajustar_velocidad)
	caja.add_child(b_aj)

	_chk_clip = CheckBox.new()
	_chk_clip.text = "Giros: solo este clip (si no, valen para todos)"
	_chk_clip.toggled.connect(func(_p: bool) -> void:
		if _sel != "":
			_elegir_hueso(_sel))
	caja.add_child(_chk_clip)
	caja.add_child(_titulo("Hueso (clic en la lista) + giro fijo en grados"))
	_lista = ItemList.new()
	_lista.custom_minimum_size = Vector2(0.0, 170.0)
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
			_reiniciar_medida()
			_refrescar_texto())
	var fila := HBoxContainer.new()
	caja.add_child(fila)
	var b_rest := Button.new()
	b_rest.text = "Reiniciar hueso"
	b_rest.pressed.connect(func() -> void:
		if _sel != "":
			(_est[_id]["todos"] as Dictionary).erase(_sel)
			for c in (_est[_id]["clip"] as Dictionary).keys():
				((_est[_id]["clip"] as Dictionary)[c] as Dictionary).erase(_sel)
			_elegir_hueso(_sel)
			_aplicar()
			_refrescar_texto())
	fila.add_child(b_rest)
	var b_todo := Button.new()
	b_todo.text = "Reiniciar todo (este personaje)"
	b_todo.pressed.connect(func() -> void:
		_est[_id] = {"todos": {}, "clip": {}, "fac": {}}
		for c in _ap.get_animation_list():
			_orig.erase(_id + "|" + String(c))   # no hace falta: las originales se conservan; se recalcula desde ellas
		_elegir_clip(_clip)
		if _sel != "":
			_elegir_hueso(_sel))
	fila.add_child(b_todo)

	caja.add_child(_titulo("Resultado (se actualiza solo)"))
	_txt = TextEdit.new()
	_txt.editable = false
	_txt.custom_minimum_size = Vector2(0.0, 150.0)
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


func _rellenar_interfaz_personaje() -> void:
	for i in range(_opt_pj.item_count):
		if _opt_pj.get_item_text(i) == _id:
			_opt_pj.select(i)
	_opt_clip.clear()
	for n in _ap.get_animation_list():
		_opt_clip.add_item(String(n))
	_lista.clear()
	for b in range(_sk.get_bone_count()):
		var nombre: String = _sk.get_bone_name(b)
		var prof: int = 0
		var p: int = _sk.get_bone_parent(b)
		while p >= 0:
			prof += 1
			p = _sk.get_bone_parent(p)
		var corto: String = nombre.replace("mixamorig_", "")
		_lista.add_item("  ".repeat(mini(prof, 8)) + corto)
		_lista.set_item_metadata(b, nombre)


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
	_lbl[clave] = v
	return s


func _etiqueta(clave: String, v: float) -> void:
	var l: Label = _lbl.get(clave, null)
	if l != null:
		l.text = "%.2f" % v


func _dic_giro(crear: bool) -> Dictionary:
	if _chk_clip != null and _chk_clip.button_pressed:
		var dc: Dictionary = _est[_id]["clip"]
		if crear and not dc.has(_clip):
			dc[_clip] = {}
		return dc.get(_clip, {})
	return _est[_id]["todos"]


# ---------- comparación ----------

func _elegir_comparacion(id2: String) -> void:
	if _modelo2 != null:
		_modelo2.queue_free()
		_modelo2 = null
		_ap2 = null
	_id2 = id2
	if id2 == "":
		_foco.x = 0.0
		return
	var ruta: String = "res://arte/modelos/%s.glb" % Pj3D.glb_de(id2)
	if not ResourceLoader.exists(ruta):
		push_warning("LabHumanoide3D: falta " + ruta)
		return
	_modelo2 = (load(ruta) as PackedScene).instantiate() as Node3D
	add_child(_modelo2)
	var aps: Array[Node] = _modelo2.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		_ap2 = aps[0] as AnimationPlayer
		for n in _ap2.get_animation_list():
			_ap2.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	var alto2: float = float(PERSONAJES[id2])
	var caja := AABB()
	var primera: bool = true
	for m in _modelo2.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m as MeshInstance3D
		var a: AABB = (_modelo2.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		caja = a if primera else caja.merge(a)
		primera = false
	var sep: float = 0.9 * maxf(_alto, alto2)
	if not primera and caja.size.y > 0.0001:
		var k: float = alto2 / caja.size.y
		_modelo2.scale = Vector3.ONE * k
		_modelo2.position = Vector3(sep - (caja.position.x + caja.size.x * 0.5) * k, -caja.position.y * k, -(caja.position.z + caja.size.z * 0.5) * k)
	_foco.x = sep * 0.5
	_dist = maxf(_alto, alto2) * 3.2 + 0.8
	_poner_clip_comparacion()


## Pone en el segundo personaje el mismo clip (por nombre exacto; si no lo tiene, el primero que contenga el mismo texto).
func _poner_clip_comparacion() -> void:
	if _ap2 == null or _clip == "":
		return
	var nombre: String = ""
	if _ap2.has_animation(_clip):
		nombre = _clip
	else:
		for n in _ap2.get_animation_list():
			if String(n).to_lower().contains(_clip.to_lower()) or _clip.to_lower().contains(String(n).to_lower()):
				nombre = String(n)
				break
	if nombre == "":
		_ap2.stop()
		return
	_ap2.play(nombre)
	_ap2.speed_scale = 0.0          # no corre solo: lo lleva _process al mismo punto que el principal


# ---------- animación ----------

func _elegir_clip(nombre: String) -> void:
	if _ap == null:
		return
	_clip = nombre
	for i in range(_opt_clip.item_count):
		if _opt_clip.get_item_text(i) == nombre:
			_opt_clip.select(i)
	_guardar_originales(nombre)
	_ap.play(nombre)
	_ocupado = true
	var fc: Dictionary = (_est[_id]["fac"] as Dictionary).get(nombre, {})
	for g in GRUPOS:
		var v: float = float(fc.get(g[0], 1.0))
		(_sl_fac[g[0]] as HSlider).value = v
		_etiqueta("f_" + String(g[0]), v)
	_ocupado = false
	_ap.speed_scale = 0.0 if _chk_pausa.button_pressed else _sl_vel.value
	_aplicar()
	_reiniciar_medida()
	_poner_clip_comparacion()
	if _sel != "":
		_elegir_hueso(_sel)
	_refrescar_texto()


## Guarda las claves originales de rotación del clip una sola vez: las del recurso se reescriben en cada cambio.
func _guardar_originales(clip: String) -> void:
	var llave: String = _id + "|" + clip
	if _orig.has(llave):
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
	_orig[llave] = d


func _giro_efectivo(clip: String, hueso: String) -> Vector3:
	var g: Vector3 = (_est[_id]["todos"] as Dictionary).get(hueso, Vector3.ZERO)
	var dc: Dictionary = _est[_id]["clip"]
	if dc.has(clip):
		g += (dc[clip] as Dictionary).get(hueso, Vector3.ZERO)
	return g


## Recalcula las claves del clip actual desde las originales: q = giro · media.slerp(q_original, factor del grupo).
func _aplicar() -> void:
	var llave: String = _id + "|" + _clip
	if _clip == "" or not _orig.has(llave):
		return
	var an: Animation = _ap.get_animation(_clip)
	var d: Dictionary = _orig[llave]
	var fc: Dictionary = (_est[_id]["fac"] as Dictionary).get(_clip, {})
	for t in d.keys():
		var hueso: String = str(an.track_get_path(t)).get_slice(":", 1)
		var gv: Vector3 = _giro_efectivo(_clip, hueso)
		var extra := Quaternion.IDENTITY
		if gv != Vector3.ZERO:
			extra = Quaternion.from_euler(Vector3(deg_to_rad(gv.x), deg_to_rad(gv.y), deg_to_rad(gv.z)))
		var qs: Array = d[t]
		var k: float = float(fc.get(_grupo_hueso.get(hueso, "resto"), 1.0))
		var media: Quaternion = Quaternion.IDENTITY
		if k != 1.0 and qs.size() > 1:
			var q0: Quaternion = qs[0]
			var suma := Vector4.ZERO
			for q in qs:
				var qq: Quaternion = q
				if qq.dot(q0) < 0.0:
					qq = Quaternion(-qq.x, -qq.y, -qq.z, -qq.w)      # mismo giro en el otro hemisferio: para promediar bien
				suma += Vector4(qq.x, qq.y, qq.z, qq.w)
			media = Quaternion(suma.x, suma.y, suma.z, suma.w).normalized()
		for i in range(qs.size()):
			var q2: Quaternion = qs[i]
			if k != 1.0 and qs.size() > 1:
				q2 = media.slerp(q2, k)
			an.track_set_key_value(t, i, extra * q2)


func _elegir_hueso(nombre: String) -> void:
	_sel = nombre
	var gv: Vector3 = _dic_giro(false).get(nombre, Vector3.ZERO)
	_ocupado = true
	for i in range(3):
		_sl_giro[i].value = gv[i]
		_etiqueta("g" + str(i), gv[i])
	_ocupado = false


# ---------- medidor de patinaje ----------

## Cada fotograma (con el clip en marcha) anota la altura y la posición horizontal de los pies. Cada medio segundo calcula la
## velocidad horizontal media de los pies mientras están apoyados (en el 30 % más bajo de su recorrido vertical).
func _medir(delta: float) -> void:
	if _pies.is_empty() or _ap == null or _ap.speed_scale <= 0.0001:
		return
	_t_real += delta
	var ys: Array = []
	var ps: Array = []
	for i in _pies:
		var pos: Vector3 = _sk.global_transform * _sk.get_bone_global_pose(i).origin
		ys.append(pos.y)
		ps.append(Vector2(pos.x, pos.z))
	_muestras.append({"t": _t_real, "y": ys, "p": ps})
	while _muestras.size() > 2 and float((_muestras[0] as Dictionary)["t"]) < _t_real - VENTANA_S:
		_muestras.pop_front()
	if _t_real - _t_medida < 0.5:
		return
	_t_medida = _t_real
	var ciclo_real: float = _ap.current_animation_length / maxf(_ap.speed_scale, 0.001)
	if _muestras.size() < 10 or float((_muestras[-1] as Dictionary)["t"]) - float((_muestras[0] as Dictionary)["t"]) < ciclo_real * 0.98:
		_vel_pie = 0.0          # aún no hay un ciclo entero de muestras
		_refrescar_medida()
		return
	var tot: float = 0.0
	var tt: float = 0.0
	for k in range(_pies.size()):
		var ymin: float = 1e9
		var ymax: float = -1e9
		for m in _muestras:
			var y: float = float((m["y"] as Array)[k])
			ymin = minf(ymin, y)
			ymax = maxf(ymax, y)
		var lim: float = ymin + 0.3 * (ymax - ymin)
		for j in range(_muestras.size() - 1):
			var a: Dictionary = _muestras[j]
			var b: Dictionary = _muestras[j + 1]
			if float((a["y"] as Array)[k]) < lim and float((b["y"] as Array)[k]) < lim:
				var dt: float = float(b["t"]) - float(a["t"])
				if dt > 0.0:
					tot += ((b["p"] as Array)[k] - (a["p"] as Array)[k]).length()
					tt += dt
	_vel_pie = tot / tt if tt > 0.0 else 0.0
	_vel_pie_1 = _vel_pie / maxf(_ap.speed_scale, 0.001)
	_refrescar_medida()


func _reiniciar_medida() -> void:
	_muestras.clear()
	_vel_pie = 0.0
	_vel_pie_1 = 0.0
	_t_medida = _t_real
	_refrescar_medida()


func _refrescar_medida() -> void:
	if _lbl_medida == null:
		return
	if _vel_pie <= 0.0:
		_lbl_medida.text = "Pies: sin medida (el clip tiene que estar en marcha; espera un ciclo). No tiene sentido en idle ni en hechizos."
		return
	var suelo: float = _sl_suelo.value
	var r: float = suelo / _vel_pie
	var veredicto: String = "sin patinaje apreciable"
	if r > 1.15:
		veredicto = "PATINA: el suelo va %.1f× más rápido que los pies" % r
	elif r < 0.87:
		veredicto = "los pies van %.1f× más rápido que el suelo (pisa de más)" % (1.0 / r)
	_lbl_medida.text = "Pies apoyados: %.2f u/s (a velocidad 1: %.2f) · suelo: %.2f u/s → %s." % [_vel_pie, _vel_pie_1, suelo, veredicto]


func _ajustar_velocidad() -> void:
	if _vel_pie_1 <= 0.0:
		return
	_sl_vel.value = clampf(_sl_suelo.value / _vel_pie_1, _sl_vel.min_value, _sl_vel.max_value)
	_reiniciar_medida()


func _refrescar_texto() -> void:
	if _txt == null or _est.is_empty():
		return
	var s: String = "personaje: %s · clip visto: %s · velocidad del clip: %.2f\n" % [_id, _clip, _sl_vel.value]
	for id in _est.keys():
		var e: Dictionary = _est[id]
		var parte: String = ""
		var todos: Dictionary = e["todos"]
		if not todos.is_empty():
			parte += "  giros para todos los clips (grados X, Y, Z):\n"
			for h in todos.keys():
				var g: Vector3 = todos[h]
				parte += "    %s: %.1f, %.1f, %.1f\n" % [h, g.x, g.y, g.z]
		for c in (e["clip"] as Dictionary).keys():
			var dd: Dictionary = e["clip"][c]
			if dd.is_empty():
				continue
			parte += "  giros solo en %s:\n" % c
			for h in dd.keys():
				var g2: Vector3 = dd[h]
				parte += "    %s: %.1f, %.1f, %.1f\n" % [h, g2.x, g2.y, g2.z]
		for c in (e["fac"] as Dictionary).keys():
			var ff: Dictionary = e["fac"][c]
			if ff.is_empty():
				continue
			parte += "  factor de zancada en %s:" % c
			for g3 in ff.keys():
				parte += " %s=%.2f" % [g3, float(ff[g3])]
			parte += "\n"
		if parte != "":
			s += "[%s]\n%s" % [id, parte]
	if _vel_pie > 0.0:
		s += "medida: pies %.2f u/s (a vel. 1: %.2f) vs suelo %.2f u/s\n" % [_vel_pie, _vel_pie_1, _sl_suelo.value]
	_txt.text = s


# ---------- cámara y dibujo ----------

func _process(delta: float) -> void:
	if _ap == null:
		return
	if _ap.current_animation != "" and not _chk_pausa.button_pressed:
		_ocupado = true
		_sl_tiempo.value = _ap.current_animation_position / maxf(_ap.current_animation_length, 0.001)
		_etiqueta("t", _sl_tiempo.value)
		_ocupado = false
	if _ap2 != null and _ap2.current_animation != "":
		var d1: float = _ap.current_animation_length
		var d2: float = _ap2.current_animation_length
		_ap2.seek(fposmod(_ap.current_animation_position / maxf(d1, 0.001), 1.0) * d2, true)
	_medir(delta)
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
	if _chk_esq == null or not _chk_esq.button_pressed or _sk == null:
		return
	_im.surface_begin(Mesh.PRIMITIVE_LINES)
	for b in range(_sk.get_bone_count()):
		var p: int = _sk.get_bone_parent(b)
		if p < 0:
			continue
		var nombre: String = _sk.get_bone_name(b)
		var col: Color = COLOR_RESTO
		match String(_grupo_hueso.get(nombre, "resto")):
			"piernas":
				col = COLOR_PIERNAS
			"brazos":
				col = COLOR_BRAZOS
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
