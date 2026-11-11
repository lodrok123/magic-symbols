extends Node

## REGLAS DEL NIVEL «BOSQUE 02 · El corazón del Bosque» (Juego, 3/11). docs/PLAN_BOSQUE_02.md.
## Mapa: mundo/datos_nivel/mapas/Bosque_02.txt (40 × 40, anillo de 4 casillas de árboles) · Nivel horneado: mundo/datos_nivel/Nivel_Bosque_02.tscn (herramientas/hornear_bosque_02.gd) · Escena: escenas/PruebaBosque02.tscn.
##
## Casi todo el nivel son piezas de Puzle3D (líneas `; pieza` / `; puzle` del .txt: cofres, puertas, cerrojos, vigías, el molino, la tinaja, el puente, el bloque…). Este script pone lo que
## el mapa no puede decir con una línea:
##   · LA MISIÓN PRINCIPAL «El corazón del Bosque» (7 objetivos DERIVADOS de flags en cada sondeo; `fijar_punto` solo al objetivo activo) y las cuatro secundarias.
##   · LOS TRES TÓTEMS (fuego, agua y rayo: Reactivo3D `totem`): al despertarse dejan su flag y al volver al nivel se despiertan solos; con los tres se pone `bosque02.ruinas.totems`, la «llave» de la puerta de las ruinas.
##   · LO QUE SE CONSUME: telarañas, puerta goblin y torres (flag `bosque02.quemado.c<x>_<y>`: al volver de la Cueva ya no están); la torre este además pone `bosque02.torre.quemada` (aparece su cofre).
##   · LA PLACA DE PESO (Reactivo3D `placa`): el bloque empujado encima pone `bosque02.ruinas.placa` (aparece el cofre épico de la trastienda).
##   · EL ARROYO: pisar la orilla este (o cualquier sitio del este) pone `bosque02.arroyo.cruzado`.
##   · LOS MARCADORES DE DATOS: el tronco-puente (cae con fuego), los lobernos y el asesino.
##   · LA GENTE: la guardabosques de la linde (`m`) y la librera de la plaza (`M`) con las pistas de cada cosa; los braseros de los cruces nacen encendidos (luz = «por aquí»).
##   · EL FINAL: abrir el cofre legendario del corazón (`bosque02.santuario.cofre`) acaba la demo (logro `nivel_completado`, rótulo y, a los 10 s, el menú principal).
##
## Los marcadores se leen POR NOMBRE del .tscn (`PackedScene.get_state()`, sin instanciar el nivel). Un nombre que falta cae a la casilla de siempre (las constantes de abajo) y avisa con push_warning.

const MISION: String = "bosque_02"
const MISION_CAMPAMENTO: String = "bosque_02_campamento"
const MISION_MOLINO: String = "bosque_02_molino"
const MISION_PIEDRA: String = "bosque_02_piedra"
const MISION_COFRES: String = "bosque_02_cofres"
const OBJ_BRASEROS: int = 0
const OBJ_ARROYO: int = 1
const OBJ_PRADERA: int = 2
const OBJ_RUINAS: int = 3
const OBJ_CAMPAMENTO: int = 4
const OBJ_ELEMENTAL: int = 5
const OBJ_COFRE: int = 6
const N_OBJ: int = 7

# --- Flags (nivel.sala.hecho). Las de piezas de Puzle3D están declaradas en el .txt; aquí las que pone o lee este script ---
const F_BRASEROS: String = "bosque02.linde.braseros"
const F_ARROYO: String = "bosque02.arroyo.cruzado"
const F_PRADERA: String = "bosque02.pradera.limpia"
const F_TOTEM: PackedStringArray = ["bosque02.totem.fuego", "bosque02.totem.agua", "bosque02.totem.rayo"]
const F_TOTEMS: String = "bosque02.ruinas.totems"
const F_CAMP_LIMPIO: String = "bosque02.campamento.limpio"
const F_CAMP_COFRE: String = "bosque02.campamento.cofre"
const F_LLAVE: String = "bosque02.santuario.llave"
const F_SANT_LIMPIO: String = "bosque02.santuario.limpio"
const F_COFRE_FINAL: String = "bosque02.santuario.cofre"
const F_TORRE: String = "bosque02.torre.quemada"
const F_PLACA: String = "bosque02.ruinas.placa"
const F_MOLINO: String = "bosque02.estanque.molino"
const F_COMPUERTA: String = "bosque02.estanque.compuerta"
const F_COFRE_MOLINO_EPICO: String = "bosque02.estanque.cofre"
const F_COFRE_PIEDRA: String = "bosque02.trastienda.cofre"
const F_TRONCO_PUENTE: String = "bosque02.tronco_puente.caido"
const F_GUARDA_SALUDO: String = "bosque02.guardabosques.saludo"
const F_FIN: String = "bosque02.fin.demo"
## Los siete cofres COMUNES (misión «Siete cofres»).
const F_COFRES_COMUNES: PackedStringArray = ["bosque02.linde.cofre", "bosque02.orilla.cofre", "bosque02.pradera.cofre", "bosque02.molino.cofre", "bosque02.torre.cofre", "bosque02.ruinas.cofre", "bosque02.escondite.cofre"]
const PREFIJO_QUEMADO: String = "bosque02.quemado.c"      ## + «x_y»: una telaraña, la puerta goblin o una torre ya consumidas
const TIPOS_QUEMABLES: PackedStringArray = ["telarana", "puerta_goblin", "torre_goblin", "seto", "tronco"]
const PAUSAS_LIBERAR: PackedFloat32Array = [0.1, 0.4, 1.0]       ## s tras montar en los que se vuelve a liberar la casilla de un objeto quemado

## Casillas del mapa horneado (columna, fila) POR DEFECTO: solo valen si el nivel no trae el marcador con su nombre.
const TOTEMS_DEFECTO: Array = [Vector2i(22, 6), Vector2i(19, 5), Vector2i(21, 10)]       ## fuego, agua, rayo (`totem_fuego_02`, `totem_agua_02`, `totem_rayo_02`)
const NOMBRES_TOTEM: PackedStringArray = ["totem_fuego_02", "totem_agua_02", "totem_rayo_02"]
const BRASEROS_LINDE: PackedStringArray = ["brasero_linde_a", "brasero_linde_b"]
const BRASEROS_LINDE_DEFECTO: Array = [Vector2i(10, 30), Vector2i(10, 34)]
const BRASEROS_GUIA: PackedStringArray = ["brasero_guia_01", "brasero_guia_02", "brasero_guia_03"]
const BRASEROS_GUIA_DEFECTO: Array = [Vector2i(19, 27), Vector2i(21, 15), Vector2i(21, 8)]
const TORRE_ESTE_DEFECTO: Vector2i = Vector2i(34, 13)
const PLACA_DEFECTO: Vector2i = Vector2i(9, 10)
const ARQUERO_FIJO_DEFECTO: Vector2i = Vector2i(34, 17)
const PUERTA_GOBLIN_DEFECTO: Vector2i = Vector2i(28, 16)
const PUERTA_SANTUARIO: Vector2i = Vector2i(8, 12)
const PUERTA_RUINAS: Vector2i = Vector2i(7, 7)
const TRONCO_BASE: Vector2i = Vector2i(13, 31)
const ELEMENTAL_DEFECTO: Vector2i = Vector2i(8, 16)
const COFRE_CAMPAMENTO: Vector2i = Vector2i(34, 16)
const COFRE_CORAZON: Vector2i = Vector2i(8, 18)
const GUARDA_DEFECTO: Vector2i = Vector2i(9, 31)
const LIBRERA_DEFECTO: Vector2i = Vector2i(10, 11)
## Dónde se pisa para dar por cruzado el arroyo (todo el este y el sur del mapa, a partir de la orilla) y el centro de la pradera (para el punto de la misión).
const RECT_ESTE: Rect2i = Rect2i(16, 22, 20, 14)
const CENTRO_PRADERA: Vector2i = Vector2i(21, 16)
const ID_LOBERNO: String = "loberno"
const ID_CANOURO: String = "canouro"

const T_SONDEO: float = 0.1              ## s entre comprobaciones
const ALCANCE_E: float = 2.7             ## unidades: hablar con la gente (la casilla mide 2,3)
const T_FIN_A_MENU: float = 10.0         ## s entre el cofre del corazón y la vuelta al menú principal
const MOTIVO_AUTOGUARDADO: String = "menu"
const RADIO_SALUDO: float = 9.2          ## u (4 casillas): la guardabosques saluda la primera vez que te acercas tanto
const RADIO_ATENCION: float = 2.7
const HISTERESIS_ATENCION: float = 0.8
const T_HABLA: float = 2.5
const COLOR_AVISO_LLAVE: Color = Color(1.0, 0.9, 0.6)

## Las pruebas lo ponen a false: acabar la demo NO cambia de escena (cambiaría la escena de la prueba por el menú).
var volver_al_menu: bool = true

const DIALOGO_GUARDA: Array = [
	"Bienvenida a la linde. Enciende los dos braseros con una chispa de fuego y mira qué guarda el bosque.",
	"El tronco seco de la orilla cae con una llama y hace de puente. Cruza y sigue el camino de tierra.",
	"Al norte de la linde hay un muro agrietado. La tierra lo rompe, y detrás alguien escondió algo.",
	"Junto a la linde hay dos ramales de hierba. Moja el extremo que da al camino y prende la bifurcación para guiar la llama hacia el brasero.",
	"Más allá del arroyo está la pradera alta: goblins, lobernos y hierba que arde. No les des fuego donde pisas.",
	"El arquero vigila la puerta del campamento. Por el hueco lateral verás un cuenco de agua. Con fuego puedes levantar vapor y avanzar a cubierto.",
]
const DIALOGO_GUARDA_BRASEROS: String = "¡Los dos braseros! Así se hace. Ahora el tronco: un fuego sobre él y cae sobre el arroyo."
const DIALOGO_GUARDA_FIN: String = "El corazón del Bosque late otra vez. Gracias, de parte de todos los que vivimos aquí."
const DIALOGO_LIBRERA: Array = [
	"Tres tótems guardan la sala del tesoro de estas ruinas: el del fuego, tras unas telarañas; el del agua, tras una reja; el del rayo, al final de una cadena.",
	"La reja del tótem de agua se abre cuando la cuenca de aquí se llena. Echa agua a la tinaja, aunque sea de lejos, desde la otra orilla.",
	"El tótem de rayo no oye hechizos: lo despierta la corriente de la fuente. Pero la pila del medio, seca, la corta. Mójala.",
	"La llave del santuario la guardan los goblins del este, en su cofre. Sin ella la puerta de piedra no se mueve.",
	"Una piedra sobre la placa del suelo abre un tesoro de la trastienda. Empújala andando contra ella.",
]
const DIALOGO_LIBRERA_TOTEMS: String = "¡Los tres tótems despiertos! La puerta de la sala del tesoro ya cede."
const DIALOGO_LIBRERA_FIN: String = "El elemental ha caído. Dicen que su cofre guarda el último glifo del Bosque."

var m: Variant = null                       ## la maqueta (PruebaTest2); sin tipo: se le llaman métodos suyos
var _jug: Jugador3D = null
var _aviso: Label = null
var _t_aviso: float = 0.0
var _acum: float = 0.0
var _montado: bool = false
var _totems: Array = [null, null, null]     ## Reactivo3D de los tres tótems (fuego, agua, rayo)
var _celdas_totem: Array = [Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO]
var _braseros_linde: Array = []             ## Reactivo3D de los dos braseros de la linde
var _braseros_celda: Array = []
var _torre_este: Vector2i = TORRE_ESTE_DEFECTO
var _celda_puerta_goblin: Vector2i = PUERTA_GOBLIN_DEFECTO
var _celda_placa: Vector2i = PLACA_DEFECTO
var _placa: Variant = null
var _celda_elemental: Vector2i = ELEMENTAL_DEFECTO
var _lobernos: Array = []
var _canouros: Array = []
var _asesino: Combate3D = null
var _tronco_puente: TroncoPuente3D = null
var _arquero_fijo: Combate3D = null
var _marca: Dictionary = {}                 ## nombre de marcador -> casilla (leído del .tscn con PackedScene.get_state())
var _puzles: Node = null
var _gente: Array = []
var _terminado: bool = false
var _quemados: Array = []


func _ready() -> void:
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
	_leer_marcas_por_nombre()
	_puzles = (m as Node).get_node_or_null("Puzles")
	var por_celda: Dictionary = {}
	for r in (m.get("_reactivos") as Array):
		if is_instance_valid(r):
			por_celda[r.celda] = r
	for i in range(3):
		_celdas_totem[i] = _celda(String(NOMBRES_TOTEM[i]), TOTEMS_DEFECTO[i])
		var t: Variant = por_celda.get(_celdas_totem[i])
		if t != null and t.tipo == "totem":
			_totems[i] = t
	for i in range(BRASEROS_LINDE.size()):
		var cb: Vector2i = _celda(String(BRASEROS_LINDE[i]), BRASEROS_LINDE_DEFECTO[i])
		_braseros_celda.append(cb)
		if por_celda.has(cb):
			_braseros_linde.append(por_celda[cb])
	for i in range(BRASEROS_GUIA.size()):
		var cg: Vector2i = _celda(String(BRASEROS_GUIA[i]), BRASEROS_GUIA_DEFECTO[i])
		var rg: Variant = por_celda.get(cg)
		if rg != null and rg.tipo == "brasero" and not bool(rg.is_lit):
			rg.encender_llama()                 # los braseros de los cruces nacen encendidos: su luz es la señal de «por aquí»
	_torre_este = _celda("torre_este", TORRE_ESTE_DEFECTO)
	_celda_puerta_goblin = _celda("puerta_goblin_02", PUERTA_GOBLIN_DEFECTO)
	_celda_elemental = _celda("elemental_02", ELEMENTAL_DEFECTO)
	_celda_placa = _celda("placa_ruinas", PLACA_DEFECTO)
	var pl: Variant = por_celda.get(_celda_placa)
	if pl != null and pl.tipo == "placa":
		_placa = pl
		pl.activado.connect(func(_t: String, _e: String) -> void: Flags.i().poner(F_PLACA))
	for i in range(3):
		var tt: Variant = _totems[i]
		if tt != null:
			var idx: int = i
			tt.activado.connect(func(_t: String, _e: String) -> void: Flags.i().poner(F_TOTEM[idx]))
	_poner_arquero_de_puesto()
	_montar_marcadores_de_datos()
	_buscar_gente()
	_persistir_quemados()
	_montar_aviso()
	_definir_misiones()
	_restaurar()
	Flags.i().flag_cambio.connect(_al_cambiar_flag)
	_montado = true
	set_process(true)


# ---------------------------------------------------------------------------------------------------------------------
#  Lectura del nivel
# ---------------------------------------------------------------------------------------------------------------------

## Lee del .tscn del nivel la casilla de cada marcador con nombre, SIN instanciarlo (como el Bosque 01 v01).
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
		var ruta_nodo: String = String(est.get_node_path(i)).trim_prefix("./")
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


## La casilla del marcador `nombre`; si el nivel no lo trae, `defecto` (y se avisa).
func _celda(nombre: String, defecto: Vector2i) -> Vector2i:
	if _marca.has(nombre):
		return _marca[nombre]
	if not _marca.is_empty():
		push_warning("Bosque 02: no hay marcador «%s» en el nivel; se usa la casilla de siempre %s" % [nombre, str(defecto)])
	return defecto


## El arquero de la casilla `arquero_fijo_01` pasa a ser de PUESTO: no persigue, dispara desde donde está (el otro arquero del campamento sí persigue).
func _poner_arquero_de_puesto() -> void:
	var c: Vector2i = _celda("arquero_fijo_01", ARQUERO_FIJO_DEFECTO)
	for n in get_tree().get_nodes_in_group("combate3d"):
		var cb: Combate3D = n as Combate3D
		if cb != null and cb.arquero and Terreno3D.celda_de(cb.casa) == c:
			cb.fijo = true
			_arquero_fijo = cb


## Lee los marcadores de datos del nivel y crea lo que piden: tronco-puente, lobernos y asesino.
func _montar_marcadores_de_datos() -> void:
	for mc in (m._marcas as Array):
		var d: Dictionary = mc
		var c: Vector2i = d["c"]
		match String(d["grupo"]):
			"tronco_puente":
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
			"loberno":
				_crear_loberno(c)
			"canouro":
				_crear_canouro(c)
			"asesino":
				_asesino = Combate3D.invocar_asesino(m, _jug, _jug.lanz, m.call("_pos_marca", c, m.ALTO)) if _jug != null else null
				if _asesino == null:
					push_warning("Bosque 02: no se pudo crear el goblin asesino de %s" % str(c))


## Un loberno: el modelo (Pj3D) más su Combate3D, como lo hace Jugador3D con los de `_goblins` al montar. Si falta el GLB no sale y se avisa.
func _crear_loberno(c: Vector2i) -> void:
	var pj: Pj3D = m.call("_personaje", [ID_LOBERNO], m.call("_pos_marca", c, m.ALTO))
	if pj == null or _jug == null:
		push_warning("Bosque 02: no se pudo crear el loberno de %s (¿falta arte/modelos/emberheart.glb?)" % str(c))
		return
	(m.get("_goblins") as Array).append(pj)
	_lobernos.append(pj)
	Combate3D.equipar(pj, m, _jug, _jug.lanz)


## 6/11 (canouro v2): un canouro del bosque denso, igual que el loberno (modelo + combate). Si falta el GLB no sale y se avisa.
func _crear_canouro(c: Vector2i) -> void:
	var pj: Pj3D = m.call("_personaje", [ID_CANOURO], m.call("_pos_marca", c, m.ALTO))
	if pj == null or _jug == null:
		push_warning("Bosque 02: no se pudo crear el canouro de %s (¿falta arte/modelos/canouro.glb?)" % str(c))
		return
	(m.get("_goblins") as Array).append(pj)
	_canouros.append(pj)
	Combate3D.equipar(pj, m, _jug, _jug.lanz)


## La guardabosques (`m`) y la librera (`M`) las crea la maqueta sin guardarlas: se busca el Pj3D más cercano a su casilla.
func _buscar_gente() -> void:
	var c_guarda: Vector2i = _celda("guardabosques_02", GUARDA_DEFECTO)
	var c_librera: Vector2i = _celda("librera_02", LIBRERA_DEFECTO)
	var g1: Pj3D = _pj_cerca(c_guarda)
	if g1 != null:
		_gente.append({"tipo": "guardabosques", "nombre": "Guardabosques", "pj": g1, "t_habla": 0.0, "lineas": 0, "atento": false, "saludo": false})
	var g2: Pj3D = _pj_cerca(c_librera)
	if g2 != null:
		_gente.append({"tipo": "librera", "nombre": "Librera", "pj": g2, "t_habla": 0.0, "lineas": 0, "atento": false, "saludo": false})


func _pj_cerca(c: Vector2i) -> Pj3D:
	var centro: Vector3 = m.call("_centro_celda", c, 0.0)
	var goblins: Array = m.get("_goblins")
	var mejor: float = 4.0
	var res: Pj3D = null
	for n in (m as Node).find_children("*", "Pj3D", true, false):
		if n is Jugador3D or goblins.has(n) or _lobernos.has(n) or _canouros.has(n):
			continue
		var d: Vector3 = (n as Pj3D).position - centro
		d.y = 0.0
		if d.length() < mejor:
			mejor = d.length()
			res = n as Pj3D
	return res


# ---------------------------------------------------------------------------------------------------------------------
#  Lo consumido: telarañas, puerta goblin, torres
# ---------------------------------------------------------------------------------------------------------------------

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


func _quitar_reactivo(r: Variant) -> void:
	m.call("_liberar", r.celda)
	(r as Node).remove_from_group(Reactivo3D.GRUPO_ARDE)
	(r as Node).remove_from_group(Reactivo3D.GRUPO_REACTIVO)
	(m.get("_reactivos") as Array).erase(r)
	(r as CollisionObject3D).collision_layer = 0
	var celda_r: Vector2i = r.celda
	(r as Node).queue_free()
	for t in PAUSAS_LIBERAR:
		get_tree().create_timer(t).timeout.connect(func() -> void:
			if m != null and is_instance_valid(m):
				m.call("_liberar", celda_r))


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
#  Las misiones: se DERIVAN de las flags
# ---------------------------------------------------------------------------------------------------------------------

func _definir_misiones() -> void:
	var mi: Misiones = Misiones.i()
	if mi.existe(MISION):
		mi.activar(MISION)           # volver de otro nivel: no se redefine (perdería lo hecho); `_sincronizar_mision` la pone al día
		for id in [MISION_CAMPAMENTO, MISION_MOLINO, MISION_PIEDRA, MISION_COFRES]:
			mi.activar(id)
		return
	mi.definir({"id": MISION, "titulo": "El corazón del Bosque", "tipo": "principal",
		"texto": "El bosque se ha quedado sin latido. Enciende los braseros de la linde, cruza el arroyo, limpia la pradera, despierta los tres tótems de las ruinas, destruye el campamento goblin para conseguir la llave del santuario y vence al elemental que guarda el corazón.",
		"origen": "Guardabosques de la linde", "recompensa": {"oro": 100},
		"objetivos": ["Enciende los dos braseros de la linde (0/2)", "Cruza el arroyo (el tronco seco cae con fuego)", "Limpia la pradera alta de goblins",
			"Despierta los tres tótems de las ruinas (0/3) y abre su sala", "Destruye el campamento goblin y coge la llave del santuario", "Vence al elemental del santuario",
			"Abre el cofre del corazón del Bosque"]})
	mi.definir({"id": MISION_CAMPAMENTO, "titulo": "Destruir el campamento", "tipo": "secundaria",
		"texto": "Los goblins del este se han hecho fuertes tras una empalizada de madera seca. Dentro guardan un cofre que brilla.",
		"origen": "Campamento goblin", "recompensa": {"oro": 50},
		"objetivos": ["Derrota a todos los goblins del campamento", "Abre el cofre épico del campamento"]})
	mi.definir({"id": MISION_MOLINO, "titulo": "La corriente del molino", "tipo": "secundaria",
		"texto": "El pulsador abre el agua hacia la pila. Quema la cuerda para desviar el agua a la rueda. Cuando el lago se electrifique, podrás abrir el cofre del borde.",
		"origen": "Estanque del molino", "recompensa": {"oro": 50},
		"objetivos": ["Abre la compuerta del molino (el pulsador pide agua)", "Quema la cuerda para llevar el caudal a la rueda", "Abre el cofre épico del estanque mientras el lago está electrificado"]})
	mi.definir({"id": MISION_PIEDRA, "titulo": "El peso de la piedra", "tipo": "secundaria",
		"texto": "En la plaza de las ruinas hay una piedra suelta y una placa en el suelo. Pesa lo bastante para abrir una trastienda.",
		"origen": "Ruinas de los tótems", "recompensa": {"oro": 50},
		"objetivos": ["Empuja la piedra hasta la placa del suelo", "Abre el cofre épico de la trastienda"]})
	mi.definir({"id": MISION_COFRES, "titulo": "Siete cofres", "tipo": "secundaria",
		"texto": "El Bosque esconde siete cofres corrientes, cada uno como premio a una tarea: braseros, el arroyo, la pradera, el molino, una torre, las ruinas y un escondite.",
		"origen": "Guardabosques de la linde", "recompensa": {"oro": 70},
		"objetivos": ["Abre los siete cofres comunes del Bosque (0/7)"]})
	for id in [MISION, MISION_CAMPAMENTO, MISION_MOLINO, MISION_PIEDRA, MISION_COFRES]:
		mi.activar(id)


## Marca cada objetivo según lo que dicen las flags. Idempotente: se llama cada sondeo.
func _sincronizar_mision() -> void:
	var mi: Misiones = Misiones.i()
	if not mi.existe(MISION):
		return
	var n_br: int = 2 if Flags.i().tiene(F_BRASEROS) else _braseros_encendidos()
	var n_tot: int = _contar_flags(F_TOTEM)
	var n_com: int = _contar_flags(F_COFRES_COMUNES)
	mi.objetivo_texto(MISION, OBJ_BRASEROS, "Enciende los dos braseros de la linde (%d/2)" % n_br)
	mi.objetivo_texto(MISION, OBJ_RUINAS, "Despierta los tres tótems de las ruinas (%d/3) y abre su sala" % n_tot)
	mi.objetivo_texto(MISION_COFRES, 0, "Abre los siete cofres comunes del Bosque (%d/7)" % n_com)
	var hechos: Dictionary = {
		OBJ_BRASEROS: Flags.i().tiene(F_BRASEROS), OBJ_ARROYO: Flags.i().tiene(F_ARROYO), OBJ_PRADERA: Flags.i().tiene(F_PRADERA),
		OBJ_RUINAS: Flags.i().tiene("bosque02.ruinas.puerta") or Flags.i().tiene("bosque02.ruinas.cofre"),
		OBJ_CAMPAMENTO: Flags.i().tiene(F_LLAVE), OBJ_ELEMENTAL: Flags.i().tiene(F_SANT_LIMPIO), OBJ_COFRE: Flags.i().tiene(F_COFRE_FINAL)}
	for o in hechos:
		if bool(hechos[o]):
			mi.objetivo_hecho(MISION, int(o))
	_marcar(MISION_CAMPAMENTO, 0, Flags.i().tiene(F_CAMP_LIMPIO))
	_marcar(MISION_CAMPAMENTO, 1, Flags.i().tiene(F_CAMP_COFRE))
	_marcar(MISION_MOLINO, 0, Flags.i().tiene(F_COMPUERTA))
	_marcar(MISION_MOLINO, 1, Flags.i().tiene(F_MOLINO))
	_marcar(MISION_MOLINO, 2, Flags.i().tiene(F_COFRE_MOLINO_EPICO))
	_marcar(MISION_PIEDRA, 0, Flags.i().tiene(F_PLACA))
	_marcar(MISION_PIEDRA, 1, Flags.i().tiene(F_COFRE_PIEDRA))
	_marcar(MISION_COFRES, 0, n_com >= F_COFRES_COMUNES.size())
	_poner_punto_activo(mi)


func _marcar(id: String, indice: int, hecho: bool) -> void:
	if hecho:
		Misiones.i().objetivo_hecho(id, indice)


## `fijar_punto` solo al objetivo activo de la principal (el primero que queda por hacer): el marcador del borde de pantalla apunta ahí y a ningún otro sitio.
func _poner_punto_activo(mi: Misiones) -> void:
	var objs: Array = mi.get_mision(MISION).get("objetivos", [])
	var activo: int = -1
	for i in range(mini(N_OBJ, objs.size())):
		if not bool((objs[i] as Dictionary).get("hecho", false)):
			activo = i
			break
	for i in range(N_OBJ):
		mi.fijar_punto(MISION, _punto_celda(_celda_objetivo(i)) if i == activo else null, i)


## Dónde está lo que pide el objetivo `i` AHORA (el primer brasero apagado, el tronco, el tótem sin despertar, la puerta que toca…).
func _celda_objetivo(i: int) -> Variant:
	match i:
		OBJ_BRASEROS:
			for k in range(_braseros_linde.size()):
				if is_instance_valid(_braseros_linde[k]) and not bool(_braseros_linde[k].is_lit):
					return _braseros_celda[k]
			return _braseros_celda[0] if not _braseros_celda.is_empty() else null
		OBJ_ARROYO:
			return TRONCO_BASE
		OBJ_PRADERA:
			return CENTRO_PRADERA
		OBJ_RUINAS:
			for k in range(3):
				if not Flags.i().tiene(F_TOTEM[k]):
					return _celdas_totem[k]
			return PUERTA_RUINAS
		OBJ_CAMPAMENTO:
			if not Flags.i().tiene(F_CAMP_LIMPIO) and not Flags.i().tiene("%s%d_%d" % [PREFIJO_QUEMADO, _celda_puerta_goblin.x, _celda_puerta_goblin.y]):
				return _celda_puerta_goblin
			return COFRE_CAMPAMENTO
		OBJ_ELEMENTAL:
			if not Flags.i().tiene(F_LLAVE):
				return COFRE_CAMPAMENTO
			return PUERTA_SANTUARIO if not Flags.i().tiene("bosque02.santuario.puerta") else _celda_elemental
		OBJ_COFRE:
			return COFRE_CORAZON
	return null


func _punto_celda(c: Variant) -> Variant:
	if c == null:
		return null
	return Terreno3D.centro_de(c as Vector2i, Terreno3D.y_pies(c as Vector2i))


func _contar_flags(lista: PackedStringArray) -> int:
	var n: int = 0
	for f in lista:
		if Flags.i().tiene(f):
			n += 1
	return n


func _braseros_encendidos() -> int:
	var n: int = 0
	for b in _braseros_linde:
		if is_instance_valid(b) and bool(b.is_lit):
			n += 1
	return n


# ---------------------------------------------------------------------------------------------------------------------
#  Restaurar lo guardado en flags
# ---------------------------------------------------------------------------------------------------------------------

## Al montar (también al volver de la Cueva): los tótems con su flag se despiertan solos.
func _restaurar() -> void:
	for i in range(3):
		var t: Variant = _totems[i]
		if t != null and Flags.i().tiene(F_TOTEM[i]) and not bool(t.activo):
			t.call("_activar_totem")
	_sincronizar_puerta_ruinas()


## Los tres tótems despiertos = la «llave» de la puerta de la sala del tesoro (flag que lee la pieza `puerta_ruinas`).
func _sincronizar_puerta_ruinas() -> void:
	if not Flags.i().tiene(F_TOTEMS) and _contar_flags(F_TOTEM) >= F_TOTEM.size():
		Flags.i().poner(F_TOTEMS)


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
	_guardar_totems()
	_sincronizar_puerta_ruinas()
	_vigilar_recorrido()
	_vigilar_torre()
	_sincronizar_mision()


## Un tótem que se ha activado deja su flag (también lo hace su señal `activado`; esto cubre el que se activó antes de conectar).
func _guardar_totems() -> void:
	for i in range(3):
		var t: Variant = _totems[i]
		if t != null and bool(t.activo):
			Flags.i().poner(F_TOTEM[i])


## Pisar el este del mapa = el arroyo está cruzado (por el tronco, por el puente o helándolo).
func _vigilar_recorrido() -> void:
	var c: Vector2i = Terreno3D.celda_de((m.get("_jugador") as Pj3D).position)
	if RECT_ESTE.has_point(c):
		Flags.i().poner(F_ARROYO)


## La torre este consumida pone la flag que hace aparecer su cofre (el genérico `_persistir_quemados` ya guardó su casilla).
func _vigilar_torre() -> void:
	if Flags.i().tiene("%s%d_%d" % [PREFIJO_QUEMADO, _torre_este.x, _torre_este.y]):
		Flags.i().poner(F_TORRE)


## Lo que pasa jugando y se cuenta en pantalla (no al montar: `_montado`).
func _al_cambiar_flag(nombre: String, valor: Variant) -> void:
	if not _montado or valor == null or (valor is bool and valor == false):
		return
	match nombre:
		F_BRASEROS:
			_decir("Los dos braseros arden. En la linde, algo brilla.", 5.0)
		F_ARROYO:
			_decir("Has cruzado el arroyo. En la orilla, algo brilla.", 5.0)
		F_PRADERA:
			_decir("La pradera queda limpia. Hay un cofre junto al camino.", 5.0)
		F_TORRE:
			_decir("La torre ha caído. Tras ella, algo brilla.", 5.0)
		F_COMPUERTA:
			_decir("La compuerta se abre: el agua corre hacia el molino. Junto al canal, algo brilla.", 6.0)
		F_MOLINO:
			_decir("La rueda del molino gira. En el borde del lago, un cofre se deja ver.", 6.0)
		F_PLACA:
			_decir("La piedra pesa sobre la placa. Algo aparece en la trastienda.", 5.0)
		F_TOTEMS:
			_decir("Los tres tótems han despertado. La sala del tesoro se abre.", 6.0)
		F_CAMP_LIMPIO:
			_decir("El campamento ha caído. Hay un cofre junto a la fogata.", 5.0)
		F_LLAVE:
			_decir("Has cogido la llave del santuario. La puerta de piedra del oeste ya te dejará pasar.", 6.0)
			var lz: Node = get_tree().get_first_node_in_group("spellcaster")
			if lz != null and lz.has_method("avisar"):
				lz.call("avisar", "Llave del santuario conseguida", COLOR_AVISO_LLAVE)
		F_SANT_LIMPIO:
			_decir("El elemental ha caído. Hay un cofre al fondo.", 5.0)
		F_COFRE_FINAL:
			_terminar()
		_:
			if F_TOTEM.has(nombre):
				_decir("Tótem despierto (%d/3)" % _contar_flags(F_TOTEM), 3.0)


## FIN DE LA DEMO: el cofre legendario del corazón se ha abierto.
func _terminar() -> void:
	if _terminado:
		return
	_terminado = true
	Flags.i().poner(F_FIN)
	var pz: Variant = (_puzles as Puzle3D).pieza("cofre_corazon") if _puzles != null else null
	var pos_fin: Vector3 = ((pz.nodo as Node3D).position + Vector3.UP) if pz != null and is_instance_valid(pz.nodo) else Vector3.ZERO
	Mundo3D.avisar_logro("nivel_completado", pos_fin, pz.nodo if pz != null else null)
	_decir("Fin de la demo. Gracias por jugar el Bosque.", T_FIN_A_MENU)
	if volver_al_menu:
		get_tree().create_timer(T_FIN_A_MENU).timeout.connect(_volver_al_menu)


func _volver_al_menu() -> void:
	if not is_inside_tree():
		return
	var arbol: SceneTree = get_tree()
	arbol.paused = false
	Partida.autoguardar(arbol, MOTIVO_AUTOGUARDADO)
	arbol.change_scene_to_file(MenuPausa.RUTA_MENU_PRINCIPAL)


# ---------------------------------------------------------------------------------------------------------------------
#  La gente: la guardabosques y la librera
# ---------------------------------------------------------------------------------------------------------------------

static func _dist(a: Vector3, b: Vector3) -> float:
	var d: Vector3 = a - b
	d.y = 0.0
	return d.length()


func _gente_tick(delta: float) -> void:
	var jugador: Pj3D = m.get("_jugador") as Pj3D
	for g in _gente:
		var gd: Dictionary = g
		var pj: Pj3D = gd["pj"] as Pj3D
		if pj == null or not is_instance_valid(pj):
			continue
		if float(gd["t_habla"]) > 0.0:
			gd["t_habla"] = float(gd["t_habla"]) - delta
			pj.mirar(jugador.position - pj.position, delta)
			if float(gd["t_habla"]) <= 0.0:
				pj.animacion_actual = ""
				pj.jugar("idle")
			continue
		var d: float = _dist(jugador.position, pj.position)
		var radio: float = RADIO_ATENCION + (HISTERESIS_ATENCION if bool(gd["atento"]) else 0.0)
		gd["atento"] = d <= radio
		if bool(gd["atento"]):
			pj.mirar(jugador.position - pj.position, delta)
		if String(gd["tipo"]) == "guardabosques" and not bool(gd["saludo"]) and not Flags.i().tiene(F_GUARDA_SALUDO) and d <= RADIO_SALUDO:
			gd["saludo"] = true
			Flags.i().poner(F_GUARDA_SALUDO)
			_decir("%s: «%s»" % [String(gd["nombre"]), String(DIALOGO_GUARDA[0])], 6.0)
			pj.mirar(jugador.position - pj.position, 1.0)


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or m == null or m.get("_jugador") == null:
		return
	var k: InputEventKey = ev as InputEventKey
	if not k.pressed or k.echo or not k.is_action("interactuar"):
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
		hablar(mejor, yo)


## Habla el NPC `g` (también lo llaman las pruebas). Devuelve el texto dicho.
func hablar(g: Dictionary, yo: Vector3) -> String:
	var pj: Pj3D = g["pj"] as Pj3D
	var texto: String = texto_de(g)
	if texto == "":
		return ""
	_decir("%s: «%s»" % [String(g["nombre"]), texto], 6.0)
	pj.mirar(yo - pj.position, 1.0)
	pj.animacion_actual = ""
	pj.jugar("talk")
	Sfx3D.play(pj, "conversacion_voz")
	g["t_habla"] = T_HABLA
	if String(g["tipo"]) == "librera":
		Tiendas.abrir("librera")                 # 11/11: además de las pistas, su tienda (tiendas.tsv; la pantalla es del Pipeline)
	return texto


## Lo que dice cada uno según lo que ha pasado (las flags).
func texto_de(g: Dictionary) -> String:
	var n: int = int(g["lineas"])
	g["lineas"] = n + 1
	match String(g["tipo"]):
		"guardabosques":
			if Flags.i().tiene(F_COFRE_FINAL):
				return DIALOGO_GUARDA_FIN
			if Flags.i().tiene(F_BRASEROS) and not Flags.i().tiene(F_TRONCO_PUENTE) and not Flags.i().tiene(F_ARROYO) and n % 2 == 0:
				return DIALOGO_GUARDA_BRASEROS
			return String(DIALOGO_GUARDA[n % DIALOGO_GUARDA.size()])
		"librera":
			if Flags.i().tiene(F_SANT_LIMPIO):
				return DIALOGO_LIBRERA_FIN
			if Flags.i().tiene(F_TOTEMS) and not bool(g.get("dijo_totems", false)):
				g["dijo_totems"] = true
				g["lineas"] = n                       # esta línea extra no cuenta para el ciclo de pistas
				return DIALOGO_LIBRERA_TOTEMS
			return String(DIALOGO_LIBRERA[n % DIALOGO_LIBRERA.size()])
	return ""


func _decir(texto: String, seg: float) -> void:
	if _aviso != null:
		_aviso.text = texto
	_t_aviso = seg
