const fs=require('fs');
const actual=require('./catalogo.json'),historico=require('./barrido.json');
const all=actual.map(e=>({...e,metricas:historico.find(h=>h.catalogo===e.catalogo&&h.nombre===e.nombre)?.metricas||[],avisos:[],rango_rms_db:0}));
const casos=[
  {
    "id": 37,
    "n": "libro_abre",
    "cat": "Sfx",
    "titulo": "Apertura del libro y pantallas",
    "cuando": "Se abre el grimorio, diario u otras pantallas que reutilizan la apertura de libro; también aparece en la ceremonia del cofre.",
    "motivo": "Una toma de 1,01 s para una acción frecuente. El paso de páginas y el cierre ya están aceptados: conviene comprobar la coherencia entre los tres.",
    "propuesta": "Conservarla si comunica apertura y encaja con el papel elegido; recortarla o bajar nivel si la transición se siente demasiado larga.",
    "pregunta": "¿Parece que se abre un libro? ¿La duración y fuerza encajan con el paso de páginas aprobado?"
  },
  {
    "id": 38,
    "n": "bolsa",
    "cat": "Sfx",
    "titulo": "Abrir y cerrar el inventario",
    "cuando": "Se abre la bolsa o la pantalla de síntesis. Algunos cierres reutilizan la señal con tono ×0,85.",
    "motivo": "Una toma de 0,51 s que puede repetirse al consultar inventario. Revisar si comunica tela, bolsa o manejo de objetos sin sonar a una compra.",
    "propuesta": "Conservarla si encaja con la bolsa; ajustar textura, nivel o duración según tu valoración.",
    "pregunta": "¿Se reconoce como una bolsa o inventario? ¿Te resulta discreta al abrir y cerrar varias veces?"
  },
  {
    "id": 39,
    "n": "pocion",
    "cat": "Sfx",
    "titulo": "Beber una poción",
    "cuando": "Mientras la jugadora bebe se reproduce un bucle, que termina al acabar o interrumpir la acción.",
    "motivo": "El archivo dura 0,35 s y se repite. Escuchar una toma aislada no permite valorar su repetición: prueba también el botón de bucle.",
    "propuesta": "Valorar textura y repetición; ajustar el enlace si cada vuelta se reconoce demasiado.",
    "pregunta": "¿Comunica beber líquido? ¿El bucle resulta natural o se nota un patrón insistente?",
    "bucle": true
  },
  {
    "id": 40,
    "n": "cofre_revelado",
    "cat": "Sfx",
    "titulo": "Recompensa al abrir un cofre",
    "cuando": "Se lanza el logro de cofre abierto. Aunque el identificador dice revelado, esta entrada corresponde a la recompensa de apertura.",
    "motivo": "Una señal de 2,00 s. Revisar si la celebración aporta satisfacción y deja espacio a objetos recogidos u otros efectos.",
    "propuesta": "Conservarla si encaja con una recompensa; recortar cola o bajar nivel si domina la apertura.",
    "pregunta": "¿Encaja como recompensa de cofre? ¿Sobra duración, brillo o intensidad?"
  },
  {
    "id": 41,
    "n": "puzle_resuelto",
    "cat": "Sfx",
    "titulo": "Confirmación de puzle resuelto",
    "cuando": "Se completa un puzle y aparece su celebración visual.",
    "motivo": "Una señal de 0,78 s. Debe entenderse como éxito y distinguirse de la recompensa del cofre y de los clics cotidianos.",
    "propuesta": "Conservarla si comunica resolución con claridad; ajustar su carácter o intensidad si resulta demasiado pequeña o exagerada.",
    "pregunta": "¿Te transmite que el puzle está resuelto? ¿Encaja con la importancia del logro?"
  },
  {
    "id": 42,
    "n": "muerte",
    "cat": "Sfx",
    "titulo": "Señal de la pantalla de muerte",
    "cuando": "Aparece la pantalla de muerte de la jugadora. Es distinta del daño recibido y de las muertes de enemigos.",
    "motivo": "Una señal de 2,19 s. Revisar si acompaña el cierre de la partida sin resultar estridente al repetirse tras varios intentos.",
    "propuesta": "Conservarla si encaja con la pantalla; ajustar duración o nivel si añade demasiada carga a cada derrota.",
    "pregunta": "¿Encaja con la muerte de la jugadora? ¿Cambiarías su fuerza, tono o duración?"
  }
].map(x=>({...x,entrada:all.find(e=>e.nombre===x.n&&(!x.cat||e.catalogo===x.cat))}));
const esc=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
const fmt=x=>Number(x).toFixed(1).replace('.',',');
function player(e,f,tag='') {const m=e.metricas.find(x=>x.archivo===f);return `<div class="clip"><p><b>${esc(tag||f)}</b> <span>${fmt(m.duracion_s)} s · RMS ${fmt(m.rms_dbfs)} dBFS</span></p><audio controls preload="none" src="../audio/${encodeURIComponent(f)}" data-db="${e.cfg.db}" data-bus="${['comprar','ui_tick','recoger','paginas_bucle','ui_equipar','no_puedes_ui','libro_cierra','libro_abre','bolsa','muerte'].includes(e.nombre)?-6:0}" data-pitch="${e.cfg.base||e.cfg.pitch||1}"></audio></div>`;}
const cards=casos.map(x=>{const e=x.entrada,ff=x.clips||e.files;return `<article id="caso-${x.id}" data-id="${x.id}"><header><span class="num">${x.id}</span><div><h2>${x.titulo}</h2><code>${e.catalogo}.${e.nombre}</code></div><span class="badge">Pendiente de tu validación</span></header><p><b>Cuándo suena:</b> ${x.cuando}</p><p><b>Por qué lo revisaría:</b> ${x.motivo}</p><p><b>Mi propuesta provisional:</b> ${x.propuesta}</p><p class="pregunta">${x.pregunta}</p>${ff.map((f,i)=>player(e,f,ff.length>1?'Variante '+(i+1)+' · '+f:'')).join('')}${x.id===1?'<p class="detalle">Escucha los primeros seis segundos desde 0:00. El archivo completo es largo; no hace falta escucharlo entero.</p>':''}${x.bucle?'<button class="bucle" type="button">Escuchar diez segundos en bucle</button>':''}${e.files.some(f=>!ff.includes(f))?'<details><summary>Escuchar las otras variantes</summary>'+e.files.filter(f=>!ff.includes(f)).map(f=>player(e,f)).join('')+'</details>':''}<div class="valoracion"><label>Tu decisión<select class="decision"><option>Pendiente</option><option>Aceptado</option><option>Mejorable</option><option>A cambiar</option></select></label><label>Qué cambiarías<textarea class="nota" rows="2" placeholder="Por ejemplo: menos agudo, demasiado largo, no parece piedra…"></textarea></label></div></article>`}).join('\n');
const flags=all.filter(e=>e.avisos.length);
const table=all.map(e=>`<tr><td>${esc(e.catalogo+'.'+e.nombre)}</td><td>${e.files.length}</td><td>${fmt(e.rango_rms_db)}</td><td>${e.avisos.length?esc(e.avisos.join('; ')):'Sin aviso automático; pendiente de escucha'}</td><td>Pendiente</td></tr>`).join('');
const html=`<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Séptima escucha de SFX · 25 noviembre 2026</title><style>:root{color-scheme:dark}*{box-sizing:border-box}body{margin:0;background:#111820;color:#e6edf6;font:16px/1.6 system-ui}main{max-width:1050px;margin:auto;padding:36px 22px 90px}h1{font-size:34px;line-height:1.2}h2{font-size:23px;margin:0}h3{margin-bottom:8px}p{margin:10px 0}code{color:#b8c9df}nav{display:flex;gap:8px;flex-wrap:wrap;margin:20px 0}a{color:#9bccff}nav a,button{border:1px solid #4d6681;border-radius:8px;padding:8px 13px;background:#24374a;color:#edf4ff;font:inherit;text-decoration:none;cursor:pointer}.panel,article{background:#1b2633;border:1px solid #384d63;border-radius:14px;padding:23px;margin:22px 0}header{display:flex;align-items:center;gap:14px;flex-wrap:wrap}.num{font-size:25px;color:#8dc9ff}.badge{font-size:12px;padding:3px 9px;border:1px solid #7b6936;border-radius:20px;color:#e9d09c}.pregunta{border-left:3px solid #88c8ff;padding:10px 14px;background:#23394c}.clip{padding:8px 0}.clip p{font-size:14px}.clip span,.detalle{color:#aebfd2;font-size:14px}audio{width:100%}select,textarea{background:#0e1925;color:#f0f6ff;border:1px solid #56718e;border-radius:6px;padding:9px;font:inherit}textarea{display:block;width:100%}.valoracion{display:grid;grid-template-columns:190px 1fr;gap:18px;margin-top:20px}label{display:block}select{display:block;max-width:100%}details{margin:15px 0}summary{cursor:pointer;color:#9bccff}table{border-collapse:collapse;width:100%;font-size:13px}td,th{text-align:left;vertical-align:top;border-bottom:1px solid #364858;padding:9px}td:first-child{overflow-wrap:anywhere}#resumen{min-height:150px}#estado{color:#91d6b1}@media(max-width:650px){.valoracion{grid-template-columns:1fr}h1{font-size:28px}.panel,article{padding:17px}}</style></head><body><main><p>MAGIC SYMBOLS · 25 NOVIEMBRE 2026</p><h1>Séptima escucha de SFX</h1><p>Séptima tanda: seis efectos todavía sin validar. Comparamos las variantes actuales y su adecuación a la acción. Las cifras proceden del barrido técnico; no son una valoración del timbre.</p><p>La preselección se basa en mediciones y uso del código. <b>El revisor no ha escuchado los archivos.</b> Tu valoración cierra la parte artística. Continuamos con efectos distintos de los que ya validaste.</p><nav>${casos.map(x=>`<a href="#caso-${x.id}">${x.id} · ${x.titulo}</a>`).join('')}</nav><div class="panel"><h3>Modo de escucha</h3><label><select id="modo"><option value="original">Original con −3 dB comunes · comparar timbre</option><option value="juego">Ganancia de catálogo y bus · sin distancia ni oclusión</option></select></label><p class="detalle">Las variantes conservan sus diferencias de nivel: no se normalizan. El segundo modo aproxima solo ganancia y tono base. Para libro y bolsa se toma como referencia el uso en interfaz, con el bus a −6 dB; otros usos pueden sonar a otro nivel. No reproduce la escena ni la suma de capas, y las llamadas concretas pueden añadir otros cambios. Para valorar volumen, usa el modo de juego; el original aplica un margen común de −3 dB para comparar timbre sin saturar los picos de la señal. Al reproducir un clip se detienen los demás.</p><p class="detalle">Puedes marcar una decisión y escribir notas. Se guardan solo en este navegador; usa el resumen de abajo para enviármelas.</p></div>${cards}<section class="panel"><h2>Tu valoración para el chat</h2><p>Basta con decirme el número y qué te molesta. También puedes preparar aquí el resumen de las casillas que hayas rellenado.</p><button id="preparar" type="button">Preparar resumen</button> <button id="copiar" type="button">Copiar</button><textarea id="resumen" readonly aria-label="Resumen para enviar al chat"></textarea><p id="estado" role="status"></p></section><details class="panel"><summary>Barrido histórico · 25 noviembre, antes de los primeros ajustes</summary><p>El rango RMS es del archivo completo: las colas, silencios y duración influyen. No equivale a sonoridad percibida. Un pico Vorbis sobre 0 dBFS tampoco prueba distorsión después de la atenuación del juego. Sin aviso automático no significa aceptado.</p><div style="overflow:auto"><table><thead><tr><th>Entrada</th><th>Tomas</th><th>Rango RMS dB</th><th>Observación técnica</th><th>Validación</th></tr></thead><tbody>${table}</tbody></table></div></details><section class="panel"><h3>Alcance de la escucha</h3><p>Las muestras permiten validar timbre y comparar variantes. Para cerrar el balance final se necesita escucharlas junto al resto de capas del combate.</p><p>Esta tanda no modifica los archivos de sonido ni el juego. Datos completos en output/auditoria_sfx_2026-11-25/barrido.json.</p></section></main><script>
const audio=[...document.querySelectorAll('audio')],cards=[...document.querySelectorAll('article')],mode=document.querySelector('#modo'),estado=document.querySelector('#estado');let timer;
function ajustar(){for(const a of audio){a.volume=mode.value==='juego'?Math.min(1,10**((Number(a.dataset.db)+Number(a.dataset.bus))/20)):0.707945784; a.preservesPitch=false;a.playbackRate=mode.value==='juego'?Number(a.dataset.pitch):1;}}mode.onchange=ajustar;ajustar();
function parar(){clearTimeout(timer);for(const a of audio){a.pause();a.loop=false;}}
document.addEventListener('play',e=>{if(e.target.tagName==='AUDIO')for(const a of audio)if(a!==e.target){a.pause();a.loop=false;}},true);
for(const b of document.querySelectorAll('.bucle'))b.onclick=()=>{parar();const a=b.closest('article').querySelector('audio');a.currentTime=0;a.loop=true;a.play().catch(()=>estado.textContent='No se pudo reproducir el archivo.');timer=setTimeout(()=>{a.pause();a.loop=false},10000)};
const key='magic-symbols-sfx-2026-11-25-tanda7';let guardado={};try{guardado=JSON.parse(localStorage.getItem(key)||'{}')}catch(e){};
function datos(){return Object.fromEntries(cards.map(a=>[a.dataset.id,{decision:a.querySelector('.decision').value,nota:a.querySelector('.nota').value}]))}
function guardar(){try{localStorage.setItem(key,JSON.stringify(datos()))}catch(e){estado.textContent='El navegador no permite guardar notas; copia el resumen antes de cerrar.'}}
for(const a of cards){const g=guardado[a.dataset.id];if(g){if(['Pendiente','Aceptado','Mejorable','A cambiar'].includes(g.decision))a.querySelector('.decision').value=g.decision;a.querySelector('.nota').value=typeof g.nota==='string'?g.nota:''}a.querySelector('.badge').textContent=a.querySelector('.decision').value==='Pendiente'?'Pendiente de tu validación':'Tu decisión: '+a.querySelector('.decision').value;a.querySelector('.decision').onchange=()=>{a.querySelector('.badge').textContent=a.querySelector('.decision').value==='Pendiente'?'Pendiente de tu validación':'Tu decisión: '+a.querySelector('.decision').value;guardar()};a.querySelector('.nota').oninput=guardar;}
function resumen(){const r=cards.filter(a=>a.querySelector('.decision').value!=='Pendiente'||a.querySelector('.nota').value.trim()).map(a=>a.dataset.id+' · '+a.querySelector('h2').textContent+': '+a.querySelector('.decision').value+(a.querySelector('.nota').value.trim()?' — '+a.querySelector('.nota').value.trim():''));document.querySelector('#resumen').value=r.length?r.join('\\n'):'Todavía no hay valoraciones.';return r.length}
document.querySelector('#preparar').onclick=()=>{resumen();estado.textContent='Resumen preparado; puedes copiarlo y enviarlo en el chat.'};document.querySelector('#copiar').onclick=async()=>{resumen();const t=document.querySelector('#resumen');try{await navigator.clipboard.writeText(t.value);estado.textContent='Copiado.'}catch(e){t.focus();t.select();estado.textContent='Texto seleccionado; pulsa Ctrl+C para copiar.'}};
</script></body></html>`;
let salida=html;const i=salida.indexOf('<details class="panel"><summary>Barrido histórico');const j=salida.indexOf('</details>',i);if(i>=0&&j>=0)salida=salida.slice(0,i)+salida.slice(j+10);fs.writeFileSync('docs/ESCUCHA_SFX_TANDA7_2026-11-25.html',salida);
fs.writeFileSync('output/auditoria_sfx_2026-11-25/tanda7.json',JSON.stringify(casos.map(x=>({...x,entrada:{catalogo:x.entrada.catalogo,nombre:x.entrada.nombre,files:x.entrada.files}})),null,2));
console.log('Creado catálogo de escucha: seis casos y barrido completo de '+all.length+' entradas.');
