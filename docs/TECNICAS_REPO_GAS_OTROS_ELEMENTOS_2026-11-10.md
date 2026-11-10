# Técnicas del repo de gas para los OTROS elementos (10/11/2026)

Origen: https://github.com/lejrimostfa/force-field-vfx-threejs (MIT). Esta vez se ha leído el **código entero**, no el README. Se clonó con `--depth 1`, sin ejecutar nada, y se leyeron
`src/gas/{solver,grid,fields,flow,advect,sources,forces,project,light,params}.js`, `src/render/{volume,sparks,optics,stage,rock,figures}.js`, `src/main.js`, `src/config.js` y, por si acaso,
`src/{hud,input,events}.js` (solo interfaz). Lo hemos comparado con nuestro port (`docs/HAZ_GAS_PORT_2026-11-09.md`, `docs/HAZ_FUEGO_VS_DEMO_2026-11-09.md`, `laboratorios/haz_gas/shaders/*`),
con la masa CPU (`laboratorios/haz_masa/haz_masa_sim.gd`) y con lo que ya hay en el juego (`haz_gas_juego.gd`, `humo_regla.gd`).
Del lado de los elementos se ha leído: `agua_toy`, `impacto_agua_toy`, `rayo_toy`, `impacto_rayo_toy`, `estado_rayo_toy`, `magma_toy`, `impacto_magma_toy`, `viento_toy`, `viento_corrientes`,
`impacto_viento_toy`, `tierra_toy`, `hielo_toy`, `naturaleza_proyectil_toy`, `naturaleza_barrera_toy`, `nube_veneno_vfx`, `presentacion/vfx_toy_juego.gd` y las entradas 376-378, 416-417, 419-420,
424-432 y 434-448 del DIARIO.

Es un documento de análisis: no cambia código.

**Reglas que respetan todas las propuestas.**
- Los colores salen de los que ya tiene el juego: `AguaPaleta`, `RayoPaleta`, `HieloPaleta`, `Vfx3D.COLOR`, las `PALETAS` de HumoRegla y los verdes del veneno.
- Estilo toon suave. Nada de amarillo en el fuego.
- Sobre FuegoToy BOLA/MURO/PILAR/BARRERA e ImpactoBolaToy solo se añaden capas, cada una con su interruptor.
- Sin Vefects ni assets comerciales.
- Lo que use compute (Forward+/Mobile, no corre headless) lleva un plan B con el toy de siempre.

**Escala de esfuerzo:** S = medio día o menos, M = 1-2 días, L = 3-5 días. Los costes son orientativos: no se ha medido nada nuevo.

---

## 1. Catálogo de técnicas del repo

Estado: **P** = portada (lab y/o juego), **p** = portada en parte, **N** = no portada. «Juego» quiere decir que ya corre en el juego, no solo en el lab.

| # | Técnica | Dónde está en el repo | Estado y dónde la tenemos |
|---|---|---|---|
| T1 | Rejillas a varias resoluciones: gas entero; velocidad, presión y curl a 1/2; luz a 1/4; luz lejana a 1/8 | `gas/fields.js` `makeFields`, `gas/grid.js` `makeGrid`, `gas/solver.js` | **P**: `HazGasSolver.crear()`; juego vía HazGasJuego |
| T2 | Advección MacCormack del gas, recortada a las 8 celdas leídas | `gas/advect.js` `advectGas`, `forward`, `correct` | **P**: `gas_avanza.glsl`, `gas_corrige.glsl` |
| T3 | Velocidad semi-Lagrangiana RK2, a propósito (MacCormack ahí hace ladrillos) | `advect.js` `backtrace`, `advectVel` | **P**: `vel_advecta.glsl` |
| T4 | Remolino por debajo de la rejilla en el backtrace del gas; crece con la rapidez | `advect.js` `gasBacktrace` (`subgrid`) | **P**: `advecta.glslinc` |
| T5 | Ruido SIN divergencia horneado: 64 ondas a·cos(2πk·x+φ) con a ⟂ k y espectro k^(-5/6), tabla 48³ que se repite | `gas/flow.js` `bakeFlow`, `grid.js` `flow()` | **P** en GPU (`flujo_48.bin`). **p** en CPU: `HazMasaSim.flujo()` (pocas ondas, lab). HumoRegla y HumoToy NO lo usan (HumoToy gira la velocidad con `curva`) |
| T6 | Ruido de valor 32³ que se repite (LCG + filtro trilineal) | `fields.js` `noiseField` | **P** |
| T7 | Forma del emisor: punto más cercano del segmento; bamboleo lento del eje que crece con t; radio que «respira» (lamidos); pulso que viaja por el chorro | `gas/sources.js` `beamAt` | **P** en el gas. **N** en los toys: el haz de FuegoToy es recto y los de agua y rayo, también |
| T8 | Alimentación en el choque: contacto a R+0,35, gaussiana·ráfaga de ruido | `sources.js` `gasSources` (`flare`) | **P** en el gas y en HazMasaSim |
| T9 | Combustión: el combustible arde y da calor; la expansión va en vel.w y la divergencia la resta | `sources.js` `burn`, `velSources` (`expansion`), `gas/project.js` `divergence` | **P** solo en GPU |
| T10 | Enfriamiento → hollín según lo lento que va el gas respecto al viento, más una pérdida ∝ T⁴ | `sources.js` `gasSources` (`slow`, `soot`) | **P** en GPU. **P en el juego** por CPU: HumoRegla (HUMO, VAPOR). Capas de serie: impacto_bola, barril, suelo y vapor |
| T11 | Polvo: el aire rápido a ras de suelo lo levanta, en una capa fina que se despeja con la altura | `sources.js` (`lift`, `clearing`) | **P** en GPU. **p** en el juego: HumoRegla POLVO, con las capas `polvo_tierra` y `polvo_viento` APAGADAS |
| T12 | Esponja en las caras abiertas: el gas se apaga y la velocidad se relaja al viento, no a 0 | `sources.js` `spongeAt` | **P** solo en GPU |
| T13 | Exclusión del sólido (no hay gas dentro, con piel blanda) | `sources.js` `outside` | **P**. Generalizado con SDF (lo nuestro) |
| T14 | Flotación ∝ T y peso ∝ hollín (el repo usa weight 0) | `sources.js` `velSources` | **P** en GPU; **p** en HumoRegla (`flota`, `sube`) |
| T15 | Arrastre hacia el viento y empuje de UN sentido: lo que va lento o vuelve se empuja hacia delante | `sources.js` `windAt`, `velSources` (`drag`, `push`, `lag`) | **P** en GPU y HazMasaSim; **p** en HumoRegla (relaja al viento, sin empuje de un sentido) |
| T16 | Piel: se quita la componente que entra, más un tirón a la superficie (wrap) | `velSources` (`skin`, `wrap`) | **P** (GPU con SDF; HazMasaSim con SDF de caja o esfera) |
| T17 | Tope de velocidad (como mucho 6 celdas por paso) | `velSources` (`vmax`) | **P** |
| T18 | Confinamiento de vorticidad: curl y luego la fuerza de su gradiente | `gas/forces.js` `curl`, `confine` | **P** solo en GPU (necesita el campo) |
| T19 | Turbulencia sin divergencia a dos escalas (16 y 9 m), ∝ T + 0,3·hollín + 0,04·\|v\| | `forces.js` `confine` (`eddies`, `stir`) | **P** en GPU; **p** en HazMasaSim |
| T20 | Viscosidad explícita que crece con T (pliegues gordos) | `forces.js` `confine` (`nu`, `blend`) | **P** solo en GPU |
| T21 | Proyección de presión: Jacobi con arranque en caliente 0,96; el sólido refleja; caras abiertas p = 0; suelo cerrado | `gas/project.js` `divergence`, `jacobi`, `project` | **P** solo en GPU |
| T22 | Volumen de luz cercano: difusión 6×2 con tinte naranja puro, atenuada por el hollín | `gas/light.js` `diffuse` | **P** en el lab realista. **N** en el juego: el toon no ejecuta esas pasadas |
| T23 | Volumen de luz lejano a 1/8; su gradiente da la dirección de la luz para los normales | `light.js` `spread` | Igual que T22 |
| T24 | Transmitancia hacia una lámpara (14 pasos): el humo hace sombra | `light.js` `key` | Igual que T22 |
| T25 | Raymarch en compute: corte con la caja, jitter IGN por fotograma, «cuerpo con borde» σ = s²/(s+edge), llamas opacas, salida anticipada | `render/volume.js` `march` | **P** en el realista. El toon (lo nuestro) cambia a isosuperficie con bisección |
| T26 | Relieve por el gradiente de densidad dentro del raymarch | `volume.js` (`slope`, `folds`) | **P** solo en el realista |
| T27 | Tope blando a la luz cercana; la lámpara se apaga donde manda el fuego | `render/optics.js` `softLight`, `volume.js` (`calm`) | **P** solo en el realista |
| T28 | Rampa temperatura → HDR y `holdHue` (comprime sin perder el tono) | `optics.js` `fireColor`, `holdHue` | **P** (paleta «pablo»). El toon usa la rampa de FuegoToy |
| T29 | Filtro temporal: historia recortada al 3×3, mezcla 0,55, copia | `volume.js` `resolveFn`, `copyFn` | **P** en el realista; en el toon no hay jitter |
| T30 | Chispas en GPU: vidas escalonadas; nacen en la piel; montan la velocidad del gas con inercia 1,6; gravedad −7; rebote 0,35; quads estirados en pantalla; color ∝ calor² | `render/sparks.js` `makeSparks` | **P** (`chispas.glsl`, en el juego también). En los toys: chispas CPU con gravedad, pero sin escalonar, sin inercia a un flujo y casi sin rebote |
| T31 | El suelo y la pared se iluminan con los campos: irradiancia, normal inclinado por el gradiente, especular, sombra de humo | `render/stage.js` `rockMaterial` | **P** en el lab (`haz_gas_roca`). **N** en el juego, que usa el decal `luz_suelo_haz` y una OmniLight |
| T32 | Normal de roca horneado (6 octavas, crestas, deformación con senos) | `render/rock.js` `bakeRock` | **P** (lab) |
| T33 | Silueta casi negra con borde de luz por fresnel | `render/figures.js` | **P** (lab) |
| T34 | Post: saturación 1,3, bloom (0,32 / 0,55 / 1,1) sobre min(hdr, 9), viñeta, ACES 0,85 | `main.js` | **P** en el lab realista; **N** en el juego (el post es del juego) |
| T35 | Cámara: órbita automática baja de tres cuartos y OrbitControls con límites | `main.js` `moveCamera`; `input.js` | **P** (lab) |
| T36 | Paso fijo de 1/60 s, sea cual sea la pantalla | `main.js` `loop` | **P** |
| T37 | Mandos por uniforms, sin recompilar; cadena fija de pasadas precompiladas en ping-pong que acaba en el índice 0 | `params.js`, `solver.js` | **P** (UBO, `_montar_cadena`) |
| T38 | El objetivo del chorro se mueve con senos | `main.js` `simulate` | **P** |

**Lo que NO está en el repo (lo que algunos le atribuyen).**
- Colisión SDF contra sólidos cualesquiera: el repo solo tiene una esfera analítica. Lo general es nuestro (`solido.glsl`, `HazMasaSim.sdf`).
- El modo toon de isosuperficie: también es nuestro.
- Ni agua, ni rayo, ni hielo, ni acoplamiento de partículas a la rejilla (las chispas solo LEEN la velocidad).
- Ni MacCormack en la velocidad, ni sombras de escena.

---

## 2. Matriz elemento × técnica

**sí** = encaja y se nota · **quizá** = encaja, pero cuesta o se nota poco · **no** = no encaja o va contra el estilo.
Solo salen las técnicas que tienen sentido fuera del fuego (T1-T4, T17 y T21 son la «máquina» del solver y van dentro de «gas 3D»).

| Técnica | Agua | Rayo | Magma | Viento | Tierra | Hielo | Naturaleza / veneno | Electrificado |
|---|---|---|---|---|---|---|---|---|
| **Gas 3D completo** (HazGasJuego: T1-T4, T21, toon) | quizá: haz de agua que se reparte por la pared en lámina, isosuperficie con el look de `agua_toy.gdshaderinc` | no: el rayo dura 0,06-0,2 s y no es materia | quizá: haz o muro de magma con el FuegoToy oscuro; pero el haz de magma ya son púas | quizá: solo la velocidad (sin dibujar el gas) moviendo hojas y jirones | no | quizá: «soplo helado» (decisión 301: fuego raymarch con paleta fría, mezcla normal) | quizá: nube de veneno como gas pesado (rejilla pequeña) | no |
| **T5 flujo sin divergencia** (CPU con pocas ondas) | sí: espuma y vaho del impacto que se arremolinan sin «respirar» | quizá: bamboleo coherente de los arcos entre redibujos | sí: humo y ceniza que se retuercen | **sí**: ráfagas; las hojas, los jirones y los puntos de las cintas siguen el mismo flujo | sí: la nube de polvo del golpe en espiral, de verdad | sí: vaho frío que se enrosca a ras de suelo | **sí**: las bocanadas se arremolinan sin órbita fija | quizá: chispitas que derivan |
| **T7 forma del emisor** (bamboleo que crece con t, radio que respira, pulso que viaja) | sí: el haz de agua deja de ser un tubo; pulsos de caudal | **sí**: el haz de rayo con pulsos de energía de la mano a la punta; eje que tiembla más lejos de la mano | quizá: púas ígneas con pulso de calor en secuencia (ya brotan en secuencia) | sí: chorro de jirones que respira | no (las púas ya van en secuencia) | quizá: escarcha que avanza con pulso | no | quizá: pulso por los arcos de la piel |
| **T8 alimentación en el choque** | sí: el haz de agua alimenta un abanico que crece y se mueve (hoy es una lámina fija) | sí: los arcos del choque nacen a R+0,35 con ráfaga (ya reptan) | sí: brasas y humo nacen en el contacto del haz o muro | sí: soplo radial alimentado mientras dura el haz | quizá | quizá | no | no |
| **T10 enfriar → hollín / vapor** (HumoRegla) | sí: VAPOR ya está (agua sobre fuego) | quizá: un hilo de humo gris donde quema la hierba | **sí**: la grieta que se enfría suelta humo oscuro; cráter, bola rodando, muro y pilar de magma | no | no | no (el hielo no humea; ver T14 inverso) | sí: la nube que arde se convierte en humo pardo bocanada a bocanada | no |
| **T11 polvo levantado** (HumoRegla POLVO) | no | quizá: polvo bajo el pilar al caer | quizá: ceniza bajo la bola que rueda | **sí**: el haz y la barrera de viento barren el suelo | **sí**: cada púa que brota y el golpe radial | no | no | no |
| **T12 esponja** | no | no | no | quizá | no | sí: el vaho frío se apaga en el borde del área | sí: el borde de la nube es el radio que envenena (ya lo marca la mancha) | no |
| **T14 flotación y peso** | sí: gotas y espuma con peso, vaho que sube | no | sí: humo que sube según la temperatura de la grieta | no | sí: polvo pesado que cae pronto | **sí** al revés: el aire frío PESA, baja y se extiende | **sí**: gas tóxico pesado a ras de suelo | no |
| **T15 viento de un sentido** | sí: lo que salpica el haz no vuelve a la jugadora | no | quizá | **sí**: nada vuelve hacia quien lanza; las hojas siguen la ráfaga | sí: el polvo de las púas va hacia delante | quizá | sí: con viento la nube se deshilacha por regla (hoy, por retraso) | no |
| **T16 piel y wrap con SDF** | **sí**: el haz y el géiser se abren y rodean al enemigo o al muro | quizá: arcos que se ciñen a la cápsula real | quizá: el haz de magma contra un muro | **sí**: la ráfaga rodea a enemigos y esquinas | quizá | quizá | sí: la nube rodea obstáculos y no los atraviesa | **sí**: los arcos se proyectan a la cápsula de verdad y no a un cilindro |
| **T18-T20 vorticidad y viscosidad** (solo GPU) | quizá (con gas 3D) | no | quizá | quizá | no | no | quizá | no |
| **T22-T24 volúmenes de luz** | no (el agua no brilla) | quizá: en el juego, el equivalente barato es un decal que parpadea; el volumen real es caro y suave | quizá: ídem, decal carmesí que late | no | no | no | no | quizá: un decal tenue bajo la entidad |
| **T25-T29 raymarch realista y temporal** | no (estilo) | no | no | no | no | no | no | no |
| **T30 chispas tipo sparks.js** | sí: gotas con inercia al flujo y rebote | **sí**: vidas escalonadas, nacen en la piel, rebote 0,35, estiradas | **sí**: brasas que rebotan y se enfrían con el color ∝ calor² (tramo bajo de la rampa) | sí: hojas y briznas con inercia al flujo | sí: cascotes que rebotan | sí: esquirlas y destellos (ya rebotan una vez) | quizá: esporas y hojas | **sí**: chispitas que saltan de la piel y rebotan en el suelo y el agua |
| **T31 suelo iluminado por el campo** | no | quizá (el decal ya hace casi lo mismo) | quizá | no | no | no | no | no |
| **T34 post** | no | no | no | no | no | no | no | no |
| **Versión barata 2D / partículas** (HazMasaSim, HumoRegla) | **sí** | sí | **sí** | **sí** | **sí** | **sí** | **sí** | sí |

---

## 3. Por elemento: las 1-3 mejores propuestas (ordenadas por ganancia/esfuerzo)

### Agua (AguaToy: BOLA, HAZ, PILAR = géiser, MURO = ola; ImpactoAguaToy)
1. **Salpicadura del haz y del géiser que rodea lo que golpea** (T8 + T15 + T16 + T30, por CPU).
   - Hoy el abanico del choque (`HazChoque`, `salpicadura_agua_haz.gdshader`) es una lámina fija con gotas que caen.
   - Con la lógica de HazMasaSim (alimentación en el contacto, piel con wrap y reparto a los lados, viento de un sentido), las GOTAS y unas manchas de espuma corren por la cara del muro o rodean al goblin, y nada vuelve a la jugadora.
   - Gotas con inercia, gravedad 9,8 y rebote 0,35 en el suelo y en el SDF.
   - Formas: haz, pilar (géiser contra el techo o un enemigo encima) e impacto contra una pared.
   - Reutiliza `HazMasaSim` (sdf, normal, flujo, `_mover_chispas`), `AguaGotas`, `AguaPaleta` y los `choques` de `VfxToyJuego._choques_locales`.
   - Esfuerzo M. Coste: ≤ 90 gotas más 20 manchas por haz en CPU (~0,2 ms).
2. **Vaho y espuma del impacto con flujo sin divergencia** (T5 + T14).
   - Las bocanadas de vaho (whitePuff CC0) y la espuma del área se arremolinan y suben con el flujo, en vez de subir rectas.
   - Formas: impacto y área. Reutiliza `HazMasaSim.flujo` o la materia VAPOR de HumoRegla, con una capa `vaho_agua` apagada de serie.
   - Esfuerzo S. Coste: despreciable.
3. **Haz de agua con HazGasJuego en «modo agua»** (gas 3D).
   - Sin combustión ni hollín, flotación 0, peso > 0 y arrastre alto. La «T» pasa a ser cantidad de agua.
   - Dibujo: una variante de `raymarch_toon.glsl` con los tres tonos por umbral y el fresnel de `agua_toy.gdshaderinc`.
   - Se ve como un chorro que se APLASTA contra el muro y se reparte en una lámina que cae por la pared.
   - Formas: haz. Plan B: el HAZ de AguaToy de hoy.
   - Esfuerzo L. Coste: el del haz de gas, 2,4-7,2 ms por haz en una 3070 (low).

### Rayo (RayoToy: BOLA, MURO = valla, PILAR = columna, BARRERA = aro, HAZ = tubo con hélices; ImpactoRayoToy; SelloRayo)
1. **Pulso y bamboleo del haz** (T7, solo shader o vértices).
   - Pulsos de energía que viajan de la mano a la punta: ruido que se desplaza con t − tiempo·0,4, como `pulse` en `beamAt`.
   - Desvío del eje que crece con la distancia a la mano: ruido(t·0,12, tiempo) · t, como `wob`. El rayo nace fijo en la mano y tiembla más lejos.
   - Formas: haz, y la valla (muro) entre postes. Colores de `RayoPaleta`, aditivo como ahora. Reutiliza `rayo_trazos.gd` y `rayo_trazo.gdshader`.
   - Esfuerzo S. Coste: nulo.
2. **Chispas como sparks.js** (T30).
   - Vidas escalonadas (no salen todas de golpe); nacen en la piel del choque, a R+0,15; v = frente·3 + aleatorio·6; gravedad; REBOTE 0,35 en el suelo (hoy se apagan al tocarlo); estiradas por la velocidad en pantalla (cola = p − v·0,028 s).
   - Formas: impacto, pilar (al llegar al suelo) y proyectil (estela).
   - Reutiliza `chispa_impacto.gdshader` y el MultiMesh de `SpriteToy`, con la lógica de `HazMasaSim._mover_chispas`.
   - Esfuerzo S-M. Coste: ≤ 60 chispas por impacto.
3. **Arcos ceñidos al sólido real** (T16 con SDF).
   - En el choque del haz con un enemigo, los arcos que reptan se proyectan sobre la cápsula y el muro de verdad, no sobre un plano.
   - Reutiliza las primitivas de `HazGasJuego` (casillas, cápsulas, cajas) evaluadas en CPU, con la misma fórmula que `solido.glsl`.
   - Esfuerzo M. Solo para el haz y el impacto.

### Magma (MagmaToy: BOLA de roca que rueda; MURO, PILAR y BARRERA = FuegoToy oscuro con piedras; HAZ = púas ígneas; ImpactoMagmaToy)
1. **Humo por regla para el magma** (T10 + T14, HumoRegla).
   - Una capa nueva `magma`, apagada de serie, con la materia HUMO y un rendimiento mayor: la lava siempre va «lenta», así que casi todo el calor que pierde sale en hollín.
   - Emisores: el cráter que se enfría (fuente mientras `calor` > 0,3), la bola que rueda (penacho fino detrás) y la cima del muro y del pilar de magma (las capas `muro` y `pilar` ya existen para el FuegoToy hijo).
   - Colores: los de la PALETA HUMO de HumoRegla (pardo y hollín), nada nuevo.
   - Formas: proyectil, impacto, área, muro, pilar y haz (las púas ígneas al hundirse).
   - Esfuerzo S (una línea `enganchar_*` por emisor más una paleta). Coste: dentro de `MAX_VIVAS` 420.
2. **Brasas como sparks.js** (T30).
   - El color se enfría con la vida (calor² con el tramo bajo de la rampa), las brasas rebotan 0,35 y las de la estela de la bola tienen inercia hacia atrás.
   - Formas: proyectil, impacto y área. Reutiliza `SpriteToy` y `ImpactoMagmaToy._avanzar_esquirlas`.
   - Esfuerzo S.
3. **Ceniza levantada por la bola que rueda** (T11, materia POLVO con los tonos `hollin` y `hollin_sombra` de HUMO).
   - Formas: proyectil. Esfuerzo S. Es quizá: compite con el humo de la regla 1.

### Viento (VientoToy revisado: cintas de `viento_corrientes.gd`, jirones de humo toon, hojas)
1. **Un solo campo de flujo para todo el viento** (T5 + T15).
   - El flujo sin divergencia de `HazMasaSim.flujo`, más un viento de un sentido a lo largo de la figura y el arrastre de la demo (0,7) con el empuje (5).
   - Hojas, jirones y los PUNTOS DE CONTROL de las cintas (`_rafaga`, `_haz`, `_tornado`) se desplazan con el MISMO campo: las ráfagas se ven coherentes y nada vuelve hacia quien lanza.
   - Formas: proyectil, haz, muro, pilar (tornado: viento tangencial más el flujo) y barrera.
   - Esfuerzo M. Coste: unas 8 ondas · 200 puntos, ~0,2 ms en CPU.
2. **Piel y wrap contra los sólidos** (T16).
   - El haz y la ráfaga rodean al goblin o a la esquina en vez de atravesarlos: las cintas se doblan por la piel.
   - Reutiliza las primitivas de `HazGasJuego` y el `sdf` de HazMasaSim.
   - Formas: haz e impacto. Esfuerzo M.
3. **Polvo y hojas barridos del suelo** (T11).
   - Encender `polvo_viento` solo para el haz y la barrera, con `anadir_aire` a lo largo del haz (hoy solo en el impacto).
   - Formas: haz, barrera y área. Esfuerzo S. Pablo dejó el polvo apagado (426): enseñarlo con capturas antes de encenderlo.

### Tierra (TierraToy: rocas del mundo; HAZ = púas en secuencia; ImpactoTierraToy)
1. **Ola de polvo que sigue a las púas** (T11 + T15).
   - Cada púa que brota llama a `HumoRegla.anadir_aire` en su pie. El aire va hacia delante (un sentido), así que el polvo corre por delante de la secuencia y no vuelve.
   - Formas: haz, muro e impacto. Reutiliza `polvo_tierra` (existe, apagada) y los tonos POLVO, que ya casan con el suelo del bosque (445).
   - Esfuerzo S.
2. **Nube del golpe con flujo sin divergencia** (T5): la «nube con cascotes en espiral» (438) gira de verdad, no en una órbita fija. Formas: impacto y área. Esfuerzo S.
3. **Cascotes como sparks.js** (T30): rebote 0,35, inercia al flujo y vidas escalonadas en el golpe. Formas: impacto y haz. Esfuerzo S. Hoy ya hay fragmentos que ruedan, así que la ganancia es pequeña.

### Hielo (HieloToy existe, pero en el juego el hielo sigue con el dibujo de antes, entrada 434)
1. **Vaho frío que PESA** (T14 al revés, más T12 y T5).
   - Una materia nueva de HumoRegla `FRIO`: flotación negativa, capa a ras de suelo como el polvo, esponja en el borde del área y remolino lento.
   - Colores de `HieloPaleta` (ESCARCHA, CLARO). Cae de los cristales y se extiende por el suelo.
   - Formas: muro, pilar, barrera, área e impacto.
   - Esfuerzo S-M. Coste: dentro del tope de HumoRegla.
2. **Soplo helado con el gas toon** (gas 3D).
   - Es la decisión 301 de Pablo: el shader de fuego raymarched, con paleta fría, sin emisión y en mezcla normal.
   - Es exactamente HazGasJuego con la rampa cambiada por `HieloPaleta`, flotación < 0 y sin hollín. Formas: haz o aliento. Plan B: la lanza de HieloToy.
   - Esfuerzo M-L. Coste: el del haz de gas.
3. **Destellos y esquirlas como sparks.js** (T30, vidas escalonadas). Formas: impacto y morir. Esfuerzo S. Ganancia baja: ya rebotan una vez.

### Naturaleza / veneno (proyectil y barrera del chamán; NubeVenenoVfx)
1. **Nube de veneno como «gas pesado» por regla** (T5 + T14 + T15 + T16).
   - Las 16 bocanadas dejan de orbitar y siguen el flujo sin divergencia, con peso: se quedan a ras de suelo.
   - Con viento se deshilachan con el arrastre de la demo, no con un retraso puesto a mano. Rodean obstáculos con la piel SDF.
   - Mismos verdes (≤ 0,22 por bocanada) y misma mancha de suelo: el radio que envenena no cambia.
   - Formas: área y estado. Reutiliza `NubeVenenoVfx` y `HazMasaSim.flujo`/`sdf`.
   - Esfuerzo M. Coste: despreciable (16 bocanadas).
2. **La nube ardiendo suelta humo** (T9 + T10).
   - El estado FUEGO de la nube emite bocanadas de HumoRegla HUMO. Es la regla tal cual: el gas «combustible» arde, se frena y da hollín pardo.
   - Va con una capa nueva `veneno_fuego`, apagada de serie. Formas: área. Esfuerzo S.
3. **Estela del proyectil con flujo** (T5): las manchas y hojas de la estela (`NaturalezaManchas`, `NaturalezaHojas`) se arremolinan detrás de la bola. Formas: proyectil. Esfuerzo S.

### Agua electrificada y estado electrificado (EstadoRayoToy ENTIDAD y SUPERFICIE)
1. **Arcos en la piel REAL** (T16): en ENTIDAD, `_piel()` usa la cápsula de la `CapsuleShape3D` del cuerpo (la misma que lee `HazGasJuego`), no un cilindro fijo. Así el estado se ciñe a goblins, lobos y limos. Esfuerzo S.
2. **Chispitas como sparks.js** (T30): nacen en la piel a R+0,15, saltan, caen y rebotan 0,35 en el suelo o en el agua, con vidas escalonadas. En SUPERFICIE derivan con la corriente del agua (2D), así se lee que el agua conduce. Formas: estado. Esfuerzo S.
3. **Pulso por los arcos** (T7) y un decal tenue que parpadea con `RayoPaleta.LUZ` bajo la entidad. Sin OmniLight: el presupuesto de luces no cambia. Esfuerzo S. Es quizá.

---

## 4. Top 5 en conjunto

| # | Propuesta | Elementos y formas | Reutiliza | Esfuerzo | Coste aproximado |
|---|---|---|---|---|---|
| 1 | **HumoRegla para el magma** (capa `magma`): humo oscuro donde se enfría la grieta: cráter, bola que rueda, muro y pilar | Magma: proyectil, impacto, área, muro, pilar | HumoRegla (materia HUMO, `enganchar_*`, capas `muro` y `pilar`) | **S** (≤ ½ día) | CPU, dentro de las 420 bocanadas |
| 2 | **Chispas tipo sparks.js** para rayo, electrificado y brasas de magma: vidas escalonadas, nacen en la piel, inercia, rebote 0,35, estiradas | Rayo: impacto, pilar, proyectil. Electrificado: estado. Magma: impacto, proyectil | `chispa_impacto.gdshader`, `SpriteToy`, `HazMasaSim._mover_chispas` | **S-M** (1 día) | ≤ 60 por efecto, CPU |
| 3 | **Un solo campo de viento**: flujo sin divergencia + viento de un sentido + piel SDF para hojas, jirones y puntos de las cintas | Viento: todas las formas | `HazMasaSim.flujo`/`sdf`, primitivas de `HazGasJuego`, `viento_corrientes.gd` | **M** (2 días) | ~0,2 ms CPU |
| 4 | **Nube de veneno como gas pesado por regla**, y que suelte humo al arder | Naturaleza: área y estado | `NubeVenenoVfx`, `HazMasaSim.flujo`, HumoRegla | **M** (1-2 días) | despreciable |
| 5 | **Haz de agua con HazGasJuego en modo agua**: se aplasta y se reparte en lámina por la pared | Agua: haz (después quizá el géiser) | HazGasJuego, `solido.glsl`, `raymarch_toon.glsl` (variante), `agua_toy.gdshaderinc` | **L** (3-5 días) | GPU 2,4-7,2 ms por haz (3070, low); plan B, AguaToy HAZ |

**Fuera del top, pero de esfuerzo S:**
- el pulso y el bamboleo del haz de rayo (T7);
- los arcos del estado electrificado en la cápsula real;
- la ola de polvo de las púas de tierra (con capturas, porque Pablo apagó el polvo);
- el vaho frío del hielo, que conviene hacer cuando el HieloToy entre en el juego.

**Lo que no recomiendo fuera del fuego:**
- Los volúmenes de luz (T22-T24) y la luz del escenario desde el campo (T31): son caros y suaves, contra el estilo. El decal que parpadea ya cubre el 80 %.
- El raymarch realista, el filtro temporal y el post (T25-T29, T34).
- El gas 3D para el rayo: dura menos que la simulación en arrancar.
- El gas 3D para la tierra.
