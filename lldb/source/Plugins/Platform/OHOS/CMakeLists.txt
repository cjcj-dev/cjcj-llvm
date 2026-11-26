add_lldb_library(lldbPluginPlatformOHOS PLUGIN
  PlatformOHOS.cpp
  HdcClient.cpp
  PlatformOHOSRemoteGDBServer.cpp

  LINK_LIBS
    lldbCore
    lldbHost
    lldbPluginPlatformLinux
    lldbPluginPlatformGDB
    boundscheck
  LINK_COMPONENTS
    Support
  )

target_include_directories(lldbPluginPlatformOHOS PRIVATE ${CMAKE_SOURCE_DIR}/../utils/boundscheck/include)
string(REPLACE "AMD64" "x86_64" ARCH_NAME "${CMAKE_SYSTEM_PROCESSOR}")
string(REPLACE "arm64" "aarch64" ARCH_NAME "${ARCH_NAME}")
target_link_directories(lldbPluginPlatformOHOS PUBLIC ${CMAKE_SOURCE_DIR}/../utils/boundscheck/lib/${ARCH_NAME})
