extends Node

## REGLAS DEL NIVEL «BOSQUE 01» (Juego, 16/10). El siguiente nivel tras Terra Fina; sale de la hoja `Nivel_Bosque_01.xlsx`.
## Mapa: mundo/datos_nivel/mapas/Bosque_01.txt · Nivel editable: mundo/datos_nivel/Nivel_Bosque_01.tscn · Escena: escenas/PruebaBosque01.tscn.
## Se generan con tools/hoja_a_nivel.py; a partir de ahí Pablo edita el .tscn en Godot y este archivo solo lee CASILLAS.
##
## POR QUÉ ES UN NODO HIJO («Reglas») y no `reglas = "bosque"`: PruebaTest2 elige las reglas por cadena fija (Pipeline) y `bosque` es
## Bosque3D, el nivel anterior. Mismo patrón que TerraFina3D: `_ready` espera un fotograma (`call_deferred`) y ya está el mundo montado.
## Los puzles de agua (la losa que sube el estanque) NO están aquí: son líneas `; pieza` / `; puzle` del .txt que lee Puzle3D («Puzles»).
##
## EL NIVEL, de sur a norte (las casillas son las del mapa horneado, con el borde de árboles; el rótulo es el de la hoja):
##   · Zona de inicio (oeste, S): dos goblins guerreros (GG). Al caer los dos aparece el COFRE C_1 (campamento NE) con el glifo de barrera.
##   · El TRONCO-PUENTE (marcador de datos `tronco_puente`, orilla este del río, con enredaderas): al recibir fuego cae SIEMPRE hacia delante
##     (eje X local del marcador) sobre el río y queda de puente. Lo hace TroncoPuente3D.
##   · El prado, con el estanque vacío en medio (T_C → Puzle3D) y el alquimista (ALC). Tres TÓTEMS DE FUEGO, cada uno con su criterio:
##       TF_1 (zona de hierba alta, sur) → que el FUEGO SE PROPAGUE a su lado (una casilla vecina ardiendo).
##       TF_2 (norte)                    → las DOS antorchas de su lado (V14, W14) encendidas a la vez.
##       TF_3 (oeste del prado este)     → las cuatro antorchas T_1..T_4 encendidas EN ORDEN (si te equivocas, se apagan todas).
##   · La PUERTA P_1 (X) se abre con los tres tótems. Detrás, el elemental del bosque (E_B); al caer aparece el COFRE C_2 = fin de la demo.
##
##   · El estanque: el TRONCO (marcador `tronco_estanque`, T19) está al fondo del cauce vacío; al llenarse de agua (la losa T_C) SUBE hasta quedar
##     a ras y el paso se abre (TroncoEstanque3D). Con el agua, el resto de la columna del cauce deja de pisarse: el único paso es el tronco.
##   · Los LOBERNOS (marcadores `loberno`, M19 y M23) usan el modelo aprobado `emberheart.glb` (17/10, Pablo; ver `Pj3D.MODELO_DE`); combaten como los goblins (Combate3D genérico).
##
## PROVISIONAL (modelo): los dos troncos son cilindros (falta el modelo con su versión caída/hundida y las enredaderas).
##
## AMPLIACIÓN (16/10, tools/ampliar_bosque_01.py). El 28 × 28 de arriba sigue en las mismas casillas; alrededor hay ramas nuevas:
##   · Rama NE (desde el campamento): un claro con una patrulla goblin (un guerrero y dos arqueros) y el COFRE 3, que aparece al caer los tres.
##     Sigue por un sendero oriental (con dos telarañas que se queman) hasta el claro de los lobernos y baja a la explanada del sur.
##   · Rama S (desde el prado): la explanada y tres CÁMARAS DE FUEGO, cada una con un puzle del laboratorio que solo pide la flecha de fuego
##     (diario 100): A «cuatro antorchas» (F1), B «contrafuego» (F4) y C «relé de braseros» (F2). Su puerta (líneas `; pieza` / `; puzle` del
##     .txt, las monta Puzle3D) da paso a la trastienda: al abrirla aparece su cofre (4, 5 y 6). Las puertas NO se vuelven a cerrar.
## QUÉ MARCADOR ES CUÁL: los marcadores del .tscn llevan NOMBRE (`cofre_01`, `antorcha_03`, `totem_fuego_02`…) y esta regla los lee POR NOMBRE
## (`PackedScene.get_state()`, sin instanciar el nivel), no por casilla: si Pablo mueve un marcador en el editor, las reglas lo siguen. Los
## nombres son el contrato: `cofre_01..07`, `totem_fuego_01` (propagación) / `_02` (antorchas) / `_03` (secuencia), `brasero_01/02` (el par de TF_2),
## `antorcha_01..04` (la secuencia, EN ORDEN), `guerrero_01/02` (los del cofre 1), `guerrero_03` + `arquero_01/02` (la patrulla del cofre 3).
## Un nombre que falta (un nivel editado a mano) cae a la casilla de siempre (las constantes de abajo) y avisa con push_warning.

const MISION: String = "bosque_01"
const OBJ_GOBLINS: int = 0
const OBJ_COFRE_1: int = 1
const OBJ_TOTEMS: int = 2
const OBJ_PUERTA: int = 3
const OBJ_ELEMENTAL: int = 4
const OBJ_COFRE_2: int = 5
const OBJ_PATRULLA: int = 6                  ## opcional: la patrulla del claro del NE
const OBJ_CAMARAS: int = 7                   ## opcional: las cuatro cámaras de fuego
const OBJ_SECRETOS: int = 8                  ## opcional: los cinco cofres de las ramas

## Los cofres, en el orden de `_cofres` / `_celdas_cofre` / `_entregado` (el 0 y el 1 son los de siempre: glifo y fin de demo).
## `nombre`: el del marcador. `puerta`: la pieza de Puzle3D cuya apertura lo hace aparecer (los de las cámaras). `botin`: lo que da al abrirse.
const COFRES: Array = [
	{"nombre": "cofre_01"}, {"nombre": "cofre_02"},
	{"nombre": "cofre_03", "botin": {"oro": 40, "pocion": 1}},
	{"nombre": "cofre_04", "puerta": "a_puerta", "botin": {"oro": 30, "pocion": 2}},
	{"nombre": "cofre_05", "puerta": "b_puerta", "botin": {"oro": 60, "seta_asada": 2}},
	{"nombre": "cofre_06", "puerta": "c_puerta", "botin": {"oro": 45, "flor_ardiente": 2, "pocion": 1}},
	{"nombre": "cofre_07", "puerta": "d_puerta", "exige_rota": "d_cuerda", "botin": {"oro": 70, "raiz_cenizas": 2, "pocion": 1}},
]
## La patrulla del claro del NE (marcadores): al caer los tres aparece el cofre 3.
const PATRULLA: PackedStringArray = ["guerrero_03", "arquero_01", "arquero_02"]
const GOBLINS_COFRE_1: PackedStringArray = ["guerrero_01", "guerrero_02"]

## Casillas del mapa horneado (columna, fila) POR DEFECTO: solo valen si el nivel no trae el marcador con su nombre (ver arriba).
const TOTEM_PROPAGACION: Vector2i = Vector2i(18, 25)        ## TF_1 (`totem_fuego_01`)
const TOTEM_ANTORCHAS: Vector2i = Vector2i(19, 8)           ## TF_2 (`totem_fuego_02`)
const TOTEM_SECUENCIA: Vector2i = Vector2i(17, 19)          ## TF_3 (`totem_fuego_03`)
const ANTORCHAS_DEL_TOTEM_2: Array = [Vector2i(18, 9), Vector2i(19, 9)]      ## V14, W14 (`brasero_01`, `brasero_02`)
## T_1..T_4 en el orden correcto (W18, U21, U16, W22 de la hoja): `antorcha_01..04`.
const SECUENCIA: Array = [Vector2i(19, 13), Vector2i(17, 16), Vector2i(17, 11), Vector2i(19, 17)]
const ID_LOBERNO: String = "loberno"
## Casillas del cauce que dejan de pisarse al llenarse el estanque (la columna oeste, menos la del tronco). Por qué solo estas: el brazo de
## arriba (fila 10) lleva a la losa T_C y tiene que seguir libre. Si el diseño quiere cortar otra parte, es esta lista.
const COLUMNA_ESTANQUE: Array = [Vector2i(16, 11), Vector2i(16, 12), Vector2i(16, 13), Vector2i(16, 15), Vector2i(16, 16),
		Vector2i(16, 17), Vector2i(16, 18), Vector2i(16, 19), Vector2i(16, 20)]

const FASE_ARDIENDO: int = 3             ## PruebaTest2.Fase.ARDIENDO (la maqueta no tiene class_name; 4 = CENIZAS, también cuenta)
const T_SONDEO: float = 0.1              ## s entre comprobaciones (los criterios no necesitan 60 Hz)
const ALCANCE_E: float = 2.7             ## unidades: hablar con el alquimista y abrir cofres (la casilla mide 2,3)
const COLOR_FUEGO: Color = Color(1.0, 0.45, 0.15)
const COLOR_APAGADO: Color = Color(0.42, 0.42, 0.48)
const COFRE_ESCENA: String = "res://arte/piezas/cofre.tscn"

const DIALOGO_ALQUIMISTA: Array = [
	"Una muestra gratis, que luego no digas. Bébela cuando duela (Q).",
	"Cuatro antorchas del prado de este lado. El orden importa: la del medio, la de abajo, la de arriba y, por último, la de abajo a la derecha.",
	"Un fallo y se apagan todas. A mí ya me ha pasado. Dos veces.",
	"Al tótem del sur no se le enciende con un hechizo: lo despierta el fuego que se contagia. La hierba alta ayuda.",
	"Dicen que al sur del prado hay cuatro cámaras con trastienda. Allí solo sirve la flecha de fuego: braseros, setos, un barril que no es de fiar y una cuerda que sostiene el agua.",
	"Y por el norte, tras el campamento, un claro con goblins que no te quieren bien. Al otro lado, un sendero con telarañas: llévate fuego.",
]

var m: Variant = null                       ## la maqueta (PruebaTest2); sin tipo: se le llaman métodos suyos
var _jug: Jugador3D = null
var _aviso: Label = null
var _t_aviso: float = 0.0
var _acum: float = 0.0
var _totems: Dictionary = {}                ## Vector2i -> Reactivo3D (los tres tótems)
var _totem_propagacion: Vector2i = TOTEM_PROPAGACION     ## las casillas de los tres tótems, ya resueltas por nombre
var _totem_antorchas: Vector2i = TOTEM_ANTORCHAS
var _totem_secuencia: Vector2i = TOTEM_SECUENCIA
var _sec: Array = []                        ## Reactivo3D de las cuatro antorchas, en orden
var _sec_prev: Array = [false, false, false, false]
var _sec_sig: int = 0                       ## cuántas llevas bien
var _sec_hecha: bool = false
var _antorchas2: Array = []
var _goblins: Array = []                    ## Combate3D del cofre 1
var _lobernos: Array = []                   ## Pj3D de los lobernos (el modelo; su Combate3D cuelga de la maqueta)
var _tronco_puente: TroncoPuente3D = null
var _tronco_estanque: TroncoEstanque3D = null
var _columna_cortada: bool = false
var _elementales: Array = []
var _celda_puerta: Vector2i = Vector2i(-1, -1)
var _puerta: MeshInstance3D = null
var _lamparas: Array = []
var _puerta_abierta: bool = false
var _celdas_cofre: Array = []               ## la casilla de cada cofre, en el orden de COFRES (cofre_01..07)
var _entregado: Array = [false, false, false, false, false, false, false]      ## el botín de cada cofre se da UNA vez, abra como abra
var _cofres: Array = [null, null, null, null, null, null, null]               ## Node3D de cada cofre cuando ya ha aparecido
var _marca: Dictionary = {}                 ## nombre de marcador -> casilla (leído del .tscn con PackedScene.get_state())
var _patrulla: Array = []                   ## Combate3D de la patrulla del claro del NE (cofre 3)
var _puzles: Node = null                    ## el nodo «Puzles» (Puzle3D) de la escena, para saber si ya se abrió cada puerta
var _npc: Pj3D = null
var _lineas: int = 0
var _muestra_dada: bool = false
var _hablando: Pj3D = null
var _t_habla: float = 0.0
var _terminado: bool = false


func _ready() -> void:
	# El padre aún no ha hecho su _ready: se espera a que termine (call_deferred corre al final del fotograma).
	call_deferred("_arrancar")


func _arrancar() -> void:
	if get_parent() != null:
		iniciar(get_parent())


## Entrada pública: `mundo` es la maqueta ya montada.
func iniciar(mundo: Variant) -> void:
	m = mundo
	for n in (m as Node).get_children():
		if n is Jugador3D:
			_jug = n
	var mapa: PackedStringArray = m.get("_mapa")
	_leer_marcas_por_nombre()
	_puzles = (m as Node).get_node_or_null("Puzles")
	var cofres_letra: Array = []
	for y in range(mapa.size()):
		for x in range(mapa[y].length()):
			match mapa[y][x]:
				"X":
					_celda_puerta = Vector2i(x, y)
				"Z":
					cofres_letra.append(Vector2i(x, y))      # de arriba abajo: C_1 (campamento) antes que C_2 (este); solo vale sin nombres
	for i in range(COFRES.size()):
		var nombre: String = String((COFRES[i] as Dictionary)["nombre"])
		if _marca.has(nombre):
			_celdas_cofre.append(_marca[nombre])
		elif i < cofres_letra.size() and not _marca.has("cofre_01"):
			_celdas_cofre.append(cofres_letra[i])             # un nivel antiguo sin nombres: los dos Z de siempre
		else:
			_celdas_cofre.append(Vector2i(-1, -1))            # este cofre no existe en este nivel
	# Tótems y antorchas: los reactivos que puso la maqueta. Los tótems salen de la capa de hechizos: no se encienden «a pelo».
	var por_celda: Dictionary = {}
	for r in (m.get("_reactivos") as Array):
		if is_instance_valid(r):
			por_celda[r.celda] = r
	for c in [_celda("totem_fuego_01", TOTEM_PROPAGACION), _celda("totem_fuego_02", TOTEM_ANTORCHAS), _celda("totem_fuego_03", TOTEM_SECUENCIA)]:
		var t: Variant = por_celda.get(c)
		if t != null and t.tipo == "totem":
			_totems[c] = t
			(t as CollisionObject3D).collision_layer = 0
	_totem_propagacion = _celda("totem_fuego_01", TOTEM_PROPAGACION)
	_totem_antorchas = _celda("totem_fuego_02", TOTEM_ANTORCHAS)
	_totem_secuencia = _celda("totem_fuego_03", TOTEM_SECUENCIA)
	for i in range(ANTORCHAS_DEL_TOTEM_2.size()):
		var c2: Vector2i = _celda("brasero_%02d" % (i + 1), ANTORCHAS_DEL_TOTEM_2[i])
		if por_celda.has(c2):
			_antorchas2.append(por_celda[c2])
	for i in range(SECUENCIA.size()):
		var c3: Vector2i = _celda("antorcha_%02d" % (i + 1), SECUENCIA[i])
		if por_celda.has(c3):
			_sec.append(por_celda[c3])
	_clasificar_combates()
	_montar_troncos_y_lobernos()
	_buscar_alquimista()
	if _celda_puerta.x >= 0:
		_montar_puerta()
	_montar_aviso()
	var objetivos: Array = [
		"Derrotar a los goblins del camino (0/%d)" % _goblins.size(), "Abrir el cofre del campamento",
		"Activar los tres tótems de fuego (0/3)", "Abrir la puerta de los tótems", "Derrotar al elemental del bosque", "Abrir el cofre final",
		"(Opcional) Derrotar a la patrulla del claro (0/%d)" % _patrulla.size(), "(Opcional) Abrir las cuatro cámaras de fuego (0/4)",
		"(Opcional) Encontrar los cinco cofres de las ramas (0/5)"]
	Misiones.i().definir({"id": MISION, "titulo": "El Bosque (1.ª parte)", "tipo": "principal",
		"texto": "Tres tótems de fuego, cada uno con su manera de despertar, abren la puerta del fondo. Detrás espera el elemental del bosque.",
		"origen": "Bosque 01", "objetivos": objetivos})
	Misiones.i().activar(MISION)
	if _goblins.is_empty():
		Misiones.i().objetivo_hecho(MISION, OBJ_GOBLINS)
	if _patrulla.is_empty():
		Misiones.i().objetivo_hecho(MISION, OBJ_PATRULLA)
	set_process(true)


## Los goblins guerreros del cofre 1 (`guerrero_01/02`) y la patrulla del claro (`guerrero_03`, `arquero_01/02`) se reconocen por la casilla donde
## nacen (`Combate3D.casa`); el elemental da el cofre 2; cualquier otro enemigo del nivel (el guerrero de la explanada) no cuenta para nada.
## Sin marcadores con nombre (un nivel antiguo) vale lo de siempre: todo guerrero es del cofre 1. Los lobernos se crean después y no cuentan aquí.
func _clasificar_combates() -> void:
	var con_nombres: bool = _marca.has("guerrero_01")
	var cofre1: Array = []
	var patrulla: Array = []
	for n in GOBLINS_COFRE_1:
		if _marca.has(n):
			cofre1.append(_marca[n])
	for n in PATRULLA:
		if _marca.has(n):
			patrulla.append(_marca[n])
	for n in get_tree().get_nodes_in_group("combate3d"):
		var cb: Combate3D = n as Combate3D
		if cb == null:
			continue
		if cb.elemental:
			_elementales.append(cb)
			continue
		var c: Vector2i = Terreno3D.celda_de(cb.casa)
		if not con_nombres:
			if not cb.arquero:
				_goblins.append(cb)
		elif cofre1.has(c):
			_goblins.append(cb)
		elif patrulla.has(c):
			_patrulla.append(cb)


## Lee del .tscn del nivel la casilla de cada marcador con nombre, SIN instanciarlo: `PackedScene.get_state()` da los nodos y sus propiedades.
## La casilla es la del mapa horneado (origen = la casilla pintada más al noroeste, como `_leer_nivel_de` de la maqueta).
func _leer_marcas_por_nombre() -> void:
	_marca.clear()
	var nivel: Variant = (m as Object).get("nivel")
	if nivel == null or String(nivel) == "":
		return
	var ruta: String = HorneadorNivel.ruta(String(nivel))
	if not ResourceLoader.exists(ruta):
		return
	var ps: PackedScene = load(ruta) as PackedScene
	if ps == null:
		return
	var est: SceneState = ps.get_state()
	var mn := Vector2i(1 << 30, 1 << 30)
	var pos_marca: Dictionary = {}
	for i in range(est.get_node_count()):
		var ruta_nodo: String = String(est.get_node_path(i)).trim_prefix("./")      # las rutas de SceneState empiezan por «./»
		if ruta_nodo == "Suelo":
			for k in range(est.get_node_property_count(i)):
				if est.get_node_property_name(i, k) == "data":
					var celdas: PackedInt32Array = (est.get_node_property_value(i, k) as Dictionary).get("cells", PackedInt32Array())
					for j in range(0, celdas.size(), 3):
						mn = Vector2i(mini(mn.x, _s16(celdas[j])), mini(mn.y, _s16(celdas[j + 1])))
		elif ruta_nodo.begins_with("Marcadores/"):
			for k in range(est.get_node_property_count(i)):
				if est.get_node_property_name(i, k) == "transform":
					pos_marca[String(est.get_node_name(i))] = (est.get_node_property_value(i, k) as Transform3D).origin
	if mn.x == 1 << 30:
		return
	for nombre in pos_marca:
		var p: Vector3 = pos_marca[nombre]
		_marca[nombre] = Vector2i(int(floor(p.x / Terreno3D.casilla)), int(floor(p.z / Terreno3D.casilla))) - mn


## Los índices de GridMap van en 16 bits con signo.
static func _s16(v: int) -> int:
	v &= 0xFFFF
	return v - 0x10000 if v >= 0x8000 else v


## La casilla del marcador `nombre`; si el nivel no lo trae, `defecto` (y se avisa: el nivel está editado a mano sin ese nombre).
func _celda(nombre: String, defecto: Vector2i) -> Vector2i:
	if _marca.has(nombre):
		return _marca[nombre]
	if not _marca.is_empty():
		push_warning("Bosque 01: no hay marcador «%s» en el nivel; se usa la casilla de siempre %s" % [nombre, str(defecto)])
	return defecto


## Lee los marcadores de datos del nivel (`tronco_puente`, `tronco_estanque`, `loberno`) y crea lo que piden. Sin marcador no hace nada:
## así un Nivel_Bosque_01.tscn editado a mano sin ellos sigue arrancando.
func _montar_troncos_y_lobernos() -> void:
	for mc in (m._marcas as Array):
		var d: Dictionary = mc
		var c: Vector2i = d["c"]
		match String(d["grupo"]):
			"tronco_puente":
				# El giro del marcador (grados, sentido de las agujas hacia +Z como en el resto de marcadores) fija hacia dónde cae: su +X local.
				var a: float = deg_to_rad(float(d["giro"]))
				var dir := Vector3(cos(a), 0.0, -sin(a))
				var celda_rio: Vector2i = c + Vector2i(roundi(dir.x), roundi(dir.z))
				var base: Vector3 = m.call("_centro_celda", c, m.ALTO)
				_tronco_puente = TroncoPuente3D.new()
				_tronco_puente.name = "TroncoPuente"
				m.add_child(_tronco_puente)
				_tronco_puente.preparar(m, base, dir, celda_rio)
			"tronco_estanque":
				_tronco_estanque = TroncoEstanque3D.new()
				_tronco_estanque.name = "TroncoEstanque"
				m.add_child(_tronco_estanque)
				_tronco_estanque.preparar(m, c)
			"loberno":
				_crear_loberno(c)


## Un loberno: el modelo (Pj3D) más su Combate3D, como lo hace Jugador3D con los de `_goblins` al montar. Si falta el GLB no sale y se avisa.
func _crear_loberno(c: Vector2i) -> void:
	var pj: Pj3D = m.call("_personaje", [ID_LOBERNO], m.call("_pos_marca", c, m.ALTO))
	if pj == null or _jug == null:
		push_warning("Bosque 01: no se pudo crear el loberno de %s (¿falta arte/modelos/emberheart.glb?)" % str(c))
		return
	(m.get("_goblins") as Array).append(pj)
	_lobernos.append(pj)
	Combate3D.equipar(pj, m, _jug, _jug.lanz)


## El alquimista lo crea `poner_puesto` sin guardarlo (solo avisa a unas reglas registradas): se busca el Pj3D más cercano a su puesto.
func _buscar_alquimista() -> void:
	var mapa: PackedStringArray = m.get("_mapa")
	var cq: Vector2i = Vector2i(-1, -1)
	for y in range(mapa.size()):
		for x in range(mapa[y].length()):
			if mapa[y][x] == "Q":
				cq = Vector2i(x, y)
	if cq.x < 0:
		return
	var centro: Vector3 = m.call("_centro_celda", cq, 0.0)
	var goblins: Array = m.get("_goblins")
	var mejor: float = 4.0
	for n in (m as Node).find_children("*", "Pj3D", true, false):
		if n is Jugador3D or goblins.has(n):
			continue
		var d: Vector3 = (n as Pj3D).position - centro
		d.y = 0.0
		if d.length() < mejor:
			mejor = d.length()
			_npc = n as Pj3D


## La puerta: un tablón que cierra el paso de oeste a este y tres lámparas encima, una por tótem.
func _montar_puerta() -> void:
	var s: float = float(m.get("S"))
	var alto: float = float(m.get("ALTO"))
	var caja := BoxMesh.new()
	caja.size = Vector3(0.28, 2.3, s * 0.92)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.34, 0.22)
	mat.roughness = 0.9
	caja.material = mat
	_puerta = MeshInstance3D.new()
	_puerta.name = "puerta_totems"
	_puerta.mesh = caja
	_puerta.position = m.call("_centro_celda", _celda_puerta, alto + 1.15)
	(m.get("_props") as Node).add_child(_puerta)
	m.call("_bloquear", _celda_puerta)
	var base: Vector3 = m.call("_centro_celda", _celda_puerta, alto + 3.9)
	for i in range(3):
		var lamp: MeshInstance3D = Formas3D.instancia("llama", COLOR_APAGADO, 0.42)
		lamp.position = base + Vector3(0.0, 0.0, (float(i) - 1.0) * 0.6)
		(m.get("_props") as Node).add_child(lamp)
		_lamparas.append(lamp)


func _montar_aviso() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 6
	add_child(capa)
	_aviso = Label.new()
	_aviso.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_aviso.position = Vector2(-300.0, -120.0)
	_aviso.custom_minimum_size = Vector2(600.0, 0.0)
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.add_theme_font_size_override("font_size", 22)
	_aviso.add_theme_color_override("font_outline_color", Color.BLACK)
	_aviso.add_theme_constant_override("outline_size", 8)
	capa.add_child(_aviso)


func _process(delta: float) -> void:
	if m == null or m.get("_jugador") == null:
		return
	_t_aviso = maxf(_t_aviso - delta, 0.0)
	if _t_aviso <= 0.0 and _aviso != null:
		_aviso.text = ""
	if _hablando != null:
		_t_habla -= delta
		if _t_habla <= 0.0:
			_hablando.animacion_actual = ""
			_hablando.jugar("idle")
			_hablando = null
	_acum += delta
	if _acum < T_SONDEO:
		return
	_acum = 0.0
	_criterio_propagacion()
	_criterio_antorchas()
	_criterio_secuencia()
	_revisar_totems_y_puerta()
	_revisar_combates()
	_revisar_camaras()
	_revisar_estanque()


## Al llenarse el estanque, el resto de la columna del cauce deja de pisarse (el agua es profunda ahí) y solo queda el tronco como paso.
## `_bloquear` y no `_bloqueadas[c] = true`: el Lanzador se entera por ahí (ver prueba_test2.gd).
func _revisar_estanque() -> void:
	if _columna_cortada or _tronco_estanque == null:
		return
	var abiertas: bool = false
	for c in COLUMNA_ESTANQUE:
		if Terreno3D.cauces_abiertos.has(c):
			abiertas = true
			break
	if not abiertas:
		return
	_columna_cortada = true
	for c in COLUMNA_ESTANQUE:
		m.call("_bloquear", c)
	_decir("El estanque se llena. El tronco empieza a subir.", 4.0)


## TF_1: se despierta cuando el fuego se ha contagiado a su lado (la casilla del tótem o alguna vecina arde o ya es ceniza).
func _criterio_propagacion() -> void:
	var t: Variant = _totems.get(_totem_propagacion)
	if t == null or bool(t.activo):
		return
	var hf: Dictionary = m.get("_hf")
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var q: Vector2i = _totem_propagacion + Vector2i(dx, dy)
			if hf.has(q) and int((hf[q] as Dictionary)["fase"]) >= FASE_ARDIENDO:
				_activar(t)
				return


## TF_2: las dos antorchas de su lado arden a la vez.
func _criterio_antorchas() -> void:
	var t: Variant = _totems.get(_totem_antorchas)
	if t == null or bool(t.activo) or _antorchas2.is_empty():
		return
	for r in _antorchas2:
		if not is_instance_valid(r) or not bool(r.is_lit):
			return
	_activar(t)


## TF_3: T_1..T_4 en orden. Cada antorcha que se enciende se compara con la que tocaba; si no es esa, se apagan todas y se empieza de cero.
func _criterio_secuencia() -> void:
	var t: Variant = _totems.get(_totem_secuencia)
	if t == null or _sec_hecha or _sec.size() != SECUENCIA.size():
		return
	var fallo: bool = false
	for i in range(_sec.size()):
		var r: Variant = _sec[i]
		var arde: bool = is_instance_valid(r) and bool(r.is_lit)
		if arde and not bool(_sec_prev[i]):
			if i == _sec_sig:
				_sec_sig += 1
			else:
				fallo = true
		_sec_prev[i] = arde
	if fallo:
		_sec_sig = 0
		for i in range(_sec.size()):
			if is_instance_valid(_sec[i]) and bool(_sec[i].is_lit):
				_sec[i].apagar_llama()
			_sec_prev[i] = false
		_decir("Orden equivocado: las antorchas se apagan.", 3.5)
	elif _sec_sig >= _sec.size():
		_sec_hecha = true
		_activar(t)


func _activar(t: Variant) -> void:
	# Mismo gesto que Bosque3D: el tótem de fuego solo reconoce un hechizo de fuego, así que se le da uno «de verdad».
	var r := RuneData.new()
	var tags: Array[String] = ["fuego", "calor"]
	r.tags = tags
	t.on_spell_hit(r, Vector3.ZERO)


func _revisar_totems_y_puerta() -> void:
	var n: int = 0
	for c in _totems:
		if bool(_totems[c].activo):
			n += 1
	Misiones.i().objetivo_texto(MISION, OBJ_TOTEMS, "Activar los tres tótems de fuego (%d/3)" % n)
	for i in range(mini(n, _lamparas.size())):
		_encender_lampara(i)
	if n >= _totems.size() and not _totems.is_empty():
		Misiones.i().objetivo_hecho(MISION, OBJ_TOTEMS)
		if not _puerta_abierta and _celda_puerta.x >= 0:
			_abrir_puerta()


func _encender_lampara(i: int) -> void:
	var lamp: MeshInstance3D = _lamparas[i]
	if lamp.has_meta("encendida"):
		return
	lamp.set_meta("encendida", true)
	lamp.set_surface_override_material(0, Formas3D.material_tinte(COLOR_FUEGO, false, "llama"))
	if m.get("_fx") != null:
		(m.get("_fx") as Vfx3D).chispazo(lamp.position, "fuego")
	_decir("Tótem activado (%d/3)" % _contar_lamparas(), 3.0)


func _contar_lamparas() -> int:
	var n: int = 0
	for l in _lamparas:
		if (l as Node).has_meta("encendida"):
			n += 1
	return n


func _abrir_puerta() -> void:
	_puerta_abierta = true
	Misiones.i().objetivo_hecho(MISION, OBJ_PUERTA)
	m.call("_liberar", _celda_puerta)
	_decir("¡La puerta se abre!", 4.0)
	if _puerta != null:
		var tw := create_tween()
		tw.tween_property(_puerta, "position:y", _puerta.position.y - 2.4, 1.4).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(_puerta.hide)


## Goblins muertos → cofre 1; elemental muerto → cofre 2.
func _revisar_combates() -> void:
	var caidos: int = 0
	for g in _goblins:
		if not is_instance_valid(g) or bool(g.muerto):
			caidos += 1
	if not _goblins.is_empty():
		Misiones.i().objetivo_texto(MISION, OBJ_GOBLINS, "Derrotar a los goblins del camino (%d/%d)" % [caidos, _goblins.size()])
	if caidos >= _goblins.size() and _cofres[0] == null:
		Misiones.i().objetivo_hecho(MISION, OBJ_GOBLINS)
		_aparecer_cofre(0)
		_decir("Los goblins han caído. En el campamento, algo brilla.", 5.0)
	_revisar_patrulla()
	if _elementales.is_empty() or _cofres[1] != null:
		return
	for e in _elementales:
		if is_instance_valid(e) and not bool(e.muerto):
			return
	Misiones.i().objetivo_hecho(MISION, OBJ_ELEMENTAL)
	_aparecer_cofre(1)
	_decir("El elemental ha caído. Hay un cofre al fondo.", 5.0)


## La patrulla del claro del NE (guerrero_03 + arquero_01/02): al caer los tres aparece el cofre 3.
func _revisar_patrulla() -> void:
	if _patrulla.is_empty():
		return
	var caidos: int = 0
	for g in _patrulla:
		if not is_instance_valid(g) or bool(g.muerto):
			caidos += 1
	Misiones.i().objetivo_texto(MISION, OBJ_PATRULLA, "(Opcional) Derrotar a la patrulla del claro (%d/%d)" % [caidos, _patrulla.size()])
	if caidos >= _patrulla.size() and _cofres[2] == null:
		Misiones.i().objetivo_hecho(MISION, OBJ_PATRULLA)
		_aparecer_cofre(2)
		_decir("La patrulla ha caído. En el claro, algo brilla.", 5.0)


## Las cámaras de fuego: cuando Puzle3D abre la puerta de una trastienda, aparece su cofre. Se mira cada T_SONDEO: no hay señal que escuchar
## (la pieza vive en el nodo «Puzles», que se monta antes que esto) y así tampoco depende del orden de arranque de los dos nodos.
func _revisar_camaras() -> void:
	if _puzles == null:
		return
	var abiertas: int = 0
	var total: int = 0
	for i in range(COFRES.size()):
		var puerta_id: String = String((COFRES[i] as Dictionary).get("puerta", ""))
		if puerta_id == "":
			continue
		var pz: Variant = (_puzles as Puzle3D).pieza(puerta_id)
		if pz == null or not is_instance_valid(pz.nodo):
			continue
		total += 1
		# La puerta de la cámara de la cuerda arranca ABIERTA (el arroyo tarda ~18 s en llegar y el vado está a 0): el cofre solo cuenta cuando la cuerda ya se rompió.
		var exige: String = String((COFRES[i] as Dictionary).get("exige_rota", ""))
		var ya_rota: bool = true
		if exige != "":
			var cz: Variant = (_puzles as Puzle3D).pieza(exige)
			ya_rota = cz != null and is_instance_valid(cz.nodo) and bool(cz.nodo.get("rota_ya"))
		if bool(pz.nodo.get("abierta")) and ya_rota:
			abiertas += 1
			if _cofres[i] == null and _celdas_cofre[i].x >= 0:
				_aparecer_cofre(i)
				_decir("Se abre la trastienda. Algo brilla dentro.", 5.0)
	if total > 0:
		Misiones.i().objetivo_texto(MISION, OBJ_CAMARAS, "(Opcional) Abrir las cuatro cámaras de fuego (%d/%d)" % [abiertas, total])
		if abiertas >= total:
			Misiones.i().objetivo_hecho(MISION, OBJ_CAMARAS)


## El cofre aparece donde el nivel lo marca (marcador `cofre_0N`), creciendo desde nada; bloquea su casilla.
func _aparecer_cofre(i: int) -> void:
	if i >= _celdas_cofre.size() or ResourceLoader.exists(COFRE_ESCENA) == false or (_celdas_cofre[i] as Vector2i).x < 0:
		return
	var c: Vector2i = _celdas_cofre[i]
	var nodo: Node3D = (load(COFRE_ESCENA) as PackedScene).instantiate() as Node3D
	nodo.name = "cofre_%02d" % (i + 1)
	nodo.position = m.call("_centro_celda", c, float(m.get("ALTO")))
	(m.get("_props") as Node).add_child(nodo)
	# V6: aparece materializándose por celdas (Cofre3D.aparecer: disolver 1 → 0). No se puede abrir hasta que acaba (`abrir()` devuelve false mientras tanto:
	# el jugador vuelve a pulsar E). Sin controlador (arte sin importar) o sin disolver, crece desde nada como antes.
	var ctrl: Cofre3D = Cofre3D.en(nodo)
	var materializa: bool = false
	if ctrl != null and nodo.is_inside_tree():
		ctrl.ocultar()
		materializa = ctrl.aparecer()
	if not materializa:
		nodo.scale = Vector3.ONE * 0.01
		create_tween().tween_property(nodo, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	m.call("_bloquear", c)
	_cofres[i] = nodo


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or m == null or m.get("_jugador") == null:
		return
	var k: InputEventKey = ev as InputEventKey
	if not k.pressed or k.echo or k.keycode != KEY_E:
		return
	var yo: Vector3 = (m.get("_jugador") as Pj3D).position
	# Cofres primero (si estás al lado de uno, abrirlo es lo que quieres), luego el alquimista.
	for i in range(_cofres.size()):
		var cf: Variant = _cofres[i]
		if cf != null and _lejos(cf.position, yo) <= ALCANCE_E:
			var ctrl: Cofre3D = Cofre3D.en(cf)
			if ctrl == null:
				_al_abrir_cofre(i)                     # el modelo no trae tapa que animar (arte sin importar): el botín se entrega igual
			elif not ctrl.esta_abierto() and ctrl.abrir():
				ctrl.abierto.connect(_al_abrir_cofre.bind(i), CONNECT_ONE_SHOT)
			return
	if _npc != null and _lejos(_npc.position, yo) <= ALCANCE_E:
		_hablar_alquimista(yo)


static func _lejos(a: Vector3, b: Vector3) -> float:
	var d: Vector3 = a - b
	d.y = 0.0
	return d.length()


func _al_abrir_cofre(i: int) -> void:
	if bool(_entregado[i]):
		return
	_entregado[i] = true
	if i == 0:
		Misiones.i().objetivo_hecho(MISION, OBJ_COFRE_1)
		if Repertoire.conseguir_sigil("barrera"):     # se escribe en la página derecha del libro al abrirlo
			_decir("Glifo de barrera conseguido: ya puedes dibujarlo.", 6.0)
		else:
			_decir("El cofre está vacío: la barrera ya era tuya.", 4.0)
	elif i == 1:
		Misiones.i().objetivo_hecho(MISION, OBJ_COFRE_2)
		_terminado = true
		# Fin de la demo = nivel completado (una vez: `_entregado[1]` ya lo guarda). Sale del cofre, que es donde esta el jugador.
		var cofre: Variant = _cofres[1]
		var pos_fin: Vector3 = (cofre as Node3D).position + Vector3.UP if cofre is Node3D else Vector3.ZERO
		Mundo3D.avisar_logro("nivel_completado", pos_fin, cofre as Node)
		_decir("Fin de la demo. Gracias por jugar el Bosque.", 10.0)
	else:
		_dar_botin(i)


## El botín de un cofre de las ramas: oro y lo que quepa en la bolsa (lo que no cabe se queda fuera y se dice).
func _dar_botin(i: int) -> void:
	var botin: Dictionary = (COFRES[i] as Dictionary).get("botin", {})
	var texto: PackedStringArray = []
	var sin_sitio: bool = false
	for id in botin:
		var n: int = int(botin[id])
		if id == "oro":
			Estado.i().dar_oro(n)
			texto.append("%d de oro" % n)
		else:
			var entra: int = Estado.i().agregar(String(id), n)
			if entra > 0:
				texto.append("%d × %s" % [entra, Objetos.nombre(String(id))])
			if entra < n:
				sin_sitio = true
	var propios: int = 0
	for k in range(2, COFRES.size()):
		if bool(_entregado[k]):
			propios += 1
	Misiones.i().objetivo_texto(MISION, OBJ_SECRETOS, "(Opcional) Encontrar los cinco cofres de las ramas (%d/5)" % propios)
	if propios >= 5:
		Misiones.i().objetivo_hecho(MISION, OBJ_SECRETOS)
	_decir("Cofre abierto: %s.%s" % [", ".join(texto), " (La bolsa está llena: lo demás se queda aquí.)" if sin_sitio else ""], 6.0)


func _hablar_alquimista(yo: Vector3) -> void:
	var texto: String = String(DIALOGO_ALQUIMISTA[_lineas % DIALOGO_ALQUIMISTA.size()])
	_lineas += 1
	if not _muestra_dada:
		if Estado.i().agregar("pocion", 1) > 0:
			_muestra_dada = true
		else:
			_lineas -= 1
			texto = "Tu bolsa no tiene hueco para la muestra. Vuelve con un sitio libre."
	_decir("Alquimista: «%s»" % texto, 6.0)
	Sintesis.abrir("alquimista")                 # F3: su taller (la interfaz es del Pipeline)
	_npc.mirar(yo - _npc.position, 1.0)
	_npc.jugar("talk")
	Sfx3D.play(_npc, "conversacion_voz")
	_hablando = _npc
	_t_habla = 2.5


func _decir(texto: String, seg: float) -> void:
	if _aviso != null:
		_aviso.text = texto
	_t_aviso = seg
