/*
  Copyright Chris Jones 2020.
  Distributed under the Boost Software License, Version 1.0.
  See accompanying file Licence.txt or copy at...
  https://www.boost.org/LICENSE_1_0.txt
*/

module dg2d.blend;

import dg2d.rasterizer;
import dg2d.misc;

/*
    How to to seperate blend modes from blitting? some way to mixin blend code
    into a blitter?

    Main downside is maybe 5 blitters, 2 fill rules, 2 or 3 repeat modes, 20 to 30 
    blend modes ==> 800 variations. 

    Last I checked blitter code is clocking in at about 1k, so do you want to
    bundle 1MB of blitter code, how long would that take to compile etc???

    Might be nice to be able to have control such that some permutations get specific
    implementation, some are handled by a generic function.

    Need to specify context for blend mixin...

    Pixel / blend variable formats...

    ARGB, alpha, red, green, blue
    XRGB, unused, red, green, blue
    AAAA, alpha, alpha, alpha, alpha

    left most component is in MSB, rightmost is in LSB.

    Most components will be 16 bits, but they will usually have been converted from an
    8 bit source, so sometimes they may have different representation in 16 bit...

    MSB16, component uses all 16 bits.
    LSB16, component uses lower 8 bits, upper 8 bits are zero

    If more than one pixel is in an __m128i then the LSB holds the leftmost pixel and
    the MSB holds the rightmost.

    blend code expects these variables defineded in the scope it is injected into
    
    __m128i d0,d1 : 4 destination pixels, ARGB or XRGB, LSB16
    __m128i c0,c1 : 4 source colours, XRGB, MSB16
    __m128i a0,a0 : 4 blend alphas, AAAA, MSB16

    if a blend mode needs destination alpha it should unpack it from the destination
    pixels itself.

    the source alpha is unpacked and multiplied by the coverage, this gives the final
    source alpha.

    ===========

    If we just consider "clip to source" and a destination
    that has no alpha we need to handle these situations....

    source coverage is 0%, just skip the pixels

    source coverage is 100%, do a solid fill

    source coverage is > 0% and < 100%, blended fill

    source coverage changes, delta fill

*/
/*
struct SourceOver_XRGB
{
    string initVars() // blemd masks
    {
    }

    // if provided can be used when alpha = 100%
    // context code sets 's0' ahead

    string opaqueFill()
    {
        return " __m128i r0 = s0; ";
    }

    // if provided can be used when alpha inbetween 0%..100%
    // context code sets 's0' ahead

    string semiFill()
    {
        d0 = _mm_mulhi_epu16 (d0,a0);
        d1 = _mm_mulhi_epu16 (d1,a1);
        d0 = _mm_packus_epi16 (d0,d1);
        d0 = _mm_adds_epi8 (d0, s0);
    }


    string blend() // regular blend, no premultiplication
    {
        d0 = _mm_mulhi_epu16 (d0,a0);
        d1 = _mm_mulhi_epu16 (d1,a1);
        d0 = _mm_packus_epi16 (d0,d1);
        d0 =  _mm_adds_epi8 (d0, s0);
    }
}
*/
/*
auto getBlendStuff(bool destHasAlpha, bool clipToSource, string opName)
{
    if (opName = "SrcOver")
    {
        if 

    }




}
*/
