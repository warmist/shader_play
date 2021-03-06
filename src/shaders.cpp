#include "shaders.h"
#include "filesys.h"

#include <fstream>
#include <sstream>
#include <map>

struct loader_context{
    int last_id = 0;
    std::map<int, std::string> filenames; //TODO: probably simple vector would work too...
};
struct shader_meta_info
{
    //std::vector<uniform> uniforms;
    std::vector<std::string> uniforms;
    std::string program; //TODO: might be more than one
    std::string type;
    GLuint gl_type;
    int filename_id;
	bool need_default_vertex = false;
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
shader_meta_info extract_info(const std::string& prog)
{
    shader_meta_info ret;
    std::stringstream fs(prog);
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
		else if (token == "//!default_vertex")
		{
			ret.need_default_vertex = true;
		}
        else if (token == "uniform")
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
	else if (token == "int")
	{
		ret.data.i = 0;
		ret.type = uniform_type::t_int;
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
	while(ss>>token)
	{
		if (token.substr(0, 2) == "//")
			token = token.substr(2, token.size() - 2);

		if (token == "!norm" && ret.type == uniform_type::t_vec3)
			ret.type = uniform_type::t_vec3_norm;
		if (token == "!clamp" && ret.type == uniform_type::t_vec3)
			ret.type = uniform_type::t_vec3_clamp;
		if (token == "!clamp" && ret.type == uniform_type::t_float)
			ret.type = uniform_type::t_float_clamp;
		if (token == "!col" && ret.type == uniform_type::t_vec3)
			ret.type = uniform_type::t_vec3_color;
		if (token == "!max")
		{
			if (ss >> token)
			{
				ret.has_max = true;
				if ((ret.type == uniform_type::t_float) || (ret.type == uniform_type::t_float_angle) || (ret.type == uniform_type::t_float_clamp)) //TODO: @TIDYUP is_float()? split into data/other type
				{
					ret.max.f = std::stof(token);
				}
				else if (ret.type == uniform_type::t_int)
				{
					ret.max.i = std::stoi(token);
				}
			}
		}
		if (token == "!min")
		{
			if (ss >> token)
			{
				ret.has_min = true;
				if ((ret.type == uniform_type::t_float) || (ret.type == uniform_type::t_float_angle) || (ret.type == uniform_type::t_float_clamp))
				{
					ret.min.f = std::stof(token);
				}
				else if (ret.type == uniform_type::t_int)
				{
					ret.min.i = std::stoi(token);
				}
			}
		}
		if (token == "!angle" && ret.type==uniform_type::t_float)
		{
			ret.type = uniform_type::t_float_angle;
		}
	}
    return ret;
}


struct shader_info{
    shader s;
    shader_meta_info sm;
};
std::string load_shader(const std::string& path,loader_context& ctx)
{
    std::fstream fs(path);
    std::string ret;
    std::string line;
    const std::string INCLUDE = "//!include";
	const std::string VERSION = "#version";
    int line_counter = 0;
    int fname_id = ctx.last_id;
    ctx.filenames[fname_id] = path;
    ctx.last_id++;
	//workaround for nvidia not likeing this when using #version

    while (std::getline(fs, line))
    {
        line_counter++;
        std::stringstream ss(line);
        std::string token;
        ss >> token;
        if (token == INCLUDE)
        {
            ss >> token;
            ret += load_shader("shaders/"+token,ctx);
            ret += "\n#line "; //restore correct line id
            ret += std::to_string(line_counter + 1);
            ret += " ";
            ret += std::to_string(fname_id);
            ret += "\n";
        }
		else if (token == VERSION)
		{
			ret += line + "\n";
			ret += "\n#line "+std::to_string(line_counter)+" ";
			ret += std::to_string(fname_id);
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
std::vector<shader> enum_shaders(loader_context& ctx)
{
    auto file_list = enum_files("shaders/*.glsl");
    std::vector<shader> ret;
    for (auto f : file_list)
    {
        shader s;
        s.path = "shaders/" + f;
        s.name = f;
        s.program = load_shader(s.path, ctx);
        ret.push_back(s);
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
void get_shader_log(shader& s,GLuint shader_id, loader_context& ctx)
{
	//TODO: ATI errors here. Should implement nvidia too
    int InfoLogLength;
    glGetShaderiv(shader_id, GL_INFO_LOG_LENGTH, &InfoLogLength);
    std::vector<char> log;
    log.resize(InfoLogLength + 1);
    
    glGetShaderInfoLog(shader_id, InfoLogLength, NULL, &log[0]);
    std::string ret;
    std::stringstream fs(log.data());
    
    std::string line;
    
    while (std::getline(fs, line))
    {
        
        std::stringstream ss(line);
        std::string token;
        ss >> token;
        if (token == "ERROR:")
        {
            
            ss >> token;
            if (token.back() == ':')
            {
                int file_id = std::stoi(token);
                if (!ctx.filenames.count(file_id))
                {
                    ret += line;
                    continue;
                }
                else
                {
                    ret += "ERROR: ";
                    ret += ctx.filenames[file_id];
                    ret += token.substr(token.find(":"));
                    while (ss >> token)
                        ret += " " + token;
                    ret += "\n";
                }
            }
        }
        else
        {
            ret += line;
            ret += "\n";
        }
    }
    s.status.log = ret;
}
program init_program(const std::vector<shader_info>& prog_shaders, const std::string& name, loader_context& ctx)
{
    program ret;
    ret.name = name;
    ret.id = glCreateProgram();
    if (ret.id == 0);//TODO: error
	std::vector<GLuint> shader_handles;
    for (const auto& info : prog_shaders)
    {
        const shader& ts = info.s;
        GLuint s_id = glCreateShader(info.sm.gl_type);

        const char *p = ts.program.c_str();
        const GLint l = ts.program.length();

        ret.shaders.push_back(ts);
        shader &tmp_s = ret.shaders.back();
       
		shader_handles.push_back(s_id);
        tmp_s.type_name = info.sm.type;

        

        glShaderSource(s_id, 1, &p, &l);
        glCompileShader(s_id);
        // Check Shader
        glGetShaderiv(s_id, GL_COMPILE_STATUS, &tmp_s.status.result);
        get_shader_log(tmp_s,s_id, ctx);

        glAttachShader(ret.id, s_id);
        
        
    }
    glLinkProgram(ret.id);
    {
        int InfoLogLength;
        glGetProgramiv(ret.id, GL_LINK_STATUS, &ret.status.result);

        glGetProgramiv(ret.id, GL_INFO_LOG_LENGTH, &InfoLogLength);
        std::vector<char> log;
        log.resize(InfoLogLength + 1);
        glGetProgramInfoLog(ret.id, InfoLogLength, NULL, log.data());
        ret.status.log = std::string(log.data(), log.size()); //TODO: a bit ugly here
        //TODO: bail on error?
    }
	for (auto s : shader_handles)
	{
		glDeleteShader(s);
	}
    ret.predef_uniforms[static_cast<int>(predefined_uniforms::resolution)] = glGetUniformLocation(ret.id, "eng_resolution");
    ret.predef_uniforms[static_cast<int>(predefined_uniforms::time)] = glGetUniformLocation(ret.id, "eng_time");
    ret.predef_uniforms[static_cast<int>(predefined_uniforms::mouse)] = glGetUniformLocation(ret.id, "eng_mouse");
    ret.predef_uniforms[static_cast<int>(predefined_uniforms::projection)] = glGetUniformLocation(ret.id, "eng_projection");
    ret.predef_uniforms[static_cast<int>(predefined_uniforms::modelview)] = glGetUniformLocation(ret.id, "eng_modelview");
    ret.predef_uniforms[static_cast<int>(predefined_uniforms::projection_inv)] = glGetUniformLocation(ret.id, "eng_projection_inv");
    ret.predef_uniforms[static_cast<int>(predefined_uniforms::modelview_inv)] = glGetUniformLocation(ret.id, "eng_modelview_inv");
    ret.predef_uniforms[static_cast<int>(predefined_uniforms::last_frame)] = glGetUniformLocation(ret.id, "eng_last_frame");
    
    init_uniforms(ret, prog_shaders);
    return ret;
}
shader_info generate_vertex_shader(shader_meta_info sm)
{
	shader_info ret;
	ret.s.path = "generated";
	ret.s.name = "generated";
	ret.s.type = GL_VERTEX_SHADER;
	ret.s.type_name = "vertex";
	ret.sm.gl_type = GL_VERTEX_SHADER;
	ret.sm.type = "vertex";
	ret.sm.program = R"(
	#version 330

	layout(location = 0) in vec3 vertexPosition_modelspace;

	varying vec3 pos;
	void main()
	{
		gl_Position.xyz = vertexPosition_modelspace;
		gl_Position.w = 1.0;
		pos=vertexPosition_modelspace;
	}
)";
	ret.s.program = ret.sm.program;

	return ret;
}
std::vector<program> enum_programs()
{
    loader_context context;
    auto shaders = enum_shaders(context);
    typedef std::map<std::string, std::vector<shader_info>> prog_info_map;
    prog_info_map program_map;
    for (const shader& s : shaders)
    {
        shader_meta_info info = extract_info(s.program);
        if (info.program == "")//TODO: throw error here?
            continue;
        shader_info si;
        si.s = s;
        si.sm = info;
        program_map[info.program].push_back(si);
		if (info.need_default_vertex)
		{	
			program_map[info.program].push_back(generate_vertex_shader(info));
		}
    }
    std::vector<program> ret;
    for (prog_info_map::iterator it = program_map.begin(); it != program_map.end(); it++)
    {
        ret.push_back(init_program(it->second, it->first,context));
    }
    return ret;
}
void free_programs(std::vector<program>& programs)
{
    for (auto p : programs)
    {
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