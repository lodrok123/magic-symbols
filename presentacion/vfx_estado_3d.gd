class_name VfxEstado3D
extends Node

## VFX POR ESTADO DE LA MATERIA (Pipeline, 18/10, receta V2). Escucha `Lanzador3D.hechizo_v2(estado, elemento, g, origen, dir, props)` y dibuja el
## hechizo como un VOLUMEN ELIPSOIDE (x, y, z en casillas) en lugar de una forma con nombre. El porqué de dibujar por ESTADO y no por forma: en la
## receta V2 las formas ya no existen en la lógica (un «muro» es un volumen X×3 de estado sólido), así que un VFX por forma no tendría de dónde
## colgarse, y un VFX por estado escala solo a cualquier (X, Y, Z) que el jugador consiga componer.
##
## REUTILIZA EL KIT (19/10, entrada 189): cada estado monta las piezas ya validadas de `VfxKit3D` (lengua, brasa, chispa, charco, cinta, cono, burbuja, ola) y de `Formas3D`
## (piedra, cristal, rayo, hoja), teñidas con el perfil del elemento (`VfxKit3D.de(elemento)`); aquí solo se decide CUÁNTAS y DÓNDE según el volumen. Antes era todo propio
## (gotas y llamas genéricas) y no se distinguía un elemento de otro. Los elementos sin arte validado (`VfxKit3D.VALIDADOS`) usan las mismas piezas con su rampa de color.
##
## Seis efectos, uno por estado, todos escalados a los semiejes del volumen y con la misma vida (nace → vive `persiste` → muere):
##   solido   bloques facetados que emergen del suelo, uno por casilla × nivel (tierra: piedras con la paleta y polvo; hielo: cristales de VFX_RAYO_HIELO P3, escarcha y luz fría)
##   liquido  lo que viaja es la burbuja de agua del kit; un volumen ancho en X es la ola (`ajustar_tira`); cae con gravedad×0,5 y salpica (el agua de verdad la pone AguaSim)
##   plasma   lenguas del kit repartidas por la huella (la altura sale de Y), brasas y chispas, charco de luz que late a 4 Hz (el pulso de 0,25 s del juego) y una luz; sin gotas
##   energia  arcos P1–P2 de VFX_RAYO_HIELO.md DENTRO del volumen (re-sorteados cada 70 ms en los saltos), halo, destello y una luz
##   gas      remolino del método del kit (rampa + ruido + erosión) que sube en espiral por el elipsoide, con hojas si es viento
##   campo    burbuja del kit que distorsiona lo que hay detrás, anillo en el suelo y motas lentas
## Propiedades (MEJORAS_POTENCIA.md §2), dibujadas con lo que REALMENTE pasa: desde la entrada 160 la señal trae `eventos` [{t, pos, dir}] (una por
## tanda de casillas, con la hora y el sitio en que el Lanzador3D las materializa), `persiste`, `suelo` y `t_caida`, así que ya no se aproxima nada:
##   copias   = un volumen COMPLETO por copia, una al lado de otra (el Lanzador las separa 2·x casillas de lado); las copias de un proyectil sí van como ecos
##   viaja    = el volumen avanza por el camino real (8 casillas/s), con la estela del kit (conos), y las tandas que va dejando persisten (huellas translúcidas)
##   rebotes  = chispas y anillo en el punto y el instante en que el camino cambia de dirección
##   crece    = nace pequeño al 30 % en planta (X y Z, no la altura) y crece lineal el tiempo que dice la receta ((1 − 0,3) / crece)
##   permanencia = «quieto»: llama baja, charco, bloque asentado. Lo que VIAJA desaparece al llegar si permanencia = 0 (ESPEC §0.3)
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
## Semieje mínimo con el que se DIBUJA un volumen, en casillas (24/10: derivan de la base 0,10, ya no son números sueltos que la recortaban). Un volumen quieto no baja
## de la esfera base; un proyectil, de la esfera base ya reducida a ESCALA_PROYECTIL: su dibujo tiene que casar con el radio con el que golpea (`HechizoVivo._radio_u`).
const PISO_QUIETO_CAS: float = Sigils.RADIO_BASE_V2
const PISO_PROYECTIL_CAS: float = Sigils.RADIO_BASE_V2 * Hechizo.ESCALA_PROYECTIL
## Densidad visual de plasma y gas (1 = la de antes). Con 1 las llamas se sumaban hasta saturar a blanco y tapaban el contorno
## del volumen; con menos partículas, más pequeñas y más transparentes se lee la silueta (el elipsoide que da el tamaño).
const DENSIDAD: float = 0.4
## MODO PLANO (elemento de prueba del laboratorio, «agua sin VFX»): con `plano = true` TODO volumen se dibuja solo como un elipsoide translúcido azul, sin llamas, motas,
## chispas ni luces, para ver el tamaño y el contorno sin nada encima. Lo pone el lab (Pablo: «no distingo nada en el fuego»); en el juego se queda en false.
static var plano: bool = false
const MAX_CARRILES: int = 4                ## copias máximas (Sigils.GLIFOS.repeticion.tope)
const VEL_VIAJE: float = 8.0               ## RESPALDO (lanzador de mentira, sin `velocidad` en la señal): casillas/s del volumen que viaja. Con el Hechizo real manda `g["velocidad"]` (ESPEC §1.2)
const ESCALA_NACE: float = 0.3             ## fracción en planta con la que nace un volumen que crece (Lanzador3D.ESCALA_NACE_V2)
const MAX_PROYECTILES: int = 8            ## dibujos de proyectil a la vez (Hechizo.MAX_VIVOS = 32 hijos incluidos serían 32 × 280 partículas); el resto vuela sin dibujo
const MAX_RAFAGAS: int = 24               ## ráfagas de `vfx_hechizo` a la vez (la estela pide una cada 0,5 u: un proyectil rápido las encadena)
const MAX_BLOQUES: int = 150               ## tope de bloques de roca de un hechizo sólido (cuentan como partículas)

## Tamaño de una casilla en unidades (Terreno3D.casilla = 2,3). Es propiedad para que la prueba y el juego puedan fijarlo sin depender de Terreno3D.
var casilla: float = 2.3
## ENCENDIDO (Pipeline, 20/10, entrada 203): con false NO dibuja los volúmenes ni los proyectiles por estado de la materia. El efecto que manda es el del
## ELEMENTO (`VfxElemento3D`); este queda apagado en la maqueta hasta que se valide elemento por elemento (la bandera del lab lo enciende). Las ráfagas de
## `vfx_hechizo` (estela, efecto_impacto, acción `vfx`) NO dependen de la bandera: no las dibuja ningún otro receptor.
var encendido: bool = true
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
	if not encendido or hv.h == null or hv.h.velocidad <= 0.0:
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
	var sv: Vector3 = hv.h.semiejes_vuelo       # el proyectil se dibuja del tamaño con el que choca (Hechizo.ESCALA_PROYECTIL)
	e.g = {"x": sv.x, "y": sv.y, "z": sv.z, "niveles": 1, "celdas": [], "persiste": 0.0, "eventos": []}
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
	if not encendido:
		return
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
	# ESPEC §1.6: de centro a centro = 2·semieje + `separacion` (m), y cada copia gira `dispersion` grados respecto a la anterior. Sin ellos (señal vieja), 2·x o 1 casilla.
	var sep: float = maxf(2.0 * float(g["x"]) + float(g["separacion"]), HechizoVivo.SEPARACION_COPIAS_MIN_CASILLAS) * casilla if g.has("separacion") else maxf(2.0 * float(g.get("x", 0.5)), 1.0) * casilla
	var abanico: float = float(g.get("dispersion", 0.0))
	var vel: float = float(g["velocidad"]) if float(g.get("velocidad", 0.0)) > 0.0 else VEL_VIAJE
	var perp: Vector2 = d2.orthogonal()
	var ev: Array = []
	for i in copias:
		var mitad: float = float(i) - float(copias - 1) * 0.5
		var o: Vector2 = Vector2(origen.x, origen.z) + perp * (mitad * sep)
		var di: Vector2 = d2.rotated(deg_to_rad(mitad * abanico))
		ev.append({"t": 0.0, "pos": o, "dir": di})
		for k in range(1, int(floorf(viaja)) + 1):
			ev.append({"t": float(k) / vel, "pos": o + di * casilla * float(k), "dir": di})
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
	var _pers: float = 1.0         ## cuánto se queda cada tanda al acabar: `persiste` (+ `permanencia` si nace quieto) o solo `permanencia` si viaja (§0.3)
	var _fin_comun: float = -1.0   ## hora (s) a la que acaban TODAS las tandas de un volumen que viaja (llegada + permanencia); −1 = no viaja o señal vieja
	var _elev: float = 0.0         ## `elevacion` en unidades: a cuánto del suelo nace el volumen (ESPEC §1.2)
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
	var _rebotes: Array = []       ## [{t, punto, sp: MultiMesh, aro: MeshInstance3D, dirs}]
	var _escudo: MeshInstance3D
	var vivo: HechizoVivo = null   ## proyectil: el nodo del que cuelga este dibujo (null = un volumen normal de `hechizo_v2`)
	var proyectil: bool = false
	var _fin: bool = false         ## el proyectil ya acabó: el dibujo se soltó del nodo y se apaga
	var _t_fin: float = 0.0
	var _con_luz: bool = false
	var _cuerpo: Node3D            ## sólido y líquido de proyectil: una bola (o la burbuja del kit), no bloques que caen ni una masa de agua

	## ---------------------------------------------------------------- construcción común
	func construir() -> void:
		proyectil = vivo != null
		_elem_kit = elemento if VfxKit3D.ELEMENTOS.has(elemento) else "fuego"      # el kit solo conoce estos; el resto se dibuja con la rampa de fuego
		_eco = float(carril) * 0.07                                                  # copias = ecos de la primera: cada una llega 0,07 s después y un poco más tenue
		rng.seed = hash("%s%s%s" % [estado, elemento, str(g.get("x", 0))]) + int(Time.get_ticks_usec() % 100000)
		col = COLORES.get(elemento, COLOR_RESERVA)
		var c: float = cfg.casilla
		# Un volumen quieto no baja de la esfera base (PISO_QUIETO_CAS); un proyectil, de la base reducida (PISO_PROYECTIL_CAS): su dibujo casa con el radio con el que golpea (`_radio_u`).
		var piso: float = PISO_PROYECTIL_CAS if proyectil else PISO_QUIETO_CAS
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
		# §0.3 (ESPEC_HECHIZO, entrada 184): lo que VIAJA desaparece al llegar o chocar y solo se queda `permanencia` s; la `persiste` del elemento no cuenta. Lo que nace quieto
		# vive `persiste` + `permanencia` (= `vida_total`). Sin `vida_total` (lanzador de mentira) se queda la regla de antes.
		var regla_nueva: bool = g.has("vida_total")
		_fin_comun = -1.0
		if regla_nueva and bool(g.get("viaja", false)):
			_pers = float(g.get("permanencia", 0.0))
			_fin_comun = _t_pista + _pers               # todas las tandas acaban a la vez: la hora de llegar + permanencia (HechizoVivo: `vida = t_viaje − t_tanda + permanencia`)
		elif regla_nueva:
			_pers = float(g["vida_total"])
		_elev = float(g.get("elevacion", 0.0)) * cfg.casilla
		if estado != "energia" and _fin_comun < 0.0:
			_pers = maxf(_pers, 0.25)
		nace = 0.2
		muere = 0.6 if estado == "solido" else 0.4
		# permanencia (ESPEC §0.3): lo que viaja pasa a «quieto» al llegar (llama baja, charco, bloque) y lo que nace quieto, al acabar `persiste`.
		_t_quieto = INF
		if regla_nueva and float(g.get("permanencia", 0.0)) > 0.0:
			_t_quieto = _t_pista if bool(g.get("viaja", false)) else nace + float(g.get("persiste", 0.0))
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
		centro.y += _elev
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
		var entra: float = smoothstep(0.0, 1.0, clampf((t - _eco) / nace, 0.0, 1.0))
		var sale: float = 1.0 - smoothstep(0.0, 1.0, clampf((t - (vida - muere)) / muere, 0.0, 1.0))
		v = entra * sale * pow(0.93, float(carril))
		_animar_kit()
		_aplicar_transform(delta)
		if _act.is_valid():
			_act.call(delta)
		_act_firmas(delta)

	## Proyectil: vive mientras el HechizoVivo esté activo. Al acabar (golpe, alcance, tiempo…) se suelta de él —el nodo se libera— y se apaga en `muere`.
	func _proceso_proyectil(delta: float) -> void:
		t += delta
		if not _fin and (not is_instance_valid(vivo) or (not vivo.activo and not vivo.quedandose) or vivo.is_queued_for_deletion()):   # `quedandose` (permanencia): ya paró, pero se queda dibujado donde está
			_soltar()
		var sale: float = 1.0
		if _fin:
			_t_fin += delta
			if _t_fin >= muere:
				queue_free()
				return
			sale = 1.0 - smoothstep(0.0, 1.0, _t_fin / muere)
		v = smoothstep(0.0, 1.0, clampf(t / nace, 0.0, 1.0)) * sale
		if is_instance_valid(vivo) and vivo.quedandose and _t_quieto == INF:
			_t_quieto = t                    # el proyectil ya paró y se queda (permanencia): pasa a «quieto»
		_animar_kit()
		_aplicar_transform(delta)
		if _act.is_valid():
			_act.call(delta)

	## Lo que sigue a la vitalidad: el `fade` de los materiales del kit, los emisores continuos y el estado «quieto».
	func _animar_kit() -> void:
		_q = smoothstep(0.0, 1.0, clampf((t - _t_quieto) / 0.25, 0.0, 1.0)) if _t_quieto < INF else 0.0
		for m in _mats_fade:
			(m as ShaderMaterial).set_shader_parameter("fade", v)
		if not (estado == "liquido" and _cayo):
			var enc: bool = v > 0.4
			for gp in _gpus:
				if (gp as GPUParticles3D).emitting != enc:
					(gp as GPUParticles3D).emitting = enc

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

	## ================================================================ PIEZAS DEL KIT (VfxKit3D)
	## (19/10, entrada 189) Cada estado se dibuja con las piezas validadas del kit —shader de llama (rampa + ruido + erosión), `bola`, `particulas`,
	## `charco`, `_cinta`, `_cono`— o de Formas3D (rayo, piedra, cristal), escaladas al volumen y con la estructura que dice la receta. Antes este
	## archivo era autocontenido (billboards de gota y llama genéricos) y todo se leía igual. El elemento del kit se fija con `_kit()` solo mientras
	## se construye una pieza (los materiales leen el perfil al crearse), y se deja como estaba para no pisar al Vfx3D.
	var _elem_kit: String = "fuego"
	var _mats_fade: Array = []        ## ShaderMaterial del kit con uniform `fade`: se animan con la vitalidad `v` (0 = deshecho, 1 = entero)
	var _gpus: Array = []             ## GPUParticles3D continuos: se apagan cuando el volumen muere
	var _q: float = 0.0               ## 0 = vivo · 1 = «quieto» (pasó la persistencia o llegó: solo queda la permanencia)
	var _t_quieto: float = INF        ## hora a la que pasa a «quieto» (permanencia, ESPEC §0.3); INF = nunca
	var _eco: float = 0.0             ## retraso de esta copia respecto a la primera (copias = ecos de la primera)
	var _grupo: Array = []            ## [[nodo, Transform3D local]]: piezas del kit que se mueven juntas (caída del líquido)

	func _kit(f: Callable) -> Variant:
		var previo: String = VfxKit3D.elemento
		VfxKit3D.elemento = _elem_kit
		var r: Variant = f.call()
		VfxKit3D.elemento = previo
		return r

	## Material de llama del kit con los ajustes de `opc`. `anima` = true → su `fade` sigue a la vitalidad `v`.
	func _mat_kit(opc: Dictionary, anima: bool = true) -> ShaderMaterial:
		var m: ShaderMaterial = _kit(func() -> Variant: return VfxKit3D.material(opc, _elem_kit))
		if anima:
			_mats_fade.append(m)
		return m

	func _malla_kit(malla: Mesh, mat: Material, xf: Transform3D = Transform3D.IDENTITY) -> MeshInstance3D:
		var mi: MeshInstance3D = VfxKit3D._malla(self, malla, mat)
		mi.transform = xf
		return mi

	## Emisor continuo del kit (`VfxKit3D.particulas`) repartido por la planta del volumen (caja, no esfera: un X×3 no es una bola) y contado
	## en el presupuesto. `caja` = semiejes de la caja de emisión (por defecto, la planta a ras de suelo).
	func _gp(pos: Vector3, n: int, vida_p: float, tam: float, vel: float, chispas: bool, grav: float, dir: Vector3, abanico: float, caja: Vector3 = Vector3.INF, en_gpus: bool = true) -> GPUParticles3D:
		var gp: GPUParticles3D = _kit(func() -> Variant: return VfxKit3D.particulas(self, pos, n, vida_p, tam, vel, chispas, true, 0.1, grav, dir, abanico))
		var pm := gp.process_material as ParticleProcessMaterial
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = caja if caja.x != INF else Vector3(maxf(semi.x * 0.85, 0.15), 0.12, maxf(semi.z * 0.85, 0.15))
		gp.visibility_aabb = AABB(Vector3(-semi.x - 4.0, -3.0, -semi.z - 4.0), Vector3(2.0 * semi.x + 8.0, 2.0 * semi.y + 8.0, 2.0 * semi.z + 8.0))
		particulas += n
		if en_gpus:
			_gpus.append(gp)
		return gp

	## Cuenta lo que una pieza del kit trae por dentro (sus GPUParticles) y recoge sus materiales con `fade` y sus emisores, para que sigan a `v`.
	func _adoptar(nodo: Node) -> void:
		var pila: Array = [nodo]
		while not pila.is_empty():
			var n: Node = pila.pop_back()
			pila.append_array(n.get_children())
			if n is GPUParticles3D:
				particulas += (n as GPUParticles3D).amount
				_gpus.append(n)
			elif n is MeshInstance3D:
				var m: Material = (n as MeshInstance3D).material_override
				if m is ShaderMaterial and (m as ShaderMaterial).shader != null and (m as ShaderMaterial).shader.code.contains("uniform float fade") and not _mats_fade.has(m):
					_mats_fade.append(m)

	## Charcos de luz del kit en el suelo, uno por cada ~radio a lo largo del eje largo del volumen (un X×3 no es un charco redondo).
	var _charcos: Array = []          ## [[Decal o MeshInstance3D, energía base]]

	func _ini_charcos(energia: float) -> void:
		var menor: float = minf(semi.x, semi.z)
		var mayor: float = maxf(semi.x, semi.z)
		var r: float = maxf(menor * 1.5, 1.2)
		var n: int = clampi(ceili(mayor / r * 0.9), 1, 4)
		for i in n:
			var off: float = 0.0 if n == 1 else lerpf(-(mayor - r * 0.6), mayor - r * 0.6, float(i) / float(n - 1))
			var pos := Vector3(off, 0.0, 0.0) if semi.x >= semi.z else Vector3(0.0, 0.0, off)
			var nodo: Node3D = _kit(func() -> Variant: return VfxKit3D.charco(self, pos, r, energia, 0.0))
			_charcos.append([nodo, energia])

	func _luz_charcos(f: float) -> void:
		for ch in _charcos:
			var nodo: Node = ch[0]
			if not is_instance_valid(nodo):
				continue
			if nodo is Decal:
				(nodo as Decal).emission_energy = float(ch[1]) * f
			elif nodo is MeshInstance3D and (nodo as MeshInstance3D).material_override is ShaderMaterial:
				((nodo as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("alfa", f)

	## Escarcha del hielo en el suelo (VFX_RAYO_HIELO P3): disco blanco azulado de borde suave que se queda mientras vive el hielo.
	var _escarcha: Node = null

	func _ini_escarcha(centro: Vector3, radio: float) -> void:
		if VfxKit3D._usa_decal():
			var d := Decal.new()
			d.size = Vector3(radio * 2.0, 1.4, radio * 2.0)
			d.position = centro + Vector3(0.0, 0.5, 0.0)
			d.texture_albedo = VfxKit3D.mancha()
			d.albedo_mix = 1.0
			d.modulate = Color(0.9, 0.97, 1.0, 0.0)
			d.cull_mask = 1
			add_child(d)
			_escarcha = d
		else:
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_texture = VfxKit3D.mancha()
			m.albedo_color = Color(0.9, 0.97, 1.0, 0.0)
			var q: MeshInstance3D = VfxKit3D._malla(self, VfxKit3D._quad(Vector2(radio * 2.0, radio * 2.0), true), m)
			q.position = centro + Vector3(0.0, 0.045, 0.0)
			_escarcha = q

	func _luz_escarcha(a: float) -> void:
		if _escarcha is Decal:
			(_escarcha as Decal).modulate = Color(0.9, 0.97, 1.0, a)
		elif _escarcha is MeshInstance3D:
			((_escarcha as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = Color(0.9, 0.97, 1.0, a)

	## Mueve juntas las piezas de un grupo (la ola o la burbuja que cae): `xf` se compone con la transformación local de cada una.
	func _mover_grupo(xf: Transform3D) -> void:
		for p in _grupo:
			(p[0] as Node3D).transform = xf * (p[1] as Transform3D)

	## Pasa los hijos de `cabeza` (lo que dibujó una pieza del kit) a este volumen conservando su transformación, para poder escalarlos y
	## moverlos como grupo sin un nodo intermedio (la prueba mide las mallas hijas del volumen, no las anidadas).
	func _agrupar(cabeza: Node3D) -> void:
		for n in cabeza.get_children():
			var xf: Transform3D = (n as Node3D).transform
			cabeza.remove_child(n)
			add_child(n)
			_grupo.append([n, xf])
		remove_child(cabeza)
		cabeza.free()

	## ================================================================ BOLA DEL KIT (proyectil de plasma)
	## La bola de fuego validada (núcleo que se deshace, cola de cometa, brasas y chispas) a la medida del proyectil. El agua pone su burbuja por
	## el gancho `bola` de su elemento; el rayo y el resto usan la común con su rampa.
	func _ini_bola() -> void:
		var cabeza := Node3D.new()
		cabeza.position = Vector3(0.0, semi.y, 0.0)
		add_child(cabeza)
		var vel: float = vivo.v.length() if vivo != null and vivo.v.length() > 0.5 else 8.0
		_kit(func() -> Variant:
			VfxKit3D.bola(cabeza, Vector3(0.0, 0.0, 1.0), _media() / 0.3, 1.0, vel)
			return null)
		_adoptar(cabeza)
		_cuerpo = cabeza
		_luz_fuego = _luz(Color(_kit(func() -> Variant: return VfxKit3D.perfil()["luz"])), 1.6, semi.length() * 1.6 + 2.0)
		_act = _act_bola

	func _act_bola(_dt: float) -> void:
		if _luz_fuego:
			_luz_fuego.light_energy = (1.6 + 0.4 * sin(t * 23.0) + 0.3 * sin(t * 9.0)) * v

	## ================================================================ CUERPO DE PROYECTIL (sólido y líquido)
	## Líquido: la burbuja del agua (kit). Sólido: una piedra de Formas3D rodando con polvo (tierra) o un cristal que apunta hacia donde va con copos
	## detrás (hielo, la «flecha de hielo»).
	func _ini_cuerpo() -> void:
		if estado == "solido":
			var hielo: bool = elemento == "hielo"
			var cuerpo: MeshInstance3D
			if hielo:
				cuerpo = Formas3D.instancia("cristal", Color(0.9, 0.96, 1.0))
				# La punta (+Y del cristal) mira hacia delante (+Z): Basis(X, +90°) lleva +Y a +Z.
				cuerpo.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(_media() * 1.3, _media() * 3.4, _media() * 1.3)), Vector3(0.0, semi.y, -_media() * 1.5))
			else:
				cuerpo = Formas3D.instancia("piedra", Color(col["hondo"]).lerp(Color("B8ADB8"), 0.5), _media() * 2.2)
				cuerpo.position = Vector3(0.0, semi.y, 0.0)
			add_child(cuerpo)
			_cuerpo = cuerpo
			_gp(Vector3(0.0, semi.y, 0.0), 14, 0.6, 0.14 if not hielo else 0.1, 0.8, false, -2.0 if not hielo else -0.5, Vector3.UP, 180.0, Vector3(0.1, 0.1, 0.1))
		else:
			var cabeza := Node3D.new()
			cabeza.position = Vector3(0.0, semi.y, 0.0)
			add_child(cabeza)
			var vel: float = vivo.v.length() if vivo != null and vivo.v.length() > 0.5 else 8.0
			_kit(func() -> Variant:
				VfxKit3D.bola(cabeza, Vector3(0.0, 0.0, 1.0), _media() / 0.3, 1.0, vel)
				return null)
			_adoptar(cabeza)
			_cuerpo = cabeza
		_act = _act_cuerpo

	func _act_cuerpo(dt: float) -> void:
		var k: float = lerpf(0.5, 1.0, v)
		if estado == "solido":
			if elemento == "hielo":
				_cuerpo.scale = Vector3.ONE * k
			else:
				_cuerpo.scale = Vector3.ONE * _media() * 2.2 * k
				_cuerpo.rotate(Vector3(0.3, 1.0, 0.2).normalized(), dt * 5.0)
		else:
			_cuerpo.scale = Vector3.ONE * k

	## ================================================================ SÓLIDO
	var _bloques: Array = []       ## [{pos, rot, esc, h, retraso, salida, fin, base, y0}]
	var _mm_bloques: MultiMesh
	var _gps_polvo: Array = []     ## polvo (tierra) o copos (hielo) que sueltan los bloques al salir: solo los primeros 0,8 s
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

	## Lo común a los dos sólidos (el local, sin casillas, y el de mundo, sobre las casillas reales): mallas, bloques, polvo/escarcha y luz.
	## `celdas` = centro de cada bloque; `datos[n]` (opcional) pisa el tamaño, la hora de salida/hundimiento y el ancla del bloque n.
	## TIERRA: piezas `piedra` de Formas3D (con su contorno) teñidas con la paleta (835832, B8ADB8, 7D747C, DB8F59) y polvo del kit.
	## HIELO: cristales `cristal` de Formas3D (VFX_RAYO_HIELO P3: uno grande inclinado y otros pequeños de acompañamiento), copos del kit y
	## escarcha en el suelo.
	func _preparar_solido(celdas: Array, datos: Array, luz_pos: Vector3) -> void:
		var c: float = cfg.casilla
		var hielo: bool = elemento == "hielo"
		var diam: float = 0.68 if hielo else 0.8          # ancho de la malla sin escalar (el cristal mide 0,68; la piedra, 0,8)
		var alto_m: float = 1.0 if hielo else 0.8         # y alto
		var tonos: Array = []
		var lado_max: float = c
		for n in celdas.size():
			var p: Vector3 = celdas[n]
			var o: Dictionary = datos[n] if n < datos.size() else {}
			var h: float = lado_max * (rng.randf_range(1.0, 1.35) if hielo else rng.randf_range(0.85, 1.05))
			var ancho: float = lado_max * (rng.randf_range(1.1, 1.3) if hielo else rng.randf_range(1.2, 1.5))
			h = float(o.get("alto", h))
			ancho = float(o.get("ancho", ancho))
			# El cristal queda casi de pie pero inclinado; la roca, rodada del todo.
			var b := Basis.from_euler(Vector3(rng.randf_range(-0.3, 0.3) if hielo else rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU), rng.randf_range(-0.3, 0.3) if hielo else rng.randf_range(0.0, TAU)))
			var retraso: float = ((p.z + semi.z) / maxf(2.0 * semi.z, 0.01)) * 0.3 + rng.randf() * 0.1 + p.y / c * 0.04
			var salida: float = (1.0 - p.y / maxf(2.0 * semi.y, 0.01)) * 0.25 + rng.randf() * 0.1
			_bloques.append({"pos": p, "rot": b, "esc": Vector3(ancho / diam, h / alto_m, ancho / diam), "h": h, "retraso": float(o.get("retraso", retraso)), "salida": float(o.get("salida", salida)),
				"fin": float(o.get("fin", vida - muere)), "base": bool(o.get("base", false)), "y0": float(o.get("y0", 0.1))})
			tonos.append(_tono_bloque(hielo))
		# Hielo: a cada cristal grande le acompaña uno pequeño, más tarde y más bajo, ladeado (no «seis iguales en círculo»).
		if hielo:
			var n0: int = _bloques.size()
			for n in n0:
				if _bloques.size() >= MAX_BLOQUES:
					break
				var m: Dictionary = (_bloques[n] as Dictionary).duplicate()
				var a: float = rng.randf() * TAU
				var d: float = c * rng.randf_range(0.3, 0.5)
				var p0: Vector3 = m["pos"]
				m["pos"] = Vector3(p0.x + cos(a) * d, p0.y, p0.z + sin(a) * d)
				var k: float = rng.randf_range(0.3, 0.5)
				var e0: Vector3 = m["esc"]
				m["esc"] = Vector3(e0.x * 0.6, e0.y * k, e0.z * 0.6)
				m["h"] = float(m["h"]) * k
				m["retraso"] = float(m["retraso"]) + rng.randf_range(0.05, 0.08)
				m["rot"] = Basis.from_euler(Vector3(rng.randf_range(-0.45, 0.45), rng.randf_range(0.0, TAU), rng.randf_range(-0.45, 0.45)))
				_bloques.append(m)
				tonos.append(_tono_bloque(hielo))
		_mm_bloques = _mm(Formas3D.malla("cristal" if hielo else "piedra"), _bloques.size(), null)
		for n in _bloques.size():
			_mm_bloques.set_instance_color(n, tonos[n])
		# Polvo (tierra) o copos (hielo) del kit: salen de la planta del conjunto mientras emergen los bloques.
		var mn := Vector3(INF, INF, INF)
		var mx := Vector3(-INF, -INF, -INF)
		for b in _bloques:
			mn = mn.min(b["pos"])
			mx = mx.max(b["pos"])
		var centro := Vector3((mn.x + mx.x) * 0.5, mn.y, (mn.z + mx.z) * 0.5)
		var caja := Vector3(maxf((mx.x - mn.x) * 0.5 + c * 0.5, 0.3), 0.12, maxf((mx.z - mn.z) * 0.5 + c * 0.5, 0.3))
		if hielo:
			_gps_polvo.append(_gp(centro + Vector3(0.0, 0.2, 0.0), 14, 1.4, 0.1, 0.7, false, -0.6, Vector3.UP, 80.0, caja, false))
			_ini_escarcha(Vector3(centro.x, centro.y - 0.1, centro.z), maxf(caja.x, caja.z) * 1.15 + c * 0.5)
			_luz_hielo = _luz(Color(col["c"]), 0.9, semi.length() * 1.4 + 2.0, luz_pos)
		else:
			_gps_polvo.append(_gp(centro + Vector3(0.0, 0.1, 0.0), 24, 0.8, 0.22, 2.6, false, -5.0, Vector3.UP, 85.0, caja, false))
			_gps_polvo.append(_gp(centro + Vector3(0.0, 0.1, 0.0), 12, 0.6, 0.1, 3.4, false, -9.0, Vector3.UP, 70.0, caja, false))
		_act = _act_solido

	func _tono_bloque(hielo: bool) -> Color:
		if hielo:
			var tono: Color = Color(0.92, 0.97, 1.0).lerp(Color(0.72, 0.88, 1.0), rng.randf())     # casi blanco: el degradado turquesa → blanco lo pone la malla
			tono.a = 0.95
			return tono
		if elemento == "tierra":
			return [Color("835832"), Color("B8ADB8"), Color("7D747C"), Color("DB8F59")][rng.randi() % 4]
		return Color(col["c"]).lerp(Color(col["hondo"]), rng.randf() * 0.5)

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
			if pos.size() >= (MAX_BLOQUES / 2 if hielo else MAX_BLOQUES):      # el hielo duplica con los cristales pequeños
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
				var fin: float = maxf(_fin_comun, t_ev + 0.25) if _fin_comun >= 0.0 else t_ev + _pers   # lo que viaja acaba junto (mín. un pulso, 0,25 s), como HechizoVivo
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
			# El cristal tiene la base en el origen de la malla; la piedra está centrada.
			var y_pos: float = p.y if not hielo else (p.y if bool(b["base"]) else p.y - c * 0.5)
			var xf := Transform3D((b["rot"] as Basis).scaled(esc), Vector3(p.x, y_pos + y_off, p.z))
			_mm_bloques.set_instance_transform(n, xf)
		for gp in _gps_polvo:
			(gp as GPUParticles3D).emitting = t < 0.8
		_luz_escarcha(0.85 * minf(v * 2.0, 1.0))
		if _luz_hielo:
			_luz_hielo.light_energy = 0.9 * v

	## ================================================================ LÍQUIDO
	## Lo que cae es la BURBUJA del agua del kit (o, si el volumen es ancho en X, una OLA: la tira del kit con `ajustar_tira` del agua), con la
	## gravedad de la receta (ESPEC §0.5: ×0,5 → cae más despacio) y, al llegar, salpicadura del kit y un anillo de ruido que se abre. El agua de
	## verdad la pone AguaSim: esto es solo la entrada.
	var _t_caida: float = 0.5
	var _ola: bool = false
	var _aro: MeshInstance3D
	var _mat_aro: ShaderMaterial
	var _gp_salpica: GPUParticles3D
	var _cayo: bool = false
	var _alto_caida: float = 0.0

	func _ini_liquido() -> void:
		# El Lanzador3D manda cuándo entra el agua (`t_caida` = 0,4 + 0,07·semieje Y en casillas, máx. 0,8 s). Sin él, la misma cuenta.
		_t_caida = float(g["t_caida"]) if float(g.get("t_caida", 0.0)) > 0.0 else clampf(0.4 + 0.07 * float(g.get("y", 0.5)), 0.4, 0.8)
		# ESPEC §0.5: con menos gravedad cae más despacio. Tiempo de caída ∝ 1/√g (agua ×0,5 → ×1,41); la gravedad 1 (o sin dato) deja el tiempo de siempre.
		_t_caida /= sqrt(clampf(float(g.get("gravedad", 1.0)), 0.2, 1.0))
		var c: float = cfg.casilla
		_alto_caida = 2.0 * semi.y + 1.6 * c
		_ola = semi.x >= 0.9 * c and semi.x > 1.5 * semi.z
		if _ola:
			var largo: float = 2.0 * semi.x
			var alto: float = maxf(2.0 * semi.y, 0.8 * c) * 1.5
			# Tres capas en Z (el volumen tiene fondo) con las erosiones y velocidades de la tira del muro del kit.
			var capas: Array = [[0.0, 0.46, 1.05, 1.0], [semi.z * 0.5, 0.5, 0.85, 0.8], [-semi.z * 0.5, 0.52, 0.8, 1.15]]
			for i in (3 if semi.z > 0.3 * c else 1):
				var cp: Array = capas[i]
				var mat: ShaderMaterial = _mat_kit({"erosion": float(cp[1]), "brillo": float(cp[2]), "calor_max": 0.95, "ondula": 0.06, "ondula_freq": 6.0, "lateral": 0.04,
					"escala_ruido": Vector2(largo / 1.7, alto * 0.1 / float(cp[3])), "velocidad": Vector2(0.0, 1.6 * float(cp[3])), "fase": float(i) * 0.43, "potencia": 1.2, "suave": 0.18, "fade": 0.0})
				_kit(func() -> Variant:
					VfxKit3D.de().ajustar_tira(mat, largo, alto, [0.0, cp[1], cp[2], cp[3]])
					return null)
				var mi: MeshInstance3D = VfxKit3D._malla(self, VfxKit3D._quad(Vector2(largo, alto), false, Vector2i(24, 8)), mat)
				_grupo.append([mi, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, float(cp[0])))])
		else:
			var cabeza := Node3D.new()
			add_child(cabeza)
			var vel: float = maxf(_alto_caida / _t_caida, 4.0)
			_kit(func() -> Variant:
				VfxKit3D.bola(cabeza, Vector3.DOWN, 1.0 / 0.3, 1.0, vel)       # r = 1: se escala a los semiejes con el grupo
				return null)
			_adoptar(cabeza)
			_agrupar(cabeza)
		_mover_grupo(Transform3D(Basis.IDENTITY, Vector3(0.0, _alto_caida, 0.0)))
		# Anillo de ruido que se abre al caer (la `onda` del kit, sin su luz ni sus partículas: aquí van contadas aparte).
		_mat_aro = _mat_kit({"erosion": 0.38, "brillo": 1.1, "calor_max": 0.95, "suave": 0.2, "potencia": 1.1, "escala_ruido": Vector2(6.0, 0.6),
			"velocidad": Vector2(0.25, 1.6), "ondula": 0.05, "ondula_freq": 8.0, "fade": 0.0}, false)
		_aro = _malla_kit(VfxKit3D._cinta(1.0, TAU, 0.5, 64, false), _mat_aro)
		_aro.visible = false
		# Salpicadura: un disparo de gotas del kit en el momento de llegar (`restart()` en `_act_liquido`).
		_gp_salpica = _gp(Vector3(0.0, 0.2, 0.0), 24, 0.7, 0.1, 3.5, false, -7.0, Vector3.UP, 70.0, Vector3(semi.x * 0.7, 0.1, semi.z * 0.7), false)
		_gp_salpica.one_shot = true
		_gp_salpica.explosiveness = 0.85
		_gp_salpica.emitting = false
		_act = _act_liquido

	func _act_liquido(_dt: float) -> void:
		var p: float = clampf(t / _t_caida, 0.0, 1.0)
		var base_y: float = 0.0 if _ola else semi.y
		if t < _t_caida:
			var y: float = lerpf(_alto_caida, base_y, p * p)
			var est: float = 1.0 + 0.5 * p                  # se estira cayendo
			if _ola:
				_mover_grupo(Transform3D(Basis.from_scale(Vector3(1.0, est, 1.0)), Vector3(0.0, y, 0.0)))
			else:
				_mover_grupo(Transform3D(Basis.from_scale(semi * 0.8 * Vector3(1.0 / sqrt(est), est, 1.0 / sqrt(est))), Vector3(0.0, y, 0.0)))
			return
		if not _cayo:
			_cayo = true
			_gp_salpica.restart()
			for gp in _gpus:
				(gp as GPUParticles3D).emitting = false      # la burbuja deja de gotear al llegar
			_aro.visible = true
		var e: float = t - _t_caida
		var aplasta: float = clampf(e / 0.12, 0.0, 1.0)
		var desvanece: float = clampf((e - 0.1) / 0.35, 0.0, 1.0)
		var sy: float = lerpf(1.0, 0.12, aplasta)
		var sxz: float = lerpf(1.0, 1.2, aplasta) * (1.0 - desvanece * 0.5)
		if _ola:
			_mover_grupo(Transform3D(Basis.from_scale(Vector3(sxz, maxf(sy * (1.0 - desvanece), 0.001), 1.0)), Vector3.ZERO))
		else:
			_mover_grupo(Transform3D(Basis.from_scale(Vector3(semi.x * 0.8 * sxz, maxf(semi.y * 0.8 * sy * (1.0 - desvanece), 0.001), semi.z * 0.8 * sxz)), Vector3(0.0, semi.y * lerpf(1.0, 0.12, aplasta), 0.0)))
		for m in _mats_fade:
			(m as ShaderMaterial).set_shader_parameter("fade", v * (1.0 - desvanece))
		_aro.visible = e < 0.6
		if _aro.visible:
			var r: float = lerpf(0.5, 1.35, clampf(e / 0.5, 0.0, 1.0))
			_aro.transform = Transform3D(Basis.from_scale(Vector3(semi.x * r, 1.0, semi.z * r)), Vector3(0.0, 0.05, 0.0))
			_mat_aro.set_shader_parameter("fade", v * (1.0 - e / 0.6))

	## ================================================================ PLASMA
	## Lenguas del kit (las del impacto de la bola de fuego: dos quads cruzados con la llama del shader) repartidas por la planta del volumen, con la
	## altura que da Y; brasas y chispas del kit; charco de luz del kit; una luz. Sin billboards.
	var _lenguas: Array = []            ## [{mi, pos, rot, ancho, alto, fase}]
	var _luz_fuego: OmniLight3D
	var _contorno: MeshInstance3D       # cáscara tenue con el contorno exacto del volumen (plasma y gas)

	func _ini_plasma() -> void:
		if proyectil:
			_ini_bola()
			return
		var c: float = cfg.casilla
		var n: int = clampi(roundi(PI * semi.x * semi.z / (c * c) * 3.0), 3, 12)
		var ancho: float = clampf(sqrt(PI * semi.x * semi.z / float(n)) * 1.5, 0.7, 2.0)
		var alto0: float = maxf(semi.y * 1.7, 0.9)
		var mats: Array = []
		for i in 3:
			mats.append(_mat_kit({"erosion": 0.4, "brillo": 1.1, "calor_max": 1.0, "ondula": 0.06, "ondula_freq": 8.0, "escala_ruido": Vector2(0.6, 0.45), "velocidad": Vector2(0.0, 1.5),
				"fase": float(i) * 0.37, "fade": 0.0}))
		var quad := VfxKit3D._quad(Vector2.ONE)
		for i in n:
			var th: float = float(i) * 2.39996
			var rr: float = sqrt((float(i) + 0.5) / float(n)) * 0.85
			var pos := Vector3(cos(th) * rr * semi.x, 0.0, sin(th) * rr * semi.z)
			var alto: float = alto0 * rng.randf_range(0.8, 1.15) * (1.0 - 0.25 * rr)         # las del centro, más altas
			var rot: float = rng.randf() * PI
			var fase: float = rng.randf() * TAU
			for k in 2:                                                                       # dos quads en cruz: tienen cuerpo desde cualquier cámara
				var mi: MeshInstance3D = VfxKit3D._malla(self, quad, mats[i % 3])
				_lenguas.append({"mi": mi, "pos": pos, "rot": rot + float(k) * PI * 0.5, "ancho": ancho * rng.randf_range(0.85, 1.1), "alto": alto, "fase": fase})
		_gp(Vector3(0.0, 0.3, 0.0), 16, 1.1, 0.12, 2.8, false, -2.0, Vector3.UP, 60.0)                    # brasas
		_gp(Vector3(0.0, 0.3, 0.0), 8, 0.9, 0.1, 4.5, true, -6.0, Vector3.UP, 50.0)                       # chispas
		_luz_fuego = _luz(Color(_kit(func() -> Variant: return VfxKit3D.perfil()["luz"])), 1.6, semi.length() * 1.6 + 2.0)
		_contorno = _elipsoide(cfg.material_burbuja(Color(col["c"]).lerp(Color(col["mota"]), 0.4)))   # silueta tenue: la llama sola no dice dónde acaba el volumen
		_ini_charcos(1.8)
		_act = _act_plasma

	func _act_plasma(_dt: float) -> void:
		for l in _lenguas:
			var k: float = (0.85 + 0.15 * sin(t * 9.0 + float(l["fase"]))) * lerpf(1.0, 0.42, _q) * (0.35 + 0.65 * v)    # quieto: llama baja
			(l["mi"] as MeshInstance3D).transform = Transform3D(Basis(Vector3.UP, float(l["rot"])) * Basis.from_scale(Vector3(float(l["ancho"]), maxf(float(l["alto"]) * k, 0.01), 1.0)), l["pos"])
		if _contorno:
			_contorno.scale = semi * (0.7 + 0.3 * v)
			(_contorno.material_override as ShaderMaterial).set_shader_parameter("vida", v * 0.3)
		if _luz_fuego:
			_luz_fuego.light_energy = (1.6 + 0.4 * sin(t * 23.0) + 0.3 * sin(t * 9.0)) * v * lerpf(1.0, 0.6, _q)
		var latido: float = 0.55 + 0.45 * (0.5 + 0.5 * sin(t * TAU * 4.0))   # el pulso del juego: cada 0,25 s
		_luz_charcos(v * (0.7 + 0.3 * latido))

	## ================================================================ ENERGÍA
	## Arcos de la pieza `rayo` de Formas3D (la misma del pilar de rayo validado, VFX_RAYO_HIELO P1–P2), como mucho 6, que cruzan el volumen de lado a
	## lado y se RE-SORTEAN a saltos cada 0,08 s (el «a saltos» de EoW); chispas eléctricas del kit; destello y una luz. El proyectil lleva además un núcleo blanco.
	var _arcos: Array = []              ## MeshInstance3D (Formas3D «rayo»)
	var _destello: MeshInstance3D
	var _luz_rayo: OmniLight3D
	var _prox_arco: float = 0.0
	const ARCOS: int = 6

	func _ini_energia() -> void:
		for a in ARCOS:
			var mi: MeshInstance3D = Formas3D.instancia("rayo", Color(col["mota"]).lerp(Color.WHITE, 0.35))
			add_child(mi)
			_arcos.append(mi)
		_sortear_arcos()
		_gp(Vector3(0.0, semi.y, 0.0), 14, 0.45, 0.1, 5.0, true, 0.0, Vector3.UP, 180.0, Vector3(maxf(semi.x * 0.8, 0.1), maxf(semi.y * 0.8, 0.1), maxf(semi.z * 0.8, 0.1)))
		_destello = _elipsoide(cfg.material_cascara(Color(col["c"]), 2.0, 0.12, 1.0), Vector3(1.05, 1.05, 1.05))
		_luz_rayo = _luz(Color(col["mota"]).lerp(Color(col["c"]), 0.4), 3.0, semi.length() * 1.8 + 3.0)
		if proyectil:
			var nucleo: ShaderMaterial = _mat_kit({"cerrado": true, "eje": VfxKit3D.EJE_CENTRO, "erosion": 0.1, "suave": 0.4, "brillo": 1.3, "calor_max": 1.0, "fresnel_pot": 1.0, "fade": 0.0})
			_malla_kit(VfxKit3D._esfera(_media() * 0.7), nucleo, Transform3D(Basis.IDENTITY, Vector3(0.0, semi.y, 0.0)))
		_act = _act_energia

	func _act_energia(_dt: float) -> void:
		if t >= _prox_arco:
			_prox_arco = t + 0.08
			_sortear_arcos()
		var f: float = clampf(1.0 - t / vida, 0.0, 1.0) if not proyectil else v
		if _luz_rayo:
			_luz_rayo.light_energy = 3.0 * f * (0.6 + 0.4 * sin(t * 90.0))
		var dest: float = clampf(1.0 - t / 0.18, 0.0, 1.0)
		_destello.visible = dest > 0.0
		_destello.scale = semi * (1.05 + 0.25 * (1.0 - dest))
		(_destello.material_override as ShaderMaterial).set_shader_parameter("color", Color(col["mota"], dest))

	## Cada arco cruza el volumen de lado a lado (no se arremolinan en el centro): así el rayo «llena» el elipsoide entero, también el X×3 y el Z×3.
	func _sortear_arcos() -> void:
		var c0 := Vector3(0.0, semi.y, 0.0)
		for a in _arcos.size():
			var u1 := Vector3(rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0)).normalized()
			var u2 := Vector3(rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0)).normalized()
			var largo: bool = a >= ARCOS - 2
			var p1: Vector3 = c0 + u1 * semi * rng.randf_range(0.7, 1.0)
			var p2: Vector3 = c0 - u1 * semi * rng.randf_range(0.5, 1.0) + (u2 * semi * 0.25 if not largo else Vector3.ZERO)
			var dirv: Vector3 = p2 - p1
			var l_tot: float = maxf(dirv.length(), 0.05)
			var ejv: Vector3 = dirv / l_tot
			var ref: Vector3 = Vector3.UP if absf(ejv.y) < 0.9 else Vector3.RIGHT
			var lat1: Vector3 = ejv.cross(ref).normalized()
			var lat2: Vector3 = ejv.cross(lat1).normalized()
			var giro: float = rng.randf() * TAU                         # el zigzag de la pieza mira a un lado distinto cada salto
			var gr: float = (0.5 if not largo else 0.7) * clampf(l_tot * 0.35, 0.25, 0.9)
			var bx: Vector3 = (lat1 * cos(giro) + lat2 * sin(giro)) * gr
			var bz: Vector3 = (lat2 * cos(giro) - lat1 * sin(giro)) * gr
			var mi: MeshInstance3D = _arcos[a]
			mi.transform = Transform3D(Basis(bx, ejv * l_tot, bz), p1)

	## ================================================================ GAS
	## Remolino del kit: cintas de llama (`_cinta`, el shader de rampa + ruido + erosión) apiladas a lo alto del elipsoide con el radio del perfil, cada
	## una girando a su ritmo; motas del kit y, si es viento, hojas de Formas3D. La silueta tenue marca el volumen.
	var _anillos: Array = []            ## [{mi, y, rad, vel, ang, incl}]
	var _mm_hojas: MultiMesh
	var _hojas: Array = []

	func _ini_gas() -> void:
		var c: float = cfg.casilla
		var viento: bool = elemento == "viento"
		var nr: int = clampi(roundi(semi.y / c * 3.0) + 3, 3, 7)
		var alto_b: float = 2.0 * semi.y / float(nr) * 1.15
		for i in nr:
			var hf: float = (float(i) + 0.5) / float(nr)
			var rad: float = sqrt(maxf(0.0, 1.0 - pow(2.0 * hf - 1.0, 2.0))) * 0.95 + 0.08
			var mat: ShaderMaterial = _mat_kit({"erosion": 0.4, "brillo": 1.0, "calor_max": 0.9, "suave": 0.22, "escala_ruido": Vector2(5.0, 0.8),
				"velocidad": Vector2(0.55 + 0.1 * float(i), 0.7), "ondula": 0.05, "ondula_freq": 7.0, "fase": float(i) * 0.31, "fade": 0.0})
			var mi: MeshInstance3D = _malla_kit(VfxKit3D._cinta(1.0, TAU, alto_b, 48, false), mat)
			_anillos.append({"mi": mi, "y": 2.0 * semi.y * hf - alto_b * 0.5, "rad": rad, "vel": (3.2 - 1.6 * hf) * (1.0 if i % 2 == 0 else 0.8), "ang": rng.randf() * TAU, "incl": rng.randf_range(-0.12, 0.12)})
		_contorno = _elipsoide(cfg.material_burbuja(Color(col["c"]).lerp(Color(col["mota"]), 0.4)))
		_gp(Vector3(0.0, semi.y, 0.0), int(24 * DENSIDAD * 2.0), 1.6, 0.18, 0.5, false, 0.2, Vector3.UP, 180.0, Vector3(maxf(semi.x * 0.8, 0.1), maxf(semi.y * 0.8, 0.1), maxf(semi.z * 0.8, 0.1)))
		if viento:
			var nh: int = int(50 * DENSIDAD)
			var mh := StandardMaterial3D.new()
			mh.vertex_color_use_as_albedo = true
			mh.cull_mode = BaseMaterial3D.CULL_DISABLED
			mh.roughness = 0.8
			_mm_hojas = _mm(_solo_cuerpo(Formas3D.malla("hoja")), nh, mh)   # sin el contorno negro: en el aire una hoja con borde de tinta se lee como mugre, no como viento
			for n in nh:
				var p: Dictionary = _nueva_particula_gas()
				p["giro"] = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
				p["vgiro"] = Vector3(rng.randf_range(-4.0, 4.0), rng.randf_range(-4.0, 4.0), rng.randf_range(-6.0, 6.0))
				p["verde"] = Color(col["hondo"]).lerp(Color(col["c"]), rng.randf())
				_hojas.append(p)
		_act = _act_gas

	## La misma pieza de Formas3D sin su 2.ª superficie (el contorno de tinta); la 0 es el cuerpo teñible por color de instancia.
	func _solo_cuerpo(m: ArrayMesh) -> ArrayMesh:
		var r := ArrayMesh.new()
		r.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, m.surface_get_arrays(0))
		return r

	func _nueva_particula_gas() -> Dictionary:
		return {"ang": rng.randf() * TAU, "h": rng.randf_range(-1.0, 1.0), "rr": rng.randf_range(0.25, 1.0), "w": rng.randf_range(1.4, 3.0), "fase": rng.randf()}

	func _pos_gas(p: Dictionary) -> Vector3:
		var yn: float = fposmod(float(p["h"]) + t * 0.22 + 1.0, 2.0) - 1.0
		var ang: float = float(p["ang"]) + float(p["w"]) * t * (1.5 - 0.5 * (yn * 0.5 + 0.5))
		var rad: float = sqrt(maxf(0.0, 1.0 - yn * yn)) * float(p["rr"])
		return Vector3(cos(ang) * semi.x * rad, semi.y * (1.0 + yn), sin(ang) * semi.z * rad)

	func _act_gas(dt: float) -> void:
		var m: float = _media()
		if _contorno:
			_contorno.scale = semi * (0.7 + 0.3 * v)
			(_contorno.material_override as ShaderMaterial).set_shader_parameter("vida", v * 0.3)
		for a in _anillos:
			a["ang"] = float(a["ang"]) + float(a["vel"]) * dt
			var r: float = float(a["rad"]) * (0.8 + 0.2 * v)
			(a["mi"] as MeshInstance3D).transform = Transform3D(Basis(Vector3.RIGHT, float(a["incl"])) * Basis(Vector3.UP, float(a["ang"])) * Basis.from_scale(Vector3(semi.x * r, 1.0, semi.z * r)), Vector3(0.0, float(a["y"]), 0.0))
		for n in _hojas.size():
			var p: Dictionary = _hojas[n]
			var pos: Vector3 = _pos_gas(p)
			var giro: Vector3 = (p["giro"] as Vector3) + (p["vgiro"] as Vector3) * t
			var s: float = (0.4 + 0.12 * m) * v
			_mm_hojas.set_instance_transform(n, Transform3D(Basis.from_euler(giro).scaled(Vector3(s, s, s)), pos))
			_mm_hojas.set_instance_color(n, p["verde"])

	## ================================================================ CAMPO
	## La burbuja que distorsiona lo de detrás (firma del campo) con la cáscara del kit encima (borde brillante por fresnel, interior que se deshace:
	## el método de la cúpula), un aro de ruido en el suelo que late cada segundo, motas del kit y un charco de luz.
	var _burbuja: MeshInstance3D
	var _cascara: MeshInstance3D
	var _aro_campo: MeshInstance3D
	var _mat_aro_campo: ShaderMaterial

	func _ini_campo() -> void:
		_burbuja = _elipsoide(cfg.material_burbuja(Color(col["c"]).lerp(Color(col["mota"]), 0.4)))
		var mat: ShaderMaterial = _mat_kit({"cerrado": true, "eje": VfxKit3D.EJE_BORDE, "erosion": 0.42, "suave": 0.25, "brillo": 1.0, "calor_max": 0.85, "fresnel_pot": 2.0,
			"potencia": 0.8, "borde": 0.7, "escala_ruido": Vector2(3.0, 2.0), "velocidad": Vector2(0.06, 0.55), "fade": 0.0})
		_cascara = _malla_kit(VfxKit3D._esfera(1.0), mat, Transform3D(Basis.from_scale(semi), Vector3(0.0, semi.y, 0.0)))
		_mat_aro_campo = _mat_kit({"erosion": 0.4, "brillo": 1.0, "calor_max": 0.9, "suave": 0.2, "escala_ruido": Vector2(6.0, 0.6), "velocidad": Vector2(0.25, 1.2), "ondula": 0.04, "fade": 0.0}, false)
		_aro_campo = _malla_kit(VfxKit3D._cinta(1.0, TAU, 0.4, 64, false), _mat_aro_campo)
		_gp(Vector3(0.0, semi.y, 0.0), 12, 2.0, 0.14, 0.4, false, 0.1, Vector3.UP, 180.0, Vector3(maxf(semi.x * 0.8, 0.1), maxf(semi.y * 0.8, 0.1), maxf(semi.z * 0.8, 0.1)))
		if not proyectil:
			_ini_charcos(1.0)
		_act = _act_campo

	func _act_campo(_dt: float) -> void:
		var respiro: float = 1.0 + 0.015 * sin(t * 3.0)
		_burbuja.scale = semi * respiro * (0.7 + 0.3 * v)
		(_burbuja.material_override as ShaderMaterial).set_shader_parameter("vida", v)
		_cascara.scale = semi * respiro * (0.7 + 0.3 * v)
		var onda: float = fposmod(t, 1.0)
		_aro_campo.transform = Transform3D(Basis.from_scale(Vector3(semi.x * (0.9 + 0.2 * onda), 1.0, semi.z * (0.9 + 0.2 * onda))), Vector3(0.0, 0.06, 0.0))
		_mat_aro_campo.set_shader_parameter("fade", v * (1.0 - onda))
		_luz_charcos(v)

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
		# viaja = estela del kit: la cola de cometa de la bola de fuego (tres conos de llama hacia atrás), a la medida del volumen y con la rampa de su elemento.
		if _viaja:
			var r_c: float = maxf(semi.x, semi.y) * 0.9
			var largo_c: float = semi.z + cfg.casilla * 1.6
			for cc in [[0.0, 1.0, 0.0], [0.5, 0.7, 1.0], [-0.5, 0.7, -1.0]]:
				var kk: float = float(cc[1])
				var mat_c: ShaderMaterial = _mat_kit({"cerrado": true, "erosion": 0.36, "brillo": 1.05, "calor_max": 0.85, "peso_ruido": 0.5, "ondula": 0.05, "ondula_freq": 9.0,
					"escala_ruido": Vector2(0.9, 0.5), "velocidad": Vector2(0.0, 2.0), "fase": float(cc[2]) * 0.37, "fade": 0.0})
				mat_c.render_priority = -1
				# La punta del cono (+Y) mira hacia atrás (−Z): Basis(X, −90°).
				_malla_kit(VfxKit3D._cono(r_c * kk, largo_c * kk), mat_c, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(float(cc[0]) * r_c * 0.4, semi.y, -(semi.z + largo_c * kk * 0.5))))
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
					mi.transform = Transform3D(Basis(der, Vector3.UP, d).scaled_local(semi), (k["p"] as Vector3) + d * _adelanto() * cfg.casilla + Vector3(0.0, semi.y + _elev, 0.0))
					mi.visible = false
					var t1: float = _fin_comun if _fin_comun >= 0.0 else float(k["t"]) + _pers   # §0.3: lo que viaja deja sus tandas hasta llegar (+ permanencia)
					_huellas.append({"t0": float(sig["t"]), "t1": minf(t1, vida - muere), "mi": mi})
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
			var frente: Vector3 = (a["p"] as Vector3) + (a["d"] as Vector3) * (_adelanto() + float(g.get("z", 0.5))) * cfg.casilla + Vector3(0.0, 0.1 + _elev, 0.0)
			_rebotes.append({"t": (float(a["t"]) + float(b["t"])) * 0.5, "punto": frente, "sp": sp, "aro": aro, "dirs": dirs})
		# solidez = borde duro: cáscara brillante y apretada alrededor del volumen.
		if float(props.get("solidez", 0.0)) > 0.0 and not sobre_celdas:
			_escudo = _elipsoide(cfg.material_cascara(Color(col["mota"]).lerp(Color.WHITE, 0.4), 4.5, 0.03, 2.0), Vector3(1.04, 1.04, 1.04))

	func _act_firmas(dt: float) -> void:
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
