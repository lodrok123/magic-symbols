# Genshin Impact · direccion de VFX y arte · que copiar en Magic Symbols

Analisis del 7/11/2026 sobre la instalacion real de `C:\Program Files\Genshin Impact`
(version instalada: build sobre Unity 2017.4.30f1 fuertemente bifurcado).

---

## 0. Que se ha podido mirar y que no

Hay que decirlo antes de nada, porque condiciona el valor de cada afirmacion de abajo.

**No accesible.** Los 59,5 GB de contenido (2403 ficheros `.blk`, de los que uno solo —
`StreamingAssets/AssetBundles/blocks/00`, 1492 ficheros — pesa 57,4 GB) son contenedores propios
cifrados de miHoYo. Ahi dentro estan las texturas, mallas, materiales, prefabs de VFX y el codigo
fuente de los shaders. No se abren sin herramientas de extraccion de terceros, asi que **no he visto
ni una sola textura ni un solo material del juego**.

**Si accesible, y es mas util de lo que parece.** Los ficheros Unity sin cifrar
(`globalgamemanagers`, `globalgamemanagers.assets`, `resources.assets`, 115 MB en total) conservan en
claro la lista de modulos nativos del motor, la lista de shaders siempre incluidos y, sobre todo,
**los nombres de 1791 propiedades de shader**. Un nombre de propiedad es una confesion: dice que
dato existe, quien lo consume y a que nivel vive. De ahi sale casi todo este documento.

**Mas dos capturas reales** que tenias en `Genshin Impact game/ScreenShot/` (una en Inazuma/Watatsumi,
otra en Sumeru interior). Son evidencia visual directa y las uso al final.

Lo que sigue separa **medido** (lo que literalmente aparece en los binarios) de **deducido**.

---

## 1. La arquitectura: no es Unity, es un motor propio con fachada de Unity

**Medido.** Junto a los modulos estandar de Unity aparecen estos modulos nativos que miHoYo ha
escrito y compilado dentro del motor:

| Modulo | Para que es |
|---|---|
| `UnityEngine.ErosionModule.dll` | sistema de **erosion**: quemado, mojado, propagacion por sectores |
| `UnityEngine.AOFieldModule.dll` | campo de **oclusion ambiental** volumetrico |
| `UnityEngine.GPUParticlesModule.dll` | particulas en GPU (VFX de verdad, no el ParticleSystem de Unity) |
| `UnityEngine.MiHoYoVegetationModule.dll` + `WindModule` | vegetacion y viento |
| `UnityEngine.LightWeightInstanceSystemModule.dll` | instanciado masivo de props |
| `UnityEngine.SoftwareOcclusionModule.dll` | oclusion por CPU |
| `UnityEngine.StreamingV2Module.dll` | streaming del mundo abierto |
| `UnityEngine.EgeriaSystemModule.dll` | sistema de terreno |
| `UnityEngine.ArkashaSystemModule.dll` | sistema de escena/nivel |
| `UnityEngine.PBDMeshSimulationModule.dll` | fisica de tela y pelo (position-based dynamics) |

Y la lista de shaders siempre incluidos revela el pipeline:

```
Hidden/Internal-DeferredShading          Hidden/Internal-ColorGradingVolume
Hidden/Internal-DeferredDecalPrepare     Hidden/Internal-HeightFog
Hidden/Internal-ErosionSectorRender      Hidden/Erosion/SectorBake
Hidden/MiHoYoScreenSpaceGrass            Hidden/MiHoYoDeformation
Hidden/MiHoYoSSSDiffusion                Hidden/PerObjectShellResolve
Hidden/Internal-MainLightCaustic         Hidden/Internal-LocalLightCaustic
Hidden/Internal-ObjectOITBlend           Hidden/Internal-Skylight
miHoYo/Scene/Base New                    miHoYo/AOField/AmbientOcclusionField
miHoYo/Fog/GodRay                        MiHoYo/Nature/LocalWindsMapReproject
miHoYo/Occlusion/DynamicOcclusion        miHoYo/Hidden/UpdateClipmap2D
```

**Deducido, y es la leccion de esta seccion:** la fuerza visual de Genshin no esta en que sus
artistas pinten mejor. Esta en que **cada cosa que da cohesion la hace el motor en un sitio unico y
global**, no cada material por su cuenta. Lo que en otro juego seria "acuerdate de poner el mismo
tinte en los 400 materiales", aqui es un modulo nativo. Esa es la diferencia estructural.

---

## 2. Los seis mecanismos de cohesion (el nucleo del analisis)

Esto es lo que preguntabas. Son seis, y estan ordenados por cuanto aportan.

### 2.1 El bloque `_ES_*`: un unico "Environment Setting" global que leen TODOS los shaders

**Medido.** Existe una familia de ~34 propiedades globales con prefijo `_ES_`:

```
_ES_SunDirection          _ES_SkyCenterWorldPos      _ES_SkyWorldUpDir
_ES_TopFrontColor         _ES_TopBackColor           _ES_SkyFrontAndBackBlendFactor
_ES_BottomFrontColor      _ES_BottomBackColor        _ES_BottomColorHeight
_ES_HorizonHaloColor      _ES_HorizonHaloHeight      _ES_HorizonHaloIntensity
_ES_InnerShadowColor      _ES_OuterShadowColor
_ES_CharacterMainLightColor  _ES_CharacterMainLightRatio
_ES_CharacterAmbientBrightness  _ES_CharacterEnvLightIntensity  _ES_CharacterAmbientLightOn
_ES_AvatarFrontRimColor   _ES_AvatarBackRimColor     _ES_AvatarRimWidth  _ES_AvatarRimWidthScale
_ES_SceneFrontRimColor    _ES_FoliageTrickAmbientFactor
_ES_GlobalFarFogParams0..3  _ES_SkyFogTopIntensity  _ES_SkyFogHaloMin  _ES_SkyFogVerticalBlendMin
_ES_DungeonLightDir
```

Lee esa lista despacio, porque es una declaracion de principios:

- El **cielo** no es una textura: son cuatro colores (`TopFront`, `TopBack`, `BottomFront`,
  `BottomBack`) mezclados segun el angulo al sol, mas un halo de horizonte. Cuatro colores definen
  la atmosfera entera.
- La **sombra** tiene color explicito, y dos: `InnerShadowColor` y `OuterShadowColor`. La sombra no
  es "menos luz", es **otro color decidido por el director de arte**, y lo deciden una vez para toda
  la zona.
- La **luz sobre personajes** es independiente de la luz de la escena
  (`_ES_CharacterMainLightColor`, `_ES_CharacterMainLightRatio`, `_ES_CharacterAmbientBrightness`).
  Los personajes nunca se oscurecen "de mas" aunque la escena si.
- El **rim light** de personajes es global (`_ES_AvatarFrontRimColor` / `BackRimColor` / `RimWidth`),
  y existe su equivalente para la escena (`_ES_SceneFrontRimColor`). Todos los objetos del mundo
  reciben el mismo borde de luz.
- `_ES_DungeonLightDir`: en interiores la direccion de luz se **sustituye** por una fija, para que
  los personajes sigan leyendose aunque no haya sol.

**Deducido.** Esto es *la* respuesta a "como consiguen cohesion". No la consiguen pieza a pieza. La
consiguen porque **ningun material decide su propia atmosfera**: todos leen el mismo bloque de
uniformes, y ese bloque se interpola entre zonas y horas del dia. Un asset nuevo entra en el mundo
ya integrado el dia que lo metes, sin retoque, porque su integracion no vive en el asset.

### 2.2 `_DeferredToonRampTex`: una sola rampa de luz para todo el juego

**Medido.** `_DeferredToonRampTex` es una propiedad del paso de **deferred shading**, no de un
material. Junto a ella: `_EnablePenumbraRamp`, `_PenumbraRampOpacity`,
`_LowResolutionPenumbraRampMask`, `_LowResolutionShadowInnerOutline`.

**Deducido.** El corte celshading no lo hace cada shader: lo hace el pipeline, una vez, en pantalla,
con **una textura de rampa compartida**. De ahi que la piedra, la madera, la tela y la hierba tengan
exactamente el mismo caracter de luz. Y `ShadowInnerOutline` explica ese filo oscuro que llevan las
sombras propias de Genshin: es un realce de borde en el buffer de sombra, global.

Detalle revelador: `_TreeDiffuseRampScale` y `_TreeDiffuseRampOffset`. Los arboles **no tienen su
propia rampa**, tienen un *desplazamiento dentro de la rampa comun*. Asi se desvian sin romper.

### 2.3 Gradacion de color por volumenes, no por zona hecha a mano

**Medido.** `Hidden/Internal-ColorGradingVolume`, `_ColorGradingProfile`, `_ColorGradingProfileArray`,
`_SDRColorGradingSrcLUT` / `_SDRColorGradingDstLUT`, `_LUTScale`, `_LUTBias`.

**Deducido.** Hay un array de perfiles de gradacion y se mezcla entre el LUT de origen y el de
destino segun donde este la camara. Cuando entras en una cueva, el color del mundo entero se desliza
hacia el LUT de la cueva. No hay "assets de cueva" con colores de cueva: hay **assets neutros bajo un
LUT de cueva**.

### 2.4 La niebla la tiñe el cielo

**Medido.** `_SkyGradientTex`, `_SkyGradientLUTForFog`, `_HeightFogRamp`, `_HeightFogColBase`,
`_HeightFogColDelta`, `_HeightFogRadialCol`, `_HeightFogSkyColIntensity`, `_ES_GlobalFarFogParams0..3`,
`_AmbientGroudColor` (el typo es suyo) y el bloque completo de `_VolumetricFog*`.

**Deducido.** La niebla lejana no tiene color propio: **muestrea el gradiente del cielo**. Por eso el
horizonte de Genshin nunca "despega" del cielo. Y `_AmbientGroudColor` dice que la luz ambiente es
hemisferica: color del cielo por arriba, color del suelo por abajo. Un objeto sobre hierba recibe
verde por debajo. Gratis, global, y es media cohesion.

### 2.5 El clipmap: el mundo alrededor del jugador como una textura

**Medido.** Una familia enorme: `_ClipmapTexture`, `_ClipmapWorldToUVAndMul`, `_ClipmapResolution`,
`_ClipmapZOffset`, `_NextClipmapWorldToUVAndMul`, `miHoYo/Hidden/UpdateClipmap2D`,
`_DeformationHeightMapRW` (+ mips 1/2/3), `_DeformationNormalMapRW`, `_HeightfieldDeformationLayerMap`,
`_HeightfieldDeformationDirtyMap`, `_DeformationProjection`, `_EnableSandBlend`, `_SnowV2On`,
`_SnowV2SSSColor`, `_SnowGlitterSpecularIntense`, `_SandGliter_TillPowerGamma`,
`MiHoYo/Nature/LocalWindsMapReproject` + `_LocalWindsMapCameraInfo`.

**Deducido.** Hay varias texturas centradas en el jugador que se desplazan con el (clipmaps): altura
de deformacion, normales de deformacion, capa de material, mapa local de viento. Pisar la nieve no
modifica la nieve: **escribe en una textura** que todos los shaders de suelo leen. El viento no se
aplica planta a planta: hay un **mapa de viento** que la hierba, las hojas y los VFX muestrean igual.
Por eso todo se mueve junto.

### 2.6 El mapa de erosion: una sola mascara proyectada que tiñe suelo, hierba y arena

**Medido.** `_ErosionMapViewProject`, `_ErosionMapHeightScaleBias`, `Hidden/Erosion/SectorBake`,
`Hidden/Erosion/SectorRender`, y los tintes: `_ErodeWetTint`, `_ErodeGrassTint`, `_ErodeSandTint`,
`_ExcludeWetTint`, `_UnderWaterWetTint`, `_ErodeWetFade`, `_ErodeWetOffset`, `_ErodeWetSmooth`,
`_WetErodeNoisePow`, `_ErodeNoise`, `_ErodeNoiseTill`, `_ErodeNoisePow`.

**Deducido, y esto te toca de lleno.** Existe **un mapa de erosion proyectado desde arriba**,
horneado y renderizado por *sectores* (`SectorBake` / `SectorRender`), con su propio modulo nativo. Lo
consumen el suelo, la hierba y la arena, **cada uno con su tinte pero con la misma mascara y el mismo
ruido**. Cuando llueve no se moja "el shader de la roca" y "el shader de la tierra" por separado:
se escribe una vez en la mascara y los tres responden coherentes.

Esto es exactamente el problema que Magic Symbols resuelve hoy casilla a casilla.

---

## 3. Texturas

**Medido (indirecto, pero duro).** Todo el contenido del juego — mallas, texturas, materiales,
prefabs de VFX, animaciones, shaders, configuracion — cabe en **59,5 GB**. Para comparar, en la misma
instalacion el **video** ocupa 43,7 GB y el **audio** 42,5 GB. Es decir: un mundo abierto de siete
regiones pesa poco mas que sus cinematicas.

**Deducido.** Eso solo sale de una forma: **las texturas no llevan luz, ni suciedad, ni desgaste, ni
color de ambiente**. Llevan forma y poco mas. Todo lo demas lo pone el pipeline en tiempo real
(rampa comun, bloque `_ES_`, LUT de zona, niebla del cielo, mapa de erosion, AO field). Una textura
"limpia" se reutiliza en siete regiones; una textura con luz horneada solo sirve donde se horneo.

Pistas concretas de que las texturas son **procedurales y parametrizadas**, no pintadas:

```
_BrickBlend  _BrickRandomClip  _BrickSmoothStepStart  _BrickSmoothStepEnd   <- ladrillo por shader
_BorderWhiteness  _DetailMapTintColor                                        <- bordes y detalle por parametro
_BaseShapeNoise  _BaseShapeNoiseTiling  _DetailShapeNoise  _DetailShapeNoiseTiling
_CurlNoiseTex  _BlueNoiseTex  _VolumeNoiseTex  _FlowMap  _DistortionTex
```

El ladrillo de Mondstadt es **un shader con una junta parametrizada**, no un atlas de ladrillos
pintado. De ahi que todos los ladrillos del juego sean el mismo ladrillo a distintas escalas, y de
ahi que no canten.

**Regla que se deduce:** *la textura aporta forma; el color lo decide el nivel.* Si un asset trae su
color decidido, el asset manda sobre la direccion de arte, y la direccion de arte deja de existir.

---

## 4. Suelos

Aqui hay el hallazgo mas concreto de todo el analisis.

**Medido.** Aparecen en claro las clases `CompleteTerrainShader`, `CTSTerrainManager`,
`CTSTerrainStitcher`, `CTSTerrainTextureDetails`, `CTSRuntimeTerrainHelper`. **CTS (Complete Terrain
Shader)** es un asset comercial de Unity (Procedural Worlds). Genshin parte de el para el terreno.

Y las propiedades de mezcla:

```
_EnableHeightBlend  _EnableThirdHeightBlend  _BlendValueFrom  _BlendValueFromThird
_BlendUV_NearFar  _DetailMapTintColor  _SecTexWithSand  _EnableSandBlend
```

**Deducido.** El suelo de Genshin es:

1. **Mezcla por altura, no por alfa, de hasta tres capas.** `_EnableThirdHeightBlend` confirma la
   tercera. Mezclar por altura es lo que hace que la tierra "se meta entre" las piedras en vez de
   disolverse encima. Es la diferencia visual entre un suelo de juego indie y uno de produccion, y
   cuesta diez lineas de shader.
2. **Tiling doble cerca/lejos** (`_BlendUV_NearFar`): una escala de textura al pie y otra a distancia,
   mezcladas por profundidad. Mata el patron repetido sin aumentar la resolucion.
3. **Tinte de detalle por parametro** (`_DetailMapTintColor`): la misma textura de detalle sirve para
   todas las regiones, cambiando un color.
4. **Arena y nieve como capa global**, no como material: `_EnableSandBlend`, `_SnowV2On`,
   `_SnowGlobalWarpFactor`, `_SnowGlobalWarpRampParams`, `_SnowGobalWarpMode`. Se activa un
   interruptor global y *todo* el suelo pasa a nevado, con su SSS (`_SnowV2SSSColor`) y su brillo
   (`_SnowGlitterSpecularIntense`).
5. **Hierba en espacio de pantalla**: `Hidden/MiHoYoScreenSpaceGrass`, `_SSGTileSizeParams`,
   `_SSGTileValidTex`, `_SSGNoiseTex`. La hierba cercana se genera *desde el suelo visible*, no esta
   colocada. El suelo y la hierba no pueden descasar porque la hierba **es** el suelo.
6. **Decals diferidos** (`Hidden/Internal-DeferredDecalPrepare`): manchas, caminos y detalles se
   proyectan sobre el G-buffer. El suelo no necesita UVs unicas para tener historia.

La cadena completa de un suelo de Genshin es entonces: *tres capas mezcladas por altura, con doble
tiling, tintadas por parametro, cubiertas por decals diferidos, cubiertas por hierba de pantalla,
deformadas por un clipmap, tintadas por el mapa de erosion, iluminadas por la rampa comun, y
gradadas por el LUT de zona.* Ningun paso de esa cadena vive en el asset.

---

## 5. Assets y props

**Medido.** `UnityEngine.LightWeightInstanceSystemModule.dll`, `_TileMapMeshRenderDataBuffer`,
`_TileMapRootRenderDataBuffer`, `_PerTileCullingMask`, `_DrawIndirectArgumentBuffer`,
`UnityEngine.SoftwareOcclusionModule.dll`, `_SphericalHistogram_Resolution`.
Tambien: `miHoYo/Occlusion/DynamicOcclusion`, `_NpcProjectedShadowRT`, `_PerObjectShadowMapTexture`.
Y las capas de navegacion: `MihoyoWalkable`, `MihoyoNotWalkable`, `MihoyoWaterMask`,
`MihoyoCoverOvercome`, `MihoyoUGCNotWalkable`.
Y los materiales de bloqueo: `materials/stage_whitebox_preview`, `stage_whitebox_transparent_preview`,
`stage_whitebox_upface_preview`, `ProBuilder/Stage_Whitebox_Preview`.

**Deducido.**

- Los props se dibujan por **instanciado indirecto en tiles**, con culling por tile. Un kit pequeño
  repetido muchisimo sale gratis; un kit grande de piezas unicas no. El sistema **empuja** hacia la
  reutilizacion: la cohesion no es solo estetica, es la opcion barata.
- Los niveles se bloquean con **ProBuilder en whitebox** y hay materiales de whitebox embarcados en
  la build final. Diseñan la forma antes que el arte, siempre.
- El mundo lleva **capas de navegacion separadas del arte** (`Walkable` / `NotWalkable` /
  `WaterMask`). La malla visual y la malla jugable son cosas distintas. Un asset se puede cambiar sin
  tocar el juego.
- `_PerObjectShadowMapTexture` y `_NpcProjectedShadowRT`: cada personaje importante tiene su **propia**
  sombra proyectada, ademas de la del mundo. Es lo que hace que los personajes esten "pegados" al
  suelo aunque la sombra global sea suave.
- `miHoYo/AOField/AmbientOcclusionField` + `_AOVolume`: un campo volumetrico de AO horneado en la
  escena. Un objeto bajo un arco se oscurece correctamente **aunque sea dinamico**. Esto es lo que
  impide que los props se vean "pegados encima" del mundo.

---

## 6. VFX

**Medido.**

```
Modulo propio:   UnityEngine.GPUParticlesModule.dll
Mezcla:          Hidden/Internal-ObjectOITBlend   (transparencias sin orden)
Shader base:     miHoYo/Particles/Alpha Blended
Profundidad:     _SOFTPARTICLES  _EnableDepthBlendNoise  _DepthBlendNoiseTex  _DepthBlendNoiseIntensity
Deformacion:     _Distortion  _DistortionIntensity  _DistortionTex  _MobileDistort_Power/Speed/Till
Flujo:           _FlowMap  _FlowParams  _FlowScaleAndBias  _Mobile_FlowDir
Erosion:         _ErodeNoise  _ErodeNoisePow  _ErodeNoiseTill
Emision:         _EmissionCurve  _EmissionScaler  _EmissionRange  _AdditiveEmission
                 _UseMainMaskAlphaAsEmission  _UseSecondaryMaskAlphaAsEmission  _UseThirdMaskAlphaAsEmission
Bloom:           _MHYBloomExpossure  _BloomFactor
Luz volumetrica: _VLB_NoiseTex3D  _VLB_NoiseGlobal
Resolucion:      _HalfResParticleTexture
```

**Deducido, y esto es muy aplicable:**

1. **Un unico shader de particula con tres mascaras.** `_UseMainMaskAlphaAsEmission`,
   `_UseSecondaryMask...`, `_UseThirdMask...` dicen que el shader toma hasta **tres mascaras en
   escala de grises** y decide por interruptor cual alimenta la emision. No hay un shader por efecto:
   hay **un shader y mascaras**. Todo el VFX de Genshin — fuego, hielo, rayo, viento — sale de la
   misma pieza de codigo con texturas distintas y colores distintos.
2. **Erosion = disolucion.** `_ErodeNoise` / `_ErodeNoisePow` / `_ErodeNoiseTill` es el patron
   universal de Genshin: nada se desvanece bajando alfa, todo se **come por ruido**. Es la firma
   visual del juego y es una linea de shader.
3. **Mezcla por profundidad con ruido** (`_EnableDepthBlendNoise`): las particulas no se cortan
   contra la geometria con un degradado limpio, se cortan con un borde ruidoso. Es lo que hace que
   el humo "entre" en el suelo en vez de posarse sobre el.
4. **Bloom con exposicion propia por efecto** (`_MHYBloomExpossure`): el artista de VFX controla
   cuanto brilla su efecto en el bloom global, sin tocar el bloom global. Evita la guerra de "mi
   efecto no se ve, le subo la emision".
5. **Particulas a media resolucion** (`_HalfResParticleTexture`) y **OIT** para que el volumen no
   cueste ni parpadee en orden.

---

## 7. Lo que confirman tus dos capturas

Mirandolas con lo de arriba en la mano:

- **La sombra es azul-verdosa, no gris.** `_ES_InnerShadowColor` / `_ES_OuterShadowColor` en accion.
  En la captura de Sumeru la sombra bajo la mesa tira a verde oliva porque la zona lo manda, no
  porque la mesa lo lleve.
- **Los personajes estan mas iluminados que la escena.** En la de Watatsumi, el fondo esta en
  penumbra azulada y Lumine/Kokomi conservan luz plena y rim. Eso es `_ES_CharacterMainLightRatio` +
  `_ES_AvatarFrontRimColor`, no dos lamparas puestas a mano.
- **El suelo empedrado no repite.** Las losas de la captura 1 tienen junta por shader y variacion de
  tono por detalle tintado: `_BrickBlend` + `_DetailMapTintColor`.
- **Los vitrales de Sumeru no iluminan la escena, la tiñen.** Verde-azul a la izquierda, dorado a la
  derecha, y los personajes reciben ese color en ambiente. Eso es el LUT de zona mas ambiente
  hemisferico, no luces de colores.
- **Ni una textura con suciedad horneada.** Madera, piedra, tela y metal estan limpios. Toda la
  "suciedad" visible es AO y sombra en tiempo real.

---

## 8. Que aplicar en Magic Symbols, por orden de rentabilidad

El contraste que importa: el proyecto tiene hoy **195 piezas `.glb` con 344 texturas propias** en
`arte/meshy/piezas` (cada pieza de Meshy llega con su textura horneada), y **~85 shaders**, casi
todos un shader por efecto (`fuego_lelu_bola`, `agua_pilar`, `rayo_sello`, `tierra_grietas`...).
Genshin hace lo contrario en los dos ejes: **pocas texturas neutras + pocos shaders parametrizados +
toda la identidad en globales de zona**. Ahi esta el margen.

### Prioridad 1 — un bloque de ambiente global (`_ES_` casero)

Lo de mayor impacto por lejos, y Godot lo da hecho con **global shader uniforms**
(`RenderingServer.global_shader_parameter_set`). Define un bloque corto y haz que **todos** los
shaders del proyecto lo lean:

```
amb_sol_dir, amb_luz_color, amb_cielo_arriba, amb_cielo_abajo,
amb_sombra_color_dentro, amb_sombra_color_fuera,
amb_rim_color, amb_rim_ancho,
amb_niebla_color (derivado de amb_cielo_abajo), amb_niebla_params
```

Ahora mismo hay 106 llamadas a `set_shader_parameter` solo en `agua_render_3d.gd` y 74 en
`prueba_test2.gd`: parametros que viajan por script hasta cada material. Un bloque global los
sustituye y, mas importante, **hace que un asset nuevo entre ya integrado**.

Esto es tambien lo que `docs/PLAN_HOMOGENEIZAR_ARTE.md` persigue, pero atacado por el lado correcto:
no homogeneizar los assets, sino quitarles la decision.

### Prioridad 2 — una rampa de luz unica

Una textura de rampa en global, leida por `base_toon.gdshader` y por el material del terreno y de
las piezas. Los casos especiales no llevan rampa propia: llevan **offset y escala** sobre la comun,
como hace Genshin con los arboles (`_TreeDiffuseRampScale` / `_TreeDiffuseRampOffset`). Con eso, las
195 piezas de Meshy pasan a tener la misma luz aunque sus texturas vengan de origenes distintos.

### Prioridad 3 — mezcla por altura en el suelo

En el shader del terreno (`prueba_test2.gd`), sustituir la mezcla por alfa entre materiales de
casilla por **mezcla por altura** con un canal de altura por capa, y añadir **doble tiling
cerca/lejos**. Es barato y es la mitad de la sensacion de "suelo de produccion". Encaja directo con
lo que ya hace `EstadosSuelo3D` con los materiales de casilla.

### Prioridad 4 — una mascara de erosion de mundo en vez de estado por casilla

Magic Symbols ya tiene el dato (`EstadosSuelo3D`: helada, escarcha, quemado, mojado, costra). Lo que
falta es el **puente visual unico**: una textura de mundo (o un clipmap alrededor del jugador) donde
se escriban esos estados, leida por el shader del suelo, por el de la hierba
(`hierba_3d.gd`) y por los props de `arte_entorno_3d.gd`, **cada uno con su tinte propio** —
exactamente `_ErodeWetTint` / `_ErodeGrassTint` / `_ErodeSandTint`.

Hoy `arte_entorno_3d.gd` instancia rocas y brotes por casilla con tope de 40 nodos. Con una mascara,
el tinte del suelo y de la hierba sale gratis y los nodos quedan solo para lo que de verdad es
geometria. Y las reacciones (quemar hierba, mojar, helar) dejarian de verse como "casillas que
cambian" para verse como "una mancha que avanza".

### Prioridad 5 — colapsar los shaders de VFX

De ~85 shaders a un **shader `toy` uber** con: tres mascaras en gris, erosion por ruido, mezcla por
profundidad con ruido, distorsion, flowmap, y color/emision por parametro. Los shaders actuales de
`presentacion/vfx/toy/` ya comparten mucho codigo (`fuego_lelu_*`, `agua_*`, `rayo_*`); lo que falta
es el paso de "mismo codigo repetido" a "mismo codigo, una vez". Beneficio doble: un arreglo arregla
todos los elementos a la vez, y los elementos quedan obligados a parecerse.

El `flipbook_erosion.gdshader` y `scroll_erosion.gdshader` que ya existen son el buen camino — hay
que generalizarlo, no añadir el octogesimo sexto shader.

### Prioridad 6 — niebla tintada por el cielo, y ambiente hemisferico

Dos lineas: la niebla toma su color de `amb_cielo_abajo` en vez de tener color propio, y la luz
ambiente se separa en color de cielo (arriba) y color de suelo (abajo). Es el detalle que hace que
los objetos no floten.

### Lo que NO conviene copiar

- El clipmap de deformacion, el AO field, el voxel GI (`Lyra*`) y la hierba en espacio de pantalla
  son sistemas de equipo grande con modulos nativos. No son rentables aqui.
- CTS como tal no aplica: Godot no lo tiene, y el terreno de Magic Symbols es por casillas, no un
  heightmap continuo. Lo que se copia es la **idea** (mezcla por altura, doble tiling, tinte por
  parametro), no la implementacion.
- SSS de piel, caustics, shell fur: coste alto, retorno bajo en este estilo.

---

## 9. Resumen en una frase

Genshin no consigue cohesion cuidando cada asset: la consigue **quitandole a cada asset el derecho a
decidir su luz, su color de sombra, su niebla y su desgaste**, y poniendo esas decisiones en un unico
bloque global por zona. Las texturas solo aportan forma. Todo lo que une el mundo ocurre despues de
la textura, en el pipeline, una sola vez.

Para Magic Symbols eso se traduce en una sola frase accionable: **mover identidad visual desde los
materiales hacia globales de zona**, empezando por el bloque de ambiente y la rampa de luz unica.
