"""Package m151 native code for Windows Pascal static linking.

Prelink native C++ COMDATs before passing objects to the Pascal linker. Only
Windows/UCRT imports are resolved at startup; all Skia code is embedded.
"""
import argparse
from bisect import bisect_right
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess


class Coff:
    def __init__(self, path):
        self.data = bytearray(path.read_bytes())
        self.machine, self.sections = struct.unpack_from('<HH', self.data)
        self.offset, self.count = struct.unpack_from('<II', self.data, 8)
        self.strings = bytearray(self.data[self.offset + 18 * self.count:])
        self.records = []
        i = 0
        while i < self.count:
            self.records.append(i)
            i += 1 + self.data[self.offset + i * 18 + 17]

    def record(self, i):
        return self.offset + i * 18

    def name(self, i):
        raw = self.data[self.record(i):self.record(i)+8]
        if raw[:4] == bytes(4):
            p = struct.unpack_from('<I', raw, 4)[0]
            return bytes(self.strings[p:self.strings.index(0, p)]).decode('utf-8')
        return bytes(raw).split(b'\0')[0].decode('utf-8')

    def info(self, i):
        return struct.unpack_from('<IhHBB', self.data, self.record(i)+8)

    def rename(self, i, name):
        struct.pack_into('<II', self.data, self.record(i), 0, len(self.strings))
        self.strings += name.encode() + b'\0'

    def resolve(self):
        definitions = {self.name(i): i for i in self.records
                       if self.info(i)[1] > 0 and self.info(i)[3] == 2}
        for name, i in list(definitions.items()):
            if name.startswith('.weak.') and '.default' in name:
                definitions.setdefault(name[6:].split('.default',1)[0], i)
        for i in self.records:
            value, section, typ, storage, aux = self.info(i)
            target = None
            if section == 0 and storage == 2:
                target = definitions.get(self.name(i))
            if section == 0 and storage == 3 and '$' in self.name(i):
                candidate=self.name(i).split('$',1)[1]
                target = definitions.get(candidate,definitions.get('_'+candidate))
            if storage == 105 and aux:
                target = definitions.get(self.name(i),struct.unpack_from('<I', self.data, self.record(i)+18)[0])
                if self.info(target)[1] == 0:
                    target = definitions.get(self.name(target))
            if target is not None and self.info(target)[1] > 0:
                p, q = self.record(i), self.record(target)
                self.data[p+8:p+16] = self.data[q+8:q+16]
                self.data[p+16] = 3
                self.rename(i, 'skia_resolved_'+str(i))
                if aux:
                    self.data[p+18:p+18+aux*18] = bytes(aux*18)

    def undefined(self):
        return sorted({self.name(i) for i in self.records
                       if self.info(i)[1] == 0 and self.info(i)[3] in (2, 105)})

    def write(self, path, hide=False):
        seen = {}
        for i in self.records:
            value, section, typ, storage, aux = self.info(i)
            if section > 0 and storage == 2:
                name = self.name(i)
                if name in seen:
                    if seen[name] != (value,section):
                        raise ValueError('Conflicting native definitions: '+name)
                    self.data[self.record(i)+16] = 3
                    self.rename(i,'skia_duplicate_'+str(i))
                else:
                    seen[name] = (value,section)
        for section in range(self.sections):
            flags = 20 + section*40 + 36
            value = struct.unpack_from('<I', self.data, flags)[0]
            struct.pack_into('<I', self.data, flags, value & ~0x1000)
        if hide:
            for i in self.records:
                name = self.name(i)
                if self.info(i)[1] > 0 and self.info(i)[3] == 2 and not name.lstrip('_').startswith(('sk4d_', 'gr4d_', 'skia_native_', 'skia_boot_')):
                    self.data[self.record(i)+16] = 3
                if len(name) > 180 or name.startswith(('_Z', '.weak.')):
                    self.rename(i, 'skia_local_' + hashlib.sha256(name.encode()).hexdigest())
        struct.pack_into('<I', self.strings, 0, len(self.strings))
        path.write_bytes(self.data[:self.offset+18*self.count] + self.strings)


def run(args):
    subprocess.run([str(a) for a in args], check=True)


def split_object(obj, directory, bits):
    """Keep each object below Pascal linkers' 16-bit relocation limits.

    Every relocation is rewritten to a chunk base plus its original symbol
    offset. Native instructions and data retain their original addends.
    """
    directory.mkdir(parents=True,exist_ok=True)
    chunks, sections = [], {}
    for section in range(1,obj.sections+1):
        h=20+(section-1)*40
        name=bytes(obj.data[h:h+8]).split(b'\0')[0].decode()
        if name.startswith('/'):
            offset=int(name[1:])
            name=bytes(obj.strings[offset:obj.strings.index(0,offset)]).decode()
        virtual=struct.unpack_from('<I',obj.data,h+8)[0]
        size,raw,rel=struct.unpack_from('<III',obj.data,h+16)
        count=struct.unpack_from('<H',obj.data,h+32)[0]
        flags=struct.unpack_from('<I',obj.data,h+36)[0]
        if name.startswith(('.debug','.gfids','.giats','.gljmp','.eh_frame')):
            continue
        if name!='.text':
            name='.data' if flags & 0x80000000 else '.rdata'
        size=max(size,virtual)
        data=bytes(obj.data[raw:raw+size]) if raw else bytes(size)
        indices=[]
        starts=[0]
        if name=='.text':
            boundaries=sorted({obj.info(i)[0] for i in obj.records
                               if obj.info(i)[1]==section and obj.info(i)[2]==32})
            while starts[-1]+262144<size:
                candidates=[v for v in boundaries if starts[-1]<v<=starts[-1]+262144]
                if not candidates:
                    candidates=[v for v in boundaries if v>starts[-1]]
                if not candidates:break
                starts.append(max(candidates) if candidates[-1]<=starts[-1]+262144 else candidates[0])
        ends=starts[1:]+[size]
        for start,end in zip(starts,ends):
            index=len(chunks)
            indices.append(index)
            chunks.append({'name':name,'section':section,'start':start,
                           'data':bytearray(data[start:end]),'rel':[],
                           'flags':flags & ~0x01001000,'exports':[]})
        sections[section]=indices
        first=0
        if flags & 0x01000000:
            count=struct.unpack_from('<I',obj.data,rel)[0]
            first=1
        for r in range(first,count):
            address,symbol,kind=struct.unpack_from('<IIH',obj.data,rel+r*10)
            if kind==0:continue
            value,target,typ,storage,aux=obj.info(symbol)
            if target <= 0:
                raise ValueError('Nonsection relocation target: '+obj.name(symbol))
            if target not in sections:
                # All target sections are mapped after this first pass.
                pass
            chunk=chunks[indices[bisect_right(starts,address)-1]]
            chunk['rel'].append((address-chunk['start'],target,value,kind))
    for i in obj.records:
        value,section,typ,storage,aux=obj.info(i)
        name=obj.name(i)
        if section in sections and storage==2 and name.lstrip('_').startswith(('sk4d_','gr4d_','skia_native_')):
            indices=sections[section]
            index=indices[bisect_right([chunks[j]['start'] for j in indices],value)-1]
            chunks[index]['exports'].append((name,value-chunks[index]['start'],typ))
    for index,chunk in enumerate(chunks):
        chunk_prefix='' if bits==64 else '_'
        symbols=[(chunk_prefix+'skia_chunk_'+str(index),0,1,32 if chunk['name']=='.text' else 0)]
        symbol_map={index:0}
        relocations=[]
        for address,section,value,kind in chunk['rel']:
            if section not in sections:
                raise ValueError('Relocation to discarded metadata section '+str(section))
            target_indices=sections[section]
            target=target_indices[bisect_right([chunks[j]['start'] for j in target_indices],value)-1]
            offset=value-chunks[target]['start']
            if target not in symbol_map:
                symbol_map[target]=len(symbols)
                symbols.append((chunk_prefix+'skia_chunk_'+str(target),0,0,32 if chunks[target]['name']=='.text' else 0))
            width=8 if bits==64 and kind==1 else 4
            old=int.from_bytes(chunk['data'][address:address+width],'little')
            chunk['data'][address:address+width]=((old+offset) % (1<<(width*8))).to_bytes(width,'little')
            relocations.append(struct.pack('<IIH',address,symbol_map[target],kind))
        symbols += [(n,v,1,t) for n,v,t in chunk['exports']]
        if len(relocations)>=65535:
            raise ValueError('Too many relocations after splitting')
        strings=bytearray(4)
        records=bytearray()
        for name,value,section,typ in symbols:
            encoded=name.encode()
            if len(encoded)<=8:
                record=encoded.ljust(8,b'\0')
            else:
                record=struct.pack('<II',0,len(strings));strings+=encoded+b'\0'
            records+=record+struct.pack('<IhHBB',value,section,typ,2,0)
        section_name=chunk['name'].encode()
        if len(section_name)>8:
            section_name=('/'+str(len(strings))).encode()
            strings+=chunk['name'].encode()+b'\0'
        struct.pack_into('<I',strings,0,len(strings))
        payload=bytes(chunk['data'])
        rel=b''.join(relocations)
        sym_offset=60+len(payload)+len(rel)
        header=struct.pack('<HHIIIHH',obj.machine,1,0,sym_offset,len(symbols),0,0)
        flags=chunk['flags'] & ~0x80  # materialize zero-filled BSS
        flags |= 0x40 if chunk['name']!='.text' else 0x20
        section_header=section_name.ljust(8,b'\0')+struct.pack('<IIIIIIHHI',0,0,len(payload),60,60+len(payload),0,len(relocations),0,flags)
        (directory/f'skia_{index:03d}.o').write_bytes(header+section_header+payload+rel+records+strings)
    expected={directory/f'skia_{i:03d}.o' for i in range(len(chunks))}
    for stale in directory.glob('skia_*.o'):
        if stale not in expected:
            stale.unlink()
    return sorted(expected)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--skia-root', type=Path, default=Path(__file__).resolve().parent.parent/'skia')
    p.add_argument('--toolchain', type=Path)
    p.add_argument('--ld', type=Path, default=Path(shutil.which('ld') or 'ld'))
    p.add_argument('--platform', choices=['win32', 'win64'], default='win64')
    p.add_argument('--output', type=Path)
    p.add_argument('--archive', type=Path)
    p.add_argument('--work', type=Path)
    a = p.parse_args()
    root = Path(__file__).resolve().parent.parent
    version_header=(a.skia_root/'sk4d/include/sk4d_version.h').read_text()
    version=re.search(r'#define SK4D_VERSION "([^"]+)"',version_header).group(1)
    if not version.startswith('151.'):
        raise ValueError('The pinned Pascal API requires sk4d/m151')
    tc = a.toolchain or Path(os.environ.get('LLVM_MINGW_ROOT', str(root/'runtime/toolchains/llvm-mingw-20240619-ucrt-x86_64')))
    out = a.output or root/'runtime/windows-static'
    work = a.work or root/'runtime/build'/f'static-prelink-{a.platform}'
    work.mkdir(parents=True, exist_ok=True)
    bits = 64 if a.platform == 'win64' else 32
    arch = 'x86_64' if bits == 64 else 'i686'
    target = arch + '-w64-mingw32'
    prefix = '' if bits == 64 else '_'
    archive = a.archive or root/f'runtime/build/static-{a.platform}/sk4d.a'
    script = work/'combine.ld'
    script.write_text('''SECTIONS {
 .text : { *(.text*) }
 .rdata : { *(.rdata*) *(.rodata*) }
 .data : { *(.data*) }
 .bss : { *(.bss*) *(COMMON) }
 .ctors : { '''+prefix+'''skia_ctor_begin = .; *(.ctors*) *(.CRT$XCU*) '''+prefix+'''skia_ctor_end = .; }
 /DISCARD/ : { *(.pdata*) *(.xdata*) *(.llvm_addrsig) *(.drectve) }
}
''')
    libraries = [tc/target/'lib'/n for n in ('libc++.a','libuuid.a','libmingwex.a','libunwind.a')]
    libraries += [tc/f'lib/clang/18/lib/windows/libclang_rt.builtins-{"x86_64" if bits==64 else "i386"}.a']
    base = [a.ld, '-m', 'i386pep' if bits == 64 else 'i386pe', '-r', '--oformat', 'pe-x86-64' if bits == 64 else 'pe-i386', '-T', script]
    combined = work/'combined.o'
    run(base + ['--whole-archive', archive, libraries[0], '--no-whole-archive'] + libraries[1:] + ['-o',combined])
    obj = Coff(combined)
    obj.resolve()
    native = work/'native.o'
    obj.write(native)
    imports = obj.undefined()
    wrappers=[]
    if bits==32:
        unary='acos asin atan ceil cos cosh exp exp2 floor log log10 log2 sin sinh sqrt tan tanh trunc round'.split()
        binary='atan2 fmod pow'.split()
        for function in unary+binary:
            float_name=prefix+function+'f'
            if float_name in imports:
                imports.remove(float_name)
                if prefix+function not in imports:imports.append(prefix+function)
                params='double x' if function in unary else 'double x,double y'
                args='x' if function in unary else 'x,y'
                float_params=params.replace('double','float')
                wrappers += [f'extern double {function}({params}); float {function}f({float_params}){{return (float){function}({args});}}']
    # MinGW's image pseudo-relocator is unnecessary: imports are explicit slots.
    special = {prefix+'_pei386_runtime_relocator'}
    imports = [name for name in imports if name not in special]
    cpp = [name for name in imports if name.lstrip('_').startswith('Z')]
    if cpp:
        raise ValueError('Unresolved C++ symbols: '+repr(cpp))
    names = {}
    for name in imports:
        imp = name.startswith('__imp_')
        raw = name[6:] if imp else name
        if bits == 32 and raw.startswith('_'):
            raw = raw[1:]
        raw = re.sub(r'@\d+$','',raw)
        names.setdefault(raw, []).append((name, imp))
    helper = work/'imports.c'
    asm = work/'imports.s'
    dlls = ['ucrtbase.dll','kernel32.dll','gdi32.dll','user32.dll','ole32.dll','oleaut32.dll',
            'advapi32.dll','shlwapi.dll','usp10.dll','fontsub.dll','opengl32.dll','msvcrt.dll','ntdll.dll']
    c = ['typedef void* (__attribute__((stdcall)) *load_t)(const char*);',
         'typedef void* (__attribute__((stdcall)) *proc_t)(void*,const char*);',
         'extern void (*skia_ctor_begin[])(void), (*skia_ctor_end[])(void);',
         'static const char *error_name; static int initialized;', 'const char* skia_native_error(void){return error_name;}',
         'void skia_native_finalize(void){}', 'void _pei386_runtime_relocator(void){}']
    c += wrappers
    s = ['.text']
    for index, (name, symbols) in enumerate(names.items()):
        c += [f'extern void* skia_import_{index};']
        slot = prefix+f'skia_import_{index}'
        s += ['.data',f'.p2align {3 if bits==64 else 2}',f'.globl {slot}',f'{slot}:']
        for symbol, imp in symbols:
            if imp:
                s += [f'.globl "{symbol}"', f'"{symbol}":']
        s += ['.quad 0' if bits==64 else '.long 0','.text']
        for symbol, imp in symbols:
            if not imp:
                s += [f'.globl "{symbol}"', f'"{symbol}":']
                if bits == 64 and name == '__intrinsic_setjmpex':
                    s += ['xor %edx,%edx']
                s += [f'jmp *{slot}'+('(%rip)' if bits == 64 else '')]
    c += ['int skia_native_initialize(load_t load,proc_t proc){',
          'if(initialized)return 0;',
          'void* modules[] = {'+','.join(f'load("{dll}")' for dll in dlls)+'};',
          'unsigned i; void (**ctor)(void);']
    for index, name in enumerate(names):
        variants = [name, '_'+name]
        if name.startswith('_'):
            variants += [name[1:]]
        c += [f'for(i=0;i<sizeof(modules)/sizeof(modules[0]);i++){{ if(!modules[i])continue;']
        for variant in variants:
            c += [f'if(!skia_import_{index}) skia_import_{index}=proc(modules[i],"{variant}");']
        c += ['}', f'if(!skia_import_{index}){{error_name="{name}";return {index+1};}}']
    c += ['for(ctor=skia_ctor_begin;ctor<skia_ctor_end;ctor++)if(*ctor && (void*)*ctor!=(void*)-1)(*ctor)();', 'initialized=1;return 0;}']
    helper.write_text('\n'.join(c)+'\n')
    asm.write_text('\n'.join(s)+'\n')
    clang = tc/'bin'/f'{target}-clang.exe'
    run([clang,'-c','-O2','-fno-builtin','-fno-stack-protector',helper,'-o',work/'imports.o'])
    run([clang,'-c',asm,'-o',work/'thunks.o'])
    final = work/'skia.o'
    run(base + [native,work/'imports.o',work/'thunks.o','-o',final])
    obj = Coff(final)
    obj.resolve()
    if obj.undefined():
        raise ValueError('Unresolved native symbols: '+repr(obj.undefined()))
    obj.write(final,hide=True)
    pieces=split_object(obj,work/'pieces',bits)
    binding=(root/'src/fpc/vendor/System.Skia.API.pas').read_text(encoding='utf-8-sig')
    required=set(re.findall(r"PChar\('((?:sk4d|gr4d)_\w+)'\)",binding))
    exported={obj.name(i).lstrip('_') for i in obj.records if obj.info(i)[1]>0 and obj.info(i)[3]==2}
    if required-exported:
        raise ValueError('Missing Pascal C API functions: '+repr(sorted(required-exported)))
    branch = 'Win64' if bits == 64 else 'Win32'
    for dest in [out/'Binary/Static'/branch, out/'Binary/Static/FPC'/branch]:
        dest.mkdir(parents=True,exist_ok=True)
        expected={piece.name for piece in pieces}
        for stale in dest.glob('skia_*.o'):
            if stale.name not in expected:
                stale.unlink()
        for piece in pieces:
            shutil.copyfile(piece,dest/piece.name)
    api = (root/'src/fpc/vendor/System.Skia.API.pas').read_text(encoding='utf-8-sig')
    start = api.index('{$IF DEFINED(SK_STATIC_LIBRARY)}\nconst')
    end = api.index("{$ELSE}\nconst\n  {$IFDEF MSWINDOWS}\n  LibraryName = 'sk4d.dll'",start)
    directives = '''{$IF DEFINED(SK_STATIC_LIBRARY)}
const
  {$IF DEFINED(WIN32) and NOT DEFINED(FPC)} _PU = '_'; {$ELSE} _PU = ''; {$ENDIF}
  LibraryName = '';
STATIC_DIRECTIVES
function skia_native_initialize(loader, getter: Pointer): Integer; cdecl; external name _PU + 'skia_native_initialize';
function skia_native_error: PAnsiChar; cdecl; external name _PU + 'skia_native_error';
procedure skia_native_finalize; cdecl; external name _PU + 'skia_native_finalize';
function skia_boot_load(name: PAnsiChar): NativeUInt; stdcall; external 'kernel32.dll' name 'LoadLibraryA';
function skia_boot_proc(module: NativeUInt; name: PAnsiChar): Pointer; stdcall; external 'kernel32.dll' name 'GetProcAddress';
function __InitLib: Integer;
begin
  Result := skia_native_initialize(@skia_boot_load,@skia_boot_proc);
  if Result <> 0 then raise Exception.Create('Missing Windows CRT import: '+string(AnsiString(skia_native_error)));
end;
procedure __FiniLib;
begin
  skia_native_finalize;
end;
'''
    links=[]
    for platform in ('Win32','Win64'):
        links += ['{$IFDEF '+platform.upper()+'}', '{$IFDEF FPC}']
        for compiler_branch in ('FPC/'+platform,platform):
            for piece in sorted((out/'Binary/Static'/compiler_branch).glob('skia_*.o')):
                links += ["{$L '../Binary/Static/"+compiler_branch+'/'+piece.name+"'}"]
            if compiler_branch.startswith('FPC'):
                links += ['{$ELSE}']
        links += ['{$ENDIF}','{$ENDIF}']
    anchors=[]
    for platform in ('Win32','Win64'):
        anchors+=['{$IFDEF '+platform.upper()+'}']
        for piece in sorted((out/'Binary/Static'/platform).glob('skia_*.o')):
            index=int(piece.stem.split('_')[1])
            name='skia_chunk_'+str(index)
            anchors+=[f"procedure {name}; cdecl; external name _PU + '{name}';"]
        anchors+=['{$ENDIF}']
    directives=directives.replace('STATIC_DIRECTIVES','\n'.join(links+anchors))
    api = api[:start]+directives+api[end:]
    (out/'Source').mkdir(exist_ok=True)
    (out/'Source/System.Skia.API.pas').write_text(api,encoding='utf-8-sig')
    (out/f'manifest-{a.platform}.json').write_text(json.dumps({'platform':a.platform,'native_version':version,
        'source_revision':subprocess.check_output(['git','rev-parse','HEAD'],cwd=a.skia_root,text=True).strip(),
        'native_compatibility':json.loads((archive.parent/'compat/manifest.json').read_text(encoding='utf-8')) if (archive.parent/'compat/manifest.json').exists() else {},
        'pascal_api':'7.3.0','api_imports':len(required),'objects':len(pieces),
        'imports':list(names),'archive_sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),
        'object_sha256':hashlib.sha256(final.read_bytes()).hexdigest(),
        'coff_sha256':{piece.name:hashlib.sha256(piece.read_bytes()).hexdigest() for piece in pieces}},indent=2))
    print('Prepared',a.platform,out)


if __name__ == '__main__':
    main()
