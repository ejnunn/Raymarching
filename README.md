# Raymarching

An OpenGL implementation of the 'Raymarching' signed-distance technique used to generate an animation of a camera flying through an endless cityscape.

All animations were created in the Pixel Shader. No triangles needed.

One block of buildings is comprised of 3 buildings each with a unique height. This block is then tessilated along the xz-plane, creating an endless sea of buildings.
