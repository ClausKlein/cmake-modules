######################################################################
# Find script for TAO
#
# Prereqs: FindACE should be called before FindTAO
#
# Includes the GenerateTaoIdl macro for IDL generation
# and finds the tao_idl executable
#
# NOTE: TAO_INCLUDE_DIRS also includes ACE_INCLUDE_DIR
#       and TAO_LIBRARIES includes ACE_BASE_LIBRARY
#
# This script only supports the 'traditional' ACE/TAO directory
# structure. If/when we start supporting the autoconf 'make install'
# directory structure, it will need to be revised.
#
# Output Variables:
# -----------------
# TAO_FOUND           : TRUE if search succeded
# TAO_INCLUDE_DIRS    : All TAO include paths plus ACE include path
# TAO_LIBRARIES       : all libraries in one variable (use this in your CMakeLists)
# TAO_LIBRARY_DIR     : library path
#
######################################################################

include(GetLibraryList)

message(STATUS "Looking for TAO")

if(NOT ACE_FOUND)
  find_package(ACE REQUIRED)
endif()

# include the idl generation macro in the Find
# script so we don't have to explicitly include
# it elsewhere
#--------------------------------------------------
include(GenerateTaoIdl)

# look for TAO_ROOT_DIR by searching for orbsvcs directory
# This is detects a "traditional" TAO build
#--------------------------------------------------
find_path(TAO_ROOT_DIR "orbsvcs" ${ACE_ROOT_DIR}/TAO NO_DEFAULT_PATH DOC "root directory of TAO build")
message(STATUS "  TAO root may be ${TAO_ROOT_DIR}")

# if TAO directory isn't there, we've probably got
# an autotools build of ACE/TAO
#--------------------------------------------------
if(NOT TAO_ROOT_DIR)
  find_path(TAO_ROOT_DIR "include/orbsvcs" ${ACE_ROOT_DIR} NO_DEFAULT_PATH DOC "root directory of TAO build")
  if(TAO_ROOT_DIR)
    # we have to cache this value because TAO_ROOT_DIR is cached
    set(TAO_WAS_BUILT_WITH_AUTOTOOLS TRUE CACHE BOOL
                                                "Different include paths are required if ACE/TAO was build with autotools"
    )
    mark_as_advanced(TAO_WAS_BUILT_WITH_AUTOTOOLS)
    message(STATUS "  TAO appears to have been built using autotools instead of traditional build")
  endif()
endif()

# Set the INCLUDE and LIB directories based on
# what we're assuming is TAO_ROOT_DIR
# TODO: do some proper checks to verify these paths
#--------------------------------------------------
if(TAO_ROOT_DIR)
  message(STATUS "  TAO root assumed to be ${TAO_ROOT_DIR}")

  # library and include dirs are different if ACE/TAO was built with
  # autotools versus their traditional build system
  if(TAO_WAS_BUILT_WITH_AUTOTOOLS)
    set(TAO_INCLUDE_DIR ${TAO_ROOT_DIR}/include)
    set(TAO_LIBRARY_DIR ${TAO_ROOT_DIR}/lib)
  else()
    # TAO includes are found under TAO, but TAO libraries are found under ACE
    set(TAO_INCLUDE_DIR ${TAO_ROOT_DIR})
    set(TAO_LIBRARY_DIR ${ACE_LIBRARY_DIR})
  endif()

  # this will be needed by GenerateTaoIdl
  set(TAO_ROOT_INCLUDE ${TAO_INCLUDE_DIR})
endif()

# find the IDL compiler
#--------------------------------------------------
find_program(TAO_IDL_COMMAND tao_idl HINTS ${ACE_ROOT_DIR}/bin NO_SYSTEM_ENVIRONMENT_PATH)
message(STATUS "  TAO_IDL_COMMAND = ${TAO_IDL_COMMAND}")

if(TAO_INCLUDE_DIR AND TAO_LIBRARY_DIR AND TAO_IDL_COMMAND)

  if(TAO_WAS_BUILT_WITH_AUTOTOOLS)
    set(TAO_INCLUDE_DIRS ${TAO_INCLUDE_DIR} ${TAO_INCLUDE_DIR}/tao ${TAO_INCLUDE_DIR}/orbsvcs)
  else()
    set(TAO_INCLUDE_DIRS
        ${ACE_INCLUDE_DIR}
        ${TAO_INCLUDE_DIR}
        ${TAO_INCLUDE_DIR}/tao
        ${TAO_INCLUDE_DIR}/orbsvcs
        ${TAO_INCLUDE_DIR}/orbsvcs/orbsvcs
    )
  endif()
  # XXX standardize on singular: it has become cmake convention even though it's somewhat misleading
  set(TAO_INCLUDE_DIR ${TAO_INCLUDE_DIRS})

  message(STATUS "  TAO_INCLUDE_DIRS:=${TAO_INCLUDE_DIRS}")

  ## find full paths to all the TAO libraries we need
  ###################################################
  set(TAO_LIBRARY_NAMES
      ACE
      TAO
      TAO_AnyTypeCode
      TAO_BiDirGIOP
      TAO_CodecFactory
      TAO_Codeset
      TAO_CosEvent
      TAO_CosEvent_Skel
      TAO_CosNaming
      TAO_CosNotification
      TAO_CosNotification_Serv
      TAO_CosNotification_Skel
      TAO_DynamicAny
      TAO_DynamicInterface
      TAO_ETCL
      TAO_IORManip
      TAO_IORTable
      TAO_Messaging
      TAO_PI
      TAO_PI_Server
      TAO_PortableServer
      TAO_Strategies
      TAO_Svc_Utils
      TAO_TypeCodeFactory
      TAO_Utils
      TAO_Valuetype
  )

  set(TAO_MISSING_LIBRARIES "")

  get_library_list(
    TAO
    ${TAO_LIBRARY_DIR}
    "d"
    "${TAO_LIBRARY_NAMES}"
    ON
  )

  if(TAO_MISSING_LIBRARIES)
    #XXX message(WARNING "Not all TAO libraries were found! Missing libraries:\n    ${TAO_MISSING_LIBRARIES}\n")
  endif()

  # Find TAO version by looking at Version.h
  find_file(
    TAO_VERSION_HEADER "Version.h"
    PATHS ${TAO_INCLUDE_DIR}
    PATH_SUFFIXES tao
    DOC "TAO version file"
    NO_DEFAULT_PATH
  )
  message(STATUS "TAO_VERSION_HEADER ${TAO_VERSION_HEADER}")
  if(EXISTS ${TAO_VERSION_HEADER})
    file(STRINGS ${TAO_VERSION_HEADER} TAO_TEMP REGEX "^#define TAO_[A-Z]+_VERSION[ \t]+[0-9]+$")
    string(REGEX REPLACE ".*#define TAO_MAJOR_VERSION[ \t]+([0-9]+).*" "\\1" TAO_VERSION_MAJOR ${TAO_TEMP})
    string(REGEX REPLACE ".*#define TAO_MINOR_VERSION[ \t]+([0-9]+).*" "\\1" TAO_VERSION_MINOR ${TAO_TEMP})
    string(REGEX REPLACE ".*#define TAO_MICRO_VERSION[ \t]+([0-9]+).*" "\\1" TAO_VERSION_PATCH ${TAO_TEMP})
    set(TAO_VERSION ${TAO_VERSION_MAJOR}.${TAO_VERSION_MINOR}.${TAO_VERSION_PATCH})
    message(STATUS "  Found TAO version ${TAO_VERSION} in ${TAO_ROOT_DIR}")
  else()
    message(WARNING "Could not find TAO version header ${TAO_VERSION_HEADER}")
  endif()

  message(STATUS "  Found TAO libs: ${TAO_LIBRARIES}")

  include(FindPackageHandleStandardArgs)
  find_package_handle_standard_args(
    TAO
    DEFAULT_MSG
    TAO_VERSION
    TAO_INCLUDE_DIRS
    TAO_LIBRARY_DIR
    TAO_LIBRARIES
  )

else()

  message(WARNING "  TAO root and/or TAO IDL compiler were not found.")

endif()
