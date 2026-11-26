"""Mach-O embedded ad-hoc CodeDirectory verification and page rehashing."""
import hashlib, struct
from macho_inspect import slices, Mach

def directories(data):
 result=[]
 for sub,base,size in slices(data):
  m=Mach(data,base)
  for cmd,p,cs in m.commands:
   if cmd!=0x1d:continue
   so,ss=struct.unpack_from('<II',data,base+p+8);so+=base
   magic,length,count=struct.unpack_from('>III',data,so)
   assert magic==0xfade0cc0 and length<=ss
   blobs={}
   for j in range(count):
    typ,off=struct.unpack_from('>II',data,so+12+8*j);bm,bl=struct.unpack_from('>II',data,so+off);blobs[typ]=(bm,so+off,bl)
   for typ,(bm,off,bl) in blobs.items():
    if bm!=0xfade0c02:continue
    ver,flags,ho,ident,nsp,ncode,lim=struct.unpack_from('>7I',data,off+8)
    hs,ht,plat,ps=data[off+36:off+40]
    if lim==0xffffffff and ver>=0x20300:lim=struct.unpack_from('>Q',data,off+56)[0]
    assert ht in (1,2,3,4) and ps>0 and ncode==(lim+(1<<ps)-1)//(1<<ps)
    assert lim<=size and ho+ncode*hs<=bl
    result.append(dict(base=base,sub=sub,off=off,length=bl,type=typ,flags=flags,hashoff=ho,hs=hs,ht=ht,ps=ps,limit=lim,ncode=ncode,nsp=nsp,blobs=blobs))
 assert result
 return result

def digest(data,cd):
 return {1:hashlib.sha1,2:hashlib.sha256,3:hashlib.sha256,4:hashlib.sha384}[cd['ht']](data).digest()[:cd['hs']]

def verify(data):
 n=0;special=0;out=[]
 for cd in directories(data):
  for i in range(cd['ncode']):
   start=cd['base']+(i<<cd['ps']);end=cd['base']+min((i+1)<<cd['ps'],cd['limit']);pos=cd['off']+cd['hashoff']+i*cd['hs']
   assert data[pos:pos+cd['hs']]==digest(data[start:end],cd),(hex(cd['base']),cd['type'],i)
   n+=1
  for i in range(1,cd['nsp']+1):
   pos=cd['off']+cd['hashoff']-i*cd['hs'];stored=data[pos:pos+cd['hs']]
   if i in cd['blobs']:
    _,off,size=cd['blobs'][i];assert stored==digest(data[off:off+size],cd),(i,'special hash mismatch');special+=1
   elif i in (2,5,7):assert not any(stored),(i,'unexpected external special-slot data')
  out.append({k:v for k,v in cd.items() if k!='blobs'})
 return dict(code_pages=n,embedded_special_slots=special,directories=out)

def rehash(data):
 changed=[]
 for cd in directories(data):
  for i in range(cd['ncode']):
   start=cd['base']+(i<<cd['ps']);end=cd['base']+min((i+1)<<cd['ps'],cd['limit']);pos=cd['off']+cd['hashoff']+i*cd['hs'];h=digest(data[start:end],cd)
   if data[pos:pos+cd['hs']]!=h:
    data[pos:pos+cd['hs']]=h;changed.append(dict(base=cd['base'],directory=cd['type'],page=i,pos=pos,size=cd['hs']))
 return changed
