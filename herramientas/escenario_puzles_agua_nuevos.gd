extends "res://herramientas/escenario_base.gd"
## Escenario · los puzles NUEVOS del LABORATORIO DE AGUA (18/11/2026, Juego): Q11 «Dos riegos a la vez» (sala (3,2)) y Q12 «Foso con cofre flotante» (sala (3,3), la fila de salas que se añadió debajo).
## Carga laboratorios/LabPuzlesAgua3D.tscn y los juega por código con las piezas de verdad. Dos pasadas, como los demás escenarios de laboratorio (lo que se abre o se llena no se deshace):
##   · `natural`  (por defecto): la vía de la jugadora (hechizos de agua: flechas y línea).
##   · `botones`  (escenario_puzles_agua_nuevos_botones.gd): el botón `!` y la placa `@`, que separan «falla el agua» de «falla el disparador».
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_puzles_agua_nuevos.gd
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_puzles_agua_nuevos_botones.gd

const RUTA_LAB: String = "res://laboratorios/LabPuzlesAgua3D.tscn"

var modo: String = "natural"          ## "natural" | "botones" (lo cambia el escenario hijo en su _init)
var lab: Node = null


func _escenario() -> void:
	await cargar(RUTA_LAB)
	lab = maqueta.get_node_or_null("Reglas")
	_ok("0 el laboratorio cuelga de la escena", lab != null)
	if lab == null:
		return
	_ok("0 el mapa y las piezas nuevas se montan sin avisos", (lab.get("_avisos") as Array).is_empty(), str(lab.get("_avisos")))
	if modo == "natural":
		await _q11_natural()
	else:
		await _q11_botones()


# ---------------------------------------------------------------------------------------------------------------------

func _sala(nombre: String) -> Dictionary:
	return lab.call("nuevo", nombre)


# ---------------------------------------------------------------------------------------------------------------------
#  Q11 · Dos riegos a la vez
# ---------------------------------------------------------------------------------------------------------------------

func _q11_estado_inicial() -> void:
	var q: Dictionary = _sala("Q11")
	var a: Pulsador3D = q["a"]
	var b: Pulsador3D = q["b"]
	var puerta: Node = q["puerta"]
	_ok("Q11.1 dos pulsadores de AGUA con rearme corto (%.2f s y %.2f s), a 2 casillas en la misma fila, y la puerta cerrada" % [a.rearme, b.rearme],
		a.modo == "agua" and b.modo == "agua" and a.rearme > 0.0 and a.rearme <= 0.5 and b.rearme == a.rearme and a.celda.y == b.celda.y and absi(a.celda.x - b.celda.x) == 2 and not bool(puerta.get("abierta")))


func _q11_natural() -> void:
	await _q11_estado_inicial()
	var q: Dictionary = _sala("Q11")
	var a: Pulsador3D = q["a"]
	var b: Pulsador3D = q["b"]
	var control: Pulsador3D = q["control"]
	var puerta: Node = q["puerta"]
	lanzador.tinta = null
	# 1 · Una flecha de agua a A: lo pulsa, pero la puerta no abre (B está libre).
	_ok("Q11.2 agua + flecha a A (desde el sur de su columna) sale", lanzar_a_celda("agua", ["flecha"], Vector2i(26, 19), Vector2i(26, 21)))
	var recarga: float = lanzador.cooldown_left[0]
	await avanzar_s(1.2)
	_ok("Q11.3 A se pulsa y con B libre la puerta sigue cerrada", a.veces == 1 and b.veces == 0 and not bool(puerta.get("abierta")))
	_ok("Q11.4 la página que lanzó queda en recarga %.2f s: otra flecha de la MISMA página no puede salir dentro del rearme (%.2f s)" % [recarga, b.rearme], recarga > b.rearme)
	# 2 · Una flecha de agua a B, un segundo después: A ya se ha rearmado (0,35 s), así que tampoco abre.
	_ok("Q11.5 agua + flecha a B (desde el sur de su columna) sale", lanzar_a_celda("agua", ["flecha"], Vector2i(28, 19), Vector2i(28, 21)))
	await avanzar_s(1.2)
	_ok("Q11.6 B se pulsa, A ya estaba libre otra vez, y la puerta sigue cerrada: dos flechas sueltas no abren", b.veces == 1 and not a.activo and not bool(puerta.get("abierta")))
	# 3 · El botón de control no abre nada.
	_ok("Q11.7 fuego + flecha al botón de control sale", lanzar_a_celda("fuego", ["flecha"], Vector2i(26, 22), Vector2i(26, 20)))
	await avanzar_s(1.2)
	_ok("Q11.8 el botón de control se pulsa con cualquier magia y no abre la puerta", control.veces >= 1 and not bool(puerta.get("abierta")))
	# 4 · Una LÍNEA de agua desde el oeste de la fila los moja a los dos en el mismo golpe.
	colocar_jugador(Vector2i(25, 19))
	await avanzar_s(0.5)
	var va: int = a.veces
	var vb: int = b.veces
	_ok("Q11.9 agua + línea hacia el este sale", lanzar("agua", ["linea_x", "linea_x"], Vector3.RIGHT))
	await avanzar_s(1.0)
	_ok("Q11.10 la línea pulsa A y B en el mismo golpe (pulsaciones +%d y +%d)" % [a.veces - va, b.veces - vb], a.veces == va + 1 and b.veces == vb + 1)
	_ok("Q11.11 … y la puerta se abre", bool(puerta.get("abierta")))


func _q11_botones() -> void:
	await _q11_estado_inicial()
	var q: Dictionary = _sala("Q11")
	var a: Pulsador3D = q["a"]
	var b: Pulsador3D = q["b"]
	var control: Pulsador3D = q["control"]
	var puerta: Node = q["puerta"]
	var placa: Pulsador3D = lab.call("pulsador_en", Vector2i(30, 22)) as Pulsador3D
	_ok("Q11.20 la placa `@` (30,22) existe", placa != null)
	# Sin hechizos: A y, un segundo después, B (A ya se rearmó): no abre.
	a.pulsar()
	await avanzar_s(1.0)
	b.pulsar()
	await avanzar_s(0.5)
	_ok("Q11.21 A y 1 s después B (rearme %.2f s): la puerta sigue cerrada" % a.rearme, a.veces == 1 and b.veces == 1 and not bool(puerta.get("abierta")))
	control.pulsar()
	await avanzar_s(0.5)
	_ok("Q11.22 el botón de control pulsado no abre la puerta", control.veces == 1 and not bool(puerta.get("abierta")))
	colocar_jugador(Vector2i(30, 22))
	await avanzar_s(0.6)
	_ok("Q11.23 la placa abre la puerta", placa.veces == 1 and bool(puerta.get("abierta")))
