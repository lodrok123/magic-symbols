extends Node

## REGLAS DEL NIVEL «BOSQUE 01 v01» (Juego, 24/10). El Bosque 01 con la forma abierta de EoW: docs/PLAN_BOSQUE_01_V01.md y sus «Decisiones de Pablo (24/10)».
## Mapa: mundo/datos_nivel/mapas/Bosque_01_v01.txt · Nivel horneado: mundo/datos_nivel/Nivel_Bosque_01_v01.tscn (herramientas/hornear_bosque_01_v01.gd) · Escena: escenas/PruebaBosque01_v01.tscn.
## Sale de escenas/bosque_01_3d.gd (el nivel de partida, que no se toca). Qué cambia:
##
## 1) TODO LO QUE VIVÍA EN VARIABLES VIVE EN FLAGS (`Flags`, estáticas: sobreviven a ir a la Cueva y volver, porque el nivel se recarga desde cero, `Niveles`). Se ESCRIBEN cuando pasan y se LEEN al montar:
##      tótems encendidos → `bosque01v1.totem.fuego_N` (al montar, el tótem se enciende solo) · puerta de los tótems → `bosque01v1.puerta_x.abierta` · telarañas, puerta goblin y torres quemadas →
##      `bosque01v1.quemado.c<x>_<y>` (al montar ya no están) · tronco-puente caído → `bosque01v1.tronco_puente.caido` (al montar ya está tumbado) · muestra del alquimista · saludos del elfo ·
##      la misión se DERIVA de las flags en cada sondeo (no se redefine si ya existe). Los cofres, las salas cerradas, el atajo, las puertas de las cámaras, el estanque, las paredes que suenan y los rompibles
##      son piezas de Puzle3D (líneas `; pieza` / `; puzle` del .txt) y ya guardan sus flags. Los enemigos de una sala o de un reto ya resuelto NO se repueblan (los vigías los retiran al montar);
##      vuelven los SUELTOS del exterior (lobernos, el guerrero de la explanada, el asesino…).
##
## 2) EL PASO BATIDO (el desafío de la barrera). La tala solo sale por la pasarela del sur: (8,6)..(8,11). Dos arqueros de PUESTO (`Combate3D.fijo`: no persiguen, disparan hasta 16 u con línea libre)
##    la baten desde (8,12)/(8,13), con adelanto (apuntan a donde estará el jugador). El cofre_01 (legendario, con la secuencia del glifo ᛜ) está en la tala: se aprende la barrera ANTES del paso. Una barrera
##    para las flechas (`Lanzador3D.solidez_para`): ᛜ + ᛁ cubre la casilla del jugador; ᛜ + flecha se planta dos casillas por delante y se avanza a su abrigo (dura 7,9 s con tierra: hay que levantar otra). Se marca el objetivo al llegar al prado; al caer los dos arqueros se pone `bosque01v1.paso.limpio` y no vuelven.
##
## 3) GENTE colocada desde el mapa con marcadores de datos (`; marcador npc <tipo> x y`, `; marcador asesino - x y`, `; marcador loberno …`): el goblin leñador (talar y, cuando cae el campamento, cavar), el
##    elfo junto a la puerta X (saludo, pistas, celebrar al abrirse la puerta y al caer el elemental), Marimanta en la boca de la Cueva (andar despacio, pensar, hablar de la Cueva) y el goblin asesino en
##    la hierba alta. Los diálogos son tablas de este archivo, como el del alquimista.
##
## Los marcadores se leen POR NOMBRE del .tscn (`PackedScene.get_state()`, sin instanciar el nivel): `totem_fuego_01..03`, `brasero_01/02`, `antorcha_01..04`, `arquero_paso_01/02`, `puerta_01`…
## Un nombre que falta cae a la casilla de siempre (las constantes de abajo) y avisa con push_warning.

const MISION: String = "bosque_01_v01"
const OBJ_TALA: int = 0
const OBJ_COFRE_BARRERA: int = 1
const OBJ_PASO: int = 2
const OBJ_TOTEMS: int = 3
const OBJ_LLAVE: int = 4
const OBJ_PUERTA: int = 5
const OBJ_ELEMENTAL: int = 6
const OBJ_COFRE_FINAL: int = 7
const OBJ_CLARO: int = 8                     ## opcional
const OBJ_CAMARAS: int = 9                   ## opcional
const OBJ_CUEVA: int = 10                    ## opcional
const OBJ_ECOS: int = 11                     ## opcional

# --- Flags (nivel.sala.hecho). Las de piezas de Puzle3D están declaradas en el .txt; aquí las que pone o lee este script ---
const F_TOTEM: PackedStringArray = ["bosque01v1.totem.fuego_1", "bosque01v1.totem.fuego_2", "bosque01v1.totem.fuego_3"]
const F_PUERTA_X: String = "bosque01v1.puerta_x.abierta"
const F_TALA_PISADA: String = "bosque01v1.tala.pisada"
const F_PASO_CRUZADO: String = "bosque01v1.paso.cruzado"
const F_PASO_LIMPIO: String = "bosque01v1.paso.limpio"
const F_COFRE_BARRERA: String = "bosque01v1.linde.cofre"
const F_LINDE_LIMPIA: String = "bosque01v1.linde.limpia"
const F_LLAVE: String = "bosque01v1.campamento.llave"
const F_CAMPAMENTO_LIMPIO: String = "bosque01v1.campamento.limpio"
const F_SANTUARIO_LIMPIO: String = "bosque01v1.santuario.limpio"
const F_COFRE_FINAL: String = "bosque01v1.santuario.cofre"
const F_CLARO_LIMPIO: String = "bosque01v1.claro.limpio"
const F_CAMARAS: PackedStringArray = ["bosque01v1.camara_a.puerta", "bosque01v1.camara_b.puerta", "bosque01v1.camara_c.puerta", "bosque01v1.camara_d.cuerda"]
const F_ECOS: PackedStringArray = ["bosque01v1.hondonada.eco", "bosque01v1.explanada.eco"]
const F_GLIFO_CUEVA: String = "cueva.c6.glifo"
const F_TRONCO_PUENTE: String = "bosque01v1.tronco_puente.caido"
const F_MUESTRA: String = "bosque01v1.alquimista.muestra"
const F_POCION_GOBLIN: String = "bosque01v1.goblin.pocion"
const F_ELFO_SALUDO: String = "bosque01v1.elfo.saludo"
const F_ELFO_CELEBRA_PUERTA: String = "bosque01v1.elfo.celebra_puerta"
const F_ELFO_CELEBRA_FINAL: String = "bosque01v1.elfo.celebra_final"
const PREFIJO_QUEMADO: String = "bosque01v1.quemado.c"      ## + «x_y»: una telaraña, la puerta goblin o una torre ya consumidas
const TIPOS_QUEMABLES: PackedStringArray = ["telarana", "puerta_goblin", "torre_goblin"]
const PAUSAS_LIBERAR: PackedFloat32Array = [0.1, 0.4, 1.0]       ## s tras montar en los que se vuelve a liberar la casilla de un objeto quemado (la solidez por colisión tarda unos fotogramas)

## Casillas del mapa horneado (columna, fila) POR DEFECTO: solo valen si el nivel no trae el marcador con su nombre.
const TOTEM_PROPAGACION: Vector2i = Vector2i(18, 25)        ## TF_1 (`totem_fuego_01`)
const TOTEM_ANTORCHAS: Vector2i = Vector2i(19, 8)           ## TF_2 (`totem_fuego_02`)
const TOTEM_SECUENCIA: Vector2i = Vector2i(17, 19)          ## TF_3 (`totem_fuego_03`)
const ANTORCHAS_DEL_TOTEM_2: Array = [Vector2i(18, 9), Vector2i(19, 9)]      ## `brasero_01`, `brasero_02`
## Las cuatro antorchas de TF_3 EN ORDEN: `antorcha_01..04`.
const SECUENCIA: Array = [Vector2i(19, 13), Vector2i(17, 16), Vector2i(17, 11), Vector2i(19, 17)]
const PASO_ARQUEROS: PackedStringArray = ["arquero_paso_01", "arquero_paso_02"]
const ARQUEROS_PASO_DEFECTO: Array = [Vector2i(8, 12), Vector2i(8, 13)]
const ID_LOBERNO: String = "loberno"
## Casillas del cauce que dejan de pisarse al llenarse el estanque (la columna oeste, menos la del tronco).
const COLUMNA_ESTANQUE: Array = [Vector2i(16, 11), Vector2i(16, 12), Vector2i(16, 13), Vector2i(16, 15), Vector2i(16, 16),
		Vector2i(16, 17), Vector2i(16, 18), Vector2i(16, 19), Vector2i(16, 20)]
## Dónde se pisa para marcar los objetivos de recorrido: la tala (x 7-10, filas 1-5) y el prado (x 9-20, filas 11-21), ya al otro lado del paso batido.
const RECT_TALA: Rect2i = Rect2i(7, 1, 4, 5)
const RECT_PRADO_TRAS_PASO: Rect2i = Rect2i(9, 11, 12, 11)

const FASE_ARDIENDO: int = 3             ## PruebaTest2.Fase.ARDIENDO (la maqueta no tiene class_name; 4 = CENIZAS, también cuenta)
const T_SONDEO: float = 0.1              ## s entre comprobaciones (los criterios no necesitan 60 Hz)
const ALCANCE_E: float = 2.7             ## unidades: hablar con la gente (la casilla mide 2,3)
const COLOR_FUEGO: Color = Color(1.0, 0.45, 0.15)
const COLOR_APAGADO: Color = Color(0.42, 0.42, 0.48)
const COLOR_AVISO_LLAVE: Color = Color(1.0, 0.9, 0.6)

# --- La gente ---
const RADIO_ATENCION: float = 2.7        ## u: si te acercas tanto, el NPC deja lo que hace y te mira
const HISTERESIS_ATENCION: float = 0.8   ## u: y vuelve a lo suyo cuando te alejas RADIO_ATENCION + esto
const VEL_ANDAR_NPC: float = 0.9         ## u/s: el goblin y el elfo
const VEL_ANDAR_MARIMANTA: float = 0.45  ## u/s: su andar de anciana
const T_TRABAJO: float = 6.0             ## s talando o cavando
const T_REPOSO: float = 2.0              ## s de idle entre dos tandas
const T_PENSAR: float = 4.0              ## s que Marimanta piensa en cada extremo
const T_HABLA: float = 2.5               ## s con el clip de hablar
const T_CELEBRAR: float = 2.4            ## s del clip de celebrar
const RADIO_SALUDO: float = 9.2          ## u (4 casillas): el elfo saluda la primera vez que te acercas tanto
const RADIO_CELEBRA_FINAL: float = 14.0  ## u: el elfo celebra el elemental caído cuando estás a tanto
const CASILLAS_ELFO_HACIA_PUERTA: int = 2
const RUTA_MARIMANTA: Vector2i = Vector2i(-1, -1)    ## casillas desde su marcador hasta el otro extremo de su paseo
const ID_GOBLIN_BASE: String = "goblin_base"
const ID_ELFO_BASE: String = "elfo_base"
const ID_MARIMANTA: String = "marimanta"
const TOCON: Vector2i = Vector2i(8, 1)               ## el decorado `tocon` del .txt: el goblin lo mira al talar
const CASILLA_CAVAR: Vector2i = Vector2i(9, 2)       ## junto a la tienda goblin (10,2): donde cava cuando el campamento ha caído
const TIENDA_TALA: Vector2i = Vector2i(10, 2)

const DIALOGO_ALQUIMISTA: Array = [
	"Una muestra gratis, que luego no digas. Bébela cuando duela (Q).",
	"Cuatro antorchas del prado de este lado. El orden importa: la del medio, la de abajo, la de arriba y, por último, la de abajo a la derecha.",
	"Un fallo y se apagan todas. A mí ya me ha pasado. Dos veces.",
	"Al tótem del sur no se le enciende con un hechizo: lo despierta el fuego que se contagia. La hierba alta ayuda.",
	"Dicen que al sur del prado hay cuatro cámaras con trastienda. Allí solo sirve la flecha de fuego: braseros, setos, un barril que no es de fiar y una cuerda que sostiene el agua.",
	"Y por el sendero del este, un claro con goblins que no te quieren bien. Llévate fuego.",
]
const DIALOGO_GOBLIN_ANTES: Array = [
	"Mis primos del este cierran el campamento en cuanto entra alguien. La llave del viejo nicho la guardan ellos, en un cofre.",
	"Yo solo corto leña. Aquí no se pelea. Las flechas del paso de abajo no son cosa mía.",
]
const DIALOGO_GOBLIN_DESPUES: Array = [
	"¿Los has echado? Pues ahora busco lo que enterraron junto a la tienda. Toma, por las molestias.",
	"Sigo cavando. Si encuentro algo brillante, es mío.",
]
const DIALOGO_ELFO: Array = [
	"Tres tótems de fuego abren esta puerta, y cada uno despierta a su manera.",
	"Las dos antorchas del norte, a la vez. Las dos, juntas.",
	"Las cuatro de este prado, en orden. La alquimista sabe cuál va primero.",
	"El del sur duerme tras esa cerradura de ahí abajo: la llave está en el campamento del este.",
	"Y a ese se le despierta con fuego que se contagia. La hierba alta ayuda.",
]
const DIALOGO_ELFO_PUERTA: String = "¡La puerta se ha abierto! Ten cuidado: dentro hay un guardián que no ha visto el sol en años."
const DIALOGO_ELFO_FINAL: String = "Lo has derrotado. El cofre del fondo es tuyo."
const DIALOGO_MARIMANTA_ANTES: String = "Esta piedra canta cuando el cristal late. Lo que la abre está ahí abajo, al fondo."
const DIALOGO_MARIMANTA_GLIFO: String = "¿Lo oyes ahora? Haz tú que suene."
const DIALOGO_MARIMANTA_ECO: String = "Queda otra, junto a la explanada. Dicen que guarda un rincón."
const DIALOGO_MARIMANTA_TODO: String = "Ya has oído todo lo que esta tierra tenía que decir."

var m: Variant = null                       ## la maqueta (PruebaTest2); sin tipo: se le llaman métodos suyos
var _jug: Jugador3D = null
var _aviso: Label = null
var _t_aviso: float = 0.0
var _acum: float = 0.0
var _montado: bool = false                  ## `iniciar` terminó: a partir de aquí un cambio de flag es algo que pasa JUGANDO (no una restauración)
var _totems: Dictionary = {}                ## Vector2i -> Reactivo3D (los tres tótems)
var _celdas_totem: Array = [Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO]   ## TF_1, TF_2, TF_3 ya resueltos por nombre (el índice es el de F_TOTEM)
var _sec: Array = []                        ## Reactivo3D de las cuatro antorchas, en orden
var _sec_prev: Array = [false, false, false, false]
var _sec_sig: int = 0                       ## cuántas llevas bien
var _sec_hecha: bool = false
var _antorchas2: Array = []
var _lobernos: Array = []                   ## Pj3D de los lobernos (el modelo; su Combate3D cuelga de la maqueta)
var _arqueros_paso: Array = []              ## Combate3D de los dos arqueros de puesto
var _asesino: Combate3D = null
var _tronco_puente: TroncoPuente3D = null
var _tronco_estanque: TroncoEstanque3D = null
var _columna_cortada: bool = false
var _celda_puerta: Vector2i = Vector2i(-1, -1)
var _puerta: MeshInstance3D = null
var _lamparas: Array = []
var _puerta_abierta: bool = false
var _marca: Dictionary = {}                 ## nombre de marcador -> casilla (leído del .tscn con PackedScene.get_state())
var _puzles: Node = null                    ## el nodo «Puzles» (Puzle3D) de la escena
var _gente: Array = []                      ## {tipo, nombre, pj, ...}: el alquimista y los NPC con rutina
var _lineas_alquimista: int = 0
var _terminado: bool = false
var _quemados: Array = []                   ## los Reactivo3D cuyo consumo se recuerda


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
	for y in range(mapa.size()):
		for x in range(mapa[y].length()):
			if mapa[y][x] == "X":
				_celda_puerta = Vector2i(x, y)
	# Tótems y antorchas: los reactivos que puso la maqueta. Los tótems salen de la capa de hechizos: no se encienden «a pelo».
	var por_celda: Dictionary = {}
	for r in (m.get("_reactivos") as Array):
		if is_instance_valid(r):
			por_celda[r.celda] = r
	_celdas_totem = [_celda("totem_fuego_01", TOTEM_PROPAGACION), _celda("totem_fuego_02", TOTEM_ANTORCHAS), _celda("totem_fuego_03", TOTEM_SECUENCIA)]
	for c in _celdas_totem:
		var t: Variant = por_celda.get(c)
		if t != null and t.tipo == "totem":
			_totems[c] = t
			(t as CollisionObject3D).collision_layer = 0
	for i in range(ANTORCHAS_DEL_TOTEM_2.size()):
		var c2: Vector2i = _celda("brasero_%02d" % (i + 1), ANTORCHAS_DEL_TOTEM_2[i])
		if por_celda.has(c2):
			_antorchas2.append(por_celda[c2])
	for i in range(SECUENCIA.size()):
		var c3: Vector2i = _celda("antorcha_%02d" % (i + 1), SECUENCIA[i])
		if por_celda.has(c3):
			_sec.append(por_celda[c3])
	_poner_arqueros_de_puesto()
	_montar_marcadores_de_datos()
	_buscar_alquimista()
	_persistir_quemados()
	if _celda_puerta.x >= 0:
		_montar_puerta()
	_montar_aviso()
	_definir_mision()
	_restaurar()
	Flags.i().flag_cambio.connect(_al_cambiar_flag)
	_montado = true
	set_process(true)


# ---------------------------------------------------------------------------------------------------------------------
#  Lectura del nivel
# ---------------------------------------------------------------------------------------------------------------------

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
		push_warning("Bosque 01 v01: no hay marcador «%s» en el nivel; se usa la casilla de siempre %s" % [nombre, str(defecto)])
	return defecto


## Los dos arqueros del paso batido (los `A` de las casillas `arquero_paso_01/02`) pasan a ser de PUESTO: no persiguen, disparan desde donde están.
func _poner_arqueros_de_puesto() -> void:
	var celdas: Array = []
	for i in range(PASO_ARQUEROS.size()):
		celdas.append(_celda(String(PASO_ARQUEROS[i]), ARQUEROS_PASO_DEFECTO[i]))
	for n in get_tree().get_nodes_in_group("combate3d"):
		var cb: Combate3D = n as Combate3D
		if cb != null and cb.arquero and celdas.has(Terreno3D.celda_de(cb.casa)):
			cb.fijo = true
			_arqueros_paso.append(cb)


## Lee los marcadores de datos del nivel y crea lo que piden: troncos, lobernos, asesino y gente.
func _montar_marcadores_de_datos() -> void:
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
				if Flags.i().tiene(F_TRONCO_PUENTE):
					_tronco_puente.caer_ya()              # ya cayó en otra visita: se queda de puente
				_tronco_puente.caido.connect(func() -> void: Flags.i().poner(F_TRONCO_PUENTE))
			"tronco_estanque":
				_tronco_estanque = TroncoEstanque3D.new()
				_tronco_estanque.name = "TroncoEstanque"
				m.add_child(_tronco_estanque)
				_tronco_estanque.preparar(m, c)
			"loberno":
				_crear_loberno(c)
			"asesino":
				_asesino = Combate3D.invocar_asesino(m, _jug, _jug.lanz, m.call("_pos_marca", c, m.ALTO)) if _jug != null else null
				if _asesino == null:
					push_warning("Bosque 01 v01: no se pudo crear el goblin asesino de %s" % str(c))
			"npc":
				_crear_npc(String(d["tipo"]), c)


## Un loberno: el modelo (Pj3D) más su Combate3D, como lo hace Jugador3D con los de `_goblins` al montar. Si falta el GLB no sale y se avisa.
func _crear_loberno(c: Vector2i) -> void:
	var pj: Pj3D = m.call("_personaje", [ID_LOBERNO], m.call("_pos_marca", c, m.ALTO))
	if pj == null or _jug == null:
		push_warning("Bosque 01 v01: no se pudo crear el loberno de %s (¿falta arte/modelos/emberheart.glb?)" % str(c))
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
	var npc: Pj3D = null
	for n in (m as Node).find_children("*", "Pj3D", true, false):
		if n is Jugador3D or goblins.has(n):
			continue
		var d: Vector3 = (n as Pj3D).position - centro
		d.y = 0.0
		if d.length() < mejor:
			mejor = d.length()
			npc = n as Pj3D
	if npc != null:
		_gente.append({"tipo": "alquimista", "nombre": "Alquimista", "pj": npc, "t_habla": 0.0, "lineas": 0})


# ---------------------------------------------------------------------------------------------------------------------
#  Lo resuelto que no es una pieza de Puzle3D: telarañas, puerta goblin, torres
# ---------------------------------------------------------------------------------------------------------------------

## Cada telaraña, puerta goblin o torre que se CONSUME pone su flag; al montar, las que ya están consumidas no existen (se liberan sus casillas y se borran).
func _persistir_quemados() -> void:
	for r in (m.get("_reactivos") as Array).duplicate():
		if not is_instance_valid(r) or not TIPOS_QUEMABLES.has(String(r.tipo)):
			continue
		var c: Vector2i = r.celda
		var flag: String = "%s%d_%d" % [PREFIJO_QUEMADO, c.x, c.y]
		if Flags.i().tiene(flag):
			_quitar_reactivo(r)
		else:
			r.consumido.connect(func(_c: Vector2i) -> void: Flags.i().poner(flag))
			_quemados.append(r)


## Lo mismo que cuando se consume: se libera la casilla (la maqueta lo hace al oír `consumido`) y el objeto desaparece.
func _quitar_reactivo(r: Variant) -> void:
	m.call("_liberar", r.celda)
	(r as Node).remove_from_group(Reactivo3D.GRUPO_ARDE)
	(r as Node).remove_from_group(Reactivo3D.GRUPO_REACTIVO)
	(m.get("_reactivos") as Array).erase(r)
	(r as CollisionObject3D).collision_layer = 0
	var celda_r: Vector2i = r.celda
	(r as Node).queue_free()
	# La solidez por colisión de los cuerpos se asienta uno o dos fotogramas DESPUÉS de montar: se libera otra vez cuando ya ha contado (si no, la casilla de la puerta goblin quedaba bloqueada).
	for t in PAUSAS_LIBERAR:
		get_tree().create_timer(t).timeout.connect(func() -> void:
			if m != null and is_instance_valid(m):
				m.call("_liberar", celda_r))


# ---------------------------------------------------------------------------------------------------------------------
#  La puerta de los tótems
# ---------------------------------------------------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------------------------------------------------
#  La misión: se DERIVA de las flags
# ---------------------------------------------------------------------------------------------------------------------

func _definir_mision() -> void:
	if Misiones.i().existe(MISION):
		Misiones.i().activar(MISION)           # volver de otro nivel: no se redefine (perdería lo hecho); `_sincronizar_mision` la pone al día
		return
	var objetivos: Array = [
		"Cruzar el arroyo por el tronco", "Abrir el cofre de la tala (el glifo de barrera)", "Cruzar el paso batido levantando una barrera",
		"Despertar los tres tótems de fuego (0/3)", "Conseguir la llave del campamento goblin", "Abrir la puerta de los tótems",
		"Derrotar al elemental del bosque", "Abrir el cofre final",
		"(Opcional) Derrotar a la patrulla del claro", "(Opcional) Abrir las cuatro cámaras de fuego (0/4)",
		"(Opcional) La Cueva: el glifo del pulso", "(Opcional) Las dos paredes que suenan (0/2)"]
	Misiones.i().definir({"id": MISION, "titulo": "El Bosque (1.ª parte, versión abierta)", "tipo": "principal",
		"texto": "Una barrera para cruzar el paso, una llave en el campamento goblin y tres tótems de fuego, cada uno con su manera de despertar, abren la puerta del fondo. Detrás espera el elemental del bosque.",
		"origen": "Bosque 01 v01", "objetivos": objetivos})
	Misiones.i().activar(MISION)


## Marca cada objetivo según lo que dicen las flags. Idempotente: se llama cada sondeo.
func _sincronizar_mision() -> void:
	var mi: Misiones = Misiones.i()
	if not mi.existe(MISION):
		return
	var n_totems: int = _contar_totems()
	mi.objetivo_texto(MISION, OBJ_TOTEMS, "Despertar los tres tótems de fuego (%d/3)" % n_totems)
	var n_camaras: int = _contar_flags(F_CAMARAS)
	mi.objetivo_texto(MISION, OBJ_CAMARAS, "(Opcional) Abrir las cuatro cámaras de fuego (%d/%d)" % [n_camaras, F_CAMARAS.size()])
	var n_ecos: int = _contar_flags(F_ECOS)
	mi.objetivo_texto(MISION, OBJ_ECOS, "(Opcional) Las dos paredes que suenan (%d/%d)" % [n_ecos, F_ECOS.size()])
	var hechos: Dictionary = {
		OBJ_TALA: Flags.i().tiene(F_TALA_PISADA), OBJ_COFRE_BARRERA: Flags.i().tiene(F_COFRE_BARRERA), OBJ_PASO: Flags.i().tiene(F_PASO_CRUZADO),
		OBJ_TOTEMS: n_totems >= F_TOTEM.size(), OBJ_LLAVE: Flags.i().tiene(F_LLAVE), OBJ_PUERTA: Flags.i().tiene(F_PUERTA_X),
		OBJ_ELEMENTAL: Flags.i().tiene(F_SANTUARIO_LIMPIO), OBJ_COFRE_FINAL: Flags.i().tiene(F_COFRE_FINAL), OBJ_CLARO: Flags.i().tiene(F_CLARO_LIMPIO),
		OBJ_CAMARAS: n_camaras >= F_CAMARAS.size(), OBJ_CUEVA: Flags.i().tiene(F_GLIFO_CUEVA), OBJ_ECOS: n_ecos >= F_ECOS.size()}
	for o in hechos:
		if bool(hechos[o]):
			mi.objetivo_hecho(MISION, int(o))


func _contar_flags(lista: PackedStringArray) -> int:
	var n: int = 0
	for f in lista:
		if Flags.i().tiene(f):
			n += 1
	return n


func _contar_totems() -> int:
	return _contar_flags(F_TOTEM)


# ---------------------------------------------------------------------------------------------------------------------
#  Restaurar lo guardado en flags
# ---------------------------------------------------------------------------------------------------------------------

## Al montar (también al volver de la Cueva): los tótems con su flag se encienden solos y la puerta con su flag ya está abierta.
func _restaurar() -> void:
	for i in range(F_TOTEM.size()):
		var t: Variant = _totems.get(_celdas_totem[i])
		if t != null and Flags.i().tiene(F_TOTEM[i]) and not bool(t.activo):
			_activar(t)
	if _totems.has(_celdas_totem[2]) and Flags.i().tiene(F_TOTEM[2]):
		_sec_hecha = true
	for i in range(mini(_contar_totems(), _lamparas.size())):
		_encender_lampara(i, true)
	if Flags.i().tiene(F_PUERTA_X) and _celda_puerta.x >= 0:
		_abrir_puerta(true)


# ---------------------------------------------------------------------------------------------------------------------
#  Fotograma
# ---------------------------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if m == null or m.get("_jugador") == null:
		return
	_t_aviso = maxf(_t_aviso - delta, 0.0)
	if _t_aviso <= 0.0 and _aviso != null:
		_aviso.text = ""
	_gente_tick(delta)
	_acum += delta
	if _acum < T_SONDEO:
		return
	_acum = 0.0
	_criterio_propagacion()
	_criterio_antorchas()
	_criterio_secuencia()
	_guardar_totems()
	_revisar_totems_y_puerta()
	_revisar_estanque()
	_vigilar_recorrido()
	_sincronizar_mision()


## Los objetivos de recorrido: pisar la tala (se cruzó el arroyo) y llegar al prado desde la pasarela (el paso batido, superado).
func _vigilar_recorrido() -> void:
	var c: Vector2i = Terreno3D.celda_de((m.get("_jugador") as Pj3D).position)
	if RECT_TALA.has_point(c):
		Flags.i().poner(F_TALA_PISADA)
	if RECT_PRADO_TRAS_PASO.has_point(c) and Flags.i().tiene(F_TALA_PISADA):
		Flags.i().poner(F_PASO_CRUZADO)


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


# ---------------------------------------------------------------------------------------------------------------------
#  Los tres tótems de fuego
# ---------------------------------------------------------------------------------------------------------------------

## TF_1: se despierta cuando el fuego se ha contagiado a su lado (la casilla del tótem o alguna vecina arde o ya es ceniza).
func _criterio_propagacion() -> void:
	var c0: Vector2i = _celdas_totem[0]
	var t: Variant = _totems.get(c0)
	if t == null or bool(t.activo):
		return
	var hf: Dictionary = m.get("_hf")
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var q: Vector2i = c0 + Vector2i(dx, dy)
			if hf.has(q) and int((hf[q] as Dictionary)["fase"]) >= FASE_ARDIENDO:
				_activar(t)
				return


## TF_2: las dos antorchas de su lado arden a la vez.
func _criterio_antorchas() -> void:
	var t: Variant = _totems.get(_celdas_totem[1])
	if t == null or bool(t.activo) or _antorchas2.is_empty():
		return
	for r in _antorchas2:
		if not is_instance_valid(r) or not bool(r.is_lit):
			return
	_activar(t)


## TF_3: T_1..T_4 en orden. Cada antorcha que se enciende se compara con la que tocaba; si no es esa, se apagan todas y se empieza de cero.
func _criterio_secuencia() -> void:
	var t: Variant = _totems.get(_celdas_totem[2])
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


## Un tótem que se ha activado (por su criterio) deja su flag: así vuelve encendido.
func _guardar_totems() -> void:
	for i in range(F_TOTEM.size()):
		var t: Variant = _totems.get(_celdas_totem[i])
		if t != null and bool(t.activo):
			Flags.i().poner(F_TOTEM[i])


func _revisar_totems_y_puerta() -> void:
	var n: int = _contar_totems()
	for i in range(mini(n, _lamparas.size())):
		_encender_lampara(i, false)
	if n >= F_TOTEM.size() and not _puerta_abierta and _celda_puerta.x >= 0:
		_abrir_puerta(false)


func _encender_lampara(i: int, en_silencio: bool) -> void:
	var lamp: MeshInstance3D = _lamparas[i]
	if lamp.has_meta("encendida"):
		return
	lamp.set_meta("encendida", true)
	lamp.set_surface_override_material(0, Formas3D.material_tinte(COLOR_FUEGO, false, "llama"))
	if en_silencio:
		return
	if m.get("_fx") != null:
		(m.get("_fx") as Vfx3D).chispazo(lamp.position, "fuego")
	_decir("Tótem activado (%d/3)" % _contar_lamparas(), 3.0)


func _contar_lamparas() -> int:
	var n: int = 0
	for l in _lamparas:
		if (l as Node).has_meta("encendida"):
			n += 1
	return n


## Abre la puerta de los tótems y lo recuerda en la flag. `ya`: sin animación ni aviso (al montar con la flag puesta).
func _abrir_puerta(ya: bool) -> void:
	_puerta_abierta = true
	Flags.i().poner(F_PUERTA_X)
	m.call("_liberar", _celda_puerta)
	if ya:
		for i in range(_lamparas.size()):
			_encender_lampara(i, true)
		if _puerta != null:
			_puerta.hide()
		return
	_decir("¡La puerta se abre!", 4.0)
	if _puerta != null:
		var tw := create_tween()
		tw.tween_property(_puerta, "position:y", _puerta.position.y - 2.4, 1.4).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(_puerta.hide)


## Lo que pasa jugando y se cuenta en pantalla (no al montar: `_montado`).
func _al_cambiar_flag(nombre: String, valor: Variant) -> void:
	if not _montado or valor == null or (valor is bool and valor == false):
		return
	match nombre:
		F_LINDE_LIMPIA:
			_decir("El goblin ha caído. En la tala, algo brilla.", 5.0)
		F_PASO_LIMPIO:
			_decir("Los arqueros han caído: el paso queda libre.", 4.0)
		F_CLARO_LIMPIO:
			_decir("La patrulla ha caído. En el claro, algo brilla.", 5.0)
		F_CAMPAMENTO_LIMPIO:
			_decir("El campamento ha caído. Hay un cofre junto a la fogata.", 5.0)
		F_LLAVE:
			_decir("Has cogido la llave pequeña del campamento. Abre la cerradura del nicho del sur.", 6.0)
			var lz: Node = get_tree().get_first_node_in_group("spellcaster")
			if lz != null and lz.has_method("avisar"):
				lz.call("avisar", "Llave pequeña conseguida", COLOR_AVISO_LLAVE)
		F_SANTUARIO_LIMPIO:
			_decir("El elemental ha caído. Hay un cofre al fondo.", 5.0)
		F_COFRE_FINAL:
			_terminado = true
			var pz: Variant = (_puzles as Puzle3D).pieza("cofre_02") if _puzles != null else null
			var pos_fin: Vector3 = ((pz.nodo as Node3D).position + Vector3.UP) if pz != null and is_instance_valid(pz.nodo) else Vector3.ZERO
			Mundo3D.avisar_logro("nivel_completado", pos_fin, pz.nodo if pz != null else null)
			_decir("Fin de la demo. Gracias por jugar el Bosque.", 10.0)


# ---------------------------------------------------------------------------------------------------------------------
#  La gente: el goblin leñador, el elfo y Marimanta
# ---------------------------------------------------------------------------------------------------------------------

func _crear_npc(tipo: String, c: Vector2i) -> void:
	var nombre: String = {ID_GOBLIN_BASE: "Goblin leñador", ID_ELFO_BASE: "Elfo", ID_MARIMANTA: "Marimanta"}.get(tipo, tipo)
	var pj: Pj3D = m.call("_npc", [tipo], m.call("_pos_marca", c, m.ALTO))
	if pj == null:
		push_warning("Bosque 01 v01: no se pudo crear el NPC «%s» de %s (falta su GLB)" % [tipo, str(c)])
		return
	var g: Dictionary = {"tipo": tipo, "nombre": nombre, "pj": pj, "casa": pj.position, "celda": c, "estado": "trabajo", "t": T_TRABAJO, "atento": false, "t_habla": 0.0,
		"lineas": 0, "bloquea": false, "ruta": 0}
	match tipo:
		ID_GOBLIN_BASE:
			g["mira"] = m.call("_centro_celda", TOCON, 0.0)
			g["punto"] = m.call("_pos_marca", CASILLA_CAVAR, m.ALTO)
			g["en_zanja"] = false
			pj.mirar((g["mira"] as Vector3) - pj.position, 1.0)
			_bloquear_npc(g, c)
			if Flags.i().tiene(F_CAMPAMENTO_LIMPIO):
				_liberar_npc(g)
				pj.position = g["punto"]                 # el campamento ya cayó en otra visita: cava desde el principio
				g["en_zanja"] = true
				g["mira"] = m.call("_centro_celda", TIENDA_TALA, 0.0)
				_bloquear_npc(g, CASILLA_CAVAR)
		ID_ELFO_BASE:
			g["estado"] = "espera"
			g["destino"] = _destino_elfo(c)
			_bloquear_npc(g, c)
			g["celebro_puerta"] = Flags.i().tiene(F_ELFO_CELEBRA_PUERTA) or Flags.i().tiene(F_PUERTA_X)
			if Flags.i().tiene(F_PUERTA_X):
				_liberar_npc(g)
				pj.position = g["destino"]               # la puerta ya se abrió en otra visita: ya está junto a ella
				_bloquear_npc(g, Terreno3D.celda_de(pj.position))
				pj.mirar(m.call("_centro_celda", _celda_puerta, 0.0) - pj.position, 1.0)
		ID_MARIMANTA:
			g["estado"] = "anda"
			g["rutas"] = [pj.position, m.call("_pos_marca", c + RUTA_MARIMANTA, m.ALTO)]
	_gente.append(g)


## A dónde camina el elfo al abrirse la puerta: CASILLAS_ELFO_HACIA_PUERTA casillas hacia ella (por la fila de la puerta, desde el oeste).
func _destino_elfo(c: Vector2i) -> Vector3:
	var p: Vector2i = _celda_puerta if _celda_puerta.x >= 0 else c + Vector2i(CASILLAS_ELFO_HACIA_PUERTA + 1, 1)
	return m.call("_pos_marca", Vector2i(p.x - 1, p.y), m.ALTO)


func _bloquear_npc(g: Dictionary, c: Vector2i) -> void:
	if bool(g["bloquea"]):
		return
	m.call("_bloquear", c)
	g["bloquea"] = true
	g["celda_bloq"] = c


func _liberar_npc(g: Dictionary) -> void:
	if not bool(g["bloquea"]):
		return
	m.call("_liberar", g["celda_bloq"])
	g["bloquea"] = false


## Distancia en el suelo (u) entre dos puntos.
static func _dist(a: Vector3, b: Vector3) -> float:
	var d: Vector3 = a - b
	d.y = 0.0
	return d.length()


func _gente_tick(delta: float) -> void:
	var jugador: Pj3D = m.get("_jugador") as Pj3D
	for g in _gente:
		var pj: Pj3D = (g as Dictionary)["pj"] as Pj3D
		if pj == null or not is_instance_valid(pj):
			continue
		var gd: Dictionary = g
		if float(gd["t_habla"]) > 0.0:
			gd["t_habla"] = float(gd["t_habla"]) - delta
			pj.mirar(jugador.position - pj.position, delta)
			if float(gd["t_habla"]) <= 0.0:
				pj.animacion_actual = ""
				pj.jugar("idle")
			continue
		match String(gd["tipo"]):
			ID_GOBLIN_BASE:
				_rutina_goblin(gd, pj, jugador, delta)
			ID_ELFO_BASE:
				_rutina_elfo(gd, pj, jugador, delta)
			ID_MARIMANTA:
				_rutina_marimanta(gd, pj, jugador, delta)


## El NPC deja lo que hace y mira a la jugadora si está a ≤ RADIO_ATENCION (con histéresis). Devuelve true mientras la atiende.
func _atender(g: Dictionary, pj: Pj3D, jugador: Pj3D, delta: float) -> bool:
	var d: float = _dist(jugador.position, pj.position)
	var radio: float = RADIO_ATENCION + (HISTERESIS_ATENCION if bool(g["atento"]) else 0.0)
	g["atento"] = d <= radio
	if not bool(g["atento"]):
		return false
	pj.mirar(jugador.position - pj.position, delta)
	pj.jugar("idle")
	return true


## Anda hacia `meta` (plano XZ) a `vel` u/s. Devuelve true al llegar (queda exactamente en ella).
func _ir_a(pj: Pj3D, meta: Vector3, vel: float, delta: float) -> bool:
	var d: Vector3 = meta - pj.position
	d.y = 0.0
	if d.length() <= vel * delta + 0.02:
		pj.position = Vector3(meta.x, pj.position.y, meta.z)
		return true
	pj.position += d.normalized() * vel * delta
	pj.mirar(d, delta)
	pj.jugar("walk")
	return false


## Alterna una tanda de trabajo (T_TRABAJO) y un reposo (T_REPOSO). Devuelve true si toca trabajar ahora.
func _tanda(g: Dictionary, delta: float) -> bool:
	g["t"] = float(g["t"]) - delta
	if float(g["t"]) <= 0.0:
		if String(g["estado"]) == "trabajo":
			g["estado"] = "reposo"
			g["t"] = T_REPOSO
		else:
			g["estado"] = "trabajo"
			g["t"] = T_TRABAJO
	return String(g["estado"]) == "trabajo"


## Goblin leñador: tala mirando al tocón; con el campamento caído se va junto a la tienda y cava.
func _rutina_goblin(g: Dictionary, pj: Pj3D, jugador: Pj3D, delta: float) -> void:
	if _atender(g, pj, jugador, delta):
		return
	var limpio: bool = Flags.i().tiene(F_CAMPAMENTO_LIMPIO)
	if limpio and not bool(g["en_zanja"]):
		_liberar_npc(g)
		if _ir_a(pj, g["punto"], VEL_ANDAR_NPC, delta):
			g["en_zanja"] = true
			g["mira"] = m.call("_centro_celda", TIENDA_TALA, 0.0)
			_bloquear_npc(g, CASILLA_CAVAR)
		return
	if _tanda(g, delta):
		pj.mirar((g["mira"] as Vector3) - pj.position, delta)
		pj.jugar("cavar" if limpio else "talar")
	else:
		pj.jugar("idle")


## Elfo: espera junto a la puerta; saluda la primera vez que te acercas; al abrirse la puerta celebra y camina hacia ella; al caer el elemental celebra otra vez.
func _rutina_elfo(g: Dictionary, pj: Pj3D, jugador: Pj3D, delta: float) -> void:
	var d: float = _dist(jugador.position, pj.position)
	match String(g["estado"]):
		"espera":
			if Flags.i().tiene(F_PUERTA_X) and not bool(g["celebro_puerta"]):
				g["celebro_puerta"] = true
				Flags.i().poner(F_ELFO_CELEBRA_PUERTA)
				_empezar_celebracion(g, pj, "camina")
				return
			if Flags.i().tiene(F_SANTUARIO_LIMPIO) and not Flags.i().tiene(F_ELFO_CELEBRA_FINAL) and d <= RADIO_CELEBRA_FINAL:
				Flags.i().poner(F_ELFO_CELEBRA_FINAL)
				_empezar_celebracion(g, pj, "espera")
				return
			if not Flags.i().tiene(F_ELFO_SALUDO) and d <= RADIO_SALUDO:
				Flags.i().poner(F_ELFO_SALUDO)
				pj.mirar(jugador.position - pj.position, 1.0)
				pj.animacion_actual = ""
				pj.jugar("saludo", true)
				g["estado"] = "saludando"
				g["t"] = maxf(pj.duracion("saludo"), T_CELEBRAR)
				return
			if d <= RADIO_ATENCION * 3.0:
				pj.mirar(jugador.position - pj.position, delta)
			pj.jugar("idle")
		"saludando", "celebrando":
			g["t"] = float(g["t"]) - delta
			if float(g["t"]) <= 0.0:
				g["estado"] = String(g.get("siguiente", "espera")) if String(g["estado"]) == "celebrando" else "espera"
				pj.animacion_actual = ""
		"camina":
			_liberar_npc(g)
			if _ir_a(pj, g["destino"], VEL_ANDAR_NPC, delta):
				g["estado"] = "espera"
				pj.mirar(m.call("_centro_celda", _celda_puerta, 0.0) - pj.position, 1.0)
				_bloquear_npc(g, Terreno3D.celda_de(pj.position))


func _empezar_celebracion(g: Dictionary, pj: Pj3D, siguiente: String) -> void:
	pj.animacion_actual = ""
	pj.jugar("celebrar", true)
	g["estado"] = "celebrando"
	g["siguiente"] = siguiente
	g["t"] = maxf(pj.duracion("celebrar"), T_CELEBRAR)


## Marimanta: anda despacio entre dos extremos y piensa T_PENSAR s en cada uno; si te acercas, te mira.
func _rutina_marimanta(g: Dictionary, pj: Pj3D, jugador: Pj3D, delta: float) -> void:
	if _atender(g, pj, jugador, delta):
		return
	if String(g["estado"]) == "pensar":
		g["t"] = float(g["t"]) - delta
		pj.jugar("pensar")
		if float(g["t"]) <= 0.0:
			g["estado"] = "anda"          # el extremo ya se cambió al llegar: ahora va al otro
		return
	var meta: Vector3 = (g["rutas"] as Array)[1 - int(g["ruta"])]
	if _ir_a(pj, meta, VEL_ANDAR_MARIMANTA, delta):
		g["ruta"] = 1 - int(g["ruta"])
		g["estado"] = "pensar"
		g["t"] = T_PENSAR


# ---------------------------------------------------------------------------------------------------------------------
#  Hablar (E)
# ---------------------------------------------------------------------------------------------------------------------

func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or m == null or m.get("_jugador") == null:
		return
	var k: InputEventKey = ev as InputEventKey
	if not k.pressed or k.echo or k.keycode != KEY_E:
		return
	var yo: Vector3 = (m.get("_jugador") as Pj3D).position
	var mejor: Dictionary = {}
	var d_mejor: float = ALCANCE_E
	for g in _gente:
		var pj: Pj3D = (g as Dictionary)["pj"] as Pj3D
		if pj == null or not is_instance_valid(pj):
			continue
		var d: float = _dist(pj.position, yo)
		if d <= d_mejor:
			d_mejor = d
			mejor = g
	if not mejor.is_empty():
		_hablar(mejor, yo)


func _hablar(g: Dictionary, yo: Vector3) -> void:
	var pj: Pj3D = g["pj"] as Pj3D
	var texto: String = _texto_de(g)
	if texto == "":
		return
	_decir("%s: «%s»" % [String(g["nombre"]), texto], 6.0)
	pj.mirar(yo - pj.position, 1.0)
	pj.animacion_actual = ""
	pj.jugar("talk")
	Sfx3D.play(pj, "conversacion_voz")
	g["t_habla"] = T_HABLA


## Lo que dice cada uno según lo que ha pasado (las flags).
func _texto_de(g: Dictionary) -> String:
	var n: int = int(g["lineas"])
	match String(g["tipo"]):
		"alquimista":
			var texto: String = String(DIALOGO_ALQUIMISTA[n % DIALOGO_ALQUIMISTA.size()])
			g["lineas"] = n + 1
			Sintesis.abrir("alquimista")               # F3: su taller (la interfaz es del Pipeline)
			if not Flags.i().tiene(F_MUESTRA):
				if Estado.i().agregar("pocion", 1) > 0:
					Flags.i().poner(F_MUESTRA)
				else:
					g["lineas"] = n
					texto = "Tu bolsa no tiene hueco para la muestra. Vuelve con un sitio libre."
			return texto
		ID_GOBLIN_BASE:
			g["lineas"] = n + 1
			if Flags.i().tiene(F_CAMPAMENTO_LIMPIO):
				if not Flags.i().tiene(F_POCION_GOBLIN) and Estado.i().agregar("pocion", 1) > 0:
					Flags.i().poner(F_POCION_GOBLIN)
					return String(DIALOGO_GOBLIN_DESPUES[0])
				return String(DIALOGO_GOBLIN_DESPUES[1])
			return String(DIALOGO_GOBLIN_ANTES[n % DIALOGO_GOBLIN_ANTES.size()])
		ID_ELFO_BASE:
			g["lineas"] = n + 1
			if Flags.i().tiene(F_SANTUARIO_LIMPIO):
				return DIALOGO_ELFO_FINAL
			if Flags.i().tiene(F_PUERTA_X):
				return DIALOGO_ELFO_PUERTA
			return String(DIALOGO_ELFO[n % DIALOGO_ELFO.size()])
		ID_MARIMANTA:
			g["lineas"] = n + 1
			if _contar_flags(F_ECOS) >= F_ECOS.size():
				return DIALOGO_MARIMANTA_TODO
			if Flags.i().tiene(F_ECOS[0]):
				return DIALOGO_MARIMANTA_ECO
			if Flags.i().tiene(F_GLIFO_CUEVA):
				return DIALOGO_MARIMANTA_GLIFO
			return DIALOGO_MARIMANTA_ANTES
	return ""


func _decir(texto: String, seg: float) -> void:
	if _aviso != null:
		_aviso.text = texto
	_t_aviso = seg
