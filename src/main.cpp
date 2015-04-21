#include <GL/gl3w.h>
#include <GLFW/glfw3.h>
#include <imgui.h>
#include "imgui_impl_glfw_gl3.h"
#include <stdio.h>



#include "shaders.h"
#include <string>
#include "filesys.h"
#include "camera.h"
#include "trackball.h"
//NOTE:col major for opengl
/*
    Ideas for the future:
        add timeline like thingy
        add ability to genrate (and maybe save) content- meshes, textures, etc...
        add shader recompilable options (e.g. #define that you can flip on and off in gui)
        rethink structure of shaders
        loading textures and meshes
        think out general architecture of pipeline setup (and modification).
*/
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
int main(int, char**)
{
    // Setup window
    glfwSetErrorCallback(error_callback);
    if (!glfwInit())
        exit(1);

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    GLFWwindow* window = glfwCreateWindow(1280, 720, "Shay play", NULL, NULL);
    glfwMakeContextCurrent(window);
    
    gl3wInit();

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
    // Generate 1 buffer, put the resulting identifier in vertexbuffer
    glGenBuffers(1, &vertexbuffer);
    // The following commands will talk about our 'vertexbuffer' buffer
    glBindBuffer(GL_ARRAY_BUFFER, vertexbuffer);
    // Give our vertices to OpenGL.
    glBufferData(GL_ARRAY_BUFFER, sizeof(g_vertex_buffer_data), g_vertex_buffer_data, GL_STATIC_DRAW);


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
    float time = 0;
    float recompile_timer = 0;
    bool first_down_frame = true;
    while (!glfwWindowShouldClose(window))
    {
        
        ImGuiIO& io = ImGui::GetIO();
        time += io.DeltaTime;
        glfwPollEvents();
        if (watcher.check_changes()) //double triggered, maybe sometimes file is in use and can't be opened when it happens
        {
            recompile_timer = time+0.5f; //TODO: probably needs timer not counter here
        }
        if (recompile_timer <= time && recompile_timer != 0)
        {
            recompile_timer = 0;
            glUseProgram(0);
            std::string p_name;
            if (current_program != nullptr)
                p_name = current_program->name;
            update_programs(programs);
            current_program = nullptr;
            for (auto& p : programs)
            {
                if (p.status.result && p.name == p_name)
                {
                    current_program = &p;
                    break;
                }
            }
        }
        ImGui_ImplGlfwGL3_NewFrame();

        {
            ImGui::Begin("Shaders");
            static float f = 0.0f;
            ImGui::Text("Application average %.3f ms/frame (%.1f FPS)", 1000.0f / ImGui::GetIO().Framerate, ImGui::GetIO().Framerate);
            auto player_pos = player.position();
            auto player_dir = player.direction();
            ImGui::Text("Pos: %.2f %.2f %.2f Look: %2f %2f %2f", player_pos.x(), player_pos.y(), player_pos.z(), player_dir.x(), player_dir.y(), player_dir.z());

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
                        case uniform_type::t_float:
                            ImGui::InputFloat(u.name.c_str(), &u.data.f);
                            break;
                        case uniform_type::t_float_clamp:
                            ImGui::SliderFloat(u.name.c_str(), &u.data.f,0,1);
                            break;
                        case uniform_type::t_vec3:
                            ImGui::InputFloat3(u.name.c_str(), u.data.f3);
                            break;
                        case uniform_type::t_vec3_clamp:
                            ImGui::SliderFloat3(u.name.c_str(), u.data.f3,0,1);
                            break;
                        case uniform_type::t_vec3_norm:
                            normalized_slider3(u.name.c_str(), u.data.f3);
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
                    //for each uniform do sth...
                    ImGui::PopID();
                }
            }

            ImGui::End();
        }
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
            glUniform2f(current_program->get_uniform(predefined_uniforms::resolution), io.DisplaySize.x, io.DisplaySize.y);
            glUniform1f(current_program->get_uniform(predefined_uniforms::time), time);
            glUniform3f(current_program->get_uniform(predefined_uniforms::mouse), (io.MousePos.x / io.DisplaySize.x) * 2 - 1, (1 - io.MousePos.y / io.DisplaySize.y) * 2 - 1, io.MouseDownTime[0]);
            player.activateGL(current_program->get_uniform(predefined_uniforms::projection), current_program->get_uniform(predefined_uniforms::modelview),
                current_program->get_uniform(predefined_uniforms::projection_inv), current_program->get_uniform(predefined_uniforms::modelview_inv));
            for (const auto& u : current_program->uniforms)
            {
                switch (u.type)
                { 
                case uniform_type::t_float:
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

        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        glDisableVertexAttribArray(0);

        ImGui::Render();
        
        

        glfwSwapBuffers(window);
        
    }

    // Cleanup
    ImGui_ImplGlfwGL3_Shutdown();
    glfwTerminate();

    return 0;
}
