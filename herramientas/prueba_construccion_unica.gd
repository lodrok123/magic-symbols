extends "res://herramientas/escenario_base.gd"
## CONSTRUCCIÓN ÚNICA DEL HECHIZO (H1 del PLAN_SISTEMA_HECHIZOS, 29/10), con la escena de verdad:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_construccion_unica.gd
## Un lanzamiento del libro construye el `Hechizo` UNA vez (`Lanzador3D._preparar_pagina`, que lo guarda en `_preparado["hechizo"]`); el rechazo de construcción, el coste, la recarga, la previsión
## (cada fotograma) y el disparo leen ese. `Hechizo.construidos` cuenta las llamadas a `construir`. Y grimorio, previsión y ejecución enseñan los mismos `coste_tinta`, `recarga`, `forma` y `en_punto`.

const DESDE := Vector2i(6, 24)
const FOTOGRAMAS_PREVISION: int = 30


func _componer(elemento: String, glifos: Array) -> void:
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element(elemento)
	for g in glifos:
		lanzador.place_sigil(String(g))
	lanzador.cooldown_left[0] = 0.0
	if jugador.tinta != null:
		jugador.tinta.actual = 100.0


func _vivos() -> Array:
	var r: Array = []
	for n in lanzador.get_children():
		if n is HechizoVivo and not n.is_queued_for_deletion():
			r.append(n)
	return r


func _escenario() -> void:
	await cargar()
	colocar_jugador(DESDE)
	await avanzar(5)
	var casos: Array = [["fuego", ["flecha"]], ["fuego", ["flecha", "repeticion"]], ["fuego", ["barrera", "flecha"]], ["tierra", ["altura"]], ["agua", ["linea_x", "pulso"]], ["fuego", []]]
	for caso in casos:
		await _caso(String(caso[0]), caso[1])
	await _copia_independiente()
	_paridad_receta()


func _caso(elemento: String, glifos: Array) -> void:
	var et: String = "%s %s" % [elemento, str(glifos)]
	_componer(elemento, glifos)
	if glifos.is_empty():
		var n0: int = Hechizo.construidos
		lanzador.cast_page(0)
		_ok("%s: una página sin glifos se niega sin construir nada" % et, not lanzador.modo_lanzar and Hechizo.construidos == n0)
		return
	# --- preparar: una construcción ---
	var antes: int = Hechizo.construidos
	lanzador.cast_page(0)
	_ok("%s: cast_page prepara la página (modo de apuntar)" % et, lanzador.modo_lanzar)
	if not lanzador.modo_lanzar:
		return
	_ok("%s: preparar la página construye el Hechizo UNA vez (%d)" % [et, Hechizo.construidos - antes], Hechizo.construidos - antes == 1)
	var datos: Dictionary = lanzador._preparado
	var h0: Hechizo = datos.get("hechizo") as Hechizo
	_ok("%s: `_preparado[\"hechizo\"]` existe y su en_punto es el de `_preparado`" % et, h0 != null and bool(datos["en_punto"]) == h0.en_punto)
	if h0 == null:
		return
	# --- previsión: cada fotograma, 0 construidos ---
	var origen: Vector3 = jugador.position + Vector3.RIGHT * Terreno3D.casilla * 1.0
	var antes_prev: int = Hechizo.construidos
	for i in range(FOTOGRAMAS_PREVISION):
		PrevisionHechizo.prever_rapido(lanzador, datos, origen, Vector3.RIGHT, 0)       # edad máxima 0: sin caché, calcula de verdad
		lanzador.rechazo_de_construccion(datos, origen)
		lanzador.hechizo_de(datos)
	_ok("%s: %d fotogramas de previsión (prever + rechazo + hechizo_de) construyen %d veces (0)" % [et, FOTOGRAMAS_PREVISION, Hechizo.construidos - antes_prev], Hechizo.construidos == antes_prev)
	# --- lo que enseñan el grimorio, la previsión y la ejecución es lo mismo ---
	var h_prev: Hechizo = lanzador.hechizo_de(datos)
	_ok("%s: hechizo_de devuelve una COPIA (no el de `_preparado`) idéntica a él (el pigmento ya está dentro)" % et, h_prev != h0 and h_prev.a_diccionario() == h0.a_diccionario())
	var receta: Lanzador3D.Receta3D = datos["receta"]
	_ok("%s: coste_tinta igual en la receta (grimorio), el preparado y la previsión (%.2f)" % [et, h0.coste_tinta], is_equal_approx(receta.coste_tinta(), h0.coste_tinta) and is_equal_approx(h_prev.coste_tinta, h0.coste_tinta))
	_ok("%s: recarga y forma iguales en receta, preparado y previsión (%.2f s, %s)" % [et, h0.recarga, h0.forma], is_equal_approx(receta.cooldown, h0.recarga) and h_prev.forma == h0.forma and receta.forma() == h0.forma and is_equal_approx(h_prev.recarga, h0.recarga))
	# --- lanzar: sin más construidos; la ejecución usa lo mismo ---
	var tinta0: float = jugador.tinta.actual if jugador.tinta != null else 0.0
	var antes_l: int = Hechizo.construidos
	var datos_l: Dictionary = lanzador._preparado
	lanzador._salir_modo(true)
	lanzador._preparado = {}
	var salio: bool = lanzador.lanzar_ahora(datos_l, jugador.position if not h0.en_punto else origen, Vector3.RIGHT, false)
	_ok("%s: lanzar_ahora saca el hechizo SIN construir otra vez (%d)" % [et, Hechizo.construidos - antes_l], Hechizo.construidos == antes_l and (salio or h0.solido_quieto))
	if salio:
		var vivos: Array = _vivos()
		if not vivos.is_empty():
			var hv: Hechizo = (vivos[0] as HechizoVivo).h
			_ok("%s: el HechizoVivo ejecuta los mismos coste_tinta, recarga, forma y en_punto" % et, is_equal_approx(hv.coste_tinta, h0.coste_tinta) and is_equal_approx(hv.recarga, h0.recarga) and hv.forma == h0.forma and hv.en_punto == h0.en_punto)
		_ok("%s: la recarga que se pone es la del Hechizo (%.2f de %.2f)" % [et, lanzador.cooldown_total[0], h0.recarga], is_equal_approx(lanzador.cooldown_total[0], h0.recarga))
		if jugador.tinta != null:
			_ok("%s: se cobra el coste del Hechizo (%.2f de %.2f, sin pigmento)" % [et, tinta0 - jugador.tinta.actual, h0.coste_tinta], absf((tinta0 - jugador.tinta.actual) - lanzador.tinta.coste_efectivo(h0.coste_tinta, h0.elemento)) < 0.01)
	for v in _vivos():
		(v as Node).queue_free()
	lanzador.cooldown_left[0] = 0.0
	await avanzar(3)


## La copia de `hechizo_de` no es una vista: tocarla (como hacen `_salida_de_mano` y los laboratorios) no cambia el preparado, y dice lo mismo que uno construido de cero.
func _copia_independiente() -> void:
	_componer("fuego", ["flecha", "repeticion"])
	lanzador.cast_page(0)
	if not lanzador.modo_lanzar:
		_ok("copia: se pudo preparar", false)
		return
	var datos: Dictionary = lanzador._preparado
	var h0: Hechizo = datos["hechizo"]
	var antes: Dictionary = h0.a_diccionario()
	var c: Hechizo = lanzador.hechizo_de(datos)
	_ok("copia: idéntica al preparado (el daño del pigmento se aplica una vez, en `_preparar_pagina`)", c.a_diccionario() == antes)
	var fresco: Dictionary = Hechizo.construir(h0.fuente, datos["receta"].contadores, float(datos["calidad"])).a_diccionario()
	var mult: float = lanzador.tinta.mult_dano("fuego") if lanzador.tinta != null else 1.0
	_ok("copia: el preparado dice lo mismo que construir de cero salvo el pigmento (×%.2f)" % mult, _igual_menos_dano(antes, fresco) and is_equal_approx(float(antes["dano"]), float(fresco["dano"]) * mult))
	c.altura_salida += 5.0
	c.dano = 12345.0
	_ok("copia: tocar la copia no toca el preparado", h0.a_diccionario() == antes)
	lanzador._cancelar_modo()
	lanzador._preparado = {}


## `Receta3D` es solo un adaptador: coste de tinta, recarga y nombre/forma de la receta dicen lo MISMO que el `Hechizo` (20 recetas × 6 elementos), y construir el hechizo de la receta dos veces
## con la misma runa no construye dos veces. `levitacion` vale como `altura` (alias) en los dos lados.
const ELEMENTOS_PARIDAD: Array = ["fire", "water", "earth", "ice", "lightning", "wind"]
const RECETAS_PARIDAD: Array = [[], ["flecha"], ["linea_x"], ["linea_z"], ["altura"], ["levitacion"], ["barrera"], ["repeticion", "repeticion"], ["rebote", "flecha"], ["pulso"],
	["permanencia", "barrera"], ["raido", "flecha"], ["raido", "barrera"], ["linea_x", "linea_x", "linea_z"], ["altura", "altura", "altura", "altura"], ["flecha", "linea_z", "repeticion"],
	["barrera", "linea_x", "altura"], ["flecha", "flecha", "flecha", "rebote", "pulso"], ["levitacion", "altura", "linea_x"], ["permanencia", "raido", "pulso", "flecha"]]

func _paridad_receta() -> void:
	var malos: int = 0
	var vistos: int = 0
	var antes: int = Hechizo.construidos
	for glifos in RECETAS_PARIDAD:
		for e in ELEMENTOS_PARIDAD:
			var rune: RuneData = load("res://nucleo/%s_rune.tres" % e) as RuneData
			var receta := Lanzador3D.Receta3D.new(Vector2.RIGHT)
			for g in glifos:
				receta.apply(String(g))
			var h: Hechizo = receta.hechizo(rune)
			var h2: Hechizo = receta.hechizo(rune)
			var bien: bool = h != null and h2 != null and h != h2 and is_equal_approx(receta.coste_tinta(), h.coste_tinta) and is_equal_approx(receta.cooldown, h.recarga) 				and String(receta.geo()["nombre"]) == h.forma and receta.forma() == h.forma and receta.n_glifos() == h.n_glifos and is_equal_approx(receta.cooldown, Sigils.cooldown_v2(receta.contadores))
			vistos += 1
			if not bien:
				malos += 1
				print("      no coincide: %s %s" % [e, str(glifos)])
	_ok("paridad: Receta3D (coste_tinta, cooldown, geo nombre, forma, n_glifos) = Hechizo en %d recetas × elementos (%d fallan)" % [vistos, malos], malos == 0 and vistos == RECETAS_PARIDAD.size() * ELEMENTOS_PARIDAD.size())
	_ok("paridad: pedir hechizo(runa) otra vez no reconstruye (%d construcciones para %d recetas)" % [Hechizo.construidos - antes, vistos], Hechizo.construidos - antes == vistos)
	# `Sigils.glifos_hasta_tope` (lee GLIFOS) = lo que calculaba el laboratorio con GLIFOS_V2 (inicio, por_glifo, tope, modo)
	var topes_mal: int = 0
	for nombre in Sigils.GLIFOS_V2:
		var d: Dictionary = Sigils.GLIFOS_V2[nombre]
		var viejo: int
		if String(d.get("modo", "suma")) == "suma_decreciente":       # 30/10: ᛁ no llega al tope (1,10 < 3,0): el «tope» es el glifo que aporta menos de 0,01 m (13 con 0,25 y ×0,75)
			viejo = ceili(1.0 + log(0.01 / float(d["por_glifo"])) / log(float(d["factor"])))
		elif String(d.get("modo", "suma")) == "multiplica":
			viejo = maxi(1, ceili(log(float(d["tope"]) / float(d["inicio"])) / log(float(d["por_glifo"])) - 0.000001))
		else:
			viejo = maxi(1, ceili((float(d["tope"]) - float(d["inicio"])) / float(d["por_glifo"]) - 0.000001))
		if Sigils.glifos_hasta_tope(String(nombre)) != viejo:
			topes_mal += 1
			print("      tope distinto en %s: %d ≠ %d" % [nombre, Sigils.glifos_hasta_tope(String(nombre)), viejo])
		if Sigils.repertorio_de(String(nombre)) != String(d["repertorio"]):
			topes_mal += 1
	_ok("GLIFOS (repertorio, tope en glifos) dice lo mismo que GLIFOS_V2 (%d distintos)" % topes_mal, topes_mal == 0)


func _igual_menos_dano(a: Dictionary, b: Dictionary) -> bool:
	for k in a:
		if k == "dano" or k == "dano_periodico":
			continue
		if JSON.stringify(a[k]) != JSON.stringify(b.get(k)):
			print("      difiere %s: %s ≠ %s" % [k, str(a[k]), str(b.get(k))])
			return false
	return a.size() == b.size()
