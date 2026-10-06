extends Node3D

## LABORATORIO DE EFECTOS 3D (estética pastel). Un claro de hierba con la elfa en el centro y una fila de
## objetivos (dummy, seto, tótem, tronco, goblin). Cada tecla lanza un elemento con Vfx3D (vfx_3d.gd)
## al objetivo marcado. Sirve para ajustar los efectos mirándolos con la misma cámara que el juego.
##
## Teclas: 1 fuego · 2 agua · 3 tierra · 4 viento · 5 rayo · 6 hielo · Espacio repetir
##         Tab / flechas: cambiar objetivo · B bucle (todos seguidos) · T cámara lenta
##         X tamaño de los efectos · V velocidad del proyectil · C cámara (juego / baja / lateral)
##         + / - zoom · G hierba · L luces de los efectos

## Las mismas bibliotecas que la maqueta (PruebaTest2): primero las regeneradas sueltas de meshy/piezas/.
const BIBLIOTECAS: Array = ["res://poc_25d/meshy/arboles_2.glb", "res://poc_25d/meshy/mercado.glb",
	"res://poc_25d/meshy/bosque.glb", "res://poc_25d/meshy/objetos.glb", "res://poc_25d/meshy/magia.glb"]
const CARPETA_PIEZAS: String = "res://poc_25d/meshy/piezas/"
## Segundos del aviso "Preparando efectos" al abrir: mientras, se lanza cada elemento una vez para que Godot
## compile sus shaders (sin esto, el primer hechizo de cada elemento da un tirón).
const PRECALENTAR: float = 1.6
const SUELO: String = "res://poc_25d/suelo_meshy/"
const OBJETIVOS: Array = [["dummy", 1.4], ["arbusto_otono", 0.8], ["totem_runico", 1.8], ["tronco", 0.7],
	["goblin", 0.85]]
const LANZADOR: Array = ["chibi_elf_v2", "chibi_elf", "chibi_test"]
const CAMARAS: Array = [["juego", 20.0], ["baja", 45.0], ["lateral", 72.0]]
const ESCALAS: Array = [1.3, 1.8, 0.9]
const VELOCIDADES: Array = [7.0, 3.5, 12.0]

var _fx: Vfx3D = null
var _lanzador: Pj3D = null
var _objetivos: Array[Node3D] = []
var _marcador: MeshInstance3D = null
var _sel: int = 2
var _ultimo: String = "fuego"
var _i_forma: int = 0
var _bucle: bool = false
var _t_bucle: float = 0.0
var _i_bucle: int = 0
var _lenta: bool = false
var _i_escala: int = 0
var _i_vel: int = 0
var _i_cam: int = 0
var _zoom: float = 9.0
var _camara: Camera3D = null
var _hierba: Hierba3D = null
var _hud: Label = null
var _bibliotecas: Array[Node3D] = []
var _grimorio: GrimorioUI = null
var _velo: Control = null
var _t_velo: float = 0.0
var _f_velo: int = 0


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.81, 0.91, 0.94)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.95, 0.94, 1.0)
	env.ambient_light_energy = 0.42
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sol.light_color = Color(1.0, 0.96, 0.88)
	sol.light_energy = 0.78
	sol.shadow_enabled = true
	add_child(sol)

	_suelo()
	_cargar_bibliotecas()
	_poner_objetivos()
	for b in _bibliotecas:
		b.free()
	_bibliotecas.clear()

	_lanzador = Pj3D.new()
	add_child(_lanzador)
	for id in LANZADOR:
		if ResourceLoader.exists("res://poc_25d/%s.glb" % id) and _lanzador.cargar(String(id)):
			break
	_lanzador.set_alto(1.0)
	_lanzador.rotation.y = PI * 0.5

	_fx = Vfx3D.new()
	_fx.escala = float(ESCALAS[0])
	add_child(_fx)
	_fx.impacto.connect(_al_impactar)

	_marcador = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.2, 1.2)
	q.orientation = PlaneMesh.FACE_Y
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = load("res://poc_25d/vfx/circulo_runico.png") as Texture2D
	m.albedo_color = Color(1, 1, 1, 0.55)
	q.material = m
	_marcador.mesh = q
	add_child(_marcador)

	_camara = Camera3D.new()
	_camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camara.far = 200.0
	add_child(_camara)
	_colocar_camara()

	_grimorio = GrimorioUI.new()
	add_child(_grimorio)
	_grimorio.abierto_cambiado.connect(_al_abrir_grimorio)

	var capa := CanvasLayer.new()
	add_child(capa)
	_hud = Label.new()
	_hud.position = Vector2(12.0, 8.0)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 6)
	capa.add_child(_hud)
	_actualizar_hud()
	_precalentar(capa)


## Tapa la pantalla un momento y lanza los seis elementos a la vez: compila shaders y carga texturas ya.
func _precalentar(capa: CanvasLayer) -> void:
	if _objetivos.is_empty():
		return
	var velo := ColorRect.new()
	velo.color = Color(0.81, 0.91, 0.94)
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var aviso := Label.new()
	aviso.text = "Preparando efectos..."
	aviso.position = Vector2(24.0, 24.0)
	aviso.add_theme_color_override("font_color", Color(0.25, 0.35, 0.4))
	velo.add_child(aviso)
	capa.add_child(velo)
	var o: Vector3 = _objetivos[_sel].position
	_fx.precalentar(_lanzador.position, o, true)
	_velo = velo
	_t_velo = 0.0
	_f_velo = 0


## --- Escenario ---

## Un claro de 14 x 10 con la textura de hierba, una plazoleta de piedra bajo la elfa y una charca.
func _suelo() -> void:
	var caja := BoxMesh.new()
	caja.size = Vector3(16.0, 1.0, 11.0)
	var mi := MeshInstance3D.new()
	mi.mesh = caja
	mi.position = Vector3(3.0, -0.5, 0.0)
	mi.material_override = _triplanar("hierba_arriba.png", Color(0.6, 0.8, 0.5))
	add_child(mi)
	var plaza := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 1.3
	cil.bottom_radius = 1.3
	cil.height = 0.04
	plaza.mesh = cil
	plaza.position = Vector3(0.0, 0.0, 0.0)
	plaza.material_override = _triplanar("stone_arriba.png", Color(0.8, 0.8, 0.85))
	add_child(plaza)
	var charca := MeshInstance3D.new()
	var pq := QuadMesh.new()
	pq.size = Vector2(3.0, 2.0)
	pq.orientation = PlaneMesh.FACE_Y
	charca.mesh = pq
	charca.position = Vector3(7.5, 0.02, 2.6)
	charca.material_override = _triplanar("water_arriba.png", Color(0.6, 0.85, 0.9))
	add_child(charca)
	_hierba = Hierba3D.new()
	add_child(_hierba)
	_hierba.sembrar(Rect2(-5.0, -5.5, 16.0, 11.0), 0.0, _peso_hierba)


func _peso_hierba(x: float, z: float) -> float:
	var d_plaza: float = Vector2(x, z).length()
	if d_plaza < 1.5:
		return clampf((d_plaza - 1.3) / 0.2, 0.0, 1.0) * 0.6
	if x > 5.8 and x < 9.2 and z > 2.2 and z < 4.6:
		return 0.0
	# Calva alrededor de los objetivos para ver bien el suelo de los impactos.
	for o in _objetivos:
		if Vector2(x - o.position.x, z - o.position.z).length() < 0.9:
			return 0.35
	return 1.0


func _triplanar(archivo: String, si_falta: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.roughness = 1.0
	m.metallic_specular = 0.0
	var ruta: String = SUELO + archivo
	if ResourceLoader.exists(ruta):
		m.albedo_texture = load(ruta) as Texture2D
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE / 4.6
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	else:
		m.albedo_color = si_falta
	return m


func _cargar_bibliotecas() -> void:
	for ruta in _piezas_sueltas() + BIBLIOTECAS:
		var r: String = String(ruta)
		if ResourceLoader.exists(r):
			_bibliotecas.append((load(r) as PackedScene).instantiate() as Node3D)


## Las regeneradas de meshy/piezas/ (como PruebaTest2, pero sin cargar su script: arrastraba todo el juego).
func _piezas_sueltas() -> Array:
	var res: Array = []
	if DirAccess.dir_exists_absolute(CARPETA_PIEZAS):
		for f in DirAccess.get_files_at(CARPETA_PIEZAS):
			var nombre: String = String(f).trim_suffix(".import").trim_suffix(".remap")
			if nombre.get_extension().to_lower() == "glb" and not res.has(CARPETA_PIEZAS + nombre):
				res.append(CARPETA_PIEZAS + nombre)
	return res


func _pieza(id: String, alto: float) -> Node3D:
	for b in _bibliotecas:
		var n: Node = b.find_child(id, true, false)
		if n is Node3D:
			var copia: Node3D = (n as Node3D).duplicate() as Node3D
			copia.transform = Transform3D.IDENTITY
			var caja: AABB = _caja(copia, Transform3D.IDENTITY)
			var raiz := Node3D.new()
			raiz.add_child(copia)
			var f: float = alto / maxf(caja.size.y, 0.0001)
			copia.scale *= f
			copia.position = -Vector3(caja.position.x + caja.size.x * 0.5, caja.position.y, caja.position.z + caja.size.z * 0.5) * f
			return raiz
	return null


func _caja(n: Node, acum: Transform3D) -> AABB:
	var t: Transform3D = acum
	if n is Node3D:
		t = acum * (n as Node3D).transform
	var res := AABB()
	var vacia: bool = true
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		res = t * (n as MeshInstance3D).mesh.get_aabb()
		vacia = false
	for h in n.get_children():
		var sub: AABB = _caja(h, t)
		if sub.size != Vector3.ZERO:
			res = sub if vacia else res.merge(sub)
			vacia = false
	return res


## Los objetivos en columna delante de la elfa.
func _poner_objetivos() -> void:
	for i in range(OBJETIVOS.size()):
		var id: String = String(OBJETIVOS[i][0])
		var alto: float = float(OBJETIVOS[i][1])
		# En columna a 4 unidades, separados 1,7: cada objetivo tiene su carril limpio.
		var pos := Vector3(4.0, 0.0, (float(i) - float(OBJETIVOS.size() - 1) * 0.5) * 1.7)
		var n: Node3D = null
		if id == "goblin":
			for g in ["goblin_warrior_chibi", "goblin_warrior"]:
				if ResourceLoader.exists("res://poc_25d/%s.glb" % g):
					var pj := Pj3D.new()
					add_child(pj)
					pj.cargar(String(g))
					pj.set_alto(alto)
					n = pj
					break
		else:
			n = _pieza(id, alto)
			if n != null:
				add_child(n)
		if n == null:
			continue
		n.position = pos
		# El goblin mira a la elfa; el resto de piezas, de frente a la cámara.
		n.rotation.y = atan2(-pos.x, -pos.z) if id == "goblin" else 0.0
		n.name = id
		_objetivos.append(n)


## --- Hechizos ---

func _lanzar(elemento: String) -> void:
	if _objetivos.is_empty():
		return
	_ultimo = elemento
	var o: Node3D = _objetivos[_sel]
	var d: Vector3 = o.position - _lanzador.position
	_lanzador.rotation.y = atan2(d.x, d.z)
	var forma: String = String(Vfx3D.FORMAS[_i_forma])
	_lanzador.lanzar(forma, elemento)
	get_tree().create_timer(1.2, false).timeout.connect(_lanzador.soltar_lanzar)
	var pie_destino: Vector3 = o.position - d.normalized() * 0.35
	var pie_origen: Vector3 = _lanzador.position + d.normalized() * 0.3
	match forma:
		"corro", "columna":
			_fx.lanzar_forma(forma, elemento, pie_origen, o.position)
		"muro":
			# Sale 1,5 u por delante de la elfa y avanza hacia el objetivo.
			_fx.lanzar_forma(forma, elemento, pie_origen, _lanzador.position + d.normalized() * 1.5)
		_:
			_fx.lanzar(elemento, pie_origen, pie_destino)
	_actualizar_hud()


func _al_impactar(_elemento: String, _punto: Vector3) -> void:
	var o: Node3D = _objetivos[_sel]
	if o is Pj3D:
		(o as Pj3D).jugar("hit")
		get_tree().create_timer(0.8, false).timeout.connect((o as Pj3D).jugar.bind("idle"))
	else:
		# La escala de reposo se guarda la primera vez: si llega otro impacto en mitad del rebote, no se
		# toma la escala aplastada como base (el objetivo se iba deformando con Espacio o el bucle).
		if not o.has_meta("escala_base"):
			o.set_meta("escala_base", o.scale)
		var base: Vector3 = o.get_meta("escala_base")
		var tw := o.create_tween()
		tw.tween_property(o, "scale", base * Vector3(1.12, 0.88, 1.12), 0.06)
		tw.tween_property(o, "scale", base, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Abre el grimorio con un estilo y un libro dados (para pruebas y capturas). `muestra` = huecos llenos.
func abrir_grimorio(datos: Vector3i) -> void:
	_grimorio.set_estilo(datos.x)
	_grimorio.set_distribucion(datos.y)
	if datos.z == 1:
		_grimorio._llenos = true
	if not _grimorio.abierto:
		_grimorio.alternar()


## Con el grimorio abierto la elfa lee y escribe (a velocidad normal aunque el mundo vaya a cámara lenta).
func _al_abrir_grimorio(abierto: bool) -> void:
	if abierto:
		_lanzador.jugar("leer")
		_lanzador.set_velocidad_animacion(1.0 / maxf(GrimorioUI.TIEMPO_ABIERTO, 0.01))
	else:
		_lanzador.set_velocidad_animacion(1.0)
		_lanzador.jugar("idle")


## Para pruebas y capturas: lanza la forma `v.x` (índice de Vfx3D.FORMAS) del elemento `v.y` sin esperar al velo.
func probar(v: Vector2i) -> void:
	if _velo != null:
		_velo.queue_free()
		_velo = null
	_i_forma = v.x
	_lanzar(String(Vfx3D.ELEMENTOS[v.y]))


## Activa o para el bucle de todos los elementos (también con la tecla B).
func set_bucle(activo: bool) -> void:
	_bucle = activo
	_t_bucle = 1.6
	_actualizar_hud()


## --- Cámara, entrada y HUD ---

func _colocar_camara() -> void:
	var incl: float = float(CAMARAS[_i_cam][1])
	var e: float = deg_to_rad(90.0 - incl)
	var dir: Vector3 = -Vector3(0.0, sin(e), cos(e))
	var foco := Vector3(2.0, 0.5, 0.0)
	_camara.size = _zoom
	_camara.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), foco - dir * 40.0)


func _process(delta: float) -> void:
	if _velo != null:
		# Por fotogramas y por tiempo (el primer fotograma tras cargar trae un delta enorme).
		_f_velo += 1
		_t_velo += minf(delta, 0.05)
		if _f_velo > 10 and _t_velo >= PRECALENTAR:
			_velo.queue_free()
			_velo = null
	if _bucle:
		_t_bucle += delta
		if _t_bucle > 1.6:
			_t_bucle = 0.0
			_i_forma = (_i_bucle / Vfx3D.ELEMENTOS.size()) % Vfx3D.FORMAS.size()
			_lanzar(String(Vfx3D.ELEMENTOS[_i_bucle % Vfx3D.ELEMENTOS.size()]))
			_i_bucle += 1
	if not _objetivos.is_empty():
		_marcador.position = _objetivos[_sel].position + Vector3(0.0, 0.03, 0.0)
		_marcador.rotate_y(delta * 0.8)


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey):
		return
	var k: InputEventKey = ev as InputEventKey
	if not k.pressed or k.echo or (_grimorio != null and _grimorio.abierto):
		return
	match k.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			_lanzar(String(Vfx3D.ELEMENTOS[k.keycode - KEY_1]))
		KEY_SPACE:
			_lanzar(_ultimo)
		KEY_TAB, KEY_RIGHT, KEY_DOWN:
			_sel = (_sel + 1) % maxi(1, _objetivos.size())
		KEY_LEFT, KEY_UP:
			_sel = (_sel - 1 + _objetivos.size()) % maxi(1, _objetivos.size())
		KEY_F:
			_i_forma = (_i_forma + 1) % Vfx3D.FORMAS.size()
		KEY_B:
			_bucle = not _bucle
			_t_bucle = 1.6
		KEY_M:
			_lenta = not _lenta
			Engine.time_scale = 0.25 if _lenta else 1.0
		KEY_X:
			_i_escala = (_i_escala + 1) % ESCALAS.size()
			_fx.escala = float(ESCALAS[_i_escala])
		KEY_V:
			_i_vel = (_i_vel + 1) % VELOCIDADES.size()
			_fx.velocidad = float(VELOCIDADES[_i_vel])
		KEY_C:
			_i_cam = (_i_cam + 1) % CAMARAS.size()
			_colocar_camara()
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			_zoom = maxf(2.0, _zoom * 0.85)
			_colocar_camara()
		KEY_MINUS, KEY_KP_SUBTRACT:
			_zoom = minf(30.0, _zoom / 0.85)
			_colocar_camara()
		KEY_G:
			_hierba.visible = not _hierba.visible
		KEY_L:
			_fx.con_luces = not _fx.con_luces
		KEY_N:
			set_nivel_grimorio(Equipo3D.nivel_grimorio % 3 + 1)
	_actualizar_hud()


## Grimorio 1 botánico · 2 rúnico · 3 legendario: el de la cadera y el estilo de página del grimorio abierto.
func set_nivel_grimorio(n: int) -> void:
	if _lanzador != null:
		_lanzador.set_nivel_grimorio(n)
	if _grimorio != null:
		_grimorio.set_estilo(Equipo3D.nivel_grimorio - 1)   # botánico, astral, acuarela


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _actualizar_hud() -> void:
	if _hud == null:
		return
	var objetivo: String = String(_objetivos[_sel].name) if not _objetivos.is_empty() else "-"
	_hud.text = "LAB DE EFECTOS 3D | objetivo: %s | último: %s (%s) | tamaño x%.1f | proyectil %.1f u/s | cámara %s%s%s%s\n1 fuego · 2 agua · 3 tierra · 4 viento · 5 rayo · 6 hielo · Espacio repetir · F forma (proyectil/corro/columna/muro) · Tab/flechas objetivo\nB bucle (24 celdas) · M cámara lenta · T grimorio · X tamaño · V velocidad · C cámara · +/- zoom · G hierba · L luces · N grimorio (%s)" % [
		objetivo, _ultimo, String(Vfx3D.FORMAS[_i_forma]), _fx.escala, _fx.velocidad, String(CAMARAS[_i_cam][0]),
		" | BUCLE" if _bucle else "", " | LENTA" if _lenta else "", "" if _fx.con_luces else " | sin luces",
		Equipo3D.NIVELES_GRIMORIO[Equipo3D.nivel_grimorio]]
