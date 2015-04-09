cmake_minimum_required (VERSION 2.6)
project(shader_play)

SET(IMGUI CACHE PATH "Path to imgui")
SET(GL3W "libs/gl3w" CACHE PATH "Path to gl3w")
SET(GLFW "C:/Users/darius/Projects/glfw-3.1.1/install" CACHE PATH "Path to glfw")

find_package(OpenGL REQUIRED)




SET(GLFW_LIBS
    optimized glfw3.lib
    debug glfw3d.lib
    )

SET(SRCS
    ${GL3W}/GL/gl3w.c
    ${IMGUI}/imgui.cpp
    src/imgui_impl_glfw_gl3.cpp

    src/filesys.cpp
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

    src/filesys.h
)

INCLUDE_DIRECTORIES(src)
INCLUDE_DIRECTORIES(${IMGUI})
INCLUDE_DIRECTORIES(${GL3W})
INCLUDE_DIRECTORIES(${GLFW}/include)


link_directories(${GLFW}/lib)
ADD_EXECUTABLE(shay_play ${SRCS} ${HDRS})
TARGET_LINK_LIBRARIES(shay_play ${GLFW_LIBS} ${OPENGL_gl_LIBRARY} ${OPENGL_glu_LIBRARY})

