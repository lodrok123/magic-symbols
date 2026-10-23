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
- **Conflicto de nombre:** ᚷ ya es «pulso» en la v2 (`crece`: el volumen nace pequeño y crece). O se renombra ᚷ («crecer») o el
  glifo nuevo se llama «resonancia» o «eco». Lo decide Pablo (§10).

**Mejoras épicas** (§7): suben las variables del glifo, no añaden glifos:
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

## 10. Decisiones para Pablo

1. **Nombre y símbolo del glifo.** ¿Se renombra ᚷ («crecer») y el nuevo se queda «pulso», o el nuevo se llama «resonancia» o «eco»?
   ¿Qué runa le toca?
2. **¿Propiedad o geometría?** Se propone propiedad (§2): resuena cualquier volumen. La otra opción es una geometría «anillo» que se
   expande, más vistosa pero que no combina con muro, haz y demás.
3. **El aire:** ¿el pulso toca solo a 1 casilla sin conductor (§3), o se permite un radio pequeño libre para que el glifo sirva fuera
   de las cuevas?
4. **Mejoras épicas:** ¿suben variables de un glifo concreto (lo propuesto) o son un recurso común que se gasta en cualquier glifo?
5. **El atajo:** ¿la salida de C6 pasa a pedir el pulso (lo propuesto) o se deja también el pulsador, para no encerrar a quien no
   entienda el glifo a la primera?
6. **¿El cofre legendario es un modelo nuevo** (Tripo) o el cofre grande actual con vetas y un material propio?

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
2. **Final.** Prismas, cofre legendario con su animación, glifo en la receta, pared hueca de salida.
3. **Opcionales y calidades.** C2, C3, C4, setas que maduran, estatuas y cofre épico, colores por calidad.
4. **Arte.** Tripo para las piezas de §11 y sustitución de las primitivas.
