#version 130														
out vec4 pColor;													
bool odd(float coordinate) {										
	return mod(coordinate, 100) < 50;								
}																	
bool isUpperHalf(float coordinate)									
{																	
	return coordinate > 200.f;										
}																	
void main() {														
	// REQUIREMENT 1B) shade pixel:									
    if ((odd(gl_FragCoord.x) && odd(gl_FragCoord.y))				
		|| (!odd(gl_FragCoord.x) && !odd(gl_FragCoord.y))) {		
		pColor = vec4(0, 0, 0, 1);									
	}																
	else if (isUpperHalf(gl_FragCoord.y)							
			&& isUpperHalf(gl_FragCoord.y)) {						
		pColor = vec4(1, 0, 0, 1);									
	}																
	else {															
		pColor = vec4(1, 1, 1, 1);									
	}																
}				