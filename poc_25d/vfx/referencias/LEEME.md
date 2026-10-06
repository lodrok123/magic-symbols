# Referencias de animación para los VFX (tarea 5.10 del plan)

Vídeos que Pablo ha reunido (6/10/2026) para fijar **cómo tiene que verse**
cada forma. Son referencias, no assets: llevan marca de agua (Envato,
Shutterstock) y **no pueden acabar en el juego**. La carpeta lleva
`.gdignore` para que Godot no la toque, y `.gitignore` hace excepción con
estos `.mp4` para que viajen entre ordenadores (6 MB en total).

| archivo | forma v2 | qué enseña |
|---|---|---|
| `barrera_fuego.mp4` (4,1 s) | `corro` / barrera (fuego) | Cúpula de fuego sobre el suelo con un **aro de llamas girando en la base**. La barrera es una semiesfera, no un anillo plano. |
| `barrera_rayo.mp4` (3,9 s) | `corro` / barrera (rayo) | Esfera que **se cierra desde abajo** en ~0,5 s, con arcos eléctricos al formarse, y luego queda quieta con chispas sueltas. Modelo de "aparición" para cualquier barrera. |
| `muro_fuego.mp4` (4,3 s) | `muro` (fuego) | Línea de llamas de altura ~1 casilla, con humo gris por encima; bucle sin principio ni fin. Lo que da el glifo `línea`. |
| `lanzallamas_fuego.mp4` (1,6 s) | `chorro` (fuego) | Llamarada horizontal que **se alarga desde el origen** y se deshace al final; no es un proyectil, es un chorro continuo. Lo que da `línea + levitación`. |
| `propagacion_fuego.mp4` (6,6 s) | bola → impacto (fuego) | Bola que cae, **se estira en columna** al tocar el suelo y deja fuego en la base. Referencia de qué pasa cuando una `bola` llega a su destino. |

**Pulso:** la referencia es la animación **`fire ring`** (aro que nace en
el jugador y se expande hacia fuera). Pendiente de añadir aquí como
`pulso_fuego.mp4`; mientras, vale el aro de la base de `barrera_fuego.mp4`
puesto a crecer.

Regla práctica para la matriz "forma = malla, elemento = material": estas
cinco son las **formas**; cambiar fuego por hielo o rayo no cambia el
movimiento, solo el material (ver `barrera_rayo` frente a `barrera_fuego`:
misma cúpula, distinto acabado).
