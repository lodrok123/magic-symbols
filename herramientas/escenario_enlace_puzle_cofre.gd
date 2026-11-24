extends "res://herramientas/escenario_base.gd"
## PUZLE → COFRE Y CAMPAMENTO COMO PUZLE (24/11/2026). En el Bosque 01 generado (semilla 12): un puzle del catálogo («Peso de la piedra»)
## y un CAMPAMENTO puestos a mano en dos salas, y el cofre del tesoro enlazado a los dos (`pz<sala>`). Mira el .txt (la regla del puzle, el
## vigía del campamento, el `aparece_si` con las dos flags) y, en el juego, que el cofre no aparece hasta que se cumplen las dos cosas.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_enlace_puzle_cofre.gd

const Generador = preload("res://herramientas/generador_mapas/generador_mazmorra.gd")
const Exportador = preload("res://herramientas/generador_mapas/exportador_mapa.gd")
const NOMBRE: String = "ZzEnlacePuzle"


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	var par: Dictionary = {"algoritmo": "bosque", "semilla": 12, "ancho": 48, "alto": 42, "nombre": NOMBRE, "barreras": 0, "puzles": 0,
		"salida_a": "CuevaTerrafina:a_bosque=desde_cueva, Precipicio:inicio, Ruinas:inicio, Bosque_02:desde_bosque01",
		"lados_salida": "s, o, s, e", "paso_tierra": 2, "estilo": "bosque", "luz": "bosque", "salas_cerradas": 0}
	# Las salas: la más grande sin papel para el campamento y otra libre para el puzle.
	var base: Dictionary = Generador.new().generar(par)
	var libres: Array = (base["salas"] as Array).filter(func(s: Dictionary) -> bool: return String(s["rol"]) == "")
	libres.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["rect"] as Rect2i).get_area() > (b["rect"] as Rect2i).get_area())
	_ok("0 hay al menos dos salas libres", libres.size() >= 2, str(libres.size()))
	if libres.size() < 2:
		return
	var s_camp: int = int(libres[0]["id"])
	var s_pz: int = -1
	for s in libres.slice(1):
		var prueba: Dictionary = Generador.new().generar(par, {}, {}, {int(s["id"]): "piedra_premio", s_camp: "campamento"})
		if String((prueba["puzles"] as Dictionary).get(int(s["id"]), "")) == "piedra_premio":
			s_pz = int(s["id"])
			break
	_ok("0 «Peso de la piedra» cabe en otra sala", s_pz >= 0)
	if s_pz < 0:
		return
	var puzles: Dictionary = {s_pz: "piedra_premio", s_camp: "campamento"}
	var m0: Dictionary = Generador.new().generar(par, {}, {}, puzles)
	_ok("1 el campamento pedido a mano se monta en su sala", String((m0["puzles"] as Dictionary).get(s_camp, "")) == "campamento" and "\n".join(m0["lineas"]).contains("camp1_vigia vigia"),
		"\n".join(m0["avisos"]))
	var enl: Dictionary = m0["salas_enlazables"]
	_ok("1 los dos se pueden enlazar a un cofre (herramienta)", enl.values().has(s_pz) and enl.values().has(s_camp), str(enl))
	# El cofre del tesoro, enlazado a los dos.
	var tesoro: Vector2i = Vector2i(-1, -1)
	for o in m0["objetos"]:
		if String(o["tipo"]) == "cofre_tesoro":
			tesoro = o["c"]
	_ok("1 hay cofre del tesoro", tesoro.x >= 0)
	var ap: Array = [{"cofre": "%d,%d" % [tesoro.x, tesoro.y], "enemigos": ["pz%d" % s_pz, "pz%d" % s_camp]}]
	var m: Dictionary = Generador.new().generar(par, {}, {}, puzles, {}, [], ap)
	var txt: String = "\n".join(m["lineas"])
	var linea_cofre: String = ""
	for l in m["lineas"]:
		if String(l).begins_with("; pieza tesoro cofre"):
			linea_cofre = l
	_ok("2 la regla del puzle pone su flag al bajar la placa", txt.contains("; puzle apa_tesoro_pz%d cuando=cat1_placa.pulsado hace=flag.poner(zzenlacepuzle.tesoro.pz%d)" % [s_pz, s_pz]), txt)
	_ok("2 el cofre pide las dos flags (puzle y campamento limpio)", linea_cofre.contains("aparece_si=flag.zzenlacepuzle.tesoro.pz%d+flag.zzenlacepuzle.campamento_1.limpio" % s_pz), linea_cofre)
	_ok("2 la vista dibuja las dos flechas verdes", (m["enlaces"] as Array).filter(func(e: Dictionary) -> bool: return bool(e.get("puzle", false))).size() == 2)
	_ok("2 el mapa es válido", Exportador.validar(m).is_empty(), str(Exportador.validar(m)))
	_ok("2 el .txt guarda el enlace (para volver a abrirlo)", Exportador.texto_mapa(m).contains("pz%d+pz%d" % [s_pz, s_camp]), "")
	# En el juego.
	_ok("3 se exporta", bool(Exportador.exportar(m)["ok"]))
	await cargar(Exportador.ruta_escena(NOMBRE), true)
	if maqueta == null:
		_borrar()
		return
	var pz: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	_ok("3 Puzle3D monta todo sin avisos", pz != null and pz.avisos.is_empty(), str(pz.avisos) if pz != null else "")
	await avanzar_s(0.5)
	_ok("3 al empezar, el cofre del tesoro está oculto", _cumple(pz, "tesoro", "oculto"))
	pz.call("_ejecutar", {"id": "cat1_placa", "accion": "pulsar", "args": []})
	await avanzar_s(0.5)
	_ok("3 con solo el puzle resuelto, sigue oculto", _cumple(pz, "tesoro", "oculto") and Flags.i().tiene("zzenlacepuzle.tesoro.pz%d" % s_pz))
	Flags.i().poner("zzenlacepuzle.campamento_1.limpio")       # el vigía la pone al caer todos sus goblins
	var t: float = 0.0
	while t < 3.0 and _cumple(pz, "tesoro", "oculto"):
		await avanzar_s(0.1)
		t += 0.1
	_ok("3 con el puzle resuelto y el campamento limpio, aparece", not _cumple(pz, "tesoro", "oculto"))
	_borrar()


func _cumple(pz: Puzle3D, id: String, cond: String) -> bool:
	return bool(pz.call("_cumple", id, cond))


func _borrar() -> void:
	for r in [Exportador.ruta_mapa(NOMBRE), Exportador.ruta_escena(NOMBRE)]:
		if FileAccess.file_exists(r):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(r))
