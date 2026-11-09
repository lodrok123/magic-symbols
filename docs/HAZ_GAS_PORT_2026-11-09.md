# Haz de gas: port fiel a Godot 4.7 de la demo de gas 3D de three.js (9/11/2026)

Origen: https://github.com/lejrimostfa/force-field-vfx-threejs (MIT, Copyright (c) 2026 lejrimostfa). El aviso completo está en
`laboratorios/haz_gas/LICENSE_force_field_vfx.txt` y cada archivo portado lo cita en su cabecera. Es una **prueba aislada del lab**: no toca `fuego_toy.gd`
ni nada del juego. La versión CPU de bocanadas (F12, `laboratorios/haz_masa/`, `docs/HAZ_FUEGO_VS_DEMO_2026-11-09.md`) se queda para comparar.

## Cómo abrirlo

- `laboratorios/LabVfxComparativa3D.tscn` (F6) y **Mayús+F12**: esfera escudo → muro → nada (sale). Al entrar se esconden el suelo, los cubos, el sol y el panel del lab,
  y el entorno pasa a negro con ACES y glow, como la demo. Al salir vuelve todo.
- Dentro: **ESPACIO** chorro sí/no · **C** cámara (la de la demo → órbita automática de la demo → la cámara del juego) · **O** esfera/muro · **1 2 3 4** calidad low/med/high/ultra ·
  **K** paleta (pablo/demo) · **T** filtro temporal · **P** pausa · **H** HUD · ratón: arrastrar orbita, rueda acerca. A la derecha están los **8 mandos de la demo** (Viento, Empuje tras el choque,
  Turbulencia, Remolinos, Desgarro fino, Viscosidad, Espesor del humo, Humo del fuego). Arriba: calidad, celdas, fps y ms de GPU por etapa.
- Prueba: `godot --path . --resolution 1280x720 --script res://herramientas/prueba_gas_haz.gd` (con ventana; sin ventana solo hace lo de CPU y lo dice con AVISO). `-- ms` solo mide tiempos.
- Capturas: `godot --path . --resolution 1280x720 --script res://herramientas/captura_gas_haz.gd -- [carpeta] [esfera,muro] [demo,cerca,contra,juego] [1,3,6] [low] [pablo|demo]`.
- Recursos horneados (solo si se cambian los generadores): `godot --headless --path . --script res://herramientas/hornear_haz_gas.gd`.

## Archivo por archivo

| Demo (three.js / TSL / WebGPU) | Godot 4.7 | Notas |
|---|---|---|
| `src/config.js` (WORLD, QUALITY, DT, TUNABLES) | `haz_gas_solver.gd` (WORLD_MIN/SIZE, CALIDADES, DT), `haz_gas.gd` (MANDOS) | Iguales. low 128×64×64 / Jacobi 16 / 48 pasos / media resolución, etc. |
| `src/gas/params.js` | `haz_gas.gd` `params` + `parametros_gpu()` → UBO `Parametros` de `shaders/gas_comun.glslinc` | Mismos valores. Un bloque std140 de 16 vec4 que se sube en cada paso (los mandos no recompilan nada). |
| `src/gas/grid.js` | `gas_comun.glslinc` (uvw, mundo, cerca, FLUJO) + push constant `Rejilla` (res, h) | Grupos de 4×4×4, como la demo. |
| `src/gas/fields.js` | `HazGasSolver.crear()` | Texture3D del RenderingDevice PRINCIPAL: gas rgba16f entero; vel, curl, clave rgba16f a la mitad; prs rgba32f a la mitad; luz 1/4 y luz lejana 1/8. Ruido de valor 32³ con la misma LCG (seed 12345). |
| `src/gas/flow.js` | `herramientas/hornear_haz_gas.gd` → `flujo_48.bin` | Mismas 64 ondas a·cos(2πk·x+fase) con a ⟂ k, espectro k^(-5/6), seed 777: se hornea una vez en CPU y se sube a una textura 3D RGBA8 que se repite. |
| `src/gas/advect.js` | `advecta.glslinc`, `gas_avanza.glsl`, `gas_corrige.glsl`, `vel_advecta.glsl` | MacCormack para el gas (recortado a las 8 celdas leídas) y semi-Lagrangiana RK2 para la velocidad, a propósito (como explica la demo: MacCormack en la velocidad hace ladrillos; la velocidad suave da los pliegues gordos). Remolino por debajo de la rejilla (subgrid) igual. |
| `src/gas/sources.js` | `gas_fuentes.glsl`, `vel_fuentes.glsl` | Todo: chorro con bamboleo y radio que respira, combustible solo en el 55-90 % final, alimentación en la piel (flare con ráfagas), combustión, enfriamiento más rápido lo lento respecto al viento → hollín, polvo a ras de suelo, esponja; chorro, flotación, peso, arrastre al viento, empuje de un sentido, piel + wrap, expansión, tope CFL. |
| `src/gas/forces.js` | `rizo.glsl`, `confina.glsl` | Rizo, confinamiento de vorticidad, turbulencia sin divergencia a dos escalas y viscosidad explícita que depende de T. |
| `src/gas/project.js` | `divergencia.glsl`, `jacobi.glsl`, `proyecta.glsl` | Mismas reglas de caras (sólido refleja la presión, suelo cerrado, caras abiertas p = 0), arranque en caliente 0,96. |
| `src/gas/solver.js` | `HazGasSolver._montar_cadena()` / `paso()` | La misma cadena fija; empieza y acaba en el índice 0 de cada pareja (ningún uniform set se rehace). Cada pasada es su propia compute list: el grafo de RenderingDevice pone las barreras. |
| `src/gas/light.js` | `luz_clave.glsl`, `luz_difunde.glsl`, `luz_lejos.glsl` | Transmitancia a la lámpara azul (14 pasos), 6×2 pasadas de difusión cercana (tinte naranja puro 1, 0,3, 0,045) y 6×2 de la lejana. |
| `src/render/optics.js` | `gas_comun.glslinc` (densidad_humo, extincion, luz_suave, color_fuego, sostener_tono) | Igual, más la paleta «pablo» (ver diferencias). |
| `src/render/volume.js` | `haz_gas_raymarch.gd` (CompositorEffect POST_TRANSPARENT) + `raymarch.glsl`, `temporal.glsl` | Raymarch a media resolución en compute, IGN con desfase por fotograma, cuerpo con borde, llamas opacas, relieve por gradiente, luz cercana topada, lámpara que se apaga donde manda el fuego, albedo 0,3, holdHue. Filtro temporal con la historia recortada al 3×3 y mezcla 0,55, y su copia. |
| `src/main.js` (post) | `compone.glsl` + entorno de `HazGas.entorno()` | escena·a + rgb, saturación 1,3, viñeta; bloom = glow de Godot (umbral 1,1, intensidad 0,32, aditivo); ACES igualado al ACESFilmic de three (exposición 0,85/0,6/1,8 y blanco 16). |
| `src/main.js` (bucle, cámara) | `HazGas._process`, `_mover_camara`, `_unhandled_input` | Un paso por cada 1/60 s; el objetivo del chorro se mueve igual (y = 2 + 0,5 sen 0,7t, z = 0,7 sen 0,43t); la cámara inicial (fov 32, (2,5, 6, 23) → (1,4, 2,4, 0)), la vuelta automática y un orbitar con ratón como OrbitControls (7-45 m, ángulo polar ≤ 0,49π). |
| `src/render/sparks.js` | `chispas.glsl` + `haz_gas_chispas.gdshader` (MultiMesh de 1000 quads) | 1000 chispas, primeras vidas escalonadas en 2,3 s, montan la velocidad del gas con inercia (1,6), gravedad -7, rebote en suelo (0,35), acantilado y escudo; quads estirados por su movimiento en pantalla (cola = p − v·0,028 s), aditivos. El hash PCG de TSL portado tal cual. Estado en una imagen rgba32f N×2 que el material lee (Texture2DRD). |
| `src/render/stage.js` | `haz_gas_roca.gdshader` | Suelo, acantilado y (nuevo) el muro: sin luces de Godot; la luz sale de los campos (color, dirección por el gradiente de la luz lejana, especular), lámpara azul con la sombra del humo. |
| `src/render/rock.js` | `herramientas/hornear_haz_gas.gd` → `roca_1024.png` | Las mismas 6 octavas con la misma LCG, crestas en la 2ª, deformación con senos; normal + altura. Importada sin compresión y con mipmaps. |
| `src/render/figures.js` | `HazGas._figura()` + `haz_gas_figura.gdshader` | El defensor de cápsulas igual; el atacante es la JUGADORA (Pj3D a 1,8 m, empuje a dos manos, con el material de silueta: casi negro con borde de fuego). |
| `src/hud.js`, `index.html` | `HazGas._montar_hud()` | Línea de estado, ayuda, y los 8 HSlider (0..máx, paso máx/200). En castellano. |

## Lo que difiere y por qué (nada omitido en silencio)

1. **Obstáculo con SDF**. El escudo de la demo es una esfera analítica; aquí `obst_sd()` vale para la esfera (da exactamente lo mismo), una caja orientada (el muro del lab: piel, wrap,
   sólido de la presión, colisión de chispas) o nada. El contacto del flare con la caja es el punto de su piel más cercano a la boquilla, a 0,35 m (con la esfera es la fórmula de la demo).
2. **Profundidad de la escena**: el raymarch también para en la profundidad de Godot (muro, jugadora). La demo no lo necesita (su único sólido es invisible). Se usa la proyección de
   `Camera3D.get_camera_projection()` (OpenGL) y la Z invertida de Vulkan (z_gl = 1 − 2d); la de `RenderSceneDataRD` ya trae la corrección de Vulkan y daba rayos equivocados con la
   cámara ortográfica del juego.
3. **Bloom**: el glow del WorldEnvironment en vez del BloomNode de three (mismo umbral 1,1; el reparto por niveles no es idéntico). La **viñeta** va antes del bloom (en la demo, después).
4. **Paleta**. Pablo: rojos y naranjas con contraste, NUNCA amarillo ni blanco quemado. Con la paleta exacta de la demo el núcleo del chorro sale (246, 191, 64) en pantalla (amarillo).
   Por defecto va la paleta **«pablo»**: el tramo «yellow» de fireColor pasa a (1, 0,27, 0,02) y el «white» a (1, 0,34, 0,05), y holdHue comprime más (0,5 en vez de 0,22); núcleo
   (239, 135, 27). Las chispas: (1, 0,3, 0,05)·(calor²·6 + 0,6). **K** vuelve a la de la demo tal cual (y la HOJA_RESUMEN tiene las dos).
5. **Chispas bajo el suelo**: la esfera de la demo (centro a 2 m, radio 2,1) entra 0,1 m en el suelo; en la demo algunas chispas pasan un fotograma bajo el suelo (tapadas por él). Aquí nacen
   encima y, si tras el rebote siguen dentro del escudo, se sacan en horizontal. Así la prueba puede exigir que ninguna atraviese suelo ni escudo.
6. **normalize(viento)** con el viento a 0 da NaN en la demo; aquí la dirección no depende del módulo (con viento > 0 es idéntico).
7. **Vista de juego**: el dominio entero se escala a 0,35 (8,4 × 4,2 × 4,2 m), con la boquilla en la mano de la jugadora y el suelo en su suelo; el acantilado y la silueta atacante se
   esconden y las chispas dejan de rebotar en él. La dinámica sigue en metros de la demo, así que a esa escala todo va 0,35 veces más «lento» en metros del lab por segundo.
8. **Compilación de shaders**: los `.glsl` se compilan en tiempo de ejecución desde el texto, con los `#include` expandidos (el importador de Godot no recompila un `.glsl` cuando solo
   cambia un `.glslinc`). El importado queda de reserva.
9. **No portado**: `events.js` / `input.js` (bus y gestos táctiles: aquí son señales y `_input`), el enlace `?q=` (aquí, teclas 1-4), la captura `__gasfx` (aquí, la prueba y el script de capturas).

## ms de GPU (RTX 3070, 1280×720, contra la esfera)

Marcas de tiempo del RenderingDevice (`capture_timestamp`), media y mediana de 240 fotogramas; cinco pasadas en momentos distintos. Varían bastante (relojes de la GPU y grafo del
RenderingDevice), así que va el rango de la **mediana del total** (simulación + luz + chispas + volumen):

| Calidad | Celdas de gas | Total (mediana) | Típico por etapa |
|---|---|---|---|
| low 128×64×64, Jacobi 16, 48 pasos | 0,52 M | **0,5-1,6 ms** | gas 0,15 · velocidad 0,12 · luz 0,07 · volumen 0,2-0,5 |
| med 192×96×96, Jacobi 24, 64 pasos | 1,77 M | **1,9-3,4 ms** | gas 0,35 · velocidad 0,6-1,1 · luz 0,11 · volumen 0,2-0,6 |
| high 256×128×128, Jacobi 32, 96 pasos | 4,19 M | **4,4-14 ms** (típico ~8) | gas 1,0 · velocidad 2,3-2,7 · luz 0,3 · volumen 0,55 |

60 fps en low y med siempre; en high, una de las cinco pasadas bajó a 45. La demo dice ~9-10 ms en low en su máquina (WebGPU en navegador, todo incluido).

## Pruebas (`herramientas/prueba_gas_haz.gd`, 0 fallos con ventana)

CPU: flujo horneado centrado; contacto y SDF de la esfera = los de la demo; contacto del muro a 0,35 m de su cara; rejillas divisibles por 8.
GPU, esfera y muro, 5 s en low: sin NaN ni infinitos (gas y velocidad); T ≤ 4; nada de gas dentro del obstáculo; las 1000 chispas, 2 s mirando cada fotograma, ni bajo el suelo ni dentro del
obstáculo; hollín junto al obstáculo ~0,16-0,18 de media y ~0,04 en el núcleo del chorro; polvo solo a ras de suelo; con el chorro apagado la T total cae a < 1 % en 2,5 s.
**Proyección**, honesto: Jacobi resuelve su ecuación (residuo de Poisson ~1 % de la divergencia), pero la divergencia que queda tras proyectar es ~70 % celda a celda y ~50 % en bloques de 4³.
Es el esquema de la demo (rejilla colocada: divergencia y gradiente centrados a 2h y laplaciano compacto en Jacobi), que no ve el modo en damero; con 200 iteraciones de Jacobi el
cociente no cambia, y casi toda esa divergencia está en el chorro (34 m/s forzados en 1-4 celdas cada paso). Umbrales: < 0,85 por celda, < 0,65 en bloques, < 0,1 de residuo de Poisson.

## Capturas

`docs/capturas/vfx_en_juego/haz_gas/`: `<esfera|muro>_<demo|cerca|contra|juego>_<1s|3s|6s|apagado>.png` (paleta pablo), `esfera_paletademo_*` (paleta de la demo) y `HOJA_RESUMEN.jpg`
(arriba demo_ref 4, 5 y 6; debajo lo nuestro con los mismos encuadres, la paleta de la demo, el muro, los instantes y la cámara del juego). Se parece de verdad en: chorro recto y limpio,
masa que se amontona contra el escudo y lo envuelve pasado su ecuador, pliegues oscuros de hollín donde se frena, chispas en estela que rebotan en el suelo, suelo y acantilado iluminados por el
fuego y la lámpara azul con humo azulado al otro lado. Suelo medido: (100, 28, 0) frente a (109, 33, 0) en demo_6.

## Qué haría falta para meterlo en el juego

- **Coste**: low cuesta 0,5-1,6 ms de GPU en una 3070 por instancia (0,5 M celdas + raymarch a media resolución). Para el juego (2.5D, varios hechizos, gama media) haría falta una rejilla más
  pequeña y ajustada al haz (p. ej. 64×32×32 sobre 4×2×2 m: ~1/8 de celdas), Jacobi 8-12, raymarch a 1/3 de resolución con 32 pasos, y quizá un paso de simulación cada dos fotogramas.
- **Dominio móvil siguiendo al haz**: el dominio ya es un nodo con transformación (la vista de juego lo usa). Para que siga a la jugadora mientras se mueve hay que desplazar el contenido
  (advección por el movimiento del dominio, o recentrar por celdas enteras y vaciar la franja que entra) en vez de mover solo la caja; y orientarla con el haz.
- **Varias instancias**: un HazGasSolver por haz vivo (las texturas son de cada uno) y un solo CompositorEffect que haga raymarch de todas las cajas en una pasada (o una por caja con
  mezcla), con tope (2-3) y reciclado; o un único dominio compartido si los haces están cerca.
- **Estilo**: el juego es de bordes recortados; este volumen es suave. Si se integra habría que decidir con Pablo si se quiere el volumen tal cual o un umbral/banda sobre él.
- **Plataformas**: necesita Forward+ o Mobile con RenderingDevice (no Compatibility) y compute; sin ventana no hay nada (las pruebas de GPU van con ventana).
