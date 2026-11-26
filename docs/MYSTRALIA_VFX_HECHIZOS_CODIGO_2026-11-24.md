# Cómo monta Mages of Mystralia los VFX de los hechizos

24/11/2026 · Análisis técnico de la instalación local. El sistema combina **prefabs visuales por elemento y por fase**, componentes de comportamiento y un ciclo de apagado independiente del hechizo. La bola de fuego utiliza varias capas de partículas con texturas animadas, estelas y una luz. Para Magic Symbols, lo más aprovechable es cómo reparten esas capas y controlan su orientación, duración y final.

La fuente principal es el C# reconstruido de `E:\SteamLibrary\steamapps\common\Mages of Mystralia\Build_Data\Managed\Assembly-CSharp.dll`, junto con las configuraciones y jerarquías serializadas de `sharedassets202.assets`. Es código descompilado del juego distribuido, no el proyecto fuente del estudio. Las observaciones de composición proceden de los prefabs; no se ha medido su coste en ejecución.

## 1 Cómo separan el hechizo de su dibujo

`MagicSystem.SpellFactory.Build` crea el hechizo base a partir de su descripción, inicializa su configuración y añade los componentes de las runas. Después hace lo mismo con las runas que lanzan otros hechizos y emite `RaiseOnAwake`.

La instancia lógica tiene posición, colisión, duración y componentes de movimiento. El efecto visual se obtiene aparte mediante `PoolUtils.SpawnFx`. Por ejemplo, `SpellRange` conserva una referencia `_fxMain` a un sistema de partículas que sigue al objeto del hechizo mediante `FollowGameObject`.

Esta separación permite que la colisión termine mientras las partículas que ya nacieron siguen visibles. También permite cambiar la trayectoria del hechizo sin crear una animación completa para cada combinación de runas.

El recorrido del proyectil es:

1. `SpellRange.Init`: configura el radio del colisionador y la dirección inicial.
2. `OnAwake`: reproduce `fxCastStartPrefab` en el punto de nacimiento.
3. `OnStart`: elige `fxMainPrefab` o `fxMainBigPrefab` y lo hace seguir al hechizo.
4. Movimiento y colisiones: los componentes de las runas modifican la instancia lógica.
5. `OnDespawn`: reproduce `fxAbortPrefab` y llama a `TurnOff` sobre el efecto principal.

**El final ordinario del proyectil usa `fxAbortPrefab`.** La detonación es otra conducta, con sus propios prefabs y su cálculo de daño. No conviene interpretar cada desaparición de una bola como una explosión de área.

## 2 Cómo organizan el catálogo visual

`FxSpellConfigManager` contiene una configuración por elemento: `fire`, `ice`, `electric` y `earth`. La esencia interna `Air` se resuelve a `electric`; hay que tenerlo en cuenta al interpretar los nombres.

Cada `FxSpellConfig` es un `ScriptableObject`, un recurso editable de Unity que contiene referencias a efectos preparados. Entre sus campos aparecen:

| Función | Campos principales |
|---|---|
| Preparación | `fxPreChargePrefab`, carga acertada y fallida |
| Nacimiento | `fxCastStartPrefab` |
| Cuerpo del proyectil | `fxMainPrefab`, `fxMainBigPrefab` |
| Golpe cercano | normales, alternativos y anidados, con variantes grandes |
| Detonación | radial y direccional, con variantes grandes |
| Final | `fxAbortPrefab`, `fxFizzlePrefab`, `fxConjureDeathPrefab` |
| Acciones propias | escudo, dash, señuelo y teletransporte |

`CommonFxSpellConfig` agrupa efectos comunes: rebote, multidisparo, empuje, congelación, quemadura e indicadores de carga y maestría.

**La composición jugable reutiliza efectos preparados.** El código selecciona variantes y modifica su posición u orientación; no genera desde cero todo el dibujo para cada receta. Las variantes grandes son referencias distintas, aunque pueden compartir materiales y estructura con las pequeñas.

## 3 La bola de fuego real

La configuración serializada `FireFxSpellConfig` tiene el identificador local 11105 en `sharedassets202.assets`. Su `fxMainPrefab` apunta a `FXSP_Orb_Fire_Pat`.

Su jerarquía contiene seis sistemas de partículas, dos componentes `TrailRenderer`, varios `Animator` y una luz:

| Capa | Recursos y configuración observados | Papel visual que sugiere la composición |
|---|---|---|
| Raíz `FXSP_Orb_Fire_Pat` | Material `PatFire_Base`, atlas de 4×4, partículas en espacio local | Volumen principal de la llama |
| `PatFire_tisons` | Material `FX_M_FLARE_ROUND_V2`, espacio de mundo | Brasas que quedan detrás |
| `Patfire_smoke` | `FX_M_SMOKE_TOON_SPLIT_BLEND`, espacio de mundo, UV de 1×4 | Humo separado del núcleo |
| `PatFire_trailing_flame` | Atlas de 4×4, renderizado de partículas estiradas, espacio de mundo | Llama que prolonga el movimiento |
| `PatFire_base` | Material `PatFire_Base_2`, atlas de 4×4, espacio local | Otra capa de llama alrededor del cuerpo |
| `PatFire_round` | Material `PatFire_Base_3`, atlas de 2×2, espacio local y estela | Refuerzo redondeado del cuerpo |
| `Point light` | Luz con animador y componente adicional | Iluminación alrededor del efecto |

Los materiales de llama y estela usan el shader `Borealys/FX/SH_Particles_Additive_HDR`. El humo usa `Particles/Alpha Blended`. Así pueden combinar partes luminosas que suman color con humo que conserva opacidad.

**El fuego usa animación dibujada en texturas.** Un atlas de 4×4 proporciona 16 cuadros y el módulo UV recorre esos cuadros durante la vida de la partícula. La forma de la llama está, en parte, en ese dibujo, además de las curvas de tamaño, color, rotación y las fuerzas del emisor.

La separación entre espacio local y espacio de mundo es especialmente útil: el cuerpo acompaña a la bola; las brasas, el humo y parte de la llama conservan su recorrido detrás. Al girar o rebotar, la historia del movimiento puede permanecer visible sin arrastrar toda la nube como un bloque.

`FXSP_Orb_Fire_Pat_Big` es el prefab de la variante grande. La jerarquía incluye capas equivalentes; su existencia permite ajustar la versión grande por separado.

## 4 El nacimiento y el impacto tienen otra composición

El nacimiento del fuego utiliza `FXSP_Baguette_Start_Fire`: un sistema raíz con material de humo, un `CORE_FLARE` y brasas. Es un destello separado del cuerpo viajero.

El final ordinario utiliza `FXSP_Abort_Fire`, con humo, `CORE_FLARE`, `EXPLO2D`, `Burnring`, humo adicional y brasas.

La detonación utiliza `FXSP_Detonate_Fire`. Entre sus capas hay destellos, anillos, un dibujo de explosión, un corte de fuego, chispas y distintos sistemas de humo. Algunas piezas de la jerarquía pueden servir de soporte o referencia; la mera presencia de un nodo no demuestra que se vea en todas las ejecuciones.

`SpellConfigDetonation.fxDetonationPrefab` elige entre cuatro opciones según las runas: radial pequeña, radial grande, direccional pequeña o direccional grande. `SpellDetonation` aplica la orientación y espera el retraso configurado antes de reproducir el efecto y calcular el daño.

La zona de daño usa `Physics.OverlapSphere` y configuraciones de esferas. El dibujo no es el colisionador. Cuando la detonación es visible para la cámara, el código también solicita sacudida y vibración.

## 5 Cada elemento cambia sus piezas

Los prefabs principales de los otros elementos muestran composiciones diferentes:

| Elemento interno | Prefab | Capas observadas |
|---|---|---|
| `Ice` | `FXSP_Orb_Ice` | Cristales, humo de mundo, humo local, copos y estela |
| `Earth` | `FXSP_Orb_Earth` | Rocas, rocas pequeñas, restos, hojas, humo y estela |
| `Air` | `FXSP_Orb_Air` | Chispas, bola eléctrica, brillo, humo y dos capas de rayos |

Hielo y tierra incluyen partículas renderizadas como mallas. Sus diferencias vienen de la geometría, las texturas y las capas de movimiento; una misma bola recoloreada no describe estos prefabs.

## 6 Cómo representan las runas

`SpellVelocity` reúne componentes que aportan velocidad inicial, velocidad adicional y velocidad angular. Actualiza el movimiento y orienta el objeto del hechizo hacia su velocidad. El efecto puede seguir esa transformación.

`SpellRange.OnStart` distingue dos casos concretos:

- Con `SpellMove`, el efecto sigue posición y rotación del hechizo.
- Sin `SpellMove`, nace mirando hacia abajo y sigue la posición sin seguir la rotación.

Por tanto, la bola quieta y la viajera pueden compartir prefab y presentarse con orientaciones diferentes.

`SpellBounce` refleja la velocidad contra la normal de la superficie y reproduce el efecto común de rebote, orientado contra la nueva velocidad. `SpellDuplicate` clona el hechizo, elimina del clon el componente que volvería a duplicarlo y añade un efecto común de multidisparo.

`SpellOnHit` prepara otro hechizo guardado y lo construye con `SpellFactory.Build` en el lugar correspondiente. Ese hechizo hijo obtiene su propio efecto y ciclo. Esto explica cómo componen cadenas de efectos sin preparar una animación única para la cadena completa.

## 7 Cómo evitan cortes al terminar

`TurnOffFX` permite apagar de forma coordinada partículas, sprites, luces y componentes de alfa. Detiene la emisión; solo borra las partículas inmediatamente si `clearOnStop` está activado. También limpia los `TrailRenderer` al reactivar el objeto para evitar que una instancia reutilizada conserve una estela antigua.

`PoolUtils.SpawnFx` obtiene efectos de un pool, normalmente el global. Los efectos que no están en bucle se entregan a `FxDespawner` automáticamente. Para los que están en bucle, la extensión `TurnOff` inicia ese retorno después del apagado.

`FxDespawner` comprueba cada 0,5 segundos si quedan partículas vivas, incluyendo las hijas. Cuando han terminado, devuelve la instancia al pool y la limpia. Tiene además un tiempo máximo de seguridad configurable.

Esto separa tres momentos: **dejar de hacer daño, dejar de emitir y desaparecer por completo**. El hechizo lógico también tiene su propia destrucción; el pooling observado aquí corresponde a los efectos y no implica que todas las instancias lógicas se reciclen.

## 8 Los conjuros que dejan cosas en el suelo

`SpellConjure` usa objetos `AConjure` y `PlayerConjure`, no solo el efecto de una bola. Controla la distancia entre apariciones, el número máximo de piezas y si hay una posición válida de suelo. Orienta cada aparición según la normal de la superficie.

Cuando la combinación de elemento y terreno no admite la aparición —por ejemplo, tierra sobre agua o hielo sobre lava en los casos comprobados— puede reproducir `fxConjureDeathPrefab`.

También existen utilidades de estelas sobre el suelo como `UpdateTrailPosition` y `TrailFadeOut`, con raycasts y reducción progresiva de longitud. Su presencia en el ensamblado no demuestra que las usen todos los hechizos; para atribuirlas a un caso concreto hay que seguir el prefab correspondiente.

## 9 Qué aprovechar en Magic Symbols

Nuestro `presentacion/vfx_elemento_3d.gd` ya separa el dibujo de `HechizoVivo`, tiene seguidores y contempla soltar el efecto al desaparecer el hechizo. El patrón de Mystralia refuerza esa dirección.

Las mejoras que más sentido tienen a partir de este análisis son:

1. **Componer una bola de fuego con pocas capas claras:** cuerpo animado, llama de arrastre, brasas, humo y luz. Ajustar primero qué aporta cada una.
2. **Separar el espacio de simulación:** cuerpo local; humo, brasas y rastro en el mundo. Probarlo con curvas y rebotes.
3. **Dar a nacimiento, choque y agotamiento recursos propios.** Reservar la explosión que comunica área de daño para las recetas que realmente la producen.
4. **Preparar variantes cuando cambia la silueta:** una detonación direccional o una versión grande pueden necesitar otra composición, además de escala.
5. **Definir un apagado común:** detener emisión y luz, dejar terminar la cola y después liberar o reciclar. Al reciclar, limpiar estelas y restaurar el estado.

La primera prueba útil sería un proyectil de fuego con tiro recto, curva y rebote. El criterio visual: el cuerpo debe conservar su lectura, la cola debe mostrar el recorrido y el impacto debe distinguirse del agotamiento. Estas son propuestas para nuestro proyecto; no se ha cambiado su implementación durante el análisis.

## 10 Referencias para continuar

Instalación analizada: `E:\SteamLibrary\steamapps\common\Mages of Mystralia\Build_Data`.

Los archivos auxiliares están en `.godot/mystralia-analysis/`, fuera del código del juego y dentro de la caché del proyecto:

- `types/`: clases C# seleccionadas, separadas por tipo.
- `decompiled/Assembly-CSharp.decompiled.cs`: ensamblado reconstruido completo.
- `spell_configs.json`: las cuatro configuraciones elementales y su gestor.
- `prefab_layers.txt`: jerarquías y materiales de los cuerpos pequeños y grandes, nacimiento, detonación radial, detonación direccional y final de los cuatro elementos.
- `prefab_layers.json`: detalle serializado de esas jerarquías, partículas y materiales.
- `inspect_assets.py`, `spell_assets.py`, `prefab_layers.py`: scripts de inspección.

Estos auxiliares pueden perderse si se limpia la caché `.godot`. Para reproducir la inspección se necesitan ILSpy, UnityPy y TypeTreeGeneratorAPI; los recursos originales permanecen en la instalación del juego.

Como contexto adicional, Patric Mondou explicó que debieron adaptar las partículas a las curvas y rebotes de las runas para que siguieran siendo legibles, y que buscaron referencias en manga y cine para su aspecto estilizado. [Entrevista al desarrollador en Game Developer](https://www.gamedeveloper.com/design/-i-mages-of-mystralia-i-dev-dishes-out-spellcasting-wisdom-and-game-industry-real-talk).
