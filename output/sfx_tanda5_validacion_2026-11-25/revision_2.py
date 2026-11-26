from pathlib import Path
import wave,json
import numpy as np
q=Path('output/sfx_tanda5_validacion_2026-11-25');sr=44100
def leer(n):
 with wave.open(str(q/n)) as w:return np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').astype(float)/32768
def guardar(n,x,rms=None):
 x=x.copy(); a=min(66,len(x)//2);b=min(660,len(x)//2)
 x[:a]*=np.linspace(0,1,a);x[-b:]*=np.linspace(1,0,b)
 if rms is not None:x*=10**(rms/20)/max(np.sqrt(np.mean(x*x)),1e-9)
 x*=min(1,10**(-4/20)/max(abs(x)))
 with wave.open(str(q/n),'wb') as w:w.setparams((1,2,sr,0,'NONE','not compressed'));w.writeframes(np.round(x*32767).astype('<i2').tobytes())
 return {'archivo':n,'duracion_s':len(x)/sr,'pico_db':float(20*np.log10(max(abs(x))))}
corte=leer('corte_madera_fuente.wav'); media=leer('madera_media_fuente.wav')
rng=np.random.default_rng(2511252602);info=[]
for n,d,impulsos in [('escudo_fractura_c.wav',.24,[(0,1),(.018,.5),(.052,.25)]),('escudo_fractura_d.wav',.34,[(0,.8),(.035,.6),(.092,.35),(.15,.16)])]:
 x=np.zeros(round(d*sr))
 for inicio,g in impulsos:
  i=round(inicio*sr);t=np.arange(round(.045*sr))/sr
  ruido=rng.normal(size=len(t));f=np.fft.rfftfreq(len(t),1/sr)
  ruido=np.fft.irfft(np.fft.rfft(ruido)*np.exp(-(f/6500)**4)*(1-np.exp(-(f/450)**4)),len(t))
  golpe=ruido*np.exp(-t/.006)*g
  x[i:i+len(golpe)]+=golpe
 # Capa corta de corte de madera real; ninguna fuente de bisagra/crujido.
 nframes=min(round(.10*sr),len(corte));x[:nframes]+=corte[:nframes]*1.2
 info.append(guardar(n,x,-23))
voz=leer('goblin_muerte_fuente.wav')*2 # deshacer el margen de decodificación, sin normalizar
for n,ini,fin,vel in [('goblin_muerte_b.wav',0,1.16,1.06),('goblin_muerte_c.wav',.28,1.56,.94)]:
 x=voz[round(ini*sr):round(fin*sr)];x=np.interp(np.arange(0,len(x)-1,vel),np.arange(len(x)),x)
 info.append(guardar(n,x))
(q/'revision_2_metricas.json').write_text(json.dumps(info,indent=2),encoding='utf8')
print(json.dumps(info,indent=2))
