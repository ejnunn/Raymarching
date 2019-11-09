#version 130														
in vec2 point;							
void main() {														
	// REQUIREMENT 1A) transform vertex:	
	gl_Position = vec4(point, 0, 1);
}	