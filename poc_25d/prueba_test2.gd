extends Node3D

## MAQUETA 3D DE TEST 2 (estética pastel).
## Lee el mismo plano de letras de test_2.gd (40 x 40) y lo monta en 3D: bloques con el suelo pintado y
## TRANSICIONES suaves entre hierba / camino / tierra / piedra (shader), agua animada, el decorado de Meshy
## (bosque.glb, objetos.glb, magia.glb), partículas (fuego, humo, brasas, esporas, destellos, pétalos) y los
## personajes chibi del pipeline. Es solo visual: se pasea con la chibi; no hay hechizos ni pruebas.
##
## Teclas: WASD mover · Shift correr · + / - zoom (la inclinación está fija a 60°, ver INCLINACION) · H sombras · P partículas
##         K decorado on/off · G hierba 3D on/off · L luz plana/suave de personajes · [ / ] tamaño de la chibi
##
## Rendimiento (docs/PLAN_ACCION_TEST2.md §1.3): el decorado va por LOTES (un MultiMesh por pieza y malla, no un
## nodo por casilla), la hierba en bloques que Godot descarta fuera de cámara y sin sombra, y la sombra del sol
## llega a 30 m. El HUD enseña llamadas de dibujo, primitivas y memoria de vídeo para la tabla de §1.2.

const TEST2 = preload("res://test_2.gd")

const S: float = 2.3                ## lado de una casilla en unidades (la chibi mide ~1)
const ALTO: float = S * 0.45        ## alto de un bloque de tierra
## 6.16: el agua llega CASI a ras del bloque de hierba (4 cm por debajo; antes 0,6 × ALTO y se veía un escalón de 40 cm). El Lanzador y el
## Jugador leen esta constante, así que el nivel lógico del agua sube con la imagen.
const ALTO_AGUA: float = ALTO - 0.04
const VEL_ANDAR: float = 1.6
const VEL_CORRER: float = 3.0
const ZOOM_INICIAL: float = 6.0
const ZOOM_MINIMO: float = 2.0
const SEGUIMIENTO: float = 14.0
## Inclinación de la cámara, BLOQUEADA (Pablo, 6/10: «de momento lockeamos en 60 grados, siguiendo al personaje»). Solo el zoom +/- sigue libre.
## Para volver a probar otros ángulos, cambiar esta constante (las teclas R/F y 1/2/3 se quitaron).
const INCLINACION: float = 60.0

const RAIZ: String = "res://poc_25d/"
const SUELO: String = "res://poc_25d/suelo_meshy/"
const VFX: String = "res://poc_25d/vfx/"
const PRECALENTAR: float = 1.6
const RUNAS: String = VFX + "runas/"
## Cartel de Meshy: giro para que el tablero mire a la cámara y dónde queda el centro del tablero (MEDIDA 1.3).
const GIRO_CARTEL: float = 319.0
## Orientación a mano de una pieza concreta del mapa Test 2 (el de jugabilidad tiene la suya: Jugabilidad3D.GIROS): casilla (x, y) del mapa → grados sobre el eje vertical. Gana a todo lo demás
## (el giro aleatorio de cada casilla y los giros fijos del código). Ej.: Vector2i(12, 7): 90.0 gira 90° lo que haya en esa casilla.
const GIROS_CELDA: Dictionary = {
}
const RUNA_EN_TABLERO: Vector3 = Vector3(0.0, 1.0, 0.14)
## Si una pieza está en varias bibliotecas, se usa la de la primera. Antes que todas, las REGENERADAS sueltas de
## meshy/piezas/<id>.glb (una pieza por GLB; ver meshy/INTEGRAR_PIEZAS.cmd): sustituyen a la de la lámina.
const CARPETA_PIEZAS: String = Pieza3D.CARPETA_PIEZAS     ## la tabla vive en pieza_3d.gd (la usa también el editor)
const BIBLIOTECAS: Array = Pieza3D.BIBLIOTECAS     ## la tabla vive en pieza_3d.gd (la usa también el editor)
## Las piezas buenas de las bibliotecas nuevas sustituyen a las de la lámina (REGENERAR.md §1): árbol y pino
## (arboles_2), seto (arbusto_otono en vez de seto_seco), puesto (puesto_mercado) y arco (arco_ruina).
## Si la nueva falta, se usa la vieja.
const SUSTITUTAS: Dictionary = Pieza3D.SUSTITUTAS     ## la tabla vive en pieza_3d.gd (la usa también el editor)
## Empujables (todavía sin mecánica en la maqueta): cubos con la textura de tierra o de hielo.
const EMPUJABLES: Array = [["tierra", Vector2i(6, 33)], ["hielo", Vector2i(28, 26)]]
## Las texturas de suelo_meshy son claras para la paleta (V 0,8-0,99; ARTE.md pide 0,2-0,76): se oscurecen
## aquí y la luz vuelve a valores normales (antes se bajaba la luz y se apagaban también los personajes).
const OSCURECER_SUELO: float = 0.78
const LUZ_AMBIENTE: float = 0.6
const LUZ_SOL: float = 1.0

## Personajes: id del pipeline (res://poc_25d/<id>.glb) y su alto en pantalla. Si falta, el sustituto.
const PJ_JUGADOR: Array = ["chibi_elf_v2", "chibi_elf", "chibi_test"]
const PJ_LIBRERA: Array = ["bookseller_chibi", "chibi_test"]
const PJ_GOBLIN: Array = ["goblin_warrior_chibi", "goblin_warrior"]
## Espadachín: el mismo modelo del guerrero con espada (Pj3D.MODELO_DE + Equipo3D.EQUIPO). Ocupa las "A" del
## mapa hasta que haya arquero en 3D.
const PJ_ESPADACHIN: Array = ["goblin_espadachin", "goblin_warrior_chibi"]
## Personajes nuevos (6/10): la alquimista de los mercados, el arquero y el guardabosques. Sus GLB aún no están en el repo
## (COPIAR_MODELOS.cmd los copia desde el pipeline): mientras falten, `_personaje` usa el siguiente de la lista.
const PJ_ALQUIMISTA: Array = ["alchemist_elf", "bookseller_chibi", "chibi_test"]
const PJ_ARQUERO: Array = ["goblin_archer_chibi", "goblin_espadachin", "goblin_warrior_chibi"]
const PJ_GUARDABOSQUES: Array = ["ranger_human", "bookseller_chibi", "chibi_test"]
const ALTO_PJ: Dictionary = {"chibi_elf_v2": 1.0, "chibi_elf": 1.0, "chibi_test": 1.0, "bookseller_chibi": 0.95,
	"goblin_warrior_chibi": 0.85, "goblin_warrior": 0.85, "goblin_espadachin": 0.85,
	"alchemist_elf": 0.95, "goblin_archer_chibi": 0.85, "ranger_human": 1.0}

## Tamaño de cada pieza de decorado (alto en unidades; las marcadas "ancho" se miden por su ancho).
const MEDIDA: Dictionary = Pieza3D.MEDIDA     ## la tabla vive en pieza_3d.gd (la usa también el editor)
const MEDIDA_ANCHO: Dictionary = Pieza3D.MEDIDA_ANCHO     ## la tabla vive en pieza_3d.gd (la usa también el editor)

## --- Alturas del suelo (6/10, Pipeline; criterio de Link's Awakening: cada casilla tiene UN nivel y lo plano va a ras) ---
## Antes cada pieza plana (placa, baldosa) se escalaba por su ancho y sobresalía lo que diera su malla (grosores distintos),
## los discos de runa iban a +0,03 y +0,05 puestos a ojo, y las bases irregulares de Meshy dejaban huecos o flotaban.
## Ahora: lo plano sobresale un grosor FIJO (PLANAS), todo decal va a una de dos alturas y toda pieza se hunde HUNDIR.
## `ALTO` y `ALTO_AGUA` no cambian de valor: el Lanzador y el Jugador los leen de aquí (ver diario).
const Y_DECAL: float = ALTO + 0.02        ## discos, runas y marcas sobre el suelo desnudo (igual que Vfx3D._marca)
const Y_SOBRE_PLANA: float = ALTO + 0.07  ## decal encima de una pieza plana (baldosa de guardado): grosor de la baldosa + 0,03
const HUNDIR: float = 0.03                ## cuánto se entierra cada pieza: la base irregular de Meshy no deja hueco ni flota
## Piezas planas: lo que sobresale del suelo, en unidades, da igual lo gruesa que venga la malla (el resto queda enterrado).
const PLANAS: Dictionary = Pieza3D.PLANAS     ## la tabla vive en pieza_3d.gd (la usa también el editor)
## Sombra de contacto (elipse plana, borde duro) bajo cada pieza en pie: ancla la pieza al suelo como en Link's Awakening.
## Radio en unidades antes de la variación de tamaño de cada copia. Lo que no está aquí no lleva sombra (plano o diminuto).
const SOMBRA_CONTACTO: Dictionary = {
	"arbol_redondo": 0.95, "arbol_redondo_2": 0.95, "pino": 0.8, "pino_2": 0.8, "arbusto": 0.6, "arbusto_flores": 0.6,
	"arbusto_otono": 0.7, "seto_seco": 0.7, "roca_grande": 0.75, "roca_cristal": 0.6, "tronco": 0.6, "tocon": 0.4,
	"totem_runico": 0.5, "brasero": 0.45, "fogata": 0.5, "puesto": 1.0, "puesto_mercado": 1.0, "dummy": 0.45,
	"cartel": 0.4, "barril": 0.4, "cofre": 0.45, "caja": 0.45, "caja_pequena": 0.35, "valla": 0.4, "arco_ruina": 0.9,
	"arco_puerta": 0.9, "portal_salida": 0.9, "seta_reactiva": 0.4, "flor_reactiva": 0.4, "raiz_reactiva": 0.4,
}

## Estado de la hierba por casilla (ESTADOS_SUELO.md §1.2). Una casilla sin entrada es hierba FINA.
enum Fase { CRECIDA = 1, PRENDIENDO = 2, ARDIENDO = 3, CENIZAS = 4 }
const MAX_ARDIENDO: int = 60         ## casillas de hierba encendidas a la vez; más allá no se propaga
const MAX_FX_HIERBA: int = 24        ## de ellas, las que llevan partículas (el resto solo oscurece el suelo)
const T_PRENDIENDO: float = 1.0      ## s en PRENDIENDO antes de ARDIENDO (IGNITE_TIME)
const T_ARDIENDO: float = 5.0        ## s ardiendo antes de CENIZAS (BURN_TIME); R sube lineal en ese tiempo
const FRENTE_VEL: float = 0.5        ## casillas/s a las que crece el frente de contagio (32 px/s ÷ 64)
const FRENTE_MIN: float = 0.4        ## a partir de aquí el frente puede prender (26 px)
const T_SALTO: float = 0.6           ## s que espera una casilla encendida antes de contagiar a una vecina (6.9a)
const FRENTE_MAX: float = 1.7        ## y se acaba aquí (SPREAD_RADIUS 110 px)
const CONO_VIENTO: float = 3.6       ## alcance del viento sobre hierba ardiendo (230 px)
const T_PISADO: float = 2.0          ## s que tarda en levantarse la hierba pisada (solo aspecto)
const T_CRECER: float = 0.6          ## s que tarda la hierba en brotar al regarla
## Ids pequeños del decorado en lotes que NO proyectan sombra (Paso 4): solo árboles, bloques, puestos y personajes.
const SIN_SOMBRA: Array = ["arbusto", "arbusto_flores", "arbusto_otono", "seto_seco", "piedras", "piedra", "setas",
	"seta", "tocon", "cartel", "pasadero", "juncos", "matas", "flores", "caja_pequena", "baldosa_guardado", "pocion"]
## Rejillas de prueba del tamaño de textura (Paso 4): px que ocupa en pantalla un metro a 1080p con el zoom inicial.
const PX_POR_UNIDAD_1080: float = 1080.0 / ZOOM_INICIAL

const COLOR_ELEMENTO: Dictionary = {
	"fuego": Color(1.0, 0.55, 0.25), "agua": Color(0.45, 0.75, 1.0), "rayo": Color(1.0, 0.92, 0.4),
}

## Mezcla del suelo: un mapa de tipos por casilla (R hierba, G camino, B tierra, A piedra) que el shader
## lee DEFORMADO por un campo de ruido para que los bordes salgan ondulados y no cuadrados. El ruido es una
## textura hecha en CPU (`_campo_ruido`), así la hierba 3D (Hierba3D) sabe exactamente dónde está el borde.
## Además: dos muestras de cada textura a escalas y giros distintos mezcladas por ruido (no se ve la
## repetición en cuadros) y una variación suave de tono a gran escala.
const CODIGO_SOMBRA: String = """
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	if (dot(p, p) > 1.0) {
		discard;
	}
	ALBEDO = vec3(0.04, 0.07, 0.05);
	ALPHA = 0.30;      // opacidad de la sombra de contacto (borde duro, sin degradado)
}
"""

const CODIGO_SUELO: String = """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D mapa : filter_linear, repeat_disable;
uniform sampler2D campo : filter_linear, repeat_enable;
uniform sampler2D estado : hint_default_black, filter_linear, repeat_disable;   // R quemado · G mojado · B helado · A pisado
uniform sampler2D t_hierba : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_camino : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_tierra : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_piedra : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 color_ceniza : source_color = vec3(0.22, 0.20, 0.18);
uniform float fuerza_ceniza = 0.0;     // 6.14: el suelo NO se ennegrece al quemarse (0 = nada; 1 = el antiguo suelo de ceniza)
uniform vec3 color_escarcha : source_color = vec3(0.84, 0.94, 0.98);
uniform float celda = 2.3;
uniform float lado = 40.0;
uniform float tam_tex = 4.6;
uniform float ruido = 0.45;
uniform float dureza = 0.16;
uniform float variacion = 0.07;
uniform float brillo = 1.0;
uniform float contraste = 2.5;                                          // rampa de luz: 1 = como el PBR · 4 = cel
uniform vec3 sombra_tinte : source_color = vec3(0.34, 0.36, 0.46);      // lo que llega a la sombra: frío y pastel
// Rugosidad: relieve fino por mapa de normales (ruido generado si no hay textura). Con la rampa de luz, los bultos
// salen como moteado claro/oscuro, que es lo que hace que la arena y la tierra no parezcan una lámina lisa.
uniform sampler2D normal_suelo : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float rugosidad = 0.5;            // 0 liso · 1 muy rugoso (tecla B)
uniform float tam_rugosidad = 1.4;        // unidades de mundo por repetición del relieve
// Relieve PROPIO de la tierra: mapa de normales sacado de su textura (piedras en relieve, musgo y gravilla). Si no hay
// (usa_normal_tierra = 0) la tierra usa el relieve genérico de arriba, como siempre.
uniform sampler2D normal_tierra : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float usa_normal_tierra = 0.0;
vec3 muestra(sampler2D t, vec2 p, float mezcla) {
	vec2 q = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p * 0.73 + vec2(0.37, 0.11);
	return mix(texture(t, p).rgb, texture(t, q).rgb, mezcla);
}
void fragment() {
	vec3 pm = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 c = pm.xz / celda;
	vec4 r = texture(campo, c / lado);
	vec2 uvm = (c + (r.rg - 0.5) * 2.0 * ruido) / lado;
	vec4 w0 = texture(mapa, uvm);
	vec4 w = smoothstep(vec4(0.5 - dureza), vec4(0.5 + dureza), w0);
	float s = w.r + w.g + w.b + w.a;
	if (s < 0.05) {
		w = w0;
		s = w.r + w.g + w.b + w.a;
	}
	w /= max(s, 0.0001);
	vec2 t = pm.xz / tam_tex;
	float m = smoothstep(0.3, 0.7, r.b);
	vec3 col = muestra(t_hierba, t, m) * w.r + muestra(t_camino, t, m) * w.g
		+ muestra(t_tierra, t, m) * w.b + muestra(t_piedra, t, m) * w.a;
	// Estado por celda (ESTADOS_SUELO.md §4). uvm ya lleva el ruido de borde: la ceniza y el charco quedan orgánicos.
	vec4 e = texture(estado, uvm);
	float q = smoothstep(0.5 - dureza, 0.5 + dureza, e.r) * w.r;               // quemado: solo donde hay hierba
	col = mix(col, color_ceniza * (0.8 + 0.4 * r.a), q * fuerza_ceniza);
	float mo = smoothstep(0.35, 0.65, e.g);                                    // mojado: el tinte del 2D (0,62 0,66 0,78)
	col = mix(col, col * vec3(0.62, 0.66, 0.78), mo);
	float he = smoothstep(0.4, 0.6, e.b);                                      // helado: escarcha por encima de todo
	col = mix(col, mix(col * vec3(0.8, 0.95, 1.05), color_escarcha * (0.9 + 0.2 * r.a), 0.7), he);
	ALBEDO = col * brillo * (1.0 + (r.a - 0.5) * 2.0 * variacion);
	ROUGHNESS = mix(1.0, 0.35, mo);
	SPECULAR = 0.0;
	// Relieve: dos escalas del mismo mapa (gruesa y fina) para que no se vea la repetición; la escarcha lo alisa,
	// la hierba lo suaviza (sus briznas ya dan textura) y la piedra lo marca más.
	vec2 tr = pm.xz / tam_rugosidad;
	vec3 n1 = texture(normal_suelo, tr).rgb * 2.0 - 1.0;
	vec3 n2 = texture(normal_suelo, tr * 3.1 + vec2(0.5, 0.25)).rgb * 2.0 - 1.0;
	vec3 nr = normalize(vec3(n1.xy * 0.65 + n2.xy * 0.35, 1.0));
	if (usa_normal_tierra > 0.5) {
		// Mismas dos muestras que el color (la segunda girada y a otra escala): la normal gira con ella.
		mat2 giro = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
		vec2 g1 = texture(normal_tierra, t).xy * 2.0 - 1.0;
		vec2 g2 = transpose(giro) * (texture(normal_tierra, giro * t * 0.73 + vec2(0.37, 0.11)).xy * 2.0 - 1.0);
		vec2 gt = mix(g1, g2, m);
		nr = normalize(vec3(mix(nr.xy, gt + nr.xy * 0.3, w.b), 1.0));
	}
	float fuerza = rugosidad * (0.5 + 0.5 * (w.g + w.b) + 0.8 * w.a) * (1.0 - he);
	NORMAL_MAP = nr * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = fuerza * 2.2;
}
void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		// Rampa suave en vez de coseno: tapa clara, sombra fría. ATTENUATION lleva la sombra proyectada.
		float luz = smoothstep(0.0, 1.0, clamp(dot(NORMAL, LIGHT) * contraste, 0.0, 1.0)) * ATTENUATION;
		DIFFUSE_LIGHT += mix(sombra_tinte, vec3(1.0), luz) * LIGHT_COLOR / PI;
	} else {
		DIFFUSE_LIGHT += max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION * LIGHT_COLOR / PI;
	}
	// El suelo mojado brilla un poco (el seco no tiene especular).
	vec3 h = normalize(VIEW + LIGHT);
	SPECULAR_LIGHT += pow(max(dot(NORMAL, h), 0.0), 40.0) * (1.0 - ROUGHNESS) * LIGHT_COLOR * ATTENUATION;
}
"""

## Agua estilizada (docs/IMPLEMENTAR_TECNICAS.md Paso 2): claro en la orilla y hondo en el centro por la
## DISTANCIA A LA ORILLA de cada celda (no hay lecho bajo el agua: el depth buffer daría una profundidad
## constante), espuma rota junto a tierra, ondas con dos normales que se cruzan y hielo cuando B (helado) sube.
const CODIGO_AGUA: String = """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D orilla : filter_linear, repeat_disable;                       // distancia a tierra / 4 (en casillas)
uniform sampler2D campo : filter_linear, repeat_enable;                         // el mismo ruido del suelo
uniform sampler2D estado : hint_default_black, filter_linear, repeat_disable;   // B = helado
uniform sampler2D normal_agua : filter_linear_mipmap, repeat_enable;
uniform sampler2D t_agua : source_color, filter_linear_mipmap, repeat_enable;   // water_arriba.png
uniform vec3 color_somero : source_color = vec3(0.52, 0.84, 0.86);
uniform vec3 color_hondo : source_color = vec3(0.16, 0.44, 0.66);
uniform vec3 color_espuma : source_color = vec3(0.96, 0.99, 1.0);
uniform vec3 color_hielo : source_color = vec3(0.82, 0.93, 0.97);
uniform float celda = 2.3;
uniform float lado = 40.0;
uniform float tam_tex = 4.6;
uniform float ruido = 0.45;
uniform float fuerza_normal = 0.5;      // 6.16: más ondas (antes 0,35)
uniform float ancho_espuma = 0.16;
uniform float brillo = 1.0;
uniform float contraste = 1.5;
uniform vec3 sombra_tinte : source_color = vec3(0.34, 0.36, 0.46);

void fragment() {
	vec3 pm = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 c = pm.xz / celda;
	vec4 r = texture(campo, c / lado);
	vec2 uvm = (c + (r.rg - 0.5) * 2.0 * ruido) / lado;      // misma deformación que el suelo
	float dist = max(texture(orilla, uvm).r * 4.0 - 0.5, 0.0);   // casillas desde el borde de la tierra
	vec2 uv = pm.xz / tam_tex;
	// Dos muestras de la normal con rumbos y velocidades distintas: rompe la repetición.
	vec2 na = texture(normal_agua, uv + TIME * vec2(0.034, 0.019)).rg * 2.0 - 1.0;
	vec2 nb = texture(normal_agua, uv * 1.7 - TIME * vec2(0.022, 0.028)).rg * 2.0 - 1.0;
	vec2 n = (na + nb) * fuerza_normal;
	float hielo = smoothstep(0.4, 0.6, texture(estado, uvm).b);
	n *= 1.0 - hielo;                                         // el hielo está quieto
	// Claro en la orilla, hondo en el centro.
	vec3 col = mix(color_somero, color_hondo, 1.0 - exp(-dist * 0.9));
	// La pintura actual como detalle, desplazada por la onda para que "ondee".
	col *= mix(vec3(1.0), texture(t_agua, uv + n * 0.08).rgb, 0.45);
	// Espuma: banda junto a la orilla, rota por el ruido y por la onda, que avanza y retrocede.
	float borde = dist + (r.b - 0.5) * 0.15 + n.x * 0.1 + sin(TIME * 0.8 + r.g * 6.28) * 0.03;
	float espuma = 1.0 - smoothstep(0.0, ancho_espuma, borde);
	espuma *= 0.55 + 0.45 * step(0.4, fract((uv.x + uv.y) * 2.5 + TIME * 0.3 + r.r));   // a trozos
	col = mix(col, color_espuma, espuma * 0.9 * (1.0 - hielo));
	// Hielo: pálido, con la textura del agua casi apagada.
	col = mix(col, color_hielo * (0.9 + 0.2 * r.a), hielo);
	NORMAL = normalize((VIEW_MATRIX * vec4(n.x, 1.0, n.y, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(VIEW, NORMAL), 0.0, 1.0), 4.0);
	col = mix(col, vec3(0.88, 0.94, 1.0), fres * 0.25 * (1.0 - hielo));
	ALBEDO = col * brillo;
	ROUGHNESS = mix(0.18, 0.6, hielo);
	SPECULAR = 0.5;
}
void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		float luz = smoothstep(0.0, 1.0, clamp(dot(NORMAL, LIGHT) * contraste, 0.0, 1.0)) * ATTENUATION;
		DIFFUSE_LIGHT += mix(sombra_tinte, vec3(1.0), luz) * LIGHT_COLOR / PI;
	} else {
		DIFFUSE_LIGHT += max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION * LIGHT_COLOR / PI;
	}
	// Brillo del sol sobre las ondas (Blinn-Phong: al definir light() se pierde el especular del PBR).
	vec3 h = normalize(VIEW + LIGHT);
	SPECULAR_LIGHT += pow(max(dot(NORMAL, h), 0.0), mix(24.0, 90.0, 1.0 - ROUGHNESS)) * 0.5 * LIGHT_COLOR * ATTENUATION;
}
"""

## Bloque empujable (Paso 5): tapa y lado distintos por la normal en el mundo y grietas que aparecen con `danio`.
const CODIGO_BLOQUE: String = """
shader_type spatial;
uniform sampler2D t_arriba : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_lado : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_grietas : filter_linear_mipmap, repeat_enable;   // R leves · G medias · B rotura
uniform float danio = 0.0;                                           // 0 intacto ... 1 a punto de romperse
uniform vec3 color_grieta : source_color = vec3(0.25, 0.18, 0.12);
uniform float tam_tex = 2.3;
uniform float brillo = 1.0;
void fragment() {
	vec3 pm = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 nm = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	bool arriba = abs(nm.y) > 0.5;
	vec2 uv = arriba ? pm.xz / tam_tex : (abs(nm.x) > 0.5 ? pm.zy : pm.xy) / tam_tex;
	vec3 col = arriba ? texture(t_arriba, uv).rgb : texture(t_lado, uv).rgb;
	vec3 g = texture(t_grietas, uv).rgb;
	float grieta = max(max(g.r * step(0.2, danio), g.g * step(0.5, danio)), g.b * step(0.8, danio));
	ALBEDO = mix(col, color_grieta, grieta) * brillo;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""


## Decorado en lotes (MultiMesh por pieza). El prerender del Test 2D lo apaga: necesita cada pieza como nodo.
@export var decorado_por_lotes: bool = true
## Círculo de transparencia alrededor del jugador: lo que queda entre la cámara y él (árboles, setos, el puesto) se
## vuelve translúcido en ese círculo. Solo afecta al decorado en lotes y a los objetos reactivos (Ocluso3D).
@export var transparencia_jugador: bool = true
@export var radio_transparencia: float = 1.9
## Quita la parte delantera del toldo del puesto de mercado (desde la cámara tapaba al tendero).
@export var recortar_toldo: bool = true
## Hierba de todo el mapa a la vez (el prerender 2D la necesita entera). Si no, solo alrededor de la chibi.
@export var hierba_completa: bool = false
## Al empezar, tapa la pantalla un instante y lanza los seis elementos para compilar sus shaders (el prerender 2D lo apaga).
@export var precalentar_al_inicio: bool = true
## Objetos que reaccionan a los hechizos (Reactivo3D, tarea 4.7: seto, tronco, telaraña, tótems, fogatas, antorchas, puente
## y placa). El prerender del Test 2D los apaga: allí son decorado.
@export var objetos_reactivos: bool = true
## Qué nivel monta esta escena: "test2" (el laboratorio de elementos, 40×40) o "jugabilidad" (el Test de jugabilidad
## de siempre, 23×23, con sus cuatro tareas: ver jugabilidad_3d.gd). Lo elige PruebaJugabilidad3D.tscn.
@export var nivel: String = "test2"
## 7.14: qué REGLAS lleva el nivel, aparte de cuál es. "" = automático (las del Test de jugabilidad solo si
## `nivel == "jugabilidad"`), "ninguna" o "jugabilidad" (tareas, puerta final, botín, NPC que hablan y guardados, leídos de
## los marcadores del nivel). Así un nivel nuevo (Nivel_Bosque.tscn) tiene tareas sin tocar código.
@export var reglas: String = ""
## 6.10 camino A: si existe `poc_25d/niveles/<nivel>.tscn` (se crea con F9, «hornear»), el decorado y lo que bloquea salen de
## sus nodos Pieza3D y no de las letras del mapa (las letras siguen dando el suelo, los personajes y los objetos reactivos).
## Se puede editar ese .tscn en Godot: mover, girar, escalar, borrar y añadir piezas. Poner a false para volver a las letras.
@export var usar_escena: bool = true
const NIVELES: String = "res://poc_25d/niveles/"
var _modo_escena: bool = false
var _registro: Array = []       ## cada _poner: [id pedido, casilla, Transform3D, bloquea, origen "decor" | "marcador"] (lo que F9 hornea)
## 7.2: nivel editable `Nivel_<Nombre>.tscn` (suelo en GridMap, piezas instanciadas, marcadores). Si existe, MANDA sobre las letras.
var _modo_nivel: bool = false
var _nivel_raiz: Node = null           ## el .tscn instanciado (fuera del árbol: solo se lee)
var _marcas: Array = []                ## marcadores de datos: {grupo, tipo, c, giro} (botín, empujables…)
var _en_marcador: bool = false         ## true mientras se coloca algo que sale de un marcador/letra, no del decorado
var _cel_barrera: Array = []           ## casillas `B` (barrera de fuego) del mapa activo, para agruparlas en paredes (7.11)
var _muros_def: Array = []             ## paredes de fuego del nivel editable: {celdas, vertical} (de los marcadores `B` con `largo`)
var _puentes_def: Array = []           ## puentes reactivos del nivel editable (marcadores `P`): {celdas, activador (casilla o (-1,-1))}
var _celdas_pieza: Dictionary = {}     ## casillas bloqueadas por una pieza del .tscn (Vector2i -> true)
var _solidos: Node3D = null            ## cuerpos de colisión de esas piezas

var _mapa: PackedStringArray = PackedStringArray()
var _giros: Dictionary = {}                ## giros a mano del mapa activo (Jugabilidad3D.GIROS o GIROS_CELDA)
## Escala de cada marcador del nivel (.tscn), por casilla: Vector3. Solo la usan los objetos que la admiten (de momento la
## telaraña); sin entrada, escala 1. En el modo letras está vacío.
var _escalas: Dictionary = {}
## Nivel editable: la casilla del GridMap que pasa a ser la (0, 0) de la maqueta (la esquina mín. de las casillas pintadas) y
## el tamaño real (ancho × alto) del rectángulo pintado. La maqueta trabaja en un cuadrado de `_lado` = el mayor de los dos,
## con la parte sobrante vacía (letra " ": sin suelo, bloqueada). Todo el .tscn se desplaza -_origen casillas al cargarlo.
var _origen: Vector2i = Vector2i.ZERO
var _ancho: int = 0
var _alto: int = 0
var _desplaza: Vector3 = Vector3.ZERO
var _lado: int = 40
var _bloqueadas: Dictionary = {}
var _bibliotecas: Array[Node3D] = []
var _props: Node3D = null
var _efectos: Node3D = null
var _girar: Array[Node3D] = []
var _goblins: Array[Pj3D] = []
var _jugador: Pj3D = null
var _mat_agua: ShaderMaterial = null
var _mat_suelo: ShaderMaterial = null
var _img_estado: Image = null             ## 40×40 RGBA8: R quemado · G mojado · B helado · A pisado
var _tex_estado: ImageTexture = null
var _estado_sucio: bool = false
var _mojada: Dictionary = {}             ## Vector2i -> ms hasta los que la hierba no prende (la acaba de mojar el agua)
const T_MOJADA_MS: int = 8000
const RADIO_APAGAR: int = 2               ## el agua apaga en un cuadrado de (2r+1) casillas, no solo en la del impacto
var _hf: Dictionary = {}                  ## Vector2i -> {fase, t, v, frente, contagia, fx}: hierba que no es FINA
var _pisadas: Dictionary = {}             ## casillas con A > 0 (se levantan solas)
var _helada: Dictionary = {}              ## casillas de agua helada (se pueden pisar)
var _fx: Vfx3D = null
var _dir_hechizo: Vector3 = Vector3(0.0, 0.0, 1.0)
var _t_cast: float = 0.0
var _precalentando: bool = false
var externo: bool = false                 ## true: Jugador3D (Juego) mueve al jugador y Combate3D a los goblins
var _velo: Control = null
var _t_velo: float = 0.0
var _f_velo: int = 0
var _ms_velo: int = 0
var _ms_estado: float = 0.0
var _empujables: Array[MeshInstance3D] = []
var _tex_grietas: Texture2D = null
var _contraste: float = 2.5
var _rugosidad: float = 0.5     ## relieve del suelo (tecla B): 0 · 0,5 · 1
var _hierba: Hierba3D = null
var _sin_hierba: Dictionary = {}          ## casillas con runa en el suelo: la hierba no la tapa
var _img_mapa: Image = null
var _img_campo: Image = null
var _camara: Camera3D = null
var _sol: DirectionalLight3D = null
var _foco: Vector3 = Vector3.ZERO
var _tam_camara: float = ZOOM_INICIAL
var _incl: float = INCLINACION
var _hud: Label = null
var _t_hud: float = 0.0
var _avisos: PackedStringArray = PackedStringArray()
var _lotes: Dictionary = {}          ## id -> Array[Transform3D] de las copias puestas
var _plantillas: Dictionary = {}     ## id -> [[Mesh, Transform3D local, Material], ...] (vacío si no hay pieza)
var _n_lotes: int = 0
var _sombras: Array[Transform3D] = []   ## elipses de contacto de las piezas puestas en lotes (se dibujan en un solo MultiMesh)
var _reactivos: Array[Reactivo3D] = []   ## los objetos de 4.7 (para enlazar el tótem de rayo con el puente)
## Los datos del nivel (de test_2.gd o de jugabilidad_3d.gd, según `nivel`).
var _reglas: Jugabilidad3D = null        ## solo en el nivel "jugabilidad": las reglas y las tareas
var _guardados: Array = []
var _suelo_obj: Array = []
var _rotulos: Dictionary = {}
var _color_prueba: Dictionary = {}
var _empuj_def: Array = EMPUJABLES


func _ready() -> void:
	_modo_nivel = usar_escena and ResourceLoader.exists(HorneadorNivel.ruta(nivel))
	if reglas == "jugabilidad" or (reglas == "" and nivel == "jugabilidad"):
		_reglas = Jugabilidad3D.new()
		_reglas.name = "Reglas"
	if nivel == "jugabilidad":
		_mapa = Jugabilidad3D.MAPA
		_giros = Jugabilidad3D.giros()
		_guardados = Jugabilidad3D.GUARDADOS
		_empuj_def = Jugabilidad3D.empujables()
	elif nivel == "pruebas":
		_mapa = NivelPruebas.MAPA              # 7.12: el banco de pruebas (16×16); lo demás vacío
		_giros = {}
		_guardados = []
		_empuj_def = []
	elif _modo_nivel and nivel != "test2":
		# Un nivel nuevo de Pablo (Nivel_Bosque.tscn…): todo sale del .tscn. Sin esto heredaba el botín, los rótulos y los
		# colores de prueba del Test 2, puestos en las casillas del Test 2.
		_mapa = PackedStringArray()
		_giros = {}
		_guardados = []
		_empuj_def = []
	else:
		_mapa = TEST2.MAPA_TEST2
		_giros = GIROS_CELDA
		_guardados = TEST2.GUARDADOS_T2
		_suelo_obj = TEST2.SUELO_T2
		_rotulos = TEST2.ROTULOS
		_color_prueba = TEST2.COLOR_PRUEBA
	if _modo_nivel:
		_leer_nivel()
	_lado = _mapa.size()
	get_viewport().msaa_3d = Viewport.MSAA_4X

	var entorno := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.81, 0.91, 0.94)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.95, 0.94, 1.0)
	env.ambient_light_energy = LUZ_AMBIENTE
	entorno.environment = env
	add_child(entorno)

	_sol = DirectionalLight3D.new()
	_sol.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	_sol.light_color = Color(1.0, 0.96, 0.88)
	_sol.light_energy = LUZ_SOL
	_sol.shadow_enabled = true
	_sol.directional_shadow_max_distance = 30.0
	add_child(_sol)

	_props = Node3D.new()
	_props.name = "Decorado"
	add_child(_props)
	_efectos = Node3D.new()
	_efectos.name = "Efectos"
	add_child(_efectos)
	_fx = Vfx3D.new()
	_efectos.add_child(_fx)
	_fx.impacto.connect(_al_impactar)

	if transparencia_jugador and decorado_por_lotes:
		Ocluso3D.preparar()
	_cargar_bibliotecas()
	_construir_suelo()
	_modo_escena = usar_escena and not _modo_nivel and ResourceLoader.exists(_ruta_escena())
	_colocar_letras()
	_colocar_extras()
	if _modo_nivel:
		_instanciar_nivel()
	elif _modo_escena:
		_instanciar_escena()
	_colocar_empujables()
	_construir_lotes()
	_sembrar_hierba()
	_ambiente()
	for b in _bibliotecas:
		b.free()
	_bibliotecas.clear()
	# El .tscn del nivel se instancia fuera del árbol solo para leerlo: hay que liberarlo a mano. Si no, todas sus piezas,
	# mallas y marcadores se quedaban vivos hasta cerrar el juego (Godot lo avisa al parar: «mesh is null», «leaked»).
	if _nivel_raiz != null and is_instance_valid(_nivel_raiz):
		_nivel_raiz.free()
	_nivel_raiz = null

	_camara = Camera3D.new()
	_camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camara.size = _tam_camara
	_camara.near = 0.1
	_camara.far = 300.0
	add_child(_camara)
	if _jugador != null:
		_foco = _centro(_jugador)
	_colocar_camara()

	var capa := CanvasLayer.new()
	add_child(capa)
	_hud = Label.new()
	_hud.position = Vector2(12.0, 8.0)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 6)
	capa.add_child(_hud)
	_actualizar_hud()
	_precalentar(capa)
	Jugador3D.montar(self)
	if _modo_escena or _modo_nivel:
		_activar_solidez_por_nodos()
	if _reglas != null:
		add_child(_reglas)
		_reglas.iniciar(self)


## --- Utilidades de rejilla ---

func _letra(c: Vector2i) -> String:
	if c.y < 0 or c.y >= _lado or c.x < 0 or c.x >= _mapa[c.y].length():
		return "#"
	return _mapa[c.y][c.x]


func _centro_celda(c: Vector2i, y: float) -> Vector3:
	return Vector3((float(c.x) + 0.5) * S, y, (float(c.y) + 0.5) * S)


func _hash(x: int, y: int, sal: int) -> int:
	return absi((x * 73856093) ^ (y * 19349663) ^ (sal * 83492791))


func _es_agua(l: String) -> bool:
	return l == "~" or l == "b"


## Tipo de suelo de una casilla para la mezcla: 0 hierba, 1 camino, 2 tierra, 3 piedra.
func _tipo_suelo(c: Vector2i) -> int:
	var l: String = _letra(c)
	if _reglas != null or (_modo_nivel and nivel != "test2"):
		# Test de jugabilidad y niveles editables (salvo el Test 2, que conserva su aldea): el suelo sale de las letras (hierba de bosque; camino bajo la puerta, la salida y las losas).
		if l == "g" or l == "F" or l == "T" or l == "B":
			return 2
		if l == "X" or l == "E" or l == "S" or l == "p" or l == "a" or l == "w" or _es_agua(l):
			return 1
		return 0
	if l == "g" or l == "F" or l == "T" or l == "B":
		return 2
	if l == "X" or l == "E" or l == "S" or l == "n" or l == "Q" or l == "M":
		return 1
	if l == "K":
		return 3
	if _es_agua(l):
		return 1    # orilla de arena alrededor del agua
	if l == "#":
		return 0
	# El camino principal (aldea -> plaza -> puerta) y el pasillo este-oeste de la fila 16.
	if (c.x >= 18 and c.x <= 20 and c.y >= 6) or c.y == 16:
		return 1
	# La aldea y la plaza: camino con manchas de hierba.
	if c.x >= 14 and c.x <= 25 and c.y >= 7 and c.y <= 38:
		return 1 if _hash(c.x, c.y, 11) % 3 != 0 else 0
	if _hash(c.x, c.y, 12) % 11 == 0:
		return 2
	return 0


## --- Suelo ---

func _construir_suelo() -> void:
	# Mapa de tipos para el shader.
	var img := Image.create_empty(_lado, _lado, false, Image.FORMAT_RGBA8)
	for y in range(_lado):
		for x in range(_lado):
			var t: int = _tipo_suelo(Vector2i(x, y))
			img.set_pixel(x, y, Color(1.0 if t == 0 else 0.0, 1.0 if t == 1 else 0.0, 1.0 if t == 2 else 0.0, 1.0 if t == 3 else 0.0))
	_img_mapa = img
	_img_campo = _campo_ruido(_lado * 8)
	var sh := Shader.new()
	sh.code = CODIGO_SUELO
	var mat_suelo := ShaderMaterial.new()
	mat_suelo.shader = sh
	mat_suelo.set_shader_parameter("mapa", ImageTexture.create_from_image(img))
	mat_suelo.set_shader_parameter("campo", ImageTexture.create_from_image(_img_campo))
	mat_suelo.set_shader_parameter("t_hierba", _tex(SUELO + "hierba_arriba.png"))
	mat_suelo.set_shader_parameter("t_camino", _tex(SUELO + "path_arriba.png"))
	# Tierra: la nueva (tierra_arriba.png + su normal) si está; si no, la de siempre.
	var hay_tierra_nueva: bool = ResourceLoader.exists(SUELO + "tierra_arriba.png") and ResourceLoader.exists(SUELO + "tierra_arriba_normal.png")
	mat_suelo.set_shader_parameter("t_tierra", _tex(SUELO + ("tierra_arriba.png" if hay_tierra_nueva else "dirt_arriba.png")))
	if hay_tierra_nueva:
		mat_suelo.set_shader_parameter("normal_tierra", load(SUELO + "tierra_arriba_normal.png") as Texture2D)
		mat_suelo.set_shader_parameter("usa_normal_tierra", 1.0)
	mat_suelo.set_shader_parameter("t_piedra", _tex(SUELO + "stone_arriba.png"))
	mat_suelo.set_shader_parameter("celda", S)
	mat_suelo.set_shader_parameter("lado", float(_lado))
	mat_suelo.set_shader_parameter("tam_tex", S * 2.0)
	mat_suelo.set_shader_parameter("brillo", OSCURECER_SUELO)
	mat_suelo.set_shader_parameter("contraste", _contraste)
	mat_suelo.set_shader_parameter("normal_suelo", _normal_suelo())
	mat_suelo.set_shader_parameter("rugosidad", _rugosidad)
	_img_estado = Image.create_empty(_lado, _lado, false, Image.FORMAT_RGBA8)
	_img_estado.fill(Color(0.0, 0.0, 0.0, 0.0))
	_tex_estado = ImageTexture.create_from_image(_img_estado)
	mat_suelo.set_shader_parameter("estado", _tex_estado)
	_mat_suelo = mat_suelo

	var mat_lado := _mat_triplanar(SUELO + "cuerpo.png", Color(0.85, 0.66, 0.5))
	var sha := Shader.new()
	sha.code = CODIGO_AGUA
	_mat_agua = ShaderMaterial.new()
	_mat_agua.shader = sha
	_mat_agua.set_shader_parameter("orilla", ImageTexture.create_from_image(_mapa_orilla()))
	_mat_agua.set_shader_parameter("campo", mat_suelo.get_shader_parameter("campo"))
	_mat_agua.set_shader_parameter("estado", _tex_estado)
	_mat_agua.set_shader_parameter("t_agua", _tex(SUELO + "water_arriba.png"))
	_mat_agua.set_shader_parameter("normal_agua", _normal_agua())
	_mat_agua.set_shader_parameter("celda", S)
	_mat_agua.set_shader_parameter("lado", float(_lado))
	_mat_agua.set_shader_parameter("tam_tex", S * 2.0)
	_mat_agua.set_shader_parameter("brillo", OSCURECER_SUELO)
	_mat_agua.set_shader_parameter("contraste", maxf(_contraste * 0.6, 1.0))

	var tierra: Array[Transform3D] = []
	var agua: Array[Transform3D] = []
	for y in range(_lado):
		for x in range(_mapa[y].length()):
			var c := Vector2i(x, y)
			var t := Transform3D(Basis.IDENTITY, _centro_celda(c, 0.0))
			if _letra(c) == " ":
				continue          # casilla sin pintar del nivel editable: sin suelo
			if _es_agua(_letra(c)):
				agua.append(t)
			else:
				tierra.append(t)
	_multimalla(_malla_bloque(ALTO, mat_suelo, mat_lado), tierra)
	_multimalla(_malla_bloque(ALTO_AGUA, _mat_agua, mat_lado), agua)
	_construir_orillas()


## --- 6.16 ORILLA: transición agua → hierba ---
## En cada casilla de tierra pegada a una de agua (por sus 4 lados) se pone una franja de arena de ~0,22 casillas con el borde
## ondulado y, de vez en cuando, un par de piedrecitas: la hierba ya no pasa de golpe al bloque de agua. Todo en dos MultiMesh.
const COLOR_ARENA: Color = Color(0.86, 0.76, 0.56)
const ANCHO_ORILLA: float = 0.24         ## fracción de casilla


func _construir_orillas() -> void:
	var franjas: Array[Transform3D] = []
	var piedras: Array[Transform3D] = []
	var dirs: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y in range(_lado):
		for x in range(_mapa[y].length()):
			var c := Vector2i(x, y)
			if _es_agua(_letra(c)) or _letra(c) == "#" or _letra(c) == " ":
				continue
			for d in dirs:
				var v: Vector2i = d
				if not _es_agua(_letra(c + v)):
					continue
				var h: int = _hash(c.x, c.y, v.x * 3 + v.y * 5 + 11)
				var grosor: float = S * ANCHO_ORILLA * (0.8 + 0.4 * float(h % 100) / 99.0)
				var largo: float = S * (0.96 + 0.04 * float((h >> 3) % 10) / 9.0)
				# La franja está pegada al borde de la casilla que da al agua: su eje largo va a lo largo del borde.
				var centro: Vector3 = _centro_celda(c, ALTO + 0.012) + Vector3(float(v.x), 0.0, float(v.y)) * (S * 0.5 - grosor * 0.5)
				var giro: float = 0.0 if v.y != 0 else PI * 0.5
				var b := Basis(Vector3.UP, giro).scaled(Vector3(largo, 1.0, grosor))
				franjas.append(Transform3D(b, centro))
				if h % 3 == 0:
					var q: Vector3 = _centro_celda(c, ALTO) + Vector3(float(v.x), 0.0, float(v.y)) * (S * 0.5 - grosor * 0.6)
					var a: Vector3 = Vector3(float(v.y), 0.0, float(v.x)) * (float((h >> 5) % 100) / 99.0 - 0.5) * S * 0.7
					var tam: float = 0.07 + 0.05 * float((h >> 9) % 10) / 9.0
					piedras.append(Transform3D(Basis(Vector3.UP, float(h % 628) / 100.0).scaled(Vector3.ONE * tam), q + a))
	if not franjas.is_empty():
		var caja := BoxMesh.new()
		caja.size = Vector3(1.0, 0.02, 1.0)
		var m := StandardMaterial3D.new()
		m.albedo_color = COLOR_ARENA * OSCURECER_SUELO
		m.roughness = 1.0
		caja.material = m
		_multimalla(caja, franjas)
	if not piedras.is_empty():
		var roca: Mesh = (Formas3D.instancia("piedra", Color(0.7, 0.66, 0.6), 1.0) as MeshInstance3D).mesh
		_multimalla(roca, piedras)


## --- 6.16 HIELO: capa de pulido sobre el agua helada ---
## Placa translúcida y brillante, con grietas claras, y dos cristales en una esquina (como `cristal_hielo`). Se borra con la casilla.
var _placas_hielo: Dictionary = {}


func _poner_placa_hielo(c: Vector2i) -> void:
	if _placas_hielo.has(c) or not _es_agua(_letra(c)):
		return
	var raiz := Node3D.new()
	raiz.position = _centro_celda(c, ALTO_AGUA + 0.02)
	add_child(raiz)
	var placa := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(S * 0.97, 0.05, S * 0.97)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.86, 0.95, 1.0, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.08
	m.metallic = 0.0
	m.metallic_specular = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	caja.material = m
	placa.mesh = caja
	placa.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(placa)
	var h: int = _hash(c.x, c.y, 77)
	for i in range(3):
		var g := MeshInstance3D.new()
		var gm := BoxMesh.new()
		gm.size = Vector3(S * (0.35 + 0.25 * float((h >> (i * 3)) % 10) / 9.0), 0.01, 0.025)
		var mg := StandardMaterial3D.new()
		mg.albedo_color = Color(1.0, 1.0, 1.0, 0.85)
		mg.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mg.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gm.material = mg
		g.mesh = gm
		g.position = Vector3((float((h >> (i * 5)) % 100) / 99.0 - 0.5) * S * 0.4, 0.03, (float((h >> (i * 7 + 1)) % 100) / 99.0 - 0.5) * S * 0.4)
		g.rotation.y = float((h >> (i * 4)) % 314) / 100.0
		raiz.add_child(g)
	for i in range(2):
		var cr: MeshInstance3D = Formas3D.instancia("cristal", Color.WHITE, 0.3 + 0.12 * float(i))
		cr.position = Vector3(S * (0.28 - 0.1 * float(i)), 0.02, S * (0.3 - 0.06 * float(i)))
		raiz.add_child(cr)
	_placas_hielo[c] = raiz


## Distancia de cada casilla de agua a la tierra más cercana (0 = tierra), /4 para caber en un byte.
func _mapa_orilla() -> Image:
	var orilla := Image.create_empty(_lado, _lado, false, Image.FORMAT_R8)
	var dist: Dictionary = {}
	var cola: Array[Vector2i] = []
	for y in range(_lado):
		for x in range(_mapa[y].length()):
			if not _es_agua(_letra(Vector2i(x, y))):
				dist[Vector2i(x, y)] = 0
				cola.append(Vector2i(x, y))
	var i: int = 0
	while i < cola.size():
		var c: Vector2i = cola[i]
		i += 1
		for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + v
			if n.x < 0 or n.y < 0 or n.y >= _lado or n.x >= _mapa[n.y].length() or dist.has(n):
				continue
			dist[n] = int(dist[c]) + 1
			cola.append(n)
	for y in range(_lado):
		for x in range(_lado):
			orilla.set_pixel(x, y, Color(clampf(float(dist.get(Vector2i(x, y), 0)) / 4.0, 0.0, 1.0), 0.0, 0.0))
	return orilla


## Normal del agua: la pintada por Pablo (suelo_meshy/agua_normal.png) si existe; si no, ruido suave.
## Relieve del suelo: suelo_meshy/suelo_normal.png si existe; si no, ruido fino convertido a normal.
func _normal_suelo() -> Texture2D:
	if ResourceLoader.exists(SUELO + "suelo_normal.png"):
		return load(SUELO + "suelo_normal.png") as Texture2D
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.035
	n.fractal_octaves = 4
	n.fractal_lacunarity = 2.4
	n.fractal_gain = 0.55
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 10.0
	nt.noise = n
	return nt


func _normal_agua() -> Texture2D:
	if ResourceLoader.exists(SUELO + "agua_normal.png"):
		return load(SUELO + "agua_normal.png") as Texture2D
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.02
	n.fractal_octaves = 2
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 6.0
	nt.noise = n
	return nt


## Hierba con volumen encima de las casillas de hierba (y su borde ondulado). Va después del decorado
## para no crecer dentro de troncos, puestos o tótems.
func _sembrar_hierba() -> void:
	_hierba = Hierba3D.new()
	_hierba.name = "Hierba"
	_hierba.brillo = OSCURECER_SUELO
	add_child(_hierba)
	_hierba.sembrar(Rect2(0.0, 0.0, float(_lado) * S, float(_lado) * S), ALTO, _peso_hierba, not hierba_completa)
	_hierba.set_estado(_tex_estado, S, float(_lado))     # después de sembrar: es ahí donde se crean los materiales
	if not hierba_completa and _jugador != null:
		_hierba.actualizar(_jugador.position, true)     # lo que se ve al empezar, de golpe; el resto al andar


## Campo de ruido para deformar los bordes (RG), mezclar dos muestras de textura (B) y variar el tono (A).
## Ruido de valor hecho aquí (no en el shader) para que CPU y GPU vean exactamente lo mismo.
func _campo_ruido(n: int) -> Image:
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var celdas: float = float(_lado)
	for y in range(n):
		for x in range(n):
			var c := Vector2(float(x) + 0.5, float(y) + 0.5) / float(n) * celdas
			var r: float = _vruido(c * 1.7, 0) * 0.67 + _vruido(c * 4.3, 1) * 0.33
			var g: float = _vruido(c * 1.7, 2) * 0.67 + _vruido(c * 4.3, 3) * 0.33
			var b: float = _vruido(c * 0.6, 4)
			var a: float = _vruido(c * 0.35, 5) * 0.7 + _vruido(c * 1.1, 6) * 0.3
			img.set_pixel(x, y, Color(r, g, b, a))
	return img


## Ruido de valor: interpola números al azar puestos en una rejilla.
func _vruido(p: Vector2, sal: int) -> float:
	var i := Vector2i(floori(p.x), floori(p.y))
	var f: Vector2 = p - Vector2(i)
	f = f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	var a: float = _azar(i, sal)
	var b: float = _azar(i + Vector2i(1, 0), sal)
	var c: float = _azar(i + Vector2i(0, 1), sal)
	var d: float = _azar(i + Vector2i(1, 1), sal)
	return lerpf(lerpf(a, b, f.x), lerpf(c, d, f.x), f.y)


func _azar(i: Vector2i, sal: int) -> float:
	return float(_hash(i.x, i.y, sal + 40) % 10007) / 10006.0


## Lectura bilineal de una imagen como la hace la GPU (centros de texel), con o sin repetición.
func _bilineal(img: Image, uv: Vector2, repetir: bool) -> Color:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var p := Vector2(uv.x * float(w) - 0.5, uv.y * float(h) - 0.5)
	var i := Vector2i(floori(p.x), floori(p.y))
	var f: Vector2 = p - Vector2(i)
	var res := Color(0, 0, 0, 0)
	for k in range(4):
		var o := Vector2i(k % 2, floori(float(k) / 2.0))
		var q: Vector2i = i + o
		if repetir:
			q = Vector2i(posmod(q.x, w), posmod(q.y, h))
		else:
			q = Vector2i(clampi(q.x, 0, w - 1), clampi(q.y, 0, h - 1))
		var peso: float = (f.x if o.x == 1 else 1.0 - f.x) * (f.y if o.y == 1 else 1.0 - f.y)
		res += img.get_pixelv(q) * peso
	return res


## Cuánta hierba hay en un punto del mundo (0..1): lo mismo que pinta el shader del suelo.
## Nada en el agua ni dentro de casillas ocupadas por decorado (salvo los muros de árboles).
func _peso_hierba(x: float, z: float) -> float:
	var celda := Vector2i(floori(x / S), floori(z / S))
	var l: String = _letra(celda)
	if _es_agua(l) or (_bloqueadas.has(celda) and l != "#") or _sin_hierba.has(celda):
		return 0.0
	var c := Vector2(x, z) / S
	var r: Color = _bilineal(_img_campo, c / float(_lado), true)
	var uvm: Vector2 = (c + Vector2(r.r - 0.5, r.g - 0.5) * 2.0 * 0.45) / float(_lado)
	var w0: Color = _bilineal(_img_mapa, uvm, false)
	var e: float = 0.16
	var wr: float = smoothstep(0.5 - e, 0.5 + e, w0.r)
	var tot: float = wr + smoothstep(0.5 - e, 0.5 + e, w0.g) + smoothstep(0.5 - e, 0.5 + e, w0.b) \
		+ smoothstep(0.5 - e, 0.5 + e, w0.a)
	if tot < 0.05:
		return w0.r
	return wr / tot


func _tex(ruta: String) -> Texture2D:
	if ResourceLoader.exists(ruta):
		return load(ruta) as Texture2D
	_avisos.append("falta " + ruta.get_file())
	return null


func _mat_triplanar(ruta: String, color_si_falta: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.roughness = 1.0
	m.metallic_specular = 0.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var t: Texture2D = _tex(ruta)
	if t != null:
		m.albedo_texture = t
		m.albedo_color = Color(OSCURECER_SUELO, OSCURECER_SUELO, OSCURECER_SUELO)
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE / (S * 2.0)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	else:
		m.albedo_color = color_si_falta
	return m


## Un bloque de una casilla: tapa (material propio) y cuatro costados (material de tierra).
func _malla_bloque(h: float, mat_tapa: Material, mat_lado: Material) -> ArrayMesh:
	var r: float = S * 0.5
	var malla := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat_tapa)
	_quad(st, Vector3(-r, h, -r), Vector3(r, h, -r), Vector3(r, h, r), Vector3(-r, h, r), Vector3.UP)
	st.commit(malla)
	var sl := SurfaceTool.new()
	sl.begin(Mesh.PRIMITIVE_TRIANGLES)
	sl.set_material(mat_lado)
	_quad(sl, Vector3(r, 0, r), Vector3(-r, 0, r), Vector3(-r, h, r), Vector3(r, h, r), Vector3(0, 0, 1))
	_quad(sl, Vector3(r, 0, -r), Vector3(r, 0, r), Vector3(r, h, r), Vector3(r, h, -r), Vector3(1, 0, 0))
	_quad(sl, Vector3(-r, 0, -r), Vector3(r, 0, -r), Vector3(r, h, -r), Vector3(-r, h, -r), Vector3(0, 0, -1))
	_quad(sl, Vector3(-r, 0, r), Vector3(-r, 0, -r), Vector3(-r, h, -r), Vector3(-r, h, r), Vector3(-1, 0, 0))
	sl.commit(malla)
	return malla


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	for v in [a, b, c, a, c, d]:
		st.set_normal(n)
		st.set_uv(Vector2((v as Vector3).x, (v as Vector3).z))
		st.add_vertex(v as Vector3)


func _multimalla(malla: Mesh, transformaciones: Array[Transform3D]) -> void:
	if transformaciones.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = malla
	mm.instance_count = transformaciones.size()
	for i in range(transformaciones.size()):
		mm.set_instance_transform(i, transformaciones[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	add_child(mi)


## --- Decorado: bibliotecas de Meshy ---

func _cargar_bibliotecas() -> void:
	for ruta in rutas_piezas_sueltas() + BIBLIOTECAS:
		var r: String = String(ruta)
		if not ResourceLoader.exists(r):
			_avisos.append("falta " + r.get_file())
			continue
		var escena: PackedScene = load(r) as PackedScene
		if escena != null:
			_bibliotecas.append(escena.instantiate() as Node3D)


## Los GLB de meshy/piezas/ (piezas regeneradas, una por archivo, con el nodo llamado como su id).
static func rutas_piezas_sueltas() -> Array:
	var res: Array = []
	if not DirAccess.dir_exists_absolute(CARPETA_PIEZAS):
		return res
	for f in DirAccess.get_files_at(CARPETA_PIEZAS):
		var nombre: String = String(f).trim_suffix(".import").trim_suffix(".remap")
		if nombre.get_extension().to_lower() == "glb" and not res.has(CARPETA_PIEZAS + nombre):
			res.append(CARPETA_PIEZAS + nombre)
	res.sort()
	return res


## El id que se usa de verdad: la sustituta si existe en alguna biblioteca.
func _id_real(id: String) -> String:
	var nuevo: String = String(SUSTITUTAS.get(id, ""))
	if nuevo != "" and _hay_pieza(nuevo):
		# Una regenerada suelta con el id viejo (meshy/piezas/<id>.glb) gana a la sustituta.
		if _hay_pieza(id) and _en_piezas_sueltas(id):
			return id
		return nuevo
	return id


func _hay_pieza(id: String) -> bool:
	for b in _bibliotecas:
		if b.find_child(id, true, false) is Node3D:
			return true
	return false


func _en_piezas_sueltas(id: String) -> bool:
	for b in _bibliotecas:
		if String(b.scene_file_path).begins_with(CARPETA_PIEZAS) and b.find_child(id, true, false) is Node3D:
			return true
	return false


## Copia de una pieza escalada a su medida, con la base en y = 0. null si no está en ninguna biblioteca.
func _pieza(id: String) -> Node3D:
	for b in _bibliotecas:
		var n: Node = b.find_child(id, true, false)
		if n != null and n is Node3D:
			var copia: Node3D = (n as Node3D).duplicate() as Node3D
			copia.transform = Transform3D.IDENTITY
			return _normalizar(copia, id)
	if not _avisos.has("sin pieza " + id):
		_avisos.append("sin pieza " + id)
	return null


func _normalizar(modelo: Node3D, id: String) -> Node3D:
	var caja: AABB = _caja(modelo, Transform3D.IDENTITY)
	var raiz := Node3D.new()
	raiz.add_child(modelo)
	if caja.size.y <= 0.0001:
		return raiz
	var f: float = 1.0
	if MEDIDA_ANCHO.has(id):
		f = float(MEDIDA_ANCHO[id]) / maxf(caja.size.x, caja.size.z)
	else:
		f = float(MEDIDA.get(id, 1.0)) / caja.size.y
	modelo.scale *= f
	var cx: float = caja.position.x + caja.size.x * 0.5
	var cz: float = caja.position.z + caja.size.z * 0.5
	modelo.position = -Vector3(cx, caja.position.y, cz) * f
	if PLANAS.has(id):
		# Pieza plana: se entierra salvo un grosor fijo, sea cual sea el que traiga la malla (placa 0,05, baldosa 0,04).
		var grosor: float = float(PLANAS[id])
		var alto_final: float = caja.size.y * f
		if alto_final > grosor:
			modelo.position.y -= alto_final - grosor
	return raiz


func _caja(n: Node, acum: Transform3D) -> AABB:
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


## Pone una pieza en una casilla, algo desplazada, girada y con un tamaño variado para que no marque la rejilla.
func _poner(id_pedido: String, c: Vector2i, y: float, bloquea: bool, variar: bool = true, giro_fijo: float = -1.0) -> Node3D:
	var id: String = _id_real(id_pedido)
	var p: Vector3 = _centro_celda(c, y if PLANAS.has(id) else y - HUNDIR)
	var h: int = _hash(c.x, c.y, id_pedido.length())
	var escala: float = 1.0
	if variar:
		p += Vector3(float(h % 61 - 30) / 100.0, 0.0, float((h >> 6) % 61 - 30) / 100.0) * S * 0.5
		escala = 0.88 + float(h % 25) / 100.0
	var giro: float = float(_giros[c]) if _giros.has(c) else (giro_fijo if giro_fijo >= 0.0 else float(h % 360))
	_registro.append([id_pedido, c, Transform3D(Basis(Vector3.UP, deg_to_rad(giro)).scaled(Vector3.ONE * escala), p), bloquea,
		"marcador" if _en_marcador else "decor"])
	if _modo_escena or (_modo_nivel and not _en_marcador):
		return null         # el nivel viene del .tscn: lo coloca _instanciar_escena (y de ahí sale qué bloquea)
	if bloquea:
		_bloqueadas[c] = true
	if decorado_por_lotes:
		if _plantilla(id).is_empty():
			return null
		if not _lotes.has(id):
			_lotes[id] = []
		(_lotes[id] as Array).append(Transform3D(Basis(Vector3.UP, deg_to_rad(giro)).scaled(Vector3.ONE * escala), p))
		if SOMBRA_CONTACTO.has(id):
			var r: float = float(SOMBRA_CONTACTO[id]) * escala
			_sombras.append(Transform3D(Basis.IDENTITY.scaled(Vector3(r * 2.0, 1.0, r * 1.7)), Vector3(p.x, Y_DECAL - 0.005, p.z)))
		return null
	var n: Node3D = _pieza(id)
	if n == null:
		return null
	n.scale = Vector3.ONE * escala
	n.position = p
	n.rotation_degrees = Vector3(0.0, giro, 0.0)
	_props.add_child(n)
	return n


## --- Objetos que reaccionan a los hechizos (Reactivo3D, tarea 4.7) ---

## Pone un Reactivo3D con la pieza de Meshy de visual (ya no va a lotes: hace falta como nodo para tintarla).
func _reactivo_pieza(tipo: String, id_pedido: String, c: Vector2i, y: float, bloquea: bool, variar: bool = true,
		giro_fijo: float = -1.0, elemento: String = "", encendida: bool = false) -> Reactivo3D:
	var raiz: Node3D = _pieza(_id_real(id_pedido))
	if raiz == null:
		return null
	var modelo: Node3D = raiz.get_child(0) as Node3D
	raiz.remove_child(modelo)
	raiz.free()
	var p: Vector3 = _centro_celda(c, y if PLANAS.has(_id_real(id_pedido)) else y - HUNDIR)
	var h: int = _hash(c.x, c.y, id_pedido.length())
	var escala: float = 1.0
	if variar:
		p += Vector3(float(h % 61 - 30) / 100.0, 0.0, float((h >> 6) % 61 - 30) / 100.0) * S * 0.5
		escala = 0.88 + float(h % 25) / 100.0
	var giro: float = float(_giros[c]) if _giros.has(c) else (giro_fijo if giro_fijo >= 0.0 else float(h % 360))
	_registro.append([id_pedido, c, Transform3D(Basis(Vector3.UP, deg_to_rad(giro)), p), bloquea, "marcador"])    # solo el giro, para hornear
	if bloquea:
		_bloqueadas[c] = true
	# Sombra de contacto solo de los que se quedan (tótem, fogata, brasero); seto, tronco y telaraña se consumen.
	if (tipo == "totem" or tipo == "fogata" or tipo == "brasero") and SOMBRA_CONTACTO.has(_id_real(id_pedido)):
		var rs: float = float(SOMBRA_CONTACTO[_id_real(id_pedido)]) * escala
		_sombras.append(Transform3D(Basis.IDENTITY.scaled(Vector3(rs * 2.0, 1.0, rs * 1.7)), Vector3(p.x, Y_DECAL - 0.005, p.z)))
	var r: Reactivo3D = _nuevo_reactivo(tipo, c, p, modelo, elemento)
	r.scale = Vector3.ONE * escala
	r.rotation_degrees = Vector3(0.0, giro, 0.0)
	r.start_lit = encendida
	_props.add_child(r)
	return r


func _nuevo_reactivo(tipo: String, c: Vector2i, p: Vector3, visual: Node3D, elemento: String) -> Reactivo3D:
	var r := Reactivo3D.new()
	r.name = "reactivo_" + tipo
	if visual != null:
		r.add_child(visual)         # primero: el prerender saca el id de la primera hija
	r.preparar(tipo, c, elemento, _fx, visual)
	r.position = p
	r.hierba_cerca = _hierba_cerca
	r.consumido.connect(_al_consumir)
	r.activado.connect(_al_activar)
	_reactivos.append(r)
	return r


## Modelos de la telaraña (Pablo, 7/10, Tripo). Cada GLB trae DOS piezas lado a lado, que se separan al cargar por el signo de x:
##   telarana_red.glb:  x < 0 la red sana (blanca) · x > 0 la red ardiendo (brasas naranjas). 1 x 0,45 de ancho y alto.
##   telarana_base.glb: x < 0 el tronco seco sobre la roca con musgo (1 de alto) · x > 0 un tronco fino suelto (0,66).
## La BASE es decorado que se queda (la red se quema, los troncos no); la RED es el visual del Reactivo3D, con dos hijas
## "sana" y "ardiendo" que el reactivo alterna al prender y apagar.
const TELARANA_RED: String = "res://poc_25d/meshy/telarana/telarana_red.glb"
const TELARANA_BASE: String = "res://poc_25d/meshy/telarana/telarana_base.glb"
const TELARANA_ESCALA_RED: float = 3.9       ## la red sana mide 0,5 → 1,95 u: cubre la casilla entre los dos troncos
const TELARANA_ESCALA_BASE: float = 2.1      ## el tronco grande mide 1,0 → 2,1 u (el alto del cuerpo de la telaraña es 2)
static var _tel_mallas: Dictionary = {}      ## "sana" | "ardiendo" | "tronco" | "palo" -> [Mesh, AABB de la parte]
static var _tel_probado: bool = false


func _cargar_telarana() -> bool:
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
					# La AABB de la parte se mide a mano: la del ArrayMesh cuenta TODOS los vértices, también los de la otra mitad.
					caja = AABB(v[idx[t + k]], Vector3.ZERO) if not hay else caja.expand(v[idx[t + k]])
					hay = true
			t += 3
		arr[Mesh.ARRAY_INDEX] = nuevo
		res.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		res.surface_set_material(res.get_surface_count() - 1, malla.surface_get_material(si))
	return [res, caja]


## Una parte de la telaraña centrada en x/z, apoyada en y = 0 (si `al_suelo`) y escalada.
func _parte_telarana(clave: String, escala_parte: float, al_suelo: bool) -> MeshInstance3D:
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


## La telaraña: la red (reactivo, arde y se va) entre dos troncos (decorado, se quedan). Sin los modelos, la de antes:
## hilos 3D (Formas3D "telarana") en un plano de pie, radio 1.
func _poner_telarana(c: Vector2i) -> void:
	if _cargar_telarana():
		var red := Node3D.new()
		red.name = "telarana"
		var sana: MeshInstance3D = _parte_telarana("sana", TELARANA_ESCALA_RED, false)
		var ardiendo: MeshInstance3D = _parte_telarana("ardiendo", TELARANA_ESCALA_RED, false)
		ardiendo.visible = false
		for h in [sana, ardiendo]:
			var mh: MeshInstance3D = h
			mh.position.y += 1.15
			mh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			red.add_child(mh)
		# Giro y escala del marcador (nivel .tscn): se aplican a la red y a los troncos, no al Reactivo3D, para que su caja
		# de colisión siga siendo la de una casilla (la telaraña bloquea su casilla, la estires o no).
		var giro_t: float = deg_to_rad(float(_giros.get(c, 0.0)))
		var esc_t: Vector3 = _escalas.get(c, Vector3.ONE)
		red.rotation.y = giro_t
		red.scale = esc_t
		var rt: Reactivo3D = _nuevo_reactivo("telarana", c, _centro_celda(c, ALTO), red, "")
		_props.add_child(rt)
		# Los troncos, a los lados de la red (en x, el plano de la red es XY) y un poco hacia atrás.
		var base := Node3D.new()
		base.name = "telarana_base"
		base.position = _centro_celda(c, ALTO)
		base.rotation.y = giro_t
		base.scale = esc_t
		var tronco: MeshInstance3D = _parte_telarana("tronco", TELARANA_ESCALA_BASE, true)
		tronco.position += Vector3(-S * 0.42, 0.0, -0.15)
		var palo: MeshInstance3D = _parte_telarana("palo", TELARANA_ESCALA_BASE * 1.25, true)
		palo.position += Vector3(S * 0.43, 0.0, -0.1)
		base.add_child(tronco)
		base.add_child(palo)
		_props.add_child(base)
		return
	var s3: MeshInstance3D = Formas3D.instancia("telarana", Color(0.93, 0.93, 0.97))
	s3.name = "telarana"
	s3.position = Vector3(0.0, 1.0, 0.0)
	var r: Reactivo3D = _nuevo_reactivo("telarana", c, _centro_celda(c, ALTO), s3, "")
	_props.add_child(r)


## El puente plegable de la cámara de rayo: levantado contra la orilla oeste (bloquea la casilla) hasta que lo tiende el
## tótem de rayo. La bisagra es el borde oeste de la casilla.
func _poner_puente(c: Vector2i) -> void:
	var raiz: Node3D = _pieza(_id_real("puente"))
	if raiz == null:
		return
	var modelo: Node3D = raiz.get_child(0) as Node3D
	raiz.remove_child(modelo)
	raiz.free()
	var cuerpo := Node3D.new()
	cuerpo.name = "puente"
	cuerpo.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	cuerpo.position = Vector3(S * 0.5, 0.0, 0.0)
	cuerpo.add_child(modelo)
	var bisagra: Vector3 = _centro_celda(c, ALTO_AGUA + 0.05) - Vector3(S * 0.5, 0.0, 0.0)
	_bloqueadas[c] = true
	var r: Reactivo3D = _nuevo_reactivo("puente", c, bisagra, cuerpo, "")
	_props.add_child(r)


## El tótem de rayo tiende el puente (nivel_base._on_interruptor).
func _enlazar_reactivos() -> void:
	var puente: Reactivo3D = null
	for r in _reactivos:
		if r.tipo == "puente":
			puente = r
	for r in _reactivos:
		if r.tipo == "totem" and r.elemento == "rayo" and puente != null:
			r.activado.connect(func(_t: String, _e: String) -> void: puente.tender())


## Bloqueo / desbloqueo EN JUEGO de una casilla (tierra que se solidifica, hielo, puente, puerta…): siempre por aquí y no
## tocando `_bloqueadas` a mano. Por qué: con el nivel en .tscn la solidez la contesta la fuente de colisión del Lanzador
## (6.10) y esta se enteraría de los cambios solo a través de `bloquear_celda` / `liberar_celda`. El diccionario se sigue
## manteniendo porque la hierba, los NPC y el reparto de objetos lo leen.
func _bloquear(c: Vector2i) -> void:
	_bloqueadas[c] = true
	if Lanzador3D.mundo_s == self:
		Lanzador3D.bloquear_celda(c)


func _liberar(c: Vector2i) -> void:
	_bloqueadas.erase(c)
	if Lanzador3D.mundo_s == self:
		Lanzador3D.liberar_celda(c)


func _al_consumir(c: Vector2i) -> void:
	_liberar(c)


func _al_activar(tipo: String, _elemento: String) -> void:
	if tipo == "puente":
		for r in _reactivos:
			if is_instance_valid(r) and r.tipo == "puente":
				_liberar(r.celda)


## Lo que el fuego de un objeto hace a la hierba (combustible.gd contagia a TODO lo que arde a ≤ 110 px cada 0,8 s):
## prende la hierba fina o crecida de alrededor, y con viento solo la de su cono.
func _hierba_cerca(pos: Vector3, radio: float, viento: Vector3) -> void:
	var c0: Vector2i = _celda_de(pos)
	var r: int = ceili(radio / S)
	for y in range(c0.y - r, c0.y + r + 1):
		for x in range(c0.x - r, c0.x + r + 1):
			var q := Vector2i(x, y)
			if not _en_mapa(q) or not _es_hierba(q):
				continue
			var d: Vector3 = _centro_celda(q, pos.y) - pos
			d.y = 0.0
			if d.length() > radio:
				continue
			if viento != Vector3.ZERO and d.length() > 0.01 and d.normalized().dot(viento.normalized()) < 0.3:
				continue
			var f: int = int((_hf[q] as Dictionary)["fase"]) if _hf.has(q) else 0
			if f == 0 or f == Fase.CRECIDA:
				_poner_fase(q, Fase.PRENDIENDO)


## El objeto que arde más cercano al centro de una casilla de hierba, si el frente de contagio (en casillas) lo toca.
func _objeto_al_alcance(c: Vector2i, frente: float) -> Reactivo3D:
	var mejor: Reactivo3D = null
	var dm: float = frente
	var centro: Vector3 = _centro_celda(c, ALTO)
	for n in get_tree().get_nodes_in_group(Reactivo3D.GRUPO_ARDE):
		var o: Reactivo3D = n as Reactivo3D
		if o == null or not o.can_burn():
			continue
		var d: Vector3 = o.global_position - centro
		d.y = 0.0
		var dc: float = d.length() / S
		if dc <= dm:
			dm = dc
			mejor = o
	return mejor


## Los tags de cada elemento (contrato on_spell_hit, diario 2026-10-06 00:50). El Lanzador3D usará los .tres del 2D.
const TAGS_ELEMENTO: Dictionary = {
	"fuego": ["fuego", "calor"], "agua": ["agua"], "tierra": ["tierra"], "viento": ["viento"],
	"rayo": ["rayo", "electrico"], "hielo": ["hielo", "frio"],
}


## Lo que hará el Lanzador3D (4.1) con CAPA_REACTIVO: avisa a los objetos reactivos de la casilla del impacto. Mientras
## el Lanzador no exista, F1–F6 pasan por aquí para poder probar los objetos.
func _golpear_objetos(elemento: String, punto: Vector3) -> void:
	if externo or not objetos_reactivos:    # con Lanzador3D (externo) los golpes llegan por on_spell_hit
		return
	var runa := RuneData.new()
	runa.display_name = elemento
	var tags: Array[String] = []
	for t in TAGS_ELEMENTO.get(elemento, []):
		tags.append(String(t))
	runa.tags = tags
	Lanzador3D.ultimo_impacto = punto
	for n in get_tree().get_nodes_in_group(Reactivo3D.GRUPO_REACTIVO):
		var o: Reactivo3D = n as Reactivo3D
		if o == null or not is_instance_valid(o) or o.collision_layer == 0:
			continue
		var d: Vector3 = o.global_position - punto
		d.y = 0.0
		if d.length() > S * 0.6:
			continue
		if o.spell_reacts(runa, _dir_hechizo):
			o.on_spell_hit(runa, _dir_hechizo)
	Lanzador3D.ultimo_impacto = Vector3.INF


## Las mallas de una pieza ya medida (como la deja _pieza), con su transformación respecto a la base.
func _plantilla(id: String) -> Array:
	if _plantillas.has(id):
		return _plantillas[id]
	var res: Array = []
	var n: Node3D = _pieza(id)
	if n != null:
		_mallas_de(n, Transform3D.IDENTITY, res)
		n.free()
	for parte in res:
		var malla: Mesh = parte[0] as Mesh
		if recortar_toldo and id == "puesto_mercado":
			malla = Ocluso3D.recortar_toldo(malla)
		if transparencia_jugador:
			malla = Ocluso3D.malla_con_hueco(malla)
			if parte[2] != null:
				parte[2] = Ocluso3D.convertir(parte[2] as Material)
		parte[0] = malla
	_plantillas[id] = res
	return res


func _mallas_de(n: Node, acum: Transform3D, res: Array) -> void:
	var t: Transform3D = acum
	if n is Node3D:
		t = acum * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mi: MeshInstance3D = n as MeshInstance3D
		var malla: Mesh = mi.mesh
		# Materiales puestos en el nodo (no en la malla): se copian a una malla propia para el MultiMesh.
		var con_nodo: bool = false
		for i in range(malla.get_surface_count()):
			if mi.get_surface_override_material(i) != null:
				con_nodo = true
		if con_nodo:
			malla = malla.duplicate() as Mesh
			for i in range(malla.get_surface_count()):
				var m: Material = mi.get_surface_override_material(i)
				if m != null:
					malla.surface_set_material(i, m)
		res.append([malla, t, mi.material_override])
	for h in n.get_children():
		_mallas_de(h, t, res)


## Un MultiMesh por pieza, malla y TROZO del mapa (BLOQUE_LOTE x BLOQUE_LOTE): centenares de nodos -> unas
## decenas de llamadas, y cada trozo con su caja para que Godot no dibuje (ni sombree) lo que queda fuera de cámara.
const BLOQUE_LOTE: float = S * 7.0

func _construir_lotes() -> void:
	for id in _lotes:
		var trozos: Dictionary = {}
		for t in (_lotes[id] as Array):
			var o: Vector3 = (t as Transform3D).origin
			var k := Vector2i(floori(o.x / BLOQUE_LOTE), floori(o.z / BLOQUE_LOTE))
			if not trozos.has(k):
				trozos[k] = []
			(trozos[k] as Array).append(t)
		for k in trozos:
			var copias: Array = trozos[k]
			for parte in _plantilla(String(id)):
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = parte[0] as Mesh
				mm.instance_count = copias.size()
				var local: Transform3D = parte[1]
				for i in range(copias.size()):
					mm.set_instance_transform(i, (copias[i] as Transform3D) * local)
				var mi := MultiMeshInstance3D.new()
				mi.name = "lote_%s_%d_%d" % [String(id), k.x, k.y]
				mi.multimesh = mm
				if SIN_SOMBRA.has(String(id)):
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if parte[2] != null:
					mi.material_override = parte[2] as Material
				_props.add_child(mi)
				_n_lotes += 1
	_construir_sombras()


## Un solo MultiMesh con la elipse de contacto de todas las piezas en pie (una llamada de dibujo).
func _construir_sombras() -> void:
	if _sombras.is_empty():
		return
	var sh := Shader.new()
	sh.code = CODIGO_SOMBRA
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.render_priority = -1       # primero: el resto de decals y la hierba se dibujan encima
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	q.orientation = PlaneMesh.FACE_Y
	q.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = q
	mm.instance_count = _sombras.size()
	for i in range(_sombras.size()):
		mm.set_instance_transform(i, _sombras[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = "sombras_contacto"
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_efectos.add_child(mi)


## Hielo = la textura del agua desaturada y aclarada (no hay textura de hielo propia).
func _textura_hielo(agua: Texture2D) -> Texture2D:
	if agua == null:
		return null
	var img: Image = agua.get_image()
	if img == null:
		return agua
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(256, 256)
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c: Color = img.get_pixel(x, y)
			var g: float = c.get_luminance()
			img.set_pixel(x, y, Color(lerpf(c.r, g, 0.75), lerpf(c.g, g, 0.7), lerpf(c.b, g, 0.55)).lightened(0.35))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Bloques empujables de tierra y hielo: cubos con tapa y lado distintos y grietas (CODIGO_BLOQUE). Las texturas
## definitivas (tierra_lado, hielo_arriba, hielo_lado, grietas en suelo_meshy/) son opcionales: sin ellas se usa
## la del suelo, el agua desaturada y unas grietas hechas con ruido.
func _colocar_empujables() -> void:
	for e in _empuj_def:
		var tipo: String = String(e[0])
		var c: Vector2i = e[1]
		var lado: float = S * 0.62
		var caja := BoxMesh.new()
		caja.size = Vector3(lado, lado, lado)
		var m := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = CODIGO_BLOQUE
		m.shader = sh
		if tipo == "hielo":
			var agua: Texture2D = _tex(SUELO + "water_arriba.png")
			var base: Texture2D = _tex_o(SUELO + "hielo_arriba.png", _textura_hielo(agua))
			m.set_shader_parameter("t_arriba", base)
			m.set_shader_parameter("t_lado", _tex_o(SUELO + "hielo_lado.png", base))
			m.set_shader_parameter("color_grieta", Color(0.9, 0.97, 1.0))
		else:
			m.set_shader_parameter("t_arriba", _tex(SUELO + "dirt_arriba.png"))
			m.set_shader_parameter("t_lado", _tex_o(SUELO + "tierra_lado.png", _tex(SUELO + "cuerpo.png")))
		m.set_shader_parameter("t_grietas", _grietas())
		m.set_shader_parameter("danio", 0.0)
		m.set_shader_parameter("brillo", OSCURECER_SUELO)
		caja.material = m
		var mi := MeshInstance3D.new()
		mi.name = "empujable_" + tipo
		mi.mesh = caja
		mi.position = Vector3(0.0, lado * 0.5, 0.0)
		var raiz := Node3D.new()           # misma forma que las piezas (raíz + modelo): el prerender 2D la recorta
		raiz.position = _centro_celda(c, ALTO)
		raiz.add_child(mi)
		_props.add_child(raiz)
		_bloqueadas[c] = true
		_empujables.append(mi)


## La textura si existe; si no, el sustituto (sin avisar: son texturas que aún no se han entregado).
func _tex_o(ruta: String, sustituta: Texture2D) -> Texture2D:
	if ResourceLoader.exists(ruta):
		return load(ruta) as Texture2D
	return sustituta


## Grietas: R leves, G medias, B rotura. La de Pablo (suelo_meshy/grietas.png) o tres redes de celdas con ruido.
func _grietas() -> Texture2D:
	if _tex_grietas != null:
		return _tex_grietas
	if ResourceLoader.exists(SUELO + "grietas.png"):
		_tex_grietas = load(SUELO + "grietas.png") as Texture2D
		return _tex_grietas
	var canales: Array[Image] = []
	for i in range(3):
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
		n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB      # 0 en los bordes entre celdas = grieta
		n.frequency = 0.018 + 0.012 * float(i)
		n.seed = 11 + i * 7
		canales.append(n.get_image(256, 256, false, false, true))
	var img := Image.create_empty(256, 256, true, Image.FORMAT_RGB8)
	for y in range(256):
		for x in range(256):
			var col := Color(0.0, 0.0, 0.0)
			for i in range(3):
				col[i] = 1.0 - smoothstep(0.06, 0.17 + 0.01 * float(i), canales[i].get_pixel(x, y).r)
			img.set_pixel(x, y, col)
	img.generate_mipmaps()
	_tex_grietas = ImageTexture.create_from_image(img)
	return _tex_grietas


## Tecla V: sube el daño del empujable más cercano a la chibi (0 → 0,34 → 0,68 → 1 → de nuevo 0).
func _danar_empujable_cercano() -> void:
	if _jugador == null or _empujables.is_empty():
		return
	var mejor: MeshInstance3D = null
	var dmin: float = 1.0e9
	for e in _empujables:
		var d: float = e.global_position.distance_to(_jugador.position)
		if d < dmin:
			dmin = d
			mejor = e
	var m: ShaderMaterial = (mejor.mesh as BoxMesh).material as ShaderMaterial
	var v0: Variant = m.get_shader_parameter("danio")
	var d0: float = float(v0) if v0 != null else 0.0
	m.set_shader_parameter("danio", 0.0 if d0 > 0.9 else minf(d0 + 0.34, 1.0))


## --- Lo que pide cada letra del plano ---

func _colocar_letras() -> void:
	# "matas" y "flores" de Meshy salieron mal (rocas de cristal y bolas): retiradas, las pone Hierba3D.
	# "caja_cristal" también: los empujables son cubos (_colocar_empujables).
	var decor: Array = ["arbusto", "arbusto_flores", "piedras", "setas", "tocon", "arbusto", "piedras"]
	for y in range(_lado):
		for x in range(_mapa[y].length()):
			var c := Vector2i(x, y)
			var l: String = _letra(c)
			var h: int = _hash(x, y, 3)
			_en_marcador = not "#~.".contains(l)      # pared, agua y suelo son decorado; el resto sale de un marcador
			match l:
				" ":
					_bloqueadas[c] = true          # fuera de lo pintado: no se pisa
				"#":
					if not (_modo_escena or _modo_nivel) or x == 0 or y == 0 or x == _mapa[y].length() - 1 or y == _lado - 1:
						_bloqueadas[c] = true      # en modo escena el borde sigue cerrado; el resto lo deciden las piezas del .tscn
					if h % 6 == 0:
						_poner("arbusto" if h % 2 == 0 else "roca_grande", c, ALTO, true)
					else:
						# Toda casilla de pared lleva un árbol: antes 1 de cada 4 quedaba sin modelo y era un hueco que parecía
						# paso pero bloqueaba (pared invisible). Juego, 2026-10-06.
						_poner("arbol_redondo" if h % 3 != 0 else "pino", c, ALTO, true)
				"~":
					_bloqueadas[c] = true
					if h % 9 == 0:
						_poner("juncos", c, ALTO_AGUA, false)
				"b":
					if objetos_reactivos:
						_poner_puente(c)
					else:
						_poner("puente", c, ALTO_AGUA + 0.05, false, false, 90.0)
				"z":
					if objetos_reactivos:
						_reactivo_pieza("seto", "seto_seco", c, ALTO, true)
					else:
						_poner("seto_seco", c, ALTO, true)
				"l":
					if objetos_reactivos:
						_reactivo_pieza("tronco", "tronco", c, ALTO, true)
					else:
						_poner("tronco", c, ALTO, true)
				"h":
					_poner("setas", c, ALTO, false)
				"r":
					_bloqueadas[c] = true
					if objetos_reactivos:
						_poner_telarana(c)
					else:
						_cartel_plano(VFX + "telarana.png", _centro_celda(c, ALTO + 1.0), 2.0, false, Color.WHITE)
				"j", "k", "i":
					var el: String = {"j": "fuego", "k": "agua", "i": "rayo"}[l]
					if objetos_reactivos:
						_reactivo_pieza("totem", "totem_runico", c, ALTO, true, false, 0.0, el)
					else:
						_poner("totem_runico", c, ALTO, true, false, 0.0)
						var col: Color = COLOR_ELEMENTO[el]
						_disco(VFX + "circulo_runico.png", _centro_celda(c, Y_DECAL), S * 1.1, col)
						_luz(_centro_celda(c, ALTO + 1.4), col, 1.0, 3.5)
				"B":
					# Barrera de fuego: la casilla bloquea (el Lanzador pone una BarreraFuego por casilla) y su fuego se dibuja luego
					# como UNA pared por tramo recto (_colocar_barreras_fuego), no una llama por casilla (7.11).
					_bloqueadas[c] = true
					_cel_barrera.append(c)
				"F":
					if objetos_reactivos:
						_reactivo_pieza("fogata", "fogata", c, ALTO, true, false, -1.0, "", true)
					else:
						_poner("fogata", c, ALTO, true, false)
						_fuego(_centro_celda(c, ALTO + 0.1), false)
				"T":
					if objetos_reactivos:
						_reactivo_pieza("brasero", "brasero", c, ALTO, true, false)
					else:
						_poner("brasero", c, ALTO, true, false)
						_fuego(_centro_celda(c, ALTO + 1.25), false, 0.6)
				"n", "Q":
					var tendero: Pj3D = poner_puesto(c, PJ_LIBRERA if l == "n" else PJ_ALQUIMISTA)
					if _reglas != null:
						_reglas.registrar_npc("librera" if l == "n" else "alquimista", tendero)
				"M":
					_npc(PJ_LIBRERA, _centro_celda(c, ALTO))
					_bloqueadas[c] = true
				"m":
					# Guardabosques (el que habla en el Test de jugabilidad): la regla le pone nombre y diálogo.
					var gb: Pj3D = _npc(PJ_GUARDABOSQUES, _centro_celda(c, ALTO))
					_bloqueadas[c] = true
					if _reglas != null:
						_reglas.registrar_npc("guardabosques", gb)
				"p", "a", "w":
					# Losas del suelo (contacto, desbloqueo de agua y de viento): las pinta y vigila la regla.
					_sin_hierba[c] = true
					if _reglas != null:
						_reglas.registrar_losa(l, c)
				"D":
					_poner("dummy", c, ALTO, true, false, 0.0)
				"s", "f", "q":
					var planta: String = {"s": "seta_reactiva", "f": "flor_reactiva", "q": "raiz_reactiva"}[l]
					_poner(planta, c, ALTO, true)
					_esporas(_centro_celda(c, ALTO + 0.5))
				"A", "W":
					var quien: Array = PJ_GOBLIN
					if l == "A":
						quien = PJ_ARQUERO if _reglas != null else PJ_ESPADACHIN
					var g: Pj3D = _personaje(quien, _centro_celda(c, ALTO))
					if g != null:
						_goblins.append(g)
				"X":
					# El arco nuevo (arco_ruina, mercado.glb) ya tiene la abertura hacia la cámara; el viejo
					# (arco_puerta, objetos.glb) la tiene a +-X y hay que girarlo. Se cruza de norte a sur.
					var arco: String = _id_real("arco_puerta")
					var giro_arco: float = 0.0 if arco == "arco_ruina" else 90.0
					if _reglas != null:
						giro_arco += 90.0       # la puerta del test de jugabilidad se cruza de oeste a este
					_poner(arco, c, ALTO, false, false, giro_arco)
				"E":
					_poner("portal_salida", c, ALTO, false, false, 0.0)
					_destellos(_centro_celda(c, ALTO + 1.5), Color(0.75, 0.9, 1.0))
				"K":
					if objetos_reactivos:
						_reactivo_pieza("placa", "placa_peso", c, ALTO, false, false)
					else:
						_poner("placa_peso", c, ALTO, false, false)
				"S":
					_jugador = _personaje(PJ_JUGADOR, _centro_celda(c, ALTO))
				".":
					if h % 9 == 0 and _tipo_suelo(c) == 0 and nivel != "pruebas":      # el banco de pruebas va limpio
						_poner(String(decor[_hash(x, y, 5) % decor.size()]), c, ALTO, false)

	_en_marcador = false
	_colocar_barreras_fuego()
	_enlazar_reactivos()
	_colocar_puentes_reactivos()


## Puentes reactivos (marcador `P`): una fila de losas bajo el agua que sube cuando se activa el marcador enlazado. El color de
## las runas es el del elemento del activador (cian si no tiene). Por qué la casilla pasa a letra `b`: el resto del juego (altura
## del jugador y goblins, hielo, agua) decide por la letra; así la casilla ya es puente y no agua.
func _colocar_puentes_reactivos() -> void:
	for d in _puentes_def:
		var celdas: Array = (d as Dictionary)["celdas"]
		var centros: Array = []
		for c in celdas:
			centros.append(_centro_celda(c, ALTO_AGUA))
		var act: Reactivo3D = null
		for r in _reactivos:
			if is_instance_valid(r) and r.celda == ((d as Dictionary)["activador"] as Vector2i):
				act = r
		var color: Color = Color(0.2, 0.9, 1.0)
		if act != null and Vfx3D.COLOR.has(act.elemento):
			color = Vfx3D.COLOR[act.elemento]
		var pr := PuenteReactivo3D.new()
		pr.name = "puente_reactivo"
		_props.add_child(pr)
		pr.preparar(celdas, centros, ALTO_AGUA + 0.12, ALTO_AGUA, _fx, color)
		pr.losa_lista.connect(_al_tender_losa)
		if act != null:
			act.activado.connect(func(_t: String, _e: String) -> void: pr.tender(act.global_position))
		elif (d as Dictionary)["activador"] != Vector2i(-1, -1):
			_avisos.append("puente reactivo: no hay objeto reactivo en la casilla %s" % str((d as Dictionary)["activador"]))


func _al_tender_losa(c: Vector2i) -> void:
	_mapa[c.y] = _mapa[c.y].substr(0, c.x) + "b" + _mapa[c.y].substr(c.x + 1)
	_liberar(c)


## 7.11: una pared de fuego continua por cada tramo recto de barrera (letras `B` contiguas, o un marcador `B` con `largo`).
## La luz y las brasas van dentro de la pared (Vfx3D.fuego_pared); `apagar_tramo` la parte cuando el agua apaga una casilla.
func _colocar_barreras_fuego() -> void:
	var tramos: Array = _muros_def if _modo_nivel else HorneadorNivel.tramos_barrera(_cel_barrera)
	for t in tramos:
		var td: Dictionary = t
		var celdas: Array = td["celdas"]
		var centros: Array = []
		for ce in celdas:
			centros.append(_centro_celda(ce as Vector2i, ALTO))
		_fx.fuego_pared(celdas, centros, Vector3.BACK if bool(td["vertical"]) else Vector3.RIGHT, S)


## --- 6.10 camino A: nivel editable (.tscn con nodos Pieza3D) ---

func _ruta_escena() -> String:
	return NIVELES + nivel + ".tscn"


## Transform de `n` respecto a `raiz` (el .tscn instanciado no está en el árbol: no hay global_transform).
func _transform_en(n: Node3D, raiz: Node) -> Transform3D:
	var t: Transform3D = n.transform
	var padre: Node = n.get_parent()
	while padre != null and padre != raiz and padre is Node3D:
		t = (padre as Node3D).transform * t
		padre = padre.get_parent()
	return t


## Lee las Pieza3D del .tscn del nivel y hace con ellas lo mismo que _poner: lotes de decorado, sombra de contacto y casilla
## bloqueada (la que contiene su posición). Lo que el Lanzador llama «huellas» sale de aquí sin cambios (calcular_huellas lee _lotes).
func _instanciar_escena() -> void:
	var ps: PackedScene = load(_ruta_escena()) as PackedScene
	if ps == null:
		_avisos.append("no se pudo cargar " + _ruta_escena())
		_modo_escena = false
		return
	var raiz: Node = ps.instantiate()
	var colocadas: int = 0
	for n in raiz.find_children("*", "Pieza3D", true, false):
		var pz: Pieza3D = n as Pieza3D
		var id_pedido: String = pz.id
		var id: String = _id_real(id_pedido)
		var t: Transform3D = _transform_en(pz, raiz)
		var p: Vector3 = t.origin
		var escala: float = t.basis.get_scale().x
		if pz.bloquea:
			var cp: Vector2i = _celda_de(p)
			_bloqueadas[cp] = true
			_celdas_pieza[cp] = true
			_poner_colision(id_pedido, t)
		if decorado_por_lotes:
			if _plantilla(id).is_empty():
				continue
			if not _lotes.has(id):
				_lotes[id] = []
			(_lotes[id] as Array).append(t)
			if SOMBRA_CONTACTO.has(id):
				var r: float = float(SOMBRA_CONTACTO[id]) * escala
				_sombras.append(Transform3D(Basis.IDENTITY.scaled(Vector3(r * 2.0, 1.0, r * 1.7)), Vector3(p.x, Y_DECAL - 0.005, p.z)))
		else:
			var nodo: Node3D = _pieza(id)
			if nodo == null:
				continue
			nodo.transform = t
			_props.add_child(nodo)
		colocadas += 1
	raiz.free()
	print("Nivel desde ", _ruta_escena(), ": ", colocadas, " piezas")


## El cuerpo sólido de una pieza que bloquea, en la capa CAPA_SOLIDO del Lanzador. Es lo que lee la fuente de solidez por
## nodos: «lo que se ve es lo que choca». La escala del nodo se aplica a mano a la forma (un StaticBody con escala no uniforme
## deforma la colisión), y solo se respeta el giro en Y.
func _poner_colision(id_pedido: String, t: Transform3D) -> void:
	if _solidos == null:
		_solidos = Node3D.new()
		_solidos.name = "Solidos"
		add_child(_solidos)
	var f: Dictionary = Pieza3D.forma_colision(id_pedido)
	var k: float = t.basis.get_scale().x
	var cuerpo := StaticBody3D.new()
	cuerpo.collision_layer = Lanzador3D.CAPA_SOLIDO
	cuerpo.collision_mask = 0
	cuerpo.add_to_group("bloquea")
	cuerpo.position = t.origin
	cuerpo.rotation.y = t.basis.orthonormalized().get_euler().y
	var forma := CollisionShape3D.new()
	if bool(f["cilindro"]):
		var cil := CylinderShape3D.new()
		cil.radius = float(f["radio"]) * k
		cil.height = float(f["alto"]) * k
		forma.shape = cil
	else:
		var caja := BoxShape3D.new()
		caja.size = (f["tam"] as Vector3) * k
		forma.shape = caja
	forma.position = (f["centro"] as Vector3) * k
	cuerpo.add_child(forma)
	_solidos.add_child(cuerpo)


## Con el nivel en .tscn la solidez pasa a ser la de la colisión real (Lanzador3D.activar_fuente_nodos). El motor de física
## no ve los cuerpos recién creados hasta un par de fotogramas de física, por eso se espera. Hasta entonces manda el diccionario.
## Lo que NO es una pieza del .tscn (agua, borde, NPC, objetos reactivos, la puerta…) sigue en `_bloqueadas` y se traspasa
## a la fuente como bloqueo «extra», para que la fuente por nodos lo vea igual que antes.
func _activar_solidez_por_nodos() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree() or Lanzador3D.mundo_s != self:
		return
	var n: int = Lanzador3D.activar_fuente_nodos(self)
	if n == 0 and not _celdas_pieza.is_empty():
		push_warning("PruebaTest2: la física no ve las piezas del nivel; vuelvo a la solidez por casillas.")
		Lanzador3D.activar_fuente_casillas()
		return
	for c in _bloqueadas.keys():
		if not _celdas_pieza.has(c):
			Lanzador3D.bloquear_celda(c)
	print("Solidez por colisión: ", n, " casillas de piezas, ", _bloqueadas.size() - _celdas_pieza.size(), " extra")


## F9: hornea lo que las letras han colocado como `niveles/Nivel_<Nombre>.tscn` (ver HorneadorNivel). Con el nivel ya cargado
## desde su .tscn no hace nada: ese archivo manda y tiene tus ediciones. Para volver a generarlo desde las letras (PISA las
## ediciones; la versión anterior se aparta como `..._copia_<hora>.tscn`): poner `usar_escena = false` y pulsar F9.
func hornear() -> String:
	if _modo_nivel or _modo_escena:
		print("Hornear: este nivel ya se ha cargado de su .tscn, que manda sobre las letras. Para regenerarlo desde las letras (pisa las ",
			"ediciones) desmarca `usar_escena` en PruebaTest2 y vuelve a pulsar F9.")
		return ""
	var extras: Array = []
	if _reglas != null:
		for r in Jugabilidad3D.RECOGIBLES:
			extras.append({"grupo": "recogible", "tipo": String(r[0]), "c": Vector2i(int(r[1]), int(r[2]))})
		extras.append({"letra": "n", "c": Jugabilidad3D.PUESTO_CELDA})
		extras.append({"letra": "Q", "c": Jugabilidad3D.PUESTO_CELDA + Vector2i(0, 3)})
		# Los setos sueltos de las reglas (no son letras del mapa): los que de verdad se pusieron, que ya constan en el registro.
		for r in _registro:
			var rd: Array = r
			var c_seto: Vector2i = rd[1]
			if String(rd[0]) == "seto_seco" and String(rd[4]) == "marcador" and _letra(c_seto) == ".":
				extras.append({"letra": "z", "c": c_seto})
	for e in _empuj_def:
		extras.append({"grupo": "empujable", "tipo": String(e[0]), "c": e[1] as Vector2i})
	if nivel == "pruebas":
		for e in NivelPruebas.piezas():
			extras.append({"rotulo": String(e[0]), "c": e[1] as Vector2i})
	var datos: Dictionary = {"nivel": nivel, "mapa": _mapa, "registro": _registro, "extras": extras}
	return HorneadorNivel.hornear(datos)


## --- 7.2: el nivel editable (Nivel_<Nombre>.tscn) ---

## Contrato con el Juego (7.5): el rectángulo del nivel en casillas DEL MUNDO de la maqueta. En un nivel editable es el
## rectángulo pintado del GridMap (puede no ser cuadrado), ya desplazado para que empiece en (0, 0): la maqueta mueve el .tscn
## entero -`origen_nivel()` casillas al cargarlo, así `_lado`, `_celda_de` y `centro_de` del Lanzador siguen valiendo.
## Con las letras, el cuadrado de siempre.
func limites() -> Rect2i:
	if _modo_nivel and _ancho > 0 and _alto > 0:
		return Rect2i(0, 0, _ancho, _alto)
	return Rect2i(0, 0, _lado, _lado)


## La casilla del GridMap del .tscn que es la (0, 0) del mundo (para pasar de casillas del editor a casillas del juego:
## juego = editor - origen_nivel()). Con las letras, (0, 0).
func origen_nivel() -> Vector2i:
	return _origen if _modo_nivel else Vector2i.ZERO


## Transform de un nodo del .tscn en el mundo de la maqueta: respecto a la raíz del nivel y desplazado -_origen casillas.
func _t_nivel(n: Node3D) -> Transform3D:
	var t: Transform3D = _transform_en(n, _nivel_raiz)
	t.origin += _desplaza
	return t


## ¿Esta pieza (id y cuerpo) está bajo un nodo con ese nombre? (Piezas / Borde)
func _bajo(n: Node, nombre: String, raiz: Node) -> bool:
	var p: Node = n.get_parent()
	while p != null and p != raiz:
		if String(p.name) == nombre:
			return true
		p = p.get_parent()
	return false


## La letra de `c` en unas filas de texto (las del nivel que se está leyendo); fuera, " ".
static func _letra_en(filas: Array, c: Vector2i) -> String:
	if c.y < 0 or c.y >= filas.size() or c.x < 0 or c.x >= (filas[c.y] as String).length():
		return " "
	return (filas[c.y] as String)[c.x]


## Recorre el .tscn y da todas las piezas (nodos con metadato `id`; no se baja dentro de ellas).
func _piezas_de(n: Node, fuera: Array) -> void:
	for h in n.get_children():
		if h.has_meta("id"):
			fuera.append(h)
		else:
			_piezas_de(h, fuera)


## Lee el nivel y deja listo lo que `_ready` esperaba de las letras: el mapa (`_mapa`), los giros de los marcadores, los
## guardados y los empujables. El resto de la maqueta (agua, hierba, personajes, objetos reactivos…) no se entera.
func _leer_nivel() -> void:
	var ps: PackedScene = load(HorneadorNivel.ruta(nivel)) as PackedScene
	if ps == null:
		_avisos.append("no se pudo cargar " + HorneadorNivel.ruta(nivel))
		_modo_nivel = false
		return
	_nivel_raiz = ps.instantiate()
	var suelo: GridMap = null
	for g in _nivel_raiz.find_children("*", "GridMap", true, false):
		suelo = g as GridMap
		break
	if suelo == null or suelo.mesh_library == null:
		_avisos.append("el nivel no tiene GridMap de suelo")
		_modo_nivel = false
		return
	# El rectángulo del nivel = la caja de las casillas pintadas (cualquier origen, también negativo). Antes salía del
	# metadato `lado` de la raíz, que se copia al duplicar un nivel (Nivel_Bosque heredó 16 de Nivel_Pruebas).
	var usadas: Array[Vector3i] = suelo.get_used_cells()
	if usadas.is_empty():
		_avisos.append("el GridMap del nivel está vacío")
		_modo_nivel = false
		return
	var mn := Vector2i(usadas[0].x, usadas[0].z)
	var mx := mn
	var por_celda: Dictionary = {}      ## Vector2i -> [planta, item]: si hay varias plantas, manda la más alta
	var otras_plantas: int = 0
	for u in usadas:
		var c2 := Vector2i(u.x, u.z)
		mn = Vector2i(mini(mn.x, c2.x), mini(mn.y, c2.y))
		mx = Vector2i(maxi(mx.x, c2.x), maxi(mx.y, c2.y))
		if u.y != 0:
			otras_plantas += 1
		if not por_celda.has(c2) or int((por_celda[c2] as Array)[0]) < u.y:
			por_celda[c2] = [u.y, suelo.get_cell_item(u)]
	if otras_plantas > 0:
		_avisos.append("%d casillas del suelo en otra planta (no la 0): cuentan como suelo de la 0 (Q/E del GridMap cambian de planta)" % otras_plantas)
	if not suelo.position.is_zero_approx():
		_avisos.append("el nodo Suelo está desplazado %s: el cargador lo ignora (déjalo en 0, 0, 0)" % str(suelo.position))
	_origen = mn
	_ancho = mx.x - mn.x + 1
	_alto = mx.y - mn.y + 1
	_desplaza = Vector3(-float(mn.x) * S, 0.0, -float(mn.y) * S)
	var lado: int = maxi(_ancho, _alto)
	var filas: Array = []
	for y in range(lado):
		filas.append(" ".repeat(lado))       # " " = sin pintar: sin suelo y bloqueada
	for c2 in por_celda:
		var cc: Vector2i = (c2 as Vector2i) - mn
		var l: String = HorneadorNivel.letra_de_item(suelo.mesh_library, int((por_celda[c2] as Array)[1]))
		filas[cc.y] = (filas[cc.y] as String).substr(0, cc.x) + l + (filas[cc.y] as String).substr(cc.x + 1)
	var giros: Dictionary = {}
	_escalas = {}
	_marcas.clear()
	_muros_def.clear()
	_puentes_def.clear()
	for n in _nivel_raiz.find_children("*", "Marcador3D", true, false):
		var mk: Marcador3D = n as Marcador3D
		var t: Transform3D = _t_nivel(mk)
		var c: Vector2i = _celda_de(t.origin)
		if c.x < 0 or c.y < 0 or c.x >= lado or c.y >= lado or _letra_en(filas, c) == " ":
			_avisos.append("marcador fuera del suelo pintado: %s en la casilla %s del editor" % [mk.name, str(c + mn)])
			continue
		var giro: float = fposmod(rad_to_deg(t.basis.orthonormalized().get_euler().y), 360.0)
		giros[c] = snappedf(giro, 0.01)
		var esc: Vector3 = t.basis.get_scale()
		if not esc.is_equal_approx(Vector3.ONE):
			_escalas[c] = esc
		if mk.letra == "B":
			# Barrera de fuego (7.11): un marcador cubre `largo` casillas a lo largo de su eje X (el más cercano: horizontal o vertical).
			var vertical: bool = absf(t.basis.x.z) > absf(t.basis.x.x)
			var dir := Vector2(0.0, 1.0) if vertical else Vector2(1.0, 0.0)
			var cubiertas: Array = []
			for k in range(maxi(mk.largo, 1)):
				var off: float = (float(k) - float(maxi(mk.largo, 1) - 1) * 0.5) * S
				var pos := Vector2(t.origin.x, t.origin.z) + dir * off
				var cb := Vector2i(int(floor(pos.x / S)), int(floor(pos.y / S)))
				if cb.x < 0 or cb.y < 0 or cb.x >= lado or cb.y >= lado or cubiertas.has(cb):
					continue
				cubiertas.append(cb)
				filas[cb.y] = (filas[cb.y] as String).substr(0, cb.x) + "B" + (filas[cb.y] as String).substr(cb.x + 1)
			if not cubiertas.is_empty():
				_muros_def.append({"celdas": cubiertas, "vertical": vertical})
			continue
		if mk.letra == "P":
			# Puente reactivo: las casillas que cubre (a lo largo de su eje X) deben ser AGUA; se quedan como agua y bloqueadas
			# hasta que lo activa el marcador enlazado (PuenteReactivo3D las convierte en puente una a una).
			var vert: bool = absf(t.basis.x.z) > absf(t.basis.x.x)
			var d2 := Vector2(0.0, 1.0) if vert else Vector2(1.0, 0.0)
			var cubre: Array = []
			for k in range(maxi(mk.largo, 1)):
				var of2: float = (float(k) - float(maxi(mk.largo, 1) - 1) * 0.5) * S
				var p2 := Vector2(t.origin.x, t.origin.z) + d2 * of2
				var cp2 := Vector2i(int(floor(p2.x / S)), int(floor(p2.y / S)))
				if cp2.x < 0 or cp2.y < 0 or cp2.x >= lado or cp2.y >= lado or cubre.has(cp2):
					continue
				if _letra_en(filas, cp2) != "~":
					_avisos.append("puente reactivo %s: la casilla %s del editor no es agua" % [mk.name, str(cp2 + mn)])
					continue
				cubre.append(cp2)
			var ca: Vector2i = Vector2i(-1, -1)
			var an: Marcador3D = mk.get_node_or_null(mk.activador) as Marcador3D if not mk.activador.is_empty() else null
			if an != null:
				ca = _celda_de(_t_nivel(an).origin)
			else:
				_avisos.append("puente reactivo %s sin activador: no se tenderá nunca" % mk.name)
			if not cubre.is_empty():
				_puentes_def.append({"celdas": cubre, "activador": ca})
			continue
		if mk.letra != "":
			filas[c.y] = (filas[c.y] as String).substr(0, c.x) + mk.letra + (filas[c.y] as String).substr(c.x + 1)
		else:
			_marcas.append({"grupo": mk.grupo, "tipo": mk.tipo, "c": c, "giro": giro})
	# Paredes (#): las casillas donde hay una pieza del Borde. Las del Borde y nada más: un árbol suelto de Piezas no es pared.
	var piezas: Array = []
	_piezas_de(_nivel_raiz, piezas)
	var guardados: Array = []
	for pn in piezas:
		var pz: Node3D = pn as Node3D
		var cp: Vector2i = _celda_de(_t_nivel(pz).origin)
		if cp.x < 0 or cp.y < 0 or cp.x >= lado or cp.y >= lado:
			continue
		if _bajo(pz, "Borde", _nivel_raiz) and _letra_en(filas, cp) != " ":      # sin suelo debajo sigue vacía
			filas[cp.y] = (filas[cp.y] as String).substr(0, cp.x) + "#" + (filas[cp.y] as String).substr(cp.x + 1)
		if String(pz.get_meta("id")) == "baldosa_guardado":
			guardados.append(cp)
	var m := PackedStringArray()
	for f in filas:
		m.append(String(f))
	_mapa = m
	_giros = giros
	_guardados = guardados
	var emp: Array = []
	for mc in _marcas:
		if String((mc as Dictionary)["grupo"]) == "empujable":
			emp.append([String((mc as Dictionary)["tipo"]), (mc as Dictionary)["c"]])
	_empuj_def = emp
	print("Nivel leído de ", HorneadorNivel.ruta(nivel), ": ", _ancho, "×", _alto, " casillas desde ", _origen, " del editor, ",
		_marcas.size(), " marcadores de datos, ", guardados.size(), " guardados")


## Lo que el .tscn aporta: el decorado (a los lotes de siempre, para que se dibuje igual y barato) y la colisión REAL de cada
## pieza (su StaticBody3D, capa MUNDO). Una pieza con `bloquea` falso no lleva cuerpo. Las celdas que ocupan esos cuerpos
## son las que la fuente de solidez por nodos (Lanzador3D) ve como bloqueadas.
func _instanciar_nivel() -> void:
	var piezas: Array = []
	_piezas_de(_nivel_raiz, piezas)
	var colocadas: int = 0
	var hundidas: int = 0
	for pn in piezas:
		var pz: Node3D = pn as Node3D
		var id_pedido: String = String(pz.get_meta("id"))
		var id: String = _id_real(id_pedido)
		var t: Transform3D = _t_nivel(pz)
		# Una pieza por debajo del suelo se sube a él: al soltarla arrastrando en el editor, Godot la deja en y = 0 (las casillas
		# del GridMap no tenían colisión) y en el juego quedaba enterrada bajo la tapa del bloque (a ALTO). Lo que está por
		# encima del suelo no se toca.
		var y_suelo: float = ALTO_AGUA if _es_agua(_letra(_celda_de(t.origin))) else ALTO
		if t.origin.y < y_suelo - 0.15:
			t.origin.y = y_suelo
			hundidas += 1
		var p: Vector3 = t.origin
		var escala: float = t.basis.get_scale().x
		if bool(pz.get_meta("bloquea", false)):
			var cuerpo: StaticBody3D = pz.get_node_or_null("cuerpo") as StaticBody3D
			if cuerpo != null:
				_poner_cuerpo(cuerpo, t, p)
			else:
				_avisos.append("pieza %s bloquea pero no tiene `cuerpo`" % pz.name)
		if decorado_por_lotes:
			if _plantilla(id).is_empty():
				continue
			if not _lotes.has(id):
				_lotes[id] = []
			(_lotes[id] as Array).append(t)
			if SOMBRA_CONTACTO.has(id):
				var r: float = float(SOMBRA_CONTACTO[id]) * escala
				_sombras.append(Transform3D(Basis.IDENTITY.scaled(Vector3(r * 2.0, 1.0, r * 1.7)), Vector3(p.x, Y_DECAL - 0.005, p.z)))
		else:
			var nodo: Node3D = _pieza(id)
			if nodo == null:
				continue
			nodo.transform = t
			_props.add_child(nodo)
		colocadas += 1
	# Los rótulos del nivel (Label3D bajo `Rotulos`, p. ej. los del banco de pruebas) se copian tal cual al decorado.
	for l in _nivel_raiz.find_children("*", "Label3D", true, false):
		var et: Label3D = (l as Label3D).duplicate() as Label3D
		et.position = _t_nivel(l as Node3D).origin
		_props.add_child(et)
	if hundidas > 0:
		_avisos.append("%d piezas estaban bajo el suelo (y < %.2f): subidas a él" % [hundidas, ALTO])
	print("Nivel desde ", HorneadorNivel.ruta(nivel), ": ", colocadas, " piezas")


## Copia el StaticBody3D de la pieza del .tscn a la maqueta, en su sitio. Las casillas que toca se apuntan en `_bloqueadas`
## (lo siguen leyendo la hierba y el reparto de objetos), y como «de pieza» para no traspasarlas luego a `extras`.
func _poner_cuerpo(modelo: StaticBody3D, t: Transform3D, p: Vector3) -> void:
	if _solidos == null:
		_solidos = Node3D.new()
		_solidos.name = "Solidos"
		add_child(_solidos)
	var cuerpo: StaticBody3D = modelo.duplicate() as StaticBody3D
	cuerpo.transform = t
	cuerpo.add_to_group("bloquea")
	_solidos.add_child(cuerpo)
	var cp: Vector2i = _celda_de(p)
	_bloqueadas[cp] = true
	_celdas_pieza[cp] = true


## Lo que test_2.gd coloca fuera del plano: guardados, objetos del suelo y carteles de cada cámara.
func _colocar_extras() -> void:
	if _reglas != null:
		_reglas.colocar(self)
	if nivel == "pruebas":
		for e in NivelPruebas.piezas():     # una pieza de cada (se hornean como decorado; los rótulos van aparte, ver hornear)
			_poner(String(e[0]), e[1] as Vector2i, ALTO, bool(e[2]), false, 0.0)
	for g in _guardados:
		var c: Vector2i = g
		_poner("baldosa_guardado", c, ALTO, false, false, 0.0)
		_disco(VFX + "circulo_runico.png", _centro_celda(c, Y_SOBRE_PLANA), S * 0.8, Color(0.6, 0.85, 1.0))
	for o in _suelo_obj:
		var datos: Array = o
		var c2 := Vector2i(int(datos[1]), int(datos[2]))
		if String(datos[0]) == "pocion":
			_poner("pocion", c2, ALTO, false)
		else:
			_oro(_centro_celda(c2, ALTO))
	for k in _rotulos:
		var c3: Vector2i = _rotulos[k]
		# El tablero del cartel de Meshy mira a 41° del eje: girado así queda de cara a la cámara (+Z).
		_poner("cartel", c3, ALTO, true, false, GIRO_CARTEL)
		_runa_cartel(String(k), _centro_celda(c3, ALTO))
		_runa_suelo(String(k), _centro_celda(c3 + Vector2i(0, 1), Y_DECAL))
		_sin_hierba[c3 + Vector2i(0, 1)] = true
		var l3 := Label3D.new()
		l3.text = String(k).to_upper()
		l3.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l3.font_size = 64
		l3.outline_size = 12
		l3.modulate = _color_prueba[k]
		l3.position = _centro_celda(c3, ALTO + 1.9)
		l3.pixel_size = 0.006
		_props.add_child(l3)


## Símbolo del elemento pintado en el tablero del cartel (brilla un poco: sin sombreado).
func _runa_cartel(elem: String, base: Vector3) -> void:
	var t: Texture2D = _tex(RUNAS + "runa_%s.png" % elem)
	if t == null:
		return
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = t
	m.albedo_color = Color(1.15, 1.15, 1.15)
	q.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = base + RUNA_EN_TABLERO
	_props.add_child(mi)


## Baldosa rúnica del elemento delante de cada cartel: luz en el suelo que late despacio.
func _runa_suelo(elem: String, p: Vector3) -> void:
	var t: Texture2D = _tex(RUNAS + "runa_suelo_%s.png" % elem)
	if t == null:
		return
	var q := QuadMesh.new()
	q.size = Vector2(S * 0.95, S * 0.95)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = t
	q.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	mi.position = p
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_efectos.add_child(mi)
	var tw := mi.create_tween().set_loops()
	tw.tween_property(m, "albedo_color", Color(1.0, 1.0, 1.0, 0.6), 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(m, "albedo_color", Color(1.3, 1.3, 1.3, 1.0), 1.4).set_trans(Tween.TRANS_SINE)


## Montoncito de monedas (no hay modelo de oro todavía).
func _oro(p: Vector3) -> Node3D:
	var moneda := CylinderMesh.new()
	moneda.top_radius = 0.09
	moneda.bottom_radius = 0.09
	moneda.height = 0.03
	moneda.radial_segments = 12
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.82, 0.35)
	m.roughness = 0.4
	moneda.material = m
	var monton := Node3D.new()
	monton.position = p
	_props.add_child(monton)
	for i in range(6):
		var mi := MeshInstance3D.new()
		mi.mesh = moneda
		mi.position = Vector3(float(i % 3 - 1) * 0.07, 0.015 + floorf(float(i) / 3.0) * 0.032, float((i * 7) % 3 - 1) * 0.05)
		monton.add_child(mi)
	return monton


## --- Personajes ---

func _personaje(opciones: Array, p: Vector3) -> Pj3D:
	for o in opciones:
		var id: String = String(o)
		if ResourceLoader.exists(RAIZ + Pj3D.glb_de(id) + ".glb"):
			var pj := Pj3D.new()
			pj.position = p
			add_child(pj)
			pj.cargar(id)
			pj.set_alto(float(ALTO_PJ.get(id, 1.0)))
			return pj
	_avisos.append("sin personaje " + String(opciones[0]))
	return null


func _npc(opciones: Array, p: Vector3) -> Pj3D:
	var n: Pj3D = _personaje(opciones, p)
	if n != null:
		n.rotation.y = 0.0
	return n


## El puesto de venta en `c` (ocupa c y c+x) con su tendero dentro, de cara a la cámara. Lo usan las letras n/Q y el
## Test de jugabilidad (PUESTO_CELDA).
func poner_puesto(c: Vector2i, tendero: Array) -> Pj3D:
	var antes: bool = _en_marcador
	_en_marcador = true            # el puesto sale de su marcador (n / Q), no del decorado del nivel
	_poner("puesto", c, ALTO, true, false, 0.0)
	_bloqueadas[c + Vector2i(1, 0)] = true
	_en_marcador = antes
	return _npc(tendero, _centro_celda(c, ALTO) + Vector3(0.0, 0.0, -S * 0.35))


## --- Efectos ---

func _mat_sprite(ruta: String, aditivo: bool, frames: int = 1) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _tex(ruta)
	if aditivo:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if frames > 1:
		m.particles_anim_h_frames = frames
		m.particles_anim_v_frames = 1
		m.particles_anim_loop = true
	return m


func _particulas(ruta: String, p: Vector3, cantidad: int, vida: float, caja: Vector3, vel: float,
		apertura: float, tam: float, aditivo: bool, frames: int = 1, gravedad: Vector3 = Vector3.ZERO,
		tam_final: float = 0.4, color: Color = Color.WHITE) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = caja
	pm.direction = Vector3.UP
	pm.spread = apertura
	pm.initial_velocity_min = vel * 0.7
	pm.initial_velocity_max = vel * 1.3
	pm.gravity = gravedad
	pm.scale_min = 0.8
	pm.scale_max = 1.2
	pm.angle_min = -20.0
	pm.angle_max = 20.0
	var curva := Curve.new()
	curva.max_value = 2.0
	curva.add_point(Vector2(0.0, 0.5))
	curva.add_point(Vector2(0.25, 1.0))
	curva.add_point(Vector2(1.0, tam_final))
	var ct := CurveTexture.new()
	ct.curve = curva
	pm.scale_curve = ct
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
	grad.colors = PackedColorArray([Color(color, 0.0), color, color, Color(color, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	if frames > 1:
		pm.anim_speed_min = 1.0
		pm.anim_speed_max = 1.0
	var quad := QuadMesh.new()
	quad.size = Vector2(tam, tam)
	quad.material = _mat_sprite(ruta, aditivo, frames)
	var gp := GPUParticles3D.new()
	gp.amount = cantidad
	gp.lifetime = vida
	gp.process_material = pm
	gp.draw_pass_1 = quad
	gp.visibility_aabb = AABB(Vector3(-6, -2, -6), Vector3(12, 10, 12))
	gp.position = p
	_efectos.add_child(gp)
	return gp


## Fuego: llamas 3D, brasas y humo (Vfx3D.fuego_fijo), con luz cálida. `barrera` = muro de llamas que ocupa la casilla.
func _fuego(p: Vector3, barrera: bool, escala: float = 1.0, eje: Vector3 = Vector3.RIGHT) -> void:
	_fx.fuego_fijo(p, barrera, escala, eje, S)
	_luz(p + Vector3(0, 0.8 * escala, 0), Color(1.0, 0.6, 0.3), 1.6 if barrera else 1.1, 4.0 if barrera else 3.0)


func _esporas(p: Vector3) -> void:
	_fx.esporas(p)


func _destellos(p: Vector3, color: Color) -> void:
	_fx.destellos(p, color)
	_luz(p, color, 1.0, 4.0)


## Pétalos y hojas que caen despacio alrededor de la cámara.
func _ambiente() -> void:
	var a := _particulas(VFX + "petalo.png", Vector3.ZERO, 26, 7.0, Vector3(9, 0.5, 9), 0.25, 60.0, 0.22, false,
		1, Vector3(0.15, -0.25, 0.05), 1.0)
	a.name = "Ambiente1"
	var b := _particulas(VFX + "hoja.png", Vector3.ZERO, 14, 8.0, Vector3(9, 0.5, 9), 0.2, 60.0, 0.25, false,
		1, Vector3(0.2, -0.22, 0.0), 1.0)
	b.name = "Ambiente2"
	var pm1: ParticleProcessMaterial = a.process_material as ParticleProcessMaterial
	pm1.angular_velocity_min = -60.0
	pm1.angular_velocity_max = 60.0
	var pm2: ParticleProcessMaterial = b.process_material as ParticleProcessMaterial
	pm2.angular_velocity_min = -45.0
	pm2.angular_velocity_max = 45.0


func _luz(p: Vector3, color: Color, energia: float, rango: float) -> void:
	var l := OmniLight3D.new()
	l.position = p
	l.light_color = color
	l.light_energy = energia
	l.omni_range = rango
	l.shadow_enabled = false
	_efectos.add_child(l)


## Un círculo rúnico plano (pieza 3D de Formas3D) tumbado en el suelo, que gira despacio. `_ruta` ya no se usa (era el sprite).
func _disco(_ruta: String, p: Vector3, tam: float, color: Color) -> void:
	var mi: MeshInstance3D = Formas3D.instancia("runa", color)
	mi.scale = Vector3(tam, 1.0, tam)
	var pivote := Node3D.new()
	pivote.add_child(mi)
	_efectos.add_child(pivote)
	pivote.position = p
	_girar.append(pivote)


## Un sprite de pie que mira a la cámara (telaraña).
func _cartel_plano(ruta: String, p: Vector3, tam: float, aditivo: bool, color: Color) -> void:
	var s3 := Sprite3D.new()
	s3.texture = _tex(ruta)
	s3.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s3.pixel_size = tam / float(maxi(s3.texture.get_width(), 1)) if s3.texture != null else 0.01
	s3.modulate = color
	s3.shaded = false
	s3.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	if aditivo:
		s3.modulate = color
	s3.position = p
	_props.add_child(s3)


## --- Estado del suelo -------------------------------------------------------------------------------------
## Las reglas son las de docs/ESTADOS_SUELO.md (sacadas del 2D); si difieren de IMPLEMENTAR_TECNICAS.md Paso 1,
## manda aquel. Canales de _img_estado: 0 R quemado · 1 G mojado · 2 B helado · 3 A pisado (solo aspecto).

func _celda_de(p: Vector3) -> Vector2i:
	return Vector2i(int(floorf(p.x / S)), int(floorf(p.z / S)))


func _en_mapa(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < _lado and c.y < _lado


## Hierba en el sentido del 2D (letras v/G): casilla de tipo hierba, sin objeto encima y que no sea agua.
func _es_hierba(c: Vector2i) -> bool:
	var l: String = _letra(c)
	return l != "#" and not _es_agua(l) and not _bloqueadas.has(c) and _tipo_suelo(c) == 0


func _poner_canal(c: Vector2i, canal: int, valor: float) -> void:
	if not _en_mapa(c):
		return
	var p: Color = _img_estado.get_pixel(c.x, c.y)
	p[canal] = clampf(valor, 0.0, 1.0)
	_img_estado.set_pixel(c.x, c.y, p)
	_estado_sucio = true


## Suma `cantidad` al canal de la casilla y las de alrededor (radio en casillas), saturando a 1.
## Las esquinas del cuadrado reciben la mitad: la marca queda redondeada.
func marcar_estado(c: Vector2i, canal: int, cantidad: float, radio: int = 0) -> void:
	for y in range(c.y - radio, c.y + radio + 1):
		for x in range(c.x - radio, c.x + radio + 1):
			var q := Vector2i(x, y)
			if not _en_mapa(q):
				continue
			var k: float = cantidad * (0.5 if absi(x - c.x) + absi(y - c.y) > radio else 1.0)
			var p: Color = _img_estado.get_pixel(x, y)
			p[canal] = clampf(p[canal] + k, 0.0, 1.0)
			_img_estado.set_pixel(x, y, p)
			if canal == 3 and p[canal] > 0.0:
				_pisadas[q] = true
	_estado_sucio = true


## Qué deja cada hechizo en el suelo, según el tipo de casilla. Un impacto toca UNA casilla (radio 0 como en el 2D).
func _al_impactar(elemento: String, punto: Vector3) -> void:
	if _precalentando:
		return
	_golpear_objetos(elemento, punto)
	var c: Vector2i = _celda_de(punto)
	if not _en_mapa(c):
		return
	if elemento == "agua" or elemento == "hielo":
		_apagar_area(c, punto)
	if _es_agua(_letra(c)):
		_impacto_en_agua(elemento, c)
	elif _es_hierba(c):
		_impacto_en_hierba(elemento, c)
	elif not _bloqueadas.has(c):
		_impacto_en_suelo(elemento, c)
	if elemento == "viento":
		marcar_estado(c, 3, 1.0, 2)      # tumba la hierba en un radio grande: solo aspecto (§5)


## Suelo neutro (§1.1, §4.1): SECO → MOJADO → HELADO. El fuego deshace un escalón y no quema.
func _impacto_en_suelo(elemento: String, c: Vector2i) -> void:
	var p: Color = _img_estado.get_pixel(c.x, c.y)
	match elemento:
		"agua":
			if p.b >= 0.5:
				return
			if p.g >= 0.5:              # dos aguas hielan
				_poner_canal(c, 1, 0.0)
				_poner_canal(c, 2, 1.0)
			else:
				_poner_canal(c, 1, 1.0)
		"hielo":
			_poner_canal(c, 1, 0.0)
			_poner_canal(c, 2, 1.0)
		"fuego":
			if p.b >= 0.5:              # el hielo pasa a charco
				_poner_canal(c, 2, 0.0)
				_poner_canal(c, 1, 1.0)
			elif p.g >= 0.5:            # el charco se seca con vapor
				_poner_canal(c, 1, 0.0)
				_fx.vapor(_centro_celda(c, ALTO))
		# rayo (descarga: lo hace el VFX), tierra y viento: no cambian canales del suelo.


## Agua (§1.5): el hielo es permanente. El agua helada se puede pisar.
func _impacto_en_agua(elemento: String, c: Vector2i) -> void:
	var p: Color = _img_estado.get_pixel(c.x, c.y)
	match elemento:
		"hielo":
			if p.b < 0.5:
				_poner_canal(c, 2, 1.0)
				_helada[c] = true
				_liberar(c)
				_poner_placa_hielo(c)
		"fuego":
			_fx.vapor(_centro_celda(c, ALTO_AGUA))      # hierve; el hielo no se derrite


## Hierba (§1.2, §4.2). Sin entrada en _hf = FINA.
func _impacto_en_hierba(elemento: String, c: Vector2i) -> void:
	var f: int = int((_hf[c] as Dictionary)["fase"]) if _hf.has(c) else 0
	match elemento:
		"fuego":
			if f == 0 or f == Fase.CRECIDA:
				_poner_fase(c, Fase.PRENDIENDO)
		"rayo":
			if f == 0 or f == Fase.CRECIDA or f == Fase.PRENDIENDO:
				_poner_fase(c, Fase.ARDIENDO)
		"agua", "hielo":
			if f == 0:
				_hf[c] = {"fase": Fase.CRECIDA, "t": 0.0, "v": 0.0, "fx": null}     # brota (y pasa a bloquear)
			elif f == Fase.PRENDIENDO or f == Fase.ARDIENDO or f == Fase.CENIZAS:
				_apagar(c)                                                          # FINA, R = 0 (rebrota)
		"viento":
			if f == Fase.ARDIENDO:
				_abanicar(c)


func _quitar_fx(c: Vector2i) -> void:
	if _hf.has(c):
		var fx: Variant = (_hf[c] as Dictionary).get("fx")
		if fx != null and is_instance_valid(fx):
			_fx.apagar(fx as Node3D)
		(_hf[c] as Dictionary)["fx"] = null


func _poner_fase(c: Vector2i, fase: int) -> void:
	var viejo: Dictionary = _hf.get(c, {})
	# Tope: una GPU integrada no aguanta medio mapa en llamas (el 6/10 se congeló). Más allá de MAX_ARDIENDO casillas encendidas a la
	# vez no se propaga más; más allá de MAX_FX_HIERBA siguen ardiendo (quemado en el suelo) pero sin partículas.
	var ardiendo: int = 0
	var con_fx: int = 0
	for k in _hf:
		var dk: Dictionary = _hf[k]
		var fk: int = int(dk["fase"])
		if fk == Fase.PRENDIENDO or fk == Fase.ARDIENDO:
			ardiendo += 1
			if dk.get("fx") != null:
				con_fx += 1
	if fase == Fase.PRENDIENDO and ardiendo >= MAX_ARDIENDO:
		return
	if fase == Fase.PRENDIENDO and int(_mojada.get(c, 0)) > Time.get_ticks_msec():
		return                                  # mojada: no prende (si no, el fuego vecino la reenciende al instante)
	_quitar_fx(c)
	var d: Dictionary = {"fase": fase, "t": 0.0, "v": 0.0, "frente": float(viejo.get("frente", 0.0)),
		"contagia": bool(viejo.get("contagia", true)), "fx": null}
	if con_fx < MAX_FX_HIERBA:
		d["fx"] = _fx.llamas(_centro_celda(c, ALTO), 0.5 if fase == Fase.PRENDIENDO else 1.0, S * 0.32)
	_hf[c] = d
	if _hierba != null:
		_hierba.set_crecida(c, 0.0)       # deja de ser alta: se achicharra


## Apagada o regada tras arder: FINA otra vez, sin rastro.
## El agua (y el hielo) apagan todo lo que arde alrededor del impacto y dejan la hierba mojada unos segundos.
func _apagar_area(c: Vector2i, punto: Vector3) -> void:
	var ahora: int = Time.get_ticks_msec() + T_MOJADA_MS
	for y in range(c.y - RADIO_APAGAR, c.y + RADIO_APAGAR + 1):
		for x in range(c.x - RADIO_APAGAR, c.x + RADIO_APAGAR + 1):
			var q := Vector2i(x, y)
			if not _en_mapa(q) or not _es_hierba(q):
				continue
			_mojada[q] = ahora
			if _hf.has(q):
				var f: int = int((_hf[q] as Dictionary)["fase"])
				if f == Fase.PRENDIENDO or f == Fase.ARDIENDO or f == Fase.CENIZAS:
					_apagar(q)
	for n in get_tree().get_nodes_in_group(Reactivo3D.GRUPO_ARDE):
		var o: Reactivo3D = n as Reactivo3D
		if o == null or o.estado != Reactivo3D.EstadoObj.ARDIENDO:
			continue
		var d: Vector3 = o.global_position - punto
		d.y = 0.0
		if d.length() <= (RADIO_APAGAR + 0.5) * S:
			o._apagar()


func _apagar(c: Vector2i) -> void:
	_quitar_fx(c)
	_hf.erase(c)
	_poner_canal(c, 0, 0.0)
	if _hierba != null:
		_hierba.set_crecida(c, 0.0)


## Viento con dirección sobre hierba ARDIENDO: prende la hierba del cono de delante (≤ 230 px, producto escalar ≥ 0,3).
func _abanicar(c: Vector2i) -> void:
	var r: int = ceili(CONO_VIENTO)
	for y in range(c.y - r, c.y + r + 1):
		for x in range(c.x - r, c.x + r + 1):
			var q := Vector2i(x, y)
			if q == c or not _en_mapa(q) or not _es_hierba(q):
				continue
			var d := Vector2(float(x - c.x), float(y - c.y))
			if d.length() > CONO_VIENTO or d.normalized().dot(Vector2(_dir_hechizo.x, _dir_hechizo.z)) < 0.3:
				continue
			var f: int = int((_hf[q] as Dictionary)["fase"]) if _hf.has(q) else 0
			if f == 0 or f == Fase.CRECIDA:
				_poner_fase(q, Fase.PRENDIENDO)


## Cada fotograma mientras haya algo vivo: fases de la hierba, contagio por frente y pisadas.
func _avanzar_estado(dt: float) -> void:
	var prender: Array[Vector2i] = []
	var promover: Array[Vector2i] = []
	var ceniza: Array[Vector2i] = []
	var objetos_a_prender: Array[Reactivo3D] = []
	for c in _hf:
		var d: Dictionary = _hf[c]
		var f: int = int(d["fase"])
		if f == Fase.CRECIDA:
			if float(d["v"]) < 1.0:
				d["v"] = minf(float(d["v"]) + dt / T_CRECER, 1.0)
				if _hierba != null:
					_hierba.set_crecida(c, float(d["v"]))
			continue
		if f != Fase.PRENDIENDO and f != Fase.ARDIENDO:
			continue
		d["t"] = float(d["t"]) + dt
		if f == Fase.PRENDIENDO and float(d["t"]) >= T_PRENDIENDO:
			promover.append(c)
		elif f == Fase.ARDIENDO:
			_poner_canal(c, 0, float(d["t"]) / T_ARDIENDO)        # el círculo quemado crece mientras arde
			if float(d["t"]) >= T_ARDIENDO:
				ceniza.append(c)
		# Contagio por frente: un círculo que crece desde la casilla; prende la primera hierba que toque y se acaba.
		# 6.9a: el fuego salta solo a las 4 vecinas (sin diagonales) y espera T_SALTO s tras prender antes de contagiar.
		if bool(d["contagia"]) and float(d["t"]) >= T_SALTO:
			d["frente"] = maxf(float(d["frente"]) + dt * FRENTE_VEL, 1.0)   # las vecinas están a 1: alcanzable ya
			var fr: float = float(d["frente"])
			if fr > FRENTE_MAX:
				d["contagia"] = false
			elif fr >= FRENTE_MIN:
				var objeto: Reactivo3D = _objeto_al_alcance(c, fr) if objetos_reactivos else null
				if objeto != null:
					# El frente toca primero un objeto que arde (seto, tronco, telaraña): prende y el frente se acaba.
					objetos_a_prender.append(objeto)
					d["contagia"] = false
					continue
				var mejor := Vector2i(-1, -1)
				var dm: float = 1.0e9
				for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = c + v
					var dist: float = Vector2(v).length()
					if dist > fr or not _en_mapa(q) or not _es_hierba(q):
						continue
					var fq: int = int((_hf[q] as Dictionary)["fase"]) if _hf.has(q) else 0
					if fq != 0 and fq != Fase.CRECIDA:
						continue
					var desempate: float = dist + float(_hash(q.x, q.y, 21) % 100) * 0.0001
					if desempate < dm:
						dm = desempate
						mejor = q
				if mejor.x >= 0:
					prender.append(mejor)
					d["contagia"] = false
	for c in promover:
		_poner_fase(c, Fase.ARDIENDO)
		(_hf[c] as Dictionary)["t"] = 0.0
	for c in ceniza:
		_quitar_fx(c)
		_poner_canal(c, 0, 1.0)
		var d2: Dictionary = _hf[c]
		d2["fase"] = Fase.CENIZAS
	for o in objetos_a_prender:
		if is_instance_valid(o):
			o.ignite()
	for q in prender:
		var fq2: int = int((_hf[q] as Dictionary)["fase"]) if _hf.has(q) else 0
		if fq2 == 0 or fq2 == Fase.CRECIDA:
			_poner_fase(q, Fase.PRENDIENDO)
	# Lo pisado se levanta solo (A baja en T_PISADO s). Mojado y helado no caducan (§4.4.5).
	var libres: Array[Vector2i] = []
	for c in _pisadas:
		var p: Color = _img_estado.get_pixel(c.x, c.y)
		p.a = maxf(p.a - dt / T_PISADO, 0.0)
		_img_estado.set_pixel(c.x, c.y, p)
		_estado_sucio = true
		if p.a <= 0.0:
			libres.append(c)
	for c in libres:
		_pisadas.erase(c)


## Lanza hacia donde mira la chibi, a 2,5 casillas (con tierra y rayo el efecto brota en el destino).
func _lanzar(elemento: String) -> void:
	var d := Vector3(sin(_jugador.rotation.y), 0.0, cos(_jugador.rotation.y))
	_dir_hechizo = d
	var destino: Vector3 = _jugador.position + d * S * 2.5
	var c: Vector2i = _celda_de(destino)
	destino.y = ALTO_AGUA if (_en_mapa(c) and _es_agua(_letra(c))) else ALTO
	_jugador.jugar("cast")
	_t_cast = 0.9
	_fx.lanzar(elemento, _jugador.position + d * 0.3, destino)


## Tapa la pantalla un momento y lanza los seis elementos: compila shaders y carga texturas antes de jugar.
## Mientras dura, los impactos no marcan el suelo.
func _precalentar(capa: CanvasLayer) -> void:
	if _jugador == null or not precalentar_al_inicio:
		return
	var velo := ColorRect.new()
	velo.color = Color(0.81, 0.91, 0.94)
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var aviso := Label.new()
	aviso.text = "Preparando efectos..."
	aviso.position = Vector2(24.0, 24.0)
	aviso.add_theme_color_override("font_color", Color(0.25, 0.35, 0.4))
	velo.add_child(aviso)
	capa.add_child(velo)
	_precalentando = true
	_velo = velo
	_t_velo = 0.0
	_f_velo = 0
	_ms_velo = Time.get_ticks_msec()
	_fx.precalentar(_jugador.position, _jugador.position + Vector3(1.5, 0.0, 1.5))


## --- Bucle ---

func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey):
		return
	var k: InputEventKey = ev as InputEventKey
	if not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_F9:
			hornear()
		KEY_H:
			_sol.shadow_enabled = not _sol.shadow_enabled
		KEY_P:
			_efectos.visible = not _efectos.visible
		KEY_K:
			_props.visible = not _props.visible
		KEY_G:
			if _hierba != null:
				_hierba.visible = not _hierba.visible
		KEY_J:
			if _hierba != null:
				_hierba.set_modo(_hierba.modo + 1)
		KEY_L:
			if _jugador != null:
				_jugador.set_modo_luz(1 - _jugador.modo_luz)
		KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6:
			if _jugador != null and _velo == null:
				_lanzar(String(Vfx3D.ELEMENTOS[k.keycode - KEY_F1]))
		KEY_T:
			# Rampa de luz del suelo y del agua: 1 (como el PBR) · 2,5 · 4 (cel suave). Para comparar capturas.
			_contraste = 1.0 if _contraste >= 4.0 else (2.5 if _contraste < 2.5 else 4.0)
			_mat_suelo.set_shader_parameter("contraste", _contraste)
			_mat_agua.set_shader_parameter("contraste", maxf(_contraste * 0.6, 1.0))
		KEY_V:
			_danar_empujable_cercano()
		KEY_B:
			# Relieve del suelo: 0 (liso) · 0,5 · 1. Para comparar capturas.
			_rugosidad = 0.0 if _rugosidad >= 1.0 else (0.5 if _rugosidad < 0.5 else 1.0)
			_mat_suelo.set_shader_parameter("rugosidad", _rugosidad)
			print("Rugosidad del suelo: %.1f" % _rugosidad)
		KEY_N:
			if _jugador != null:
				_jugador.set_nivel_grimorio(Equipo3D.nivel_grimorio % 3 + 1)
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			_tam_camara = maxf(ZOOM_MINIMO, _tam_camara * 0.9)
			_camara.size = _tam_camara
		KEY_MINUS, KEY_KP_SUBTRACT:
			_tam_camara = minf(60.0, _tam_camara * 1.1)
			_camara.size = _tam_camara
		KEY_BRACKETLEFT:
			if _jugador != null:
				_jugador.set_escala(_jugador.scale.x * 0.9)
		KEY_BRACKETRIGHT:
			if _jugador != null:
				_jugador.set_escala(_jugador.scale.x * 1.1)
		KEY_COMMA, KEY_PERIOD:
			# Postura: , baja la cabeza 2°, . la echa atrás 2° (con Shift, los hombros: < cierra, > abre).
			if _jugador != null:
				var q: Array = _jugador.postura()
				var paso: float = 2.0 if k.keycode == KEY_PERIOD else -2.0
				if k.shift_pressed:
					q[3] = float(q[3]) + paso
				else:
					q[0] = float(q[0]) + paso
				_jugador.set_postura(float(q[0]), float(q[1]), float(q[2]), float(q[3]), float(q[4]), float(q[5]), float(q[6]))
				_imprimir_postura()
		KEY_U, KEY_I:
			# Piernas: U dobla las rodillas 2°, I las estira (con Shift, los pies: cierra / abre).
			# Letras y no ; ' porque en teclado español ; es Shift+, y Godot nunca lo manda como tecla propia.
			if _jugador != null:
				var q: Array = _jugador.postura()
				var paso: float = 2.0 if k.keycode == KEY_I else -2.0
				if k.shift_pressed:
					q[5] = float(q[5]) + paso
				else:
					q[4] = float(q[4]) + paso
				_jugador.set_postura(float(q[0]), float(q[1]), float(q[2]), float(q[3]), float(q[4]), float(q[5]), float(q[6]))
				_imprimir_postura()
		KEY_Y, KEY_O:
			# Pelvis: Y la echa adelante 2°, O la endereza (quita el culo en pompa sin mover las piernas).
			if _jugador != null:
				var q: Array = _jugador.postura()
				q[6] = float(q[6]) + (2.0 if k.keycode == KEY_O else -2.0)
				_jugador.set_postura(float(q[0]), float(q[1]), float(q[2]), float(q[3]), float(q[4]), float(q[5]), float(q[6]))
				_imprimir_postura()


## Tipo de hierba: 0 briznas · 1 tarjetas pintadas · 2 las dos (tecla J).
func set_modo_hierba(m: int) -> void:
	if _hierba != null:
		_hierba.set_modo(m)


## Impactos de prueba (capturas y QA): [["fuego", Vector2i(12, 8)], ["agua", Vector2i(13, 8)], ...].
func impactar_en(lista: Array) -> void:
	_precalentando = false
	for e in lista:
		_al_impactar(String(e[0]), _centro_celda(e[1] as Vector2i, ALTO))


## Escribe en la consola el estado de cada casilla viva (QA): fase de la hierba y canales del suelo.
func imprimir_estado() -> void:
	for c in _hf:
		var d: Dictionary = _hf[c]
		print("CAPTURA estado ", c, " fase=", Fase.find_key(int(d["fase"])), " t=", snappedf(float(d["t"]), 0.1))
	for y in range(_lado):
		for x in range(_lado):
			var p: Color = _img_estado.get_pixel(x, y)
			if p.r > 0.0 or p.g > 0.0 or p.b > 0.0:
				print("CAPTURA canales ", Vector2i(x, y), " R=", snappedf(p.r, 0.01), " G=", p.g, " B=", p.b)


## Lleva a la chibi a una casilla (para pruebas y capturas).
func ir_a(c: Vector2i) -> void:
	if _jugador == null:
		return
	_jugador.position = _centro_celda(c, ALTO)
	_foco = _centro(_jugador)
	if _hierba != null and not hierba_completa:
		_hierba.set_radio(clampi(ceili(_tam_camara * 0.95 / _hierba.lado_bloque) + 1, 2, 7))
		_hierba.actualizar(_jugador.position, true)


func _centro(p: Pj3D) -> Vector3:
	return p.position + Vector3(0.0, 0.85 * p.scale.y, 0.0)


func _colocar_camara() -> void:
	var e: float = deg_to_rad(90.0 - _incl)
	var dir: Vector3 = -Vector3(0.0, sin(e), cos(e))
	_camara.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), _foco - dir * 40.0)


func _process(delta: float) -> void:
	if _jugador != null:
		if not externo:
			_mover(delta)
		if _hierba != null and not hierba_completa:
			# El radio crece con el zoom para que no se vea el borde de lo sembrado al alejar la cámara.
			_hierba.set_radio(clampi(ceili(_tam_camara * 0.95 / _hierba.lado_bloque) + 1, 2, 7))
			_hierba.actualizar(_jugador.position)
		_foco = _foco.lerp(_centro(_jugador), 1.0 - exp(-SEGUIMIENTO * delta))
		if transparencia_jugador and decorado_por_lotes:
			Ocluso3D.actualizar(_jugador.position + Vector3(0.0, 0.8, 0.0), radio_transparencia)
		var amb: Node = _efectos.get_node_or_null("Ambiente1")
		if amb != null:
			(amb as Node3D).position = _jugador.position + Vector3(0.0, 5.0, 0.0)
		var amb2: Node = _efectos.get_node_or_null("Ambiente2")
		if amb2 != null:
			(amb2 as Node3D).position = _jugador.position + Vector3(0.0, 5.0, 0.0)
		# Los goblins miran al jugador cuando está cerca.
		for g in _goblins:
			var d: Vector3 = _jugador.position - g.position
			d.y = 0.0
			if not externo and d.length() < 7.0:
				g.mirar(d, delta)
	_colocar_camara()
	for p in _girar:
		p.rotate_y(delta * 0.4)
	# Estado del suelo: avanza las fases de la hierba, levanta lo pisado y sube la textura una vez por frame.
	_t_cast = maxf(_t_cast - delta, 0.0)
	if not _hf.is_empty() or not _pisadas.is_empty():
		var t0: int = Time.get_ticks_usec()
		_avanzar_estado(delta)
		_ms_estado = lerpf(_ms_estado, float(Time.get_ticks_usec() - t0) / 1000.0, 0.1)
	if _estado_sucio:
		_tex_estado.update(_img_estado)      # update() reutiliza la textura en GPU; create_from_image la recrearía
		_estado_sucio = false
	if _hierba != null:
		_hierba.subir_crecida()
		if _jugador != null:
			_hierba.set_posicion_jugador(_jugador.position)
	if _velo != null:
		# Tiempo REAL (no suma de deltas): si el equipo va lento o compila shaders a tirones, el velo no se eterniza.
		_f_velo += 1
		_t_velo = float(Time.get_ticks_msec() - _ms_velo) / 1000.0
		if _f_velo > 10 and _t_velo >= PRECALENTAR:
			_velo.queue_free()
			_velo = null
			_precalentando = false
	_t_hud += delta
	if _t_hud > 0.3:
		_t_hud = 0.0
		_actualizar_hud()


func _pisable(p: Vector3) -> bool:
	var c := Vector2i(int(floorf(p.x / S)), int(floorf(p.z / S)))
	if c.x < 0 or c.y < 0 or c.y >= _lado or c.x >= _mapa[c.y].length():
		return false
	if _hf.has(c) and int((_hf[c] as Dictionary)["fase"]) == Fase.CRECIDA and float((_hf[c] as Dictionary)["v"]) > 0.5:
		return false      # la hierba crecida es sólida (grass_block.gd GROWN)
	return not _bloqueadas.has(c)


func _mover(delta: float) -> void:
	var entrada := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		entrada.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		entrada.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		entrada.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		entrada.y += 1.0
	if entrada == Vector2.ZERO:
		if _t_cast <= 0.0:
			_jugador.jugar("idle")
		return
	var mov: Vector3 = Vector3(entrada.x, 0.0, entrada.y).normalized()
	var correr: bool = Input.is_key_pressed(KEY_SHIFT)
	var paso: Vector3 = mov * (VEL_CORRER if correr else VEL_ANDAR) * delta
	var destino: Vector3 = _jugador.position + paso
	if not _pisable(destino):
		destino = _jugador.position + Vector3(paso.x, 0.0, 0.0)
		if not _pisable(destino):
			destino = _jugador.position + Vector3(0.0, 0.0, paso.z)
			if not _pisable(destino):
				destino = _jugador.position
	# Sobre el puente se va a la altura del agua + tablas; en tierra, a la del bloque.
	var c := Vector2i(int(floorf(destino.x / S)), int(floorf(destino.z / S)))
	destino.y = ALTO_AGUA + 0.12 if (_letra(c) == "b" or _helada.has(c)) else ALTO
	_jugador.position = destino
	marcar_estado(c, 3, 0.35)      # pisa la hierba de su casilla (solo aspecto)
	_jugador.mirar(mov, delta)
	_jugador.jugar("run" if correr else "walk")


func _imprimir_postura() -> void:
	var q: Array = _jugador.postura()
	print("Postura %s: cabeza %.0f° cuello %.0f° columna %.0f° brazos %.0f° rodillas %.0f° pies %.0f° pelvis %.0f° (apúntalo en Pj3D.POSTURAS)" % [
		_jugador.id, q[0], q[1], q[2], q[3], q[4], q[5], q[6]])


func _actualizar_hud() -> void:
	var aviso: String = ""
	if not _avisos.is_empty():
		aviso = "\n(!) " + ", ".join(_avisos.slice(0, 6))
		if _avisos.size() > 6:
			aviso += " ..."
	var tipo_hierba: String = String(Hierba3D.NOMBRES_MODO[_hierba.modo]) if _hierba != null else "-"
	var dibujo: String = "dibujo: %d llamadas · %d k prim. · %d MB vídeo · %d lotes" % [
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0),
		int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0), _n_lotes]
	if _hierba != null:
		dibujo += " · hierba %d bloques / %d matojos" % [_hierba.numero_de_bloques(), _hierba.numero_de_matojos()]
	_hud.text = "TEST 2 en 3D | %d FPS | inclinación %d° (fija) | sombras %s | partículas %s | hierba: %s | %s%s\nWASD mover · Shift correr · +/- zoom · H sombras · P partículas · K decorado · G hierba · J tipo de hierba · [ ] tamaño · N grimorio · , . cabeza · U I rodillas · Y O pelvis (Shift: brazos / pies)\nF1–F6 hechizos (fuego agua tierra viento rayo hielo) · T rampa de luz %.1f · B relieve · V grietas del empujable más cercano · estado: %d casillas, %.2f ms" % [
		int(Engine.get_frames_per_second()), int(_incl), "sí" if _sol.shadow_enabled else "no",
		"sí" if _efectos.visible else "no", tipo_hierba, dibujo, aviso, _contraste, _hf.size() + _pisadas.size(), _ms_estado]
	if _reglas != null:
		_hud.text = _hud.text.replace("TEST 2 en 3D", "Test de jugabilidad en 3D")
