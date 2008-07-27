#  Copyright (c) 2008 Peter Kümmel 
#  
#  Permission is hereby granted, free of charge, to any person
#  obtaining a copy of this software and associated documentation
#  files (the "Software"), to deal in the Software without
#  restriction, including without limitation the rights to use,
#  copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the
#  Software is furnished to do so, subject to the following
#  conditions:
#  
#  The above copyright notice and this permission notice shall be
#  included in all copies or substantial portions of the Software.
#  
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
#  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
#  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
#  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
#  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
#  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
#  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
#  OTHER DEALINGS IN THE SOFTWARE.

cmake_minimum_required(VERSION 2.6)

project(lqt)


set(CMAKE_RUNTIME_OUTPUT_DIRECTORY  ${CMAKE_BINARY_DIR}/bin) 
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY  ${CMAKE_BINARY_DIR}/lib) 
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY  ${CMAKE_BINARY_DIR}/lib) 

find_package(Lua51 REQUIRED)

find_package(Qt4 REQUIRED)
set(QT_USE_QTCORE 1) 
set(QT_USE_QTGUI 1)
set(QT_USE_QTNETWORK 1)
set(QT_USE_QTWEBKIT 1)   
include(${QT_USE_FILE})

if(MSVC)
	set(CMAKE_SUPPRESS_REGENERATION TRUE) 
	add_definitions(-D_CRT_SECURE_NO_WARNINGS)
	set(CMAKE_DEBUG_POSTFIX d)
endif()

if(MINGW)
	set(CMAKE_SHARED_LINKER_FLAGS "-Wl,-add-stdcall-alias")
	SET(CMAKE_VERBOSE_MAKEFILE ON)
endif()


macro(lqt_files name folder)
	file(GLOB ${name}_sources ${folder}/*.cpp) 
	file(GLOB ${name}_headers ${folder}/*.hpp) 
	qt4_wrap_cpp(${name}_moc ${${name}_headers})
	qt4_automoc(${${name}_sources})
	set(${name}_src ${${name}_sources} ${${name}_moc})	
	set(${name}_h ${${name}_headers})
	source_group(generated FILES ${${name}_moc})
	project_source_group("${GROUP_CODE}" ${name}_sources ${name}_headers)
endmacro()

 
# folders in the msvc projects 
# mode==flat  : headers and sources not in folders 
# mode==split : standard behavior of cmake, split headers and sources 
# mode==<other values> : code is in this folder 
macro(project_source_group mode sources headers) 
	if(${mode} MATCHES "flat") 
		source_group("Source Files" Files) 
		source_group("Header Files" Files) 
		source_group("cmake" FILES CMakeLists.txt) 
	else() 
		if(NOT ${mode} MATCHES "split") 
			source_group("${mode}" FILES ${${sources}} ${${headers}}) 
		endif() 
	endif() 
endmacro()
set(GROUP_CODE "Source Files")


add_subdirectory(cpptoxml)


macro(build_qt_lib_binding BIND)

	# hardcoded in generator.lua
	set (LQT_GEN_DIR ${BIND}_src)
	file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/${LQT_GEN_DIR})

	set (BINDING_SRC ${LQT_GEN_DIR}/${BIND}_merged_build.cpp)
	set_source_files_properties(${BINDING_SRC} PROPERTIES  GENERATED TRUE)

	if (UNIX)
		set (PP_CONFIG ${CMAKE_SOURCE_DIR}/cpptoxml/parser/rpp/pp-qt-configuration)
	else()
		set (PP_CONFIG ${CMAKE_SOURCE_DIR}/cpptoxml/parser/rpp/pp-qt-configuration-win)
	endif()

	set (GEN_XML ${LQT_GEN_DIR}/${BIND}.xml)
	add_custom_target(generate_xml_${BIND} 	COMMAND cpptoxml 
							${BIND} 
							-C ${PP_CONFIG}
							-I ${QT_INCLUDE_DIR} 
							-o ${GEN_XML}
						COMMENT "Generating XML: running cpptoxml on ${BIND} "
						VERBATIM)


	add_custom_target(generate_cpp_${BIND}  COMMAND cmake -E copy_directory ${CMAKE_SOURCE_DIR}/common ${LQT_GEN_DIR}
						COMMAND lua 
							"${CMAKE_SOURCE_DIR}/generator/generator.lua" 
							${GEN_XML} 
							-i ${BIND} -i lqt_qt.hpp 
							-n ${BIND} 
							-t ${CMAKE_SOURCE_DIR}/generator/types.lua 
							-t ${CMAKE_SOURCE_DIR}/generator/qtypes.lua 
							-f ${CMAKE_SOURCE_DIR}/generator/qt_internal.lua
						COMMENT "Generating binding code with Lua"
						VERBATIM)


	file(GLOB COMMON_src ${CMAKE_SOURCE_DIR}/common/*.cpp) 
	file(GLOB COMMON_h ${CMAKE_SOURCE_DIR}/common/*.hpp) 
	include_directories(${CMAKE_SOURCE_DIR}/common ${LUA_INCLUDE_DIR} ${QT_INCLUDES})

	add_library(lqt_${BIND} SHARED ${BINDING_SRC} ${COMMON_src} ${COMMON_h})
	target_link_libraries(lqt_${BIND} ${QT_LIBRARIES} ${LUA_LIBRARY})		

	add_dependencies(generate_xml_${BIND}  cpptoxml)		
	add_dependencies(generate_cpp_${BIND}  generate_xml_${BIND} )
	add_dependencies(lqt_${BIND} generate_cpp_${BIND} )
endmacro()


build_qt_lib_binding(QtCore)
build_qt_lib_binding(QtGui)
build_qt_lib_binding(QtNetwork)
build_qt_lib_binding(QtWebKit)

