# Prompts: tronco-puente, bloqueo de enredaderas y libro + pluma + mano (16 de octubre de 2026)

Tres encargos: **(A)** el tronco-puente de Bosque 01 (`TroncoPuente3D`, entrada 110 del diario; hoy un cilindro), **(B)** un bloqueo de enredaderas que arde y se abre, con restos quemados,
y **(C)** el libro, la pluma y la mano escribiendo (hoy 2D por capas: `ManoPluma2D`, entrada 103). Más, de regalo, **(D)** el tronco del estanque (`TroncoEstanque3D`, el otro pedido de la 110).
Mismo método que `PROMPTS_PIEZAS_PUZLE.md` y `PROMPTS_LAB_FUEGO.md`: **una pieza por generación**, *Text to 3D* (o *Image to 3D* donde se indica), pega el bloque [ESTILO] **al final** de
cada prompt y refina con el *target poly count* y la textura de cada título. Al bajar: `meshy\entrada\<id>.glb` → `INTEGRAR_PIEZAS.cmd` → `CatalogoAssets` tecla H (o me pasas los GLB y los integro yo).

```
[ESTILO] Stylized chibi anime game asset, hand-painted texture, soft pastel colors, Ghibli-inspired,
cute rounded chunky shapes, clean readable silhouette, soft cel shading, matte, no harsh baked shadows,
single object, centered, no base, no ground plane, no background, no outline, no black lines.
```

## Reglas que NO son de estilo
1. **Nada de fuego, brasas ni brillo pintado.** Lo quemado se pide **ya quemado** (negro, agrietado, ceniza) y **sin brasas**: las llamas y las brasas las pone el motor (`Enredadera3D`, `Vfx3D`).
2. **Lo que arde tiene dos mallas, viva y quemada**, con **el mismo tamaño y el mismo origen** (así el cambio no salta; es lo que ya hace `enredadera.glb`).
3. **Origen**: centro de la base (y = 0 el suelo), salvo donde se diga. **Frente hacia +Z.** Medidas: las del título (casilla = 2,3 u; la jugadora mide ~1); si Meshy no las respeta se escalan al integrar.
4. **Verde de las enredaderas**: el mismo de `enredadera.glb` (verde hoja medio, pastel, sin amarillos) para que no desentonen con las que ya existen. **Sin flores rojas ni azules** (los colores de elemento son del motor).
5. **Sin texto** en nada, ni runas pintadas.

## Prioridad
1) **A** tronco-puente en pie y caído, 2) **B** bloqueo vivo y quemado, 3) **C** mano con pluma (3 poses) y libro, 4) restos quemados y pluma suelta, 5) **D** tronco del estanque.

---

## A. Tronco-puente (Bosque 01, K10 → J10)

Un tronco **de pie** a la orilla del río, con enredaderas; al recibir fuego **cae siempre hacia delante (+X local)** sobre la casilla del río y se hace puente. El Juego lo gira entero (1 s) alrededor de
**su pie**, así que el modelo es **un tronco con el origen en el pie**. Para que alcance la otra orilla mide **2,6 de largo** (la casilla del río es de 2,3).

### A1. `tronco_puente_pie` (2 000–3 500 tris, textura 1024–2048)
> A tall dead tree trunk standing upright, chunky and slightly tapered, thick bark with deep grooves, a few stubby cut-off branch stumps, a broken jagged top, mossy roots flaring at the foot,
> and several thick green climbing vines winding around it from bottom to top with a few big leaves. Vertical, straight enough to fall forward like a bridge: no big side branches.
> Height 2.6 units, diameter 0.7 units at the base and 0.5 at the top. **Origin at the center of the base** (the foot). Flat cut at the bottom.

### A2. `tronco_puente_caido` (2 000–3 500 tris, textura 1024–2048)
> The same dead tree trunk lying on the ground, perfectly straight along the X axis, after it burned: the bark scorched black and cracked in places, the pale wood showing through the cracks, a flat
> walkable top about 0.55 units wide, the green vines burnt to thin black crumbly strands hanging along the sides, a little white ash at the cracks. **No fire, no embers, no smoke, no glow.**
> Length 2.6 units, diameter 0.7 units, resting on its side. **Origin at the center of the foot end, at ground level**, the trunk running toward +X.

*Si prefieres un solo modelo: genera solo A1 y el Juego lo gira (el aspecto quemado lo pone el motor con un tinte oscuro y llamas). A2 es el cambio de malla «se ha quemado».*

---

## B. Bloqueo con enredaderas

Una pared de enredaderas espesas que **cierra el paso** de una casilla y **arde** para abrirlo (la mecánica de `Enredadera3D`: viva → ardiendo → quemada → se deshace).

### B1. `bloqueo_enredaderas` (2 500–4 500 tris, textura 1024–2048)
> A dense wall of thick tangled green vines blocking a path: a knotted barrier of woody vine stems twisting over and under each other, big round leaves, a few small thorns, roots spreading at the
> bottom and two stubby wooden stakes at the sides holding it up. Wider than tall, solid and impassable, no gaps you could walk through.
> 2.2 units wide, 1.6 units tall, 0.5 units deep. **Origin at the center of the base.** Same green as the other game vines.

### B2. `bloqueo_enredaderas_quemado` (1 800–3 500 tris, textura 1024–2048)
> The same vine barrier after burning: every vine charred black and brittle, twisted and broken, leaves gone, collapsed to about 60 percent of the height, the two wooden stakes scorched, grey ash
> clumped at the roots, an open gap in the middle where the barrier fell. **No fire, no embers, no smoke, no glow.**
> Same footprint as the living one: 2.2 units wide, 0.5 deep, 1.0 tall at most. **Same origin (center of the base).**

### B3. `enredadera_quemada_a` y `enredadera_quemada_b` (200–500 tris cada una, textura 512)
Restos pequeños para esparcir donde arde una enredadera (los pone la maqueta; el Juego no los ve).
> (a) A small tangle of charred black vine strands curled on the ground, a few brittle twigs, a pinch of grey ash, flat and low. 0.6 units wide, 0.15 tall.
> (b) A short burnt vine stump with two blackened roots sticking out, cracked and crumbly, a little grey ash around it. 0.5 units wide, 0.3 tall.
> No fire, no embers, no glow.

### B4. `ceniza_enredadera` (80–200 tris, textura 256)
> A flat irregular patch of soft grey ash with a few tiny black charred twig pieces on it, very low, almost flat. 0.9 units across, 0.03 tall. No glow.

---

## C. Libro, pluma y mano escribiendo

Hoy la mano es un sprite 2D por capas (`presentacion/ui/laminas/mano_pluma.png`, `mano_escribiendo.png`, `mano_levantada.png`) que el Juego mueve sobre el libro (`ManoPluma2D.apuntar/punta`). Con estos modelos
la mano se **renderiza desde arriba a PNG** (SubViewport, fondo transparente) y sustituye a los de hoy **sin cambiar la API**; el libro 3D sirve para el fondo y para el libro en las manos de la jugadora.
**La tinta no se modela** (es `TintaPluma2D`, en código).

**Consejo importante para la mano:** Meshy falla mucho con manos. Usa **Image to 3D con el PNG que ya existe** de cada pose (`mano_pluma.png`, `mano_escribiendo.png`, `mano_levantada.png`) como imagen de entrada y el
texto de abajo como refuerzo: así conserva el estilo y los dedos de las que ya se ven en el juego.

### C1. `mano_pluma_reposo` · C2. `mano_pluma_escribiendo` · C3. `mano_pluma_levantada` (1 500–3 000 tris cada una, textura 1024)
> A single chibi right hand seen from above holding a quill pen: chubby simplified hand with four short rounded fingers and a thumb, no fingernails detail, a wide cream sleeve cuff with a thin brown
> trim at the wrist, the long white feather quill held between thumb and index finger with a small dark metal nib at the tip. Smooth cartoon skin, soft pastel colors. No arm beyond the cuff, no ink, no text.
> - **reposo (C1):** relaxed, the quill tilted up about 30 degrees, the hand resting flat.
> - **escribiendo (C2):** the quill tilted down about 55 degrees with the nib touching the page, fingers pinched firmly.
> - **levantada (C3):** the hand lifted, the quill pointing up about 70 degrees, fingers loose.
> Size: hand 0.5 units long, quill 0.7 units long. **Origin at the nib (the pen tip)**, the pen pointing toward +Z, back of the hand facing up (+Y).

### C4. `pluma` (300–700 tris, textura 512)
Suelta, para el icono del objeto y la animación de la tinta.
> A long white feather quill pen lying straight, soft curved feather vane with a few split barbs, a pale cream shaft and a small dark metal nib at the tip. Length 0.7 units, 0.1 wide. No ink. **Origin at the nib**, pointing toward +Z.

### C5. `grimorio_abierto` (2 500–4 500 tris, textura 1024–2048)
> An open magic spellbook seen from above lying flat: two blank cream parchment pages slightly curved toward the spine, a thick dark brown leather cover with chunky corners and small brass corner
> protectors, a thin red ribbon bookmark between the pages, a few stacked page edges at the sides. **The pages are completely blank: no text, no runes, no drawings.** 1.4 units wide, 1.0 deep, 0.25 tall.
> **Origin at the center of the spine, on the table.** Pages facing +Y.

### C6. `grimorio_cerrado` (1 500–3 000 tris, textura 1024)
> The same spellbook closed, lying flat: dark brown leather cover with chunky brass corner protectors, a leather strap with a small brass clasp, a plain round brass medallion on the front with **no symbol**,
> cream page edges visible at the side. 0.7 units wide, 1.0 deep, 0.25 tall. **Origin at the center of the base.** Front cover facing +Y.

---

## D. (extra) Tronco del estanque

Pedido (b) de la entrada 110: **sube con el agua** hasta quedar a ras y dejar pasar. Un solo modelo (el Juego lo sube y baja).

### D1. `tronco_estanque` (1 500–3 000 tris, textura 1024)
Medidas tomadas de `TroncoEstanque3D` (diámetro 0,6, largo 2,6): el código lo gira a lo largo de `eje` y lo sube y baja, así que **el origen es el CENTRO DEL EJE del tronco** (no la base).
> A thick fallen log lying horizontally, dark damp bark with a couple of knots, thick bright green moss covering most of the top, a few small ferns and soft green vines hanging off the sides, a flat-ish walkable top, both ends cut flat with visible tree rings. Chunky rounded shapes, slightly tapered, no branches sticking out. Length 2.6 units along the X axis, diameter 0.6 units. **Origin at the center of the log (the middle of its axis)**, lying along +X, moss facing +Y. No water, no ground, no roots.
> + [ESTILO]

**Nota (16/10, Pablo):** `grimorio_cerrado` y `grimorio_abierto` (C5, C6) **ya no hacen falta**: el libro cerrado es el render 3D de Pablo y las páginas son la lámina 2D (`docs/ARTE.md` §16).

---

## Resumen (14 generaciones)
| Tanda | Piezas | Para |
|---|---|---|
| 1 | `tronco_puente_pie`, `tronco_puente_caido` | A · `TroncoPuente3D` |
| 2 | `bloqueo_enredaderas`, `bloqueo_enredaderas_quemado` | B |
| 3 | `mano_pluma_reposo`, `mano_pluma_escribiendo`, `mano_pluma_levantada` | C · `ManoPluma2D` |
| 4 | `grimorio_abierto`, `grimorio_cerrado`, `pluma` | C |
| 5 | `enredadera_quemada_a`, `enredadera_quemada_b`, `ceniza_enredadera` | B (restos) |
| 6 | `tronco_estanque` | D · `TroncoEstanque3D` |
