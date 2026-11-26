# Mages of Mystralia: análisis a fondo y qué aprovechar (21/11/2026)

21/11/2026 · contexto **dirección (análisis)** · **análisis para decidir, nada construido**. Amplía la fila de *Mages of Mystralia* de `REFERENCIAS_JUEGOS_2026-11-21.md` §2.1.

**Qué es.** Aventura de acción en 3D con vista cenital, tipo Zelda, de Borealys Games (Canadá). Salió en PC en mayo de 2017 y en Switch en 2019. Su protagonista, Zia, es una maga desterrada. El guion es de Ed Greenwood. Tiene secuela anunciada en 2024, *Echoes of Mystralia*. Metacritic: entre 69 y 78 según la plataforma, críticas «mixtas o medias». **Todas las reseñas coinciden: lo mejor es el sistema de crear hechizos y los puzles; lo flojo, el combate.**

**Fuentes y fiabilidad.** Al final está la lista de URL. Lo más fiable es el artículo del director de juego, Patric Mondou (2016), y su entrevista de 2019. Las reglas de cómo se enlazan las runas salen de una respuesta del propio equipo en el foro de Steam. La wiki de fans, el análisis de GameSpot y la guía completa de Steam no se pudieron leer, así que **la lista de runas está incompleta** y lo que no está confirmado lo marco como *(sin confirmar)*.

---

## 1. Cómo funciona su sistema de hechizos

### 1.1 Cuatro hechizos base

Todo hechizo parte de uno de cuatro moldes:

| Base | Qué hace | Equivalente aproximado nuestro |
|---|---|---|
| **Immedi** | Golpe cercano (es su ataque cuerpo a cuerpo) | Golpe F, pero el suyo tiene elemento |
| **Actus** | Crea una bola que se queda un rato en el sitio | Bola sin ᛇ flecha |
| **Creo** | Conjurar (crear cosas en el mundo) | Barrera ᛝ, bloque de tierra |
| **Ego** | Actúa sobre la propia Zia | **No lo tenemos** |

El **elemento no se dibuja**: cada molde tiene una variante de elemento que cambia con el avance (el golpe empieza eléctrico y luego puede ser de hielo; la bola de fuego luego puede ser una esfera de rayo). Hay tribus de goblins que resisten ciertos elementos.

### 1.2 Tres clases de runa

| Clase | Qué hace | Ejemplos confirmados |
|---|---|---|
| **Comportamiento** | Añade una conducta **al hechizo entero** | **Mover**: la bola sale como proyectil; en Ego, Zia **hace un dash** en vez de un escudo. **Buscar** (*homing*). **Duplicar**: multidisparo. **Rebotar** en paredes. **Maestría** (añade efecto del elemento al dañar, *sin confirmar*). **Tiempo** (acelera si va pegada a Mover, según un jugador). |
| **Aumento** | Modifica **solo la runa a la que va pegada**, en el orden en que se pegó | **Izquierda, Derecha, Inversa**. La inversa en un proyectil dispara hacia atrás, y sirve para disparar huyendo. |
| **Disparador** | Cuando pasa algo, **lanza otro hechizo ya guardado** | Al impactar, al terminar, cada cierto tiempo (periódico), al lanzar |

Lo importante del aumento lo explicó el equipo en el foro: **«Actus + Derecha + Mover»** dispara una bola a la derecha de Zia, y **«Actus + Mover + Derecha»** dispara una bola que **curva** a la derecha. Es decir, **el mismo par de runas hace cosas distintas según a qué esté enganchado**. Lo nuestro más parecido es `ORDEN_PARES` (ᛇ antes de ᚠ = ráfaga).

### 1.3 El editor

Es un grafo: un nodo central (el molde) y runas enganchadas alrededor, con estética de constelaciones. **El disparador no lleva dentro un hechizo nuevo: apunta a otro hechizo que ya tienes guardado.** Así se anidan (la wiki habla de un tope de 4 disparadores por cadena, *sin confirmar*). Los jugadores **pausaban el combate** para retocar runas. Cada runa añadida sube el coste de maná; según la wiki, los aumentos no lo suben *(sin confirmar)*.

### 1.4 Cómo se consiguen las runas

- **Una runa cada vez.** El director quería que se aprendieran «una a una».
- **Las runas se ganan en salas de puzle**, casi siempre encendiendo antorchas contra reloj. Para cada sala hay que construir un hechizo concreto.
- **Pistas de pago** junto a cada sala: dicen **qué runas hacen falta**, no la solución.
- **Puertas de constelación**: un puzle aparte en rejilla hexagonal que da esferas para subir vida y maná.
- **Vuelta atrás**: con runas nuevas se abren caminos viejos (interruptores de viento, barreras que se detonan).

---

## 2. La historia de su diseño (lo más valioso)

Del artículo de Mondou (2016). Es un mapa de errores que nos podemos ahorrar:

1. **Prototipo de flujo de nodos.** El jugador programaba la secuencia y los datos pasaban de nodo en nodo. Resultado: «demasiado complejo».
2. **Pila de comportamientos (verano de 2015).** Quitaron toda la secuencia; cada runa colgaba del centro. Era limitado pero **mucho más accesible y divertido** en las pruebas. Ejemplo: añadir «movimiento» ya implicaba proyectil, **la forma salía de la runa**, como en nuestro juego.
3. **Los socios lo vieron flojo.** Se había quedado «casi en un sistema de personalización».
4. **Plantillas (PAX East 2016).** Tres moldes que se rellenaban; quitaron «canalizado» y «sostenido» y añadieron «sobre uno mismo». **Ese último acabó lleno de combinaciones escritas a mano, «y no nos gustó».**
5. **Disparadores y anidado (finales de 2016), inspirados en *Transistor*.** Añadieron cuatro disparadores, quitaron «explotar al contacto» por redundante y **bajaron de 20 a 11 runas de comportamiento. El sistema «seguía pareciendo diez veces más profundo».**
6. **Duración.** Apuntaban a 10 horas y en las pruebas salían 15 o más, **porque los jugadores se quedaban experimentando**.

**Lección:** la profundidad no sale de tener más piezas. **Sale de que las piezas se compongan.** Y cuando escribieron combinaciones a mano, se arrepintieron: es nuestro pilar «las combinaciones emergen», confirmado desde fuera.

---

## 3. Qué falló (y nos afecta de lleno)

Las críticas al combate son **casi las mismas que salieron en nuestro playtest del 14/11**:

| Su problema | Quién lo dice | ¿Nos pasa? |
|---|---|---|
| **Hechizo a distancia desde el principio, así que la dificultad se resolvió con enemigos «esponja» (mucha vida)** | Nintendo Life | **Sí: «todo con fuego + flecha».** Es el aviso más importante: **no arreglarlo subiendo vidas**. |
| IA simple, poca variedad real de enemigos | Nintendo Life | Diagnóstico §0.5 y §0.7 de PROPUESTAS_COMBATE. |
| Poco feedback al chocar; sin números de vida ni de daño, todo a prueba y error | Nintendo Life | Nosotros sí tenemos rótulos y barra. Bien. |
| **No se nota la diferencia entre dos combinaciones** («como un puzle de piezas sin lectura») | Nintendo Life | Riesgo real con 14 glifos. Tenemos `diferencia()` y `texto_cambio`, que van por delante. |
| **Las reglas de enlace parecen incoherentes** | Un jugador en el foro de Steam | Riesgo con `ORDEN_PARES`: el orden de dibujo es invisible. |
| **Puzles de solución demasiado concreta**: «un hechizo que debería funcionar y no funciona» | Hardcore Gamer | Revisar en los puzles con glifos. |
| Todo gasta maná y se vacía rápido | Hardcore Gamer, Nintendo Life | Lo contrario a nosotros (sobra tinta). Hay un punto medio. |
| Congelar a la jugadora unos segundos; recuperación lenta tras golpe que deja encadenarla | Nintendo Life, Hardcore Gamer | Evitar aturdimientos largos sobre la jugadora. |
| Pocos puntos de viaje rápido, mucha vuelta atrás para encontrar runas | Game Informer, Nintendo Life | Tenerlo en cuenta en la mazmorra de glifos. |

**Lo que sí funcionó en combate:** los jefes («no se ganan aporreando botones») y un caso concreto que el director cuenta con orgullo, la **gárgola de la Cripta**. Querían enemigos que «no fueran solo sacos de vida», y los jugadores encontraron **tres soluciones**: la prevista (un señuelo), una bola quieta usada como mina y una bola con aumento inverso que sale por la espalda. De ahí sacaron su regla: **los momentos memorables salen de enemigos con varias soluciones abiertas**.

---

## 4. Comparación con Magic Symbols

| Aspecto | Mystralia | Magic Symbols | Quién va por delante |
|---|---|---|---|
| Entrada | Menú de grafo, se monta con calma | Se dibuja a mano en el libro, tiempo al 30 % | Nosotros (más identidad), ellos (más fácil) |
| La forma sale de las piezas | Sí desde la versión 2 | Sí (`Hechizo._derivar`) | Igual |
| Molde base | 4 moldes explícitos | Sin molde: la forma emerge de los glifos | Nosotros (más emergente) |
| Elemento | Variante del molde, no se elige libre | Sello que se dibuja | Nosotros |
| Orden importa | Explícito: enganchas el aumento a una runa | Implícito: orden de dibujo (`ORDEN_PARES`) | Ellos en legibilidad |
| Anidado | Disparador que lanza **otro hechizo guardado** | `al_golpear` + `crear_hijo` existen, sin glifo que los use para lanzar otra página | **Ellos** |
| Hechizos sobre sí misma | Ego: escudo, y con Mover, dash | No hay | **Ellos** |
| Mundo que reacciona | Antorchas, interruptores, barreras | Estados del suelo, materia, reacciones | Nosotros, de lejos |
| Explicar cambios | Sin lectura | `diferencia()` y texto por glifo | Nosotros |
| Progresión | Una runa por sala de puzle; vuelta atrás | Glifos en cofres legendarios; la mazmorra está por diseñar | Ellos (lo tienen resuelto) |

---

## 5. Qué aprovechar

Ordenado por lo que aporta y respetando el marco de la demo (fuego, agua y tierra; «solo entra lo que da opciones»).

### A. Disparador que lanza otra página *(lo más valioso)*
**Qué:** un glifo disparador nuevo (⧖ `retardo` ya no está libre: hoy se ve como «carga») que, al impactar o al acabar, **lanza el hechizo de otra página del libro**. Por ejemplo, la página 1 es una flecha de agua con disparador «al impactar → página 2», y la página 2 es una barrera de tierra. Resultado: la flecha llega y levanta un muro donde cae.
**Por qué:** es justo lo que llevó su sistema de «personalización» a «diez veces más profundo» sin añadir piezas. Además **reutiliza las páginas**, que ya existen: no hay que guardar hechizos aparte.
**Encaje:** mejora la C3 de PROPUESTAS_COMBATE (que proponía un hijo fijo). Los eventos `al_golpear` y `crear_hijo` de `Hechizo` ya existen.
**Límites que yo pondría:** un solo nivel de anidado en la demo (una página no puede llamar a otra que a su vez llame a otra), y se cobra la tinta de las dos.

### B. Hechizos sobre sí misma (su «Ego»)
**Qué:** una forma de lanzar la página **sobre la jugadora** en lugar de hacia delante. Con ᛇ flecha, un **dash** del elemento; con ᛝ barrera, un **escudo** del elemento; con ᚱ pulso, una onda alrededor (sola, la barrera ya rodea a la jugadora, según el comentario de `Sigils.GLIFOS`: es medio camino andado).
**Por qué:** responde al «pocas acciones» del playtest **sin botones nuevos**: la jugadora se monta su propia defensa y movilidad. En Mystralia, Mover en Ego = dash es de lo más citado.
**Aviso de su historia:** su categoría «sobre uno mismo» acabó llena de casos escritos a mano y no les gustó. Si se hace, que salga de las mismas reglas de derivación y no de una tabla aparte.
**Pregunta abierta:** cómo se marca «sobre mí» al dibujar: ¿un glifo propio, dibujar en un sitio del libro, o una tecla al lanzar?

### C. Enemigos con varias soluciones (la gárgola)
**Qué:** diseñar cada enemigo nuevo pensando **tres formas de vencerlo con los glifos que ya hay**. Ejemplo con fuego, agua y tierra: un goblin con escudo frontal se vence con rebote en la pared, con una bola con ᛉ permanencia dejada como mina en su camino o con ᛃ retorno, que le da por la espalda al volver.
**Por qué:** es lo que salvó su combate y el antídoto contra las «esponjas». Encaja con los escudos de elemento propuestos en `REFERENCIAS_JUEGOS` §4.
**Regla práctica:** si solo hay una solución, es un puzle; si hay tres, es combate.

### D. Recortar el catálogo de glifos para la demo
**Qué:** revisar los 14 glifos y quedarse con los que **cambian algo que se ve y se juega**. Ellos bajaron de 20 a 11 y el sistema ganó profundidad.
**Por qué:** el GDD ya dice que varios glifos no cumplen lo que prometen (repetición con flecha, `crecer`…). Menos glifos también es menos VFX que acabar, lo mismo que se buscó al recortar elementos el 18/11.
**Cómo medirlo:** una prueba que construya cada pareja de glifos con fuego, agua y tierra y avise cuando dos combinaciones dan el mismo `Hechizo`. Si dos glifos no se distinguen, uno sobra. Es justo la queja de Nintendo Life convertida en prueba.

### E. Hacer visible el orden
**Qué:** cuando el orden de dibujo cambia el hechizo (ᛇ antes de ᚠ = ráfaga), el libro lo enseña: una flecha entre los dos glifos o el nombre del efecto («ráfaga») junto al par.
**Por qué:** en Mystralia el orden era explícito y aun así un jugador lo vio «incoherente». En lo nuestro el orden es invisible. `ORDEN_PARES` ya apunta a qué glifo atribuirlo, así que el dato está.

### F. Una sala de glifo, un glifo (progresión)
**Qué:** para la mazmorra de glifos que tienes pendiente, copiar su estructura: cada glifo se gana en **una sala de puzle que solo se resuelve usándolo**, y luego abre caminos viejos.
**Extra útil:** su **pista de pago** dice qué piezas hacen falta, no la solución. Barato y respeta al jugador que quiere pensar.
**Lo que evitar:** soluciones demasiado concretas. Probar cada sala con al menos dos recetas distintas.

### G. Coste: forma barata, potencia cara
**Qué:** si sus aumentos de dirección no cuestan maná *(sin confirmar)* y los comportamientos sí, la regla para la tinta (A3 de PROPUESTAS_COMBATE) puede ser que **los glifos que cambian forma o dirección cuesten poco y los que multiplican (ᚠ repetición, ᛉ permanencia, copias) cuesten mucho**.
**Ya va por ahí en parte:** en `Sigils.GLIFOS` (`nucleo/sigils.gd`) ᛃ retorno, ᚨ buscar y ⧖ carga cuestan 0 de tinta por glifo, y barrera y ᚱ pulso cuestan 4. Lo que falta es lo del diagnóstico §0.6: el recargo por copias y permanencia está a 0 en `dano.gd`. Antes de tocar nada, comprobar qué se cobra de verdad al lanzar.
**Por qué:** su «todo gasta y se vacía» fue criticado, y lo nuestro (tinta que sobra) tampoco tensa. Esta regla castiga el spam de potencia y deja experimentar con la forma.

### H. Lo que **no** copiar
- Subir la vida de los enemigos para compensar el ataque a distancia.
- Aturdir o congelar a la jugadora varios segundos.
- Un editor de menú en lugar del dibujo: dibujar es la identidad del juego.
- Una categoría de hechizos con combinaciones escritas a mano.

---

## 6. Para jugarlo tú

Ficha para rellenar jugando: `FICHA_ESTUDIO_MYSTRALIA.md`. Su secuela, *Echoes of Mystralia* (2026), está analizada en `ECHOES_OF_MYSTRALIA_2026-11-21.md`.

Si lo pruebas (unas 6–10 horas; está en Steam, GOG, Epic y consolas), lo que más merece la pena mirar:
1. **La primera hora**: cómo enseña una runa cada vez.
2. **La Cripta** (tercera mazmorra) y su gárgola.
3. **Mover sobre Ego** (el dash) y los disparadores: es lo que nos falta.
4. El combate contra goblins normales: para ver el problema de las esponjas en carne propia.

## 6 bis. Observado jugando (Pablo, 21/11/2026)

### O1 · Presentación de cada objeto nuevo
**Qué hace Mystralia:** al conseguir algo importante (por ejemplo, el «Libro de conjuros»), la pantalla se oscurece y aparece una lámina: «Nuevo objeto», el objeto grande en el centro, su nombre en letras grandes y **una frase de la protagonista** que da una pista de para qué sirve. (Captura de Pablo.)
**Lo que tenemos:** al inscribir un glifo de cofre legendario, `CeremoniaCofre3D` (`objetos/ceremonia_cofre_3d.gd:421`) solo enseña el texto «Runa inscrita: <nombre>» con `AvisoObjeto.mostrar_texto`. No explica para qué sirve.
**Propuesta (Pablo):** cuando entra un **glifo o sello nuevo**, una página que explique **un poco su uso**: el glifo grande, su nombre y una o dos frases de qué hace, y a ser posible una pequeña animación del efecto. Ayuda a entender sin tutoriales largos y encaja con el «una runa cada vez» de Mystralia (§1.4).
**Encaje:** el texto puede salir de lo que ya enseña el libro al añadir un glifo (`Hechizo.diferencia()` / `texto_cambio`), para no escribirlo dos veces. Es trabajo de la ceremonia (Juego) y de la lámina (Pipeline).

### O2 · Puzle: plataforma móvil, chorro y escudo
**Qué hace Mystralia:** una plataforma de piedra se desplaza junto a un muro; una cara de piedra del muro escupe un chorro continuo (parece viento con hojas) que cruza el recorrido. Zia se sube a la plataforma y **lanza su escudo (Ego) para que el chorro no la tire** mientras la plataforma pasa. (Vídeo de Pablo, 17 s, fotogramas a los 8–14 s.)
**Para nosotros:** apuntado como puzle **X5** en `PUZLES_DEMO_TRES_SELLOS_2026-11-20.md` §3, usando la **trampa dragón** (`TrampaDragon3D`) como chorro. Su chorro ya se corta en lo sólido, así que una barrera protege; lo que falta es la plataforma móvil y que la barrera viaje con ella.

### O3 · Arquero contra escudo: aviso, vuelo, rebote
Vídeo de Pablo (11,7 s, 30 fps). Zia con el escudo de Ego puesto; un goblin arquero le dispara desde abajo. Medido fotograma a fotograma en dos disparos (los fotogramas están en el directorio temporal de la sesión, no en el repo).

| Fase | Qué se ve | Tiempo |
|---|---|---|
| Recarga | El goblin se agacha con el arco | ~0,5 s (4,53 → 5,00 s) |
| Se levanta | Alza el arco hacia Zia | ~0,1 s |
| **Línea de apuntado** | Una línea fina del arco a Zia; se aclara hasta blanco justo antes de soltar | |
| Vuelo | La flecha cruza en muy pocos fotogramas | ~0,1–0,15 s (estimado) |
| **De la línea al impacto** | | **0,53 s** (f81 → f97) y **0,47 s** (f154 → f168) |
| Impacto | **Destello blanco grande en estrella** sobre el escudo, y otro más pequeño | 2–3 fotogramas (~0,1 s) |
| **Rebote** | La flecha **no vuelve** al arquero: sale despedida de lado, girando y partida, y cae | ~0,3 s visible |
| Cadencia | Entre dos impactos | **2,4 s** (3,23 → 5,60 s) |
| Escudo | **Aguanta varias flechas** sin romperse (3 en el clip) | todo el clip |

**La clave del diseño:** casi todo el margen de reacción está en la **línea de apuntado**, no en el vuelo. La flecha es rapidísima, pero la línea avisa medio segundo antes y es imposible no verla.

**Sonido:** no puedo oír el vídeo. Pendiente de que Pablo describa qué suena al soltar, al chocar y al rebotar.

**Cómo es lo nuestro hoy** (`enemigos/combate_3d.gd`, `magia/lanzador_3d.gd`):

| | Mystralia | Magic Symbols |
|---|---|---|
| Aviso | Línea del arco a la jugadora, ~0,5 s | Tensar 0,9 s (`PREPARAR_FLECHA`) con **marca en el suelo** que la sigue y se fija al soltar (`AvisoAtaque3D`) |
| Vuelo | ~0,1–0,15 s | **Lento**: 9 u/s (`VEL_FLECHA`); a 4–8 u son 0,45–0,9 s. Se esquiva andando |
| Cadencia | 2,4 s | 0,9 s de tensar + 2,2 s de descanso |
| Contra la burbuja | La flecha rebota y cae; el escudo sigue | La burbuja **revienta con la primera flecha** y la flecha desaparece (`burbuja_recibe`, suena `escudo_roto`) |
| Contra una barrera sólida | — | La flecha desaparece y la barrera encaja el daño (`solidez_para`) |
| Rebote | Siempre visible | **Ya existe** para el **muro de viento**: la flecha sale reflejada 0,2 s (`_desviar_flecha` y `normal_rebote_flecha`). Viento está fuera de la demo |
| Sonido | (pendiente) | `arco` al soltar, `escudo_roto` al reventar la burbuja |

**Propuestas** (en la lista de la sesión, `PROPUESTAS_SESION_MYSTRALIA_2026-11-21.md`, como C7–C10):
- **Línea de apuntado** del arquero, a la altura del vuelo, que se aclara antes de soltar. Más legible que solo la marca en el suelo.
- **Flecha más rápida con el mismo aviso**: el margen pasa del vuelo a la línea. Hoy la flecha lenta se esquiva andando, lo que también hace el combate fácil.
- **Rebote visible contra barreras de tierra, de agua y la burbuja**: reutilizar `_desviar_flecha`, que ya hace el rebote del muro de viento, con destello blanco y un sonido seco de rebote.
- **Burbuja que aguanta las flechas normales** y solo revienta con golpes de elemento (los que tienen reacción en `REACCIONES_BURBUJA`). Decisión de diseño para Pablo.

### O4 · Puzle: el brasero en la balsa y el fuego suspendido
Vídeo de Pablo (17,7 s). **Lo que se ve:**
1. En un muelle hay una **placa de presión**. Junto a él flota una **balsa con un brasero**.
2. **Sin nadie en la placa, la balsa está en el muelle; al pisarla, la balsa se aleja** por el agua (1,5 → 2,0 s), y vuelve al bajarse (4,0 s).
3. Zia, **de pie en la placa** (no se puede mover sin que la balsa se vaya), lanza **bolas de fuego que se quedan quietas en el aire** (el molde Actus sin Mover) en el borde del muelle, donde atraca la balsa (10,0 → 10,8 s). La primera bola sigue ahí al menos 6 s después.
4. Se baja de la placa: la balsa vuelve, **el brasero pasa por la bola suspendida y se enciende** (destello blanco a los 12,0 s) y se abre la puerta (12,5 s).

**El verbo:** dejar un hechizo suspendido **en el camino de algo que se mueve**, porque tú no puedes estar en los dos sitios a la vez. Es una «mecha» o una trampa que se deja preparada.
**Lo que no se ve en el clip:** por qué no basta con encender el brasero cuando la balsa está atracada. **Para nuestra versión (Pablo, 21/11):** un **muro en medio** que bloquee físicamente el disparo directo (flecha de fuego o haz). Así la bola suspendida es la única salida y la regla se ve sin explicarla.
**Para nosotros:** apuntado como **X6** en `PUZLES_DEMO_TRES_SELLOS_2026-11-20.md` §3. La bola quieta es fuego con ᛉ permanencia y sin ᛇ flecha; la balsa usa la misma plataforma móvil que X5.

### O5 · Cómo se crea el puente de hielo *(referencia, no para copiar)*
**Decisión de Pablo (21/11):** no se copia. En Mystralia el hielo se pone con **un botón propio**, no con un hechizo compuesto. Se guarda como **referencia de una interacción muy buena entre el agua, un hechizo de hielo y el suelo**: cómo un hechizo transforma una superficie y la vuelve transitable.

Vídeo de Pablo (13,2 s). Zia cruza un río creando losas de hielo. Medido cada 0,2 s:

| Paso | Qué se ve | Tiempo |
|---|---|---|
| Lanzar | Desde la orilla tira un **copo pequeño** a una casilla por delante | ~0,2 s de vuelo (1,8 → 2,0 s) |
| Caer | El copo toca el agua con un destello blanco | 2,2 s |
| **Nacer** | Aparece de golpe una **losa hexagonal** de hielo | ~0,2 s tras tocar el agua (2,4 s) |
| **Onda** | Un **anillo de escarcha** se abre alrededor de la losa y se desvanece | ~0,6 s (2,4 → 3,0 s) |
| Subir | Zia pisa la losa | 3,0–3,2 s |
| Siguiente | **Desde la losa** lanza el siguiente copo; la nueva losa **se funde** con la anterior (bordes unidos) | ~1,6 s por losa (2,0 → 3,6 s) |
| Durar | Las losas siguen ahí al llegar a la otra orilla | al menos 6 s |

**Lo que lo hace sentirse bien:**
- **Una semilla visible**: un proyectil pequeño que anuncia dónde va a nacer la losa.
- **Nacimiento instantáneo con onda**: la losa sale entera y de golpe, y la onda de escarcha le da peso.
- **Piezas que encajan**: losas hexagonales que se unen. El puente se ve como un solo objeto y no como bloques sueltos.
- **Ritmo de pasos**: lanzar, pisar y lanzar desde ahí. Es el mismo ritmo que nuestro T3 · El foso.

**Para nosotros:** T3 ya propone ese ritmo con plataformas de tierra ᛒ que duran 8 s, pero sobre una **hondonada seca**, porque la tierra no se puede levantar sobre agua (`puede_construir_en`). El hielo no entra en la demo. La pregunta de con qué hacerlo está en `PROPUESTAS_SESION_MYSTRALIA_2026-11-21.md` (P5).

### O6 · Jefe inicial: el ogro de la maza
Vídeo de Pablo (28 s; combate de unos 21 s, de 2,0 a 23,0 s). Un ogro grande con casco de cuernos y una maza enorme, en una explanada redonda con un anillo de piedra en el centro (con un barril rojo dentro; en el clip no se ve que tenga papel). **A Pablo le gusta como concepto de jefe inicial, y su secuencia de ataques nos vale tal cual** (ver C13).

**Su repertorio** (medido cada 0,1–0,4 s):

| # | Ataque | Qué se ve | Tiempos |
|---|---|---|---|
| 1 | **Entrada de un salto** | Salta desde el borde y cae junto al anillo | 2,0 → 3,2 s |
| 2 | **Barridos persiguiendo** | Avanza hacia Zia dando golpes laterales con la maza extendida (2–3 seguidos) | 3,6 → 5,6 s |
| 3 | **Mazazo vertical** | Tras un barrido, **levanta la maza sobre la cabeza** y la clava; nube blanca de polvo en el impacto | levanta 6,2 → **impacto 6,6** (~0,4 s de aviso); se queda quieto **~0,6 s** (6,8 → 7,4) |
| 4 | **Retirada y carga de salto** | Se va a un borde, **se agacha**, salta hacia Zia (se ve su sombra) y cae a su lado | agacharse 12,6 → 13,0 s; vuelo ~0,8 s (13,2 → 14,0) |
| 5 | **Mazazo con onda** | Tras la carga, otro mazazo cuya **nube de polvo avanza** por el suelo hacia Zia | 15,2 → 15,6 s |
| 6 | **Peonza** | Gira con la maza extendida dentro del anillo y remata con un mazazo | giro ~1,6 s (18,4 → 20,0); remate 20,8 s |

**Por qué funciona como primer jefe:**
- **Pocas ideas, muy claras**: cerca barre, en medio machaca, lejos salta. La jugadora aprende a leer distancias.
- **Cada golpe fuerte tiene su ventana**: tras el mazazo se queda quieto ~0,6 s, y es cuando Zia le pega (en el clip, 7,0–7,2 s, por su lado).
- **Ritmo de presión y respiro**: unos 4 s de acoso cerca, se aleja, salta. La retirada es el momento de lanzar desde lejos.
- **Se esquiva de lado** con el dash (5,9 s y 13,4 s), no con el escudo. Todo se evita moviéndose (C5).
- **Avisos grandes**: maza en alto, agacharse antes del salto, sombra en el suelo y nubes de polvo que marcan dónde pega.

### O7 · Concepto de glifo: la página de runas y el antes/después
Captura de la página «Actus #1» y vídeo de Pablo (55,8 s) que alterna el editor y el juego: **primero el hechizo base sin runa, después con la runa Mover**, en dos moldes.

**La página de runas, pieza a pieza:**

| Zona | Qué tiene | Para qué sirve |
|---|---|---|
| Cabecera | Nombre del hechizo («Actus #1»), botón «Editar» y **barra de coste** debajo | Cada runa añadida alarga la barra: el coste se ve al montar |
| Página izquierda | **Lienzo hexagonal con rejilla triangular**. El hechizo base en el centro (la bola de fuego, animada) y un **aro vacío en un vértice vecino** que marca dónde puede ir la siguiente runa | Enseña los huecos válidos sin texto |
| Pie izquierdo | **Cuatro huecos de elemento**; el elegido lleva su gema (roja = fuego) | El elemento es una pieza más del hechizo |
| Página derecha | **Catálogo por familias**: Cualidades (9), Incrementos (6), Disparadores (5). Lo que no tienes sale con candado y «Bloqueado»; lo recién ganado, con la etiqueta **«Nuevo»** | Se ve **cuánto falta por descubrir** (20 runas en total) y qué es nuevo |
| Ficha flotante | Al pasar por una runa: **nombre, una frase y en qué moldes vale**. Mover: «Añade una cualidad de movimiento al conjuro. Válido con ACTUS, CREO y EGO» | Explica la runa sin salir del libro |
| Menú «Conjuros» | Los cuatro moldes (Immedi, Actus, Creo, Ego), **cada uno en un botón del mando** (X, Y, B, RT) | Un hechizo por botón, siempre a mano |

**La iteración que enseña el vídeo** (lo que Pablo llama «concepto de glifo»):

| Molde | Sin runa (base) | Con Mover |
|---|---|---|
| **Actus** | La bola de fuego **se queda quieta** donde se lanza y arde en el suelo (19–22 s: varias llamas fijas) | **Sale disparada** como proyectil (48–50 s) |
| **Ego** | **Escudo** alrededor de Zia (burbuja) | **Dash** con estela azul (23–27 s) |

**La idea clave:** **la runa no es un efecto, es un verbo que se aplica al molde.** «Mover» no significa «proyectil»: significa «que esto se mueva», y por eso convierte la bola en proyectil y el escudo en dash. La misma pieza da dos resultados distintos y los dos se entienden.

**En el vídeo, Pablo mueve Mover por varios vértices del hexágono** (5–9 s y 42–46 s). Según el equipo de Mystralia, las cualidades se aplican al hechizo entero sin importar dónde estén, y la posición solo importa para los incrementos (§1.2). En el clip no se aprecia un cambio de dirección al mover la runa de sitio, lo que cuadra con esa regla.

**Cómo es lo nuestro:**
- **El concepto ya lo tenemos**: la regla R1 dice que ᛇ flecha sobre algo con forma **hace que la forma viaje** (bola → proyectil, barrera → muro que avanza), y la barrera sola rodea a la jugadora, como el Ego. Es el mismo «verbo sobre la base».
- **Lo que no tenemos es enseñarlo**:
  - en el libro no he encontrado un **catálogo de glifos con huecos bloqueados** ni una etiqueta de **nuevo** (la mochila sí los tiene: huecos bloqueados y brillo de objeto nuevo en `presentacion/ui/bolsa_ui.gd`);
  - no hay **ficha por glifo** con frase y «en qué vale»;
  - no hay un **antes/después** que muestre el mismo hechizo sin el glifo y con él. Sí existe el texto de lo que cambia al añadir un glifo (`Hechizo.diferencia()` / `texto_cambio`).

**Propuestas** (H6–H8 en la lista de la sesión).

### O8 · Jefe del bosque: presentación y aliento que se bloquea con barrera
Vídeo de Pablo (46 s): Twigg, un árbol gigante en un pantano. A Pablo le gustan **dos cosas como ejemplos importantes**: la presentación del jefe (**solo para jefes**) y la anticipación del aliento con el bloqueo con barrera. Vale para un dragón.

**La presentación** (medida cada 1 s):

| Momento | Qué se ve |
|---|---|
| 4–6 s | Zia avanza por el camino; hay un tocón raro en el agua |
| 7–13 s | La cámara se va hacia el pantano y lo recorre |
| 14 s | Salpicadura: algo emerge |
| 15–17 s | El árbol gigante se levanta del agua |
| 18–30 s | **Rótulo en dos líneas**: un epíteto pequeño («Gigante Despreciable del Bosque») y el **NOMBRE** grande («TWIGG»), en el tercio de abajo, unos 12 s. Mientras tanto se le encienden los ojos verdes y Zia puede seguir moviéndose |
| 31 s | Desaparece el rótulo y aparece su **barra de vida** arriba: empieza el combate |

Para nosotros **la cámara no se mueve** (los cambios de vista marean): el jefe se presenta dentro de la vista de siempre.

**El aliento** (medido cada 0,2 s en dos ataques):

| Fase | Qué se ve | Tiempo |
|---|---|---|
| Anticipación 1 | **Gira la cabeza y la baja**; la boca se enciende (un brillo rosado) | ~0,8–1,4 s (31,0 → 32,2 y 38,6 → 39,4) |
| Anticipación 2 | Se alza de lado y aparecen **anillos verdes en el agua a sus pies** | ~0,6–0,8 s (32,4 → 33,2 y 39,4 → 40,0) |
| Aliento | Una **nube verde enorme que barre** de un lado al otro y cruza el camino | ~2,8 s (33,4 → 36,2) y ~3 s (40,2 → 43,2) |
| Bloqueo | Zia se queda dentro de la nube con su **barrera** puesta: la nube la envuelve y sigue de largo | ~1 s de contacto (41,6 → 42,6) |
| Final | Cabeza atrás, ojos encendidos, vuelta al reposo | ~0,6 s |

**Lo que lo hace legible:** dos avisos seguidos, uno en el cuerpo (cabeza y boca) y otro en el suelo (anillos), que suman unos **2 s** antes del primer daño. Y **empieza siempre por un lado**: la jugadora sabe hacia dónde moverse o cuándo levantar la barrera.

**Hecho (21/11):** un dragón placeholder con las dos ideas. Ver C14 en `PROPUESTAS_SESION_MYSTRALIA_2026-11-21.md`.

### O9 · El mismo jefe: puntos débiles, exposición, temblor y carril
Dos vídeos más de Pablo (17,8 s y 35,6 s), medidos cada 0,1–0,8 s. El temblor se ha medido comparando el desplazamiento de la imagen del fondo entre fotogramas seguidos.

**1. Puntos débiles que abren la exposición** (vídeo de 35,6 s):

| Momento | Qué pasa |
|---|---|
| De pie (2,5 → 19,5 s) | El árbol tiene **tres cristales morados** en las ramas (izquierda, centro y arriba a la derecha). Zia dispara bolas de fuego hacia arriba |
| Cada acierto | El cristal **se queda ardiendo** (una llama fija sobre la rama): se ve cuántos llevas. Aciertos a los 4,1 s, 13,7 s y 19,2 s |
| Tercer cristal | **Se derrumba** (19,8 → 20,6 s, ~0,8 s) y deja a ras de suelo, a la altura de Zia, un **orbe rosa**: el sitio donde de verdad se le hace daño |
| Expuesto | Unos **9,7 s** (20,4 → 30,1 s) para pegarle al orbe desde cerca. En el otro vídeo, unos 8 s (4,5 → 12,0 s) |
| Se levanta | 30,1 → 30,5 s: vuelve a ponerse de pie con los ojos encendidos |

Es lo que describe Pablo: **termina su secuencia, expone sus debilidades y da tiempo; el golpe en el punto débil revela dónde hacerle daño.** Las dos capas (cristales arriba que se aciertan desde lejos y orbe abajo que se golpea de cerca) hacen que la pelea tenga **dos ritmos**: apuntar y luego castigar.

**2. Feedback con un enemigo grande:**

| Suceso | Temblor de pantalla | Otro feedback |
|---|---|---|
| **Golpe del cuerpo contra el suelo** (3,6 → 3,8 s) | Oscilación vertical de unos **±40 px sobre 1438** (≈3 % del alto), ~0,2 s, cambiando de sentido cada fotograma | — |
| **Golpe al orbe** (26,0 s) | Un solo **tirón** de cámara (~44 px) | **Toda la silueta del jefe se pone blanca** 1–2 fotogramas: se lee desde lejos que el golpe ha entrado |
| **Se levanta** (30,0 → 30,4 s; en el otro vídeo 13,1 → 13,4 s) | Oscilación de ±25–45 px, **0,3–0,4 s** | Ojos que se encienden |
| Acierto en un cristal | Ninguno medible | La llama que se queda |

**La regla que se deduce:** el temblor largo es para **lo que hace el cuerpo grande** (caer, golpear el suelo, levantarse); el golpe de la jugadora al punto débil lleva **un tirón corto y el destello de la silueta entera**; los golpes pequeños no tiemblan.

**3. Posicionamiento: un carril.** Zia se mueve casi solo **de izquierda a derecha** por un camino al pie del jefe; apenas cambia de fila (eje Y de la pantalla). El jefe está **detrás del carril**, siempre a la misma distancia. Por eso la cámara los encuadra a los dos sin moverse, y los ataques llegan de frente o barriendo el carril. **Esto contesta el problema de encuadre de C15**: con un carril, el jefe queda siempre a la misma altura de pantalla.

### O10 · Hechizos 1–4 con variantes en cada botón (Pablo: «esto sería similar a nuestras páginas; esta era la respuesta»)
Dos capturas de Pablo: el menú «Conjuros» y el HUD en juego.

**Lo que se ve:**
- **Cuatro huecos fijos, uno por molde y botón**: Immedi (X), Actus (Y), Creo (B) y Ego (RT). El molde lo decide el hueco, no una runa.
- **Cada hueco guarda varios hechizos**: «Ego #1», «Ego #2» y un «+» para crear otro. Al elegir uno, la página de la derecha lo enseña (con su barra de coste) y abajo están **Equipar, Editar y Eliminar**.
- El molde nuevo lleva la etiqueta **«Nuevo»** (Creo, recién ganado).
- **En el HUD**, junto a cada icono con su botón, sale el **nombre del hechizo equipado** («Immedi #1», «Ego #1»…): la jugadora ve qué tiene en cada botón sin abrir nada.

**La idea de Pablo para nosotros:** las páginas pasan a ser **hechizos 1–4** y **varias pulsaciones del mismo botón cambian el hechizo** de ese botón (por ejemplo, la tecla 4 pasa de «Ego #1» a «Ego #2»). Así hay más hechizos a mano sin más botones, y el botón ya dice de qué tipo es.

**Por qué es «la respuesta»:** contesta dos preguntas abiertas.
- **H2 (cómo se marca «sobre mí»)**: con un botón propio para los hechizos sobre la jugadora (su Ego en RT), no hace falta glifo ni gesto: lo que se dibuja en esa página sale sobre ella (flecha = dash, barrera = escudo).
- **«Pocas acciones»** del playtest: 4 botones × varias variantes, sin tener que abrir el libro en combate (que está prohibido desde el 5/11).

Ver H10 en `PROPUESTAS_SESION_MYSTRALIA_2026-11-21.md`.

### O11 · Tiempo para reaccionar: el escudo solo sirve si da tiempo a sacarlo
Vídeo de Pablo (32 s). Un enemigo vive en un lago y **sale a la superficie para disparar**; Zia está en la orilla. Las bolas **azules** son las del enemigo; las **rojas**, las bolas de fuego de Zia (que buscan al enemigo). Medido cada 0,1–0,25 s en tres disparos:

| Fase | Qué se ve | Tiempo |
|---|---|---|
| Aviso | El enemigo **asoma del agua** y brilla azul bajo él | ~0,5–1 s antes del disparo (16,0 → 17,6 s) |
| Vuelo | La bola azul cruza el lago **despacio**, en línea recta y siempre visible | **~2,0–2,25 s** (4,9 → 7,0 s; 7,75 → 10,0 s; 17,75 → 20,0 s) |
| Escudo | Zia saca el escudo (la burbuja del Ego) **justo antes del impacto** | **0,4–0,5 s antes** (9,6 → 10,0 s; 19,5 → 20,0 s) |
| Impacto | Destello blanco y la bola **se rompe en esquirlas** azules; Zia no recibe daño | ~0,2 s de esquirlas |
| Respuesta | Nada más bloquear, Zia contraataca (bola de fuego que busca, o un rayo) | inmediatamente |

**La regla que enseña** (y la que pide Pablo: «es importante que haya tiempo de reacción, si no la barrera no hace nada»): **lo que se bloquea tiene que dar tiempo a ver, decidir y sacar la protección**. Aquí sobra: el proyectil está ~2 s a la vista y el escudo sale en ~0,5 s, así que la jugadora decide cuándo. El momento de sacarlo es una pequeña habilidad (ni muy pronto ni muy tarde) y el bloqueo abre el contraataque.

**Contraste con la flecha del arquero (O3):** allí la flecha es rapidísima (~0,1 s) y el aviso es la línea (~0,5 s); Zia **ya tenía el escudo puesto**. Son dos tipos de ataque distintos: el **rápido** se esquiva o se para con una protección ya puesta; el **lento** se bloquea reaccionando. Ver C18 y la nota de C8 en `PROPUESTAS_SESION_MYSTRALIA_2026-11-21.md`.

### O12 · El escudo DEVUELVE la flecha al que la disparó (Pablo: «esto es importante, mira cómo rebota y el feedback»)
Vídeo de Pablo (22 s). Un goblin arquero dispara desde arriba; Zia, en un camino, se protege con el escudo (Ego). Medido cada 0,067–0,15 s (los destellos se localizaron buscando píxeles blancos nuevos entre fotogramas):

| Fase | Qué se ve | Tiempo |
|---|---|---|
| Aviso | El arco del goblin **brilla en verde** | 6,25 s |
| Vuelo | Una flecha verde baja hacia Zia | ~0,3–0,45 s (6,40 → 6,85 s) |
| Escudo | Aparece el aro del escudo alrededor de Zia | 6,70 s (0,15 s antes del choque) |
| **Choque** | **Destello blanco en estrella** en el punto de contacto, 2–3 fotogramas | 6,85 s |
| **Rebote** | La flecha **sale de vuelta hacia el arquero**, curvándose un poco, con un **rastro de puntos verdes** que dibuja el camino | 6,90 → 7,60 s |
| **Le da** | **Chispas blancas en el goblin**: su propia flecha le ha alcanzado | ~7,75–7,90 s (~0,9 s tras el choque) |

Más tarde (15,9 y 17,0 s) pasa lo mismo con otros disparos, con destello amarillo-blanco y una nube de humo gris en el sitio del golpe.

**Lo que lo hace bueno:**
- **El bloqueo es un ataque**: devolver la flecha castiga al tirador sin gastar nada. Convierte la defensa en una jugada.
- **El camino de vuelta se ve** (rastro de puntos del color de la flecha): la jugadora entiende qué ha pasado y a quién le va a dar.
- **Tres golpes de feedback en orden**: destello en el escudo, rastro de vuelta y chispas en el enemigo.
- **El escudo de Mystralia sale casi al instante** (0,15 s antes del choque basta). El nuestro tarda 0,53–0,70 s (medido, C18): con flechas de 0,6 s de aviso + vuelo, solo vale si ya está puesto.

Ver C19 en `PROPUESTAS_SESION_MYSTRALIA_2026-11-21.md`.

### O13 · Puzle: disparar a través del chorro para apagarlo
Vídeo de Pablo (10 s, zona de hielo). Medido cada 0,2 s:

| Momento | Qué se ve |
|---|---|
| 0 → 3,3 s | Una torreta lanza hacia abajo un **chorro de viento helado** que corta el camino. Zia espera al otro lado |
| 2,5 → 2,9 s | Zia dispara una bola de fuego **a través del chorro** (lo cruza sin desviarse) hacia un **brasero** que hay a un lado |
| 3,1 s | El brasero **se enciende** (destello amarillo) |
| 3,3 s | **El chorro se apaga** (0,2 s después) y la torreta se queda con un remolino azul |
| 3,3 → 5,7 s | **~2,4 s sin chorro**: el paso está libre |
| 5,7 s | El chorro **vuelve a salir** desde arriba, aunque el brasero sigue encendido |

**El verbo:** encender algo **al otro lado de un peligro** para abrir el paso un rato corto, y cruzar a tiempo.
**Sin confirmar:** si el brasero es lo que apaga el chorro o si coincide con un ciclo. La coincidencia de 0,2 s apunta al brasero. Pendiente de que Pablo lo confirme.
Ver X7 en `PUZLES_DEMO_TRES_SELLOS_2026-11-20.md`.

### O14 · El hechizo que va al suelo: base, con Mover y con Mover + Derecha
Vídeo de Pablo (36 s): el mismo hechizo de hielo de suelo (molde Creo) en tres versiones, y al final el editor con las runas. Medido cada 0,25–0,4 s:

| Versión | Qué hace | Tiempos |
|---|---|---|
| **Base** | Lanza un copo corto y nace **una losa** de hielo donde cae, con su anillo de escarcha | copo 8,35 s → losa 8,6 s (~0,25 s) |
| **+ Mover** | El copo **sigue avanzando y va dejando losas detrás**: un **camino recto** de unas 9–10 losas que dura varios segundos | 13,0 → 14,6 s (una losa cada ~0,18 s); sigue ahí a los 18,6 s |
| **+ Mover + Derecha** | El copo **gira todo el rato a la derecha**: el camino sale **en arco**, casi un círculo alrededor de Zia | 21,8 → 26,2 s |

**La lectura:** es otra vez «la runa es un verbo sobre la base» (O7). Mover sobre un hechizo que **crea suelo** no da un proyectil: da **un rastro de suelo creado**. Derecha no apunta a otro sitio: **dobla el rastro**. Con dos runas salen tres herramientas distintas: un punto de apoyo, un puente recto y un camino curvo (o un corral alrededor de algo).

**Cómo estamos nosotros:** el ᛒ suelo de hoy **ignora la flecha** («ᛒ manda», `magia/glifo_suelo.gd:17`). Pero nuestras reglas ya dicen lo mismo que Mystralia: **ᛇ sobre algo con forma hace que la forma viaje** (R1) y **ᛃ sobre lo que viaja añade la vuelta** (R2). Ver H11.

### O15 · Puzle: tres braseros, plataformas móviles y un chorro que empuja
Vídeo de Pablo (15,5 s, sala de hielo). Medido cada 0,3 s:

| Momento | Qué pasa |
|---|---|
| 1,2 s | Zia enciende desde el suelo el brasero de arriba a la derecha |
| 2,1 → 2,7 s | Enciende con una bola de fuego **en diagonal** el de abajo a la derecha |
| 3,0 → 5,1 s | Se sube a una **losa con estrella** (plataforma móvil, como la de O2) que cruza el foso; por encima pasa un **chorro de viento** que empuja y Zia **lleva el escudo puesto** (destello al chocar, 4,5 s) |
| 5,7 → 6,0 s | Desde la plataforma, enciende el **tercer brasero**, que no se alcanzaba desde el suelo |
| 6,9 s | Se abre la puerta |

**El verbo:** la plataforma móvil no es el puzle, es **el sitio desde el que se dispara**: da un ángulo de tiro que el suelo no da. El chorro añade una segunda cosa que vigilar (protegerse mientras te llevan), igual que en O2.
Ver X8 en `PUZLES_DEMO_TRES_SELLOS_2026-11-20.md`.

### O16 · Jefe de hielo: la anticipación se repite en cada golpe, y los esqueletos que resucitan
Vídeo de Pablo (34 s). Un jefe de hielo enorme cuya **cola** acaba en una maza de cristal, y una arena llena de esqueletos. Medido cada 0,2–0,4 s.

**1. La cola: la misma anticipación en cada golpe** (Pablo: «tómalo como una regla con todos los jefes»)

| Fase | Qué se ve | Tiempo |
|---|---|---|
| Apuntar | La maza se coloca sobre un punto de la arena | ~0,4–0,8 s |
| **Levantar** | La maza **sube** (crece en pantalla porque se acerca a la cámara) | **~0,6–0,8 s** (12,6 → 13,2 s; 15,2 → 15,6; 16,8 → 17,2; 18,4; 19,2) |
| Golpe | Cae y deja un **anillo** en el suelo | 13,4 → 14,4 s |

En una serie de cinco o seis golpes seguidos, **todos llevan el mismo levantar**: ninguno se salta el aviso. Aunque el jefe vaya rápido, la jugadora siempre puede leer cada golpe.

**Feedback al pegarle:** el cristal de la cola se **perfila en rojo** y luego se pone **entero en blanco** un instante (24,4 → 25,15 s, dos golpes). Es la silueta blanca de O9 (C17), con un aviso rojo antes.

**2. Los esqueletos que resucitan** (Pablo: «esta idea es la que vale para el mouro zombi»)

| Fase | Qué se ve | Tiempo |
|---|---|---|
| Caído | El esqueleto vencido queda como **montón de huesos en el suelo**, donde cayó | — |
| Aviso | Se forma **un anillo de escombros alrededor** de los huesos, con **destellos morados** | ~1,8 s (13,0 s →) |
| Se levanta | El esqueleto **se levanta en el mismo sitio** | ~14,8 s |

Varios a la vez (22,9 → 23,9 s): cada uno con su anillo y su brillo morado. **Se ve de antemano dónde y cuándo vuelve cada uno**, así que la jugadora puede decidir: rematar los huesos, alejarse o prepararse.

Ver C22 y C23 en `PROPUESTAS_SESION_MYSTRALIA_2026-11-21.md`.

### O17 · La runa «Impacto»
Captura de Pablo del catálogo de runas, ya con más runas ganadas: **Mover** y **Buscador** (cualidades), **Derecha** (incremento) e **Impacto** (disparador). Ficha de Impacto: «Lanza un disparador de forma automática al golpear un objetivo o un obstáculo». A Pablo le gusta el concepto: **al impactar, hace X**. Usos para nosotros en H1b de `PROPUESTAS_SESION_MYSTRALIA_2026-11-21.md`.

### O18 · La runa «Repetición»: varias a la vez
Captura de Pablo (22/11): con Repetición, la bola de fuego sale **triplicada en paralelo**. Las tres bolas avanzan juntas, una al lado de otra, hacia el enemigo, desde la plataforma de la jugadora. Pablo: «Hagamos lo mismo para cada bola, haz o lo que sea: un elemento más saliendo a la vez». En lo nuestro, ᚠ ya lo hace con el proyectil y con los volúmenes quietos, pero no con el haz ni con ᛒ. Detalle en H13 de `PROPUESTAS_SESION_MYSTRALIA_2026-11-21.md`.

### O19 · Puzle de plataformas sobre raíles movidas por molinetes de viento
Vídeo de Pablo (22/11, 31 s; analizado fotograma a fotograma, sin sonido):
- **Escenario:** un cañón con pilares y agua al fondo. Entre los pilares, **raíles largos** (vigas de madera) con una **plataforma octogonal** que corre por cada uno. Junto a la parada de cada plataforma, en un pilar pequeño, hay un **molinete de aspas naranjas**.
- **Cómo se juega:**
  1. La jugadora se sube a la plataforma (0–2 s).
  2. **Lanza viento al molinete** (2,5 s: remolino blanco junto a las aspas, que giran).
  3. La plataforma **recorre su raíl entero hasta el otro pilar**, con ella encima (3,5–7 s; unos 3–4 s de viaje). La cámara la sigue.
  4. En el pilar de llegada hay **otra plataforma en otro raíl**, a menudo en otra dirección, y otro molinete: se repite (12–27 s, cuatro tramos en total).
- **Tramo con peligro** (15,5–17,5 s): mientras va en una plataforma, cruza un proyectil rojo y estalla una nube de polvo junto al molinete de abajo. En las fotos no se ve si lo lanza ella o es un peligro de la sala; su barra azul baja en ese momento.
- **Lo que hace bueno el diseño:**
  - **Un verbo**, viento al molinete, aplicado en cadena.
  - El **desafío es de posición y de puntería**: hay que lanzar desde la plataforma, a veces hacia atrás o de lado, y elegir qué molinete activar.
  - **El recorrido se lee solo**: el raíl enseña adónde vas a ir antes de activarlo.
- **Para nosotros:** P10 de `PROPUESTAS_SESION_MYSTRALIA_2026-11-21.md`.

### O20 · El disparador «De una vez» y el catálogo de runas a mitad de juego
Captura de Pablo (22/11) del libro de runas, más avanzado que en O17:
- **Cualidades:** Mover, Duplicar, Rebote, Buscador y Lluvia.
- **Incrementos:** Derecha, Izquierda, Tiempo, Invertir y Aleatorio.
- **Disparadores:** Impacto y **De una vez**, con la ficha «Al usar un conjuro lanza a la vez un disparador».

Huecos bloqueados quedan en cada familia (H7: se ve cuánto falta). A Pablo le interesa «De una vez»: el hechizo enganchado sale en el mismo instante que el primero. Para nosotros: H15 de `PROPUESTAS_SESION_MYSTRALIA_2026-11-21.md`, como tercera condición de la página de dos círculos.

También son de interés para más adelante **Izquierda y Derecha** (curvar la trayectoria; nosotros lo planteamos con el hueco de la corona, H11 y punto 8 de las mejoras), **Invertir** y **Aleatorio**.

### O21 · «De una vez» en el editor y en juego: los dos hechizos salen con un pequeño retardo
Vídeo de Pablo (22/11, 36 s, medido fotograma a fotograma a 30 fps):
- **En el editor** (0–25 s):
  - «De una vez» ocupa **un hueco del anillo de runas** del conjuro (Actus #3).
  - Al ponerlo, el juego pide: **«Selecciona el conjuro que quieras disparar de una vez»**, y se elige **otro conjuro ya guardado** de la lista (Immedi, Actus, Greo…).
  - O sea: el hechizo enganchado es **una referencia a otra página**, como nuestro H1, no un segundo círculo dibujado en la misma página (H12).
- **En juego** (28,8–33,9 s): la página es una andanada de 3 bolas de fuego paralelas, y «De una vez» lanza otra igual.
  - Primer hechizo: chispas blancas en los puntos de salida, un destello blanco grande y las bolas.
  - Segundo hechizo: igual, **5 fotogramas (≈ 0,17 s) después**, detrás de la primera andanada.
  - Es idéntico en los tres lanzamientos del vídeo.
- **Por qué** (Pablo): un pequeño retardo que parece lógico y evita errores; se leen dos hechizos y no uno mezclado.
- **Para nosotros:** H15 de `PROPUESTAS_SESION_MYSTRALIA_2026-11-21.md`.

### O22 · Jefe de dos: uno escuda al otro
Vídeo de Pablo (22/11, 87 s; analizado fotograma a fotograma, sin sonido). Pablo: «un jefe muy sencillo: uno escuda a otro».
- **Arena:** plataforma octogonal de madera sobre el agua, sin obstáculos.
- **Los dos enemigos** (dos barras arriba a la derecha):
  - **El tanque:** un gólem grande de jade, cuerpo a cuerpo, que persigue.
  - **El escudero:** un bloque pequeño naranja que se queda **en el borde**, lejos.
- **Fase 1 · el escudo** (0–3 s):
  - El escudero une al tanque con un **hilo de luz** visible y le pone una **burbuja dorada**.
  - Mientras el hilo está, **el tanque no recibe daño**. El escudero, además, dispara andanadas de 3 proyectiles a la jugadora.
- **Cómo se rompe** (2,4–3,0 s): la jugadora **golpea al escudero**, el hilo se corta y la burbuja desaparece.
  - El escudero queda **aturdido, con estrellas girando encima** (6,5–21,5 s; en las fotos no se distingue si es un aturdimiento largo o varios seguidos).
  - Mientras, el tanque es vulnerable y la jugadora lo baja (se ve el rayo de la debilidad al acertar).
- **Transición** (22–30 s): el tanque cae hecho pedazos. Cinemática: el escudero **crece y se carga de rayos**. Es la fase 2, sola y furiosa.
- **Fase 2** (31–76 s), el escudero solo:
  - Se mueve por el borde con **acometidas que dejan copias doradas** (41, 49, 55 y 67 s).
  - Dispara andanadas de 3 y en un momento **oscurece la arena** (57 s).
  - Cae a los 75 s en pedazos dorados y se abre el paso (77–80 s: farol y pasarela).
- **Lo que hace bueno el diseño:**
  - **Una regla legible:** el hilo dice quién protege a quién.
  - **Una prioridad clara:** primero el pequeño, aunque el grande sea el que pega.
  - **Una transición que cambia la pelea:** el que sobrevive se enfada.
- **Para nosotros:** C24 de `PROPUESTAS_SESION_MYSTRALIA_2026-11-21.md`.

### O23 · Cómo telegrafía el goblin: pose quieta y golpe seco
Vídeo de Pablo (22/11, 9 s de juego; medido fotograma a fotograma a 30 fps). Pablo: «mira cómo el goblin telegrafía sus ataques; busquemos de inicio este output lag».

| | Ataque 1 | Ataque 2 |
|---|---|---|
| Se pone en guardia: **agachado, con la porra atrás**, quieto y mirando a la jugadora | 2,47 s | ~5,93 s |
| Aguanta la pose **quieto** | **~0,7 s** (2,47–3,20) | **~0,5 s** (5,93–6,40) |
| **Acometida:** salta 2–3 cuerpos hasta ella | **~2 fotogramas, ~0,07 s** (3,27–3,33) | ~2 fotogramas (6,47–6,53) |
| Contacto | ~3,33 s | ~6,53 s |

- **No hay marca en el suelo.** El aviso es solo el cuerpo: una pose muy reconocible (más bajo, el arma atrás) y **la quietud** en medio de un enemigo que antes se movía.
- **El reparto es el truco:** la anticipación es **larga y quieta** (0,5–0,7 s) y la ejecución **casi instantánea**. El golpe se siente seco y rápido, pero nunca injusto, porque la pose ya lo ha dicho.
- **Para nosotros:** C25 de `PROPUESTAS_SESION_MYSTRALIA_2026-11-21.md`.

### O24 · Puzle: reflejar un rayo de luz con hielo
Vídeo de Pablo (22/11, 9 s de juego; analizado fotograma a fotograma):
- **La sala:** una cueva oscura. Por un agujero del techo baja un **haz de luz** que cae sobre un **pedestal en forma de estrella**, en un claro iluminado rodeado de vías de vagoneta. En una pared, a la derecha, hay un **cristal azul**: el receptor.
- **Cómo se juega:**
  1. La jugadora se pone en el pedestal, dentro de la luz.
  2. **Saca su escudo de hielo** (1,7 s): un cristal curvo delante de ella.
  3. **La luz rebota en el hielo** y sale como un **rayo horizontal hacia donde mira** (1,8 s: a la izquierda).
  4. **Girando, el rayo barre toda la sala** (2,4 s arriba, 3,9 s abajo a la derecha, 6–7,8 s otra vuelta).
- **El reflejo dura mientras mantiene el escudo** (unos 3 s cada vez, 1,7–4,4 y 4,8–7,8 s). Al soltarlo, la luz vuelve a caer en el pedestal sin más.
- En el vídeo no llega a apuntar al receptor: enseña la mecánica.
- **Lo que hace bueno el diseño:**
  - **Un hechizo defensivo que se usa para otra cosa:** el escudo es un espejo.
  - **Apuntar es girar el cuerpo:** se entiende sin explicación.
  - **El rayo se ve entero:** se sabe en todo momento adónde apunta.
- **Para nosotros:** P11 de `PROPUESTAS_SESION_MYSTRALIA_2026-11-21.md`.

### O25 · Puzle: la luz que incide mueve un objeto (vagoneta de cristal)
Vídeo de Pablo (22/11, 35 s de juego; analizado por fotogramas). Pablo: «al incidir luz se mueve un objeto».
- **Piezas:**
  - un **haz de luz fijo** que entra por la parte de abajo de la sala;
  - un **cristal grande** sobre un pedestal: recibe el haz y lo **reemite en una dirección**, que la jugadora **gira con «Activar»** (el botón de interactuar; 4,5–24,9 s, el haz sale a la izquierda, a la derecha…);
  - una **vagoneta con un cristal azul** sobre unas vías que dan la vuelta a la sala.
- **La regla:** cuando la luz da en el cristal de la vagoneta, este **se enciende y la vagoneta avanza por las vías**. Sin luz, se para. En el vídeo sube por la vía de la derecha (de 9 a 21 s ya está arriba) y luego baja hacia la jugadora (31,7–35,1 s).
- **Cadena de dos reflejos** (29,5–35,1 s): el cristal grande manda la luz hacia la jugadora, ella la **refleja con su escudo de hielo** (O24) hacia la vagoneta y la va **siguiendo mientras se mueve**, girándose para no perderla.
- **Lo que hace bueno el diseño:**
  - **La luz es un motor**, no un interruptor: mientras le das, se mueve.
  - **Hay que mantener la puntería** sobre un objetivo que se mueve.
  - **Combina las dos fuentes de giro:** el cristal fijo, que se gira con un botón, y el escudo, que se gira con el cuerpo.
- **Para nosotros:** P12 de `PROPUESTAS_SESION_MYSTRALIA_2026-11-21.md`.

### O26 · Puzle: alinear los cristales y poner tú el último reflejo
Dos vídeos de Pablo (22/11): 1454-32, que de 189 s tiene unos 45 s de juego (59–108 s), y 1459-20, de 33 s, que muestra la misma sala resuelta. Pablo: «alinear espejos y después poner tú el último reflejo».
- **Piezas:**
  - un **cristal fuente** en un claro donde cae la luz del techo, que manda un haz fijo;
  - un **cristal pequeño** en un hueco de las rocas, al otro lado;
  - un **cristal alto sobre un pedestal giratorio** en el centro, que se gira con «Activar».
- **La cadena** (1459-20):
  1. La fuente da en el cristal pequeño de las rocas.
  2. La jugadora se pone junto a él y, **con su escudo de hielo, refleja el haz** hacia el pedestal central (10,3 s).
  3. El cristal central **reemite en la dirección en que está girado** (12,1 s: a la izquierda; 25,2 s: hacia abajo).
  4. Con el central bien orientado, la luz llega a la **puerta**: cinemática de la puerta que se abre con el haz (28 s). En el otro vídeo, la recompensa es una **gema del alma violeta** (108 s).
- **El orden importa:** primero se **deja girado** el cristal central (es fijo, se queda donde lo dejas) y después la jugadora **cierra la cadena** con su reflejo, que solo dura mientras lo mantiene.
- **En 1454-32** (59 s) hay otra sala con la misma idea: fuente → cristal girable → un bloque oscuro que la luz deshace en polvo.
- **Lo que hace bueno el diseño:**
  - mezcla **preparar** (piezas que se quedan) con **ejecutar** (el reflejo propio, que hay que mantener);
  - el haz se ve en todo momento, así que **se depura mirando**.
- **Para nosotros:** P13 de `PROPUESTAS_SESION_MYSTRALIA_2026-11-21.md`.

### O27 · Jefe sombra: invulnerable hasta que la luz lo expone
Vídeo de Pablo (22/11, 37 s; analizado por fotogramas). Pablo: «no quiero este enemigo, sino conceptos de mitología celta e íbera con una filosofía parecida».
- **Arena:** plataforma circular sobre un lago tóxico. En el borde hay **ocho braseros** (aros amarillos) y por el techo entra un haz de luz.
- **El enemigo:** un demonio alado que es **una sombra plana en el suelo**. Recorre la arena y lanza fuego (andanadas y estallidos en el suelo, 11,7 s). **Como sombra no recibe daño.**
- **La ventana:**
  - Al romperse el techo (18,9 s), cae una **mancha de luz** en el centro.
  - Cuando la sombra entra en ella, **se vuelve cuerpo**, con contorno rojo (21,6 s), y **queda aturdido** con estrellas (29,7 s). La jugadora le pega y el golpe fuerte lo pone en **silueta blanca** (27,9 s).
  - Después vuelve a ser sombra y huye.
  - Hacia los 34 s los braseros y unos rayos entre ellos parecen formar parte de la segunda fase. En las fotos no se ve con claridad.
- **La filosofía (lo que pide Pablo):**
  1. Por defecto es **invulnerable**.
  2. **La arena tiene la herramienta** que lo cambia (la luz).
  3. La jugadora tiene que **manipular el entorno o un elemento** para abrir la ventana, no solo pegar.
  4. La ventana **se lee clara** (cuerpo, contorno, estrellas) y **dura poco**.
  5. El enemigo **evita activamente** esa condición.
  6. Mientras es invulnerable **sigue atacando**, así que hay presión.
- **Para nosotros:** conceptos en `docs/ENEMIGOS_MITOLOGIA_2026-11-22.md`.

### O28 · Los hechizos tienen nombre
Captura de Pablo (22/11) del selector de hechizos en combate: cuatro botones (X, Y, B, RT), cada uno con el icono del tipo de hechizo y **su nombre** al lado. Unos son automáticos («Immedi #2») y otros los ha puesto la jugadora («Hielo doble», «Camino de tierra», «Dash»). Pablo: «el juego deja renombrar tus hechizos para que, cuando elijas la página, sepas qué conjuras». Para nosotros: H16 de `PROPUESTAS_SESION_MYSTRALIA_2026-11-21.md`.

### O29 · Puzle: la esfera tras el murete (cambiar el hechizo para llegar)
Vídeo de Pablo (23/11, 27 s; analizado por fotogramas). Pablo: «puzle sencillo».
- **La sala:** una plataforma circular con un **cofre cerrado** en el centro. Al norte, unas escaleras suben a un pasillo, pero las corta un **murete de piedra con una estrella** que no se puede cruzar. Detrás del murete, sobre un pedestal y a unas 3 casillas, hay una **esfera armilar dorada** con un contorno amarillo que avisa de que se puede activar.
- **Cómo se juega:**
  1. Desde el murete, la jugadora lanza su hechizo de fuego hacia la esfera (15,4 s). **No llega:** el murete corta el disparo directo.
  2. Abre el libro y **edita la página** «Actus #5» (17–20 s): le añade el incremento **Invertir** («invierte la dirección de la cualidad asociada»), que cambia la trayectoria.
  3. Vuelve a lanzar (20,5 s) y el fuego **llega a la esfera**: destello blanco (20,8 s), llamas (21 s) y queda encendida en rojo.
  4. Se **abre el cofre** del centro (22 s) y una **cinemática** enseña una losa negra con una runa que aparece abajo, junto al puente (23–25 s).
- No se distingue la trayectoria exacta (pasa en menos de 0,3 s): lo que se ve es **un intento fallido, editar la página y un intento bueno**.
- **Lo que hace bueno el diseño:**
  - **El obstáculo es la pregunta:** el objetivo se ve y está cerca, pero el tiro recto no sirve.
  - **La respuesta es el libro, no la puntería:** se resuelve cambiando la forma del hechizo, que es lo que hace único al juego.
  - **Barato:** una pieza que se enciende y un murete; la recompensa (cofre y atajo) se enseña con una cinemática corta.
- **Para nosotros:** P14 de `PROPUESTAS_SESION_MYSTRALIA_2026-11-21.md`.

## 7. Preguntas para decidir

1. ¿Te interesa el **disparador que lanza otra página** (A) para después de la demo o incluso dentro?
2. ¿Hechizos **sobre sí misma** (B)? Si sí, ¿cómo se marca al dibujar?
3. ¿Hacemos la **auditoría de glifos** con la prueba de parejas (D) para decidir cuáles entran en la demo?

---

## Fuentes

- Mondou, P. «Creative process of a procedural spell crafting system», Game Developer, 2016: https://gamedeveloper.com/design/creative-process-of-a-procedural-spell-crafting-system
- Entrevista a Mondou, Game Developer, 2019: https://gamedeveloper.com/design/-i-mages-of-mystralia-i-dev-dishes-out-spellcasting-wisdom-and-game-industry-real-talk
- Foro de Steam, «How do runes chain?» (respuesta del equipo, 9/5/2017): https://steamcommunity.com/app/529660/discussions/0/1326718197224753900/
- Reseña de Nintendo Life (6/10, 2019): https://www.nintendolife.com/reviews/switch-eshop/mages_of_mystralia
- Reseña de Hardcore Gamer (2017): https://hardcoregamer.com/reviews/review-mages-of-mystralia/257639/
- Guía de runas de Pixel Twelve: https://pixeltwelve.com/articles/mages-of-mystralia-spellcrafting-runes
- Wikipedia (fechas y notas): https://en.wikipedia.org/wiki/Mages_of_Mystralia
- Sin poder leer: wiki de Fandom (lista de runas), GameSpot, Destructoid, Giant Bomb y la guía completa de Steam.
