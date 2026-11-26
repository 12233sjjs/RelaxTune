#!/usr/bin/env python3
"""Reproducible 0.5 -> 0.5.1 ProMotion adapter, pinned to the supplied inputs.
This patches binaries; it does not claim to compile or device-test iOS code.
"""
import argparse, copy, gzip, hashlib, io, json, lzma, math, os, pathlib, plistlib, shutil, struct, subprocess, tarfile
from macho_inspect import Mach
from codesign_util import verify, rehash
HERE=pathlib.Path(__file__).resolve().parent
INPUT1='d5130ca773d45b45ca48e61781b88365a0492b93eec3ce84519d389c348b8403'
INPUT2='b96bfa462178b034897400cec04cdbd334a27453f8582f6738de0dc6e7c741ff'
DYLDIR='Library/MobileSubstrate/DynamicLibraries/'
LIB=DYLDIR+'RelaxTune.dylib'
HELPER=DYLDIR+'RelaxTuneProMotion120.dylib'
HELPER_PLIST=DYLDIR+'RelaxTuneProMotion120.plist'
PREFS='Library/PreferenceBundles/RelaxTunePrefs.bundle/Root.plist'
SETTINGS_LABEL='ProMotion 120Hz（重启生效）'
SETTINGS_FOOTER='120Hz改用ProMotion 1.0.14-1原始实现。更改总开关或120Hz开关后，须重载SpringBoard并重新打开App；其他设置仍按原逻辑生效。'
SPECS=[dict(name='arm64',base=0x4000,helper=0x6f08,callback=0x72e0,ctor=0x7604,body=0x761c,epilogue=0x777c,settings=0x7c10,dlsym=0x81fc,pac=0),dict(name='arm64e',base=0x1c000,helper=0x72bc,callback=0x76ec,ctor=0x7a3c,body=0x7a58,epilogue=0x7bd8,settings=0x810c,dlsym=0x8778,pac=1)]
def sha(b):return hashlib.sha256(b).hexdigest()
def run(args):return subprocess.run([str(x) for x in args],check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
def branch(pc,target,link=False):
 d=target-pc;assert d%4==0 and -(1<<27)<=d<(1<<27)
 return (0x94000000 if link else 0x14000000)|((d>>2)&0x3ffffff)
def manifest(root):
 return {p.relative_to(root).as_posix():dict(sha256=sha(p.read_bytes()),mode=oct(p.stat().st_mode&0o777),bytes=p.stat().st_size) for p in sorted(root.rglob('*')) if p.is_file()}
def make_loader(spec,out):
 text=(HERE/'loader.S.in').read_text().replace('BODY_VA',hex(spec['body'])).replace('AUTH_CALL',str(spec['pac']))
 asm=out/(spec['name']+'-loader.S');obj=asm.with_suffix('.o');raw=asm.with_suffix('.bin');asm.write_text(text)
 run(['as','-o',obj,asm]);run(['objcopy','-O','binary','--only-section=.text',obj,raw])
 code=bytearray(raw.read_bytes()[spec['body']:]);assert len(code)<=spec['epilogue']-spec['body']
 assert struct.unpack_from('<I',code,0)[0]==0x94000000
 assert struct.unpack_from('<I',code,40)[0]==0x94000000
 assert struct.unpack_from('<I',code,64)[0]==0x14000000
 for at,target,link in [(0,spec['settings'],True),(40,spec['dlsym'],True),(64,spec['epilogue'],False)]:struct.pack_into('<I',code,at,branch(spec['body']+at,target,link))
 pc=spec['body']+4;delta=(0x10000-(pc&~4095))>>12
 struct.pack_into('<I',code,4,0x90000008|((delta&3)<<29)|(((delta>>2)&0x7ffff)<<5))
 raw.write_bytes(code)
 return code

def archive_members(package, control=False):
 flag='--ctrl-tarfile' if control else '--fsys-tarfile'
 raw=run(['dpkg-deb',flag,package]).stdout
 with tarfile.open(fileobj=io.BytesIO(raw)) as tf:
  return [copy.copy(t) for t in tf.getmembers()]
def ar_members(package):
 data=package.read_bytes();assert data[:8]==b'!<arch>\n';pos=8;items=[]
 while pos<len(data):
  hdr=data[pos:pos+60];assert len(hdr)==60 and hdr[58:60]==b'`\n'
  n=int(hdr[48:58]);name=hdr[:16].decode().strip().rstrip('/')
  items.append((name,hdr,data[pos+60:pos+60+n]));pos+=60+n+(n%2)
 assert pos==len(data);return items
def build_preserving_metadata(package1,package2,root,target):
 donor={t.name.lstrip('./'):t for t in archive_members(package2) if t.isfile()}
 source={control:archive_members(package1,control) for control in (False,True)}
 packed={}
 for control,members in source.items():
  if not control:
   for new,old in [(HELPER,DYLDIR+'ProMotion120.dylib'),(HELPER_PLIST,DYLDIR+'ProMotion120.plist')]:
    t=copy.copy(donor[old]);t.name='./'+new;members.append(t)
  stream=io.BytesIO()
  with tarfile.open(fileobj=stream,mode='w',format=tarfile.GNU_FORMAT) as tf:
   for original in members:
    t=copy.copy(original);rel=t.name.removeprefix('./').rstrip('/')
    assert not pathlib.PurePosixPath(rel).is_absolute() and '..' not in pathlib.PurePosixPath(rel).parts
    path=(root/'DEBIAN' if control else root)/rel
    if t.isfile():
     value=path.read_bytes();t.size=len(value);tf.addfile(t,io.BytesIO(value))
    else:tf.addfile(t)
  packed[control]=stream.getvalue()
 output=bytearray(b'!<arch>\n')
 for name,hdr,value in ar_members(package1):
  if name.startswith(('control.tar','data.tar')):
   raw=packed[name.startswith('control.tar')]
   if name.endswith('.gz'):value=gzip.compress(raw,compresslevel=9,mtime=0)
   elif name.endswith('.lzma'):value=lzma.compress(raw,format=lzma.FORMAT_ALONE,preset=9)
   elif name.endswith('.xz'):value=lzma.compress(raw,format=lzma.FORMAT_XZ,preset=9)
   else:raise ValueError('Unsupported source compression: '+name)
  hdr=hdr[:48]+str(len(value)).ljust(10).encode()+hdr[58:]
  output.extend(hdr+value+(b'\n' if len(value)%2 else b''))
 target.write_bytes(output)
 checked=0
 for control in (False,True):
  actual={t.name:t for t in archive_members(target,control)}
  for t in source[control]:
   u=actual[t.name]
   for k in ['uid','gid','uname','gname','mode','mtime','type','linkname']:assert getattr(t,k)==getattr(u,k),(t.name,k)
   checked+=1
 return {'original_metadata_preserved':True,'entries_checked_including_additions':checked,'method':'original tar/ar metadata retained; file bytes from staging; no filesystem chown assumption'}

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--package1',type=pathlib.Path,required=True);ap.add_argument('--package2',type=pathlib.Path,required=True);ap.add_argument('--out',type=pathlib.Path,required=True);a=ap.parse_args()
 assert sha(a.package1.read_bytes())==INPUT1,'package1 mismatch';assert sha(a.package2.read_bytes())==INPUT2,'package2 mismatch'
 out=a.out.resolve();out.mkdir(parents=True,exist_ok=True);root=out/'staging';donor=out/'donor'
 assert not root.exists() and not donor.exists(),'use a fresh output directory'
 run(['dpkg-deb','-R',a.package1,root]);run(['dpkg-deb','-R',a.package2,donor]);before=manifest(root)
 lib=root/LIB;data=bytearray(lib.read_bytes());old=bytes(data);sig_before=verify(old);patches=[]
 for s in SPECS:
  m=Mach(old,s['base']);assert m.syms[s['settings']]==['_RTLoadSettings'];assert m.syms[s['callback']]==['_RTRefreshRateDidChange'];assert m.stubs[s['dlsym']]=='_dlsym'
  for key in ('helper','callback'):
   pos=s['base']+s[key];expected='7f2303d5' if s['pac'] else ('ffc300d1' if key=='helper' else 'ff8304d1')
   assert data[pos:pos+4].hex()==expected,(s['name'],key,data[pos:pos+4].hex())
   data[pos:pos+4]=bytes.fromhex('c0035fd6');patches.append(dict(arch=s['name'],reason='disable_old_'+key,va=s[key],size=4))
  code=make_loader(s,out);pos=s['base']+s['body'];data[pos:pos+len(code)]=code
  assert data[s['base']+s['ctor']:pos]==old[s['base']+s['ctor']:pos]
  assert data[s['base']+s['epilogue']:s['base']+s['epilogue']+4]==bytes.fromhex('e00313aa')
  patches.append(dict(arch=s['name'],reason='conditional_original_promotion_loader',va=s['body'],size=len(code),hex=code.hex()))
 slots=rehash(data);sig_after=verify(data);assert sig_before==sig_after
 allowed=[]
 for s in SPECS:
  for p in patches:
   if p['arch']==s['name']:allowed.append((s['base']+p['va'],s['base']+p['va']+p['size']))
 allowed += [(h['pos'],h['pos']+h['size']) for h in slots]
 assert len(data)==len(old) and all(any(lo<=i<hi for lo,hi in allowed) for i,(x,y) in enumerate(zip(old,data)) if x!=y)
 lib.write_bytes(data)
 donorlib=(donor/(DYLDIR+'ProMotion120.dylib')).read_bytes();donorsig=verify(donorlib)
 (root/HELPER).write_bytes(donorlib);os.chmod(root/HELPER,0o755)
 (root/HELPER_PLIST).write_bytes(plistlib.dumps({'Filter':{'Bundles':['com.12233sjjs.relaxtune.manual-loader-only']}}));os.chmod(root/HELPER_PLIST,0o644)
 filt=root/(DYLDIR+'RelaxTune.plist');f=plistlib.loads(filt.read_bytes());df=plistlib.loads((donor/(DYLDIR+'ProMotion120.plist')).read_bytes())
 f['Filter']['Bundles']=list(dict.fromkeys(f['Filter']['Bundles']+df['Filter']['Bundles']));filt.write_bytes(plistlib.dumps(f))
 pf=root/PREFS;p=plistlib.loads(pf.read_bytes());switch=next(i for i in p['items'] if i.get('key')=='HighRefresh');switch['label']=SETTINGS_LABEL
 next(i for i in p['items'] if i.get('label')=='动画')['footerText']=SETTINGS_FOOTER;pf.write_bytes(plistlib.dumps(p,fmt=plistlib.FMT_BINARY,sort_keys=False))
 control=root/'DEBIAN/control';c=control.read_text();assert '\nVersion: 0.5\n' in c
 c=c.replace('\nVersion: 0.5\n','\nVersion: 0.5.1\n')
 c+='Conflicts: com.doimty.promotion, cn.zqbb.fix120hz, cn.zqbb.fix120hz15, com.zqbb.fix120hz, com.zqbb.dynamic120hz\n'
 c+='Tag: supports::roothide\n'
 c='\n'.join(('Installed-Size: '+str(math.ceil(sum(p.stat().st_size for p in root.rglob('*') if p.is_file() and 'DEBIAN' not in p.parts)/1024))) if line.startswith('Installed-Size:') else line for line in c.split('\n'));control.write_text(c)
 after=manifest(root);changed=[k for k in before if before[k]!=after[k]];added=sorted(set(after)-set(before))
 assert set(changed)=={'DEBIAN/control',LIB,PREFS,DYLDIR+'RelaxTune.plist'},changed
 assert added==sorted([HELPER,HELPER_PLIST]);assert all(before[k]['mode']==after[k]['mode'] for k in before)
 target=out/'com.12233sjjs.relaxtune_0.5.1_iphoneos-arm64e.deb';archive_metadata=build_preserving_metadata(a.package1,a.package2,root,target)
 check=out/'reextracted';run(['dpkg-deb','-R',target,check]);assert manifest(check)==after
 report=dict(archive_metadata=archive_metadata,scope_policy='main filter union deliberately applies to existing non-refresh features too; existing guards, switches and exclusions retained',package1_sha256=INPUT1,package2_sha256=INPUT2,version='0.5.1',artifact=target.name,artifact_bytes=target.stat().st_size,artifact_sha256=sha(target.read_bytes()),original_provider_sha256=sha(donorlib),patched_library_sha256=sha(data),patches=patches,code_hash_slots_updated=slots,patched_signature=sig_after,provider_signature=donorsig,changed_original_files=changed,added_files=added,original_manifest=before,final_manifest=after,reextraction_exact_match=True,device_runtime_tested=False,highrefresh_switch='startup-only; restart SpringBoard and apps after changes')
 (out/'audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));(out/'SHA256SUMS').write_text(sha(target.read_bytes())+'  '+target.name+'\n')
 print(json.dumps({k:report[k] for k in ['artifact','artifact_bytes','artifact_sha256','original_provider_sha256','changed_original_files','added_files','device_runtime_tested']},ensure_ascii=False,indent=2))
if __name__=='__main__':main()
