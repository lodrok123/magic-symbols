# Análisis de *Echoes of Wisdom*: qué aprender para Magic Symbols

21/10/2026 · contexto JUEGO · documento de estudio, **no es diseño aprobado**.

**Origen.** RomFS del cartucho de Pablo (`C:\Users\pablo\Desktop\Extraccion Juego\EXTRAIDO\Zelda\`), leído en solo lectura. Se han estudiado las 95 tablas de datos, 25 niveles (31 027 objetos colocados), los 450 actores, 29 flujos de eventos, los 96 shaders y una muestra de modelos y texturas.

**Límite que no se negocia.** Del juego no entra nada en el repo ni en Magic Symbols: ni datos, ni textos, ni modelos, ni texturas, ni shaders. Solo entran las conclusiones, contadas con nuestras palabras. Los números del juego se citan aquí para entender cómo está construido, no para copiarlos.

**Cómo leer las marcas.** **[M]** = medido contando bytes o filas. **[D]** = deducido (interpretación razonable, pero no confirmada). Los detalles con todas las tablas están en los cuatro anexos: `EOW_1_TABLAS.md`, `EOW_2_NIVELES.md`, `EOW_3_ACTORES.md` y `EOW_4_ASSETS.md`.

---

## La idea de fondo

EoW es un juego de puzles con muchísimas combinaciones (128 ecos × elementos × salas), y **casi nada de eso está escrito como regla**. Lo sostienen tres decisiones que se repiten en todos los sistemas:

1. **Datos en tablas que se referencian entre sí.** Hay una tabla por sistema, no columnas que se van añadiendo al objeto.
2. **Papeles pequeños en lugar de tipos grandes.** Ningún objeto es «de fuego». En su lugar *emite calor*, *propaga llama*, *se puede prender*, *está ardiendo* o *apaga*.
3. **Lógica, números y presentación por separado.** La lógica emite una señal, una tabla decide el efecto y el sonido, y los números viven aparte y se comparten entre variantes.

Es la misma filosofía de `ARQUITECTURA.md` («las combinaciones no se programan, emergen»), llevada más lejos de lo que la llevamos hoy. Ahí está lo útil: no hay que inventar una arquitectura nueva, sino terminar de aplicar la nuestra.

---

## 1. Coste de lo que se invoca (los ecos) → coste de hechizos

- **[M] El coste va de 1 a 6 y mide el poder, no el tamaño.**
  - De los 35 objetos, 23 cuestan 1. Las versiones más fuertes de un enemigo suben de 1 a 2 puntos por nivel (2 → 4 → 5).
  - **Las variantes elementales cuestan lo mismo sea cual sea el elemento**: los tres Keese elementales cuestan 4.
  - La suma de los 128 ecos es 320.
- **[M] La rebaja de coste va en otra columna.** Hay seis grupos de unos 14 ecos, ordenados según el avance en la historia. Los de coste 1 no pueden bajar.
- **[M] La huella en la rejilla es un dato:**
  - forma: redonda, rectángulo o alta;
  - ancho, fondo y alto, con la altura en **medias casillas**;
  - si se ajusta a la rejilla: los 35 objetos sí; de los monstruos, solo los que están fijos o enraizados;
  - qué giros admite, como un número.
- **[M] Los totales están cerrados.** La energía del compañero suma exactamente 1000: un 70 % viene de los jefes y un 30 % de los secretos. Los coleccionables de poder suman exactamente 150.

**Para nosotros.**
- Un coste entero por glifo y por sello, y la rebaja en otra columna ligada a la progresión (encaja con §7 síntesis de `DISENO_FUTURO.md`). Que **el elemento no cambie el coste**: así el jugador elige el elemento por lo que hace, no por lo que cuesta.
- Fijar desde el principio cuánto maná o cuántas páginas se pueden conseguir en total, y repartirlo entre jefes y secretos.
- Para §3b (glifos como geometría): guardar alturas en medias casillas; las formas sólidas (barrera, muro) se ajustan a la rejilla y los proyectiles van libres.

## 2. Reacciones elementales: emisor y receptor

- **[M] De los 450 actores:**

  | Actores | Papel |
  |---|---|
  | 148 | emiten calor |
  | 136 | pueden estar ardiendo |
  | 58 | propagan llama |
  | 19 | se pueden prender (las flechas, por ejemplo) |
  | 91 | reciben descarga |
  | 13 | están electrificados |
  | 87 | se congelan |
  | 4 | apagan |
  | ~160 | les afecta el viento |

- **[M] Las variantes se hacen sumando o quitando papeles.** El Zol de agua es el Zol normal sin los papeles de fuego y con «apaga». El bloque de hielo es la caja de madera sin fuego ni transporte y con hielo.
- **[M] Todos los enemigos tienen el mismo paquete de reacciones:** quemado, electrocutado, congelado, empujado, caer al agua, a la lava o al vacío, aturdido… En los 9 que comprobé está completo o le falta una. Un escudo añade su propio paquete (guardia, escudo roto).
- **[M] La presentación va en una tabla aparte.** La lógica emite señales como `prendido`, `apagado_por_agua`, `congelado`, `derretido` o `entra_en_lava`, y una tabla por actor decide qué efecto y qué sonido salen, con variantes según el suelo.

**Para nosotros (§4 Enemigos y §2 Intención por elemento).**
- Partir nuestras etiquetas en pares emisor/receptor: `emite_calor`, `propaga_llama`, `inflamable`, `ardiendo`, `apaga`, `conduce`, `electrificado`, `congelable`.
  - Una flecha `inflamable` que atraviesa una hoguera sale ardiendo sin ninguna regla escrita para ese caso.
  - Encaja con lo que ya hacemos por duck typing (`on_spell_hit`).
- Un **contrato de reacciones obligatorio** para todo enemigo: arder, congelarse, electrocutarse, ser empujado y caer al agua. El escudo que arde de §4 sería un componente con sus propias reacciones.
- Una tabla `señal → partículas + sonido` como Resource. Al pipeline le daría un catálogo cerrado de VFX que producir.

## 3. Lógica de puzles sin código por sala

- **[M] 479 condiciones con nombre.** Se combinan con Y u O, se niegan con `!` y pueden contener otras condiciones.
  - 132 son **plantillas** que leen los parámetros `$0…$7` del objeto colocado: una sola condición vale para cualquier puerta.
  - Tipos de comprobación: flag global, objeto en inventario, interruptor local de la sala (0–7), estado de una misión, variable, contador, temporizador, estado de la jugadora (suelo, agua, pared, aire).
- **[M] Las flags se nombran por sala y por hecho** (`L001R017SwitchFoot`), no por objeto. Un interruptor escribe la flag y la leen dos puertas, una valla, una estatua y un cerrojo de sala. Hay 1624 flags globales; una mazmorra grande usa unas 40.
- **[M] Unos pocos objetos lógicos invisibles hacen los puzles:**
  - «comprueba que todos han muerto»: enlazado a N enemigos, escribe una flag;
  - «cierra la sala»: escucha esa flag;
  - el activador condicional;
  - los sensores de zona.

  L_Dungeon001 tiene 92 objetos lógicos frente a 14 enemigos.
- **[M] Los eventos solo hacen la escena** (cámara, puerta, jingle). El flujo del cofre es el mismo para todos: el objeto le llega como argumento.

**Para nosotros.**
- Un autoload `Flags` con `flag_cambiado(nombre)`.
- Puertas, cofres y bloqueos con `@export var flag: StringName`.
- Tres o cuatro actores lógicos: comprobador, cerrojo, sensor y activador condicional.
- Condiciones con nombre en una tabla, que pueden preguntar también por el **estado de una casilla** (mojada, ardiendo…). Así un puzle «apaga las tres antorchas» se monta solo con datos.
- Encaja con «un nivel es un plano de letras»: las letras dicen *qué* es cada casilla, y un bloque de datos aparte dice *cómo está enlazado*.

## 4. Niveles, rejilla, colisión y navegación

- **[M] Unidades.** La casilla de diseño mide 1,5 y debajo hay una rejilla técnica de 0,75. Una sala de pantalla tiene unas 12×12 casillas. Las mazmorras grandes tienen unas 24 salas (19–30); las pequeñas, unas 8.
- **[M] Agua, lava, vacío y escaleras son volúmenes** (cajas colocadas), no un tipo de suelo: hay 262 estanques, 101 lavas y 88 abismos.
- **[M] Además del dibujo hay un mapa 3D de ocupación** (sólido sí/no, por celda, en octree) por sala. [D] Sirve para preguntar «¿cabe aquí?» sin lanzar rayos.
- **[M] La colisión lleva un material por triángulo** (código + flags). No se han encontrado los nombres de los materiales.
- **[M] La navegación es una rejilla de columnas con altura** (una zona por sala), no una malla de polígonos.
- **[M] Cámara:** presets con nombre que se eligen por zona. Perspectiva estrecha: 28° a −45° en la vista cenital y 10° en la lateral, casi ortográfica.

**Para nosotros (prueba 3D, §0 y §0b).**
- **Separar en capas** el tipo de suelo (plano de letras), el estado de la casilla (mojada, quemada…) y los volúmenes (agua que rellena: §2, «rellenar un espacio con agua»).
- Un **mapa de ocupación por casilla y altura**, actualizado al empujar o crear bloques. Lo consultan el rasterizado de glifos de §3b, la regla de «¿cabe el bloque de tierra?» y la IA.
- **A\* sobre casillas** (altura + vecinos, salto ±1) en lugar de NavigationMesh. Con altura entera basta, y se invalida al cambiar un bloque.
- Presets de cámara ortográfica por zona.

## 5. Arte, shaders y rendimiento (prueba 3D)

- **[M] Un shader por receta**, hecho en un editor de nodos: 81 materiales. Todos comparten las mismas opciones de sistema (niebla, SSAO, dither, sombras).
- **[M] El estado se resuelve en el shader:**
  - hay una variante `Burn` para lo quemado;
  - la aparición de un eco es un **disolver por celdas Voronoi**, sin partículas;
  - el agua tiene opacidad por profundidad, espuma de orilla y cáusticas en coordenadas de mundo;
  - la lava usa un flowmap.
- **[M] Look diorama:** tilt-shift + DOF + SSAO + bloom + tonemap.
  - Una única luz direccional casi cenital, cuyo color da el tono de cada mazmorra, más luz ambiente de dos colores.
  - Albedos de contraste muy bajo y sin luz horneada. En los personajes, rim y fresnel de color en vez de PBR realista.
- **[M] Transparencia por tramado** (Bayer 4×4) en todos los materiales: sirve para fundir techos y objetos que tapan y para que las cosas aparezcan, sin ordenar transparencias.
- **[M] Presupuestos:**
  - protagonista: unos 9–11k triángulos y 67 huesos, texturas de 256²;
  - enemigo: unos 1,8k;
  - objetos: 700–1.500;
  - salas: 2,6k–41k;
  - texturas compartidas de 1024² (unos 2,8 MB por juego de texturas);
  - **sin LODs**.

  Formatos: BC1/BC3 para el color, BC5 para las normales. Cubemaps de 64² por sala. Sombra sin cascadas en una caja de ±15 m alrededor de la jugadora.
- **[M] La hierba solo tiene viento:** no se aparta al pasar (eso lo tendríamos que hacer nosotros).

**Para nosotros (criterios 2 y 6 de §0).**
- **Estado por casilla con una textura de 1 píxel por casilla** (R mojado, G quemado, B helado, A ceniza) que lee el shader del suelo. **Responde al criterio 6 sin un PNG por estado**, y la misma textura la pueden leer la hierba y los VFX.
- Fuego que ilumina con `OmniLight3D` sin sombra (Forward+ ya reparte las luces por grupos).
- Fundido de lo que tapa la cámara con descarte por tramado.
- Un `ReflectionProbe` por sala.
- Cifras orientativas para Meshy: decimar al protagonista a 5–10k triángulos. Detalle en el anexo 4.

---

## Lo que NO se ha podido saber

- Los números de juego: radios, daños, tiempos y cuánto rebaja cada grupo de coste. Están en una base de datos compilada que no tiene nombres de campo.
- Los nombres de los materiales de colisión.
- El contenido de las partículas (`Common.ptcl`, 269 MB, no se ha traído).
- Cuántas luces puntuales usa cada sala.

## Propuesta de revisión paso a paso

Ordenada por lo que más afecta a decisiones abiertas:

1. **Reacciones emisor/receptor** (§2): cambia cómo se escriben las etiquetas de elementos y enemigos. Es contexto Juego.
2. **Estado por casilla con shader** (§5): decide el criterio 6 de la prueba 3D. Es Juego + Pipeline.
3. **Flags y actores lógicos** (§3): la forma de montar los puzles del Test 3.
4. **Capas de nivel, ocupación y A\*** (§4): rasterizado de glifos y navegación.
5. **Coste de hechizos y totales cerrados** (§1): para cuando toque la síntesis (§7).
6. **Look diorama y presupuestos** (§5): más del Pipeline que del Juego.

Nada de esto cambia ningún archivo del proyecto. Cuando decidas un punto, lo pasamos a `DISENO_FUTURO.md` con su coste, como manda el documento.
