const fs=require('fs');
const casos=[
{id:31,n:'golpe_carne',cat:'Sfx3D',titulo:'Impacto sobre el cuerpo del enemigo',cuando:'Un enemigo de cuerpo blando recibe un golpe; acompaña al hechizo o arma que lo provoca.',motivo:'Cuatro variantes de 0,37–0,47 s. Conviene comparar su textura y evitar que dominen a la voz o al ataque.',propuesta:'Valorar qué variantes encajan con el cuerpo del goblin y si necesitan menos nivel.',pregunta:'¿Se reconoce el impacto sobre un cuerpo? ¿Conservarías todas las variantes o elegirías algunas?'},
{id:32,n:'golpe_piedra',cat:'Sfx3D',titulo:'Impacto sobre el gólem de piedra',cuando:'El cuerpo o núcleo vulnerable del gólem recibe un golpe.',motivo:'Tres variantes de 0,80–0,94 s: más largas que los impactos de carne. Revisar especialmente material y cola.',propuesta:'Conservar las que comuniquen piedra; recortar la cola si retrasa la lectura del siguiente golpe.',pregunta:'¿Suena a piedra golpeada? ¿Sobra resonancia o duración?'},
{id:33,n:'limo_golpe',cat:'Sfx3D',titulo:'Golpe del limo y daño a su cuerpo',cuando:'El limo recibe daño; la misma entrada también se reproduce al ejecutar su golpe.',motivo:'Una señal breve de 0,31 s compartida entre ataque y daño. La muerte del limo ya está aceptada y debe seguir distinguiéndose.',propuesta:'Valorar si la textura sirve en ambos usos; si solo encaja en uno, separar las señales.',pregunta:'¿Encaja como impacto blando del limo? ¿La usarías para atacar, recibir daño o ambos?'},
{id:34,n:'hielo_quiebra',cat:'Sfx',titulo:'Rotura de hielo en piezas del puzle',cuando:'Una pieza helada del puzle se quiebra. Es una entrada distinta de la congelación del mundo ya aprobada.',motivo:'Tres variantes de 1,47–1,57 s. La tercera mide unos 4,3 dB RMS menos que la segunda; eso orienta la comparación, no demuestra diferencia perceptiva equivalente.',propuesta:'Elegir las fracturas que identifiquen hielo y después ajustar duración o balance entre variantes.',pregunta:'¿Parece hielo quebrándose? ¿Qué variantes conservarías y qué recortarías?'},
{id:35,n:'explosion',cat:'Sfx',titulo:'Explosión de geoda o pieza del puzle',cuando:'Explota la geoda de pulso o una pieza del puzle. El barril del mundo tiene otra entrada de sonido.',motivo:'Una toma de 1,12 s, a −6 dB de catálogo. Revisar la escala del estallido frente a los impactos comunes.',propuesta:'Conservarla si encaja con una explosión de ese tamaño; ajustar nivel o cola si domina la escena.',pregunta:'¿Encaja la fuerza y textura de la explosión? ¿La harías más breve o más discreta?'},
{id:36,n:'maza_impacto',cat:'Sfx3D',titulo:'Impacto de la maza al conectar',cuando:'El ataque de maza conecta con su objetivo.',motivo:'Una toma de 0,70 s. Se debe distinguir del impacto del cuerpo del caso 31 y funcionar al coincidir con otras capas.',propuesta:'Conservarla si aporta peso al arma sin ocultar la respuesta del objetivo.',pregunta:'¿Comunica un arma pesada golpeando? ¿Cambiarías ataque, textura, duración o nivel?'}
];
let s=fs.readFileSync('output/auditoria_sfx_2026-11-25/generar_escucha_tanda5.cjs','utf8');
s=s.replace("const all=require('./barrido.json');",`const actual=require('./catalogo.json'),historico=require('./barrido.json');
const all=actual.map(e=>({...e,metricas:historico.find(h=>h.catalogo===e.catalogo&&h.nombre===e.nombre)?.metricas||[],avisos:[],rango_rms_db:0}));`);
const ini=s.indexOf('const casos=['),fin=s.indexOf('].map(x=>',ini);
s=s.slice(0,ini)+'const casos='+JSON.stringify(casos,null,2)+s.slice(fin+1);
s=s.replaceAll('tanda5','tanda6').replaceAll('TANDA5','TANDA6').replaceAll('Quinta','Sexta');
s=s.replace('Problemas de integración separados de la escucha','Alcance de la escucha').replace('Sfx.play_en y Sfx.bucle no asignan Mundo; hay contactos de magia con suelo sin sonido y el aviso golem_carga no existe en los catálogos. Requieren revisar integración: no se solucionan aprobando o sustituyendo un timbre.','Las muestras permiten validar timbre y comparar variantes. Para cerrar el balance final se necesita escucharlas junto al resto de capas del combate.');
fs.writeFileSync('output/auditoria_sfx_2026-11-25/generar_escucha_tanda6.cjs',s);
require('./generar_escucha_tanda6.cjs');
const h=fs.readFileSync('docs/ESCUCHA_SFX_TANDA6_2026-11-25.html','utf8');
const path=require('path');let n=0;
for(const m of h.matchAll(/src="([^"]+)"/g)){if(!fs.existsSync(path.resolve('docs',decodeURIComponent(m[1]))))throw Error(m[1]);n++;}
new Function(h.match(/<script>([\s\S]*?)<\/script>/)[1]);
const prev=[1,2,3,4,5].flatMap(i=>require('./tanda'+i+'.json'));
for(const c of casos){if(prev.some(p=>p.n===c.n&&(p.cat||p.entrada.catalogo)===c.cat))throw Error('Caso repetido');}
console.log(n+' muestras presentes; seis casos nuevos; JavaScript válido.');
