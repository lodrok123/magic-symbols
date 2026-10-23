# Jugadora base y túnica aparte (23 de octubre de 2026)

**Por qué:** las mangas de `woodland_wanderer` solapan con el cuerpo al doblar el brazo. Cuerpo, mangas, capa y túnica son una sola
malla con pesos automáticos, así que la tela y el brazo tiran de los mismos huesos. Con un **cuerpo base** y la **ropa en piezas
aparte** sobre el mismo esqueleto, cada prenda lleva sus pesos (más suaves en lo ancho) y cambiar de ropa es cambiar una pieza, que es
lo que pide la decisión 4 del Pulso (los ingredientes épicos pueden dar ropa nueva).

**Lo que no cambia:** el esqueleto `mixamorig` y las 22 animaciones de la elfa (`chibi_elf`/`woodland_wanderer`), la altura en el juego
(1,0 u), la cara y los ojos pequeños. La base tiene que poder llevar **las mismas animaciones sin retarget** (mismo rig de Mixamo).

**Antes de generar:** las decisiones de `docs/PLAN_RIGGING.md` §7 (A-pose o T-pose, esqueleto ligero o con dedos, quién encaja el
maestro). Estos prompts asumen la propuesta del plan: **A-pose** y Mixamo.

---

## 1. Jugadora base (cuerpo con ropa ceñida)

Todo lo que se queda siempre puesto va en la base, **ceñido al cuerpo**: nada que cuelgue ni que se separe del brazo o de la cadera.

**Referencia de estilo:** una captura de frente de `woodland_wanderer` (la jugadora de hoy) para la cara, el pelo y la proporción.

> Same 3D chibi character style, same body proportions, same head size and SAME SMALL GENTLE EYES as the reference elf girl (about 3
> heads tall). This is her BASE outfit, everything tight-fitting: a cream long-sleeve fitted shirt with sleeves tight to the arms down
> to the wrists, a dark brown fitted vest laced at the front, a slim brown leather belt sitting on the waist with no pouches or
> hanging straps, dark green fitted leggings, brown leather knee boots that hug the calves. Peach-orange hair in a SHORT BOB that ends
> above the shoulders, tucked behind the long pointed ears (so a hood can go over it later). No cloak, no hood, no cape, no skirt, no
> tunic, no loose fabric, no book, no props. Full body, front view, symmetrical A-pose with arms 35 degrees away from the body, palms
> down, fingers apart, legs slightly apart, plain light background, soft even lighting.

**Versión corregida (23/10, tras la primera imagen):** la primera salió con ojos de chibi grandes y brillantes, unas 4,5 cabezas de
alto y botas con puño ancho. Esta lo corrige; se pasa con la primera imagen como referencia de pose y ropa:

> Same character, same A-pose and same outfit as the reference image, with three changes. 1) PROPORTIONS: chibi, about 3 heads tall,
> big head, shorter body and short legs, like the reference elf girl from the game. 2) EYES: small gentle eyes, 25% smaller than the
> reference, soft brown, no sparkles, no big highlights, calm friendly expression. 3) BOOTS: slim knee boots that hug the calves, the top
> of the boot flush with the leg with no wide flared cuff, a single thin strap with a small buckle. Keep everything else tight-fitting:
> cream long-sleeve fitted shirt tight to the wrists, dark brown laced vest, slim belt without pouches, dark green fitted leggings,
> peach-orange short bob above the shoulders with the long pointed ears out. Empty hands, no props. Full body, front view, symmetrical
> A-pose with arms 35 degrees away from the body, palms down, fingers apart, legs slightly apart, plain light background, soft even
> lighting.

**Si sale mal:**
- **Ojos grandes:** *"eyes 25% smaller, no sparkles in the eyes"*.
- **Ropa holgada o mangas anchas:** *"all clothing skin-tight, sleeves tight to the arms"*.
- **Pelo largo por la espalda:** *"short bob haircut above the shoulders"*.

**Meshy, de imagen a 3D:**

> chibi elf girl base body, tight-fitting clothes, A-pose, empty hands, game character, ready for rig

Rig con Mixamo (como la elfa de hoy), para que los 22 clips valgan tal cual. Nombre al instalar: `jugadora_base`.

---

## 2. La ropa de encima, en piezas aparte

Cada prenda se genera **sobre la misma silueta de la base** para que encaje sin estirarla. El camino que mejor sale con IA:

1. **Imagen de la base vestida.** Con la imagen de la base como referencia, se pide la misma figura **con la prenda puesta** (prompts de
   abajo).
2. **Imagen de la prenda sola.** Con esa imagen como referencia: *"the same garment alone, worn by an invisible body, same pose and same
   size, nothing else"*.
3. **Meshy, de imagen a 3D, SIN rig:** la prenda sola. En Blender, con el script de encaje del plan de rigging: se coloca sobre la
   base, se le **transfieren los pesos del cuerpo** y se **suavizan** en brazos y cadera. Máximo 4 influencias por vértice.

### 2a. Capa corta con capucha (la seña de la jugadora)

> The same elf girl in the same A-pose wearing a forest-green hooded CAPELET over her base outfit: a short cape that covers only the
> shoulders and upper arms and ends at the elbows, cream trim along the edges, the hood UP over the short hair with the long ears
> poking out through slits, a small round wooden clasp at the chest. The capelet stands slightly away from the arms (no fabric fused
> to the arms). Plain light background.

- **Por qué corta:** una capa que baja más allá del codo es lo que hoy choca con las mangas. Hasta el codo, el brazo dobla por debajo.
- **La capucha** va puesta y sigue a la cabeza (hueso `Head`); las orejas salen por las aberturas, como ahora.

Nombre: `ropa_capa_capucha`.

### 2b. Túnica

> The same elf girl in the same A-pose wearing a forest-green sleeveless TUNIC over her base outfit: it starts at the shoulders, is
> cinched at the waist under the belt and flares to mid-thigh with side slits up to the hip, cream embroidered hem with small leaf
> motifs. NO SLEEVES (the arms show the tight cream shirt). Plain light background.

- **Sin mangas** a propósito: las mangas son de la base, ceñidas, y no pueden chocar.
- **Las aberturas** dejan doblar las piernas al correr sin que la falda se estire.

Nombre: `ropa_tunica`.

### 2c. Cinturón del libro (opcional)

> A brown leather belt with a small book holster on the left hip and a round brass buckle, same size as the elf girl's waist, alone,
> plain light background.

Va como pieza de equipo (como las dagas o el escudo): el libro se cuelga ahí cuando no se lanza.

Nombre: `ropa_cinturon_libro`.

---

## 3. En el juego

- `jugadora_base` con sus 22 clips de `chibi_elf`. Encima, `ropa_capa_capucha` y `ropa_tunica` como mallas con el **mismo esqueleto**
  (en Godot, `MeshInstance3D` con `skeleton` apuntando al de la base), así que siguen cada animación sin código.
- La ropa nueva que den los ingredientes épicos es otra prenda generada igual (misma silueta, mismo esqueleto).
- **Prueba de que funciona:** las 6 poses de `PLAN_RIGGING.md` §3 (brazos arriba, sentadilla, zancada, giro de cintura, cabeza a los
  lados, cast) con captura, y que ninguna prenda atraviese el brazo al doblar el codo.
