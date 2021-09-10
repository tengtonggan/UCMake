# ----------------------------------------------------------------------------
#
# Ubpa_AddDep(<dep-list>)
#
# ----------------------------------------------------------------------------
#
# Ubpa_Export([INC <inc>])
# - export some files
# - inc: default ON, install include/
#
# ----------------------------------------------------------------------------

message(STATUS "include UbpaPackage.cmake")

set(Ubpa_${PROJECT_NAME}_have_dependencies FALSE)

function(Ubpa_DecodeVersion major minor patch version)
  if("${version}" MATCHES "^([0-9]+)\\.([0-9]+)\\.([0-9]+)")
    set(${major} "${CMAKE_MATCH_1}" PARENT_SCOPE)
    set(${minor} "${CMAKE_MATCH_2}" PARENT_SCOPE)
    set(${patch} "${CMAKE_MATCH_3}" PARENT_SCOPE)
  elseif("${version}" MATCHES "^([0-9]+)\\.([0-9]+)")
    set(${major} "${CMAKE_MATCH_1}" PARENT_SCOPE)
    set(${minor} "${CMAKE_MATCH_2}" PARENT_SCOPE)
    set(${patch} "" PARENT_SCOPE)
  else()
    set(${major} "${CMAKE_MATCH_1}" PARENT_SCOPE)
    set(${minor} "" PARENT_SCOPE)
    set(${patch} "" PARENT_SCOPE)
  endif()
endfunction()

function(Ubpa_ToPackageName rst name version)
  set(tmp "${name}.${version}")
  string(REPLACE "." "_" tmp ${tmp})
  set(${rst} ${tmp} PARENT_SCOPE)
endfunction()

function(Ubpa_PackageName rst)
  Ubpa_ToPackageName(tmp ${PROJECT_NAME} ${PROJECT_VERSION})
  set(${rst} ${tmp} PARENT_SCOPE)
endfunction()

macro(Ubpa_AddDepPro projectName name version)
  set(Ubpa_${projectName}_have_dependencies TRUE)
  list(FIND Ubpa_${projectName}_dep_name_list "${name}" _idx)
  if(_idx EQUAL -1)
    message(STATUS "start add dependence ${name} ${version}")
    set(_need_find TRUE)
  else()
    set(_A_version "${${name}_VERSION}")
    set(_B_version "${version}")
    if(_A_version EQUAL _B_version)
      message(STATUS "Diamond dependence of ${name} with same version: ${_A_version} and ${_B_version}")
      set(_need_find FALSE)
    else()
      message(FATAL_ERROR "Diamond dependence of ${name} with incompatible version: ${_A_version} and ${_B_version}")
    endif()
  endif()
  if(_need_find)
    list(APPEND Ubpa_${projectName}_dep_name_list ${name})
    list(APPEND Ubpa_${projectName}_dep_version_list ${version})
    message(STATUS "find package: ${name} ${version}")
    find_package(${name} ${version} QUIET)
    if(${${name}_FOUND})
      message(STATUS "${name} ${${name}_VERSION} found")
    else()
      set(_address "git@github.com:Ubpa/${name}.git")
      message(STATUS "${name} ${version} not found")
      message(STATUS "fetch: ${_address} with tag ${version}")
      FetchContent_Declare(
        ${name}
        GIT_REPOSITORY ${_address}
        GIT_TAG "${version}"
      )
      FetchContent_MakeAvailable(${name})
      message(STATUS "${name} ${version} build done")
    endif()
  endif()
endmacro()

macro(Ubpa_AddDep name version)
  Ubpa_AddDepPro(${PROJECT_NAME} ${name} ${version})
endmacro()

macro(Ubpa_Export)
  cmake_parse_arguments("ARG" "TARGET;CPM" "" "DIRECTORIES" ${ARGN})
  
  Ubpa_PackageName(package_name)
  message(STATUS "export ${package_name}")

  set(UBPA_PACKAGE_INIT "
get_filename_component(include_dir \"\${CMAKE_CURRENT_LIST_DIR}/../include\" ABSOLUTE)
include_directories(\"\${include_dir}\")\n")
  
  if(ARG_CPM OR Ubpa_${PROJECT_NAME}_have_dependencies)
    set(UBPA_PACKAGE_INIT "${UBPA_PACKAGE_INIT}
if(NOT FetchContent_FOUND)
  include(FetchContent)
endif()
if(NOT UCMake_FOUND)
  message(STATUS \"find package: UCMake ${UCMake_VERSION}\")
  find_package(UCMake ${UCMake_VERSION} EXACT QUIET)
  if(NOT UCMake_FOUND)
    set(_Ubpa_UCMake_address \"git@github.com:Ubpa/UCMake.git\")
    message(STATUS \"UCMake ${UCMake_VERSION} not found\")
    message(STATUS \"fetch: \${_Ubpa_UCMake_address} with tag \${UCMake_VERSION}\")
    FetchContent_Declare(
      UCMake
      GIT_REPOSITORY \${_Ubpa_UCMake_address}
      GIT_TAG ${UCMake_VERSION}
    )
    FetchContent_MakeAvailable(UCMake)
    message(STATUS \"UCMake ${UCMake_VERSION} build done\")
  endif()
endif()
"
    )
    
    list(LENGTH Ubpa_${PROJECT_NAME}_dep_name_list _dep_num)
    if(_dep_num GREATER 0)
      message(STATUS "[Dependencies]")
      list(LENGTH Ubpa_${PROJECT_NAME}_dep_name_list _dep_num)
      math(EXPR _stop "${_dep_num}-1")
      foreach(index RANGE ${_stop})
        list(GET Ubpa_${PROJECT_NAME}_dep_name_list ${index} dep_name)
        list(GET Ubpa_${PROJECT_NAME}_dep_version_list ${index} dep_version)
        message(STATUS "- ${dep_name} ${dep_version}")
        string(APPEND UBPA_PACKAGE_INIT "Ubpa_AddDepPro(${PROJECT_NAME} ${dep_name} ${dep_version})\n")
      endforeach()
    endif()
  endif()
  
  if(ARG_TARGET)
    # generate the export targets for the build tree
    # needs to be after the install(TARGETS) command
    export(EXPORT "${PROJECT_NAME}Targets"
      NAMESPACE "Ubpa::"
      #FILE "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Targets.cmake"
    )
    
    # install the configuration targets
    install(EXPORT "${PROJECT_NAME}Targets"
      FILE "${PROJECT_NAME}Targets.cmake"
      NAMESPACE "Ubpa::"
      DESTINATION "${package_name}/cmake"
    )
  endif()
  
  include(CMakePackageConfigHelpers)
  # generate the config file that is includes the exports
  configure_package_config_file(${PROJECT_SOURCE_DIR}/config/Config.cmake.in
    "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake"
    INSTALL_DESTINATION "${package_name}/cmake"
    NO_SET_AND_CHECK_MACRO
    NO_CHECK_REQUIRED_COMPONENTS_MACRO
  )
  
  # generate the version file for the config file
  write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake"
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMinorVersion
  )

  # install the configuration file
  install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake"
    DESTINATION "${package_name}/cmake"
  )
  
  foreach(dir ${ARG_DIRECTORIES})
    string(REGEX MATCH "(.*)/" prefix ${dir})
    if("${CMAKE_MATCH_1}" STREQUAL "")
      set(_destination "${package_name}")
    else()
      set(_destination "${package_name}/${CMAKE_MATCH_1}")
    endif()
    install(DIRECTORY ${dir} DESTINATION "${_destination}")
  endforeach()
endmacro()
