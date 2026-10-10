"""Tripo GLBs write some accessor min/max as numbers instead of arrays; Blender refuses them."""
import json,struct,sys
src,dst=sys.argv[1],sys.argv[2]
d=open(src,'rb').read()
l=struct.unpack('<I',d[12:16])[0]; j=json.loads(d[20:20+l]); rest=d[20+l:]
bad=0
for i,a in enumerate(j['accessors']):
    for k in ('max','min'):
        if k in a and not isinstance(a[k],list):
            bad+=1; a[k]=[a[k]]
print('fixed',bad)
js=json.dumps(j,separators=(',',':')).encode()
js+=b' '*((4-len(js)%4)%4)
out=struct.pack('<4sII',b'glTF',2,12+8+len(js)+len(rest))+struct.pack('<I4s',len(js),b'JSON')+js+rest
open(dst,'wb').write(out)
