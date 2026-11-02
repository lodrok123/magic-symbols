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
(CC0, 2 $, el único con goblin, gólem y goo). Los bundles GDC de Sonniss (gratis, sin atribución, sin redistribuir) no caben en el disco.
