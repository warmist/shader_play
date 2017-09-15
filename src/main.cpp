#define _GLFW_USE_DWM_SWAP_INTERVAL 1
#include <GL/gl3w.h>
#include <GLFW/glfw3.h>
#include <imgui.h>
#include "imgui_impl_glfw_gl3.h"
#include <stdio.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846264338327
#endif

#include "shaders.h"
#include <string>
#include "filesys.h"
#include "camera.h"
#include "trackball.h"
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

#include <cstdint>

//NOTE:col major for opengl
/*
    Ideas for the future:
        add timeline like thingy
        add ability to genrate (and maybe save) content- meshes, textures, etc...
        add shader recompilable options (e.g. #define that you can flip on and off in gui)
        rethink structure of shaders
        loading textures and meshes
        think out general architecture of pipeline setup (and modification).
    other stuff:
        octree sdfs
        composite screens (render something with few shaders and then compose)
        cellular automata
*/
//#define DO_GL_DEBUG
const char* version_string=nullptr;
static void error_callback(int error, const char* description)
{
    fprintf(stderr, "Error %d: %s\n", error, description);
}
void print_prog_status(const prog_status& s)
{
    if (s.result == GL_TRUE)
        ImGui::TextWrapped("Compile ok.");
    else
    {
        if (s.log.size()>0)
            ImGui::TextWrapped("Log:%s", s.log.c_str());
    }
}
void reset_camera(Camera& p)
{
    p.setPosition(Eigen::Vector3f(10, 10, 10));
    p.setTarget(Eigen::Vector3f(0, 0, 0));
    //p.setUp(Eigen::Vector3f::UnitY()); //TODO: fix setUp for camera
}
void handle_keys(GLFWwindow* window, Camera& p, float delta_time)
{
    float move_speed = delta_time*10;
    float angle = move_speed / 20;
    Eigen::Vector3f right=Eigen::Vector3f::UnitX();
    Eigen::Vector3f up = Eigen::Vector3f::UnitY();
    Eigen::Vector3f forward = Eigen::Vector3f::UnitZ();
#define KY_PRESS(KEY) if(glfwGetKey(window, KEY) == GLFW_PRESS)
    KY_PRESS(GLFW_KEY_W)
        p.localTranslate(-forward *move_speed);
    KY_PRESS(GLFW_KEY_S)
        p.localTranslate(forward *move_speed);
    KY_PRESS(GLFW_KEY_A)
        p.localTranslate(right *move_speed);
    KY_PRESS(GLFW_KEY_D)
        p.localTranslate(-right *move_speed);
    KY_PRESS(GLFW_KEY_UP)
        p.rotateAroundTarget(Eigen::Quaternionf(Eigen::AngleAxisf(-angle, right)));
    KY_PRESS(GLFW_KEY_DOWN)
        p.rotateAroundTarget(Eigen::Quaternionf(Eigen::AngleAxisf(angle, right)));
    KY_PRESS(GLFW_KEY_LEFT)
        p.rotateAroundTarget(Eigen::Quaternionf(Eigen::AngleAxisf(-angle, up)));
    KY_PRESS(GLFW_KEY_RIGHT)
        p.rotateAroundTarget(Eigen::Quaternionf(Eigen::AngleAxisf(angle, up)));
    KY_PRESS(GLFW_KEY_Q)
        p.rotateAroundTarget(Eigen::Quaternionf(Eigen::AngleAxisf(-angle, forward)));
    KY_PRESS(GLFW_KEY_E)
        p.rotateAroundTarget(Eigen::Quaternionf(Eigen::AngleAxisf(angle, forward)));
    KY_PRESS(GLFW_KEY_SPACE)
    {
        reset_camera(p);
    }
#undef KY_PRESS
}
void handle_mouse(Camera& p, float dx, float dy)
{
    Eigen::Quaternionf q = Eigen::AngleAxisf(float(dx*M_PI), Eigen::Vector3f::UnitY())
        * Eigen::AngleAxisf(float(-dy*M_PI), Eigen::Vector3f::UnitX());
    p.rotateAroundTarget(q);
}
void renorm(float* data, int id_fixed)
{
    
    float sum = 0;
    for (int i = 0; i < 3; i++)
    {
        if (i != id_fixed)
            sum += data[i] * data[i];
    }
    float fixed = data[id_fixed];
    float trg = 1 - fixed*fixed;
    if (fixed == 1)
    {
        for (int i = 0; i < 3; i++)
        {
            if (i != id_fixed)
                data[i] = 0;
        }
    }
    else
    {
        sum = sqrt(sum);
        if (sum < std::numeric_limits<float>::epsilon())
        {
            for (int i = 0; i < 3; i++)
            {
                if (i != id_fixed)
                {
                    data[i] = sqrt(trg);
                    return;
                }
            }
        }
        for (int i = 0; i < 3; i++)
        {
            if (i != id_fixed)
                data[i] = (data[i] / sum)*sqrt(trg);
        }
    }
}
bool normalized_slider3(const char* label, float* data)
{
    float arr[3];
    for (int i = 0; i < 3; i++)
    {
        if (data[i] != data[i])
            data[i] = 0;
        arr[i] = data[i];
    }
    if (ImGui::SliderFloat3(label, data, -1, 1))
    {
        for (int i = 0; i < 3; i++)
        {
            if (arr[i] != data[i])
            {
                renorm(data, i);
                return true;
            }
        }
        return true;
    }
    return false;
}
void make_gui(std::vector<program>& programs, program*& current_program)
{
    ImGuiIO& io = ImGui::GetIO();
    ImGui::Begin("Shaders");

    float w = io.DisplaySize.x; 
    float h = io.DisplaySize.y;
    const float w_size = 300;
    ImGui::SetWindowPos(ImVec2(w - w_size, 0), ImGuiSetCond_FirstUseEver);
    ImGui::SetWindowSize(ImVec2(w_size, h), ImGuiSetCond_FirstUseEver);
    ImGui::Text("Version:%s", version_string);
    ImGui::Text("%.3f ms/frame (%.1f FPS)", 1000.0f / io.Framerate, io.Framerate);

    for (program& p : programs)
    {
        bool is_current = &p == current_program;

        if (ImGui::CollapsingHeader(p.name.c_str()))
        {
            ImGui::PushID(p.name.c_str());
            ImGui::Indent();
            if (ImGui::CollapsingHeader("Info"))
            {
                ImGui::Text("Program id: %d", p.id);
                print_prog_status(p.status);
                ImGui::Separator();
                for (const shader& s : p.shaders)
                {
                    ImGui::Text("Shader: %s(%s) Id:%d", s.name.c_str(), s.type_name.c_str(), s.id);
                    print_prog_status(s.status);
                    ImGui::Separator();
                }
            }
            for (auto& u : p.uniforms)
            {
                switch (u.type)
                {
				case uniform_type::t_float_angle:
					if (u.has_max && u.has_min)
					{
						ImGui::SliderAngle(u.name.c_str(), &u.data.f, u.min.f, u.max.f);
					}
					else
					{
						ImGui::SliderAngle(u.name.c_str(), &u.data.f);
					}
					break;
                case uniform_type::t_float:
					if (u.has_max && u.has_min)
					{
						ImGui::SliderFloat(u.name.c_str(), &u.data.f, u.min.f, u.max.f);
					}
					else
					{
						ImGui::InputFloat(u.name.c_str(), &u.data.f);
					}
                    break;
                case uniform_type::t_float_clamp:
					if (u.has_max && u.has_min)
					{
						ImGui::SliderFloat(u.name.c_str(), &u.data.f, u.min.f, u.max.f);
					}
					else
					{
						ImGui::SliderFloat(u.name.c_str(), &u.data.f, 0, 1);
					}
                    break;
                case uniform_type::t_vec3:
                    ImGui::InputFloat3(u.name.c_str(), u.data.f3);
                    break;
                case uniform_type::t_vec3_clamp:
                    ImGui::SliderFloat3(u.name.c_str(), u.data.f3, 0, 1);
                    break;
                case uniform_type::t_vec3_norm:
                    normalized_slider3(u.name.c_str(), u.data.f3);
                    break;
				case uniform_type::t_int:
					if (u.has_max && u.has_min)
					{
						ImGui::SliderInt(u.name.c_str(), &u.data.i, u.min.i, u.max.i);
					}
					else
					{
						ImGui::InputInt(u.name.c_str(), &u.data.i);
					}
					break;
                default:
                    ImGui::Text("Unsupported uniform:%s", u.name.c_str());
                }

            }
            if (p.status.result && ImGui::Checkbox("Use", &is_current))
            {
                if (current_program == &p)
                {
                    current_program = nullptr;
                }
                else
                {
                    current_program = &p;
                }
            }
            ImGui::Unindent();
            ImGui::PopID();
        }
    }

    ImGui::End();

}
struct pixel_buffer
{
    GLuint pixelbuffer[2];
    GLuint texture;
    GLsizeiptr screen_size = 0;

    GLuint framebuffer;
    GLuint framebuffer_tex;

    int index = 0;
    int next_index = 1;
    pixel_buffer()
    {
        glGenBuffers(2, pixelbuffer);
        glGenTextures(1, &texture);
        glGenFramebuffers(1, &framebuffer);
        glGenTextures(1, &framebuffer_tex);
        //glGenRenderbuffers(1, &amp; mSceneData.mDepthBuffer);
    }
    void update_buffer_size( ImGuiIO& io)
    {
        if (io.DisplaySize.x < 0)
            return;
        if (screen_size == (int)io.DisplaySize.x*io.DisplaySize.y)
            return;
        screen_size = GLsizeiptr(io.DisplaySize.x*io.DisplaySize.y);
        const unsigned pixel_size = sizeof(unsigned char)*16;

        glBindBuffer(GL_PIXEL_PACK_BUFFER, pixelbuffer[0]);
        glBufferData(GL_PIXEL_PACK_BUFFER, screen_size*pixel_size, 0, GL_DYNAMIC_DRAW);

        glBindBuffer(GL_PIXEL_PACK_BUFFER, pixelbuffer[1]);
        glBufferData(GL_PIXEL_PACK_BUFFER, screen_size*pixel_size, 0, GL_DYNAMIC_DRAW);

        glBindTexture(GL_TEXTURE_2D, texture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        //glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 0);
        glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
        //glTexStorage2D(GL_TEXTURE_2D, 1, GL_RGBA16F, (int)io.DisplaySize.x, (int)io.DisplaySize.y );
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, (int)io.DisplaySize.x, (int)io.DisplaySize.y, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
        
        //GL_INVALID_ENUM
        // Because we're also using this tex as an image (in order to write to it),
        // we bind it to an image unit as well
        //glBindImageTexture(0, texture, 0, GL_FALSE, 0, GL_WRITE_ONLY, GL_R32F);



        

        glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);

        glBindTexture(GL_TEXTURE_2D, framebuffer_tex);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, (int)io.DisplaySize.x, (int)io.DisplaySize.y, 0, GL_RGBA, GL_FLOAT, NULL);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, framebuffer_tex, 0);
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
    }
    GLuint cur_buffer()
    {
        return pixelbuffer[index];
    }
    GLuint next_buffer()
    {
        return pixelbuffer[next_index];
    }
    void flip()
    {
        index = (index + 1) % 2;
        next_index = (index + 1) % 2;
    }
};
void APIENTRY dgb_callback(GLenum source, GLenum type, GLuint id, GLenum severity, GLsizei length, const GLchar *message, GLvoid *userParam)
{
    __debugbreak();
}
std::vector<uint32_t> tmp_buffer;
int main(int, char**)
{
    // Setup window
    glfwSetErrorCallback(error_callback);
    if (!glfwInit())
        exit(1);
    
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 4);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
#ifdef DO_GL_DEBUG
    glfwWindowHint(GLFW_OPENGL_DEBUG_CONTEXT, true);
#endif

    GLFWwindow* window = glfwCreateWindow(1280, 720, "Shay play", NULL, NULL);
    glfwMakeContextCurrent(window);

    
    
    gl3wInit();
    version_string = (const char*)glGetString(GL_VERSION);

    glfwSwapInterval(1);

#ifdef DO_GL_DEBUG
    glDebugMessageCallback(&dgb_callback, nullptr);
    glEnable(GL_DEBUG_OUTPUT);
#endif
    GLuint VertexArrayID;
    glGenVertexArrays(1, &VertexArrayID);
    glBindVertexArray(VertexArrayID);
    static const GLfloat g_vertex_buffer_data[] = {

        -1.0f, -1.0f, 0.0f,
        1.0f, -1.0f, 0.0f,
        -1.0f, 1.0f, 0.0f,
       1.0f, 1.0f, 0.0f,
    };
    // This will identify our vertex buffer
    GLuint vertexbuffer;
   
    glGenBuffers(1, &vertexbuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexbuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(g_vertex_buffer_data), g_vertex_buffer_data, GL_STATIC_DRAW);

    pixel_buffer pbos;
    
    // Setup ImGui binding
    ImGui_ImplGlfwGL3_Init(window, true);
    ImGui::GetIO().IniFilename = nullptr; //disable ini saving/loading

    ImVec4 clear_color = ImColor(114, 144, 154);

    Camera player;
    Trackball tracker;
    tracker.setCamera(&player);
    reset_camera(player);
    program* current_program = nullptr;
    
    std::vector<program> programs = enum_programs();
    dir_watcher watcher("shaders");
    // Main loop
    float time = 0; //TODO: Floating point time. This could have bad accuracy in long run
    float recompile_timer = 0;
    bool first_down_frame = true;
	std::string was_name;
    while (!glfwWindowShouldClose(window))
    {
        
        ImGuiIO& io = ImGui::GetIO();
        
        time += io.DeltaTime; //seems strange, maybe use glfwGetTime?
        glfwPollEvents();
        
        if (watcher.check_changes()) //double triggered, maybe sometimes file is in use and can't be opened when it happens
        {
            recompile_timer = time+0.5f;
        }
        if (recompile_timer <= time && recompile_timer != 0)
        {
            recompile_timer = 0;
            glUseProgram(0);
			if (current_program != nullptr)
			{
				was_name= current_program->name;
			}
            update_programs(programs);
            current_program = nullptr;
            for (auto& p : programs)
            {
                if (p.status.result && p.name == was_name)
                {
                    current_program = &p;
                    break;
                }
            }
        }
        ImGui_ImplGlfwGL3_NewFrame();
        pbos.update_buffer_size(io);
        make_gui(programs,current_program);

        handle_keys(window, player, io.DeltaTime);
        player.setViewport(unsigned(io.DisplaySize.x), unsigned(io.DisplaySize.y));
        if (io.MouseDown[0] && !io.MouseDownOwned[0])
            handle_mouse(player, io.MouseDelta.x / io.DisplaySize.x, -io.MouseDelta.y / io.DisplaySize.y);
        
        /* broken, nans only... FIXME: figure this out
        if (io.MouseDown[0] && !io.MouseDownOwned[0])
        {
            if (first_down_frame)
            {
                //ImGui::Text("Start tracking");
                tracker.start(Trackball::Around);
            }
            else
            {
                //ImGui::Text("Mouse move %.2f %.2f", io.MousePos.x, io.MousePos.y);

            }
            tracker.track(Eigen::Vector2i(io.MousePos.x, io.MousePos.y));
            first_down_frame = false;
        }
        else
        {
            //ImGui::Text("Stop tracking");
            first_down_frame = true;
        }
        //*/
       
        if (current_program)
        {
            glUseProgram(current_program->id);
            glUniform1i(current_program->get_uniform(predefined_uniforms::last_frame), 0);
            glActiveTexture(GL_TEXTURE0 + 0);
            glBindTexture(GL_TEXTURE_2D, pbos.texture);
            glUniform2f(current_program->get_uniform(predefined_uniforms::resolution), io.DisplaySize.x, io.DisplaySize.y);
            glUniform1f(current_program->get_uniform(predefined_uniforms::time), time);
            float dur = io.MouseDownDuration[0];
            if (io.MouseDownOwned[0])
                dur = 0;
            glUniform3f(current_program->get_uniform(predefined_uniforms::mouse), (io.MousePos.x / io.DisplaySize.x) * 2 - 1, (1 - io.MousePos.y / io.DisplaySize.y) * 2 - 1, dur);
            
            player.activateGL(current_program->get_uniform(predefined_uniforms::projection), current_program->get_uniform(predefined_uniforms::modelview),
                current_program->get_uniform(predefined_uniforms::projection_inv), current_program->get_uniform(predefined_uniforms::modelview_inv));

            for (const auto& u : current_program->uniforms)
            {
                switch (u.type)
                { 
				case uniform_type::t_int:
					glUniform1i(u.id, u.data.i);
					break;
                case uniform_type::t_float:
				case uniform_type::t_float_angle:
                case uniform_type::t_float_clamp:
                    glUniform1f(u.id, u.data.f);
                    break;
                case uniform_type::t_vec3: 
                case uniform_type::t_vec3_clamp:
                case uniform_type::t_vec3_norm:
                    glUniform3fv(u.id, 1, u.data.f3);
                default:;
                }
            }
        }
        else
            glUseProgram(0);

        
        // Rendering
        glViewport(0, 0, (int)io.DisplaySize.x, (int)io.DisplaySize.y);
        glClearColor(clear_color.x, clear_color.y, clear_color.z, clear_color.w);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glBindVertexArray(VertexArrayID);
        
        glEnableVertexAttribArray(0);
        glBindBuffer(GL_ARRAY_BUFFER, vertexbuffer);
        glVertexAttribPointer(
            0,                  // attribute 0. No particular reason for 0, but must match the layout in the shader.
            3,                  // size
            GL_FLOAT,           // type
            GL_FALSE,           // normalized?
            0,                  // stride
            (void*)0            // array buffer offset
            );
        glBindFramebuffer(GL_FRAMEBUFFER, pbos.framebuffer);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        glBindFramebuffer(GL_FRAMEBUFFER, 0);

        glBindFramebuffer(GL_READ_FRAMEBUFFER, pbos.framebuffer);
        glBlitFramebuffer(0, 0, (int)io.DisplaySize.x, (int)io.DisplaySize.y, 0, 0, (int)io.DisplaySize.x, (int)io.DisplaySize.y, GL_COLOR_BUFFER_BIT, GL_NEAREST);
        glBindFramebuffer(GL_READ_FRAMEBUFFER, 0);

        if (current_program)
        {
           
            //load stuff into texture

            glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
            glPixelStorei(GL_PACK_ALIGNMENT, 1);
            glBindFramebuffer(GL_READ_FRAMEBUFFER, pbos.framebuffer);

            glBindBuffer(GL_PIXEL_PACK_BUFFER, pbos.cur_buffer());
            glReadPixels(0, 0, (int)io.DisplaySize.x, (int)io.DisplaySize.y, GL_RGBA, GL_FLOAT, 0);
            glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
            glBindBuffer(GL_PIXEL_UNPACK_BUFFER, pbos.cur_buffer());
			ImGui::Begin("Shaders");
			if (ImGui::Button("Save image"))
			{
                int w = (int)io.DisplaySize.x;
                int h = (int)io.DisplaySize.y;

				tmp_buffer.resize(w*h * 4);
				glReadPixels(0, 0, w,h, GL_RGBA, GL_UNSIGNED_BYTE, tmp_buffer.data());
				stbi_write_png("capture.png", w,h, 4, tmp_buffer.data()+w*(h-1), -4 * w);
			}
			ImGui::End();
            /*
             
            
            glBindBuffer(GL_PIXEL_UNPACK_BUFFER, pbos.next_buffer());*/
            
            
            
            //glPixelStorei(GL_UNPACK_ROW_LENGTH, (int)io.DisplaySize.x);
            //glTexImage2D(pbos.texture, 0, GL_RGBA, (int)io.DisplaySize.x, (int)io.DisplaySize.y, 0, GL_BGRA, GL_UNSIGNED_BYTE, pbos.tmp_buffer.data());
            glActiveTexture(GL_TEXTURE0 + 0);
            glBindTexture(GL_TEXTURE_2D, pbos.texture);
            glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, (int)io.DisplaySize.x, (int)io.DisplaySize.y, GL_RGBA, GL_FLOAT, 0);
            //glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);

            glBindFramebuffer(GL_READ_FRAMEBUFFER, 0);
        }
        glDisableVertexAttribArray(0);
        
        ImGui::Render();
        
        glfwSwapBuffers(window);

        //pbos.flip();
		glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
		glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
        
    }

    // Cleanup
    ImGui_ImplGlfwGL3_Shutdown();
    glfwTerminate();

    return 0;
}
