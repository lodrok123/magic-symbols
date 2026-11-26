# Monte Sumicio · Inventario de implementación

Revisión del PDF *Monte-Sumicio*, 71 páginas, y del estado del proyecto al 16/11/2026. Las páginas indican el origen de cada bloque. El inventario recoge trabajo propuesto; las decisiones abiertas necesitan definición de diseño antes de convertirlas en requisitos.

## Punto de partida

| Bloque | Disponible en el proyecto | Trabajo restante |
|---|---|---|
| Aldea | Escena de prueba con subida, portón, empalizada, tres pallozas familiares y tienda. Las cuatro puertas animadas llevan a interiores con cámara propia. | Ambientación de altura, variantes de casas y acabado de la Torre Verde. |
| Primera visita | Escolta, audiencia corta, cofre épico desbloqueado por Marimanta, uniforme, reacciones de la tendera y acceso a casas. | Ampliar la audiencia y conectar sus estados con la progresión de la torre. Conservar el cofre épico aprobado como entrega del uniforme. |
| Comercio y síntesis | La tienda del este tiene compra y mesa de síntesis. La HUD provisional permite arrastrar ingredientes y previsualizar recetas. | Incorporar a Dona Comba, su misión, la venta de materiales y los cambios de precio por recompensas. |
| Base técnica | Estados persistentes, guardado, diario de eventos, misiones, inventario, atuendos y transiciones de nivel. Hay modelos de Marimanta y bastón, además de lobernos y Canouro en otros contenidos. | Reutilizar esas piezas en las escenas y conectar los nuevos sistemas con el guardado. |

## Aldea y Torre Verde

| ID | Trabajo | Estado o dependencia | PDF |
|---|---|---|---|
| AL-01 | Ambientar la subida desde la fraga húmeda hasta el terreno abierto. Añadir niebla por debajo de la aldea, humo que sale por la paja y una silueta de torre visible antes del portón. | Ampliación de maqueta. La conexión exterior depende del mapa de la Fraga. | 1–5, 22 |
| AL-02 | Variantes de palloza heredada o reparada. Completar hogar central, penumbra, horno, arcas, aperos, ahumado y cuadra con vacas y cerdo separado. | Reutilizar exterior, Ástrago, Travariza y mobiliario de Brais. | 6–12 |
| AL-03 | Dar identidad a familias y gremios mediante vestuario, habitantes, diálogos y atrezo. Representar rateros sin gorro, cacos de gorro verde y druidas de gorro rojo. Preparar la variante de gremio con obrador, armería y objetos robados. | Falta contenido. Definir qué parte de la jerarquía y especialización mágica se enseña jugando y cuál queda en diálogos. | 13–21 |
| TV-01 | Construir cuerpo y distribución de Torre Verde. Plantas circulares, hueco central, escalera de madera, balcones, terrazas y vegetación interior. | Torre en maqueta. Empezar por audiencia y despacho. | 22–24 |
| TV-02 | Biblioteca con anaqueles curvos, sala de estudio con pupitres y atriles, aula de lectura y celdas de aprendices. Preparar acceso a dormitorio y estudio tras la admisión. | Nuevos interiores y mobiliario. | 25–28, 39 |
| TV-03 | Integrar el modelo y bastón de Marimanta. Escenificar la entrega del grimorio de Leonardo, su reacción, la advertencia, Noche de la Fada, sector norte y relato del Biosbardo. Mostrar cómo Mid escucha y reacciona. Cerrar con admisión y autorización del cofre. | La visita corta y el cofre ya funcionan. Confirmar origen del grimorio y orden respecto a la derrota del Canouro. | 23, 29–34 |
| TV-04 | Añadir conversación recurrente sobre Pedro Chosco, cancioncilla al salir, desbloqueo de Sombra y Baúl Compartido en el dormitorio. | Definir entre quiénes se comparte el baúl, permisos y persistencia. | 43–44 |
| TV-05 | Enseñar la runa de Agua y registrar la lección en el grimorio. Preparar uso de la torre como base de descanso, recuperación y comercio. | Reutilizar el elemento existente. Definir qué repertorio trae Mid al entrar. | 45–46 |
| TV-06 | Ampliar el cambio de estatus con diálogos, vínculos y misiones secundarias. Aplicar efectos de atuendo a detección, hostilidad, comercio y acceso a campamentos según el tipo de criatura. | El equipo y los permisos locales existen. Distinguir admisión persistente de efectos del atuendo equipado; fijar prioridad ante enemigos en alerta. | 39–42 |

## Nivel I y grimorio de campo

| ID | Trabajo | Dependencia | PDF |
|---|---|---|---|
| NI-01 | Historia I. Visitas a dos sociedades chamánicas, tradiciones del Titán de la Naturaleza, comparación de fuentes y leyendas, apuntes y evaluación cerrada. | Asentamientos, fuentes y contenido de examen. Aclarar si la formación religiosa previa se da por acreditada. | 34–35 |
| NI-02 | Botánica y Herboristería I. Identificación, recolección responsable, herbario, prácticas en obrador y evaluación de especies. | Catálogo de especies y registro de descubrimiento. La mesa ya existe. | 36, 45 |
| NI-03 | Orientación y Cuaderno de Campo. Senderos recorridos, relieve y rastros, registro de clima, hora y lugar, bestiario, mapa y expedición supervisada. | Mapa completo y definición de cuándo se considera recorrido un sendero o descubierta una especie. | 37, 45–46 |
| NI-04 | Competencia Rúnica I. Dilemas prácticos y evaluación de invocación, control y aplicación de runas. | Definir dilemas, soluciones válidas y papel del prerrequisito Ética del Druida. | 38 |
| NI-05 | Seguimiento persistente de las cuatro asignaturas, examen y reconocimiento de Nivel I. Restringir los mapas de la torre hasta aprobar. | Reutilizar sistema de misiones. Fijar orden de expedición, exámenes y acreditación. | 34–38, 46, 71 |

## Fraga, puesto del guardabosques y Dona Comba

| ID | Trabajo | Estado o dependencia | PDF |
|---|---|---|---|
| FR-01 | Conectar aldea, puesto y lugares de la Fraga con entradas y salidas. Situar patrullas sumicias y puntos de observación desde la torre de vigilancia. | Depende del mapa completo en preparación. | 3, 39–42, 46, 50–60 |
| FR-02 | Papones diurnos y ratas burlonas. Modelos y animaciones, encuentros en grupo, mordedura venenosa y respuesta a Agua. | Definir comportamiento y ventaja concreta del agua. | 47–48 |
| BE-01 | Tras el Canouro, colocar a Benvito Brisaboa con coroza y gorro rojo. Desbloquear su habitación al ganar su amistad y habilitar descanso, cura, obrador y baúl. | Reutilizar el combate del Canouro donde encaje; crear personaje y variante del puesto. | 49–51 |
| BE-02 | Decisión de callar o decir «Beltaine». Mantener la habitación como recompensa común. Añadir diálogos y cambios de atrezo progresivos del Museo del Amor, o encuentro y desenlace con Beltaine en el Linde. | Estados de rama, visitas y epílogos. Coordinar el encuentro con la misión de Comba. | 52–54, 60 |
| DC-01 | Sustituir la tendera genérica por Dona Comba con traje azul de arratiana. Exponer el gorro verde y activar «Miña xoia» tras observarlo. | Tienda, rechazo inicial y acceso como aprendiz ya existen. Definir gesto y tiempo de observación. | 55–56 |
| DC-02 | Registrar tres paquetes invisibles de día y pistas nocturnas desde la torre. Vestido en el Arroyo de Piedras Negras, pulseras en Río de Cristais y tercer paquete en Linde del Robledal. | Mapa, ciclo horario, descubrimiento y estado por hallazgo. Reutilizar lobernos en el cementerio; definir su visión entre tumbas. | 56–60 |
| DC-03 | Olláparo en el Círculo de Piedras Antiguas. Dos fases ligadas a los ojos, resistencia al fuego y papel del agua. | Modelo, animaciones, arena, reglas de daño y persistencia del encuentro. | 58–59 |
| DC-04 | Cueva del Lago Termal. Sábana vacía, rastro de perfume, galerías y lago turquesa. La Coca permanece en el agua y ataca a distancia; electricidad eficaz, agua y fuego inútiles. Perfume flotante tras la derrota. | Nueva zona, jefe y recompensa. Decidir cómo se sigue el rastro. | 61–62 |
| DC-05 | Libro mojado opcional y pista sobre la Noche de la Fada. Sellar la entrada al salir y retirar su referencia del mapa. | Definir cómo conservar la oportunidad de leer el libro antes del cierre y qué queda registrado después. | 63–64 |
| DC-06 | Entregas independientes a Comba. Vestido reduce precios a la mitad, pulseras mejoran el pago por materiales y perfume amplía la bolsa. | Compra y capacidad ya existen. Implementar venta, modificadores y recompensas únicas; fijar tarifa y aumento de capacidad. | 65 |

## Ciudadela y supervisión imperial

| ID | Trabajo | Dependencia | PDF |
|---|---|---|---|
| CI-01 | Acceso a las Ruinas de la Antigua Ciudadela, puerta de adamantiu y escudo de los Scombrani. Diseñar su comportamiento frente a magia y las condiciones de paso. | Nuevo acceso y activos. Confirmar si repeler magia se representa como regla jugable. | 66 |
| CI-02 | Berengueres con Gran Maestre en el anverso y Fehu en el reverso. Revisar icono, tienda, recompensas y textos que hoy muestran oro. | Decidir alcance del cambio de presentación de la moneda. | 67 |
| CI-03 | Quinto Aelius Augustus. Modelo, escudo, gafas, halo y escena en despacho con Marimanta. Incorporar supervisión, cambios en la región y contexto imperial. | Nuevo personaje y guion; parte del contexto puede entrar por diálogo. | 68–70 |
| CI-04 | Convocatoria por nivel, expedición de Nivel I y paso a exámenes. Permitir registrar flora y fauna y definir qué pasa al intentar sacar otros objetos de la ciudadela. | NI-05, CI-01 y mapa de ruinas. Fijar cómo se comunica y aplica la restricción. | 71 |

## Orden propuesto

1. **Torre Verde y audiencia** (TV-01, TV-03). Son el siguiente tramo que puede cerrarse en la escena actual mientras avanza el mapa. Integrar a Marimanta y verificar entrega, admisión y apertura del cofre, incluida la carga de partida.
2. **Vida de la aldea** (AL-01–03, TV-02, DC-01). Acabar los espacios con función inmediata y presentar a Dona Comba con su gorro como punto de arranque de misión.
3. **Progresión y servicios** (TV-04–06, NI-01–05). Fijar estados de asignatura, permisos, decisiones de atuendo y registros antes de poblar el mapa.
4. **Contenido territorial y cierre** (FR-01–02, BE-01–02, DC-02–06, CI-01–04). Colocar rutas, encuentros, pistas y expedición sobre el mapa cuando estén cerrados sus accesos y lugares.

Comprobaciones transversales al implementar: guardar y cargar antes y después de cada desbloqueo irreversible; registrar hitos en el diario de pruebas; comprobar que recompensas y cofres se conceden una vez; probar las dos ramas de Benvito, las tres entregas por separado y el acceso sellado de la cueva.

## Referencias del proyecto

- Escena, maqueta y visita: `escenas/PruebaMonteSumicio.tscn`, `escenas/monte_sumicio_maqueta.gd`, `escenas/monte_sumicio_visita.gd`.
- Interiores: `escenas/InteriorPalloza.tscn`, `escenas/interior_palloza.gd`.
- Sistemas reutilizables: `nucleo/niveles.gd`, `nucleo/partida.gd`, `nucleo/flags.gd`, `nucleo/misiones.gd`, `nucleo/atuendos.gd`, `nucleo/tiendas.gd`, `nucleo/sintesis.gd`, `nucleo/playlog.gd`.
- Arte: `arte/modelos/marimanta.glb`, `arte/modelos/baston_marimanta.glb`, `arte/meshy/piezas/palloza_brais_meshy.glb`.
