// Assignment 1, Chessboard - Yvonne Rogell. Seattle University, FQ 2019. 
// CPSC 5700 - Computer Graphics. 

#include <glad.h>							// GL header file
#include <glfw3.h>							// GL toolkit
#include <stdio.h>							// printf, etc.
#include "GLXtras.h"						// convenience routines

GLuint vBuffer = 0;							// GPU buf ID, valid > 0
GLuint program = 0;						 	// shader ID, valid if > 0

void InitVertexBuffer() {
	// REQUIREMENT 3A) create GPU buffer, copy 4 vertices
	float pts[][2] = { {-1,-1},{-1,1},{1,1},{1,-1} }; // 'object'
	glGenBuffers(1, &vBuffer);						// ID for GPU buffer
	glBindBuffer(GL_ARRAY_BUFFER, vBuffer);			// make it active
	glBufferData(GL_ARRAY_BUFFER, sizeof(pts), pts, GL_STATIC_DRAW);
}

void Display() {
	glUseProgram(program);							// ensure correct program
	glBindBuffer(GL_ARRAY_BUFFER, vBuffer);			// activate vertex buffer
	// REQUIREMENT 3B) set vertex feeder
	
	GLint id = glGetAttribLocation(program, "point");
	glEnableVertexAttribArray(id);
	glVertexAttribPointer(id, 2, GL_FLOAT, GL_FALSE, 0, (void*)0);
	//	in subsequent code we will replace the above three lines with
	//	VertexAttribPointer(program, "point", 2, 0, (void *) 0);
	glDrawArrays(GL_QUADS, 0, 4);		            // display entire window
	glFlush();							            // flush GL ops
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
	GLFWwindow* w = glfwCreateWindow(400, 400, "Chessboard", NULL, NULL);
	if (!w)
		return AppError("can't open window");
	glfwMakeContextCurrent(w);
	gladLoadGLLoader((GLADloadproc)glfwGetProcAddress);	// set OpenGL extensions
	// following line will not compile unless glad.h >= OpenGLv4.3
	glDebugMessageCallback(GlslError, NULL);
	// REQUIREMENT 2) build shader program
	int v = CompileShaderViaFile("VertexShader.glsl", GL_VERTEX_SHADER);
	int p = CompileShaderViaFile("PixelShader.glsl", GL_FRAGMENT_SHADER);

	program = LinkProgram(v, p);
	if (!(program))
		return AppError("can't link shader program");
	InitVertexBuffer();										// set GPU vertex memory
	glfwSetKeyCallback(w, Keyboard);
	while (!glfwWindowShouldClose(w)) {						// event loop
		Display();
		if (PrintGLErrors())								// test for runtime GL error
			getchar();										// if so, pause
		glfwSwapBuffers(w);									// double-buffer is default
		glfwPollEvents();
	}
	glfwDestroyWindow(w);
	glfwTerminate();
}


// pixelshader
//#version 130
//out vec4 pColor;
//bool odd(float coordinate) {
//	return mod(coordinate, 100) < 50;
//}
//bool isUpperHalf(float coordinate)
//{
//	return coordinate > 200.f;
//}
//void main() {
//	// REQUIREMENT 1B) shade pixel:									
//	if ((odd(gl_FragCoord.x) && odd(gl_FragCoord.y))
//		|| (!odd(gl_FragCoord.x) && !odd(gl_FragCoord.y))) {
//		pColor = vec4(0, 0, 0, 1);
//	}
//	else if (isUpperHalf(gl_FragCoord.y)
//		&& isUpperHalf(gl_FragCoord.y)) {
//		pColor = vec4(1, 0, 0, 1);
//	}
//	else {
//		pColor = vec4(1, 1, 1, 1);
//	}
//}

// pixelshader working
//
//#version 130
//#ifdef GL_ES
//precision mediump float;
//#endif
//
//uniform float u_time;
//
//void main() {
//	// gl_FragColor = vec4(0.87,0.0,1.0,1.0);
//	vec2 xy = gl_FragCoord.xy; // We obtain our coordinates for the current pixel
//	vec4 solidRed = vec4(0, 0.0, 0.0, 1.0); // This is actually black right now
//	if (xy.x > 300.0) {//Arbitrary number, we don't know how big our screen is!
//		solidRed.r = 1.0;//Set its red component to 1.0
//	}
//	gl_FragColor = solidRed;
//}
//
//#ifdef GL_ES
//precision mediump float;
//#endif
//
//float circle(in vec2 _st, in float _radius) {
//	vec2 dist = _st - vec2(0.5);
//	return 1. - smoothstep(_radius - (_radius * 0.01),
//		_radius + (_radius * 0.01),
//		dot(dist, dist) * 4.0);
//}
//
//void main() {
//	vec2 st = gl_FragCoord.xy / 400;
//
//	vec3 color = vec3(circle(st, 0.9));
//
//	gl_FragColor = vec4(color, 1.0);
//}
