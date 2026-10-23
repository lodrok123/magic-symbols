# Plan · El Pulso resonante: la recompensa legendaria de la Cueva

Propuesta del 23/10/2026 sobre la idea de Pablo: la Cueva (`PLAN_BOSQUE_EOW.md` §6) gira en torno a un tema, el **pulso resonante**.
Durante la mazmorra el jugador ve varios usos del pulso y, al final, en un cofre propio con una animación corta, consigue el
**glifo** que le permite emitirlo. De paso se fijan tres calidades de recompensa: **común** (materiales), **épica** (materiales de
mejora) y **legendaria** (glifos).

La regla es **no tirar lo que hay sino potenciarlo**. Las seis salas, sus elementos y sus líneas de `Puzle3D` se quedan. El pulso se
añade por encima y reutiliza lo que ya conduce: el agua, `Terreno3D.conductores` y el nexo eléctrico (`NexoRayo3D`).

## 1. La idea en una frase

> Antes del cofre el pulso es **del escenario** y el jugador aprende a **llevarlo**. Después del cofre el pulso es **suyo**.

Es el patrón de las mazmorras de Zelda/EoW: el objeto de la mazmorra se entiende antes de tenerlo y se usa en cuanto se tiene. Aquí
la salida de la Cueva **pide** el pulso propio, de modo que el primer uso es obligatorio y llega justo después de la animación.

## 2. El glifo: una propiedad, no una geometría

En la receta v2 (`GLIFOS_RECETA.md` §2) el **volumen** dice qué espacio ocupa el hechizo y las **propiedades** dicen qué hace con él
en el tiempo. El pulso es lo segundo: cualquier volumen puede resonar. Por eso se propone como **glifo de propiedad**:

| glifo | parámetro | por glifo | tope | qué significa para cualquier volumen |
|---|---|---|---|---|
| *(por decidir)* resonancia | `resuena` (casillas) | +4 | 12 | al nacer el volumen (o al chocar, si *viaja*), suelta un **pulso** desde sus casillas que recorre los conductores conectados hasta `resuena` casillas |

- **Lleva el elemento de la receta.** Un pulso de fuego enciende braseros al otro lado de la veta, uno de rayo descarga en el agua
  (lo de hoy, con más alcance), uno de tierra agrieta lo que toca y uno de hielo congela el agua por la que pasa. Las combinaciones
  salen solas, como en el resto de la v2.
- **Sin elemento** es un pulso puro: activa receptores y cristales, revela paredes huecas por el eco y no hace daño.
- **El pulso base (decisión de Pablo, 23/10)** es ese pulso puro y tiene color propio: **azulado claro** (`Pulso3D.COLOR_BASE`,
  ≈ `Color(0.62, 0.85, 1.0)`, #9ED9FF). Es el color con el que se encienden vetas, cristales y receptores cuando el pulso no lleva
  elemento, el del pulso del escenario antes del cofre y el que se ve por defecto. Con elemento, el frente toma el color de su runa.
- **Conflicto de nombre:** ᚷ ya era «pulso» en la v2 (`crece`: el volumen nace pequeño y crece). Resuelto por Pablo (§10, punto 1) y construido en la fase 2: ᚷ se ve como «crecer» y ᚱ como «pulso».

**Mejoras épicas** (§7). *Superado por la decisión de Pablo del 23/10 (§10, punto 4): los épicos son ingredientes para mejorar al
personaje (vida, tinta, pigmentos, ropa), no variables del glifo.* La propuesta original era subir las variables del glifo:
- `resuena` +2 casillas;
- **saltos**: cuántos cristales resonantes puede atravesar;
- **fuerza**: los golpes de pulso que recibe un reactivo.

Es la misma idea de siempre: las propiedades mejoran variables de la clase del hechizo.

## 3. El pulso como señal

Regla única, igual para el pulso del escenario y para el del jugador:

1. Nace en un **emisor** (casillas de origen) con un elemento (o ninguno) y un alcance en casillas.
2. Avanza **casilla a casilla**, unos 0,08 s por casilla, por las 4 vecinas que **conducen**:
   - agua de juego;
   - vetas;
   - puentes de piedra;
   - basalto enfriado;
   - bloques de enlace y nexos mojados.
   
   Es la búsqueda de `EmisorRayo3D`, pero con tiempo y con alcance.
3. Por el aire no viaja: solo toca lo que haya a **1 casilla** del emisor. Sin conductor, el pulso es corto.
4. Al llegar a un **modificador** cambia (dirección, elemento, alcance). Al llegar a un **receptor** o a un **reactivo**, lo activa.
5. Se ve y se oye:
   - un anillo en el suelo al nacer;
   - cada conductor se ilumina al pasar el frente y se apaga detrás;
   - un tono por elemento que sube al llegar a un receptor.

Ese retraso por casilla es lo que hace legible el circuito: el jugador **ve el camino** que ha recorrido el pulso y dónde se cortó.

## 4. Las cinco familias

A la separación de Pablo (conductores, receptores, modificadores y reactivos) se suma una quinta, **emisores**, sin la que el circuito
no arranca.

| familia | elementos | qué hacen | lo que ya hay y se aprovecha |
|---|---|---|---|
| **Emisores** | cristal latente, pulsador, el jugador (tras el cofre) | sueltan pulsos: solos cada pocos segundos, al pisarlos o al golpearlos | `pulsador`, `emisor` (fuente eléctrica de C5) |
| **Conductores** | vetas minerales, puentes de piedra, agua subterránea, bloques de enlace | llevan el pulso de casilla en casilla | agua (`Terreno3D.conduce`), `NexoRayo3D` (es ya un bloque de enlace: corta seco, conduce mojado), basalto `R` de la lava enfriada |
| **Modificadores** | prisma orientable, cristal resonante, cristal teñido | el prisma gira el pulso 90°; el resonante lo repite con alcance nuevo; el teñido le cambia el elemento | nuevo. El teñido es el que une el pulso con las runas |
| **Receptores** | receptor rúnico, estatuas | reaccionan a un pulso: a cualquiera, a uno de un elemento o a una **secuencia** | `brasero` y `contador` (un brasero ya es un receptor de fuego), `totem`, puertas |
| **Reactivos** | columnas agrietadas, paredes huecas, estalactitas, **setas** | acumulan golpes y caen, responden con eco o sueltan algo | `muro` (`MuroAgrietado3D`: la columna es el mismo código con otro modelo), `seta` (`Recolectable3D`) |

**Setas resonantes.** Una seta que recibe un pulso suelta esporas y **madura**: se recoge una variante mejor (ingrediente común de
más valor). Une el tema con los recolectables que acaban de entrar y premia al que experimenta.

**Estalactitas y cámara cenital.** Desde arriba el techo no se ve. Se cambian por **estalagmitas que vibran** o por una **sombra en el
suelo** que crece antes de que caiga la roca. El aviso tiene que estar en el suelo.

## 5. Sala a sala

El recorrido no cambia (C1 → C2 → C3 → C4 → C5 → C6 → atajo). Cada sala conserva su elemento y gana **un uso del pulso**. Las
marcadas como *principal* son paso obligado; las *opcionales* dan materiales.

| sala | lo de hoy (se queda) | el pulso añade | familia que enseña | |
|---|---|---|---|---|
| **C1 · Boca** | braseros de fuego que abren el paso norte | un **cristal latente** en el centro late cada 3 s; una veta lo une a un grupo de setas que brillan y maduran con cada latido. No hay puzle: se **ve** el pulso antes de que importe | emisor + conductor | principal (enseña) |
| **C2 · Grietas** | muro agrietado de tierra hacia C3 | una veta **cortada** entre un cristal latente y una **columna agrietada** que tapa un nicho. Un hechizo de tierra empuja el **bloque de enlace** al hueco, el pulso llega y la columna cae → cofre **común** | conductor + reactivo | opcional |
| **C3 · Río de lava** | agua para enfriar la lava (10 s) | la lava no conduce, pero el **basalto enfriado sí**: mientras dura, une una veta de un lado con un receptor del otro, que baja una reja a un rincón con un cofre **común**. Contrarreloj doble | conductor temporal | opcional |
| **C4 · Sala cerrada** | dos goblins, cofre con la llave | **cristales resonantes** en las paredes y vetas en el suelo. Golpear un cristal manda un pulso por las vetas: aturde al goblin que esté encima y hace caer las estalagmitas que vibran. El escudo para proyectiles, pero **no lo que viene del suelo** | reactivo en combate | principal (ayuda, no obliga) |
| **C5 · Charca eléctrica** | la fuente electrifica la charca; el hielo la corta y la vuelve suelo | un **receptor sumergido** al fondo: la fuente lo alimenta por el agua y él manda el pulso por una veta que **atraviesa la pared hasta C6**. Si el jugador congela toda la charca para cruzar, el circuito de C6 muere: hay que **dejar un hilo de agua** o derretirlo luego con fuego | conductor (agua) + elección | principal |
| **C6 · Santuario** | puerta con llave, cofre grande, atajo | entra el pulso de C5. Dos o tres **prismas orientables** (se giran con viento o golpeándolos) lo llevan al **receptor rúnico** que hay ante el **cofre legendario**. El cofre se abre (§8). El **atajo** de vuelta a C1 pasa a ser una **pared hueca** que solo responde al pulso propio: primer uso del glifo | modificador + receptor | principal (final) |

**El secreto (épico).** Detrás de una **pared hueca** de C1 hay tres **estatuas**. Piden una secuencia de pulsos de elemento (por
ejemplo fuego, hielo, fuego) y dan el cofre **épico**. Solo se puede hacer con el glifo, así que es la razón para volver al salir por
el atajo, que deja justo en C1. Las estatuas sirven también de lección: el glifo mezcla con las runas.

Con eso salen **siete tipos nuevos de pieza**: cristal latente, veta, bloque de enlace, prisma, receptor, estatua y pared hueca. A eso
se suman dos variantes de las piezas actuales (columna = muro; estalagmita que vibra). Se quedan fuera, para no saturar una mazmorra
de seis salas, el **puente de piedra** (el basalto de C3 hace su papel) y el **cristal teñido** (se guarda para la siguiente
mazmorra, que ya tendrá el glifo).

## 6. Mapa: qué cambia en `Cueva.txt`

Las líneas actuales siguen tal cual. Se añaden letras y líneas nuevas; la gramática es la de `Puzle3D` (`; pieza` / `; puzle`).
Borrador, a validar con `Puzle3D` al montarlo:

```
; pieza latido_c1 cristal 4 14 cada=3
; pieza veta_c1 veta 4 14 celdas=4,14..4,16
; pieza veta_c5 veta 19 15 celdas=19,15..17,15          ← cruza la pared C5/C6
; pieza sumergido receptor 22 15 elemento=rayo
; pieza prisma_a prisma 15 15 dir=n
; pieza prisma_b prisma 15 13 dir=o
; pieza ante_cofre receptor 14 13
; pieza tesoro cofre 13 13 calidad=legendaria oculto_hasta=ante_cofre
; pieza salida pared_hueca 9 16
; puzle abre_tesoro cuando=ante_cofre.activado hace=tesoro.aparecer
; puzle abre_salida cuando=salida.eco hace=atajo.abrir
```

- **Letras nuevas del plano** (propuesta): `v` veta, `k` cristal latente, `p` prisma, `h` pared hueca.
- **Flags**, con la forma de siempre (`nivel.sala.hecho`): `cueva.c6.glifo` al abrir el cofre y `cueva.c1.estatuas` en el secreto.

## 7. Las tres calidades

| | **Común** | **Épico** | **Legendario** |
|---|---|---|---|
| **qué es** | materiales que se consiguen | materiales de **mejora** | **glifos** |
| **color** | gris o blanco | morado | dorado |
| **dónde sale** | setas, jarrones, goblins, cofres pequeños y nichos opcionales | secretos: estatuas, paredes huecas | el cofre del final de la mazmorra: **uno por mazmorra** |
| **contenedor** | cofre pequeño de madera, o suelto en el suelo | cofre mediano de piedra con vetas moradas | cofre grande propio (§8) |
| **qué hace** | ingredientes (cocina, pociones, transformaciones de `Objetos.PLANTAS`) | sube una variable de un glifo que ya se tiene (`resuena`, saltos, fuerza…) | se escribe en el libro: un glifo nuevo para siempre |
| **en la Cueva** | setas roja, azul y marrón; seta madura; esquirla de cristal; mineral de veta | **núcleo de eco** (estatuas) | **glifo de resonancia** |
| **aviso al cogerlo** | `avisar("X (+1)")` de hoy, `logro_brillo` | aviso morado más largo, sonido propio y un destello corto | la animación de §8 |

- **El color manda en todo:** borde del aviso, brillo del cofre, motas de `VfxKit3D` y, si se añade, el icono del inventario.
- **Desde lejos:** un cofre épico o legendario sin abrir echa una **columna de luz** de su color, visible desde la entrada de la sala.

`Estado.agregar(objeto, n)` ya guarda los comunes. Los épicos necesitan un registro mínimo de **mejoras por glifo**, y el legendario
reutiliza el desbloqueo de glifos del libro.

La lista completa de materiales de la Cueva, sala a sala y con lo que hay que dar de alta, está en `MATERIALES_CUEVA.md`.

## 8. El cofre legendario y su animación

**El cofre.** Más grande (unas 1,6 casillas), de piedra oscura con **vetas doradas** que forman parte del circuito de C6. Cuando el
receptor se activa, el pulso sube por las vetas del propio cofre: el jugador ve que el cofre **es** el final del circuito. Hasta
entonces está sellado (sin interacción) y las vetas apagadas.

**La animación (unos 4,5 s, se puede saltar a partir de la segunda vez):**

| s | qué pasa |
|---|---|
| 0,0 | el jugador pulsa E. Se bloquea el control, la cámara se acerca y se baja un poco (`_tam_camara` hacia 4), entran franjas de cine |
| 0,4 | la luz de la zona baja al 40 % (`LuzZona3D`). Solo quedan las vetas doradas del cofre |
| 0,8 | la tapa se abre de golpe y sale un **anillo de pulso** que recorre todas las vetas de la sala a la vez (las de C6 se encienden en onda) |
| 1,4 | el glifo sale girando y sube 1,5 casillas. Crece un **halo** (glow up): emisión de 0 a 4 y bloom alto unos instantes |
| 2,6 | destello blanco corto (0,15 s), el halo se condensa y el glifo cae en el **libro**, que se abre solo |
| 3,2 | el glifo **se dibuja en la página** trazo a trazo (la escritura en el libro es el camino de verdad) y aparece su nombre en dorado |
| 4,5 | vuelve la luz y la cámara, aviso dorado: «Pared hueca: prueba el pulso». La salida (§5, C6) es el primer uso |

El sonido acompaña el ritmo: zumbido grave que sube, golpe al abrir y una nota limpia al escribirse el glifo.

## 9. Legibilidad y presupuesto

- **Pocas cosas, bien leídas.** Siete piezas nuevas en seis salas, y una sola idea por sala (§5).
- **El pulso siempre en el suelo**, nunca a la altura de la cámara. Las vetas son un **decal o una textura** sobre el suelo y las
  paredes, sin geometría propia: el brillo es un parámetro del material que recorre el frente.
- **Coste:** el pulso es una búsqueda por casillas, como la del emisor, y solo pinta las casillas que toca. Sin partículas por casilla:
  un anillo al nacer y uno al llegar a un receptor.
- **Cámara cenital:** nada que se lea desde el techo (§4, estalactitas).

## 10. Decisiones de Pablo (23/10)

1. **Nombre: «pulso».** El glifo nuevo se llama **pulso** y no «resonancia» ni «eco». Por tanto el ᚷ de hoy («pulso», `crece`) pasa a
   llamarse **«crecer»** (solo el nombre: su parámetro y su runa no cambian). Runa del pulso: **ᚱ** (raido, «camino, ritmo»),
   libre desde el 17/10 (`GLIFOS_RECETA.md` §2.1). Confirmada por Pablo el 23/10.
2. **Propiedad**, no geometría: el pulso es algo que se le **transfiere** al hechizo (que resuene). Cualquier volumen puede resonar.
3. **El aire:** sin conductor, el pulso toca **1 casilla**, como en §3. Para usarlo a distancia se combina con otra propiedad: **flecha +
   pulso** lleva el pulso hasta donde choca. No se escribe como caso especial: sale del **momento de ejecución** (§10 bis).
4. **Mejoras épicas = ingredientes para mejorar al personaje** (vida, tinta, pigmentos nuevos, quizá ropa), **no** variables de un
   glifo. Cambia §2 («Mejoras épicas») y la fila «épico» de §7: el núcleo de eco y la geoda son ingredientes de mejora del personaje.
5. **El atajo pide el pulso**, sin pulsador de reserva. Que una situación obligue a usar una habilidad está bien; lo que importa es que
   se **entienda** qué hay que hacer (pared hueca que suena, vetas que llevan a ella, el aviso al coger el glifo).
6. **Cofre legendario: modelo nuevo** (Tripo), más grande, con una **animación de la jugadora abriendo el cofre**, un **primer plano**
   y un **destello de luz más fuerte** que el de §8. Pide un clip «abrir cofre» para la jugadora.

## 10 bis. Momento de ejecución de las propiedades (propuesta de Pablo, 23/10)

**La idea:** cada glifo de propiedad declara **cuándo actúa** en la vida del hechizo:

| momento | cuándo | ejemplos |
|---|---|---|
| **al inicio** | al nacer el volumen, una vez | pulso sin flecha: resuena en el sitio donde nace |
| **continuo** | mientras el volumen vive, cada cierto tiempo | pulso en un muro (barrera): late cada n s mientras dura |
| **al final** | al chocar o al acabarse, una vez | flecha + pulso: el pulso sale donde choca la flecha |

**Por qué encaja:** la receta v2 ya se interpreta en un orden fijo (`GLIFOS_RECETA.md` §2.4) y su paso 3 («vida») es justo una línea
de tiempo: nace → crece → viaja → dura. El momento solo dice en qué punto de esa línea se engancha cada propiedad. Así el orden de los
glifos queda definido por datos y no por el orden en que se dibujan en la página, y se evitan estados indeseados como un pulso que
sale en la mano antes de que el hechizo exista, o dos efectos que se pisan en el mismo fotograma.

**Cómo se propone hacerlo:**
- **Un dato por glifo, con valor por defecto.** El momento es una variable más de la propiedad, en los datos del glifo, como el
  parámetro, el «por glifo» y el tope. El jugador no lo elige a mano: sale de la receta.
- **Regla por defecto para el pulso:** al final si el hechizo viaja (flecha); continuo si el volumen persiste (barrera o elemento
  sólido); al inicio en el resto. Así flecha + pulso es «pulso a distancia» sin escribir el caso.
- **Orden dentro de un mismo momento: fijo**, el de §2.4 (volumen, copias, vida, materia, daño). Nunca el orden de dibujo.
- **Sin reentradas:** un efecto que nace en un momento no vuelve a disparar el mismo momento del hechizo que lo creó (un pulso al final
  no provoca otro final).
- **Sirve para las demás propiedades.** Rebote es «al final» que reinicia la vida, repetición es «al inicio», y los aparcados encajan
  solos: retardo es «antes del inicio» y destello es «al final».

**Riesgo:** el momento continuo multiplica efectos (un muro que late 8 s con pulso de rayo). Necesita un periodo mínimo con nombre y
que cuente en el coste de tinta (§2.5: más propiedades activas = más caro).

## 11. Lo que hay que construir

**Código**
- `Pulso3D`, la señal: nace, avanza por casillas con retraso y alcance, y avisa a lo que toca. Comparte la búsqueda con
  `EmisorRayo3D` (`Terreno3D.conduce`).
- Piezas nuevas de `Puzle3D`:
  - `cristal` (late cada n s o al golpearlo);
  - `veta` (conductor de celdas, se ilumina);
  - `enlace` (bloque empujable; o `NexoRayo3D` ampliado);
  - `prisma` (dir, se gira);
  - `receptor` (elemento opcional);
  - `estatua` (secuencia);
  - `pared_hueca` (eco).
- Variantes: `muro` con modelo de columna, estalagmita que vibra, seta que madura (`Recolectable3D`).
- Propiedad `resuena` en la receta v2, con el contrato de hechizo (`on_spell_hit`) para receptores y reactivos.
- Calidades: campo `calidad` en `cofre`, colores y avisos por calidad, columna de luz, registro de mejoras épicas.
- `CofreLegendario3D` y la secuencia de §8 (cámara, luz, glifo, libro).

**Arte** (se añade a `arte/meshy/PROMPTS_CUEVA.md`)
- cristal resonante (latente y encendido);
- prisma orientable;
- receptor rúnico;
- estatua de piedra;
- cofre legendario;
- cofre épico;
- textura de veta (suelo y pared, con máscara de brillo);
- columna agrietada.

**Pruebas:** ampliar `herramientas/captura_cueva.gd` con el recorrido del pulso (C1 late, C5 → C6 llega, prismas, receptor, cofre,
pared hueca con pulso propio, estatuas) y una prueba de `Pulso3D` sola (alcance, retraso, corte, cambio de elemento).

## 12. Fases

1. **Señal y lectura.** `Pulso3D`, `cristal`, `veta` y `receptor` con arte provisional (primitivas brillantes). C1 y el circuito
   C5 → C6 con un solo receptor. Basta para ver si el pulso se **lee**.
   **HECHA el 23/10** (con los modelos de la hoja D1 ya instalados en vez de primitivas; las primitivas quedan de reserva si falta el modelo):
   - [x] `Pulso3D` (`objetos/pulso_3d.gd`): nace en el emisor, avanza a `SEG_POR_CASILLA` = 0,08 s por las 4 vecinas que conducen, alcance en casillas,
     1 casilla por el aire, sin reentradas, avisa con `on_pulso(pulso)` a los nodos del grupo `pulsable3d`. `COLOR_BASE` = #9ED9FF; con elemento, el color de su runa.
     La búsqueda es la de la fuente eléctrica: `EmisorRayo3D.ola` (con distancia y alcance; `agua_conectada` ahora la usa). Conduce `Terreno3D.conduce` (agua, bajo
     puente, nexo mojado) más las vetas. Se ve: anillo al nacer, losa que se apaga en el agua, veta que se enciende casilla a casilla; suena `sello_ok` (provisional).
   - [x] `cristal` (`CristalPulso3D`): late cada `cada` s (3) o al golpearlo con un hechizo (pulso del elemento del hechizo). Modelo `cristal_resonante`.
   - [x] `veta` (`VetaPulso3D`): losa por casilla con `veta_mineral.png` × máscara `veta_mineral_mascara.png`; el brillo es máscara × color del pulso por emisión.
     Añade un **hilo guía** entre casillas vecinas (no sale de la textura: sin él la red de grietas al azar no se lee como camino).
   - [x] `receptor` (`ReceptorPulso3D`): se activa con un pulso (del `elemento`, si lo pide), pone `flag=` (`nivel.sala.hecho`), `rearme=<s>`. Modelo `receptor_runico`.
   - [x] Cristal turquesa: `BrilloPulso3D` cambia el material por uno propio que lee la misma textura, baja saturación y valor al cian en reposo (`SAT_REPOSO`, `OSCURECER_REPOSO`) y
     pone la emisión del pulso solo ahí. Sin tocar `ocluso_3d.gd`.
   - [x] Puzle3D: piezas `cristal`, `veta`, `receptor`; señales `late` y `activado`/`apagado`; condición `receptor.activo|libre`; acciones `cristal.latir`,
     `receptor.activar|apagar` y `emisor.pulso(alcance)` (la fuente suelta un pulso de rayo por el agua).
   - [x] Cueva: C1 con `latido_c1` (6,15) y `veta_c1` (6 casillas, hasta junto a los braseros y las setas); C5 → C6 con la regla `c5_pulso` (cada descarga de la fuente suelta
     un pulso de rayo, alcance 24), `veta_c5` (8 casillas desde la orilla, bajo la puerta, hasta el receptor) y `ante_cofre` (14,13, flag `cueva.c6.pulso`).
     **Diferencia con §5/§6:** no hay receptor sumergido ni relé: la propia fuente emite el pulso por el agua y la veta sale de la charca. El receptor es uno, en C6. Congelar la
     charca corta el circuito (comprobado).
   - [x] Pruebas: `prueba_pulso.gd` (señal sola), `escenario_cueva_pulso.gd` (C1 late, C5 → C6 llega, hielo corta) y `captura_pulso.gd` (con ventana, `docs/capturas/pulso_fase1/`).
   - [ ] Lo que NO está en la fase 1 (va en las siguientes): prismas, bloque de enlace, basalto y puente de piedra como conductores, reactivos (`on_pulso` en columnas, setas,
     estatuas), sonido propio, glifo del jugador.
2. **Final.** Prismas, cofre legendario con su animación, glifo en la receta, pared hueca de salida.
   **HECHA el 23/10** (`escenario_cueva_pulso.gd` y `prueba_pulso.gd` a 0; capturas con ventana en `docs/capturas/pulso_fase2/`):
   - [x] **Glifo ᚱ «pulso»** (id `raido`, parámetro `resuena`, +4 casillas por glifo, tope 12 = `Pulso3D.ALCANCE_DEFECTO`): `Sigils.GLIFOS` / `GLIFOS_V2`, `GestureLibrary.SIGILS`, PNG `raido.png`, campo `Hechizo.resuena`
     (propiedad que encarece +25 %). El pulso del jugador es la misma señal `Pulso3D.emitir` con el elemento de la receta (sin elemento, el azul claro base) y con el marcador `del_jugador`.
   - [x] **ᚷ → «crecer»**: solo cambia lo que ve el jugador (`Sigils.NOMBRE_VISIBLE`: chuleta del libro, paleta, «se parece a…»). El id `pulso`, las muestras grabadas, el PNG, el parámetro `crece`, la runa y el efecto
     quedan igual (las pruebas de crecer siguen verdes). **Diferencia con lo pedido:** el id interno de ᚱ no es `pulso` sino `raido` (`pulso` sigue siendo el id de ᚷ: renombrarlo rompería las muestras de Pablo y las pruebas).
   - [x] **Momento de ejecución (§10 bis)** como mecanismo general de la receta v2 (detalle en `GLIFOS_RECETA.md` §2.4 bis): dato `momento` / `momento_si` / `paso` / `accion` por glifo en `Sigils.GLIFOS`,
     `Hechizo.momento_de` y `Hechizo.acciones_en` (orden fijo), ejecución en `HechizoVivo` (`_arrancar_momentos`, `_momento`, `_terminar`). ᚱ: **final** si viaja, **continuo** si el volumen se queda (barrera, permanencia, sólido), **inicio**
     en el resto (el haz incluido). Continuo: periodo mínimo `Sigils.PERIODO_MIN_CONTINUO_S` (1,5 s), tope `MAX_DISPAROS_CONTINUOS` (8), recargo de tinta `COSTE_CONTINUO_V2` (+25 %). Sin reentradas: inicio y final una vez, y un hijo (`crear_hijo`) no repite
     los efectos de su padre. Flecha, barrera, repetición, rebote, crecer y permanencia llevan su `momento` como descripción, sin `accion`: no cambian lo que hacen.
   - [x] **Prisma** (`PrismaPulso3D`, pieza `prisma`, `dir=n|e|s|o`): reemite el pulso por la casilla que mira (mismo elemento, mismo dueño, alcance restante; no vuelve por donde vino; `Pulso3D.linaje` impide que dos prismas se lo pasen para siempre).
     Se gira 90° en sentido horario con un golpe de hechizo (cualquier elemento) o con E; un puntero luminoso en el suelo marca la salida. **En la Cueva hay UNO** (`prisma_c6`, 15,16): lleva el pulso de C5 al receptor (mirando al norte) o,
     girado al oeste, por la veta que va a la pared hueca. No se han puesto 2–3 como decía §5 para no rehacer C6.
   - [x] **Pared hueca** (`ParedHuecaPulso3D`, pieza `pared_hueca`, `flag=`): un trozo del kit `cueva_pared` que hace ECO con cualquier pulso (anillo, destello azul, dos notas graves) y SE ABRE solo con el pulso del jugador. Sustituye al atajo
     (`atajo` + `boton`): sin pulsador de reserva. Vetas que llevan hasta ella (`veta_c6_oeste`) y aviso dorado al coger el glifo.
   - [x] **Cofre legendario** (`SecuenciaCofreLegendario3D`, claves `abre_si=` y `glifo=` de la pieza `cofre`): sellado hasta que el receptor está activo; al abrirlo, control bloqueado, cámara en primer plano, luz de zona al 40 %,
     tapa, onda dorada por las vetas, glifo con halo, destello blanco + desenfoque radial + pico de luz, caída a una página que se abre sola, escritura de arriba abajo con su nombre, desbloqueo (`Repertoire.unlock_sigil`, flag `cueva.c6.glifo`),
     aviso dorado «Pared hueca: prueba el pulso». Saltable (E, Espacio, Intro o Esc) desde la segunda vez (flag global `global.cofre.legendario_visto`). **Diferencias con §8:** el glifo sube 1 casilla (no 1,5) y el primer plano es tamaño 4,8 (no 4)
     con un desplazamiento del encuadre hacia el cofre, porque con 4 y 1,5 el glifo se salía de la pantalla; la escritura es un barrido de arriba abajo (el ᚱ aún no tiene muestras grabadas para dibujarlo trazo a trazo) y la página es un panel propio, no el libro real.
     **Falta el clip «abrir cofre» de la jugadora:** se usa `pick_up` (coger un objeto), ver `PENDIENTES.md`.
   - [x] **Cueva iluminada en azul** (encargo de Pablo): emisión de reposo muy baja del azul base en cristales, vetas, receptor y prisma (`BrilloPulso3D.ENERGIA_REPOSO`, `VetaPulso3D.EMISION_REPOSO`) y luces tenues sin sombras
     (`LUZ_REPOSO_ENERGIA` 0,5, `LUZ_REPOSO_ALCANCE`, tope `MAX_LUCES_REPOSO` = 8 vivas a la vez). El destello del pulso queda por encima (luces de 1,6 y emisión de 3,0).
   - [ ] Sigue sin hacerse (fase 3): setas que maduran, estatuas, cofre épico, columnas agrietadas con `on_pulso`, bloque de enlace, sonido propio del pulso, y los otros 1–2 prismas de C5/C6.
3. **Opcionales y calidades.** C2, C3, C4, setas que maduran, estatuas y cofre épico, colores por calidad.
4. **Arte.** Tripo para las piezas de §11 y sustitución de las primitivas.
