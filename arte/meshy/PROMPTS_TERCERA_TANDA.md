# Tercera tanda: la cascada, lo que falta de la Cueva y los iconos del HUD (24 de octubre de 2026)

Pablo: «dame más prompts, necesito algunos más para generar». Sale de lo que hoy sigue siendo provisional en las capturas
(`docs/capturas/cueva_cascada/`, `docs/capturas/cueva_completa/`, `docs/capturas/hud_eow/`) y de `docs/PENDIENTES.md`.

Método de siempre (`PROMPTS_CUEVA.md`, segunda tanda): **hojas de 4–6 piezas**, una imagen con las piezas separadas sobre fondo liso → un
GLB → `recibir_assets.py ver` / `lote --escalera` / `instalar`. Cada pieza lleva su id, que es el nombre con que el mapa la pide. Si una
pieza sale mal en la hoja, se pide sola (*Text to 3D*, o *Image to 3D* con la imagen de la hoja recortada). Bloque [ESTILO] al final:

```
[ESTILO] Stylized chibi anime game asset, hand-painted texture, soft pastel colors, Ghibli-inspired,
cute rounded chunky shapes, clean readable silhouette, soft cel shading, matte, no harsh baked shadows,
single object, centered, no base, no ground plane, no background, no outline, no black lines.
```

Reglas de la Cueva (las mismas): casilla = 2,3 u, la jugadora mide ~1, origen en el centro de la base, frente hacia +Z; **nada de brillo
ni agua pintados** (el agua, la espuma y la luz las pone el motor); piedra **azul grisácea** de la familia de `pared_foso_cueva`; sin texto.

---

## F1. Hoja «cascada» — para la cascada de C2 (prioridad 1)

Referencia: los fotogramas del vídeo de EoW (cortinas entre pilares de roca con musgo, espuma al pie). Hoy son cajas
(`Puzle3D._levantar_terraza`, ver `c2_cascada_terraza_v3.png`).

#### `pilar_cascada` (600–1 200 tris) — separa dos cortinas (ya pedido en `PROMPTS_CUEVA.md` §E; va en esta hoja)
> A tall narrow cave rock pillar standing between two waterfalls: a chunky stack of rounded blue-grey stones fused into one column,
> flat almost vertical left and right sides, a rounded bulging front face with soft cracks, the lower third darker and damp, a thick
> cap of soft green moss spilling over the top edge with a small fern tuft and two or three tiny butter-yellow flowers, no water,
> no glow. 0.8 units wide, 3.1 tall, 1.6 deep.

#### `pilar_cascada_ancho` (700–1 400 tris) — el de los flancos, más ancho, para que las cortinas no parezcan de tamaño igual
> A wide cave rock buttress at the side of a waterfall: two or three big rounded blue-grey boulders stacked and fused, one flat
> vertical side facing the water, the other side rough and rounded, damp darker base, a mossy top with ferns hanging over the edge,
> no water, no glow. 1.4 units wide, 3.1 tall, 1.6 deep.

#### `labio_cascada` (400–800 tris) — el borde de la cornisa por donde se desborda el agua
> A long smooth stone lip at the edge of a rock ledge where water spills over: one rounded worn slab, slightly dipped in the middle,
> polished and darker where the water runs, small moss tufts at both ends, flat underside and flat back. One tile long (2.3), 0.6 deep,
> 0.35 tall.

#### `rocas_salpicadura` (300–700 tris) — rocas al pie de la caída que asoman del agua
> A small group of three wet rounded boulders of different sizes huddled together, as if sticking out of a pool at the foot of a
> waterfall, dark blue-grey with a damp sheen, a little moss on the tallest one, flat bottom. 1.2 units wide, 0.6 tall.

#### `musgo_colgante` (300–600 tris) — cortina de musgo y raíces que cuelga del borde de la cornisa
> A fringe of hanging moss and thin roots draping down from a ledge edge: a flat mossy strip on top with soft green strands and a few
> thin roots hanging down unevenly, flat back to sit against a wall. 1.2 units wide, 0.9 tall, 0.2 deep.

#### `helechos_cueva` (300–600 tris) — mata para los bordes del pozo
> A clump of cave ferns with five or six curling fronds in muted teal-green, paler tips, growing from a tiny mossy stone, compact.
> 0.7 units wide, 0.6 tall.

## F2. Hoja «C3 y C4» — lo que falta de los puzles (prioridad 2)

#### `geoda_resonante` (600–1 200 tris) — la geoda de la pared hueca de C3 (`docs/MATERIALES_CUEVA.md`)
> A big rough blue-grey boulder split open on its front face, the hollow inside lined with many small pale aquamarine crystals pointing
> inward, matte crystals with clean facets, a few cracks around the opening, flat bottom, no glow. 1.2 units wide, 1.0 tall.

#### `estalagmita_resonante` (400–900 tris) — las estalagmitas que vibran con el pulso en C4 (aún no existen)
> A single tall slender stalagmite of blue-grey wet rock with three thin rings of pale aquamarine crystal embedded around it at
> different heights, a rounded tip, a wider base with drips, matte, no glow. 0.6 units wide, 1.8 tall.

#### `estalagmita_rota` (300–600 tris) — la misma, caída tras vibrar (estado roto)
> The same slender cave stalagmite broken in two: the stump still standing with a jagged top and the upper part lying on its side
> next to it, pale aquamarine crystal rings visible at the break, a few pebbles. 1.4 units wide, 0.7 tall.

#### `brasero_cueva` (500–1 000 tris) — el brasero de C1 con piedra de cueva (el de ahora es del Bosque)
> A low round stone fire bowl on three short stubby legs, carved blue-grey stone with one simple engraved ring, an empty bowl with a
> few charcoal lumps inside, **no fire, no embers, no glow** (the fire is added in the game). 0.9 units wide, 0.9 tall.

**Recordatorio:** la hoja **D3 «recolectables»** de `PROMPTS_CUEVA.md` (`alga_cueva`, `basalto_suelto`, `mineral_veta`,
`esquirla_cristal`, `jarron_roto`) sigue sin generar; si quieres, va en la misma tanda.

## F3. Iconos 2D de los consumibles nuevos del HUD (prioridad 2)

Hoy se dibujan en código (`Objetos.dibujar`) y `prueba_escritura_hud` los exime hasta que tengan PNG. Se piden como **imagen**, no como
modelo: **128 × 128, fondo transparente**, el mismo estilo plano que `presentacion/ui/laminas/objeto_pocion.png` (vector limpio, un brillo
blanco, sin contorno negro, sin sombra). Van a `presentacion/ui/laminas/objeto_<id>.png`.

```
[ICONO] Flat vector game item icon, clean simple shapes, soft flat colors with one small white highlight, no black outline,
no drop shadow, centered, transparent background, 128x128.
```

#### `objeto_tonico_tinta.png`
> A tall slim glass vial with a cork stopper, filled with deep blue ink, a single pale blue drop shape on the glass + [ICONO]

#### `objeto_balsamo_protector.png`
> A small round squat jar with a wide golden lid, filled with a pale golden-amber balm, a tiny shield shape engraved on the front + [ICONO]

#### `objeto_infusion_brezo.png`
> A small round clay cup of warm purple-pink herbal tea with a sprig of heather (small purple flowers) resting on the rim + [ICONO]

---

## Total

| hoja | piezas | prioridad |
|---|---|---|
| F1 cascada | 6 | 1 |
| F2 C3 y C4 | 4 | 2 |
| F3 iconos HUD | 3 (imágenes) | 2 |

**13 piezas.** Ninguna bloquea el juego: hasta que lleguen siguen las cajas, las piezas teñidas y los iconos en código.
