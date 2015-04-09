#pragma once

#include <string>
#include <vector>

#include <GL/gl3w.h>
#include <GLFW/glfw3.h>
enum class predefined_uniforms{
    resolution,time,last
};
struct prog_status{
    GLint result;
    std::vector<char> log;
};
struct shader{
    std::string path;
    std::string name;

    GLuint id = -1;
    GLuint type = -1;
    std::string type_name;//TODO: maybe a function here?

    prog_status status;

    
};

struct program{
    std::string name;

    GLuint id = -1;
    std::vector<shader> shaders;
    //shader tess; //TODO: maybe support these too?
    prog_status status;

    GLint predef_uniforms[static_cast<int>(predefined_uniforms::last)];
    GLint get_uniform(predefined_uniforms u){
        return predef_uniforms[static_cast<int>(u)];
    }
};

std::vector<program> enum_programs();
