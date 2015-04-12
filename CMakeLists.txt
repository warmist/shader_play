cmake_minimum_required (VERSION 2.6)
project(shader_play)

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${PROJECT_SOURCE_DIR}/cmake/")



SET(IMGUI CACHE PATH "Path to imgui")
SET(GL3W "libs/gl3w" CACHE PATH "Path to gl3w")
SET(GLFW "C:/Users/darius/Projects/glfw-3.1.1/install" CACHE PATH "Path to glfw")

find_package(OpenGL REQUIRED)
FIND_PACKAGE(Eigen3 REQUIRED)



SET(GLFW_LIBS
    optimized glfw3.lib
    debug glfw3d.lib
    )

SET(SRCS
    ${GL3W}/GL/gl3w.c
    ${IMGUI}/imgui.cpp
    src/imgui_impl_glfw_gl3.cpp
    
    src/camera.cpp
    src/trackball.cpp
    src/filesys.cpp
    src/shaders.cpp
    src/main.cpp
)
SET(HDRS
    ${GL3W}/GL/gl3w.h
    ${GL3W}/GL/glcorearb.h

    ${IMGUI}/imgui.h
    ${IMGUI}/imconfig.h
    ${IMGUI}/stb_rect_pack.h
    ${IMGUI}/stb_textedit.h
    ${IMGUI}/stb_truetype.h

    src/imgui_impl_glfw_gl3.h
    
    src/camera.h
    src/trackball.h
    src/filesys.h
    src/shaders.h
)

INCLUDE_DIRECTORIES(src)
INCLUDE_DIRECTORIES(${IMGUI})
INCLUDE_DIRECTORIES(${GL3W})
INCLUDE_DIRECTORIES(${GLFW}/include)
INCLUDE_DIRECTORIES(${EIGEN3_INCLUDE_DIR})

link_directories(${GLFW}/lib)
ADD_EXECUTABLE(shay_play ${SRCS} ${HDRS})
TARGET_LINK_LIBRARIES(shay_play ${GLFW_LIBS} ${OPENGL_gl_LIBRARY} ${OPENGL_glu_LIBRARY})


