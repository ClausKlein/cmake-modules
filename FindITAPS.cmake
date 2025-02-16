# - Try to find ITAPS
#
# This will define
#
#  ITAPS_FOUND          - Requested components were found
#  ITAPS_INCLUDES       - Includes for all available components
#  ITAPS_LIBRARIES      - Libraries for all available components
#
#  ITAPS_MESH_FOUND     - System has iMesh
#  ITAPS_MESH_INCLUDES  - The iMesh include directory
#  ITAPS_MESH_LIBRARIES - Link these to use iMesh
#
#  ITAPS_GEOM_FOUND     - System has iGeom
#  ITAPS_GEOM_INCLUDES  - The iGeom include directory
#  ITAPS_GEOM_LIBRARIES - Link these to use iGeom
#
#  ITAPS_REL_FOUND      - System has iRel
#  ITAPS_REL_INCLUDES   - The iRel include directory
#  ITAPS_REL_LIBRARIES  - Link these to use iRel
#
# Setting this changes the behavior of the search
#  ITAPS_MESH_DEFS_FILE - path to iMesh-Defs.inc
#  ITAPS_GEOM_DEFS_FILE - path to iGeom-Defs.inc
#  ITAPS_REL_DEFS_FILE  - path to iRel-Defs.inc
#
# If any of these variables are in your environment, they will be used as hints
#  IMESH_DIR - directory in which iMesh resides
#  IGEOM_DIR - directory in which iGeom resides
#  IREL_DIR  - directory in which iRel resides
#
# Redistribution and use is allowed according to the terms of the BSD license.
# For details see the accompanying COPYING-CMAKE-SCRIPTS file.
#

include(FindPackageMultipass)
include(ResolveCompilerPaths)
include(CheckCSourceRuns)
include(FindPackageHandleStandardArgs)

find_program(MAKE_EXECUTABLE NAMES make gmake)

macro(ITAPS_PREPARE_COMPONENT component name)
  find_file(ITAPS_${component}_DEFS_FILE ${name}-Defs.inc HINTS ENV I${component}_DIR PATH_SUFFIXES lib64 lib)
  # If ITAPS_XXX_DEFS_FILE has changed, the library will be found again
  find_package_multipass(
    ITAPS_${component}
    itaps_${component}_config_current
    STATES
    DEFS_FILE
    DEPENDENTS
    INCLUDES
    LIBRARIES
    EXECUTABLE_RUNS
  )
endmacro()

macro(ITAPS_GET_VARIABLE makefile name var)
  set(${var} "NOTFOUND" CACHE INTERNAL "Cleared" FORCE)
  execute_process(
    COMMAND ${MAKE_EXECUTABLE} -f ${${makefile}} show VARIABLE=${name} OUTPUT_VARIABLE ${var} RESULT_VARIABLE itaps_return
  )
endmacro(ITAPS_GET_VARIABLE)

macro(ITAPS_TEST_RUNS
      component
      name
      includes
      libraries
      program
      runs
)
  # message (STATUS "Starting run test: ${includes} ${libraries} ${runs}")
  multipass_c_source_runs("${includes}" "${libraries}" "${program}" ${runs})
  if(NOT ITAPS_${component}_EXECUTABLE_RUNS)
    set(ITAPS_${component}_EXECUTABLE_RUNS
        "${${runs}}"
        CACHE BOOL
              "Can the system successfully run an ${name} executable?  This variable can be manually set to \"YES\" to force CMake to accept a given configuration, but this will almost always result in a broken build."
              FORCE
    )
  endif()
endmacro(ITAPS_TEST_RUNS)

macro(ITAPS_REQUIRED_LIBS
      component
      name
      includes
      libraries_all
      program
      libraries_required
)
  # message (STATUS "trying program: ${program}")
  resolve_libraries(_all_libraries "${libraries_all}")
  list(GET _all_libraries 0 _first_library)
  itaps_test_runs(
    ${component}
    ${name}
    "${includes}"
    "${_first_library};${itaps_rel_libs}"
    "${program}"
    ${name}_works_minimal
  )
  if(${name}_works_minimal)
    set(${libraries_required} "${_first_library}")
    message(STATUS "${name} executable works when only linking to the interface lib, this probably means you have shared libs."
    )
  else()
    itaps_test_runs(
      ${component}
      ${name}
      "${includes}"
      "${_all_libraries};${itaps_rel_libs}"
      "${itaps_mesh_program}"
      ${name}_works_extra
    )
    if(${name}_works_extra)
      set(${libraries_required} "${_all_libraries}")
      message(STATUS "${name} executable requires linking to extra libs, this probably means it's statically linked.")
    else()
      message(STATUS "${name} could not be used, maybe the install is broken.")
    endif()
  endif()
endmacro()

macro(ITAPS_HANDLE_COMPONENT component name program)
  itaps_prepare_component("${component}" "${name}")
  if(ITAPS_${component}_DEFS_FILE AND NOT itaps_${component}_config_current)
    # A temporary makefile to probe this ITAPS components's configuration
    set(itaps_config_makefile "${PROJECT_BINARY_DIR}/Makefile.${name}")
    file(WRITE ${itaps_config_makefile}
         "## This file was autogenerated by FindITAPS.cmake
include ${ITAPS_${component}_DEFS_FILE}
show :
\t-@echo -n \${\${VARIABLE}}"
    )
    itaps_get_variable(itaps_config_makefile I${component}_INCLUDEDIR itaps_includedir)
    itaps_get_variable(itaps_config_makefile I${component}_LIBS itaps_libs)
    file(REMOVE ${itaps_config_makefile})
    find_path(itaps_include_tmp ${name}.h HINTS ${itaps_includedir} NO_DEFAULT_PATH)
    set(ITAPS_${component}_INCLUDES "${itaps_include_tmp}" CACHE STRING "Include directories for ${name}")
    set(itaps_include_tmp "NOTFOUND" CACHE INTERNAL "Cleared" FORCE)
    itaps_required_libs(
      "${component}"
      "${name}"
      "${ITAPS_${component}_INCLUDES}"
      "${itaps_libs}"
      "${program}"
      itaps_${component}_required_libraries
    )
    set(ITAPS_${component}_LIBRARIES "${itaps_${component}_required_libraries}" CACHE STRING "Libraries for ${name}")
    mark_as_advanced(ITAPS_${component}_EXECUTABLE_RUNS ITAPS_${component}_LIBRARIES)
  endif()
  set(ITAPS_${component}_FOUND "${ITAPS_${component}_EXECUTABLE_RUNS}")
endmacro()

itaps_handle_component(
  MESH
  iMesh
  "
/* iMesh test program */
#include <iMesh.h>
#define CHK(err) if (err) return 1
int main(int argc,char *argv[]) {
  int err;
  iMesh_Instance m;
  iMesh_newMesh(\"\",&m,&err,0);CHK(err);
  iMesh_dtor(m,&err);CHK(err);
  return 0;
}
"
)
find_path(imesh_include_tmp iMeshP.h HINTS ${ITAPS_MESH_INCLUDES} NO_DEFAULT_PATH)
if(imesh_include_tmp)
  set(ITAPS_MESH_HAS_PARALLEL "YES")
else()
  set(ITAPS_MESH_HAS_PARALLEL "NO")
endif()
set(imesh_include_tmp "NOTFOUND" CACHE INTERNAL "Cleared" FORCE)

set(itaps_rel_libs) # Extra libraries which should only be set when linking with iRel

itaps_handle_component(
  GEOM
  iGeom
  "
/* iGeom test program */
#include <iGeom.h>
#define CHK(err) if (err) return 1
int main() {
  int ierr;
  iGeom_Instance g;
  iGeom_newGeom(\"\",&g,&ierr,0);CHK(ierr);
  iGeom_dtor(g,&ierr);CHK(ierr);
  return 0;
}
"
)

if(ITAPS_MESH_FOUND AND ITAPS_GEOM_FOUND) # iRel only makes sense if iMesh and iGeom are found
  set(itaps_rel_libs "${ITAPS_MESH_LIBRARIES}" "${ITAPS_GEOM_LIBRARIES}")
  itaps_handle_component(
    REL
    iRel
    "
/* iRel test program */
#include <iRel.h>
#define CHK(err) if (err) return 1
int main() {
  int ierr;
  iRel_Instance rel;
  iRel_create(\"\",&rel,&ierr,0);CHK(ierr);
  iRel_destroy(rel,&ierr);CHK(ierr);
  return 0;
}
"
  )
endif()

set(ITAPS_INCLUDES)
set(ITAPS_LIBRARIES)
foreach(component REL GEOM MESH)
  if(ITAPS_${component}_INCLUDES)
    list(APPEND ITAPS_INCLUDES "${ITAPS_${component}_INCLUDES}")
  endif()
  if(ITAPS_${component}_LIBRARIES)
    list(APPEND ITAPS_LIBRARIES "${ITAPS_${component}_LIBRARIES}")
  endif()
  message(STATUS "ITAPS_${component}: ${ITAPS_${component}_INCLUDES} ${ITAPS_${component}_LIBRARIES}")
endforeach()
list(REMOVE_DUPLICATES ITAPS_INCLUDES)
list(REMOVE_DUPLICATES ITAPS_LIBRARIES)

set(ITAPS_FOUND_REQUIRED_COMPONENTS YES)
if(ITAPS_FIND_REQUIRED)
  foreach(component ${ITAPS_FIND_COMPONENTS})
    if(NOT ITAPS_${component}_FOUND)
      set(ITAPS_FOUND_REQUIRED_COMPONENTS NOTFOUND)
    endif()
  endforeach()
endif()

message(STATUS "ITAPS: ${ITAPS_INCLUDES}  ${ITAPS_LIBRARIES}")

find_package_handle_standard_args(
  ITAPS
  "ITAPS not found, check environment variables I{MESH,GEOM,REL}_DIR"
  ITAPS_INCLUDES
  ITAPS_LIBRARIES
  ITAPS_FOUND_REQUIRED_COMPONENTS
)
