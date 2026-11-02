# Migración a Unreal: coste y tiempo, con datos medidos (1/11/2026)

Complemento de `COMPARATIVA_VFX_GODOT_UNREAL_2026-11-01.md` §2.5. Pablo pidió «revisar la POC de Unreal y mirar cómo sería una migración en coste y tiempo, con datos reales». Todo lo que aquí es **medida** sale de comandos sobre el repo (`git ls-files`, recuento de líneas, `grep` de clases de Godot) o de los archivos de la POC en `E:\UnrealProjects\MS_POC_VFX`. Todo lo que es **estimación** lleva su supuesto al lado, para poder cambiarlo.

---

## 0. Resumen

| | Dato |
|---|---|
| Juego hoy (medido) | 582 scripts GDScript, 152 731 líneas: 90 581 de juego, 36 026 de pruebas (164 scripts en `herramientas/prueba_*`), 26 124 de herramientas. 218 escenas (59 de juego, 159 de modelos importados), 490 GLB, 153 audios, 82 documentos, 15 `.tres`. |
| Lo escondido (medido) | 82 shaders incrustados en 51 scripts, 62 scripts que tocan `RenderingServer`, 44 que construyen mallas por código, 39 que construyen texturas, 126 que leen la línea de comandos (flujo sin ventana), rig propio (3 `SkeletonModifier3D`, muelles, ropa). |
| POC de Unreal a las 12:35 (1 h 30 de agente) | 5 sistemas Niagara, 4 Blueprints y el personaje con teclas, todo creado por script Python; **ninguna captura presentable aún** (sprites en damero, cámaras mal puestas, columna de fluidos y bola vacías). Los cinco materiales son contenido del motor duplicado; la columna de fluidos es la plantilla de Niagara Fluids copiada tal cual. |
| Migración (estimación) | **50–80 jornadas de agente** de escritura más la validación de Pablo. Al ritmo medido en Godot (25 días con commit de 37 de calendario), **3–4 meses a dedicación completa, 5–8 a media**, con el juego parado y sin una sola función nueva al final. |
| Requisitos previos que hoy faltan | Compilador de C++ (no hay `cl.exe` en la máquina), proyecto C++ en vez de solo Blueprint, un banco de pruebas en Unreal equivalente a los 164 scripts sin ventana. |

La regla de decisión de la comparativa (§5) no cambia. Y con la POC como está, la condición «Unreal gana en aspecto» todavía no se puede ni evaluar.

---

## 1. Revisión de la prueba B (estado a las 12:35)

### 1.1 Cómo está trabajando la sesión

No ha ido por clics en el editor. Ha montado una **cola de scripts Python** que el editor de Unreal ejecuta: cada tarea deja `Saved/cola_py/<hora>_<nombre>.hecho` (el script) y `.out` (su salida). Los scripts viven en `E:\UnrealProjects\MS_POC_VFX\Scripts\` (00 a 08 más `poc_niagara.py`, 14,7 KB de ayudas). Es la vía que hace medible el «flujo con agentes» de §2.4 de la comparativa, y es el hallazgo más útil de la mañana.

Lo que ha costado: **7 reinicios del editor en 40 minutos** (`Saved/Logs/editor_gui.log` a `editor_gui7.log`, de 11:58 a 12:35), porque cada cambio de API o de plugin obliga a reabrir. Una tarea en segundo plano falló con código 1 y se repitió.

### 1.2 Qué hay creado (medido en `Content/POC`)

| Asset | Cómo | Tamaño |
|---|---|---|
| `NS_BolaFuego`, `NS_ImpactoFuego`, `NS_MuroFuego`, `NS_ColumnaFuego` | `04_niagara.py` sobre `poc_niagara.py`: emisores, módulos, curvas, renderers de sprite, luz y malla, parámetros de usuario `User.Longitud` y `User.Altura` | 1,3–1,8 MB cada uno |
| `NS_ColumnaFuego_Fluidos` | `duplicate_asset` de `/NiagaraFluids/Templates/Gas/3D/Systems/Grid3D_Gas_Fire`, «copiado tal cual» | 12,7 MB |
| `M_POC_Fuego/Humo/Chispa/Calor/Nucleo` | `duplicate_asset` de `/NetworkPredictionExtras/Art/Effects/Proto/Shared/Materials/` (contenido de un plugin del motor), con las banderas `used_with_niagara_sprites` puestas a las 12:33 | 12–22 KB |
| `BP_BolaFuego`, `BP_MuroFuego`, `BP_ColumnaFuego`, `BP_ColumnaFuego_Fluidos` | `06_bp.py` con `BlueprintGraphEditor` (API de grafos de 5.8): componentes, nodos, pines, conexiones, compilación. Bola: esfera de colisión + `ProjectileMovement` + `OnComponentHit` → spawn del impacto y destruirse. Muro y columna: variable float, `SetNiagaraVariableFloat` y escala en `BeginPlay`. **Compilan sin errores** (`run06.out`). | |
| `BP_ThirdPersonCharacter` modificado | `07_personaje.py`: eventos `LanzarBola/Muro/Columna/ColumnaFluidos`, teclas 1–4 con nodos `InputKey`, spawn delante del jugador | |
| `Lvl_POC.umap` | nivel con sol, cielo, niebla y una `CameraActor` «CamaraCapturas» | 29 KB |
| Capturas | `08_capturas.py`: máquina de estados sobre el tick de Slate que arranca PIE, lanza los efectos, mueve la cámara y guarda PNG a 1920×1080; series `prev1`, `prev2`, `prev3` en `Saved/Screenshots/WindowsEditor/` | 28 PNG |

### 1.3 Lo que se ve en las capturas `prev3` (12:34)

Las he mirado una a una:

- **muro_cerca**: suelo a cuadros y la sombra del maniquí. La cámara no apunta al muro.
- **columna_cerca**: la cámara está dentro de una malla (parece la capa del maniquí) y detrás se ven las llamas como **cuadrados grises en damero** con alguna lengua de fuego encima.
- **columna_fluidos_cerca**: nada, solo el suelo y los cubos.
- **bola_impacto_cerca**: nada.
- **diez_muros_ui**: diez muros como **placas grises en damero** con llamas sueltas dentro; el `stat fps` no se lee en la captura.

El damero es la textura por defecto de Unreal cuando un material no está listo para sprites de Niagara. La sesión lo detectó y duplicó los materiales con las banderas correctas a las 12:33; la serie `prev3` es de las 12:34, así que puede que estuviera capturada antes de recompilar. A las 12:37 seguía trabajando. Conclusión honesta: **a 1 h 30 no hay todavía una imagen que Pablo pueda puntuar**.

### 1.4 Parte del resultado que es contenido ajeno (criterio 6 de §4)

- Materiales: los cinco vienen del plugin `NetworkPredictionExtras` (fuego y humo con flipbook `SubUV`, chispa, distorsión de calor, esfera de energía). Son del motor: no salen de Unreal (regla de §0).
- Columna de fluidos: plantilla de Niagara Fluids sin cambios.
- Personaje, animaciones, nivel base: plantilla Third Person.
- Propio: curvas de color, tamaño y alfa; tasas, formas, velocidades; la lógica de los Blueprints; el escalado por parámetro de usuario.

Para el aspecto, lo que se verá en pantalla depende casi por completo del contenido ajeno (texturas y materiales). Eso no es malo dentro de Unreal, pero deja el criterio 6 en la zona alta y recuerda que «en Unreal se ve bien» significa «el fuego del plugin se ve bien».

### 1.5 Tiempos (medidos por marcas de archivo)

| Hora | Hito |
|---|---|
| 11:05 | Proyecto creado desde la plantilla (`Config/DefaultInput.ini`) |
| 11:46 | Primer script ejecutado (`00_hola.py`): 41 min de instalación, plugins y canal de Python |
| 11:47–11:56 | Volcado de la API de Niagara (1,8 MB) y de FX; exploración de Blueprints |
| 12:15 | Los cinco sistemas Niagara, reconstruidos «limpios en 19 s» |
| 12:28 | Los cuatro Blueprints compilan; nivel con luz y cámara |
| 12:29 | Primera tanda de capturas (`prev2`) |
| 12:33 | Materiales duplicados con banderas de Niagara (arreglo del damero) |
| 12:35 | `prev3`: sigue sin captura presentable |

Godot (prueba A) no se cronometró por horas como pedía §0: fue una tarde larga de agente con tres rondas de ajuste y el render del atlas en Blender (3 min por intento, varios intentos). Las dos pruebas incumplen la misma regla; cuando acabe la B habrá que apuntar las horas de las dos con la misma vara.

### 1.6 Qué parte del flujo con agentes sobrevive (criterio 5)

| Pieza del flujo actual | En la POC de Unreal |
|---|---|
| Código en texto, diferenciable, commit por tarea | **Sí**: los scripts Python regeneran todos los assets desde cero. Los `.uasset` resultantes son binarios, pero son derivados. |
| Ejecución sin ventana (`--headless`) | **No, de momento**: hace falta el editor abierto con interfaz; la cola de scripts lo rodea. Unreal tiene `-run=pythonscript` y commandlets sin interfaz, no probados aquí. |
| Pruebas automáticas | **No hay**: ni una. El equivalente serían tests de Automation en C++ o scripts Python con aserciones lanzados por commandlet. |
| Capturas automáticas | **Sí**, con PIE, pero con tirones (la sesión tuvo que poner `slomo 0.1` para fotografiar la bola) y sin poder crear actores en PIE desde Python. |
| Entrada del jugador | A medias: los eventos de Enhanced Input no se crean desde Python; usó nodos `InputKey` antiguos. |
| Ciclo editar → ver | 7 reinicios del editor en 40 min. |

---

## 2. Lo que habría que migrar, medido

### 2.1 Código de juego (sin herramientas), por carpeta

| Carpeta | Scripts | Líneas | Lo que es | A dónde iría en Unreal |
|---|---|---|---|---|
| `nucleo` | 33 | 7 231 | `Hechizo`, glifos, receta, estados, datos de partida | C++ puro (structs y `UObject`), casi sin motor |
| `magia` | 9 | 7 414 | `lanzador_3d` 2 886, `hechizo_vivo` 1 492, `spellcaster` 808, `grimorio` 736, `formas_3d` 685 | C++ (actores y componentes): volúmenes, eventos, viaje |
| `jugador` | 17 | 6 649 | `pj_3d` 2 028, `jugador_3d` 1 106, rig propio (muelles, ropa, 3 `SkeletonModifier3D`) | `CharacterMovement` + Control Rig o Chaos Cloth; retarget de las animaciones GLB |
| `enemigos` | 11 | 5 547 | `combate_3d` 2 347, gólem, chamán | C++ + State Tree / Behavior Tree |
| `objetos` | 39 | 9 631 | `objetos_3d` 1 500 y 38 más | C++ actores |
| `mundo` | 16 | 5 264 | `agua_sim_3d` 1 073, niveles, zonas | Water plugin o simulación propia en C++; niveles por Python |
| `escenas` | 9 | 6 468 | `puzle` 2 959, bosque | Niveles + C++ |
| `presentacion` | 80 | 32 588 | VFX (`vfx_3d` 2 217, `vfx_estado_3d` 1 492, `vfx_kit_3d` 1 031, `vfx_elementos` 2 061, `conjuro` 680, reacciones), agua render (3 375), UI (18 scripts, 5 265: `spellbook` 1 645, pestañas, pluma), posproceso, hierba, niebla, oclusión… | Niagara por Python (como la POC), materiales (82 shaders a rehacer en grafo o nodo Custom HLSL), UMG/Slate, Geometry Script para mallas |
| `laboratorios` | 21 | 9 789 | Bancos de prueba interactivos | Mapas de prueba; la mitad se puede tirar |
| **Total juego** | **235** | **90 581** | | |

### 2.2 Herramientas y pruebas

| Bloque | Scripts | Líneas | A dónde iría |
|---|---|---|---|
| `herramientas/prueba_*` | 164 | 36 026 | Tests de Automation (C++) o Python con aserciones por commandlet. Es lo que da seguridad al flujo con agentes; sin esto, cada cambio lo valida Pablo a mano. |
| Otras herramientas `.gd` | 183 | 26 124 | Scripts de editor en Python. Muchas son montadores de un solo uso; se rehacen solo las que se vuelven a necesitar. |
| Python (Blender, Meshy, audio) | 39 | — | **Se quedan**: no dependen del motor. |

### 2.3 Lo que no se ve contando scripts

| Cosa | Medido | Por qué cuesta |
|---|---|---|
| Shaders incrustados en GDScript | 82 en 51 scripts (más 4 `.gdshader`) | No hay traducción automática a materiales de Unreal. Cada uno se rehace como grafo o como nodo Custom con HLSL; los que usan `hint_screen_texture`, `depth_texture` o `INSTANCE_CUSTOM` cambian de forma. |
| `RenderingServer` directo | 62 scripts | Acceso de bajo nivel (instancias, multimesh, viewports). En Unreal es C++ con `UInstancedStaticMesh`, render targets o RDG. |
| Mallas por código (`SurfaceTool`, `ArrayMesh`) | 44 scripts | `ProceduralMeshComponent` o Geometry Script, con otra API. |
| Texturas por código (`Image`, `ImageTexture`) | 39 scripts | Render targets o `UTexture2D` desde C++. |
| `SubViewport` | 24 scripts | Scene capture components. |
| Flujo sin ventana (`get_cmdline`) | 126 scripts | Commandlets o `-ExecCmds`; distinto de `extends SceneTree`. |
| Rig propio | `CapaMuelles3D`, `Ropa3D`, `montar_ropa_glb`, 3 `SkeletonModifier3D` | Se sustituye por Control Rig y Chaos Cloth, que son otra cosa; las animaciones GLB de la jugadora se reimportan y se retargetean. |
| Escenas de juego `.tscn` | 59 (las otras 159 son modelos importados) | Niveles y Blueprints de datos; se pueden generar por Python. |
| Recursos `.tres` y JSON de datos | 15 + 32 | Data Assets o tablas; trivial. |
| Documentos | 82 `.md`, diario con 297 entradas | Se quedan; ESPEC_HECHIZO y GLIFOS_RECETA valen igual. |

### 2.4 Lo que sobrevive sin tocar

Pipeline de Blender y Meshy (Python), 490 GLB (se reimportan por script con Interchange), 153 audios, las texturas, el diseño (especificación de hechizos, glifos, recetas), el diario y la forma de trabajar por tareas y commits.

---

## 3. Estimación

### 3.1 Método y supuestos

1. **Líneas equivalentes** = líneas × factor por bloque. El factor recoge cuánto cambia la forma de hacerlo en Unreal, no solo el idioma: 1,0 para lógica pura (`nucleo`, pruebas), 1,1–1,5 para actores y jugador, 1,8 para `presentacion` (shaders, Niagara, UI, render de bajo nivel), 0,5–0,6 para laboratorios y herramientas de un uso.
2. **Ritmo del agente en Unreal**: 2 500–4 000 líneas equivalentes por jornada. En Godot el ritmo medido es de unas 8 000 líneas añadidas por día con commit (199 959 añadidas en 25 días con commit, contando reescrituras y código generado). Tomo entre la mitad y un tercio por lo visto en la POC: compilación de C++ (medio minuto a dos por ciclo), editor que hay que reiniciar, assets binarios que no se pueden leer con `grep`, y una API de Python incompleta (Enhanced Input, PIE).
3. **Cadencia de Pablo**: en Godot hubo commits en 25 de los 37 días de calendario desde el primer commit (25/9); es la medida de cuánto tiempo real cabe por semana con la revisión de Pablo dentro.
4. La migración es **fiel**: el juego que hay hoy, con sus pruebas, sin funciones nuevas. Un rediseño que aproveche Unreal (dejar el rig propio, el agua propia, la mitad de los laboratorios) baja la cifra pero cambia el juego.

### 3.2 Jornadas de agente por bloque

| Bloque | Líneas | Factor | Equivalentes | Jornadas (4 000/día – 2 500/día) |
|---|---|---|---|---|
| `nucleo` | 7 231 | 1,0 | 7 231 | 1,8 – 2,9 |
| `magia` | 7 414 | 1,3 | 9 638 | 2,4 – 3,9 |
| `jugador` | 6 649 | 1,5 | 9 974 | 2,5 – 4,0 |
| `enemigos` | 5 547 | 1,2 | 6 656 | 1,7 – 2,7 |
| `objetos` | 9 631 | 1,1 | 10 594 | 2,6 – 4,2 |
| `mundo` | 5 264 | 1,4 | 7 370 | 1,8 – 2,9 |
| `escenas` | 6 468 | 1,2 | 7 762 | 1,9 – 3,1 |
| `presentacion` | 32 588 | 1,8 | 58 658 | 14,7 – 23,5 |
| `laboratorios` | 9 789 | 0,5 | 4 895 | 1,2 – 2,0 |
| Pruebas | 36 026 | 1,0 | 36 026 | 9,0 – 14,4 |
| Otras herramientas | 26 124 | 0,6 | 15 674 | 3,9 – 6,3 |
| **Escritura** | **152 731** | | **174 478** | **44 – 70** |
| Puesta en marcha: compilador, proyecto C++, banco de pruebas, cola de scripts, importador de GLB | | | | 3 – 5 |
| Importar y retargetear assets (490 GLB, animaciones de la jugadora, audio) | | | | 2 – 4 |
| **Total** | | | | **≈ 50 – 80 jornadas de agente** |

### 3.3 Calendario

- A la cadencia medida (25 de cada 37 días con trabajo que llega a commit): 50–80 jornadas son **75–120 días de calendario, 2,5–4 meses**, si no se hace nada más.
- A media dedicación (el juego sigue en Godot mientras tanto, o Pablo reparte el tiempo): **5–8 meses**.
- Lo que hay al final: el mismo juego de hoy, con otro motor, sin una función nueva, y con todo el conocimiento de ajuste fino (gamefeel, capa, pies, agua) por volver a conseguir.

### 3.4 Lo que la cifra no incluye

- **Aprendizaje**: la POC es el primer contacto del agente con la API de Python de Unreal 5.8; cada hallazgo de hoy (qué se puede crear y qué no) se paga una vez, pero habrá más.
- **Las manos de Pablo**: en Godot revisa escenas en texto y corre pruebas sin abrir nada. En Unreal revisará `.uasset` abriendo el editor; cada revisión es más larga. No está medido.
- **Disco y máquina**: el motor ocupa 29,5 GB en E y el proyecto de la POC 0,4 GB; un proyecto con los 490 GLB y la caché de derivados estará en 20–40 GB. Falta instalar Visual Studio Build Tools (unos 10 GB más). C sigue con 0,2 GB libres.
- **Tokens**: no se ha medido el consumo de las dos sesiones de hoy; la tarjeta de uso de la app lo da por periodo, no por sesión.

### 3.5 Sensibilidad: qué mueve la cifra

| Si… | Entonces |
|---|---|
| Se renuncia a la migración fiel: fuera laboratorios, herramientas de un uso y el 30 % de las pruebas que cubren cosas ya estables | −15 a −20 jornadas; se pierde la red de regresión justo cuando más se necesita |
| Niagara y Blueprints por Python dejan de bastar y hay que entrar al editor a mano | Factor de `presentacion` de 1,8 a 3,0: +20 a +30 jornadas, y pasan a ser horas de Pablo, no de agente |
| Se hace el juego solo en Blueprints, sin C++ | No es viable con agentes: los grafos son binarios y la API de grafos de Python cubre nodos básicos (la POC lo muestra), no un juego de 90 000 líneas |
| Pablo mantiene Godot y adopta el método de la prueba A (§1.5 de la comparativa) | El traslado del fuego al sistema de hechizos son 2–4 jornadas; el resto de elementos, 1–2 jornadas cada uno |

---

## 4. Lo que la POC tiene que entregar antes de rellenar la tabla de §4 de la comparativa

1. Capturas donde se vea el fuego: muro y columna a 2 m y 10 m, bola en vuelo e impacto, diez muros con el `stat fps` legible.
2. Las horas, apuntadas con la misma vara que en Godot (y Godot tiene que apuntar las suyas a posteriori: atlas, shaders, escenas, capturas, tres rondas).
3. El porcentaje de contenido ajeno en pantalla, dicho con claridad: hoy son los cinco materiales y la plantilla de fluidos.
4. Un intento de ejecución sin interfaz (`-run=pythonscript` o commandlet) para saber si el flujo sin ventana existe o no.
5. La rama `claude/poc-unreal` con los scripts y las capturas en `docs/capturas/comparativa_vfx/unreal/`.

Con eso y las notas de aspecto de Pablo sobre las dos pruebas se rellena la tabla. Esta estimación es la fila «coste de llegar al juego entero»: 0 en Godot, 50–80 jornadas de agente y 3–8 meses de calendario en Unreal.
