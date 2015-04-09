#include <imgui.h>
#include "imgui_impl_glfw_gl3.h"
#include <stdio.h>
#include <GL/gl3w.h>
#include <GLFW/glfw3.h>


#include "shaders.h"
#include <string>

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
            ImGui::TextWrapped("Log:%s", &s.log[0]);
    }
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
    program* current_program = nullptr;
    
    std::vector<program> programs = enum_programs();

    // Main loop
    float time = 0;
    while (!glfwWindowShouldClose(window))
    {
        ImGuiIO& io = ImGui::GetIO();
        time += io.DeltaTime;
        glfwPollEvents();

        ImGui_ImplGlfwGL3_NewFrame();

        {
            ImGui::Begin("Shaders");
            static float f = 0.0f;
            ImGui::Text("Application average %.3f ms/frame (%.1f FPS)", 1000.0f / ImGui::GetIO().Framerate, ImGui::GetIO().Framerate);
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
                        for (const shader& s : p.shaders)
                        {
                            ImGui::Text("Shader: %s(%s) Id:%d", s.name.c_str(), s.type_name.c_str(), s.id);
                            print_prog_status(s.status);
                            ImGui::Separator();
                        }
                    }
                    if (p.status.result && ImGui::Checkbox("Use", &is_current))
                    {
                        if (current_program == &p)
                        {
                            current_program = 0;
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
        if (current_program)
        {
            glUseProgram(current_program->id);
            glUniform2f(current_program->get_uniform(predefined_uniforms::resolution), io.DisplaySize.x, io.DisplaySize.y);
            glUniform1f(current_program->get_uniform(predefined_uniforms::time), time);
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
