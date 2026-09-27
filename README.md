# Magic Symbols

Juego 2D de magia por dibujo de runas, hecho en **Godot 4.7**.

Dibujas un símbolo, el juego lo reconoce, y el elemento que sale
reacciona con el mundo de forma física: el fuego se propaga por la
hierba, el viento lo aviva, el agua conduce el rayo, el hielo deja el
suelo resbaladizo.

Referencias: *Magicka* (combinar elementos), *Witch Hat Atelier* (que
dibujar importe), *Breath of the Wild* (reacciones físicas entre
elementos).

---

## Cómo se juega

| Tecla | Acción |
|---|---|
| `WASD` | Moverse |
| `Shift` | Saltar |
| `T` | Abrir / cerrar el grimorio (el tiempo se detiene) |
| `R` | Reintentar tras morir |

Con el grimorio abierto:

- Dibuja en el **núcleo** (el círculo central) → eliges el **elemento**
  (fuego, agua, tierra, rayo, hielo, tiempo, viento).
- Dibuja en un **sector** (uno de los 8 alrededor) → añades un **sello**
  con su dirección. Varios sellos en el mismo sector **se combinan**:
  barrera + levitación da una columna, levitación + flecha un tornado que
  se mueve. Ninguna de esas combinaciones está programada — emergen.
- Al cerrar el libro con `T`, se lanza lo que hayas compuesto.

Dibujar en varios sectores lanza varios componentes a la vez: cuatro
flechas en cuatro sectores son cuatro proyectiles en cuatro direcciones.

### Modo de grabación

Dentro del grimorio, `G` entra y sale del modo de grabación, donde
dibujar **no lanza nada**: guarda el trazo como muestra del gesto
seleccionado. `1`–`9` eligen gesto y **`← →` recorren la lista entera** —
hacen falta, porque hay 13 grabables y solo 9 teclas. `Retroceso` borra la
última muestra y `Supr` (dos veces) borra todas las de ese gesto.

**Los dibujos de cada runa están en `docs/runas.png`.**

Graba **varias muestras por gesto** (cuatro o cinco): el mismo trazo
sale distinto rápido que despacio, grande que pequeño, y con una sola
muestra el reconocedor es frágil.

---

## Cómo está montado

La idea que sostiene todo el proyecto es que **el comportamiento son
datos, no código**:

- Un **elemento** es un archivo `.tres` (`fire_rune.tres`,
  `ice_rune.tres`…) con su color, su daño y sus etiquetas. Inventar un
  elemento es crear un `.tres` y añadir una línea a `spellcaster.gd`.
- Una **animación** es una hoja de sprites que cumple un contrato escrito
  (`docs/ANIMACION.md`). Cambiar de personaje es cambiar los PNG.
- Un **gesto** es una plantilla grabada en `gesture_library.tres`.
  Cambiar cómo se dibuja el fuego es redibujarlo, no reescribir una
  función que lo detecte.
- Una **reacción** es una etiqueta. El agua no pregunta "¿eres fuego?",
  pregunta "¿traes la etiqueta `calor`?". Por eso un elemento nuevo
  funciona contra el mundo entero sin tocar el mundo.
- Los **sellos** (flecha, pilar, barrera, repetición, aumento) no
  declaran combinaciones: cada uno escribe su aportación en una receta
  común (`spell_recipe.gd`) y la receta terminada se interpreta al
  final. `pilar + flecha` da un muro de fuego sin que esa regla esté
  escrita en ninguna parte.

El reconocedor es **$P (Point-Cloud Recognizer)** de Vatavu, Anthony y
Wobbrock (ICMI 2012), portado a GDScript en `gesture_recognizer.gd`.
Licencia New BSD.

**`ARQUITECTURA.md` tiene el detalle completo**, incluidas las
decisiones que se tomaron y por qué, y los callejones sin salida que se
midieron y se descartaron.

---

## Seguir en otro ordenador

1. Instala **Godot 4.7** y clona este repositorio.
2. Abre la carpeta desde el gestor de proyectos de Godot.
3. La primera apertura tarda: Godot reconstruye `.godot/` reimportando
   todas las texturas. Es normal y solo pasa una vez.

### Límite de tamaño de textura

Ninguna textura debe pasar de ~1280 px de lado. Las tiras de efectos se
montan en **rejilla de 6 columnas**, no en tira larga: una tira de 19
fotogramas de 128 px mide 2432 px y falla al arrancar con
`Texture dimensions exceed device maximum` en cualquier tarjeta con el
tope en 2048. `tools/gen_fx.py` genera las tiras ya en ese formato.

---

## Créditos de recursos

- **Kenney Sketch Town** (CC0) — los cubos de terreno.
- **Kenney** — packs de interfaz, runas y partículas (CC0).
- Reconocedor de gestos **$P** de Vatavu, Anthony y Wobbrock (New BSD).
- Personaje, y efectos de rayo/hielo/tiempo: generados por los scripts de
  `tools/`. Son de relleno y están pensados para sustituirse.

## Las herramientas de `tools/`

Se guardan en el repo para que cada paso sea **repetible**, en vez de
acordarse de que un día alguien recortó unos PNG a mano:

| script | qué genera |
|---|---|
| `gen_iso_tiles.py` | los cubos de terreno, desde el zip de Sketch Town |
| `gen_actor.py` | las cinco hojas de animación del personaje |
| `gen_fx.py` | las tiras de efecto de rayo, hielo y tiempo |
| `gen_floor.py` | la textura de fondo sin costuras |
