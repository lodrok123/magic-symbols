extends "res://herramientas/escenario_base.gd"
## MIDE CUÁNTO TARDA EN SALIR UNA BARRERA (21/11, dirección; regla C18 de docs/PROPUESTAS_SESION_MYSTRALIA_2026-11-21.md): desde que se pulsa la página hasta que la protección EXISTE
## (una burbuja nueva en `Lanzador3D._barrera_activa` o una solidez nueva en `_solideces_v2`). Se lanza por el camino del lanzamiento inteligente, CON la animación de lanzar
## (`lanzar_pagina_ya(..., con_conjuro = true)`): los escenarios lanzan sin ella y por eso no lo medían.
## Mide fuego, agua y tierra, con barrera sola y con barrera + flecha, dos veces cada una, en la Sala del Gólem (gólem quieto), cada vez desde una casilla distinta.
## Tiempo de JUEGO (suma de deltas, lo que ve el enemigo) y fotogramas. No afirma nada: imprime una tabla.
##   godot --headless --fixed-fps 60 --path . --script res://herramientas/medir_salida_barrera.gd

const RUTA_SALA: String = "res://escenas/PruebaSalaGolem.tscn"
const RECETAS: Array = [["barrera"], ["barrera", "flecha"]]
const ELEMENTOS: Array = ["fuego", "agua", "tierra"]
const SITIOS: Array = [Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 6), Vector2i(2, 7), Vector2i(6, 1), Vector2i(6, 2), Vector2i(6, 6), Vector2i(6, 7),
	Vector2i(10, 1), Vector2i(10, 7), Vector2i(13, 1), Vector2i(13, 2)]


func _ids_protecciones() -> Dictionary:
	var r: Dictionary = {}
	if lanzador._barrera_activa != null and is_instance_valid(lanzador._barrera_activa):
		r[lanzador._barrera_activa.get_instance_id()] = "burbuja"
	for s in lanzador._solideces_v2:
		if is_instance_valid(s):
			r[(s as Object).get_instance_id()] = "solidez"
	return r


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_SALA, true)
	if maqueta == null or jugador == null or lanzador == null:
		return
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	var g: Node = z.nodo("golem_a") if z != null else null
	if g != null:
		g.set("quieto", true)
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = maxi(Repertoire.max_sigils_per_page, 8)
	(jugador as Jugador3D).vida = 100000.0
	var lanzados: Dictionary = {"t": -1.0}
	lanzador.lanzado.connect(func(_e: String, _f: String, _n: int) -> void: lanzados["t"] = reloj.t)
	var filas: Array = []
	var k: int = 0
	for el in ELEMENTOS:
		for receta in RECETAS:
			for vez in range(2):
				var sitio: Vector2i = SITIOS[k % SITIOS.size()]
				k += 1
				colocar_jugador(sitio)
				await avanzar(10)
				lanzador.select_page(0)
				lanzador.clear_sequence()
				lanzador.place_element(String(el))
				for gl in receta:
					lanzador.place_sigil(String(gl))
				lanzador.cooldown_left[0] = 0.0
				if lanzador.tinta != null:
					lanzador.tinta.rellenar_barra()
				var antes: Dictionary = _ids_protecciones()
				lanzados["t"] = -1.0
				var t0: float = reloj.t
				var f0: int = reloj.fotogramas
				var ok: bool = lanzador.lanzar_pagina_ya(0, jugador.position, Vector3(1, 0, 0), true)
				var t_sale: float = -1.0
				var tipo: String = ""
				while reloj.t - t0 < 3.0:
					await process_frame
					var ahora: Dictionary = _ids_protecciones()
					for id in ahora:
						if not antes.has(id):
							t_sale = reloj.t - t0
							tipo = String(ahora[id])
							break
					if t_sale >= 0.0:
						break
				var t_lanzado: float = (float(lanzados["t"]) - t0) if float(lanzados["t"]) >= 0.0 else -1.0
				filas.append([String(el), " + ".join(receta), vez + 1, ok, t_lanzado, t_sale, reloj.fotogramas - f0, tipo])
				await avanzar_s(0.6)
	print("")
	print("SALIDA DE LA BARRERA (tiempo de juego desde la pulsación; -1 = no salió en 3 s)")
	print("elemento | receta            | vez | lanzada | nace el hechizo | existe la protección | fotogramas | tipo")
	for f in filas:
		print("%-8s | %-17s | %d   | %-7s | %6.2f s        | %6.2f s             | %4d       | %s" % [f[0], f[1], f[2], str(f[3]), f[4], f[5], f[6], f[7]])
	print("CastPoints x_mano: instante %.2f del clip recortado %.2f–%.2f a ×%.1f; abajo_golpe (corro): instante %.2f de %.2f–%.2f. Tierra ×%.1f." % [
		float(CastPoints.VARIACIONES["x_mano"]["instante"]), float(CastPoints.VARIACIONES["x_mano"]["inicio"]), float(CastPoints.VARIACIONES["x_mano"]["fin"]),
		float(CastPoints.VARIACIONES["x_mano"]["velocidad"]), float(CastPoints.VARIACIONES["abajo_golpe"]["instante"]),
		float(CastPoints.VARIACIONES["abajo_golpe"]["inicio"]), float(CastPoints.VARIACIONES["abajo_golpe"]["fin"]), float(CastPoints.ESCALA_TIEMPO["tierra"])])
