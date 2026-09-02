set(LLVM_LINK_COMPONENTS
  Core
  IRReader
  ScalarOpts
  Support
  )

add_llvm_tool(cjir-capture
  cjir-capture.cpp
  )
