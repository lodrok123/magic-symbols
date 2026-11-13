# De dónde sale cada sonido

## Sintetizados — `tools/gen_sfx.py`

Todo lo elemental y lo mágico. Se generan con código, igual que los
sprites de `gen_fx.py`, y por el mismo motivo: **no existe una grabación
de "hielo cristalizando" ni de "el tiempo yendo hacia atrás"**, así que
da igual buscarla. Además salen de la misma familia — el crepitar de una
bola de fuego y el de un árbol ardiendo son el mismo generador— y
cambiar cómo suena el hielo es tocar un número y relanzar.

```
elem_fuego  elem_agua  elem_hielo  elem_rayo
elem_viento elem_tierra elem_tiempo
prender  congelar  chispa  derrumbe  rodar  arco  pira
dano  muerte
trazo  sello_ok  sello_no
```

`trazo`, `sello_ok` y `sello_no` están aquí a propósito aunque haya
packs de interfaz: el trazo es tiza (ningún pack la trae) y los dos
avisos son **música**, no foley — dos notas que suben y una que baja,
para que se lean como "sí" y "no" sin explicárselo a nadie.

## Grabados — Kenney, CC0 (dominio público)

El foley. Aquí la síntesis pierde siempre: el oído conoce estos sonidos
de memoria y detecta el fraude al instante. Seis pisadas reales distintas
valen más que cualquier algoritmo.

| archivo del juego | origen |
|---|---|
| `paso_0..5.ogg` | RPG Audio · `footstep00..05` |
| `puerta_abre_0..1.ogg` | RPG Audio · `doorOpen_1`, `doorOpen_2` |
| `puerta_cierra_0..1.ogg` | RPG Audio · `doorClose_1`, `doorClose_3` |
| `libro_abre.ogg` | RPG Audio · `bookOpen` |
| `libro_cierra.ogg` | RPG Audio · `bookClose` |
| `pagina_0..2.ogg` | RPG Audio · `bookFlip1..3` |
| `clavar.ogg` | RPG Audio · `chop` |
| `creak.ogg` | RPG Audio · `creak1` |

Paquetes: **Kenney RPG Audio** y **Kenney UI Audio**, ambos CC0 — uso
libre, también comercial, sin atribución obligatoria. Los .zip originales
están en `Assets/`.

**Grabados el 2/11 (tarea R; copiados desde `audio/fuentes/`)**, todos CC0. Cada entrada sustituida del catálogo guarda además el sintetizado de antes (`f_sint`;
con `Sfx.GRABADOS = false` suena ése).

| archivo del juego | original | autor · pack |
|---|---|---|
| `kenney_monedas_0..1.ogg` | `handleCoins`, `handleCoins2` | Kenney · RPG Audio |
| `kenney_recoger_0..3.ogg` | `cloth1..4` | Kenney · RPG Audio |
| `kenney_equipar_0..1.ogg` | `beltHandle1..2` | Kenney · RPG Audio |
| `kenney_bolsa_0.ogg`, `kenney_bolsa_1.ogg` | `handleSmallLeather2`, `cloth3` | Kenney · RPG Audio |
| `kenney_bolsa_tela.ogg` | `cloth2` | Kenney · RPG Audio |
| `kenney_comprar_0.ogg`, `kenney_comprar_1.ogg` | `handleCoins` (RPG Audio), `confirmation_001` (Interface Sounds) | Kenney |
| `kenney_clic_0..4.ogg` | `click_001..005` | Kenney · Interface Sounds |
| `kenney_error_0..3.ogg` | `error_001`, `error_002`, `error_004`, `error_005` | Kenney · Interface Sounds |
| `kenney_cofre_tapa_0..2.ogg` | `impactWood_medium_000..002` | Kenney · Impact Sounds |
| `kenney_golpe_piedra_0..2.ogg` | `impactMining_000..002` | Kenney · Impact Sounds |
| `kenney_golpe_carne_0..2.ogg` | `impactPunch_medium_000..002` | Kenney · Impact Sounds |
| `kenney_clavar_0.ogg`, `kenney_clavar_1.ogg` | `impactPunch_heavy_000`, `impactWood_heavy_000` | Kenney · Impact Sounds |
| `kenney_paso_golem_0..3.ogg` | `footstep_concrete_000..003` (tono ×0,6 en el juego) | Kenney · Impact Sounds |
| `kenney_paso_goblin_0..3.ogg` | `footstep_grass_000..002`, `footstep_wood_000` (tono ×1,2 en el juego) | Kenney · Impact Sounds |
| `oga_gato_maullido_0.wav`, `oga_gato_maullido_1.wav`, `oga_gato_maullido_2.ogg` | `cat_mewpurr.wav`, `cat_softmew.wav`, `Meow.ogg` | «cat purr meow» y «meow» · https://opengameart.org/content/cat-purr-meow · https://opengameart.org/content/meow |
| `oga_gato_ronroneo_loop.wav` | `cat_purractive_loop.wav` | «cat purr meow» · https://opengameart.org/content/cat-purr-meow |
| `fs_pluma_pergamino.mp3` | `pluma_pergamino_brktkrgll.mp3` (Freesound 856167, previsualización HQ) | brktkrgll · https://freesound.org/people/brktkrgll/sounds/856167/ |
| `fs_paginas_bucle.mp3` | `paginas_P_Chester.mp3` (Freesound 465260, previsualización HQ) | P_Chester · https://freesound.org/people/P_Chester/sounds/465260/ |

## Sintetizados — `tools/gen_sonidos_ambiente.py`

Ambiente y criaturas, también por código (sin muestras: no hay licencias
que atribuir). Semilla fija: relanzar da los mismos archivos.

```
fuego_loop  agua_loop  agua_cae_loop  conversacion_murmullo_loop      (bucles; agua_cae_loop = el chorro de la tinaja, 15/10)
goblin_grito_0..2  gato_maullido_0..1  conversacion_voz_0..2
paso_hierba_0..3  paso_roca_0..3
```

Los `_loop` llevan la costura ya cruzada, pero Godot necesita que el
`.ogg` esté marcado como bucle al importarlo (`Loop` en la pestaña Import).
`paso_hierba` y `paso_roca` son por superficie; `paso_0..5` (Kenney) quedan
como paso genérico.

**Pisadas suaves (27/10):** `paso_suave_hierba_0..5`, `paso_suave_tierra_0..5` y
`paso_suave_roca_0..5` (.wav) las genera `tools/gen_pasos_suaves.py`, también
sintetizadas y sin licencia. Son las que suenan ahora al andar (`Sfx3D.CATALOGO`);
las de antes siguen aquí para comparar.

## Cómo cambiar uno

Copiar el archivo nuevo en `audio/` y tocar su línea en `CATALOGO`
(`sfx.gd`). Nada más: ningún sitio que llame a `Sfx.play()` sabe qué
archivo hay detrás ni en qué formato.

## Fases del conjuro (18/10, Pipeline)

`fuego|agua|hielo|rayo|viento|tierra|tiempo` + `_carga` y `x_mano_impacto`, `alto_impacto`, `abajo_impacto`: **sintetizados** con
`audio/gen_sfx_hechizos.py` (numpy, sin dependencias; semilla fija, así que se regeneran idénticos). Sin licencia externa.

## Grabados de OpenGameArt, CC0 (27/10)

Todos con licencia **CC0** (dominio público: sin obligación de citar; se cita igual por orden). Se descargaron
el 27/10/2026 y se renombraron con el prefijo `oga_`. Los usan `Sfx.CATALOGO` y `Sfx3D` (comprobado en
`herramientas/prueba_sonidos_grabados.gd`).

| archivo en audio/ | original | autor · página |
|---|---|---|
| `oga_agua_corriendo_loop.ogg` | `water_flowing.ogg` de `sfx_loops.zip` | rubberduck · https://opengameart.org/content/30-cc0-sfx-loops |
| `oga_paso_hojas_0..1.ogg`, `oga_paso_barro_0.ogg`, `oga_paso_grava_0.ogg`, `oga_paso_piedra_0.ogg`, `oga_paso_madera_0..2.ogg` | `leaves01..02`, `mud02`, `gravel`, `stone01`, `wood01..03` (.ogg) | kdd · https://opengameart.org/content/different-steps-on-wood-stone-leaves-gravel-and-mud |
| `oga_fuego_crepita_loop.wav` | `fire-1.wav` | AntumDeluge · https://opengameart.org/content/fire-crackling |
| `oga_conjuro_arcano_0..6.ogg` | `magical_1..7.ogg` | JaggedStone · https://opengameart.org/content/magic-spell-sfx |
| `oga_relampago_0.wav`, `oga_relampago_1.wav`, `oga_descarga_chasquidos.wav` | `hit.wav`, `groundhit.wav`, `snaploop.wav` | faxcorp · https://opengameart.org/node/150369 (Electricity Game Sound Pack) |
| `oga_congelar_0.wav`, `oga_congelar_1.wav` | `coldsnap.wav`, `ice.wav` de `icespells.zip` | bart · https://opengameart.org/content/ice-spells |

Los sintetizados a los que sustituyen (`agua_loop`, `fuego_loop`, `elem_hielo`, `elem_rayo`, `congelar`, `arde_bucle`
y las pisadas `paso_*`) siguen en esta carpeta por si se quiere volver atrás: basta con cambiar el nombre en el catálogo.

## Lote GDC 2026 de Sonniss — `audio/sn_*.ogg` (10/11) · NO están en el repositorio

Foley profesional del muestrario gratuito «GDC 2026 Game Audio Bundle» (https://gdc.sonniss.com/, 347 pistas de 17 librerías, 8 GB).
**Licencia** (https://sonniss.com/gdc-bundle-license/): uso libre y comercial en juegos, sin atribución, proyectos ilimitados; **prohibido
distribuir los sonidos como sonidos** (ni editados) y prohibido entrenar IA con ellos. El juego terminado sí puede llevarlos.
Como este repositorio es público, los `audio/sn_*` van en `.gitignore`: cada máquina los genera. Sin ellos el juego suena con lo de antes
(`Sfx.archivos_de`: la clave «f_sn» solo cuenta si el archivo existe; `Sfx.SONNISS = false` o la fila S:SONNISS del panel F3 los apaga para comparar).

**Cómo regenerarlos:** bajar los cinco zip de https://gdc.sonniss.com/ y extraerlos en una carpeta FUERA del proyecto (hay nombres de más de 260
caracteres: extraer con rutas largas). En esta máquina están en `C:\Users\paranda\Documents\magic-symbols-sonidos-fuente\sonniss_gdc2026`. Después
`python audio/procesa_sonniss.py <esa carpeta> audio` (pide numpy, scipy y soundfile) y `godot --headless --import --path .`.
El script recorta la toma, pasa a mono 44,1 kHz, funde, iguala el pico a −3 dB y, en las voces de goblin, sube el tono (de orco a goblin).

| archivo en audio/ | entrada del catálogo | pista original | librería |
|---|---|---|---|
| `sn_golpe_carne_0.ogg` | Sfx3D `golpe_carne` | `FGHTImpt_4 x Punch, Body 02_344 Audio_Cinematic Fight Vol 1.wav` | 344 Audio - Cinematic Fight Vol. 1 |
| `sn_golpe_carne_1.ogg` | Sfx3D `golpe_carne` | `FGHTImpt_4 x Punch, Body 02_344 Audio_Cinematic Fight Vol 1.wav` | 344 Audio - Cinematic Fight Vol. 1 |
| `sn_golpe_carne_2.ogg` | Sfx3D `golpe_carne` | `FGHTImpt_4 x Punch, Body 02_344 Audio_Cinematic Fight Vol 1.wav` | 344 Audio - Cinematic Fight Vol. 1 |
| `sn_golpe_carne_3.ogg` | Sfx3D `golpe_carne` | `FGHTImpt_4 x Punch, Body 02_344 Audio_Cinematic Fight Vol 1.wav` | 344 Audio - Cinematic Fight Vol. 1 |
| `sn_dano_jugadora_0.ogg` | Sfx `dano_jugadora` | `VOXReac_British Detective Pain Vocal Female Dying High Grunt Breath_ESM_AAAGCBFD.wav` | Epic Stock Media - AAA Game Character British Female Detective |
| `sn_goblin_grito_0.ogg` | Sfx3D `goblin_grito` | `HMNBrth_Construction Kit Male Screeching Breath Inhale Weak Squeal 05_ESM_HC4.wav` | Epic Stock Media - Humanoid Creatures Vol 4 - Monstrous and Undead Creature Vocalization Sound Sets |
| `sn_goblin_grito_1.ogg` | Sfx3D `goblin_grito` | `CREAHmn_Designed Orc Male Attack Long Heavy Hit Charged Up 03_ESM_HC4.wav` | Epic Stock Media - Humanoid Creatures Vol 4 - Monstrous and Undead Creature Vocalization Sound Sets |
| `sn_goblin_grito_2.ogg` | Sfx3D `goblin_grito` | `CREAHmn_Violent Humanoid Creature Exhale Short 4_SNDBTS_VB-SE.wav` | SoundBits - Vox Bestiae - Source Elements |
| `sn_goblin_muere_0.ogg` | Sfx3D `goblin_muere` | `VOXReac_Construction Kit Male Flutter Death Vocal Stuttered Long 05_ESM_HC4.wav` | Epic Stock Media - Humanoid Creatures Vol 4 - Monstrous and Undead Creature Vocalization Sound Sets |
| `sn_hielo_quiebra_0.ogg` | Sfx `hielo_quiebra` | `ice, crack, ice block snapping-001.wav` | Alexander Kopeikin - 100 kHz Designed Ice |
| `sn_hielo_quiebra_1.ogg` | Sfx `hielo_quiebra` | `ice, surface cracking, fissure, fast, hard-003.wav` | Alexander Kopeikin - 100 kHz Designed Ice |
| `sn_hielo_quiebra_2.ogg` | Sfx `hielo_quiebra` | `ice, block of ice crushed, heavy-015.wav` | Alexander Kopeikin - 100 kHz Designed Ice |
| `sn_derrumbe_0.ogg` | Sfx `derrumbe` | `Woosh Debris.wav` | Cinematic Sound Design - Colossal Impacts |
| `sn_explosion_0.ogg` | Sfx `explosion` | `EXPLDsgn_Explosion Small Blast Enemy Death Crunchy Boom Cartoon Noisy Crash Impact Delay 03_ESM_AG.wav` | Epic Stock Media - Anime Game |
| `sn_hundido_burbujas_0.ogg` | Sfx `hundido_burbujas` | `WATRImpt_Impact Water Deep Submerge Bubble Drown Ship Hit 05_ESM_EMWI.wav` | Epic Stock Media - Elemental Mutation Whooshes and Impacts |
| `sn_limo_golpe_0.ogg` | Sfx3D `limo_golpe` | `WOODImpt_Hit Blood Spill Splat Wood Impact Light Hit Squelch Small Thump 03_ESM_TDG.wav` | Epic Stock Media - Tower Defense Game |
| `sn_limo_muere_0.ogg` | Sfx3D `limo_muere` | `GORESplt_Gore Designed Transient Heavy Impact Smash 01_ESM_HALG.wav` | Epic Stock Media - Halloween Game - Haunted House and Horror Audio Scare Kit |
| `sn_voltereta_0.ogg` | Sfx `voltereta` | `FOLYClth_ClothMovement24_InMotionAudio_FoleyT-Shirt.wav` | InMotionAudio - Foley T-Shirt |
| `sn_voltereta_1.ogg` | Sfx `voltereta` | `FOLYClth_ClothMovement24_InMotionAudio_FoleyT-Shirt.wav` | InMotionAudio - Foley T-Shirt |
| `sn_voltereta_2.ogg` | Sfx `voltereta` | `FOLYClth_ClothMovement29_InMotionAudio_FoleyT-Shirt.wav` | InMotionAudio - Foley T-Shirt |
| `sn_siseo_apagado_0.ogg` | Sfx `siseo_apagado` | `42 Campfire, Putting Out Fire, Water from Bottle, Variation, Close.wav` | Ivo Vicic - Campfire - Bonfire FX |
| `sn_chispazo_0.ogg` | Sfx `chispazo` | `ELECArc_ArcDesign15_InMotionAudio_Arc.wav` | InMotionAudio - Arc |
| `sn_rayo_carga_0.ogg` | Sfx `rayo_carga` | `ELECArc_ArcPowerUpDesign04_InMotionAudio_Arc.wav` | InMotionAudio - Arc |
| `sn_zumbido_electrico_0.ogg` | Sfx `zumbido_electrico` | `ELECBuzz_Buzz27_InMotionAudio_Arc.wav` | InMotionAudio - Arc |
| `sn_viento_0.ogg` | Sfx `viento` | `WINDDsgn_Wind, Rush, Whoosh, Long x5 01_344 Audio_Elemental Palette Designed Vol 1.wav` | 344 Audio - Elemental Palette Designed Vol. 1 |
| `sn_magma_0.ogg` | Sfx `magma` | `FIREWhsh_Whoosh Fire Deep Growl Monster Saturated Crisp 03_ESM_EMWI.wav` | Epic Stock Media - Elemental Mutation Whooshes and Impacts |
| `sn_salpicadura_0.ogg` | Sfx `salpicadura` | `WATRMisc_Water, Liquid Impact, Bubble, Sci Fi, Hit 04_344 Audio_Elemental Palette Designed Vol 1.wav` | 344 Audio - Elemental Palette Designed Vol. 1 |
| `sn_hielo_rompe_0.ogg` | Sfx `hielo_rompe` | `ICEBrk_Skill Freeze Whoosh Break Impact Layered Movement Shatter 03_ESM_TDG.wav` | Epic Stock Media - Tower Defense Game |
| `sn_escudo_roto_0.ogg` | Sfx `escudo_roto` | `GLASMvmt_Whoosh Glass Crystal Fragments Sharp Shards Dry 05_ESM_EMWI.wav` | Epic Stock Media - Elemental Mutation Whooshes and Impacts |
| `sn_escudo_golpe_0.ogg` | Sfx y Sfx3D `escudo_golpe` | `METLImpt_Metal Old File Impact Tap Against Tire Iron Metallic Hit 01_ESM_HDGM.wav` | Epic Stock Media - HD Game Materials |
| `sn_dano_0.ogg` | Sfx `dano` | `FGHTImpt_Combat Punch Impact Light Hit Delay Crunchy Vintage Quick Smack 05_ESM_AG.wav` | Epic Stock Media - Anime Game |
| `sn_no_puedes_0.ogg` | Sfx `no_puedes` | `Deny Muted.wav` | Cinematic Sound Design - UI Interaction Elements |
| `sn_moneda_0.ogg` | Sfx `moneda` | `Ting Coins.wav` | Cinematic Sound Design - UI Interaction Elements |
| `sn_moneda_1.ogg` | Sfx `moneda` | `Foley Coin Flip Single Fast.wav` | Cinematic Sound Design - Hybrid Game & UI Elements |
| `sn_logro_acierto_0.ogg` | Sfx `logro_acierto` | `Interface Plucks Happy.wav` | Cinematic Sound Design - User Interface |
| `sn_objetivo_cumplido_0.ogg` | Sfx `objetivo_cumplido` | `Game Entry Happy Short.wav` | Cinematic Sound Design - Hybrid Game & UI Elements |
| `sn_logro_brillo_0.ogg` | Sfx `logro_brillo` | `Button Arp Twinkle.wav` | Cinematic Sound Design - User Interface |
| `sn_cofre_revelado_0.ogg` | Sfx `cofre_revelado` | `GAMEMisc_Magic Creation 23_CB Sounddesign_APPlicable Sounds.wav` | CB_Sounddesign - Applicable Sounds - Organic UI and Building Games SFX |
| `sn_bolsa_0.ogg` | Sfx `bolsa` | `CLOTHFlp_Action Inventory Open Flip Cloth Canvas Bag Slide Light 02_ESM_FG2.wav` | Epic Stock Media - Fantasy Game 2 - Sound Kit for Enchanted Realms |
| `sn_aturdido_0.ogg` | Sfx `aturdido` | `Cartoon Confused Dizzy.wav` | Cinematic Sound Design - Cartoon Bloopers |
| `sn_reaccion_grande_0.ogg` | Sfx `reaccion_grande` | `Impact Cut Sweep.wav` | Cinematic Sound Design - Colossal Impacts |
| `sn_barrido_0.ogg` | Sfx `barrido` | `OBJMisc_ScratchCard_SurfaceWipe_04_InMotionAudio_ScratchCard.wav` | InMotionAudio - Scratch Card |
| `sn_recarga_lista_0.ogg` | Sfx `recarga_lista` | `MECHClik_USALightSwitch_On05_InMotionAudio_USAHotel.wav` | InMotionAudio - USA Hotel |
| `sn_muerte_0.ogg` | Sfx `muerte` | `Cartoon Transition Bass Down.wav` | Cinematic Sound Design - Cartoon & Animation Vol 2 |
| `sn_tiempo_tic_0.ogg` | Sfx `tiempo_tic` | `CLOCKTick_Crooked Antique Clock_344 Audio_Antique Clocks.wav` | 344 Audio - Antique Clocks |
| `sn_boton_clic_0.ogg` | Sfx `boton_clic` | `MECHLtch_Click Deep Mechanism Latch Button Nearfield Thunk 02_ESM_HDLM.wav` | Epic Stock Media - HD Lock And Mechanism Sound Design Kit |
| `sn_amb_bosque_0.ogg` | Sfx `amb_bosque` | `AMBSwmp_Meadow Pipits calling many Insects humming Wind blowing through Grass_JSE_HoN_Stereo.wav` | Just Sound Effects - Highlands of Norway |
| `sn_amb_grillos_0.ogg` | Sfx `amb_grillos` | `AMBSubn_Ambience, Forest Crickets, Birds, Connecticut 02_344 Audio_East Coast America.wav` | 344 Audio - East Coast America Vol. 1 |
| `sn_amb_cueva_0.ogg` | Sfx `amb_cueva` | `WINDInt_ChimneyWind05_InMotionAudio_ChimneyWind.wav` | InMotionAudio - Chimney Wind |
| `sn_hielo_flecha_0.ogg` | Sfx `hielo_flecha` | `DSGNStngr_Power Up Bright Positive Successful Light Saturation Crash Shimmer 05_ESM_AG.wav` | Epic Stock Media - Anime Game |
| `sn_sintetizar_0.ogg` | Sfx `sintetizar` | `MAGAngl_Magic Light Spell Enchantment Potion Effect Tonal Bright 03_ESM_FG2.wav` | Epic Stock Media - Fantasy Game 2 - Sound Kit for Enchanted Realms |
| `sn_flecha_clava_0.ogg` | Sfx `flecha_clava` | `Arrow Hit Rattle.wav` | Cinematic Sound Design - Cartoon Bloopers |
| `sn_aterrizar_0.ogg` | Sfx `aterrizar` | `FOLYClth_SinglePats04_InMotionAudio_FoleyT-Shirt.wav` | InMotionAudio - Foley T-Shirt |
| `sn_salto_0.ogg` | Sfx `salto` | `Woosh Sweep Slide Infographics Basic.wav` | Cinematic Sound Design - Ultra Transitions & Impacts |
| `sn_golem_rugido_0.ogg` | Sfx3D `golem_rugido` | `ANMLRept_Large Herbivore Roar 01_344 Audio_Dinosaurs Vol 2.wav` | 344 Audio - Dinosaurs Vol. 2 |
| `sn_jefe_rugido_0.ogg` | Sfx3D `jefe_rugido` | `ANMLRept_T Rex_344 Audio_Dinosaurs.wav` | 344 Audio - Dinosaurs Vol. 1 |
| `sn_limo_divide_0.ogg` | Sfx3D `limo_divide` | `Cartoon Bubbles Short.wav` | Cinematic Sound Design - Cartoon & Animation Vol 2 |
| `sn_trueno_0.ogg` | Sfx `trueno` | `THUN_Interior Thunder Rumble_JF_INT Storm_01.wav` | Jake Fielding - Interior Wind Rain and Storms |
| `sn_puzle_resuelto_0.ogg` | Sfx `puzle_resuelto` | `Accept Boing Crunch.wav` | Cinematic Sound Design - UI Interaction Elements |
| `sn_loberno_ladrido_0.ogg` | Sfx3D `loberno_ladrido` | `ANMLDog_Dog Barks, Multiple, Indoors, Perspective,_344 Audio_Dog Vocalisations_02.wav` | 344 Audio - Dog Vocalisations Vol. 1 |
| `sn_loberno_ladrido_1.ogg` | Sfx3D `loberno_ladrido` | `ANMLDog_Dog Barks, Multiple, Indoors, Perspective,_344 Audio_Dog Vocalisations_02.wav` | 344 Audio - Dog Vocalisations Vol. 1 |
| `sn_loberno_ladrido_2.ogg` | Sfx3D `loberno_ladrido` | `ANMLDog_Dog Barks, Multiple, Indoors, Perspective,_344 Audio_Dog Vocalisations_02.wav` | 344 Audio - Dog Vocalisations Vol. 1 |
| `sn_loberno_muere_0.ogg` | Sfx3D `loberno_muere` | `ANMLDog_Dog Shuffle, Grunt, Movement, Lying Down_344 Audio_Dog Vocalisations.wav` | 344 Audio - Dog Vocalisations Vol. 1 |
| `sn_impacto_suelo_0.ogg` | Sfx3D `impacto_suelo` | `SWSH_SWING IMPACTS Quick Heavy Weapon Swing To Thud Impact Var 01_DDUMAIS_MWP2.wav` | David Dumais Audio - Melee Weapons Sound Effects Pack 2 |
| `sn_impacto_suelo_1.ogg` | Sfx3D `impacto_suelo` | `SWSH_SWING IMPACTS Quick Heavy Weapon Swing To Thud Impact Var 01_DDUMAIS_MWP2.wav` | David Dumais Audio - Melee Weapons Sound Effects Pack 2 |
| `sn_impacto_suelo_2.ogg` | Sfx3D `impacto_suelo` | `SWSH_SWING IMPACTS Quick Heavy Weapon Swing To Thud Impact Var 01_DDUMAIS_MWP2.wav` | David Dumais Audio - Melee Weapons Sound Effects Pack 2 |
| `sn_impacto_suelo_3.ogg` | Sfx3D `impacto_suelo` | `SWSH_SWING IMPACTS Quick Heavy Weapon Swing To Thud Impact Var 01_DDUMAIS_MWP2.wav` | David Dumais Audio - Melee Weapons Sound Effects Pack 2 |
| `sn_libro_abre_0.ogg` | Sfx `libro_abre` | `PAPRMisc_Pile Of Antique Books Falling Over 8_344 Audio_Antiques - Books.wav` | 344 Audio - Antique Books |
| `sn_pagina_0.ogg` | Sfx `pagina` | `PAPRMisc_Antique Books Flicking Through Pages 11_344 Audio_Antiques - Books.wav` | 344 Audio - Antique Books |
| `sn_carga_bucle_0.ogg` | Sfx `carga_bucle` | `PAPRMisc_Antique Books Slow Page Turns 6_344 Audio_Antiques - Books.wav` | 344 Audio - Antique Books |
| `sn_naturaleza_0.ogg` | Sfx `naturaleza` | `WOODFric_Wood Shaker Microphone Head Roll Table Alternate Grainy 05_ESM_HDGM.wav` | Epic Stock Media - HD Game Materials |
| `sn_arco_carga_0.ogg` | Sfx3D `arco_carga` | `WOODFric_Wood Shaker Microphone Head Roll Table Alternate Grainy 05_ESM_HDGM.wav` | Epic Stock Media - HD Game Materials |
| `sn_maza_impacto_0.ogg` | Sfx3D `maza_impacto` | `Impact Cut Sweep.wav` | Cinematic Sound Design - Colossal Impacts |
| `sn_explosion_barril_0.ogg` | Sfx `explosion_barril` | `13 Fireworks_powerful explosions_multiples in a row_near.wav` | Ivo Vicic - Fireworks FX |
| `sn_explosion_barril_1.ogg` | Sfx `explosion_barril` | `13 Fireworks_powerful explosions_multiples in a row_near.wav` | Ivo Vicic - Fireworks FX |
| `sn_arde_bucle_0.ogg` | Sfx `arde_bucle` | `24 Campfire, Dropping Fresh Pine Branches in Fire, Crackling, Sizzling Strong, Close 02.wav` | Ivo Vicic - Campfire - Bonfire FX |

**Segunda tanda (13/11, 39 archivos, las filas desde `sn_siseo_apagado_0`):** 27 sustituyen a un sonido sintetizado o de Kenney y 12 son de acciones que no sonaban
(inventario completo en `docs/INVENTARIO_SFX_2026-11-13.md`). En esta tanda el script iguala además el RMS al del archivo que sustituye (opción «como») y
hace bucle sin costura en los tres ambientes (opción «bucle»). En la máquina `pablo` el lote está en `C:\Users\pablo\Downloads\sonniss_gdc2026`.

**Tercera tanda (13/11, 18 archivos, desde `sn_puzle_resuelto_0`):** pistas que eligió Pablo de oído, con su destino. Sale `sn_silbido_arma_0` (lo sustituye `sn_maza_impacto_0`).

Elegidos por el nombre de la pista y medidos (duración, pico y RMS parecidos a lo que sustituyen), **sin escucharlos**: valida Pablo de oído
con `docs/escucha_sonniss.html` (antes y después de cada uno).
Del lote también servirían, sin usar aún: murmullo de gente en español (Sonik, «Spanish Wallas»), hoguera (Ivo Vicic), golpes de lanza en madera y
espada (344 Audio, «Historical Weapons»), 21 golpes de arma con zumbido (David Dumais), pasar páginas de libro antiguo (344 Audio) y arco eléctrico (InMotionAudio).

## Fuentes descargadas sin usar todavía — `audio/fuentes/` (2/11)

Packs completos bajados el 2/11/2026 para sustituir sintetizados por grabaciones. **Nada de esto está en el catálogo aún**:
cuando un sonido pase al juego se copia a `audio/` con prefijo (`kenney_`, `oga_`, `fs_`, `lk_`), se da de alta en `CATALOGO`
y se anota aquí en la tabla de arriba. Los packs enteros no se cargan en Godot (la carpeta lleva un `.gdignore`).

| carpeta | pack | licencia | contenido |
|---|---|---|---|
| `kenney_rpg-audio/` | Kenney RPG Audio · https://kenney.nl/assets/rpg-audio | CC0 | 50: monedas, tela, cinturón, libro, puertas, pasos, armas |
| `kenney_impact-sounds/` | Kenney Impact Sounds · https://kenney.nl/assets/impact-sounds | CC0 | 130: pasos por material e impactos (madera, metal, piedra, cristal, tela) |
| `kenney_interface-sounds/` | Kenney Interface Sounds · https://kenney.nl/assets/interface-sounds | CC0 | 100: clics, confirmar, volver, error, deslizar |
| `kenney_ui-audio/` | Kenney UI Audio · https://kenney.nl/assets/ui-audio | CC0 | 50: clics, rollover, interruptores |
| `oga_gato/` | «cat purr meow» (`cat_*.wav`) y «meow» (`Meow*.ogg`) · https://opengameart.org/content/cat-purr-meow · https://opengameart.org/content/meow | CC0 | ronroneo en bucle, maullidos |
| `freesound/` | seis clips CC0 de Freesound (previsualización HQ en mp3, el wav original pide cuenta): `pluma_papel_duro_marcoman89` (194905), `pluma_pergamino_brktkrgll` (856167), `pluma_pergamino_Nickh69` (507864), `pagina_eZZin` (641757), `paginas_P_Chester` (465260), `paginas_lento_rapido_jephwallace` (318615) · https://freesound.org/people/<autor>/sounds/<id>/ | CC0 | pluma escribiendo (bucle para `trazo`), hojas pasando (bucle para la animación de páginas) |
| `lentikula/` | **pendiente de bajar a mano** (itch.io «name your own price» a 0): «Basic Spell Impacts» (20: rayo, fuego, hielo, agua) · https://lentikula.itch.io/freecc0-basic-spell-impacts-sfx y «Druid Spell Impacts» (15: tierra, planta, viento) · https://lentikula.itch.io/druid-spell-impacts | CC0 | impactos por elemento, 48 kHz 24 bit |

Vistos y NO bajados (CC-BY 4.0, exigen acreditar; decide Pablo): «Magic Spell SFX» de The Soundrack (425, nueve elementos,
carga/lanzar/vuelo; 1,5 GB), «Reading & Writing Sound Pack» de The Soundrack (266: libros, páginas, lápiz), «Free Monster Sounds»
de Coucassi (8 criaturas con aparecer/ataque/daño/muerte/pasos; trae limo y orco). De pago: «Monster Vocalizations» de Morphonaut
(CC0, 2 $, el único con goblin, gólem y goo). Los bundles GDC de Sonniss anteriores (2015–2024, 9–48 GB cada uno; gratis, sin atribución, sin redistribuir) siguen sin bajar; el de 2026 sí (arriba).
