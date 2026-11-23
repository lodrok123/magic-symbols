# Secuencia de mejoras para los VFX de hechizos

La referencia es el haz volumétrico a cámara de juego. En cada forma buscamos un cuerpo que se distinga de un vistazo, movimiento que revele el material y una respuesta legible al contacto o al apagado. Mediremos el resultado en la misma escena, con la misma cámara y la misma receta antes y después.

## 0. Fijar la referencia y los locks propuestos

| VFX | Decisión propuesta | Comprobación pendiente |
|---|---|---|
| Haces volumétricos de fuego, agua, viento y rayo | Congelar el aspecto del haz principal. | Comprobar el contacto de viento con un enemigo aislado y el aspecto del tercer haz simultáneo cuando se agotan los dos dominios de gas. |
| Haz de púas de tierra | Dar por cerrado su arte. | Usar las capturas aprobadas del bosque como referencia de regresión. |
| Muro de tierra | Congelar geometría y silueta. | Comprobar que el dibujo cubre las casillas sólidas en tamaños corto y largo. |
| Proyectil y cráter de magma | Congelar su diseño y usar la roca del cráter como referencia de material. | Confirmar vuelo, impacto y enfriamiento a cámara normal antes del cierre. |
| Géiser alto de agua | Congelar dirección artística y colapso. | Confirmar en movimiento. La variante baja y ancha se trabaja en el paso 3. |

Referencias del repositorio en [la matriz de cobertura](VFX_MATRIZ_COBERTURA_2026-11-13.md), [púas en el bosque](capturas/vfx_en_juego/pinchos_tierra/juego_despues_16h.png) y [el haz contra el muro](capturas/vfx_en_juego/haz_gas_toon/toon_muro_juego_3s.png).

## 1. Barrera de agua

**Estado de revisión 19/11:** el usuario aprueba el aspecto de las barreras pequeña y grande del laboratorio. Se conserva esta versión; la integración del contacto de combate continúa pendiente.

- Sustituir el elipsoide provisional de `AguaToy` por una membrana con flujo superficial y espuma concentrada en el borde inferior. Reutilizar los recursos del muro donde encajen. Mantener visible lo que ocurre dentro.
- Resolver por orden formación desde el borde, respuesta a un golpe lateral y caída de la membrana al expirar. Para el golpe, localizar primero qué señal de juego proporciona un punto de contacto real. Si falta, dejar la reacción pendiente de ese dato.
- Cerrar cuando la huella concuerde con la protección real, el punto de impacto se pueda localizar por la onda y la caída se distinga del estado activo. Comprobar barrera pequeña y grande, en reposo y recibiendo un golpe.

## 2. Muro de agua

**Segunda revisión 19/11:** nacimiento de 1,15 s con acumulación, subida y rizado; ondulaciones de altura y profundidad compartidas con la espuma. Referencias, capturas y resultados en [el registro del laboratorio](VFX_REVISION_LAB_2026-11-19.md). Pendiente de aprobación visual.

**Tercera revisión 19/11:** colapso frontal de 2,2 s: la cresta adelanta, el labio cae primero y el cuerpo la sigue hasta una salpicadura delantera. Se suprime la contraola visual trasera al expirar. Se conservan la simulación de agua y el daño. Pendiente de aprobación visual del muro.

**Cuarta revisión 19/11:** nacimiento de 1,65 s, con 0,30 s iniciales de anticipación mediante ondas bajas sin levantar el muro. Después crece paulatinamente desde el centro a los extremos y forma la cresta. Conserva el colapso frontal de la tercera revisión. F2 permite repetir desde cero.

**Quinta revisión 19/11, rechazada y revertida:** la propuesta de volumen único se retira por petición del usuario. Se restaura la cuarta revisión: anticipación de 0,30 s, nacimiento de 1,65 s y colapso frontal de 2,2 s. La barrera y el viento aprobados se conservan; magma continúa pausado.

- Mantener la rotura hacia delante del 16/11. Hacer visible el flujo ascendente y variar por tramos el momento y la cantidad de espuma de la cresta.
- Comparar el frente de espuma con el agua real en la cámara de juego. Hoy se dibuja una lámina hacia delante y el agua se reparte de forma simétrica. Ajustar la lectura del rastro al área real. Si se quiere cambiar el reparto del agua, tratarlo como un cambio de jugabilidad.
- Cerrar cuando se distingan subida, fase activa y rotura, tanto en el muro largo habitual como en la variante alta. Comparar vista normal y lateral con las capturas de `captura_muro_agua.gd` y `captura_rastro_agua.gd`.

## 3. Géiser bajo y ancho

- Ajustar la relación entre el chorro y el charco en esa proporción. Dar más peso al flujo vertical junto al origen y reservar la extensión mayor de la lámina para el colapso.
- Cerrar cuando todavía se lea como géiser antes de caer y el charco gane protagonismo al terminar. Comparar las dos proporciones con `captura_pilar_agua.gd` y comprobar el ciclo con `prueba_agua_toy.gd`.

## 4. Magma persistente

**Pausado por el usuario el 19/11.** Se conserva la primera versión del laboratorio sin nuevos cambios de magma.

1. **Muro.** Construir primero el material compartido con roca oscura, fisuras al rojo y llamas localizadas en las juntas. Usar el cráter existente como referencia de color y enfriamiento.
2. **Pilar.** Reusar ese material en una masa vertical. Hacer que el ascenso y las fracturas comuniquen peso.
3. **Barrera.** Reusar el material en un perímetro de roca que marque el límite y mantenga visible el interior desde la cámara de juego.

Cerrar cada forma por separado cuando se distingan el cuerpo rocoso, el calor localizado y el apagado, y la silueta siga la huella del hechizo. Comparar fuego y magma con la misma figura y tamaño. Revisar `prueba_magma_toy.gd` y comprobar visualmente el proyectil, el cráter y las púas tras los cambios en recursos compartidos.

## 5. Pilar de viento

**Segunda revisión 19/11:** solo en el pilar alto, hélices a ×1,55 y 18 trazos ascendentes adicionales. La variante baja conserva la revisión anterior. **Pilar de viento aprobado por el usuario** tras esta revisión; conservar el efecto actual.

- Comparar primero las proporciones alta y baja con `captura_pilar_viento.gd`. Conservar las hélices de la alta si se leen en movimiento. En la baja, usar cintas de distinto grosor y hojas que suban siguiendo el mismo flujo. Reducir el peso visual del disco si compite con la corriente.
- Cerrar cuando la dirección ascendente se reconozca también en la variante baja y el apagado conserve la altura mientras pierde fuerza.

## 6. Verificación y cierre

- Comparar los cambios a cámara normal durante el ciclo completo. Usar el bosque para lectura sobre vegetación y un fondo oscuro para comprobar el contraste. Añadir vista lateral cuando ayude a verificar espesor o contacto.
- Ejecutar las pruebas existentes de cada familia tocada. Para los haces, usar `prueba_haz_gas_viento_rayo.gd` y `prueba_haz_gas_juego.gd`, y comprobar en una sesión gráfica el enemigo aislado, el tercer haz y la variante sin gas. Registrar el rendimiento en la 3070 si se cambia el coste de renderizado.
- Registrar para cada lock la receta, la captura de referencia y el resultado de las comprobaciones. Mantener abiertos los fallos concretos de contacto, legibilidad o rendimiento.

Esta secuencia parte de la revisión del código y las capturas existentes, incluidas las del 16/11. Queda pendiente comprobar la animación y el rendimiento en una instalación funcional de Godot.

## Implementación de revisión en el laboratorio (19/11)

Las variantes de los pasos 1–5 están en `laboratorios/LabVfxRevision3D.tscn`. Abrir la escena y pulsar F6 en el editor. Dentro, F6/F7 recorren once recetas, F1 compara original/mejora conservando los ejes, F2 repite, F3 muestra un golpe lateral de agua y F4 inicia el apagado. F8 compara magma/fuego con la misma geometría. C conserva las cámaras del laboratorio anterior y Tab permite revisar el gesto.

Se implementan como subclases dentro de `laboratorios/vfx_revision/`: el juego y el laboratorio original siguen usando los recursos vigentes. Los locks artísticos permanecen abiertos hasta la revisión visual. Registro de recetas, capturas, comprobaciones y límites: [VFX_REVISION_LAB_2026-11-19.md](VFX_REVISION_LAB_2026-11-19.md).
