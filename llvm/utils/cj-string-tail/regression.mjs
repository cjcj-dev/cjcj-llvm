#!/usr/bin/env zx
import fs from 'node:fs';import path from 'node:path';import {spawnSync} from 'node:child_process';import {createHash} from 'node:crypto';
const out=process.argv[2],native=process.argv[3],oldIR=process.argv[4];if(!out||!native||!oldIR)throw Error('new output, native install, saved old IR required');fs.mkdirSync(out);
const here=import.meta.dirname,source=path.resolve(here,'../..'),test=source+'/test/Transforms/LICM/cj-load-speculation-bounds.ll',r={out,native,oldIR,test,steps:[]};const save=()=>fs.writeFileSync(out+'/result.json',JSON.stringify(r,null,2));
const cg='/sys/fs/cgroup'+fs.readFileSync('/proc/self/cgroup','utf8').trim().split('::').at(-1);r.resources=Object.fromEntries(['cpuset.cpus.effective','memory.max','memory.swap.max'].map(k=>[k,fs.readFileSync(cg+'/'+k,'utf8').trim()]));r.limits=fs.readFileSync('/proc/self/limits','utf8');save();if(r.resources['memory.swap.max']!=='0'||!r.limits.match(/Max core file size\s+0\s+0/))throw Error('resource contract');
const env={...process.env,LD_LIBRARY_PATH:native+'/lib'};delete env.LD_PRELOAD;delete env.LD_AUDIT;
const run=(tag,exe,args,expect={rc:0,signal:null})=>{const x={tag,exe,args,cwd:out,expect,start:new Date().toISOString()};r.steps.push(x);save();const o=fs.openSync(out+'/'+tag+'.stdout','wx'),e=fs.openSync(out+'/'+tag+'.stderr','wx');const p=spawnSync(exe,args,{cwd:out,env,stdio:['ignore',o,e],timeout:60000});fs.closeSync(o);fs.closeSync(e);Object.assign(x,{rc:p.status,signal:p.signal,error:p.error?.message,end:new Date().toISOString()});save();if(p.status!==expect.rc||p.signal!==expect.signal)throw Error('unexpected result '+tag);};
run('opt',native+'/bin/opt',['-S','--cangjie-pipeline','-passes=function(loop-mssa(licm))',test,'-o',out+'/new.ll']);
run('filecheck',path.resolve(native,'../build/bin/FileCheck'),[test,'--input-file='+out+'/new.ll']);
for(const [tag,ir] of [['old',oldIR],['new',out+'/new.ll']]){
 run(tag+'-compile-ir','/usr/lib/llvm-15/bin/clang',['-O0','-c',ir,'-o',out+'/'+tag+'.o']);
 run(tag+'-link','/usr/lib/llvm-15/bin/clang',['-O0',here+'/guard.c',out+'/'+tag+'.o','-o',out+'/'+tag]);
 const elf=out+'/'+tag;r[tag]={elf,sha256:createHash('sha256').update(fs.readFileSync(elf)).digest('hex')};save();
 run(tag+'-run',elf,[],tag==='old'?{rc:null,signal:'SIGSEGV'}:{rc:0,signal:null});
}
r.end=new Date().toISOString();save();
