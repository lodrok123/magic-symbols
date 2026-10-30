class_name Surtidor3D
extends Area3D

## SURTIDOR (9.11, Juego): la fuente de piedra (letra `u`) que, al recibir AGUA, llena el CAUCE SECO (casillas `c`) y lo une
## al río. Es la regla «agua que rellena» de 5.5, en pequeño: un solo surtidor, un solo cauce, una sola vez.
##
## POR QUÉ SE CAMBIA LA LETRA DE LA CASILLA. Todo el juego decide si una casilla es agua mirando su letra (`~`): el jugador al
## nadar, los goblins al esquivarla, el hielo, el emisor de rayo. Si el cauce «parece» agua pero su letra sigue siendo `c`,
## nada de eso lo sabe y la corriente no pasaría. Cambiar la letra en `_mapa` (y bloquearla a pie, como las demás `~`) hace
## que TODAS esas reglas lo vean a la vez, sin tocar ninguna. Lo mismo hizo el puente reactivo con la letra `b`.
##
## Cómo se ve: si la maqueta tiene `poner_agua(celdas)` (lo pone el Pipeline, 9.7) se usa para dibujar el agua de verdad; si
## no, una losa azul translúcida por casilla. La lógica no depende de ello: se prueba sin dibujo.
##
## Contrato de hechizos (docs/DIARIO.md, 2026-10-06): on_spell_hit, spell_reacts, nivel_altura, carried_element. Solo reacciona
## al agua. El hielo no: congelar el surtidor no lo llena.

signal lleno(celdas: Array)

const LETRA_CAUCE: String = "c"
const T_ENTRE_CASILLAS: float = 0.22     ## s entre una casilla del cauce y la siguiente: el agua BAJA, no aparece de golpe

var m: Variant = null
var celda: Vector2i = Vector2i.ZERO
var cauce: Array = []                    ## Vector2i del cauce seco, de la más cercana al surtidor a la más lejana
var esta_lleno: bool = false

## --- Con la simulación del agua (11.5) ---
## El surtidor ABRE el cauce y echa un manantial en su primera casilla: el agua corre por él y cada casilla pasa a ser «~»
## cuando la simulación dice que ya tiene agua, no por un temporizador.
const CAUDAL_SURTIDOR: float = 6.0       ## u³/s. Una casilla de cauce con agua son ~4,8 u³ (5,3 u² × 0,9 de hondo)
const NIVEL_LLENO: float = 0.8           ## fracción de la hondura del cauce (LECHO_AGUA) a la que se cierra el manantial
const VOL_TINAJA: float = 30.0           ## u³ de referencia de una tinaja CON FONDO (15/10, Pablo): `Mundo3D.abrir_cauce(celdas, caudal, VOL_TINAJA)` la apaga sola al echarlos. El canal del Bosque NO lo usa: sigue permanente hasta que el tótem para la tinaja (13/10). Con 1,5 u³/s y el arranque de 18 s (que gasta ~13,5), serían ~11 s más a pleno caudal
const CAUDAL_TINAJA: float = 1.5         ## u³/s del canal de RUINAS (manantial finito desde el 15/10: ver VOL_TINAJA). Medido en el Bosque 60 s (12/10): con 1,0 el canal desagua al río más rápido de lo que entra y no llega a 0,25; con 3,0 inunda la zona (+230 trocitos de agua); con 1,5 el canal queda en 0,48/0,35/0,18 y solo salen ~55 trocitos del canal. Saldrá de calcular_chorro (11.17)
const SOBRE_FONDO_FORZADO: float = 0.3   ## u: hasta dónde llena a la fuerza un canal de ruinas (fondo + esto), no hasta alto_agua
const T_MAX: float = 40.0                ## s: si el agua no llega (cauce mal puesto), se llena a la fuerza para no atascar el nivel
var _sim: AguaSim3D = null
var _convertidas: Dictionary = {}
var _t_total: float = 0.0
var _permanente: bool = false            ## canal de ruinas: el grifo no se cierra nunca


func preparar(p_mundo: Variant, p_celda: Vector2i) -> void:
	m = p_mundo
	celda = p_celda
	position = Terreno3D.centro_de(celda, Terreno3D.alto_suelo)
	cauce = _calcular_cauce()


func _ready() -> void:
	collision_layer = Lanzador3D.CAPA_REACTIVO
	collision_mask = 0
	monitoring = false
	monitorable = true
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(Terreno3D.casilla * 0.9, 1.4, Terreno3D.casilla * 0.9)
	forma.shape = caja
	forma.position = Vector3(0.0, 0.7, 0.0)
	add_child(forma)


## ¿Es cauce seco la casilla `c` de la maqueta? La letra «c» o un tramo de canal de ruinas (`_es_canal`: `-`, `L` o las piezas canal_*
## de un nivel horneado). Se pregunta a la maqueta y no a Lanzador3D porque preparar() va antes de configurarlo.
static func es_cauce_de(p_mundo: Variant, c: Vector2i) -> bool:
	if p_mundo == null:
		return false
	return String(p_mundo.call("_letra", c)) == LETRA_CAUCE or (p_mundo.has_method("_es_canal") and bool(p_mundo.call("_es_canal", c)))


func _calcular_cauce() -> Array:
	return Surtidor3D.buscar_cauce(celda, func(c: Vector2i) -> bool: return Surtidor3D.es_cauce_de(m, c))


## Casillas de cauce unidas (por las 4 vecinas) a las vecinas del surtidor, ordenadas por distancia de relleno: así el agua
## corre desde el surtidor hacia fuera. Estática: se mide sin escena.
static func buscar_cauce(origen: Vector2i, es_cauce: Callable) -> Array:
	var visto: Dictionary = {}
	var cola: Array = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c: Vector2i = origen + d
		if bool(es_cauce.call(c)) and not visto.has(c):
			visto[c] = true
			cola.append(c)
	var i: int = 0
	while i < cola.size():
		var c2: Vector2i = cola[i]
		i += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var v: Vector2i = c2 + d
			if not visto.has(v) and bool(es_cauce.call(v)):
				visto[v] = true
				cola.append(v)
	return cola


## --- Contrato con los hechizos ---

func on_spell_hit(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO, hechizo: Hechizo = null) -> void:
	if rune_data != null and Materia.riega(Materia.de(hechizo if hechizo != null else rune_data)) and not esta_lleno:
		llenar()


func spell_reacts(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO, hechizo: Hechizo = null) -> bool:
	return rune_data != null and Materia.riega(Materia.de(hechizo if hechizo != null else rune_data)) and not esta_lleno


func carried_element() -> RuneData:
	return null


func nivel_altura() -> int:
	return 1


## Llena el cauce, una casilla tras otra. Se puede llamar a mano (las pruebas).
func llenar() -> void:
	if esta_lleno:
		return
	esta_lleno = true
	cauce = _calcular_cauce()               # otra vez: al preparar, la maqueta puede no haber leído aún el canal
	if Terreno3D.agua_sim != null and is_inside_tree() and not cauce.is_empty():
		_llenar_con_fisica(Terreno3D.agua_sim)
		return
	var celdas: Array = cauce.filter(func(c: Variant) -> bool: return String(m.call("_letra", c)) == LETRA_CAUCE)   # el canal de ruinas no cambia de letra
	if m != null and m.get("_fx") != null:
		(m.get("_fx") as Vfx3D).chispazo(global_position + Vector3(0.0, 1.2, 0.0), "agua")
	for i in range(celdas.size()):
		var c: Vector2i = celdas[i]
		if i == 0 or not is_inside_tree():
			Surtidor3D.convertir_a_agua(m, c)
		else:
			get_tree().create_timer(T_ENTRE_CASILLAS * float(i)).timeout.connect(Surtidor3D.convertir_a_agua.bind(m, c))
	var total: float = T_ENTRE_CASILLAS * float(maxi(celdas.size() - 1, 0))
	if is_inside_tree():
		get_tree().create_timer(total).timeout.connect(func() -> void: lleno.emit(celdas))
	else:
		lleno.emit(celdas)


func _llenar_con_fisica(sim: AguaSim3D) -> void:
	_sim = sim
	if m != null and m.get("_fx") != null:
		(m.get("_fx") as Vfx3D).chispazo(global_position + Vector3(0.0, 1.2, 0.0), "agua")
	for c in cauce:
		Terreno3D.cauces_abiertos[c] = true
		sim.solidificar_casilla(c as Vector2i, false)      # el foso se abre: el agua puede entrar
	_permanente = _tiene_canal_ruinas()
	if _permanente:
		# La tinaja es un manantial por CANAL, no por quien lo abre: la maqueta también lo abre cuando el agua de su chorro llega
		# (PruebaTest2._montar_canal → Mundo3D.abrir_cauce). Por la misma vía, la segunda llamada no suma otra vez (si no, 3,0 u³/s inunda).
		Mundo3D.abrir_cauce(cauce, CAUDAL_TINAJA)
	else:
		sim.sumar_fuente(cauce[0] as Vector2i, CAUDAL_SURTIDOR)
	set_process(true)


## ¿Alguna casilla del cauce es canal de ruinas? Entonces el surtidor es la TINAJA: un manantial que no se cierra.
func _tiene_canal_ruinas() -> bool:
	for c in cauce:
		if Terreno3D.es_canal_ruinas(c as Vector2i):
			return true
	return false


## Hasta dónde se llena a la fuerza una casilla del cauce: el canal de ruinas, a su fondo + 0,3; el cauce «c», hasta alto_agua.
func _nivel_forzado(c: Vector2i) -> float:
	if Terreno3D.es_canal_ruinas(c):
		return Terreno3D.alto_suelo + Terreno3D.FONDO_CANAL + SOBRE_FONDO_FORZADO
	return Terreno3D.alto_agua


## Al llegar el agua: el cauce «c» cambia de letra a «~» (como siempre); el canal de ruinas NO (sigue siendo canal para la maqueta y
## `es_agua` ya lo ve por la simulación).
func _pasar_a_agua(c: Vector2i) -> void:
	if String(m.call("_letra", c)) == LETRA_CAUCE:
		Surtidor3D.convertir_a_agua(m, c)


func _process(delta: float) -> void:
	if _sim == null:
		set_process(false)
		return
	_t_total += delta
	for c in cauce:
		if not _convertidas.has(c) and _sim.es_agua_casilla(c as Vector2i):
			_convertidas[c] = true
			_pasar_a_agua(c as Vector2i)
	var todas: bool = _convertidas.size() >= cauce.size()
	if not todas and _t_total >= T_MAX:
		for c in cauce:                                     # a la fuerza: mejor un nivel jugable que un surtidor roto
			if not _convertidas.has(c):
				_sim.llenar_casilla(c as Vector2i, _nivel_forzado(c as Vector2i))
				_convertidas[c] = true
				_pasar_a_agua(c as Vector2i)
		todas = true
	if todas and _permanente:
		# La tinaja deja el grifo abierto: el canal desagua por donde la pieza abre y se mantiene a su nivel.
		var celdas_p: Array = cauce.duplicate()
		_sim = null
		set_process(false)
		lleno.emit(celdas_p)
		return
	if todas:
		# Cierra el grifo cuando el cauce está casi a su nivel (no al llegar el agua): con el grifo abierto de más, un
		# cauce sin río que lo desagüe subiría por encima de la orilla. Lo que falte lo reparte el agua que ya hay.
		var media: float = 0.0
		for c in cauce:
			media += _sim.profundidad_casilla(c as Vector2i)
		media /= float(cauce.size())
		if media >= NIVEL_LLENO * Terreno3D.LECHO_AGUA or _t_total >= T_MAX:
			_sim.sumar_fuente(cauce[0] as Vector2i, -CAUDAL_SURTIDOR)
			var celdas: Array = cauce.duplicate()
			_sim = null
			set_process(false)
			lleno.emit(celdas)


## Pasa UNA casilla de la maqueta a agua: la letra (`~`), el bloqueo a pie, y su dibujo.
static func convertir_a_agua(p_mundo: Variant, c: Vector2i) -> void:
	if p_mundo == null or not is_instance_valid(p_mundo):
		return
	var mapa: PackedStringArray = p_mundo.get("_mapa")
	if c.y < 0 or c.y >= mapa.size() or c.x < 0 or c.x >= mapa[c.y].length():
		return
	var fila: String = mapa[c.y]
	mapa[c.y] = fila.substr(0, c.x) + "~" + fila.substr(c.x + 1)
	p_mundo.set("_mapa", mapa)
	var bloq: Variant = p_mundo.get("_bloqueadas")
	if bloq is Dictionary:
		(bloq as Dictionary)[c] = true           # como el resto del agua: a pie no se pisa (se nada desde la orilla)
	if p_mundo.has_method("poner_agua"):
		p_mundo.call("poner_agua", [c])
	elif p_mundo is Node3D and (p_mundo as Node3D).is_inside_tree():
		var q := MeshInstance3D.new()
		var plano := QuadMesh.new()
		plano.orientation = PlaneMesh.FACE_Y
		plano.size = Vector2(Terreno3D.casilla, Terreno3D.casilla)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.25, 0.5, 0.9, 0.7)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		plano.material = mat
		q.mesh = plano
		q.name = "agua_nueva"
		q.position = Terreno3D.centro_de(c, Terreno3D.alto_agua + 0.02)
		(p_mundo as Node3D).add_child(q)
	var fx: Variant = p_mundo.get("_fx")
	if fx != null:
		(fx as Vfx3D).vapor(Terreno3D.centro_de(c, Terreno3D.alto_agua))
