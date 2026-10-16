extends SceneTree
## Prueba sin ventana de ConjuroVfx3D (T6b): con un Lanzador de mentira que emite `conjuro_fase` en los tiempos reales, comprueba que
## cada elemento crea voluta y forma, que la voluta llega a la mano, y que al disparo no queda nada colgando. Sin depender de Lanzador3D.
##   godot --headless --path . --script res://herramientas/prueba_conjuro_vfx.gd
class FalsoLanzador:
	extends Node
	signal conjuro_fase(fase: String, elemento: String, posicion: Vector3)
	func tiempos_conjuro(_e: String) -> Array:
		return [0.05, 0.10, 0.05]

var fallos: int = 0

func ok(c: bool, m: String) -> void:
	if c:
		print("  ok  ", m)
	else:
		print("  FALLA ", m)
		fallos += 1

func _initialize() -> void:
	await process_frame
	var mundo := Node3D.new(); root.add_child(mundo)
	var l := FalsoLanzador.new(); mundo.add_child(l)
	var c: ConjuroVfx3D = ConjuroVfx3D.conectar(l, mundo)
	ok(c != null, "conectar devuelve el nodo")
	ok(ConjuroVfx3D.conectar(Node.new(), mundo) == null, "sin señal conjuro_fase no conecta")
	var libro := Vector3(-0.3, 0.55, 0.0)
	var mano := Vector3(0.4, 0.8, 0.2)
	for el in ConjuroVfx3D.PERFIL.keys() + ["inventado"]:
		var antes: int = c.get_child_count()
		l.conjuro_fase.emit("runa", el, mano)
		l.conjuro_fase.emit("voluta", el, libro)
		ok(c.get_child_count() == antes + 1, "%s: nace la voluta" % el)
		var cab: Node3D = c.get_child(c.get_child_count() - 1)
		ok(cab.global_position.distance_to(libro) < 0.01, "%s: sale del libro" % el)
		await create_timer(0.14).timeout
		ok(cab.global_position.distance_to(mano) < 0.08, "%s: llega a la mano (%.3f)" % [el, cab.global_position.distance_to(mano)])
		l.conjuro_fase.emit("forma", el, mano)
		ok(c._vivos.size() >= 1, "%s: hay forma en la mano" % el)
		await create_timer(0.08).timeout
		l.conjuro_fase.emit("disparo", el, mano)
		await create_timer(0.3).timeout
		await process_frame
		ok(c._vivos.is_empty(), "%s: tras el disparo no queda forma" % el)
	await create_timer(1.0).timeout
	await process_frame
	ok(c.get_child_count() == 0, "al cabo de un segundo no queda ningún nodo (%d)" % c.get_child_count())
	print("FALLOS ", fallos)
	quit(1 if fallos > 0 else 0)
