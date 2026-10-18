extends SceneTree
## El cofre nace CERRADO (Pipeline, 16/10; Pablo en Bosque 01: «el cofre estaba abierto inicialmente»).
##   godot --headless --path . --script res://herramientas/prueba_cofre_cerrado.gd
## Causa: el GLB sale con la tapa ABIERTA y solo `Cofre3D.preparar` la deja en el clip «cerrado», pero se llamaba al pulsar E. Ahora `cofre.tscn` trae el
## controlador y se prepara solo al entrar en el árbol. Se mide la rotación de la tapa, no se mira a ojo.

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	var ps: PackedScene = load("res://arte/piezas/cofre.tscn") as PackedScene
	_ok("A1 existe arte/piezas/cofre.tscn", ps != null)
	var c: Node3D = ps.instantiate() as Node3D
	root.add_child(c)
	await process_frame
	await process_frame
	var tapa: Node3D = c.find_child("cofre_tapa", true, false) as Node3D
	_ok("A2 la pieza trae su Cofre3D (uno solo) sin que nadie lo pida", c.find_children("*", "Cofre3D", true, false).size() == 1)
	# La pose cerrada es la que deja `cerrar()` (el clip «cerrado» en su primer fotograma); la abierta, la rotación identidad de la tapa.
	var q_nace: Quaternion = tapa.quaternion
	var ctrl: Cofre3D = Cofre3D.en(c)
	_ok("A3 Cofre3D.en devuelve el que ya lleva (no crea otro)", ctrl != null and c.find_children("*", "Cofre3D", true, false).size() == 1)
	ctrl.cerrar()
	_ok("B1 al nacer la tapa ya está en la pose cerrada (no la del GLB, que es la abierta)", q_nace.is_equal_approx(tapa.quaternion) and not q_nace.is_equal_approx(Quaternion.IDENTITY),
		"nace %s · cerrada %s" % [str(q_nace), str(tapa.quaternion)])
	_ok("B2 esta_abierto() = false al nacer", not ctrl.esta_abierto())
	# Y se sigue abriendo: anticipación (0,4 s) + clip (0,55 s).
	_ok("C1 abrir() arranca", ctrl.abrir())
	await create_timer(1.3).timeout
	_ok("C2 tras la secuencia está abierto y la tapa a su pose abierta", ctrl.esta_abierto() and tapa.quaternion.angle_to(Quaternion.IDENTITY) < 0.01, str(tapa.quaternion))
	_ok("C3 abrir() otra vez no hace nada", not ctrl.abrir())
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)
