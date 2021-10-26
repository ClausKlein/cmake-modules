## TAO IDL
# Define a macro to generate IDL output
# After this macro is called,
#
# !!IMPORTANT!! To set the exports, the following
# variables must be set before calling this macro:
# EXPORT_NAME (e.g. mylib_Export ) and
# EXPORT_FILE (e,g. mylib_Export.h )
#
# Upon completion of this macro, the following variables will exist
#
# TAO_IDL_GENERATED - all files generated (add this to your target)
#
# TAO_IDL_GENERATED_HEADERS - generated header files (used for include
#                             file install)
#
# To add additional includes to the tao_idl command line, add them
# to TAO_IDL_INCLUDES before calling the macro:
# set( TAO_IDL_INCLUDES -I/my/foo/include ${TAO_IDL_INCLUDES )
#
#############################################################
macro(tao_wrap_idl)

  option(IDL_OUTPUT_IN_SOURCE_DIR "" OFF)
  if(NOT IDL_OUTPUT_IN_SOURCE_DIR)
    # in-source files need to see out-of-source files
    include_directories(${CMAKE_CURRENT_BINARY_DIR})
  endif()

  # on unix, set the LD_LIBRARY_PATH explicitly for tao_idl
  # and the PATH so tao_idl can use gperf
  #-----------------------------------------------------
  set(TAO_LIB_VAR "")
  set(TAO_BIN_VAR "")
  if(UNIX)
    set(LD_PATH_VAR LD_LIBRARY_PATH)
    if(APPLE) # "think different", indeed
      set(LD_PATH_VAR DYLD_LIBRARY_PATH)
    endif()
    set(ORIGINAL_PATH $ENV{PATH})
    set(ORIGINAL_LD_PATH $ENV{${LD_PATH_VAR}})
    set(TAO_LIB_VAR "${LD_PATH_VAR}=${ORIGINAL_LD_PATH}:${ACE_ROOT_DIR}/lib")
    set(TAO_BIN_VAR "PATH=${ORIGINAL_PATH}:${ACE_ROOT_DIR}/bin")
  endif()

  # the generated files need to reference the *_Export files,
  # so copy them to the out-of-source tree to avoid nasty
  # include path referencing mess
  #-----------------------------------------------------
  if(EXPORT_FILE)
    message(STATUS "Copying ${EXPORT_FILE} file to out-of-source tree... (GenerateTaoIdl)")
    exec_program(
      "${CMAKE_COMMAND}" ARGS -E copy_if_different "${CMAKE_CURRENT_SOURCE_DIR}/${EXPORT_FILE}"
                              "${CMAKE_CURRENT_BINARY_DIR}/${EXPORT_FILE}"
    )
  endif()

  set(IDL_CHDR "C.h")
  set(IDL_CINL "C.inl")
  set(IDL_CSRC "C.cpp")
  set(IDL_SHDR "S.h")
  set(IDL_SINL "S.inl")
  set(IDL_SSRC "S.cpp")

  set(TAO_IDL_VER_FLAGS "")
  # newer versions of TAO (ACE version 5.8.1+) default to generating errors
  # for anonymous types. -aw overrides this and makes it a warning
  # Nice of them to add new compiler flags as a "patch" update...
  if(ACE_VERSION VERSION_GREATER 5.8.0)
    set(TAO_IDL_VER_FLAGS -w -aw -Cw)
  endif()

  # -si flag disappeared somewhere before 2.1.2. Use default .inl extensions
  # NO! -ci ${IDL_CINL} -si ${IDL_SINL}
  # XXX -GC Generate the AMI classes
  # -in        To generate <>s for standard #include'd files (non-changing files)
  list(APPEND TAO_IDL_FLAGS ${TAO_IDL_VER_FLAGS} -in -Wb,pre_include=ace/pre.h -Wb,post_include=ace/post.h)
  #message(WARNING "TAO_IDL_FLAGS = ${TAO_IDL_FLAGS}")

  # TODO we should to some system introspection to narrow this list down
  set(TAO_IDL_INCLUDES
      -I${TAO_ROOT_INCLUDE}
      -I${TAO_ROOT_INCLUDE}/tao
      -I${TAO_ROOT_INCLUDE}/orbsvcs
      -I${TAO_ROOT_INCLUDE}/orbsvcs/orbsvcs
      # XXX -I/usr/local/share/idl
      # XXX -I/usr/local/share/idl/orbsvcs
      ${TAO_IDL_INCLUDES}
  )

  # add a custom command set for idl files
  #-----------------------------------------------------
  foreach(IDL_FILENAME ${ARGN})

    # get the basename (i.e. "NAME Without Extension")
    get_filename_component(IDL_BASE ${IDL_FILENAME} NAME_WE)
    get_filename_component(IDL_DEP_PATH ${IDL_FILENAME} ABSOLUTE)
    get_filename_component(IDL_SRC_DIR ${IDL_DEP_PATH} DIRECTORY)
    file(RELATIVE_PATH IDL_PATH ${CMAKE_CURRENT_SOURCE_DIR} ${IDL_SRC_DIR})
    #message(WARNING "IDL_PATH=${IDL_PATH}")

    if(IDL_OUTPUT_IN_SOURCE_DIR)
      set(SRCDIR ${IDL_SRC_DIR})
      set(OOSDIR ${IDL_SRC_DIR})
    else() # NOTE: OutOffSource Directory used! CK
      set(SRCDIR ${IDL_SRC_DIR})
      set(OOSDIR ${CMAKE_CURRENT_BINARY_DIR}/${IDL_PATH})
      #message(WARNING "OOSDIR=${OOSDIR}")
    endif()

    set(IDL_OUTPUT_HEADERS ${OOSDIR}/${IDL_BASE}${IDL_CHDR} ${OOSDIR}/${IDL_BASE}${IDL_CINL}
                           ${OOSDIR}/${IDL_BASE}${IDL_SHDR}
    )
    # newer versions of TAO don't generate servant inline files
    # not sure what version this happened at, the version
    # below is a guess
    if(ACE_VERSION VERSION_LESS 6.0.2)
      message(FATAL_ERROR "ACE_VERSION: ${ACE_VERSION} VERSION_LESS 6.0.2")
      list(APPEND IDL_OUTPUT_HEADERS ${OOSDIR}/${IDL_BASE}${IDL_SINL})
    endif()

    set(IDL_OUTPUT_SOURCES ${OOSDIR}/${IDL_BASE}${IDL_CSRC} ${OOSDIR}/${IDL_BASE}${IDL_SSRC})
    set(IDL_OUTPUT_FILES ${IDL_OUTPUT_HEADERS} ${IDL_OUTPUT_SOURCES})

    if(EXPORT_NAME)
      if(NOT EXTRA_TAO_IDL_ARGS MATCHES ".*export_macro=\"${EXPORT_NAME}\"")
        set(EXTRA_TAO_IDL_ARGS ${EXTRA_TAO_IDL_ARGS} -Wb,export_macro="${EXPORT_NAME}")
      endif()
    endif()

    if(EXPORT_FILE)
      if(NOT EXTRA_TAO_IDL_ARGS MATCHES ".*export_include=\"${EXPORT_FILE}\"")
        set(EXTRA_TAO_IDL_ARGS ${EXTRA_TAO_IDL_ARGS} -Wb,export_include="${EXPORT_FILE}")
      endif()
    endif()

    # output files depend on at least the corresponding idl
    set(DEPEND_FILE_LIST ${SRCDIR}/${IDL_BASE}.idl)

    file(READ ${IDL_FILENAME} IDL_FILE_CONTENTS LIMIT 2048)
    #message(WARNING "IDL_FILE_CONTENTS = ${IDL_FILE_CONTENTS}")

    # look for other dependencies
    foreach(IDL_DEP_FULL_FILENAME ${ARGN})
      get_filename_component(IDL_DEP_BASE ${IDL_DEP_FULL_FILENAME} NAME_WE)
      if(IDL_FILE_CONTENTS MATCHES ${IDL_DEP_BASE}\\.idl AND NOT IDL_DEP_FULL_FILENAME STREQUAL IDL_FILENAME)
        #message(STATUS "${IDL_FILENAME} depends on ${IDL_DEP_FULL_FILENAME}")
        list(APPEND DEPEND_FILE_LIST ${IDL_DEP_FULL_FILENAME})
      endif()
    endforeach()

    option(IDL_DEBUG_DEPENDENCIES "" OFF)
    if(IDL_DEBUG_DEPENDENCIES)
      message(STATUS "--------------------------------------")
      message(STATUS "  IDL_OUTPUT_FILES=${IDL_OUTPUT_FILES}")
      message(STATUS "  DEPEND_FILE_LIST=${DEPEND_FILE_LIST}")
      message(STATUS "       TAO_BIN_VAR=${TAO_BIN_VAR}")
      message(STATUS "       TAO_LIB_VAR=${TAO_LIB_VAR}")
      message(STATUS "   TAO_IDL_COMMAND=${TAO_IDL_COMMAND}")
      message(STATUS "     TAO_IDL_FLAGS=${TAO_IDL_FLAGS}")
      message(STATUS "EXTRA_TAO_IDL_ARGS=${EXTRA_TAO_IDL_ARGS}")
    endif()

    # setup the command
    #-----------------------------------------------------
    add_custom_command(
      OUTPUT ${IDL_OUTPUT_FILES}
      DEPENDS ${DEPEND_FILE_LIST}
      COMMAND ${TAO_BIN_VAR} ${TAO_LIB_VAR} ${TAO_IDL_COMMAND} ARGS ${TAO_IDL_FLAGS} ${EXTRA_TAO_IDL_ARGS}
              -I${CMAKE_CURRENT_SOURCE_DIR} ${TAO_IDL_INCLUDES} -o ${OOSDIR} ${IDL_DEP_PATH}
    )

    list(APPEND TAO_IDL_GENERATED_HEADERS ${IDL_OUTPUT_HEADERS})
    list(APPEND TAO_IDL_GENERATED ${IDL_OUTPUT_FILES})

  endforeach()

endmacro()
