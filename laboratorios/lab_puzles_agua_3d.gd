class_name LabPuzlesAgua3D
extends Node

## LABORATORIO DE PUZLES DE AGUA (Fase 13.8, 15/10, Juego). F6 sobre `laboratorios/LabPuzlesAgua3D.tscn`.
## Mapa: mundo/datos_nivel/mapas/PuzlesAgua.txt (25 × 25: nueve salas de 7 × 7; el jugador nace en la del centro y cada sala es un
## puzle). Para DEPURAR la mecánica de fluidos con las piezas de verdad (tinaja, canal, cauce `c`, simulación AguaSim3D, jugador) y con
## los tres disparadores que pidió Pablo: BOTÓN `!` (cualquier magia), PLACA `@` (sensor de presencia: pisarla) y PULSADOR DE AGUA `%`
## (solo agua). Cada puzle se puede resolver por su vía «natural» (lanzar el hechizo que toca) y por los botones, para separar «falla
## el agua» de «falla el disparador».
##
## POR QUÉ ES UN NODO HIJO Y NO `reglas = "..."`: igual que TerraFina3D: PruebaTest2 elige las reglas por cadena fija (Pipeline). La
## escena cuelga este nodo como hijo; `_ready` del hijo corre antes que el del padre, así que espera un fotograma y entonces la
## maqueta ya está montada (jugador, Lanzador3D, simulación de agua y la tinaja conectada a `Mundo3D.abrir_cauce`).
##
## LAS SALAS (columna, fila de salas; casillas x 1–7 / 9–15 / 17–23, y igual):
##   Q1 (1,0) LLENA LA CUENCA: tinaja `u` → codo `L` → recto `-` → cuenca `c` 3 × 2. Nivel ≥ 0,45 en (12,5) abre la puerta Z.
##            Vías: agua a la tinaja · botón `!` (activa la tinaja) · placa `@`.
##   Q2 (0,0) TRASVASE: cuenca A llena (2–3, 2–3) · compuerta de HIELO en (4,3) · cuenca B vacía (5–6, 2–3).
##            Fuego a la compuerta (se derrite) o `!`/`@` la abren; B ≥ 0,35 en (6,3) abre Z. (Vasos comunicantes: 0,9 → ~0,45/0,45.)
##   Q3 (2,0) PRESA DE HIELO: arroyo de canal `-` (18, 1–7) con manantial arriba y desagüe abajo. Hielo en (18,2) corta el agua: el
##            vado (18,4) baja de 0,25 y Z se abre MIENTRAS dure el hielo (DURA_HIELO s). `!`/`@` hielan (18,2) por código.
##   Q4 (0,1) DESVÍA EL RÍO: manantial (4,10) → bifurcación (4,12): brazo oeste (3–1, 12) con compuerta ABIERTA en (3,12) y desagüe en (1,12);
##            brazo este (5–7, 12), fondo de saco con la «rueda» (detector ≥ 0,4 en (6,12)). Cerrar la compuerta (hielo, o `!`/`@`) embalsa el
##            caudal en el este y la rueda arranca; reabrirla (fuego) lo vacía por el oeste.
##   Q5 (2,1) VACÍA PARA PASAR: pasillo `c` (20, 10–12) inundado a 0,7 (se nada). Desagüe: compuerta de hielo en (20,13) hacia el
##            sumidero (20,14). Fuego la abre (o `!`/`@`); con (20,11) ≤ 0,25 Z se abre. El fuego también evapora (VOL_EVAPORA por golpe).
##   Q6 (1,2) RIEGA: pulsador de AGUA `%` (12,19): solo el agua lo activa (el botón `!` de al lado NO abre Z: es el control). También `@`.
##            La sala es hierba: para ver el charco de un impacto (y si se seca: bug «charco eterno»).
##   Q7 (2,2) RAYO POR EL AGUA: fuente eléctrica `e` (18,20) → canal seco `-` (19–21, 20) → tótem de rayo `i` (22,20). El canal está
##            abierto pero vacío: ~6 hechizos de agua lo llenan (≥ 0,25: 1,33 u³ en 9 trocitos) y la fuente (EmisorRayo3D) conduce hasta el tótem, que abre Z.
##            Fuego lo evapora y corta. `!`/`@` echan el agua por código.
##   Q9 (3,0) MOLINO: arroyo de canal (28, 1–7) cerrado por una compuerta en (28,2); el molino (28,5) gira con la corriente (abre Z
##            mientras gira) o 6 s si lo golpea un hechizo de agua (Z se abre y se vuelve a cerrar). `!`/`@` abren la compuerta.
##   Q10 (3,1) ROCA Y BARRIL: cauce (25–30, 12) con manantial en (26,12) y aliviadero en (25,12); una ROCA en (28,12) corta el curso.
##            Fuego al barril (28,11) → explota → la roca se desmorona → el agua llega al este; (30,12) ≥ 0,4 abre Z. Hielo en (27,12)
##            vuelve a cortarlo. `!`/`@` encienden el barril por código.
##   Q8 (0,2) NIVEL JUSTO: tinaja `u` (5,19) → recto `-` (4,19) → cuenca (2–3, 18–19). Z abre solo con (2,18) en 0,5 ± 0,08. El `!` CIERRA
##            EL GRIFO (AguaSim3D.apagar_fuente) y el fuego evapora para bajar. Las tinajas del lab vierten CAUDAL_TINAJA_LAB durante VOL_TINAJA_LAB u³.
## Teclas: 1–9 y 0 (= Q10) llevan al jugador a la entrada de esa sala · R recarga la escena · (las de la maqueta siguen valiendo).
## El HUD muestra, por puzle, la profundidad leída por su detector, el estado de su compuerta y si la puerta está abierta; y el
## volumen total de agua de la escena (si crece sin manantiales, hay una fuga al revés).

const NIVEL_MAPA: String = "PuzlesAgua"
const CAUDAL_TINAJA_LAB: float = 0.5         ## u³/s de las tinajas del lab (Pablo, 15/10: con 1,5 la banda de Q8 se cruza en 3 s y Q1 inunda la sala)
const VOL_TINAJA_LAB: float = 20.0           ## u³ por tinaja: Q1 necesita 14,3 para 0,45 en 6 casillas; la tinaja vierte unos 40 s
const CAUDAL_ARROYO: float = 0.6             ## u³/s del manantial de Q4 (y de Q3 hasta el 15/10)
const CAUDAL_ARROYO_Q3: float = 1.5          ## u³/s del arroyo de Q3. Medido 15/10: con 0,6 el vado se queda en 0,23 (< 0,25, la puerta ya está abierta sin presa)
const DURA_HIELO_BOTON: float = AguaSim3D.DURA_HIELO
const T_HUD: float = 0.2

## Puerta de premio: una losa que bloquea su casilla hasta que el puzle se cumple (y vuelve a cerrarse si deja de cumplirse).
class PuertaLab extends Node3D:
	var celda: Vector2i = Vector2i.ZERO
	var abierta: bool = false
	var _losa: MeshInstance3D = null
	var _y0: float = 0.0
	func preparar(c: Vector2i) -> void:
		celda = c
		position = Terreno3D.centro_de(c, Terreno3D.alto_suelo)
		Terreno3D.bloquear_celda(c)
		_losa = MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(Terreno3D.casilla * 0.9, 2.2, 0.3)
		_losa.mesh = b
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.36, 0.22)
		_losa.material_override = mat
		_y0 = 1.1
		_losa.position = Vector3(0.0, _y0, 0.0)
		add_child(_losa)
	func poner(si: bool) -> void:
		if si == abierta:
			return
		abierta = si
		if si:
			Terreno3D.liberar_celda(celda)
		else:
			Terreno3D.bloquear_celda(celda)
		var tw: Tween = create_tween()
		tw.tween_property(_losa, "position:y", _y0 - 2.1 if si else _y0, 0.8).set_trans(Tween.TRANS_SINE)

var m: Variant = null                        ## la maqueta (PruebaTest2). Sin tipo: se le llama a métodos suyos
var _jug: Jugador3D = null
var _puzles: Array = []                      ## [{nombre, entrada, detector, compuerta, puerta, pulsadores}]
var _hud: Label = null
var _t_hud: float = 0.0
var _hielos: Dictionary = {}                 ## Vector2i -> s que le quedan a un hielo puesto por botón
var _pulsadores: Dictionary = {}             ## Vector2i -> Pulsador3D (para las pruebas: pulsar por código)
var _avisos: Array = []


func _ready() -> void:
	call_deferred("_arrancar")


func _arrancar() -> void:
	if get_parent() != null:
		iniciar(get_parent())


## Entrada pública: `mundo` es la maqueta ya montada (con la simulación de agua).
func iniciar(mundo: Variant) -> void:
	m = mundo
	for n in (m as Node).get_children():
		if n is Jugador3D:
			_jug = n
	if Terreno3D.agua_sim == null:
		push_error("LabPuzlesAgua3D: la escena necesita agua_fisica = true (no hay AguaSim3D)")
		return
	_comprobar_mapa()
	_cablear_tinajas()
	_montar_q1()
	_montar_q2()
	_montar_q3()
	_montar_q4()
	_montar_q5()
	_montar_q6()
	_montar_q7()
	_montar_q8()
	_montar_q9()
	_montar_q10()
	_montar_hud()
	set_process(true)


## Que las letras del mapa sean las que este archivo espera (si Pablo mueve algo en el .txt, que se sepa al arrancar y no a media prueba).
func _comprobar_mapa() -> void:
	var esperadas: Dictionary = {
		Vector2i(13, 2): "u", Vector2i(12, 2): "L", Vector2i(12, 3): "-", Vector2i(12, 5): "c",
		Vector2i(4, 3): "c", Vector2i(6, 3): "c", Vector2i(18, 2): "-", Vector2i(18, 4): "-",
		Vector2i(3, 12): "c", Vector2i(6, 12): "c", Vector2i(20, 13): "c", Vector2i(12, 19): "%",
		Vector2i(5, 19): "u", Vector2i(4, 19): "-", Vector2i(2, 18): "c",
		Vector2i(18, 20): "e", Vector2i(20, 20): "-", Vector2i(22, 20): "i",
		Vector2i(28, 2): "-", Vector2i(28, 5): "-", Vector2i(26, 12): "c", Vector2i(28, 12): "c", Vector2i(30, 12): "c",
	}
	for c in esperadas:
		var l: String = Terreno3D.letra_de(c)
		if l != esperadas[c]:
			_avisos.append("mapa: en %s esperaba «%s» y hay «%s»" % [c, esperadas[c], l])
			push_warning("LabPuzlesAgua3D: " + _avisos.back())


## La maqueta solo conecta UNA tinaja a `Mundo3D.abrir_cauce` (PruebaTest2._montar_canal se queda con la última) y lo hace con
## CAUDAL_TINAJA/VOL_TINAJA. Aquí hay dos tinajas y se quiere otro caudal: se conectan las dos desde el lab con los valores del lab;
## `abrir_cauce` REAJUSTA el manantial si ya existía con otros valores (la señal de la maqueta salta antes que esta: misma casilla, mismo paso).
func _cablear_tinajas() -> void:
	var canales: Dictionary = {Vector2i(13, 2): [Vector2i(12, 2), Vector2i(12, 3)], Vector2i(5, 19): [Vector2i(4, 19)]}
	for r in (m.get("_reactivos") as Array):
		if not is_instance_valid(r) or String(r.get("tipo")) != "surtidor" or not bool(r.get("_es_tinaja")):
			continue
		var orden: Array = canales.get(r.celda, [])
		if orden.is_empty():
			_avisos.append("tinaja en %s sin canal conocido" % [r.celda])
			continue
		r.sin_arroyo()
		r.agua_llega.connect(func() -> void: Mundo3D.abrir_cauce(orden, CAUDAL_TINAJA_LAB, VOL_TINAJA_LAB))


# ---------------------------------------------------------------------------------------------------------------------
#  Piezas comunes
# ---------------------------------------------------------------------------------------------------------------------

## Abre a la simulación las casillas `c` de una cuenca (hasta ahora selladas) y, si se pide, las llena hasta `y_sup`.
func _abrir_cuenca(celdas: Array, y_sup: float = -INF) -> void:
	var sim: AguaSim3D = Terreno3D.agua_sim
	for c in celdas:
		Terreno3D.cauces_abiertos[c] = true
		sim.solidificar_casilla(c as Vector2i, false)
		if y_sup > -INF:
			sim.llenar_casilla(c as Vector2i, y_sup)


func _lecho() -> float:
	return Terreno3D.alto_agua - Terreno3D.LECHO_AGUA


func _pulsador(c: Vector2i, modo: String, rearme: float = 0.0) -> Pulsador3D:
	var p := Pulsador3D.new()
	p.name = "pulsador_%s_%d_%d" % [modo, c.x, c.y]
	p.preparar(c, modo, rearme)
	(m.get("_props") as Node).add_child(p)
	_pulsadores[c] = p
	return p


func pulsador_en(c: Vector2i) -> Pulsador3D:
	return _pulsadores.get(c, null)


func _compuerta(c: Vector2i, abierta: bool, abre_con: String, cierra_con: String, vertical: bool = true, estrecha: bool = true) -> Compuerta3D:
	var k := Compuerta3D.new()
	k.name = "compuerta_%d_%d" % [c.x, c.y]
	k.estrecha = estrecha
	k.preparar(c, abierta, abre_con, cierra_con, vertical)
	(m.get("_props") as Node).add_child(k)
	return k


func _detector(c: Vector2i, objetivo: float, banda: float = 0.0, invertido: bool = false) -> NivelAgua3D:
	var d := NivelAgua3D.new()
	d.name = "nivel_%d_%d" % [c.x, c.y]
	d.preparar(c, objetivo, banda, invertido)
	(m.get("_props") as Node).add_child(d)
	return d


func _puerta(c: Vector2i) -> PuertaLab:
	var p := PuertaLab.new()
	p.name = "puerta_%d_%d" % [c.x, c.y]
	p.preparar(c)
	(m.get("_props") as Node).add_child(p)
	return p


func _registrar(nombre: String, entrada: Vector2i, detector: NivelAgua3D, compuerta: Compuerta3D, puerta: PuertaLab) -> Dictionary:
	var q: Dictionary = {"nombre": nombre, "entrada": entrada, "detector": detector, "compuerta": compuerta, "puerta": puerta}
	_puzles.append(q)
	if detector != null and puerta != null:
		detector.nivel_alcanzado.connect(puerta.poner)
	return q


func _tinaja_en(c: Vector2i) -> Reactivo3D:
	for r in (m.get("_reactivos") as Array):
		if is_instance_valid(r) and r.tipo == "surtidor" and r.celda == c:
			return r
	return null


static func _runa(etiquetas: Array) -> RuneData:
	var r := RuneData.new()
	var t: Array[String] = []
	for e in etiquetas:
		t.append(String(e))
	r.tags = t
	return r


## Hiela una casilla por código (como el hechizo, pero sin apuntar) y la deshiela pasados DURA_HIELO s (con el reloj de este nodo,
## no con un temporizador del árbol: así va con la simulación y con las pruebas sin ventana).
func _helar_por_boton(c: Vector2i) -> void:
	var sim: AguaSim3D = Terreno3D.agua_sim
	sim.helar_casilla(c, true)
	Terreno3D.poner_helada(c, true)
	_hielos[c] = DURA_HIELO_BOTON


# ---------------------------------------------------------------------------------------------------------------------
#  Los puzles
# ---------------------------------------------------------------------------------------------------------------------

func _montar_q1() -> void:
	_abrir_cuenca([Vector2i(11, 4), Vector2i(12, 4), Vector2i(13, 4), Vector2i(11, 5), Vector2i(12, 5), Vector2i(13, 5)])
	var det: NivelAgua3D = _detector(Vector2i(12, 5), 0.45)
	var q: Dictionary = _registrar("Q1 cuenca", Vector2i(12, 8), det, null, _puerta(Vector2i(15, 1)))
	var tinaja: Reactivo3D = _tinaja_en(Vector2i(13, 2))
	var activar := func(_modo: String) -> void:
		if tinaja != null:
			tinaja.on_spell_hit(_runa(["agua", "humedo"]), Vector3.ZERO)
	_pulsador(Vector2i(10, 2), "magia").pulsado.connect(activar)
	_pulsador(Vector2i(10, 6), "presencia").pulsado.connect(activar)
	q["tinaja"] = tinaja


func _montar_q2() -> void:
	var a: Array = [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 3)]
	var b: Array = [Vector2i(5, 2), Vector2i(6, 2), Vector2i(5, 3), Vector2i(6, 3)]
	_abrir_cuenca(a, Terreno3D.alto_agua)            # A llena hasta el nivel del río (0,9 de hondo)
	_abrir_cuenca(b)
	var k: Compuerta3D = _compuerta(Vector2i(4, 3), false, "fuego", "")
	var det: NivelAgua3D = _detector(Vector2i(6, 3), 0.35)
	_registrar("Q2 trasvase", Vector2i(4, 8), det, k, _puerta(Vector2i(1, 6)))
	_pulsador(Vector2i(2, 6), "magia").pulsado.connect(func(_mo: String) -> void: k.abrir())
	_pulsador(Vector2i(6, 6), "presencia").pulsado.connect(func(_mo: String) -> void: k.abrir())
	# (Sin tronco que flote en B, de momento: Flotador3D es un cuerpo rígido y con el nivel leído de letras no hay suelo con colisión;
	# caería sin fin cuando B está vacía. Irá con 12.4 / «plataforma pisable», AGUA_PUZLES.md §3.)


func _montar_q3() -> void:
	var arroyo: Array = []
	for y in range(1, 8):
		arroyo.append(Vector2i(18, y))
	Mundo3D.abrir_cauce(arroyo, CAUDAL_ARROYO_Q3, 0.0)                           # manantial arriba (con su arranque suave), INFINITO: es un arroyo, no una tinaja
	Terreno3D.agua_sim.fijar_nivel(Vector2i(18, 7), Terreno3D.alto_suelo + Terreno3D.FONDO_CANAL + 0.02)   # desagüe abajo
	var det: NivelAgua3D = _detector(Vector2i(18, 4), 0.25, 0.0, true)
	_registrar("Q3 presa", Vector2i(20, 8), det, null, _puerta(Vector2i(22, 4)))
	var helar := func(_mo: String) -> void: _helar_por_boton(Vector2i(18, 2))
	_pulsador(Vector2i(17, 6), "magia", 3.0).pulsado.connect(helar)
	_pulsador(Vector2i(21, 6), "presencia").pulsado.connect(helar)


func _montar_q4() -> void:
	var red: Array = [Vector2i(4, 10), Vector2i(4, 11), Vector2i(4, 12), Vector2i(2, 12), Vector2i(1, 12),
		Vector2i(5, 12), Vector2i(6, 12), Vector2i(7, 12)]
	_abrir_cuenca(red)
	var sim: AguaSim3D = Terreno3D.agua_sim
	sim.fuente_en(Vector2i(4, 10), CAUDAL_ARROYO)
	# Solo el brazo oeste desagua (nivel fijo bajo). El este es un FONDO DE SACO: con el oeste abierto se queda al nivel del cruce (~0,1 u,
	# el agua escapa por el oeste); cerrado el oeste, todo el caudal se embalsa en el este y sube hasta la «rueda». Medido en la primera
	# tirada (15/10): con los dos brazos desaguando a nivel fijo, las profundidades no distinguían el caudal (0,11 → 0,11): a estas
	# pendientes una tubería lleva 0,3 u³/s con un desnivel de un centésimo. El caudal se ve en la ALTURA solo si el agua se embalsa.
	sim.fijar_nivel(Vector2i(1, 12), _lecho() + 0.1)
	var k: Compuerta3D = _compuerta(Vector2i(3, 12), true, "fuego", "hielo", true, false)   # abierta y ANCHA (es un brazo del río, no un grifo); el hielo la tapona, el fuego la vuelve a abrir
	var det: NivelAgua3D = _detector(Vector2i(6, 12), 0.4)                            # «la rueda»
	_registrar("Q4 desvío", Vector2i(8, 12), det, k, _puerta(Vector2i(6, 10)))
	_pulsador(Vector2i(2, 10), "magia", 2.0).pulsado.connect(func(_mo: String) -> void: k.alternar())
	_pulsador(Vector2i(6, 14), "presencia").pulsado.connect(func(_mo: String) -> void: k.alternar())


func _montar_q5() -> void:
	var pasillo: Array = [Vector2i(20, 10), Vector2i(20, 11), Vector2i(20, 12)]
	_abrir_cuenca(pasillo, _lecho() + 0.7)                                       # se nada (≥ UMBRAL_NADO)
	_abrir_cuenca([Vector2i(20, 14)])
	Terreno3D.agua_sim.fijar_nivel(Vector2i(20, 14), _lecho() + 0.02)             # el sumidero
	var k: Compuerta3D = _compuerta(Vector2i(20, 13), false, "fuego", "", false)
	var det: NivelAgua3D = _detector(Vector2i(20, 11), 0.25, 0.0, true)
	_registrar("Q5 vaciar", Vector2i(16, 12), det, k, _puerta(Vector2i(22, 10)))
	_pulsador(Vector2i(18, 10), "magia").pulsado.connect(func(_mo: String) -> void: k.abrir())
	_pulsador(Vector2i(18, 14), "presencia").pulsado.connect(func(_mo: String) -> void: k.abrir())


func _montar_q6() -> void:
	var puerta: PuertaLab = _puerta(Vector2i(12, 22))
	var q: Dictionary = _registrar("Q6 riego", Vector2i(12, 16), null, null, puerta)
	var agua: Pulsador3D = _pulsador(Vector2i(12, 19), "agua")
	agua.pulsado.connect(func(_mo: String) -> void: puerta.poner(true))
	_pulsador(Vector2i(14, 19), "presencia").pulsado.connect(func(_mo: String) -> void: puerta.poner(true))
	# El botón de magia de esta sala es el CONTROL: cualquier hechizo lo pulsa, pero no abre nada. Si abre, el modo "agua" no filtra.
	var control: Pulsador3D = _pulsador(Vector2i(10, 19), "magia", 2.0)
	q["pulsador_agua"] = agua
	q["control"] = control


func _montar_q8() -> void:
	_abrir_cuenca([Vector2i(2, 18), Vector2i(3, 18), Vector2i(2, 19), Vector2i(3, 19)])
	var det: NivelAgua3D = _detector(Vector2i(2, 18), 0.5, 0.08)
	var q: Dictionary = _registrar("Q8 nivel justo", Vector2i(4, 16), det, null, _puerta(Vector2i(1, 22)))
	var cerrar := func(_mo: String) -> void: Terreno3D.agua_sim.apagar_fuente(Vector2i(4, 19))
	_pulsador(Vector2i(2, 21), "magia", 1.0).pulsado.connect(cerrar)
	_pulsador(Vector2i(6, 22), "presencia").pulsado.connect(cerrar)
	q["tinaja"] = _tinaja_en(Vector2i(5, 19))


func _montar_q7() -> void:
	var canal: Array = [Vector2i(19, 20), Vector2i(20, 20), Vector2i(21, 20)]
	_abrir_cuenca(canal)                                                          # abierto y vacío (abrir_solo recordado: forma de canal)
	var em := EmisorRayo3D.new()
	em.name = "emisor_18_20"
	(m.get("_props") as Node).add_child(em)
	em.preparar(m, Vector2i(18, 20))
	var puerta: PuertaLab = _puerta(Vector2i(20, 22))
	var q: Dictionary = _registrar("Q7 rayo", Vector2i(20, 16), null, null, puerta)
	var totem: Reactivo3D = null
	for r in (m.get("_reactivos") as Array):
		if is_instance_valid(r) and String(r.get("tipo")) == "totem" and String(r.get("elemento")) == "rayo" and r.celda == Vector2i(22, 20):
			totem = r
	if totem != null:
		totem.activado.connect(func(_t: String, _e: String) -> void: puerta.poner(true))
	else:
		_avisos.append("Q7: no hay tótem de rayo en (22,20)")
	q["emisor"] = em
	q["totem"] = totem
	q["canal"] = canal
	var echar := func(_mo: String) -> void:
		for c in canal:
			Terreno3D.agua_sim.llenar_casilla(c as Vector2i, Terreno3D.alto_suelo + Terreno3D.FONDO_CANAL + 0.35)   # como ~6 hechizos: 0,35 u en el cajón
	_pulsador(Vector2i(18, 22), "magia", 1.0).pulsado.connect(echar)
	_pulsador(Vector2i(22, 22), "presencia").pulsado.connect(echar)


func _montar_q9() -> void:
	var arroyo: Array = []
	for y in range(1, 8):
		arroyo.append(Vector2i(28, y))
	_abrir_cuenca(arroyo)                                                         # el canal, abierto pero SECO: el manantial nace al abrir la compuerta
	var sim: AguaSim3D = Terreno3D.agua_sim
	sim.fijar_nivel(Vector2i(28, 7), Terreno3D.alto_suelo + Terreno3D.FONDO_CANAL + 0.02)   # desagüe abajo
	# La compuerta hace de grifo: abierta, arranca el manantial (con su rampa); cerrada, lo apaga. (Con el manantial siempre abierto y la
	# compuerta cerrada el agua se apilaba sin fin en la primera casilla: el cajón del canal no rebosa hacia los lados.)
	var k: Compuerta3D = _compuerta(Vector2i(28, 2), false, "", "", false)      # losa E-O: el agua va N-S
	k.cambio.connect(func(abierta: bool) -> void:
		if abierta:
			sim.sumar_fuente_gradual(Vector2i(28, 1), CAUDAL_ARROYO_Q3, ReaccionesAgua3D.ARRANQUE_CAUCE)
		else:
			sim.apagar_fuente(Vector2i(28, 1))
	)
	var mol := Molino3D.new()
	mol.name = "molino_28_5"
	mol.preparar(Vector2i(28, 5), 0.3, true)
	(m.get("_props") as Node).add_child(mol)
	var puerta: PuertaLab = _puerta(Vector2i(31, 4))
	var q: Dictionary = _registrar("Q9 molino", Vector2i(28, 8), null, k, puerta)
	mol.girando.connect(puerta.poner)
	q["molino"] = mol
	_pulsador(Vector2i(26, 6), "magia").pulsado.connect(func(_mo: String) -> void: k.abrir())
	_pulsador(Vector2i(30, 6), "presencia").pulsado.connect(func(_mo: String) -> void: k.abrir())


func _montar_q10() -> void:
	var cauce: Array = [Vector2i(25, 12), Vector2i(26, 12), Vector2i(27, 12), Vector2i(29, 12), Vector2i(30, 12)]
	_abrir_cuenca(cauce)
	var sim: AguaSim3D = Terreno3D.agua_sim
	sim.fuente_en(Vector2i(26, 12), CAUDAL_ARROYO)
	sim.fijar_nivel(Vector2i(25, 12), _lecho() + 0.85)                           # aliviadero: lo que sobra se va por aquí, no por la sala
	var roca: Compuerta3D = _compuerta(Vector2i(28, 12), false, "explosion", "", true, false)
	var barril := Barril3D.new()
	barril.name = "barril_28_11"
	barril.preparar(Vector2i(28, 11))
	(m.get("_props") as Node).add_child(barril)
	var det: NivelAgua3D = _detector(Vector2i(30, 12), 0.4)
	var q: Dictionary = _registrar("Q10 roca", Vector2i(24, 12), det, roca, _puerta(Vector2i(30, 10)))
	q["barril"] = barril
	_pulsador(Vector2i(26, 10), "magia").pulsado.connect(func(_mo: String) -> void: barril.encender())
	_pulsador(Vector2i(30, 14), "presencia").pulsado.connect(func(_mo: String) -> void: barril.encender())


# ---------------------------------------------------------------------------------------------------------------------
#  Marcha
# ---------------------------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	# Hielos puestos por botón: caducan como los del hechizo.
	for c in _hielos.keys():
		_hielos[c] = float(_hielos[c]) - delta
		if float(_hielos[c]) <= 0.0:
			_hielos.erase(c)
			if Terreno3D.agua_sim != null:
				Terreno3D.agua_sim.helar_casilla(c, false)
			Terreno3D.poner_helada(c, false)
	_t_hud += delta
	if _t_hud >= T_HUD:
		_t_hud = 0.0
		_refrescar_hud()


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or m == null:
		return
	var k: InputEventKey = ev as InputEventKey
	if not k.pressed or k.echo:
		return
	if k.keycode == KEY_R:
		get_tree().reload_current_scene()
		return
	# El orden de _puzles es Q1…Q6, Q7, Q8, Q9, Q10; la tecla 0 es Q10.
	var teclas: Dictionary = {KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3, KEY_5: 4, KEY_6: 5, KEY_7: 6, KEY_8: 7, KEY_9: 8, KEY_0: 9}
	if teclas.has(k.keycode):
		var n: int = int(teclas[k.keycode])
		if n < _puzles.size():
			colocar_jugador(_puzles[n]["entrada"] as Vector2i)


## Teletransporte del jugador a una casilla (lo mismo que escenario_base.colocar_jugador).
func colocar_jugador(c: Vector2i) -> void:
	if _jug == null:
		return
	var p: Vector3 = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
	if _jug.pj != null:
		_jug.pj.position = p
	_jug.position = p


func puzle(nombre: String) -> Dictionary:
	for q in _puzles:
		if String(q["nombre"]).split(" ")[0] == nombre:        # «Q1», no «Q1 cuenca»; y «Q1» no es «Q10»
			return q
	return {}


func _montar_hud() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 6
	add_child(capa)
	_hud = Label.new()
	_hud.position = Vector2(12.0, 150.0)
	_hud.add_theme_font_size_override("font_size", 15)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 6)
	capa.add_child(_hud)
	_refrescar_hud()


func _refrescar_hud() -> void:
	if _hud == null or Terreno3D.agua_sim == null:
		return
	var t: String = "LAB PUZLES DE AGUA · 1–9, 0 ir a la sala · R recargar · agua total %.1f u³\n" % Terreno3D.agua_sim.volumen_total()
	for q in _puzles:
		var linea: String = "  %-16s" % String(q["nombre"])
		var det: NivelAgua3D = q["detector"]
		if det != null:
			linea += " nivel %.2f %s %.2f%s" % [det.profundidad, "≤" if det.invertido else ("≈" if det.banda > 0.0 else "≥"), det.objetivo,
				(" ±%.2f" % det.banda) if det.banda > 0.0 else ""]
		var k: Compuerta3D = q["compuerta"]
		if k != null:
			linea += "  compuerta %s" % ("ABIERTA" if k.abierta else "cerrada")
		if q.has("molino"):
			var mo: Molino3D = q["molino"]
			linea += "  corriente %.2f u/s  rueda %s" % [mo.corriente(), "GIRA" if mo.activo else "quieta"]
		if q.has("barril"):
			var ba: Barril3D = q["barril"]
			linea += "  barril %s" % ("EXPLOTADO" if ba.explotado else ("encendido" if ba.encendido else "entero"))
		if q.has("emisor"):
			var em: EmisorRayo3D = q["emisor"]
			linea += "  agua electrificada %d casillas" % em.electrificada.size()
		var p: PuertaLab = q["puerta"]
		if p != null:
			linea += "  puerta %s" % ("ABIERTA" if p.abierta else "cerrada")
		t += linea + "\n"
	for a in _avisos:
		t += "  AVISO " + String(a) + "\n"
	_hud.text = t
