class_name Verraco3D
extends Node3D

## X2 de docs/PLAN_COMBATE_2026-11-22.md · EL VERRACO (docs/ENEMIGOS_MITOLOGIA_2026-11-22.md §2; Pablo, 22/11: «Sí, ese orden»). Dueño: Juego. PLACEHOLDER de primitivas, como el dragón.
##
## Un jabalí vivo con ARMADURA puesta (barda de cuero, hueso y tablas atada con correas). Filosofía (§0, del jefe sombra de Mystralia, O27): con la armadura puesta no hay daño; la ventana la abre el entorno.
##   · ACECHA: mira a la jugadora. Si la ve en línea libre y a ≤ VISTA_CASILLAS, se prepara.
##   · POSE (C25, A5): pezuña y cabeza baja, QUIETO, POSE_S; una línea en el suelo (`AvisoAtaque3D.rectangulo`, ventana de esquiva de 0,25 s del cuerpo a cuerpo).
##     Si en ese tiempo aparece una BARRERA NUEVA en su línea, FRENA y no embiste (hay que ponerla cuando ya ha arrancado: la tierra tarda 0,70 s en salir, C18).
##   · EMBISTE en línea recta a VEL_EMBESTIDA hasta la jugadora + PASADA_CASILLAS. Si choca contra algo SÓLIDO (pared, columna, barrera de tierra) queda ATURDIDO ATURDIDO_S;
##     si no choca, se para y vuelve a acechar. Sobre suelo MOJADO patina y sigue (hasta PATINA_EXTRA_CASILLAS más): se estrella más lejos de lo que calculaba.
##     A la jugadora que pilla la hiere (DANO_EMBESTIDA) y la aparta (la voltereta la libra).
##   · CON ARMADURA (estado inicial): ningún hechizo, del elemento que sea, le hace daño (golpe sordo y «Armadura», lo ineficaz, C20). Cada choque le arranca UNA placa
##     (`placas_rotas`, de PLACAS: testuz, lomo, flancos). Al último choque CAE LA ARMADURA (`sin_armadura`, señal `expuesto`) y NO vuelve: solo `reiniciar` la devuelve.
##   · SIN ARMADURA: cualquier hechizo le hace daño, ×1; mientras está ATURDIDO, ×MULT_NUCLEO. Sigue acechando y embistiendo igual; si choca contra algo sólido
##     recibe DANO_CHOQUE y queda aturdido. El agua sigue haciéndolo patinar, con o sin armadura.
## Al morir la jugadora vuelve como al empezar (`reiniciar`, G1).

signal embiste
signal choca(placas: int)
signal frena
signal expuesto
signal derrotado

enum Fase { ACECHA, POSE, EMBISTE, ATURDIDO, MUERTO }

static var VIDA: float = 90.0
static var VISTA_CASILLAS: float = 7.0
static var POSE_S: float = 0.6
static var VEL_EMBESTIDA: float = 9.0          ## u/s
static var PASADA_CASILLAS: float = 2.0       ## cuánto se pasa de donde estaba ella si no choca
static var PATINA_EXTRA_CASILLAS: float = 4.0 ## lo más que alarga la embestida el suelo mojado
static var ATURDIDO_S: float = 2.0
static var REPOSO_S: float = 1.2              ## tras una embestida sin choque o un frenazo, antes de volver a prepararse
static var PLACAS: int = 3                    ## choques que aguanta la armadura (una placa por choque)
static var MULT_NUCLEO: float = 1.5
static var DANO_EMBESTIDA: float = 25.0
static var EMPUJE_JUGADORA: float = 2200.0    ## la unidad de `Jugador3D.push` (la del 2D)
static var DANO_CHOQUE: float = 20.0           ## lo que se hace al chocar sin armadura
static var DANO_BARRERA: float = 40.0         ## lo que le quita a la barrera contra la que se estrella
static var TEMBLOR_CHOQUE: float = 0.45
const ANCHO_LINEA: float = 0.55               ## media anchura de la línea del suelo y de su golpe
const RADIO_CUERPO: float = 0.75
const COLOR_CERDA: Color = Color(0.27, 0.18, 0.12)          ## cerda marrón oscuro
const COLOR_PLACA: Color = Color(0.72, 0.55, 0.36)          ## cuero claro de la barda
const COLOR_DANO: Color = Color(1.0, 0.55, 0.15)

var fase: int = Fase.ACECHA
var vida: float = VIDA
var vida_max: float = VIDA
var placas_rotas: int = 0
var sin_armadura: bool = false                ## cae al último choque y solo `reiniciar` la devuelve
var celda: Vector2i = Vector2i.ZERO
var casa: Vector3 = Vector3.ZERO
var dir: Vector3 = Vector3(0, 0, 1)
var _mundo: Node = null
var _t: float = 0.0
var _libre_u: float = 0.0                     ## en la pose: distancia libre por delante (para notar una barrera nueva)
var _queda_u: float = 0.0                     ## en la embestida: lo que le queda por recorrer
var _patinado_u: float = 0.0
var _hirio: bool = false
var _aviso: AvisoAtaque3D = null
var _lanz: Lanzador3D = null
# Para las pruebas
var embestidas: int = 0
var choques: int = 0
var frenazos: int = 0
var patinazos: int = 0
var golpes_sin_efecto: int = 0
var golpes_dano: int = 0
var golpes_jugadora: int = 0
var reinicios: int = 0
var ultimo_choque: String = ""

var _raiz: Node3D = null
var _cabeza: Node3D = null
var _placas: Array[Node3D] = []              ## testuz, lomo, flancos: una se oculta por choque
var _mat: StandardMaterial3D = null
var _cuerpo: CuerpoVerraco = null
var _destello: float = 0.0


## El cuerpo que reciben los hechizos (capa de reactivos, como los cristales del dragón).
class CuerpoVerraco extends Area3D:
	var verraco: Verraco3D = null

	func montar(v: Verraco3D) -> void:
		verraco = v
		monitoring = false
		monitorable = true
		collision_mask = 0
		collision_layer = Lanzador3D.CAPA_REACTIVO
		var forma := CollisionShape3D.new()
		var caja := BoxShape3D.new()
		caja.size = Vector3(1.3, 2.4, 1.9)
		forma.shape = caja
		forma.position = Vector3(0.0, 1.2, 0.0)
		add_child(forma)

	func on_spell_hit(rune_data: RuneData, direccion: Vector3 = Vector3.ZERO, hechizo: Hechizo = null) -> void:
		if verraco != null:
			verraco.on_spell_hit(rune_data, direccion, hechizo)

	func spell_reacts(_r: RuneData, _d: Vector3 = Vector3.ZERO, _h: Hechizo = null) -> bool:
		return verraco != null and verraco.fase != Verraco3D.Fase.MUERTO

	func carried_element() -> RuneData:
		return null


## Lo monta la pieza `verraco` de Puzle3D: en la casilla `p_celda`, mirando hacia `p_mira` (n, e, s, o).
func preparar(p_celda: Vector2i, p_mira: String, p_vida: float, p_mundo: Node) -> void:
	celda = p_celda
	_mundo = p_mundo
	vida = p_vida if p_vida > 0.0 else VIDA
	vida_max = vida
	match p_mira:
		"n": dir = Vector3(0, 0, -1)
		"e": dir = Vector3(1, 0, 0)
		"o": dir = Vector3(-1, 0, 0)
		_: dir = Vector3(0, 0, 1)
	casa = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda)) if Terreno3D.en_mapa(celda) else Vector3.ZERO
	position = casa
	_construir()
	_orientar()


func _ready() -> void:
	add_to_group("verraco")


func lanzador() -> Lanzador3D:
	if _lanz == null or not is_instance_valid(_lanz):
		_lanz = get_tree().get_first_node_in_group("spellcaster") as Lanzador3D if is_inside_tree() else null
	return _lanz


func jugadora() -> Node3D:
	var l: Lanzador3D = lanzador()
	return l.jugador as Node3D if l != null and l.jugador != null and is_instance_valid(l.jugador) else null


# ---------------------------------------------------------------------------------------------------------------------
#  Marcha
# ---------------------------------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t += delta
	_destello = maxf(0.0, _destello - delta)
	match fase:
		Fase.ACECHA:
			_acechar()
		Fase.POSE:
			_pose()
		Fase.EMBISTE:
			_embestir(delta)
		Fase.ATURDIDO:
			if _t >= ATURDIDO_S:
				_cambiar(Fase.ACECHA)
	_animar(delta)


func _cambiar(nueva: int) -> void:
	fase = nueva
	_t = 0.0


## Mira a la jugadora; si la ve en línea libre, a tiro, y sin barrera en medio, se prepara (pose + línea en el suelo).
func _acechar() -> void:
	var j: Node3D = jugadora()
	if j == null or bool(j.get("muerto")) or _t < REPOSO_S:
		return
	var rel: Vector3 = j.global_position - global_position
	rel.y = 0.0
	if rel.length() < 0.2 or rel.length() > VISTA_CASILLAS * Terreno3D.casilla:
		return
	dir = rel.normalized()
	_orientar()
	if not Terreno3D.linea_libre(global_position, j.global_position):
		return
	var libre: float = _libre_hasta(maxf(rel.length() + (PASADA_CASILLAS + PATINA_EXTRA_CASILLAS) * Terreno3D.casilla, 0.0))
	if libre < rel.length() - 0.3:
		return                                           # hay algo entre los dos (una barrera ya puesta): no embiste contra lo que ve
	_libre_u = libre
	_queda_u = minf(rel.length() + PASADA_CASILLAS * Terreno3D.casilla, libre + 0.05)
	_cambiar(Fase.POSE)
	_quitar_aviso()
	if is_inside_tree() and get_parent() != null:
		_aviso = AvisoAtaque3D.rectangulo(get_parent(), global_position, dir, _queda_u, ANCHO_LINEA, POSE_S, self, 0.0)
		_aviso.ventana = AvisoAtaque3D.VENTANA_CUERPO     # A5: esquiva perfecta en los últimos 0,25 s
	if Sfx.CATALOGO.has("golem_carga"):
		Sfx3D.play(self, "golem_carga")


## La pose (C25): quieto. Si aparece una barrera NUEVA en su línea (más cerca que lo libre de antes), frena.
func _pose() -> void:
	var libre: float = _libre_hasta(_libre_u + 0.1)
	if libre < _libre_u - 0.3 and libre < _queda_u:
		frenazos += 1
		_quitar_aviso()
		Combate3D.flotante(get_parent(), global_position + Vector3(0, 2.0, 0), "¡Frena!", COLOR_PLACA, 1.0)
		PlayLog.event("verraco_frena", {"libre": snappedf(libre, 0.01)})
		frena.emit()
		_cambiar(Fase.ACECHA)
		return
	if _t >= POSE_S:
		embestidas += 1
		_hirio = false
		_patinado_u = 0.0
		_aviso = null                                    # el aviso acaba solo en su instante
		embiste.emit()
		PlayLog.event("verraco_embiste", {"largo": snappedf(_queda_u, 0.01)})
		_cambiar(Fase.EMBISTE)


func _embestir(delta: float) -> void:
	var paso: float = minf(VEL_EMBESTIDA * delta, maxf(_queda_u, 0.0))
	var sig: Vector3 = global_position + dir * paso
	var punta: Vector3 = sig + dir * RADIO_CUERPO
	var obst: String = _obstaculo(punta)
	if obst != "":
		_chocar(obst, punta)
		return
	global_position = sig
	_queda_u -= paso
	# Suelo mojado: patina y sigue (lo que le quede se alarga, con tope).
	var c: Vector2i = Terreno3D.celda_de(global_position)
	if Terreno3D.estados != null and Terreno3D.estados.tiene(c, EstadosSuelo3D.MOJADA) and _patinado_u < PATINA_EXTRA_CASILLAS * Terreno3D.casilla:
		var extra: float = minf(paso, PATINA_EXTRA_CASILLAS * Terreno3D.casilla - _patinado_u)
		if _patinado_u <= 0.0 and extra > 0.0:
			patinazos += 1
			Combate3D.flotante(get_parent(), global_position + Vector3(0, 1.8, 0), "¡Patina!", Combate3D.COLORES.get("agua", Color.CYAN), 0.9)
		_queda_u += extra
		_patinado_u += extra
	# La jugadora en su camino.
	var j: Node3D = jugadora()
	if j != null and not _hirio:
		var d: Vector3 = j.global_position - global_position
		d.y = 0.0
		if d.length() <= RADIO_CUERPO + 0.35:
			_hirio = true
			var vida0: float = float(j.get("vida"))
			if j.has_method("recibir_dano"):
				j.call("recibir_dano", DANO_EMBESTIDA, global_position)
			if float(j.get("vida")) < vida0:
				golpes_jugadora += 1
				var lado: Vector3 = Vector3(-dir.z, 0.0, dir.x)
				if lado.dot(d) < 0.0:
					lado = -lado
				if j.has_method("push"):
					j.call("push", (lado + dir * 0.5).normalized(), EMPUJE_JUGADORA)
	if _queda_u <= 0.01:
		_cambiar(Fase.ACECHA)                            # no chocó: se para y vuelve a acechar


## Qué hay en `p` que le pare: «muro» (terreno sólido o bloqueado), «barrera» (una SolidezV2 de la jugadora), «agua» (honda) o «» (nada).
func _obstaculo(p: Vector3) -> String:
	var c: Vector2i = Terreno3D.celda_de(p)
	if not Terreno3D.en_mapa(c):
		return "muro"
	if Terreno3D.celda_solida(c, 0) or (Terreno3D.bloqueada(c) and c != Terreno3D.celda_de(global_position)):
		return "muro"
	var l: Lanzador3D = lanzador()
	if l != null and l.solidez_en(Vector3(p.x, Terreno3D.y_pies(c) + 0.8, p.z)) != null:
		return "barrera"
	if Lanzador3D.es_agua(c):
		return "agua"
	return ""


## Distancia libre (u) por delante, en `dir`, hasta `maximo`.
func _libre_hasta(maximo: float) -> float:
	var paso: float = Terreno3D.casilla * 0.25
	var s: float = paso
	while s <= maximo:
		if _obstaculo(global_position + dir * (s + RADIO_CUERPO)) != "":
			return s
		s += paso
	return maximo


func _chocar(que: String, punto: Vector3) -> void:
	_quitar_aviso()
	if que == "agua":
		_cambiar(Fase.ACECHA)                            # se para en la orilla (no se tira al agua)
		return
	choques += 1
	ultimo_choque = que
	if que == "barrera":
		var l: Lanzador3D = lanzador()
		if l != null:
			l.solidez_para(Vector3(punto.x, Terreno3D.y_pies(Terreno3D.celda_de(punto)) + 0.8, punto.z), DANO_BARRERA)
	_temblar(TEMBLOR_CHOQUE)
	Sensacion3D.golpe_sordo(self)
	if not sin_armadura:
		placas_rotas = mini(placas_rotas + 1, PLACAS)
		_pintar_placas()
		Combate3D.flotante(get_parent(), global_position + Vector3(0, 2.0, 0), "¡Placa rota! (%d/%d)" % [placas_rotas, PLACAS], COLOR_PLACA, 1.1)
	PlayLog.event("verraco_choca", {"contra": que, "placas": placas_rotas})
	choca.emit(placas_rotas)
	if not sin_armadura and placas_rotas >= PLACAS:
		_soltar_armadura()
	elif sin_armadura:
		recibir(DANO_CHOQUE)
	if fase != Fase.MUERTO:
		_cambiar(Fase.ATURDIDO)


## Al último choque la barda se desata y cae: ya no se la vuelve a poner.
func _soltar_armadura() -> void:
	sin_armadura = true
	_temblar(TEMBLOR_CHOQUE * 1.5)
	Combate3D.flotante(get_parent(), global_position + Vector3(0, 2.2, 0), "¡Cae la armadura!", COLOR_DANO, 1.3)
	PlayLog.event("verraco_expuesto", {})
	expuesto.emit()


# ---------------------------------------------------------------------------------------------------------------------
#  Hechizos
# ---------------------------------------------------------------------------------------------------------------------

## Con armadura no hay daño (de ningún elemento); sin ella, daño normal, y ×MULT_NUCLEO si está aturdido.
func on_spell_hit(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO, hechizo: Hechizo = null) -> void:
	if fase == Fase.MUERTO:
		return
	if not sin_armadura:
		golpes_sin_efecto += 1
		Sensacion3D.golpe_sordo(self)
		if golpes_sin_efecto % 3 == 1:
			Combate3D.flotante(get_parent(), global_position + Vector3(0, 2.0, 0), "Armadura", Contacto.COLOR_INEFICAZ, 0.9)
		return
	var d: float = hechizo.dano if hechizo != null else 0.0
	if d <= 0.0 and rune_data != null and rune_data.get("damage") != null:
		d = float(rune_data.get("damage"))
	golpes_dano += 1
	_destello = 0.1
	recibir(d * (MULT_NUCLEO if fase == Fase.ATURDIDO else 1.0))


func recibir(d: float) -> void:
	if d <= 0.0 or fase == Fase.MUERTO:
		return
	vida = maxf(vida - d, 0.0)
	Combate3D.flotante(get_parent(), global_position + Vector3(0, 2.2, 0), str(int(round(d))), COLOR_DANO, 1.1)
	if vida <= 0.0:
		_morir()


func _morir() -> void:
	_quitar_aviso()
	_cambiar(Fase.MUERTO)
	if _cuerpo != null:
		_cuerpo.collision_layer = 0
		_cuerpo.monitorable = false
	_temblar(TEMBLOR_CHOQUE * 1.5)
	PlayLog.event("verraco_derrotado", {})
	derrotado.emit()
	var tw: Tween = create_tween()
	tw.tween_property(_raiz, "scale", Vector3(1.2, 0.05, 1.2), 0.6).set_ease(Tween.EASE_IN)


## G1 (morir y reintentar): vuelve a su sitio, entero y con la armadura puesta. Vencido, se queda vencido.
func reiniciar() -> void:
	if fase == Fase.MUERTO:
		return
	_quitar_aviso()
	global_position = casa
	vida = vida_max
	placas_rotas = 0
	sin_armadura = false
	_pintar_placas()
	reinicios += 1
	_cambiar(Fase.ACECHA)


func _quitar_aviso() -> void:
	if _aviso != null and is_instance_valid(_aviso):
		_aviso.cancelar()
	_aviso = null


func _temblar(intensidad: float) -> void:
	var fx: Variant = _mundo.get("_fx") if _mundo != null else null
	if fx is Vfx3D:
		(fx as Vfx3D).temblor(intensidad)


# ---------------------------------------------------------------------------------------------------------------------
#  Dibujo (primitivas: un jabalí con barda)
# ---------------------------------------------------------------------------------------------------------------------

func _caja(nombre: String, tam: Vector3, pos: Vector3, mat: Material, padre: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nombre
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	padre.add_child(mi)
	return mi


func _placa(nombre: String, mat: Material, padre: Node3D, partes: Array) -> void:
	var n := Node3D.new()
	n.name = nombre
	padre.add_child(n)
	for pt in partes:
		_caja(nombre + "_p", pt[0], pt[1], mat, n)
	_placas.append(n)


func _construir() -> void:
	_raiz = Node3D.new()
	_raiz.name = "Raiz"
	add_child(_raiz)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = COLOR_CERDA
	_mat.roughness = 1.0
	var oscuro := StandardMaterial3D.new()
	oscuro.albedo_color = COLOR_CERDA.darkened(0.35)
	oscuro.roughness = 1.0
	var cuero := StandardMaterial3D.new()
	cuero.albedo_color = COLOR_PLACA
	cuero.roughness = 0.9
	_caja("Lomo", Vector3(1.1, 0.9, 1.7), Vector3(0.0, 0.95, 0.0), _mat, _raiz)
	_caja("Cruz", Vector3(1.0, 0.35, 0.6), Vector3(0.0, 1.5, 0.45), _mat, _raiz)            # la joroba del jabalí
	for x in [-0.35, 0.35]:
		for z in [-0.55, 0.55]:
			_caja("Pata", Vector3(0.28, 0.55, 0.28), Vector3(x, 0.28, z), oscuro, _raiz)
	_cabeza = Node3D.new()
	_cabeza.name = "Cabeza"
	_cabeza.position = Vector3(0.0, 1.05, 0.95)
	_raiz.add_child(_cabeza)
	_caja("Testa", Vector3(0.8, 0.65, 0.7), Vector3(0.0, 0.0, 0.2), _mat, _cabeza)
	_caja("Hocico", Vector3(0.5, 0.35, 0.4), Vector3(0.0, -0.12, 0.65), oscuro, _cabeza)
	var colmillo := StandardMaterial3D.new()
	colmillo.albedo_color = Color(0.92, 0.9, 0.82)
	for x in [-0.22, 0.22]:
		var cm: MeshInstance3D = _caja("Colmillo", Vector3(0.08, 0.3, 0.08), Vector3(x, 0.05, 0.75), colmillo, _cabeza)
		cm.rotation.x = -0.5
	# La barda: tres placas de cuero (testuz, lomo, flancos), una por choque.
	_placa("PlacaTestuz", cuero, _cabeza, [[Vector3(0.86, 0.2, 0.55), Vector3(0.0, 0.36, 0.2)]])
	_placa("PlacaLomo", cuero, _raiz, [[Vector3(1.2, 0.14, 1.2), Vector3(0.0, 1.43, -0.15)]])
	_placa("PlacaFlancos", cuero, _raiz, [[Vector3(0.1, 0.65, 1.3), Vector3(-0.58, 0.95, 0.0)], [Vector3(0.1, 0.65, 1.3), Vector3(0.58, 0.95, 0.0)]])
	_cuerpo = CuerpoVerraco.new()
	_cuerpo.name = "Cuerpo"
	add_child(_cuerpo)
	_cuerpo.montar(self)


func _pintar_placas() -> void:
	for i in range(_placas.size()):
		_placas[i].visible = i >= placas_rotas


func _orientar() -> void:
	if dir.length() > 0.01:
		rotation.y = atan2(dir.x, dir.z)


func _animar(_delta: float) -> void:
	if _raiz == null:
		return
	var inclina: float = 0.0
	var cabeza_x: float = 0.0
	var sube: float = 0.0
	match fase:
		Fase.POSE:
			var k: float = clampf(_t / 0.15, 0.0, 1.0)
			inclina = 0.12 * k                              # se echa hacia delante…
			cabeza_x = 0.45 * k                             # …con la cabeza baja (C25: la pose se SOSTIENE)
			sube = -0.08 * k
		Fase.EMBISTE:
			inclina = 0.16
			cabeza_x = 0.4
			sube = absf(sin(_t * 22.0)) * 0.08              # galope
		Fase.ATURDIDO:
			cabeza_x = -0.2
			_raiz.rotation.z = 0.08 * sin(_t * 9.0)         # tambaleo
		Fase.MUERTO:
			return
	if fase != Fase.ATURDIDO:
		_raiz.rotation.z = 0.0
	_raiz.rotation.x = inclina
	_raiz.position.y = sube
	_cabeza.rotation.x = cabeza_x
	_mat.emission_enabled = _destello > 0.0
	_mat.emission = Color.WHITE
	_mat.emission_energy_multiplier = 2.0
