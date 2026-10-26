extends SceneTree
## Prueba (20/10, Juego; Pablo: «que las colisiones sean cercanas al modelo real y no a la cuadrícula del suelo»). Sin ventana: `--headless --fixed-fps 30`.
## Mide tres cosas de lo que bloquea o recibe el golpe:
##   1. Los goblins (Combate3D) chocan, como el jugador, contra la FORMA real de una casilla bloqueada «parcial» (su huella) y no contra la casilla entera;
##      sin forma conocida siguen bloqueados por la casilla.
##   2. La caja de acierto de un Reactivo3D se ajusta a su visual (antes: 0,9 casillas = 2,07 u para todo lo que no fuera uno de siete tipos) y solo se encoge.
##   3. Las excepciones (placa, puente, surtidor) conservan su caja de siempre.
##   4. (21/10) FuenteNodos: una forma ancha (el pino de 1,59) que solo ROZA una casilla vecina la deja `parcial` (el jugador choca con la forma)
##      pero NO bloqueada entera (hechizos, flechas, línea de visión, BFS); su propia casilla sí. `liberar` limpia las dos capas.
class MundoFalso extends Node3D:
	var _lado: int = 20
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	var _goblins: Array = []
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])

var _fallos: int = 0
var _mundo: MundoFalso = null


func _ok(c: bool, m: String) -> void:
	print(("OK    " if c else "FALLO ") + m)
	if not c:
		_fallos += 1


func _initialize() -> void:
	await process_frame
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
	_goblins_y_huellas()
	await _cajas_de_acierto()
	_f10()
	await _forma_ancha()
	print("RESULTADO colisiones_forma · FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _goblin() -> Combate3D:
	var j := Jugador3D.new()
	j.position = Vector3(18 * 2.3, 1.0, 18 * 2.3)
	var modelo := Pj3D.new()
	modelo.position = Vector3(8 * 2.3, 2.3 * 0.45, 10 * 2.3)
	_mundo.add_child(modelo)
	var g: Combate3D = Combate3D.equipar(modelo, _mundo, j, null)
	g.set_physics_process(false)
	g.altura = 0.85
	return g


func _goblins_y_huellas() -> void:
	var cas: float = Terreno3D.casilla
	var celda := Vector2i(10, 10)
	var centro: Vector3 = Terreno3D.centro_de(celda, 0.0)
	# Un barril de 0,4 de radio en el centro de la casilla (10, 10): bloquea la casilla pero su forma es un círculo.
	_mundo._bloqueadas[celda] = true
	Terreno3D.huellas.clear()
	Terreno3D.huellas[celda] = [Vector3(centro.x, centro.z, 0.4)]
	var g: Combate3D = _goblin()
	g.position = Vector3(centro.x - cas * 0.9, Terreno3D.y_pies(Vector2i(9, 10)), centro.z)      # en la casilla de al lado (9, 10)
	_ok(Terreno3D.es_parcial(celda), "la casilla del barril es «parcial» (se conoce su forma)")
	_ok(g._puede_estar(Vector3(centro.x - 1.0, Terreno3D.y_pies(celda), centro.z)), "el goblin entra en la casilla del barril si se queda fuera de su círculo (a 1,0 u del centro, círculo de 0,4): ANTES no podía")
	_ok(not g._puede_estar(Vector3(centro.x - 0.3, Terreno3D.y_pies(celda), centro.z)), "…pero no entra en el círculo del barril (a 0,3 u del centro)")
	_ok(not g._puede_estar(Vector3(centro.x, Terreno3D.y_pies(celda), centro.z)), "…ni en su centro")
	# Sin forma conocida (sin huella): la casilla entera sigue bloqueada, como antes.
	var otra := Vector2i(12, 12)
	_mundo._bloqueadas[otra] = true
	var c2: Vector3 = Terreno3D.centro_de(otra, 0.0)
	g.position = Vector3(c2.x - cas * 0.9, Terreno3D.y_pies(Vector2i(11, 12)), c2.z)
	_ok(not Terreno3D.es_parcial(otra) and not g._puede_estar(Vector3(c2.x - 1.0, Terreno3D.y_pies(otra), c2.z)), "una casilla bloqueada SIN forma conocida sigue bloqueando entera")
	# Estando ya dentro de la casilla del barril puede salir (no se queda atrapado).
	g.position = Vector3(centro.x - 0.3, Terreno3D.y_pies(celda), centro.z)
	_ok(g._puede_estar(Vector3(centro.x - 0.6, Terreno3D.y_pies(celda), centro.z)), "si ya está metido en el círculo, puede salir hacia fuera")
	Terreno3D.huellas.clear()
	_mundo._bloqueadas.erase(celda)
	_mundo._bloqueadas.erase(otra)


func _cuerpo(r: Reactivo3D) -> BoxShape3D:
	for h in r.get_children():
		if h is CollisionShape3D:
			return (h as CollisionShape3D).shape as BoxShape3D
	return null


func _reactivo(tipo: String, lado: float) -> Reactivo3D:
	var vis := Node3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(lado, lado, lado)
	mi.mesh = bm
	mi.position = Vector3(0.0, lado * 0.5, 0.0)
	vis.add_child(mi)
	var r := Reactivo3D.new()
	r.add_child(vis)
	r.preparar(tipo, Vector2i(5, 5), "", null, vis)
	_mundo.add_child(r)
	return r


func _cajas_de_acierto() -> void:
	var antes: float = Reactivo3D.S * 0.9
	var r1: Reactivo3D = _reactivo("seta", 0.6)
	var b1: BoxShape3D = _cuerpo(r1)
	_ok(b1 != null and b1.size.x < antes - 0.5 and b1.size.x >= Reactivo3D.MIN_CUERPO - 0.0001, "una seta de 0,6 u ya no tiene caja de 0,9 casillas (%.2f u): se ajusta a su visual (mínimo %.1f)" % [b1.size.x, Reactivo3D.MIN_CUERPO])
	var r2: Reactivo3D = _reactivo("raiz", 1.4)
	var b2: BoxShape3D = _cuerpo(r2)
	_ok(b2 != null and b2.size.x > b1.size.x and b2.size.x <= antes + 0.0001, "una pieza mayor (1,4 u) tiene la caja mayor (%.2f u) y nunca pasa de la de siempre (%.2f)" % [b2.size.x, antes])
	var r3: Reactivo3D = _reactivo("placa", 0.6)
	var b3: BoxShape3D = _cuerpo(r3)
	_ok(b3 != null and absf(b3.size.x - Reactivo3D.S * 0.7) < 0.001, "la placa conserva su caja (el área que se pisa): %.2f" % b3.size.x)
	var r4: Reactivo3D = _reactivo("surtidor", 0.6)
	var b4: BoxShape3D = _cuerpo(r4)
	_ok(b4 != null and absf(b4.size.x - Reactivo3D.S) < 0.001, "el surtidor conserva la suya, medida a mano: %.2f" % b4.size.x)
	await process_frame


## F10 (PlayLog3D): una casilla «parcial» ya no se pinta entera en rojo; se pinta su forma real (círculo de la huella) y la bloqueada sin forma sigue en rojo.
func _f10() -> void:
	var celda := Vector2i(10, 10)
	var otra := Vector2i(12, 12)
	var c: Vector3 = Terreno3D.centro_de(celda, 0.0)
	_mundo._bloqueadas[celda] = true
	_mundo._bloqueadas[otra] = true
	Terreno3D.huellas.clear()
	Terreno3D.huellas[celda] = [Vector3(c.x, c.z, 0.4)]
	var jug := Node3D.new()
	jug.position = Terreno3D.centro_de(Vector2i(9, 10), 0.0)
	_mundo.add_child(jug)
	var rojas: int = 0
	var formas: int = 0
	# El mundo falso no tiene `_jugador` ni `_hf`: se los damos con un envoltorio de propiedades dinámicas.
	var env := EnvF10.new()
	env._jugador = jug
	env._bloqueadas = _mundo._bloqueadas
	env._mapa = _mundo._mapa
	env._lado = 20
	root.add_child(env)
	var pl := PlayLog3D.new()
	pl.mundo = env
	pl._pintar_colisiones()
	for h in env.get_children():
		if h is MeshInstance3D and (h as MeshInstance3D).visible:
			if (h as MeshInstance3D).mesh is CylinderMesh or (h as MeshInstance3D).material_override.albedo_color.g > 0.9:
				formas += 1
			else:
				rojas += 1
	_ok(formas == 1, "F10: la casilla con barril pinta UNA forma real (círculo) y no un cuadrado (formas %d)" % formas)
	_ok(rojas >= 1, "F10: la casilla bloqueada sin forma conocida y el borde siguen en rojo (%d casillas)" % rojas)
	Terreno3D.huellas.clear()
	_mundo._bloqueadas.erase(celda)
	_mundo._bloqueadas.erase(otra)


func _forma_ancha() -> void:
	var cas: float = Terreno3D.casilla
	var c := Vector2i(10, 10)
	var vecina := Vector2i(11, 10)
	var cuerpo := StaticBody3D.new()
	cuerpo.collision_layer = Terreno3D.CAPA_SOLIDO
	var forma := CollisionShape3D.new()
	var cil := CylinderShape3D.new()
	cil.radius = cas * 0.65                          # roza la vecina (su caja del 90 % empieza a 0,55 casillas) sin llegar a su centro (0,75)
	cil.height = 2.0
	forma.shape = cil
	cuerpo.add_child(forma)
	root.add_child(cuerpo)
	cuerpo.global_position = Terreno3D.centro_de(c, Terreno3D.alto_suelo + 1.0)
	cuerpo.add_to_group("bloquea")
	await physics_frame
	await physics_frame
	var antes = Terreno3D.fuente
	var f := Terreno3D.FuenteNodos.new(_mundo)
	f.reconstruir()
	_ok(f.es_parcial(c) and f.es_parcial(vecina), "forma ancha: la casilla propia y la vecina rozada son «parciales» (el jugador choca con la forma)")
	_ok(f.bloquea(c), "forma ancha: su propia casilla está bloqueada entera")
	_ok(not f.bloquea(vecina), "forma ancha: la vecina que solo roza NO se bloquea entera (antes: pasillos cerrados para hechizos y BFS)")
	f.liberar(c)
	_ok(not f.bloquea(c) and not f.cubiertas.has(c) and not f.es_parcial(c), "liberar() limpia las dos capas (celdas y cubiertas)")
	f.bloquear_completa(vecina)
	_ok(f.bloquea(vecina) and not f.es_parcial(vecina), "bloquear_completa() bloquea entera y deja de ser parcial")
	Terreno3D.fuente = antes
	cuerpo.queue_free()


class EnvF10 extends MundoFalso:
	var _jugador: Node3D = null
	var _hf: Dictionary = {}
