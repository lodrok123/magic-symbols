extends "res://herramientas/escenario_base.gd"
## B3 de docs/PLAN_COMBATE_2026-11-22.md (C2, 22/11): el limo de AGUA deja el suelo mojado al moverse y el de FUEGO, quemado; una casilla cada 0,5 s como mucho, y su propio
## rastro no lo alimenta (no crece ni se cura por pisarlo).
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_rastro_limo.gd

const RUTA_SALA: String = "res://escenas/PruebaArenaCombate.tscn"


func _probar(elemento: String, estado: String) -> void:
	var desde := Vector2i(16, 12)
	var li: Limo3D = Limo3D.crear(maqueta as Node3D, Terreno3D.centro_de(desde, Terreno3D.y_pies(desde)), elemento, false)
	_ok("0 se crea un limo de %s" % elemento, li != null)
	if li == null:
		return
	await avanzar(5)
	li.health = 10000.0
	li.vida_max = 10000.0
	var grande0: bool = li.grande
	(jugador as Jugador3D).vida = 100000.0
	# Que la persiga: la jugadora se va alejando por la fila 12 hacia el oeste.
	var t: float = 0.0
	while t < 6.0:
		var x: int = 15 - int(t * 1.4)
		colocar_jugador(Vector2i(maxi(x, 2), 12))
		t += await avanzar_s(0.2)
	var marcadas: int = 0
	for c in li._rastro.keys():
		if Terreno3D.estados.tiene(c as Vector2i, estado):
			marcadas += 1
	# Las casillas que ya eran de su elemento (las que quemó o mojó su acometida al alcanzarla) no cuentan como rastro: se mira el camino entero.
	var camino: int = 0
	var cf: Vector2i = Terreno3D.celda_de(li.position)
	for x in range(mini(cf.x, desde.x), maxi(cf.x, desde.x) + 1):
		if Terreno3D.estados.tiene(Vector2i(x, 12), estado):
			camino += 1
	_ok("B3 el limo de %s deja rastro al moverse (%d marcadas por él; %d casillas del camino con «%s»)" % [elemento, li.rastros, camino, estado], li.rastros >= 1 and camino >= 2,
		"se movió de %s a %s" % [desde, cf])
	_ok("B3 el rastro del limo de %s es suelo %s" % [elemento, estado], marcadas >= 1, "%d de %d casillas con «%s»" % [marcadas, li._rastro.size(), estado])
	_ok("B3 como mucho una casilla cada %.1f s" % Limo3D.RASTRO_INTERVALO, li.rastros <= int(6.0 / Limo3D.RASTRO_INTERVALO) + 1)
	_ok("B3 su propio rastro no lo hace crecer", li.grande == grande0, "grande %s → %s" % [grande0, li.grande])
	li.queue_free()
	if li.cuerpo != null and is_instance_valid(li.cuerpo):
		li.cuerpo.queue_free()
	await avanzar(5)


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_SALA, true)
	if lanzador == null:
		return
	await _probar("agua", EstadosSuelo3D.MOJADA)
	await _probar("fuego", EstadosSuelo3D.QUEMADA)
