# Plan de combate (22/11/2026)

22/11/2026 · contexto **dirección (combate)** · **plan para que Pablo decida; no hay nada implementado.**

Se basa en tres documentos. `CATALOGO_EXISTENTE_2026-11-22.md` (§0, §3 y §4) dice lo que ya hay. `PROPUESTAS_SESION_MYSTRALIA_2026-11-21.md` (C1–C23 y P1–P9) y `REFERENCIAS_JUEGOS_2026-11-21.md` (§3 y §4) dan las ideas. Las cifras dudosas se han vuelto a mirar en el código (§1). Las rutas son relativas a `E:\magic-symbols\`.

**Coste:** B bajo (constantes o una función), M medio (una pieza nueva o varios archivos), A alto (sistema nuevo o arte).

## Decisiones de Pablo (22/11, respuestas a §10)

| # | Pregunta | Decisión | Qué cambia en el plan |
|---|---|---|---|
| 1 | C10 · Burbuja | **Las flechas rebotan** contra la burbuja de viento, agua y tierra, y **se queman** contra la de fuego. La burbuja aguanta varias, como el escudo de Mystralia (O3) | B2: la fila de la burbuja ya está decidida. Rebote como en O3: la flecha sale despedida de lado, girando, y cae (no vuelve al tirador; volver es solo del viento en las barreras) |
| 2 | C13 · Ojáncano | **Es un jefe posterior**: llega cuando ya hay agua, y apagar la barba es el examen del agua (opción b) | F2 se queda al final del orden. No hace falta la opción a ni la c |
| 3 | C15 · Cámara de jefe | **Sí: cada jefe tiene su cámara**, distinta según el jefe | F1 con la opción b: un tamaño propio por sala de jefe (`zoom=` en `; camara`), fijo durante el combate |
| 4 | Espera del guerrero | **Se deja como está, de momento**: 0,6 s de espera, con el aviso cubriendo el ataque entero (~1,2 s) | A1 |
| 5 | Escudos | **Valen los tres**, y **se permiten los casos contraproducentes** que se ven venir (el fuego cura la costra del limo) | B1 sin cambios. C20 #5 queda decidido: se permiten |
| 6 | Tinta al matar | **+6 / +10 / +4, de momento** | C1 con esas cifras |
| 7 | Postura | **No, de momento.** Si hace falta más adelante, se estudia | D2 aparcado (sale del orden) |
| 8 | Kit de la partida nueva | **No se toca.** Qué glifos hay en cada sitio se diseñará al crear los niveles | E2: fuera la nota del kit |
| 9 | Arquero (C7, C8) | **No a las dos.** La flecha tiene que poder pararse aunque no sea realista: se queda lenta (9 u/s) para que dé tiempo a sacar la barrera | A1 sin línea de apuntado. C8 descartada |
| 10 | Aviso del dragón | **Rectángulo rojo que parpadea** y un **movimiento exagerado de la cabeza hacia atrás** | A2: rectángulo del carril (B) y más recorrido de cabeza en la fase de carga |

---

## 0. El problema y cómo lo ataca el plan

**Playtest del 14/11:** el combate es demasiado fácil y **fuego + flecha vale para todo**. Mirando el código, las causas son estas:

1. **Nada obliga a cambiar de página.** Desde el 6/11 no hay debilidades por defecto. Solo los goblins de los niveles «Bosque*» son débiles al agua y resisten el fuego (×0,75), y eso no basta para dejar de usar fuego. El único escudo de elemento (madera → fuego) solo está en ArenaCombate.
2. **La tinta no aprieta.** Se regenera, cada reacción da +20 y el golpe F devuelve tinta. Matar no da nada, pero tampoco hace falta.
3. **Casi todos los enemigos son goblins de 50 de vida.** El suelo (el pilar del juego) casi no entra en el combate: solo lo escriben el limo y el chamán.
4. **Los ataques que sí aprietan avisan tarde.** El guerrero y el arquero esperan sin marca antes del aviso (§1). Endurecer sin arreglarlo se sentiría injusto.

**Orden del plan:** primero **justicia** (que todo se vea venir), luego **obligar a cambiar de página**, luego **recursos y profundidad**, y por último **encuentros y jefes**. Las fases A y B son las que responden al playtest. Las fases C–F lo refuerzan.

| Fase | Qué | Puntos |
|---|---|---|
| A · Justicia | Avisos completos, dragón con `AvisoAtaque3D`, golpe del elemental y no cobrar por nada | A1–A4 |
| B · Cambiar de página | Escudos de elemento, tabla de contacto C19 y enemigos que escriben suelo | B1–B3 |
| C · Recursos | Tinta al matar | C1 |
| D · Profundidad | Daño contra pared (la postura queda aparcada) | D1 |
| E · Encuentros | Oleadas con aviso y enemigos en los biomas de la demo | E1–E2 |
| F · Jefes | Encuadre C15, Ojáncano C13 y mouro zombi C23 | F1–F3 |

---

## 1. Lo comprobado en el código (correcciones al catálogo)

| Punto | El catálogo dice | El código dice |
|---|---|---|
| **Carga del guerrero** | Carga 0,6 s sin aviso y luego el círculo | Correcto, con un matiz: son **0,6 s quieto sin marca** (`PREPARAR_GOLPE`, `enemigos/combate_3d.gd:137`) y luego **~0,6 s de aviso** (`MOMENTO_GOLPE_GUERRERO` 0,19 de un clip de ~3,2 s, `:144`). El ataque dura ~1,2 s, pero **solo se ve la mitad**. La tabla C18 da «0,6 s de preparar» y se queda corta |
| **Carga del arquero** | Tensa 0,9 s sin aviso | Correcto. Durante los 0,9 s (`PREPARAR_FLECHA`, `:207`) **tampoco suena nada**: `arco_carga` suena al terminar, junto con el aviso (`:2131`, `:2197`). La tabla C18 cuenta esos 0,9 s como tiempo de reacción, pero **no se ven ni se oyen**. El tiempo de reacción real es el clip hasta soltar más el vuelo |
| **Limo** | No escribe suelo (C2 «propuesta») | **A MEDIAS**: su acometida ya pone su elemento en la casilla de la jugadora (agua → mojada, fuego → quemada…; `enemigos/limo_3d.gd:853-871`). Solo al acertar. No deja rastro al moverse |
| **`ganar_jefe()`** | «Matar no da tinta; `ganar_jefe()` no la llama nadie» | Es otra cosa: sube la **barra máxima** (+30 por jefe, `nucleo/tinta.gd:176`). No es tinta al matar. Para soltar tinta ya existe `recuperar(cantidad)` (`:363`) |
| **Dragón** | No usa `AvisoAtaque3D` | Confirmado: sus anillos son mallas propias (`objetos/dragon_jefe_3d.gd:401`, `:824-834`; `ANILLOS_S` 0,8) |
| **Pantano** | Sin enemigos | Confirmado: `Pantano.txt` no tiene ninguna pieza de enemigo. `CuevaAgua.txt` y `MonteSumicio.txt` tampoco. Solo `PruebaPantano.tscn` usa `kit = "demo"` |
| **Cámara por sala** | Solo acerca | Confirmado: `ZOOM_MINIMO_SALA` 3,5 y ningún máximo (`presentacion/camara_salas.gd:17`) |

---

## 2. Fase A · Justicia (antes de endurecer nada)

> **Estado (22/11, hecho sin ventana salvo A3):**
> - **A1 hecho.** El guerrero avisa ahora ~1,33 s, desde que empieza a cargar (antes ~0,7 s visibles). El asesino avisa 1,05 s. El arquero avisa y suena desde que empieza a tensar. Prueba: `herramientas/prueba_aviso_carga.gd`, 0 fallos. `prueba_ataques_avisados.gd` se ha actualizado (el aviso del arquero ya sale antes del clip) y da 0 fallos.
> - **Lo que salió al medir:** el arquero de `prueba_ataques_avisados` tarda **~5,6 s** desde que avisa hasta que la flecha llega, y el de la Gruta Batida **3,5 s** hasta soltar. El clip de disparo tarda mucho más que los 0,9 s de tensar que daba la tabla C18. La flecha se puede parar de sobra; si parece demasiado lenta, se ajusta `VEL_ANIM_ARQUERO`.
> - **Fallo previo arreglado:** el goblin con escudo de la ArenaCombate se creaba **sin jugador** (`escenas/puzle.gd`, pieza `goblin_escudo`): nunca veía a nadie ni atacaba. Ahora busca al jugador como el gólem.
> - **A2 hecho:** rectángulo rojo que parpadea (4 veces por segundo) y el cuello se echa hacia atrás y vuelve de golpe al soplar. Da la voltereta perfecta. `escenario_dragon_jefe.gd`: 0 fallos.
> - **A3 hecho:** `ELEM_MOMENTO_GOLPE` 0,28; el clip va a ×0,6 hasta el golpe y a ×1 después (el ataque dura ~3,6 s, no 5). Aviso de 1,42 s. Fotos en `docs/capturas/anticipacion_enemigos_A3`: el puño toca el suelo en la misma foto que sale el daño.
> - **A4: la premisa no se cumplía.** Tierra + barrera sola **no es un cobro sin efecto**. Sale con 0 manifestaciones porque su única casilla es la tuya y ahí no se levanta el bloque («estás encima»). Pero su **protección (SolidezV2) sí nace y te cubre**. Lo que falla es que **no se ve nada** y que no cuenta para el tope de 3 barreras. No se ha tocado el cobro. Prueba: `herramientas/prueba_cobro_sin_efecto.gd`. **Decisión de Pablo** (§10, pregunta 11).

### A1 · Aviso en la carga previa del guerrero y del arquero (C22, C18)
- **Qué:** que el aviso salga **cuando empieza la carga** y no cuando arranca el clip.
  - **Guerrero:** el círculo sale al empezar `_carga` y dura `PREPARAR_GOLPE` + lo que tarda el clip en golpear (~1,2 s). Hoy se ven 0,6 s. El encogerse (`_anticipar`) pasa también al principio.
  - **Arquero:** el círculo que sigue a la jugadora sale al empezar a tensar y `arco_carga` suena entonces, no 0,9 s después. **Sin línea de apuntado (C7) y sin flecha más rápida (C8)** (Pablo, 22/11): la flecha sigue a 9 u/s para que se pueda parar con barrera.
  - Si el enemigo deja de cargar (le pegan, se ciega o la jugadora sale del alcance), el aviso se cancela. `AvisoAtaque3D.cancelar()` ya existe.
- **Ojo:** con más aviso, la voltereta perfecta (ventana de 0,6 s) no cambia, pero el combate se hace más fácil. Se compensa con la fase B, no quitando aviso. Si se quiere mantener la presión, **acortar `PREPARAR_GOLPE` a ~0,3 s** con el aviso completo: el ataque se adelanta y se ve entero.
- **Archivos:** `enemigos/combate_3d.gd` (`_atacar` :2078, `_ia_arquero` :2103, `_ia_arquero_fijo` :2169, `_avisar_ataque` :2248).
- **Coste:** B. **Depende de:** nada.
- **Prueba:** ampliar `herramientas/captura_anticipacion_enemigos.gd` al guerrero y al arquero (Bosque 02 o ArenaCombate). Debe salir que el aviso aparece al empezar la carga y que el daño llega cuando el aviso acaba. `escenario_arena_combate.gd` debe seguir con 0 fallos.

### A2 · El dragón usa `AvisoAtaque3D` (C22)
- **Qué:** en la fase de carga, el dragón pinta un `AvisoAtaque3D` del carril que va a barrer, que dura carga + anillos (1,7 s). Con eso entra la **voltereta perfecta y el tiempo bruja** en el jefe, y las flechas de borde de pantalla. Los anillos se quedan como adorno de la boca o se quitan; lo decide Pablo al verlo.
- **Forma (decidida, Pablo 22/11):** un **rectángulo rojo que parpadea** sobre el carril entero, más un **movimiento exagerado de la cabeza hacia atrás** al cargar (hoy la cabeza va atrás y hacia el lado; se le da más recorrido). El parpadeo es nuevo en `AvisoAtaque3D`: una opción que haga latir el relleno, sin tocar a los demás enemigos.
- **Archivos:** `objetos/dragon_jefe_3d.gd` (fase de carga) y, si se quiere abanico, `enemigos/aviso_ataque_3d.gd`.
- **Coste:** B (rectángulo) o M (abanico). **Depende de:** nada.
- **Prueba:** `herramientas/escenario_dragon_jefe.gd`, con una comprobación nueva: una voltereta en los últimos 0,6 s del aviso activa el tiempo bruja. Fotos con `captura_dragon_jefe.gd`.

### A3 · El golpe del elemental coincide con el daño (C22)
- **Qué:** lo ya propuesto. `ELEM_MOMENTO_GOLPE` 0,6 → ~0,28 y el clip más lento (`vel_anim` ≈ 0,6) para mantener ~1,4 s de aviso.
- **Archivos:** `enemigos/combate_3d.gd:156` y `:2087`.
- **Coste:** B. **Depende de:** nada.
- **Prueba:** `captura_anticipacion_enemigos.gd` otra vez. El golpe tiene que verse y hacer daño en el mismo fotograma (±0,1 s).

### A4 · No cobrar tinta por un hechizo que no se forma (C20 #2)
- **Qué:** si un hechizo sale con 0 manifestaciones, se rechaza **antes de cobrar**, con el «no puedes» que ya existe (página en rojo). Es lo mismo que hace ᛒ sobre agua. Además hay que averiguar por qué tierra + barrera sola sale con 0 manifestaciones en el carril del dragón y no en la Sala del Gólem.
- **Archivos:** `magia/lanzador_3d.gd` (el cobro), `magia/hechizo_vivo.gd` (las manifestaciones) y `magia/glifo_suelo.gd:12` como modelo.
- **Coste:** B–M (depende de la causa). **Depende de:** nada. Ayuda a C18: la barrera de tierra tiene que salir para que la tabla C19 tenga sentido.
- **Prueba:** reproducir el caso del registro (tierra + barrera en `SalaDragon`, tinta 88 → 76). Debe quedar en 88 y sonar el «no puedes». `prueba_dano_tinta.gd` sin cambios.

### A5 · Regla de partida del cuerpo a cuerpo: anticipación quieta y golpe seco (C25, Mystralia O23)
- **Regla** (Pablo, 22/11: «busquemos de inicio este output lag»), para guerrero, asesino, loberno y canouro:
  1. **pose de carga sostenida** durante toda la anticipación: cuerpo encogido, arma atrás y quieto;
  2. **anticipación de 0,5–0,7 s**;
  3. **ejecución en ≤ 0,1 s**;
  4. **recuperación visible**.
  - El círculo del suelo dura exactamente la anticipación.
  - Para los jefes (C22), la misma estructura en cada golpe: la pose se puede acortar en fases duras, nunca quitar.
- **Hecho en el guerrero (22/11), sin commit.** Los demás, después de que Pablo lo vea.
  - `enemigos/combate_3d.gd`: `GOLPE_SECO` (interruptor), `MOMENTO_CARGA_GUERRERO` 0,14, `GOLPE_SECO_LLEGA` 0,25, `GOLPE_SECO_EJECUTA` 0,07, `_iniciar_golpe_seco` y `_sostener_anticipacion`.
  - El 0,14 está medido sobre las pistas del clip LeftSlash (`herramientas/medir_clip_guerrero.gd`): el brazo del arma casi se para en el 0,14 (34 °/s, cambia de sentido) y va más deprisa en el 0,19–0,20 (≈ 410 °/s), el contacto.
- **Medido** (`herramientas/prueba_golpe_seco.gd`, 0 fallos):

  | | Antes | Ahora |
  |---|---|---|
  | Círculo | 1,36 s | **0,67 s** |
  | Pose | Ninguna (de pie, y un pulso de encogerse de 0,3 s) | **Congelada en la carga** (fracción 0,149) y encogida (alto/ancho 0,77) de 0,27 a 0,63 s |
  | De soltar al contacto | ~0,6 s de balanceo | **1 fotograma** (0,67 → 0,70 s) |
  | Daño | Al acabar el círculo | A 0,70 s, cuando se llena (0,67) |

- **Fotos:** `docs/capturas/golpe_seco_antes` y `docs/capturas/golpe_seco_despues`, con `captura_anticipacion_enemigos.gd -- <carpeta> guerrero`. Después: del 01 al 09, agachado con la porra atrás y quieto; en el 10, el golpe; luego, la recuperación.
- **Ventana de esquiva del cuerpo a cuerpo: decidida y hecha** (Pablo, 22/11: «Sí, a 0,25 s»).
  - Cada `AvisoAtaque3D` lleva su `ventana`. El golpe seco del guerrero usa `VENTANA_CUERPO` = **0,25 s**. Los ataques lentos (gólem, elemental, aliento, flechas) siguen con `VENTANA_ESQUIVA` = 0,6.
  - El parpadeo blanco del círculo y la flecha del borde de pantalla empiezan en esa ventana.
  - Prueba (`prueba_golpe_seco.gd`): una voltereta a 0,37 s del golpe no da tiempo bruja; una a 0,17 s, sí. 0 fallos.
- **Ojo:**
  - ~~La ventana de esquiva (0,6 s) ocupaba casi todo el círculo de 0,67 s~~: resuelto arriba.
  - Con ataques más cortos, las fichas de G2 rotan antes: se espera menos turno.

> **Fuera de este plan, pero lo necesita:** el buffer del golpe F y la voltereta que cancela el final del lanzamiento (G1). Son de la sesión de **gamefeel**. Conviene que lleguen antes de la fase B, porque con enemigos más duros la jugadora necesita poder salir del lanzamiento.

---

## 3. Fase B · Obligar a cambiar de página (el núcleo del plan)

> **Estado (22/11, hecho sin ventana, sin arte):**
> - **B1 hecho, salvo dónde se colocan** (eso es E2). Componente nuevo `enemigos/coraza_elemento_3d.gd` (`CorazaElemento3D`): una capa sobre todo el cuerpo que se consulta como el escudo (`Combate3D.on_spell_hit`, `prever_golpe`, `escudo_cubre`). Mientras está entera, nada le quita vida.
>   - **Barro** (goblin, pieza nueva `goblin_coraza`): la tierra la agrieta (2 golpes); el agua la ablanda y entonces basta 1; el fuego la endurece (hasta 3).
>   - **Brasa** (limo de fuego, `limo … coraza=brasa`): el agua la rompe; el fuego la aviva; la tierra rebota.
>   - El rombo va del color del elemento que la rompe. La capa es una cápsula de color, provisional (Pipeline).
>   - En la ArenaCombate, al sur. Prueba: `prueba_coraza_elemento.gd`, 0 fallos.
>   - ~~La flecha de tierra solo llegaba a 1 casilla~~ → **resuelto por HECHIZOS (22/11):** Pablo quitó la gravedad de los hechizos («penaliza demasiado»; `Hechizo.GRAVEDAD_EN_HECHIZOS = false`) y ahora las flechas de tierra y agua vuelan rectas y aciertan a 1 y a 2 casillas.
> - **B2 hecho:** tabla `nucleo/contacto.gd` (`Contacto`), tal cual la aprobada, más la burbuja de C10.
>   - La usan la flecha del arquero, la de la trampa de flechas y el aliento del dragón.
>   - Lo que no protege deja cruzar el proyectil sin gastar la barrera, con golpe sordo y, la primera vez, un rótulo («El fuego no para el fuego»).
>   - Prueba: `prueba_contacto.gd`, 0 fallos.
>   - **Pendiente:** la previsión (`PrevisionReaccion3D`) aún no lee la tabla. La IA aún rodea barreras que no le paran. La bola de veneno solo mira la burbuja. El chorro de fuego de la trampa dragón es un haz de hechizo que se corta en cualquier barrera, sin mirar el elemento. El haz del dragón se ve cortado por la barrera de fuego aunque el daño pasa.
> - **B3, limo hecho:** el limo de agua deja suelo mojado y el de fuego, quemado (1 casilla cada 0,5 s). Su propio rastro no lo alimenta. Prueba: `prueba_rastro_limo.gd`, 0 fallos. **El goblin con antorcha queda pendiente** (necesita la antorcha como pieza de mano, Pipeline).

### B1 · Escudos de elemento (C1)
- **Qué:** generalizar `Escudo3D` para que lo rompa **un elemento**, no solo el fuego. Tres escudos, uno por elemento de la demo:

  | Escudo | Lo rompe | Cómo se rompe | Lo demás | Enemigo |
  |---|---|---|---|---|
  | **Madera** (ya existe) | Fuego | Arde 4 s; el goblin se quema el brazo y no ataca | Lo empuja y para | Goblin con escudo |
  | **Costra de brasa** | Agua | El agua lo apaga en vapor y se agrieta | El fuego lo **cura** (caso contraproducente que se ve, C20 #5) y la tierra rebota | Limo de fuego (`limo elemento=fuego`) |
  | **Coraza de barro seco** | Tierra | Un golpe de tierra (flecha o pulso) la rompe en trozos | El fuego la **cuece** (más dura un rato, se ve) y el agua la ablanda: la tierra la rompe a la primera | Goblin guerrero o mouro con coraza (lo elige Pablo) |

- **Cómo:** `Escudo3D` ya tiene `papeles` (`inflamable`, `bloquea_proyectiles`). Se añade un dato `rompe_con` (elemento) y un papel por material. El bloqueo de frente (cono de 120°) y el empujón sin daño ya están. Para el limo, el escudo es una **capa del cuerpo**, no un disco en el brazo: cubre todos los lados y se rompe entero.
- **Lectura:** el borde y el rombo del enemigo ya se pintan del color de la debilidad (V5). Con escudo, el rombo pasa a ser **el color del elemento que rompe el escudo** y, al romperse, vuelve al de su debilidad.
- **Dónde ponerlos (para que la demo los pida):** el goblin con escudo de madera **sale de ArenaCombate** y entra en el Bosque 02 (pradera o campamento). El limo de fuego va a la Cueva y la coraza al Pantano (E2).
- **Archivos:** `enemigos/escudo_3d.gd`, `enemigos/combate_3d.gd` (la consulta `escudo.para`), `enemigos/limo_3d.gd` y `enemigos/limo_visual_3d.gd` (la capa), `escenas/puzle.gd:464` y `:501` (parámetro `escudo=` en `vigia` o en el marcador), los mapas y el arte de las dos mallas nuevas (Pipeline).
- **Coste:** M (código) + arte. **Depende de:** nada para el de madera. La coraza necesita que la tierra salga bien (A4).
- **Prueba:** ampliar `herramientas/prueba_escudo_goblin.gd` con los tres materiales (rompe / no rompe / caso contraproducente) y `prueba_limo_combate.gd` con el limo de fuego. Fotos con `captura_goblin_escudo.gd` y `captura_limo.gd`.

### B2 · Tabla de contacto barrera × proyectil (C19, aprobada como punto de partida)
- **Qué:** la tabla del 21/11, sin cambios: flecha, flecha ardiendo, fuego, agua, piedra y veneno contra barrera de fuego, agua y tierra (viento después). Catálogo cerrado de acciones: `para`, `quema`, `apaga`, `frena`, `vapor`, `pasa`, `repele`.
- **Incluye C20** (lo que no hace nada se tiene que leer):
  - Feedback común de «ineficaz»: golpe sordo, chispa gris y, la primera vez, rótulo corto («El fuego no para el fuego»). Se reutilizan `COLOR_FLASH_PIEDRA` y `Sensacion3D.golpe_sordo`.
  - Si el proyectil **pasa**, la barrera no se gasta. Si hay **vapor**, se gastan las dos.
  - Distinguir **cruzar una llama** (la flecha se enciende, A2) de **chocar con una barrera de fuego** (se quema).
  - `PrevisionReaccion3D` lee la misma tabla y marca el caso ineficaz (C20 #4).
  - La IA rodea solo las barreras que de verdad la paran (C20 #6).
- **C10 queda dentro (decidido, Pablo 22/11):** la flecha **rebota** contra la burbuja de viento, agua o tierra y **se quema** contra la de fuego. La burbuja **no revienta** con flechas y aguanta varias. El rebote es como en Mystralia (O3): destello blanco en estrella y la flecha sale despedida de lado, girando, y cae. Se reutiliza `_desviar_flecha`.
- **Archivos:** tabla nueva `nucleo/contacto.gd` (o dentro de `Lanzador3D`, generalizando `REACCIONES_BURBUJA`, `lanzador_3d.gd:82-91`). Además `enemigos/combate_3d.gd` (`_vuelo_flecha` :2336-2375), `enemigos/bola_veneno_3d.gd`, `objetos/dragon_jefe_3d.gd` y las trampas dragón (el chorro de fuego), y `presentacion/prevision_reaccion_3d.gd`.
- **Coste:** M. **Depende de:** A4 (la barrera de tierra tiene que salir).
- **Prueba:** escenario nuevo `herramientas/escenario_contacto.gd`. Para cada celda de la tabla, un tirador (arquero, chamán, trampa dragón) contra una barrera ya puesta. Se comprueba la acción, si la barrera se gasta y si la jugadora recibe daño. `prueba_catalogo_reacciones` y `prueba_dano_tinta` se **regeneran a propósito** y se anota en el diario (C20 #8).

### B3 · Enemigos que escriben suelo (C2)
- **Qué:** que el suelo sea parte del combate.
  - **Limo:** hoy solo escribe al acertar. Que deje **rastro al moverse**, como mucho una casilla cada ~0,5 s y con los topes globales de `suelo-legible`: limo de agua → mojada, limo de fuego → quemada. Así la jugadora tiene combos: un limo de agua moja el suelo y la tierra o el rayo aprovechan el mojado.
  - **Goblin con antorcha** (variante del guerrero): su golpe deja la casilla **quemada** y prende la hierba (con la propagación controlada que ya existe). Es más peligroso, pero el agua lo apaga (la antorcha se apaga y pasa a ser un guerrero normal).
  - **Ojáncano** (F2): sus mazazos con la barba encendida queman el suelo.
- **Archivos:** `enemigos/limo_3d.gd` (`_physics_process`, reutilizando `_elemento_a_la_jugadora` :853), `enemigos/combate_3d.gd` (variante `antorcha` en `_conectar`), `escenas/puzle.gd` (parámetro) y `mundo/estados_suelo_3d.gd` (`poner` y `aplicar` ya sirven; no hace falta tocarlo).
- **Coste:** B (limo) + B–M (antorcha: la pieza de mano es arte).
- **Depende de:** nada. Se luce más con E2 (enemigos en el Pantano).
- **Prueba:** `prueba_limo_combate.gd`: un limo de agua que anda 5 s deja N casillas mojadas, sin pasar del tope. Escenario de antorcha: el golpe deja quemada la casilla y el agua apaga la antorcha.

---

## 4. Fase C · Recursos

> **Ojo (22/11, cambio de HECHIZOS, B9a):** ᛇ flecha ya no sube el daño. Fuego + ᛇ hace 13,2 lleve una flecha o tres, y un goblin (50 de vida, DEF 2) pide 5 flechas de fuego. Las cifras de la tinta al matar (+6/+10/+4) y el balance del dragón (20 por flecha al núcleo) se revisan con esto en mano.

### C1 · Tinta al matar (C3)

> **Estado (22/11): hecho sin ventana, junto con el recogible de vida que pidió Pablo** («mete un recogible en botín de los enemigos que te cure al recoger y otro para la tinta»). Todo está en `enemigos/combate_3d.gd`: `_soltar_recogibles`, llamado desde `_soltar_botin`, y `Botin3D` con `tipo`, que reutiliza el salto y el imán del oro.
> - **Gota de tinta:** +6, o +10 si es grande (masa ≥ 2 o el elemental), y +4 si murió por su debilidad o después de una reacción premiada. Tiene forma de gota, del color del pigmento activo, y al cogerla suena `tinta_sube` y sale «+N tinta».
> - **Recogible de vida:** cura un **12 % de la vida máxima** (12 de 100) al cogerlo; no va a la bolsa. Sale con un **15 %** de probabilidad, o un **25 %** si la vida está por debajo del 34 %: nunca está garantizado y cura lo mismo. Es rosa-rojo, suena `pocion_fin` y sale «+N vida».
> - Los dos **desaparecen a los 8 s** y parpadean los 2 últimos. No salen de muñecos (`premia_tinta` false), ni de enemigos ahogados, ni de los que tengan `suelta_recogibles = false`. Interruptores globales: `GOTAS_TINTA` y `RECOGIBLES_VIDA`.
> - Prueba: `herramientas/escenario_recogibles.gd`, 0 fallos. Las de botín, muerte y tinta siguen en 0 fallos.
> - **Fórmula de botín aprobada (Pablo, 22/11; `MEJORAS_HECHIZOS_MYSTRALIA_2026-11-22.md` §11), primera implementación hecha (§11.7):**
>   - **Curva continua de vida** (`Combate3D.prob_vida`): `h = (vida + curación pendiente) / vida_max`, `p = 0,15·lim((1−h)/0,2) + 0,10·lim((0,5−h)/0,3)`. Da 0 % con la vida llena (antes, 15 %), 15 % al 80 %, 18,3 % al 40 % y 25 % al 20 % o menos. La curación pendiente son los recogibles de vida vivos a ≤ 8 casillas.
>   - **Con la barra llena (vida o tinta) ni se imanta ni se coge**: se queda en el suelo hasta caducar. Con hueco entra lo que cabe, el número enseña eso y lo que sobra se apunta como desperdiciado.
>   - **El limo dividido reparte** (`cuota_botin`): sus trozos suman el oro del original (entero, sin perder monedas), una sola gota y una tirada de vida y de materiales repartida. Antes cada trozo soltaba todo entero.
>   - **Registro:** `Combate3D.cuentas` (generado, recogido, recuperado, desperdiciado y caducado, por tipo) y eventos `gota_tinta`, `recogible_vida`, `sin_vida` (con la racha), `coge_tinta`/`coge_vida` y `recogible_perdido`.
>   - **Tablas validadas** (`Botin.validar`): un peso negativo, una probabilidad fuera de 0..1 o una suma 0 hacen que la tabla no se tire (resultado vacío y aviso). Un objeto repetido es un aviso: sus filas cuentan aparte y los pesos suman. Las 25 tablas de hoy son válidas.
>   - El oro, la fórmula de tinta y el reintento no se han tocado.
>   - Prueba: `herramientas/escenario_botin_curva.gd`, 0 fallos. Las de recogibles, botín, limos, muerte, tinta y reintento siguen en 0.
>   - **Decidido (Pablo, 22/11): «déjalo así; en juegos parecidos ya se hace así y es intuitivo».** Con poco hueco se coge lo que cabe y se pierde el resto (12 de vida con 3 de hueco: cura 3 y se pierden 9), sin hueco mínimo.
> - **Pendiente:**
>   - Apagarlo por encuentro desde el mapa: hoy es una variable por enemigo y no hay parámetro de pieza.
>   - Arte propio: ahora son esferas.
>   - Verlo con ventana.
>   - Revisar las cifras con el daño nuevo de la flecha (B9a).
- **Qué:** al morir, el enemigo suelta **gotas de tinta** que se recogen al pasar por encima (imán corto), como el botín. Recomendación de partida: **+6 por goblin, +10 por enemigo grande**, más **+4 si muere por reacción o por debilidad**. Así matar bien rinde más que repetir fuego. Los muñecos (`premia_tinta = false`) no sueltan nada.
- **Por qué gotas y no tinta directa:** obligan a moverse por la sala (C5: quedarse quieta lanzando se castiga) y se leen.
- **Archivos:** `enemigos/combate_3d.gd` (`_morir` :3720), `enemigos/botin_goblin.gd` (el soltar y recoger ya existe para el botín), `nucleo/tinta.gd` (`recuperar`) y un VFX de gota (Pipeline; color del pigmento activo, `Tinta.color()`).
- **Coste:** B–M. **Depende de:** nada. **Ojo:** endurece poco por sí sola; lo que la hace importante es B1 (hay que gastar en tres páginas).
- **Prueba:** `prueba_dano_tinta.gd` con un caso nuevo: matar un goblin con fuego y con su debilidad, recoger y comparar la tinta. Comprobar que el muñeco no suelta nada.

---

## 5. Fase D · Profundidad

### D1 · Daño contra pared (C11)
- **Qué:** un enemigo empujado que choca con un muro, un sólido o una barrera de la jugadora recibe daño **proporcional a la velocidad que le quedaba** (por ejemplo, 10 × v / v_ref, con un tope) y queda aturdido 0,5 s. Lleva su propio feedback: polvo, golpe seco y número de daño. La caída a agua honda ya mata. Conecta con H1b: flecha de tierra → barrera detrás del enemigo y empujarlo contra ella.
- **Archivos:** `enemigos/combate_3d.gd` (`push` :759 y el paso de empuje; hoy el empuje se para contra el muro sin consecuencias), y `enemigos/golem_3d.gd` y `limo_3d.gd` si tienen paso propio.
- **Coste:** M. **Depende de:** nada. **Se enseña** con una sala del tipo `SalaEmpuje`.
- **Prueba:** `herramientas/escenario_sala_empuje.gd`. Un empuje fuerte contra el muro hace daño y uno débil no. `prueba_empuje_masa.gd`: un enemigo pesado recibe menos daño (lleva menos velocidad).

### D2 · Postura y rendimientos decrecientes (C12) — **APARCADO**
> **Pablo, 22/11:** no hace falta una barra de postura por ahora. Si más adelante hace falta, se estudia. Lo que sigue queda como referencia.

- **Qué es la postura, en corto:** además de la vida, el enemigo tiene una barra de **«aguante»**, que no es vida. No baja con cualquier golpe, sino con los golpes bien elegidos: su debilidad, una reacción, el golpe F o estamparlo contra una pared. Cuando se llena, el enemigo **se desmorona**: queda aturdido unos segundos y recibe más daño. Es la ventana para rematar. Ejemplos: Sekiro y los FF VII Remake y XVI. Sirve para que **variar** de golpes rinda más que repetir fuego + flecha.
- **Qué:** una segunda barra pequeña bajo la vida. La llenan los golpes de debilidad, las reacciones, el golpe F y el daño contra pared. Llena → **roto**: aturdido 2 s y recibe ×1,5. Se vacía sola si se deja de presionar. Y el **mismo control seguido dura menos**: congelado, aturdido o enraizado repetido sobre el mismo enemigo dura ×0,6 y luego ×0,3 durante 6 s. Así un elemento no bloquea a nadie.
- **Por qué:** premia **variar** (lo contrario de fuego + flecha para todo) sin endurecer las misiones.
- **Archivos:** `enemigos/combate_3d.gd` (estados :1017, barra :3069-3116), `nucleo/dano.gd` y `presentacion/ui/barra_hud.gd`.
- **Coste:** M. **Depende de:** D1 (suma postura) y B1 (romper un escudo puede llenar la postura). Es lo último de la parte de enemigos normales: **se decide tras jugar A–C** (si con escudos y tinta ya basta, quizá sobra).
- **Prueba:** escenario con un goblin y una serie fija de golpes. La postura sube como se espera, el «roto» llega en N golpes y el tercer congelado dura menos que el primero.

---

## 6. Fase E · Encuentros

### E1 · Oleadas con aviso
- **Qué:** una pieza de mapa `oleada` dentro de una sala cerrada (`vigia` + `cerrojo`, que ya existen). Cuando quedan K enemigos o pasan N s, salen los siguientes. Cada uno se anuncia **1 s antes** con un círculo en el suelo (un color distinto del rojo de ataque, para no confundirlo) y humo. La sala se abre al vaciarse la última oleada. Así cada sala es una **receta escrita como datos** (roles + terreno + oleadas).
- **Archivos:** `escenas/puzle.gd` (pieza nueva junto a `vigia` :290, :318, :370, :464), `enemigos/combate_3d.gd` (`equipar` :529 ya crea enemigos sueltos), `enemigos/aviso_ataque_3d.gd` (variante sin daño y de otro color) y los mapas.
- **Coste:** M. **Depende de:** nada. Encaja con P8 (temporizador) si se quiere una oleada por tiempo.
- **Prueba:** escenario `herramientas/escenario_oleadas.gd`. Se matan los de la primera oleada, salen los de la segunda tras su aviso de 1 s, ninguno aparece encima de la jugadora y el cerrojo se abre al final.

### E2 · Enemigos en los biomas de la demo
- **Qué:** que cada bioma de la demo (bosque, cueva y pantano) tenga su elenco y pida su herramienta:

  | Bioma | Hoy | Propuesta |
  |---|---|---|
  | **Bosque** (Bosque 01 v01 y 02) | Goblins, lobernos, canouros, chamán y elemental | + goblin con escudo de madera (B1) y + goblin con antorcha (B3). El escudo pide **fuego** y los goblins del bosque son débiles al **agua** y resisten el fuego: hay que alternar las dos páginas (fuego para el escudo, agua para el goblin y la antorcha) |
  | **Cueva** | Goblins (7 líneas) | + limo de fuego con costra (B1, pide **agua**) y + gólem (pide **tierra**/hielo para tumbarlo; ya existe en SalaGolem) |
  | **Pantano** | **Nada** (solo la nube de veneno) | Limos de agua que mojan el suelo (B3), mouro zombi (F3) y goblin o mouro con coraza de barro (B1, pide **tierra**). El pantano moja: la reacción sobre mojado (×1,5) se aprende aquí |

- **El kit no se toca** (Pablo, 22/11): qué glifos y sellos hay en cada sitio se diseña al crear los niveles.
- **Archivos:** `mundo/datos_nivel/mapas/Pantano.txt`, `Cueva.txt` y `Bosque_02.txt`, y las escenas (`kit`).
- **Coste:** B (mapas) por bioma, una vez existan B1 y B3. **Depende de:** B1, B3 y F3.
- **Prueba:** un recorrido sin ventana por cada bioma que compruebe que los enemigos montan y que la sala se puede limpiar **con el kit que se tiene en ese punto de la ruta** (C20 #3).

---

## 6b. Fase G · Encuentros vivos (lista de mejoras aprobada por Pablo, 22/11: «Sí, repártelo»)

Va **antes de E1 (oleadas)**: las oleadas se montan sobre el encuentro que se reinicia (G1) y que reparte los turnos de ataque (G2).

> **Estado (22/11): G1 y G2 hechos sin ventana ni commit.**
> - **G1:** `escenas/puzle.gd` (`al_reaparecer`, `VigiaPuzle.reiniciar`, `CerrojoPuzle.reiniciar`, `_cambiar_nodo`; interruptor `Puzle3D.REINTENTAR`), `Combate3D.receta`/`recrear`/`retirar`/`olvidar_pelea`, `DragonJefe3D.reiniciar`.
>   - Se reponen goblins (incluidos el asesino y los de escudo o coraza), limos, gólem, chamán y elemental.
>   - **No se reponen** el mouro, la Santa Compaña ni el gatopedro (no tienen receta): si mueren en un encuentro no resuelto, no vuelven.
>   - Prueba `herramientas/escenario_reintentar.gd` (sala C4 de la Cueva y Sala del Dragón): 0 fallos.
> - **G2:** `enemigos/coordinador_encuentro.gd` (`CoordinadorEncuentro`, `MAX_ATACANTES` = 2). Sin ficha, el enemigo se recoloca (`Combate3D._recolocar`): rodea a la jugadora al borde de su alcance, se pone delante del chamán si hay uno a menos de 7 u, o, si es arquero, se mueve de lado.
>   - Prueba `herramientas/escenario_coordinar.gd`: pico 2 atacando, el que espera se mueve y los tres llegan a atacar. 0 fallos.
> - **Decisiones que he tomado y Pablo puede cambiar:**
>   - El dragón vuelve a presentarse con el rótulo al reintentar.
>   - Los enemigos sueltos, fuera de un encuentro, recuperan la vida y dejan de perseguirla.
>   - ~~Los enemigos repuestos sueltan su botín otra vez~~ → **decidido (Pablo, 22/11: «Sí, como ahora»)**: los repuestos vuelven a soltar oro y gotas.
>   - Siguen abiertas: el dragón que se vuelve a presentar, y el mouro, la Santa Compaña y el gatopedro, que no se reponen.
>   - Los objetos que quedaron en el suelo se quedan.

### G1 · Morir y reintentar (contrato del encuentro)
- **Hoy:** `Jugador3D.reaparecer()` (`jugador/jugador_3d.gd:852`) emite `reaparecio` y **nadie la escucha**. Los enemigos heridos o muertos, las fases del jefe, las puertas del `cerrojo` y los ataques en vuelo se quedan como estaban. Si mueres dentro de una sala cerrada, reapareces fuera y la puerta sigue cerrada.
- **Regla (Pablo):**

  | Qué | Al reintentar |
  |---|---|
  | Cofre permanente, misión completada, atajo abierto | Se conserva (son flags) |
  | Vida y fase de los enemigos del encuentro | Se restauran |
  | Ataques, avisos y efectos transitorios | Se retiran |
  | Recompensa única | No se vuelve a dar |
  | Puzle terminado | Se queda resuelto según su flag |

- **Cómo:**
  - El **vigía** es el encuentro. Al ver por primera vez a sus enemigos, antes de que empiece la pelea, guarda una **receta** de cada uno: modelo, casilla de partida, tipo (goblin, limo, gólem, chamán, elemental), escudo, coraza, debilidad, puesto…
  - Al reaparecer, cada vigía **no resuelto y ya empezado** quita a sus enemigos (vivos, muertos o nacidos después, como los hijos del limo) y los **vuelve a crear desde la receta**. También actualiza las piezas del mapa que apuntaban a ellos.
  - El **cerrojo** no vencido se abre (y se vuelve a cerrar al entrar).
  - El **dragón** vuelve a dormir con la vida llena y los cristales apagados.
  - Se retiran los avisos, las flechas en vuelo y las bolas de veneno.
  - Los enemigos sueltos (fuera de un vigía) dejan de perseguir y recuperan la vida.
- **Archivos:** `escenas/puzle.gd` (vigía, cerrojo y escucha de `reaparecio`), `enemigos/combate_3d.gd` (receta y recrear), `objetos/dragon_jefe_3d.gd` (`reiniciar`).
- **Coste:** M. **Depende de:** nada.
- **Prueba:** `herramientas/escenario_reintentar.gd`. Morir a mitad de un encuentro de la arena y comprobar que vuelve todo como al empezar, y que lo resuelto y las flags se quedan.

### G2 · Coordinar los encuentros
- **Qué:** el encuentro sabe quiénes pelean y reparte **permisos de ataque**: como mucho N ataques peligrosos preparándose a la vez (de partida, 2). El que no tiene permiso no se queda quieto: **rodea** a la jugadora buscando otro ángulo, se pone **junto al chamán** o el arquero **busca línea**. Los permisos rotan.
- **Reaprovecha:** el apoyo del chamán, los turnos de los canouros (1,5 s) y el vigía como inicio y fin del encuentro.
- **Archivos:** clase nueva `enemigos/coordinador_encuentro.gd` y una consulta en `Combate3D._atacar` y `_ia_arquero` («¿puedo cargar?»).
- **Coste:** M. **Depende de:** G1 (el mismo encuentro).
- **Prueba:** dos guerreros y un arquero contra la jugadora. Como mucho 2 cargan a la vez, y el que espera se recoloca (se mueve) en vez de quedarse quieto.

## 6c. Encuentros élite o de reto

Son encuentros **opcionales y difíciles**, que se premian: el camino principal sigue suave (REFERENCIAS §3.5).

### X1 · Pareja élite: el escudero y el tanque (C24, de MAGES O22)
- **Estado:** Pablo lo ha pedido **solo como posible enemigo o élite** (22/11). **Solo anotado, sin implementar.**
- **Qué:**
  - Un **escudero** lejano une a un **tanque** con un hilo de luz. Mientras el hilo esté, el tanque es inmune.
  - El hilo se corta de dos maneras:
    - **golpeando al escudero**, que queda aturdido unos 3–4 s;
    - **poniendo algo sólido en medio**, con la misma regla que el aliento del dragón (`Lanzador3D.solidez_en`, tabla de contacto B2). Así se resuelve con un hechizo, no solo con daño.
  - Si el hilo se corta con una barrera, el escudero la rodea para volver a unirse.
  - Cuando cae uno, el otro se enfurece.
- **Tres soluciones (C4):**
  - pegar al escudero;
  - cortar el hilo con una barrera de tierra;
  - separarlos: empujar al tanque fuera del alcance del hilo, o contra una pared (D1).
- **Qué se reaprovecha:**

  | Pieza | Qué hay | Qué falta |
  |---|---|---|
  | Escudero | Chamán v2 (`enemigos/chaman_3d.gd`): ya escuda, y el ritual se corta si le pegan | Un escudo **sostenido por el hilo** (inmunidad), en vez del escudo de vida que se gasta |
  | Hilo | `presentacion/hilo_luz_3d.gd` (`HiloLuz3D`) | Que lo corte lo sólido, mirado como el aliento del dragón (`largo_aliento_u`) |
  | Tanque | Gólem (inmune de pie) o goblin con coraza (`CorazaElemento3D`, B1) | Nada: el hilo se le pone encima |
  | Aturdir | Estado `aturdido` / `stun_timer` de `Combate3D` | Que cortarle el hilo de un golpe lo aturda 3–4 s |
  | Furia | La furia del elemental (×1,3 velocidad, ×0,7 descanso) | Aplicarla al superviviente |
  | Coordinación | G2: el que espera ya **protege al chamán** (`_recolocar`) | Que el tanque se ponga entre la jugadora y el escudero siempre, no solo cuando espera turno |
  | Reintentar | G1: el vigía repone a los dos | Nada |
  | Presentación | `PresentacionJefe` (rótulo y barra) | Dos barras, si va como mini-jefe |

- **Archivos:** clase nueva `enemigos/escudero_3d.gd` (sobre `Chaman3D`) o un modo del chamán; `enemigos/combate_3d.gd` (inmunidad mientras haya hilo, que se consulta como la coraza en `on_spell_hit`); una pieza de mapa `pareja_elite` en `escenas/puzle.gd`; una sala de reto.
- **Coste:** M. **Depende de:** B1 y B2 (hechos), G1 y G2 (hechos). Con todo eso ya está, es sobre todo montar piezas.
- **Prueba:**
  - con el hilo puesto, ningún hechizo quita vida al tanque;
  - una barrera de tierra entre los dos corta el hilo y el tanque recibe daño;
  - un golpe al escudero corta el hilo y lo aturde;
  - al caer uno, el otro se enfurece;
  - al morir la jugadora, los dos vuelven (G1).

### X2 · El Verraco: élite de ruinas, «que se rompa contra la piedra» (ENEMIGOS_MITOLOGIA §2)
- **Estado (22/11): HECHO con D1 y PROBADO POR PABLO** («el concepto del verraco funciona, faltan animaciones y demás, pero me gusta. Lo he probado y funciona»). Sin commit. **Pendiente: modelo y animaciones (Pipeline).** Pablo aprobó el orden: «Sí, ese orden».
  - **Código:** `enemigos/verraco_3d.gd` (`Verraco3D`, placeholder de primitivas: un jabalí de granito) y pieza de mapa `verraco` (`mira`, `vida`) en `escenas/puzle.gd`, que también lo reinicia al reaparecer.
  - **D1:** `Combate3D._chocar_pared`. Un enemigo empujado a ≥ 2,5 u/s que se para en seco contra lo sólido pierde hasta 15 (según la velocidad) y queda aturdido 0,5 s. Interruptor `Combate3D.CHOQUE_PARED`.
  - **Dónde verlo:** `escenas/PruebaSalaVerraco.tscn` (mapa `SalaVerraco.txt`: sala con una columna en medio y el Verraco al este).
  - **Prueba:** `herramientas/escenario_verraco.gd`, 0 fallos, con lo de la lista de abajo y además:
    - granito;
    - pose quieta con línea y ventana de 0,25 s;
    - la embestida que hiere;
    - voltereta perfecta a 0,2 s sí y a 0,4 s no;
    - reintento;
    - D1 flojo sin daño y fuerte con daño.
  - **Fotos:** `docs/capturas/verraco` (`herramientas/captura_verraco.gd`): quieto, pose con la línea, embistiendo, agrietado contra la pared («25» a la jugadora) y partido con el núcleo.
  - **Ojo, de las fotos:**
    - con la luz azul de la cueva el granito se ve azulado (ya se aclaró una vez);
    - la cámara sigue a la jugadora, así que con 4 casillas de separación se queda al borde de pantalla.
  - **Cómo es la embestida:** recorre hasta donde estaba ella más 2 casillas. Solo choca si hay algo sólido dentro de ese recorrido; si no, se para y vuelve a acechar. El suelo mojado la alarga hasta 4 casillas.
  - **Decisiones mías, para Pablo:**
    - vida 90;
    - núcleo 6 s;
    - daño de la embestida 25;
    - la barrera contra la que se estrella pierde 40;
    - el golpe F no le afecta (no está en el grupo de enemigos).
- (Antes: «Anotado, sin implementar hasta que Pablo apruebe el orden». Recomendado primero: no depende de puzles.)
- **Filosofía (§0, del jefe sombra de Mystralia, O27):** invulnerable por defecto. La ventana se abre manipulando el entorno con lo que ya sabe hacer la jugadora.
- **Qué:**
  - Un jabalí o toro de granito vetón, **invulnerable**: los hechizos rebotan con el golpe sordo de lo ineficaz (C20).
  - Al verla, **embiste en línea recta** hasta chocar. Avisa con la **pose C25** (pezuña y cabeza baja, quieto) y una línea en el suelo (`AvisoAtaque3D.rectangulo`, con la ventana de 0,25 s del cuerpo a cuerpo).
  - **Si choca contra algo sólido** (pared, columna o barrera de tierra), se agrieta y queda aturdido unos 2 s. **Con tres grietas, núcleo** a tiro (el patrón del gólem y del dragón, C16 y C17).
  - **Frena si ve una barrera recién puesta** en su línea: hay que levantarla cuando ya ha arrancado. La barrera de tierra tarda 0,70 s en salir (C18).
- **Tres soluciones (C4):**
  1. barrera de tierra en su camino;
  2. delante de una columna, voltereta perfecta en el último momento;
  3. **suelo mojado** en su carril: patina (`patinar`, que ya existe) y se estrella más lejos de lo que calculaba.
- **Qué se reaprovecha:**
  - gólem: inmune de pie, núcleo y grietas;
  - golpe seco y pose de A5 (C25);
  - tabla de contacto y golpe sordo (B2, C20);
  - `patinar` y estados del suelo;
  - reintento y reparto de ataques (G1, G2).
- **Lo que falta:**
  - **D1, el daño contra pared (C11)**: aquí es su razón de ser. Se hace con el Verraco: el empuje o la embestida que se para contra lo sólido avisa del choque (y le hace daño a quien no es inmune).
  - La embestida como ataque (avance recto a velocidad alta hasta chocar o recorrer N casillas).
  - Que frene ante una barrera nueva.
  - El modelo: un placeholder de primitivas, como el dragón, hasta que haya arte.
- **Archivos:** `enemigos/verraco_3d.gd` (nuevo, sobre `Combate3D` o `Golem3D`), `enemigos/combate_3d.gd` (choque contra lo sólido, D1), una pieza `verraco` en `escenas/puzle.gd` y una sala en la ArenaCombate o en Ruinas.
- **Coste:** M (+ D1, M). **Depende de:** A5, B2, G1 y G2 (hechos) y D1 (por hacer, va con él).
- **Prueba:**
  - los hechizos no le hacen daño;
  - una embestida contra el muro deja 1 grieta y lo aturde;
  - una barrera puesta antes de arrancar lo frena, y una puesta después lo para y lo agrieta;
  - sobre suelo mojado patina y llega más lejos;
  - con 3 grietas, el núcleo recibe daño;
  - la voltereta en los últimos 0,25 s da tiempo bruja.

### X3 · El Basilisco: élite de cueva, «devuélvele la mirada» (ENEMIGOS_MITOLOGIA §1)
- **Estado:** anotado, sin implementar. **Va después de X10** (sesión de puzles, `PLAN_PUZLES_2026-11-22.md`, pasos 3b y 3c, «base de la luz»).
- **Qué:**
  - **Invulnerable** (escamas).
  - Su **mirada es un haz** que barre en línea y se corta en lo sólido, con el cálculo del aliento del dragón y la tabla de contacto. Lo que toca queda **lento**.
  - **Si la mirada da en la protección de agua** de la jugadora, **se refleja** hacia donde ella mira, con la **misma regla y la misma pieza que X10**. Si el reflejo le da a él, se **petrifica** unos 3 s (gris, quieto, vulnerable) y el golpe F lo agrieta (×2, como lo congelado).
  - **Evita la condición:** antes de mirar gira buscando un ángulo sin la protección en medio. La mirada se anuncia con pose y ojos que se encienden (A5).
- **Tres soluciones:**
  1. reflejar la mirada con la protección de agua;
  2. reflejarla con un **prisma** de la sala girado hacia él;
  3. **taparle la vista** con una barrera de tierra y pegarle por detrás mientras rodea el muro.
- **Qué se reaprovecha:** el haz con corte (dragón), la tabla de contacto (B2), el reflejo y el prisma (X10 y 3b), el estado `lento`, la anticipación (A5), el reintento (G1) y la silueta blanca del golpe fuerte (C17).
- **Coordinación con puzles:** el reflejo tiene que ser **una sola pieza** para el rayo de luz del puzle y para la mirada del Basilisco. Pedido a la sesión de puzles (22/11) que la base 3b exponga una función común del tipo «un rayo de `origen` y `dirección` → su recorrido con reflejos y en qué acaba», para que la mirada la use igual.
- **Archivos:** `enemigos/basilisco_3d.gd` (nuevo), una pieza `basilisco` en `escenas/puzle.gd` y una sala en Cuevas, junto a los puzles de luz.
- **Coste:** M (si X10 y 3b están hechos). **Depende de:** X10 y 3b (puzles), B2 y A5 (hechos).
- **Prueba:**
  - los hechizos no le hacen daño;
  - su mirada se corta en una barrera de tierra y deja `lento` a quien toca;
  - con la protección de agua delante, el reflejo le da y se petrifica 3 s;
  - petrificado, el golpe F lo agrieta;
  - un prisma girado hacia él hace lo mismo.

**Orden recomendado de las élites:** X2 Verraco (con D1) → X1 pareja escudero y tanque → X3 Basilisco, cuando la base de la luz de puzles exista.

## 7. Fase F · Jefes

### F1 · Encuadre de jefes (C15)
- **Decidido (Pablo, 22/11): cada jefe tiene su cámara.**
- **Qué (opción b + d):** la línea `; camara` de una sala de jefe lleva un **tamaño propio fijo**, por ejemplo `; camara 1,1..15,6 zoom=10`. Al entrar en la sala, la cámara pasa suave (con el `paso_zoom` que ya existe, ~1 s) a ese tamaño y **no cambia durante el combate**. Es una vista por sala, no un cambio de vista en mitad de la pelea. Las fotos con cámara 10 (`docs/capturas/dragon_jefe/abierta`) enseñan cómo se vería. El carril (d) ya está en la Sala del Dragón.
- **Cámara fija:** el ángulo y el giro no cambian; solo cambia el tamaño, una vez al entrar en la sala.
- **Archivos:** `presentacion/camara_salas.gd` (`leer` :31, que acepte `zoom=`; hoy solo hay `ZOOM_MINIMO_SALA`), `presentacion/prueba_test2.gd` (donde se aplica) y `SalaDragon.txt`.
- **Coste:** B. **Depende de:** la decisión de Pablo.
- **Prueba:** `herramientas/prueba_camara_cuevas.gd` (o una nueva). Entrar en la sala lleva el tamaño a 10 en ≤1 s y salir lo devuelve a 6. Fotos con `captura_dragon_jefe.gd` con la cámara del juego: el dragón de pie tiene que verse entero.

### F2 · Ojáncano (C13)
- **Decidido (Pablo, 22/11): es un jefe posterior.** Llega cuando ya se tiene agua, y apagar la barba es el examen del agua.
- **Qué:** el jefe del bosque con la secuencia del ogro de Mystralia (aprobada como concepto). Se reutiliza:
  - `AvisoAtaque3D` para todos sus golpes (regla C22: cada golpe repite su gesto).
  - El golpe de área y la furia del elemental (`ELEM_*`).
  - El salto del limo.
  - `PresentacionJefe` para el rótulo.
  - El encuadre F1.
  - Los mazazos que queman el suelo (B3).
  - La barba como punto débil (el aturdido del dragón con agua es el mismo patrón).
- **Archivos:** `enemigos/ojancano_3d.gd` (nuevo), `escenas/puzle.gd` (pieza), un mapa de arena y el modelo y los clips (Pipeline: Mixamo, flujo probado el 5/11).
- **Coste:** A. **Depende de:** A2 (el patrón de jefe con aviso), F1 y la decisión del orden (§8).
- **Prueba:** escenario como `escenario_dragon_jefe.gd`. Cada ataque saca su aviso en cada repetición, cada aviso da ≥1,2 s si se quiere bloquear (C18), la barba se apaga con agua y aturde, y se puede ganar con el kit de esa pasada.

### F3 · Mouro zombi que resucita donde cae (C23)
- **Qué:** lo propuesto el 21/11. Deja restos, avisa con un anillo y un brillo morado ~1,8 s y se levanta **en el sitio** mientras la mámoa siga abierta. Los restos usan la tabla de contacto (B2): el **fuego los quema** (ya no vuelve), la **tierra los entierra** y el **agua no hace nada** (se lee como ineficaz). Es el enemigo del **Pantano** (E2).
- **Archivos:** `enemigos/mouro_espectro_3d.gd` (hoy rebrota en la mámoa) y el anillo de aviso (`AvisoAtaque3D` morado o pieza propia).
- **Coste:** M. **Depende de:** B2 (para la tabla de los restos). Sin B2 puede salir solo con el fuego.
- **Prueba:** escenario con la mámoa abierta. Matar al mouro deja restos, el aviso dura 1,8 s, se levanta en el mismo sitio, el fuego sobre los restos lo impide y tapar la mámoa corta el bucle.

---

## 8. Piezas de combate que piden los puzles (P1–P9)

| Puzle | Pieza de combate que necesita | Dónde está en este plan |
|---|---|---|
| **P1 · X5** Plataforma bajo el dragón | Que la barrera proteja del chorro de la trampa dragón **según su elemento** (la de fuego no, C19) | B2 (falta además la plataforma móvil P6, que no es de combate) |
| **P7 · X7** Brasero tras el chorro | El chorro de la trampa dragón apagable ~2,5 s y un hechizo que cruza el chorro (fuego que pasa por fuego, C19) | B2; temporizador P8 |
| **P9 · X8** Tres braseros y las plataformas | **Un chorro que empuja** (de agua) y una barrera que aguanta el empuje | B2 (fila «agua» de la tabla + empuje) y D1 (el empuje ya existe en `Jugador3D.push`) |
| **P4 · X6** La mecha suspendida | Ninguna (plataforma, permanencia y muro) | — |
| P2, P3, P5, P6, P8 | No son de combate. P8 (temporizador) lo pueden usar las oleadas por tiempo (E1) | — |

**Regla C20 #3 para todos:** cada puzle se comprueba contra el kit que se tiene en ese punto de la ruta. Si P1 pide protegerse del fuego y en esa pasada solo hay fuego, no se puede resolver.

---

## 9. Orden recomendado y resumen

| # | Punto | Coste | Depende de | Responde a «fácil / fuego vale para todo» |
|---|---|---|---|---|
| 1 | A1 Aviso en la carga del guerrero y del arquero | B | — | Base de justicia antes de endurecer |
| 2 | A3 Golpe del elemental | B | — | Justicia |
| 3 | A4 No cobrar por nada | B–M | — | Justicia (y que la tierra salga) |
| 4 | A2 Dragón con `AvisoAtaque3D` | B | — | Justicia en el jefe |
| 5 | **B1 Escudos de elemento** | M + arte | A4 (la coraza) | **Directo**: obliga a cambiar de página |
| 6 | **B2 Tabla de contacto C19** | M | A4 | **Directo**: la barrera depende del elemento |
| 7 | B3 Enemigos que escriben suelo | B–M | — | El suelo entra en el combate |
| 8 | C1 Tinta al matar | B–M | — | Ritmo; pesa con B1 |
| 9 | E2 Enemigos en los biomas (Pantano primero) | B por bioma | B1, B3, F3 | Que la demo los pida |
| 10 | F1 Encuadre de jefes | B | decisión | Jefes jugables |
| 11 | D1 Daño contra pared | M | — | Profundidad |
| 12 | E1 Oleadas con aviso | M | — | Encuentros más ricos |
| 13 | F3 Mouro zombi | M | B2 | Pantano |
| — | ~~D2 Postura y rendimientos~~ | M | D1, B1 | **Aparcado** (Pablo, 22/11) |
| 15 | F2 Ojáncano | A | A2, F1, orden | El examen del bosque |

**Playtest de control** después del punto 8: jugar el Bosque 02 con el kit de la demo y ver si fuego + flecha sigue valiendo para todo. Se miden los lanzamientos por página con M1 si se reactiva.

---

## 10. Preguntas para Pablo

> **Respondidas el 22/11** (tabla «Decisiones de Pablo» al principio). Están todas decididas.
>
> **11 (de A4), decidida (Pablo, 22/11):** «círculo de tierra alrededor, capa fina; así hay una debilidad en los ataques del suelo o explosiones». **Hecho:** anillo fino de tierra que brota alrededor de su casilla y se hunde al acabar la protección (~7 s). Cuenta como una barrera (tope de 3). Para solo proyectiles (flechas, chorros del dragón y de las trampas); los golpes desde el suelo, el cuerpo a cuerpo y las explosiones lo atraviesan, porque esos ataques no consultan la solidez. Código: `magia/hechizo_vivo.gd` (`_anillo_tierra`). Prueba: `prueba_cobro_sin_efecto.gd`, 0 fallos.

1. **C10 · Burbuja:** ¿aguanta las flechas normales y solo revienta con elemento, o revienta siempre (hoy)? Con la tabla C19 es una fila más.
2. **C13 · Ojáncano:** si es el primer jefe y aún no hay agua, ¿cómo se apaga la barba? (a) No se apaga en la primera pasada; (b) es el jefe del Bosque **a la vuelta**, ya con agua; (c) se apaga con algo del escenario.
3. **C15 · Encuadre de jefes:** ¿vale un **tamaño de cámara propio por sala de jefe** (b, sin cambiar ángulo ni giro, fijo durante el combate), o cuenta como cambio de vista y vamos a jefes bajos (a)?
4. **A1 · Carga del guerrero:** con el aviso completo, ¿se mantiene la espera de 0,6 s (más fácil de leer, ~1,2 s de aviso) o se acorta a ~0,3 s (~0,9 s de aviso, más presión)?
5. **B1 · Escudos:** ¿te valen los tres (madera → fuego, costra de brasa → agua, coraza de barro → tierra)? ¿La coraza la lleva un goblin o un mouro? ¿Se permiten los casos **contraproducentes** que se ven (el fuego cura la costra del limo) o solo ineficaces? (C20 #5)
6. **C1 · Tinta al matar:** ¿gotas que hay que recoger (recomendado) o tinta directa? ¿Te valen +6 / +10 / +4 por reacción como punto de partida?
7. **D2 · Postura:** ¿entra en la demo o se decide tras jugar los escudos y la tinta?
8. **E2 · Kit de la partida nueva:** ¿«Nueva partida» pasa al kit «demo» (fuego, agua y tierra)? Si no, los escudos se esquivan con hielo o rayo.
9. **C7 / C8 · Arquero:** ¿línea de apuntado que se aclara (C7) con el aviso de A1? ¿Flecha más rápida con el mismo aviso (C8)? C8 quita tiempo de reacción y choca con bloquear la flecha con barrera (C18).
10. **A2 · Aviso del dragón:** ¿rectángulo del carril (B, exacto en la sala-carril) o abanico nuevo (M)? ¿Se quedan los anillos como adorno?
