class_name Hierba3D
extends Node3D

## HIERBA CON VOLUMEN sobre el suelo pintado: matojos de briznas (3D de verdad, se mecen con el viento)
## y florecitas sueltas, todo en MultiMesh (miles de copias en una sola llamada de dibujo).
## En BLOQUES de `lado_bloque` (docs/HIERBA_OPTIMIZACION.md): cada bloque tiene sus MultiMesh y su caja, así que
## Godot no dibuja los que quedan fuera de cámara; y con `actualizar(pos)` solo existen los de alrededor del
## jugador (se crean al acercarse, uno por fotograma, y se liberan al alejarse; con la misma semilla salen iguales).
## Antes: un MultiMesh para todo el mapa (~40 000 matojos dibujados siempre). Sin sombras.
##
## Uso:
##   var h := Hierba3D.new()
##   add_child(h)
##   h.sembrar(Rect2(x0, z0, ancho, fondo), altura_del_suelo, func(x, z): return peso_de_hierba)
## `peso` devuelve 0..1: 1 = hierba plena, 0 = nada (camino, piedra). En los bordes (0,3-0,7) los matojos
## salen más altos y juntos: es lo que dibuja el borde ondulado entre hierba y camino.
##
## Dos capas, que se pueden ver juntas o por separado (`set_modo`):
##   briznas  matojos 3D de color liso, hechos por código (muchos y pequeños)
##   tarjetas matojos PINTADOS (suelo_meshy/hierba_matojos.png, 2 x 2 dibujos) que miran a la cámara

## Densidad y tamaño de bloque bajados el 6/10 (Pipeline): a zoom 6 se ven ~11x7 u y se generaban 25 bloques de 9,2 u
## (~2.100 u2) con 10 matojos/u2 x 9 briznas = ~5,7 M de triángulos y un tirón de CPU (8.460 matojos por bloque nuevo).
## Ahora 3,5 matojos/u2 x 5 briznas (más anchas, para que la mata siga tapando) y bloques de 4,6 u: ~5x menos triángulos,
## el recorte por bloque es más fino y cada bloque nuevo cuesta ~1/10. El volumen lo ponen las tarjetas pintadas.
@export var densidad: float = 5.0           ## matojos por unidad cuadrada en hierba plena
@export var flores_por_unidad: float = 0.18
@export var alto_matojo: float = 0.30      ## la chibi mide ~1
## 16/10 (Pipeline, diario 96): el verde de la hierba y el de la textura del suelo chocaban (foto de Pablo). MEDIDO sobre las texturas de
## suelo_meshy (media sobre píxeles opacos): el suelo (`hierba_arriba.png`) es (0,63 · 0,82 · 0,51), tono 97°; las tarjetas pintadas
## (`hierba_matojos.png`) son (0,58 · 0,71 · 0,37), tono 82°, más amarillas y oscuras; las briznas de antes (base 0,50/0,72/0,40 → punta
## 0,86/0,96/0,62) salían entre 78° y 101°. Ahora las briznas van del 97° del suelo, un poco más oscuras en la raíz y más claras en la punta, y las
## tarjetas llevan un tinte (`tinte_tarjetas`) que las acerca al tono del suelo sin aplanarlas.
## 16/10 (Pipeline, diario 100, Fase 14.2 c): MEDIDO EN PANTALLA (Bosque, capturas del sandbox, tono medio de los píxeles de mata frente al de los
## de suelo sin mata) el tinte de arriba (1,06 · 1,12 · 1,28, calculado sobre las TEXTURAS) dejaba las matas en 120° contra un suelo que
## se ve a 86°: la luz recorta el canal verde del suelo (llega a 1,0) y lo amarillea 11° respecto a su textura (97°), cosa que el cálculo
## sobre texturas no ve. Con (1,14 · 1,12 · 1,12) salen 110° y con (1,20 · 1,12 · 1,00) 102°: se queda este último, a medio camino entre el
## suelo que se ve hoy (86°) y el que se vería sin recorte (93–97°; con OSCURECER_SUELO 0,64 medí 93°). Si algún día baja la exposición del
## suelo, estas matas quedan más cerca de él, no más lejos.
@export var color_base: Color = Color(0.58, 0.77, 0.45)
@export var color_punta: Color = Color(0.76, 0.93, 0.63)
@export var tinte_tarjetas: Color = Color(1.20, 1.12, 1.00)
@export var viento: float = 1.0
@export var semilla: int = 7
@export var modo: int = 2                    ## 0 briznas · 1 tarjetas pintadas · 2 las dos
@export var densidad_tarjetas: float = 5.5   ## matojos pintados por unidad cuadrada
@export var alto_tarjeta: float = 0.55
@export var atlas_tarjetas: String = "res://arte/suelo_meshy/hierba_matojos.png"
@export var lado_bloque: float = 4.6         ## lado de cada bloque, en unidades (2 casillas de la maqueta)
@export var radio_sembrar: int = 2           ## con actualizar(): bloques alrededor del jugador que se siembran
@export var radio_liberar: int = 4           ## ... y a partir de cuántos se liberan
@export var bloques_por_fotograma: int = 2   ## como mucho, para repartir el coste al andar (bloques pequeños: 2 cuestan menos que 1 de los viejos)
@export var brillo: float = 1.0              ## multiplica el color (la maqueta oscurece el suelo y la hierba igual)
@export var albedos_eow: bool = true         ## albedos (22/10, `Albedos3D`): valor de las briznas y contraste/valor de las tarjetas igualados con el suelo; false = como antes (se pone antes de sembrar)
## 6/11 (Pablo: «una hierba más procedural… en vez de esparcir, pequeños bloques»): cada matojo sale distinto (alto, ancho, inclinación, tono y fase del balanceo propios,
## entre `TOPES.variantes` mallas de matojo) y la siembra se agrupa (`AGRUPADO`: casillas calvas y densidad por ruido). false = la hierba de antes (una malla, escala
## uniforme, reparto parejo): lo usan las capturas antes/después. Se pone antes de `sembrar`.
@export var procedural: bool = true
@export var casilla: float = 2.3             ## lado de una casilla del mapa: la SEMILLA de la siembra es por casilla (`hash(semilla, cx, cz)`), así dos siembras (y dos horneados) dan lo mismo

## TOPES por bloque (GPU integrada; 19 mapas con cientos de piezas). Si una casilla pide más, se ralea a partes iguales (`_ralear`): nunca se pasa.
## Triángulos: un matojo son `briznas × 3` (cada brizna 2 tramos = 3 triángulos); una tarjeta o una flor, 2. A tope: 220 × 18 + 220 × 2 + 40 × 2 ≈ 4,5 k por bloque,
## ×25 bloques visibles ≈ 112 k (docs/HIERBA_OPTIMIZACION.md pedía < 150 k).
const TOPES: Dictionary = {
	"matojos_por_bloque": 220,
	"tarjetas_por_bloque": 220,
	"flores_por_bloque": 40,
	"triangulos_por_bloque": 5000,
	"variantes": 3,                 ## mallas de matojo distintas (4, 5 y 6 briznas, cada una con su curva); con `procedural` false, solo la de siempre
}
## AGRUPADO: lo que rompe la planicie DENTRO de las matas (el campo de matas con claros lo da quien siembra: `_mata_hierba` de la maqueta).
const AGRUPADO: Dictionary = {
	"p_calva": 0.14,                ## probabilidad de que una casilla de hierba salga CALVA (sin matojos ni tarjetas ni flores): huecos entre corros
	"tam_densidad": 3.1,            ## tamaño (u) del ruido de densidad: dentro de una mata, unas zonas más tupidas que otras
	"densidad_min": 0.45,           ## fracción de la rejilla que sobrevive donde el ruido de densidad vale 0 (en 1 sobrevive todo)
	"rejilla_x": 1.3,               ## la rejilla de briznas y tarjetas es 1,3× más tupida: las calvas y el ruido quitan ≈ un tercio, así el presupuesto de copias queda como antes, pero en corros
	"alto_min": 0.60,               ## alto de un matojo: alto_matojo × [alto_min, alto_max] (antes 0,75–1,25)
	"alto_max": 1.45,
	"ancho_min": 0.75,              ## ancho (escala XZ) relativo al alto: [ancho_min, ancho_max]
	"ancho_max": 1.25,
	"inclinacion_max": 0.38,        ## rad: cada matojo se tumba un poco hacia un lado al azar
	"tono": 0.07,                   ## desvío del tinte hacia amarillo (+) o azulado (−), dentro de la paleta: Color(v·(1+a), v, v·(1−a/2))
}

## W2 (2/11, docs/REVISION_GAMEFEEL_30-10.md §11): la hierba se aparta con muelle. Lo afinable; lo alimenta `Caminar3D.actualizar` cada fotograma con `set_apartado`.
static var APARTAR_FUERZA: float = 0.3            ## inclinación de las puntas al apartarse (las tarjetas, ×0,83: 0,25 como siempre)
static var APARTAR_RADIO: float = 0.9             ## u andando…
static var APARTAR_RADIO_CORRER: float = 1.2      ## …y corriendo
static var APARTAR_RADIO_BASE: float = 0.7        ## el de antes de W2 (sin `Sensacion3D.ACTIVA`)
static var APARTAR_RETORNO_S: float = 0.6         ## s que tarda en volver con rebote al salir ella del radio

const NOMBRES_MODO: Array = ["briznas", "tarjetas pintadas", "briznas + tarjetas"]

const COLORES_FLOR: Array = [Color(1.0, 0.78, 0.86), Color(1.0, 1.0, 0.96), Color(1.0, 0.93, 0.55),
	Color(0.80, 0.78, 1.0), Color(1.0, 0.70, 0.62)]

const CODIGO_MATOJO: String = """
shader_type spatial;
render_mode cull_disabled, shadows_disabled;
uniform vec3 base : source_color = vec3(0.58, 0.77, 0.45);
uniform vec3 punta : source_color = vec3(0.76, 0.93, 0.63);
uniform float viento = 1.0;
uniform float brillo = 1.0;
uniform vec2 alb_hierba = vec2(1.0);     // albedos: (K, VALOR) de Albedos3D; (1, 1) = como antes
uniform sampler2D estado : hint_default_black, filter_linear, repeat_disable;     // estado oficial del suelo (Mundo3D.textura_estados()): aquí solo R quemado
uniform sampler2D pisado : hint_default_black, filter_linear, repeat_disable;     // R: hierba aplastada (solo aspecto; la escribe la maqueta, no es estado de juego)
uniform sampler2D crecida : hint_default_black, filter_linear, repeat_disable;    // R: 1 = hierba crecida (alta y tupida)
uniform sampler2D humedad : hint_default_black, filter_linear, repeat_disable;    // R mojada · G escarcha (solo aspecto, `Hierba3D.mojar/escarchar`)
uniform float celda = 2.3;
uniform float lado = 40.0;
uniform vec3 posicion_jugador = vec3(-1000.0, 0.0, -1000.0);
uniform float radio_pisar = 0.7;
uniform float fuerza_apartar = 0.3;      // W2: cuánto se inclina una punta al apartarse (`Hierba3D.APARTAR_FUERZA`)
uniform vec4 rast1 = vec4(0.0);          // W2: rastro de la jugadora (xyz = dónde estuvo, w = peso del muelle; 0 = nada)
uniform vec4 rast2 = vec4(0.0);
uniform vec4 rast3 = vec4(0.0);
uniform vec4 rast4 = vec4(0.0);
uniform vec4 rast5 = vec4(0.0);
uniform vec2 empuje = vec2(0.0);         // W2: velocidad de la jugadora sobre el suelo / velocidad de correr (arrastra las puntas)
vec2 apartar_de(vec2 o, vec2 p, float peso) {
	vec2 d = o - p;
	return normalize(d + vec2(0.001, 0.0)) * (1.0 - smoothstep(0.0, radio_pisar, length(d))) * peso;
}
varying float alto;
varying vec3 tinte;
varying float quemado;
varying float mojado;
varying float escarcha;
void vertex() {
	alto = UV.y;
	tinte = INSTANCE_CUSTOM.rgb;
	vec3 origen = MODEL_MATRIX[3].xyz;
	vec2 uv_e = origen.xz / (celda * lado);
	vec4 e = texture(estado, uv_e);
	quemado = e.r;
	// Mojada y escarcha: lo que pinta la maqueta o, cuando llegue, el estado oficial (G mojada, B helada): manda el mayor.
	vec2 hu = texture(humedad, uv_e).rg;
	mojado = max(hu.r, e.g);
	escarcha = max(hu.g, e.b);
	// Quemada: se queda en un cuarto de alto. Crecida (el agua la hace brotar): el doble de alta. Mojada: algo lacia.
	float cre = texture(crecida, uv_e).r;
	VERTEX.y *= mix(1.0, 0.12, smoothstep(0.2, 0.8, e.r)) * mix(1.0, 1.7, cre) * mix(1.0, 0.85, mojado);   // 6.14: quemada = rastrojo muy corto
	vec3 mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// INSTANCE_CUSTOM.a = fase propia del matojo (0..1; 1 = la de siempre): dos matojos vecinos no se mecen a la vez.
	float t = TIME * 1.7 + mundo.x * 0.55 + mundo.z * 0.35 + INSTANCE_CUSTOM.a * 6.2832;
	// Mojada pesa y se mueve menos; con escarcha está tiesa.
	float rigidez = mix(1.0, 0.6, mojado) * (1.0 - 0.85 * escarcha);
	float meneo = (sin(t) * 0.6 + sin(t * 2.3 + 1.7) * 0.25) * viento * alto * alto * rigidez;
	float inv_x = 1.0 / max(length(MODEL_MATRIX[0].xyz), 0.001);
	float inv_z = 1.0 / max(length(MODEL_MATRIX[2].xyz), 0.001);
	VERTEX.x += meneo * 0.05 * inv_x;
	VERTEX.z += meneo * 0.025 * inv_z;
	// Pisada por celda (solo aspecto): se tumba hacia +x+z.
	float tumbar = texture(pisado, uv_e).r * alto * alto;
	VERTEX.x += tumbar * 0.18 * inv_x;
	VERTEX.z += tumbar * 0.10 * inv_z;
	// Se aparta de la chibi en radial (W2, 2/11: y con muelle. El rastro `rast1..5` son los puntos donde estuvo (peso 1 mientras estaba dentro del radio; al salir,
	// seno amortiguado 0,6 s que pasa un poco al otro lado), y `empuje` arrastra las puntas en el sentido de la marcha). Sin rastro ni empuje es el apartado de siempre.
	vec2 ap = apartar_de(origen.xz, posicion_jugador.xz, 1.0) + apartar_de(origen.xz, rast1.xz, rast1.w) + apartar_de(origen.xz, rast2.xz, rast2.w)
			+ apartar_de(origen.xz, rast3.xz, rast3.w) + apartar_de(origen.xz, rast4.xz, rast4.w) + apartar_de(origen.xz, rast5.xz, rast5.w);
	float am = length(ap);
	ap *= min(am, 1.0) / max(am, 0.0001);
	ap += empuje * 0.5 * min(am, 1.0);
	vec2 apartar = ap * alto * alto * fuerza_apartar * (1.0 - 0.7 * escarcha);
	VERTEX.x += apartar.x * inv_x;
	VERTEX.z += apartar.y * inv_z;
}
void fragment() {
	// La normal se fija aquí (no en vertex) porque con cull_disabled la cara de atrás la invertiría.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	vec3 c = mix(base, punta, smoothstep(0.0, 1.0, alto));
	vec3 media_b = 0.5 * (base + punta);
	c = (media_b + (c - media_b) * alb_hierba.x) * alb_hierba.y;     // albedos
	c = mix(c, vec3(0.55, 0.49, 0.30), quemado * 0.7);   // 6.14: rastrojo pajizo, no negro
	c *= mix(1.0, 0.6, mojado);                                                   // mojada: más oscura (EoW: −30 a −40 %)
	c = mix(c, vec3(0.80, 0.88, 0.94), escarcha * mix(0.2, 0.6, alto));          // escarcha: blanco azulado, más en las puntas (sin llegar a nieve)
	ALBEDO = c * tinte * brillo;
	ROUGHNESS = mix(1.0, 0.45, max(mojado, escarcha * 0.8));
	SPECULAR = max(mojado * 0.35, escarcha * 0.4);                              // un brillo: mojada y escarcha reflejan algo de luz
}
"""

## Tarjeta pintada: un cuadrado que mira siempre a la cámara, apoyado por abajo en el suelo, con uno de los
## cuatro dibujos del atlas (INSTANCE_CUSTOM.a) y la punta meciéndose con el viento.
const CODIGO_TARJETA: String = """
shader_type spatial;
render_mode cull_disabled, shadows_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform float viento = 1.0;
uniform float brillo = 1.0;
uniform vec2 alb_hierba = vec2(1.0);     // albedos: (K, VALOR) de Albedos3D; (1, 1) = como antes
uniform vec3 alb_media = vec3(0.3);      // albedos: media lineal del atlas (por alfa), calculada al crear el material
uniform sampler2D estado : hint_default_black, filter_linear, repeat_disable;
uniform sampler2D pisado : hint_default_black, filter_linear, repeat_disable;
uniform sampler2D crecida : hint_default_black, filter_linear, repeat_disable;
uniform sampler2D humedad : hint_default_black, filter_linear, repeat_disable;    // R mojada · G escarcha (solo aspecto)
uniform float celda = 2.3;
uniform float lado = 40.0;
uniform vec3 posicion_jugador = vec3(-1000.0, 0.0, -1000.0);
uniform float radio_pisar = 0.7;
uniform float fuerza_apartar = 0.25;     // W2 (como en las briznas): inclinación de las tarjetas al apartarse
uniform vec4 rast1 = vec4(0.0);
uniform vec4 rast2 = vec4(0.0);
uniform vec4 rast3 = vec4(0.0);
uniform vec4 rast4 = vec4(0.0);
uniform vec4 rast5 = vec4(0.0);
uniform vec2 empuje = vec2(0.0);
vec2 apartar_de(vec2 o, vec2 p, float peso) {
	vec2 d = o - p;
	return normalize(d + vec2(0.001, 0.0)) * (1.0 - smoothstep(0.0, radio_pisar, length(d))) * peso;
}
varying vec3 tinte;
varying float quemado;
varying float mojado;
varying float escarcha;
varying float alto_v;
void vertex() {
	tinte = INSTANCE_CUSTOM.rgb;
	float fila = floor(INSTANCE_CUSTOM.a * 3.99);
	float alto = 1.0 - UV.y;
	alto_v = alto;
	UV = (UV + vec2(mod(fila, 2.0), floor(fila / 2.0))) * 0.5;
	vec3 origen = MODEL_MATRIX[3].xyz;
	vec2 uv_e = origen.xz / (celda * lado);
	vec4 e = texture(estado, uv_e);
	quemado = e.r;
	vec2 hu = texture(humedad, uv_e).rg;
	mojado = max(hu.r, e.g);
	escarcha = max(hu.g, e.b);
	float cre = texture(crecida, uv_e).r;
	float escala_y = mix(1.0, 0.1, smoothstep(0.2, 0.8, e.r)) * mix(1.0, 1.6, cre) * mix(1.0, 0.85, mojado);   // 6.14
	vec3 der = normalize(INV_VIEW_MATRIX[0].xyz);
	// W2 (2/11): el apartado de la tarjeta es el mismo de las briznas (radial, con el rastro de muelle y el arrastre de la marcha), proyectado sobre el eje de la pantalla en que se inclina.
	vec2 ap = apartar_de(origen.xz, posicion_jugador.xz, 1.0) + apartar_de(origen.xz, rast1.xz, rast1.w) + apartar_de(origen.xz, rast2.xz, rast2.w)
			+ apartar_de(origen.xz, rast3.xz, rast3.w) + apartar_de(origen.xz, rast4.xz, rast4.w) + apartar_de(origen.xz, rast5.xz, rast5.w);
	float am = length(ap);
	ap *= min(am, 1.0) / max(am, 0.0001);
	ap += empuje * 0.5 * min(am, 1.0);
	float cerca = dot(ap, normalize(der.xz + vec2(0.0001, 0.0))) * (1.0 - 0.7 * escarcha);     // con escarcha apenas se aparta
	float tumbar = (texture(pisado, uv_e).r + cerca) * alto * alto * fuerza_apartar;
	float esc = length(MODEL_MATRIX[0].xyz);
	vec3 arr = normalize(INV_VIEW_MATRIX[1].xyz);
	float t = TIME * 1.7 + origen.x * 0.55 + origen.z * 0.35;
	float rigidez = mix(1.0, 0.6, mojado) * (1.0 - 0.85 * escarcha);
	float meneo = (sin(t) * 0.6 + sin(t * 2.3 + 1.7) * 0.25) * viento * alto * alto * 0.12 * rigidez;
	vec3 mundo = origen + (der * (VERTEX.x + meneo + tumbar) + arr * VERTEX.y * escala_y) * esc;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(mundo, 1.0)).xyz;
}
void fragment() {
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	vec4 c = texture(atlas, UV);
	if (c.a < 0.5) {
		discard;
	}
	vec3 rgb = (alb_media + (c.rgb - alb_media) * alb_hierba.x) * alb_hierba.y;     // albedos: compresión hacia la media del atlas + valor
	vec3 col = mix(rgb * tinte, vec3(0.55, 0.49, 0.30), quemado * 0.7);   // 6.14: pajizo, no negro
	col *= mix(1.0, 0.6, mojado);                                                // mojada: más oscura
	col = mix(col, vec3(0.80, 0.88, 0.94), escarcha * mix(0.2, 0.6, alto_v));    // escarcha: más en las puntas (sin llegar a nieve)
	ALBEDO = col * brillo;
	ROUGHNESS = mix(1.0, 0.45, max(mojado, escarcha * 0.8));
	SPECULAR = max(mojado * 0.35, escarcha * 0.4);
}
"""

const CODIGO_FLOR: String = """
shader_type spatial;
render_mode cull_disabled, shadows_disabled;
uniform sampler2D forma : filter_linear_mipmap;
uniform float brillo = 1.0;
varying vec3 tinte;
void vertex() {
	tinte = INSTANCE_CUSTOM.rgb;
}
void fragment() {
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	vec4 f = texture(forma, UV);
	if (f.a < 0.5) {
		discard;
	}
	ALBEDO = (f.r * tinte + f.g * vec3(1.0, 0.82, 0.30)) * brillo;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""

## true = los matojos, las tarjetas y las flores reciben la sombra del sol; false = como siempre, sin sombra (más barato). Afinable en caliente (panel F3).
static var RECIBE_SOMBRA: bool = false
var _mat_matojo: ShaderMaterial = null
var _mat_tarjeta: ShaderMaterial = null
var _mat_flor: ShaderMaterial = null
var _img_crecida: Image = null
var _tex_crecida: ImageTexture = null
var _crecida_sucia: bool = false
## Bloque 1 EoW: hierba MOJADA y con ESCARCHA (solo aspecto). Las casillas de hierba no reciben el estado oficial del suelo (ReaccionesSuelo3D
## solo actúa en las de clase «suelo»), así que la maqueta avisa aquí al regarla o helarla. RG8, una casilla por píxel; se seca sola.
## El shader se queda con el mayor de esto y del estado oficial (G mojada, B helada): si algún día la hierba pasa a EstadosSuelo3D, ya se ve.
const MOJADA_S: float = 8.0          ## s que se ve mojada del todo (= `PruebaTest2.T_MOJADA_MS`, lo que tarda en poder prender otra vez)
const ESCARCHA_S: float = EstadosSuelo3D.DURA["helada"]       ## s con escarcha: la duración del reloj oficial del hielo (C2, 3/11; antes un 20 propio); al fundirse queda mojada. Solo aspecto: la hierba no entra en `EstadosSuelo3D`
const FUNDIDO_S: float = 2.5         ## s que tarda en desvanecerse al acabar
var _img_humedad: Image = null
var _tex_humedad: ImageTexture = null
var _humedad: Dictionary = {}        ## Vector2i -> [mojada_hasta, escarcha_hasta, intensidad] (en segundos de `_reloj`)
var _reloj: float = 0.0
var _malla: ArrayMesh = null
var _mallas: Array[ArrayMesh] = []         ## variantes de matojo (`TOPES.variantes`; la 0 es `_malla`, la de siempre)
var _tris_variante: PackedInt32Array = PackedInt32Array()     ## triángulos de cada variante
var _stats: Dictionary = {}                ## Vector2i bloque -> {matojos, tarjetas, flores, triangulos, casillas: {Vector2i: matojos}, huella: int}: lo que se midió al crearlo (vale en headless)
var _quad_tarjeta: QuadMesh = null
var _quad_flor: QuadMesh = null
var _zona: Rect2 = Rect2()
var _y: float = 0.0
var _peso: Callable
var _bloques: Dictionary = {}              ## Vector2i -> Node3D con los MultiMesh del bloque (briznas, tarjetas, flores)
var _pendientes: Array[Vector2i] = []
var _centro: Vector2i = Vector2i(999999, 999999)


## Prepara materiales y mallas (una vez) y siembra. Con `alrededor = true` NO siembra nada todavía: los bloques
## salen con `actualizar(posición del jugador)` y se liberan al alejarse (docs/HIERBA_OPTIMIZACION.md §2.2).
## Con false siembra el mapa entero, igualmente en bloques (laboratorio de VFX, prerender del Test 2D).
## 9.6: multiplicador de altura por punto del mundo (x, z) → 0..1, opcional. La hierba corta decorativa (`,`) sale más baja.
var _alto: Callable = Callable()

## 5/11 (Pablo, playtest del Bosque 02: «en acumulaciones más densas»): campo de MATAS opcional (x, z) → 0..1. Con él, la hierba no se reparte pareja: en el
## centro de cada mancha la rejilla es `MATA_MULT_DENSIDAD` veces más tupida y las briznas salen algo más altas; hacia el borde se aclara hasta
## `CLARO_DENSIDAD` (un claro casi limpio). Sin él (vacío) la siembra es la de siempre, así que los laboratorios y el Test 2D no cambian.
var _matas: Callable = Callable()
const MATA_MULT_DENSIDAD: float = 1.7     ## la rejilla de briznas/tarjetas es 1,7× más tupida que `densidad`/`densidad_tarjetas` (se queda en 1 ud de paso por brizna de ≈0,44)
const CLARO_DENSIDAD: float = 0.05        ## fracción de la rejilla densa que sobrevive en pleno claro (matas = 0): ≈ 0,085 × la densidad de siempre
const MATA_ALTURA_CLARO: float = 0.80     ## multiplicador de altura de las briznas en el claro...
const MATA_ALTURA_CENTRO: float = 1.30    ## ... y en el corazón de la mancha (se interpola con el valor de la mata)


func sembrar(zona: Rect2, y: float, peso: Callable, alrededor: bool = false, alto: Callable = Callable(), matas: Callable = Callable()) -> void:
	_zona = zona
	_y = y
	_peso = peso
	_alto = alto
	_matas = matas
	_preparar()
	if not alrededor:
		for bz in range(ceili(zona.size.y / lado_bloque)):
			for bx in range(ceili(zona.size.x / lado_bloque)):
				_crear_bloque(Vector2i(bx, bz))
		set_modo(modo)


## Llamar a menudo (cada fotograma vale: solo trabaja al cambiar de bloque) con la posición del jugador.
## Encola los bloques que faltan en `radio_sembrar` (del más cercano al más lejano), libera los que pasan de
## `radio_liberar` y crea como mucho `bloques_por_fotograma`, para repartir el coste al andar.
func actualizar(pos: Vector3, todos: bool = false) -> void:
	var c := Vector2i(floori((pos.x - _zona.position.x) / lado_bloque), floori((pos.z - _zona.position.y) / lado_bloque))
	if c != _centro:
		_centro = c
		_pendientes.clear()
		for dz in range(-radio_sembrar, radio_sembrar + 1):
			for dx in range(-radio_sembrar, radio_sembrar + 1):
				var b := c + Vector2i(dx, dz)
				if _dentro(b) and not _bloques.has(b):
					_pendientes.append(b)
		_pendientes.sort_custom(func(a: Vector2i, b2: Vector2i) -> bool:
			return (a - c).length_squared() < (b2 - c).length_squared())
		for b in _bloques.keys():
			if ((b as Vector2i) - c).length_squared() > radio_liberar * radio_liberar:
				(_bloques[b] as Node3D).queue_free()
				_bloques.erase(b)
				_stats.erase(b)
	var n: int = 0
	while (todos or n < bloques_por_fotograma) and not _pendientes.is_empty():
		_crear_bloque(_pendientes.pop_front())
		n += 1


## Cambia el radio (p. ej. al alejar la cámara) y vuelve a mirar qué falta en el próximo actualizar().
func set_radio(r: int) -> void:
	if r == radio_sembrar:
		return
	radio_sembrar = r
	radio_liberar = r + 2
	_centro = Vector2i(999999, 999999)


func _dentro(b: Vector2i) -> bool:
	return b.x >= 0 and b.y >= 0 and float(b.x) * lado_bloque < _zona.size.x and float(b.y) * lado_bloque < _zona.size.y


## El código del shader según `RECIBE_SOMBRA`: igual que `base` (sin sombra) o sin el `shadows_disabled` del render_mode.
static func _codigo(base: String) -> String:
	return base.replace(", shadows_disabled", "") if RECIBE_SOMBRA else base


## Cambia `RECIBE_SOMBRA` y reescribe el código de los tres materiales ya creados (todos los bloques los comparten), para verlo en caliente.
func poner_recibe_sombra(v: bool) -> void:
	RECIBE_SOMBRA = v
	var pares: Array = [[_mat_matojo, CODIGO_MATOJO], [_mat_tarjeta, CODIGO_TARJETA], [_mat_flor, CODIGO_FLOR]]
	for p in pares:
		var m: ShaderMaterial = p[0] as ShaderMaterial
		if m != null and m.shader != null:
			m.shader.code = _codigo(String(p[1]))


func _preparar() -> void:
	if _malla != null:
		return
	_mat_matojo = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = _codigo(CODIGO_MATOJO)
	_mat_matojo.shader = sh
	_mat_matojo.set_shader_parameter("base", color_base)
	_mat_matojo.set_shader_parameter("punta", color_punta)
	_mat_matojo.set_shader_parameter("viento", viento)
	_mat_matojo.set_shader_parameter("brillo", brillo)
	_mallas.clear()
	_tris_variante.clear()
	var formas: Array = [[99, 5, 0.7, 0.5], [131, 4, 0.85, 0.5], [173, 6, 0.55, 0.45]]     # [semilla, briznas, alto base, alto extra]: la 0 es la de siempre
	for i in range(int(TOPES["variantes"]) if procedural else 1):
		var f: Array = formas[i % formas.size()]
		var m: ArrayMesh = _malla_matojo(int(f[0]), int(f[1]), float(f[2]), float(f[3]))
		m.surface_set_material(0, _mat_matojo)
		_mallas.append(m)
		_tris_variante.append(int(f[1]) * 3)
	_malla = _mallas[0]
	if ResourceLoader.exists(atlas_tarjetas):
		_mat_tarjeta = ShaderMaterial.new()
		var sht := Shader.new()
		sht.code = _codigo(CODIGO_TARJETA)
		_mat_tarjeta.shader = sht
		_mat_tarjeta.set_shader_parameter("atlas", load(atlas_tarjetas) as Texture2D)
		_mat_tarjeta.set_shader_parameter("viento", viento)
		_mat_tarjeta.set_shader_parameter("brillo", brillo)
		_quad_tarjeta = QuadMesh.new()
		_quad_tarjeta.size = Vector2(1.0, 1.0)
		_quad_tarjeta.center_offset = Vector3(0.0, 0.5, 0.0)
		_quad_tarjeta.material = _mat_tarjeta
	_mat_flor = ShaderMaterial.new()
	var shf := Shader.new()
	shf.code = _codigo(CODIGO_FLOR)
	_mat_flor.shader = shf
	_mat_flor.set_shader_parameter("forma", _textura_flor())
	_mat_flor.set_shader_parameter("brillo", brillo)
	_quad_flor = QuadMesh.new()
	_quad_flor.size = Vector2(1.0, 1.0)
	_quad_flor.orientation = PlaneMesh.FACE_Y
	_quad_flor.material = _mat_flor
	Albedos3D.aplicar_hierba(_mat_matojo, _mat_tarjeta, (load(atlas_tarjetas) as Texture2D) if _mat_tarjeta != null else null, albedos_eow)


## Un bloque: briznas, tarjetas y flores de su rectángulo, con semilla propia (sale igual si se vuelve a crear).
func _crear_bloque(b: Vector2i) -> void:
	var rect := Rect2(_zona.position + Vector2(b) * lado_bloque, Vector2(lado_bloque, lado_bloque)).intersection(_zona)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var padre := Node3D.new()
	padre.name = "Bloque_%d_%d" % [b.x, b.y]
	add_child(padre)
	_bloques[b] = padre
	# 6/11: la siembra va CASILLA a casilla con semilla propia (`hash(semilla, cx, cz)`): el bloque solo recorta. Así una casilla sale igual en cualquier bloque,
	# en cualquier siembra y en cualquier horneado, y `rehacer_bloque_en` deja donde estaban las matas que ya había.
	# (arrays normales, no Packed: se comparten por referencia entre `_sembrar_casilla` y `_ralear`; se empaquetan al final)
	var acc: Dictionary = {"matojos": [], "tintes_m": [], "variante": [], "tarjetas": [], "tintes_t": [], "flores": [], "tintes_f": [],
		"casillas": {}, "huella": 0}
	var c0 := Vector2i(floori(rect.position.x / casilla + 0.001), floori(rect.position.y / casilla + 0.001))
	var c1 := Vector2i(ceili(rect.end.x / casilla - 0.001) - 1, ceili(rect.end.y / casilla - 0.001) - 1)
	for cz in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			_sembrar_casilla(Vector2i(cx, cz), rect, acc)
	# Topes: se ralea a partes iguales, nunca se corta por un lado del bloque.
	var n_m: int = _ralear([acc["matojos"], acc["tintes_m"], acc["variante"]], int(TOPES["matojos_por_bloque"]))
	var n_t: int = _ralear([acc["tarjetas"], acc["tintes_t"]], int(TOPES["tarjetas_por_bloque"]))
	var n_f: int = _ralear([acc["flores"], acc["tintes_f"]], int(TOPES["flores_por_bloque"]))
	var variante: Array = acc["variante"]
	var tris: int = _triangulos(variante, n_t, n_f)
	if tris > int(TOPES["triangulos_por_bloque"]):
		# Demasiados triángulos aun dentro de los topes de copias (todo matojos de 6 briznas, p. ej.): se ralean los matojos hasta entrar.
		var sobra: float = float(tris - int(TOPES["triangulos_por_bloque"]))
		var media: float = float(tris - n_t * 2 - n_f * 2) / maxf(float(n_m), 1.0)
		n_m = _ralear([acc["matojos"], acc["tintes_m"], acc["variante"]], maxi(n_m - ceili(sobra / maxf(media, 1.0)), 0))
		tris = _triangulos(variante, n_t, n_f)
	# Un MultiMesh por variante de matojo ("briznas", "briznas_1", …), más tarjetas y flores.
	for v in range(_mallas.size()):
		var trs_v: Array[Transform3D] = []
		var tin_v: PackedColorArray = PackedColorArray()
		for i in range(n_m):
			if int(variante[i]) == v:
				trs_v.append((acc["matojos"] as Array)[i] as Transform3D)
				tin_v.append((acc["tintes_m"] as Array)[i] as Color)
		_multimalla(_mallas[v], trs_v, tin_v, padre, "briznas" if v == 0 else "briznas_%d" % v)
	if _quad_tarjeta != null:
		_multimalla(_quad_tarjeta, Array(acc["tarjetas"], TYPE_TRANSFORM3D, "", null), PackedColorArray(acc["tintes_t"]), padre, "tarjetas")
	_multimalla(_quad_flor, Array(acc["flores"], TYPE_TRANSFORM3D, "", null), PackedColorArray(acc["tintes_f"]), padre, "flores")
	_stats[b] = {"matojos": n_m, "tarjetas": n_t, "flores": n_f, "triangulos": tris, "casillas": acc["casillas"], "huella": acc["huella"]}
	# Caja del bloque: el rectángulo + 1 u de margen (el viento y las tarjetas que miran a la cámara sobresalen).
	var caja := AABB(Vector3(rect.position.x - 1.0, _y - 0.5, rect.position.y - 1.0),
		Vector3(rect.size.x + 2.0, 2.5, rect.size.y + 2.0))
	for h in padre.get_children():
		(h as MultiMeshInstance3D).custom_aabb = caja
	_aplicar_modo(padre)
	Caminar3D.decorar_bloque(self, padre, rect, _y)       # W5 (2/11): hojas bajo los árboles y motas/luciérnagas; hijos del bloque, se liberan con él


## La siembra de UNA casilla (briznas, tarjetas y flores), con su semilla, recortada al rectángulo del bloque. Acumula en `acc`.
func _sembrar_casilla(c: Vector2i, rect: Rect2, acc: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([semilla, c.x, c.y])
	var rc := Rect2(float(c.x) * casilla, float(c.y) * casilla, casilla, casilla)
	var con_matas: bool = _matas.is_valid()
	var casillas: Dictionary = acc["casillas"]
	casillas[c] = 0
	# Calva: la casilla entera sin detalle (huecos entre corros). Se decide antes de nada para que el resto del azar no cambie. En el corazón de una mata
	# (matas ≥ 0,98: también la casilla que la naturaleza acaba de germinar) no hay calvas.
	var r_calva: float = rng.randf()
	if procedural and r_calva < float(AGRUPADO["p_calva"]):
		if not con_matas or float(_matas.call(rc.get_center().x, rc.get_center().y)) < 0.98:
			return
	var matojos: Array = acc["matojos"]
	var tintes_m: Array = acc["tintes_m"]
	var variante: Array = acc["variante"]
	var huella: int = int(acc["huella"])
	# Briznas: rejilla con jitter; en el borde (peso 0,3-0,7) más altas, la "franja" que pisa el camino.
	var rej_x: float = float(AGRUPADO["rejilla_x"]) if procedural else 1.0
	var paso: float = 1.0 / sqrt(maxf(densidad * (MATA_MULT_DENSIDAD if con_matas else 1.0) * rej_x, 0.01))
	var n_rej: int = ceili(casilla / paso)
	for iz in range(n_rej):
		for ix in range(n_rej):
			var x: float = rc.position.x + (float(ix) + rng.randf()) * paso
			var z: float = rc.position.y + (float(iz) + rng.randf()) * paso
			var r_dens: float = rng.randf()
			if not rc.has_point(Vector2(x, z)) or not rect.has_point(Vector2(x, z)):
				continue
			if procedural and r_dens > _densidad_local(x, z):
				continue            # ruido de densidad: dentro de una mata, zonas más tupidas y zonas ralas
			var m: float = 1.0
			if con_matas:
				m = float(_matas.call(x, z))
				if rng.randf() > lerpf(CLARO_DENSIDAD, 1.0, m):
					continue            # antes de pedir el peso (lo caro): en los claros casi todo se descarta aquí
			var w: float = float(_peso.call(x, z))
			if w <= 0.02 or rng.randf() > w * 1.15:
				continue
			var borde: float = 1.0 - absf(w - 0.5) * 2.0
			var s: float = alto_matojo * (1.0 + borde * 0.6)
			var s_a: float
			var base: Basis
			var tinte: Color
			if procedural:
				s *= lerpf(float(AGRUPADO["alto_min"]), float(AGRUPADO["alto_max"]), rng.randf())
				s_a = s * lerpf(float(AGRUPADO["ancho_min"]), float(AGRUPADO["ancho_max"]), rng.randf())
				var incl: float = rng.randf() * float(AGRUPADO["inclinacion_max"])
				base = Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, incl)
				var v: float = 0.88 + rng.randf() * 0.2
				var a: float = (rng.randf() * 2.0 - 1.0) * float(AGRUPADO["tono"])
				tinte = Color(v * (1.0 + a), v, v * (1.0 - a * 0.5), rng.randf())      # alfa = fase del balanceo
				variante.append(rng.randi() % _mallas.size())
			else:
				s *= 0.75 + rng.randf() * 0.5
				s_a = s
				base = Basis(Vector3.UP, rng.randf() * TAU)
				var v0: float = 0.9 + rng.randf() * 0.2
				tinte = Color(v0, v0 * (0.97 + rng.randf() * 0.06), v0 * (0.95 + rng.randf() * 0.08), 1.0)
				variante.append(0)
			if con_matas:
				var k: float = lerpf(MATA_ALTURA_CLARO, MATA_ALTURA_CENTRO, m)
				s *= k
				s_a *= k
			if _alto.is_valid():
				var k2: float = float(_alto.call(x, z))
				s *= k2
				s_a *= k2
			matojos.append(Transform3D(base.scaled(Vector3(s_a, s, s_a)), Vector3(x, _y, z)))
			tintes_m.append(tinte)
			casillas[c] = int(casillas[c]) + 1
			huella = hash([huella, snappedf(x, 0.001), snappedf(z, 0.001), snappedf(s, 0.001)])
	# Tarjetas pintadas: menos y algo más grandes; también más altas en el borde.
	if _quad_tarjeta != null:
		var trs: Array = acc["tarjetas"]
		var tintes: Array = acc["tintes_t"]
		var paso_t: float = 1.0 / sqrt(maxf(densidad_tarjetas * (MATA_MULT_DENSIDAD if con_matas else 1.0) * rej_x, 0.01))
		var n_rt: int = ceili(casilla / paso_t)
		for iz in range(n_rt):
			for ix in range(n_rt):
				var x2: float = rc.position.x + (float(ix) + rng.randf()) * paso_t
				var z2: float = rc.position.y + (float(iz) + rng.randf()) * paso_t
				var r_dens2: float = rng.randf()
				if not rc.has_point(Vector2(x2, z2)) or not rect.has_point(Vector2(x2, z2)):
					continue
				if procedural and r_dens2 > _densidad_local(x2, z2):
					continue
				var m2: float = 1.0
				if con_matas:
					m2 = float(_matas.call(x2, z2))
					if rng.randf() > lerpf(CLARO_DENSIDAD, 1.0, m2):
						continue
				var w2: float = float(_peso.call(x2, z2))
				if w2 <= 0.05 or rng.randf() > w2 * 1.1:
					continue
				var borde2: float = 1.0 - absf(w2 - 0.5) * 2.0
				var s2: float = alto_tarjeta * ((0.7 + rng.randf() * 0.6) if procedural else (0.8 + rng.randf() * 0.45)) * (1.0 + borde2 * 0.35)
				if con_matas:
					s2 *= lerpf(MATA_ALTURA_CLARO, MATA_ALTURA_CENTRO, m2)
				if _alto.is_valid():
					s2 *= float(_alto.call(x2, z2))
				trs.append(Transform3D(Basis.IDENTITY.scaled(Vector3(s2, s2, s2)), Vector3(x2, _y, z2)))
				var v2: float = 0.92 + rng.randf() * 0.14
				# Los dibujos con flor (0 y 1) salen menos que los de solo hierba (2 y 3).
				var celda: float = [0.0, 1.0, 2.0, 2.0, 3.0, 3.0, 3.0][rng.randi() % 7]
				tintes.append(Color(v2 * tinte_tarjetas.r, v2 * tinte_tarjetas.g, v2 * (0.96 + rng.randf() * 0.06) * tinte_tarjetas.b, (celda + 0.5) / 4.0))
				huella = hash([huella, snappedf(x2, 0.001), snappedf(z2, 0.001)])
	# Flores: pocas, solo en hierba plena, a veces en grupitos de 2-3. Por casilla salen < 1 de media: la parte decimal es una probabilidad.
	var flores: Array = acc["flores"]
	var tintes_f: Array = acc["tintes_f"]
	var esperadas: float = rc.get_area() * flores_por_unidad
	var n_flor: int = int(esperadas) + (1 if rng.randf() < esperadas - floorf(esperadas) else 0)
	for i in range(n_flor):
		var x3: float = rc.position.x + rng.randf() * rc.size.x
		var z3: float = rc.position.y + rng.randf() * rc.size.y
		var r_m: float = float(_matas.call(x3, z3)) if con_matas else 1.0
		var r_w: float = float(_peso.call(x3, z3))
		var col: Color = COLORES_FLOR[rng.randi() % COLORES_FLOR.size()]
		var n_grupo: int = 1 + rng.randi() % 3
		if not rect.has_point(Vector2(x3, z3)) or r_m < 0.35 or r_w < 0.85:
			continue            # las flores crecen dentro de las matas, no sueltas en el claro
		for k in range(n_grupo):
			var p := Vector3(x3 + rng.randf_range(-0.18, 0.18), _y + 0.07 + rng.randf() * 0.05,
				z3 + rng.randf_range(-0.18, 0.18))
			var sf: float = 0.15 + rng.randf() * 0.06
			var bf := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3))
			flores.append(Transform3D(bf.scaled(Vector3(sf, sf, sf)), p))
			tintes_f.append(col)
	acc["huella"] = huella


## Ruido de densidad (0..1 → `densidad_min`..1): el mismo ruido de valor del horneador (`HorneadorNivel._vruido`), con la semilla de la hierba. Determinista por (x, z).
func _densidad_local(x: float, z: float) -> float:
	var n: float = HorneadorNivel._vruido(Vector2(x, z) / float(AGRUPADO["tam_densidad"]), semilla + 5)
	return lerpf(float(AGRUPADO["densidad_min"]), 1.0, n)


## Deja como mucho `tope` elementos en cada uno de los arrays PARALELOS de `listas` (mismo tamaño todos), quitando a partes iguales (se queda
## uno de cada `n / tope`, repartidos por todo el bloque). Los modifica en el sitio. Devuelve cuántos quedan.
func _ralear(listas: Array, tope: int) -> int:
	var n: int = (listas[0] as Array).size()
	if n <= tope:
		return n
	var indices: PackedInt32Array = PackedInt32Array()
	var paso_k: float = float(n) / float(maxi(tope, 1))
	for k in range(tope):
		indices.append(int(float(k) * paso_k))
	for lista in listas:
		var l: Array = lista
		var quedan: Array = []
		for i in indices:
			quedan.append(l[i])
		l.clear()
		l.append_array(quedan)
	return tope


func _triangulos(variante: Array, n_t: int, n_f: int) -> int:
	var tris: int = n_t * 2 + n_f * 2
	for v in variante:
		tris += _tris_variante[int(v)]
	return tris


## Lo medido al crear el bloque `b` (vale en headless, donde el MultiMesh no guarda las copias): {matojos, tarjetas, flores, triangulos, casillas: {casilla: matojos}, huella}.
## Vacío si el bloque no existe.
func estadisticas_bloque(b: Vector2i) -> Dictionary:
	return _stats.get(b, {})


## Matojos de la casilla `c` (−1 si su bloque no está creado).
func matojos_en_casilla(c: Vector2i) -> int:
	var p := Vector2((float(c.x) + 0.5) * casilla, (float(c.y) + 0.5) * casilla)
	var b := Vector2i(floori((p.x - _zona.position.x) / lado_bloque), floori((p.y - _zona.position.y) / lado_bloque))
	if not _stats.has(b):
		return -1
	return int(((_stats[b] as Dictionary)["casillas"] as Dictionary).get(c, 0))


## Suma de todos los bloques creados: {matojos, tarjetas, flores, triangulos, bloques, casillas, casillas_vacias}.
func estadisticas() -> Dictionary:
	var r: Dictionary = {"matojos": 0, "tarjetas": 0, "flores": 0, "triangulos": 0, "bloques": _stats.size(), "casillas": 0, "casillas_vacias": 0, "max_triangulos_bloque": 0, "max_matojos_bloque": 0}
	for b in _stats:
		var s: Dictionary = _stats[b]
		for k in ["matojos", "tarjetas", "flores", "triangulos"]:
			r[k] = int(r[k]) + int(s[k])
		r["max_triangulos_bloque"] = maxi(int(r["max_triangulos_bloque"]), int(s["triangulos"]))
		r["max_matojos_bloque"] = maxi(int(r["max_matojos_bloque"]), int(s["matojos"]))
		for c in (s["casillas"] as Dictionary):
			r["casillas"] = int(r["casillas"]) + 1
			if int((s["casillas"] as Dictionary)[c]) == 0:
				r["casillas_vacias"] = int(r["casillas_vacias"]) + 1
	return r


## 6/11 (arte del entorno): el peso de hierba de una casilla cambió (la naturaleza germinó tierra) → rehace SOLO el bloque que contiene `p` (mundo). Con la misma semilla las matas que ya había salen
## donde estaban y aparecen las nuevas. Si el bloque no existe (lejos del jugador) no hace nada: cuando se cree saldrá ya con el peso nuevo.
func rehacer_bloque_en(p: Vector3) -> void:
	var b := Vector2i(floori((p.x - _zona.position.x) / lado_bloque), floori((p.z - _zona.position.y) / lado_bloque))
	if not _bloques.has(b):
		return
	(_bloques[b] as Node3D).queue_free()
	_bloques.erase(b)
	_stats.erase(b)
	_crear_bloque(b)


## 0 briznas · 1 tarjetas pintadas · 2 las dos.
func set_modo(m: int) -> void:
	modo = posmod(m, 3)
	for b in _bloques:
		_aplicar_modo(_bloques[b] as Node3D)


func _aplicar_modo(padre: Node3D) -> void:
	var hay_tarjetas: bool = _quad_tarjeta != null
	for h in padre.get_children():
		if String(h.name).begins_with("briznas"):
			(h as Node3D).visible = modo != 1 or not hay_tarjetas
		elif h.name == "tarjetas":
			(h as Node3D).visible = modo != 0


## Matojos (briznas) de los bloques que hay ahora mismo.
func numero_de_matojos() -> int:
	var n: int = 0
	for b in _bloques:
		for h in (_bloques[b] as Node).get_children():
			if h is MultiMeshInstance3D and String(h.name).begins_with("briznas"):
				n += (h as MultiMeshInstance3D).multimesh.instance_count
	return n


## Bloques de hierba creados ahora mismo (con `actualizar`, solo los de alrededor del jugador).
func numero_de_bloques() -> int:
	return _bloques.size()


## Texturas de estado del suelo y la rejilla que las indexa: `tex` = el estado OFICIAL (`Mundo3D.textura_estados()`: aquí solo se lee R quemado) y
## `pisado` = la hierba aplastada (R8, la pone la maqueta; solo aspecto). B2: ya no hay una imagen propia con los dos mezclados.
## También crea la capa de hierba CRECIDA (un estado del objeto hierba, no del suelo: ESTADOS_SUELO.md §4.4).
func set_estado(tex: Texture2D, pisado: Texture2D, celda: float, lado: float) -> void:
	_img_crecida = Image.create_empty(int(lado), int(lado), false, Image.FORMAT_R8)
	_img_crecida.fill(Color(0.0, 0.0, 0.0, 1.0))
	_tex_crecida = ImageTexture.create_from_image(_img_crecida)
	_img_humedad = Image.create_empty(int(lado), int(lado), false, Image.FORMAT_RG8)
	_tex_humedad = ImageTexture.create_from_image(_img_humedad)
	_humedad.clear()
	for m in [_mat_matojo, _mat_tarjeta]:
		if m != null:
			m.set_shader_parameter("estado", tex)
			m.set_shader_parameter("pisado", pisado)
			m.set_shader_parameter("crecida", _tex_crecida)
			m.set_shader_parameter("humedad", _tex_humedad)
			m.set_shader_parameter("celda", celda)
			m.set_shader_parameter("lado", lado)


## El estado oficial cambió de objeto (el mapa cambió de tamaño): se lo da otra vez a los materiales.
func set_estado_textura(tex: Texture2D) -> void:
	for m in [_mat_matojo, _mat_tarjeta]:
		if m != null:
			m.set_shader_parameter("estado", tex)


## Dónde está la chibi: las matas cercanas se apartan.
func set_posicion_jugador(p: Vector3) -> void:
	for m in [_mat_matojo, _mat_tarjeta]:
		if m != null:
			m.set_shader_parameter("posicion_jugador", p)


## W2: el rastro de la jugadora (`rastro`: hasta 5 Vector4, xyz = dónde estuvo, w = peso del muelle), el radio de apartado y el empuje de su marcha (vel / vel. de correr, plano XZ).
## Se llama cada fotograma desde `Caminar3D.actualizar`; con rastro vacío, radio `APARTAR_RADIO_BASE` y empuje cero es el apartado de siempre.
func set_apartado(rastro: Array, radio: float, empuje: Vector2) -> void:
	for m in [_mat_matojo, _mat_tarjeta]:
		if m == null:
			continue
		for i in range(5):
			m.set_shader_parameter("rast%d" % (i + 1), (rastro[i] as Vector4) if i < rastro.size() else Vector4.ZERO)
		m.set_shader_parameter("radio_pisar", radio)
		m.set_shader_parameter("empuje", empuje)
	if _mat_matojo != null:
		_mat_matojo.set_shader_parameter("fuerza_apartar", APARTAR_FUERZA)
	if _mat_tarjeta != null:
		_mat_tarjeta.set_shader_parameter("fuerza_apartar", APARTAR_FUERZA * 0.83)


## Lo que el shader tiene ahora de cada uniform del apartado (para las pruebas).
func parametro_apartado(nombre: String) -> Variant:
	return _mat_matojo.get_shader_parameter(nombre) if _mat_matojo != null else null


## Los bloques creados cuyo rectángulo está a menos de `radio` (plano XZ) de `p`: Array de [Vector2i, Rect2]. Para los pájaros de `Caminar3D`.
func bloques_cerca(p: Vector3, radio: float) -> Array:
	var r: Array = []
	for b in _bloques:
		var rect := Rect2(_zona.position + Vector2(b) * lado_bloque, Vector2(lado_bloque, lado_bloque)).intersection(_zona)
		var q := Vector2(clampf(p.x, rect.position.x, rect.end.x), clampf(p.z, rect.position.y, rect.end.y))
		if q.distance_to(Vector2(p.x, p.z)) <= radio:
			r.append([b, rect])
	return r


## Hierba crecida de una casilla (0 = fina, 1 = alta). Se sube a la GPU al llamar a `subir_crecida()`.
func set_crecida(c: Vector2i, valor: float) -> void:
	if _img_crecida == null or c.x < 0 or c.y < 0 or c.x >= _img_crecida.get_width() or c.y >= _img_crecida.get_height():
		return
	_img_crecida.set_pixel(c.x, c.y, Color(valor, 0.0, 0.0, 1.0))
	_crecida_sucia = true


## Los nodos de los bloques creados ahora mismo (para que `Caminar3D` revise sus hojas y motas).
func nodos_bloques() -> Array:
	return _bloques.values()


## ¿La casilla tiene la hierba crecida (alta y tupida)? Para las briznas sueltas al correr (`Caminar3D`).
func es_crecida(c: Vector2i) -> bool:
	return _img_crecida != null and c.x >= 0 and c.y >= 0 and c.x < _img_crecida.get_width() and c.y < _img_crecida.get_height() and _img_crecida.get_pixel(c.x, c.y).r > 0.5


func subir_crecida() -> void:
	if _crecida_sucia and _tex_crecida != null:
		_tex_crecida.update(_img_crecida)
		_crecida_sucia = false


## La hierba de la casilla `c` se ve mojada `MOJADA_S` s (`intensidad` 0..1: los bordes del área regada, menos).
func mojar(c: Vector2i, intensidad: float = 1.0) -> void:
	var h: Array = _humedad.get(c, [0.0, 0.0, 0.0])
	h[0] = maxf(float(h[0]), _reloj + MOJADA_S)
	h[2] = maxf(float(h[2]), intensidad)
	_humedad[c] = h


## La hierba de la casilla `c` se ve con escarcha `ESCARCHA_S` s; al fundirse queda mojada.
func escarchar(c: Vector2i, intensidad: float = 1.0) -> void:
	var h: Array = _humedad.get(c, [0.0, 0.0, 0.0])
	h[1] = maxf(float(h[1]), _reloj + ESCARCHA_S)
	h[2] = maxf(float(h[2]), intensidad)
	_humedad[c] = h


## Seca la hierba con el tiempo y sube la textura (una vez por fotograma, desde la maqueta). Sin casillas húmedas no cuesta nada.
func avanzar_humedad(dt: float) -> void:
	_reloj += dt
	if _humedad.is_empty() or _img_humedad == null:
		return
	var secas: Array[Vector2i] = []
	for c in _humedad:
		var h: Array = _humedad[c]
		var fin_escarcha: float = float(h[1])
		# La escarcha que se funde deja la casilla mojada (como el suelo: helada → mojada). Lo mojado entra mientras la escarcha se desvanece,
		# para que no haya salto.
		if fin_escarcha > 0.0 and _reloj >= fin_escarcha - FUNDIDO_S:
			h[0] = maxf(float(h[0]), fin_escarcha + MOJADA_S)
			if _reloj >= fin_escarcha:
				h[1] = 0.0
		var k: float = float(h[2])
		var mojada: float = clampf((float(h[0]) - _reloj) / FUNDIDO_S, 0.0, 1.0) * k
		var escarcha: float = clampf((float(h[1]) - _reloj) / FUNDIDO_S, 0.0, 1.0) * k
		if c.x >= 0 and c.y >= 0 and c.x < _img_humedad.get_width() and c.y < _img_humedad.get_height():
			_img_humedad.set_pixel(c.x, c.y, Color(mojada, escarcha, 0.0, 1.0))
		if mojada <= 0.0 and escarcha <= 0.0:
			secas.append(c)
	for c in secas:
		_humedad.erase(c)
	_tex_humedad.update(_img_humedad)


func set_viento(v: float) -> void:
	viento = v
	if _mat_matojo != null:
		_mat_matojo.set_shader_parameter("viento", v)
	if _mat_tarjeta != null:
		_mat_tarjeta.set_shader_parameter("viento", v)


## Un matojo: `briznas` briznas curvadas que salen del centro (alto 1, se escala por copia). UV.y = altura 0..1. Con (99, 5, 0.7, 0.5) es el de siempre.
func _malla_matojo(semilla_forma: int = 99, briznas: int = 5, alto_base: float = 0.7, alto_extra: float = 0.5) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla_forma
	for i in range(briznas):
		var ang: float = float(i) / float(briznas) * TAU + rng.randf() * 0.5
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var lado := Vector3(-dir.z, 0.0, dir.x)
		var alto: float = alto_base + rng.randf() * alto_extra
		var inclin: float = 0.18 + rng.randf() * 0.3
		var ancho: float = (0.21 + rng.randf() * 0.06) * sqrt(5.0 / float(briznas))     ## más ancha: son 5 briznas y no 9 (con menos briznas, algo más anchas aún)
		var base: Vector3 = dir * 0.12 * rng.randf()
		var medio: Vector3 = base + dir * inclin * 0.35 + Vector3.UP * alto * 0.55
		var punta: Vector3 = base + dir * inclin + Vector3.UP * alto
		# Dos tramos (base ancha -> medio -> punta) para que la brizna se curve.
		var a0: Vector3 = base - lado * ancho
		var a1: Vector3 = base + lado * ancho
		var m0: Vector3 = medio - lado * ancho * 0.6
		var m1: Vector3 = medio + lado * ancho * 0.6
		for v in [[a0, 0.0], [a1, 0.0], [m1, 0.55], [a0, 0.0], [m1, 0.55], [m0, 0.55],
				[m0, 0.55], [m1, 0.55], [punta, 1.0]]:
			st.set_uv(Vector2(0.5, float(v[1])))
			st.set_normal(Vector3.UP)
			st.add_vertex(v[0] as Vector3)
	return st.commit()


## Flor de 5 pétalos: R = pétalo (se tiñe), G = centro (amarillo), A = recorte.
func _textura_flor() -> ImageTexture:
	var n: int = 64
	var img := Image.create_empty(n, n, true, Image.FORMAT_RGBA8)
	var c := Vector2(n, n) * 0.5
	for y in range(n):
		for x in range(n):
			var p := Vector2(float(x) + 0.5, float(y) + 0.5) - c
			var r: float = p.length() / (float(n) * 0.5)
			var ang: float = atan2(p.y, p.x)
			var petalo: float = 0.62 + 0.36 * absf(cos(ang * 2.5))
			var col := Color(0, 0, 0, 0)
			if r < 0.26:
				col = Color(0.0, 1.0, 0.0, 1.0)
			elif r < petalo:
				var sombra: float = 0.82 + 0.18 * (r / petalo)
				col = Color(sombra, 0.0, 0.0, 1.0)
			img.set_pixel(x, y, col)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _multimalla(malla: Mesh, trs: Array[Transform3D], tintes: PackedColorArray, padre: Node3D, nombre: String) -> void:
	if trs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = malla
	mm.instance_count = trs.size()
	for i in range(trs.size()):
		mm.set_instance_transform(i, trs[i])
		mm.set_instance_custom_data(i, tintes[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = nombre
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(mi)
