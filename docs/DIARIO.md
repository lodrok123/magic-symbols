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
