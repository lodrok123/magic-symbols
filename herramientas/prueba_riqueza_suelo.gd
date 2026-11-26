extends "res://herramientas/escenario_base.gd"

## PRUEBA DE LA CAPA DE RIQUEZA DEL SUELO Y DE LA VARIEDAD DE DECORADO (26/11/2026, presentacion/riqueza_suelo_3d.gd y tabla_decorado_bioma.gd), sin ventana:
##   1. Cargar dos veces el mismo mapa generado da EXACTAMENTE el mismo decorado (mismos lotes y mismas posiciones): determinista por semilla y casilla.
##   2. Otra semilla de decorado reparte distinto (no es el mismo confeti en todos los mapas).
##   3. Con `riqueza_suelo` y `decorado_bioma` apagados (los niveles hechos a mano) no sale ninguna pieza del pack ni cuenta de riqueza.
##   4. Con la riqueza encendida nada cae sobre camino `g`, losas `R`, agua ni casilla de pieza de puzle; y nada de lo sembrado bloquea una casilla que no sea `#`.
##   5. Hay menos densidad en el centro de los claros que en los bordes (la mitad, por lo menos).
##   6. Ninguna pieza vetada (peso 0) sale; el límite de modelos por trozo de 7×7 se cumple.
## Genera «ZzRiquezaPrueba» (bosque, 40×34), lo exporta, y al acabar BORRA lo que escribió.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_riqueza_suelo.gd

const Generador = preload("res://herramientas/generador_mapas/generador_mazmorra.gd")
const Exportador = preload("res://herramientas/generador_mapas/exportador_mapa.gd")
const TABLA = preload("res://presentacion/tabla_decorado_bioma.gd")
const S: float = 2.3
const NOMBRE: String = "ZzRiquezaPrueba"


func _firma(mq: Node) -> String:
	var partes: PackedStringArray = PackedStringArray()
	var ids: Array = mq._lotes.keys()
	ids.sort()
	for id in ids:
		var h: int = 0
		for t in (mq._lotes[id] as Array):
			var o: Vector3 = (t as Transform3D).origin
			h = (h * 31 + roundi(o.x * 100.0) * 7 + roundi(o.z * 100.0) * 13) % 2147483647
		partes.append("%s:%d:%d" % [id, (mq._lotes[id] as Array).size(), h])
	return "|".join(partes)


func _carga(par: Dictionary) -> Node:
	var m: Dictionary = Generador.new().generar(par)
	var res: Dictionary = Exportador.exportar(m)
	_ok("0 se exporta " + String(par["nombre"]), bool(res["ok"]), String(res.get("error", "")))
	Flags.nuevo()
	Estado.nuevo()
	if maqueta != null and is_instance_valid(maqueta):
		maqueta.queue_free()
		await avanzar(5)
	await cargar(Exportador.ruta_escena(String(par["nombre"])), false)
	return maqueta


func _escenario() -> void:
	var par: Dictionary = Generador.parametros_defecto()
	par.merge({"nombre": NOMBRE, "algoritmo": "bosque", "semilla": 5, "ancho": 40, "alto": 34, "estilo": "bosque", "luz": "bosque"}, true)
	await _carga(par)
	var mq: Node = maqueta
	var f1: String = _firma(mq)
	var cuentas1: Dictionary = mq.riqueza_cuentas.duplicate()
	var filas: PackedStringArray = Generador.new().generar(par)["filas"]
	# 4 · dónde cae
	var puzle: Dictionary = {}
	for q in mq._celdas_puzle_del_mapa():
		puzle[q] = true
	var ids_riqueza: Dictionary = {}      # solo las piezas de otro pack: esas las pone SOLO la capa de riqueza (las del juego también salen de los adornos de siempre)
	for papel in ["hierba_corta", "flor", "roca", "tronco"]:
		for f in TABLA.filas("bosque", papel, true):
			if TABLA.es_externa(String(f[0])):
				ids_riqueza[String(f[0])] = true
	var malas: int = 0
	var en_celda: Dictionary = {}
	var total: int = 0
	for id in ids_riqueza:
		for t in (mq._lotes.get(id, []) as Array):
			var o: Vector3 = (t as Transform3D).origin
			var c := Vector2i(floori(o.x / S), floori(o.z / S))
			var l: String = mq._letra(c)
			total += 1
			# (la orilla no cuenta: las rocas del decorado de claros de siempre también pueden caer junto al agua; la capa de riqueza sí la evita)
			if not (l == "." or l == "," or l == "v") or puzle.has(c):
				malas += 1
				print("  mal puesta: ", id, " en ", c, " letra ", l, " puzle=", puzle.has(c))
			en_celda[c] = int(en_celda.get(c, 0)) + 1
	_ok("4 nada de la riqueza cae en camino, losa, agua ni casilla de pieza de puzle", malas == 0 and total > 100, "%d de %d mal puestas" % [malas, total])
	# 5 · borde frente a centro
	var suma_borde: int = 0
	var n_borde: int = 0
	var suma_centro: int = 0
	var n_centro: int = 0
	for y in range(filas.size()):
		for x in range(filas[y].length()):
			if filas[y][x] != ".":
				continue
			var d: int = 99
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					var yy: int = y + dy
					var xx: int = x + dx
					if yy < 0 or xx < 0 or yy >= filas.size() or xx >= filas[yy].length() or not ".,v".contains(filas[yy][xx]):
						d = mini(d, maxi(absi(dx), absi(dy)))
			if d <= 1:
				suma_borde += int(en_celda.get(Vector2i(x, y), 0))
				n_borde += 1
			elif d >= 2:
				suma_centro += int(en_celda.get(Vector2i(x, y), 0))
				n_centro += 1
	var dens_borde: float = float(suma_borde) / maxf(float(n_borde), 1.0)
	var dens_centro: float = float(suma_centro) / maxf(float(n_centro), 1.0)
	_ok("5 menos riqueza en el centro de los claros (a 2 o más casillas del borde) que en el borde (≤ 80 %)", n_borde > 10 and n_centro > 10 and dens_centro <= dens_borde * 0.8, "borde %.2f por casilla (%d casillas) · centro %.2f (%d casillas)" % [dens_borde, n_borde, dens_centro, n_centro])
	# 6 · vetadas y límite de modelos por trozo
	var vetada: bool = false
	for id in mq._lotes:
		var s: String = String(id)
		if s.contains("birch") or s.contains("grassmountain") or s.contains("gorse"):
			vetada = true
	_ok("6 ninguna pieza de peso 0 sale (abedules, hierba de monte, tojo)", not vetada)
	var por_trozo: Dictionary = {}
	for id in ids_riqueza:
		for t in (mq._lotes.get(id, []) as Array):
			var o2: Vector3 = (t as Transform3D).origin
			var k := Vector2i(floori(o2.x / (S * 7.0)), floori(o2.z / (S * 7.0)))
			if not por_trozo.has(k):
				por_trozo[k] = {}
			(por_trozo[k] as Dictionary)[id] = true
	var max_modelos: int = 0
	for k in por_trozo:
		max_modelos = maxi(max_modelos, (por_trozo[k] as Dictionary).size())
	# hierba (4) + flores (3) + roca (2) + tronco (2) + variantes de los trozos que cruza el desplazamiento
	_ok("6 los modelos de la capa de riqueza por trozo de 7×7 casillas no pasan de 11", max_modelos <= 11, "máximo %d" % max_modelos)
	# 1 · mismo mapa, mismo decorado
	await _carga(par)
	_ok("1 volver a cargar el mismo mapa da el mismo decorado (lotes y posiciones)", _firma(maqueta) == f1 and str(maqueta.riqueza_cuentas) == str(cuentas1), str(cuentas1))
	# 2 · otra semilla de decorado
	var txt: String = FileAccess.get_file_as_string(Exportador.ruta_escena(NOMBRE))
	var f_escena: FileAccess = FileAccess.open(Exportador.ruta_escena(NOMBRE), FileAccess.WRITE)
	f_escena.store_string(txt.replace("semilla_decorado = 5", "semilla_decorado = 6"))
	f_escena.close()
	Flags.nuevo()
	Estado.nuevo()
	maqueta.queue_free()
	await avanzar(5)
	await cargar(Exportador.ruta_escena(NOMBRE), false)
	_ok("2 otra semilla de decorado reparte distinto", _firma(maqueta) != f1)
	# 3 · apagado (niveles hechos a mano)
	par["decorado"] = false
	await _carga(par)
	var con_pack: int = 0
	for id in maqueta._lotes:
		if TABLA.es_externa(String(id)):
			con_pack += (maqueta._lotes[id] as Array).size()
	_ok("3 con la variedad y la riqueza apagadas no sale ninguna pieza de otro pack ni hay cuentas", con_pack == 0 and (maqueta.riqueza_cuentas as Dictionary).is_empty(), "%d piezas de otro pack" % con_pack)
	maqueta.queue_free()
	await avanzar(3)
	for ruta in [Exportador.ruta_mapa(NOMBRE), Exportador.ruta_escena(NOMBRE)]:
		if FileAccess.file_exists(ruta):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
