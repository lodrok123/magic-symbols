@tool
class_name Pieza3D
extends Node3D

## UNA PIEZA DE DECORADO DEL NIVEL (6.10, camino A). Es lo que contiene un nivel horneado (`poc_25d/niveles/<nivel>.tscn`).
##
## En el EDITOR de Godot dibuja el modelo de la pieza (el mismo que usa la maqueta: árbol, roca, puesto, cartel…), así que se
## puede coger con los gizmos, moverla, girarla, escalarla, duplicarla (Ctrl+D) o borrarla. Para añadir una nueva: Añadir nodo →
## Pieza3D, y elegir el `id` de la lista del inspector.
##
## En el JUEGO no dibuja nada por sí misma: `PruebaTest2` lee todas las Pieza3D del nivel y las mete en sus lotes (MultiMesh)
## como siempre, y marca como bloqueadas las casillas de las que tengan `bloquea`. El origen del nodo es el centro de la base
## de la pieza (a ras de suelo, ver ALTO en prueba_test2.gd): la casilla que ocupa sale de su posición.

## Qué pieza es. Es el id que se pide en el mapa (p. ej. "arbol_redondo"); las sustituciones de modelo se aplican solas.
@export var id: String = "":
	set(v):
		id = v
		if is_inside_tree() and Engine.is_editor_hint():
			_reconstruir()
## ¿Impide el paso en la casilla donde está? (árboles, rocas, puestos, carteles: sí; hierba, setas, baldosas: no.)
@export var bloquea: bool = false

static var _bibliotecas: Array = []

var _visual: Node3D = null


## --- Tablas de piezas (una sola copia: las usa la maqueta, que las alias en prueba_test2.gd, y el editor) ---
const S: float = 2.3                       ## lado de una casilla (el de PruebaTest2.S)
const CARPETA_PIEZAS: String = "res://arte/meshy/piezas/"

const BIBLIOTECAS: Array = ["res://arte/meshy/arboles_2.glb", "res://arte/meshy/mercado.glb",
	"res://arte/meshy/bosque.glb", "res://arte/meshy/objetos.glb", "res://arte/meshy/magia.glb"]

const SUSTITUTAS: Dictionary = {
	"arbol_redondo": "arbol_redondo_2", "pino": "pino_2", "seto_seco": "arbusto_otono",
	"puesto": "puesto_mercado", "arco_puerta": "arco_ruina",
}

const MEDIDA: Dictionary = {
	"arbol_redondo": 4.2, "pino": 4.6, "arbusto": 1.0, "arbusto_flores": 1.0, "matas": 0.45,
	"arbol_redondo_2": 4.2, "pino_2": 4.6, "arbusto_otono": 1.3, "puesto_mercado": 1.9, "arco_ruina": 3.4,
	"roca_cristal": 1.4, "roca_grande": 1.4, "piedras": 0.35, "tocon": 0.6, "tronco": 0.7, "setas": 0.35, "valla": 0.8, "cartel": 0.95,
	"arco_puerta": 3.4, "totem_runico": 1.8, "brasero": 1.4, "fogata": 0.6, "puesto": 1.9, "caja_pequena": 0.6,
	"placa_peso": 0.15, "juncos": 0.8, "barril": 0.8, "cofre": 0.6, "caja": 0.8,
	"baldosa_guardado": 0.12, "seto_seco": 1.3, "dummy": 1.4, "seta_reactiva": 0.8, "flor_reactiva": 0.9,
	"raiz_reactiva": 0.9, "portal_salida": 3.0, "pocion": 0.45, "pilar": 1.8,
	"cristal_sanctuario": 1.4,   # 12/10: la fuente eléctrica (cristal azul de Meshy, pintado amarillo por objetos_3d.gd); su alto
	"tinaja_ruina": 1.5,      # ruinas_agua.glb (Meshy «Mossbound Relics»): la tinaja que vierte el agua
	# campamento_goblin.glb (Meshy «Tusks of the Red Fang»). Alturas en unidades; la puerta y la empalizada van por ancho (abajo).
	"tienda_goblin": 2.0, "torre_goblin": 3.2, "estandarte_goblin": 2.2,
	# 15/10: campamento.glb (campamento del guardabosques, 4 piezas). Mismo factor de escala para las cuatro (x4 sobre el GLB: la tienda, la mayor,
	# queda en 1,7 de alto y 2,65 de ancho) para que mantengan sus proporciones. Cada una lleva debajo su trozo plano de suelo del Meshy.
	"campamento_tienda": 1.7, "campamento_cazo": 1.35, "campamento_rocas": 0.8, "campamento_cofre": 0.57,
	# 15/10: praderas.glb (Meshy «Mossy Meadow Elements», una sola malla que separé en 4 nodos sin suelo). Mismo factor (×1,6 sobre el GLB).
	"rocas_pequenas": 0.33, "roca_musgosa": 0.5, "hierba_alta": 0.53, "hojas_caidas": 0.23,
	# 15/10: bosque_flora.glb (Meshy «Woodland Flora Collection», una malla separada en 5 nodos sin suelo). Mismo factor ×1,6 (los troncos apilados ×1,9).
	"helecho": 0.5, "tronco_musgoso": 0.38, "canas": 0.54, "flores_blancas": 0.34, "troncos_apilados": 0.45,
	# 15/10: bosque_crafting.glb y bosque_tile.glb (Meshy «Enchanted Crafting» / «Enchanted Forest Tile»; cada hoja era una sola malla).
	# Las parejas que se cambian una por otra en el juego (seta azul ↔ quemada, tronco con ↔ sin resina) miden parecido para que el cambio no «salte»
	# (la seta azul es `seta_reactiva`, arriba: 0,8).
	# 20/10: las 43 piezas nuevas de aprobacion3d/ (Pipeline, diario 213). Los glb miden 0,03–0,57 en sus unidades: sin esta entrada saldrían a 1,0 de alto.
	# VALORES DE PARTIDA a ojo desde las proporciones medidas (los de ancho, en MEDIDA_ANCHO): se afinan viéndolas en el nivel. `arbusto_flores` ya estaba (1,0).
	"abedul_amarillo": 4.0, "arbol_viejo": 4.4, "sauce": 3.8, "arbusto_bayas": 0.9,
	"tocon_alto": 1.1, "tocon_hueco": 0.8, "tocon_seco": 0.5, "tronco_enredadera": 1.8, "valla_lianas": 0.9, "roca_hueca": 0.7,
	"hierba_espesa": 0.55, "helecho_ancho": 0.5, "flores_amarillas": 0.45, "flores_colores": 0.5, "planta_violeta": 0.55, "planta_agua": 0.5, "planta_hojas": 0.6,
	"setas_amarillas": 0.35, "bloque_hierba": 0.5, "cubo_hielo": 0.5,
	"bloque_runa_roja": 0.8, "bloque_runa_naranja": 0.8, "bloque_runa_verde": 0.8, "bloque_runa_azul": 0.8, "bloque_runa_amarilla": 0.8, "bloque_runa_cian": 0.8,
	"cartel_runa_roja": 1.2, "cartel_runa_naranja": 1.2, "cartel_runa_verde": 1.2, "cartel_runa_azul": 1.2, "cartel_runa_amarilla": 1.2, "cartel_runa_cian": 1.2,
	"seta_quemada": 0.57, "tronco_resina": 0.8, "tronco_sin_resina": 0.8, "raiz_mundo": 0.7, "cristal_elemental": 0.6, "paja": 0.45,
	# 23/10 · la Cueva (lo que se mide por alto; las paredes y la boca van por ancho, en MEDIDA_ANCHO). La jugadora mide ~1.
	"jarron": 0.6, "jarron_alto": 0.95, "setas_rojas": 0.7, "setas_azules": 0.7, "setas_marrones": 0.65,
	"estalagmitas_a": 1.5, "estalagmitas_b": 1.8, "puerta_llave_marco": 2.4, "puerta_llave_hoja": 2.1,
	# 23/10 · hoja «pulso» (docs/PLAN_PULSO_RESONANTE.md §4; PROMPTS_CUEVA D1). Altura del prompt, salvo el cristal (1,6 → 1,5) y la estatua (1,8 → 1,7):
	# el modelo sale más ancho que lo pedido (peana de rocas) y a la altura del prompt ocuparían 1,3 de planta. El bloque de enlace va por ancho (MEDIDA_ANCHO).
	"cristal_resonante": 1.5, "prisma_orientable": 1.2, "receptor_runico": 1.1, "estatua_piedra": 1.7, "columna_agrietada": 2.5,
}

const MEDIDA_ANCHO: Dictionary = {"fogata": S * 0.6, "puente": S * 1.05, "puente_runico": S * 1.3,      # 11/10: el puente de piedra rúnica: casilla de agua + un poco de cada orilla
	 "pasadero": S * 0.8, "placa_peso": S * 0.8,
	# 15/10: las tres losas de runas (se pisan; la runa va encima por código: RunaLosa3D). Mismo ancho que la baldosa de guardado.
	"losa_runas_llana": S * 0.85, "losa_runas_remaches": S * 0.85, "losa_runas_ovalo": S * 0.85,
	"cofre": 0.65,   # 15/10: cofre_anim.glb mide 0,79 de ancho; a 0,65 queda de alto ~0,8 (como barril y caja)
	# 23/10 · la Cueva (docs/PLAN_BOSQUE_EOW.md §6): el kit de paredes ocupa UNA casilla exacta de planta para que encaje en la rejilla;
	# el muro agrietado un poco menos (deja ver la junta con la pared); la boca de la cueva, dos casillas.
	# Algo más que una casilla (× 1,12): el modelo encaja por su lado MAYOR, así que el otro queda corto y entre dos paredes se abría un hueco.
	"cueva_pared": S * 1.12, "cueva_esquina_ext": S * 1.12, "cueva_esquina_int": S * 1.12, "cueva_pared_baja": S * 1.12, "muro_ruina": S,
	"muro_agrietado": S * 0.96, "boca_cueva": S * 2.0, "llave_pequena": 0.35,
		# 23/10 · hoja «recompensas» (PROMPTS_CUEVA D2): por ancho del prompt (el alto sale de la proporción del modelo: 1,28 y 0,8). La placa, 1,8 × 1,8.
		"cofre_legendario": 1.6, "cofre_epico": 1.1, "placa_presion_cueva": 1.8,
		"bloque_enlace": 1.0,    # 23/10: pulso. El prompt pedía un cubo de 1,0; el modelo es una losa (1,0 × 0,7 × 1,0), así que se mide por ancho
	"baldosa_guardado": S * 0.85,
	# Canales de ruinas (enderezados en el GLB). Mismo factor de escala los dos (el codo mide 0,439 de ancho frente a 0,493 del recto).
	# `canal_recto`: corre a lo largo de X, abierto por -X y +X (giro 90 = a lo largo de Z). `canal_codo`: abierto por -X y +Z,
	# cerrado por +X y -Z (giro 180 = abierto por +X y -Z; 90 = +Z y +X; 270 = -Z y -X).
	"canal_recto": S, "canal_codo": S * 0.89,
	# Campamento goblin: la puerta mide 1,6 casillas de ancho (cabe en una y se apoya en las empalizadas de los lados, ~1,8 de alto);
	# la empalizada, 1 casilla (~1,0 de alto). La tienda es más ancha que una casilla (~3 de ancho con 2,0 de alto).
	"puerta_goblin": S * 1.6, "empalizada_goblin": S,
	# 20/10: piezas nuevas anchas o planas (diario 213): se miden por ancho para conservar la proporción real. Valores de partida.
	"nenufar": 1.0, "nenufar_flor": 0.5, "laja_piedra": 1.4, "cuenco_piedra": 0.8, "hojas_monton": 0.9, "raices_musgo": 1.4, "raices_secas": 1.6,
	"ramas_suelo": 1.2, "tocon_roca": 1.6, "tronco_seco": 1.8}

## Giro (grados, sobre Y) que se le da al modelo suelto para que mire como espera el juego (+Z local = hacia donde apunta el marcador).
## 11/10 puse 180 al cristal de la fuente eléctrica creyendo que su canal azul salía por -Z: era al revés (visto desde arriba, el canal
## de venas sale por +Z, que es hacia donde el juego electrifica el agua: `_celda_frente_fuente`). Con 180 las venas se alejaban del canal.
## Se deja a 0 (sin giro); la entrada sigue aquí por si otro modelo suelto necesita girarse.
const GIRO_MODELO: Dictionary = {"cristal_sanctuario": 0.0}

const PLANAS: Dictionary = {"placa_peso": 0.05, "baldosa_guardado": 0.04, "pasadero": 0.10,
	"losa_runas_llana": 0.08, "losa_runas_remaches": 0.08, "losa_runas_ovalo": 0.08,
	"nenufar": 0.05, "nenufar_flor": 0.12, "laja_piedra": 0.10,
	"placa_presion_cueva": 0.2}       # 23/10: PROMPTS_CUEVA D2 (0,2 de alto; el modelo sale a 0,28 y se hunde el resto)       # 20/10: grosor de las piezas nuevas planas (diario 213; partida)


func _ready() -> void:
	if Engine.is_editor_hint():
		_reconstruir()


func _reconstruir() -> void:
	if _visual != null and is_instance_valid(_visual):
		_visual.queue_free()
	_visual = null
	if id == "":
		return
	_visual = crear_visual(id)
	if _visual == null:
		# Sin modelo (id desconocido o falta la biblioteca): una caja magenta con el id, para que la pieza se vea y se pueda coger.
		_visual = Node3D.new()
		var caja := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.8, 0.8, 0.8)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.1, 0.8, 0.55)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.material = m
		caja.mesh = bm
		caja.position.y = 0.4
		_visual.add_child(caja)
		var rotulo := Label3D.new()
		rotulo.text = id
		rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		rotulo.pixel_size = 0.006
		rotulo.position.y = 1.1
		_visual.add_child(rotulo)
		push_warning("Pieza3D: no hay modelo para '%s' (¿id mal escrito o falta la biblioteca .glb?)" % id)
	_visual.name = "visual"
	add_child(_visual)      # sin owner: no se guarda en el .tscn, se vuelve a crear al abrirlo


## La lista de ids del inspector: todas las piezas con medida conocida.
func _validate_property(propiedad: Dictionary) -> void:
	if propiedad.name == "id":
		propiedad.hint = PROPERTY_HINT_ENUM_SUGGESTION
		var ids: Array = (_constantes().get("MEDIDA", {}) as Dictionary).keys()
		ids.sort()
		propiedad.hint_string = ",".join(PackedStringArray(ids))


## --- Modelo de la pieza (mismo recorrido que prueba_test2.gd: _pieza / _normalizar) ---

## Las tablas de arriba, en un diccionario (el editor no depende de prueba_test2.gd: si ese script no compila, las piezas se ven igual).
static func _constantes() -> Dictionary:
	return {"CARPETA_PIEZAS": CARPETA_PIEZAS, "BIBLIOTECAS": BIBLIOTECAS, "SUSTITUTAS": SUSTITUTAS, "MEDIDA": MEDIDA,
		"MEDIDA_ANCHO": MEDIDA_ANCHO, "PLANAS": PLANAS}


static func _cargar_bibliotecas() -> void:
	if not _bibliotecas.is_empty():
		return
	var t: Dictionary = _constantes()
	var rutas: Array = []
	var carpeta: String = String(t.get("CARPETA_PIEZAS", ""))
	if carpeta != "" and DirAccess.dir_exists_absolute(carpeta):
		var sueltas: Array = []
		for f in DirAccess.get_files_at(carpeta):
			var nombre: String = String(f).trim_suffix(".import").trim_suffix(".remap")
			if nombre.get_extension().to_lower() == "glb" and not sueltas.has(carpeta + nombre):
				sueltas.append(carpeta + nombre)
		sueltas.sort()
		rutas.append_array(sueltas)
	rutas.append_array(t.get("BIBLIOTECAS", []) as Array)
	for r in rutas:
		if ResourceLoader.exists(String(r)):
			var escena: PackedScene = load(String(r)) as PackedScene
			if escena != null:
				_bibliotecas.append(escena.instantiate() as Node3D)


static func _hay(id: String) -> bool:
	for b in _bibliotecas:
		if (b as Node).find_child(id, true, false) is Node3D:
			return true
	return false


## El id que se usa de verdad (la sustituta si existe en alguna biblioteca), igual que `_id_real` de la maqueta.
static func id_real(id: String) -> String:
	_cargar_bibliotecas()
	var nuevo: String = String((_constantes().get("SUSTITUTAS", {}) as Dictionary).get(id, ""))
	if nuevo != "" and _hay(nuevo):
		var carpeta: String = String(_constantes().get("CARPETA_PIEZAS", ""))
		if _hay(id):
			for b in _bibliotecas:
				if String((b as Node).scene_file_path).begins_with(carpeta) and (b as Node).find_child(id, true, false) is Node3D:
					return id
		return nuevo
	return id


## Copia del modelo de la pieza, a su medida y con la base en y = 0 centrada. null si ninguna biblioteca la tiene.
static func crear_visual(id_pedido: String) -> Node3D:
	var id: String = id_real(id_pedido)
	# 12/10: un modelo suelto con el mismo nombre que el id (`meshy/piezas/<id>.glb`) se usa directamente, sin depender del nombre
	# del nodo raíz que deje el importador.
	var suelto: String = CARPETA_PIEZAS + id + ".glb"
	if ResourceLoader.exists(suelto):
		var escena_suelta: PackedScene = load(suelto) as PackedScene
		if escena_suelta != null:
			var suelto_n: Node3D = escena_suelta.instantiate() as Node3D
			suelto_n.rotation.y = deg_to_rad(float(GIRO_MODELO.get(id, 0.0)))
			return _normalizar(suelto_n, id)
	for b in _bibliotecas:
		var n: Node = (b as Node).find_child(id, true, false)
		if n != null and n is Node3D:
			var copia: Node3D = (n as Node3D).duplicate() as Node3D
			copia.transform = Transform3D.IDENTITY
			return _normalizar(copia, id)
	return null


## 15/10: cambia el aspecto de una pieza YA colocada por el de otra (seta azul → quemada, tronco con resina → sin resina) sin tocar su
## colocación ni su colisión. `pieza` es la raíz de la pieza (la escena de `arte/piezas/` o el nodo que devuelve la maqueta): se sustituye su
## hijo `modelo` (o, si no lo tiene, la propia pieza se queda y se le añade). Devuelve false si no existe el modelo nuevo.
## Guarda el id en el metadato `id_visual` para saber qué aspecto lleva. El tamaño del nuevo sale de su propio MEDIDA.
static func cambiar_visual(pieza: Node3D, id_nuevo: String) -> bool:
	if pieza == null:
		return false
	var nuevo: Node3D = crear_visual(id_nuevo)
	if nuevo == null:
		return false
	var viejo: Node = pieza.get_node_or_null("modelo")
	var tf: Transform3D = Transform3D.IDENTITY
	if viejo is Node3D:
		tf = (viejo as Node3D).transform
		pieza.remove_child(viejo)
		viejo.queue_free()
	nuevo.name = "modelo"
	nuevo.transform = tf * nuevo.transform
	pieza.add_child(nuevo)
	pieza.set_meta("id_visual", id_nuevo)
	return true


## --- Colisión de la pieza (6.10, para la fuente de solidez por nodos del Lanzador) ---

## Colisión de la pieza: MEDIDA SOBRE EL MODELO (20/10). Antes: un cilindro fijo de 0,38 para los árboles y una caja del 80 % del
## AABB para el resto; la caja rellenaba el hueco de los arcos y las puertas (muros invisibles) y el cilindro no seguía el tronco.
## Ahora los cascos salen de `ColisionPieza` (franja de paso del personaje, un casco por cada trozo que de verdad esté ahí).
static var _formas: Dictionary = {}
static var _cascos: Dictionary = {}


## Cascos convexos medidos de la pieza `id_pedido` (nubes de puntos en su espacio local, base en y = 0, sin escala).
## Modo según `ColisionPieza.MODO`; una pieza que no está en la tabla se mide como «contorno» (alguien la ha pedido sólida
## en un nivel). Vacía si no hay modelo o es más baja que `ColisionPieza.ALTO_MIN_SOLIDO` (se pisa).
static func cascos_colision(id_pedido: String) -> Array:
	var id: String = id_real(id_pedido)
	if _cascos.has(id):
		return _cascos[id]
	var lista: Array = []
	var vis: Node3D = crear_visual(id)
	if vis != null:
		var modo: String = ColisionPieza.modo(id)
		lista = ColisionPieza.cascos(vis, "contorno" if modo == "ninguna" else modo)
		vis.free()
	_cascos[id] = lista
	return lista


## Los cuerpos de colisión de la pieza, listos para colgar de un StaticBody3D: un CollisionShape3D por casco, con la
## escala `k` ya aplicada a los puntos (un StaticBody con escala no uniforme deforma la colisión).
static func formas_colision(id_pedido: String, k: float = 1.0) -> Array:
	var res: Array = []
	for nube in cascos_colision(id_pedido):
		var pts := PackedVector3Array()
		for p in (nube as PackedVector3Array):
			pts.append(p * k)
		var sh := ConvexPolygonShape3D.new()
		sh.points = pts
		var cs := CollisionShape3D.new()
		cs.shape = sh
		res.append(cs)
	return res


## Resumen en caja/cilindro de esos cascos, para quien solo sabe de cajas (la maqueta hasta que use `formas_colision`), en su
## espacio local (base en y = 0, sin escala): {"cilindro": bool, "radio", "tam" (caja), "alto", "centro", "cascos": n}.
## OJO: una caja que envuelve dos pilares sigue tapando el paso entre ellos; para arcos y puertas hay que usar `formas_colision`.
static func forma_colision(id_pedido: String) -> Dictionary:
	var id: String = id_real(id_pedido)
	if _formas.has(id):
		return _formas[id]
	var lista: Array = cascos_colision(id)
	var f: Dictionary = {}
	if lista.is_empty():
		# sin cuerpo medido (pieza baja que se pisa o sin modelo): un metro cúbico, como cuando no hay modelo
		f = {"cilindro": false, "tam": Vector3(1.0, 1.0, 1.0), "alto": 1.0, "centro": Vector3(0.0, 0.5, 0.0), "cascos": 0}
	else:
		f = ColisionPieza.caja_de(lista)
		if ColisionPieza.modo(id) == "tronco" or ColisionPieza.modo(id) == "tronco_bajo":
			var r: float = maxf((f["tam"] as Vector3).x, (f["tam"] as Vector3).z) * 0.5
			f["cilindro"] = true
			f["radio"] = r
	_formas[id] = f
	return f


static func _normalizar(modelo: Node3D, id: String) -> Node3D:
	var t: Dictionary = _constantes()
	# 15/10: un modelo animado (el cofre) llega en la pose de reposo del GLB, que no es la del clip «cerrado» (la tapa asoma por detrás).
	# Se mide con «cerrado» aplicado: así el tamaño y el centro salen de la pieza tal como se ve en el nivel, no de la tapa suelta.
	var anim: Node = modelo.find_child("AnimationPlayer", true, false)
	if anim is AnimationPlayer and (anim as AnimationPlayer).has_animation("cerrado"):
		(anim as AnimationPlayer).play("cerrado")
		(anim as AnimationPlayer).advance(0.0)
	var caja: AABB = _caja(modelo, Transform3D.IDENTITY)
	var raiz := Node3D.new()
	raiz.add_child(modelo)
	if caja.size.y <= 0.0001:
		return raiz
	var f: float = 1.0
	var ancho: Dictionary = t.get("MEDIDA_ANCHO", {})
	if ancho.has(id):
		f = float(ancho[id]) / maxf(caja.size.x, caja.size.z)
	else:
		f = float((t.get("MEDIDA", {}) as Dictionary).get(id, 1.0)) / caja.size.y
	modelo.scale *= f
	var cx: float = caja.position.x + caja.size.x * 0.5
	var cz: float = caja.position.z + caja.size.z * 0.5
	modelo.position = -Vector3(cx, caja.position.y, cz) * f
	var planas: Dictionary = t.get("PLANAS", {})
	if planas.has(id):
		var grosor: float = float(planas[id])
		var alto_final: float = caja.size.y * f
		if alto_final > grosor:
			modelo.position.y -= alto_final - grosor
	return raiz


static func _caja(n: Node, acum: Transform3D) -> AABB:
	var t: Transform3D = acum
	if n is Node3D:
		t = acum * (n as Node3D).transform
	var res := AABB()
	var vacia: bool = true
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		res = t * (n as MeshInstance3D).mesh.get_aabb()
		vacia = false
	for h in n.get_children():
		var sub: AABB = _caja(h, t)
		if sub.size != Vector3.ZERO:
			res = sub if vacia else res.merge(sub)
			vacia = false
	return res


## --- 13/10: visuales compartidos por el juego y la vista previa del editor (para que se vean IGUAL en los dos) ---

## Tinte amarillo del cristal (fuente eléctrica `e`): material propio por malla, con un brillo suave. Lo aplican el
## Reactivo3D del juego (objetos_3d.gd) y el marcador `e` en el editor. Antes solo el juego: en el editor salía azul.
## 10/10: ya no pinta la malla entera de amarillo plano (tapaba el musgo y la piedra del modelo): conserva la textura
## original y solo pasa a amarillo los píxeles de tono azul/cian; el resto del albedo queda como venía.
const CODIGO_TINTE_AMARILLO: String = """
shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float tono_desde = 0.45;     // el azul del cristal cae en 0.50-0.60 (cian a azul); el musgo (0.15-0.25) y la piedra no
uniform float tono_hasta = 0.72;
uniform float tono_destino = 0.125;  // amarillo cálido
uniform float emision = 0.55;
vec3 a_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}
vec3 a_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}
void fragment() {
	vec3 t = texture(albedo_tex, UV).rgb;
	vec3 hsv = a_hsv(pow(t, vec3(1.0 / 2.2)));          // el tono se mide en sRGB, como se ve
	float k = smoothstep(tono_desde - 0.04, tono_desde, hsv.x) * (1.0 - smoothstep(tono_hasta, tono_hasta + 0.04, hsv.x));
	k *= smoothstep(0.05, 0.16, hsv.y);                 // solo los grises casi sin color (piedra clara, reflejos blancos) no cambian
	vec3 amarillo = pow(a_rgb(vec3(tono_destino, clamp(hsv.y * 1.8, 0.0, 0.85), hsv.z)), vec3(2.2));
	ALBEDO = mix(t, amarillo, k);
	EMISSION = amarillo * k * emision;
	ROUGHNESS = 0.6;
}
"""
static var _sombreador_amarillo: Shader = null


static func tinte_amarillo(nodo: Node) -> void:
	if nodo is MeshInstance3D:
		var mi := nodo as MeshInstance3D
		var tex: Texture2D = null
		var activo: Material = mi.get_active_material(0)
		if activo is BaseMaterial3D:
			tex = (activo as BaseMaterial3D).albedo_texture
		elif activo is ShaderMaterial:
			# En el juego el Reactivo3D ya cambió el material por el de Ocluso3D (círculo de transparencia): ahí la
			# textura va en el parámetro `tex_albedo`. Sin esto, el juego caía al tinte plano y salía todo amarillo.
			tex = (activo as ShaderMaterial).get_shader_parameter("tex_albedo") as Texture2D
		if tex != null:
			if _sombreador_amarillo == null:
				_sombreador_amarillo = Shader.new()
				_sombreador_amarillo.code = CODIGO_TINTE_AMARILLO
			var sm := ShaderMaterial.new()
			sm.shader = _sombreador_amarillo
			sm.set_shader_parameter("albedo_tex", tex)
			mi.material_override = sm
		else:
			# sin textura que conservar: el tinte plano de antes
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(1.0, 0.86, 0.3)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.88, 0.35)
			m.emission_energy_multiplier = 0.45
			mi.material_override = m
	for h in nodo.get_children():
		tinte_amarillo(h)


## Telaraña (Pablo, 7/10, Tripo). Cada GLB trae DOS piezas lado a lado, que se separan por el signo de x:
##   telarana_red.glb:  x < 0 la red sana (blanca) · x > 0 la red ardiendo (brasas naranjas).
##   telarana_base.glb: x < 0 el tronco seco sobre la roca con musgo · x > 0 un tronco fino suelto.
## Antes vivía solo en prueba_test2.gd y el marcador `r` del editor era una caja.
const TELARANA_RED: String = "res://arte/meshy/telarana/telarana_red.glb"
const TELARANA_BASE: String = "res://arte/meshy/telarana/telarana_base.glb"
const TELARANA_ESCALA_RED: float = 3.9       ## la red sana mide 0,5 → 1,95 u: cubre la casilla entre los dos troncos
const TELARANA_ESCALA_BASE: float = 2.1      ## el tronco grande mide 1,0 → 2,1 u
const TELARANA_ALTO_RED: float = 1.15        ## la red sube 1,15 sobre el suelo
static var _tel_mallas: Dictionary = {}      ## "sana" | "ardiendo" | "tronco" | "palo" -> [Mesh, AABB de la parte]
static var _tel_probado: bool = false


static func telarana_cargar() -> bool:
	if _tel_probado:
		return not _tel_mallas.is_empty()
	_tel_probado = true
	var partes: Dictionary = {}
	for par in [[TELARANA_RED, "sana", "ardiendo"], [TELARANA_BASE, "tronco", "palo"]]:
		var malla: Mesh = _malla_de_glb(String(par[0]))
		if malla == null:
			return false
		partes[par[1]] = _mitad_malla(malla, true)
		partes[par[2]] = _mitad_malla(malla, false)
	_tel_mallas = partes
	return true


## Una parte de la telaraña centrada en x/z, apoyada en y = 0 (si `al_suelo`) y escalada.
static func telarana_parte(clave: String, escala_parte: float, al_suelo: bool) -> MeshInstance3D:
	var d: Array = _tel_mallas[clave]
	var m := MeshInstance3D.new()
	m.name = clave
	m.mesh = d[0] as Mesh
	var caja: AABB = d[1]
	var cen: Vector3 = caja.get_center()
	var y0: float = caja.position.y if al_suelo else 0.0
	m.scale = Vector3.ONE * escala_parte
	m.position = Vector3(-cen.x, -y0 if al_suelo else -cen.y, -cen.z) * escala_parte
	return m


## Los dos troncos de la telaraña, a los lados de la red, en coordenadas de la casilla (los usa el juego y el editor).
static func telarana_troncos() -> Array:
	var tronco: MeshInstance3D = telarana_parte("tronco", TELARANA_ESCALA_BASE, true)
	tronco.position += Vector3(-S * 0.42, 0.0, -0.15)
	var palo: MeshInstance3D = telarana_parte("palo", TELARANA_ESCALA_BASE * 1.25, true)
	palo.position += Vector3(S * 0.43, 0.0, -0.1)
	return [tronco, palo]


## La telaraña entera (red sana + troncos) tal como la pone el juego: para la vista previa del marcador `r`.
static func visual_telarana() -> Node3D:
	if not telarana_cargar():
		return null
	var raiz := Node3D.new()
	var sana: MeshInstance3D = telarana_parte("sana", TELARANA_ESCALA_RED, false)
	sana.position.y += TELARANA_ALTO_RED
	raiz.add_child(sana)
	for t in telarana_troncos():
		raiz.add_child(t as Node3D)
	return raiz


static func _malla_de_glb(ruta: String) -> Mesh:
	if not ResourceLoader.exists(ruta):
		return null
	var ps: PackedScene = load(ruta) as PackedScene
	if ps == null:
		return null
	var raiz: Node = ps.instantiate()
	var mi: MeshInstance3D = raiz as MeshInstance3D
	if mi == null:
		var l: Array = raiz.find_children("*", "MeshInstance3D", true, false)
		mi = l[0] as MeshInstance3D if not l.is_empty() else null
	var m: Mesh = mi.mesh if mi != null else null
	raiz.free()
	return m


## [Mesh, AABB de la parte]: los triángulos de `malla` cuyo centro tiene x < 0 (`izquierda`) o x >= 0. Conserva UV y material.
static func _mitad_malla(malla: Mesh, izquierda: bool) -> Array:
	var res := ArrayMesh.new()
	var caja := AABB()
	var hay: bool = false
	for si in range(malla.get_surface_count()):
		var arr: Array = malla.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var nuevo := PackedInt32Array()
		var t: int = 0
		while t + 2 < idx.size():
			var mx: float = (v[idx[t]].x + v[idx[t + 1]].x + v[idx[t + 2]].x) / 3.0
			if (mx < 0.0) == izquierda:
				for k in range(3):
					nuevo.append(idx[t + k])
					caja = AABB(v[idx[t + k]], Vector3.ZERO) if not hay else caja.expand(v[idx[t + k]])
					hay = true
			t += 3
		arr[Mesh.ARRAY_INDEX] = nuevo
		res.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		res.surface_set_material(res.get_surface_count() - 1, malla.surface_get_material(si))
	# 11/10: la malla conserva TODOS los vértices (solo cambian los índices), así que su AABB salía con las dos mitades juntas (el
	# doble de ancho y descentrado). Con el de la parte, lo que se mide sobre ella (cuerpo de colisión) es lo que se ve.
	res.custom_aabb = caja
	res.set_meta("aabb_parte", caja)       # get_aabb() devuelve el de todos los vértices; quien mida la parte lee esto
	return [res, caja]


## Modelo de un personaje (goblin, elemental, NPC, jugador) para la vista previa de su marcador: el mismo GLB y el mismo alto
## que le da el juego (PruebaTest2._personaje: PJ_* y ALTO_PJ; Pj3D.MODELO_DE), con los pies en y = 0. Sin animar.
static func visual_personaje(opciones: Array, altos: Dictionary, modelos: Dictionary) -> Node3D:
	for o in opciones:
		var id: String = String(o)
		var ruta: String = "res://arte/modelos/%s.glb" % String(modelos.get(id, id))
		if not ResourceLoader.exists(ruta):
			continue
		var ps: PackedScene = load(ruta) as PackedScene
		if ps == null:
			continue
		var m: Node3D = ps.instantiate() as Node3D
		var caja: AABB = _caja(m, Transform3D.IDENTITY)
		var raiz := Node3D.new()
		raiz.add_child(m)
		if caja.size.y > 0.0001:
			var f: float = float(altos.get(id, 1.0)) / caja.size.y
			m.scale *= f
			m.position.y = -caja.position.y * f
		return raiz
	return null
