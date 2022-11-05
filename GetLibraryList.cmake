# from:
# https://github.com/mallanmba/soraCore/blob/master/cmake/Modules/GetLibraryList.cmake
#
# Find a list of debug and release libraries for a
# given package. Example:
# Upon successful completion,
# get_library_list( FOO ${FOO_LIBRARY_DIR} "D" "foo bar" )
# would set:
#
# (unix)
# FOO_foo_LIBRARY = libfoo.so
# FOO_bar_LIBRARY = libbar.so
# FOO_LIBRARIES = ${FOO_foo_LIBRARY} ${FOO_bar_LIBRARY}
#
# (windows)
# FOO_foo_LIBRARY = optimized foo.lib debug fooD.lib
# FOO_bar_LIBRARY = optimized bar.lib debug barD.lib
# FOO_LIBRARIES = ${FOO_foo_LIBRARY} ${FOO_bar_LIBRARY}
#
# Any libraries that are not found are placed in
# FOO_MISSING_LIBRARIES
#
###########################################################

## find a single library. called by get_library_list. May be used
## for optional libraries in a package
##--------------------------------------------------------------------
macro(get_pkg_library
      PKG_PREFIX
      LIBRARY_DIR
      DEBUG_POSTFIX
      LIBRARY_NAME
      GET_DEBUG_AND_RELEASE
)

  set(LIBRARY_VAR_NAME ${PKG_PREFIX}_${LIBRARY_NAME}_LIBRARY)

  set(ACTUAL_NAME ${LIBRARY_NAME})
  if(${ARGC} EQUAL 6)
    set(ACTUAL_NAME ${ARGV5})
  endif()

  ##-- release libraries
  ##--------------------
  set(RELEASE_VAR_NAME ${PKG_PREFIX}_${LIBRARY_NAME}_LIBRARY_RELEASE)
  if(NOT ${RELEASE_VAR_NAME}) ## only search for it if it hasn't been found already
    find_library(${RELEASE_VAR_NAME} ${ACTUAL_NAME} ${LIBRARY_DIR} NO_DEFAULT_PATH)
  endif()

  if(NOT GET_DEBUG_AND_RELEASE)

    if(${RELEASE_VAR_NAME})
      mark_as_advanced(${RELEASE_VAR_NAME})
      set(${LIBRARY_VAR_NAME} ${${RELEASE_VAR_NAME}})
    else()
      set(${PKG_PREFIX}_MISSING_LIBRARIES ${${PKG_PREFIX}_MISSING_LIBRARIES} ${LIBRARY_VAR_NAME})
    endif()

  else() #-- on Windows we need to distinguish between optimized and debug

    if(${RELEASE_VAR_NAME})
      mark_as_advanced(${RELEASE_VAR_NAME})
    else()
      set(${PKG_PREFIX}_MISSING_LIBRARIES "${${PKG_PREFIX}_MISSING_LIBRARIES} ${RELEASE_VAR_NAME}")
    endif()

    ##-- debug libraries
    ##-------------------
    set(DEBUG_VAR_NAME ${PKG_PREFIX}_${LIBRARY_NAME}_LIBRARY_DEBUG)
    if(NOT ${DEBUG_VAR_NAME}) ## only search for it if it hasn't been found already
      find_library(${DEBUG_VAR_NAME} ${ACTUAL_NAME}${DEBUG_POSTFIX} ${LIBRARY_DIR} NO_DEFAULT_PATH)
    endif(NOT ${DEBUG_VAR_NAME})

    if(${DEBUG_VAR_NAME})
      mark_as_advanced(${DEBUG_VAR_NAME})
    else()
      set(${PKG_PREFIX}_MISSING_LIBRARIES "${${PKG_PREFIX}_MISSING_LIBRARIES} ${DEBUG_VAR_NAME}")
    endif()

    ##-- set user var
    ##----------------------
    set(TEMP_VAR "")

    if(${RELEASE_VAR_NAME} AND ${DEBUG_VAR_NAME})
      if(${RELEASE_VAR_NAME})
        set(TEMP_VAR optimized ${${RELEASE_VAR_NAME}})
      endif()

      if(${DEBUG_VAR_NAME})
        set(TEMP_VAR ${TEMP_VAR} debug ${${DEBUG_VAR_NAME}})
      endif()
    elseif(${RELEASE_VAR_NAME})
      set(TEMP_VAR ${${RELEASE_VAR_NAME}})
    elseif(${DEBUG_VAR_NAME})
      set(TEMP_VAR ${${DEBUG_VAR_NAME}})
    endif()

    if(NOT TEMP_VAR)
      set(TEMP_VAR NOTFOUND)
    endif()

    set(${LIBRARY_VAR_NAME} ${TEMP_VAR})

  endif()
endmacro()

##
## Find a list of libraries and set them in a ${PKG_PREFIX}_LIBRARIES
## variable. Also looks for release/debug libraries on Windows.
## PKG_PREFIX    : package prefix
## LIBRARY_DIR   : directory to search for libraries
## DEBUG_POSTFIX : postfix that denotes a debug library (typically "d")
## LIBRARY_NAMES : list of library names to search for
## (optional)    : set to TRUE if you want to search for debug&release lib names on UNIX
##---------------------------------------------------------------------------
macro(get_library_list
      PKG_PREFIX
      LIBRARY_DIR
      DEBUG_POSTFIX
      LIBRARY_NAMES
)

  set(GET_DEBUG_AND_RELEASE FALSE)
  if(WIN32)
    set(GET_DEBUG_AND_RELEASE TRUE)
  endif()
  if(${ARGC} EQUAL 5)
    set(GET_DEBUG_AND_RELEASE ${ARGV4})
  endif()

  foreach(LIBRARY_NAME ${LIBRARY_NAMES})
    get_pkg_library(
      ${PKG_PREFIX}
      ${LIBRARY_DIR}
      ${DEBUG_POSTFIX}
      ${LIBRARY_NAME}
      ${GET_DEBUG_AND_RELEASE}
    )
    ##-- add it to the list
    ##------------------------
    if(${LIBRARY_VAR_NAME})
      set(${PKG_PREFIX}_LIBRARIES ${${PKG_PREFIX}_LIBRARIES} ${${LIBRARY_VAR_NAME}})
    endif()
  endforeach()

  if(${PKG_PREFIX}_MISSING_LIBRARIES)
    message(WARNING "Could not find the following ${PKG_PREFIX} libraries:")
    message(WARNING "    ${${PKG_PREFIX}_MISSING_LIBRARIES}")
  endif()

endmacro()

## if a depend file exists, use the targets for linking
## instead of the library path. This will probably have
## some issues on windows when release exists but debug
## does not. If this approach works, move it into
## get_library_list and do it automatically
##---------------------------------------------------------------------------
macro(get_library_imports PKG_NAME LIBRARY_DIR LIBRARY_NAMES)
  string(TOUPPER "${PKG_NAME}" PKG_PREFIX)

  set(DEPEND_DIR ${LIBRARY_DIR}/cmake)
  set(DEPEND_FILE ${DEPEND_DIR}/${PKG_NAME}.cmake)
  #message("  (dbg) depend file is ${DEPEND_FILE}")
  #message("  (dbg) LIBRARY_NAMES=${LIBRARY_NAMES}")

  if(EXISTS ${DEPEND_FILE})
    message(STATUS "  importing ${PKG_NAME} dependency info from ${DEPEND_FILE}")
    include(${DEPEND_FILE})
    set(${PKG_PREFIX}_HAS_IMPORTS TRUE)

    # reconstruct the PKG_LIBRARIES variable
    set(${PKG_PREFIX}_LIBRARIES "")

    foreach(LIBRARY_NAME ${LIBRARY_NAMES})
      #message("  (dbg) check ${PKG_PREFIX}_${LIBRARY_NAME}_LIBRARY = ${${PKG_PREFIX}_${LIBRARY_NAME}_LIBRARY}")

      # if the library was found, change the value to target name instead of lib path
      if(${PKG_PREFIX}_${LIBRARY_NAME}_LIBRARY)
        set(${PKG_PREFIX}_${LIBRARY_NAME}_LIBRARY ${LIBRARY_NAME})
        set(${PKG_PREFIX}_LIBRARIES ${${PKG_PREFIX}_LIBRARIES} ${LIBRARY_NAME})
      endif()

      #message("  (dbg) check ${PKG_PREFIX}_${LIBRARY_NAME}_LIBRARY = ${${PKG_PREFIX}_${LIBRARY_NAME}_LIBRARY}")

    endforeach()

  else()
    message(WARNING "Failed to find dependency info file ${DEPEND_FILE}")
  endif()

endmacro()
