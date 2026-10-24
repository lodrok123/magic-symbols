# Auditoría de la clase `Hechizo` frente a su especificación y a lo que de verdad se ejecuta en el juego

24/10/2026 · rama `claude/proyecto-analisis-profundo-bf47f8` (commit `7a91ea36`) · sin tocar el repo.

Todo lo medido sale de dos scripts escritos en el scratchpad y de las pruebas del repo:
- `barrido_hechizos.gd` → `barrido_salida.txt`
- `depurar_casos.gd` → `depurar_salida.txt`
- pruebas del repo → `salida_<prueba>.txt`

Las cifras son de esas salidas; cuando algo no se pudo medir, se dice.

---

## 0. Qué significa «cumplir el Sello»

- **Acepción de diseño (la que se ha usado aquí): Sello = elemento.** Así lo fijan `ARQUITECTURA.md:14`, `docs/CONTEXTO.md:36`, `README.md:35` y `Lanzador3D.PROGRESIONES` («SELLO = elemento, GLIFO = forma», `magia/lanzador_3d.gd:90`). «Cumplir el Sello» se ha leído así: lo que aporta cada elemento (ESPEC §2 y los `*_rune.tres`) se construye y se ejecuta, para los seis, en todas las figuras.
- **Acepción vieja, que sigue viva en el código: sello = glifo de sector.** Aparece en:
  - `nucleo/sigils.gd:4` («QUÉ APORTA CADA SELLO» = glifos);
  - `GestureLibrary.BIBLIA`, `uso: "sello"` = glifo de sector (`nucleo/gesture_library.gd:79-95`);
  - los avisos «Página llena: %d sellos» y «Aún no conoces ese sello» (`magia/grimorio.gd:449,468`);
  - el contador del libro «sellos %d/%d», que cuenta glifos (`presentacion/ui/spellbook.gd:1824`);
  - los sonidos `sello_ok` y `sello_no`.

  El jugador ve «sellos 2/6» cuando habla de glifos. Esto choca con el vocabulario oficial.
- **No hay ningún documento llamado «Sello»** que sea una especificación concreta.

---

## A. Matriz de cumplimiento de la ESPEC (docs/ESPEC_HECHIZO.md v1.1)

Leyenda de «¿cumple?»:
- **sí**
- **no**
- **parcial**
- **solo dato**: se construye pero nadie lo ejecuta
- **solo lab**: se ejecuta, pero ningún glifo ni `.tres` lo produce, así que solo llega desde el laboratorio o desde `con()`

La columna «lo lee» se sacó con un grep de `h.|hechizo.|…<campo>` en `magia/`, `enemigos/`, `objetos/`, `presentacion/`, `jugador/` y `escenas/` (resultado en `lecturas_campos.txt`).

### §0 Reglas generales

| espec | código | ¿cumple? | nota |
|---|---|---|---|
| §0.1 unidades en m y m/s; × casilla solo en HechizoVivo | `hechizo.gd:15-16`; `hechizo_vivo.gd:907` (v × casilla), `:903`, `:910`, `:911` | sí | `Lanzador3D._salida_de_mano` escribe `altura_salida` en m (`lanzador_3d.gd:1213`): es correcto. |
| §0.3 si viaja: recorre, se para al chocar y se queda `permanencia`; `persiste` no cuenta | `hechizo_vivo.gd:1155-1193` (fin y quedarse); `:1201-1212` | **parcial / contradicción doc-código** | Al pararse, el proyectil aplica su materia con `vida = persiste + permanencia` (`:1208`). Una flecha de fuego sin ᛉ **deja una zona de llamas de 3 s**, y la ESPEC §0.3 dice literalmente «una flecha de fuego sin Permanencia no se queda ardiendo». La regla viene de la entrada 191 del diario («regla de impacto»), pero la ESPEC no se actualizó. |
| §0.3 si no viaja: `persiste + permanencia` | `hechizo_vivo.gd:197`, `:217-218`, `:766` | sí | La solidez tiene un suelo de 2 s (`VIDA_MIN_SOLIDEZ_V2`, `:44`, `:695`). |
| §0.6 nada escondido en constantes | — | parcial | Siguen siendo constantes y no campos: `Combate3D` ×0,6 de lento (`combate_3d.gd:458`, en vez de `ralentiza_fuerza`), +15 del hielo sobre mojado y ×1,5 del rayo (`:491`, `:496`), y `FUERZA_EMPUJE` del viento (`lanzador_3d.gd:1719`). |

### §1.1 Geometría

| campo | base espec → código | quién lo cambia (espec → código) | tope | lo lee | ¿cumple? |
|---|---|---|---|---|---|
| `semieje_x` | 0,10 → `RADIO_BASE_V2` 0,10 (`sigils.gd:295`; `hechizo.gd:115`) | ᛁ horizontal +0,25 → `PASO_ANCHO_V2` 0,25 (`sigils.gd:303`, `:375`) | 3,0 → 3,0 | `geo()` → rasterizado (`hechizo_vivo.gd:150`, `:423`) | sí |
| `semieje_z` | 0,10 → 0,10 | ᛁ vertical +0,10 → `PASO_FONDO_V2` 0,10 (`:305`, `:376`) | 3,0 → 3,0 | ídem | sí |
| `semieje_y` | 0,10 → 0,10 | ᛏ +0,30 → `PASO_ALTURA_V2` 0,30 (`:301`, `:377`) | 1,0 → 1,0 | `niveles`, materia sólida | sí |
| `grosor_min` | 0,10 → 0,10 (`hechizo.gd:129`) | — | — | solo `_limitar` (`:325-327`) | sí |
| `volumen`, `superficie`, `niveles` | derivados (`:215-220`, `:437`) | — | — | `niveles` sí (vía `GeometriaV2.niveles`); `volumen` y `superficie` no los lee nadie del juego | sí (derivados) |

**Contradicción conocida «radio base 0,10 / 0,25»:** está **resuelta en la ESPEC** (§1.1 ya dice 0,10). Sigue abierta en:
- `PENDIENTES.md:103`;
- la tabla de glifos de `ARQUITECTURA.md:176-177` (dice +0,15);
- `ARQUITECTURA.md` §«Topes» (sin cifras de paso).

`Sigils.VOLUMEN_AGUA_BASE_V2` usa a propósito la esfera de 0,25 (`sigils.gd:449`).

### §1.2 Movimiento

| campo | base | quién lo cambia | tope | lo lee (archivo:línea) | ¿cumple? |
|---|---|---|---|---|---|
| `velocidad` | 0 | flecha = 4/casilla = **1,739 m/s** (`sigils.gd:310`, `:380`) | — | `hechizo_vivo.gd:123`, `:907` | sí |
| `distancia_max` | 0 | flecha 2 + 1 por glifo (`desde 1`, +1·n), tope 6 (`sigils.gd:381`) | 8 (§1.9) | `hechizo_vivo.gd:910` | sí |
| `aceleracion` | 0 | — | — | `hechizo_vivo.gd:944-945` | solo lab |
| `gravedad` | 1 (`hechizo.gd:141`) | el `.tres` con `fija` (la ESPEC dice «× estado»; con base 1 da lo mismo) | — | `hechizo_vivo.gd:908`, `:950` | sí, **pero ver D-2: tierra y hielo caen a 0,7 casillas** |
| `elevacion` | 0 | ningún glifo («flota» futuro) | 2 | `hechizo_vivo.gd:261`, `:903` | solo lab |
| `rebotes` | 0 | ᚢ +1, tope 3 (`sigils.gd:388`) | — | proyectil `hechizo_vivo.gd:996`, `:1013`; volumen vía `props` (`:369`) | sí (proyectil); en el haz no hace nada (lo dice la ESPEC §3b) |
| `retorna` / `busca` | false / 0 | — | — | `:1156` / `:941`, `:1100` | solo lab |
| `en_punto` | false | barrera fija true (`sigils.gd:385`) | — | `lanzador_3d.gd:804`, `:924` | sí, **pero ver D-5: con flecha y esqueleto nace en la mano** |
| un solo desplazamiento (8 m/s por defecto) | `VELOCIDAD_VIAJE_DEFECTO` 8 (`hechizo.gd:56`) | — | — | `hechizo_vivo.gd:399` | **solo lab**: la flecha siempre pone `velocidad` > 0, así que la rama «volumen que viaja» (`:215-216`, `:382-390`) no la alcanza ninguna receta. En el barrido: 0 de 48 048. |
| «el choque acaba el viaje: casilla sólida, **barrera que bloquea (solidez de otro hechizo)**, golpe más allá de `perfora`» | proyectil: `_avanzar` mira `celda_solida` (`:992-994`), `_golpes_areas` mira `bloquea_proyectiles` (`:1043`) | — | — | — | **parcial**: el proyectil **no consulta `_barrera_en`/`SolidezV2`** (lo hace solo `trazar`, `lanzador_3d.gd:1573`). Una flecha del jugador atraviesa los muros con solidez que acaba de levantar, y la reflexión de «barrera + rebote» no afecta a las flechas. |

### §1.3 Tiempo

| campo | base | quién lo cambia | tope | lo lee | ¿cumple? |
|---|---|---|---|---|---|
| `persiste` | 0 | elemento (× calidad, `hechizo.gd:312-314`) | 25 con `permanencia` | `hechizo_vivo.gd:157` (copia del RuneData), `:197`, `:1208` | sí (ver §0.3) |
| `permanencia` | 0 | ᛉ +2 tope 25 (`sigils.gd:392`); barrera +1 por cada glifo sucesivo (`salta 1`, `:386`) | 25 − `persiste` (`hechizo.gd:331`) | `hechizo_vivo.gd:197`, `:216`, `:1188` | sí |
| `retardo` | 0 | aparcado | — | `hechizo_vivo.gd:381`, `:383` (**solo en la rama de volumen**; el proyectil y el haz no lo leen) | solo lab / parcial |
| `intervalo` | 0,25 | — | — | `hechizo_vivo.gd:565-566`, `:374`, `:758` | sí |
| `crece` | 0 | ᚷ +0,5, tope 1,5 (`sigils.gd:390`) | 1,5 | `props["crece"]` → `fases_crece` (`hechizo_vivo.gd:367`, `:403-414`) | **parcial**: (1) se aplica como **fracción de escala por segundo** (`s = escala_nace + crece·t`, `:411`), no en **m/s de radio** como dice §1.3; el comentario de `hechizo.gd:133` lo deja para E2, que no lo hizo. (2) **No hace nada** en el proyectil ni en el haz. (3) Con 3 glifos o menos el volumen es tan pequeño que crecer no cambia ninguna casilla: **0 de 222** volúmenes quietos con ᚷ mostraron más de una tanda (barrido B). En el juego, ᚷ solo cambia el VFX. |
| `escala_nace` | 0,3 | — | — | `hechizo_vivo.gd:374` | sí |

### §1.4 Física y choque

| campo | base espec → código | quién | lo lee | ¿cumple? |
|---|---|---|---|---|
| `densidad` | 1 → 1 | elemento (§2, valores en el `.tres` ✓) | nadie | solo dato (la ESPEC lo permite: «solo se rellena») |
| `masa` | derivado (`hechizo.gd:221-223`) | — | nadie | solo dato |
| `solidez` | **0 → 0** | barrera 1 × 1,5ⁿ, tope 3 (`sigils.gd:384`) | `props` → `_solidez` (`hechizo_vivo.gd:205`, `:328-329`); `:773` | sí. **Contradicción documental:** el comentario de `hechizo.gd:136` dice que el doc pone 1, pero la ESPEC §1.4 pone 0. El 1 es de `HECHIZO_CLASE.md:61`, que está desfasado. |
| `resistencia` | ESPEC «10 × solidez» → código **30 × solidez** (`hechizo.gd:73`, `:226`) | derivado | `hechizo_vivo.gd:696` (`aguante`) | **no** (divergencia declarada en el código, sin decisión de Pablo anotada en la ESPEC) |
| `pisable` | false | elemento | Hechizo: **nadie**. Se lee del RuneData (`rune.pisable`, `hechizo_vivo.gd:493`) | parcial (si se toca en el lab, no tiene efecto) |
| `elasticidad` | 0,2 | — | **nadie** (el rebote invierte la velocidad entera: `hechizo_vivo.gd:997-1000`, `:1015`) | solo dato |
| `perfora` | 0 | — | `:1051`, `:1124` | solo lab |
| `choca_con` | 0 = mundo + enemigos | — | `:980`, `:984` | solo lab |
| `golpea_lanzador` | false | — | `:854`, `:1128` | solo lab |

### §1.5 Potencia y elemento

| campo | base | quién | lo lee | ¿cumple? |
|---|---|---|---|---|
| `dano` | 1 | elemento `fija` (`hechizo.gd:338`); tierra +18 (`suma`) | `combate_3d.gd:472`; `hechizo_vivo.gd:727`, `:825`; pigmento `lanzador_3d.gd:1179` | sí |
| `dano_periodico` | 0 | fuego 40 | `hechizo_vivo.gd:567` → `ZonaV2` | sí |
| `potencia` | 1 | aparcado | **nadie**. GLIFOS_RECETA §2.4 paso 5 dice «daño × potencia» y no se aplica | solo dato |
| `intensidad_estado` | 1 | — | **nadie** | solo dato |
| `temperatura`, `humedad`, `conductividad` | 0 | elemento (valores ✓) | nadie | solo dato (permitido por la ESPEC) |
| `quema`, `moja`, `congela`, `congela_mojado`, `aturde`, `ralentiza`, `interrumpe` | 0 | `.tres` | `combate_3d.gd:485`, `487`, `494`, `494`, `534-535`, `503`, `500` | sí, **pero cada estado solo se aplica si el elemento es «su» elemento** (`match el:` en `combate_3d.gd:479-503`). Un `quema` puesto a un hechizo de agua en el lab no hace nada. Para «cumplir el Sello» basta; para que «los efectos sean datos», no. |
| `ralentiza_fuerza` | 0 (tierra 0,4) | `.tres` | **nadie** (`vel_mult` usa 0,6 fijo, `combate_3d.gd:458`; casualmente 0,6 = 1 − 0,4) | solo dato |
| `veneno`, `veneno_dps` | 0 / 3 | — | `combate_3d.gd:526-530` | solo lab |
| `empuje` | 0 (del elemento) | elemento | `Hechizo.empuje`: **nadie**. La zona de gas lee `z.rune.empuje` del RuneData (`hechizo_vivo.gd:645`) | parcial |
| `fuerza_golpe` | 400 | `.tres` | `combate_3d.gd:532-533` | sí |
| `deja` | "" | elemento | `Hechizo.deja`: **nadie**. Se lee `rune.deja` (`hechizo_vivo.gd:288`, `:491`, `:572`, `:681`) | parcial |
| `estado_materia` | solido | elemento | `hechizo_vivo.gd:152` | sí |
| `color`, `etiquetas` | — | elemento | `Hechizo.color`: nadie (el VFX va por el nombre del elemento) | solo dato |

### §1.6 Propagación y copias

| campo | base | quién | lo lee | ¿cumple? |
|---|---|---|---|---|
| `copias` | 1 | ᚠ +1, tope 4 (`sigils.gd:387`) | `props["copias"]` → `eventos_de` (`hechizo_vivo.gd:366-381`) | **parcial / no** (ver D-1): **no** en el proyectil (un solo `_iniciar_proyectil`, `:123-124`); con un número **par** de copias, en volúmenes pequeños **se solapan** y salen menos; en el haz no hace nada (lo dice la ESPEC §3b). |
| `separacion` | 0,5 | — | `hechizo_vivo.gd:372` | sí (solo volúmenes) |
| `dispersion` | 15° | — | `hechizo_vivo.gd:379` | sí (solo volúmenes; el proyectil no tiene abanico) |

### §1.7 y §1.8 Derivados

| derivado | código | lo lee el juego | ¿cumple? |
|---|---|---|---|
| `viaja` | `hechizo.gd:435` | `hechizo_vivo.gd:133`, `:195`, `:766` | sí |
| `flota`, `anclado`, `protege`, `se_expande`, `se_repite`, `rebota` | `hechizo.gd:227-244` | nadie (solo `prueba_hechizo`) | sí (derivados correctos, sin uso) |
| `persistente` | `hechizo.gd:247-249` | `momento_de` (`:520`) | sí |
| `haz`, `alcance_haz` | `:252-260` | `hechizo_vivo.gd:168`, `:243` | sí |
| `forma`, `cast_point`, `niveles` | `:436-438` | `lanzador_3d.gd:1010`; Receta3D | sí. 0 desacuerdos con `Receta3D` en 48 048 casos. |
| `coste_tinta` | `:439-443` | el libro cobra `Tinta.coste_receta(receta.coste_v2())` (`lanzador_3d.gd:792`, `:1017`), **otra cuenta**, aunque da el mismo número | sí (0 desacuerdos), pero hay **dos fuentes de verdad** |
| `recarga` | `Sigils.cooldown_v2` (`:444`) | `receta.cooldown` (`lanzador_3d.gd:1020`) | sí. **Vale 0 sin glifos** (6 casos), pero el libro no deja lanzar una página sin glifos (`grimorio.gd:656`, `lanzador_3d.gd:747`). |
| `figura()` | `hechizo.gd:549-558` | **nadie del juego** (solo pruebas). `VfxElemento3D` decide por su cuenta (`vfx_elemento_3d.gd:264`, `:293`, `:299`) | **parcial**: barrera + flecha da `figura() == "barrera"`, pero se ejecuta y se dibuja como **proyectil** (6 006 combinaciones). |

### §1.9 Límites globales

| límite | código | ¿cumple? | medido |
|---|---|---|---|
| semieje X/Z ≤ 3, Y ≤ 1, ≥ `grosor_min` | `_limitar` (`hechizo.gd:325-327`) | sí | 0 violaciones / 48 048 |
| `elevacion` ≤ 2 | `:328` | sí | 0 |
| **altura total (`elevacion` + 2·semieje_y) ≤ 2 niveles** | **no existe** en `_limitar` | **no** | Desde `construir()` no aparece (ningún glifo da elevación), pero `con({"elevacion": 2})` con Y = 1 da 4 m. `prueba_hechizo.gd:341-342` lo acepta. |
| `distancia_max` ≤ 8 | `:329` | sí | 0 |
| `persiste + permanencia` ≤ 25 | `:330-331` | sí | 0 |
| `copias` ≤ 8 | `:332` | sí | 0 |
| **glifos por hechizo = 6 = «los huecos de la página»** | `Hechizo.MAX_GLIFOS` 6 (`:54`): solo lo usa el lab (`lab_hechizos_3d.gd:1422`) | **no** | La lámina «bosque», la única del juego, tiene **3 huecos** (`spellbook.gd:133-134`, `prueba_libro_bosque.gd:61-62`) y la regla es 1 glifo por hueco (`grimorio.gd:474`). **El jugador lanza 3 glifos como máximo**. `max_sigils_per_page` = 6 en el kit «pruebas» y 2 en «bosque» (`lanzador_3d.gd:97`, `:102`). La paleta F1 sube el límite a 8 (`rune_palette.gd:118`), pero sigue habiendo solo 3 huecos. |
| profundidad 2 / 32 vivos | `hechizo.gd:45-46`; `hechizo_vivo.gd:864`, `:873` | sí (lo cubre `prueba_hechizo_vivo`) | — |

### §2 Lo que aporta cada elemento (valores reales de los `.tres`)

| | fuego | agua | tierra | hielo | rayo | viento | tiempo |
|---|---|---|---|---|---|---|---|
| estado | plasma ✓ | liquido ✓ | solido ✓ | solido ✓ | energia ✓ | gas ✓ | campo ✓ |
| damage (→ `dano`) | 50 ✓ | 40 ✓ | 0 + 18 `suma` = 18 ✓ | 20 ✓ | 55 ✓ | 0 ✓ (por defecto) | 0 ✓ |
| persiste | 3 ✓ | 0 ✓ | 8 ✓ | 6 ✓ | 0,2 ✓ | 1,5 ✓ | 4 ✓ |
| gravedad | 0 ✓ | 0,5 ✓ | 1 ✓ | 1 ✓ | 0 ✓ | 0 ✓ | 0 ✓ |
| densidad | 0,2 ✓ | 1 ✓ | 2 ✓ | 0,9 ✓ | 0 ✓ | 0,1 ✓ | 0 ✓ |
| temperatura | 1 ✓ | 0 ✓ | 0 ✓ | −1 ✓ | 0 ✓ | 0 ✓ | 0 ✓ |
| humedad | 0 ✓ | 1 ✓ | 0,2 ✓ | 0,5 ✓ | 0 ✓ | 0 ✓ | 0 ✓ |
| conductividad | 0 ✓ | 0,3 ✓ | 0 ✓ | 0 ✓ | 1 ✓ | 0 ✓ | 0 ✓ |
| impulso_salida | — | 1,6 | — | — | — | — | — |
| empuje (RuneData) | 0,2 | 0,5 | 0,8 | 0,2 | 0,2 | 1,0 | 0 |
| estado al golpear | quema 3 | moja 6 | ralentiza 3 / fuerza 0,4 | congela 1,5 / mojado 2,5 | aturde 1,2 | interrumpe 0,7 | — |
| fuerza_golpe | 500 | 600 | 2200 | 300 | 400 | 0 | (400) |
| deja / pisable | quemado / no | mojado / no | — / **sí** | helado / **sí** | — / no | — / no | — / no |

Todos los valores de §2 **coinciden** (`prueba_hechizo` `_espec_e1` también lo comprueba). La ESPEC no da valores de `impulso_salida`, `empuje` ni de los estados; los de arriba son los del `.tres`.

**Se ejecuta en todas las figuras** (barrido B, 1 716 ejecuciones reales de `HechizoVivo.crear`): las 5 materias jugables × {haz, proyectil, volumen quieto} corrieron con casillas > 0 en las 15 parejas. Las únicas excepciones son los 2 rechazos de un sólido de 2 niveles: tierra o hielo con ᛏᛏᛏ, que el juego no deja lanzar (`MAX_NIVELES_SUBIBLES` = 1).

**Lo que no se ejecuta como manda el elemento:** la gravedad 1 de tierra y hielo **sin `impulso_salida`** hace que su flecha **caiga al suelo a 0,70 casillas** de las 2 de alcance (0,43 si sale de la mano real de la jugadora, 0,40 u). Medido en `depurar_salida.txt`. Es el mismo problema que tenía el agua en la entrada 239 del diario, que se arregló solo para el agua.

### §3 Glifos (`Sigils.GLIFOS`, `sigils.gd:374-398`)

| glifo | espec | código | ¿cumple? | momento / paso |
|---|---|---|---|---|
| `linea_x` | `semieje_x` +0,25, tope 3; sin barrera ni flecha = haz | +0,25 tope 3; `haz` (`hechizo.gd:252-254`) | sí | inicio / 1 |
| `linea_z` | `semieje_z` +0,10, tope 3; haz | ídem | sí | inicio / 1 |
| `altura` (alias `levitacion`) | `semieje_y` +0,30, tope 1 | ídem (`ALIAS_V2`, `sigils.gd:433`) | sí | inicio / 1 |
| `flecha` | velocidad 4 u/s (1,74 m/s); distancia 2 + 1, tope 6 | ídem | sí. **`GLIFOS_RECETA.md:75` sigue diciendo «+3»** | continuo / 3 |
| `barrera` | solidez 1·1,5ⁿ, tope 3; `en_punto`; +1 s de permanencia por glifo sucesivo | ídem | sí | continuo / 4 |
| `repeticion` | copias +1, tope 4 | ídem | construye sí; **ejecuta parcial** (D-1) | inicio / 2 |
| `rebote` | rebotes +1, tope 3 | ídem | sí (proyectil); en el haz no hace nada (ESPEC) | final / 3 |
| `pulso` (ᚷ, «crecer») | crece +0,5 m/s, tope 1,5 | +0,5 tope 1,5, **aplicado como escala/s** | parcial (§1.3) | continuo / 3 |
| `permanencia` (ᛉ) | +2 s, tope 25 | ídem | construye sí; **no se puede dibujar ni está en ningún kit** (C-1) | final / 3 |
| `raido` (ᚱ, «pulso») | resuena +4, tope 12 (PLAN_PULSO §2) | ídem; `accion: emitir_pulso`, `momento_si` | sí. **No se puede dibujar** (C-1) | inicio, o final si viaja, o continuo si persistente / 5 |
| aparcados (`retardo`, `atraccion`, `espejo`, `amplificar`) | — | van a `ignorados` + aviso «Aún sin uso» (`lanzador_3d.gd:786-788`, `:2426`) | sí | — |

Momento de ᚱ medido por figura, en el barrido A (combinaciones con ᚱ):
- haz/inicio 4 950
- proyectil/final 4 290
- barrera/continuo 4 290
- barrera/final 1 716 (barrera + flecha, que viaja)
- esfera/inicio 504 · esfera/continuo 1 008 (tierra y hielo: sólido = persistente)
- pulso/inicio 504 · pulso/continuo 756

El momento final del proyectil, el continuo del volumen quieto y el inicio del haz **sueltan el `Pulso3D`** en el 100 % de las 396 ejecuciones del barrido B.

**Coste del ᚱ continuo:** 504 combinaciones son «ᚱ continuo sin recargo de tinta» (tierra o hielo sin barrera ni permanencia). Es el «límite conocido» de `GLIFOS_RECETA.md:144`.

### §3b Haz

| regla | código | ¿cumple? |
|---|---|---|
| alcance 3 + 1 por ᛁ, tope 6 | `hechizo.gd:61-63`, `:256-260` | sí (0 casos de más de 8 en el barrido) |
| ancho 0,35 y 0,9 s (+ `permanencia`) | `:64-65`; `hechizo_vivo.gd:263` | sí |
| instantáneo, perfora, se para en sólidos y barreras | `hechizo_vivo.gd:243` (`camino` con `atraviesa = true`, que pasa por `trazar` → `_barrera_en`) | sí |
| deja el estado de suelo y golpea una vez; la energía usa la descarga | `:281-292` | sí |
| copias, rebotes y crece no cambian el haz | — | sí (es lo que dice la ESPEC). Aun así son **4 950 combinaciones de cada tipo** en las que el glifo cuesta tinta y recarga sin hacer nada. |
| con barrera es muro y con flecha es proyectil | `hechizo.gd:254` | sí (`prueba_haz` 82 OK) |

---

## B. Cobertura de combinaciones (barrido medido)

- **Glifos reales** (`Sigils.GLIFOS`, 10): `linea_x`, `linea_z`, `altura`, `flecha`, `barrera`, `repeticion`, `rebote`, `pulso`, `permanencia`, `raido`.
- **Elementos jugables** (6): fuego, agua, tierra, hielo, rayo, viento. El tiempo devuelve `null` sin permiso y un hechizo con permiso (comprobado).

### Parte A · construir

Se construyeron las **8 008 combinaciones de 0 a 6 glifos × 6 elementos = 48 048 hechizos**. Resultados:

- `null`: 0.
- Límites de §1.9: 0 violaciones.
- `figura()` y `forma` fuera de su conjunto: 0.
- `coste_tinta` NaN, infinito o mayor que 100: 0.
- `niveles` > 2: 0.
- `copiar()` y `copiar().con({})` reproducen todos los números de `a_diccionario()` en los 48 048 casos.
- `Receta3D` (el camino del libro: tinta, recarga, forma) da lo mismo que `Hechizo` en los 48 048 casos.
- **El único «fallo»:** `recarga` = 0 en las 6 páginas sin glifos (`Sigils.cooldown_v2({})`). El libro no las deja lanzar.

Reparto:
- **Por figura:** barrera 18 018 · haz 12 474 · proyectil 12 012 · esfera 2 772 · pulso 2 772. Es idéntico para cada elemento (3 003 / 2 079 / 2 002 / 462 / 462).
- **Por forma:** x_mano 38 394 · alto 6 732 · abajo 2 922.
- **Lanzables desde el libro** (3 glifos como máximo y solo de los 8 dibujables): **990** = 165 recetas × 6. Por figura: haz 294, barrera 270, proyectil 216, esfera 120, pulso 90.

Combinaciones «raras»:

| clase | casos | ejemplo |
|---|---|---|
| coste en el tope (100 = toda la barra de partida) | 19 608 (114 lanzables desde el libro) | fuego `linea_x`×4 (con la base 0,10 el coste crece ×15; ya anotado en `PENDIENTES.md:148` y en la entrada 249 del diario) |
| barrera + flecha: `figura()` dice barrera y se ejecuta como proyectil | 6 006 | `linea_x`×4 + flecha + barrera |
| proyectil con copias (sale **un** proyectil) | 6 006 | flecha + repetición |
| proyectil con crece (no crece) | 6 006 | flecha + pulso |
| haz con copias / con rebotes / con crece (no hacen nada, pero cuestan) | 4 950 de cada | `linea_x`×5 + repetición |
| barrera + rebote quieta (refleja) | 4 290 | — |
| sólido de 2 niveles: `construir()` lo da por bueno; `cast_page` y `HechizoVivo` lo rechazan | 572 (**2** lanzables desde el libro: tierra y hielo con ᛏᛏᛏ) | — |
| ᚱ continuo sin recargo de tinta | 504 | tierra con ᛏ×5 + ᚱ |
| vida recortada a 25 s | 0 en el barrido (necesita más de 6 glifos) | — |

### Parte B · ejecutar

Se ejecutaron **286 combinaciones de 0 a 3 glifos × 6 = 1 716** con `HechizoVivo.crear` en un mundo falso de 20×20, con `AguaSim`. Los proyectiles se avanzaron a mano hasta que acabaron.

- **Ramas:** volumen quieto 834 · haz 486 · proyectil 396 (cada materia en las tres; sólido = tierra + hielo, por eso cuenta doble). Volumen que viaja: **0**.
- **Rechazados (casillas = 0):** solo los 2 sólidos de 2 niveles.
- **Solidez** → `SolidezV2` creada: 396 de 396. En el proyectil se crea al impactar.
- **ᚱ:** suelta el pulso en 396 de 396.
- **Proyectiles:** 274 acaban por «alcance» y **122 por «suelo»**. Los de «suelo» son las flechas de tierra y de hielo (ver §2).
- **Rebotes** en proyectil: 23 de 66 rebotaron. En una sala de 20 casillas con alcance ≤ 4 la mayoría no llega a la pared, así que no es un fallo.
- **Copias no ejecutadas: 348.**
  - proyectil: 66 de 66 (siempre 1);
  - haz: 102 de 102 (lo dice la ESPEC);
  - volumen quieto: 180. Con un número par de copias y separación de 1 casilla, los centros quedan en el borde entre casillas y se rasterizan en la misma. Medido en `depurar_salida.txt`: ᚠ ×1 da **1** casilla en vez de 2, y ᚠ ×3 (4 copias) da **3**.
- **Crece sin efecto en las casillas: 390** (todas las combinaciones con ᚷ y 3 glifos o menos).

---

## C. Ejecución en el juego (cadena real del libro)

La cadena es:
1. `spellbook.gd` → `Lanzador3D.add_gesture` (`lanzador_3d.gd:672`) → `Grimorio.add_gesture` / `add_sigil` (`grimorio.gd:442-488`: runa activa, presupuesto `max_sigils_per_page`, 1 glifo por hueco);
2. `cast_current` → `cast_page` (`lanzador_3d.gd:728-805`) → `Receta3D.apply` → `Hechizo.construir` (para `en_punto`, `:804`) → modo lanzar;
3. `_soltar` → `lanzar_ahora` (cobra tinta y recarga, `:1016-1021`) → `_conjurar_punto` / `_conjurar` → `_disparar` (`:1169`) → `receta.hechizo(rune)` → pigmento → `_salida_de_mano` → `lanzar_hechizo` → `HechizoVivo.crear` → `_materializar_haz` / `_iniciar_proyectil` / `_materializar` → `_vivir` → `MATERIA_V2` + `_solidez` + momentos + eventos.

**C-1. Qué puede DIBUJAR hoy el jugador.** Nivel de arranque: `run/main_scene = escenas/PruebaBosque01_v01.tscn` (`project.godot:14`), con `kit = "pruebas"` (`PruebaBosque01_v01.tscn:13`).

- **Sellos:** los 6 (`lanzador_3d.gd:105`).
- **Glifos activos:** flecha, barrera, linea, altura, levitacion, repeticion, rebote, pulso (`:106`). **No están `permanencia` ni `raido`.**
- **Muestras en `gesture_library.tres`:** 13 gestos, 55 muestras: flecha 8, barrera 4, levitacion 3, linea 3, pulso 6, rebote 3, repeticion 6; elementos: fuego 5, agua 5, hielo 3, rayo 3, tierra 3, viento 3.
  - **Sin muestras:** `permanencia`, `raido` y `altura`. `altura` se dibuja como `levitacion`, que es su alias.
- **Consecuencias:**
  - ᛉ no se puede usar en el juego de ninguna forma, salvo con el botón F1 «Añadir todos» (`rune_palette.gd:117`).
  - ᚱ **se consigue** en el cofre legendario de la Cueva (`objetos/secuencia_cofre_legendario_3d.gd:593`, `conseguir_sigil`), **pero no se puede trazar** (no tiene plantillas). Hasta que Pablo grabe sus muestras con G, solo se coloca con la paleta.
- **Páginas:** 3. Glifos por página: 6 de presupuesto, pero **solo 3 huecos** (lámina «bosque»). El kit «bosque» (sin `kit`) da fuego + flecha y 2 glifos.

**C-2. Lo que `cast_page` rechaza antes de lanzar:**
- página sin elemento o con un elemento inactivo;
- **página sin glifos** («le falta algún glifo», `:747`; también `grimorio.gd:656`): la «esfera sin glifos» de `ARQUITECTURA.md:254` **no se puede lanzar desde el libro**;
- recarga pendiente;
- glifo inactivo;
- **sólido con más de 1 nivel** (`GeometriaV2.aviso_materia`, `:779`): tierra o hielo con ᛏᛏᛏ (2 de las 990 lanzables). La «columna de hielo de 2 niveles» de `GLIFOS_RECETA.md:122` **no existe**: 2 ᛏ dan 1 nivel y 3 ᛏ se rechazan;
- **tinta insuficiente** (`:792-799`): 114 de las 990 cuestan 100, que es la barra de partida entera;
- `MAX_GLIFOS` **no se comprueba** en `cast_page`.

Los glifos aparcados no se rechazan: se avisa «Aún sin uso» y se lanza igual.

**C-3. Ramas de HechizoVivo por figura y estado:**
- `MATERIA_V2` cubre los 6 estados (`hechizo_vivo.gd:23-26`); `ESTADO_RESERVA_V2` = campo para un estado desconocido (`:21`, `:152`).
- No hay `push_warning` ni «aún sin uso» en `hechizo_vivo.gd`.
- Retornos tempranos: el aviso de altura (`:171-173`) y el haz contra una pared (devuelve 1 como mínimo, `:276`).
- **Lo que falta o no se ejecuta:**
  1. copias en el proyectil;
  2. crece en el proyectil, y el crece «en m/s»;
  3. retardo en el proyectil y en el haz;
  4. `elasticidad` en el rebote;
  5. el choque del proyectil con `SolidezV2` (y la reflexión de barrera + rebote contra flechas);
  6. la rama «volumen que viaja», inalcanzable desde los glifos;
  7. la altura total de §1.9.

**C-4. Código preparado sin dato y dato sin código:**
- **Código sin ningún glifo ni `.tres` que lo alimente** (solo lab o `con()`):
  - `aceleracion`, `elevacion`, `retardo`, `retorna`, `busca`, `perfora`, `radio_explosion`, `golpea_lanzador`, `veneno`/`veneno_dps`, `choca_con`, `estela`, `efecto_impacto`;
  - **todos los `eventos`**: los 6 eventos y las 5 acciones (ningún glifo trae `op: "anade"`);
  - `curar_lanzador` de `HECHIZO_CLASE.md:125` ni siquiera existe.
- **Datos que nadie lee:**
  - `potencia`, `intensidad_estado`, `elasticidad`, `ralentiza_fuerza`;
  - `densidad`, `masa`, `temperatura`, `humedad`, `conductividad` (permitido por la ESPEC);
  - `Hechizo.empuje`, `Hechizo.deja`, `Hechizo.pisable` y `Hechizo.color`: se leen del RuneData, así que si se tocan en el lab no pasa nada;
  - `volumen`, `superficie`, los 6 estados de §1.7 y `figura()`.

**C-5. Pruebas existentes** (ejecutadas hoy; todas con **FALLOS 0**):

| prueba | resultado | qué cubre | hueco |
|---|---|---|---|
| `prueba_hechizo` | 1 001 combinaciones × 6 × 2 calidades, 276 622 comparaciones, 0. Los 4 fallos de la entrada 249 del diario ya no salen. | construir = camino viejo, hasta **4** glifos | no llega a 5–6 glifos; la altura total de §1.9 no se mira |
| `prueba_receta_v2` | 1 001 × 6, 0 | receta y materia por tandas | **fuerza `velocidad = 0`** (`prueba_receta_v2.gd:374`) para probar copias y viaje: el «abanico de 3 bolas de hielo» (`:572`) **no es lo que pasa en el juego** |
| `prueba_hechizo_vivo` | 76 OK, 0 | cada campo de HC4 y los eventos, con `con()` | no prueba las copias en el proyectil |
| `prueba_materia_v2` | 205 OK, 0 | 6 estados × 4 volúmenes | apaga el haz (`HAZ_ACTIVO = false`) y usa 6–8 glifos, que el libro no permite |
| `prueba_haz` | 82 OK, 0 | haz por elemento | — |
| `prueba_tamano_proyectil` | 54 OK, 0 | tamaño en vuelo | 2 errores de `_dibujar_proyectil` diferido con el objeto liberado (`vfx_estado_3d.gd`) |
| `prueba_pulso` | 71 OK, 0 | ᚱ y su momento | — |
| `prueba_golpe` | 18 montajes, 0 | Combate3D | — |
| `prueba_cast_points` | 146 OK, 0 | camino real `cast_page` + soltar, **solo con flecha** | no prueba barrera + flecha con esqueleto (D-5). Lanza 5 «Tween started with no Tweeners» (ConjuroVfx3D) |
| `escenario_lab_hechizos` | 270 OK, 0 | lab | — |

**Ninguna prueba lanza las combinaciones por el libro real.** `escenario_libro`, `escenario_conjuro`, `prueba_cast_points` y `escenario_base.lanzar` pasan por `cast_page` / `lanzar_pagina_ya`, pero con un puñado de recetas (flecha, ᛜ+ᛁ, ᛜ+flecha). Ninguna recorre las 165 recetas lanzables × 6, ni el reconocimiento de gestos (`escenario_libro.gd:6` lo excluye expresamente).

---

## D. Lista final ordenada

### Incumplimientos (de más a menos bloqueante)

1. **D-1 · ᚠ repetición no se ejecuta en el proyectil y falla con un número par de copias en los volúmenes.**
   - flecha + ᚠ = **1** proyectil (6 006 combinaciones; 66 de 66 ejecutadas). Ver `hechizo_vivo.gd:123-124`, `:898-920`.
   - ᚠ ×1 en una esfera da **1** casilla en vez de 2 y ᚠ ×3 da 3 en vez de 4 (`hechizo_vivo.gd:372-378`: la separación mínima de 1 casilla con desplazamiento ±0,5 cae en el borde de la casilla).
   - `GLIFOS_RECETA.md:126` promete «tres bolas de hielo en abanico», y `prueba_receta_v2.gd:572` solo lo consigue forzando `velocidad = 0`.
2. **D-2 · El Sello tierra y el Sello hielo: su flecha cae a 0,70 casillas de 2** (0,43 desde la mano real). Causa: `gravedad` 1 y `impulso_salida` 0 en `earth_rune.tres` y `ice_rune.tres`. El agua se arregló con `impulso_salida` 1,6 (diario 239); tierra y hielo no.
3. **D-3 · El libro admite 3 glifos, no 6.** `Hechizo.MAX_GLIFOS = 6` dice ser «los huecos de la página», pero la lámina «bosque» tiene 3 y la regla es 1 glifo por hueco (`spellbook.gd:133-134`, `grimorio.gd:474`). De 48 048 combinaciones, solo **990** son lanzables por el jugador. Además, ᛉ y ᚱ **no se pueden dibujar** (no tienen muestras) y ᛉ no está en ningún kit.
4. **D-4 · §0.3 contradice al código.** La flecha deja su materia con `persiste` al pararse (`hechizo_vivo.gd:1208`); la ESPEC dice que no. Hay que actualizar la ESPEC (entrada 191 del diario) o el código.
5. **D-5 · Barrera + flecha con esqueleto nace en la mano, no en el punto apuntado** (*a verificar en pantalla*). `cast_page` fija el origen en el punto (`lanzador_3d.gd:924-928`), pero `_salida_de_mano(hechizo, origen)` devuelve mano − origen (`:1214`) y `_iniciar_proyectil` lo suma (`hechizo_vivo.gd:904-905`). Lo trajo el commit E2 `7a91ea36`. No hay prueba.
6. **D-6 · El proyectil no se para en una `SolidezV2`** (§1.2) y la reflexión de barrera + rebote no afecta a las flechas, ni a las del jugador ni a las de los goblins (`combate_3d.gd:1136` solo para). `hechizo_vivo.gd:1029-1054` frente a `lanzador_3d.gd:1573`.
7. **D-7 · `crece` en escala/s y no en m/s** (§1.3). Con 3 glifos o menos **nunca cambia una casilla** (390 de 390): ᚷ solo cambia el VFX. Tampoco hace nada en el proyectil.
8. **D-8 · `resistencia` = 30 × solidez** frente a «10» en la ESPEC §1.4 (`hechizo.gd:73`). Falta una decisión de Pablo escrita en la ESPEC.
9. **D-9 · Falta el límite de altura total** (`elevacion` + 2·Y ≤ 2 niveles) en `_limitar` (§1.9).
10. **D-10 · `figura()` no coincide con lo que se ejecuta** para barrera + flecha (6 006 casos), y ningún sistema del juego la usa (el VFX decide por su cuenta).
11. **D-11 · Coste en el tope:** 19 608 de 48 048 (114 de las 990 del libro) cuestan la barra entera. Está pendiente (`PENDIENTES.md:148`).
12. **D-12 · Documentos desfasados:**
    - `ARQUITECTURA.md:176-177` (pasos +0,15);
    - `GLIFOS_RECETA.md:75` (flecha +3), `:79` («escala/s», que contradice la ESPEC), `:122` (pilar de hielo de 2 niveles), `:126` (abanico);
    - `HECHIZO_CLASE.md:61` (solidez 1), `:80` (daño × calidad);
    - comentario de `hechizo.gd:18` («aún no lo lee nadie») y de `:136`;
    - `PENDIENTES.md:103`, ya resuelto;
    - `ARQUITECTURA.md:254`: la esfera sin glifos no se puede lanzar desde el libro.

### Campos muertos

- **Solo dato:** `potencia`, `intensidad_estado`, `elasticidad`, `ralentiza_fuerza`, `densidad`, `masa`, `temperatura`, `humedad`, `conductividad`, `volumen`, `superficie`, `flota`, `anclado`, `protege`, `se_expande`, `se_repite`, `rebota`, `figura()`.
- **Sombra del RuneData** (se lee el RuneData y no el Hechizo): `empuje`, `deja`, `pisable`, `color`.
- **Solo lab** (ningún glifo ni `.tres` los produce): `aceleracion`, `elevacion`, `retardo`, `retorna`, `busca`, `perfora`, `radio_explosion`, `golpea_lanzador`, `veneno`, `veneno_dps`, `choca_con`, `estela`, `efecto_impacto`, `eventos` (6 eventos y 5 acciones).

### Combinaciones que no se ejecutan como dicen los datos

| combinación | qué pasa |
|---|---|
| flecha + ᚠ | 1 proyectil |
| flecha + ᚷ | no crece |
| ᚠ par en volumen | copias solapadas |
| ᛁ + ᚠ / ᚢ / ᚷ | el haz las ignora; lo dice la ESPEC, pero cobran tinta y recarga |
| ᚷ con 3 glifos o menos | sin efecto en el juego |
| flecha de tierra o hielo | cae al suelo |
| barrera + flecha | `figura` barrera, ejecución proyectil, posible origen en la mano |
| ᛜ + ᚢ | refleja solo el haz y los volúmenes que viajan (inalcanzables), no las flechas |
| tierra o hielo con ᛏᛏᛏ | rechazado |
| la rama «volumen que viaja» | inalcanzable |
| ᛉ, ᚱ | no dibujables |

### Pruebas nuevas propuestas (para que «todas se construyen y se ejecutan» quede medido en `tools/pruebas.cmd`, que recoge cualquier `herramientas/prueba_*.gd`)

1. **`prueba_barrido_hechizos`** (la parte A de `barrido_hechizos.gd`). Para las 8 008 × 6 afirma:
   - no es `null`; respeta los límites de §1.9, **incluida la altura total**;
   - `figura` y `forma` son válidas; el coste es finito y ≤ `Tinta.MAXIMA`;
   - la recarga es > 0 salvo en la página vacía;
   - `copiar()` y `con({})` son idénticos a `a_diccionario()`;
   - `Receta3D` == `Hechizo` (tinta, recarga, forma);
   - `figura()` coincide con la rama que ejecuta HechizoVivo.

   Hoy fallaría por D-9 (si se prueba con `con`) y D-10.
2. **`prueba_ejecucion_combinaciones`** (la parte B). Para las 165 recetas lanzables × 6 sellos con `HechizoVivo.crear` afirma:
   - casillas > 0 salvo el aviso de altura;
   - **copias vistas == copias** (volumen y proyectil);
   - solidez → `SolidezV2`;
   - ᚱ suelta su pulso en su momento;
   - **cada flecha recorre al menos el 80 % de `distancia_max` o acaba en un obstáculo, nunca «suelo» en terreno llano**;
   - ᚷ cambia algo medible (o se declara «solo VFX» en una lista).

   Hoy fallaría por D-1, D-2 y D-7.
3. **`escenario_libro_combinaciones`**: en `PruebaBosque01_v01` con el kit «pruebas», por `place_sigil` + `lanzar_pagina_ya`. Las 165 recetas × 6: o sale (manifestaciones > 0) o se rechaza con un aviso conocido (altura, tinta); se cuentan las dos cosas. También comprueba que ninguna página pasa de los huecos abiertos.
4. **`prueba_glifos_dibujables`**: cada glifo activo en algún kit, o conseguible en un cofre, tiene **≥ 3 muestras** en `gesture_library.tres` y lo reconoce `GestureRecognizer` (con sus propias muestras ligeramente deformadas). Hoy fallaría por `raido`; además señalaría que `permanencia` no está en ningún kit.
5. **`prueba_campos_ejecutados`**: para cada campo de `Hechizo.CAMPOS`, un `con({campo: valor ≠ defecto})` produce una diferencia observable en HechizoVivo o Combate3D, o el campo figura en una lista explícita `CAMPOS_SOLO_DATO` dentro de la prueba. Así ningún campo queda muerto sin que se diga.
6. **`prueba_en_punto_proyectil`**: barrera + flecha por `lanzar_ahora` con un jugador con esqueleto. Afirma el origen que decida Pablo: el punto apuntado o la mano (D-5).
