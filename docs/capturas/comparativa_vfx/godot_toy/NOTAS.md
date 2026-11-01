# Prueba 3 de VFX en Godot: cinco efectos de fuego «toy» (1/11/2026)

Rama `claude/prueba3-godot-toy` (worktree `E:\tmp\wt_prueba3_godot`), sin push. Diseño: `docs/PRUEBA3_VFX_TOY_2026-11-01.md`. Referencia: `docs/capturas/comparativa_vfx/referencia_toy/` (`eow_hierba.jpg` es el juez de la llama, `la_pilar.jpg` el pilar, `la_antorchas.jpg` la bola).

## Nota propia frente a la referencia (1–5) y lo que falta

| Efecto | Nota | Rondas | Lo que falta |
|---|---|---|---|
| Bola estática (`bola_cerca`, `bola_juego`) | **3,5** | 3 | Es una bola gorda y redonda con un borde claro y una puntita, bien parecida a las antorchas de `la_antorchas.jpg`, pero la punta no ondula tanto como una llama de `eow_hierba.jpg` (se ve un poco «farolillo»); dentro se adivinan los círculos concéntricos de las tres capas. |
| Muro (`muro_cerca`, `muro_juego`) | **3,5** | 3 | Lenguas gordas, blandas y con las puntas torcidas, translúcidas, con filo crema y base clara; se parece a las llamas de la hierba. Falta: son 17 lenguas de la misma familia (se nota la repetición en la fila de delante), el color tira a amarillo claro donde la referencia es más naranja ámbar, y no hay el brillo de la hierba quemada debajo. |
| Pilar (`pilar_cerca`, `pilar_juego`) | **3,5** | 2 | Columna de bultos gordos que suben (lo que pide `la_pilar.jpg`), con núcleo claro, anillo en el suelo y chispas. Falta: el borde es más liso que el de la referencia (que tiene los lóbulos separados, como nubes de fuego) y la parte alta se afina demasiado pronto. |
| Bola en movimiento + impacto (`bola_vuelo`, `bola_impacto`) | **3** | 2 | La estela corta se ve poco (es una nube difusa, no una cola con forma de lengua) y el impacto es un estallido de siete pétalos con un anillo en el suelo, correcto pero sin la silueta clara de la referencia; el resplandor de la luz sobre el suelo del lab lava el color en la cámara cerca. **No pasa de 3 en dos rondas: apuntado, no se tocó más.** |
| Barrera (`barrera_cerca`, `barrera_juego`) | **3** | 2 | Cáscara translúcida con borde luminoso y ocho lenguas que suben girando, se ve a la jugadora dentro. Falta: las lenguas son «hojas» de bordes afilados, no las puntas redondas y gordas de la bola o el muro; el fresnel de la cáscara es un velo amarillo claro que se parece más a una burbuja que a un fuego. **No pasa de 3 en dos rondas: apuntado.** |

Media de las cinco: **3,3**. Es la nota de quien lo ha hecho; la que vale es la de Pablo.

## Qué hay

| Cosa | Dónde |
|---|---|
| Escenas con `EfectoVfx3D` (`preparar` / `lanzar` / `morir` / `impactar`) | `presentacion/vfx/toy/`: `BolaFuegoToy.tscn` (estática; con `proyectil` activo suelta estela; al `impactar` instancia `ImpactoBolaToy.tscn`), `MuroFuegoToy.tscn`, `PilarFuegoToy.tscn`, `BarreraFuegoToy.tscn` |
| Shader de la llama (plano con billboard en Y o completo; dos ruidos que suben, gradiente vertical, `smoothstep` ancho, rampa continua) | `llama_toy.gdshader` |
| Resplandor aditivo (halo, charco en el suelo, anillo) | `halo_toy.gdshader` |
| Cáscara de la barrera (esfera, dos pasadas: cara de atrás y de delante) | `barrera_toy.gdshader`, `barrera_toy_trasera.gdshader`, `barrera_toy.gdshaderinc` |
| Script del raíz con los diez mandos | `efecto_toy.gd` (`class_name EfectoToy extends EfectoVfx3D`) |
| Montaje de un solo uso (después se edita en el editor) | `herramientas/vfx/montar_efectos_toy.gd` |
| Lab: F1 bola estática · F2 muro · F3 pilar · F4 bola en vuelo con impacto · F5 barrera · F6 diez muros; RePág/AvPág eligen mando, + / − lo mueven, Retroceso lo repone; el panel enseña los diez con su valor | `laboratorios/lab_vfx_comparativa_3d.gd` |
| Captura con ventana, GIF y fps | `herramientas/captura_vfx_toy.gd`, `herramientas/gif_desde_secuencia.py` |
| Prueba sin ventana | `herramientas/prueba_vfx_toy.gd` (0 fallos) |
| Capturas (los 11 PNG del diseño) y GIF de 3 s (`bola`, `bola_vuelo`, `muro`, `pilar`, `barrera`) | esta carpeta |

## Los diez mandos (raíz de cada escena, inspector, grupo «Los diez mandos», con rango)

`altura` (0,3–3) · `chisporroteo` (0–1, ronda 2; sustituye a `ancho`, que sigue como ajuste suelto en «Otros») · `blandura` (0,05–1) · `ondulacion` (0–1,5) · `velocidad` (0,1–4) · `brillo` (0,3–3) · `halo` (0–3) · `tono` (0 fuego, 1 azul) · `chispas` (0–1, proporción) · `luz` (0–4, energía de la luz).
Cada instancia duplica sus materiales al nacer, así que mover un mando en una no cambia las demás. Fuera de los diez: `vida` (segundos que dura al lanzar), `proyectil` (bola), `titileo`, `aparicion` (la anima el AnimationPlayer).

## Método

Todo procedimental, sin texturas de llama ni flipbook. Cada lengua es un plano (`QuadMesh`) con `llama_toy.gdshader`: en metros dentro del plano, la silueta es una gota (semiancho que baja desde el radio hasta cero en la punta con una potencia `afilado`, base redondeada, o un círculo si es bola) más dos ruidos de senos que suben a distinta velocidad (el segundo se resta al primero) que muerden el borde y mecen la punta; el borde se pasa por `smoothstep` ancho (`blandura`), nunca `discard`. Color por rampa continua (naranja → amarillo → blanco crema) según lo hondo que esté el píxel dentro de la lengua, un filo más claro y translúcido en el borde y el corazón más claro en la base. El tiempo no se cuantiza. Capas: exterior grande y tenue, cuerpo, núcleo claro y un halo aditivo (otro plano con caída suave) además de la luz (una `OmniLight3D` con titileo suave en `efecto_toy.gd`) y de 8 a 16 chispas pequeñas aditivas. No hay humo. Muro: 9 lenguas atrás (más altas y tenues) y 8 delante (más bajas y brillantes) más un charco de luz alargado en el suelo. Pilar: tres capas altas con un mando interno `bultos` (anchura que sube y baja en ondas: las bolas apiladas). Barrera: shader en coordenadas del objeto, `lenguas` con torsión y giro, franja de base continua y fresnel para el borde de la cáscara.

Dos cosas que dieron guerra y quedan apuntadas:

- El ruido de valor con `hash` (el de siempre) dejaba **parches rectangulares** en la llama (cada celda del ruido se veía como un bloque con borde duro); se cambió por un ruido liso de senos con dominio deformado y los parches desaparecieron. Tiempo perdido: ≈ 8 min.
- `smoothstep` con los bordes al revés (`smoothstep(1.0, 0.9, x)`) es indefinido en GLSL y dejaba cortes en el borde del plano. Se escribió como `1 - smoothstep(0.9, 1.0, x)`.

## Horas por paso (reloj del PC; salida de la sesión)

| Paso | Marcas | Tiempo |
|---|---|---|
| Leer el diseño, las referencias, la prueba 2 y el lab; traer la infraestructura de la prueba 2 (merge de `claude/prueba2-godot-toon`, solo chocó el diario) | antes de 16:58 | ≈ 10 min |
| Shaders (llama, halo), `EfectoToy`, script de montaje, teclas F1–F6 y diez mandos del lab, script de captura | 16:58 – 17:02 | ≈ 4 min |
| Bola: cuatro rondas de captura (azulada y blanca demasiado, corte de plano, luz que lava) | 17:02 – 17:07 | ≈ 5 min |
| Muro, pilar y barrera: shaders, primera captura, ronda 2 (anillo, cámara por efecto, bultos) | 17:07 – 17:12 | ≈ 5 min |
| Parches rectangulares: diagnóstico (aislar capas, quitar ondulación, cambiar hash) y ruido nuevo | 17:12 – 17:14 | ≈ 8 min (con las rondas de muro) |
| Impacto con pétalos y barrera más naranja (ronda 2 de ambos) | 17:17 – 17:19 | ≈ 3 min |
| Capturas finales, `diez_muros` sin vsync (primero salió 59 fps: era el vsync), 5 secuencias con Movie Maker y GIF | 17:19 – 17:20 | ≈ 3 min |
| `prueba_vfx_toy.gd`, NOTAS, diario | 17:20 – | ver el diario |

Total de reloj de agente ≈ **40 min** de las 16 h de presupuesto. Hora de Pablo con los mandos: pendiente.

## Resultados medidos

- **`diez_muros`** (diez `MuroFuegoToy`, 1920 × 1080, RTX 3070, vsync apagado, media de 60 fotogramas): **717 fps** (`diez_muros_fps.txt`; con vsync da 59 y no dice nada). 10 luces y 140 partículas en total; por efecto, 1 luz y 14 partículas.
- **Presupuesto por efecto** (`prueba_vfx_toy.gd`): bola 1 luz y 26 partículas (8 chispas + 18 de la estela, que solo emite en modo proyectil), muro 1 y 14, pilar 1 y 16, barrera 1 y 14, impacto 1 y 14; todos ≤ 1 luz y ≤ 300 partículas.
- **Prueba sin ventana: 0 fallos** (escenas cargan, contrato, presupuesto, los diez mandos con rango y el mismo en el lab, que los mandos llegan solo a su instancia, `preparar` y `lanzar(vida)`, estilo por el código de los shaders —sin cuantizar, sin contorno, sin umbral duro, rampa continua, ningún rojo oscuro, azul solo por el mando `tono`—, capturas y GIF existen).
- **Las cinco modificaciones de Pablo con un mando o un parámetro** (comprobado con la prueba): (1) fuego azul = `tono` 1; (2) llama el doble de alta = `altura` 2; (3) mitad de chispas = `chispas` 0,5; (4) barrera el doble de grande = escala 2 del raíz (o `preparar` con el volumen doble); (5) pilar que dura 1 s y se apaga = `lanzar(1.0)` (se libera a los 0,87 s). Cronometrado con Pablo: pendiente.

## Lo que no está

- Humo claro escaso: no se puso (el diseño dice «como mucho»).
- La estela de la bola es una nube difusa, no una cola de lengua; la barrera se queda en 3; el impacto, en 3.
- Que los shaders **compilen** se ve porque salen en las capturas (ventana real, Vulkan); la prueba sin ventana solo comprueba que cargan.
- El lab usa el bloom (`glow`) del entorno; no se ha probado el efecto en el entorno del juego, que puede no tenerlo (los halos aditivos están para que no dependa de él, pero el aspecto cambiaría).
- Sin comparar a ojo con la referencia lado a lado en una pantalla de Pablo; los GIF son 640 px de ancho, 24 fps, 192 colores.

## Ronda 2 (1/11): menos amarillo, más contraste y chisporroteo en las puntas

Pablo: «la mejor prueba de hoy», pero demasiado amarillo, faltan rojos y anaranjados y contraste, y las puntas son lisas y lentas.

**Color.** Rampa nueva en `llama_toy.gdshader` y en la barrera: borde rojo-anaranjado (0,85 / 0,12 / 0,03) que se funde en transparencia, cuerpo naranja saturado (1 / 0,30 / 0,03), amarillo (1 / 0,62 / 0,12) y blanco crema solo en un núcleo pequeño; `calor` pasa por `pow(calor, 1,8)` para que el salto núcleo-cuerpo se note; el filo ya no es crema sino naranja intenso (como el borde de las lenguas de `eow_hierba.jpg`). Halos aditivos en rojo-naranja y a 0,6 de lo que eran; luz, chispas y trocitos en naranja. No hizo falta un mando `calidez`: se quedan los diez.

**Medida** (`herramientas/medir_tonos_fuego.py`: píxeles con saturación > 0,4 y valor > 0,35, sin el panel; rojo-naranja = tono < 20°, naranja 20–40°, amarillo > 40°; las capturas de antes están en `antes_ronda2/`):

| Captura | Antes: rojo-naranja / naranja / amarillo | Después |
|---|---|---|
| `muro_cerca` | 0 / 38 / 62 % | **41 / 59 / 0 %** |
| `pilar_cerca` | 0 / 24 / 76 % | **20 / 79 / 1 %** |
| `bola_cerca` | 0 / 17 / 83 % | 31 / 69 / 0 % |
| `barrera_cerca` | 0 / 8 / 92 % | 7 / 89 / 4 % |

Objetivo 15–30 % rojo-naranja, 50–65 % naranja, ≤ 20 % amarillo: el muro tiene demasiado rojo (41 %), el pilar y la barrera demasiado naranja y poco rojo (la barrera, 7 %); el amarillo ya no pasa del 4 %. Límite de la medida: el borde translúcido sobre el suelo gris del lab se mezcla y cuenta como naranja o desaparece; el núcleo amarillo-blanco es tan pequeño (< 2 %) que apenas cuenta.

**Chisporroteo.** Mando `chisporroteo` (0–1, por defecto 0,6) que escala tres cosas: (1) en el shader, dos ruidos finos y rápidos (2,5 y 3,2 veces la velocidad del grande) que solo actúan en el tercio de arriba de cada lengua: muerden el borde y cortan pedacitos que se apagan a saltos; el cuerpo sigue blando; (2) trocitos de llama que se desprenden de la punta (partículas con rampa amarillo → naranja → rojo, vida 0,5 s, 2 a 6 por segundo según el efecto: bola 4, muro 6, pilar 6, barrera 6); (3) titileo irregular de 9 y 14 Hz del brillo (± 14 %) y de la luz (± 12 %). Con `chisporroteo` 0 vuelve a lo liso de la ronda 1. Presupuesto: 1 luz y ≤ 32 partículas por efecto.

**Resultados.** Capturas y los cinco GIF de 3 s rehechos (en los GIF se ven las puntas romperse y los trocitos subir); diez muros a 1920 × 1080: 786 fps sin vsync; prueba sin ventana a 0 fallos (la comprobación de paleta ahora pide los cuatro colores de la rampa y rojo ≥ 0,85). Notas propias tras la ronda: bola 3,5, muro 4, pilar 4, bola en movimiento 3, barrera 3,5 (la barrera gana mucho con el color; la estela de la bola sigue siendo una nube). Reloj de la ronda: 17:25 – 17:38, ≈ 13 min (de ellos ≈ 3 perdidos por un parche que dejó dos `@export` con el mismo nombre y escenas generadas sin script).

## Ronda 3 (1/11): fuego por texturas, método del tutorial de Le Lu

Pablo pidió rehacer los cinco con el método del tutorial «GODOT - Tutorial Fuego (shader) VFX» de Le Lu (rojo-naranja con contraste y puntas rotas que chisporrotean). Las escenas de la ronda 2 están guardadas como `BolaFuegoToy_r2.tscn`, `MuroFuegoToy_r2.tscn`, `PilarFuegoToy_r2.tscn`, `BarreraFuegoToy_r2.tscn` (el impacto de la bola es el de la ronda 2 en las dos) y las capturas y GIF de la ronda 2 en `ronda2/`.

**Contenido ajeno:** el pack gratuito de texturas de Le Lu en `assets/vfx/lelu_noise/` (49 texturas y `readme.txt`; su autor permite usarlas en juegos comerciales sin acreditar; aquí se citan igualmente). Se usan 4: `T_FirePanningCyl45.png` (lenguas), `T_PerlinNoise_Tiled.png` (segundo ruido), `T_CloudNoise_Tiled.png` (desplazamiento de vértices) y `T_Noise1_tiled.png` (ruido fino de las puntas). Todo lo demás (mallas, shaders, rampas, luz, chispas, escenas) es propio. Porcentaje de contenido ajeno en lo que se ve: la forma de las lenguas viene de una textura ajena (≈ 100 % de la silueta del cuerpo), el color, el movimiento y el resto son propios.

**Método (shader `fuego_lelu.gdshaderinc` + cuatro variantes `fuego_lelu*.gdshader`):** (1) mallas de revolución abiertas hechas por código con `SurfaceTool` (U alrededor, V = 0 abajo y 1 arriba): cilindros con ahusamiento, una gota para la bola y una esfera para la barrera; (2) la textura de lenguas sube (`uv.y + TIME`) y gira un poco en U; (3) segundo ruido con otra velocidad y escala, sumado; (4) se resta `pow(V, 1,3) × 1,1` y se suma un desfase; (5) `ALPHA = smoothstep(umbral, umbral + blandura, f)` con blandura 0,22: lenguas con punta, ni duras ni borrosas; (6) color por una `GradientTexture1D` indexada por `f` (rojo-anaranjado → naranja → amarillo → blanco crema) con `pow` de contraste 1,1, más una rampa azul para `tono`; (7) vértices desplazados con el ruido de nubes que sube, más cuanto más arriba; (8) fundido arriba. Capas: cilindro exterior y otro interior más estrecho, más caliente (rampa desplazada) y más rápido. Chisporroteo: ruido fino y rápido solo en el tercio de arriba que rompe las puntas, más titileo; los trocitos desprendidos y la luz son los de la ronda 2. Los diez mandos son los mismos nombres de uniform, así que `EfectoToy` y el lab no cambian (el mando `chisporroteo` ahora manda sobre el ruido fino del shader).

**Mezcla frente a aditivo** (probado en el pilar con la misma escena): el aditivo (`fuego_lelu_add.gdshader`) lava el fuego hasta amarillo claro y pierde el contraste con el fondo; la mezcla conserva el rojo y el naranja. Se queda la mezcla; el aditivo se deja en la carpeta por si se quiere mezclar.

**Aplicación:** pilar = cilindro de 0,5 × 4 m (r 0,5 → 0,36) + interior de r 0,3; bola = gota (r 0,42) + interior + halo, en modo proyectil el cuerpo se inclina 55° hacia atrás y sale una malla de estela con la misma textura; muro = 7 cilindros de r 0,5 con escala X 1,3 (elipses) solapados a lo largo de 6,9 m, cada uno con otro desfase de UV y velocidad, más 7 interiores (funcionó a la primera, no hizo falta volver a la ronda 2); barrera = esfera de r 1,5 con el mismo shader (UV esférica, `v_base` = 0,3 para que el fuego empiece en el suelo, giro y borde de fresnel), dos pasadas.

**Medida de tonos** (`herramientas/medir_tonos_fuego.py`, mismo método que la ronda 2; objetivo 15–30 % rojo-naranja, 50–65 % naranja, ≤ 20 % amarillo):

| Captura | Ronda 2 (rojo-naranja / naranja / amarillo) | Ronda 3 |
|---|---|---|
| `muro_cerca` | 41 / 59 / 0 % | **16 / 68 / 16 %** |
| `pilar_cerca` | 20 / 79 / 1 % | **26 / 57 / 17 %** |
| `bola_cerca` | 31 / 69 / 0 % | **32 / 62 / 7 %** |
| `barrera_cerca` | 7 / 89 / 4 % | **38 / 48 / 14 %** |

Dentro de la horquilla: pilar. Fuera por poco: muro (naranja 68 en vez de ≤ 65), bola (rojo 32 en vez de ≤ 30) y barrera (rojo 38 y naranja 48). El amarillo no pasa del 17 % en ninguno. Primeras versiones: con la rampa más corta el amarillo subía al 29 % y con la rampa larga el rojo al 65 %; se ajustaron los puntos de la rampa y el `pow` en cuatro vueltas.

**Notas propias (1–5, contra `eow_hierba.jpg` y lo que Pablo pidió):** bola 4, muro 4, pilar 4,5, bola en movimiento 3,5 (la estela inclinada se lee como un cometa; el impacto sigue siendo el de la ronda 2, más blando que el resto), barrera 4. Media 4. Lo que falta: estas llamas son más duras y realistas que las de «juguete» de la ronda 1 (cuerpo con lenguas con punta, no redondo y gordo); el interior de la bola se ve como un cristal poco denso desde arriba; el impacto no se rehízo con el método nuevo.

**Resultados y horas.** Diez muros a 1920 × 1080: **540 fps** sin vsync (cada muro son 14 mallas de 14 × 33 vértices). Prueba sin ventana: 0 fallos (ahora comprueba el shader de texturas, las texturas de Le Lu y las escenas `_r2`; salen mensajes `ERROR` de fugas de recursos al cerrar el modo sin ventana, sin efecto). Presupuesto por efecto: 1 luz y ≤ 26 partículas. Reloj de la ronda: 20:31 – 20:40 ≈ 9 min (shader y generador a la primera, 4 vueltas de rampa para los tonos).

## Ronda 4 (1/11): una sola silueta en la bola y un muro continuo

Pablo: la dirección de la ronda 3 vale; solo pulido. Las capturas y GIF de la ronda 3 de bola y muro están en `ronda3/`.

**Bola.** Se veían dos contornos (la gota de fuera y, dentro, el núcleo o la cara de atrás del cilindro, como una gota de cristal). Cambios: (a) la capa exterior usa `cull_back` (`fuego_lelu_delante.gdshader`): se descarta la cara trasera; (b) el núcleo ya no es una segunda malla con borde propio, sino un halo aditivo pequeño (sin silueta, se funde); (c) el cuerpo es más opaco (`desfase` 0,72) y la malla se cierra abajo (antes quedaba un agujero en el polo). Probado: solo `cull_back` quitaba la cara de atrás pero dejaba el borde del núcleo; con el núcleo en halo y desfase 0,85 el cuerpo salía opaco y amarillo (27 %), sin lenguas; 0,72 deja lenguas visibles y una sola silueta. Comprobado en `bola_cerca` (desde arriba y al lado), `bola_juego` y `bola_vuelo`. Queda un detalle: al cerrar el polo, las lenguas convergen y se ve una estrella de meridianos en la base.

**Muro.** Los siete cilindros con huecos se sustituyen por UNA malla de revolución con sección rectangular redondeada (superelipse de 6,9 × 0,6 m, exponente 6, `_malla_lazo` en `montar_efectos_lelu.gd`), con la U medida por la longitud del contorno (la textura no se estira en los lados largos; 5 repeticiones, un número entero para que la costura cierre) y otra malla interior más estrecha, caliente y rápida. Resultado: una banda continua de fuego con lenguas distintas a lo largo; desde `muro_juego` y `muro_cerca` (2 m) no se adivina ningún círculo. Primer intento con 12 repeticiones: hierba fina, demasiadas lenguas diminutas; con 5 se parecen a las de antes. La opción (a) (más cilindros solapados) no hizo falta.

**Medida de tonos** (rojo-naranja / naranja / amarillo; objetivo 15–30 / 50–65 / ≤ 20): `muro_cerca` 17 / 60 / 23 % (ronda 3: 16 / 68 / 16), `bola_cerca` 22 / 58 / 21 % (ronda 3: 32 / 62 / 7). Amarillo un poco por encima del 20 % en ambos (la bola por el núcleo aditivo; `muro_juego` y `bola_juego`, con muy pocos píxeles de fuego, dan 29 y 25 % de amarillo).

**Resultados.** Diez muros a 1920 × 1080: **638 fps** sin vsync (540 en la ronda 3; la banda tiene menos mallas). Prueba sin ventana a 0 fallos. Capturas y GIF rehechos de bola, `bola_vuelo` y muro (pilar, barrera e impacto no se tocaron). Notas propias: bola 4 (una sola llama; le falta que el cuerpo sea menos liso y que no se vea la estrella de la base), muro 4,5. Reloj de la ronda: 20:45 – 20:55, ≈ 10 min.

## Ronda 5 (1/11): la bola, sin estrella ni facetas

Pablo: en `bola_cerca` se veía una estrella de meridianos en la base (las lenguas convergían al polo) y la superficie parecía una gema low-poly. Solo la bola; capturas y GIF anteriores en `ronda4/`.

**Cambios.** (1) La gota se queda abierta abajo (radio 0,07, ya no 0,01) y su base se funde: nuevo uniform `fade_base` (alfa de 0 a 1 entre V = 0 y 0,2), más un disco aditivo naranja-rojo pequeño debajo (`Base`) que tapa el hueco; (2) 64 segmentos alrededor y 40 anillos de altura (antes 32 y 18) y uniform `vert_polo` = 1, que lleva a 0 el desplazamiento de vértices hacia la punta (el cuerpo tiene la silueta redonda; el desplazamiento ya era 0 en la base); (3) segundo ruido más fuerte en el cuerpo (`peso_ruido` 0,55 con 3 × 1,6 repeticiones) y la rampa más baja (`escala_rampa` 0,75) para que el cuerpo sea naranja y no crema. Probado en el camino: con el ruido al 0,85 el cuerpo se agujereaba como un queso (celdas del ruido); con `fade_base` 0,42 la mitad de abajo quedaba pálida y translúcida; 0,2 es el punto.

**Comprobación** (vistas desde arriba, de lado y desde el suelo en el lab, más `bola_cerca`, `bola_juego` y `bola_vuelo`): sin facetas, silueta redonda y una sola; la estrella ya no se ve como estrella, queda un abanico muy tenue en el borde de abajo (visible solo desde abajo o a 2 m, y fundido).

**Tonos** (`bola_cerca`; objetivo 15–30 / 50–65 / ≤ 20): 18 / 76 / 6 % (ronda 4: 22 / 58 / 21): demasiado naranja y poco amarillo, el cuerpo es ahora casi plano de color; el núcleo claro se ve poco. Prueba sin ventana: 0 fallos. Nota propia de la bola: 4,5 (cuerpo liso, una sola llama; le falta un núcleo más claro). Reloj: 20:49 – 21:00, ≈ 11 min.

## Ronda 6 (1/11): la bola como billboard

La ronda 5 no resolvió la bola: el abanico de la base seguía viéndose como un disco con rayos y en vuelo parecía un cilindro cortado con tapa. Causa: en una malla de revolución, cualquier UV que converge en un polo pellizca la textura y fundir o cerrar el polo deja una tapa. Se cambia de enfoque. La malla de la ronda 5 queda como `BolaFuegoToy_malla.tscn` y sus capturas y GIF en `ronda5/` para compararlas.

**Método.** Un solo quad con billboard y el shader `fuego_lelu_bola.gdshader` (el método de Le Lu en 2D): la textura de lenguas sube por el eje de la llama, un segundo ruido, y en lugar del gradiente vertical se resta un **gradiente radial** (distancia al centro de la bola, estirada hacia arriba) con `pot_grad` 3,2: la silueta es una gota redonda abajo con lenguas arriba; la textura pesa poco en la mitad de abajo (silueta redonda) y todo el peso arriba; mismo `smoothstep` con `blandura` 0,22, misma rampa y núcleo claro en el centro (`calor_extra`); el ruido fino de las puntas y el titileo son los de siempre; un marco que apaga el alfa en el borde del quad. Sin malla 3D: no hay polos, facetas ni tapas. Halo aditivo pequeño detrás, luz, chispas y trocitos como antes. En vuelo, `EfectoToy` pone `inclin` = 1 y le pasa a cada frame la velocidad (`vel_dir`): el eje de la llama se alinea en pantalla con la velocidad y la llama se alarga hacia atrás (la estela es la misma llama estirada, no un segundo objeto); no hay cilindros.

**Comprobación:** una sola silueta, sin disco y sin rayos, desde la cámara del juego, desde arriba, de lado y desde el suelo (vistas del lab), en `bola_cerca`, `bola_juego` y `bola_vuelo`. El impacto no se tocó (sigue el de la ronda 2).

**Mallas frente a billboard.** El billboard gana: la malla de la ronda 5 daba un buen volumen pero nunca perdió del todo el abanico de la base ni el aspecto de tapa en vuelo; el billboard no tiene ninguno de los dos defectos. Lo que se pierde: no se ve de perfil si la cámara baja a ras (siempre mira a la cámara) y el interior no tiene cuerpo.

**Tonos** (`bola_cerca`; objetivo 15–30 / 50–65 / ≤ 20): **15 / 65 / 20 %** (ronda 5: 20 / 74 / 6). Núcleo claro visible. Nota propia de la bola: 4,5. Prueba sin ventana: 0 fallos. Reloj: 20:53 – 21:05, ≈ 12 min (la primera versión era una llama alta y estrecha, no una bola; se ensanchó con `radio` 0,52 y `alargado` 0,72).
