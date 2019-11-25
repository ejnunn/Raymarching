#version 130
const int MAX_MARCHING_STEPS = 255;
const float MIN_DIST = 0.0;
const float MAX_DIST = 100.0;
const float EPSILON = 0.0001;
uniform float time;
uniform float windowHeight;
uniform float windowWidth;

/**
 * Constructive solid geometry intersection operation on SDF-calculated distances.
 */
float intersectSDF(float distA, float distB) {
    return max(distA, distB);
}

/**
 * Constructive solid geometry union operation on SDF-calculated distances.
 */
 float unionSDF(float distA, float distB) {
	return min(distA, distB);
 }

 /**
 * Constructive solid geometry difference operation on SDF-calculated distances.
 */
 float differenceSDF(float distA, float distB) {
	return max(distA, -distB);
 }

 float displacement(vec3 p) {
	return sin(5*p.x) * sin(5*p.y) * sin(5*p.z);
}

 /**
 * Signed distance function for a cube centered at the origin
 * with width = height = length = 2.0
 */
float cubeSDF(vec3 p, vec3 dims) {
    // If d.x < 0, then -1 < p.x < 1, and same logic applies to p.y, p.z
    // So if all components of d are negative, then p is inside the unit cube
    vec3 d = abs(p) - dims;
    
    // Assuming p is inside the cube, how far is it from the surface?
    // Result will be negative or zero.
    float insideDistance = min(max(d.x, max(d.y, d.z)), 0.0);
    
    // Assuming p is outside the cube, how far is it from the surface?
    // Result will be positive or zero.
    float outsideDistance = length(max(d, 0.0));
    
    return insideDistance + outsideDistance;
}

/**
 * Signed distance function for a cube centered at the origin
 * with width = height = length = 2.0
 */
float cubeSDF(vec3 p) {
    return cubeSDF(p, vec3(1, 1, 1));
}

/**
 * Signed distance function for a sphere centered at the origin with radius 1.0
 */
float sphereSDF(vec3 p, float r, vec3 centerP) {
    return length(p - centerP) - r;
}

/**
 * Creates a torus using two points
 */
float torusSDF(vec3 p1)
{
	vec3 p2 = p1 * 2;
	vec2 q = vec2(length(p1.xz)-p2.x,p1.y);
	return length(q)-p2.y;	// FIXME - does not seem to render object at all
}

/**
 * Creates a plane with a given normal vector n
 */
float planeSDF( vec3 p, vec4 n ) {
  // n must be normalized
  return dot(p,n.xyz) + n.w;
}

/**
 * Creates one instance of a unique shape
 */
 float nodeSDF(vec3 p) {
	// matrix of tunnels
	float tunnel1Dist = sphereSDF(p, 1.35, vec3(0, 0, 0));
	float tunnel2Dist = cubeSDF(p);
	float tunnelDist =  differenceSDF(tunnel2Dist,tunnel1Dist);

	// center style object
	float styleSphereDist = sphereSDF(p, .125, vec3(0));
	float styleDist = styleSphereDist + .2*displacement(p);
	
	return unionSDF(tunnelDist, styleDist);
}

/**
 * Creates multiple spheres by reusing (or instancing) objects using the modulo operation.
 */
float multiNodesSDF(vec3 p) {
  p.xyz = mod(p.xyz, 2.0)-vec3(1);		// instance on xyz-plane
  return nodeSDF(p);             // node distance estimate
}


/**
 * Signed distance function describing the scene.
 * 
 * Absolute value of the return value indicates the distance to the surface.
 * Sign indicates whether the point is inside or outside the surface,
 * negative indicating inside.
 */
float sceneSDF(vec3 samplePoint) {
	float matrixDist = multiNodesSDF(samplePoint);
	//float centerPoint = sphereSDF(samplePoint, 0.1, vec3(1, 1, 1));
	
	//return min(matrixDist, centerPoint);
	return matrixDist;
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
    const vec3 ambientLight = 0.5 * vec3(1.0, 1.0, 1.0);
    vec3 color = ambientLight * k_a;
    
	// center light
	vec3 centerLightPos = vec3(.5*cos(3.0*time), cos(.25*time), sin(.5*time));
	vec3 centerLightIntensity = vec3(sin(time));
	color += phongContribForLight(k_d, k_s, alpha, p, eye, centerLightPos, centerLightIntensity);

	// orbit lights
	vec3 orbitLightPos = vec3(cos(3.0*time), cos(3.0*time), sin(3.0*time));
	vec3 orbitLight1Intensity = vec3(0.8, 0.8, 0.8);
	color += phongContribForLight(k_d, k_s, alpha, p, eye, orbitLightPos, orbitLight1Intensity);
    
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


void main()
{
	vec3 viewDir = rayDirection(75.0, vec2(windowWidth, windowHeight), gl_FragCoord.xy);
    vec3 eye = vec3(1.25, 1.25, 20.0-time);
    
    mat4 viewToWorld = viewMatrix(eye, vec3(1.0, 1.0, 1-time), vec3(0.0, 1.0, 0.0));
    
    vec3 worldDir = (viewToWorld * vec4(viewDir, 0.0)).xyz;
    
    float dist = shortestDistanceToSurface(eye, worldDir, MIN_DIST, MAX_DIST);
    
    if (dist > MAX_DIST - EPSILON) {
        // Didn't hit anything
		// ground
		if ( viewDir.y < 0.0) {
			gl_FragColor = vec4(0.3, 0.3, 0.3, 1.0); // dark grey
			return;
		}
		// sky
        gl_FragColor = vec4(0.0, 0.0, 0.0, 0.8); // blue
		return;
    }
    
    // The closest point on the surface to the eyepoint along the view ray
    vec3 p = eye + dist * worldDir;
    
    vec3 K_a = vec3(0.2, 0.2, 0.2);
    vec3 K_d = vec3(.6*sin(time)+.3, .6*sin(time*2)+.3, .6*sin(time*3)+.3);
    vec3 K_s = vec3(1.0, 1.0, 1.0);
    float shininess = 1000.0;
    
    vec3 color = phongIllumination(K_a, K_d, K_s, shininess, p, eye);
    
    gl_FragColor = vec4(color, 1.0);
}