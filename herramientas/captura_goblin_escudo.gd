extends SceneTree
## CAPTURAS del escudo del goblin, su mano quemada y las burbujas del hundimiento (22/10). NECESITA VENTANA (no sirve --headless).
##   godot --path . --fixed-fps 30 --script res://herramientas/captura_goblin_escudo.gd -- <carpeta> [tomas separadas por coma]
## Tomas: brazo (escudo en el brazo: idle, andar y atacar, vistas de frente y tres cuartos) · mojado (seco / mojado / secándose / seco) · disolver (hoja de fotogramas
## del escudo quemado deshaciéndose) · mano (la mano quemada: clip y chispas) · burbujas (hoja del hundimiento sobre un «agua» translúcida).
## Todo sobre un suelo plano en un rincón vacío del Bosque 01 (modelo: captura_empujado_goblin.gd).
const ID: String = "goblin_warrior_chibi"
const CENTRO: Vector3 = Vector3(300.0, 0.0, 300.0)
const RECORTE: Vector2i = Vector2i(420, 420)
const TOMAS_TODAS: Array = ["brazo", "mojado", "disolver", "mano", "burbujas"]
const DT: float = 1.0 / 30.0

var _mundo: Node3D = null
var _carpeta: String = "docs/capturas/goblin_escudo"
var _suelo: MeshInstance3D = null
var _fondo: MeshInstance3D = null
var _camara: Camera3D = null
var _modelo: Pj3D = null
var _g: Combate3D = null


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_carpeta = a[0]
	var tomas: Array = String(a[1]).split(",") if a.size() > 1 else TOMAS_TODAS
	DirAccess.make_dir_recursive_absolute(_carpeta)
	# Un mundo mínimo propio (no el Bosque 01: así no depende de la maqueta): terreno de prueba, Mundo3D, una luz y un cielo neutro.
	var filas: PackedStringArray = []
	var bloq: Dictionary = {}
	for y in range(10):
		var f: String = ""
		for x in range(10):
			f += "."
		filas.append(f)
	Terreno3D.alturas.clear()
	Terreno3D.permanentes.clear()
	Terreno3D.cargar_datos(filas, bloq)
	Terreno3D.activar_fuente_casillas()
	_mundo = Mundo3D.new()
	root.add_child(_mundo)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	sol.light_energy = 1.3
	_mundo.add_child(sol)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.68, 0.8)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.ambient_light_energy = 0.9
	we.environment = env
	_mundo.add_child(we)
	for _i in 10:
		await process_frame
	_suelo = _plano(Color(0.62, 0.5, 0.36))
	_fondo = _plano(Color(0.1, 0.12, 0.14))
	_fondo.visible = false
	_camara = Camera3D.new()
	_camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	_mundo.add_child(_camara)
	_camara.make_current()
	for t in tomas:
		match String(t):
			"brazo":
				await _t_brazo()
			"mojado":
				await _t_mojado()
			"disolver":
				await _t_disolver()
			"mano":
				await _t_mano()
			"burbujas":
				await _t_burbujas()
			"clip":
				await _t_clip()
	quit()


func _plano(color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30.0, 30.0)
	m.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	m.material_override = mat
	_mundo.add_child(m)
	m.global_position = CENTRO
	return m


## Un goblin guerrero con escudo, de verdad (Combate3D + Escudo3D), en el centro del suelo plano, mirando a +Z.
func _goblin(con_escudo: bool = true, fisica: bool = true) -> void:
	if _g != null and is_instance_valid(_g):
		_g.queue_free()
	if _modelo != null and is_instance_valid(_modelo):
		_modelo.queue_free()
	_modelo = Pj3D.new()
	_mundo.add_child(_modelo)
	_modelo.cargar(ID)
	_modelo.grafo = ArbolAnimPj.GRAFO_REDUCIDO
	_modelo.set_alto(0.85)
	_modelo.position = CENTRO
	_g = Combate3D.equipar(_modelo, _mundo, Jugador3D.new(), null)
	_g.altura = 0.85
	_g.quieto = true
	_g.position = CENTRO
	_g.casa = CENTRO
	_g.mirada = Vector3(0, 0, 1)
	_g.health = 100000.0
	_g.vida_max = 100000.0
	_modelo.mirar(Vector3(0, 0, 1), 1.0)
	if con_escudo:
		Escudo3D.equipar(_g)
	await _frames(4)
	_g.set_physics_process(fisica)
	var y: float = _g.global_position.y             # el goblin se apoya en la casilla fuera del mapa (~1 u): el suelo plano sube a sus pies
	_suelo.global_position.y = y
	_fondo.global_position.y = y - 3.0


## Cámara ortogonal en `desde` (relativo al suelo) mirando a `foco` (relativo al suelo), con tamaño `tam`.
func _cam(desde: Vector3, foco: Vector3, tam: float) -> void:
	_camara.size = tam
	var o: Vector3 = _suelo.global_position
	_camara.global_position = o + desde
	_camara.look_at(o + foco, Vector3.UP)


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _foto(nombre: String) -> Image:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	var lado: int = mini(img.get_height(), img.get_width())
	var rec: Image = img.get_region(Rect2i((img.get_width() - lado) / 2, (img.get_height() - lado) / 2, lado, lado))
	rec.resize(RECORTE.x, RECORTE.y, Image.INTERPOLATE_LANCZOS)
	if nombre != "":
		rec.save_png("%s/%s.png" % [_carpeta, nombre])
	return rec


func _hoja(imgs: Array, nombre: String, columnas: int = 3) -> void:
	var filas: int = int(ceil(float(imgs.size()) / float(columnas)))
	var hoja := Image.create(RECORTE.x * columnas, RECORTE.y * filas, false, (imgs[0] as Image).get_format())
	for i in range(imgs.size()):
		hoja.blit_rect(imgs[i] as Image, Rect2i(0, 0, RECORTE.x, RECORTE.y), Vector2i((i % columnas) * RECORTE.x, (i / columnas) * RECORTE.y))
	hoja.save_png("%s/%s.png" % [_carpeta, nombre])


func _agua() -> Hechizo:
	return Hechizo.construir(load("res://nucleo/water_rune.tres"), {})


func _fuego() -> Hechizo:
	return Hechizo.construir(load("res://nucleo/fire_rune.tres"), {})


## Escudo en el brazo: idle, andar y atacar (clips a mano, sin IA), de frente y de tres cuartos por los dos lados.
func _t_brazo() -> void:
	await _goblin(true, false)
	var imgs: Array = []
	var vistas: Array = [["frente", Vector3(0.0, 1.5, 2.4)], ["tc_izq", Vector3(1.8, 1.3, 1.8)], ["tc_der", Vector3(-1.8, 1.3, 1.8)]]
	for clip in ["idle", "walk", "attack"]:
		_modelo.animacion_actual = ""
		_modelo.jugar(clip)
		await _frames(18 if clip != "attack" else 9)
		for v in vistas:
			_cam(v[1], Vector3(0.0, 0.5, 0.0), 1.3)
			await _frames(1)
			imgs.append(await _foto("brazo_%s_%s" % [clip, v[0]]))
	print("escudo en brazo: ", _g.escudo.en_brazo, " pos ", _g.escudo.global_position, " equipo de adorno visible: ", _modelo.poner_equipo_visible("escudo", false))
	_hoja(imgs, "brazo")


## Seco, recién mojado, secándose (último segundo y medio) y seco otra vez.
func _t_mojado() -> void:
	await _goblin(true, false)
	var imgs: Array = []
	_cam(Vector3(0.0, 1.3, 2.4), Vector3(0.0, 0.5, 0.0), 1.2)
	await _frames(3)
	imgs.append(await _foto("mojado_1_seco"))
	_g.escudo.on_spell_hit(load("res://nucleo/water_rune.tres"), Vector3(0, 0, -1), _agua())
	await _frames(4)
	imgs.append(await _foto("mojado_2_mojado"))
	var t: float = 4.0 * DT
	for objetivo in [Escudo3D.T_MOJADO - 0.75, Escudo3D.T_MOJADO + 0.3]:      # a mitad del aclarado y ya seco
		await _frames(int((objetivo - t) / DT))
		t = objetivo
		imgs.append(await _foto("mojado_%d" % (imgs.size() + 1)))
	print("mojado visible al final: ", _g.escudo.se_ve_mojado(), " mojado_t ", _g.escudo.mojado_t)
	_hoja(imgs, "mojado", 4)


## El escudo ardiendo y, al consumirse, deshaciéndose por celdas.
func _t_disolver() -> void:
	await _goblin(true, true)
	var imgs: Array = []
	_g.escudo.prender()
	await _frames(8)
	_cam(Vector3(0.8, 1.2, 1.9), _g.escudo.global_position - _suelo.global_position, 0.9)
	await _frames(1)
	imgs.append(await _foto("disolver_0_ardiendo"))
	_g.escudo.arde_t = 0.02                         # que se consuma ya (en vez de esperar sus 3 s)
	var n: int = 0
	for paso in [2, 3, 3, 3, 3, 4]:
		await _frames(paso)
		n += paso
		_cam(Vector3(0.8, 1.2, 1.9), _g.escudo.global_position - _suelo.global_position, 0.9)
		await _frames(1)
		imgs.append(await _foto("disolver_%d" % imgs.size()))
		print("disolver: fotograma ", n, " desintegra_t ", snappedf(_g.escudo.desintegra_t, 0.01), " disolver ", snappedf(_g.escudo.disolver, 0.01))
	_hoja(imgs, "disolver", 4)


## La mano quemada: el clip y las chispas, desde el momento en que se consume el escudo.
func _t_mano() -> void:
	await _goblin(true, true)
	var imgs: Array = []
	_g.escudo.prender()
	await _frames(2)
	_g.escudo.arde_t = 0.02
	await _frames(1)
	var t: float = 0.0
	for seg in [0.05, 0.2, 0.4, 0.6, 0.9, 1.3]:
		await _frames(maxi(int((seg - t) / DT), 0))
		t = seg
		_cam(Vector3(0.9, 1.1, 1.8), Vector3(0.0, 0.5, 0.0), 1.0)
		await _frames(1)
		imgs.append(await _foto("mano_%d" % (imgs.size() + 1)))
		print("mano t=", seg, " anim ", _modelo.animacion_actual, " estado ", _modelo.estado_anim(), " stun ", snappedf(_g.stun_timer, 0.01))
	_hoja(imgs, "mano", 3)


## El hundimiento: un goblin que se hunde en un «agua» translúcida (y sin escudo, para no distraer), con burbujas y salpicadura sincronizadas.
func _t_burbujas() -> void:
	await _goblin(false, true)
	_g.mirada = Vector3(0, 0, 1)
	ReaccionesVfx3D.conectar(Mundo3D.actual if Mundo3D.actual != null else _mundo, _mundo)
	var mat: StandardMaterial3D = _suelo.material_override as StandardMaterial3D
	mat.albedo_color = Color(0.25, 0.5, 0.75, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fondo.visible = true
	_g.set_physics_process(false)
	_g._punto_hundido = Vector3(_g.global_position.x, _suelo.global_position.y, _g.global_position.z)
	var imgs: Array = []
	_cam(Vector3(0.0, 1.4, 2.8), Vector3(0.0, -0.1, 0.0), 1.8)
	await _frames(2)
	_g._morir(true)
	print("hundimiento: duración anunciada ", _g.duracion_hundimiento, " s")
	var t: float = 0.0
	var dur: float = _g.duracion_hundimiento
	for fr in [0.03, 0.2, 0.4, 0.6, 0.8, 0.92, 1.0, 1.2]:       # fracciones del hundimiento real (y una última, ya sin cuerpo)
		var seg: float = dur * float(fr)
		await _frames(maxi(int((seg - t) / DT), 0))
		t = seg
		imgs.append(await _foto("burbujas_%d" % (imgs.size() + 1)))
		print("burbujas: t=%.2f s (%.0f %% del hundimiento) goblin y=%.2f" % [seg, float(fr) * 100.0, _modelo.position.y - _suelo.global_position.y if is_instance_valid(_modelo) else NAN])
	_hoja(imgs, "burbujas", 4)


## El clip mano_quemada SIN escudo ni chispas, contra el idle en los mismos instantes (fila de arriba: idle; fila de abajo: mano quemada).
func _t_clip() -> void:
	await _goblin(false, false)
	var imgs_i: Array = []
	var imgs_m: Array = []
	var tiempos: Array = [0.0, 0.1, 0.2, 0.3, 0.5, 0.8, 1.1]
	for clip in ["idle", "mano_quemada"]:
		_modelo.animacion_actual = ""
		_modelo.jugar(clip, clip == "mano_quemada")
		await _frames(2)
		var t: float = 2.0 * DT
		for seg in tiempos:
			await _frames(maxi(int((float(seg) - t) / DT), 0))
			t = float(seg)
			_cam(Vector3(1.4, 1.1, 1.9), Vector3(0.0, 0.5, 0.0), 1.1)
			await _frames(1)
			(imgs_i if clip == "idle" else imgs_m).append(await _foto(""))
	_hoja(imgs_i + imgs_m, "clip_mano", tiempos.size())
