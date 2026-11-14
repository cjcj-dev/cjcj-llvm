#!/usr/bin/env zx
// Install the normal rebuilt compiler with its producer-carried dependencies,
// then exercise the original public missing-java diagnostic once.
import fs from 'node:fs';
import path from 'node:path';
import {spawn} from 'node:child_process';
import {createHash} from 'node:crypto';
import {pathToFileURL, fileURLToPath} from 'node:url';
const [mode,task,output,producer]=process.argv.slice(2);
if(!['install','consume'].includes(mode)||![task,output].every(x=>x&&path.isAbsolute(x)))throw Error('mode, absolute task and new output required');
const source=task+'/compiler-source',tuple='linux_x86_64_cjnative';
const digest=p=>({path:p,real:fs.realpathSync(p),sha256:createHash('sha256').update(fs.readFileSync(p)).digest('hex')});
if(mode==='install') {
  if(!producer||!path.isAbsolute(producer))throw Error('absolute compiler producer required');
  fs.mkdirSync(output);
  const sdk=task+'/core-r2/sdk',install=output+'/sdk';
  const metadata={platform:'linux_x86_64',compilerCommit:'2ceb9c05debfbdd55b06fe109d9ecade6decce50',compilerFile:'libexec/compiler/cjcj-stage1',compilerProducer:producer,llvmProduct:'6c308570df737c773416fb462a1f87d158bd0d58',scope:'String tail regression; not complete SDK qualification'};
  const config={work:output+'/flow',install,repos:{},platform:'linux_x86_64',stages:[{id:'install',output:install,metadata,copies:[
    {from:sdk,to:'',owner:'frozen normal core-r2 SDK',exclude:['bin/cjc','bin/cjc-frontend','bin/cjcj-stage1','bin/cjcj-stage1.entry','libexec/compiler','libexec/runtime','.compiler-exec','share/cjcj/cjo','share/cjcj/runtime_shim','compiler-inputs.json','STAGE-INPUTS.json','BUILD-MANIFEST.json','compiler-lineage.json']},
    {from:producer+'/bin/cjcj-stage1',to:'bin/cjcj-stage1',owner:'normal rebuilt compiler'},
    {from:producer+'/.compiler-exec',to:'.compiler-exec',owner:'normal compiler link dependencies'},
    {from:producer+'/share/cjcj/cjo',to:'share/cjcj/cjo',owner:'normal compiler modules'},
    {from:producer+'/share/cjcj/runtime_shim',to:'share/cjcj/runtime_shim',owner:'normal compiler shim'},
    {from:producer+'/compiler-inputs.json',to:'compiler-inputs.json',owner:'normal producer facts'}],
    entries:[{directory:'bin',retain:'libexec/compiler',names:['cjcj-stage1'],libraries:['.compiler-exec/runtime/lib/'+tuple,'.compiler-exec/lib/'+tuple,'.compiler-exec/third_party/llvm/lib','tools/lib']}],
    links:{'bin/cjc':'cjcj-stage1','bin/cjc-frontend':'cjcj-stage1','libexec/compiler/cjc':'cjcj-stage1','libexec/compiler/cjc-frontend':'cjcj-stage1','libexec/runtime':'../.compiler-exec/runtime'}}],finalStage:'install'};
  fs.writeFileSync(output+'/install.json',JSON.stringify(config,null,2));
  const child=spawn(process.execPath,[source+'/ci/bootstrap/sdk-flow.mjs','--config',output+'/install.json','--no-package'],{stdio:'inherit'});
  const result=await new Promise((resolve,reject)=>{child.on('error',reject);child.on('exit',(rc,signal)=>resolve({rc,signal}));});
  fs.writeFileSync(output+'/install-result.json',JSON.stringify(result,null,2));
  process.exitCode=result.rc??1;
} else {
  const sdk=output+'/sdk',result={sdk,scope:'one missing-java public diagnostic; no original-crash causality claim'};
  const cgroup='/sys/fs/cgroup'+fs.readFileSync('/proc/self/cgroup','utf8').trim().split('::').at(-1);
  result.resources=Object.fromEntries(['cpuset.cpus.effective','memory.max','memory.swap.max'].map(k=>[k,fs.readFileSync(cgroup+'/'+k,'utf8').trim()]));
  result.limits=fs.readFileSync('/proc/self/limits','utf8');
  const save=()=>fs.writeFileSync(output+'/consumer-result.json',JSON.stringify(result,null,2));save();
  if(result.resources['memory.swap.max']!=='0'||!result.limits.match(/Max core file size\s+0\s+0/))throw Error('resource contract');
  const {cleanSdkEnvironment}=await import(pathToFileURL(source+'/ci/bootstrap/sdk-platform.mjs'));
  const env=cleanSdkEnvironment(sdk,'linux_x86_64',process.env,sdk+'/.compiler-exec');env.LD_DEBUG='libs';
  result.env=Object.fromEntries(['HOME','PATH','CANGJIE_HOME','LD_LIBRARY_PATH','LD_DEBUG','cjHeapSize'].map(k=>[k,env[k]??null]));
  result.identity=['libexec/compiler/cjcj-stage1','.compiler-exec/runtime/lib/'+tuple+'/libcangjie-runtime.so','.compiler-exec/third_party/llvm/lib/libLLVM-15.so'].map(p=>digest(sdk+'/'+p));
  result.entry=fs.readFileSync(sdk+'/bin/cjcj-stage1.entry','utf8');
  const input='/mnt/cjcj-data/impl_full_sdk_sol_1108/mainline-test-1111/cangjie_test/testsuites/LLT/compiler/CJMP/java/sema/let_pattern.cj';
  result.input=digest(input);result.argv=[sdk+'/bin/cjc','-j4','--error-count-limit=10000','--diagnostic-format=noColor',input,'-o',output+'/let_pattern.out','--output-type=dylib','-L'+sdk+'/runtime/lib/'+tuple,'-ljava.internal','-ljava.lang'];
  result.cwd=output;result.started=new Date().toISOString();save();
  const stdout=fs.openSync(output+'/let_pattern.stdout','wx'),stderr=fs.openSync(output+'/let_pattern.stderr','wx');
  const child=spawn(result.argv[0],result.argv.slice(1),{cwd:output,env,stdio:['ignore',stdout,stderr]});
  const observed=new Map(),timer=setInterval(()=>{try{const exe=fs.readlinkSync('/proc/'+child.pid+'/exe');if(exe.includes('/libexec/compiler/'))observed.set(exe,{pid:child.pid,exe,maps:fs.readFileSync('/proc/'+child.pid+'/maps','utf8').split('\n').filter(l=>/libLLVM|libcangjie-runtime|libboundscheck/.test(l))});}catch{}},20);
  const status=await new Promise((resolve,reject)=>{child.on('error',reject);child.on('exit',(rc,signal)=>resolve({rc,signal}));});clearInterval(timer);fs.closeSync(stdout);fs.closeSync(stderr);
  Object.assign(result,status,{ended:new Date().toISOString(),processes:[...observed.values()]});save();
  const diagnostic=fs.readFileSync(output+'/let_pattern.stdout','utf8')+fs.readFileSync(output+'/let_pattern.stderr','utf8');
  result.expectedExitReached=result.rc===1&&result.signal===null;
  result.missingJavaReached=diagnostic.includes("can not find package 'java.lang'");save();
  if(!result.expectedExitReached||!result.missingJavaReached)throw Error('PUBLIC_MISSING_JAVA_CONTROL_FAILED');
  console.log('PUBLIC_MISSING_JAVA_EXPECTED_EXIT_1');
}
