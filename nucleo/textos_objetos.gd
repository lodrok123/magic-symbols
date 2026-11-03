class_name TextosObjetos
extends RefCounted

## B4 (tercera tanda, 2/11): lo que dice la mochila de cada objeto y el libro de cada glifo, en una o dos frases verdaderas.
## DESCRIPCION: id de `nucleo/datos/objetos.tsv` → texto (los ingredientes cuentan qué ETIQUETAS aportan a las recetas de `recetas.tsv`; los consumibles, lo que hace su `efecto`).
## GLIFO: nombre de glifo de `Sigils` (el id, no el nombre que ve la jugadora: ᚷ es `pulso` y se ve «crecer», ᚱ es `raido` y se ve «pulso», ⧖ es `retardo` y se ve «carga») → qué hace, con los
## números de `Sigils.GLIFOS` y del playtest del 30/10 (diario 294). Si cambia un número en `Sigils`, cambia aquí: `prueba_textos_objetos` solo comprueba que no falte ninguno.
## `Objetos.descripcion(id)` lee de aquí y, si falta, de la columna `desc` de la tabla.

const DESCRIPCION: Dictionary = {
	"oro": "La moneda del reino. Sirve para comprar en las tiendas y pagar las mejoras del alquimista.",
	# --- Setas ---
	"seta": "Seta común del bosque. Aporta vitalidad. Si la quemas, la mojas, la hielas o la electrificas, se vuelve otra seta.",
	"seta_asada": "Una seta que pasó por el fuego y huele a brasa. Aporta vitalidad y calor; va en la Brasa embotellada.",
	"seta_humeda": "Una seta empapada de agua. Aporta vitalidad y agua.",
	"seta_helada": "Una seta cubierta de escarcha. Aporta vitalidad y frío; va en el Frasco de frescor.",
	"seta_electrificada": "Una seta que chisporrotea. Aporta vitalidad y electricidad.",
	"esporas": "Esporas que dispersa el viento. Aportan viento a las recetas.",
	"seta_resonante": "Una seta que madura al compás del pulso. Aporta vitalidad y resonancia.",
	"esporas_luminosas": "Esporas que brillan en la oscuridad. Aportan resonancia, viento y tinta; van en el Pigmento Azul de Eco.",
	"seta_cristalizada": "Una seta cristalizada por el frío que tintinea al tocarla. Aporta resonancia y frío.",
	"seta_palida": "Crece donde no llega la luz y es tóxica: no la comas. Aporta toxicidad y algo de vitalidad a las recetas.",
	# --- Flores y plantas ---
	"flor_luna": "Una flor de pétalos pálidos. Aporta vitalidad y tinta.",
	"flor_ardiente": "Sus pétalos arden sin quemarse. Aporta tinta y calor; va en el Pigmento Resina Carmesí.",
	"flor_rocio": "Gotas que no se secan. Aporta tinta y agua; va en el Tónico de tinta.",
	"flor_chispa": "Pica al tocarla. Aporta tinta y electricidad.",
	"flor_escarcha": "Fría y quebradiza. Aporta tinta y frío.",
	"petalos": "Pétalos ligeros como el aire. Aportan tinta y viento.",
	"lavanda": "Huele a calma y calma a las criaturas del bosque. Aporta vitalidad y viento.",
	"baya": "Bayas dulces y rojas. Aportan vitalidad; van en la Poción de vida y en el Antídoto.",
	"helecho": "Hojas frescas. Aportan vitalidad; son la base de la Infusión de brezo.",
	"flor_silvestre": "Crece por todo el prado. Aporta algo de tinta; va en el Tónico de tinta.",
	"alga_cueva": "Un alga atrapada en el hielo de la charca. Aporta agua y vitalidad.",
	"alga_seca": "Quebradiza y salada. Aporta calor y tierra.",
	"alga_cargada": "Zumba dentro del frasco. Aporta electricidad y agua.",
	"musgo_cueva": "Musgo siempre húmedo. Aporta agua, vitalidad y tinta.",
	"helecho_cueva": "Crece junto a la cascada de la cueva. Aporta vitalidad.",
	# --- Raíces ---
	"raiz": "Una raíz retorcida. Aporta tierra y vitalidad.",
	"raiz_cenizas": "Negra y dura, de quemada. Aporta tierra y calor.",
	"raiz_hinchada": "Llena de agua. Aporta tierra y agua.",
	"raiz_magnetica": "Atrae el metal. Aporta tierra y electricidad.",
	"cristal_tierra": "Se forma al golpear una raíz con tierra. Aporta tierra.",
	# --- Materiales del mundo ---
	"resina": "Pegajosa y dorada: sale del tronco al golpearlo. Aporta calor y tinta; va en el Pigmento Resina Carmesí y en la Brasa embotellada.",
	"corteza": "Dura como un escudo pequeño. Aporta protección y tierra; va en el Bálsamo protector.",
	"panal": "El viento lo descuelga de la colmena. Aporta vitalidad y tinta.",
	"pluma": "Cae del nido cuando sopla el viento. Aporta viento y vitalidad.",
	"seda": "Una telaraña helada se recoge entera. Aporta frío y protección.",
	"carbon": "Lo que queda de un seto que ardió. Aporta calor y tierra.",
	"piedra": "Una piedra del camino. Aporta tierra.",
	"mineral_veta": "Un trozo de la veta del pulso. Aporta tierra y resonancia.",
	"esquirla_cristal": "Zumba muy bajito. Aporta resonancia.",
	"basalto": "Roca de lava enfriada. Aporta tierra y calor.",
	"obsidiana": "Lava enfriada de golpe con hielo. Aporta tierra, frío y calor.",
	"polvo_cristal": "El pigmento azul del pulso. Aporta resonancia y tinta; es la base del Pigmento Azul de Eco.",
	"cristal_cargado": "Una esquirla que guarda un rayo. Aporta resonancia y electricidad.",
	"ceniza_geoda": "Lo que deja la geoda al explotar. Aporta resonancia y tierra.",
	# --- Botín de enemigos ---
	"colmillo_goblin": "Amarillento y astillado. Aporta tierra y protección; va en el Bálsamo protector.",
	"jiron_escudo": "Cuero chamuscado de un escudo que ardió. Aporta calor y protección.",
	"baba_limo": "Tiembla sola; un limo la deja al caer. Aporta agua y toxicidad; va en el Antídoto.",
	"pluma_chaman": "Del tocado del chamán goblin. Aporta viento y toxicidad.",
	"polvo_golem": "Piedra molida que aún pesa. Aporta tierra y protección.",
	# --- Épicos y glifo ---
	"nucleo_eco": "Late dentro como un segundo corazón. Material épico que no se vende: lo pide el alquimista para el Frasco hondo II.",
	"geoda_resonante": "Hueca y cantarina. Material épico: lo pide el alquimista para el Frasco de reserva II.",
	"savia_elemental": "La deja el elemental del bosque al caer. Material épico: lo pide el alquimista para el Corazón robusto III.",
	"glifo_resonancia": "Del cofre legendario. Al usarlo escribe el glifo ᚱ «pulso» en el libro: suelta un pulso resonante con el elemento del hechizo.",
	# --- Consumibles ---
	"pocion": "Cura 40 de vida al beberla, 1,5 s quieto; un golpe la interrumpe. Equípala y usa Q.",
	"pocion_grande": "Cura 80 de vida, el doble que la poción, y tarda lo mismo en beberse.",
	"tonico_tinta": "Recarga un frasco de tinta vacío. Solo sirve si falta algún frasco.",
	"balsamo_protector": "Absorbe por completo el próximo golpe. Dura 20 s; si nadie te pega, se pierde.",
	"infusion_brezo": "Regenera 3 de vida por segundo durante 12 s. Un golpe no corta el efecto.",
	"antidoto": "Quita el veneno y te protege de él durante 60 s.",
	"frescor": "Te hace aguantar el calor del volcán durante 90 s.",
	"abrigo": "Te hace aguantar el frío de la cumbre durante 90 s.",
	# --- Pigmentos ---
	"pigmento_carmesi": "Tinta roja: durante 60 s el fuego hace ×1,5 de daño.",
	"pigmento_ocre": "Tinta ocre: durante 60 s los hechizos de tierra cuestan la mitad de tinta.",
	"pigmento_musgo": "Tinta verde: durante 60 s los hechizos de viento cuestan la mitad de tinta.",
	"pigmento_ambar": "Tinta ámbar: durante 60 s el rayo hace ×1,5 de daño.",
	"pigmento_eco": "Tinta de pulso: durante 60 s desaparece el recargo de tinta del glifo ᚱ.",
	# --- Objetos clave ---
	"llave": "Abre la puerta de la Cueva (C4).",
	"llave_goblin": "La llave del campamento goblin: abre su puerta.",
	"perla": "Objeto de misión: guárdala hasta que alguien la pida.",
	"aletas": "Con ellas puedes nadar.",
	# --- Ropa ---
	"capa": "Una capa ligera para la ranura exterior. Se consigue en cofres o misiones; el alquimista puede bordarla con seda helada.",
	"capucha": "Tapa el pelo y poco más (ranura de cabeza). El alquimista puede forrarla de musgo.",
	"tunica": "Túnica de viaje (ranura del medio). El alquimista puede teñirla con resina y jirones.",
	"capa_escarcha": "Capa bordada con seda helada: te hace inmune al frío y da 1 de defensa.",
	"tunica_salamandra": "Túnica teñida con resina y jirones: te hace inmune al calor y da 1 de defensa.",
	"capucha_musgo": "Capucha forrada de musgo: filtra las esporas, te hace inmune al veneno y da 1 de defensa.",
}

## Glifos: el id de `Sigils` (GLIFOS, FORM, OPERATOR y GLYPHS). Los números son los de `Sigils.GLIFOS` y el playtest del 30/10.
const GLIFO: Dictionary = {
	"flecha": "Flecha: el hechizo viaja en línea recta. La 1.ª da 2 casillas de alcance y cada una más suma 1 (tope 6) y un empujón hacia arriba.",
	"barrera": "Barrera: el hechizo te rodea y bloquea proyectiles. Cada una multiplica su solidez por 1,5 (tope 3) y, desde la 2.ª, suma 1 s de permanencia.",
	"repeticion": "Repetición: lo que lanzas sale varias veces. Cada una suma una copia (hasta 4 en total).",
	"rebote": "Rebote: al acabar, el proyectil rebota. Cada uno suma un rebote (tope 3).",
	"pulso": "Crecer: el hechizo crece mientras vive (+0,5 m/s, tope 1,5) y cada ᚷ multiplica su tamaño final por 1,25.",
	"permanencia": "Permanencia: lo que sale se queda donde nace o donde para. Cada una suma 2 s (tope 25 s).",
	"raido": "Pulso: al llegar al final de un proyectil, o a intervalos si el hechizo se queda, suelta un pulso con tu elemento. Cada ᚱ suma 4 casillas de alcance (tope 12); con barrera o permanencia cuesta un 25 % más de tinta.",
	"linea": "Línea: estira el hechizo; un trazo horizontal lo ensancha y uno vertical lo alarga. La 1.ª alarga 1 casilla (0,5 m de semieje) y cada siguiente 0,5 casillas. Sola, con un elemento, es un rayo.",
	"linea_x": "Línea horizontal: ensancha el hechizo. La 1.ª alarga 1 casilla y cada ᛁ siguiente 0,5 casillas; con barrera, un muro de 3 casillas pide 3.",
	"linea_z": "Línea vertical: alarga el hechizo hacia delante. La 1.ª alarga 1 casilla y cada ᛁ siguiente 0,5 casillas.",
	"altura": "Altura: eleva el hechizo. El 1.º suma 0,30 m de semieje y cada siguiente un 15 % menos que el anterior (decreciente, sin tope): 1 = 1 nivel, 3 = 2 niveles y 6 = 3 niveles.",
	"levitacion": "Levitación: cuenta como altura (ᛏ). Eleva el hechizo: 1 = 1 nivel y 6 = 3 niveles (rendimiento decreciente, sin tope).",
	"perforar": "Perforar: el proyectil atraviesa 1 enemigo más por glifo (tope 3) antes de pararse. Sin flecha, el haz atraviesa hasta esas casillas sólidas o barreras.",
	"retorno": "Retorno: al acabar la ida, el proyectil vuelve y golpea de nuevo. Un segundo ᛃ no suma nada más.",
	"buscar": "Buscar: el proyectil se imanta al enemigo vivo más cercano de su cono. Cada ᚨ abre más el cono: ±60°, ±90° y ±120° (tope 3).",
	"retardo": "Carga: lo que sale tarda 1 s más por glifo en salir (tope 3 s) y a cambio nace un 20 % más grande y con un 25 % más de daño por glifo.",
	"atraccion": "Atracción: lo que toca es tirado hacia ti si viaja, o hacia el centro si se queda.",
	"espejo": "Espejo: lo que viaja o nace lejos sale también hacia atrás.",
	"amplificar": "Amplificar: duplica el daño del hechizo y sube la intensidad de su efecto.",
}


## La descripción de un objeto; "" si no está en la tabla (entonces `Objetos.descripcion` usa la de objetos.tsv).
static func descripcion(id: String) -> String:
	return String(DESCRIPCION.get(id, ""))


## Qué hace un glifo (por su id de `Sigils`); "" si no se conoce.
static func glifo(nombre: String) -> String:
	return String(GLIFO.get(nombre, ""))
