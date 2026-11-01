# Prueba 2 de VFX en Godot: muro de fuego toon (1/11/2026)

Rama `claude/prueba2-godot-toon` (worktree `E:\tmp\wt_prueba2_godot`), sin push. Diseño: `docs/PRUEBA2_VFX_TOON_2026-11-01.md`. Referencia: `docs/capturas/comparativa_vfx/referencia/` (`ref_muro.jpg`, `ref_hoguera.png`, `ref_impacto.jpg`).

## Qué hay

| Cosa | Dónde |
|---|---|
| Shader de la llama (procedimental, un plano) | `presentacion/vfx/toon/fuego_toon.gdshader` |
| Humo de bolas de dos tonos, chispas, núcleo de la bola | `humo_toon.gdshader`, `chispa_toon.gdshader`, `bola_toon.gdshader` |
| Rampas en escalones (`GradientTexture1D`, interpolación constante) | `rampa_fuego_toon.tres` (rojo, naranja, amarillo) y `rampa_fuego_azul.tres` |
| Escenas con `EfectoVfx3D` (`preparar` / `lanzar` / `morir`) | `MuroFuegoToon.tscn` (obligatoria), `ColumnaFuegoToon.tscn`, `BolaFuegoToon.tscn`, `ImpactoFuegoToon.tscn` (extra) |
| Montaje de un solo uso (después se edita en el editor) | `herramientas/vfx/montar_muro_fuego_toon.gd` |
| Lab: tecla 5 muro, 6 columna, 7 bola, 9 diez muros toon; RePág/AvPág eligen mando, + / − lo mueven, Retroceso lo repone | `laboratorios/lab_vfx_comparativa_3d.gd` |
| Captura (con ventana, sin clics) y secuencia con Movie Maker | `herramientas/captura_vfx_toon.gd` |
| Prueba sin ventana | `herramientas/prueba_vfx_toon.gd` |
| Capturas y GIF | esta carpeta |

Los diez mandos de `fuego_toon.gdshader` (con rango en el inspector): `fps`, `umbral`, `altura_llama`, `desplazamiento`, `contorno`, `rampa`, `velocidad`, `escala_ruido`, `brillo`, `erosion`. Además hay ajustes finos fuera de los diez (`suavidad` con tope 0,03, `ancho_lengua`, `base_brillante`, `gotas`, `semilla`, `tam_malla`, `billboard_y`, `retroceso`, `color_contorno`).

## Método

Procedimental puro, sin flipbook ni Blender. El muro son dos planos (`PlaneMesh` 6,9 × 1,5 m, subdividido 48 × 6, uno delante y otro 9 cm detrás con otra semilla). En el fragmento hay tres capas de celdas a lo largo del muro; en cada celda una lengua cuya altura, ladeo y ondulación salen de un ruido de valor 1D en tiempo cuantizado (`floor(TIME * fps) / fps`). Su forma es una gota invertida (ancha abajo, punta redondeada, `pow(1 − yn^2,4; 0,5)`); la «profundidad» dentro de la lengua se pasa por la rampa en escalones y sale rojo en el borde, naranja en el cuerpo y amarillo claro en el corazón. Encima de cada punta, a ratos, una gota suelta que sube y se va de golpe. La silueta se decide con descarte (alfa 0/1, `discard`), así que no hay mezcla ni orden de planos y el borde es duro. La malla ondula por desplazamiento de vértices con el mismo ruido. El tamaño en metros se lee de la escala del nodo (`MODEL_MATRIX`), de modo que un muro el doble de largo tiene el doble de lenguas (la misma densidad), no lenguas el doble de anchas. Humo y chispas son `GPUParticles3D` con `fixed_fps = 12` y sin interpolar; la luz es una `OmniLight3D` cuyo `light_energy` va por una pista de 12 claves a 1/12 s con interpolación del vecino más cercano. Columna, bola e impacto reutilizan `fuego_toon` con `billboard_y` (el plano gira hacia la cámara sin tumbarse); la bola y el impacto añaden `bola_toon` (círculo de borde ondulado en tres tonos concéntricos, con contorno oscuro en el impacto).

## Horas por paso (reloj del PC; las marcas son las de la sesión)

| Paso | Marcas | Tiempo |
|---|---|---|
| Lectura del diseño, referencias, prueba 1 y lab; importación de Godot (la caché se hizo en < 1 min, no en 10) | 13:24 – 13:26 | ≈ 2 min |
| Tres shaders + script de montaje + primera escena `MuroFuegoToon.tscn` | 13:26 – 13:27 | ≈ 2 min |
| Tecla 5, panel y diez mandos en el lab; script de captura | 13:28 – 13:31 | ≈ 3 min |
| Una ejecución colgada por un error de sangría en el lab (esperé el tiempo límite de 4 min antes de mirar el log) | 13:30 – 13:34 | ≈ 4 min perdidos |
| Cinco rondas de captura y corrección del muro (r1 a r5) | 13:34 – 13:37 | ≈ 3 min |
| Secuencia de 3 s con Movie Maker, análisis de fotogramas consecutivos y GIF | 13:38 – 13:40 | ≈ 2 min |
| `prueba_vfx_toon.gd` (primer intento 3 fallos: dos por leer valores por defecto del servidor de render en headless y uno por la paleta con el bloom del lab; arreglados) | 13:40 – 13:41 | ≈ 2 min |
| Columna, bola e impacto (extras) con sus capturas y dos rondas de corrección | 13:41 – 13:49 | ≈ 8 min |
| Prueba final a 0 fallos, importación para generar los `.uid` | 13:49 – 13:51 | ≈ 2 min |
| NOTAS, diario y commit | 13:51 – | (ver el diario) |

Total hasta el muro que yo daría por «razonable»: **≈ 17 min de reloj** (13:24 → 13:41, restando los 4 min perdidos: ≈ 13 min). Con los extras, ≈ 27 min. De las 16 h de presupuesto se ha usado menos de una hora; ninguna parte del cuello de botella fue el motor, sino acertar con la forma de la silueta (rondas r1 a r4). Pendiente de la hora de Pablo con los mandos: la nota de aspecto y las cinco modificaciones, que no he hecho.

## Rondas de corrección (cada captura mirada con la herramienta de lectura de imágenes)

| Ronda | Qué se vio | Qué se cambió |
|---|---|---|
| r1 | Un rectángulo rojo llenaba todo el plano (la banda de la base valía 0,15 en todas partes y pasaba el umbral); lenguas muy puntiagudas porque la silueta dependía del color | Banda de la base solo bajo su altura; la silueta pasa a ser geometría (`q < 1 − umbral`, `yn < 1 − umbral`) y el color es aparte |
| r2 | Silueta correcta, lenguas en forma de llama de icono, borde rojo muy grueso, núcleo amarillo enorme, humo y chispas grandes, banda de la base alta | Punta más roma, altura por defecto 0,8, rampa con rojo más estrecho, base más baja, humo y chispas más pequeños |
| r3 | Las gotas sueltas salían como anillos naranja con centro amarillo | Gotas de un solo tono; menos gotas (0,35); extremos del muro bajan; borde de las lenguas ondulado a saltos de fotograma |
| r4 | Mucho más cerca de la referencia; el rojo casi desaparecía | Rojo hasta 0,13 en la rampa |
| r5 | Muro, lejos, juego y diez muros correctos; chispas con forma de hexágono (el rombo se recortaba contra el cuadrado) | Chispa más estrecha en X (rombo de verdad) |
| Extras | Columna: una sábana naranja sin forma a 2 m; bola: las lenguas dejaban ver el borde plano del plano por los lados; impacto: el borde de la bola se cortaba contra el cuadrado | Lenguas más estrechas en la columna; plano de la bola más estrecho y detrás del núcleo (`retroceso`); radio de `bola_toon` más pequeño (`radio_base`) |

## Frente a cada rasgo de §0.1

| Rasgo | Resultado | Cómo se comprobó |
|---|---|---|
| Paleta: tres tonos planos (≈ `#FFF3B0`, `#FF8A1F`, `#C8321E`), humo en dos grises azulados, chispas amarillas | **Cumple.** Rampa constante con exactamente esos tres colores; en `muro_cerca_solo_llama.png` (llama, humo y chispas sobre negro, sin bloom) hay **6 colores distintos a 5 bits** (3 de llama + 2 de humo + 1 de chispa) frente a un límite de 8 | `prueba_vfx_toon.gd`, sección 7. El número de la llama sola es 3. |
| Silueta: lenguas redondeadas como gotas invertidas que se separan por arriba y desaparecen de golpe, `suavidad` ≤ 0,03 | **Cumple en lo medible, a medias en el parecido.** Tope del rango y valor por defecto de `suavidad` ≤ 0,03 y descarte duro; hay gotas sueltas. Frente a `ref_muro.jpg` las lenguas son más regulares y simétricas («papel picado»); la referencia es más desordenada, con una masa continua más baja y lenguas que se funden | Prueba sección 5; mirada en las capturas |
| Animación a 12 fps cuantizados en todo | **Cumple, medido.** Con Movie Maker a 24 fps (121 fotogramas) la diferencia entre fotogramas consecutivos alterna 0,000 (idénticos) y 0,06 a 0,11 de la imagen: la imagen entera (llama, humo, chispas y luz) solo cambia cada dos fotogramas. `fps` es un mando | `sec`: script `captura_vfx_toon.gd -- sec`, análisis con Pillow en `E:\tmp\prueba2_godot\an.py` (no se versiona) |
| Iluminación de la llama: ninguna (`unshaded`) | **Cumple por construcción** (los tres shaders son `unshaded` y la prueba lo comprueba en el código). Capturé `muro_cerca_sin_sol.png` con el sol apagado pero **no he hecho una comparación numérica** entre las dos: solo la he mirado | `muro_cerca_sin_sol.png` frente a `muro_cerca.png` |
| Luz emitida: una luz cálida con titileo cuantizado, ≤ 1 luz por efecto | **Cumple.** Una `OmniLight3D`, 12 claves a 1/12 s con interpolación del vecino más cercano. En la escena del muro: 1 luz y 54 partículas | Prueba secciones 2 y 6 |
| Humo en bolas de dos tonos que nace en la punta | **Cumple en la forma, no del todo en el parecido.** Nace a 1 m (la punta típica), no del suelo; bolas de dos tonos. Se ve como esferas sueltas flotando; en la referencia es más escaso y pegado a las lenguas | Prueba (posición del emisor ≥ 60 % del alto); mirado en las capturas |
| Contorno opcional | **Cumple.** Mando `contorno` 0–1 (línea oscura donde la profundidad es menor que `umbral + contorno × 0,12`); por defecto apagado en el muro, 0,5 en el impacto | Capturas del impacto; el muro con contorno no lo he capturado |
| Distancia: se lee a 10 m con la cámara del juego | **Cumple.** `juego_muro.png` y `muro_lejos.png` se leen como línea de fuego; el humo y las gotas se ven como motas | Mirado |
| Presupuesto: ≤ 1 luz, ≤ 300 partículas, diez muros ≥ 60 fps a 1080p | Luz y partículas **cumplen** (1 luz; muro 54, columna 38, bola 24). Los diez muros dieron **58 fps y 60 fps** en dos ejecuciones a **1600 × 1000** (RTX 3070) con 10 luces y 540 partículas; **no he medido a 1080p ni con el fps desbloqueado**, así que el «≥ 60» no queda demostrado | `diez_muros.png` |

Lo que más separa el muro de `ref_muro.jpg`, según yo: (1) la masa continua baja de la referencia, que aquí es una franja plana de crema en la base; (2) lenguas demasiado ordenadas; (3) el humo en esferas aisladas. Mi estimación del parecido es de **2,5–3 sobre 5**, pero esa nota es de Pablo.

## Extras

- **Columna** (`columna_cerca.png`, `columna_lejos.png`): es la parte más floja. Dos lenguas altas con billboard bloqueado en Y; de lejos se lee como columna de fuego, a 2 m queda como una pared de naranja sin la silueta de gota de `ref_hoguera.png`.
- **Bola** (`bola_vuelo_cerca.png`): núcleo de tres tonos con borde ondulado y una lengua hacia arriba. Las lenguas dejan ver su borde plano inferior por encima del núcleo.
- **Impacto** (`bola_impacto_cerca.png`, `bola_impacto_lejos.png`): la parte más cercana a su referencia (`ref_impacto.jpg`): masa de tres tonos con contorno recortado, chispas y humo.

## Contenido ajeno

**0 %.** Todo es propio: shaders escritos aquí, ninguna textura (las lenguas, las bolas y las chispas son geometría en el fragmento; la rampa son tres colores en un `.tres`). No se usa ninguna imagen de la referencia como textura (siguen siendo solo para mirar). El suelo, los cubos y la jugadora del lab son los de la prueba 1.

## Lo que no se pudo verificar

- Que los tres shaders **compilen** se ve porque se renderizan en las capturas (ventana real, Vulkan); la prueba sin ventana solo comprueba que se cargan, no que compilen.
- El fps a 1080p y sin límite (ver arriba).
- No he hecho **las cinco modificaciones de §1** ni el «solo, sin pedir código, cronometrado»: son para la hora de Pablo. Mi estimación de cada una con los mandos actuales: (1) fuego azul: tecla de la rampa en el lab (ya existe `rampa_fuego_azul.tres`), 1 paso; (2) de 12 a 6 fps: mando `fps`, 1 paso (pero las partículas llevan `fixed_fps` aparte, en el inspector de cada nodo, y la luz sus claves); (3) lenguas un 50 % más altas: mando `altura_llama` de 0,8 a 1,2; (4) quitar el humo y doblar las chispas: hace falta tocar la escena (borrar el nodo `Humo` y subir `amount` de `Chispas`); (5) muro al doble de largo con la misma densidad: `preparar` con el doble de X escala el plano y el shader mantiene la densidad (comprobado la escala en la prueba, no el aspecto en pantalla).
- La `Movie Maker` grabó a 1152 × 648; el GIF son 36 fotogramas a 12 por segundo, 768 px de ancho, 64 colores (la cuantización del GIF puede cambiar tonos respecto a la captura).
- No he abierto el editor de Godot: las escenas están escritas por script y comprobadas por carga en headless y por las capturas; no he revisado cómo se ven en el inspector.

---

# Ronda 2 (1/11, tras «parece un papel», Pablo): lenguas sueltas superpuestas en vez de un plano

Lo de arriba describe la ronda 1 (dos planos con `fuego_toon`). `muro_cerca_r1.png` es la captura de aquella ronda, para comparar. Esta sección es la que vale para el muro; columna, bola e impacto siguen con la técnica de la ronda 1 y no se han rehecho.

## Qué tiene el fuego de `ref_muro.jpg` y no tenía el mío (descrito mirando la referencia y mis capturas de la ronda 1; lo escribo al final de la ronda, no antes de tocar nada)

- **Proporción de tonos**: en la referencia domina un naranja ámbar (≈ `#C06020` a `#E08020`) con un amarillo cálido (≈ `#E0C020`) en la base y la mitad baja de cada lengua; el rojo es solo el borde fino de arriba. En la ronda 1 yo tenía una franja de crema de 7 m (el tono más claro ocupaba la mitad de la llama) y tres tonos en zonas enormes. Medido: el 89 % de los píxeles de fuego de la referencia son de tono < 45° (naranja) y solo el 11 % amarillo; en mi ronda 1 la luz crema/amarilla era dominante.
- **Forma**: lenguas más anchas que altas, redondeadas, de muchos tamaños, solapadas a distintas profundidades; la mía eran dientes de sierra idénticos en un solo plano.
- **Línea de base**: no es recta; sube y baja con la hierba. La mía era una regla.
- **Humo**: poco, gris claro, fino. **Chispas**: muchas, pequeñas, como puntos.
- **Brillo**: el fuego de la referencia es oscuro-cálido (valor entre 0,75 y 0,9 en el 45 % de los píxeles); el mío era saturado y al máximo.

## Qué cambió

| Antes (ronda 1) | Ahora (ronda 2) |
|---|---|
| Dos planos con tres capas de lenguas cada uno | **Tres grupos de `GPUParticles3D` (24 grandes detrás, 44 medianas, 52 pequeñas delante = 120 lenguas)**, cada partícula es una lengua en un quad (`lengua_toon.gdshader`) que gira hacia la cámara sin tumbarse, con su forma (anchura, ladeo y ondulación por semilla de la posición de nacimiento), su altura (0,25–1,0 m) y su vida (0,4–0,8 s: nace, crece, se estrecha y desaparece de golpe). Más anchas que altas (quad 1,35 : 1). Ancho máximo al 30 % de la altura, punta redondeada |
| Rampa de 3 tonos | **Rampa de 5 escalones** (`rampa_fuego_5.tres`): rojo oscuro (borde), rojo-naranja, naranja, amarillo ámbar, crema; el color depende de la altura dentro de la lengua (crema solo en el corazón de la base, amarillo la mitad baja, naranja el cuerpo, rojo arriba y en el borde). El crema ya no es la mitad de la llama sino un 3 % de los píxeles |
| Franja recta crema | **Base** (`base_toon.gdshader`): franja de ≈ 16 cm, amarillo abajo, naranja, rojo fino, con el borde superior ondulado por ruido de valor a saltos de 1/12 s |
| Sin resplandor | **Halo** (`halo_toon.gdshader`): óvalo plano aditivo de dos tonos en el suelo con el radio titilando a saltos de fotograma; la luz sigue siendo una |
| Esferas azules opacas | Humo en bolas de **dos grises cálidos** con el tono claro como media luna, borde irregular, 0,3 a 0,5 m, **7 vivas**, desde 0,75 m de altura (la punta de las lenguas) |
| Rombos | Chispas alargadas con cabeza redonda y cola fina, **90 vivas**, dos tonos que salen de la propia rampa (no añaden colores) |
| Paleta de la spec tal cual | Los colores se bajaron de brillo (`brillo` 0,86) y se calibraron contra lo que sale por pantalla, porque el tonemap del lab (filmic) aclara y desvía el amarillo: ámbar `#F09A20`, naranja `#DC6418`, rojo `#C4401A`, borde `#8A2412`, crema `#FFD88A` (más oscuros y menos amarillos que `#FF8A1F` / `#FFF3B0` de §0.1; el objetivo era parecerse a la referencia, que manda) |

Los diez mandos de `lengua_toon.gdshader` (mismo nombre que los de `fuego_toon` para el panel del lab; el lab los aplica a todos los materiales toon y `fps` además a `fixed_fps` de las partículas): `fps`, `umbral`, `altura_llama` (fracción del quad), `desplazamiento` (ladeo y ondulación), `contorno` (borde rojo oscuro, 0,35), `rampa`, `velocidad` (ritmo del ondular), `escala_ruido` (frecuencia del ondular), `brillo` (0,86), `erosion`.

## Medida objetiva por ronda

`herramientas/distancia_fuego_toon.gd` (sin ventana): histograma de tono × valor de 8 × 8 celdas sobre los píxeles de fuego (saturación > 0,4), en la franja de la referencia (filas 270–380 de 668) y en el rectángulo del muro de mi captura (`muro_cerca.png`: rect 220,200,1380,800; `juego_muro.png`: rect 220,140,1160,250). Distancia 0 = igual, 2 = nada en común. **Límites**: la referencia incluye hierba naranja detrás (cuenta como fuego), el JPEG da degradados que un fuego plano nunca tendrá (así que hay un suelo por debajo de 0 que no se alcanza), y mi rectángulo lleva chispas y humo.

| Versión | `muro_cerca` | `juego_muro` | Qué se cambió |
|---|---|---|---|
| Ronda 1 | 1,034 | 1,036 | (base de comparación) |
| r8 primera con partículas (lenguas como colinas, amarillo vivo) | 0,727 | 0,758 | el cambio de técnica |
| r9 tonos más naranja, sparks 110 | 0,725 | 0,741 | |
| r10 lenguas más puntiagudas y densas | 0,726 | 0,740 | |
| r11 / r12 brillo 0,9 y ámbar | 0,732 / 0,730 | 0,741 / 0,741 | casi nada: el tonemap deshacía el cambio |
| r13 tonos subidos a naranja saturado | 0,944 | 0,954 | **peor**; se desechó (todo el fuego quedó en una sola celda de tono y valor) |
| r14 rampa más oscura calibrada con la salida real | 0,580 | 0,648 | **el mejor muro_cerca** |
| r15 lenguas más bajas, más anchas, humo menor | 0,655 | 0,653 | más parecido a la vista, la métrica no bajó |
| **Final entregado** | **0,662** | **0,650** | chispas con la rampa (cuenta ≤ 8 colores) |

Lectura honesta: la distancia bajó de 1,03 a 0,65 (−37 %) pero no por debajo de ≈ 0,6 porque el fuego plano tiene el 70 % de sus píxeles en una sola celda de valor y la referencia reparte 54 / 35 / 9 % en tres. No hay forma de bajar eso sin degradado o ruido de textura, que es justo lo que no queremos. Mirando las capturas, r15 se parece más a la referencia que r14 aunque la métrica empeore un poco (lenguas de tamaño y proporción más cercanos), así que no la he tratado como criterio único. La ronda 1 → 2 sí baja y la captura se acerca claramente.

## Nota propia frente a `ref_muro.jpg` (1–5)

- Ronda 1: **2 / 5** (se lee como fuego, pero es una franja de recortes idénticos con una base de regla).
- Ronda 2 (`juego_muro.png`, cámara del juego): **3,5 / 5**; ya es la misma familia de fuego: lenguas redondeadas, solapadas, de tamaños distintos, base ondulada, tres tonos más el amarillo claro abajo y rojo fino arriba, humo escaso, chispas pequeñas. Lo que me impide el 4: (1) las lenguas son más altas y puntiagudas que las de la referencia, que forman una masa baja casi continua; (2) cada lengua tiene bandas horizontales de color nítidas («cebolla»), la referencia las tiene más irregulares; (3) en `muro_cerca.png` (cámara oblicua a 2 m) se ven los quads de perfil y la base como tira fina con puntitos; (4) el humo son bolas aisladas, no una nube.
- Tiempo: 13:58 – 14:44 ≈ **46 min de reloj** para la ronda (muy por debajo del límite de 3 h; paro porque la métrica ha dejado de bajar y la nota propia, 3,5, no llega al 4 por cosas que cuestan más que unos retoques: lenguas con ruido de borde propio y más masa baja).

## Otros resultados de la ronda

- Secuencia de 3 s (36 fotogramas a 12 por segundo en `muro_2m_3s.gif`) rehecha. A 24 fps la diferencia entre fotogramas consecutivos sigue alternando 0,000 y 0,09–0,12: se mueve solo cada 1/12 s (lenguas, humo, chispas, luz, halo).
- `prueba_vfx_toon.gd`: **0 fallos**; paleta de **7 colores** a 5 bits (5 de llama, 2 de humo; las chispas usan los de la rampa). La captura de la paleta (`muro_cerca_solo_llama.png`) oculta el halo (aditivo, añadiría tonos que no son de la llama) y el bloom.
- Partículas del muro: 120 lenguas + 7 humo + 90 chispas = 217 (≤ 300), 1 luz. Diez muros: 60 fps (el panel de la captura), a 1600 × 1000, no a 1080p.
- No cumple lo pedido: la rampa son 5 tonos y no 3 (por petición de la ronda), y los colores se alejan de `#FFF3B0` / `#FF8A1F` / `#C8321E` (ver arriba). No he probado `contorno` más alto ni el halo con el sol apagado.
