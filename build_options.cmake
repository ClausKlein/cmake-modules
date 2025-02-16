# ===========================================================================
# CMAKE PART: BUILD-OPTIONS: Setup CMAKE Build Options
# ===========================================================================
# USE: INCLUDE-AFTER project() !!!

include_guard(DIRECTORY)

# ---------------------------------------------------------------------------
# general user options for ninja and cppcheck
# ---------------------------------------------------------------------------
option(CMAKE_C_DEPFILE_EXTENSION_REPLACE "name depend files as main.d instead of main.c.d" YES)
option(CMAKE_C_OUTPUT_EXTENSION_REPLACE "name object files as main.o instead of main.c.o" YES)
option(CMAKE_CXX_DEPFILE_EXTENSION_REPLACE "name depend files as main.d instead of main.cpp.d" YES)
option(CMAKE_CXX_OUTPUT_EXTENSION_REPLACE "name object files as main.o instead of main.cpp.o" YES)

option(CMAKE_DEPENDS_IN_PROJECT_ONLY "do not use system header files" YES)
if(CMAKE_DEPENDS_IN_PROJECT_ONLY)
  set(CMAKE_DEPFILE_FLAGS_C "-MMD" CACHE STRING "dependency flag" FORCE)
  set(CMAKE_DEPFILE_FLAGS_CXX "-MMD" CACHE STRING "dependency flag" FORCE)
else()
  set(CMAKE_DEPFILE_FLAGS_C "-MD" CACHE STRING "dependency flag" FORCE)
  set(CMAKE_DEPFILE_FLAGS_CXX "-MD" CACHE STRING "dependency flag" FORCE)
endif()

# ----------------------------------------------------------------------------
# Compiler config
# ----------------------------------------------------------------------------
option(CXX_STANDARD_REQUIRED "Require C++17 standard" YES)
if(CXX_STANDARD_REQUIRED)
  set(CMAKE_CXX_STANDARD 17) # Use C++17 standard
  set(CMAKE_STANDARD_REQUIRED YES)
  set(CMAKE_CXX_EXTENSIONS NO)
endif()

option(COMPILER_WARNINGS_ARE_ERRORS "To be pedantic! ;-)" YES)
if(COMPILER_WARNINGS_ARE_ERRORS)
  if(MSVC)
    # warning level 4 and all warnings as errors
    add_compile_options(/W4 /WX)
  else()
    # lots of warnings and all warnings as errors
    add_compile_options(
      -Wall
      -Wextra
      -Wpedantic
      -Werror
      -Wno-unknown-warning-option
      -Wno-unused-parameter
      -Wno-unused-variable
    )
  endif()
endif()

option(USE_CXX_CPPCHECK "run cppcheck along with the compiler and report any problems" NO)
if(USE_CXX_CPPCHECK)
  find_program(CMAKE_CXX_CPPCHECK cppcheck HINTS /usr/local/bin "C:/Program Files/Cppcheck" REQUIRED)
else()
  unset(CMAKE_CXX_CPPCHECK)
endif()

option(USE_OUTPUT_PATH "build all libaries and runtime files at build/lib and build/bin" YES)
if(USE_OUTPUT_PATH)
  # -----------------------------------------------------------------------
  # Where to put all the LIBRARY targets when built.  This variable is used to initialize the
  # LIBRARY_OUTPUT_DIRECTORY property on all the targets.
  # -----------------------------------------------------------------------
  set(LIBRARY_OUTPUT_PATH ${CMAKE_BINARY_DIR}/lib)

  # -----------------------------------------------------------------------
  # Make sure the linker can find a library once it is built.
  # -----------------------------------------------------------------------
  link_directories(${LIBRARY_OUTPUT_PATH})

  # -----------------------------------------------------------------------
  # Where to put all the RUNTIME targets when built.  This variable is used to initialize the
  # RUNTIME_OUTPUT_DIRECTORY property on all the targets.
  # -----------------------------------------------------------------------
  set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
endif()

if(CMAKE_EXPORT_COMPILE_COMMANDS)
  set(CMAKE_CXX_STANDARD_INCLUDE_DIRECTORIES ${CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES})
endif()

option(ENABLE_CLANG_TIDY "Add clang-tidy checks automatically as prebuild step" NO)
if(ENABLE_CLANG_TIDY)
  include(${CMAKE_CURRENT_LIST_DIR}/clang-tidy.cmake)
endif()
