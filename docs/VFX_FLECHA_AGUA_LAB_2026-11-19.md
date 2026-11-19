# Flecha de agua: prueba de nacimiento e impacto

Escena: `res://laboratorios/LabFlechaAgua3D.tscn`. Ejecutar desde CMD o PowerShell:

```powershell
E:\magic-symbols\tools\probar_flecha_agua.cmd
```

Dos lanzamientos sincronizados: izquierda vertical, derecha horizontal hacia +X. Abre enfocando el horizontal. El bucle dura 11 segundos y el radio inicial es 0,40 m. El horizontal mantiene una altura de 1,10 m hasta un bloque de prueba: se comprime en X, salpica hacia el lado del lanzador y las gotas caen por gravedad. El charco empieza 0,22 s después del golpe y su máscara se recorta para no atravesar el bloque. C permite recuperar la comparación con el lanzamiento vertical.

Abre por defecto en **vista lateral ortográfica**, mirando el plano X/Y del lanzamiento. L recupera esa vista después de orbitar; G usa la elevación de 30° de la cámara de juego del laboratorio base, también ortográfica, para comprobar el charco desde el ángulo del juego. C cambia el foco sin perder el ángulo elegido. La rueda ajusta el zoom ortográfico.

| Control | Acción |
|---|---|
| Espacio | Pausar / continuar |
| R | Reiniciar el ciclo |
| S | Velocidad normal / cámara lenta x0,2 |
| Flechas izquierda / derecha | Pausar y retroceder / avanzar 0,05 s |
| 1 / 2 / 3 | Parar en formación / compresión / charco |
| 4 | Parar en vuelo para revisar la continuidad de cabeza y cola |
| H | Mostrar / ocultar panel |
| C | Vista conjunta / vertical / horizontal |
| L / G | Vista lateral / ángulo de juego a 30° |
| Botón derecho y arrastrar | Orbitar |
| Rueda | Acercar / alejar |
| F5 | Suelo claro / oscuro |
| + / - | Cambiar radio entre 0,20 y 0,65 m y reiniciar |
| B | Activar / desactivar la repetición |

## Resultado preparado

| Fase | Tiempo desde inicio | Comportamiento |
|---|---|---|
| Nacimiento | 0–1,20 s | Crecimiento de una masa irregular, con deformaciones amplias y unas pocas gotas que se desprenden por debajo. |
| Sostén | 1,20–1,40 s | Masa completa, superficie en movimiento. |
| Vuelo | 1,40–2,40 s | Cabeza gruesa y cola que se estrecha, construidas con la misma malla cerrada. Solo tres gotas pequeñas desprendidas del extremo; recupera forma redonda antes de contactar. |
| Compresión | 2,40–2,56 s | Se aplasta contra el suelo y se ensancha mientras empieza el depósito. |
| Salpicadura | Desde 2,415 s, hasta unos 3,5 s | Lámina asimétrica con distintas alturas y alcance, apertura mayor hacia delante en oblicuo y rotura progresiva. Gotas orientadas por velocidad y fragmentos aplanados con gravedad; la lámina dura hasta 2,95 s. |
| Depósito | 2,40–10,90 s | Expansión durante 0,85 s, ondas que se amortiguan, persistencia y retirada gradual al final. |

En oblicuo la salpicadura se desplaza y las gotas reciben velocidad hacia delante. El charco es una elipse desplazada en esa dirección; el vertical se mantiene aproximadamente radial. Ambos conservan la misma área para un mismo radio. Al variar el radio, el área del depósito escala con el volumen de la esfera (`r³`), lo que equivale a asumir una profundidad media constante. El contorno irregular reduce el área respecto a la elipse ideal: es una regla visual coherente, no un cálculo de fluido.

Estética del agua del proyecto: todos los materiales se construyen con `AguaMallas.material()`, que proporciona la paleta central de `agua_paleta.gd` y las texturas LeLu `T_Noise_Wf4` / `T_Noise_W5i`. Los shaders de esta prueba incluyen `agua_toy.gdshaderinc`: reutilizan `agua_tonos`, sus bandas de color, `agua_cau` / `agua_cau3`, el tinte de cáusticas, el borde y el fundido por profundidad. Masa, cola, gotas, fragmentos y charco comparten los mismos tonos turquesa. Son unshaded, sin iluminación especular ni emisión, como el agua toy del proyecto.

La geometría mantiene el ciclo de la revisión anterior. La masa conserva una refracción discreta de pantalla con comprobación de profundidad y normales calculadas sobre la deformación y la cola. El depósito calcula las cáusticas en coordenadas de mundo: se expande la máscara sin estirar la textura. No hay un contorno blanco de espuma permanente. El reloj del laboratorio controla también las texturas para poder pausarlas o retroceder. La refracción hereda el límite de Godot: la copia de pantalla no contiene otros objetos transparentes.

La revisión toma como referencia visual el vídeo local `Grabación 2026-11-19 183116.mp4` (6,8 s), revisado por fotogramas: crecimiento irregular, estiramiento continuo y apertura del impacto en láminas. Se conserva el tono de agua del proyecto y un depósito más persistente que el residuo breve del vídeo. Las vistas cercanas aíslan el efecto elegido; H permite ocultar el panel al juzgarlo.

## Revisión 2 (referencia: grabación del 19/11, revisada por fotogramas)

- **Destellos puntuales** (`agua_destello.gdshader`, 7 quads que miran a cámara): nacen en el impacto, duran 3–7 fotogramas a 30 fps y pulsan. Color: `tono_b` aclarado hacia espuma, sin llegar a blanco puro.
- **Cabeza clara en vuelo** (`cabeza`): el frente de la masa se aclara y la cola queda más oscura. Aclarado breve de la lámina en el primer contacto (`destello`, 0,14 s).
- **Lámina con picos**: dos frecuencias de puntas en el borde que suben durante la apertura y resisten la rotura; malla 128×12.
- **Picos suavizados** (revisión 3): exponentes 5→2,2 y 8→3, frecuencia más baja y altura a la mitad. **Pared lateral** (rehecha tras el ejemplo del usuario del 19/11, grabación `20261119-2008-56`): contra una pared el agua no forma copa; revienta en una nube de fragmentos. El lanzamiento horizontal ahora tiene un chapoteo muy fino y breve sobre la pared (`pared`, 0,26 s) y 130 fragmentos que salen por el hemisferio frente a la pared. La mayoría sale despacio y pocos llegan lejos (0,8–4,6 m/s); hay muchos pequeños y pocos gruesos; una de cada tres es esquirla aplanada que gira y el resto son gotas alargadas en su dirección real de movimiento. Salen escalonados durante ~0,1 s, caen por gravedad y se encogen al final en vez de desaparecer de golpe. El suelo y el impacto vertical no cambian.
- **Charco**: frente de lóbulos (cada dirección avanza a su ritmo), islotes sueltos delante del frente y retirada en islotes con la textura de flujo del proyecto. El quad es 1,3 veces mayor que el charco (el área visible no cambia).
- La prueba pasa con 0 fallos en modo gráfico. En `--headless` los transformes de MultiMesh se leen como identidad, por lo que la comprobación de gotas sobre el suelo falla ahí; usar el modo gráfico.

## Alcance y conexión pendiente

Todo el código está en el laboratorio. El muro restaurado, la barrera aprobada, el viento aprobado y magma conservan su estado anterior. Las recetas de producción de flecha y de impacto tampoco se sustituyen todavía.

**Decisión de diseño (19/11/2026):** estos charcos serán la forma en que el suelo queda en **estado mojado**. El aspecto del charco (lóbulos, islotes sueltos, retirada en islotes) es el que debe mostrar el suelo mojado en el juego, gobernado por el reloj de estados del suelo y no por el reloj visual del lab.

El charco de esta escena es **visual**. No moja casillas, no causa reacciones ni añade volumen a `AguaSim3D`. Su duración de 8,5 s desde el impacto sirve para revisar la persistencia; no representa la duración efectiva del agua del juego.

Tras aceptar el aspecto, la integración debe reutilizar el contacto y normal reales del proyectil; seguir el volumen y las celdas que ya deposita `_materia_liquido()` en `magia/hechizo_vivo.gd`; y retirar gradualmente este depósito transitorio al aparecer el render de agua del terreno. No añadir una segunda cantidad de agua. La prueba actual cubre suelo horizontal, no paredes, escalones ni obstáculos.

Referencia solicitada: [Water Bending Tutorial, A Bit Of Game Dev](https://www.youtube.com/watch?v=3CcWus6d_B8). Esta prueba implementa la propuesta acordada en Godot; no importa shaders ni recursos Unity del vídeo.

## Verificación y archivos

- `herramientas/prueba_flecha_agua_revision.gd`: compresión contra el suelo, comienzo simultáneo del depósito, conservación del área entre ángulos, escalado con volumen, persistencia, retirada final, cambios de tiempo y limpieza de gotas al repetir. Incluye radios 0,20 / 0,40 / 0,65 m, restablecimiento de la cola al retroceder y gotas activas finitas por encima del suelo.
- La revisión de estética comprueba la paleta central y las texturas en los cinco materiales de cada lanzamiento. Añade capturas cercanas sobre suelo claro y oscuro de nacimiento, vuelo, salpicadura y charco. Los archivos de producción compartidos se reutilizan sin editarlos.
- Godot 4.7.2, Vulkan Forward+, RTX 3070: prueba gráfica a 1280×720, 0 fallos y sin errores de scripts ni shaders. Capturas de las fases general y cercana revisadas; la aceptación artística queda para la revisión del usuario.
- Escena ejecutada durante 370 fotogramas a 30 fps: ciclo completo y comienzo de la repetición, salida 0 y sin errores de motor. Se revisaron también las capturas cercanas de nacimiento, vuelo, compresión, rotura de láminas y depósito.
- Capturas reproducibles en `docs/capturas/vfx_revision_2026-11-19/flecha_agua/`.

```powershell
godot --headless --path E:/magic-symbols --script res://herramientas/prueba_flecha_agua_revision.gd
godot --path E:/magic-symbols --fixed-fps 30 --script res://herramientas/prueba_flecha_agua_revision.gd -- --capturas
```

Código: `laboratorios/lab_flecha_agua_3d.gd`, `laboratorios/vfx_revision/flecha_agua_revision.gd`, `agua_flecha.gdshader` y `agua_deposito.gdshader`. Entrada: `laboratorios/LabFlechaAgua3D.tscn` y `tools/probar_flecha_agua.cmd`.
