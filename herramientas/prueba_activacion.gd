extends SceneTree
## Punto de activación (P2, 13/10): la bola y el chorro acaban en `punto_activacion()` del objeto que los para, no donde rozan su caja.
## Sin ventana ni Vfx3D: se prueban las dos preguntas que el Lanzador le hace al objeto. Lo escribe el Juego.
##   godot --headless --path . --script res://herramientas/prueba_activacion.gd

class Cuenco extends Area3D:
	var punto: Vector3 = Vector3.ZERO
	var reacciona: bool = true
	func punto_activacion() -> Vector3:
		return punto
	func spell_reacts(_r: RuneData, _d: Vector3) -> bool:
		return reacciona
	func on_spell_hit(_r: RuneData, _d: Vector3 = Vector3.ZERO) -> void:
		pass

class SinPunto extends Area3D:
	func on_spell_hit(_r: RuneData, _d: Vector3 = Vector3.ZERO) -> void:
		pass

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _caja(a: Area3D, centro: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(1.0, 1.0, 1.0)
	cs.shape = b
	a.add_child(cs)
	a.collision_layer = Lanzador3D.CAPA_REACTIVO
	a.collision_mask = 0
	a.position = centro
	root.add_child(a)


func _initialize() -> void:
	await process_frame
	var m := Node3D.new()
	root.add_child(m)
	var l := Lanzador3D.new()
	l.mundo = m
	root.add_child(l)
	var rune := RuneData.new()
	rune.tags.append("calor")
	# Un cuenco cuya caja está a 5 m, centrada en y = 1, y cuyo punto de activación está más arriba (y = 1,4).
	var cu := Cuenco.new()
	_caja(cu, Vector3(5.0, 1.0, 0.0))
	cu.punto = Vector3(5.0, 1.4, 0.0)
	await physics_frame
	await physics_frame
	var rec := {"desde": Vector3(0, 1, 0), "hasta": Vector3(4.5, 1, 0), "dir": Vector3.RIGHT, "rune": rune,
		"golpes": [{"obj": cu, "dist": 4.5, "punto": Vector3(4.5, 1, 0)}]}
	_ok("1 la bola que para en un objeto acaba en su punto de activación", l._activacion_al_final(rec) == cu.punto, str(l._activacion_al_final(rec)))
	var paso := {"desde": Vector3(0, 1, 0), "hasta": Vector3(6.9, 1, 0), "dir": Vector3.RIGHT, "rune": rune,
		"golpes": [{"obj": cu, "dist": 4.5, "punto": Vector3(4.5, 1, 0)}]}
	_ok("2 si el tramo sigue más allá del golpe (lo cruzó), no acaba ahí", l._activacion_al_final(paso) == Vector3.INF)
	cu.reacciona = false
	_ok("3 si el objeto no reacciona al hechizo, no hay punto", l._activacion_al_final(rec) == Vector3.INF)
	cu.reacciona = true
	var s := SinPunto.new()
	_caja(s, Vector3(0, 1, 5))
	var rec2 := {"desde": Vector3(0, 1, 0), "hasta": Vector3(0, 1, 4.5), "dir": Vector3(0, 0, 1), "rune": rune,
		"golpes": [{"obj": s, "dist": 4.5, "punto": Vector3(0, 1, 4.5)}]}
	_ok("4 un objeto sin punto_activacion no cambia nada", l._activacion_al_final(rec2) == Vector3.INF)
	var sin: Dictionary = {"desde": Vector3.ZERO, "hasta": Vector3(3, 0, 0), "dir": Vector3.RIGHT, "rune": rune, "golpes": []}
	_ok("5 un tramo que acaba en pared o en el alcance tampoco", l._activacion_al_final(sin) == Vector3.INF)
	await physics_frame
	# Chorro: el haz desde la mano (y = 1) por +X cruza la caja del cuenco.
	_ok("6 el chorro que cruza el cuenco devuelve su punto de activación", l._activacion_en_haz(Vector3(0, 1, 0), Vector3.RIGHT, 8.0, rune) == cu.punto)
	_ok("7 si el haz es más corto que la distancia al cuenco, no", l._activacion_en_haz(Vector3(0, 1, 0), Vector3.RIGHT, 3.0, rune) == Vector3.INF)
	_ok("8 un haz hacia otro lado, tampoco", l._activacion_en_haz(Vector3(0, 1, 0), Vector3(-1, 0, 0), 8.0, rune) == Vector3.INF)
	cu.reacciona = false
	_ok("9 el cuenco que no reacciona no termina el haz", l._activacion_en_haz(Vector3(0, 1, 0), Vector3.RIGHT, 8.0, rune) == Vector3.INF)
	print("FALLOS: %d" % _fallos)
	quit(_fallos)
