# Prompts del Pantano · tanda 1 (7 de noviembre de 2026)

Las 12 piezas de **prioridad 1** del pantano de `docs/assets_biomas.tsv` (hoja **Assets_biomas** de `docs/BD_INTERACTUABLES.xlsx`) y la textura
de suelo `barro_arriba`. El pantano es el **siguiente mapa jugable**: estas piezas son las que lo hacen reconocible y las que sostienen sus
puzles. La propuesta completa está en `docs/PROPUESTA_BIOMAS.md`.

**Método de siempre:** una pieza por generación en *Text to 3D* (o *Image to 3D* con su referencia), nunca en lámina. Pega el bloque
`[ESTILO]` **al final** de cada prompt y pide el *target poly count* de cada título. Al bajar: `meshy\entrada\<id>.glb` con el id exacto →
el script de integración las junta en `arte/meshy/packs/pack_pantano.glb`.

```
[ESTILO] Stylized chibi anime game asset, hand-painted texture, soft pastel colors, Ghibli-inspired,
cute rounded chunky shapes, clean readable silhouette, soft cel shading, matte, no harsh baked shadows,
single object, centered, no base, no ground plane, no background, no outline, no black lines.
```

## Reglas que importan para que funcione en el juego

1. **Paleta del pantano** (`docs/ARTE.md` §2): verde musgo `#346A60`, verde claro `#8CAF80`, barro `#887F69`, malva `#55434F`, sombra
   `#2B253C`. Al integrarlas se ajustan a `Paleta3D` (color de la paleta × detalle en gris), como el pack Provencal.
2. **Medidas** (casilla = 2,3 u; la jugadora mide ~1; un nivel = 1,04 u): las de cada título. Origen en el centro de la base, **frente
   hacia +Z** (la cámara es fija al norte). Lo modular ocupa una casilla exacta.
3. **Triángulos**: el detalle manda. Los árboles se repetirán mucho: se piden con detalle y el motor les pone sombra reducida.
4. **Nada de brillo pintado**: las setas luminosas, el farolillo y la planta carnívora se piden apagados. La emisión y la luz las pone el
   motor. Pide las zonas que brillarán en un color limpio y liso (sombrerillos, cristal del farol) para poder hacer la máscara.
5. **Tarjetas con alfa** (musgo colgante, hojas de las eneas): bien recortadas y sin halo, porque el recorte por alfa del shader común
   (`Ocluso3D`, desde el 7/11) usa umbral 0,5.

---

## Árboles (los que dan identidad al bioma)

#### `arbol_manglar` (5 000 tris, 2048)
> A stylized mangrove tree standing on tall arching stilt roots above the water line, a rounded dark green canopy #346A60 with lighter tips
> #8CAF80, twisted grey-brown trunk, a few hanging moss strands. 2.5 units wide, 3.5 tall.

Es el árbol tipo. Entre las raíces pasa el agua de la simulación: la colisión solo en el tronco, no en el arco de raíces.

#### `cipres_calvo` (5 000 tris, 2048)
> A tall bald cypress swamp tree with a flared buttressed base, layered flat feathery green foliage, long grey-green Spanish moss hanging
> from the branches, a few knobby knee roots around the base. 2.0 units wide, 4.2 tall.

El musgo colgante en tarjetas con alfa (regla 5). Es el árbol alto: marca el horizonte del mapa.

#### `arbol_muerto` (3 000 tris, 1024)
> A dead twisted swamp tree with no leaves, gnarled grey trunk splitting into crooked bare branches, a hollow knot, a bit of pale moss,
> eerie but cute. 2.0 units wide, 3.0 tall.

Inflamable: arde y deja paso. Es el bloqueo de madera del pantano.

#### `raices_arco` (4 000 tris, 1024)
> A huge arch of tangled mangrove roots rising out of muddy water and bending over to form a passage, moss and small ferns on top, dark wet
> bark. 2.3 units wide, 1.4 deep, 2.0 tall.

Se pasa por debajo. Una variante puede cerrarse con enredadera (bloqueo que se quema).

## Pasarelas (el suelo del pantano: la jugadora no nada en el barro)

#### `pasarela_recta` (1 500 tris, 1024)
> A straight wooden boardwalk segment over swamp water: weathered planks of uneven length on two log stringers, supported by four short
> round posts, rope tied around two posts. One tile, 2.3 long, 1.4 wide, 0.6 tall.

#### `pasarela_codo` (1 800 tris, 1024)
> A 90 degree corner segment of the same weathered wooden boardwalk on round posts. One tile, 2.3 by 2.3, 0.6 tall.

#### `pasarela_rota` (1 500 tris, 1024)
> A broken segment of the same wooden boardwalk with a gap of missing planks in the middle and two snapped planks hanging into the water.
> One tile, 2.3 long, 1.4 wide.

**Las tres en la misma sesión de Meshy y con la misma referencia** (sube la recta como *Image to 3D* para el codo y la rota), para que las
tablas casen. Se pisan; la rota no: el hueco se tapa con hielo o con un bloque de tierra (puzle).

## Hito

#### `cabana_palafito` (10 000 tris, 2048)
> A cozy swamp stilt hut: a small wooden cabin with a patched thatch roof raised on crooked posts above the water, a little porch with a
> ladder down, a round window, hanging herbs and a lantern by the door facing front. 4.6 units wide, 3.0 tall.

La casa del NPC del pantano. Puerta, porche y escalera hacia +Z. El farol de la puerta se pide apagado (regla 4).

## Vegetación con mecánica

#### `juncos_altos` (1 500 tris, 1024)
> A dense clump of tall cattails with brown velvety seed heads and long thin green leaves, some bent. 0.8 units wide, 1.4 tall.

Tapa la vista y es inflamable: el fuego abre claros. Hojas en tarjetas con alfa.

#### `flor_carnivora` (2 500 tris, 1024)
> A cute oversized venus flytrap plant with two open toothed jaw leaves facing up, pink inside, green outside, soft rounded teeth, a cluster
> of small leaves at the base. 0.9 units wide, 1.0 tall.

Planta reactiva (idea de puzle: el rayo la cierra y se pisa como plataforma). Si se puede, pide las dos mandíbulas como piezas separadas
para animarlas; si no, se anima entera.

#### `seta_luminosa` (1 000 tris, 1024)
> A cluster of five slender swamp mushrooms with translucent bell caps in pale teal, thin stems, growing from a mossy log stub. 0.5 units
> wide, 0.5 tall.

Los sombrerillos en un teal liso: son la máscara de emisión. La reutiliza la cueva.

## Luz

#### `farolillo_pantano` (1 200 tris, 1024)
> A crooked wooden pole with a small hanging glass lantern on a hook, a candle inside, rope wrapped around the pole. 0.5 units wide, 1.6
> tall.

Es la luz guía del pantano (como los braseros-guía del Bosque 02). El cristal del farol en un color liso; la llama y la luz las pone el
motor (`OmniLight3D` + `LuzTitila3D`).

## Suelo

#### `barro_arriba` (textura 1024², repetible)
> Seamless tileable top-down stylized hand-painted swamp mud texture, dark olive-brown #887F69 and moss green #346A60, small glossy puddles,
> scattered tiny leaves, flat even lighting.

Va a `arte/suelo_meshy/barro_arriba.png`, como `tierra_arriba`. El brillo húmedo lo pone el shader (rugosidad), no la textura: pide los
charquitos con un tono algo más oscuro, sin reflejos pintados. Comprueba que repite sin costura (ponla 3×3 antes de subirla).

---

## Lo que ya existe y NO se genera

`sauce`, `nenufar`, `nenufar_flor`, `juncos`, `canas`, `planta_agua`, `tronco_musgoso`, `tronco_enredadera`, `tocon_hueco`, `raices_musgo`,
`raiz_mundo`, `musgo_colgante`, `setas_marrones`, `telarana`, la enredadera (`arte/meshy/enredadera/enredadera.glb`), las enredaderas
`prov_vines_group_*`, los tablones `prov_woodenplank_*`, la lámina de orilla (`arte/meshy/bosque/bosque_orilla.glb`: juncos, tocón con
musgo, nenúfares, rocas con musgo), las rocas estilizadas con musgo y la nube de veneno (`NubeVeneno3D`).

## Tanda 2 (prioridad 2–3, después)

`pilote`, `muelle`, `barca_rota`, `lirio_pantano`, `hongo_estante`, `charca_burbujas`, `caldero_bruja`, `totem_pantano`, `jaula_colgante`,
`puente_cuerda`, `isla_hierba`, `lianas_colgantes`. Sus prompts están en `docs/assets_biomas.tsv`.
