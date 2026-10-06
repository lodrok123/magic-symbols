# Encargo para el contexto JUEGO: contrato de estados del suelo (5 de octubre de 2026)

Texto para abrir una sesión del contexto Juego. Se puede pegar tal cual como primer mensaje.

---

Eres el contexto **Juego** de Magic Symbols (jugabilidad, runas, niveles). Antes de nada lee, en este
orden: `docs/PROPIETARIOS.md` (qué archivos son tuyos), las últimas entradas de `docs/DIARIO.md`,
`docs/NUEVOS_SISTEMAS.md`, `docs/TECNICAS_APLICABLES.md` (§1 tabla, §4) y `docs/IMPLEMENTAR_TECNICAS.md`
(cabecera y Paso 1, incluida la "Corrección"). Comprueba que la carpeta conectada es el repo
`magic-symbols` y en qué copia estás (`pablo` o `paranda`); dilo al empezar.

## Situación

Pablo ha aprobado llevar a la maqueta 3D (`poc_25d/PruebaTest2`, del Pipeline) una **capa de estado del
terreno por celda**: quemado, mojado, helado, pisado, que leen los shaders de suelo, hierba y agua. El
Pipeline va a programarla. Pero las **reglas** de esos estados (qué deja cada elemento, en qué orden,
cuánto dura, qué deshace qué) son jugabilidad, y **ya existen en el juego 2D**, que es tuyo:

- `neutral_block.gd`: SECO → MOJADO → HELADO (dos aguas); el hielo hiela de golpe; el calor deshace un
  escalón y del charco sale vapor; el charco conduce el rayo con pestillo de 0,6 s; el mojado no caduca.
- `grass_block.gd`: fina / crecida / prendiendo / ardiendo / cenizas; frente de fuego que contagia; el
  viento lo lanza; el agua apaga, rebrota cenizas y hace crecer la fina.
- `water_block.gd`: congelar, conducir, calmarse, disipar.
- `combate_comun.gd`: mojado 6 s, quemadura 3 s, congelado 1,5/2,5 s, tintes del sprite por estado.
- `earth_block.gd` / empujables: brota con agua, se desmorona con disipar.

El Pipeline **no debe inventar otras reglas**: debe copiar las tuyas. Hoy, en `IMPLEMENTAR_TECNICAS.md`
Paso 1, `_al_impactar()` y `_decaer_estado()` llevan reglas provisionales escritas por QA (mojado que
caduca a los 6 s, etc.) que **no coinciden** con el 2D. Tu trabajo es publicar el contrato para que las
sustituya.

## Tarea 1 (la importante): `docs/ESTADOS_SUELO.md`

Nuevo documento tuyo, extraído **del código, no de memoria**: lee cada archivo justo antes de resumirlo
y cita la función de la que sale cada regla. Contenido:

1. **Tabla de transiciones por tipo de bloque.** Una tabla por `neutral`, `hierba`, `agua`, `tierra
   (empujable/construido)`, `hielo permanente`. Columnas: *estado actual* · *elemento que llega* (por
   etiqueta de runa: `agua`, `frio`, `calor`, `rayo`, `viento`, `tierra`, `disipar`) · *estado resultante* ·
   *efecto lateral* (vapor, descarga, contagio, sonido `Sfx`) · *dura* (∞ o segundos y qué lo corta) ·
   *función*. Las celdas sin reacción se ponen explícitamente como "—" para que el Pipeline no las
   rellene por su cuenta.
2. **Tabla de estados en personajes** (`combate_comun.gd`): estado · lo provoca · duración · qué lo
   anula · qué cambia (daño ×, salto del rayo, congela más) · tinte exacto del sprite (los `Color` del
   código).
3. **Visual 2D de cada estado**: textura o `modulate` (valores exactos de `_set_state` / `_set_visual`),
   para que el 3D elija colores equivalentes (QA los compara).
4. **Mapa a los cuatro canales de la textura 3D** (`R` quemado · `G` mojado · `B` helado · `A` pisado):
   para cada estado 2D, qué valor de canal le corresponde, y qué estados 2D **no caben** en cuatro
   canales (p. ej. hierba *crecida* vs *fina*, *prendiendo* vs *ardiendo*, charco *electrificado*) con tu
   propuesta: canal compartido con umbrales (0,5 = fina, 1,0 = crecida) o "no se representa en el suelo,
   lo hace el VFX". El Pipeline no decide esto; tú sí.
5. **Lo que el 2D no tiene y el 3D sí** (pisado por la chibi, hierba que se aparta): deja claro que son
   solo visuales, sin efecto de juego, para que nadie los convierta en mecánica sin pasar por Pablo.

Formato: español, tablas Markdown, cabecera con fecha y "fuente de verdad: el código 2D; si difieren, el
código manda y se actualiza este doc". Sin reescribir ningún `.gd`.

## Tarea 2: entrada en `docs/DIARIO.md`

Al final, una entrada `2026-10-05 · Juego` que diga que existe `docs/ESTADOS_SUELO.md`, que es el
contrato de reglas para la capa de estado 3D, y que el Pipeline debe ajustar `_al_impactar()` y
`_decaer_estado()` de `IMPLEMENTAR_TECNICAS.md` Paso 1 a él. Si la copia del repo tiene el diario con
entradas perdidas (ha pasado dos veces hoy), no restaures las ajenas: avísalo en tu entrada.

## Tarea 3 (solo si Pablo dice en qué copia): `docs/CAMBIOS_JUEGO_PENDIENTES.md`

Hay tres diffs tuyos pendientes (hielos del agua, muerte de los goblins con `anim_orden = "death"`,
interrupción al recibir golpe). Pregunta a Pablo en qué copia del repo se aplican antes de tocar
`nivel_base.gd`, `goblin_guerrero.gd` y `goblin_arquero.gd`; si no contesta, no los apliques.

## Lo que NO haces

- No tocas `poc_25d/`, `pipeline/`, `art/` ni `docs/ARTE.md`: son del Pipeline. Si ves algo que debe
  cambiar ahí, lo escribes en el diario y paras.
- No cambias reglas de juego al documentarlas. Si al leer el código ves una regla que te parece mal
  (p. ej. que el mojado del suelo no caduque mientras el del enemigo sí), la anotas en una sección
  "Dudas para Pablo" al final del doc; no la "arreglas".
- No haces commit ni push.

## Cómo sabrás que está bien

- Cada fila de las tablas cita una función real y existe en el archivo.
- La tabla de bloques no tiene huecos: toda combinación estado × elemento tiene resultado o "—".
- El mapa a canales deja decidido qué hace el 3D con *crecida*, *prendiendo* y *electrificado*.
- QA (contexto de arte) puede coger el doc y comparar los tintes 2D con los colores del shader 3D sin
  abrir el código.
