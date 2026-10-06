# Técnicas de otros juegos aplicables a Magic Symbols (5 de octubre de 2026)

Análisis de cuatro dosieres de investigación (Zelda BotW/TotK, Mario Odyssey + DK Bananza + Luigi's
Mansion 3, Journey + deformación de arena + agua estilizada) cribados contra lo que hay hoy en el
proyecto: la maqueta 3D `poc_25d/PruebaTest2` (suelo `CODIGO_SUELO` con 4 texturas mezcladas por un
mapa RGBA de celdas, agua triplanar con `uv1_offset` desplazándose, `Hierba3D` por bloques con viento
en el vértice, VFX por `GPUParticles3D`) y el juego 2D (`nivel_base.gd`, estados mojado / quemado /
congelado de `docs/NUEVOS_SISTEMAS.md`). Hardware objetivo: GPU integrada Intel, Forward+.

Criterio de criba: **ganancia visible por unidad de coste en GPU integrada** y que encaje con el canon
de arte (la elfa chibi, pastel, cel suave). Lo que necesita teselación, vóxeles, 9 plantillas de calidad
o cubemaps de oclusión se descarta por diseño; lo caro-pero-vistoso queda como opcional medido.

Responsables: **Pipeline** programa (shaders, `prueba_test2.gd`, `hierba_3d.gd`); **Pablo** genera texturas
y máscaras; **QA** (este contexto) mide antes/después y valida la coherencia.

---

## 1. Tabla de veredictos

| # | Técnica (origen) | Qué resuelve aquí | Veredicto | Coste | Resp. |
|---|---|---|---|---|---|
| D1 | Agua estilizada por profundidad: Beer-Lambert claro/oscuro, espuma por diferencia de profundidad, 2 normales desplazadas, fresnel (dosier Journey/agua) | El agua de Test2 es una textura que se desliza; no hay orilla, no hay volumen; el hielo es "agua desaturada" | **Aplicar** | 1 shader, 0 texturas nuevas obligatorias | Pipeline |
| D2 | Capa de estado por celda: humedad / daño / material por vóxel (Bananza) + campo de hierba RGB (BotW) | Fuego, agua, hielo y pisadas no dejan marca en el suelo ni en la hierba; cada estado es solo partículas | **Aplicar** (es la pieza que más rinde) | 1 `Image` 40×40 + 6 líneas en 2 shaders | Pipeline + Pablo (2 texturas) |
| D3 | Rampa difusa de contraste `saturate(4·N·L)` (Journey) | El suelo y los bloques tienen sombreado PBR plano; la chibi es cel. Unifica la lectura | **Aplicar** (barato, reversible con un uniform) | 3 líneas | Pipeline |
| D4 | Inclinación de hierba por `player_position` (receta Godot) | La elfa atraviesa la hierba sin tocarla | **Aplicar** | 1 uniform global + 4 líneas | Pipeline |
| D5 | Rastro por SubViewport ortográfico (huellas, hierba aplastada, marcas de quemado persistentes) (dosier deformación) | Huellas en tierra/nieve, hierba pisada que se recupera | **Adaptar** después de D2 (D2 ya cubre lo persistente por celda; esto añade lo fino) | 1 SubViewport 256², 1 cámara, 1 sprite por huella | Pipeline + Pablo (sprite huella) |
| D6 | Albedo arriba/lado separado + grietas por daño (Bananza) | Empujables de tierra/hielo son cubos de una textura; no se ve cuánto les queda | **Adaptar** a `_malla_bloque` (ya tiene tapa y lado) | 1 máscara de grietas, 1 uniform | Pipeline + Pablo |
| D7 | Reducción de texturas guiada por captura (BotW) + LOD lejano sin sombras | VRAM 2,7 GB y stuttering en Test2 | **Aplicar como regla de presupuesto** (no como herramienta) | Solo disciplina | QA mide, Pipeline aplica |
| D8 | Cáusticas proyectadas desde XZ reconstruido por profundidad (Odyssey/agua) | Agua poco profunda "viva" sin partículas | **Opcional** tras D1 (medir; 1 muestra extra por píxel de agua) | 1 textura cáustica | Pablo + Pipeline |
| D9 | Refracción por copia de pantalla ordenada antes del agua (Odyssey) | Fondo del agua distorsionado | **Descartar por ahora**: `screen_texture` + `hint_screen_texture` fuerza copia de pantalla por frame; en integrada se nota | — | — |
| D10 | Especular "océano" Blinn-Phong + brillo de destellos umbralizado (Journey) | Nieve/hielo con chispa | **Opcional** solo en hielo (celdas pocas), nunca en suelo entero | 4 líneas | Pipeline |
| D11 | Teselación de arena (Journey, LM3) | Deformación real de malla | **Descartar**: Godot 4 no tesela; el desplazamiento de vértices necesita malla densa = más tris en integrada | — | — |
| D12 | Oclusión cubemap 6 direcciones interior/exterior (Bananza) | Partículas que no entran en sitios cerrados | **Descartar**: el mapa es exterior y de una planta | — | — |
| D13 | 9 plantillas de calidad × texturas (Bananza) | Pipeline de materiales | **Descartar**: ya tenemos [ESTILO] + `docs/ASSETS_FALTANTES.md`; añadir solo la regla de D7 | — | — |
| D14 | Máscara de suciedad/mojado en el personaje (Odyssey) | La chibi no "se moja" al recibir agua | **Opcional 2D-friendly**: en 3D un uniform `mojado` que oscurece albedo + baja rugosidad; en 2D un `modulate` | 1 uniform / 1 modulate | Pipeline |
| D15 | Blend de dos materiales por vértice (BotW terreno) | Transiciones de suelo | **Ya está** (`CODIGO_SUELO` mezcla 4 por celda con ruido). Solo tomar la mejora: usar la altura de la textura para que la hierba "muerda" el camino en vez de fundirse | 1 canal más o la `r.b` del campo | Pipeline |

Lo que vale para el juego 2D (`nivel_base.gd`): D2 (estado por celda) y D14 se traducen a `modulate`/un
shader `CanvasItem` sobre el tile; D1, D3, D4, D5 no (son 3D o se prerenderizan). Se detalla en §4.

---

## 2. Desarrollos para programación (Pipeline)

Cada desarrollo lleva: por qué, cómo en Godot 4.7, qué medir. Todo en `poc_25d/` salvo que se diga.
Código orientativo, no para pegar sin leer; nombres en español como el resto del POC.

### D2 — Capa de estado del terreno (primero: es la base de D1, D4, D5 y D6)

**Por qué.** Hoy un fuego sobre hierba produce partículas y nada más; cuando se apagan el mundo está
igual. Bananza guarda por vóxel *humedad, daño y material*; BotW guarda por celda la altura y el color
de la hierba. Nosotros ya tenemos la unidad: la celda de `S = 2.3 u` y el `Image` `_img_mapa` 40×40 que
alimenta `CODIGO_SUELO`. Basta un segundo `Image` del mismo tamaño con el **estado** y leerlo en los
shaders de suelo, hierba y agua. Un `Image` de 40×40 RGBA8 son 6,4 KB; subirlo con `ImageTexture.update()`
cuando cambia una celda cuesta nada.

**Canales** (0–1, se pueden mezclar):

| Canal | Significado | Quién lo escribe | Decae |
|---|---|---|---|
| R | **quemado** (ceniza) | impacto de fuego sobre hierba / seto | no (o muy lento) |
| G | **mojado** | impacto de agua, charco; la lluvia si la hay | sí, ~6 s como el estado del enemigo |
| B | **helado / escarcha** | impacto de hielo sobre suelo o agua | sí, salvo "hielo permanente" |
| A | **pisado** (hierba aplastada) | posición del jugador y goblins cada frame | sí, ~2 s |

**Cómo.** En `prueba_test2.gd`:

```gdscript
var _img_estado: Image = null          # 40×40 RGBA8, un píxel por celda
var _tex_estado: ImageTexture = null

func _crear_estado() -> void:
	_img_estado = Image.create(_lado, _lado, false, Image.FORMAT_RGBA8)
	_img_estado.fill(Color(0, 0, 0, 0))
	_tex_estado = ImageTexture.create_from_image(_img_estado)
	# El mismo texture en los tres materiales: suelo, hierba y agua.
	mat_suelo.set_shader_parameter("estado", _tex_estado)

## Suma `cantidad` al canal `canal` de la celda y sus vecinas (radio en celdas), saturando a 1.
func marcar_estado(c: Vector2i, canal: int, cantidad: float, radio: int = 0) -> void:
	for y in range(c.y - radio, c.y + radio + 1):
		for x in range(c.x - radio, c.x + radio + 1):
			if x < 0 or y < 0 or x >= _lado or y >= _lado:
				continue
			var p: Color = _img_estado.get_pixel(x, y)
			p[canal] = minf(p[canal] + cantidad, 1.0)
			_img_estado.set_pixel(x, y, p)
	_tex_estado.update(_img_estado)   # no create_from_image: update() reutiliza la textura en GPU

## Decaimiento: G, B y A bajan con el tiempo. Se hace cada 0,25 s, no cada frame (40×40 = 1600 get/set).
func _decaer_estado(delta: float) -> void:
	for y in _lado:
		for x in _lado:
			var p: Color = _img_estado.get_pixel(x, y)
			if p.g + p.b + p.a <= 0.0:
				continue
			p.g = maxf(p.g - delta / 6.0, 0.0)
			p.b = maxf(p.b - delta / 20.0, 0.0)
			p.a = maxf(p.a - delta / 2.0, 0.0)
			_img_estado.set_pixel(x, y, p)
	_tex_estado.update(_img_estado)
```

Dónde engancharlo: `lab_vfx_3d.gd::_al_impactar(elemento, punto)` ya recibe el elemento y el punto; ahí
`marcar_estado(celda(punto), canal_de(elemento), 1.0, 1)`. Fuego sobre una celda con `G > 0.5` no marca R
(el mojado apaga, igual que en el combate); hielo sobre agua marca B y el shader de agua lo lee.

En `CODIGO_SUELO`, después de calcular `col`:

```glsl
uniform sampler2D estado : filter_linear, repeat_disable;   // mismo uv que `mapa`
uniform sampler2D t_ceniza : source_color, filter_linear_mipmap, repeat_enable;  // Pablo
uniform sampler2D t_escarcha : source_color, filter_linear_mipmap, repeat_enable; // Pablo
...
	vec4 e = texture(estado, c / lado);
	// Quemado: cruza a la textura de ceniza con el mismo ruido de borde que el resto (dureza).
	float q = smoothstep(0.5 - dureza, 0.5 + dureza, e.r + (r.r - 0.5) * ruido);
	col = mix(col, muestra(t_ceniza, t, m), q);
	// Mojado: albedo más oscuro y saturado, rugosidad baja (lo de Bananza: "wet = darken + gloss").
	col = mix(col, col * col * 1.6, e.g * 0.8);
	float rug = mix(1.0, 0.35, e.g);
	// Escarcha: aclara y tira a cian; encima de todo.
	col = mix(col, muestra(t_escarcha, t, m), smoothstep(0.3, 0.8, e.b));
	ALBEDO = col * brillo * (1.0 + (r.a - 0.5) * 2.0 * variacion);
	ROUGHNESS = rug;
	SPECULAR = mix(0.0, 0.5, e.g);
```

`filter_linear` en `estado` hace que el borde entre celdas se funda media celda; con `dureza` y el ruido
del `campo` queda orgánico, igual que las transiciones de suelo actuales. Sin texturas de Pablo, `t_ceniza`
puede ser `t_tierra * 0.35` y `t_escarcha` `vec3(0.85, 0.95, 1.0)` para probar.

En `CODIGO_MATOJO` / `CODIGO_TARJETA` (`hierba_3d.gd`), en `vertex()`:

```glsl
uniform sampler2D estado : filter_linear, repeat_disable;
uniform float celda = 2.3;
uniform float lado = 40.0;
...
	vec4 e = texture(estado, mundo.xz / (celda * lado));
	// Quemada: se encoge al 25 % y en fragment se tiñe de ceniza (varying `quemado`).
	// Pisada: se tumba hacia +x/+z un 60 % (el rastro fino de D5 lo mejora).
	float encoger = mix(1.0, 0.25, e.r);
	VERTEX.y *= encoger;
	VERTEX.xz += vec2(0.06, 0.03) * e.a * alto * alto / escala_modelo;
	quemado = e.r;
```

y en `fragment()` `c = mix(c, vec3(0.22, 0.2, 0.18), quemado)`. Como la hierba es `MultiMesh` por bloques,
esto no toca instancias ni CPU: **el fuego que quema hierba cuesta lo mismo que no quemarla**.

**Medir.** `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME` y FPS antes/después con 20 impactos de fuego
seguidos (tecla B del laboratorio). Esperado: ±0 draw calls, < 0,2 ms por `update()`.

### D1 — Agua estilizada (sustituye el triplanar con `uv1_offset`)

**Por qué.** El agua actual es una textura plana desplazándose; no se distingue orilla de centro ni se nota
el volumen. La receta del dosier (Beer-Lambert para claro/oscuro, espuma por diferencia de profundidad,
dos normales desplazadas, fresnel) es la de "agua de juego estilizado" que usan Odyssey y BotW y entra
en un solo `ShaderMaterial` sin pases extra. Único coste real: `hint_depth_texture` activa la copia del
depth buffer (una vez por frame, Forward+ ya la tiene para el SSAO si se usa; aquí no, así que es una copia
de 1 pantalla por frame, aceptable). Si en la Intel se nota, hay fallback sin depth (§D1-b).

**Cómo.** Nuevo `CODIGO_AGUA` en `prueba_test2.gd`, aplicado a la **tapa** de `_malla_bloque(ALTO_AGUA, ...)`
(el lado se queda con `mat_lado`):

```glsl
shader_type spatial;
render_mode cull_back, depth_draw_opaque;   // sin transparencia real: barato y sin problemas de orden
uniform sampler2D depth : hint_depth_texture, filter_linear;
uniform sampler2D n1 : hint_normal, filter_linear_mipmap, repeat_enable;   // Pablo (o generada)
uniform sampler2D t_agua : source_color, filter_linear_mipmap, repeat_enable; // la water_arriba.png actual
uniform sampler2D estado : filter_linear, repeat_disable;
uniform vec3 color_somero : source_color = vec3(0.45, 0.80, 0.85);
uniform vec3 color_hondo : source_color = vec3(0.12, 0.40, 0.62);
uniform float absorcion = 2.5;      // Beer-Lambert: cuánto tarda en oscurecer con la profundidad
uniform float dist_espuma = 0.18;   // en unidades de mundo
uniform float celda = 2.3;
uniform float lado = 40.0;
uniform float fuerza_normal = 0.35;

// Profundidad lineal del depth buffer. Se usa la inversa de la proyección y no la fórmula corta del dosier
// (P[3][2] / (d + P[2][2])) porque Godot 4.3+ usa Z invertida en Forward+ y la corta da valores al revés.
float prof_lineal(vec2 suv, float d, mat4 IP) {
	vec4 v = IP * vec4(suv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}

void fragment() {
	vec3 pm = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 uv = pm.xz / (celda * 2.0);
	// Dos muestras de la misma normal, direcciones y velocidades distintas: rompe la repetición.
	vec3 na = texture(n1, uv + TIME * vec2(0.020, 0.011)).rgb * 2.0 - 1.0;
	vec3 nb = texture(n1, uv * 1.7 - TIME * vec2(0.013, 0.017)).rgb * 2.0 - 1.0;
	vec3 n = normalize(vec3((na.xy + nb.xy) * fuerza_normal, 1.0));
	// Profundidad del fondo bajo este píxel vs. profundidad de la superficie.
	float d_fondo = prof_lineal(SCREEN_UV, texture(depth, SCREEN_UV).r, INV_PROJECTION_MATRIX);
	float d_sup = -VERTEX.z;   // VERTEX en fragment() está en espacio de vista: su -z es la profundidad lineal
	float grosor = max(d_fondo - d_sup, 0.0);
	// Beer-Lambert: claro en la orilla, hondo en el centro.
	vec3 col = mix(color_hondo, color_somero, exp(-grosor * absorcion));
	col *= mix(vec3(1.0), texture(t_agua, uv + n.xy * 0.03).rgb, 0.5); // la pintura actual, como detalle
	// Espuma donde el fondo casi toca la superficie (orilla, piedras, pasaderos).
	float espuma = 1.0 - smoothstep(0.0, dist_espuma, grosor);
	espuma *= step(0.35, fract(uv.x * 3.0 + uv.y * 2.0 + TIME * 0.4 + n.x)); // rota, no una línea plana
	col = mix(col, vec3(0.95, 0.98, 1.0), espuma * 0.9);
	// Hielo (D2 canal B): sin movimiento, pálido, opaco.
	vec4 e = texture(estado, pm.xz / (celda * lado));
	col = mix(col, vec3(0.80, 0.92, 0.97), smoothstep(0.3, 0.8, e.b));
	n = mix(n, vec3(0.0, 0.0, 1.0), e.b);
	ALBEDO = col;
	NORMAL_MAP = n * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
	ROUGHNESS = mix(0.15, 0.6, e.b);
	SPECULAR = 0.5;
	// Fresnel: de frente se ve el color, al ras refleja el cielo (más claro).
	float fres = pow(1.0 - clamp(dot(normalize(-VERTEX), NORMAL), 0.0, 1.0), 4.0);
	ALBEDO = mix(ALBEDO, vec3(0.86, 0.93, 1.0), fres * 0.4 * (1.0 - e.b));
}
```

Se quita `_mat_agua.uv1_offset += ...` de `_process` (línea ~1102): el movimiento ya está en `TIME`.
`_textura_hielo()` (línea 649) deja de hacer falta para el agua congelada por hechizo; los **empujables**
de hielo la siguen usando hasta que exista `hielo_arriba.png` (ya pedida en `PROMPTS_FALTANTES.md`).

**D1-b, fallback sin depth.** Si la Intel pierde más de 10 % con `hint_depth_texture`: sustituir `grosor`
por una **máscara de orilla precalculada** en el mismo `Image` del mapa (distancia en celdas a la celda de
tierra más cercana, calculada una vez en `_construir_suelo`). Pierde la espuma contra pasaderos y piedras
colocadas, mantiene orilla y claro/hondo. Es exactamente la simplificación que hace BotW para el agua
lejana.

**Medir.** FPS con la cámara llena de agua (ir a la zona del río, tecla +/- zoom) con y sin
`hint_depth_texture` (comentar la línea de `depth` y poner `grosor = 1.0`).

### D3 — Rampa difusa de contraste (toon suave en suelo y bloques)

**Por qué.** La elfa chibi sale del pipeline con 2 bandas de cel (`anime_a.json`); el suelo y los bloques
de Test2 son PBR con `ROUGHNESS = 1`. Journey resuelve la misma tensión con una rampa: `N.y *= 0.3` para
aplanar el terreno y `saturate(4·N·L)` para que la luz "muerda" en vez de degradar. En Godot se hace en
`light()`:

```glsl
uniform float contraste = 4.0;   // 1.0 = PBR normal; 4.0 = cel suave
uniform vec3 sombra_tinte : source_color = vec3(0.62, 0.66, 0.82); // sombra fría pastel (canon)
void light() {
	float ndl = clamp(dot(NORMAL, LIGHT) * contraste, 0.0, 1.0);
	ndl = smoothstep(0.0, 1.0, ndl);
	DIFFUSE_LIGHT += mix(ALBEDO * sombra_tinte, ALBEDO, ndl) * LIGHT_COLOR * ATTENUATION;
}
```

Va en `CODIGO_SUELO`, `CODIGO_AGUA` (sin él las normales del agua pierden gracia; usar `contraste = 2`)
y en los lados de `_malla_bloque`. **No** en la hierba: ya fija `NORMAL` hacia arriba y se degrada por
`alto`. La `sombra_tinte` sustituye al `OSCURECER_SUELO` de `_mat_triplanar`.

**Medir.** Solo visual: captura de la elfa sobre hierba y sobre camino con `contraste` 1 / 2.5 / 4; QA
elige y se anota en `docs/ARTE.md` (archivo de Pipeline; QA propone, Pipeline escribe).

### D4 — Hierba que se aparta del jugador

**Por qué.** 4 líneas y se nota en cada paso. Es la receta estándar de Godot: un uniform global con la
posición del jugador y empujar los vértices altos en dirección radial.

**Cómo.** En `project.godot` (Pablo o Pipeline; es un cambio de proyecto): `shader_globals/posicion_jugador`
tipo `vec3`. En `prueba_test2.gd::_process`: `RenderingServer.global_shader_parameter_set("posicion_jugador",
_jugador.global_position)`. En los dos shaders de `hierba_3d.gd`, en `vertex()` tras el viento:

```glsl
global uniform vec3 posicion_jugador;
uniform float radio_pisar = 0.7;   // ≈ 1/3 de celda
...
	vec2 d = mundo.xz - posicion_jugador.xz;
	float cerca = 1.0 - smoothstep(0.0, radio_pisar, length(d));
	vec2 apartar = normalize(d + vec2(0.001)) * cerca * alto * alto * 0.35;
	// (mismo divisor de escala que el empuje del viento)
```

Para los goblins no compensa un uniform por cada uno: con el canal A de D2 (pisado) basta.

### D5 — Rastro fino por SubViewport (huellas y hierba aplastada que se recupera)

**Por qué.** D2 marca por celda (2,3 u); una huella es 0,2 u. El dosier de deformación describe lo justo:
un `SubViewport` con cámara ortográfica cenital que mira **solo** al mapa, donde cada paso dibuja un
`Sprite2D` (la huella) y un `ColorRect` semitransparente por frame va "borrando" (`clear_mode` KEEP +
rectángulo negro con alpha 0,02). La textura resultante se lee en suelo y hierba como D2 pero con detalle.
Para un mapa de 40 celdas × 2,3 u = 92 u, un viewport de **512×512** da 5,5 px por unidad: una huella de
0,2 u son 1,1 px… demasiado poco. **1024×1024** (11 px/u) es el mínimo útil y son 4 MB de VRAM RGBA8;
en R8 (solo intensidad) 1 MB. Recomendación: **R8 a 1024, estático** (no sigue al jugador: el mapa cabe).

**Cómo.** Nuevo nodo `Rastro3D` (Pipeline): `SubViewport` 1024², `render_target_update_mode = ALWAYS`,
`transparent_bg = false`, `Camera2D` fija; método `pisar(pos_mundo: Vector3, giro: float)` que instancia
una `Sprite2D` con `huella.png` (Pablo: 64×64, blanca sobre transparente, forma de pie chibi) en
`(pos.x, pos.z) * (1024 / 92)` y la elimina tras 0,1 s (el viewport conserva lo dibujado). Desvanecer: un
`ColorRect` negro a pantalla completa con `modulate.a = 0.015` que se dibuja cada frame; a 60 fps un
rastro dura ~1 s en bajar a la mitad. El shader de suelo lee `rastro` con las mismas uv que `estado` y
oscurece `col *= 1.0 - 0.25 * rastro` (huella húmeda en tierra, ceniza removida en quemado); la hierba
lo suma al canal A.

Nieve/arena con **desplazamiento de vértices** (la huella hundida de verdad): solo si una zona concreta
del mapa es nieve; el suelo de Test2 es un plano de 1 quad por celda, habría que subdividirlo a 8×8 por
celda **solo en esas celdas**. No hacerlo en todo el mapa (D11).

**Medir.** Un SubViewport 1024² R8 actualizado cada frame: esperado < 0,3 ms en integrada; si sube de
1 ms, `update_mode = ONCE` y disparar `update` solo cuando alguien pisa.

### D6 — Empujables con cara arriba / lado separadas y grietas por daño

**Por qué.** Bananza separa albedo de tapa y de lado y añade normal de grieta + AO según daño. Nuestros
empujables (`_colocar_empujables`, línea 669) son un cubo con la textura del suelo por los seis lados.
`_malla_bloque` ya tiene `mat_tapa` y `mat_lado`: usarlos también aquí resuelve la mitad.

**Cómo.** Tapa: `tierra_arriba.png` (ya existe como `t_tierra`); lado: `tierra_lado.png` (Pablo, 512,
franjas horizontales de estratos pastel). Grietas: un uniform `danio` (0–1) y `t_grietas` (Pablo, 512,
máscara blanca sobre negro, 3 niveles separados en R/G/B para que `danio` las vaya encendiendo):

```glsl
float g = step(1.0 - danio, texture(t_grietas, UV).r);   // R = grietas leves, G = medias, B = rotura
ALBEDO = mix(albedo, albedo * 0.45, g);
```

Para hielo, mismo esquema con `hielo_arriba.png` + `hielo_lado.png` y las grietas en azul claro en vez de
oscuras. El `danio` lo sube el juego cuando el bloque recibe tierra (rompe) o fuego (derrite el hielo).

### D7 — Reglas de presupuesto en GPU integrada (BotW: "la captura manda")

BotW decidía la resolución de cada textura mirando cuántos píxeles ocupaba en pantalla en capturas
reales. Nosotros no necesitamos la herramienta, solo la regla, porque la cámara es ortográfica fija:
**el tamaño en pantalla de cada cosa es constante**.

1. QA mide una vez con el HUD (tecla P): píxeles de alto de una celda, de la elfa, de un árbol, de un
   prop a 1080p y al zoom por defecto. Se anota en `docs/ASSETS_FALTANTES.md` junto al poly budget.
2. Regla: **textura ≤ 2 × píxeles en pantalla** (el ×2 por el zoom máximo y los mips). Si un prop ocupa
   120 px, su textura es 256, no 1024. Las de 2048 de Meshy se bajan en el import (`Image.resize` en
   `INTEGRAR_PIEZAS` o preset de import).
3. Todo lo que está a más de 2 celdas del borde de pantalla no proyecta sombra: `GeometryInstance3D.cast_shadow
   = OFF` para hierba (ya), props pequeños y oro; solo árboles, bloques y personajes proyectan.
4. Compresión: `compress/mode = 2` (VRAM compressed) en todo lo que no sea sprite de VFX; `detect_3d`
   apagado en `pipeline_output` (ya está en `PLAN_ACCION_TEST2.md`, se mantiene aquí como regla).

### D8 y D10 — Opcionales medidos

- **Cáusticas** (D8): con `d_fondo` de D1 se reconstruye el punto del fondo
  `pf = INV_VIEW_MATRIX * vec4(VIEW_dir * d_fondo, 1.0)` y se muestrea `t_causticas(pf.xz * 0.4 + TIME*0.02)`
  sumándolo a `col` solo donde `grosor < 1.0`. Una muestra más. Pablo: textura cáustica 256 tileable, blanca
  sobre negro, trazo suave (no la Voronoi dura de los realistas).
- **Destellos en hielo** (D10): `float chispa = step(0.985, dot(reflect(-LIGHT, normal_ruidosa), VIEW))`
  donde `normal_ruidosa` es la normal con un ruido por píxel (`fract(sin(dot(uv, vec2(12.9898, 78.233)))
  * 43758.5453)`). Solo si `e.b > 0.5`. Barato porque las celdas heladas son pocas.

---

## 3. Desarrollos para arte (Pablo)

Lo que hace falta generar para los desarrollos anteriores, en orden de uso. Todas las texturas de suelo
**tileables en los cuatro bordes**, mismo estilo pastel pintado que `water_arriba.png` y las de
`suelo/`. Prompt base para Meshy/imagen, cambiando la pieza:

> Seamless tileable hand-painted game ground texture, top view, soft pastel painted style matching a
> Ghibli-inspired chibi game, no objects, no harsh shadows, square **[tamaño]**, tileable on all four edges.
> **[pieza]**

| Archivo | Para | Tamaño | [pieza] |
|---|---|---|---|
| `suelo/ceniza_arriba.png` | D2 (R quemado) | 512 | burnt ground: dark grey ash with a few charred black patches and faint orange embers, matte |
| `suelo/escarcha_arriba.png` | D2 (B helado) | 512 | frosted ground: pale cyan-white frost crystals over faint green, soft sparkle dots, no snowflake shapes |
| `suelo/agua_normal.png` | D1 | 512 | **normal map** of gentle rolling water ripples, low frequency, soft, tileable (si no, Pipeline la genera con `NoiseTexture2D` + `as_normal_map`) |
| `suelo/causticas.png` | D8 | 256 | soft white caustic light pattern on black, rounded cells, blurry edges, not sharp |
| `suelo/tierra_lado.png`, `suelo/hielo_lado.png` | D6 | 512 | side of an earth block: horizontal pastel soil strata with small pebbles / side of an ice block: pale cyan with vertical faint streaks |
| `suelo/grietas.png` | D6 | 512 | crack mask: white cracks on black, three growing stages in red, green and blue channels (Pipeline puede montarla a partir de una sola en escala de grises con tres umbrales) |
| `vfx/huella.png` | D5 | 64 | single chibi footprint silhouette, white on transparent, rounded, cute |
| `suelo/hielo_arriba.png` | D1/D6 | 1024 | ya en `PROMPTS_FALTANTES.md` |

Y una decisión de arte que no es textura: el color de **sombra** del mundo (D3 `sombra_tinte`). Propuesta
QA: el lila-azulado de la sombra de la elfa en el master de Meshy, para que la sombra del suelo y la del
personaje sean la misma familia. Se fija mirando la captura de D3.

---

## 4. Lo que se lleva al juego 2D

La capa de estado (D2) es la misma idea aplicada al tilemap: `nivel_base.gd` ya decide por celda si hay
hielo permanente o agua; añadir un `Dictionary` celda → `{quemado, mojado, helado}` y pintarlo con:

- quemado: cambiar el tile a `grass_burnt` (bloque pendiente de generar por el pipeline, misma plantilla
  128×102 con la cara de arriba en y=33) o, hasta entonces, `modulate = Color(0.45, 0.42, 0.40)`.
- mojado: `modulate = Color(0.78, 0.82, 0.92)` con `Tween` de vuelta en 6 s (el mismo tiempo que el estado
  del enemigo, para que se lean juntos).
- helado: ya existe (`hielo_*`), solo falta aplicar las correcciones de `docs/CAMBIOS_JUEGO_PENDIENTES.md`.
- D14 en el personaje: al recibir agua, `modulate` azulado 6 s en el `MsActor`; al quemarse, naranja 3 s.

Estos son cambios de `nivel_base.gd` y de los goblins (archivos de Juego): QA los redacta como diff en
`docs/CAMBIOS_JUEGO_PENDIENTES.md` cuando Pablo confirme en qué copia del repo se aplican.

---

## 5. Orden propuesto y cómo se valida

| Paso | Qué | Quién | Validación QA |
|---|---|---|---|
| 1 | D2 estado por celda (sin texturas, con los colores de prueba) | Pipeline | 20 fuegos con B: ±0 draw calls; la hierba quemada se ve desde la cámara |
| 2 | D4 hierba que se aparta | Pipeline | Vídeo de la elfa cruzando hierba |
| 3 | Texturas ceniza/escarcha/normal de agua | Pablo | Tileables sin costura a `tam_tex = 4.6` |
| 4 | D1 agua (con D1-b medido como fallback) | Pipeline | FPS cámara llena de agua, con y sin depth |
| 5 | D3 rampa (`contraste` 1 / 2.5 / 4, capturas) | Pipeline + QA | Elección anotada en `docs/ARTE.md` |
| 6 | D7 medición de píxeles y rebaja de texturas | QA mide, Pipeline aplica | VRAM en el administrador de tareas antes/después (hoy 2,7 GB) |
| 7 | D6 empujables | Pablo + Pipeline | Cubo con 3 niveles de grieta en `CatalogoAssets` |
| 8 | D5 rastro fino, D8 cáusticas, D10 chispa | Pipeline | Solo si 1–6 dejan margen de FPS |

Cada paso se mide en Test2 con el HUD (H/G/K/P) y se apunta en `docs/PLAN_ACCION_TEST2.md` en la tabla de
rendimiento. Nada de esto toca el prerender 2D (`test2d`) salvo que D3 cambie el look del suelo: en ese
caso hay que reprerenderizar los bloques, y conviene decidirlo antes del paso 5.

---

## 6. Descartado y por qué (para no volver a estudiarlo)

- **Teselación / desplazamiento real de arena o nieve** (Journey, LM3): Godot 4 no tiene teselación; la
  alternativa es malla densa, que es justo lo que la integrada no aguanta. D5 da el 80 % con un sprite.
- **Refracción por copia de pantalla** (Odyssey): una copia de pantalla por frame; en Forward+ sobre Intel
  cuesta más que todo D1 junto. Si algún día hay GPU dedicada, se añade con `hint_screen_texture`.
- **Oclusión cubemap de 6 direcciones** (Bananza): es para interiores con partículas de clima; el mapa es
  exterior.
- **9 plantillas de calidad de material** (Bananza): sustituido por [ESTILO] + presupuesto por asset.
- **Vóxeles**: el mundo es de celdas fijas; D2 es el equivalente 2D de "por vóxel".
- **Decals para marcas** (dosier deformación): límite de 8 por malla y solo Forward+/Mobile; el canal R
  de D2 y el rastro de D5 hacen lo mismo sin el límite.
- **Chispa de arena por bloom** (Odyssey): el bloom es un pase de pantalla; con umbral en el shader (D10)
  se consigue lo mismo en las pocas celdas de hielo.
