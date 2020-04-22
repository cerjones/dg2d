DG2D -- D Graphics 2D

Consists of 3 parts...

Rasterizer, a high performance software rasterizer.
Geometry, points, rects, paths, etc...
Font, very basic font parser, pretty much just pulls glyphs from truetype font files atm.

Performance:

Best performance is with LDC, you also need link time optimization on, or cross module inlining enabled. This is so that the intel intrinsics get inlined properly.

Its ony single threaded at the moment.

limitations / requirements:

The rasterizer only works with 32 bits per pixel, and scanlines must be 16 byte aligned. 
Requires x86 SSE2
Requires "intel-intrinsics" by AuburnSounds

Todo / Goals (in no particular order):

Plain D blitters, so the rasterizer will work on any CPU.

Improve font support. I see the font stuff as just a facility to extract the data from font files, font picking and text layout is out of this project scope i think.
 
Fast font rendering and auto hinting. I have a couple of ideas to make font rendering much faster. Id like to explore auto hinting.

Expand geometry features, stoking, other shape primatives. 

Other blend modes, eg Porter Duff etc... Not yet figured a sensible way to do this that would not either be slow, or result in vast amounts of generated code.

Multithreaded rendering. I have 2 potential ideas for implementing this.

