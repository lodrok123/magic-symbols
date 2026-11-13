extends SceneTree
## Arte del entorno (6/11/2026): el escombro en relieve, el vapor por casilla, el brote de naturaleza y la hierba germinada que se ve. Lo que NO se puede medir sin GPU (cómo queda el shader del
## suelo, el flipbook animado) lo enseña `captura_arte_entorno.gd`; aquí se mide todo lo que es dato: texturas, nodos, topes, determinismo, señales. Sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_arte_entorno.gd

const ARTE = preload("res://presentacion/arte_entorno_3d.gd")
const MAQUETA = preload("res://presentacion/prueba_test2.gd")

class MundoFalso extends Node3D:
	var _lado: int = 20
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	var _precalentando: bool = false
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])
	func _es_agua(l: String) -> bool:
		return l == "~"
	func _es_hierba(c: Vector2i) -> bool:
		return c.x >= 0 and c.y >= 0 and c.x < _lado and c.y < _lado and String(_mapa[c.y][c.x]) == "v"
	func _al_impactar(_elemento: String, _punto: Vector3) -> void:
		pass
	func quitar_placa_hielo(_c: Vector2i) -> void:
		pass

const SECA := Vector2i(8, 8)
const AGUA := Vector2i(12, 12)
const TIERRA := Vector2i(6, 6)

var _fallos: int = 0
var _m: MundoFalso = null
var _e: EstadosSuelo3D = null
var _arte: Node3D = null


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_montar()
	_texturas()
	_naturaleza_tres()
	await _escombro()
	_costra()
	_tope_rocas()
	_vapor()
	_brote()
	_extra()
	_germinar_maqueta()
	_arte.queue_free()
	_e.limpiar()
	_e.olvidar_materiales()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _montar() -> void:
	var filas: PackedStringArray = []
	for y in range(20):
		var f: String = ""
		for x in range(20):
			f += "#" if (x == 0 or y == 0 or x == 19 or y == 19) else "."
		filas.append(f)
	filas[AGUA.y] = filas[AGUA.y].substr(0, AGUA.x) + "~" + filas[AGUA.y].substr(AGUA.x + 1)
	_m = MundoFalso.new()
	_m._mapa = filas
	root.add_child(_m)
	Lanzador3D.configurar(_m)
	Terreno3D.alturas.clear()
	_e = Terreno3D.estados
	_e.limpiar()
	_e.olvidar_materiales()
	_e.hierba_en = Callable(_m, "_es_hierba")
	_arte = ARTE.new()
	root.add_child(_arte)
	_arte.conectar(_e)


func _tam(ruta: String) -> Vector2i:
	var t: Texture2D = load(ruta) as Texture2D
	return Vector2i(t.get_width(), t.get_height()) if t != null else Vector2i.ZERO


func _texturas() -> void:
	_ok("1 vapor.png 768x512 (6x4 = 24 fotogramas de 128)", _tam(ARTE.HOJA_VAPOR) == Vector2i(768, 512) and ARTE.VAPOR_COLUMNAS * ARTE.VAPOR_FILAS == 24, str(_tam(ARTE.HOJA_VAPOR)))
	_ok("1 naturaleza.png 768x384 (6x3 = 18 fotogramas)", _tam(ARTE.HOJA_NATURALEZA) == Vector2i(768, 384) and ARTE.NATURALEZA_COLUMNAS * ARTE.NATURALEZA_FILAS == ARTE.NATURALEZA_FOTOGRAMAS, str(_tam(ARTE.HOJA_NATURALEZA)))
	_ok("1 escombro_arriba.png 1024x1024", _tam("res://arte/suelo_meshy/escombro_arriba.png") == Vector2i(1024, 1024), str(_tam("res://arte/suelo_meshy/escombro_arriba.png")))
	_ok("1 el GLB del terreno con guijarros está instalado y carga", load(ARTE.RUTA_TERRENO) is PackedScene)
	var magma_ok: bool = true
	for i in range(ARTE.VARIANTES_MAGMA):
		magma_ok = magma_ok and load(ARTE.RUTA_MAGMA % i) is PackedScene
	_ok("1 las 5 piedras de magma (la roca de la costra) cargan", magma_ok)
	var huella: float = ARTE._huella((load(ARTE.RUTA_TERRENO) as PackedScene).instantiate())
	_ok("1 el terreno mide ~1 u de lado (se normaliza a 0,25-0,35)", huella > 0.9 and huella < 1.1, "huella %.3f" % huella)
	_ok("1 la textura de escombro es la que lee el shader del suelo", (load("res://presentacion/prueba_test2.gd") as GDScript).source_code.contains("t_escombro") and (load("res://presentacion/prueba_test2.gd") as GDScript).source_code.contains("estado_extra"))


func _naturaleza_tres() -> void:
	var r: RuneData = load("res://nucleo/naturaleza_rune.tres") as RuneData
	_ok("2 naturaleza_rune.tres apunta a naturaleza.png", r != null and r.vfx_sheet != null and r.vfx_sheet.resource_path.ends_with("art/fx/naturaleza.png"), r.vfx_sheet.resource_path if r != null and r.vfx_sheet != null else "sin hoja")
	_ok("2 …con 18 fotogramas", r != null and r.vfx_frames == 18 and r.frames_for() == 18)
	var sp := Sprite2D.new()
	_ok("2 …y setup_sprite la parte en 6 columnas x 3 filas", r.setup_sprite(sp) and sp.hframes == 6 and sp.vframes == 3, "%dx%d" % [sp.hframes, sp.vframes])
	sp.free()


func _escombro() -> void:
	# Escombro de tierra (sin costra): 2-3 trozos de escombro_terreno.glb, con semilla por casilla.
	_e.poner(SECA, EstadosSuelo3D.ESCOMBRO, true)
	var n: int = _arte.rocas_en(SECA)
	_ok("3 poner escombro crea 2-3 trozos", n >= 2 and n <= 3 and _arte.rocas_vivas() == n, "n=%d" % n)
	var lista: Array = _arte._rocas[SECA]
	var escalas_ok: bool = true
	var ruta_ok: bool = true
	for r in lista:
		var s: float = (r as Node3D).scale.x * ARTE._huella(r)
		escalas_ok = escalas_ok and s > ARTE.LADO_MIN - 0.01 and s < ARTE.LADO_MAX + 0.01
		ruta_ok = ruta_ok and String((r as Node3D).get_meta("ruta")) == ARTE.RUTA_TERRENO
	_ok("3 …cada trozo mide 0,25-0,35 u y es del terreno de guijarros", escalas_ok and ruta_ok)
	var antes: Array = []
	for r in lista:
		antes.append([(r as Node3D).position, (r as Node3D).rotation.y, (r as Node3D).scale.x])
	var hijos_antes: int = _arte.get_child_count()
	# Caduca (6 s): se quitan.
	_e.avanzar(6.5)
	_ok("3 al caducar el escombro se quitan los trozos", not _e.tiene(SECA, EstadosSuelo3D.ESCOMBRO) and _arte.rocas_en(SECA) == 0 and _arte.rocas_vivas() == 0)
	var ocultas: bool = true
	for r in lista:
		ocultas = ocultas and not (r as Node3D).visible
	_ok("3 …y quedan ocultos en el pool (no se destruyen)", ocultas and _arte.get_child_count() == hijos_antes)
	# Vuelve a salir: MISMA casilla = mismo resultado (semilla) y sin instanciar nada nuevo (pool).
	_e.poner(SECA, EstadosSuelo3D.ESCOMBRO, true)
	var lista2: Array = _arte._rocas[SECA]
	var igual: bool = lista2.size() == antes.size()
	if igual:
		for i in range(lista2.size()):
			var r2: Node3D = lista2[i]
			var a: Array = antes[i]
			# El pool devuelve los nodos en otro orden, así que se compara como conjunto: cada trozo nuevo existe entre los de antes.
			var hay: bool = false
			for k in range(antes.size()):
				var b: Array = antes[k]
				if (b[0] as Vector3).is_equal_approx(r2.position) and is_equal_approx(float(b[1]), r2.rotation.y):
					hay = true
			igual = igual and hay
			if a.is_empty():
				igual = false
	_ok("3 la misma casilla da los mismos trozos (semilla por casilla)", igual)
	_ok("3 …sin crear nodos nuevos (pool)", _arte.get_child_count() == hijos_antes, "%d vs %d" % [_arte.get_child_count(), hijos_antes])
	_ok("3 semilla distinta para otra casilla", ARTE.semilla_de(SECA) != ARTE.semilla_de(Vector2i(9, 8)) and ARTE.semilla_de(SECA) == ARTE.semilla_de(Vector2i(8, 8)))
	_e.poner(SECA, EstadosSuelo3D.ESCOMBRO, false)
	_ok("3 quitar a mano el escombro también retira los trozos", _arte.rocas_vivas() == 0)


func _costra() -> void:
	_e.limpiar()
	_e.poner_material(AGUA, "agua")
	var r: Dictionary = ReaccionesSuelo3D.aplicar(AccionElemental.nueva("magma", Terreno3D.centro_de(AGUA, 0.0), 0.0))
	_ok("4 magma sobre agua deja escombro y vapor (R1)", _e.tiene(AGUA, EstadosSuelo3D.ESCOMBRO) and _e.tiene(AGUA, EstadosSuelo3D.VAPOR) and bool(r.get("cambio", false)))
	_ok("4 …y el escombro es COSTRA", _e.es_costra(AGUA))
	var lista: Array = _arte._rocas.get(AGUA, [])
	var magma: bool = not lista.is_empty()
	for rr in lista:
		magma = magma and String((rr as Node3D).get_meta("ruta")).contains("piedra_est_magma_")
	_ok("4 las rocas de la costra son las piedras de magma", magma, "%d trozos" % lista.size())
	_e.avanzar(7.0)
	_ok("4 la costra caduca: sin trozos, sin marca de costra y sin vapor", _arte.rocas_en(AGUA) == 0 and not _e.es_costra(AGUA) and _arte.vapores_vivos() == 0)
	# Escombro de tierra en otra casilla NO es costra.
	_e.poner(SECA, EstadosSuelo3D.ESCOMBRO, true)
	_ok("4 el escombro de tierra no es costra y usa la roca normal", not _e.es_costra(SECA) and String((_arte._rocas[SECA][0] as Node3D).get_meta("ruta")) == ARTE.RUTA_TERRENO)
	_e.poner(SECA, EstadosSuelo3D.ESCOMBRO, false)


func _tope_rocas() -> void:
	_e.limpiar()
	# El estado ya topa a 20 casillas (MAX_CASILLAS_VIVAS); aquí se fuerza el aviso en 30 para medir el tope PROPIO de nodos.
	for i in range(30):
		_arte._al_cambiar(Vector2i(2 + i % 15, 2 + i / 15), EstadosSuelo3D.ESCOMBRO, true)
	var visibles: int = 0
	for h in _arte.get_children():
		if h is Node3D and (h as Node3D).visible and h.has_meta("ruta"):       # (los emisores de vapor y los brotes también cuelgan de aquí: no son rocas)
			visibles += 1
	_ok("5 tope MAX_ROCAS_ESCOMBRO = 40 nodos vivos", ARTE.MAX_ROCAS_ESCOMBRO == 40 and _arte.rocas_vivas() <= 40 and visibles == _arte.rocas_vivas(), "vivos %d, visibles %d" % [_arte.rocas_vivas(), visibles])
	_ok("5 …y al pasarse cede la casilla más antigua", not _arte._rocas.has(Vector2i(2, 2)) and _arte._rocas.has(Vector2i(2 + 29 % 15, 2 + 29 / 15)))
	var total: int = _arte.get_child_count()
	for i in range(30):
		_arte._al_cambiar(Vector2i(2 + i % 15, 2 + i / 15), EstadosSuelo3D.ESCOMBRO, false)
	_ok("5 al quitarlo todo no queda ninguno vivo y el pool no crece", _arte.rocas_vivas() == 0 and _arte.get_child_count() == total)
	_e.limpiar()
	_arte._process(1.0)       # el repaso de medio segundo también barre lo que `limpiar` dejó sin avisar
	_ok("5 sin estados el repaso no deja nada", _arte.rocas_vivas() == 0)


func _vapor() -> void:
	_e.limpiar()
	_e.poner(SECA, EstadosSuelo3D.VAPOR, true)
	_ok("6 poner vapor crea UN emisor en la casilla", _arte.vapores_vivos() == 1)
	_e.poner(SECA, EstadosSuelo3D.VAPOR, true)
	_arte._al_cambiar(SECA, EstadosSuelo3D.VAPOR, true)
	_ok("6 …y repetirlo no crea otro", _arte.vapores_vivos() == 1)
	var gp: GPUParticles3D = _arte._vapor[SECA] as GPUParticles3D
	var sm: StandardMaterial3D = (gp.draw_pass_1 as QuadMesh).material as StandardMaterial3D
	_ok("6 el emisor usa vapor.png a 6x4 y en bucle", sm.albedo_texture != null and sm.albedo_texture.resource_path.ends_with("art/fx/vapor.png") and sm.particles_anim_h_frames == 6 and sm.particles_anim_v_frames == 4 and sm.particles_anim_loop)
	var tinte: Color = ARTE.VAPOR_TINTE
	_ok("6 …con tinte blanco-azulado leve (distinto del humo quemado)", tinte.b > tinte.r and tinte.b >= tinte.g and tinte.r > 0.8, str(tinte))
	_e.avanzar(4.5)
	_ok("6 el vapor caduca (4 s) y el emisor muere con él", not _e.tiene(SECA, EstadosSuelo3D.VAPOR) and _arte.vapores_vivos() == 0 and not gp.emitting)
	# Vapor de los cruces: Vfx3D.vapor y VfxPuzle3D.vapor usan la misma hoja.
	var v: GPUParticles3D = VfxPuzle3D.vapor(_m, Vector3.ZERO, 1.0, true)
	var sm2: StandardMaterial3D = (v.draw_pass_1 as QuadMesh).material as StandardMaterial3D
	_ok("6 VfxPuzle3D.vapor (cruces, apagar_vapor) usa la misma hoja", sm2.albedo_texture != null and sm2.albedo_texture.resource_path.ends_with("vapor.png") and v.emitting)
	v.queue_free()
	var fx := Vfx3D.new()
	_m.add_child(fx)
	var antes: int = fx.get_child_count()
	fx.vapor(Vector3.ZERO)
	# 13/11: desde 29c848ed (9/11) `Vfx3D.vapor` engancha además el vapor por regla (`HumoRegla.enganchar_vapor`), y desde f75501c2 esas capas van encendidas:
	# el emisor de la hoja ya no es por fuerza el ÚLTIMO hijo. Se busca entre los nuevos.
	var nuevo: Node = null
	for i in range(antes, fx.get_child_count()):
		var h: Node = fx.get_child(i)
		if h is GPUParticles3D and (h as GPUParticles3D).draw_pass_1 is QuadMesh and ((h as GPUParticles3D).draw_pass_1 as QuadMesh).material is StandardMaterial3D:
			var tex: Texture2D = (((h as GPUParticles3D).draw_pass_1 as QuadMesh).material as StandardMaterial3D).albedo_texture
			if tex != null and tex.resource_path.ends_with("vapor.png"):
				nuevo = h
				break
	_ok("6 Vfx3D.vapor (impacto de vapor, hielo que caduca) pinta el emisor de la hoja", nuevo != null, "%d hijos nuevos" % (fx.get_child_count() - antes))
	fx.queue_free()


func _brote() -> void:
	_e.limpiar()
	_e.olvidar_materiales()
	var n0: int = _arte.brotes_vivos()
	_e.poner_material(TIERRA, "hierba")
	_ok("7 germinar (material → hierba) saca un brote de naturaleza", _arte.brotes_vivos() == n0 + 1)
	var s: Sprite3D = _arte._brotes[TIERRA] as Sprite3D
	_ok("7 …con naturaleza.png a 6x3", s.texture != null and s.texture.resource_path.ends_with("art/fx/naturaleza.png") and s.hframes == 6 and s.vframes == 3)
	_e.poner_material(TIERRA, "hierba")
	_ok("7 …y repetir el material no duplica el brote", _arte.brotes_vivos() == n0 + 1)
	var suelto: Sprite3D = ARTE.brote(_m, Vector3.ZERO, 0.5, 0.0)
	_ok("7 el brote suelto (adorno del enraizado) existe", suelto != null and suelto.get_parent() == _m)
	suelto.queue_free()
	# Los materiales del mapa al montar NO son una germinación.
	var cuenta: Array = [0]
	var f: Callable = func(_c: Vector2i, _mat: String) -> void: cuenta[0] += 1
	_e.material_cambiado.connect(f)
	_e.leer_materiales("; material 3 3 hierba\n")
	_e.material_cambiado.disconnect(f)
	_ok("7 leer_materiales (montar el mapa) no avisa de germinación", cuenta[0] == 0 and _e.material_de(Vector2i(3, 3)) == "hierba")
	for i in range(ARTE.MAX_BROTES + 6):
		_arte._al_material(Vector2i(2 + i % 15, 5 + i / 15), "hierba")
	_ok("7 tope MAX_BROTES", _arte.brotes_vivos() <= ARTE.MAX_BROTES, str(_arte.brotes_vivos()))


func _extra() -> void:
	_e.limpiar()
	_e.poner(SECA, EstadosSuelo3D.ESCOMBRO, true)
	_e.poner_material(AGUA, "agua")
	ReaccionesSuelo3D.aplicar(AccionElemental.nueva("magma", Terreno3D.centro_de(AGUA, 0.0), 0.0))
	var img: Image = _e.textura_extra().get_image()
	var p: Color = _e.imagen().get_pixelv(SECA)
	_ok("8 la segunda imagen de estado lleva el escombro en R", img.get_pixelv(SECA).r > 0.9 and img.get_pixelv(SECA).g < 0.1, str(img.get_pixelv(SECA)))
	_ok("8 …y la costra de magma en G", img.get_pixelv(AGUA).r > 0.9 and img.get_pixelv(AGUA).g > 0.9, str(img.get_pixelv(AGUA)))
	_ok("8 la imagen principal (R quemada·G mojada·B helada·A segada) no cambia por el escombro", p.is_equal_approx(Color(0, 0, 0, 0)), str(p))
	_ok("8 es el mismo objeto de siempre (se actualiza, no se recrea)", _e.textura_extra() == _e.textura_extra() and Mundo3D.textura_estados_extra() == Terreno3D.estados.textura_extra())
	_e.avanzar(7.0)
	_e.textura_extra()          # rehace la imagen (se lee la copia de CPU: `get_image` de la textura en el renderizador de mentira de --headless devuelve la primera)
	_ok("8 al caducar el escombro vuelve a negro", _e._img2.get_pixelv(SECA).r < 0.01)
	_e.limpiar()


func _germinar_maqueta() -> void:
	# La maqueta de verdad, sin árbol (como `prever_hierba` en R1): germinar mete la casilla en su autómata de hierba.
	_e.limpiar()
	_e.olvidar_materiales()
	var m: Node3D = MAQUETA.new()
	var filas: PackedStringArray = []
	for y in range(20):
		filas.append("#".repeat(20) if (y == 0 or y == 19) else "#" + "g".repeat(18) + "#")      # «g» = tierra pisada (tipo de suelo 2)
	m._mapa = filas
	m._lado = 20
	m._img_mapa = Image.create_empty(20, 20, false, Image.FORMAT_RGBA8)
	m._img_mapa.fill(Color(0, 0, 1, 0))
	m._tex_mapa = ImageTexture.create_from_image(m._img_mapa)
	var c := Vector2i(5, 5)
	_ok("9 antes de germinar la tierra no es hierba", not m._es_hierba(c) and m._tipo_suelo(c) == 2)
	_e.hierba_en = Callable(m, "_es_hierba")
	_e.material_cambiado.connect(m._al_cambiar_material)
	_e.poner(c, EstadosSuelo3D.MOJADA, true)
	var r: Dictionary = _e.aplicar(c, "brota")
	_ok("9 la naturaleza sobre tierra mojada germina (R1)", bool(r.get("cambio", false)) and _e.material_de(c) == "hierba")
	_ok("9 la maqueta la da por hierba (`_es_hierba`, `_tipo_suelo`)", m._es_hierba(c) and m._tipo_suelo(c) == 0 and m._germinadas.has(c))
	_ok("9 …y repinta su pixel del mapa de tipos (verde)", m._img_mapa.get_pixelv(c).r > 0.9 and m._img_mapa.get_pixelv(c).b < 0.1, str(m._img_mapa.get_pixelv(c)))
	_ok("9 …y ahora el fuego puede prenderla (`prever_hierba`)", m.prever_hierba("fuego", c) == "prende", m.prever_hierba("fuego", c))
	_ok("9 …y la naturaleza sobre ella brota alta (autómata)", m.prever_hierba("naturaleza", c) == "brota")
	_ok("9 la vecina sin germinar sigue sin ser hierba", not m._es_hierba(Vector2i(6, 5)) and m.prever_hierba("fuego", Vector2i(6, 5)) == "")
	m.germinar_hierba(Vector2i(0, 0))
	_ok("9 una pared (#) no germina", not m._germinadas.has(Vector2i(0, 0)))
	_e.material_cambiado.disconnect(m._al_cambiar_material)
	_e.hierba_en = Callable(_m, "_es_hierba")
	m.free()
