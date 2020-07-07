/**
  This module contains some helper functions for the blitter modules.

  Copyright: Chris Jones
  License: Boost Software License, Version 1.0
  Authors: Chris Jones
*/

module dg2d.blitex;

import dg2d.misc;
import dg2d.rasterizer;

/**
  Calculate the gradient index for given repeat mode 
*/

__m128i calcRepeatModeIDX(RepeatMode mode)(__m128i ipos, __m128i lutmsk, __m128i lutmsk2)
{
    static if (mode == RepeatMode.Repeat)
    {
        return ipos & lutmsk;
    }
    else static if (mode == RepeatMode.Pad)
    {
        enum __m128i XMZERO = [0,0,0,0]; // Needed because DMD sucks balls
        ipos = ipos & _mm_cmpgt_epi32(ipos, XMZERO);
        return (ipos | _mm_cmpgt_epi32(ipos, lutmsk)) & lutmsk;
    }
    else
    {
        return (ipos ^ _mm_cmpgt_epi32(ipos & lutmsk2, lutmsk)) & lutmsk;
    }
}

/**
  broadcast alpha

  x is [A2,R2,G2,B2,A1,R1,G1,B1], 16 bit per channel but only low 8 bits used 
  returns [A2,A2,A2,A2,A1,A1,A1,A1], all 16 bits used
  shuffleVector version (commented out) should lower to pshufb, but it is a bit slower on
  my CPU, maybe from increased register pressure?
*/

__m128i _mm_broadcast_alpha(__m128i x)
{
    x = _mm_shufflelo_epi16!255(x);
    x = _mm_shufflehi_epi16!255(x);
    return _mm_slli_epi16(x,8);
//    return  cast(__m128i)
//        shufflevector!(byte16, 7,6,7,6,7,6,7,6,  15,14,15,14,15,14,15,14)
//            (cast(byte16)a, cast(byte16)a);
}

