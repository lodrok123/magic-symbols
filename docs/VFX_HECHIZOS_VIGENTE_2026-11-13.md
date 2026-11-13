# VFX de hechizos: cómo se dibuja hoy (13/11/2026)

La guía de entrada al dibujo de los hechizos. Sustituye, como descripción de lo que hay, a los apartados 7 y 7 bis de `COMO_SE_GENERA_UN_HECHIZO.md`, que se quedaron en el 7/11 (antes del gas, el humo por regla y las chispas). La cadena de la lógica (glifos → `Hechizo` → `HechizoVivo`) sigue estando allí y no se repite aquí.

Qué casilla dibuja quién, elemento por elemento, está en `VFX_MATRIZ_COBERTURA_2026-11-13.md`.

Escrita leyendo el código del 13/11 (`main`, bd03f739). No se ha lanzado el juego para comprobarla.

## 1. La regla

**La lógica decide, el VFX representa.** El dibujo solo escucha: no decide daño, alcance, tamaño ni duración. Si hay que cambiar lo que pasa, se cambia la lógica.

## 2. Tres capas

| capa | qué es | dónde |
|---|---|---|
| 1. Enganche | escucha al lanzador y al mundo, y crea el dibujo que toque | `presentacion/vfx_toy_juego.gd` (`VfxToyJuego`) |
| 2. Toy del elemento | la geometría, construida por código a partir de figura y semiejes | `presentacion/vfx/toy/<elemento>_toy.gd` y sus `impacto_<elemento>_toy.gd` |
| 3. Capas añadidas | efectos que se suman al toy, cada uno con su interruptor | `haz_gas_juego.gd`, `humo_regla.gd`, `chispas_repo.gd`, `campo_viento.gd`, `haz_choque.gd` |

Debajo de todo sigue el **dibujo antiguo** (`VfxElemento3D`, con las piezas de `presentacion/vfx_elementos/`), que se calla para los elementos que tienen el toy encendido.

El **tiempo** queda fuera de todo esto (decisión de Pablo, 13/11): es un elemento cinemático, de historia, y no tendrá toy ni entrará en `vfx_procedural_elementos`.

## 3. Qué escucha el enganche

| señal | de quién | qué hace |
|---|---|---|
| `conjuro_fase("forma")` | `Lanzador3D` | `empezar_carga`: la bola crece en la mano. Rayo y viento, con su versión revisada, empiezan antes, en la fase «voluta» (`usa_cast_propio`) |
| `child_entered_tree` con un `HechizoVivo` que es proyectil y no haz | `Lanzador3D` | proyectil: suelta la bola de la mano (o crea un toy) y sigue su posición, su dirección y su tamaño |
| `terminado(causa, pos, normal, material)` | `HechizoVivo` | `finalizar`: impacto con la normal, fin sin choque o cancelación, según la causa |
| `rebotado(pos, normal)` | `HechizoVivo` | `rebotar` |
| `hechizo_v2(estado, elemento, g, origen, dir, props)` | `Lanzador3D` | todo lo que no viaja como proyectil (apartado 4) |
| `tierra_deshecha(c)` | `Lanzador3D` | el `TierraToy` que cubría esa casilla se hunde |
| `plataforma_tierra_lanzada` | `Lanzador3D` | retira la carga de la mano |
| `cambio(c, "electrificada", si)` | `Terreno3D.estados` | pone o quita un `EstadoRayoToy` de superficie en la casilla |
| `reaccion("electrocutado", punto, nodo)` | `Mundo3D` | cuelga un `EstadoRayoToy` de la entidad |

`hechizo_v2` no trae el `Hechizo`: el enganche usa el último `HechizoVivo` que entró en el lanzador. Si no lo encuentra, no dibuja nada.

## 4. Del `Hechizo` a la figura

Lo que decide por dónde va el dibujo, en el orden en que lo mira `_en_hechizo`:

| lo que dice la lógica | camino | qué se dibuja |
|---|---|---|
| `proyectil` y no `haz` | `_proyectil` | BOLA que sigue al `HechizoVivo` |
| `g.haz` | `_haz` | HAZ del punto de salida a la punta real. El largo es el recorrido que calculó la lógica |
| `g.orbita` | `_orbes` | una BOLA por orbe, que sigue `HechizoVivo.orbes[i]` |
| `g.viaja` con ruta | `_volumen_que_viaja` | un toy por copia que recorre los eventos de tiempo |
| tierra sólida con `g.celdas` y niveles | `_tierra_sobre_celdas` | un `TierraToy` dimensionado a las casillas reales |
| lo demás | `_volumen` | la figura que diga `desde_hechizo(h)`, una por sitio |

Datos del volumen que modifican el dibujo:

- `g.estalla`: la vida es el tiempo hasta el estallido, y el radio del impacto en área es el de la lógica.
- `g.columna`: el pilar crece de abajo arriba escalando su Y en el tiempo que dice la lógica.
- `crece` en un proyectil: la bola nace pequeña y llega a su tamaño en vuelo.
- `g.haz.choques`: puntos y normales donde el haz choca. Se pasan al toy y al gas.
- `HazGas.escala_de(h)`: grosor del haz y de su choque, de 0,5 con una ᛁ a 1 con el máximo de glifos.
- meta `ritmo_nacer_vfx` en el `Hechizo`: velocidad del «nacer» (la usa el dragón de pared).

**Lo que hoy no tiene un camino propio en `VfxToyJuego`:** la barrera que late (ᛝ antes de ᚷ), ᚦ perforar, ᚨ buscar, el retardo y el raído. Puede que se lean por otras vías (la propia lógica repite golpes o cambia la ruta), pero no hay nada en el enganche que las dibuje de forma distinta. Está sin revisar a fondo.

## 5. El toy

Todos comparten la API y las cinco figuras (`BOLA`, `MURO`, `PILAR`, `BARRERA`, `HAZ`):

```gdscript
definir(figura, x, y, z, vuela)   # semiejes en metros
desde_hechizo(h)                  # figura, tamaños y vuelo salen del Hechizo
lanzar(vida)
empezar_carga(duracion, tam) → soltar(dir) | cancelar_carga()
impactar_en(pos, normal) · rebotar(pos, normal) · terminar_sin_choque() · finalizar(motivo, pos, normal)
```

- La base es `EfectoToy` (los diez mandos) sobre `EfectoVfx3D` (`preparar` / `lanzar` / `morir`, con «nacer», «vivir» y «morir»).
- La escala y la figura salen de `FuegoToy.describir(h)` para todos: un hechizo cambia de elemento sin cambiar de tamaño.
- La máquina de carga e impacto está **copiada** de un toy a otro, no compartida. Un arreglo en una hay que llevarlo a las demás.
- Origen: la bola por su centro; muro, pilar y barrera apoyados en el suelo; el haz sale hacia −Z.

## 6. El haz tiene dos dibujantes

Con GPU (Forward+ o Mobile, no Compatibility ni `--headless`) y su ajuste encendido, el haz lo dibuja el gas (`HazGasJuego`). El toy se crea igual, porque lleva la luz y la vida, pero se le quita lo que el gas ya dibuja:

| elemento | qué queda del toy |
|---|---|
| fuego | la luz del suelo y la del hechizo (`solo_luz`) |
| rayo | las luces (`solo_luces`) |
| agua | nada visible (`ocultar_toy`) |
| viento | nada visible (`ocultar_toy`) |
| magma, tierra | no usan gas: púas |

Si no hay GPU, el ajuste está apagado o ya hay `MAX_INSTANCIAS` (2) dominios vivos, sale el HAZ del toy de siempre. Ese es el plan B y tiene que seguir viéndose bien.

Un haz nuevo que sale casi del mismo sitio y con el mismo tamaño reutiliza el dominio vivo. Un haz de rayo de 0,2 s o menos se dibuja como un solo destello.

## 7. Las capas añadidas

| capa | qué añade | interruptor | de serie |
|---|---|---|---|
| `HumoRegla` | humo, vapor, polvo y humo de magma, por bocanadas en CPU | `HumoRegla.capas` | encendidas: `impacto_bola`, `barril`, `suelo`, `vapor`, `magma`. Apagadas: `muro`, `pilar`, `haz`, `dragon`, `polvo_tierra`, `polvo_viento` |
| `ChispasRepo` | chispas con vidas escalonadas, inercia y rebote | `ChispasRepo.capas` | todas encendidas: `rayo_impacto`, `rayo_pilar`, `rayo_proyectil`, `electrificado`, `electrificado_capsula`, `magma_impacto`, `magma_proyectil` |
| `CampoViento` | un solo campo de flujo para hojas, jirones y cintas | `vfx_campo_viento` | encendido |
| `HazChoque` | el haz de agua y el de rayo envuelven lo que golpean | con el toy | — |
| `EstadoRayoToy` | el estado electrificado, en entidad y en superficie | con el toy de rayo | — |

Una capa apagada deja el efecto exactamente como estaba. Es la forma de enseñar algo nuevo sin tocar lo validado.

## 8. Ajustes

Todos en `[magic_symbols]` de `project.godot`:

| ajuste | valor hoy | qué hace |
|---|---|---|
| `vfx_procedural` | true | enciende los toys |
| `vfx_procedural_elementos` | `fuego,agua,rayo,magma,viento,tierra` | para qué elementos. El hielo no está |
| `vfx_haz_gas` | true | gas en el haz de fuego |
| `vfx_haz_gas_agua` | true | gas en el haz de agua |
| `vfx_haz_gas_viento` | true | gas en el haz de viento |
| `vfx_haz_gas_rayo` | true | gas en el haz de rayo |
| `vfx_rayo_revisado` | true | la versión revisada del rayo |
| `vfx_viento_revisado` | true | el viento de cintas (`viento_corrientes.gd`) |

Sin entrada en `project.godot`, con el valor por defecto del código: `vfx_campo_viento`, `vfx_veneno_gas_pesado` y `vfx_veneno_humo` (los tres true; los dos últimos los lee `nube_veneno_vfx.gd`).

## 9. Presupuesto

| tope | valor | dónde |
|---|---|---|
| toys vivos | 12 | `VfxToyJuego.MAX_VIVOS` |
| luces por hechizo | 1 (las copias la apagan) | `_sin_luz` |
| copias de un volumen que se dibujan | 4 | `SITIOS_MAX` |
| casillas electrificadas dibujadas | 24 | `MAX_AGUA_ELECTRICA` |
| dominios de gas | 2, entre todos los elementos | `HazGasJuego.MAX_INSTANCIAS` |
| bocanadas de humo | 420, y 20 emisores | `HumoRegla` |
| chispas | 60 por emisor, 360 en escena | `ChispasRepo` |

Los toys dibujan con MultiMesh por CPU y sin `GPUParticles3D`. El gas es la excepción: usa compute, se mide en la máquina de la 3070 y siempre tiene plan B.

## 10. Añadir o cambiar algo

- **Un elemento nuevo:** una clase toy con la misma API, su entrada en `VfxToyJuego._nuevo` y en `ELEMENTOS`, y su nombre en `vfx_procedural_elementos`.
- **Un efecto encima de lo validado:** una capa con su clave en `capas`, apagada de serie, y una línea de enganche.
- **Un dato nuevo de la lógica:** se añade al volumen `g` de `hechizo_v2` o a una señal, y el enganche lo pasa. El toy no pregunta a la lógica.

Cómo se comprueba (pruebas, capturas y laboratorios) sigue en `COMO_SE_GENERA_UN_HECHIZO.md` §7 bis, «Cómo se comprueba» y «Trampas que ya nos han mordido»: esa parte sigue valiendo.

## 11. Dónde está el resto

| tema | documento |
|---|---|
| carácter de cada elemento y los cuatro tiempos | `PLAN_VFX_ELEMENTOS.md` (las fichas son del 31/10: describen el dibujo antiguo) |
| el port del gas | `HAZ_GAS_PORT_2026-11-09.md`, `HAZ_FUEGO_VS_DEMO_2026-11-09.md` |
| gas de viento, rayo y agua | `GAS_VIENTO_RAYO_2026-11-11.md` |
| técnicas del repo de gas para otros elementos | `TECNICAS_REPO_GAS_OTROS_ELEMENTOS_2026-11-10.md` |
| el primer enganche de los toys | `ENGANCHE_VFX_TOY_2026-11-02.md` |
| humo toon | `HUMO_TOON_2026-11-06.md` |
| estados del suelo y reacciones | `ESTADOS_SUELO.md`, `REACCIONES_ENTORNO_2026-11-06.md` |
