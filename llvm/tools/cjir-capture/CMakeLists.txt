set(LLVM_LINK_COMPONENTS
  Core
  IRReader
  ScalarOpts
  Support
  )

add_llvm_tool(cjir-capture
  cjir-capture.cpp
  )

# Capture releases are self-contained: the executable and its product LLVM
# library live in sibling bin/ and lib/ directories.  Keep the normal build
# free of absolute or external library search paths when copied into a
# release directory.
set_target_properties(cjir-capture PROPERTIES
  BUILD_RPATH "\$ORIGIN/../lib"
  INSTALL_RPATH "\$ORIGIN/../lib"
  )
