extends SceneTree
## V6 de docs/PLAN_EOW_VISUAL.md (21/10, Pipeline + Juego): MATERIAL COMÚN CON «QUEMADO» Y «DISOLVER POR CELDAS» (presentacion/ocluso_3d.gd).
## Sin ventana: godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_quemado_disolver.gd
## OJO: en headless no hay GPU, así que el shader NO se compila ni se dibuja aquí. Esto comprueba el CABLEADO (qué uniform se mueve y cuándo, y que la
## lógica no cambia); que el shader compila y se ve bien lo comprueba herramientas/captura_v6.gd CON VENTANA.
## Lo que comprueba:
##   1. El material de un seto es el común (ShaderMaterial de Ocluso3D) con `quemado` y `disolver` a 0 y el código de la oclusión del jugador intacto.
##   2. Mientras arde, `quemado` SUBE de 0 hacia 1 siguiendo los segundos de combustión; la pieza no se aplasta y `disolver` sigue en 0.
##   3. Al consumirse, `disolver` va de 0 a 1 en T_DISOLVER s (la pieza sigue ahí, sin aplastarse, con la colisión ya quitada) y solo entonces se libera.
##   4. Apagar con agua a medias devuelve `quemado` a 0 (vuelve a sano) y no deja `disolver`.
##   5. Con `Ocluso3D.usar_quemado_disolver = false` vuelve el comportamiento anterior: tinte uniforme y aplastarse, sin tocar los uniforms.
##   6. El escudo quemado se desintegra con `disolver` de 0 a 1 en T_DESINTEGRA s (sin encoger) y con el interruptor apagado encoge como antes.

class MundoFalso extends Node3D:
	const S: float = 2.3
	const ALTO: float = 2.3 * 0.45
	var _lado: int = 20
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	var _goblins: Array = []
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])

const S: float = 2.3
const DT: float = 1.0 / 60.0   ## los cuadros de física van a 60 Hz aunque --fixed-fps sea 30
var _mundo: MundoFalso = null
var _fx: Vfx3D = null
var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	Ocluso3D.preparar()
	_crear_mundo()
	await _arder_y_consumirse()
	await _apagar_a_medias()
	await _interruptor_apagado()
	await _escudo()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _crear_mundo() -> void:
	var filas: PackedStringArray = []
	for y in range(20):
		var f: String = ""
		for x in range(20):
			f += "#" if (x == 0 or y == 0 or x == 19 or y == 19) else "."
		filas.append(f)
	_mundo = MundoFalso.new()
	_mundo._mapa = filas
	root.add_child(_mundo)
	Lanzador3D.configurar(_mundo)
	for y in range(20):
		for x in range(20):
			if filas[y][x] == "#":
				_mundo._bloqueadas[Vector2i(x, y)] = true
	_fx = Vfx3D.new()
	root.add_child(_fx)


## Un seto con un visual de una caja verde con material estándar (como los de Meshy), que `Reactivo3D` convierte al común.
func _seto(tipo: String = "seto", cx: float = 5.0, cz: float = 5.0) -> Reactivo3D:
	var r := Reactivo3D.new()
	var vis := Node3D.new()
	var mi := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(1.2, 1.3, 1.2)
	mi.mesh = caja
	mi.position = Vector3(0.0, 0.65, 0.0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.6, 0.25)
	mi.material_override = null
	mi.set_surface_override_material(0, m)
	vis.add_child(mi)
	r.add_child(vis)
	r.preparar(tipo, Vector2i(int(cx), int(cz)), "", _fx, vis)
	r.position = Vector3((cx + 0.5) * S, MundoFalso.ALTO, (cz + 0.5) * S)
	_mundo.add_child(r)
	return r


func _material(r: Reactivo3D) -> Material:
	var mi: MeshInstance3D = r.visual.get_child(0) as MeshInstance3D
	return mi.get_surface_override_material(0)


func _esperar(seg: float) -> void:
	for _i in range(int(round(seg / DT))):
		await physics_frame


func _arder_y_consumirse() -> void:
	Ocluso3D.usar_quemado_disolver = true
	var r: Reactivo3D = _seto()
	await process_frame
	var mat: Material = _material(r)
	_ok("1. el seto usa el material común", Ocluso3D.es_comun(mat), str(mat))
	var codigo: String = (mat as ShaderMaterial).shader.code if mat is ShaderMaterial else ""
	_ok("1. la oclusión del jugador sigue en el shader", codigo.contains("oc_jugador.w > 0.0 && !IN_SHADOW_PASS") and codigo.contains("discard"))
	_ok("1. quemado y disolver parten de 0", Ocluso3D.quemado_de(mat) == 0.0 and Ocluso3D.disolver_de(mat) == 0.0)
	var dur: float = float(r._num_combustible()[0])
	var escala0: Vector3 = r.scale
	r.ignite()
	_ok("2. prende", r.estado == Reactivo3D.EstadoObj.ARDIENDO)
	var muestras: Array = []
	for k in range(3):
		await _esperar(dur * 0.25)
		muestras.append(Ocluso3D.quemado_de(mat))
	print("      quemado a 25/50/75 %% de la combustión: ", muestras)
	_ok("2. quemado SUBE mientras arde", float(muestras[0]) > 0.1 and float(muestras[1]) > float(muestras[0]) and float(muestras[2]) > float(muestras[1]))
	_ok("2. sigue a los segundos de combustión", absf(float(muestras[1]) - 0.5) < 0.12, "50%% -> %.2f" % float(muestras[1]))
	_ok("2. no se aplasta ni se disuelve mientras arde", r.scale.is_equal_approx(escala0) and Ocluso3D.disolver_de(mat) == 0.0)
	# Hasta consumirse.
	var tope: int = 0
	while r.estado != Reactivo3D.EstadoObj.CONSUMIDO and tope < 400:
		await physics_frame
		tope += 1
	_ok("3. se consume", r.estado == Reactivo3D.EstadoObj.CONSUMIDO)
	_ok("3. colisión ya quitada (lógica igual que antes)", r.collision_layer == 0)
	_ok("3. quemado llegó a 1", Ocluso3D.quemado_de(mat) > 0.99, str(Ocluso3D.quemado_de(mat)))
	var vals: Array = []
	var cuadros: int = 0
	while is_instance_valid(r) and cuadros < 60:
		await physics_frame
		cuadros += 1
		if is_instance_valid(r):
			vals.append(Ocluso3D.disolver_de(mat))
	var seg: float = cuadros * DT
	print("      disolver (cada 3 cuadros): ", vals.filter(func(v: float) -> bool: return true).slice(0, 20, 3))
	var crece: bool = true
	for i in range(1, vals.size()):
		if float(vals[i]) < float(vals[i - 1]) - 0.0001:
			crece = false
	_ok("3. disolver crece de 0 a ~1 sin saltos atrás", crece and vals.size() > 3 and float(vals[0]) < 0.4 and float(vals[vals.size() - 1]) > 0.7, "primero %.2f ultimo %.2f" % [float(vals[0]), float(vals[vals.size() - 1])])
	_ok("3. se libera pasados T_DISOLVER s (como antes pasados 0,5)", not is_instance_valid(r) and absf(seg - Reactivo3D.T_DISOLVER) < 0.15, "%.2f s" % seg)


func _apagar_a_medias() -> void:
	var r: Reactivo3D = _seto("seto", 8.0, 5.0)
	await process_frame
	var mat: Material = _material(r)
	r.ignite()
	await _esperar(float(r._num_combustible()[0]) * 0.4)
	var antes: float = Ocluso3D.quemado_de(mat)
	r._apagar()
	await _esperar(Reactivo3D.FUNDIDO + 0.2)
	_ok("4. apagado: vuelve a sano", antes > 0.2 and Ocluso3D.quemado_de(mat) < 0.01 and Ocluso3D.disolver_de(mat) == 0.0, "de %.2f a %.2f" % [antes, Ocluso3D.quemado_de(mat)])
	_ok("4. apagado: la pieza sigue sana y en pie", r.estado == Reactivo3D.EstadoObj.SANO and is_instance_valid(r))
	r.queue_free()


func _interruptor_apagado() -> void:
	Ocluso3D.usar_quemado_disolver = false
	var r: Reactivo3D = _seto("seto", 11.0, 5.0)
	await process_frame
	var mat: Material = _material(r)
	var c0: Color = Ocluso3D.color_de(mat)
	r.ignite()
	await _esperar(0.9)
	_ok("5. interruptor apagado: tinte uniforme y uniforms quietos", Ocluso3D.color_de(mat).v < c0.v - 0.05 and Ocluso3D.quemado_de(mat) == 0.0,
		"v %.2f -> %.2f" % [c0.v, Ocluso3D.color_de(mat).v])
	r._consumir()
	await _esperar(0.42)   # TRANS_BACK + EASE_IN primero sube un poco: se mira cerca del final
	_ok("5. interruptor apagado: se aplasta y no disuelve", (not is_instance_valid(r) or r.scale.y < 0.8) and Ocluso3D.disolver_de(mat) == 0.0, "escala.y %.2f" % (r.scale.y if is_instance_valid(r) else 0.0))
	await _esperar(0.3)
	Ocluso3D.usar_quemado_disolver = true


func _escudo() -> void:
	var filas: PackedStringArray = []
	var bloq: Dictionary = {}
	for y in range(10):
		var f: String = ""
		for x in range(10):
			if x == 0 or y == 0 or x == 9 or y == 9:
				f += "#"
				bloq[Vector2i(x, y)] = true
			else:
				f += "."
		filas.append(f)
	Terreno3D.alturas.clear()
	Terreno3D.permanentes.clear()
	Terreno3D.cargar_datos(filas, bloq)
	Terreno3D.activar_fuente_casillas()
	var mundo := Mundo3D.new()
	root.add_child(mundo)
	var jug := Jugador3D.new()
	jug.position = Vector3(1.5 * S, Terreno3D.alto_suelo, 8.5 * S)
	jug.pj = Pj3D.new()
	mundo.add_child(jug.pj)
	for interruptor in [true, false]:
		Ocluso3D.usar_quemado_disolver = interruptor
		var p := Vector3((4 + 0.5) * S, Terreno3D.y_pies(Vector2i(4, 4)), (4 + 0.5) * S)
		var modelo := Pj3D.new()
		modelo.id = "goblin_warrior"
		modelo.position = p
		mundo.add_child(modelo)
		var g: Combate3D = Combate3D.equipar(modelo, mundo, jug, null)
		g.set_physics_process(false)
		g.altura = 0.85
		g.quieto = true
		g.position = p
		g.mirada = Vector3(0, 0, 1)
		g.health = 100000.0
		g.vida_max = 100000.0
		var e: Escudo3D = Escudo3D.equipar(g)
		await process_frame
		var etq: String = "6. escudo (disolver %s)" % ("ON" if interruptor else "OFF")
		_ok(etq + ": la malla quemada usa el material común", not e._mats_quemado.is_empty(), "%d materiales" % e._mats_quemado.size())
		var esc0: Vector3 = e._quemado.scale
		e.prender()
		e._consumir("quemado")
		var muestras: Array = []
		var cuadros: int = 0
		while e.desintegra_t > 0.0 and cuadros < 60:
			await physics_frame
			cuadros += 1
			muestras.append([e.desintegra_t, e.disolver, e._quemado.scale.x / esc0.x])
		var seg: float = cuadros * DT
		if interruptor:
			var ult: Array = muestras[muestras.size() - 1]
			var mitad: Array = muestras[muestras.size() / 2]
			print("      escudo a mitad: disolver %.2f escala %.2f · al final: disolver %.2f" % [float(mitad[1]), float(mitad[2]), float(ult[1])])
			_ok(etq + ": disolver sube de 0 a 1 y no encoge", float(mitad[1]) > 0.3 and float(mitad[1]) < 0.7 and absf(float(mitad[2]) - 1.0) < 0.001 and float(ult[1]) > 0.95)
			_ok(etq + ": el material recibe el valor", Ocluso3D.disolver_de(e._mats_quemado[0]) > 0.95)
		else:
			var mitad2: Array = muestras[muestras.size() / 2]
			_ok(etq + ": encoge como antes y no toca disolver", float(mitad2[2]) < 0.8 and Ocluso3D.disolver_de(e._mats_quemado[0]) == 0.0, "escala a mitad %.2f" % float(mitad2[2]))
		_ok(etq + ": dura T_DESINTEGRA s y luego se oculta", absf(seg - Escudo3D.T_DESINTEGRA) < 0.15 and not e._quemado.visible, "%.2f s" % seg)
		modelo.queue_free()
	Ocluso3D.usar_quemado_disolver = true
