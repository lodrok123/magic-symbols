# Uniforme de Monte Sumicio (Mid) sobre la jugadora base (11 de noviembre de 2026)

**De dónde sale:** la ficha de personaje de *Midir Tuatha Dé Danann* («Mid»): capa-caperuza roja de lana con gorro picudo y caído,
camisa de lino, chaleco, faltriquera, bombachos, polainas y botines. Inspirada en el traje regional gallego.

**A qué se traduce:** NO a un personaje nuevo. El juego viste a `jugadora_base` por piezas sobre el mismo esqueleto
(`jugador/ropa_3d.gd`, `arte/modelos/ropa.json`), así que el uniforme es **un juego de prendas nuevas** que sustituye al verde de hoy
(`capa`, `capucha`, `tunica`). El cuerpo, la cara, los ojos pequeños, el pelo y los 22 clips no cambian.

---

## 1. Qué hay en la ficha y qué vale tal cual

La ficha está dibujada en semirrealista, a 7 cabezas y sobre pergamino. Lo que el juego enseña es un chibi de 3 cabezas, pastel, de
1,0 u de alto, visto desde arriba a 60° y pequeño en pantalla. A ese tamaño sobreviven **la silueta, dos o tres colores y una marca**
(`docs/PERSONAJE.md`). Leída así, la ficha se reparte en tres grupos:

| de la ficha | qué es en el juego | decisión |
|---|---|---|
| camisa de lino crema, chaleco oscuro, cinturón de cuero | **ya está en la base** (camisa crema ceñida, chaleco marrón atado, cinturón fino) | nada que generar: con la capa puesta se ve exactamente eso |
| capa-caperuza roja, borde cosido a mano, cierre en el pecho | la `capa` (exterior, con muelles) + la `capucha` (cabeza) | **prenda nueva: `capa_sumicio` y `capucha_sumicio`** (§3) |
| bombachos oscuros + polainas crema cruzadas + botines con hebilla | hoy son mallas verdes ceñidas y botas altas de la base | **prenda nueva de piernas: `piernas_sumicio`** (oculta `piernas` y `botas`) (§4) |
| faltriquera de cuero con costuras rojas, bandolera | equipo colgado de un hueso, como el libro en la cadera | opcional, pieza de `Equipo3D` (§5) |
| mangas abullonadas | tela suelta en el brazo: **lo que se prohibió** en la base (chocaba al doblar el codo) | no se hace; queda la manga ceñida |
| pelo cobrizo rizado y largo, orejas humanas | el pelo lo tapa la capucha; las orejas de la base son de elfa y salen por la capucha | decidido: la elfa, con su pelo; la ropa no toca la base (§7) |
| expresiones, retrato | el juego no anima la cara | no aplica |

**La marca** del uniforme es una sola: la **capucha roja de punta caída**. Es lo que distingue a Mid a 1:1 y lo único en lo que hay que
gastar generaciones. Los pespuntes blancos de la ficha a ese tamaño son **una orla crema fina** (como la de la capa verde de hoy), con
la raya discontinua pintada en la textura: no se verá de lejos y sí de cerca en la bolsa y los diálogos.

## 2. Paleta

Sin rojo puro: la saturación del `WorldEnvironment` ya sube 1,1 (`docs/ARTE.md` §10) y el fuego de los hechizos es `#F2551E`;
una capa de ese tono se confundiría con una jugadora ardiendo. La ficha ya tira a granate, que es lo que conviene.

| pieza | color | hex de referencia | nota |
|---|---|---|---|
| capa y capucha | granate de lana | `#9E3444` | sombra `#6E2432`; se pide «muted brick red / burgundy», nunca «bright red» |
| orla y polainas | crema de lino | `#EFE3C6` | el mismo crema de la camisa de la base |
| chaleco, bombachos | marrón pardo muy oscuro | `#3A2E2A` | el chaleco ya es de la base; los bombachos a juego |
| cuero (cinturón, botines, faltriquera) | marrón silla | `#7A4A2E` | cerca de `TIERRA` (`#835832`) de la paleta cerrada |
| hebillas | latón apagado | `#B08A4A` | sin brillo metálico: `roughness` alta |

Ventaja que no tiene el verde de hoy: en `bosque_01_v01_idle.png` la capucha verde se funde con la hierba; una granate recorta la
figura sobre todos los biomas (Bosque, Cueva, Pantano) sin tocar la luz. Es el mismo motivo por el que la ficha la eligió.

## 3. Capa y capucha de Sumicio

Mismo método que `PROMPTS_JUGADORA_BASE.md` §2: imagen de la base vestida → imagen de la prenda sola → Meshy/Tripo de imagen a 3D
**sin rig** → `herramientas/rig/encajar_ropa.py` → `herramientas/montar_ropa_glb.gd` (con `muelles` para la capa).

**Referencia de estilo:** `docs/capturas/jugadora_base/base_frente.png` (la base en A-pose) y, para la forma, la columna «lado» de la
ficha (la punta cae hacia atrás).

**3a. La base vestida.**

> The same elf girl in the same A-pose wearing a muted BURGUNDY wool hooded CAPELET over her base outfit: a short cape that covers the
> shoulders and upper arms and ends at the elbows, standing slightly away from the arms, a thin cream linen trim along every edge with
> small hand-stitch dashes painted on it, a small round brass button closing it at the chest. The HOOD is up over the short hair and has
> a long pointed tip that FLOPS DOWN AND BACK over the right shoulder like a sleeping cap; the long elf ears poke out through slits.
> Soft pastel colors, hand-painted texture, chunky rounded shapes, no gradients, no shine. Plain light background, soft even lighting.

**3b. La prenda sola** (con la imagen de 3a como referencia):

> The same burgundy hooded capelet alone, worn by an invisible body, same pose, same size, same floppy pointed hood tip, nothing else,
> plain light background.

**Meshy / Tripo:** *"chibi game character hooded capelet, single garment, no body, A-pose"*. Entrada: `vestido_sumicio.glb` (capa y
capucha juntas, como vino el vestido verde: `encajar_ropa.py` las parte por la altura de la `capucha` de su config).

**Si sale mal:**
- **Rojo chillón:** *"muted burgundy, desaturated, wool, no bright red"*.
- **La punta sube** (como la de hoy): *"the hood tip hangs down behind the head, soft and limp, not standing up"*.
- **Capa larga:** *"the cape ends at the elbows"*: por debajo del codo vuelve a chocar con la manga.

**Qué cambia respecto a la verde y qué no:**
- La **capa** lleva las mismas 8 cadenas de muelles (`CapaMuelles3D`): el montador las calcula sobre la malla nueva; no hay código.
- La **capucha** va rígida al hueso `Head`, como hoy. La punta caída se deja **horneada en la geometría**, inclinada hacia atrás y a la
  derecha: con la cámara a 60° se lee como caída sin simularla. Decidido (11/11, Pablo): rígida; no se le pone cadena de muelles.
- La capucha encoge con la cabeza a 0,80 (`Pj3D.PROPORCIONES`), igual que la verde; la capa se repesa con `repesar_capa.gd` como ya se hizo
  (`capa_pesos`, 25/10). El ancho de la capa en los hombros tiene que quedar como la de hoy: si la punta pesa en `Head`, se estira la nuca.

## 4. Piernas: bombachos, polainas y botines

Es la prenda nueva de verdad: hoy no existe nada por debajo del cinturón. Tapa las zonas `piernas` y `botas` de la base
(`ropa.json`, `oculta`), así que puede ser más ancha que la malla sin que asome la verde.

**Lo que hay que respetar:** la rodilla y el tobillo doblan en `Running`, `RollDodge` y la sentadilla. **La parte ancha del bombacho
queda por encima de la rodilla** y de rodilla para abajo todo va ceñido (polaina y botín): así la articulación cae en tela pegada y
los pesos salen limpios del cuerpo, como con la bota alta de hoy.

> The same elf girl in the same A-pose, her legs now in dark brown BAGGY BREECHES that puff out at the thigh and gather just ABOVE the
> knee, cream linen LEG WRAPS criss-crossed tightly from the knee to the ankle, and short brown leather ANKLE BOOTS with a single small
> brass buckle. Nothing hangs loose below the knee. Soft pastel colors, hand-painted texture, chunky rounded shapes. Plain light
> background, soft even lighting.

Prenda sola: *"the same breeches, leg wraps and ankle boots alone, worn by invisible legs, same pose and size, nothing else"*.

Entrada: `piernas_sumicio.glb`. Config de encaje propia (una entrada `piernas` en el json de `encajar_ropa.py`, sin `atenuar_piernas`:
aquí las piernas SÍ tienen que pesar).

## 5. Faltriquera: no (decidido 11/11, Pablo)

No se genera. El libro ya ocupa la cadera izquierda (`docs/capturas/jugadora_integrada/escenario_apuntar_frente.png`) y es el arma; la
bolsa de la ficha estorbaría. Si algún día se quiere, es una pieza de `Equipo3D` colgada de `mixamorig_Hips`, no ropa.

## 6. En el juego

**HECHO (11/11, diario 476):** las tres prendas están montadas e integradas con los .glb de Meshy de Pablo (ver `herramientas/rig/ropa_sumicio_capa.json` y
`ropa_sumicio_piernas.json`, y `docs/capturas/uniforme_sumicio/`). Lo de abajo era el plan; lo que queda es lo que dice el diario (roces de los antebrazos en movimiento y las
piernas lavanda de la silueta, que no es de la ropa).

**Decidido (11/11, Pablo): el uniforme SUSTITUYE a la capa y la capucha verdes.** Eso quita trabajo: no hay ids nuevos para ellas.

- `capa` y `capucha` se quedan con sus ids, sus filas de `objetos.tsv` y sus entradas de `ropa.json`; lo que cambia es el `.glb`:
  `arte/modelos/ropa_capa.glb` y `ropa_capucha.glb` (con sus texturas `ropa_*_albedo/normal/orm.jpg`) se generan de nuevo desde
  `vestido_sumicio.glb`. Las bordadas (`capa_escarcha`, `capucha_musgo`) heredan el aspecto nuevo solas, porque dibujan con el `.glb` de
  su base. Convendría actualizar el `nombre`/`desc` de las filas («Capa de Sumicio», «Capucha de Sumicio») y el `color` del icono
  (`#4D6BB3` y `#5C4D80` son azules: pasar a granate `#9E3444`).
- La **túnica** verde no tiene equivalente en la ficha (el chaleco va a la vista). Se queda como prenda aparte de `ranura=medio`, sin
  cambiar; con el uniforme puesto no se lleva.
- `piernas_sumicio` sí es nueva: entrada en `ropa.json` (oculta `piernas`, `botas`), `.glb` en `arte/modelos/` y fila en `objetos.tsv`
  con una ranura nueva `piernas`, que hoy no existe en `Ropa3D.ranura_de`: comprobar que el inventario admite la cuarta ranura. Si va
  siempre puesta con el uniforme, se pone en el equipo inicial junto a `capa` y `capucha`.
- Presupuesto: cada prenda a ≤ 6 000 triángulos tras el `Decimate` de `encajar_ropa.py` (hoy el `tris` de la config está en 9 000; la
  jugadora entera debería quedar en 9–11 k, `arte/meshy/PRESUPUESTO.md`). Texturas a 1024, como las de hoy.
- Prueba de que funciona: las 6 poses de `docs/PLAN_RIGGING.md` §3 en `laboratorios/LabJugadora3D.tscn`, y además `Running` de lado para
  los bombachos y `RollDodge` para que la punta de la capucha no atraviese la espalda. Las capturas de referencia de hoy
  (`docs/capturas/jugadora_integrada/`, `capa_costura/`) quedan como «antes».

## 7. Decisiones de Pablo (todas tomadas el 11/11)

1. **Orejas: decidido (11/11, Pablo): Mid ES la elfa del juego.** La ficha se adapta: orejas largas que salen por la capucha, como
   hoy. No hay base nueva. Los prompts de arriba ya lo asumen.
2. **Pelo: decidido (11/11, Pablo): se deja el melocotón de la base.** Regla: una prenda se pone encima y **no cambia al personaje
   de debajo** (ni malla ni albedo de `jugadora_base`). La capucha tapa el pelo; el flequillo que asoma es el de siempre.
3. **Sustituye o convive: decidido (11/11, Pablo): sustituye.** Ver §6.
4. **Faltriquera: decidido (11/11, Pablo): no.** Ver §5.
5. **Punta de la capucha: decidido (11/11, Pablo): rígida**, horneada inclinada hacia atrás y a la derecha, al hueso `Head`. Sin cadena de muelles.
