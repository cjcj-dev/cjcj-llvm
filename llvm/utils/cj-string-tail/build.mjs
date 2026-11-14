#!/usr/bin/env zx
import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
const root=process.argv[2];if(!root||!path.isAbsolute(root))throw Error('new absolute output required');fs.mkdirSync(root);
const source=path.resolve(import.meta.dirname,'../..'),cfg='/mnt/cjcj-data/impl_full_sdk_sol_1108/integrated-gc-1114/native/build/third_party/cjnative-prefix/tmp/cjnative-cfgcmd.txt';
const state={source,root,steps:[]};const save=()=>fs.writeFileSync(root+'/result.json',JSON.stringify(state,null,2));
const cg='/sys/fs/cgroup'+fs.readFileSync('/proc/self/cgroup','utf8').trim().split('::').at(-1);state.resources=Object.fromEntries(['cpuset.cpus.effective','memory.max','memory.swap.max'].map(k=>[k,fs.readFileSync(cg+'/'+k,'utf8').trim()]));state.limits=fs.readFileSync('/proc/self/limits','utf8');save();if(state.resources['memory.swap.max']!=='0'||!state.limits.match(/Max core file size\s+0\s+0/))throw Error('resource contract');
state.commit=spawnSync('git',['-C',source,'rev-parse','HEAD'],{encoding:'utf8'}).stdout.trim();
const run=(tag,exe,args)=>{const row={tag,exe,args,cwd:root,start:new Date().toISOString()};state.steps.push(row);save();const o=fs.openSync(root+'/'+tag+'.stdout','wx'),e=fs.openSync(root+'/'+tag+'.stderr','wx');const p=spawnSync(exe,args,{cwd:root,env:process.env,stdio:['ignore',o,e]});fs.closeSync(o);fs.closeSync(e);Object.assign(row,{rc:p.status,signal:p.signal,end:new Date().toISOString()});save();if(p.status!==0)process.exit(p.status??1);};
state.original=fs.readFileSync(cfg,'utf8');const args=state.original.trim().slice(5,-1).split(';').slice(1).filter(x=>x!=='<SOURCE_DIR><SOURCE_SUBDIR>').map(x=>x.replaceAll('|',';')).map(x=>x.startsWith('-DCMAKE_INSTALL_PREFIX=')?'-DCMAKE_INSTALL_PREFIX='+root+'/install':x.startsWith('-DCJ_LLVM_COMMIT=')?'-DCJ_LLVM_COMMIT='+state.commit:x.startsWith('-DLLVM_PARALLEL_LINK_JOBS=')?'-DLLVM_PARALLEL_LINK_JOBS=2':x);
run('configure','/usr/bin/cmake',[...args,'-S',source,'-B',root+'/build']);
run('build','/usr/bin/cmake',['--build',root+'/build','--target','opt','llc','llvm-dis','llvm-as','llvm-extract','llvm-link','FileCheck','-j','12']);
run('install','/usr/bin/cmake',['--build',root+'/build','--target','install-opt','install-llc','install-llvm-dis','install-llvm-as','install-llvm-extract','install-llvm-link','install-LLVM','-j','4']);
