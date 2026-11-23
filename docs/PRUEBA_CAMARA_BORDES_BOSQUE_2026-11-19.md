# Prueba de cámara en bordes de bosque y cueva

## Revisión del planteamiento

No se ha localizado en los documentos de esta copia una propuesta específica de bloqueo de cámara por bordes. La cámara actual de `presentacion/prueba_test2.gd` sigue al personaje con interpolación y adelanto, sin confinar el encuadre al nivel. Esta prueba concreta el comportamiento solicitado en un laboratorio independiente.

La cámara se detiene cuando **el borde de su encuadre sobre el suelo** alcanza el límite visual de la zona. No esperamos a que el personaje toque una pared. Se bloquea únicamente el eje que alcanza el límite: junto al borde este sigue habiendo seguimiento norte/sur. En una esquina pueden detenerse ambos ejes. Al volver al interior recupera el seguimiento, sin salto ni rebote.

## Diseño con poco decorado

Hay dos maquetas, alternadas mediante Tab:

| Zona | Suelo visible | Decorado principal |
| --- | --- | --- |
| Claro de bosque / boca de cueva | 36 × 28 unidades | Tres árboles separados, boca de cueva del catálogo y camino |
| Interior de cueva | 20 × 16 unidades | Dos tramos cortos de pared al fondo, tres rocas y marca de acceso |

Se conserva la inclinación del bosque real: 60° desde la vertical, cámara ortográfica y zoom inicial 6.

El suelo visible y la zona transitable son distintos. Se reserva una banda escénica de **4 unidades** alrededor de la zona transitable. Con esta inclinación, la altura del personaje se proyecta hacia arriba en pantalla: limitar únicamente el suelo cortaba el sombrero en el borde norte. El margen permite mostrar al personaje completo sin levantar una barrera continua de árboles o paredes.

Esta banda todavía es suelo sencillo: no necesita contener objetos altos. La maqueta representa los límites físicos mediante colisiones invisibles y usa un personaje geométrico de referencia. En el nivel definitivo el límite transitable debe corresponder a terreno, desnivel, roca u otro cierre que se entienda. El bloqueo de cámara resuelve el encuadre; no sustituye el diseño de la colisión.

## Ejecutar y comparar

En CMD:

```cmd
cd /d E:\magic-symbols
tools\probar_camara_bosque.cmd
```

También se puede abrir `laboratorios/LabCamaraBosque3D.tscn` en Godot y pulsar F6.

| Control | Función |
| --- | --- |
| WASD / Mayús | Caminar / correr |
| Tab | Alternar claro de bosque e interior de cueva; reinicia posición |
| L | Activar/desactivar el bloqueo y comparar |
| 1 | Centro |
| 2 / 3 | Oeste / este |
| 4 / 5 | Norte / sur |
| 6 / 7 | Noroeste / noreste |
| 8 / 9 | Suroeste / sureste |
| + / - | Acercar / alejar |
| F2 | Guías: naranja = suelo visible, verde = límite transitable, cian = encuadre sobre el suelo |
| R | Reiniciar la zona actual |
| Esc | Cerrar |

Recorrido recomendado: 1 → 3; caminar norte/sur junto al borde este; 7 para comprobar la esquina; L para comparar; volver al centro; Tab y repetir dentro de la cueva. Alejar el zoom y redimensionar la ventana para comprobar que la vista sigue cabiendo.

## Implementación

- `laboratorios/camara_bordes_bosque.gd`: calcula la huella del encuadre intersectando las cuatro esquinas de la cámara con el plano del suelo. Tiene en cuenta inclinación, giro y formato de ventana. Limita el foco con esa huella, no con una distancia fija al personaje.
- El foco deseado se limita antes de interpolar; se vuelve a limitar después para mantener el encuadre dentro al cambiar el zoom o la ventana. Suavizado exponencial independiente de los FPS.
- Si el zoom solicitado no cabe en la sala, se acerca hasta que quepa; se conserva el zoom solicitado para recuperarlo cuando vuelva a haber espacio. El HUD muestra ambos valores.
- `laboratorios/lab_camara_bosque_3d.gd` y su escena: movimiento, dos zonas, comparación y puntos de revisión.
- `tools/probar_camara_bosque.cmd`: lanzamiento con el Godot local.
- No cambia mapas, `project.godot` ni la cámara de producción. Tab cambia de maqueta: no prueba una transición continua entre exterior e interior ni secuencias de cofres, adelanto o temblores de la cámara real.

## Verificación

`herramientas/prueba_camara_bordes_bosque.gd` comprueba formatos 16:9, 4:3, ultrapanorámico y vertical; giros 0°, 90° y 37°; varios zooms; ambas zonas y una sala de 4 × 4. Incluye bordes, esquinas, suavizado al cambiar de encuadre, bloqueo por eje, liberación al regresar, ausencia de deriva y visibilidad completa del personaje en los nueve puntos de ambas maquetas.

Resultado con Godot 4.7.2 y renderizado Forward+ en RTX 3070: **2.096 comprobaciones, 0 fallos**, incluidas dos capturas guardadas. Las capturas de referencia están en `docs/capturas/camara_bordes/`. Sin capturas son 2.094 comprobaciones.

Para repetir sin ventana en este PC:

```cmd
"C:\Users\pablo\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path "E:\magic-symbols" --script res://herramientas/prueba_camara_bordes_bosque.gd
```

Para repetir con imágenes, quitar `--headless` y añadir `-- --capturas` al final.
