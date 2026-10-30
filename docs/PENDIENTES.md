# Pendientes abiertos

Foto del 21/10/2026, sacada de los chats de claude.ai y cruzada con el DIARIO (hasta la entrada 236). Repasada el 23/10 con lo hecho el 22 y el 23.
Cada tarea tiene **un dueño**. Al cerrarla, se tacha aquí y se apunta en el DIARIO.
La lista detallada de tareas sigue estando en `PLAN_ARREGLOS.md` y `PLAN_EOW.md`; esto es el índice de lo que está vivo.

## Pablo (decidir o validar)

**Commits y horneado**
- [ ] Commitear las entradas 226–236 del DIARIO (todas «sin commit»).
- [ ] Re-hornear las piezas viejas con la colisión por contorno (DIARIO 228–229).

**Decidir o validar**
- [ ] Clip de GOLPE propio de la jugadora (Meshy): un empujón corto con las dos manos y zancada, o un golpe con el libro o el bastón, ~0,5 s y con empuje. Hoy el golpe F (C1) usa `cast_empuje` recortado, que se lee como un gesto de magia con poco brazo; su rol `attack` apunta a `FacePunchReaction`, un golpe RECIBIDO.
- [ ] Probar la tecla F (golpe cuerpo a cuerpo, C1) en el playtest: alcance de 1 casilla, empuje de ~2,2 casillas, daño 5 y reutilización de 0,8 s son valores de partida.
- [ ] Validar el clip «Drowning» de los dos goblins (DIARIO 231).
- [ ] Aplicar el ajuste de proyecto que pide la entrada 233 (luz por zona / tilt-shift).
- [ ] Números de la tinta (PLAN_EOW E1) y recetas de pigmentos por zona (tinta, paso 2).
- [x] ~~Presupuesto de polígonos~~ — V8 aplicado el 21/10 (`2bc0534`): `arbol_redondo_2` en el Bosque 01 y piezas de 12 k a 6 k; el pino queda.
- [ ] Puente 0,41 u por debajo de las orillas: subirlo o dejarlo.
- [ ] Tronco-puente: aceptar el estirado ×1,31 o reexportar a 3,4 con enredaderas.
- [ ] Integrar el esqueleto en el canouro.
- [ ] Recetas y mejoras del alquimista (DISENO_FUTURO §7, tarea 3.4).
- [ ] Aprobar los diálogos del guardabosques y la librera (tarea 9.12).
- [ ] Describir el «hay dos problemas» del trazo del 16/10 (el mensaje se cortó).

**Grabar**
- [ ] Gestos de ᛁ (dos orientaciones) y de ᛉ.

## Juego

**Pruebas**
- [ ] Colisiones por contorno: `escenario_bosque_01_ramas` pasó de 0 a 4 fallos (no se llega a pie a los marcadores; las telarañas no liberan su casilla). Verificar si la entrada 230 lo resuelve.
- [x] ~~Bajar a 0 los 46 fallos de `pruebas_resultado.txt` del 20/10~~ — **23/10: batería completa en 0 fallos (127 pruebas, `tools/pruebas.cmd`)**. Los últimos: `prueba_colision_contorno` leía la lista de piezas de `ULTIMAS_INSTALADAS.txt` (ahora fija), y la batería no daba `--fixed-fps 30` a las pruebas que lo piden en su cabecera.

**PLAN_EOW, rondas 1–4**
- [x] ~~B1 estado de suelo con un solo dueño~~ · ~~C1 flags con nombre~~ · ~~D1 ocupación por casilla~~ · ~~A2 propagación por contacto~~ · ~~A3 reacciones de enemigo y hundirse~~ · ~~C2 condiciones y/o/no~~ · ~~C3 sala cerrada~~ · ~~A4 `Mundo3D.reaccion`~~ · ~~A5 escudo del goblin~~ · ~~D2 pathfinding~~ — hechas el 21/10, sin commit (diario 238).
- [ ] Lo que dejaron abierto (diario 238; el clip «Drowning» ya está activo, diario 240): `Jugador3D.quemar(s)` si el jugador debe arder; la patrulla y el gatopedro aún no usan rutas; peor caso del A* con altura ≈ 5,4 ms (> 1 ms) — 24/10: bajado a ~0,9 ms de mediana con las mismas rutas; quedan las consultas sin ruta con alturas (p99 de varios ms); pasar los cofres de `bosque_01_3d.gd` a la gramática de C3.
- [x] ~~Decidir: ¿siete reacciones también para el elemental? ¿el escudo ardiendo prende al goblin? ¿se queda `CONTACTO_ENTRE_ENEMIGOS = true`?~~ — decidido y aplicado el 21/10 (diario 239): el elemental basta con fuego (daño) y agua (cura); el escudo quemado le quema la mano y se desintegra; los enemigos no se contagian entre ellos.
- [x] ~~Laboratorio de playtest EoW (`laboratorios/LabPlaytestEoW.tscn`, 7 salas)~~ — hecho el 21/10 (diario 240).
- [x] ~~**El suelo no guarda «mojada» ni «quemada» al jugar**~~ — arreglado el 21/10 (diario 242; queda el agua sobre hierba). (hallazgo del lab, diario 240): los impactos solo pintan `_img_estado` de la maqueta, así que `casilla(x,y).mojada/quemada` de los puzles nunca se cumple fuera del lab (allí lo suple `SALA5_PUENTE_ESTADOS`). Decidir: que el Juego lo escriba al aplicar la acción (`Mundo3D.aplicar` → `EstadosSuelo3D.aplicar`) o esperar a B2.
- [ ] Decidir sobre los ajustes del lab (diario 240), uno por uno: ¿pasan al juego o se quedan como ayuda? `SALA1_LIBERAR_BRASERO_ARQUERO` (una flecha nunca cruza un brasero), `SALA1_CORRIMIENTO_BRASERO` (un goblin no llega a tocar el brasero), `SALA1_QUEMA_GOBLIN_S` (la quemadura de 3 s se apaga antes del seto), `SALA4_OLFATO` (el goblin tras una pared no se entera; se rinde a > 10 u), letra de hielo inicial en el mapa (`SALA2_HELAR_FRANJA`), tierra de 1 nivel que no frena a un goblin.
- [ ] Al andar, a veces el personaje vuelve al «círculo marrón» del inicio (playtest 21/10). Sin reproducir: falta un vídeo o más detalle de Pablo.

**Otras tareas**
- [ ] 10.4 controles relativos a la cámara (sin marcar en PLAN_ARREGLOS).
- [ ] Asistencia al trazo: los parciales al 60 % siguen por debajo del 80 %.
- [ ] Glifos nuevos de MEJORAS_POTENCIA §6 (perforar, senda, marca…), solo si Pablo los aprueba.
- [x] ~~**Pulso resonante, fase 2** (`PLAN_PULSO_RESONANTE.md` §12.2)~~ — hecha el 23/10: glifo ᚱ «pulso» (id `raido`) y ᚷ → «crecer», momento de ejecución (inicio / continuo / final) como mecanismo de la receta v2, prisma, pared hueca de salida, cofre legendario con su secuencia, Cueva iluminada en azul. Capturas en `docs/capturas/pulso_fase2/`.
- [x] ~~**Materiales de la Cueva: datos, alga y basalto con condición, colmillo de goblin y avisos por calidad**~~ — hecho el 23/10 (`docs/MATERIALES_CUEVA.md`, «Hecho el 23/10»; prueba `herramientas/prueba_materiales_cueva.gd`, capturas en `docs/capturas/materiales_cueva/`).
- [x] **Tercera tanda colocada en la Cueva** (24/10): `pilar_cascada`/`pilar_cascada_ancho`, `labio_cascada`, `rocas_salpicadura`, `musgo_colgante` y `helechos_cueva` en la cascada de C2 (`Puzle3D._levantar_terraza`); `brasero_cueva` en C1 (`modelo=cueva`, `Reactivo3D.cambiar_visual`); `geoda_resonante` (C3) y `estalagmita_resonante` ×3 (C4) como `decorado` (pieza nueva de Puzle3D); `alga_cueva`, `basalto_suelto`, `esquirla_cristal` (sube del cristal al dar la esquirla, `MineralPulso`) y `jarron_roto` (restos del jarrón). Fotos: `docs/capturas/cueva_piezas/`.
- [x] **Estalagmitas resonantes de C4** (24/10, hecho): `EstalagmitaPulso3D` / pieza `estalagmita`. 1.er pulso (por su casilla o la veta de al lado) vibra 0,5 s; el 2.º la tira (a `cae=` o, por defecto, alejándose de la veta) y aturde 3 s y daña 25 a los `Combate3D` de la casilla donde cae (a la jugadora no); queda `estalagmita_rota`, escombro bajo que no bloquea; `flag` recuerda la caída. Ni en pie ni rota bloquean casilla (las flechas se paran en lo sólido y en C4 estorbaban).
- [x] ~~**Geoda resonante de C3, solo de ADORNO.**~~ — 26/10: ya es la geoda EXPLOSIVA que tumba la columna-puente (diario 260). La pared hueca de C3 que la guardaba no se hace.
- [x] **Franja clara de la cascada de C2 quitada** (24/10): la cortina se funde por arriba (`fundido_arriba`, uniform de `AguaRender3D` solo para la Cueva) mientras el delantal de la lámina de la cornisa se apaga hacia abajo (cruce, no suma). Queda, como mucho, una línea de 1 px.
- [ ] **Materiales de la Cueva, lo que queda:** (24/10: `seta_resonante`, `mineral_veta`, `esquirla_cristal`, el cofre épico de las estatuas de C1 y el jarrón ya están hechos) la pared hueca de C3 con la geoda, la mejora concreta del personaje que da cada épico (vida, tinta, pigmentos, ropa), la llave en la bolsa, y arte 3D propio de alga, basalto suelto y cristal resonante.
- [ ] **El colmillo de goblin va directo a la bolsa** (con aviso y texto flotante), no cae al suelo. Si Pablo lo quiere recogible, hace falta una pieza de botín de objeto (hoy solo las monedas lo son).
- [x] ~~**`escenario_cueva_pulso.gd` falla 2-3 comprobaciones ajenas a los materiales** (23/10, al acabar este trabajo): las constantes del brillo azul (`BrilloPulso3D`: reposo, luz y destello) y el material liso del interior del cofre legendario. Lo tocan los agentes de la luz y los cofres; revisar cuando terminen.~~ — comprobado el 26/10: `FALLOS: 0`.
- [ ] **Pulso resonante, lo que queda:** (la fase 3 está hecha el 24/10; el 26/10 la columna ya hace de PUENTE sobre la lava de C3, diario 260) los otros 1–2 prismas de C5/C6, las estalagmitas que vibran de C4, (26/10: el sonido propio del pulso ya existe, `pulso_resonante.wav`, primera versión por afinar de oído) y que en C5 la descarga amarilla de la fuente tapa el frente del pulso por el agua.
- [ ] **Pipeline: clip «abrir cofre» de la jugadora** (PLAN_PULSO_RESONANTE §10 punto 6). No existe: la secuencia del cofre legendario usa `pick_up` (coger un objeto) y, desde el primer plano cenital, se lee como un bulto agachado. Cuando llegue el clip, cambiar `SecuenciaCofreLegendario3D.ROL_ANIMACION`.
- [x] ~~**Pablo / Pipeline: la tapa del cofre legendario abierto** se ve flotando separada del cuerpo (captura `docs/capturas/pulso_fase2/cofre_9_despues.png`; su interior se ve con reflejos morados). Es del modelo/`Cofre3D` (fase 1), no de la secuencia: revisar la bisagra de `cofre_legendario`.~~ — comprobado el 26/10 con `captura_cofre_abrir.gd`: la tapa abierta queda pegada al fondo del cofre, sin gap.
- [ ] **Pablo: grabar las muestras de perforar ᚦ, retorno ᛃ y buscar ᚨ** (`G` en el libro, ids `perforar`, `retorno`, `buscar`; el retardo ya las tenía) — H5, 30/10, diario 291. Hasta entonces se prueban por contadores y por la paleta F1 (`prueba_glifos_dibujables` los avisa, no falla). Y **decidir cuándo se ganan en el juego** (hoy solo los dan `todo` y `pruebas`) y si cuentan para el daño (hoy sí, por defecto), la tinta (a 0) y qué hace el 2.º ᛃ (nada).
- [ ] **Pipeline: PNG de ᛃ jera** (retorno; `Sigils.GLYPHS["retorno"]`, hoy el libro lo pinta con el trazo a mano) y, si procede, una lámina de la chuleta con más de 9 casillas de glifo (el kit «pruebas» ya tiene 10 con dibujo y la 10.ª no se pinta) — H5, diario 291.
- [ ] **Pablo: grabar las muestras de ᚱ y ᛉ** (`G` en el libro, ids `raido` y `permanencia`). 27/10: comprobado con trazos sintéticos que los dos gestos son **compatibles** (`herramientas/prueba_gestos_raido_permanencia.gd`): grabados se reconocen el 74–97 %, casi nunca se leen como otro glifo (0–2 %) y no le roban nada a los demás (0 %); el rival más cercano de los dos es repetición (ᚠ). Antes de grabarlos, un ᚱ o un ᛉ dibujado se acepta como OTRO glifo el 2–39 % de las veces (rebote, flecha, repetición). Cómo grabar: ᚱ en 1 o 2 trazos (palo + panza y pata) con la panza angulosa, ᛉ con el palo entero en 2 trazos; varias muestras de cada estilo que se vaya a usar (el ᚱ de 3 trazos sin grabar baja al 43–64 %). Al grabarlas, repetir la prueba con las muestras reales. Sin ellas los glifos se pueden poner con la paleta (F1) pero no se reconoce dibujándolo; con ellas, la escritura del cofre podría dibujarse trazo a trazo (hoy es un barrido de arriba abajo).
- [x] ~~**Coste en tinta del pulso continuo:** el recargo `COSTE_CONTINUO_V2` (+25 %) solo ve las propiedades de la receta (barrera o permanencia); un ᚱ con elemento sólido (tierra, hielo) sin barrera también late, pero sin recargo. Para cubrirlo, `Receta3D.coste_v2` tendría que conocer el elemento.~~ — H4 (29/10): `Dano.es_continuo` lo decide con el Hechizo; el interruptor `Dano.CONTINUO_POR_HECHIZO` está a `false` (el golden no se regenera) hasta que Pablo decida (DANO_Y_TINTA §2).
- [ ] **La pared hueca de la Cueva se parece a cualquier otra pared** (es un `cueva_pared` con un resplandor azul tenue): se entiende por las vetas que llevan hasta ella, el eco y el aviso al coger el glifo. Si en el playtest no se entiende, darle un detalle propio (grieta, runa).
- [x] ~~**Brillo azul de la Cueva**~~ — hecho el 24/10: el ambiente de las seis salas es azul (`LuzZona3D` `cueva` y variantes `cueva_*`), medido en `docs/capturas/cueva_completa/`. Si se quiere aún más, manchas azules sueltas en el suelo (no hechas).
- [x] ~~El laboratorio de recetas (`lab_recetas_3d.gd`) enseña los ids de los glifos tal cual (ᚷ sale como «pulso» y ᚱ como «raido»): pasarlos por `Sigils.nombre_visible`.~~ — ya lo hace (líneas 515 y 605 de `lab_recetas_3d.gd`); comprobado en H7 (29/10, diario 284), y el libro nombra también con `nombre_visible` el glifo recién escrito.

## Pipeline

- [x] `elfo_base` (22/10, Tripo, 65 huesos): idle cabizbajo prestado de `chibi_elf`. — resuelto 22/10: Pablo pasó el elfo con clips propios (idle, walk, hablar, greet_02, cheer); ya no toma nada de la elfa.
- [ ] `elfo_base`: faltan clips de correr (ahora usa walk), cast, golpe, muerte, rodar, leer y nado; los pasará Pablo.
- [ ] `goblin_base` (22/10, Tripo, 65 huesos; idle, walk, hablar, chop, dig): faltan clips de correr (ahora usa walk), golpe recibido, muerte y los que pida cada NPC goblin (cast, saludo...); aún no lo usa ningún NPC. Ver `docs/capturas/goblin_base/`.
- [x] `marimanta`: bastón vertical y apoyado en el suelo bajo la mano — hecho el 23/10 (`d6532ca2`, `PiezaApoyada3D`). Al andar y hablar queda delante del pecho porque el clip lleva la mano ahí; Pablo lo deja así.
- [ ] `marimanta` (23/10, Meshy, 66 huesos): su idle no es encorvado y «pensar» se frota las manos en vez de llevar una a la barbilla; faltan golpe y muerte.
- [ ] Ningún NPC usa todavía `elfo_base`, `goblin_base` ni `marimanta`, y el goblin asesino solo sale con Alt+F11: colocarlos en los niveles.
**Agua y suelo**
- [x] ~~Triángulos vacíos en las esquinas del agua o la orilla~~ — hecho el 22/10 (`2c45783`: vértice en el centro de cada cuadrito).
- [x] ~~`OSCURECER_SUELO`: igualar hierba y suelo (ARTE §10)~~ — hecho el 22/10 con los albedos por familia (`edc7906`): suelo efectivo 0,70 en la hierba y 0,66 en el camino.
- [ ] La tinaja deja de verter cuando el puzle se completa: comprobar.
- [x] ~~Más sensación de movimiento en el río~~ — hecho el 22/10 (`2c45783`: franjas visibles en el agua filtro, AVANCE_FLUJO 2,0). Las caídas no se han visto: el Bosque 01 no tiene ninguna.
- [ ] Agua del cauce hondo lleno: sale menta opaca y no deja ver las losas, con manchas pálidas rectangulares.
- [ ] Guijarros del lecho bajo el filtro: aún queda alguno oscuro en las esquinas (×1,5 desde `2c45783`).

**Hechizos**
- [x] ~~Hielo con la textura del hielo renderizado en 3D~~ — hecho el 22/10 (`283de21`: material de la compuerta de hielo).
- [ ] Comprobar que la bola de fuego crece a la vista (DIARIO 226). La carga en la mano ya no la tapa la esfera lisa del Lanzador (`65507eb`).
- [ ] **Retirar el camino «Campo» y `SpellRecipe` (H1, 29/10, DIARIO 277):** `Receta3D` ya es solo un adaptador contadores + calidad → `Hechizo`, pero `_sincronizar` y los campos antiguos de `SpellRecipe` (`travels`, `spread`, `blocks`, `height`, `copies`, `bounces`, `pulse`, `lifetime`) se quedan porque los lee el camino «Campo» (`_crear_campo`, `es_barrera_cupula`, `_barrido`, `_una_ola`), `prueba_barrera` y `objetos/guardian_barrera_3d.gd`; `_sincronizar` va por `GeometriaV2.evaluar` → `Sigils.aplicar_v2` → `GLIFOS_V2`, así que esas tres cosas viven mientras viva el Campo. Al retirarlo caen también `GLIFOS_V2`, `aplicar_v2`, `GeometriaV2.evaluar`, `prueba_receta_v2`/`prueba_geometria`/`prueba_pulso` (que aún llaman a `aplicar_v2`/`GLIFOS_V2`) y `prueba_hechizo` pierde su paridad de tablas.

**Encargos del plan EoW (diario 238)**
- [x] B2 (21/10): el suelo, el agua y la hierba leen `Mundo3D.textura_estados()` y `_img_estado` se retiró de `prueba_test2.gd`. Lo «pisado» (hierba aplastada) quedó en `_tex_pisado` (R8 propia de la maqueta); el círculo quemado que crece mientras arde es el *avance visual* de `EstadosSuelo3D` (`poner_avance`/`avance`, no es un hecho).
- [x] ~~Enganchar `ReaccionesVfx3D.conectar(mundo, fx)` al montar el nivel~~ — hecho el 21/10 (`92cec87`).
- [x] Burbujas del hundimiento al aviso `impacto(…, "hundido", …)` / reacción `hundido` (1,6 s de efecto frente a 1,0 s de hundimiento). — hecho 22/10: duran lo que el hundimiento real (el clip, 3,2 s; no 1,0), `ReaccionesVfx3D.dura_hundimiento`.
- [x] Escudo del goblin: ajuste visual en el brazo, efectos de `EXCEPCIONES["escudo"]` con el nodo real y escudo mojado visible. — hecho 22/10 (colgado de `LeftForeArm`, EXCEPCIONES probadas con el nodo real, escudo mojado con capa). Ver diario 248.
- [x] Mano quemada (diario 239): clip `mano_quemada` del goblin (+ `"mano_quemada"` en `ArbolAnimPj.ESTADOS_REDUCIDO` y en `Pj3D.SINONIMOS`), disolver por celdas del escudo quemado en vez del encogido provisional, y chispas en la mano con la señal `Escudo3D.mano_quemada`. — hecho 22/10 (clip por código sobre el Idle, disolver por celdas ya existía, chispas en la mano). Ver diario 248.
- [ ] Flecha de agua en arco (diario 239): comprobar que el VFX del líquido sigue la trayectoria nueva (`vfx_estado_3d.gd` calcula su propia caída con `gravedad`).
- [ ] Opcional: llama visible en la flecha ardiendo (meta `ardiendo`), pista «E: abrir» en el cofre, losa propia de puerta de sala.

**Personajes y objetos**
- [ ] Clips de cast a una mano con el libro al pecho (`arte/meshy/PROMPTS_CAST.md`).
- [ ] El libro vuelve al cinto tras el cast; cast más rápido sin quitar fotogramas.
- [ ] Mangas y túnica de la elfa (choque con la túnica de la cadera).
- [ ] Regenerar los objetos del catálogo con los prompts nuevos.
- [ ] Panel del laboratorio con las variables distintas de cero (abajo a la izquierda): comprobar si se hizo.

## Dirección (documentación y orden)

**Documentos**
- [x] ~~Pasar `PLAN_EOW.md` a `PLAN_ARREGLOS.md` como Fase 15~~ — hecho el 21/10 (con una entrada que apunta a la Fase 14, que sigue en `FASE14_PRESENTACION.md`).
- [x] ~~Reescribir para el 3D las secciones de `ARQUITECTURA.md` (Arte, Animación, Vista isométrica) y la cabecera y §3–§8 de `ARTE.md` (ver `DECISIONES_CHATS.md` §2).~~ Hecho el 21/10 (diario 237).
- [x] ~~Reescribir para el 3D las secciones de lógica de `ARQUITECTURA.md`~~ — hecho el 23/10 (`94bb7318`, `06c42fa1`).
- [ ] Resolver la contradicción del radio base: 0,10 frente a 0,25 de `ESPEC_HECHIZO.md`.

**Organización**
- [ ] Fundir los laboratorios sueltos en LabHechizos.
- [ ] Decidir AguaCapa frente a W1' midiendo la GPU.
- [ ] Conectar ConsumoFuego3D.

**Limpieza del repo**
- [x] ~~Meter `tools/godot_local.txt`, `salida*.txt` y `pruebas_resultado.txt` en `.gitignore`.~~ — hecho el 26/10 (`.gitignore` corregido y archivos fuera del índice).
- [x] ~~Quitar el archivo `main)` de la raíz.~~ — ya no existe (26/10).
- [ ] Archivar los `.cmd` de OneDrive.
- [ ] Arreglar la fila mal formada «Shaders del suelo» en `PROPIETARIOS.md` y subir esa versión al Project de claude.ai.

**Rutina**
- [ ] Playtest de 20 minutos.
- [ ] Medición de rendimiento semanal.

## Lote del 21/10 tarde (diario 245)
- [ ] Pablo: mirar las capturas de `docs/capturas/look_v1v2/` y decidir la fuerza del tilt-shift y el gris del fondo.
- [ ] Pablo: las 4 decisiones de `docs/PLAN_RIGGING.md` §7 antes de empezar el rigging común.
- [ ] Afinar de oído los 4 jingles de logros (`Sfx.CATALOGO`, `audio/gen_sfx_logros.py`).
- [x] ~~Enganchar `Logros3D.conectar` y `ReaccionesVfx3D.conectar` en la maqueta (todos los niveles), y un emisor de «nivel_completado»~~ — hecho el 21/10 (`92cec87`). Titán y los niveles sin reglas no tienen fin: llamar a `Mundo3D.avisar_logro("nivel_completado", …)` cuando lo tengan.
- [x] ~~Plan visual V3–V8~~ — hecho el 21/10 (diario 246).
- [x] ~~Pablo: generar en Meshy tierra, hielo y el atlas de viento~~ — recibidos el 21/10 (diario 246).

## Lote del 21/10 noche (diario 246)
- [x] ~~Lotes de tierra y hielo y atlas de viento: instalar y enganchar en los VFX~~ — hecho y aprobado el 21/10 (diario 247).
- [x] ~~Capturas de V3–V7 y decisión de V8~~ — revisado y aprobado por Pablo el 21/10 (diario 247).
- [x] ~~Esquirla, placa rota y hojas de viento~~ — hecho el 21/10 (`5b1d368`): cometa en el proyectil de hielo (`VfxHielo.proyectil_esquirla` para volver), placa rota al perder el hielo una casilla, hojas 0,25–0,5 u. Falta verlo jugando.
- [ ] **Revisar en el próximo playtest (Pablo, 22/10):** agua filtro con algas y rocas (`2f7bc26`, `0d7bad3`: densidad, verde neón de las algas, rocas azuladas, balanceo en movimiento) y goblins empujados y levantándose (`1bb0c1f`: altura del vuelo, 2,7 s fuera de combate, pies que resbalan, arco del arquero).
- [x] ~~Tiras de transición entre suelos (joints) con la lámina pintada~~ (`e6d7e00`, `b3093ba`, `36b575c`) — **lámina v2 validada por Pablo el 22/10**. Queda: labio/falda para el borde del cauce seco (escalón de geometría).
- [x] ~~Rayo = línea + elemento (forma «haz») en los seis elementos; muro solo con barrera~~ (`bc864ec`) — **aprobado por Pablo el 21/10**.
- [x] ~~Viento con el atlas como máscara~~ (`71b754d`) — **validado por Pablo el 21/10**. Esquirla en la flecha, rayo de hielo y tierra legible en `b0e4ffb` — **validados por Pablo el 21/10**.
- [x] Forma de hechizo «rayo» en el camino actual (hecho y aprobado, `bc864ec`) (VfxElemento3D) para que `VfxHielo.rayo` se vea jugando; hoy solo lo dispara el chorro antiguo de recetas. **Regla de Pablo (21/10): el rayo es glifo `linea` (ᛁ) + elemento** (rayo de hielo = línea + hielo, y así con cada elemento; no confundir con el elemento «rayo» ᛊ). Chocaba con `linea` = «muro delante»: **decidido y hecho el 21/10: el muro pasa solo a `barrera`; `linea` + elemento = haz** (forma `haz`; `VfxElemento3D.haz`, `prueba_haz.gd`, ESPEC_HECHIZO §3b). Pablo valida cómo se ve cada rayo (`docs/capturas/haz/`).
- [ ] Pablo: ¿roca a 2,5 k (`aprobacion3d/v8_piezas/`)? ¿`pino_2` con otro color para pasar también el pino?
- [ ] Commitear (su sesión) los cambios ajenos de `Nivel_Bosque_01.tscn` y de `prueba_test2.gd` (colisión por contorno, F7).
- [x] ~~Migrar los usos de `_img_estado` (hierba, agua, Lanzador, reacciones, lab) a `Mundo3D.textura_estados()` para poder retirarlo (cierra B2).~~ Hecho el 21/10.
- [x] ~~Enredadera con el `quemado`/`disolver` común; cofre que aparece con `disolver`~~ — hecho el 22/10 (`c3718a5`).
- [ ] Pablo: ¿suavizar la franja blanca del labio del cauce seco (tras `881fc85`)?
- [ ] Albedos de las piezas: la corrección se inyecta en `Ocluso3D` al arrancar (`Albedos3D.parchear_ocluso`); meterla en `ocluso_3d.gd` cuando su sesión lo suelte. Pablo: ¿más saturación en los acentos (`PIEZAS_SAT`)?

## Lote del 22–23/10
- [ ] **Revisar en el playtest:** rim nuevo de la jugadora; tronco del estanque que bloquea en el fondo seco; escudo del goblin en el brazo, mojado y mano quemada; burbujas al ahogarse; bordes sin cantos; goblin asesino (Alt+F11: ataque doble, dagas, andar agazapado).
- [ ] Goblin asesino: los dedos abiertos asoman junto al mango de las dagas; el walk va ×1,4 sin medir si patina; el segundo corte solo cuenta si el primero falla (invulnerabilidad de 0,7 s).
## Lote del 24/10
- [ ] **Coste de tinta con la base 0,10** (Pablo: «más tarde»): se mide contra la esfera de 0,10 y un muro de 3 casillas o un pilar de 2
  niveles llegan al tope de 100. Propuesta: medir contra una esfera de referencia de 0,15 (muro ≈ 41, pilar ≈ 30). Diario 249.
- [ ] Una columna de TIERRA de 2 niveles no se lanza (`Jugador3D.MAX_NIVELES_SUBIBLES` = 1) y el fuego no se dibuja más alto con ᛏ: decidir.
- [x] ~~Desafío de la barrera del Bosque 01 v01: decidir cómo hacerlo obligatorio~~ — **decidido el 27/10 (Pablo): la mazmorra anterior al Bosque (la Gruta Batida, la de ᛜ) será obligatoria por historia**, así que la barrera llega antes del Bosque y no hace falta forzarla dentro del Bosque 01 v01.
- [ ] Bosque 01 v01: modelo de la boca de la Cueva (hoy una losa) y recorrerlo entero a mano.
- [ ] Recetas (vida, tinta, pigmentos) con su base de datos: para más adelante (Pablo, 24/10).
## Fase 3 del Pulso / Cueva jugable (24/10) — lo que salió al recorrerla de punta a punta

- [x] **La flecha de AGUA enfría la lava** (24/10, hecho): la flecha real se PARA en el borde de la lava (casilla sólida) y deja el agua en la orilla de la simulación (las casillas de lava bloqueadas no admiten agua de hechizo); `Lava3D` mira la simulación cada 0,2 s y se enfría con agua en una casilla suya (≥ 0,008 u) o pegada (≥ 0,02 u), igual que con hielo (`Lava3D.CADA_AGUA`). `escenario_cueva_completa` cruza el río de C3 con la flecha de agua REAL (`_lanzar_real`, con gravedad) y el pulso cruza el puente. Fotos: `docs/capturas/cueva_cascada/c3_*`.
- [x] **La flecha de TIERRA ya no levanta bloque ni pica nada con gravedad real** desde el cambio de la mano real (`Lanzador3D._salida_de_mano`, 24/10). ARREGLADO el mismo día: los proyectiles con gravedad salen como antes (0,9 u sobre los pies, sin apartarse a la mano), lo comprueba `prueba_cast_points` E2b. Sigue en pie: `escenario_cueva_completa` la lanza sin gravedad; probar a mano C2 (enlace y muro) con el arco real.
- [ ] **El bloque de tierra del último golpe tapa el hueco del muro agrietado de C2** (~8 s en el escenario; 25 s como máximo): se espera o se salta.
- [ ] **ᚱ con hielo o tierra sin flecha no soltaba el pulso** (el bloque no se levanta bajo los pies, `casillas` = 0): arreglado (`HechizoVivo._pulso_sin_volumen`), pero el hechizo sigue «sin volumen» en pantalla.
- [ ] **ᚱ se perdía al cambiar de nivel** (cada nivel reaplica su progresión): arreglado para los glifos de cofre con la flag `global.glifo.<id>` y `Puzle3D._restaurar_glifos`. Los glifos que se ganen por otras vías (tienda, `Repertoire.unlock_sigil` a pelo) siguen sin persistir.
- [x] **Cascada de C2** (24/10, hecho): ya no es el puente de ruinas. Tres canales `-` (1..3, 4..5) sobre una TERRAZA de roca (`manantial … terraza=1`, `Terreno3D.elevacion_canal`: el fondo del canal sube 1 u sin usar `fijar_altura`, así que no es presa) contra la pared norte, sin pieza de ruinas (`sin_piedra=si`), lámina ancha (`bloque=`) y un pozo de 6 casillas delante (al sur, lejos del muro sur que tapaba el pozo antiguo). Cae ~2 u y se ve la cortina con vetas, espuma al pie y ondas desde la cámara del juego. Fotos y comparación: `docs/capturas/cueva_cascada/` (`captura_cueva_cascada.gd`). Lo que aún no se parece a la de EoW: una sola cortina de 3 casillas (en el vídeo son varias separadas por pilares de roca con musgo), el borde oscuro del pozo corta la cortina, la lámina de arriba es un shader propio (no el agua de la simulación, que en poco fondo es casi transparente) y la espuma al pie es más tímida; el pozo no es hondo.
- [ ] **Estatuas**: sin sonido propio ni la lección del orden más allá del color de cada estatua; la secuencia es fuego, hielo, fuego de izquierda a derecha.## Cueva Resonante (27/10) — docs/CUEVA_RESONANTE.md
- [x] **Nivel `CuevaResonante`** (mapa editable `mapas/CuevaResonante.txt`, escena `PruebaCuevaResonante.tscn`): la Cueva rehecha con la curva de EoW presentar → desarrollar → combinar; C6 ya no se resuelve sola. Autoplay `escenario_cueva_resonante.gd`: 102 comprobaciones a 0 (a pie, hechizos reales con gravedad, E; sin teletransportes ni pulsos inyectados), con recarga final.
- [x] Bugs de la auditoría: reglas de receptor por flag (la reja de C3 no volvía a abrirse tras volver al nivel), `flag=` en la columna de C2, `cae=` fijo en las estalagmitas, el prisma ya no suma una casilla de alcance, la columna-puente no se agrieta con pulsos, aviso de `Puzle3D` si un hueco está también en `celdas`.
- [ ] **Pablo: playtest de la Cueva Resonante** (27/10: cuando esté todo afinado). Mirar sobre todo la reja del nicho de C1 (¿se ve el brasero?), si se entiende que el receptor de C5 abre la reja del oeste, y los 25 s de la tierra en C6.
- [ ] Pablo: ¿el Bosque 01 v01 lleva ya a la Cueva Resonante? (`boca_salida … a=CuevaResonante:desde_bosque` en `Bosque_01_v01.txt`).
- [ ] Pablo: validar la base de recogibles (`docs/RECOGIBLES_DB.md` §6, `docs/recogibles_propuesta.tsv`).
- [ ] Colocar `boca_cueva` y `llave_pequena` como `decorado` (ya se pueden) tras verlos en una captura con ventana.
- [ ] Bajos sin arreglar: el tono de «llegada» del pulso suena aunque lo tocado no reaccione (`Pulso3D._avisar`); un receptor con `rearme` + `flag` no quita la flag.
## Gruta Batida (27/10) — docs/GRUTA_BATIDA.md
- [x] **Nivel `GrutaBatida`** (mapa `mapas/GrutaBatida.txt`, escena `PruebaGrutaBatida.tscn`, kit `barrera`): el nivel de ᛜ, seis salas que presentan, desarrollan y combinan escudo, peso a distancia, fuego a distancia y puente de hielo; el cofre da ᛉ y su primer uso es el atajo de salida. Autoplay `escenario_gruta_batida.gd`: 84 comprobaciones a 0.
- [x] Motor: `vigia … puesto=si` (arqueros de puesto desde el mapa) y la placa de presencia nota lo que pesa (grupo `peso`: el bloque de tierra).
- [x] ~~Rediseño: mostrar ᛜ sin darlo y darlo al final~~ — **28/10: construida SOLO CON FUEGO** (Pablo: «la barrera como concepto, sin más elementos que el fuego»). Kit `gruta` (fuego + flecha); los **guardianes** (`guardian`, `objetos/guardian_barrera_3d.gd`) levantan la barrera de fuego en sus marcas; el cofre da ᛜ y el atajo pide la de la jugadora junto a un tótem roto. Piezas nuevas `puente` y `puerta modelo=reja`; la llama de una barrera prende las cuerdas. Autoplay 76 comprobaciones a 0; fotos en `docs/capturas/gruta_batida/`. La versión de tres elementos sigue en `GRUTA_PERMANENCIA.md`.
- [ ] **Pablo: ver las fotos y jugar la Gruta** (`docs/GRUTA_BATIDA.md` §5): ¿se entiende sin texto el tótem → hilo → llama tras la reja? ¿el hilo debería verse antes del primer golpe? ¿dos golpes por arquero está bien? ¿el guardabosques del Bosque sigue vendiendo la barrera?
- [ ] La barrera de FUEGO no hace de escudo (medido el 28/10: su solidez dura 2,4 s; las flechas pasan igual). Si se quiere un escudo de fuego, es una regla nueva (p. ej. que queme las flechas que la cruzan).
- [ ] Barreras que no hacen lo esperado (sonda del 27/10): agua + ᛜ no activa un `pulsador modo=agua` ni apaga un muro de fuego `B`.

## Libro y progresión (27/10, decisiones de Pablo)
- [x] **Kit de arranque y huecos de glifo** (informe de dirección §8, puntos 1–2): el PRIMER libro de la historia tiene en su página derecha sitio para **4 elementos y 6 glifos**; es capacidad, no kit: se empieza con menos y se ganan jugando. Los 3 huecos de glifo del círculo (página izquierda) se quedan como están. Más adelante, en un punto de la historia, llega un **libro nuevo** con más sitio (y quizá más elementos: se confirma jugando). Hecho: `Repertoire.max_elementos` / `max_glifos` (0 = sin límite), `Lanzador3D.CAPACIDAD_PRIMER_LIBRO` en las progresiones `nivel1`, `bosque` y `barrera` (`todo` y `pruebas` sin límite; «Añadir todos» de la paleta F1 lo quita); con el libro lleno `unlock_element` / `unlock_sigil` / `conseguir_sigil` devuelven false y avisan una vez por consola; la página derecha pinta como mucho la capacidad y vela las casillas de la lámina que pasan de ella. Prueba: `herramientas/prueba_capacidad_libro.gd`.
- [ ] El libro nuevo (más capacidad): cuándo llega en la historia, su lámina y si trae más elementos. Se decide jugando.
- [ ] «Altura» (⊥) no tiene dibujo en `Sigils.GLYPHS`: la página derecha no lo pinta aunque esté activo (lo vio `prueba_capacidad_libro`).


## Humedad y reloj de estados (27/10; lote 3 del informe de dirección, cambio 1, e idea de DK Bananza)
- [x] **Un solo reloj de estados:** `Mundo3D._process` llama a `EstadosSuelo3D.avanzar`; antes solo lo llamaban las pruebas y nada caducaba. `DURA` de «mojada» = 20 s (lo mismo que `AguaSim3D.SECA_EN`); helada, electricidad, quemada y segada siguen sin caducar (la helada de suelo tiene su reloj en `Lanzador3D`).
- [x] **La humedad se ve como un valor 0–1:** el hecho «mojada» sigue siendo sí/no para las reglas (dos aguas hielan mientras dura), pero la imagen pinta `intensidad_vista`: sube en 0,8 s al mojarse (`SUBE`) y se aclara en los últimos 8 s (`SECADO`).
- [x] **`AguaSim3D.textura_mojado()` existe:** el suelo la pedía desde el 12/10 y no estaba, así que el suelo que moja el agua nunca se veía. Pinta lo que el agua dejó mojado (se seca en 20 s) y una **franja de orilla** húmeda de dos trocitos junto a toda el agua visible (solo aspecto). Cuesta ~1,5 ms (8 veces por segundo; solo recorre la caja con agua).
- Prueba `herramientas/prueba_humedad.gd` (0 fallos); fotos `herramientas/captura_humedad.gd` → `docs/capturas/humedad/` (cueva y bosque).
- [ ] En la Cueva el mojado se lee poco: el tinte del mojado es azulado (`tinte_mojado`) y la luz de la Cueva ya es azul. Si se quiere que se vea, un tinte más oscuro o más brillo especular solo con `estilo = "cueva"`.
- [ ] Sigue aparte la hierba mojada (`Hierba3D.MOJADA_S` 8 s y `_mojada` de la maqueta): el agua sobre hierba no deja «mojada» oficial (cambio 6 del informe).
- [ ] La columna `al_caducar` del cambio 1 no se ha hecho: ningún estado la necesita todavía (el hielo de suelo ya deja la casilla mojada por `ReaccionesSuelo3D.derretir`).

## Agua y Cueva (27/10)
- [x] **Agua electrificada sin cuadros amarillos** (`EmisorRayo3D.CODIGO_AGUA`): vetas finas que saltan a tirones, en coordenadas del mundo (siguen de una casilla a otra), que SUMAN luz y no tapan el frente del pulso; se funden en los lados que dan a agua sin corriente; destello al soltar y se apagan a lo largo de la descarga.
- [x] **Costuras rectas de las cáusticas:** el Voronoi de la red de luz buscaba 3 × 3 celdas y el segundo centro a veces quedaba fuera; ahora 5 × 5 (`LechoRio3D.arista`, `AguaRender3D.celdas`). La fuerza de las cáusticas lee la profundidad bilineal, no por trocito.
- [x] **Franja marrón del borde del mapa:** ya no sale desde la pared de piedra de la Cueva del 23/10 (`pared_foso_cueva`); comprobado en las fotos de hoy.
- [x] **Mojado en la Cueva:** oscurece casi sin color y brilla más (`MOJADO_CUEVA_*` en `prueba_test2.gd`): la franja mojada queda un tercio más oscura que la roca seca.
- [x] **Hierba mojada oficial:** el agua sobre hierba deja «mojada» 8 s (`ReaccionesSuelo3D.HIERBA_MOJADA_S`, lo que la hierba se ve mojada y no prende), sin la tabla de transiciones.
- [x] **Cáusticas sobre lo sumergido** (`LechoRio3D.capa_causticas`): una capa de superposición con la misma red de luz para guijarros, algas y rocas del lecho; sirve para cualquier malla bajo el agua (un goblin que nada, más adelante).
- [x] **Pisadas suaves:** `tools/gen_pasos_suaves.py` (toque grave amortiguado, sin agudos, seis por suelo) y −12 dB en `Sfx3D.CATALOGO`. Falta oírlas jugando y ajustar el volumen de oído.
- [ ] Romper con plantillas y fundir la base de las piezas: propuesta en `docs/PLAN_ROMPIBLES_Y_BASES.md`, con decisiones abiertas.

## Empujar bloques (27/10) — docs/EMPUJAR_BLOQUES.md
- [x] **Pieza `bloque`** (`BloqueEmpujable3D`, `material=piedra|hielo`): bloquea su casilla, pesa (placas), la piedra avanza una casilla por empujón y tiende los huecos de veta (`Pulso3D.enlace_tendido`), el hielo resbala hasta que algo lo para, el viento lo empuja, no se guarda su posición (al recargar vuelve a su casilla). Gramática en la cabecera de `escenas/puzle.gd`.
- [x] **Empujar desde `Jugador3D`** (`_gestionar_empuje`): 0,35 s apretando contra un bloque pegado; `empujando` es true mientras empuja (también atascada) y suena el clip `empujar`.
- [x] **Sala del Empuje** (`SalaEmpuje`, 4 salas: el bloque, el hielo, la veta, la otra orilla) y su autoplay `escenario_sala_empuje.gd` (71 comprobaciones, 0 fallos, sin teletransportes ni bloques movidos por código).
- [x] Un bloque que queda sin salida (el hielo que llega a la pared sin placa) se deshace a los 3 s y reaparece en su casilla: decisión fuera del brief, para que no haya atascos sin remedio.
- [ ] **Oír y ver:** los sonidos son claves existentes (`rodar`, `clavar`, `derrumbe`) y el hielo es un cubo translúcido sin textura; faltan un arrastre de piedra y un deslizar de hielo propios, y una textura de hielo en `arte/suelo_meshy`. Probado solo en headless: falta jugarlo en pantalla para el tacto (¿0,35 s?, ¿0,45 s por casilla?, ¿el bloque de piedra ensanchado se ve bien?).
- [ ] La flecha de viento (y la de fuego) vuela solo 2 casillas (`distancia_max`): el viento a distancia de E4 cabe justo. Decidir si el viento debe llegar más lejos.
- [ ] El bloque no empuja a los enemigos ni se deja empujar por ellos, y la jugadora que pisa hielo resbala junto a él sin interacción: sin diseñar.
- [ ] Los otros niveles no usan bloques todavía (el Bosque sigue con los cubos solo visuales de `prueba_test2._colocar_empujables`).
- [x] **Empujar con peso (28/10, Pablo):** la piedra va a 1,0 u/s con arranque de 0,4 s y frenado de 0,3 s solo al final, y encadena casillas mientras se sigue apretando; la jugadora va acoplada al bloque; el clip `empujar` va lento al cargar y proporcional a la velocidad al empujar; el hielo arranca pesado media casilla y luego resbala a ~0,25 s por casilla. Autoplay: 80 comprobaciones.
- [ ] **Afinar de oído y de vista:** `VEL_EMPUJE`, `T_ARRANQUE`, `T_FRENADO` (BloqueEmpujable3D) y `ZANCADA_EMPUJAR` (Jugador3D, estimada: comprobar con `prueba_rigging_postura` que los pies del clip `empujar` no patinan).
- [ ] **Sonido del arrastre:** no hay un arrastre de piedra grabado; el bucle es `rodar.wav` (sintetizado) a −17 dB (`Sfx3D.AMBIENTES["arrastre"]`). **Polvo a ras de suelo:** no existe un efecto pequeño continuo (`VfxPuzle3D.polvo` es la nube del derrumbe); no se ha inventado ninguno. Falta uno para la base del bloque en marcha.

## Combate: apuntado, objetos y enemigos (27/10) — docs/PROPUESTA_COMBATE.md §7
- [x] ~~La flecha de tierra levantaba un pilar al pararse~~ **hecho 28/10** (Pablo: «solo golpe y empuje»; DIARIO 261): sin ᛉ ni ᛜ solo golpea; con ᛉ o ᛜ deja bloque. La Cueva levanta tierra con tierra + barrera donde se apunta. **Pablo:** en C2 la tierra vive 8 s y el cristal late cada 4 s, así que casi siempre pasa un solo pulso y hay que levantar la tierra dos veces para tumbar la columna (4 de 4 vueltas del escenario). ¿Se deja, se da `golpes=1` a la columna o el cristal late más a menudo?
- [ ] **Pablo: las otras flechas al pararse** (ESPEC §0.3): la de fuego deja 3 s de llamas, la de agua su charco y la de hielo hiela. ¿Igual que la tierra (solo con ᛉ) o se quedan así? Ojo: `escenario_puzles_agua` (Q9.4) cuenta con el charco de la flecha de agua.
- [ ] **Apuntado · ver las fotos** de `docs/capturas/apuntado/antes` y `despues` (28/10): recorrido real con galones, sombra del arco, retículas, casillas fantasma, colores propios, «no se puede» antes de soltar; y la segunda tanda, cursor de retícula y fantasma con textura del elemento (fotos 8 a 10). Elegir la siguiente tanda de ideas de `docs/APUNTADO.md`.
- [ ] **A3 · ver las fotos** de `docs/capturas/prevision_reaccion/` y decir si se leen (tamaño de los rótulos, colores, si sobra el rótulo del suelo bajo un enemigo). Hecho y probado el 28/10 (`PrevisionReaccion3D`, `prueba_prevision_reaccion`, 51 comprobaciones); detalle en `PROPUESTA_COMBATE.md` §7.
- [ ] **Fase 1 · Apuntado:** ~~A1 lanzamiento rápido~~ **hecho 27/10** (mantener 1/2/3, soltar lanza, andar mientras se apunta, `prueba_lanzamiento_rapido`; **`TIEMPO_PAGINA` = 0,7 por afinar en el playtest de Pablo**; el «lanzamiento inteligente» se activa desde la paleta F1, aún sin pantalla de ajustes) · ~~A2 reacción «en seco»~~ **hecho 28/10** (`PrevisionHechizo.prever` / `prever_rapido` en `magia/prevision_hechizo.gd`: enemigos, suelo y piezas con las mismas reglas que el impacto, sin aplicar nada; ~1 ms una flecha; `prueba_prevision_hechizo`, 170 comprobaciones; no cubre eventos del hechizo, pulsos de zona ni combos en cadena: ver `PROPUESTA_COMBATE.md` §7) · ~~A3 previsualizar la reacción~~ **hecho 28/10** (`presentacion/prevision_reaccion_3d.gd`; falta el visto bueno de Pablo a las fotos) · ~~A4 trayectorias~~ **hecho 28/10** (rombo en cada rebote, copias de ᚠ tenues, flecha fantasma y silueta del empujado con «Se hunde»; `prueba_trayectorias`, 22 comprobaciones) · A5 imán (más adelante).
- [ ] **Fase 2 · Combate:** ~~C1 golpe cuerpo a cuerpo~~ **[hecho 28/10: tecla F, 5 de daño, ≥ 2 casillas de empuje, sin tinta, 0,8 s de reutilización; clip provisional (el empuje a dos manos de los cast points, la jugadora no tiene golpe propio: pedido arriba); `prueba_golpe_cuerpo`, 61 comprobaciones]** · C2 +20 de tinta por reacción (una vez por enemigo y tipo) **[hecho 28/10: hundido, electrocutado, congelado, mano quemada y apagado]** · ~~C3 ataques avisados~~ **hecho 28/10** (`AvisoAtaque3D`: guerrero, asesino, elemental, arqueros y limo; misma zona que el daño) · ~~C4 esquiva con premio~~ **hecho 28/10** (`TiempoBruja`: rodar en los últimos 0,25 s del aviso → mundo a 0,3 durante 0,6 s de juego, ella a su paso e invulnerable, puede lanzar rodando). Prueba de las dos: `prueba_ataques_avisados` (37 comprobaciones).
- [ ] **Fase 3 · Enemigos:** ~~E1 limo elemental~~ **hecho 28/10 con las reglas de Pablo** (`Limo3D`: persigue, salta encima 15 / 30 de grande, se tiñe, crece, se cura; pieza `limo`; sala `PruebaSalaLimo.tscn`; `prueba_limo_combate` 41 y `escenario_sala_limo` 14 comprobaciones) · ~~E2 chamán goblin~~ **hecho 28/10 con las reglas de Pablo** (`Chaman3D`: rig con el esqueleto de Marimanta, traza un rombo en el suelo y escuda en verde a sus aliados, luego bolas de veneno de lejos; pieza `chaman`; sala `PruebaSalaChaman.tscn`) · ~~E3 gólem de piedra~~ **hecho 28/10** (`Golem3D`: de pie nada le hace daño; viento sobre hielo lo hace resbalar → tumbado o hundido; golpe avisado y núcleo expuesto ×1,5; pieza `golem`; sala `PruebaSalaGolem.tscn`; `prueba_golem_combate` 91 y `escenario_sala_golem`; queda por decidir lava sin tinta, tamaño de la zona del golpe y ventana del núcleo) · E4 el resto de §4.
- [ ] **Sonidos de los enemigos nuevos (Pablo, 29/10: «para el futuro»):** el chamán (trazo de la runa, clavar, onda del escudo, bola de veneno) usa hoy `escudo_golpe`; el gólem usa `derrumbe` y `escudo_golpe`; el limo y los avisos, los sintetizados del lote 1. Buscar en OpenGameArt CC0 como los del 27/10.
  - [ ] **E1: aspecto del limo hecho por código (prototipo, 27/10):** `enemigos/limo_visual_3d.gd` (`LimoVisual3D`: gelatina translúcida con shader, núcleo que late, cara, burbujas; `cargar(elemento)`, `saltar`, `golpe`, `dividir`, `congelar`), escena F6 `escenas/PruebaLimo.tscn`, fotos `herramientas/captura_limo.gd` (con ventana) en `docs/capturas/limo/`, prueba `herramientas/prueba_limo_visual.gd` (0 fallos). **Variante GRANDE (27/10):** el mismo elemento otra vez hace crecer (0,6 → 1,0 → 1,6; `crecer()`, señal `crecio`); el grande lleva cejas, núcleo mayor y tinte más fuerte; `dividir()` baja un escalón. **Falta:** que Pablo lo apruebe en pantalla; la boca es una «o» (no un arco fruncido); el cubo de hielo tiene el borde inferior algo irregular; sin IA, sin daño ni `Combate3D`, sin sonidos; los hijos de `dividir()` son nodos hermanos sin lógica; no está en ninguna escena de juego; decidir si se sustituye por un modelo de Meshy (`arte/meshy/PROMPTS_ENEMIGOS_COMBATE.md` §1).
- [ ] **Pablo · limo (28/10):** jugar la sala `PruebaSalaLimo.tscn`. Decidir: ¿el golpe que lo tiñe debería hacerle daño? (hoy lo absorbe entero); ¿el limo teñido tiene debilidad (p. ej. agua contra el de fuego)? (hoy ×1 con todo); ¿lleva su elemento en el ataque (quemar, mojar)? ¿se divide con fuego o se hace bloque con hielo (la propuesta original)? Vida 60 y el rayo le quita 55 de una flecha: ¿más vida?
- [ ] **Flechas en arco a 1 casilla (28/10):** la flecha de agua y la de tierra van en arco y, a una casilla, le pasan por ENCIMA a un enemigo bajo como el limo (0,6 u); a dos casillas le dan. La previsión lo dice igual (no pinta nada). Decidir si se baja el arco de cerca o se agranda la ventana vertical del golpe (`HechizoVivo.VENTANA_Y_U`).
- [ ] **Pablo · C3/C4:** ver los avisos y el tiempo bruja en el playtest: el aviso del arquero dura lo que tensa (~3,9 s), ¿demasiado? ¿la ventana de 0,25 s es justa? El hechizo lanzado dentro del tiempo bruja también va lento: ¿debería ir a velocidad normal?
- [ ] **Pablo · gamefeel lote 1 (28/10, `presentacion/sensacion_3d.gd`):** probar y afinar de vista y de oído. Todo son `static var` de `Sensacion3D` (y `Combate3D.HITSTOP` / `HITSTOP_DEBIL` / `ANTICIPA_ESCALA`): retroceso 1,1 u/s (~0,16 u), zoom 2,5 % en 0,12 s, destello de la mano, hitstop 0,04–0,10 s según el daño (la jugadora, el 60 %), viñeta 0,22 s, temblor 0,35 y hitstop 0,05 al recibir daño, pulsación guardada 0,15 s. Los tres sonidos nuevos (`lanzar_salida`, `no_puedes`, `aviso_ataque`, de `audio/gen_sfx_sensacion.py`) son sintetizados: cambiarlos por grabados si no convencen.
- [ ] **Pablo · gamefeel lote 2 (29/10, hecho; `Sensacion3D`, DIARIO 269):** probar y afinar. Arranque del proyectil: sale a 1,7× durante ~0,1 s, frena a ~0,65× y en 0,4 s vuelve a su velocidad habiendo recorrido LO MISMO (alcance y llegada lejana iguales); estirón 1,5 y estela de bolitas. Polvo al ser empujado (goblin y jugadora) y al caer (vuelo del empujón, limo, caída de alto). Esquiva perfecta (29/10, tras el playtest: ventana 0,6 s, sin parpadeo, DIARIO 270): filtro violeta desaturado (por debajo del HUD), copias violetas cada 0,1 s mientras se mueve (hasta 16) y tic cada 0,5 s (toc al acabar); **volver a probarla**. Gólem: polvo y temblor 0,3 en el mazazo. Muerte: temblor 0,22; el último de la sala (16 u alrededor de ella) pone cámara lenta 0,3 durante 0,45 s + 0,25 de vuelta (no si el tiempo ya era del libro o del tiempo bruja). Oro: salta 0,9 u en 0,42 s y se imanta a 2,4 u. Reacciones grandes (vapor, descarga, congelado sobre mojado, hundido, el limo que crece, el núcleo y el resbalón del gólem): rótulo ×1,8, hitstop del mundo 0,12 s, temblor 0,4 y sonido. Filtro y copias vistos con ventana (`herramientas/captura_bruja.gd`). Sonidos nuevos sintetizados: `tiempo_tic`, `reaccion_grande`, `moneda`.
- [ ] **Pablo · gamefeel lote 3 (29/10, hecho; DIARIO 271):** probar y afinar. Respingo del modelo al recibir un golpe (0,16 u en 0,16 s). Flechas en el borde hacia el enemigo que marca un ataque fuera de pantalla (a menos de 16 u). Música de combate sintetizada (`combate_loop`, −17 dB; entra en 1,2 s cuando alguien la persigue, sale en 2,5 s) y remate `sala_limpia` al caer todos: **oírla** y decidir si vale o se cambia por una grabada.
- [ ] **Pablo · gamefeel lote 4 (29/10, hecho; DIARIO 276; propuestas en `docs/PROMPT_RESUMEN_GAMEFEEL.md` §5):** probar y afinar (todo en el panel F3 de `LabHechizos3D`, entradas «S:»). Cuerpo golpeado que suena (carne, piedra, limo; limo que muere), sonido de daño de la jugadora y latido por debajo de 1/3 de vida, voltereta con polvo y roce + su icono de recarga (ahora sí se pinta) + clic al volver (ella y las páginas), cámara que se adelanta 0,7 u hacia donde anda y 1,2 u hacia donde apunta, andar con arranque de 0,07 s y frenada de 0,05 s, proyectil que se nota al parar contra pared/bloque/barrera, aro de carga en la mano con zumbido. Sonidos sintetizados: cambiar por grabados los de carne/daño si no convencen. **Pendiente de la lista (§5):** C10 kill confirm de la tinta, C11 golpe de los sólidos grandes, C12 previsión que late, D13–D16 (sonidos por familia, tensar antes del golpe, muertes por elemento, respingo al escudo), E17–E19 (barras con peso, flechas para el chamán), F21–F22 (medir con PlayLog, presupuesto único de temblor y accesibilidad).
- [ ] **`escenario_playtest_eow` inestable (visto el 29/10, ya en el código del remoto, también con la sensación apagada):** a veces el fuego de los setos mata al arquero de la sala 7 antes de la línea 983 (`arq.receive_damage` sobre un nodo liberado → se cae el motor), y 1.12/1.13 (el goblin ardiendo prende el seto) y 4.13 (la ruta de la X) salen unas veces sí y otras no. Probable origen: las vidas a la mitad (DIARIO 268). Sin tocar: es la prueba de otro.
- [ ] **Fase 4 · Objetos:** O1 rueda de 8 objetos · O2 frascos arrojables (aceite, agua, escarcha, chispa) · O3 señuelo · O4 trampas · O5 síntesis.
- [ ] **Fase 5 · Herramientas permanentes (una por mazmorra):** H1 elegir la primera (propuesta: gancho de raíz) · H2 construirla.
- [ ] **Pablo:**
  - teclas del golpe (F) y de la rueda (Tab);
  - modelos del limo, el chamán y el gólem;
  - iconos de la rueda y, si hace falta, el clip de golpe;
  - sonidos;
  - playtests al final de cada fase;
  - validar RECOGIBLES_DB §6.

## Hechizos · H6 interacción material (29/10, docs/PLAN_SISTEMA_HECHIZOS.md §3 H6; primera entrega: diario 286; segunda: diario 290)
Hecho: los `.tres` ya traían temperatura/humedad/conductividad/densidad; `Materia` (`nucleo/materia.gd`, con `Materia.cumple(m, nombre)`); el contrato `on_spell_hit/spell_reacts(rune, dir, hechizo = null)`; `objetos_3d.gd` y, en la **segunda entrega**, los doce objetos que aún leían etiquetas (`barril`, `cuerda`, `compuerta`, `nexo_rayo`, `bloque_empujable`, `molino`, `muro_agrietado`, `surtidor`, `tronco_puente`, `lava`, `pulsador`, `veta_pulso`), el lanzador (`Lanzador3D.reacciona_a`, `trazar(…, hechizo)`, `empuje_de_golpe(…, hechizo)`, la llama que lleva el viento, la tierra quieta, `BarreraFuego`) y `PrevisionHechizo`. `grep "tags.has(" objetos/ magia/` ya no devuelve nada. Pruebas: `prueba_materia_reactivos_2` (cada objeto con un elemento sin etiquetas que provoca su reacción y otro con las propiedades equivocadas) y `prueba_materia_lanzador`.
- [x] Los doce objetos y el lanzador (viento lleva la llama, `empuje_de_golpe`, tierra quieta → muro, llama de `BarreraFuego`) por `Materia`.
- [x] Los puntos del lanzador que consultaban `spell_reacts` sin `hechizo`: la bola (`_activacion_al_final`, por `tramo["hechizo"]`) y el trazado de `HechizoVivo.camino` ya lo reciben, y `PrevisionHechizo` lo pasa por los mismos caminos. **Queda sin Hechizo a propósito** el camino antiguo `Campo` (`_barrido`, `_activacion_en_haz`, `ZonaV2._golpear`): solo tiene `RuneData` y se retira con él (sus etiquetas y números siguen valiendo por `Materia.de(rune)`).
- [x] `MATERIAL_POR_TIPO` en `objetos_3d.gd` (+ `material()`, `reaccion_material(m)`): DISPONIBLE, nadie lo usa salvo `prueba_materia_reactivos_2`. **Diferencias de diseño** con la lógica por papeles, para Pablo (detalle en el diario 290): el agua, el hielo y el viento hacen algo por material a una pieza sana («crece», «congela», «agita», «moja», «escarcha») y nada por papeles; el rayo «prende» por papeles y por material solo «chamusca» el tronco (al seto vegetal, nada); la tierra «astilla» el tronco por material; el barril apagado reacciona por material a agua, hielo y tierra, y el encendido a viento (aviva) y hielo (apaga), y por papeles no.
- [ ] `nucleo/objetos.gd` `elemento_de` (240-246) y `nucleo/sfx.gd` (319): **NO se migran** (decisión de la 2.ª entrega): nombran el elemento / eligen un sonido, no deciden una reacción. Si algún día un elemento sin etiquetas debe nombrarse solo, sería una función aparte.
- [ ] Reactivos que NO leen etiquetas (deciden por `elemento ==` o por el tipo del golpe: `rompible_3d`, `recolectable_3d`, `colmena_3d`, `nido_3d`, `cristal_pulso_3d`, `prisma_pulso_3d`, `guardian_barrera_3d`, inner class de `combate_3d.gd`): ya pueden recibir el 3.er argumento; migrar cuando se toque su reacción.
- [ ] Los fabricantes de `RuneData` solo-etiquetas (`bosque_3d`, `bosque_01_3d`, `bosque_01_v01_3d`, `puzle.gd`, `emisor_rayo_3d`): siguen valiendo (Materia las traduce); sustituir por el `.tres` o por `Hechizo.construir` si se quiere el número real.
- [ ] `enemigos/combate_3d.gd` `decidir_golpe` (vapor / congelar mojado / arco por temperatura y conductividad) y SUSTITUIR la lógica por papeles por `reaccion_material` (el catálogo `MATERIAL_POR_TIPO` ya existe; faltan por declarar la hierba y los cristales, y decidir con Pablo las diferencias de diseño del diario 290): hoy `Materia.reaccion` solo se usa en pruebas.
