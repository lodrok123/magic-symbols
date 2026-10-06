# Cómo implementar las técnicas aprobadas (5 de octubre de 2026)

Guía de implementación de `docs/TECNICAS_APLICABLES.md` (aprobado por Pablo). Está escrita para que
**Pipeline** la aplique en `poc_25d/` paso a paso, y para que QA mida cada paso antes del siguiente.
Los anclajes son nombres de función y líneas del disco de hoy (`C:\Users\paranda\...`); si el archivo ha
cambiado, manda la función, no el número. Todo el código va en español como el resto del POC.

Cambios respecto a `TECNICAS_APLICABLES.md`, tras releer el código:

- **El agua no usa el depth buffer en la primera versión.** El suelo de Test2 son bloques de una celda sin
  lecho: bajo el agua no hay geometría, así que la "profundidad" sería constante (0,62 u) o infinita. La
  señal correcta aquí es la **distancia a la orilla** por celda (lo que en el doc era el fallback D1-b).
  El depth queda para una segunda versión, solo para espuma contra pasaderos y piedras, y se explica por
  qué obliga a hacer el agua transparente.
- **Sin `global uniform`**: la posición del jugador se pasa como uniform normal a los dos materiales de
  hierba cada frame (dos `set_shader_parameter` por frame; nada que tocar en `project.godot`).
- **Hechizos en Test2**: hoy solo se lanzan en `LabVfx3D`. Para ver el estado del suelo hay que poder
  lanzar en Test2: se añade `Vfx3D` y las teclas **F1–F6** (1/2/3 ya son presets de cámara).

Orden: **Paso 1 (estado + hierba que se aparta) → Paso 2 (agua) → Paso 3 (rampa) → Paso 4 (presupuesto)
→ Paso 5 (empujables, cuando estén las texturas) → Paso 6 (2D, lo redacta QA)**. Cada paso termina con
una medición que se apunta en la tabla de rendimiento de `docs/PLAN_ACCION_TEST2.md`.

---

## Paso 1 — Capa de estado por celda + hierba que se aparta (D2 + D4)

> **Corrección (17:40).** El juego 2D **ya tiene** estas reglas implementadas: `neutral_block.gd`
> (SECO → MOJADO → HELADO con dos aguas; el calor lo deshace con vapor; el charco conduce el rayo; el
> mojado **no caduca**), `grass_block.gd` (fina / crecida / prendiendo / ardiendo / cenizas, el agua
> rebrota), `water_block.gd` (se congela) y `combate_comun.gd` (tintes mojado/quemando/congelado en
> personajes). Las reglas de `_al_impactar()` y los tiempos de `_decaer_estado()` de abajo son
> **provisionales**: el Juego publica el contrato `docs/ESTADOS_SUELO.md` (ver `docs/ENCARGO_JUEGO_ESTADOS.md`)
> y el Pipeline ajusta esas dos funciones a él. Lo que no cambia: la textura de estado, los shaders y la API
> de `Hierba3D`. En concreto: el canal G (mojado) no decae, un segundo impacto de agua pasa a B (helado),
> el fuego sobre G lo seca (G = 0, vapor) y no quema, y la hierba de una celda con R (cenizas) rebrota
> (R = 0) con agua.

Archivos: `poc_25d/prueba_test2.gd`, `poc_25d/hierba_3d.gd`. Sin texturas nuevas (colores de prueba).

### 1.1 `prueba_test2.gd` — variables

Junto a `var _img_mapa: Image = null` (línea ~138):

```gdscript
var _mat_suelo: ShaderMaterial = null   ## se guarda para poder cambiarle uniforms
var _img_estado: Image = null           ## 40×40 RGBA8: R quemado · G mojado · B helado · A pisado
var _tex_estado: ImageTexture = null
var _estado_sucio: bool = false         ## true = hay que subir _img_estado a la GPU este frame
var _t_decaer: float = 0.0
var _fx: Vfx3D = null                   ## hechizos en la maqueta (F1–F6)
```

Y una constante junto a `COLOR_ELEMENTO`:

```gdscript
## Canal de _img_estado que escribe cada elemento al impactar (−1 = no deja marca).
const CANAL_ELEMENTO: Dictionary = {"fuego": 0, "agua": 1, "hielo": 2, "viento": 3, "rayo": 0, "tierra": -1}
```

### 1.2 `CODIGO_SUELO` — leer el estado

Añadir a los uniforms:

```glsl
uniform sampler2D estado : filter_linear, repeat_disable;   // mismas uv que `mapa`
uniform vec3 color_ceniza : source_color = vec3(0.22, 0.20, 0.18);
uniform vec3 color_escarcha : source_color = vec3(0.84, 0.94, 0.98);
```

Y sustituir las cuatro últimas líneas de `fragment()` (desde `ALBEDO = ...`) por:

```glsl
	vec4 e = texture(estado, uvm);          // uvm ya lleva el ruido de borde: la ceniza queda orgánica
	// Quemado: solo donde hay hierba (w.r); el camino y la piedra no arden.
	float q = smoothstep(0.5 - dureza, 0.5 + dureza, e.r) * w.r;
	col = mix(col, color_ceniza * (0.8 + 0.4 * r.a), q);
	// Mojado: más oscuro y saturado, menos rugoso (Bananza: "wet = darken + gloss").
	col = mix(col, col * col * 1.5, e.g * 0.85);
	// Escarcha: por encima de todo.
	col = mix(col, color_escarcha * (0.9 + 0.2 * r.a), smoothstep(0.3, 0.8, e.b));
	ALBEDO = col * brillo * (1.0 + (r.a - 0.5) * 2.0 * variacion);
	ROUGHNESS = mix(1.0, 0.35, e.g);
	SPECULAR = 0.5 * e.g;
```

Por qué `uvm` y no `c / lado`: `uvm` es la uv de celda ya desplazada por el ruido del campo; usándola el
borde de la ceniza ondula igual que el borde hierba/camino. Cuando Pablo entregue `ceniza_arriba.png` y
`escarcha_arriba.png`, `color_ceniza` pasa a `muestra(t_ceniza, t, m)` y lo mismo con la escarcha.

### 1.3 `_construir_suelo()` — crear la textura de estado

Tras `mat_suelo.set_shader_parameter("brillo", OSCURECER_SUELO)`:

```gdscript
	_img_estado = Image.create_empty(_lado, _lado, false, Image.FORMAT_RGBA8)
	_img_estado.fill(Color(0.0, 0.0, 0.0, 0.0))
	_tex_estado = ImageTexture.create_from_image(_img_estado)
	mat_suelo.set_shader_parameter("estado", _tex_estado)
	_mat_suelo = mat_suelo
```

### 1.4 Funciones nuevas (después de `_pisable`)

```gdscript
## Celda de un punto del mundo (sin comprobar límites).
func _celda_de(p: Vector3) -> Vector2i:
	return Vector2i(int(floorf(p.x / S)), int(floorf(p.z / S)))


## Suma `cantidad` al canal (0 R quemado · 1 G mojado · 2 B helado · 3 A pisado) de la celda y las de
## alrededor (radio en celdas), saturando a 1. No sube la textura: lo hace _process una vez por frame.
func marcar_estado(c: Vector2i, canal: int, cantidad: float, radio: int = 0) -> void:
	if canal < 0:
		return
	for y in range(c.y - radio, c.y + radio + 1):
		for x in range(c.x - radio, c.x + radio + 1):
			if x < 0 or y < 0 or x >= _lado or y >= _lado:
				continue
			# Las esquinas del cuadrado reciben la mitad: la marca queda redondeada.
			var k: float = cantidad * (0.5 if absi(x - c.x) + absi(y - c.y) > radio else 1.0)
			var p: Color = _img_estado.get_pixel(x, y)
			p[canal] = clampf(p[canal] + k, 0.0, 1.0)   # cantidad negativa = quitar (el fuego derrite escarcha)
			_img_estado.set_pixel(x, y, p)
	_estado_sucio = true


## Mojado, helado y pisado se van solos; el quemado se queda. Cada 0,25 s, no cada frame.
func _decaer_estado(dt: float) -> void:
	var cambio: bool = false
	for y in range(_lado):
		for x in range(_lado):
			var p: Color = _img_estado.get_pixel(x, y)
			if p.g <= 0.0 and p.b <= 0.0 and p.a <= 0.0:
				continue
			p.g = maxf(p.g - dt / 6.0, 0.0)     # 6 s, como el estado "mojado" del combate
			p.b = maxf(p.b - dt / 20.0, 0.0)    # 20 s (el hielo permanente irá aparte)
			p.a = maxf(p.a - dt / 2.0, 0.0)     # 2 s: la hierba pisada se levanta
			_img_estado.set_pixel(x, y, p)
			cambio = true
	if cambio:
		_estado_sucio = true


## Qué deja cada hechizo en el suelo. El mojado apaga el fuego (vapor, como en el combate).
func _al_impactar(elemento: String, punto: Vector3) -> void:
	var c: Vector2i = _celda_de(punto)
	if c.x < 0 or c.y < 0 or c.x >= _lado or c.y >= _lado:
		return
	var actual: Color = _img_estado.get_pixel(c.x, c.y)
	match elemento:
		"fuego":
			if actual.g > 0.5:
				return
			marcar_estado(c, 0, 1.0, 1)
			marcar_estado(c, 2, -1.0, 1)        # el fuego derrite la escarcha (cantidad negativa resta)
		"agua":
			marcar_estado(c, 1, 1.0, 1)
			marcar_estado(c, 0, -0.5, 0)        # y lava parte de la ceniza
		"hielo":
			marcar_estado(c, 2, 1.0, 1)
		"viento":
			marcar_estado(c, 3, 1.0, 2)         # tumba la hierba en un radio grande
		"rayo":
			marcar_estado(c, 0, 0.6, 0)
```

### 1.5 `_process()` — subir la textura, decaer, hierba

Al final de `_process`, antes de `_t_hud += delta`:

```gdscript
	_t_decaer += delta
	if _t_decaer >= 0.25:
		_decaer_estado(_t_decaer)
		_t_decaer = 0.0
	if _estado_sucio:
		_tex_estado.update(_img_estado)    # update() reutiliza la textura en GPU; create_from_image la recrearía
		_estado_sucio = false
	if _hierba != null and _jugador != null:
		_hierba.set_posicion_jugador(_jugador.position)
```

Y en `_mover()`, justo después de `_jugador.position = destino`:

```gdscript
	marcar_estado(c, 3, 0.35)    # pisa la hierba de su celda (c ya está calculada dos líneas arriba)
```

### 1.6 Hechizos en la maqueta

En `_ready()`, después de crear `_efectos`:

```gdscript
	_fx = Vfx3D.new()
	_efectos.add_child(_fx)
	_fx.impacto.connect(_al_impactar)
```

En `_unhandled_input`, dentro del `match`:

```gdscript
		KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6:
			if _jugador != null:
				_lanzar(String(Vfx3D.ELEMENTOS[k.keycode - KEY_F1]))
```

Y la función (el orden de `Vfx3D.ELEMENTOS` es fuego, agua, tierra, viento, rayo, hielo):

```gdscript
## Lanza hacia donde mira la chibi, a 2,5 celdas (con tierra y rayo el efecto brota en el destino).
func _lanzar(elemento: String) -> void:
	var d := Vector3(sin(_jugador.rotation.y), 0.0, cos(_jugador.rotation.y))
	var destino: Vector3 = _jugador.position + d * S * 2.5
	var c: Vector2i = _celda_de(destino)
	destino.y = ALTO_AGUA if (c.y >= 0 and c.y < _lado and c.x >= 0 and _es_agua(_letra(c))) else ALTO
	_jugador.jugar("cast")
	get_tree().create_timer(0.9, false).timeout.connect(_jugador.jugar.bind("idle"))
	_fx.lanzar(elemento, _jugador.position + d * 0.3, destino)
```

Añadir a la segunda línea del HUD: `· F1–F6 hechizos`.

### 1.7 `hierba_3d.gd` — leer el estado y apartarse del jugador

Uniforms nuevos en **los dos** shaders (`CODIGO_MATOJO` y `CODIGO_TARJETA`):

```glsl
uniform sampler2D estado : filter_linear, repeat_disable;
uniform float celda = 2.3;
uniform float lado = 40.0;
uniform vec3 posicion_jugador = vec3(-1000.0, 0.0, -1000.0);
uniform float radio_pisar = 0.7;    // ≈ 1/3 de celda
varying float quemado;
```

`CODIGO_MATOJO`, `vertex()` completo (sustituye al actual):

```glsl
void vertex() {
	alto = UV.y;
	tinte = INSTANCE_CUSTOM.rgb;
	vec3 origen = MODEL_MATRIX[3].xyz;
	vec4 e = texture(estado, origen.xz / (celda * lado));
	quemado = e.r;
	// Quemada: se queda en un cuarto de alto. Se escala el vértice local antes de todo lo demás.
	VERTEX.y *= mix(1.0, 0.25, smoothstep(0.2, 0.8, e.r));
	vec3 mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * 1.7 + mundo.x * 0.55 + mundo.z * 0.35;
	float empuje = (sin(t) * 0.6 + sin(t * 2.3 + 1.7) * 0.25) * viento * alto * alto;
	float inv_x = 1.0 / max(length(MODEL_MATRIX[0].xyz), 0.001);
	float inv_z = 1.0 / max(length(MODEL_MATRIX[2].xyz), 0.001);
	VERTEX.x += empuje * 0.05 * inv_x;
	VERTEX.z += empuje * 0.025 * inv_z;
	// Pisada por celda (canal A): se tumba hacia +x+z. Mojada (G): se tumba un poco, pesa.
	float tumbar = max(e.a, e.g * 0.3) * alto * alto;
	VERTEX.x += tumbar * 0.18 * inv_x;
	VERTEX.z += tumbar * 0.10 * inv_z;
	// Se aparta de la chibi en radial (D4).
	vec2 d = origen.xz - posicion_jugador.xz;
	float cerca = 1.0 - smoothstep(0.0, radio_pisar, length(d));
	vec2 apartar = normalize(d + vec2(0.001, 0.0)) * cerca * alto * alto * 0.3;
	VERTEX.x += apartar.x * inv_x;
	VERTEX.z += apartar.y * inv_z;
}
```

y en su `fragment()`: `vec3 c = mix(mix(base, punta, smoothstep(0.0, 1.0, alto)), vec3(0.24, 0.22, 0.20), quemado);`.

`CODIGO_TARJETA`, en `vertex()`: tras `float alto = 1.0 - UV.y;` y `vec3 origen = ...`:

```glsl
	vec4 e = texture(estado, origen.xz / (celda * lado));
	quemado = e.r;
	float escala_y = mix(1.0, 0.3, smoothstep(0.2, 0.8, e.r));
	vec2 d = origen.xz - posicion_jugador.xz;
	float cerca = 1.0 - smoothstep(0.0, radio_pisar, length(d));
	float tumbar = (max(e.a, e.g * 0.3) + cerca) * alto * alto * 0.25;
```

y cambiar la línea `vec3 mundo = ...` por:

```glsl
	vec3 mundo = origen + (der * (VERTEX.x + empuje + tumbar) + arr * VERTEX.y * escala_y) * esc;
```

En su `fragment()`: `ALBEDO = mix(c.rgb * tinte, vec3(0.24, 0.22, 0.20), quemado) * brillo;`.

API nueva en `Hierba3D` (después de `set_viento`):

```gdscript
## Textura de estado del suelo (R quemado · G mojado · B helado · A pisado) y rejilla que la indexa.
func set_estado(tex: Texture2D, celda: float, lado: float) -> void:
	for m in [_mat_matojo, _mat_tarjeta]:
		if m != null:
			m.set_shader_parameter("estado", tex)
			m.set_shader_parameter("celda", celda)
			m.set_shader_parameter("lado", lado)


func set_posicion_jugador(p: Vector3) -> void:
	for m in [_mat_matojo, _mat_tarjeta]:
		if m != null:
			m.set_shader_parameter("posicion_jugador", p)
```

Y en `prueba_test2.gd::_sembrar_hierba()`, tras `_hierba.sembrar(...)`:
`_hierba.set_estado(_tex_estado, S, float(_lado))`. (`_preparar()` crea los materiales dentro de
`sembrar`, por eso va después.) Las flores no leen el estado: cuando la celda arde, lo honesto sería
borrarlas; se deja para cuando el bloque de hierba se recree (son `MultiMesh` por bloque; `_crear_bloque`
puede saltarse flores en celdas con `e.r > 0.5` si se le pasa `_img_estado`; opcional).

### 1.8 Medición del paso 1 (QA)

Con `B` no hay bucle en Test2: lanzar **20 fuegos seguidos con F1** andando por la hierba y luego 20 aguas.

| Medida (HUD) | Antes | Después | Esperado |
|---|---|---|---|
| llamadas de dibujo | | | +0 (el `Vfx3D` suma las suyas mientras hay partículas; contar con P apagado) |
| FPS andando por hierba | | | igual ±1 |
| ms de `_decaer_estado` (medir con `Time.get_ticks_usec()` alrededor) | | | < 0,3 ms cada 0,25 s |

Visual: la ceniza aparece bajo la llama con borde ondulado y no en el camino; la hierba de la celda se
encoge y oscurece; el agua oscurece el suelo y se seca en ~6 s; la elfa abre un claro al andar.

---

## Paso 2 — Agua estilizada por distancia a la orilla (D1, versión sin depth)

Archivo: `poc_25d/prueba_test2.gd`. Sin texturas obligatorias: la normal se genera con `NoiseTexture2D`
hasta que exista `suelo_meshy/agua_normal.png`.

### 2.1 Mapa de orilla

En `_construir_suelo()`, antes de crear `_mat_agua`, un BFS desde las celdas de tierra:

```gdscript
	# Distancia de cada celda de agua a la tierra más cercana, en celdas (0 = orilla, 3+ = hondo).
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
			var d: float = float(dist.get(Vector2i(x, y), 0))
			orilla.set_pixel(x, y, Color(clampf((d - 0.5) / 3.0, 0.0, 1.0), 0.0, 0.0))
```

`(d − 0,5) / 3`: la celda pegada a tierra (d = 1) vale 0,17, a tres celdas ya es hondo. Con
`filter_linear` el degradado cruza media celda a cada lado, y el ruido del campo lo ondula.

### 2.2 `CODIGO_AGUA`

Nueva constante junto a `CODIGO_SUELO`:

```glsl
const CODIGO_AGUA: String = """
shader_type spatial;
render_mode cull_back;
uniform sampler2D orilla : filter_linear, repeat_disable;     // 0 orilla … 1 hondo
uniform sampler2D campo : filter_linear, repeat_enable;        // el mismo ruido del suelo
uniform sampler2D estado : filter_linear, repeat_disable;      // B = helado
uniform sampler2D normal_agua : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_agua : source_color, filter_linear_mipmap, repeat_enable;  // water_arriba.png
uniform vec3 color_somero : source_color = vec3(0.52, 0.84, 0.86);
uniform vec3 color_hondo : source_color = vec3(0.16, 0.44, 0.66);
uniform vec3 color_espuma : source_color = vec3(0.96, 0.99, 1.0);
uniform vec3 color_hielo : source_color = vec3(0.82, 0.93, 0.97);
uniform float celda = 2.3;
uniform float lado = 40.0;
uniform float tam_tex = 4.6;
uniform float ruido = 0.45;
uniform float fuerza_normal = 0.4;
uniform float ancho_espuma = 0.12;
uniform float brillo = 1.0;

void fragment() {
	vec3 pm = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 c = pm.xz / celda;
	vec4 r = texture(campo, c / lado);
	vec2 uvm = (c + (r.rg - 0.5) * 2.0 * ruido) / lado;     // misma deformación que el suelo
	float hondo = texture(orilla, uvm).r;
	vec2 uv = pm.xz / tam_tex;
	// Dos muestras de la normal con rumbos y velocidades distintas: rompe la repetición.
	vec3 na = texture(normal_agua, uv + TIME * vec2(0.020, 0.011)).rgb * 2.0 - 1.0;
	vec3 nb = texture(normal_agua, uv * 1.7 - TIME * vec2(0.013, 0.017)).rgb * 2.0 - 1.0;
	vec3 n = normalize(vec3((na.xy + nb.xy) * fuerza_normal, 1.0));
	// Claro en la orilla, hondo en el centro (Beer-Lambert sobre la distancia a tierra).
	vec3 col = mix(color_somero, color_hondo, 1.0 - exp(-hondo * 2.2));
	// La pintura actual como detalle, desplazada por la normal para que "ondee".
	col *= mix(vec3(1.0), texture(t_agua, uv + n.xy * 0.04).rgb, 0.45);
	// Espuma: una banda junto a la orilla, rota por el ruido y por la normal, que avanza y retrocede.
	float borde = hondo + (r.b - 0.5) * 0.15 + n.x * 0.05 + sin(TIME * 0.8 + r.g * 6.28) * 0.03;
	float espuma = 1.0 - smoothstep(0.0, ancho_espuma, borde);
	espuma *= 0.55 + 0.45 * step(0.4, fract((uv.x + uv.y) * 2.5 + TIME * 0.3 + r.r)); // a trozos
	col = mix(col, color_espuma, espuma * 0.9);
	// Hielo (estado.b): quieto, pálido, menos brillante.
	float hielo = smoothstep(0.3, 0.8, texture(estado, uvm).b);
	col = mix(col, color_hielo * (0.9 + 0.2 * r.a), hielo);
	n = mix(n, vec3(0.0, 0.0, 1.0), hielo);
	// Fresnel suave: la cámara ortográfica inclinada lo ve casi constante; la normal lo hace variar.
	float fres = pow(1.0 - clamp(dot(VIEW, NORMAL), 0.0, 1.0), 4.0);
	col = mix(col, vec3(0.88, 0.94, 1.0), fres * 0.25 * (1.0 - hielo));
	ALBEDO = col * brillo;
	NORMAL_MAP = n * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
	ROUGHNESS = mix(0.18, 0.6, hielo);
	SPECULAR = 0.5;
}
"""
```

### 2.3 Material y limpieza

Cambiar `var _mat_agua: StandardMaterial3D = null` por `var _mat_agua: ShaderMaterial = null` y en
`_construir_suelo()` sustituir `_mat_agua = _mat_triplanar(SUELO + "water_arriba.png", ...)` por:

```gdscript
	var sha := Shader.new()
	sha.code = CODIGO_AGUA
	_mat_agua = ShaderMaterial.new()
	_mat_agua.shader = sha
	_mat_agua.set_shader_parameter("orilla", ImageTexture.create_from_image(orilla))
	_mat_agua.set_shader_parameter("campo", mat_suelo.get_shader_parameter("campo"))
	_mat_agua.set_shader_parameter("estado", _tex_estado)
	_mat_agua.set_shader_parameter("t_agua", _tex(SUELO + "water_arriba.png"))
	_mat_agua.set_shader_parameter("normal_agua", _normal_agua())
	_mat_agua.set_shader_parameter("celda", S)
	_mat_agua.set_shader_parameter("lado", float(_lado))
	_mat_agua.set_shader_parameter("tam_tex", S * 2.0)
	_mat_agua.set_shader_parameter("brillo", OSCURECER_SUELO)
```

Función nueva:

```gdscript
## Normal del agua: la pintada por Pablo si existe; si no, ruido suave convertido a normal.
func _normal_agua() -> Texture2D:
	if ResourceLoader.exists(SUELO + "agua_normal.png"):     # no _tex(): que no salga el aviso (!) mientras no exista
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
```

`NoiseTexture2D` se genera en un hilo: el primer frame el agua sale
plana; aceptable en la maqueta.

Quitar de `_process` las dos líneas `if _mat_agua != null: _mat_agua.uv1_offset += ...` (el movimiento
ya va con `TIME`). `_textura_hielo()` se queda solo para los empujables.

### 2.4 Segunda versión: espuma contra objetos con depth (opcional, medir)

Para que las piedras, pasaderos y postes del puente tengan espuma alrededor hace falta comparar la
profundidad del agua con la de lo que hay detrás. En Godot eso obliga a que el agua se dibuje en la
**pasada transparente** (si es opaca, el depth prepass ya contiene el agua y la diferencia es 0). Cambios:

- `render_mode cull_back, depth_draw_always;` y al final de `fragment()` `ALPHA = 1.0;` (escribir ALPHA la
  manda a la pasada transparente aunque sea opaca).
- `uniform sampler2D depth : hint_depth_texture, filter_nearest;` y:

```glsl
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, texture(depth, SCREEN_UV).r, 1.0);
	float d_fondo = -v.z / v.w;          // funciona con la Z invertida de Godot 4.3+
	float grosor = max(d_fondo + VERTEX.z, 0.0);   // VERTEX.z es negativo en espacio de vista
	espuma = max(espuma, 1.0 - smoothstep(0.0, 0.25, grosor));
```

Coste: la pasada transparente no usa el prepass y el agua pasa a ordenarse con partículas y hierba.
**Medir** con la cámara llena de río: si baja > 5 % de FPS, se queda la versión 2.2.

### 2.5 Medición del paso 2 (QA)

| Medida | Triplanar (antes) | Orilla (2.2) | Con depth (2.4) |
|---|---|---|---|
| FPS cámara llena de río, zoom por defecto | | | |
| FPS zoom mínimo (+ hasta tope) | | | |
| VRAM (HUD) | | | |

Visual: orilla clara con espuma rota, centro hondo, ondas sin rejilla visible, hielo con F6 sobre el agua
queda quieto y pálido.

---

## Paso 3 — Rampa de contraste (D3)

Archivo: `poc_25d/prueba_test2.gd` (`CODIGO_SUELO` y `CODIGO_AGUA`).

Añadir a ambos shaders:

```glsl
uniform float contraste = 2.5;                                 // 1 = PBR; 4 = cel suave
uniform vec3 sombra_tinte : source_color = vec3(0.62, 0.66, 0.82);   // sombra fría pastel

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT) * contraste, 0.0, 1.0);
	ndl = smoothstep(0.0, 1.0, ndl);
	DIFFUSE_LIGHT += mix(ALBEDO * sombra_tinte, ALBEDO, ndl) * LIGHT_COLOR * ATTENUATION;
	// El especular del agua se conserva con Blinn-Phong simple (el PBR se pierde al definir light()).
	vec3 h = normalize(VIEW + LIGHT);
	SPECULAR_LIGHT += pow(clamp(dot(NORMAL, h), 0.0, 1.0), mix(8.0, 64.0, 1.0 - ROUGHNESS)) * SPECULAR * LIGHT_COLOR * ATTENUATION;
}
```

`ATTENUATION` ya incluye la sombra del sol. En el agua, `NORMAL` dentro de `light()` ya lleva el
`NORMAL_MAP`, así que la rampa sigue las ondas.

Tecla de prueba para QA, en `_unhandled_input`:

```gdscript
		KEY_T:
			var c: float = float(_mat_suelo.get_shader_parameter("contraste"))
			c = 1.0 if c >= 4.0 else (2.5 if c < 2.5 else 4.0)
			_mat_suelo.set_shader_parameter("contraste", c)
			_mat_agua.set_shader_parameter("contraste", maxf(c * 0.6, 1.0))
```

Los lados de los bloques (`mat_lado`, `StandardMaterial3D`) se quedan PBR en este paso: en Test2 se ven
poco (inclinación 20°) y convertirlos exige otro shader. Si al comparar capturas chirrían, se les pone el
mismo `light()` en un `CODIGO_LADO` con `t_lado` triplanar sencillo (`pm.xz` o `pm.xy` según `abs(NORMAL)`).

**Medición**: tres capturas (contraste 1 / 2,5 / 4) de la elfa sobre hierba, sobre camino y junto al río,
mismo encuadre. QA elige; Pipeline deja el valor por defecto y anota la decisión en `docs/ARTE.md` §
sombras. Decisión asociada: si cambia el look del suelo, los bloques del prerender 2D se rehacen.

---

## Paso 4 — Presupuesto en GPU integrada (D7)

Sin código nuevo salvo dos líneas; es disciplina.

1. **QA mide píxeles** con una captura a 1080p al zoom por defecto: alto de una celda, de la elfa, de un
   árbol, de un arbusto, de una moneda. Se añade una columna "px en pantalla" a `docs/ASSETS_FALTANTES.md`.
2. **Regla**: textura ≤ 2 × px en pantalla, redondeado a potencia de 2. Dónde aplicarla:
   - En el editor de Godot: seleccionar las texturas de `poc_25d/meshy/piezas/` y `equipo/` que superen el
     límite → pestaña *Importar* → *Process → Size Limit* = 512 (o 256 para props pequeños) → *Reimportar*.
     Son archivos `.import` (los genera Godot: se tocan desde el editor, no a mano).
   - O en `INTEGRAR_PIEZAS` (Pipeline): al copiar un GLB, si su textura embebida supera el límite del
     asset, `Image.resize(limite, limite, Image.INTERPOLATE_LANCZOS)` antes de guardar.
3. **Sombras**: el decorado va por lotes (`decorado_por_lotes = true` → `_construir_lotes()` crea un
   `MultiMeshInstance3D` por id). Ahí, para los ids pequeños (`oro`, `matas`, `arbusto`, `arbusto_flores`,
   `seta`, `piedra`, `tocon`, `cartel`, `pasadero`): `mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF`
   (una constante `SIN_SOMBRA: Array` junto a `EMPUJABLES`). Solo árboles, bloques, puestos y personajes
   proyectan. Con `H` se mide cuánto cuestan las sombras que quedan.
4. **Compresión**: confirmar `compress/mode=2` (VRAM compressed) en todas las texturas de `poc_25d/` menos
   los sprites de `vfx/` (que son pequeños y con alfa); `detect_3d` desactivado en `pipeline_output/`.

**Medición**: VRAM del HUD y memoria del proceso en el administrador de tareas antes/después (hoy 2 779 MB).

---

## Paso 5 — Empujables con tapa/lado y grietas (D6) — cuando Pablo entregue las texturas

Archivo: `poc_25d/prueba_test2.gd`, `_colocar_empujables()` (línea ~669). Texturas:
`suelo_meshy/tierra_lado.png`, `hielo_arriba.png`, `hielo_lado.png`, `grietas.png` (ver §3 del doc de técnicas).

Shader `CODIGO_BLOQUE` (tapa/lado por normal en mundo, grietas por `danio`):

```glsl
shader_type spatial;
uniform sampler2D t_arriba : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_lado : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_grietas : filter_linear_mipmap, repeat_enable;   // R leves · G medias · B rotura
uniform float danio = 0.0;            // 0 intacto … 1 a punto de romperse
uniform vec3 color_grieta : source_color = vec3(0.25, 0.18, 0.12);
uniform float tam_tex = 2.3;
void fragment() {
	vec3 pm = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 nm = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	bool arriba = abs(nm.y) > 0.5;
	vec2 uv = arriba ? pm.xz / tam_tex : (abs(nm.x) > 0.5 ? pm.zy : pm.xy) / tam_tex;
	vec3 col = arriba ? texture(t_arriba, uv).rgb : texture(t_lado, uv).rgb;
	vec3 g = texture(t_grietas, uv).rgb;
	float grieta = max(max(g.r * step(0.2, danio), g.g * step(0.5, danio)), g.b * step(0.8, danio));
	ALBEDO = mix(col, color_grieta, grieta);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
```

Para hielo: `color_grieta = vec3(0.9, 0.97, 1.0)` (grietas claras). El `danio` lo sube el juego (tierra
sobre tierra lo rompe en 3 golpes; fuego sobre hielo lo derrite en 2). En la maqueta, una tecla que suba
`danio` del empujable más cercano en 0,34 sirve para validar las tres etapas en `CatalogoAssets`.

---

## Paso 6 — Juego 2D (Juego/QA)

Mismo modelo de estado por celda en `nivel_base.gd` (`Dictionary` celda → `{quemado, mojado, helado}`) y
`modulate` por tile hasta que exista el bloque `grass_burnt`. QA lo redacta como diff en
`docs/CAMBIOS_JUEGO_PENDIENTES.md` cuando Pablo confirme en qué copia del repo se aplica (sigue pendiente
el mismo aviso para los tres diffs que ya hay ahí).

---

## Checklist para cerrar cada paso

- [ ] Compila sin avisos en la consola de Godot (el POC avisa con `(!)` en el HUD si falta algo).
- [ ] Tabla de medición rellena y copiada a `docs/PLAN_ACCION_TEST2.md`.
- [ ] Captura de antes/después en `poc_25d/capturas/paso_N_*.png` (carpeta nueva; es del POC).
- [ ] Entrada en `docs/DIARIO.md` con lo que cambió de contrato (nuevas funciones de `Hierba3D`, teclas, `CODIGO_AGUA`).
