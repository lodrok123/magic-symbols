# Pendientes abiertos

Foto del 21/10/2026, sacada de los chats de claude.ai y cruzada con el DIARIO (hasta la entrada 236).
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
- [ ] Presupuesto de polígonos: 8–12k frente al de EoW; decimar o sustituir `arbol_redondo` y `pino` por sus `_2` (`arte/meshy/PRESUPUESTO.md`).
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
- [ ] Bajar a 0 los 46 fallos de `pruebas_resultado.txt` del 20/10. Los peores: agua_tinaja, bosque_01, agua_estanque, hielo, asistencia.

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

## Pipeline

**Agua y suelo**
- [ ] Triángulos vacíos en las esquinas del agua o la orilla.
- [ ] `OSCURECER_SUELO`: igualar hierba y suelo (ARTE §10).
- [ ] La tinaja deja de verter cuando el puzle se completa: comprobar.
- [ ] Más sensación de movimiento en la caída y en el río.

**Hechizos**
- [ ] Hielo con la textura del hielo renderizado en 3D.
- [ ] Comprobar que la bola de fuego crece a la vista (DIARIO 226).

**Encargos del plan EoW (diario 238)**
- [ ] B2: el shader del suelo lee `Mundo3D.textura_estados()` y se retira `_img_estado` de `prueba_test2.gd`.
- [ ] Enganchar `ReaccionesVfx3D.conectar(mundo, fx)` al montar el nivel: sin eso las reacciones de A4 no se ven ni suenan. (El lab de playtest ya lo hace por su cuenta; falta en la maqueta para todos los niveles.)
- [ ] Burbujas del hundimiento al aviso `impacto(…, "hundido", …)` / reacción `hundido` (1,6 s de efecto frente a 1,0 s de hundimiento).
- [ ] Escudo del goblin: ajuste visual en el brazo, efectos de `EXCEPCIONES["escudo"]` con el nodo real y escudo mojado visible.
- [ ] Mano quemada (diario 239): clip `mano_quemada` del goblin (+ `"mano_quemada"` en `ArbolAnimPj.ESTADOS_REDUCIDO` y en `Pj3D.SINONIMOS`), disolver por celdas del escudo quemado en vez del encogido provisional, y chispas en la mano con la señal `Escudo3D.mano_quemada`.
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
- [ ] Reescribir para el 3D las secciones de lógica de `ARQUITECTURA.md` (piezas del sistema, mundo, niveles, Test 2, partículas, bloqueo físico, interfaz): nombran scripts 2D que ya no existen (diario 237).
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
- [ ] Enganchar `Logros3D.conectar` y `ReaccionesVfx3D.conectar` en la maqueta (todos los niveles), y un emisor de «nivel_completado».
- [x] ~~Plan visual V3–V8~~ — hecho el 21/10 (diario 246).
- [x] ~~Pablo: generar en Meshy tierra, hielo y el atlas de viento~~ — recibidos el 21/10 (diario 246).

## Lote del 21/10 noche (diario 246)
- [x] ~~Lotes de tierra y hielo y atlas de viento: instalar y enganchar en los VFX~~ — hecho y aprobado el 21/10 (diario 247).
- [x] ~~Capturas de V3–V7 y decisión de V8~~ — revisado y aprobado por Pablo el 21/10 (diario 247).
- [x] ~~Esquirla, placa rota y hojas de viento~~ — hecho el 21/10 (`5b1d368`): cometa en el proyectil de hielo (`VfxHielo.proyectil_esquirla` para volver), placa rota al perder el hielo una casilla, hojas 0,25–0,5 u. Falta verlo jugando.
- [x] ~~Viento con el atlas como máscara~~ (`71b754d`) — **validado por Pablo el 21/10**. Esquirla en la flecha, rayo de hielo y tierra legible en `b0e4ffb` — **validados por Pablo el 21/10**.
- [ ] Forma de hechizo «rayo» en el camino actual (VfxElemento3D) para que `VfxHielo.rayo` se vea jugando; hoy solo lo dispara el chorro antiguo de recetas. **Regla de Pablo (21/10): el rayo es glifo `linea` (ᛁ) + elemento** (rayo de hielo = línea + hielo, y así con cada elemento; no confundir con el elemento «rayo» ᛊ). Chocaba con `linea` = «muro delante»: **decidido y hecho el 21/10: el muro pasa solo a `barrera`; `linea` + elemento = haz** (forma `haz`; `VfxElemento3D.haz`, `prueba_haz.gd`, ESPEC_HECHIZO §3b). Pablo valida cómo se ve cada rayo (`docs/capturas/haz/`).
- [ ] Pablo: ¿roca a 2,5 k (`aprobacion3d/v8_piezas/`)? ¿`pino_2` con otro color para pasar también el pino?
- [ ] Commitear (su sesión) los cambios ajenos de `Nivel_Bosque_01.tscn` y de `prueba_test2.gd` (colisión por contorno, F7).
- [ ] Migrar los usos de `_img_estado` (hierba, agua, Lanzador, reacciones, lab) a `Mundo3D.textura_estados()` para poder retirarlo (cierra B2).
- [ ] Enredadera con el `quemado`/`disolver` común (necesita `corte_y` en el shader común); cofre que aparece con `disolver`.