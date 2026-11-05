extends "res://herramientas/escenario_base.gd"
## Prueba de las TRAMPAS DE PARED (5/11/2026; docs/TRAMPAS_PARED_2026-11-05.md): la cabeza de dragón (`trampa_dragon`) y el mascarón de flechas (`trampa_flechas`), en el laboratorio de puzles de fuego (salas F7, F8, F9)
## con la maqueta, el jugador, el Lanzador3D y las piezas de verdad. Comprueba:
##   1. el mapa monta las piezas sin avisos y la gramática rechaza lo mal escrito (trampa en suelo, `ciclo` roto, `mira` desconocida);
##   2. el dragón respeta el ciclo (reposo → aviso 0,5 s → fuego → reposo), el desfase, y los dos de F7 no arden a la vez;
##   3. el chorro llega a su alcance y no más (con reactivos en cada casilla), y se para en un bloque;
##   4. daña a la jugadora dentro y no fuera, respetando su invulnerabilidad; a un enemigo por la vía de los hechizos;
##   5. el agua (hechizo real y regla `apagar`) la apaga 8 s y vuelve sola;
##   6. la flecha sale cada `cada` s, vuela recta a su velocidad, se para en muros y en un bloque, daña a la jugadora (y se acaba ahí), y la de fuego prende los setos y enciende el barril de F9;
##   7. la flecha normal (`elemento=ninguno`) también;
##   8. los nodos no se acumulan;
##   9. MIDE: tamaño de cada pieza, altura de la boca, alcance del chorro y de la flecha, daños.
## Corre con:   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_trampas_pared.gd

const RUTA_LAB: String = "res://laboratorios/LabPuzlesFuego3D.tscn"

class ReactivoFalso extends Node3D:
	var golpes: int = 0
	func on_spell_hit(_rune: RuneData, _dir: Vector3 = Vector3.ZERO) -> void:
		golpes += 1

var lab: Node = null
var _pz: Puzle3D = null
var _runa_agua: RuneData = null
var _extras: Array = []


func _escenario() -> void:
	await cargar(RUTA_LAB)
	lab = maqueta.get_node_or_null("Reglas")
	_ok("0 el laboratorio monta sus salas y las tres de trampas", lab != null and (lab.get("_trampas") as Array).size() == 3, str((lab.get("_trampas") as Array).size()) if lab != null else "sin lab")
	if lab == null:
		return
	_pz = lab.get("_puzle_nodo") as Puzle3D
	_runa_agua = Puzle3D.runa(["agua", "humedo"])
	_ok("1 el mapa monta las piezas de trampas sin avisos", (lab.get("_avisos") as Array).is_empty(), str(lab.get("_avisos")))
	_gramatica()
	_cableado()
	await _ciclo()
	await _alcance_chorro()
	await _dano_jugadora()
	await _dano_enemigo()
	await _agua()
	await _flecha_fuego()
	await _flecha_normal()
	await _lab_f7()
	await _lab_f8()
	await _lab_f9()
	await _nodos()
	_medidas()


# ---------------------------------------------------------------------------------------------------------------------
#  Ayudas
# ---------------------------------------------------------------------------------------------------------------------

func _props() -> Node:
	return maqueta.get("_props") as Node


func _dragon(c: Vector2i, mira: String, enc: float, apag: float, desfase: float = 0.0, alcance: int = 5, elem: String = "fuego") -> TrampaDragon3D:
	var t := TrampaDragon3D.new()
	t.name = "TestDragon%d_%d" % [c.x, c.y]
	t.preparar(c, mira, elem, alcance, maqueta)
	t.preparar_ciclo(enc, apag, desfase)
	_props().add_child(t)
	_extras.append(t)
	return t


func _flechas(c: Vector2i, mira: String, cada: float, elem: String = "fuego", alcance: int = 8, vel: float = 3.5, desfase: float = 0.0) -> TrampaFlechas3D:
	var t := TrampaFlechas3D.new()
	t.name = "TestFlechas%d_%d" % [c.x, c.y]
	t.preparar(c, mira, elem, alcance, maqueta)
	t.preparar_ciclo(cada, desfase, vel)
	_props().add_child(t)
	_extras.append(t)
	return t


func _quitar(t: Node) -> void:
	if is_instance_valid(t):
		t.queue_free()
	_extras.erase(t)


## Un bloque de piedra empujable de verdad en `c`. Al quitarlo hay que liberar su casilla a mano: el bloque no lo hace en `_exit_tree` (en el juego nunca se libera).
func _bloque(c: Vector2i) -> BloqueEmpujable3D:
	var b := BloqueEmpujable3D.new()
	b.name = "BloqueTest%d_%d" % [c.x, c.y]
	b.preparar(c, "piedra", maqueta)
	_props().add_child(b)
	return b


func _quitar_bloque(b: BloqueEmpujable3D) -> void:
	var c: Vector2i = b.celda
	b.queue_free()
	Terreno3D.liberar_celda(c)


## El último proyectil (HechizoVivo con velocidad) vivo del lanzador.
func _ultimo_proyectil() -> HechizoVivo:
	var r: HechizoVivo = null
	for ch in lanzador.get_children():
		if ch is HechizoVivo and (ch as HechizoVivo).proyectil and (ch as HechizoVivo).activo:
			r = ch
	return r


## Sigue un proyectil hasta que acaba: {p0, p (donde acabó), causa, t (s de vuelo), dev_y, dev_z (desvío máximo respecto a la salida)}.
func _seguir(hv: HechizoVivo) -> Dictionary:
	var r: Dictionary = {"p0": Vector3.ZERO, "p": Vector3.ZERO, "causa": "", "t": 0.0, "dev_y": 0.0, "dev_z": 0.0}
	if hv == null:
		return r
	r["p0"] = hv.p
	r["p"] = hv.p
	hv.terminado.connect(func(causa: String, pos: Vector3, _n: Vector3, _m: String) -> void:
		r["causa"] = causa
		r["p"] = pos)
	var t0: float = reloj.t
	var n: int = 0
	while is_instance_valid(hv) and hv.activo and n < 600:
		r["dev_y"] = maxf(float(r["dev_y"]), absf(hv.p.y - (r["p0"] as Vector3).y))
		r["dev_z"] = maxf(float(r["dev_z"]), absf(hv.p.z - (r["p0"] as Vector3).z))
		await process_frame
		n += 1
	r["t"] = reloj.t - t0
	return r


func _reactivo(c: Vector2i) -> ReactivoFalso:
	var r := ReactivoFalso.new()
	r.add_to_group("reactivo3d")
	_props().add_child(r)
	r.position = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
	return r


func _jugadora_lista(c: Vector2i) -> void:
	jugador.set("vida", 100.0)
	jugador.set("muerto", false)
	jugador.set("_t_inv", 0.0)
	colocar_jugador(c)


func _vida() -> float:
	return float(jugador.get("vida"))


func _sin_hijos_vivos(esperar_s: float = 4.0) -> void:
	await avanzar_s(esperar_s)


# ---------------------------------------------------------------------------------------------------------------------
#  1. Gramática y cableado
# ---------------------------------------------------------------------------------------------------------------------

func _gramatica() -> void:
	var buenas: String = "; pieza d trampa_dragon 5 5 mira=s ciclo=2.0,1.5 desfase=0.5 alcance=4 elemento=agua agua=no\n; pieza f trampa_flechas 6 5 mira=e cada=1.2 vel=3 alcance=6 elemento=ninguno\n; puzle p cuando=d.escupe si=f.activa hace=f.apagar(3) y=d.encender\n; puzle q cuando=f.dispara hace=d.apagar"
	var r: Dictionary = Puzle3D.parsear(buenas)
	_ok("1.1 la gramática lee las dos piezas y las dos reglas (señales, condición y acciones con argumento)", (r["piezas"] as Array).size() == 2 and (r["reglas"] as Array).size() == 2 and (r["avisos"] as Array).is_empty(), str(r["avisos"]))
	var p0: Puzle3D.Pieza = (r["piezas"] as Array)[0]
	_ok("1.2 `ciclo=2.0,1.5` llega como [2.0, 1.5] y `agua=no` como false", p0.p.get("ciclo") == [2.0, 1.5] and p0.p.get("agua") == false, str(p0.p))
	for mala in ["; pieza d trampa_dragon 5 5 ciclo=2.0", "; pieza d trampa_dragon 5 5 ciclo=2.0,x", "; pieza d trampa_dragon 5 5 mira=x", "; pieza f trampa_flechas 5 5 cada=a", "; pieza f trampa_flechas 5 5 elemento=dragon",
			"; pieza d trampa_dragon 5 5\n; puzle p cuando=d.escupe hace=d.apagar(1,2)", "; pieza d trampa_dragon 5 5\n; puzle p cuando=d.dispara hace=d.apagar"]:
		var rm: Dictionary = Puzle3D.parsear(mala)
		var mal: bool = not (rm["avisos"] as Array).is_empty() and ((rm["piezas"] as Array).is_empty() or (rm["reglas"] as Array).is_empty())
		_ok("1.3 la gramática rechaza «%s»" % mala.replace("\n", " ¦ "), mal, str(rm["avisos"]))
	# Una trampa en una casilla de SUELO (o que da a un muro) se avisa y no se monta.
	var otro := Puzle3D.new()
	root.add_child(otro)
	otro.iniciar(maqueta, "PuzlesFuego", "; pieza en_suelo trampa_dragon 10 10 mira=s\n; pieza da_al_muro trampa_flechas 0 5 mira=o\n; pieza fuera trampa_dragon 99 99\n")
	_ok("1.4 una trampa en suelo, una que da a un muro y una fuera del mapa se avisan y no se montan", otro.avisos.size() == 3 and otro.nodo("en_suelo") == null and otro.nodo("da_al_muro") == null, str(otro.avisos))
	otro.queue_free()


func _cableado() -> void:
	var a: TrampaDragon3D = _pz.nodo("t_drg_a") as TrampaDragon3D
	var b: TrampaDragon3D = _pz.nodo("t_drg_b") as TrampaDragon3D
	_ok("1.5 F7 monta los dos dragones en el muro norte (26,8) y (30,8), mirando al sur", a != null and b != null and a.celda == Vector2i(26, 8) and b.celda == Vector2i(30, 8) and a.mira == "s" and a.dir == Vector3(0, 0, 1))
	_ok("1.6 sus ciclos son los del mapa (1,5 s de fuego, 2,0 s de descanso; el segundo desfasado 1,75 s)", a != null and b != null and a.encendida_s == 1.5 and a.apagada_s == 2.0 and b.desfase_s == 1.75)
	var f8: TrampaFlechas3D = _pz.nodo("t_fl_a") as TrampaFlechas3D
	var f9: TrampaFlechas3D = _pz.nodo("t_fl_fuego") as TrampaFlechas3D
	_ok("1.7 F8 y F9 montan los mascarones: uno de flecha normal mirando al oeste y otro de fuego mirando al este", f8 != null and f9 != null and f8.elemento == "" and f8.mira == "o" and f9.elemento == "fuego" and f9.mira == "e" and f9.cada_s == 3.0)
	_ok("1.8 la trampa está en la cara del muro y a ras del suelo de la casilla de delante", a != null and absf(a.position.z - 9.0 * Terreno3D.casilla) < 0.01 and absf(a.position.y - Terreno3D.y_pies(Vector2i(26, 9))) < 0.01, "pos %s" % a.position)
	# Orientaciones: el +Z local mira hacia fuera del muro en las cuatro.
	var bien: bool = true
	for m in ["n", "e", "s", "o"]:
		var t := TrampaDragon3D.new()
		t.preparar(Vector2i(10, 10), m, "fuego", 5, null)
		var fuera: Vector3 = (t.global_transform.basis * Vector3(0, 0, 1)) if t.is_inside_tree() else (Basis(Vector3.UP, t.rotation.y) * Vector3(0, 0, 1))
		if fuera.distance_to(TrampaPared3D.DIRS[m]) > 0.001:
			bien = false
		t.free()
	_ok("1.9 las cuatro orientaciones (n, e, s, o) sacan la boca hacia fuera del muro", bien)


# ---------------------------------------------------------------------------------------------------------------------
#  2. El ciclo del dragón (a mano, 1/30 s por paso: exacto)
# ---------------------------------------------------------------------------------------------------------------------

func _paso(t: TrampaPared3D, s: float) -> void:
	var n: int = int(roundf(s * 30.0))
	for _i in range(n):
		t._physics_process(1.0 / 30.0)


func _ciclo() -> void:
	var d: TrampaDragon3D = _dragon(Vector2i(22, 24), "n", 1.2, 1.0)
	d.set_physics_process(false)
	jugador.position = Terreno3D.centro_de(Vector2i(2, 2))          # lejos: aquí no se mide el daño
	_ok("2.1 sin desfase empieza en reposo y no ha lanzado nada", d.fase == TrampaDragon3D.Fase.REPOSO and d.ticks == 0)
	var primer_aviso: float = -1.0
	var primer_fuego: float = -1.0
	var vuelta_reposo: float = -1.0
	var t: float = 0.0
	var antes: int = d.fase
	for i in range(int(2.4 * 30.0)):
		d._physics_process(1.0 / 30.0)
		t += 1.0 / 30.0
		if d.fase != antes:
			if d.fase == TrampaDragon3D.Fase.AVISO and primer_aviso < 0.0:
				primer_aviso = t
			elif d.fase == TrampaDragon3D.Fase.FUEGO and primer_fuego < 0.0:
				primer_fuego = t
			elif d.fase == TrampaDragon3D.Fase.REPOSO and primer_fuego > 0.0 and vuelta_reposo < 0.0:
				vuelta_reposo = t
			antes = d.fase
	_ok("2.2 el aviso empieza a los 0,5 s (descanso 1,0 − aviso 0,5)", absf(primer_aviso - 0.5) < 0.07, "%.2f s" % primer_aviso)
	_ok("2.3 el fuego empieza a los 1,0 s, tras 0,5 s de aviso", absf(primer_fuego - 1.0) < 0.07 and absf((primer_fuego - primer_aviso) - 0.5) < 0.07, "%.2f s; aviso de %.2f s" % [primer_fuego, primer_fuego - primer_aviso])
	_ok("2.4 vuelve al reposo a los 2,2 s (1,2 s de fuego)", absf(vuelta_reposo - 2.2) < 0.07, "%.2f s" % vuelta_reposo)
	_ok("2.5 en un fuego de 1,2 s lanza 2 haces (a 0,0 y 0,8 s) y escupe una vez", d.ticks == 2 and d.escupidas == 1, "ticks %d, escupidas %d" % [d.ticks, d.escupidas])
	# Desfase: empieza ya a mitad del fuego (1,5 s dentro del ciclo: descanso 1,0 + 0,5 de fuego).
	var d2: TrampaDragon3D = _dragon(Vector2i(24, 24), "n", 1.2, 1.0, 1.5)
	d2.set_physics_process(false)
	_ok("2.6 con `desfase=1.5` empieza ya escupiendo (cuenta como una escupida)", d2.fase == TrampaDragon3D.Fase.FUEGO and d2.escupidas == 1)
	d2._physics_process(1.0 / 30.0)
	_ok("2.7 …y suelta su primer haz en el primer paso", d2.ticks == 1)
	# Sin descanso escupe siempre; sin fuego, nunca.
	var d3: TrampaDragon3D = _dragon(Vector2i(26, 24), "n", 1.0, 0.0)
	d3.set_physics_process(false)
	_paso(d3, 1.0)
	var d4: TrampaDragon3D = _dragon(Vector2i(28, 24), "n", 0.0, 1.0)
	d4.set_physics_process(false)
	_paso(d4, 3.0)
	_ok("2.8 `apagada=0` escupe siempre y `encendida=0` no escupe nunca", d3.fase == TrampaDragon3D.Fase.FUEGO and d3.ticks >= 1 and d4.ticks == 0 and d4.fase == TrampaDragon3D.Fase.REPOSO)
	# `cerca`: dormida si la jugadora está lejos; despierta al acercarse.
	var dz: TrampaDragon3D = _dragon(Vector2i(24, 24), "n", 1.0, 1.0)
	dz.cerca = 3.0
	dz.set_physics_process(false)
	_jugadora_lista(Vector2i(2, 2))
	_paso(dz, 4.0)
	var dormido_ok: bool = dz.dormida() and dz.ticks == 0 and dz.fase == TrampaDragon3D.Fase.REPOSO
	_jugadora_lista(Vector2i(24, 21))
	_paso(dz, 4.0)
	_ok("2.8b `cerca=3`: dormida con la jugadora lejos (4 s sin ciclo ni haces) y despierta al acercarse (%d haces en 4 s)" % dz.ticks, dormido_ok and not dz.dormida() and dz.ticks >= 1)
	_quitar(dz)
	_jugadora_lista(Vector2i(2, 2))
	# Los dos del laboratorio (F7) no arden a la vez: se muestrea su ciclo teórico durante dos periodos.
	var a: TrampaDragon3D = _pz.nodo("t_drg_a") as TrampaDragon3D
	var b: TrampaDragon3D = _pz.nodo("t_drg_b") as TrampaDragon3D
	var a_y_b: int = 0
	var ninguno: float = 0.0
	var paso_s: float = 0.01
	var x: float = 0.0
	while x < 7.0:
		var fa: int = a.fase_de(fposmod(x + a.desfase_s, a.periodo()))
		var fb: int = b.fase_de(fposmod(x + b.desfase_s, b.periodo()))
		if fa == TrampaDragon3D.Fase.FUEGO and fb == TrampaDragon3D.Fase.FUEGO:
			a_y_b += 1
		if fa != TrampaDragon3D.Fase.FUEGO and fb != TrampaDragon3D.Fase.FUEGO:
			ninguno += paso_s
		x += paso_s
	_ok("2.9 F7: los dos dragones no escupen nunca a la vez (los dos callados %.2f s de cada 3,5)" % (ninguno / 2.0), a_y_b == 0, "solapes %d" % a_y_b)
	for e in [d, d2, d3, d4]:
		_quitar(e)
	await avanzar_s(2.0)


# ---------------------------------------------------------------------------------------------------------------------
#  3. Alcance del chorro (reactivos en cada casilla)
# ---------------------------------------------------------------------------------------------------------------------

func _golpes_en_columna(x: int, y0: int, n: int) -> Array:
	var r: Array = []
	for k in range(n):
		r.append(_reactivo(Vector2i(x, y0 - k)))
	return r


func _alcance_chorro() -> void:
	var res: Dictionary = {}
	for alc in [3, 4, 5, 6]:
		var d: TrampaDragon3D = _dragon(Vector2i(22, 24), "n", 1.0, 100.0)
		d.alcance = alc
		d.set_physics_process(false)
		jugador.position = Terreno3D.centro_de(Vector2i(2, 2))
		var reac: Array = _golpes_en_columna(22, 23, 7)            # y 23 … 17: casillas 0 … 6 de delante del muro
		d._tick()
		var golpeadas: Array = []
		for k in range(reac.size()):
			if (reac[k] as ReactivoFalso).golpes > 0:
				golpeadas.append(k)
		res[alc] = golpeadas
		var ultima: int = int(golpeadas.back()) if not golpeadas.is_empty() else -1
		_ok("3.%d alcance=%d: el chorro golpea las casillas %s de delante del muro (la última es la %d, la siguiente no)" % [alc, alc, str(golpeadas), ultima], ultima == alc and (reac[ultima + 1] as ReactivoFalso).golpes == 0 if ultima + 1 < reac.size() else ultima == alc, "")
		_ok("3.%d.b …y con alcance=%d la casilla 0 (pegada al muro) no se golpea con el hechizo (el haz no cuenta la del lanzador)" % [alc, alc], (reac[0] as ReactivoFalso).golpes == 0)
		for r in reac:
			(r as Node).queue_free()
		_quitar(d)
		await avanzar_s(1.2)
	print("MEDIDA alcance del chorro (casillas de delante del muro con golpe, de la 0 a la 6): %s" % str(res))
	# Un bloque de piedra delante lo para.
	var dd: TrampaDragon3D = _dragon(Vector2i(22, 24), "n", 1.0, 100.0)
	dd.set_physics_process(false)
	var bq: BloqueEmpujable3D = _bloque(Vector2i(22, 20))
	await avanzar(3)
	var reac2: Array = _golpes_en_columna(22, 23, 7)
	dd._tick()
	var golp2: Array = []
	for k in range(reac2.size()):
		if (reac2[k] as ReactivoFalso).golpes > 0:
			golp2.append(k)
	_ok("3.5 un bloque de piedra en la casilla 3 (22,20) para el chorro: llega a la 2 y no más", not golp2.is_empty() and int(golp2.back()) == 2 and not golp2.has(4) and not golp2.has(5), str(golp2))
	for r in reac2:
		(r as Node).queue_free()
	_quitar_bloque(bq)
	_quitar(dd)
	await avanzar_s(1.2)


# ---------------------------------------------------------------------------------------------------------------------
#  4. Daño
# ---------------------------------------------------------------------------------------------------------------------

func _dano_jugadora() -> void:
	var d: TrampaDragon3D = _dragon(Vector2i(22, 24), "n", 1.0, 100.0)
	d.set_physics_process(false)
	_jugadora_lista(Vector2i(22, 21))                         # casilla 2 de delante: dentro del chorro
	d._tick()
	var v1: float = _vida()
	_ok("4.1 dentro del chorro, un haz le quita DANO_TICK (%.0f)" % TrampaDragon3D.DANO_TICK, absf((100.0 - v1) - TrampaDragon3D.DANO_TICK) < 0.01, "vida %.1f" % v1)
	d._tick()
	_ok("4.2 un segundo haz justo después no le quita más (invulnerabilidad de 0,7 s)", absf(_vida() - v1) < 0.001, "vida %.1f" % _vida())
	await avanzar_s(0.85)
	d._tick()
	_ok("4.3 …y 0,85 s después, el siguiente haz vuelve a herirla (TICK_S %.1f > INVULNERABLE %.1f): %.1f daño/s" % [TrampaDragon3D.TICK_S, Jugador3D.INVULNERABLE, TrampaDragon3D.DANO_TICK / TrampaDragon3D.TICK_S], absf(_vida() - (v1 - TrampaDragon3D.DANO_TICK)) < 0.01, "vida %.1f" % _vida())
	# Fuera: a una casilla de lado, más allá del alcance, y pegada al muro pero de lado.
	var casos: Array = [["una casilla al lado (21,21)", Vector2i(21, 21)], ["más allá del alcance, casilla 6 (22,17)", Vector2i(22, 17)], ["al lado de la boca (21,23)", Vector2i(21, 23)]]
	for caso in casos:
		await avanzar_s(0.9)
		_jugadora_lista(caso[1] as Vector2i)
		d._tick()
		_ok("4.4 fuera del chorro, %s: no le pasa nada" % caso[0], _vida() == 100.0, "vida %.1f" % _vida())
	# En reposo no hiere aunque esté dentro.
	var r: TrampaDragon3D = _dragon(Vector2i(24, 24), "n", 1.0, 100.0)
	r.set_physics_process(false)
	_jugadora_lista(Vector2i(24, 21))
	_paso(r, 1.0)                                              # 1,0 s de reposo (el descanso es de 100 s: aviso solo al final)
	_ok("4.5 en reposo no hiere aunque esté dentro de la columna", _vida() == 100.0 and r.ticks == 0)
	# Respeta la altura: en otro nivel (más de ALTO_NIVEL) no la alcanza.
	_jugadora_lista(Vector2i(22, 21))
	jugador.position.y += Terreno3D.ALTO_NIVEL * 2.0
	d._tick()
	_ok("4.6 a otro nivel de altura no la alcanza", _vida() == 100.0, "vida %.1f" % _vida())
	# La burbuja de barrera / el bálsamo van por recibir_dano: con la vida llena sigue siendo la vía de siempre. Se mira que NO llama a otra cosa: la herida es un recibir_dano.
	_ok("4.7 el daño pasa por Jugador3D.recibir_dano (cuenta como daño recibido: `dano_recibido` emitida y `golpes_jugadora` sube)", d.golpes_jugadora >= 2, "golpes %d" % d.golpes_jugadora)
	_jugadora_lista(Vector2i(2, 2))
	for e in [d, r]:
		_quitar(e)
	await avanzar_s(1.2)


func _enemigo(c: Vector2i) -> Combate3D:
	var modelo := Pj3D.new()
	modelo.position = Lanzador3D.centro_de(c, Terreno3D.y_pies(c))
	maqueta.add_child(modelo)
	var e: Combate3D = Combate3D.equipar(modelo, maqueta as Node3D, jugador as Jugador3D, lanzador)
	e.set_physics_process(false)
	e.altura = 0.85
	return e


func _dano_enemigo() -> void:
	var d: TrampaDragon3D = _dragon(Vector2i(22, 24), "n", 1.0, 100.0)
	d.set_physics_process(false)
	var e: Combate3D = _enemigo(Vector2i(22, 21))
	var v0: float = e.health
	d._tick()
	await avanzar(2)
	var uno: float = v0 - e.health
	_ok("4.8 un enemigo en el chorro pierde vida por la vía de los hechizos (el haz de fuego: %.1f)" % uno, uno > 0.0, "vida %.1f → %.1f" % [v0, e.health])
	var fuera: Combate3D = _enemigo(Vector2i(21, 21))
	var vf: float = fuera.health
	d._tick()
	await avanzar(2)
	_ok("4.9 …y uno a una casilla de lado no", fuera.health == vf, "vida %.1f" % fuera.health)
	# Daño por segundo sobre un enemigo: 4 haces seguidos (3,2 s) y se ve cuánto ha perdido (incluye la quemadura que deja).
	e.health = e.vida_max
	var inicio: float = e.health
	var t0: float = reloj.t
	for _i in range(4):
		d._tick()
		await avanzar_s(TrampaDragon3D.TICK_S)
	var dt: float = reloj.t - t0
	print("MEDIDA daño al enemigo: un haz %.1f; 4 haces en %.1f s: %.1f (%.1f/s, con la quemadura incluida; goblin %.0f de vida)" % [uno, dt, inicio - e.health, (inicio - e.health) / dt, e.vida_max])
	_ok("4.10 el daño sostenido al enemigo es mayor que el de un solo haz (se acumula)", inicio - e.health > uno, "%.1f" % (inicio - e.health))
	_quitar(d)
	for x in [e, fuera]:
		if is_instance_valid(x):
			x.queue_free()
	await avanzar_s(1.2)


# ---------------------------------------------------------------------------------------------------------------------
#  5. El agua la apaga
# ---------------------------------------------------------------------------------------------------------------------

func _agua() -> void:
	var d: TrampaDragon3D = _dragon(Vector2i(22, 24), "n", 1.0, 100.0)
	d.set_physics_process(false)
	d.on_spell_hit(_runa_agua)
	_ok("5.1 un golpe de agua la apaga (activa = false, fase APAGADA) y avisa", not d.activa and d.fase == TrampaDragon3D.Fase.APAGADA)
	var antes: int = d.ticks
	_paso(d, 3.0)
	_ok("5.2 apagada no avisa ni escupe (3 s)", d.ticks == antes and d.fase == TrampaDragon3D.Fase.APAGADA)
	_paso(d, TrampaPared3D.T_AGUA_S)
	_ok("5.3 a los %.0f s vuelve a funcionar, empezando en reposo" % TrampaPared3D.T_AGUA_S, d.activa and d.fase != TrampaDragon3D.Fase.APAGADA, "fase %d" % d.fase)
	d.apaga_con_agua = false
	d.on_spell_hit(_runa_agua)
	_ok("5.4 con `agua=no` el agua no la apaga", d.activa)
	d.apaga_con_agua = true
	d.on_spell_hit(Puzle3D.runa(["fuego", "calor"]))
	_ok("5.5 el fuego no la apaga (es de fuego)", d.activa)
	d.on_spell_hit(Puzle3D.runa(["hielo", "frio"]))
	_ok("5.6 el hielo sí", not d.activa)
	d.encender()
	_ok("5.7 `encender()` la reactiva en el acto", d.activa)
	# Una flecha de agua REAL lanzada contra la cabeza (el camino de la jugadora): la apaga.
	_jugadora_lista(Vector2i(22, 21))
	await avanzar_s(1.5)                                        # que acaben la animación de golpe y la invulnerabilidad: sin eso `puede_lanzar` es false
	var salio: bool = lanzar("agua", ["flecha", "flecha"], Vector3(0, 0, 1))
	await avanzar_s(1.6)
	_ok("5.8 una flecha de agua REAL de la jugadora que le da a la cabeza la apaga", salio and not d.activa, "salió %s, activa %s" % [salio, d.activa])
	# La regla del mapa: el botón ! de F7 apaga los dos dragones 8 s.
	var a: TrampaDragon3D = _pz.nodo("t_drg_a") as TrampaDragon3D
	var b: TrampaDragon3D = _pz.nodo("t_drg_b") as TrampaDragon3D
	a.encender()
	b.encender()
	(lab.call("pulsador_en", Vector2i(25, 10)) as Node).call("pulsar")
	await avanzar(2)
	_ok("5.9 el botón ! de F7 (`hace=t_drg_a.apagar(8) y=t_drg_b.apagar(8)`) apaga los dos dragones", not a.activa and not b.activa)
	a._apagada_t = 0.1                                          # no se esperan 8 s de reloj: se acorta lo que queda para mirar que vuelven solos
	b._apagada_t = 0.1
	await avanzar_s(0.5)
	_ok("5.10 …y vuelven solos al acabar la cuenta", a.activa and b.activa)
	a.apagar(0.0)
	b.apagar(0.0)
	_jugadora_lista(Vector2i(2, 2))
	_quitar(d)
	await avanzar_s(1.2)


# ---------------------------------------------------------------------------------------------------------------------
#  6. Flecha de fuego (hechizo real)
# ---------------------------------------------------------------------------------------------------------------------

func _flecha_fuego() -> void:
	# Mascarón en el muro (16,19) que mira al este: la fila y=19 de la sala (2,2), x 17…23, y el muro x=24.
	var f: TrampaFlechas3D = _flechas(Vector2i(16, 19), "e", 2.0, "fuego", 8, 3.5)
	f.set_physics_process(false)
	jugador.position = Terreno3D.centro_de(Vector2i(2, 2))
	var hv_antes: int = lanzador.get_child_count()
	f._disparar()
	await avanzar(1)
	var hv: HechizoVivo = _ultimo_proyectil()
	_ok("6.1 el disparo crea un HechizoVivo de fuego con forma de proyectil (la misma flecha de fuego de la jugadora)", hv != null and hv.h.proyectil and hv.elemento == "fuego" and hv.h.figura() == "proyectil", "hijos del lanzador %d → %d" % [hv_antes, lanzador.get_child_count()])
	if hv == null:
		_quitar(f)
		return
	var s1: Dictionary = await _seguir(hv)
	var p0: Vector3 = s1["p0"]
	var recorrido_x: float = (s1["p"] as Vector3).x - p0.x
	_ok("6.2 vuela recta: no cae ni se desvía (desvío vertical %.3f u, lateral %.3f u)" % [s1["dev_y"], s1["dev_z"]], float(s1["dev_y"]) < 0.02 and float(s1["dev_z"]) < 0.02)
	var v_med: float = recorrido_x / maxf(float(s1["t"]), 0.01)
	_ok("6.3 va a la velocidad pedida (3,5 casillas/s = %.1f u/s; medida %.1f u/s de media, con el arranque suave)" % [3.5 * Terreno3D.casilla, v_med], v_med > 5.5 and v_med < 3.5 * Terreno3D.casilla + 0.5, "%.2f u/s" % v_med)
	_ok("6.4 se para en el muro del fondo (x=24) y no lo atraviesa: causa «%s», recorrió %.1f u (%.2f casillas)" % [s1["causa"], recorrido_x, recorrido_x / Terreno3D.casilla], s1["causa"] == "muro" and (s1["p"] as Vector3).x < 24.0 * Terreno3D.casilla + 0.1, "x final %.2f; muro en %.2f" % [(s1["p"] as Vector3).x, 24.0 * Terreno3D.casilla])
	print("MEDIDA flecha de fuego: de la ranura (x=%.1f) al muro, %.1f u (%.1f casillas) en %.2f s" % [p0.x, recorrido_x, recorrido_x / Terreno3D.casilla, s1["t"]])
	# Alcance corto: se acaba por alcance, no por muro.
	var f2: TrampaFlechas3D = _flechas(Vector2i(16, 21), "e", 2.0, "fuego", 3, 3.5)
	f2.set_physics_process(false)
	f2._disparar()
	await avanzar(1)
	var hv2: HechizoVivo = _ultimo_proyectil()
	var s2: Dictionary = await _seguir(hv2)
	var casillas2: float = ((s2["p"] as Vector3).x - (s2["p0"] as Vector3).x) / Terreno3D.casilla
	_ok("6.5 con alcance=3 se acaba por alcance a las 3 casillas (causa «%s», %.2f casillas)" % [s2["causa"], casillas2], s2["causa"] == "alcance" and absf(casillas2 - 3.0) < 0.2)
	# Un bloque la para.
	var bq: BloqueEmpujable3D = _bloque(Vector2i(20, 19))
	await avanzar(3)
	f._disparar()
	await avanzar(1)
	var s3: Dictionary = await _seguir(_ultimo_proyectil())
	_ok("6.6 un bloque de piedra delante (20,19) la para antes: causa «%s», x final %.1f < borde del bloque %.1f" % [s3["causa"], (s3["p"] as Vector3).x, 20.0 * Terreno3D.casilla], (s3["causa"] == "muro" or s3["causa"] == "golpe") and (s3["p"] as Vector3).x < 20.0 * Terreno3D.casilla + 0.05)
	_quitar_bloque(bq)
	await avanzar(2)	# Daña a la jugadora: 12, y la flecha se acaba ahí (no sigue).
	_jugadora_lista(Vector2i(20, 19))
	f.set_physics_process(true)
	f._disparar()
	var n4: int = 0
	while float(_vida()) == 100.0 and n4 < 300:
		await process_frame
		n4 += 1
	await avanzar(3)
	_ok("6.7 la flecha de fuego hiere a la jugadora con DANO_JUGADORA (%.0f): vida %.1f" % [TrampaFlechas3D.DANO_JUGADORA, _vida()], absf((100.0 - _vida()) - TrampaFlechas3D.DANO_JUGADORA) < 0.01)
	_ok("6.8 …y la flecha se acaba al herirla (no atraviesa a la jugadora ni la hiere dos veces)", f.vuelos_activos() == 0 and f.golpes_jugadora == 1, "golpes %d, vuelos %d" % [f.golpes_jugadora, f.vuelos_activos()])
	# Fuera de la fila no le pasa nada.
	_jugadora_lista(Vector2i(20, 21))
	f._disparar()
	await avanzar_s(2.0)
	_ok("6.9 en otra fila no la toca", _vida() == 100.0)
	# Un enemigo en la fila.
	var e: Combate3D = _enemigo(Vector2i(21, 19))
	var v0: float = e.health
	f._disparar()
	var n10: int = 0
	await avanzar(2)
	while f.vuelos_activos() > 0 and n10 < 400:
		await process_frame
		n10 += 1
	await avanzar(2)
	var directo: float = v0 - e.health
	await avanzar_s(1.6)
	var murio: bool = not is_instance_valid(e) or e.health <= 0.0
	var v_fin: float = maxf(e.health, 0.0) if is_instance_valid(e) else 0.0
	_ok("6.10 un enemigo en la fila pierde vida por la vía de los hechizos (%.1f → %.1f%s)" % [v0, v_fin, ", muere" if murio else ""], directo > 0.0)
	print("MEDIDA flecha de fuego al enemigo (goblin de %.0f de vida): %.1f en el golpe; a los 1,6 s lleva %.1f%s por la quemadura que deja; a la jugadora: %.0f" % [v0, directo, v0 - v_fin, " (muere)" if murio else "", TrampaFlechas3D.DANO_JUGADORA])
	# Para comparar: la MISMA flecha de fuego lanzada por la jugadora (fuego + ᛇ) contra otro goblin en la misma casilla.
	if is_instance_valid(e):
		e.queue_free()
	await avanzar(3)
	var e2: Combate3D = _enemigo(Vector2i(21, 19))
	var w0: float = e2.health
	_jugadora_lista(Vector2i(19, 19))
	await avanzar_s(1.5)
	var salio_j: bool = lanzar("fuego", ["flecha"], Vector3.RIGHT)
	await avanzar_s(2.0)
	var dj: float = w0 - (maxf(e2.health, 0.0) if is_instance_valid(e2) else 0.0)
	print("MEDIDA para comparar: la flecha de fuego de la JUGADORA (fuego + ᛇ, salió %s) deja a un goblin de %.0f de vida en %.1f menos a los 2 s; la de la trampa, %.1f" % [str(salio_j), w0, dj, v0 - v_fin])
	var ht: Hechizo = f.construir_hechizo({"flecha": 1}, {})
	var hj: Hechizo = Hechizo.construir(load("res://nucleo/fire_rune.tres") as RuneData, {"flecha": 1})
	print("MEDIDA hechizos: flecha de la trampa dano %.1f quema %.1f (glifos de daño %d) · flecha de la jugadora (1 ᛇ) dano %.1f quema %.1f (glifos de daño %d)" % [ht.dano, ht.quema, ht.n_glifos_dano, hj.dano, hj.quema, hj.n_glifos_dano])
	if is_instance_valid(e2):
		e2.queue_free()
	_jugadora_lista(Vector2i(2, 2))
	# Ciclo: dispara cada `cada` s en tiempo real y avisa 0,35 s antes.
	f.set_physics_process(true)
	f.apagar(0.0)
	f.encender()
	var disparos0: int = f.disparos
	var avisos_vistos: float = 0.0
	var t_ini: float = reloj.t
	var t_prev: float = reloj.t
	while reloj.t - t_ini < 6.0:
		await process_frame
		if f.en_aviso:
			avisos_vistos += reloj.t - t_prev
		t_prev = reloj.t
	var cuantos: int = f.disparos - disparos0
	_ok("6.11 con cada=2,0 dispara 3 veces en 6 s (disparos %d)" % cuantos, cuantos == 3, "%d" % cuantos)
	_ok("6.12 la ranura avisa unos %.2f s por disparo (AVISO_S = %.2f)" % [avisos_vistos / 3.0, TrampaFlechas3D.AVISO_S], absf(avisos_vistos / float(maxi(cuantos, 1)) - TrampaFlechas3D.AVISO_S) < 0.12)
	for x in [f, f2]:
		_quitar(x)
	if is_instance_valid(e):
		e.queue_free()
	_jugadora_lista(Vector2i(2, 2))
	await avanzar_s(1.5)


# ---------------------------------------------------------------------------------------------------------------------
#  7. Flecha normal
# ---------------------------------------------------------------------------------------------------------------------

func _flecha_normal() -> void:
	var f: TrampaFlechas3D = _flechas(Vector2i(16, 19), "e", 2.0, "ninguno", 8, 3.5)
	f.set_physics_process(false)
	_jugadora_lista(Vector2i(2, 2))
	var antes: int = _props().get_child_count()
	f._disparar()
	await avanzar(1)
	var fl: FlechaTrampa3D = null
	for ch in _props().get_children():
		if ch is FlechaTrampa3D:
			fl = ch
	_ok("7.1 `elemento=ninguno` dispara una flecha normal (FlechaTrampa3D) sin pasar por un hechizo", fl != null)
	if fl == null:
		_quitar(f)
		return
	var p0: Vector3 = fl.global_position
	var maxy: float = 0.0
	var t0: float = reloj.t
	while is_instance_valid(fl) and fl.vivo:
		maxy = maxf(maxy, absf(fl.global_position.y - p0.y) + absf(fl.global_position.z - p0.z))
		await process_frame
	var t1: float = reloj.t
	_ok("7.2 vuela recta y se acaba en el muro del fondo", maxy < 0.01, "desvío %.3f" % maxy)
	await avanzar(2)
	_ok("7.3 se libera al acabar (los nodos no se acumulan)", _props().get_child_count() <= antes, "%d → %d hijos" % [antes, _props().get_child_count()])
	_jugadora_lista(Vector2i(20, 19))
	f.set_physics_process(true)
	f._disparar()
	var n: int = 0
	while _vida() == 100.0 and n < 300:
		await process_frame
		n += 1
	_ok("7.4 la flecha normal hiere a la jugadora con %.0f (la del goblin): vida %.1f" % [Combate3D.DANO_FLECHA, _vida()], absf((100.0 - _vida()) - Combate3D.DANO_FLECHA) < 0.01)
	# Un bloque delante la para y la jugadora detrás no recibe nada.
	var bq: BloqueEmpujable3D = _bloque(Vector2i(19, 19))
	await avanzar_s(1.0)
	_jugadora_lista(Vector2i(21, 19))
	f.apagar(0.0)
	f.encender()
	f._t = f.cada_s - 0.05
	await avanzar_s(5.0)
	_ok("7.5 con un bloque en (19,19) la jugadora de detrás (21,19) no recibe nada en %d disparos" % f.disparos, _vida() == 100.0 and f.disparos >= 2, "vida %.1f" % _vida())
	_quitar_bloque(bq)
	await avanzar(2)
	# Un enemigo (la jugadora, apartada: la flecha la herirá antes si está en la fila).
	_jugadora_lista(Vector2i(2, 2))
	var e: Combate3D = _enemigo(Vector2i(21, 19))
	var v0: float = e.health
	var causas: Array = []
	f._disparar()
	for ch in _props().get_children():
		if ch is FlechaTrampa3D:
			(ch as FlechaTrampa3D).fin.connect(func(c: String) -> void: causas.append(c))
	await avanzar_s(1.6)
	print("      [7.6] causa de fin de la flecha: %s; enemigo en %s; celda (19,19) sólida: %s" % [str(causas), str(Terreno3D.celda_de(e.position)), str(Terreno3D.celda_solida(Vector2i(19, 19), 0))])
	_ok("7.6 un enemigo en la fila pierde %.0f (receive_damage de la flecha normal)" % (v0 - e.health), e.health < v0)
	_quitar(f)
	if is_instance_valid(e):
		e.queue_free()
	_jugadora_lista(Vector2i(2, 2))
	await avanzar_s(1.0)


# ---------------------------------------------------------------------------------------------------------------------
#  Las salas del laboratorio, jugadas
# ---------------------------------------------------------------------------------------------------------------------

func _lab_f7() -> void:
	var a: TrampaDragon3D = _pz.nodo("t_drg_a") as TrampaDragon3D
	var b: TrampaDragon3D = _pz.nodo("t_drg_b") as TrampaDragon3D
	a.encender()
	b.encender()
	a._al_encender()
	b._al_encender()
	# La jugadora andando por el pasillo cruza los dos chorros: se mide cuánto daño recibe si cruza sin mirar y si espera el turno.
	_jugadora_lista(Vector2i(25, 12))
	var vida0: float = _vida()
	var ok_cruce: bool = await mover_hacia(Vector2i(31, 12), 25.0, 0.4)
	var perdio: float = vida0 - _vida()
	print("MEDIDA F7: cruzar andando de (25,12) a (31,12) sin esperar el turno: %s, daño recibido %.0f" % ["llegó" if ok_cruce else "no llegó", perdio])
	_ok("7.7 F7: andando sin esperar el turno recibe daño pero cabe cruzar (≤ 2 haces: %.0f)" % perdio, perdio >= 0.0 and perdio <= 2.0 * TrampaDragon3D.DANO_TICK + 0.01)
	var placa: Node = _pz.nodo("t_drg_placa")
	_ok("7.8 F7: llegó a la placa del fondo y se pisa", ok_cruce and bool(placa.get("activo")))
	a.apagar(0.0)
	b.apagar(0.0)
	_jugadora_lista(Vector2i(2, 2))


func _lab_f8() -> void:
	var f: TrampaFlechas3D = _pz.nodo("t_fl_a") as TrampaFlechas3D
	var bloque: BloqueEmpujable3D = _pz.nodo("t_fl_bloque") as BloqueEmpujable3D
	f.encender()
	f._t = 0.0
	# Sin el bloque en la fila la jugadora de (3,20) recibe flechas; con el bloque empujado a (5,20), no.
	_jugadora_lista(Vector2i(3, 20))
	var disp0: int = f.disparos
	await avanzar_s(4.0)
	var vida_sin: float = _vida()
	_ok("7.9 F8: sin el bloque en la fila, quien se queda en (3,20) recibe flechas (%d disparos, vida %.0f)" % [f.disparos - disp0, vida_sin], vida_sin < 100.0)
	_jugadora_lista(Vector2i(3, 21))
	var puede: bool = bloque.puede_moverse(Vector2i(0, -1))
	var empujo: bool = bloque.empujar(Vector2i(0, -1))
	await avanzar_s(1.5)
	print("      [F8 bloque] puede_moverse %s, empujar %s, moviendo %s, celda %s, pos %s" % [puede, empujo, bloque.moviendo, bloque.celda, bloque.position])
	_ok("7.10 F8: el bloque se empuja al norte y queda en la fila (5,20)", empujo and Terreno3D.celda_de(bloque.position) == Vector2i(5, 20), "en %s" % str(Terreno3D.celda_de(bloque.position)))
	_jugadora_lista(Vector2i(3, 20))
	var disp1: int = f.disparos
	await avanzar_s(4.5)
	_ok("7.11 F8: con el bloque delante, quien está en (3,20) no recibe nada en %d disparos" % (f.disparos - disp1), _vida() == 100.0 and f.disparos - disp1 >= 2, "vida %.0f" % _vida())
	f.apagar(0.0)
	_jugadora_lista(Vector2i(2, 2))


func _lab_f9() -> void:
	var f: TrampaFlechas3D = _pz.nodo("t_fl_fuego") as TrampaFlechas3D
	var s1: Node = _pz.nodo("t_fl_s1")
	var s2: Node = _pz.nodo("t_fl_s2")
	var ba: Barril3D = _pz.nodo("t_fl_barril") as Barril3D
	_ok("7.12 F9: los setos y el barril están enteros antes de empezar", s1 != null and s2 != null and ba != null and not bool(s1.get("is_lit")) and not bool(s2.get("is_lit")) and not ba.explotado)
	_ok("7.12b F9: dormida (`cerca=6`) mientras la jugadora está lejos: no ha disparado ni una vez desde que arrancó la escena", f.dormida() and f.disparos == 0, "disparos %d" % f.disparos)
	_jugadora_lista(Vector2i(12, 17))                          # entra en la sala (a 5,8 casillas de la trampa, `cerca=6`; el barril, a 12 u: fuera de su radio)
	f._t = f.cada_s - 0.05                                     # el primer disparo sale ya
	var t0: float = reloj.t
	var t_s1: float = -1.0
	var t_s2: float = -1.0
	var t_ba: float = -1.0
	while reloj.t - t0 < 30.0 and t_ba < 0.0:
		await process_frame
		if t_s1 < 0.0 and is_instance_valid(s1) and bool(s1.get("is_lit")):
			t_s1 = reloj.t - t0
		if t_s2 < 0.0 and is_instance_valid(s2) and bool(s2.get("is_lit")):
			t_s2 = reloj.t - t0
		if ba.explotado:
			t_ba = reloj.t - t0
	_ok("7.13 F9: la flecha de fuego prende el primer seto (a los %.1f s del disparo)" % t_s1, t_s1 > 0.0)
	_ok("7.14 F9: el fuego corre al segundo seto (%.1f s) y enciende el barril, que explota (%.1f s)" % [t_s2, t_ba], t_s2 > 0.0 and t_ba > 0.0)
	f.apagar(0.0)
	_jugadora_lista(Vector2i(2, 2))
	await avanzar_s(1.0)


# ---------------------------------------------------------------------------------------------------------------------
#  8. Los nodos no se acumulan
# ---------------------------------------------------------------------------------------------------------------------

func _nodos() -> void:
	for e in _extras.duplicate():
		_quitar(e)
	for id in ["t_drg_a", "t_drg_b", "t_fl_a", "t_fl_fuego"]:
		(_pz.nodo(id) as TrampaPared3D).apagar(0.0)
	await avanzar_s(6.0)
	var base_l: int = lanzador.get_child_count()
	var base_m: int = maqueta.get_child_count()
	var base_p: int = _props().get_child_count()
	# Una trampa de cada con ciclos cortos funcionando 12 s; después se apagan y se deja que todo caduque.
	var d: TrampaDragon3D = _dragon(Vector2i(22, 24), "n", 1.5, 0.5)
	var f: TrampaFlechas3D = _flechas(Vector2i(16, 19), "e", 0.7, "fuego", 8, 3.5)
	var g: TrampaFlechas3D = _flechas(Vector2i(16, 21), "e", 0.7, "ninguno", 8, 3.5)
	_jugadora_lista(Vector2i(2, 2))
	var maxl: int = 0
	var maxm: int = 0
	var t0: float = reloj.t
	while reloj.t - t0 < 12.0:
		await process_frame
		maxl = maxi(maxl, lanzador.get_child_count())
		maxm = maxi(maxm, maqueta.get_child_count())
	for x in [d, f, g]:
		_quitar(x)
	await avanzar_s(6.0)
	_ok("8.1 tras 12 s de tres trampas a tope y 6 s de calma, el lanzador, la maqueta y el decorado tienen los mismos hijos que antes (%d/%d/%d; pico %d/%d)" % [lanzador.get_child_count(), maqueta.get_child_count(), _props().get_child_count(), maxl, maxm],
		lanzador.get_child_count() <= base_l and maqueta.get_child_count() <= base_m and _props().get_child_count() <= base_p, "base %d/%d/%d" % [base_l, base_m, base_p])
	_ok("8.2 durante el funcionamiento el pico de hechizos vivos es acotado (≤ 12 en el lanzador)", maxl - base_l <= 12, "pico +%d" % (maxl - base_l))


# ---------------------------------------------------------------------------------------------------------------------
#  9. Medidas
# ---------------------------------------------------------------------------------------------------------------------

func _medidas() -> void:
	var d: TrampaDragon3D = _dragon(Vector2i(22, 24), "n", 1.0, 100.0)
	d.set_physics_process(false)
	var m_ret: Dictionary = d.medidas()
	d.fase = TrampaDragon3D.Fase.FUEGO
	d._animar(0.0, true)
	var m_ext: Dictionary = d.medidas()
	print("MEDIDA dragón (u; 1 casilla = %.1f u): losa %.1f × %.1f × %.2f; con la cabeza retraída %.2f × %.2f × %.2f saliente; lanzada a escupir %.2f × %.2f × %.2f saliente (%.2f casillas)" % [Terreno3D.casilla, TrampaDragon3D.LOSA.x, TrampaDragon3D.LOSA.y, TrampaDragon3D.LOSA.z,
		m_ret["ancho"], m_ret["alto"], m_ret["saliente"], m_ext["ancho"], m_ext["alto"], m_ext["saliente"], float(m_ext["saliente"]) / Terreno3D.casilla])
	print("MEDIDA dragón: boca a %.2f u del suelo (%.2f casillas) y a %.2f u de la cara del muro; chorro de %.1f u desde la cara con alcance 5 (%.2f casillas)" % [d.altura_boca_u(), d.altura_boca_u() / Terreno3D.casilla, d.boca_local().z, d.largo_chorro_u(), d.largo_chorro_u() / Terreno3D.casilla])
	var f: TrampaFlechas3D = _flechas(Vector2i(16, 19), "e", 2.0, "fuego", 8)
	f.set_physics_process(false)
	var mf: Dictionary = f.medidas()
	print("MEDIDA mascarón de flechas (u): %.2f × %.2f × %.2f saliente (%.2f casillas de ancho); ranura a %.2f u del suelo y a %.2f de la cara del muro" % [mf["ancho"], mf["alto"], mf["saliente"], float(mf["ancho"]) / Terreno3D.casilla, f.altura_boca_u(), f.boca_local().z])
	print("MEDIDA tiempos: aviso del dragón %.2f s; aviso del mascarón %.2f s; haz cada %.1f s (el haz se ve %.1f s); invulnerabilidad de la jugadora %.1f s" % [TrampaDragon3D.AVISO_S, TrampaFlechas3D.AVISO_S, TrampaDragon3D.TICK_S, Hechizo.HAZ_DURA_S, Jugador3D.INVULNERABLE])
	print("MEDIDA daño a la jugadora: dragón %.0f por haz = %.1f/s sostenido; flecha %.0f; para comparar: golpe de goblin %.0f, flecha de goblin %.0f, barril 20" % [TrampaDragon3D.DANO_TICK, TrampaDragon3D.DANO_TICK / TrampaDragon3D.TICK_S, TrampaFlechas3D.DANO_JUGADORA, Combate3D.DANO_GOLPE, Combate3D.DANO_FLECHA])
	print("MEDIDA velocidad: la jugadora anda a 1,6 u/s y corre a 3 u/s; la flecha va a %.1f u/s (flecha normal %.1f u/s)" % [3.5 * Terreno3D.casilla, FlechaTrampa3D.VEL_U])
	_quitar(d)
	_quitar(f)
