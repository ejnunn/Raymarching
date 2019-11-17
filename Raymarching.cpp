// Raymarching Project - Eric Nunn, Yvonne Rogell. Seattle University, FQ 2019. 
// CPSC 5700 - Computer Graphics

#include <glad.h>							// GL header file
#include <glfw3.h>							// GL toolkit
#include <stdio.h>							// printf, etc.
#include <time.h>
#include "GLXtras.h"						// convenience routines
#include "Camera.h"

GLuint vBuffer = 0;							// GPU buf ID, valid > 0
GLuint program = 0;						 	// shader ID, valid if > 0
float start = clock();
float windowWidth = 800.0;
float windowHeight = 800.0;

// Window size and camera initilization
int winWidth = 500, winHeight = 500;

// Camera parameters: screenWidth, screenHeight, rotation, translation, FOV, nearDist, farDist, invVert
Camera camera(winWidth / 2, winHeight / 2, vec3(0, 0, 0), vec3(0, 0, -1), 10, 0.001f, 500, false);


void InitVertexBuffer() {
	float pts[][2] = { {-1,-1},{-1,1},{1,1},{1,-1} }; // 'object'
	glGenBuffers(1, &vBuffer);						// ID for GPU buffer
	glBindBuffer(GL_ARRAY_BUFFER, vBuffer);			// make it active
	glBufferData(GL_ARRAY_BUFFER, sizeof(pts), pts, GL_STATIC_DRAW);
}

void Display(GLFWwindow* w) {
	glUseProgram(program);							// ensure correct program
	glBindBuffer(GL_ARRAY_BUFFER, vBuffer);			// activate vertex buffer
	float time = (clock() - start) / CLOCKS_PER_SEC;

	GLint id = glGetAttribLocation(program, "point");
	SetUniform(program, "time", time);
	SetUniform(program, "windowHeight", windowHeight);
	SetUniform(program, "windowWidth", windowWidth);
	glEnableVertexAttribArray(id);
	glVertexAttribPointer(id, 2, GL_FLOAT, GL_FALSE, 0, (void*)0);
	
	// Set camera speed
	camera.SetSpeed(0.3f, 0.01f);

	// Set window size
	int screenWidth, screenHeight;
	glfwGetWindowSize(w, &screenWidth, &screenHeight);

	// Set vertex attribute pointers& uniforms
	VertexAttribPointer(program, "point", 2, 0, (void *) 0);
	glDrawArrays(GL_QUADS, 0, 4);		            // display entire window
	glFlush();							            // flush GL ops
}

// To dynamically resize the viewport when a user resizes the application window
void Resize(GLFWwindow* w, int width, int height) {
	camera.Resize(width, height);
	glViewport(0, 0, width, height);
}


void Keyboard(GLFWwindow* window, int key, int scancode, int action, int mods) {
	if (key == GLFW_KEY_ESCAPE && action == GLFW_PRESS)		// test for program exit
		glfwSetWindowShouldClose(window, GLFW_TRUE);
}

void GlfwError(int id, const char* reason) {
	printf("GFLW error %i: %s\n", id, reason);
	getchar();
}

void APIENTRY GlslError(GLenum source, GLenum type, GLuint id, GLenum severity,
	GLsizei len, const GLchar* msg, const void* data) {
	printf("GLSL Error: %s\n", msg);
	getchar();
}

int AppError(const char* msg) {
	glfwTerminate();
	printf("Error: %s\n", msg);
	getchar();
	return 1;
}

int main() {												// application entry
	glfwSetErrorCallback(GlfwError);						// init GL toolkit
	if (!glfwInit())
		return 1;
	// create named window of given size
	GLFWwindow* w = glfwCreateWindow(windowWidth, windowHeight, "Raymarching cityscape", NULL, NULL);
	if (!w)
		return AppError("can't open window");
	glfwMakeContextCurrent(w);
	gladLoadGLLoader((GLADloadproc)glfwGetProcAddress);	// set OpenGL extensions
	// following line will not compile unless glad.h >= OpenGLv4.3
	glDebugMessageCallback(GlslError, NULL);
	// import shaders from separate files
	int v = CompileShaderViaFile("VertexShader.glsl", GL_VERTEX_SHADER);
	int p = CompileShaderViaFile("PixelShader.glsl", GL_FRAGMENT_SHADER);

	program = LinkProgram(v, p);
	if (!(program))
		return AppError("can't link shader program");
	InitVertexBuffer();										// set GPU vertex memory
	camera.SetSpeed(.01f, .001f);							// otherwise, a bit twitchy
	glfwSetWindowSizeCallback(w, Resize);					// so can view larger window
	glfwSwapInterval(1);
	glfwSetKeyCallback(w, Keyboard);
	while (!glfwWindowShouldClose(w)) {						// event loop
		Display(w);
		if (PrintGLErrors())								// test for runtime GL error
			getchar();										// if so, pause
		glfwSwapBuffers(w);									// double-buffer is default
		glfwPollEvents();
	}
	glfwDestroyWindow(w);
	glfwTerminate();
}