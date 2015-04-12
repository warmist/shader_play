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
            ret.uniforms.push_back(line);
        }
    }
    return ret;
}
uniform parse_uniform(const std::string& line)
{
    uniform ret;
    std::stringstream ss(line);
    std::string token;
    ss >> token;//uniform
    ss >> token;
    if (token == "float")
    {
        ret.data.f = 0;
        ret.type = uniform_type::t_float;
    }
    else if (token == "vec3")
    {
        ret.data.f3[0] = 0;
        ret.data.f3[1] = 0;
        ret.data.f3[2] = 0;
        ret.type = uniform_type::t_vec3;
    }
    else
        return ret; //unsupported type
    ss >> token;
    ret.name = token.substr(0,token.size()-1);
    if (token.substr(0, 4) == "eng_")
    {
        ret.id = 0;
        return ret;//built-in uniform
    }
    if (ss >> token)
    {
        if (token == "//!norm" && ret.type == uniform_type::t_vec3)
            ret.type = uniform_type::t_vec3_norm;
        if (token == "//!clamp" && ret.type == uniform_type::t_vec3)
            ret.type = uniform_type::t_vec3_clamp;
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
std::string load_shader(const std::string& path)
{
    std::fstream fs(path);
    std::string ret;
    std::string line;
    const std::string INCLUDE = "//!include";
    int line_counter = 0;
    while (std::getline(fs, line))
    {
        std::stringstream ss(line);
        std::string token;
        ss >> token;
        if (token == INCLUDE)
        {
            ss >> token;
            ret += load_shader(token);
            ret += "\n#line ";
            ret += std::to_string(line_counter + 1);
            ret += "\n";
        }
        else
        {
            ret += line;
            ret += "\n";
        }
    }
    return ret;
}
void init_uniforms(program& p, const std::vector<shader_info>& prog_shaders)
{
    typedef std::map<std::string, uniform> uniform_map_type;
    uniform_map_type uniform_map;
    for (const auto& shader:prog_shaders)
    {
        for (const auto& u : shader.sm.uniforms)
        {
            uniform p = parse_uniform(u);
            if (p.name == "")
                continue;//TODO: throw error?
            if (p.id == 0)
                continue;//skip built-ins
            //TODO: check if name already exists but clashes
            uniform_map[p.name] = p;
        }
    }
    for (const auto& u : uniform_map)
    {
        p.uniforms.push_back(u.second);
    }
    for (auto& u : p.uniforms)
    {
        u.id=glGetUniformLocation(p.id, u.name.c_str());
        //TODO: check id here;
    }
}
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
        
        std::string s = load_shader(info.s.path);
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
        //TODO: bail on error?
    }
    ret.predef_uniforms[static_cast<int>(predefined_uniforms::resolution)] = glGetUniformLocation(ret.id, "eng_resolution");
    ret.predef_uniforms[static_cast<int>(predefined_uniforms::time)] = glGetUniformLocation(ret.id, "eng_time");
    ret.predef_uniforms[static_cast<int>(predefined_uniforms::mouse)] = glGetUniformLocation(ret.id, "eng_mouse");
    ret.predef_uniforms[static_cast<int>(predefined_uniforms::projection)] = glGetUniformLocation(ret.id, "eng_projection");
    ret.predef_uniforms[static_cast<int>(predefined_uniforms::modelview)] = glGetUniformLocation(ret.id, "eng_modelview");
    ret.predef_uniforms[static_cast<int>(predefined_uniforms::projection_inv)] = glGetUniformLocation(ret.id, "eng_projection_inv");
    ret.predef_uniforms[static_cast<int>(predefined_uniforms::modelview_inv)] = glGetUniformLocation(ret.id, "eng_modelview_inv");
    
    init_uniforms(ret, prog_shaders);
    return ret;
}

std::vector<program> enum_programs()
{
    auto shaders = enum_shaders();
    typedef std::map<std::string, std::vector<shader_info>> prog_info_map;
    typedef std::map<std::string, uniform> uniform_map_type;
    prog_info_map program_map;
    uniform_map_type uniform_map;
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
void free_programs(std::vector<program>& programs)
{
    for (auto p : programs)
    {
        for (auto s : p.shaders)
        {
            glDeleteShader(s.id);
        }
        glDeleteProgram(p.id);
    }
}
void update_programs(std::vector<program>& programs)//FIXME: something smarter would be nice
{
    std::vector<program> p = enum_programs();
    for (const auto& prog : programs) 
    {
        for (auto& prog2 : p)
        {
            if (prog.name == prog2.name)
            {
                for (const auto&u : prog.uniforms)
                {
                    for (auto&u2 : prog2.uniforms)
                    {
                        if (u.name == u2.name)
                        {
                            u2.data = u.data;
                        }
                    }
                }
            }
        }
    }
    programs.swap(p); 
}