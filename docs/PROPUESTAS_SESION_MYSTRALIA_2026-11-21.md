# Propuestas de la sesión de referencias (21/11/2026)

21/11/2026 · contexto **dirección (análisis)** · **lista viva**: se va añadiendo a medida que Pablo juega y comenta. Al final de la sesión se ordena y se convierte en plan.

Recoge las propuestas de `REFERENCIAS_JUEGOS_2026-11-21.md`, `MAGES_OF_MYSTRALIA_2026-11-21.md`, `ECHOES_OF_MYSTRALIA_2026-11-21.md`, `DIBUJAR_EN_GAMEPLAY_2026-11-21.md` y lo observado jugando. Cada fila enlaza al apartado donde está explicada.

**Coste:** B bajo (constantes o una función), M medio (una pieza nueva o varios archivos), A alto (sistema nuevo o arte). **Estado:** propuesta, aprobada, hecha o descartada.

## Medir (para decidir con datos)

| Id | Propuesta | Origen | Coste | Estado |
|---|---|---|---|---|
| M1 | Cifras del libro en `Estadisticas`: aperturas, tiempo abierto, páginas reescritas, lanzamientos por página y receta, trazos no reconocidos, intentos de abrir el libro en combate | DIBUJAR §3 | B | **Aprobada (21/11), en pausa** |
| M2 | Mapa de prueba `SalaDibujo.txt` con cuatro encuentros y versión A/B con y sin dibujo | DIBUJAR §4 | M | Propuesta |
| M3 | Ficha de estudio de Mystralia, rellenada jugando | FICHA_ESTUDIO | — | En curso (Pablo juega) |

## Combate

| Id | Propuesta | Origen | Coste | Estado |
|---|---|---|---|---|
| C1 | **Escudos de elemento** en tres enemigos (madera → fuego, limo de fuego → agua, coraza → tierra) | REFERENCIAS §3.2 y §4 | M | Propuesta |
| C2 | Enemigos que escriben suelo (goblin con antorcha, limo de agua) | REFERENCIAS §3.2 | B | Propuesta |
| C3 | La tinta como tensión: coste por copias y permanencia, golpe F que devuelve tinta, gotas de tinta al matar | REFERENCIAS §3.3; MAGES §5 G | B | Propuesta |
| C4 | Enemigos con **tres soluciones** (la gárgola): regla de diseño para cada enemigo nuevo | MAGES §3 y §5 C | — | Propuesta |
| C5 | Todo ataque enemigo se esquiva moviéndose; quedarse quieta lanzando se castiga | ECHOES §5 D | — | Propuesta |
| C6 | Un jefe por bioma que se gana con su elemento, con fases que cambian el suelo | REFERENCIAS §3.6 | A | Propuesta |
| C7 | **Línea de apuntado** del arquero que se aclara antes de soltar | MAGES O3 | B | Propuesta |
| C8 | **Flecha más rápida con el mismo aviso** (el margen pasa del vuelo a la línea) | MAGES O3 | B | Propuesta |
| C9 | **Rebote visible** de flechas contra barreras y burbuja (reutilizar `_desviar_flecha` del muro de viento), con destello y sonido | MAGES O3 | B–M | Propuesta |
| C10 | **Burbuja que aguanta flechas normales** y solo revienta con elemento | MAGES O3 | B | Para decidir |
| C11 | Daño al chocar contra pared o caer a agua honda tras un empuje | REFERENCIAS §1.3 | M | Propuesta |
| C12 | Barra de aturdimiento (postura) y rendimientos decrecientes del control | REFERENCIAS §3.4 | M | Propuesta |
| C13 | **Jefe Ojáncano con la secuencia del ogro de Mystralia, tal cual** (ver abajo) | MAGES O6 (Pablo) | A | Aprobado como concepto |
| C19 | **Reacción al contacto barrera × proyectil**: cada proyectil enemigo tiene propiedades (materia, si arde) y una tabla dice qué hace cada barrera: el fuego quema la flecha, el agua apaga el fuego, la tierra para, el viento repele (devuelve al tirador, O12)… **con casos inefectivos a propósito** (una barrera de fuego no para un lanzallamas). Feedback de O12: destello, rastro de vuelta, chispas en el enemigo | MAGES O12 (Pablo) | M | **Aprobada la tabla de partida (Pablo, 21/11)**; sin programar |
| C20 | **Revisión de «no hace nada»**: feedback de ineficaz, no cobrar por lo que no se forma, puzles resolubles con el kit, previsión honesta, IA coherente (ver abajo) | Pablo (21/11) | B–M | Propuesta; el cobro sin efecto **pasa hoy** |
| C21 | **Suelo + viento te desplaza** (también a la jugadora), con el empuje que ya existe | Pablo (21/11) | B | Propuesta; viento fuera de la demo |
| C22 | **Regla de jefes: cada golpe repite su anticipación**. Un ataque siempre se anuncia con el mismo gesto, también dentro de una serie y en fases rápidas (se puede acortar, nunca quitar) | MAGES O16 (Pablo: «regla con todos los jefes») | — | **Regla aprobada (Pablo, 21/11)** |
| C23 | **Mouro zombi que resucita donde cae**: deja sus restos en el suelo; un anillo y un brillo morado avisan ~1,8 s antes de que se levante en ese mismo sitio | MAGES O16 (Pablo: «esta idea es la que vale») | M | Propuesta (ver abajo) |
| C24 | **Pareja élite: el escudero y el tanque** (Pablo, 22/11: «uno escuda a otro»). El escudero, desde lejos, protege al tanque con un **hilo** visible: mientras el hilo está, el tanque es inmune. Se corta golpeando al escudero o **poniendo algo sólido en medio**. Cuando cae uno, el otro se enfurece | MAGES O22 (Pablo) | M | Propuesta como enemigo o élite (ver abajo) |
| C25 | **Anticipación quieta y golpe seco** (Pablo, 22/11: «busquemos de inicio este output lag»): el enemigo **aguanta una pose de guardia quieto ~0,5–0,7 s** y luego golpea **en 2–3 fotogramas**. El aviso lo da el cuerpo; el golpe es rápido pero justo | MAGES O23 (Pablo) | B | Propuesta como **regla de partida** para los enemigos cuerpo a cuerpo (ver abajo) |
| C18 | **Regla del tiempo de reacción**: todo ataque que se quiera bloquear con barrera da, entre el primer aviso y el impacto, al menos **reacción (~0,3 s) + lo que tarda en salir la barrera + un margen**; si no, la barrera «no hace nada» (Pablo). Dos familias de ataque: **lentos que se bloquean reaccionando** (Mystralia: ~2 s a la vista, escudo 0,5 s antes) y **rápidos que se esquivan** o se paran con una protección ya puesta | MAGES O11 (Pablo) | B | Propuesta (ver abajo) |
| C14 | **Dragón jefe placeholder**: presentación con rótulo (solo jefes) y aliento con anticipación que barre y se bloquea con barrera | MAGES O8 (Pablo) | M | **Hecho (21/11), sin jugar** |
| C15 | **Encuadre de los jefes**: con la cámara del juego (tamaño 6) solo se ven unas 2 casillas por encima de la jugadora; un jefe grande o lejano se queda fuera de cuadro | C14 (fotos) | — | **Para decidir** (nueva opción d: carril, de O9) |
| C16 | **Exposición por puntos débiles**: 2–3 puntos que se aciertan desde lejos (cada uno queda marcado, por ejemplo ardiendo); al último, el jefe cae y expone un núcleo a ras de suelo unos 8–10 s, donde sí recibe daño | MAGES O9 (Pablo) | M | **Hecho en el dragón (21/11), sin jugar** |
| C17 | **Feedback de cuerpo grande**: temblor largo (≈3 % del alto, 0,2–0,4 s) solo para caer, golpear el suelo y levantarse; tirón corto y **destello blanco de la silueta entera** al golpear el núcleo; nada en golpes pequeños | MAGES O9 (Pablo) | B | **Hecho en el dragón (21/11), sin jugar** |

### C19 · Devolver proyectiles (de O12)

**Cómo estamos hoy** (`enemigos/combate_3d.gd`, `magia/lanzador_3d.gd`):
- Contra la **burbuja**, la flecha del goblin **revienta la burbuja y desaparece** (`burbuja_recibe`).
- Contra una **barrera sólida**, la flecha **desaparece** y la barrera encaja el daño (`solidez_para`).
- Contra el **muro de viento** (fuera de la demo), la flecha **se desvía** según la normal del muro y desaparece a los 0,2 s (`_desviar_flecha`). No vuelve al tirador ni hace daño.
- Para los hechizos **de la jugadora** ya existe un reflejo: un proyectil que choca con una solidez con **barrera + rebote** se refleja una vez (`HechizoVivo`, `_reflejado`).

**Propuesta:**
1. **Qué devuelve:** la protección de la jugadora (burbuja o barrera; cuál, en la decisión de abajo) devuelve la flecha **hacia el tirador**, no según la normal. Vuelve a la misma velocidad, **con el daño del enemigo** (12 la del arquero) y puede herir a otros enemigos en el camino.
2. **Feedback**, en este orden: destello blanco en estrella en el punto de contacto (2–3 fotogramas), un sonido seco de rebote, **rastro de puntos del color del proyectil** durante la vuelta y **chispas + destello del color** en el enemigo al darle (el destello por elemento ya existe, tarea H).
3. **La burbuja no revienta** con una flecha devuelta (enlaza con C10).
4. **Reutiliza** el código del muro de viento (`_desviar_flecha`) cambiando la dirección de salida por «hacia el tirador» y dejando que la flecha siga viva y golpee.

**Decisión de Pablo (21/11): no es una regla única, es una reacción al CONTACTO según propiedades.**
> «Lo importante es que el proyectil tenga propiedad para que haya barreras más efectivas, o programar la reacción al contacto. Con fuego debería quemarse y con viento repelerse. Esto puede hacer que haya casos donde una protección sea inefectiva; por ejemplo, en un lanzallamas una barrera de fuego no te protege. Hay que permitir casos inefectivos.»

Encaja con el pilar «las combinaciones emergen»: nadie escribe «la barrera de agua para la flecha»; la flecha tiene un material, la barrera un elemento, y una **tabla de contacto** dice qué pasa. Devolver (O12) es **una** de las reacciones posibles (la del viento), no la de todas.

**1. Cada proyectil enemigo lleva propiedades.** Las mismas que ya usan los hechizos (`Materia`: sólido, líquido, plasma, energía, gas) más si arde:

| Proyectil | Materia | Arde |
|---|---|---|
| Flecha del arquero | sólido (madera) | es inflamable (ya: A2) |
| Flecha ardiendo | sólido (madera) | sí |
| Chorro o bola de fuego (trampa dragón, aliento) | plasma | sí |
| Chorro o bola de agua | líquido | no |
| Piedra, pedrada | sólido (piedra) | no |
| Veneno del chamán | líquido | no |

**2. Tabla de contacto barrera × proyectil** (**aprobada por Pablo como punto de partida, 21/11**; ✓ protege, ✗ no protege, ~ a medias). Viento va aparte porque no está en la demo.

| Proyectil ↓ · Barrera → | **Fuego** | **Agua** | **Tierra** | *Viento (después)* |
|---|---|---|---|---|
| Flecha | ✓ **se quema**: ceniza y chispas | ✓ **se frena y cae** mojada | ✓ **se clava** y para | ✓ **se repele**: vuelve al tirador (O12) |
| Flecha ardiendo | ✗ **pasa** (ya arde) | ✓ **se apaga** y cae | ✓ se clava | ✓ se repele, avivada |
| Fuego (bola, chorro, **lanzallamas**) | ✗ **pasa** (el caso de Pablo) | ✓ **se apaga en vapor**; la barrera se gasta | ✓ para | ~ lo esparce: no protege de frente |
| Agua | ~ **se anulan en vapor** (las dos se pierden) | ✗ **pasa** (se suma) | ✓ para | ✓ se repele |
| Piedra | ✗ **pasa** | ✗ **la frena, no la para** | ✓ para | ✗ no la mueve |
| Veneno | ✓ **se quema** | ~ se diluye: hace menos daño | ✓ para | ✓ lo dispersa |

**3. Los casos inefectivos se tienen que LEER.** Si una protección no sirve, la jugadora tiene que entender por qué y no pensar que es un fallo: el proyectil la cruza con un efecto propio (la flecha ardiendo atraviesa la llama sin apagarse; la piedra rompe la cortina de agua) y suena un golpe sordo distinto. La previsión de reacciones (`PrevisionReaccion3D`) puede avisar antes de lanzar: «el fuego no para el fuego».

**4. Cómo entraría en el código (sin hacer):**
- Una tabla de datos `REACCIONES_CONTACTO[barrera][proyectil] = acción`, con un catálogo cerrado de acciones: `para`, `quema`, `apaga`, `frena`, `vapor`, `pasa`, `repele`. Generaliza `Lanzador3D.REACCIONES_BURBUJA` (hoy solo para la burbuja).
- Las flechas de `Combate3D` consultan la tabla al tocar una burbuja o una solidez (`_vuelo_flecha`, `combate_3d.gd:2336`), en vez de reventar o desaparecer siempre igual.
- **Ojo con lo que hay hoy:** la flecha que cruza una llama **sale ardiendo** (A2, `_flecha_toca_fuego`). Con una barrera de fuego, hoy podría encenderla en vez de quemarla. La tabla tiene que distinguir **cruzar una llama pequeña** (fogata: se enciende) de **chocar con una barrera de fuego** (se quema).
- **Tiempo de reacción (C18):** sigue valiendo. Elegir la barrera adecuada solo tiene sentido si da tiempo a sacarla.

**Lo que se descarta de antes:** las opciones a, b y c (devolver siempre, solo con rebote o solo justo a tiempo) quedan sustituidas por la tabla: devolver es lo que hace el viento.

### C22 · Regla de jefes: la anticipación se repite (de O16)

- **La regla:** cada ataque de un jefe tiene **su** gesto de aviso, y lo hace **cada vez**: en el primer golpe, en el quinto de una serie y en la fase de furia. En fases más duras se puede **acortar** el aviso, pero no quitarlo ni cambiarlo.
- **Cómo cumplen hoy:**
  - **Dragón placeholder:** cada aliento repite carga y anillos. **Cumple.**
  - **Ogro y Ojáncano** (C13): la secuencia de Mystralia ya lo hace: maza en alto antes de cada mazazo, agacharse antes de cada salto. **Cumple en el diseño.**
  - **Gólem y elemental:** revisados con fotos el 21/11 (abajo).
- **Se suma a C18:** el aviso acortado tiene que seguir dando tiempo de reacción si el ataque se quiere bloquear.
- **La regla tiene dos partes** (Pablo, 21/11): el **aviso en el suelo** y que **la animación anticipe el golpe**, y que **el golpe se vea cuando de verdad hace daño**.

**Revisión del gólem y el elemental (21/11, con ventana).** Herramienta nueva `herramientas/captura_anticipacion_enemigos.gd`: en la Sala del Gólem graba cada ataque desde que sale el aviso hasta 0,4 s después, un fotograma cada 0,1 s, con lo que le queda al aviso escrito; dos ataques de cada uno. Fotos en `docs/capturas/anticipacion_enemigos`.

| | Gólem | Elemental |
|---|---|---|
| Aviso en el suelo | Rectángulo, **1,43 s** (`AnimacionesGolem.INSTANTE_GOLPE`) | Rectángulo, **1,83 s** (0,6 de un clip de ~3,05 s) |
| Anticipación del cuerpo | Neutro hasta 0,5 s; **levanta los puños** de 0,6 a 1,3 s | **Abre y levanta los brazos** de 0,3 a 0,6 s |
| Cuándo se VE el golpe | **1,4 s** | **~0,85 s**: los puños llegan al suelo y se queda agachado e inmóvil |
| Cuándo HACE daño | **1,4 s**, cuando acaba el aviso | **1,8–1,9 s**, cuando acaba el aviso (y sale la onda de polvo) |
| ¿Cumple? | **Sí**: anticipa y el golpe coincide con el aviso | **No**: el golpe se ve **~1 s antes** de hacer daño. Parece que ya ha golpeado, la jugadora entra en la zona y el daño llega «tarde» |
| Repite el gesto en cada golpe | Sí (mismo clip) | Sí (mismo clip) |
| Furia | — | Solo acelera el paso (×1,3) y acorta el descanso (×0,7); el clip y el aviso no cambian: cumple |

**Causa del elemental:** `ELEM_MOMENTO_GOLPE = 0,6` está puesto a ojo («SIN medir: 0,55–0,65», `enemigos/combate_3d.gd:156`). Medido en las fotos, el contacto está hacia **0,28** del clip (~0,85 s de ~3,05 s).

**Propuesta de arreglo (sin hacer; Pablo, 21/11: «al plan final»):**
- Poner `ELEM_MOMENTO_GOLPE` ≈ **0,28** para que el daño caiga cuando se ve el golpe.
- Eso dejaría el aviso en ~0,85 s, corto para la regla C18. Para mantener ~1,4 s de aviso, **reproducir el clip más despacio** (`vel_anim` ≈ 0,6 en `_iniciar_ataque(1.0, ELEM_MOMENTO_GOLPE, _golpe_elemental)`, `combate_3d.gd:2087`): anticipación más larga y golpe sincronizado.
- Volver a pasar esta captura para comprobarlo.

### C23 · El mouro zombi que resucita donde cae (de O16)

**Hoy** (`enemigos/mouro_espectro_3d.gd`): con la mámoa abierta, al llegar a 0 de vida **se deshace sin dejar cuerpo** y a los `T_REBROTE` s **vuelve a salir por la mámoa**, con humo y la animación de levantarse. La pregunta que plantea es «¿de dónde vuelve y cómo corto el bucle?» (tapar la mámoa).

**La idea de Mystralia:**
1. **Deja restos donde cae** (huesos y trapos en el suelo), que se ven y siguen ahí.
2. **Aviso en el sitio:** antes de volver, un **anillo** alrededor de los restos y un **brillo morado** que crece, **~1,8 s**.
3. **Se levanta en ese mismo sitio**, no en la mámoa.

**Cómo encajarlo con lo nuestro** (propuesta):
- **La mámoa sigue siendo la fuente:** mientras esté abierta, los restos resucitan; tapada, ya no. El bucle se corta igual, pero ahora **se ve en cada cuerpo** cuál va a volver y cuándo.
- **Los restos admiten elementos** (tabla de contacto, C19): **fuego los quema** y ese ya no vuelve; **tierra los entierra** (como tapar una mámoa pequeña); **agua no hace nada** (caso ineficaz que se lee). Así la jugadora tiene tres respuestas: rematar con fuego, tapar con tierra o tapar la mámoa.
- **Se reaprovecha casi todo:** la animación de levantarse (`Getting_Up`, rol `cast_surgir`) y el humo ya existen; lo nuevo es dejar los restos, el anillo con brillo morado y levantarse en el sitio en vez de en la mámoa.
- **Color:** el morado no está en la paleta de los elementos del mundo; para lo «no muerto» lo distingue bien del fuego, el agua y la tierra.

### C25 · Anticipación quieta y golpe seco (de O23)

**En Mystralia, medido** (O23): el goblin se agacha con la porra atrás y **aguanta quieto 0,5–0,7 s**, mirando a la jugadora. Luego **salta 2–3 cuerpos en ~0,07 s** y golpea. No hay marca en el suelo.

**Cómo estamos** (`enemigos/combate_3d.gd`, guerrero goblin):
- **Carga quieto `PREPARAR_GOLPE` 0,6 s** (desde A1, con el círculo en el suelo desde el principio).
- Después reproduce el clip `LeftSlash`, y el golpe cae en el **0,19 del clip** (`MOMENTO_GOLPE_GUERRERO`): **~0,6 s más de animación** hasta el contacto.
- El encogimiento de anticipación (`ANTICIPA_ESCALA`) es **un pulso de 0,3 s** (0,12 para encogerse y 0,18 para volver), no una pose sostenida.
- **Total: ~1,2–1,33 s de aviso**, pero el golpe es **un balanceo lento de 0,6 s**, no un golpe seco.

**La diferencia** no es el total, es el **reparto**: Mystralia hace la anticipación **larga y quieta** y la ejecución **instantánea**. Nosotros tenemos una espera sin pose clara y luego un golpe que se ve venir despacio. Lo suyo se siente más rápido y más justo a la vez.

**Propuesta, como regla de partida para los enemigos cuerpo a cuerpo** (guerrero, asesino, loberno, canouro):
1. **Pose de guardia sostenida** durante toda la anticipación: el cuerpo encogido (`ANTICIPA_ESCALA` mantenido, no un pulso), el arma atrás (el fotograma de máxima carga del clip, congelado) y **quieto**. Ese es el aviso principal; el círculo del suelo es el secundario.
2. **Anticipación de 0,5–0,7 s** (la de Mystralia). En el guerrero son los 0,6 s de `PREPARAR_GOLPE` que ya decidiste mantener.
3. **Ejecución en ≤ 0,1 s**: el tramo del clip desde la carga hasta el contacto, reproducido muy deprisa, o una **acometida** corta hacia la jugadora como la del goblin.
4. **Recuperación visible** después (ya existe: el «vulnerable al terminar» del guerrero con escudo).

**Ojo:**
- **El aviso total baja** de ~1,3 s a ~0,7 s. Encaja en la regla C18: el cuerpo a cuerpo **es de esquivar**, no de bloquear, y la voltereta perfecta (ventana de 0,6 s) sigue cabiendo.
- **El círculo del suelo** tiene que durar exactamente la anticipación (A1 ya lo hace desde el principio de la carga).
- **Regla de jefes C22:** la misma estructura vale para cada golpe de un jefe (pose sostenida y golpe seco), acortando la pose en fases duras pero nunca quitándola.

### C24 · Pareja élite: el escudero y el tanque (de O22)

**En Mystralia:**
- Un tanque grande de cuerpo a cuerpo y un escudero pequeño que se queda en el borde.
- El escudero une al tanque con un hilo de luz y le pone una burbuja: mientras dura, el tanque no recibe daño.
- Al golpear al escudero, el hilo se corta, el escudero queda aturdido (estrellas) y el tanque es vulnerable.
- Cuando cae el tanque, el escudero crece y pelea solo, más rápido (acometidas con copias, andanadas).

**Cómo encaja con lo nuestro:** casi todo existe ya.

| Pieza | Qué hay | Qué falta |
|---|---|---|
| **El escudero** | El **chamán v2** ya escuda a sus aliados (escudo de naturaleza de 25, que el fuego quema; `enemigos/chaman_3d.gd`) y su ritual se corta si le pegan | Un escudo **sostenido por un hilo** (mientras el hilo está, inmunidad), en vez del escudo de vida que se gasta |
| **El hilo** | `HiloLuz3D` (`presentacion/hilo_luz_3d.gd`): cinta de luz que une dos cosas, del color del elemento | Que lo **corte lo sólido**, con la misma regla que el aliento del dragón: una barrera de tierra entre los dos **corta el escudo**. Eso es lo nuestro: se resuelve con un hechizo, no solo con daño |
| **El tanque** | El gólem (inmune de pie) o un goblin con coraza (B1) | Nada: el hilo se le aplica encima |
| **Aturdir al escudero** | Estado `aturdido` en `Combate3D` | Al cortarle el hilo de un golpe, aturdido unos 3–4 s. Si el hilo se corta con una barrera, el escudero **intenta rodearla** para volver a unirse (la IA ya rodea barreras) |
| **Furia del que queda** | La furia del elemental (×1,3 de velocidad, ×0,7 de descanso) | Aplicarla al superviviente. Si queda el escudero: acometidas y andanadas. Si queda el tanque: más rápido y sin descanso |
| **Coordinación** | El coordinador de encuentros (G2) ya hace que un enemigo **proteja al chamán** | El tanque se pone entre la jugadora y el escudero: es la «protección» de G2 con un motivo claro |
| **Presentación** | `PresentacionJefe` (rótulo y barra) | Dos barras, una por enemigo, si va como mini-jefe |

**Tres formas de resolverlo** (C4, enemigos con tres soluciones):
1. **Golpear al escudero:** flecha de fuego o de agua desde lejos.
2. **Cortar el hilo con una barrera de tierra** entre los dos.
3. **Quemar el escudo** con fuego, como el escudo de naturaleza de hoy. Esto es opcional: si se quiere que el hilo sea la única regla, el escudo no se quema.

**Como élite, no como jefe:** sirve de **encuentro de reto** (salas opcionales, REFERENCIAS §3.5) o de **mini-jefe** al final de una zona de la demo. Va bien en el Bosque, con un goblin con coraza de tanque y un chamán de escudero, o en la Cueva, con el gólem y un chamán.

**Variantes de otro elemento** (D1): el hilo y el escudo del color del escudero. Uno de agua se corta con fuego (vapor) y uno de fuego se corta con agua: mismo enemigo, otra solución.

### C20 · Cuando una interacción no hace nada (revisión, 21/11)

**Principio de Pablo:** que una interacción no sea efectiva o «no haga nada» **está bien**; el juego tiene que permitirlo. Esta revisión busca qué puede salir mal cuando pasa, para que «no hace nada» se lea como una regla del mundo y no como un fallo.

| # | Riesgo | Ejemplo en el juego | Propuesta |
|---|---|---|---|
| 1 | **Parece un fallo** del juego, no una regla | La flecha ardiendo cruza la barrera de fuego como si no existiera; un hechizo al cuerpo del dragón no hace nada | **Un feedback común de «ineficaz»**: golpe sordo, chispa gris y, la primera vez, un rótulo corto («El fuego no para el fuego»). Ya hay piezas: el destello gris y el rótulo «Piedra» del gólem (`COLOR_FLASH_PIEDRA`, `combate_3d.gd:74`) |
| 2 | **Cobrar tinta por nada** | **Pasa hoy**: tierra + barrera sola en el carril del dragón sale con **0 manifestaciones y cobra 12 de tinta** (registro de la prueba: de 88 a 76) | Si un hechizo no se puede formar, **rechazarlo antes de cobrar**, como ya hace ᛒ sobre agua (`glifo_suelo.gd:12`). Si se forma pero resulta ineficaz contra algo, cobrar es justo: fue una elección |
| 3 | **Puzles sin solución** | Si un puzle pide protegerse de un chorro de fuego (X5) y en esa pasada solo se tiene fuego, la barrera de fuego no sirve: no se puede resolver | Revisar cada puzle contra el kit que se tiene en ese momento (la ruta de §5 de PUZLES_DEMO); que los escenarios automáticos lo comprueben |
| 4 | **La previsión miente** | La previsión enseña la barrera como protección cuando no lo es | `PrevisionReaccion3D` lee la misma tabla de contacto (C19) y marca el caso ineficaz |
| 5 | **Peor que nada** | Hoy una flecha que cruza fuego **sale ardiendo** (A2): una barrera de fuego podría hacer que la flecha haga más daño | **Decidir**: ¿se permiten casos contraproducentes o solo ineficaces? Mi propuesta: permitirlos solo si se ven venir (la flecha se enciende de forma visible antes de llegar) |
| 6 | **La IA se comporta raro** | Desde la entrada 551 los enemigos rodean las barreras de la jugadora; rodearían también una que no les para | Que la IA rodee solo las barreras que de verdad le cortan el paso o el disparo (misma tabla) |
| 7 | **¿Se gasta la barrera?** | Un proyectil ineficaz que la cruza ¿le quita aguante? | Proponer: si **pasa**, la barrera no se gasta; si la **anula** (vapor), se gastan las dos |
| 8 | **Pruebas que esperan efecto** | Las pruebas con «golden» (`prueba_catalogo_reacciones`, `prueba_dano_tinta`) cambiarán al meter la tabla | Regenerarlas a propósito y apuntarlo, como se hizo el 21/11 en la entrada 550 |

### C21 · Suelo + viento te desplaza (Pablo, 21/11)

**Hoy:** ᛒ suelo con viento es una **trampa de un solo uso** que solo salta cuando entra un **enemigo**: explota y le aplica el golpe del viento (`magia/glifo_suelo.gd:14-16`). No mueve a la jugadora.
**Idea de Pablo:** aprovechar lo que existe para que **suelo + viento desplace a quien lo pisa, también a la jugadora**: una corriente en el suelo que te lanza hacia donde sopla. Es movilidad hecha con el sistema de siempre (el empuje del viento, `Lanzador3D.empuje_de_golpe`, y `Jugador3D.push`, que ya usan el gólem y las trampas) y no una pieza nueva.
**Aviso:** el viento está fuera de la demo (18/11). Queda para después, o como pieza del mundo (una losa de viento del escenario) si se quiere en la demo sin el sello.

### C18 · Tiempo de reacción para bloquear (regla)

- **La cuenta:** `aviso + vuelo ≥ 0,3 s (ver y decidir) + salida de la barrera + 0,2 s de margen`.
- **Salida de la barrera, MEDIDA el 21/11** (`herramientas/medir_salida_barrera.gd`, Sala del Gólem, lanzamiento inteligente con la animación de lanzar, tiempo de juego desde la pulsación hasta que la protección existe; dos veces cada una, siempre igual):

  | Barrera | Sale en |
  |---|---|
  | Fuego o agua, sola o con flecha | **0,53 s** (32 fotogramas a 60 fps) |
  | Tierra, sola o con flecha | **0,70 s** (la tierra va ×1,3, `CastPoints.ESCALA_TIEMPO`) |

  Con el lanzamiento de mantener y soltar se suma lo que la jugadora tarde en soltar. En esta sala, tierra + barrera sola sí sale (en el carril del dragón salía con 0 manifestaciones: depende de dónde se lanza, falta mirar por qué).
- **Mínimo que sale de la cuenta:** **≈ 1,0 s** entre el primer aviso y el impacto para bloquear con fuego o agua, **≈ 1,2 s** con tierra.
- **Cómo estamos hoy:**

  | Ataque | Aviso + llegada | ¿Se puede bloquear reaccionando? |
  |---|---|---|
  | **Aliento del dragón** | 0,9 s de carga + 0,8 s de anillos = **1,7 s** | **Sí**, con cualquier elemento (la prueba lo confirma con barrera + flecha) |
  | **Arquero goblin** | 0,9 s de tensar + 0,45–0,9 s de vuelo = **1,35–1,8 s** | **Sí, justo**; a poca distancia (vuelo corto), con tierra no |
  | **Golpe del guerrero goblin** | 0,6 s de preparar | **No**: se esquiva (está bien que sea de esquivar) |
  | **Trampa dragón** | 0,5 s de aviso | **No**: se cronometra o se tapa antes |
  | **Mystralia, como referencia** | ~2 s a la vista | Sí, con mucho margen |
- **Lectura:** el aliento cumple la regla; el arquero, por los pelos; el resto son ataques de esquivar o de trampa, y está bien que lo sean. **Si un ataque nuevo se diseña para bloquearse, que dé al menos 1,2 s** (así vale cualquier elemento) o, mejor, **≈2 s como Mystralia**, para que sacar la barrera sea una decisión y no un reflejo.
- **Ojo con C8** («flecha más rápida con el mismo aviso»): acorta el tiempo para reaccionar. Encaja solo en ataques que se **esquivan**, no en los que se quieren **bloquear**.
- **Lo que falta para cumplir la regla:** una protección que se pueda sacar rápido y delante de ti. Hoy la barrera sola de tierra no lo hace (sale con 0 manifestaciones en el carril del dragón, C14). La respuesta probable es el botón «sobre mí» de H10 con la barrera = escudo (H2).

### C14 · El dragón jefe placeholder (hecho el 21/11)

- **Dónde verlo:** `escenas/PruebaSalaDragon.tscn` (mapa `mundo/datos_nivel/mapas/SalaDragon.txt`). Ponte a 2 casillas del dragón (está en la fila de arriba) para que se presente.
- **Código:** `objetos/dragon_jefe_3d.gd` (`DragonJefe3D`, sobre la base de las trampas de pared: su chorro es el haz de fuego de verdad) y `enemigos/presentacion_jefe.gd` (`PresentacionJefe`, el rótulo y la barra; **sirve para cualquier jefe**). Pieza de mapa nueva `dragon_jefe` en `escenas/puzle.gd`.
- **Lo que hace:** duerme bajo el suelo; al acercarte sale (1,6 s), se le encienden los ojos y aparece el rótulo «Guardian del foso / DRAGON» (4,6 s). Luego aparece la barra y empieza el ciclo: reposo 2,2 s → carga 0,9 s (cabeza atrás y hacia el lado por el que empezará, boca encendida, suena la carga) → anillos 0,8 s → aliento 2,6 s que barre 110° → recupera 1,2 s (recibe ×1,5). Alterna el lado de empezar. El agua mientras carga o sopla lo aturde 3 s (es el sitio para la barba del Ojáncano).
- **Cómo se bloquea:** algo sólido entre la boca y la jugadora corta el chorro (la barrera encaja 4 de daño por soplo); también vale la burbuja y moverse.
- **Todo se ajusta** en las `static var` del principio de `dragon_jefe_3d.gd` y de `presentacion_jefe.gd`.
- **Prueba:** `herramientas/escenario_dragon_jefe.gd`, 0 fallos. Un aviso honesto: la barrera de tierra sola corta el chorro pero el barrido la rodea y la alcanza un soplo; con barrera + flecha (muro delante), ninguno. La flecha de agua tarda 0,87 s en llegar, dentro de los 1,7 s de carga y anillos.
- **Fotos:** `docs/capturas/dragon_jefe/juego` (cámara del juego) y `docs/capturas/dragon_jefe/abierta` (cámara más abierta, tamaño 11), con `herramientas/captura_dragon_jefe.gd`.
- **Placeholder de verdad:** el dibujo es de primitivas, no hay sonido de rugido (usa el de carga del fuego) y no se mueve de su casilla.

### C15 · Encuadre de los jefes (decisión)

En las fotos con la cámara del juego, el dragón se queda **cortado por arriba incluso a 2 casillas**; con la cámara abierta se ve entero. Mystralia enseña la arena completa. Opciones:
- **a)** Los jefes pelean **cerca y bajos**: arenas pequeñas y jefes que no pasen de 2 casillas por encima de la jugadora.
- **b)** Las **salas de jefe tienen su propio tamaño de cámara fijo** desde que entras (no cambia durante el combate, así que no es un cambio de vista).
- **c)** Los jefes se colocan **abajo o a los lados** de la arena, donde la cámara ve más.
- **d)** *(de O9, el jefe del bosque de Mystralia)* **Arena en carril**: la jugadora se mueve de izquierda a derecha por una franja estrecha (1–2 filas) al pie del jefe, que está detrás, siempre a la misma distancia. Con la cámara que sigue a la jugadora, el jefe queda siempre a la misma altura de pantalla. Los ataques barren el carril (como el aliento del dragón) o caen en él. Es la que mejor encaja con la cámara fija.

### Aplicado al dragón placeholder (hecho el 21/11, sin jugar)
1. **Carril**: la Sala del Dragón es una franja de 2 filas (3 y 4) al pie del dragón (8,1), con **agua honda al sur** en vez de muro (un muro pegado al carril tapaba a la jugadora y salía su silueta). El aliento barre el carril.
2. **Puntos débiles**: tres cristales morados (punta de cada ala y pecho). Cualquier hechizo los enciende y se quedan ardiendo; brillan más tras cada aliento. Con los tres, cae (0,8 s), apoya la cabeza y el **núcleo rosa** queda a tiro 8 s: es lo único que le quita vida (×1,5). Luego se levanta y los cristales se apagan. El cuerpo no recibe daño.
3. **Temblor y destello**: `Vfx3D.temblor(0,6)` al caer y al levantarse; tirón corto de cámara y **silueta entera en blanco** (mínimo 2 fotogramas dibujados) al golpear el núcleo.
4. **Lo que se ha visto en las pruebas y fotos:**
   - **Con la cámara del juego el dragón de pie sigue cortado por arriba**, aun con el carril (caído sí se ve el núcleo). El carril fija la distancia, pero la cámara de tamaño 6 no da para un jefe alto: **C15 sigue abierta y la opción que lo arregla es la b** (tamaño de cámara propio de la sala de jefe). Las fotos con cámara 10 (`docs/capturas/dragon_jefe/abierta`) enseñan cómo se vería.
   - **La barrera sola de tierra no protege del aliento**: en el carril sale con 0 manifestaciones y no corta nada. Con barrera + flecha (muro delante), sí. Enlaza con H2 (hechizos sobre sí misma) y C10 (burbuja).
   - **El agua que queda delante apaga las bolas de fuego** que pasan por ella (en la prueba, el agua de un acierto en el cristal del pecho apagaba luego el fuego al núcleo). Es coherente con el juego, pero en el combate puede confundir: el jugador moja el pecho y luego no puede quemar el núcleo.
   - **Balance de partida**: una flecha de fuego al núcleo quita 20 (de 300). En 8 s caben unas 6–8 flechas: harían falta 2–3 caídas. Ajustable en `VIDA` y `MULT_NUCLEO`.

### C13 · El Ojáncano (jefe inicial)

**Concepto de Pablo:** el Ojáncano (gigante de la mitología cántabra) con la **barba en llamas que se le apaga**, y la secuencia de ataques del ogro de Mystralia **tal cual**. Hoy solo existe como idea (memoria del 18/11: «solo concepto, falta todo»); no hay código ni mapa.

**Secuencia (de O6):**
1. **Entrada de un salto.**
2. **Barridos persiguiendo** (2–3 golpes laterales).
3. **Mazazo vertical**: aviso ~0,4 s con la maza en alto, nube de polvo, **0,6 s quieto** = ventana para pegarle.
4. **Retirada a un borde y carga de salto**: se agacha ~0,4 s, vuela ~0,8 s con sombra en el suelo y cae junto a la jugadora.
5. **Mazazo con onda** de polvo que avanza por el suelo.
6. **Peonza** de ~1,6 s y remate con mazazo.

**Cómo encaja lo nuestro** (propuestas para decidir; la secuencia no se toca):
- **La maza** puede ser un tronco arrancado, como en la leyenda.
- **La barba encendida** es su punto débil: el agua la apaga y lo deja **aturdido unos segundos** (la ventana grande). Con la barba encendida, sus mazazos podrían **dejar el suelo quemado** (enemigo que escribe suelo, C2).
- **Piezas que ya existen para reutilizar**: aviso de ataque en el suelo (`AvisoAtaque3D`), golpe de área con aviso del elemental (`ELEM_ALCANCE_GOLPE`, `ELEM_ANCHO_GOLPE`) y su furia (`ELEM_FURIA_*`), y el salto con acometida del limo (`limo_3d.gd`).

**Problema de orden que hay que resolver.** Si es **jefe inicial**, en la primera pasada del Bosque solo se tiene fuego, flecha y barrera, y **el agua llega después** (Monte Sumicio). Opciones:
- **a)** Se vence en la primera pasada **sin apagar la barba**: solo con las ventanas de los mazazos. Lo de apagarla queda para otro encuentro más tarde.
- **b)** Es el jefe del **Bosque a la vuelta**, ya con agua: deja de ser «inicial», pero apagar la barba es el examen del sello recién ganado (como Zelda).
- **c)** La barba se apaga con **algo del escenario** (una tinaja, un charco, una cascada a la que hay que atraerlo), no con el sello de agua.

## Gamefeel

| Id | Propuesta | Origen | Coste | Estado |
|---|---|---|---|---|
| G1 | Cancelar el final del lanzamiento con la voltereta; tolerancia de pulsación también en voltereta y golpe F | REFERENCIAS §1.1 | B | Propuesta |
| G2 | Golpe recibido escalado, aviso de vida baja | REFERENCIAS §1.5 (E3) | B | Propuesta |
| G3 | Cámara lenta al caer el último enemigo de la sala | REFERENCIAS §1.4 | B | Propuesta |
| G4 | **Regla de legibilidad**: los avisos enemigos siempre por encima de nuestros efectos | ECHOES §5 B | M | Propuesta |
| G5 | Vibración del mando por golpe dado, recibido y lanzado | REFERENCIAS §1.3 | B | Propuesta |
| G6 | El libro reacciona en combate (tiembla al recibir daño, la página lista brilla) | REFERENCIAS §1.6 | M | Propuesta |
| G7 | **Feedback de la jugadora al recibir un golpe** (Pablo, 22/11: «creo que es pobre»): revisado con fotos; **desaparece** durante la invulnerabilidad, no tiene destello en el cuerpo y un golpe de 12 se ve igual que uno de 45 (ver abajo) | Pablo (22/11) | B | Propuesta |

### G7 · Feedback de la jugadora al recibir un golpe (revisión, 22/11)

**Cómo se ha mirado:**
- Herramienta nueva `herramientas/captura_feedback_jugadora.gd` (Sala del Gólem, con ventana): tres golpes, de 12 (flecha), 45 (puñetazo del elemental) y 15 dejándola con poca vida.
- Fotos cada 2 fotogramas durante 0,9 s. Hojas en `docs/capturas/feedback_jugadora/hoja_*.png`.

**Lo que hay hoy** (`Jugador3D.recibir_dano`, `jugador/jugador_3d.gd:643`; `Sensacion3D.dano_recibido`, `presentacion/sensacion_3d.gd:498`):
- **Viñeta roja** a pantalla completa: dura 0,22 s, con opacidad de 0,3 a 0,5 según el golpe (×1,3 si la deja baja).
- **Temblor** de 0,2 a 0,5 según la fracción de vida perdida.
- **Hitstop de 0,05 s**, o 0,12 s si la deja por debajo del 25 %.
- **Sonido** `dano_jugadora`, más grave cuanto mayor es el golpe.
- **Número rojo** encima, siempre del mismo tamaño, y **empujón** de 4,5.
- **Animación `hit`** (0,35 s) e **invulnerabilidad de 0,4 s**, en la que el modelo **parpadea apagándose entero** (`pj.visible`, `jugador_3d.gd:1712`).
- **Vida baja:** borde rojo, la barra late y suena un latido. Esto funciona bien en las fotos.

**Lo que se ve en las fotos:**

| # | Problema | En las fotos |
|---|---|---|
| 1 | **Desaparece** al recibir el golpe | En 0,14 y 0,27 s **no está**: solo se ve el polvo del empujón. Parece que se ha ido, no que la han golpeado. Es justo el momento que más hay que ver |
| 2 | **No hay destello en el cuerpo** | Los enemigos se ponen blancos y luego del color del golpe, y se aplastan. Ella no cambia de color: el golpe solo se ve en la pantalla (viñeta) y en el número |
| 3 | **Un golpe de 12 y uno de 45 se ven casi iguales** | Mismo número (tamaño y color), misma desaparición y misma pose. La diferencia (temblor y viñeta algo mayores) no se nota en las fotos |
| 4 | **El hitstop de 0,05 s no se siente** | Es menos de 2 fotogramas a 30 fps. Los enemigos van de 0,04 a 0,10 s y los juegos de referencia dan 0,1–0,2 s al golpe grande de la jugadora |
| 5 | **La viñeta dura muy poco** | En el golpe pequeño casi no se ve; a los 0,14 s ya no está |
| 6 | **No dice de dónde vino** | Ni la viñeta ni el empujón marcan claramente la dirección del golpe |

**Propuestas, por orden de impacto:**
1. **Que no desaparezca nunca.** La invulnerabilidad se enseña con un **parpadeo de color** (emisión blanca o roja que late) o con transparencia, no apagando el modelo. Ya existe la pieza: `Jugador3D.destello_color` (el destello verde al beber, `jugador_3d.gd:1442`).
2. **Destello en el cuerpo**, como el de los enemigos: blanco 0,05 s y luego rojo 0,2 s, con un **aplastamiento** corto (`SQUASH` de `Combate3D`). Es el aviso principal de «me han dado».
3. **Escalar con el golpe**, con tres tamaños:
   - **pequeño (<15 % de la vida):** destello, número normal y sonido;
   - **medio:** además, hitstop de 0,08 s y número más grande;
   - **grande (≥30 %):** hitstop de 0,15 s, número grande que salta (como los ×1,7 de los enemigos), viñeta más larga (0,4 s), temblor máximo y un **retroceso con pose de tambaleo** más largo.
4. **Viñeta con dirección:** más oscura en el lado del que viene el golpe (el shader ya recibe la fuerza; habría que añadir el ángulo).
5. **Sonido de voz** (un quejido corto) en tres tamaños, además del golpe. Hoy es un solo sonido que cambia de tono.
6. **Revisar la invulnerabilidad de 0,4 s:** con el coordinador (G2) pueden pegar dos a la vez, y 0,4 s es corto. Propuesta: 0,6–0,8 s, bien visible (punto 1).

**Sin revisar todavía:** los golpes que **paran** la barrera, la burbuja o el bálsamo. Habría que comprobar que suenen y se vean distintos, como un golpe bloqueado y no como nada. Tampoco se han revisado el daño ambiental (llama propia, suelo electrificado), que hoy solo pone la viñeta y el número, ni el golpe que mata.

## Hechizos y libro

| Id | Propuesta | Origen | Coste | Estado |
|---|---|---|---|---|
| H1 | **Disparador que lanza otra página** («al impactar → página 2») | MAGES §5 A | M | Propuesta |
| H1b | **Runa «Impacto» (Pablo: «un concepto de runa que me gusta»)**: «lanza un disparador de forma automática al golpear un objetivo o un obstáculo» (texto de Mystralia). Es el disparador de H1 en su forma más clara: **al impactar, hace X** | MAGES O17 (Pablo) | M | Anotado (usos abajo) |
| H2 | **Hechizos sobre sí misma** (dash, escudo) | MAGES §5 B | M | Respuesta de Pablo (21/11): un **botón propio** («Ego» en Mystralia), ver H10 |
| H3 | **Auditoría de glifos** con prueba de parejas; recortar los que no se distinguen | MAGES §5 D | B | Propuesta |
| H4 | **La vecindad en la corona** sustituye al orden de dibujo (o al menos se enseña en la página) | ECHOES §5 A; MAGES §5 E | M | Para decidir |
| H5 | **Página de presentación** de cada glifo o sello nuevo: nombre, una o dos frases de uso, animación | MAGES O1 (Pablo) | M | Propuesta |
| H6 | **El glifo como verbo, enseñado con un antes/después**: en la presentación (H5) y en la ficha del libro, el mismo hechizo **sin el glifo y con él**, en dos bases (por ejemplo, flecha: bola que se queda → proyectil; barrera que te rodea → muro que avanza) | MAGES O7 (Pablo) | M | Propuesta |
| H7 | **Catálogo de glifos en el libro** por familias, con los que faltan **bloqueados** (se ve cuánto queda por descubrir) y etiqueta de **nuevo**; reutilizar el patrón de la mochila | MAGES O7 | M | Propuesta |
| H8 | **Ficha por glifo** al señalarlo: nombre, una frase y **en qué bases vale** («con bola, barrera y…»); el texto sale de `Hechizo.diferencia()` donde se pueda | MAGES O7 | B | Propuesta |
| H9 | **Coste visible al dibujar**: una barra bajo la página que crece con cada glifo, como la de Mystralia (enlaza con E4 de PROPUESTAS_COMBATE) | MAGES O7 | B | Propuesta |
| H12 | **Página de dos círculos** (Pablo, inspirada en *Witch Hat Atelier*): Hechizo 1 + condición + Hechizo 2 en la misma página; el segundo puede ser de otro elemento | Pablo (21/11) | M–A (casi todo libro) | **Aprobada como hechizo muy avanzado (Pablo, 21/11)**: 2 sellos y 6 glifos en total, un sello por círculo |
| H11 | **ᛒ suelo que viaja deja un rastro**: con ᛇ flecha, lo que se planta avanza y deja **un camino** de casillas (plataformas de tierra sobre el vacío, capa de tierra que frena, fila de trampas); con ᛃ retorno, el camino **se curva y vuelve** (arco o corral). Sale de nuestras reglas R1 y R2, sin casos escritos a mano | MAGES O14 (Pablo) | M | Propuesta (ver abajo) |
| H13 | **ᚠ repetición = un elemento más saliendo A LA VEZ, en cualquier forma** (Pablo, 22/11, captura de la runa Repetición de Mystralia: tres bolas de fuego paralelas). Cada ᚠ suma una copia que sale junto a las otras: bolas, haces, barreras… | MAGES O18 (Pablo) | B–M | Propuesta (ver abajo) |
| H15 | **Disparador «De una vez»** (Pablo, 22/11, captura de Mystralia: «Al usar un conjuro lanza a la vez un disparador»): el segundo hechizo sale **en el mismo momento** que el primero, no al impactar. En lo nuestro es una **tercera condición de la página de dos círculos** (H12): «a la vez», además de «al impactar» y «al acabar» | MAGES O20 (Pablo) | B (sobre H12) | Anotado (ver abajo) |
| H16 | **Nombre de cada hechizo** (Pablo, 22/11, captura del selector de Mystralia: «Immedi #2», «Hielo doble», «Camino de tierra», «Dash» junto a cada botón): cada página tiene un **nombre**, que sale solo de la receta y que la jugadora puede **cambiar** en el libro. Se ve en el HUD y en el selector (H10) para saber qué se lanza | MAGES O28 (Pablo) | B–M | Propuesta (ver abajo) |
| H14 | **Mejoras de glifos tras jugar y estudiar el código de Mystralia** (Pablo, 22/11): Buscar que conserva el objetivo, distribuciones de Repetición, Barrera que dice qué para, Carga unificada con la sobrecarga, Crecer y Permanencia con coste propio, conectores (= H12), Rebote como condición, Flecha sin daño implícito y Pulso frente a hijos. Revisado con el código: **qué glifos suben el daño** como regla general | `MEJORAS_HECHIZOS_MYSTRALIA_2026-11-22.md` | B–A (por punto) | Propuesta revisada; orden revisado al final del documento |
| H10 | **Hechizos 1–4 con variantes**: cuatro botones fijos (uno puede ser «sobre mí», que resuelve H2), cada uno con varios hechizos guardados; un **selector elige cuál está activo** en cada botón y el botón solo lanza. El HUD enseña el nombre del activo en cada botón | MAGES O10 (Pablo) | M | **Decidido el gesto (Pablo, 21/11): selector** |

### H1b · Runa «Impacto»: al golpear, hace X (de O17)

**En Mystralia:** es un **disparador** (familia aparte de cualidades e incrementos). Su ficha dice: «Lanza un disparador de forma automática al golpear un objetivo o un obstáculo». Al tocar algo, el hechizo lanza el hechizo enganchado.
**En lo nuestro: YA EXISTE** (C3, 6/11/2026; comprobado en el código el 21/11). No hay glifo nuevo: es **⧖ `retardo` dibujado ENTRE dos formas**. Con flecha + ⧖ + barrera, la flecha vuela y, al pararse (golpe, muro, suelo o alcance), **nace la barrera en ese punto**, con el elemento de la página. Está en `nucleo/hechizo.gd:30-41` (`DISPARADOR`) y `:452-499`, y en `magia/hechizo_vivo.gd:1781-1814` (`_crear_hijo`, `_hijo_de_pagina`). El hijo cobra un recargo (`Dano.K_HIJO` = 0,10), la profundidad máxima es 2, no nace si la flecha vuelve con ᛃ, y lo comprueba `herramientas/prueba_bloque_b5_c3.gd`.

**Lo que le falta para usarlo en la demo:**
1. **⧖ no está en el kit de la demo** (flecha, línea, barrera, altura, pulso y suelo). O entra ⧖, o el papel de disparador pasa a otro glifo del kit.
2. **No se ve:** depende del orden de dibujo, que el libro no enseña (el mismo problema de H4). La página tendría que mostrar «flecha → al impactar → barrera» con una flecha entre las dos partes. `Hechizo.hijo_siguiente` ya guarda el hijo para que la interfaz lo enseñe.
3. **ᛒ suelo no puede ser el hijo:** `DISPARADOR["despues"]` solo admite flecha, barrera y líneas. Añadir `suelo` es una línea de datos y da la trampa en el punto de impacto (uso 2 de abajo).
4. **El hijo es del mismo elemento.** Para que sea de otro (agua que deja tierra), hace falta H1: que el hijo salga de **otra página** (`Lanzador3D.receta_de_ficha`) en vez de lo dibujado detrás del ⧖.
5. **Feedback:** que el hijo **se vea nacer** en el punto de impacto, con destello y sonido propios.

**Usos posibles con fuego, agua y tierra:**

| Receta (página 1 → al impactar → página 2) | Qué consigue | Dónde sirve |
|---|---|---|
| Flecha de agua → barrera de tierra | Un muro **donde cae la flecha**, lejos de la jugadora | Tapar una trampa o un respiradero a distancia; protegerse de un arquero levantando el muro junto a él |
| Flecha de fuego → ᛒ suelo de fuego | Una **trampa** plantada donde golpea | Minar el camino de un enemigo que viene |
| Flecha de tierra → barrera de tierra | Golpea y deja un **muro detrás del enemigo** | Combate: empujarlo contra el muro (C11, daño contra pared) |
| Flecha de fuego → pulso de agua | Quema y luego **apaga y moja** la zona | Vapor que ciega a un grupo (B2 de PROPUESTAS_COMBATE) |
| Flecha contra una reja → barrera de fuego | La barrera **nace al otro lado** de lo golpeado | Encender un brasero tras una reja sin tótem (G6 de la Gruta Batida, con la mano de la jugadora) |

**Cuidados:** un solo nivel de encadenado en la demo (H1), cobrar la tinta de las dos páginas, y que el segundo hechizo **se vea nacer** en el punto de impacto (destello y sonido propios) para que se entienda la cadena.

### H12 · Página de dos círculos: un hechizo que contiene otro (idea de Pablo, 21/11)

**La idea** (boceto de Pablo): en la página, **dos círculos**: **Hechizo 1** a la izquierda, **Hechizo 2** a la derecha, y entre ellos un **recuadro con la condición que los une** (al impactar, al acabar…). Inspirada en *Witch Hat Atelier*, donde hay conjuros que actúan como una subfunción de otro. Es la forma visible del disparador (H1b): en vez de esconderlo en el orden de dibujo, **se dibuja**.

**¿Es implementable? Sí, y la lógica está casi hecha.** Lo caro es el libro, no el hechizo.

| Pieza | Qué hay | Qué falta | Coste |
|---|---|---|---|
| Partir la página en padre e hijo | `Hechizo.DISPARADOR` ya parte la página en dos por el ⧖ (`nucleo/hechizo.gd:452-499`) | Partirla por **círculo** en vez de por orden de dibujo | B |
| Que nazca el hijo en el sitio | `crear_hijo` con `glifos_hijo` (`magia/hechizo_vivo.gd:1781-1814`), profundidad máxima, recargo de tinta | Nada | — |
| **Hijo de otro elemento** | El hijo usa el elemento del padre (`h.fuente`) | Que el círculo 2 tenga **su propio sello** y se pase su runa a `Hechizo.construir` | B |
| Condiciones | Ya hay eventos: `al_impactar`, `al_detenerse`, `al_expirar`, `al_rebotar`, `al_matar` (`hechizo.gd:65`) | Un glifo o símbolo por condición en el recuadro; empezar con **una o dos** (al impactar, al acabar) | B |
| Guardar la página | La ficha guarda un sello y sus glifos | Guardar `{hijo: {sello, glifos}, condición}`. Ojo: las páginas guardadas no se recargan en el Grimorio (`repertoire.gd:216`, ya anotado en LIBRO_AVANZADO §0) | B–M |
| **El libro** | Un círculo con núcleo y 6 huecos (`presentacion/ui/spellbook.gd`). El libro avanzado ya tiene **reconocimiento por zonas** (`LIBROS["avanzado"]`) | Dibujar dos círculos más pequeños y el recuadro; reconocer en cuál se dibuja; repartir los huecos (por ejemplo 3 + 3) | **M–A** |
| Previsión y feedback | `Hechizo.hijo_siguiente` ya existe para la interfaz | Enseñar los dos hechizos y el momento del paso; que el hijo **se vea nacer** | M |

**¿Añade demasiada complejidad?** Para la jugadora, **menos que lo de hoy**: el disparador actual depende de un orden de dibujo invisible, y dos círculos con una condición en medio se explican solos. Para el desarrollo, es sobre todo trabajo de interfaz. Las condiciones para que no se desborde:
1. **Un solo nivel**: dos círculos, nunca un círculo dentro de otro dentro de otro.
2. **Pocas condiciones** al principio (al impactar y al acabar).
3. **No en el primer libro**: que la página doble sea una **mejora del libro** o una página especial que se gana (encaja con «sellos por historia» y con un libro posterior).
4. **Huecos repartidos**, no sumados: los mismos 6 glifos entre los dos círculos, para que la tinta y la lectura no se disparen.

**Decisión de Pablo (21/11):** «puede ser un hechizo muy avanzado y acotado a 2 sellos y 6 glifos, repartiendo cada sello en un hechizo». Es decir:
- **Hechizo muy avanzado**: no está en el primer libro.
- **2 sellos**: uno en cada círculo (cada hechizo tiene su elemento).
- **6 glifos en total**, repartidos entre los dos círculos (no 6 por círculo). Es el mismo tope que ya tiene `Hechizo.MAX_GLIFOS` y el del libro avanzado, así que la capacidad no crece.

**Confirmado con números (Pablo, 22/11): «6 repartidos».** Se comparó con «6 + 6, solo con los glifos principales», medido con `Hechizo.construir` (fuego).
- Un círculo de 3 glifos: daño 13, tinta 20–28, recarga 2–3 s.
- Uno de 6: daño 26–44, tinta 54–72, recarga 3,5–4 s.
- **6 + 6:** duplica el daño (53–88) y cuesta **108–145 de tinta**, más que la barra inicial (100). Además, 15 huecos y 14 trazos por página.
- **3 + 3:** cuesta lo mismo que una página llena (40–56 de tinta) y hace igual daño o menos. Lo que se gana es la combinación, no la potencia.
- Si más adelante hace falta margen: una **mejora del libro de 6 a 8 en total**, nunca 6 por círculo.

**Relación con lo demás:** sustituye la forma de dibujar el disparador de H1b (el ⧖ entre formas) y resuelve H1 (hijo de otro elemento) sin tener que llamar a otra página. El libro avanzado de dos sellos (LIBRO_AVANZADO) es otra cosa (una reacción en un solo hechizo); pueden convivir o la página doble puede ocupar su sitio.

### H13 · Repetición: una copia más a la vez, en todas las formas (de O18, Pablo 22/11)

**En Mystralia:** con la runa Repetición, la bola sale **triplicada en paralelo**: tres bolas de fuego en fila, una al lado de otra, a la vez. Pablo: «Hagamos lo mismo para cada bola, haz o lo que sea: un elemento más saliendo a la vez».

**Cómo está hoy ᚠ** (`nucleo/sigils.gd:393`: +1 copia por glifo, tope 4; tinta 3 por glifo):

| Forma | ¿Repite a la vez? | Cómo | Dónde |
|---|---|---|---|
| **Proyectil** (con ᛇ) | **Sí** | Las copias salen juntas, separadas `separacion` de lado y abiertas en un abanico de `dispersion` grados en total | `HechizoVivo.salida_de_copia`, `magia/hechizo_vivo.gd:270-277` |
| **Volumen quieto** (bola, barrera) | **Sí** | `copias` volúmenes repartidos a lo largo de X (perpendicular a la mirada), una casilla de centro a centro como mínimo | `hechizo_vivo.gd:982-1010` |
| **Haz** (ᛁ) | **No: FALTA** | `_materializar_haz` dibuja un solo haz y no lee `copias`; ᚠ cobra tinta y no hace nada (salvo ᛁ ᚠ ᛃ, que pasa a órbita, R3) | `hechizo_vivo.gd:485-558` |
| **ᛒ suelo** | No | ᛒ manda e ignora los demás glifos | `magia/glifo_suelo.gd:17` |
| Con ᛇ **antes** de ᚠ | No: **ráfaga en fila**, una tras otra cada 0,12 s | Es el orden de dibujo (C2) | `nucleo/hechizo.gd:24-26`, `magia/lanzador_3d.gd:1924` |

**Propuesta:**
1. **Haz:** con ᚠ, `copias` haces paralelos separados una casilla de lado, cada uno con su recorrido y su corte en lo sólido (repetir el cálculo de `_materializar_haz` desplazando el origen como hace `salida_de_copia`). Es el caso que falta y el más vistoso: un «rastrillo» de fuego.
2. **ᛒ suelo:** con ᚠ, planta `copias` trampas o plataformas en fila perpendicular a la mirada. Encaja con H11 (ᛒ que viaja): ᚠ ensancha y ᛇ alarga.
3. **Revisar el abanico:** Mystralia las saca **paralelas**; nosotros abrimos 15° (`dispersion`). Decidir si la repetición va paralela (como la captura) o en abanico. El comentario de `nucleo/hechizo.gd:174` dice «hoy no hay abanico» y está desfasado: el proyectil sí lo usa.
4. **Que se lea:** las copias nacen a la vez desde la mano, con un solo sonido más grueso, no tres seguidos.

**Cuidados:**
- **Ráfaga y repetición conviven** por el orden de dibujo: ᛇ antes de ᚠ = en fila (ya existe); ᚠ antes de ᛇ o sin ᛇ = a la vez. Hay que enseñarlo (H4, H6).
- **ᚠ no está en el kit de la demo** y el primer libro ya está lleno (P3 del plan de hechizos, aplazada).
- **Tinta y daño:** cada copia ya tiene recargo (`Dano`, ×0,15 por copia). Con el haz, revisar que tres haces no peguen tres veces al mismo enemigo si se solapan.
- **Topes:** las copias cuentan para el tope de hechizos vivos (32) y de barreras (3).

### H15 · Disparador «De una vez» (de O20, Pablo 22/11)

**En Mystralia:** es su segundo disparador, junto a «Impacto». Ficha: «Al usar un conjuro lanza a la vez un disparador». Al lanzar, el hechizo enganchado sale **en el mismo instante**, sin esperar a que el primero golpee.

**En lo nuestro:**
- **Encaja en la página de dos círculos (H12)** como condición del recuadro central: **«a la vez»** (al lanzar), junto a «al impactar» y «al acabar». El evento ya existe: `al_nacer` (`nucleo/hechizo.gd:65`).
- **Para qué sirve,** con fuego, agua y tierra y un sello por círculo:

| Círculo 1 + «a la vez» + círculo 2 | Qué consigue |
|---|---|
| Flecha de fuego + barrera de tierra | **Disparar y cubrirse** en una sola pulsación: el muro sale delante mientras la flecha vuela (contra arqueros, C18) |
| Flecha de agua + flecha de fuego | Dos proyectiles de elementos distintos a la vez. Si se cruzan, hacen vapor: ¿se permite? (ver abajo) |
| Barrera de agua que te rodea + pulso ᚱ de tierra | Protegerse y apartar a los que están cerca |
| ᛒ suelo de tierra + flecha | Plantar una plataforma o una trampa y disparar a la vez |

**Pablo (22/11): «el problema de este glifo es que es muy poderoso».** Pagar todo al lanzar y tomar la recarga del más lento **no basta**, porque «a la vez» regala tres cosas:
- **una acción entera:** dos hechizos por el tiempo de uno;
- **ataque y defensa sin exponerse:** disparar y cubrirse en el mismo instante, que es justo lo que el combate quiere que sea una decisión (C18);
- **reacciones a la carta:** fuego + agua es vapor garantizado, sin depender del mundo.

**Contrapesos propuestos** (de más a menos importante; se pueden combinar):

| # | Contrapeso | Qué quita | Coste |
|---|---|---|---|
| 1 | **Recarga = la SUMA de las dos**, no la del más lento | Lanzarlos por separado sale igual de rápido: lo que se gana es solo la simultaneidad, no tiempo | B |
| 2 | **Tiempo de lanzar = la suma** (`CastPoints`, tierra ×1,3 incluida) | Más exposición mientras se lanza. Con un arquero apuntando, hay que elegir el momento | B |
| 3 | **Tinta = la suma + un recargo** (por ejemplo, +30 %) | Es el hechizo más caro del libro, así que no se repite sin pensar | B |
| 4 | **Sin sobrecarga** en una página «a la vez» | Que no se sumen dos potencias ×1,5 | B |
| 5 | **Solo un círculo hace daño:** el otro tiene que ser de forma o defensa (barrera, ᛒ, pulso sin daño…) | Corta lo más fuerte: dos ataques juntos. Deja «disparar y cubrirse» como el uso pensado | B–M |
| 6 | **Cada círculo con menos glifos**: ya pasa (6 en total, repartidos) | Cada hechizo es más flojo que uno solo de página entera | Ya está |

**Mi recomendación:** **1 + 2 + 4** de serie (lo hacen una decisión táctica, no una ganancia gratis) y **5** si al probarlo sigue sobrando. El 3 solo si la tinta vuelve a apretar (P9 ya bajó el daño de la flecha).

**Decidido (Pablo, 22/11): 1 + 2 + 4**: recarga sumada, tiempo de lanzar sumado y sin sobrecarga. «Si vemos que no es práctico, mejoraremos algo.»

**Cómo sale en Mystralia: con un pequeño retardo** (vídeo de Pablo, 22/11, medido fotograma a fotograma a 30 fps; detalle en O21 de `MAGES_OF_MYSTRALIA_2026-11-21.md`):
- La página era una andanada de **3 bolas de fuego paralelas** con «De una vez» enganchado a otra igual.
- **Primer hechizo:** chispas blancas en los puntos de salida (fotograma 866), un destello blanco grande (867) y las bolas (868).
- **Segundo hechizo:** lo mismo **5 fotogramas después**: chispas (871), destello (872) y bolas (873). Sale detrás de la primera andanada, sin solaparse.
- **Igual en los tres lanzamientos** del vídeo (866→871, 913→918, 972→977): **≈ 0,17 s** entre los dos.
- Para Pablo, es una forma de **evitar errores con un retardo que parece lógico**: se leen dos hechizos y no uno mezclado.

**Lo que tomamos:**
- **`RETARDO_A_LA_VEZ` ≈ 0,15–0,2 s** entre el círculo 1 y el círculo 2, y **cada uno con su destello de salida**, para que se lean como dos.
- **Resuelve casi toda la decisión 1** (reaccionar al nacer): en 0,17 s el primer proyectil ya se ha separado de la mano. Sigue haciendo falta el filtro por linaje para lo que **no se mueve**: una barrera de fuego y otra de agua en el mismo sitio harían vapor igual. El hallazgo de la sesión de hechizos es que hoy el cruce no mira el linaje (`hechizo_vivo.gd:2192-2205`).
- **No cambia el tiempo de lanzar** (contrapeso 2): el retardo va dentro de la suma, no se añade.

**Lo que hay que decidir:**
1. **¿Los dos hechizos reaccionan entre sí al nacer?** Fuego y agua juntos en la mano harían vapor al instante (hechizo contra hechizo, `CRUCES`). Propuesta: **no reaccionan entre ellos hasta que se separan** (el mismo linaje no se cruza), pero sí con lo que encuentren. Que reaccionen sería un caso «contraproducente que se ve venir» (C20 #5, ya permitido).
2. ~~**Coste:** se pagan los dos al lanzar~~ → **insuficiente (Pablo, 22/11)**: ver los contrapesos de arriba.
3. ~~**Recarga:** la del más lento~~ → **insuficiente (Pablo, 22/11)**: propuesta, la suma (contrapeso 1).

**Diferencia con lo que ya hay:**
- **Libro avanzado:** mezcla dos sellos en **un** hechizo (agua + tierra = naturaleza).
- **«A la vez»:** son **dos** hechizos que salen juntos, cada uno con su elemento.
- **Repetición ᚠ (H13):** copias del **mismo** hechizo.

### H16 · Nombre de cada hechizo (de O28, Pablo 22/11)

**En Mystralia:** en el selector, junto a cada botón (X, Y, B, RT), aparece el **nombre del hechizo** equipado. Unos son automáticos («Immedi #2»: el tipo y un número) y otros los ha puesto la jugadora («Hielo doble», «Camino de tierra», «Dash»). Pablo: «así, cuando eliges la página, sabes qué conjuras».

**Cómo estamos:**
- Una página es `{elemento, elemento2?, glifos}` (`nucleo/repertoire.gd:219-222`). La escribe y la lee el Grimorio (`magia/grimorio.gd:201-231`, `volcar_paginas` y la recarga) y se guarda en la partida. **No tiene nombre.**
- El HUD de páginas (`presentacion/ui/page_hud.gd:89-138`) dibuja un círculo por página, con el color del elemento, el dibujo del sello, la recarga y la tecla («1», «2», «3»). **No dice qué hace cada página.**

**Cómo lo haría:**
1. **Dato (B).** Dos claves nuevas en la página:
   - `nombre`, el texto;
   - `nombre_propio`, verdadero si lo puso la jugadora.

   Se guardan y se leen como `elemento2` (`repertoire.gd:298-300` y `grimorio.gd:215/231`). Una partida vieja, sin la clave, recibe el nombre automático.
2. **Nombre automático (B)**, sacado de la receta y no de una tabla de recetas: **forma + elemento + un rasgo**.
   - Forma, del perfil que ya calcula la previsión del casteo (`PrevisionCasteo3D.perfil`):
     - flecha → «Flecha»;
     - barrera local → «Escudo»;
     - barrera con flecha → «Muro que avanza»;
     - haz → «Chorro»;
     - suelo → «Trampa» o «Plataforma»;
     - órbita → «Orbes».
   - Elemento: «de fuego», «de agua», «de tierra».
   - Rasgo, del glifo que más pesa: «doble» si hay copias, «largo» si hay alcance, «grande» si hay altura, «que vuelve» si hay retorno, «que pulsa» si hay pulso.
   - Ejemplos: «Flecha de fuego», «Escudo de agua», «Chorro de fuego largo», «Plataforma de tierra».
   - **Si la jugadora no lo ha renombrado, se rehace cada vez que cambia la página.** Si lo ha renombrado, se respeta.
3. **Renombrar en el libro (M).**
   - En la página abierta, el nombre va en la cabecera. Al pulsarlo se convierte en un campo de texto (tope de unos 18 caracteres, Intro acepta, Esc cancela).
   - **Dejarlo vacío** vuelve al automático.
   - Con mando no hay texto todavía, y no hace falta: el automático ya funciona.
4. **Dónde se ve:**
   - **HUD (B):** el nombre de la **página activa**, bajo los círculos y en pequeño. Al cambiar de página aparece en grande ~1,2 s y se reduce. No se muestran los tres siempre: llenarían la pantalla en combate.
   - **Selector de página activa (H10, ya decidido):** aquí es donde más sirve. Cada botón con su nombre, como en la captura de Mystralia. **H10 y H16 van juntos.**
   - **Libro:** la cabecera de cada página y el índice de pestañas.
   - **Cifras del libro (M1):** usar el nombre en vez de «página 2».

**Cuidado:**
- Los nombres automáticos tienen que ser **cortos** (dos o tres palabras), o no caben en el HUD.
- Si la jugadora pone un nombre que miente («Escudo» en una flecha), se respeta: es suyo. La silueta de la previsión ya dice la verdad.

### H11 · ᛒ suelo que viaja (de O14)

**Hoy:** ᛒ manda sobre todo lo demás; con flecha, planta lo mismo que sin ella en una sola casilla (`magia/glifo_suelo.gd:17`).
**Propuesta:** que ᛒ siga las reglas generales de forma en vez de ignorarlas:

| Receta | Qué haría | Con tierra (demo) | Con fuego o agua (demo) |
|---|---|---|---|
| ᛒ | Planta en la casilla apuntada (como hoy) | Plataforma sobre el vacío o capa que frena | Trampa de un solo uso |
| ᛒ + ᛇ | **Avanza y deja un rastro** de casillas en línea recta (largo según ᛇ, como el alcance de la flecha) | **Puente de plataformas** sobre un foso, o una franja que frena | **Fila de trampas** (un pasillo minado) |
| ᛒ + ᛇ + ᛃ | El rastro **se curva y vuelve** hacia la lanzadora | Camino en U, o un **corral** alrededor de un enemigo | Cerco de trampas |

**Por qué encaja:** es la misma regla que ya cumplen la bola y la barrera con la flecha (R1, R2); no hace falta escribir casos. Y es lo que más se celebra de Mystralia: una misma runa da herramientas distintas según la base.

**Lo que hay que cuidar:**
- **T3 · El foso** se diseñó para cruzar **paso a paso** (lanzar, subir, lanzar): un puente de una vez lo haría trivial. O el rastro es corto (2–3 casillas con un ᛇ) y caro en tinta, o T3 pasa a pedir el rastro y otro puzle conserva el paso a paso.
- **Topes:** `GlifoSuelo.MAX_VIVOS` = 6 piezas plantadas a la vez; un rastro largo lo llenaría solo. Contar el rastro como una sola pieza.
- **Ritmo de dibujo:** que el rastro **se vaya poniendo** (una casilla cada ~0,2 s, como Mystralia) y no aparezca de golpe: se lee mejor y da tiempo a reaccionar.
- **Derecha/izquierda:** nosotros no tenemos runas de dirección; ᛃ retorno da la curva de vuelta. Una curva hacia un lado concreto podría salir del **hueco de la corona** donde se dibuja la flecha (cada hueco ya tiene su dirección, `Grimorio.dir_corona`). Para decidir.

### H10 · Cómo encajar «pulsar otra vez cambia el hechizo» con el lanzamiento de hoy

Hoy las teclas 1/2/3 ya hacen cosas al pulsar (`Lanzador3D.pulsar_pagina`, `magia/lanzador_3d.gd:1036-1054`): **mantener = apuntar y soltar = lanzar**; con el lanzamiento inteligente, **pulsar = lanzar al instante**. Si pulsar otra vez cambia de hechizo, choca con eso. Opciones:
- **a) Doble toque cambia**: un toque lanza (como hoy) y dos toques seguidos (en menos de ~0,25 s) pasan al siguiente hechizo de ese botón sin lanzar. Riesgo: el primer toque del doble ya habría lanzado; hay que esperar ese margen antes de lanzar, y el lanzamiento se nota menos inmediato.
- **b) Pulsar elige, mantener lanza**: si el botón no está seleccionado, pulsar lo selecciona; si ya lo está, pulsar cambia al siguiente; **mantener y soltar** lanza (como hoy). Es claro, pero cambia la costumbre del lanzamiento inteligente.
- **c) Un botón aparte para cambiar** (por ejemplo, la rueda del ratón o un gatillo + el número). No toca el lanzamiento, pero añade un botón.
- ~~Lo que yo probaría primero: b~~.
- **Decisión de Pablo (21/11): un SELECTOR de «página activa».** Como el «Equipar» de Mystralia: se elige qué hechizo está activo en cada botón, y el botón solo lanza, como hoy (mantener apunta, soltar lanza; o pulsar lanza con el lanzamiento inteligente). No hace falta ni doble toque (a) ni cambiar al pulsar (b), y no se toca `pulsar_pagina`.
- **Dónde vive el selector (Pablo, 21/11): en los dos sitios.** «La preparación es importante y en combate te da el abanico.» Fuera de combate, en el libro (se prepara qué hay en cada botón); en combate, un control rápido para cambiar el activo sin abrir el libro. Hoy no existe ninguno en combate (`select_page` solo lo usa el libro): falta elegir ese control (rueda del ratón, cruceta o gatillo + número).

**Lo que falta saber de Mystralia:** en las capturas se ve que cada botón tiene varios hechizos guardados y uno equipado; no queda claro si en el juego se cambia pulsando el mismo botón o solo desde el menú. Se puede comprobar jugando.

## Puzles y mundo

| Id | Propuesta | Origen | Coste | Estado |
|---|---|---|---|---|
| P1 | **X5 · Plataforma bajo el dragón**: plataforma móvil, trampa dragón y barrera que protege | MAGES O2; PUZLES_DEMO §3 | M | Propuesta (falta plataforma móvil) |
| P2 | Una sala por glifo en su mazmorra, con pista de pago que dice qué glifos hacen falta | MAGES §5 F | M | Propuesta |
| P3 | Sala de prácticas dentro del mundo (probar páginas sin gastar tinta) | ECHOES §5 C | M | Propuesta |
| P4 | **X6 · La mecha suspendida**: balsa con brasero que mueve una placa; bola de fuego quieta con permanencia en su camino; **un muro en medio impide el disparo directo** (Pablo) | MAGES O4; PUZLES_DEMO §3 | M | Propuesta (falta plataforma móvil) |
| P5 | ~~Puente sobre agua copiado de Mystralia~~ → **solo referencia** (Pablo, 21/11: allí el hielo va con un botón propio). Lo que se guarda es la **sensación** para cualquier hechizo que transforme el suelo: semilla visible, nacimiento de golpe con onda, piezas que encajan, ritmo de pasos. Ya anotado en T3 | MAGES O5; PUZLES_DEMO T3 | — | Referencia |
| P7 | **X7 · El brasero tras el chorro**: disparar a través de una trampa dragón para encender un brasero que la apaga ~2,5 s y cruzar a tiempo. Casi solo mapa: la regla «botón apaga trampa» ya existe | MAGES O13; PUZLES_DEMO §3 | B | Propuesta (Pablo confirma: el brasero dispara un temporizador) |
| P9 | **X8 · Tres braseros y las plataformas**: el tercer brasero solo se alcanza desde una plataforma móvil que cruza un foso bajo un chorro que empuja; la barrera aguanta el empuje | MAGES O15; PUZLES_DEMO §3 | M | Propuesta (necesita P6 y un chorro que empuje) |
| P8 | **Temporizador común con cuenta atrás visible**: disparador → cambio durante N s, la cuenta se ve en el mundo y avisa al final; unifica los relojes sueltos (brasero con relé, rearmes, trampa apagada, tierra que parpadea) | Pablo (21/11); `CONCEPTO_TEMPORIZADOR_2026-11-21.md` | B–M | Concepto escrito; **A o B se decide en el plan final** (Pablo, 21/11) |
| P10 | **X9 · Plataformas en raíl sobre el cañón**: cada plataforma recorre su raíl de pilar a pilar cuando se activa el **receptor de su parada** con un elemento; varios tramos encadenados en direcciones distintas, lanzando desde encima de la plataforma (ver abajo) | MAGES O19 (Pablo, 22/11) | M | Propuesta (necesita P6) |
| P11 | **X10 · Reflejar el rayo de luz**: un haz de luz cae del techo sobre un pedestal. La protección de la jugadora (barrera o burbuja) lo **refleja hacia donde mira**, y girando lo lleva hasta un receptor (ver abajo) | MAGES O24 (Pablo, 22/11) | M | Propuesta |
| P12 | **X11 · La luz mueve la vagoneta**: una vagoneta con un cristal **avanza por su raíl mientras le da la luz** y se para si no. La luz llega por un cristal que se gira con E y por el reflejo de la jugadora (X10), que tiene que seguirla mientras se mueve (ver abajo) | MAGES O25 (Pablo, 22/11) | M | Propuesta (necesita P6 y X10) |
| P13 | **X12 · Alinear los cristales y poner tú el último reflejo**: primero se dejan girados los cristales fijos (con E) y después la jugadora **cierra la cadena con su reflejo**, mientras lo mantiene, hasta la puerta (ver abajo) | MAGES O26 (Pablo, 22/11) | B (sobre X10) | Propuesta |
| P14 | **X13 · El brasero tras el murete**: el objetivo se ve, pero un murete corta el tiro recto; hay que **cambiar la página** para que el hechizo llegue (rebote, retorno o altura) (ver abajo) | MAGES O29 (Pablo, 23/11) | B | Propuesta |
| P6 | **Plataforma móvil** como pieza (la necesitan X5 y X6): recorrido fijo, la mueve una placa o va sola, y lleva lo que tiene encima (jugadora, barrera, brasero) | MAGES O2 y O4 | M | Propuesta |

### P11 · X10 · Reflejar el rayo de luz (de O24)

**En Mystralia:** un haz de luz baja del techo a un pedestal. La jugadora se pone en él y saca su escudo de hielo, y la luz sale reflejada **como un rayo horizontal hacia donde mira**. Girando, barre toda la sala hasta dar en un cristal receptor. El reflejo dura mientras mantiene el escudo.

**Lo que ya tenemos** (el sistema del pulso resonante, `escenas/puzle.gd:87-140`):

| Pieza | Qué hace hoy | Para X10 |
|---|---|---|
| `cristal` (`CristalPulso3D`) | Emisor: suelta un pulso desde su casilla | Base de la **fuente de luz**. Falta una variante «luz cenital», sin pieza en el suelo: un haz que baja del techo |
| `prisma` (`PrismaPulso3D`) | Reemite el pulso hacia donde mira; gira 90° con un golpe o con E | Ya es un **reflector**, pero fijo y a saltos de 90° |
| `receptor` (`ReceptorPulso3D`) | Se activa al llegarle un pulso y pone una flag | El **cristal azul** de Mystralia: no hace falta nada nuevo |
| Rayo continuo que se corta en lo sólido | El haz ᛁ (`Hechizo.haz`) y el aliento del dragón | El **rayo reflejado** se dibuja y se corta igual |

**Cómo pasarlo a la demo** (no hay hielo):
- **Reflector = la protección de la jugadora.** Propuesta: **la barrera o la burbuja de agua refleja la luz** (el agua como espejo, coherente con el mundo). Mientras la jugadora está en el haz con su protección de agua, la luz sale hacia donde mira. La variante de hielo, la de Mystralia, queda para después (D1).
- **Apuntar girando:** el rayo sigue la mirada de la jugadora (la misma dirección que el apuntado).
- **Dura lo que dura la protección.** Es la regla de «lo que se mantiene» y encaja con la burbuja.

**Lo que pide la sala:**
- **Fácil:** un receptor a la vista; se gira y se acierta.
- **Media:** el receptor está detrás de una esquina, así que la luz va al **prisma** (fijo, que se gira con E) y de ahí al receptor. Es una cadena de dos reflejos con piezas que ya existen.
- **Difícil:** dos receptores con un temporizador (P8): el primero abre una puerta durante N s, y hay que mover el rayo al segundo antes de que se cierre.

**Qué hace falta construir:**
1. La **luz cenital**: haz desde el techo hasta la casilla del pedestal, con el pedestal como pieza.
2. La **regla «la protección de agua en el haz refleja»**: el rayo sale de la jugadora en su dirección de mirada, se dibuja como el haz ᛁ y activa el receptor.
3. **Que el prisma acepte la luz** además del pulso, o que la luz sea un tipo de pulso continuo.

**Cuidado:** la cámara fija tiene que ver a la vez el pedestal y el receptor. Si la sala es grande, la cámara por sala ya existe.

### P12 · X11 · La luz mueve la vagoneta (de O25)

**En Mystralia:**
- Un haz fijo da en un cristal grande, que lo reemite en la dirección que elige la jugadora con «Activar».
- Una vagoneta con un cristal azul **avanza por sus vías mientras la luz le da** y se para cuando no.
- Para llevarla adonde hace falta, la jugadora **refleja la luz con su escudo** (X10) y la va siguiendo mientras la vagoneta se mueve.

**Es la suma de dos piezas que ya están en la lista:**
- la **plataforma en raíl** (X9, P6), pero con un **motor continuo** en vez de un viaje entero por activación;
- el **rayo de luz reflejado** (X10).

Y del pulso resonante (`escenas/puzle.gd:87-140`) ya existen el **prisma**, que se gira 90° con E o con un golpe (el «cristal grande» de Mystralia), y el **receptor**.

**Qué falta:**
1. **Un modo `va=luz` en la plataforma móvil (P6):** avanza por su `ruta` **mientras un receptor suyo recibe luz**, a velocidad constante, y se para al dejar de recibirla. En las puntas, se queda. Es otro modo junto a `va=placa`, `va=sola` y `va=orden`, que ya propone el plan de puzles.
2. **El receptor encima de la plataforma**, que se mueve con ella. El rayo tiene que seguirlo: el reflejo se recalcula cada fotograma.
3. **Hacia dónde avanza:** en Mystralia, en una dirección fija de la vía. Propuesta: **la dirección de la vía**, no «alejándose de la luz» (más fácil de leer y de diseñar).

**Para qué sirve en una sala:**
- **Llevar la vagoneta al final** de la vía para que haga de puente, de contrapeso o de llave.
- **Cadena:** fuente → prisma (girado con E) → reflejo de la jugadora → vagoneta. Dos reflejos, y uno de ellos con el cuerpo.
- **Tensión:** si la vía pasa detrás de un muro, la jugadora tiene que moverse para no perder la línea.

**Variantes de otro elemento (D1):** la misma vagoneta movida por un **chorro de agua** (una flecha o un haz de agua que la empuja mientras le da) o por **fuego** (un brasero en la vagoneta que avanza mientras arde). Es la misma pieza con otro receptor.

### P13 · X12 · Alinear los cristales y poner tú el último reflejo (de O26)

**En Mystralia:**
- Una fuente de luz da en un cristal pequeño. La jugadora, con su escudo, refleja ese haz hacia un **cristal central sobre un pedestal giratorio**, que reemite en la dirección en que está girado.
- Con el central bien orientado, la luz llega a la puerta y esta se abre.
- **Primero se prepara** (girar el central, que se queda donde lo dejas) y **después se ejecuta** (el reflejo propio, que solo dura mientras se mantiene).

**En lo nuestro sale casi entero de lo que ya hay o ya está propuesto:**
- **El cristal central** = el **prisma** del pulso resonante, que se gira 90° con E o con un golpe (`escenas/puzle.gd:132`).
- **El reflejo de la jugadora** = X10 (la protección de agua refleja la luz hacia donde mira).
- **La puerta** = un **receptor** con una regla de mapa que abre la puerta, como cualquier otro receptor.
- **Lo único nuevo** es que el prisma acepte la luz (ya anotado en X10, punto 3).

**Diseño de la sala:**
- **El orden tiene que obligar:** que la jugadora no pueda girar el prisma mientras refleja (está lejos de él, al otro lado del haz). Así hay que pensar antes de colocarse.
- **Dos prismas** para la versión difícil: la cadena fuente → reflejo de la jugadora → prisma 1 → prisma 2 → puerta.
- **Ojo con los 90°:** nuestros prismas giran en cuatro direcciones (n, e, s, o). Las salas se diseñan **sobre la cuadrícula**, con fuente, prismas y receptor alineados en filas y columnas. Eso hace el puzle legible, no limitado.
- **Recompensa:** en Mystralia es un objeto especial (gema del alma violeta). Encaja con el cofre mágico o una mejora del libro.

**Es una de las tres variantes del rayo de luz:**
- X10: reflejar y apuntar;
- X11: la luz mueve la vagoneta;
- X12: alinear y cerrar la cadena.

Con la luz cenital, el reflejo y el prisma con luz se pueden hacer las tres.

### P14 · X13 · El brasero tras el murete (de O29)

**En Mystralia:** una esfera que se enciende con fuego está detrás de un murete que no se cruza. El tiro recto choca; la jugadora **edita la página** (añade Invertir) y el segundo tiro llega. Se abre el cofre de la sala y aparece un atajo.

**La idea para nosotros:** un **puzle de libro**. No pide puntería ni piezas nuevas, sino **saber qué glifo cambia el camino** del hechizo. Es el mejor tipo de puzle para enseñar que las páginas se preparan.

**Lo que ya tenemos:**
- **El objetivo:** un **brasero** (Reactivo3D), que ya enciende con fuego y pone su flag. El contador y el cofre con `aparece_si` también existen.
- **El murete:** cualquier casilla de roca baja o `#`, que corta el proyectil.
- **Glifos que cambian el camino**, ya hechos:
  - **ᚢ rebote** (`rebotes`): rebota en la pared lateral y entra por el hueco. Es la versión más clara: se ve el ángulo.
  - **retorno** (`retorna`): el proyectil va y vuelve. Sirve si el brasero está **detrás de la jugadora** respecto a un pilar, o si se lanza desde el otro lado de una reja.
  - **altura** (`altura_salida`): pasa **por encima** del murete. Es la traducción más directa, pero la altura llega más tarde (Cuevas).
- **ᚨ buscar no vale:** hoy solo busca enemigos en un cono de 60° (`hechizo_vivo.gd:672`), no braseros. Mejor así: si buscara braseros, el puzle se resolvería solo.

**Salas de ejemplo (de fácil a difícil):**
- **Rebote (Bosque 01 o 02):** el brasero está en un nicho detrás de un murete, con una pared de piedra en ángulo al lado. Con fuego + flecha, choca; con fuego + flecha + rebote, entra. Recompensa: cofre o atajo.
- **Retorno:** el brasero está en un saliente a la espalda de la jugadora, separado por una reja que deja pasar el fuego pero no a ella. Se lanza hacia delante, el hechizo vuelve y lo enciende al pasar.
- **Doble (más tarde):** dos braseros, uno por rebote y otro por altura, que se encienden con un temporizador (P8). Obliga a llevar **dos páginas** preparadas.

**Qué hace falta construir:** casi nada.
1. **Comprobar** que el rebote del fuego entra en el nicho de forma fiable desde la casilla obvia (prueba de escenario, como las demás).
2. **La pista:** el murete o una placa junto a él dibuja el glifo que pide (como la pista de pago de P2), o se deja a la vista una pared que «invita» a rebotar.
3. **El enseñar la recompensa:** la cámara por sala o un plano corto del atajo que aparece. Si no, basta con el cofre a la vista.

**Cuidado:** que el murete se lea como **«no se cruza, pero se ve por encima»**: bajo, con el brasero visible, para que la jugadora piense en el hechizo y no en buscar otro camino.

## Mejoras fuera de los hechizos (Pablo, 22/11)

Lista que trajo Pablo tras revisar combate, acciones, botín, cartografía, misiones y guardado, comparándolos con Mystralia. Comprobada en el código el 22/11 y **repartida** (Pablo: «Sí, repártelo»).

| Id | Mejora | Lo que dice el código | Quién | Estado |
|---|---|---|---|---|
| L1 | **Guardado fiable**: copia anterior por ranura y validar secciones | Confirmado: `Partida.guardar` borraba la partida antes de renombrar el temporal | Dirección | **Hecho (22/11)**: `.anterior` por ranura, `leer` la usa si la principal se rompe o falta, se validan `meta` y `jugadora` y el tipo de cada sección. `prueba_partida` bloque 7: 14 comprobaciones bien. Queda el fallo de antes: `tiendas` no está en `partida_ejemplo.json` |
| L2 | **Buffer del golpe F** y prioridad entre acciones | Confirmado: el golpe F se pierde si la jugadora está ocupada | Gamefeel (G1, 2.2) | En marcha |
| L3 | **Contrato de morir y reintentar** | Confirmado: `reaparecer()` emite `reaparecio` y nadie lo escucha; el encuentro no se reinicia | Combate | En marcha |
| L4 | **Coordinar los encuentros** (cuántos atacan a la vez, quién se recoloca) | Confirmado: no hay turnos de ataque entre goblins | Combate (sobre L3) | En marcha |
| L5 | **Botín según la necesidad** | — | Combate | **Hecho dentro de C1**: el recogible de vida sale un 15 %, o un 25 % con poca vida |
| L6 | **Temporizadores legibles** | Es P8 | Puzles | Propuesta |
| L7 | **Reiniciar un puzle** sin morir | Hay piezas que ya reaparecen (bloque y roca empujables) | Puzles | Propuesta |
| L8 | **Memoria de obstáculos en el mapa** (puerta cerrada vista, cofre inaccesible…) | La cartografía y las misiones ya existen | Después de la demo | Aparcada |

### P10 · X9 · Plataformas en raíl sobre el cañón (de O19)

**En Mystralia:** un cañón con raíles entre pilares. Cada raíl lleva una plataforma, y junto a su parada hay un molinete. Con viento al molinete, la plataforma recorre el raíl entero (~3–4 s) con la jugadora encima hasta el pilar siguiente. Allí empieza otro raíl, con su plataforma y su molinete. Son cuatro tramos.

**Cómo pasarlo a lo nuestro** (el viento está fuera de la demo):
- **El receptor es de un elemento de la demo,** con piezas que ya existen:
  - **Agua → noria:** una flecha o un haz de agua la hace girar. Es la traducción más directa del molinete.
  - **Fuego → brasero con relé:** como en X7, un brasero que, encendido, tira de la plataforma.
  - **Tierra → contrapeso:** un bloque o una plataforma de tierra sobre una losa de pesos que la hace bajar o deslizar.
- **El raíl enseña el recorrido** antes de activarlo: vigas de pilar a pilar, de modo que la jugadora sabe adónde va. Encaja con la cámara fija, porque el recorrido se ve entero.
- **Lo que pide la sala:**
  - **Puntería desde una plataforma que se mueve:** el receptor del tramo siguiente se activa al llegar, o incluso en marcha.
  - **Elegir qué receptor activar:** puede haber dos raíles en un mismo pilar, y uno lleva a un callejón o a un cofre.
  - Más adelante, **un peligro en el tramo:** una trampa dragón que barre el raíl, que se tapa con la barrera (la regla C18: aviso suficiente) o se esquiva cambiando de plataforma.

**Qué hace falta construir:**
1. La **plataforma móvil (P6)**, con recorrido fijo y que lleve lo que tiene encima. Es la misma pieza que necesitan X5, X6 y X8.
2. Una **pieza «raíl»** que la guíe y se dibuje: vigas, y topes en los extremos.
3. Que un **receptor de elemento mueva una plataforma**: la regla de mapa «receptor → plataforma.avanzar», como la de «botón apaga trampa» que ya existe en `escenas/puzle.gd`.
4. Si se quiere en el Pantano, el agua honda bajo los raíles hace de foso. Caer es volver a la orilla, no morir (L7, reiniciar el puzle).

**Cuidado con la cámara:** en Mystralia la cámara sigue a la jugadora en cada tramo y se ve el recorrido entero. Con nuestro tamaño 6, un raíl largo puede salirse del encuadre: raíles de 4–6 casillas, o la cámara por sala (`; camara`), que ya existe.

## Tutorial: lo que se tiene antes del Bosque 01

**Observado en Mystralia (Pablo, 21/11):** al principio, y muy rápido, el juego da muchas recompensas, para que la jugadora tenga con qué jugar enseguida.

**Propuesta de Pablo:** llegar al Bosque 01 con **fuego, flecha y barrera**, con la barrera ganada en el tutorial.

**Cómo está hoy:**
- La **Gruta Batida** ya hace eso: se entra con fuego + flecha, los tótems enseñan la barrera y el cofre del santuario la da (`GrutaBatida.txt:125`, kit `gruta`). Pero la ruta de la demo (PUZLES_DEMO §5) **empieza en el Bosque 01**: la Gruta no está en la ruta.
- **La barrera se da en cuatro sitios**: el cofre de la Gruta, el `cofre_01` del Bosque 01 (`Bosque_01_v01.txt:125`), el `cofre_corazon` del Bosque 02 (`Bosque_02.txt:311`) y el guardabosques del Bosque antiguo, que la vende por 20 de oro (`escenas/bosque_3d.gd:17`).
- La barrera **de fuego no hace de escudo**: dura 2,4 s y las flechas del arquero pasan igual (medido el 28/10, GRUTA_BATIDA §1).

| Id | Propuesta | Origen | Coste | Estado |
|---|---|---|---|---|
| TU1 | **La Gruta Batida pasa a ser el tutorial** y va antes del Bosque 01 en la ruta de la demo | Pablo | B | Propuesta |
| TU2 | **Cambiar las otras recompensas de barrera**: `cofre_01` del Bosque 01 y `cofre_corazon` del Bosque 02 dan otra cosa (ver TU4 y TU5) | consecuencia de TU1 | B (solo mapas) | Propuesta |
| TU3 | **Recompensas rápidas al principio**: en los primeros minutos, el libro (con su lámina, H5), la primera página, el sello de fuego y la flecha como entregas separadas y celebradas, no como kit de arranque silencioso | MAGES O1 (Pablo) | M | Propuesta |
| TU4 | **Segunda página** como recompensa al final del tutorial o en el Bosque 01: permite llevar a la vez fuego + flecha y fuego + barrera. Es la primera decisión de preparar | DIBUJAR §2 (P1, P2) | B | Propuesta |
| TU5 | **Primer glifo geométrico: ᛁ línea, en el Bosque 01 o 02**, no en el tutorial. Altura, más tarde (Cuevas, con la tierra) | ver abajo | B | Para decidir |
| TU6 | La barrera del tutorial **protege de verdad** de las flechas, o al menos la burbuja (enlaza con C10) | GRUTA §1; MAGES O3 | B | Para decidir |

**Sobre los geométricos (la duda de Pablo).** En la demo son dos: **ᛁ línea** y **altura**. Mi recomendación:
- **No meterlos en el tutorial.** Cambian tamaño y forma, que es más difícil de leer que «sale disparado» (flecha) o «nace aquí» (barrera). El tutorial ya enseña dos ideas.
- **ᛁ línea pronto, en el Bosque 01 o 02.** Con fuego no se lee como «más largo»: es un **chorro instantáneo** que quema todo lo que hay en la línea y se para en lo sólido (`Hechizo.haz`). Es un verbo nuevo y claro, distinto de la flecha. Sirve para setos en fila y braseros alineados, y para el combate.
- **Altura, más tarde.** Su uso claro es subir con tierra (T2 · La cornisa), y la tierra llega en las Ruinas. Sin tierra, la altura con fuego o agua se lee mal.

## Después de la demo

### D1 · Variantes de otro elemento (principio de Pablo, 22/11)

> «No hay problema con hacer variantes de otro elemento; de hecho es lo mejor y lo más barato.»

**La regla:** cuando una pieza o un puzle ya funciona con un elemento, su versión con otro elemento es **contenido barato**. Se reutiliza la pieza, el mapa y la prueba, y solo cambian el receptor, el color y la reacción. Se diseña con un elemento para la demo, y las variantes quedan para después (o para salas de reto).

**Variantes ya anotadas:**

| Pieza o puzle | Versión de la demo | Variantes para después |
|---|---|---|
| X9 · Plataformas en raíl (P10) | Noria de agua | Brasero (fuego), contrapeso (tierra) y **molinete de viento** (el de Mystralia, cuando entre el viento) |
| Trampa dragón | Chorro de fuego | **Chorro de agua a presión que empuja** (X8, pregunta 12 de puzles), chorro de tierra que levanta escombro |
| Corazas de elemento (B1 de combate) | Madera → fuego, brasa → agua, barro → tierra | Hielo, rayo… cuando entren en el juego |
| Limo que deja rastro (B3 de combate) | Agua → mojado, fuego → quemado | Tierra → escombro |

**Cómo se mantiene barato:** las piezas tienen que llevar el **elemento como parámetro** de mapa (`elemento=agua`), no como pieza nueva, igual que `limo … coraza=brasa`.

## Pendiente de Pablo

- Describir el **sonido** del vídeo del arquero: al soltar, al chocar con el escudo y al rebotar (C9).
- Decidir C10 (burbuja), H2 (cómo se marca «sobre mí») y H4 (vecindad u orden).
- Tutorial: TU1 (¿la Gruta Batida es el tutorial?), TU5 (cuándo entra ᛁ línea) y TU6 (¿la barrera protege?).
- C13 Ojáncano: ¿cómo se apaga la barba si es el primer jefe y aún no hay agua? (opciones a, b, c).
- C15 Encuadre de los jefes con la cámara fija (opciones a, b, c).
