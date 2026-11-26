import wave,json
from pathlib import Path
import numpy as np
q=Path('output/sfx_tanda4_validacion_2026-11-25');sr=44100

def fade(x,ms=4):
 x=x.copy();n=min(round(sr*ms/1000),len(x)//2)
 x[:n]*=np.linspace(0,1,n);x[-n:]*=np.linspace(1,0,n);return x

def escribir(nombre,x,origen):
 x=x-np.mean(x);x=fade(x)
 x*=min(10**(-30/20)/max(np.sqrt(np.mean(x*x)),1e-10),10**(-15/20)/max(abs(x)))
 with wave.open(str(q/(nombre+'.wav')),'wb') as w:
  w.setparams((1,2,sr,0,'NONE','not compressed'));w.writeframes(np.round(x*32767).astype('<i2').tobytes())
 return {'archivo':nombre+'.wav','segundos':len(x)/sr,'rms_dbfs':float(20*np.log10(np.sqrt(np.mean(x*x)))),'origen':origen,'integrado':False}

with wave.open(str(q/'back_fuente.wav')) as w:raw=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').astype(float)/32768
f=np.fft.rfftfreq(len(raw),1/sr);a=np.fft.irfft(np.fft.rfft(raw)*np.exp(-(f/1600)**4),len(raw))
info=[escribir('rechazo_a',a,'Kenney Interface Sounds / back_001.ogg, CC0; filtro suave a 1,6 kHz')]
n=round(.18*sr);b=np.zeros(n)
for comienzo,fr,largo in [(0,330,.065),(.075,275,.085)]:
 t=np.arange(round(largo*sr))/sr;env=np.sin(np.pi*np.minimum(1,t/largo))**2
 z=np.sin(2*np.pi*fr*t)*env;i=round(comienzo*sr);b[i:i+len(z)]+=z
info.append(escribir('rechazo_b',b,'Sintesis propia: dos notas bajas descendentes, 330 y 275 Hz'))
t=np.arange(round(.09*sr))/sr;rng=np.random.default_rng(251124)
x=rng.normal(size=len(t));f=np.fft.rfftfreq(len(x),1/sr)
x=np.fft.irfft(np.fft.rfft(x)*np.exp(-(f/850)**4),len(x));x*=(1-np.exp(-t/.002))*np.exp(-t/.018)
info.append(escribir('rechazo_c',x,'Sintesis propia: ruido filtrado grave con envolvente corta'))
(q/'alternativas_19.json').write_text(json.dumps(info,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(info,ensure_ascii=False,indent=2))
