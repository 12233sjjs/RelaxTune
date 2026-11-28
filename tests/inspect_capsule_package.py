#!/usr/bin/env python3
"""Read-only stdlib validation of the built 0.5.2 DEB; not loader/device proof."""
import hashlib, io, json, pathlib, plistlib, struct, sys, tarfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
def sha(b):return hashlib.sha256(b).hexdigest()
def ar_members(data):
    assert data[:8]==b'!<arch>\n';out={};pos=8
    while pos<len(data):
        h=data[pos:pos+60];assert len(h)==60 and h[58:]==b'`\n'
        name=h[:16].decode().strip().rstrip('/');size=int(h[48:58]);assert name not in out
        out[name]=data[pos+60:pos+60+size];assert len(out[name])==size
        pos+=60+size+(size%2)
    assert pos==len(data);return out
def archive(data):
    items={}
    with tarfile.open(fileobj=io.BytesIO(data),mode='r:*') as t:
        for m in t:
            name=m.name.removeprefix('./').rstrip('/')
            assert not name.startswith('/') and '..' not in pathlib.PurePosixPath(name).parts
            assert name not in items,(name,'duplicate')
            items[name]=(m,t.extractfile(m).read() if m.isfile() else None)
    return items
def slice_table(b):
    if b[:4]==bytes.fromhex('cafebabe'):
        n=struct.unpack_from('>I',b,4)[0]
        return [(cpu,sub,off,size) for cpu,sub,off,size,_ in (struct.unpack_from('>5I',b,8+20*i) for i in range(n))]
    assert b[:4]==bytes.fromhex('cffaedfe')
    cpu,sub=struct.unpack_from('<II',b,4);return [(cpu,sub,0,len(b))]
def inspect_mach(b):
    result=[]
    for cpu,sub,base,size in slice_table(b):
        d=b[base:base+size];assert len(d)==size and d[:4]==bytes.fromhex('cffaedfe')
        c,s,ft,ncmd,szcmd=struct.unpack_from('<5I',d,4);assert (c,s)==(cpu,sub)
        p=32;sig=None;loads=[];minimum=None
        for _ in range(ncmd):
            cmd,n=struct.unpack_from('<II',d,p);assert n>=8 and p+n<=len(d)
            if cmd==0x1d:sig=struct.unpack_from('<II',d,p+8)
            if cmd in (0xc,0x18|0x80000000,0x1f|0x80000000):
                off=struct.unpack_from('<I',d,p+8)[0];loads.append(d[p+off:p+n].split(b'\0')[0].decode())
            if cmd==0x32:minimum=struct.unpack_from('<I',d,p+12)[0]
            if cmd==0x25:minimum=struct.unpack_from('<I',d,p+8)[0]
            p+=n
        assert p==32+szcmd and sig is not None
        so,ss=sig;assert so+ss<=len(d)
        magic,length,count=struct.unpack_from('>3I',d,so);assert magic==0xfade0cc0 and length<=ss
        blobs={}
        for j in range(count):
            typ,off=struct.unpack_from('>2I',d,so+12+8*j);bm,bl=struct.unpack_from('>2I',d,so+off)
            assert off+bl<=length;blobs[typ]=(bm,so+off,bl)
        pages=special=directories=0
        for typ,(bm,off,bl) in blobs.items():
            if bm!=0xfade0c02:continue
            directories+=1
            ver,flags,ho,ident,nsp,ncode,lim=struct.unpack_from('>7I',d,off+8)
            hs,ht,platform,ps=d[off+36:off+40]
            if lim==0xffffffff and ver>=0x20300:lim=struct.unpack_from('>Q',d,off+56)[0]
            assert ht in (1,2,3,4) and ps>0 and lim<=size
            assert ncode==(lim+(1<<ps)-1)//(1<<ps) and ho+ncode*hs<=bl
            digest=lambda data:{1:hashlib.sha1,2:hashlib.sha256,3:hashlib.sha256,4:hashlib.sha384}[ht](data).digest()[:hs]
            for i in range(ncode):
                expected=digest(d[i<<ps:min((i+1)<<ps,lim)])
                assert d[off+ho+i*hs:off+ho+(i+1)*hs]==expected,(sub,typ,i)
                pages+=1
            for i in range(1,nsp+1):
                stored=d[off+ho-i*hs:off+ho-(i-1)*hs]
                if i in blobs:
                    _,at,sz=blobs[i];assert stored==digest(d[at:at+sz]);special+=1
                elif i in (2,5,7):assert not any(stored)
        assert directories>0
        result.append({'cpu':cpu,'subtype':hex(sub),'filetype':ft,'minimum_ios_packed':minimum,'loads':loads,'code_pages':pages,'embedded_special_slots':special})
    return result
def check(path):
    data=path.read_bytes();ar=ar_members(data);assert ar['debian-binary']==b'2.0\n'
    ct=archive(next(v for k,v in ar.items() if k.startswith('control.tar')))
    control=ct['control'][1].decode();fields=dict(line.split(': ',1) for line in control.splitlines() if ': ' in line)
    assert fields['Package']=='com.12233sjjs.relaxtune' and fields['Version']=='0.5.2'
    assert fields['Architecture']=='iphoneos-arm64e'
    assert 'com.zhuifeng.dateinfo (>= 1.3.10)' in fields['Depends']
    assert 'firmware (>= 16.0)' in fields['Depends'] and 'firmware (<< 17.0)' in fields['Depends']
    assert not any(n in ct for n in ('preinst','postinst','prerm','postrm')),'Unexpected maintainer script'
    payload=archive(next(v for k,v in ar.items() if k.startswith('data.tar')))
    manifest=json.loads((ROOT/'docs/TIME-CAPSULE-DONOR-MANIFEST.json').read_text())
    forbidden=set(manifest['donor']['payload_sha256'].values())
    for name,(member,b) in payload.items():
        assert 'dateinfo' not in name.lower(),('Third-party file path',name)
        if b is not None:assert sha(b) not in forbidden,('Third-party payload',name)
    libraries=[n for n in ('Library','var/jb/Library') if any(p.startswith(n+'/') for p in payload)]
    assert len(libraries)==1;lib=libraries[0]
    main=lib+'/MobileSubstrate/DynamicLibraries/RelaxTune.dylib'
    prefs=lib+'/PreferenceBundles/RelaxTunePrefs.bundle/RelaxTunePrefs'
    provider=lib+'/MobileSubstrate/DynamicLibraries/RelaxTuneProMotion120.dylib'
    assert {n for n in payload if n.endswith('.dylib')}=={main,provider}
    infos={}
    for name in (main,prefs,provider):
        b=payload[name][1];assert b is not None;records=inspect_mach(b)
        assert {r['cpu'] for r in records}=={0x0100000c}
        expected={'0x80000002'} if name==provider else {'0x0','0x80000002'}
        assert {r['subtype'] for r in records}==expected
        if name==main:
            for _,_,off,size in slice_table(b):
                for text in (b'DIBubbleView',b'TimeCapsuleBatteryTemp',b'IOPMPowerSource',b'Temperature'):
                    assert text in b[off:off+size],('Missing new source content',text)
        infos[name]={'sha256':sha(b),'bytes':len(b),'slices':records}
    assert sha(payload[provider][1])==sha((ROOT/'layout/Library/MobileSubstrate/DynamicLibraries/RelaxTuneProMotion120.dylib').read_bytes())
    settings=plistlib.loads(payload[lib+'/PreferenceBundles/RelaxTunePrefs.bundle/Root.plist'][1])['items']
    setting=next(i for i in settings if i.get('key')=='TimeCapsuleBatteryTemp')
    assert setting['default'] is False
    return {'status':'PASS_STATIC_PACKAGE_ONLY','filename':path.name,'bytes':len(data),'sha256':sha(data),'control':fields,'payload_entries':len(payload),'binaries':infos,'donor_payloads_absent':True,'temperature_default_enabled':False,'limitations':['Embedded page hashes are not author authenticity, CMS trust or AMFI acceptance','No iOS loading, hardware PAC, UI or battery-sensor test','Existing sources unchanged is checked against the Git baseline separately']}
if __name__=='__main__':
    path=pathlib.Path(sys.argv[1]);result=check(path)
    text=json.dumps(result,indent=2,ensure_ascii=False)+'\n';print(text)
    if len(sys.argv)>2:pathlib.Path(sys.argv[2]).write_text(text)
