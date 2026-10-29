# Prompt resumen: el gamefeel del juego (29/10/2026)

> Texto autocontenido para pegar a otra IA (o para leerlo Pablo) y repasar todo lo que hay hecho de **sensación de juego**
> (gamefeel) y lo que falta. Fuentes: `docs/DIARIO.md` (entradas 75, 264, 269, 270, 271), `docs/PENDIENTES.md` (lotes 1–3),
> `docs/PROPUESTA_COMBATE.md`, contrastadas con el código: `presentacion/sensacion_3d.gd` (`Sensacion3D`, el sitio único),
> `enemigos/combate_3d.gd` (golpe, hitstop, aplastamiento, barra, botín), `enemigos/aviso_ataque_3d.gd`, `jugador/jugador_3d.gd`,
> `jugador/tiempo_bruja.gd`, `magia/lanzador_3d.gd`, `magia/hechizo_vivo.gd`, `presentacion/vfx_3d.gd` (`temblor`, `golpe_estrella`,
> `golpe_direccional`), `presentacion/vfx_elemento_3d.gd`, `presentacion/ui/page_hud.gd`, `nucleo/sfx.gd` (catálogo),
> `audio/gen_sfx_sensacion.py` y las pruebas `herramientas/prueba_sensacion*.gd`. **Cuando doc y código discrepan, manda el código.**

---

## 1. Para quien lo reciba

Eres el responsable del **gamefeel** de un juego de Godot 4.7 (todo en español): vista isométrica con cámara ortográfica, una
bruja que dibuja runas en un grimorio y lanza hechizos elementales (fuego, agua, tierra, viento, rayo, hielo) que reaccionan
con el mundo y con los enemigos (goblins, limo, chamán, gólem, elemental). Referencias declaradas del proyecto: *Magicka*,
*Witch Hat Atelier*, *Breath of the Wild*; para la sensación, Pablo (el diseñador) ha pedido cosas «tipo Bayonetta» (tiempo
bruja) y de juegos de acción con avisos en el suelo. Tu trabajo: **conocer lo que ya hay (§2), cómo se ajusta y se prueba (§3),
qué está validado y qué no (§4), y proponer mejoras concretas y priorizadas (§5)**, cada una con el número o la regla a tocar
y en qué archivo. Reglas de la casa:

- **La sensación no cambia reglas.** Daño, empuje real, alcance, recarga y tinta son del sistema de combate; `Sensacion3D`
  solo cambia cómo se ve, se oye y se nota. `Sensacion3D.ACTIVA = false` lo apaga todo y el juego sigue igual.
- **Cada número es un `static var`** (en `Sensacion3D` y en `Combate3D`), para cambiarlo en vivo desde un laboratorio o el
  playtest. Se afina de vista y de oído; las pruebas sin ventana solo garantizan que se dispara y que no rompe nada.
- **Los sonidos nuevos son sintetizados** (`audio/gen_sfx_sensacion.py`, Python puro) como primera versión; el criterio del
  proyecto (`nucleo/sfx.gd`) es: lo elemental y lo imposible de grabar, sintetizado; el foley, grabado (Kenney / OpenGameArt CC0).
- **Nada entra en un nivel sin probarse** en una sala de prueba o un laboratorio, y cada lote lleva su `prueba_sensacion_N`.
- Pregunta antes de inventar: si algo no está aquí, dilo y pregunta a Pablo.

---

## 2. Lo que hay hecho (inventario por momento de juego)

### 2.1 Al lanzar un hechizo (`Sensacion3D.disparo`, desde `Lanzador3D._disparar`)
- **Retroceso** de la jugadora contra la dirección: `RETROCESO_V0` 1,1 u/s (decae ×7/s, ~0,16 u). No se aplica a lo que nace
  donde se apunta (la barrera): la prueba de lanzamiento rápido cazó que alejaba 0,06 u la barrera del anillo de alcance.
- **Golpe de zoom** de la cámara: `ZOOM_GOLPE` 2,5 % en `T_ZOOM` 0,12 s, con `size` (ortográfica) o `fov`; un golpe nuevo parte
  siempre del valor original, así que no se acumulan.
- **Destello en la mano** del color del elemento (`Vfx3D.golpe_estrella`, `DESTELLO_MANO` 0,55, 0,08 s).
- **Sonido de salida común** `lanzar_salida` debajo del sonido del elemento. Ya había antes: capa arcana `conjuro_arcano` al
  empezar el conjuro, `<elemento>_carga`, bucle de carga mientras se apunta y `*_impacto` al materializarse.
- **Pulsación guardada** 0,15 s reales (`Lanzador3D.BUFFER_PULSACION`): 1/2/3 pulsada mientras rueda, golpea, encaja un golpe o
  lanza se guarda y entra al poder; Ctrl mientras golpea o lanza rueda al acabar.
- **Ritmo del tiempo**: componer con el libro abierto, mundo a 0,3 (`TIEMPO_LIBRO`); lanzamiento rápido manteniendo 1/2/3,
  mundo a 0,7 (`TIEMPO_PAGINA`, por afinar); apuntar con arrastre, 0,3 (`TIEMPO_LANZAR`). Andando, el clip de la jugadora sigue
  el ritmo del mundo para que los pies no patinen; quieta, va a velocidad normal.
- **Apuntado** (`Apuntado3D`): recorrido con cinta, retícula, cursor propio, fantasmas del hechizo (hasta 8), previsión de daño
  («×1,5», «×0,75», «Piedra») y de reacción («Resbala», «Se hunde», «¡Lava!») antes de soltar (A2/A3).

### 2.2 Al no poder lanzar (`Sensacion3D.no_puedes`)
En cada negativa (ahora no, recarga, altura, tinta, no cabe): golpe seco `no_puedes`, la página tiembla de lado con un aro rojo en
el HUD (`PageHud.temblar`, 0,3 s) y el cursor parpadea en rojo con una X (`T_CURSOR_NO` 0,25). Además suena el `sello_no` de antes.

### 2.3 El proyectil en vuelo (lote 2)
- **Arranque** (`factor_arranque`, lo aplica `HechizoVivo._physics_process` solo en la ida del vuelo real): el paso lleva
  `dt × (1 + 0,7·g(u))` con `g(u) = (1 − u)²(1 + 2u − 15u²)` durante `T_ARRANQUE` 0,4 s: sale a 1,7×, frena a ~0,65× y vuelve a 1.
  La integral de `g` es 0, así que a partir de 0,4 s el recorrido es exactamente el de sin arranque: alcance, arco y previsión intactos.
- **Estirón** ×1,5 en la dirección del vuelo (adelgaza 1/√s: mismo volumen; achatado al frenar) y **estela** de bolitas aditivas
  mientras va rápido (`VfxElemento3D.Proyectil`). De antes: el proyectil nace al 20 % y crece en 0,6 s, cola y chispas que se
  apagan al pararse.

### 2.4 Golpear a un enemigo (`Combate3D`, lotes 1 y 3; parte ya existía)
- **Hitstop proporcional al daño** (`Sensacion3D.hitstop_de`): de `HITSTOP` 0,04 s a `HITSTOP_DEBIL` 0,10 s a 40 de daño
  (`DANO_HITSTOP_MAX`) o con su debilidad; congela a ESE enemigo (IA, animación, empuje). **Compartido**: la jugadora se congela el
  60 % (`Jugador3D.hitstop`).
- **Destello blanco** 0,20 s (`DESTELLO_GOLPE`; el daño continuo usa 0,10 para no parpadear), **aplastamiento**
  `SQUASH_ESCALA` (1,25 · 0,8 · 1,25) que vuelve en 0,15 s con rebote, y desde el lote 3 **respingo** del modelo
  (`RESPINGO` 0,16 u hacia donde va el golpe, un cuarto en ir y el resto en volver con rebote; el elemental, el 60 %). El nodo,
  la colisión y el aviso no se mueven.
- **Temblor de cámara** `TEMBLOR_GOLPE` 0,25 (0,5 si es débil), golpe F 0,12 (`GolpeCuerpo.TEMBLOR`).
- **Números flotantes** con pop (nacen ×1,7 y encogen con rebote), color del elemento, ×1,45 y «!» si es su debilidad; el daño
  continuo (quemadura, veneno, pulsos) se suma en un solo número.
- **Partículas en la dirección del golpe** (`Vfx3D.golpe_direccional`; el golpe F en blanco).
- **Salto visual** con viento y tierra (`SALTO_ALTO` 0,25 u, 0,3 s).
- **Barra de vida** (15/10): invisible con la vida llena, destello blanco 0,14 s al golpe, el trozo perdido espera 0,35 s antes de
  encogerse. Rombo de debilidad siempre visible.
- **Interrupción**: 0,6 s sin atacar tras un golpe con daño (0,3 con otro daño).

### 2.5 Recibir daño la jugadora (`Sensacion3D.dano_recibido`)
Viñeta roja (shader en un CanvasLayer 50, `ALFA_VINETA` 0,5 × fuerza 0,6–1 según el daño, 0,22 s), temblor `TEMBLOR_DANO` 0,35 y
hitstop `HITSTOP_DANO` 0,05 s. Parpadeo de invulnerabilidad 0,7 s (no durante el tiempo bruja). El veneno no empuja ni da invulnerabilidad.

### 2.6 Avisos de ataque y esquiva perfecta (C3/C4, lotes 1 a 3)
- **Aviso** (`AvisoAtaque3D`): zona en el suelo que se llena hasta el instante del impacto; el enemigo se encoge al empezar
  (`ANTICIPA_ESCALA` 1,12 · 0,86 · 1,12) y suena `aviso_ataque`. En los últimos `VENTANA_ESQUIVA` **0,6 s** (era 0,25: en los
  registros de Pablo las volteretas caían a 0,45–0,66 s del golpe y ninguna daba premio) el borde late en blanco.
- **Tiempo bruja** (`TiempoBruja`): rodar en la ventana → mundo a 0,3 durante 0,6 s de juego (2 s reales), ella compensada e
  invulnerable, puede lanzar rodando.
- **Esquiva perfecta vistosa** (`EfectoBruja`): filtro de pantalla desaturado y violeta con viñeta (capa −5, bajo el HUD,
  `FUERZA_BRUJA` 0,8, entra en 0,08 s), copias violetas aditivas de la pose cada 0,1 s mientras se mueva ≥ 0,25 u (hasta 16, viven
  0,5 s, alfa 0,6, sin los planos del suelo), `tiempo_tic` cada 0,5 s reales y un «toc» grave al acabar.
- **Flechas en el borde** (`DirectorSensacion`, lote 3): triángulo del color del aviso a 34 px del borde hacia el enemigo con
  aviso vivo que no sale en pantalla y está a menos de 16 u; crece con el aviso y late en blanco a ×1,5 en la ventana.

### 2.7 Empujes, caídas y golpes al suelo (lote 2)
- **Polvo** (`Sensacion3D.polvo` → `VfxPuzle3D.polvo`, nunca en agua): goblin empujado (al salir y al caer del vuelo), limo al
  aterrizar, jugadora empujada (≥ 2 u/s: el retroceso de lanzar no) y al caer de alto (≥ 4,5 u/s).
- **Mazazo del gólem** (`mazazo`, pedido de Pablo en el playtest): polvo bajo cada puño (0,9 u) y uno mayor en el centro (×1,6),
  temblor 0,3.

### 2.8 Muerte, botín y fin del combate (lotes 2 y 3)
- **Muerte con peso** (`Sensacion3D.muerte`, desde `_morir`): temblor 0,22; si no queda ningún enemigo vivo a 16 u de ella
  (`RADIO_SALA`), **cámara lenta** 0,3 durante 0,45 s reales + 0,25 de vuelta (`CamaraLenta`, solo si `time_scale` era 1 y lo
  suelta si otro lo toca) y zoom 6 %.
- **Oro imantado** (`Combate3D.Botin3D`): sale del cuerpo en arco (0,9 u, 0,42 s, botecito), se imanta a 2,4 u (40 u/s² hasta
  14 u/s) y suena `moneda` al cogerlo.
- **Música de combate** (`DirectorSensacion`): `combate_loop` sintetizado (4 compases a 110 ppm, la menor) entra en 1,2 s a −17 dB
  cuando alguien la persigue a menos de 16 u; si caen todos, remate `sala_limpia` y baja en 2,5 s; si solo dejan de perseguirla,
  acaba sin remate tras 2,5 s. Es la **primera música del juego**. `PlayLog`: `combate_empieza` / `combate_acaba`.

### 2.9 Reacciones grandes (lote 2)
`Sensacion3D.reaccion_grande` (vapor, descarga del rayo sobre mojado, congelado sobre mojado, hundido, el limo que crece, el
núcleo del gólem y su resbalón): rótulo ×1,8 (mismo texto, las pruebas lo buscan), **hitstop del mundo** 0,12 s (todos los
enemigos y ella), temblor 0,4, zoom 4 % en 0,18 s y `reaccion_grande`. De antes: `ReaccionesVfx3D` con vapor, burbujas, chispas y
sus sonidos (`siseo_apagado`, `chapoteo`, `hundido_burbujas`…), y los logros con campanas (`Logros3D`).

### 2.10 Lo que ya existía fuera de los lotes y cuenta como sensación
- `Vfx3D.temblor(intensidad 0..1)` con base recordada (varios golpes seguidos no descentran la cámara); temblores internos de los
  impactos elementales (0,05–0,12).
- Cámara: ortográfica a 40 u del foco, el foco sigue a la jugadora con `lerp(1 − e^(−14·dt))` (`PruebaTest2.SEGUIMIENTO`), sin
  adelanto hacia donde se mueve o apunta. Tilt-shift y diorama (look v1/v2).
- Grimorio: `trazo` de tiza con ±18 % de tono, `sello_ok` / `sello_no` como dos notas, pasar página, abrir y cerrar el libro.
- Pisadas por material a distancia recorrida (no por tiempo; `Sfx3D`, grabadas), río que sube de volumen al acercarse, crepitar
  del fuego grabado; grito de alerta y de muerte de los goblins (`snd_alerta`, `snd_muere`). En `jugador_3d.gd` **no hay ningún otro
  sonido**: ni voltereta, ni salto, ni daño recibido, ni muerte de la jugadora.
- Antirráfaga de 70 ms por sonido (`Sfx.VEDA_MS`) para que 24 manifestaciones del mismo fotograma suenen una vez.
- Hielo que resbala para la jugadora (`HIELO_ACEL` 3, `HIELO_FRENO` 0,9, giro ×0,35), goblins con ritmo ×0,8 y zancada medida
  (no patinan), empujón del goblin con vuelo, caída y levantarse.

---

## 3. Cómo se ajusta y cómo se prueba

- **Un solo sitio:** `presentacion/sensacion_3d.gd`. Cabecera con la lista por lotes; `static var` por efecto; `cuenta` (diccionario
  de cuántas veces se pidió cada cosa) para las pruebas; `ACTIVA` apaga todo. Los números de golpe que ya vivían en `Combate3D`
  (`HITSTOP`, `HITSTOP_DEBIL`, `TEMBLOR_GOLPE`, `SQUASH_*`, `ANTICIPA_ESCALA`, `DESTELLO_GOLPE`) siguen allí.
- **Pruebas sin ventana** (`godot --headless --fixed-fps 30 --script …`): `prueba_sensacion` (35 comprobaciones),
  `prueba_sensacion_2` (48), `prueba_sensacion_3` (25). Regresión completa a 0 salvo los dos fallos de siempre
  (`prueba_mapa_abierto` 8, `escenario_playtest_eow` inestable por las vidas a la mitad).
- **Capturas con ventana** (lo que no se puede ver en headless): `herramientas/captura_bruja.gd` (filtro y copias),
  `captura_flechas.gd`, `captura_golem_combate.gd`.
- **Sonidos:** `python audio/gen_sfx_sensacion.py` regenera los nueve (`lanzar_salida`, `no_puedes`, `aviso_ataque`, `tiempo_tic`,
  `reaccion_grande`, `moneda`, `combate_loop`, `sala_limpia`; semilla fija, los anteriores salen idénticos); volumen e intención
  en `Sfx.CATALOGO`.
- **Registros de playtest** (`user://playtest_logs`, `PlayLog`): sirvieron para medir que las volteretas llegaban tarde (270).
  Es la herramienta para decidir con datos y no de oído.

---

## 4. Estado de validación (29/10)

| cosa | estado |
|---|---|
| Lote 1 (lanzar, no poder, pulsación guardada, golpes) | hecho, commit `39b2429f`; **sin afinar en playtest** (PENDIENTES 235) |
| Lote 2 (arranque, polvo, esquiva, muerte, oro, reacciones) | hecho, commit `24aa0c70`; playtest 270: gólem y limo bien, chamán bien |
| Esquiva perfecta | Pablo «no la he apreciado»; corregida (ventana 0,6, sin parpadeo, copias cada 0,1 s); **volver a probar** |
| Mazazo del gólem | añadido a petición de Pablo (polvo + temblor 0,3); por ver |
| Lote 3 (respingo, flechas, música) | hecho, commit `3e6e4605`; **oír la música** y decidir si se queda o se cambia por grabada |
| Sonidos de los enemigos nuevos (chamán, gólem, limo) | pendiente «para el futuro»: usan `escudo_golpe` / `derrumbe` / los del lote 1 |
| Ralentización del lanzamiento rápido 0,7 | sin decidir (Pablo la afina) |
| Aviso del arquero (~3,9 s) y hechizo lento dentro del tiempo bruja | preguntas abiertas a Pablo (PENDIENTES 234) |

---

## 5. Huecos detectados y propuestas (priorizadas)

Ordenadas por lo que más se nota por lo que cuesta. Cada una con el archivo y el número de partida.

### A. Lo que falta y se nota siempre (lote 4 propuesto)

1. **Sonido del golpe recibido por el enemigo.** `Sfx.CATALOGO` tiene `dano` pero **solo lo toca el golpe F**
   (`GolpeCuerpo.SONIDO_TOCA`): un hechizo que acierta suena por su impacto elemental, no por el cuerpo que recibe. Al morir sí
   suena (`snd_muere` = `goblin_muere` por `Sfx3D`), pero el limo, el chamán y el gólem heredan el grito de goblin. Propuesta: en
   `Combate3D._impacto_visual` un «golpe carne» corto grabado (3–4 variantes, ±10 % de tono) escalado al hitstop, y `snd_muere`
   propio por familia. Es lo primero que un jugador echa de menos sin saber decir qué.
2. **Sonido al recibir daño la jugadora.** `Sensacion3D.dano_recibido` es solo visual. Un «uf» o golpe sordo corto (grabado), más
   grave cuanto mayor el daño, y un latido o filtro de graves cuando la vida baja de un tercio (señal continua de peligro, hoy solo
   la barra lo dice).
3. **Sonido y polvo de la voltereta.** La voltereta es la acción defensiva central y no suena ni levanta polvo (solo la esquiva
   perfecta tiene efecto). `Jugador3D` al empezar `_t_roll`: `polvo` pequeño (0,3 u) y un roce de tela. También la **recarga de la
   voltereta** (4 s, `TIEMPO_VOLTERETA`) no se ve en ningún sitio: un aro o icono que se llena en el HUD, y el mismo `no_puedes`
   suave si se pulsa antes.
4. **Impacto del hechizo contra el mundo y los objetos.** Enemigos y reactivos (brasero, tinaja, barril, bloque, compuerta) no
   comparten capa de sensación: cada `on_spell_hit` hace lo suyo. Propuesta: `Sensacion3D.impacto_mundo(pos, elemento, dano)` que
   dé un temblor pequeño (0,08–0,15 según tamaño del hechizo), `golpe_direccional` y la estrella de impacto siempre que un proyectil
   se pare contra algo sólido (pared, bloque, barrera), aunque no reaccione; hoy un proyectil contra una pared se apaga sin más.
5. **Cámara con adelanto.** El foco va a la jugadora con `lerp` (14/s) sin mirar hacia dónde se mueve ni hacia dónde apunta. Dos
   cosas baratas en `PruebaTest2._process`: adelanto de 0,6–0,9 u en la dirección del movimiento (suave, 3–4/s) y, mientras se
   apunta, correr el foco un 25–35 % hacia el ratón o el punto de la retícula (como *Hades* / *Enter the Gungeon*). Con la cámara
   ortográfica se nota mucho y el zoom de golpe ya existe para encadenarlo.

### B. Movimiento de la jugadora (lo que hace que «andar» se sienta)

6. **Aceleración y frenada cortas fuera del hielo.** Hoy `objetivo = mov × vel` es instantáneo (solo el hielo tiene `move_toward`).
   Un arranque de ~0,08 s y una frenada de ~0,06 s (con `move_toward` sobre `_vel_hielo` también en suelo normal, tasas 25 y 35 u/s²)
   dan peso sin que parezca que resbala. Pequeño **estirón vertical** del modelo al arrancar y aplastamiento al parar (±4 %) con la
   misma lógica que `SQUASH_ESCALA`.
7. **Giro con inclinación.** `pj.mirar(mov, delta)` ya suaviza; añadir una inclinación del torso de 3–5° hacia el giro (o hacia la
   dirección de carrera) vende la velocidad. Polvo pequeño al cambiar de sentido brusco corriendo (> 120°).
8. **Aterrizaje del salto** (`Shift`): hoy solo hay polvo si cae a ≥ 4,5 u/s. Un aplastamiento corto del modelo y un paso más
   fuerte al tocar suelo tras cualquier salto; golpe de zoom muy pequeño (1 %) al caer de alto.

### C. Lanzar y acertar (lo propio del juego)

9. **Anticipación de carga visible.** La mano brilla al soltar, pero mientras se mantiene 1/2/3 no hay crecimiento: un aro rúnico
   que se cierra en la mano con el bucle de carga subiendo de tono (el bucle existe: `fuego_carga_bucle`, solo fuego) y partículas
   que convergen. Y **cada elemento con su bucle de carga** (hoy solo el fuego lo tiene).
10. **Kill confirm distinto por reacción.** Matar con una reacción premiada (hundido, electrocutado, congelado, mano quemada,
    apagado) ya da +20 de tinta: que se vea llegar: un hilo de tinta del enemigo a la barra y un «tic» en la barra de tinta al
    sumar (`PageHud.destello` ya existe para páginas; falta el de tinta).
11. **Hitstop también en lo grande de la barrera y el pulso.** `reaccion_grande` congela el mundo, pero el pulso ᚱ que llega a una
    veta o un muro de tierra que se levanta no tienen golpe: un `golpe_zoom` 2 % y temblor 0,1 al materializarse un sólido grande
    (`x_mano_impacto` ya suena).
12. **Previsión que vibra.** Cuando el fantasma del apuntado cubre a un enemigo débil, el rótulo «×1,5» puede latir una vez y el
    cursor cambiar de forma (hoy solo cambia el color). Enseña a leer debilidades sin texto.

### D. Enemigos (que pegar y que peguen se lea)

13. **Sonidos propios por familia** (ya en PENDIENTES 230): chamán (trazo, clavar, onda, bola), gólem (pasos pesados con temblor 0,05
    por paso, mazazo grave), limo (chapoteo gelatinoso, salto). OpenGameArt CC0 como los del 27/10.
14. **Anticipación más larga en el modelo.** `ANTICIPA_ESCALA` dura lo que el aviso; añadir un «tensar» (el modelo se echa atrás 0,1 u
    y tiembla un poco los últimos 0,15 s antes del golpe) cuesta poco y hace la ventana de 0,6 s más legible que el borde blanco solo.
15. **Muerte por elemento.** Hoy todos mueren igual (tween de escala). Un cuerpo que se congela y se rompe con hielo, que se queda
    carbonizado y se deshace con fuego, que sale volando con viento: tres variantes en `_morir` leídas de la última reacción.
16. **Respingo también al goblin empujado por el golpe F** y en el escudo: cuando el escudo absorbe, hoy el enemigo no se mueve;
    un respingo ×0,4 y chispas en el escudo distinguen «le di al escudo» de «no le di».

### E. Interfaz y señales continuas

17. **Barras con peso.** Vida y tinta de la jugadora (`Jugador3D.Y_BARRAS`): trozo perdido que espera y se encoge (como la barra de los
    goblins del 15/10), temblor de la barra al recibir daño, destello al recuperar tinta por reacción.
18. **Recarga de las páginas** visible como aro que se llena en `PageHud` con un «clic» suave al completarse (hoy `no_puedes` avisa
    de que no está, pero nada avisa de que ya está).
19. **Flechas del borde también para el chamán que traza** (es su aviso, pero no es un `AvisoAtaque3D`), para que se sepa que hay que
    interrumpirlo aunque esté fuera de pantalla.

### F. Método

20. **Panel en vivo de `Sensacion3D`** en el laboratorio (F1 o `LabHechizos3D`): deslizadores para las ~40 `static var`, botón
    «apagar todo», y un modo «comparar» que alterna `ACTIVA` cada 5 s. Sin esto, afinar de vista obliga a reiniciar.
21. **Medir con `PlayLog` lo que se quiere mejorar** antes de tocar números: tiempo entre pulsación y disparo, cuántas negativas por
    minuto (`no_puedes`), cuántas volteretas caen en la ventana (ya se hizo en 270), cuántos golpes a enemigos no se ven en pantalla.
22. **Un solo presupuesto de temblor.** Hay temblores desde `Vfx3D` (internos), `Combate3D`, `GolpeCuerpo`, `Golem3D` y `Sensacion3D`;
    `_temblor` ya evita acumular, pero no hay tope por segundo. Proponer `Sensacion3D.temblor(fuente, intensidad)` con tope y
    prioridad, y una opción de accesibilidad (reducir temblor y filtros de pantalla).

### Orden sugerido para el lote 4
A1 + A2 + A3 (sonido de daño, muerte, jugadora, voltereta) → A5 (cámara con adelanto) → B6 (aceleración) → A4 (impacto contra el
mundo) → C9 (carga visible) → F20 (panel en vivo). Todo son `static var` nuevos en `Sensacion3D`, sin cambiar reglas, con
`prueba_sensacion_4` y capturas con ventana para lo que no se ve en headless.
