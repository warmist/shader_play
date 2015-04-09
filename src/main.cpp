#include <imgui.h>
#include "imgui_impl_glfw_gl3.h"
#include <stdio.h>
#include <GL/gl3w.h>
#include <GLFW/glfw3.h>

#include "filesys.h"
#include <string>

struct shader{
    std::string path;
    std::string name;
};
std::string extract_name(const std::string& path)
{
    std::string::size_type pos = path.find_last_of("/");
    if (pos == std::string::npos)
    {
        pos = path.find_last_of("\\");
    }
    if (pos == std::string::npos)
        return "<INVALID>"; //TODO: can it BE?!
    return path.substr(pos);
}
std::vector<shader> enum_shaders()
{
    auto file_list = enum_files("shaders/*.txt");
    std::vector<shader> ret;
    for (auto f : file_list)
    {
        shader s;
        s.path = f;
        s.name = extract_name(f);
        ret.push_back(s);
    }
    return ret;
}
static void error_callback(int error, const char* description)
{
    fprintf(stderr, "Error %d: %s\n", error, description);
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

    // Setup ImGui binding
    ImGui_ImplGlfwGL3_Init(window, true);
    ImGui::GetIO().IniFilename = nullptr; //disable ini saving/loading

    ImVec4 clear_color = ImColor(114, 144, 154);
    
    std::vector<shader> shaders = enum_shaders();
    // Main loop
    while (!glfwWindowShouldClose(window))
    {
        ImGuiIO& io = ImGui::GetIO();
        glfwPollEvents();
        
        ImGui_ImplGlfwGL3_NewFrame();

        {
            ImGui::Begin("Shaders");
            static float f = 0.0f;
            ImGui::Text("Application average %.3f ms/frame (%.1f FPS)", 1000.0f / ImGui::GetIO().Framerate, ImGui::GetIO().Framerate);
            for (const shader& s : shaders)
            {
                if (ImGui::CollapsingHeader(s.name.c_str()))
                {
                    ImGui::Text("Path: %s", s.path.c_str());
                    //for each uniform do sth...
                }
            }
            
            ImGui::End();
        }


        // Rendering
        glViewport(0, 0, (int)io.DisplaySize.x, (int)io.DisplaySize.y);
        glClearColor(clear_color.x, clear_color.y, clear_color.z, clear_color.w);
        glClear(GL_COLOR_BUFFER_BIT);
        ImGui::Render();

        glfwSwapBuffers(window);
    }

    // Cleanup
    ImGui_ImplGlfwGL3_Shutdown();
    glfwTerminate();

    return 0;
}
