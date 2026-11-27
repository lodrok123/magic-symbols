# Jabalí acorazado (27 de noviembre de 2026)

Pedido de Pablo: «algo más orgánico: piensa en un jabalí con armadura». Sustituye al jabalí de granito (placeholder de `Verraco3D`).
La lógica es la del verraco: embiste en línea, y lo mejor es ponerle un muro delante. Con la armadura puesta no le vale ningún
hechizo; cada choque le arranca una pieza y, sin ella, es vulnerable a todo.

**La idea:** un jabalí de monte vivo, grande y de cerda oscura, al que los goblins le han atado una barda. No es metal pulido:
cuero hervido, tablas, hueso y cuerda, del mismo taller que la empalizada y los estandartes goblin. Va rebozado en barro
húmedo de revolcarse: por eso el agua le resbala y el fuego no prende.

**Cómo se reparte el trabajo:**
- **El jabalí va sin armadura, en una malla.** Es lo que queda cuando se le cae.
- **La armadura son tres piezas aparte**, que se cuelgan en Godot y se sueltan una a una: testera, lomera y flanqueras.
  Si vienen pegadas a la malla no se pueden desprender y el rig las deforma.
- **Rig de cuadrúpedo**, como el loberno. Pose neutra: de pie, las cuatro patas rectas y separadas, cabeza al frente.

---

## 1. Imagen de concepto (los dos estados en una lámina)

**Referencia de estilo:** una captura de lado de `arte/modelos/loberno.glb` y otra de `goblin_warrior_chibi.glb`.

> Same stylized hand-painted 3D game style as the references. A wild boar, stocky and heavy, big head about a third of the
> body, short legs, dark brown bristly fur with a darker spiky mane along the spine, paler dusty belly, small amber eyes, a
> wet dark snout, two short curved ivory tusks, small ears, thin short tail. Patches of drying mud on the legs and flanks.
> Shown twice, side view, same pose, standing on four straight legs, head level: LEFT without any armour; RIGHT wearing
> crude goblin-made barding: (1) a head plate of thick boiled leather with a bone ridge down the middle and two wooden
> cheek boards, leaving eyes, snout and tusks free; (2) a back plate of overlapping leather scales stitched with thick cord
> over the shoulders and spine; (3) two side panels of rough wooden planks lashed with rope and leather straps, with big
> round rivets and a faded red goblin paint mark. Visible straps and knots under the belly and chest. Warm muted palette:
> dark browns, tan leather, bone white, dull red accent. No metal shine, no rider, no saddle. Plain light background, soft
> even lighting.

**Si sale mal:**
- **Armadura de caballero, metálica:** *"no steel, no plate metal: leather, wood, bone and rope only, crude and hand-made"*.
- **Cerdo rosa o de granja:** *"wild boar, dark bristly fur, long snout, tusks"*.
- **Demasiado realista o feroz:** *"stylized, chunky simple shapes, readable from a top-down camera"*.

## 2. Meshy, de imagen a 3D

**El cuerpo** (con la mitad izquierda de la lámina):

> stylized wild boar, dark bristly fur, tusks, standing on four straight legs, neutral pose, no armour, game creature,
> ready for quadruped rig

Nombre al instalar: `jabali`. Largo en el juego: unas 1,9 casillas (la caja de hoy es 1,3 × 2,4 × 1,9).

**Las tres piezas**, una generación cada una, sin rig:

> stylized game prop: boar head armour, thick boiled leather plate with a bone ridge and two wooden cheek boards, hanging
> straps, hollow inside, single object, plain background

> stylized game prop: boar back armour, overlapping tan leather scales stitched with thick cord, curved to sit over a
> spine, hanging straps, hollow underneath, single object, plain background

> stylized game prop: boar side armour panel, rough wooden planks lashed with rope and leather straps, round rivets, faded
> red painted mark, slightly curved, single object, plain background

- Nombres: `barda_testera`, `barda_lomera`, `barda_flanquera` (una malla; la del otro lado se refleja en Godot).
- Orden en que caen: flanqueras, lomera y testera la última (es la que choca).

## 3. Animaciones que hacen falta

| Rol | Qué | Notas |
|---|---|---|
| `idle` | quieto, hocico bajo, resopla | acecha |
| `pose` | escarba con una pata y baja la cabeza | 0,6 s: es el aviso de la embestida |
| `run` | galope bajo y pesado | la embestida |
| `frena` | clava las patas delanteras | cuando ve un muro recién puesto |
| `choque` | rebota hacia atrás y sacude la cabeza | se enlaza con el aturdido |
| `aturdido` | tambaleo en el sitio | 2 s |
| `hit` / `death` | | la muerte, de lado en el suelo |
