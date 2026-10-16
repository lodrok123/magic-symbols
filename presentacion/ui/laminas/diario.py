from lib import *
import tempfile
import sys, os, random
PERG=(239,231,211,255); PERG_S=(222,208,176,255); PERG_C=(246,239,222,255); BORDE=(139,111,78,255); INK=(78,58,38,255)
ORO=(230,190,80,255); PLATA=(176,186,204,255)

def pergamino(w=900,h=1000):
    im,d,ss=nuevo(w,h,2)
    r=random.Random(9)
    # hoja con borde ondulado
    def borde(x0,y0,x1,y1,amp):
        pts=[]
        for t in range(0,41): pts.append((x0+(x1-x0)*t/40,y0+r.uniform(-amp,amp)))
        for t in range(0,41): pts.append((x1+r.uniform(-amp,amp),y0+(y1-y0)*t/40))
        for t in range(40,-1,-1): pts.append((x0+(x1-x0)*t/40,y1+r.uniform(-amp,amp)))
        for t in range(40,-1,-1): pts.append((x0+r.uniform(-amp,amp),y0+(y1-y0)*t/40))
        return pts
    d.polygon(p(borde(60,70,w-60,h-70,5),ss),fill=PERG)
    # manchas de envejecido
    capa=Image.new("RGBA",im.size,(0,0,0,0)); cd=ImageDraw.Draw(capa)
    for i in range(60):
        cx,cy=r.uniform(70,w-70),r.uniform(80,h-80); rr=r.uniform(30,110)
        cd.ellipse([(cx-rr)*ss,(cy-rr)*ss,(cx+rr)*ss,(cy+rr)*ss],fill=(200,170,120,r.randint(8,22)))
    capa=capa.filter(ImageFilter.GaussianBlur(14)); m=im.split()[3]
    capa.putalpha(ImageChops.multiply(capa.split()[3],m)); im.alpha_composite(capa)
    d=ImageDraw.Draw(im)
    # marco fino interior
    d.rectangle([110*ss,120*ss,(w-110)*ss,(h-120)*ss],outline=(190,165,125,255),width=2*ss)
    # rollos arriba y abajo
    for y in (50,h-90):
        d.rounded_rectangle([30*ss,y*ss,(w-30)*ss,(y+44)*ss],radius=22*ss,fill=PERG_C)
        d.rounded_rectangle([30*ss,(y+24)*ss,(w-30)*ss,(y+44)*ss],radius=10*ss,fill=PERG_S)
        for x in (30,w-30): elipse(d,(x,y+22),20,22,PERG_S,ss); elipse(d,(x,y+22),9,10,(120,92,60,255),ss)
    im=contorno(im,2.4,(104,78,50,255))
    return reducir(im,w,h)

def icono_principal(s=64):
    im,d,ss=nuevo(s,s)
    # escudo dorado con exclamación
    d.polygon(p([(32,6),(56,14),(54,38),(32,58),(10,38),(8,14)],ss),fill=ORO)
    d.polygon(p([(32,6),(56,14),(54,38),(32,58)],ss),fill=(205,160,50,255))
    d.rounded_rectangle([29*ss,16*ss,35*ss,36*ss],radius=3*ss,fill=INK); elipse(d,(32,44),3.4,3.4,INK,ss)
    return reducir(contorno(im,2.0,(104,78,40,255)),s,s)

def icono_secundaria(s=64):
    im,d,ss=nuevo(s,s)
    # pergamino enrollado plateado con una pluma
    d.rounded_rectangle([12*ss,14*ss,50*ss,50*ss],radius=6*ss,fill=PERG)
    d.rounded_rectangle([8*ss,10*ss,56*ss,20*ss],radius=5*ss,fill=PLATA); d.rounded_rectangle([8*ss,46*ss,56*ss,56*ss],radius=5*ss,fill=PLATA)
    for y in (28,34,40): d.line(p([(18,y),(44,y)],ss),fill=INK,width=2*ss)
    return reducir(contorno(im,2.0,(86,92,110,255)),s,s)

def seguida(s=32):
    im,d,ss=nuevo(s,s)
    elipse(d,(16,16),12,12,(255,255,255,255),ss); elipse(d,(16,16),7,7,(200,60,50,255),ss)
    return reducir(contorno(im,1.6,(104,60,40,255)),s,s)

def casilla(hecha,s=28):
    im,d,ss=nuevo(s,s)
    d.rounded_rectangle([3*ss,3*ss,25*ss,25*ss],radius=4*ss,fill=PERG_C)
    im=contorno(im,1.8,(104,78,50,255)); d=ImageDraw.Draw(im)
    if hecha:
        d.line(p([(7,15),(12,21),(22,7)],ss),fill=(60,120,70,255),width=int(3.2*ss)); 
    return reducir(im,s,s)

if __name__=="__main__":
    out=sys.argv[1]; os.makedirs(out,exist_ok=True)
    pergamino().save(f"{out}/diario_pergamino.png")
    icono_principal().save(f"{out}/diario_icono_principal.png"); icono_secundaria().save(f"{out}/diario_icono_secundaria.png")
    seguida().save(f"{out}/diario_seguida.png"); casilla(False).save(f"{out}/diario_casilla.png"); casilla(True).save(f"{out}/diario_casilla_hecha.png")
    prev=Image.new("RGBA",(1100,1000),(60,60,70,255)); prev.alpha_composite(Image.open(f"{out}/diario_pergamino.png"),(0,0))
    x=920
    for n in ("diario_icono_principal","diario_icono_secundaria","diario_seguida","diario_casilla","diario_casilla_hecha"):
        im=Image.open(f"{out}/{n}.png"); prev.alpha_composite(im,(x,60)); x=x if False else x; 
        prev.alpha_composite(im,(920,60+['diario_icono_principal','diario_icono_secundaria','diario_seguida','diario_casilla','diario_casilla_hecha'].index(n)*80))
    prev.convert("RGB").save(tempfile.gettempdir() + "/prev_diario.png")
