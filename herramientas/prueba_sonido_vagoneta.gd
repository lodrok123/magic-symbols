extends "res://herramientas/escenario_base.gd"
## Prueba de integración: arranque sin chirrido, rodadura, juntas y parada.
## El registro comprueba eventos, NO valida el timbre: eso se escucha en juego.

func _escenario() -> void:
	await cargar("res://escenas/PruebaPtVagonetas.tscn")
	var vag: Vagoneta3D = null
	for n in maqueta.find_children("*", "", true, false):
		if n is Vagoneta3D and n.name == "cat1_vag":
			vag = n
	_ok("hay vagoneta en la pista del nivel real", vag != null)
	if vag == null:
		return
	colocar_jugador(vag.celda + Vector2i(0, 1))
	await avanzar(3)
	Sfx.REGISTRAR = true
	Sfx.vaciar_registro()
	_ok("se puede empujar por la vía", vag.empujar(Vector2i(0, -1), true))
	await avanzar_s(0.8)
	var p: AudioStreamPlayer3D = vag.get("_rodadura") as AudioStreamPlayer3D
	_ok("al moverse hay rodadura con el archivo nuevo", p != null and p.stream != null and p.stream.get_length() > 5.9)
	_ok("arrancar en recta no dispara chirrido", Sfx.veces("vagoneta_chirrido") == 0)
	if p != null:
		_ok("rodadura sigue el bus Mundo u Ocluido", p.bus == Sfx3D.BUS_MUNDO or p.bus == Sfx3D.BUS_OCLUIDO)
	# Caminar una casilla no necesita continuar empujando: llega a su centro y frena.
	await avanzar_s(3.2)
	_ok("cruzar la junta produce un golpe de raíl", Sfx.veces("vagoneta_junta") > 0)
	await avanzar_s(0.8)
	_ok("quieta se retira el sostenido", vag.get("_rodadura") == null)
	for archivo in Sfx3D.CATALOGO["vagoneta_junta"]["f"]:
		var sonido: AudioStream = load("res://audio/" + String(archivo))
		_ok("junta importada corta: " + String(archivo), sonido != null and sonido.get_length() < 0.15)
	Sfx.REGISTRAR = false
