# Pendientes abiertos

Foto del 21/10/2026, sacada de los chats de claude.ai y cruzada con el DIARIO (hasta la entrada 236). Repasada el 23/10 con lo hecho el 22 y el 23.
Cada tarea tiene **un dueño**. Al cerrarla, se tacha aquí y se apunta en el DIARIO.
La lista detallada de tareas sigue estando en `PLAN_ARREGLOS.md` y `PLAN_EOW.md`; esto es el índice de lo que está vivo.

## Pablo (decidir o validar)

**Commits y horneado**
- [ ] Commitear las entradas 226–236 del DIARIO (todas «sin commit»).
- [ ] Re-hornear las piezas viejas con la colisión por contorno (DIARIO 228–229).

**Decidir o validar**
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
- [ ] Lo que dejaron abierto (diario 238; el clip «Drowning» ya está activo, diario 240): `Jugador3D.quemar(s)` si el jugador debe arder; la patrulla y el gatopedro aún no usan rutas; peor caso del A* con altura ≈ 5,4 ms (> 1 ms); pasar los cofres de `bosque_01_3d.gd` a la gramática de C3.
- [x] ~~Decidir: ¿siete reacciones también para el elemental? ¿el escudo ardiendo prende al goblin? ¿se queda `CONTACTO_ENTRE_ENEMIGOS = true`?~~ — decidido y aplicado el 21/10 (diario 239): el elemental basta con fuego (daño) y agua (cura); el escudo quemado le quema la mano y se desintegra; los enemigos no se contagian entre ellos.
- [x] ~~Laboratorio de playtest EoW (`laboratorios/LabPlaytestEoW.tscn`, 7 salas)~~ — hecho el 21/10 (diario 240).
- [x] ~~**El suelo no guarda «mojada» ni «quemada» al jugar**~~ — arreglado el 21/10 (diario 242; queda el agua sobre hierba). (hallazgo del lab, diario 240): los impactos solo pintan `_img_estado` de la maqueta, así que `casilla(x,y).mojada/quemada` de los puzles nunca se cumple fuera del lab (allí lo suple `SALA5_PUENTE_ESTADOS`). Decidir: que el Juego lo escriba al aplicar la acción (`Mundo3D.aplicar` → `EstadosSuelo3D.aplicar`) o esperar a B2.
- [ ] Decidir sobre los ajustes del lab (diario 240), uno por uno: ¿pasan al juego o se quedan como ayuda? `SALA1_LIBERAR_BRASERO_ARQUERO` (una flecha nunca cruza un brasero), `SALA1_CORRIMIENTO_BRASERO` (un goblin no llega a tocar el brasero), `SALA1_QUEMA_GOBLIN_S` (la quemadura de 3 s se apaga antes del seto), `SALA4_OLFATO` (el goblin tras una pared no se entera; se rinde a > 10 u), letra de hielo inicial en el mapa (`SALA2_HELAR_FRANJA`), tierra de 1 nivel que no frena a un goblin.
- [ ] Al andar, a veces el personaje vuelve al «círculo marrón» del inicio (playtest 21/10). Sin reproducir: falta un vídeo o más detalle de Pablo.

**Otras tareas**
- [ ] 10.4 controles relativos a la cámara (sin marcar en PLAN_ARREGLOS).
- [ ] Asistencia al trazo: los parciales al 60 % siguen por debajo del 80 %.
- [ ] Glifos nuevos de MEJORAS_POTENCIA §6 (perforar, senda, marca…), solo si Pablo los aprueba.
- [ ] **Pulso resonante** (`PLAN_PULSO_RESONANTE.md` §12): la FASE 1 (señal y lectura) está hecha el 23/10 (`Pulso3D`, `cristal`, `veta`, `receptor`, C1 y C5 → C6). Quedan la fase 2 (prismas, cofre legendario con animación, glifo ᚱ «pulso» y ᚷ → «crecer», pared hueca de salida), la 3 (C2–C4, setas, estatuas, cofre épico, reactivos con `on_pulso`), el sonido propio del pulso (hoy `sello_ok` a distintos tonos) y que en C5 la descarga amarilla de la fuente tapa el frente del pulso por el agua.

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
- [ ] Meter `tools/godot_local.txt`, `salida*.txt` y `pruebas_resultado.txt` en `.gitignore`.
- [ ] Quitar el archivo `main)` de la raíz.
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