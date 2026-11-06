extends "res://herramientas/escenario_base.gd"
## Captura del ARTE DEL ENTORNO (6/11): escombro en relieve + suelo de grava, costra de magma, vapor y una casilla germinada. NECESITA VENTANA (hace falta renderizar):
##   E:\magic-symbols\tools\Godot_v4.7.2-stable_win64.exe --path E:\magic-symbols --script res://herramientas/captura_arte_entorno.gd
## Monta la escena real del Bosque (la misma de los escenarios; no hay lab nuevo), pone los estados por código con una caducidad larga (para que dé tiempo a verlos) y guarda
## docs/capturas/arte_entorno/*.png. Las fotos de la hierba germinada son antes/después de la MISMA casilla.

const DIR: String = "res://docs/capturas/arte_entorno"
const S: float = 2.3


func _escenario() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	await cargar()
	if maqueta == null:
		return
	_ocultar_ui(root)
	var e: EstadosSuelo3D = Terreno3D.estados
	# --- Escombro, costra, vapor en una fila de 4 casillas de suelo seco junto al jugador ---
	var fila: Array = _fila_de_suelo(4)
	_ok("1 hay 4 casillas de suelo libres para la toma", fila.size() == 4, str(fila))
	if fila.size() == 4:
		await _foco(fila[1] as Vector2i, fila[2] as Vector2i, 7.0)
		await avanzar(20)
		_guardar("0_antes")
		e.poner(fila[0], EstadosSuelo3D.ESCOMBRO, true, 1.0, 120.0)                       # escombro de tierra
		e.poner(fila[1], EstadosSuelo3D.MOJADA, true, 1.0, 120.0)
		ReaccionesSuelo3D.aplicar(AccionElemental.nueva("magma", Terreno3D.centro_de(fila[1], 0.0), 0.0))   # magma sobre suelo mojado = costra + vapor
		e.poner(fila[1], EstadosSuelo3D.ESCOMBRO, true, 1.0, 120.0)                       # (alarga el reloj; sigue siendo costra)
		e.poner(fila[1], EstadosSuelo3D.VAPOR, true, 1.0, 120.0)
		e.poner(fila[2], EstadosSuelo3D.VAPOR, true, 1.0, 120.0)                          # vapor solo
		e.poner(fila[3], EstadosSuelo3D.QUEMADA, true, 1.0, 120.0)                        # una quemada al lado: el humo/ceniza no debe confundirse con el vapor
		e.poner(fila[3], EstadosSuelo3D.ESCOMBRO, true, 1.0, 120.0)
		await avanzar_s(2.5)
		_guardar("1_escombro_costra_vapor")
		await _foco(fila[0] as Vector2i, fila[0] as Vector2i, 3.5)
		await avanzar_s(0.6)
		_guardar("2_escombro_detalle")
		await _foco(fila[1] as Vector2i, fila[1] as Vector2i, 3.5)
		await avanzar_s(0.6)
		_guardar("3_costra_detalle")
		for c in fila:
			e.poner(c as Vector2i, EstadosSuelo3D.ESCOMBRO, false)
			e.poner(c as Vector2i, EstadosSuelo3D.VAPOR, false)
			e.poner(c as Vector2i, EstadosSuelo3D.QUEMADA, false)
			e.poner(c as Vector2i, EstadosSuelo3D.MOJADA, false)
	# --- Hierba germinada: tierra mojada + naturaleza ---
	var tierra: Vector2i = _casilla_de_tierra()
	_ok("2 hay una casilla de tierra para germinar", tierra.x >= 0, str(tierra))
	if tierra.x >= 0:
		await _foco(tierra, tierra, 5.0)
		await avanzar(20)
		_guardar("4_germinar_antes")
		e.poner(tierra, EstadosSuelo3D.MOJADA, true, 1.0, 120.0)
		var r: Dictionary = e.aplicar(tierra, "brota")
		_ok("2 la naturaleza germina la tierra mojada", bool(r.get("cambio", false)) and e.material_de(tierra) == "hierba")
		_ok("2 la maqueta la tiene por hierba", bool(maqueta.call("_es_hierba", tierra)))
		await avanzar_s(0.7)
		_guardar("5_germinar_naciendo")
		await avanzar_s(2.5)
		_guardar("6_germinar_despues")
		var arte: Node = maqueta.get("_arte_entorno") as Node
		_ok("2 hay un brote de naturaleza vivo", arte != null and int(arte.call("brotes_vivos")) >= 1)
		# Y ahora arde: la hierba germinada entra en el autómata del fuego.
		var prev: String = String(maqueta.call("prever_hierba", "fuego", tierra))
		_ok("2 el fuego puede prenderla", prev == "prende" or prev == "", prev)
	print("capturas en %s" % ProjectSettings.globalize_path(DIR))


## `n` casillas seguidas en x, de suelo (no agua, no pared, no ocupadas), lo más cerca posible del jugador.
func _fila_de_suelo(n: int) -> Array:
	var p: Vector2i = celda_jugador()
	var mejor: Array = []
	var mejor_d: int = 1 << 30
	for dy in range(-8, 9):
		for dx in range(-8, 9):
			var c0 := Vector2i(p.x + dx, p.y + dy)
			var ok: bool = true
			var fila: Array = []
			for i in range(n):
				var c := Vector2i(c0.x + i, c0.y)
				# Despejada también la franja de 3 casillas hacia la cámara (al sur): si no, un árbol de delante tapa la toma.
				for k in range(0, 4):
					var q := Vector2i(c.x, c.y + k)
					if not Terreno3D.en_mapa(q) or Terreno3D.es_agua(q) or Terreno3D.letra_de(q) == "#" or bool((maqueta.get("_bloqueadas") as Dictionary).has(q)) or q == p:
						ok = false
				if not ok:
					break
				fila.append(c)
			if ok and absi(dx) + absi(dy) < mejor_d and absi(dx) + absi(dy) >= 2:
				mejor_d = absi(dx) + absi(dy)
				mejor = fila
	return mejor


## Una casilla de tierra (tipo de suelo 2, la del campamento) para germinar: tierra seca de verdad, con sitio libre alrededor.
func _casilla_de_tierra() -> Vector2i:
	var lado: int = Terreno3D.lado_del_mapa()
	for y in range(lado):
		for x in range(lado):
			var c := Vector2i(x, y)
			if int(maqueta.call("_tipo_suelo", c)) == 2 and not Terreno3D.es_agua(c) and not bool((maqueta.get("_bloqueadas") as Dictionary).has(c)):
				var vecinas: int = 0
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if int(maqueta.call("_tipo_suelo", c + d)) == 2:
						vecinas += 1
				if vecinas >= 3:
					return c
	return Vector2i(-1, -1)


func _foco(a: Vector2i, b: Vector2i, zoom: float) -> void:
	var p: Vector3 = (Vector3((float(a.x) + 0.5) * S, 0.5, (float(a.y) + 0.5) * S) + Vector3((float(b.x) + 0.5) * S, 0.5, (float(b.y) + 0.5) * S)) * 0.5
	maqueta.set("_jugador", null)
	maqueta.set("_foco", p)
	maqueta.set("_tam_camara", zoom)
	maqueta.get("_camara").size = zoom
	maqueta.call("_colocar_camara")
	await avanzar(10)


func _guardar(nombre: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	var ruta: String = "%s/%s.png" % [DIR, nombre]
	var err: int = img.save_png(ruta)
	print("captura %s -> %s (%dx%d)" % [("guardada" if err == OK else "ERROR %d" % err), ruta, img.get_width(), img.get_height()])


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
