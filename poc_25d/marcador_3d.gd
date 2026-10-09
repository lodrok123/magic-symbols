@tool
class_name Marcador3D
extends Node3D

## UN MARCADOR DE NIVEL (7.2). Dice «aquí empieza el jugador», «aquí hay un goblin arquero», «aquí va una barrera de fuego»:
## todo lo que no es decorado ni suelo. El cargador (prueba_test2.gd) lee los marcadores del Nivel_<nombre>.tscn y hace con ellos
## lo que antes hacía con las letras del mapa: mismo comportamiento.
##
## Se coloca como una pieza más: Añadir nodo → Marcador3D, elegir la `letra` en el inspector y mover/girar con los gizmos.
## OJO: un marcador vive en la CASILLA donde está su centro (2,3 u); la posición exacta dentro de la casilla no cuenta, el giro sí.
##
## `letra` es la del mapa de siempre (S jugador, A arquero, W guerrero, G elemental de bosque, B barrera de fuego, X puerta, E salida, n/Q puestos,
## M/m personajes, p/a/w baldosas, K placa, z seto, l tronco, j/k/i tótems de fuego/agua/rayo, F fogata, T brasero, D muñeco,
## s/f/q plantas reactivas, r telaraña, h setas). Si está vacía, el marcador es de DATOS y manda `grupo`:
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
	if modelo != null:
		_visual.add_child(modelo)
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
