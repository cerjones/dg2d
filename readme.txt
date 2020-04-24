DG2D - 2D vector graphics rendering library for the D programming language.

Features:

Fills abitrary paths, with lines, quads and cubics.
Solid fill, line gradient, radial gradient and angular gradient.
Very basic font rendering. (Just pulls glyphs from a truetype file atm)
Some geometry, points, rects, paths.
Very fast, high performance rasterizer with SIMD support.

Its very early days in terms of features but you can draw stuff!

Performance:

Best performance is with LDC, you need link time optimization on, or cross module inlining enabled. This is so that the intel intrinsics get inlined properly.

Its single threaded at the moment. So if you run the demo the FPS is for one core.

limitations / requirements:

The rasterizer only works with 32 bits per pixel, and scanlines must be 16 byte aligned. 
Requires x86 SSE2
Requires "intel-intrinsics" by AuburnSounds

Todo / Goals (in no particular order):

Plain D blitters, so the rasterizer will work on any CPU.

Improve font support: Expand supported trutype features. I also have a couple of ideas to make font rendering much faster. Id like to explore auto hinting.

Expand geometry features, stroking, other shape primatives. 

Other blend modes, eg Porter Duff etc... Not yet figured a sensible way to do this that would not either be slow, or result in vast amounts of generated code.

Multithreaded rendering. I have 2 potential ideas for implementing this.

Image support, pattern fills.

Rounded rectangle shader. Essentialy a kind of gradient fill where the distance from the perimeter is used to index the gradient.