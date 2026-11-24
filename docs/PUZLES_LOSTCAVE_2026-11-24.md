# Puzles para Lost Cave (24/11/2026)

Propuesta de puzles para el nivel `LostCave` (`escenas/PruebaLostCave.tscn`, mapa generado por `tools/mapa_lostcave.py`), con las
piezas de puzle que ya existen (`escenas/puzle.gd`) y las del pack «Stylized Lost Cave» donde tienen sentido.

**Estado (24/11, tarde): MONTADOS los siete** en `tools/mapa_lostcave.py` (genera `LostCave.txt`), con la escena en el kit `demo`. La prueba
`herramientas/escenario_lostcave_puzles.gd` los resuelve todos en el juego: 0 fallos. Lo que cambió respecto a la propuesta está en §4.

Reglas que se respetan: solo **fuego, agua y tierra** y los glifos del kit demo (flecha, línea ᛁ, barrera ᛜ, altura, pulso ᚱ, suelo ᛒ);
enemigos de cueva: **gólem y limos**; nada de hielo, viento, magma ni naturaleza. Lost Cave se lee como las **Cuevas del paso 6** de la ruta
(`PUZLES_DEMO_TRES_SELLOS_2026-11-20.md` §5.2): se llega con los tres sellos y es donde se aprende la tierra.

---

## 1. Inventario

### 1.1 Lo que tiene hoy Lost Cave
Cinco salas, **solo decorado** (122 piezas `decorado`), ningún puzle, ningún enemigo, ningún cofre, sin entrada ni salida a otros niveles.

| Sala | Casillas | Decorado del pack que ya hay |
|---|---|---|
| BOCA | 11,18 · 9×7 | arco grande, árboles, helechos, setas, faroles de pie |
| CRUCE | 8,8 · 15×7 | arco de roca, 2 columnas, grieta azul brillante, estalagmitas, 2 cristales sueltos |
| MINA | 1,4 · 6×13 | bocamina, vía con curva, 2 vagonetas, carro, barriles, cajas, pico, pala, **dinamita, detonador y bomba** |
| CRISTALES | 24,4 · 7×13 | 6 cristales grandes (3 rojos, 3 azules), 2 sueltos, 5 hexágonos, plantas brillantes |
| SANTUARIO | 10,1 · 11×5 | portal de runas, arco, 2 tótems, 2 rocas-tótem, **2 símbolos rupestres**, altar con velas y libros |

### 1.2 Puzles de cueva que ya existen en otros mapas
`Cueva.txt` y `CuevaResonante.txt` (casi iguales): braseros + contador, cristal resonante, vetas (con hueco para bloque de tierra), prisma,
receptores, geodas, columnas que tumba el pulso, columna-puente sobre lava, estalagmitas, pared hueca (ᚱ), estatuas, cerrojo con vigía,
cofres épico y legendario. `CuevaAgua.txt`: emisores, nexo y tótem (rayo: fuera de la demo).

### 1.3 Piezas del pack con sentido de puzle
| Pieza del pack | Qué puede ser | Pieza de puzle que la hace funcionar |
|---|---|---|
| `dynamite_a/b`, `blastingmachine`, `bomb`, `barrel_*` | carga de voladura | `barril` (explota y rompe `muro`) |
| `entrance`, `minearch`, `tunnel` | bocamina tapiada | `muro` agrietado delante |
| `trolley_*`, rieles | vagoneta pesada | decorado junto a `roca_empujable` (no hay pieza que se mueva por raíl: P6 sin hacer) |
| `crystal_red_*` / `crystal_blue_*` | fuego / agua | decorado que marca el elemento de cada `receptor` |
| `hex_*` | piedra que reparte | decorado sobre el `prisma` |
| `calca_glowingcrack_a` | grieta que suena hueca | junto a una `pared_hueca` (ᚱ) |
| `calca_symbol_a..d`, `totem_a`, `totemstone_b` | orden de los sellos | pistas de la secuencia de `estatuas` |
| `portalblocks`, `shrinearch` | puerta del santuario | `puerta` reja / cofre legendario |
| `brokenrail_*`, `woodenplank`, `rope_*`, `woodsupport` | puente de mina caído | borde del `precipicio` (letra « » dentro del mapa) |
| `stonecolumn_a/b` | columna que cae | `columna` (pulso) |
| `flatplatform`, `smallplatform_*` | plataformas de tablones | decorado junto a las placas |

Descartadas para puzle: el agua del pack (manda la del mundo), vegetación, atrezo menudo (libros, botellas, sillas).

---

## 2. Propuesta: seis puzles, uno o dos por sala

Coste: **A** = solo mapa con piezas que existen · **B** = una pieza o regla pequeña.

| Id | Sala | Puzle | Verbo | Sellos | Coste |
|---|---|---|---|---|---|
| LC1 | MINA | **La voladura** | llevar la explosión al muro | fuego | A |
| LC2 | MINA | **La balanza de la mina** (C7) | pesar con lo que hay | tierra + ᛜ, empuje | A |
| LC3 | CRUCE → SANTUARIO | **El puente caído** (T3) | tender tierra sobre el vacío | tierra + barrera + línea | A |
| LC4 | CRISTALES | **Rojo y azul** | elegir el elemento del pulso y llevarlo | fuego, agua, ᚱ, prisma | A |
| LC5 | CRUCE | **La grieta que suena** | descubrir la pared hueca | ᚱ | A |
| LC6 | SANTUARIO | **Los tres sellos** | secuencia de los tres elementos | fuego, agua, tierra + ᚱ | A |
| LC7 | CRUCE | **Sala del gólem** (cerrojo) | combate | gólem + 2 limos | A |

### LC1 · La voladura (MINA)
Al final de la vía, una galería hundida tapiada por un `muro golpes=3`. Sobre la curva de la vía hay un `barril`, con la dinamita, el
detonador y la bomba del pack al lado. Fuego al barril → explota y rompe el muro. Detrás, un `cofre` épico. (Montado: ver §4.)

### LC2 · La balanza de la mina (MINA)
La reja del fondo de la mina se abre con dos placas (`pulsador modo=presencia`): A pide `peso=3`, B pide `peso=1`. En la sala hay una roca
mediana (2) y una pequeña (1), junto a las vagonetas. Solución: las dos rocas a A y un bloque de tierra en B, que dura 25 s; la regla
`si=A.pulsado` evita que la tierra sola la abra. Detrás de la reja, la llave o el cofre.
*Comprobar al montar:* que la tierra se levanta sobre la casilla de la placa y que dos rocas suman en la misma casilla (si no, tres placas).

### LC3 · El puente caído (pasillo CRUCE → SANTUARIO)
El pasillo de 3 de ancho (columnas 14-16, filas 6-7) pasa a ser un **precipicio** de 2 de hondo (letra « » dentro del mapa:
`Precipicio3D` pone las paredes y el fondo negro). A los dos lados, restos del puente de la mina: `brokenrail`, `woodenplank`, `rope`.
Se cruza con el puente de tierra (barrera + líneas desde el borde). El santuario solo se alcanza así: es donde se **estrena la tierra**.

### LC4 · Rojo y azul (CRISTALES)
Un `cristal` resonante dormido (`cada=0`) en el centro. Dos `receptor`, uno `elemento=fuego` (con `crystal_red` alrededor) y otro
`elemento=agua` (con `crystal_blue`), cada uno al final de su `veta`. Entre el cristal y las vetas, un `prisma` que se gira con E. Se golpea el cristal con fuego, se gira el prisma hacia la veta roja; luego agua y la azul. Los dos activos → se abre una
reja con un `cofre` épico. Enseña que el pulso lleva el elemento del hechizo.

### LC5 · La grieta que suena (CRUCE)
La grieta azul brillante (`calca_glowingcrack_a`, ya está en 10,9) se pone sobre una `pared_hueca`: suena hueca con cualquier pulso y se abre
con el ᚱ de la jugadora. Detrás, un nicho con jarrones y un fragmento de savia (o lo que diga Pablo).

### LC6 · Los tres sellos (SANTUARIO)
Tres `estatuas` delante del portal, `secuencia=fuego,agua,tierra`. Los símbolos rupestres y los tótems del pack hacen de pista del orden
(uno por estatua, en la pared de detrás). Al completar se abre la reja del portal (`portalblocks`) y aparece el **cofre legendario**.
Es el cierre de la cueva y pide los tres sellos.

### LC7 · Sala del gólem (CRUCE)
`cerrojo` en las dos bocas laterales del cruce y `vigia` con 1 gólem y 2 limos. Mientras no caen, no se puede ir a MINA ni a CRISTALES. Usa
el reintento de COMBATE (G1) que ya existe.

**Orden de recorrido:** BOCA → CRUCE (LC7, LC5 opcional) → MINA (LC1, LC2) y CRISTALES (LC4) en el orden que quiera → puente (LC3) →
SANTUARIO (LC6).

---

## 3. Qué hace falta y qué no

- Todo es **coste A**: solo líneas `; pieza` y `; puzle` en `tools/mapa_lostcave.py` (que genera `LostCave.txt`) y, para LC3, el hueco « »
  en el dibujo del mapa.
- **No** se hace: la vagoneta que se mueve por raíl (necesita la plataforma móvil P6, sin hacer) ni piezas funcionales con el modelo del pack
  (el barril, el muro y las placas siguen con su modelo; el pack va al lado como decorado). Si Pablo quiere que el barril sea `lost_barrel`,
  es un cambio pequeño en `puzle.gd` (como `brasero modelo=cueva`).
- Prueba: `herramientas/escenario_lostcave_puzles.gd` resuelve cada puzle en el juego, como `escenario_catalogo_puzles`.

---

## 4. Lo montado (24/11) y lo que cambió de la propuesta

| Id | Casillas | Cómo se resuelve en la prueba | Cambio respecto a §2 |
|---|---|---|---|
| LC7 | cerrojo en (15,16), (7,11) y (23,10..12); sala 8,8..22,14; gólem (15,9), limos (11,11) y (19,11) | se entra, se cierran las bocas; muertos los tres (**por código**: no se prueba el combate), se abren | — |
| LC5 | veta (12,13..12,14) → pared hueca (12,15) → nicho (11..12,16), cofre épico | fuego + ᚱ sobre la veta | **Lleva una veta:** el pulso de la jugadora solo corre por lo que conduce. La grieta del pack no se repite junto a la pared (caía sobre un muro). |
| LC1 | barril (3,16), muro (3,17) golpes=3, galería 2..5,18..20, cofre épico (3,20) | flecha de fuego al barril | **El barril va pegado al muro, sobre la vía** (radio 2,6 u: en diagonal no llegaba). Solo con fuego: el barril tapa el único acceso al muro. |
| LC2 | placas (4,7) peso 2, (2,7) peso 1, (6,6) peso 1; rocas mediana (4,9) y pequeña (2,9); reja (2,3), cofre épico (2,1) | dos empujones al norte por roca (con `empujar`, lo que dispara el empuje andando) y tierra + barrera en (6,6) | La reja no guarda flag (`abierto=` solo vale con llave). Sin intercambio de rocas: cada roca ya está en línea con su placa. |
| LC4 | cristal dormido (27,11), veta (28,11), prisma (29,11) mirando al oeste, vetas (29,9..10) y (29,12..13), receptores fuego (29,8) y agua (29,14), cofre épico (30,4) | fuego al cristal sin girar (no pasa nada); 1 giro + fuego; 2 giros + agua; aparece el cofre | El hexágono encima del prisma no se pone (nada de decorado sobre piezas de puzle). Cristales rojos al norte y azules al sur. |
| LC3 | precipicio (14..16, 6..7); el arco del santuario pasa de (15,6) a (15,5); vía rota asomando en (15,8) | tierra + barrera + 2 líneas desde (15,9) apuntando a (15,8); se cruza andando a (15,4) | — |
| LC6 | estatuas (13,3) (15,3) (17,3), cofre legendario (15,2); la mesa va a (17,1) y dos velas a (12,3) y (18,3) | fuego + ᚱ, agua + ᚱ, tierra + ᚱ + flecha | Estatuas en la fila 3 (en la 4 tapaban la salida del arco). |

**Recompensas:** un fragmento de savia en cada épico de LC1, LC4 y LC5 (tres = una savia entera); LC2 da oro y una poción; el legendario
(LC6) da 60 de oro y un núcleo de eco. **A decidir por Pablo:** si el legendario da un glifo o un sello (hoy no, para no adelantar la
progresión de los glifos sin mazmorra).

**Kit:** `PruebaLostCave.tscn` pasa de `pruebas` a `demo` (fuego, agua y tierra; flecha, línea, barrera, altura, ᚱ y suelo). Con
`pruebas` no había ᚱ y LC5 y LC6 no se podían hacer.

**Otras pruebas tocadas:** `captura_lostcave_nivel.gd` comprobaba que se llega andando a las cinco salas; ahora comprueba que al
SANTUARIO **no** se llega andando (el precipicio). 0 fallos.

**Sin probar:** jugarlo con teclado y ratón; el combate real contra el gólem; que una jugadora entienda sin texto que la placa (6,6)
pide tierra y que el prisma se gira con E.
