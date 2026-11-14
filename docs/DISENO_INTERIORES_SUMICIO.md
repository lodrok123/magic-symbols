# Interiores de Monte Sumicio: pallozas y Torre Verde

Propuesta de diseño (14/11/2026) a partir del PPTX `Monte-Sumicio` (láminas 6–12, 18–22 y 24–29, 43). Las láminas están en
`docs/capturas/monte_sumicio/pptx/` (`lamina_NN_1.jpeg`). Es para revisar con Pablo **antes** de construir.

## Qué hay hoy

- **Pallozas** (`escenas/interior_palloza.gd`, `InteriorPalloza.tscn`): sala cuadrada de 5 × 5 casillas con cajas de color; Ástrago medio escalón más alto,
  hogar, vara de ahumado, banco, arcón, pesebre y tabique (`arte/piezas/interior_palloza_familiar.tscn`). Tres familiares (Iria, Brais, Sabela) y la tienda del este.
- **Torre Verde** (`escenas/interior_torre.gd`, `InteriorTorre.tscn`): solo la planta baja, 7 × 7 redonda, con Marimanta, sus cofres, un cofre mágico,
  el hueco central y una escalera de decorado.
- Cámara fija desde el sur a ~57° (como el exterior). Todo se lee desde arriba: lo importante tiene que verse en planta.

## Reglas comunes

1. **Se lee en planta.** Cada sala tiene 1–2 cosas grandes que la identifican desde la cámara (el fuego, el hueco de la torre, las estanterías curvas).
2. **El muro sur es bajo** (como ya hace la torre) para que la cámara vea dentro; los muebles altos van al norte.
3. **Luz cálida y dirigida:** cada sala tiene una fuente (el hogar, las velas, una ventana) y el resto en penumbra, como las láminas.
4. **Cada sala tiene algo que hacer** (hablar, abrir, recoger, una pista), pero poco: es un respiro entre zonas de juego.
5. **Reaprovechar antes que crear**: banco, arcón, pesebre, hogar, barril, caja, jarrones, `prov_bench`, `prov_stool`, pociones. Lo nuevo se pide a Meshy (lista al final).

---

## 1. Palloza familiar (Iria, Brais, Sabela) — láminas 8–12 y 18

> «Un solo espacio en penumbra, sin chimenea: el humo del hogar se filtra por la paja.» · «Tres generaciones bajo el mismo techo.»

Planta redonda dentro de la rejilla 5 × 5 (las esquinas son muro). De sur a norte: **umbral → Travariza (abajo) → Ástrago (medio escalón arriba)**.

```
        N
   ┌─────────────┐
   │ ░ HO  AR  ░ │   HO horno de pan (lám. 10) · AR arcas del grano (lám. 12)
   │ AP  🔥  BA  │   🔥 hogar central SIN chimenea, humo que sube a la paja · BA banco (la abuela)
   │ ▲▲▲▲▲▲▲▲▲▲ │   ▲ borde del Ástrago (medio escalón)
   │ VA  ·  PE   │   VA valla de la Travariza · PE pesebre con la vaca / el cerdo aparte
   │ ░  [ ]   ░ │   [ ] umbral y puerta baja
   └─────────────┘
        S
```

- **Ástrago (norte, alto):** el hogar en el centro con las **varas de ahumado** encima (chorizos y castañas, lám. 10). Al norte el **horno de pan** y
  las **arcas**. Al oeste **aperos y yugos** colgados del muro (lám. 12). Al este el **banco** junto al fuego.
- **Travariza (sur, baja):** la vaca tumbada en paja y un cerdo en un reservado (lám. 11), tras una valla baja. Calienta la casa: el humo y la luz del
  hogar llegan hasta aquí.
- **Gente:** tres generaciones (lám. 18): abuela en el banco, padre o madre de pie, un niño junto al fuego. Hoy solo hay un vecino por casa:
  propongo **2–3 figuras** por palloza, solo una habla.
- **Variaciones entre casas** (para que no sean iguales): Iria con la mesa del pan; Brais con más paja y el cofre junto al pesebre (ya existe);
  Sabela con telar o cestería.
- **Qué se hace:** hablar (pistas y ambiente), el **cofre** de cada casa (ya existe), y como mucho **un objeto** que se recoge (castañas, pan).
- **Luz:** el hogar como única luz, naranja; un haz de humo/luz en el centro, como la lámina 8.

## 2. Palloza del gremio del gorro verde — láminas 19–20

> «En las pallozas de gremio, el espacio que debería ser para los animales se ocupa con un obrador de venenos y una armería.»

Es la misma palloza, pero **la Travariza es un taller**: mesa con mortero y frascos (lám. 20), armero con cuchillos, y por las paredes **lo robado**
(gafas, vestidos, joyas, dentaduras postizas) colgado como moneda. Cuatro o cinco cacos de verde. Sin animales ni calor: más fría y oscura.

- **Qué se hace:** **trueque** (ellos venden lo robado) y quizá una secundaria. Hoy no existe esta casa: hay que **decidir cuál es** (ver dudas).

## 3. La tienda del este (ya existe)

Mostrador y mesa de síntesis. Propuesta: que se note que es **de Sumicio**: sacos de lo robado detrás del mostrador (lám. 19), frascos como los del
gremio, y la tendera con su gorro. Mismo uso que hoy (comprar, vender, sintetizar).

---

## 4. La Torre Verde por dentro — láminas 24–29 y 43

> «Plantas circulares apiladas alrededor de un hueco central, recorridas por una escalera de madera. La luz entra por los balcones de roble y castaño.
> Desde las terrazas se cuela musgo, helecho y hiedra hacia el interior.»

**Estructura común de cada planta:** sala redonda de 7 × 7 casillas (como la planta baja de hoy), **hueco central** con barandilla de madera
(no se pisa; desde arriba se ve la planta de abajo en penumbra), **escalera de madera pegada al muro** que sube a la siguiente planta, y una o dos
**ventanas-balcón** por donde entra la luz y cuelgan hiedra y helecho. Cambiar de planta = subir o bajar la escalera con un fundido corto,
como las puertas.

### Orden de plantas (de abajo arriba), según el PPTX

| Planta | Sala | Lámina | Qué hay | Qué se hace |
| --- | --- | --- | --- | --- |
| 0 · Baja | **Sala de lectura (el aula)** | 27 | Mesas largas con pergaminos, pupitres pequeños, la ventana a la montaña. Marimanta enseña aquí. | Entrada desde la puerta. Las clases de las asignaturas (futuro). |
| 1 | **Sala de estudio** | 26 | Pupitres y atriles de castaño a escala sumiciu, una vela en cada pupitre, aprendices de rojo copiando. | Hablar con aprendices (pistas de las asignaturas). |
| 2 | **La biblioteca** | 25 | Anaqueles curvos que siguen el muro, rodeando el hueco; el **archivo de mapas**, cerrado. | Leer libros (lore). Los mapas, bloqueados hasta el Nivel I. |
| 3 | **Celdas de aprendices** | 28 | Celdas pequeñas de piedra: cama baja, arcón, ventana estrecha. Una es la de Mid. | **Dormir/guardar** en la celda de Mid (cuando sea alumna). |
| 4 · Alta | **Despacho de Marimanta** | 29, 43 | Mesa, sillón, su bastón, velas, humo de la visita de Pedro Chosco en sueños. | **La audiencia** y la entrega de encargos; sus cofres. |

**Cambio que implica:** hoy la audiencia es en la planta baja. Según el PPTX, el despacho está **arriba**. Propongo: al entrar la primera vez, el
guardia o un aprendiz te sube al despacho (o subes tú por la escalera), y la planta baja queda como aula.

### Plano tipo de una planta

```
            N  (ventana-balcón)
      ┌───╮───────────╭───┐
      │  ╱  ▓▓  ▓▓  ▓▓  ╲ │   ▓ muebles altos pegados al muro norte (anaqueles, camas, pupitres)
      │ │   ▓       ▓    E│   E escalera de madera pegada al muro (sube al norte, baja al sur)
      │ │      ╔═══╗     E│
      │ │ ▓    ║ H ║   ▓ E│   H hueco central con barandilla (no se pisa)
      │ │      ╚═══╝      │
      │  ╲    ·     ·   ╱ │   muro sur bajo: la cámara ve dentro
      └──────── [ ] ──────┘   [ ] la puerta (planta baja) o el rellano de la escalera (resto)
            S
```

---

## Decisiones de Pablo (14/11/2026)

- **La audiencia sube al despacho** (planta alta). La planta baja es el aula; se sube por la escalera con un fundido corto entre plantas.
- **El gremio del gorro verde va en una palloza NUEVA** (la quinta); Iria, Brais y Sabela siguen siendo familias.
- **Las cinco plantas de la torre se construyen ya** (aula, estudio, biblioteca, celdas, despacho), con formas simples donde falten piezas.
- **Los muebles nuevos los genera Pablo en Meshy** (lista abajo, con el texto para pegar). Mientras llegan, van formas simples en su sitio y escala,
  para cambiarlas por el .glb sin mover nada.

## Piezas que hacen falta (para pedir a Meshy)

Reaprovechables ya: hogar, banco, arcón, pesebre, tabique, barril, caja, jarrones, pociones, `prov_bench`, `prov_stool`.

**Pallozas:** horno de pan de barro · varas de ahumado con chorizos · yugo y aperos (hoz, horquilla) · arca del grano · vaca tumbada · cerdo ·
haz de paja · cesto · telar pequeño.
**Gremio:** mesa de obrador con mortero y frascos · armero con cuchillos · montón de objetos robados (gafas, dentaduras, joyas).
**Torre:** barandilla curva de madera · tramo de escalera de madera · pupitre bajo · atril · vela sobre platillo · anaquel curvo con libros y rollos ·
cama baja de aprendiz · mesa larga de lectura · sillón y mesa de Marimanta · hiedra/helecho colgante (ya hay `musgo_colgante`, `prov_vines_*`).

### Texto para Meshy (estilo común + una línea por pieza)

Estilo común para todas (pegar delante): *stylized hand-painted fantasy prop, Galician rural medieval, chunky readable shapes for a top-down
3/4 camera, warm muted earthy palette, worn wood and granite, low poly, single object, no base, no background.*

Tamaño de referencia: una casilla del juego mide 2,3 m; Mid mide ~1,2 m; los Sumicius son bajitos (muebles «a su escala», más bajos de lo normal).

| Pieza (archivo) | Descripción para Meshy | Tamaño aprox. |
| --- | --- | --- |
| `horno_pan` | clay bread oven, dome shaped, small arched mouth, soot stains, built against a stone wall | 1,2 × 1,0 × 1,0 m |
| `varas_ahumado` | wooden drying rack hanging over a fire, horizontal poles with chorizo sausages and chestnut strings | 1,6 × 0,6 m |
| `arca_grano` | traditional Galician wooden grain chest, carved front, heavy lid, iron bands | 1,2 × 0,6 × 0,7 m |
| `yugo_aperos` | wooden ox yoke and farm tools (sickle, pitchfork, rake) hanging together on wall pegs | 1,4 × 0,2 × 1,2 m |
| `vaca_tumbada` | brown cow lying down on straw, calm, cartoony | 1,8 × 0,9 m |
| `cerdo` | small pink-brown pig standing | 0,8 m |
| `cesto_paja` | woven straw basket with chestnuts / a straw bundle | 0,5 m |
| `telar` | small wooden hand loom with half woven wool cloth | 1,0 × 0,6 × 1,0 m |
| `mesa_obrador` | alchemist workbench, mortar and pestle, glass jars with pickled herbs and poisons, knife | 1,4 × 0,7 × 0,8 m |
| `armero` | wooden weapon rack with crude daggers, short spears and slingshots | 1,0 × 0,3 × 1,2 m |
| `botin_robado` | messy pile of stolen trinkets: spectacles, false teeth, rings, necklaces, a folded dress | 0,7 m |
| `barandilla_curva` | curved wooden balcony railing segment, oak posts, quarter circle | 2,3 m de arco |
| `escalera_madera` | straight wooden staircase flight with side rail, 8 steps, rustic | 2,3 × 0,9 × 1,6 m |
| `pupitre_bajo` | low small wooden writing desk for a child-sized goblin, slanted top, inkwell and quill | 0,7 × 0,5 × 0,6 m |
| `atril` | wooden lectern with an open old book | 0,5 × 0,4 × 0,9 m |
| `vela_platillo` | single lit candle on a metal dish, wax drips | 0,15 m |
| `anaquel_curvo` | curved wooden bookshelf following a round wall, full of old books and scroll rolls | 2,3 m de arco × 1,8 m |
| `cama_aprendiz` | low narrow wooden bed with straw mattress and wool blanket | 1,7 × 0,8 × 0,4 m |
| `mesa_lectura` | long heavy wooden reading table with scattered parchments | 2,2 × 0,8 × 0,7 m |
| `despacho_marimanta` | old witch's desk with candles, books, a skull-free curio and a tall high-backed chair | 1,6 × 0,9 m |

## Orden de trabajo propuesto

1. **Palloza familiar** (es la que más se ve): planta redonda, Ástrago/Travariza, hogar con humo, y las piezas que ya tenemos. Luego las piezas de Meshy.
2. **Torre: planta tipo + escalera entre plantas** (el sistema), con la planta baja (aula) y el despacho arriba; mover la audiencia al despacho.
3. **Biblioteca, estudio y celdas** con sus piezas.
4. **Gremio del gorro verde** y retoques de la tienda.
