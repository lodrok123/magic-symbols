# Plan · Bosque v02 «El corazón del Bosque» (3/11/2026) — lo que hay construido

Encargo de Pablo (3/11): «Mapa grande al menos 30×30 con muros lejanos. Guiado sutil (los caminos guían por los puntos de interés). Cofres comunes, al menos 5, como recompensa de actividades (puzles, enemigos…). Cofres épicos por misiones distintas (destruir un campamento, por ejemplo). Cofre legendario al acabar la demo. Usar todo lo que hay en temática bosque y todo lo reactivo. Libertad para ejecutarlo. Revisar y testear que el nivel sea resoluble del principio al final.»

Este documento describe **lo que hay** (el plan de partida se reescribió al construir el nivel; los cambios respecto a él van en el apartado 9).

Decisión de ejecución: el Bosque v01 (52×44, `Bosque_01_v01`) se conserva tal cual (sus pruebas siguen valiendo). `Bosque_02` es un nivel nuevo y pasa a ser `Niveles.NIVEL_INICIAL`; las salidas `a_bosque` de la Cueva, la Cueva Resonante y las Grutas (Batida y Permanencia) apuntan a `Bosque_02:boca_cueva`.

| Qué | Dónde |
|---|---|
| Mapa y todas las líneas `; zona` / `; pieza` / `; puzle` / `; nombre` / `; marcador` / `; decorado` | `mundo/datos_nivel/mapas/Bosque_02.txt` |
| Nivel horneado | `mundo/datos_nivel/Nivel_Bosque_02.tscn` (`herramientas/hornear_bosque_02.gd`, sin el paso de «retoques» del v01) |
| Escena | `escenas/PruebaBosque02.tscn` (raíz `prueba_test2.gd`, `nivel = "Bosque_02"`, `arqueros`, `kit = "pruebas"`, `zona_luz = "bosque"`, `agua_fisica`, hijos `Reglas` y `Puzles`) |
| Reglas (misión, tótems, NPC, fin de demo) | `escenas/bosque_02_3d.gd` |
| Prueba de resolubilidad a pie | `herramientas/prueba_bosque_02_recorrido.gd` |
| Escenario (zonas y viaje de ida y vuelta a la Cueva) | `herramientas/escenario_bosque_02.gd` |
| Capturas (con ventana) | `herramientas/captura_bosque_02.gd` → `docs/capturas/bosque_02/` |

## 1. Mapa: 40 × 40, anillo de bosque de 4 casillas

- `lado` = 40 (x 0..39, y 0..39). **Muros lejanos:** las 4 filas y columnas exteriores son `#` (árboles, pinos y rocas grandes que la maqueta pone en toda casilla `#`), de modo que la cámara ortogonal nunca enseña el vacío. El **área jugable es x 4..35, y 4..35 (32 × 32 ≥ 30 × 30)**; la prueba afirma que el anillo es todo `#` y que ninguna pieza ni marcador cae fuera.
- Dentro, el bosque se compone con `#` en grupos (nunca rectas largas): claros unidos por **caminos `g`** de una casilla de ancho (el guiado). Hierba alta `v` solo en la pradera (con un cortafuegos de 2 casillas junto a la empalizada, porque la puerta goblin arde). `,` hierba corta decorativa en manchas (repartida con el mismo ruido que `; azar_suelo`, pero sin tierra para no confundir el camino).
- Las zonas (`; zona …`) ponen luz, tiempo de mezcla (5 s los exteriores, 1 s las salas), rótulo la primera vez y la tabla de botín de los jarrones.

```
    0000000000111111111122222222223333333333
    0123456789012345678901234567890123456789
 4  ##############~~########################
 5  #####RRRR#RRLu~~RR#k#R##ggggggggg-######
 6  #####RRRR#RR-R~~RR#R#rj#g.~~~~,.,-######
 7  #######R##cccR~~RRRRRRr#ge~~~~...-######
 8  #####RDRRRcccR~~RRRRRTRgg.~~~~,..-######
 9  ####,RRRRRRRRR~~RRRRRRR#g,.,,,...-######
10  ####,RRRRKRRRR~~RecRciR#ggggggggg-######
11  #####RRRRRMRRR~~######,#################
12  ########R#####~~vvvvvvgvfv..x..,,,,,####
13  #####RRRRRRR##~~v#vvv#gvvv..x,t.t,o,####
14  #####RRRRRRR##~~#vvWvvgvvA,,x,.W.W,,####
15  #####RRRRRRR##~~vsvvvTgvvv,,x,,.F,,,####
16  #####RRRGRRR##~~vvggggggggggygggggg.####
17  #####RRRRRRR##~~vvgv#vvv##..x,,,,,A.####
18  #####RRRRRRR##~~vvgvvvvv#v.,x,,tAV..####
19  #####RRRRRRR##~~vvgvqvvvWv,,x,o.....####
20  ##############~~vvgvvvvvvv#,############
21  #######....###~~vvgvvvvvvv,,############
22  ######,,..,###~~#,g,##########.#.##,####
23  ######r,..r###~~#,g,##########,..,,,####
24  ######,,..,###~~#,gggglgggzzgggggggU####
25  ######.,,,####~~#.g.##########,..,,,####
26  ########g#####~~#.g.##########,##,,,####
27  ########g#####~~#.gT##########.,..######
28  ####,...g..,,,~~,,g,,,########......####
29  ####..s...,,h,~~r,g,##....,,.,##########
30  ####.....,T,,,~~..g,,...,s,.s.##########
31  ####h..,,m,.g,~~ggggggggggghg,##########
32  ####...Sggggg.~~..........,,g,##########
33  ####.s......,,~~,,,,.#,h,,s.,.##########
34  ####...#..T.s,~~r,,,,#,,,,,,############
35  ####.........,~~,,,,,,##################
```

Leyenda: `#` árbol/roca · `~` agua (arroyo x 14..15 y el lago del estanque) · `R` piedra (ruinas y santuario) · `g` camino · `,` hierba corta · `v` hierba alta · `c` cauce de piedra (cuencas y pozos) · `-`/`L` canal · `S` jugadora · `m` guardabosques · `M` librera · `W` `A` goblins guerrero y arquero · `G` elemental · `T` brasero · `F` fogata · `z` seto · `l` tronco · `r` telaraña · `j` `k` `i` tótems de fuego, agua y rayo · `u` tinaja · `e` fuente eléctrica · `K` placa de peso · `D` muñeco · `s` `f` `q` seta, flor y raíz reactivas · `h` setas decorativas · `y` puerta goblin · `o` torre goblin · `t` tienda · `x` empalizada · `V` estandarte · `U` arco de la boca de la Cueva.

El **arroyo** `~` corre de norte a sur por x = 14..15 (y 4..35) y parte el mapa en oeste (linde, escondite, plaza de las ruinas y santuario) y este (orilla, claro de las setas, pasillo y boca de la Cueva, pradera, campamento, ruinas del este y estanque). Se cruza **por el tronco-puente** de la linde (fuego) o, más al norte, **por el puente roto** (14..15, 9), que tiende el agua o la cuerda quemada. (Helar el agua también vale, con el reloj de 20 s de C2; no hace falta para resolver el nivel.)

## 2. Puntos de interés (coordenadas finales)

1. **La linde (inicio)** · x 4..13, y 28..35 · S en (7,32). Guardabosques `m` (9,31). **Dos braseros** apagados (10,30) y (10,34) con un `contador` (11,30): con 2/2 se pone `bosque02.linde.braseros` y aparece el **cofre común 1** (11,33). Setas `s` ×3, setas `h` ×2, jarrones ×4 y cajas ×2 (botín `bosque`). El **tronco-puente** (marcador, base (13,31), cae hacia el este) cruza el arroyo hasta (16,31).
2. **El escondite** · x 6..10, y 21..27 · el **muro agrietado** (8,27) (2 golpes de tierra) tapa el corredor (8,26); detrás, el **cofre común 7** (8,22), un jarrón y dos telarañas (6,23)/(10,23) (el hielo las vuelve seda).
3. **La orilla este y el claro de las setas** · x 16..21 / 22..29, y 28..35 · al pisar la orilla se pone `bosque02.arroyo.cruzado` y aparece el **cofre común 2** (19,33). Telarañas (16,29) y (16,34); brasero-guía (19,27); 3 setas recogibles (`seta`), 3 `s`, 2 `h`, jarrones. Sube un camino de dos casillas hasta la pradera.
4. **El pasillo de la Cueva y la boca** · pasillo y=24 (x 19..34) cerrado por el **tronco** (22,24) y los **dos setos** (26,24)/(27,24) (fuego; los setos se contagian). La boca: salida a `Cueva:desde_bosque` en (34,24)+(35,24) (el arco `U` de (35,24) es decorado que bloquea su casilla; por eso la salida ocupa también (34,24)), entrada `boca_cueva` en (33,24) mirando al oeste. Jarrones. La zona se llama «La boca de la cueva».
5. **La pradera alta** · x 16..27, y 12..21 · hierba alta `v`. Goblins: guerreros (19,14), (24,19); arquero (25,14); lobernos (17,19), (26,20) (marcadores). Colmena (21,12), colgada de un árbol (viento = panal, fuego = nube de veneno); nido (26,12) (viento = pluma); seta (17,15), flor (24,12), raíz (20,19); brasero-guía (21,15). El vigía `vig_pradera` (los 5) pone `bosque02.pradera.limpia` y aparece el **cofre común 3** (21,20). Dos ramas: norte (hueco (22,11) a las ruinas) y este (puerta goblin (28,16)).
6. **Las ruinas del este** · x 16..22, y 5..10 (suelo `R`):
   - **Tótem de fuego** `j` (22,6) tras una telaraña (22,7) (y otra (21,6)): fuego a la telaraña desde (22,9) y luego al tótem desde (22,8).
   - **Tótem de agua** `k` (19,5) en un nicho cuya **reja** (19,7) abre la cuenca de la plaza oeste: agua a la **tinaja** (13,5) (se dispara desde (16,5), al otro lado del arroyo, con dos flechas = 3 casillas), la tinaja vierte por el canal `L`/`-` ((12,5), (12,6)) a la cuenca `c` (10..12, 7..8) y cuando el nivel de (11,8) llega a 0,45 se pone `bosque02.ruinas.reja` y la reja se abre. Tarda de 45 a 100 s de reloj de juego.
   - **Tótem de rayo** `i` (21,10): fuente eléctrica (17,10) – pozo (18,10) – **nexo** (19,10) – pozo (20,10). Con el nexo seco la corriente se corta; una flecha de agua al nexo (desde (19,8)) lo moja y la siguiente descarga (cada ~5,6 s) despierta el tótem.
   - Con los tres se pone `bosque02.ruinas.totems` (la «llave» de la sala del tesoro). Muñeco `D` (6,8), brasero-guía (21,8), **asesino** (marcador, 20,8). El **pulsador de agua** (17,9) y la **cuerda** (16,8) tienden el **puente roto** (14..15, 9) (agua al pulsador desde (19,9), o fuego a la cuerda).
7. **La plaza oeste (ruinas)** · x 5..13, y 5..11 · la **sala del tesoro** (interior 5..8, 5..6) con su puerta de llave (7,7) y el **cofre común 6** (6,5). El **bloque** (5,10) se empuja desde (4,10) (se entra por (4,9)) por la pista y=10 hasta la **placa K** (9,10) (reactivo de peso): aparece el **cofre épico 3** (11,10). La librera `M` (10,11). Estatuas y pilares de adorno. Al sur, la puerta del santuario (8,12).
8. **El estanque del molino** · x 24..33, y 5..10 · lago `~` (26..29, 6..8) con la **fuente eléctrica** (25,7); **canal x = 33** (y 5..10): manantial (33,5) apagado → compuerta (33,6) → molino (33,8) → desagüe (33,10). El **pulsador de agua** (31,8) abre la compuerta (aparece el **cofre común 4** (32,5)); cuando la rueda gira (`bosque02.estanque.molino`) aparece el **cofre épico 2** (27,9), **sellado** hasta que el lago está electrificado (`casilla(27,8).electrificada`, el reloj de 2 s de C2: la fuente descarga cada ~5,6 s). Alga (28,7) recogible solo con la casilla helada.
9. **El campamento goblin** · x 28..35, y 12..19 · empalizada `x` (x = 28) con la **puerta goblin** `y` (28,16) (fuego); el **cerrojo** (29,16) se cierra al pisar la sala (30..35, 12..19) y se abre cuando el vigía `vig_camp` (5: dos guerreros, dos arqueros —uno de puesto, (34,17)— y el **chamán** (32,14)) lo da por limpio. Tiendas, estandarte, cazo y rocas de adorno, **fogata** (32,15), barriles (31,17), (35,15), torres `o` (34,13) y (30,19). **Cofre épico 1** (34,16) (da la llave del santuario). **Cofre común 5** (35,13) aparece al consumirse la torre este.
10. **El santuario** · x 5..11, y 13..19 (puerta (8,12) de llave, cerrojo (8,13), sala 5..11 × 14..19) · el **elemental** `G` (8,16), un guardián de barrera dormido (5,16) (marca (7,15) y (9,15)) y adornos. **Cofre legendario** (8,18) tras vencerlo: **fin de la demo**.

## 3. Cofres (11)

| id | casilla | calidad | aparece / se abre cuando | contenido |
|---|---|---|---|---|
| `cofre_linde` | (11,33) | común | aparece al arder los 2 braseros de la linde (fuego) | `tabla:cofre_pequeno` |
| `cofre_orilla` | (19,33) | común | aparece al cruzar el arroyo (pisar la orilla este) | `tabla:cofre_pequeno` |
| `cofre_pradera` | (21,20) | común | aparece al caer los 5 enemigos de la pradera (vigía) | 30 de oro + 1 poción |
| `cofre_molino` | (32,5) | común | aparece al abrir la compuerta del molino (agua al pulsador) | `tabla:cofre_pequeno` |
| `cofre_torre` | (35,13) | común | aparece al consumirse la torre este (fuego) | `tabla:cofre_pequeno` |
| `cofre_ruinas` | (6,5) | común | siempre visible; la puerta (7,7) pide los 3 tótems | 40 de oro + 2 setas asadas |
| `cofre_escondite` | (8,22) | común | siempre visible; el muro (8,27) lo tapa (tierra ×2) | 50 de oro + 1 poción |
| `cofre_campamento` | (34,16) | **épico** | aparece al caer el campamento (vigía) | capucha de musgo · pone `bosque02.santuario.llave` |
| `cofre_estanque` | (27,9) | **épico** | aparece al girar la rueda; sellado salvo con el lago electrificado | capa de escarcha |
| `cofre_trastienda` | (11,10) | **épico** | aparece al pesar el bloque sobre la placa K | túnica de salamandra |
| `cofre_corazon` | (8,18) | **legendario** | aparece al caer el elemental (vigía) | glifo ᛜ barrera + 150 de oro + 2 pociones grandes · fin de la demo |

Las flags de apertura son `bosque02.<sala>.cofre` (`linde`, `orilla`, `pradera`, `molino`, `torre`, `ruinas`, `escondite`, `campamento`, `estanque`, `trastienda`, `santuario`).

La mochila tiene 8 huecos y el botín del camino (carbón, panal, pluma, colmillos, setas, pociones) la llena deprisa: con la mochila llena el cofre avisa «la mochila está llena: lo demás se queda aquí». La prueba de recorrido hace sitio antes de cada cofre, igual que lo haría la jugadora. (Si molesta, se sube la capacidad con el alquimista o se da un hueco libre al entrar.)

## 4. Guiado sutil

- Los caminos `g` salen de la linde (junto a S), llegan al tronco y, al otro lado, suben por la orilla este a la pradera; allí se bifurcan: norte (hueco (22,11) a las ruinas y, por el puente, a la plaza y el santuario), este (campamento) y, desde la orilla, el pasillo a la boca de la Cueva. Sin flechas salvo la de misión.
- **Braseros-guía encendidos de serie** en los cruces ((19,27) camino norte, (21,15) cruce de la pradera, (21,8) ruinas): su luz es la señal «por aquí»; los braseros de la linde (10,30), (10,34) nacen apagados porque encenderlos es la actividad.
- **Rótulos de zona** la primera vez (`titulo=`), **carteles** de adorno en las bifurcaciones y diálogos: la guardabosques (linde) da cinco pistas (braseros, tronco, muro, pradera, campamento) y la librera (plaza) otras cinco (los tres tótems, la reja y la tinaja, la fuente y el nexo, la llave, la piedra y la placa).
- La **flecha de la misión** (`Misiones.fijar_punto`) solo apunta al objetivo ACTIVO de la principal (el primero que queda por hacer), no a todos.

## 5. Misiones (código en `bosque_02_3d.gd`, flags → `objetivo_hecho`)

Principal **«El corazón del Bosque»** (recompensa 100 de oro), 7 objetivos: 1 enciende los dos braseros de la linde (n/2) · 2 cruza el arroyo · 3 limpia la pradera · 4 despierta los tres tótems y abre su sala (n/3) · 5 destruye el campamento (llave del santuario) · 6 vence al elemental · 7 abre el cofre del corazón.

Secundarias (todas activas desde el principio): **«Destruir el campamento»** (derrotar al campamento; abrir el cofre épico) · **«La corriente del molino»** (compuerta; rueda; cofre épico con el lago electrificado) · **«El peso de la piedra»** (bloque sobre la placa; cofre épico de la trastienda) · **«Siete cofres»** (los siete comunes, n/7).

Fin de la demo: al abrirse el cofre legendario (`bosque02.santuario.cofre`) el script pone `_terminado`, emite el logro `nivel_completado` (rótulo «¡Nivel completado!»), enseña «Fin de la demo. Gracias por jugar el Bosque.» y a los 10 s **autoguarda y vuelve al menú principal** (`Partida.autoguardar` + `change_scene_to_file(MenuPausa.RUTA_MENU_PRINCIPAL)`, lo mismo que «Salir al menú principal» del menú de pausa). Las pruebas ponen `reglas.volver_al_menu = false` (y la de recorrido lo vuelve a poner a `true` justo antes del cofre legendario para comprobar la vuelta al menú).

## 6. Reactivos usados (lista de comprobación y casilla)

seto `z` (26,24), (27,24) · tronco `l` (22,24) · telaraña `r` (22,7), (21,6), (16,29), (16,34), (6,23), (10,23) · puerta goblin `y` (28,16) · torre `o` (34,13), (30,19) · fogata `F` (32,15) · brasero `T` (10,30), (10,34) y guías (19,27), (21,15), (21,8) · tótems `j` (22,6), `k` (19,5), `i` (21,10) · seta `s` (6,29), (5,33), (12,34), (17,15), (25,30), (26,33), (28,30) · flor `f` (24,12) · raíz `q` (20,19) · fuente eléctrica `e` (17,10), (25,7) · tinaja `u` (13,5) · placa `K` (9,10) · muñeco `D` (6,8) · **puente reactivo** (pieza `puente` (14..15,9)) con **cuerda** (16,8) y **pulsador de agua** (17,9) · pulsador de agua (31,8) · compuerta (33,6) · nivel (11,8) · molino (33,8) · nexo (19,10) · cuencas/manantial/desagüe · contador (11,30) · colmena (21,12) · nido (26,12) · barriles (31,17), (35,15) · bloque (5,10) · muro agrietado (8,27) · guardián de barrera (5,16) · setas recogibles `seta` ×3 (24,30), (26,32), (28,33) y alga (28,7) · jarrones y cajas (botín por zona) · tronco-puente (marcador 13,31) · lobernos (17,19), (26,20) · asesino (20,8) · chamán (32,14) · elemental `G` (8,16) · puertas con llave (7,7) y (8,12), reja (19,7), cerrojos (29,16) y (8,13).

**Quedan fuera, y por qué:** el **tronco del estanque** (`TroncoEstanque3D`: pide un cauce hondo que se llene y rodear el nivel de más agua; el Bosque 01 v01 ya lo prueba) · las **baldosas `p` `a` `w`** (su lógica vive en `Jugabilidad3D`/`Bosque3D` —`registrar_losa`—, que este nivel no carga; sus papeles los hacen el pulsador de agua y la placa de peso) · la **barrera de fuego `B`** (es un muro que bloquea el paso; aquí hay un `guardian` dormido) · enredaderas, limo y gólem (no estaban en la lista) · lava y cristales de pulso (cosas de la Cueva, según el plan) · hierba alta junto a la empalizada (el plan la pedía en «el borde del campamento»; queda un cortafuegos de 2 casillas porque la puerta goblin arde y la hierba prendería la pradera entera).

## 7. Pruebas

**`herramientas/prueba_bosque_02_recorrido.gd`** (resolubilidad «a pie»). Carga `PruebaBosque02.tscn` de verdad (con el `.tscn` horneado) y recorre la misión principal EN ORDEN y lo opcional, **sin teletransportes**:

- Para cada tramo hay un **BFS sobre `Terreno3D.pisable`** desde la casilla actual de la jugadora hasta el objetivo: si no hay camino con lo abierto hasta ese momento, falla; si lo hay, se la lleva por él **casilla a casilla** (0,1 s por casilla, ningún salto de más de una casilla).
- Cada acción es el **mecanismo real**: hechizo lanzado con `Lanzador3D.lanzar_pagina_ya` desde la casilla donde está la jugadora (con el alcance de la flecha: una flecha llega a 2 casillas, dos a 3), cofre abierto con la acción `abrir` de Puzle3D (= pulsar E a su lado), piedra con `BloqueEmpujable3D.empujar`, puertas tocadas acercándose 0,8 u.
- En cada cierre afirma **«cerrado antes / abierto después»**: el camino (o el cofre) NO existe antes y SÍ después (tronco, muro, pasillo de la Cueva, telaraña del tótem, reja, nexo, puente roto, puerta de las ruinas, bloque y placa, compuerta, lago sellado/electrificado, puerta goblin, cerrojo del campamento, torre, puerta del santuario, cerrojo del santuario).
- Al final: flag `bosque02.santuario.cofre`, logro `nivel_completado` (+1), **7 comunes, 3 épicos y 1 legendario** abiertos (todos alcanzados a pie), las 11 flags, la misión principal y las cuatro secundarias completas, vuelta al menú principal a los 10 s, el anillo todo `#` y ninguna pieza/marcador fuera del área.
- **Lo único no real:** un guerrero de la pradera cae a hechizos de verdad (tierra, agua y rayo), pero los demás goblins, el asesino y el elemental se dan por derrotados con `Combate3D.muerto = true` (marcado `[muerto=true]`): la prueba comprueba que el vigía, el cerrojo y el cofre reaccionan. Para la colmena y el nido la flecha de viento no llega en headless (igual que en `escenario_botin`), así que se avisa (`AVISO`) y se aplica el contrato `on_spell_hit` directo. La vida de la jugadora se mantiene alta y, como la mochila tiene 8 huecos, antes de abrir cada cofre tira lo que no necesita.

**`herramientas/escenario_bosque_02.gd`**: las 10 zonas (luz, mezcla, nombre, rótulo una vez) y el viaje de ida y vuelta Bosque 02 → Cueva → Bosque 02 con lo resuelto conservado (flags, cofre abierto, tronco-puente, pasillo quemado, telaraña, tótem de fuego, braseros-guía, misión).

**Pruebas adaptadas** (apuntaban al v01 como destino de la Cueva o como nivel inicial): `prueba_mapa_abierto` (destino y tabla de niveles), `escenario_cueva_completa` (la salida de C1 lleva ahora al Bosque 02, a (33,24)), `prueba_partida_menu` (el nivel inicial es `PruebaBosque02.tscn`) y `escenario_bosque_01_v01` (la salida de la Cueva se redirige a mano al v01 para seguir probando que conserva su estado).

## 8. Entregables

Mapa, horneado, escena, reglas, misiones, `Niveles.ESCENAS` + `NIVEL_INICIAL`, salidas de la Cueva/Gruta al v02, prueba de recorrido con 0 fallos, escenario, capturas, pruebas viejas adaptadas, este documento y la entrada 345 del diario.

## 9. Qué cambió al construirlo respecto al plan de partida

- **Puente roto**: el plan lo ponía en (14..15, 24..25) con una baldosa de agua `a`. Las baldosas no tienen lógica en este nivel, así que es una pieza `puente` en (14..15, 9) con un **pulsador de agua** y una **cuerda**; el cruce principal del sur es el **tronco-puente**. El arroyo ya no tiene un puente fijo `b` en y = 8.
- **Fogata de la linde → dos braseros**: la letra `F` nace encendida y el cofre de la linde pedía encenderla; ahora son los dos braseros `T` (que nacen apagados) con un contador. La fogata `F` está en el campamento.
- **Cofre de la orilla**: no hay hielo cronometrado que lo abra; aparece al pisar la orilla este (cruzar con el tronco, el puente o el hielo vale igual).
- **Estanque**: el plan pedía rayo + nexo + cuerda + tronco; quedó como compuerta + molino (agua al pulsador) y lago electrificado por la fuente (cofre épico sellado), copiando los puzles de agua probados (Q7 y Q9 de `PuzlesAgua`). El nexo y la cadena eléctrica están en las ruinas (tótem de rayo).
- **Ruinas**: la puerta de las ruinas es una pieza `puerta` con `llave=bosque02.ruinas.totems` (no la letra `X`, que es de las reglas del v01); los tótems `j` `k` `i` los despierta el script (flag por tótem). El tótem de agua se protege con una reja que abre la cuenca de la tinaja (módulo Q1 de `PuzlesAgua`). La cuenca y la cadena eléctrica están lejos del arroyo: el agua del río se metía en el cauce y la fuente electrificaba el río entero (lección aprendida con la prueba).
- **Boca de la Cueva**: la salida es la casilla (34,24)+(35,24) y la entrada (33,24), porque el arco `U` de (35,24) bloquea su casilla y no se podría llegar a ella a pie (y un arco en el hueco (22,11) cortaba el paso: se quitó). Es `modo=pisar` como en el v01.
- **Escondite**: pasó de «bosque denso SE» a un cuarto oculto al norte de la linde (muro agrietado); el SE tiene el claro de las setas y la boca de la Cueva.
- **Santuario**: sin barrera `B`; guardián dormido más cerrojo de sala.
- **Cofre legendario**: da el glifo ᛜ (barrera) como en el v01, además de oro y pociones grandes.
- **Coordenadas**: el campamento ocupa x 28..35 (el plan decía 26..35), la pradera x 16..27 y las ruinas se partieron en este (tótems y estanque) y oeste (sala del tesoro, bloque y santuario). El bloque se empuja desde (4,10), al que se llega por (4,9) (con el muñeco y un jarrón puestos mal la pista quedaba sellada: lo cazó la prueba).

## 10. Cosas que se ven y no son de este nivel

- El **cerrojo** de sala (`CerrojoPuzle`, del Bosque 01 v01 también) deja su losa hundida con unos centímetros por encima del suelo: en el campamento se ve como un rectángulo pardo en (29,16) cuando está abierto. Es de `escenas/puzle.gd`; no se ha tocado.
- Al montar el guardián de barrera sale un aviso `sin pieza losa_runas_ovalo` en la maqueta (ya salía en la Gruta Batida): la prueba lo ignora a propósito.
- La guardabosques usa el GLB `ranger_human`, que solo trae `Idle` y `Stand_Talking`: avisa de que le falta el clip `walk` (no anda, solo habla).
