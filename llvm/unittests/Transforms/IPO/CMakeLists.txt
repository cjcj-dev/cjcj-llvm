set(LLVM_LINK_COMPONENTS
  Analysis
  AsmParser
  Core
  IPO
  Passes
  Support
  TransformUtils
  )

add_llvm_unittest(IPOTests
  LowerTypeTests.cpp
  WholeProgramDevirt.cpp
  AttributorTest.cpp
  CJPartialEscapeAnalysisTest.cpp
  )

set_property(TARGET IPOTests PROPERTY FOLDER "Tests/UnitTests/TransformsTests")
