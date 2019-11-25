// PixelShader.glsl
// Final project - Raymarching cityscape
// Yvonne Rogell & Eric Nunn
// Graphics 5700, FQ 2019
// Seattle University

#version 130
const int MAX_MARCHING_STEPS = 255;
const float MIN_DIST = 0.0;
const float MAX_DIST = 100.0;
const float EPSILON = 0.0001; // Threshold for seeing if you hit an object
const float CAMERA_SPEED = 5.0;
uniform float time;
uniform float windowHeight;
uniform float windowWidth;
bool hitGround;
bool hitMoon;

/**
 * Returns the difference between two objects. distB is subtracted from distA.
 * Constructive solid geometry difference operation on SDF-calculated distances.
 */
 float differenceSDF(float distA, float distB) {
	return max(distA, -distB);
 }

/**
 * Signed distance function for a cube centered at "center""
 * with custom radii for length, width and height (added to "dims").
 */
float cubeSDF(vec3 p, vec3 dims, vec3 center) {
	vec3 q = abs(p-center) - dims;
    return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

/**
 * Signed distance function for a sphere with radius "r", 
 * centered at "center".
 */
float sphereSDF(vec3 p, float r, vec3 center) {
    return length(p - center) - r;
}

/**
 * Create a building with repeating windows. Building size is defined
 * by "dims", and building is centered at "center" with rounded edges
 * defined by fillet. 
 */
float buildingWithWindow(vec3 p, vec3 dims, vec3 center, float fillet) {
	
	float building = cubeSDF(p, dims, center) - fillet;
	vec3 windowSize = vec3(0.05,  0.075, 0.05);

	// Only make windows in the middle of the building, 
	// i.e. not too close to the ground or the roof
	if (p.y < dims.y - 0.15 && p.y > 0.4) {
		p.x = mod(p.x, 0.2) + 0.0;
		p.y = mod(p.y, 0.35) + 0.0;
		p.z = mod(p.z, 0.2) + 0.0;
		float window1 = cubeSDF(p, windowSize, vec3(center.x + 0.1, center.y + 0.1, 0.08));
		return differenceSDF(building, window1);
	}
	return building;
}

/**
 * Create a block of three buildings.
 */
float cityBlockSDF(vec3 p) {
	// building 1 attributes
	vec3 dims1 = vec3(0.75, 5.0, 0.75);
	vec3 center1 = vec3(0,0,-2.75);
	float fillet1 = 0.125;
	
	// building 2 attributes
	vec3 dims2 = vec3(.75, 3.0, .75);
	vec3 center2 = vec3(0,0,0);
	float fillet2 = 0.125;

	// building 3 attributes
	vec3 dims3 = vec3(.75, 4.0, .75);
	vec3 center3 = vec3(0,0,2.75);
	float fillet3 = 0.125;

	// distance to rounded-building
	float building1Dist = buildingWithWindow(p, dims1, center1, fillet1);
	float building2Dist = buildingWithWindow(p, dims2, center2, fillet2);
	float building3Dist = buildingWithWindow(p, dims3, center3, fillet3);
	
	return min(building1Dist, min(building2Dist, building3Dist));
}

/**
 * Creates multiple objects by reusing (or instancing) objects using the modulo operation.
 */
float multiCityBlockSDF(vec3 p) {
	// mod value changes size of repeated instance area, +/- vec affects offset of repeated area
	p.xz = mod(p.xz, vec2(6.0, 8.0)) - vec2(3.0, 4.0); // instance on xy-plane
	
	return cityBlockSDF(p);
}

/**
 * Creates multiple objects by reusing (or instancing) objects using the modulo operation.
 */
float groundSDF(vec3 p) {
	p.xz = mod(p.xz, 2.0)-vec2(1.0);								// instance on xy-plane
	return cubeSDF(p, vec3(10.0, 1.0, 10.0), vec3(0,0,0)) + 1.0;	// cube DE
}

/**
 * Signed distance function describing the scene.
 * 
 * Absolute value of the return value indicates the distance to the surface.
 * Sign indicates whether the point is inside or outside the surface,
 * negative indicating inside.
 */
float sceneSDF(vec3 samplePoint) {
	// Reset all color flags
	hitMoon = false;
	hitGround = false;

	// Calculate distance to each object
	float groundDist = groundSDF(samplePoint);
	float objectDist = multiCityBlockSDF(samplePoint);
	vec3 moonCenter = vec3(10.0, 20.0, -30.0-CAMERA_SPEED*time);
	float moonDist = sphereSDF(samplePoint, 5, moonCenter);
	
	// Check if ground is closest
	if (groundDist < objectDist && groundDist < moonDist) {
		hitGround = true;
		return groundDist;
	}
	// Check if moon is hit
	else if (moonDist < groundDist && moonDist < objectDist) {
		hitMoon = true;
		return moonDist;
	}
	// Otherwise building was hit
	else {
		return objectDist;
	}
}

/**
 * Return the shortest distance from the eyepoint to the scene surface along
 * the marching direction. If no part of the surface is found between start and end,
 * return end.
 * 
 * eye: the eye point, acting as the origin of the ray
 * marchingDirection: the normalized direction to march in
 * start: the starting distance away from the eye
 * end: the max distance away from the ey to march before giving up
 */
float shortestDistanceToSurface(vec3 eye, vec3 marchingDirection, float start, float end) {
    float depth = start;
    for (int i = 0; i < MAX_MARCHING_STEPS; i++) {
        float dist = sceneSDF(eye + depth * marchingDirection);
        if (dist < EPSILON) {
			return depth;
        }
        depth += dist;
        if (depth >= end) {
            return end;
        }
    }
    return end;
}
            

/**
 * Return the normalized direction to march in from the eye point for a single pixel.
 * 
 * fieldOfView: vertical field of view in degrees
 * size: resolution of the output image
 * fragCoord: the x,y coordinate of the pixel in the output image
 */
vec3 rayDirection(float fieldOfView, vec2 size, vec2 fragCoord) {
    vec2 xy = fragCoord - size / 2.0;
    float z = size.y / tan(radians(fieldOfView) / 2.0);
    return normalize(vec3(xy, -z));
}

/**
 * Using the gradient of the SDF, estimate the normal on the surface at point p.
 */
vec3 estimateNormal(vec3 p) {
    return normalize(vec3(
        sceneSDF(vec3(p.x + EPSILON, p.y, p.z)) - sceneSDF(vec3(p.x - EPSILON, p.y, p.z)),
        sceneSDF(vec3(p.x, p.y + EPSILON, p.z)) - sceneSDF(vec3(p.x, p.y - EPSILON, p.z)),
        sceneSDF(vec3(p.x, p.y, p.z  + EPSILON)) - sceneSDF(vec3(p.x, p.y, p.z - EPSILON))
    ));
}

/**
 * Lighting contribution of a single point light source via Phong illumination.
 * 
 * The vec3 returned is the RGB color of the light's contribution.
 *
 * k_a: Ambient color
 * k_d: Diffuse color
 * k_s: Specular color
 * alpha: Shininess coefficient
 * p: position of point being lit
 * eye: the position of the camera
 * lightPos: the position of the light
 * lightIntensity: color/intensity of the light
 *
 * See https://en.wikipedia.org/wiki/Phong_reflection_model#Description
 */
vec3 phongContribForLight(vec3 k_d, vec3 k_s, float alpha, vec3 p, vec3 eye,
                          vec3 lightPos, vec3 lightIntensity) {
    vec3 N = estimateNormal(p);
    vec3 L = normalize(lightPos - p);
    vec3 V = normalize(eye - p);
    vec3 R = normalize(reflect(-L, N));
    
    float dotLN = dot(L, N);
    float dotRV = dot(R, V);
    
    if (dotLN < 0.0) {
        // Light not visible from this point on the surface
        return vec3(0.0, 0.0, 0.0);
    } 
    
    if (dotRV < 0.0) {
        // Light reflection in opposite direction as viewer, apply only diffuse
        // component
        return lightIntensity * (k_d * dotLN);
    }
    return lightIntensity * (k_d * dotLN + k_s * pow(dotRV, alpha));
}

/**
 * Lighting via Phong illumination.
 * 
 * The vec3 returned is the RGB color of that point after lighting is applied.
 * k_a: Ambient color
 * k_d: Diffuse color
 * k_s: Specular color
 * alpha: Shininess coefficient
 * p: position of point being lit
 * eye: the position of the camera
 *
 * See https://en.wikipedia.org/wiki/Phong_reflection_model#Description
 */
vec3 phongIllumination(vec3 k_a, vec3 k_d, vec3 k_s, float alpha, vec3 p, vec3 eye) {
    const vec3 ambientLight = 0.2 * vec3(1.0, 1.0, 1.0);
    vec3 color = ambientLight * k_a;
    
	// street light
    vec3 light1Pos = vec3(0.0,
                          2.0,
                          CAMERA_SPEED*time);
    vec3 light1Intensity = vec3(0.2, 0.2, 0.2);
    
    color += phongContribForLight(k_d, k_s, alpha, p, eye,
                                  light1Pos,
                                  light1Intensity);
	
	// moon light
	vec3 light2Pos = vec3(4.0,
                          16.0,
                          -24.0-CAMERA_SPEED*time);
    vec3 light2Intensity = vec3(0.8, 0.8, 0.8);
    
    color += phongContribForLight(k_d, k_s, alpha, p, eye,
                                  light2Pos,
                                  light2Intensity);
    return color;
}

/**
 * Return a transform matrix that will transform a ray from view space
 * to world coordinates, given the eye point, the camera target, and an up vector.
 *
 * This assumes that the center of the camera is aligned with the negative z axis in
 * view space when calculating the ray marching direction. See rayDirection.
 */
mat4 viewMatrix(vec3 eye, vec3 center, vec3 up) {
    // Based on gluLookAt man page
    vec3 f = normalize(center - eye);
    vec3 s = normalize(cross(f, up));
    vec3 u = cross(s, f);
    return mat4(
        vec4(s, 0.0),
        vec4(u, 0.0),
        vec4(-f, 0.0),
        vec4(0.0, 0.0, 0.0, 1)
    );
}

/**
 * Method adding color and phong illumination to objects defined in scene.
 */
vec3 shade(vec3 p, vec3 eye)
{
	// object hit - default
	vec3 K_a = vec3(0.2, 0.2, 0.2);
	vec3 K_d = vec3(0.7, 0.2, 0.2); // red
	vec3 K_s = vec3(1.0, 1.0, 1.0);
	float shininess = 10.0;
    
	// ground hit
	if (hitGround) {
		K_a = vec3(0.2, 0.2, 0.2);
		K_d = vec3(0.2, 0.2, 0.2); // dark grey
		K_s = vec3(0.5, 0.5, 0.5);
	}

	// moon hit
	if (hitMoon) {
		K_a = vec3(0.5, 0.5, 0.5);
		K_d = vec3(1.0, 1.0, 1.0); // white
		K_s = vec3(0.2, 0.2, 0.2);
	}

    return phongIllumination(K_a, K_d, K_s, shininess, p, eye);
}

/**
 * Returns color for the given frag coordinate.
 */
vec4 colorForFrag(vec2 fragCoord) 
{
	vec3 viewDir = rayDirection(120.0, vec2(windowWidth, windowHeight), fragCoord);
    // moving camera postion in z direction with time:
	vec3 eye = vec3(-0.25, clamp(0.5*time, 2, 6), 15.0-CAMERA_SPEED*time);
	vec3 target = vec3(-0.25, 3.0, -CAMERA_SPEED*time);
    
    mat4 viewToWorld = viewMatrix(eye, target, vec3(0.0, 1.0, 0.0));
    
    vec3 worldDir = (viewToWorld * vec4(viewDir, 0.0)).xyz;
    
    float dist = shortestDistanceToSurface(eye, worldDir, MIN_DIST, MAX_DIST);
    
    if (dist > MAX_DIST - EPSILON) {
        // Didn't hit anything
		// sky
        return vec4(0.0, 0.0, 0.2, 0.3); // blue
    }
    
    // The closest point on the surface to the eyepoint along the view ray
    vec3 p = eye + dist * worldDir;

	return vec4(shade(p, eye), 1.0);
}

// Main function. Gets and sets the color of the current point in space. 
void main()
{
	vec4 color = colorForFrag(gl_FragCoord.xy);
    gl_FragColor = vec4(color);
}