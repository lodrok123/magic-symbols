# Materiales del inventario para Meshy (29 de octubre de 2026)

Un modelo pequeño por objeto de `nucleo/datos/objetos.tsv` (columna `modelo`). Cada `.glb` sirve para **dos cosas**: el botín en el
suelo (`BotinObjeto3D`, `docs/PLAN_BASE_DATOS.md` §3.1) y el **icono de la bolsa**, que se renderiza del modelo con
`herramientas/captura_iconos.gd` (ortogonal a 60°, 128×128, fondo transparente → `arte/iconos/<id>.png`). Así el icono es del mismo
estilo que el mundo y no hay que dibujar dos veces.

**Modo:** un objeto por generación, nunca en lámina (`PROMPTS_EQUIPO.md`). Sin rig. Presupuesto: **≤ 800 triángulos** por objeto
(`PRESUPUESTO.md`): es un icono y un botín, no una pieza de escenario. Al bajarlos: `meshy\entrada\<id>.glb` con el id de la tabla;
el Pipeline los orienta (base en el origen, el lado bonito hacia −Z, que es el que ve la cámara a 60°) y los pasa a `arte/piezas/`.

**Estilo común** (pégalo al final de cada prompt; es el de `ARTE.md` §10, diorama chibi pastel):

> stylized chibi game item, soft pastel colors, hand-painted texture, chunky rounded shapes, clean simple
> silhouette, slightly oversized and toy-like, single object, no base, no ground, no hands, plain background,
> soft even lighting, front three-quarter view

**Colores:** cada objeto tiene su color en la columna `color` de la tabla; pásalo en el prompt como «main color #RRGGBB». Los
objetos **transformados por un elemento** llevan el color del elemento de `ARTE.md` §1 como acento: fuego `#F2551E`, agua `#2A9DFB`,
hielo `#5ECFF5`, tierra `#C8875A`, viento `#8FD46A`, rayo `#F2C63C`, pulso (resonante) azul claro `#99D9FF`. Si sale demasiado
realista: *"simple shapes, low detail, toy-like"*.

**Lo que ya existe y no se genera:** `setas_rojas` / `setas_azules` / `setas_marrones` (las setas y sus variantes se tiñen por
código), `alga_cueva`, `basalto_suelto`, `esquirla_cristal`, `musgo_colgante`, `helechos_cueva`, `rocas_pequenas`, `llave_pequena`,
`ropa_capa` / `ropa_capucha` / `ropa_tunica` (la ropa se enseña con el icono de la prenda renderizado del `.glb` de `arte/modelos`).

---

## Tanda 1 · ingredientes del Bosque 01 (lo que más se ve)

| id | prompt |
|---|---|
| `flor_luna` | A small pale moon flower with five rounded petals (#D9D9FF) and a soft glowing cream center, short green stem with two leaves |
| `lavanda` | A small bunch of three lavender sprigs tied with a thin string, purple-violet buds (#B38CF2), grey-green stems |
| `bayas` | A cluster of five plump red berries (#D9335A) on a tiny twig with two small green leaves, glossy highlights |
| `helecho` | A single fresh fern frond (#59BF66), gently curled tip, soft rounded leaflets |
| `flor_silvestre` | A cheerful yellow wildflower (#FFE666) with round petals and an orange center, short stem |
| `raiz` | A twisted gnarled root (#99734D), three forked ends, a few tiny root hairs, chunky and rounded |
| `resina` | A drop-shaped lump of golden tree resin (#E6A640), translucent, with a tiny bark chip stuck to it |
| `corteza` | A curved piece of thick tree bark (#8C6B4D), rounded edges, soft ridges, a bit of green moss on top |
| `panal` | A hexagon-patterned chunk of honeycomb (#F2C14E), dripping golden honey, rounded corners |
| `pluma` | A single soft downy feather (#F2F2E6), slightly curved quill, fluffy barbs at the base |
| `seda` | A ball of frost-covered spider silk (#E6E6F2) with icy sparkle, a few pale blue crystal specks (#5ECFF5) |
| `carbon` | A chunk of charcoal (#333333) with a faint orange ember glow in the cracks (#F2551E) |
| `cristal_tierra` | A rough earthy crystal cluster (#B38C4D), four stubby amber-brown prisms growing from a stone base |
| `colmillo_goblin` | A single curved goblin fang (#EBE0BD), yellowed, slightly chipped tip, tied with a thin leather strip |
| `jiron_escudo` | A torn scrap of scorched brown leather (#8C5A33) with charred black edges and a small iron rivet |
| `savia_elemental` | A glowing teardrop of green living sap (#7AD96B) with tiny leaves floating inside and a soft purple epic glow (#B86BFF) at the rim |

## Tanda 2 · ingredientes de la Cueva

| id | prompt |
|---|---|
| `esporas` | A puff of pale green spore dust (#BFE699), three small floating fluffy clumps around a tiny mushroom cap |
| `mineral_veta` | A chunk of blue-grey ore (#8094C7) with glowing light-blue veins (#99D9FF) running across its faces |
| `obsidiana` | A faceted shard of black volcanic glass (#262633), sharp but rounded edges, cool blue reflection on one face (#5ECFF5) |
| `polvo_cristal` | A small open leather pouch of glowing light-blue crystal powder (#D9F2FF), a few glittering grains spilling out |
| `ceniza_geoda` | A small pile of lavender-grey dust (#8C8CA6) with tiny glowing blue crystal chips (#99D9FF) in it |
| `baba_limo` | A wobbly blob of translucent green slime (#9EE68C) with two soft bubbles inside, glossy |
| `pluma_chaman` | A long dark-purple feather (#7A5CA6) with a bone bead and a thin cord tied to the quill, a faint green toxic tint at the tip |
| `polvo_golem` | A small heap of grey-brown stone grit (#998C80) with one tiny glowing orange rune chip on top |
| `nucleo_eco` | A floating heart-sized violet crystal core (#B86BFF) with a softer inner glow and two thin rings of light orbiting it |
| `geoda_resonante` | A split geode (#9E5CF2) showing a hollow full of glowing violet crystals, rough grey stone outside |
| `glifo_resonancia` | A small golden rune tablet (#FFD14D) with the raido rune ᚱ engraved and glowing, rounded corners, legendary sparkle |

## Tanda 3 · consumibles y pigmentos (frascos)

Todos los frascos comparten la silueta: **cuello corto, cuerpo redondo, tapón de corcho** y una etiqueta pequeña. Cambia el líquido.

| id | prompt |
|---|---|
| `pocion` | A round glass potion bottle with a cork stopper, filled with bright red liquid (#FF594D), small cream label, a heart-shaped highlight |
| `pocion_grande` | A larger round potion bottle with a cork, deep red liquid (#FF3333), gold band around the neck |
| `tonico_tinta` | A tall slim ink bottle with a cork, deep blue ink (#4D8CFF) with a white glossy drop shape inside, small quill drawn on the label |
| `balsamo_protector` | A wide squat ceramic jar with a leather lid and a cloth strap, golden balm (#F2BD47) visible at the rim |
| `infusion_brezo` | A round bottle with a cork, purple herbal infusion (#A86BDB) with a sprig of heather floating inside |
| `antidoto` | A round bottle with a cork, bright green liquid (#8CD96B) with tiny bubbles, a small leaf on the label |
| `frescor` | A round bottle with a cork, icy light-blue liquid (#7ACCFF) with frost on the glass and a snowflake on the label |
| `abrigo` | A round bottle with a cork, glowing orange ember liquid (#FF9E47) with a tiny flame inside and warm light |
| `pigmento_carmesi` | A small square ink pot with a wooden lid, crimson pigment (#D93338) dripping down one side |
| `pigmento_ocre` | A small square ink pot with a wooden lid, ochre pigment (#CC9438) |
| `pigmento_musgo` | A small square ink pot with a wooden lid, mossy green pigment (#61B84D) |
| `pigmento_ambar` | A small square ink pot with a wooden lid, glowing amber pigment (#F28C1F) with a tiny spark |
| `pigmento_eco` | A small square ink pot with a wooden lid, luminous light-blue pigment (#6BB8FF) with soft rings of light |

## Tanda 4 · piezas reactivas nuevas del mapa (escenario, no icono)

Estas van en el mundo (`PiezaPuzle3D`), presupuesto de pieza (≤ 3000 triángulos), base en el origen.

| id | prompt |
|---|---|
| `colmena` | A round papery wild beehive hanging from a short branch stub, warm tan with soft stripes (#F2C14E / #D9A640), a small dark opening, a few tiny bees as dots |
| `nido` | A small round bird nest of woven twigs (#99734D) with three pale blue eggs and two feathers sticking out |
| `cristal_cargado` | (variante del cristal resonante) A resonant crystal shard crackling with yellow lightning (#F2C63C) along its edges, light-blue body (#C7EBFF) |

## Lo que no hace falta generar

- Variantes por elemento de la seta, la flor, la raíz y el alga (`seta_asada`, `flor_rocio`, `raiz_magnetica`…): se usa el modelo
  base **teñido** con el color de la columna `color` (como ya hace `Recolectable3D` con `Paleta3D.tintar`) y, en el icono, el aro con
  el color del elemento. Si Pablo quiere icono propio para las 14 variantes, se piden en una tanda 5 con el mismo prompt base y el
  acento del elemento.
- `oro`: la moneda ya existe (`Combate3D.Botin3D`).
- Ropa bordada (`capa_escarcha`, `tunica_salamandra`, `capucha_musgo`): mismo `.glb` de la prenda con tinte y emisión. Si se
  decide hacer conjuntos propios, van en `PROMPTS_JUGADORA_BASE.md` con el esqueleto de la jugadora.
