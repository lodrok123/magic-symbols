# Enemigos de mitología celta e íbera (22/11/2026)

22/11/2026 · contexto **dirección (combate y diseño)** · **conceptos para que Pablo elija; no hay nada implementado.**

**Origen:** el jefe sombra de Mystralia (O27 en `MAGES_OF_MYSTRALIA_2026-11-21.md`). Pablo: «no quiero este enemigo, sino que prepares conceptos en base a la mitología celta/íbera y propongas enemigos con una filosofía parecida».

## 0. La filosofía que se copia (no el enemigo)

1. **Invulnerable por defecto.** Pegar sin más no sirve.
2. **La arena trae la herramienta** que lo cambia.
3. **Abrir la ventana es manipular el entorno o un elemento**, con lo que ya sabe hacer la jugadora (fuego, agua, tierra, barrera, reflejo), no con un arma nueva.
4. **La ventana se lee y dura poco:** cambio de cuerpo, contorno, aturdido y luego un golpe fuerte con silueta blanca (ya existe, C17).
5. **El enemigo evita esa condición** a propósito: huye de la luz, protege su fuente o deshace lo que construyes.
6. **Mientras es invulnerable, sigue atacando**, con avisos (C18, C22, C25).

Además, cada concepto cumple la regla de **tres soluciones** (C4) y usa **solo fuego, agua y tierra** (la demo). Las variantes de otro elemento quedan para después (D1).

**Ya tenemos de mitología gallega y asturiana:** mouro, Santa Compaña y ánimas, canouro, loberno, gatopedro, Marimanta, el Sumicio y el Ojáncano (concepto). Lo que sigue **no repite** ninguno.

**Sobre los mitos:** el resumen de cada criatura es la tradición tal como se suele contar. Lo que hace en combate es **invención nuestra**, inspirada en ese rasgo. Si un detalle del mito va a decidir algo, conviene contrastarlo antes con una fuente.

---

## 1. El Basilisco (Asturias) · élite de cueva · «devuélvele la mirada»

**El mito:** el *basiliscu* nace de un huevo que pone un gallo viejo y que incuba un sapo o una culebra. **Mata con la mirada.** Para acabar con él, se le pone delante **un espejo**: muere al verse a sí mismo.

**En combate:**
- **Invulnerable:** su cuerpo de escamas no recibe daño.
- **Ataque:** **la mirada es un haz**, que barre en línea y se corta en lo sólido (el mismo sistema que el aliento del dragón y la tabla de contacto C19). Lo que toca queda **«petrificado»**: más lento unos segundos (el estado `lento`, que ya existe).
- **La ventana:** si la mirada da en una **protección de agua** de la jugadora, **se refleja** hacia donde ella mira (la misma regla que el puzle X10). Si el reflejo le da a él, **se petrifica a sí mismo** unos 3 s: gris, quieto y vulnerable. Un golpe F lo agrieta (×2, como lo congelado).
- **Evita la condición:** antes de mirar, **gira buscando un ángulo** donde la jugadora no tenga su protección entre los dos, y la mirada tiene anticipación (C25): pose y ojos que se encienden.
- **Tres soluciones:**
  1. reflejar la mirada con la protección de agua;
  2. reflejarla con un **prisma** de la sala (el del pulso, que ya existe) girado hacia él;
  3. **taparle la vista** con una barrera de tierra y pegarle por detrás mientras rodea el muro.

**Qué reutiliza:** el haz con corte (dragón), la tabla de contacto (B2), el reflejo (X10), el prisma, `lento` y la anticipación (A5).
**Coste:** M, si X10 está hecho.
**Dónde:** Cuevas, junto a la familia de puzles de luz: aprende el reflejo en el puzle y lo usa en el combate.

---

## 2. El Verraco (vetones, Iberia) · élite de ruinas o bosque · «que se rompa contra la piedra»

**El mito:** los *verracos* son esculturas de granito de **toros y jabalíes** que dejaron los vetones en la Edad del Hierro, en tierras de Ávila y Salamanca; los Toros de Guisando son los más conocidos. Se cree que guardaban ganado, pastos o lindes. Que **despierten** es invención nuestra.

**En combate:**
- **Invulnerable:** es granito. Los hechizos rebotan con un golpe sordo (el feedback de «ineficaz», C20).
- **Ataque:** cuando la jugadora cruza su línea de vista, **embiste en línea recta** hasta chocar con algo. Avisa con la pose de pezuña y cabeza baja (C25) y una línea en el suelo.
- **La ventana:** si **choca contra algo sólido** (una pared, una columna o una **barrera de tierra** de la jugadora), **se agrieta** y queda aturdido unos 2 s. Con tres grietas, se parte y enseña el **núcleo** (el patrón del gólem y del dragón).
- **Evita la condición:** **frena** si ve una barrera recién puesta en su línea. Hay que levantarla **cuando ya ha arrancado** (tiempo de lanzar de la tierra: 0,70 s, C18). Eso convierte la barrera en una decisión de reflejos.
- **Tres soluciones:**
  1. barrera de tierra en su camino;
  2. ponerse delante de una columna y esquivar en el último momento (voltereta perfecta, ventana de 0,25 s);
  3. **mojar el suelo** de su carril (agua) para que **patine** y se estrelle más lejos de lo que calculaba (el `patinar`, que ya existe).

**Qué reutiliza:** el gólem (inmune de pie y núcleo), el **daño contra pared (C11)**, que aquí sería su razón de ser, la barrera de tierra, `patinar` y el golpe sordo.
**Coste:** M (C11 hay que hacerlo).
**Dónde:** Ruinas, con la tierra recién ganada: es el examen del sello de tierra.

---

## 3. El Cuélebre (Asturias y Cantabria) · jefe de pantano · «tápale la fuente»

**El mito:** el *cuélebre* es una **serpiente alada** que vive en cuevas y **fuentes**, guarda tesoros y a las xanas encantadas, y tiene **escamas impenetrables**. Según algunas versiones, la noche de San Juan duerme o es vulnerable, y de viejo se va al mar.

**En combate:**
- **Invulnerable:** mientras está **enroscado en su manantial**, se cura y nada le hace daño.
- **Ataques:**
  - chorros de agua a presión que **empujan**: una variante de la trampa dragón (X8, D1);
  - **coletazos** con anticipación.
  - Con cada fase **inunda** más la arena (agua honda, que mata a los enemigos que caen y a ella la obliga a rodear).
- **La ventana:** hay que **tapar el manantial**: un bloque de tierra (ᛒ o barrera de tierra) sobre la boca, como tapar la mámoa del mouro. Sin fuente, **sale a buscar otra** y, al arrastrarse fuera, **enseña el vientre**, la única parte blanda, unos 4 s.
- **Evita la condición:** **escupe agua** sobre los bloques de tierra para deshacerlos (tierra + agua = barro, que se cae). Hay que taparlo **cuando está atacando** y no mira, o tapar dos fuentes seguidas.
- **Tres soluciones:**
  1. tapar con un bloque de tierra;
  2. **secar** la fuente con fuego sostenido: vapor (agua + fuego), más lento pero que no puede deshacer;
  3. romper una presa de la sala para que el agua se vaya por otro sitio (pieza de mapa).

**Qué reutiliza:** la mámoa del mouro (fuente que se tapa), agua honda, estados del suelo, la trampa dragón de agua (variante D1), la presentación de jefe y las fases.
**Coste:** A (jefe).
**Dónde:** Pantano. Encaja con la decisión del Ojáncano: el examen del agua y la tierra juntos.

---

## 4. El Trasgu o Trasno (Asturias y Galicia) · élite de puzle · «atrápalo»

**El mito:** el *trasgu* o *trasno* es un **duende de la casa**, travieso, que cambia las cosas de sitio, hace ruido y desordena. Para librarse de él se le encarga algo **imposible**: recoger del suelo un saco de mijo derramado, llevar agua en un cesto o blanquear una piel negra.

**En combate:** casi no hace daño. Es un **saboteador**.
- **Invulnerable e intocable:** es rapidísimo y **se teletransporta** entre sitios de la sala cuando le apuntas, con un aviso de humo.
- **Ataque:** **deshace el puzle**. Apaga braseros, gira prismas, empuja bloques y abre y cierra compuertas. Lo hace con un aviso: se le ve ir hacia la pieza (C18).
- **La ventana:** **encerrarlo**. Si queda rodeado (barreras de tierra, un corral de suelo con ᛒ + ᛇ + ᛃ (H11), el borde de agua honda o un círculo de suelo quemado que no cruza), **no puede saltar** y se le puede golpear. A los 3 golpes, se rinde y se va.
- **Evita la condición:** salta **antes** de que se cierre el cerco, así que hay que cerrar el último lado de golpe.
- **El guiño al mito:** si en la sala hay un **saco de mijo**, el trasgu se distrae recogiendo granos uno a uno (una tarea imposible), y queda quieto unos segundos. Es una solución opcional y divertida.
- **Tres soluciones:**
  1. corral de barreras de tierra;
  2. círculo de fuego en el suelo;
  3. el saco de mijo.

**Qué reutiliza:** las piezas de puzle que ya existen (braseros, prismas, bloques), las barreras y su tope de 3, el suelo quemado y la IA que rodea barreras (aquí al revés: las teme).
**Coste:** M. Lo caro es la IA de «ir a deshacer».
**Dónde:** dentro de una sala de puzle. Es muy buen **encuentro de reto opcional** (C24, salas élite).

---

## 5. El Nubeiro o Nuberu (Galicia y Asturias) · jefe o élite al aire libre · «tócale las campanas»

**El mito:** el *nubeiro* (o *nuberu*) es el **señor de las nubes y la tormenta**: trae el granizo que destroza las cosechas y vive en las nubes. En los pueblos se **«tocaba a nube»**: se repicaban las campanas para espantar la tormenta.

**En combate:**
- **Invulnerable:** está **en su nube**, fuera de alcance. En el suelo solo se ve **la sombra de la nube** (aviso), que persigue a la jugadora.
- **Ataques:** donde está la sombra, **lluvia** (moja el suelo) y luego **granizo** (golpes de área con aviso en el suelo, C18). La lluvia convierte el suelo quemado en mojado y apaga braseros: deshace lo que hagas.
- **La ventana:** en la arena hay **campanas** (receptores que se activan de un golpe de hechizo). Al **tocar tres campanas seguidas** antes de que se apague el temporizador (P8), la nube se deshace y el Nubeiro **cae al suelo aturdido** unos 5 s.
- **Evita la condición:** pone su sombra **encima de la campana** que vas a tocar y la moja (una campana mojada no suena). Hay que **secarla con fuego** primero o tocarla desde lejos con una flecha.
- **Tres soluciones:**
  1. flechas a las campanas desde lejos;
  2. **vapor:** fuego en el suelo mojado bajo la nube para que pese y baje (reacción que ya existe);
  3. atraer la sombra a un sitio con techo, donde no llueve, y tocar las campanas libres.

**Qué reutiliza:** receptores, el temporizador común (P8), los estados del suelo (mojado y quemado), los avisos de área, la presentación de jefe y las variantes con rayo para después (D1).
**Coste:** M–A.
**Dónde:** Monte o Bosque exterior. La sombra móvil es muy legible con la cámara fija.

---

## 6. Resumen para elegir

| Concepto | Mito | Cómo se abre la ventana | Elemento clave | Tipo | Coste | Depende de |
|---|---|---|---|---|---|---|
| **Basilisco** | Asturias | Devolverle la mirada | Agua (reflejo) | Élite, cueva | M | X10 |
| **Verraco** | Vetones (Iberia) | Que choque contra la piedra | Tierra (barrera) | Élite, ruinas | M | C11 |
| **Cuélebre** | Asturias y Cantabria | Tapar o secar su fuente | Tierra y fuego | Jefe, pantano | A | Fases de jefe, D1 |
| **Trasgu** | Asturias y Galicia | Encerrarlo | Tierra y fuego | Élite de puzle | M | H11 opcional |
| **Nubeiro** | Galicia y Asturias | Tocar las campanas | Fuego y flecha | Jefe o élite, exterior | M–A | P8 |

**Mi recomendación para empezar:**
- **el Verraco**, porque es barato, enseña la tierra y hace que C11 tenga sentido;
- **el Basilisco**, porque ata el combate a la familia de puzles de luz.

Los dos son élites, no jefes.

**Descartado a propósito:** el *Gaueko* (espíritu vasco de la noche, que no soporta la luz). Sería la traducción directa del jefe sombra de Mystralia, y Pablo no quiere ese enemigo.
