#!/usr/bin/env zx
// Assertion-only old/new checks share a new mutable cache, never the frozen
// native-r1 build/install. Production reuses ccache with the normal flags.
import fs from 'node:fs';import path from 'node:path';import {spawnSync} from 'node:child_process';
const [out,mode,jobs]=process.argv.slice(2);
if(!out||!path.isAbsolute(out)||!['assert','release'].includes(mode)||!/^\d+$/.test(jobs??''))throw Error('absolute new output, assert|release, jobs required');
fs.mkdirSync(out);const source=path.resolve(import.meta.dirname,'../..'),build=mode==='assert'?path.resolve(out,'../opaque-cache'):out+'/build';
const r={out,source,build,mode,steps:[],commit:spawnSync('git',['-C',source,'rev-parse','HEAD'],{encoding:'utf8'}).stdout.trim()};const save=()=>fs.writeFileSync(out+'/result.json',JSON.stringify(r,null,2));
const cg='/sys/fs/cgroup'+fs.readFileSync('/proc/self/cgroup','utf8').trim().split('::').at(-1);r.resources=Object.fromEntries(['cpuset.cpus.effective','memory.max','memory.swap.max'].map(k=>[k,fs.readFileSync(cg+'/'+k,'utf8').trim()]));r.limits=fs.readFileSync('/proc/self/limits','utf8');save();if(r.resources['memory.swap.max']!=='0'||!r.limits.match(/Max core file size\s+0\s+0/))throw Error('resource contract');
const run=(tag,exe,args)=>{const row={tag,exe,args,start:new Date().toISOString()};r.steps.push(row);save();const o=fs.openSync(out+'/'+tag+'.stdout','wx'),e=fs.openSync(out+'/'+tag+'.stderr','wx');const p=spawnSync(exe,args,{stdio:['ignore',o,e]});fs.closeSync(o);fs.closeSync(e);Object.assign(row,{rc:p.status,signal:p.signal,end:new Date().toISOString()});save();if(p.status!==0)process.exit(p.status??1);};
r.original=fs.readFileSync('/mnt/cjcj-data/impl_full_sdk_sol_1108/integrated-gc-1114/native/build/third_party/cjnative-prefix/tmp/cjnative-cfgcmd.txt','utf8');
const args=r.original.trim().slice(5,-1).split(';').slice(1).filter(x=>x!=='<SOURCE_DIR><SOURCE_SUBDIR>').map(x=>x.replaceAll('|',';')).map(x=>x.startsWith('-DCMAKE_INSTALL_PREFIX=')?'-DCMAKE_INSTALL_PREFIX='+out+'/install':x.startsWith('-DCJ_LLVM_COMMIT=')?'-DCJ_LLVM_COMMIT='+r.commit:x.startsWith('-DLLVM_PARALLEL_LINK_JOBS=')?'-DLLVM_PARALLEL_LINK_JOBS=2':x);
if(mode==='assert')args.push('-DLLVM_ENABLE_ASSERTIONS=ON','-DLLVM_ABI_BREAKING_CHECKS=FORCE_OFF');
run('configure','/usr/bin/cmake',[...args,'-S',source,'-B',build]);fs.copyFileSync(build+'/CMakeCache.txt',out+'/CMakeCache.txt');
run('build','/usr/bin/cmake',['--build',build,'--target',...(mode==='assert'?['opt']:['opt','llc','llvm-dis','llvm-as','llvm-extract','llvm-link']),'-j',jobs]);
run('install','/usr/bin/cmake',['--build',build,'--target',...(mode==='assert'?['install-opt','install-LLVM']:['install-opt','install-llc','install-llvm-dis','install-llvm-as','install-llvm-extract','install-llvm-link','install-LLVM']),'-j','4']);
