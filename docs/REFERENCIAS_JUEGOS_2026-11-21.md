# Inventario de referencias: gamefeel, hechizos y combate (21/11/2026)

21/11/2026 · contexto **dirección (análisis)** · **inventario para leer y decidir, nada construido**.

Qué hacen otros juegos en tres campos, ordenado por técnica y no por juego, para poder elegir piezas sueltas. Cada fila dice qué juego lo hace, cómo funciona y qué significa para Magic Symbols.

**Cómo leer la columna «Para nosotros»:**
- **HAY**: según los documentos ya está construido (`REVISION_GAMEFEEL_30-10.md`, `PROPUESTAS_COMBATE_2026-11-06.md`). Conviene comprobarlo en el juego antes de darlo por bueno.
- **PROP**: ya está propuesto en un documento del repo (se indica cuál). No se repite aquí, solo se enlaza.
- **NUEVO**: no aparece en los documentos del repo.
- **NO**: choca con algo que ya decidiste (cámara fija, tres elementos en la demo, «solo entra lo que da opciones»).

**Marco de la demo** (decidido el 18/11): fuego, agua y tierra; bosque, cueva y pantano; cámara fija. Problema abierto del playtest del 14/11: **el combate es demasiado fácil y hay pocas acciones** (se pasó todo con fuego + flecha). Las secciones 3 y 4 apuntan sobre todo a ese problema.

**Fuentes:** el análisis sale de lo que sé de estos juegos y de las charlas públicas conocidas (Swink, *Game Feel*, 2008; Jonasson y Purho, «Juice it or Lose it», 2012; Nijman, «The Art of Screenshake», 2013; Nintendo, «Breath of the Wild», GDC 2017). No lo he contrastado hoy con webs. Las URL de las referencias que ya se usaron están en `PROPUESTAS_COMBATE_2026-11-06.md` §1. Si un detalle concreto de un juego va a decidir algo, conviene comprobarlo antes.

---

## 0. Resumen en una página

1. **Gamefeel.** Ya tienes casi todo lo de «impacto» (hitstop, destello, empuje, temblor). Lo que falta en la mayoría de juegos buenos y aquí no aparece es **tolerancia de entrada** (buffer, cancelaciones) y **feedback de la jugadora tan rico como el del enemigo**. Son baratos y se notan mucho.
2. **Hechizos.** El sistema de sello + glifos es de la familia de *Mages of Mystralia*, *Transistor*, *Path of Exile* y *Noita*: piezas que modifican piezas. Todos resuelven el mismo problema: que el jugador **vea lo que va a pasar antes de pagar**. Además todos ponen un **coste que obliga a elegir**. Aquí la tinta todavía no obliga (diagnóstico §0.6 de PROPUESTAS).
3. **Combate.** Los juegos que se sienten difíciles y justos con pocas acciones (*Hades*, *Death's Door*, *Doom Eternal*, *Hogwarts Legacy*) hacen lo mismo: **cada enemigo pide una herramienta distinta**. Si una sola herramienta vale para todo, el combate se vuelve fácil, que es justo lo que viste en el playtest. Con tres elementos, la palanca más directa son los **escudos y armaduras elementales** y los **enemigos que modifican el suelo**.
4. **Top 6 para la demo** (detalle en §4): escudos de elemento, enemigos que escriben suelo, la tinta como tensión, buffer de entrada, golpe recibido escalado y un jefe que se gana con lo de su zona.

---

## 1. Gamefeel

### 1.1 Entrada y respuesta (lo que el jugador nota sin saber nombrarlo)

| Técnica | Quién | Cómo funciona | Para nosotros |
|---|---|---|---|
| **Buffer de entrada** | *Celeste*, *Hollow Knight*, *Hades*, cualquier *Souls* | Si pulsas una acción un poco antes de que acabe la anterior, se guarda y sale en cuanto puede (unos 0,1–0,2 s). Sin buffer, el juego «se come» pulsaciones y se siente torpe. | **HAY** para las páginas: `BUFFER_PULSACION` 0,15 s (`magia/lanzador_3d.gd`). Falta comprobar la voltereta y el golpe F. |
| **Cancelar animaciones** | *Hades* (el dash cancela casi todo), *Devil May Cry*, *Wizard of Legend* | Cada animación tiene una ventana en la que otra acción la interrumpe. La esquiva suele cancelar el final de cualquier ataque. | **NUEVO.** Revisar si la voltereta cancela el final del lanzamiento. Si no lo hace, el combate se siente pesado. |
| **Coyote time** | *Celeste*, plataformas en general | Unos milisegundos de margen para saltar después de dejar el borde. | **NO** aplica tal cual (no hay saltos de plataforma). La idea sí sirve: dar margen en las ventanas de premio, como la voltereta perfecta. |
| **Prioridad: respuesta o animación** | *Monster Hunter* y *Souls* (compromiso total) frente a *Hades* (respuesta inmediata) | Un juego elige si la animación manda (pesado, táctico) o si manda el mando (ágil). Mezclar las dos cosas confunde. | Decisión de diseño. Lo de «tiempo bruja» y el libro al 30 % apunta a táctico **al dibujar** y ágil **al moverse**. Conviene escribirlo como regla. |
| **Curvas de aceleración y giro** | *Mario 64*, *Journey*, *Swink* | La velocidad sube y baja con una curva y el giro tiene inercia; según la curva, se siente patinar o se siente preciso. | **HAY** en parte (W3 «cuerpo y cámara que acompañan»). Ajustable en F3. |
| **Apuntado asistido** | *Hades* (asistencia suave), *Tunic*, *Death's Door* | Con cámara fija y vista cenital, el ataque se corrige unos grados hacia el enemigo más cercano en el cono. | Revisar `APUNTADO.md`. Si no hay imán suave, es **NUEVO** y abarata mucho la frustración. |

### 1.2 Anticipación (antes del golpe)

| Técnica | Quién | Cómo funciona | Para nosotros |
|---|---|---|---|
| **Telegrafiar con tres capas** | *Hades*, *Hyper Light Drifter*, *Zelda* | Pose del enemigo, destello o color, y marca en el suelo, cada una algo antes que la anterior. | **HAY** «avisos de ataque». Comprobar que tienen las tres capas y no solo una. |
| **Señal de sonido antes del golpe** | *Sekiro* (kanji + sonido de peligro), *Monster Hunter* | Un sonido distinto por tipo de ataque: el jugador reacciona de oído y no tiene que mirar todo el rato. | **NUEVO** si los avisos son solo visuales. Encaja con las grabaciones de foley ya aprobadas. |
| **Carga visible del hechizo propio** | *Hades II* (Omega), *Elden Ring* (milagros cargados), *Wizard of Legend* | Brillo y sonido que suben mientras se mantiene el botón, con un «clic» al llegar al nivel. | **PROP** C1 (sobrecarga de página, aceptado). Falta el «clic» de nivel alcanzado: **NUEVO**. |

### 1.3 Impacto (el golpe)

| Técnica | Quién | Cómo funciona | Para nosotros |
|---|---|---|---|
| **Hitstop** | *Monster Hunter*, *Hollow Knight*, *Street Fighter* | Se congelan unos fotogramas al conectar; más daño, más pausa. | **HAY** en enemigos (escalado por daño). **PROP** E1: escalarlo por potencia del hechizo. |
| **Destello del color del elemento** | *Hades*, *Genshin Impact* | El enemigo se pinta un instante del color del golpe. | **HAY** (tarea H). |
| **Empuje por masa** | *Hades* (golpe contra pared = daño extra), *Into the Breach* | El empuje depende del peso. En *Hades*, chocar contra una pared o un pilar hace daño. | **HAY** empuje por masa (tarea P). **NUEVO: daño al chocar contra pared o caer a agua honda.** Da una acción táctica sin botón nuevo; la tierra (bloques) la potencia. |
| **Capas de sonido del golpe** | *Doom Eternal*, *Hades* | Tres capas a la vez: transitorio seco, cuerpo del material y cola. Variaciones aleatorias de tono para que no canse. | **HAY** en parte (S1, S2, grabaciones). Revisar que haya variación de tono. |
| **Temblor direccional** | Nijman (Vlambeer) | El temblor va en la dirección del golpe y no es aleatorio; corto y con caída rápida. | Comprobar en `Sensacion3D`. Con cámara fija, mejor temblor pequeño que zoom (los cambios de vista marean). |
| **Partículas de material** | *Hollow Knight*, *Dead Cells* | El golpe suelta trozos del material del enemigo (madera, piedra, limo), no del hechizo. | **NUEVO** a medias: hay muerte por elemento (E). Las partículas del material del enemigo al golpear son otra cosa. |
| **Vibración del mando** | *Ratchet & Clank: Rift Apart*, *Astro Bot* | Vibración distinta por golpe dado, golpe recibido y hechizo lanzado. | **NUEVO.** Es barato en Godot (`Input.start_joy_vibration`). |

### 1.4 Después del golpe (residuo y consecuencia)

| Técnica | Quién | Cómo funciona | Para nosotros |
|---|---|---|---|
| **Residuo en el mundo** | *Noita*, *Wizard of Legend*, *Splatoon* | Quemaduras, charcos y escombro se quedan: el combate deja un mapa de lo que pasó. | **HAY** estados del suelo y charcos de agua. Pilar del juego. |
| **Cámara lenta en el último enemigo** | *Hades*, *Hotline Miami*, *Doom* | Al caer el último enemigo de la sala, 0,3–0,5 s a cámara lenta y un sonido de cierre. | **NUEVO.** Marca el final del encuentro y premia sin coste. |
| **Recompensa visible al matar** | *Doom Eternal* (salen recursos), *Death's Door* (almas) | Al morir, el enemigo suelta lo que el jugador necesita y eso le empuja a pelear en vez de esconderse. | **NUEVO**: que suelten gotas de tinta. Enlaza con §3.3. |
| **Cadáveres y restos que duran** | *Diablo*, *Hades* (poco) | Los restos duran un tiempo y dicen dónde fue la pelea. | Opcional. Cuidado con el rendimiento. |

### 1.5 Feedback de la jugadora

| Técnica | Quién | Cómo funciona | Para nosotros |
|---|---|---|---|
| **Golpe recibido escalado** | *Hades*, *Hollow Knight* (pausa larga + temblor al recibir) | Golpe pequeño = poco ruido; golpe grande = pausa, temblor y viñeta. | **PROP** E3. Hoy siempre es igual (§0.8 de PROPUESTAS). |
| **Aviso de vida baja** | Casi todos | Latido, borde rojo y sonido apagado por debajo de un umbral. | **PROP** E3. |
| **Última oportunidad** | *Hades* (Death Defiance), *Celeste* (modo asistencia) | Un salvavidas visible y limitado en lugar de bajar la dificultad. | **NUEVO**, para cuando suba la dificultad: subir el riesgo sin frustrar. |
| **Muerte rápida y vuelta rápida** | *Celeste*, *Hotline Miami*, *Hades* | Reintentar en menos de 2 s; la muerte no castiga con espera. | Revisar el tiempo actual de reaparición. |

### 1.6 Interfaz con «juice»

| Técnica | Quién | Cómo funciona | Para nosotros |
|---|---|---|---|
| **Barras con retardo** | *Street Fighter*, *Souls* | La vida perdida se queda un momento en otro color antes de bajar. Se ve cuánto dolió. | Comprobar la barra de enemigo y la de la jugadora. |
| **Números que saltan según el tipo** | *Genshin* (color por elemento, grande en reacción), *Hades* | Tamaño y color dicen si fue normal, débil, resistido o reacción. | **PROP** E2 (rótulo propio de reacción). |
| **El libro como objeto vivo** | *Okami* (el pincel), *Inscryption*, *Ni no Kuni* (Wizard's Companion) | El objeto mágico reacciona: tiembla al recibir daño, la tinta salpica, la página brilla cuando está lista. | **HAY** pasar página con la mano (L). **NUEVO**: que el libro reaccione a lo que pasa en combate. Es la seña de identidad del juego. |

---

## 2. Hechizos

### 2.1 Cómo se introduce un hechizo

| Sistema | Quién | Cómo funciona | Lección |
|---|---|---|---|
| **Gesto libre** | *Lost Magic* (DS), *Okami*, *Arx Fatalis*, *Black & White* | Se dibuja la runa. En *Lost Magic* se encadenan hasta tres runas para combinar, en tiempo real, y el reconocimiento es tolerante. | Es la familia de Magic Symbols. *Lost Magic* es la referencia más cercana: **dibujar en combate funciona si el reconocimiento perdona y el mundo se ralentiza**. *Arx* frustraba por ser estricto. |
| **Gesto preparado y botón en combate** | *Arx Fatalis* (3 hechizos preparados), *Okami HD* | Se dibuja con calma y se guarda; en combate se lanza con un botón. | **HAY**: páginas 1/2/3 y lanzamiento rápido. Es el término medio correcto. |
| **Cola de elementos** | *Magicka* | Hasta 5 elementos en cola con teclas y la forma depende de la mezcla. | Referencia del GDD. Su lección es el equilibrio por estructura: los opuestos se anulan. |
| **Varita como programa** | *Noita* | El orden de las cartas en la varita decide qué hace; modificadores, disparadores y dos tiempos (retardo y recarga). | **PROP** C2 (orden) y C3 (al impactar). |
| **Ranuras con tres funciones** | *Transistor* | Cada pieza sirve como ataque, como modificador de otra o como pasiva. Una misma pieza cambia según dónde la pongas. | **NUEVO y muy afín.** Un glifo podría hacer cosas distintas en el núcleo o en un sector. Encaja con el pilar «las combinaciones emergen». |
| **Gemas de apoyo** | *Path of Exile* | Una habilidad más gemas de soporte enlazadas («proyectiles extra», «encadenar»). Cada soporte sube el coste de maná. | Es exactamente glifo = soporte. Lección: **cada soporte sube el coste** (**PROP** A3). |
| **Runas de forma, aumento y disparador** | *Mages of Mystralia* | Cenital tipo Zelda. Cuatro hechizos base (melee, proyectil, área, escudo) + runas de comportamiento («sigue», «rebota»), aumento y disparador («al tocar», «al morir»). Los puzles se resuelven creando hechizos. | **La referencia más parecida a tu juego** y no está en el GDD. Análisis a fondo en `MAGES_OF_MYSTRALIA_2026-11-21.md`. |
| **Runas con gramática** | *Eternal Darkness* (GameCube) | Alineación + verbo + nombre: «proyectar» + «área», etc. Las runas se encuentran en el mundo y un hechizo nuevo se descubre por gramática. | Inspira la **progresión por descubrimiento**: el jugador deduce combinaciones sin que se las den hechas. |

### 2.2 Coste y ritmo

| Sistema | Quién | Cómo funciona | Para nosotros |
|---|---|---|---|
| **Recurso que se recarga atacando** | *Death's Door* (flechas y hechizos con 4 cargas que vuelven al golpear cuerpo a cuerpo), *Doom Eternal* | El hechizo es fuerte, pero obliga a ir al melee para recargarlo. | **PROP** C5 (golpe F devuelve tinta). **Es la palanca más fuerte contra el «fuego + flecha para todo».** |
| **Cargas y no barra** | *Death's Door*, *Hades* (Cast con 1–3 ojos) | Pocas cargas enteras en vez de una barra continua: se cuentan de un vistazo. | **NUEVO**: mostrar la tinta también como «lanzamientos que me quedan» de la página activa. |
| **Retardo y recarga separados** | *Noita* | Uno marca la cadencia entre disparos y otro el descanso al vaciar la varita. | Útil para «repetición»: se puede encarecer en tiempo y no solo en tinta. |
| **Coste por soporte** | *Path of Exile* | Más modificadores, más coste: la potencia no sale gratis. | **PROP** A3. Hoy la tinta no tensa (diagnóstico §0.6). |
| **Hechizo potente con enfriamiento largo** | *Hogwarts Legacy*, *FF XVI* (Eikons) | Pocos hechizos fuertes con enfriamiento visible; obliga a rotar. | **NO** del todo: chocaría con la tinta. Sirve para la sobrecarga (C1), con un enfriamiento visible tras sobrecargar. |

### 2.3 Hechizo que cambia el mundo

| Sistema | Quién | Cómo funciona | Para nosotros |
|---|---|---|---|
| **Química de reglas** | *BotW / TotK* | Elementos sin estado × materiales con estado: el fuego quema la hierba, la hierba propaga y la corriente sube. Se diseñó en un prototipo 2D cenital. | **PROP** B4 (material por casilla, aceptado). |
| **Aura más disparador** | *Genshin Impact* | Un elemento se queda como «aura» en el enemigo y el siguiente lo dispara: agua + fuego = Vaporizar (multiplica el daño); hay un enfriamiento interno para que no se abuse. | **NUEVO como regla general.** Ordena las reacciones: quién deja aura y quién dispara. Con tres elementos, por ejemplo: el agua deja «mojado» y el fuego lo dispara como «vapor»; la tierra deja «lento» y otro elemento lo remata (a decidir). Es simple y crece bien. |
| **Superficies y nubes** | *Divinity: OS2*, *Baldur's Gate 3* | El suelo tiene capa de superficie (agua, fuego, aceite) y capa de nube (vapor, humo). Se pueden «bendecir» o «maldecir». | **PROP** B2/B3 (nube de vapor). |
| **El hechizo deja un objeto** | *Echoes of Wisdom*, *Trine* (el mago conjura cajas y tablones), *Scribblenauts* | Lo que lanzas se queda como objeto con física que se usa en puzles y combate. Límite de objetos vivos. | **HAY** barreras de tierra y bloques. **PROP** C4 (tope de barreras). |
| **Píxel que cae y se propaga** | *Noita* | Todo es material simulado. | Inspiración visual; no copiar la simulación (coste). |
| **Hechizo × hechizo** | *Spellbreak*, *Magicka* | Un hechizo que cruza la zona de otro se transforma. | **PROP** B5. |

### 2.4 Legibilidad y descubrimiento

| Técnica | Quién | Cómo funciona | Para nosotros |
|---|---|---|---|
| **Previsión antes de lanzar** | *Mages of Mystralia*, *Path of Exile* (ficha de la habilidad), *Into the Breach* (todo se ve antes) | El jugador ve forma, alcance y coste antes de pagar. | **HAY** previsión de reacciones. **PROP** E4 (tinta). |
| **Grimorio que se rellena** | *Magicka* (libro de Magicks), *Eternal Darkness*, *Pokémon* (Pokédex) | Lo descubierto se apunta; los huecos vacíos invitan a buscar. | **NUEVO**: página de «reacciones descubiertas». Excluiste el códex, así que solo si encaja como página del libro y no como menú. |
| **Enemigo que enseña el hechizo** | *Zelda* (el objeto de la mazmorra vence al jefe), *Mega Man* | El enemigo o el jefe está diseñado para que la herramienta nueva sea la respuesta. | Ver §3.6 jefes. |
| **Nombres que dicen lo que hacen** | *Genshin* («Vaporizar», «Congelar»), *DOS2* | La reacción tiene nombre y rótulo propio. | **PROP** E2 y tabla §6 de PROPUESTAS. |

### 2.5 Sensación del hechizo (gamefeel aplicado a la magia)

| Técnica | Quién | Cómo funciona | Para nosotros |
|---|---|---|---|
| **Retroceso del mago** | *Wizard of Legend*, *Hogwarts Legacy* | Al lanzar algo fuerte, el personaje retrocede un paso o se clava. | **PROP** E1. |
| **Silueta antes que detalle** | *Kena*, *Hades* | El hechizo se lee por forma y color incluso en una captura en miniatura. | **HAY** como regla de VFX (glifo = forma, elemento = material). |
| **Sonido de lanzamiento por elemento y nivel** | *Hogwarts Legacy*, *Elden Ring* | Cada escuela suena distinta y la versión cargada suena más grave y más ancha. | Revisar con el pack de Leonardo Calvo y el foley de Sonniss. |
| **Pausa de dibujo con sonido propio** | *Okami* (el mundo pasa a sepia y suena el pincel) | Entrar en «modo dibujo» cambia la imagen y el sonido de golpe. | **HAY** el tiempo al 30 %. **NUEVO**: tratamiento visual y sonoro claro al abrir el libro (desaturar, filtrar la música). |

---

## 3. Combate

### 3.1 Vocabulario de acciones

El playtest dijo «pocas acciones». Lo que tienen los juegos de referencia con poco vocabulario pero mucha profundidad:

| Juego | Acciones | Por qué no aburre |
|---|---|---|
| *Hades* | Ataque, especial, Cast, dash, (Omega en II) | Cada acción tiene un papel distinto (daño, área, control, movilidad) y las mejoras cambian **cómo** funcionan, no solo cuánto. |
| *Death's Door* | Melee, ataque cargado, arco o hechizo, rodar | El hechizo es fuerte pero depende del melee (recarga). La esquiva es la defensa principal. |
| *Hyper Light Drifter* | Espada, pistola, dash | La pistola se recarga golpeando con la espada: mismo bucle que *Death's Door*. |
| *Doom Eternal* | Muchas armas, pero cada enemigo pide una | El juego obliga a cambiar: débil a una cosa y casi inmune al resto. |
| *Hogwarts Legacy* | Hechizos de control, fuerza y daño + escudo + parry | Los escudos de color exigen la escuela correcta. |
| **Magic Symbols hoy** | Páginas 1/2/3, golpe F, voltereta, (sobrecarga, propuesta) | Si fuego + flecha vale para todo, sobran las otras dos páginas. **El fallo no es el número de acciones, es que una sola sirve para todo.** |

### 3.2 Enemigos que piden herramientas distintas

| Técnica | Quién | Cómo funciona | Para nosotros (fuego, agua, tierra) |
|---|---|---|---|
| **Escudo elemental** | *Hogwarts Legacy* (escudos de color), *Genshin* (escudos de elemento), *Doom Eternal* | El enemigo lleva un escudo que solo rompe un elemento; luego es vulnerable a todo. | **NUEVO y el más directo.** Goblin con escudo de madera → fuego. Limo de fuego → agua. Mouro con armadura de barro → tierra lo rompe. Obliga a cambiar de página sin castigar al que juega bien. |
| **Armadura que se rompe con impacto** | *Hades* (armadura amarilla), *Doom Eternal* | Barra extra que solo bajan los golpes fuertes o de un tipo. | Tierra = golpe pesado (rompe armadura), fuego = daño continuo, agua = control y empuje. Da un **papel** a cada elemento. |
| **Roles de enemigo** | *Doom Eternal* («piezas de ajedrez»), *Hades* | Hay carne, tanque, artillería, enjambre y apoyo; cada sala mezcla roles. | Ya tienes los roles en goblins (guerrero, arquero, asesino, chamán), pero los niveles son casi solo goblins (§0.7). **PROP** D1. |
| **Debilidad a una forma, no a un elemento** | *Okami* | El enemigo solo cae con un trazo concreto. | **PROP** D4. Encaja: «solo le daña la barrera» o «solo el área». |
| **Enemigo que escribe en el suelo** | *Divinity: OS2*, *Magicka* (los enemigos también lanzan) | El enemigo deja charcos, fuego o barro, y la jugadora tiene que usar el suelo a su favor o limpiarlo. | **NUEVO.** El chamán ya deja veneno. Goblin con antorcha que quema hierba; limo de agua que moja el suelo (la jugadora lo convierte en vapor con fuego). Convierte el suelo en parte del combate y no solo de los puzles. |
| **Enemigo que reacciona al mundo** | *BotW* (los bokoblins huyen del fuego, cogen armas) | La IA lee la química y la jugadora puede usarla para manipularla. | **PROP** D2. |
| **Enemigo invulnerable mientras…** | *Zelda* (Darknut, Stalfos), *Hollow Knight* | Bloquea de frente, se cubre al cargar, es vulnerable al terminar su ataque. | El guerrero con escudo va por aquí. Ampliar a otros enemigos como regla: cada uno tiene una ventana. |

### 3.3 Bucles de recursos (qué empuja a pelear bien)

| Técnica | Quién | Cómo funciona | Para nosotros |
|---|---|---|---|
| **El melee recarga el hechizo** | *Death's Door*, *Hyper Light Drifter* | Sin melee no hay hechizos: obliga a acercarse y a arriesgar. | **PROP** C5. |
| **Cada recurso sale de una acción distinta** | *Doom Eternal* (motosierra → munición, ejecución → vida, lanzallamas → armadura) | El jugador cambia de acción porque necesita cosas distintas. | **NUEVO** en el reparto: por ejemplo, la tinta vuelve con el golpe F, la vida con remates de reacción y la sobrecarga con la voltereta perfecta. Cada acción alimenta otra. |
| **Premio por reacción** | *Genshin*, *Hades* (Duo boons) | Hacer la reacción rinde más que repetir el mismo golpe. | **HAY** tinta por reacción. Comprobar que el premio se nota (E2). |
| **Castigo por spam** | *Magicka* (te dañas a ti mismo), *Noita* | Repetir lo mismo tiene un coste o un riesgo. | **PROP** B7 (fuego amigo suave) y A3. |

### 3.4 Control de masas y estados

| Técnica | Quién | Cómo funciona | Para nosotros |
|---|---|---|---|
| **Barra de aturdimiento (postura)** | *Sekiro*, *FF VII Remake*, *FF XVI* | Además de vida, el enemigo tiene una barra que se llena con presión y lo deja vulnerable. En *FF7R* hay que «presionarlo» con algo concreto. | **NUEVO.** Encaja con «mojado + fuego = vapor que aturde». La barra recompensa variar elementos frente a repetir. |
| **Rendimientos decrecientes** | *Genshin* (enfriamiento interno), MMO | El mismo control seguido dura menos cada vez. | **NUEVO** y barato. Evita que un elemento bloquee a todo enemigo. |
| **Estado que abre un remate** | *Magicka*, *DOS2* | Congelado + golpe = roto. | **PROP** B1. Con tres elementos: «embarrado» + fuego = barro cocido (inmóvil, frágil); a decidir. |

### 3.5 Diseño de encuentros

| Técnica | Quién | Cómo funciona | Para nosotros |
|---|---|---|---|
| **Sala como receta** | *Hades*, *Doom Eternal* | Cada encuentro es una mezcla de roles + terreno + oleadas, escrita como datos. | **PROP** D1. Encaja con «datos, no código». |
| **Terreno con peligros** | *Hades* (trampas que dañan a enemigos también), *Into the Breach* | Pinchos, agua honda y barriles dañan a los dos bandos; empujar a un enemigo encima es una jugada. | **HAY** barriles y trampas de pared. **NUEVO**: diseñar salas para empujar enemigos a ellos (enlaza con daño contra pared, §1.3). |
| **Oleadas con aviso** | *Hades*, *Hyper Light Drifter* | El enemigo nuevo aparece con un círculo visible 1 s antes. | Comprobar cómo aparecen hoy. |
| **Encuentros opcionales difíciles** | *Hades* (salas de reto), *Zelda* (cuevas de reto) | La dificultad alta es opcional y se premia; el camino principal sigue suave. | Encaja con «no subir la dificultad de las misiones»: **el reto va aparte**. |

### 3.6 Jefes

| Técnica | Quién | Cómo funciona | Para nosotros |
|---|---|---|---|
| **El jefe examina lo aprendido** | *Zelda* (el objeto de la mazmorra), *Mega Man* | El jefe se vence con la herramienta de su zona, usada de una forma nueva. | Bosque → fuego, pantano → agua, cueva → tierra (o como lo repartas). |
| **Fases que añaden una regla** | *Hollow Knight*, *Cuphead* | Cada fase añade un ataque o cambia el suelo; no solo sube la velocidad. | Las fases pueden cambiar el estado del suelo de la arena: es tu mecánica principal. |
| **Arena que se transforma** | *Hades* (Hidra), *Furi* | El jefe cambia la arena (agua, lava, plataformas). | Encaja con estados del suelo y con la Santa Compaña o el mouro como jefes de mitología. |

### 3.7 Dificultad sin frustrar

| Técnica | Quién | Cómo funciona | Para nosotros |
|---|---|---|---|
| **Dificultad que elige el jugador** | *Hades* (Pacto de castigo), *Celeste* (modo asistencia) | Interruptores concretos («enemigos +20 % de vida») en vez de fácil, normal y difícil. | Para más adelante; no hace falta en la demo. |
| **Variantes por zona** | *Zelda* (enemigos de color: rojo, azul, negro) | El mismo enemigo con más vida, otra debilidad y otro color. | **PROP** D5 y A2. Barato y legible. |

---

## 4. Lo que yo haría primero para la demo (fuego, agua y tierra)

Elegido por **lo que ataca el «combate demasiado fácil»**, por coste y por no salirse del marco decidido. Si algo ya está propuesto, aquí se dice solo por qué subirlo en la lista.

| # | Qué | De quién | Por qué ahora | Coste |
|---|---|---|---|---|
| 1 | **Escudos de elemento** en tres enemigos (goblin con escudo de madera → fuego; limo de fuego → agua; mouro con coraza → tierra) | *Hogwarts Legacy*, *Doom Eternal* | Obliga a usar las tres páginas sin endurecer las misiones. Responde directamente a «todo con fuego + flecha». | Medio: barra extra en `Combate3D` + VFX del escudo. |
| 2 | **Enemigos que escriben suelo** (goblin con antorcha, limo de agua) | *DOS2*, *Magicka* | Lleva al combate los estados del suelo, el pilar del juego, que hoy viven casi solo en puzles. | Bajo: ya existe la escritura de estados. |
| 3 | **La tinta como tensión**: A3 (coste por glifo) + C5 (el golpe F devuelve tinta) + gotas de tinta al matar | *Path of Exile*, *Death's Door*, *Doom Eternal* | Sin coste no hay decisión. Con el golpe F que recarga, el combate gana ritmo de ida y vuelta. | Bajo: constantes + un drop. |
| 4 | **Cancelación con voltereta** y buffer también para voltereta y golpe F (el de las páginas y A4, voltereta a 1,5 s, ya están en el código) | *Hades*, *Celeste* | Hace que subir la dificultad se sienta justo y no torpe. Es la base antes de endurecer nada. | Bajo. |
| 5 | **Golpe recibido escalado, vida baja y cámara lenta al acabar la sala** (E3 + §1.4) | *Hades*, *Hollow Knight* | Cuando el combate sea más duro, la jugadora tiene que notar el peligro. | Bajo. |
| 6 | **Un jefe por bioma que se gane con su elemento**, con fases que cambian el suelo | *Zelda*, *Hollow Knight* | Cierra la demo con un examen de lo aprendido. | Alto; empezar por uno. |

Después, según el playtest: daño contra pared y agua honda (§1.3), barra de aturdimiento (§3.4), aura + disparador al estilo *Genshin* como regla de reacciones (§2.3) y el libro que reacciona en combate (§1.6).

**Para estudiar jugando** (una tarde cada uno, si quieres ver las cosas en mano): *Mages of Mystralia* (el hechizo compuesto más parecido al tuyo), *Death's Door* (combate cenital con pocas acciones y recarga por melee) y *Hades* (feedback y encuentros).

---

## 5. Preguntas para decidir

1. ¿Te encaja que **cada elemento tenga un papel** (tierra = romper armadura, fuego = daño continuo, agua = control y empuje) o prefieres que los tres sirvan para todo y solo cambie la debilidad?
2. ¿**Escudos de elemento** (§3.2) en la demo, sí o no? Es lo que más cambiaría la sensación de «demasiado fácil».
3. ¿El combate es **táctico al dibujar y ágil al moverse** (regla de §1.1)? Si es así, el buffer y las cancelaciones van primero.
4. ¿Página de «reacciones descubiertas» dentro del libro, o se queda fuera como el códex?
