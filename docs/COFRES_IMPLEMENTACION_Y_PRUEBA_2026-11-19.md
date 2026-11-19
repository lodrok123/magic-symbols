# Cofres: implementación y prueba

19/11/2026. Implementación conectada a los cofres de CofrePuzle y laboratorio independiente disponible.

## Travelling y presentación con confirmación

Actualización solicitada: después de abrir, una cámara de ceremonia independiente recorre una órbita de 55 grados alrededor del personaje mientras se acerca durante 0,85 s. La trayectoria es curva, con el personaje como centro, y termina en un encuadre cercano de su rostro y la recompensa. Se congela ese plano y se muestra el nombre del objeto con el botón Continuar. La presentación espera indefinidamente: no tiene cierre automático.

Se continúa con una pulsación nueva de E, Espacio, Intro, el botón A del mando o un clic en Continuar. La repetición automática de una tecla mantenida no confirma. La espera mantiene bloqueado el control de movimiento y no repite la entrega de recompensas.

En el legendario se presenta primero la runa completa. Al confirmar se abre el libro, la runa entra en su página y queda inscrita; después se cierra el libro y la cámara regresa suavemente al juego. El libro permanece oculto durante la espera para no tapar la recompensa. El guion legendario dura aproximadamente 5,35 s más el tiempo que el jugador permanezca mirando el objeto. En el épico, la cámara vuelve al confirmar con una transición de 0,65 s.

La cámara de juego conserva su seguimiento y parámetros: durante la ceremonia se usa otra Camera3D, por lo que ese seguimiento no arrastra el plano de presentación. El modo de efectos reducidos también conserva la espera, con la cámara fija sin travelling.

La protagonista mantiene la mirada hacia el cofre desde antes de iniciar el gesto, durante la órbita y al presentar la recompensa. La órbita mueve exclusivamente la cámara: no gira al personaje para que mire al objetivo. El laboratorio vuelve a orientar el personaje al cofre cada vez que se reinicia o repite; se usa Pj3D.mirar para mantener también coherente su orientación interna.

## Assets

No se necesita descargar material para ejecutar esta versión. Se han creado localmente:

- Estrellas de cinco puntas y placa frontal: 1 plateada, 2 violetas o 3 doradas.
- Libro articulado con lomo, dos tapas, bloques de páginas y una página receptora de runas.
- Abanico de luz, aro de trazos, onda en el suelo y estela del vuelo.

El libro de ceremonia usa geometría sencilla generada por código y colores correspondientes a los tres niveles del grimorio. No reproduce todavía el detalle escultórico y las texturas de las mallas Meshy. Es una versión funcional animable: para igualar exactamente el arte original habría que reconstruir esas tapas y páginas a partir de los modelos fuente. Esto no bloquea la apertura, el vuelo ni la inscripción.

Se reutilizan los modelos de cofre, las texturas de runas reales, el gesto AbrirCofre, Opening_A_Lid y los sonidos del proyecto. Las piezas épica y legendaria no tienen clips de tapa: usan el giro por código que ya admite Cofre3D.

## Qué cambia en juego

- Cofres comunes: conservan su apertura y añaden una estrella.
- Cofres épicos: dos estrellas violetas, gesto corto, luz violeta y presentación hasta confirmar.
- Cofres con runa: presentación hasta confirmar, libro abierto en el mundo 3D, runa viajando por una curva, conversión de luz a tinta sobre la página y cierre del libro.
- Cofres legendarios sin runa: presentación de objeto con color y tres estrellas doradas, sin inventar una runa.
- Se retira el fogonazo blanco de pantalla completa de la ceremonia legendaria.
- El libro normal del cinto o de la mano queda oculto mientras actúa su representación articulada y recupera su estado después.
- El director coordina la entrega de botín y el desbloqueo; saltar o interrumpir no repite recompensas. La columna de rareza se apaga al comenzar.
- Las tablas de botín se resuelven una vez para que la recompensa presentada coincida con lo concedido. Si hay varios objetos se presenta el primero y se entrega la lista habitual completa.
- Para objetos sin icono se muestra una moneda en el caso del oro y una esfera del color del objeto en los demás casos, junto a su nombre.

## Abrir la prueba

Desde CMD:

```bat
cd /d E:\magic-symbols
tools\probar_cofres.cmd
```

O abrir laboratorios/LabCofresCeremonia3D.tscn en Godot y pulsar F6.

Controles:

| Control | Acción |
|---|---|
| Común / Épico / Legendario | Elegir modelo y categoría |
| Abrir / repetir, o Espacio | Ejecutar la apertura; durante la presentación, Espacio confirma |
| E / Espacio / Intro / A / Continuar | Confirmar la presentación y seguir la ceremonia |
| Saltar apertura / continuar presentación | Saltar el arranque en el laboratorio o confirmar si ya se muestra el objeto |
| Reiniciar, o R | Cancelar y volver al cofre cerrado |
| Libro 1 / 2 / 3 | Elegir apariencia de la próxima ceremonia |
| Mixamo completo | Comparar Opening_A_Lid sin sustituir el gesto del juego |
| Contacto Mixamo | Ajustar el momento de abrir la tapa |
| Efectos reducidos | Cámara fija y sin abanico, aro, onda ni estela |
| Deslizador | Velocidad de la simulación; se restaura al salir |
| Cámara | Tres cuartos, frontal o elevada |
| Ocultar personaje | Revisar las estrellas sin que la protagonista las tape |

El laboratorio no concede objetos ni escribe flags de progreso. Para la primera visión conviene dejar Mixamo desactivado y elegir Legendario. En juego se conserva la regla de salto a partir de haber visto una ceremonia legendaria.

La confirmación del objeto está disponible también la primera vez; es independiente de la regla de saltar la apertura. Para revisar el plano fijo, no pulses hasta haber comprobado la recompensa.

## Animación Mixamo

Opening_A_Lid dura 8,933 s. Medición sobre el clip traducido a jugadora_base, a 30 muestras por segundo: punto más bajo medio de ambas manos a los 1,767 s, altura aproximada de 0,349 unidades con protagonista de altura 1. Esta medida proporciona el contacto inicial de 1,77 s del comparador; no garantiza por sí sola el contacto geométrico con todos los cofres.

El gesto usado en juego sigue siendo AbrirCofre, con el instante de manos ya definido en Pj3D. Mixamo completo es una alternativa de revisión más larga; no se ha añadido un recorte destructivo ni se han cambiado sus roles globales.

## Archivos principales

| Archivo | Función |
|---|---|
| presentacion/cofre_estrellas_3d.gd | Placa y emblemas por calidad |
| presentacion/libro_ceremonia_3d.gd | Geometría articulada, página y tinta |
| presentacion/cofre_ceremonia_vfx_3d.gd | Abanico y aro que se dibuja |
| objetos/ceremonia_cofre_3d.gd | Director común, vuelo, cámara, luz, audio y cierre |
| objetos/secuencia_cofre_legendario_3d.gd | Conserva el nombre público anterior heredando el director |
| presentacion/cofre_3d.gd | Estrellas, color, gesto externo y cancelación de tweens |
| jugador/pj_3d.gd | Cesión y restauración del libro sin acceso externo a sus tweens |
| escenas/puzle.gd | Selección de ceremonia, botín estable y entrega única |
| laboratorios/LabCofresCeremonia3D.tscn | Escena para revisar el resultado |

## Validación

Pruebas ejecutadas con Godot 4.7.2:

- prueba_cofres_ceremonia: recursos reales, estrellas, inscripción 3D, entrega única, salto/cancelación, tres libros, cesión desde cinto/mano y botín real de CofrePuzle.
- prueba_cofres_cueva: montaje en PruebaCueva, vuelo, libro, progreso y restauración de control/cámara.

La ampliación de estas pruebas comprueba travelling con desplazamiento real, espera sin cierre automático, cámara inmóvil aunque cambie la de juego, rechazo de teclas mantenidas y continuación por evento de teclado real en la cueva. Los scripts de captura y escenarios que recorrían la secuencia automáticamente ahora confirman explícitamente su presentación.
- prueba_cofre_cerrado y prueba_cofre_estados: apertura y estados anteriores.
- prueba_mixamo_clips: retarget y alternativas existentes.
- escenario_cueva_pulso: regresión completa del nivel. Se actualizó la comprobación de la página 2D a libro 3D y se separaron los pulsos del jugador de los de la fuente autónoma en la prueba del prisma.

Capturas del motor en docs/capturas/cofres_ceremonia/ y docs/capturas/cofres_cueva/. Las capturas de revisión se generaron con Compatibility; la cueva avisa de que SSAO/AA de pantalla requieren otro renderizador. No se ha cambiado el renderizador configurado en el proyecto.

Para repetir la prueba nueva sin ventana:

```bat
tools\Godot_v4.7.2-stable_win64.exe --headless --path . --script res://herramientas/prueba_cofres_ceremonia.gd
tools\Godot_v4.7.2-stable_win64.exe --headless --fixed-fps 30 --path . --script res://herramientas/prueba_cofres_cueva.gd
```

## Correspondencia con el plan

A01 laboratorio, A02 calibración, A03 estrellas, A04 libro, A05 cesión del libro, A06 épico, A07 legendario, A08 VFX, A09 audio, A10 entrega/restauración, A11 pruebas y A12 conexión con CofrePuzle están implementados. La apariencia exacta del libro Meshy queda como trabajo de acabado artístico; la estructura animable y las tres paletas están disponibles.
