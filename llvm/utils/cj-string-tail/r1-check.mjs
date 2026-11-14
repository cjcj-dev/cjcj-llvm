#!/usr/bin/env zx
import fs from 'node:fs';import path from 'node:path';import {spawnSync} from 'node:child_process';import {createHash} from 'node:crypto';
const [out,native,arm]=process.argv.slice(2);if(!out||!native||!['old','new'].includes(arm))throw Error('new output, LLVM install, old|new');fs.mkdirSync(out);
const source=path.resolve(import.meta.dirname,'../..'),root=path.resolve(native,'../../'),check=root+'/native-r1/build/bin/FileCheck',opt=native+'/bin/opt';
const r={out,native,arm,source,steps:[],identity:[opt,native+'/lib/libLLVM-15.so'].map(p=>({path:p,sha256:createHash('sha256').update(fs.readFileSync(p)).digest('hex')}))};const save=()=>fs.writeFileSync(out+'/result.json',JSON.stringify(r,null,2));
const cg='/sys/fs/cgroup'+fs.readFileSync('/proc/self/cgroup','utf8').trim().split('::').at(-1);r.resources=Object.fromEntries(['cpuset.cpus.effective','memory.max','memory.swap.max'].map(k=>[k,fs.readFileSync(cg+'/'+k,'utf8').trim()]));r.limits=fs.readFileSync('/proc/self/limits','utf8');save();if(r.resources['memory.swap.max']!=='0'||!r.limits.match(/Max core file size\s+0\s+0/))throw Error('resource contract');
const env={...process.env,LD_LIBRARY_PATH:native+'/lib',LD_DEBUG:'libs'};delete env.LD_PRELOAD;delete env.LD_AUDIT;
const run=(tag,exe,args,expect={rc:0,signal:null})=>{const row={tag,exe,args,expect,start:new Date().toISOString()};r.steps.push(row);save();const o=fs.openSync(out+'/'+tag+'.stdout','wx'),e=fs.openSync(out+'/'+tag+'.stderr','wx');const p=spawnSync(exe,args,{env,stdio:['ignore',o,e],timeout:60000});fs.closeSync(o);fs.closeSync(e);Object.assign(row,{rc:p.status,signal:p.signal,error:p.error?.message,end:new Date().toISOString()});save();if(p.status!==expect.rc||p.signal!==expect.signal)throw Error('unexpected result '+tag);};
const ordinary=source+'/test/Transforms/LICM/cj-load-speculation-bounds.ll',refs=source+'/test/Transforms/LICM/cj-ref-read-speculation-types.ll';
for(const [tag,test,opaque,cj,fail] of arm==='old'?[['opaque-control',ordinary,true,false,false],['opaque-ordinary',ordinary,true,true,true],['opaque-ref',refs,true,true,true]]:[['typed-ordinary',ordinary,false,true,false],['opaque-ordinary',ordinary,true,true,false],['typed-ref',refs,false,true,false],['opaque-ref',refs,true,true,false]]){
 run(tag,opt,[...(opaque?['-opaque-pointers']:['-opaque-pointers=0']),'-S',...(cj?['-cangjie-pipeline']:[]),'-passes=function(loop-mssa(licm))',test,'-o',out+'/'+tag+'.ll'],fail?{rc:null,signal:'SIGABRT'}:undefined);
 if(fail){const text=fs.readFileSync(out+'/'+tag+'.stderr','utf8');if(!text.includes('getNonOpaquePointerElementType'))throw Error('target assertion not reached '+tag);}
 else run(tag+'-check',check,[test,'--input-file='+out+'/'+tag+'.ll']);
}
