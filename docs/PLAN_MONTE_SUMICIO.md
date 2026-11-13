# Plan de nivel · Monte Sumicio

## Estado de partida

Revisión sobre `a6d20abb`. `154d64b5` incorporó el mapa, la maqueta de la aldea, la primera visita, los interiores de palloza y la tienda con síntesis. `fed0fa62` añadió las puertas animadas, los suelos de la aldea y el cofre épico del uniforme. `cddbef70` corrigió el pelo visible a través de la capucha roja.

**Primera visita completada, según la confirmación de Pablo.** Mid sube desde la Fraga con el grimorio de Leonardo, sigue al guardia hasta Marimanta, completa la audiencia, recoge el uniforme, usa un servicio de la aldea y vuelve a la Fraga. Este recorrido es la referencia para probar regresiones cuando se añadan las asignaturas y se amplíe la Torre.

| Ya montado | Trabajo pendiente |
| --- | --- |
| Subida desde la Fraga, portón, guardia y escolta hasta la audiencia | Acabado visual de la subida y lectura de la Torre desde el sendero. |
| Audiencia y admisión de Mid | Ampliar la Torre con espacios de estudio, biblioteca y celdas. Incorporar el modelo animado de Marimanta donde se use una figura provisional. |
| Tres interiores familiares, tienda del este y síntesis. Brais propone combinar seta asada y baya. | Dar función propia a la palloza del gremio y ampliar los servicios con descanso y prácticas de obrador. |
| Cofre del uniforme, equipamiento automático, Vestuario y autoguardado | Resolver permisos de alumna, efectos del atuendo equipado y comportamiento de partidas que ya lo compraron a la librera. |
| Ida y vuelta de la primera visita | Añadir encargos de campo y evaluaciones al regreso a la Torre. |

## Recorrido propuesto

1. **Subir desde la Fraga.** El camino estrecho deja atrás helechos y musgo, pasa a roca expuesta y muestra la Torre Verde sobre las pallozas antes de alcanzar la empalizada. El guardia comprueba el motivo de la visita y abre el portón para escoltar a Mid.
2. **Entregar el Grimorio del Guardabosques.** Mid llega al despacho de Marimanta con el grimorio de Leonardo. La Maestre recibe el libro, recuerda su advertencia y cuenta qué ocurrió tras la Noche de la Fada. El sector norte y la rima del Biosbardo completan la conversación. La interpretación de Mid se expresa con pausas, mirada y animación breve, en línea con su mutismo selectivo.
3. **Ingresar en la Torre Verde.** Marimanta revisa el grimorio de Mid y la acepta como alumna. Mid recoge el uniforme del cofre que ya existe y consulta las cuatro asignaturas pendientes para el Nivel I.
4. **Usar la aldea como base.** Mid puede conocer a Brais, comerciar, hacer síntesis y descansar. El encargo de Brais sirve de primera actividad opcional con la seta asada y una baya. La biblioteca, las salas de estudio, el dormitorio y el despacho ofrecen motivos para volver.
5. **Salir a la Fraga y regresar.** El cuaderno registra observaciones de campo. La subida de vuelta desemboca en un portón accesible a Mid como alumna. La aprobación del Nivel I se obtiene al entregar las cuatro evaluaciones y desbloquea los mapas de la Torre.

## Acciones de producción

| Orden | Acción | Dependencia y criterio de cierre |
| --- | --- | --- |
| 1 | **Montar el primer encargo de Nivel I.** Usar `Misiones` para activar el encargo tras la admisión. En un tramo de la Fraga, permitir descubrir el camino, identificar una planta y registrar una criatura. Preparar la revisión de las tres entradas al volver con Marimanta. | Reutiliza la ida y vuelta ya operativa. La misión se puede iniciar también desde una partida que ya completó la primera visita. El progreso se conserva al viajar y al cargar, y las observaciones repetidas cuentan una sola vez. |
| 2 | **Ampliar la Torre Verde.** Probar una planta de estudio y lectura, una galería de biblioteca y una planta superior con despacho y celdas. Dar continuidad visual al hueco central, la escalera de madera y los balcones. Reutilizar `marimanta.glb`, `baston_marimanta.glb` y sus animaciones. | Puede arrancar en paralelo al encargo. Antes de producir arte, verificar visibilidad de Mid, oclusión, colisiones, interacción entre plantas y reaparición al cargar. Repetir la primera visita al integrar la nueva planta. |
| 3 | **Dar función al uniforme y a la admisión.** Propuesta: la admisión gobierna el portón, las tiendas, los obradores, el dormitorio y los diálogos de la aldea. `Atuendos.puesto()` gobierna el reconocimiento en campamentos y el comportamiento de patrullas en la Fraga. Identificar a los Sumicius por facción o por datos de encuentro y ajustar la detección de bestias y enemigos de alerta alta con ambos trajes. Revisar la venta actual del uniforme y la migración del cofre. | Depende del estado de admisión. Probar compra previa, admisión con mochila llena, cambio de traje al cargar y durante una persecución, acceso a un campamento y diferencias de detección con el traje verde y el rojo. |
| 4 | **Completar las cuatro asignaturas.** Ampliar los registros de campo con el catálogo de especies y senderos. Diseñar las pruebas, los prerrequisitos y la entrega de cada asignatura según la tabla de evaluaciones. | Depende del primer encargo y de concretar los senderos, asentamientos y especies. Los mapas de la Torre se abren al aprobar las cuatro asignaturas. |
| 5 | **Producir la aldea y sus interiores.** Reutilizar la palloza de Brais. Variar cubiertas de centeno, granito con líquenes y reparaciones de las viviendas. Terminar el hogar y la Travariza familiar con horno, humo filtrado por la paja, alimentos colgados, aperos y ganado donde se vea desde cámara. Dar al gremio de gorro verde un interior con taller, armería y objetos robados. Introducir la jerarquía con los PNJ y sus rutinas: rateros sin gorro, cacos de verde y druidas de rojo. | Depende de aprobar la planta, las rutas y la cámara. Cerrar con una lectura clara desde la subida y probar las puertas, el corte de cubiertas, las transiciones y el recorrido interior en ventana. |
| 6 | **Activar las visitas posteriores y el cambio de guardabosques.** Ampliar el trato de vecinos y las secundarias tras la admisión. Añadir el diálogo recurrente sobre Pedro Chosco en el despacho y la cancioncilla al salir. Introducir a Benvito Brisaboa, con su coroza, en el Puesto del Guardabosques tras la derrota del Canouro que lo ocupa. | Depende de identificar el Canouro concreto del relato y guardar su derrota. `Bosque_02` ya tiene canouros de encuentro. Probar el puesto antes y después del hito y volver a cargar ambos estados. |

## Evaluaciones del Nivel I

| Asignatura | Actividad que hay que diseñar | Aprobación |
| --- | --- | --- |
| Historia I | Acreditar formación religiosa en un Templo autorizado. Visitar dos sociedades chamánicas activas y contrastar una tradición del Titán de la Naturaleza con una fuente histórica. | Apuntes del grimorio y prueba de respuesta cerrada en la Torre. |
| Botánica y Herboristería I | Identificar árboles, arbustos, hongos y plantas, registrar el herbario y practicar la recolección responsable en un obrador local. | Herbario de especies locales, identificación práctica y trabajo en el obrador. |
| Orientación y Cuaderno de Campo | Acreditar dibujo y cartografía, completar una expedición supervisada y recorrer los senderos de la Fraga. Registrar relieve, rastros, hora, clima y lugar. | Expedición y cuaderno con mapa del área y bestiario. El progreso puede contar por tramos descubiertos y especies registradas. |
| Competencia Rúnica I | Acreditar Ética del Druida y resolver dilemas de campo mediante runas elementales. Diseñar pruebas que aprovechen los reactivos y el repertorio que Mid trae de Terra Fina. | Resolver los casos y explicar el uso elegido. Las prácticas de Mid pueden usar elementos que los chamanes sumicios no estudian. |

## Decisiones para el primer pase

- **Primer encargo de campo.** Elegir un tramo, una planta y una criatura en el recorrido de la Fraga que ya usa la primera visita. Ampliar el catálogo después de validar cómo se registra y se entrega cada observación.
- **Biosbardo y Canouro.** Propuesta inicial: la prueba del Biosbardo se explica durante la audiencia. Diseñar una misión propia solo si ese encargo forma parte de la ruta de Mid. Vincular a Benvito a la derrota del ocupante del puesto, con una identidad propia dentro de los encuentros de Canouro.
- **Biblioteca, mapas y uniforme.** Propuesta inicial: biblioteca accesible al ingresar y mapas reservados hasta el Nivel I. Si la librera conserva la venta del atuendo, probar qué puede hacer una Mid que lo compró antes de ser admitida. El pase a la aldea dependería de la admisión y el reconocimiento en la Fraga seguiría la regla de atuendo equipado que se acuerde.

## Siguiente hito jugable

Tras la admisión, Mid recibe un encargo, baja a la Fraga, registra un tramo, una planta y una criatura y vuelve a la Torre para que Marimanta revise las entradas. El jugador puede consultar qué le falta antes de volver. Al cerrar este encargo se registra el avance del Nivel I y los mapas de la Torre siguen reservados hasta aprobar las cuatro asignaturas.

Probar desde una admisión nueva y desde un guardado con la primera visita completada. Guardar y cargar a mitad del trabajo de campo y después de la entrega. Comprobar que volver a observar la misma especie o recorrer el mismo tramo conserva el progreso correcto.

## Torre Verde, pallozas y camino de piedra

[Lámina de concepto](capturas/monte_sumicio/concepto_torre_pallozas_camino.png). Arriba se ven el exterior y el corte de la Torre. Abajo, una palloza familiar y el camino de piedra. La distribución jugable usa desniveles menores que los del corte de la palloza y se ajustará con la cámara del juego.

### Editar el exterior en Godot

Abrir `mundo/datos_nivel/Nivel_MonteSumicio.tscn`. El juego toma el terreno y las posiciones de esta escena.

- **Suelo.** Seleccionar el `GridMap` y pintar con **HIERBA**, **TIERRA**, **PIEDRA** o **EMPEDRADO**. Para sustituir un material, elegir la misma planta de la casilla. Las plantas 0 a 4 corresponden a los rellanos y terrazas, con medio escalón de altura por planta.
- **Piezas.** Mover el nodo completo de la palloza, el portón o la torre para que viajen juntos sus elementos. Ajustar la coordenada Y a la superficie de la terraza de destino. Las casas se enlazan a sus interiores por nombre.
- **Marcadores.** `InicioFraga` fija la aparición y el regreso por la Fraga. Los nodos bajo `Escolta` son los puntos del guardia en orden. El último es donde espera durante la audiencia. Revisarlos al cambiar el trazado entre el portón y la torre.
- Guardar la escena y probar con `tools/probar_monte_sumicio.cmd`.

### Torre Verde

**Exterior.** Tres cuerpos circulares de granito en disminución, galerías de roble y castaño, cubierta oscura de lajas y vegetación que cae de los balcones. Dejar visible el arco de entrada desde el camino principal. La torre debe asomar sobre la empalizada y las cubiertas de paja desde el último tramo de subida.

| Planta | Recorrido y función |
| --- | --- |
| Baja | Entrada desde la aldea, sala de lectura y pupitres de estudio. Escalera pegada al perímetro y vista al hueco central. |
| Galería | Biblioteca con estanterías curvas y acceso al archivo de mapas, cerrado hasta aprobar el Nivel I. Rellano amplio donde desembarca la escalera. |
| Alta | Despacho de Marimanta para audiencia y entrega de encargos. Celdas de aprendices a lo largo del perímetro, con cama, arcón y ventana estrecha. |

Construir primero una sección jugable con entrada, escalera, galería y despacho. Probar el acceso con Mid y el guardia, el giro de cámara, las barandillas, la vuelta entre plantas y el guardado. Usar sectores de pared, balcones y cubiertas independientes para ocultar solo lo que tapa a Mid. Modelar después el granito, la carpintería y el mobiliario.

### Interiores de las pallozas

Reutilizar la palloza de Brais y el sistema de cámara y fundido de `InteriorPalloza`. Las tres variantes comparten muro circular, puerta baja y cubierta de paja desmontable.

| Variante | Planta e interacciones |
| --- | --- |
| Familiar, empezando por Brais | Umbral despejado y Ástrago elevado medio escalón. Hogar y vara de ahumado en el centro, horno y arcas al fondo. Travariza baja junto al umbral, separada por una valla. Dejar libres el recorrido hasta Brais y el acceso al cofre junto al pesebre. |
| Gremio de gorro verde | Sustituir la cuadra por un taller con mesa, frascos y armario. Colocar el equipo y los objetos de intercambio a los lados para conservar un paso central. |
| Tienda del este | Mostrador y exposición a un lado, mesa de síntesis al otro. Diferenciar los dos puestos con luz y mobiliario, y reservar espacio frente a ambos para interactuar. |

### Camino y enlace con Bosque 02

- **Pavimento.** Primera pasada aplicada desde el portón a la Torre con granito irregular. Mantener las losas grandes en los umbrales. Para el acabado, estrechar las ramas hacia las casas y reducir la densidad de piedra en los bordes hasta mezclarla con tierra, musgo y hierba.
- **Subida (13/11/2026, Pablo).** Bosque 02 se amplió 12 filas al norte: `mapas/Bosque_02.txt` mide ahora 40 × 52 y todas las coordenadas antiguas suben 12 en `y`. El anillo se abre en `x=24` desde la plaza del estanque y sube por roca hasta el claro del sendero (filas 1..8). El acceso con **E** está en `(24,1)` y llega al pie de Monte Sumicio en `InicioFraga`.
- **Regreso.** Desde `InicioFraga`, **E** devuelve a Mid a `(24,3)` en Bosque 02, mirando al sur. La antigua senda sur `(7,37)` ya no es salida.
- **Primer encargo (hecho, 13/11/2026).** Tras la audiencia (textos del PPTX, láminas 29–33) y el uniforme, Marimanta da «Trabajo de campo» (`nucleo/encargo_marimanta.gd`, flags `montesumicio.encargo.*`). Junto a la salida norte se anotan con **E** el hito `(26,3)`, el helecho `(21,5)` y el nido `(28,6)`. Al volver, Marimanta revisa el grimorio y aparece un cofre legendario en la Torre con la **runa de agua** (`global.sello.agua`, se conserva entre niveles). Prueba: `herramientas/prueba_encargo_marimanta.gd`.
- **Pendiente.** La prueba del Biosbardo la pedirá el guardia antes de abrir el portón; depende de la cueva y del campamento del guardabosques, todavía sin hacer.

Referencias del PPTX `Monte-Sumicio`: láminas 1–20 para acceso, aldea y rangos, 21–33 para Torre y audiencia, 34–41 para estudios y atuendos, 42–47 para servicios, visitas posteriores, Benvito y la vuelta a la Fraga.
