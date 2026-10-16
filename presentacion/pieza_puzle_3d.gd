class_name PiezaPuzle3D
extends Node3D

## PIEZAS DE PUZLE (16/10, Pipeline, Fase 13.5/13.7). El modelo, los estados, los efectos y el sonido de cada pieza de `objetos/` del Juego
## (Pulsador3D, Compuerta3D, Barril3D, Molino3D, NexoRayo3D…), SIN tocar su lógica: el Juego instancia una de estas por pieza, la cuelga de
## su nodo y le dice en qué estado está. Sustituye a los cilindros y cajas de placeholder.
##
##   var v: PiezaPuzle3D = PiezaPuzle3D.crear("pulsador", {"tinte": "agua"})
##   add_child(v)                    # el origen está en el CENTRO DE LA BASE, y no lleva suelo ni colisión (la colisión es la del Juego)
##   v.poner_estado("hundido")       # anima, suena y lanza el efecto; con `poner_estado("hundido", false)` salta sin animar ni sonar
##
## TABLA DE ESTADOS (la misma está en docs/ARTE.md §5): `ESTADOS`. Un id que la familia no conoce se ignora (devuelve false): el Juego
## puede llamar sin miedo. Los efectos y los sonidos se disparan al CAMBIAR de estado con `animar` = true; `sonido = false` los mudo.
##
## Todo se dibuja con primitivas facetadas en el estilo chibi del Bosque (colores planos, aristas visibles) y con los NODOS NOMBRADOS que
## el Juego puede necesitar (`rueda` en el molino: la gira el Juego). Cuando haya GLB de Meshy (arte/meshy/piezas/), `crear` cargará
## `res://arte/piezas/<familia>.tscn` si existe y la API NO cambia: mismos ids de estado, mismos nodos nombrados.
##
## MODELOS DE MESHY (16/10, láminas «puzle»): si existen los GLB de `res://arte/meshy/puzle/` (`MODELO_ARCHIVO`), cada familia se construye con
## ellos (un nodo por pieza, ya ORIENTADO, a ESCALA de `CAJA` y con el origen en el centro de la base; las piezas de una misma familia vienen
## ENSAMBLADAS en el origen: el marco y la hoja, la base y el botón…). Si falta el archivo o una pieza, se dibuja la primitiva de siempre.
## Los ids de estado y los nodos con nombre (`boton`, `tapa`, `hoja`, `rueda`, `marca`, `cascote_N`…) son los mismos en los dos casos.
## `crear(familia, {"modelos": false})` fuerza las primitivas; `PiezaPuzle3D.usar_modelos = false` lo hace para todas (las pruebas lo usan).
##
## Medidas (u, escala de casilla 2,3): ver `CAJA`.

signal estado_cambiado(id: String)

const ESTADOS: Dictionary = {
	"pulsador": ["arriba", "hundido"],
	"placa": ["arriba", "hundida"],
	"compuerta": ["cerrada", "abierta"],
	"compuerta_hielo": ["entera", "derritiendose", "nada"],
	"roca": ["entera", "rota"],
	"barril": ["entero", "mecha", "explosion"],
	"molino": ["quieto"],
	"pila": ["seca", "mojada", "electrificada"],
	"poste_nivel": ["apagado", "encendido"],
	"reja": ["cerrada", "abriendose", "abierta"],
	"tapon_hielo": ["entero", "derritiendose", "nada"],
}

## Caja que ocupa cada familia (ancho X, alto Y, fondo Z; origen en el centro de la base). La compuerta y la reja llevan el ancho en X:
## para una losa que cruza la casilla de norte a sur (`vertical` = true en Compuerta3D) se llama `orientar(true)`.
const CAJA: Dictionary = {
	"pulsador": Vector3(0.9, 0.9, 0.9), "placa": Vector3(1.8, 0.1, 1.8), "compuerta": Vector3(2.2, 1.5, 0.42),
	"compuerta_hielo": Vector3(2.2, 1.5, 0.42), "roca": Vector3(2.2, 1.3, 2.2), "barril": Vector3(0.9, 0.95, 0.9),
	"molino": Vector3(2.0, 1.65, 1.5), "pila": Vector3(1.1, 0.5, 1.1), "poste_nivel": Vector3(0.3, 2.0, 0.3),
	"reja": Vector3(2.2, 2.4, 0.42), "tapon_hielo": Vector3(0.9, 0.4, 0.9),
}

## Qué GLB (de `RUTA_PUZLE`) guarda cada pieza. Una lámina de Meshy por archivo: Fantasy Dungeon Props (dungeon), Forgotten Fantasy Pro (forgotten) y
## Fantasy Terrain Asset (terrain). Cada pieza es un nodo con su id como nombre (cómo se separaron: docs/ARTE.md §12).
const RUTA_PUZLE: String = "res://arte/meshy/puzle/"
const MODELO_ARCHIVO: Dictionary = {
	"compuerta_marco": "puzle_dungeon", "compuerta_hoja_madera": "puzle_dungeon", "compuerta_hoja_hierro": "puzle_dungeon",
	"pulsador_base": "puzle_dungeon", "pulsador_boton": "puzle_dungeon", "placa_marco": "puzle_dungeon", "placa_tapa": "puzle_dungeon",
	"reja_marco": "puzle_forgotten", "reja_hoja": "puzle_forgotten", "poste_vara": "puzle_forgotten", "poste_farolillo": "puzle_forgotten",
	"tinaja_ruina_vacia": "puzle_forgotten", "tapon_hielo": "puzle_forgotten",
	"barril": "puzle_terrain", "compuerta_hoja_hielo": "puzle_terrain", "pila_piedra": "puzle_terrain", "pila_borne": "puzle_terrain",
	"pila_borne_piedra": "puzle_terrain", "roca_entera": "puzle_terrain", "roca_cascote_0": "puzle_terrain", "roca_cascote_1": "puzle_terrain",
	"roca_cascote_2": "puzle_terrain", "roca_cascote_3": "puzle_terrain", "molino_rueda": "puzle_terrain", "molino_soporte": "puzle_terrain",
	"molino_eje": "puzle_terrain",
}
## Con modelos: el eje del molino queda a esta altura (el poste del modelo es bajo: la rueda mide Ø1,08 y gira justo sobre el suelo) y
## los bornes de la pila se separan un poco más (el borne del modelo es más ancho que la caja de cobre).
const MOLINO_EJE_Y_MODELO: float = 0.54
const BORNE_X_MODELO: float = 0.72
const T_MECHA: float = 1.2                         ## s que arde la mecha: la misma de Barril3D.T_MECHA (si el Juego la cambia, pasa `{"mecha": s}` a `crear`)
const T_DERRETIR: float = 3.2                      ## s que tarda el hielo en derretirse
const T_COMPUERTA: float = 0.6                     ## la misma de Compuerta3D.T_MOVER
const BAJA_COMPUERTA: float = 0.9                  ## lo que baja la hoja al abrirse (u)
const TINTE: Dictionary = {"magia": Color(0.88, 0.3, 0.24), "agua": Color(0.28, 0.58, 1.0), "presencia": Color(0.95, 0.8, 0.3)}

## 16/10 (14.2 c): los colores de las piezas salen de la PALETA CERRADA (Paleta3D; docs/ARTE.md §10), no de valores propios. El musgo y la
## madera oscura son la hierba de sombra y la madera ensombrecidas (`darkened`), no colores nuevos; el cobre, el naranja de los flancos.
const C_PIEDRA: Color = Paleta3D.PIEDRA
const C_PIEDRA_OSC: Color = Paleta3D.PIEDRA_OSCURA
static var C_MUSGO: Color = Paleta3D.HIERBA_SOMBRA.darkened(0.3)
const C_MADERA: Color = Paleta3D.MADERA
static var C_MADERA_OSC: Color = Paleta3D.MADERA.darkened(0.25)
const C_HIERRO: Color = Paleta3D.METAL
const C_COBRE: Color = Paleta3D.TIERRA_FLANCO
const C_HIELO: Color = Color(0.72, 0.92, 1.0, 0.72)
const C_AGUA: Color = Color(0.3, 0.6, 1.0, 0.82)
const C_AGUA_ELEC: Color = Color(1.0, 0.88, 0.35, 0.85)

static var _tex_runa: Texture2D = null

var familia: String = ""
var estado: String = ""
var sonido: bool = true                            ## false = ni sonidos ni efectos (las pruebas sin ventana)
var tinte: String = "magia"                        ## pulsador: "magia" (rojo) | "agua" (azul) | "presencia" (ocre)
var rueda: Node3D = null                           ## molino: la rueda de palas (la gira el Juego con `rueda.rotate_x(...)`; el eje queda quieto)
var _opc: Dictionary = {}
var _eje_y: float = 0.82                           ## molino: altura del eje (con modelo, `MOLINO_EJE_Y_MODELO`)
var _borne_x: float = 0.62                         ## pila: separación de los bornes
var _mecha_x: float = 0.1                          ## barril: dónde sale la mecha (con modelo, en el agujero del centro)
var _hielo_color: Color = C_HIELO                  ## el color que se le pone al hielo entero (con modelo, blanco: manda la textura)
var _runa_apagada: Color = Color(0.25, 0.23, 0.22, 0.85)   ## la runa de la placa sin pulsar (con modelo, invisible: ya viene tallada en la tapa)
var _n: Dictionary = {}                            ## nodos nombrados de la pieza
var _m: Dictionary = {}                            ## materiales propios (se animan al cambiar de estado)
var _tween: Tween = null
var _fx_vivo: Array = []                           ## emisores continuos del estado actual (se apagan al salir de él)
var _t: float = 0.0
static var usar_modelos: bool = true               ## false = siempre primitivas (pruebas)
static var _mallas_modelo: Dictionary = {}          ## id -> Mesh (se saca una vez del GLB; el árbol instanciado se libera)
var _sombra: MeshInstance3D = null                 ## la sombra de contacto (SombraContacto3D); se esconde cuando la pieza «desaparece»


## Crea la pieza de `familia` (ver ESTADOS) ya en su estado inicial. `opc`: tinte (pulsador), material "madera"|"hierro" (compuerta),
## marca (poste_nivel: altura de la marca en u), mecha (barril: s). null si la familia no existe.
static func crear(p_familia: String, opc: Dictionary = {}) -> PiezaPuzle3D:
	if not ESTADOS.has(p_familia):
		push_warning("PiezaPuzle3D: familia desconocida «%s»" % p_familia)
		return null
	var p := PiezaPuzle3D.new()
	p.familia = p_familia
	p._opc = opc
	p.name = "Puzle_" + p_familia
	p.tinte = String(opc.get("tinte", "magia"))
	p._construir()
	if p_familia != "placa":          # la placa va a ras del suelo: no proyecta nada
		var c: Vector3 = CAJA[p_familia]
		var dx: float = c.x * 1.15
		var dz: float = c.z * 1.15 if absf(c.x - c.z) < 0.3 else c.z * 1.15 + 0.25
		p._sombra = SombraContacto3D.poner(p, dx, dz, 0.012)
	p.poner_estado(String(ESTADOS[p_familia][0]), false)
	return p


func caja() -> Vector3:
	return CAJA[familia]


## La malla del modelo de Meshy de la pieza `id` (null si no hay GLB, no está esa pieza o `usar_modelos` es false). Se saca del GLB una sola
## vez y se guarda; el árbol instanciado se libera en el acto (el Mesh y sus materiales siguen vivos mientras alguien los use).
## PÚBLICA a propósito: el Juego la usa para la tinaja vacía (`PiezaPuzle3D.malla_modelo("tinaja_ruina_vacia")`).
static func malla_modelo(id: String) -> Mesh:
	if not usar_modelos or not MODELO_ARCHIVO.has(id):
		return null
	if _mallas_modelo.has(id):
		return _mallas_modelo[id]
	var ruta: String = RUTA_PUZLE + String(MODELO_ARCHIVO[id]) + ".glb"
	if not ResourceLoader.exists(ruta):
		return null
	var ps: PackedScene = load(ruta) as PackedScene
	if ps == null:
		return null
	var raiz: Node = ps.instantiate()
	var mesh: Mesh = null
	for h in raiz.find_children(id, "MeshInstance3D", true, false):
		mesh = (h as MeshInstance3D).mesh
	raiz.free()
	if mesh != null:
		_mallas_modelo[id] = mesh
	return mesh


## ¿Esta instancia dibuja `id` con su modelo? (`usar_modelos`, que haya GLB y que `crear` no lo haya desactivado con `{"modelos": false}`).
func _usa(id: String) -> bool:
	return bool(_opc.get("modelos", true)) and malla_modelo(id) != null


## Cuelga de `padre` el modelo `id` (ya orientado y a escala; su origen es el de la familia, salvo `pos`). null si no hay modelo.
func _modelo(padre: Node3D, id: String, nombre: String = "", pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh: Mesh = malla_modelo(id)
	if mesh == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = nombre if nombre != "" else id
	mi.position = pos
	padre.add_child(mi)
	return mi


## Copia PROPIA del material del modelo `id` (para animar el color o el brillo de una instancia sin tocar a las demás).
static func _material_modelo(id: String) -> StandardMaterial3D:
	var mesh: Mesh = malla_modelo(id)
	var m: Material = mesh.surface_get_material(0) if mesh != null else null
	if m is StandardMaterial3D:
		return (m as StandardMaterial3D).duplicate() as StandardMaterial3D
	return _mat(Color(0.8, 0.8, 0.8))


## Material de hielo para un modelo: el del GLB (la textura de cristales) pero translúcido y con un poco de luz propia.
static func _hielo_modelo(id: String) -> StandardMaterial3D:
	var m: StandardMaterial3D = _material_modelo(id)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 1.0, 1.0, 0.82)
	m.roughness = 0.2
	m.emission_enabled = true
	m.emission = Color(0.45, 0.8, 1.0)
	m.emission_energy_multiplier = 0.2
	return m


## Gira la pieza para una losa que cruza la casilla de norte a sur (compuerta, reja y molino con su eje).
func orientar(vertical: bool) -> void:
	rotation.y = PI * 0.5 if vertical else 0.0


## Cambia el pulsador de modo (y de color) sin reconstruirlo.
func poner_tinte(modo: String) -> void:
	if not TINTE.has(modo):
		return
	tinte = modo
	if familia == "pulsador":
		poner_estado(estado, false)


## Poste de nivel: sube o baja la marca (altura en u sobre la base).
func poner_marca(altura: float) -> void:
	if _n.has("marca"):
		(_n["marca"] as Node3D).position.y = clampf(altura, 0.2, 1.6)


## La runa de la placa de presión: encendida o apagada, sin tocar la posición de la tapa.
func poner_runa(encendida: bool) -> void:
	if _m.has("runa"):
		_brillo(_m["runa"], Color(1.0, 0.85, 0.4), 2.0 if encendida else 0.0)


## Pone la pieza en el estado `id`. Devuelve false si la familia no lo conoce. `animar` = false salta directo (sin movimiento, sonido ni efecto).
func poner_estado(id: String, animar: bool = true) -> bool:
	if not (ESTADOS[familia] as Array).has(id):
		return false
	var antes: String = estado
	estado = id
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_apagar_fx()
	if animar and is_inside_tree():
		_tween = create_tween().set_parallel(true)
		_tween.tween_interval(0.01)
	call("_e_" + familia, id, animar, antes)
	if _sombra != null:
		_sombra.visible = id != "nada" and id != "explosion"
	set_process(familia == "barril" and id == "mecha" or familia == "pila" and id == "electrificada")
	estado_cambiado.emit(id)
	return true


func _process(delta: float) -> void:
	_t += delta
	if familia == "barril" and estado == "mecha":
		var k: float = 1.0 - clampf(_t / float(_opc.get("mecha", T_MECHA)), 0.0, 1.0)
		_brillo(_m["cuerpo"], Color(1.0, 0.4, 0.1), 0.4 + 0.9 * absf(sin(_t * (14.0 + 18.0 * (1.0 - k)))))
	elif familia == "pila" and estado == "electrificada":
		_brillo(_m["borne"], COLOR_RAYO_PILA, 0.5 + 0.8 * absf(sin(_t * 31.0)) * randf())


const COLOR_RAYO_PILA: Color = Color(1.0, 0.9, 0.4)


## ---------------------------------------------------------------------------------------------------------------------------
## Utilidades de construcción
## ---------------------------------------------------------------------------------------------------------------------------

static func _mat(c: Color, rug: float = 0.85, met: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rug
	m.metallic = met
	if c.a < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func _brillo(m: StandardMaterial3D, c: Color, energia: float) -> void:
	m.emission_enabled = energia > 0.0
	m.emission = c
	m.emission_energy_multiplier = energia


## Malla con las caras planas (aristas visibles, estilo facetado) y, si `irregular` > 0, los vértices movidos de forma determinista.
static func _facetada(base: Mesh, irregular: float = 0.0, semilla: int = 1) -> ArrayMesh:
	var a: Array = base.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var n: int = idx.size() if idx.size() > 0 else v.size()
	for i in range(n):
		var p: Vector3 = v[idx[i] if idx.size() > 0 else i]
		if irregular > 0.0:
			# la misma posición recibe siempre el mismo empujón (los vértices duplicados de la costura no se separan)
			var h: int = hash(Vector3i((p * 100.0).round()) ) + semilla * 7919
			var d := Vector3(float((h >> 3) & 255) / 255.0 - 0.5, float((h >> 11) & 255) / 255.0 - 0.5, float((h >> 19) & 255) / 255.0 - 0.5)
			p += d * irregular
		st.add_vertex(p)
	st.generate_normals()
	return st.commit()


static func _mi(padre: Node3D, malla: Mesh, mat: Material, pos: Vector3, nombre: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = mat
	mi.position = pos
	if nombre != "":
		mi.name = nombre
	padre.add_child(mi)
	return mi


static func _caja_mesh(tam: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = tam
	return b


static func _cil_mesh(rt: float, rb: float, h: float, seg: int = 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


func _caja(padre: Node3D, tam: Vector3, pos: Vector3, mat: Material, nombre: String = "") -> MeshInstance3D:
	return _mi(padre, _caja_mesh(tam), mat, pos, nombre)


func _cil(padre: Node3D, rt: float, rb: float, h: float, pos: Vector3, mat: Material, seg: int = 10, nombre: String = "") -> MeshInstance3D:
	return _mi(padre, _cil_mesh(rt, rb, h, seg), mat, pos, nombre)


func _nodo(nombre: String, pos: Vector3 = Vector3.ZERO, padre: Node3D = null) -> Node3D:
	var n := Node3D.new()
	n.name = nombre
	n.position = pos
	(padre if padre != null else self).add_child(n)
	_n[nombre] = n
	return n


## Anima `prop` de `obj` a `val` (o lo pone directo si no se anima).
func _t_(obj: Object, prop: String, val: Variant, dur: float, retraso: float = 0.0, trans: int = Tween.TRANS_SINE, aceleracion: int = Tween.EASE_IN_OUT) -> void:
	if _tween == null or dur <= 0.0:
		obj.set_indexed(NodePath(prop), val)
		return
	_tween.tween_property(obj, prop, val, dur).set_trans(trans).set_ease(aceleracion).set_delay(retraso)


func _suena(nombre: String, animar: bool) -> void:
	if animar and sonido and is_inside_tree():
		Sfx.play(self, nombre)


## Dónde cuelgan los efectos: la escena (un hijo se iría con la pieza si el Juego la libera justo al terminar), y la posición en su espacio.
func _fx_padre() -> Node3D:
	var esc: Node = get_tree().current_scene if is_inside_tree() else null
	return (esc as Node3D) if esc is Node3D else self


func _fx_pos(local: Vector3) -> Vector3:
	var p: Node3D = _fx_padre()
	return local if p == self else p.to_local(to_global(local))


func _hay_fx(animar: bool) -> bool:
	return animar and sonido and is_inside_tree()


func _apagar_fx() -> void:
	for e in _fx_vivo:
		if is_instance_valid(e):
			(e as GPUParticles3D).emitting = false
			(e as GPUParticles3D).get_tree().create_timer(2.5, false).timeout.connect((e as GPUParticles3D).queue_free)
	_fx_vivo.clear()
	_t = 0.0


func _construir() -> void:
	call("_c_" + familia)


## ---------------------------------------------------------------------------------------------------------------------------
## 1. PULSADOR · Ø0,9 × 0,9 · arriba / hundido (tinte: magia rojo, agua azul, presencia ocre)
## ---------------------------------------------------------------------------------------------------------------------------

func _c_pulsador() -> void:
	if _usa("pulsador_base") and _usa("pulsador_boton"):
		_c_pulsador_modelo()
		return
	var piedra: StandardMaterial3D = _mat(C_PIEDRA)
	_cil(self, 0.43, 0.48, 0.5, Vector3(0, 0.25, 0), piedra, 10, "base")
	_cil(self, 0.5, 0.5, 0.06, Vector3(0, 0.03, 0), _mat(C_PIEDRA_OSC), 10, "zocalo")
	_m["aro"] = _mat(C_PIEDRA_OSC)
	_cil(self, 0.37, 0.37, 0.05, Vector3(0, 0.5, 0), _m["aro"], 10, "aro")
	_m["boton"] = _mat(TINTE["magia"], 0.45)
	_n["boton"] = _cil(self, 0.3, 0.33, 0.38, Vector3(0, 0.7, 0), _m["boton"], 10, "boton")


## Con modelo: la base lleva el aro de piedra tallado; el aro de luz es un anillo fino sobre el borde que solo se ve hundido. El botón sale ya
## colocado (arriba) en el GLB: su posición en `arriba` es 0 y `y_arriba` (meta) le dice a `_e_pulsador` dónde está su «arriba».
func _c_pulsador_modelo() -> void:
	_modelo(self, "pulsador_base", "base")
	_m["boton"] = _material_modelo("pulsador_boton")
	var boton: MeshInstance3D = _modelo(self, "pulsador_boton", "boton")
	boton.material_override = _m["boton"]
	boton.set_meta("y_arriba", 0.0)
	_n["boton"] = boton
	_m["aro"] = _mat(C_PIEDRA_OSC)
	var aro: MeshInstance3D = _cil(self, 0.4, 0.4, 0.03, Vector3(0, 0.385, 0), _m["aro"], 16, "aro")
	aro.visible = false
	_n["aro"] = aro


func _e_pulsador(id: String, animar: bool, antes: String) -> void:
	var col: Color = TINTE[tinte]
	(_m["boton"] as StandardMaterial3D).albedo_color = col
	var hundido: bool = id == "hundido"
	var ya: float = float((_n["boton"] as Node).get_meta("y_arriba", 0.7))      # primitiva: 0,7 · modelo: 0 (viene ya en su sitio)
	_t_(_n["boton"], "position:y", ya - 0.15 if hundido else ya, 0.08)
	if _n.has("aro"):
		(_n["aro"] as Node3D).visible = hundido
	_brillo(_m["boton"], col, 0.9 if hundido else 0.0)
	_brillo(_m["aro"], col, 1.4 if hundido else 0.0)
	(_m["aro"] as StandardMaterial3D).albedo_color = col.darkened(0.5) if hundido else C_PIEDRA_OSC
	if hundido and antes != id:
		_suena("boton_clic", animar)


## ---------------------------------------------------------------------------------------------------------------------------
## 2. PLACA DE PRESIÓN con runa · 1,8 × 1,8 × 0,1 · arriba / hundida (la runa se enciende al hundirse; `poner_runa` la fuerza)
## ---------------------------------------------------------------------------------------------------------------------------

func _c_placa() -> void:
	if _usa("placa_marco") and _usa("placa_tapa"):
		_c_placa_modelo()
		return
	# El marco es un BORDE hueco (cuatro listones) sobre un fondo bajo: así la tapa, al hundirse, se ve metida en él y no tapada por él.
	var osc: StandardMaterial3D = _mat(C_PIEDRA_OSC)
	_caja(self, Vector3(1.8, 0.03, 1.8), Vector3(0, 0.015, 0), osc, "fondo")
	for lado in [-1.0, 1.0]:
		_caja(self, Vector3(1.8, 0.1, 0.125), Vector3(0, 0.05, lado * 0.8375), osc, "marco")
		_caja(self, Vector3(0.125, 0.1, 1.55), Vector3(lado * 0.8375, 0.05, 0), osc, "marco")
	var tapa: Node3D = _nodo("tapa", Vector3(0, 0.08, 0))
	_caja(tapa, Vector3(1.55, 0.06, 1.55), Vector3.ZERO, _mat(C_PIEDRA), "losa")
	for sx in [-1.0, 1.0]:                              # cuatro tachuelas en las esquinas: se lee «placa», no «baldosa»
		for sz in [-1.0, 1.0]:
			_cil(tapa, 0.07, 0.07, 0.05, Vector3(sx * 0.66, 0.03, sz * 0.66), _mat(C_COBRE, 0.5, 0.15), 6)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _runa()
	m.albedo_color = Color(0.25, 0.23, 0.22, 0.85)
	m.emission_texture = _runa()
	_m["runa"] = m
	var q := QuadMesh.new()
	q.size = Vector2(1.1, 1.1)
	q.orientation = PlaneMesh.FACE_Y
	_mi(tapa, q, m, Vector3(0, 0.035, 0), "runa")


## Con modelo: la tapa trae la runa tallada; encima va la runa de luz (invisible apagada) que se enciende al hundirse. La tapa sale ya en su
## sitio en el GLB: `y_arriba` = 0.
func _c_placa_modelo() -> void:
	_modelo(self, "placa_marco", "marco")
	var tapa: Node3D = _nodo("tapa", Vector3.ZERO)
	tapa.set_meta("y_arriba", 0.0)
	_modelo(tapa, "placa_tapa", "losa")
	_runa_apagada = Color(0.25, 0.23, 0.22, 0.0)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _runa()
	m.albedo_color = _runa_apagada
	m.emission_texture = _runa()
	_m["runa"] = m
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	q.orientation = PlaneMesh.FACE_Y
	_mi(tapa, q, m, Vector3(0, 0.125, 0), "runa")


func _e_placa(id: String, animar: bool, antes: String) -> void:
	var hundida: bool = id == "hundida"
	var ya: float = float((_n["tapa"] as Node).get_meta("y_arriba", 0.08))      # primitiva: 0,08 · modelo: 0
	_t_(_n["tapa"], "position:y", ya - 0.04 if hundida else ya, 0.12)
	var m: StandardMaterial3D = _m["runa"]
	m.albedo_color = Color(1.0, 0.85, 0.4, 1.0) if hundida else _runa_apagada
	_brillo(m, Color(1.0, 0.85, 0.4), 2.0 if hundida else 0.0)
	if hundida and antes != id:
		_suena("placa_hunde", animar)


## Una runa sencilla dibujada a mano: aro y tres trazos en «ᛉ». Se genera una vez (no hace falta ninguna textura en disco).
static func _runa() -> Texture2D:
	if _tex_runa != null:
		return _tex_runa
	var n: int = 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n * 0.5, n * 0.5)
	var trazos: Array = [[Vector2(0, -26), Vector2(0, 34)], [Vector2(0, -2), Vector2(-24, -30)], [Vector2(0, -2), Vector2(24, -30)]]
	for y in range(n):
		for x in range(n):
			var p: Vector2 = Vector2(x, y) - c
			var d: float = absf(p.length() - 55.0)               # el aro
			for t in trazos:
				d = minf(d, _d_seg(p, t[0], t[1]))
			var a: float = 1.0 - smoothstep(2.5, 5.0, d)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_tex_runa = ImageTexture.create_from_image(img)
	return _tex_runa


static func _d_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (p - (a + ab * t)).length()


## ---------------------------------------------------------------------------------------------------------------------------
## 3. COMPUERTA de madera o hierro con guías · 2,2 × 1,3 × 0,3 · cerrada / abierta (la hoja baja 0,9 u)
## ---------------------------------------------------------------------------------------------------------------------------

## Dos postes con su ranura y un dintel: el marco común a la compuerta, la de hielo y la reja. `alto` = altura de los postes.
func _marco(alto: float, ancho: float = 2.2, grueso: float = 0.42) -> void:
	var p: StandardMaterial3D = _mat(C_PIEDRA)
	var oscuro: StandardMaterial3D = _mat(C_PIEDRA_OSC)
	for lado in [-1.0, 1.0]:
		_caja(self, Vector3(0.3, alto, grueso), Vector3(lado * (ancho * 0.5 - 0.15), alto * 0.5, 0), p, "poste")
		_caja(self, Vector3(0.34, 0.12, grueso + 0.06), Vector3(lado * (ancho * 0.5 - 0.15), alto + 0.06, 0), oscuro, "capitel")
	_caja(self, Vector3(ancho, 0.16, grueso), Vector3(0, alto + 0.08, 0), p, "dintel")
	_caja(self, Vector3(ancho * 0.9, 0.06, grueso * 0.7), Vector3(0, 0.03, 0), oscuro, "umbral")
	for sx in [-1.0, 1.0]:                                  # un poco de musgo en la base de cada poste: son ruinas
		_cil(self, 0.14, 0.2, 0.2, Vector3(sx * (ancho * 0.5 - 0.15), 0.1, grueso * 0.35), _mat(C_MUSGO), 6)


func _c_compuerta() -> void:
	var hierro: bool = String(_opc.get("material", "madera")) == "hierro"
	var id_hoja: String = "compuerta_hoja_hierro" if hierro else "compuerta_hoja_madera"
	if _usa("compuerta_marco") and _usa(id_hoja):
		_modelo(self, "compuerta_marco", "marco")
		_modelo(_nodo("hoja"), id_hoja, "modelo")          # la hoja sale ya dentro del marco: cerrada = posición 0
		return
	_marco(1.4)
	var hoja: Node3D = _nodo("hoja", Vector3(0, 0.0, 0))
	var madera: StandardMaterial3D = _mat(C_MADERA)
	var banda: StandardMaterial3D = _mat(C_HIERRO, 0.5, 0.6)
	if hierro:
		for k in range(7):                                  # barrotes
			_cil(hoja, 0.05, 0.05, 1.3, Vector3(-0.72 + k * 0.24, 0.65, 0), banda, 6)
		for y in [0.25, 1.05]:
			_caja(hoja, Vector3(1.7, 0.09, 0.12), Vector3(0, y, 0), banda)
	else:
		for k in range(4):                                  # cuatro tablones
			_caja(hoja, Vector3(0.41, 1.3, 0.14), Vector3(-0.63 + k * 0.42, 0.65, 0), _mat(C_MADERA if k % 2 == 0 else C_MADERA_OSC))
		for y in [0.28, 1.02]:                              # y dos flejes de hierro con remaches
			_caja(hoja, Vector3(1.7, 0.1, 0.18), Vector3(0, y, 0), banda)
			for sx in [-0.7, 0.0, 0.7]:
				_cil(hoja, 0.045, 0.045, 0.2, Vector3(sx, y, 0), _mat(C_COBRE, 0.5, 0.15), 6).rotation.x = PI * 0.5
	# un asa para que parezca de poleas
	_cil(self, 0.05, 0.05, 0.3, Vector3(0, 1.62, 0), _mat(C_HIERRO, 0.5, 0.6), 6)


func _e_compuerta(id: String, animar: bool, antes: String) -> void:
	var abierta: bool = id == "abierta"
	_t_(_n["hoja"], "position:y", -BAJA_COMPUERTA if abierta else 0.0, T_COMPUERTA)
	if antes != id and antes != "":
		_suena("compuerta_baja", animar)
		if _hay_fx(animar):
			VfxPuzle3D.polvo(_fx_padre(), _fx_pos(Vector3(0, 0.15, 0)), 0.5)


## ---------------------------------------------------------------------------------------------------------------------------
## 4. COMPUERTA DE HIELO · 2,2 × 1,3 × 0,3 · entera / derritiéndose / nada (el material es el de la costra de hielo: translúcido y celeste)
## ---------------------------------------------------------------------------------------------------------------------------

func _hielo_mat() -> StandardMaterial3D:
	var m: StandardMaterial3D = _mat(C_HIELO, 0.12)
	m.emission_enabled = true
	m.emission = Color(0.45, 0.8, 1.0)
	m.emission_energy_multiplier = 0.25
	m.rim_enabled = true
	m.rim = 0.6
	return m


func _c_compuerta_hielo() -> void:
	if _usa("compuerta_marco") and _usa("compuerta_hoja_hielo"):
		_modelo(self, "compuerta_marco", "marco")
		_hielo_color = Color(1.0, 1.0, 1.0, 0.82)
		_m["hielo"] = _hielo_modelo("compuerta_hoja_hielo")
		_modelo(_nodo("hoja"), "compuerta_hoja_hielo", "bloque").material_override = _m["hielo"]
		return
	_marco(1.4)
	var hoja: Node3D = _nodo("hoja")
	var m: StandardMaterial3D = _hielo_mat()
	_m["hielo"] = m
	_mi(hoja, _facetada(_caja_mesh(Vector3(1.75, 1.3, 0.3)), 0.07, 3), m, Vector3(0, 0.65, 0), "bloque")
	for k in range(5):                                      # cristales que sobresalen por arriba y por los lados
		var h: float = 0.35 + 0.12 * float(k % 3)
		var c: CylinderMesh = _cil_mesh(0.0, 0.13, h, 4)
		var mi: MeshInstance3D = _mi(hoja, _facetada(c, 0.03, k + 5), m, Vector3(-0.7 + k * 0.35, 1.3 + h * 0.4, 0.04 * float(k % 2) - 0.02), "cristal")
		mi.rotation = Vector3(0.0, k * 0.8, (float(k) - 2.0) * 0.1)


func _e_compuerta_hielo(id: String, animar: bool, antes: String) -> void:
	_derretir(id, animar, antes, 1.0)


## Entera → derritiéndose (baja y se aplasta soltando vapor) → nada. Lo comparten la compuerta y el tapón de hielo. `esc` = tamaño del vapor.
func _derretir(id: String, animar: bool, antes: String, esc: float) -> void:
	var hoja: Node3D = _n["hoja"]
	var m: StandardMaterial3D = _m["hielo"]
	match id:
		"entera", "entero":
			hoja.visible = true
			_t_(hoja, "scale", Vector3.ONE, 0.0)
			hoja.position.y = 0.0
			m.albedo_color = _hielo_color
		"derritiendose":
			hoja.visible = true
			_t_(hoja, "scale", Vector3(1.04, 0.14, 1.04), T_DERRETIR, 0.0, Tween.TRANS_QUAD, Tween.EASE_IN)
			_t_(m, "albedo_color:a", 0.3, T_DERRETIR)
			if antes != id:
				_suena("hielo_quiebra", animar)
				if _hay_fx(animar):
					var v: GPUParticles3D = VfxPuzle3D.vapor(_fx_padre(), _fx_pos(Vector3(0, 0.5, 0)), esc, true)
					_fx_vivo.append(v)
		"nada":
			hoja.visible = false
			if antes != id and antes == "derritiendose" and _hay_fx(animar):
				VfxPuzle3D.vapor(_fx_padre(), _fx_pos(Vector3(0, 0.2, 0)), esc)


## ---------------------------------------------------------------------------------------------------------------------------
## 5. ROCA DE DERRUMBE · Ø2,2 × 1,3 · entera / rota (cuatro cascotes que caen y quedan en el suelo)
## ---------------------------------------------------------------------------------------------------------------------------

const ROCA_TROZOS: Array = [
	{"r": 0.8, "pos": Vector3(0.0, 0.5, 0.0), "esc": Vector3(1.15, 0.8, 1.05), "suelta": Vector3(-0.15, 0.0, 0.1)},
	{"r": 0.6, "pos": Vector3(0.62, 0.42, 0.25), "esc": Vector3(1.0, 0.85, 1.0), "suelta": Vector3(1.05, 0.0, 0.5)},
	{"r": 0.58, "pos": Vector3(-0.58, 0.44, -0.3), "esc": Vector3(1.0, 0.85, 1.0), "suelta": Vector3(-1.0, 0.0, -0.55)},
	{"r": 0.5, "pos": Vector3(0.08, 0.92, -0.42), "esc": Vector3(1.0, 0.9, 1.0), "suelta": Vector3(0.3, 0.0, -1.0)},
]


func _c_roca() -> void:
	if _usa("roca_entera") and _usa("roca_cascote_0") and _usa("roca_cascote_1") and _usa("roca_cascote_2") and _usa("roca_cascote_3"):
		_c_roca_modelo()
		return
	var mat: StandardMaterial3D = _mat(Color(0.46, 0.44, 0.42), 1.0)
	var musgo: StandardMaterial3D = _mat(C_MUSGO, 1.0)
	for i in range(ROCA_TROZOS.size()):
		var t: Dictionary = ROCA_TROZOS[i]
		var s := SphereMesh.new()
		s.radius = float(t["r"])
		s.height = float(t["r"]) * 2.0
		s.radial_segments = 7
		s.rings = 4
		var mi: MeshInstance3D = _mi(self, _facetada(s, float(t["r"]) * 0.35, i + 1), mat, t["pos"], "cascote_%d" % i)
		mi.scale = t["esc"]
		mi.rotation = Vector3(0.0, float(i) * 1.3, 0.0)
		_n["cascote_%d" % i] = mi
	# una capa de musgo en lo alto: la roca lleva años ahí
	var cap := SphereMesh.new()
	cap.radius = 0.4
	cap.height = 0.5
	cap.radial_segments = 6
	cap.rings = 3
	_mi(_n["cascote_0"] as Node3D, _facetada(cap, 0.1, 9), musgo, Vector3(0.1, 0.55, 0.0), "musgo")


## Con modelo: la roca ENTERA es una sola malla (`entera`) y los cuatro cascotes son modelos aparte que están escondidos hasta que se rompe.
## Al romperse la entera desaparece y los cascotes salen de su sitio, caen al suelo (y = 0: su origen es la base) y quedan ahí.
func _c_roca_modelo() -> void:
	_n["entera"] = _modelo(self, "roca_entera", "entera")
	for i in range(ROCA_TROZOS.size()):
		var c: MeshInstance3D = _modelo(self, "roca_cascote_%d" % i, "cascote_%d" % i)
		c.visible = false
		_n["cascote_%d" % i] = c


func _e_roca_modelo(rota: bool, animar: bool, antes: String) -> void:
	(_n["entera"] as Node3D).visible = not rota
	for i in range(ROCA_TROZOS.size()):
		var t: Dictionary = ROCA_TROZOS[i]
		var c: Node3D = _n["cascote_%d" % i]
		c.visible = rota
		var d: Vector3 = t["suelta"]
		var p: Vector3 = t["pos"]
		if rota:
			if animar and antes != "rota":
				c.position = Vector3(p.x * 0.5, 0.4, p.z * 0.5)
			_t_(c, "position:x", d.x, 0.55, float(i) * 0.04, Tween.TRANS_QUAD, Tween.EASE_OUT)
			_t_(c, "position:z", d.z, 0.55, float(i) * 0.04, Tween.TRANS_QUAD, Tween.EASE_OUT)
			_t_(c, "position:y", 0.0, 0.75, float(i) * 0.04, Tween.TRANS_BOUNCE, Tween.EASE_OUT)
			_t_(c, "rotation:y", float(i + 1) * 0.9, 0.7, float(i) * 0.04)
		else:
			c.position = Vector3.ZERO
			c.rotation = Vector3.ZERO
	if rota and antes != "rota":
		_suena("derrumbe", animar)
		if _hay_fx(animar):
			VfxPuzle3D.polvo(_fx_padre(), _fx_pos(Vector3(0, 0.4, 0)), 1.3)


func _e_roca(id: String, animar: bool, antes: String) -> void:
	var rota: bool = id == "rota"
	if _n.has("entera"):
		_e_roca_modelo(rota, animar, antes)
		return
	for i in range(ROCA_TROZOS.size()):
		var t: Dictionary = ROCA_TROZOS[i]
		var c: Node3D = _n["cascote_%d" % i]
		var pos: Vector3 = t["pos"]
		var esc: Vector3 = t["esc"]
		if rota:
			var d: Vector3 = t["suelta"]
			var r: float = float(t["r"]) * 0.5                               # cascote: la mitad de grande, apoyado en el suelo
			_t_(c, "position:x", d.x, 0.55, float(i) * 0.04, Tween.TRANS_QUAD, Tween.EASE_OUT)
			_t_(c, "position:z", d.z, 0.55, float(i) * 0.04, Tween.TRANS_QUAD, Tween.EASE_OUT)
			_t_(c, "position:y", r * 0.7, 0.75, float(i) * 0.04, Tween.TRANS_BOUNCE, Tween.EASE_OUT)
			_t_(c, "scale", esc * 0.5, 0.55, float(i) * 0.04)
			_t_(c, "rotation:z", float(i + 1) * 0.9, 0.7, float(i) * 0.04)
		else:
			c.position = pos
			c.scale = esc
			c.rotation.z = 0.0
	if rota and antes != id:
		_suena("derrumbe", animar)
		if _hay_fx(animar):
			VfxPuzle3D.polvo(_fx_padre(), _fx_pos(Vector3(0, 0.4, 0)), 1.3)


## ---------------------------------------------------------------------------------------------------------------------------
## 6. BARRIL DE PÓLVORA · Ø0,9 × 0,95 · entero / mecha (arde `T_MECHA` s) / explosión (fogonazo; después ya no hay barril)
## ---------------------------------------------------------------------------------------------------------------------------

func _c_barril() -> void:
	if _usa("barril"):
		_m["cuerpo"] = _material_modelo("barril")
		var t: Node3D = _nodo("cuerpo")
		_modelo(t, "barril", "modelo").material_override = _m["cuerpo"]
		_mecha_x = 0.0                                       # el modelo trae el agujero de la mecha en el centro de la tapa
		_barril_mecha()
		return
	var cuerpo: StandardMaterial3D = _mat(C_MADERA)
	_m["cuerpo"] = cuerpo
	var tonel: Node3D = _nodo("cuerpo")
	_cil(tonel, 0.37, 0.4, 0.22, Vector3(0, 0.12, 0), cuerpo, 12)
	_cil(tonel, 0.44, 0.44, 0.5, Vector3(0, 0.47, 0), cuerpo, 12)               # la panza
	_cil(tonel, 0.4, 0.37, 0.22, Vector3(0, 0.83, 0), cuerpo, 12)
	_cil(tonel, 0.4, 0.4, 0.04, Vector3(0, 0.95, 0), _mat(C_MADERA_OSC), 12)     # la tapa
	var hierro: StandardMaterial3D = _mat(C_HIERRO, 0.5, 0.6)
	for y in [0.2, 0.47, 0.76]:
		var aro := MeshInstance3D.new()
		var t := TorusMesh.new()
		var r: float = 0.4 if y != 0.47 else 0.45
		t.inner_radius = r - 0.025
		t.outer_radius = r + 0.035
		t.rings = 12
		t.ring_segments = 5
		aro.mesh = t
		aro.material_override = hierro
		aro.position = Vector3(0, y, 0)
		tonel.add_child(aro)
	# Calavera pintada: dos ojos y una nariz en la panza (un barril de pólvora se reconoce de lejos)
	var pint: StandardMaterial3D = _mat(Color(0.12, 0.1, 0.09), 0.9)
	for sx in [-0.1, 0.1]:
		_mi(tonel, _facetada(SphereMesh.new(), 0.0, 1), pint, Vector3(sx, 0.5, 0.435), "ojo").scale = Vector3(0.06, 0.07, 0.03)
	_barril_mecha()


## La mecha (un cordón de 0,3 que se consume) y la luz del barril. Las comparten el barril de primitivas y el del modelo.
func _barril_mecha() -> void:
	var fus: Node3D = _nodo("mecha", Vector3(_mecha_x, 0.95, 0.0))
	_cil(fus, 0.018, 0.018, 0.3, Vector3(0, 0.15, 0), _mat(Color(0.85, 0.8, 0.6)), 5)
	_n["punta"] = _nodo("punta", Vector3(0, 0.3, 0), fus)
	var luz := OmniLight3D.new()
	luz.name = "luz"
	luz.light_color = Color(1.0, 0.6, 0.25)
	luz.omni_range = 2.5
	luz.light_energy = 0.0
	luz.position = Vector3(_mecha_x, 1.2, 0.0)
	add_child(luz)
	_n["luz"] = luz


func _e_barril(id: String, animar: bool, antes: String) -> void:
	var fus: Node3D = _n["mecha"]
	var tonel: Node3D = _n["cuerpo"]
	var luz: OmniLight3D = _n["luz"]
	var dura: float = float(_opc.get("mecha", T_MECHA))
	match id:
		"entero":
			tonel.visible = true
			fus.visible = true
			fus.scale = Vector3.ONE
			luz.light_energy = 0.0
			_brillo(_m["cuerpo"], Color.BLACK, 0.0)
		"mecha":
			tonel.visible = true
			fus.visible = true
			fus.scale = Vector3.ONE
			luz.light_energy = 1.4
			_t_(fus, "scale", Vector3(1.0, 0.08, 1.0), dura, 0.0, Tween.TRANS_LINEAR)
			if _hay_fx(animar):
				var ch: GPUParticles3D = VfxPuzle3D.chispas(self, Vector3(_mecha_x, 1.25, 0.0), true, 0.5)
				ch.local_coords = true
				_fx_vivo.append(ch)
				if _tween != null:
					_tween.tween_property(ch, "position:y", 0.98, dura).set_trans(Tween.TRANS_LINEAR)
			_suena("mecha", animar)
		"explosion":
			tonel.visible = false
			fus.visible = false
			luz.light_energy = 0.0
			if antes != id:
				_suena("explosion", animar)
				if _hay_fx(animar):
					VfxPuzle3D.fogonazo(_fx_padre(), _fx_pos(Vector3(0, 0.5, 0)), float(_opc.get("radio", 2.6)))


## ---------------------------------------------------------------------------------------------------------------------------
## 7. RUEDA DE MOLINO · Ø1,5, ancho 0,6 · el nodo «rueda» va aparte del eje y de los dos postes: la gira el Juego (`rueda.rotate_x(w * dt)`)
## ---------------------------------------------------------------------------------------------------------------------------

const MOLINO_RADIO: float = 0.75
const MOLINO_EJE_Y: float = 0.82                   ## altura del eje sobre la base

func _c_molino() -> void:
	if _usa("molino_rueda") and _usa("molino_soporte") and _usa("molino_eje"):
		_c_molino_modelo()
		return
	var madera: StandardMaterial3D = _mat(C_MADERA)
	var oscura: StandardMaterial3D = _mat(C_MADERA_OSC)
	var hierro: StandardMaterial3D = _mat(C_HIERRO, 0.5, 0.6)
	# Soportes: dos postes de piedra con una muesca, y el eje (QUIETO) de poste a poste.
	var eje: Node3D = _nodo("eje", Vector3(0, MOLINO_EJE_Y, 0))
	for lado in [-1.0, 1.0]:
		_caja(self, Vector3(0.22, MOLINO_EJE_Y + 0.25, 0.4), Vector3(lado * 0.92, (MOLINO_EJE_Y + 0.25) * 0.5, 0.0), _mat(C_PIEDRA), "poste")
		_caja(self, Vector3(0.3, 0.1, 0.5), Vector3(lado * 0.92, 0.05, 0.0), _mat(C_PIEDRA_OSC))
		_cil(eje, 0.13, 0.13, 0.12, Vector3(lado * 0.78, 0, 0), hierro, 8).rotation.z = PI * 0.5          # cojinete
	var barra: MeshInstance3D = _cil(eje, 0.07, 0.07, 1.7, Vector3.ZERO, oscura, 8, "barra")
	barra.rotation.z = PI * 0.5
	# La rueda: dos aros octogonales unidos por 8 palas y 4 radios. Eje de giro = X (la normal de los aros).
	rueda = _nodo("rueda", Vector3(0, MOLINO_EJE_Y, 0))
	for sx in [-0.26, 0.26]:
		var aro := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = MOLINO_RADIO - 0.06
		t.outer_radius = MOLINO_RADIO
		t.rings = 8
		t.ring_segments = 4
		aro.mesh = t
		aro.rotation.z = PI * 0.5
		aro.position = Vector3(sx, 0, 0)
		aro.material_override = madera
		rueda.add_child(aro)
	for k in range(8):
		var brazo := Node3D.new()
		brazo.rotation.x = float(k) * TAU / 8.0
		rueda.add_child(brazo)
		_caja(brazo, Vector3(0.6, 0.06, 0.34), Vector3(0, MOLINO_RADIO - 0.04, 0.0), oscura, "pala")       # la pala, ancho 0,6 (eje X)
		if k % 2 == 0:
			_caja(brazo, Vector3(0.1, MOLINO_RADIO - 0.1, 0.06), Vector3(0, (MOLINO_RADIO - 0.1) * 0.5, 0.0), madera, "radio")
	_cil(rueda, 0.16, 0.16, 0.5, Vector3.ZERO, madera, 8, "buje").rotation.z = PI * 0.5


## Con modelo: el soporte (un poste de piedra) va una vez a cada lado (el segundo, girado 180°) y el eje de madera con sus abrazaderas cruza de
## poste a poste. La rueda es un modelo con el eje de giro en X y su centro en el origen del nodo `rueda`, que está a la altura del eje.
func _c_molino_modelo() -> void:
	_eje_y = MOLINO_EJE_Y_MODELO
	var eje: Node3D = _nodo("eje", Vector3(0, _eje_y, 0))
	_modelo(eje, "molino_eje", "barra", Vector3(0, -_eje_y, 0))      # el GLB trae el eje ya a su altura: se compensa la del nodo
	for lado in [1.0, -1.0]:
		var poste: MeshInstance3D = _modelo(self, "molino_soporte", "poste")
		poste.rotation.y = 0.0 if lado > 0.0 else PI
	rueda = _nodo("rueda", Vector3(0, _eje_y, 0))
	_modelo(rueda, "molino_rueda", "modelo")


func _e_molino(_id: String, _animar: bool, _antes: String) -> void:
	pass                                                  # un solo estado: lo que se mueve es `rueda`, y lo mueve el Juego


## ---------------------------------------------------------------------------------------------------------------------------
## 8. PILA DE PIEDRA con dos bornes de cobre · Ø1,1 × 0,45 · seca / mojada (disco de agua) / electrificada (bornes brillan, chispas)
## ---------------------------------------------------------------------------------------------------------------------------

func _c_pila() -> void:
	if _usa("pila_piedra") and _usa("pila_borne"):
		_c_pila_modelo()
		return
	var p: StandardMaterial3D = _mat(C_PIEDRA)
	_cil(self, 0.55, 0.5, 0.3, Vector3(0, 0.15, 0), p, 10, "pie")
	_cil(self, 0.55, 0.55, 0.12, Vector3(0, 0.36, 0), _mat(C_PIEDRA_OSC), 10, "borde")
	_cil(self, 0.4, 0.4, 0.1, Vector3(0, 0.38, 0), _mat(Color(0.2, 0.2, 0.22)), 10, "hueco")           # el vaso, oscuro por dentro
	_m["borne"] = _mat(C_COBRE, 0.45, 0.15)           # poco metal: sin reflejos del entorno un cobre muy metálico sale marrón
	for lado in [-1.0, 1.0]:
		_caja(self, Vector3(0.22, 0.5, 0.12), Vector3(lado * 0.62, 0.25, 0), _m["borne"], "borne")
		_cil(self, 0.07, 0.07, 0.1, Vector3(lado * 0.62, 0.55, 0), _m["borne"], 6, "punta")
	_m["agua"] = _mat(C_AGUA, 0.1)
	_n["agua"] = _cil(self, 0.4, 0.4, 0.05, Vector3(0, 0.445, 0), _m["agua"], 10, "agua")       # asoma 0,015 sobre el borde del hueco


## Con modelo: la pila (cuenco de piedra con el fondo de madera) y dos bornes de cobre, uno a cada lado. El agua es un disco dentro del cuenco,
## por debajo del borde (el cuenco mide 0,38 de alto).
func _c_pila_modelo() -> void:
	_borne_x = BORNE_X_MODELO
	_modelo(self, "pila_piedra", "pie")
	_m["borne"] = _material_modelo("pila_borne")
	for lado in [-1.0, 1.0]:
		_modelo(self, "pila_borne", "borne", Vector3(lado * _borne_x, 0.0, 0.0)).material_override = _m["borne"]
	_m["agua"] = _mat(C_AGUA, 0.1)
	_n["agua"] = _cil(self, 0.42, 0.42, 0.04, Vector3(0, 0.3, 0), _m["agua"], 12, "agua")


func _e_pila(id: String, animar: bool, antes: String) -> void:
	var agua: MeshInstance3D = _n["agua"]
	var m: StandardMaterial3D = _m["agua"]
	var borne: StandardMaterial3D = _m["borne"]
	match id:
		"seca":
			agua.visible = false
			_brillo(borne, Color.BLACK, 0.0)
			if antes in ["mojada", "electrificada"] and _hay_fx(animar):
				VfxPuzle3D.vapor(_fx_padre(), _fx_pos(Vector3(0, 0.45, 0)), 0.8)         # el agua se evapora
		"mojada":
			agua.visible = true
			m.albedo_color = C_AGUA
			_brillo(m, Color.BLACK, 0.0)
			_brillo(borne, Color.BLACK, 0.0)
			if animar:
				agua.scale = Vector3(0.3, 1.0, 0.3)
				_t_(agua, "scale", Vector3.ONE, 0.3, 0.0, Tween.TRANS_BACK, Tween.EASE_OUT)
			if antes == "seca":
				_suena("agua", animar)
				if _hay_fx(animar):
					VfxPuzle3D.salpicadura(_fx_padre(), _fx_pos(Vector3(0, 0.42, 0)), 1.0)
		"electrificada":
			agua.visible = true
			agua.scale = Vector3.ONE
			m.albedo_color = C_AGUA_ELEC
			_brillo(m, Color(1.0, 0.85, 0.3), 1.2)
			_brillo(borne, COLOR_RAYO_PILA, 0.8)
			_suena("zumbido_electrico", animar)
			if _hay_fx(animar):
				for lado in [-1.0, 1.0]:
					var ch: GPUParticles3D = VfxPuzle3D.chispas(self, Vector3(lado * _borne_x, 0.6, 0.0), true, 0.7)
					ch.local_coords = true
					_fx_vivo.append(ch)


## ---------------------------------------------------------------------------------------------------------------------------
## 9. POSTE DE NIVEL · 0,1 × 1,8 · apagado / encendido (vara con marca y farolillo; `poner_marca` mueve la marca)
## ---------------------------------------------------------------------------------------------------------------------------

func _c_poste_nivel() -> void:
	var modelo: bool = _usa("poste_vara") and _usa("poste_farolillo")
	if modelo:
		_modelo(self, "poste_vara", "vara")                 # la vara y su pie de piedra, en una sola malla (1,8 de alto)
	else:
		_cil(self, 0.16, 0.2, 0.1, Vector3(0, 0.05, 0), _mat(C_PIEDRA_OSC), 8, "pie")
		_cil(self, 0.045, 0.05, 1.7, Vector3(0, 0.9, 0), _mat(C_MADERA), 6, "vara")
	var marca: Node3D = _nodo("marca", Vector3(0, float(_opc.get("marca", 0.9)), 0))
	_caja(marca, Vector3(0.22, 0.05, 0.22), Vector3.ZERO, _mat(Color(0.88, 0.3, 0.24), 0.5), "banda")
	_caja(marca, Vector3(0.1, 0.1, 0.1), Vector3(0.14, 0.0, 0.0), _mat(Color(0.88, 0.3, 0.24), 0.5), "flecha").rotation.y = PI * 0.25
	# El farolillo: una cabina de cristal con cuatro varillas y un caperuza.
	var farol: Node3D = _nodo("farol", Vector3(0, 1.8 if modelo else 1.7, 0))
	_m["cristal"] = _mat(Color(0.6, 0.55, 0.4, 0.55), 0.2)
	if modelo:
		# El farolillo del modelo (hierro y cristal) lleva una esfera de luz dentro: es ella la que se enciende y se apaga.
		_modelo(farol, "poste_farolillo", "modelo")
		_mi(farol, _facetada(SphereMesh.new(), 0.0, 1), _m["cristal"], Vector3(0, 0.2, 0), "cristal").scale = Vector3(0.075, 0.085, 0.075)
		var luz_m := OmniLight3D.new()
		luz_m.name = "luz"
		luz_m.light_color = Color(1.0, 0.78, 0.4)
		luz_m.omni_range = 3.2
		luz_m.light_energy = 0.0
		luz_m.position = Vector3(0, 2.0, 0)
		add_child(luz_m)
		_n["luz"] = luz_m
		return
	_mi(farol, _facetada(SphereMesh.new(), 0.0, 1), _m["cristal"], Vector3(0, 0.12, 0), "cristal").scale = Vector3(0.12, 0.13, 0.12)
	for k in range(4):
		var ang: float = float(k) * TAU / 4.0 + PI * 0.25
		_caja(farol, Vector3(0.02, 0.28, 0.02), Vector3(cos(ang) * 0.1, 0.12, sin(ang) * 0.1), _mat(C_HIERRO, 0.5, 0.6))
	_cil(farol, 0.0, 0.16, 0.12, Vector3(0, 0.33, 0), _mat(C_HIERRO, 0.5, 0.6), 6, "caperuza")
	var luz := OmniLight3D.new()
	luz.name = "luz"
	luz.light_color = Color(1.0, 0.78, 0.4)
	luz.omni_range = 3.2
	luz.light_energy = 0.0
	luz.position = Vector3(0, 1.8, 0)
	add_child(luz)
	_n["luz"] = luz


func _e_poste_nivel(id: String, animar: bool, antes: String) -> void:
	var enc: bool = id == "encendido"
	var m: StandardMaterial3D = _m["cristal"]
	m.albedo_color = Color(1.0, 0.82, 0.45, 0.85) if enc else Color(0.45, 0.45, 0.5, 0.55)
	_brillo(m, Color(1.0, 0.7, 0.3), 2.2 if enc else 0.0)
	_t_(_n["luz"], "light_energy", 1.5 if enc else 0.0, 0.25)
	if enc and antes != id:
		_suena("prender", animar)


## ---------------------------------------------------------------------------------------------------------------------------
## 10. PUERTA O REJA DE PREMIO · 2,2 × 2,4 × 0,3 · cerrada / abriéndose / abierta (la reja baja hasta esconderse en el suelo)
## ---------------------------------------------------------------------------------------------------------------------------

func _c_reja() -> void:
	if _usa("reja_marco") and _usa("reja_hoja"):
		_modelo(self, "reja_marco", "marco")               # con el escudo sobre el dintel
		_modelo(_nodo("hoja"), "reja_hoja", "modelo")      # con su cerrojo; sale ya dentro del marco: cerrada = posición 0
		return
	_marco(2.2)
	# Un escudo de piedra sobre el dintel: es la puerta del premio y tiene que parecer importante.
	_cil(self, 0.0, 0.3, 0.3, Vector3(0, 2.62, 0), _mat(C_PIEDRA_OSC), 4)
	_cil(self, 0.1, 0.1, 0.08, Vector3(0, 2.5, 0.22), _mat(C_COBRE, 0.45, 0.15), 8).rotation.x = PI * 0.5
	var hoja: Node3D = _nodo("hoja")
	var hierro: StandardMaterial3D = _mat(C_HIERRO, 0.5, 0.6)
	for k in range(8):
		_cil(hoja, 0.045, 0.05, 2.1, Vector3(-0.77 + k * 0.22, 1.05, 0), hierro, 6)
		_cil(hoja, 0.0, 0.07, 0.14, Vector3(-0.77 + k * 0.22, 2.17, 0), hierro, 4)              # punta de lanza
	for y in [0.5, 1.15, 1.8]:
		_caja(hoja, Vector3(1.75, 0.08, 0.1), Vector3(0, y, 0), hierro)
	_cil(hoja, 0.15, 0.15, 0.1, Vector3(0, 1.15, 0.07), _mat(C_COBRE, 0.45, 0.15), 8).rotation.x = PI * 0.5    # el cerrojo


func _e_reja(id: String, animar: bool, antes: String) -> void:
	var hoja: Node3D = _n["hoja"]
	match id:
		"cerrada":
			_t_(hoja, "position:y", 0.0, T_COMPUERTA * 1.5)
		"abriendose":
			_t_(hoja, "position:y", -2.2, 1.4, 0.0, Tween.TRANS_QUAD, Tween.EASE_IN_OUT)
			if _tween != null:
				_tween.tween_callback(func() -> void:
					estado = "abierta"                    # al terminar de bajar queda «abierta» (sin repetir sonido ni efecto)
					estado_cambiado.emit("abierta")).set_delay(1.4)
			_suena("compuerta_baja", animar)
			if _hay_fx(animar):
				VfxPuzle3D.polvo(_fx_padre(), _fx_pos(Vector3(0, 0.15, 0)), 0.7)
		"abierta":
			hoja.position.y = -2.2


## ---------------------------------------------------------------------------------------------------------------------------
## 12. TAPÓN DE HIELO del desagüe · 0,9 × 0,9 · entero / derritiéndose / nada
## ---------------------------------------------------------------------------------------------------------------------------

func _c_tapon_hielo() -> void:
	if _usa("tapon_hielo"):
		_hielo_color = Color(1.0, 1.0, 1.0, 0.82)
		_m["hielo"] = _hielo_modelo("tapon_hielo")
		_modelo(_nodo("hoja"), "tapon_hielo", "bloque").material_override = _m["hielo"]
		return
	var hoja: Node3D = _nodo("hoja")
	var m: StandardMaterial3D = _hielo_mat()
	_m["hielo"] = m
	_mi(hoja, _facetada(_cil_mesh(0.4, 0.44, 0.34, 6), 0.05, 4), m, Vector3(0, 0.17, 0), "bloque")
	for k in range(4):
		var c: CylinderMesh = _cil_mesh(0.0, 0.1, 0.26, 4)
		var mi: MeshInstance3D = _mi(hoja, _facetada(c, 0.02, k + 2), m, Vector3(cos(float(k) * 1.57) * 0.18, 0.4, sin(float(k) * 1.57) * 0.18), "cristal")
		mi.rotation = Vector3(cos(float(k)) * 0.2, 0.0, sin(float(k)) * 0.2)


func _e_tapon_hielo(id: String, animar: bool, antes: String) -> void:
	_derretir(id, animar, antes, 0.55)


## ---------------------------------------------------------------------------------------------------------------------------
## 11. TINAJA: se queda el modelo del Bosque (`tinaja_ruina`, Pieza3D) y se le añade el estado «vacía» (el Juego avisa con AguaSim3D.fuentes_agotadas())
## ---------------------------------------------------------------------------------------------------------------------------

const TINAJA_ESTADOS: Array = ["llena", "vacia"]

## Estado de una tinaja ya colocada (cualquier Node3D con el modelo dentro). «vacia»: el modelo se ve seco y polvoriento (un velo pardo
## sobre todas sus mallas) y suelta una última bocanada de vapor; «llena»: lo quita. Mientras no haya un modelo propio de tinaja vacía
## (cuando lo haya, `Pieza3D.cambiar_visual(pieza, "tinaja_ruina_vacia")` lo sustituye y esto deja de hacer falta), esta es la API.
static func poner_estado_tinaja(pieza: Node3D, id: String, animar: bool = true) -> bool:
	if pieza == null or not TINAJA_ESTADOS.has(id):
		return false
	var vacia: bool = id == "vacia"
	var velo: StandardMaterial3D = null
	if vacia:
		velo = StandardMaterial3D.new()
		velo.albedo_color = Color(0.5, 0.42, 0.33, 0.38)
		velo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		velo.roughness = 1.0
	for mi in _mallas(pieza):
		(mi as GeometryInstance3D).material_overlay = velo
	pieza.set_meta("estado_tinaja", id)
	if vacia and animar and pieza.is_inside_tree():
		VfxPuzle3D.vapor(pieza, Vector3(0, 1.0, 0), 0.7)
		Sfx.play(pieza, "creak")
	return true


static func _mallas(raiz: Node) -> Array:
	var r: Array = []
	for h in raiz.get_children():
		if h is GeometryInstance3D:
			r.append(h)
		r.append_array(_mallas(h))
	return r
