// VertexShader.glsl
// Final project - Raymarching cityscape
// Yvonne Rogell & Eric Nunn
// Graphics 5700, FQ 2019
// Seattle University

#version 130
in vec2 point;
uniform mat4 persp;
void main() {	
	gl_Position = vec4(point, 0, 1);
}
