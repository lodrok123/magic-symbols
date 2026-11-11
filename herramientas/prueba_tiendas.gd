extends SceneTree
## TIENDAS (11/11, Juego; `nucleo/tiendas.gd`, `nucleo/datos/tiendas.tsv`):
##   1 · la tabla: cada fila vende un objeto que existe, a precio > 0, con una condición que se entiende
##   2 · la oferta: solo lo desbloqueado y con existencias, en el orden de la tabla
##   3 · comprar: cobra el oro, mete el objeto, avisa; los motivos de no poder (oro, sitio, agotado, bloqueado, no lo vende)
##   4 · existencias limitadas que se gastan y viajan con la partida
##   5 · desbloqueo por flag (el pigmento de musgo tras despertar los tótems)
##   6 · abrir avisa a la pantalla
##   godot --headless --path . --script res://herramientas/prueba_tiendas.gd

var _fallos: int = 0


func _initialize() -> void:
	_probar()
	print("FALLOS: %d" % _fallos)
	quit(0 if _fallos == 0 else 1)


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	if not bien:
		_fallos += 1
	print(("OK    " if bien else "FALLO ") + nombre + ("  " + info if info != "" else ""))


func _probar() -> void:
	Estado.nuevo()
	Flags.nuevo()
	# 1 · la tabla
	var malas: Array = []
	for t in BD.tiendas():
		for f in BD.tienda(String(t)):
			var o: String = String(f["objeto"])
			var cond: String = String(f.get("se_desbloquea", ""))
			if not Objetos.existe(o) or int(f["precio"]) <= 0 or not (cond in ["", "siempre"] or cond.begins_with("flag:") or cond.begins_with("mejora:") or cond.begins_with("tener:")):
				malas.append("%s/%s" % [t, o])
	_ok("1 alquimista y librera; cada fila vende un objeto que existe, con precio y condición válidos", BD.tiendas().has("alquimista") and BD.tiendas().has("librera") and malas.is_empty() and BD.errores().is_empty(), str(malas))
	# 2 · la oferta
	var lib: Array = Tiendas.oferta("librera")
	var ids: Array = []
	for o in lib:
		ids.append(String(o["objeto"]))
	_ok("2 la librera ofrece lo suyo en orden y sin el pigmento de musgo (bloqueado por los tótems)", ids.size() > 3 and ids[0] == "flor_silvestre" and not ids.has("pigmento_musgo"), str(ids))
	_ok("2 sin fin = -1; con existencias, las que quedan", int(lib[0]["quedan"]) == -1 and Tiendas.quedan("librera", "bulbo_luz") == 3)
	# 3 · comprar
	var e: Estado = Estado.i()
	e.oro = 10
	var p: Dictionary = Tiendas.puede("librera", "bulbo_luz")
	_ok("3 sin oro: dice cuánto falta y no compra", p["motivo"] == Tiendas.SIN_ORO and int(p["oro_falta"]) == 5 and not Tiendas.comprar("librera", "bulbo_luz") and e.oro == 10, str(p))
	e.oro = 100
	var avisos: Array = []
	Tiendas.i().comprado.connect(func(t: String, o: String, n: int, pr: int) -> void: avisos.append([t, o, n, pr]))
	_ok("3 con oro compra: cobra 15, mete el bulbo y avisa", Tiendas.comprar("librera", "bulbo_luz") and e.oro == 85 and e.cuenta("bulbo_luz") == 1 and avisos.size() == 1, str(avisos))
	_ok("3 varias de golpe cobran por unidad", Tiendas.comprar("librera", "flor_silvestre", 5) and e.oro == 65 and e.cuenta("flor_silvestre") == 5)
	_ok("3 lo que no vende: no_vende", Tiendas.puede("librera", "nucleo_eco")["motivo"] == Tiendas.NO_VENDE and Tiendas.puede("nadie", "pocion")["motivo"] == Tiendas.NO_VENDE)
	Estado.nuevo()
	e = Estado.i()
	e.oro = 500
	e.capacidad = 1
	e.agregar("piedra", Objetos.pila("piedra"))
	_ok("3 con la mochila llena: sitio (y no cobra)", Tiendas.puede("alquimista", "pocion")["motivo"] == Tiendas.SIN_SITIO and not Tiendas.comprar("alquimista", "pocion") and e.oro == 500)
	# 4 · existencias
	Estado.nuevo()
	e = Estado.i()
	e.oro = 500
	_ok("4 se pueden comprar las 3 que hay de golpe", Tiendas.comprar("librera", "polvo_cristal", 3) and Tiendas.quedan("librera", "polvo_cristal") == 0)
	_ok("4 agotado: ya no sale en la oferta y no se compra", Tiendas.puede("librera", "polvo_cristal")["motivo"] == Tiendas.AGOTADO and not _en_oferta("librera", "polvo_cristal"))
	_ok("4 una tienda no gasta las existencias de otra", Tiendas.quedan("alquimista", "tonico_tinta") == 3)
	var g := Estado.new()
	g.desde_dic(e.a_dic())
	_ok("4 lo comprado viaja con la partida", Tiendas.quedan("librera", "polvo_cristal", g) == 0 and Tiendas.quedan("librera", "bulbo_luz", g) == 3)
	# 5 · desbloqueo
	_ok("5 el pigmento de musgo está bloqueado sin la flag de los tótems", Tiendas.puede("librera", "pigmento_musgo")["motivo"] == Tiendas.BLOQUEADO)
	Flags.i().poner("bosque02.ruinas.totems")
	_ok("5 con la flag aparece y se compra", _en_oferta("librera", "pigmento_musgo") and Tiendas.comprar("librera", "pigmento_musgo") and e.cuenta("pigmento_musgo") == 1)
	# 6 · abrir
	var abiertas: Array = []
	Tiendas.i().tienda_abierta.connect(func(t: String) -> void: abiertas.append(t))
	Tiendas.abrir("librera")
	Tiendas.abrir("no_existe")
	_ok("6 abrir avisa a la pantalla (y una tienda que no existe, no)", abiertas == ["librera"], str(abiertas))
	Estado.nuevo()
	Flags.nuevo()


func _en_oferta(tienda: String, objeto: String) -> bool:
	for o in Tiendas.oferta(tienda):
		if String(o["objeto"]) == objeto:
			return true
	return false
