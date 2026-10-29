extends "res://herramientas/escenario_base.gd"
## H7 (29/10, PLAN_SISTEMA_HECHIZOS §3): LO QUE EL LIBRO ENSEÑA ES LO QUE PASA. Sin ventana, con la escena de verdad:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_resumen_hechizo.gd
## 1. `Hechizo.resumen()["tinta"]` es lo que cobra `lanzar_ahora` y `["recarga"]` lo que se pone en `cooldown_total`: 12 recetas × 3 elementos, con el resumen que el libro guarda (`resumen_pagina`).
## 2. `Lanzador3D.avisos_de` dice lo que dice `_preparar_pagina` cuando rechaza o avisa: altura, glifo sin uso y tinta insuficiente, cada uno provocado.
## 3. `diferencia()` al añadir ᛁ, ᛇ, ᛉ y ᚠ cambia SOLO los campos de ese glifo (según `origen`) más los derivados; `texto_cambio` nunca sale vacío ni con «null».
## 4. Frases con unidades, cambio de página, deshacer y que la tinta cambie no pierde el último glifo.

const DESDE := Vector2i(6, 24)
const ELEMENTOS: Array = ["fuego", "agua", "tierra"]
const RECETAS: Array = [["flecha"], ["flecha", "repeticion"], ["barrera", "flecha"], ["linea_x"], ["linea_x", "pulso"], ["altura"], ["rebote", "flecha"], ["permanencia", "barrera"],
	["raido", "flecha"], ["pulso", "flecha", "repeticion"], ["flecha", "linea_x", "barrera"], ["linea_z", "linea_x", "altura"]]


func _componer(elemento: String, glifos: Array) -> void:
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element(elemento)
	for g in glifos:
		_poner(String(g))
	lanzador.cooldown_left[0] = 0.0
	lanzador.feedback_text = ""
	if jugador.tinta != null:
		jugador.tinta.actual = jugador.tinta.maxima
		jugador.tinta.frascos = 0


## Como la paleta (`place_sigil`) pero sin el tope de huecos abiertos del libro «bosque»: cada glifo al primer sector libre de los 8.
func _poner(glifo: String) -> void:
	for i in range(8):
		var sector: Vector2 = Vector2(cos(TAU / 8.0 * float(i)), sin(TAU / 8.0 * float(i))) if i > 0 else Vector2.RIGHT
		var libre: bool = true
		for c in lanzador.current_components:
			if (c["direction"] as Vector2).is_equal_approx(sector) and not (c["sigils"] as Array).is_empty():
				libre = false
		if libre:
			lanzador.add_sigil(sector, glifo, 1.0)
			return


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
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = 0
	_ok("el lanzador del juego tiene tinta", lanzador.tinta != null)
	await _cobro_y_recarga()
	_comprobar_avisos()
	_diferencias()
	_frases()
	_libro()


## 1. tinta y recarga del resumen = lo que cuesta y lo que tarda de verdad
func _cobro_y_recarga() -> void:
	var casos: int = 0
	var lanzados: int = 0
	var malos: int = 0
	for elemento in ELEMENTOS:
		for glifos in RECETAS:
			_componer(String(elemento), glifos)
			var r: Dictionary = lanzador.resumen_pagina(0)
			var res: Dictionary = r["resumen"]
			casos += 1
			var h: Hechizo = r["hechizo"]
			if not (h != null and is_equal_approx(float(res["tinta"]), h.coste_tinta) and is_equal_approx(float(res["recarga"]), h.recarga) and String(res["forma"]) == h.forma):
				malos += 1
				print("      el resumen no dice lo del Hechizo: %s %s" % [elemento, str(glifos)])
				continue
			lanzador.cast_page(0)
			if not lanzador.modo_lanzar:
				print("      (no se prepara, solo se mira el aviso) %s %s → «%s»" % [elemento, str(glifos), lanzador.feedback_text])
				continue
			var datos: Dictionary = lanzador._preparado
			var tinta0: float = jugador.tinta.actual
			var origen: Vector3 = jugador.position + Vector3.RIGHT * Terreno3D.casilla * 1.0
			lanzador._salir_modo(true)
			lanzador._preparado = {}
			var salio: bool = lanzador.lanzar_ahora(datos, jugador.position if not h.en_punto else origen, Vector3.RIGHT, false)
			if salio:
				lanzados += 1
				var cobrado: float = tinta0 - jugador.tinta.actual
				var bien: bool = absf(cobrado - float(res["tinta"])) < 0.01 and is_equal_approx(lanzador.cooldown_total[0], float(res["recarga"]))
				bien = bien and is_equal_approx(float(r["tinta_prevista"]), float(res["tinta"]))      # sin pigmento: la prevista es el coste
				if not bien:
					malos += 1
					print("      %s %s: cobra %.2f y recarga %.2f, el resumen dice %.2f y %.2f" % [elemento, str(glifos), cobrado, lanzador.cooldown_total[0], float(res["tinta"]), float(res["recarga"])])
			for v in _vivos():
				(v as Node).queue_free()
			lanzador.cooldown_left[0] = 0.0
			await avanzar(2)
	_ok("resumen: tinta y recarga = lo que se cobra y se recarga al lanzar (%d recetas × elementos, %d lanzadas, %d no cuadran)" % [casos, lanzados, malos], malos == 0 and casos == RECETAS.size() * ELEMENTOS.size())
	_ok("resumen: se lanzaron de verdad al menos 24 de las 36 (%d)" % lanzados, lanzados >= 24)


## 2. los avisos del libro son los de `_preparar_pagina`
func _comprobar_avisos() -> void:
	# altura rechazada: un sólido (tierra) más alto de lo que se sube
	var provocado: bool = false
	for n in range(1, 7):
		_componer("tierra", _repetir("altura", n))
		var r: Dictionary = lanzador.resumen_pagina(0)
		if (r["avisos"] as Array).any(func(a): return String(a).begins_with("Demasiada altura")):
			lanzador.cast_page(0)
			_ok("avisos: altura rechazada (%d ᛏ de tierra): el libro dice «%s»" % [n, str((r["avisos"] as Array)[0])], not lanzador.modo_lanzar and lanzador.feedback_text == String((r["avisos"] as Array)[0]))
			provocado = true
			break
	_ok("avisos: se pudo provocar el rechazo por altura", provocado)
	# glifo aparcado: se avisa y se sigue
	_componer("fuego", ["flecha", "retardo"])
	var r2: Dictionary = lanzador.resumen_pagina(0)
	lanzador.cast_page(0)
	_ok("avisos: «Aún sin uso» del libro = el de cast_page («%s»)" % lanzador.feedback_text, (r2["avisos"] as Array).size() == 1 and lanzador.feedback_text == String((r2["avisos"] as Array)[0]) and lanzador.feedback_text.begins_with("Aún sin uso"))
	lanzador._cancelar_modo()
	lanzador._preparado = {}
	# tinta insuficiente
	_componer("fuego", ["flecha", "repeticion"])
	jugador.tinta.actual = 1.0
	jugador.tinta.frascos = 0
	var r3: Dictionary = lanzador.resumen_pagina(0)
	lanzador.cast_page(0)
	_ok("avisos: «Tinta insuficiente» del libro = el de cast_page («%s»)" % lanzador.feedback_text, (r3["avisos"] as Array).size() == 1 and lanzador.feedback_text == String((r3["avisos"] as Array)[0]) and not lanzador.modo_lanzar and lanzador.feedback_text.begins_with("Tinta insuficiente"))
	# y la función pura dice lo mismo sin pasar por el libro
	var h: Hechizo = r3["hechizo"]
	_ok("avisos: `avisos_de` pura = la del libro", Lanzador3D.avisos_de(h, r3["rune"], PackedStringArray(), jugador.tinta) == r3["avisos"])
	_ok("avisos: sin tinta (pruebas, laboratorios) no hay aviso de tinta", Lanzador3D.avisos_de(h, r3["rune"], PackedStringArray()).is_empty())
	# la tinta cambia → el aviso cambia, y la diferencia con el glifo anterior se conserva
	var texto_antes: String = String(r3["texto"])
	jugador.tinta.actual = jugador.tinta.maxima
	var r4: Dictionary = lanzador.resumen_pagina(0)
	_ok("avisos: con tinta otra vez el aviso desaparece", (r4["avisos"] as Array).is_empty())
	_ok("avisos: cambiar la tinta no borra lo que aportó el último glifo (%s)" % texto_antes, String(r4["texto"]) == texto_antes and not texto_antes.is_empty())
	# sin elemento y sin glifos
	lanzador.clear_sequence()
	_ok("avisos: página vacía = sin avisos", (lanzador.resumen_pagina(0)["avisos"] as Array).is_empty() and bool(lanzador.resumen_pagina(0)["vacia"]))
	lanzador.add_sigil(Vector2.RIGHT, "flecha", 1.0)
	_ok("avisos: glifos sin elemento = «Sin elemento»", (lanzador.resumen_pagina(0)["avisos"] as Array).has("Sin elemento"))
	lanzador.clear_sequence()
	lanzador.place_element("fuego")
	var falta: Array = lanzador.resumen_pagina(0)["avisos"]
	lanzador.cast_page(0)
	_ok("avisos: elemento sin glifos = el de cast_page («%s»)" % lanzador.feedback_text, falta.size() == 1 and String(falta[0]) == lanzador.feedback_text)
	_componer("fuego", ["barrera"])
	_ok("avisos: la barrera «Nace donde apuntas» sale como nota, no como aviso", (lanzador.resumen_pagina(0)["notas"] as Array).has("Nace donde apuntas") and (lanzador.resumen_pagina(0)["avisos"] as Array).is_empty())


func _repetir(glifo: String, n: int) -> Array:
	var l: Array = []
	for _i in range(n):
		l.append(glifo)
	return l


## 3. añadir un glifo cambia solo lo suyo
func _diferencias() -> void:
	var casos: Array = [["ᛁ", "linea_x", ["flecha"]], ["ᛇ", "flecha", ["linea_x"]], ["ᛉ", "permanencia", ["flecha"]], ["ᚠ", "repeticion", ["flecha"]]]
	for caso in casos:
		for elemento in ELEMENTOS:
			var nombre: String = "%s %s + %s" % [caso[0], elemento, str(caso[2])]
			_componer(String(elemento), caso[2])
			_poner(String(caso[1]))
			var r: Dictionary = lanzador.resumen_pagina(0)
			var dif: Array = r["diferencia"]
			var ajenos: Array = []
			var propios: int = 0
			for d in dif:
				var g: String = String((d as Dictionary)["glifo"])
				if g == String(caso[1]):
					propios += 1
				elif g != "":
					ajenos.append("%s (%s)" % [(d as Dictionary)["campo"], g])
				elif not _es_derivado_o_potencia(String((d as Dictionary)["campo"])):
					ajenos.append("%s (sin origen de glifo)" % (d as Dictionary)["campo"])
			_ok("%s: cambia solo lo del glifo (%d campos suyos) y los derivados%s" % [nombre, propios, "" if ajenos.is_empty() else " · ajenos: " + str(ajenos)], propios > 0 and ajenos.is_empty())
			var texto: String = String(r["texto"])
			_ok("%s: la frase no está vacía ni dice «null» → «%s»" % [nombre, texto], not texto.is_empty() and not texto.contains("null") and Hechizo.texto_cambio(dif) == texto)
			for f in (r["frases"] as Array):
				if String((f as Dictionary)["texto"]).is_empty() or String((f as Dictionary)["texto"]).contains("null"):
					_ok("%s: cada frase tiene texto" % nombre, false)


func _es_derivado_o_potencia(campo: String) -> bool:
	return Hechizo.DERIVADOS.has(campo) or campo == "dano" or campo == "en_punto"      # en_punto: la regla del sólido quieto (origen «derivado:solido»), no un glifo


## 4. las frases con unidades, sobre diferencias hechas a mano
func _frases() -> void:
	var casos: Array = [
		[{"campo": "semiejes.x", "antes": 0.5, "despues": 1.0, "glifo": "linea_x"}, "+1 casilla de ancho"],
		[{"campo": "semiejes.z", "antes": 0.5, "despues": 1.5, "glifo": "linea_z"}, "+2 casillas de fondo"],
		[{"campo": "semiejes.y", "antes": 1.0, "despues": 0.5, "glifo": "altura"}, "−1 casilla de alto"],
		[{"campo": "distancia_max", "antes": 3.0, "despues": 4.0, "glifo": "flecha"}, "+1 m de alcance"],
		[{"campo": "permanencia", "antes": 0.0, "despues": 2.0, "glifo": "permanencia"}, "+2 s"],
		[{"campo": "copias", "antes": 1, "despues": 2, "glifo": "repeticion"}, "+1 copia"],
		[{"campo": "copias", "antes": 1, "despues": 3, "glifo": "repeticion"}, "+2 copias"],
		[{"campo": "dano", "antes": 13.0, "despues": 26.0, "glifo": ""}, "daño 13 → 26"],
		[{"campo": "coste_tinta", "antes": 8.0, "despues": 18.0, "glifo": ""}, "tinta 8 → 18"],
		[{"campo": "en_punto", "antes": false, "despues": true, "glifo": "barrera"}, "nace donde apuntas"],
		[{"campo": "recarga", "antes": 2.0, "despues": 2.5, "glifo": ""}, "recarga 2,0 → 2,5 s"],
		[{"campo": "veneno", "antes": 0.0, "despues": 3.0, "glifo": "x"}, "veneno: 0 → 3"],
	]
	for caso in casos:
		var t: String = Hechizo.texto_cambio([caso[0]])
		_ok("frase: %s → «%s»" % [str(caso[0]["campo"]), t], t.contains(String(caso[1])) and not t.contains("null"))
	var libre: Array = [{"campo": "color", "antes": "#fff", "despues": "#000", "glifo": ""}]
	_ok("frase: un campo sin frase propia sale «campo: antes → después» (%s)" % Hechizo.texto_cambio(libre), Hechizo.texto_cambio(libre) == "color: #fff → #000")
	_ok("frase: sin cambios, texto vacío", Hechizo.texto_cambio([]) == "")


## 5. cambiar de página, deshacer y vaciar
func _libro() -> void:
	_componer("fuego", ["flecha"])
	_poner("linea_x")
	var a: String = String(lanzador.resumen_pagina(0)["texto"])
	lanzador.select_page(1)
	lanzador.place_element("agua")
	_poner("barrera")
	var b: Dictionary = lanzador.resumen_pagina(1)
	lanzador.select_page(0)
	_ok("libro: cada página guarda su último cambio (la 1 sigue diciendo «%s»)" % a, String(lanzador.resumen_pagina(0)["texto"]) == a and String(b["texto"]) != a)
	lanzador.undo_last()
	var d: Array = lanzador.resumen_pagina(0)["diferencia"]
	var ancho: Dictionary = {}
	for x in d:
		if String((x as Dictionary)["campo"]) == "semiejes.x":
			ancho = x
	_ok("libro: deshacer ᛁ da el cambio contrario: %s" % Hechizo.texto_cambio(d), not ancho.is_empty() and float(ancho["despues"]) < float(ancho["antes"]) and Hechizo.texto_cambio(d).contains("−"))
	var res: Dictionary = lanzador.resumen_pagina(0)["resumen"]
	var directo: Hechizo = Lanzador3D.receta_de_ficha(lanzador.pages[0], lanzador.rune_database.get(lanzador.pages[0]["element"]), lanzador.tinta)["hechizo"]
	_ok("libro: el resumen de la página = el del Hechizo que construye el lanzamiento (misma fusión)", directo.resumen() == res)
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.select_page(1)
	lanzador.clear_sequence()
	lanzador.select_page(0)
