# from
# https://raw.githubusercontent.com/approvals/ApprovalTests.cpp/master/CMake/WarningsAsErrors.cmake
# and
# https://releases.llvm.org/11.0.0/tools/clang/docs/DiagnosticsReference.html#id604
#
# modified to use it global, but optional by CK
option(WarningsAsErrors "To be really pedantic!" YES)
if(WarningsAsErrors)
  if(CMAKE_CXX_COMPILER_ID MATCHES "Clang" AND CMAKE_CXX_SIMULATE_ID MATCHES "MSVC")
    add_compile_options(/W4 /WX)
  elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    add_compile_options(
      -Wall
      -Wextra
      -Werror
      -Wno-long-long
      -Wno-unknown-pragmas
    )

    if(CMAKE_CXX_COMPILER_ID STREQUAL "Clang" AND CMAKE_CXX_COMPILER_VERSION GREATER_EQUAL 10.0)
      add_compile_options(
        -Wdeprecated
        -Wpointer-arith
        -Wnewline-eof
        -Wshadow
        -Wno-c++11-long-long
      )
    endif()
  elseif(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
    string(REGEX REPLACE " /W[0-4]" "" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
    add_compile_options(/W4 /WX /std:c++latest)
  endif()
endif()
