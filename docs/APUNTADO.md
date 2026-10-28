# El aspecto del apuntado

28/10/2026 · contexto JUEGO · **dos tandas hechas y probadas** (la segunda: cursor y fantasma); falta el visto bueno de Pablo a las fotos.

- **Código:** `presentacion/apuntado_3d.gd` (`Apuntado3D`), montado por `Lanzador3D._crear_marcadores` / `_pintar_previsualizacion` / `_poner_cursor`.
- **Prueba:** `herramientas/prueba_apuntado.gd` (56 comprobaciones, 0 fallos).
- **Fotos:** `herramientas/captura_apuntado.gd -- <carpeta>` (con ventana). En `docs/capturas/apuntado/antes/` y `despues/`, con los mismos casos.
  - Falta el «antes» de la foto 3, porque el caso se cambió después. Las fotos 8 a 10, las de los fantasmas, solo tienen «después».
  - El cursor del sistema no sale en una captura: el script lo pinta encima, en el punto apuntado.

## Segunda tanda: cursor y fantasma

- **Cursor.** Mientras se apunta, el ratón es una **retícula del color del elemento** (anillo, cuatro marcas y un punto, con contorno oscuro); en rojo y con X si no se lanzaría. Al salir vuelve el del sistema.
  - Es un cursor del sistema (`Input.set_custom_mouse_cursor`), así que va sin retraso.
  - Solo se cambia cuando cambia el color o el estado (`Lanzador3D.cursor_puesto`).
- **Fantasma.** Lo que nace y se queda (las barreras de fuego, tierra, hielo o agua…) enseña una **cúpula translúcida en cada casilla que ocupará**, con la textura viva de su elemento: llamas que suben, ondas, facetas que destellan, chispas, vetas, piedra a trozos.
  - Sale de lo que el hechizo anunciaría a su dibujo (`hechizo_v2`), guardado en seco (`PrevisionHechizo.ultimo_recorrido.volumenes`): es el mismo sitio y las mismas casillas.
  - No es el VFX real, porque ese anima, suena y caduca. Es su silueta.
  - Un proyectil o un haz no dejan fantasma: ya se ven su recorrido y su retícula.

## Qué fallaba (fotos de `antes/`)

| problema | por qué confundía |
|---|---|
| la flecha era una barra recta de largo fijo | no decía por dónde va el hechizo ni dónde se para: atravesaba enemigos y paredes, y la flecha de tierra vuela en arco |
| una caja bajo la jugadora con cualquier proyectil | parecía que el hechizo «caía» en ella; era la caja del cuerpo del proyectil en el origen |
| el color de la runa | la tierra (parda) no se veía sobre la tierra; todo era plano y sin contorno |
| la barrera era una alfombra | igual que las casillas de cualquier otro hechizo |
| el anillo de alcance (3 casillas) salía siempre | solo limita a lo que nace donde apuntas |
| el rayo en línea no enseñaba el haz | solo una caja en la jugadora |
| tres copias se veían como una | |

## Qué hace ahora

- **El recorrido real.** El vuelo en seco de A2 (`HechizoVivo.prever` guarda los puntos en `caminos`) se dibuja como una **cinta con galones que avanzan** hacia donde va. Sigue el arco, se para donde choca o cae y se dibuja una vez por copia.
- **La sombra punteada** en el suelo, cuando el recorrido va por el aire (más de 0,35 u). Así se lee la distancia en la vista isométrica.
- **Una retícula** (anillo con cuatro marcas) donde acaba cada recorrido. Con varias copias, más pequeñas.
- **El haz** (rayo + ᛁ) dibuja su recta de la mano a la punta. Lo que nace donde apuntas (barrera) lleva un **hilo** desde la jugadora hasta el origen.
- **Las casillas de lo que no vuela** son un **fantasma**: aristas marcadas, contorno oscuro, relleno suave y el alto real. Un proyectil ya no enseña cajas.
- **Colores propios del indicador** (`Apuntado3D.COLORES`), más vivos que los de las runas, y un **contorno oscuro** en todo.
- **El anillo de alcance**, de guiones que giran despacio, solo con lo que nace donde apuntas. Si se apunta más lejos, el origen se queda en el borde.
- **«No se puede»** (un sólido que no cabe, o fuera de alcance): todo en rojo rayado, una retícula con X y el motivo escrito encima, **antes** de soltar. Antes solo se avisaba al soltar.
- Todo late suavemente. Los nodos se reutilizan: pintar cada fotograma no crea nada.

Sin reglas nuevas: el recorrido es el mismo vuelo que A2 compara con el real. Las previsiones de A2 (170) y A3 (51) siguen a 0 fallos.

## Ideas para las siguientes tandas (por decidir)

1. ~~El cursor del ratón como retícula~~ **hecho**.
2. ~~El fantasma del hechizo en el destino~~ **hecho** (como silueta con textura; el VFX real queda descartado por ahora).
3. **El rebote** (A4): como el vuelo en seco simula los rebotes, la línea quebrada debería salir sola, pero no está comprobado. Falta probarlo, poner una marca en cada rebote y añadir un caso de prueba.
4. **Enfoque al apuntar:** con el tiempo lento, oscurecer y desaturar un poco los bordes de la pantalla (viñeta). El indicador resaltaría sin hacerlo más grande.
5. **Coste en la barra de tinta:** al apuntar, el trozo que se gastará parpadea en la barra (y en rojo si no llega).
6. **Sonido del apuntado:** un zumbido suave del elemento mientras se apunta, y un «clic» al pasar sobre algo que reacciona (A3).
7. **Imán suave** (A5, mando): la retícula se pega al enemigo más cercano en ±10°.
8. **Alcance de la flecha:** hoy se ve dónde acaba; también podría verse un arco tenue del alcance máximo en la dirección del ratón.

## Para el playtest

- La velocidad de los galones (`CODIGO_CINTA`, `TIME * 1.4`) y el pulso (`sin(TIME * 4.0)`): si cansan, se bajan.
- El grosor de la cinta (`ANCHO_CINTA`, 0,26 u) y de la retícula con la cámara de juego.
- Con varias copias en el mismo sitio las retículas se solapan aunque sean pequeñas.
- El cursor, a tamaño real (48 px), en la pantalla de Pablo: si se ve pequeño, se sube `TAM_CURSOR`.
- La fuerza del fantasma (`CODIGO_FANTASMA`: alfa 0,06 + 0,5 × textura + 0,55 × borde). El agua y el viento son los que menos textura enseñan.
- El fantasma de una barrera de un nivel mide media casilla de alto. Hay que comprobar que coincide con lo que sale de verdad.
