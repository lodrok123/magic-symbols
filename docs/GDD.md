# Magic Symbols: GDD corto (2/11/2026)

Lo que el juego quiere ser, en dos páginas. Si algo no está decidido, dice «sin decidir». El estado real del código está en `docs/DIRECCION_2026-11-02.md`; el detalle del presente, en `ARQUITECTURA.md`.

## Qué juego es

Un juego de puzles y aventura en 3D, con una elfa chibi maga, donde dibujas sellos y glifos en un libro para lanzar hechizos que cambian el mundo.

## Referencias

*Magicka* (combinar elementos), *Witch Hat Atelier* (que dibujar importe), *Echoes of Wisdom* (el hechizo deja algo en el mundo que se usa), *Link's Awakening* (estética chibi y pastel), *Wizard of Legend* (gamefeel: anticipación, impacto, hitstop, residuo), *Kena* (efectos con silueta y color con intención), *Noita* (el elemento cambia el estado del suelo y se propaga). Los cuatro pilares de VFX son Echoes of Wisdom, Wizard of Legend, Kena y Noita (`docs/PLAN_VFX_ELEMENTOS.md` §0).

## Pilares de diseño

1. **Datos, no código.** Un elemento, un glifo o un nivel es una fila de datos; las reglas se leen de tablas.
2. **Las combinaciones emergen.** Nadie escribe «fuego + tierra»: cada glifo aporta lo suyo y la receta terminada se interpreta.
3. **Solo entra lo que da opciones nuevas al jugador.** Un sistema que no abre jugadas no entra, aunque sea bonito (`docs/DISENO_FUTURO.md`).

## Bucle de juego

Cámara ortogonal a 60° que gira de 90° en 90°. Con el libro abierto el tiempo va al 30 %. La jugadora abre el libro, dibuja un sello en el núcleo (elemento) y glifos en los sectores (forma), cierra y lanza **desde ella**. El elemento cambia el mundo (moja, hiela, quema, electrifica, siega) y ese cambio abre el paso: puzles y mazmorras por niveles encadenados (Gruta Batida, Bosque, Cueva, Cueva Resonante).

## Sistema de hechizos

- Seis elementos: fuego, agua, tierra, rayo, hielo y viento.
- 14 entradas de glifo en `nucleo/sigils.gd` (`GLIFOS`): líneas en X y Z, altura, flecha, barrera, repetición, rebote, crecer, permanencia, pulso, perforar, retorno, buscar y carga.
- `nucleo/hechizo.gd` junta elemento y glifos en un `Hechizo`: tres semiejes X/Y/Z, una figura, `viaja` y `haz`.
- Los glifos de línea y altura estiran los semiejes; los de propiedad suman o multiplican un parámetro con tope.
- La **materia** del elemento decide cómo se ejecuta (`magia/hechizo_vivo.gd`): sólido (bloque), líquido (simulación de agua), plasma (zona que daña), energía (descarga) y gas (empuje).
- Una sola entrada de daño y de tinta (`nucleo/dano.gd`).
- La regla visual madre: el glifo manda la forma y el elemento manda el material y la microanimación.
- Primeras versiones oficiales de VFX: fuego y agua (`presentacion/vfx/toy/`). Hielo, rayo, tierra y viento, sin versión oficial.

## Estados del mundo

`mundo/estados_suelo_3d.gd` guarda estados por casilla; las transiciones son una tabla.

| llega | si la casilla | pasa |
|---|---|---|
| agua | helada | nada |
| agua | mojada | se hiela |
| agua | otra | se moja |
| frío | cualquiera | se hiela (quita mojada) |
| calor | helada | pasa a mojada |
| calor | mojada | se seca (vapor) |

Estados: helada, electrificada, quemada, mojada y segada. Cada estado lleva su reloj en `EstadosSuelo3D.DURA`: el mojado se seca a los 20 s, el **hielo se va a los 20 s** (y deja la casilla mojada) y **la electricidad a los 2 s si nadie la mantiene** (un emisor de rayo activo la renueva mientras dura la descarga; un hechizo de rayo la deja en las casillas mojadas o de agua que toca); quemada y segada no caducan (sin decidir). Una zona de calor acorta el hielo a un tercio y una de frío casi lo detiene. Reacciones más ricas en `mundo/reacciones_*_3d.gd`.

## Enemigos

En `enemigos/`: goblin guerrero (con escudo), arquero, asesino y chamán (escudo de naturaleza a los aliados), limo elemental, gólem y gatopedro. Comparten `combate_3d.gd` (vida, debilidades, estados, empuje por masa, avisos de ataque). Jefes: sin verificar el catálogo; ver DIRECCION §1.

## Progresión decidida

- **Sellos por historia** (Pablo, 24/10). Qué sello da cada zona, sin decidir; la auditoría del 24/10 propone hielo en la Torre del Agua.
- **Glifos** en cofres legendarios, uno por mazmorra temática.
- **Mejoras** (vida, tinta, pigmentos) por recetas con ingredientes; la ropa sale de cofres y misiones.
- **Tinta**: se empieza con 100 y el tope es 300 (`nucleo/tinta.gd`).
- **Primer libro**: capacidad para 4 elementos y 6 glifos; un libro nuevo llega más adelante, sin decidir cuándo ni con qué elementos.
- Kit real de arranque: decidido, aún no activo en el nivel inicial, que según DIRECCION §1 usa `kit = "pruebas"` (sin verificar en el código).

## Estado actual

- Maduro: modelo de hechizo, ejecución por materia, estados del suelo, enemigos, puzles por datos y unas 175 pruebas sin ventana.
- Verde: el fuego y el agua oficiales no están en el juego, solo en el laboratorio; conviven seis familias de VFX.
- Verde: varios glifos no cumplen lo que prometen (repetición con flecha, impulso de tierra y hielo, `crecer`).
- Verde: el mundo no tiene reloj propio y la hierba vive en la maqueta, no en `mundo/`.
- Verde: progresión sin cerrar y build con restos de depuración.

## Documentos que mandan

`docs/DIRECCION_2026-11-02.md` (dónde está y por dónde seguir), `ARQUITECTURA.md` (el presente), `docs/DISENO_FUTURO.md` (lo que se quiere), `docs/PLAN_VFX_ELEMENTOS.md` (VFX y estado del mundo), `docs/PENDIENTES.md` y `docs/DECISIONES_CHATS.md` (decisiones), `docs/PROPIETARIOS.md` (quién toca qué), `docs/CONTEXTO.md` (cómo se trabaja).
