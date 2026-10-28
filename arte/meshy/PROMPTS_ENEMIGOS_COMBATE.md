# Limo elemental, chamán goblin y gólem de piedra (enemigos nuevos, 27 de octubre de 2026)

Son los enemigos E1–E3 de `docs/PROPUESTA_COMBATE.md` §4. Pablo pidió el chamán **con sombrero rojo**.

**Cómo se reparte el trabajo:**
- **Lo que cambia de color con el elemento se tiñe en Godot.** El limo y el cristal del bastón del chamán vienen en un **blanco grisáceo neutro**: el juego los tiñe de rojo, azul o amarillo según el elemento que llevan. Si vienen ya coloreados, el tinte se ensucia.
- **Lo que se separa o brilla va aparte:** el bastón del chamán y el núcleo del gólem son piezas sueltas (`Equipo3D`, como las dagas del asesino). Así el núcleo puede brillar, latir o apagarse sin tocar la malla.
- **Humanoides en A-pose y con las manos vacías:** el chamán y el gólem. El limo **no lleva rig**: se aplasta, se estira y se divide por código.

---

## 1. Limo elemental (`limo`)

**Qué hace en el juego:** absorbe el elemento que le das y lo usa en su ataque. Con fuego se divide en dos más pequeños; con hielo se queda congelado como un bloque empujable. Hay que leer de un vistazo qué elemento lleva, así que tiene que ser **claro, translúcido y de color neutro**.

### Imagen de concepto
> Stylized 3D game creature, cute but slightly menacing: an ELEMENTAL SLIME, a single rounded blob of thick
> translucent jelly, like a soft gumdrop wider than tall, slightly flattened at the base where it touches the
> ground. Inside the jelly floats a small round dense CORE, a slightly darker sphere, clearly visible through
> the gel. Two small simple dark oval eyes on the front surface and a tiny frowning mouth. A few small bubbles
> suspended inside. NEUTRAL PALE COLOR: milky white-grey semi-transparent gel, no strong hue (it will be tinted
> in game). Smooth glossy surface, hand-painted stylized look, chunky readable silhouette, no limbs, no
> accessories. Front three-quarter view, plain light background, soft even lighting.

**Si sale mal:**
- **Sale verde o de color:** *"colorless milky white gel, no green, no hue"*.
- **Sale con brazos o patas:** *"no limbs, a single blob shape"*.
- **El núcleo no se ve:** *"a clearly visible darker core sphere inside the translucent gel"*.

### Meshy, de imagen a 3D
> stylized translucent slime blob with inner core, neutral white grey, game creature, static mesh, no rig, low poly

- **Nombre al instalar:** `limo`.
- **Altura en el juego:** 0,6. El pequeño, el que sale al dividirse, es el mismo modelo a 0,35.
- **Sin rig ni clips:** el andar a saltos, el aplastarse al atacar y el dividirse se hacen por código. Si Meshy no deja la gelatina translúcida, no pasa nada: el material translúcido se pone en Godot.

---

## 2. Chamán goblin (`goblin_chaman`)

**Qué hace en el juego:** se queda detrás de sus guerreros y les pone una protección del elemento que va cambiando. Tiene que leerse **de lejos, como el que manda**: el sombrero rojo es su seña.

**Referencia de estilo:** una captura de frente de `arte/modelos/goblin_warrior_chibi.glb`. Misma familia que el guerrero, el arquero y el asesino.

### Imagen de concepto
> Same 3D chibi goblin style, same body proportions, same head, big pointed ears and eyes as the reference
> goblin, about 3 heads tall. New character: a goblin SHAMAN, older and a bit hunched in the face but standing
> upright, olive-green wrinkled skin, wise sly half-closed eyes, a long thin braided chin beard tied with a bead.
> Headwear: a tall wide-brimmed bright RED felt hat with a pointed crooked crown that bends backwards (stiff, it
> stays above the shoulders), a band of small bones and two feathers on the hatband; the big ears come out under
> the brim. Outfit: a ragged layered robe of dark brown and faded ochre cloth reaching the shins, a short fur
> mantle on the shoulders, a necklace of small bones, teeth and one carved wooden totem charm, painted white
> stripe marks on the cheeks, cloth wraps on the forearms, a rope belt with small pouches and dried herbs, bare
> feet with cloth wraps. Palette: the RED hat is the brightest element, the rest muted browns, ochre, bone white.
> EMPTY HANDS: no staff, no props in the hands. Standing upright, full body, front view, symmetrical A-pose with
> arms 35 degrees away from the body, palms down, fingers apart, legs slightly apart, plain light background,
> soft even lighting.

**Si sale mal:**
- **El sombrero cae o se dobla sobre la espalda:** *"stiff red hat, the crooked tip stays above the shoulders"*. Si cae, el autorig lo pega a la columna y se deforma al andar.
- **Sale con el bastón en la mano:** *"hands completely empty and open"*.
- **La túnica tapa las piernas en bloque:** *"robe split at the front, legs visible below the knees"*. Si no, el rig no puede andar.
- **Sale encorvado:** *"standing straight, upright posture, A-pose"*.

### Meshy, de imagen a 3D
> chibi goblin shaman, tall stiff red felt hat, ragged robe, bone necklace, A-pose, empty hands, game character,
> ready for rig, no staff

- **Nombre al instalar:** `goblin_chaman`.
- **Altura en el juego:** 0,85, como la familia goblin. El sombrero sobresale por encima.

### El bastón (aparte)
> stylized chibi game prop: a gnarled crooked wooden shaman staff, about as tall as a goblin, twisted dark wood
> wrapped with leather strips, small bones and a feather hanging near the top, crowned by a claw-like wooden
> fork holding a round CRYSTAL ORB in NEUTRAL clear white-grey (it will be tinted in game), hand-painted texture,
> single object, no hand, plain background

- **Nombre al instalar:** `baston_chaman`.
- **Cristal:** el juego lo tiñe del elemento de la protección que está poniendo.

### Animaciones que hacen falta
| Rol | Qué | Notas |
|---|---|---|
**28/10: el chamán YA ESTÁ RIGGEADO Y ANIMADO, sin pedir nada más a Meshy.** `arte/modelos/goblin_chaman_rig.glb` = su malla con el esqueleto de Marimanta (66 huesos, `tools/autorig_chaman.py`); sus clips vienen de Marimanta y del goblin guerrero (por `ClipsFamilia`) y los de ataque se generan por código (`jugador/animaciones_chaman.gd`, con IK de brazos y piernas):

| Rol | De dónde sale | Notas |
|---|---|---|
| `idle` | Marimanta `Idle_02` | el bastón va plantado en el suelo bajo su mano derecha (`PiezaApoyada3D`) |
| `walk` | Marimanta `Elderly_Shaky_Walk_inplace` | apoyado en el palo; se queda atrás de los guerreros |
| `talk`, `pensar`, `run` | Marimanta | |
| `trazar` (bucle, 2,5 s) | **generado** | inclinado 50°, las dos manos en el bastón (agarrado a la derecha), la punta a ras de suelo dibuja el sello y el rombo (`TrazosRitual`) delante de él |
| `clavar` (1,0 s) | **generado** | alza el bastón (tan alto como llegan sus brazos cortos) y lo clava en el centro; `INSTANTE_CLAVAR` = 0,62 s |
| `lanzar` (1,1 s) | **generado** | echa el bastón atrás y lo lanza hacia delante; la bola de veneno sale a los 0,55 s (`INSTANTE_LANZAR`) |
| `hit`, `death`, `drown` | goblin guerrero | `SlapReaction`, `Die`, `Drowning` |
| `empujado` / `levantarse` | `Pj3D._preparar_empujado` | |

(Los clips que se habían pedido a Meshy — `trazar` y `clavar` — ya no hacen falta.)

---

## 3. Gólem de piedra (`golem_piedra`)

**Qué hace en el juego:** las flechas no le hacen daño. Se le derriba haciéndole resbalar sobre hielo con viento, o empujándolo al agua o a la lava. Tras su golpe avisado se queda unos segundos de rodillas **con el núcleo al aire**, y ese es su punto débil. Tiene que leerse **pesado, lento y muy sólido**, con el pecho abierto donde va el núcleo.

### Imagen de concepto
> Stylized 3D chibi game creature, same cute-chunky style as a chibi goblin but much bigger and heavier: a CAVE
> STONE GOLEM, about twice the height of a goblin, a massive barrel-shaped torso made of stacked rough grey-blue
> cave rock slabs, very small head sunk between huge shoulders, two small glowing pale-blue eye slits, long thick
> rocky arms that almost reach the ground with big blocky fists, short stubby legs. Patches of green moss and small
> ferns on the shoulders and head, a few tiny glowing blue crystal veins in the cracks (subtle). In the CENTER of the
> chest an open round HOLLOW socket framed by rock plates, EMPTY (the glowing core is a separate piece). Matte
> rough stone, hand-painted texture, heavy readable silhouette. Standing upright, full body, front view,
> symmetrical A-pose with arms 30 degrees away from the body, fists open with thick stone fingers apart, legs
> apart, plain light background, soft even lighting.

**Si sale mal:**
- **El hueco del pecho sale relleno:** *"the chest socket is an empty hole, nothing inside"*.
- **Los brazos salen pegados al cuerpo:** *"arms clearly separated from the torso, A-pose"*. Si no, el rig los funde.
- **Sale realista o dark fantasy:** *"cute chunky chibi proportions, stylized, game for all ages"*.
- **Demasiados cristales** (no se lee como piedra): *"only a few thin crystal veins, mostly plain rock"*.

### Meshy, de imagen a 3D
> chibi cave stone golem, massive rocky torso with empty chest socket, moss, long arms, short legs, A-pose,
> game character, ready for rig

- **Nombre al instalar:** `golem_piedra`.
- **Altura en el juego:** 1,7, unas dos veces un goblin. Ocupa una casilla, pero se ve grande.

### El núcleo (aparte)
> stylized game prop: a round glowing magic CORE stone, a smooth sphere of pale blue crystal with a brighter
> swirling light inside, wrapped by three thin rough rock bands like a cage, hand-painted, single object, plain
> background

- **Nombre al instalar:** `nucleo_golem`.
- **En el juego:** va en el hueco del pecho. Brilla más cuando está expuesto y se apaga al morir.

### Animaciones que hacen falta
| Rol | Qué | Notas |
|---|---|---|
| `idle` | respiración lenta y pesada, polvo cayendo | |
| `walk` | andar muy lento, cada paso hace temblar | va más despacio que la jugadora |
| `attack` | **golpe con los dos puños desde arriba, con una carga larga** (~1 s brazos arriba) | el aviso del juego sale durante la carga |
| `expuesto` | tras el golpe, se queda de rodillas con el pecho adelantado unos 2–3 s y se levanta | es la ventana del punto débil |
| `resbalar` | pierde el equilibrio hacia atrás y cae | para el hielo con viento |
| `hit` | apenas se inmuta, un temblor | |
| `death` | se desmorona hacia delante | el juego puede deshacerlo en rocas (`Rompible3D`) |
| `levantarse` | se incorpora despacio apoyando los puños | |

Si los clips de `walk` o `attack` de Mixamo se ven ligeros, ralentízalos (0,6–0,7): el peso se lee en el tiempo.
