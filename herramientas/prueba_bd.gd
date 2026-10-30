extends SceneTree
## F0 de PLAN_BASE_DATOS (29/10, Juego): `BD` carga las siete tablas de `nucleo/datos/*.tsv` y `Objetos` se genera de ellas.
## Comprueba tres cosas: (1) las tablas están bien formadas y se refieren unas a otras sin huecos (ids, vías, etiquetas, recetas, botín);
## (2) lo que `Objetos` generaba a mano antes (DATOS, PLANTAS, MINERALES, CONSUMIBLES...) sale IGUAL de las tablas, para que los 32 sitios
## que lo leen no noten el cambio; (3) la mochila usa la pila de cada objeto (`Objetos.pila`) en vez de un 9 para todo.
## Sin ventana ni escena.
##   godot --headless --path . --script res://herramientas/prueba_bd.gd
## o, desde la raíz del repo:  tools\prueba_una.cmd prueba_bd

const ETIQUETAS_BD: Array = ["calor", "frio", "agua", "electrico", "tierra", "viento", "resonante", "vital", "tinta", "raro", "toxico", "proteccion"]
const ELEMENTOS: Array = ["fuego", "agua", "tierra", "hielo", "rayo", "viento"]
const VIAS_FIJAS: Array = ["pulso", "E", "golpe", "romper", "abrir", "sintesis", "oro", "recompensa", "segar", "consumido", "bordado", "escudo ardiendo", ""]
## Las `de` de fuentes.tsv que no son un objeto: plantas del mundo, reactivos, enemigos, cofres, vendedores y prendas.
const PIEZAS: Array = ["seta", "flor", "raiz", "alga", "bayas", "lavanda", "helecho", "flor_silvestre", "rocas_pequenas", "musgo", "helecho_cueva", "seta_palida",
	"veta", "cristal_resonante", "jarron", "lava", "geoda", "hierba", "arbol", "colmena", "nido", "telarana", "seto", "goblin", "goblin_escudo", "limo", "chaman",
	"golem", "elemental", "cofre", "cofre_epico", "cofre_legendario", "alquimista", "guardabosques", "basalto", "esquirla_cristal", "seta_resonante", "capa",
	"tunica", "capucha", ""]
## Los 36 ids que tenía `Objetos.DATOS` antes de F0 (sacados de `git show HEAD:nucleo/objetos.gd`).
const IDS_DE_ANTES: Array = ["oro", "pocion", "tonico_tinta", "balsamo_protector", "infusion_brezo", "lavanda", "baya", "helecho", "piedra", "flor_silvestre",
	"seta", "seta_electrificada", "seta_asada", "seta_helada", "seta_humeda", "esporas", "flor_luna", "flor_ardiente", "flor_rocio", "flor_chispa", "petalos",
	"flor_escarcha", "raiz", "raiz_cenizas", "raiz_hinchada", "raiz_magnetica", "cristal_tierra", "seta_resonante", "alga_cueva", "alga_seca", "mineral_veta",
	"esquirla_cristal", "basalto", "colmillo_goblin", "nucleo_eco", "geoda_resonante"]

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_carga()
	_referencias()
	_recetas_y_botin()
	_compatibilidad()
	_mochila()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _carga() -> void:
	BD.recargar()
	_ok("1 las siete tablas cargan sin filas mal formadas", BD.errores().is_empty(), str(BD.errores()))
	_ok("1 objetos: 77 filas", BD.objetos().size() == 77, str(BD.objetos().size()))
	_ok("1 las demás tablas no están vacías", not BD.fuentes().is_empty() and not BD.recetas().is_empty() and not BD.mejoras().is_empty()
		and not BD.estados_mundo().is_empty() and not BD.tabla("goblin").is_empty() and not BD.reactivos("arbol").is_empty())
	var pocion: Dictionary = BD.objeto("pocion")
	_ok("1 conversión: número, lista, Color, efecto y usos", int(pocion.get("pila", 0)) == 9 and BD.objeto("seta_asada")["etiquetas"] == ["vital", "calor"]
		and pocion["color"] is Color and (pocion["efecto"] as Dictionary) == {"cura": 40} and (pocion["usos"] as Array).size() == 2)
	_ok("1 «-» es vacío: oro sin etiquetas ni efecto, color de la fuente sin condición", (BD.objeto("oro")["etiquetas"] as Array).is_empty()
		and (BD.objeto("oro")["efecto"] as Dictionary).is_empty() and String(BD.fuentes_de("seta")[0]["condicion"]) == "")
	var ant: Dictionary = BD.objeto("antidoto")["efecto"]
	_ok("1 efecto con texto y números: antidoto", ant == {"cura_estado": "veneno", "inmune": "veneno", "dura": 60}, str(ant))
	_ok("1 decimales: mejoras.por_nivel de tinta_frasco es 0,1", is_equal_approx(float(BD.mejora("tinta_frasco")["por_nivel"]), 0.1))
	_ok("1 un id que no existe da {} y [] (sin romper)", BD.objeto("no_existe").is_empty() and BD.receta("x").is_empty() and BD.tabla("x").is_empty()
		and BD.fuentes_de("x").is_empty() and BD.reactivos("x").is_empty() and BD.mejora("x").is_empty() and BD.estado_mundo("x").is_empty())
	# Una fila con otro número de columnas o un id repetido no se carga y se cuenta: lo comprobamos con el parser genérico.
	var cab: PackedStringArray = PackedStringArray(["id", "etiquetas", "potencia", "efecto", "color", "nota"])
	var fila: Dictionary = BD._fila(cab, PackedStringArray(["x", "calor, frio", "3", "a=1;b=2.5;c=z", "#FF0000", "-"]))
	_ok("1 _fila genérico: lista, número, efecto, color y «-»", fila["etiquetas"] == ["calor", "frio"] and fila["potencia"] == 3 and (fila["efecto"] as Dictionary) == {"a": 1, "b": 2.5, "c": "z"}
		and (fila["color"] as Color).is_equal_approx(Color(1, 0, 0)) and fila["nota"] == "", str(fila))


func _referencias() -> void:
	var objs: Dictionary = BD.objetos()
	var malas: Array = []
	for id in objs:
		for e in (objs[id]["etiquetas"] as Array):
			if not ETIQUETAS_BD.has(e):
				malas.append("%s:%s" % [id, e])
	_ok("2 toda etiqueta de objetos.tsv está en el vocabulario cerrado", malas.is_empty(), str(malas))
	malas = []
	for id in objs:
		if String(objs[id]["calidad"]) == "epico" and String(objs[id]["uso"]) == "ingrediente" and int(objs[id]["potencia"]) < 4:
			malas.append(id)
	_ok("2 los ingredientes épicos tienen potencia >= 4 (la ropa épica no aporta etiquetas)", malas.is_empty(), str(malas))
	malas = []
	for id in objs:
		if (objs[id]["etiquetas"] as Array).is_empty() != (int(objs[id]["potencia"]) == 0):
			malas.append(id)
	_ok("2 potencia 0 si y solo si no tiene etiquetas", malas.is_empty(), str(malas))
	var de_malos: Array = []
	var vias_malas: Array = []
	var obj_malos: Array = []
	for f in BD.fuentes():
		var de: String = String(f["de"])
		if not objs.has(de) and not PIEZAS.has(de):
			de_malos.append(de)
		var via: String = String(f["via"])
		var ok_via: bool = ELEMENTOS.has(via) or VIAS_FIJAS.has(via) or (via.begins_with("golpes:") and via.substr(7).is_valid_int())
		if not ok_via:
			vias_malas.append(via)
		if not objs.has(String(f["objeto"])):
			obj_malos.append(f["objeto"])
		if float(f["prob"]) <= 0.0 or float(f["prob"]) > 1.0 or int(f["min"]) > int(f["max"]):
			vias_malas.append("%s prob/min/max" % f["objeto"])
	_ok("2 cada `de` de fuentes es un objeto o una pieza conocida", de_malos.is_empty(), str(de_malos))
	_ok("2 cada `via` de fuentes es un elemento, pulso, golpes:n, E, golpe, romper...", vias_malas.is_empty(), str(vias_malas))
	_ok("2 cada `objeto` de fuentes existe en objetos.tsv", obj_malos.is_empty(), str(obj_malos))
	var sin_fuente: Array = []
	for id in objs:
		if BD.fuentes_de(id).is_empty():
			sin_fuente.append(id)
	_ok("2 todo objeto sale de algún sitio (tiene al menos una fila en fuentes)", sin_fuente.is_empty(), str(sin_fuente))
	var estados_mal: Array = []
	for id in BD.mejoras():
		var m: Dictionary = BD.mejoras()[id]
		if int(m["tope"]) <= 0 or float(m["por_nivel"]) <= 0.0:
			estados_mal.append(id)
	_ok("2 cada mejora tiene tope y por_nivel positivos", estados_mal.is_empty(), str(estados_mal))
	var zonas_mal: Array = []
	for p in ["hierba", "arbol", "colmena", "cofre"]:
		if BD.reactivos(p).is_empty():
			zonas_mal.append(p)
	_ok("2 reactivos_mapa: hierba, árbol, colmena y cofre reaccionan", zonas_mal.is_empty(), str(zonas_mal))


func _recetas_y_botin() -> void:
	var objs: Dictionary = BD.objetos()
	var da_malo: Array = []
	var req_malo: Array = []
	var ancla_mala: Array = []
	for id in BD.recetas():
		var r: Dictionary = BD.recetas()[id]
		var da: String = String(r["da"])
		if da.begins_with("mejora:"):
			if not BD.mejoras().has(da.substr(7)):
				da_malo.append(id)
		else:
			var p: PackedStringArray = da.split(":")
			if p.size() != 2 or not objs.has(p[0]) or not p[1].is_valid_int() or p[1].to_int() <= 0:
				da_malo.append(id)
		if (r["requiere"] as Array).is_empty():
			req_malo.append(id)
		for q in (r["requiere"] as Array):
			var t: PackedStringArray = String(q).split(">=")
			if t.size() != 2 or not ETIQUETAS_BD.has(t[0]) or not t[1].is_valid_int():
				req_malo.append("%s:%s" % [id, q])
		if String(r["ancla"]) != "" and not objs.has(String(r["ancla"])):
			ancla_mala.append(id)
	_ok("3 cada `da` de recetas es objeto:n existente o mejora:<id> de mejoras.tsv", da_malo.is_empty(), str(da_malo))
	_ok("3 cada `requiere` usa solo etiquetas del vocabulario y >=", req_malo.is_empty(), str(req_malo))
	_ok("3 cada `ancla` es un objeto que existe", ancla_mala.is_empty(), str(ancla_mala))
	var botin_mal: Array = []
	var n_filas: int = 0
	for tabla in ["jarron_bosque", "jarron_ruinas", "jarron_cueva", "jarron_campamento", "jarron_santuario", "jarron_clasico", "jarron_atardecer", "jarron_agua", "jarron_fuego", "jarron_hielo",
			"hierba_segada", "tronco_golpe", "seto_quemado", "goblin", "goblin_escudo", "limo", "chaman", "golem", "elemental", "cofre_pequeno"]:
		var filas: Array = BD.tabla(tabla)
		if filas.is_empty():
			botin_mal.append("vacía " + tabla)
		for f in filas:
			n_filas += 1
			var o: String = String(f["objeto"])
			if o != "nada" and not objs.has(o):
				botin_mal.append("%s: %s no existe" % [tabla, o])
			# F1: una fila con `independiente = si` guarda en `peso` una PROBABILIDAD (0 < p <= 1); las demás, un peso > 0.
			var indep: bool = String(f.get("independiente", "")) == "si"
			if float(f["peso"]) <= 0.0 or (indep and float(f["peso"]) > 1.0) or int(f["min"]) > int(f["max"]):
				botin_mal.append("%s: %s peso/min/max" % [tabla, o])
			if String(f.get("independiente", "")) not in ["", "si"]:
				botin_mal.append("%s: %s independiente «%s»" % [tabla, o, f.get("independiente", "")])
	_ok("3 botin_tablas: cada objeto existe o es `nada`, peso > 0 (probabilidad <= 1 si es independiente) y min <= max (%d filas de 20 tablas)" % n_filas, botin_mal.is_empty() and n_filas == 54, str(botin_mal) + " " + str(n_filas))


func _compatibilidad() -> void:
	var faltan: Array = []
	for id in IDS_DE_ANTES:
		if not Objetos.DATOS.has(id):
			faltan.append(id)
	_ok("4 Objetos.DATOS contiene los 36 ids de antes", faltan.is_empty() and IDS_DE_ANTES.size() == 36, str(faltan))
	_ok("4 DATOS tiene todas las filas de la tabla", Objetos.DATOS.size() == BD.objetos().size())
	var claves_mal: Array = []
	for id in IDS_DE_ANTES:
		var d: Dictionary = Objetos.DATOS[id]
		for k in ["nombre", "desc", "color", "forma", "categoria", "etiquetas", "potencia", "pila", "uso", "modelo", "zona"]:
			if not d.has(k):
				claves_mal.append("%s.%s" % [id, k])
		if not (d["color"] is Color) or d.has("calidad") != (id in ["nucleo_eco", "geoda_resonante"]):
			claves_mal.append(id + " color/calidad")
	_ok("4 cada entrada conserva nombre, desc, color, forma y gana categoria, etiquetas, potencia, pila, uso, modelo, zona", claves_mal.is_empty(), str(claves_mal))
	_ok("4 `usos` solo en los 8 que ya los tenían", _con_usos() == ["balsamo_protector", "baya", "helecho", "infusion_brezo", "lavanda", "nucleo_eco", "pocion", "tonico_tinta"], str(_con_usos()))
	_ok("4 PLANTAS.seta igual que antes", Objetos.PLANTAS["seta"] == {"base": "seta", "tabla": {"rayo": "seta_electrificada", "fuego": "seta_asada", "hielo": "seta_helada",
		"agua": "seta_humeda", "viento": "esporas"}}, str(Objetos.PLANTAS["seta"]))
	_ok("4 PLANTAS.flor igual que antes", Objetos.PLANTAS["flor"] == {"base": "flor_luna", "tabla": {"fuego": "flor_ardiente", "agua": "flor_rocio", "rayo": "flor_chispa",
		"viento": "petalos", "hielo": "flor_escarcha"}}, str(Objetos.PLANTAS["flor"]))
	_ok("4 PLANTAS.raiz igual que antes", Objetos.PLANTAS["raiz"] == {"base": "raiz", "tabla": {"fuego": "raiz_cenizas", "agua": "raiz_hinchada", "rayo": "raiz_magnetica",
		"tierra": "cristal_tierra"}}, str(Objetos.PLANTAS["raiz"]))
	_ok("4 PLANTAS.alga igual que antes (la reacción de la charca electrificada espera a su fase)", Objetos.PLANTAS["alga"] == {"base": "alga_cueva", "tabla": {"fuego": "alga_seca"}}, str(Objetos.PLANTAS["alga"]))
	_ok("4 PLANTAS nuevas: musgo, helecho de cueva y seta pálida, con base y sin tabla", Objetos.PLANTAS["musgo"] == {"base": "musgo_cueva", "tabla": {}}
		and Objetos.PLANTAS["helecho_cueva"] == {"base": "helecho_cueva", "tabla": {}} and Objetos.PLANTAS["seta_palida"] == {"base": "seta_palida", "tabla": {}}
		and Objetos.PLANTAS.size() == 7, str(Objetos.PLANTAS.keys()))
	_ok("4 MINERALES igual que antes", Objetos.MINERALES == {"veta": {"via": "tierra", "golpes": 1, "da": "mineral_veta"},
		"cristal_resonante": {"via": "golpe", "golpes": 2, "da": "esquirla_cristal"}, "jarron": {"via": "romper", "golpes": 1, "da": "esquirla_cristal"}}, str(Objetos.MINERALES))
	_ok("4 mineral_de sigue dando lo mismo", Objetos.mineral_de("veta", "tierra") == "mineral_veta" and Objetos.mineral_de("cristal_resonante", "golpe") == "esquirla_cristal"
		and Objetos.mineral_de("jarron", "romper") == "esquirla_cristal" and Objetos.mineral_de("veta", "fuego") == "")
	var c: PackedStringArray = Objetos.CONSUMIBLES
	_ok("4 CONSUMIBLES empieza por poción, tónico, bálsamo e infusión (el orden de R)", c.size() >= 4 and c[0] == "pocion" and c[1] == "tonico_tinta" and c[2] == "balsamo_protector"
		and c[3] == "infusion_brezo", str(c))
	var todos_equipar: bool = true
	for id in BD.objetos():
		if (String(BD.objeto(id)["uso"]) == "equipar") != c.has(id):
			todos_equipar = false
	_ok("4 CONSUMIBLES son exactamente los objetos con uso = equipar", todos_equipar)
	_ok("4 CURAN: la poción y la infusión curan (y la grande); el tónico y la seta no", Objetos.cura("pocion") and Objetos.cura("infusion_brezo") and Objetos.cura("pocion_grande")
		and not Objetos.cura("tonico_tinta") and not Objetos.cura("seta"))
	_ok("4 CLAVE: llaves, perla y aletas", Objetos.CLAVE.has("llave") and Objetos.CLAVE.has("llave_goblin") and Objetos.CLAVE.has("perla") and Objetos.CLAVE.has("aletas")
		and not Objetos.CLAVE.has("pocion"))
	_ok("4 categoria() agrupa como antes", Objetos.categoria("pocion") == "pociones" and Objetos.categoria("tonico_tinta") == "pociones" and Objetos.categoria("pigmento_eco") == "pociones"
		and Objetos.categoria("llave") == "clave" and Objetos.categoria("capa") == "clave" and Objetos.categoria("glifo_resonancia") == "clave"
		and Objetos.categoria("seta") == "componentes" and Objetos.categoria("oro") == "componentes" and Objetos.categoria("nucleo_eco") == "componentes"
		and Objetos.categoria("no_existe") == "componentes")
	_ok("4 categoria_bd, etiquetas y potencia", Objetos.categoria_bd("seta") == "hongo" and Objetos.categoria_bd("pocion") == "consumible" and Objetos.categoria_bd("no_existe") == ""
		and Objetos.etiquetas("seta_asada") == ["vital", "calor"] and Objetos.potencia("nucleo_eco") == 5 and Objetos.potencia("oro") == 0 and Objetos.etiquetas("no_existe").is_empty())
	_ok("4 es_consumible / es_ingrediente", Objetos.es_consumible("pocion") and not Objetos.es_consumible("seta") and Objetos.es_ingrediente("seta") and not Objetos.es_ingrediente("pocion")
		and not Objetos.es_ingrediente("oro"))
	_ok("4 efecto(pocion).cura == 40 y los otros tres consumibles de siempre", Objetos.efecto("pocion").get("cura") == 40 and int(Objetos.efecto("tonico_tinta")["frascos"]) == 1
		and is_equal_approx(float(Objetos.efecto("balsamo_protector")["dura"]), 20.0) and is_equal_approx(float(Objetos.efecto("infusion_brezo")["tasa"]), 3.0)
		and is_equal_approx(float(Objetos.efecto("infusion_brezo")["dura"]), 12.0) and Objetos.efecto("seta").is_empty())
	_ok("4 usos(pocion) da dos frases; seta ninguna", Objetos.usos("pocion").size() == 2 and Objetos.usos("seta").is_empty())
	_ok("4 calidad y color de siempre", Objetos.calidad("nucleo_eco") == "epico" and Objetos.calidad("seta") == "comun" and Objetos.calidad("no_existe") == "comun"
		and Objetos.color("pocion").is_equal_approx(Color("#FF594D")) and Objetos.color("no_existe") == Color.WHITE)
	_ok("4 existe / nombre", Objetos.existe("seta") and not Objetos.existe("no_existe") and Objetos.nombre("pocion") == "Poción de vida" and Objetos.nombre("no_existe") == "no_existe")


func _con_usos() -> Array:
	var r: Array = []
	for id in Objetos.DATOS:
		if Objetos.DATOS[id].has("usos"):
			r.append(id)
	r.sort()
	return r


func _mochila() -> void:
	_ok("5 Objetos.pila: seta 20, frasco 9, capa 1, oro 999, desconocido 9", Objetos.pila("seta") == 20 and Objetos.pila("pocion") == 9 and Objetos.pila("capa") == 1
		and Objetos.pila("oro") == 999 and Objetos.pila("no_existe") == 9)
	var e: Estado = Estado.new()
	_ok("5 mochila vacía: 8 huecos de 20 setas = 160; de capas = 8; de un id desconocido = 72", e.sitio_para("seta") == 160 and e.sitio_para("capa") == 8 and e.sitio_para("zzz") == 72)
	_ok("5 meter 20 setas ocupa UN hueco", e.agregar("seta", 20) == 20 and e.huecos_usados() == 1 and e.cuenta("seta") == 20)
	_ok("5 con 20 setas caben 7 huecos más de 20 = 140", e.sitio_para("seta") == 140, str(e.sitio_para("seta")))
	_ok("5 la capa tiene pila 1: tres capas = tres huecos", e.agregar("capa", 3) == 3 and e.huecos_usados() == 4 and e.sitio_para("capa") == 4)
	_ok("5 una 21.ª seta abre un segundo hueco", e.agregar("seta", 1) == 1 and e.huecos_usados() == 5)
	_ok("5 completar la pila de setas: caben 19 del hueco medio vacío + 3 huecos libres de 20", e.sitio_para("seta") == 19 + 3 * 20, str(e.sitio_para("seta")))
	var f: Estado = Estado.new()
	f.agregar("pocion", 9)
	_ok("5 las pociones siguen a 9 por hueco", f.huecos_usados() == 1 and f.agregar("pocion", 1) == 1 and f.huecos_usados() == 2)
	var g: Estado = Estado.new()
	g.agregar("zzz", 10)
	_ok("5 un id fuera de la tabla sigue a 9 por hueco (como siempre)", g.huecos_usados() == 2)
