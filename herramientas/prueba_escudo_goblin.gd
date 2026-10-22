extends SceneTree
## Escudo del goblin con el NODO REAL (modelo GLB con esqueleto), mano quemada y burbujas del hundimiento (22/10).
## Sin ventana: godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_escudo_goblin.gd
##   1. El escudo va colgado del antebrazo (`en_brazo`), a poca distancia del hueso, lo sigue al cambiar de clip y oculta el de adorno de Equipo3D.
##   2. Los efectos de EXCEPCIONES["escudo"] (prendido, consumido, bloqueado) se resuelven y suenan con el nodo real del escudo.
##   3. Escudo mojado: capa visible al recibir agua, se aclara al final y desaparece al secarse; fuego sobre mojado lo seca.
##   4. Mano quemada: el clip existe (por código), está en el grafo reducido y en SINONIMOS, el goblin lo reproduce al consumirse el escudo y salen las chispas.
##   5. El escudo quemado se disuelve por celdas (uniform `disolver` de 0 a 1 en T_DESINTEGRA).
##   6. Burbujas: duran lo que el hundimiento real y la constante compartida es la de Combate3D.

const DT: float = 1.0 / 30.0
const S: float = 2.3
var _mundo: Mundo3D = null
var _jugador: Jugador3D = null
var _fallos: int = 0
var _emitidas: Array = []


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	var filas: PackedStringArray = []
	for _y in range(10):
		filas.append("..........")
	Terreno3D.alturas.clear()
	Terreno3D.permanentes.clear()
	Terreno3D.cargar_datos(filas, {})
	Terreno3D.activar_fuente_casillas()
	_mundo = Mundo3D.new()
	root.add_child(_mundo)
	_mundo.reaccion.connect(func(n: String, p: Vector3, nd: Node) -> void: _emitidas.append([n, p, nd]))
	_jugador = Jugador3D.new()
	_jugador.position = Vector3(1.5 * S, Terreno3D.alto_suelo, 8.5 * S)
	_jugador.pj = Pj3D.new()
	_mundo.add_child(_jugador.pj)
	await _brazo()
	await _excepciones()
	await _mojado()
	await _mano()
	await _burbujas()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _goblin(cx: int, cz: int) -> Combate3D:
	var p := Vector3((cx + 0.5) * S, Terreno3D.y_pies(Vector2i(cx, cz)), (cz + 0.5) * S)
	var modelo := Pj3D.new()
	_mundo.add_child(modelo)
	modelo.cargar("goblin_warrior_chibi")
	modelo.grafo = ArbolAnimPj.GRAFO_REDUCIDO
	modelo.set_alto(0.85)
	modelo.position = p
	var g: Combate3D = Combate3D.equipar(modelo, _mundo, _jugador, null)
	g.altura = 0.85
	g.quieto = true
	g.position = p
	g.casa = p
	g.mirada = Vector3(0, 0, 1)
	g.health = 100000.0
	g.vida_max = 100000.0
	return g


func _pasos(g: Combate3D, segundos: float) -> void:
	for _i in range(int(ceil(segundos / DT))):
		await process_frame                  # el escudo corre su propia física: un fotograma = DT


func _n(nombre: String, nodo: Node) -> int:
	var c: int = 0
	for e in _emitidas:
		if e[0] == nombre and e[2] == nodo:
			c += 1
	return c


func _rune(a: String) -> RuneData:
	return load("res://nucleo/%s_rune.tres" % a)


func _h(a: String) -> Hechizo:
	return Hechizo.construir(_rune(a), {})


func _brazo() -> void:
	var g := _goblin(2, 2)
	var e: Escudo3D = Escudo3D.equipar(g)
	g.set_physics_process(false)
	await process_frame
	await process_frame
	_ok("1.1 con un modelo con esqueleto el escudo va EN EL BRAZO", e.en_brazo)
	var hueso: Variant = g.pj.hueso_ahora(Escudo3D.HUESO_ESCUDO)
	_ok("1.2 existe el hueso del antebrazo", hueso != null)
	var d: float = e.global_position.distance_to((hueso as Transform3D).origin)
	_ok("1.3 el centro del disco está pegado al antebrazo (< 0,2 u; no flota)", d < 0.2, "d=%.3f" % d)
	var adorno: int = g.pj.poner_equipo_visible("escudo", false)
	_ok("1.4 el escudo de adorno del brazo existe y se oculta (no se ve doble)", adorno == 1)
	var antes: Vector3 = e.global_position
	g.pj.animacion_actual = ""
	g.pj.jugar("walk")
	for _i in 20:
		await process_frame
	_ok("1.5 al cambiar de clip el escudo sigue a la mano (se mueve)", e.global_position.distance_to(antes) > 0.02, "mov=%.3f" % e.global_position.distance_to(antes))
	var d2: float = e.global_position.distance_to((g.pj.hueso_ahora(Escudo3D.HUESO_ESCUDO) as Transform3D).origin)
	_ok("1.6 y sigue pegado al hueso", d2 < 0.2, "d=%.3f" % d2)
	var sin_esq := Combate3D.equipar(_sin_modelo(), _mundo, _jugador, null)
	var e2: Escudo3D = Escudo3D.equipar(sin_esq)
	_ok("1.7 sin esqueleto vuelve a ir delante del cuerpo", not e2.en_brazo)


func _sin_modelo() -> Pj3D:
	var m := Pj3D.new()
	m.id = "goblin_warrior"
	m.position = Vector3(5.5 * S, Terreno3D.alto_suelo, 5.5 * S)
	_mundo.add_child(m)
	return m


func _excepciones() -> void:
	var g := _goblin(4, 2)
	var e: Escudo3D = Escudo3D.equipar(g)
	g.set_physics_process(false)
	_emitidas.clear()
	g.on_spell_hit(_rune("fire"), Vector3(0, 0, -1), _h("fire"))
	_ok("2.1 un disparo de fuego de frente: `bloqueado` y `prendido` con el nodo del escudo", _n("bloqueado", e) == 1 and _n("prendido", e) == 1, str(_emitidas.size()))
	for tipo in ["bloqueado", "prendido", "consumido"]:
		var fila: Dictionary = ReaccionesVfx3D.resolver(tipo, ReaccionesVfx3D.tipo_de(e))
		_ok("2.2 `%s` del escudo resuelve su EXCEPCIÓN" % tipo, ReaccionesVfx3D.tipo_de(e) == "escudo" and ReaccionesVfx3D.EXCEPCIONES["escudo"].has(tipo) and not fila.is_empty(), str(fila))
	var r: Dictionary = ReaccionesVfx3D.reproducir("prendido", e.global_position, e, _mundo)
	_ok("2.3 reproducir `prendido` con el nodo real: llamas pequeñas (esc 0,5) y bucle", r.get("vfx") == "llamas_cuerpo" and is_equal_approx(float(r.get("esc")), 0.5) and bool(r.get("bucle")), str(r))
	_ok("2.4 y deja un sonido en bucle sonando", ReaccionesVfx3D.suena_bucle(e))
	var c: Dictionary = ReaccionesVfx3D.reproducir("consumido", e.global_position, e, _mundo)
	_ok("2.5 `consumido` = escudo_roto y corta el bucle", c.get("vfx") == "escudo_roto" and not ReaccionesVfx3D.suena_bucle(e), str(c))
	var b: Dictionary = ReaccionesVfx3D.reproducir("bloqueado", e.global_position, e, _mundo)
	_ok("2.6 `bloqueado` = escudo_golpe", b.get("vfx") == "escudo_golpe", str(b))


func _mojado() -> void:
	var g := _goblin(6, 2)
	var e: Escudo3D = Escudo3D.equipar(g)
	g.set_physics_process(false)
	_ok("3.1 seco al principio", not e.se_ve_mojado())
	g.on_spell_hit(_rune("water"), Vector3(0, 0, -1), _h("water"))
	var tiene_capa: bool = false
	for m in e._entero.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).material_overlay != null:
			tiene_capa = true
	_ok("3.2 con agua se ve mojado (capa sobre las mallas del escudo entero)", e.se_ve_mojado() and tiene_capa)
	var a0: float = e._capa_mojada.albedo_color.a
	await _pasos(g, Escudo3D.T_MOJADO - Escudo3D.T_SECADO * 0.5)
	var a1: float = e._capa_mojada.albedo_color.a if e._capa_mojada != null else 0.0
	_ok("3.3 al acercarse el final se aclara (más suave que al principio)", a1 < a0 and a1 > 0.0, "%.2f -> %.2f" % [a0, a1])
	await _pasos(g, Escudo3D.T_SECADO)
	var queda: bool = false
	for m in e._entero.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).material_overlay != null:
			queda = true
	_ok("3.4 se seca: sin capa", not e.se_ve_mojado() and not queda)
	g.on_spell_hit(_rune("water"), Vector3(0, 0, -1), _h("water"))
	g.on_spell_hit(_rune("fire"), Vector3(0, 0, -1), _h("fire"))
	_ok("3.5 fuego sobre mojado lo seca de golpe (vapor)", not e.se_ve_mojado() and e.estado == "entero")


func _mano() -> void:
	var g := _goblin(2, 4)
	var e: Escudo3D = Escudo3D.equipar(g)
	var p: Pj3D = g.pj
	_ok("4.1 el goblin tiene el clip `mano_quemada` (construido por código: no viene en el GLB)", p.tiene_mano_quemada() and p.clip_de("mano_quemada") == Pj3D.ANIM_MANO_QUEMADA)
	_ok("4.2 dura lo que T_MANO_QUEMADA", is_equal_approx(p.duracion("mano_quemada"), Escudo3D.T_MANO_QUEMADA), "%.2f" % p.duracion("mano_quemada"))
	_ok("4.3 `mano_quemada` está en ESTADOS_REDUCIDO y en SINONIMOS", ArbolAnimPj.ESTADOS_REDUCIDO.has("mano_quemada") and Pj3D.SINONIMOS.has("mano_quemada"))
	var mueve: bool = false
	for h in Pj3D.MANO_QUEMADA_HUESOS.keys():
		if absf(Pj3D.giro_mano_quemada(h, 0.4).w) < 0.999:
			mueve = true
	_ok("4.4 el clip mueve el brazo (giros distintos del Idle) y vuelve al Idle al final", mueve and Pj3D.giro_mano_quemada("mixamorig_LeftHand", 1.0).is_equal_approx(Quaternion.IDENTITY))
	var emitidas: Array = []
	e.mano_quemada.connect(func(gg: Combate3D) -> void: emitidas.append(gg))
	e.prender()
	e.arde_t = 0.01
	g.set_physics_process(true)
	await process_frame
	await process_frame
	await process_frame
	_ok("4.5 al consumirse ardiendo: señal `mano_quemada`, goblin aturdido y clip pedido", emitidas.size() == 1 and g.stun_timer > 0.5 and p.animacion_actual == "mano_quemada", "%s stun=%.2f anim=%s" % [emitidas.size(), g.stun_timer, p.animacion_actual])
	var chispas: Node = p._esqueleto().find_child("ChispasManoQuemada", true, false)
	_ok("4.6 salen las chispas en la mano (attachment con 3 emisores)", chispas != null and chispas.get_child_count() == 3, str(chispas))
	for _i in int(Escudo3D.T_MANO_QUEMADA / DT) + 5:
		await process_frame
	_ok("4.7 el goblin sale del aturdimiento y las chispas dejan de emitir", g.stun_timer <= 0.0 and chispas != null and not (chispas.get_child(0) as GPUParticles3D).emitting)
	for _i in int(VfxReaccion3D.VIDA_RESTO_MANO_QUEMADA / DT) + 5:
		await process_frame
	_ok("4.8 y el attachment se libera solo", not is_instance_valid(chispas))
	# Disolver por celdas
	_ok("5.1 la malla quemada usa el material común con `disolver`", not e._mats_quemado.is_empty())
	_ok("5.2 el disolver llegó (casi) a 1 al desintegrarse", e.disolver > 0.9 or e.desintegra_t <= 0.0, "disolver=%.2f desint=%.2f" % [e.disolver, e.desintegra_t])
	_ok("5.3 ya no se ve la malla quemada", not e._quemado.visible)


func _burbujas() -> void:
	_ok("6.1 la duración por defecto del efecto es la constante de Combate3D", is_equal_approx(VfxReaccion3D.DURA_HUNDIMIENTO, Combate3D.TIEMPO_HUNDIMIENTO))
	_ok("6.2 sin anunciar nada, `dura_hundimiento` = esa constante", is_equal_approx(ReaccionesVfx3D.dura_hundimiento(Node3D.new()), Combate3D.TIEMPO_HUNDIMIENTO))
	var g := _goblin(4, 4)
	g.set_physics_process(false)
	g._punto_hundido = Vector3(g.global_position.x, Terreno3D.alto_agua, g.global_position.z)
	g._morir(true)
	var dur: float = g.duracion_hundimiento
	_ok("6.3 el goblin anuncia lo que dura de verdad su hundimiento (el clip)", dur > 0.5 and is_equal_approx(dur, g.pj.duracion("drown")), "%.2f" % dur)
	var hundidos: int = _n("hundido", g)
	_ok("6.4 y `ReaccionesVfx3D` lo lee", is_equal_approx(ReaccionesVfx3D.dura_hundimiento(g), dur))
	var r: Node3D = VfxReaccion3D.hundimiento(_mundo, Vector3(1, 0, 1), 1.0, ReaccionesVfx3D.dura_hundimiento(g))
	_ok("6.5 el efecto se monta con esa duración", is_equal_approx(float(r.get_meta("dura")), dur))
	var vistas: Dictionary = {}                 # id de cada tanda de burbujas (amount 5) -> su vida
	var t_ultima: float = 0.0
	for i in int(dur / DT) + 3:
		await process_frame
		for ch in r.get_children():
			if ch is GPUParticles3D and (ch as GPUParticles3D).amount == 5 and not vistas.has(ch.get_instance_id()):
				vistas[ch.get_instance_id()] = (ch as GPUParticles3D).lifetime
				t_ultima = float(i) * DT
	var tandas: int = vistas.size()
	_ok("6.6 las 7 tandas de burbujas salen TODAS dentro del hundimiento (la última a %.2f de %.2f s)" % [t_ultima, dur], tandas == VfxReaccion3D.TANDAS_BURBUJAS and t_ultima <= dur, "tandas=%d" % tandas)
	var ultima_vida: float = 0.0
	for v in vistas.values():
		ultima_vida = float(v)
	_ok("6.7 la última tanda vive poco (no pasa de lo que queda de hundimiento)", ultima_vida <= maxf(dur / float(VfxReaccion3D.TANDAS_BURBUJAS), VfxReaccion3D.VIDA_BURBUJA_MIN) + 0.01, "vida=%.2f" % ultima_vida)
	_ok("6.8 se emitió la reacción `hundido` con el goblin (una vez)", hundidos == 1)
