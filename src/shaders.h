#pragma once

#include <string>
#include <vector>

#include <GL/gl3w.h>
#include <GLFW/glfw3.h>
enum class predefined_uniforms{
    resolution, time, mouse, projection, modelview, projection_inv, modelview_inv, last_frame, last
};
struct prog_status{
    GLint result;
    std::string log;
};
struct shader{
    std::string path;
    std::string name;

    std::string program; //TODO: duplication with meta program

    GLuint type = -1;
    std::string type_name;//TODO: maybe a function here?

    prog_status status;
};
enum class uniform_type{
    t_float,t_float_clamp,t_vec3,t_vec3_norm,t_vec3_clamp,t_int,t_float_angle,t_vec3_color, last
};
struct uniform{
    GLuint id = -1;

    std::string name;
    uniform_type type;

    union{
        float f;
        float f3[3];
		int i;
    } data;
	union{
		float f;
		int i;
	} min;
	bool has_min = false;
	union {
		float f;
		int i;
	} max;
	bool has_max = false;
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
    std::vector<uniform> uniforms;
};

std::vector<program> enum_programs();
void free_programs(std::vector<program>& programs);
void update_programs(std::vector<program>& programs);
