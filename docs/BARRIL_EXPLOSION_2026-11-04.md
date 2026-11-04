# Barril de pólvora: explosión y área de efecto (4/11/2026)

Rama `claude/barril-explosion`. Decisiones de Pablo: la explosión daña a enemigos y jugadora dentro del área (como las bombas de Echoes of Wisdom), un círculo en el suelo avisa del alcance mientras arde la mecha, el radio se queda en `Barril3D.RADIO` = 2,6 u. Todo el fuego sale del FuegoToy oficial.

## Qué se ve

**Aviso (mientras arde la mecha, 1,2 s)** · `AvisoAreaFuego` (`presentacion/vfx/toy/aviso_area_fuego.gd`). Un decal de fuego: una caja de lado 2·RADIO que se proyecta sobre el terreno leyendo la profundidad (`explosion_suelo.gdshader`), así que sigue los desniveles (hasta ±1 casilla) y no hay z-fighting. Borde nítido rojo-naranja a 2,6 u exactos, relleno que crece del centro al borde con la mecha (0 % → 100 %) y late: 1,6 Hz al encender, ≈4,3 Hz a mitad, 8-9 Hz al final. Bordes con lamidos suaves. Desaparece al apagar con agua o al explotar. Cada barril de una cadena tiene el suyo.

**Explosión (≈ 0,8 s; el nodo se libera a 1,35 s)** · `ExplosionFuegoToy` (`explosion_fuego_toy.gd`), paramétrica por `radio`. Junta piezas ya hechas:

| Instante | Qué |
|---|---|
| 0–0,14 s | destello hit22 (estrella) con halo y luz que se apaga; la bola nace |
| 0–0,8 s | bola de fuego redonda: `ImpactoFuegoToy` estilo B (flipbook de Le Lu recoloreado con la rampa de la bola) con radio de impacto 0,85 u (0,327 · radio); se hincha en 0,18 s y se enfría |
| 0–0,6 s | chispas y brasas hacia fuera: `ImpactoFuegoToy` estilo C (≈ 32 trazos y unas brasas, con gravedad y rozamiento) |
| 0–0,38 s | onda a ras de suelo: el frente crece de 0 a 2,6 u (ease-out) y llega exactamente al alcance; el anillo se apaga hacia 0,7 s |
| 0–0,85 s | resplandor rojo-naranja en el suelo que se apaga |

Sin humo. Se mantiene el `PulsoPantalla3D` de antes. El cuerpo y el aro metálico del barril desaparecen (antes el aro se quedaba).

## Colores

Todos de `FuegoToy._rampa_bola` (rojo `(0,85, 0,12, 0,03)` → rojo-naranja `(1, 0,32, 0,03)` → naranja `(1, 0,52, 0,08)` → `(1, 0,64, 0,14)` → `(1, 0,8, 0,42)`). El decal no pasa del 0,85 de la rampa (naranja, g/r = 0,62) y usa sobre todo 0,2-0,6 (rojo-naranja). A la bola y las chispas se les baja la temperatura con `ImpactoFuegoToy.desp_calor` = -0,17 (nuevo, 0 por defecto: los demás impactos no cambian). El único amarillo es el núcleo del primer instante (≈ 0,05-0,1 s).

## Daño (en `Barril3D._explotar`, por las vías que ya existen)

| | Valor | Comparación |
|---|---|---|
| Enemigos (`Combate3D.recibir_golpe_cuerpo`) | `DANO_ENEMIGO` 35, `EMPUJE_ENEMIGO` 6000 | golpe F 5 · jarrón 8 · caja 6 · piedra 12 · geoda 30; goblin 50 de vida (con su defensa le quita 33 y sale despedido ≈ 4 u) |
| Jugadora (`Jugador3D.recibir_dano(20, punto)`) | `DANO_JUGADORA` 20 | un golpe de goblin = 20 sobre 100 de vida; respeta defensa, barrera, bálsamo e invulnerabilidad de 0,7 s; retroceso 4,5 u/s desde el barril |
| Alcance | en el plano ≤ `RADIO` 2,6 u y `ALTO_AFECTA` 1,6 u de diferencia de altura | |

Un escudo activo de frente para el golpe del enemigo (vía `recibir_golpe_cuerpo`). Lo de siempre se rompe (grupo `explosionable`: rocas, muro agrietado, jarrones, cajas).

**Cadena:** hasta ahora no funcionaba (el barril no era `explosionable` ni tenía `recibir_explosion`). Ahora los barriles del grupo `barriles_polvora` a ≤ RADIO se encienden por la explosión (con su mecha de 1,2 s y su aviso). No se metió en `explosionable` para no cambiar lo que hace la lava con ese grupo.

## Mecha

`T_MECHA` sigue en 1,2 s. A 3,0 u/s (correr) se sale del círculo en 0,9 s desde el centro; andando (1,6 u/s) desde el centro no daría tiempo (1,9 u < 2,6 u), pero se enciende casi siempre desde lejos. Si el aviso se ve corto al jugar, 1,5 s deja salir andando desde el borde de la casilla; no se ha cambiado.

## Pruebas y capturas

`herramientas/prueba_barril_explosion.gd` (40 comprobaciones; sobre PruebaBosque real) y `herramientas/captura_barril_explosion.gd` (con ventana). Capturas en `docs/capturas/barril_explosion/`: `explosion_juego.png`, `explosion_cerca.png` (6 instantes: 0,04 · 0,10 · 0,18 · 0,30 · 0,48 · 0,72 s), `aviso_juego.png`, `aviso_cerca.png` (15 %, 50 %, 90 % de la mecha), con la cámara del juego mirando al norte (tamaño 6, inclinada 30°). Los pinos del decorado se esconden en la captura porque tapaban el barril.

`PiezaPuzle3D` (familia «barril») y `VfxPuzle3D.fogonazo` se dejan como estaban: el juego no usa `PiezaPuzle3D` para el barril (solo `Barril3D`), así que nunca salen dos explosiones.
## Revisión de la tarde (4/11/2026, a petición de la coordinación)

- **Destello:** ya no es una bola amarilla grande. Tamaño ×0,45 (`FLASH_K`; ≈1,3 u de diámetro, menos del 30 % del radio) y brillo 2,2 (`FLASH_BRILLO`), que lo deja casi blanco-crema en el centro; pasa a naranja-rojo en ~0,1 s.
- **Masa:** la rampa se recorre por su parte roja, `TRAMO_BOLA` = 0,0–0,5 (antes 0,3–0,8), así que el núcleo es naranja y los bordes rojo intenso; forma más recortada, `RECORTE_BOLA` = 0,24–0,62 (antes sin recorte), para que se vean lóbulos y lenguas y no una nube. `DESP_CALOR` baja de -0,17 a -0,05 (el tramo ya hace el trabajo).
- **Altura y duración:** la bola se aplasta (`APLASTA` = 0,7: más ancha que alta y más pegada al suelo) y dura 0,5 s en vez de 0,8 (`DUR_K` = 0,62; masa visible ≈ 0,45 s). Ya no tapa a la jugadora a 3,6 u. El nodo se libera igual a 1,35 s.
- **Anillo:** el color del frente baja de 0,25–0,6 a 0,1–0,5 de la rampa: más rojo en el borde exterior.
- **Barril encendido:** la emisión (incluso a 0,05) saturaba todo el cilindro de naranja con el entorno del juego, así que se quitó: la madera parpadea de marrón a rojo (`COLOR_MADERA` → `COLOR_MECHA`, mezcla 0,15–0,45). El decal ya no pinta sobre superficies verticales (descarta por la normal reconstruida de la profundidad), así que no tiñe los costados del barril ni los cuerpos; la tapa superior sí recibe algo de tinte.
- Parámetros nuevos de `ImpactoFuegoToy` (`flash_k`, `flash_brillo`, `tramo_bola`, `recorte_bola`, `aplasta_bola`, `dur_k`), todos neutros por defecto.
- Captura extra: `barril_entero_juego.png` / `barril_entero_cerca.png` (barril sin encender).

## 5/11/2026 · Modelo de Meshy, más fuego, barril pequeño lanzable y la colmena

Rama `claude/barril-modelo-lanzable` (desde main, sin merge). Tras el playtest largo de Pablo: «La explosión del barril está bien, falta su asset y que se sienta un poco más como fuego, el tamaño está bien. También puedes hacerlo más pequeño y hacerlo lanzable» y «Hacen falta assets, por ejemplo para la colmena y barril».

### 1. El barril ya tiene su modelo

`Barril3D` deja de dibujarse con un cilindro y un aro y usa el modelo de Meshy **«barril» de la lámina `puzle_terrain`** (el mismo que ya usa `PiezaPuzle3D`: `PiezaPuzle3D.malla_modelo("barril")`): Ø0,98 × 0,95 u, madera con aros de hierro, **calavera pintada** y el agujero de la mecha en la tapa. Sí se reconoce como barril de pólvora (se ve en `barril_modelo_cerca.png`). OJO: `arte/meshy/piezas/barril.glb` / `arte/piezas/barril.tscn` es OTRO modelo (un barril abierto de 0,7 × 0,8 sin calavera, decorado); no se usa porque no se lee como pólvora. No hace falta pedir otro a Meshy.

- Mira a +Z (la calavera de cara a la cámara, que mira al norte) y no se gira. Origen en el centro de la base. Colisión: la caja de siempre (1,0 × 0,95 × 1,0). Si no hay modelo (`PiezaPuzle3D.usar_modelos = false` o falta el GLB) vuelve a las primitivas de antes.
- **Mecha visible:** un cordón fino (0,22 u) sobre la tapa que se acorta según arde, con una **brasa roja en la punta**, chispas naranjas (`VfxPuzle3D._emisor` con la textura `brasa`, no las amarillas de `chispas`) y una luz naranja pequeña (energía 0,7). Apagado, solo el cordón.
- **Parpadeo rojo sin saturar:** el modelo trae su textura, así que el albedo base es blanco y parpadea hacia un tinte rojo suave (`TINTE_MODELO`, mezcla 0,13–0,38); sin emisión. En la prueba: canal verde/azul mínimo 0,80 (nunca por debajo de 0,6) y `emission_enabled` false.
- El aviso del área (`AvisoAreaFuego`) ya no es hijo directo del barril: va suelto (`top_level`) y se coloca a ras del suelo bajo él cada fotograma, para que no gire ni se levante cuando el pequeño viaja.

### 2. Más fuego en la explosión (mismo tamaño y duración de lo fuerte)

`ExplosionFuegoToy` conserva la bola, las chispas y la onda (radio 2,6 u, bola de 0,85 u de radio) y suma, todo de **FuegoToy** (su textura de lenguas, shaders y rampa):

| Qué | Cómo | Cuándo |
|---|---|---|
| **Lenguas** | 6 pilares de FuegoToy (`Figura.PILAR`): uno central (0,55 × 2,3 u) y cinco alrededor (0,28–0,34 de ancho, 1,35–1,9 de alto) a 0,28–0,36 · radio del centro. Cada uno sube desde el suelo y se apaga con su `aparicion` (0 → 1 → 0) | nacen entre 0,04 y 0,19 s; plenos hasta 0,36–0,46 s; se han ido entre 0,72 y 0,88 s |
| **Brasas en el suelo** | 5 pilares enanos (0,13 × 0,34 u) dentro del radio, a 0,38–0,66 · radio del centro (≈ 1–1,7 u), se quedan ardiendo en el suelo | nacen 0,22–0,32 s; empiezan a apagarse a 0,80–0,95 s; se han ido a 1,25–1,40 s (≈ 1 s encendidas) |
| **Humo cálido** | una bocanada de 7 partículas marrón rojizo (0,36, 0,20, 0,14), 40 % de opacidad, que sube y se abre | a los 0,10 s, vive 0,9 s |

Lo fuerte (destello + bola + lenguas) dura ≤ 0,88 s; el nodo se libera a 1,5 s (antes 1,35: lo que se alarga son las brasas del suelo). Colores: a las lenguas se les recorta la rampa (`escala_rampa` 0,72 y `contraste` 1,2 sobre la rampa de fuego, que acaba en amarillo pálido) para que lleguen a naranja y no a amarillo; los bordes son los del pilar validado (blandura 0,22). El único amarillo vivo es el destello del primer instante, como antes. Mismo tamaño: radio, bola y onda no se tocan. Todo escala con `radio / 2,6` (el barril pequeño lo hace ×0,62).

Capturas (cámara del juego, al norte, tamaño 6): `explosion_juego.png` (instantes 0,05 · 0,14 · 0,26 · 0,42 · 0,62 · 0,95 s). Comparada con la de ayer (flash, masa roja con lóbulos, chispas y onda, todo plano a las 0,3 s y sin nada después), ahora a 0,42 s hay una columna de llamas con puntas de varias alturas y a 0,95 s quedan las brasas pequeñas en el suelo con un poco de humo. `explosion_cerca.png` es la misma tira con la cámara más cerca.

### 3. Barril pequeño lanzable

Variante `Barril3D.pequeno = true`: el mismo modelo a ×0,58 (**0,55 de alto**), caja de colisión ×0,58. En el mapa: `; pieza <id> barril x y tam=pequeno` (clave nueva `tam=normal|pequeno` de `Puzle3D`; sin ella es el grande).

| | Grande | Pequeño |
|---|---|---|
| Radio | 2,6 u | **1,6 u** (aviso de área del mismo radio) |
| Daño a enemigos | 35 (empuje 6000) | **20** (empuje 4500) |
| Daño a la jugadora | 20 | **12** |
| Mecha | 1,2 s | **2,4 s** (más larga: hay que poder cogerlo, llevarlo y lanzarlo) |
| Se coge | no | sí, con E |

**Cómo se coge y se lleva:** es un cogible de `CargarObjeto3D` (grupo `cogible`, metadato `barril_pequeno`, fila nueva de `COGIBLES`: vel 0,65, alcance 3 casillas = 6,9 u, golpe 4, no rompe). **Decisión: se CARGA sobre la cabeza (clips `levantar` / `cargar_idle` / `cargar_andar` / `lanzar_objeto`), no es `ligero`** (`ligero: false` explícito, aunque mida 0,55): con `coger_lanzar` se coge y se lanza de una vez en 1,2 s y no habría forma de llevarlo encendido, que es lo que lo hace una bomba. Mientras lo lleva no ocupa casilla ni colisión (`al_coger`), y al soltarlo con Q (`al_soltar`) o caer ocupa la del suelo, como un jarrón. Un golpe recibido con él en brazos lo tira (`al_recibir_golpe`).

**La mecha y cuándo explota:**
- Se enciende igual que el grande: hechizo de fuego o de rayo, una explosión vecina (cadena) o algo que arda a `RADIO_FUEGO` (el contagio entre setos). **La mecha corre también en brazos y en el aire.**
- Encendido y en las manos: explota **donde esté al acabar la mecha, también en las manos de la jugadora** (le hace los 12 de daño, `recibir_dano`; el barril se libera y ella queda con las manos libres). La explosión se centra en el suelo bajo ella.
- Lanzado encendido: explota **al tocar suelo, pared o enemigo, o al acabar la mecha, lo que pase antes**. Gancho nuevo en `CargarObjeto3D._aterrizar`: `al_impactar_lanzado(punto)` (tres líneas; si el objeto lo tiene, se llama justo después de dejarlo).
- Lanzado **sin encender**: no explota nunca; cae, se queda en el suelo (entero, con su casilla) y se puede volver a coger.
- Soltado con Q encendido: sigue ardiendo en el suelo y explota al acabar.
- Cadena: un barril grande que explota a ≤ 2,6 u lo enciende. (El pequeño no alcanza al grande de la casilla de al lado: 2,3 u > 1,6.)
- Arreglo de paso en `CargarObjeto3D._volar`: si el objeto se libera en pleno vuelo (explota en el aire) el cast daba «Trying to cast a freed object»; ahora se comprueba antes.

**Laboratorio:** `mundo/datos_nivel/mapas/PuzlesFuego.txt` (el de puzles de fuego, no se crea otro): dos barriles pequeños en la sala del inicio (10,13) y (14,13), y en la sala de al lado (18,12) otro pequeño y (22,12) un barril grande como blanco (bloque F6).

Capturas: `pequeno_brazos.png` (en el suelo cogido y a 25 %, 60 % y 90 % de la mecha), `pequeno_explosion_manos.png` (explota en las manos: tira de 6 instantes; ella queda dentro del fuego y sale el «12»), `pequeno_lanzado.png` (vuelo con la mecha encendida y explosión al caer; cámara más abierta), `barril_modelo_cerca.png` (grande y pequeño juntos: entero, mecha al 45 % y al 90 %).

**Dónde pondría barriles pequeños en el Bosque 02** (no se ha tocado `Bosque_02.txt`; son propuestas para quien lo edite):
1. **Junto al muro agrietado / la roca que hay que volar**, a dos o tres casillas: un barril pequeño suelto + un brasero o un seto seco cerca para que el jugador aprenda «cógelo, enciéndelo, lánzalo al muro». Es el tutorial natural de la bomba lanzable.
2. **En la pradera de la colmena (`colmena_pradera`, 21,12)**: uno pequeño a 3–4 casillas. El viento tira el panal y el fuego lo quema con nube de veneno; un barril lanzado desde lejos quema la colmena sin entrar en la nube (la nube mide 1,5 u y el barril 1,6: se lanza a ≥ 3 u).
3. **Detrás de un grupo de goblins quietos o en un campamento**: uno encendido y lanzado limpia a dos o tres (20 de daño, 50 de vida cada uno: dos barriles o barril + golpe).
Mejor de uno en uno y sin que haya otro grande a menos de 2,6 u de donde caerá (la cadena lo haría explotar solo).

### 4. Colmena y otros assets

- **Colmena:** `objetos/colmena_3d.gd` (pieza `colmena` del mapa, `; pieza <id> colmena x y`). **No hay modelo**: busca `res://arte/piezas/colmena.tscn` y no existe, así que dibuja primitivas (una rama de 0,5 u y una esfera de cera de r = 0,28 de color `COLOR_CERA` (0,95, 0,76, 0,30) colgando a 1,4 u). No se ha generado nada. Lo que el modelo tiene que traer: el origen en el suelo de la casilla y todo colgando de un punto a ~1,85 u (la rama arriba, el panal a 1,4 u de centro); **un nodo hijo llamado `panal`** (el cuerpo de la colmena), que el código esconde cuando el viento lo tira; mide ≈ 0,6 de ancho y 0,75 de alto (el cuerpo). `arder()` esconde todo el modelo.

  **Prompt de Meshy para la colmena** (para pegar con el estilo común de `arte/meshy/PROMPTS_INVENTARIO.md`):
  > A wild beehive hanging from a short gnarled branch stub, stylized chibi game prop: a plump, slightly drooping teardrop-shaped beehive made of layered rounded wax scales in warm honey gold (#F2C14E) with soft amber bands (#D9A640), a small round dark entrance hole in the lower third, two fat drips of honey on one side, a few little bee-yellow dots as bees, the short branch stub on top in warm brown bark (#7A5A3A) with two soft green leaves (#6DBE5A) and a loop of the branch holding the hive. Toy-like, chunky rounded shapes, hand-painted pastel texture, clean simple silhouette, low detail, single object, no ground, no base, plain background, soft even lighting, front three-quarter view, about 0.6 wide and 0.75 tall for the hive

  Si sale con abejas de relieve o demasiado realista: *«simple shapes, low detail, toy-like»*. Después, el Pipeline separa la rama y el cuerpo (nodo `panal`) y lo deja en `arte/piezas/colmena.tscn` (el lado bonito hacia −Z).
- **Barril:** el modelo actual sirve (se lee como pólvora). Si Pablo quiere un aspecto más de «bomba» para el pequeño, prompt opcional: *«A tiny powder keg bomb for a chibi fantasy game: a small round wooden barrel (about 0.55 high) with two dark iron hoops, a skull and crossbones painted in black on the front, a short cream fuse sticking out of a hole in the lid, toy-like chunky rounded shapes, soft hand-painted pastel texture, single object, no ground, plain background, front three-quarter view»*. No hace falta para que funcione.
- Otros que siguen sin modelo y se dibujan con primitivas: `Nido3D` (`PROMPTS_INVENTARIO.md` ya trae su prompt) y la tinaja vacía.

### 5. Pruebas

`herramientas/prueba_barril_explosion.gd` pasa de 40 a **76 comprobaciones** (sobre PruebaBosque real): el modelo se carga y mide lo que debe (grande 0,95 × Ø0,98; pequeño 0,55 × Ø0,57; centrado, sin girar, colisión), la mecha, las chispas y el parpadeo sin saturar, las lenguas y brasas (6 y 5, envolvente y duración), el aviso a ras de suelo; y el pequeño: se coge, se lleva encendido y explota en las manos a los 2,4 s dañando a la jugadora (12), lanzado encendido explota al impactar con daño menor (18–20) y a un enemigo fuera del radio 1,6 no le pasa nada, lanzado sin encender no explota (ni pasado el tiempo de la mecha), con la mecha casi acabada explota en el aire, contra una pared explota delante de ella, y la cadena con el barril grande sigue.
`herramientas/captura_barril_explosion.gd` saca todas las capturas de arriba (con ventana).