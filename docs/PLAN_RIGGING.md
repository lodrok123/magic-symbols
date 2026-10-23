# Plan de rigging común · rigs propios sin depender del autorig

21/10/2026 · análisis (Opus) a petición de Pablo tras el playtest: «preparar un plan de rigging común para desarrollar mejores rigs y no depender del autorig».
Es el desarrollo de las tareas **13.1–13.4** de `docs/PLAN_ARREGLOS.md` (Fase 13, «Animación», sin empezar). Responsable: **Pipeline** (`docs/PROPIETARIOS.md`); el Juego solo pone el contrato (`Pj3D`) y la prueba automática.

---

## 1. El problema, medido en lo que ya ha pasado

| síntoma | dónde se vio | causa |
|---|---|---|
| Cada personaje necesita su tabla de arreglos | `Pj3D.CORRECCION_POSTURA`, `POSTURAS`, `FACTOR_ZANCADA`, `_anular_raiz`, `_acortar_paso` (`jugador/pj_3d.gd`) | el autorig de Meshy coloca los huesos donde cree; la pose de reposo y las longitudes cambian de un modelo a otro, así que los mismos clips dan posturas distintas |
| Clips que arrastran la cadera o se salen de su sitio | `MageSoellCast001` (0,36), `HitReaction` del guerrero (1,25 alturas), ataque/andar/golpe del elemental (diario y comentarios de `Pj3D.SINONIMOS` / `CLIPS_DE`) | movimiento de raíz metido en la pelvis; cada clip viene de una fuente distinta |
| Mangas y abrigo que se deforman | `woodland_wanderer_suave.glb` (pesos suavizados a mano, diario 29) y pendiente «mangas y túnica de la elfa» | pesos automáticos sin revisar en ropa ancha |
| Rig de cuadrúpedo rechazado | loberno («no me gusta el rig», diario 53–54) | autorig de cuadrúpedo muy irregular |
| **Retarget de la hiena al canouro rechazado** (21/10: «las formas se estiran mucho más que antes») | diario 207 | se copiaron giros entre dos esqueletos con **proporciones distintas** (patas de la hiena más largas) sin compensar longitudes ni pies: el resultado estira la malla. **Lección: retargetear solo entre esqueletos de la misma familia y proporciones parecidas, y con los pies resueltos por IK o con pistas de posición escaladas.** |

Conclusión: el problema no es «un rig malo», es que **no hay un esqueleto de referencia por familia**. Cada modelo trae el suyo y cada clip se apaña para ese modelo.

## 2. La idea: un esqueleto maestro por familia

| familia | maestro | quién lo usa hoy | huesos |
|---|---|---|---|
| **Bípedo** | Mixamo (nombres `mixamorig:*`), versión **ligera sin dedos** (≈ 28 huesos, la que ya llevan goblins y elemental) | elfa, goblins, NPC, elemental | ~28 (+ dedos opcionales si un clip los pide) |
| **Cuadrúpedo** | «Wolf» (51 huesos, el del loberno/emberheart) | loberno, canouro, futuros animales | 51 |

**22/10 · `elfo_base` = la malla base de los elfos** (`arte/modelos/elfo_base.glb`; Tripo, 19 678 tris, 0,98 u de alto, esqueleto Mixamo **completo de 65 huesos con dedos**, A-pose, sin animaciones). Los clips los toma de `chibi_elf` (mismos nombres de hueso, otra pose de reposo y otras proporciones) con `ClipsFamilia` (`jugador/clips_familia.gd`): retarget en código al cargar, sin tablas por personaje; es el adelanto de «Pj3D carga la biblioteca de su familia» (§3.6) para este modelo. Respaldo de los NPC elfos en `PruebaTest2` (`PJ_ALQUIMISTA`, `PJ_LIBRERA`). Las 4 decisiones de §7 siguen **pendientes**: `elfo_base` no las resuelve (el rig de 65 huesos con dedos es una variante más del bípedo ligero de 28, no el maestro).

**22/10 · `goblin_base` = la malla base de los goblins NPC** (`arte/modelos/goblin_base.glb`; Tripo, 25 358 vértices, 0,98 u de alto en el GLB, esqueleto Mixamo **completo de 65 huesos con dedos**, los mismos nombres que `elfo_base`). Trae **5 clips propios**: `idle` (15,3 s), `walk` (2,3 s), `hablar` (10,0 s), `chop` (6,6 s, talar sin hacha) y `dig` (16,4 s, cavar). Roles de `Pj3D`: idle, walk, talk→`hablar`, `talar`→`chop`, `cavar`→`dig`; `run` cae en `walk` (`ROL_SUSTITUTO`) y el walk pierde el avance de la cadera (`RAIZ_ANULADA`). Es un NPC (rol visual NPC, no entra en `MODELOS_EMPUJABLES`), 0,85 u en juego como el resto de la familia goblin. No lo usa ningún NPC todavía.

**23/10 · `marimanta` = la anciana duende (NPC)** (`arte/modelos/marimanta.glb`; Meshy «Crimson Goblin Duchess», riggeada por Meshy: **66 huesos** Mixamo con dedos más `headfront`, 1,70 u de alto en el GLB, 0,80 en juego). El GLB sale de los dos FBX de Meshy con `herramientas/convertir_fbx_a_glb.gd` (FBXDocument → GLTFDocument: huesos `smartrig_*`→`mixamorig_*`, personaje enderezado de Z-up a Y-up, texturas de 2048 PNG a 1024 JPEG con metálico+rugosidad fundidos). Trae 7 clips: `Idle_02`, `Walking`, `Elderly_Shaky_Walk` (+ `_inplace`), `Running`, `Scheming_Hand_Rub`, `Talk_with_Left_Hand_on_Hip`; roles idle, walk→`_inplace` y talk (`CLIPS_DE`), run, `pensar`→Scheming. El bastón (`baston_marimanta.glb`, Tripo) va en `RightHand` por `Equipo3D`, vertical solo en idle (rígido a la mano). Prueba `prueba_marimanta`, capturas en `docs/capturas/marimanta/`. No la usa ningún NPC todavía.

**23/10 · `jugadora_base` = la candidata a protagonista, con la ropa en piezas aparte** (`arte/modelos/jugadora_base.glb`; Meshy «Willow Fernstep», rigueada en **Mixamo** por Pablo y exportada desde Blender: **66 huesos** = los 65 de Mixamo con dedos + `headfront`; 31 127 tris, 1,70 u de alto en el GLB (1,0 en juego), A-pose, sin clips propios). Sale de `herramientas/convertir_fbx_a_glb.gd` (nuevo modo `-` = sin clips; texturas a 1024 JPEG con ORM). Los clips: los **22 de la elfa** (`chibi_elf`) por `ClipsFamilia` (`FUENTES["jugadora_base"]`), sin tablas de corrección: todos los roles de `Pj3D` resuelven como en la elfa, pies en el suelo y sin deriva de raíz. La carrera de Meshy del zip no se usa (otro esqueleto y la de la elfa ya vale). **Ropa por piezas** (`jugador/ropa_3d.gd`, `Ropa3D`; datos en `arte/modelos/ropa.json`): `ropa_capa_capucha.glb` y `ropa_tunica.glb`, cada una un `MeshInstance3D` con el MISMO esqueleto y Skin que el cuerpo, colgado del `Skeleton3D` de la base con `skeleton = ".."`; equipar es `Pj3D.poner_ropa(id)` (o `Pj3D.ROPA_POR_DEFECTO`), sin código por prenda. El encaje lo hacen `herramientas/rig/encajar_ropa.py` (Blender: separar las dos prendas del `vestido.glb` de Tripo, diezmar, escalar por alturas a la cabeza grande, sacar de la piel y del pelo, pesos de la base por el punto más cercano, suavizados y a 4 influencias; parámetros en `herramientas/rig/ropa_jugadora_base.json`) y `herramientas/montar_ropa_glb.gd` (Godot: pone la malla sobre una copia de la escena de la base, así el esqueleto y las poses de enlace son idénticos, sin reexportar desde Blender). Prueba `prueba_jugadora_base`, capturas en `docs/capturas/jugadora_base/`.
**Ocultar zonas de la base bajo la ropa (pendiente, sin hacer):** el cuerpo es UNA malla (pelo, camisa, chaleco, pantalón y botas fundidos), así que bajo la túnica se sigue dibujando el chaleco/cinturón de la base y bajo la capucha el pelo (asoma por los bordes y, en poses extremas, por la tela). Para ocultar por zonas habría que partir `jugadora_base.glb` en mallas (cabeza+pelo, torso, brazos, piernas, botas) con los mismos huesos y pesos (Blender, por grupos de vértices; el reparto ya está en los pesos) y que cada prenda diga en `ropa.json` qué zonas tapa (`oculta`, ya en los datos) para que `Ropa3D.poner/quitar` oculte/muestre esas mallas. Es un trabajo de ~1 h de Blender y un cambio pequeño en `Ropa3D`.

Cada maestro se guarda **una vez** en `arte/rigs/<familia>/`:
- `maestro.blend` + `maestro.glb`: el esqueleto en **pose de reposo fija** (A-pose para el bípedo, de pie para el cuadrúpedo), mirando a +Z, Y arriba, a escala del juego (chibi ≈ 1 u de alto; goblin 0,85; casilla 2,3).
- `maniqui.glb`: una malla neutra de esa familia **ya pesada y revisada** (hombros, caderas, codos, rodillas, cuello). Sirve de fuente para transferir pesos.
- `biblioteca.res`: la `AnimationLibrary` con los clips de la familia (`idle, walk, run, attack, hit, death, cast…`), **todos sin movimiento de raíz en la pelvis** (el avance lo pone el juego) y con la cadera dentro de 0,3 alturas.

## 3. El flujo de un personaje nuevo (sin autorig)

1. **Meshy, sin rig.** Pedir la malla en la pose de reposo de la familia (A-pose / de pie), simétrica, con brazos separados del cuerpo y sin ropa fundida con las manos. En el prompt, la imagen de referencia de la pose (como se hace ya con la elfa).
2. **Blender, encajar el maestro** (script, no a mano): importar la malla, escalarla a la altura de su familia, y mover las articulaciones del maestro a la malla **sin renombrar ni añadir huesos** (puntos de encaje: hombros, codos, muñecas, caderas, rodillas, tobillos, cuello, cabeza; marcados una vez y guardados en un `.json` por modelo para repetirlo).
3. **Pesos:** `Data Transfer` desde el `maniqui.glb` (proyección por superficie) + `Automatic Weights` solo donde no llegue + `Smooth`, **máximo 4 influencias por vértice, normalizado**. Ropa ancha (mangas, túnica, capa): grupo aparte con pesos suavizados, como se hizo con la elfa.
4. **Comprobar en 6 poses de prueba** (brazos arriba, sentadilla, zancada, giro de cintura, cabeza a los lados, cast): captura automática para Pablo antes de seguir.
5. **Exportar** `arte/modelos/<id>.glb` **sin animaciones** (o con las propias si las tiene únicas).
6. **Godot:** `Pj3D` carga la biblioteca de su familia cuando el modelo no trae el clip (tarea 13.2). Con el mismo esqueleto y la misma pose de reposo, **los clips se comparten sin retarget** y sin tablas de corrección por personaje. `ProporcionChibi` sigue sirviendo para la cabeza grande: actúa después de la animación.

Todo el paso 2–5 va en **un script de Blender** (`herramientas/rig/encajar_maestro.py`) que se lanza con un `.cmd` completo en el PC de Pablo (el sandbox no tiene Blender). Objetivo de 13.1: **una hora, determinista** por personaje.

## 4. De dónde salen los clips

- **Bípedo:** Mixamo (gratis) bajado una vez sobre el maestro, más Cascadeur para lo que no haya (cast a una mano con el libro al pecho, `mano_quemada`, ahogarse de verdad). Los clips procedurales del Pipeline (`Drowning`, diario 231) se generan ya sobre el maestro.
- **Cuadrúpedo:** los 12 clips de «Wolf» + Cascadeur. **No** traer clips de otro cuadrúpedo con otras proporciones (la hiena): si hace falta uno, se rehace sobre el «Wolf».
- **Retarget (solo si un clip viene de otro esqueleto de la misma familia):** el importador de Godot 4 con `BoneMap` + `SkeletonProfileHumanoid` (bípedos) o un `SkeletonProfile` propio del «Wolf», con «Rest Fixer» y la posición de la pelvis **escalada por la altura** (no copiada). Así no se estira: es lo que faltó en la hiena.

## 5. Prueba automática (Juego escribe, Pipeline mantiene la lista)

`herramientas/prueba_rigs.gd` (es la 13.3 de PLAN_ARREGLOS), recorre `arte/modelos/*.glb` y por cada uno:
- esqueleto = el de su familia (mismos nombres, misma jerarquía, pose de reposo dentro de una tolerancia);
- altura = la de su familia (± 5 %), pies en el suelo en `idle`;
- pesos: ≤ 4 influencias, ningún vértice sin peso, suma = 1;
- cada rol de `Pj3D.SINONIMOS` que su familia promete tiene clip (propio o de biblioteca);
- ningún clip arrastra la cadera más de 0,3 alturas (lo que hoy se corrige a mano con `_anular_raiz`);
- con el maestro aplicado, `CORRECCION_POSTURA` / `FACTOR_ZANCADA` de ese personaje deberían quedarse vacíos: si hace falta uno, el encaje del paso 2 está mal.

## 6. Migración (orden por lo que más se ve)

1. Goblins (guerrero, arquero, espadachín): son los que más salen y ya comparten esqueleto.
2. La elfa jugadora (`woodland_wanderer`): quitar sus correcciones de postura y la versión `_suave`.
3. NPC (librera, alquimista, guardabosques, grandmaster).
4. Elemental.
5. Cuadrúpedos sobre «Wolf»: loberno (ya está), canouro (sin la hiena), gato.

## 7. Lo que tiene que decidir Pablo antes de empezar

**Decidido por Pablo el 23/10:**
1. **A-pose** para el bípedo maestro.
2. **La protagonista, completa (≈ 65 huesos, con dedos)**: el cast con la pluma los necesita. El resto de la familia bípeda puede ir con
   el ligero; elfo_base, goblin_base, el goblin asesino y Marimanta ya traen el completo.
3. **Clips que falten:** primero IA (texto a animación de Meshy, como hasta ahora) y Cascadeur como alternativa para los que la IA no
   saque bien (los que necesitan precisión: abrir el cofre sincronizado con la tapa, el corte con los brazos extendidos, el cast con la
   pluma).
4. **Encaje del maestro: aprobado** que lo haga el Pipeline con el script y capturas, y que Pablo lo valide.

*(Texto original de las preguntas:)*

1. **A-pose o T-pose** para el bípedo maestro (propuesta: **A-pose**, deforma mejor los hombros; Meshy la genera bien con referencia).
2. **Bípedo ligero (≈ 28 huesos, sin dedos) o completo (≈ 65, con dedos).** Propuesta: ligero; dedos solo si el cast con la pluma lo exige (entonces una variante «con manos» del maestro, misma raíz).
3. **Cascadeur** para los clips que falten (gratis para uso indie) o seguir con clips procedurales del Pipeline.
4. **Quién encaja el maestro** la primera vez (marcar los puntos de encaje de cada modelo): Pablo en Blender con el script, o el Pipeline con capturas para que Pablo valide.
