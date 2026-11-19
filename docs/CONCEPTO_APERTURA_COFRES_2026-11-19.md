# Concepto: apertura de cofres épicos y legendarios

Actualización de implementación: la presentación incorpora travelling hacia el personaje y plano fijo de la recompensa hasta una pulsación nueva del jugador. En el legendario, el libro se abre después de confirmar y recibe entonces la runa. Los tiempos de las tablas originales no incluyen esa espera manual; consultar COFRES_IMPLEMENTACION_Y_PRUEBA_2026-11-19.md para el comportamiento vigente.

Fecha: 19/11/2026. Estado: propuesta visual y de animación; sin cambios en la lógica del juego.

## Dirección

Una pequeña ceremonia de descubrimiento: contacto con la tapa, luz por la juntura, apertura y recompensa suspendida. Inspiración de ritmo: la claridad de Echoes of Wisdom y la expectación de Ocarina of Time 3D. La identidad de Magic Symbols la ponen los trazos de tinta luminosa y los motivos celtas.

El objeto es el centro del plano. La luz lo enmarca sin ocultar su silueta. Épico violeta; legendario dorado, según Objetos.CALIDADES. Sin fogonazo blanco de pantalla completa. La ilustración conceptual asociada representa intención artística, no una captura del motor ni una validación de los clips.

## Revisión del material local

| Recurso comprobado | Hallazgo | Uso propuesto |
|---|---|---|
| arte/meshy/mixamo_clips.glb | Opening_A_Lid: 8,93 s, medidos en los accessors temporales del GLB | Fuente para la variante legendaria pausada |
| jugador/clips_familia.gd | Opening_A_Lid ya se asigna a Mixamo_AbrirTapa en FUENTE_CLIPS_MIXAMO, incluida en jugadora_base | Probar el clip alternativo sin sustituir globalmente abrir_cofre |
| docs/capturas/mixamo_prueba/Opening_A_Lid.png | Hoja existente al 10/50/90 %, frente y perfil: inclinación, manos adelantadas y recuperación de pie | Evidencia de poses; todavía no demuestra contacto con un cofre |
| arte/meshy/clips_jugadora.py | AbrirCofre se recorta del original entre 0,8 y 3,6 s: tramo nominal de 2,8 s | Primera opción para el épico |
| presentacion/cofre_3d.gd | Anticipación de 0,4 s, apertura de tapa de 0,55 s según contrato, señales abriendo y abierto | Reutilizar la tapa y sincronizar sus eventos con la protagonista |
| objetos/secuencia_cofre_legendario_3d.gd | Secuencia existente de 4,5 s específica de glifos: cámara, halo, escritura en libro | Conservar su función especial al descubrir glifos |

También se revisó docs/CLIPS_MIXAMO_CANDIDATOS.md. Opening_A_Lid ya está disponible localmente: no hace falta descargar otra animación para preparar la prueba. No se ha reproducido ni retocado el clip en este trabajo; la selección es provisional hasta verlo con tapa y vestuario en movimiento.

## Guion épico: 2,2 s, objetivo de montaje

| Tiempo | Personaje y cofre | Cámara, luz y sonido |
|---|---|---|
| 0,00–0,40 | Mira el cofre y empieza a inclinarse; manos hacia la tapa | Acercamiento ortográfico leve; clic del cierre |
| 0,40–0,75 | Breve resistencia antes de abrir | Juntura violeta; pocos trazos se reúnen en el cierre; subida tonal |
| 0,75–1,30 | Tapa abre; protagonista comienza a incorporarse | Abanico violeta contenido, sin tapar el objeto; acento musical |
| 1,30–1,90 | Recompensa asciende y queda suspendida; personaje la observa | Giro del objeto de unos 30 grados; halo sencillo; nombre e icono |
| 1,90–2,20 | Vuelta a pose de reposo | Motas se disipan, cámara recupera encuadre y vuelve el control |

La duración es un objetivo, condicionado al recorte del gesto y su recuperación. Evitar acelerar un clip entero hasta volver brusco el movimiento. Primera comparación: AbrirCofre frente a un recorte de Mixamo_AbrirTapa.

## Identificación de cofres por estrellas (revisión de Pablo)

El número de estrellas y su color identifican la categoría antes de abrir. Propuesta de correspondencia: común, una estrella blanco plateado; épico, dos estrellas violetas; legendario, tres estrellas doradas. La cantidad concreta es una propuesta de diseño; Pablo ha confirmado el uso conjunto de número y color.

Estrellas integradas como pequeños emblemas en la placa frontal, centradas y separadas, con suficiente tamaño para distinguirlas desde la cámara del juego. No representarlas mediante partículas. Comparten forma y acabado entre categorías; cambia su número y color. La categoría se reconoce también sin distinguir colores. El épico enciende sus dos estrellas a la vez durante la anticipación; el legendario enciende sus tres estrellas sucesivamente. Tras abrir, las estrellas permanecen como emblemas de color con emisión atenuada y sin animación de espera.

## Guion legendario revisado: libro abierto y runa, 4,5 s

La dirección elegida por Pablo es mostrar el libro abierto y la runa introduciéndose físicamente en su página. Esta ceremonia pasa a ser la presentación principal del cofre legendario con runa. El libro es el de la protagonista, no un libro cerrado presentado como botín. Se amplía el objetivo de 3,4 a 4,5 s para que apertura, vuelo e inscripción se entiendan.

| Tiempo | Acción | Lectura visual y sonido |
|---|---|---|
| 0,00–0,55 | La protagonista se inclina hacia el cofre | Acercamiento suave; clic del cierre |
| 0,55–1,20 | Las tres estrellas doradas se encienden en orden | Luz por la juntura y crescendo breve |
| 1,20–1,75 | La tapa abre; la runa emerge | Abanico dorado contenido y una onda suave |
| 1,75–2,40 | La protagonista se incorpora; su libro flota delante de ella y se abre | Las tapas giran, las páginas se despliegan; runa suspendida sobre el cofre |
| 2,40–3,15 | La runa vuela desde el cofre hasta la página abierta | Trayectoria curva corta con estela de tinta dorada; la runa se reduce y se orienta al plano de la página |
| 3,15–3,85 | La runa entra en el papel y queda inscrita | Pulso localizado en la página; trazo de tinta permanente y nombre; acorde de descubrimiento |
| 3,85–4,50 | Breve lectura de la runa; el libro se cierra y regresa | Cámara, ambiente y control recuperan su estado |

La silueta de la runa debe mantenerse continua desde el cofre hasta su inscripción, sin desaparecer y ser sustituida por otra imagen desconectada. Al tocar la página, su luz se convierte en tinta. El libro abierto se coloca en tres cuartos hacia cámara para ver ambas páginas y la runa; no depender de que los dedos agarren el libro durante esta primera versión. Usar el mismo libro y ocultar temporalmente su representación de reposo si es necesario para evitar duplicados.

La apertura del libro se resuelve con pivotes de tapas y páginas; no requiere una nueva animación corporal Mixamo. Primero comprobar que el modelo actual permite separar esos movimientos; si es una malla rígida única, preparar una variante animable. Mixamo_AbrirTapa sigue como candidato para la interacción con el cofre. Los tiempos son objetivos hasta probar el montaje.

En la prueba comparar 4,5 s y una versión compacta de aproximadamente 3,8 s solo si mantiene legibles el vuelo y la inscripción. Si en el futuro existen cofres legendarios sin runa, usar presentación de objeto sin inventar una inscripción en el libro.

### Guion anterior de 3,4 s (referencia sustituida)

La tabla siguiente conserva la propuesta inicial para comparación; la versión elegida arriba la sustituye para cofres con runa.

| Tiempo | Personaje y cofre | Cámara, luz y sonido |
|---|---|---|
| 0,00–0,55 | Se inclina y coloca las manos | Cámara se aproxima; ambiente baja suavemente a aproximadamente el 75 % |
| 0,55–1,20 | La tapa resiste un instante | Tres marcas se iluminan en orden; luz dorada por la juntura; crescendo |
| 1,20–1,75 | Apertura de tapa, sincronizada con las manos | Luz dorada en abanico y una única onda suave en el suelo |
| 1,75–2,70 | Se incorpora mientras la recompensa asciende y se sostiene | Trazos dibujan un aro celta detrás del objeto; acorde de descubrimiento |
| 2,70–3,10 | Objeto claramente presentado | Nombre dorado; brillo breve concentrado en el objeto |
| 3,10–3,40 | Recuperación a reposo | Cámara y ambiente vuelven; control disponible |

Variante de comparación en laboratorio: 4,5 s para comprobar si Mixamo necesita más tiempo de contacto y recuperación. Preferir esa duración si 3,4 s obliga a cortes visibles. Los 8,93 s completos no son el objetivo por defecto.

Si la recompensa es un glifo nuevo, utilizar la ceremonia del libro existente como variante propia: la recompensa termina escrita en la página. La secuencia genérica debe aceptar también objetos, materiales y mejoras; no asumir siempre un glifo.

## Montaje de Mixamo

1. Reproducir Mixamo_AbrirTapa con el cofre real. Marcar inicio útil, contacto de manos, impulso de apertura y recuperación. Las tres poses disponibles no permiten fijar esos fotogramas con precisión.
2. Ajustar distancia y orientación del personaje al modelo; verificar altura de manos, pies y paso de la tapa. Evitar desplazamientos instantáneos al iniciar.
3. Crear un recorte independiente para la ceremonia, manteniendo el clip fuente y el rol abrir_cofre existentes.
4. Repartir duración entre aproximación, apertura y recuperación; usar una pausa breve de expectación solo donde la pose lo permita.
5. Disparar la apertura de tapa desde el contacto medido. No aplicar el instante de 1,4 s de AbrirCofre a Opening_A_Lid: pertenecen a clips distintos.
6. Impedir que Cofre3D arranque agacharse mientras el director controla Mixamo_AbrirTapa. Un solo responsable de la animación del personaje durante la ceremonia.

## Efectos y encuadre

- Plano de tres cuartos elevado compatible con la cámara del juego; personaje y recompensa siempre completos. Acercar aproximadamente un 8 % en épico y un 14 % en legendario como puntos de partida.
- Épico: abanico corto, halo limpio y una ráfaga pequeña de trazos violetas.
- Legendario: abanico más alto, una onda en el suelo y aro celta que se escribe detrás de la recompensa. Evitar que coincidan con una columna de rareza todavía visible.
- Aro y objeto orientados para leerse desde la cámara; altura de presentación ajustada al encuadre, no a una cifra fija que pueda sacar el objeto de pantalla.
- Clic, crujido de bisagra, subida tonal y acorde propio. Coordinar el aviso de recompensa para que no dispare otro jingle encima del acorde.
- Modo reducido: sin cambio de cámara ni destello; conserva tapa, color, sonido y presentación de recompensa.

## Próxima prueba propuesta

Actualización de alcance: comprobar también la lectura de las estrellas desde la cámara normal y la secuencia completa del libro abierto. El legendario de prueba contiene una runa: debe verse salir del cofre, viajar, entrar en la página y quedar inscrita. Validar que el libro no aparece duplicado y que cerrar, saltar o repetir restaura su representación normal.

Laboratorio independiente con cofre épico y legendario reales, protagonista vestida y recompensa de ejemplo. Comparar AbrirCofre y Mixamo_AbrirTapa; botones para repetir, cámara fija/acercamiento, velocidad y efectos reducidos. Línea de tiempo con contacto, apertura, presentación y recuperación.

Revisar: contacto de manos, ausencia de deslizamiento de pies, tapa sin atravesar el cuerpo, objeto legible, recuperación sin salto, luz y cámara restauradas. Al repetir o saltar, conceder la recompensa una sola vez y limpiar todos los efectos. Este laboratorio y la integración quedan pendientes de implementación.
