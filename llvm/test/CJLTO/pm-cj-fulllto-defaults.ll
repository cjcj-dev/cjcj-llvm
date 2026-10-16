; XFAIL: *
; Basic test for the cangjie FullLTO pipeline.

; RUN: llvm-as %s -o %t
; RUN: ld.lld -shared --plugin-opt=debug-pass-manager --mllvm --cangjie-pipeline \
; RUN:     --plugin-opt=no-opaque-pointers --mllvm --cangjie-full-lto %t -o %t1 2>&1 \
; RUN:     | FileCheck %s --check-prefix=CHECK-O

; CHECK-O: Running pass: VerifierPass
; CHECK-O-NEXT: Running analysis: VerifierAnalysis
; CHECK-O-NEXT: Running pass: CJRuntimeLowering
; CHECK-O-NEXT: Running analysis: InnerAnalysisManagerProxy<{{.*}}Module
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on llvm.cj.memset.p0i8
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN11std$FS$time8DateTime3nowE$timeZone___0v
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN11std$FS$time8DateTime3nowEC_ZN11std$FS$time8TimeZoneE
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on llvm.memcpy.p0i8.p0i8.i64
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN11std$FS$time8DateTime1-ER_ZN11std$FS$time8DateTimeE
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN11std$FS$time8Duration13toNanosecondsEv
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN11std$FS$core6String23createStringFromLiteralE
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN13std$FS$format6Extend7Float646formatER_ZN11std$FS$core6StringE
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN11std$FS$core6String1+ER_ZN11std$FS$core6StringE
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN11std$FS$core7printlnER_ZN11std$FS$core6StringE
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on llvm.sadd.with.overflow.i64
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on llvm.expect.i1
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on rt$CreateOverflowException_msg
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on CJ_MCC_ThrowException
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on user.main
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on CJ_MCC_C2NStub
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on CJ_MCC_N2CStub
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on llvm.cj.heapmalloc.class
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on CJ_MCC_NewObjectFast
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on CJ_MCC_OnFinalizerCreated
; CHECK-O-NEXT: Running pass: Annotation2MetadataPass
; CHECK-O-NEXT: Running pass: CrossDSOCFIPass
; CHECK-O-NEXT: Running pass: OpenMPOptPass
; CHECK-O-NEXT: Running pass: GlobalDCEPass
; CHECK-O-NEXT: Invalidating analysis: VerifierAnalysis
; CHECK-O-NEXT: Invalidating analysis: InnerAnalysisManagerProxy<{{.*}}Module
; CHECK-O-NEXT: Running pass: ForceFunctionAttrsPass
; CHECK-O-NEXT: Running pass: InferFunctionAttrsPass
; CHECK-O-NEXT: Running analysis: InnerAnalysisManagerProxy<{{.*}}Module
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on llvm.cj.memset.p0i8
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN11std$FS$time8DateTime3nowE$timeZone___0v
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN11std$FS$time8DateTime3nowEC_ZN11std$FS$time8TimeZoneE
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on llvm.memcpy.p0i8.p0i8.i64
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN11std$FS$time8DateTime1-ER_ZN11std$FS$time8DateTimeE
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN11std$FS$time8Duration13toNanosecondsEv
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN11std$FS$core6String23createStringFromLiteralE
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN13std$FS$format6Extend7Float646formatER_ZN11std$FS$core6StringE
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN11std$FS$core6String1+ER_ZN11std$FS$core6StringE
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN11std$FS$core7printlnER_ZN11std$FS$core6StringE
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on llvm.sadd.with.overflow.i64
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on llvm.expect.i1
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on rt$CreateOverflowException_msg
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on CJ_MCC_ThrowException
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on CJ_MCC_C2NStub
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on CJ_MCC_N2CStub
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on CJ_MCC_NewObjectFast
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on CJ_MCC_OnFinalizerCreated
; CHECK-O-NEXT: Invalidating analysis: InnerAnalysisManagerProxy<{{.*}}Module
; CHECK-O-NEXT: Running analysis: InnerAnalysisManagerProxy<{{.*}}Module
; CHECK-O-NEXT: Running pass: CallSiteSplittingPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: TargetIRAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: DominatorTreeAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: CallSiteSplittingPass on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: TargetIRAnalysis on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Invalidating analysis: DominatorTreeAnalysis on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running pass: CallSiteSplittingPass on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: TargetIRAnalysis on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Invalidating analysis: DominatorTreeAnalysis on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Running pass: CallSiteSplittingPass on user.main
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on user.main
; CHECK-O-NEXT: Running analysis: TargetIRAnalysis on user.main
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on user.main
; CHECK-O-NEXT: Invalidating analysis: DominatorTreeAnalysis on user.main
; CHECK-O-NEXT: Running pass: PGOIndirectCallPromotion
; CHECK-O-NEXT: Running analysis: ProfileSummaryAnalysis
; CHECK-O-NEXT: Running analysis: OptimizationRemarkEmitterAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: OptimizationRemarkEmitterAnalysis on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: OptimizationRemarkEmitterAnalysis on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: OptimizationRemarkEmitterAnalysis on user.main
; CHECK-O-NEXT: Running pass: IPSCCPPass
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: AssumptionAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: AssumptionAnalysis on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: AssumptionAnalysis on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on user.main
; CHECK-O-NEXT: Running analysis: AssumptionAnalysis on user.main
; CHECK-O-NEXT: Running pass: CalledValuePropagationPass
; CHECK-O-NEXT: Running analysis: InnerAnalysisManagerProxy<{{.*}}Module
; CHECK-O-NEXT: Running analysis: LazyCallGraphAnalysis
; CHECK-O-NEXT: Running analysis: FunctionAnalysisManagerCGSCCProxy on (_ZN7default17benchmarkIfElseD4Ev)
; CHECK-O-NEXT: Running analysis: OuterAnalysisManagerProxy<{{.*}}LazyCallGraph
; CHECK-O-NEXT: Running pass: PostOrderFunctionAttrsPass on (_ZN7default17benchmarkIfElseD4Ev)
; CHECK-O-NEXT: Running analysis: AAManager on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: BasicAA on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: ScopedNoAliasAA on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: TypeBasedAA on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: OuterAnalysisManagerProxy<{{.*}}Function
; CHECK-O-NEXT: Running analysis: FunctionAnalysisManagerCGSCCProxy on (_ZN7default21timeBenchmarkIfElseD4Ev)
; CHECK-O-NEXT: Running analysis: OuterAnalysisManagerProxy<{{.*}}LazyCallGraph
; CHECK-O-NEXT: Running pass: PostOrderFunctionAttrsPass on (_ZN7default21timeBenchmarkIfElseD4Ev)
; CHECK-O-NEXT: Running analysis: AAManager on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: BasicAA on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: ScopedNoAliasAA on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: TypeBasedAA on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: OuterAnalysisManagerProxy<{{.*}}Function
; CHECK-O-NEXT: Running analysis: FunctionAnalysisManagerCGSCCProxy on (_ZN7default4mainEv)
; CHECK-O-NEXT: Running analysis: OuterAnalysisManagerProxy<{{.*}}LazyCallGraph
; CHECK-O-NEXT: Running pass: PostOrderFunctionAttrsPass on (_ZN7default4mainEv)
; CHECK-O-NEXT: Running analysis: AAManager on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: BasicAA on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: ScopedNoAliasAA on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: TypeBasedAA on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: OuterAnalysisManagerProxy<{{.*}}Function
; CHECK-O-NEXT: Running analysis: FunctionAnalysisManagerCGSCCProxy on (user.main)
; CHECK-O-NEXT: Running analysis: OuterAnalysisManagerProxy<{{.*}}LazyCallGraph
; CHECK-O-NEXT: Running pass: PostOrderFunctionAttrsPass on (user.main)
; CHECK-O-NEXT: Running analysis: AAManager on user.main
; CHECK-O-NEXT: Running analysis: BasicAA on user.main
; CHECK-O-NEXT: Running analysis: ScopedNoAliasAA on user.main
; CHECK-O-NEXT: Running analysis: TypeBasedAA on user.main
; CHECK-O-NEXT: Running analysis: OuterAnalysisManagerProxy<{{.*}}Function
; CHECK-O-NEXT: Running pass: ReversePostOrderFunctionAttrsPass
; CHECK-O-NEXT: Running analysis: CallGraphAnalysis
; CHECK-O-NEXT: Running pass: GlobalSplitPass
; CHECK-O-NEXT: Running pass: WholeProgramDevirtPass
; CHECK-O-NEXT: Invalidating analysis: InnerAnalysisManagerProxy<{{.*}}Module
; CHECK-O-NEXT: Invalidating analysis: LazyCallGraphAnalysis
; CHECK-O-NEXT: Invalidating analysis: InnerAnalysisManagerProxy<{{.*}}Module
; CHECK-O-NEXT: Invalidating analysis: CallGraphAnalysis
; CHECK-O-NEXT: Running pass: GlobalOptPass
; CHECK-O-NEXT: Running analysis: InnerAnalysisManagerProxy<{{.*}}Module
; CHECK-O-NEXT: Running analysis: BlockFrequencyAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: BranchProbabilityAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: LoopAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: PostDominatorTreeAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: TargetIRAnalysis on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: TargetIRAnalysis on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Running pass: PromotePass on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: AssumptionAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: TargetIRAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: PromotePass on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: AssumptionAnalysis on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running pass: PromotePass on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: AssumptionAnalysis on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Running pass: PromotePass on user.main
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on user.main
; CHECK-O-NEXT: Running analysis: AssumptionAnalysis on user.main
; CHECK-O-NEXT: Running analysis: TargetIRAnalysis on user.main
; CHECK-O-NEXT: Running pass: ConstantMergePass
; CHECK-O-NEXT: Running pass: DeadArgumentEliminationPass
; CHECK-O-NEXT: Invalidating analysis: InnerAnalysisManagerProxy<{{.*}}Module
; CHECK-O-NEXT: Running analysis: InnerAnalysisManagerProxy<{{.*}}Module
; CHECK-O-NEXT: Running pass: InstCombinePass on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: AssumptionAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: TargetIRAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: OptimizationRemarkEmitterAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: AAManager on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: BasicAA on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: ScopedNoAliasAA on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: TypeBasedAA on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: OuterAnalysisManagerProxy<{{.*}}Function
; CHECK-O-NEXT: Invalidating analysis: DominatorTreeAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: BasicAA on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: AAManager on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: InstCombinePass on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: AssumptionAnalysis on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: TargetIRAnalysis on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: OptimizationRemarkEmitterAnalysis on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: AAManager on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: BasicAA on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: ScopedNoAliasAA on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: TypeBasedAA on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: OuterAnalysisManagerProxy<{{.*}}Function
; CHECK-O-NEXT: Invalidating analysis: DominatorTreeAnalysis on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Invalidating analysis: BasicAA on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Invalidating analysis: AAManager on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running pass: InstCombinePass on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: AssumptionAnalysis on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: TargetIRAnalysis on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: OptimizationRemarkEmitterAnalysis on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: AAManager on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: BasicAA on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: ScopedNoAliasAA on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: TypeBasedAA on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: OuterAnalysisManagerProxy<{{.*}}Function
; CHECK-O-NEXT: Invalidating analysis: DominatorTreeAnalysis on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Invalidating analysis: BasicAA on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Invalidating analysis: AAManager on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Running pass: InstCombinePass on user.main
; CHECK-O-NEXT: Running analysis: AssumptionAnalysis on user.main
; CHECK-O-NEXT: Running analysis: TargetIRAnalysis on user.main
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on user.main
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on user.main
; CHECK-O-NEXT: Running analysis: OptimizationRemarkEmitterAnalysis on user.main
; CHECK-O-NEXT: Running analysis: AAManager on user.main
; CHECK-O-NEXT: Running analysis: BasicAA on user.main
; CHECK-O-NEXT: Running analysis: ScopedNoAliasAA on user.main
; CHECK-O-NEXT: Running analysis: TypeBasedAA on user.main
; CHECK-O-NEXT: Running analysis: OuterAnalysisManagerProxy<{{.*}}Function
; CHECK-O-NEXT: Invalidating analysis: DominatorTreeAnalysis on user.main
; CHECK-O-NEXT: Invalidating analysis: BasicAA on user.main
; CHECK-O-NEXT: Invalidating analysis: AAManager on user.main
; CHECK-O-NEXT: Running pass: ModuleInlinerWrapperPass
; CHECK-O-NEXT: Running analysis: InlineAdvisorAnalysis
; CHECK-O-NEXT: Running analysis: InnerAnalysisManagerProxy<{{.*}}Module
; CHECK-O-NEXT: Running analysis: LazyCallGraphAnalysis
; CHECK-O-NEXT: Running analysis: FunctionAnalysisManagerCGSCCProxy on (_ZN7default17benchmarkIfElseD4Ev)
; CHECK-O-NEXT: Running analysis: OuterAnalysisManagerProxy<{{.*}}LazyCallGraph
; CHECK-O-NEXT: Running pass: InlinerPass on (_ZN7default17benchmarkIfElseD4Ev)
; CHECK-O-NEXT: Running pass: InlinerPass on (_ZN7default17benchmarkIfElseD4Ev)
; CHECK-O-NEXT: Running analysis: FunctionAnalysisManagerCGSCCProxy on (_ZN7default21timeBenchmarkIfElseD4Ev)
; CHECK-O-NEXT: Running analysis: OuterAnalysisManagerProxy<{{.*}}LazyCallGraph
; CHECK-O-NEXT: Running pass: InlinerPass on (_ZN7default21timeBenchmarkIfElseD4Ev)
; CHECK-O-NEXT: Running pass: InlinerPass on (_ZN7default21timeBenchmarkIfElseD4Ev)
; CHECK-O-NEXT: Running analysis: BlockFrequencyAnalysis on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: BranchProbabilityAnalysis on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: LoopAnalysis on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: PostDominatorTreeAnalysis on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: BlockFrequencyAnalysis on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: BranchProbabilityAnalysis on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: LoopAnalysis on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: PostDominatorTreeAnalysis on _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: AAManager on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: BasicAA on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Invalidating analysis: DominatorTreeAnalysis on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Invalidating analysis: LoopAnalysis on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Invalidating analysis: PostDominatorTreeAnalysis on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Invalidating analysis: BranchProbabilityAnalysis on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Invalidating analysis: BlockFrequencyAnalysis on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Invalidating analysis: BasicAA on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Invalidating analysis: AAManager on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Clearing all analysis results for: _ZN7default17benchmarkIfElseD4Ev
; CHECK-O-NEXT: Clearing all analysis results for: (_ZN7default17benchmarkIfElseD4Ev)
; CHECK-O-NEXT: Running analysis: FunctionAnalysisManagerCGSCCProxy on (_ZN7default4mainEv)
; CHECK-O-NEXT: Running analysis: OuterAnalysisManagerProxy<{{.*}}LazyCallGraph
; CHECK-O-NEXT: Running pass: InlinerPass on (_ZN7default4mainEv)
; CHECK-O-NEXT: Running pass: InlinerPass on (_ZN7default4mainEv)
; CHECK-O-NEXT: Running analysis: BlockFrequencyAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: BranchProbabilityAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: LoopAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: PostDominatorTreeAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: BlockFrequencyAnalysis on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: BranchProbabilityAnalysis on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: LoopAnalysis on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: PostDominatorTreeAnalysis on _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Running analysis: AAManager on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: BasicAA on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: DominatorTreeAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: LoopAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: PostDominatorTreeAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: BranchProbabilityAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: BlockFrequencyAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: BasicAA on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: AAManager on _ZN7default4mainEv
; CHECK-O-NEXT: Clearing all analysis results for: _ZN7default21timeBenchmarkIfElseD4Ev
; CHECK-O-NEXT: Clearing all analysis results for: (_ZN7default21timeBenchmarkIfElseD4Ev)
; CHECK-O-NEXT: Running analysis: FunctionAnalysisManagerCGSCCProxy on (user.main)
; CHECK-O-NEXT: Running analysis: OuterAnalysisManagerProxy<{{.*}}LazyCallGraph
; CHECK-O-NEXT: Running pass: InlinerPass on (user.main)
; CHECK-O-NEXT: Running pass: InlinerPass on (user.main)
; CHECK-O-NEXT: Running analysis: BlockFrequencyAnalysis on user.main
; CHECK-O-NEXT: Running analysis: BranchProbabilityAnalysis on user.main
; CHECK-O-NEXT: Running analysis: LoopAnalysis on user.main
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on user.main
; CHECK-O-NEXT: Running analysis: PostDominatorTreeAnalysis on user.main
; CHECK-O-NEXT: Invalidating analysis: InlineAdvisorAnalysis
; CHECK-O-NEXT: Running pass: SimplifyCFGPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: SimplifyCFGPass on user.main
; CHECK-O-NEXT: Invalidating analysis: DominatorTreeAnalysis on user.main
; CHECK-O-NEXT: Invalidating analysis: LoopAnalysis on user.main
; CHECK-O-NEXT: Invalidating analysis: PostDominatorTreeAnalysis on user.main
; CHECK-O-NEXT: Invalidating analysis: BranchProbabilityAnalysis on user.main
; CHECK-O-NEXT: Invalidating analysis: BlockFrequencyAnalysis on user.main
; CHECK-O-NEXT: Invalidating analysis: LazyCallGraphAnalysis
; CHECK-O-NEXT: Invalidating analysis: InnerAnalysisManagerProxy<{{.*}}Module
; CHECK-O-NEXT: Running analysis: InnerAnalysisManagerProxy<{{.*}}Module
; CHECK-O-NEXT: Running analysis: LazyCallGraphAnalysis
; CHECK-O-NEXT: Running analysis: FunctionAnalysisManagerCGSCCProxy on (_ZN7default4mainEv)
; CHECK-O-NEXT: Running analysis: OuterAnalysisManagerProxy<{{.*}}LazyCallGraph
; CHECK-O-NEXT: Running pass: PEAPass on (_ZN7default4mainEv)
; CHECK-O-NEXT: Running analysis: LoopAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: DominatorTreeAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: LoopAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: FunctionAnalysisManagerCGSCCProxy on (user.main)
; CHECK-O-NEXT: Running analysis: OuterAnalysisManagerProxy<{{.*}}LazyCallGraph
; CHECK-O-NEXT: Running pass: PEAPass on (user.main)
; CHECK-O-NEXT: Running analysis: LoopAnalysis on user.main
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on user.main
; CHECK-O-NEXT: Invalidating analysis: DominatorTreeAnalysis on user.main
; CHECK-O-NEXT: Invalidating analysis: LoopAnalysis on user.main
; CHECK-O-NEXT: Running pass: SimplifyCFGPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: SimplifyCFGPass on user.main
; CHECK-O-NEXT: Running pass: PartialEscapeAnalysisPass on (_ZN7default4mainEv)
; CHECK-O-NEXT: Running analysis: LoopAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: PartialEscapeAnalysisPass on (user.main)
; CHECK-O-NEXT: Running analysis: LoopAnalysis on user.main
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on user.main
; CHECK-O-NEXT: Running pass: GlobalOptPass
; CHECK-O-NEXT: Running pass: GlobalDCEPass
; CHECK-O-NEXT: Running pass: ArgumentPromotionPass on (_ZN7default4mainEv)
; CHECK-O-NEXT: Running pass: ArgumentPromotionPass on (user.main)
; CHECK-O-NEXT: Running pass: SROAPass on _ZN7default4mainEv (411 instructions)
; CHECK-O-NEXT: Running pass: EarlyCSEPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: MemorySSAAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: AAManager on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: BasicAA on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: SpeculativeExecutionPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: JumpThreadingPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: LazyValueAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: CorrelatedValuePropagationPass on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: LoopAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: MemorySSAAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: LazyValueAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: SimplifyCFGPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: InstCombinePass on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: LibCallsShrinkWrapPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: TailCallElimPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: SimplifyCFGPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: ReassociatePass on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: InstCombinePass on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: RequireAnalysisPass
; CHECK-O-NEXT: Running pass: LoopSimplifyPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: LoopAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: LCSSAPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: MemorySSAAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: ScalarEvolutionAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: InnerAnalysisManagerProxy<{{.*}}Function
; CHECK-O-NEXT: Running pass: LoopRotatePass on Loop at depth 1
; CHECK-O-NEXT: Running pass: IndVarSimplifyPass on Loop at depth 1
; CHECK-O-NEXT: Running pass: LoopDeletionPass on Loop at depth 1
; CHECK-O-NEXT: Running pass: LoopInstSimplifyPass on Loop at depth 1
; CHECK-O-NEXT: Running pass: LoopSimplifyCFGPass on Loop at depth 1
; CHECK-O-NEXT: Running pass: LICMPass on Loop at depth 1
; CHECK-O-NEXT: Running pass: LoopRotatePass on Loop at depth 1
; CHECK-O-NEXT: Running pass: LICMPass on Loop at depth 1
; CHECK-O-NEXT: Running pass: SimpleLoopUnswitchPass on Loop at depth 1
; CHECK-O-NEXT: Running pass: LoopRotatePass on Loop at depth 1
; CHECK-O-NEXT: Running pass: IndVarSimplifyPass on Loop at depth 1
; CHECK-O-NEXT: Running pass: LoopDeletionPass on Loop at depth 1
; CHECK-O-NEXT: Running pass: LoopInstSimplifyPass on Loop at depth 1
; CHECK-O-NEXT: Running pass: LoopSimplifyCFGPass on Loop at depth 1
; CHECK-O-NEXT: Running pass: LICMPass on Loop at depth 1
; CHECK-O-NEXT: Running pass: LoopRotatePass on Loop at depth 1
; CHECK-O-NEXT: Running pass: LICMPass on Loop at depth 1
; CHECK-O-NEXT: Running pass: SimpleLoopUnswitchPass on Loop at depth 1
; CHECK-O-NEXT: Running pass: SimplifyCFGPass on _ZN7default4mainEv
; CHECK-O-NEXT: Clearing all analysis results for: <possibly invalidated loop>
; CHECK-O-NEXT: Invalidating analysis: DominatorTreeAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: BasicAA on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: AAManager on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: LoopAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: MemorySSAAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: ScalarEvolutionAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: InnerAnalysisManagerProxy<{{.*}}Function
; CHECK-O-NEXT: Running pass: InstCombinePass on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: AAManager on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: BasicAA on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: LoopSimplifyPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: LoopAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: LCSSAPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: ScalarEvolutionAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: InnerAnalysisManagerProxy<{{.*}}Function
; CHECK-O-NEXT: Running pass: LoopIdiomRecognizePass on Loop at depth 1
; CHECK-O-NEXT: Running pass: IndVarSimplifyPass on Loop at depth 1
; CHECK-O-NEXT: Running pass: LoopDeletionPass on Loop at depth 1
; CHECK-O-NEXT: Running pass: LoopFullUnrollPass on Loop at depth 1
; CHECK-O-NEXT: Running pass: SROAPass on _ZN7default4mainEv
; CHECK-O-NEXT: Clearing all analysis results for: <possibly invalidated loop>
; CHECK-O-NEXT: Invalidating analysis: ScalarEvolutionAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: InnerAnalysisManagerProxy<{{.*}}Function
; CHECK-O-NEXT: Running pass: MergedLoadStoreMotionPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: GVNPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: MemoryDependenceAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: PhiValuesAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: PhiValuesAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: MemoryDependenceAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: SCCPPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: BDCEPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: DemandedBitsAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: InstCombinePass on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: DemandedBitsAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: JumpThreadingPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: LazyValueAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: CorrelatedValuePropagationPass on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: LazyValueAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: ADCEPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: PostDominatorTreeAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: MemCpyOptPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: MemorySSAAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: DSEPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: LoopSimplifyPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: LCSSAPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: ScalarEvolutionAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: InnerAnalysisManagerProxy<{{.*}}Function
; CHECK-O-NEXT: Running pass: LICMPass on Loop at depth 1
; CHECK-O-NEXT: Invalidating analysis: PostDominatorTreeAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: CoroElidePass on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: SimplifyCFGPass on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: DominatorTreeAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: BasicAA on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: AAManager on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: LoopAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: MemorySSAAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: ScalarEvolutionAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: InnerAnalysisManagerProxy<{{.*}}Function
; CHECK-O-NEXT: Running pass: InstCombinePass on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: AAManager on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: BasicAA on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: DominatorTreeAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: BasicAA on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: AAManager on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: SROAPass on user.main
; CHECK-O-NEXT: Running pass: EarlyCSEPass on user.main
; CHECK-O-NEXT: Running analysis: MemorySSAAnalysis on user.main
; CHECK-O-NEXT: Running analysis: AAManager on user.main
; CHECK-O-NEXT: Running analysis: BasicAA on user.main
; CHECK-O-NEXT: Running pass: SpeculativeExecutionPass on user.main
; CHECK-O-NEXT: Running pass: JumpThreadingPass on user.main
; CHECK-O-NEXT: Running analysis: LazyValueAnalysis on user.main
; CHECK-O-NEXT: Running pass: CorrelatedValuePropagationPass on user.main
; CHECK-O-NEXT: Invalidating analysis: LazyValueAnalysis on user.main
; CHECK-O-NEXT: Running pass: SimplifyCFGPass on user.main
; CHECK-O-NEXT: Running pass: InstCombinePass on user.main
; CHECK-O-NEXT: Running pass: LibCallsShrinkWrapPass on user.main
; CHECK-O-NEXT: Running pass: TailCallElimPass on user.main
; CHECK-O-NEXT: Invalidating analysis: LoopAnalysis on user.main
; CHECK-O-NEXT: Invalidating analysis: MemorySSAAnalysis on user.main
; CHECK-O-NEXT: Running pass: SimplifyCFGPass on user.main
; CHECK-O-NEXT: Running pass: ReassociatePass on user.main
; CHECK-O-NEXT: Running pass: InstCombinePass on user.main
; CHECK-O-NEXT: Running pass: RequireAnalysisPass
; CHECK-O-NEXT: Running pass: LoopSimplifyPass on user.main
; CHECK-O-NEXT: Running analysis: LoopAnalysis on user.main
; CHECK-O-NEXT: Running pass: LCSSAPass on user.main
; CHECK-O-NEXT: Running pass: SimplifyCFGPass on user.main
; CHECK-O-NEXT: Running pass: InstCombinePass on user.main
; CHECK-O-NEXT: Running pass: LoopSimplifyPass on user.main
; CHECK-O-NEXT: Running pass: LCSSAPass on user.main
; CHECK-O-NEXT: Running pass: SROAPass on user.main
; CHECK-O-NEXT: Running pass: MergedLoadStoreMotionPass on user.main
; CHECK-O-NEXT: Running pass: GVNPass on user.main
; CHECK-O-NEXT: Running analysis: MemoryDependenceAnalysis on user.main
; CHECK-O-NEXT: Running analysis: PhiValuesAnalysis on user.main
; CHECK-O-NEXT: Running pass: SCCPPass on user.main
; CHECK-O-NEXT: Running pass: BDCEPass on user.main
; CHECK-O-NEXT: Running analysis: DemandedBitsAnalysis on user.main
; CHECK-O-NEXT: Running pass: InstCombinePass on user.main
; CHECK-O-NEXT: Running pass: JumpThreadingPass on user.main
; CHECK-O-NEXT: Running analysis: LazyValueAnalysis on user.main
; CHECK-O-NEXT: Running pass: CorrelatedValuePropagationPass on user.main
; CHECK-O-NEXT: Invalidating analysis: LazyValueAnalysis on user.main
; CHECK-O-NEXT: Running pass: ADCEPass on user.main
; CHECK-O-NEXT: Running analysis: PostDominatorTreeAnalysis on user.main
; CHECK-O-NEXT: Running pass: MemCpyOptPass on user.main
; CHECK-O-NEXT: Running analysis: MemorySSAAnalysis on user.main
; CHECK-O-NEXT: Running pass: DSEPass on user.main
; CHECK-O-NEXT: Running pass: LoopSimplifyPass on user.main
; CHECK-O-NEXT: Running pass: LCSSAPass on user.main
; CHECK-O-NEXT: Running pass: CoroElidePass on user.main
; CHECK-O-NEXT: Running pass: SimplifyCFGPass on user.main
; CHECK-O-NEXT: Running pass: InstCombinePass on user.main
; CHECK-O-NEXT: Invalidating analysis: DominatorTreeAnalysis on user.main
; CHECK-O-NEXT: Invalidating analysis: BasicAA on user.main
; CHECK-O-NEXT: Invalidating analysis: AAManager on user.main
; CHECK-O-NEXT: Invalidating analysis: LoopAnalysis on user.main
; CHECK-O-NEXT: Invalidating analysis: PhiValuesAnalysis on user.main
; CHECK-O-NEXT: Invalidating analysis: MemoryDependenceAnalysis on user.main
; CHECK-O-NEXT: Invalidating analysis: DemandedBitsAnalysis on user.main
; CHECK-O-NEXT: Invalidating analysis: PostDominatorTreeAnalysis on user.main
; CHECK-O-NEXT: Invalidating analysis: MemorySSAAnalysis on user.main
; CHECK-O-NEXT: Invalidating analysis: LazyCallGraphAnalysis
; CHECK-O-NEXT: Invalidating analysis: InnerAnalysisManagerProxy<{{.*}}Module
; CHECK-O-NEXT: Running pass: CJDevirtualOpt
; CHECK-O-NEXT: Running pass: InstCombinePass on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: AAManager on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: BasicAA on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: JumpThreadingPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: LazyValueAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: SROAPass on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: LazyValueAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: TailCallElimPass on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: DominatorTreeAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: BasicAA on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: AAManager on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: InstCombinePass on user.main
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on user.main
; CHECK-O-NEXT: Running analysis: AAManager on user.main
; CHECK-O-NEXT: Running analysis: BasicAA on user.main
; CHECK-O-NEXT: Running pass: JumpThreadingPass on user.main
; CHECK-O-NEXT: Running analysis: LazyValueAnalysis on user.main
; CHECK-O-NEXT: Running pass: SROAPass on user.main
; CHECK-O-NEXT: Running pass: TailCallElimPass on user.main
; CHECK-O-NEXT: Invalidating analysis: DominatorTreeAnalysis on user.main
; CHECK-O-NEXT: Invalidating analysis: BasicAA on user.main
; CHECK-O-NEXT: Invalidating analysis: AAManager on user.main
; CHECK-O-NEXT: Invalidating analysis: LazyValueAnalysis on user.main
; CHECK-O-NEXT: Running analysis: InnerAnalysisManagerProxy<{{.*}}Module
; CHECK-O-NEXT: Running analysis: LazyCallGraphAnalysis
; CHECK-O-NEXT: Running analysis: FunctionAnalysisManagerCGSCCProxy on (_ZN7default4mainEv)
; CHECK-O-NEXT: Running analysis: OuterAnalysisManagerProxy<{{.*}}LazyCallGraph
; CHECK-O-NEXT: Running pass: PostOrderFunctionAttrsPass on (_ZN7default4mainEv)
; CHECK-O-NEXT: Running analysis: AAManager on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: BasicAA on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: FunctionAnalysisManagerCGSCCProxy on (user.main)
; CHECK-O-NEXT: Running analysis: OuterAnalysisManagerProxy<{{.*}}LazyCallGraph
; CHECK-O-NEXT: Running pass: PostOrderFunctionAttrsPass on (user.main)
; CHECK-O-NEXT: Running analysis: AAManager on user.main
; CHECK-O-NEXT: Running analysis: BasicAA on user.main
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on user.main
; CHECK-O-NEXT: Running pass: RequireAnalysisPass
; CHECK-O-NEXT: Running analysis: GlobalsAA
; CHECK-O-NEXT: Running analysis: CallGraphAnalysis
; CHECK-O-NEXT: Running pass: InvalidateAnalysisPass<llvm::AAManager> on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: AAManager on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: InvalidateAnalysisPass<llvm::AAManager> on user.main
; CHECK-O-NEXT: Invalidating analysis: AAManager on user.main
; CHECK-O-NEXT: Running pass: OpenMPOptCGSCCPass on (_ZN7default4mainEv)
; CHECK-O-NEXT: Running pass: OpenMPOptCGSCCPass on (user.main)
; CHECK-O-NEXT: Running pass: LoopSimplifyPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: LoopAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: LCSSAPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: MemorySSAAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: AAManager on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: ScalarEvolutionAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: InnerAnalysisManagerProxy<{{.*}}Function
; CHECK-O-NEXT: Running pass: LICMPass on Loop at depth 1
; CHECK-O-NEXT: Running pass: GVNPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: MemoryDependenceAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: PhiValuesAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: ScalarEvolutionAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: InnerAnalysisManagerProxy<{{.*}}Function
; CHECK-O-NEXT: Invalidating analysis: PhiValuesAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: MemoryDependenceAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: MemCpyOptPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: DSEPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: PostDominatorTreeAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: MergedLoadStoreMotionPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: LoopSimplifyPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: LCSSAPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: ScalarEvolutionAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: InnerAnalysisManagerProxy<{{.*}}Function
; CHECK-O-NEXT: Running pass: IndVarSimplifyPass on Loop at depth 1
; CHECK-O-NEXT: Running pass: LoopDeletionPass on Loop at depth 1
; CHECK-O-NEXT: Running pass: LoopFullUnrollPass on Loop at depth 1
; CHECK-O-NEXT: Running pass: LoopDistributePass on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: LoopVectorizePass on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: BlockFrequencyAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: BranchProbabilityAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: DemandedBitsAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: LoopUnrollPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: WarnMissedTransformationsPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: InstCombinePass on _ZN7default4mainEv
; CHECK-O-NEXT: Clearing all analysis results for: <possibly invalidated loop>
; CHECK-O-NEXT: Invalidating analysis: MemorySSAAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: ScalarEvolutionAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: InnerAnalysisManagerProxy<{{.*}}Function
; CHECK-O-NEXT: Invalidating analysis: DemandedBitsAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: SimplifyCFGPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: SCCPPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: InstCombinePass on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: BDCEPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: DemandedBitsAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: VectorCombinePass on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: AlignmentFromAssumptionsPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: ScalarEvolutionAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: InstCombinePass on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: JumpThreadingPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: LazyValueAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: DominatorTreeAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: BasicAA on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: LoopAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: AAManager on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: PostDominatorTreeAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: BranchProbabilityAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: BlockFrequencyAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: DemandedBitsAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: ScalarEvolutionAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Invalidating analysis: LazyValueAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: LoopSimplifyPass on user.main
; CHECK-O-NEXT: Running analysis: LoopAnalysis on user.main
; CHECK-O-NEXT: Running pass: LCSSAPass on user.main
; CHECK-O-NEXT: Running pass: GVNPass on user.main
; CHECK-O-NEXT: Running analysis: AAManager on user.main
; CHECK-O-NEXT: Running analysis: MemoryDependenceAnalysis on user.main
; CHECK-O-NEXT: Running analysis: PhiValuesAnalysis on user.main
; CHECK-O-NEXT: Running pass: MemCpyOptPass on user.main
; CHECK-O-NEXT: Running analysis: MemorySSAAnalysis on user.main
; CHECK-O-NEXT: Running pass: DSEPass on user.main
; CHECK-O-NEXT: Running analysis: PostDominatorTreeAnalysis on user.main
; CHECK-O-NEXT: Running pass: MergedLoadStoreMotionPass on user.main
; CHECK-O-NEXT: Running pass: LoopSimplifyPass on user.main
; CHECK-O-NEXT: Running pass: LCSSAPass on user.main
; CHECK-O-NEXT: Running pass: LoopDistributePass on user.main
; CHECK-O-NEXT: Running analysis: ScalarEvolutionAnalysis on user.main
; CHECK-O-NEXT: Running analysis: InnerAnalysisManagerProxy<{{.*}}Function
; CHECK-O-NEXT: Running pass: LoopVectorizePass on user.main
; CHECK-O-NEXT: Running pass: LoopUnrollPass on user.main
; CHECK-O-NEXT: Running pass: WarnMissedTransformationsPass on user.main
; CHECK-O-NEXT: Running pass: InstCombinePass on user.main
; CHECK-O-NEXT: Running pass: SimplifyCFGPass on user.main
; CHECK-O-NEXT: Running pass: SCCPPass on user.main
; CHECK-O-NEXT: Running pass: InstCombinePass on user.main
; CHECK-O-NEXT: Running pass: BDCEPass on user.main
; CHECK-O-NEXT: Running analysis: DemandedBitsAnalysis on user.main
; CHECK-O-NEXT: Running pass: VectorCombinePass on user.main
; CHECK-O-NEXT: Running pass: AlignmentFromAssumptionsPass on user.main
; CHECK-O-NEXT: Running pass: InstCombinePass on user.main
; CHECK-O-NEXT: Running pass: JumpThreadingPass on user.main
; CHECK-O-NEXT: Running analysis: LazyValueAnalysis on user.main
; CHECK-O-NEXT: Invalidating analysis: DominatorTreeAnalysis on user.main
; CHECK-O-NEXT: Invalidating analysis: BasicAA on user.main
; CHECK-O-NEXT: Invalidating analysis: LoopAnalysis on user.main
; CHECK-O-NEXT: Invalidating analysis: AAManager on user.main
; CHECK-O-NEXT: Invalidating analysis: PhiValuesAnalysis on user.main
; CHECK-O-NEXT: Invalidating analysis: MemoryDependenceAnalysis on user.main
; CHECK-O-NEXT: Invalidating analysis: MemorySSAAnalysis on user.main
; CHECK-O-NEXT: Invalidating analysis: PostDominatorTreeAnalysis on user.main
; CHECK-O-NEXT: Invalidating analysis: ScalarEvolutionAnalysis on user.main
; CHECK-O-NEXT: Invalidating analysis: InnerAnalysisManagerProxy<{{.*}}Function
; CHECK-O-NEXT: Invalidating analysis: DemandedBitsAnalysis on user.main
; CHECK-O-NEXT: Invalidating analysis: LazyValueAnalysis on user.main
; CHECK-O-NEXT: Invalidating analysis: LazyCallGraphAnalysis
; CHECK-O-NEXT: Invalidating analysis: InnerAnalysisManagerProxy<{{.*}}Module
; CHECK-O-NEXT: Invalidating analysis: CallGraphAnalysis
; CHECK-O-NEXT: Running pass: LowerTypeTestsPass
; CHECK-O-NEXT: Running pass: LowerTypeTestsPass
; CHECK-O-NEXT: Running pass: SimplifyCFGPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: SimplifyCFGPass on user.main
; CHECK-O-NEXT: Running pass: EliminateAvailableExternallyPass
; CHECK-O-NEXT: Running pass: GlobalDCEPass
; CHECK-O-NEXT: Invalidating analysis: InnerAnalysisManagerProxy<{{.*}}Module
; CHECK-O-NEXT: Running pass: CGProfilePass
; CHECK-O-NEXT: Running analysis: InnerAnalysisManagerProxy<{{.*}}Module
; CHECK-O-NEXT: Running analysis: BlockFrequencyAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: BranchProbabilityAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: LoopAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: PostDominatorTreeAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: TargetIRAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: BlockFrequencyAnalysis on user.main
; CHECK-O-NEXT: Running analysis: BranchProbabilityAnalysis on user.main
; CHECK-O-NEXT: Running analysis: LoopAnalysis on user.main
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on user.main
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on user.main
; CHECK-O-NEXT: Running analysis: PostDominatorTreeAnalysis on user.main
; CHECK-O-NEXT: Running analysis: TargetIRAnalysis on user.main
; CHECK-O-NEXT: Running pass: AnnotationRemarksPass on _ZN7default4mainEv
; CHECK-O-NEXT: Running pass: AnnotationRemarksPass on user.main
; CHECK-O-NEXT: Running pass: CJSpecificOpt
; CHECK-O-NEXT: Invalidating analysis: InnerAnalysisManagerProxy<{{.*}}Module
; CHECK-O-NEXT: Running pass: PlaceSafepoints
; CHECK-O-NEXT: Running analysis: InnerAnalysisManagerProxy<{{.*}}Module
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on llvm.cj.memset.p0i8
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN11std$FS$time8DateTime3nowE$timeZone___0v
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN11std$FS$time8DateTime3nowEC_ZN11std$FS$time8TimeZoneE
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on llvm.memcpy.p0i8.p0i8.i64
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN11std$FS$time8DateTime1-ER_ZN11std$FS$time8DateTimeE
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN11std$FS$time8Duration13toNanosecondsEv
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN11std$FS$core6String23createStringFromLiteralE
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN13std$FS$format6Extend7Float646formatER_ZN11std$FS$core6StringE
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN11std$FS$core6String1+ER_ZN11std$FS$core6StringE
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN11std$FS$core7printlnER_ZN11std$FS$core6StringE
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on llvm.expect.i1
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on rt$CreateOverflowException_msg
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on CJ_MCC_ThrowException
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on user.main
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on CJ_MCC_C2NStub
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on CJ_MCC_N2CStub
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on CJ_MCC_NewObjectFast
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on CJ_MCC_OnFinalizerCreated
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on llvm.lifetime.start.p0i8
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on llvm.lifetime.end.p0i8
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on llvm.memset.p0i8.i64
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on CJ_MCC_StackCheck
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on MCC_SafepointStub
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on gc.safepoint_poll
; CHECK-O-NEXT: Invalidating analysis: InnerAnalysisManagerProxy<{{.*}}Module
; CHECK-O-NEXT: Running pass: CJBarrierOpt
; CHECK-O-NEXT: Running analysis: InnerAnalysisManagerProxy<{{.*}}Module
; CHECK-O-NEXT: Running analysis: LoopAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: LoopAnalysis on user.main
; CHECK-O-NEXT: Running analysis: DominatorTreeAnalysis on user.main
; CHECK-O-NEXT: Running pass: CJFastBarrier
; CHECK-O-NEXT: Running pass: RewriteStatepointsForCangjieGC
; CHECK-O-NEXT: Running analysis: PostDominatorTreeAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: TargetIRAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on _ZN7default4mainEv
; CHECK-O-NEXT: Running analysis: PostDominatorTreeAnalysis on user.main
; CHECK-O-NEXT: Running analysis: TargetIRAnalysis on user.main
; CHECK-O-NEXT: Running analysis: TargetLibraryAnalysis on user.main
; CHECK-O-NEXT: Invalidating analysis: InnerAnalysisManagerProxy<{{.*}}Module
; CHECK-O-NEXT: Running pass: VerifierPass
; CHECK-O-NEXT: Running analysis: VerifierAnalysis

target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

%"record._ZN11std$FS$core6StringE" = type { i8 addrspace(1)*, i64 }
%Unit.Type = type { i8 }
%"record._ZN11std$FS$time8DateTimeE" = type { i32, i32, i64, i64, i8 addrspace(1)*, i64 }
%"record._ZN11std$FS$time8DurationE" = type { i64 }

@_ZN7default1kE = global i64 2, align 8, !GlobalVarType !0
@_ZN7default1lE = global i64 2, align 8, !GlobalVarType !0
@_ZN7default1mE = global i64 2, align 8, !GlobalVarType !0
@_ZN7default1nE = global i64 2, align 8, !GlobalVarType !0
@_ZN7default4repsE = internal constant i64 100000000, align 8, !GlobalVarType !0
@"$const_string.0" = private unnamed_addr constant [4 x i8] c"add\00"
@"$const_string.2" = private unnamed_addr constant [3 x i8] c".3\00"
@"$const_string.3" = private unnamed_addr constant [7 x i8] c" ns/op\00"
@"$const_string.5" = private unnamed_addr constant [20 x i8] c"BenchmarkIfElseD4: \00"

declare void @CJ_MCC_ThrowException(i8 addrspace(1)*)
declare void @"_ZN11std$FS$core6String1+ER_ZN11std$FS$core6StringE"(%"record._ZN11std$FS$core6StringE"* noalias sret(%"record._ZN11std$FS$core6StringE"), i8 addrspace(1)*, %"record._ZN11std$FS$core6StringE" addrspace(1)*, i8 addrspace(1)*, %"record._ZN11std$FS$core6StringE" addrspace(1)*) gc "cangjie"
declare void @"_ZN11std$FS$core6String23createStringFromLiteralE"(%"record._ZN11std$FS$core6StringE"* noalias sret(%"record._ZN11std$FS$core6StringE"), i8*, i64) gc "cangjie"
declare void @"_ZN11std$FS$core7printlnER_ZN11std$FS$core6StringE"(%Unit.Type* noalias sret(%Unit.Type), i8 addrspace(1)*, %"record._ZN11std$FS$core6StringE" addrspace(1)*) gc "cangjie"
declare void @"_ZN11std$FS$time8DateTime1-ER_ZN11std$FS$time8DateTimeE"(%"record._ZN11std$FS$time8DurationE"* noalias sret(%"record._ZN11std$FS$time8DurationE"), i8 addrspace(1)*, %"record._ZN11std$FS$time8DateTimeE" addrspace(1)*, i8 addrspace(1)*, %"record._ZN11std$FS$time8DateTimeE" addrspace(1)*) gc "cangjie"
declare i8 addrspace(1)* @"_ZN11std$FS$time8DateTime3nowE$timeZone___0v"() gc "cangjie"
declare void @"_ZN11std$FS$time8DateTime3nowEC_ZN11std$FS$time8TimeZoneE"(%"record._ZN11std$FS$time8DateTimeE"* noalias sret(%"record._ZN11std$FS$time8DateTimeE"), i8 addrspace(1)*) gc "cangjie"
declare i64 @"_ZN11std$FS$time8Duration13toNanosecondsEv"(i8 addrspace(1)*, %"record._ZN11std$FS$time8DurationE" addrspace(1)*) gc "cangjie"
declare void @"_ZN13std$FS$format6Extend7Float646formatER_ZN11std$FS$core6StringE"(%"record._ZN11std$FS$core6StringE"* noalias sret(%"record._ZN11std$FS$core6StringE"), double, i8 addrspace(1)*, %"record._ZN11std$FS$core6StringE" addrspace(1)*) gc "cangjie"
declare void @llvm.cj.memset.p0i8(i8*, i8, i64, i1)
declare i1 @llvm.expect.i1(i1, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8* noalias nocapture writeonly, i8* noalias nocapture readonly, i64, i1 immarg)
declare { i64, i1 } @llvm.sadd.with.overflow.i64(i64, i64)
declare i8 addrspace(1)* @"rt$CreateOverflowException_msg"(i8 addrspace(1)*, %"record._ZN11std$FS$core6StringE" addrspace(1)*) gc "cangjie"

define internal void @_ZN7default17benchmarkIfElseD4Ev(%Unit.Type* noalias sret(%Unit.Type) %0) gc "cangjie" {
entry:
  %enumTmp = alloca %"record._ZN11std$FS$core6StringE"
  %callRet = alloca %"record._ZN11std$FS$core6StringE"
  %1 = alloca i64
  %val.ov = alloca { i64, i1 }
  %i = alloca i64
  %"$stop-compiler" = alloca i64
  %"$iter-i" = alloca i64
  %2 = bitcast %"record._ZN11std$FS$core6StringE"* %enumTmp to i8*
  call void @llvm.cj.memset.p0i8(i8* align 8 %2, i8 0, i64 16, i1 false)
  %3 = bitcast %"record._ZN11std$FS$core6StringE"* %callRet to i8*
  call void @llvm.cj.memset.p0i8(i8* align 8 %3, i8 0, i64 16, i1 false)
  br label %thunk782E

thunk782E:                                        ; preds = %entry
  store i64 0, i64* %"$iter-i"
  %4 = load i64, i64* @_ZN7default4repsE
  store i64 %4, i64* %"$stop-compiler"
  br label %block.body797E

block.body797E:                                   ; preds = %if.end1608E, %thunk782E
  %5 = load i64, i64* %"$iter-i"
  %6 = load i64, i64* %"$stop-compiler"
  %icmpslt = icmp slt i64 %5, %6
  br i1 %icmpslt, label %while.body1620E, label %block.end797E

while.body1620E:                                  ; preds = %block.body797E
  %7 = load i64, i64* %"$iter-i"
  store i64 %7, i64* %i
  %8 = load i64, i64* %"$iter-i"
  %9 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %8, i64 1)
  store { i64, i1 } %9, { i64, i1 }* %val.ov
  %10 = getelementptr inbounds { i64, i1 }, { i64, i1 }* %val.ov, i32 0, i32 1
  %11 = load i1, i1* %10
  %12 = call i1 @llvm.expect.i1(i1 %11, i1 false)
  br i1 %12, label %overflow0E, label %normal0E

normal0E:                                         ; preds = %while.body1620E
  %13 = getelementptr inbounds { i64, i1 }, { i64, i1 }* %val.ov, i32 0, i32 0
  %14 = load i64, i64* %13
  store i64 %14, i64* %1
  %15 = load i64, i64* %1
  store i64 %15, i64* %"$iter-i"
  %16 = load i64, i64* @_ZN7default1nE
  %icmpsgt = icmp sgt i64 %16, 16
  br i1 %icmpsgt, label %if.then1608E, label %if.else1608E

overflow0E:                                       ; preds = %while.body1620E
  call void @"_ZN11std$FS$core6String23createStringFromLiteralE"(%"record._ZN11std$FS$core6StringE"* noalias sret(%"record._ZN11std$FS$core6StringE") %callRet, i8* getelementptr inbounds ([4 x i8], [4 x i8]* @"$const_string.0", i32 0, i32 0), i64 3)
  %17 = addrspacecast %"record._ZN11std$FS$core6StringE"* %callRet to %"record._ZN11std$FS$core6StringE" addrspace(1)*
  %18 = call i8 addrspace(1)* @"rt$CreateOverflowException_msg"(i8 addrspace(1)* null, %"record._ZN11std$FS$core6StringE" addrspace(1)* %17)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %18)
  unreachable

if.then1608E:                                     ; preds = %normal0E
  %19 = load i64, i64* @_ZN7default1mE
  %icmpsgt1 = icmp sgt i64 %19, 16
  br i1 %icmpsgt1, label %if.then860E, label %if.else860E

if.then860E:                                      ; preds = %if.then1608E
  %20 = load i64, i64* @_ZN7default1lE
  %icmpsgt2 = icmp sgt i64 %20, 16
  br i1 %icmpsgt2, label %if.then851E, label %if.else851E

if.then851E:                                      ; preds = %if.then860E
  %21 = load i64, i64* @_ZN7default1kE
  %icmpsgt3 = icmp sgt i64 %21, 16
  br i1 %icmpsgt3, label %if.then842E, label %if.else842E

if.then842E:                                      ; preds = %if.then851E
  store i64 16, i64* @_ZN7default1nE
  br label %if.end842E

if.else842E:                                      ; preds = %if.then851E
  store i64 17, i64* @_ZN7default1nE
  br label %if.end842E

if.end842E:                                       ; preds = %if.else842E, %if.then842E
  br label %if.end851E

if.else851E:                                      ; preds = %if.then860E
  store i64 18, i64* @_ZN7default1nE
  br label %if.end851E

if.end851E:                                       ; preds = %if.else851E, %if.end842E
  br label %if.end860E

if.else860E:                                      ; preds = %if.then1608E
  store i64 19, i64* @_ZN7default1nE
  br label %if.end860E

if.end860E:                                       ; preds = %if.else860E, %if.end851E
  br label %if.end1608E

if.else1608E:                                     ; preds = %normal0E
  %22 = load i64, i64* @_ZN7default1nE
  %icmpsgt4 = icmp sgt i64 %22, 15
  br i1 %icmpsgt4, label %if.then1607E, label %if.else1607E

if.then1607E:                                     ; preds = %if.else1608E
  %23 = load i64, i64* @_ZN7default1mE
  %icmpsgt5 = icmp sgt i64 %23, 15
  br i1 %icmpsgt5, label %if.then909E, label %if.else909E

if.then909E:                                      ; preds = %if.then1607E
  %24 = load i64, i64* @_ZN7default1lE
  %icmpsgt6 = icmp sgt i64 %24, 15
  br i1 %icmpsgt6, label %if.then900E, label %if.else900E

if.then900E:                                      ; preds = %if.then909E
  %25 = load i64, i64* @_ZN7default1kE
  %icmpsgt7 = icmp sgt i64 %25, 15
  br i1 %icmpsgt7, label %if.then891E, label %if.else891E

if.then891E:                                      ; preds = %if.then900E
  store i64 15, i64* @_ZN7default1nE
  br label %if.end891E

if.else891E:                                      ; preds = %if.then900E
  store i64 16, i64* @_ZN7default1nE
  br label %if.end891E

if.end891E:                                       ; preds = %if.else891E, %if.then891E
  br label %if.end900E

if.else900E:                                      ; preds = %if.then909E
  store i64 17, i64* @_ZN7default1nE
  br label %if.end900E

if.end900E:                                       ; preds = %if.else900E, %if.end891E
  br label %if.end909E

if.else909E:                                      ; preds = %if.then1607E
  store i64 18, i64* @_ZN7default1nE
  br label %if.end909E

if.end909E:                                       ; preds = %if.else909E, %if.end900E
  br label %if.end1607E

if.else1607E:                                     ; preds = %if.else1608E
  %26 = load i64, i64* @_ZN7default1nE
  %icmpsgt8 = icmp sgt i64 %26, 14
  br i1 %icmpsgt8, label %if.then1606E, label %if.else1606E

if.then1606E:                                     ; preds = %if.else1607E
  %27 = load i64, i64* @_ZN7default1mE
  %icmpsgt9 = icmp sgt i64 %27, 14
  br i1 %icmpsgt9, label %if.then958E, label %if.else958E

if.then958E:                                      ; preds = %if.then1606E
  %28 = load i64, i64* @_ZN7default1lE
  %icmpsgt10 = icmp sgt i64 %28, 14
  br i1 %icmpsgt10, label %if.then949E, label %if.else949E

if.then949E:                                      ; preds = %if.then958E
  %29 = load i64, i64* @_ZN7default1kE
  %icmpsgt11 = icmp sgt i64 %29, 14
  br i1 %icmpsgt11, label %if.then940E, label %if.else940E

if.then940E:                                      ; preds = %if.then949E
  store i64 14, i64* @_ZN7default1nE
  br label %if.end940E

if.else940E:                                      ; preds = %if.then949E
  store i64 15, i64* @_ZN7default1nE
  br label %if.end940E

if.end940E:                                       ; preds = %if.else940E, %if.then940E
  br label %if.end949E

if.else949E:                                      ; preds = %if.then958E
  store i64 16, i64* @_ZN7default1nE
  br label %if.end949E

if.end949E:                                       ; preds = %if.else949E, %if.end940E
  br label %if.end958E

if.else958E:                                      ; preds = %if.then1606E
  store i64 17, i64* @_ZN7default1nE
  br label %if.end958E

if.end958E:                                       ; preds = %if.else958E, %if.end949E
  br label %if.end1606E

if.else1606E:                                     ; preds = %if.else1607E
  %30 = load i64, i64* @_ZN7default1nE
  %icmpsgt12 = icmp sgt i64 %30, 13
  br i1 %icmpsgt12, label %if.then1605E, label %if.else1605E

if.then1605E:                                     ; preds = %if.else1606E
  %31 = load i64, i64* @_ZN7default1mE
  %icmpsgt13 = icmp sgt i64 %31, 13
  br i1 %icmpsgt13, label %if.then1007E, label %if.else1007E

if.then1007E:                                     ; preds = %if.then1605E
  %32 = load i64, i64* @_ZN7default1lE
  %icmpsgt14 = icmp sgt i64 %32, 13
  br i1 %icmpsgt14, label %if.then998E, label %if.else998E

if.then998E:                                      ; preds = %if.then1007E
  %33 = load i64, i64* @_ZN7default1kE
  %icmpsgt15 = icmp sgt i64 %33, 13
  br i1 %icmpsgt15, label %if.then989E, label %if.else989E

if.then989E:                                      ; preds = %if.then998E
  store i64 13, i64* @_ZN7default1nE
  br label %if.end989E

if.else989E:                                      ; preds = %if.then998E
  store i64 14, i64* @_ZN7default1nE
  br label %if.end989E

if.end989E:                                       ; preds = %if.else989E, %if.then989E
  br label %if.end998E

if.else998E:                                      ; preds = %if.then1007E
  store i64 15, i64* @_ZN7default1nE
  br label %if.end998E

if.end998E:                                       ; preds = %if.else998E, %if.end989E
  br label %if.end1007E

if.else1007E:                                     ; preds = %if.then1605E
  store i64 16, i64* @_ZN7default1nE
  br label %if.end1007E

if.end1007E:                                      ; preds = %if.else1007E, %if.end998E
  br label %if.end1605E

if.else1605E:                                     ; preds = %if.else1606E
  %34 = load i64, i64* @_ZN7default1nE
  %icmpsgt16 = icmp sgt i64 %34, 12
  br i1 %icmpsgt16, label %if.then1604E, label %if.else1604E

if.then1604E:                                     ; preds = %if.else1605E
  %35 = load i64, i64* @_ZN7default1mE
  %icmpsgt17 = icmp sgt i64 %35, 12
  br i1 %icmpsgt17, label %if.then1056E, label %if.else1056E

if.then1056E:                                     ; preds = %if.then1604E
  %36 = load i64, i64* @_ZN7default1lE
  %icmpsgt18 = icmp sgt i64 %36, 12
  br i1 %icmpsgt18, label %if.then1047E, label %if.else1047E

if.then1047E:                                     ; preds = %if.then1056E
  %37 = load i64, i64* @_ZN7default1kE
  %icmpsgt19 = icmp sgt i64 %37, 12
  br i1 %icmpsgt19, label %if.then1038E, label %if.else1038E

if.then1038E:                                     ; preds = %if.then1047E
  store i64 12, i64* @_ZN7default1nE
  br label %if.end1038E

if.else1038E:                                     ; preds = %if.then1047E
  store i64 13, i64* @_ZN7default1nE
  br label %if.end1038E

if.end1038E:                                      ; preds = %if.else1038E, %if.then1038E
  br label %if.end1047E

if.else1047E:                                     ; preds = %if.then1056E
  store i64 14, i64* @_ZN7default1nE
  br label %if.end1047E

if.end1047E:                                      ; preds = %if.else1047E, %if.end1038E
  br label %if.end1056E

if.else1056E:                                     ; preds = %if.then1604E
  store i64 15, i64* @_ZN7default1nE
  br label %if.end1056E

if.end1056E:                                      ; preds = %if.else1056E, %if.end1047E
  br label %if.end1604E

if.else1604E:                                     ; preds = %if.else1605E
  %38 = load i64, i64* @_ZN7default1nE
  %icmpsgt20 = icmp sgt i64 %38, 11
  br i1 %icmpsgt20, label %if.then1603E, label %if.else1603E

if.then1603E:                                     ; preds = %if.else1604E
  %39 = load i64, i64* @_ZN7default1mE
  %icmpsgt21 = icmp sgt i64 %39, 11
  br i1 %icmpsgt21, label %if.then1105E, label %if.else1105E

if.then1105E:                                     ; preds = %if.then1603E
  %40 = load i64, i64* @_ZN7default1lE
  %icmpsgt22 = icmp sgt i64 %40, 11
  br i1 %icmpsgt22, label %if.then1096E, label %if.else1096E

if.then1096E:                                     ; preds = %if.then1105E
  %41 = load i64, i64* @_ZN7default1kE
  %icmpsgt23 = icmp sgt i64 %41, 11
  br i1 %icmpsgt23, label %if.then1087E, label %if.else1087E

if.then1087E:                                     ; preds = %if.then1096E
  store i64 11, i64* @_ZN7default1nE
  br label %if.end1087E

if.else1087E:                                     ; preds = %if.then1096E
  store i64 12, i64* @_ZN7default1nE
  br label %if.end1087E

if.end1087E:                                      ; preds = %if.else1087E, %if.then1087E
  br label %if.end1096E

if.else1096E:                                     ; preds = %if.then1105E
  store i64 13, i64* @_ZN7default1nE
  br label %if.end1096E

if.end1096E:                                      ; preds = %if.else1096E, %if.end1087E
  br label %if.end1105E

if.else1105E:                                     ; preds = %if.then1603E
  store i64 14, i64* @_ZN7default1nE
  br label %if.end1105E

if.end1105E:                                      ; preds = %if.else1105E, %if.end1096E
  br label %if.end1603E

if.else1603E:                                     ; preds = %if.else1604E
  %42 = load i64, i64* @_ZN7default1nE
  %icmpsgt24 = icmp sgt i64 %42, 10
  br i1 %icmpsgt24, label %if.then1602E, label %if.else1602E

if.then1602E:                                     ; preds = %if.else1603E
  %43 = load i64, i64* @_ZN7default1mE
  %icmpsgt25 = icmp sgt i64 %43, 10
  br i1 %icmpsgt25, label %if.then1154E, label %if.else1154E

if.then1154E:                                     ; preds = %if.then1602E
  %44 = load i64, i64* @_ZN7default1lE
  %icmpsgt26 = icmp sgt i64 %44, 10
  br i1 %icmpsgt26, label %if.then1145E, label %if.else1145E

if.then1145E:                                     ; preds = %if.then1154E
  %45 = load i64, i64* @_ZN7default1kE
  %icmpsgt27 = icmp sgt i64 %45, 10
  br i1 %icmpsgt27, label %if.then1136E, label %if.else1136E

if.then1136E:                                     ; preds = %if.then1145E
  store i64 10, i64* @_ZN7default1nE
  br label %if.end1136E

if.else1136E:                                     ; preds = %if.then1145E
  store i64 11, i64* @_ZN7default1nE
  br label %if.end1136E

if.end1136E:                                      ; preds = %if.else1136E, %if.then1136E
  br label %if.end1145E

if.else1145E:                                     ; preds = %if.then1154E
  store i64 12, i64* @_ZN7default1nE
  br label %if.end1145E

if.end1145E:                                      ; preds = %if.else1145E, %if.end1136E
  br label %if.end1154E

if.else1154E:                                     ; preds = %if.then1602E
  store i64 13, i64* @_ZN7default1nE
  br label %if.end1154E

if.end1154E:                                      ; preds = %if.else1154E, %if.end1145E
  br label %if.end1602E

if.else1602E:                                     ; preds = %if.else1603E
  %46 = load i64, i64* @_ZN7default1nE
  %icmpsgt28 = icmp sgt i64 %46, 9
  br i1 %icmpsgt28, label %if.then1601E, label %if.else1601E

if.then1601E:                                     ; preds = %if.else1602E
  %47 = load i64, i64* @_ZN7default1mE
  %icmpsgt29 = icmp sgt i64 %47, 9
  br i1 %icmpsgt29, label %if.then1203E, label %if.else1203E

if.then1203E:                                     ; preds = %if.then1601E
  %48 = load i64, i64* @_ZN7default1lE
  %icmpsgt30 = icmp sgt i64 %48, 9
  br i1 %icmpsgt30, label %if.then1194E, label %if.else1194E

if.then1194E:                                     ; preds = %if.then1203E
  %49 = load i64, i64* @_ZN7default1kE
  %icmpsgt31 = icmp sgt i64 %49, 9
  br i1 %icmpsgt31, label %if.then1185E, label %if.else1185E

if.then1185E:                                     ; preds = %if.then1194E
  store i64 9, i64* @_ZN7default1nE
  br label %if.end1185E

if.else1185E:                                     ; preds = %if.then1194E
  store i64 10, i64* @_ZN7default1nE
  br label %if.end1185E

if.end1185E:                                      ; preds = %if.else1185E, %if.then1185E
  br label %if.end1194E

if.else1194E:                                     ; preds = %if.then1203E
  store i64 11, i64* @_ZN7default1nE
  br label %if.end1194E

if.end1194E:                                      ; preds = %if.else1194E, %if.end1185E
  br label %if.end1203E

if.else1203E:                                     ; preds = %if.then1601E
  store i64 12, i64* @_ZN7default1nE
  br label %if.end1203E

if.end1203E:                                      ; preds = %if.else1203E, %if.end1194E
  br label %if.end1601E

if.else1601E:                                     ; preds = %if.else1602E
  %50 = load i64, i64* @_ZN7default1nE
  %icmpsgt32 = icmp sgt i64 %50, 8
  br i1 %icmpsgt32, label %if.then1600E, label %if.else1600E

if.then1600E:                                     ; preds = %if.else1601E
  %51 = load i64, i64* @_ZN7default1mE
  %icmpsgt33 = icmp sgt i64 %51, 8
  br i1 %icmpsgt33, label %if.then1252E, label %if.else1252E

if.then1252E:                                     ; preds = %if.then1600E
  %52 = load i64, i64* @_ZN7default1lE
  %icmpsgt34 = icmp sgt i64 %52, 8
  br i1 %icmpsgt34, label %if.then1243E, label %if.else1243E

if.then1243E:                                     ; preds = %if.then1252E
  %53 = load i64, i64* @_ZN7default1kE
  %icmpsgt35 = icmp sgt i64 %53, 8
  br i1 %icmpsgt35, label %if.then1234E, label %if.else1234E

if.then1234E:                                     ; preds = %if.then1243E
  store i64 8, i64* @_ZN7default1nE
  br label %if.end1234E

if.else1234E:                                     ; preds = %if.then1243E
  store i64 9, i64* @_ZN7default1nE
  br label %if.end1234E

if.end1234E:                                      ; preds = %if.else1234E, %if.then1234E
  br label %if.end1243E

if.else1243E:                                     ; preds = %if.then1252E
  store i64 10, i64* @_ZN7default1nE
  br label %if.end1243E

if.end1243E:                                      ; preds = %if.else1243E, %if.end1234E
  br label %if.end1252E

if.else1252E:                                     ; preds = %if.then1600E
  store i64 11, i64* @_ZN7default1nE
  br label %if.end1252E

if.end1252E:                                      ; preds = %if.else1252E, %if.end1243E
  br label %if.end1600E

if.else1600E:                                     ; preds = %if.else1601E
  %54 = load i64, i64* @_ZN7default1nE
  %icmpsgt36 = icmp sgt i64 %54, 7
  br i1 %icmpsgt36, label %if.then1599E, label %if.else1599E

if.then1599E:                                     ; preds = %if.else1600E
  %55 = load i64, i64* @_ZN7default1mE
  %icmpsgt37 = icmp sgt i64 %55, 7
  br i1 %icmpsgt37, label %if.then1301E, label %if.else1301E

if.then1301E:                                     ; preds = %if.then1599E
  %56 = load i64, i64* @_ZN7default1lE
  %icmpsgt38 = icmp sgt i64 %56, 7
  br i1 %icmpsgt38, label %if.then1292E, label %if.else1292E

if.then1292E:                                     ; preds = %if.then1301E
  %57 = load i64, i64* @_ZN7default1kE
  %icmpsgt39 = icmp sgt i64 %57, 7
  br i1 %icmpsgt39, label %if.then1283E, label %if.else1283E

if.then1283E:                                     ; preds = %if.then1292E
  store i64 7, i64* @_ZN7default1nE
  br label %if.end1283E

if.else1283E:                                     ; preds = %if.then1292E
  store i64 8, i64* @_ZN7default1nE
  br label %if.end1283E

if.end1283E:                                      ; preds = %if.else1283E, %if.then1283E
  br label %if.end1292E

if.else1292E:                                     ; preds = %if.then1301E
  store i64 9, i64* @_ZN7default1nE
  br label %if.end1292E

if.end1292E:                                      ; preds = %if.else1292E, %if.end1283E
  br label %if.end1301E

if.else1301E:                                     ; preds = %if.then1599E
  store i64 10, i64* @_ZN7default1nE
  br label %if.end1301E

if.end1301E:                                      ; preds = %if.else1301E, %if.end1292E
  br label %if.end1599E

if.else1599E:                                     ; preds = %if.else1600E
  %58 = load i64, i64* @_ZN7default1nE
  %icmpsgt40 = icmp sgt i64 %58, 6
  br i1 %icmpsgt40, label %if.then1598E, label %if.else1598E

if.then1598E:                                     ; preds = %if.else1599E
  %59 = load i64, i64* @_ZN7default1mE
  %icmpsgt41 = icmp sgt i64 %59, 6
  br i1 %icmpsgt41, label %if.then1350E, label %if.else1350E

if.then1350E:                                     ; preds = %if.then1598E
  %60 = load i64, i64* @_ZN7default1lE
  %icmpsgt42 = icmp sgt i64 %60, 6
  br i1 %icmpsgt42, label %if.then1341E, label %if.else1341E

if.then1341E:                                     ; preds = %if.then1350E
  %61 = load i64, i64* @_ZN7default1kE
  %icmpsgt43 = icmp sgt i64 %61, 6
  br i1 %icmpsgt43, label %if.then1332E, label %if.else1332E

if.then1332E:                                     ; preds = %if.then1341E
  store i64 6, i64* @_ZN7default1nE
  br label %if.end1332E

if.else1332E:                                     ; preds = %if.then1341E
  store i64 7, i64* @_ZN7default1nE
  br label %if.end1332E

if.end1332E:                                      ; preds = %if.else1332E, %if.then1332E
  br label %if.end1341E

if.else1341E:                                     ; preds = %if.then1350E
  store i64 8, i64* @_ZN7default1nE
  br label %if.end1341E

if.end1341E:                                      ; preds = %if.else1341E, %if.end1332E
  br label %if.end1350E

if.else1350E:                                     ; preds = %if.then1598E
  store i64 9, i64* @_ZN7default1nE
  br label %if.end1350E

if.end1350E:                                      ; preds = %if.else1350E, %if.end1341E
  br label %if.end1598E

if.else1598E:                                     ; preds = %if.else1599E
  %62 = load i64, i64* @_ZN7default1nE
  %icmpsgt44 = icmp sgt i64 %62, 5
  br i1 %icmpsgt44, label %if.then1597E, label %if.else1597E

if.then1597E:                                     ; preds = %if.else1598E
  %63 = load i64, i64* @_ZN7default1mE
  %icmpsgt45 = icmp sgt i64 %63, 5
  br i1 %icmpsgt45, label %if.then1399E, label %if.else1399E

if.then1399E:                                     ; preds = %if.then1597E
  %64 = load i64, i64* @_ZN7default1lE
  %icmpsgt46 = icmp sgt i64 %64, 5
  br i1 %icmpsgt46, label %if.then1390E, label %if.else1390E

if.then1390E:                                     ; preds = %if.then1399E
  %65 = load i64, i64* @_ZN7default1kE
  %icmpsgt47 = icmp sgt i64 %65, 5
  br i1 %icmpsgt47, label %if.then1381E, label %if.else1381E

if.then1381E:                                     ; preds = %if.then1390E
  store i64 5, i64* @_ZN7default1nE
  br label %if.end1381E

if.else1381E:                                     ; preds = %if.then1390E
  store i64 6, i64* @_ZN7default1nE
  br label %if.end1381E

if.end1381E:                                      ; preds = %if.else1381E, %if.then1381E
  br label %if.end1390E

if.else1390E:                                     ; preds = %if.then1399E
  store i64 7, i64* @_ZN7default1nE
  br label %if.end1390E

if.end1390E:                                      ; preds = %if.else1390E, %if.end1381E
  br label %if.end1399E

if.else1399E:                                     ; preds = %if.then1597E
  store i64 8, i64* @_ZN7default1nE
  br label %if.end1399E

if.end1399E:                                      ; preds = %if.else1399E, %if.end1390E
  br label %if.end1597E

if.else1597E:                                     ; preds = %if.else1598E
  %66 = load i64, i64* @_ZN7default1nE
  %icmpsgt48 = icmp sgt i64 %66, 4
  br i1 %icmpsgt48, label %if.then1596E, label %if.else1596E

if.then1596E:                                     ; preds = %if.else1597E
  %67 = load i64, i64* @_ZN7default1mE
  %icmpsgt49 = icmp sgt i64 %67, 4
  br i1 %icmpsgt49, label %if.then1448E, label %if.else1448E

if.then1448E:                                     ; preds = %if.then1596E
  %68 = load i64, i64* @_ZN7default1lE
  %icmpsgt50 = icmp sgt i64 %68, 4
  br i1 %icmpsgt50, label %if.then1439E, label %if.else1439E

if.then1439E:                                     ; preds = %if.then1448E
  %69 = load i64, i64* @_ZN7default1kE
  %icmpsgt51 = icmp sgt i64 %69, 4
  br i1 %icmpsgt51, label %if.then1430E, label %if.else1430E

if.then1430E:                                     ; preds = %if.then1439E
  store i64 4, i64* @_ZN7default1nE
  br label %if.end1430E

if.else1430E:                                     ; preds = %if.then1439E
  store i64 5, i64* @_ZN7default1nE
  br label %if.end1430E

if.end1430E:                                      ; preds = %if.else1430E, %if.then1430E
  br label %if.end1439E

if.else1439E:                                     ; preds = %if.then1448E
  store i64 6, i64* @_ZN7default1nE
  br label %if.end1439E

if.end1439E:                                      ; preds = %if.else1439E, %if.end1430E
  br label %if.end1448E

if.else1448E:                                     ; preds = %if.then1596E
  store i64 7, i64* @_ZN7default1nE
  br label %if.end1448E

if.end1448E:                                      ; preds = %if.else1448E, %if.end1439E
  br label %if.end1596E

if.else1596E:                                     ; preds = %if.else1597E
  %70 = load i64, i64* @_ZN7default1nE
  %icmpsgt52 = icmp sgt i64 %70, 3
  br i1 %icmpsgt52, label %if.then1595E, label %if.else1595E

if.then1595E:                                     ; preds = %if.else1596E
  %71 = load i64, i64* @_ZN7default1mE
  %icmpsgt53 = icmp sgt i64 %71, 3
  br i1 %icmpsgt53, label %if.then1497E, label %if.else1497E

if.then1497E:                                     ; preds = %if.then1595E
  %72 = load i64, i64* @_ZN7default1lE
  %icmpsgt54 = icmp sgt i64 %72, 3
  br i1 %icmpsgt54, label %if.then1488E, label %if.else1488E

if.then1488E:                                     ; preds = %if.then1497E
  %73 = load i64, i64* @_ZN7default1kE
  %icmpsgt55 = icmp sgt i64 %73, 3
  br i1 %icmpsgt55, label %if.then1479E, label %if.else1479E

if.then1479E:                                     ; preds = %if.then1488E
  store i64 3, i64* @_ZN7default1nE
  br label %if.end1479E

if.else1479E:                                     ; preds = %if.then1488E
  store i64 4, i64* @_ZN7default1nE
  br label %if.end1479E

if.end1479E:                                      ; preds = %if.else1479E, %if.then1479E
  br label %if.end1488E

if.else1488E:                                     ; preds = %if.then1497E
  store i64 5, i64* @_ZN7default1nE
  br label %if.end1488E

if.end1488E:                                      ; preds = %if.else1488E, %if.end1479E
  br label %if.end1497E

if.else1497E:                                     ; preds = %if.then1595E
  store i64 6, i64* @_ZN7default1nE
  br label %if.end1497E

if.end1497E:                                      ; preds = %if.else1497E, %if.end1488E
  br label %if.end1595E

if.else1595E:                                     ; preds = %if.else1596E
  %74 = load i64, i64* @_ZN7default1nE
  %icmpsgt56 = icmp sgt i64 %74, 2
  br i1 %icmpsgt56, label %if.then1594E, label %if.else1594E

if.then1594E:                                     ; preds = %if.else1595E
  %75 = load i64, i64* @_ZN7default1mE
  %icmpsgt57 = icmp sgt i64 %75, 2
  br i1 %icmpsgt57, label %if.then1546E, label %if.else1546E

if.then1546E:                                     ; preds = %if.then1594E
  %76 = load i64, i64* @_ZN7default1lE
  %icmpsgt58 = icmp sgt i64 %76, 2
  br i1 %icmpsgt58, label %if.then1537E, label %if.else1537E

if.then1537E:                                     ; preds = %if.then1546E
  %77 = load i64, i64* @_ZN7default1kE
  %icmpsgt59 = icmp sgt i64 %77, 2
  br i1 %icmpsgt59, label %if.then1528E, label %if.else1528E

if.then1528E:                                     ; preds = %if.then1537E
  store i64 2, i64* @_ZN7default1nE
  br label %if.end1528E

if.else1528E:                                     ; preds = %if.then1537E
  store i64 3, i64* @_ZN7default1nE
  br label %if.end1528E

if.end1528E:                                      ; preds = %if.else1528E, %if.then1528E
  br label %if.end1537E

if.else1537E:                                     ; preds = %if.then1546E
  store i64 4, i64* @_ZN7default1nE
  br label %if.end1537E

if.end1537E:                                      ; preds = %if.else1537E, %if.end1528E
  br label %if.end1546E

if.else1546E:                                     ; preds = %if.then1594E
  store i64 5, i64* @_ZN7default1nE
  br label %if.end1546E

if.end1546E:                                      ; preds = %if.else1546E, %if.end1537E
  br label %if.end1594E

if.else1594E:                                     ; preds = %if.else1595E
  %78 = load i64, i64* @_ZN7default1mE
  %icmpsgt60 = icmp sgt i64 %78, 1
  br i1 %icmpsgt60, label %if.then1591E, label %if.else1591E

if.then1591E:                                     ; preds = %if.else1594E
  %79 = load i64, i64* @_ZN7default1lE
  %icmpsgt61 = icmp sgt i64 %79, 1
  br i1 %icmpsgt61, label %if.then1582E, label %if.else1582E

if.then1582E:                                     ; preds = %if.then1591E
  %80 = load i64, i64* @_ZN7default1kE
  %icmpsgt62 = icmp sgt i64 %80, 1
  br i1 %icmpsgt62, label %if.then1573E, label %if.else1573E

if.then1573E:                                     ; preds = %if.then1582E
  store i64 1, i64* @_ZN7default1nE
  br label %if.end1573E

if.else1573E:                                     ; preds = %if.then1582E
  store i64 2, i64* @_ZN7default1nE
  br label %if.end1573E

if.end1573E:                                      ; preds = %if.else1573E, %if.then1573E
  br label %if.end1582E

if.else1582E:                                     ; preds = %if.then1591E
  store i64 3, i64* @_ZN7default1nE
  br label %if.end1582E

if.end1582E:                                      ; preds = %if.else1582E, %if.end1573E
  br label %if.end1591E

if.else1591E:                                     ; preds = %if.else1594E
  store i64 4, i64* @_ZN7default1nE
  br label %if.end1591E

if.end1591E:                                      ; preds = %if.else1591E, %if.end1582E
  br label %if.end1594E

if.end1594E:                                      ; preds = %if.end1591E, %if.end1546E
  br label %if.end1595E

if.end1595E:                                      ; preds = %if.end1594E, %if.end1497E
  br label %if.end1596E

if.end1596E:                                      ; preds = %if.end1595E, %if.end1448E
  br label %if.end1597E

if.end1597E:                                      ; preds = %if.end1596E, %if.end1399E
  br label %if.end1598E

if.end1598E:                                      ; preds = %if.end1597E, %if.end1350E
  br label %if.end1599E

if.end1599E:                                      ; preds = %if.end1598E, %if.end1301E
  br label %if.end1600E

if.end1600E:                                      ; preds = %if.end1599E, %if.end1252E
  br label %if.end1601E

if.end1601E:                                      ; preds = %if.end1600E, %if.end1203E
  br label %if.end1602E

if.end1602E:                                      ; preds = %if.end1601E, %if.end1154E
  br label %if.end1603E

if.end1603E:                                      ; preds = %if.end1602E, %if.end1105E
  br label %if.end1604E

if.end1604E:                                      ; preds = %if.end1603E, %if.end1056E
  br label %if.end1605E

if.end1605E:                                      ; preds = %if.end1604E, %if.end1007E
  br label %if.end1606E

if.end1606E:                                      ; preds = %if.end1605E, %if.end958E
  br label %if.end1607E

if.end1607E:                                      ; preds = %if.end1606E, %if.end909E
  br label %if.end1608E

if.end1608E:                                      ; preds = %if.end1607E, %if.end860E
  br label %block.body797E

block.end797E:                                    ; preds = %block.body797E
  ret void
}

define internal void @_ZN7default21timeBenchmarkIfElseD4Ev(%Unit.Type* noalias sret(%Unit.Type) %0) gc "cangjie" {
entry:
  %callRet17 = alloca %Unit.Type
  %enumTmp18 = alloca %"record._ZN11std$FS$core6StringE"
  %enumTmp16 = alloca %"record._ZN11std$FS$core6StringE"
  %enumTmp15 = alloca %"record._ZN11std$FS$core6StringE"
  %callRet14 = alloca %"record._ZN11std$FS$core6StringE"
  %callRet13 = alloca %"record._ZN11std$FS$core6StringE"
  %enumTmp12 = alloca %"record._ZN11std$FS$core6StringE"
  %enumTmp11 = alloca %"record._ZN11std$FS$core6StringE"
  %callRet10 = alloca %"record._ZN11std$FS$core6StringE"
  %enumTmp9 = alloca %"record._ZN11std$FS$core6StringE"
  %callRet8 = alloca %"record._ZN11std$FS$core6StringE"
  %callRet7 = alloca %"record._ZN11std$FS$core6StringE"
  %callRet6 = alloca %"record._ZN11std$FS$core6StringE"
  %perTime = alloca double
  %enumTmp4 = alloca %"record._ZN11std$FS$time8DateTimeE"
  %enumTmp = alloca %"record._ZN11std$FS$time8DateTimeE"
  %callRet3 = alloca %"record._ZN11std$FS$time8DurationE"
  %endTime = alloca %"record._ZN11std$FS$time8DateTimeE"
  %callRet2 = alloca %"record._ZN11std$FS$time8DateTimeE"
  %startTime = alloca %"record._ZN11std$FS$time8DateTimeE"
  %callRet = alloca %"record._ZN11std$FS$time8DateTimeE"
  %1 = bitcast %"record._ZN11std$FS$core6StringE"* %enumTmp18 to i8*
  call void @llvm.cj.memset.p0i8(i8* align 8 %1, i8 0, i64 16, i1 false)
  %2 = bitcast %"record._ZN11std$FS$core6StringE"* %enumTmp16 to i8*
  call void @llvm.cj.memset.p0i8(i8* align 8 %2, i8 0, i64 16, i1 false)
  %3 = bitcast %"record._ZN11std$FS$core6StringE"* %enumTmp15 to i8*
  call void @llvm.cj.memset.p0i8(i8* align 8 %3, i8 0, i64 16, i1 false)
  %4 = bitcast %"record._ZN11std$FS$core6StringE"* %callRet14 to i8*
  call void @llvm.cj.memset.p0i8(i8* align 8 %4, i8 0, i64 16, i1 false)
  %5 = bitcast %"record._ZN11std$FS$core6StringE"* %callRet13 to i8*
  call void @llvm.cj.memset.p0i8(i8* align 8 %5, i8 0, i64 16, i1 false)
  %6 = bitcast %"record._ZN11std$FS$core6StringE"* %enumTmp12 to i8*
  call void @llvm.cj.memset.p0i8(i8* align 8 %6, i8 0, i64 16, i1 false)
  %7 = bitcast %"record._ZN11std$FS$core6StringE"* %enumTmp11 to i8*
  call void @llvm.cj.memset.p0i8(i8* align 8 %7, i8 0, i64 16, i1 false)
  %8 = bitcast %"record._ZN11std$FS$core6StringE"* %callRet10 to i8*
  call void @llvm.cj.memset.p0i8(i8* align 8 %8, i8 0, i64 16, i1 false)
  %9 = bitcast %"record._ZN11std$FS$core6StringE"* %enumTmp9 to i8*
  call void @llvm.cj.memset.p0i8(i8* align 8 %9, i8 0, i64 16, i1 false)
  %10 = bitcast %"record._ZN11std$FS$core6StringE"* %callRet8 to i8*
  call void @llvm.cj.memset.p0i8(i8* align 8 %10, i8 0, i64 16, i1 false)
  %11 = bitcast %"record._ZN11std$FS$core6StringE"* %callRet7 to i8*
  call void @llvm.cj.memset.p0i8(i8* align 8 %11, i8 0, i64 16, i1 false)
  %12 = bitcast %"record._ZN11std$FS$core6StringE"* %callRet6 to i8*
  call void @llvm.cj.memset.p0i8(i8* align 8 %12, i8 0, i64 16, i1 false)
  %13 = bitcast %"record._ZN11std$FS$time8DateTimeE"* %enumTmp4 to i8*
  call void @llvm.cj.memset.p0i8(i8* align 8 %13, i8 0, i64 40, i1 false)
  %14 = bitcast %"record._ZN11std$FS$time8DateTimeE"* %enumTmp to i8*
  call void @llvm.cj.memset.p0i8(i8* align 8 %14, i8 0, i64 40, i1 false)
  %15 = bitcast %"record._ZN11std$FS$time8DateTimeE"* %endTime to i8*
  call void @llvm.cj.memset.p0i8(i8* align 8 %15, i8 0, i64 40, i1 false)
  %16 = bitcast %"record._ZN11std$FS$time8DateTimeE"* %callRet2 to i8*
  call void @llvm.cj.memset.p0i8(i8* align 8 %16, i8 0, i64 40, i1 false)
  %17 = bitcast %"record._ZN11std$FS$time8DateTimeE"* %startTime to i8*
  call void @llvm.cj.memset.p0i8(i8* align 8 %17, i8 0, i64 40, i1 false)
  %18 = bitcast %"record._ZN11std$FS$time8DateTimeE"* %callRet to i8*
  call void @llvm.cj.memset.p0i8(i8* align 8 %18, i8 0, i64 40, i1 false)
  br label %thunk1624E

thunk1624E:                                       ; preds = %entry
  %19 = call i8 addrspace(1)* @"_ZN11std$FS$time8DateTime3nowE$timeZone___0v"()
  call void @"_ZN11std$FS$time8DateTime3nowEC_ZN11std$FS$time8TimeZoneE"(%"record._ZN11std$FS$time8DateTimeE"* noalias sret(%"record._ZN11std$FS$time8DateTimeE") %callRet, i8 addrspace(1)* %19)
  %20 = bitcast %"record._ZN11std$FS$time8DateTimeE"* %startTime to i8*
  %21 = bitcast %"record._ZN11std$FS$time8DateTimeE"* %callRet to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* align 8 %20, i8* align 8 %21, i64 40, i1 false)
  call void @_ZN7default17benchmarkIfElseD4Ev(%Unit.Type* noalias sret(%Unit.Type) %callRet17)
  %22 = call i8 addrspace(1)* @"_ZN11std$FS$time8DateTime3nowE$timeZone___0v"()
  call void @"_ZN11std$FS$time8DateTime3nowEC_ZN11std$FS$time8TimeZoneE"(%"record._ZN11std$FS$time8DateTimeE"* noalias sret(%"record._ZN11std$FS$time8DateTimeE") %callRet2, i8 addrspace(1)* %22)
  %23 = bitcast %"record._ZN11std$FS$time8DateTimeE"* %endTime to i8*
  %24 = bitcast %"record._ZN11std$FS$time8DateTimeE"* %callRet2 to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* align 8 %23, i8* align 8 %24, i64 40, i1 false)
  %25 = addrspacecast %"record._ZN11std$FS$time8DateTimeE"* %endTime to %"record._ZN11std$FS$time8DateTimeE" addrspace(1)*
  %26 = addrspacecast %"record._ZN11std$FS$time8DateTimeE"* %startTime to %"record._ZN11std$FS$time8DateTimeE" addrspace(1)*
  call void @"_ZN11std$FS$time8DateTime1-ER_ZN11std$FS$time8DateTimeE"(%"record._ZN11std$FS$time8DurationE"* noalias sret(%"record._ZN11std$FS$time8DurationE") %callRet3, i8 addrspace(1)* null, %"record._ZN11std$FS$time8DateTimeE" addrspace(1)* %25, i8 addrspace(1)* null, %"record._ZN11std$FS$time8DateTimeE" addrspace(1)* %26)
  %27 = addrspacecast %"record._ZN11std$FS$time8DurationE"* %callRet3 to %"record._ZN11std$FS$time8DurationE" addrspace(1)*
  %28 = call i64 @"_ZN11std$FS$time8Duration13toNanosecondsEv"(i8 addrspace(1)* null, %"record._ZN11std$FS$time8DurationE" addrspace(1)* %27)
  %29 = sitofp i64 %28 to double
  %30 = load i64, i64* @_ZN7default4repsE
  %31 = sitofp i64 %30 to double
  %div = fdiv double %29, %31
  store double %div, double* %perTime
  call void @"_ZN11std$FS$core6String23createStringFromLiteralE"(%"record._ZN11std$FS$core6StringE"* noalias sret(%"record._ZN11std$FS$core6StringE") %callRet6, i8* getelementptr inbounds ([20 x i8], [20 x i8]* @"$const_string.5", i32 0, i32 0), i64 19)
  %32 = load double, double* %perTime
  call void @"_ZN11std$FS$core6String23createStringFromLiteralE"(%"record._ZN11std$FS$core6StringE"* noalias sret(%"record._ZN11std$FS$core6StringE") %callRet7, i8* getelementptr inbounds ([3 x i8], [3 x i8]* @"$const_string.2", i32 0, i32 0), i64 2)
  %33 = addrspacecast %"record._ZN11std$FS$core6StringE"* %callRet7 to %"record._ZN11std$FS$core6StringE" addrspace(1)*
  call void @"_ZN13std$FS$format6Extend7Float646formatER_ZN11std$FS$core6StringE"(%"record._ZN11std$FS$core6StringE"* noalias sret(%"record._ZN11std$FS$core6StringE") %callRet8, double %32, i8 addrspace(1)* null, %"record._ZN11std$FS$core6StringE" addrspace(1)* %33)
  %34 = addrspacecast %"record._ZN11std$FS$core6StringE"* %callRet6 to %"record._ZN11std$FS$core6StringE" addrspace(1)*
  %35 = addrspacecast %"record._ZN11std$FS$core6StringE"* %callRet8 to %"record._ZN11std$FS$core6StringE" addrspace(1)*
  call void @"_ZN11std$FS$core6String1+ER_ZN11std$FS$core6StringE"(%"record._ZN11std$FS$core6StringE"* noalias sret(%"record._ZN11std$FS$core6StringE") %callRet10, i8 addrspace(1)* null, %"record._ZN11std$FS$core6StringE" addrspace(1)* %34, i8 addrspace(1)* null, %"record._ZN11std$FS$core6StringE" addrspace(1)* %35)
  call void @"_ZN11std$FS$core6String23createStringFromLiteralE"(%"record._ZN11std$FS$core6StringE"* noalias sret(%"record._ZN11std$FS$core6StringE") %callRet13, i8* getelementptr inbounds ([7 x i8], [7 x i8]* @"$const_string.3", i32 0, i32 0), i64 6)
  %36 = addrspacecast %"record._ZN11std$FS$core6StringE"* %callRet10 to %"record._ZN11std$FS$core6StringE" addrspace(1)*
  %37 = addrspacecast %"record._ZN11std$FS$core6StringE"* %callRet13 to %"record._ZN11std$FS$core6StringE" addrspace(1)*
  call void @"_ZN11std$FS$core6String1+ER_ZN11std$FS$core6StringE"(%"record._ZN11std$FS$core6StringE"* noalias sret(%"record._ZN11std$FS$core6StringE") %callRet14, i8 addrspace(1)* null, %"record._ZN11std$FS$core6StringE" addrspace(1)* %36, i8 addrspace(1)* null, %"record._ZN11std$FS$core6StringE" addrspace(1)* %37)
  %38 = addrspacecast %"record._ZN11std$FS$core6StringE"* %callRet14 to %"record._ZN11std$FS$core6StringE" addrspace(1)*
  call void @"_ZN11std$FS$core7printlnER_ZN11std$FS$core6StringE"(%Unit.Type* noalias sret(%Unit.Type) %callRet17, i8 addrspace(1)* null, %"record._ZN11std$FS$core6StringE" addrspace(1)* %38)
  ret void
}

define i64 @_ZN7default4mainEv() gc "cangjie" {
entry:
  %callRet2 = alloca %Unit.Type
  br label %thunk1670E

thunk1670E:                                       ; preds = %entry
  call void @_ZN7default21timeBenchmarkIfElseD4Ev(%Unit.Type* noalias sret(%Unit.Type) %callRet2)
  ret i64 0
}

define i64 @user.main() gc "cangjie" {
entry:
  %retVal = alloca i64
  br label %thunk1685E

thunk1685E:                                       ; preds = %entry
  %0 = call i64 @_ZN7default4mainEv()
  store i64 %0, i64* %retVal
  %1 = load i64, i64* %retVal
  ret i64 %1
}

!llvm.module.flags = !{!1}

!0 = !{!"l"}
!1 = !{i32 2, !"CJBC", i32 1}
