class_name VfxEstado3D
extends Node

## VFX POR ESTADO DE LA MATERIA (Pipeline, 18/10, receta V2). Escucha `Lanzador3D.hechizo_v2(estado, elemento, g, origen, dir, props)` y dibuja el
## hechizo como un VOLUMEN ELIPSOIDE (x, y, z en casillas) en lugar de una forma con nombre. El porqué de dibujar por ESTADO y no por forma: en la
## receta V2 las formas ya no existen en la lógica (un «muro» es un volumen X×3 de estado sólido), así que un VFX por forma no tendría de dónde
## colgarse, y un VFX por estado escala solo a cualquier (X, Y, Z) que el jugador consiga componer.
##
## Seis efectos, uno por estado, todos escalados a los semiejes del volumen y con la misma vida (nace → vive `persiste` → muere):
##   solido   bloques facetados que emergen del suelo, uno por casilla × nivel (tierra: roca y polvo; hielo: cristal, escarcha y luz fría)
##   liquido  una masa que CAE sobre el volumen y se deshace en gotas y un anillo de salpicadura (el agua de verdad la pone AguaSim: aquí no hay agua)
##   plasma   llamas que llenan el volumen, brasas, charco de luz en el suelo que late a 4 Hz (el pulso de 0,25 s del juego) y una luz
##   energia  arcos DENTRO del volumen (re-sorteados cada 70 ms, como P2 de VFX_RAYO_HIELO.md), halo azul, destello y una luz
##   gas      remolino de motas (y hojas si es viento) que sube en espiral por el elipsoide
##   campo    burbuja translúcida que distorsiona lo que hay detrás, anillo en el suelo y motas lentas
## Propiedades (MEJORAS_POTENCIA.md §2), dibujadas con lo que REALMENTE pasa: desde la entrada 160 la señal trae `eventos` [{t, pos, dir}] (una por
## tanda de casillas, con la hora y el sitio en que el Lanzador3D las materializa), `persiste`, `suelo` y `t_caida`, así que ya no se aproxima nada:
##   copias   = un volumen COMPLETO por copia, una al lado de otra (el Lanzador las separa 2·x casillas de lado), no ecos detrás
##   viaja    = el volumen avanza por el camino real (8 casillas/s), con estela, y las tandas que va dejando persisten (huellas translúcidas)
##   rebotes  = chispas y anillo en el punto y el instante en que el camino cambia de dirección
##   crece    = nace al 30 % en planta (X y Z, no la altura) y crece lineal el tiempo que dice la receta ((1 − 0,3) / crece)
##   solidez  = borde duro (cáscara brillante)
## Sin `eventos` (un lanzador de mentira) se reconstruyen con la misma regla de Lanzador3D._eventos_v2 (copias de lado, viaje recto, sin rebotes).
## Color: siempre el del elemento (COLORES, de Paleta3D / VFX_RAYO_HIELO.md §7 / PERFIL de conjuro_vfx_3d.gd).
## Presupuesto POR VOLUMEN: ≤ 2 luces y ≤ 400 «partículas» (se cuentan TODAS las instancias de MultiMesh, también los bloques). Con copias hay un
## volumen por copia: solo el primero lleva luz, así que un hechizo entero no pasa de 1 luz (rayo/fuego/hielo) aunque tenga cuatro copias. Los
## contadores `luces` y `particulas` de cada EfectoHechizo se rellenan al construir y la prueba los verifica recorriendo el árbol, sin fiarse de ellos.
## Además (entradas 167–169 del Juego):
##   · CENTRO: con barrera (`props` trae `solidez`) el volumen es la circunferencia que rodea al jugador y está centrado en él: el adelanto sobre la
##     mano lo da `Lanzador3D.GeometriaV2.adelanto(g)` (0 con barrera; z − radio base sin ella), el mismo que usan las casillas y el alambre del lab.
##   · `Lanzador3D.vfx_hechizo(nombre, posicion, elemento)`: la acción `vfx`, la `estela` y el `efecto_impacto` de un hechizo piden un efecto por NOMBRE.
##     Se resuelve por palabras clave del nombre (`tipo_de_vfx`) a una ráfaga corta de partículas del color del elemento (clase `Rafaga`).
##   · PROYECTILES (velocidad > 0): no emiten `hechizo_v2`. Cada `HechizoVivo` proyectil que entra en el lanzador recibe su volumen colgado de él, así que
##     se mueve con él (su `global_position` es la del proyectil); al acabar, el dibujo se suelta, se apaga en 0,35 s y se libera.
##
## Uso:   VfxEstado3D.conectar(lanzador, mundo)     (mundo = el Node3D donde colgar los hechizos; todo se libera solo al acabar)

const MAX_LUCES: int = 2
const MAX_PARTICULAS: int = 400
## Densidad visual de plasma y gas (1 = la de antes). Con 1 las llamas se sumaban hasta saturar a blanco y tapaban el contorno
## del volumen; con menos partículas, más pequeñas y más transparentes se lee la silueta (el elipsoide que da el tamaño).
const DENSIDAD: float = 0.4
## MODO PLANO (elemento de prueba del laboratorio, «agua sin VFX»): con `plano = true` TODO volumen se dibuja solo como un elipsoide translúcido azul, sin llamas, motas,
## chispas ni luces, para ver el tamaño y el contorno sin nada encima. Lo pone el lab (Pablo: «no distingo nada en el fuego»); en el juego se queda en false.
static var plano: bool = false
const MAX_CARRILES: int = 4                ## copias máximas (Sigils.GLIFOS_V2.repeticion.tope)
const VEL_VIAJE: float = 8.0               ## casillas/s del volumen que viaja (Lanzador3D.VEL_VIAJA_V2)
const ESCALA_NACE: float = 0.3             ## fracción en planta con la que nace un volumen que crece (Lanzador3D.ESCALA_NACE_V2)
const MAX_PROYECTILES: int = 8            ## dibujos de proyectil a la vez (Hechizo.MAX_VIVOS = 32 hijos incluidos serían 32 × 280 partículas); el resto vuela sin dibujo
const MAX_RAFAGAS: int = 24               ## ráfagas de `vfx_hechizo` a la vez (la estela pide una cada 0,5 u: un proyectil rápido las encadena)
const MAX_BLOQUES: int = 150               ## tope de bloques de roca de un hechizo sólido (cuentan como partículas)

## Tamaño de una casilla en unidades (Terreno3D.casilla = 2,3). Es propiedad para que la prueba y el juego puedan fijarlo sin depender de Terreno3D.
var casilla: float = 2.3
## Alto de un nivel de tierra (Terreno3D.ALTO_NIVEL = 2,3 · 0,45). Con él se apilan los bloques de un volumen sólido sobre sus casillas reales.
var alto_nivel: float = 2.3 * 0.45
## Opcional: altura del suelo de una casilla (Terreno3D.y_pies). Sin ella, todo el volumen se apoya en `g["suelo"]` (la altura bajo el origen).
var y_pies: Callable = Callable()
var _proy_vivos: int = 0          ## dibujos de proyectil vivos (colgados de su HechizoVivo o apagándose)
var _proy_con_luz: int = 0        ## de ellos, los que llevan luz (tope MAX_LUCES en total, no una por proyectil)
var _rafagas: int = 0

## Palabras clave del nombre de un VFX → tipo de ráfaga. El PRIMER tipo cuya palabra aparezca gana; sin palabra, «estela» / «impacto» y, si no, genérico.
const PALABRAS_VFX: Array = [
	["humo", "humo"], ["ceniza", "humo"], ["vapor", "humo"], ["niebla", "humo"],
	["chispa", "chispa"], ["electr", "chispa"], ["rayo", "chispa"], ["relampag", "chispa"], ["brasa", "chispa"], ["ascua", "chispa"],
	["gota", "gota"], ["agua", "gota"], ["salpic", "gota"], ["burbuja", "gota"],
	["piedra", "piedra"], ["roca", "piedra"], ["polvo", "piedra"], ["tierra", "piedra"], ["escombro", "piedra"],
	["copo", "copo"], ["hielo", "copo"], ["escarcha", "copo"], ["nieve", "copo"], ["cristal", "copo"],
	["destello", "destello"], ["luz", "destello"], ["flash", "destello"],
	["estela", "estela"], ["rastro", "estela"],
	["impacto", "estallido"], ["golpe", "estallido"], ["explo", "estallido"], ["estallido", "estallido"],
]
## Cada tipo: n partículas, vida (s), vel (u/s) radial, sube (u/s, + sube), grav (u/s², + cae), tam (u), mezcla del sprite, color (clave de COLORES), crece (el sprite se hincha).
const TIPOS_VFX: Dictionary = {
	"estallido": {"n": 20, "vida": 0.5, "vel": 3.5, "sube": 0.5, "grav": 0.0, "tam": 0.22, "mezcla": "blend_add", "color": "mota", "crece": false},
	"estela": {"n": 6, "vida": 0.5, "vel": 0.3, "sube": 0.3, "grav": 0.0, "tam": 0.2, "mezcla": "blend_add", "color": "c", "crece": false},
	"chispa": {"n": 12, "vida": 0.4, "vel": 4.5, "sube": 0.0, "grav": 6.0, "tam": 0.09, "mezcla": "blend_add", "color": "mota", "crece": false},
	"humo": {"n": 7, "vida": 0.9, "vel": 0.5, "sube": 0.8, "grav": 0.0, "tam": 0.4, "mezcla": "blend_mix", "color": "hondo", "crece": true},
	"gota": {"n": 12, "vida": 0.55, "vel": 2.5, "sube": 0.0, "grav": 9.0, "tam": 0.09, "mezcla": "blend_mix", "color": "mota", "crece": false},
	"piedra": {"n": 10, "vida": 0.7, "vel": 3.0, "sube": 0.0, "grav": 9.0, "tam": 0.12, "mezcla": "blend_mix", "color": "hondo", "crece": false},
	"copo": {"n": 12, "vida": 0.8, "vel": 1.5, "sube": 0.0, "grav": 1.5, "tam": 0.1, "mezcla": "blend_add", "color": "mota", "crece": false},
	"destello": {"n": 3, "vida": 0.25, "vel": 0.2, "sube": 0.0, "grav": 0.0, "tam": 0.9, "mezcla": "blend_add", "color": "mota", "crece": false},
	"generico": {"n": 12, "vida": 0.5, "vel": 2.0, "sube": 0.2, "grav": 0.0, "tam": 0.15, "mezcla": "blend_add", "color": "c", "crece": false},
}

## RESPALDO para un lanzador sin `g["persiste"]` (los de mentira de las pruebas): cuánto vive lo creado por estado y elemento (s), como RuneData.persiste:
## fuego 3, tierra 8, hielo 6, rayo 0,2, viento 1,5, tiempo 4. El Lanzador3D ya manda `persiste` (entrada 160, multiplicado por la calidad del trazo) y
## manda esa cifra, no esta tabla.
const PERSISTE: Dictionary = {
	"solido": {"tierra": 8.0, "hielo": 6.0, "_": 5.0},
	"liquido": {"_": 1.0},
	"plasma": {"fuego": 3.0, "_": 3.0},
	"energia": {"rayo": 0.2, "_": 0.2},
	"gas": {"viento": 1.5, "_": 1.5},
	"campo": {"tiempo": 4.0, "_": 3.0},
}

const COLORES: Dictionary = {
	"fuego": {"c": Color(0.95, 0.33, 0.12), "mota": Color(1.0, 0.82, 0.38), "hondo": Color(0.45, 0.08, 0.04)},
	"agua": {"c": Color(0.16, 0.62, 0.98), "mota": Color(0.70, 0.90, 1.0), "hondo": Color(0.20, 0.45, 0.80)},
	"viento": {"c": Color(0.56, 0.83, 0.42), "mota": Color(0.88, 1.0, 0.80), "hondo": Color(0.33, 0.58, 0.28)},
	"rayo": {"c": Color(0.35, 0.62, 1.0), "mota": Color(1.0, 1.0, 0.90), "hondo": Color(1.0, 0.93, 0.40)},
	"hielo": {"c": Color(0.62, 0.82, 0.96), "mota": Color(0.86, 0.93, 0.99), "hondo": Color(0.55, 0.74, 0.92)},
	"tierra": {"c": Color(0.78, 0.53, 0.35), "mota": Color("B8ADB8"), "hondo": Color("835832")},
	"tiempo": {"c": Color(0.72, 0.58, 0.98), "mota": Color(0.95, 0.88, 1.0), "hondo": Color(0.45, 0.30, 0.75)},
}
const COLOR_RESERVA: Dictionary = {"c": Color(0.7, 0.75, 0.85), "mota": Color(0.95, 0.95, 1.0), "hondo": Color(0.45, 0.5, 0.6)}

## Sprite suave (círculo o llama) que mira a la cámara; `billboard` = 0 lo deja tumbado (charcos de luz en el suelo). El color y la transparencia
## salen del color de la instancia del MultiMesh, así UN material sirve a cientos de partículas.
const CODIGO_SUAVE: String = """
shader_type spatial;
render_mode unshaded, %MEZCLA%, depth_draw_never, cull_disabled, shadows_disabled;
uniform float billboard = 1.0;
uniform float llama = 0.0;
void vertex() {
	if (billboard > 0.5) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	}
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r;
	if (llama > 0.5) {
		float w = mix(0.22, 1.0, UV.y);
		r = length(vec2(p.x / w, p.y * 0.85));
	} else {
		r = length(p);
	}
	float a = 1.0 - smoothstep(0.15, 1.0, r);
	ALBEDO = COLOR.rgb;
	ALPHA = a * a * COLOR.a;
}
"""

## Cáscara con borde de fresnel (aditiva): el «borde duro» de la solidez, las cáscaras de los ecos y el destello del rayo.
const CODIGO_CASCARA: String = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform float borde = 3.0;
uniform float base = 0.08;
uniform float brillo = 1.0;
void fragment() {
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), borde);
	ALBEDO = color.rgb * brillo;
	ALPHA = clamp(base + f, 0.0, 1.0) * color.a;
}
"""

## Burbuja del campo: tiñe un poco y DESVÍA lo que hay detrás (lee la pantalla), con el fresnel marcando el borde.
const CODIGO_BURBUJA: String = """
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_back, shadows_disabled;
uniform sampler2D pantalla : hint_screen_texture, filter_linear_mipmap;
uniform vec4 color : source_color = vec4(0.7, 0.8, 1.0, 1.0);
uniform float vida = 1.0;
uniform float distorsion = 1.0;
varying vec3 pos_l;
void vertex() {
	pos_l = VERTEX;
}
void fragment() {
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.5);
	vec2 off = vec2(sin(pos_l.y * 7.0 + TIME * 2.6), cos(pos_l.x * 7.0 + pos_l.z * 5.0 + TIME * 2.1)) * 0.018 * distorsion * (0.5 + f);
	vec3 fondo = textureLod(pantalla, SCREEN_UV + off, 0.0).rgb;
	ALBEDO = mix(fondo, color.rgb, clamp(0.10 + f * 0.65, 0.0, 1.0));
	ALPHA = vida;
}
"""

var _mundo: Node3D
var _hechizos: Array[Node] = []
var _sombreadores: Dictionary = {}


## Engancha un VfxEstado3D al lanzador (cualquier objeto con la señal `hechizo_v2`) y lo cuelga de `mundo`.
static func conectar(lanzador: Object, mundo: Node3D) -> VfxEstado3D:
	var v := VfxEstado3D.new()
	v.name = "VfxEstado3D"
	v._mundo = mundo
	mundo.add_child(v)
	if lanzador != null and lanzador.has_signal("hechizo_v2"):       # sin lanzador (una escena sin magia) no hay nada que escuchar
		lanzador.connect("hechizo_v2", v._en_hechizo)
	if lanzador != null and lanzador.has_signal("vfx_hechizo"):
		lanzador.connect("vfx_hechizo", v._en_vfx)
	if lanzador is Node:                                             # los proyectiles (HechizoVivo con velocidad) cuelgan del lanzador y no emiten hechizo_v2
		(lanzador as Node).child_entered_tree.connect(v._en_nodo_del_lanzador)
	return v


## Compila de antemano los shaders y las mallas de los siete efectos (sólido de tierra y de hielo, líquido, plasma, energía, gas, campo) lanzando uno
## minúsculo de cada, con `solidez` para que también compile la cáscara. Se llama detrás del velo de «Preparando efectos…» de la maqueta: sin esto,
## el primer hechizo de cada estado compila sus shaders EN PLENO JUEGO y da un tirón. No pasa por el Lanzador3D: no hay lógica, solo dibujo.
func precalentar(origen: Vector3) -> void:
	var props: Dictionary = {"solidez": 1.0}
	for par in [["solido", "tierra"], ["solido", "hielo"], ["liquido", "agua"], ["plasma", "fuego"], ["energia", "rayo"], ["gas", "viento"], ["campo", "tiempo"]]:
		var g: Dictionary = {"x": 0.5, "y": 0.5, "z": 0.5, "niveles": 1, "celdas": [], "props": props, "persiste": 0.25, "suelo": origen.y, "t_caida": 0.4}
		_en_hechizo(par[0], par[1], g, origen, Vector3(0.0, 0.0, 1.0), props)


## Hechizos vivos ahora mismo (para la prueba: tras `persiste` + el fundido tiene que ser 0).
func activos() -> int:
	var n: int = 0
	for h in get_children():
		if h is EfectoHechizo and not h.is_queued_for_deletion():
			n += 1
	return n


## Dibujos de proyectil vivos (colgados de su HechizoVivo o apagándose) y ráfagas de `vfx_hechizo` vivas (para la prueba: al acabar todo, 0).
func proyectiles() -> int:
	return _proy_vivos


func rafagas() -> int:
	return _rafagas


## Un nodo entra en el lanzador. Si es un HechizoVivo con `velocidad` > 0 es un PROYECTIL: no emite `hechizo_v2` (esa señal pinta un volumen quieto), así que
## su dibujo cuelga de él y se mueve con él. Se hace en diferido: `child_entered_tree` salta DENTRO de `add_child`, antes de que `_iniciar_proyectil`
## ponga su posición y su velocidad, y el nodo todavía no ha terminado de nacer.
func _en_nodo_del_lanzador(n: Node) -> void:
	if not (n is HechizoVivo):
		return
	var hv: HechizoVivo = n
	if hv.h == null or hv.h.velocidad <= 0.0:
		return
	_dibujar_proyectil.call_deferred(hv)


func _dibujar_proyectil(hv: HechizoVivo) -> void:
	if not is_instance_valid(hv) or not hv.is_inside_tree() or not hv.activo or _proy_vivos >= MAX_PROYECTILES:
		return
	var e := EfectoHechizo.new()
	e.cfg = self
	e.vivo = hv
	e.estado = hv.estado
	e.elemento = hv.elemento
	e.g = {"x": hv.h.semieje_x, "y": hv.h.semieje_y, "z": hv.h.semieje_z, "niveles": 1, "celdas": [], "persiste": 0.0, "eventos": []}
	e.props = {}
	e.origen = hv.global_position
	e.dir = hv.v
	e.pista = [{"t": 0.0, "p": Vector3.ZERO, "d": Vector3(0.0, 0.0, -1.0)}]
	e.todas = e.pista
	_proy_vivos += 1
	hv.add_child(e)
	e.construir()


## `Lanzador3D.vfx_hechizo`: un hechizo pide un efecto por nombre (acción `vfx`, `estela` o `efecto_impacto`). Una ráfaga corta del color del elemento.
func _en_vfx(nombre: String, posicion: Vector3, elemento: String) -> void:
	if nombre == "" or _rafagas >= MAX_RAFAGAS:
		return
	var r := Rafaga.new()
	r.cfg = self
	r.tipo = TIPOS_VFX[tipo_de_vfx(nombre)]
	r.reducida = nombre.to_lower().contains("estela")        # una estela se pide cada 0,5 u: más pequeña y más corta que un impacto con el mismo material
	r.elemento = elemento
	_rafagas += 1
	add_child(r)
	r.position = posicion
	r.construir()


## Qué tipo de ráfaga es un nombre de VFX (ver PALABRAS_VFX). Un nombre que no conocemos sale «generico»: el hechizo se ve, con su color, y el nombre queda
## pedido en el diario para que el Juego y yo fijemos un catálogo.
static func tipo_de_vfx(nombre: String) -> String:
	var m: String = nombre.to_lower()
	for par in PALABRAS_VFX:
		if m.contains(String(par[0])):
			return String(par[1])
	return "generico"


func _en_hechizo(estado: String, elemento: String, g: Dictionary, origen: Vector3, dir: Vector3, props: Dictionary) -> void:
	var carriles: Array = _carriles(g, origen, dir, props)
	# Un sólido con las casillas REALES de la señal se dibuja una sola vez sobre ellas (los bloques quedan donde el Juego pone la colisión); lo demás,
	# un volumen por carril (copia).
	var sobre_celdas: bool = estado == "solido" and not (g.get("celdas", []) as Array).is_empty()
	var n: int = 1 if sobre_celdas else carriles.size()
	for i in n:
		var h := EfectoHechizo.new()
		h.cfg = self
		h.estado = estado
		h.elemento = elemento
		h.g = g
		h.props = props
		h.origen = origen
		h.dir = dir
		h.pista = carriles[i]
		h.todas = carriles
		h.carril = i
		h.sobre_celdas = sobre_celdas
		add_child(h)
		h.construir()


## Los CARRILES del hechizo: una pista por copia, [{t, p: Vector3 (en el suelo), d: Vector3 (horizontal, unitaria)}] por orden de hora. Salen de
## `g["eventos"]` (lo que el Lanzador3D materializa de verdad): las tandas más tempranas son los orígenes de cada copia y cada tanda posterior se une
## al carril cuya última posición le queda más cerca (a la misma hora, a lo sumo una por carril). Las tandas en el mismo sitio y con la misma dirección
## (las fases de `crece`) se funden: no hay nada que mover.
func _carriles(g: Dictionary, origen: Vector3, dir: Vector3, props: Dictionary) -> Array:
	var d0 := Vector2(dir.x, dir.z)
	if d0.length() < 0.001:
		d0 = Vector2(0.0, -1.0)
	d0 = d0.normalized()
	var suelo: float = float(g.get("suelo", origen.y))
	var eventos: Array = (g.get("eventos", []) as Array).duplicate()
	if eventos.is_empty():
		eventos = _eventos_de_props(g, origen, d0, props)
	eventos.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
	var t_min: float = float((eventos[0] as Dictionary)["t"])
	var carriles: Array = []
	for ev in eventos:
		if absf(float((ev as Dictionary)["t"]) - t_min) < 0.001 and carriles.size() < MAX_CARRILES:
			carriles.append([_kf(ev, suelo)])
	for ev in eventos:
		var e: Dictionary = ev
		if absf(float(e["t"]) - t_min) < 0.001:
			continue
		var mejor: int = -1
		var dmin: float = INF
		for i in carriles.size():
			var c: Array = carriles[i]
			var ult: Dictionary = c.back()
			if absf(float(ult["t"]) - float(e["t"])) < 0.001 and c.size() > 1:
				continue                      # este carril ya tiene su tanda a esta hora
			var dd: float = Vector2((ult["p"] as Vector3).x, (ult["p"] as Vector3).z).distance_to(e["pos"] as Vector2)
			if dd < dmin:
				dmin = dd
				mejor = i
		if mejor >= 0:
			(carriles[mejor] as Array).append(_kf(e, suelo))
	# Se funden las tandas que no mueven ni giran el volumen.
	var limpios: Array = []
	for c in carriles:
		var l: Array = []
		for kf in c:
			if l.is_empty() or (kf["p"] as Vector3).distance_to((l.back() as Dictionary)["p"] as Vector3) > 0.05 or (kf["d"] as Vector3).dot((l.back() as Dictionary)["d"] as Vector3) < 0.999:
				l.append(kf)
		limpios.append(l)
	return limpios


func _kf(ev: Dictionary, suelo: float) -> Dictionary:
	var p: Vector2 = ev["pos"]
	var d := Vector3((ev["dir"] as Vector2).x, 0.0, (ev["dir"] as Vector2).y)
	d = d.normalized() if d.length() > 0.001 else Vector3(0.0, 0.0, -1.0)
	return {"t": float(ev["t"]), "p": Vector3(p.x, suelo, p.y), "d": d}


## Sin `eventos` (un lanzador de mentira): la misma regla que Lanzador3D._eventos_v2 sin crecimiento ni rebotes. Copias de lado separadas
## max(2·x, 1) casillas y, si viaja, una tanda por casilla recorrida a VEL_VIAJE casillas/s.
func _eventos_de_props(g: Dictionary, origen: Vector3, d2: Vector2, props: Dictionary) -> Array:
	var copias: int = clampi(int(props.get("copias", 1.0)), 1, MAX_CARRILES)
	var viaja: float = float(props.get("viaja", 0.0))
	var sep: float = maxf(2.0 * float(g.get("x", 0.5)), 1.0) * casilla
	var perp: Vector2 = d2.orthogonal()
	var ev: Array = []
	for i in copias:
		var o: Vector2 = Vector2(origen.x, origen.z) + perp * ((float(i) - float(copias - 1) * 0.5) * sep)
		ev.append({"t": 0.0, "pos": o, "dir": d2})
		for k in range(1, int(floorf(viaja)) + 1):
			ev.append({"t": float(k) / VEL_VIAJE, "pos": o + d2 * casilla * float(k), "dir": d2})
	return ev


func material_suave(mezcla: String, tumbado: bool = false, llama: bool = false) -> ShaderMaterial:
	var clave: String = "%s%s%s" % [mezcla, tumbado, llama]
	if not _sombreadores.has(clave):
		var sh := Shader.new()
		sh.code = CODIGO_SUAVE.replace("%MEZCLA%", mezcla)
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("billboard", 0.0 if tumbado else 1.0)
		m.set_shader_parameter("llama", 1.0 if llama else 0.0)
		_sombreadores[clave] = m
	return _sombreadores[clave]


func material_cascara(color: Color, borde: float = 3.0, base: float = 0.08, brillo: float = 1.0) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = CODIGO_CASCARA
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("borde", borde)
	m.set_shader_parameter("base", base)
	m.set_shader_parameter("brillo", brillo)
	return m


func material_burbuja(color: Color) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = CODIGO_BURBUJA
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("color", color)
	return m


## Malla de caras planas: SurfaceTool desindexa y recalcula normales, así cada triángulo es una faceta (la roca y el cristal se leen «talladas»).
static func facetada(malla: Mesh) -> Mesh:
	var st := SurfaceTool.new()
	st.create_from(malla, 0)
	st.deindex()
	st.generate_normals()
	return st.commit()


## ==========================================================================================================================================
## UN HECHIZO: nodo en el SUELO bajo el centro del volumen, con +Z hacia donde apunta el lanzamiento y +X a su derecha. Todo se dibuja en ese
## espacio local con los semiejes (a_r, a_u, a_f) = (x, y, z) × casilla; el centro del elipsoide está en (0, a_u, 0).
## ==========================================================================================================================================
class EfectoHechizo:
	extends Node3D

	var cfg: VfxEstado3D
	var estado: String
	var elemento: String
	var g: Dictionary
	var props: Dictionary
	var origen: Vector3
	var dir: Vector3

	var luces: int = 0
	var particulas: int = 0
	var t: float = 0.0
	var vida: float = 1.0          ## segundos hasta liberarse (nace + persiste + muere)
	var nace: float = 0.2
	var muere: float = 0.4
	var v: float = 0.0             ## vitalidad 0..1: sube al nacer, 1 mientras vive, baja al morir (todos los efectos la multiplican)
	var col: Dictionary
	var semi: Vector3              ## (a_r, a_u, a_f) en unidades
	var rng := RandomNumberGenerator.new()
	var pista: Array = []          ## el carril de ESTE volumen: [{t, p, d}] (ver VfxEstado3D._carriles)
	var todas: Array = []          ## los carriles de todas las copias (el sólido sobre casillas mira todos)
	var carril: int = 0
	var sobre_celdas: bool = false ## sólido dibujado sobre las casillas reales (mundo fijo, un solo EfectoHechizo)
	var _pers: float = 1.0         ## `persiste` leído de la señal (o del respaldo)
	var _t_pista: float = 0.0      ## hora de la última tanda: lo que tarda en recorrerse el camino
	var _t_crece: float = 1.0
	var _d_act: Vector3 = Vector3(0.0, 0.0, -1.0)
	var _p_ant: Vector3 = Vector3.INF
	var _avance: float = 0.0       ## cuánto se ha desplazado este cuadro (para la estela)
	var _w: Node3D                 ## contenedor en coordenadas de MUNDO (rebotes y huellas no se mueven con el volumen)
	var _huellas: Array = []       ## [{t0, t1, mi}] tandas ya dejadas por el volumen al viajar (siguen vivas `persiste` s)
	var _crece: bool = false
	var _viaja: bool = false
	var _act: Callable
	var _estela: MultiMesh
	var _estela_z: PackedFloat32Array = PackedFloat32Array()
	var _estela_edad: PackedFloat32Array = PackedFloat32Array()
	var _estela_sig: float = 0.0
	var _estela_i: int = 0
	var _rebotes: Array = []       ## [{t, punto, sp: MultiMesh, aro: MeshInstance3D, dirs}]
	var _escudo: MeshInstance3D
	var vivo: HechizoVivo = null   ## proyectil: el nodo del que cuelga este dibujo (null = un volumen normal de `hechizo_v2`)
	var proyectil: bool = false
	var _fin: bool = false         ## el proyectil ya acabó: el dibujo se soltó del nodo y se apaga
	var _t_fin: float = 0.0
	var _con_luz: bool = false
	var _cuerpo: MeshInstance3D    ## sólido y líquido de proyectil: una bola, no bloques que caen ni una masa de agua

	## ---------------------------------------------------------------- construcción común
	func construir() -> void:
		proyectil = vivo != null
		rng.seed = hash("%s%s%s" % [estado, elemento, str(g.get("x", 0))]) + int(Time.get_ticks_usec() % 100000)
		col = COLORES.get(elemento, COLOR_RESERVA)
		var c: float = cfg.casilla
		# Un volumen quieto no baja de 0,25 casilla para verse; un proyectil, de 0,1: su dibujo tiene que casar con el radio con el que golpea (`_radio_u`).
		var piso: float = 0.1 if proyectil else 0.25
		semi = Vector3(maxf(float(g.get("x", 0.5)), piso) * c, maxf(float(g.get("y", 0.5)), piso) * c, maxf(float(g.get("z", 0.5)), piso) * c)
		_d_act = (pista[0] as Dictionary)["d"]
		_t_pista = float((pista.back() as Dictionary)["t"])
		_crece = float(props.get("crece", 0.0)) > 0.0
		_t_crece = clampf((1.0 - ESCALA_NACE) / maxf(float(props.get("crece", 0.0)), 0.01), 0.15, 2.5)
		_viaja = pista.size() > 1 and ((pista[0] as Dictionary)["p"] as Vector3).distance_to((pista.back() as Dictionary)["p"] as Vector3) > 0.5
		# `persiste` viene en la señal (ya multiplicado por la calidad del trazo). Solo un lanzador sin él cae a la tabla.
		var per: Dictionary = PERSISTE.get(estado, {"_": 2.0})
		_pers = float(per.get(elemento, per.get("_", 2.0)))
		if g.has("persiste"):
			_pers = float(g["persiste"])
		if estado != "energia":
			_pers = maxf(_pers, 0.25)
		nace = 0.2
		muere = 0.6 if estado == "solido" else 0.4
		vida = _t_pista + nace + _pers + muere
		if proyectil:
			nace = 0.12
			muere = 0.35
			vida = 1.0e9                # vive mientras el proyectil esté activo; al soltarse se apaga en `muere`
		match ("plano" if VfxEstado3D.plano else estado):
			"plano":
				_ini_plano()
			"solido" when proyectil:
				_ini_cuerpo()
			"liquido" when proyectil:
				_ini_cuerpo()
			"solido":
				if sobre_celdas:
					_ini_solido_celdas()
				else:
					_ini_solido()
			"liquido":
				_ini_liquido()
				vida = _t_pista + _t_caida + 1.3
			"plasma":
				_ini_plasma()
			"energia":
				_ini_energia()
				nace = 0.03
				muere = 0.15
				vida = _t_pista + 0.2 + nace + muere
			"gas":
				_ini_gas()
			_:
				_ini_campo()
		if not proyectil:
			_ini_firmas()           # copias, viaje, rebotes y borde duro son de un volumen quieto; el proyectil ya se mueve con su nodo
		_aplicar_transform()

	## La pista a la hora `tt`: [posición en el suelo, dirección]. Entre dos tandas el volumen se desliza en línea recta; la dirección es la del tramo
	## al que llega (al rebotar cambia en el tramo que sigue al choque).
	func _muestra(tt: float) -> Array:
		var n: int = pista.size()
		if n == 1 or tt <= float((pista[0] as Dictionary)["t"]):
			return [(pista[0] as Dictionary)["p"], (pista[0] as Dictionary)["d"]]
		for i in range(n - 1):
			var a: Dictionary = pista[i]
			var b: Dictionary = pista[i + 1]
			if tt < float(b["t"]):
				var k: float = (tt - float(a["t"])) / maxf(float(b["t"]) - float(a["t"]), 0.0001)
				return [(a["p"] as Vector3).lerp(b["p"] as Vector3, k), b["d"]]
		return [(pista[n - 1] as Dictionary)["p"], (pista[n - 1] as Dictionary)["d"]]

	## Cuánto se adelanta el centro del volumen sobre la mano, en casillas. Lo decide el Lanzador3D (GeometriaV2.adelanto, entrada 165): con barrera
	## (`props` trae `solidez`) es 0 —el volumen rodea al jugador y está centrado en él— y sin ella, z − radio base. `e` es lo que ha crecido en planta.
	func _adelanto(e: float = 1.0) -> float:
		return Lanzador3D.GeometriaV2.adelanto({"z": float(g.get("z", 0.5)) * e, "props": props})

	## Proyectil: el dibujo es hijo del HechizoVivo, así que sólo gira hacia donde va (la dirección horizontal de su velocidad) y baja medio volumen
	## para que el centro del elipsoide caiga en el origen del nodo (= la posición del proyectil).
	func _transform_proyectil(dt: float) -> void:
		if _fin:
			return                      # soltado: se queda donde acabó
		var d_obj := Vector3(vivo.v.x, 0.0, vivo.v.z)
		if d_obj.length() > 0.05:
			d_obj = d_obj.normalized()
			var mezcla: Vector3 = _d_act.lerp(d_obj, clampf(dt * 25.0, 0.0, 1.0))
			_d_act = mezcla.normalized() if mezcla.length() > 0.05 else d_obj
		var der: Vector3 = Vector3.UP.cross(_d_act).normalized() * -1.0
		transform = Transform3D(Basis(der, Vector3.UP, _d_act), Vector3(0.0, -semi.y, 0.0))

	func _aplicar_transform(dt: float = 1.0) -> void:
		if proyectil:
			_transform_proyectil(dt)
			return
		if sobre_celdas:
			transform = Transform3D.IDENTITY          # los bloques ya llevan sus coordenadas de mundo
			return
		var m: Array = _muestra(t)
		var p: Vector3 = m[0]
		var d_obj: Vector3 = m[1]
		if dt >= 1.0:
			_d_act = d_obj
		else:
			var mezcla: Vector3 = _d_act.lerp(d_obj, clampf(dt * 25.0, 0.0, 1.0))
			_d_act = mezcla.normalized() if mezcla.length() > 0.05 else d_obj
		_avance = 0.0 if _p_ant == Vector3.INF else p.distance_to(_p_ant)
		_p_ant = p
		# Crece: solo en planta (X y Z). El centro se adelanta `_adelanto(e)` casillas: la cara de atrás se queda en la mano (o, con barrera, el volumen sigue centrado en el jugador).
		var e: float = 1.0
		if _crece:
			e = lerpf(ESCALA_NACE, 1.0, clampf(t / _t_crece, 0.0, 1.0))
		var der: Vector3 = Vector3.UP.cross(_d_act).normalized() * -1.0
		var base := Basis(der, Vector3.UP, _d_act)
		var centro: Vector3 = p + _d_act * _adelanto(e) * cfg.casilla
		transform = Transform3D(base * Basis.from_scale(Vector3(e, 1.0, e)), centro)

	func _luz(color: Color, energia: float, rango: float, pos: Vector3 = Vector3(INF, 0.0, 0.0)) -> OmniLight3D:
		if carril > 0:
			return null                # solo el primer volumen lleva luz: cuatro copias no son cuatro luces
		if proyectil:
			if cfg._proy_con_luz >= MAX_LUCES:
				return null            # ocho proyectiles no son ocho luces: las dos primeras
			cfg._proy_con_luz += 1
			_con_luz = true
		var l := OmniLight3D.new()
		l.light_color = color
		l.light_energy = energia
		l.omni_range = rango
		l.shadow_enabled = false
		l.position = Vector3(0.0, semi.y, 0.0) if pos.x == INF else pos
		add_child(l)
		luces += 1
		return l

	func _mm(malla: Mesh, n: int, mat: Material, colores: bool = true, padre: Node = null) -> MultiMesh:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = colores
		mm.instance_count = n
		mm.mesh = malla
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 64.0
		(padre if padre != null else self).add_child(mi)
		particulas += n
		var oculto := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
		for i in n:
			mm.set_instance_transform(i, oculto)
			mm.set_instance_color(i, Color(1, 1, 1, 0))
		return mm

	func _elipsoide(mat: Material, escala: Vector3 = Vector3.ONE) -> MeshInstance3D:
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 28
		sm.rings = 14
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(0.0, semi.y, 0.0)
		mi.scale = semi * escala
		add_child(mi)
		return mi

	func _quad() -> QuadMesh:
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		return q

	func _punto_interior() -> Vector3:
		var u := Vector3(rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0)).normalized()
		var r: float = pow(rng.randf(), 1.0 / 3.0)
		return Vector3(0.0, semi.y, 0.0) + u * r * semi

	func _oculto() -> Transform3D:
		return Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)

	func _media() -> float:
		return (semi.x + semi.y + semi.z) / 3.0

	## ---------------------------------------------------------------- bucle
	func _process(delta: float) -> void:
		if proyectil:
			_proceso_proyectil(delta)
			return
		t += delta
		if t >= vida:
			queue_free()
			return
		var entra: float = smoothstep(0.0, 1.0, clampf(t / nace, 0.0, 1.0))
		var sale: float = 1.0 - smoothstep(0.0, 1.0, clampf((t - (vida - muere)) / muere, 0.0, 1.0))
		v = entra * sale
		_aplicar_transform(delta)
		if _act.is_valid():
			_act.call(delta)
		_act_firmas(delta)

	## Proyectil: vive mientras el HechizoVivo esté activo. Al acabar (golpe, alcance, tiempo…) se suelta de él —el nodo se libera— y se apaga en `muere`.
	func _proceso_proyectil(delta: float) -> void:
		t += delta
		if not _fin and (not is_instance_valid(vivo) or not vivo.activo or vivo.is_queued_for_deletion()):
			_soltar()
		var sale: float = 1.0
		if _fin:
			_t_fin += delta
			if _t_fin >= muere:
				queue_free()
				return
			sale = 1.0 - smoothstep(0.0, 1.0, _t_fin / muere)
		v = smoothstep(0.0, 1.0, clampf(t / nace, 0.0, 1.0)) * sale
		_aplicar_transform(delta)
		if _act.is_valid():
			_act.call(delta)

	func _soltar() -> void:
		_fin = true
		_t_fin = 0.0
		if is_inside_tree() and is_instance_valid(cfg) and cfg.is_inside_tree():
			reparent(cfg)               # conserva la transformación global: se queda donde acabó el proyectil

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE and proyectil and is_instance_valid(cfg):
			cfg._proy_vivos -= 1
			if _con_luz:
				cfg._proy_con_luz -= 1

	## ================================================================ CUERPO DE PROYECTIL (sólido y líquido)
	func _ini_cuerpo() -> void:
		if estado == "solido":
			var sm := SphereMesh.new()
			sm.radius = 1.0
			sm.height = 2.0
			sm.radial_segments = 8
			sm.rings = 4
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(col["hondo"]).lerp(Color(col["c"]), 0.5)
			mat.roughness = 0.9
			_cuerpo = MeshInstance3D.new()
			_cuerpo.mesh = VfxEstado3D.facetada(sm)
			_cuerpo.material_override = mat
			_cuerpo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_cuerpo.position = Vector3(0.0, semi.y, 0.0)
			add_child(_cuerpo)
		else:
			_cuerpo = _elipsoide(cfg.material_burbuja(Color(col["c"])))
		_act = _act_cuerpo

	func _act_cuerpo(dt: float) -> void:
		var k: float = lerpf(0.5, 1.0, v)
		if estado == "solido":
			_cuerpo.scale = Vector3.ONE * _media() * k
			_cuerpo.rotate(Vector3(0.3, 1.0, 0.2).normalized(), dt * 5.0)
		else:
			_cuerpo.scale = semi * k
			(_cuerpo.material_override as ShaderMaterial).set_shader_parameter("vida", v)

	## ================================================================ SÓLIDO
	var _bloques: Array = []       ## [{pos, rot, esc, retraso, nivel}]
	var _mm_bloques: MultiMesh
	var _mm_polvo: MultiMesh
	var _polvo: Array = []
	var _luz_hielo: OmniLight3D

	func _ini_solido() -> void:
		var c: float = cfg.casilla
		var nx: int = maxi(1, roundi(2.0 * float(g.get("x", 0.5))))
		var nz: int = maxi(1, roundi(2.0 * float(g.get("z", 0.5))))
		var ny: int = maxi(1, int(g.get("niveles", maxi(1, roundi(2.0 * float(g.get("y", 0.5)))))))
		var celdas: Array = []
		for j in ny:
			for i in nx:
				for k in nz:
					var lx: float = (float(i) + 0.5 - float(nx) * 0.5) * c
					var lz: float = (float(k) + 0.5 - float(nz) * 0.5) * c
					var ly: float = (float(j) + 0.5) * c * (2.0 * semi.y / (float(ny) * c))
					var q := Vector3(lx / semi.x, (ly - semi.y) / semi.y, lz / semi.z)
					if q.length_squared() <= 1.25 or celdas.is_empty() and i == nx / 2 and k == nz / 2:
						celdas.append(Vector3(lx, ly, lz))
		celdas.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)
		if celdas.size() > MAX_BLOQUES:
			celdas.resize(MAX_BLOQUES)
		_preparar_solido(celdas, [], Vector3(INF, 0.0, 0.0))

	## Lo común a los dos sólidos (el local, sin casillas, y el de mundo, sobre las casillas reales): mallas, material, bloques, polvo y luz.
	## `celdas` = centro de cada bloque; `datos[n]` (opcional) pisa el tamaño, la hora de salida/hundimiento y el ancla del bloque n.
	func _preparar_solido(celdas: Array, datos: Array, luz_pos: Vector3) -> void:
		var c: float = cfg.casilla
		var hielo: bool = elemento == "hielo"
		var malla: Mesh
		if hielo:
			var cil := CylinderMesh.new()
			cil.top_radius = 0.05
			cil.bottom_radius = 0.5
			cil.height = 1.0
			cil.radial_segments = 6
			cil.rings = 1
			malla = VfxEstado3D.facetada(cil)
		else:
			var es := SphereMesh.new()
			es.radius = 0.5
			es.height = 1.0
			es.radial_segments = 6
			es.rings = 3
			malla = VfxEstado3D.facetada(es)
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.15 if hielo else 0.9
		mat.metallic_specular = 0.8 if hielo else 0.2
		if hielo:
			mat.emission_enabled = true
			mat.emission = Color(col["hondo"]) * 0.5
			mat.emission_energy_multiplier = 0.8
		elif elemento != "tierra":
			mat.emission_enabled = true
			mat.emission = Color(col["c"]) * 0.6
		_mm_bloques = _mm(malla, celdas.size(), mat)
		var lado_max: float = c
		for n in celdas.size():
			var p: Vector3 = celdas[n]
			var o: Dictionary = datos[n] if n < datos.size() else {}
			var h: float = lado_max * (rng.randf_range(1.0, 1.35) if hielo else rng.randf_range(0.85, 1.05))
			var ancho: float = lado_max * (rng.randf_range(1.1, 1.3) if hielo else rng.randf_range(1.2, 1.5))
			h = float(o.get("alto", h))
			ancho = float(o.get("ancho", ancho))
			var b := Basis.from_euler(Vector3(rng.randf_range(-0.12, 0.12) if hielo else rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU), rng.randf_range(-0.12, 0.12) if hielo else rng.randf_range(0.0, TAU)))
			var retraso: float = ((p.z + semi.z) / maxf(2.0 * semi.z, 0.01)) * 0.3 + rng.randf() * 0.1 + p.y / c * 0.04
			var salida: float = (1.0 - p.y / maxf(2.0 * semi.y, 0.01)) * 0.25 + rng.randf() * 0.1
			_bloques.append({"pos": p, "rot": b, "esc": Vector3(ancho, h, ancho), "retraso": float(o.get("retraso", retraso)), "salida": float(o.get("salida", salida)),
				"fin": float(o.get("fin", vida - muere)), "base": bool(o.get("base", false)), "y0": float(o.get("y0", 0.1))})
			var tono: Color
			if hielo:
				tono = Color(col["mota"]).lerp(Color(col["hondo"]), rng.randf())
				tono.a = 0.92
			elif elemento == "tierra":
				tono = [Color("835832"), Color("B8ADB8"), Color("7D747C"), Color("DB8F59")][rng.randi() % 4]
			else:
				tono = Color(col["c"]).lerp(Color(col["hondo"]), rng.randf() * 0.5)
			_mm_bloques.set_instance_color(n, tono)
		# Polvo (tierra) o escarcha (hielo): salen del pie de cada bloque cuando emerge.
		var np: int = mini(70, 20 + celdas.size() * 2)
		var pm: Mesh
		var matp: Material
		if elemento == "tierra" or not hielo:
			var bx := BoxMesh.new()
			bx.size = Vector3(0.14, 0.14, 0.14)
			pm = bx
			var mp := StandardMaterial3D.new()
			mp.vertex_color_use_as_albedo = true
			mp.roughness = 1.0
			matp = mp
		else:
			pm = _quad()
			matp = cfg.material_suave("blend_add")
		_mm_polvo = _mm(pm, np, matp)
		for n in np:
			var b: Dictionary = _bloques[rng.randi() % _bloques.size()]
			var p: Vector3 = b["pos"]
			_polvo.append({"base": Vector3(p.x, float(b["y0"]), p.z), "vel": Vector3(rng.randf_range(-1.8, 1.8), rng.randf_range(1.0, 3.2), rng.randf_range(-1.8, 1.8)), "t0": float(b["retraso"]) + 0.05, "giro": rng.randf() * TAU})
		if hielo:
			_luz_hielo = _luz(Color(col["c"]), 0.9, semi.length() * 1.4 + 2.0, luz_pos)
		_act = _act_solido

	## SÓLIDO SOBRE LAS CASILLAS REALES: la señal trae `celdas` (las que el Lanzador3D materializa, en coordenadas de casilla del mundo) y `niveles`. Los
	## bloques de roca (o el cristal de hielo) se ponen EXACTAMENTE en ellas, apilados `niveles` veces sobre la altura del suelo de cada casilla, de modo que
	## la roca dibujada y la colisión del Juego coinciden aunque el hechizo mire en diagonal. Cada casilla sale a la hora de la tanda más cercana
	## (`eventos`) y se hunde `persiste` s después de salir, como el bloque de verdad. Tierra: hasta `niveles` bloques por casilla, repartidos si no
	## caben en MAX_BLOQUES. Hielo: un cristal por casilla, tan alto como la columna.
	func _ini_solido_celdas() -> void:
		var c: float = cfg.casilla
		var hielo: bool = elemento == "hielo"
		var niv: int = maxi(1, int(g.get("niveles", 1)))
		var mapa: Array = (g["celdas"] as Array).duplicate()
		var o2 := Vector2(origen.x, origen.z)
		mapa.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return Vector2((float(a.x) + 0.5) * c, (float(a.y) + 0.5) * c).distance_to(o2) < Vector2((float(b.x) + 0.5) * c, (float(b.y) + 0.5) * c).distance_to(o2))
		var tandas: Array = []
		for ca in todas:
			tandas.append_array(ca)
		var por_celda: int = 1 if hielo else clampi(MAX_BLOQUES / maxi(mapa.size(), 1), 1, niv)
		var grupo: float = float(niv) / float(por_celda)          # niveles que cubre cada bloque
		var alto_n: float = cfg.alto_nivel
		var suelo_g: float = float(g.get("suelo", origen.y))
		var extension: float = maxf(maxf(semi.x, semi.z), c)
		var pos: Array = []
		var datos: Array = []
		var suma := Vector3.ZERO
		for cc in mapa:
			var cel: Vector2i = cc
			if pos.size() >= MAX_BLOQUES:
				break
			var cx: float = (float(cel.x) + 0.5) * c
			var cz: float = (float(cel.y) + 0.5) * c
			var y_b: float = float(cfg.y_pies.call(cel)) if cfg.y_pies.is_valid() else suelo_g
			# la tanda más cercana a esta casilla (y a qué distancia cae de su centro, para el orden de salida dentro de ella)
			var t_ev: float = 0.0
			var d_ev: float = INF
			for kf in tandas:
				var dd: float = Vector2((kf["p"] as Vector3).x, (kf["p"] as Vector3).z).distance_to(Vector2(cx, cz))
				if dd < d_ev - 0.01 or (absf(dd - d_ev) <= 0.01 and float(kf["t"]) < t_ev):
					d_ev = dd
					t_ev = float(kf["t"])
			var salida_ola: float = clampf(d_ev / extension, 0.0, 1.0) * (_t_crece if _crece else 0.25)
			for j in por_celda:
				var base_t: float = t_ev + salida_ola + rng.randf() * 0.1 + float(j) * 0.04
				var fin: float = t_ev + _pers
				var d: Dictionary
				var centro: Vector3
				if hielo:
					centro = Vector3(cx, y_b, cz)
					d = {"alto": (float(niv) * alto_n + c * 0.6) * rng.randf_range(1.0, 1.3), "ancho": c * rng.randf_range(0.8, 1.0), "base": true}
				else:
					centro = Vector3(cx, y_b + (float(j) + 0.5) * grupo * alto_n, cz)
					d = {"alto": grupo * alto_n * rng.randf_range(1.1, 1.5), "ancho": c * rng.randf_range(1.0, 1.25)}
				d["retraso"] = base_t
				d["fin"] = fin
				d["salida"] = (1.0 - float(j) / float(maxi(por_celda, 1))) * 0.25 + rng.randf() * 0.1
				d["y0"] = y_b + 0.1
				pos.append(centro)
				datos.append(d)
				suma += centro
		var centroide: Vector3 = suma / float(maxi(pos.size(), 1))
		_preparar_solido(pos, datos, Vector3(centroide.x, centroide.y + semi.y, centroide.z))

	func _act_solido(_dt: float) -> void:
		var c: float = cfg.casilla
		var hielo: bool = elemento == "hielo"
		for n in _bloques.size():
			var b: Dictionary = _bloques[n]
			var p: Vector3 = b["pos"]
			var subida: float = clampf((t - float(b["retraso"])) / 0.35, 0.0, 1.0)
			var ease_out: float = 1.0 - pow(1.0 - subida, 3.0) * (1.0 + 0.5 * (1.0 - subida))   # pasa un pelo de largo y vuelve (rebote seco)
			var hundir: float = clampf((t - float(b["fin"]) - float(b["salida"]) * muere) / (muere * 0.7), 0.0, 1.0)
			var y_off: float = -(1.0 - ease_out) * c * 1.3 - hundir * c * 1.4
			var esc: Vector3 = b["esc"]
			var centro_y: float = p.y + (esc.y * 0.5 if bool(b["base"]) else (esc.y * 0.5 - c * 0.5 if hielo else 0.0))
			var xf := Transform3D((b["rot"] as Basis).scaled(esc), Vector3(p.x, centro_y + y_off, p.z))
			_mm_bloques.set_instance_transform(n, xf)
		for n in _polvo.size():
			var pl: Dictionary = _polvo[n]
			var e: float = t - float(pl["t0"])
			if e < 0.0 or e > 0.9:
				_mm_polvo.set_instance_transform(n, _oculto())
				continue
			var vel: Vector3 = pl["vel"]
			var pos: Vector3 = (pl["base"] as Vector3) + vel * e + Vector3(0.0, -4.5 * e * e if not hielo else -0.6 * e * e, 0.0)
			var k: float = 1.0 - e / 0.9
			var s: float = 1.0 if not hielo else 0.35 * (0.5 + 0.5 * k)
			_mm_polvo.set_instance_transform(n, Transform3D(Basis.from_euler(Vector3(e * 3.0, float(pl["giro"]), 0.0)).scaled(Vector3(s, s, s)), pos))
			var cc: Color = Color(col["mota"]) if hielo else Color(col["hondo"]).lerp(Color(col["mota"]), 0.4)
			cc.a = k * (0.9 if hielo else 1.0)
			_mm_polvo.set_instance_color(n, cc)
		if _luz_hielo:
			_luz_hielo.light_energy = 0.9 * v

	## ================================================================ LÍQUIDO
	var _t_caida: float = 0.5
	var _masa: MeshInstance3D
	var _aro: MeshInstance3D
	var _mm_gotas: MultiMesh
	var _gotas: Array = []

	func _ini_liquido() -> void:
		# El Lanzador3D manda cuándo entra el agua (`t_caida` = 0,4 + 0,07·semieje Y en casillas, máx. 0,8 s). Sin él, la misma cuenta.
		_t_caida = float(g["t_caida"]) if float(g.get("t_caida", 0.0)) > 0.0 else clampf(0.4 + 0.07 * float(g.get("y", 0.5)), 0.4, 0.8)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(Color(col["c"]), 0.68)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.08
		mat.metallic_specular = 1.0
		mat.emission_enabled = true
		mat.emission = Color(col["c"]) * 0.25
		_masa = _elipsoide(mat, Vector3(0.85, 0.85, 0.85))
		var tor := TorusMesh.new()
		tor.inner_radius = 0.92
		tor.outer_radius = 1.0
		tor.rings = 32
		tor.ring_segments = 6
		_aro = MeshInstance3D.new()
		_aro.mesh = tor
		_aro.material_override = cfg.material_cascara(Color(col["mota"]), 1.0, 0.9, 1.2)
		_aro.position = Vector3(0.0, 0.08, 0.0)
		_aro.visible = false
		add_child(_aro)
		var es := SphereMesh.new()
		es.radius = 0.5
		es.height = 1.0
		es.radial_segments = 6
		es.rings = 3
		var mg := StandardMaterial3D.new()
		mg.vertex_color_use_as_albedo = true
		mg.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mg.roughness = 0.1
		mg.emission_enabled = true
		mg.emission = Color(col["c"]) * 0.3
		_mm_gotas = _mm(es, 130, mg)
		for n in 130:
			var ang: float = rng.randf() * TAU
			var rad: float = sqrt(rng.randf())
			var sp: float = rng.randf_range(1.6, 4.5) * (0.6 + 0.12 * _media())
			_gotas.append({"p0": Vector3(cos(ang) * rad * semi.x * 0.9, 0.3, sin(ang) * rad * semi.z * 0.9), "vel": Vector3(cos(ang) * sp * rng.randf_range(0.2, 1.0), rng.randf_range(2.5, 6.0), sin(ang) * sp * rng.randf_range(0.2, 1.0)), "tam": rng.randf_range(0.10, 0.26) * (0.8 + 0.08 * _media())})
		_act = _act_liquido

	func _act_liquido(_dt: float) -> void:
		var inicio: float = _t_caida
		var alto: float = 2.0 * semi.y + 1.6 * cfg.casilla
		if t < inicio:
			var p: float = t / inicio
			var y: float = lerpf(alto, semi.y, p * p)
			var est: float = 1.0 + 0.5 * p
			_masa.position = Vector3(0.0, y, 0.0)
			_masa.scale = semi * 0.85 * Vector3(1.0 / sqrt(est), est, 1.0 / sqrt(est))
		else:
			var e: float = t - inicio
			var aplasta: float = clampf(e / 0.12, 0.0, 1.0)
			var desvanece: float = clampf((e - 0.1) / 0.35, 0.0, 1.0)
			var sy: float = lerpf(0.85, 0.12, aplasta) * (1.0 - desvanece)
			var sxz: float = lerpf(0.85, 1.2, aplasta) * (1.0 - desvanece * 0.5)
			_masa.position = Vector3(0.0, semi.y * lerpf(1.0, 0.12, aplasta), 0.0)
			_masa.scale = Vector3(semi.x * sxz, maxf(semi.y * sy, 0.001), semi.z * sxz)
			_masa.visible = desvanece < 1.0
			_aro.visible = e < 0.6
			if _aro.visible:
				var r: float = lerpf(0.5, 1.35, clampf(e / 0.5, 0.0, 1.0))
				_aro.scale = Vector3(semi.x * r, 1.0, semi.z * r)
				(_aro.material_override as ShaderMaterial).set_shader_parameter("color", Color(Color(col["mota"]), 1.0 - e / 0.6))
			for n in _gotas.size():
				var gt: Dictionary = _gotas[n]
				var ee: float = e - 0.05
				var pos: Vector3 = (gt["p0"] as Vector3) + (gt["vel"] as Vector3) * ee + Vector3(0.0, -12.0 * 0.5 * ee * ee, 0.0)
				if ee < 0.0 or pos.y < 0.0:
					_mm_gotas.set_instance_transform(n, _oculto())
					continue
				var s: float = float(gt["tam"])
				_mm_gotas.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3(s, s * 1.3, s)), pos))
				_mm_gotas.set_instance_color(n, Color(col["mota"]).lerp(Color(col["c"]), 0.5))

	## ================================================================ PLASMA
	var _mm_llamas: MultiMesh
	var _mm_brasas: MultiMesh
	var _llamas: Array = []
	var _brasas: Array = []
	var _luz_fuego: OmniLight3D
	var _charco: MultiMesh
	var _contorno: MeshInstance3D       # cáscara tenue con el contorno exacto del volumen (plasma y gas)

	func _ini_plasma() -> void:
		var nl: int = int(220 * DENSIDAD)
		_mm_llamas = _mm(_quad(), nl, cfg.material_suave("blend_add", false, true))
		for n in nl:
			_llamas.append({"edad": rng.randf(), "vida": rng.randf_range(0.5, 1.1), "pos": _punto_llama(), "sube": rng.randf_range(0.8, 1.8)})
		var nb: int = int(60 * DENSIDAD)
		_mm_brasas = _mm(_quad(), nb, cfg.material_suave("blend_add"))
		for n in nb:
			_brasas.append({"edad": rng.randf(), "vida": rng.randf_range(0.8, 1.6), "pos": _punto_llama(), "vel": Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(1.5, 3.0), rng.randf_range(-0.5, 0.5))})
		_luz_fuego = _luz(Color(col["c"]), 1.6, semi.length() * 1.6 + 2.0)
		_contorno = _elipsoide(cfg.material_burbuja(Color(col["c"]).lerp(Color(col["mota"]), 0.4)))   # silueta tenue: la llama sola no dice dónde acaba el volumen
		# Charco de luz en el suelo: un sprite tumbado (1 instancia de MultiMesh para poder darle color y latido).
		if not proyectil:                                   # un proyectil va por el aire: no deja charco de luz en el suelo
			_charco = _mm(_quad(), 1, cfg.material_suave("blend_add", true))
		_act = _act_plasma

	func _punto_llama() -> Vector3:
		var p: Vector3 = _punto_interior()
		p.y = semi.y + (p.y - semi.y) * 0.9 - semi.y * 0.3   # sesgado hacia abajo: las llamas nacen abajo y suben
		p.y = maxf(p.y, 0.1)
		return p

	func _act_plasma(dt: float) -> void:
		var m: float = _media()
		var tam: float = 0.4 + 0.2 * m
		for n in _llamas.size():
			var f: Dictionary = _llamas[n]
			f["edad"] = float(f["edad"]) + dt / float(f["vida"])
			if float(f["edad"]) >= 1.0:
				f["edad"] = 0.0
				f["pos"] = _punto_llama()
			var e: float = f["edad"]
			var pos: Vector3 = (f["pos"] as Vector3) + Vector3(0.0, e * float(f["sube"]) * (0.7 + 0.25 * semi.y), 0.0)
			var k: float = sin(e * PI) * v
			var s: float = tam * k
			if s < 0.01:
				_mm_llamas.set_instance_transform(n, _oculto())
				continue
			_mm_llamas.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3(s * 0.8, s * 1.5, 1.0)), pos))
			var cc: Color = Color(col["mota"]).lerp(Color(col["c"]), clampf(e * 1.6, 0.0, 1.0)).lerp(Color(col["hondo"]), clampf((e - 0.55) * 2.0, 0.0, 1.0))
			cc.a = 0.55 * (1.0 - e * 0.6)
			_mm_llamas.set_instance_color(n, cc)
		for n in _brasas.size():
			var b: Dictionary = _brasas[n]
			b["edad"] = float(b["edad"]) + dt / float(b["vida"])
			if float(b["edad"]) >= 1.0:
				b["edad"] = 0.0
				b["pos"] = _punto_llama()
			var e: float = b["edad"]
			var pos: Vector3 = (b["pos"] as Vector3) + (b["vel"] as Vector3) * e * (0.6 + 0.2 * semi.y)
			var s: float = 0.09 * (1.0 - e) * v
			if s < 0.005:
				_mm_brasas.set_instance_transform(n, _oculto())
				continue
			_mm_brasas.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3(s, s, 1.0)), pos))
			_mm_brasas.set_instance_color(n, Color(col["mota"], 1.0))
		if _contorno:
			_contorno.scale = semi * (0.7 + 0.3 * v)
			(_contorno.material_override as ShaderMaterial).set_shader_parameter("vida", v * 0.6)
		if _luz_fuego:
			_luz_fuego.light_energy = (1.6 + 0.4 * sin(t * 23.0) + 0.3 * sin(t * 9.0)) * v
		if _charco == null:
			return
		var latido: float = 0.55 + 0.45 * (0.5 + 0.5 * sin(t * TAU * 4.0))   # el pulso del juego: cada 0,25 s
		var lado: float = 2.4 * (0.95 + 0.05 * latido) * (0.2 + 0.8 * v)
		_charco.set_instance_transform(0, Transform3D(Basis.from_euler(Vector3(-PI * 0.5, 0.0, 0.0)) * Basis.from_scale(Vector3(semi.x * lado, semi.z * lado, 1.0)), Vector3(0.0, 0.05, 0.0)))
		_charco.set_instance_color(0, Color(Color(col["c"]), (0.35 + 0.25 * latido) * v))

	## ================================================================ ENERGÍA
	var _mm_nucleo: MultiMesh
	var _mm_halo: MultiMesh
	var _mm_chispas: MultiMesh
	var _chispas: Array = []
	var _destello: MeshInstance3D
	var _luz_rayo: OmniLight3D
	var _prox_arco: float = 0.0
	const ARCOS: int = 9
	const TRAMOS: int = 7

	func _ini_energia() -> void:
		var cubo := BoxMesh.new()
		cubo.size = Vector3.ONE
		var mn := StandardMaterial3D.new()
		mn.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mn.vertex_color_use_as_albedo = true
		mn.albedo_color = Color(1, 1, 1)
		var mh := StandardMaterial3D.new()
		mh.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mh.vertex_color_use_as_albedo = true
		mh.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mh.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_mm_nucleo = _mm(cubo, ARCOS * TRAMOS, mn)
		_mm_halo = _mm(cubo, ARCOS * TRAMOS, mh)
		_mm_chispas = _mm(_quad(), 30, cfg.material_suave("blend_add"))
		for n in 30:
			var u := Vector3(rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0)).normalized()
			_chispas.append({"p0": Vector3(0.0, semi.y, 0.0) + u * semi * rng.randf_range(0.2, 0.9), "vel": u * rng.randf_range(2.0, 6.0), "tam": rng.randf_range(0.10, 0.22)})
		_destello = _elipsoide(cfg.material_cascara(Color(col["c"]), 2.0, 0.12, 1.0), Vector3(1.05, 1.05, 1.05))
		_luz_rayo = _luz(Color(col["mota"]).lerp(Color(col["c"]), 0.4), 3.0, semi.length() * 1.8 + 3.0)
		_act = _act_energia

	func _act_energia(_dt: float) -> void:
		if t >= _prox_arco:
			_prox_arco = t + 0.07
			_sortear_arcos()
		var f: float = clampf(1.0 - t / vida, 0.0, 1.0)
		if _luz_rayo:
			_luz_rayo.light_energy = 3.0 * f * (0.6 + 0.4 * sin(t * 90.0))
		var dest: float = clampf(1.0 - t / 0.18, 0.0, 1.0)
		_destello.visible = dest > 0.0
		_destello.scale = semi * (1.05 + 0.25 * (1.0 - dest))
		(_destello.material_override as ShaderMaterial).set_shader_parameter("color", Color(col["mota"], dest))
		for n in _chispas.size():
			var s: Dictionary = _chispas[n]
			var e: float = t
			var k: float = 1.0 - clampf(e / (vida * 0.9), 0.0, 1.0)
			var pos: Vector3 = (s["p0"] as Vector3) + (s["vel"] as Vector3) * e
			var tam: float = float(s["tam"]) * k
			_mm_chispas.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3(tam, tam, 1.0)), pos))
			_mm_chispas.set_instance_color(n, Color(col["mota"], k))

	func _sortear_arcos() -> void:
		for a in ARCOS:
			var u1 := Vector3(rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0)).normalized()
			var u2 := Vector3(rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0)).normalized()
			var c0 := Vector3(0.0, semi.y, 0.0)
			var largo: bool = a >= ARCOS - 3
			# Los arcos cruzan el volumen de lado a lado (no se arremolinan en el centro): así el rayo «llena» el elipsoide entero, también el X×3 y el Z×3.
			var p1: Vector3 = c0 + u1 * semi * rng.randf_range(0.7, 1.0)
			var p2: Vector3 = c0 - u1 * semi * rng.randf_range(0.5, 1.0) + (u2 * semi * 0.25 if not largo else Vector3.ZERO)
			var dirv: Vector3 = p2 - p1
			var l_tot: float = dirv.length()
			var ejv: Vector3 = dirv / maxf(l_tot, 0.001)
			var ref: Vector3 = Vector3.UP if absf(ejv.y) < 0.9 else Vector3.RIGHT
			var lat1: Vector3 = ejv.cross(ref).normalized()
			var lat2: Vector3 = ejv.cross(lat1).normalized()
			var prev: Vector3 = p1
			for s in TRAMOS:
				var k: float = float(s + 1) / float(TRAMOS)
				var sig: Vector3 = p1 + dirv * k
				if s < TRAMOS - 1:
					var ruido: float = 0.12 * l_tot / float(TRAMOS) * 3.0 + 0.1
					sig += lat1 * rng.randf_range(-ruido, ruido) + lat2 * rng.randf_range(-ruido, ruido)
				var seg: Vector3 = sig - prev
				var ls: float = maxf(seg.length(), 0.001)
				var b := Basis.looking_at(seg / ls, Vector3.UP if absf(seg.normalized().y) < 0.95 else Vector3.RIGHT)
				var mitad: Vector3 = (prev + sig) * 0.5
				var gr: float = 0.045 if not largo else 0.07
				_mm_nucleo.set_instance_transform(a * TRAMOS + s, Transform3D(b.scaled(Vector3(gr, gr, ls * 1.08)), mitad))
				_mm_nucleo.set_instance_color(a * TRAMOS + s, Color(col["mota"]) * 1.0)
				_mm_halo.set_instance_transform(a * TRAMOS + s, Transform3D(b.scaled(Vector3(gr * 3.0, gr * 3.0, ls * 1.1)), mitad))
				_mm_halo.set_instance_color(a * TRAMOS + s, Color(col["c"], 0.16))
				prev = sig

	## ================================================================ GAS
	var _mm_motas: MultiMesh
	var _mm_hojas: MultiMesh
	var _motas: Array = []
	var _hojas: Array = []

	func _ini_gas() -> void:
		var viento: bool = elemento == "viento"
		var nh: int = 50 if viento else 0
		nh = int(nh * DENSIDAD)
		var nm: int = int(120 * DENSIDAD)
		_mm_motas = _mm(_quad(), nm, cfg.material_suave("blend_mix"))
		for n in nm:
			_motas.append(_nueva_particula_gas())
		_contorno = _elipsoide(cfg.material_burbuja(Color(col["c"]).lerp(Color(col["mota"]), 0.4)))
		if nh > 0:
			var q := _quad()
			var mh := StandardMaterial3D.new()
			mh.vertex_color_use_as_albedo = true
			mh.cull_mode = BaseMaterial3D.CULL_DISABLED
			mh.roughness = 0.8
			_mm_hojas = _mm(q, nh, mh)
			for n in nh:
				var p: Dictionary = _nueva_particula_gas()
				p["giro"] = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
				p["vgiro"] = Vector3(rng.randf_range(-4.0, 4.0), rng.randf_range(-4.0, 4.0), rng.randf_range(-6.0, 6.0))
				p["verde"] = Color(col["hondo"]).lerp(Color(col["c"]), rng.randf())
				_hojas.append(p)
		_act = _act_gas

	func _nueva_particula_gas() -> Dictionary:
		return {"ang": rng.randf() * TAU, "h": rng.randf_range(-1.0, 1.0), "rr": rng.randf_range(0.25, 1.0), "w": rng.randf_range(1.4, 3.0), "fase": rng.randf()}

	func _pos_gas(p: Dictionary) -> Vector3:
		var yn: float = fposmod(float(p["h"]) + t * 0.22 + 1.0, 2.0) - 1.0
		var ang: float = float(p["ang"]) + float(p["w"]) * t * (1.5 - 0.5 * (yn * 0.5 + 0.5))
		var rad: float = sqrt(maxf(0.0, 1.0 - yn * yn)) * float(p["rr"])
		return Vector3(cos(ang) * semi.x * rad, semi.y * (1.0 + yn), sin(ang) * semi.z * rad)

	func _act_gas(_dt: float) -> void:
		var m: float = _media()
		var tam: float = 0.24 + 0.14 * m
		if _contorno:
			_contorno.scale = semi * (0.7 + 0.3 * v)
			(_contorno.material_override as ShaderMaterial).set_shader_parameter("vida", v * 0.6)
		for n in _motas.size():
			var p: Dictionary = _motas[n]
			var yn: float = fposmod(float(p["h"]) + t * 0.22 + 1.0, 2.0) - 1.0
			var borde: float = 1.0 - absf(yn)
			var s: float = tam * v * (0.6 + 0.6 * borde)
			_mm_motas.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3(s, s, 1.0)), _pos_gas(p)))
			_mm_motas.set_instance_color(n, Color(Color(col["mota"]).lerp(Color(col["c"]), 0.4), 0.30 * borde * v))
		for n in _hojas.size():
			var p: Dictionary = _hojas[n]
			var pos: Vector3 = _pos_gas(p)
			var giro: Vector3 = (p["giro"] as Vector3) + (p["vgiro"] as Vector3) * t
			var s: float = (0.22 + 0.07 * m) * v
			_mm_hojas.set_instance_transform(n, Transform3D(Basis.from_euler(giro).scaled(Vector3(s * 0.7, s, s)), pos))
			_mm_hojas.set_instance_color(n, p["verde"])

	## ================================================================ CAMPO
	var _burbuja: MeshInstance3D
	var _mm_deriva: MultiMesh
	var _deriva: Array = []
	var _aro_campo: MeshInstance3D

	func _ini_campo() -> void:
		_burbuja = _elipsoide(cfg.material_burbuja(Color(col["c"]).lerp(Color(col["mota"]), 0.4)))
		_mm_deriva = _mm(_quad(), 40, cfg.material_suave("blend_add"))
		for n in 40:
			_deriva.append(_nueva_particula_gas())
		var tor := TorusMesh.new()
		tor.inner_radius = 0.95
		tor.outer_radius = 1.0
		tor.rings = 40
		tor.ring_segments = 6
		_aro_campo = MeshInstance3D.new()
		_aro_campo.mesh = tor
		_aro_campo.material_override = cfg.material_cascara(Color(col["mota"]), 1.0, 0.9, 1.0)
		_aro_campo.position = Vector3(0.0, 0.06, 0.0)
		add_child(_aro_campo)
		_act = _act_campo

	func _act_campo(_dt: float) -> void:
		var respiro: float = 1.0 + 0.015 * sin(t * 3.0)
		_burbuja.scale = semi * respiro * (0.7 + 0.3 * v)
		(_burbuja.material_override as ShaderMaterial).set_shader_parameter("vida", v)
		var onda: float = fposmod(t, 1.0)
		_aro_campo.scale = Vector3(semi.x * (0.9 + 0.2 * onda), 1.0, semi.z * (0.9 + 0.2 * onda))
		(_aro_campo.material_override as ShaderMaterial).set_shader_parameter("color", Color(col["mota"], v * (1.0 - onda) * 0.9))
		var tam: float = 0.14 + 0.05 * _media()
		for n in _deriva.size():
			var p: Dictionary = _deriva[n]
			var pos: Vector3 = _pos_gas(p)
			pos = Vector3(0.0, semi.y, 0.0) + (pos - Vector3(0.0, semi.y, 0.0)) * 0.9
			var s: float = tam * v
			_mm_deriva.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3(s, s, 1.0)), pos))
			_mm_deriva.set_instance_color(n, Color(col["mota"], 0.6 * v))

	## ================================================================ PLANO (sin VFX)
	## La cáscara del volumen, en el azul del agua (la gota de agua de base), con su LÍMITE bien marcado: el borde de la cáscara brilla (silueta) y tres aros blancos
	## —los círculos máximos XZ, XY e YZ del elipsoide— más su huella en el suelo dicen dónde acaba el volumen desde cualquier cámara (Pablo: «contorno muy visible»).
	var _aros_plano: Array = []                       ## [MeshInstance3D, Basis de orientación, Vector3 de escala unidad]

	func _ini_plano() -> void:
		var azul: Color = Color(COLORES["agua"]["c"]).lerp(Color(COLORES["agua"]["mota"]), 0.3)
		_burbuja = _elipsoide(cfg.material_burbuja(azul))
		_silueta_plano = _elipsoide(cfg.material_cascara(Color(0.45, 0.95, 1.0), 2.0, 0.0, 1.6))
		var tor := TorusMesh.new()
		tor.inner_radius = 0.955
		tor.outer_radius = 1.0
		tor.rings = 64
		tor.ring_segments = 8
		var mat: ShaderMaterial = cfg.material_cascara(Color(1.0, 1.0, 1.0), 1.0, 1.0, 1.5)
		for o in [Basis.IDENTITY, Basis(Vector3.RIGHT, PI * 0.5), Basis(Vector3.BACK, PI * 0.5), Basis.IDENTITY]:
			var mi := MeshInstance3D.new()
			mi.mesh = tor
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			_aros_plano.append([mi, o])
		_act = _act_plano

	var _silueta_plano: MeshInstance3D

	func _act_plano(_dt: float) -> void:
		var k: float = 0.7 + 0.3 * v
		var s: Vector3 = semi * k
		_burbuja.scale = s
		(_burbuja.material_override as ShaderMaterial).set_shader_parameter("vida", v * 0.8)
		_silueta_plano.scale = s * 1.01
		(_silueta_plano.material_override as ShaderMaterial).set_shader_parameter("color", Color(0.45, 0.95, 1.0, v))
		for n in _aros_plano.size():
			var mi: MeshInstance3D = _aros_plano[n][0]
			var o: Basis = _aros_plano[n][1]
			var e: Vector3                                   # semiejes del plano del aro, en los ejes LOCALES del toro (x, grosor, z)
			var centro: Vector3 = Vector3(0.0, semi.y * k, 0.0)
			match n:
				0:
					e = Vector3(s.x, (s.x + s.z) * 0.5, s.z)                 # horizontal, a media altura (XZ)
				1:
					e = Vector3(s.x, (s.x + s.y) * 0.5, s.y)                 # vertical de frente (XY)
				2:
					e = Vector3(s.y, (s.y + s.z) * 0.5, s.z)                 # vertical de lado (YZ)
				_:
					e = Vector3(s.x, (s.x + s.z) * 0.5, s.z)                 # la huella en el suelo (XZ a ras)
					centro = Vector3(0.0, 0.06, 0.0)
			mi.transform = Transform3D(o * Basis.from_scale(e), centro)

	## ================================================================ FIRMAS POR PROPIEDAD (encima del estado)
	func _ini_firmas() -> void:
		_w = Node3D.new()
		_w.top_level = true                # rebotes y huellas viven en coordenadas de MUNDO: no se mueven con el volumen
		add_child(_w)
		# viaja = estela: 24 puffs que se quedan atrás.
		if _viaja:
			_estela = _mm(_quad(), 24, cfg.material_suave("blend_add"))
			_estela_z.resize(24)
			_estela_edad.resize(24)
			for n in 24:
				_estela_edad[n] = 9.0
			# Lo que va dejando: cada tanda ya materializada sigue viva `persiste` s. Es una cáscara tenue donde estuvo el volumen (no se repite el efecto
			# entero en cada casilla: serían cientos de partículas por hechizo). Solo las zonas con pulsos; el sólido deja sus bloques y el agua su agua.
			if estado == "plasma" or estado == "gas" or estado == "campo":
				for i in range(pista.size() - 1):
					var k: Dictionary = pista[i]
					var sig: Dictionary = pista[i + 1]
					var d: Vector3 = k["d"]
					var der: Vector3 = Vector3.UP.cross(d).normalized() * -1.0
					var mi := _elipsoide(cfg.material_cascara(Color(col["c"]), 3.0, 0.03, 0.7))
					remove_child(mi)
					_w.add_child(mi)
					mi.transform = Transform3D(Basis(der, Vector3.UP, d).scaled_local(semi), (k["p"] as Vector3) + d * _adelanto() * cfg.casilla + Vector3(0.0, semi.y, 0.0))
					mi.visible = false
					_huellas.append({"t0": float(sig["t"]), "t1": minf(float(k["t"]) + _pers, vida - muere), "mi": mi})
		# rebote = chispas y un anillo donde el camino REAL cambia de dirección (el Lanzador3D traza el camino con `trazar`): a mitad del tramo que acaba
		# en el choque, en la cara delantera del volumen. Sin viaje no hay camino y no rebota nada que dibujar (rebote sin flecha solo refleja golpes).
		var tope: int = mini(3, int(float(props.get("rebotes", 0.0))))
		for i in range(1, pista.size()):
			if _rebotes.size() >= tope:
				break
			var a: Dictionary = pista[i - 1]
			var b: Dictionary = pista[i]
			if (a["d"] as Vector3).dot(b["d"] as Vector3) >= 0.9:
				continue
			var sp := _mm(_quad(), 12, cfg.material_suave("blend_add"), true, _w)
			var tor := TorusMesh.new()
			tor.inner_radius = 0.9
			tor.outer_radius = 1.0
			var aro := MeshInstance3D.new()
			aro.mesh = tor
			aro.material_override = cfg.material_cascara(Color(col["mota"]), 1.0, 1.0, 1.4)
			aro.visible = false
			_w.add_child(aro)
			var dirs: Array = []
			for n in 12:
				dirs.append(((b["d"] as Vector3) * rng.randf_range(0.2, 1.2) + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.4, 1.4), rng.randf_range(-0.6, 0.6))).normalized() * rng.randf_range(2.0, 5.0))
			var frente: Vector3 = (a["p"] as Vector3) + (a["d"] as Vector3) * (_adelanto() + float(g.get("z", 0.5))) * cfg.casilla + Vector3(0.0, 0.1, 0.0)
			_rebotes.append({"t": (float(a["t"]) + float(b["t"])) * 0.5, "punto": frente, "sp": sp, "aro": aro, "dirs": dirs})
		# solidez = borde duro: cáscara brillante y apretada alrededor del volumen.
		if float(props.get("solidez", 0.0)) > 0.0 and not sobre_celdas:
			_escudo = _elipsoide(cfg.material_cascara(Color(col["mota"]).lerp(Color.WHITE, 0.4), 4.5, 0.03, 2.0), Vector3(1.04, 1.04, 1.04))

	func _act_firmas(dt: float) -> void:
		if _estela:
			_estela_sig -= dt
			var avance: float = _avance
			if _estela_sig <= 0.0 and v > 0.3:
				_estela_sig = 0.06
				_estela_z[_estela_i] = 0.0
				_estela_edad[_estela_i] = 0.0
				_estela_i = (_estela_i + 1) % 24
			for n in 24:
				if _estela_edad[n] > 1.0:
					_estela.set_instance_transform(n, _oculto())
					continue
				_estela_edad[n] += dt / 0.6
				_estela_z[n] -= avance
				var k: float = 1.0 - _estela_edad[n]
				var s: float = (0.5 + 0.2 * _media()) * (0.5 + 0.5 * k)
				_estela.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3(s, s, 1.0)), Vector3(0.0, semi.y, _estela_z[n])))
				_estela.set_instance_color(n, Color(col["c"], 0.5 * k))
		for r in _rebotes:
			var e: float = t - float(r["t"])
			var aro: MeshInstance3D = r["aro"]
			var sp: MultiMesh = r["sp"]
			var p0: Vector3 = r["punto"]
			if e < 0.0 or e > 0.5:
				aro.visible = false
				for n in 12:
					sp.set_instance_transform(n, _oculto())
				continue
			aro.visible = true
			var rad: float = lerpf(0.4, 1.0, e / 0.5) * maxf(semi.x, semi.z)
			aro.transform = Transform3D(Basis.from_scale(Vector3(rad, 1.0, rad)), p0)
			(aro.material_override as ShaderMaterial).set_shader_parameter("color", Color(col["mota"], 1.0 - e / 0.5))
			for n in 12:
				var pos: Vector3 = p0 + Vector3(0.0, 0.2, 0.0) + (r["dirs"][n] as Vector3) * e + Vector3(0.0, -6.0 * e * e, 0.0)
				var s: float = 0.14 * (1.0 - e / 0.5)
				sp.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3(s, s, 1.0)), pos))
				sp.set_instance_color(n, Color(col["mota"], 1.0))
		for hu in _huellas:
			var mi: MeshInstance3D = hu["mi"]
			var vis: bool = t >= float(hu["t0"]) and t < float(hu["t1"]) + 0.3
			mi.visible = vis
			if vis:
				var a: float = clampf(1.0 - (t - float(hu["t1"])) / 0.3, 0.0, 1.0) * smoothstep(0.0, 0.12, t - float(hu["t0"]))
				(mi.material_override as ShaderMaterial).set_shader_parameter("color", Color(col["c"], 0.55 * a))


## ==========================================================================================================================================
## UNA RÁFAGA de `vfx_hechizo`: unas pocas partículas (≤ 20) que salen de un punto del mundo y se apagan solas. Sin luz. La resuelve `tipo_de_vfx`.
## ==========================================================================================================================================
class Rafaga:
	extends Node3D

	var cfg: VfxEstado3D
	var tipo: Dictionary
	var elemento: String = ""
	var reducida: bool = false
	var t: float = 0.0
	var _vida: float = 0.5
	var _mm: MultiMesh
	var _dirs: Array = []
	var _col: Color = Color.WHITE

	func construir() -> void:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var c: Dictionary = VfxEstado3D.COLORES.get(elemento, VfxEstado3D.COLOR_RESERVA)
		_col = Color(c[String(tipo["color"])])
		var n: int = int(tipo["n"])
		_vida = float(tipo["vida"])
		if reducida:
			n = maxi(4, int(n * 0.4))
			_vida *= 0.6
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		_mm = MultiMesh.new()
		_mm.transform_format = MultiMesh.TRANSFORM_3D
		_mm.use_colors = true
		_mm.instance_count = n
		_mm.mesh = q
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = _mm
		mi.material_override = cfg.material_suave(String(tipo["mezcla"]))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 16.0
		add_child(mi)
		for i in n:
			_dirs.append(Vector3(rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0)).normalized() * rng.randf_range(0.4, 1.0))
		_pintar()

	func _process(delta: float) -> void:
		t += delta
		if t >= _vida:
			queue_free()
			return
		_pintar()

	func _pintar() -> void:
		var e: float = clampf(t / _vida, 0.0, 1.0)
		var vel: float = float(tipo["vel"])
		var tam: float = float(tipo["tam"])
		for i in _dirs.size():
			var pos: Vector3 = (_dirs[i] as Vector3) * vel * t + Vector3(0.0, float(tipo["sube"]) * t - 0.5 * float(tipo["grav"]) * t * t, 0.0)
			var s: float = tam * ((0.5 + e) if bool(tipo["crece"]) else (1.0 - e))
			_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(s, s, 1.0)), pos))
			_mm.set_instance_color(i, Color(_col, 0.9 * (1.0 - e)))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE and is_instance_valid(cfg):
			cfg._rafagas -= 1
