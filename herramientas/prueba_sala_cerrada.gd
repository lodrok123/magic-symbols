extends SceneTree
## C3 de docs/PLAN_EOW.md (21/10, Juego): SALA QUE SE CIERRA HASTA DERROTAR A TODOS. Sin ventana, con enemigos y cofre REALES:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_sala_cerrada.gd
## Sala de Puzle3D con `vigia` + `cerrojo` + `cofre` (la gramática exacta está en la cabecera de escenas/puzle.gd):
##   1. Gramática: lo bien escrito se lee; lo mal escrito avisa y no monta a medias.
##   2. Montaje: puertas abiertas, vigía sin cumplir, cofre OCULTO (invisible, sin bloquear su casilla).
##   3. Entrar: el jugador fuera no cierra; al pisar la sala el cerrojo se cierra y bloquea las casillas de las puertas.
##   4. Derrotar a 3 goblins (uno muere por daño, otro por daño y el tercero se HUNDE): hasta el último, nada se abre. Luego: señal una vez, flag
##      puesta, puertas abiertas, y el cofre APARECE cerrado (con efecto, bloqueando su casilla).
##   5. Abrir el cofre (API de Cofre3D): al acabar la animación se pone su flag. Reentrar a la sala ya no la cierra.
##   6. «Recargar partida»: Flags guardar → Flags.nuevo → cargar → un Puzle3D NUEVO con el mismo texto: el cofre nace ABIERTO (no vuelve a aparecer
##      cerrado, no hay efecto) y la sala nace abierta aunque los goblins hayan vuelto. Partida a medias (solo la sala limpia): cofre cerrado sin efecto.
##      Partida nueva: cofre oculto otra vez. La carga DESPUÉS de montar también abre el cofre.
##   7. Un vigía cuya lista no casa con ningún enemigo avisa y no da la sala por limpia.

class FalsoLanzador extends Node:
	var jugador: Node3D = null

const DT: float = 1.0 / 60.0
const S: float = 2.3
const LADO: int = 14
const RUTA: String = "user://prueba_sala_cerrada.json"
const TEXTO: String = """
; pieza v  vigia   1 1 de=5,3..11,8 flag=prueba.s1.limpia
; pieza cj cerrojo 4 5 celdas=4,5..4,6 sala=5,3..11,8 hasta=prueba.s1.limpia
; pieza cf cofre   10 7 aparece_si=v.todos abierto=prueba.s1.cofre
; puzle abre cuando=v.todos_derrotados hace=cj.abrir
"""

var _fallos: int = 0
var _mundo: Mundo3D = null
var _jugador: Jugador3D = null
var _lanz: FalsoLanzador = null
var _cuerpo_jugador: Node3D = null


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_gramatica()
	_montar_terreno()
	await _sala_completa()
	await _vigia_sin_enemigos()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


# ---------------------------------------------------------------------------------------------------------------------
#  1. Gramática
# ---------------------------------------------------------------------------------------------------------------------

func _gramatica() -> void:
	var r: Dictionary = Puzle3D.parsear(TEXTO)
	_ok("1 la sala de ejemplo se lee sin avisos (3 piezas, 1 regla)", (r["piezas"] as Array).size() == 3 and (r["reglas"] as Array).size() == 1 and (r["avisos"] as Array).is_empty(), str(r["avisos"]))
	if (r["piezas"] as Array).size() == 3:
		var cf: Puzle3D.Pieza = r["piezas"][2]
		_ok("1 aparece_si queda leído como expresión y abierto como flag", cf.exprs.has("aparece_si") and cf.exprs["aparece_si"][0][0]["id"] == "v" and cf.p["abierto"] == "prueba.s1.cofre", str(cf.exprs))
	var m: Dictionary = Puzle3D.parsear("\n".join([
		"; pieza v vigia 1 1 flag=mal",                                        # flag sin nivel.sala.hecho
		"; pieza c cofre 2 2 aparece_si=zzz.todos",                            # pieza que no existe: el cofre se descarta
		"; pieza c2 cofre 3 3 aparece_si=a+",                                  # condición a medias
		"; pieza c3 cofre 3 4 abierto=Mal",
		"; pieza j cerrojo 4 4 sala=1,1",
		"; pieza ok vigia 1 1 de=2,2",
		"; puzle r cuando=ok.todos_derrotados si=ok.quedan hace=j.abrir",
		"; puzle r2 cuando=ok.nada hace=j.abrir",                              # señal que no existe
		"; puzle r3 cuando=ok hace=j.cerrar si=ok.no_existe",                  # condición que no existe
	]))
	var av: Array = m["avisos"]
	var ids: Array = []
	for p in (m["piezas"] as Array):
		ids.append((p as Puzle3D.Pieza).id)
	_ok("1 las líneas mal escritas avisan y se descartan (solo sobreviven j y ok)", ids == ["j", "ok"], str(ids) + " " + str(av))
	_ok("1 una condición de aparece_si rota NO deja un cofre que aparezca siempre", not ids.has("c") and not ids.has("c2"))
	_ok("1 la regla buena se lee y las dos malas no", (m["reglas"] as Array).size() == 1 and av.size() >= 6, "%d reglas, %d avisos" % [(m["reglas"] as Array).size(), av.size()])


# ---------------------------------------------------------------------------------------------------------------------
#  Montaje
# ---------------------------------------------------------------------------------------------------------------------

func _montar_terreno() -> void:
	var filas: PackedStringArray = []
	var bloq: Dictionary = {}
	for y in range(LADO):
		var f: String = ""
		for x in range(LADO):
			var borde: bool = x == 0 or y == 0 or x == LADO - 1 or y == LADO - 1
			f += "#" if borde else "."
			if borde:
				bloq[Vector2i(x, y)] = true
		filas.append(f)
	Terreno3D.alturas.clear()
	Terreno3D.permanentes.clear()
	Terreno3D.cargar_datos(filas, bloq)
	Terreno3D.activar_fuente_casillas()
	_mundo = Mundo3D.new()
	root.add_child(_mundo)
	_jugador = Jugador3D.new()
	_jugador.position = _centro(2, 5)
	_jugador.pj = Pj3D.new()
	_mundo.add_child(_jugador.pj)
	# El jugador "falso" que ve el Puzle3D (igual que Pulsador3D en modo presencia): un lanzador en el grupo «player» que sabe su `jugador`.
	_cuerpo_jugador = Node3D.new()
	_mundo.add_child(_cuerpo_jugador)
	_lanz = FalsoLanzador.new()
	_lanz.jugador = _cuerpo_jugador
	_lanz.add_to_group("player")
	root.add_child(_lanz)
	_mover(2, 5)


func _centro(cx: int, cy: int) -> Vector3:
	return Vector3((cx + 0.5) * S, Terreno3D.y_pies(Vector2i(cx, cy)), (cy + 0.5) * S)


func _mover(cx: int, cy: int) -> void:
	_cuerpo_jugador.position = _centro(cx, cy)


func _goblin(tipo: String, cx: int, cy: int) -> Combate3D:
	var modelo := Pj3D.new()
	modelo.id = "goblin_warrior" if tipo == "guerrero" else "goblin_archer"
	modelo.position = _centro(cx, cy)
	_mundo.add_child(modelo)
	var g: Combate3D = Combate3D.equipar(modelo, _mundo, _jugador, null)
	g.set_physics_process(false)
	g.altura = 0.85
	g.quieto = true
	g.position = _centro(cx, cy)
	g.casa = g.position
	return g


func _espera(s: float) -> void:
	await create_timer(s).timeout


# ---------------------------------------------------------------------------------------------------------------------
#  2–6. La sala
# ---------------------------------------------------------------------------------------------------------------------

## Monta una sala nueva con TEXTO y devuelve el Puzle3D.
func _levantar() -> Puzle3D:
	var z := Puzle3D.new()
	root.add_child(z)
	z.iniciar(_mundo, "", TEXTO)
	return z


## Quita las piezas de una sala (y las casillas que bloqueaban) para montar la siguiente sobre el mismo terreno.
func _desmontar(z: Puzle3D) -> void:
	for pz in z.piezas():
		var nd: Node = (pz as Puzle3D.Pieza).nodo
		if is_instance_valid(nd):
			nd.free()
	z.free()
	for c in [Vector2i(4, 5), Vector2i(4, 6), Vector2i(10, 7)]:
		Terreno3D.liberar_celda(c)


func _sala_completa() -> void:
	Flags.nuevo()
	var g1: Combate3D = _goblin("guerrero", 7, 4)
	var g2: Combate3D = _goblin("arquero", 8, 6)
	var g3: Combate3D = _goblin("guerrero", 9, 5)
	var fuera: Combate3D = _goblin("guerrero", 12, 12)         # nace fuera de la sala: no cuenta
	var z: Puzle3D = _levantar()
	var vistos_aviso: Array = []
	z.aviso_nuevo.connect(func(t: String) -> void: vistos_aviso.append(t))
	await _espera(0.3)
	var v: Puzle3D.VigiaPuzle = z.nodo("v") as Puzle3D.VigiaPuzle
	var cj: Puzle3D.CerrojoPuzle = z.nodo("cj") as Puzle3D.CerrojoPuzle
	var cf: Puzle3D.CofrePuzle = z.nodo("cf") as Puzle3D.CofrePuzle
	_ok("2 las tres piezas montadas, sin avisos", v != null and cj != null and cf != null and z.avisos.is_empty(), str(z.avisos))
	if v == null or cj == null or cf == null:
		return
	var cierres: Array = []
	cj.cambio.connect(func(c: bool) -> void: cierres.append(c))
	var derrotas: Array = [0]
	v.todos_derrotados.connect(func() -> void: derrotas[0] += 1)
	var apariciones: Array = [0]
	cf.aparecido.connect(func() -> void: apariciones[0] += 1)
	_ok("2 el vigía ve a los 3 de la sala y no al de fuera", v.vistos.size() == 3 and not v.vistos.has(fuera), "vistos %d" % v.vistos.size())
	_ok("2 las puertas nacen abiertas (casillas libres)", not cj.cerrado and not Terreno3D.bloqueada(Vector2i(4, 5)) and not Terreno3D.bloqueada(Vector2i(4, 6)))
	_ok("2 el vigía no está cumplido (quedan 3) y la condición lo dice", not v.completo and v.restantes() == 3 and z.cumple_expr([[{"neg": false, "tipo": "pieza", "id": "v", "cond": "quedan"}]]))
	_ok("2 el cofre está OCULTO: invisible, sin bloquear la casilla y sin poder abrirse", cf.es_oculto and not cf.modelo.visible and not Terreno3D.bloqueada(Vector2i(10, 7)) and not cf.abrir())
	_ok("2 el cuerpo físico del cofre está apagado mientras no existe", cf._cuerpo == null or cf._cuerpo.collision_layer == 0)
	var hay_ctrl: bool = cf.ctrl != null
	_ok("2 el cofre real tiene su Cofre3D y lo tiene OCULTO", hay_ctrl and bool(cf.ctrl.call("esta_oculto")), "ctrl %s" % str(cf.ctrl))

	# 3. Entrar
	_mover(2, 5)
	await _espera(0.4)
	_ok("3 con el jugador fuera de la sala, el cerrojo no cierra", not cj.cerrado and cierres.is_empty())
	_mover(4, 5)                                                # pisar la propia puerta no es entrar
	await _espera(0.4)
	_ok("3 pisar la casilla de la puerta no cuenta como entrar (no se cierra encima)", not cj.cerrado)
	_mover(5, 5)
	await _espera(0.4)
	_ok("3 al pisar la sala el cerrojo se CIERRA, una vez, y bloquea las dos casillas", cj.cerrado and cierres == [true] and Terreno3D.bloqueada(Vector2i(4, 5)) and Terreno3D.bloqueada(Vector2i(4, 6)), str(cierres))
	_ok("3 la condición cj.cerrado se cumple", z.cumple_expr([[{"neg": false, "tipo": "pieza", "id": "cj", "cond": "cerrado"}]]))

	# 4. Derrotar a los tres
	g1.receive_damage(10000.0)
	await _espera(0.5)
	_ok("4 con 1 de 3 caído, nada se abre y el cofre sigue oculto", v.restantes() == 2 and not v.completo and cj.cerrado and cf.es_oculto)
	g2.receive_damage(10000.0)
	await _espera(0.5)
	_ok("4 con 2 de 3 caídos, tampoco", v.restantes() == 1 and not v.completo and cj.cerrado and cf.es_oculto and derrotas[0] == 0)
	fuera.receive_damage(10000.0)                                 # el de fuera no cuenta
	await _espera(0.5)
	_ok("4 que caiga el de fuera no cumple al vigía", not v.completo and cj.cerrado)
	var hundidos: Array = []
	g3.hundido.connect(func(_e: Combate3D) -> void: hundidos.append(1))
	g3._morir(true)                                               # el último SE HUNDE (A3): cuenta igual
	await _espera(0.6)
	_ok("4 el tercero se hunde y el vigía lo cuenta: todos derrotados, UNA vez", g3.se_hundio and hundidos.size() == 1 and v.completo and derrotas[0] == 1, "derrotas %d" % derrotas[0])
	_ok("4 el vigía pone su flag", Flags.i().tiene("prueba.s1.limpia"))
	_ok("4 la regla abre el cerrojo: puertas abiertas y casillas libres", not cj.cerrado and cierres == [true, false] and not Terreno3D.bloqueada(Vector2i(4, 5)) and not Terreno3D.bloqueada(Vector2i(4, 6)), str(cierres))
	_ok("4 el cofre APARECE (una vez), cerrado, visible y bloqueando su casilla", cf.es_cerrado and not cf.es_oculto and apariciones[0] == 1 and cf.modelo.visible and Terreno3D.bloqueada(Vector2i(10, 7)), "apariciones %d" % apariciones[0])
	_ok("4 y el Cofre3D está en «cerrado» o «apareciendo» (con efecto)", String(cf.ctrl.call("estado_nombre")) in ["cerrado", "apareciendo"], String(cf.ctrl.call("estado_nombre")))
	await _espera(0.8)
	_ok("4 acabado el efecto, el Cofre3D está «cerrado»", String(cf.ctrl.call("estado_nombre")) == "cerrado")
	_ok("4 aún no se ha puesto la flag del cofre", not Flags.i().tiene("prueba.s1.cofre"))

	# 5. Abrir el cofre
	_ok("5 abrir() arranca la apertura", cf.abrir())
	_ok("5 abrirlo dos veces seguidas no repite", not cf.abrir())
	_ok("5 mientras se abre, la flag aún no está", not Flags.i().tiene("prueba.s1.cofre") and not cf.es_abierto)
	await _espera(1.8)
	_ok("5 abierto: estado, flag y Cofre3D «abierto»", cf.es_abierto and not cf.es_cerrado and Flags.i().tiene("prueba.s1.cofre") and String(cf.ctrl.call("estado_nombre")) == "abierto")
	_mover(2, 5)
	await _espera(0.3)
	_mover(6, 4)
	await _espera(0.4)
	_ok("5 la sala ya vencida no se vuelve a cerrar al reentrar", not cj.cerrado and cierres == [true, false])

	# 6. Recargar la partida
	_ok("6 guardar escribe el archivo", Flags.i().guardar(RUTA))
	_desmontar(z)
	Flags.nuevo()
	_ok("6 (control) partida nueva: sin flags", Flags.i().nombres().is_empty())
	_ok("6 cargar devuelve true", Flags.i().cargar(RUTA))
	var g4: Combate3D = _goblin("guerrero", 7, 4)                # al recargar el nivel los enemigos vuelven
	_mover(6, 4)                                                  # y el jugador aparece DENTRO de la sala
	var z2: Puzle3D = _levantar()
	await _espera(0.5)
	var v2: Puzle3D.VigiaPuzle = z2.nodo("v") as Puzle3D.VigiaPuzle
	var cj2: Puzle3D.CerrojoPuzle = z2.nodo("cj") as Puzle3D.CerrojoPuzle
	var cf2: Puzle3D.CofrePuzle = z2.nodo("cf") as Puzle3D.CofrePuzle
	_ok("6 sala recargada: montada sin avisos", v2 != null and cj2 != null and cf2 != null and z2.avisos.is_empty(), str(z2.avisos))
	if v2 == null or cj2 == null or cf2 == null:
		return
	var apariciones2: Array = [0]
	cf2.aparecido.connect(func() -> void: apariciones2[0] += 1)
	_ok("6 el cofre sigue ABIERTO: visible, estado abierto y Cofre3D «abierto»", cf2.es_abierto and cf2.modelo.visible and String(cf2.ctrl.call("estado_nombre")) == "abierto")
	_ok("6 no vuelve a aparecer cerrado ni con efecto", apariciones2[0] == 0 and not cf2.es_cerrado and not cf2.es_oculto)
	_ok("6 su casilla sigue bloqueada (es un cofre)", Terreno3D.bloqueada(Vector2i(10, 7)))
	_ok("6 la sala nace abierta y NO se cierra con el jugador dentro (aunque haya goblins)", not cj2.cerrado and v2.completo and not Terreno3D.bloqueada(Vector2i(4, 5)))
	g4.free()

	# 6b. Partida a medias: solo la sala limpia (el cofre aún no se abrió)
	_desmontar(z2)
	Flags.nuevo()
	Flags.i().poner("prueba.s1.limpia")
	var z3: Puzle3D = _levantar()
	await _espera(0.3)
	var cf3: Puzle3D.CofrePuzle = z3.nodo("cf") as Puzle3D.CofrePuzle
	var v3: Puzle3D.VigiaPuzle = z3.nodo("v") as Puzle3D.VigiaPuzle
	_ok("6b con la sala limpia y el cofre sin abrir, el cofre nace CERRADO y visible (aparece_si ya se cumple), sin efecto", cf3.es_cerrado and cf3.modelo.visible and String(cf3.ctrl.call("estado_nombre")) == "cerrado" and v3.completo)
	# Y ahora se abre: la flag manda.
	_ok("6b se puede abrir", cf3.abrir())
	await _espera(1.8)
	_ok("6b abierto pone su flag", Flags.i().tiene("prueba.s1.cofre"))

	# 6c. Partida nueva: todo como al principio
	_desmontar(z3)
	Flags.nuevo()
	var z4: Puzle3D = _levantar()
	await _espera(0.3)
	var cf4: Puzle3D.CofrePuzle = z4.nodo("cf") as Puzle3D.CofrePuzle
	_ok("6c partida nueva: el cofre vuelve a estar OCULTO", cf4.es_oculto and not cf4.modelo.visible and not Terreno3D.bloqueada(Vector2i(10, 7)))
	# La carga llega DESPUÉS de montar el nivel: el cofre se abre solo.
	Flags.i().cargar(RUTA)
	await process_frame
	_ok("6c cargar la partida DESPUÉS de montar abre el cofre", cf4.es_abierto and cf4.modelo.visible and String(cf4.ctrl.call("estado_nombre")) == "abierto")
	_desmontar(z4)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA))
	for g in [g1, g2, g3, fuera]:
		if is_instance_valid(g):
			g.free()
	await _espera(1.5)


# ---------------------------------------------------------------------------------------------------------------------
#  7. Un vigía que no casa con nadie
# ---------------------------------------------------------------------------------------------------------------------

func _vigia_sin_enemigos() -> void:
	Flags.nuevo()
	var z := Puzle3D.new()
	root.add_child(z)
	z.iniciar(_mundo, "", "\n".join([
		"; pieza v vigia 1 1 de=5,3..11,8",
		"; pieza c cofre 10 7 aparece_si=v.todos",
	]))
	await _espera(T_SIN + 0.4)
	var v: Puzle3D.VigiaPuzle = z.nodo("v") as Puzle3D.VigiaPuzle
	var c: Puzle3D.CofrePuzle = z.nodo("c") as Puzle3D.CofrePuzle
	_ok("7 un vigía sin enemigos que casen NO da la sala por limpia", v != null and not v.completo and c.es_oculto)
	var avisado: bool = false
	for a in z.avisos:
		if String(a).contains("ningún enemigo"):
			avisado = true
	_ok("7 y lo avisa una vez", avisado and z.avisos.size() == 1, str(z.avisos))
	_desmontar(z)


const T_SIN: float = Puzle3D.T_VIGIA_SIN_ENEMIGOS
