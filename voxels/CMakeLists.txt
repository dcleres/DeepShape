cmake_minimum_required(VERSION 2.8)
set (CMAKE_CXX_STANDARD 11)

project(voxelizer CXX)

find_package(PkgConfig) # pkg_check_modules

find_package(Boost COMPONENTS atomic thread date_time filesystem system unit_test_framework REQUIRED)

if(Boost_FOUND)
	include_directories(${Boost_INCLUDE_DIR})
else()
	message(FATAL_ERROR "Boost is required by Voxelizer")
endif()

if(PKG_CONFIG_FOUND)
  pkg_check_modules(FCL fcl)
  # check to see if the pkg is installed under the libccd name
  if(NOT FCL_FOUND)
    pkg_check_modules(FCL libfcl)
  endif()
endif()

if(NOT FCL_FOUND)
    # if pkfconfig is not installed, then fall back on more fragile detection
    # of ccd
    find_path(FCL_INCLUDE_DIRS collision.h
        PATH_SUFFIXES fcl)
    find_path(FCL_LIBRARY_DIRS
        ${CMAKE_SHARED_LIBRARY_PREFIX}fcl${CMAKE_SHARED_LIBRARY_SUFFIX})
    if(FCL_INCLUDE_DIRS AND FCL_LIBRARY_DIRS)
        set(FCL_LIBRARIES ${CMAKE_SHARED_LIBRARY_PREFIX}fcl${CMAKE_SHARED_LIBRARY_SUFFIX})
    else()
        message(FATAL_ERROR "Libfcl is required by Voxelizer")
    endif()
endif()
include_directories(${FCL_INCLUDE_DIRS})
link_directories(${FCL_LIBRARY_DIRS})

find_package(ASSIMP)
if(NOT ASSIMP_FOUND)
  pkg_check_modules(ASSIMP assimp)
endif()

if( ASSIMP_FOUND )
  message(STATUS "Found assimp version ${ASSIMP_VERSION}, ${ASSIMP_PACKAGE_VERSION}, ${ASSIMP_INCLUDE_DIRS}")
  # For older versions of libassimp2, 
  # like the one in Ubuntu 12.04 
  set(CMAKE_REQUIRED_LIBRARIES assimp) 
  find_path(ASSIMP_LIBRARY_DIRS
        ${CMAKE_SHARED_LIBRARY_PREFIX}assimp${CMAKE_SHARED_LIBRARY_SUFFIX})
  if(ASSIMP_LIBRARY_DIRS)
      #set(ASSIMP_LIBRARIES ${CMAKE_SHARED_LIBRARY_PREFIX}assimp${CMAKE_SHARED_LIBRARY_SUFFIX})
      message(STATUS "Assimp library : " ${ASSIMP_LIBRARIES}) 
  else()
      message(FATAL_ERROR "Libassimp is required by Voxelizer")
  endif()
  if( ${ASSIMP_VERSION} STRGREATER "2.0.0" )
    set(IS_ASSIMP3 1)
  endif()
endif()

# Find OpenCV, you may need to set OpenCV_DIR variable
# to the absolute path to the directory containing OpenCVConfig.cmake file
# via the command line or GUI
find_package(OpenCV REQUIRED)

# If the package has been found, several variables will
# be set, you can find the full list with descriptions
# in the OpenCVConfig.cmake file.
# Print some message showing some of them
message(STATUS "OpenCV library status:")
message(STATUS "    version: ${OpenCV_VERSION}")
message(STATUS "    libraries: ${OpenCV_LIBS}")
message(STATUS "    include path: ${OpenCV_INCLUDE_DIRS}")

if(CMAKE_VERSION VERSION_LESS "2.8.11")
    # Add OpenCV headers location to your include paths
    include_directories(${OpenCV_INCLUDE_DIRS})
    endif()

add_subdirectory(src bin)

enable_testing()
add_subdirectory(test)
