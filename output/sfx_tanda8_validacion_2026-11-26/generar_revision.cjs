const fs=require('fs'),path=require('path');const root=path.resolve(__dirname,'../..');
const catalogo=require('../auditoria_sfx_2026-11-25/catalogo.json'),propuestas=require('./propuestas.json');
const casos=[
  {
    "id": 43,
    "titulo": "Fuego A: carga y fuego ardiendo en bucle",
    "estado": "Aceptado · aplicado",
    "nota": "A es para carga y fuego ardiendo, no para impacto. Carga breve: copia exacta del recorte elegido. Carga sostenida y arde_bucle: grabación completa de origen oga_fuego_crepita_loop.wav, preparada para bucle, sin la envolvente del recorte. El ambiente de fuego 3D ya utiliza esa misma fuente. Se conservan los niveles de cada uso.",
    "nombre": "fuego_carga"
  },
  {
    "id": 44,
    "titulo": "Impacto de agua: variante 2",
    "estado": "Mejorable · ajuste aplicado",
    "nota": "Variante 2 a −19 dB, 12 dB más baja que la señal general. Solo impacto; la carga conserva su entrada propia.",
    "nombre": "agua_impacto"
  },
  {
    "id": 45,
    "titulo": "Impacto de hielo: variante 3",
    "estado": "Aceptado · aplicado",
    "nota": "Variante 3 asignada a hielo_impacto. La elección no corresponde a carga ni a la señal general.",
    "nombre": "hielo_impacto"
  },
  {
    "id": 46,
    "titulo": "Impacto de rayo: variante 1",
    "estado": "Aceptado · aplicado",
    "nota": "Variante 1 asignada a rayo_impacto. La elección no corresponde a carga ni a la señal general.",
    "nombre": "rayo_impacto"
  },
  {
    "id": 47,
    "titulo": "Impacto de viento: A",
    "estado": "Aceptado · aplicado",
    "nota": "Copia exacta de la propuesta A, fuente Extreme Winds de 344 Audio/Sonniss. Asignada a viento_impacto, manteniendo −11 dB y variación de tono.",
    "nombre": "viento_impacto"
  },
  {
    "id": 48,
    "titulo": "Impacto de tierra: variante 1",
    "estado": "Aceptado · aplicado",
    "nota": "Solo la variante 1 en tierra_impacto, manteniendo −8 dB y variación de tono.",
    "nombre": "tierra_impacto"
  }
];let total=0;
function player(src,label,db){if(!fs.existsSync(path.resolve(root,'docs',src)))throw Error(src);total++;return `<p>${label}</p><audio controls preload="none" src="${src}" data-db="${db}"></audio>`}
const cards=casos.map(c=>{let clips;if(c.protos)clips=c.protos.map((f,i)=>player('../output/sfx_tanda8_validacion_2026-11-26/'+f,(i?'B':'A')+' · '+propuestas.find(p=>p.archivo===f).origen,c.db)).join('');else {const e=catalogo.find(e=>e.catalogo==='Sfx'&&e.nombre===c.nombre);if(!e)throw Error(c.nombre);c.entrada=e;clips=e.files.map((f,i)=>player('../audio/'+f,(e.files.length>1?'Variante '+(i+1)+' · ':'')+f,e.cfg.db)).join('')}return `<section><h2>${c.id} · ${c.titulo}</h2><p><b>${c.estado}</b></p><p>${c.nota}</p>${clips}</section>`}).join('');
const html=`<!doctype html><html lang="es"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>SFX · Octava tanda revisada</title><style>:root{color-scheme:dark}body{font:16px/1.6 system-ui;background:#121c28;color:#e6eef7;max-width:960px;margin:32px auto;padding:0 20px 60px}section{background:#1c2b3d;border:1px solid #435e7c;border-radius:12px;padding:22px;margin:20px 0}audio{width:100%}select{font:inherit;padding:7px}</style><h1>Octava tanda: decisiones y nuevas propuestas</h1><p>Fuego A para carga y bucles. Agua 2 sutil, hielo 3, rayo 1, viento A y tierra 1 para impacto.</p><label>Escucha <select id="modo"><option value="juego">Nivel de catálogo aproximado</option><option value="original">Muestra con margen de −3 dB</option></select></label><p>Para juzgar el agua más sutil usa el modo de catálogo. El modo original permite comparar timbre y escuchar con mayor claridad las propuestas. No se simulan distancia, mezcla con escritura, capas simultáneas ni variaciones aleatorias. Las nuevas propuestas se basan en procedencia y edición técnica; el revisor no ha escuchado los archivos.</p>${cards}<script>const audio=[...document.querySelectorAll('audio')],modo=document.querySelector('#modo');function ajustar(){for(const a of audio)a.volume=modo.value==='juego'?Math.min(1,10**(Number(a.dataset.db)/20)):10**(-3/20)}modo.onchange=ajustar;ajustar();for(const a of audio)a.addEventListener('play',()=>{for(const b of audio)if(b!==a)b.pause()});</script></html>`;
new Function(html.match(/<script>([\s\S]*?)<\/script>/)[1]);
fs.writeFileSync(path.join(root,'docs/VALIDACION_SFX_TANDA8_2026-11-26.html'),html);
fs.writeFileSync(path.join(__dirname,'decisiones_pablo.json'),JSON.stringify({casos,propuestas},null,2));
console.log(total+' muestras presentes; JavaScript válido.');
