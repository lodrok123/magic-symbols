# Catálogo de puzles del generador: revisión y ampliación (26/11/2026)

Encargo de Pablo: «quiero que los puzles sean variados (tenemos muy pocos); revisa lo que hay y lo que se revisó de Mages of Mystralia; si hubiera alguno más que pudiéramos meter, hazlo». 
Demo = SOLO fuego, agua y tierra, con los glifos flecha, línea, barrera, altura, ᚱ (raido) y suelo.

**Resumen.** Había 28 plantillas (27 se resuelven con los sellos de la demo; `charca_helada` pide hielo). Ahora hay **41**: 13 nuevas más las 5 de agua de la rama fusionada, que no llevaban `; necesita` ni `; validacion` y ya las llevan. Las 13 nuevas se colocan con el generador sin avisos, cargan sin errores y **se resuelven de verdad con hechizos reales** (`herramientas/comprobar_puzles_agua.gd`, que ahora vale para cualquier puzle, no solo los de agua); cada una lleva además pruebas «nada» que demuestran que no se resuelven solas ni con el gesto equivocado. Los niveles de playtest nuevos son `PtFuego2`, `PtAgua2` y `PtTierra2` (18 puzles).

## 1. Revisión de lo que había

Las 28 plantillas, agrupadas por la mecánica que de verdad enseñan (contando como UNA las que usan la misma idea):

| Idea | Plantillas | Comentario |
|---|---|---|
| Encender todos los braseros | `braseros_premio`, `braseros_puerta` | Misma idea (una da cofre, otra una señal). El fuego que enciende cosas ya sobra en los niveles (PUZLES_DEMO §2). |
| Relé de braseros | `rele_braseros` | El único con tiempo, pero encima de braseros. |
| Mecha de setos y barril | `contrafuego` | |
| Barril contra el muro agrietado / el muro de agua | `barril_muro`, `presa_barril` | Dos usos de la explosión. |
| Pulso por la veta | `cristal_receptor`, `veta_dos_caminos`, `prisma_rojo_azul`, `pared_hueca_nicho`, `estatuas_sellos` | Cinco plantillas, todas de la Cueva: son lo más variado, pero piden ᚱ o un cristal. |
| Muro agrietado a golpes | `escondite_muro` | El único puzle «de tierra a golpes». |
| Empujar a la placa | `piedra_pista`, `piedra_premio` | **Casi iguales** (la segunda solo cambia la salida por un cofre). |
| Vagonetas | `vagoneta_pista`, `vagoneta_curva`, `vagoneta_boton`, `vagoneta_aguja` | **Cuatro** de una misma pieza. La pista y la curva son «empujar una vagoneta» con distinta vía; el botón y la aguja son mecanismos de verdad. |
| Bloque de hielo resbalando | `hielo_pista` | |
| Balanza de pesos | `balanza_rocas` | |
| Puentes y cruces de agua | `puente_cuerda`, `puente_aliviadero`, `puente_raices`, `rio_lava`, `charca_helada` (hielo) | Cuatro formas de cruzar agua, pero casi todas con fuego o agua a un punto. |
| Agua con nivel, balsa y molino | `cofre_balsa`, `molino_paso_bajo`, `riega_pulsador` | `riega_pulsador` es el más sencillo del catálogo (un golpe de agua a una placa). |

**Huecos** (ver tabla de cobertura): casi todo era fuego (encender, quemar, explotar); **tierra** solo tenía cuatro puzles propios y ninguno enseñaba proteger, retener agua ni pesar a distancia; **agua** tenía tres propios y ninguno con la línea ᛁ, la lava con peso ni el tiempo; no había **ni una sola trampa de pared** en el catálogo (dragones, mascarones, gotera), ni **veneno**, ni **mural/orden** de braseros, ni **choque térmico**. Los glifos de la demo ᛁ línea y ᛜ barrera (para proteger) casi no se usaban; **altura y suelo (ᛒ) siguen sin ningún puzle** (ver §6).

**Repeticiones a vigilar:** cuatro vagonetas, dos de piedra a la placa, dos de braseros-todos. Cuentan como una idea cada grupo; no las he tocado.

## 2. Tabla de cobertura, antes y después

«Antes» = las 28 que había (27 resolubles con la demo). «Después» = las 41 de ahora (40 resolubles con la demo). Un puzle cuenta en la fila de su combinación de sellos.

### Por sello

| Sello | Antes | Después |
|---|---:|---:|
| Solo fuego | 7 | 10 |
| Solo agua | 3 | 6 |
| Solo tierra | 4 | 6 |
| Combina dos o tres sellos | 3 | 6 |
| Alternativa (uno u otro) | 2 | 3 |
| Cualquiera de los tres | 4 | 5 |
| Ninguno (se resuelve empujando) | 4 | 4 |
| **Total (demo)** | **27** | **40** |

Sellos tocados en total (un puzle que pide dos cuenta en los dos; «cualquiera» y las alternativas no cuentan): 

| | Fuego | Agua | Tierra |
|---|---:|---:|---:|
| Antes | 10 | 7 | 6 |
| Después | 16 | 13 | 9 |

### Por tipo

| Tipo | Antes | Después |
|---|---:|---:|
| premio | 13 | 26 |
| paso | 5 | 5 |
| salida | 10 | 10 |

Todas las nuevas son **premio** (un cofre, a la vista o que aparece). Las `salida` (que enlazan una puerta o un puente) son pocas y siguen siendo en su mayoría braseros, placas y vagonetas; queda como mejora convertir en `salida` las nuevas que valgan (cada una ya tiene la señal: `cofre.aparecido`, `muro.roto`, etc.).

### Por verbo (lo que hace la jugadora)

| Verbo | Antes | Después |
|---|---:|---:|
| encender | 3 | 4 |
| apagar | 0 | 2 |
| empujar | 6 | 7 |
| pesar | 4 | 6 |
| romper | 3 | 5 |
| regar | 1 | 2 |
| llenar / vaciar / retener | 4 | 7 |
| cruzar | 5 | 8 |
| secuencia / orden | 1 | 2 |
| pulso | 5 | 6 |
| tiempo (cuenta atrás, ritmo) | 2 | 5 |
| construir terreno (bloque de tierra) | 4 | 6 |
| protegerse / cortar un peligro | 0 | 4 |
| transformar un estado (calentar, enfriar, derretir) | 1 | 4 |
| revelar una pista | 0 | 1 |
| mecanismo (aguja, vagoneta) | 4 | 4 |
| cooperar dos a la vez | 0 | 1 |

Verbos que **no existían** y ahora sí: apagar una trampa (dragón, gotera), proteger construyendo (escudo de tierra), retener agua (presa en seco), pesar a distancia (placa en una isla), transformar un estado (choque térmico, lava enfriada), revelar una pista (mural), orden de braseros, regar a la vez (línea), cortar una propagación (cortafuegos), quemar un gas (setas), pulso que explota (geoda).

### Mecánicas distintas

Contando una sola vez las plantillas que enseñan la misma idea (los grupos de §1), el catálogo tenía **23** mecánicas distintas resolubles con la demo; ahora tiene **36** (las 13 nuevas son 13 mecánicas distintas entre sí y de las 23). Además tocan por primera vez piezas ya programadas que ninguna plantilla usaba: `trampa_dragon` (×3), `trampa_flechas`, `respiradero`, `secuencia` y `mural`, muro `termica`, `lava` con `roca_empujable`, `geoda` + `columna`, pulsadores de agua con rearme corto, manantial con `inicia=no`, y `molino` con `hechizo=no`.

## 3. Plantillas nuevas (13)

| Id | Título | Sellos | Verbo | Origen | Nivel de playtest |
|---|---|---|---|---|---|
| `choque_termico` | Choque térmico: la roca al rojo | fuego + agua | calentar y enfriar (transformar estado) · romper | lab de fuego F14 (propuesta 8 del catálogo de 18/11) | PtFuego2 · sala 6 (nº 5) |
| `braseros_orden` | Braseros en orden y mural de barro | fuego + agua | secuencia · revelar (mural) · encender | lab de fuego F15 (propuesta 10 y 12 de 18/11) | PtFuego2 · sala 2 (nº 2) |
| `dragon_brasero` | El brasero tras el chorro | fuego | apagar una trampa disparando a través de ella · tiempo | Mystralia X7 / O13 | PtFuego2 · sala 3 (nº 3) |
| `gotera_brasero` | Brasero bajo la gotera | fuego | apagar (el agua como obstáculo) · cortar el flujo · tiempo | lab de fuego F16 (propuesta 13 de 18/11) | PtFuego2 · sala 4 (nº 1) |
| `dos_riegos` | Dos riegos a la vez | agua | regar a la vez (línea ᛁ) | lab de agua Q11 (propuesta 4 de 18/11) | PtAgua2 · sala 1 (nº 1) |
| `lava_roca_peso` | La roca sobre la lava enfriada | agua | enfriar · empujar · pesar · cruzar (tiempo) | lab de agua Q15 (propuesta 7 de 18/11) | PtAgua2 · sala 3 (nº 2) |
| `escudo_flechas` | Escudo de tierra contra las flechas | tierra | protegerse construyendo · cruzar | lab de tierra T5 (T4 de PUZLES_DEMO) | PtTierra2 · sala 3 (nº 2) |
| `retener_cuenca` | Retener el agua: tapón de tierra | tierra + agua | retener agua (presa en seco) · llenar | lab de agua T1b (T1 de PUZLES_DEMO) | PtTierra2 · sala 5 (nº 4) |
| `setas_veneno` | El pasillo de las setas de veneno | fuego o agua | quemar o atascar el gas · cruzar | lab de fuego F12 (propuesta 6 de 18/11) | PtFuego2 · sala 7 (nº 4) |
| `geoda_columna` | La geoda que tumba la columna | cualquiera | pulso → explosión · romper | Cueva C3 (geoda + columna) | PtFuego2 · sala 5 (nº 6) |
| `placa_isla` | La placa de la isla | tierra | pesar a distancia · construir | lab de tierra T1 (placa a distancia) | PtTierra2 · sala 4 (nº 3) |
| `molino_hielo` | El molino tras la compuerta de hielo | fuego | derretir → hacer fluir → mover (molino) | lab de agua Q9 con grifo de hielo (idea propia) | PtTierra2 · sala 7 (nº 5) |
| `dragon_seto_cofre` | El dragón que enciende la mecha | agua | cortar una propagación (cortafuegos) · proteger | lab de fuego F13 (propuesta 5 de 18/11) | PtAgua2 · sala 7 (nº 4) |

Cada una lleva en su `.txt` un comentario de diseño (qué ve la jugadora, la idea, la solución), `; necesita` exacto, `; validacion pendiente` y sus líneas `; prueba` para el comprobador.

De Mages of Mystralia: **X7 «el brasero tras el chorro»** está hecha (`dragon_brasero`). **X13 / P14 «el brasero tras el murete» NO se puede con lo que hay** (ver §6). Lo de «sin código» de PUZLES_DEMO / CATALOGO 18/11 que se ha montado: propuestas 4 (`dos_riegos`), 5 (`dragon_seto_cofre`), 6 (`setas_veneno`), 7 (`lava_roca_peso`), 8 (`choque_termico`), 10 y 12 (`braseros_orden`), 13 (`gotera_brasero`) y T1b/T4/T1 de PUZLES_DEMO (`retener_cuenca`, `escudo_flechas`, `placa_isla`).

### Niveles de playtest nuevos

Generados por `herramientas/generar_playtest_puzles.gd` (kit «demo»; un puzle por sala, en orden desde el inicio; **Alt + número** te lleva a cada sala; detalle en `docs/PLAYTEST_PUZLES.md`).

**PtFuego2** · Fuego 2 (chorros, setas, mural). Abrir: `E:\magic-symbols\tools\Godot_v4.7.2-stable_win64.exe --path E:\magic-symbols res://escenas/PruebaPtFuego2.tscn`

| Orden | Sala | Puzle | Necesita |
|---|---|---|---|
| 1 | 4 | Brasero bajo la gotera (`gotera_brasero`) · nueva | fuego + flecha |
| 2 | 2 | Braseros en orden y mural de barro (`braseros_orden`) · nueva | fuego + agua + flecha |
| 3 | 3 | El brasero tras el chorro (`dragon_brasero`) · nueva | fuego + flecha |
| 4 | 7 | El pasillo de las setas de veneno (`setas_veneno`) · nueva | fuego + flecha, o agua + flecha |
| 5 | 6 | Choque térmico: la roca al rojo (`choque_termico`) · nueva | fuego + agua + flecha |
| 6 | 5 | La geoda que tumba la columna (`geoda_columna`) · nueva | fuego + flecha, o agua + flecha, o tierra + flecha |
| 7 | 8 | La veta de los dos caminos (`veta_dos_caminos`) | fuego + flecha |

**PtAgua2** · Agua 2 (riegos, lava, balsa, puentes). Abrir: `E:\magic-symbols\tools\Godot_v4.7.2-stable_win64.exe --path E:\magic-symbols res://escenas/PruebaPtAgua2.tscn`

| Orden | Sala | Puzle | Necesita |
|---|---|---|---|
| 1 | 1 | Dos riegos a la vez (`dos_riegos`) · nueva | agua + linea |
| 2 | 3 | La roca sobre la lava enfriada (`lava_roca_peso`) · nueva | agua + flecha |
| 3 | 6 | El puente de zarcillos (`puente_raices`) | agua + flecha |
| 4 | 7 | El dragón que enciende la mecha (`dragon_seto_cofre`) · nueva | agua + flecha |
| 5 | 8 | El puente y el aliviadero (`puente_aliviadero`) | fuego + flecha |
| 6 | 5 | El cofre que viene a ti (`cofre_balsa`) | agua + flecha, o fuego + flecha |

**PtTierra2** · Tierra 2 (escudo, isla, presa, molinos). Abrir: `E:\magic-symbols\tools\Godot_v4.7.2-stable_win64.exe --path E:\magic-symbols res://escenas/PruebaPtTierra2.tscn`

| Orden | Sala | Puzle | Necesita |
|---|---|---|---|
| 1 | 2 | El molino y la pasarela (`molino_paso_bajo`) | tierra + barrera |
| 2 | 3 | Escudo de tierra contra las flechas (`escudo_flechas`) · nueva | tierra + barrera |
| 3 | 4 | La placa de la isla (`placa_isla`) · nueva | tierra + barrera |
| 4 | 5 | Retener el agua: tapón de tierra (`retener_cuenca`) · nueva | tierra + barrera + agua + flecha |
| 5 | 7 | El molino tras la compuerta de hielo (`molino_hielo`) · nueva | fuego + flecha |

`PtFuego`, `PtVagonetas`, `PtAguaTierra`, `PtEmpujePulso`, `PtJefeCueva`, `PtJefeBosque` y `PtHielo` se han regenerado también (la herramienta rehace todos; sus puzles son los de siempre y cada nivel guarda la copia del mapa anterior).

## 4. Catálogo completo

`Estado` = `; validacion` de la plantilla (todas las nuevas, `pendiente`: las validará Pablo jugando). `Verificación` = qué prueba automática la resuelve.

| Id | Título | Tipo | Sellos | Verbo | Estado | Nivel de playtest · sala | Verificación | Origen |
|---|---|---|---|---|---|---|---|---|
| `balanza_rocas` | Balanza: dos rocas y un bloque de tierra | premio | tierra | pesar · empujar · construir | ajustes | PtAguaTierra · sala 5 (nº 6) | escenario_catalogo_nuevos | Lost Cave LC2 (mina) |
| `barril_muro` | Voladura: barril contra el muro | premio | fuego | romper (explosión) | aceptado | PtFuego · sala 6 (nº 5) | escenario_catalogo_nuevos | Lost Cave LC1 (voladura) |
| `braseros_orden` (nueva) | Braseros en orden y mural de barro | premio | fuego + agua | secuencia · revelar (mural) · encender | pendiente | PtFuego2 · sala 2 (nº 2) | comprobar_puzles_agua | lab de fuego F15 (propuesta 10 y 12 de 18/11) |
| `braseros_premio` | Tres braseros y un cofre | premio | fuego | encender (todos) | aceptado | PtFuego · sala 3 (nº 2) | — (solo la coloca el generador) | Cueva C1 |
| `braseros_puerta` | Dos braseros que abren | salida | fuego | encender (todos) | aceptado | PtFuego · sala 2 (nº 1) | prueba_generador_mapas (colocación) | Bosque 01 (activador de barrera) |
| `charca_helada` | Charca que hay que helar | paso | hielo | cruzar (helar) | pendiente | PtHielo · sala 1 (nº 1) | — (fuera de la demo) | idea propia (hielo) |
| `choque_termico` (nueva) | Choque térmico: la roca al rojo | premio | fuego + agua | calentar y enfriar (transformar estado) · romper | pendiente | PtFuego2 · sala 6 (nº 5) | comprobar_puzles_agua | lab de fuego F14 (propuesta 8 del catálogo de 18/11) |
| `cofre_balsa` | El cofre que viene a ti | premio | agua o fuego | llenar / vaciar · transportar | pendiente | PtAgua2 · sala 5 (nº 6) | comprobar_puzles_agua | Q12 lab de agua (26/11) |
| `contrafuego` | Contrafuego: setos y barril | premio | fuego | propagar el fuego (setos → barril) | aceptado | PtFuego · sala 7 (nº 4) | escenario_catalogo_puzles | Bosque 01 F4 |
| `cristal_receptor` | Cristal dormido y receptor de fuego | salida | cualquiera | pulso (cristal → veta → receptor) | aceptado | PtFuego · sala 5 (nº 6) | escenario_catalogo_nuevos | Cueva C2/C6 |
| `dos_riegos` (nueva) | Dos riegos a la vez | premio | agua | regar a la vez (línea ᛁ) | pendiente | PtAgua2 · sala 1 (nº 1) | comprobar_puzles_agua | lab de agua Q11 (propuesta 4 de 18/11) |
| `dragon_brasero` (nueva) | El brasero tras el chorro | premio | fuego | apagar una trampa disparando a través de ella · tiempo | pendiente | PtFuego2 · sala 3 (nº 3) | comprobar_puzles_agua | Mystralia X7 / O13 |
| `dragon_seto_cofre` (nueva) | El dragón que enciende la mecha | premio | agua | cortar una propagación (cortafuegos) · proteger | pendiente | PtAgua2 · sala 7 (nº 4) | comprobar_puzles_agua | lab de fuego F13 (propuesta 5 de 18/11) |
| `escondite_muro` | Escondite tras el muro agrietado | premio | tierra | romper (golpes) | pendiente | PtAguaTierra · sala 4 (nº 4) | escenario_catalogo_puzles | Bosque 02 |
| `escudo_flechas` (nueva) | Escudo de tierra contra las flechas | premio | tierra | protegerse construyendo · cruzar | pendiente | PtTierra2 · sala 3 (nº 2) | comprobar_puzles_agua | lab de tierra T5 (T4 de PUZLES_DEMO) |
| `estatuas_sellos` | Tres estatuas: fuego, agua, tierra (ᚱ) | premio | fuego + agua + tierra | secuencia de pulsos (ᚱ) | pendiente | PtEmpujePulso · sala 6 (nº 4) | escenario_catalogo_nuevos | Cueva C1 / Lost Cave LC6 |
| `geoda_columna` (nueva) | La geoda que tumba la columna | premio | cualquiera | pulso → explosión · romper | pendiente | PtFuego2 · sala 5 (nº 6) | comprobar_puzles_agua | Cueva C3 (geoda + columna) |
| `gotera_brasero` (nueva) | Brasero bajo la gotera | premio | fuego | apagar (el agua como obstáculo) · cortar el flujo · tiempo | pendiente | PtFuego2 · sala 4 (nº 1) | comprobar_puzles_agua | lab de fuego F16 (propuesta 13 de 18/11) |
| `hielo_pista` | Bloque de hielo en la pista | salida | tierra | empujar (deslizar) · frenar con barrera | pendiente | PtAguaTierra · sala 7 (nº 5) | — | Sala del Empuje E2 |
| `lava_roca_peso` (nueva) | La roca sobre la lava enfriada | premio | agua | enfriar · empujar · pesar · cruzar (tiempo) | pendiente | PtAgua2 · sala 3 (nº 2) | comprobar_puzles_agua | lab de agua Q15 (propuesta 7 de 18/11) |
| `molino_hielo` (nueva) | El molino tras la compuerta de hielo | premio | fuego | derretir → hacer fluir → mover (molino) | pendiente | PtTierra2 · sala 7 (nº 5) | comprobar_puzles_agua | lab de agua Q9 con grifo de hielo (idea propia) |
| `molino_paso_bajo` | El molino y la pasarela | salida | tierra | desviar / retener flujo (presa) · cruzar | pendiente | PtTierra2 · sala 2 (nº 1) | comprobar_puzles_agua | P4 (23/11) |
| `pared_hueca_nicho` | Pared hueca y nicho (ᚱ) | premio | cualquiera | pulso del jugador (ᚱ) | pendiente | PtEmpujePulso · sala 4 (nº 3) | escenario_catalogo_nuevos | Lost Cave LC5 |
| `piedra_pista` | Bloque de piedra en la pista | salida | ninguno | empujar · pesar | pendiente | PtEmpujePulso · sala 1 (nº 1) | — | Bosque 02 s10 / Sala del Empuje |
| `piedra_premio` | Peso de la piedra (cofre) | premio | ninguno | empujar · pesar | pendiente | PtEmpujePulso · sala 5 (nº 2) | escenario_catalogo_puzles | Bosque 02 s10 |
| `placa_isla` (nueva) | La placa de la isla | premio | tierra | pesar a distancia · construir | pendiente | PtTierra2 · sala 4 (nº 3) | comprobar_puzles_agua | lab de tierra T1 (placa a distancia) |
| `presa_barril` | Presa: el barril rompe el muro del agua | premio | fuego | romper · llenar / vaciar | ajustes | PtAguaTierra · sala 9 (nº 7) | escenario_catalogo_nuevos | Pablo 26/11 |
| `prisma_rojo_azul` | Prisma: rojo y azul | premio | fuego + agua | pulso (orientar el prisma) | pendiente | PtEmpujePulso · sala 3 (nº 5) | escenario_catalogo_nuevos | Lost Cave LC4 |
| `puente_aliviadero` | El puente y el aliviadero | paso | fuego | vaciar · quemar la cuerda · cruzar | pendiente | PtAgua2 · sala 8 (nº 5) | comprobar_puzles_agua | Bosque 02 / rama de agua |
| `puente_cuerda` | Puente plegado: agua o fuego | paso | agua o fuego | activar (placa) o quemar la cuerda · cruzar | pendiente | PtAguaTierra · sala 3 (nº 3) | escenario_catalogo_puzles | Bosque 02 / Gruta Batida G4 |
| `puente_raices` | El puente de zarcillos | paso | agua | regar (germinar) · cruzar | pendiente | PtAgua2 · sala 6 (nº 3) | comprobar_puzles_agua | puente de zarcillos 23/11 |
| `rele_braseros` | Relé de braseros | salida | fuego | encender · tiempo (relé) | aceptado | PtFuego · sala 4 (nº 3) | escenario_catalogo_puzles | Bosque 01 F2 |
| `retener_cuenca` (nueva) | Retener el agua: tapón de tierra | premio | tierra + agua | retener agua (presa en seco) · llenar | pendiente | PtTierra2 · sala 5 (nº 4) | comprobar_puzles_agua | lab de agua T1b (T1 de PUZLES_DEMO) |
| `riega_pulsador` | Riega la placa | salida | agua | activar (pulsador de agua) | pendiente | PtAguaTierra · sala 1 (nº 1) | escenario_catalogo_puzles | Bosque 02 |
| `rio_lava` | Río de lava | paso | agua | enfriar · cruzar (tiempo) | pendiente | PtAguaTierra · sala 2 (nº 2) | — | Cueva C3 |
| `setas_veneno` (nueva) | El pasillo de las setas de veneno | premio | fuego o agua | quemar o atascar el gas · cruzar | pendiente | PtFuego2 · sala 7 (nº 4) | comprobar_puzles_agua | lab de fuego F12 (propuesta 6 de 18/11) |
| `vagoneta_aguja` | Vagoneta y aguja: elige el ramal (mecanismo) | salida | cualquiera | mecanismo (aguja + lanzar) | aceptado | PtVagonetas · sala 4 (nº 4) | escenario_catalogo_nuevos | Lost Cave |
| `vagoneta_boton` | Vagoneta lanzada contra el muro (mecanismo) | premio | cualquiera | mecanismo (lanzar contra muro) | aceptado | PtVagonetas · sala 3 (nº 3) | escenario_catalogo_nuevos | Lost Cave |
| `vagoneta_curva` | Vagoneta por la curva (a mano) | premio | ninguno | empujar (vagoneta, curva) | pendiente | PtVagonetas · sala 5 (nº 2) | escenario_catalogo_nuevos | Lost Cave |
| `vagoneta_pista` | Vagoneta a la placa (a mano) | salida | ninguno | empujar · pesar (vagoneta) | aceptado | PtVagonetas · sala 1 (nº 1) | escenario_catalogo_nuevos | Lost Cave |
| `veta_dos_caminos` | La veta de los dos caminos | salida | fuego + tierra | pulso · construir (enlace) / girar prisma | pendiente | PtFuego2 · sala 8 (nº 7) | comprobar_puzles_agua (26/11) | rama de agua (26/11) |

## 5. Cómo se ha comprobado

Todo con `godot --headless --fixed-fps 30 --path . --script res://herramientas/<prueba>.gd` (acaban imprimiendo `FALLOS: n`).

- **`herramientas/comprobar_puzles_agua.gd`** (el comprobador de la rama de agua) vale ahora para cualquier plantilla: genera un mapa con la plantilla puesta en una sala, lo exporta, lo carga y aplica las líneas `; prueba …` de la plantilla con hechizos reales (`Lanzador3D`). Pasos nuevos: `cruza a b sin_dano|con_dano` (anda de verdad y mide la vida), `empuja <pieza> n|e|s|o [veces]`, `usa <pieza>` (E de verdad: gira un prisma), `abre <cofre>` (E de verdad), y la condición `jugador herido|sano`. Los mapas temporales llevan el id del proceso (`CatComp<pid>_P<n>`), así que se pueden lanzar varias pasadas a la vez.
- **Cada plantilla nueva lleva dos clases de prueba:** una o más `solucion` que RESUELVEN (golpes reales, esperas, y casi siempre `abre cofre`: la jugadora se pone junto al cofre y pulsa E) y una o más `nada…` que demuestran que NO se resuelve sola ni con el gesto equivocado (agua sin tapón en `retener_cuenca`; riegos sueltos en `dos_riegos`; tierra, fuego solo o agua sola a la roca térmica; desorden de braseros; sin escudo, las flechas dan; sin encender el brasero, el chorro hiere; barril que revienta si no se corta la mecha…).
- Resultado de la última pasada (todo con `FALLOS: 0`):

| Prueba | Resultado |
|---|---|
| `comprobar_puzles_agua` · `choque_termico`, `braseros_orden`, `dos_riegos` | 12 pruebas, 0 con fallo |
| `comprobar_puzles_agua` · `dragon_brasero`, `gotera_brasero`, `escudo_flechas`, `setas_veneno` | 12 pruebas, 0 con fallo |
| `comprobar_puzles_agua` · `lava_roca_peso`, `retener_cuenca`, `placa_isla`, `geoda_columna`, `molino_hielo`, `dragon_seto_cofre` | 18 pruebas, 0 con fallo |
| `comprobar_puzles_agua` · `cofre_balsa`, `puente_aliviadero`, `puente_raices`, `molino_paso_bajo` (las cuatro de agua con pruebas) | 22 pruebas, 0 con fallo |
| `comprobar_puzles_agua` · `veta_dos_caminos` (pruebas nuevas: tierra, prisma con E, prisma con hechizo, nada) | 4 pruebas, 0 con fallo |
| `comprobar_puzles_agua` · `dragon_seto_cofre` (con su disposición final de dos filas de muro) | 4 pruebas, 0 con fallo |
| `escenario_catalogo_puzles` | `FALLOS: 0` |
| `escenario_catalogo_nuevos` (comprueba además que TODAS las plantillas dicen su `; necesita`) | `FALLOS: 0` |
| `prueba_generador_mapas` (incluye «ninguna pared queda de punta» con las 41 plantillas) | 114150 comprobaciones, `FALLOS: 0` |
| `generar_playtest_puzles` (cada nivel Pt carga con `Puzle3D` sin avisos; Alt+n lleva a cada sala) | `FALLOS: 0` |

Lo que las pruebas automáticas NO prueban: el aspecto (modelos de las trampas en el muro, roca térmica, mural…), el sonido, ni la dificultad. Para eso están los niveles de playtest. Una limitación del comprobador: lanza los hechizos con `lanzar_pagina_ya`, sin pasar por el cálculo de tinta ni el modo de apuntar.

Cosas que salieron al probar (ya corregidas en las plantillas): una plantilla de 9 casillas de ancho no cabía en las salas de 4-8 por defecto (`lava_roca_peso` pasó a 8); una pieza sobre una `#` de la plantilla invalida el mapa (de ahí el cambio de §7 para las trampas); un cofre o una placa sobre un muro de la plantilla también (tres plantillas los tenían mal colocados); un muro de una sola casilla de grueso se ve de punta (`dragon_seto_cofre`); en `escudo_flechas` cruzar sin escudo no es que duela: la jugadora **no llega** (muere en la línea de tiro), así que la prueba `nada` mide que se hiere en vez de que no se cruza.

## 6. Lo que queda fuera (y lo que le falta)

### De Mages of Mystralia (docs/MAGES_OF_MYSTRALIA_2026-11-21.md, PROPUESTAS_SESION_MYSTRALIA, PUZLES_DEMO §3)

| Puzle | Estado | Qué le falta |
|---|---|---|
| **X7 El brasero tras el chorro** (O13) | **Hecho:** `dragon_brasero` | — |
| **X13 / P14 El brasero tras el murete** (O29) | **No se puede con lo que hay** | Necesita un obstáculo que corte el tiro recto y se salte cambiando el hechizo. Con los glifos de la demo no existe: `altura` sube el VOLUMEN del hechizo (pilares, muros), no su trayectoria, y `HechizoVivo` consulta `celda_solida(c, 0)` a nivel 0 en todas partes (solo el trazado antiguo de `Lanzador3D.trazar` usa el nivel); el rebote y el retorno no están en el kit de la demo; ᚨ no busca braseros. Además una plantilla no puede declarar muretes bajos (alturas). Hay que decidir qué glifo de la demo cambia el camino (o meter el rebote en el kit) y añadir la pieza. |
| X5 Plataforma bajo el dragón (O2), X6 La mecha suspendida (O4), X8 Tres braseros y plataformas (O15), X9 Plataformas en raíl (O19), X11 La luz mueve la vagoneta (O25) | Pendientes | **La plataforma móvil (P6)**: pieza nueva grande (ruta, lleva lo que tiene encima, la barrera viaja con ella). Además, X8 pide un chorro que empuje; X6, una bola de fuego quieta con permanencia. |
| X10 Reflejar el rayo de luz (O24), X12 Alinear los prismas (O26) | Pendientes | **La luz cenital con su pedestal** y la regla «la protección de agua refleja»; que el prisma acepte luz además de pulso. Código nuevo grande. |

### Del resto de PUZLES_DEMO §3 y del catálogo de 18/11

| Puzle | Qué le falta |
|---|---|
| T2 La cornisa (tierra + altura) y **T3 El foso (ᛒ suelo)** | Son los dos que **enseñarían los glifos `altura` y `suelo`** de la demo, hoy sin ningún puzle en el catálogo. T3 necesita que una plantilla pueda declarar casillas de **vacío** (hoy un espacio en la plantilla es «no tocar»; el vacío solo lo pone el generador para las barreras de paso, en `generador_mazmorra.gd` y el exportador). T2 necesita una pieza `cornisa` (altura fija con modelo) en `puzle.gd`. Una letra de vacío en las plantillas y una pieza `cornisa` pequeña los desbloquean; no lo he hecho porque tocaba el generador, que está en edición por otro agente. **Es lo primero que haría.** |
| T5 Las bocas de la mámoa | Decidir qué sale de la mámoa; hay un mouro que combatir (no automatizable de forma fiable). El lab T7 (sellar la mámoa) sirve de base. |
| T6 Pedrada que empuja | Código: la flecha de tierra mueve un bloque una casilla. |
| X1 Trampas en el vado | Es un combate (vigía + ᛒ trampas). |
| X2 Lava, presa y arroyo | Comprobar que el agua de la simulación enfría la lava (hoy solo la enfría un hechizo). |
| X3 Setas tapadas | Reacción nueva: «tierra tapa el respiradero». |
| X4 La caldera, Q13 Brasas en el sendero, Q14 El barril que no debe estallar, Q16 Subir la balsa, F14 Cortina de vapor | Estado «agua caliente», brasas que se reavivan, urna frágil, balsa que sigue el nivel, vapor que tapa la vista (sistemas nuevos). |
| La caldera (propuesta 1), el **reloj de agua** (propuesta 2) y **nivel justo** (Q8) del lab | Se pueden montar sin código, pero **no tienen reintento**: si se pierde el nivel no hay forma de volver a llenar sin recargar la sala (en el lab se hace con R), y una mazmorra no puede dejar un puzle sin salida. Entrarían con L7 «reiniciar un puzle» (hoy propuesta). |
| Lleva la pólvora (F10, propuesta 3) | Se puede montar sin código; falta que el comprobador sepa coger, encender y lanzar el barril pequeño (hoy lo hace solo `escenario_puzles_fuego_nuevos.gd`). |
| Tres bancales (Q15) | Se puede montar; es otra versión de «regar» y no aporta un verbo nuevo. No la he metido. |
| Convertir en `salida` (para enlazar a puertas y puentes) las nuevas que valgan | Las 13 nuevas son `premio`; cada una ya tiene su señal (`cofre.aparecido`, `muro.roto`, `orden.completa`…). |

## 7. Cambios de código (todos pequeños)

- **`herramientas/generador_mapas/generador_mazmorra.gd`** (`_estampar`, 3 líneas): una `trampa_dragon` o `trampa_flechas` (sin `exenta=si`) puede ir sobre una `#` de la plantilla. Antes, cualquier pieza sobre un muro invalidaba la plantilla; las cabezas de dragón y los mascarones van metidos en el muro, así que ninguna plantilla de trampas se podía estampar.
- **`herramientas/generador_mapas/exportador_mapa.gd`** (validación de piezas, 2 líneas): la misma excepción («cae en pared»).
- **`herramientas/generador_mapas/catalogo_puzles.gd`**: solo la cabecera (pasos nuevos de `; prueba`, trampas sobre `#`, aviso sobre ids que coinciden con valores de claves).
- **`herramientas/comprobar_puzles_agua.gd`**: pasos `empuja`, `usa`, `abre`, `cruza … sin_dano|con_dano`, condición `jugador herido|sano`, prefijo de mapas temporales por proceso.
- **`herramientas/generar_playtest_puzles.gd`**: tres grupos nuevos (PtFuego2, PtAgua2, PtTierra2); en PtTierra2 va primero la plantilla grande (la colocación es «la primera sala libre donde cabe», sin marcha atrás).
- Plantillas: `; necesita` y `; validacion pendiente` en las 5 de agua de la fusión (`cofre_balsa`, `molino_paso_bajo`, `puente_aliviadero`, `puente_raices`, `veta_dos_caminos`) y pruebas nuevas en `veta_dos_caminos`.
- No hay cambios en `escenas/puzle.gd` ni en los objetos.

## 8. Pendiente y heredado

- Ningún fallo heredado: las pasadas base (`escenario_catalogo_puzles`, `escenario_catalogo_nuevos`, `prueba_generador_mapas`) pasan con las 41 plantillas.
- Las trampas en el muro se ven por primera vez en mapas del catálogo: **hay que mirarlas con ventana** (que la cabeza de dragón y el mascarón quedan bien en el muro de la plantilla, que el chorro se lee, que la cámara los enseña).
- Todo queda `pendiente` de playtest. Cuando Pablo juegue los niveles Pt, sus decisiones van a `; validacion` y `; nota_playtest` de cada plantilla y a la hoja maestra (filas `cat_<id>`; no la he tocado).
- Cada vez que se regeneran los niveles Pt, el exportador deja junto a cada mapa una copia del anterior (`Pt…_copia_<fecha>.txt`). He dejado solo la primera de cada nivel (el estado de antes de esta tanda) y borrado las que eran de mis pasadas intermedias.

