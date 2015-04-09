#include "shaders.h"
#include "filesys.h"

#include <fstream>
#include <sstream>
#include <map>
struct shader_meta_info
{
    //std::vector<uniform> uniforms;
    std::vector<std::string> uniforms;
    std::string program; //TODO: might be more than one
    std::string type;
    GLuint gl_type;
};
GLuint get_gl_shader_type(const std::string& type)
{
    if (type == "fragment")
        return GL_FRAGMENT_SHADER;
    if (type == "vertex")
        return GL_VERTEX_SHADER;
    if (type == "geometry")
        return GL_GEOMETRY_SHADER;
    //TODO: maybe support tesselation shaders
    return 0;
}
shader_meta_info extract_info(const std::string& path)
{
    shader_meta_info ret;
    std::fstream fs(path);
    std::string line;
    const std::string PROGNAME = "//!program";
    while (std::getline(fs, line))
    {
        std::stringstream ss(line);
        std::string token;
        ss >> token;
        if (token == PROGNAME)
        {
            if(!(ss >> token)) continue; //TODO: throw? error here
            ret.program = token;
            if (!(ss >> token)) continue; //TODO: throw? error here
            ret.type = token;
            ret.gl_type = get_gl_shader_type(ret.type);
            if (!ret.gl_type) continue; //TODO: throw? error here

        }
        if (token == "uniform")
        {
            ret.uniforms.push_back(token);
        }
    }
    return ret;
}
std::vector<shader> enum_shaders()
{
    auto file_list = enum_files("shaders/*.glsl");
    std::vector<shader> ret;
    for (auto f : file_list)
    {
        shader s;
        s.path = "shaders/" + f;
        s.name = f;
        ret.push_back(s);
    }
    return ret;
}

struct shader_info{
    shader s;
    shader_meta_info sm;
};

program init_program(const std::vector<shader_info>& prog_shaders,const std::string& name)
{
    program ret;
    ret.name = name;
    ret.id = glCreateProgram();
    if (ret.id == 0);//TODO: error
    for (const auto& info : prog_shaders)
    {
        const shader& ts = info.s;
        GLuint s_id = glCreateShader(info.sm.gl_type);
        std::fstream fs(info.s.path);

        std::istreambuf_iterator<char> eos;
        std::string s(std::istreambuf_iterator<char>(fs), eos);
        const char *p = s.c_str();
        const GLint l = s.length();

        ret.shaders.push_back(ts);
        shader &tmp_s = ret.shaders.back();
        tmp_s.id = s_id;
        tmp_s.type_name = info.sm.type;

        int InfoLogLength;

        glShaderSource(s_id, 1, &p, &l);
        glCompileShader(s_id);
        // Check Shader
        glGetShaderiv(s_id, GL_COMPILE_STATUS, &tmp_s.status.result);
        glGetShaderiv(s_id, GL_INFO_LOG_LENGTH, &InfoLogLength);
        tmp_s.status.log.resize(InfoLogLength+1);
        glGetShaderInfoLog(s_id, InfoLogLength, NULL, &tmp_s.status.log[0]);

        glAttachShader(ret.id, s_id);
        
        
    }
    glLinkProgram(ret.id);
    {
        int InfoLogLength;
        glGetProgramiv(ret.id, GL_LINK_STATUS, &ret.status.result);

        glGetProgramiv(ret.id, GL_INFO_LOG_LENGTH, &InfoLogLength);
        ret.status.log.resize(InfoLogLength + 1);
        glGetProgramInfoLog(ret.id, InfoLogLength, NULL, &ret.status.log[0]);
    }
    ret.predef_uniforms[static_cast<int>(predefined_uniforms::resolution)] = glGetUniformLocation(ret.id, "eng_resolution");
    ret.predef_uniforms[static_cast<int>(predefined_uniforms::time)] = glGetUniformLocation(ret.id, "eng_time");
    //TODO: error check here
    return ret;
}

std::vector<program> enum_programs()
{
    auto shaders = enum_shaders();
    typedef std::map<std::string, std::vector<shader_info>> prog_info_map;
    prog_info_map program_map;
    for (const shader& s : shaders)
    {
        shader_meta_info info = extract_info(s.path);
        if (info.program == "")//TODO: throw error here?
            continue;
        shader_info si;
        si.s = s;
        si.sm = info;
        program_map[info.program].push_back(si);
    }
    std::vector<program> ret;
    for (prog_info_map::iterator it = program_map.begin(); it != program_map.end(); it++)
    {
        ret.push_back(init_program(it->second, it->first));
    }
    return ret;
}