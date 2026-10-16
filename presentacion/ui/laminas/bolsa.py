from lib import *
import tempfile
import sys, os, json
CUERO=(122,79,46,255); CUERO_S=(90,56,32,255); COSTURA=(210,176,122,255); PERG=(239,231,211,255); PERG_S=(227,220,201,255)
HEB=(224,194,106,255); INK=(78,58,38,255)

def silueta_pts(w, h):
    """Contorno de la bolsa (cuello arriba, panza abajo) en coordenadas 0..1 → lista de puntos."""
    pts=[]
    # mitad derecha por una curva y se refleja
    ctrl=[(0.30,0.10),(0.28,0.20),(0.36,0.30),(0.50,0.42),(0.60,0.58),(0.64,0.76),(0.58,0.90),(0.44,0.97),(0.30,0.98)]
    # catmull-rom simple
    def cr(p0,p1,p2,p3,t):
        return tuple(0.5*((2*p1[i])+(-p0[i]+p2[i])*t+(2*p0[i]-5*p1[i]+4*p2[i]-p3[i])*t*t+(-p0[i]+3*p1[i]-3*p2[i]+p3[i])*t**3) for i in (0,1))
    c=[ctrl[0]]+ctrl+[ctrl[-1]]
    for i in range(1,len(c)-2):
        for k in range(12): pts.append(cr(c[i-1],c[i],c[i+1],c[i+2],k/12))
    der=[(0.5+x*0.78/0.64*0.64 if False else 0.5+ (x-0.5)*1.0, y) for x,y in pts]
    return pts

def mascara(w,h,margen):
    """Máscara de la bolsa: cuello estrecho arriba, panza ancha, base redondeada."""
    m=Image.new("L",(w*SS,h*SS),0); d=ImageDraw.Draw(m)
    cx=w/2
    perfil=[]
    for i in range(0,201):
        t=i/200; y=h*(0.16+0.775*t)
        # semiancho: cuello 0.13w → hombros → panza 0.46w → base redonda
        if t<0.10: a=0.14+0.05*(t/0.10)
        elif t<0.55: a=0.19+0.27*math.sin((t-0.10)/0.45*math.pi/2)
        else: a=0.46*math.sqrt(max(0,1-((t-0.55)/0.45)**2))+0.0
        perfil.append((a*w-margen,y))
    pts=[(cx+a,y) for a,y in perfil]+[(cx-a,y) for a,y in reversed(perfil)]
    d.polygon(p(pts,SS),fill=255)
    return m

def bolsa(w,h):
    ext=mascara(w,h,0)
    im=Image.new("RGBA",ext.size,(0,0,0,0))
    # cuero
    cu=Image.new("RGBA",ext.size,CUERO); cu.putalpha(ext); im.alpha_composite(cu)
    # sombreado inferior del cuero
    grad=Image.new("L",ext.size,0); gd=ImageDraw.Draw(grad)
    for y in range(ext.size[1]): gd.line([(0,y),(ext.size[0],y)],fill=int(90*max(0,(y/ext.size[1]-0.5)*2)))
    sh=Image.new("RGBA",ext.size,CUERO_S); sh.putalpha(ImageChops.multiply(ext,grad)); im.alpha_composite(sh)
    # interior de pergamino (máscara más pequeña)
    marg=int(w*0.055)
    inte=mascara(w,h,marg)
    # recorte arriba: el cuello tapa la parte alta del interior
    top=Image.new("L",ext.size,0); ImageDraw.Draw(top).rectangle([0,int(h*0.27)*SS,ext.size[0],ext.size[1]],fill=255)
    inte=ImageChops.multiply(inte,top)
    pg=Image.new("RGBA",ext.size,PERG); pg.putalpha(inte); im.alpha_composite(pg)
    # sombra interior (borde del pergamino algo más oscuro)
    borde=ImageChops.subtract(inte,inte.filter(ImageFilter.MinFilter(int(w*0.03)*SS|1)))
    bs=Image.new("RGBA",ext.size,PERG_S); bs.putalpha(borde.filter(ImageFilter.GaussianBlur(3*SS))); im.alpha_composite(bs)
    # costura: línea de puntos siguiendo el borde del interior
    cos=Image.new("RGBA",ext.size,(0,0,0,0)); cd=ImageDraw.Draw(cos)
    cont=inte.filter(ImageFilter.MaxFilter(int(w*0.02)*SS|1))
    ring=ImageChops.subtract(cont,inte.filter(ImageFilter.MaxFilter(int(w*0.008)*SS|1)))
    # puntos: se modula el anillo con un patrón de rayas diagonales → costura discontinua
    pat=Image.new("L",ext.size,0); pd=ImageDraw.Draw(pat)
    paso=int(w*0.035)*SS
    for k in range(-ext.size[1],ext.size[0]+ext.size[1],paso): pd.line([(k,0),(k-ext.size[1],ext.size[1])],fill=255,width=paso//2)
    ring=ImageChops.multiply(ring,pat)
    cs=Image.new("RGBA",ext.size,COSTURA); cs.putalpha(ring); im.alpha_composite(cs)
    # cuello: cordón y lazo
    d=ImageDraw.Draw(im); cx=w*SS/2
    ny=int(h*0.205)*SS
    cap(d,(w*0.31,h*0.205),(w*0.69,h*0.205),h*0.018,(214,184,131,255),SS)
    elipse(d,(w*0.5,h*0.205),w*0.045,w*0.045,HEB,SS)
    for sg in (-1,1):
        d.polygon(p([(w*0.5,h*0.21),(w*(0.5+sg*0.12),h*0.265),(w*(0.5+sg*0.08),h*0.29),(w*0.5,h*0.23)],SS),fill=(214,184,131,255))
    # boca de la bolsa (pliegue superior): una elipse más clara en el cuello
    elipse(d,(w*0.5,h*0.16),w*0.17,h*0.03,CUERO_S,SS)
    elipse(d,(w*0.5,h*0.158),w*0.15,h*0.022,(60,38,22,255),SS)
    im=contorno(im,max(2,w/160),(70,40,24,255))
    return reducir(im,w,h), reducir(inte.convert("RGBA"),w,h).split()[0]

def anclas(masc, w, h):
    """Puntos de anclaje dentro del interior: filas que se estrechan hacia el cuello, 3→5 huecos."""
    px=masc.load(); filas=[]
    ys=[0.40,0.52,0.64,0.76,0.87]; cols=[2,3,4,4,3]
    for yf,n in zip(ys,cols):
        y=int(yf*h); xs=[x for x in range(w) if px[x,y]>128]
        if not xs: continue
        a,b=min(xs),max(xs); ancho=(b-a)*0.86; c=(a+b)/2
        fila=[round((c+(i-(n-1)/2)*ancho/max(1,n-1 if n>1 else 1)*((n-1)/n if n>1 else 0))/w,4) for i in range(n)]
        filas.append({"y":round(yf,3),"x":fila})
    return filas

def banda(w=480,h=72):
    im,d,ss=nuevo(w,h)
    cinta=(214,184,131,255); cinta_s=(188,152,98,255)
    d.polygon(p([(34,10),(w-34,10),(w-34,h-10),(34,h-10)],ss),fill=cinta)
    d.polygon(p([(34,h-22),(w-34,h-22),(w-34,h-10),(34,h-10)],ss),fill=cinta_s)
    for sg,x0 in ((-1,34),(1,w-34)):
        e=(x0+sg*30,h/2); d.polygon(p([(x0,10),(x0+sg*34,10),(x0+sg*18,h/2),(x0+sg*34,h-10),(x0,h-10)],ss),fill=cinta_s if sg<0 else cinta_s)
    d.line(p([(40,18),(w-40,18)],ss),fill=COSTURA,width=2*ss)
    d.line(p([(40,h-18),(w-40,h-18)],ss),fill=COSTURA,width=2*ss)
    im=contorno(im,2.4,(70,40,24,255)); return reducir(im,w,h)

if __name__=="__main__":
    out=sys.argv[1]; os.makedirs(out,exist_ok=True)
    meta={}
    for nombre,(w,h) in {"g":(640,720),"p":(320,360)}.items():
        b,m=bolsa(w,h); b.save(f"{out}/bolsa_silueta_{nombre}.png")
        mm=Image.new("RGBA",(w,h),(255,255,255,0)); mm.putalpha(m); mm.save(f"{out}/bolsa_interior_{nombre}.png")
        meta[nombre]={"tam":[w,h],"filas":anclas(m,w,h)}
    banda().save(f"{out}/bolsa_banda_nombre.png")
    json.dump(meta,open(f"{out}/bolsa_anclas.json","w"),indent=1)
    prev=Image.new("RGBA",(640+480+20,760),(60,60,70,255)); prev.alpha_composite(Image.open(f"{out}/bolsa_silueta_g.png"),(0,0)); prev.alpha_composite(Image.open(f"{out}/bolsa_banda_nombre.png"),(650,20))
    d=ImageDraw.Draw(prev)
    for f in meta["g"]["filas"]:
        for x in f["x"]: d.ellipse([x*640-30,f["y"]*720-30,x*640+30,f["y"]*720+30],outline=(255,0,0,255),width=2)
    prev.convert("RGB").save(tempfile.gettempdir() + "/prev_bolsa.png")
