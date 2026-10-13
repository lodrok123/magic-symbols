# Equipo del goblin y otros assets para Meshy (5 de octubre de 2026, versión 2)

**Modo:** un objeto por generación, NO en lámina. Así cada pieza tiene toda la textura para ella sola.
Estilo común (pégalo al final de cada prompt):

> stylized chibi game asset, soft pastel colors, hand-painted texture, chunky rounded shapes, clean
> simple silhouette, no base, no ground, plain background

Al bajarlos: el GLB en `meshy\entrada\` con el nombre del id (`garrote.glb`...). Yo los oriento, los
escalo y los paso a `poc_25d\equipo\`. Mientras tanto el goblin lleva el garrote y el escudo hechos
por código (`equipo_3d.gd`).

## 1. Equipo del goblin warrior: mismo método que la elfa (imagen de concepto y luego Meshy)

**Referencia:** `referencias/goblin_referencia.png` (el goblin chibi de frente y de 3/4, sin armas).

**Paso 1. Imagen de concepto de cada pieza.** Genera **una imagen por objeto** (Meshy trabaja mejor con
un objeto solo) y sube `goblin_referencia.png` como referencia de estilo.

Garrote:
> A weapon for the goblin in the reference image, same stylized chibi 3D game style, same soft hand-painted
> texture and warm earthy palette (tan leather, light brown wood, muted green, cream bandages).
> A crude goblin wooden club: a thick knotted branch head with three small rusty iron studs, the grip wrapped
> in cream cloth bandages tied with rope, like the bandages on the goblin's arms and legs. Chunky, rounded,
> friendly shapes, not realistic, not scary. Single object, no hands, no character, standing vertically,
> full object visible, front view, plain light background, soft even lighting.

Escudo:
> A shield for the goblin in the reference image, same stylized chibi 3D game style, same soft hand-painted
> texture and warm earthy palette. A small round goblin shield made of three rough light-brown wooden planks,
> a dented dull iron rim, a round iron boss in the center, a patched leather piece and a cream bandage wrapped
> on one side, matching the goblin's patched clothes. Chunky, rounded, friendly shapes. Single object,
> no character, seen from the front, slightly tilted, full object visible, plain light background,
> soft even lighting.

Si sale demasiado detallado o realista, añade: *"simple shapes, low detail, toy-like"*.

**Paso 2. Meshy, de imagen a 3D**, una vez por imagen. Texto: *"stylized chibi game prop, single object"*.
Sin rig: las armas no lo necesitan.

**Paso 3.** Descarga los GLB y déjalos en `meshy\entrada\` como `garrote.glb` y `escudo.glb`. Yo los oriento
(mango en el origen), los escalo al goblin y los paso a `poc_25d\equipo\`. El goblin los usará solo,
sin cambiar código: `equipo_3d.gd` busca primero el GLB y, si no está, usa la versión hecha por código.

**Opcional, `espada_goblin`:** igual que el garrote, cambiando el objeto por
*"a short chipped goblin cleaver sword, rusty blade, wooden handle wrapped in cream bandages"*.

**El arma de la elfa es su grimorio, no un bastón:** ver `PROMPTS_GRIMORIO.md`.

## 2. Para rehacer (salieron mal o muy pobres en las láminas)
Por orden de lo que más se ve en la maqueta:
| id | qué pasa ahora | prompt |
|---|---|---|
| `arbol_redondo` | 2000 triángulos, de cerca se ve borroso | round fluffy cartoon tree, big puffy light-green canopy made of soft rounded clumps, short thick brown trunk with roots |
| `pino` | facetado | cartoon pine tree, layered teal-green tiers with soft rounded tips, short brown trunk |
| `seto_seco` | plano, en fila parece un ciempiés | dry thorny bramble hedge block, tangled brown branches with a few orange dry leaves, roughly cubic, can be tiled side by side |
| `arco_puerta` | se puede quedar; mejor suelto | ancient stone archway gate with moss and ivy, two pillars and a rounded top, wide opening |
| `puesto` | se puede quedar | small market stall with blue and white striped awning, wooden counter with books on it |
| `totem_runico` | se puede quedar | carved stone rune totem with a glowing blue rune on the front, moss at the base |
| `matas` | rocas de cristal | **no hace falta**: la hierba ya se hace por código (`hierba_3d.gd`) |
| `flores` | bolas | **no hace falta**: las flores ya se hacen por código |

## 3. Personajes
- **Elfa nueva con la base de la librera:** ver `PROMPTS_ELFA.md`.
- **Goblin con el arma en la mano:** **no** hace falta regenerarlo. El arma va aparte, colgada del hueso de la
  mano, y así se puede cambiar.
