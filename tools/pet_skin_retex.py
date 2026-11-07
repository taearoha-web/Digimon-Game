# Gradient-map recolour of KayKit palette atlas cells (used for the pet skins, see
# assets/vendor/pets/SOURCE.json). usage: python3 tools/pet_skin_retex.py src.png out.png '<spec json>'
import sys,json
from PIL import Image
import numpy as np
src,out,spec=sys.argv[1],sys.argv[2],json.loads(sys.argv[3])
im=np.asarray(Image.open(src).convert('RGBA')).astype(np.float32)/255
H,W=im.shape[:2]
def hexc(h): h=h.lstrip('#'); return np.array([int(h[i:i+2],16)/255 for i in (0,2,4)],np.float32)
for r in spec:
    if 'cell' in r:
        c,row=r['cell']; gx,gy=r.get('grid',[8,4]); cw,ch=W//gx,H//gy
        x0,y0,x1,y1=c*cw,row*ch,(c+1)*cw,(row+1)*ch
    else: x0,y0,x1,y1=r['rect']
    reg=im[y0:y1,x0:x1,:3]
    l=reg@np.array([0.299,0.587,0.114],np.float32)
    lo,hi=float(l.min()),float(l.max()); rng=max(hi-lo,0.15)
    t=np.clip((l-lo)/rng,0,1)[...,None]
    stops=[hexc(s) for s in r['ramp']]
    n=len(stops)-1; idx=np.minimum((t*n).astype(int),n-1); f=t*n-idx
    S=np.stack(stops); a=S[idx[...,0]]; b=S[idx[...,0]+1]
    im[y0:y1,x0:x1,:3]=a*(1-f)+b*f
Image.fromarray((np.clip(im,0,1)*255).astype(np.uint8)).save(out); print('wrote',out)
