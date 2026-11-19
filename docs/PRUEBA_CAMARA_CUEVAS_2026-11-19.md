# Cámara confinada en las cuevas reales

## Alcance

La prueba del bosque se amplía a las cuatro cuevas existentes. Se usan el personaje animado, los materiales, las luces, los objetos y los puzles del proyecto. Las escenas de laboratorio heredan las originales y reconstruyen el nivel desde su mapa TXT (`usar_escena=false`). No sobrescriben escenas, mapas TXT ni niveles horneados editables.

| Laboratorio | Escena original | Salas | Muros exteriores originales → prueba |
| --- | --- | --- | --- |
| `LabCamaraCuevas3D.tscn` | `PruebaCueva.tscn` | 7 | 100 → 27 |
| `LabCamaraCuevaAgua3D.tscn` | `PruebaCuevaAgua.tscn` | 4 | 80 → 20 |
| `LabCamaraCuevaResonante3D.tscn` | `PruebaCuevaResonante.tscn` | 7 | 100 → 27 |
| `LabCamaraGrutaBatida3D.tscn` | `PruebaGrutaBatida.tscn` | 6 | 84 → 23 |

## Comportamiento

- Por defecto el encuadre queda confinado a la sala transitable. Se parte de las áreas de `Zonas3D`, pero se separan C1 y su nicho secreto en dos salas de cámara: la iluminación compartida no debe ampliar el límite de la sala principal. Se elimina el margen lateral exterior y se conserva solo media casilla al norte y un cuarto al sur para la proyección del personaje.
- En los pasillos se libera el límite de sala y se mantiene el límite del mapa. Se interpolan tanto el rectángulo como el foco al cambiar de área; el desplazamiento normal del foco queda limitado a 8 unidades por segundo. Durante el cruce se permite salir del rectángulo de la sala para mantener al personaje completo visible, conservando siempre el límite exterior del mapa.
- El cálculo incluye la altura del foco real: la cámara mira al torso y la intersección del centro de pantalla con el suelo no coincide con los pies.
- El encuadre se limita por eje; el zoom efectivo se acerca si el solicitado no cabe. Se conserva el zoom solicitado para recuperarlo al salir de una sala pequeña o desactivar el bloqueo.
- La variante dispersa retira aproximadamente tres de cada cuatro modelos del **perímetro exterior del mapa**, conservando esquinas y puntos de referencia. Se mantienen las colisiones del borde. Los tabiques entre salas, puertas, agua y objetos de puzle se conservan.
- Las salidas al bosque se desactivan exclusivamente en este laboratorio para no abandonar la prueba accidentalmente. Tab permite cambiar de cueva.
- Se ocultan el texto de depuración de la maqueta y la paleta de runas para despejar el encuadre. F1 permite recuperar la paleta.

## Ejecutar

En CMD:

```cmd
cd /d E:\magic-symbols
tools\probar_camara_cuevas.cmd
```

Para abrir directamente una variante:

```cmd
tools\probar_camara_cuevas.cmd agua
tools\probar_camara_cuevas.cmd resonante
tools\probar_camara_cuevas.cmd gruta
```

Para comparar con el perímetro completo, en otra ejecución:

```cmd
tools\probar_camara_cuevas.cmd cueva completos
```

| Control | Función |
| --- | --- |
| WASD / Mayús | Movimiento habitual / correr |
| F6 | Activar o desactivar el bloqueo de cámara |
| Mayús + F6 | Alternar límites por sala / mapa completo |
| Tab | Siguiente cueva: principal → agua → resonante → gruta |
| RePág / AvPág | Sala anterior / siguiente; busca una casilla seca y transitable |
| Inicio | Volver a la entrada inicial |
| Fin | Preparar el recorrido al borde oeste con límite por sala y zoom 6 |
| Insert | Mostrar u ocultar las guías: cian = encuadre permitido; dorado = recorrido permitido del foco |
| + / - | Zoom habitual del juego |
| F1 | Mostrar u ocultar la paleta de runas |

Recorrido de revisión v3: **cerrar la ventana anterior y relanzar el CMD**. El panel debe indicar «CÁMARA v3». Pulsar **Fin** y mantener **A** hacia la izquierda: el panel pasa a **X: BLOQUEADA**, la coordenada X de cámara deja de cambiar y el personaje continúa andando antes de tocar el muro. Pulsar F6 para comparar. AvPág y Tab permiten revisar otras salas y cuevas. Recorrer también las puertas y pasillos a pie; Mayús + F6 compara el cierre por sala con el del mapa completo.

### Por qué el límite anterior no se apreciaba

Se usaban directamente las áreas de iluminación, que en C1 incluyen también el nicho situado tras la pared sur, y se añadía una casilla completa de margen. El personaje podía llegar al muro antes que la cámara al límite. Además, el texto «bloqueo SÍ» indicaba que la opción estaba habilitada, no que un eje estuviera efectivamente detenido.

La verificación anterior con teletransportes confirmaba que el encuadre cabía, pero no que la cámara se frenase antes de la colisión. Se añade ahora una regresión con las acciones reales de movimiento y las colisiones del personaje, comparando el mismo trayecto con y sin límite. En la revisión v2 renderizada a 1280 × 720 y 30 FPS: **96 fotogramas y 5,08 unidades de personaje avanzando con la cámara quieta en X**, frente a un único fotograma aislado en la comparación sin límite. Las imágenes `Cueva_bloqueada_1.png` y `Cueva_bloqueada_2.png` muestran el fondo fijo y al personaje en dos posiciones distintas.

## Implementación y comprobaciones

### Continuidad entre salas (v3)

Se añade un recorrido con movimiento real desde C1 a C2 por la puerta norte y de vuelta. La prueba abre la puerta en su instancia, sin cambiar el mapa ni el estado guardado. Antes de la corrección detectó 13 fotogramas con parte del personaje fuera de pantalla y un desplazamiento de cámara de 2,174 unidades en un fotograma.

La corrección suaviza el foco además del rectángulo y protege la proyección de pies y cabeza **antes** de que los pies cambien de sala: la cabeza atraviesa el encuadre del umbral primero. En la comprobación a 30 FPS sin ventana, el recorrido cruza las áreas `[C1, pasillo, C2]`, regresa a C1, mantiene al personaje completo visible en todos los fotogramas y reduce el máximo desplazamiento por fotograma a **0,267 unidades**. La cueva principal pasa **308 comprobaciones sin fallos**.

La verificación final de v3 con renderizado Forward+ a 1280 × 720 pasa **1.066 comprobaciones, 0 fallos**, en las cuatro cuevas, incluidas seis capturas. El recorrido del pasillo mantiene el personaje completo en pantalla y el máximo desplazamiento de 0,267 unidades por fotograma. El recorrido del borde conserva 90 fotogramas y 4,76 unidades de avance del personaje con la cámara detenida en X; sin límite solo hay un fotograma aislado.

`laboratorios/lab_camara_cuevas_3d.gd` hereda la maqueta del juego y añade únicamente el comportamiento de esta prueba. `camara_bordes_bosque.gd` incorpora el cálculo relativo a un foco elevado; su comportamiento anterior se conserva.

`herramientas/prueba_camara_cuevas.gd` monta las cuatro escenas con sus puzles. Comprueba nueve posiciones por sala, encuadre dentro de sala y mapa, pies y cabeza del personaje dentro de pantalla, colisiones exteriores, densidad de muros, controles de comparación, salidas desactivadas y límite de zoom. Durante el recorrido automático los enemigos permanecen quietos para que sus golpes no desplacen al personaje; en la prueba jugable mantienen su comportamiento habitual.

La revisión v2 completa pasó **1.061 comprobaciones, 0 fallos** en las cuatro cuevas, incluyendo el recorrido caminando con y sin bloqueo y seis capturas. La cueva principal sin ventana también pasó 303 comprobaciones sin fallos. Los resultados de 1.002 comprobaciones de la versión inicial cubrían encuadres estáticos y no detectaban el problema anterior. La regresión previa del laboratorio de bosque pasó 2.094 comprobaciones sin fallos.

Las capturas de las cuatro cuevas están en `docs/capturas/camara_cuevas/`. La cámara del bosque y las cuevas de producción no se modifican. Se mantienen avisos de recursos del renderizador al cerrar las escenas originales; no se han observado errores de script durante el recorrido verificado.

Para repetir las comprobaciones en este PC:

```cmd
"C:\Users\pablo\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --fixed-fps 30 --path "E:\magic-symbols" --script res://herramientas/prueba_camara_cuevas.gd
```

Para generar las imágenes, quitar `--headless` y añadir `-- --capturas` al final. Para verificar solo la principal con todos sus muros, añadir `-- --muros-completos --solo-principal`.
