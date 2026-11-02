# Prueba B de la comparativa de VFX: POC en Unreal 5.8

Notas de la sesión del 1/11/2026 (11:08–12:45) para `docs/COMPARATIVA_VFX_GODOT_UNREAL_2026-11-01.md` §2. Proyecto en `E:\UnrealProjects\MS_POC_VFX` (UE 5.8.4 en `E:\UE_5.8`, caché DDC en `E:\UnrealDDC`; nada en C). Pablo no estaba delante del PC: todo se hizo sin tocar la ventana del editor.

## Capturas

Mismos nombres que en `../godot/`. Las de PIE se tomaron con `AutomationLibrary.take_high_res_screenshot` a 1920×1080 y `r.ScreenPercentage 100`; `diez_muros.png` es la captura del editor con `stat fps` y `stat unit` visibles (la única forma de que el contador salga en la imagen).

| Captura | Qué se ve | Estado |
|---|---|---|
| `bola_vuelo_cerca.png` | Bola a 1 s de vuelo (con `slomo 0.1` para poder capturarla) | Las llamas y chispas van con la bola. El núcleo (esfera fresnel) sale de ~1,5 m aunque se pidió 36 cm: `Particles.Scale` no se aplicó al renderizador de malla. |
| `bola_impacto_cerca.png`, `bola_impacto_lejos.png` | Impacto contra el cubo a 2 m y 10 m | Llamas, chispas y luz en el punto de choque. Un emisor (el humo) sale como un cuadrado a cuadros: a su material le falta la compilación para sprites de Niagara en SM6. |
| `muro_cerca.png`, `muro_lejos.png`, `juego_muro.png` | Muro de fuego de 6,9 m a 2 m, 10 m y desde la cámara del juego | Pared horizontal de llamas con chispas. Sin humo ni calor (ver abajo). |
| `verif_muro_longitud2.png` | Muro lanzado con `Longitud = 2` | El muro se alarga a 13,8 m: el parámetro `User.Longitud` + la escala del componente funcionan. |
| `columna_cerca.png`, `columna_lejos.png` | Columna de 3,4 m de sprites a 2 m y 10 m | Llamas altas, chispas, humo tenue y luz. |
| `columna_fluidos_cerca.png`, `columna_fluidos_lejos.png` | Columna por Niagara Fluids (`Grid3D_Gas_Fire` duplicado) | **No renderiza**: solo se ve la caja roja de límites del sistema. Probado `r.HeterogeneousVolumes 1`; no bastó. |
| `diez_muros.png`, `diez_muros_1080p.png` | Diez muros a la vez | `stat fps`: **72,5 fps, 13,8 ms** (Game 8,7 ms, GPU 12,1 ms, 280 draws). Medido también desde el tick de Slate: 72,8 fps de media, dt máximo 17 ms. Sin ningún muro el editor va a ~118 fps. |

Equipo: el mismo que la prueba A de Godot, con el editor de Unreal abierto (el PIE corre dentro del editor, no en un ejecutable empaquetado, así que el fps es pesimista).

## Horas por paso (tiempo de agente, con Pablo fuera)

| Paso | Tiempo | Notas |
|---|---|---|
| 1. Instalación de UE 5.8 (Pablo), proyecto Third Person, plugins | 11:08–11:56 (de ellas ~35 min esperando la instalación) | Proyecto por copia de la plantilla `TP_ThirdPersonBP` + `.uproject` escrito a mano con los plugins NiagaraFluids, PythonScriptPlugin, EditorScriptingUtilities. No hay Starter Content en 5.8. |
| 2. Nivel (plano 20×20, cuatro cubos, Sol, cielo, atmósfera, niebla) | 10 min | `Scripts/01_nivel.py`. Primer intento con el sol bajo el horizonte por el orden de `unreal.Rotator(roll, pitch, yaw)`. |
| 3. Cinco sistemas Niagara | 20 min (12:00–12:20) | `Scripts/04_niagara.py` + `poc_niagara.py`. Fallo de 20 min por los materiales (sprites a cuadros). |
| 4. Cuatro Blueprints de actor + teclas en el personaje | 15 min (12:20–12:35) | `Scripts/06_bp.py`, `07_personaje.py`. Explorar la API de grafos (`05_bp_explorar.py`) fue la mitad. |
| 5. Capturas en PIE y cuatro rondas de corrección | 20 min (12:26–12:45) | `Scripts/08_capturas.py`. Cada ronda = parar el editor, apartar carpetas, relanzar y encolar 04→06→07→08 (~2 min). |
| **Total** | **~1 h 40** de agente (1 h 5 sin la espera de la instalación) | Frente a las ~4 h de la prueba A en Godot, con un resultado visual más pobre (ver abajo). |

## Contenido de Epic frente a contenido propio

**De Epic (venía con el motor):**
- La plantilla Third Person entera: personaje, animaciones, Enhanced Input, mapa de ejemplo.
- Los **cinco materiales** de fuego, humo, chispa, calor y esfera de energía, duplicados desde el plugin `NetworkPredictionExtras` (`/NetworkPredictionExtras/Art/Effects/Proto/...`) a `/Game/POC/Materiales/M_POC_*`, con el flag de uso en Niagara activado. Sus texturas (`T_Fire_SubUV` 1024², `T_Smoke_SubUV` 2048²) también. No había otro fuego en el motor: sin Starter Content y sin cuenta de Fab no hay nada «de la caja».
- La plantilla `Grid3D_Gas_Fire` de Niagara Fluids (duplicada tal cual a `NS_ColumnaFuego_Fluidos`).
- El cubo y el plano son las mallas básicas del motor.

**Propio (escrito por el agente en esta sesión):**
- El nivel `Lvl_POC`.
- Los cuatro sistemas Niagara de sprites (`NS_BolaFuego`, `NS_ImpactoFuego`, `NS_MuroFuego`, `NS_ColumnaFuego`): emisores, módulos, curvas, parámetros `User.Longitud` y `User.Altura`.
- Los cuatro Blueprints (`BP_BolaFuego`, `BP_MuroFuego`, `BP_ColumnaFuego`, `BP_ColumnaFuego_Fluidos`) y los cuatro eventos del personaje.
- Los 13 scripts Python de `E:\UnrealProjects\MS_POC_VFX\Scripts` (~980 líneas) y `Content/Python/init_unreal.py`.

En números gruesos: el aspecto (materiales y texturas) es 100 % de Epic; la estructura (sistemas, Blueprints, nivel, teclas) es 100 % propia.

## Lo que no se hizo o no quedó como pedía §2.3

- **Humo y calor.** El material de distorsión de calor (`M_Heat_Distortion`) no compila para `PCD3D_SM6` y se quitó de los cuatro sistemas. El humo sale como cuadrado a cuadros en el impacto (el mismo problema en una variante). Es una tarde de Pablo en el editor de materiales, no de script.
- **Niagara Fluids.** La columna de fluidos no renderiza (solo la caja de límites). Probablemente falte configurar el renderizador de volumen o el proyecto para volúmenes heterogéneos; no se investigó más por tiempo.
- **Timeline nacer/vivir/morir en el muro.** No se pudo crear un nodo Timeline desde Python. Se sustituyó por una curva de envolvente en Niagara sobre `Emitter.Age` (0→1 en 0,3 s, 1 hasta 4,3 s, 0 a 4,8 s) y `InitialLifeSpan` del actor. Cumple el mismo efecto, no la misma construcción.
- **Enhanced Input.** La API Python de 5.8 no crea nodos de evento de Input Action. Las teclas 1–4 son nodos `InputKey` clásicos (funcionan en PIE; en un proyecto real habría que pasarlos a Enhanced Input a mano).
- **Núcleo de la bola** demasiado grande (ver tabla).
- **Verificación de teclas.** Las teclas no se han pulsado (no hay control de ventana): se verificó llamando a los eventos `LanzarBola`/`LanzarMuro`/`LanzarColumna` del personaje desde PIE, que es lo que las teclas disparan.
- Las **cinco modificaciones de §0** quedan para Pablo, como pedía la tarea.

## Flujo con agentes: lo que sobrevive y lo que no (§2.4)

**Sobrevive, y mejor de lo esperado:**
- Todo el contenido se construyó sin un solo clic: nivel, cinco sistemas Niagara, cuatro Blueprints con grafos (eventos, Spawn Actor, Set Niagara Variable, OnComponentHit, variables miembro), personaje, capturas en PIE con cámara y `stat fps`. La API Python de 5.8 (`FXConverterUtilitiesLibrary`, `BlueprintGraphEditor`, `SubobjectDataSubsystem`, `LevelEditorSubsystem`) lo cubre.
- Los scripts son texto reproducible: `04→06→07→08` reconstruye todo en ~2 min desde cero. Los `.uasset` binarios se pueden tratar como artefacto de compilación.
- Blueprints compilan y se pueden leer de vuelta (nodos, pines, errores) desde Python.

**No sobrevive o cuesta:**
- **El editor es obligatorio y hay que hablarle de fuera.** Remote Control (HTTP) existe, pero ejecutar Python por él exige abrir una superficie de ejecución remota que el modo automático bloqueó. Lo sustituyó una cola local: `init_unreal.py` ejecuta cada `Saved/cola_py/*.py` en el tick del editor y deja un `.out`. Funciona, pero cada script tarda lo que tarde el editor y los errores de reentrada (el tick se vuelve a llamar durante una captura) costaron una ronda entera.
- **Ningún diálogo modal se puede cerrar.** Un «¿sobrescribir?» congeló el editor; la solución fue matar el proceso y apartar carpetas antes de reconstruir. Cada corrección = reiniciar el editor (7 reinicios en 40 min).
- **Niagara en commandlet se cae**: hay que tener el editor abierto con ventana.
- **Lo visual no se depura por texto.** Sprites a cuadros, sol bajo el horizonte, muro vertical, núcleo gigante: cada uno se vio solo en la captura, nunca en un log. Sin poder mirar la ventana, cada iteración son dos minutos de reconstrucción y una captura.
- **Huecos de la API**: sin Timeline, sin nodos de Enhanced Input, sin `begin_deferred_actor_spawn`, el valor por defecto de un pin promovible no se guarda, `UNiagaraExternalEditUtilities` solo desde C++. Cada hueco se rodea, pero el rodeo es un sitio donde Pablo tendrá que entrar a mano.
- **Contenido**: sin Fab por script. Todo el aspecto depende de lo que haya en el disco.

**Valoración honesta.** Para construir estructura (sistemas, Blueprints, nivel, pruebas) el flujo con agentes funciona en Unreal casi tan bien como en Godot. Para el aspecto, no: Godot deja los shaders y las escenas como texto que se lee, se compara y se corrige sin abrir nada; en Unreal el material, la curva o la escala que están mal solo se ven en una captura, y corregirlos por script es a ciegas. El 80 % del tiempo de esta POC se fue en ese ciclo (reconstruir, capturar, mirar), no en escribir. Comparado con la prueba A: en Godot las iteraciones de aspecto fueron tres rondas de ajuste fino; aquí fueron cuatro rondas para llegar a «se ve fuego» y aún quedan humo, calor, fluidos y el núcleo.

## Cómo abrirlo

1. Abrir `E:\UnrealProjects\MS_POC_VFX\MS_POC_VFX.uproject` (el mapa de inicio es `Lvl_POC`).
2. Play. Teclas: **1** bola, **2** muro, **3** columna de sprites, **4** columna de fluidos.
3. Para reconstruir desde cero: apartar `Content/POC/VFX` y `Content/POC/BP`, abrir el editor y ejecutar en la consola Python `exec(open(r"E:\UnrealProjects\MS_POC_VFX\Scripts\04_niagara.py").read())` y luego `06_bp.py`, `07_personaje.py`, `08_capturas.py` (este último toma las capturas en PIE). Con el editor abierto también vale dejar un `.py` en `Saved/cola_py/`.
