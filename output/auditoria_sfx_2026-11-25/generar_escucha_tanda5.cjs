const fs=require('fs');
const all=require('./barrido.json');
const casos=[
  {
    "id": 25,
    "n": "escudo_golpe",
    "cat": "Sfx",
    "titulo": "Golpe bloqueado por escudo",
    "cuando": "Una barrera o protección recibe y bloquea un golpe. La misma señal se reutiliza en algunas protecciones enemigas.",
    "motivo": "Una toma de unos 0,29 s para un evento que puede repetirse durante el combate. Debe comunicar bloqueo y distinguirse de la rotura.",
    "propuesta": "Conservarla si el bloqueo se reconoce; ajustar material, duración o intensidad según tu valoración.",
    "pregunta": "¿Se entiende que la protección aguanta el golpe? ¿Qué cambiarías de su textura o fuerza?"
  },
  {
    "id": 26,
    "n": "escudo_roto",
    "cat": "Sfx",
    "titulo": "Rotura de escudo o burbuja",
    "cuando": "Se rompe una barrera o revienta una burbuja protectora.",
    "motivo": "Una toma de aproximadamente 1,40 s. La pérdida de la protección necesita diferenciarse claramente del golpe bloqueado del caso 25.",
    "propuesta": "Conservarla si comunica rotura; revisar la cola y el balance con el golpe que la provoca.",
    "pregunta": "¿Se entiende que has perdido la protección? ¿La duración y el material encajan con una barrera mágica?"
  },
  {
    "id": 27,
    "n": "recarga_lista",
    "cat": "Sfx",
    "titulo": "Página o esquiva disponible otra vez",
    "cuando": "Una página termina de recargarse o vuelve a estar disponible la voltereta. Las páginas usan un tono algo más alto que la esquiva.",
    "motivo": "Una única señal de unos 0,15 s, a nivel bajo en el catálogo. Debe reconocerse sin invadir cada pocos segundos el combate.",
    "propuesta": "Conservarla si sirve como aviso discreto de disponibilidad; ajustar su claridad frente al resto de acciones.",
    "pregunta": "¿Se entiende como algo que vuelve a estar listo? ¿Te resulta demasiado mecánico, débil o repetitivo?"
  },
  {
    "id": 28,
    "n": "no_puedes",
    "cat": "Sfx",
    "titulo": "Acción no permitida durante el juego",
    "cuando": "Se intenta una acción que no puede ejecutarse en el mundo, como lanzar sin recursos o sin estar listo. Es distinto de la negativa de los menús.",
    "motivo": "Una toma de unos 0,45 s. El rechazo de interfaz ya usa la opción C; falta decidir si este contexto necesita otra señal.",
    "propuesta": "Valorar esta negativa en relación con la C sutil ya aprobada para menús; conservar la distinción solo si ayuda.",
    "pregunta": "¿Conservarías este aviso para el mundo o usarías también la opción C de los menús? ¿Qué cambiarías?"
  },
  {
    "id": 29,
    "n": "goblin_muere",
    "cat": "Sfx3D",
    "titulo": "Muerte del goblin",
    "cuando": "Muere un goblin; es una señal distinta de su alerta, cuya variante 3 ya elegiste.",
    "motivo": "La toma dura unos 1,58 s; el juego aplica tono base ×0,8, por lo que se alarga. Hay una sola interpretación seleccionada.",
    "propuesta": "Conservarla si encaja con la voz de alerta y el tamaño del personaje; recortar o bajar si domina el final del golpe.",
    "pregunta": "¿Parece el mismo goblin que al alertar? ¿La voz y la duración encajan con su muerte?"
  },
  {
    "id": 30,
    "n": "limo_muere",
    "cat": "Sfx3D",
    "titulo": "Muerte del limo",
    "cuando": "El limo revienta al quedarse sin vida; puede coincidir con un remate elemental.",
    "motivo": "Una única toma de unos 1,33 s. Debe comunicar la desintegración de un cuerpo blando sin tapar el golpe o reacción que lo mata.",
    "propuesta": "Conservarla si el material del limo se reconoce; revisar cola y nivel en relación con el resto de muertes.",
    "pregunta": "¿Se oye un limo que revienta? ¿Qué cambiarías de textura, duración o intensidad?"
  }
].map(x=>({...x,entrada:all.find(e=>e.nombre===x.n&&(!x.cat||e.catalogo===x.cat))}));
const esc=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
const fmt=x=>Number(x).toFixed(1).replace('.',',');
function player(e,f,tag='') {const m=e.metricas.find(x=>x.archivo===f);return `<div class="clip"><p><b>${esc(tag||f)}</b> <span>${fmt(m.duracion_s)} s · RMS ${fmt(m.rms_dbfs)} dBFS</span></p><audio controls preload="none" src="../audio/${encodeURIComponent(f)}" data-db="${e.cfg.db}" data-bus="${['comprar','ui_tick','recoger','paginas_bucle','ui_equipar','no_puedes_ui','libro_cierra'].includes(e.nombre)?-6:0}" data-pitch="${e.cfg.base||e.cfg.pitch||1}"></audio></div>`;}
const cards=casos.map(x=>{const e=x.entrada,ff=x.clips||e.files;return `<article id="caso-${x.id}" data-id="${x.id}"><header><span class="num">${x.id}</span><div><h2>${x.titulo}</h2><code>${e.catalogo}.${e.nombre}</code></div><span class="badge">Pendiente de tu validación</span></header><p><b>Cuándo suena:</b> ${x.cuando}</p><p><b>Por qué lo revisaría:</b> ${x.motivo}</p><p><b>Mi propuesta provisional:</b> ${x.propuesta}</p><p class="pregunta">${x.pregunta}</p>${ff.map((f,i)=>player(e,f,ff.length>1?'Variante '+(i+1)+' · '+f:'')).join('')}${x.id===1?'<p class="detalle">Escucha los primeros seis segundos desde 0:00. El archivo completo es largo; no hace falta escucharlo entero.</p>':''}${x.bucle?'<button class="bucle" type="button">Escuchar diez segundos en bucle</button>':''}${e.files.some(f=>!ff.includes(f))?'<details><summary>Escuchar las otras variantes</summary>'+e.files.filter(f=>!ff.includes(f)).map(f=>player(e,f)).join('')+'</details>':''}<div class="valoracion"><label>Tu decisión<select class="decision"><option>Pendiente</option><option>Aceptado</option><option>Mejorable</option><option>A cambiar</option></select></label><label>Qué cambiarías<textarea class="nota" rows="2" placeholder="Por ejemplo: menos agudo, demasiado largo, no parece piedra…"></textarea></label></div></article>`}).join('\n');
const flags=all.filter(e=>e.avisos.length);
const table=all.map(e=>`<tr><td>${esc(e.catalogo+'.'+e.nombre)}</td><td>${e.files.length}</td><td>${fmt(e.rango_rms_db)}</td><td>${e.avisos.length?esc(e.avisos.join('; ')):'Sin aviso automático; pendiente de escucha'}</td><td>Pendiente</td></tr>`).join('');
const html=`<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Quinta escucha de SFX · 25 noviembre 2026</title><style>:root{color-scheme:dark}*{box-sizing:border-box}body{margin:0;background:#111820;color:#e6edf6;font:16px/1.6 system-ui}main{max-width:1050px;margin:auto;padding:36px 22px 90px}h1{font-size:34px;line-height:1.2}h2{font-size:23px;margin:0}h3{margin-bottom:8px}p{margin:10px 0}code{color:#b8c9df}nav{display:flex;gap:8px;flex-wrap:wrap;margin:20px 0}a{color:#9bccff}nav a,button{border:1px solid #4d6681;border-radius:8px;padding:8px 13px;background:#24374a;color:#edf4ff;font:inherit;text-decoration:none;cursor:pointer}.panel,article{background:#1b2633;border:1px solid #384d63;border-radius:14px;padding:23px;margin:22px 0}header{display:flex;align-items:center;gap:14px;flex-wrap:wrap}.num{font-size:25px;color:#8dc9ff}.badge{font-size:12px;padding:3px 9px;border:1px solid #7b6936;border-radius:20px;color:#e9d09c}.pregunta{border-left:3px solid #88c8ff;padding:10px 14px;background:#23394c}.clip{padding:8px 0}.clip p{font-size:14px}.clip span,.detalle{color:#aebfd2;font-size:14px}audio{width:100%}select,textarea{background:#0e1925;color:#f0f6ff;border:1px solid #56718e;border-radius:6px;padding:9px;font:inherit}textarea{display:block;width:100%}.valoracion{display:grid;grid-template-columns:190px 1fr;gap:18px;margin-top:20px}label{display:block}select{display:block;max-width:100%}details{margin:15px 0}summary{cursor:pointer;color:#9bccff}table{border-collapse:collapse;width:100%;font-size:13px}td,th{text-align:left;vertical-align:top;border-bottom:1px solid #364858;padding:9px}td:first-child{overflow-wrap:anywhere}#resumen{min-height:150px}#estado{color:#91d6b1}@media(max-width:650px){.valoracion{grid-template-columns:1fr}h1{font-size:28px}.panel,article{padding:17px}}</style></head><body><main><p>MAGIC SYMBOLS · 25 NOVIEMBRE 2026</p><h1>Quinta escucha de SFX</h1><p>Quinta tanda: seis efectos todavía sin validar. Comparamos las variantes actuales y su adecuación a la acción. Las cifras proceden del barrido técnico; no son una valoración del timbre.</p><p>La preselección se basa en mediciones y uso del código. <b>El revisor no ha escuchado los archivos.</b> Tu valoración cierra la parte artística. Continuamos con efectos distintos de los que ya validaste.</p><nav>${casos.map(x=>`<a href="#caso-${x.id}">${x.id} · ${x.titulo}</a>`).join('')}</nav><div class="panel"><h3>Modo de escucha</h3><label><select id="modo"><option value="original">Original con −3 dB comunes · comparar timbre</option><option value="juego">Ganancia de catálogo y bus · sin distancia ni oclusión</option></select></label><p class="detalle">Las variantes conservan sus diferencias de nivel: no se normalizan. El segundo modo aproxima solo ganancia y tono base. No reproduce la escena ni la suma de capas, y las llamadas concretas pueden añadir otros cambios. Para valorar volumen, usa el modo de juego; el original aplica un margen común de −3 dB para comparar timbre sin saturar los picos de la señal. Al reproducir un clip se detienen los demás.</p><p class="detalle">Puedes marcar una decisión y escribir notas. Se guardan solo en este navegador; usa el resumen de abajo para enviármelas.</p></div>${cards}<section class="panel"><h2>Tu valoración para el chat</h2><p>Basta con decirme el número y qué te molesta. También puedes preparar aquí el resumen de las casillas que hayas rellenado.</p><button id="preparar" type="button">Preparar resumen</button> <button id="copiar" type="button">Copiar</button><textarea id="resumen" readonly aria-label="Resumen para enviar al chat"></textarea><p id="estado" role="status"></p></section><details class="panel"><summary>Barrido histórico · 25 noviembre, antes de los primeros ajustes</summary><p>El rango RMS es del archivo completo: las colas, silencios y duración influyen. No equivale a sonoridad percibida. Un pico Vorbis sobre 0 dBFS tampoco prueba distorsión después de la atenuación del juego. Sin aviso automático no significa aceptado.</p><div style="overflow:auto"><table><thead><tr><th>Entrada</th><th>Tomas</th><th>Rango RMS dB</th><th>Observación técnica</th><th>Validación</th></tr></thead><tbody>${table}</tbody></table></div></details><section class="panel"><h3>Problemas de integración separados de la escucha</h3><p>Sfx.play_en y Sfx.bucle no asignan Mundo; hay contactos de magia con suelo sin sonido y el aviso golem_carga no existe en los catálogos. Requieren revisar integración: no se solucionan aprobando o sustituyendo un timbre.</p><p>Esta tanda no modifica los archivos de sonido ni el juego. Datos completos en output/auditoria_sfx_2026-11-25/barrido.json.</p></section></main><script>
const audio=[...document.querySelectorAll('audio')],cards=[...document.querySelectorAll('article')],mode=document.querySelector('#modo'),estado=document.querySelector('#estado');let timer;
function ajustar(){for(const a of audio){a.volume=mode.value==='juego'?Math.min(1,10**((Number(a.dataset.db)+Number(a.dataset.bus))/20)):0.707945784; a.preservesPitch=false;a.playbackRate=mode.value==='juego'?Number(a.dataset.pitch):1;}}mode.onchange=ajustar;ajustar();
function parar(){clearTimeout(timer);for(const a of audio){a.pause();a.loop=false;}}
document.addEventListener('play',e=>{if(e.target.tagName==='AUDIO')for(const a of audio)if(a!==e.target){a.pause();a.loop=false;}},true);
for(const b of document.querySelectorAll('.bucle'))b.onclick=()=>{parar();const a=b.closest('article').querySelector('audio');a.currentTime=0;a.loop=true;a.play().catch(()=>estado.textContent='No se pudo reproducir el archivo.');timer=setTimeout(()=>{a.pause();a.loop=false},10000)};
const key='magic-symbols-sfx-2026-11-25-tanda5';let guardado={};try{guardado=JSON.parse(localStorage.getItem(key)||'{}')}catch(e){};
function datos(){return Object.fromEntries(cards.map(a=>[a.dataset.id,{decision:a.querySelector('.decision').value,nota:a.querySelector('.nota').value}]))}
function guardar(){try{localStorage.setItem(key,JSON.stringify(datos()))}catch(e){estado.textContent='El navegador no permite guardar notas; copia el resumen antes de cerrar.'}}
for(const a of cards){const g=guardado[a.dataset.id];if(g){if(['Pendiente','Aceptado','Mejorable','A cambiar'].includes(g.decision))a.querySelector('.decision').value=g.decision;a.querySelector('.nota').value=typeof g.nota==='string'?g.nota:''}a.querySelector('.badge').textContent=a.querySelector('.decision').value==='Pendiente'?'Pendiente de tu validación':'Tu decisión: '+a.querySelector('.decision').value;a.querySelector('.decision').onchange=()=>{a.querySelector('.badge').textContent=a.querySelector('.decision').value==='Pendiente'?'Pendiente de tu validación':'Tu decisión: '+a.querySelector('.decision').value;guardar()};a.querySelector('.nota').oninput=guardar;}
function resumen(){const r=cards.filter(a=>a.querySelector('.decision').value!=='Pendiente'||a.querySelector('.nota').value.trim()).map(a=>a.dataset.id+' · '+a.querySelector('h2').textContent+': '+a.querySelector('.decision').value+(a.querySelector('.nota').value.trim()?' — '+a.querySelector('.nota').value.trim():''));document.querySelector('#resumen').value=r.length?r.join('\\n'):'Todavía no hay valoraciones.';return r.length}
document.querySelector('#preparar').onclick=()=>{resumen();estado.textContent='Resumen preparado; puedes copiarlo y enviarlo en el chat.'};document.querySelector('#copiar').onclick=async()=>{resumen();const t=document.querySelector('#resumen');try{await navigator.clipboard.writeText(t.value);estado.textContent='Copiado.'}catch(e){t.focus();t.select();estado.textContent='Texto seleccionado; pulsa Ctrl+C para copiar.'}};
</script></body></html>`;
let salida=html;const i=salida.indexOf('<details class="panel"><summary>Barrido histórico');const j=salida.indexOf('</details>',i);if(i>=0&&j>=0)salida=salida.slice(0,i)+salida.slice(j+10);fs.writeFileSync('docs/ESCUCHA_SFX_TANDA5_2026-11-25.html',salida);
fs.writeFileSync('output/auditoria_sfx_2026-11-25/tanda5.json',JSON.stringify(casos.map(x=>({...x,entrada:{catalogo:x.entrada.catalogo,nombre:x.entrada.nombre,files:x.entrada.files}})),null,2));
console.log('Creado catálogo de escucha: seis casos y barrido completo de '+all.length+' entradas.');
