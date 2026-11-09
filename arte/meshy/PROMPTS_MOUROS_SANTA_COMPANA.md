# Mouro espectral y Santa Compaña (enemigos de glifo, 9 de noviembre de 2026)

Son dos de los enemigos de `docs/Playtests/REVISION_PLAYTEST_CUATRO_ELEMENTOS_2026-11-09.md` §B3 ter: el **mouro da mámoa**
(glifo ᛉ permanencia: vuelve a su túmulo mientras la mámoa siga abierta) y la **Santa Compaña** (glifo ᛁ línea: procesión en fila
que se pasa la cruz al morir el que la lleva).

**Decisión de Pablo (9/11):** en el lore del juego **los mouros ya existen y son los «elfos»**. Así que esto no es una criatura
nueva: es **un mouro muerto**. Tiene que leerse como «esa gente, pero difunta», no como un fantasma genérico. La Santa Compaña se
respeta tal cual es en la leyenda, y lo que cambia es el **aspecto**: espectral y no-muerto, no aldeanos con vela.

> **Revisión del 9/11 (segunda versión de los prompts).** La primera tanda salió **realista**: el ánima con proporciones humanas
> (unas 8 cabezas), tela fotográfica con cientos de jirones finos, y la mámoa como un escaneo con hierba hoja a hoja y líquenes.
> La culpa era de estos prompts, no del generador: **no llevaban el bloque [ESTILO] ni el negativo de `PROMPTS.md`**, no decían
> «chibi, 3 cabezas» y encima estaban llenos de palabras que empujan al fotorrealismo («weathered», «lichen», «dry cloth»,
> «frayed into long strips»). Abajo van corregidos. Lo que sí estaba bien de aquella tanda es la **silueta**: la capucha de pico
> que deja la cara en sombra y la mámoa abierta con el hueco cuadrado se leen bien, y sirven como referencia de forma.

---

## 0 · Estilo (va delante de TODOS los prompts)

Esto no es opcional ni se resume: se **pega literalmente** delante de cada prompt de pieza, igual que en `PROMPTS.md`. Es lo que
faltó en la primera tanda.

### [ESTILO]
```
Stylized chibi anime game asset, hand-painted texture, soft pastel colors, Ghibli-inspired, cute rounded chunky
shapes, clean readable silhouette, soft cel shading, matte, no harsh baked shadows, single object, centered,
no base, no ground plane, no background.
```

### [NEGATIVO]
```
realistic, photorealistic, photoscan, metallic, glossy, dark, grim, high contrast, noisy texture, fine detail,
thin fringe, individual grass blades, lichen speckle, ground plane, base, pedestal, text, multiple objects,
sharp spikes, outline, black lines
```

Y, solo para estos dos (ver §0 bis), lo que no puede salir **por un lado ni por el otro**:
```
cute, kawaii, adorable, big shiny eyes, eye highlight, sparkle, blush, rosy cheeks, smiling,
teeth, fangs, blood, wounds, gore, red glowing eyes, claws, monster face, horror
```

### Paleta (la de la chibi, `PROMPTS.md`)
Hierba menta `#a8d9a0` · camino crema `#ffe8aa` · tierra melocotón `#e6b98f` · piedra gris lila `#dde0ea` ·
sombra gris cálido `#69645b` · acento rosa `#f7c6d3` · oro `#f9d792`.

Lo espectral de estos dos sale de **esa misma paleta desaturada**, no de grises sucios: piedra gris lila para la tela, crema para
la piel, un toque de menta o petróleo muy suave en la sombra. Un fantasma pastel asusta igual y **encaja con el bosque**.

### Vía recomendada: *Image to 3D*, no *Text to 3D*
`PROMPTS.md` ya lo dice y aquí importa el doble, porque son personajes de una familia que ya existe:

- **Personajes (§1 y §2):** la entrada es una **captura de frente de `arte/modelos/elfo_base.glb`** sobre fondo claro. Meshy copia
  de la imagen la proporción y la cara; del texto, solo la ropa. Sin esa captura vuelven a salir de 8 cabezas.
- **Decorado (§5 y §6):** una captura de `roca_grande` o de los muros de granito de la Cueva, para que la piedra sea la misma
  piedra del juego y no un escaneo.
- **Props (§3 y §4):** valen de texto; son pequeños.

### La prueba de que está bien
Antes de refinar y texturizar, poner la vista previa **al lado de la captura de `elfo_base`** (o de `roca_grande`, en el decorado)
y mirar dos cosas: **¿cuántas cabezas mide?** y **¿se ve la textura a trozos planos o a poros?**. Si no casa, se regenera antes de
gastar el texturizado: cambiar el estilo después obliga a repetirlo todo.

---

## 0 bis · Cómo dar miedo sin salirse del estilo (revisión del 9/11, segunda tanda)

La segunda tanda **ya está en el estilo del juego** (chibi, pastel, textura plana): eso se da por bueno y no se toca. Lo que
falta es que **den miedo**: salieron tiernos. El mouro parece un niño elfo con los ojos grandes y el ánima, un muñeco
encapuchado simpático.

El error de bulto sería arreglarlo con dientes, sangre, garras o cuencas rojas: eso **rompe el estilo**, desentona con el bosque
pastel y además no es el juego que es. En una paleta así el miedo no viene del gore: viene de **una sola cosa que está mal**.
Seis palancas, por orden de lo que más cambia con menos esfuerzo:

| # | palanca | qué pedir |
|---|---|---|
| 1 | **El ojo sin brillo** | Es LA regla. Un ojo chibi da ternura por el **punto blanco de luz**; quítalo y el mismo ojo está muerto. El mouro: dos óvalos planos y negros, mate, **sin reflejo, sin iris, sin pupila, sin blanco**. *"flat matte black eyes, no highlight, no sparkle, no iris"* |
| 2 | **Sin boca** | Ni sonrisa ni ceño: **nada**. Una cara sin boca no se puede leer, y lo que no se puede leer inquieta. |
| 3 | **El hueco de la capucha vacío** | Lo que asusta del ánima es que **dentro no haya nadie**. Nada de barbilla rosada asomando: un vacío **plano y oscuro**, del mismo tono mire donde mire. En Godot se remata con un material sin iluminar dentro de la capucha. |
| 4 | **Una proporción equivocada** | Siguen siendo chibi, pero **una** medida se va: **manos grandes de dedos largos** colgando quietas, y una figura algo más estirada (3,5 cabezas en vez de 3). Lo demás, igual que la familia. |
| 5 | **La piel, muerta** | Fuera el melocotón y el rubor: **gris crema**, mismo valor en la cara que en las manos, sin color en las mejillas. La piel sana es la mitad de la ternura. |
| 6 | **Algo torcido** | Todo lo demás es simétrico y quieto; **una** cosa no: la diadema un poco ladeada, el bajo de la mortaja más largo por un lado, tierra seca en el borde (ha salido de una tumba). |

**Lo que NO se pide nunca:** dientes, colmillos, sangre, heridas, carne, ojos rojos, garras, cara de monstruo, cuerpo retorcido.
Al negativo: `teeth, fangs, blood, wounds, gore, red glowing eyes, claws, monster face, horror, scary face`. El miedo lo ponen las
seis palancas de arriba, no la cara.

**Y la mitad del susto no está en el modelo.** Conviene saberlo antes de pedir más al prompt: estos dos **no andan**, se deslizan
(piernas desvanecidas por material, sin pasos); la Compaña **gira la cabeza hacia la jugadora** sin dejar la fila; no hacen ruido
al moverse y suenan solo las campanillas de la cruz; y la niebla a ras de suelo llega antes que ellos. Un modelo quieto y pálido
con eso encima da más miedo que cualquier cosa que se le pinte a la textura.

- **La familia manda.** Los dos personajes son de la familia del elfo: **chibi, unas 3 cabezas de alto**, cabeza grande, cuerpo y
  piernas cortos, manos y pies chicos y redondeados. Si salen esbeltos, el lore no se lee y además desentonan al lado de la
  jugadora.
- **Lo espectral NO se pide a Meshy: se hace en Godot.** El modelo viene **opaco y mate**, en pastel desaturado. La transparencia,
  el desvanecido de las piernas, el rim frío y el parpadeo son un pase de material en `MaterialPersonaje3D` (`next_pass`, como el
  rim y la silueta de hoy), que además deja intacto el tinte de `Combate3D` (quemado, congelado, destello del golpe). Un modelo
  que venga ya translúcido o con humo pegado **no se puede teñir**.
- **Lo que se pasa de mano o brilla va aparte:** la cruz y el candil son piezas sueltas (`Equipo3D`, como el bastón del chamán).
  La cruz **tiene que ser pieza suelta**: la mecánica es que pase de un ánima a la siguiente cuando cae el guía.
- **Piernas sí, aunque no se vean.** La túnica va **abierta por delante con las piernas visibles bajo la rodilla**: si el faldón es
  un bloque, el autorig lo pega a la columna y no hay andar posible. El «no tiene pies» se consigue **desvaneciendo el material de
  la cadera hacia abajo**, no quitando geometría. Así los dos usan los clips de andar que ya hay.
- **Pocas formas y grandes.** Todo lo roto va en **3 a 5 picos anchos**, nunca en un fleco. A 60 px un fleco fino es ruido gris, y
  además se come los triángulos que hacen falta en la silueta.

Presupuesto: son enemigos de 0,9–1,1 u (≈ 55–65 px con la cámara de `PruebaTest2`), así que **8 000–12 000 tris y 2048** como la
familia goblin; con formas grandes y planas sobra. La Compaña sale **de tres en tres**: pasarse de 12 000 son 36 000 en pantalla.

---

## 1. Mouro espectral (`mouro_espectro`)

**Qué hace en el juego:** sale de su mámoa, pelea despacio y, si lo matas con la mámoa abierta, **vuelve a brotar a los 4 s**. Se
acaba con él tapando el túmulo. Tiene que leerse que es **de los mouros** (la gente de debajo de la tierra, los «elfos» del juego)
y que lleva mucho muerto: señorío antiguo, no harapos de mendigo.

**Entrada:** captura de frente de `arte/modelos/elfo_base.glb` + [ESTILO] + este texto.

### Imagen de concepto
> Same chibi game character style as the reference elf, hand-painted and pastel, but NOT cute: this one is dead.
> Proportions: still chibi and big-headed, but stretched a little, about 3.5 heads tall, with LONG THIN ARMS and
> noticeably BIG HANDS with long fingers hanging still and open at the sides; short legs, small bare feet, long
> pointed ears. New character: the DEAD MOURO, an old underground elf-lord who still guards his barrow. FACE:
> perfectly symmetrical, blank and calm, GREY-CREAM dead skin with no blush and no pink, the same flat tone on
> face and hands; the eyes are two plain narrow MATTE BLACK ovals, completely flat, with NO highlight, NO
> sparkle, NO iris, NO white; NO MOUTH AT ALL, no nose shadow, no eyebrows, no wrinkles. Straight flat pale grey
> hair cut level at the jaw, hanging without movement. Outfit in BIG SIMPLE SHAPES: a long sleeveless tunic with
> one wide band of simple zig-zag embroidery along the hem, split at the front so both legs are visible below the
> knees; a mantle hanging from both shoulders whose lower edge is torn into FOUR wide pointed shapes, no fringe;
> a broad flat belt with one square buckle; a thin plain circlet on the brow, sitting SLIGHTLY CROOKED; a band of
> dry earth staining the bottom of the tunic, painted as one soft flat shape. PALETTE: pale grey-lilac cloth,
> grey-cream skin, one dull gold accent on circlet and buckle, desaturated pastel, nothing bright. Flat
> hand-painted texture with large colour areas, soft cel shading, matte. EMPTY HANDS: no weapon, no staff, no
> props. Full body, front view, symmetrical A-pose with arms 35 degrees away from the body, palms down, fingers
> apart, legs slightly apart, plain light background, soft even lighting.

**Si sale mal:**
- **Sale tierno, de niño elfo:** es el fallo de la segunda tanda. Tres frases, por este orden:
  *"flat matte black eyes, no highlight, no sparkle, no iris"* · *"no mouth at all"* · *"grey-cream dead skin, no blush, no pink
  cheeks"*. Si solo se puede decir una, la de los ojos: el punto de luz del ojo es lo que lo hace mono.
- **Sale esbelto, de persona:** *"chibi, big head, about 3.5 heads tall, short legs, like the reference elf"*. Fue el fallo de la
  primera tanda y el único que no se puede arreglar después.
- **Las manos salen pequeñas y monas:** *"big hands with long fingers, hanging open and still"*. Son la proporción que se va de
  sitio a propósito.
- **Sale fotorrealista, con tela de foto y pliegues finos:** *"flat hand-painted texture, large colour areas, soft cel shading,
  matte, no photorealism"*.
- **El manto acaba en fleco:** *"the torn edge is only four wide pointed shapes, no fringe, no thin strips"*.
- **Sale translúcido, con humo o brillando:** *"solid opaque body, matte, no transparency, no glow, no smoke"*. Lo espectral lo
  pone el juego; si viene en el modelo, el tinte del golpe no se ve.
- **Sale como un zombi podrido:** *"calm hollow face, not rotten, no exposed flesh, no wounds"*. Es un difunto antiguo, no carne.
- **Pierde las orejas o la cara de elfo:** *"same long pointed ears and same face shape as the reference elf"*. Es lo único que
  dice que es un mouro.

### Meshy, de imagen a 3D
> chibi undead elf lord, blank face, flat matte black eyes, no mouth, grey dead skin, long thin arms and big
> hands, long split tunic, torn mantle, crooked circlet, pastel grey lilac and cream, hand-painted, A-pose,
> empty hands, game character, ready for rig, solid opaque, no transparency, not cute

- **Nombre al instalar:** `mouro_espectro`.
- **Altura en el juego:** 1,05 (un poco más que la jugadora: era un señor).
- **Tris / textura:** 8 000–12 000 · 2048 (1024 vale a este tamaño).
- **Clips** (de los de Mixamo ya probados con `elfo_base` el 5/11, `docs/CLIPS_MIXAMO_CANDIDATOS.md`): `idle` ← **Old_Man_Idle**,
  `walk` ← **Old_Man_Walk**, `attack` ← **Standing_2H_Magic_Area_Attack_01**, `hit_reaction` ←
  **Standing_React_Large_From_Front_2**, `dead` ← **Falling_Back_Death**.
- **Lo que NO es clip:** salir de la mámoa y volver a brotar. Eso es código (posición + desvanecido del material), como el
  dividirse del limo.

---

## 2. Ánima de la Santa Compaña (`anima_compana`)

**Qué hace en el juego:** van **tres en fila india**; el primero lleva la cruz y, cuando cae, **la cruz pasa al siguiente** y la
procesión sigue. Hay que cogerlos a todos de una pasada (ᛁ). De lejos lo que tiene que leerse es **la fila**: tres siluetas
idénticas, encapuchadas, a la misma altura, y **una** con la cruz. Por eso es **un solo modelo repetido tres veces**: nada de
variantes.

**Entrada:** la misma captura de `elfo_base.glb` + [ESTILO] + este texto. De la primera tanda se puede reaprovechar la imagen
**solo como referencia de silueta** (la capucha de pico y la cara en sombra estaban bien), diciendo «misma silueta, proporciones
chibi».

### Imagen de concepto
> Same chibi game character style as the reference elf, hand-painted and pastel, but NOT cute: this is a dead
> soul. Proportions: chibi and big-headed, stretched a little, about 3.5 heads tall, with LONG THIN ARMS and BIG
> HANDS with long fingers hanging still and open at the sides. New character: a SOUL of the night procession
> walking in a funeral train. Head covered by a big pointed HOOD hanging forward, and INSIDE THE HOOD THERE IS
> NOBODY: a completely EMPTY flat dark void, one single even dark tone, NO face, NO chin, NO eyes, NO skin, no
> shading inside, as if the hood were hollow. Outfit in BIG SIMPLE SHAPES: a hooded cloak over a plain shroud
> robe, closed at the chest with one simple cord knot, both SPLIT AT THE FRONT so that both legs stay visible
> below the knees (this is needed for the rig), the hem reaching mid-calf and cut into FIVE wide pointed shapes,
> clearly longer on one side than on the other, no fringe and no thin strips; wide loose sleeves ending at the
> wrist with the big bare grey-cream hands out, no blush, no pink. A band of dry earth stains the bottom of the
> robe, painted as one soft flat shape. No armour, no jewellery, no belt, no insignia. PALETTE: pale cream linen
> for the robe and soft grey-lilac for the cloak, so hood and robe read apart; desaturated pastel, nothing
> bright; flat hand-painted texture with large colour areas, soft cel shading, matte, NO glow, NO transparency,
> NO candle, NO cross, NO props of any kind, solid opaque. EMPTY HANDS: both hands open and empty. Full body,
> front view, symmetrical A-pose with arms 35 degrees away from the body, palms down, fingers apart, plain light
> background, soft even lighting.

**Si sale mal:**
- **Sale mono, de muñeco:** es el fallo de la segunda tanda, y aquí todo depende del hueco de la capucha:
  *"inside the hood there is nobody, an empty flat dark void, no face, no chin, no skin"*. En la segunda tanda asomaba una
  barbilla rosada y eso lo convierte en un niño con capucha.
- **Sale de persona, alto y delgado:** *"chibi, big head, about 3.5 heads tall, short legs"*. Fue el fallo de la primera tanda.
- **Las manos salen pequeñas:** *"big grey-cream hands with long fingers, hanging open and still"*.
- **El bajo sale deshilachado en cien tiras:** *"the hem is five wide pointed shapes, no fringe, no thin strips"*.
- **El faldón llega al suelo y tapa las piernas:** *"split at the front, both legs visible below the knees"*. Aquí hay que
  aguantarse: **la geometría necesita piernas** o el autorig no anda. El «no tiene pies» lo pone el juego desvaneciendo el
  material de la cadera hacia abajo (§7), no el modelo.
- **Viene con la cruz o la vela puestas:** *"hands completely empty and open, no cross, no candle"*. Las dos son piezas sueltas
  (§3 y §4) o la cruz no podrá pasar de mano en mano.
- **La capucha sale como un gorro o cae hacia atrás:** *"big pointed hood hanging forward over the face, face in shadow"*. Si cae
  sobre la espalda, el autorig la pega a la columna y se deforma al andar.
- **Se ve la cara entera:** *"only the chin visible inside the hood"*. La cara vacía es la mitad del miedo.
- **El faldón es un bloque:** *"cloak and robe split at the front, both legs visible below the knees"*.

### Meshy, de imagen a 3D
> chibi hooded dead soul, big pointed hood with an empty dark void inside, no face, long thin arms and big
> hands, torn shroud cloak, pastel cream and grey lilac, hand-painted, A-pose, empty hands, game character,
> ready for rig, solid opaque, no props, not cute

- **Nombre al instalar:** `anima_compana`.
- **Altura en el juego:** 1,0. Las tres idénticas y a la misma altura: la fila se lee por la repetición.
- **Tris / textura:** 8 000–12 000 · 2048.
- **Clips:** `idle` ← **Praying_2**, `walk` ← **Old_Man_Walk** (la marcha lenta de la procesión), `entregar` ← **Opening_A_Lid** o
  **Push** (pasar la cruz al de atrás), `hit_reaction` ← **Standing_React_Large_From_Front_2**, `dead` ← **Falling_Back_Death**.

---

## 3. Cruz de la procesión (`cruz_compana`) — pieza suelta

**Qué hace en el juego:** la lleva el guía y **pasa al siguiente** cuando cae. Dice de un vistazo quién manda en la fila, así que
tiene que verse por encima de las cabezas.

### Imagen de concepto
> [ESTILO] A single chibi game prop: an old PROCESSIONAL CROSS carried by hand. A straight chunky wooden staff in
> warm grey-brown, with a simple plain latin cross at the top made of the same wood, held at the joint by two
> flat bands in soft gold. Hanging from the two arms of the cross, one short cord each with a small rounded bell
> at the end. Chunky rounded shapes, flat hand-painted texture with large colour areas, soft cel shading, matte.
> No fabric, no banner, no figure on the cross, no engravings, no gems, no glow, no sharp spikes. Vertical, staff
> pointing down, cross at the top, grip in the lower third. Single object, plain light background.

**Si sale mal:**
- **Sale con estandarte o paño:** *"no fabric, no banner, bare cross"* (el paño pide simulación y aquí no la hay).
- **Sale un crucifijo con figura:** *"a plain empty cross, no figure"*.
- **Sale astillada y realista:** *"chunky smooth wood, hand-painted, no cracks, no wood grain detail"*.
- **Sale enorme:** la vara mide **1,4 u**; la cruz de arriba, 0,35 u de ancho.

### Meshy, de imagen a 3D
> chibi wooden processional cross on a staff, gold bands, two small bells, pastel warm brown, hand-painted,
> static prop, single object, low poly

- **Nombre al instalar:** `cruz_compana`. **Mango en el origen, apuntando a +Y**, como el arco del arquero y el bastón del chamán,
  para que `Equipo3D` la cuelgue del hueso de la mano.
- **Tris / textura:** 400–800 · 512.

---

## 4. Candil del ánima (`candil_compana`) — pieza suelta, opcional

**Qué hace en el juego:** cada ánima lleva uno; es lo que hace la fila visible en una sala a oscuras (estado `oscuridad`) y lo que
la delata antes de verla. La llama **no va en el modelo**: la pone el VFX (`llama_tira8`).

### Imagen de concepto
> [ESTILO] A single chibi game prop: a small HAND CANDLE HOLDER. A shallow round dish in soft grey metal with a
> chunky curved finger loop on one side, and in the middle one short fat stub of cream white candle with two or
> three big soft drips of wax over the rim. Rounded chunky shapes, flat hand-painted texture, soft cel shading,
> matte. NO FLAME, no fire, no glow; the wick is one short dark line. Single object, plain light background.

**Si sale mal:**
- **Viene con llama:** *"no flame, no fire, no glow, unlit candle"*.
- **Sale un farol cerrado de cristal:** *"an open flat dish candle holder, no glass, no lantern"*.
- **La cera sale en mil goterones:** *"only two or three big soft wax drips"*.

### Meshy, de imagen a 3D
> chibi metal candle dish with fat wax candle stub, unlit, no flame, pastel grey and cream, hand-painted, static
> prop, single object, low poly

- **Nombre al instalar:** `candil_compana`. Asa en el origen. Tamaño 0,18 u.
- **Tris / textura:** 150–300 · 256.

---

## 5. Mámoa (`mamoa`) — la pieza que hace el puzle

**Qué hace en el juego:** es **la casilla** de la que vuelve el mouro, y taparla es la forma de acabar con él. Sin esta pieza el
enemigo de ᛉ no existe: es la mitad de la mecánica, no decorado. Tiene que leerse **abierta** desde la cámara del juego y el hueco
tiene que ser **una casilla entera**, para que quepa encima una barrera o la losa.

**Entrada:** captura de `roca_grande` o de los muros de granito de la Cueva + [ESTILO] + este texto. **La hierba no va en el
modelo**: la pone `Hierba3D` en el juego, así que el montículo viene con el césped **pintado plano**, sin una sola brizna de
geometría.

### Imagen de concepto
> [ESTILO] A single chibi game environment piece: an ancient BURIAL MOUND opened at the top. A low rounded earth
> mound, wider than tall, with smooth simple surfaces: the turf is painted as flat mint-green areas with soft
> edges over peach-brown earth, NO individual grass blades, no moss clumps, no lichen speckles. At its centre,
> FOUR chunky rounded slabs of pale grey-lilac stone stand leaning slightly inwards and frame a clean SQUARE
> opening, like a dolmen whose capstone is missing; ONE of the four is clearly tilted and sunken lower than the
> others, so the ring is not tidy. The opening is a FLAT BLACK VOID: no inner walls, no floor, no bottom
> visible, one single even black shape, as if the hole had no end. The square must stay clean so a flat slab can
> rest on top. Around the foot of the mound, SIX big rounded stones, evenly spaced and clearly separated, and
> ONE flat slab lying on the grass. Chunky readable shapes, flat hand-painted texture with large
> colour areas, soft cel shading, matte, low contrast. No treasure, no bones, no props, no glow, no fog. Three
> quarter view from slightly above, plain light background.

**Si sale mal:**
- **Sale como un escaneo, con hierba hoja a hoja y líquenes:** *"flat painted turf, large colour areas, no individual grass
  blades, no lichen, hand-painted, no photorealism"*. Fue el fallo de la primera tanda y además mata el presupuesto de
  triángulos.
- **Las piedras del borde salen muchas y pequeñas:** *"only six big rounded stones, clearly separated"*.
- **Sale simpática, como un donut de piedras:** la de la segunda tanda estaba en estilo pero era amable. Dos frases:
  *"the opening is a flat black void with no visible floor or inner walls"* y *"one of the four slabs tilted and sunken"*. Un
  agujero con fondo es un pozo; uno sin fondo es una tumba.
- **Sale cerrada o con la tapa puesta:** *"the capstone is missing, the shaft is open"*. La tapa es la pieza §6.
- **El hueco sale redondo o pequeño:** *"a clean square opening, wide enough for a flat slab to rest on it"*.
- **Sale un dolmen de pie tipo Stonehenge:** *"a low earth mound, not standing stones"*.
- **Viene con huesos o tesoro dentro:** *"empty dark opening, no bones, no treasure"* (el botín lo pone el juego).

### Meshy, de imagen a 3D
> chibi burial mound with open square stone opening on top, missing capstone, pastel mint grass and grey lilac
> stone, hand-painted, game environment piece, static mesh, no rig, low poly

- **Nombre al instalar:** `mamoa`. 2 casillas de ancho, 0,9 u de alto, el hueco **1 casilla exacta**.
- **Tris / textura:** 1 200–2 500 · 1024. Referencia de lo que ya funciona: `roca_grande` 814 tris.

---

## 6. Losa de la mámoa (`losa_mamoa`) — pieza suelta

**Qué hace en el juego:** es **la tapa**: la que se empuja (`BloqueEmpujable3D`) o se crea con tierra sobre el hueco para que el
mouro no vuelva. Tiene que leerse que **encaja** ahí: misma piedra, mismo cuadrado.

### Imagen de concepto
> [ESTILO] A single chibi game prop: a thick flat rectangular CAPSTONE slab of pale grey-lilac stone, the missing
> top of a dolmen. Chunky rounded edges, one face flatter than the other, two or three soft mint-green moss
> patches painted on the upper face as flat shapes. Flat hand-painted texture with large colour areas, soft cel
> shading, matte. No carvings, no runes, no cracks, no speckles, no glow. Lying flat, three quarter view, single
> object, plain light background.

**Si sale mal:**
- **Sale con runas grabadas:** *"no carvings, no runes, plain stone"* (las runas tienen su propia pieza en el juego).
- **Sale fina:** *"a thick heavy slab"*. Tiene que parecer que pesa: es lo que detiene al mouro.
- **Sale con grano de piedra realista:** *"flat painted stone, large colour areas, no texture detail"*.

### Meshy, de imagen a 3D
> chibi flat stone capstone slab with painted moss, pastel grey lilac, hand-painted, static prop, single object,
> low poly

- **Nombre al instalar:** `losa_mamoa`. 1 casilla × 1 casilla, 0,25 u de grueso.
- **Tris / textura:** 200–500 · 512.

---

## 7. Lo que NO se pide a Meshy

Para que no se encargue de más y para que quede claro qué falta por hacer en el juego:

| lo espectral | dónde se hace |
|---|---|
| transparencia, piernas desvanecidas, rim frío, parpadeo | pase nuevo en `presentacion/material_personaje_3d.gd` (`next_pass`), que deja vivo el tinte de `Combate3D` |
| el mouro saliendo y volviendo a brotar de la mámoa | código del enemigo (posición + desvanecido), como el dividirse del limo |
| la llama del candil y el halo de la fila en la oscuridad | `llama_tira8` y la luz de zona que ya existen |
| la niebla a ras de suelo de la procesión | VFX de nube, el mismo molde que la nube de veneno |
| la hierba del montículo | `Hierba3D`, que la siembra por casilla |
| el negro sin fondo del hueco de la mámoa y del interior de la capucha | material sin iluminar (`unshaded`), para que no cambie con la luz de la zona: es lo que lo hace un vacío y no una sombra |
| que no anden, que se deslicen sin pasos | sin clip de `walk` en el movimiento: avance por código, como el limo |
| que la Compaña te mire sin salirse de la fila | giro del hueso del cuello hacia la jugadora, como el apuntado |
| el silencio: ni pisadas ni voz, solo las campanillas de la cruz | `Sfx`, al montar el encuentro |
| el tinte del elemento al golpearlos | `Combate3D`, sin tocar nada: por eso los modelos vienen pálidos y opacos |

## Orden de generación

1. **`mamoa`** y **`losa_mamoa`**. Son las más baratas y sin ellas el enemigo de ᛉ no se puede ni montar.
2. **`anima_compana`** + **`cruz_compana`**. Las dos juntas: el ánima sin la cruz no es la Santa Compaña, es un encapuchado.
3. **`mouro_espectro`**.
4. **`candil_compana`**, cuando haya una sala a oscuras donde luzca.

Y antes de nada: **una sola prueba**. Generar primero el ánima con la captura de `elfo_base` y ponerla al lado de la jugadora.
Dos preguntas, en este orden:

1. **¿Es del juego?** Mismas proporciones, textura a trozos planos, paleta pastel. Esto ya se consiguió en la segunda tanda.
2. **¿Da miedo?** Tapa la capucha con el dedo: si lo que queda parece un muñeco, falta §0 bis. La prueba buena es enseñársela a
   alguien sin contexto: si dice «qué mono», no vale.

Si falla cualquiera de las dos, se ajusta **antes** de generar las otras seis, que es justo lo que `PROMPTS.md` lleva diciendo
desde octubre.
