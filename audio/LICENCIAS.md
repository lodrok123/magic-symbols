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

## Cómo cambiar uno

Copiar el archivo nuevo en `audio/` y tocar su línea en `CATALOGO`
(`sfx.gd`). Nada más: ningún sitio que llame a `Sfx.play()` sabe qué
archivo hay detrás ni en qué formato.
