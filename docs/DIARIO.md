# Diario entre contextos

Cada sesión que toque un contrato, o algo que el otro contexto necesite
saber, añade una entrada **al final**. Al empezar, leer las últimas.
Formato: fecha · contexto · qué cambió · qué le hace falta al otro.

---

- **2026-10-04 · Pablo** · Se crea `docs/PROPIETARIOS.md` con el reparto de
  archivos entre Juego y Pipeline. Pendientes conocidos que cruzan la
  frontera: el Juego ya busca el clip `shot_in_the_back_and_fall` del héroe
  (Pipeline: procesarlo del inbox); `project.godot` apunta a
  `tests/walk_8dir_test.tscn`, que no existe, y activa
  `addons/ms_sprite_importer` sin carpeta `addons/` (Pablo).
- **2026-10-04 · Juego (QA de arte)** · Nuevo `docs/QA_ARTE.md` con lo medido
  sobre bloques y clips. Para el Pipeline: los hielos de `art/` tienen la cara
  en y=96 (no 33) y se dibujan 22 px hundidos; `shot_and_fall_backward` del
  guerrero ya existe y el Juego lo va a usar, pero `MsActor.jugar()` necesita
  poder quedarse en el último fotograma (`volver = ""`); mientras no llegue
  `shot_in_the_back_and_fall`, recortar la muerte del héroe a los fotogramas
  0–5 de `hit_reaction_to_waist` (ahora se levanta al final). Pendiente de
  Pablo: confirmar en Godot la lista §4 del informe.
- **2026-10-05 · Juego (QA de arte)** · Procesado `chibi_elf` a mano con Pablo. Lo que falló y
  **le toca al Pipeline**: (1) `validate_character_config.py` necesita `jsonschema` y nadie lo instala
  (`requirements` o `pip install` en el `.cmd`); (2) `EXPORTAR_GODOT.cmd` usa `>/dev/null`, que en
  Windows falla y cae al Python de la Store (`where py >nul 2>nul`); (3) `build_character.py` no hace
  la fase de arte y `exportar_godot.py` solo lo dice al final, con los renders hechos; (4) el
  `REPORTE.md` solo lo reescribe `PROCESAR_PERSONAJES.cmd`: un build lanzado a mano deja la cabecera
  `RECHAZADO` vieja y el exportador se niega; (5) los atlas salen del master sin el look del E2E
  ("pendiente de probar con Blender real"); (6) `config/ms.json` pide `character_style: personaje_toon`
  y `profiles/styles/personaje_toon.json` no existe: los personajes se renderizan sin toon ni contorno;
  (7) un clip `walk_*` con desplazamiento (`Walk_Turn_Right`) se rechaza por el nombre: avisar antes de
  ensamblar. Medido en los 3 atlas que hay: direcciones correctas, figura 174 px en 256×320 → 118 px en
  juego; para 95 px, `escala_relativa: 0.8`. Clips nuevos que el Juego puede adoptar cuando salga el
  `meta.json`: `dead`, `roll_dodge`, `stand_and_drink`, `readandwrite`, `charged_ground_slam`.
  Los 3 GLB de Meshy (árboles, mercado, armas) están partidos en bibliotecas del POC
  (`poc_25d/meshy/arboles_2.glb`, `mercado.glb`, `armas_goblin.glb`; ver `meshy/ESTADO.md`).
  Los cambios del Juego que pidió el Pipeline ayer quedan como diff en
  `docs/CAMBIOS_JUEGO_PENDIENTES.md` (se aplican en la copia que mande). **Ojo:** hay dos copias del
  repo (`pablo` y `paranda`) con diarios distintos; este es el de `paranda`.
- **2026-10-05 (noche) · Pipeline** · Hecho lo de `PLAN_ACCION_TEST2.md` §2.2 (detalle en su §4) y aplicados en
  `paranda` los tres diffs de `CAMBIOS_JUEGO_PENDIENTES.md` (hielo del pipeline, muerte con animación, parón al
  recibir golpe): **falta F6 en Test2 y Mundo**. Los 7 puntos del pipeline 2D: (1) los `.cmd` instalan
  `requirements.txt` si falta `jsonschema`/`Pillow`, y `build_character.py` también si se lanza a mano;
  (2) `EXPORTAR_GODOT.cmd` busca Python como los demás (`py -3`, sin `/dev/null`); (3)+(4) `build_character.py`
  termina con `cerrar_build.py`: fase de arte si el master es más nuevo que el arte y `REPORTE.md` nuevo con el
  veredicto de ese build (ya no se queda la cabecera `RECHAZADO` vieja); los informes de animaciones
  desactivadas no cuentan (el `dead_render_validation.json` viejo rechazaba a `chibi_elf`); (5) los atlas pueden
  salir del GLB de arte con `"atlas_desde": "arte"` en `config/ms.json` (por defecto `master` hasta decidir el
  canon; ojo: el E2E alarga las acciones ×1,25, lo avisa el REPORTE); (6) `personaje_toon` **sí** se aplica en
  `paranda` (render_character también busca en `tools/estilos`; el metadata de `chibi_elf` dice toon + outline):
  ahora el REPORTE lo dice en una línea; (7) `procesar_inbox.py` mide cuánto se desplaza la cadera en cada GLB
  ANTES de ensamblar: un `walk_*`/`run_*` que se mueve, o cualquiera que se va más de un alto de cadera
  (Dead 1,6, Roll_Dodge 4,5, Swim 6,2), se desactiva con el motivo en el REPORTE. `render_character.py` no se
  ha tocado: los renders ya validados siguen al día. `mercado.glb` vuelve a tener los ids de `ESTADO.md`
  (una subida intermedia lo había pisado). Hierba: aplicado `HIERBA_OPTIMIZACION.md` §2.1 y §2.2 (bloques
  de 4×4 casillas, solo alrededor de la chibi, deterministas); de §2.3, `visibility_range` NO sirve con la
  cámara ortográfica a 40 u (desaparecería todo) y las tarjetas ya recortaban con `discard`.
- **2026-10-05 (noche) · Pipeline** · Grimorios de Meshy integrados en el POC: `poc_25d/equipo/grimorio_1..3.glb`
  (botánico, rúnico, legendario) en la cadera de `chibi_elf`, con tecla N para cambiar de nivel
  (`Equipo3D.nivel_grimorio`, `Pj3D.set_nivel_grimorio`). Solo 3D: los atlas del Test 2D y del pipeline siguen
  con el grimorio que se renderizó.
- **2026-10-05 (noche) · QA/Juego** · Nuevo `docs/TECNICAS_APLICABLES.md`: criba de cuatro dosieres (BotW/TotK,
  Odyssey/Bananza/LM3, Journey + deformación + agua) contra Test2. Para Pipeline, en orden: D2 capa de estado
  por celda (`Image` 40×40 RGBA: quemado/mojado/helado/pisado leída por suelo, hierba y agua; se escribe desde
  `_al_impactar`), D4 hierba que se aparta (`global uniform posicion_jugador`), D1 shader de agua por
  profundidad que sustituye `_mat_agua` + `uv1_offset` (con fallback sin depth), D3 rampa toon en `light()`,
  D7 regla "textura ≤ 2× píxeles en pantalla". Para Pablo: 7 texturas (tabla §3). Descartado y por qué en §6.
  No toca nada existente todavía: es propuesta para medir paso a paso en `PLAN_ACCION_TEST2.md`.
- **2026-10-05 (17:30) · QA/Juego** · Nuevos `docs/IMPLEMENTAR_TECNICAS.md` (guía paso a paso para el
  Pipeline en `poc_25d/`: estado por celda + `Vfx3D` con F1–F6 + `Hierba3D.set_estado()`/`set_posicion_jugador()`,
  `CODIGO_AGUA` por orilla, rampa toon con tecla T, presupuesto, empujables) y `docs/ENCARGO_JUEGO_ESTADOS.md`
  (el Juego publica `docs/ESTADOS_SUELO.md`, contrato de reglas sacado del 2D, que ya las tiene en
  `neutral_block.gd`/`grass_block.gd`/`water_block.gd`/`combate_comun.gd`; el Pipeline ajusta a él las reglas
  provisionales del Paso 1). **Aviso:** este diario está cambiando entre dos versiones en disco (a las 17:30
  faltaban las dos entradas del Pipeline; ahora falta la de PLAN_ACCION_TEST2): hay dos sesiones escribiendo
  desde copias distintas o un checkout por medio. Conviene que Pablo lo mire antes del commit.
- **2026-10-05 (17:45) · QA/Juego** · `goblin_archer_chibi` RECHAZADO por el propio Pipeline: la
  auto-desactivación de `dead` (se desplaza 1,30 altos de cadera) escribe `"_desactivada": "..."` en
  `character.json` y `character.schema.json` (`additionalProperties: false`) lo rechaza en la validación
  siguiente. **Pipeline:** admitir claves `^_` en el esquema o llevar la nota al REPORTE. Pablo lo
  arregla a mano borrando la línea. De paso: `walk_002` es el *Walk_Backward_with_Bow* (el juego espera
  `walk_back`); faltan `aim` y `alert`; sin `dead` el arquero no tiene muerte. `alchemist_elf` APROBADO.
- **2026-10-05 (noche) · Pipeline** · Aplicados `IMPLEMENTAR_TECNICAS.md` pasos 1, 2, 3 y 5 (y las sombras del 4) en
  `poc_25d` (detalle y teclas: `LEEME.md`). **Contrato**: el estado del suelo sigue `ESTADOS_SUELO.md`, no el Paso 1
  provisional (G y B no caducan; el fuego no quema el suelo neutro; dos aguas hielan; hierba ardiendo = R sube 0→1 en 5 s;
  crecida aparte, en `Hierba3D`). Decisiones mías, a confirmar: (a) "hierba" en la maqueta = casilla de tipo hierba del
  mapa de suelo sin objeto encima (las de camino/tierra/piedra son suelo neutro); (b) el agua helada se puede pisar
  (se quita de las bloqueadas y la chibi camina a la altura del agua + 0,12); (c) un impacto toca una casilla (radio 0,
  Dudas 7); (d) no hay objetos que arden (seto, tronco, setas, telaraña) en la maqueta todavía. API nueva: `Hierba3D.set_estado /
  set_posicion_jugador / set_crecida`, `Vfx3D.llamas / apagar / vapor`, `PruebaTest2.F1–F6, T, V`. La espuma con depth (§2.4)
  no está. Ojo: el prerender del Test 2D usa ya la rampa de luz (otro contraste en las baldosas). Le falta a QA: tabla de
  medición de cada paso (HUD) y capturas antes/después.
- **2026-10-05 (noche) · Pipeline** · `procesar_inbox.py` ya no escribe `_desactivada` en `character.json` (el esquema no admite
  claves extra y tumbaba al arquero): el motivo va al REPORTE; quitada la línea del `character.json` de `goblin_archer_chibi`.
  Carteles con runa y baldosas rúnicas en `PruebaTest2`; `seto_seco.glb` de Meshy integrado.
- **2026-10-05 (noche) · Pipeline** · Paso 4 (texturas): `chibi_elf`, `bookseller_chibi` y `goblin_warrior_chibi` de 2048 a 1024 px
  (GLB de ~27 MB a ~8 MB; sin diferencia visible a zoom máximo). Script `reducir_pj.py` (en la carpeta de trabajo del Pipeline;
  no toca índices, vale para personajes con esqueleto). Para QA: la columna "px en pantalla" de `ASSETS_FALTANTES.md` sale de
  180 px/unidad × el alto de `MEDIDA`; los atlas de Meshy se quedan a 2048.
- **2026-10-05 (20:30) · Pablo (vía Claude)** · La carpeta de trabajo sigue siendo
  `C:\Users\pablo\Documents\magic-symbols`; la de `OneDrive\Documentos\magic-symbols` es solo
  transporte entre ordenadores (`SUBIR_A_ONEDRIVE.cmd` / `BAJAR_DE_ONEDRIVE.cmd`, nadie escribe ahí).
  Se deja de usar git. Nueva regla 7 de `PROPIETARIOS.md`: **ningún
  contexto crea documentos nuevos en `docs/`**; se proponen en el diario y los crea Pablo. Los doce
  documentos de hoy que no están en la tabla de la regla 7 son borradores hasta que su dueño los
  integre en los vivos y los borre. Firmas: solo `Juego` y `Pipeline`. `DISENO_FUTURO.md` §0 (P0):
  criterio de decisión y condición de fin de la prueba 3D (`poc_25d`), fecha límite 12/10;
  **Pipeline:** no añadir a la maqueta nada que no ayude a medir uno de los seis criterios.
  Este diario ha tenido dos versiones en disco hoy: es OneDrive; antes de escribir, releer.
- **2026-10-05 (20:55) · Juego** · `goblin_archer_chibi`: build directo VALID (8 clips, 38 min, log `_logs\...180318.log`)
  y arte APROBADO; falta `EXPORTAR_GODOT.cmd`. **Pipeline:** la fase de arte avisa de ×1,25 frames en todos los clips
  (el E2E guarda la escena a 30 fps y el master está a 24); no afecta a los atlas (salen del master) pero sí lo hará si
  algún día `atlas_desde: arte`. Y en el REPORTE de la ingesta el `walk_002` del arquero es *Walk_Backward_with_Bow*:
  el Juego lo necesita como `walk_back`; propongo renombrar el clip en `character.json`/`meta.json` antes de exportar
  o mapearlo en `goblin_arquero.gd`. Leída la regla 7: a partir de ahora el Juego no crea docs; propone aquí.
- **2026-10-05 (21:35) · Juego (a petición de Pablo, en archivos del POC)** · Postura de la chibi en 3D: `ProporcionChibi`
  gana `cabeza_atras / cuello_atras / columna_atras / brazos_abrir` (grados, sumados al clip cada fotograma, en
  `_process_modification`); `Pj3D.POSTURAS` por id (elfa: 8/3/2/0) y `set_postura()/postura()`; en `PruebaTest2`
  teclas `,` `.` (cabeza) y Shift+`,` `.` (hombros), imprimen los valores. Motivo: los clips de Meshy la dejan
  cabizbaja y encogida de lado. Solo 3D; para los sprites habría que llevarlo al master de Blender y rerrenderizar.
  **Pipeline:** si el signo del eje X local del rig sale al revés, invertir en `_girar`.
- **2026-10-05 (22:45) · Juego (a petición de Pablo, archivos del POC)** · Postura de la chibi cerrada y fijada en
  `Pj3D.POSTURAS`: `chibi_elf: [-20, 8, 6, 24, 16, -12, -4]` = cabeza, cuello, columna (eje X local), hombros (Z),
  rodillas (X, el tobillo se contragira), pies (muslos en Y), pelvis (cadera en X con los muslos contragirados
  premultiplicando en el espacio del padre, así las piernas no se mueven). Todo en `ProporcionChibi._process_modification`.
  Teclas de ajuste en PruebaTest2: `, .` cabeza · `U I` rodillas · `Y O` pelvis · con Shift hombros / pies; imprimen la
  línea para copiar. `;` `'` no valen en teclado español (`;` es Shift+`,`). Grimorio de la elfa movido de la cadera
  izquierda a la espalda centrada (`equipo_3d.gd`, `Hips (0, 0.06, -0.20)`, giro 180°): más visible y tapa el solape
  vestido/brazos. Solo 3D; los sprites no lo llevan. **Pipeline:** tres archivos (`pj_3d.gd`, `proporcion_chibi.gd`,
  `prueba_test2.gd`) tocados; Godot los pisó cuatro veces esta noche con "guardar" desde el editor de scripts: antes de
  editar, releer del disco. Pendiente propuesto: giro de muñecas (palmas al muslo) y bajar hombros a ~14°.
- **2026-10-05 (23:55) · Juego** · Pablo pide pasar Test2 a "prueba real" = condición de fin de `DISENO_FUTURO.md` §0.
  Estado: fuego que prende y se contagia ✔ (Pipeline, F1–F6); grimorio real ✗; goblin con Combate ✗; tabla de medición ✗.
  Plan propuesto (doc lo crea Pablo, regla 7; detalle en el chat de hoy): (1) `Spellbook`+`GestureRecognizer` en un
  `CanvasLayer` + `Lanzador3D` nuevo (receta → `Vfx3D.lanzar` + `Area3D` proyectil con etiquetas; sustituye a
  `spellcaster.gd`, 929 líneas `Node2D`; `spell_form`/`spell_material` no se portan, su papel lo hace `Vfx3D`) — Juego,
  con VFX por forma del Pipeline; (2) contrato `on_spell_hit(rune_data, direction)` en `Pj3D` y objetos que arden — Juego
  define, Pipeline engancha; (3) `Combate3D` desde `CombateComun` (misma tabla; tinte de material, barra `Label3D`) + IA
  mínima del guerrero — Juego; (4) jugador mínimo (daño/muerte) — Juego; (5) tabla de medición — QA; (6) letras A →
  arquero cuando haya GLB. Reutilizable tal cual: `GestureRecognizer`, `RuneData`, `SpellRecipe`, `Sigils`, `Progresion`,
  `Alquimia`, `Misiones`, `Estado`, `Objetos`, `Botin`, `Spellbook`. Otros cambios de hoy en `poc_25d` (a petición de
  Pablo): relieve del suelo (`normal_suelo`, tecla B) y variante `goblin_espadachin` (`Pj3D.MODELO_DE`, `Equipo3D.EQUIPO`,
  letras A del mapa, `CatalogoAssets`). **Pipeline:** Godot pisó `prueba_test2.gd` dos veces más; releer siempre.
- **2026-10-06 (00:15) · Pablo (vía Claude)** · `PLAN_ARREGLOS.md` fase 4 **"Test 3"**: el plan del Juego de
  las 23:55 con dueños, más altura (cámara 7), VFX por forma, validación de GLB y layout. Reparto de archivos
  dentro de `poc_25d/`: `lanzador_3d / combate_3d / jugador_3d / playlog_3d` son del Juego; el resto del POC,
  del Pipeline. Pablo decide 4.0a-c (altura, cast point, tierra con duración / retardo) antes de que el Juego
  empiece 4.1. **Para los dos:** cerrar el editor de scripts de Godot mientras un chat escribe en `poc_25d`.
- **2026-10-06 (00:20) · Pablo (vía Claude)** · Decisiones 4.0a-c cerradas en `DISENO_FUTURO.md` §0b: altura con
  `MAX_NIVELES_SUBIBLES = 2`; **modo lanzar** (tiempo al 70 %, `readandwrite` + partículas sutiles, el ratón
  controla dirección y posición, alcance 3 casillas, `anim_cast` por forma en datos); tierra 25 s / hielo 20 s
  con duración; caída al agua → `swim_forward`; retardo fuera. Tareas nuevas en el plan: Juego 4.1b, 4.1c,
  4.4b; Pipeline 4.6b y 4.8 ampliada. **Contrato que cambia:** `ESTADOS_SUELO.md`, el hielo caduca (Juego lo
  escribe, Pipeline lo cumple).
- **2026-10-06 (00:50) · Juego** · **Tarea 4.2: contrato `on_spell_hit` en 3D** (publicado para que el Pipeline enganche 4.7 en
  paralelo). Constantes y variables en `poc_25d/lanzador_3d.gd` (esqueleto nuevo, `class_name Lanzador3D`; 4.1 le pondrá el
  cuerpo sin cambiar nada de esto). Es el mismo trato que en 2D, con `Vector3`:
  1. **Firma:** `func on_spell_hit(rune_data: RuneData, direccion: Vector3) -> void`. `direccion` es horizontal y unitaria (y = 0), o
     `Vector3.ZERO` si el hechizo está quieto (una tierra quieta construye; una flecha de tierra, no). Se decide por
     `rune_data.tags`, **nunca** por `rune_type`. Etiquetas que existen hoy: fuego `[fuego, calor]` (daño 40) · agua `[agua]` (40) ·
     viento `[viento]` · tierra `[tierra]` · rayo `[rayo, electrico]` (55, es un haz) · hielo `[hielo, frio]` (20) · tiempo
     `[tiempo, disipar]` (fuera del Test 3) · vapor `[vapor]` (lo genera el mundo, no se lanza).
  2. **Quién lo implementa:** un `Area3D` (o un hijo `Area3D` de un cuerpo) con `collision_layer |= Lanzador3D.CAPA_REACTIVO`
     (capa 9). Los hechizos viven en `CAPA_HECHIZO` (capa 8) y solo miran la 9 y la 10 (`CAPA_BLOQUEO`: zonas que paran
     proyectiles). **Pipeline:** si el POC ya usa las capas 8-10, dilo aquí y las muevo yo.
  3. **Posición:** no va en la firma. Justo antes de llamar, el lanzador pone `Lanzador3D.ultimo_impacto` (Vector3, mundo) y
     `Lanzador3D.ultimo_nivel` (int); los borra después (`Vector3.INF`). Quien la necesite (la hierba, para prender desde el punto de
     contacto) la lee; quien no, la ignora.
  4. **Opcionales** (si no existen se asume lo de siempre): `spell_reacts(rune_data, direccion) -> bool` (¿cambia algo de verdad?;
     falta = sí) · `spell_passes_through() -> bool` (superficie: reacciona pero no detiene) · `spell_flies_over(rune_data, cargado) -> bool`
     (el agua deja volar al viento) · `carried_element() -> RuneData` (lo que el viento se lleva: una llama) ·
     `bloquea_proyectiles(proyectil) -> bool` y `refleja_a(proyectil) -> bool` (en la zona de `CAPA_BLOQUEO`) ·
     `push(direccion: Vector3, fuerza: float)` · `nivel_altura() -> int` (niveles que ocupa; 0 = a ras; falta = 0).
  5. **Orden de una colisión** (el de `spell.gd::_on_area_entered`): (a) si es zona de bloqueo y `bloquea_proyectiles` → el proyectil muere
     o rebota, y no se sigue; (b) el viento intenta `carried_element` y `push`; (c) sin `on_spell_hit`, nada; (d) `spell_reacts`;
     (e) `on_spell_hit`; (f) el proyectil muere si el objeto reaccionó y no es `spell_passes_through`/`spell_flies_over`. Un muro aplica su
     elemento **una vez** a cada objeto que cruza.
  6. **Altura (§0b):** un proyectil vuela a medio nivel (`ALTO_NIVEL * 0,5`, más lo que sume la levitación) y choca con lo que tenga
     `nivel_altura() >= 1 + nivel_del_hechizo`: un bloque de tierra (1) para una flecha normal; un charco (0), no. Los enemigos
     declaran 1. `ALTO_NIVEL` = `S * 0,45` copiado de `prueba_test2.gd`: si allí cambia, avisad.
  7. **Suelo:** sin cambios. Sigue `PruebaTest2._al_impactar(elemento, punto)` conectado a `Vfx3D.impacto` y las reglas de
     `ESTADOS_SUELO.md`. `Lanzador3D` llamará a `Vfx3D.lanzar(elemento, pie_origen, pie_destino)` con el **destino real** (donde el
     hechizo para), así el suelo se marca donde de verdad impacta. Nada que tocar en `Vfx3D`.
  8. **Jugador y enemigos:** `Pj3D` **no** implementa el contrato; lo hará un hijo `Combate3D` (Juego, 4.3) con su `Area3D`. Al Pipeline
     solo le tocan los objetos del mapa (4.7): seto, tronco, telaraña (muro, arden), tótems, antorchas, puente, placa.
  Peticiones para `prueba_test2.gd` / `Pj3D`: ninguna todavía; las de 4.1b (clip de lanzar por nombre) irán en la entrada de ese paso.
- **2026-10-06 (01:30) · Pipeline** · Hechas 4.8, 4.6 y 4.6b (detalle y teclas: `poc_25d/LEEME.md`, arriba del todo; sin medir, la nube no tiene Vulkan).
  **Para el Juego (API nueva, nada de lo vuestro tocado):** (1) `Vfx3D.lanzar_forma(forma, elemento, pie_origen, pie_destino, opciones := {})`,
  forma ∈ `Vfx3D.FORMAS` = proyectil · corro · columna · muro; `opciones`: `radio` (corro: radio del anillo; muro: semiancho; 1,2 u), `dura` (s).
  **Es otra función, no un parámetro nuevo de `lanzar`**: `lanzar(elemento, origen, destino)` sigue igual (= proyectil) y emite `impacto`; las demás
  formas son solo visuales y **no emiten `impacto`** (el suelo se marca donde lo decida el Lanzador con `_al_impactar`). Corro y columna: `pie_destino` es el
  centro/base; muro: `pie_destino` es donde nace y avanza hacia donde apunta origen→destino (4 filas × 5, 0,75 u entre filas). Distancias en unidades del mundo
  (`escala` las multiplica). (2) `Pj3D.lanzar(forma, elemento) -> float` (clip de `Pj3D.ANIM_CAST` en bucle + motas del elemento en la mano; devuelve la duración
  del clip) y `Pj3D.soltar_lanzar()` (quita las motas y vuelve a idle): es lo que pide 4.1b; cae a `readandwrite` si no hay clip. (3) `Pj3D.validar()` avisa por
  consola al cargar (clips mínimos, cadera que se desplaza, escala); la lista mínima por tipo está en `ASSETS_PENDIENTES.md` §1. Cambios de comportamiento que
  os afectan: el `cast` genérico de la elfa es ahora `MageSoellCast003` (el anterior arrastraba la cadera); el `hit` del goblin es `SlapReaction` (el
  `HitReaction` desplazaba la cadera 1,25 alturas); `hit` de la elfa existe (`FacePunchReaction`; antes no resolvía a nada). Los clips en `Pj3D` van todos en bucle
  (también death/hit): para una muerte que se quede tumbada haría falta un `una_vez` en `jugar()`, lo hago en 4.9 si el Juego lo pide así.
  Hierba/suelo/Test2: sin cambios. **Siguiente:** 4.7 con el contrato de las 00:50 (el POC no usa las capas 8–10: libres), luego 4.9 y 4.10.
- **2026-10-06 (02:10) · Pipeline** · Hecha 4.7 (detalle: `poc_25d/LEEME.md`). Probada en motor con un script (sin medir rendimiento): el fuego recorre una hilera de 10 setos,
  la telaraña arde, agua apaga fogata, tótem de rayo tiende el puente (se desbloquea la celda).
  **Para el Juego:** (1) `Reactivo3D` (`poc_25d/objetos_3d.gd`) es un `Area3D` en grupos `reactivo3d` y `flammable3d`; implementa `on_spell_hit`, `spell_reacts`, `carried_element`
  y `nivel_altura()` (0 fogata/puente/placa, 1 el resto). Sus capas de colisión son las que fije el Juego (el POC no usa 8–10); aún no las pone, así que **hay que
  asignar `CAPA_REACTIVO` al instanciarlos** cuando el Lanzador exista. (2) La placa se acciona con **cualquier nodo del grupo `"peso"`** que solape su Area3D: el bloque de tierra
  y el empujable del Juego deben añadirse a ese grupo. (3) Hasta que haya Lanzador, F1–F6 llegan a los objetos por `PruebaTest2._golpear_objetos` (emulación del contrato);
  cuando el Lanzador llame a `on_spell_hit`, se puede quitar. (4) No convertí la barrera de fuego (B) ni las setas (h): no están en 4.7.
  `prerender_test2d.gd` apaga `objetos_reactivos`. **Siguiente:** 4.9 (guerrero y arquero jugables) y 4.10 (layout Test 3).
- **2026-10-06 (03:00) · Juego** · Hechos 4.1, 4.1b, 4.1c, 4.4, 4.4b, 4.3 y 4.5 (compilados y probados en Godot 4.7 headless con un script; sin ver ni medir en pantalla real). Archivos nuevos en `poc_25d/`: `lanzador_3d.gd` (sustituye al stub), `jugador_3d.gd`, `combate_3d.gd`, `playlog_3d.gd`; y `docs/ESTADOS_SUELO.md` (§7 nueva: **cambio de contrato**, la tierra y el hielo caducan en el 3D).
  **CORRECCIÓN al contrato de las 00:50, punto 4/6:** `nivel_altura()` **falta = 1** (no 0). Un objeto con 0 (fogata, puente, placa, charco) está **a ras**: reacciona a lo que pasa por encima o lo toca, pero **no lo detiene**; lo que vuela más alto (levitación) lo salta. `Reactivo3D` ya declara 0/1 así: encaja tal cual.
  **Peticiones al Pipeline (exactas):**
  1. `prueba_test2.gd`, 5 cambios (diff probado sobre vuestra versión de las 01:07, líneas aprox.): (a) tras `var _precalentando: bool = false` → `var externo: bool = false`; (b) al final de `_ready`, tras `_precalentar(capa)` → `Jugador3D.montar(self)`; (c) en `_golpear_objetos`: `if externo or not objetos_reactivos:` (con Lanzador los golpes llegan por `on_spell_hit`; si no, todo se aplica dos veces); (d) en `_process`: `if not externo: _mover(delta)`; (e) en el bucle de goblins: `if not externo and d.length() < 7.0:`. Con `externo = true` Jugador3D mueve al jugador y Combate3D a los goblins.
  2. **BUG en `objetos_3d.gd`:** el `enum Estado` interno choca con la clase global `Estado` (`estado.gd`, el oro/mochila del 2D) y no compila en el proyecto real (`Cannot assign a value of type Reactivo3D.Estado to variable "estado" with specified type Estado`). Renombrarlo, p. ej. `EstadoObj` (11 usos; yo lo probé así).
  3. Nada más. Uso `Pj3D.lanzar(forma, elemento)` / `soltar_lanzar()`, `Vfx3D.lanzar_forma` (una vez por hechizo; columna: una por casilla) y `Vfx3D.lanzar` para proyectiles. Las formas no emiten `impacto`: **el suelo lo marco yo llamando a `_al_impactar` una vez por casilla** (por eso (c)). Los clips de muerte/golpe van en bucle: uso mi propio `Jugador3D.una_vez()` (pausa el AnimationPlayer al final), no hace falta `una_vez` en `jugar`.
  **De qué depende mi código en `PruebaTest2` (no los renombréis sin avisar):** `S`, `ALTO`, `ALTO_AGUA`, `VEL_ANDAR`, `VEL_CORRER`, `_lado`, `_letra`, `_bloqueadas`, `_helada`, `_hf` (`fase`, `v`; `Fase.CRECIDA = 1`), `_pisadas`, `_img_estado`, `_poner_canal`, `marcar_estado`, `_al_impactar`, `_fx`, `_camara`, `_jugador`, `_goblins`, `_velo`; y `Reactivo3D` (grupo `reactivo3d`: `Jugador3D.montar` les añade `CAPA_REACTIVO`).
  **Qué hace cada cosa:** `Lanzador3D` hereda de `spellcaster.gd` (libro, $P, páginas, recarga). Regla del libro: un glifo por sector (el segundo se rechaza: "Hueco ocupado") y todos los glifos de la página se funden en UNA receta; `pilar` y `retardo` fuera. Al cerrar el libro (o 1/2/3) entra el **modo lanzar**: `Engine.time_scale = 0,7`, jugador quieto, ratón fija origen (≤3 casillas de ti; cerca de ti nace en ti) y arrastrando, dirección; soltar lanza; clic derecho/Esc cancela (o a los 12 s). Flechas/haces: barrido instantáneo con efectos retrasados; muro, corro, columna, onda: `Campo` con golpes por `on_spell_hit`. Tierra: 25 s, apila 2, tope 8. Hielo: 20 s (ver ESTADOS_SUELO §7). Columna = barrera + levitación: sólida, 2 niveles. Jugador: Espacio salta (un nivel; máx. 2 niveles subibles), nada si pisa agua, vida 100, muere y reaparece a los 2,2 s. Goblins: IA del `goblin_guerrero.gd` (detecta a 2,5 casillas, persigue, golpea 20, se rinde a los 3,5 s), misma tabla de efectos, botín 10 de oro. **F12:** panel de medición; al cerrar el juego escribe `resumen_3d` en `user://playtest_logs/`.
  **Teclas ahora tomadas por el libro** (consume el evento): `T` abre el libro y `1/2/3` lanzan página; los presets de cámara 1/2/3 y la rampa de luz T de `PruebaTest2` ya no se alcanzan. Proponed otras teclas si las queréis (p. ej. F7–F9).
  **Cómo probar (Pablo):** cerrar el editor de scripts; aplicar la petición 1 y 2 (o pedírmelo a mí); abrir `poc_25d/PruebaTest2.tscn` y F5. `T` abre el libro: dibuja el elemento y glifos, `T` para cerrar → apuntas con el ratón → sueltas. WASD, Shift, Espacio, F12.
- **2026-10-06 (07:10) · Juego** · A petición de Pablo apliqué yo las peticiones de las 03:00 (cambios mínimos, sin más): `objetos_3d.gd`, `enum Estado` → `EstadoObj` (11 usos; chocaba con la clase global `Estado`); `prueba_test2.gd`: `var externo`, `Jugador3D.montar(self)` tras `_precalentar(capa)`, `if externo or not objetos_reactivos:` en `_golpear_objetos`, `if not externo:` en torno a `_mover(delta)` y `if not externo and d.length() < 7.0:` en el bucle de goblins. Pipeline: reabrid esos dos archivos antes de editarlos.
- **2026-10-06 (10:30) · Juego** · Hechas 1.2, 3.0 (verificada) y 3.1; sin probar en Godot (no hay editor en esta sesión): abrid `IsoTest`/`Test2` con F6 y comprobad. (1) **Muro del mundo:** `nivel_base.MURO_MUNDO = 3` (capas 1+2) en árboles y props macizos; `player.gd` mantiene la máscara de la capa 2 aunque suba. (2) **Arquero tras morir:** `on_spell_hit` de guerrero y arquero sale si `health <= 0`; `_die()` los saca de los grupos `goblins`/`enemies`; `CombateComun._arco_cercano` salta cadáveres. (3) **3.0:** el código de `goblin_guerrero._die`, `nivel_base._agua` (`water_frozen_*`) e `interrupcion` ya estaba; los tres PNG existen en `export_godot/terrain/bosque_01/sprites/blocks/`. **Pipeline:** ningún `.gd` referencia `art/hielo_1_nevado.png`, `hielo_2_escarcha.png` ni `hielo_3_claro.png`: podéis borrarlos. (4) **3.1:** con `aim_with_mouse`, `spellcaster.add_sigil` rechaza el segundo glifo de un sector ("Hueco ocupado: ya hay 'X'") y `place_sigil` (paleta) va al primer hueco libre; sin ratón no cambia. La fusión de glifos en una sola receta ya existía en `cast_page`; `spellbook.gd` ya pintaba el aro del hueco ocupado, no hizo falta tocarlo. `Lanzador3D` tiene su propia comprobación y sigue valiendo.
- **2026-10-06 (10:45) · Juego** · Filas L1–L3 y H1–H4 de la propuesta de playtest 3D: L1 (modo lanzar), L2 (tierra 25 s), L3 (hielo 20 s y nado), H1 (salto un nivel, máx. 2), H2 (columna sólida de 2) y H3 (cobertura, goblins no suben) **ya estaban** en `lanzador_3d.gd`/`jugador_3d.gd`/`combate_3d.gd` (4.1b, 4.1c, 4.4, 4.4b). Añadido ahora, sin probar en Godot: **H4** (agua, hielo y charcos solo a nivel 0): `Lanzador3D._agua_o_hielo_en_altura` descarta esos dos elementos sobre casillas con `altura_en >= 1` (tierra o columna), y `impacto_filtrado` se conecta a `Vfx3D.impacto` en lugar de `PruebaTest2._al_impactar` (lo hace `Jugador3D.montar`, ambos del Juego; llama a `_al_impactar` y a `al_impactar` en el mismo orden de antes). Arreglo de L3: el hielo de muros y corros (`marcar_celda`) no se apuntaba para caducar; ahora sí. **Pipeline, sin cambios en vuestros archivos, pero:** `Jugador3D.montar` desconecta `Callable(mundo, "_al_impactar")` de `_fx.impacto`; si renombráis esa función o la conectáis de otra forma, avisad. Evento nuevo de PlayLog: `estado_en_altura_rechazado`.
- **2026-10-06 (tarde) · Pipeline** · A petición de Pablo (hierba que pesa, VFX "pegatinas", piezas que crean desniveles; referencia Link's Awakening). **Sin probar en Godot** (la nube no tiene editor): abrir `poc_25d/PruebaTest2.tscn`, dejar que reimporte `vfx/` y mirar. **Cerrar el editor de scripts de Godot mientras se aplica** (pisó `prueba_test2.gd` seis veces el 5/10).
  (1) **Hierba (`hierba_3d.gd`):** `densidad` 10 → 3,5, matojo de 9 → 5 briznas más anchas, `lado_bloque` 9,2 → 4,6, `bloques_por_fotograma` 2. Antes: 25 bloques de 9,2 u con ~5,7 M de triángulos para ~11×7 u visibles y un tirón por bloque nuevo (8.460 matojos). Ahora ~5× menos triángulos. `prueba_test2` calcula el radio con `lado_bloque`, no hace falta tocarlo. Si se ve rala: subir `densidad_tarjetas` antes que `densidad`.
  (2) **Desniveles (`prueba_test2.gd`):** `Y_DECAL = ALTO + 0,02` para discos/runas/marcas (antes +0,03, +0,05 y +0,02 según el sitio; `objetos_3d.gd` pasa de 0,03 a 0,02); `PLANAS` (placa 0,05 · baldosa de guardado 0,04 · pasadero 0,10): lo plano sobresale un grosor fijo y el resto de la malla queda enterrado; `HUNDIR = 0,03` entierra toda pieza para que la base irregular de Meshy no flote; `SOMBRA_CONTACTO`: elipse oscura de borde duro bajo árboles, rocas, setos, tótems, puestos… (un solo MultiMesh `sombras_contacto` en `Efectos`). **`ALTO` y `ALTO_AGUA` no cambian**: `Lanzador3D` los lee de aquí. **Pendiente de decidir (Pablo/Juego):** el puente (`ALTO_AGUA + 0,05`) queda 0,41 u por debajo de las orillas (`ALTO`); igualarlo exige que `Jugador3D` use la altura del puente al pisarlo, y eso es del Juego.
  (3) **VFX (`vfx/*.png`, `vfx_3d.gd`):** los 28 sprites se rehacen con `tools/gen_vfx_flat.py` en estilo plano (3 tonos + contorno grueso), mismos nombres y 256×256; hay tiras nuevas de 8 fotogramas `llama_tira8` (rehecha), `humo_tira8`, `polvo_tira8`, `brasa_tira8`, `chispa_electrica_tira8`, `destello_tira8`: `Vfx3D._particulas` usa `<nombre>_tira8.png` sola si existe. Solo `circulo_runico` sigue aditivo (`ADITIVOS`); el resto va opaco (alfa mínimo 0,92) y el fundido se reduce al último 12 %. Las ilustraciones antiguas quedan en `vfx/_pegatinas_v1/` (con `.gdignore`, no se importan; se pueden borrar). `vfx/runas/` no se toca. **Juego:** nada que cambiar; la API de `Vfx3D` es la misma.
- **2026-10-06 (mediodía) · Pipeline** · A petición de Pablo (los VFX en sprites no convencen; piezas aprobadas: suelo, hierba animada, partículas del aire, cámara a 60°). Verificado por primera vez **en un Godot 4.7 de la nube** (headless + capturas con render por software: las formas valen, el color de la captura sale lavado). **Cerrar el editor de scripts antes de abrir el proyecto.**
  (1) **Cámara:** `INCLINACION = 60.0` en `prueba_test2.gd` (la versión del repo había perdido el bloqueo). Se quitan R/F y 1/2/3; el zoom +/- sigue libre.
  (2) **VFX en 3D, sin sprites (sustituye al punto 3 de la entrada de la tarde):** `poc_25d/formas_3d.gd` (nuevo, `Formas3D`): 19 piezas facetadas con 3 tonos por vértice y contorno (llama, ascua, nube, burbuja, gota, chispa, estrella, copo, hoja, piedra, cristal, púa, corona, rayo, remolino, anillo, runa, grieta, disco). `vfx_3d.gd` reescrito sobre ellas: partículas `GPUParticles3D` con malla 3D, opacas, sin fundido alfa. **La API pública de `Vfx3D` no cambia** (`lanzar`, `lanzar_forma`, `llamas`, `apagar`, `vapor`, `ceniza`, `chispazo`, `chispas_mano`, `precalentar`, señal `impacto`, `escala`, `velocidad`, `con_luces`). Nuevo: `Vfx3D.fuego_fijo(p, barrera, esc)` (lo usan fogatas, braseros y la barrera B). El bloque de tierra es un bloque de verdad (tierra con contorno, se hunde al caducar). Los tótems usan `Formas3D "runa"` en vez del disco-sprite. Los PNG de `vfx/` quedan solo para el aire (pétalos, hojas, esporas, destellos).
  **Para el Juego (opcional, son cosas vuestras):** (a) el bloque de tierra real del Lanzador es una caja marrón lisa: podría usar `dirt_arriba`/`tierra_lado` de `suelo_meshy/` y un contorno; (b) `lanzar_forma("columna", …, {"dura": min(duracion, 3.0)})` limita a 3 s el efecto visual de la columna aunque la barrera dure más; (c) el puente sigue 0,41 u por debajo de las orillas (pendiente de la entrada de la tarde).
  (3) **Personajes nuevos:** `PJ_ALQUIMISTA`, `PJ_ARQUERO` y `PJ_GUARDABOSQUES` en `prueba_test2.gd` (con sustituto si falta el GLB), `ALTO_PJ` ampliado, `poner_puesto()`. **Los GLB `alchemist_elf` y `goblin_archer_chibi` NO están en el repo** (solo hay `character.json` y atlas 2D): `COPIAR_MODELOS.cmd` ya los copia desde `pipeline\characters\<id>\<id>_master.glb`; hasta entonces salen la librera y el goblin de espada, con la etiqueta del modelo cargado sobre la cabeza. **Juego:** `Combate3D` solo conoce al guerrero cuerpo a cuerpo; el arquero (clips `archery_shot`, `hit_reaction`, `electrocution_reaction`) necesita su IA a distancia en 3D (disparar una flecha con `Lanzador3D`/`Vfx3D.lanzar`).
  (4) **PRUEBA NUEVA: `poc_25d/PruebaJugabilidad3D.tscn` (F6).** Es `prueba_test2.gd` con `@export var nivel = "jugabilidad"` y las reglas en `poc_25d/jugabilidad_3d.gd` (`Jugabilidad3D`). El MAPA 23×23, PROPS, RECOGIBLES, GUARDADOS, PUESTO_CELDA, EMPUJABLES y SETOS son los de `test_jugabilidad.gd` **copiados tal cual** (misma letra, misma casilla). Hace: las 4 tareas (losa p, goblins muertos = `_goblins` vacío, hablar con E a cualquier NPC, antorchas T = todos los braseros `is_lit`), puerta X cerrada hasta cumplirlas con 4 llamas (una por tarea), botín del suelo (pociones y oro a `Estado.i()`), guardados (mueven `Jugador3D.puntos_inicio`), HUD de tareas y puestos de librera y alquimista. **No hace (es del Juego):** el combate y la IA de goblins y arquero, la mochila/tienda, las runas de las losas a/w (se ven y avisan, no dan runas) y el viento que lleva la llama de las fuentes F hasta las antorchas por encima del río (depende de `Lanzador3D`). Adaptaciones: `g` (plataforma de tierra) es suelo de tierra a ras, no un nivel elevado; `v` es hierba normal de `Hierba3D`; los props de hierba/flores/lavanda/helecho los cubre `Hierba3D`. Probado por script en Godot 4.7: las 4 tareas se completan, la puerta se abre y se desbloquea su casilla. **Sin probar jugando**; para decidir si migramos hace falta que Pablo lo juegue.
  (5) **Cambios en archivos del Juego:** ninguno. En `prueba_test2.gd` solo se ha tocado lo del Pipeline (datos por nivel, `poner_puesto`, `_npc` devuelve el nodo, `_oro` devuelve el nodo). Siguen igual: `S`, `ALTO`, `ALTO_AGUA`, `_bloqueadas`, `_goblins`, `_jugador`, `_fx`, `_camara`, `externo`, `Jugador3D.montar(self)`.

## 2026-10-06 15:45 · Juego · Nivel jugable: PruebaJugabilidad3D con el combate y las reglas del Juego

**Qué pasa al abrir `poc_25d/PruebaJugabilidad3D.tscn` (F6).** El mapa, las 4 tareas, la puerta y el botín son del Pipeline (`jugabilidad_3d.gd`); `prueba_test2.gd` ya llama a `Jugador3D.montar(self)`, así que el nivel ya juega con el libro (T), el modo lanzar, la altura, el nadar, el combate de goblins y las mediciones (F12). No he creado un segundo nivel: el que había empezado queda descartado.

**Lo que he añadido (solo en mis ficheros):**
- `lanzador_3d.gd`: `Lanzador3D.colocar_barreras(mundo)` + clase `BarreraFuego`. En cada casilla `B` pone un Area3D (capa REACTIVO) que implementa `on_spell_hit`: **agua o frío la apagan** (apaga la llama de `fuego_fijo`, quita la luz, vapor, libera la casilla de `_bloqueadas`); fuego, rayo o viento no hacen nada. La llama y la luz las localiza por posición, sin tocar `prueba_test2.gd`.
- `jugador_3d.gd`: `montar()` llama a `colocar_barreras`.
- `combate_3d.gd`: **IA de arquero** (modelo `goblin_archer*`): se acerca hasta 6,5 u, retrocede dentro de 2,4 u y dispara una flecha cada ~3 s (12 de daño, vuela a 9 u/s hacia donde estabas: si te mueves, falla; un muro la bloquea). Mientras falte el GLB `goblin_archer_chibi` el Pipeline pone el espadachín y este se comporta como cuerpo a cuerpo.

**Pendiente / para el Pipeline:** (1) las losas `a`/`w` solo avisan: en el 3D todos los elementos ya están disponibles, no hay runas que dar; (2) el puente sigue 0,41 u bajo las orillas: decisión abierta, se pasa por tolerancia de paso (0,55) sin tocar nada; (3) el viento que lleva la llama de las fuentes F a los braseros sí lo hace `Lanzador3D`, pero los braseros también se encienden directamente con fuego.

Probado en headless (Godot 4.7): 5 barreras con llama y luz, el agua apaga y libera la casilla, el fuego no; el arquero acierta con flechas de 12. **Sin probar jugando.**

— Juego

## 2026-10-06 (tarde, 2) · Pipeline · VFX de agua, viento, hielo y rayo al estilo del fuego (solo `formas_3d.gd` y `vfx_3d.gd`)
Revisión de los elementos que no eran fuego (el fuego ya estaba aprobado). Probado por script en Godot 4.7 de la nube (sin medir rendimiento; colores de captura lavados). **La API de `Vfx3D` no cambia.**
- `Formas3D.EFECTO_TRANS` (gota, burbuja, corona, remolino, cristal, copo, rayo): ya no llevan contorno negro ni tres tonos planos (parecían pegatinas); son facetas **translúcidas con degradado** base→punta, sin luz y con mezcla normal (la aditiva se quemaba sobre el suelo claro). Agua: azul vivo → casi blanco; hielo: turquesa translúcido → punta blanca; viento: cintas verde pálido (el remolino sube de 8 a 12 tramos y las bandas son más anchas, antes casi no se veía); rayo: amarillo → pálido, más ancho, con un **halo** (segunda pieza más ancha y translúcida) en `_brote`.
- El humo (`nube`) era un bloque gris facetado: ahora es más redondo y mucho más transparente. El anillo de ondas del agua salía color arena (tomaba el color de `anillo`); ahora es azul.
- La tierra no se toca: es un bloque de verdad con textura. Pendiente de su valoración visual por Pablo (se ve liso).
- Sitios para buscar más piezas/partículas (todos con licencia libre; comprobad la de cada pack): Kenney (kenney.nl, "Particle Pack", CC0), Quaternius (quaternius.com, CC0, modelos low-poly), OpenGameArt.org, Poly Pizza (poly.pizza, CC0/CC-BY), itch.io (etiqueta "VFX" + "free"), y la Godot Asset Library para shaders de efectos. Mejor traer **mallas o shaders** que sprites: encajan con el estilo 3D.

- **2026-10-06 (16:30) · Pipeline** · Revisados `alchemist_elf` y `goblin_archer_chibi` (los `_master.glb` de `pipeline/characters/` cargados en Godot 4.7 con `Pj3D.validar()`). **Alquimista:** 0 avisos (clips Idle, Walking, Running, HandOnHipGesture, StandTalkingAngry; cadera quieta); le basta para npc (idle, walk, talk). **Arquero:** clips ArcheryShot, Dead, ElectrocutionReaction, HitReaction, Idle, Idle002, Running, Walk002, Walking; faltaban por nombre `attack` y `walk_back`: `Pj3D.CLIPS_DE["goblin_archer_chibi"]` los resuelve ahora a `ArcheryShot` y `Walk002` (0 avisos). `Dead` arrastra la cadera 1,3 alturas, normal en una muerte. **Para el Juego:** `pj.jugar("attack")` dispara y `pj.jugar("walk_back")` retrocede; `ArcheryShot` dura 5 s, hay que cortarlo al soltar la flecha. Sin comprobar a ojo que `Walk002` sea hacia atrás (se ve andar con la mano a la cara) ni que haya arco en las manos (hay carcaj; el arco no está en el GLB).

- **2026-10-06 (17:10) · Pipeline** · **Arco del arquero integrado** (`Meshy_AI_Tribal_Bow_and_Arrow`, una sola malla de 13,8 k triángulos con arco y flecha). Partida por piezas conexas en `poc_25d/equipo/arco.glb` (empuñe en el origen, limbos en +Y, cuerda en +X, 0,78 de alto) y `flecha.glb` (punta en +Y, 0,6 de largo), con la textura a 1024 (1 MB y 0,7 MB). `Equipo3D.EQUIPO["goblin_archer_chibi"]` cuelga el arco de **`RightHand`** (rot 0,0,-90; en `ArcheryShot` esa es la mano que lo sostiene estirada y la cuerda queda del lado del arquero). Comprobado en render por script con el clip de disparo. **Para el Juego:** `Pj3D` equipa el arco solo al cargar `goblin_archer_chibi`; `Equipo3D.pieza("flecha")` da la flecha (suelta, centrada, punta +Y) por si queréis un proyectil con modelo en vez de la forma de código. No se ha tocado nada vuestro. Pendiente de mirar en movimiento (andar/correr con el arco en la mano).

- **2026-10-06 (17:20) · Juego** · **El agua no apagaba la barrera de fuego: `lanzador_3d.gd` y `jugador_3d.gd` del repo habían vuelto a la versión anterior** (sin `colocar_barreras` ni `BarreraFuego`; el `combate_3d.gd` con la IA del arquero sí estaba). Vuelvo a ponerlas, con un cambio más: **el agua salpica y apaga también las casillas de fuego pegadas** (una flecha abre un hueco de hasta 3 casillas). Probado en headless: desde las filas 6, 9 y 10 la flecha de agua llega y apaga; las filas 7 y 8 quedan tapadas desde el oeste por la caja de tierra empujable (12,7) y un objeto del decorado en (11,8), así que hay que apuntar a las otras o empujar la tierra. Si vuelve a pasar que los ficheros del Juego retroceden, avisadme: no es cosa mía. `PruebaJugabilidad3D` no se ha tocado. — Juego

- **2026-10-06 (18:00) · Juego** · **Colisiones que no se ven (revisión de todo `PruebaJugabilidad3D`).** Cruzado cada casilla de `_bloqueadas` con el tamaño real del modelo (los .glb de `meshy/`): (1) **el puesto**: `poner_puesto` bloquea `c` y `c+1`, pero el modelo (3,5 x 3,2 u) está centrado en `c` y solo cubre 1,5 casillas: sobran ~1,7 u de pared invisible a su derecha (casillas (3,6) y (3,9)); (2) **objetos pequeños que bloquean la casilla entera (2,3 u)**: barriles (0,9–1,2 u), cajas (1,0), cartel (1,6), tocones, troncos: ocupan el 16–60 % de la casilla; (3) paredes `#`: árboles de 4–6 u, sin problema; (4) el resto (rocas, setos, tótem, fogatas) cubre su casilla. Las casillas libres se cruzan todas entre sí (0 pasos rechazados).
  **Arreglo (solo del jugador, en mis ficheros):** `Lanzador3D.calcular_huellas()` saca de `_lotes` y `_plantilla` el círculo real de cada objeto; en una casilla bloqueada el jugador solo choca dentro de ese círculo + 0,3 de cuerpo (`Jugador3D._puede_estar`). Telaraña, barrera de fuego, puente, paredes y todo lo sin huella siguen enteros; los hechizos y los goblins siguen usando la casilla entera. **Petición al Pipeline (opcional, mejor arreglo de raíz):** en `poner_puesto`, centrar el modelo entre `c` y `c+1` (`+ Vector3(S*0.5, 0, 0)`) o bloquear solo `c`.
  **Nuevo: F10** (en `playlog_3d.gd`) dibuja lo que bloquea alrededor del jugador: rojo = casilla bloqueada, naranja = hierba crecida (sólida), violeta = tierra o columna, azul = agua, cian = hielo. Sirve para ver de un vistazo cualquier pared invisible. La hierba crecida por el agua es sólida (regla del 2D) y puede ser lo que se ve como "pared" en medio de la hierba. — Juego

- **2026-10-06 (18:15) · Juego** · **Cambio mío en `prueba_test2.gd` (Pipeline), una línea, a petición de Pablo ("otra colisión"):** en `_colocar_letras`, caso `"#"`, `elif h % 4 != 3:` pasa a `else:`. Antes 1 de cada 4 casillas de pared (`#`) no recibía árbol, pero seguía en `_bloqueadas`: un hueco entre dos árboles que parecía paso y era pared invisible (p. ej. (3,11), (11,11), (15,11), (7,11) en la pared sur de la sala norte y varias del borde). Ahora todas llevan árbol (o arbusto/roca como antes). Comprobado con F10 y render: el hueco de (11,11) queda tapado. Afecta también a PruebaTest2 (misma regla). Si el Pipeline prefiere dejar huecos reales, que los marque con otra letra y no con `#`. — Juego

### 2026-10-06 19:05 · Juego · barrera = forma "muro" con su duración real
Respuesta a la petición de Pipeline. Cambios en `lanzador_3d.gd` (mío):
- `Receta3D.forma()`: toda barrera con `spread` (salvo la columna con altura) devuelve `"muro"`; ya no se devuelve `"corro"` (la barrera quieta pasa a `"muro"`, y con ello `cast_muro` al lanzar).
- `_visual_campo`: barrera quieta o móvil llama a `fx.lanzar_forma("muro", ...)` con `dura = receta.vida()` (antes 0,9 s fijos; ya sin tope de 3 s). Dirección del muro: la del campo si es móvil; si es quieto, de lanzador a centro (o +Z si coinciden).
- La columna de tierra sigue dibujándose casilla a casilla con `"columna"`.

- **2026-10-06 (19:10) · Pipeline** · **Círculo de transparencia del jugador + toldo del puesto recortado (petición de Pablo).** (1) **Nuevo `poc_25d/ocluso_3d.gd` (`Ocluso3D`)**: lo que queda entre la cámara y el jugador (árboles, setos, puesto…) se vuelve translúcido en un círculo de pantalla de 1,9 m de radio centrado en él, con descarte en trama (dither) y sin mezcla alfa. Se aplica a los **lotes** del decorado y a los **Reactivo3D** (`objetos_3d.gd` convierte su copia de material y tinta/enciende con `Ocluso3D.poner_color` / `poner_emision`, que valen para los dos tipos de material). **No** se aplica a personajes, VFX, suelo ni hierba. Se apaga con `transparencia_jugador = false` o `radio_transparencia`; solo actúa con `decorado_por_lotes` (el prerender 2D queda igual). Un solo parámetro de shader global (`oc_jugador`) que `_process` de `prueba_test2.gd` actualiza con la posición del jugador (`_jugador.position`), así que vale también con `externo = true`. (2) **El toldo del puesto de mercado tapaba al tendero** desde la cámara del juego: `Ocluso3D.recortar_toldo` quita de la malla la mitad delantera del techo (queda una tira trasera); `recortar_toldo = false` lo deja entero. Probado en una escena aparte con cámara ortogonal a 50° (compatibilidad); **sin F6 en la maqueta completa ni medida de rendimiento** (el shader añade ~1 cálculo de distancia por píxel solo en el decorado). Juego: **no hace falta tocar nada**; `Lanzador3D.calcular_huellas()` lee `_plantilla` como antes (la malla del puesto es ahora la recortada, su caja casi no cambia). Sobre vuestra petición del puesto (centrarlo entre `c` y `c+1`): no la he aplicado todavía. — Pipeline

- **2026-10-06 (19:30) · Pipeline** · **INSTRUCCIONES PARA EL JUEGO: formas y VFX de los hechizos (anillo de fuego y el resto).** Pablo las pide ya. Nuevo en `vfx_3d.gd`: **`"corro"` es ahora un ANILLO CERRADO de pared del elemento** (de 8 a 18 tramos sobre la circunferencia, interior libre, sin el círculo plano del suelo; la referencia `fire_ring`). Todas las formas son `Vfx3D.lanzar_forma(forma, elemento, pie_origen, pie_destino, opciones)` y **solo dibujan**: no emiten `impacto` ni colisionan; eso es del Lanzador. Hoy hacéis `muro` para toda barrera con `spread` y "el corro ya no se usa": **hay que recuperarlo para el área sin barrera**. Tabla:
  1. **Proyectil** (vuela): `fx.lanzar(elemento, pie_a, pie_b)` con los pies reales de origen y destino. El VFX (llama, gota, remolino, cristal) ya va girado 90° con la punta en la dirección de vuelo; no hay que girar nada. La flecha del arquero lleva el elemento igual: pasadle el vector real lanzador→objetivo, no `Vector3.ZERO`. Si queréis el modelo de la flecha: `Equipo3D.pieza("flecha")` (punta +Y, centrada).
  2. **Barrera / muro** (quieto o móvil): `lanzar_forma("muro", el, pie_c - d, pie_c, {"radio": clampf(radio, 0.6, 3.0), "dura": receta.vida()})`, con `d` = dirección del campo (móvil) o lanzador→centro (quieto). La pared mide `radio*2 + 0,6` de largo, es PERPENDICULAR a `d` y queda 0,2 por delante de `pie_c - d`. Ya lo tenéis así. La forma depende del elemento (fuego = lenguas, agua = ola, tierra = bloques pegados, viento = lámina, rayo = zigzag, hielo = cristales).
  3. **Corro / área con `spread` SIN barrera** (el "anillo de fuego"): `lanzar_forma("corro", el, pie_o, pie_c, {"radio": clampf(radio, 0.6, 3.5), "dura": minf(receta.vida(), 3.0)})`. `radio` = radio real del campo en METROS (el máximo de `c3.puntos` al centro, como ya calculáis); el anillo cae justo sobre esa circunferencia. En `Receta3D.forma()` poned `"corro"` para `spread` que NO sea barrera, y `"muro"` solo si lo es. Colisión/daño: hacedlo en el ANILLO (casillas a distancia ≈ radio ± 0,5 casilla del centro), no en el disco entero, para que lo que se ve coincida con lo que quema; el interior está libre.
  4. **Columna** (una manifestación alta): `lanzar_forma("columna", el, pie_c, pie_c, {"dura": minf(duracion, 3.0)})`, una llamada por casilla, como ya hacéis.
  5. **Barrera de fuego del mapa (letra "B")**: ya la hace `prueba_test2.gd` con `_fx.fuego_fijo(p, true, 1.0, eje, S)` y el eje de las "B" vecinas (BACK si hay "B" arriba o abajo, RIGHT si no); cuelga como hijo directo de `Vfx3D` llamado "fuego_fijo", así que `BarreraFuego` sigue encontrándola por posición y `fx.apagar(llama)` la apaga igual (oculta MeshInstance3D y OmniLight3D).
  6. **Tierra real** (`construir_tierra`, hoy una caja marrón): opcional, para que se parezca al muro: dejad la caja como COLISIÓN invisible y dibujad encima `lanzar_forma("muro", "tierra", ...)`. Pablo no lo ha pedido todavía; preguntadle antes.
  **Rendimiento:** el corro son hasta 18 mallas pero solo 1 de cada 4 lleva luz y partículas; el muro lleva 1 luz y 1 emisor. No lancéis varios corros a la vez sin necesidad. **Animación del lanzador:** `Pj3D.jugar("cast", true)` y esperad `duracion("cast")` si queréis que el VFX salga al final del gesto. **Arquero y guerrero** (pendiente de antes): mientras dure el clip de ataque, ni se mueven ni piden otra animación; el arquero suelta la flecha en `Pj3D.duracion("attack") * Pj3D.momento_golpe("attack")` (para el arquero ≈ 0,84 del clip de 5 s); el guerrero espera `duracion("attack")` antes de volver a andar hacia el jugador. Probado solo en una escena de prueba (compatibilidad); sin F6 en la maqueta. — Pipeline

### 2026-10-06 19:30 · Juego · formas según la tabla de Pipeline (corro, muro, tierra) — sustituye a la entrada de las 19:05
Cambios en `lanzador_3d.gd` (mío):
- `Receta3D.forma()`: `"muro"` solo para la barrera que avanza (barrera + flecha); `"corro"` para el área quieta (barrera sola, pulso). Columna y onda como antes. Se recupera `"corro"`.
- `_visual_campo`: muro → `lanzar_forma("muro", ..., {radio, dura = receta.vida()})`; quieto → `lanzar_forma("corro", el, pie_o, pie_c, {radio (m, máx. de los puntos al centro, tope 3,5), dura = min(vida, 3 s)})`. Daño/colisión ya van solo por los puntos del aro (el interior está libre).
- **Tierra**: el anillo de tierra dura `DURACION_TIERRA` (25 s) en vez de 3 s, y los bloques (`construir_tierra(c, dibujar=false)`) quedan como colisión invisible bajo el anillo (punto 6 de Pipeline; Pablo lo pide ahora con `stone_ring`). La caja marrón sigue visible cuando se construye tierra de otra forma.
- Proyectil: ya llamaba a `fx.lanzar` con los pies reales (`y_pies` de origen y destino de cada tramo), sin girar nada. La flecha del goblin arquero sigue siendo una caja que vuela (no lleva elemento).
- Flecha y barrera nacen siempre en el jugador (`origin = 0` si `travels` o `spread`), y arquero/guerrero esperan al clip de ataque (ver entradas anteriores).
- Límite conocido: con repetición salen aros concéntricos y el `corro` se dibuja solo con el radio del mayor.

### 2026-10-06 18:55 · Juego · goblins: animación de ataque completa (`combate_3d.gd`)
Guerrero y arquero quedan bloqueados (`_ataque`) durante `pj.duracion("attack") / velocidad` (no andan, no giran, no piden otra animación); se cancela con golpe, parálisis, hielo o muerte (`_ataque_id` descarta el golpe/flecha pendiente). Clip con `jugar("attack", true)`. Arquero ×1,25 (5 s → 4 s, flecha a los 3,36 s = `momento_golpe` 0,84); guerrero ×1,0 (3,21 s, golpe a 0,19). Constantes arriba de `combate_3d.gd`. Evento PlayLog `goblin_ataca`. Nota para Pipeline: en ArcheryShot no se ve arco y casi todo el clip (0-3,8 s) es estático.

### 2026-10-06 19:15 · Juego · flecha y barrera nacen siempre en el jugador
`lanzador_3d.gd`: tras `apply`, si `travels` o `spread` → `receta.origin = 0.0`. El glifo "lejos" ya no las desplaza.

### 2026-10-06 21:00 · Pablo (vía Juego) · referencias de animación para los VFX de 5.10
Pablo ha dejado varias animaciones de **lanzallamas, muros y barreras** como referencia de cómo deben verse los VFX de la matriz 5.10 (Pipeline). Y el **pulso debe seguir la animación `fire ring`**: aro que nace en el jugador y se expande, no un corro quieto; así el pulso (empuja) y la barrera (protege, anillo fijo) se distinguen a primera vista. Anotado en `PLAN_ARREGLOS.md` 5.10/5.11 y en `DISENO_FUTURO.md` §3. Están en `poc_25d/vfx/referencias/` (renombradas: `barrera_fuego`, `barrera_rayo`, `muro_fuego`, `lanzallamas_fuego`, `propagacion_fuego`; `LEEME.md` dice qué enseña cada una; `.gdignore` para Godot y excepción en `.gitignore` para que viajen). Falta `pulso_fuego.mp4` (la `fire ring`): Pablo la añade. Los originales siguen en `tools/` hasta que Pablo los borre. — Juego

- **2026-10-06 (21:00) · Juego** · **Fase 5 del `PLAN_ARREGLOS.md`: hechas 5.1, 5.2, 5.3 y 5.8; 5.4–5.7 pendientes (ver abajo).** Cambios en `lanzador_3d.gd` y `jugador_3d.gd` (míos), probados en headless (el nivel carga; abrir/cerrar el libro deja `time_scale` en 0,3 y luego 1,0); sin F6.
  - **5.1 El origen es siempre el jugador.** `_actualizar_puntero` ya no mueve el origen: el ratón da solo la dirección. El anillo de `ALCANCE_ORIGEN` (3 casillas) se sigue dibujando como referencia; el alcance de viaje de la flecha sigue siendo `ALCANCE_FLECHA` = 8 casillas (5.1 dice "3 casillas": **pregunta para Pablo**, ¿se baja a 3?).
  - **5.2 Tiempo del libro.** Constantes `TIEMPO_LIBRO = 0.3` y `TIEMPO_LANZAR = 0.3` (`RALENTIZADO` es ahora igual a la segunda). `spellbook.gd` (de Pablo, no tocado) sigue haciendo `get_tree().paused = true` al abrir; `Lanzador3D` lo deshace cada fotograma mientras el libro esté abierto (`process_mode = ALWAYS`; con pausa real —muerte, victoria— no hace nada) y pone `Engine.time_scale = 0.3`; al cerrar, lo restaura antes de entrar en modo lanzar. Con el libro abierto el jugador no se mueve (`Jugador3D` mira `lanz.libro_abierto()`); los goblins sí, lentos. Propuesta para Pablo: cuando quiera, que `spellbook.gd` deje de pausar y se quite este parche.
  - **5.3 Altura: un nivel.** `MAX_NIVELES_SUBIBLES = 1`, `MAX_TIERRA_APILADA = 1`, la columna de barrera + levitación es de 1 nivel. `ESTADOS_SUELO.md` y `DISENO_FUTURO.md` §0b siguen hablando de dos niveles: lo actualizo cuando Pablo confirme.
  - **5.8 Contrato VFX v2.** Lo que el Lanzador pasará a `Vfx3D.lanzar_forma(forma, elemento, pie_origen, pie_destino, opciones)` cuando exista 5.4 (todas solo dibujan; la colisión es del Lanzador). `bola` (= `lanzar` actual): `radio` m. `corro`: `radio` (m), `dura` ≤ 3 s (tierra: 25 s). `pilar`: delante del jugador, `altura` en niveles (1), `dura` = vida del campo. `muro`: `radio` = semilargo (m), `dura` = vida, dirección = `pie_destino - pie_origen`; el de hielo y tierra es sólido (bloque) y los demás, fluido. `onda`: `radio` final (m), `dura` ≤ 2 s, expandiéndose desde el jugador. `chorro` (lanzallamas): `largo` (m), `direccion`, `dura` = vida (se mantiene). `acompanante`: pegado al jugador, `dura` = vida, sin colisión. Hoy existen `proyectil`, `corro`, `columna` y `muro`: faltan `pilar`, `onda`, `chorro` y `acompanante`.
  - **No hecho: 5.4 (glifos v2), 5.5, 5.6, 5.7.** 5.4 toca `sigils.gd` y `spell_recipe.gd` (de Pablo) y pide un glifo nuevo, `linea`, con gesto grabado. Lo dejo hasta que Pablo diga si lo hago como propuesta (archivo aparte) o si lo integra él; 5.5–5.7 dependen de 5.4. El plan (`PLAN_ARREGLOS.md`) no lo marco: es de Pablo.

- **2026-10-06 (21:25) · Juego** · **Aviso:** los cambios de las 21:00 (5.1–5.3 y 5.8) habían desaparecido del disco a las 21:11 (`lanzador_3d.gd` y `jugador_3d.gd` volvieron a la versión de las 19:30, y esta entrada también). Los he vuelto a escribir. Es otra vez el editor de scripts de Godot: **cerrad las pestañas de `lanzador_3d.gd`, `jugador_3d.gd` y `combate_3d.gd` en Godot** o volverá a pasar. Todo lo de 5.1 que el plan marca "a medias" está ya incluido: origen = jugador siempre, 5.2 con `TIEMPO_LIBRO`/`TIEMPO_LANZAR` = 0,3, 5.3 con 1 nivel.

- **2026-10-06 (21:50) · Juego** · **Barrera estática = `cupula`** (respuesta a Pipeline 21:40; esta entrada se había perdido al guardar). `lanzador_3d.gd`, `_visual_campo`: la barrera quieta llama a `lanzar_forma("cupula", elemento, pie_o, pie_c, {radio (m, 0,6–3,5), dura = vida del campo})`. Siguen con `corro`: la **tierra** (anillo de piedra, petición de Pablo; sus bloques son colisión invisible) y el pulso/onda (aro que se abre). `muro` = barrera + flecha. `Receta3D.forma()` devuelve `"corro"` para la barrera quieta (nombre que usa la animación de lanzar de `Pj3D`); si queréis otro clip para la cúpula, decídmelo. Sobre 5.8: vale que `pilar` ignore `altura` y que `chorro` use `pie_destino - pie_origen`. (Nota: la entrada de Pipeline de las 21:40 desapareció del diario en algún guardado: **Pipeline, revisad que sigue ahí**.)
- **2026-10-06 (22:00) · Juego** · **5.4, primera parte: glifo `linea` (muro delante) en `Receta3D`.** Hecho sin tocar archivos de Pablo: `Receta3D.apply("linea")` activa `line` (+ `spread` + `blocks`, recarga 2,0 s, varias líneas ensanchan el muro como varias barreras) y `_spread_points` pone una fila perpendicular a la mirada a 1,5 casillas. `forma()` devuelve `"muro"`; el visual usa `lanzar_forma("muro", ...)` con `dura = vida` y la dirección lanzador→centro. Con flecha sale el muro que avanza de siempre; la tierra deja bloques sólidos (colisión) con el muro de piedra dibujado. Probado en headless sin el glifo en el libro (`linea` → 3 casillas; `linea+barrera` → 5; `linea+linea` → 5; `barrera` sola sigue en anillo de 8). **Faltan, y no son míos**: (a) `Sigils.FORM["linea"]` para que el libro la acepte: propuesta exacta, en `sigils.gd` junto a `"barrera"`: `"linea": {"spread": true, "blocks": true, "cooldown": 2.0},` y `GLYPHS["linea"]` cuando haya icono; (b) plantilla del gesto en `gesture_library.tres` (Pablo, una raya horizontal) e icono `assets/ui/glyphs/linea.png` (Pipeline). **Pendiente del Juego en 5.4:** `flecha` como desplazamiento con duración, `barrera` como redondez, `levitacion` estática, `pulso` como empuje y el chorro (`linea + levitacion`); cambian el significado de los glifos que Pablo ya juega, así que los hago cuando confirme el playtest de lo anterior (5.14) y la pregunta del alcance (¿flecha a 3 casillas?).

### 2026-10-07 09:45 · Pablo (vía Juego) · Fase 6 en `PLAN_ARREGLOS.md`: playtest largo del 7/10
Pablo jugó `PruebaJugabilidad3D` y dejó `Magic_Symbols_Playtest 071026.docx` (hoy en la copia de OneDrive; se copia a `docs/Playtests/`). Cada punto del documento es ya una tarea con dueño en la **fase 6** del plan. Lo más urgente, por dueño:
- **Juego (6.1–6.9):** `linea`/`pulso` por el libro y aviso para grabar plantillas; cadena de casteo T → `readandwrite` sostenido mientras se apunta → `cast` al soltar; **barrera que dura más, sigue al jugador y para golpes y flechas** (la queja más repetida); `tierra + barrera` = esfera de tierra y `barrera + pulso` = anillo que crece (el `stone_ring` actual pasa al pulso); bola pequeña por elemento (`fuego + flecha` sale como gota gigante; `rayo + flecha` = bola eléctrica); voltereta (`roll_dodge`, ≤ 1 casilla, 4 s), beber poción (1,5 s bloqueado), nadar flotando; fuego solo a casillas pegadas; **medir el retardo de reconocimiento** de sellos/glifos.
- **Pipeline (6.10–6.20):** **propuesta de nivel editable** (bloques → `.tscn` horneado o paleta de piezas, colisión por malla; Pablo decide, no se programa antes); libro en manos + `readandwrite` en bucle; clips `walk02` en el andar, `roll_dodge`, `stand_drink` con poción al 50 % en la mano; arquero bloqueado en el fotograma de brazos extendidos y arco +20 %; hierba con más masa y **sin mancha negra** al quemarse; una lengua en antorchas; agua a ras, orilla, pulido del hielo; **VFX del pulso que crece** (4 fotogramas del playtest, `anillo_fuego.glb`) y sólidos que se rompen; bola por elemento; esfera de tierra; tocón, arbusto, puesto, señal; iconos nuevos (`flecha` = `<`, `linea` = `|`, `hielo` = `X`, `pulso` = dos semicírculos).
- **Pablo (6.0, 6.21–6.24):** copiar el docx al repo, decidir la estructura (6.10) y la hierba crecida sólida o no (6.22), grabar plantillas, fijar el símbolo de levitación (en el docx está repetido el de flecha). — Juego

### 2026-10-07 09:50 · Pablo (vía Juego) · decisiones sobre la fase 6 + AVISO de archivos que retroceden
Pablo confirma: **6.0 hecho** (docx en `docs/Playtests/`); **6.21 validado** (símbolos `<` flecha, `|` línea, `X` hielo, dos semicírculos pulso; levitación pendiente de fijar); **6.22 → opción (a)**: la hierba crecida **deja de ser sólida** en 3D (Juego, 6.22a); **6.23**: el tiempo al 30 % se siente bien, no se ajusta, cadena de casteo confirmada; **6.24 validado** (`rayo + flecha` = bola eléctrica; rayo que cae = `rayo + levitación + barrera`, corto). Todo lo demás de la fase 6 confirmado tal cual: Juego y Pipeline pueden empezar.
**AVISO:** a las 09:37 `PLAN_ARREGLOS.md` y `DIARIO.md` volvieron en disco a la versión de ayer 21:15 (el diario perdió las entradas del Juego de 21:00–22:00 y la fase 6). Los he restaurado de mi copia. Los `.gd` de `poc_25d` no se tocaron. Quien escriba el diario: **leedlo del disco justo antes y añadid al final**; no lo reescribáis desde una copia vieja. — Juego
- **2026-10-07 (09:50, añadido)** · Símbolo de **levitación = `^`** (el ángulo de flecha con la punta arriba; flecha sigue valiendo `<` y `>`). Pipeline: icono `levitacion.png` en 6.20(e). Pablo: al grabar, comprobar con `podar_gestos.py` que `^` no cae dentro del margen de `<`/`>`. — Juego

### 2026-10-07 10:20 · Pipeline · 6.10 PROPUESTA: del mapa de bloques a un nivel editable (decide Pablo; no se programa nada hasta entonces)
**Punto de partida (medido en el código).** `prueba_test2.gd` (2296 líneas) lee el mapa de letras (`_mapa()`) y construye todo: suelo por casillas, lotes de decorado (`MultiMesh`), árboles en cada `#`, objetos, hierba. La solidez **no es física**: es el diccionario `_bloqueadas` (casilla → true) que consultan el Lanzador, el jugador y los goblins; el Lanzador añade «huellas» (`calcular_huellas`) con círculos por pieza para que una casilla no sea siempre entera. Por eso: (1) el puesto bloquea una casilla de más (la caja roja del playtest), (2) la hierba crecida bloquea al azar, (3) no se puede mover una pieza sin tocar el mapa, (4) las piezas que no ocupan casilla entera tienen una huella aproximada.
**Lo que NO cambia en ninguna opción:** modelos y materiales (`Ocluso3D`, `Reactivo3D`, `Formas3D`, `Vfx3D`), el sistema de estados del suelo (agua/hielo/fuego/tierra) y la lógica de hechizos: solo cambia **de dónde salen** las piezas y **cómo se decide qué bloquea**.

**Camino A — «hornear»: el mapa de letras sigue siendo la fuente, y `prueba_test2` lo convierte una vez en un `.tscn` editable.**
- Un script de editor (`@tool`, una vez por cambio de mapa) recorre las letras y escribe un `Nivel_X.tscn` normal: un `Node3D` por pieza (instancia de su escena), con `Transform3D` (posición y giro libres), un `StaticBody3D` + colisión **de la propia malla** (`create_convex_shape` para rocas, árboles, puesto, tocón; `create_trimesh_shape` para estáticos grandes como puentes), suelo como un `GridMap` o un plano por zona. Pablo abre el `.tscn`, mueve, gira, borra, añade.
- El juego **carga el `.tscn`** y rellena `_bloqueadas` y los estados del suelo **a partir de los nodos** (grupo `bloquea`, grupo `reactivo`), no de las letras. Se mantiene un modo «regenerar desde letras» para volver a empezar.
- **Coste (mío, Pipeline):** hornear + escenas de pieza + colisión por malla + generador del `.tscn`: **~2–3 días**. **Coste (Juego):** cambiar `_bloqueadas`, `calcular_huellas`, `jugabilidad_3d`, los goblins y el lanzador para leer nodos/colisiones en vez de casillas: **~2–3 días** y es la parte que más duele (hoy todo pregunta «¿casilla bloqueada?»; habría que dejar esa pregunta como una función que consulta el mundo físico). **Riesgos:** dos fuentes de verdad si Pablo edita el `.tscn` y luego alguien regenera desde letras (hay que decidir que, a partir de hoy, el `.tscn` manda y el mapa de letras se archiva); los `MultiMesh` de decorado se pierden como lotes (un nodo por árbol: ~600 nodos en el Test 2; vale en UHD 620 si se vuelve a agrupar al hornear, `MultiMeshInstance3D` por tipo, con la colisión aparte).
- **Qué gana Pablo:** lo mismo que pide, ya en una semana corta, con poco riesgo para lo jugado.

**Camino B — nivel a mano desde cero con paleta de piezas + `GridMap` solo para el suelo.**
- Cada pieza validada pasa a ser una **escena** (`pieza_arbol.tscn`, `pieza_puesto.tscn`, `pieza_roca_grande.tscn`…) con su colisión de malla ya puesta, su ancla en la base y sus metadatos (`bloquea`, `reactivo`, `inflamable`…). Pablo construye el nivel **arrastrando** escenas al editor (o desde una paleta tipo `GridMap`/`MeshLibrary` para el suelo) y las gira libremente. Nada de letras.
- El estado del suelo (agua, hielo, fuego, hierba) sigue siendo por **casilla lógica**, pero la rejilla se **deduce de la geometría** al cargar (un `GridMap` de suelo con tipos de bloque + lo que digan las piezas), no se dibuja desde letras.
- **Coste (mío):** convertir ~40 piezas del catálogo a escenas con colisión y metadatos, `GridMap`/`MeshLibrary` de suelo, un cargador de nivel y un par de herramientas de editor: **~4–6 días**. **Coste (Juego):** igual que A (~2–3 días) **más** reescribir la lógica que hoy nace de las letras: spawners de goblins, puerta, baldosas de contacto, NPC (`K`, `S`, `E`…): pasarían a nodos con marcadores: **~+2 días**. **Riesgos:** más trabajo antes de poder jugar de nuevo un nivel entero; hay que rehacer a mano el Test 2 (o escribir el conversor de A igualmente, para no perderlo).
- **Qué gana Pablo:** el flujo más limpio a largo plazo (los niveles son escenas; control total; mapas más grandes sin 2296 líneas de constructor) y quita de raíz la dependencia de las letras.

**Colisión por malla real (vale para A y B).** Se pone en cada pieza: `convex` para lo redondeado y compacto (árbol: solo el tronco, no la copa; roca; tocón; puesto: el volumen de la mesa, no el toldo), `trimesh` solo para estáticos grandes que se recorren (puente, pasarela), y `Area3D` sin cuerpo para lo que no debe bloquear (hierba, telaraña = ralentiza). Con eso desaparecen las colisiones fantasma del puesto y de la hierba: **lo que se ve es lo que choca**. Coste extra de física en la UHD 620: bajo (~600 convexos estáticos son baratos; lo caro sería `trimesh` dinámico, que no se usa).

**Mi recomendación.** **Camino A primero** (menos riesgo, 1 semana, ya sirve a Pablo para montar niveles), con las piezas ya como escenas; eso **es** el 70 % del camino B, así que migrar luego a B no se tira nada. Si Pablo ya sabe que el Test 2 se archiva, B directo sale ~2 días más caro pero ahorra un cambio de mundo después.
**Preguntas para Pablo:** (1) ¿A o B? (2) ¿el mapa de letras se archiva tras hornear? (3) ¿la rejilla lógica sigue siendo de casillas de 2,3 u o se admiten piezas girables a cualquier ángulo (la rejilla seguiría para estados del suelo, pero el bloqueo sería por colisión real)? (4) ¿la hierba crecida sin colisión (6.22a, ya decidido) se quedaría como `Area3D`, sí? Mientras decide, sigo con 6.11 → 6.20 sobre el sistema actual: **todo vale igual en A, en B o con bloques**.

### 2026-10-07 10:05 · Juego · fase 6: 6.1–6.9 (menos el arreglo de 6.9) + peticiones
**Hecho (probado en headless; en pantalla falta tu ojo, Pablo):**
- **6.1** `pulso` ya funcionaba; `linea` está implementada en `Receta3D` (muro estático 1,5 casillas delante). **Pablo, falta de tu lado:** en `sigils.gd` añadir `"linea": {"spread": true, "blocks": true, "cooldown": 2.0},` en `FORM` (+ `GLYPHS["linea"]` cuando exista el icono) y **grabar las plantillas** (6.21: `<`, `|`, `X`, pulso = dos semicírculos, `^` levitación) para poder jugar 5.14.
- **6.2** Cadena de casteo: `apuntar_lanzar()` mantiene el clip `leer` (el libro, `readandwrite`) mientras se apunta; `lanzar_clip()` reproduce `cast` al soltar. Sin cambios de API.
- **6.3** Barrera quieta = cúpula que **sigue al jugador**, dura más (`MULT_VIDA_BARRERA` 2×, mín. 6 s) y tiene **escudo 60**: `Jugador3D.recibir_dano` llama a `Lanzador3D.absorber_golpe(cantidad, desde)`; si lo absorbe no hay daño ("Bloqueado"/"Rota", evento `barrera_absorbe`). Medido: 3 golpes de 20 absorbidos, el 4º pasa.
- **6.4** `tierra + barrera` = cúpula de tierra (sin bloques de colisión); `barrera + pulso` = corro que crece (`T_CRECE` 0,9 s).
- **6.5** Flecha = bola pequeña (`RADIO_BOLA` 0,25 m), `ALCANCE_FLECHA` 3 casillas; `rayo + flecha` = bola eléctrica (se acabó el haz de 8). Velocidad por elemento a partir de `fx.velocidad` (rayo ×2, tierra ×0,8). Tabla §3 de `DISENO_FUTURO.md` actualizada (fila flecha; edición parcial autorizada).
- **6.22a** La hierba crecida **ya no bloquea** en `Lanzador3D.pisable` (una regla quitada). **Pipeline:** `prueba_test2.gd:2235` (y el comentario "pasa a bloquear" de la línea ~1838) conserva la regla vieja para lo suyo; revisadla.
- **6.6 Voltereta** (Ctrl): ≤1 casilla en 0,35–1 s según el clip `roll`, avanza con `_puede_estar` paso a paso y se corta si choca, i-frames mientras dura, reutilización `TIEMPO_VOLTERETA` = 4 s, evento `voltereta`. Medido: 2,29 m (casilla 2,3), golpe en i-frames = 0 daño. Solo Ctrl por ahora: el botón derecho lo dejo hasta saber si el libro/apuntar lo usa.
- **6.7 Beber** (Q): `drink` 1,5 s con el jugador quieto y sin lanzar, cura `CURA_POCION` = 40 al terminar y gasta la poción; un golpe interrumpe y no cura (probado). Solo con vida < máx. y poción en la mochila.
- **6.8 Nadar:** `HUNDIDO` = 0,35 (pies a `ALTO_AGUA − 0,35`). No verificado con la cámara del juego: **Pablo, mira si flota bien**; el valor es una constante en `jugador_3d.gd`.

**6.9 (b) MEDIDO, sin tocar nada:** el retardo del reconocimiento NO es el $P ni un `await`: es `GESTURE_PAUSE` = 0,75 s en `spellbook.gd` (espera tras el último trazo para ver si sigues dibujando), y `gesture_countdown` resta `delta` de `_process`, que **se escala con `Engine.time_scale`**. Con el libro abierto el tiempo va al 30 %, así que esa pausa dura **2,5 s reales** (medido: 0,75 s de delta → 2498 ms). **Propuesta para `spellbook.gd` (de Pablo):** en `_process`, `gesture_countdown -= delta / maxf(Engine.time_scale, 0.01)` (la pausa pasa a durar 0,75 s reales) y, si sigue pareciendo larga, bajar `GESTURE_PAUSE` a ~0,5.
**6.9 (a) Fuego en hierba:** esa lógica vive en `prueba_test2.gd` (~1960–1985: el bucle de 8 vecinos con radio `fr`), archivo del Pipeline. Cambio pedido: solo las 4 vecinas `Vector2i(±1,0)`, `(0,±1)` (quitar las 4 diagonales) y un retardo de 0,6 s por salto (`PRENDIENDO` → `ARDIENDO` espera 0,6 s antes de contagiar). No lo toco.

**Peticiones al Pipeline (firma exacta):**
1. `Vfx3D.lanzar_forma("corro", el, a, b, {"radio": float, "dura": float, "crece": true, "t_crece": float, "rompe": bool})` → anillo que **crece** de 0 a `radio` en `t_crece` s; `rompe` = true para tierra/hielo (6.17). El Juego ya lo pasa.
2. `lanzar_forma("cupula", ..., {"radio", "dura", "rompe": bool})` honrando `rompe` (6.19). Opcional: que devuelva el `Node3D` raíz para emparentarlo al jugador (hoy lo busco como hijo nuevo de `fx`).
3. `lanzar_forma("bola", el, a, b, {"radio": 0.25})`: **la forma "bola" debe respetar `radio`** (hoy llama a `lanzar` e ignora las opciones) y el rayo debe verse como bola eléctrica (6.18).
4. `Pj3D.equipar(nombre: String) -> void` (`"pocion"`) y `Pj3D.desequipar() -> void` (6.12). El Juego ya los llama con `has_method`, así que no rompe si aún no existen.
Archivos tocados: `poc_25d/lanzador_3d.gd`, `poc_25d/jugador_3d.gd`, `docs/DISENO_FUTURO.md` (tabla §3, una fila). — Juego

### 2026-10-07 11:30 · Pipeline · Entrega 6.11–6.19 (+ parte de 6.20)
**Archivos (todos del Pipeline):** `pj_3d.gd`, `equipo_3d.gd`, `vfx_3d.gd`, `objetos_3d.gd`, `hierba_3d.gd`, `prueba_test2.gd`; PNG nuevos en `art/ui/glyphs/`; capturas en `docs/qa/vfx/` (`pulso_crece`, `bola_elementos`, `cupula_tierra`).

**API nueva / cambiada (firma exacta):**
- `Vfx3D.lanzar(elemento, pie_origen, pie_destino, radio: float = 0.22)` · bola por elemento (fuego con estela, bola eléctrica, gota, remolino, carámbano, piedra). `lanzar_forma("bola", …, {"radio": r})` ya lo respeta. Al llegar: tierra → impacto de piedras, rayo → impacto eléctrico.
- `lanzar_forma("onda"|"corro", el, a, b, {"crece": true, "radio": r, "dura": 1.6, "rompe": true})` · el anillo crece 0,5·dura, se sostiene 0,2·dura y luego los fluidos pasan a ceniza/humo y los sólidos (tierra, hielo) se rompen en fragmentos. `crece: false` mantiene la onda antigua. Fuego usa `anillo_fuego.glb`.
- `Vfx3D.apagar(n, opciones := {})` · `{"rompe": true}` rompe en trozos que caen hacia fuera.
- `lanzar_forma("cupula", …)` con tierra = hemisferio de piedras que sube y se rompe (`rompe`). Sigue sin devolver el nodo raíz.
- `Vfx3D.llamas(suelo, esc, radio, lenguas: int = 0)` · `lenguas > 0` fija el número; braseros y fogatas usan 1 (6.15).
- `Pj3D.apuntar()` / `cancelar_apuntar()` · libro en las manos + `readandwrite` en vaivén mientras se apunta (6.11). `lanzar()` y `soltar_lanzar()` guardan el libro (0,15 s).
- `Pj3D.giro_al_andar(grados: float)` · mezcla ~0,4 s de `walk02` si el giro > 35° y se anda/corre (6.12).
- `Pj3D.rodar() -> float` / `soltar_rodar()` · `roll` sin desplazamiento de cadera (el Juego mueve al nodo). Devuelve la duración.
- `signal bebida_terminada` · `Pj3D.beber(dur: float = 1.5) -> float` · `stand_drink` (tramo 2–6 s acelerado a `dur`) con la poción en la mano izquierda; al acabar desequipa y vuelve a idle.
- `Pj3D.equipar(pieza_id: String) -> Node3D` (`"pocion"`; devuelve null si no existe) y `Pj3D.desequipar(pieza_id: String = "")` (vacío = todas). Vale para la llamada sin argumentos que hace el Juego.
- `Pj3D.apuntar_clip(nombre := "attack") -> bool` / `soltar_apuntado(vel := 1.0)` · congela el clip del arquero en el fotograma de brazos extendidos (3,0 s del `attack`; tabla `FOTOGRAMA_APUNTADO`). Arco del goblin +20 % (escala `(1.2, 1.2, 2.2)`).

**Cambios sin API:** hierba más densa (`densidad` 5,0 · tarjetas 5,5 · alto 0,55); quemada = paja, sin negro, y sin colisión. Suelo: uniform `fuerza_ceniza = 0` (sin mancha negra). **`ALTO_AGUA = ALTO - 0.04`** (antes ALTO·0,6): agua a ras; **el Lanzador, la natación y el puente leen esta constante**, revisadlo. Orilla de arena + piedrecitas en cada casilla de tierra junto a agua. Hielo: placa translúcida con grietas y dos cristales (`_poner_placa_hielo`). Puesto 1,9 y señal 0,95.

**No probado (solo harness aislado, sin el juego real ni rendimiento en la UHD 620):** el flujo en el Juego de libro/apuntar/rodar/beber; `walk02` como giro en movimiento; si el fotograma 3,0 s del arquero coincide con el de Pablo (cambiar `FOTOGRAMA_APUNTADO` si no); orilla, placa de hielo y `ALTO_AGUA` dentro de `PruebaTest2` (el sandbox no compila el Lanzador); coste de las MultiMesh de orilla.

**6.20 pendiente de arte:** tocón (dos variantes), arbusto, puesto sin objetos, señal con texto: entradas en `ASSETS_PENDIENTES.md`. El puesto centrado entre `c` y `c+1` es de `_bloqueadas` (Juego). Iconos `<` `|` `X` `^` y dos semicírculos generados por código (primer pase). — Pipeline


### 2026-10-07 10:40 · Pipeline · `linea` no se ve en el libro y tinta más oscura (petición a Juego)
Pablo: "linea no se ve en el libro; me gustaría que las letras fueran negras". Causa, medida leyendo `sigils.gd` y `spellbook.gd`:
1. **`linea` (y `hielo`) no están en `Sigils.GLYPHS`** (`sigils.gd` ~102–113), así que el libro no tiene textura que pintar. El Pipeline ya entregó `art/ui/glyphs/linea.png` (`|`) y rehízo `flecha.png`, `hielo.png`, `pulso.png`, `levitacion.png`. Hace falta: `"linea": preload("res://art/ui/glyphs/linea.png")` y `"hielo": preload("res://art/ui/glyphs/hielo.png")` (ya existe).
2. **Tinta:** todos los PNG de `art/ui/glyphs/` son blancos y el libro los tiñe con `INK = Color(0.24, 0.19, 0.16)` (`spellbook.gd:42`), un marrón. Para negro, cambiar `INK` (y `INK_SOFT`, `INK_FAINT`, `LEGEND_FADED`, que repiten ese color) a algo como `Color(0.05, 0.04, 0.04)`. No pinto los PNG en negro: se teñirían a negro y los glifos de color (núcleo) dejarían de tomar el color del elemento.
Archivos que toca el Juego: `sigils.gd`, `spellbook.gd`. — Pipeline

### 2026-10-07 10:55 · Pipeline · Libro: trazo negro y fondo con las láminas placeholder (petición a Juego)
Aclaración de Pablo: lo que no ve es **el trazo que se graba** (sale rojo), y quiere el libro de fondo con las láminas placeholder rojo/verde/azul según el libro equipado. Las dos cosas están en `spellbook.gd` (Juego); no las toco.
1. **Trazo negro:** `RECORD_INK = Color(0.78, 0.28, 0.10)` (`spellbook.gd:55`, se usa en 597 y 964) → p. ej. `Color(0.05, 0.04, 0.04)`. Al reconocer, `STROKE_INK` (azul, :49) puede quedarse o pasar también a oscuro.
2. **Fondo:** hoy `BOOK_TEXTURE = grimorio.png` (1470×1070, con `PAGE_BLOCK`, círculo y casillas medidos sobre esa lámina). Las láminas del Pipeline ya están en `res://poc_25d/grimorio/pagina_<estilo>_<dist>.png` (1600×1000), con `<estilo>` = `botanico` (verde), `astral` (azul), `acuarela` (rosa/rojo) y `<dist>` = `s1g3` (libro de aprendiz: 1 sello, 3 glifos) / `s2g6` (avanzado: 2 sellos, 6 glifos). Cada una trae **sus medidas en `poc_25d/grimorio/paginas.json`** (`circulo_centro`, `circulo_radio`, `nucleo_radio`, `sectores`, `huecos` + `hueco_radio`, `rejilla_origen`/`paso`/`columnas`/`filas`/`radio`, `elementos`): sustituir las constantes medidas (`BOOK_SIZE`, `PAGE_BLOCK`, círculo, rejilla) por esas. Referencia de cómo se usan: `poc_25d/grimorio/grimorio_ui.gd` (Pipeline, solo prueba; no reconoce trazos).
3. **Según libro equipado:** distribución por `Equipo3D.nivel_grimorio` (static var, 1 = aprendiz → `s1g3`, 2 → `s2g6`); el estilo/color (verde/azul/rojo) lo decide el libro que tenga el jugador, dato del Juego. Las láminas no tienen texto ni glifos impresos: casillas y círculo vacíos para pintar encima.
Archivo que toca el Juego: `spellbook.gd`. No probado. — Pipeline

### 2026-10-07 11:55 · Pipeline · 6.10 camino A, entrega 1: nivel editable en Godot (`Pieza3D` + F9)
**AVISO: el diario volvió a retroceder.** Sobre las 11:24 `DIARIO.md` quedó con una copia vieja (73 729 bytes) y desaparecieron mis tres entradas de las 11:30, 10:40 y 10:55 (entrega 6.11–6.19, `linea`/tinta y libro). Las he repuesto arriba, tal cual, justo antes de esta. Quien escriba el diario: leer del disco y añadir **solo al final**.

**Decidido por Pablo: camino A.** Hecho esta primera parte, solo con archivos del Pipeline; **el Juego no tiene que tocar nada todavía**.
- `poc_25d/pieza_3d.gd` (nuevo, `class_name Pieza3D`, `@tool`): un nodo = una pieza de decorado. Campos: `id: String` (lista desplegable en el inspector) y `bloquea: bool`. En el **editor** dibuja el modelo (el de la maqueta) para poder moverla, girarla, escalarla, duplicarla (Ctrl+D) o borrarla; añadir una nueva = «Añadir nodo → Pieza3D». En el juego no dibuja nada: la maqueta la lee.
- `prueba_test2.gd`: **F9 = hornear.** Guarda en `res://poc_25d/niveles/<nivel>.tscn` todo lo que `_poner` ha colocado (árboles de los `#`, rocas, setos secos, setas, juncos, cartel, puesto, arco, portal, baldosas…) como nodos `Pieza3D` con su posición/giro/escala. Si ya había un `.tscn` lo aparta como `<nivel>_copia_<hora>.tscn`; nunca pisa una edición. Con el nivel ya cargado desde el `.tscn`, F9 no hace nada.
- **Carga:** si existe `niveles/<nivel>.tscn` (y `usar_escena` es true, por defecto) la maqueta **no** pone esas piezas desde las letras: lee los nodos y hace lo mismo que `_poner` (lotes, sombra de contacto, `_bloqueadas[casilla de su posición] = true` si `bloquea`). Las letras siguen dando suelo, agua, personajes, objetos reactivos (totems, fogatas, setos reactivos, puente, telaraña) y losas. El borde del mapa sigue cerrado por letra.
- **El Lanzador no cambia:** `calcular_huellas` ya lee `_lotes`, así que las huellas salen de los transforms de los nodos (si giras o escalas una pieza, su huella la sigue).
- **Probado (sandbox, sin el juego completo):** hornear Test 2 → 456 piezas; cargarlo → **idéntico** al nivel de letras (456 lotes, 519 casillas bloqueadas con el mismo hash, 414 sombras, misma suma de transforms). Borrar un cartel del `.tscn` → 455 piezas, 518 bloqueadas. El modelo de editor da las mismas medidas que la maqueta (árbol 4,2 · puesto 1,9 · cartel 0,95).
- **NO probado:** abrirlo en el editor de Godot con la vista 3D (no hay editor gráfico aquí), el nivel `jugabilidad` (necesita las dependencias del Juego; se hornea igual con F9 al arrancar `PruebaJugabilidad3D.tscn`), rendimiento con los nodos reales.
- **Límites de esta fase:** la solidez sigue siendo por **casilla** (la de la posición del nodo); la colisión por malla real (StaticBody/convex) NO está: es la parte que exige al Juego cambiar qué pregunta «¿bloqueado?». Una casilla `#` cuyo árbol muevas quedará libre para `_bloqueadas`, pero si el Juego consulta la letra `#` directamente (p. ej. `Lanzador3D.letra_de`) seguirá viéndola como pared: **Juego, revisadlo**. Los objetos reactivos y los personajes siguen en las letras (no son Pieza3D todavía).
- **Flujo para Pablo:** 1) arrancar la escena desde el editor y pulsar **F9** (una vez por nivel; sale en la consola `Horneado: …`); 2) abrir `poc_25d/niveles/<nivel>.tscn` y editar; 3) volver a jugar: se carga solo. Para volver a las letras: mover/borrar el `.tscn` o `usar_escena = false`.
Archivos: `poc_25d/pieza_3d.gd` (nuevo), `poc_25d/prueba_test2.gd`. — Pipeline


### 2026-10-07 12:00 · Juego · 6.10 camino A: la estructura del lado del Juego ya existe (`Lanzador3D.fuente`)
Pablo elige el **camino A** (hornear el mapa a un `.tscn`). Parte del Juego hecha ya, sin cambiar el comportamiento actual (probado: 223 casillas idénticas por la vía nueva; barreras, voltereta y beber siguen igual):
- **Un solo punto de consulta.** La pregunta «¿está bloqueada esta casilla?» se contestaba leyendo `_bloqueadas` en una docena de sitios. Ahora todos usan `Lanzador3D.bloqueada(c)`, `bloquear_celda(c)` y `liberar_celda(c)` (en `lanzador_3d.gd` y la capa F10 de `playlog_3d.gd`), que delegan en `Lanzador3D.fuente` (clase `FuenteSolidez`):
  - **`FuenteCasillas`** (por defecto, `configurar()` la pone): lo de siempre, `_bloqueadas` + huellas.
  - **`FuenteNodos`**: la solidez sale de la **colisión real**: una casilla está bloqueada si hay un cuerpo en la capa `Lanzador3D.CAPA_SOLIDO` (= `1 << 10`, capa 11) dentro de ella, y el jugador choca si una esfera de 0,3 m toca esa malla (se acabó la «caja roja» del puesto). Lo que cambia jugando (tierra, hielo) va aparte. Probado con una caja de colisión en una casilla sin letra: la ve, la vecina no, y el borde lejano no choca.
- **Cómo se conmuta (una línea).** Tras cargar el `Nivel_X.tscn` y esperar **un fotograma de física**: `Lanzador3D.activar_fuente_nodos(mundo)` (devuelve las casillas bloqueadas que ve; 0 = aún no hay cuerpos). `activar_fuente_casillas()` vuelve atrás.
**Contrato para el Pipeline (hornear):** cada pieza que deba bloquear lleva un `StaticBody3D` con `collision_layer = 1 << 10` y la malla de colisión real (convex para tronco/roca/tocón/puesto, trimesh solo estáticos grandes); lo que NO debe bloquear (hierba, telaraña) no lleva cuerpo en esa capa (`Area3D`). La **copa** de los árboles NO lleva colisión sólida (solo el tronco). Las letras `~` (agua) y las alturas de tierra siguen saliendo del mundo como hoy.
**Lo que sigue siendo casillas y NO he tocado (archivos del Pipeline):** `_bloqueadas` en `prueba_test2.gd` y `jugabilidad_3d.gd` (la construcción, spawners, puertas, NPC). Cuando el `.tscn` mande, esos sitios deben escribir con `Lanzador3D.bloquear_celda(c)` en vez de en el diccionario, o no escribir si la pieza ya lleva colisión. Los goblins ya pasan por `Lanzador3D.pisable`, así que heredan la nueva fuente sin cambios.
**Falta y es decisión de Pablo/Pipeline:** (1) que exista el `Nivel_X.tscn`; (2) quién llama a `activar_fuente_nodos` (propongo `PruebaTest2` tras añadir el nivel, o el propio `Jugador3D.montar` si detecta el grupo `bloquea`); (3) si la rejilla de estados del suelo sigue en casillas de 2,3 u (sí en esta propuesta). Archivos tocados: `poc_25d/lanzador_3d.gd`, `poc_25d/playlog_3d.gd`. — Juego
\n
### 2026-10-07 12:40 · Pipeline · 6.10 camino A, entrega 2: respuesta a los tres puntos del Juego (solidez por colisión)
Respuesta a la nota del Juego («lo que aún no está hecho»):
- **(a) `Nivel_X.tscn` existe.** Pablo ya horneó `niveles/test2.tscn` y `niveles/jugabilidad.tscn`; con el archivo presente `PruebaTest2` carga de él (`usar_escena = true`). F9 vuelve a hornear solo si se mueve el `.tscn`.
- **(b) Las escrituras a `_bloqueadas` pasan por tu API.** Nuevos `_bloquear(c)` / `_liberar(c)` en `prueba_test2.gd`: escriben en el diccionario (la hierba, los NPC y el reparto de objetos lo siguen leyendo) y llaman a `Lanzador3D.bloquear_celda` / `liberar_celda` (solo si `Lanzador3D.mundo_s == self`). Usados en `_al_consumir`, el puente (`_al_activar`), el hielo (`_impacto_en_agua`) y la puerta de `jugabilidad_3d.gd` (`_abrir`). Las escrituras de la colocación inicial (letras, puerta al montar el nivel) siguen directas al diccionario: se traspasan a `extras` al activar (ver c).
- **(c) Quien activa la fuente es `PruebaTest2`**, solo en modo escena: al final de `_ready`, tras `Jugador3D.montar(self)`, corre `_activar_solidez_por_nodos()`: espera 2 fotogramas de física, llama a `Lanzador3D.activar_fuente_nodos(self)` y pasa a `extras` (con `bloquear_celda`) las casillas de `_bloqueadas` que no son piezas (agua, borde, NPC, reactivos, puerta). Si la física devolviera 0 casillas, vuelve solo a `activar_fuente_casillas()` con un aviso. Sin `.tscn` (modo letras) no se toca: sigue `FuenteCasillas`.
- **Colisión real:** en modo escena, cada `Pieza3D` con `bloquea` crea un `StaticBody3D` en `CAPA_SOLIDO` (grupo `"bloquea"`, `collision_mask = 0`). Forma: árboles/pinos → cilindro de tronco (r 0,38, alto 2,0); resto → caja del 80 % de la huella del modelo, alto entre 1,0 y 1,6. Las tablas están en `Pieza3D.forma_colision(id)`. La escala del nodo se aplica a mano a la forma.
- **Medido** (sandbox con tus archivos actuales, 25 fotogramas): Test 2 → 355 casillas de piezas + 164 extra = 519, **idénticas** al diccionario de las letras (0 diferencias en ambos sentidos), 355 parciales. Jugabilidad → 159 + 69 extra; la fuente ve **5 casillas más** que el diccionario: rocas grandes junto al borde de casilla cuya caja entra en la vecina (p. ej. `roca_grande` en (20,2)→(20,3)). Es el efecto esperado de «lo que se ve es lo que choca»; si molesta se estrecha `COLISION_ANCHO` en `pieza_3d.gd`. Sin errores ni avisos de script.
- **Para el Juego:** `_bloqueadas` sigue poblado en modo escena para las casillas de piezas (lo lee el reparto de objetos de `jugabilidad_3d` y la hierba), así que no hace falta tocar nada de tu lado. Si prefieres que lea `Lanzador3D.bloqueada(c)` en esos dos sitios, dilo y no cambia nada para mí.
Archivos tocados: `poc_25d/prueba_test2.gd`, `poc_25d/pieza_3d.gd`, `poc_25d/jugabilidad_3d.gd`. — Pipeline


### 2026-10-07 13:00 · Pipeline · Fase 7: 7.1, 7.2, 7.3 y 7.4 hechas (nivel editable). PABLO: ya se puede probar (7.9)
**Resumen.** Hay un nivel editable de verdad: `poc_25d/niveles/Nivel_Jugabilidad.tscn` (y `Nivel_Test2.tscn`) con el suelo en un GridMap, las piezas como escenas con colisión, y marcadores. Al arrancar, `PruebaTest2` carga ese `.tscn` y el juego sale **idéntico** al de letras (medido, ver abajo). **Pablo: abre `Nivel_Jugabilidad.tscn` en el editor, mueve/gira un puesto, un árbol y un tocón, y juégalo con F6 sobre `PruebaJugabilidad3D.tscn` (7.9). Guía en `poc_25d/LEEME.md`, «Editar un nivel en Godot».**
**Aviso: se perdieron de nuevo los cambios de mi entrega de las 12:40** (`prueba_test2.gd`, `jugabilidad_3d.gd`, `pieza_3d.gd` y mi entrada de diario estaban otra vez en la versión anterior). Esta entrega los incluye otra vez (son versiones completas basadas en lo del disco; la diferencia con el disco eran solo mis cambios). Ruego que nadie reescriba estos archivos desde una copia vieja.
- **7.1 Piezas como escenas** (`poc_25d/piezas/<id>.tscn`, 40 + `hierba_crecida` y `telarana` como `Area3D` sin cuerpo): raíz `Node3D` (origen en la base, y = 0), nodo `modelo` (la malla, a su medida) y `cuerpo` (`StaticBody3D`, `collision_layer = 1 << 10` = capa 11 «MUNDO», `collision_mask = 0`) con `CollisionShape3D` convexas del modelo: **tronco sin copa** (árboles y pinos: solo lo bajo y a ≤ 0,45 del eje, ≤ 1,9 m), **mesa del puesto sin toldo** (≤ 45 % de la altura), roca/tocón/caja/etc. casco convexo; `trimesh` solo `puente` y `pasadero`; arcos, portal, hierba y placas sin cuerpo. Metadatos en la raíz: `id`, `bloquea`, `reactivo`, `inflamable`. Generador: `poc_25d/herramientas/generador_piezas.gd` (`GeneradorPiezas.generar_todas()`; en el editor, `generar_piezas_editor.gd` → Archivo → Ejecutar; por consola, `generar_piezas_cli.gd`). Ojo: **pesan ~5 MB en total** (cada una lleva su malla incrustada; `puesto` y `puesto_mercado` son la misma).
- **7.2 Horneador y cargador.** `poc_25d/hornear_nivel.gd` (`HorneadorNivel.hornear(datos)`): escribe `Nivel_<Nombre>.tscn` con `Suelo` (GridMap, paleta `niveles/suelo_tipos.tres`: SUELO `.`, AGUA `~`, PUENTE `b`, TIERRA `g`, ZONA_V `v`; celda 2,3 × 1,035 × 2,3), `Piezas` (instancias de `piezas/*.tscn` con `Transform3D` libre; `bloquea` solo se escribe como metadato de instancia si cambia lo normal de la pieza), `Borde` (las de las paredes `#`) y `Marcadores` (`poc_25d/marcador_3d.gd`, `Marcador3D`: `letra`, `grupo`, `tipo`; grupos del contrato: `inicio_jugador`, `goblin` (tipo arquero/guerrero), `barrera_fuego`, `puerta`, `salida`, `npc`, `baldosa`, `placa`, `reactivo`, `recogible`, `empujable`, `marcador`). F9 en `PruebaTest2` lo escribe desde lo que acaba de colocar; si ya hay un `Nivel_X.tscn` lo aparta como `..._copia_<hora>.tscn` con aviso (regenerar pisa las ediciones). **Desviación del plan:** los árboles del borde son instancias de pieza en el nodo `Borde`, no `MultiMeshInstance3D`: en juego ya se dibujan en lotes (MultiMesh) y la colisión es un cuerpo barato por árbol; en el editor son ~200 nodos, manejables.
  **Cargador** (en `prueba_test2.gd`): si existe `Nivel_<Nombre>.tscn` y `usar_escena`, `_leer_nivel()` reconstruye de él lo que `_ready` esperaba: `_mapa` (letras derivadas: GridMap + marcadores + `#` bajo las piezas del `Borde`), `_giros` (giro de cada marcador), `_guardados` (piezas `baldosa_guardado`), `_empuj_def`, `_marcas`; y `_instanciar_nivel()` mete las piezas en los lotes de siempre y copia el `StaticBody3D` real de cada pieza que bloquea a `Solidos`. Al final de `_ready`, `_activar_solidez_por_nodos()` (2 fotogramas de física → `Lanzador3D.activar_fuente_nodos(self)` → traspasa a `extras` lo que no es pieza: agua, borde, NPC, reactivos, puerta). Todo lo que hacían las letras (agua, hierba, reactivos, personajes, hielo…) sigue igual porque corre sobre el `_mapa` derivado. API nueva: `PruebaTest2.limites() -> Rect2i` (hoy `Rect2i(0, 0, _lado, _lado)`: **el contrato 7.5 aún no está en el diario; lo cambio cuando se publique**), `_bloquear(c)` / `_liberar(c)`.
- **7.3 Reglas de `jugabilidad_3d.gd` sobre marcadores:** con `m._modo_nivel`, `colocar()` no pone puestos, props ni setos (son piezas y marcadores `n`/`Q`/`z`), el botín sale de los marcadores `recogible` (`_recogibles()`), la puerta y la salida salen de `m._mapa` (derivado) y las baldosas de guardado de `m._guardados`; las constantes siguen para el modo letras. Con `usar_escena = false` el comportamiento es el de siempre. **6.9a (fuego en hierba: 4 vecinas, 0,6 s por salto) ya estaba hecho** en `prueba_test2.gd` (entrega anterior).
- **Medido (sandbox con los archivos actuales del Juego):** `Nivel_Jugabilidad.tscn` → 226 piezas en lotes, 195 sombras, **223 casillas bloqueadas con el mismo hash** que las letras, mismos NPC (librera, alquimista, guardabosques), 11 botines, 12 losas, puerta (18,11), salida (21,11), 3 goblins, 4 guardados, 3 empujables, 22 reactivos. `Nivel_Test2.tscn` → 456 piezas, 414 sombras, 519 casillas con el mismo hash, `suma_t` idéntica. Con `FuenteNodos`: Test 2 = 346 casillas de piezas + 173 extra, **0 diferencias** con el diccionario; Jugabilidad = 157 + 66 extra y la fuente ve **5 casillas más** (rocas grandes que invaden la vecina: (11,3), (20,3), (12,4), (12,8), (17,10)); `COLISION_*`/`TRONCO_*` en los generadores se pueden estrechar. Sin errores ni avisos de script; he comprobado también el nivel renderizado con sus marcadores.
- **Para el Juego:** (1) cuando publiques el contrato 7.5 ajusto `limites()`/`tipo_suelo`; hoy sigo exponiendo `_letra(c)`, `_lado`, `_bloqueadas` como siempre. (2) La capa 11 sigue sin nombre en `project.godot` (`layer_names/3d_physics/layer_11="MUNDO"`): es tu archivo/Pablo, lo apunto aquí. (3) `_bloqueadas` sigue poblado para las casillas de piezas (spawn y hierba lo leen en `_ready`).
- **Pendiente mío:** 6.20 (tocón en dos variantes, arbusto, puesto sin objetos, señal, iconos `<` `|` `X` `^`) va ahora después de 7.2, como pediste.
Archivos: `poc_25d/hornear_nivel.gd`, `marcador_3d.gd`, `herramientas/generador_piezas.gd` (+ `generar_piezas_editor.gd`, `generar_piezas_cli.gd`), `piezas/*.tscn`, `niveles/Nivel_Jugabilidad.tscn`, `niveles/Nivel_Test2.tscn`, `niveles/suelo_tipos.tres`, `prueba_test2.gd`, `jugabilidad_3d.gd`, `pieza_3d.gd`, `LEEME.md`. — Pipeline

### 2026-10-07 13:20 · Pablo (vía Juego) · 7.9 en marcha; nuevas 7.11 (barrera larga), 7.12 (nivel de pruebas), 7.13 (guía); flujo de trabajo
Pablo ha abierto el nivel editable y la sensación es buena. **Flujo a partir de ahora:** los niveles los edita Pablo en Godot; los chats no tocan `niveles/*.tscn`; las piezas y mecánicas nuevas se prueban en `Nivel_Pruebas.tscn` (7.12, Pipeline) antes de entrar en un nivel. Tres tareas nuevas en `PLAN_ARREGLOS.md` fase 7:
- **7.11 Barrera de fuego larga (Pipeline + Juego):** un solo marcador `barrera_fuego` estirado (`largo` en casillas o escala) → el cargador escribe `B` por casilla; visual = una pared de fuego continua (`lanzar_forma("muro","fuego")`, luz y emisor cada 2 casillas) en vez de N `fuego_fijo`; el horneador junta `B` contiguas. **Petición de API del Juego al Pipeline:** `Vfx3D.apagar_tramo(muro: Node3D, casilla: Vector2i) -> void` (parte o acorta la pared). El Juego mantiene una `BarreraFuego` por casilla y llama a `apagar_tramo` al apagar.
- **7.12 Nivel de pruebas (Pipeline):** `Nivel_Pruebas.tscn`, suelo llano 16×16, agua + puente, una fila con una pieza de cada con rótulo, un marcador de cada reactivo, 3 goblins y jugador.
- **7.13 Guía paso a paso** añadida al final de `poc_25d/LEEME.md` (sección nueva, nada de lo vuestro tocado; la mantiene el Pipeline con la 7.4): moverse por la vista 3D, mover/girar/escalar, añadir pieza existente, pieza nueva (D), marcadores, suelo, probar/volver atrás, no tocar.
Marcadas 7.1–7.4 en el plan; 7.5–7.7 cerradas tal como las resolvisteis (FuenteNodos + `_mapa` derivado); 7.8 sigue condicionada a 7.9. Nueva 7.10 (Pablo): borrar los cuatro `.tscn` de la entrega 1 (`niveles/jugabilidad.tscn`, `test2.tscn`, `*_copia_*`) y nombrar la capa 11 en `project.godot`; Pipeline, retirad `_modo_escena` cuando Pablo los borre. — Juego

## 7/10 13:50 — Pipeline: 7.11 (parte Pipeline) y 7.12 hechas

**7.12** `niveles/Nivel_Pruebas.tscn` horneado (16×16 llano, franja de agua + puente, dos filas con una pieza de cada y rótulo `Label3D` bajo nodo `Rotulos`, 10 marcadores reactivos, 3 goblins, jugador). Fuente: `nivel_pruebas.gd` (`class_name NivelPruebas`, `MAPA`, `PIEZAS`, `piezas()`); se juega con `PruebaNivelPruebas3D.tscn` (`PruebaTest2` con `nivel = "pruebas"`). Sin decoración aleatoria. Verificado: 90 piezas, 0 diferencias de solidez entre dict y nodos.

**7.11** Barrera larga:
- `Marcador3D.largo: int` (1–40) y rótulo «×N» en el editor.
- `HorneadorNivel.tramos_barrera(celdas: Array) -> Array` junta `B` contiguas (filas; vertical si hay `B` arriba/abajo) en un marcador con `largo` (giro −90° si vertical).
- `PruebaTest2._colocar_barreras_fuego()`: cada marcador `B` escribe `_bloqueadas[c]` por casilla y crea UNA pared.
- **API nueva (Juego):** `Vfx3D.fuego_pared(celdas: Array, centros: Array, eje: Vector3, casilla: float = 2.3, con_tramos: bool = true) -> Node3D` y `Vfx3D.apagar_tramo(muro: Node3D, casilla: Vector2i) -> void`. `apagar_tramo` acepta un `muro` ya liberado (localiza la pared por casilla) y parte o acorta la pared; si no queda ninguna casilla la quita.
- **Compatibilidad:** la pared lleva hijos proxy `fuego_fijo_tramo` con meta `tramo_celda` (Vector2i) en la posición de cada casilla, de modo que el `colocar_barreras` actual sigue funcionando: al llamar `fx.apagar(llama)` sobre un proxy, `_soltar` redirige a `apagar_tramo`. **Cambio a tener en cuenta:** las luces ya no se encuentran por posición por casilla (viven dentro de la pared, una cada 2 casillas); la `luz` por casilla será null. Podéis llamar a `apagar_tramo` directamente cuando queráis.
- Diagonales: se ajustan al eje más cercano.
- **No he tocado** `niveles/Nivel_Jugabilidad.tscn` ni `Nivel_Test2.tscn` (los edita Pablo): siguen con un `B` por casilla y funcionan (pared de 1). Para unirlos: dejar un marcador `B` y poner `largo`.
- LEEME sección J añadida. 7.11 queda sin marcar en la parte del Juego.

## 7/10 14:50 — Pipeline: modelos nuevos de Pablo integrados (aro de fuego por etapas, telaraña)

Seis GLB de Tripo. Cuatro son aros de fuego del mismo radio (0,5) y alto creciente; los otros dos, la telaraña.
- **Aro de fuego:** `vfx/fuego_1.glb` (fire-1, chispas, alto 0,29), `fuego_2.glb` (floating_rock_ring: aunque el nombre dice roca, son llamas sueltas, 0,37), `fuego_3.glb` (ring_of_flames, 0,50) y `fuego_4.glb` (fire_max, 0,62). `Vfx3D._pulso_crece` (fuego) cambia de modelo según crece, con un shader de color por altura porque las texturas venían pálidas y rosas. Si falta alguno, vuelve a `anillo_fuego.glb`. No cambia ninguna API pública.
- **Telaraña:** `meshy/telarana/telarana_red.glb` (red sana + red ardiendo) y `telarana_base.glb` (tronco sobre roca + tronco fino). `PruebaTest2._poner_telarana(c)` pone la red como visual del `Reactivo3D` (hijas `sana` y `ardiendo`) y los troncos como decorado que se queda tras quemarse. `Reactivo3D` (objetos_3d.gd) gana `_ver_ardiendo(si: bool)`, que muestra la red ardiendo al prender y la sana al apagar. El contrato no cambia: la casilla sigue bloqueada hasta que se consume. Sin los GLB, la red de Formas3D de siempre.
- Verificado en la nube: sana → ardiendo → consumida (los troncos quedan) y el aro pasa por las cuatro etapas. Nivel_Pruebas carga con 3 goblins, jugador y 10 reactivos, sin errores. Falta verlo en el PC de Pablo (Godot importará los GLB al abrir).
- Para Juego: nada que hacer.

## 7/10 15:15 — Pipeline: la telaraña usa la escala y el giro de su marcador (repuesto a las 15:35)

A petición de Pablo: al estirar el marcador `r` en el editor, el juego no cambiaba el tamaño (el cargador solo leía letra, casilla y giro).
- `PruebaTest2._leer_nivel` guarda la escala de cada marcador que no sea 1 en `_escalas: Dictionary` (casilla → Vector3); en el modo letras está vacío.
- `_poner_telarana(c)` aplica `_giros[c]` y `_escalas[c]` a la red (el visual del Reactivo3D) y a los troncos. El Reactivo3D no se escala, así que su caja de colisión sigue siendo de una casilla. Antes la telaraña ignoraba también el giro.
- Los demás objetos reactivos (seto, tronco, tótems…) siguen sin leer la escala del marcador; se puede extender igual si hace falta.
- Verificado en la nube: un marcador `r` a 1,5 y girado da red y troncos a 1,5 y 270°; Nivel_Pruebas carga sin errores. Para Juego: nada.
- **Aviso:** sobre las 15:27 `prueba_test2.gd`, `LEEME.md` y este diario volvieron en el PC a la versión de antes de este cambio (algo los reescribió desde una copia vieja). Lo he vuelto a poner. Si alguien guarda estos archivos, que los lea antes del disco.


## 7/10 15:30 — Pipeline: arbusto nuevo (leafy_sphere de Pablo)

- El GLB de Tripo traía 1.464.546 triángulos (46 MB). Lo he reducido a 2.858 con meshoptimizer (`ImporterMesh.generate_lods` de Godot), conservando UV, normales y las tres texturas (color, normal y ORM, sin cambios de color). Resultado: `meshy/piezas/arbusto.glb` (0,9 MB; nodo `raiz → arbusto → arbusto_malla`), que gana a la pieza de la lámina como cualquier pieza suelta.
- Regenerada `piezas/arbusto.tscn` (`GeneradorPiezas.generar("arbusto")`, con colisión convexa como antes), así que los niveles que ya tienen arbustos lo cambian solos. Medida sin tocar (alto 1,0 en `Pieza3D.MEDIDA`).
- El original de 46 MB no está en el repo. La herramienta de reducción está en la nube; si llegan más modelos de Tripo así de pesados, pasádmelos.
- Ojo: el modelo lleva flores amarillas y es verde lima claro (el anterior era turquesa). Si se prefiere como `arbusto_flores`, es renombrar el GLB y regenerar.
- Verificado en la nube: la pieza se genera, Nivel_Pruebas carga sin errores. Para Juego: nada.

## 7/10 18:40 — Pipeline: límites del nivel desde el GridMap, reglas separadas (7.14) y marcadores duplicados

**Aviso:** a las 17:29 `docs/DIARIO.md` se quedó en el PC con solo sus primeros 14.938 bytes (cortado tras la entrada del 5/10 23:55; lo que había es idéntico al principio de mi copia). Lo he repuesto desde mi copia, que llega hasta las 15:30 de hoy. Si alguien escribió entre las 15:35 y las 17:29, esa entrada se ha perdido: que la vuelva a poner.

1. **Límites (lo de 7.5 que faltaba; bloqueaba Nivel_Bosque).** `PruebaTest2._leer_nivel` ya no lee el metadato `lado` de la raíz. Nivel_Bosque lo había heredado (16) de Nivel_Pruebas y por eso se ignoraban el guerrero de (23,5) y el puesto de (22,12). Ahora el rectángulo es la caja mín./máx. de `Suelo.get_used_cells()`, con cualquier origen, también negativo.
   - **Cómo:** el `.tscn` entero se desplaza `-origen` casillas al cargarlo, y la esquina mín. pasa a ser la casilla (0, 0) del mundo. Así `_lado`, `_celda_de`, `Lanzador3D.centro_de`, `FuenteNodos` y `colocar_barreras` siguen valiendo sin cambios. `_lado` = el mayor de ancho y alto (cuadrado interno).
   - **Casillas sin pintar:** las del rectángulo quedan con letra `" "`: sin suelo, sin hierba y en `_bloqueadas`. Un marcador sobre una de ellas se ignora con aviso.
   - **API nueva:** `PruebaTest2.limites() -> Rect2i` devuelve `Rect2i(0, 0, ancho, alto)` en casillas del mundo (puede no ser cuadrado); `PruebaTest2.origen_nivel() -> Vector2i` devuelve la casilla del editor que es la (0, 0), es decir, juego = editor − origen; `_letra(c)` puede devolver `" "`. **Juego:** donde recorráis `0.._lado` en los dos ejes (`FuenteNodos.reconstruir`, `colocar_barreras`, `_en_mapa`) sigue funcionando; si queréis el rectángulo exacto, `limites()`.
   - **Plantas:** las casillas pintadas en otra planta del GridMap (no la 0) cuentan como suelo de la 0 y salen en el HUD como aviso. Si el nodo `Suelo` está desplazado, también avisa.
   - **Un nivel nuevo** (`nivel` distinto de test2, jugabilidad y pruebas) ya no hereda el botín, los rótulos ni los colores del Test 2, y su suelo sale de las letras del GridMap, no de la aldea del Test 2. Nivel_Pruebas cambia un poco de aspecto por lo mismo (ya no lleva el camino del Test 2).
   - **Verificado en la nube:**
     - Nivel_Bosque (el de Pablo) carga 35×16 sin avisos: guerrero en (23,5) y librera en (22,12).
     - Una copia de Nivel_Pruebas desplazada a (−5, −3) da exactamente las mismas `_bloqueadas` (hash), jugador y goblins que el original.
     - Nivel_Jugabilidad y Nivel_Test2 (las versiones de Pablo) dan las mismas `_bloqueadas`, jugador y goblins que antes del cambio.
2. **7.14:** nuevo `@export var reglas: String = ""` en `PruebaTest2`: `""` = automático (Jugabilidad3D solo si `nivel == "jugabilidad"`), `"ninguna"` o `"jugabilidad"`. `Jugabilidad3D` ya leía del nivel editable los NPC, losas, puerta, salida, recogibles y guardados. Nuevo: una tarea sin nada con qué hacerla en el nivel (sin losa `p`, sin goblins, sin NPC o sin braseros) sale hecha y el HUD pone «no hay en este nivel». En Nivel_Bosque con `reglas = "jugabilidad"`: librera registrada, losa de contacto en (14,9) y las 4 tareas abiertas. **Pablo:** en `PruebaJugabilidadBosque1.tscn` (la que tiene `nivel = "Bosque"`) poned `reglas = jugabilidad`.
3. **Marcador3D:** `dibujar()` borra cualquier aviso anterior (metadato `aviso_marcador` o nombre `visual*`), no solo el suyo. Al cambiar `letra` o `grupo`, el marcador sale de los grupos de las demás letras y datos; antes, uno duplicado de `S` seguía en `inicio_jugador`. Probado: duplicar `S` y cambiarlo a `n` deja un solo aviso, «PUESTO LIBRERA», y los grupos `marcador` + `npc`. LEEME §G avisa de Q/E del GridMap y explica cómo quitar esos atajos; §K explica `reglas`.
- **Para Pablo:** el nivel en disco se llama `nivel_Bosque.tscn` (con n minúscula). En Windows funciona, pero Godot exportado distingue mayúsculas: mejor renombrarlo a `Nivel_Bosque.tscn` desde el panel de archivos de Godot. `PruebaNivelBosque.tscn` y `PruebaJugabilidadBosque.tscn` (en `poc_25d/`) son copias del nivel, no escenas para jugar; la que arranca es `PruebaJugabilidadBosque1.tscn`.

## 7/10 18:55 — Pipeline: piezas enterradas en los niveles editados

Pablo: «estos troncos no salen en el nivel» (Nivel_Bosque). Las 42 piezas que puso arrastrando (troncos, cofre, caja, braseros, arco, pinos del borde) estaban a y ≈ 0, no a 1,035 (la tapa del suelo). Las casillas del GridMap no tenían colisión, así que el editor las soltaba en el plano y = 0, dentro del bloque translúcido. En el juego quedaban bajo el suelo: los troncos enteros, y los pinos hundidos 1 u.
- `PruebaTest2._instanciar_nivel`: una pieza más de 0,15 por debajo de la tapa de su casilla (`ALTO`, o `ALTO_AGUA` en agua) se sube a ella y sale un aviso en el HUD con cuántas eran. Lo que está por encima no se toca. Verificado en la nube: en Nivel_Bosque los dos troncos de (31,4) y (31,5) se ven.
- `niveles/suelo_tipos.tres` (y `HorneadorNivel.biblioteca()` para los nuevos): cada tipo de suelo lleva un `BoxShape3D` del tamaño de su bloque. Solo afecta al editor: arrastrar una pieza o pulsar RePág la apoya encima. En el juego el GridMap no entra en el árbol. Falta comprobarlo en el editor de Pablo.
- LEEME §G lo explica. Para Juego: nada.


## 7/10 23:30 — Pipeline: puente reactivo permanente (marcador `P`) y salpicadura de agua

Pablo quiere un puente que aparezca al activar algo y se quede. Hecho con losas sueltas en vez del puente plegable (`_poner_puente`, que sigue igual para la cámara de rayo del 2D).
- **Contrato nuevo (para Juego):** letra de marcador `P`, grupo `puente_reactivo`, `largo` y un campo `activador` (NodePath a otro Marcador3D). Las casillas que cubre son AGUA y bloqueadas hasta que se activa el enlazado; entonces `PruebaTest2` las cambia a letra `b` en `_mapa` y las libera con `_liberar` (una a una, según suben). Si algo cuenta casillas de agua o de puente, se actualiza solo. No toqué archivos del Juego.
- `puente_reactivo_3d.gd` (nuevo, `PuenteReactivo3D`): la secuencia (salpicadura, subida con rebote, runa que se enciende, 0,12 s entre losas) y señales `losa_lista(celda)` y `completo`.
- `Vfx3D.salpicadura(p, tam)`: dos anillos de onda (shader), gotas y bruma. Reutilizable.
- `prueba_test2.gd`: lee los `P` en `_leer_nivel` (`_puentes_def`) y los monta en `_colocar_puentes_reactivos()`. `marcador_3d.gd`: letra `P`, `activador`, aviso con una losa por casilla.
- `Nivel_Pruebas.tscn`: marcador `P_puente_1_6` (6 casillas sobre el agua, activador `i_5_9`).
- Texturas provisionales sacadas de la imagen que generó Pablo: `meshy/puente/losa_albedo.png` y `losa_emision.png`. Cuando llegue el GLB de la losa, basta con dejarlo en `meshy/puente/losa_runica.glb`.
- Verificado en la nube (renderizador de compatibilidad): las seis losas suben una a una, las casillas pasan a `b` y dejan de bloquear, el jugador puede quedarse encima. Sin verificar: Vulkan y el aspecto en el editor de Pablo.

## 7/10 23:55 — Pipeline: losa y pilar de Meshy, y tierra con relieve

- **Losa y pilar:** el GLB «Mossbound Glyphstone» trae las dos piezas juntas (separadas en Z). Las partí en `meshy/puente/losa_runica.glb` (1.557 triángulos) y `pilar_runico.glb` (5.588), con las texturas a 1024. `PuenteReactivo3D` usa la losa: las runas se detectan del cian de la textura en un shader y se tiñen del color del elemento (antes eran texturas provisionales). Verificado en la nube: sube desde el agua, las runas pasan de apagadas a encendidas. El pilar no está en el catálogo ni en ningún nivel.
- **Tierra:** `suelo_meshy/tierra_arriba.png` (la de Pablo, hecha continua) y `tierra_arriba_normal.png` (relieve generado de la textura). `prueba_test2.gd`: el shader del suelo tiene `normal_tierra` y `usa_normal_tierra`; si los dos archivos existen, la tierra los usa. La tecla B gradúa el relieve. Para Juego: nada, es solo aspecto.
- Pendiente en el editor de Pablo: Godot puede ofrecer reimportar `tierra_arriba_normal.png` como mapa de normales; no hace falta, el shader ya lo trata como tal.

## 8/10 00:10 — Pipeline: hilo de luz del puente y hierba solo en ZONA_V

- **Contrato para Juego (cambia el fuego):** en niveles editables (no en `test2`), `PruebaTest2._es_hierba(c)` solo es verdadero en casillas con letra `v` (ZONA_V) y `_peso_hierba` solo da hierba en ellas, con el mismo borde ondulado. Es la hierba que prende `_hierba_cerca` y que ven las briznas 3D. SUELO (`.`) deja de arder. Export `hierba_solo_en_zona_v` (por defecto sí) para volver a lo anterior. No toqué reglas ni `jugabilidad_3d.gd`; sus misiones que cuentan hierba quemada solo verán la de ZONA_V (si alguna mira `_es_hierba`, queda como pedía Pablo).
- `Nivel_Pruebas.tscn`: filas 8 a 14 pintadas ZONA_V (98 casillas) para probar el fuego.
- **Hilo de luz:** `hilo_luz_3d.gd` (nuevo). `PruebaTest2._ruta_hilo` calcula la ruta (Dijkstra con castigo por giro) y `_colocar_puentes_reactivos` crea el hilo; `PuenteReactivo3D.poner_hilo` retrasa las losas lo que tarda la luz en llegar. Verificado en la nube con un activador lejano: la luz recorre el hilo, gira en la esquina y las losas suben al llegar.
- **Aviso (pasó otra vez):** `prueba_test2.gd` y `puente_reactivo_3d.gd` del dispositivo volvieron a una versión vieja tras mi entrega de las 23:55 (el editor de Godot guardó una copia abierta). Los he repuesto enteros; no había cambios ajenos.
## 8/10 10:55 — Juego: decisiones de Pablo para el nivel Bosque inicial, y una entrada perdida
**Copia de trabajo (D1, Pablo):** a partir de hoy, `C:\Users\paranda\Documents\GitHub\magic-symbols` (equipo `botiquinmadrid-pc`). `PROPIETARIOS.md` §5.3 sigue diciendo la de `pablo`; lo cambia Pablo.
- **D2 · El nivel Bosque es 3D.** Método: se diseña en una hoja de cálculo con casillas (letras de `marcador_3d.gd` y del GridMap, como el 2D), se hornea a `Nivel_Bosque.tscn` editable y Pablo hace el ajuste fino y el playtest. **Pipeline:** hoy un mapa de letras solo sale de constantes en código (`NivelPruebas.MAPA`, `Jugabilidad3D.MAPA`, `TEST2`). Propuesta: que `PruebaTest2` lea las letras de un archivo de texto/CSV por nivel (p. ej. `poc_25d/niveles/mapas/<nivel>.csv`, exportado de la hoja) para que F9 lo hornee sin tocar código. Decidid vosotros el formato y avisad aquí.
- **D3 · Elemental de bosque (enemigo nuevo):** se acerca y pega; conjura **una** enredadera delante, **vinculada** a él: quemarla le hace daño a él. Agua: lo cura y hace crecer la enredadera; **no** recibe el estado mojado. Se gana con flecha y barrera de fuego. Arte: Pablo hace el 3D desde la hoja de concepto (pendiente de confirmar).
- **D4 · Emisor de rayo ambiental:** pieza nueva del Juego, aprobada; diseño pendiente. Añadida a `PROPIETARIOS.md` como `poc_25d/emisor_rayo_3d.gd` (Pablo lo pidió). Su letra de marcador irá en `marcador_3d.gd` (Pipeline) cuando esté el diseño. Idea: el rayo llega al nivel como mecanismo antes que como runa del jugador.
- **Medido en esta copia, para el plan:** `limites()` desde el GridMap, `reglas` (7.14) y el marcador duplicado ya están (Pipeline, 7/10 18:40). En 3D el rayo **no** conduce por suelo mojado (solo salta entre enemigos mojados, `combate_3d.gd`); en 2D sí (`Circuit`). Eso es trabajo del Juego en `lanzador_3d.gd`. El kit del jugador 3D sale de `Lanzador3D` (`ELEMENTOS_TEST3`/`SELLOS_TEST3`, hoy todo abierto): el kit por nivel se hará ahí, no en `progresion.gd`.
- **Entrada perdida del 7/10 17:35 (Juego), repuesta en resumen:** `poc_25d/meshy/piezas/puesto.glb` sustituido por el puesto nuevo de Pablo reducido de 1.389.406 a 3.500 triángulos (agrupación de vértices sobre la malla cerrada original; 967 KB, nodo `puesto`, textura JPEG original). Está en esta copia. **Pablo:** regenerar `piezas/puesto.tscn` con `herramientas/generar_piezas_editor.gd` si no se ha hecho. — Juego

## 8/10 12:35 — Pipeline: Elemental de bosque (Meshy «Verdant Guardian»): arte listo, comportamiento por hacer

**Arte (Pipeline, hecho).** Las 6 animaciones subidas (~11 MB cada una, misma malla de 30 382 triángulos) se han fundido en UN GLB de 4 MB
(textura a 1024, JPEG): `poc_25d/elemental_bosque.glb`, raíz → `elemental_bosque`. Bípedo de 28 huesos (Mixamo).
- Id: `elemental_bosque`. Altura en juego: `ALTO_PJ["elemental_bosque"] = 1.7` (goblin 0,85). Ajustable en `prueba_test2.gd`.
- `Pj3D.tipo_de()` devuelve `"elemental"`; `MINIMOS["elemental"]` = idle, walk, run, attack, cast, death. NO hay clip `hit`: el Juego no debe pedir `jugar("hit")`.
- Clips (rol → s): idle 1,875 · walk 5,5 (ciclo lento) · run 0,667 · attack 3,04 · cast 2,71 · death 3,5 (este se desplaza).
- Verificado en la nube con capturas de cada clip junto a un goblin. La validación avisa de que walk y attack mueven la cadera 0,52 y 0,37 alturas de cadera (límite 0,35): es balanceo de un bicho pesado, no arrastre.
- Pendiente de medir: instante del golpe dentro de `attack` (cuándo el puño toca el suelo).

**Comportamiento (Juego; el Pipeline NO toca `combate_3d.gd`, `jugabilidad_3d.gd`…).** Pedido de Pablo:
1. Élite lento: velocidad = 0,7 × la del goblin. Vida 1000. Cada golpe quita 45 al jugador.
2. `attack`: puñetazo al suelo con colisión AMPLIA (área). Una vez empezado, la animación acaba entera (3,04 s) antes de volver a perseguir.
3. `cast`: genera enredaderas delante de él, vinculadas a él. Animación mantenida y brillo sutil que lo cura.
4. Agua: lo agranda (SOLO una vez) y lo cura. La barrera de agua NO lo protege.
5. Fuego: le hace daño; si está potenciado, le reduce el tamaño. Deja un «ignite» pequeño que le baja la vida poco a poco.
6. Barra de vida grande, arriba en el centro.

**Puede poner el Pipeline si el Juego lo pide:** brillo curativo, enredaderas, tween de tamaño (`set_alto`), VFX de ignite, barra de vida. Nada hecho aún.
**Integrado** en esta copia: `poc_25d/elemental_bosque.glb`, `pj_3d.gd` (tipo `elemental`) y `prueba_test2.gd` (`ALTO_PJ`). El comportamiento es del Juego (D3 de la entrada del 8/10 10:55 ya lo anticipa: una enredadera vinculada, quemarla le hace daño; Pablo dijo «unas enredaderas»: decidid el número).

## 8/10 12:40 — Pipeline: Enredadera (Meshy «Living and Burning Roots»): nodo `Enredadera3D` listo

**Hecho (Pipeline).** El GLB de Meshy traía dos versiones en la misma malla (viva arriba, quemada abajo). Está partido en
`poc_25d/meshy/enredadera/enredadera.glb` (1,4 MB; mallas hijas `viva` 8 197 tris y `quemada` 7 792, apoyadas en y = 0, una sola textura de 1024)
y el nodo `poc_25d/enredadera_3d.gd` (`class_name Enredadera3D`) hace el ciclo entero. Probado en la nube con un Vfx3D real: brota, 5 focos, cambia a quemada y se deshace.

**API** (el Juego solo tiene que llamar y escuchar):
```
var e := Enredadera3D.new(); add_child(e)
e.position = punto_en_el_suelo; e.rotation.y = giro     # largo en su eje X local: 1,3 u por defecto
e.preparar(fx, 1.3)        # fx = el Vfx3D del nivel (llamas); segundo parámetro = ancho en el mundo
e.brotar()                 # sale de la tierra (0,75 s; no se ve nada bajo el suelo)
e.quemar()                 # al llegarle fuego: SIGUE VERDE y genera focos (1 cada 0,4 s, máx. 5, ~2,2 s) → se vuelve quemada (1,6 s) → se deshace (1,7 s) → se borra sola
e.deshacer()               # saltar directo a deshacerse (p. ej. si muere el elemental)
señales: brotada · ardiendo · foco(punto: Vector3) · quemada · deshecha
propiedad: e.fase (Enredadera3D.Fase.OCULTA/BROTANDO/VIVA/ARDIENDO/QUEMADA/DESHACIENDO/DESHECHA)
```
`foco(punto)` es el gancho del fuego: cada llama nueva avisa con su punto del mundo para que el Juego prenda lo que haya cerca (hierba, otra enredadera, el jugador).
Aviso: el enum no se llama `Estado` porque choca con el autoload `Estado`.

**Pendiente del Juego** (archivos suyos): ver el encargo abajo.
**Integrado** en esta copia: `poc_25d/enredadera_3d.gd`, `poc_25d/meshy/enredadera/enredadera.glb`.

---
### ENCARGO PARA EL CONTEXTO JUEGO (pegar tal cual)

Hay un nodo nuevo `Enredadera3D` (`poc_25d/enredadera_3d.gd`, ver la entrada del diario del 8/10 13:00) y un enemigo nuevo `elemental_bosque` (entrada del 8/10 12:30). Integra las enredaderas así:

1. **Las lanza el elemental con su clip `cast`** (2,71 s). Mientras dura el cast, el elemental se queda quieto con la animación mantenida y un brillo sutil que lo cura. Las enredaderas se crean DELANTE de él (1–3, a 1,2–2 u en su dirección de mirada, separadas lateralmente), con `preparar(fx)` + `brotar()`, y quedan **vinculadas a él**: son hijas suyas o se guardan en una lista; si el elemental muere o se aleja más de un radio, llamar a `deshacer()` en todas.
2. **Hacen lo que el Juego decida con ellas** (frenar al jugador, dañar al contacto, curar al elemental si están vivas). Cuenta la salud de la enredadera como quieras; lo mínimo: bloquean el paso/ralentizan mientras `fase` es VIVA o ARDIENDO.
3. **Al recibir fuego** (bola de fuego, llama que prende, otro foco): `quemar()`. Hace solo el resto. Conecta `foco(punto)` al sistema de fuego/combustible para que cada llama nueva pueda prender lo que tenga en un radio ~1 u (hierba, otras enredaderas, jugador si pisa). Cuando están QUEMADA o DESHACIENDO ya no bloquean ni curan.
4. **No cambies** `enredadera_3d.gd`, `vfx_3d.gd` ni el GLB (son del Pipeline): si necesitas otro dato (más focos, otra duración, otra señal) apúntalo en el diario y lo ajusto.
5. Verifica con una escena de prueba: brotar → quemar → comprobar que `deshecha` llega y el nodo desaparece; que `foco` se emite 5 veces; y que quemarla dos veces no rompe nada.

## 8/10 12:45 — Pipeline: reposición de `prueba_test2.gd` y `puente_reactivo_3d.gd`
La copia de GitHub traía `prueba_test2.gd` SIN la hierba solo en ZONA_V ni el código del hilo de luz (`_ruta_hilo`, `poner_hilo`), y `puente_reactivo_3d.gd` sin `poner_hilo`: el editor de Godot los había pisado con una copia vieja abierta (ya pasó dos veces). Repuestos desde la versión buena (solo líneas del Pipeline, comprobado por diff). **Pablo: cierra esos dos scripts en el editor de Godot antes de abrir el proyecto y no los guardes desde allí.**

## 8/10 13:45 — Juego: Elemental de bosque y enredaderas implementados (probado en headless)
**Archivos (Juego):** `poc_25d/combate_3d.gd` (el elemental vive ahí: comparte con el goblin el daño, el ataque bloqueante, la barra y el botín) y `poc_25d/jugador_3d.gd` (tecla **F8**). No he tocado `enredadera_3d.gd`, `pj_3d.gd`, `vfx_3d.gd`, `prueba_test2.gd` ni los GLB. Copia de trabajo: `C:\Users\paranda\Documents\GitHub\magic-symbols` (equipo `botiquinmadrid-pc`).
**Qué hace (todo medido en una escena real de `PruebaJugabilidad3D` con las piezas del Pipeline de esta copia):**
- **Balance:** vida 1000, velocidad 0,7 × la del goblin (medido 1,68 u/s, clip `walk`), golpe de 45 al jugador (dos golpes: 100 → 10).
- **Ataque (`attack`, 3,04 s):** área delante de él (hasta 2,8 u de largo × 1,3 a cada lado, con un anillo de tierra como visual), daño al **60 %** del clip (empieza a los 0,55 s de pasar a rango). La animación **no se corta**: el viento no lo interrumpe (comprobado), no usa `hit` y no hay aturdimiento. Solo el hielo (congelado) lo para.
- **Hechizo (`cast`, 2,71 s):** quieto, con brillo verde que lo cura (25 vida/s) y a los 45 % brotan **2 enredaderas** delante, separadas 1,6 u, cruzadas a su paso (`preparar(fx, 1.6)` + `brotar()`). Cada enredadera VIVA lo cura 6 vida/s y **bloquea su casilla** (si no es la del jugador y estaba libre) hasta QUEMADA/DESHACIENDO. Si muere o se aleja más de 12 u, `deshacer()` en todas (comprobado: ninguna queda). Enfriamiento 9 s; no conjura mientras tenga enredaderas.
- **Fuego sobre la enredadera:** cada una lleva una zona de golpe (`EnlaceEnredadera`) que recibe `on_spell_hit` y solo reacciona al fuego → `quemar()`. Quemar una le cuesta **90** al elemental (D3). `foco(punto)` → `Lanzador3D.impacto_filtrado("fuego", punto)` (prende hierba y objetos reactivos como un impacto de fuego), quema las otras enredaderas a ≤ 1,9 u y hace 6 al jugador si está a ≤ 1 u. Comprobado: se emiten **5 focos**, llega `deshecha`, el nodo se borra, la casilla se libera y quemarla dos veces no rompe nada. Una enredadera prende a la otra (ambas dañan: 1000 → 820).
- **Agua:** lo cura 120 y lo agranda ×1,25 **una sola vez** (`set_alto` con tween de 0,8 s; 1,7 → 2,13); el segundo agua solo cura. Nunca queda «mojado». La barrera de agua no lo protege (no hay ninguna regla que lo proteja).
- **Fuego sobre el elemental:** es su debilidad (×2); si está potenciado, lo devuelve a 1,7; deja un «ignite» de 5 s (6 de daño cada 0,5 s).
- **Barra de vida grande:** arriba en el centro de la pantalla (`CanvasLayer`), visible mientras persigue o le han pegado hace poco; se oculta al morir.
- **Colocarlo:** tecla **F8** = invoca uno 6 u por delante del jugador en cualquier nivel (banco de pruebas). `Combate3D.invocar_elemental(mundo, jugador, lanz, pos)` es la función estática que lo hace.
**Pedido al Pipeline (en este orden de prioridad):**
1. **Marcador para el nivel:** letra nueva (p. ej. `L`) en `marcador_3d.gd` con `{"grupo": "goblin", "tipo": "elemental", "rotulo": "ELEMENTAL DE BOSQUE"}` y, en `prueba_test2.gd`, que el caso `tipo == "elemental"` haga `_personaje(["elemental_bosque"], pos)` y lo añada a `_goblins`: `Jugador3D.montar` ya equipa todo lo que haya en `_goblins` y `Combate3D` lo reconoce por `pj.id == "elemental_bosque"`. Sin eso solo sale con F8.
2. **Instante exacto del puñetazo** dentro de `attack`: el Juego usa 0,60; dímelo si cae distinto (constante `ELEM_MOMENTO_GOLPE`).
3. **Arte opcional:** brillo curativo (ahora es un tinte verde), VFX de «ignite» en el elemental, enredaderas más grandes (ahora ancho 1,6) y un aviso de zona del puñetazo.
**Decisiones mías, por si Pablo quiere cambiarlas:** 2 enredaderas; el elemental no lleva `resiste`; aturdimiento y viento no lo afectan; «la barrera de agua no lo protege» lo he leído como «no tiene inmunidad al agua más allá de no mojarse». **Sin probar con la cámara del juego:** el aspecto del brillo, la barra y el anillo del puñetazo. — Juego

## 8/10 14:05 — Pipeline: clip de golpe de fuego del elemental de bosque
Añadido el clip de Meshy «Hit_Fire_Reaction» a `poc_25d/elemental_bosque.glb` (ahora 4 MB, 7 clips). Dentro del GLB se llama **`hit_fire`** y dura **4,71 s** (Meshy lo trae como `Electrocution_Reaction`: el bicho se sacude entero; es largo). La cadera no se arrastra (0,07, dentro del límite).
- `Pj3D`: `CLIPS_DE["elemental_bosque"] = {"hit": "hit_fire"}` y `hit` pasa a `MINIMOS["elemental"]`: `jugar("hit")` lo reproduce sin tocar nada más.
- **Juego:** tu entrada del 13:45 dice que el elemental no usa `hit`. Si quieres usarlo, por ejemplo al recibir fuego (×2), pide `hit` o `hit_fire`. 4,7 s es mucho para un jefe que acosa: puedes cortarlo a ~1,5–2 s (`Pj3D` permite parar el clip) o reproducirlo solo la primera vez que arde. Decisión tuya.
- Probado en la nube: arranca, el modelo se ve bien y la validación no da avisos nuevos. — Pipeline


## 8/10 15:50 — Pipeline: grietas del puñetazo (`Vfx3D.grietas`) y entradas del diario repuestas
- **Nuevo:** `Vfx3D.grietas(suelo: Vector3, radio: float, dura: float = 2.2) -> Node3D`. Pega en el suelo una imagen plana (`poc_25d/vfx/grietas_impacto.png`, 1024², círculo de tierra agrietada con matojos y piedrecitas; la lámina de Pablo con la perspectiva deshecha). Entra con golpe de escala (0,12 s), se queda y se desvanece en el último 40 % de `dura`; se borra sola. Giro distinto según el punto. Plana a propósito: es una marca en el suelo. Para el puñetazo del elemental: `fx.grietas(punto_del_golpe, 1.4)` (el área de daño es 2,8 × 1,3; ajusta `radio` a lo que veas). Probado en la nube: apoya en el suelo y desaparece sin dejar nodos.
- **Pendiente de Pablo:** de la misma lámina quedan 3 piezas para 3D (escombros, enredadera espinosa y restos quemados, que forman la pareja viva/quemada de una enredadera grande). Cuando las pase por Meshy las integro.
- **Aviso:** el `DIARIO.md` de esta copia había vuelto a una versión anterior y faltaban las entradas del 8/10 13:45 (Juego) y 14:05 (Pipeline). Las he repuesto desde mi copia, sin tocar su contenido (comparado por diff: lo que había en el archivo está contenido en lo repuesto). Si falta algo más en vuestra copia, revisad con `git log -p docs/DIARIO.md`. — Pipeline

## 8/10 16:40 — Pipeline: enredadera espinosa (Meshy «Thornvine and Ashes») como variante de `Enredadera3D`
- **Nuevo GLB:** `poc_25d/meshy/enredadera/enredadera_espinosa.glb` (1,5 MB). El de Meshy traía la enredadera espinosa y los restos quemados lado a lado sobre una placa de suelo que sobraba; los he separado en dos mallas, `viva` (8 814 tris) y `quemada` (5 736 tris), sin la placa, apoyadas en y = 0.
- **Uso:** `e.preparar(fx, ancho, "espinosa")` (tercer parámetro opcional; sin él, la enredadera de siempre). `ancho` sigue siendo el ancho en el mundo (la viva espinosa mide 0,767 en el GLB y el nodo lo escala). Mismo ciclo, mismas señales y mismos 5 focos. Probado en la nube.
- **Para el Juego:** si quieres una enredadera más grande y hostil (p. ej. la del elemental potenciado), pasa `"espinosa"`. Es un cambio de una línea en vuestra llamada.
- **Calidad (dicho sin adornos):** la viva se ve bien, aunque Meshy ha dejado las hojas como bolitas y alguna espina suelta; la quemada es sobre todo un montón de piedrecitas con unos pinchos oscuros: no se parece a la lámina de restos quemados (la ceniza gris estaba horneada en la textura de la placa que he quitado). Sirve, pero si Pablo la quiere mejor hay que regenerar solo los restos. — Pipeline

## 8/10 20:05 — Juego (con Pablo): Fase 8, glifos como geometría; y estado del elemental en la copia de `pablo`
**Decisión (Pablo, 8/10):** el documento *Diseño matemático de glifos 3D* sustituye a la semántica v2 de §3 (la 5.4 queda sustituida). La esfera es la forma por defecto (sin glifo; el círculo queda para Barrera), el radio lo da un glifo nuevo **Tamaño**, y la etapa 1 son cinco glifos: **Línea, Altura, Tamaño, Flecha, Barrera**. Detalle en `DISENO_FUTURO.md` §3b; tareas en `PLAN_ARREGLOS.md` Fase 8 (8.0–8.12).
- **Juego:** 8.4–8.9. Los nombres de forma de `Receta3D.forma()` se conservan: `Vfx3D`/`Formas3D` no cambian salvo la forma nueva `arco`.
- **Pipeline:** 8.10 (las formas leen `radio`/`largo`/`alto`; forma `arco`) y 8.11 (iconos `altura`, `tamano`, `linea`).
- **Pablo:** 8.1 (confirmar flecha = alcance, fuera «pulso + flecha = curva», fuera amplificar/retardo/atracción/espejo en 3D), 8.2 (`sigils.gd`), 8.3 (gestos: propuesta Altura = `⊥`, Tamaño = `+`).

**Medido en `C:\Users\pablo\Documents\magic-symbols` (equipo `desktop-gsqgpnk`) a las 19:55, para Pipeline:**
- El código del Juego del elemental **sí está** (`combate_3d.gd` con `ELEM_*`, F8 en `jugador_3d.gd`). Se puede probar con F8.
- Los GLB y PNG de las entradas del Pipeline de 14:05, 15:50 y 16:40 **sí están** (`elemental_bosque.glb`, `enredadera_espinosa.glb`, `vfx/grietas_impacto.png`), **pero su código no**: `pj_3d.gd` no tiene `CLIPS_DE["elemental_bosque"]` ni `hit` en `MINIMOS["elemental"]`; `vfx_3d.gd` no tiene `func grietas` (fecha del archivo: 7/10 23:18); `enredadera_3d.gd` no acepta `"espinosa"`. **Pipeline: vuelve a subir esos tres `.gd` desde tu copia.** No es grave para probar: el Juego no llama a ninguno de los tres.
- Tampoco está la letra de marcador del elemental (pedido 1 del Juego, 13:45): de momento solo sale con F8.
— Juego

## 8/10 20:30 — Pipeline: repuesto el código que faltaba, elemental a 2,5 y letra `G` en el mapa
Hecho en `C:\Users\pablo\Documents\magic-symbols` (`desktop-gsqgpnk`), con cambios parciales sobre vuestros archivos (diff comprobado: solo líneas del Pipeline; nada del Juego pisado).
- **`pj_3d.gd`:** `CLIPS_DE["elemental_bosque"] = {"hit": "hit_fire"}` y `"hit"` en `MINIMOS["elemental"]`. **`elemental_bosque.glb`** actualizado (faltaba el clip `hit_fire`: el de la copia era el anterior, sin él).
- **`vfx_3d.gd`:** `func grietas(suelo, radio, dura = 2.2)` (imagen `vfx/grietas_impacto.png`, que ya estaba).
- **`enredadera_3d.gd`:** `preparar(fx, ancho, "espinosa")` (el GLB ya estaba).
- **`prueba_test2.gd`:** `ALTO_PJ["elemental_bosque"]` de 1,7 a **2,5** (pedido de Pablo; el Juego escala golpe, rango y colisión con eso). **Letra `G`** (nuevo): `const PJ_ELEMENTAL` y un caso `"G"` que crea el elemental con `_personaje` y lo mete en `_goblins`; el Jugador3D le cuelga su `Combate3D` al arrancar (`equipar` reconoce el id), igual que a los goblins. No hace falta tocar `combate_3d.gd`.
- **`marcador_3d.gd`:** `"G": {"grupo": "goblin", "tipo": "elemental", "rotulo": "ELEMENTAL DE BOSQUE", ...}`, como pedía el diario. Pablo: para colocarlo en un nivel, pon un marcador con letra `G` donde quieras que aparezca.
- **Sin probar en vuestro Godot** (la nube no tiene vuestro `Jugador3D`/`Combate3D` actuales): comprobad que un nivel con una `G` hace salir un elemental de 2,5 de alto que ataca y se cura. **Juego:** si el radio de la cápsula (0,7) o la altura de colisión no escalan con 2,5, es cosa vuestra (`combate_3d.gd`). — Pipeline

### 8/10 21:00 — Juego: elemental a 2,5 u y 8.4 `GeometriaHechizo`
- **`combate_3d.gd` (elemental escala con su altura).** Nueva `ELEM_ALTO_REF = 1.7` (la altura para la que se midieron las cosas) y `_k_ref() = altura / ELEM_ALTO_REF`. Escalan con ella: radio de la cápsula (0,7), `ELEM_RANGO`, alcance y ancho del puñetazo y la distancia a la que brotan las enredaderas (`1,7 + 0,35`). `_factor_tamano()` (agua) no cambia. Con 1,7 u todo queda idéntico a antes.
- **Medido en headless a 2,5 u:** k = 1,47, radio de cápsula 1,03. Con agua (×1,25 → 3,13 u): k = 1,84, radio efectivo 1,29 (diámetro 2,57 vs casilla 2,3). El movimiento es por el centro, así que no se atasca; las 2 enredaderas brotan. **No he podido mirar el encuadre de la cámara ortográfica** (headless); Pablo/Pipeline: comprobad en un nivel con `G` que el elemental con agua (3,1 u) cabe en pantalla.
- **`lanzador_3d.gd`, 8.4:** clase `GeometriaHechizo` junto a `Receta3D`. `evaluar(contadores, max_y)` con `{linea, altura, tamano, flecha, barrera}` devuelve `{base, nombre, radio, largo, alto, alcance, envuelve, bloquea, resistencia, proyectil, y_tope, valida, aviso}` en casillas, en el orden base → Altura → Tamaño → Barrera → Flecha → tope Y. Sin nodos. Prueba headless: 19 filas de la tabla (esfera sola, proyectil, corro, columna, muro, muro alto, muro que avanza, arco, bola grande, topes de Tamaño/Flecha/Barrera, tope Y) y 300 barajas del orden de dibujo dan lo mismo. 0 fallos.
- **Decisiones mías que Pablo puede cambiar:** (1) `proyectil` = lo que viaja (Flecha) sin envolver al jugador; **Línea + Flecha (muro que avanza) cuenta como proyectil** y no entra en el tope Y. (2) Flecha + Barrera: la Flecha se ignora (no se traslada algo que va alrededor del jugador). (3) `bloquea` = Barrera, literal; hoy la Línea sola bloquea proyectiles, eso se decide en 8.5. (4) Grosor de la línea 0,5 casilla fijo; Tamaño no lo toca. (5) Tamaño tope ×3: esfera 0,5→1,5 casillas (2 usos), línea 3→9 (3 usos).
- **Para el Pipeline (8.10):** las claves que leerán los VFX son `radio`, `largo`, `alto` (casillas) y `nombre`, que añade `arco` al vocabulario actual (`proyectil`, `corro`, `columna`, `muro`, `punto`).
- **Espero a Pablo:** 8.1 (confirmar flechas = alcance, quitar «pulso+flecha=curva», amplificar/retardo/atracción/espejo fuera del 3D) para empezar 8.5. — Juego

### 8/10 21:05 — Pipeline — Elemental: tirones y animaciones «atascadas»
- **Causa en el Pipeline (arreglada en `pj_3d.gd`):** (1) `Pj3D.jugar` cambiaba de clip con `play(clip)` sin mezcla: salto seco de pose (la cadera pasa de 0,81 en idle a 0,65 en walk). Ahora mezcla `MEZCLA_CLIPS = 0.15` s para todos los personajes. (2) Los clips `attack`, `walk` y `hit_fire` del elemental arrastran la cadera (attack +0,3 y acaba 8 cm fuera; walk ±0,33; hit_fire acaba 7 cm atrás), y al cambiar de clip el modelo saltaba. Se les quita el desplazamiento horizontal de la cadera al cargar (`_anular_raiz`, el mismo mecanismo que `roll`); desaparece el aviso «arrastra la cadera» de `attack`. Los bucles de walk/idle/run/cast son continuos (medido: último fotograma = primero).
- **Para el Juego (`combate_3d.gd`, no lo toco), medido leyendo el código:** (a) `_ia`: con `_ataque > 0` pone `moviendo = 0` y vuelve; el ataque dura todo el clip (3 s a vel. 1), así que si el jugador se aleja el elemental se queda clavado en la pose hasta que acaba (sin `_cancelar_ataque` por distancia): ese es el «se atasca cuando el jugador se aleja». Propuesta: cancelar o dejar de esperar si el jugador sale de `rango` + margen. (b) En el borde del rango `moviendo` alterna 0/2 (atacar ↔ perseguir) y reinicia clips; conviene histéresis (rango de entrada < rango de salida). (c) `walk` dura 5,5 s: a velocidad 1 los pies resbalan; ajustar `set_velocidad_animacion` en `_animar` según la velocidad real si se ve patinar. (d) Con `stun_timer`/`congelado` `_animar` no cambia de clip: puede quedarse en el último fotograma de attack/cast.
- Sin probar en el Godot de Pablo. — Pipeline

### 8/10 21:45 — Juego: IA del elemental y del goblin (4 fallos revisados)
Todo en `combate_3d.gd`, probado en headless con el elemental (el goblin comparte código):
- **Ataque sin cancelar:** nuevo `_golpe_pendiente`. Si el jugador pasa de `rango × 1,4` antes de que salga el golpe, se cancela el ataque (`_cancelar_ataque`) y vuelve a perseguir. Una vez salido el golpe se deja acabar la animación. No afecta al arquero. Medido: tras alejarse, `_ataque = 0` y `moviendo = 1`.
- **Alternancia en el borde:** histéresis `_en_rango`: entra a `rango`, sale a `rango × 1,2` (`HISTERESIS_RANGO`). Medido: a 1,1×rango sigue atacando, a 1,5× sale. El goblin sigue conectando (su `_conectar` llega a rango+0,5 = 1,7 > 1,2×1,2).
- **Pies resbalando (solo elemental):** `_animar` ajusta `set_velocidad_animacion` en `walk` = `velocidad real × duración del clip / ELEM_ZANCADA_WALK`, entre 0,5 y 2,5. **`ELEM_ZANCADA_WALK = 5.0` es una estimación mía** (no he podido medir cuánto avanza el clip): hay que afinarla a ojo en el juego (más alta = pasos más lentos). El goblin no se toca: no conozco su zancada.
- **Aturdido:** en stun pasa a `idle` en vez de quedarse en el último fotograma de attack/cast. Congelado sigue quedándose en la pose a propósito (velocidad 0). El elemental es inmune a stun.
— Juego

### 8/10 22:30 — Juego: 8.5, 8.6, 8.7 y 8.8 hechas (probadas en headless)
Todo en `poc_25d/lanzador_3d.gd`; casillas 8.4–8.8 marcadas en `PLAN_ARREGLOS.md`.
- **8.5:** `Receta3D` cuenta los cinco glifos (`contadores`). Sin glifos antiguos (levitación, repetición, rebote, pulso, amplificar… → `antigua = true`) usa `GeometriaHechizo` (`usa_geo()`): `forma()` sale de `geo().nombre` y `manifestaciones()` de la rasterización; con algún glifo antiguo todo sigue como hoy (probado). Los indicadores antiguos (`travels`, `spread`, `blocks`, `height`) se derivan de la geometría (`_sincronizar`), así que campos, barridos y cúpula no cambian. Nombres de forma intactos + `arco`. 2D sin tocar.
- **Bloqueo por material (decisión 3):** Barrera siempre bloquea; Línea sin Barrera solo con tierra o hielo (`_crear_campo`). Probado.
- **Flecha = alcance (8.1a):** 3 casillas, +1 por flecha, tope 5 (probado: 3 flechas → 5). **Barrera repetida = resistencia:** escudo `60 × 1,5^(n-1)`, tope ×3 (3 barreras → 135); el aro ya no crece. `SELLOS_TEST3` sin amplificar/atraccion/espejo (8.1c).
- **8.6:** `GeometriaHechizo.celdas()` (estática, pura): una casilla cuenta si su **centro** cae dentro; la esfera siempre incluye la casilla del jugador; línea = banda de 1 casilla a 1,5 delante; forma envolvente = banda hueca de 1 casilla a (radio+1) del jugador. Medido (2000 posiciones/ángulos al azar): la línea sale **siempre conexa (8 vecinos)**. **Limitación medida:** con la regla «centro dentro» una línea en diagonal cuenta cosas distintas según dónde esté el jugador en su casilla (largo 3: 2–5 casillas; largo 7 a 45°: 4–10; en los ejes siempre 3 y 7). Si molesta, la alternativa es dibujar la línea por las casillas que atraviesa (más estable, pero ya no es «centro dentro»). **Tope Y:** `cast_page` avisa («Demasiada altura: sube 2 niveles y solo se pueden pisar 1. No se lanza.») y no entra en modo lanzar (`cast_rechazado_altura` en el log).
- **8.7 `arco`:** Línea + Barrera = banda hueca alrededor del jugador limitada a un arco de ancho `largo` centrado en la mirada; bloquea. A `Jugador3D`/`Vfx3D` se les pasa `forma_vfx()` = `"muro"` hasta que el Pipeline tenga `arco` (8.10).
- **8.8:** en modo lanzar se dibuja una caja translúcida por casilla (con su altura; roja si la receta no vale) y los proyectiles alargan la flecha hasta su alcance. Para el libro: `Lanzador3D.aviso_receta(glifos: Array) -> String` (estática). **Pablo:** si quieres el aviso al cerrar el libro, `spellbook.gd` (tuyo) llama a esa función.
- **Limitaciones:** (a) Tamaño en un proyectil agranda lo dibujado (radio ×1…×3) pero el golpe sigue siendo un rayo sin grosor. (b) Tierra + Altura no apila más de un bloque. (c) El muro que avanza (Línea+Flecha) no dejó campo vivo en mi prueba, tampoco con la ruta antigua: no es regresión, pero hay que mirarlo en el juego. (d) La cúpula dibujada pasa de 1,4 a 1,5 casillas de radio. — Juego

### 8/10 22:40 — Juego: la altura de un nivel sale del mundo (probar con 0,5 casilla)
Pablo pide probar con un nivel = 0,5 del lado de la casilla (hoy 0,45). `Lanzador3D.ALTO_NIVEL` era una constante duplicada; ahora es `static var` y `configurar()` la iguala al `ALTO` de `prueba_test2.gd`. Comprobado con `ALTO = S * 0.5`: 1,15 u (ratio 0,5). **Pipeline:** para el cambio hay que poner `const ALTO: float = S * 0.5` en `prueba_test2.gd` (tuyo; yo no lo toco). — Juego

### 8/10 22:55 — Juego: parche de glifos fuera, altura y tamano en el Test 3, y la paleta F1 en 3D
- **Quitado `Receta3D.GLIFOS_PARCHE` y `RECARGA_PARCHE`:** con 8.2 hecha, `linea`, `altura` y `tamano` los conoce `Repertoire`; la recarga sale de `Sigils.FORM` (altura 2,0, tamano 1,5, comprobado). `SELLOS_TEST3` ya lleva `altura` y `tamano`.
- **La paleta F1 NO estaba montada en `PruebaJugabilidad3D`** (solo en `Blockout` y `TestJugabilidad`); allí F1 era el atajo de fuego de `prueba_test2.gd`. La he montado en `Lanzador3D.construir_interfaz` (const `PALETA_RUNAS`, igual que en esos dos). Comprobado en headless: la paleta enseña **Linea, Altura y Tamano**, F1 la oculta y ya no lanza el fuego de prueba (el Lanzador consume la tecla antes).
- **Descubierto al probar: la regla «un glifo por sector» deja la paleta inservible para recetas de varios glifos** (la paleta pone todo en el sector de la derecha y el segundo se rechaza con «Hueco ocupado»). Arreglado solo para la paleta: `Lanzador3D.place_sigil` reparte los glifos por los 8 sectores en orden. Comprobado: Fuego + Línea + Altura + Tamano + Tamano → muro de largo 7, alto 1, válido. **Pablo, ojo de diseño:** con ocho sectores y esa regla, repetir un glifo (Tamaño ×2, Flecha ×3, Barrera ×3) gasta un sector cada vez; una receta como «Línea + Altura + Tamaño×2 + Flecha×3» ocupa 7 de 8. Quizá convenga decidirlo antes del playtest 8.12.
- **Pendiente del Pipeline:** cuando avise de que `arco` existe en `Vfx3D`/animación de lanzar, cambio `forma_vfx()` (una línea). — Juego

### 8/10 23:20 — Juego: progresión en el libro (primer nivel: 1 sello, 2 glifos, 1 página)
Pedido de Pablo («que se refleje la progresión y los libros disponibles»; nivel 1 = **Fuego + Flecha + Barrera**, **una página**, como mucho 2 glifos en ella). Vocabulario del diseño: sello = elemento, glifo = forma.
- **Lo que ya hacía el libro:** la leyenda solo enseña los sellos y glifos activos en `Repertoire`. Lo que faltaba era decidir QUÉ está activo en 3D (`Lanzador3D._ready` abría siempre todo el Test 3) y que las **páginas** también dependieran de la progresión.
- **`repertoire.gd`:** `Repertoire.max_pages` (0 = todas) y `Repertoire.pages_available(total)`.
- **`spellbook.gd`** (permiso explícito de Pablo): las pestañas de página solo pintan las que tienes, y las teclas 1/2/3 con el libro abierto ignoran las que no. **`page_hud.gd`:** lo mismo en las bolitas del HUD.
- **`poc_25d/lanzador_3d.gd`:** tabla `PROGRESIONES` (`todo` = banco de pruebas de siempre, 3 páginas y 6 glifos por página; `nivel1`), `aplicar_progresion(nombre)` (estática), que se elige por el nombre del nivel (`mundo.nivel`; desconocido → `todo`), y `PROGRESION_FORZADA` para probar un nivel sin tocar el mundo. `select_page` y `cast_page` rechazan páginas que no tienes.
- **Probado en headless:** `todo` → 6 sellos, 9 glifos, 3 páginas (idéntico a antes). Forzando `nivel1` → sellos [fuego], glifos [flecha, barrera], 1 página, 2 glifos por página; elegir o lanzar la página 2 o 3 no hace nada. **No he podido ver el libro dibujado** (headless): mirad que solo sale una pestaña.
- **Pablo — para probarlo:** pon `PROGRESION_FORZADA = "nivel1"` en `lanzador_3d.gd`, o llama al nivel `nivel1`. Hoy `PruebaJugabilidad3D` se llama `jugabilidad` y sigue con todo, para no quitarte el banco de pruebas. Cuando se abran premios (la hierba da agua + barrera, etc.) basta con `Repertoire.unlock_*` y subir `Repertoire.max_pages`; `progresion.gd` (2D) no se ha tocado. La paleta F1 sigue ofreciendo las 3 páginas (es una herramienta de prueba). — Juego

### 9/10 09:50 — Juego: línea sola = chorro (haz desde la mano); línea + altura = muro. Contrato forma ← receta
Encargo de Pablo. Cambio en `poc_25d/lanzador_3d.gd` (solo ese archivo). **Probado en headless** (formas, casillas, vida; 360 direcciones); **no he visto el dibujo en el juego**.
- **Qué forma sale de cada receta (Fase 8):** línea sola → `chorro` · línea + tamaño → `chorro` más largo · **línea + flecha → `chorro` más largo** (decisión de Pablo hoy: la Flecha ALARGA el haz, +1 casilla por flecha, tope 9; ya no lo traslada) · línea + altura → `muro` (alto) · línea + altura + flecha → `muro` que avanza (como hoy) · línea + barrera → `arco` · flecha sola → `proyectil` · barrera sola → `corro` (`cupula` si es la barrera quieta) · altura sola → `columna`. Receta con algún glifo que NO es de la etapa 1 (levitación, rebote, pulso…): sigue en la vía antigua y `línea` ahí sigue siendo `muro` (su geometría es la pared de siempre; un «chorro» dibujado sobre una pared no coincidiría con lo que daña).
- **Geometría del haz:** `GeometriaHechizo.celdas` recorre el rayo de la mano hacia delante (de 0,5 a 0,5 + largo casillas) y toma las casillas que atraviesa, sin la del lanzador: 3-6 casillas según el ángulo (más en diagonal). Largo base 3, +2 por Tamaño. El haz no se traslada (`travels = false`), así que no es muro móvil.
- **Vida del haz = lo que dura el dibujo:** `VIDA_CHORRO` = 1,6 s (× calidad). `_visual_campo` llama a `lanzar_forma("chorro", el, pie_mano, pie_mano + dir·largo, {largo, dura = vida del campo})`; el muro sigue con `lanzar_forma("muro", …)`; `colocar_barreras` no cambia (usa su propia ruta de marcadores).
- **Suelo (ESTADOS_SUELO §4.1/§4.2):** el haz marca sus casillas al nacer con `marcar_celda → _al_impactar`, igual que el muro y que el impacto de la flecha. Según `PruebaTest2`: el fuego **solo quema (R) hierba**; en suelo neutro no escribe R (solo deshiela y seca charcos con vapor). **Para el Pipeline:** el quemado del haz debe pintarse únicamente sobre casillas de hierba; en suelo neutro no hay quemado. No he comprobado en vivo que flecha, haz y muro marquen la misma casilla; está leído en el código, no medido en partida.
- **Tierra e hielo** (decisión de Pablo: «chorro también»): salen como `chorro` pero su campo sigue bloqueando proyectiles durante su vida (decisión 3 del 8/10), y la tierra sigue levantando bloques en sus casillas (como el muro de línea). Si no se ve bien, se revisa con el dibujo delante.
- **Animación de lanzar:** `forma_vfx()` (lo que va a `lanzar_clip`/`apuntar_lanzar`): `chorro` → `proyectil` (lanzamiento horizontal); `muro` con línea + altura → `columna` (brazos alzados); el resto igual. `Pj3D.ANIM_CAST` no se toca (es del Pipeline).
- **Pide al Pipeline:** (1) opcional, `ANIM_CAST["chorro"]` propio en `pj_3d.gd`; cuando exista, quito el rodeo de `forma_vfx()` (una línea). (2) Revisar el `chorro` de `Vfx3D` para `tierra` e `hielo` (ahora recibe esos elementos) y que `largo` en metros llegue hasta la última casilla.
- **Pablo:** la copia `GitHub\magic-symbols` está atrasada (sin Fase 8); se trabajó en `Documents\magic-symbols`. El 23:50 del 8/10 (libro nivel 1: `Spellbook.LIBROS`, `Repertoire.libro`) estaba en el otro equipo y su entrada no está en este diario; el código sí está aquí.
— Juego

## 9/10 09:50 — Pipeline: fuego luminoso aditivo (prototipo para aprobar)
- **Qué es:** el estilo nuevo del fuego (referencias de `Documents\Arte`: `Flecha_fuego`, `Linea_Fuego`, `Barrera_Fuego`, `Muro_fuego`), que sustituye al facetado de tres tonos SOLO para el fuego. Los demás elementos no se tocan. **Por defecto sale el estilo viejo** (`Vfx3D.estilo_fuego_nuevo = false`; en `prueba_test2.gd`, `fuego_nuevo = false`) hasta que Pablo lo apruebe.
- **Archivos:** nuevo `poc_25d/fuego_3d.gd` (`Fuego3D`, todo el kit, funciones estáticas); enganches pequeños en `vfx_3d.gd` (la propiedad, `precalentar`, `lanzar`, `_proyectil`, `_impacto_fuego`, `_chorro_forma`, `_cupula`, `_muro`, `fuego_pared`); `lab_vfx_3d.gd` (teclas) y `prueba_test2.gd` (propiedad `fuego_nuevo` y bloom). `lanzador_3d.gd` no se toca.
- **Para compararlo (Lab):** **Y** alterna estilo viejo/nuevo en el mismo sitio (el Lab arranca con el nuevo) · **K** apaga/enciende el bloom (para ver que el agua y el hielo no brillan) · el HUD enseña el estilo, el bloom y los FPS. Usa **F** para elegir forma (proyectil, chorro, cúpula, muro) y 1 para fuego.
- **Kit (reutilizable para otros elementos cambiando la rampa: `Fuego3D.rampa_de(elemento)` + `TONOS_RAMPA`):** (1) shader `spatial` de llama `unshaded, blend_add, depth_draw_never, cull_disabled` con ruido sin costuras que se desplaza, erosión con `smoothstep`, rampa de color y `brillo` en HDR; uniforms: `erosion, suave, brillo, calor_max, eje, potencia, base_min, lateral, corte, fade, ondula…`; (2) primitivas de Godot con ese shader: esfera (bola), conos (cola), cilindro (haz), cintas de `ArrayMesh` (aro de la cúpula), media esfera (cúpula) y quads verticales (muro); (3) pocas partículas: brasas aditivas y chispas alargadas (ver limitaciones); (4) `Decal` de luz naranja bajo el hechizo y `Decal` de quemado oscuro; (5) `OmniLight3D` con parpadeo y `Fuego3D.activar_glow(env)`. El ruido es una imagen de `FastNoiseLite.get_seamless_image` (no `NoiseTexture2D`: este genera en otro hilo y deja unos fotogramas la llama sin textura).
- **Los cuatro hechizos:** *Flecha* (`proyectil`): llamita en la mano 0,15 s (la bola sale después de ese retraso) → bola con núcleo y envoltura que se deshace + cola de cometa de tres conos que se estira con `velocidad` → impacto con 6 lenguas verticales en estrella, anillo de luz, destello, charco de luz, quemado, brasas y chispas; emite `impacto` como siempre. *Línea sola* (`chorro`, forma nueva para la línea): haz de la mano al suelo a `largo` (4 por defecto) con dos capas, el ruido avanza por el cilindro y los vértices ondulan; crece desde la mano en 0,25 s y en el extremo arde el impacto en bucle mientras dure (`dura`). *Barrera* (`cupula`): 3 cintas curvas que giran y convergen en un aro en el suelo, y luego media esfera que sube con corte por altura, borde brillante por fresnel y el interior erosionado; la raíz nace en `centro`, así que el Lanzador puede seguir moviéndola como la de siempre. *Línea + levitación* (`muro`): chispas en arco → llamas bajas a lo largo de la línea → la tira crece con la erosión bajando. La pared larga que dibuja `fuego_pared` (7.11, la de `BarreraFuego`) usa también esa tira, una por casilla y solapadas un 12 % para que no se vean las juntas; la lógica de tramos, luces y `apagar_tramo` no cambia.
- **Medido (nube, Godot 4.7, Compatibilidad en software, así que sirve para comparar, no como FPS reales):** tiempo por fotograma con la escena vacía 34,0 ms; con cúpula + muro de fuego a la vez: **viejo 43,4 ms (+9)**, **nuevo 57,8 ms (+24)**. Por separado, cúpula viejo +6,8 / nuevo +17,7 y muro viejo +4,7 / nuevo +15 (el muro con 3 capas; ahora lleva 1 capa por superficie, que es lo que pedía el encargo). Son superficies grandes aditivas: lo caro es el relleno de píxeles, no la geometría. **Mídelo en tu GPU con el Lab** (cúpula + muro a la vez: F hasta cúpula, 1, F hasta muro, 1). Si pesa, el recorte más fácil es bajar `radial_segments` de la cúpula o reducir su resolución de ruido.
- **Lo que NO he podido comprobar:** el **bloom**. Mi sandbox no tiene Vulkan (solo Compatibilidad, que no tiene HDR: ahí el bloom lava toda la escena, por eso `activar_glow` no hace nada en Compatibilidad). Umbral HDR de 1,4 (luminancia): solo lo superan los corazones del fuego (blanco-amarillo a `brillo` ≈ 2,2); el cuerpo naranja va a ≈ 1,3 con tono capado, y el agua, los cristales y el suelo de la maqueta quedan en ≈ 1,0. **Hay que mirarlo en Forward+**: si el suelo claro o el agua brillan, sube `glow_hdr_threshold` en `Fuego3D.activar_glow`; si el fuego no brilla lo bastante, sube el `brillo` de los núcleos. Los **Decal** se comprobaron en Forward+ solo en teoría: en Compatibilidad no se dibujan, así que ahí el charco y el quemado caen a un plano plano pegado al suelo (`_usa_decal()`), que es lo que he visto.
- **Limitaciones, sin adornos:** las «chispas con estela» son quads alargados que siguen su velocidad, no `RibbonTrailMesh` (más caro y lo quiero ver aprobado antes). Los Decal proyectan sobre cualquier superficie de la capa 1, incluidos los personajes si pasan por debajo; si molesta, `cull_mask` en `charco`/`chamusco`. El corro, el arco, la onda y la columna de fuego siguen con el estilo viejo (no estaban en el encargo). `fuego_fijo` (antorchas) también.
- **Para el Juego/Pablo:** nada que cambiar en `lanzador_3d.gd` para ver el prototipo. Cuando Pablo lo apruebe, `fx.estilo_fuego_nuevo = true` (o `fuego_nuevo` en el inspector de `prueba_test2`). Para la Línea sola, el Juego tiene que pedir la forma `"chorro"` con `{"largo": …, "dura": …}` (hoy la Línea sola sale como `muro`; eso lo decide el Lanzador).
- **Aviso:** la copia `C:\Users\paranda\Documents\GitHub\magic-symbols` va por detrás de la de `Documents\magic-symbols`; he trabajado en esta última, como pidió Pablo. Esta máquina lleva `vfx_3d.gd` sin el `arco` (8.10); mis enganches están hechos con parches anclados que no dependen de él. — Pipeline

## 9/10 10:15 — Pipeline: fuego luminoso, más naranja y rojo (feedback de Pablo)
- Pablo lo ha probado en el Lab (Forward+): la forma está bien, pero se veía amarillo-blanco lavado. Cambios solo en `fuego_3d.gd`: rampa más naranja-roja; bola con contorno rojo-naranja ancho (`calor_max` 0,5, borde más suave) y un corazón amarillo más pequeño; cola, lenguas, haz, cúpula y muro también con `calor_max` ≈ 0,5 y `brillo` ≈ 1,0; brasas y chispas naranjas en vez de amarillo pálido; bloom más contenido (umbral HDR 1,6 e intensidad 0,55). No cambia ninguna firma. — Pipeline

## 9/10 10:40 — Pipeline: fuego luminoso, degradado naranja (feedback de Pablo, 10:22)
- Pablo pidió más naranja y un degradado: un núcleo naranja pequeño y naranjas cada vez más oscuros hacia fuera. Cambios solo en `fuego_3d.gd`:
  - **Rampa sin blanco ni amarillo:** del rojo oscuro (borde) al naranja vivo (corazón).
  - **La llama pasa de `blend_add` a `blend_mix`.** Medido: sumado sobre la hierba clara, cualquier naranja viraba a amarillo (0,8·(1, 0,48, 0,08) + hierba ≈ (1,27, 0,88, 0,39)); con mezcla el naranja se ve tal cual sobre cualquier suelo. El borde más frío es también el más transparente, así que el contorno se deshace. `brillo` > 1 sigue alimentando el bloom. El anillo de luz, las brasas, el destello y el charco siguen aditivos (son luz).
  - **Bola:** envoltura naranja-roja con degradado hacia el borde, núcleo naranja vivo pequeño encima (`render_priority`), cola por debajo y empezando detrás de la bola.
  - Nuevo uniform `peso_ruido` (cuánto manda el ruido frente al degradado).
- Probado en la nube (Compatibilidad) con las cuatro formas: todas en la misma paleta. **Aviso:** esto se aparta del «aditivo» del encargo; si Pablo quiere volver a aditivo, es una línea (`render_mode`) en `CODIGO`, pero sobre suelo claro volverá a amarillear. — Pipeline

## 9/10 10:50 — Pipeline: fuego luminoso, paleta de la lámina `Flecha_fuego` y contorno que se mueve (feedback de Pablo, 10:30)
- Pablo: lo de las 10:40 tenía demasiado rojo y naranja; la referencia es su lámina `Flecha_fuego`. Cambios solo en `fuego_3d.gd`:
  - **Rampa nueva:** corazón crema-amarillo pálido grande → amarillo cálido → naranja solo en el contorno. Ya no hay rojos oscuros.
  - **Se queda la mezcla (`blend_mix`) de las 10:40**, para que los colores no se laven sobre la hierba clara. El contorno ya no se hace transparente: es la franja naranja.
  - **Contoneo:** el vertex shader desplaza la superficie con una onda más un ruido que se mueve (`ondula`, `ondula_freq`), así la silueta baila como una llama. Lo llevan la bola, la cola, las lenguas del impacto, las cintas de la cúpula y el muro.
  - La cola empieza pegada a la bola. Brasas y chispas en amarillo-naranja.
- Probado en la nube con las cuatro formas. — Pipeline

## 9/10 11:05 — Pipeline: fuego luminoso — la bola queda fijada; haz, cúpula y muro con sus ajustes
- **Fijado por Pablo (10:40):** la bola de las 10:50, con el Lab a tamaño ×0,6 y proyectil a 4,5 u/s.
- **Haz (Línea sola, `chorro`):** más grueso, como en la lámina `Linea_Fuego`: se ensancha de la mano hacia la punta. Mientras crece, avanza por delante la misma bola con cola que la flecha (fotograma 2 de la lámina). Sin rayas: las mallas cerradas (bola, cola y haz) usan ahora una variante del shader con `cull_back` (`"cerrado": true` en `material()`). Con mezcla y las dos caras, las de detrás salían a veces por encima y dejaban franjas.
- **Muro:** ahora son lenguas separadas y altas (más frecuencia horizontal del ruido, menos vertical y más caída hacia la punta). Antes era una nube.
- **Cúpula:** misma paleta y contoneo; sin cambios de forma.
- Probado en la nube a escala 0,6. Para verlos en el Lab: F hasta `chorro`, `cupula` o `muro` y pulsar 1. — Pipeline

## 9/10 11:20 — Pipeline: fuego luminoso — cuña del haz, muro arreglado y onda con ruido (feedback de Pablo, 10:54)
- **Muro («da error»: salía un rectángulo amarillo lleno):** era un `smoothstep` con los bordes al revés (`smoothstep(1.0, 0.96, x)`), que en GLSL es indefinido. En Compatibilidad funcionaba por casualidad y en Forward+ dejaba el quad entero opaco. Corregido a `1.0 - smoothstep(0.96, 1.0, x)`. Lección para todo el kit: siempre `edge0 < edge1`.
- **Haz:** cuña en el origen. El haz sale de una punta en la mano (cono corto) y se abre; antes salía cortado.
- **Onda (`onda`, y el corro que crece) de fuego:** nueva `Fuego3D.onda`. Es un aro de llamas cerrado (cinta de 360°) que nace en el centro y se abre hasta el radio, con el borde de arriba comido por el ruido y contoneándose; deja charco de luz y brasas. Enganche en `vfx_3d.gd`, en `_pulso_crece` (solo fuego con `estilo_fuego_nuevo`).
- Probado en la nube. — Pipeline

## 9/10 11:10 — Pipeline: haz de fuego con color homogéneo (Pablo, 11:02)
- Solo `Fuego3D.haz`. Las dos capas del haz (exterior y corazón) tenían distinto tope de rampa y brillo, y salían manchas claras y oscuras. Ahora llevan el mismo color (`calor_max` 0,92, `brillo` 1,1), menos peso del ruido (`peso_ruido` 0,4) y la punta se come menos (`base_min` 0,6). La forma no cambia. — Pipeline

## 9/10 11:15 — Pipeline: muro de fuego con grosor en Z (idea de Pablo, 11:04)
- El muro era un solo plano de grosor 0 en Z; visto de canto o en diagonal casi desaparece. Ahora `Fuego3D.muro` usa 3 capas separadas ±0,09 en Z (con ruido y velocidad distintos), lo que le da cuerpo desde cualquier ángulo. La pared persistente (`fuego_pared`) sigue con 1 capa. El rectángulo lleno de las 10:54 era otra cosa (el `smoothstep` al revés, ya corregido a las 11:20). — Pipeline

## 9/10 11:25 — Pipeline: prueba de pilar de fuego (Pablo, 11:07)
- Nueva `Fuego3D.pilar`: el muro con ancho y alto intercambiados (x ↔ y). Columna de llamas de 1,7 × escala de ancho y (2 × radio + 0,6) × escala de alto (en el Lab, 1,02 × 1,8), hecha con dos tiras cruzadas a 90° de 3 capas cada una. Lleva chispas desde la mano, brasas, luz y charco. Enganche en `vfx_3d.gd`, forma `"pilar"`, solo fuego con `estilo_fuego_nuevo`; si no, sigue `_columna`. Es una prueba; si gusta, se fija. — Pipeline

## 9/10 11:30 — Pipeline: pilar de fuego con ruido también en X (Pablo, 11:19)
- Nuevo uniform `lado_ruido` en el shader de llama: con > 0, la «altura» de la llama cae hacia los costados del quad y el ruido muerde los lados igual que la punta. Así el contorno es irregular en X y no solo en Y. `Fuego3D.tira` lo recibe como último parámetro (`lados`, 0 por defecto, así el muro no cambia). El pilar lo usa a 1,0. — Pipeline

## 12/10 (rev. 4) · Pipeline · Fuente eléctrica = cristal (modelo nuevo, amarillo con chispas)
- **Modelo nuevo:** `poc_25d/meshy/piezas/cristal_sanctuario.glb` (Meshy «Azure Crystal Sanctuary»). `Pieza3D` y `_pieza` (prueba_test2.gd) lo cargan directamente por nombre de archivo (`meshy/piezas/<id>.glb`), sin depender del nombre del nodo raíz. Medida: 1,4 de alto (`MEDIDA`).
- **Marcador `e`** (`marcador_3d.gd`, `LETRAS`): pieza `cristal_sanctuario` (antes `roca_cristal`). Ya no es el totem de piedra.
- **Juego (`prueba_test2.gd`):** `_colocar_letras` pone el emisor con `cristal_sanctuario`.
- **Amarillo** (`objetos_3d.gd`, `_tinte_amarillo`): al montar el emisor se pinta el modelo de amarillo con un brillo suave, en lugar del azul del modelo. Las chispas amarillas siguen siendo las de `_montar_emisor`.
- **Comportamiento:** igual que antes (mismo marcador `e`, mismo giro, misma electricidad por el canal azul). Solo cambia el modelo y su color.
- **Para Pablo:** el modelo ocupa más que el totem; si tapa el canal, baja `MEDIDA["cristal_sanctuario"]` en `pieza_3d.gd`.
Archivos: `pieza_3d.gd`, `objetos_3d.gd`, `prueba_test2.gd`, `marcador_3d.gd`, `meshy/piezas/cristal_sanctuario.glb`. — Pipeline

## 13/10 · Pipeline · Cauce: piedra y agua en la posición del marcador, con la textura de patio
- **Causa del desajuste:** los marcadores `-` y `L` se pintaban en el centro de su casilla y sin escala; el editor enseña el marcador tal cual (p. ej. `L_2_28` en x 5,77 / z 65,13 y escala 0,707 / 1,064). Ahora `prueba_test2.gd` guarda el transform real de cada canal (`_canal_tf`, en `_leer_nivel`) y la piedra (`_piedra_canal`) y el agua (`_canal_centro`) van ahí. El giro sigue saliendo de la vecindad (`_abre_hacia`), sin cambios.
- **Textura:** la piedra del canal usa `res://poc_25d/meshy/texturas/patio_musgo_albedo.jpg` (albedo del patio musgo, 1024). Solo cambia el material.
- **Para Pablo:** al abrir Godot se importa la textura nueva. Si el canal queda raro, dilo y ajusto la escala del agua (ahora usa solo posición; la escala del marcador afecta a la piedra, no al agua).
- Pendiente: baldosas de patio alrededor de las casillas de agua (no tocado aquí).
Archivos: `prueba_test2.gd`, `meshy/texturas/patio_musgo_albedo.jpg`. — Pipeline

## 13/10 (2) · Pipeline · Baldosas de patio en la zona del agua
- **Qué:** las casillas `-`, `L`, `u` y `e` (canal, tinaja y cristal) llevan una baldosa de patio con el albedo nuevo encima de la piedra caliza. `_construir_baldosas` (`prueba_test2.gd`) las pone tras el cauce seco.
- **Muro:** cada baldosa lleva un muro en el lado que da a la hierba (o a la tierra si no hay hierba). Sin tierra alrededor, va lisa.
- **Ajustes** en el código: `ALTO_MURO_BALDOSA` (0,3) y `GROSOR_MURO_BALDOSA` (0,5).
- **Para Pablo:** es una primera versión sin probar en Godot. Dime si el muro va al lado correcto y si la textura se repite demasiado.
Archivos: `prueba_test2.gd`. — Pipeline

## 13/10 (3) · Pipeline · Nivel horneado = editor (pasos 1 y 2)
- **Paso 1 (marcadores tal cual):** `prueba_test2.gd` guarda el transform real de todos los marcadores (`_marca_tf`). Las piezas de decorado (`_poner`) y las reactivas (`_reactivo_pieza`) se colocan con su posición, giro y escala, sin variación aleatoria. Solo afecta al nivel horneado (`Nivel_Bosque`).
- **Paso 2 (suelo del editor):** en el nivel horneado el suelo es una copia del GridMap `Suelo` (bloques planos de `suelo_tipos.tres`), en el mismo marco que los marcadores. Se oculta el suelo propio del juego (hierba, camino, tierra y orillas). Sigue el agua del juego, el cauce y el canal.
- **Qué no es 1:1 todavía:** el agua del canal (`Canal3D`) usa la posición del marcador, pero no su escala en X/Z (ancho del agua).
- **Para Pablo:** verifica en `PruebaBosque`. Si algún objeto no coincide, dime cuál.
Archivos: `prueba_test2.gd`. — Pipeline

## 13/10 (4) · Pipeline · Nivel_Bosque → PruebaBosque 1:1, comprobado en Godot
- **Cómo se ha medido:** proyecto completo en la nube (GitHub + lo nuevo del equipo), mismo encuadre y misma luz para `Nivel_Bosque` tal cual (vista del editor) y para `PruebaBosque`. Se comparan capturas y la caja de cada objeto. Las 365 piezas de decorado coinciden en posición, tamaño y altura (< 5 cm). El suelo es idéntico.
- **Arreglado (`prueba_test2.gd`):** el decorado va por lotes y `_poner` llenaba el lote con el centro de la casilla, sin la escala del marcador. Ahora usa el transform del marcador también en los lotes (el canal salía en otro sitio y con huecos). Personajes (goblins, elemental, NPC, jugador) y telarañas salen donde está su marcador (`_pos_marca`), no en el centro de la casilla.
- **Vista previa del editor (`marcador_3d.gd` + `pieza_3d.gd`):** el marcador dibuja lo mismo que pone el juego: la telaraña entera, el modelo de cada personaje con su alto (`PJ_*`, `ALTO_PJ`), la losa de agua como círculo rúnico, y el cristal amarillo con su luz. El tinte del cristal y la telaraña viven ahora en `Pieza3D` y los usan el juego y el editor.
- **Luz:** `niveles/luz_juego.tscn` (nuevo) tiene el entorno y el sol del juego con sus valores. Está instanciado en `Nivel_Bosque` para que el editor se vea con la misma luz. El juego no lo lee (solo lee suelo, piezas, marcadores y rótulos).
- **Corrección:** el cambio de `cell_center_x/z = false` del GridMap era un error (movía el suelo media casilla). Ya está revertido; el centrado original era el correcto.
- **Lo que no es 1:1 a propósito:** rótulos del editor, la barrera `B` (invisible hasta activarse), la lógica del Juego (tablón y lámparas de la puerta, chispas, parpadeo de la luz, goblins que se mueven) y la hierba automática (Hierba3D), que el editor no dibuja.
Archivos: `prueba_test2.gd`, `marcador_3d.gd`, `pieza_3d.gd`, `objetos_3d.gd`, `niveles/Nivel_Bosque.tscn`, `niveles/luz_juego.tscn` (nuevo). — Pipeline

## 13/10 (5) · Pipeline · Vuelve el suelo del juego (se deshace el «paso 2»)
- El suelo del nivel horneado vuelve a ser el del juego (hierba y camino con textura, piedra bajo canal/tinaja/cristal, agua animada y orillas). El «paso 2» lo había cambiado por los bloques planos del GridMap del editor: igualaba en la dirección equivocada (el juego bajaba al nivel de los bloques de colocación). Comprobado con capturas antes/después.
- Se mantiene el resto de 13/10 (4): piezas, canal, personajes y telarañas en la posición del marcador; vistas previas del editor; `luz_juego.tscn`.
- Pendiente (decide Pablo): que el editor muestre el suelo del juego (hoy enseña los bloques de colocación del GridMap).
Archivos: `prueba_test2.gd`. — Pipeline

## 13/10 (6) · Pipeline · El editor pinta el suelo del juego (`VistaSuelo`)
- **Nuevo `poc_25d/vista_suelo_editor.gd`** (nodo `VistaSuelo` en `Nivel_Bosque`): solo actúa en el editor. Lee el nivel ABIERTO (GridMap y marcadores, también sin guardar) y construye el suelo con el código del juego (hereda de `prueba_test2.gd`: `_leer_nivel_de`, `_construir_suelo`, `_sembrar_hierba`). Hierba, camino, tierra, piedra, agua, cauce, orillas y matas, iguales que en `PruebaBosque` (comparado con capturas).
- **Bloques del GridMap:** se ocultan en el editor mientras se ve el suelo. Para pintar casillas: `ver_bloques` en el inspector de `VistaSuelo`. Al guardar quedan visibles (no cambia lo guardado). `ver_hierba` quita las matas si pesa; `actualizar` rehace a mano.
- **Se rehace solo** al cambiar casillas o marcadores (cuando dejan de cambiar medio segundo).
- **`prueba_test2.gd`:** `_leer_nivel` se parte en cargar + `_leer_nivel_de(raiz)` (la vista le pasa la escena abierta). El juego sale idéntico (comparado antes/después).
- **Diferencias que quedan:** en el juego la hierba aparece alrededor del jugador al andar (en el editor sale toda); el agua y la hierba se mueven; los árboles cambian un poco de sombreado por el material de transparencia junto al jugador.
- Para Pablo: `poc_25d/vista_suelo_editor.gd` es nuevo; va con el resto de `poc_25d` en `PROPIETARIOS.md`.
Archivos: `vista_suelo_editor.gd` (nuevo), `prueba_test2.gd`, `niveles/Nivel_Bosque.tscn`. — Pipeline

## 13/10 (7) · Pipeline · Chispas del cristal sutiles, río desde la caída del chorro y agua electrificada azul
- **Cristal (`objetos_3d.gd`):** chispas mucho más sutiles: 4 por altura (antes 10), más pequeñas y apagadas (`BRILLO_CHISPAS_CRISTAL` 0,4, con `Vfx3D.atenuar`); luz a 0,4 (`LUZ_CRISTAL`); chispazo grande cada 2,5-5 s y pequeño (`Vfx3D.chispazo_suave`). La luz del marcador `e` en el editor usa el mismo `LUZ_CRISTAL`.
- **Río desde la caída:** el agua del canal empieza donde cae el chorro (`Canal3D.configurar(..., inicio)`, `Reactivo3D.punto_caida_global`, `sin_arroyo`). Fuera la salpicadura de la caída y el arroyo hasta el borde de la casilla.
- **Tinaja movida:** `u_3_26` de z 60,48 a 61,09 (0,61 hacia el canal): el chorro caía sobre el borde de piedra del codo, fuera del agua. Para deshacerlo, devolver su z a 60,48 en el editor.
- **Agua electrificada (`prueba_test2.gd`, `vfx_3d.gd`):** chispas azules del rayo (`Vfx3D.chispas_agua`, color del hechizo de rayo) pocas y apagadas (`BRILLO_CHISPA_AGUA` 0,55). En el canal van sobre la tira de agua de cada tramo (su altura y el sitio del marcador; antes iban al centro de la casilla y a la altura del río, por debajo del agua del canal). Luz azul a 0,35 (`LUZ_AGUA_ELECTRICA`) y chispazo suave cada 0,9 s (antes amarillo cada 0,3 s).
- **Agua de paddy-exe/Godot-3D-Stylized-Water:** revisada. MIT, para Godot 3.2 (no carga en 4.7 tal cual), sin cambios desde 2021, y usa la textura de profundidad/pantalla. Propuesta: llevar su aspecto (dos tonos, espuma en la orilla, olas suaves) a nuestro `CODIGO_AGUA` con el mapa de orilla que ya tenemos. Pendiente de que Pablo lo apruebe.
Archivos: `objetos_3d.gd`, `canal_3d.gd`, `vfx_3d.gd`, `prueba_test2.gd`, `marcador_3d.gd`, `niveles/Nivel_Bosque.tscn`. — Pipeline

## 13/10 (8) · Pipeline · Agua del río estilizada (low-poly), prueba
- `CODIGO_AGUA` (`prueba_test2.gd`) tiene un modo estilizado con el aspecto de paddy-exe/Godot-3D-Stylized-Water (MIT), rehecho sin profundidad de escena: facetas planas en una rejilla de triángulos que se inclinan con las olas, dos tonos en bandas por la distancia a la orilla (el mapa de orilla de siempre), línea de espuma nítida junto a tierra y manchas de espuma de dos ruidos cruzados.
- Interruptor `agua_estilizada` (PruebaBosque y VistaSuelo, por defecto activado): desmarcado vuelve el agua pintada de antes. Ajustes en el sombreado: `faceta`, `altura_ola`, `color_somero_est`, `color_hondo_est`, `bandas`, `espuma_manchas`, `contraste_faceta`.
- Se ve igual en el editor (VistaSuelo usa el mismo código). El agua del canal (`Canal3D`, otro sombreado) no cambia todavía.
Archivos: `prueba_test2.gd`. — Pipeline

## 10/10 · Pipeline · Cristal amarillo solo en el azul y orilla del agua suave
- **Cristal (`pieza_3d.gd`, `Pieza3D.tinte_amarillo`):** ya no pinta la malla entera de amarillo plano. Conserva la textura y pasa a amarillo solo los píxeles de tono azul/cian (musgo y piedra quedan como venían). En el juego la textura se lee del parámetro `tex_albedo` del material de `Ocluso3D`. Efecto lateral: con el tinte puesto el cristal no tiene el círculo de transparencia del jugador (antes tampoco).
- **Orilla del agua (`prueba_test2.gd`):** el mapa de distancia a la orilla se amplía x4 con interpolación cúbica (se acaban los picos de rombo) y la espuma de la orilla pasa de corte seco a degradado (`transicion_orilla`, 0,4 casillas). Quedan los ajustes `ancho_espuma` (ya sin uso en la línea de orilla) y `espuma_manchas`.
- Para Pablo: comprobado con capturas en Godot 4.7.2 (cristal suelto y PruebaBosque); no probado en el editor con VistaSuelo.
Archivos: `pieza_3d.gd`, `prueba_test2.gd`. — Pipeline
