# Input:
# TENSORFLOW_ROOT 
# BUILD_CPP_IF
#
# Output:
# TensorFlow_FOUND        
# TensorFlow_INCLUDE_DIRS 
# TensorFlow_LIBRARY    
# TensorFlow_LIBRARY_PATH
# TensorFlowFramework_LIBRARY    
# TensorFlowFramework_LIBRARY_PATH
#
# Target:
# TensorFlow::tensorflow_framework
# TensorFlow::tensorflow_cc

if (BUILD_CPP_IF AND INSTALL_TENSORFLOW)
  # Here we try to install libtensorflow_cc using conda install.

  if (USE_CUDA_TOOLKIT)
    set (VARIANT cuda)
  else ()
    set (VARIANT cpu)
  endif ()

  if (NOT DEFINED TENSORFLOW_ROOT)
    set (TENSORFLOW_ROOT ${CMAKE_INSTALL_PREFIX})
  endif ()
  # execute conda install
  execute_process(
	  COMMAND conda create libtensorflow_cc=*=${VARIANT}* -c deepmodeling -y -p ${TENSORFLOW_ROOT}
	  )
endif ()

if (BUILD_CPP_IF AND USE_TF_PYTHON_LIBS AND NOT SKBUILD)
  # Here we try to install libtensorflow_cc.so as well as libtensorflow_framework.so using libs within the python site-package tensorflow folder.
  execute_process(
    COMMAND ${Python_EXECUTABLE} -c "import tensorflow; print(tensorflow.sysconfig.get_lib())"
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
    OUTPUT_VARIABLE TENSORFLOW_ROOT
    RESULT_VARIABLE TENSORFLOW_ROOT_RESULT_VAR
    ERROR_VARIABLE TENSORFLOW_ROOT_ERROR_VAR
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
  if (NOT ${TENSORFLOW_ROOT_RESULT_VAR} EQUAL 0)
    message(FATAL_ERROR "Cannot determine tensorflow root, error code: ${TENSORFLOW_ROOT_RESULT_VAR}, error message: ${TENSORFLOW_ROOT_ERROR_VAR}")
  endif()
endif ()

if(DEFINED TENSORFLOW_ROOT)
  string(REPLACE "lib64" "lib" TENSORFLOW_ROOT_NO64 ${TENSORFLOW_ROOT})
endif(DEFINED TENSORFLOW_ROOT)

# define the search path
list(APPEND TensorFlow_search_PATHS ${TENSORFLOW_ROOT})
if(BUILD_CPP_IF AND NOT USE_TF_PYTHON_LIBS)
list(APPEND TensorFlow_search_PATHS ${TENSORFLOW_ROOT_NO64})
list(APPEND TensorFlow_search_PATHS "/usr/")
list(APPEND TensorFlow_search_PATHS "/usr/local/")
endif()
if(BUILD_PY_IF OR USE_TF_PYTHON_LIBS)
	# here TENSORFLOW_ROOT is path to site-packages/tensorflow
	# for conda libraries, append extra paths
	list(APPEND TensorFlow_search_PATHS "${TENSORFLOW_ROOT}/../tensorflow_core")
endif()

# includes
find_path(TensorFlow_INCLUDE_DIRS
  NAMES 
  tensorflow/core/public/session.h
  tensorflow/core/platform/env.h
  tensorflow/core/framework/op.h
  tensorflow/core/framework/op_kernel.h
  tensorflow/core/framework/shape_inference.h
  PATHS ${TensorFlow_search_PATHS} 
  PATH_SUFFIXES "/include"
  NO_DEFAULT_PATH
  )
  
if (NOT TensorFlow_INCLUDE_DIRS AND tensorflow_FIND_REQUIRED)
  message(FATAL_ERROR 
    "Not found 'include/tensorflow/core/public/session.h' directory or other header files in path '${TensorFlow_search_PATHS}' "
    "You can manually set the tensorflow install path by -DTENSORFLOW_ROOT ")
endif ()

if (BUILD_CPP_IF AND NOT USE_TF_PYTHON_LIBS)
  message (STATUS "Enabled cpp interface build, looking for tensorflow_cc and tensorflow_framework")
  # tensorflow_cc and tensorflow_framework
  if (NOT TensorFlow_FIND_COMPONENTS)
    set(TensorFlow_FIND_COMPONENTS tensorflow_cc tensorflow_framework)
  endif ()
  # the lib
  list(APPEND CMAKE_FIND_LIBRARY_SUFFIXES .so.1)
  list(APPEND CMAKE_FIND_LIBRARY_SUFFIXES .so.2)
  set (TensorFlow_LIBRARY_PATH "")
  foreach (module ${TensorFlow_FIND_COMPONENTS})
    find_library(TensorFlow_LIBRARY_${module}
      NAMES ${module}
      PATHS ${TensorFlow_search_PATHS} PATH_SUFFIXES lib NO_DEFAULT_PATH
      )
    if (TensorFlow_LIBRARY_${module})
      list(APPEND TensorFlow_LIBRARY ${TensorFlow_LIBRARY_${module}})
      get_filename_component(TensorFlow_LIBRARY_PATH_${module} ${TensorFlow_LIBRARY_${module}} PATH)
      list(APPEND TensorFlow_LIBRARY_PATH ${TensorFlow_LIBRARY_PATH_${module}})
    elseif (tensorflow_FIND_REQUIRED)
      message(FATAL_ERROR 
	"Not found lib/'${module}' in '${TensorFlow_search_PATHS}' "
	"You can manually set the tensorflow install path by -DTENSORFLOW_ROOT ")
    endif ()
  endforeach ()
else (BUILD_CPP_IF AND NOT USE_TF_PYTHON_LIBS)
  message (STATUS "Disabled cpp interface build, looking for tensorflow_framework")
endif (BUILD_CPP_IF AND NOT USE_TF_PYTHON_LIBS)


# tensorflow_framework
if (NOT TensorFlowFramework_FIND_COMPONENTS)
  if (WIN32)
    set(TensorFlowFramework_FIND_COMPONENTS _pywrap_tensorflow_internal)
    set(TF_SUFFIX "")
  else ()
  set(TensorFlowFramework_FIND_COMPONENTS tensorflow_framework)
    set(TF_SUFFIX lib)
  endif ()
endif ()
# the lib
if (WIN32)
  list(APPEND TensorFlow_search_PATHS ${TENSORFLOW_ROOT}/python)
else ()
list(APPEND CMAKE_FIND_LIBRARY_SUFFIXES .so.1)
list(APPEND CMAKE_FIND_LIBRARY_SUFFIXES .so.2)
endif()
set (TensorFlowFramework_LIBRARY_PATH "")
foreach (module ${TensorFlowFramework_FIND_COMPONENTS})
  find_library(TensorFlowFramework_LIBRARY_${module}
    NAMES ${module}
    PATHS ${TensorFlow_search_PATHS} PATH_SUFFIXES ${TF_SUFFIX} NO_DEFAULT_PATH
    )
  if (TensorFlowFramework_LIBRARY_${module})
    list(APPEND TensorFlowFramework_LIBRARY ${TensorFlowFramework_LIBRARY_${module}})
    get_filename_component(TensorFlowFramework_LIBRARY_PATH_${module} ${TensorFlowFramework_LIBRARY_${module}} PATH)
    list(APPEND TensorFlowFramework_LIBRARY_PATH ${TensorFlowFramework_LIBRARY_PATH_${module}})
  elseif (tensorflow_FIND_REQUIRED)
    message(FATAL_ERROR 
      "Not found ${TF_SUFFIX}/${module} in '${TensorFlow_search_PATHS}' "
      "You can manually set the tensorflow install path by -DTENSORFLOW_ROOT ")
  endif ()
endforeach ()

# find _pywrap_tensorflow_internal and set it as tensorflow_cc
if (BUILD_CPP_IF AND USE_TF_PYTHON_LIBS)
  set(TF_SUFFIX python)
  if(WIN32)
    set(TensorFlow_FIND_COMPONENTS _pywrap_tensorflow_internal.lib)
  else ()
    set(TensorFlow_FIND_COMPONENTS _pywrap_tensorflow_internal${CMAKE_SHARED_MODULE_SUFFIX})
  endif()
  foreach (module ${TensorFlow_FIND_COMPONENTS})
    find_library(TensorFlow_LIBRARY_${module}
      NAMES ${module}
      PATHS ${TensorFlow_search_PATHS} PATH_SUFFIXES ${TF_SUFFIX} NO_DEFAULT_PATH
      )
    if (TensorFlow_LIBRARY_${module})
      list(APPEND TensorFlow_LIBRARY ${TensorFlow_LIBRARY_${module}})
      get_filename_component(TensorFlow_LIBRARY_PATH_${module} ${TensorFlow_LIBRARY_${module}} PATH)
      list(APPEND TensorFlow_LIBRARY_PATH ${TensorFlow_LIBRARY_PATH_${module}})
      set (TensorFlow_LIBRARY_tensorflow_cc ${TensorFlow_LIBRARY_${module}})
    elseif (tensorflow_FIND_REQUIRED)
      message(FATAL_ERROR 
        "Not found ${TF_SUFFIX}/${module} in '${TensorFlow_search_PATHS}' ")
    endif ()
  endforeach ()
endif()


# find protobuf header
find_path(TensorFlow_INCLUDE_DIRS_GOOGLE
  NAMES 
  google/protobuf/type.pb.h
  PATHS ${TensorFlow_search_PATHS} 
  PATH_SUFFIXES "/include"
  NO_DEFAULT_PATH
  )
  # try to find from ldd list of TF library
  # a warning is threw here, just ignore it
  # https://stackoverflow.com/a/49738486/9567349
  if ($ENV{LD_LIBRARY_PATH})
    string(REPLACE ":" ";" _LD_LIBRARY_DIRS $ENV{LD_LIBRARY_PATH})
  endif()
  file(GET_RUNTIME_DEPENDENCIES
    RESOLVED_DEPENDENCIES_VAR TensorFlow_LINKED_LIBRARIES
    UNRESOLVED_DEPENDENCIES_VAR TensorFlow_LINKED_LIBRARIES_UNRESOLVED
    LIBRARIES ${TensorFlowFramework_LIBRARY}
    POST_INCLUDE_REGEXES "^.+protobuf\..+$"
    DIRECTORIES "${_LD_LIBRARY_DIRS}"
  )
  # search protobuf from linked libraries
  foreach(_lib ${TensorFlow_LINKED_LIBRARIES})
      string(REGEX MATCH "^.+protobuf\..+$" _protobuf_lib ${_lib})
      if (_protobuf_lib)
        set(Protobuf_LIBRARY ${_protobuf_lib})
        break()
      endif()
  endforeach()
if (NOT TensorFlow_INCLUDE_DIRS_GOOGLE)
  message(STATUS "Protobuf headers are not found in the directory of TensorFlow, assuming external protobuf was used to build TensorFlow")
  if (NOT Protobuf_LIBRARY)
    message(FATAL_ERROR "TensorFlow is not linked to protobuf")
  endif()
  get_filename_component(Protobuf_LIBRARY_DIRECTORY ${Protobuf_LIBRARY} DIRECTORY)
  # assume the include directory is ../include
  set(Protobuf_INCLUDE_DIR ${Protobuf_LIBRARY_DIRECTORY}/../include)
  find_package(Protobuf REQUIRED)
  set(TensorFlow_INCLUDE_DIRS_GOOGLE ${Protobuf_INCLUDE_DIRS})
endif()
list(APPEND TensorFlow_INCLUDE_DIRS ${TensorFlow_INCLUDE_DIRS_GOOGLE})

if (BUILD_CPP_IF)
  # define the output variable
  if (TensorFlow_INCLUDE_DIRS AND TensorFlow_LIBRARY AND TensorFlowFramework_LIBRARY)
    set(TensorFlow_FOUND TRUE)
  else ()
    set(TensorFlow_FOUND FALSE)
  endif ()
else (BUILD_CPP_IF)
  if (TensorFlow_INCLUDE_DIRS AND TensorFlowFramework_LIBRARY)
    set(TensorFlow_FOUND TRUE)
  else ()
    set(TensorFlow_FOUND FALSE)
  endif ()
endif (BUILD_CPP_IF)

# detect TensorFlow version
try_run(
  TENSORFLOW_VERSION_RUN_RESULT_VAR TENSORFLOW_VERSION_COMPILE_RESULT_VAR
  ${CMAKE_CURRENT_BINARY_DIR}/tf_version
  "${CMAKE_CURRENT_LIST_DIR}/tf_version.cpp"
  CMAKE_FLAGS "-DINCLUDE_DIRECTORIES:STRING=${TensorFlow_INCLUDE_DIRS}"
  RUN_OUTPUT_VARIABLE TENSORFLOW_VERSION
  COMPILE_OUTPUT_VARIABLE TENSORFLOW_VERSION_COMPILE_OUTPUT_VAR
)
if (NOT ${TENSORFLOW_VERSION_COMPILE_RESULT_VAR})
  message(FATAL_ERROR "Failed to compile: \n ${TENSORFLOW_VERSION_COMPILE_OUTPUT_VAR}" )
endif()
if (NOT ${TENSORFLOW_VERSION_RUN_RESULT_VAR} EQUAL "0")
  message(FATAL_ERROR "Failed to run, return code: ${TENSORFLOW_VERSION}" )
endif()

# print message
if (NOT TensorFlow_FIND_QUIETLY)
  message(STATUS "Found TensorFlow: ${TensorFlow_INCLUDE_DIRS}, ${TensorFlow_LIBRARY}, ${TensorFlowFramework_LIBRARY} "
    " in ${TensorFlow_search_PATHS} (found version \"${TENSORFLOW_VERSION}\")")
endif ()

unset(TensorFlow_search_PATHS)

if (TENSORFLOW_VERSION VERSION_GREATER_EQUAL 2.10)
  set (CMAKE_CXX_STANDARD 17)
elseif (TENSORFLOW_VERSION VERSION_GREATER_EQUAL 2.7)
  set (CMAKE_CXX_STANDARD 14)
else()
  set (CMAKE_CXX_STANDARD 11)
endif()

if (MSVC)
  # see TF .bazelrc
  add_compile_options(/W0 /Zc:__cplusplus /D_USE_MATH_DEFINES /d2ReducedOptimizeHugeFunctions)
  set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS TRUE)
endif()
if (TENSORFLOW_VERSION VERSION_GREATER_EQUAL 2.4 AND MSVC)
  # see TF 2.4 release notes
  add_compile_options(/Zc:preprocessor)
endif()

set(OP_CXX_ABI 0)
# auto op_cxx_abi
if(MSVC OR APPLE)
  # skip on windows or osx
  set(OP_CXX_ABI 0)
elseif (NOT DEFINED OP_CXX_ABI)
  if (TENSORFLOW_VERSION VERSION_GREATER_EQUAL 2.9) # changed by Yufan
    # TF 2.9 removes the tf_cxx11_abi_flag function, which is really bad...
    # try compiling with both 0 and 1, and see which one works
    try_compile(
      CPP_CXX_ABI_COMPILE_RESULT_VAR0
      ${CMAKE_CURRENT_BINARY_DIR}/tf_cxx_abi0
      "${CMAKE_CURRENT_LIST_DIR}/test_cxx_abi.cpp"
      LINK_LIBRARIES ${TensorFlowFramework_LIBRARY}
      CMAKE_FLAGS "-DINCLUDE_DIRECTORIES:STRING=${TensorFlow_INCLUDE_DIRS}"
      COMPILE_DEFINITIONS -D_GLIBCXX_USE_CXX11_ABI=0
      )
    try_compile(
      CPP_CXX_ABI_COMPILE_RESULT_VAR1
      ${CMAKE_CURRENT_BINARY_DIR}/tf_cxx_abi1
      "${CMAKE_CURRENT_LIST_DIR}/test_cxx_abi.cpp"
      LINK_LIBRARIES ${TensorFlowFramework_LIBRARY}
      CMAKE_FLAGS "-DINCLUDE_DIRECTORIES:STRING=${TensorFlow_INCLUDE_DIRS}"
      COMPILE_DEFINITIONS -D_GLIBCXX_USE_CXX11_ABI=1
      )
    if (NOT ${CPP_CXX_ABI_COMPILE_RESULT_VAR0} AND ${CPP_CXX_ABI_COMPILE_RESULT_VAR1})
      set(OP_CXX_ABI 1)
    elseif(${CPP_CXX_ABI_COMPILE_RESULT_VAR0} AND NOT ${CPP_CXX_ABI_COMPILE_RESULT_VAR1})
      set(OP_CXX_ABI 0)
    else()
      message(FATAL_ERROR "Failed to detect OP_CXX_ABI, please set it manually")
    endif()
  else()
    try_run(
      CPP_CXX_ABI_RUN_RESULT_VAR CPP_CXX_ABI_COMPILE_RESULT_VAR
      ${CMAKE_CURRENT_BINARY_DIR}/tf_cxx_abi
      "${CMAKE_CURRENT_LIST_DIR}/tf_cxx_abi.cpp"
      LINK_LIBRARIES ${TensorFlowFramework_LIBRARY}
      CMAKE_FLAGS "-DINCLUDE_DIRECTORIES:STRING=${TensorFlow_INCLUDE_DIRS}"
      RUN_OUTPUT_VARIABLE CPP_CXX_ABI
      COMPILE_OUTPUT_VARIABLE CPP_CXX_ABI_COMPILE_OUTPUT_VAR
      )
    if (NOT ${CPP_CXX_ABI_COMPILE_RESULT_VAR})
      message(FATAL_ERROR "Failed to compile: \n ${CPP_CXX_ABI_COMPILE_OUTPUT_VAR}" )
    endif()
    if (NOT ${CPP_CXX_ABI_RUN_RESULT_VAR} EQUAL "0")
      message(FATAL_ERROR "Failed to run, return code: ${CPP_CXX_ABI}" )
    endif()
    set(OP_CXX_ABI ${CPP_CXX_ABI})
  endif()
  message (STATUS "Automatically determined OP_CXX_ABI=${OP_CXX_ABI} ")
else()
  message (STATUS "User set OP_CXX_ABI=${OP_CXX_ABI} ")  
endif()    
# message the cxx_abi used during compiling
if (${OP_CXX_ABI} EQUAL 0) 
  message (STATUS "Set GLIBCXX_USE_CXX_ABI=0")
else ()
  set (OP_CXX_ABI 1)
  message (STATUS "Set GLIBCXX_USE_CXX_ABI=1")
endif ()

# set _GLIBCXX_USE_CXX11_ABI flag globally
add_definitions(-D_GLIBCXX_USE_CXX11_ABI=${OP_CXX_ABI})

# set import libraries
# https://cmake.org/cmake/help/latest/guide/importing-exporting/
# TensorFlow::tensorflow_framework

add_library(TensorFlow::tensorflow_framework SHARED IMPORTED GLOBAL)
if(WIN32)
  if(USE_TF_PYTHON_LIBS)
    string(REGEX REPLACE "[.]lib" ".pyd" _DLL_FILE ${TensorFlowFramework_LIBRARY})
  else()
    string(REGEX REPLACE "[.]lib" ".dll" _DLL_FILE ${TensorFlowFramework_LIBRARY})
  endif()
  set_target_properties(TensorFlow::tensorflow_framework PROPERTIES
               IMPORTED_IMPLIB ${TensorFlowFramework_LIBRARY}
               IMPORTED_LOCATION ${_DLL_FILE})
else()
set_property(TARGET TensorFlow::tensorflow_framework PROPERTY
             IMPORTED_LOCATION ${TensorFlowFramework_LIBRARY})
endif()
set_property(TARGET TensorFlow::tensorflow_framework PROPERTY
             CXX_STANDARD ${CMAKE_CXX_STANDARD})
target_include_directories(TensorFlow::tensorflow_framework INTERFACE ${TensorFlow_INCLUDE_DIRS})
target_compile_definitions(TensorFlow::tensorflow_framework INTERFACE
                           -D_GLIBCXX_USE_CXX11_ABI=${OP_CXX_ABI})

# TensorFlow::tensorflow_cc
if(BUILD_CPP_IF)
  add_library(TensorFlow::tensorflow_cc SHARED IMPORTED GLOBAL)
  if(WIN32)
    if(USE_TF_PYTHON_LIBS)
      string(REGEX REPLACE "[.]lib" ".pyd" _DLL_FILE ${TensorFlow_LIBRARY_tensorflow_cc})
    else()
      string(REGEX REPLACE "[.]lib" ".dll" _DLL_FILE ${TensorFlow_LIBRARY_tensorflow_cc})
    endif()
    set_target_properties(TensorFlow::tensorflow_cc PROPERTIES
                 IMPORTED_IMPLIB ${TensorFlow_LIBRARY_tensorflow_cc}
                 IMPORTED_LOCATION ${_DLL_FILE})
  else()
    set_property(TARGET TensorFlow::tensorflow_cc PROPERTY
                IMPORTED_LOCATION ${TensorFlow_LIBRARY_tensorflow_cc})
  endif()
  set_property(TARGET TensorFlow::tensorflow_cc PROPERTY
              CXX_STANDARD ${CMAKE_CXX_STANDARD})
  target_include_directories(TensorFlow::tensorflow_cc INTERFACE ${TensorFlow_INCLUDE_DIRS})
  target_compile_definitions(TensorFlow::tensorflow_cc INTERFACE
                            -D_GLIBCXX_USE_CXX11_ABI=${OP_CXX_ABI})
  if (USE_TF_PYTHON_LIBS)
    # link: libpython3.x.so
    target_link_libraries (TensorFlow::tensorflow_cc INTERFACE ${Python_LIBRARIES})
  endif()
endif()
