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
const CARPETA_PIEZAS: String = "res://poc_25d/meshy/piezas/"

const BIBLIOTECAS: Array = ["res://poc_25d/meshy/arboles_2.glb", "res://poc_25d/meshy/mercado.glb",
	"res://poc_25d/meshy/bosque.glb", "res://poc_25d/meshy/objetos.glb", "res://poc_25d/meshy/magia.glb"]

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
	"baldosa_guardado": 0.12, "seto_seco": 1.3, "dummy": 1.4, "seta_reactiva": 0.9, "flor_reactiva": 0.9,
	"raiz_reactiva": 0.9, "portal_salida": 3.0, "pocion": 0.45, "pilar": 1.8,
	"cristal_sanctuario": 1.4,   # 12/10: la fuente eléctrica (cristal azul de Meshy, pintado amarillo por objetos_3d.gd); su alto
	"tinaja_ruina": 1.5,      # ruinas_agua.glb (Meshy «Mossbound Relics»): la tinaja que vierte el agua
	# campamento_goblin.glb (Meshy «Tusks of the Red Fang»). Alturas en unidades; la puerta y la empalizada van por ancho (abajo).
	"tienda_goblin": 2.0, "torre_goblin": 3.2, "estandarte_goblin": 2.2,
}

const MEDIDA_ANCHO: Dictionary = {"fogata": S * 0.6, "puente": S * 1.05, "pasadero": S * 0.8, "placa_peso": S * 0.8,
	"baldosa_guardado": S * 0.85,
	# Canales de ruinas (enderezados en el GLB). Mismo factor de escala los dos (el codo mide 0,439 de ancho frente a 0,493 del recto).
	# `canal_recto`: corre a lo largo de X, abierto por -X y +X (giro 90 = a lo largo de Z). `canal_codo`: abierto por -X y +Z,
	# cerrado por +X y -Z (giro 180 = abierto por +X y -Z; 90 = +Z y +X; 270 = -Z y -X).
	"canal_recto": S, "canal_codo": S * 0.89,
	# Campamento goblin: la puerta mide 1,6 casillas de ancho (cabe en una y se apoya en las empalizadas de los lados, ~1,8 de alto);
	# la empalizada, 1 casilla (~1,0 de alto). La tienda es más ancha que una casilla (~3 de ancho con 2,0 de alto).
	"puerta_goblin": S * 1.6, "empalizada_goblin": S}

const PLANAS: Dictionary = {"placa_peso": 0.05, "baldosa_guardado": 0.04, "pasadero": 0.10}


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
			return _normalizar(escena_suelta.instantiate() as Node3D, id)
	for b in _bibliotecas:
		var n: Node = (b as Node).find_child(id, true, false)
		if n != null and n is Node3D:
			var copia: Node3D = (n as Node3D).duplicate() as Node3D
			copia.transform = Transform3D.IDENTITY
			return _normalizar(copia, id)
	return null


## --- Colisión de la pieza (6.10, para la fuente de solidez por nodos del Lanzador) ---

## Piezas cuyo cuerpo sólido es solo el tronco (la copa no impide el paso: se pasa por debajo).
const SOLO_TRONCO: Array = ["arbol_redondo", "arbol_redondo_2", "pino", "pino_2"]
const TRONCO_RADIO: float = 0.38
const TRONCO_ALTO: float = 2.0
## Las demás: una caja del 80 % de lo que ocupa el modelo (se roza el borde sin chocar, como las huellas de siempre),
## con altura entre 1,0 y 1,6: ha de cubrir de sobra donde mira la esfera del jugador (0,3-0,9 por encima del suelo).
const COLISION_ANCHO: float = 0.8
const COLISION_ALTO_MIN: float = 1.0
const COLISION_ALTO_MAX: float = 1.6

static var _formas: Dictionary = {}


## Forma de la colisión de la pieza `id_pedido`, en su espacio local (base en y = 0, sin escala):
## {"cilindro": bool, "radio": float, "tam": Vector3 (caja), "alto": float, "centro": Vector3}.
static func forma_colision(id_pedido: String) -> Dictionary:
	var id: String = id_real(id_pedido)
	if _formas.has(id):
		return _formas[id]
	var f: Dictionary = {}
	if SOLO_TRONCO.has(id):
		f = {"cilindro": true, "radio": TRONCO_RADIO, "alto": TRONCO_ALTO, "centro": Vector3(0.0, TRONCO_ALTO * 0.5, 0.0)}
	else:
		var vis: Node3D = crear_visual(id)
		var caja := AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 1.0, 1.0))     # sin modelo: un metro cúbico
		if vis != null:
			caja = _caja(vis, Transform3D.IDENTITY)
			vis.free()
		var alto: float = clampf(caja.size.y, COLISION_ALTO_MIN, COLISION_ALTO_MAX)
		var tam := Vector3(maxf(caja.size.x * COLISION_ANCHO, 0.3), alto, maxf(caja.size.z * COLISION_ANCHO, 0.3))
		var c: Vector3 = caja.position + caja.size * 0.5
		f = {"cilindro": false, "tam": tam, "alto": alto, "centro": Vector3(c.x, alto * 0.5, c.z)}
	_formas[id] = f
	return f


static func _normalizar(modelo: Node3D, id: String) -> Node3D:
	var t: Dictionary = _constantes()
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
const TELARANA_RED: String = "res://poc_25d/meshy/telarana/telarana_red.glb"
const TELARANA_BASE: String = "res://poc_25d/meshy/telarana/telarana_base.glb"
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
	return [res, caja]


## Modelo de un personaje (goblin, elemental, NPC, jugador) para la vista previa de su marcador: el mismo GLB y el mismo alto
## que le da el juego (PruebaTest2._personaje: PJ_* y ALTO_PJ; Pj3D.MODELO_DE), con los pies en y = 0. Sin animar.
static func visual_personaje(opciones: Array, altos: Dictionary, modelos: Dictionary) -> Node3D:
	for o in opciones:
		var id: String = String(o)
		var ruta: String = "res://poc_25d/%s.glb" % String(modelos.get(id, id))
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
