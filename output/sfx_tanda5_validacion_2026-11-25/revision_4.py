from pathlib import Path
import wave,json
import numpy as np
q=Path('output/sfx_tanda5_validacion_2026-11-25')
def leer(p):
 with wave.open(str(p)) as w:return w.getframerate(),np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').astype(float)/32768
def guardar(p,sr,x):
 with wave.open(str(p),'wb') as w:
  w.setparams((1,2,sr,0,'NONE','not compressed'));w.writeframes(np.round(np.clip(x,-1,1)*32767).astype('<i2').tobytes())
info=[]
for i,(src,gain) in enumerate([('goblin_muerte_fuente.wav',2),('goblin_muerte_b.wav',1),('goblin_muerte_c.wav',1)]):
 sr,x=leer(q/src);y=(x[:len(x)//2]*gain).copy()
 n=min(round(.008*sr),len(y));y[-n:]*=np.linspace(1,0,n)
 nombre=f'sn_goblin_muere_corto_{i}.wav';guardar(Path('audio')/nombre,sr,y)
 assert len(y)==len(x)//2
 assert np.allclose(y[:-n],(x*gain)[:len(y)-n])
 info.append({'archivo':nombre,'fuente':src,'duracion_antes_s':len(x)/sr,'duracion_s':len(y)/sr,'fundido_final_ms':8})
sr,x=leer(q/'referencia_madera_nueva.wav')
for i in range(0,len(x),4410):
 rms=max(float(np.sqrt(np.mean(x[i:i+4410]**2))),1e-9)
 print(round(i/sr,2),round(20*np.log10(rms),1))
recortes=[]
for nombre,ini,fin in [('madera_nueva_a.wav',.68,1.56),('madera_nueva_b.wav',2.07,2.68)]:
 y=x[round(ini*sr):round(fin*sr)].copy()
 a=round(.003*sr);b=round(.025*sr)
 y[:a]*=np.linspace(0,1,a);y[-b:]*=np.linspace(1,0,b)
 gain=min(1,10**(-3/20)/max(abs(y)));y*=gain
 guardar(q/nombre,sr,y)
 recortes.append({'archivo':nombre,'inicio_s':ini,'fin_s':fin,'ganancia_db':float(20*np.log10(gain)),'integrado':False})
(q/'revision_4_madera.json').write_text(json.dumps({'video':'20261125-1603-17.2680289.mp4','recortes':recortes,'procedencia':'Referencia facilitada por Pablo; autor y licencia originales no identificados'},ensure_ascii=False,indent=2),encoding='utf8')
(q/'revision_4_goblin.json').write_text(json.dumps({'variantes':info,'db':-18,'integrado':True},indent=2),encoding='utf8')
print(json.dumps(info,indent=2))
