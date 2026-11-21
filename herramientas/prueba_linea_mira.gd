extends "res://herramientas/escenario_base.gd"
## LÍNEA DE MIRA de las flechas (21/11/2026; Pablo: «quiero que las flechas sean visibles»; enemigos/aviso_ataque_3d.gd `linea`, combate_3d.gd, chaman_3d.gd, objetos/trampa_flechas_3d.gd, estela_flecha_3d.gd).
## Tres escenas reales, una detrás de otra:
##   A · Bosque: el arquero goblin. La línea sale al tensar, es tenue y SIGUE a la jugadora, se FIJA en los últimos T_FIJADO s (ya no se mueve aunque ella sí; el círculo del destino se fija con ella), la flecha
##       sale HACIA el punto fijado (si ella se apartó, falla), la línea se apaga al soltar, no cuenta para la esquiva (no está en el grupo de avisos) y con AVISAR_ATAQUES apagado no sale. `fin_de_vuelo` acaba en el muro.
##   B · Sala del chamán: lo mismo con la flecha de veneno (línea verde, estela verde).
##   C · Laboratorio de puzles de fuego: el mascarón de flechas. La línea sale con el aviso (0,6 s), de la ranura al muro del fondo; un bloque delante la acorta; se apaga al disparar o al apagar la trampa;
##       con cada = 1,0 s los disparos siguen saliendo cada segundo exacto (el aviso más largo NO mueve el ciclo); la flecha normal lleva estela.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_linea_mira.gd

const FILA: int = 33
const RUTA_LAB: String = "res://laboratorios/LabPuzlesFuego3D.tscn"
const RUTA_SALA: String = "res://escenas/PruebaSalaChaman.tscn"

var _creados: Array = []
var _extras: Array = []


func _pos(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) + 0.5) * Terreno3D.casilla, Terreno3D.y_pies(c), (float(c.y) + 0.5) * Terreno3D.casilla)


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	Repertoire.activate_all()
	await avanzar(20)
	await _caso_arquero()
	await _caso_fin_de_vuelo()
	await _caso_apagado()
	await _recargar(RUTA_SALA, true)
	await _caso_chaman()
	await _recargar(RUTA_LAB, false)
	await _caso_trampa()
	await _caso_trampa_ciclo()


## Quita la escena de antes y carga otra (el reloj se conserva).
func _recargar(ruta: String, usar_escena: bool) -> void:
	_limpiar()
	if maqueta != null and is_instance_valid(maqueta):
		maqueta.queue_free()
	await avanzar(5)
	maqueta = null
	lanzador = null
	jugador = null
	await cargar(ruta, usar_escena)


func _limpiar() -> void:
	var lista: Variant = maqueta.get("_goblins") if maqueta != null and is_instance_valid(maqueta) else null
	for n in _creados:
		if is_instance_valid(n):
			if n is Combate3D:
				(n as Combate3D)._quitar_aviso()
			if lista is Array:
				(lista as Array).erase(n)
			(n as Node).queue_free()
	_creados.clear()
	for a in get_nodes_in_group(AvisoAtaque3D.GRUPO) + get_nodes_in_group(AvisoAtaque3D.GRUPO_LINEAS):
		(a as AvisoAtaque3D).cancelar()
	for n in _extras:
		if is_instance_valid(n):
			n.queue_free()
	_extras.clear()
	if lanzador != null and is_instance_valid(lanzador):
		TiempoBruja.terminar(lanzador)
	Engine.time_scale = 1.0
	Combate3D.AVISAR_ATAQUES = true


func _jugadora_lista(c: Vector2i) -> void:
	colocar_jugador(c)
	var j: Jugador3D = jugador as Jugador3D
	j.vida = 100000.0
	j._t_inv = 0.0
	j._roll_cd = 0.0
	j._t_roll = 0.0
	j._empuje = Vector3.ZERO


func _mover_jugadora(d: Vector3) -> void:
	var j: Jugador3D = jugador as Jugador3D
	j.position += d
	j.pj.position = j.position
	j._ultima = j.position


func _enemigo(ids: Array, c: Vector2i) -> Combate3D:
	var p: Vector3 = _pos(c)
	var modelo: Pj3D = maqueta.call("_personaje", ids, p)
	if modelo == null:
		return null
	var g: Combate3D = Combate3D.equipar(modelo, maqueta, jugador as Jugador3D, lanzador)
	g.position = p
	g.casa = p
	g.health = 100000.0
	g.vida_max = 100000.0
	_creados.append(g)
	_creados.append(modelo)
	return g


## La línea de mira viva (no apagándose) de `dueno`, o null.
func _linea_de(dueno: Node) -> AvisoAtaque3D:
	for a in get_nodes_in_group(AvisoAtaque3D.GRUPO_LINEAS):
		var l: AvisoAtaque3D = a as AvisoAtaque3D
		if l != null and is_instance_valid(l) and l.dueno == dueno and not l.cancelado and not l.apagando:
			return l
	return null


func _esperar_linea(dueno: Node, max_s: float = 8.0) -> AvisoAtaque3D:
	var t: float = 0.0
	while t < max_s:
		var l: AvisoAtaque3D = _linea_de(dueno)
		if l != null:
			return l
		t += await avanzar_s(1.0 / 30.0)
	return null


func _flecha_goblin(en: Node) -> Node3D:
	var r: Node3D = null
	for n in en.get_children():
		if n is Node3D and (n as Node3D).has_meta("flecha_goblin"):
			r = n
	return r


func _xz(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)


# ---------------------------------------------------------------------------------------------------------------------
#  A · el arquero goblin
# ---------------------------------------------------------------------------------------------------------------------

func _caso_arquero() -> void:
	print("--- A · arquero")
	_jugadora_lista(Vector2i(10, FILA))
	var g: Combate3D = _enemigo(["goblin_archer_chibi"], Vector2i(12, FILA))
	if g == null or not g.arquero:
		_aviso("A: no hay modelo goblin_archer_chibi; caso saltado")
		return
	var ln: AvisoAtaque3D = await _esperar_linea(g)
	_ok("A1 al tensar sale una línea de mira (forma «linea»)", ln != null and ln.forma == "linea")
	if ln == null:
		return
	var circulo: AvisoAtaque3D = null
	for a in get_nodes_in_group(AvisoAtaque3D.GRUPO):
		if (a as AvisoAtaque3D).dueno == g:
			circulo = a
	_ok("A2 el círculo del destino se queda (hay los dos) y la línea NO cuenta para la esquiva (no está en el grupo de avisos)", circulo != null and not ln.is_in_group(AvisoAtaque3D.GRUPO) and ln.is_in_group(AvisoAtaque3D.GRUPO_LINEAS))
	_ok("A3 apuntando: no fijada, tenue y fina (núcleo %.3f u de mitad)" % ln.mitad_nucleo(), not ln.fijada and absf(ln.mitad_nucleo() - AvisoAtaque3D.LINEA_ANCHO_APUNTE * 0.5) < 0.001)
	_ok("A4 sale del arco del goblin (%.2f u de su origen de flecha)" % _xz(ln.centro).distance_to(_xz(g._origen_flecha())), _xz(ln.centro).distance_to(_xz(g._origen_flecha())) < 0.05)
	# SIGUE el apuntado: se mueve a la jugadora 1 u y la línea la acompaña.
	_mover_jugadora(Vector3(0.0, 0.0, 1.0))
	await avanzar(2)
	var objetivo: Vector3 = jugador.position + Vector3(0.0, 0.8, 0.0)
	_ok("A5 mientras apunta SIGUE a la jugadora (punto apuntado a %.2f u de ella)" % _xz(ln.punto_apuntado).distance_to(_xz(objetivo)), not ln.fijada and _xz(ln.punto_apuntado).distance_to(_xz(objetivo)) < 0.1)
	_ok("A6 acaba en el destino (no hay muro entre medias): fin a %.2f u del punto apuntado" % _xz(ln.fin).distance_to(_xz(ln.punto_apuntado)), _xz(ln.fin).distance_to(_xz(ln.punto_apuntado)) < 0.3)
	var n: int = 0
	while is_instance_valid(ln) and not ln.fijada and g._golpe_pendiente and n < 300:
		await avanzar(1)
		n += 1
	_ok("A7 se FIJA a ≈ %.1f s del disparo (quedan %.2f s)" % [AvisoAtaque3D.T_FIJADO, ln.queda()], ln.fijada and ln.queda() <= AvisoAtaque3D.T_FIJADO + 0.06 and ln.queda() >= AvisoAtaque3D.T_FIJADO - 0.12)
	var punto0: Vector3 = ln.punto_apuntado
	var fin0: Vector3 = ln.fin
	_ok("A8 al fijarse el goblin recuerda el punto y el círculo se fija con ella", g._apunte_es_fijo and g._apunte_fijado.distance_to(punto0) < 0.001 and circulo != null and is_instance_valid(circulo) and _xz(circulo.centro).distance_to(_xz(punto0)) < 0.01)
	# Fijada: ella se aparta de lado (2 u) y la línea NO se mueve.
	_mover_jugadora(Vector3(0.0, 0.0, 2.0))
	await avanzar(4)
	_ok("A9 fijada NO se mueve aunque ella sí (punto y fin iguales)", ln.punto_apuntado.distance_to(punto0) < 0.001 and ln.fin.distance_to(fin0) < 0.001 and _xz(circulo.centro).distance_to(_xz(punto0)) < 0.01)
	_ok("A10 fijada es más ancha y más viva (núcleo %.3f ≥ el doble que apuntando)" % ln.mitad_nucleo(), ln.mitad_nucleo() >= AvisoAtaque3D.LINEA_ANCHO_APUNTE * 0.5 * 2.0)
	while g._golpe_pendiente and n < 600:
		await avanzar(1)
		n += 1
	await avanzar(1)
	_ok("A11 al soltar la línea se apaga (apagándose o ya liberada)", not is_instance_valid(ln) or ln.apagando)
	var flecha: Node3D = _flecha_goblin(g.mundo)
	_ok("A12 sale la flecha en vuelo", flecha != null)
	if flecha != null:
		var eje: Vector3 = -flecha.global_transform.basis.z.normalized()
		var hacia_fijo: Vector3 = (punto0 - flecha.global_position).normalized()
		var hacia_ella: Vector3 = (jugador.position + Vector3(0.0, 0.8, 0.0) - flecha.global_position).normalized()
		_ok("A13 la flecha va HACIA el punto fijado (cos %.3f) y no hacia donde está ella ahora (cos %.3f): lo que se ve es lo que pega" % [eje.dot(hacia_fijo), eje.dot(hacia_ella)], eje.dot(hacia_fijo) > 0.99 and eje.dot(hacia_ella) < 0.985)
		_ok("A14 la flecha lleva estela (cintas hijas, el cuerpo de la flecha no cambia)", flecha.get_node_or_null("Estela") is EstelaFlecha3D and flecha.get_node("Estela").get_child_count() == 2)
	var v0: float = (jugador as Jugador3D).vida
	await avanzar_s(2.0)
	_ok("A15 ella se apartó tras fijarse: la flecha falla (vida %.0f → %.0f)" % [v0, (jugador as Jugador3D).vida], (jugador as Jugador3D).vida >= v0)
	await avanzar_s(0.3)
	_ok("A16 la línea ya no existe", not is_instance_valid(ln))
	# Quieta hasta el final: sí da.
	_limpiar()
	await avanzar(3)
	_jugadora_lista(Vector2i(10, FILA))
	var g2: Combate3D = _enemigo(["goblin_archer_chibi"], Vector2i(12, FILA))
	var v1: float = (jugador as Jugador3D).vida
	var ln2: AvisoAtaque3D = await _esperar_linea(g2)
	var hubo2: bool = ln2 != null
	var t_dano: float = 0.0
	while t_dano < 5.0 and (jugador as Jugador3D).vida >= v1:
		t_dano += await avanzar_s(1.0 / 30.0)
	_ok("A17 si ella se queda quieta sobre la línea fijada, la flecha le da (%.1f s)" % t_dano, hubo2 and (jugador as Jugador3D).vida < v1, "vida %.0f → %.0f" % [v1, (jugador as Jugador3D).vida])
	# Arquero de puesto: el apuntado lleva ADELANTO (donde estará ella).
	g2.fijo = true
	g2._vel_jug = Vector3(3.0, 0.0, 0.0)
	var sin_adelanto: Vector3 = jugador.position + Vector3(0.0, 0.8, 0.0)
	var con: Vector3 = g2._apunte_vivo()
	_ok("A18 el arquero de puesto apunta con ADELANTO (%.2f u por delante de ella)" % con.distance_to(sin_adelanto), con.distance_to(sin_adelanto) > 0.3 and con.distance_to(g2._con_adelanto(g2._origen_flecha(), sin_adelanto)) < 0.001)
	_limpiar()
	await avanzar(3)


func _caso_fin_de_vuelo() -> void:
	print("--- A2 · hasta dónde llega")
	# Hacia el este desde (10, FILA): el primer muro de verdad.
	var y: float = Terreno3D.y_pies(Vector2i(10, FILA)) + 1.0
	var o: Vector3 = _pos(Vector2i(10, FILA))
	o.y = y
	var muro: int = -1
	for x in range(11, 60):
		if Terreno3D.celda_solida(Vector2i(x, FILA), 0):
			muro = x
			break
	if muro < 0:
		_aviso("A19: no hay un muro al este de (10,%d); caso saltado" % FILA)
		return
	var lejos: Vector3 = o + Vector3(float(muro + 3 - 10) * Terreno3D.casilla, 0.0, 0.0)
	var fin: Vector3 = AvisoAtaque3D.fin_de_vuelo(o, lejos, lanzador)
	var borde: float = float(muro) * Terreno3D.casilla
	_ok("A19 `fin_de_vuelo` se para ANTES del primer muro (x=%d): fin.x %.2f ≤ borde %.2f y a menos de %.2f de él" % [muro, fin.x, borde, AvisoAtaque3D.LINEA_PASO + 0.01], fin.x <= borde + 0.001 and fin.x >= borde - AvisoAtaque3D.LINEA_PASO - 0.01)
	var corto: Vector3 = o + Vector3(1.0, 0.0, 0.0)
	_ok("A20 si nada la corta llega al destino", AvisoAtaque3D.fin_de_vuelo(o, corto, lanzador).distance_to(corto) < 0.001)
	var ln: AvisoAtaque3D = AvisoAtaque3D.linea(maqueta, o, lejos, 1.0, null, lanzador)
	_ok("A21 la línea creada hasta el otro lado del muro acaba en el muro (fin.x %.2f)" % ln.fin.x, ln != null and absf(ln.fin.x - fin.x) < 0.001)
	ln.cancelar()
	# Una barrera (volumen con solidez) también la corta.
	_jugadora_lista(Vector2i(10, FILA))
	await avanzar(2)


func _caso_apagado() -> void:
	print("--- A3 · AVISAR_ATAQUES apagado")
	Combate3D.AVISAR_ATAQUES = false
	_ok("A22 `AvisoAtaque3D.linea` devuelve null con AVISAR_ATAQUES apagado", AvisoAtaque3D.linea(maqueta, Vector3.ZERO, Vector3.RIGHT, 1.0) == null)
	_jugadora_lista(Vector2i(10, FILA))
	var g: Combate3D = _enemigo(["goblin_archer_chibi"], Vector2i(12, FILA))
	if g == null:
		return
	var ln: AvisoAtaque3D = await _esperar_linea(g, 3.5)
	_ok("A23 el arquero ataca sin línea ni aviso con AVISAR_ATAQUES apagado", ln == null and g._linea == null and g._aviso == null)
	Combate3D.AVISAR_ATAQUES = true
	_limpiar()
	await avanzar(3)


# ---------------------------------------------------------------------------------------------------------------------
#  B · el chamán
# ---------------------------------------------------------------------------------------------------------------------

func _caso_chaman() -> void:
	print("--- B · chamán")
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	if z == null:
		_ok("B0 la sala del chamán tiene sus puzles", false)
		return
	Repertoire.activate_all()
	await avanzar(10)
	var j: Jugador3D = jugador as Jugador3D
	var ch: Chaman3D = z.nodo("chaman_a") as Chaman3D
	_ok("B0 hay chamán", ch != null)
	if ch == null:
		return
	for n in get_nodes_in_group("combate3d"):
		if n is Combate3D and not (n is Chaman3D):
			(n as Combate3D).quieto = true                # los guerreros de la sala no molestan
	ch.quieto = false
	ch.objetivo = null
	ch.c_estado = "vigila"
	ch._cd_ritual = 99.0
	ch._cd_bola = 99.0
	ch._cd_flecha = 0.0
	colocar_jugador(Vector2i(13, 5))
	j.vida = 100.0
	j._t_inv = 0.0
	j.curar_estado("veneno")
	ch.position = Vector3(j.position.x + 7.0, j.position.y, j.position.z)
	ch._empuje = Vector3.ZERO
	var f0: int = ch.flechas
	ch._empezar_lanzar("flecha")
	var ln: AvisoAtaque3D = _linea_de(ch)
	_ok("B1 al levantar el bastón sale la línea de mira, teñida del verde del veneno", ln != null and ln.color_linea.is_equal_approx(Chaman3D.COLOR_FLECHA_VENENO) and ln.forma == "linea")
	if ln == null:
		return
	_ok("B2 dura hasta que suelta (INSTANTE_LANZAR / ritmo = %.2f s) y no cuenta para la esquiva" % ln.t_impacto, absf(ln.t_impacto - AnimacionesChaman.INSTANTE_LANZAR / ch.ritmo()) < 0.02 and not ln.is_in_group(AvisoAtaque3D.GRUPO))
	var n: int = 0
	while is_instance_valid(ln) and not ln.fijada and n < 300:
		await avanzar(1)
		n += 1
	var punto0: Vector3 = ln.punto_apuntado
	_ok("B3 se fija a ≈ %.2f s de soltar (quedan %.2f s)" % [ln.fijado_s, ln.queda()], ln.fijada and ln.queda() <= ln.fijado_s + 0.06 and ch._apunte_es_fijo)
	_mover_jugadora_c(j, Vector3(0.0, 0.0, 2.0 * Terreno3D.casilla))
	var t: float = 0.0
	while t < 4.0 and ch.flechas == f0:
		await avanzar(1)
		t += 1.0 / 30.0
	_ok("B4 suelta la flecha de veneno", ch.flechas == f0 + 1 and ch.ultima_flecha != null and is_instance_valid(ch.ultima_flecha))
	if ch.ultima_flecha != null and is_instance_valid(ch.ultima_flecha):
		var fl: Node3D = ch.ultima_flecha
		var eje: Vector3 = -fl.global_transform.basis.z.normalized()
		var hacia: Vector3 = (punto0 - fl.global_position).normalized()
		_ok("B5 la flecha va hacia el punto fijado (cos %.3f)" % eje.dot(hacia), eje.dot(hacia) > 0.99)
		_ok("B6 lleva estela", fl.get_node_or_null("Estela") is EstelaFlecha3D)
	await avanzar_s(1.5)
	_ok("B7 ella se apartó tras fijarse: falla (vida %.1f, pilas %d)" % [j.vida, j.pilas_veneno()], j.pilas_veneno() == 0 and is_equal_approx(j.vida, 100.0))
	_ok("B8 la línea se apagó al soltar", not is_instance_valid(ln))
	# Interrumpido a medias: la línea desaparece.
	ch._cd_flecha = 0.0
	ch.c_estado = "vigila"
	ch._empezar_lanzar("flecha")
	await avanzar(2)
	var ln2: AvisoAtaque3D = _linea_de(ch)
	var hubo: bool = ln2 != null
	ch._terminar_lanzar()
	await avanzar_s(0.3)
	_ok("B9 si se interrumpe el lanzamiento la línea desaparece", hubo and not is_instance_valid(ln2), "hubo %s · estado %s · flechas %d" % [str(hubo), ch.c_estado, ch.flechas])


func _mover_jugadora_c(j: Jugador3D, d: Vector3) -> void:
	j.pj.position += d
	j.position += d


# ---------------------------------------------------------------------------------------------------------------------
#  C · el mascarón de flechas
# ---------------------------------------------------------------------------------------------------------------------

func _props() -> Node:
	return maqueta.get("_props") as Node


func _flechas(c: Vector2i, mira: String, cada: float, elem: String = "fuego", alcance: int = 8, vel: float = 3.5, desfase: float = 0.0) -> TrampaFlechas3D:
	var t := TrampaFlechas3D.new()
	t.name = "TestFlechas%d_%d" % [c.x, c.y]
	t.preparar(c, mira, elem, alcance, maqueta)
	t.preparar_ciclo(cada, desfase, vel)
	_props().add_child(t)
	_extras.append(t)
	return t


func _bloque(c: Vector2i) -> BloqueEmpujable3D:
	var b := BloqueEmpujable3D.new()
	b.name = "BloqueTest%d_%d" % [c.x, c.y]
	b.preparar(c, "piedra", maqueta)
	_props().add_child(b)
	return b


func _hasta_aviso(f: TrampaFlechas3D, max_s: float = 6.0) -> bool:
	var t: float = 0.0
	while t < max_s and not (f.en_aviso and f.linea != null):
		t += await avanzar_s(1.0 / 30.0)
	return f.en_aviso and f.linea != null


func _caso_trampa() -> void:
	print("--- C · mascarón de flechas")
	var j: Jugador3D = jugador as Jugador3D
	j.vida = 100.0
	j.muerto = false
	j._t_inv = 0.0
	colocar_jugador(Vector2i(2, 2))
	_ok("C0 el aviso del mascarón sube a 0,6 s (AVISO_S %.2f)" % TrampaFlechas3D.AVISO_S, absf(TrampaFlechas3D.AVISO_S - 0.6) < 0.001)
	# Mascarón en el muro (16,19) que mira al este: la fila y=19, muro del fondo en x=24 (como en prueba_trampas_pared).
	var f: TrampaFlechas3D = _flechas(Vector2i(16, 19), "e", 2.0, "ninguno", 8, 3.5)
	var vio: bool = await _hasta_aviso(f)
	_ok("C1 durante el aviso hay línea de mira", vio and f.linea != null and f.linea.forma == "linea" and f.linea.dueno == f)
	if not vio:
		return
	var ln: AvisoAtaque3D = f.linea
	_ok("C2 la línea NO cuenta para la esquiva (fuera del grupo de avisos)", not ln.is_in_group(AvisoAtaque3D.GRUPO))
	_ok("C3 sale de la ranura (a %.2f u de la boca)" % _xz(ln.centro).distance_to(_xz(f.boca_mundo())), _xz(ln.centro).distance_to(_xz(f.boca_mundo())) < 0.01)
	var borde: float = 24.0 * Terreno3D.casilla
	_ok("C4 llega hasta el muro del fondo y no lo atraviesa (fin.x %.2f ≤ %.2f, a menos de 0,25 u)" % [ln.fin.x, borde], ln.fin.x <= borde + 0.001 and ln.fin.x >= borde - AvisoAtaque3D.LINEA_PASO - 0.01)
	_ok("C5 va por el carril de la flecha (misma z que la ranura: %.2f vs %.2f)" % [ln.fin.z, f.boca_mundo().z], absf(ln.fin.z - f.boca_mundo().z) < 0.01)
	_ok("C6 los primeros s del aviso, tenue (no fijada)", not ln.fijada)
	var n: int = 0
	while is_instance_valid(ln) and not ln.fijada and n < 200:
		await avanzar(1)
		n += 1
	_ok("C7 se fija los últimos %.1f s del aviso (quedan %.2f s)" % [AvisoAtaque3D.T_FIJADO, ln.queda()], ln.fijada and ln.queda() <= AvisoAtaque3D.T_FIJADO + 0.06)
	_ok("C8 el halo es el ancho con el que la flecha acierta (%.2f u de mitad)" % ln.halo, is_equal_approx(ln.halo, TrampaFlechas3D.RADIO_ACIERTO_U))
	var d0: int = f.disparos
	n = 0
	while f.disparos == d0 and n < 200:
		await avanzar(1)
		n += 1
	await avanzar(1)
	_ok("C9 al disparar la línea se apaga detrás de la flecha (f.linea nulo, la línea apagándose)", f.linea == null and (not is_instance_valid(ln) or ln.apagando))
	var fl: FlechaTrampa3D = null
	for ch in _props().get_children():
		if ch is FlechaTrampa3D:
			fl = ch
	_ok("C10 la flecha normal lleva estela y un asta más gruesa (%.2f u)" % FlechaTrampa3D.ASTA_U, fl != null and fl.get_node_or_null("Estela") is EstelaFlecha3D and FlechaTrampa3D.ASTA_U >= 0.07)
	await avanzar_s(0.4)
	_ok("C11 la línea se libera sola", not is_instance_valid(ln))
	# Un bloque delante la acorta.
	var bq: BloqueEmpujable3D = _bloque(Vector2i(20, 19))
	_extras.append(bq)
	await avanzar(3)
	var vio2: bool = await _hasta_aviso(f)
	var ln3: AvisoAtaque3D = f.linea
	var tope: float = 20.0 * Terreno3D.casilla
	_ok("C12 un bloque en (20,19) acorta la línea: fin.x %.2f ≤ %.2f" % [ln3.fin.x if ln3 != null else -1.0, tope], vio2 and ln3.fin.x <= tope + 0.001 and ln3.fin.x >= tope - AvisoAtaque3D.LINEA_PASO - 0.01)
	# Apagar la trampa en pleno aviso quita la línea.
	f.apagar(0.0)
	await avanzar_s(0.3)
	_ok("C13 si la trampa se apaga en pleno aviso, la línea desaparece", f.linea == null and not is_instance_valid(ln3))
	f.encender()
	# Con AVISAR_ATAQUES apagado no hay línea.
	Combate3D.AVISAR_ATAQUES = false
	await avanzar_s(3.0)
	_ok("C14 con AVISAR_ATAQUES apagado la trampa avisa (ranura) pero no dibuja la línea", f.linea == null and f.disparos > d0)
	Combate3D.AVISAR_ATAQUES = true
	# Quitar el bloque.
	var c_bq: Vector2i = bq.celda
	bq.queue_free()
	Terreno3D.liberar_celda(c_bq)
	await avanzar(2)
	f.queue_free()
	_extras.erase(f)
	# Trampa de fuego: la línea es rojo-naranja, nunca amarilla.
	var ff: TrampaFlechas3D = _flechas(Vector2i(16, 21), "e", 2.0, "fuego", 8, 3.5)
	var vio3: bool = await _hasta_aviso(ff)
	var c: Color = ff.linea.color_linea if ff.linea != null else Color.WHITE
	_ok("C15 la trampa de fuego dibuja su línea rojo-naranja, sin amarillo (%s)" % str(c), vio3 and c.r > 0.9 and c.g < 0.5 and c.b < 0.2)
	ff.queue_free()
	_extras.erase(ff)
	await avanzar(3)


func _caso_trampa_ciclo() -> void:
	print("--- C2 · el ciclo no se mueve")
	var f: TrampaFlechas3D = _flechas(Vector2i(16, 19), "e", 1.0, "ninguno", 8, 3.5)
	var tiempos: Array = []
	var d_prev: int = f.disparos
	var t_av: float = 0.0
	var t_prev: float = reloj.t
	var t_ini: float = reloj.t
	while reloj.t - t_ini < 6.2:
		await process_frame
		if f.en_aviso:
			t_av += reloj.t - t_prev
		t_prev = reloj.t
		if f.disparos != d_prev:
			tiempos.append(reloj.t)
			d_prev = f.disparos
	var ok_int: bool = tiempos.size() >= 5
	var peor: float = 0.0
	for i in range(1, tiempos.size()):
		peor = maxf(peor, absf(float(tiempos[i]) - float(tiempos[i - 1]) - 1.0))
	_ok("C16 con cada=1,0 s los disparos siguen saliendo cada segundo (%d disparos, desvío máximo %.3f s)" % [tiempos.size(), peor], ok_int and peor < 0.06)
	_ok("C17 con cada=1,0 s el aviso dura AVISO_S por ciclo (%.2f s de aviso en total, esperado ≈ %.2f)" % [t_av, 6.2 * minf(TrampaFlechas3D.AVISO_S, 1.0)], absf(t_av - 6.2 * 0.6) < 0.5)
	f.queue_free()
	_extras.erase(f)
	_limpiar()
	print("FIN")
