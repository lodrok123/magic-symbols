@tool
class_name Marcador3D
extends Node3D

## UN MARCADOR DE NIVEL (7.2). Dice «aquí empieza el jugador», «aquí hay un goblin arquero», «aquí va una barrera de fuego»:
## todo lo que no es decorado ni suelo. El cargador (prueba_test2.gd) lee los marcadores del Nivel_<nombre>.tscn y hace con ellos
## lo que antes hacía con las letras del mapa: mismo comportamiento.
##
## Se coloca como una pieza más: Añadir nodo → Marcador3D, elegir la `letra` en el inspector y mover/girar con los gizmos.
## OJO: un marcador vive en la CASILLA donde está su centro (2,3 u); la posición exacta dentro de la casilla no cuenta, el giro sí.
## Excepción (10/10): la tinaja `u` SÍ respeta dónde la pongas dentro de su casilla (los demás se centran).
##
## `letra` es la del mapa de siempre (S jugador, A arquero, W guerrero, G elemental de bosque, B barrera de fuego, X puerta, E salida, n/Q puestos,
## M/m personajes, p/a/w baldosas, K placa, z seto, l tronco, j/k/i tótems de fuego/agua/rayo, F fogata, T brasero, D muñeco,
## s/f/q plantas reactivas, r telaraña, h setas, e fuente eléctrica, u tinaja, y puerta goblin, o torre goblin, - canal recto, L canal codo).
## Canal (`-` y `L`, 10/10): una casilla del canal de ruinas por el que corre el agua de la tinaja. Su GIRO es el de la pieza (recto: corre
## a lo largo de X; codo: con giro 0 abre al oeste y al sur, 90 → sur y este…) y `lleno` dice si la casilla empieza con agua (vacía por
## defecto: se llena sola cuando la tinaja vierte). Los canales conectados a la casilla de delante de la tinaja forman UN canal.
## Si está vacía, el marcador es de DATOS y manda `grupo`:
## «recogible» (tipo: pocion | oro) o «empujable» (tipo: tierra | hielo).

@export var letra: String = "":
	set(v):
		letra = v
		if is_inside_tree():
			_agrupar()        # al cambiar de letra (p. ej. tras Ctrl+D) deja el grupo de la letra vieja
		_actualizar()
@export var grupo: String = "":
	set(v):
		grupo = v
		if is_inside_tree():
			_agrupar()
@export var tipo: String = ""
## Solo canal (`-`, `L`): la casilla EMPIEZA con agua (true) o vacía (false, lo normal: la llena la tinaja). En el editor se ve el agua.
@export var lleno: bool = false:
	set(v):
		lleno = v
		_actualizar()
## Solo barrera de fuego (`B`): cuántas casillas cubre, a lo largo del eje X LOCAL del marcador (gíralo para ponerla vertical:
## -90° en Y). El marcador va en el CENTRO de la pared. Las diagonales se ajustan al eje más cercano (la rejilla es de 2,3 u).
@export_range(1, 40) var largo: int = 1:
	set(v):
		largo = maxi(v, 1)
		_actualizar()
## Solo puente reactivo (`P`): el marcador va en el CENTRO del puente, sobre AGUA, y `largo` (arriba) son las casillas que cubre
## a lo largo de su eje X local. Aquí se elige QUÉ lo activa: otro marcador (un tótem, un brasero, una placa…). Si se deja
## vacío, el puente no se tiende nunca (el cargador lo avisa).
@export_node_path("Marcador3D") var activador: NodePath = NodePath("")

## Qué es cada letra: grupo del contrato, rótulo, color de la caja de aviso y (si lo hay) la pieza de modelo que se dibuja.
const LETRAS: Dictionary = {
	"S": {"grupo": "inicio_jugador", "rotulo": "JUGADOR", "color": Color(0.3, 0.9, 0.4)},
	"A": {"grupo": "goblin", "tipo": "arquero", "rotulo": "GOBLIN ARQUERO", "color": Color(0.9, 0.3, 0.2)},
	"W": {"grupo": "goblin", "tipo": "guerrero", "rotulo": "GOBLIN GUERRERO", "color": Color(0.9, 0.3, 0.2)},
	"G": {"grupo": "goblin", "tipo": "elemental", "rotulo": "ELEMENTAL DE BOSQUE", "color": Color(0.9, 0.3, 0.2)},
	"B": {"grupo": "barrera_fuego", "rotulo": "BARRERA DE FUEGO", "color": Color(1.0, 0.5, 0.1)},
	"X": {"grupo": "puerta", "rotulo": "PUERTA", "color": Color(0.7, 0.5, 0.3), "pieza": "arco_puerta"},
	"P": {"grupo": "puente_reactivo", "rotulo": "PUENTE REACTIVO", "color": Color(0.2, 0.9, 1.0)},
	"E": {"grupo": "salida", "rotulo": "SALIDA", "color": Color(0.7, 0.9, 1.0), "pieza": "portal_salida"},
	"n": {"grupo": "npc", "tipo": "librera", "rotulo": "PUESTO LIBRERA", "color": Color(0.9, 0.8, 0.4), "pieza": "puesto"},
	"Q": {"grupo": "npc", "tipo": "alquimista", "rotulo": "PUESTO ALQUIMISTA", "color": Color(0.9, 0.8, 0.4), "pieza": "puesto"},
	"M": {"grupo": "npc", "tipo": "librera", "rotulo": "NPC LIBRERA", "color": Color(0.9, 0.8, 0.4)},
	"m": {"grupo": "npc", "tipo": "guardabosques", "rotulo": "NPC GUARDABOSQUES", "color": Color(0.9, 0.8, 0.4)},
	"p": {"grupo": "baldosa", "tipo": "contacto", "rotulo": "BALDOSA CONTACTO", "color": Color(1.0, 0.85, 0.35)},
	"a": {"grupo": "baldosa", "tipo": "agua", "rotulo": "BALDOSA AGUA", "color": Color(0.45, 0.72, 1.0)},
	"w": {"grupo": "baldosa", "tipo": "viento", "rotulo": "BALDOSA VIENTO", "color": Color(0.65, 1.0, 0.8)},
	"K": {"grupo": "placa", "rotulo": "PLACA DE PESO", "color": Color(0.8, 0.8, 0.8), "pieza": "placa_peso"},
	"D": {"grupo": "muneco", "rotulo": "MUÑECO", "color": Color(0.8, 0.6, 0.4), "pieza": "dummy"},
	"z": {"grupo": "reactivo", "tipo": "seto", "rotulo": "SETO SECO", "color": Color(0.6, 0.5, 0.2), "pieza": "seto_seco"},
	"l": {"grupo": "reactivo", "tipo": "tronco", "rotulo": "TRONCO", "color": Color(0.5, 0.35, 0.2), "pieza": "tronco"},
	"j": {"grupo": "reactivo", "tipo": "totem_fuego", "rotulo": "TÓTEM FUEGO", "color": Color(1.0, 0.4, 0.2), "pieza": "totem_runico"},
	"k": {"grupo": "reactivo", "tipo": "totem_agua", "rotulo": "TÓTEM AGUA", "color": Color(0.3, 0.6, 1.0), "pieza": "totem_runico"},
	"i": {"grupo": "reactivo", "tipo": "totem_rayo", "rotulo": "TÓTEM RAYO", "color": Color(0.9, 0.9, 0.3), "pieza": "totem_runico"},
	"F": {"grupo": "reactivo", "tipo": "fogata", "rotulo": "FOGATA", "color": Color(1.0, 0.5, 0.1), "pieza": "fogata"},
	"T": {"grupo": "reactivo", "tipo": "brasero", "rotulo": "BRASERO", "color": Color(1.0, 0.5, 0.1), "pieza": "brasero"},
	"s": {"grupo": "reactivo", "tipo": "seta", "rotulo": "SETA REACTIVA", "color": Color(0.8, 0.4, 0.8), "pieza": "seta_reactiva"},
	"f": {"grupo": "reactivo", "tipo": "flor", "rotulo": "FLOR REACTIVA", "color": Color(0.9, 0.5, 0.7), "pieza": "flor_reactiva"},
	"q": {"grupo": "reactivo", "tipo": "raiz", "rotulo": "RAÍZ REACTIVA", "color": Color(0.5, 0.4, 0.3), "pieza": "raiz_reactiva"},
	"r": {"grupo": "reactivo", "tipo": "telarana", "rotulo": "TELARAÑA", "color": Color(0.9, 0.9, 0.9)},
	"h": {"grupo": "reactivo", "tipo": "setas", "rotulo": "SETAS", "color": Color(0.8, 0.4, 0.8), "pieza": "setas"},
	# 9.6 (10/10, nivel Bosque 1): la lógica es del Juego (9.10 rayo por el agua, 9.11 surtidor y cauce); la maqueta los dibuja.
	"e": {"grupo": "reactivo", "tipo": "emisor_rayo", "rotulo": "FUENTE ELÉCTRICA", "color": Color(0.95, 0.9, 0.3), "pieza": "cristal_sanctuario"},
	"u": {"grupo": "reactivo", "tipo": "surtidor", "rotulo": "TINAJA", "color": Color(0.4, 0.7, 1.0), "pieza": "tinaja_ruina"},
	# 10/10: campamento goblin. Estos dos ARDEN (tienda, empalizada y estandarte son decorado puro: letras t, x y V, sin marcador).
	"y": {"grupo": "reactivo", "tipo": "puerta_goblin", "rotulo": "PUERTA GOBLIN", "color": Color(0.8, 0.3, 0.2), "pieza": "puerta_goblin"},
	"o": {"grupo": "reactivo", "tipo": "torre_goblin", "rotulo": "TORRE GOBLIN", "color": Color(0.8, 0.3, 0.2), "pieza": "torre_goblin"},
	# 10/10: canal de ruinas (antes letras de decorado). No bloquea; el agua la monta el cargador a partir de estos marcadores.
	"-": {"grupo": "canal", "tipo": "recto", "rotulo": "CANAL RECTO", "color": Color(0.4, 0.7, 1.0), "pieza": "canal_recto"},
	"L": {"grupo": "canal", "tipo": "codo", "rotulo": "CANAL CODO", "color": Color(0.4, 0.7, 1.0), "pieza": "canal_codo"},
}
const DATOS: Dictionary = {
	"recogible": {"rotulo": "RECOGIBLE", "color": Color(1.0, 0.85, 0.2)},
	"empujable": {"rotulo": "BLOQUE EMPUJABLE", "color": Color(0.6, 0.45, 0.3)},
}

var _visual: Node3D = null


func _ready() -> void:
	_agrupar()
	if Engine.is_editor_hint():
		_actualizar()


## Al grupo del contrato (a mano `grupo` si es un marcador de datos). Antes sale de los grupos de cualquier otra letra o
## dato: un marcador duplicado (Ctrl+D) y cambiado de letra conservaba el grupo viejo, y los grupos se guardan en el .tscn.
func _agrupar() -> void:
	for info in LETRAS.values():
		var gv: String = String((info as Dictionary).get("grupo", ""))
		if gv != "" and is_in_group(gv):
			remove_from_group(gv)
	for gd in DATOS.keys():
		if is_in_group(String(gd)):
			remove_from_group(String(gd))
	add_to_group("marcador", true)
	var g: String = grupo
	if LETRAS.has(letra):
		g = String((LETRAS[letra] as Dictionary).get("grupo", ""))
	if g != "":
		add_to_group(g, true)


func _actualizar() -> void:
	if is_inside_tree() and Engine.is_editor_hint():
		dibujar()


## Dibuja el aviso del marcador (solo se llama en el editor; público para poder probarlo fuera de él).
func dibujar() -> void:
	# Fuera TODO aviso anterior, no solo el nuestro: al duplicar un marcador (Ctrl+D) el editor copia también su aviso, y la
	# copia queda huérfana (se veía «JUGADOR» dentro de «PUESTO LIBRERA»). Se reconocen por el metadato o por el nombre.
	for h in get_children():
		if h.has_meta("aviso_marcador") or String(h.name).begins_with("visual"):
			remove_child(h)
			h.queue_free()
	_visual = null
	var info: Dictionary = LETRAS.get(letra, DATOS.get(grupo, {"rotulo": "MARCADOR ?" if letra == "" else "LETRA " + letra, "color": Color(1, 0, 1)}))
	var rotulo: String = String(info.get("rotulo", "MARCADOR"))
	var col: Color = info.get("color", Color(1, 0, 1))
	if tipo != "" and not LETRAS.has(letra):
		rotulo += " (" + tipo + ")"
	_visual = Node3D.new()
	if letra == "B":
		var pared := MeshInstance3D.new()
		var pbm := BoxMesh.new()
		pbm.size = Vector3(2.3 * float(largo), 1.45, 0.5)
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(col, 0.5)
		pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pbm.material = pmat
		pared.mesh = pbm
		pared.position.y = 0.72
		_visual.add_child(pared)
		rotulo += " ×%d" % largo
	if letra == "P":
		# una losa plana translúcida por casilla, para ver en el editor cuánto cubre y hacia dónde
		for k in range(largo):
			var losa := MeshInstance3D.new()
			var lbm := BoxMesh.new()
			lbm.size = Vector3(2.3 * 0.9, 0.2, 2.3 * 0.9)
			var lmat := StandardMaterial3D.new()
			lmat.albedo_color = Color(col, 0.45)
			lmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			lbm.material = lmat
			losa.mesh = lbm
			losa.position = Vector3((float(k) - float(largo - 1) * 0.5) * 2.3, 0.1, 0.0)
			_visual.add_child(losa)
		rotulo += " ×%d" % largo
	var pieza: String = String(info.get("pieza", ""))
	var modelo: Node3D = Pieza3D.crear_visual(pieza) if pieza != "" else null
	# 13/10: la vista previa es lo que pone el juego (PruebaBosque), no una caja: la telaraña entera, los personajes con su
	# modelo y su alto, y el cristal teñido de amarillo como en el juego.
	if modelo == null and letra == "r":
		modelo = Pieza3D.visual_telarana()
	if modelo == null and PJ_DE_LETRA.has(letra):
		modelo = _visual_personaje()
	if modelo == null and letra == "a":
		modelo = _visual_losa_agua()
	if modelo != null and letra == "e":
		Pieza3D.tinte_amarillo(modelo)
		_visual.add_child(_luz_cristal())
	if modelo != null:
		_visual.add_child(modelo)
		if lleno and (letra == "-" or letra == "L"):
			_visual.add_child(_agua_vista_previa())
	elif letra != "B" and letra != "P":
		var caja := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.7, 1.4, 0.7)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(col, 0.65)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.material = mat
		caja.mesh = bm
		caja.position.y = 0.7
		_visual.add_child(caja)
		# una flecha corta hacia +Z (el frente) para ver hacia dónde mira
		var punta := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.15, 0.15, 0.6)
		pm.material = bm.material
		punta.mesh = pm
		punta.position = Vector3(0.0, 1.0, 0.55)
		_visual.add_child(punta)
	# 12/10: el cristal (`e`) se ve solo como cristal en el editor: sin la etiqueta «FUENTE ELÉCTRICA».
	if letra != "e" or modelo == null:
		var et := Label3D.new()
		et.text = rotulo
		et.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		et.no_depth_test = true
		et.pixel_size = 0.006
		et.modulate = col
		et.outline_size = 8
		et.position.y = 2.0 if modelo == null else 2.6
		_visual.add_child(et)
	_visual.name = "visual"
	_visual.set_meta("aviso_marcador", true)
	add_child(_visual)      # sin owner: no se guarda en el .tscn


## Letra -> lista de personajes del juego (constantes PJ_* de prueba_test2.gd; la `A` es el arquero, como con reglas).
const PJ_DE_LETRA: Dictionary = {"A": "PJ_ARQUERO", "W": "PJ_GOBLIN", "G": "PJ_ELEMENTAL", "M": "PJ_LIBRERA",
	"m": "PJ_GUARDABOSQUES", "S": "PJ_JUGADOR"}


## 13/10: el modelo del personaje de este marcador, con el GLB y el alto que usa el juego (se leen de los scripts, sin copiarlos).
func _visual_personaje() -> Node3D:
	var juego: Script = load("res://poc_25d/prueba_test2.gd") as Script
	var pj: Script = load("res://poc_25d/pj_3d.gd") as Script
	if juego == null or pj == null:
		return null
	var k: Dictionary = juego.get_script_constant_map()
	var modelos: Dictionary = pj.get_script_constant_map().get("MODELO_DE", {})
	return Pieza3D.visual_personaje(k.get(String(PJ_DE_LETRA[letra]), []), k.get("ALTO_PJ", {}), modelos)


## 13/10: la luz amarilla del cristal, como la pone el juego (Reactivo3D._montar_emisor: COLOR_RAYO, energía 1, alcance 4,
## a 1,3 de alto, sin sombras). En el juego además parpadea y echa chispas; aquí se queda fija.
func _luz_cristal() -> OmniLight3D:
	var obj: Script = load("res://poc_25d/objetos_3d.gd") as Script
	var col: Color = Color(1.0, 0.92, 0.4)
	var energia: float = 1.0
	if obj != null:
		col = obj.get_script_constant_map().get("COLOR_RAYO", col)
		energia = float(obj.get_script_constant_map().get("LUZ_CRISTAL", energia))
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energia
	l.omni_range = 4.0
	l.position = Vector3(0.0, 1.3, 0.0)
	l.shadow_enabled = false
	return l


## 13/10: la losa de agua (`a`) como la pinta el juego (bosque_3d.gd): un círculo rúnico de 0,85 casillas a ras de suelo.
func _visual_losa_agua() -> Node3D:
	var reglas: Script = load("res://poc_25d/bosque_3d.gd") as Script
	var col: Color = Color(0.45, 0.72, 1.0)
	if reglas != null:
		col = reglas.get_script_constant_map().get("COLOR_LOSA_AGUA", col)
	var disco: MeshInstance3D = Formas3D.instancia("runa", col)
	if disco == null:
		return null
	disco.scale = Vector3(2.3 * 0.85, 1.0, 2.3 * 0.85)
	var raiz := Node3D.new()
	raiz.position.y = 0.02
	raiz.add_child(disco)
	return raiz


## Vista previa del agua de un canal LLENO (solo para el editor): tiras azules translúcidas. Recto: de borde a borde a lo largo de X.
## Codo (con giro 0 abre al oeste y al sur): del borde oeste al centro y del centro al borde sur. Las mide igual que Canal3D (ancho 0,6).
func _agua_vista_previa() -> Node3D:
	var raiz := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.66, 0.95, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var s: float = 2.3
	var tiras: Array = []     # [centro Vector3, tamaño Vector2 (x, z)]
	if letra == "-":
		tiras.append([Vector3(0.0, 0.15, 0.0), Vector2(s, 0.6)])
	else:
		tiras.append([Vector3(-s * 0.25, 0.15, 0.0), Vector2(s * 0.5, 0.6)])
		tiras.append([Vector3(0.0, 0.15, s * 0.25), Vector2(0.6, s * 0.5)])
	for t in tiras:
		var pm := PlaneMesh.new()
		pm.size = t[1]
		pm.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = pm
		mi.position = t[0]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(mi)
	return raiz
