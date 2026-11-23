class_name DragonJefe3D
extends TrampaPared3D

## DRAGÓN JEFE · PLACEHOLDER (21/11/2026, Pablo; visto en Mages of Mystralia, docs/MAGES_OF_MYSTRALIA_2026-11-21.md O8 y O9). Banco de pruebas de las ideas de jefe:
##
## 1. PRESENTACIÓN (solo jefes). Dormido bajo el suelo hasta que la jugadora se acerca a `cerca` casillas. Entonces SE LEVANTA (SUBIDA_S), se le encienden los ojos y sale el
##    RÓTULO con epíteto y nombre (`PresentacionJefe`). La cámara no se mueve. Mientras dura el rótulo no ataca; al acabar aparece su barra de vida y empieza el combate.
##
## 2. ALIENTO CON ANTICIPACIÓN, QUE SE BLOQUEA CON UNA BARRERA. El ciclo es:
##      REPOSO (sigue a la jugadora con la cabeza)
##      → CARGA (CARGA_S): echa la cabeza atrás y abajo, GIRA HACIA EL LADO POR EL QUE VA A EMPEZAR, la boca se enciende y suena la carga;
##      → ANILLOS (ANILLOS_S): anillos que se abren a sus pies (el aviso en el suelo de Mystralia), la boca a tope;
##      → ALIENTO (ALIENTO_S): un chorro de fuego que BARRE un abanico de BARRIDO_GRADOS de un lado al otro (pasa por donde estaba la jugadora al empezar);
##      → RECUPERA (RECUPERA_S): cabeza caída; sus PUNTOS DÉBILES brillan más (es el momento de apuntarles).
##    El chorro es un HECHIZO REAL (el haz de fuego de siempre, como la trampa dragón): enciende, quema el suelo y SE CORTA EN LO SÓLIDO. A la jugadora la hiere el propio
##    dragón si está dentro del chorro, con la vía de siempre (invulnerabilidad, defensa y BURBUJA). Así se bloquea:
##      · una BARRERA (ᛜ) o un bloque de tierra entre la boca y la jugadora corta el chorro antes de llegar (`largo_aliento_u`); la barrera encaja DANO_BARRERA_TICK por soplo;
##      · la BURBUJA de barrera alrededor de la jugadora se come el golpe (`Jugador3D.recibir_dano`);
##      · o se esquiva moviéndose hacia el lado del que viene el barrido.
##    El AGUA mientras carga o sopla lo apaga y lo ATURDE (ATURDIDO_S). Es el sitio para la «barba que se apaga» del Ojáncano.
##
## 3. PUNTOS DÉBILES Y EXPOSICIÓN (O9). El cuerpo NO recibe daño. Tiene N_PUNTOS cristales (punta de cada ala y pecho) que cualquier hechizo enciende: cada uno se queda
##    ardiendo, así que se ve cuántos van. Con el último, CAE (CAE_S, temblor al tocar el suelo), apoya la cabeza en el carril y deja a la vista el NÚCLEO (la garganta
##    encendida) EXPUESTO_S s: solo ahí recibe daño, con un DESTELLO BLANCO de toda la silueta y un TIRÓN corto de cámara. Luego SE LEVANTA (LEVANTA_S, temblor), los
##    cristales se apagan y vuelve a empezar.
##
## 4. FEEDBACK DE CUERPO GRANDE (O9): temblor largo (`Vfx3D.temblor`) solo para lo que hace el cuerpo (caer, levantarse); tirón corto y silueta blanca al golpear el núcleo;
##    los golpes pequeños (cristales, cuerpo) no tiemblan.
##
## Dibujo: primitivas (cuerpo, patas, cola, alas, cuello, cabeza con cuernos y mandíbula). Es un placeholder: cuando haya modelo, se cambia `_construir`.
## En el mapa: `; pieza <id> dragon_jefe x y mira=s cerca=3.5 vida=300 nombre=Dragon epiteto=Guardian_del_foso` (x,y = casilla de SUELO donde está; `mira` = hacia el carril;
## nombre y epíteto sin tildes ni espacios: los «_» se leen como espacios). Señales para las reglas: `derrotado` (por defecto), `presentado`, `aliento`, `aturdido`, `expuesto`.
## Prueba: herramientas/escenario_dragon_jefe.gd · Sala: escenas/PruebaSalaDragon.tscn (mapas/SalaDragon.txt, un CARRIL de dos filas al pie del dragón).

signal presentado                  ## acabó la presentación: empieza el combate
signal carga_empieza               ## empieza la anticipación del aliento
signal aliento_empieza
signal aliento_termina
signal aturdido                    ## el agua le apagó el aliento
signal punto_encendido(n: int)     ## un cristal más encendido (n = cuántos van)
signal expuesto                    ## cayó: el núcleo está a tiro
signal se_levanta
signal derrotado

enum Fase { DORMIDO, PRESENTA, REPOSO, CARGA, ANILLOS, ALIENTO, RECUPERA, ATURDIDO, CAE, EXPUESTO, LEVANTA, MUERTO }

# --- Ajustes (static var: se tocan en vivo) ---
static var SUBIDA_S: float = 1.6             ## lo que tarda en salir del suelo
static var HUNDIDO_U: float = 3.4            ## lo que está metido bajo el suelo antes de salir
static var REPOSO_S: float = 2.2
static var CARGA_S: float = 0.9              ## cabeza atrás + boca que se enciende
static var ANILLOS_S: float = 0.8            ## anillos en el suelo
static var ALIENTO_S: float = 2.6            ## lo que dura el barrido
static var RECUPERA_S: float = 1.6
static var ATURDIDO_S: float = 3.0
static var BARRIDO_GRADOS: float = 110.0     ## abanico que barre
## A2 de PLAN_COMBATE (22/11, Pablo: «rectángulo parpadeante rojo y movimiento exagerado hacia atrás de la cabeza»): al empezar la carga sale un `AvisoAtaque3D` rectangular
## (el de los demás enemigos: da la voltereta perfecta y el tiempo bruja) que cubre lo que puede barrer, hasta que empieza el aliento (CARGA_S + ANILLOS_S).
static var AVISO_ALIENTO: bool = true
static var AVISO_PARPADEO_HZ: float = 4.0    ## parpadeos por segundo del rectángulo
static var RETROCESO_ATRAS_U: float = 0.75   ## lo que se echa el cuello hacia atrás (hacia el cuerpo) al cargar
static var RETROCESO_ALTO_U: float = 0.35    ## y hacia arriba
static var RETROCESO_GIRO: float = 0.6       ## rad que levanta la cabeza (contra el cabeceo hacia abajo)
static var RETROCESO_VUELTA: float = 9.0     ## 1/s: lo rápido que vuelve adelante al soltar el aliento (el latigazo)
static var GIRO_MAX_GRADOS: float = 70.0     ## lo más que gira la cabeza a cada lado
static var TICK_S: float = 0.2               ## un soplo (un haz) cada tanto
static var DANO_TICK: float = 8.0            ## a la jugadora, por soplo que la alcanza
static var DANO_BARRERA_TICK: float = 4.0    ## lo que encaja una barrera por soplo
static var LATERAL_U: float = 0.8            ## ancho del chorro a cada lado, junto a la boca
static var ABRE_POR_U: float = 0.10          ## lo que se ensancha por cada u de distancia
static var VIDA: float = 300.0
static var CAE_S: float = 0.8                ## de pie a tumbado (Mystralia: ~0,8 s)
static var EXPUESTO_S: float = 8.0           ## núcleo a tiro (Mystralia: 8–10 s)
static var LEVANTA_S: float = 0.7
static var MULT_NUCLEO: float = 1.5          ## daño en el núcleo
static var TEMBLOR_CUERPO: float = 0.6       ## intensidad de `Vfx3D.temblor` al caer y al levantarse (0,6 → 0,12 u, ≈2 % del alto con la cámara de tamaño 6)
static var TIRON_U: float = 0.06             ## lo que baja la cámara en el tirón del golpe al núcleo
static var SILUETA_S: float = 0.07           ## destello blanco de toda la silueta (Mystralia: 1–2 fotogramas a 30 fps)
static var SILUETA_FOTOGRAMAS: int = 2       ## y como mínimo estos fotogramas DIBUJADOS (con pocos fps, varios pasos de física caben en uno y se apagaba antes de verse)

const ALCANCE_DEFECTO: int = 6
const CERCA_DEFECTO: float = 3.5
const COLOR_ESCAMA_D: Color = Color(0.55, 0.12, 0.08)
const COLOR_VIENTRE_D: Color = Color(0.9, 0.45, 0.15)
const COLOR_CUERNO_D: Color = Color(0.2, 0.08, 0.06)
const COLOR_CRISTAL: Color = Color(0.72, 0.35, 1.0)        ## morado, como los cristales del árbol de Mystralia
const COLOR_NUCLEO: Color = Color(1.0, 0.72, 0.9)
const N_ANILLOS: int = 3
## Dónde van los cristales (local; +Z hacia el carril). La caja con la que reciben hechizos es una COLUMNA hasta el suelo (los proyectiles vuelan bajos) en esa x,z.
const PUNTOS: Array = [Vector3(-2.3, 2.0, 0.5), Vector3(0.0, 1.5, 1.25), Vector3(2.3, 2.0, 0.5)]
const CUELLO_BASE: Vector3 = Vector3(0.0, 1.55, 0.55)     ## donde nace el cuello (A2: el retroceso se suma a esto)
const NUCLEO_LOCAL: Vector3 = Vector3(0.0, 0.55, 2.0)      ## donde queda la garganta con la cabeza en el suelo

var fase: int = Fase.DORMIDO
var vida: float = VIDA
var vida_max: float = VIDA
var nombre: String = "Dragón"
var epiteto: String = "Guardián del foso"
var presentacion: PresentacionJefe = null
var puntos: Array = []                        ## los PuntoDebil

# --- Contadores (las pruebas los leen) ---
var alientos: int = 0
var soplos: int = 0
var golpes_jugadora: int = 0
var cortes_solido: int = 0                   ## soplos que alcanzaban a la jugadora pero los cortó algo sólido antes
var en_burbuja: int = 0                      ## soplos que llegaron a la jugadora estando en su burbuja
var impactos: int = 0                        ## hechizos que le han dado (cuerpo, cristales o núcleo)
var ultima_via: String = ""                  ## la vía (Materia.via) del último hechizo que le dio
var golpes_sin_efecto: int = 0               ## hechizos al cuerpo fuera de la exposición
var golpes_nucleo: int = 0
var exposiciones: int = 0
var temblores: int = 0
var tirones: int = 0
var ultimo_golpe: String = ""                ## cómo fue el último soplo que hirió a la jugadora (para las pruebas)

var _t: float = 0.0
var _a_ini: float = 0.0                      ## grados, respecto a `dir` (+ = a su izquierda)
var _a_fin: float = 0.0
var _lado: float = 1.0
var _yaw: float = 0.0                        ## giro de la cabeza (grados)
var _cabeceo: float = 0.0                    ## 0 = cabeza alta, 1 = echada atrás y abajo, ~2,2 = en el suelo
var _caido: float = 0.0                      ## 0 = de pie, 1 = tumbado
var _brillo_boca: float = 0.0
var _retroceso: float = 0.0                  ## A2: 0 = cuello en su sitio, 1 = echado atrás del todo (carga)
var _aviso: AvisoAtaque3D = null             ## A2: el aviso del aliento en curso
var avisos_aliento: int = 0                  ## A2: cuántos avisos ha sacado (para las pruebas)
var _ineficaz_avisado: bool = false          ## B2: ya avisó en este aliento de que una barrera no lo para
var _t_soplo: float = 0.0
var _destello: float = 0.0
var _silueta: float = 0.0
var _silueta_fotogramas: int = 0
var _temblo_caida: bool = false
var _hechizo: Hechizo = null

var _raiz: Node3D = null                     ## todo el dibujo (sube, baja y se inclina)
var _cuello: Node3D = null                   ## gira (yaw) y cabecea
var _cabeza: Node3D = null
var _mandibula: Node3D = null
var _boca: Node3D = null
var _bola_boca: MeshInstance3D = null
var _mat_boca: StandardMaterial3D = null
var _mat_ojos: StandardMaterial3D = null
var _mat_escama: StandardMaterial3D = null
var _mat_silueta: StandardMaterial3D = null
var _mallas: Array[MeshInstance3D] = []
var _anillos: Array[MeshInstance3D] = []
var _mat_anillos: Array[StandardMaterial3D] = []
var _nucleo: Nucleo = null


## Lo coloca DE PIE en la casilla de suelo `p_celda`, mirando a `p_mira`. Se llama antes de colgarlo del árbol.
func preparar_jefe(p_celda: Vector2i, p_mira: String, p_alcance: int, p_cerca: float, p_vida: float, p_nombre: String, p_epiteto: String, p_mundo: Node = null) -> void:
	preparar(p_celda, p_mira, "fuego", p_alcance, p_mundo)
	var suelo: float = Terreno3D.y_pies(celda) if Terreno3D.hay_mundo() and Terreno3D.en_mapa(celda) else Terreno3D.alto_suelo
	position = Terreno3D.centro_de(celda, suelo)
	cerca = p_cerca
	vida_max = maxf(p_vida, 1.0)
	vida = vida_max
	if p_nombre != "":
		nombre = p_nombre.replace("_", " ")
	if p_epiteto != "":
		epiteto = p_epiteto.replace("_", " ")
	apaga_con_agua = false            # el agua no lo apaga como a una trampa: lo aturde (ver on_spell_hit)
	if Terreno3D.hay_mundo():
		Terreno3D.bloquear_celda(celda)


func prof_cuerpo() -> float:
	return 1.2


func boca_local() -> Vector3:
	if _boca != null and is_inside_tree():
		return to_local(_boca.global_position)
	return Vector3(0.0, 1.5, 2.0)


# ---------------------------------------------------------------------------------------------------------------------
#  Cristales (puntos débiles) y núcleo: piezas que reciben hechizos por su cuenta
# ---------------------------------------------------------------------------------------------------------------------

## Un cristal del cuerpo. Cualquier hechizo lo enciende mientras el dragón está en pie y peleando; encendido, arde hasta que el dragón se levanta.
class PuntoDebil extends Area3D:
	var dragon: DragonJefe3D = null
	var encendido: bool = false
	var _cristal: MeshInstance3D = null
	var _llama: MeshInstance3D = null
	var _mat: StandardMaterial3D = null
	var _mat_llama: StandardMaterial3D = null
	var _t: float = 0.0

	func montar(d: DragonJefe3D, alto: float) -> void:
		dragon = d
		monitoring = false
		monitorable = true
		collision_mask = 0
		collision_layer = Lanzador3D.CAPA_REACTIVO
		var forma := CollisionShape3D.new()
		var caja := BoxShape3D.new()
		caja.size = Vector3(1.0, 3.2, 1.0)
		forma.shape = caja
		forma.position = Vector3(0.0, 1.6 - alto, 0.0)          # columna desde el suelo: los proyectiles vuelan bajos
		add_child(forma)
		_mat = StandardMaterial3D.new()
		_mat.albedo_color = DragonJefe3D.COLOR_CRISTAL
		_mat.emission_enabled = true
		_mat.emission = DragonJefe3D.COLOR_CRISTAL
		_mat.emission_energy_multiplier = 1.5
		_cristal = MeshInstance3D.new()
		_cristal.name = "Cristal"
		var pm := PrismMesh.new()
		pm.size = Vector3(0.36, 0.55, 0.36)
		_cristal.mesh = pm
		_cristal.material_override = _mat
		add_child(_cristal)
		_mat_llama = StandardMaterial3D.new()
		_mat_llama.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_llama.albedo_color = TrampaPared3D.COLOR_BRASA_VIVA
		_llama = MeshInstance3D.new()
		_llama.name = "Llama"
		var s := SphereMesh.new()
		s.radius = 0.2
		s.height = 0.5
		_llama.mesh = s
		_llama.material_override = _mat_llama
		_llama.position = Vector3(0.0, 0.42, 0.0)
		_llama.visible = false
		add_child(_llama)

	func on_spell_hit(rune_data: RuneData, direccion: Vector3 = Vector3.ZERO, hechizo: Hechizo = null) -> void:
		if dragon == null:
			return
		dragon.on_spell_hit(rune_data, direccion, hechizo)       # el agua también aturde aunque dé en un cristal
		if not encendido and dragon.puntos_activos():
			encender()

	func spell_reacts(_r: RuneData, _d: Vector3 = Vector3.ZERO, _h: Hechizo = null) -> bool:
		return dragon != null and dragon.puntos_activos()

	func carried_element() -> RuneData:
		return null

	func encender() -> void:
		if encendido:
			return
		encendido = true
		_mat.albedo_color = TrampaPared3D.COLOR_BRASA
		_mat.emission = TrampaPared3D.COLOR_BRASA
		_llama.visible = true
		dragon._al_encender_punto()

	func apagar_punto() -> void:
		encendido = false
		_mat.albedo_color = DragonJefe3D.COLOR_CRISTAL
		_mat.emission = DragonJefe3D.COLOR_CRISTAL
		_llama.visible = false

	## `invita` = el dragón está en la ventana de recuperación: brilla más.
	func animar(delta: float, invita: bool) -> void:
		_t += delta
		# Solo recibe hechizos cuando se puede encender: tumbado, el cuerpo se inclina y su columna taparía el núcleo.
		var activo: bool = dragon != null and dragon.puntos_activos()
		collision_layer = Lanzador3D.CAPA_REACTIVO if activo else 0
		monitorable = activo
		if encendido:
			_llama.scale = Vector3(1.0, 1.0 + 0.25 * sin(_t * 14.0), 1.0)
			_mat.emission_energy_multiplier = 2.0
		else:
			_mat.emission_energy_multiplier = (2.5 + 1.5 * sin(_t * 8.0)) if invita else 1.2


## La garganta: solo existe (recibe y se ve) mientras está EXPUESTO.
class Nucleo extends Area3D:
	var dragon: DragonJefe3D = null
	var _bola: MeshInstance3D = null
	var _mat: StandardMaterial3D = null
	var _t: float = 0.0

	func montar(d: DragonJefe3D) -> void:
		dragon = d
		monitoring = false
		monitorable = false
		collision_mask = 0
		collision_layer = 0
		# Columna desde el suelo, como los cristales: los proyectiles vuelan a alturas distintas (la bola de fuego, alta) y una esfera a ras de suelo no la cazaba.
		var forma := CollisionShape3D.new()
		var caja := BoxShape3D.new()
		caja.size = Vector3(1.4, 3.2, 1.4)
		forma.shape = caja
		forma.position = Vector3(0.0, 1.6 - DragonJefe3D.NUCLEO_LOCAL.y, 0.0)
		add_child(forma)
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.albedo_color = DragonJefe3D.COLOR_NUCLEO
		_bola = MeshInstance3D.new()
		_bola.name = "Nucleo"
		var s := SphereMesh.new()
		s.radius = 0.38
		s.height = 0.76
		_bola.mesh = s
		_bola.material_override = _mat
		_bola.visible = false
		add_child(_bola)

	func activar(si: bool) -> void:
		monitorable = si
		collision_layer = Lanzador3D.CAPA_REACTIVO if si else 0
		_bola.visible = si

	func activo() -> bool:
		return collision_layer != 0

	func on_spell_hit(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO, hechizo: Hechizo = null) -> void:
		if dragon != null and activo():
			dragon.golpe_nucleo(rune_data, hechizo)

	func spell_reacts(_r: RuneData, _d: Vector3 = Vector3.ZERO, _h: Hechizo = null) -> bool:
		return dragon != null and activo()

	func carried_element() -> RuneData:
		return null

	func animar(delta: float) -> void:
		_t += delta
		_bola.scale = Vector3.ONE * (1.0 + 0.12 * sin(_t * 6.0))


# ---------------------------------------------------------------------------------------------------------------------
#  Dibujo (primitivas)
# ---------------------------------------------------------------------------------------------------------------------

func _construir() -> void:
	# La caja pequeña de la base (la de las trampas) se apaga: el cuerpo tiene la suya y los cristales las suyas.
	for h in get_children():
		if h is CollisionShape3D:
			(h as CollisionShape3D).disabled = true
	_mat_escama = _material(COLOR_ESCAMA_D)
	var vientre: StandardMaterial3D = _material(COLOR_VIENTRE_D)
	var cuerno: StandardMaterial3D = _material(COLOR_CUERNO_D)
	_raiz = Node3D.new()
	_raiz.name = "Dragon"
	add_child(_raiz)
	# Cuerpo, patas y cola.
	var cuerpo: MeshInstance3D = _esfera("Cuerpo", 1.0, Vector3(0.0, 1.15, -0.4), _mat_escama, _raiz)
	cuerpo.scale = Vector3(1.15, 0.85, 1.3)
	var panza: MeshInstance3D = _esfera("Panza", 0.8, Vector3(0.0, 0.95, -0.15), vientre, _raiz)
	panza.scale = Vector3(1.0, 0.75, 1.15)
	for lado in [-1.0, 1.0]:
		for frente in [0.35, -1.05]:
			_caja("Pata", Vector3(0.36, 0.8, 0.42), Vector3(0.75 * lado, 0.4, frente), _mat_escama, _raiz)
	var cola: Node3D = Node3D.new()
	cola.name = "Cola"
	cola.position = Vector3(0.0, 0.9, -1.6)
	_raiz.add_child(cola)
	for i in range(4):
		_esfera("ColaSeg%d" % i, 0.32 - 0.06 * float(i), Vector3(0.0, -0.12 * float(i), -0.42 * float(i)), _mat_escama, cola)
	# Alas abiertas hacia los lados: en sus puntas van los cristales de los lados.
	for lado in [-1.0, 1.0]:
		var ala: MeshInstance3D = _caja("Ala", Vector3(1.9, 0.08, 1.1), Vector3(1.35 * lado, 1.85, 0.0), vientre, _raiz)
		ala.rotation = Vector3(0.0, 0.0, 0.35 * lado)
	# Cuello: gira de lado a lado (yaw) y cabecea. Lleva la cabeza en la punta.
	_cuello = Node3D.new()
	_cuello.name = "Cuello"
	_cuello.position = CUELLO_BASE
	_raiz.add_child(_cuello)
	for i in range(3):
		_esfera("CuelloSeg%d" % i, 0.34 - 0.04 * float(i), Vector3(0.0, 0.1 * float(i), 0.32 * float(i)), _mat_escama if i % 2 == 0 else vientre, _cuello)
	_cabeza = Node3D.new()
	_cabeza.name = "Cabeza"
	_cabeza.position = Vector3(0.0, 0.25, 1.05)
	_cuello.add_child(_cabeza)
	_caja("Craneo", Vector3(0.7, 0.46, 0.7), Vector3.ZERO, _mat_escama, _cabeza)
	_caja("Hocico", Vector3(0.48, 0.3, 0.5), Vector3(0.0, -0.05, 0.55), _mat_escama, _cabeza)
	for lado in [-1.0, 1.0]:
		var c: MeshInstance3D = _caja("Cuerno", Vector3(0.12, 0.12, 0.6), Vector3(0.3 * lado, 0.3, -0.3), cuerno, _cabeza)
		c.rotation = Vector3(-0.6, -0.45 * lado, 0.0)
	_mat_ojos = _material(COLOR_BRASA_VIVA, 0.0, true)
	_mat_ojos.albedo_color = Color(0.15, 0.06, 0.03)
	_esfera("OjoIzq", 0.08, Vector3(-0.3, 0.14, 0.24), _mat_ojos, _cabeza)
	_esfera("OjoDer", 0.08, Vector3(0.3, 0.14, 0.24), _mat_ojos, _cabeza)
	_mandibula = Node3D.new()
	_mandibula.name = "Mandibula"
	_mandibula.position = Vector3(0.0, -0.2, 0.0)
	_cabeza.add_child(_mandibula)
	_caja("MandibulaHueso", Vector3(0.44, 0.1, 0.8), Vector3(0.0, -0.04, 0.42), vientre, _mandibula)
	# La boca: de aquí sale el chorro, y aquí se enciende la bola de la carga.
	_boca = Node3D.new()
	_boca.name = "Boca"
	_boca.position = Vector3(0.0, -0.1, 0.85)
	_cabeza.add_child(_boca)
	_mat_boca = _material(COLOR_BRASA, 3.0, true)
	_mat_boca.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bola_boca = _esfera("BolaBoca", 0.22, Vector3.ZERO, _mat_boca, _boca)
	_bola_boca.visible = false
	# Anillos del aviso, a sus pies (no suben ni bajan con el cuerpo: van en el suelo).
	for i in range(N_ANILLOS):
		var mi := MeshInstance3D.new()
		mi.name = "Anillo%d" % i
		var t := TorusMesh.new()
		t.inner_radius = 0.92
		t.outer_radius = 1.0
		t.rings = 32
		t.ring_segments = 6
		mi.mesh = t
		var m := _material(COLOR_BRASA_VIVA, 1.5, true)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = m
		mi.position = Vector3(0.0, 0.06, 0.6)
		mi.scale = Vector3(1.0, 0.15, 1.0)
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_anillos.append(mi)
		_mat_anillos.append(m)
	# Caja del cuerpo: recibe los hechizos que le dan (no le hacen daño fuera de la exposición).
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(2.4, 2.4, 2.6)
	forma.shape = caja
	forma.position = Vector3(0.0, 1.2, -0.4)
	add_child(forma)
	# Cristales y núcleo.
	for p in PUNTOS:
		var pd := PuntoDebil.new()
		pd.name = "Cristal%d" % puntos.size()
		pd.position = p
		_raiz.add_child(pd)
		pd.montar(self, (p as Vector3).y)
		puntos.append(pd)
	_nucleo = Nucleo.new()
	_nucleo.name = "Nucleo"
	_nucleo.position = NUCLEO_LOCAL
	add_child(_nucleo)
	_nucleo.montar(self)
	# Material de la silueta blanca (se pone encima de todas las mallas del cuerpo un instante).
	_mat_silueta = StandardMaterial3D.new()
	_mat_silueta.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_silueta.albedo_color = Color(1.0, 1.0, 1.0)
	_juntar_mallas(_raiz)
	_raiz.position.y = -HUNDIDO_U
	_raiz.visible = false


func _juntar_mallas(n: Node) -> void:
	for h in n.get_children():
		if h is PuntoDebil:
			continue
		if h is MeshInstance3D:
			_mallas.append(h)
		_juntar_mallas(h)


# ---------------------------------------------------------------------------------------------------------------------
#  Marcha
# ---------------------------------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t += delta
	_destello = maxf(_destello - delta, 0.0)
	match fase:
		Fase.DORMIDO:
			if _jugadora_cerca():
				empezar_presentacion()
		Fase.PRESENTA:
			_raiz.position.y = lerpf(-HUNDIDO_U, 0.0, _ease(minf(_t / SUBIDA_S, 1.0)))
			if _t >= SUBIDA_S + PresentacionJefe.duracion_titulo():
				_terminar_presentacion()
		Fase.REPOSO:
			_yaw = move_toward(_yaw, _angulo_a_jugadora(), 60.0 * delta)
			_cabeceo = move_toward(_cabeceo, 0.0, 2.0 * delta)
			_brillo_boca = move_toward(_brillo_boca, 0.0, 2.0 * delta)
			if _t >= REPOSO_S:
				_empezar_carga()
		Fase.CARGA:
			var k: float = minf(_t / CARGA_S, 1.0)
			_yaw = lerpf(_yaw, _a_ini, minf(1.0, 6.0 * delta))
			_cabeceo = _ease(k)
			_retroceso = _ease(k)
			_brillo_boca = k * 0.8
			if _t >= CARGA_S:
				_cambiar(Fase.ANILLOS)
		Fase.ANILLOS:
			_retroceso = 1.0 + 0.04 * sin(_t * 40.0)          # tenso, temblando, a punto de soltar
			_brillo_boca = 0.8 + 0.2 * sin(_t * 30.0)
			if _t >= ANILLOS_S:
				_cambiar(Fase.ALIENTO)
				_t_soplo = 0.0
				alientos += 1
				aliento_empieza.emit()
		Fase.ALIENTO:
			_yaw = lerpf(_a_ini, _a_fin, smoothstep(0.0, 1.0, minf(_t / ALIENTO_S, 1.0)))
			_cabeceo = 0.35
			_brillo_boca = 1.0
			_t_soplo -= delta
			if _t_soplo <= 0.0:
				_t_soplo += TICK_S
				_soplo()
			if _t >= ALIENTO_S:
				aliento_termina.emit()
				_cambiar(Fase.RECUPERA)
		Fase.RECUPERA, Fase.ATURDIDO:
			_cabeceo = move_toward(_cabeceo, 1.3, 3.0 * delta)
			_brillo_boca = move_toward(_brillo_boca, 0.0, 3.0 * delta)
			if _t >= (RECUPERA_S if fase == Fase.RECUPERA else ATURDIDO_S):
				_cambiar(Fase.REPOSO)
		Fase.CAE:
			_caido = _ease(minf(_t / CAE_S, 1.0))
			_yaw = move_toward(_yaw, 0.0, 120.0 * delta)
			_cabeceo = lerpf(_cabeceo, 2.2, minf(1.0, 5.0 * delta))
			_brillo_boca = 0.0
			if not _temblo_caida and _t >= CAE_S * 0.85:
				_temblo_caida = true
				_temblar(TEMBLOR_CUERPO)                     # el cuerpo toca el suelo
			if _t >= CAE_S:
				_cambiar(Fase.EXPUESTO)
				_nucleo.activar(true)
				exposiciones += 1
				expuesto.emit()
		Fase.EXPUESTO:
			_caido = 1.0
			_cabeceo = 2.2
			if _t >= EXPUESTO_S:
				_nucleo.activar(false)
				_cambiar(Fase.LEVANTA)
				_temblar(TEMBLOR_CUERPO)                     # se levanta
				se_levanta.emit()
		Fase.LEVANTA:
			_caido = 1.0 - _ease(minf(_t / LEVANTA_S, 1.0))
			_cabeceo = lerpf(2.2, 0.0, minf(_t / LEVANTA_S, 1.0))
			if _t >= LEVANTA_S:
				for p in puntos:
					(p as PuntoDebil).apagar_punto()
				_cambiar(Fase.REPOSO)
		Fase.MUERTO:
			_raiz.position.y = lerpf(0.0, -HUNDIDO_U, _ease(minf(_t / 2.0, 1.0)))
	if fase != Fase.CARGA and fase != Fase.ANILLOS:
		_retroceso = move_toward(_retroceso, 0.0, RETROCESO_VUELTA * delta)     # A2: al soltar, el cuello vuelve de golpe (latigazo)
	for p in puntos:
		(p as PuntoDebil).animar(delta, fase == Fase.RECUPERA or fase == Fase.ATURDIDO)
	if _nucleo != null:
		_nucleo.animar(delta)
	_animar(delta)


func _cambiar(nueva: int) -> void:
	fase = nueva
	_t = 0.0
	if not (nueva in [Fase.CARGA, Fase.ANILLOS, Fase.ALIENTO]):
		_quitar_aviso()                              # A2: aturdido, caído o muerto: el aliento ya no llega


## A2: el aviso del aliento. Rectángulo desde el dragón hacia el carril: tan largo como el alcance y tan ancho como lo que barre la cabeza en su giro máximo.
func _avisar_aliento() -> void:
	_quitar_aviso()
	if not AVISO_ALIENTO or not is_inside_tree() or get_parent() == null:
		return
	var largo: float = float(alcance) * Terreno3D.casilla
	var ancho: float = largo * sin(deg_to_rad(GIRO_MAX_GRADOS))
	_aviso = AvisoAtaque3D.rectangulo(get_parent(), global_position, dir, largo, ancho, CARGA_S + ANILLOS_S, self, 0.0)
	_aviso.parpadeo = AVISO_PARPADEO_HZ
	avisos_aliento += 1


func _quitar_aviso() -> void:
	if _aviso != null and is_instance_valid(_aviso):
		_aviso.cancelar()
	_aviso = null


## G1 de PLAN_COMBATE (22/11, morir y reintentar): la jugadora reapareció. Si el combate había empezado y no estaba vencido, el dragón vuelve a dormir bajo el suelo con la
## vida llena y los cristales apagados; al acercarse otra vez se presenta de nuevo, como la primera vez. Vencido, se queda vencido.
var reinicios: int = 0

func reiniciar() -> void:
	if fase == Fase.DORMIDO or fase == Fase.MUERTO:
		return
	_quitar_aviso()
	vida = vida_max
	for p in puntos:
		(p as PuntoDebil).apagar_punto()
	if _nucleo != null:
		_nucleo.activar(false)
	_caido = 0.0
	_cabeceo = 0.0
	_retroceso = 0.0
	_brillo_boca = 0.0
	_yaw = 0.0
	if presentacion != null and is_instance_valid(presentacion):
		presentacion.queue_free()
	presentacion = null
	_cambiar(Fase.DORMIDO)
	_raiz.visible = false
	_raiz.position.y = -HUNDIDO_U
	_raiz.rotation.x = 0.0
	if _mat_ojos != null:
		_mat_ojos.emission_enabled = false
	reinicios += 1
	PlayLog.event("dragon_reiniciado", {})


## A2 (para las pruebas): el aviso del aliento vivo, o null.
func aviso_aliento() -> AvisoAtaque3D:
	return _aviso if _aviso != null and is_instance_valid(_aviso) and not _aviso.cancelado else null


func _jugadora_cerca() -> bool:
	var j: Node3D = jugadora()
	if j == null:
		return false
	return Vector2(Terreno3D.celda_de(j.global_position) - celda).length() <= cerca


## Empieza la presentación (la llama la cercanía, o una prueba).
func empezar_presentacion() -> void:
	if fase != Fase.DORMIDO:
		return
	_cambiar(Fase.PRESENTA)
	_raiz.visible = true
	_mat_ojos.emission_enabled = true
	_mat_ojos.emission = COLOR_BRASA_VIVA
	_mat_ojos.emission_energy_multiplier = 0.0
	if is_inside_tree():
		Sfx.play(self, "fuego_carga")
		presentacion = PresentacionJefe.crear(self, epiteto, nombre)
		get_tree().create_timer(SUBIDA_S * 0.6, false).timeout.connect(_al_asomar)


func _al_asomar() -> void:
	if presentacion != null and is_instance_valid(presentacion):
		presentacion.mostrar_titulo()


func _terminar_presentacion() -> void:
	_raiz.position.y = 0.0
	if presentacion != null and is_instance_valid(presentacion):
		presentacion.mostrar_barra()
		presentacion.fijar_vida(vida / vida_max)
	_cambiar(Fase.REPOSO)
	presentado.emit()


func _empezar_carga() -> void:
	var centro: float = clampf(_angulo_a_jugadora(), -GIRO_MAX_GRADOS + BARRIDO_GRADOS * 0.5, GIRO_MAX_GRADOS - BARRIDO_GRADOS * 0.5)
	_lado = -_lado                                # alterna el lado por el que empieza: la jugadora tiene que mirar la cabeza
	_a_ini = centro - _lado * BARRIDO_GRADOS * 0.5
	_a_fin = centro + _lado * BARRIDO_GRADOS * 0.5
	_cambiar(Fase.CARGA)
	_ineficaz_avisado = false
	_avisar_aliento()
	carga_empieza.emit()
	if is_inside_tree():
		Sfx.play(self, "fuego_carga")


## Grados de la jugadora respecto a `dir` (+ = a su izquierda), recortado al giro máximo.
func _angulo_a_jugadora() -> float:
	var j: Node3D = jugadora()
	if j == null:
		return 0.0
	var rel: Vector3 = j.global_position - global_position
	rel.y = 0.0
	if rel.length() < 0.01:
		return 0.0
	var a: float = rad_to_deg(dir.signed_angle_to(rel.normalized(), Vector3.UP))
	return clampf(a, -GIRO_MAX_GRADOS, GIRO_MAX_GRADOS)


## Hacia dónde sopla ahora (mundo, horizontal).
func dir_aliento() -> Vector3:
	return dir.rotated(Vector3.UP, deg_to_rad(_yaw)).normalized()


func origen_aliento() -> Vector3:
	var b: Vector3 = _boca.global_position if _boca != null and is_inside_tree() else global_position + dir * 2.0 + Vector3(0.0, 1.5, 0.0)
	return b - dir_aliento() * HechizoVivo.HAZ_BOCA_U


## Un soplo: un haz de fuego real en la dirección de ahora, y la herida a la jugadora si el chorro la alcanza.
func _soplo() -> void:
	var o: Vector3 = origen_aliento()
	var d: Vector3 = dir_aliento()
	var largo: float = largo_aliento_u(o, d)
	if _hechizo == null:
		_hechizo = construir_hechizo({"linea_x": clampi(alcance - 2, 1, 4)})
	if _hechizo != null:
		var h: Hechizo = _hechizo.copiar()
		h.set_meta(VfxToyJuego.META_RITMO_NACER, TrampaDragon3D.RITMO_LLAMAS)
		lanzar_hechizo_vivo(h, o, d)
	soplos += 1
	var j: Node3D = jugadora()
	if j == null:
		return
	var a: float = _a_lo_largo(o, d, j.global_position)
	if not _en_abanico(o, d, j.global_position, a):
		return
	if a > largo:
		cortes_solido += 1                       # estaba en el chorro, pero algo sólido lo cortó antes
		return
	var l: Lanzador3D = lanzador()
	if l != null and l.burbuja_contiene(j.global_position + Vector3(0.0, 0.8, 0.0)):
		en_burbuja += 1
	if herir_jugadora(DANO_TICK, o):
		golpes_jugadora += 1
		ultimo_golpe = "boca %s (casilla %s), yaw %.0f°, largo %.2f u, jugadora a %.2f u en %s" % [str(o.snapped(Vector3.ONE * 0.01)), str(Terreno3D.celda_de(o)), _yaw, largo, a, str(Terreno3D.celda_de(j.global_position))]


func _a_lo_largo(o: Vector3, d: Vector3, p: Vector3) -> float:
	var rel: Vector3 = p - o
	rel.y = 0.0
	return rel.dot(d)


func _en_abanico(o: Vector3, d: Vector3, p: Vector3, a: float) -> bool:
	if a < 0.0 or a > float(alcance) * Terreno3D.casilla:
		return false
	var rel: Vector3 = p - o
	rel.y = 0.0
	var lado: float = absf(rel.dot(Vector3(-d.z, 0.0, d.x)))
	return lado <= LATERAL_U + a * ABRE_POR_U


## Hasta dónde llega el chorro (u desde el origen): el alcance, cortado por la primera casilla sólida o la primera barrera viva (que encaja DANO_BARRERA_TICK).
func largo_aliento_u(o: Vector3, d: Vector3) -> float:
	var maximo: float = float(alcance) * Terreno3D.casilla
	var paso: float = Terreno3D.casilla * 0.25
	var l: Lanzador3D = lanzador()
	var s: float = paso
	while s <= maximo:
		var p: Vector3 = o + d * s
		var c: Vector2i = Terreno3D.celda_de(p)
		if c != celda:
			if Terreno3D.hay_mundo() and Terreno3D.celda_solida(c, 0):
				return s
			# B2 de PLAN_COMBATE (22/11, C19): la barrera corta el chorro según su elemento (`Contacto`): la de fuego no protege (el fuego no para el fuego), la de agua lo apaga
			# en vapor y se gasta más, la de tierra lo para.
			var q: Vector3 = Vector3(p.x, Terreno3D.y_pies(c) + 0.8, p.z)
			var sol: Lanzador3D.SolidezV2 = l.solidez_en(q) if l != null else null
			if sol != null:
				var acc: String = Contacto.accion(sol.elemento, "fuego")
				Contacto._anotar(sol.elemento, "fuego", acc)
				if Contacto.protege(acc):
					sol.golpe(Contacto.gasto(acc, DANO_BARRERA_TICK))
					return s
				if not _ineficaz_avisado:
					_ineficaz_avisado = true
					Contacto.avisar_ineficaz(sol.elemento, "fuego", q, get_parent())
		s += paso
	return maximo


# ---------------------------------------------------------------------------------------------------------------------
#  Recibir hechizos
# ---------------------------------------------------------------------------------------------------------------------

## Al cuerpo (o a un cristal, que lo reenvía): NO hace daño. El agua mientras carga o sopla lo aturde.
func on_spell_hit(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO, hechizo: Hechizo = null) -> void:
	if _lanzando or fase in [Fase.DORMIDO, Fase.PRESENTA, Fase.MUERTO]:
		return
	var via: String = Materia.via(Materia.de(hechizo if hechizo != null else rune_data))
	impactos += 1
	ultima_via = via
	if (via == "agua" or via == "hielo") and fase in [Fase.CARGA, Fase.ANILLOS, Fase.ALIENTO]:
		_aturdir()
	golpes_sin_efecto += 1
	_destello = 0.06                              # un parpadeo pequeño: le ha dado, pero no le duele


func spell_reacts(_rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO, _hechizo: Hechizo = null) -> bool:
	return not _lanzando and not (fase in [Fase.DORMIDO, Fase.PRESENTA, Fase.MUERTO])


## ¿Se pueden encender cristales ahora? (en pie y peleando)
func puntos_activos() -> bool:
	return fase in [Fase.REPOSO, Fase.CARGA, Fase.ANILLOS, Fase.ALIENTO, Fase.RECUPERA, Fase.ATURDIDO]


func puntos_encendidos() -> int:
	var n: int = 0
	for p in puntos:
		if (p as PuntoDebil).encendido:
			n += 1
	return n


## Lo llama un cristal al encenderse. Con todos encendidos, cae.
func _al_encender_punto() -> void:
	var n: int = puntos_encendidos()
	punto_encendido.emit(n)
	if n >= puntos.size() and puntos_activos():
		_caer()


func _caer() -> void:
	if fase == Fase.ALIENTO:
		aliento_termina.emit()
	_temblo_caida = false
	_cambiar(Fase.CAE)


## Un hechizo en el núcleo expuesto: el único daño que recibe.
func golpe_nucleo(rune_data: RuneData, hechizo: Hechizo) -> void:
	if fase != Fase.EXPUESTO:
		return
	var d: float = hechizo.dano if hechizo != null else 0.0
	if d <= 0.0 and rune_data != null and rune_data.get("damage") != null:
		d = float(rune_data.get("damage"))
	impactos += 1
	golpes_nucleo += 1
	_silueta = SILUETA_S
	_silueta_fotogramas = SILUETA_FOTOGRAMAS
	_tiron()
	recibir(d * MULT_NUCLEO)


## El agua le apaga el aliento: cabeza caída ATURDIDO_S.
func _aturdir() -> void:
	if fase == Fase.ALIENTO:
		aliento_termina.emit()
	_cambiar(Fase.ATURDIDO)
	aturdido.emit()


func recibir(d: float) -> void:
	if d <= 0.0 or fase == Fase.MUERTO:
		return
	vida = maxf(vida - d, 0.0)
	_destello = 0.12
	if presentacion != null and is_instance_valid(presentacion):
		presentacion.fijar_vida(vida / vida_max)
	if vida <= 0.0:
		_morir()


func _morir() -> void:
	if fase == Fase.ALIENTO:
		aliento_termina.emit()
	_cambiar(Fase.MUERTO)
	if _nucleo != null:
		_nucleo.activar(false)
	if presentacion != null and is_instance_valid(presentacion):
		presentacion.ocultar_barra()
	if Terreno3D.hay_mundo():
		Terreno3D.liberar_celda(celda)
	derrotado.emit()


# ---------------------------------------------------------------------------------------------------------------------
#  Feedback de cuerpo grande
# ---------------------------------------------------------------------------------------------------------------------

## Temblor largo de cámara (`Vfx3D.temblor`, ~0,33 s): solo para lo que hace el cuerpo (caer, levantarse).
func _temblar(intensidad: float) -> void:
	temblores += 1
	var fx: Variant = _mundo.get("_fx") if _mundo != null else null
	if fx is Vfx3D:
		(fx as Vfx3D).temblor(intensidad)


## Tirón corto de cámara (baja TIRON_U y vuelve) al golpear el núcleo. Si hay un temblor en marcha, no se pisa con él.
func _tiron() -> void:
	tirones += 1
	if not is_inside_tree():
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null or cam.has_meta("temblor_base"):
		return
	var v0: float = cam.v_offset
	var tw := cam.create_tween()
	tw.tween_property(cam, "v_offset", v0 - TIRON_U, 0.04)
	tw.tween_property(cam, "v_offset", v0, 0.08)


# ---------------------------------------------------------------------------------------------------------------------
#  Animación
# ---------------------------------------------------------------------------------------------------------------------

func _animar(delta: float) -> void:
	if _cuello == null:
		return
	var respira: float = sin(_t_vivo() * 1.6) * 0.03
	_cuello.rotation = Vector3(-0.15 + 0.45 * _cabeceo - RETROCESO_GIRO * _retroceso + respira, deg_to_rad(_yaw), 0.0)
	_cuello.position = CUELLO_BASE + Vector3(0.0, RETROCESO_ALTO_U, -RETROCESO_ATRAS_U) * _retroceso
	_mandibula.rotation.x = 0.55 * _brillo_boca
	_bola_boca.visible = _brillo_boca > 0.02
	_bola_boca.scale = Vector3.ONE * (0.4 + 0.9 * _brillo_boca)
	_mat_boca.albedo_color.a = clampf(_brillo_boca, 0.0, 1.0)
	_luz.light_energy = 2.5 * _brillo_boca
	_luz.position = boca_local()
	# Tumbado: el cuerpo baja y se inclina hacia el carril.
	if fase != Fase.PRESENTA and fase != Fase.DORMIDO and fase != Fase.MUERTO:
		_raiz.position.y = -0.55 * _caido
	_raiz.rotation.x = 0.28 * _caido
	var ojos: float = 0.0
	match fase:
		Fase.PRESENTA:
			ojos = clampf((_t - SUBIDA_S * 0.6) / 0.5, 0.0, 1.0) * 3.0
		Fase.ATURDIDO:
			ojos = 0.6 + 0.6 * sin(_t * 18.0)
		Fase.CAE, Fase.EXPUESTO:
			ojos = 0.4
		Fase.DORMIDO, Fase.MUERTO:
			ojos = 0.0
		_:
			ojos = 3.0
	if _mat_ojos.emission_enabled:
		_mat_ojos.emission_energy_multiplier = ojos
	_mat_escama.emission_enabled = _destello > 0.0
	_mat_escama.emission = Color(1.0, 0.9, 0.8)
	_mat_escama.emission_energy_multiplier = 2.0
	# Anillos: solo en la fase de anillos, escalonados, se abren y se apagan.
	for i in range(_anillos.size()):
		var k: float = -1.0
		if fase == Fase.ANILLOS:
			k = (_t - float(i) * ANILLOS_S * 0.25) / (ANILLOS_S * 0.6)
		var ver: bool = k > 0.0 and k < 1.0
		_anillos[i].visible = ver
		if ver:
			var r: float = lerpf(0.8, 3.4, k)
			_anillos[i].scale = Vector3(r, 0.15, r)
			_mat_anillos[i].albedo_color.a = (1.0 - k) * 0.85


## La silueta blanca va por fotogramas DIBUJADOS: dura SILUETA_S y, como mínimo, SILUETA_FOTOGRAMAS fotogramas, aunque el juego vaya lento.
## Se cambia el material de cada pieza por el blanco y luego se devuelve el suyo (`material_overlay` no se pintaba en esta escena: medido con fotos el 21/11).
var _blanca_puesta: bool = false
var _mats_originales: Array = []

func _process(delta: float) -> void:
	var blanca: bool = _silueta > 0.0 or _silueta_fotogramas > 0
	_silueta = maxf(_silueta - delta, 0.0)
	_silueta_fotogramas = maxi(_silueta_fotogramas - 1, 0)
	if blanca == _blanca_puesta:
		return
	_blanca_puesta = blanca
	if blanca:
		_mats_originales.clear()
		for m in _mallas:
			_mats_originales.append(m.material_override)
			m.material_override = _mat_silueta
	else:
		for i in range(_mallas.size()):
			_mallas[i].material_override = _mats_originales[i] if i < _mats_originales.size() else null


func silueta_blanca() -> bool:
	return _blanca_puesta


func _t_vivo() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


static func _ease(k: float) -> float:
	return 1.0 - pow(1.0 - clampf(k, 0.0, 1.0), 3.0)
