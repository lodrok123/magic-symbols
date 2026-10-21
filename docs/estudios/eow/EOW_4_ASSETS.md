# Echoes of Wisdom: estudio técnico de los assets (shaders, texturas, modelos, luz y efectos)

Objetivo: entender cómo resolvió Grezzo los problemas técnicos que tiene la prueba "poc_25d" de Magic Symbols (Godot 4.7), **sin copiar assets ni código**. Aquí solo hay cifras medidas, nombres de parámetros (que sirven como pistas de diseño) y conclusiones explicadas con palabras propias.

Origen: RomFS del cartucho de Pablo, `region_common/`. Copia de trabajo en el contenedor: `/mnt/user-data/uploads/Extraccion Juego/EXTRAIDO/Zelda/region_common/`.

Leyenda: **[M]** = MEDIDO (sale de leer los binarios), **[D]** = DEDUCIDO (interpretación mía; puede estar mal).

Herramientas propias (en `.../scratchpad/eow/assets/scripts/`):
- `dics.py`: localiza los diccionarios ResDic (`_DIC` o magic 0) y sus claves en BFRES/BFSHA/BNTX.
- `bfsha_resumen.py` y `resumen_todos.py`: modelos de sombreado, opciones estáticas con sus valores, samplers, bloques uniform, atributos y nº de programas compilados.
- `bntx.py`: lee las cabeceras BRTI; desentrelaza el formato block-linear de Tegra y decodifica el mip0 (con `texture2ddecoder` compilado a mano) **solo para inspección local**.
- `bfres.py`: lee FMDL/FVTX/FSHP/FMAT/FSKL v9 (los offsets los verifiqué a mano en Pot y L_Dungeon001_001).
- `cbor_min.py`: decodifica `__ref_info.stref`, que resultó estar en CBOR.

Salidas en `.../eow/assets/out/`: `bfsha_resumen.txt`, `materiales.psv`, `bntx.txt`, `bfres.txt`, `bfres.json`, `stref.json`, más los listados de carpetas.

---

## 1. Shaders (BFSHA v8 con BNSH embebido)

### 1.1 Inventario [M]
- 96 `.bfsha` (62,3 MB) + 3 `.bntx` en `shader/`.
  - 81 son materiales: coinciden 1:1 con `ShaderList`, que tiene 81 filas.
  - 15 son de sistema y no aparecen en ShaderList: `postprocess`, `PP_DofCustom`, `clustered_culling`, `light_culling_compute`, `compute_shadowprojection`, `OptGGXLut`, `CubemapBlend`, `WaterBlend`, `ProjectionMask`, `CopyTexture`, `transition`, `shape_anim_compute`, `compute_convertToRgb8`, `dev_postprocess` y `Mock_TilingPatternAnim`.
- Cada material `.bfsha` contiene 2 modelos de sombreado: `<Nombre>` y `<Nombre>_depth`, la pasada de profundidad y sombras.
- Todos los materiales comparten **17 opciones estáticas de sistema**:
  - `model_mode` (0‑4)
  - `instancing_mode` (0/1)
  - `light_culling_mode` (fijo **3**)
  - `shadow_filtering_mode` (fijo 1)
  - `shadow_profile_mode` (0/1)
  - `fog_mode` (0/1)
  - `dither_mode` (0/1)
  - `shadow_distance_fade_mode` (fijo 1)
  - `use_alpha_test` (0/1)
  - `ambient_lighting_mode` (fijo 4)
  - `light_probe_grid_mode` (fijo 0)
  - `use_additional_light` (0/1)
  - `ssao_mode` (0/1)
  - `dev_r3d_shader`, `dev_mode` (38 valores), `dev_lod_level` (3) y `system_id`

  En el modelo `_depth` casi todas quedan fijas en 0. Lo único que varía ahí es `model_mode`, `dither_mode`, `use_alpha_test` e `instancing_mode`.
- Programas compilados por archivo (contando reflexiones de fragment en el BNSH):

| programas | nº archivos | ejemplos |
|---|---|---|
| 136 | 58 | todos los M_PBR_*, M_Lava, M_FloorLava, M_Unlit_CrackInside/CrackWall00 |
| 128 | 2 | M_Unlit_WaterBlock, M_WaterGeyser |
| 8 | 19 | casi todos los M_Unlit_* (cielo, nubes, stencil, decal...) |
| 4 | 2 | M_Water, M_Unlit_Decal |
| 392 | 1 | M_PBR_BG_RGBE_Fresnel (2 MB) |

  Total ≈ 8.700 programas en los 82 materiales/mocks.

### 1.2 Arquitectura de materiales [M nombres / D interpretación]
- **No hay un "uber‑shader" con opciones de material.** Las opciones son todas de sistema (niebla, dither, sombras, SSAO, instancing). La variación de material se hace con **81 shaders distintos**, uno por receta, cada uno con su propio bloque `Material` y nombres de parámetro en estilo editor de nodos:
  - Funciones reutilizables con prefijo `Fn_…`: `Fn_EffectPaste_*`, `Fn_VegetationTransform_*`, `Fn_UV_WorldPos_*`, `Fn_BG_Boundary_wall_*`, `Fn_CloudOpt_*`, `Fn_EffectCrack_*`.
  - El render info `shader_editor` y la opción `dev_r3d_shader` apuntan a un editor visual [D].
- Bloques uniform comunes: `Global, View, Shape, Skeleton, PerObject, LightSet, LightProbe, R3dDynamicOption, opt, Material`, más los buffers `LightMask`, `LightDepthMask` e `InstanceInfoArray`.
- Texturas de sistema a las que puede acceder cualquier material:
  - `_colorBuffer, _depthBuffer, _stencilBuffer, _opaqueColorBuffer, _customStencilBuffer, _projectionMaskBuffer, _currentDepthBuffer, _ssrBuffer, _normalBuffer, _occlusionTex`
  - `_shadowArray0, _envSpec0/1, _envLocalSpec0, _optimizeGGXLut, _dither`
- Nomenclatura (deducida de los nombres y comprobada con los samplers de cada familia):

| sufijo | significado | evidencia [M] |
|---|---|---|
| `RGB` | PBR fondo con Albedo + Normal + **RGBMap** empaquetado | samplers `Albedo0 Normal0 RGBMap0` |
| `RGBE` | igual + Emissive | + `Emissive0` |
| `L2` / `L3` | 2 / 3 capas de material mezcladas | `Albedo0..3, Normal0..2, RGBMap0..2` |
| `UV01`, `UV1`, `UV12` | qué canal UV usa cada capa | atributos `_u0 _u1 _u2` |
| `WP`, `WP0`, `WP02` | UV proyectadas en **world position** (planar/triplanar) | parámetro `Fn_UV_WorldPos_WorldPos_Scale` |
| `mVC` | máscara de mezcla = **vertex color** | atributo `_c0` |
| `m1A`, `m0A1`, `m3uv1` | máscara = alfa de una capa o UV de otra | [D] |
| `_B` | variante "Boundary" (mundo de la Grieta, vista lejana) | `Fn_BG_Boundary_wall_*`, `Fn_BG_FB_DistantView_*` |
| `Paste` | objeto "eco" colocado: disolución/aparición | 23 parámetros `Fn_EffectPaste_*` + sampler `Fn_EffectPaste_RGBMap4` |
| `Burn` | variante quemada | `albedo_color, mask0` |
| `UVanim` | UV animadas | `UVsrt` |
| `Fresnel`, `Whitish`, `MulColor` | ajustes de color y borde | — |
| `Unlit_*` | sin iluminación: cielo, nubes, grieta, stencil, decal, línea eléctrica, fade de techo... | — |

- **PBR de fondos (M_PBR_BG_RGB)**: solo 3 texturas, y los parámetros de material son únicamente `Alpha` y `DitherTransparency`.
- **PBR de personajes (M_PBR_Char00)**:
  - 57 parámetros, entre ellos `AlbedoColor, smoothness0, metalness0, EmissiveColor/Intensity, EnvmapBias, FresnelColor/Pow, UseSphereMap, Desaturation, TobeDark`, `mask_fresnel_*` y todo `Fn_EffectPaste_*`.
  - 14 samplers: `Smoothness0, Metalness0, Occlusion0` separados, `Emissive0/1`, `RGBMap0..2`.
  - El "look juguete" del personaje no viene de un PBR realista: viene de **fresnel de color + sphere map** (`paste_spheremap`) [D].
- **Ecos ("Paste")**: el mismo material lleva la animación de aparición y desaparición:
  - disolución con `DissolveStartPos/Size/Range/Inverse`
  - recorte alfa con retardo en el interior (`AlphaCutOut`, `AlphaCutOutInsideDelay`)
  - fresnel de color `MainColor/InsideColor`
  - gradiente animado
  - textura compartida `MI_paste_01_rgb4`: BC5 256², ruido Voronoi de 2 canales con un valor aleatorio por celda [M al decodificar]

  Es decir, el objeto "se construye por celdas" sin partículas.
- **Grieta (Crack)** `M_Unlit_CrackWall00` + `M_Unlit_Stencil` + `M_Unlit_CrackInside`:
  - la malla de la grieta escribe stencil (`Stenceil_Mask0/1/2_Switch`)
  - el interior se pinta con flowmap, gradiente radial y colores por profundidad (`SubColor1_NearZ/FarZ`)
  - el borde son 3 capas de textura con scroll y distorsión
  - `ProjectionMask` y `_projectionMaskBuffer` proyectan la máscara sobre la escena [D]

### 1.3 Agua, lava, vegetación (parámetros [M], lectura [D])
- `M_Water` (31 parámetros) / `M_WaterSide` / `M_Unlit_WaterSide` / `M_WaterSideBoundary`:
  - Opacidad por profundidad: `DepthMinOpasity`, `DepthMaxOpasity`, `DepthFadeOffset`, `DepthFadeLength`.
  - Espuma de orilla: `WaterEdgeColor`, `Width` / `EdghWidth`.
  - Cáusticas: `CausticsColorMin/Max`, `Intencity`, `Speed`, `SIze`, `Distance`.
  - Distorsión y flujo: `Distortion`, `FLowDistortion`, `FLowTexSize`, `FlowSpeed`.
  - Olas: 3 escalas de normal (`WaveScaleA/B/C`), `NomalSpeed`, `NomalIntencity`; `UseVartexColorG`.
  - Otros: `EnvMapIntensity` con sampler `Cube0`, `mtl/smt`, UV en world position.
  - **M_Water solo tiene 4 programas.** Existe además `WaterBlend.bfsha`, con samplers `_waterSampler, _waterEmissiveSampler, _opaqueSampler, _depthSampler` [M]. Mi lectura es que el agua se pinta en un buffer aparte y luego se compone con la escena opaca y su profundidad, para la refracción y el fundido por profundidad [D].
- `BlockWater.bfres` (bloque de agua del eco), **modular**:
  - 26 shapes: 8 esquinas (6 tris), 12 aristas (64 tris) y 6 caras subdivididas (512 tris cada una para el desplazamiento de vértices `VertecOffset`).
  - Total 3.888 tris, 1,65 m de lado [M].
  - Las piezas se encienden o apagan según los vecinos [D], que es justo el problema del agua por casilla.
- `M_Lava`, 14 parámetros: `Brightness, FlowSpeed, FlowDistortion, TexSize, BaceSmt, VertecOffset, RockTexSizeA/B, RockSpeed, RockIntencity, RockSmt, NomalOffset`.
  - Samplers: 2 albedo + 3 normales, entre ellas un flowmap `MI_LavaFlow_00_nml` en **R8G8 512² sin mips** y una máscara `MI_LavaHole_Mask`.
  - `M_FloorLava` usa un emisivo **BC5** de 2 canales (grietas incandescentes) más `Fn_EffectCrack_*` y UV en world position.
- `M_PBR_BG_Vegetation`: parámetros `albedo_color, mask0, Fn_VegetationTransform_WindRed, WindGreen, OscillationSpeed, WindVector`.
  - Lleva vertex color `_c0` [M].
  - El viento se pondera con los canales R y G del vertex color: R = balanceo de toda la mata, G = aleteo de puntas [D].
  - **No hay parámetros de interacción con el jugador** (hierba que se aparta) [M, por ausencia]. La hierba (`Grass.bfres`) es un actor con 1 hueso y 1 animación de material [M], así que la reacción a jugador, corte o fuego se resuelve como actor y no en el shader [D].

### 1.4 Post‑proceso (`postprocess.bfsha`, 3 MB, 60 modelos, ~405 programas) [M]
| función | modelos |
|---|---|
| Bloom | `pfx_brightpass` (con auto‑exposición), `pfx_downsample`, `pfx_blur`, `pfx_composite` |
| **Tilt‑shift / miniatura** | `pfx_tiltshift_blur`, `_blur_h`, `_blur_v`, `_transform`, `pfx_tiltshift_dof_transform`, `_dof_downsample`, `_dof_back_alpha_transform`; bloque `PFXTiltShiftParam` |
| DOF | `pfx_predof, pfx_dofblur(_low/_mid/_alpha), pfx_dof_composite(_back/_alpha), pfx_dof_factor` (6 pasadas) |
| SSAO | `pfx_ssao`, `_ssao_2/3/4_samples` (calidad escalable), `pfx_fastssao_downsample/calc/draw`, `pfx_ssao_blur`, `_composite(_2_occlusion)`, `pfx_ssaomask` |
| Contorno y silueta | `pfx_outline(_dilate/_blit/_clear)`, `pfx_edge_color`, `pfx_edge_geometry`, **`pfx_silhouette`** (personaje visto a través de paredes [D]), `pfx_fillcolor` |
| Composición final "uber" `pfx_color_filter` | `tonemap_mode` 0‑2, `use_vignette`, `use_color_transform`, `use_auto_exposure`, `chromatic_aberration_mode` 0‑3, `radial_blur_mode` 0‑3 |
| Otros | FXAA, SSR (pixel y compute), lens flare, mosaico, motion blur, feedback blur, grayscale, combinaciones add/mul/replace |

- `PP_DofCustom.bfsha` [M], parámetros: `focalDistance, focusRange, frontRange/Curve, backRange/Curve, blurSizeScale, blurRatio, tiltShiftCenter, tiltShiftNormal, tiltShiftRange, tiltShiftGamma, tiltShiftBlurRatio, tiltShiftDofBlurRatio, tiltShiftDofFocalDistance, tiltShiftDofBackRange/Curve, tiltShiftDofBackBlurFadeWidth, tiltShiftBlurSizeScale`.
  - El tilt‑shift se define como una **banda en pantalla**, con centro + normal (orientación) + rango + gamma, y se combina con el DOF por profundidad.
- `kodama/EnvironmentalEffect.kobin` contiene presets de entorno por tipo de escena [M]: `TiltShift`, `DOFoff`, `FieldCommonLowDOF`, `LDungeonCastle_TopLowDOF`, `DungeonTopWater`, `DungeonSideLava`... (47 claves). El DOF y el tilt‑shift se ajustan por escena, y distinguen vista cenital ("Top") de lateral ("Side").
- `Resolution.json` [M]: 1408×792 en dock y 1024×576 en portátil. Es render a resolución reducida y luego reescalado (`pfx_blit_scale`, `compute_convertToRgb8`).

### 1.5 Iluminación por GPU [M nombres / D funcionamiento]
- `clustered_culling.bfsha`: modelos `clear_tiles`, `raster_culling`, `raster_culling_yz`; bloques `PerLight`, `ZSlice`; buffers `LightMask` y `LightDepthMask`.
  - Funcionamiento [D]: rasteriza volúmenes de luz sobre una rejilla de clusters con cortes en Z y genera una máscara de bits por tile más una máscara de profundidad.
  - `light_culling_compute.bfsha` es la versión compute.
  - Todos los materiales compilan `light_culling_mode = 3` y `use_additional_light` 0/1.
  - Conclusión: hay muchas luces puntuales locales (antorchas, fuego) con coste por píxel acotado.
- `compute_shadowprojection.bfsha`: `compute_depth_minmax`, `override_shaodwprojection(_shadowpass/_eff)`, `override_projection_mask`, **`gpu_culling`, `gpu_culling_shadow`** (buffers `InstanceInfoArray → CulledInstanceInfoArray`, `IndirectBuffer`).
  - Hay culling de instancias en GPU con dibujado indirecto, que se usa para hierba y árboles instanciados [D].
  - El volumen de la sombra se ajusta a la profundidad mínima y máxima visible [D].
- `OptGGXLut.bfsha` genera en tiempo de ejecución la LUT de BRDF GGX ("Opt" = versión optimizada).
- `CubemapBlend.bfsha` (bloque `CubemapBlendParam`) mezcla dos cubemaps; se ve en `_envSpec0/_envSpec1` + `_envLocalSpec0`. Hay transición de reflejos entre sala/probe local y global [D].
- `DitherDefault.bntx`: **matriz Bayer 4×4 en R8** [M], valores 16,144,48,176 / 208,80,240,112 / 64,192,32,160 / 255,128,224,96.
  - Todos los materiales tienen el parámetro `DitherTransparency` y la opción `dither_mode` [M].
  - Hay además un `M_Unlit_BG_DFadeRoof` ("fade del techo") [M].
  - Lectura [D]: la transparencia por tramado de pantalla es universal; sirve para el fade de objetos o techos que tapan la cámara y para aparecer/desaparecer sin ordenar transparencias.
- `shape_anim_compute.bfsha`: los blend shapes se calculan en compute.

---

## 2. Texturas (BNTX)

### 2.1 Formatos [M]
Muestra: 257 texturas embebidas en 20 BFRES + 37 de `sharedtexture`, cubemaps y shader.

| uso (sufijo) | formato | nº |
|---|---|---|
| `_alb` albedo | **BC1 sRGB** (78), BC3 sRGB si hay alfa (3), BC4 (10, máscaras) | 91 |
| `_nml` normal | **BC5 SNORM** (2 canales) | 51 |
| `_rgb` mapa empaquetado de fondo | **BC1 UNORM** | 36 |
| `_smt` / `_mtl` personaje | **BC4 UNORM** (1 canal) | 40 |
| `_ems` emisivo | BC7 sRGB / BC1 sRGB; FloorLava BC5 UNORM | 4 |
| `rgb4` máscara paste | BC5 UNORM | 7 |
| flowmap lava | R8G8 UNORM sin mips | 1 |
| cubemaps | BC1 sRGB, 6 caras | — |

- **No hay ASTC ni BC6H/HDR.** BC7 es testimonial (4 casos).
- Mips completos en todo, menos el flowmap: 1024² → 11 mips, 2048² → 12 mips.
- Contenido del **RGBMap** [M por estadística]:
  - G = 0 en todas las texturas medidas: metalness 0 en fondos.
  - R ≈ 86‑171 de media, variable: smoothness o rugosidad [D].
  - B ≈ 170‑255, casi blanco: oclusión ambiental [D].
  - Los personajes, en cambio, llevan smoothness y metalness en BC4 separados.
- `PbrDefaultTextureSet.bntx` contiene los valores por defecto (64²): albedo, normal, metalness, smoothness, occlusion, emissive, rgbmap (RGBA8 blanco).

### 2.2 Tamaños [M]
| tipo | tamaño típico |
|---|---|
| personaje (Link, 123 texturas, 9,2 MB) | 256² (82), 512² (18), 512×256 (10); los ojos y la boca tienen varias versiones (`.0`, `paste_*`) |
| enemigo (Octorok) | 4×512² + 256²; 0,97 MB |
| objeto (Pot / Box / Chest / Bonfire) | 256²–512², 0,27–0,8 MB |
| hierba, césped | 256² / 128² y 64×32; 0,06–0,18 MB |
| sala de mazmorra | sin texturas propias (todo en compartidas) o 1024² (3‑10 texturas, 2,8‑8,6 MB) |
| conjunto compartido `MI_*` | 3 texturas (alb + nml + rgb) de 1024² = **2.809.984 bytes**; algunas paredes llevan normal + rgb a 2048² (9,1 MB) |
| cubemap por sala | **64² × 6, BC1 sRGB, 7 mips, 30.720 B** (37.000 B el archivo); global `Default` 128² |

### 2.3 `sharedtexture/` y `__ref_info.stref` [M]
- 788 `.bntx`, 1.063 MB en total, mediana 713 KB. Nombre = `MI_<zona>_<pieza>_<nn>.bntx`.
- Cada archivo agrupa el set del material: `MI_X_alb`, `MI_X_nml`, `MI_X_rgb`, y opcionalmente `_ems`.
- **El nombre del material en el BFRES es igual al nombre del set compartido** (p. ej. FMAT `MI_OP_ground_00` → `MI_OP_ground_00_alb/_nml/_rgb`).
- `__ref_info.stref` es un mapa **CBOR**: 193 claves de nivel o zona → lista de `.bntx` compartidos que necesita, 3.519 referencias en total.
  - Mediana de 17 sets por clave, máximo 105.
  - `L_Dungeon001` necesita 45 sets ≈ **84 MB** en disco; la mediana por zona es ≈ 19 MB [M].
  - Funciona como **manifiesto de precarga** por nivel [D].
- Los más reutilizados son `MI_Water_a/_b` (71/70 zonas), `MI_Forest_f_grass_01` (48) y los `joint_w_grass` (44, 38, 28).
  - Los **"joint"** son tiras de transición con alfa (BC3) que se superponen en los bordes entre suelos, por ejemplo hierba sobre tierra [M nombre + imagen decodificada].

### 2.4 Estilo (inspección visual local, no se entrega) [D]
- Albedos de **contraste bajo y pintado suave**. En las muestras de suelo y pared, el valor HSV p5–p95 abarca apenas 25‑45 niveles de 255:
  - hierba: 94‑125
  - pared Plains: 162‑208
  - mazmorra: 79‑123
- Ruido de alta frecuencia muy leve, sin luz horneada, detalle a base de manchas de color.
- Los personajes y enemigos (Octorok) son prácticamente **planos con degradados suaves**: aspecto de plástico o juguete pintado.
- Las hojas son tarjetas con alfa en atlas de 128×256.
- El cubemap de una sala es una foto real de esa sala a 64 px (se ve el muro de la mazmorra).

---

## 3. Modelos (BFRES v9)

### 3.1 Cifras por muestra [M]
| modelo | shapes | mats | huesos | vértices | **tris** | LODs | tamaño (m, X×Y×Z) | texturas |
|---|---|---|---|---|---|---|---|---|
| Pot (vasija) | 1 | 1 | 1 | 476 | **720** | 1 | 1,20×1,24×1,20 | 4 (256²) |
| BoxWooden | 1 | 1 | 1 | 528 | **728** | 1 | 1,57×1,50×1,57 | 4 (512²/256²) |
| BlockIce | 1 | 1 | 1 | 60 | **60** | 1 | 1,50³ | 5 (256², 1 BC7) |
| BlockWater | 26 | 1 | 1 | 2.402 | **3.888** | 1 | 1,65³ | 3 |
| SwitchFoot | 2 | 2 | 2 | 174 | **164** | 1 | 1,50×0,27×1,50 | 6 (128²) |
| TreasureBox | 2 | 1 | 2 | 1.128 | **1.084** | 1 | 1,42×0,71×1,75 | 4 |
| Bonfire | 1 | 1 | 1 | 1.145 | **1.576** | 1 | 1,49×1,54×1,50 | 4 (512²) |
| LavaHole | 2 | 2 | 3 | 726 | **996** | 1 | 2,46×0,51×2,54 | 8 |
| Grass (mata) | 2 | 1 | 1 | 1.009 | **1.280** | 1 | 1,55×0,98×1,54 | 3 (256²) |
| Lawn (césped) | 3 | 2 | 4 | 563 | **431** | 1 | 1,72×0,95×1,63 | 6 |
| FlowerHyrule | 2 | 2 | 1 | 620 | **782** | 1 | 3,18×1,12×1,64 | 6 |
| TreeHebra (árbol) | 1 | 1 | 1 | 579 | **850** | 1 | 2,98×4,32×3,09 | 4 (512²) |
| CrackMove (grieta) | 3 | 3 | 21 | 3.428 | **6.272** | 1 | 16,6×62,5×16,6 | 1 |
| **Octorok** (enemigo) | 2 | 1 | **21** | 1.076 | **1.818** | 1 | 0,82×1,10×0,82 | 5 (512²) |
| **Player (Link)** | 17 | 14 | **67** | 7.246 | **11.461** (≈9.000 sin las variantes de cara/sombrero de Zelda) | 1 | 1,21×**1,34**×1,11 | 123 (9,2 MB) |
| **Zelda** (8 trajes en 1 archivo) | 43 | 20 | **118** | 29.844 | 47.120 en total; por traje **≈5.000‑8.500** (ZC00 = 8.542) | 1 | 1,48×1,21×1,10 | externas |
| HyruleHouse00 (casa) | 12 | 12 | 1 | 16.674 | **21.233** | 1 | 13,9×4,2×10,5 | 37 (11,8 MB) |
| BdL_Dungeon001 (fachada) | 2 | 2 | 1 | 2.255 | **3.354** | 1 | 10,5×6,1×5,9 | 6×1024² |
| L_Dungeon001_001 (sala pequeña) | 10 | 10 | 1 | 2.149 | **2.570** | 1 | **18,5×12,8×18,2** | compartidas |
| L_Dungeon001_002 | 14 | 14 | 1 | 2.933 | **3.433** | 1 | 27,4×13,6×18,0 | 3 (≤256²) |
| L_Dungeon001_007 (sala grande) | 39 | 25 | 1 | 18.062 | **18.762** | 1 | 60×51×92 | 3×1024² |
| L_Dungeon001_010 (sala más grande) | 25 | 25 | 1 | 31.926 | **40.866** | 1 | 49×21×101 | 10 (8,6 MB) |
| Field_HyrulePlains_005 (trozo de campo) | 16 | 16 | 1 | 19.452 | **28.893** | 1 | 30×6×95 | 11 (7,3 MB) |

- **Ningún modelo tiene LODs**: `meshCount = 1` en los 194 shapes medidos.
- Las salas no tienen esqueleto (1 hueso). Hay 1 shape por material (las mallas ya vienen agrupadas por material).
- Las animaciones van en el mismo BFRES:
  - Link: 356 FSKA, 7 FMAA, 11 FSCN/FCAM
  - Zelda: 578 FSKA
  - Octorok: 35 FSKA
- Skinning: hasta 4 influencias en cuerpos y pelo, 1‑2 en caras y accesorios (`skin` 1‑4) [M].
- Tamaño de sala de mazmorra en `level/*.elo` y `map/` [M]: 644 salas BFRES (2,95 GB en total, mediana 1,28 MB).
  - L_Dungeon001 tiene 22 salas, entre 71 KB y 9,8 MB.

### 3.2 Formatos de vértice [M]
- Posición `float32×3` (en una shape de Grass, `float16×4`).
- Normal / tangente / binormal en `snorm 10_10_10_2`; en algunos props y en Octorok, tangente y binormal en `snorm8×4`.
- UV en `float16×2`, `unorm16×2` o `snorm16×2`, y hasta `unorm8×2` en UVs secundarias.
- Color `unorm8×4`. Índices de hueso `uint8×{1,2,4}`, pesos `unorm8×{2,4}` o `unorm16×4`.
- Stride: **20‑40 bytes por vértice** (sala típica 28 B; personaje 29‑40 B).

### 3.3 Escala y rejilla [M + D]
- Los bloques de eco miden 1,5 m de lado (BoxWooden 1,57; BlockIce 1,50; BlockWater 1,65 con su borde; SwitchFoot 1,50). Link mide **1,34 m** de alto en su caja.
- Los `.bfgrid` ("Grid", versión 2) llevan un float **0,75** = **tamaño de celda** (medio bloque). Dimensiones medidas:
  - L_Dungeon001_001: 28×19×29
  - L_Dungeon001_007: 70×60×100
  - BdChurch: 8×10×8

  Funcionan como rejilla de colocación o navegación para los ecos [D].
- Una sala "de pantalla" de mazmorra mide ≈ 18 × 18 m ≈ **12 × 12 bloques de 1,5 m**.

---

## 4. Iluminación, clima, cielo, reflejos

### 4.1 LightAnimations.bfres [M + D]
- 164 escenas de luz (FSCN) y 636 FLIT. Cada escena tiene **1 luz `directional` + 1 `hemiSphere`** (ambiente cielo/suelo).
- En exteriores hay 14 luces: 7 climas × (dir + hemi): Sunny, Cloudy, Rainy, Thunder, Snowy, Blizzard y SandStorm.
- Hay variantes `_Top` (cenital) y `_Side` (lateral) por mazmorra.
- Valores medidos (orden interpretado [D]: dirección xyz, intensidad, —, color rgb / hemi: up, color cielo, color suelo):

| escena | direccional | hemisferio |
|---|---|---|
| LDungeon001_Top | dir (0, −1, 0,3), int 0,6, color (1, 1, 0,75) | cielo 0,5 / suelo 0,4 (gris) |
| LDungeon001_Side | dir (0, −0,7, −0,7), int 1,5 | igual |
| LDungeon002_Top (agua) | int 0,5, color (0,49, 0,64, 0,92) azulado | cielo (0,19, 0,22, 0,25) / suelo (0,12, 0,24, 0,35) |
| LDungeon003_Top | color (0,9, 0,63, 0,44) cálido | cálido |
| HyruleHouse001_Stove | int 0,6, color (0,91, 0,54, 0,29) naranja | — |
| FieldCommon | dir (−0,45, −0,83, 0,33), int 3,0, color (1, 1, 0,91) | cielo (0,14, 0,07, 0,15) / suelo (0,28, 0,25, 0,37) |

- En vista cenital la luz principal es **casi vertical, inclinada ~17° hacia +Z**, y el **color de la luz define el tono de la mazmorra** (cálido, frío, verdoso).

### 4.2 Niebla y clima [M]
- `FogAnimations.bfres`: 16 FSCN y 60 FFOG.
- `Weather.json`: 182 entradas, cada una con luz + niebla de profundidad + niebla de altura + probabilidades de clima + temperatura por franja horaria.
  - 130 sin niebla de profundidad y 136 con `FogOff` de altura.
  - Solo 4 entradas tienen clima aleatorio (nieve, ventisca, tormenta de arena).
  - Las mazmorras prácticamente no usan niebla.

### 4.3 Sombras [M]
- `ShadowMapSettings` define 11 perfiles con `mAabb` (Min/Max por eje) y `mDintance` (Begin/End).
  - `Default`: ±15 m en X/Y, −20/+10 en Z, distancia 1000‑1500, que en la práctica no tiene límite.
  - `Field`: 50‑70 m. Hay overrides por nivel (12) y por región (2), por ejemplo `HighCeiling` +45 Y para jefes.
- Lectura [D]: **un único mapa de sombra ortográfico encajado en una caja de unos 30 m alrededor del jugador o la sala**, sin cascadas. Con cámara cenital fija no se necesitan.

### 4.4 Cielo y cubemaps [M]
- `SkySphere.json`: interiores y mazmorras **sin cielo**. `mCubeMapCaptureSkySphereName` indica que la esfera de cielo se usa también para capturar los cubemaps.
- `cubemap/`: 70 carpetas por zona, con cubemaps nombrados por hash (1‑5 por zona), más `global/` (≈75 por nivel o región, p. ej. `LD001`, `LD004_Lava`, `SDungeonIce`).
  - **Todos de 64² BC1 sRGB, LDR, 7 mips, 37 KB.** No usan RGBM ni HDR.
  - Son reflexiones especulares "de ambiente", de bajo coste y suficientes para materiales casi mates.

### 4.5 Instancing (InstancedModelList, 28 filas) [M]
- Árboles: TreePlains01‑03, TreeHyrule, TreeRiver, TreeAncient, TreeForest, TreeJungle03‑05 (ShapeVisibilityFlag 3).
- Céspedes: Lawn, LawnVolcano, LawnSea, LawnWater, LawnDesert, LawnFlowerRiver, LawnTall, LawnLow... (flag 1).
- Estos se dibujan **instanciados**, con culling en GPU (§1.5).

---

## 5. Efectos (PTCL "VFXB" v0x16)
- `Bg.ptcl`, `Enemy.ptcl` y `Player.ptcl` (37.376 B cada uno, contenido distinto) solo contienen **1 emitter set "dummyBG" con 1 emisor "dummy"** y 2 BNSH [M]. Su estructura de secciones es `ESTA → ESET → EMTR → GRTF (texturas) → PRMA / G3PR (primitivas) → GRSN / GRSC (shaders)`.
- **Todos los efectos reales están en `Common.ptcl` (269.136.648 bytes)**. No lo traje: la herramienta solo copia archivos enteros y no permite leer solo la cabecera.
- Lo que se sabe sin traerlo [M, por nombres en `tailor/*.drsb`, el sistema de reacciones de cada actor]: los efectos se disparan por **acciones de interacción elemental**, por ejemplo:
  - `ac_Ignition`, `ac_OnFire`, `ac_BurnBreak`
  - `ac_Extinguishing_water`, `ac_Extinguishing_wind` (efectos `Fire_WaterVanish_00`, `Fire_WindVanish_00`)
  - `ac_Frozen`, `ac_FrozenInHotWater`, `ac_IceMelt`, `ac_IceBreak`, `ac_Electric`
  - `ac_BulletWaterElectrice` (electricidad en agua)
  - `ac_EnterWater` / `Lava` / `Quicksand` / `HotSpring`, `ac_InBlockWater`
  - `Land_M_{Grass,Earth,Sand,Snow,Water,Desert}`, `Object_Move_{Grass,Sand,Snow,Desert}`
  - `HitBurn` / `HitIce` / `HitElectric`, con sus sonidos `SE_OBJ_GRASS_FIRE_LOOP`, `SE_OBJ_ICE_BLOCK_MELT`...
- Es una **tabla actor × reacción → (efecto, sonido)** separada del código [D].

---

## 6. Conclusiones aplicables a Magic Symbols (Godot 4.7)

### 6.1 Materiales con estado por casilla, resueltos por shader
- EoW no tiene un shader de suelo "con estados" en tiempo de ejecución. Lo que tiene:
  - capas mezcladas por vertex color (`L2/L3 …mVC`) y UV en world position (`WP`)
  - una variante `Burn` con máscara
  - tiras "joint" con alfa para las transiciones entre suelos
- Propuesta para Godot, por qué y qué hacer:
  1. **Textura de datos de estado por sala**. Por qué: el estado cambia en juego y no puede ir en el vertex color, que es estático. Qué hacer:
     - Una `Image` RGBA8 de N×M píxeles, 1 píxel por casilla: R = mojado, G = quemado, B = helado, A = ceniza (0‑255).
     - Se sube como `ImageTexture` y se actualiza con `update()` solo cuando cambia algo (son KB, no MB).
     - En el shader del suelo (`shader_type spatial`): `world_pos.xz / tamaño_casilla` → UV del estado. Leer con filtro lineal para bordes suaves, o con `texelFetch` + ruido para bordes "pintados".
  2. **Cada estado como modificador del albedo y la rugosidad, no como textura nueva** (igual que `albedo_color/mask0` del Burn):
     - mojado: oscurecer el albedo un 30‑40 % y bajar la rugosidad (un charco con `ROUGHNESS` bajo da el reflejo del probe)
     - quemado: multiplicar por un color carbón con una máscara de ruido
     - helado: mezclar hacia blanco azulado, añadir fresnel y bajar la rugosidad
     - ceniza: gris desaturado con ruido de grano

     Una sola textura de ruido tileable compartida (BC4) basta para romper los bordes.
  3. Las **transiciones entre casillas** se hacen en el shader con el ruido. Las tiras alfa "joint" del juego son la alternativa artística si se necesita más control.
  4. Un solo material de suelo con `uniform sampler2D estado_casillas` y `instance uniform` para la sala evita variantes. EoW usa un shader por receta, pero en Godot mantener una sola receta de suelo es más simple.

### 6.2 Look "diorama/juguete"
- **Tilt‑shift**: Godot no lo trae. Se hace con un `CompositorEffect` (compute) o con un quad de pantalla completa con `hint_screen_texture` + `hint_depth_texture`:
  - desenfoque separable H/V fuera de una banda de pantalla definida por centro + normal + rango + gamma, como `PFXTiltShiftParam`
  - mezclado opcionalmente con el DOF por profundidad de `CameraAttributesPractical`

  Hay que exponer el centro y el ancho como parámetros por escena, igual que hacen los presets `TiltShift` / `LowDOF` / `DOFoff`.
- **SSAO** del `Environment` en calidad media o baja, que EoW escala con variantes de 2/3/4 muestras. Hace que las piezas "se apoyen" en el suelo.
- **Luz**: 1 `DirectionalLight3D` casi cenital (≈15‑20° de inclinación), con un color que dé el tono de cada zona y energía de 0,6‑1,5. Ambiente hemisférico con `Environment.ambient_light_source = Sky` y un cielo procedural o `ShaderMaterial` de cielo con 2 colores (cielo y suelo), o bien color plano (≈0,4‑0,5 gris en mazmorras).
- **Albedos de bajo contraste** sin luz horneada: el contraste lo ponen la luz, el AO y el tono.
- Bloom suave (`glow`), tonemap filmic/ACES, viñeta ligera y FXAA o TAA. Nada de cromática por defecto (en EoW es un modo opcional de efectos).
- Personajes: el "plástico" de EoW sale de **fresnel de color + sphere map** y no de PBR realista. En Godot: `rim`/`rim_tint` del StandardMaterial3D o un `ShaderMaterial` con fresnel de color, rugosidad media‑alta y metalness 0.
- **Silueta a través de paredes** (`pfx_silhouette`): segunda pasada del personaje con `depth_test_disabled` y `render_priority`, o un material `next_pass` que pinte un color plano donde está tapado.

### 6.3 Agua y lava estilizadas
- **Agua** (las pistas salen de los parámetros de M_Water):
  - opacidad y color por profundidad: diferencia entre la profundidad de escena (`hint_depth_texture`) y la del fragmento, con un mínimo y un máximo
  - espuma de orilla donde esa diferencia es casi 0
  - cáusticas proyectadas en world position
  - 2‑3 normales a distinta escala desplazándose
  - refracción leve con `hint_screen_texture`
  - reflejo del probe de la sala

  Para agua por casilla, conviene una malla **modular** (cara, arista, esquina) que se active según los vecinos, como BlockWater, o un shader que lea la textura de estado (canal "profundidad/agua").
- **Lava**: emisivo alto (`EMISSION` × energía > 1 para el glow), flowmap de 2 canales (RG8, puede ir sin comprimir y sin mips como en el juego), una capa de "roca" fría encima con su propio desplazamiento y vértices ondulando. Suelo de lava con grietas: emisivo de 2 canales (en Godot, RG en BC5/RGTC) más una máscara.

### 6.4 Fuego que ilumina la escena
- EoW tiene culling de luces en clusters/froxels activo en todos los materiales, igual que el **Forward+** de Godot.
- Usar `OmniLight3D` por fuego **sin sombras** (o con sombra solo en el fuego principal) y rango corto (3‑6 m).
- Animar la energía y el color con un ruido barato desde script o `AnimationPlayer`.
- El límite por cluster en Godot se controla en `rendering/limits/cluster_builder/max_clustered_elements`; decenas de luces pequeñas por sala no son problema en Forward+.
- En móvil/Compatibility hay límite de luces por objeto: conviene decidir pronto qué renderer usar.

### 6.5 Hierba
- El shader de vegetación de EoW solo hace viento: dos pesos en el vertex color (R balanceo, G puntas) + dirección + velocidad. La hierba que reacciona (cortar, quemar) es un actor aparte.
- En Godot:
  - `MultiMeshInstance3D` por sala/chunk; Godot hace culling por AABB del MultiMesh entero, así que conviene trocearlo por sala o por bloques de 8×8 casillas.
  - Shader con viento por `COLOR.r/g`.
  - Para "apartarse", un `uniform vec3 jugador_pos` (o un array pequeño de posiciones) y desplazamiento radial en `vertex()`.
  - Para estados (quemada, helada), leer la **misma textura de estado por casilla** en el shader de hierba: color carbón, encoger y ocultar la instancia.
- Presupuesto medido: mata de 1.280 tris, césped de 431. Para muchas instancias conviene bajar a 50‑200 tris por mata (tarjetas cruzadas).

### 6.6 Presupuestos razonables (de EoW a chibi Meshy en Godot)
| elemento | EoW (medido) | objetivo Magic Symbols |
|---|---|---|
| protagonista | 9‑11k tris, 67 huesos, texturas 256² (alb BC1, nml BC5, smt BC4) | Meshy suele dar 20‑100k: **retopo/decimar a 5‑10k**, ≤ 70 huesos, 1‑2 materiales, atlas de 1024² (o 512²) |
| enemigo pequeño | 1,8k tris, 21 huesos, 512² | 1,5‑4k tris, ≤ 30 huesos, 512² |
| prop de casilla (1,5 m) | 60‑1.600 tris, 256²‑512² | 300‑1.500 tris, 256²‑512² |
| hierba / césped | 430‑1.300 tris | 50‑300 tris por mata, instanciada |
| árbol | 850 tris, 512² | 800‑2.000 tris |
| sala de pantalla (~18×18 m) | 2,5k‑41k tris, texturas compartidas 1024² por material | 10‑40k tris por sala, sets 1024² compartidos entre salas |
| LOD | ninguno | no hacen falta con cámara fija ortográfica; sí `visibility_range` para detalles |

- La cámara está fija y lejos, por eso los personajes de EoW usan texturas de 256². Más resolución no se ve en pantalla.

### 6.7 Compresión de texturas en Godot
- Importar en **VRAM Compressed**. En escritorio Godot usa S3TC/BPTC: BC1 o BC3 por defecto, y BC7 si se activa `compress/high_quality`. EoW usa casi solo BC1, que es suficiente para albedos pintados de bajo contraste.
- Normales con `compress/normal_map = Enable`, para que Godot las comprima a 2 canales (RGTC/BC5), igual que EoW.
- **Empaquetar ORM** (oclusión, rugosidad, metalness) en una sola textura, como el `RGBMap` de EoW, y poner metalness a 0 en el decorado. Ojo: Godot espera R = AO, G = roughness, B = metallic, y EoW usa otro orden (smoothness invertida).
- Para máscaras de 1 canal (ruido, flowmaps), usar texturas de 1‑2 canales; Godot puede comprimirlas como RGTC.
- Si se exporta a móvil o Switch, Godot genera ETC2/ASTC.
- Cálculo de VRAM: un set alb + nml + orm de 1024² ≈ 0,7 + 1,4 + 0,7 MB ≈ **2,8 MB** con mips (es la cifra medida en EoW). Una sala con 15‑20 sets ≈ 40‑60 MB.

### 6.8 Fade por dither de lo que tapa la cámara
- EoW lleva `DitherTransparency` en todos los materiales, con una Bayer 4×4 y un shader específico para techos.
- En Godot:
  - En `StandardMaterial3D` existe `distance_fade_mode = Pixel Dither / Object Dither`, que sirve para el fade por cercanía a la cámara.
  - Para "tapa al jugador", un `ShaderMaterial` con `uniform float opacidad` y un descarte por umbral Bayer 4×4 en `fragment()` (comparar con `FRAGCOORD.xy % 4`).
  - Desde script: raycast/área entre cámara y jugador → interpolar `opacidad`.

  Se queda en el pipeline opaco (sin ordenación, con sombras correctas) y es lo más barato.
- Se puede reutilizar el mismo umbral para que los objetos aparezcan y desaparezcan (similar a `Fn_EffectPaste_Dissolve*`, pero con ruido Voronoi en vez de Bayer).

### 6.9 Reflejos por sala
- EoW usa cubemaps de **64², LDR, uno por sala/zona** y mezcla entre sala y global.
- En Godot: un `ReflectionProbe` por sala, `update_mode = Once`, resolución baja (`rendering/reflections/reflection_atlas/reflection_size` 128‑256) y `box_projection` en salas cerradas.
- No hace falta SDFGI ni VoxelGI para este estilo. Si se quiere rebote de color, `LightmapGI` estático por sala o simplemente el ambiente hemisférico.

### 6.10 Sombras
- Un solo mapa direccional ajustado a la sala: `DirectionalLight3D` con `directional_shadow_mode = Orthogonal` (sin cascadas), `max_distance` ≈ 30‑40 m y `shadow_blur` moderado.
- Con cámara ortográfica fija, las cascadas no aportan.

### 6.11 VFX por elemento
- Lo que conviene copiar de EoW no es un efecto concreto sino **la tabla de reacciones**: (actor/superficie × elemento) → (efecto, sonido, cambio de estado).
  - Ejemplos: `Ignition`, `OnFire`, `Extinguishing_water/wind`, `Frozen`, `IceMelt`, `Electric`, `Electric en agua`, `Land/Move` por superficie.
  - En Magic Symbols puede ser un `Resource` de datos que también escriba en la **textura de estado por casilla** (mojado, quemado, helado, ceniza). Así el VFX (`GPUParticles3D`) y el shader del suelo comparten la misma fuente de verdad.

---

## 7. Pendiente / no medido
- Contenido de `Common.ptcl` (nº de emisores y texturas de partícula): no se trajo (269 MB).
- Valores numéricos de los parámetros de material (bloques `Material` de cada FMAT) y del tilt‑shift por escena: los nombres están medidos, los valores no. `EnvironmentalEffect.kobin` usa claves con hash.
- Semántica exacta del contenido de `.bfgrid` y `.cide` (cabecera medida, cuerpo sin decodificar).
- Número de luces puntuales por sala (en `level/*.elo` solo aparecen las etiquetas `TagTailorPlayer_Lamp_Wall_*`).
