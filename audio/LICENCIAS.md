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
