# Trampas de pared que lanzan hechizos (5/11/2026)

Petición de Pablo: *«aprovechar los hechizos para crear objetos que "lancen" un hechizo de forma recurrente: el lanzallamas perpetuo del Zelda; una cabeza larga con boca de dragón que escupe fuego de forma continua; una trampa que dispare flechas + fuego. Así aprovechamos el sistema para crear otras cosas»*. Después: *crear el prototipo, medirlo y preparar los prompts de los assets; un dragón tipo Herensuge para el dragón; libertad para las flechas (que se intuya una flecha de fuego); en ambos casos, TRAMPAS DE PARED.*

Rama `claude/trampas-pared` (desde `main`, sin merge). Código en `objetos/trampa_pared_3d.gd` (base), `trampa_dragon_3d.gd`, `trampa_flechas_3d.gd` y `flecha_trampa_3d.gd`; pieza de mapa en `escenas/puzle.gd`; ejemplos en el laboratorio de puzles de fuego (`PuzlesFuego.txt`, salas F7–F9); prueba `herramientas/prueba_trampas_pared.gd`; capturas con `herramientas/captura_trampas_pared.gd` en `docs/capturas/trampas_pared/`.

---

## 1. Diseño

### Una pieza genérica que lanza un hechizo REAL

`TrampaPared3D` (clase base, un `Area3D` reactivo) es una pieza pegada a un muro que, con su ciclo, **construye un `Hechizo` y lo crea con `HechizoVivo.crear(hechizo, origen, dir, lanzador)`**, el mismo camino que la jugadora (`Lanzador3D.lanzar_hechizo`), usando el `Lanzador3D` del grupo `spellcaster`. Sin tinta, sin recarga y sin la animación de la jugadora, pero con todo lo demás: el sonido del hechizo, el dibujo oficial (FuegoToy: el chorro y la bola en vuelo), las reacciones (el agua apaga el fuego, un muro de tierra o una barrera lo parte, enciende setos, cuerdas, barriles y braseros, deja el suelo quemado) y el daño a los enemigos por `Combate3D`.

Dos hijos ponen el ciclo y el dibujo:

| | Dragón (`trampa_dragon`) | Mascarón de flechas (`trampa_flechas`) |
|---|---|---|
| Qué lanza | el **haz** de siempre (`elemento` + ᛁ × (alcance − 2); el chorro de FuegoToy), relanzado cada 0,8 s mientras dura el fuego | una **flecha**: `elemento` + ᛇ (la bola de fuego en vuelo de FuegoToy) sin caída, con la velocidad y el alcance del mapa. `elemento=ninguno`: una flecha normal (un palo que vuela recto, `FlechaTrampa3D`, sin hechizo) |
| Ciclo | `ciclo=<encendida>,<apagada>` s + `desfase` | `cada=<s>` + `desfase` |
| Aviso | 0,5 s antes de cada escupitajo: la cabeza retrocede, abre la mandíbula, echa brasas y humo, y la boca se enciende | 0,35 s antes de cada disparo: la ranura pasa del rescoldo al rojo vivo; fogonazo de 0,25 s al salir |
| Movimiento | respira en reposo, retrocede al avisar, se lanza hacia delante al escupir y tiembla | ninguno (los carbones del brasero parpadean) |

### Por qué el chorro es un haz relanzado

El haz del juego es **instantáneo**: aplica su golpe a todo el recorrido al nacer y se queda dibujado `HAZ_DURA_S` = 0,9 s (`Hechizo`, `HechizoVivo._materializar_haz`). No existe un haz «sostenido». Para un chorro continuo se **relanza el haz cada `TICK_S` = 0,8 s** mientras dura el fuego: los dibujos se solapan 0,1 s y se ve continuo, y cada haz vuelve a golpear lo que hay dentro (los enemigos, los setos, los barriles…). Consecuencia que se ve en pantalla y no es un fallo: **la última llama aguanta hasta 0,9 s tras el último haz**, así que el chorro se ve algo más de lo que dura el daño (con `encendida=2.0` los haces salen a 0,0 · 0,8 · 1,6 s y la última llama se apaga a los 2,5 s). La llama residual no hiere a la jugadora (el daño solo se da en los haces).

`TICK_S` está elegido a propósito **mayor que la invulnerabilidad de la jugadora** (`Jugador3D.INVULNERABLE` = 0,7 s): así cada haz entra y el daño sostenido es previsible (10 / 0,8 s = 12,5 por segundo).

### Cómo se hiere a la jugadora

Un haz no hiere al lanzador, y un proyectil con `golpea_lanzador` ni la hiere en los primeros 0,25 s (`HechizoVivo.SEGURIDAD_S`) ni se acaba al herirla. Por eso **la propia trampa** hace lo que hace el barril: `Jugador3D.recibir_dano(cantidad, desde)`, que respeta su invulnerabilidad, la defensa, el bálsamo y la burbuja de barrera.

- Dragón: en cada haz, si la jugadora está **dentro del chorro** (a ≤ 0,75 u del eje, entre 0,5 u antes de la boca y el final del haz cortado por la primera casilla sólida, y a la altura del suelo del chorro): 10.
- Flecha: la trampa vigila el proyectil; si pasa a ≤ 0,6 u de la jugadora (horizontal) y a ≤ 1,7 u por encima de sus pies, le hace 12 y **termina la flecha** con su impacto de golpe. La flecha normal hace lo mismo por su cuenta.
- A los enemigos los hiere el hechizo con las vías de siempre (`_golpear`, `on_spell_hit`, estados y quemadura).

### Cómo se desactiva

- **Agua o hielo** (hechizo real de la jugadora, o `on_spell_hit`): la apaga **8 s** (`T_AGUA_S`); vuelve sola, en reposo y empezando el ciclo desde el principio. `agua=no` en el mapa: el agua no la apaga.
- **Reglas del mapa**: `hace=<id>.apagar(<s>)` (s segundos; sin argumento, hasta `encender`) y `hace=<id>.encender`. Señales: `escupe`/`calla`/`apagada` (dragón), `dispara`/`apagada` (flechas). Condiciones: `si=<id>.activa` / `.apagada`.
- **Obstáculos**: un bloque de piedra (empujable o de tierra), una barrera o un muro delante de la boca paran el chorro y la flecha como a cualquier hechizo.
- **Lejanía** (`cerca=<casillas>`): dormida (ciclo parado, sin lanzar nada) mientras la jugadora esté a más de esas casillas de la casilla de delante. Es útil para que una trampa no gaste ni se «gaste» antes de que la jugadora llegue (lo usan F7, F8 y F9).

### Colocación: dentro del muro

`x y` es la casilla del **MURO** (una `#`) y `mira` (n|e|s|o) hacia dónde da: lo que lanza sale a la casilla de delante, que tiene que ser suelo (`Puzle3D._casilla_valida` avisa y no monta la pieza si no). El nodo se coloca en la cara del muro (centro + media casilla hacia `mira`), a ras del suelo de la casilla de delante, con su +Z local hacia fuera. No bloquea nada (como un adorno con boca): quien se pega a ella la atraviesa.

**Cámara (importante para el arte y para el diseño de niveles).** La cámara del juego es fija y mira al norte desde el sur: **los muros del norte con `mira=s` se ven de frente** (así salen las capturas); los muros del este y del oeste (`mira=o`/`e`) se ven **de canto** (el mascarón parece una columna delgada; la flecha en vuelo se ve bien); los del sur (`mira=n`) quedan **detrás del muro** y casi no se ven. En el laboratorio los muros son pinos (las `#` del Bosque): los pinos del muro sur de la sala tapan la parte de abajo.

La caja con la que recibe hechizos (`prof_cuerpo()`) **tiene que acabar antes de donde nace lo que lanza**: un proyectil que nace dentro de un `Area3D` reactivo se golpea a sí mismo y se para ahí (así murió la primera flecha de fuego, en la propia ranura).

---

## 2. Formato de mapa

```
; pieza <id> trampa_dragon  x y [mira=n|e|s|o] [ciclo=<encendida>,<apagada>] [desfase=<s>] [alcance=3..6] [elemento=fuego|agua|hielo|rayo|tierra|viento] [agua=si|no] [cerca=<casillas>]
; pieza <id> trampa_flechas x y [mira=n|e|s|o] [cada=<s>] [desfase=<s>] [alcance=<casillas>] [vel=<casillas/s>] [elemento=fuego|ninguno|agua|…] [agua=si|no] [cerca=<casillas>]
```

| clave | defecto | qué hace |
|---|---|---|
| `mira` | `s` | hacia dónde da (la casilla de delante tiene que ser suelo) |
| `ciclo` | `2.0,1.5` | dragón: s de fuego y s de descanso. El ciclo se cuenta desde el inicio del descanso: reposo → aviso (los últimos 0,5 s del descanso) → fuego. `apagada=0` escupe siempre; `encendida=0` nunca |
| `cada` | `1.2` | flechas: s entre disparos (el aviso son los últimos 0,35 s) |
| `desfase` | `0` | en qué punto del ciclo empieza (s). Con `desfase` dentro del fuego, el dragón empieza ya escupiendo |
| `alcance` | dragón `5` (3–6) · flechas `8` (1–8) | dragón: casillas de chorro desde la boca (ᛁ × alcance−2); flechas: casillas de vuelo (`distancia_max`, tope de un hechizo = 8) |
| `vel` | `3.5` | flechas: casillas/s (= 8,05 u/s; la flecha del goblin va a 9 u/s) |
| `elemento` | `fuego` | el elemento del hechizo. `ninguno` (solo flechas): flecha normal |
| `agua` | `si` | `no`: el agua y el hielo no la apagan |
| `cerca` | `0` | casillas: dormida mientras la jugadora esté más lejos (0 = siempre despierta) |

Reglas: `cuando=<id>.escupe|calla|apagada` (dragón) o `.dispara|apagada` (flechas); `si=<id>.activa|apagada`; `hace=<id>.apagar(<s>)` y `hace=<id>.encender`. Ejemplo: `; puzle apaga cuando=boton.pulsado hace=drg.apagar(8) y=fl.apagar`. La gramática completa está en la cabecera de `escenas/puzle.gd` (tabla de piezas, señales, condiciones y acciones); el tipo de valor nuevo `par` lee `ciclo=2.0,1.5`.

### Ejemplos puestos (`PuzlesFuego.txt`, laboratorio de puzles de fuego; teclas **6, 7 y 8** llevan a F7, F8 y F9)

- **F7 · dragones cronometrados** (sala (3,1), x 25–31, y 9–13; añadí muros en y=14–15 para que no se rodee): dos cabezas en el muro norte, `(26,8)` y `(30,8)`, `mira=s`, `ciclo=1.5,2.0` y la segunda con `desfase=1.75` (nunca arden las dos a la vez; callan las dos 0,5 s de cada 3,5). Chorros por las columnas x=26 y x=30 (alcance 5: cubren y=9..13). Placa de presencia en `(31,12)` y botón `!` en `(25,10)` que apaga los dos 8 s. `cerca=8`.
- **F8 · flechas que se esquivan o se bloquean** (sala (0,2)): mascarón normal en el muro `(8,20)`, `mira=o`, `cada=1.5`, `elemento=ninguno`, por la fila y=20 hasta la placa `(1,20)`; un bloque de piedra empujable en `(5,21)` que se empuja al norte a `(5,20)` y tapa lo de detrás. `cerca=8`.
- **F9 · la flecha de fuego que enciende** (sala (1,2)): mascarón de fuego en el muro `(8,22)`, `mira=e`, `cada=3.0`; la flecha prende el seto `(12,22)`, el fuego corre al seto `(13,22)` y enciende el barril `(14,22)`, que explota (uso positivo de la trampa). Botón `!` en `(9,18)` que la apaga. `cerca=6`. Agua a un seto = cortafuegos (como F4).

El lab pone HUD con el estado de cada trampa (reposo / AVISO / ESCUPE / APAGADA) y carteles. No se ha tocado `Bosque_02.txt`.

---

## 3. Números medidos

Todos salen de `herramientas/prueba_trampas_pared.gd` (líneas `MEDIDA …`) salvo lo marcado. **Unidades:** u del motor; 1 casilla = 2,3 u; la jugadora anda a 1,6 u/s y corre a 3 u/s.

### Tamaño en la pared (para el arte)

| | Dragón | Mascarón de flechas |
|---|---|---|
| Losa pegada al muro (ancho × alto × grueso) | 2,0 × 2,6 × 0,30 u (0,87 × 1,13 × 0,13 casillas) | 1,6 × 1,9 × 0,30 u (0,70 × 0,83 × 0,13 casillas) |
| Pieza entera (ancho × alto × saliente) | 2,00 × 2,60 × **1,70** u con la cabeza lanzada (0,74 casillas de saliente); × 1,21 con la cabeza retraída | 1,60 × **2,21** (con el brasero) × 0,68 u (0,30 casillas de saliente) |
| Altura de la boca / ranura sobre el suelo | **1,20 u** (0,52 casillas) | **0,95 u** (0,41 casillas) |
| Distancia de la boca a la cara del muro | 1,70 u (retraída: 1,21) | 0,62 u |
| Caja con la que recibe hechizos | 1,6 × 1,8 × 1,05 u | 1,6 × 1,8 × 0,55 u |
| Para comparar | un goblin mide 0,85 u de alto; la casilla, 2,3 | |

### Alcance

| | Medido |
|---|---|
| Chorro (dragón) | con `alcance=N` el haz golpea las casillas **1…N de delante del muro** (la 0, pegada a la cabeza, no la golpea el hechizo; la herida a la jugadora sí la cubre desde 0,5 u antes de la boca). Medido con reactivos en cada casilla para N = 3, 4, 5, 6: `[1,2,3]`, `[1..4]`, `[1..5]`, `[1..6]`, y la siguiente a la última no. Medido en u: con alcance 5, el chorro llega a **12,8 u de la cara del muro (5,57 casillas)**, cortado por la primera casilla sólida |
| Chorro con un bloque de piedra en la casilla 3 | llega a la 2 y no más |
| Anchura | el recorrido del haz es de 1 casilla; el dibujo, 0,8 u (0,35 casillas); el daño a la jugadora, ±0,75 u del eje (1,5 u) |
| Flecha | `vel=3.5` → medida **7,9 u/s de media** (8,05 pedidos, con el arranque suave); recta (desvío 0,000 u); en la sala de prueba recorre **15,0 u (6,5 casillas) en 1,90 s** hasta el muro del fondo y se para ahí (causa «muro»); con `alcance=3` se acaba a las 2,84 casillas (causa «alcance»); un bloque la para antes (causa «golpe») |

### Tiempos

| | |
|---|---|
| Ciclo del dragón (defecto) | 2,0 s de fuego + 1,5 s de descanso = 3,5 s |
| Aviso del dragón | **0,5 s** (medido 0,50 con pasos de 1/30 s: aviso a los 0,5 s, fuego a los 1,0 s, reposo a los 2,2 s en un ciclo de 1,2 + 1,0) |
| Haz del dragón | cada 0,8 s (dos haces en 1,2 s de fuego: a 0,0 y a 0,8; tres en 2,0 s); dibujo 0,9 s |
| Mascarón | `cada=1,2` por defecto (F8 1,5 · F9 3,0); aviso **0,35 s** (medido 0,37); fogonazo 0,25 s |
| Despertar de agua | 8 s |

### Daño

| | A la jugadora | A un goblin (50 de vida) |
|---|---|---|
| Dragón | **10 por haz**, entra cada haz (0,8 s > 0,7 s de invulnerabilidad): **12,5 por segundo** sostenido; un segundo haz dentro de la invulnerabilidad no hiere (medido: 90 → 90 → 80). Cruzar el chorro andando (1,5 u a 1,6 u/s ≈ 0,9 s) cuesta 1 haz (10), a veces 2; corriendo (0,5 s), 0 o 1. **Cruzar el pasillo de F7 sin esperar el turno andando, 20 (2 haces)** | 7,9 por haz + la quemadura; 4 haces en 3,2 s: 31,6 (9,9/s) |
| Flecha de fuego | **12** (= la flecha del arquero goblin) | el hechizo `fuego + ᛇ` es de 13,2 de base y 3 s de quemadura: en la prueba el goblin **muere** (53,3 en el golpe medido a los pocos fotogramas). La flecha de fuego de la JUGADORA (mismo hechizo) deja al goblin en 37,9 menos a los 2 s. La diferencia no se ha aislado (la bola de la trampa es más gruesa: semieje 0,28 m frente a 0,10) |
| Flecha normal | **12** | 12 (`receive_damage`) |
| Para comparar (dado por Pablo / código) | golpe de goblin **20**, barril **20** a la jugadora, flecha de goblin 12 | |

---

## 4. Lo que está comprobado y lo que no

`herramientas/prueba_trampas_pared.gd` (**FALLOS 0**, 90 comprobaciones, sobre el lab real con maqueta, jugador y Lanzador3D): la gramática (y rechaza trampa en suelo, que dé a un muro o fuera del mapa, `ciclo` roto, `mira` desconocida); las cuatro orientaciones; el ciclo (aviso 0,5 s, desfase, `apagada=0`/`encendida=0`, los dos de F7 nunca a la vez); `cerca` (dormida y despierta); el alcance del chorro (3 a 6) y que un bloque lo para; la herida a la jugadora dentro y no fuera (al lado, más allá del alcance, junto a la boca, otro nivel, en reposo), con la invulnerabilidad; el daño a un enemigo; el agua (golpe, flecha de agua REAL de la jugadora, `agua=no`, hielo, la regla del botón de F7 que apaga 8 s y la vuelta sola); la flecha de fuego (hechizo de proyectil, recta, velocidad, para en el muro, en un bloque y por alcance, hiere a la jugadora una vez y se acaba, no toca otra fila, daña a un enemigo, `cada` y aviso); la flecha normal (recta, se libera, 12 a la jugadora, la tapa un bloque, daña a un enemigo); F7 andando por el pasillo hasta la placa; F8 (sin bloque recibe flechas, con el bloque empujado a la fila no); F9 (dormida con la jugadora lejos; flecha → seto → seto → barril explota); y que los nodos no se acumulan (12 s de tres trampas a tope + 6 s de calma: mismos hijos del lanzador, la maqueta y el decorado que al principio; pico de +5 hechizos vivos).

**No verificado:** a mano con ventana (solo capturas); el viento (desviar la flecha o el chorro) no se ha probado, aunque pasa por el mismo sistema; el hielo contra el chorro (solo apaga la trampa); ningún nivel real (Bosque 02 no se ha tocado); el sonido es el del hechizo y `fuego_carga` en el aviso del dragón (no hay sonido propio); la trampa no guarda estado (al recargar el nivel empieza de nuevo); en niveles con varias trampas conviene `cerca` (cada haz es un nodo con su luz). El `Area3D` de la trampa no bloquea a la jugadora (puede atravesar la cabeza). Los modelos son primitivas: el arte de abajo las sustituye.

---

## 5. Para el arte: qué debe traer cada modelo

Convención del Pipeline (`PROMPTS_INVENTARIO.md`): una pieza por generación, sin rig, presupuesto de pieza **≤ 3 000 triángulos**, textura 1024 (a este tamaño en pantalla basta), `.glb` con **un nodo por pieza móvil**. **Origen:** el centro del borde inferior de la **cara trasera plana** de la losa (el plano que se pega al muro), a ras de suelo; **el lado bonito (la boca) hacia −Z** (el Pipeline lo orienta; al enganchar el modelo, `TrampaPared3D` lo girará 180° para dejar la boca hacia +Z local). La cara trasera de la losa tiene que ser **completamente plana** y llegar al borde (se entierra 0,1 u en el muro).

Los nombres de nodo que el código esperará (aún no están enganchados: hoy dibuja primitivas con estos mismos nombres):

| Dragón | `Losa`, `Hueco` (el arco oscuro), `Cuello` (cadena de 5 segmentos o un solo mesh deformable), `Cabeza` (sin mandíbula, pivote en el cuello), `Mandibula` (pieza aparte, pivote en la bisagra bajo y detrás del cráneo, que abre ~45°) |
|---|---|
| Mascarón | `Losa`, `Cara` (el relieve), `Ranura` (la ranura de arquero: la pieza que se ilumina, material propio emisivo), `Ojos` (material propio emisivo), `Brasero` y `Carbones` (material propio emisivo) |

Colores del juego: fuego `#F2551E`; el dragón en **rojo-naranja con contraste, nunca amarillo dominante** (la rampa de FuegoToy, el gusto de Pablo: blando tipo Link's Awakening / Echoes of Wisdom).

### Prompt 1 · Dragón tipo Herensuge para trampa de pared

Referencia: el **Herensuge** (la serpiente-dragón de siete cabezas de la mitología vasca: cabezas de cuello largo y escamoso que salen de una cueva y escupen fuego); aquí **UNA** cabeza.

> A single dragon head on a long scaly serpent neck, inspired by the Basque Herensuge (the seven-headed cave serpent-dragon): the neck rises out of a dark rounded cave mouth carved in a flat rectangular stone slab and curves in a gentle S towards the front, the head hanging in front of the slab with its mouth slightly open as if about to spit fire. Stylized chibi game prop, soft toy-like Link's Awakening / Echoes of Wisdom look. Scales warm red-orange (#C8391F) with a lighter orange belly and underside ridges (#F2551E) and darker red shadow scales (#7A1E14), small orange back spines along the neck, two short curved dark horns (#3A1A14), big round glowing amber-orange eyes (#FF8A2A), chunky soft snout with two nostrils, rounded blunt teeth, mouth interior glowing ember red-orange (#F2551E). NEVER yellow as the main color; no gold, no cream, no green. The lower jaw is a SEPARATE hinged piece (own node `Mandibula`, pivot at the back hinge below the skull) so it can open about 45 degrees; the head (`Cabeza`) is another piece and the neck (`Cuello`) is a chain of 5 chunky rounded segments so it can retract into the cave mouth. The slab (`Losa`) is a flat rectangular stone wall slab in warm grey stone (#8A7F76), mossy at the corners, with chunky rounded edges and a rounded arch frame (`Hueco`) around the dark cave mouth; the BACK of the slab is perfectly flat and reaches all the edges so it can be pushed against a wall. Scale: slab 2.0 wide x 2.6 tall x 0.30 thick; the mouth centre sits 1.2 above the bottom of the slab; with the neck fully extended the snout reaches 1.7 in front of the back face (retracted: 1.2); the arch opening about 1.0 wide x 1.15 tall. Origin at the bottom centre of the flat back face; the front (mouth) towards -Z. Toy-like, chunky rounded shapes, hand-painted pastel texture, clean simple silhouette, low detail, single object, no base, no ground, no characters, plain background, soft even lighting, front three-quarter view. Under 3000 triangles.

Si sale demasiado realista: *«simple shapes, low detail, toy-like»*. Si la cabeza sale como serpiente sin cuernos: pedir *«two small curved horns and a rounded dragon snout»*. Pedir **sin cuerpo detrás de la losa**: lo que sobra del cuello se esconde dentro del arco.

### Prompt 2 · Trampa de flechas de fuego

Libre: un **mascarón de piedra con ranura de arquero y brasero de carbones**; se intuye que sale una flecha de fuego (la ranura ennegrecida, el brasero encendido encima y las vetas de hollín).

> A carved stone guardian mask for a wall arrow trap, stylized chibi game prop: a chunky rounded salamander-like face in warm grey stone (#8A7F76) set into a flat rectangular stone slab, two narrow slanted eye slits glowing ember orange (#F2551E), a heavy brow ridge, and instead of a mouth a long horizontal ARCHER SLIT (about 0.84 wide x 0.16 tall) that is dark and blackened with soot streaks running down from it, with a glowing red-orange ember visible deep inside the slit (#F2551E), as if a flaming arrow is about to fly out. On top of the head sits a small round stone brazier bowl holding three glowing red-orange coals (#F2551E, #C8391F) with a few tiny ember specks. Small carved arrow-feather patterns along the border of the slab, scorched black tips on the slab edges. NEVER yellow as the main color. The slit (`Ranura`), the eyes (`Ojos`), and the coals (`Carbones`) are separate pieces with their own materials so they can glow; the brazier bowl (`Brasero`) is its own piece. The BACK of the slab is perfectly flat and reaches all the edges so it can be pushed against a wall. Scale: slab 1.6 wide x 1.9 tall x 0.30 thick; the carved face relief protrudes to 0.68 in front of the back face and the archer slit sits 0.95 above the bottom of the slab and 0.62 in front of the back face; the brazier rises to 2.2 total height. Origin at the bottom centre of the flat back face; the front (slit) towards -Z. Toy-like, chunky rounded shapes, hand-painted pastel texture, clean simple silhouette, low detail, single object, no base, no ground, no characters, plain background, soft even lighting, front view slightly from above. Under 2500 triangles.

Variante (si el mascarón no convence): *«a boar head» / «a snarling lizard head»* con las mismas ranuras ennegrecidas y el mismo brasero.

Tras generarlos: el Pipeline separa las piezas con los nombres de arriba y los deja en `arte/piezas/trampa_dragon.tscn` y `arte/piezas/trampa_flechas.tscn`; el código ya expone `boca_local()` y `prof_cuerpo()` (ajustar si el modelo cambia las medidas) y las piezas móviles de las primitivas se llaman igual (`Cabeza`, `Mandibula`, `Cuello0..4`, `Ranura`).

---

## 6. Capturas (`docs/capturas/trampas_pared/`, cámara del juego, a cámara lenta)

- `dragon_ciclo_cerca.png` / `dragon_ciclo_juego.png`: reposo · aviso · fuego al empezar · fuego a tope · fuego al final.
- `dragon_pasillo.png` (F7 con los pinos del muro, tal cual el juego) y `dragon_pasillo_limpio.png` (sin pinos).
- `mascaron_frente_cerca.png` / `_juego.png`: los dos mascarones de frente (fuego a la derecha, flecha normal a la izquierda): reposo · ranura avisando · fogonazo · flecha en vuelo.
- `mascaron_flecha_secuencia.png`: F9 de canto (el mascarón del muro oeste visto de lado): ranura apagada · avisando · flecha en vuelo · el seto prendiendo.
