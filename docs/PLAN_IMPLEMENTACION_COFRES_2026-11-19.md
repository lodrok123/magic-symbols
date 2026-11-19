# Inventario y acciones: cofres con estrellas y ceremonia del libro

Fecha: 19/11/2026. Referencia: CONCEPTO_APERTURA_COFRES_2026-11-19.md.
Estado actualizado: implementación realizada. Ver COFRES_IMPLEMENTACION_Y_PRUEBA_2026-11-19.md para archivos definitivos, comandos, validación y el alcance del libro articulado. El inventario y las acciones siguientes conservan el diagnóstico previo como referencia.

## Resultado que buscamos

- Cofres identificables antes de abrir por estrellas en su placa frontal: propuesta de 1 plateada para común, 2 violetas para épico y 3 doradas para legendario.
- Apertura épica breve, objetivo 2,2 s, con recompensa legible.
- Apertura legendaria con runa, objetivo 4,5 s: tapa, aparición de runa, apertura del libro de la protagonista, vuelo continuo hasta la página, inscripción y regreso del libro.
- Recompensa, flags y controles coherentes al terminar, saltar o cargar partida.

## Inventario comprobado

| Necesidad | Material existente | Estado real y acción necesaria |
|---|---|---|
| Modelo épico | arte/piezas/cofre_epico.tscn; arte/meshy/piezas/cofre_epico.glb | GLB con cofre_cuerpo y cofre_tapa separados, 2 mallas y sin clips. Reutilizar con giro de tapa por código; comprobar su bisagra en movimiento. |
| Modelo legendario | arte/piezas/cofre_legendario.tscn; arte/meshy/piezas/cofre_legendario.glb | Misma separación y ausencia de clips. No asumir que reproduce el clip del cofre común. |
| Control de tapa | presentacion/cofre_3d.gd | Ya ofrece estados, anticipación, giro sin clip, señales abriendo/abierto y restauración. Añadir configuración por calidad y control explícito del gesto corporal. |
| Paleta de rareza | nucleo/objetos.gd, Objetos.CALIDADES | Violeta épico y dorado legendario ya definidos. Usar esta fuente; añadir número de estrellas en una tabla de presentación central. |
| Estrellas | Las escenas de cofres revisadas instancian sus GLB sin nodos específicos de estrellas | Preparar emblemas independientes y sus anclajes frontales. No se ha comprobado si hay decoración equivalente horneada en las texturas. |
| Gesto breve | arte/meshy/jugadora_clips.glb; jugador/clips_familia.gd | AbrirCofre está asignado al rol abrir_cofre. El script de recorte define un tramo nominal de 2,8 s. Comparar montaje para épico. |
| Gesto largo | arte/meshy/mixamo_clips.glb | Opening_A_Lid: 8,93 s medidos en el GLB; disponible como Mixamo_AbrirTapa. Marcar contacto y recuperación antes de recortar. |
| Validación de poses | docs/capturas/mixamo_prueba/Opening_A_Lid.png | Existe hoja de frente/perfil al 10/50/90 %. No sustituye la revisión de movimiento con cofre. |
| Grimorios del equipo | arte/equipo/grimorio_1.glb, grimorio_2.glb, grimorio_3.glb | Cada archivo tiene un nodo, una malla y ningún clip. No hay tapas/páginas articuladas listas en estos modelos. Preparar variante animable que conserve el aspecto del nivel equipado. |
| Libro de personaje | jugador/pj_3d.gd; jugador/equipo_3d.gd | Libro en cinto/mano y vuelo de regreso ya gestionados. El estado en_mano_abierto no demuestra apertura geométrica: actualmente se instancia Equipo3D.pieza("grimorio"). Ampliar mediante API explícita para ceremonia. |
| Brazo del libro | jugador/brazo_libro_3d.gd | Modificador para sostener el libro al lanzar. Coordinar su peso durante el gesto de abrir; primera versión con libro flotante para evitar un nuevo agarre animado. |
| Director legendario | objetos/secuencia_cofre_legendario_3d.gd | Cámara, bloqueo, luz, glifo, salto y desbloqueo existentes. Sustituir presentación del libro y rebajar destello. |
| Libro de la ceremonia actual | _caer_al_libro(), _escribir() en el director legendario | Hoy crea un Panel y TextureRect en CanvasLayer: transición del glifo 3D a interfaz 2D. Debe reemplazarse por página y trayectoria en el mundo 3D. |
| Imagen de runa | Sigils.GLYPHS, usado por el director actual | Reutilizar textura del glifo real; añadir tratamiento sobre página 3D sin inventar una runa genérica. |
| Luz y partículas | objetos/vfx_calidad_3d.gd; presentacion/vfx_kit_3d.gd; Pulso3D | Reutilizar color, motas y onda. Crear abanico, aro celta y estela; comprobar que la columna de rareza no se superpone a la ceremonia. |
| Sonidos | nucleo/sfx.gd | Hay entradas creak, cofre_tapa, libro_abre, libro_cierra, pagina, pulso_resonante y logro_acierto. Audicionar variantes y mezcla; componer/seleccionar crescendo y resolución propios si no encajan. Existencia de entradas no equivale a mezcla final validada. |
| Integración | escenas/puzle.gd, clase CofrePuzle | Hoy elige ceremonia por glifo no vacío, no únicamente por calidad. _al_abrirse da botín y fija flag al terminar la tapa; coordinar esa entrega con la presentación. |
| Progresión | _desbloquear() del director; Repertoire y Flags | Hay guardia escrito y flag por glifo. Conservar una sola concesión y resolver coherencia entre cofre abierto y runa inscrita. |
| Pruebas existentes | herramientas/prueba_cofre_cerrado.gd, prueba_cofre_estados.gd, prueba_mixamo_clips.gd, prueba_mano_libro.gd | Reutilizar para regresión de tapa, estados, retarget y libro. Añadir cobertura de la nueva ceremonia donde estas pruebas no lleguen. |

## Material que hay que preparar

| Entregable | Cantidad mínima | Preparación concreta | Condición para aceptarlo |
|---|---|---|---|
| Emblema de estrella | 1 geometría reutilizable | Estrella de cinco puntas con espesor ligero y material parametrizable; distribuir 1/2/3 desde el mismo recurso | Se distinguen cantidad y color desde la cámara normal y sin iluminación especial |
| Anclajes de cofre | 1 frontal y 1 interior por variante usada | Marcadores para estrellas y salida de runa; medir orientación y escala de las escenas reales | Estrellas fuera de la tapa y de la cerradura; runa emerge del hueco |
| Grimorio animable | 1 estructura compartida con 3 apariencias | Lomo, pivotes de tapas, bloques de páginas, página receptora y marcador de inscripción; materiales según nivel equipado | Se abre y cierra sin huecos graves; conserva la identidad del libro de equipo |
| Página receptora | 1 superficie y material | Coordenadas y orientación estables para colocar la textura real de la runa; tinta, brillo y progreso | Se ve desde la cámara y no parpadea por superposición de superficies |
| Montaje corporal | 2 perfiles de secuencia | Épico corto y legendario pausado usando las fuentes existentes; eventos medidos | Manos y tapa sincronizadas; pies sin deslizamientos visibles; recuperación continua |
| Efectos nuevos | Abanico, aro celta y estela | Parámetros de color, escala, intensidad y duración; pulso localizado al inscribir | El brillo no borra la runa ni la página; sin destello blanco de pantalla completa |
| Mezcla de sonido | 2 perfiles | Sincronizar cierre, bisagra y acorde; añadir libro/página para legendario | Un único acento principal; el aviso no duplica el jingle |
| Laboratorio | 1 escena independiente | Cofres común/épico/legendario, protagonista real, libro de equipo y runa real | Repetible sin modificar inventario ni flags de la partida habitual |

No hace falta descargar otro clip Mixamo para comenzar. El bloqueo de arte principal es el libro articulado. Para el prototipo se puede construir con geometría simple y materiales aproximados; para integrarlo debe conservar las apariencias de los tres grimorios.

## Acciones en orden

| ID | Prioridad | Acción | Archivos o salida | Depende de | Criterio de cierre |
|---|---|---|---|---|---|
| A01 | P0 | Preparar laboratorio aislado y registrar estado inicial del personaje, cámara y libro | Nuevos: laboratorios/LabCofresCeremonia3D.tscn y laboratorios/lab_cofres_ceremonia_3d.gd | — | Repetir y reiniciar sin escribir progreso habitual; mostrar fases y tiempos |
| A02 | P0 | Medir modelos y contacto de los clips con ambos cofres; comprobar pivotes y frente | Registro de tiempos en este plan o ficha de calibración | A01 | Selección de clip por variante, instante real de contacto y recuperación definidos |
| A03 | P0 | Crear estrella reutilizable, tabla por calidad y anclajes frontales | Nuevo controlador propuesto: presentacion/cofre_estrellas_3d.gd; escenas de cofres | A01 | 1/2/3 visibles y materiales independientes por instancia; escala y orientación correctas |
| A04 | P0 | Preparar grimorio articulado con página receptora y tres apariencias | Nueva escena propuesta: arte/equipo/grimorio_ceremonia.tscn; controlador presentacion/libro_ceremonia_3d.gd | A01 | Apertura/cierre reproducibles; superficie receptora y punto de destino en 3D |
| A05 | P0 | Añadir cesión temporal del libro al director de ceremonia | jugador/pj_3d.gd y coordinación con Equipo3D | A04 | Un solo libro visible; cancela transiciones previas de forma controlada; devuelve estado correcto al terminar o interrumpir |
| A06 | P1 | Parametrizar anticipación, color y gesto en Cofre3D; montar perfil épico | presentacion/cofre_3d.gd; director épico nuevo o director común con perfiles | A02, A03 | Objetivo 2,2 s ajustado al gesto; sin agacharse automático simultáneo con animación externa |
| A07 | P1 | Montar el guion legendario de 4,5 s con libro 3D | objetos/secuencia_cofre_legendario_3d.gd y controlador del libro | A02, A04, A05 | La misma runa se ve salir, viajar, entrar y quedar escrita; libro cierra y regresa |
| A08 | P1 | Añadir abanico, estela, aro y pulso de página; retirar fogonazo anterior en este perfil | VFX reutilizables de ceremonia; VfxCalidad3D cuando proceda | A06, A07 | Lectura clara de recompensa y página con brillo normal y efectos reducidos |
| A09 | P1 | Montar y ajustar audio de ambos perfiles | nucleo/sfx.gd solo si hacen falta entradas; director de secuencia | A06, A07 | Sonidos alineados a eventos; sin avisos ni música solapando el acento principal |
| A10 | P0 antes de integrar | Definir entrega única y restauración ante salto/carga/cambio de escena | escenas/puzle.gd, director legendario, Flags/Repertoire sin duplicar lógica | A06, A07 | Nunca queda cofre consumido sin runa; ni doble botín, doble gasto de llave o jugador bloqueado |
| A11 | P1 | Validar laboratorio y regresiones; revisar ambas duraciones en movimiento | Pruebas existentes y nueva prueba de ceremonia | A03–A10 | Matriz de comprobaciones de abajo satisfecha y revisión visual documentada |
| A12 | P2 | Activar en un cofre épico y un legendario de nivel real; después ampliar | Selección de perfil en CofrePuzle y escenas correspondientes | A11 | Funciona con suelo, cámara, obstáculos y guardado reales |

P0 = base necesaria o condición imprescindible para integrar. P1 = construcción y revisión de la experiencia. P2 = despliegue en niveles. Son prioridades, no tareas ya ejecutadas.

## Contratos a concretar al implementar

1. **Propiedad de la animación:** un solo director controla personaje, tapa y libro durante la ceremonia. Cofre3D conserva las operaciones de tapa y restauración, pero no arranca otro gesto cuando hay animación externa.
2. **Libro:** proponer operaciones públicas de iniciar ceremonia, obtener marcador de página, finalizar y cancelar. Evitar que el director modifique directamente _libro y _libro_tween. Registrar visibilidad/estado previos y restaurarlos; una copia visual temporal solo puede existir mientras el libro normal está oculto.
3. **Trayectoria:** origen en el marcador interior del cofre y destino en la página. Interpolar posición, giro y escala en 3D; mantener identidad visual de la runa al transferirla al material de la página.
4. **Recompensa:** separar tapa abierta, presentación terminada y recompensa concedida. Definir un punto único de concesión; al saltar se ejecuta ese mismo cierre una vez. Resolver explícitamente el caso actual en que la flag de cofre abierto se pone antes del desbloqueo de glifo. Propuesta: transacción de progreso final para cofre/runa, con recuperación si se interrumpe después de abrir físicamente la tapa.
5. **Elección de perfil:** distinguir calidad del cofre y tipo de recompensa. Legendario con runa usa libro; épico usa presentación breve. Mantener compatible el contenido actual que activa ceremonia por glifo sin depender del nombre del modelo.
6. **Laboratorio:** usar recompensa simulada y estado aislado; no reutilizar ciegamente el desbloqueo real al repetir. La prueba de integración sí verifica Flags/Repertoire sobre estado temporal restaurable.
7. **Cierre:** matar tweens y emisores de la ceremonia antes de restaurar cámara, luz, libro y control, de modo que no se vuelvan a alterar tras terminar. Comprobar nodos válidos si se sale del nivel.

## Validación requerida

| Caso | Resultado esperado |
|---|---|
| Cofre cerrado a distancia de juego | Cantidad y color de estrellas legibles; decoración sin atravesar malla |
| Épico y legendario desde distintos ángulos | Tapa abre correctamente; manos no atraviesan cuerpo/tapa; recompensa completa en plano |
| Libro equipado de nivel 1, 2 o 3 | Apariencia correcta, un único libro visible, inscripción sobre página |
| Libro inicialmente en cinto, mano o regresando | Entrada coherente en ceremonia y retorno estable; libro_valido() coherente con el contrato nuevo |
| Repetición y doble interacción | Una sola secuencia activa; concesión y gasto únicos |
| Salto antes de abrir, durante vuelo y al inscribir | Política de salto respetada; cierre consistente y sin efectos huérfanos |
| Carga tras abrir o tras inscribir | Cofre y runa concordantes; no vuelve a entregarse recompensa |
| Cambio de escena durante ceremonia | Sin referencias inválidas ni cámara, luz, control o libro retenidos |
| Ventana y resolución distintas | Estrellas, runa y libro legibles; nombre dentro de pantalla |
| Efectos reducidos | Información completa sin destello ni movimiento de cámara |
| Cofres existentes sin la ceremonia nueva | Estados oculto/aparece/cerrado/abierto y botín mantienen su comportamiento |

## Comandos existentes para la fase de validación

Desde CMD, en E:\magic-symbols:

```bat
tools\Godot_v4.7.2-stable_win64.exe --headless --path . --script res://herramientas/prueba_cofre_cerrado.gd
tools\Godot_v4.7.2-stable_win64.exe --headless --path . --script res://herramientas/prueba_cofre_estados.gd
tools\Godot_v4.7.2-stable_win64.exe --headless --path . --script res://herramientas/prueba_mixamo_clips.gd
tools\Godot_v4.7.2-stable_win64.exe --headless --path . --script res://herramientas/prueba_mano_libro.gd
```

Estos comandos corresponden a scripts existentes; no se han ejecutado para este inventario. El comando del laboratorio nuevo se añadirá cuando se cree su escena. No hay todavía una prueba ejecutable del concepto completo.

## Punto de partida recomendado

Ejecutar A01–A05 primero. Con eso se podrá revisar lo decisivo: estrellas legibles, manos sincronizadas con la tapa y libro realmente abierto. A continuación montar el vuelo y la inscripción (A07), cerrar el perfil épico (A06), y añadir efectos/audio sobre ese montaje ya legible. La integración en niveles queda después de las comprobaciones de progreso y restauración.
