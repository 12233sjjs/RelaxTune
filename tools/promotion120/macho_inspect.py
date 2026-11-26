import struct, json, pathlib, capstone, sys
class Mach:
 def __init__(self, data, base=0):
  self.data=data; self.base=base; self.d=data[base:]; d=self.d
  assert d[:4]==bytes.fromhex('cffaedfe')
  self.cpu,self.sub,self.ft,self.ncmd,self.szcmd,self.flags,_=struct.unpack_from('<7I',d,4)
  self.sections=[]; self.segments=[]; self.commands=[]; self.symbols=[]; self.syms={}; self.cs={}; self.ptrs={}; self.binds={}; self.stubs={}
  p=32; symtab=None
  for i in range(self.ncmd):
   cmd,sz=struct.unpack_from('<II',d,p); self.commands.append((cmd,p,sz))
   if cmd==0x19:
    _,_,seg,vm,vms,fo,fs,ma,init,ns,fl=struct.unpack_from('<II16sQQQQIIII',d,p)
    self.segments.append(dict(seg=seg.rstrip(b'\0').decode(),vm=vm,vms=vms,off=fo,size=fs,prot=init))
    for j in range(ns):
     vals=struct.unpack_from('<16s16sQQIIIIIIII',d,p+72+j*80)
     name,seg,addr,size,off,align,relo,nrel,flags,r1,r2,r3=vals
     s=dict(name=name.rstrip(b'\0').decode(),seg=seg.rstrip(b'\0').decode(),addr=addr,size=size,off=off,flags=flags,r1=r1,r2=r2);self.sections.append(s)
     if s['name'] in ('__cstring','__objc_methname','__objc_classname','__objc_methtype'):
      at=off
      while at<off+size:
       e=d.find(b'\0',at);e=off+size if e<0 else e
       self.cs[addr+at-off]=d[at:e].decode('utf8','replace');at=e+1
   elif cmd==2:symtab=struct.unpack_from('<IIII',d,p+8)
   p+=sz
  if symtab:
   so,nsy,st,sts=symtab
   for j in range(nsy):
    si,t,se,desc,val=struct.unpack_from('<IBBHQ',d,so+j*16);e=d.find(b'\0',st+si)
    name=d[st+si:e].decode('utf8','replace');self.symbols.append(dict(name=name,type=t,sec=se,desc=desc,addr=val))
    if val:self.syms.setdefault(val,[]).append(name)
  self.imports=[]; self.chained=False
  for cmd,p,sz in self.commands:
   if cmd==0x80000034:
    self.chained=True; fixoff,fixsize=struct.unpack_from('<II',d,p+8)
    version,starts,imports,symbols,count,fmt,symfmt=struct.unpack_from('<7I',d,fixoff)
    for j in range(count):
     stride={1:4,2:8,3:16}[fmt];v=struct.unpack_from('<Q' if fmt==3 else '<I',d,fixoff+imports+j*stride)[0]
     no=(v>>32) if fmt==3 else (v>>9);at=fixoff+symbols+no;e=d.index(0,at);self.imports.append(d[at:e].decode())
  for s in self.sections:
   if s['name'] in ('__objc_selrefs','__objc_classrefs','__objc_superrefs','__mod_init_func','__got','__la_symbol_ptr'):
    for at in range(0,s['size'],8):
     addr=s['addr']+at;raw=struct.unpack_from('<Q',d,s['off']+at)[0]
     if self.chained and raw>>63:
      idx=raw&0xffffff
      if idx<len(self.imports):self.binds[addr]=self.imports[idx]
     else:self.ptrs[addr]=(raw&0xfffffffff) if self.chained else raw
   if s['name']=='__cfstring':
    for at in range(0,s['size'],32):
     _,_,ptr,ln=struct.unpack_from('<QQQQ',d,s['off']+at)
     if self.chained:ptr&=0xfffffffff
     self.cs[s['addr']+at]='@'+self.cs.get(ptr,f'{ptr:#x}/{ln}')
  self.parse_bind()
  for cmd,p,sz in self.commands:
   if cmd==0xb:
    fields=struct.unpack_from('<18I',d,p+8);indoff,nind=fields[12:14];inds=struct.unpack_from('<'+'I'*nind,d,indoff)
    for s in self.sections:
     if s['name'] in ('__stubs','__auth_stubs','__la_symbol_ptr','__got','__auth_got'):
      step=s['r2'] if s['flags']&0xff==8 else 8
      if not step:continue
      for j in range(s['size']//step):
       k=s['r1']+j
       if k<len(inds) and inds[k]<len(self.symbols):self.stubs[s['addr']+j*step]=self.symbols[inds[k]]['name']
  for s in self.sections:
   if s['name']=='__objc_stubs':
    md=capstone.Cs(capstone.CS_ARCH_ARM64,capstone.CS_MODE_LITTLE_ENDIAN);md.detail=True
    for at in range(0,s['size'],32):
     ins=list(md.disasm(d[s['off']+at:s['off']+at+8],s['addr']+at))
     if len(ins)==2 and ins[0].mnemonic=='adrp' and ins[1].mnemonic=='ldr':
      addr=ins[0].operands[1].imm+ins[1].operands[1].mem.disp
      self.stubs[s['addr']+at]='objc_msgSend$'+self.cs.get(self.ptrs.get(addr,0),f'{addr:#x}')
 def off(self,va):
  for s in self.segments:
   if s['vm']<=va<s['vm']+s['size']:return va-s['vm']+s['off']
  raise ValueError(hex(va))
 def parse_bind(self):
  for cmd,p,sz in self.commands:
   if cmd not in (0x22,0x80000022):continue
   vals=struct.unpack_from('<10I',self.d,p+8)
   for off,size in (vals[2:4],vals[4:6],vals[6:8]):
    pos=off;end=off+size;seg=0;addr=0;name=''
    def ul():
     nonlocal pos
     val=0;sh=0
     while True:
      x=self.d[pos];pos+=1;val|=(x&127)<<sh;sh+=7
      if x<128:return val
    def bind():self.binds[self.segments[seg]['vm']+addr]=name
    while pos<end:
     v=self.d[pos];pos+=1;op=v&0xf0;im=v&15
     if op==0x00:continue
     elif op==0x10:pass
     elif op==0x20:ul()
     elif op==0x30:pass
     elif op==0x40:e=self.d.index(0,pos);name=self.d[pos:e].decode();pos=e+1
     elif op==0x50:pass
     elif op==0x60:ul()
     elif op==0x70:seg=im;addr=ul()
     elif op==0x80:addr+=ul()
     elif op==0x90:bind();addr+=8
     elif op==0xa0:bind();addr+=8+ul()
     elif op==0xb0:bind();addr+=8+im*8
     elif op==0xc0:
      count,skip=ul(),ul()
      for j in range(count):bind();addr+=8+skip
     else:break
 def label(self,addr):
  if addr in self.cs:return repr(self.cs[addr])
  if addr in self.syms:return '|'.join(self.syms[addr])
  if addr in self.stubs:return self.stubs[addr]
  if addr in self.binds:return self.binds[addr]
  if addr in self.ptrs:return f'ptr->{self.ptrs[addr]:#x} '+self.label(self.ptrs[addr])
  return ''
 def disasm(self,start=None,end=None):
  s=next(s for s in self.sections if s['name']=='__text');start=s['addr'] if start is None else start;end=s['addr']+s['size'] if end is None else end
  md=capstone.Cs(capstone.CS_ARCH_ARM64,capstone.CS_MODE_LITTLE_ENDIAN);md.detail=True;md.skipdata=True
  regs={};out=[]
  for i in md.disasm(self.d[self.off(start):self.off(end-1)+1],start):
   lab=self.label(i.address)
   if lab:out.append('\n'+lab+':')
   notes=[]
   if i.id:
    ops=i.operands
    for op in ops:
     if op.type==capstone.arm64.ARM64_OP_IMM and op.imm>256:
      text=self.label(op.imm)
      if text:notes.append(text)
    if i.mnemonic=='adrp':regs[i.reg_name(ops[0].reg)]=ops[1].imm
    elif i.mnemonic=='adr':regs[i.reg_name(ops[0].reg)]=ops[1].imm
    elif i.mnemonic=='add' and len(ops)>2 and ops[2].type==capstone.arm64.ARM64_OP_IMM:
     rd,rn=i.reg_name(ops[0].reg),i.reg_name(ops[1].reg)
     if rn in regs:
      regs[rd]=regs[rn]+ops[2].imm;text=self.label(regs[rd]);notes+=([hex(regs[rd])+' '+text] if text else [])
    elif i.mnemonic.startswith(('ldr','ldur')) and len(ops)>1 and ops[1].type==capstone.arm64.ARM64_OP_MEM:
     mem=ops[1].mem;rn=i.reg_name(mem.base)
     if rn in regs:
      addr=regs[rn]+mem.disp;text=self.label(addr);notes+=([hex(addr)+' '+text] if text else []);regs.pop(i.reg_name(ops[0].reg),None)
    elif i.mnemonic in ('b','ret','retab'):regs={}
   out.append(f'{i.address:08x} {i.bytes.hex():8s} {i.mnemonic:10s} {i.op_str:44s}'+(' ; '+' / '.join(dict.fromkeys(notes)) if notes else ''))
  return '\n'.join(out)

def slices(data):
 if data[:4]==bytes.fromhex('cafebabe'):
  return [(sub,off,size) for cpu,sub,off,size,al in (struct.unpack_from('>IIIII',data,8+20*i) for i in range(struct.unpack_from('>I',data,4)[0]))]
 return [(struct.unpack_from('<I',data,8)[0],0,len(data))]
if __name__=='__main__':
 p=pathlib.Path(sys.argv[1]);data=p.read_bytes();out=pathlib.Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=True)
 for sub,off,size in slices(data):
  m=Mach(data,off);name=f'{p.stem}-{sub:08x}'
  (out/(name+'.json')).write_text(json.dumps(dict(base=off,size=size,cpu=m.cpu,sub=sub,sections=m.sections,segments=m.segments,symbols=m.symbols,strings=m.cs,binds=m.binds,stubs=m.stubs,pointers=m.ptrs),ensure_ascii=False,indent=2))
  (out/(name+'.asm')).write_text(m.disasm())
  print(name,'base',hex(off),'size',hex(size),'text',[(s['addr'],s['size']) for s in m.sections if s['name']=='__text'])
