# cmake-format: off

find_program(GIT_PROGRAM git REQUIRED)
message(DEBUG "${GIT_PROGRAM}")

find_program(PYTHON_PROGRAM python REQUIRED)
message(DEBUG "${PYTHON_PROGRAM}")

find_program(CLANG_TIDY_PROGRAM run-clang-tidy REQUIRED)
message(DEBUG "${CLANG_TIDY_PROGRAM}")

execute_process(
    COMMAND ${GIT_PROGRAM} rev-parse --show-toplevel
    OUTPUT_VARIABLE GIT_TOPLEVEL
)

# remove trailing whitespace from output
string(STRIP ${GIT_TOPLEVEL} GIT_TOPLEVEL)

# filter a git repository's files.
function(get_cmake_files)
    cmake_parse_arguments("" "" "OUTPUT_LIST" "GIT_PATTERN" ${ARGN})

    execute_process(
        COMMAND
            ${GIT_PROGRAM} ls-files --cached --exclude-standard ${_GIT_PATTERN}
        WORKING_DIRECTORY ${GIT_TOPLEVEL}
        OUTPUT_VARIABLE all_files
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    string(REGEX REPLACE "[\n\r]+" ";" all_files "${all_files}")
    set(${_OUTPUT_LIST} ${all_files} PARENT_SCOPE)
endfunction()

get_cmake_files(GIT_PATTERN ::*.cpp ::*.cxx OUTPUT_LIST CPP_FILES)

list(TRANSFORM CPP_FILES PREPEND ${GIT_TOPLEVEL}/)
execute_process(
    COMMAND ${PYTHON_PROGRAM} ${CLANG_TIDY_PROGRAM} -p build ${CPP_FILES}
    WORKING_DIRECTORY ${GIT_TOPLEVEL}
    OUTPUT_FILE run-clang-tidy.log
    ERROR_FILE run-clang-tidy.log
    COMMAND_ECHO STDOUT
    ECHO_OUTPUT_VARIABLE
    ECHO_ERROR_VARIABLE
    COMMAND_ERROR_IS_FATAL ANY
)

return()

#XXX ##############################################################
# NOTE: this fails if not all cpp files are used within the cmake project!
foreach(cmake_file IN LISTS CPP_FILES)
    message(DEBUG "${cmake_file}")
    # set(_source_cmake_file ${GIT_TOPLEVEL}/${cmake_file})

    execute_process(
        COMMAND clang-tidy -p build ${cmake_file}
        WORKING_DIRECTORY ${GIT_TOPLEVEL}
        COMMAND_ECHO STDOUT
        OUTPUT_VARIABLE clang-tidy.out
        ERROR_VARIABLE clang-tidy.err
        ECHO_OUTPUT_VARIABLE
        ECHO_ERROR_VARIABLE
        RESULT_VARIABLE result
    )
    file(APPEND run-clang-tidy.log ${clang-tidy.out} ${clang-tidy.err})

    if(result)
        message(FATAL_ERROR "clang-tidy ${cmake_file} failed!")
    endif()
endforeach()
#XXX ##############################################################

# cmake-format: on
