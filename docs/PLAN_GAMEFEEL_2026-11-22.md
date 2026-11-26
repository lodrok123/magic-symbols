# Plan de gamefeel (22/11/2026)

22/11/2026 · sesión **gamefeel** · plan para que Pablo decida.

> **Estado (22/11, después de la primera respuesta de Pablo):**
> - **Nada de mando por ahora**: primero, builds jugables. **2.9 (imán) y 2.10 (vibración) quedan aparcados.** La pregunta 6 está contestada.
> - Pablo pidió implementar **lo que sale del playtest de Mages of Mystralia**:
>   - **2.3 / C22, elemental:** hecho por la sesión de **combate** (su A3 en `PLAN_COMBATE_2026-11-22.md`; `ELEM_MOMENTO_GOLPE` 0,28 y la recuperación a velocidad normal). La pregunta 8 queda resuelta así: el ataque no se alarga.
>   - **C17, cuerpo grande (O9), ampliado al gólem:** nueva `Sensacion3D.temblor_cuerpo_grande` (`presentacion/sensacion_3d.gd`), con `TEMBLOR_CUERPO_GRANDE` = 0,3. Es el mismo valor que el mazazo «suave» del gólem que pidió Pablo el 29/10. El gólem tiembla al caer tumbado en el hielo y al levantarse (`enemigos/golem_3d.gd`). El elemental tiembla con su puñetazo contra el suelo (`_golpe_elemental` en `combate_3d.gd`; se añadió cuando la sesión de combate acabó con el archivo).
>   - **Prueba:** `herramientas/escenario_cuerpo_grande.gd` da 0 fallos (gólem y elemental). También `prueba_ataques_avisados` y `prueba_elemental_v2`. Siguen dando 0 fallos `prueba_sensacion` 1–4, `escenario_sala_golem` y `prueba_golem_combate`. **No se ha visto con ventana.**
> - **2.2 · Buffer del golpe F: HECHO (22/11, reparto aprobado por Pablo).** Detalle en §2.2.
> - **2.1 · Cancelar el lanzamiento con la voltereta: NO hecha.** Espera las preguntas 1 y 2. La base para hacerla ya está: `fase_accion()`.
> - **G7 · Feedback de la jugadora al recibir un golpe: HECHO (22/11, aprobado por Pablo).** Detalle en §2.11.
> - El resto (reaparición, G4, temblor direccional y libro) **sigue esperando la decisión.**

Sale de `CATALOGO_EXISTENTE_2026-11-22.md` (§0, §1 y §4), de las propuestas G1–G6, C17 y C22 de `PROPUESTAS_SESION_MYSTRALIA_2026-11-21.md` y de `REFERENCIAS_JUEGOS_2026-11-21.md` §1 (atrasado). Las cifras dudosas se han vuelto a mirar en el código hoy; donde el catálogo se queda corto, se dice.

**Lo esencial:** el gamefeel de impacto está casi entero. Lo que falta es sobre todo **respuesta al mando** (cancelar y guardar pulsaciones), **legibilidad** y **que el libro se sienta vivo**. Hay un hallazgo que cambia el orden: **el juego no tiene ningún botón de mando configurado** (`project.godot`: 0 eventos de mando). La vibración y el imán de apuntado dependen de eso.

---

## 1. Lo que ya está: solo hay que comprobarlo jugando

Nada de esto se ha visto con ventana en esta sesión. Son cosas programadas que hay que **sentir** antes de tocarlas.

| Qué | Dónde se ve | Qué mirar | Ajuste |
|---|---|---|---|
| Buffer de páginas y de voltereta (0,15 s) | `PruebaBosque02.tscn`, contra los goblins | Pulsar 1/2/3 o Ctrl justo al acabar la voltereta o el golpe F: ¿sale siempre? | `Lanzador3D.BUFFER_PULSACION` (`magia/lanzador_3d.gd:198`) |
| Voltereta perfecta (tiempo bruja) | `PruebaSalaGolem.tscn`, rodar al final del aviso del mazazo | ¿Se nota la ventana de 0,6 s? ¿Mareo del tinte violeta? | `AvisoAtaque3D.VENTANA_ESQUIVA` (`enemigos/aviso_ataque_3d.gd:21`) |
| Hitstop, destello y temblor por golpe y por potencia (E1) | `PruebaBosque02.tscn` | ¿El golpe fuerte se distingue del flojo? ¿Demasiada pausa con muchos enemigos? | `presentacion/sensacion_3d.gd:71-72`, `enemigos/combate_3d.gd:65-76` |
| Sobrecarga (mantener 0,8 s) | Cualquier mapa, mantener una página | ¿Se oye el clic y se ve el anillo a tiempo? | `lanzador_3d.gd:59-65` |
| Golpe recibido escalado y vida baja (E3) | `PruebaBosque02.tscn`, dejarse pegar | ¿Se distingue un golpe de 12 de uno de 45? ¿El latido cansa? | `sensacion_3d.gd:55-68`, `:129-131` |
| Cámara lenta del último enemigo | `PruebaBosque02.tscn`, limpiar un grupo | ¿0,45 s a ×0,3 es premio o corte? | `sensacion_3d.gd:104-108` |
| Muerte por elemento | Matar goblins con fuego, agua y tierra | ¿Se lee cada una? | `combate_3d.gd:54-61` |
| C17 · cuerpo grande (temblor largo y silueta blanca) | `PruebaSalaDragon.tscn` (ponerse a 2 casillas) | ¿El temblor al caer y levantarse se siente pesado sin marear? | `objetos/dragon_jefe_3d.gd` (static var del principio) |
| Barras con retardo y números de daño | Cualquier combate | ¿La franja fantasma se ve? | `presentacion/ui/barra_hud.gd:26-36` |

**Propuesta:** una sola partida de 15–20 minutos con estas filas apuntadas, y que Pablo marque «bien / tocar / quitar». Las del panel F3 se pueden afinar en directo.

---

## 2. Lo que falta, por orden (impacto y coste)

**Coste:** B bajo (constantes o una función), M medio (una pieza nueva o varios archivos), A alto. El orden pone primero lo que más se nota con menos riesgo.

| # | Qué | Id | Impacto | Coste |
|---|---|---|---|---|
| 1 | La voltereta cancela el final del lanzamiento | G1 | Alto | B |
| 2 | Buffer del golpe F | G1 | Medio | B |
| 3 | Arreglar el desfase del golpe del elemental | C22 | Alto (golpe «injusto») | B |
| 4 | Reaparición en menos de 2 s | REF §1.5 | Medio | B |
| 5 | Los avisos enemigos, por encima de nuestros efectos | G4 | Alto | B–M |
| 6 | Temblor direccional | REF §1.3 | Medio | B–M |
| 7 | Posproceso al abrir el libro | REF §1.6 | Medio | M |
| 8 | El libro reacciona en combate | G6 | Medio-alto (identidad) | M |
| 9 | Imán de apuntado | REF §1.1 | Bajo con ratón, alto con mando | M |
| 10 | Vibración de mando | G5 | Nulo hoy (no hay mando) | B, pero **bloqueado** |

### 2.1 · La voltereta cancela el final del lanzamiento (G1)

- **Hoy:** `_lanzando` bloquea la voltereta (`jugador/jugador_3d.gd:1256`). `_lanzando` dura lo que el clip de lanzar (`_t_lanzar`, de 0,4 a 4 s; `:378`, `:388`), **también después de que el hechizo ya ha salido**. La jugadora se queda clavada en la pose mientras el enemigo ya ataca.
- **Propuesta:** dejar rodar en cuanto el hechizo **ya ha salido** (`Lanzador3D.conjurando` pasa a false justo antes de `_disparar`, `magia/lanzador_3d.gd:1563-1568`). Al rodar: `_t_lanzar = 0`, `_lanzando = false` y `pj.soltar_lanzar()`, lo mismo que hace `:905-907` al acabar el clip.
- **Antes de que salga** (runa, voluta, forma en la mano) **no** se cancela: así no se pierde un hechizo pagado. Ver pregunta 1.
- **Haz sostenido** (el haz retiene el gesto lo que dure, `:378`): ver pregunta 2.
- **Archivos:** `jugador/jugador_3d.gd` (`_gestionar_acciones`, variable `ocupado` de `:1256`). Constante nueva: `CANCELA_LANZAR_CON_VOLTERETA: bool = true` para poder apagarlo.
- **Prueba:** escenario nuevo `herramientas/escenario_gamefeel_cancelar.gd` sobre `escenario_base.gd`. Lanza una flecha con `lanzar()`, espera a que salga, pulsa Ctrl con `_tecla()` y afirma que la voltereta empieza en el fotograma siguiente y que el proyectil sigue vivo. Segundo caso: Ctrl durante la runa → no rueda, pero queda guardado (buffer) y rueda al salir el hechizo.

### 2.2 · Buffer del golpe F (G1)

- **Hoy:** F se pierde si no se puede golpear en ese instante (`jugador_3d.gd:1272-1275`). La voltereta y las páginas sí guardan la pulsación.
- **Propuesta:** el mismo patrón que la voltereta (`:1258-1270`): `_pegar_guardado = Lanzador3D.BUFFER_PULSACION` si `puede_golpear_cuerpo()` es false, se descuenta en tiempo real y se dispara en cuanto se pueda. Apunta `pulsacion_guardada` con `accion: golpe` en el diario.
- **Ojo:** con la recarga de 0,8 s (`jugador/golpe_cuerpo.gd:16-17`) no conviene guardar la pulsación si falta más de 0,15 s de recarga. Si no, aporrear F encadena golpes sin querer.
- **Prueba:** en el mismo escenario: F pulsada 0,1 s antes de acabar la voltereta → golpe al acabar. F pulsada con 0,5 s de recarga → no sale.
- **HECHO (22/11)** en `jugador/jugador_3d.gd`:
  - **Buffer:** `_pegar_guardado` usa la misma ventana que la voltereta (`Lanzador3D.BUFFER_PULSACION`, 0,15 s reales). Solo se guarda si `golpe_guardable()` lo permite: viva, en suelo, sin nadar ni carga y con la recarga del golpe a ≤ 0,15 s. Aporrear F durante un golpe no encadena golpes. Al salir, el diario apunta `pulsacion_guardada` con `accion: golpe`.
  - **Prioridad entre acciones:** **la voltereta gana.** Con una voltereta guardada, el golpe espera. Si la voltereta sale, el golpe guardado se borra (`_iniciar_voltereta`) y no sale después. Las páginas tienen su propio buffer en `Lanzador3D` y no cambian.
  - **Fases:** `fase_accion()` devuelve la acción y su fase. Golpe F: preparación hasta el impacto, ejecución durante 0,05 s (`T_EJECUCION_GOLPE`) y recuperación el resto. Lanzar: preparación mientras `Lanzador3D.conjurando` (el hechizo aún no ha salido) y recuperación el resto del clip. Voltereta: toda es ejecución. Apuntar: preparación. **Es lo que usará la 2.1:** cancelar con la voltereta solo cuando lanzar esté en «recuperacion».
  - **Prueba:** `herramientas/escenario_buffer_golpe.gd` da 0 fallos. Cubre seis casos: F al final de la voltereta, F que caduca, aporrear F, recarga a punto de acabar, prioridad Ctrl+F y las fases de golpe, voltereta y lanzar con conjuro. También dan 0 fallos `prueba_sensacion` (su caso 3d: Ctrl durante un golpe sigue rodando al acabar), `prueba_sensacion_2` y `escenario_cuerpo_grande`. **Sin ventana.**
  - **Aviso honesto:** en el caso 1, la voltereta acabó durante los 3 fotogramas de la pulsación, así que el golpe salió en ese mismo momento (0,00 s). Se comprueba que golpea al acabar de rodar, pero no se llega a ver el golpe «esperando» en el buffer. Eso sí se ve en los casos 2, 4 y 5.

### 2.3 · Desfase del golpe del elemental (C22)

- **Comprobado hoy:** `ELEM_MOMENTO_GOLPE = 0.6` «SIN medir» (`enemigos/combate_3d.gd:156`). Se usa en `_iniciar_ataque(1.0, ELEM_MOMENTO_GOLPE, _golpe_elemental)` (`:2087`). Las fotos del 21/11 dan el contacto hacia **0,28** del clip (~0,85 de ~3,05 s). El daño llega ~1 s después de verse el golpe.
- **Propuesta (ya aprobada para el plan):** `ELEM_MOMENTO_GOLPE = 0.28` y `vel_anim = 0.6` en esa llamada. Cuenta: 3,05 / 0,6 × 0,28 ≈ **1,42 s** de aviso, el mismo que el gólem. Cumple C18 (≥ 1,2 s para bloquear con cualquier elemento). `_iniciar_ataque` ya alarga el clip si el aviso bajara de `AvisoAtaque3D.T_MIN` (`:2220`), así que no hay riesgo de aviso demasiado corto.
- **Efecto secundario:** con la animación al 0,6, el ataque entero dura más (~5 s en vez de ~3). Mirar si el descanso (`ELEM_DESCANSO` 1,2) sobra.
- **Prueba:** volver a pasar `herramientas/captura_anticipacion_enemigos.gd` (con ventana) y comparar con `docs/capturas/anticipacion_enemigos`: el fotograma con los puños en el suelo tiene que coincidir con el final del aviso.
- **Fuera de este apartado, pero relacionado (C22 en el catálogo):** el guerrero y el arquero cargan sin aviso y el dragón no usa `AvisoAtaque3D`. Es combate: lo apunto para su plan.

### 2.4 · Reaparición en menos de 2 s

- **Comprobado hoy:** `presentacion/ui/pantalla_muerte.gd:17-21`: fundido 0,6 + mantiene 1,5 + negro 0,45 = **2,55 s** hasta reaparecer, más 0,5 s de salida. Sin pantalla (laboratorios), `Jugador3D.TIEMPO_REAPARECER` = 2,2 (`jugador_3d.gd:61`).
- **Propuesta:** fundido 0,35 + mantiene 0,8 + negro 0,3 = **1,45 s**, y salida 0,4. Bajar también `TIEMPO_REAPARECER` a 1,5 para que coincidan. La invulnerabilidad al volver (1,2 s, `:863`) se queda.
- **Prueba:** escenario que mata a la jugadora (vida a 0 por código) y mide el tiempo hasta el evento `reaparece` del diario. Afirma < 2 s.

### 2.5 · Los avisos enemigos, por encima de nuestros efectos (G4)

- **Hallazgo de hoy:** el aviso dibuja con `render_priority = 2` (`enemigos/aviso_ataque_3d.gd:135`). Varios efectos nuestros dibujan **por encima**: FuegoToy, el fuego oficial (3, `presentacion/vfx/toy/fuego_toy.gd:914`), la carga (3, `carga_toy.gd:51`), los sprites del toy (5, `sprite_toy.gd:69`) y la niebla del canouro (10, `presentacion/niebla_canouro_3d.gd:339`). Una barrera de fuego encima de un círculo de aviso puede taparlo.
- **Propuesta:** una regla de capas escrita en un solo sitio, por ejemplo `const CAPA_AVISO: int = 20` en `AvisoAtaque3D`, y que el aviso use ese valor; nuestros efectos, por debajo. Si el aviso queda oculto bajo humo o fuego espeso, darle un **borde que se dibuje sin prueba de profundidad** (ya tiene `depth_draw_never`).
- **Prueba:** fotos. Lanzar una barrera de fuego y una de agua encima del aviso del gólem en `PruebaSalaGolem.tscn`, antes y después, con la herramienta de captura de anticipación ampliada (no hace falta un lab nuevo).
- **Riesgo:** toca materiales de VFX. La memoria del 2/11 dice que V1–V3 (VFX de hechizos) eran de otro chat. Aquí solo se cambiaría el número de capa del aviso, no los VFX (pregunta 7).

### 2.6 · Temblor direccional

- **Hoy:** `Vfx3D._temblor` mueve `h_offset` / `v_offset` 5 veces al azar en 0,03 s cada una (`presentacion/vfx_3d.gd:2344-2367`; fuerza máxima 0,2, `:62`). No sabe de dónde viene el golpe.
- **Propuesta:** `temblor_dir(intensidad, dir_mundo)`. La dirección del golpe se pasa a pantalla. Primera sacudida **en esa dirección**, luego 2 rebotes que caen rápido (unos 0,12 s en total). Mismo tope de fuerza. Usos: golpe a un enemigo (dirección del hechizo; `Sensacion3D.temblor_golpe`, `:404`) y golpe recibido (dirección del atacante; `Sensacion3D.dano_recibido`, `:495`). El temblor al azar se queda para explosiones y para C17.
- **Cámara fija:** el temblor es pequeño y no cambia el encuadre ni el zoom.
- **Archivos:** `presentacion/sensacion_3d.gd` (reúne el temblor del fotograma y ahora también su dirección) y una función nueva en `vfx_3d.gd` junto a `_temblor`, con las mismas metas (`temblor_base`) para que no se pisen.
- **Prueba:** `herramientas/prueba_sensacion_5.gd`, sin escena: llama a `temblor_dir` con una cámara falsa y afirma que el primer desplazamiento tiene el signo de la dirección y que vuelve al centro. Sentirlo, solo jugando.

### 2.7 · Posproceso al abrir el libro

- **Hoy:** abrir el libro baja el tiempo a ×0,3 (`Lanzador3D.TIEMPO_LIBRO`, `lanzador_3d.gd:47`) y nada más. Se abre y se cierra en `presentacion/ui/spellbook.gd` (`_toggle` :929, `_animar_libro` :943).
- **Propuesta:** con el libro abierto, el mundo se **desatura un poco (~40 %), se oscurece un poco y lleva una viñeta suave de tinta**, con un fundido igual de largo que el del libro. Sin zoom ni cambio de encuadre. Variante barata: el mismo shader de pantalla de `PantallaMuerte` (`pantalla_muerte.gd:26-38`) con otros valores, en una capa por debajo del libro.
- **¿Y al apuntar?** Apuntar también va a ×0,3 (`TIEMPO_LANZAR`). Ver pregunta 4.
- **Coste a vigilar:** un shader de pantalla completa cuesta poco, pero la máquina de pruebas tiene GPU integrada. Medir los FPS con y sin él.
- **Prueba:** fotos con el libro cerrado y abierto en `PruebaBosque02.tscn` (herramienta de captura con ventana) y FPS medidos en las dos.

### 2.8 · El libro reacciona en combate (G6)

- **Hoy:** reacciona el **HUD de páginas**: tiembla en rojo al «no puedes», destella al estar lista y lleva el arco de sobrecarga (`presentacion/ui/page_hud.gd`). El libro grande no se abre con enemigos cerca (`LIBRO_EN_COMBATE` = false, `lanzador_3d.gd:776`). El libro 3D de la elfa sale a la mano al apuntar (`jugador_3d.gd:347`).
- **Propuesta en dos capas** (ver pregunta 5):
  - **a) HUD de páginas (B):** al recibir un golpe, las páginas dan un respingo y salpican una gota de tinta. Con poca tinta, la tinta de la página se ve aguada. Al acertar una debilidad, la página que lanzó brilla un instante.
  - **b) Libro 3D en la mano o en el cinto (M):** la página lista hace un destello del color del elemento en el libro. Con la sobrecarga, el libro vibra. Al recibir un golpe, se agita. Necesita mirar el modelo del libro (`jugador/pj_3d.gd`).
- **Ganchos ya hechos:** `Sensacion3D.dano_recibido`, `recarga_lista` (:1014), `ping_debil` (:432) y la sobrecarga de `lanzador_3d.gd:1348-1370`. No hace falta inventar eventos.
- **Prueba:** contadores de `Sensacion3D.cuenta` en una `prueba_sensacion` y fotos del HUD en un golpe.

### 2.9 · Imán de apuntado

- **Hoy:** `presentacion/apuntado_3d.gd` solo dibuja. Con ratón se apunta con precisión al punto.
- **Propuesta:** al soltar una página de **proyectil** (ᛇ flecha), si hay un enemigo apuntable en un cono pequeño (±8°) y a su alcance, la dirección gira hacia él como mucho esos grados. Nunca con barrera, ᛒ suelo ni haz. Se puede copiar la búsqueda del glifo ᚨ, que ya respeta `apuntable()` (el canouro con niebla no se deja fijar; `magia/hechizo_vivo.gd:2093-2105`).
- **Valor:** con ratón es pequeño y puede molestar (el disparo no va donde pones el cursor). Con mando es casi obligatorio. Ver pregunta 6.
- **Prueba:** escenario con un goblin a 6° de la línea de tiro: con imán le da y sin imán falla.

### 2.10 · Vibración de mando (G5): bloqueada

- **Hoy:** no hay ninguna llamada a `start_joy_vibration` y **tampoco hay acciones de mando** en `project.godot`. Sin mando no hay nada que vibrar.
- **Propuesta para cuando haya mando:** un módulo pequeño, `presentacion/vibracion.gd`, con `Vibracion.pulso(debil, fuerte, segundos)`, que no haga nada sin mando conectado. Lo llaman los mismos ganchos de `Sensacion3D`: golpe dado (corto y seco), golpe recibido (más largo, según el daño), hechizo lanzado (según la potencia), sobrecarga completa (clic) y esquiva perfecta.
- **Lo que de verdad cuesta** es dar soporte de mando: mover y apuntar con el stick, lanzar con gatillos y **dibujar en el libro** con el stick. Eso es un apartado propio (A).

### 2.11 · G7: feedback de la jugadora al recibir un golpe (HECHO, 22/11)

Revisión con fotos en `PROPUESTAS_SESION_MYSTRALIA_2026-11-21.md` §G7. Lo hecho, punto por punto:

1. **Ya no desaparece.** `_sincronizar` deja siempre `pj.visible = true`. La invulnerabilidad se enseña con un **parpadeo de brillo** en la emisión de sus materiales (`COLOR_INVULNERABLE`, `ENERGIA_INVULNERABLE` 0,9, `HZ_PARPADEO` 7). Si la invulnerabilidad llega sin golpe (al reaparecer), el parpadeo arranca solo. En la voltereta y en el tiempo bruja, no. Al acabar, la emisión vuelve a la de antes.
2. **Destello en el cuerpo:** blanco 0,05 s y rojo que se apaga en 0,2 s, más un **aplastamiento** de 0,18 s (`Jugador3D.destello_golpe`). Usa la misma maquinaria que `destello_color`.
3. **Tres tamaños** (`Sensacion3D.tamano_golpe`, por fracción de la vida máxima):

   | | Pequeño (< 15 %) | Medio | Grande (≥ 30 %, y siempre el que mata) |
   |---|---|---|---|
   | Hitstop | 0,05 | 0,08 | 0,15 (vida baja: al menos 0,12) |
   | Número | ×1 | ×1,3 | ×1,7 |
   | Viñeta | 0,30 s | 0,32 s | 0,40 s |
   | Temblor | Según el daño, como antes | Según el daño | El máximo |
   | Tambaleo | Empujón 4,5 y bloqueo 0,35 s | Igual | Empujón 7 y bloqueo 0,5 s |

4. **Viñeta con dirección:** el shader recibe hacia dónde está el golpe en la pantalla. Ese lado se oscurece hasta ×1,7 y el contrario baja (`VINETA_DIR` 0,7).
5. **Quejido de voz:** el hueco está listo (`Sensacion3D.VOZ_GOLPE`, un nombre por tamaño), pero **vacío: el proyecto no tiene grabaciones de voz de la jugadora.** Cuando las haya, basta con poner sus nombres del catálogo de `Sfx`.
6. **Invulnerabilidad 0,4 → 0,6 s.** No llega a 0,8 porque `TrampaDragon3D.TICK_S` es 0,8 y cada haz tiene que entrar. Avisada la sesión de combate.

**También revisado:**
- **Golpe parado por la barrera, la cúpula o el bálsamo:** ahora sale «Bloqueado», con un destello azulado corto en ella y un temblor mínimo (`Sensacion3D.golpe_bloqueado`). El sonido ya lo ponía quien lo para. **La burbuja que revienta con una flecha** no pasa por `recibir_dano`: eso sigue igual (es de C19, combate).
- **Daño ambiental:** además de la viñeta y el número, destella en el cuerpo del color del elemento. Sin hitstop ni empujón, como antes.
- **El golpe que mata:** cuenta como grande.

**Pruebas:**
- Nueva `herramientas/escenario_feedback_jugadora.gd`: 0 fallos.
- Cambiadas **a propósito**, porque exigían el hitstop único de antes: `prueba_feedback_combate` E3.4 y `prueba_sensacion` caso 6. Las dos dan 0 fallos.
- Siguen dando 0 fallos: `prueba_interfaz_u1_u4`, `prueba_sensacion` 2–4, `escenario_buffer_golpe`, `escenario_cuerpo_grande`, `prueba_bloque_b_enemigo` y `prueba_ataques_avisados`.
- `prueba_trampas_pared`: en una primera tanda salieron 4 fallos en F9 (7.12–7.14), también con 0,4. **Repetida después, dos veces, da 0 fallos**, y la sesión de combate tampoco los reproduce. Lo más probable es que esa ejecución cargara scripts a medio editar por otra sesión, que entonces estaba cambiando archivos.

**Fotos:** `docs/capturas/feedback_jugadora/despues/` (antes, en `docs/capturas/feedback_jugadora/hoja_*.png`; después, en `despues/hoja_*.png`, recortes alrededor de ella):
- se ve en todos los fotogramas;
- el golpe la pinta de rojo;
- el parpadeo blanco se ve bien, quizá **demasiado fuerte** en el golpe pequeño (se ajusta con `ENERGIA_INVULNERABLE`);
- la viñeta marca el lado del golpe.

**No se ha jugado.**

### 2.12 · Gota de tinta recogible: el aspecto (HECHO, 24/11)

- **Pedido de Pablo:** integrar la gota del concepto «Gota de tinta · azul arcano · tinta viscosa». **La jugabilidad ya existía** (C1 de combate: el enemigo la suelta al morir, salta, flota, se imanta y da tinta; caduca a los 8 s). Faltaba el aspecto, que era una esfera estirada.
- **3D, no 2D:**
  - la gota gira, salta y vuela hacia ella con la cámara a 60°;
  - la punta curvada es asimétrica y solo se lee al girar si tiene volumen;
  - al imantarse se estira hacia ella, y un sprite plano no lo haría bien.
- **Hecha en código, sin modelo externo:** `presentacion/gota_tinta_3d.gd` (`GotaTinta3D`).
  - **Cuerpo:** un torno sobre una espina que se dobla en la punta, con la gotita que cuelga.
  - **Charco:** irregular, solo con la gota quieta. Ni gira ni flota con ella.
  - **Material:** del color del pigmento activo («Azul Arcano» por defecto, el del concepto), con un remolino más claro, el borde más oscuro, brillo y algo de emisión.
  - **Imán:** la gota apunta hacia ella y se estira según la velocidad.
- **En `enemigos/combate_3d.gd` (Botin3D, avisado a combate):** se tocan tres líneas: montar la gota, llamar a `al_paso` cada fotograma y leer el color del número desde una meta. Valores, imán y contadores no cambian.
- **Pruebas:** `escenario_recogibles`, `escenario_botin_curva` y `prueba_botin_zona` dan 0 fallos.
- **Fotos:** herramienta `herramientas/captura_gota_tinta.gd` → `docs/capturas/gota_tinta/`. Hojas: `hoja_juego` (cámara del juego), `hoja_cerca` (de cerca, misma inclinación) y `hoja_iman` (el estirón).
  - Se parece al concepto.
  - **En la cueva azul de la Sala del Gólem se confunde algo con el suelo.** En el bosque debería destacar; si no, se puede subir la emisión (`emision` del material).
- **Nota técnica:** al crear una clase nueva hay que registrarla con `godot --headless --path E:\magic-symbols --import`. Si no, las pruebas sin ventana no la encuentran.
- **No se ha jugado.**

---

## 3. Orden propuesto de trabajo

1. **Tanda 1 (B, un día):** 2.1 cancelar, 2.2 buffer F, 2.3 elemental y 2.4 reaparición. Con escenario automático y captura del elemental. Luego Pablo juega 10 minutos en `PruebaBosque02.tscn` y `PruebaSalaGolem.tscn`.
2. **Partida de comprobación** de la §1 (puede ir junto con la anterior).
3. **Tanda 2:** 2.5 legibilidad (fotos) y 2.6 temblor direccional.
4. **Tanda 3:** 2.7 posproceso del libro y 2.8 libro que reacciona (capa a).
5. **Más tarde:** 2.9 imán y 2.10 vibración, cuando se decida si habrá mando.

Todo se probaría sin ventana con `E:\magic-symbols\tools\Godot_v4.7.2-stable_win64.exe --headless --fixed-fps 30 --path E:\magic-symbols --script res://herramientas/X.gd`, y con ventana solo las capturas.

---

## 4. Preguntas para Pablo

1. **Cancelar el lanzamiento:** ¿la voltereta corta **solo el final** (el hechizo ya salió) o también **antes de que salga**? Si es antes, ¿se pierde el hechizo y la tinta o se devuelve? Mi propuesta: solo el final.
2. **Haz sostenido:** si rueda mientras sostiene un haz, ¿el haz se corta o no se puede rodar hasta que acabe? Mi propuesta: se corta (rodar es la salida de emergencia).
3. **Reaparición:** ¿vale 1,45 s hasta volver (fundido 0,35 + texto 0,8 + negro 0,3)? ¿O se quita el texto «Has muerto» cuando la muerte es rápida?
4. **Posproceso:** ¿solo con el libro abierto o también al apuntar (las dos van a ×0,3)? ¿Desaturar, oscurecer o las dos cosas?
5. **Libro que reacciona:** ¿solo el HUD de páginas (barato) o también el libro 3D de la elfa?
6. **Mando:** ¿la demo tendrá mando? Si no, la vibración se aparca y el imán se hace muy suave o no se hace. Si sí, el soporte de mando es un apartado nuevo antes de G5.
7. **Legibilidad (G4):** ¿puedo cambiar la capa de dibujo del aviso aunque los VFX de hechizos los lleve otra sesión? Solo tocaría `aviso_ataque_3d.gd`, no los efectos.
8. **Elemental:** con el arreglo, su ataque dura ~5 s en vez de ~3. ¿Bajamos el descanso para que no se vuelva lento?
9. **Orden:** ¿empezamos por la tanda 1 tal cual?
