extends "res://herramientas/escenario_base.gd"

## PRUEBA de la escena de RUINAS CON TRAMPAS (25/11/2026): escenas/PruebaRuinasTrampas.tscn (mapa RuinasTrampas). Comprueba que las piezas montan sin avisos, que
## están las dos trampas de pared (3 mascarones, 2 dragones) y el tótem, que cada trampa de pared tiene su CONTRAFUERTE del pack y que los muros finos están.
## Con la jugadora delante de cada trampa, espera a que dispare y hace una foto con la cámara del juego. Necesita ventana y el pack generado (arte/stylescape/LEEME.md):
##   godot --path . --script res://herramientas/captura_ruinas_trampas.gd
## Fotos en docs/capturas/stylescape/trampas/.

const ESCENA: String = "res://escenas/PruebaRuinasTrampas.tscn"
const DIR: String = "res://docs/capturas/stylescape/trampas"
## [foto, casilla de la jugadora, trampa a la que esperar (nodo), señal]
const FOTOS: Array = [
	["1_pasillo_mascarones", Vector2i(12, 11), "t_masc_2", "dispara"],
	["2_patio_dragon", Vector2i(24, 6), "t_dragon_patio", "escupe"],
	["3_dragon_oeste", Vector2i(23, 8), "t_dragon_pasillo", "escupe"],
	["4_sala_totem", Vector2i(12, 5), "t_totem", "dispara"],
	["5_entrada", Vector2i(4, 13), "", ""],
]


func _escenario() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	Flags.nuevo()
	Estado.nuevo()
	await cargar(ESCENA, false)
	var pz: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	_ok("1 Puzle3D sin avisos", pz != null and pz.avisos.is_empty(), str(pz.avisos.slice(0, 4)) if pz != null else "sin Puzle3D")
	var masc: int = 0
	var dragones: int = 0
	for n in maqueta.find_children("*", "TrampaPared3D", true, false):
		if n is TrampaDragon3D:
			dragones += 1
		elif n is TrampaFlechas3D:
			masc += 1
	_ok("2 hay 4 mascarones (uno exento) y 2 dragones", masc == 4 and dragones == 2, "%d mascarones, %d dragones" % [masc, dragones])
	var pilares: Array = []
	var muros: int = 0
	for n in maqueta.find_children("*", "Node3D", true, false):
		var id: String = String((n as Node).get_meta("id", ""))
		if id == "ss_pillar_01":
			pilares.append(n)
		elif id.begins_with("ss_"):
			muros += 1
	_ok("3 muros finos del pack en las paredes", muros > 50, "%d piezas" % muros)
	_ok("3 un contrafuerte por trampa de pared (5)", pilares.size() == 5, str(pilares.size()))
	# Cada trampa de pared tiene un contrafuerte detrás, con la cara a ras de la suya (a menos de 0,2 u).
	var pegadas: int = 0
	for n in maqueta.find_children("*", "TrampaPared3D", true, false):
		var t: TrampaPared3D = n
		if t.exenta:
			continue
		for p in pilares:
			var cara: Vector3 = (p as Node3D).global_position + t.dir * (0.5175)
			if Vector2(cara.x - t.global_position.x, cara.z - t.global_position.z).length() < 0.2:
				pegadas += 1
				break
	_ok("3 cada trampa de pared está apoyada en su contrafuerte", pegadas == 5, "%d de 5" % pegadas)
	for cl in root.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false
	root.get_window().size = Vector2i(1600, 900)
	for f in FOTOS:
		colocar_jugador(f[1])
		await avanzar(30)
		var trampa: Node = maqueta.find_child(String(f[2]), true, false) if String(f[2]) != "" else null
		var vio: bool = false
		if trampa != null:
			var t0: float = reloj.t
			var antes: int = int(trampa.get("lanzamientos"))
			while reloj.t - t0 < 8.0 and int(trampa.get("lanzamientos")) == antes:
				await process_frame
			vio = int(trampa.get("lanzamientos")) > antes
			await avanzar(12)       # que se vea el disparo en vuelo
		if String(f[2]) != "":
			_ok("4 %s: la trampa %s dispara con la jugadora cerca" % [f[0], f[2]], vio)
		var ruta: String = ProjectSettings.globalize_path(DIR).path_join("%s.png" % f[0])
		root.get_viewport().get_texture().get_image().save_png(ruta)
		print("captura: ", ruta)
		await avanzar(90)            # la invulnerabilidad y la vida: que no se acumule daño de una foto a otra
		jugador.set("vida", jugador.get("vida_max") if jugador.get("vida_max") != null else jugador.get("vida"))
