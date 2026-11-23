# Revisión de VFX en laboratorio — 19/11/2026

Implementación de los pasos 1–5 de [la secuencia](VFX_SECUENCIA_MEJORAS_2026-11-19.md), preparada para revisión. Las clases de producción no cambian. Las variantes heredan las APIs y ciclos existentes; la selección experimental vive exclusivamente en `LabVfxRevision3D`.

## Estado vigente: restaurada la cuarta revisión

El usuario rechaza la quinta revisión y pide volver atrás. Se retira el volumen único y se restaura el muro anterior, con anticipación de 0,30 s, nacimiento paulatino de 1,65 s y colapso frontal de 2,2 s. Las aprobaciones de barrera y viento y la pausa de magma se mantienen. Las capturas de la quinta ronda se conservan como historial de la propuesta rechazada; no representan el efecto activo.

## Quinta revisión: una masa continua, sin espuma (rechazada y revertida)

El usuario rechaza la lectura de tres rectángulos separados y sus ribetes blancos. **Esta revisión sustituye el cuerpo de las rondas 1–4.** La referencia vigente es el dibujo lateral de cinco fases aportado por el usuario: pequeño abultamiento, elevación, frente alto, curvatura del labio y colapso delantero.

Se elimina el conjunto de tres cortinas y los billboards de cuerpo/cresta. El muro experimental tiene ahora **un único volumen cerrado, una superficie de malla y un material**. El perfil se extruye a lo largo de la anchura y se cierra en ambos extremos; el nacimiento y el apagado deforman esa misma geometría.

- La anticipación es un pequeño abultamiento de la propia masa, sin anillos de otro efecto.
- La subida forma un frente alto; el gancho se cierra al empezar la caída.
- La masa cae hacia delante y acaba en una película baja del mismo volumen.
- Se retiran espuma, ribetes blancos, franjas, gotas y láminas de charco separadas del muro.
- El material conserva los tonos turquesa, con variación suave en superficie. El cuerpo activo tiene cobertura completa para evitar ver caras internas como capas separadas; se desvanece al final del apagado.

El laboratorio arranca ahora en **Muro agua largo**. Con las mejoras activas muestra **«MURO DE AGUA v5 | UN SOLO VOLUMEN | SIN ESPUMA»**. F2 repite el nacimiento; F4 colapsa; F7 pasa al muro alto. F1 permite comparar con la versión de producción anterior, que conserva sus cortinas y espuma.

Abrir con `tools/probar_vfx_revision.cmd`, o con el comando de Godot de este documento. La barrera de agua y el viento aprobados se conservan; magma sigue pausado. Las recetas de géiser mantienen su implementación anterior.

| Vista lateral nueva | Muro largo | Muro alto |
|---|---|---|
| Elevación inicial | [Nacimiento](capturas/vfx_revision_2026-11-19/ronda5/perfil/02_nacer_28.png) | [Nacimiento](capturas/vfx_revision_2026-11-19/ronda5/perfil/03_nacer_28.png) |
| Masa activa | [Activa](capturas/vfx_revision_2026-11-19/ronda5/perfil/02_activo.png) | [Activa](capturas/vfx_revision_2026-11-19/ronda5/perfil/03_activo.png) |
| Inicio de curvatura | [Labio](capturas/vfx_revision_2026-11-19/ronda5/perfil/02_morir_08.png) | [Labio](capturas/vfx_revision_2026-11-19/ronda5/perfil/03_morir_08.png) |
| Caída frontal | [Caída](capturas/vfx_revision_2026-11-19/ronda5/perfil/02_morir_20.png) | [Caída](capturas/vfx_revision_2026-11-19/ronda5/perfil/03_morir_20.png) |

La cámara lateral de diagnóstico es ahora horizontal, para comprobar el perfil sin mezclar la elevación de los dos extremos de la extrusión. Las capturas oblicuas están en la misma carpeta sin el subdirectorio `perfil`.

Validación gráfica de ambos tamaños en RTX 3070, en perfil y vista oblicua: **0 fallos y 0 errores del motor/shaders**. La prueba comprueba un único cuerpo, tapas cerradas, ausencia de los nodos de espuma/gotas y de píxeles blancos en el render activo, fases continuas y liberación al terminar. Esto verifica la construcción y el funcionamiento; la aprobación artística del nuevo muro sigue pendiente.

Para regenerar: `prueba_vfx_revision.gd -- --capturas-vfx --ronda5 --perfil` (quitar `--perfil` para vista oblicua).

La regresión completa de las once recetas sin ventana también pasa con **0 fallos**. Medición activa en RTX 3070, 1280×720, mismo procedimiento de calentamiento y 60 muestras que en rondas anteriores:

| Muro | GPU anterior / volumen único (ms) | Dibujos anterior / volumen único |
|---|---|---|
| Largo | 0,191 / 0,047 | 7 / 2 |
| Alto | 0,154 / 0,044 | 7 / 2 |

Los dos dibujos del nuevo volumen corresponden al prepaso de profundidad y al color de una sola superficie. [Medidas de esta ronda](capturas/vfx_revision_2026-11-19/ronda5/medidas_rtx3070.json). Son muestras cortas de diagnóstico, no una garantía de rendimiento en escenas completas.

## Cuarta revisión: anticipación y nacimiento paulatino

En los muros largo y alto, el nacimiento dura ahora **1,65 s**:

- **0–0,30 s:** ondas bajas y agua que se reúne en el suelo; la altura del muro permanece en cero.
- **0,30–0,95 s:** aparece una lámina baja y comienza la subida desde el centro, con retraso hacia los extremos.
- **0,95–1,65 s:** el cuerpo gana altura de forma continua, se forma la cresta y desaparece la señal inicial del suelo.

La anticipación tiene su propia pista de animación, separada del crecimiento del cuerpo. Al repetir con **F2**, ambas se reinician desde cero. El colapso frontal de **2,2 s** de la tercera revisión se conserva; viento y barrera aprobados, y magma pausado, mantienen sus versiones.

| Receta | Anticipación | Lámina baja | Subida | Cresta |
|---|---|---|---|---|
| Muro largo | [Ondas](capturas/vfx_revision_2026-11-19/ronda4/02_nacer.png) | [Lámina](capturas/vfx_revision_2026-11-19/ronda4/02_nacer_28.png) | [Subida](capturas/vfx_revision_2026-11-19/ronda4/02_nacer_38.png) | [Cresta](capturas/vfx_revision_2026-11-19/ronda4/02_nacer_48.png) |
| Muro alto | [Ondas](capturas/vfx_revision_2026-11-19/ronda4/03_nacer.png) | [Lámina](capturas/vfx_revision_2026-11-19/ronda4/03_nacer_28.png) | [Subida](capturas/vfx_revision_2026-11-19/ronda4/03_nacer_38.png) | [Cresta](capturas/vfx_revision_2026-11-19/ronda4/03_nacer_48.png) |

Validación gráfica con RTX 3070: **0 fallos y 0 errores de motor/shaders**. Se comprueba que hay señal durante el retardo sin altura, que el crecimiento posterior pasa por estados intermedios y que se mantiene el recorrido frontal del colapso. Para regenerar esta ronda: `prueba_vfx_revision.gd -- --capturas-vfx --ronda4`. La captura `activo` se toma tras completar la nueva duración del nacimiento.

## Tercera revisión: colapso frontal del muro

El usuario aprueba el **pilar de viento**; se conserva la versión revisada. La barrera de agua sigue aprobada y magma continúa pausado.

En ambos tamaños del muro, **F4** activa un colapso de **2,2 s**:

1. La cresta se adelanta manteniendo altura; el labio empieza a caer antes que la espalda.
2. El cuerpo se curva y se estira hacia delante, con la base retrasada. No se encoge el nodo entero.
3. Las gotas siguen la cabeza de la ola. Al aterrizar, la salpicadura aparece delante y una lámina de agua avanza desde esa zona, pierde espesor y se desvanece.

La cortina y la espuma utilizan la misma función de deformación. Se retira el **frente visual trasero** durante el apagado: la tercera revisión sustituye el rastro bidireccional de las rondas anteriores por una rotura frontal. No cambia las casillas mojadas ni la simulación de agua del juego. Referencia de dirección artística: [Tsunami Wave Effect de Gabriel Aguiar](https://www.gabrielaguiarprod.com/product-page/unity-tsunami-wave-effect-nami-s-ult-league-of-legends).

Capturas de perfil; el frente del hechizo está hacia la derecha:

| Muro | Activo | Cresta adelantándose | Cuerpo cayendo | Aterrizaje |
|---|---|---|---|---|
| Largo | [Activo](capturas/vfx_revision_2026-11-19/ronda3/perfil/02_activo.png) | [Avance](capturas/vfx_revision_2026-11-19/ronda3/perfil/02_morir_20.png) | [Caída](capturas/vfx_revision_2026-11-19/ronda3/perfil/02_morir_32.png) | [Suelo](capturas/vfx_revision_2026-11-19/ronda3/perfil/02_morir_44.png) |
| Alto | [Activo](capturas/vfx_revision_2026-11-19/ronda3/perfil/03_activo.png) | [Avance](capturas/vfx_revision_2026-11-19/ronda3/perfil/03_morir_20.png) | [Caída](capturas/vfx_revision_2026-11-19/ronda3/perfil/03_morir_32.png) | [Suelo](capturas/vfx_revision_2026-11-19/ronda3/perfil/03_morir_44.png) |

`prueba_vfx_revision.gd -- --capturas-vfx --ronda3 --perfil` comprueba en RTX 3070 que la cresta avanza antes de aterrizar, el punto de salpicadura está delante y el nodo mantiene la escala durante la caída. Sin `--perfil` genera la vista oblicua. Las referencias anteriores permanecen en sus carpetas para comparar.

Resultado: los muros largo y alto pasan la prueba gráfica en ambas vistas; la regresión completa de once recetas sin ventana también pasa. **0 fallos y 0 errores de scripts, shaders o motor.** La prueba verifica además que no hay frente trasero visible y que cada efecto se libera al terminar. Se conservan sin editar los scripts del viento aprobado, el magma y el shader de la barrera aprobada.

## Segunda revisión: decisiones del usuario

| Recetas | Estado tras el comentario del usuario |
|---|---|
| Barrera de agua pequeña/grande | **Aprobada visualmente.** Se conserva su efecto. La conexión al contacto real de combate sigue pendiente. |
| Muro de agua largo/alto | Anticipación y nacimiento gradual de la cuarta revisión, movimiento de la segunda y colapso frontal de la tercera; pendiente de aprobación. |
| Géiser bajo/ancho | Se conserva la primera revisión; sin nueva aprobación. |
| Muro, pilar y barrera de magma | **Trabajo pausado por el usuario.** Se conserva la versión del laboratorio sin nuevos cambios. |
| Viento alto | **Aprobado por el usuario.** Se conserva la revisión con más líneas y más velocidad. |
| Viento bajo/ancho | Se conserva la primera revisión; sin nueva aprobación. |

### Muro de agua: nacimiento y movimiento

El nacimiento dura **1,15 s**: primero reúne una lámina con ondas en el suelo; después levanta el cuerpo desde el centro hacia los extremos y termina rizando el labio. Durante la fase activa, dos ondulaciones viajan en sentidos distintos y modifican altura y profundidad del perfil. La espuma y las cortinas comparten las funciones de movimiento y el reloj local del efecto para mantenerse unidas. Se mantiene el rastro simétrico y la rotura hacia delante.

Referencias consultadas para esta propuesta:

- [Gabriel Aguiar — Tsunami Wave Effect](https://www.gabrielaguiarprod.com/product-page/unity-tsunami-wave-effect-nami-s-ult-league-of-legends): referencia visual cercana de ataques con una cresta estilizada y silueta legible.
- [Rinban Academy — Stylized Water & Ocean Combat VFX](https://rinbanacademy.artstation.com/projects/P4e4GB): referencia de dirección artística para movimiento líquido, salpicaduras y ritmo de habilidades de combate.
- [Albmarvil — Stylized Water Shader with Unreal Engine](https://realtimevfx.com/t/stylized-water-shader-with-unreal-engine/11321): desglose del autor con ondas Gerstner; referencia técnica para combinar desplazamiento vertical y horizontal. La implementación del laboratorio usa su propio perfil de ola y ondas sinusoidales, no una simulación Gerstner completa.

La secuencia concreta de acumulación/subida/rizado es una decisión de diseño para este hechizo. Se conservan los colores del agua del proyecto.

### Pilar de viento alto

Se mantienen las hélices existentes con su reloj **×1,55**, y se añaden **18 trazos finos** con fases y grosores distintos que ascienden rápidamente por el interior y la periferia. Durante el apagado, pierden grosor y opacidad conservando la altura. Esta modificación solo se activa en la proporción alta; la columna baja conserva la revisión anterior.

### Capturas y comprobaciones de la segunda revisión

Las capturas anteriores quedan como referencia de la primera ronda. Nuevas secuencias:

| Receta | Nacimiento inicial | Subida | Activa | Movimiento posterior |
|---|---|---|---|---|
| Muro largo | [Lámina](capturas/vfx_revision_2026-11-19/ronda2/02_nacer.png) | [Subida](capturas/vfx_revision_2026-11-19/ronda2/02_nacer_18.png) | [Activa](capturas/vfx_revision_2026-11-19/ronda2/02_activo.png) | [Movimiento](capturas/vfx_revision_2026-11-19/ronda2/02_movimiento.png) |
| Muro alto | [Lámina](capturas/vfx_revision_2026-11-19/ronda2/03_nacer.png) | [Subida](capturas/vfx_revision_2026-11-19/ronda2/03_nacer_18.png) | [Activa](capturas/vfx_revision_2026-11-19/ronda2/03_activo.png) | [Movimiento](capturas/vfx_revision_2026-11-19/ronda2/03_movimiento.png) |
| Viento alto | [Nacimiento](capturas/vfx_revision_2026-11-19/ronda2/09_nacer.png) | [Ascenso](capturas/vfx_revision_2026-11-19/ronda2/09_nacer_18.png) | [Activa](capturas/vfx_revision_2026-11-19/ronda2/09_activo.png) | Revisar en movimiento en el laboratorio |

`prueba_vfx_revision.gd -- --capturas-vfx --ronda2` renderiza estas tres recetas y comprueba el nacimiento, la sincronización de la espuma, el aumento de líneas, su ascenso y que el apagado conserva la altura: **0 fallos y 0 errores del motor/shaders** en RTX 3070. La prueba completa sin ventana también pasa con 0 fallos, incluyendo las barreras aprobadas. No se han editado el efecto de magma ni el shader de la barrera aprobada.

La opción `--ronda2` de `medir_vfx_revision.gd` permite medir únicamente los dos muros y el viento alto, guardando resultados separados de la primera ronda.

Medición corta de la segunda revisión, con el mismo procedimiento de 40 fotogramas de calentamiento y media de 60 a 1280×720, VSync desactivado y RTX 3070:

| Receta | GPU original / segunda revisión (ms) | Fotograma original / segunda revisión (ms) | Dibujos original / segunda revisión |
|---|---|---|---|
| Muro largo | 0,249 / 0,237 | 1,02 / 1,14 | 7 / 7 |
| Muro alto | 0,168 / 0,168 | 0,85 / 0,87 | 7 / 7 |
| Viento alto | 0,048 / 0,060 | 2,49 / 4,52 | 5 / 5 |

[Datos completos de la segunda revisión](capturas/vfx_revision_2026-11-19/ronda2/medidas_rtx3070.json). El viento añade trabajo de generación de cintas por CPU aunque mantiene el número de dibujos; conviene comprobar varias columnas simultáneas antes de integrarlo. El fotograma incluye render y espera: no equivale a tiempo exclusivo de CPU. La medición es de actividad; el nacimiento del agua añade temporalmente un dibujo para la lámina inicial.

## Abrir y comparar

Abrir `laboratorios/LabVfxRevision3D.tscn` y pulsar **F6 en el editor**. La escena vuelve a empezar en la barrera de agua pequeña; F6/F7 recorren las recetas, incluyendo los muros restaurados. Atajos dentro de la ventana:

| Tecla | Acción |
|---|---|
| F6 / F7, o [ / ] | Receta anterior / siguiente |
| F1 | Original / mejoras; conserva figura, dimensiones ajustadas y mandos |
| F2 | Repetir nacimiento con las dimensiones actuales |
| F3 | Golpe lateral de muestra sobre la membrana de agua |
| F4 | Expirar; F2 permite repetir el ciclo |
| F5 | Suelo claro / oscuro |
| F8 | En las recetas de magma: fuego de referencia / magma, a la misma escala |
| C | Cámara de juego / cerca / lejos / libre |
| Tab / Mayús+Tab | Gesto de lanzamiento / cámara lenta |
| U/J, I/K, O/L | Aumentar/reducir X, Y, Z |
| H | Mostrar/ocultar ayuda |

En cámara libre: botón derecho arrastrado gira, rueda acerca/aleja, botón central desplaza. Se conservan los controles y mandos del laboratorio original. Los atajos F1–F8 de esta escena tienen las funciones de la tabla.

## Cambios y recetas

Los valores son los ejes que acepta `definir`, en metros; X/Z son semiejes. En muro/pilar Y representa la altura que ya utiliza el toy. Las capturas de esta tabla usan un fondo neutro y una cámara fija oblicua de diagnóstico; la escena interactiva permite comprobar la cámara normal del juego.

| ID | Receta | X / Y / Z | Cambio | Captura activa |
|---|---|---|---|---|
| 00 | Barrera agua pequeña | 0,85 / 1,10 / 0,85 | Membrana transparente; formación desde el borde, espuma basal, onda local y caída | [Activa](capturas/vfx_revision_2026-11-19/00_activo.png) |
| 01 | Barrera agua grande | 2,40 / 1,80 / 2,40 | Mismo comportamiento y huella elíptica | [Activa](capturas/vfx_revision_2026-11-19/01_activo.png) |
| 02 | Muro agua largo | 3,45 / 1,50 / 0,30 | Flujo ascendente y espuma por tramos; tercera revisión con colapso frontal | [Activa de la primera ronda](capturas/vfx_revision_2026-11-19/02_activo.png) |
| 03 | Muro agua alto | 1,60 / 2,40 / 0,30 | Conserva el perfil y la rotura hacia delante | [Activa](capturas/vfx_revision_2026-11-19/03_activo.png) |
| 04 | Géiser alto | 0,50 / 4,00 / 0,50 | Referencia de regresión: conserva el efecto vigente | [Activa](capturas/vfx_revision_2026-11-19/04_activo.png) |
| 05 | Géiser bajo/ancho | 1,30 / 1,60 / 1,30 | Charco activo menor, falda estrecha y chorro más presente; extensión radial reservada al colapso | [Activa](capturas/vfx_revision_2026-11-19/05_activo.png) |
| 06 | Muro magma | 3,45 / 1,50 / 0,30 | Cuerpo de basalto, material del cráter, calor en fisuras y llamas pequeñas en juntas | [Activa](capturas/vfx_revision_2026-11-19/06_activo.png) |
| 07 | Pilar magma | 0,50 / 4,00 / 0,50 | Bloques solapados, ascenso escalonado y enfriamiento antes de hundirse | [Activa](capturas/vfx_revision_2026-11-19/07_activo.png) |
| 08 | Barrera magma | 1,50 / 1,50 / 1,50 | Perímetro de rocas bajo que deja visible el interior | [Activa](capturas/vfx_revision_2026-11-19/08_activo.png) |
| 09 | Viento alto | 0,50 / 4,00 / 0,50 | Conserva las hélices; disco menos dominante | [Activa](capturas/vfx_revision_2026-11-19/09_activo.png) |
| 10 | Viento bajo/ancho | 1,30 / 1,60 / 1,30 | Cintas ascendentes de grosor alterno, hojas que suben, disco muy tenue | [Activa](capturas/vfx_revision_2026-11-19/10_activo.png) |

Para cada ID se guardan también `ID_nacer.png`, `ID_morir_08.png`, `ID_morir_20.png` y `ID_morir_32.png`: nacimiento y tres momentos del apagado, con el ensayo fijado a 30 fps. Las barreras añaden `ID_golpe.png`. Estas secuencias sirven para revisar etapas, no sustituyen la animación en vivo.

En la primera y segunda ronda, el rastro del muro añadía un reflejo trasero para representar el reparto simétrico descrito en la secuencia. La tercera ronda elimina esa contraola visual al colapsar. No modifica casillas mojadas, simulación ni daño. La equivalencia exacta con casillas del bosque queda pendiente de integración; `huella` sigue siendo una estimación de extensión, no una máscara de todas las casillas.

## Contacto de la barrera

`Lanzador3D.Burbuja.revento(recibido, punto, reaccion)` ya comunica una posición al romperse. En un golpe de enemigo, `absorber()` obtiene esa posición con `punto_hacia(desde)`: proyecta el origen del atacante hacia el contorno horizontal a la altura del centro. No conserva la altura ni la intersección real del golpe. Además, la burbuja de juego revienta al primer impacto.

Por ello la variante ofrece `golpe_en(punto_mundo)` y F3 proporciona un contacto conocido sobre su propia piel. La onda y su localización se pueden juzgar en el laboratorio; no se conecta una reacción persistente al combate ni se cambia la regla de rotura. Para integrar: pasar el contacto de colisión real y sincronizar la reacción con `revento`. La huella del laboratorio sigue sus ejes; su correspondencia con `RADIO_BURBUJA` y `ALTO_BURBUJA` requiere esa integración.

## Validación

- Godot 4.7.2, Vulkan Forward+, NVIDIA RTX 3070: once variantes renderizadas durante nacimiento, actividad y apagado, reconstrucción entre figuras y liberación al terminar; **0 fallos y 0 errores de scripts, shaders o motor** en `prueba_vfx_revision.gd`.
- Comparación original/mejora conservando ejes ajustados y recorrido de las once recetas comprobados por la misma prueba.
- `prueba_magma_toy.gd` y `prueba_viento_tierra_toy.gd`: 0 fallos.
- `prueba_agua_toy.gd`: 0 fallos a velocidad normal con `--max-fps 60`. Con `--fixed-fps 30` tuvo seis fallos de temporización: la prueba mezcla reloj real y avance acelerado. No se modificó para ocultarlos.
- `prueba_haz_gas_viento_rayo.gd` y `prueba_haz_gas_juego.gd` sin ventana: 0 fallos; verifican parámetros y fallback, no certifican el aspecto de gas en GPU.
- `prueba_haz_gas_juego.gd` con GPU, caso `goblin`: 0 fallos de sus comprobaciones; verifica también el máximo de dos dominios, que el tercero usa el toy visible y que daño/largo/choques no cambian. La consola del ensayo existente emite errores `Parameter "material" is null` al manejar materiales; por ello no se declara limpia la regresión gráfica de haces ni se cierran sus locks.
- `prueba_haz_gas_viento_rayo.gd` con GPU y `--sin-costes`: 0 fallos; cubre aire, muro, contacto de viento con cuerpo y destello de rayo. También aparecen errores de material nulo en la consola de este ensayo existente, pendientes fuera de estas variantes de laboratorio.

Comandos reproducibles (sustituir `godot` por la ruta del ejecutable):

```powershell
godot --path . res://laboratorios/LabVfxRevision3D.tscn
godot --headless --path . --fixed-fps 30 --script res://herramientas/prueba_vfx_revision.gd
godot --path . --fixed-fps 30 --script res://herramientas/prueba_vfx_revision.gd -- --capturas-vfx
godot --path . --disable-vsync --script res://herramientas/medir_vfx_revision.gd
```

Las capturas regeneradas y la medición JSON se escriben en `.godot/`, para no sobrescribir las referencias guardadas aquí.

## Coste de renderizado de la primera ronda

Medida de un solo efecto activo, 1280×720, cámara ortográfica de tamaño 6, 40 fotogramas de calentamiento y media de los 60 siguientes, VSync desactivado. Datos completos en [medidas_rtx3070.json](capturas/vfx_revision_2026-11-19/medidas_rtx3070.json). El tiempo de fotograma incluye la espera y el render; no representa tiempo exclusivo de CPU. Son muestras cortas de diagnóstico, no una garantía de fps en el bosque.

| Receta | GPU original / mejora (ms) | Dibujos original / mejora |
|---|---|---|
| Barrera agua grande | 0,304 / 0,074 | 2 / 2 |
| Muro agua largo | 0,212 / 0,214 | 7 / 7 |
| Géiser bajo/ancho | 0,128 / 0,112 | 8 / 7 |
| Muro magma | 0,162 / 0,115 | 13 / 51 |
| Viento bajo/ancho | 0,071 / 0,063 | 7 / 7 |

El muro de magma añade geometría y pequeños efectos de fuego por junta: **51 dibujos frente a 13** en esta muestra. Aunque el coste GPU aislado es bajo, queda pendiente medir varios muros simultáneos sobre vegetación antes de promoverlo al juego.

## Locks y trabajo abierto

| Lock de la secuencia | Referencia / resultado |
|---|---|
| Haces principales | Código y recursos de producción intactos. Pruebas sin GPU pasan; límite de dos dominios y tercer haz con toy comprobados también con GPU. Cierre visual y errores de materiales de los ensayos existentes pendientes. |
| Púas de tierra | Sin cambios; referencia `pinchos_tierra/juego_despues_16h.png` de la secuencia. |
| Muro de tierra | Sin cambios; comprobar cobertura de casillas corto/largo en su escena de juego antes de cerrar. |
| Proyectil y cráter de magma | Material compartido reutilizado sin editar el shader; prueba existente de magma pasa. Vuelo, impacto y enfriamiento conservan su implementación. |
| Géiser alto | Captura ID 04 y ciclo completo incluidos como referencia de regresión. |

La barrera de agua y el pilar de viento quedan aprobados visualmente por el usuario. Siguen pendientes: aceptación del nuevo muro en movimiento y sobre vegetación, precisión del rastro sobre casillas reales y contacto real de barrera. Magma queda pausado por indicación del usuario. Las demás formas mantienen su estado de revisión anterior.

## Flecha de agua e impacto en suelo

Nueva prueba independiente: [VFX_FLECHA_AGUA_LAB_2026-11-19.md](VFX_FLECHA_AGUA_LAB_2026-11-19.md). Lanzador `tools/probar_flecha_agua.cmd`; escena `laboratorios/LabFlechaAgua3D.tscn`. Compara lanzamiento vertical y oblicuo con formación, compresión, salpicadura y depósito persistente. El depósito es visual y aún no se conecta a las casillas del juego.
