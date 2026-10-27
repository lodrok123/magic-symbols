# La Cueva Resonante — la Cueva como mazmorra de EoW

27/10/2026 · contexto JUEGO · **listo para playtest**.

- **Mapa (editable):** `mundo/datos_nivel/mapas/CuevaResonante.txt`
- **Escena:** `escenas/PruebaCuevaResonante.tscn` (nivel `CuevaResonante` en `Niveles.ESCENAS`)
- **Autoplay:** `herramientas/escenario_cueva_resonante.gd` (102 comprobaciones, 0 fallos, ~4 min de juego)

La Cueva antigua (`Cueva.txt`, `PruebaCueva.tscn`) sigue igual, con sus pruebas. La nueva usa la **misma geometría** (27 × 25, seis salas de 8 × 8 y el nicho de las estatuas). Ya estaba probada: paredes del kit, cascada, luz por zona y caminos. Lo que cambia es **qué hay en cada sala y en qué orden se aprende**. Solo hay tres cambios de pared: el nicho del brasero en C1 y el santuario en C6.

---

## 1. La regla de EoW: presentar → desarrollar → combinar

En las mazmorras de EoW una pieza nueva aparece primero **sola y sin riesgo**, de forma que se *ve* qué hace. La sala siguiente la **pide** con un giro, y la última sala la **mezcla** con lo anterior. La Cueva antigua tenía todas las piezas, pero no seguía esa curva:

| problema de la Cueva antigua | por qué rompe la curva |
|---|---|
| **C6 se resolvía sola**: el prisma ya nacía mirando al receptor y la fuente de C5 lo activaba por el agua | la sala final, la del glifo, no tenía puzle; se llegaba andando |
| **C5 era andar**: se rodeaba la charca y el pulso llegaba solo | el agua como conductor y el hielo que corta se veían, pero nunca se pedían |
| **El prisma salía por primera vez en C6** y, encima, no hacía falta | una pieza sin presentar justo en el final |
| **«El pulso lleva el elemento del golpe» era opcional en C1**: el brasero del fondo también se encendía a flechazos | la idea central de la mazmorra no se pedía nunca |
| **En C2 el pulso era opcional** (la columna); lo obligado era el muro de tierra de siempre | el receptor y el hueco de veta no se aprendían en el camino principal |
| **El receptor de elemento (`elemento=`) no se usaba** | se perdía la mezcla «runa + pulso» antes del glifo |

## 2. Los átomos

Cada pieza del pulso es un átomo con un solo papel. Son las cinco familias del `PLAN_PULSO_RESONANTE.md` §4, más las piezas elementales que ya había.

| átomo | familia | pieza del mapa | qué hace |
|---|---|---|---|
| **E1** cristal que late | emisor | `cristal cada=3` | suelta un pulso azul cada n s |
| **E2** cristal dormido / teñido | emisor | `cristal cada=0` | late solo al golpearlo; **el pulso lleva el elemento del golpe** |
| **E3** fuente eléctrica | emisor | `emisor` + `fuente.pulso(n)` | cada descarga suelta un pulso de rayo por el agua |
| **C1** veta | conductor | `veta` | lleva el pulso de casilla en casilla |
| **C2** hueco de veta | conductor que construye el jugador | `veta enlaces=` | conduce solo con un bloque de tierra encima (25 s) |
| **C3** agua | conductor | `~`, simulación | conduce; **el hielo corta** |
| **C4** basalto | conductor temporal | `lava vuelve=10` | la lava enfriada conduce y se pisa durante 10 s |
| **C5** columna-puente | conductor creado por una reacción | `columna puente=` | la tumba una explosión; queda como puente para siempre |
| **M1** prisma | modificador | `prisma dir=` | reemite el pulso hacia donde mira; se gira con E o con un golpe de hechizo |
| **R1** receptor | receptor | `receptor` | se activa con cualquier pulso y pone una flag |
| **R2** receptor de elemento | receptor | `receptor elemento=` | solo con un pulso de ese elemento; en reposo brilla de su color |
| **R3** brasero | receptor | `brasero` | se enciende con fuego **o con un pulso de fuego** |
| **R4** estatuas | receptor de secuencia | `estatuas` | pulsos de elementos en orden (opcional, con el glifo) |
| **X1** seta que madura | reactivo / premio | `seta madura=si` | madura con el pulso → seta resonante |
| **X2** columna agrietada | reactivo | `columna` | dos pulsos la tumban |
| **X3** geoda | reactivo | `geoda` | un pulso la hace explotar: rompe lo que tiene cerca |
| **X4** estalagmita | reactivo de combate | `estalagmita` | vibra y cae sobre el goblin de al lado |
| **X5** pared hueca | reactivo | `pared_hueca` | hace eco con cualquier pulso; **solo la abre el pulso propio (ᚱ)** |

## 3. La curva, sala a sala

`P` = presentar (sin riesgo, se ve), `D` = desarrollar (se pide con un giro), `C` = combinar (con otros átomos), `o` = opcional.

| átomo | C1 Boca | C2 Grietas | C3 Lava | C4 Cerrada | C5 Charca | C6 Santuario |
|---|:-:|:-:|:-:|:-:|:-:|:-:|
| E1 cristal que late | **P** | D | D | | | |
| E2 cristal golpeado / teñido | **P** (obligado) | | D | D | | **C** |
| E3 fuente | | | | | **P** | |
| C1 veta | **P** | D | D | D | D | C |
| C2 hueco + tierra | | **P** (obligado) + D(o) | | | | **C** |
| C3 agua (y hielo que corta) | | | | | **P** | |
| C4 basalto | | | P(o) | | | |
| C5 columna-puente | | | **P** | | | |
| M1 prisma | | | | | **P** (obligado) | **C** |
| R1 receptor | | **P** | D(o) | | | |
| R2 receptor de elemento | | | | | **P** (rayo) | **C** (fuego) |
| R3 brasero | **P** | | | | | |
| X1 seta que madura | P | | | | | |
| X2 columna | | P(o) | **D** | | | |
| X3 geoda | **P** (demostración) | | **D** | | | |
| X4 estalagmita | | | | P | | |
| X5 pared hueca | | | | | | **P** (eco) → primer uso del glifo |

### C1 · La Boca — *presentar*
- **Se ve sin hacer nada:** el cristal late cada 3 s; su pulso azul recorre la veta, hace brillar y madurar las setas y llega al brasero del nicho, **que no prende**. El pulso azul no quema.
- **Se ve al acercarse:** la geoda pegada a la veta explota con el primer latido en cuanto la jugadora está a 2 casillas, y rompe el jarrón de al lado. Esto anuncia C3.
- **Paso obligado:** los dos braseros. El de la derecha se enciende a flechazos, como ya se sabe hacer. El del **nicho** está tras una reja que para las flechas: la única forma de encenderlo es **golpear el cristal con fuego**. Así la idea de la mazmorra («el pulso lleva el elemento») se aprende en la primera sala, con el brasero visible y la veta que lleva hasta él.

### C2 · Las grietas — *presentar el receptor y el hueco*
- **Paso obligado:** la salida del este es una **reja** que abre un receptor. Su veta está cortada justo al sur del cristal. **Tierra + barrera** sobre el hueco (nace donde apuntas) tiende el enlace y el siguiente latido activa el receptor.
- **Opcional (misma idea, con giro):** otro hueco al oeste lleva el pulso a la **columna agrietada**. Dos latidos la tumban y abren el nicho del cofre. El filón da mineral con tierra.
- El muro agrietado de la Cueva antigua (dos golpes de tierra) **desaparece**: era una lección del Bosque, no del pulso. Con él se va también el bug del bloque de tierra que tapaba el hueco.

### C3 · El río de lava — *desarrollar*
- **Paso obligado:** cruzar el río. Hay dos soluciones:
  - **la geoda** (lo visto en C1): golpear el cristal dormido de la orilla. El pulso hace explotar la geoda y la columna cae como **puente permanente**. Es la solución «de la mazmorra».
  - **el agua**: enfriar la lava y cruzar en 10 s.
- **Opcional (contrarreloj):** con la fila 5 enfriada, el pulso del cristal cruza por el **basalto** y el receptor sube la reja del cofre del rincón.

### C4 · La sala cerrada — *desarrollar en combate*
Dos goblins y la sala se cierra. Los cristales dormidos de las paredes mandan el pulso por las vetas del suelo, que **aturde** al goblin que la pisa (el escudo no para lo que viene del suelo). Las estalagmitas le caen encima. Ayudan, pero no obligan. El cofre da la **llave**.

### C5 · La charca eléctrica — *presentar agua, prisma y receptor de elemento*
- La fuente descarga y su pulso de rayo corre por el agua hasta el **prisma**, que nace mirando al agua y no lo reemite.
- **Paso obligado:** **un giro** (E o un golpe de hechizo) lo pone al oeste. El pulso sale por la veta hasta el **receptor de rayo**, que ya brilla amarillo en reposo: dice qué pide. Ese receptor abre la reja de C6.
- **Lo que enseña sin decirlo:** si se hiela la charca, el circuito se corta hasta que el hielo se funde (20 s). Ninguna casilla de la veta toca el agua: sin el prisma no hay camino.

### C6 · El santuario — *combinar*
El cofre legendario está en un santuario al norte, tras la **puerta de la llave**, y **sellado** hasta que el receptor de **fuego** de su frente recibe un pulso de fuego. El circuito es: cristal dormido → veta → **hueco** → **prisma** → receptor de fuego. Hace falta todo lo aprendido:
1. **tierra + barrera** en el hueco (C2);
2. **dos giros** del prisma, de sur a oeste y a norte (C5). Nace mirando a la pared hueca, así que el primer intento hace **eco** en la salida: es la pista de lo que vendrá;
3. **fuego al cristal**: pulso teñido (C1) para un receptor de elemento (C5).

Después, la llave abre el santuario y el cofre da **ᚱ** con su secuencia. Su primer uso es la **pared hueca** de la salida, que lleva a C1 por el atajo. Las estatuas del nicho de C1 (opcional, épico) quedan para volver con el glifo.

## 4. Claridad: lo que comprueba el autoplay, además de que se pueda resolver

Cada sala comprueba también **lo que no debe pasar antes de resolverla** (`[legible]` en la salida). Si eso pasara, la sala se resolvería sola o por accidente:

- C1: el pulso azul no prende el brasero; la flecha directa no lo prende; con un solo brasero la puerta no se abre.
- C2: con la veta cortada el receptor no se activa.
- C3: la lava bloquea las dos filas antes de resolver.
- C5: el pulso llega al prisma mal girado y **no** activa el receptor.
- C6: sin hueco tendido el fuego no llega al prisma; con el prisma al sur el pulso hace eco en la pared hueca y el receptor sigue apagado.

**Dos fallos de diseño que salieron al autoplayearla** (ya corregidos):
1. **El prisma emite desde la casilla que mira, y esa casilla toca a sus vecinas.** En C5 el prisma mirando al oeste (al suelo) tocaba la veta desde (20,12) y activaba el receptor sin hacer nada. Ahora nace mirando al agua. **Regla para editar:** la casilla a la que mira un prisma «apagado» no puede tocar ninguna veta ni receptor.
2. **25 s de tierra no dan para ir a girar el prisma a mano y volver.** El orden natural es girar, tender y golpear. El prisma se gira también a hechizazos desde la fila 17, sin pisar el circuito.

## 5. Assets de la Cueva integrados

| asset | dónde | cómo |
|---|---|---|
| `cristal_resonante`, `receptor_runico`, `prisma_orientable`, `columna_agrietada`, `geoda_resonante`, `estalagmita_resonante`, `estatua_piedra`, `cofre_legendario`/`cofre_epico`, `brasero_cueva`, `puerta_llave_*`, jarrones, `alga_cueva`, `basalto_suelto` | en sus piezas | igual que en la Cueva antigua; ahora el prisma, el receptor de elemento y la columna-puente salen en el camino principal |
| `roca_musgosa`, `helechos_cueva`, `estalagmitas_a/b`, `rocas_salpicadura`, `musgo_colgante`, `raices_musgo` | adorno en C1, C2, C3, C5 y C6 | sección «ADORNO» al final del mapa (`decorado`), editable línea a línea |
| `cueva_pared_baja`, `boca_cueva`, `llave_pequena`, `bloque_enlace` | **se pueden poner** como `decorado` (lista ampliada en `Puzle3D.CLAVES`) | no se han colocado: sin captura con ventana no se puede comprobar cómo se ven. Propuestas: `boca_cueva` sobre la salida al Bosque y `llave_pequena` en el pedestal de la puerta de C6 |
| `placa_presion_cueva` | sin usar | `pulsador modo=presencia modelo=cueva`: queda como átomo para la siguiente mazmorra |

Nunca se generaron `setas_cueva` ni `charco_cueva_borde`.

## 6. Cómo editar el nivel

Todo está en el `.txt`. La gramática completa está en la cabecera de `escenas/puzle.gd`.
- **Plano:** las 25 primeras filas. `#` es pared (el kit elige la pieza según sus vecinas), `.` suelo, `~` charca, `R` basalto bajo la lava, `T` brasero, `W` goblin, `e` fuente, `S` inicio, `-` canal y `c` pozo.
- **Piezas:** `; pieza <id> <tipo> <x> <y> clave=valor`. **Reglas:** `; puzle <nombre> cuando=… hace=…`.
- **Reglas de receptor por flag** (`cuando=flag.<flag del receptor>`), no por señal. Al volver de otro nivel el receptor nace activo *antes* de engancharse las reglas, y la señal no llega nunca; la flag se repite al montar.
- **Huecos de veta:** la casilla del hueco va en `enlaces=` y **no** en `celdas=`. Si está en las dos, conduce sin bloque. Ahora `Puzle3D` avisa al montar.
- **El pulso solo avanza a las 4 vecinas.** Dos vetas en casillas pegadas son la misma red. Para que algo dependa de un prisma o de un hueco, deja una casilla sin conductor entre medias.
- Tras cambiar algo, pasa el autoplay:

```bash
tools/Godot_v4.7.2-stable_win64.exe --headless --fixed-fps 30 --path . --script res://herramientas/escenario_cueva_resonante.gd
```

## 7. Bugs revisados

**Arreglados (también en `Cueva.txt` cuando aplica):**

| bug | gravedad | arreglo |
|---|---|---|
| Tras volver de otro nivel, la reja de C3 no se abría nunca: el receptor nace activo antes de engancharse la regla y el cofre del rincón quedaba encerrado | alta | reglas de receptor por flag (`cuando=flag.…`) en las dos Cuevas |
| La columna del nicho de C2 se levantaba otra vez al volver (sin `flag=`) | media | `flag=…c2.columna` |
| Al volver, el paso norte de C1 estaba cerrado otra vez (braseros apagados, la puerta no se acuerda) | media | pareja `hace=flag.poner(cuevap.c1.norte)` + `cuando=flag.…` (Cueva Resonante) |
| Las estalagmitas caídas reaparecían en otra casilla al volver (la dirección no se guardaba) | baja | `cae=` fijo en el mapa |
| Cada prisma sumaba una casilla de alcance y reemitía un pulso ya agotado | baja | `PrismaPulso3D.on_pulso`: alcance − 1, y nada si no queda |
| La columna-puente de C3 se agrietaba, temblaba y sonaba con cada pulso aunque solo la tumba la explosión | baja | `MuroAgrietado3D.on_pulso` ignora los pulsos si es puente |
| Un hueco puesto también en `celdas` conducía sin bloque, en silencio | baja (de edición) | aviso de `Puzle3D` al montar |

**Vistos y no arreglados (bajos, para decidir):**
- El tono de «llegada» del pulso suena aunque lo tocado no reaccione: un receptor ya activo o una seta ya madura (`Pulso3D._avisar` no mira lo que devuelve `on_pulso`). Arreglarlo pide unificar qué devuelve `on_pulso` en todas las piezas.
- Un receptor con `rearme` y `flag` no quita la flag al apagarse. Ninguna Cueva lo usa.

## 8. Para el playtest

- Abre `escenas/PruebaCuevaResonante.tscn` (F6). Con el kit de pruebas se entra con todos los elementos y glifos menos ᚱ.
- **ᚱ todavía no tiene muestras grabadas** (`PENDIENTES.md`): tras el cofre, el glifo está en el libro pero **no se reconoce dibujándolo**. Para la pared hueca de la salida, ponlo con la paleta (F1) o graba sus muestras con `G` antes de jugar.
- El hueco de veta pide **tierra + barrera**: una página sin glifos no se lanza.
- **El autoplay no puede comprobar estas cosas:**
  - si la reja (losa) del nicho de C1 deja ver el brasero;
  - si se entiende que el receptor de C5 (al norte) abre la reja del oeste (al sur), que queda lejos;
  - si los 25 s de la tierra en C6 agobian;
  - cómo se ve el adorno nuevo.
- La salida al Bosque y la entrada desde el Bosque siguen apuntando a la Cueva **antigua** (`a=Cueva:desde_bosque`). Para que el Bosque lleve a esta, cambia esa salida a `a=CuevaResonante:desde_bosque` en `Bosque_01_v01.txt`.

## 9. Lista de recogibles

En `docs/RECOGIBLES_DB.md`: la propuesta de base de datos para la síntesis.
