if (EXISTS ${CMAKE_SOURCE_DIR}/${CMAKE_PROJECT_NAME}.cmake)
  include (${CMAKE_SOURCE_DIR}/${CMAKE_PROJECT_NAME}.cmake)
endif ()

# prevent build in source directory
if ("${CMAKE_BINARY_DIR}" STREQUAL "${CMAKE_SOURCE_DIR}")
    message (SEND_ERROR "Building in the source directory is not supported.")
    message (FATAL_ERROR "Please remove the created \"CMakeCache.txt\" file, the \"CMakeFiles\" directory and create a build directory and call \"${CMAKE_COMMAND} <path to the sources>\".")
endif ("${CMAKE_BINARY_DIR}" STREQUAL "${CMAKE_SOURCE_DIR}")

# allow only Debug and Release builds
set (CMAKE_CONFIGURATION_TYPES "Debug;Release" CACHE STRING "")
mark_as_advanced (CMAKE_CONFIGURATION_TYPES)

# set Debus as default build target
if (NOT CMAKE_BUILD_TYPE)
  set (CMAKE_BUILD_TYPE Debug CACHE STRING
      "Choose the type of build, options are: Debug, Release."
      FORCE)
endif ()

# create our output directroy
if (NOT EXISTS ${CMAKE_BINARY_DIR}/Build)
  file (MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/Build)
endif ()

# read version from file
macro (acg_get_version)
    if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${ARGN}/VERSION")
      file (READ "${CMAKE_CURRENT_SOURCE_DIR}/${ARGN}/VERSION" _file)
    else ()
      file (READ "${CMAKE_CURRENT_SOURCE_DIR}/VERSION" _file)
    endif ()

    string (
        REGEX REPLACE
        "^.*ID=([^\n]*).*$" "\\1"
        _id ${_file}
    )
    string (
        REGEX REPLACE
        "^.*VERSION=([^\n]*).*$" "\\1"
        _version ${_file}
    )
    string (
        REGEX REPLACE
        "^.*MAJOR=([^\n]*).*$" "\\1"
        _major ${_file}
    )
    string (
        REGEX REPLACE
        "^.*MINOR=([^\n]*).*$" "\\1"
        _minor ${_file}
    )
    string (
        REGEX REPLACE
        "^.*PATCH=([^\n]*).*$" "\\1"
        _patch ${_file}
    )

    set (${_id}_VERSION ${_version})
    set (${_id}_VERSION_MAJOR ${_major})
    set (${_id}_VERSION_MINOR ${_minor})
    set (${_id}_VERSION_PATCH ${_patch})
endmacro ()


# set directory structures for the different platforms
if (CMAKE_HOST_SYSTEM_NAME MATCHES Windows)
  set (ACG_PROJECT_DATADIR ".")
  set (ACG_PROJECT_LIBDIR "lib")
  set (ACG_PROJECT_BINDIR ".")
  set (ACG_PROJECT_PLUGINDIR "Plugins")
  if (NOT EXISTS ${CMAKE_BINARY_DIR}/Build/${ACG_PROJECT_LIBDIR})
    file (MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/Build/${ACG_PROJECT_LIBDIR})
  endif ()
elseif (APPLE)
  set (ACG_PROJECT_DATADIR "share/${CMAKE_PROJECT_NAME}")
  set (ACG_PROJECT_LIBDIR "lib${LIB_SUFFIX}")
  set (CMAKE_LIBRARY_OUTPUT_DIR "${CMAKE_BINARY_DIR}/Build/${ACG_PROJECT_LIBDIR}")
  set (ACG_PROJECT_PLUGINDIR "${ACG_PROJECT_LIBDIR}/plugins")
  set (ACG_PROJECT_BINDIR "bin")
else ()
  set (ACG_PROJECT_DATADIR "share/${CMAKE_PROJECT_NAME}")
  set (ACG_PROJECT_LIBDIR "lib${LIB_SUFFIX}")
  set (ACG_PROJECT_PLUGINDIR "${ACG_PROJECT_LIBDIR}/plugins")
  set (ACG_PROJECT_BINDIR "bin")
endif ()

if( NOT APPLE )
  # check 64 bit
  if( CMAKE_SIZEOF_VOID_P MATCHES 4 )
    set( HAVE_64_BIT 0 )
  else( CMAKE_SIZEOF_VOID_P MATCHES 4 )
    set( HAVE_64_BIT 1 )
  endif( CMAKE_SIZEOF_VOID_P MATCHES 4 )
endif (  NOT APPLE )

# allow a project to modify the directories
if (COMMAND acg_modify_project_dirs)
  acg_modify_project_dirs ()
endif ()

if (NOT EXISTS ${CMAKE_BINARY_DIR}/Build/${ACG_PROJECT_DATADIR})
 file (MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/Build/${ACG_PROJECT_DATADIR})
endif ()


# sets default build properties
macro (acg_set_target_props target)
  if (WIN32)
    set_target_properties (
      ${target} PROPERTIES
      BUILD_WITH_INSTALL_RPATH 1
      SKIP_BUILD_RPATH 0
    )
  elseif (APPLE AND NOT ACG_PROJECT_MACOS_BUNDLE)
  if (NOT (CMAKE_MAJOR_VERSION  LESS 3) )
      # save rpath
      set_target_properties (
        ${target} PROPERTIES
        INSTALL_RPATH "@executable_path/../${ACG_PROJECT_LIBDIR}"
        MACOSX_RPATH 1
        #BUILD_WITH_INSTALL_RPATH 1
        SKIP_BUILD_RPATH 0
      )  
    else()
      # save rpath via install name dir
      set_target_properties (
        ${target} PROPERTIES
        INSTALL_NAME_DIR "@executable_path/../${ACG_PROJECT_LIBDIR}"
        #BUILD_WITH_INSTALL_RPATH 1
        SKIP_BUILD_RPATH 0
      ) 
    endif(NOT (CMAKE_MAJOR_VERSION  LESS 3))
  elseif (NOT APPLE)

    set_target_properties (
      ${target} PROPERTIES
      INSTALL_RPATH "$ORIGIN/../${ACG_PROJECT_LIBDIR}"
      BUILD_WITH_INSTALL_RPATH 1
      SKIP_BUILD_RPATH 0
      RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/Build/${ACG_PROJECT_BINDIR}"
      LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/Build/${ACG_PROJECT_LIBDIR}"
    )
  endif ()
endmacro ()

include (AddFileDependencies)
include (ACGCompiler)

# define INCLUDE_TEMPLATES for everything we build
add_definitions (-DINCLUDE_TEMPLATES)

#unset cached qt variables which are set by all qt versions. version is the major number of the qt version (e.g. 4 or 5, not 4.8)
macro (acg_unset_qt_shared_variables version)
  if (ACG_INTERNAL_QT_LAST_VERSION)
    if (NOT ${ACG_INTERNAL_QT_LAST_VERSION} EQUAL ${version})
      unset(QT_BINARY_DIR)
      unset(QT_PLUGINS_DIR)
      unset(ACG_INTERNAL_QT_LAST_VERSION)
    endif()
  endif()
  set (ACG_INTERNAL_QT_LAST_VERSION "${version}" CACHE INTERNAL "Qt Version, which was used on the last time")
endmacro()

# look for selected qt dependencies
macro (acg_qt4)
  if (NOT QT4_FOUND)
    acg_unset_qt_shared_variables(4)
    find_package (Qt4 COMPONENTS QtCore QtGui ${ARGN})

    set (QT_USE_QTOPENGL 1)
    set (QT_USE_QTNETWORK 1)
    set (QT_USE_QTSCRIPT 1)
    set (QT_USE_QTSQL 1)
    set (QT_USE_QTXML 1)
    set (QT_USE_QTXMLPATTERNS 1)
    set (QT_USE_QTHELP 1)
    set (QT_USE_QTWEBKIT 1)
    set (QT_USE_QTUITOOLS 1)

    include (${QT_USE_FILE})
  endif ()
endmacro ()

macro (acg_qt5)

   if(POLICY CMP0020)
     # Automatically link Qt executables to qtmain target on Windows
     cmake_policy(SET CMP0020 NEW)
   endif(POLICY CMP0020)
  #if (NOT QT5_FOUND)

    #set (QT_MIN_VERSION ${ARGN})

  #try to find qt5 automatically
  #for custom installation of qt5, dont use any of these variables
  set (QT5_INSTALL_PATH "" CACHE PATH "Path to Qt5 directory which contains lib and include folder")
  if (EXISTS "${QT5_INSTALL_PATH}")
    set (CMAKE_PREFIX_PATH "${CMAKE_PREFIX_PATH};${QT5_INSTALL_PATH}")
    set (QT5_INSTALL_PATH_EXISTS TRUE)
  endif()
  
  
    
    find_package (Qt5Core QUIET)
     
    #find WINDOWS_SDK to avoid qt error. This must be done BEFORE Qt5Widgets is searched
    if (Qt5Core_FOUND AND WIN32)    
      string(REGEX REPLACE "^([0-9]+)\\.[0-9]+\\.[0-9]+.*" "\\1" QT_VERSION_MAJOR "${Qt5Core_VERSION_STRING}")
      string(REGEX REPLACE "^[0-9]+\\.([0-9])+\\.[0-9]+.*" "\\1" QT_VERSION_MINOR "${Qt5Core_VERSION_STRING}")
      string(REGEX REPLACE "^[0-9]+\\.[0-9]+\\.([0-9]+).*" "\\1" QT_VERSION_PATCH "${Qt5Core_VERSION_STRING}")
    
      if ( (QT_VERSION_MAJOR EQUAL 5) AND (QT_VERSION_MINOR LESS 3 OR ( QT_VERSION_MINOR EQUAL 3 AND QT_VERSION_PATCH EQUAL 0 )) ) # for all Qt version > 5.0.0 and < 5.3.1
        #glu32.lib is needed by qt5 opengl version. it cannot find it by itself so we help qt
        #this block has to be executed, before Qt5Gui is searched, otherwise we will end up with the (not so useful) QT5 error message 
        set(WINDOWS_SDK_LIBS "COULD_NOT_FOUND" CACHE PATH "Path to the latest windows sdk libs which includes glu32.lib. Used by Qt5.")
        if (EXISTS "${WINDOWS_SDK_LIBS}\\glu32.lib")
          set (CMAKE_PREFIX_PATH "${CMAKE_PREFIX_PATH};${WINDOWS_SDK_LIBS}")
        elseif(QT5_INSTALL_PATH_EXISTS) #trying to install qt5. notify about missing sdk before the qt message comes
          message(FATAL_ERROR "Could not find glu32.lib. This is necessary for QT5 OpenGL version for windows, spleace specify glu32.lib in WINDOWS_SDK_LIB or install Qt version >= 5.3.1")
        endif()
      endif()    
    endif(Qt5Core_FOUND AND WIN32)
    
    find_package (Qt5Gui QUIET)
    find_package (Qt5OpenGL QUIET)
    

    if (Qt5Core_FOUND AND Qt5Gui_FOUND AND Qt5OpenGL_FOUND)
      set (QT5_FOUND TRUE)
    endif()
    
    if (QT5_FOUND)   
      acg_unset_qt_shared_variables(5)
    
      #set plugin dir
      list(GET Qt5Gui_PLUGINS 0 _plugin)
      if (_plugin)
        get_target_property(_plugin_full ${_plugin} LOCATION)
        get_filename_component(_plugin_dir ${_plugin_full} PATH)
      set (QT_PLUGINS_DIR "${_plugin_dir}/../" CACHE PATH "Path to the qt plugin directory")
      elseif(QT5_INSTALL_PATH_EXISTS)
        set (QT_PLUGINS_DIR "${QT5_INSTALL_PATH}/plugins/" CACHE PATH "Path to the qt plugin directory")
      elseif()
        set (QT_PLUGINS_DIR "QT_PLUGIN_DIR_NOT_FOUND" CACHE PATH "Path to the qt plugin directory")
      endif(_plugin)
      
      #set binary dir for fixupbundle
      if(QT5_INSTALL_PATH_EXISTS)
        set(_QT_BINARY_DIR "${QT5_INSTALL_PATH}/bin")
      else()
        get_target_property(_QT_BINARY_DIR ${Qt5Widgets_UIC_EXECUTABLE} LOCATION)
        get_filename_component(_QT_BINARY_DIR ${_QT_BINARY_DIR} PATH)
      endif(QT5_INSTALL_PATH_EXISTS)
      
      set (QT_BINARY_DIR "${_QT_BINARY_DIR}" CACHE PATH "Qt5 binary Directory")
      mark_as_advanced(QT_BINARY_DIR)
      
      set (CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)
  
      include_directories(${Qt5Core_INCLUDE_DIRS})
      include_directories(${Qt5Gui_INCLUDE_DIRS})
      include_directories(${Qt5OpenGL_INCLUDE_DIRS})
      add_definitions(${Qt5Core_DEFINITIONS})
      add_definitions(${Qt5Gui_DEFINITIONS})
      add_definitions(${Qt5OpenGL_DEFINITIONS})
      
      if ( NOT MSVC )
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fPIC")
      endif()

      set (QT_LIBRARIES ${Qt5Core_LIBRARIES} ${Qt5Widgets_LIBRARIES}
        ${Qt5Gui_LIBRARIES} ${Qt5OpenGL_LIBRARIES})
       
      if (MSVC)
        set (QT_LIBRARIES ${QT_LIBRARIES} ${Qt5Core_QTMAIN_LIBRARIES})
      endif()

    #add_definitions(-DQT_NO_OPENGL)

    #adding QT_NO_DEBUG to all release modes. 
    #  Note: for multi generators like msvc you cannot set this definition depending of
    #  the current build type, because it may change in the future inside the ide and not via cmake
    if (MSVC_IDE)
      set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} /DQT_NO_DEBUG")
      set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} /DQT_NO_DEBUG")
    
    set(CMAKE_C_FLAGS_MINSIZEREL "${CMAKE_C_FLAGS_RELEASE} /DQT_NO_DEBUG")
      set(CMAKE_CXX_FLAGS_MINSITEREL "${CMAKE_C_FLAGS_RELEASE} /DQT_NO_DEBUG")
    
    set(CMAKE_C_FLAGS_RELWITHDEBINFO "${CMAKE_C_FLAGS_RELEASE} /DQT_NO_DEBUG")
      set(CMAKE_CXX_FLAGS_RELWITHDEBINFO "${CMAKE_C_FLAGS_RELEASE} /DQT_NO_DEBUG")
    else(MSVC_IDE)
      if(NOT CMAKE_BUILD_TYPE STREQUAL "Debug")
        add_definitions(-DQT_NO_DEBUG)
      endif()
    endif(MSVC_IDE)

    endif ()
endmacro ()

# unsets the given variable
macro (acg_unset var)
    set (${var} "" CACHE INTERNAL "")
endmacro ()

# sets the given variable
macro (acg_set var value)
    set (${var} ${value} CACHE INTERNAL "")
endmacro ()

# test for OpenMP
macro (acg_openmp)
  if (NOT OPENMP_NOTFOUND)
    find_package(OpenMP)
    if (OPENMP_FOUND)
      set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${OpenMP_CXX_FLAGS}")
      set (CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${OpenMP_C_FLAGS}")
      add_definitions(-DUSE_OPENMP)
    else ()
      set (OPENMP_NOTFOUND 1)
    endif ()
  endif ()
endmacro ()

# test for FTGL
macro (acg_ftgl)
  find_package (Freetype)

  if (FREETYPE_FOUND)
    find_package (FTGL)

    if (FTGL_FOUND)
      add_definitions (-DUSE_FTGL)
      include_directories (${FTGL_INCLUDE_DIR} ${FREETYPE_INCLUDE_DIR_freetype2})
      set (FTGL_LIBS ${FREETYPE_LIBRARIES} ${FTGL_LIBRARIES})
    endif ()
  endif ()
endmacro ()

# append all files with extension "ext" in the "dirs" directories to "ret"
# excludes all files starting with a '.' (dot)
macro (acg_append_files ret ext)
  foreach (_dir ${ARGN})
    file (GLOB _files "${_dir}/${ext}")
    foreach (_file ${_files})
      get_filename_component (_filename ${_file} NAME)
      if (_filename MATCHES "^[.]")
	list (REMOVE_ITEM _files ${_file})
      endif ()
    endforeach ()
    list (APPEND ${ret} ${_files})
  endforeach ()
endmacro ()

# append all files with extension "ext" in the "dirs" directories and its subdirectories to "ret"
# excludes all files starting with a '.' (dot)
macro (acg_append_files_recursive ret ext)
  foreach (_dir ${ARGN})
    file (GLOB_RECURSE _files "${_dir}/${ext}")
    foreach (_file ${_files})
      get_filename_component (_filename ${_file} NAME)
      if (_filename MATCHES "^[.]")
	list (REMOVE_ITEM _files ${_file})
      endif ()
    endforeach ()
    list (APPEND ${ret} ${_files})
  endforeach ()
endmacro ()


# drop all "*T.cc" files from list
macro (acg_drop_templates list)
  foreach (_file ${${list}})
    if (_file MATCHES "T.cc$")
      list (REMOVE_ITEM ${list} ${_file})
    endif ()
  endforeach ()
endmacro ()

# generate moc targets for sources in list
macro (acg_qt4_automoc moc_SRCS)
  qt4_get_moc_flags (_moc_INCS)

  set (_matching_FILES )
  foreach (_current_FILE ${ARGN})

     get_filename_component (_abs_FILE ${_current_FILE} ABSOLUTE)
     # if "SKIP_AUTOMOC" is set to true, we will not handle this file here.
     # here. this is required to make bouic work correctly:
     # we need to add generated .cpp files to the sources (to compile them),
     # but we cannot let automoc handle them, as the .cpp files don't exist yet when
     # cmake is run for the very first time on them -> however the .cpp files might
     # exist at a later run. at that time we need to skip them, so that we don't add two
     # different rules for the same moc file
     get_source_file_property (_skip ${_abs_FILE} SKIP_AUTOMOC)

     if ( NOT _skip AND EXISTS ${_abs_FILE} )

        file (READ ${_abs_FILE} _contents)

        get_filename_component (_abs_PATH ${_abs_FILE} PATH)

        string (REGEX MATCHALL "Q_OBJECT" _match "${_contents}")
        if (_match)
            get_filename_component (_basename ${_current_FILE} NAME_WE)
            set (_header ${_abs_FILE})
            set (_moc    ${CMAKE_CURRENT_BINARY_DIR}/moc_${_basename}.cpp)

            add_custom_command (OUTPUT ${_moc}
                COMMAND ${QT_MOC_EXECUTABLE}
                ARGS ${_moc_INCS} ${_header} -o ${_moc}
                DEPENDS ${_header}
            )

            add_file_dependencies (${_abs_FILE} ${_moc})
            set (${moc_SRCS} ${${moc_SRCS}} ${_moc})
            
        endif ()
     endif ()
  endforeach ()
endmacro ()

# generate moc targets for sources in list
macro (acg_qt5_automoc moc_SRCS)
  qt5_get_moc_flags (_moc_INCS)
  
  list(REMOVE_DUPLICATES _moc_INCS)

  set (_matching_FILES )
  foreach (_current_FILE ${ARGN})

     get_filename_component (_abs_FILE ${_current_FILE} ABSOLUTE)
     # if "SKIP_AUTOMOC" is set to true, we will not handle this file here.
     # here. this is required to make bouic work correctly:
     # we need to add generated .cpp files to the sources (to compile them),
     # but we cannot let automoc handle them, as the .cpp files don't exist yet when
     # cmake is run for the very first time on them -> however the .cpp files might
     # exist at a later run. at that time we need to skip them, so that we don't add two
     # different rules for the same moc file
     get_source_file_property (_skip ${_abs_FILE} SKIP_AUTOMOC)

     if ( NOT _skip AND EXISTS ${_abs_FILE} )

        file (READ ${_abs_FILE} _contents)

        get_filename_component (_abs_PATH ${_abs_FILE} PATH)

        string (REGEX MATCHALL "Q_OBJECT" _match "${_contents}")
        if (_match)
            get_filename_component (_basename ${_current_FILE} NAME_WE)
            set (_header ${_abs_FILE})
            set (_moc    ${CMAKE_CURRENT_BINARY_DIR}/moc_${_basename}.cpp)

            add_custom_command (OUTPUT ${_moc}
                COMMAND ${QT_MOC_EXECUTABLE}
                ARGS ${_moc_INCS} ${_header} -o ${_moc}
                DEPENDS ${_header}
            )

            add_file_dependencies (${_abs_FILE} ${_moc})
            set (${moc_SRCS} ${${moc_SRCS}} ${_moc})

        endif ()
     endif ()
  endforeach ()
endmacro ()

# generate uic targets for sources in list
macro (acg_qt4_autouic uic_SRCS)

  set (_matching_FILES )
  foreach (_current_FILE ${ARGN})

     get_filename_component (_abs_FILE ${_current_FILE} ABSOLUTE)

     if ( EXISTS ${_abs_FILE} )

        file (READ ${_abs_FILE} _contents)

        get_filename_component (_abs_PATH ${_abs_FILE} PATH)

        get_filename_component (_basename ${_current_FILE} NAME_WE)
        string (REGEX REPLACE "Ui$" "" _cbasename ${_basename})
        set (_outfile ${CMAKE_CURRENT_BINARY_DIR}/ui_${_basename}.hh)
        set (_header ${_basename}.hh)
        set (_source ${_abs_PATH}/${_cbasename}.cc)
        
        add_custom_command (OUTPUT ${_outfile}
            COMMAND ${QT_UIC_EXECUTABLE}
            ARGS -o ${_outfile} ${_abs_FILE}
            DEPENDS ${_abs_FILE})

        add_file_dependencies (${_source} ${_outfile})
        set (${uic_SRCS} ${${uic_SRCS}} ${_outfile})
            
     endif ()
  endforeach ()
endmacro ()

# generate uic targets for sources in list
macro (acg_qt5_autouic uic_SRCS)

  set (_matching_FILES )
  foreach (_current_FILE ${ARGN})

     get_filename_component (_abs_FILE ${_current_FILE} ABSOLUTE)

     if ( EXISTS ${_abs_FILE} )

        file (READ ${_abs_FILE} _contents)

        get_filename_component (_abs_PATH ${_abs_FILE} PATH)

        get_filename_component (_basename ${_current_FILE} NAME_WE)
        string (REGEX REPLACE "Ui$" "" _cbasename ${_basename})
        set (_outfile ${CMAKE_CURRENT_BINARY_DIR}/ui_${_basename}.hh)
        set (_header ${_basename}.hh)
        set (_source ${_abs_PATH}/${_cbasename}.cc)

        add_custom_command (OUTPUT ${_outfile}
            COMMAND ${Qt5Widgets_UIC_EXECUTABLE}
            ARGS -o ${_outfile} ${_abs_FILE}
            MAIN_DEPENDENCY ${_abs_FILE} VERBATIM)

        add_file_dependencies (${_source} ${_outfile})
        set (${uic_SRCS} ${${uic_SRCS}} ${_outfile})

     endif ()
  endforeach ()
endmacro ()

# generate qrc targets for sources in list
macro (acg_qt4_autoqrc qrc_SRCS)

  set (_matching_FILES )
  foreach (_current_FILE ${ARGN})

     get_filename_component (_abs_FILE ${_current_FILE} ABSOLUTE)

     if ( EXISTS ${_abs_FILE} )

        file (READ ${_abs_FILE} _contents)

        get_filename_component (_abs_PATH ${_abs_FILE} PATH)

        get_filename_component (_basename ${_current_FILE} NAME_WE)
        set (_outfile ${CMAKE_CURRENT_BINARY_DIR}/qrc_${_basename}.cpp)
        
        add_custom_command (OUTPUT ${_outfile}
            COMMAND ${QT_RCC_EXECUTABLE}
            ARGS -o ${_outfile}  ${_abs_FILE}
            DEPENDS ${_abs_FILE}) 

        add_file_dependencies (${_source} ${_outfile})
        set (${qrc_SRCS} ${${qrc_SRCS}} ${_outfile})

     endif ()
  endforeach ()
endmacro ()

# get all files in directory, but ignore svn
macro (acg_get_files_in_dir ret dir)
  file (GLOB_RECURSE __files RELATIVE "${dir}" "${dir}/*")
  foreach (_file ${__files})
    if (NOT _file MATCHES ".*svn.*")
      list (APPEND ${ret} "${_file}")
    endif ()
  endforeach ()
endmacro ()

# copy the whole directory without svn files
function (acg_copy_after_build target src dst)
  acg_unset (_files)
  acg_get_files_in_dir (_files ${src})
  foreach (_file ${_files})
    add_custom_command(TARGET ${target} POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy_if_different "${src}/${_file}" "${dst}/${_file}"
    )
  endforeach ()
endfunction ()

# install the whole directory without svn files
function (acg_install_dir src dst)
  acg_unset (_files)
  acg_get_files_in_dir (_files ${src})
  foreach (_file ${_files})
    get_filename_component (_file_PATH ${_file} PATH)
    install(FILES "${src}/${_file}"
      DESTINATION "${dst}/${_file_PATH}"
    )
  endforeach ()
endfunction ()

# extended version of add_executable that also copies output to out Build directory
function (acg_add_executable _target)
  add_executable (${_target} ${ARGN})

  # set common target properties defined in common.cmake
  acg_set_target_props (${_target})

  if (WIN32 OR (APPLE AND NOT ACG_PROJECT_MACOS_BUNDLE))
    add_custom_command (TARGET ${_target} POST_BUILD
                        COMMAND ${CMAKE_COMMAND} -E
                        copy_if_different
                          $<TARGET_FILE:${_target}>
                          ${CMAKE_BINARY_DIR}/Build/${ACG_PROJECT_BINDIR}/$<TARGET_FILE_NAME:${_target}>)
  endif (WIN32 OR (APPLE AND NOT ACG_PROJECT_MACOS_BUNDLE))
  
  if (NOT ACG_PROJECT_MACOS_BUNDLE OR NOT APPLE)
    install (TARGETS ${_target} DESTINATION ${ACG_PROJECT_BINDIR})
  endif ()
endfunction ()

# extended version of add_library that also copies output to out Build directory
function (acg_add_library _target _libtype)

  if (${_libtype} STREQUAL SHAREDANDSTATIC)
    set (_type SHARED)
    if (NOT WIN32 OR MINGW)
      set (_and_static 1)
    else ()
      set (_and_static 0)
    endif ()    
  else ()
    set (_type ${_libtype})
    set (_and_static 0)
  endif ()

  add_library (${_target} ${_type} ${ARGN} )

  # set common target properties defined in common.cmake
  acg_set_target_props (${_target})

  if (_and_static)
    add_library (${_target}Static STATIC ${ARGN})

    # set common target properties defined in common.cmake
    acg_set_target_props (${_target}Static)

    set_target_properties(${_target}Static PROPERTIES OUTPUT_NAME ${_target})
    
    if (NOT APPLE)
      set_target_properties (${_target}Static PROPERTIES 
                             LIBRARY_OUTPUT_DIRECTORY "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}"
                            )
    endif ()
  endif ()

  if ( (WIN32 AND MSVC) OR (APPLE AND NOT ACG_PROJECT_MACOS_BUNDLE))
    if (${_type} STREQUAL SHARED)
      add_custom_command (TARGET ${_target} POST_BUILD
                          COMMAND ${CMAKE_COMMAND} -E
                          copy_if_different
                            $<TARGET_FILE:${_target}>
                            ${CMAKE_BINARY_DIR}/Build/${ACG_PROJECT_LIBDIR}/$<TARGET_FILE_NAME:${_target}>)
	  add_custom_command (TARGET ${_target} POST_BUILD
                          COMMAND ${CMAKE_COMMAND} -E
                          copy_if_different
                            $<TARGET_LINKER_FILE:${_target}>
                            ${CMAKE_BINARY_DIR}/Build/${ACG_PROJECT_LIBDIR}/$<TARGET_LINKER_FILE_NAME:${_target}>)
    elseif (${_type} STREQUAL MODULE)
      if (NOT EXISTS ${CMAKE_BINARY_DIR}/Build/${ACG_PROJECT_PLUGINDIR})
        file (MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/Build/${ACG_PROJECT_PLUGINDIR})
      endif ()
      add_custom_command (TARGET ${_target} POST_BUILD
                          COMMAND ${CMAKE_COMMAND} -E
                          copy_if_different
                            $<TARGET_FILE:${_target}>
                            ${CMAKE_BINARY_DIR}/Build/${ACG_PROJECT_PLUGINDIR}/$<TARGET_FILE_NAME:${_target}>)
    elseif (${_type} STREQUAL STATIC)
	  add_custom_command (TARGET ${_target} POST_BUILD
                          COMMAND ${CMAKE_COMMAND} -E
                          copy_if_different
                            $<TARGET_FILE:${_target}>
                            ${CMAKE_BINARY_DIR}/Build/${ACG_PROJECT_LIBDIR}/$<TARGET_FILE_NAME:${_target}>)
	endif()
	
	 
	# make an extra copy for windows into the binary directory
    if (${_type} STREQUAL SHARED AND WIN32)
      add_custom_command (TARGET ${_target} POST_BUILD
                          COMMAND ${CMAKE_COMMAND} -E
                          copy_if_different 
                            $<TARGET_FILE:${_target}>
                            ${CMAKE_BINARY_DIR}/Build/${ACG_PROJECT_BINDIR}/$<TARGET_FILE_NAME:${_target}>)
	endif () 
    
  endif( (WIN32 AND MSVC) OR (APPLE AND NOT ACG_PROJECT_MACOS_BUNDLE))
  
  if (_and_static)
    add_custom_command (TARGET ${_target}Static POST_BUILD
                        COMMAND ${CMAKE_COMMAND} -E
                        copy_if_different
                          $<TARGET_FILE:${_target}Static>
                          ${CMAKE_BINARY_DIR}/Build/${ACG_PROJECT_LIBDIR}/$<TARGET_FILE_NAME:${_target}Static>)

  endif ()
 

  # Block installation of libraries by setting ACG_NO_LIBRARY_INSTALL
  if ( NOT ACG_NO_LIBRARY_INSTALL ) 
    if (NOT ACG_PROJECT_MACOS_BUNDLE OR NOT APPLE)
      if (${_type} STREQUAL SHARED OR ${_type} STREQUAL STATIC )
        install (TARGETS ${_target}
                 RUNTIME DESTINATION ${ACG_PROJECT_BINDIR}
                 LIBRARY DESTINATION ${ACG_PROJECT_LIBDIR}
                 ARCHIVE DESTINATION ${ACG_PROJECT_LIBDIR})
        if (_and_static)
          install (TARGETS ${_target}Static
                   DESTINATION ${ACG_PROJECT_LIBDIR})
        endif ()
      elseif (${_type} STREQUAL MODULE)
        install (TARGETS ${_target} DESTINATION ${ACG_PROJECT_PLUGINDIR})
      endif ()
    endif ()
  endif()

endfunction ()

#generates qt translations
function (acg_add_translations _target _languages _sources)

  string (TOUPPER ${_target} _TARGET)
  # generate/use translation files
  # run with UPDATE_TRANSLATIONS set to on to build qm files
  option (UPDATE_TRANSLATIONS_${_TARGET} "Update source translation *.ts files (WARNING: make clean will delete the source .ts files! Danger!)")

  set (_new_ts_files)
  set (_ts_files)

  foreach (lang ${_languages})
    if (NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/translations/${_target}_${lang}.ts" OR UPDATE_TRANSLATIONS_${_TARGET})
      list (APPEND _new_ts_files "translations/${_target}_${lang}.ts")
    else ()
      list (APPEND _ts_files "translations/${_target}_${lang}.ts")
    endif ()
  endforeach ()


  set (_qm_files)
  if ( _new_ts_files )
    qt4_create_translation(_qm_files ${_sources} ${_new_ts_files})
  endif ()

  if ( _ts_files )
    qt4_add_translation(_qm_files2 ${_ts_files})
    list (APPEND _qm_files ${_qm_files2})
  endif ()

  # create a target for the translation files ( and object files )
  # Use this target, to update only the translations
  add_custom_target (translations_target_${_target} DEPENDS ${_qm_files})

  # Build translations with the application
  add_dependencies(${_target} translations_target_${_target} )

  if (NOT EXISTS ${CMAKE_BINARY_DIR}/Build/${ACG_PROJECT_DATADIR}/Translations)
    file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/Build/${ACG_PROJECT_DATADIR}/Translations )
  endif ()

  foreach (_qm ${_qm_files})
    get_filename_component (_qm_name "${_qm}" NAME)
    add_custom_command (TARGET translations_target_${_target} POST_BUILD
                        COMMAND ${CMAKE_COMMAND} -E
                        copy_if_different
                          ${_qm}
                          ${CMAKE_BINARY_DIR}/Build/${ACG_PROJECT_DATADIR}/Translations/${_qm_name})
  endforeach ()

  if (NOT ACG_PROJECT_MACOS_BUNDLE OR NOT APPLE)
    install (FILES ${_qm_files} DESTINATION "${ACG_PROJECT_DATADIR}/Translations")
  endif ()
endfunction ()
