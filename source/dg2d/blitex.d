/*
  This module contains some helper functions for the blitter modules.

  Copyright: Chris Jones
  License: Boost Software License, Version 1.0
  Authors: Chris Jones
*/

module dg2d.blitex;

import dg2d.misc;
import dg2d.rasterizer;

immutable __m128i XMZERO = 0;
immutable __m128i XMFFFF = 0xFFFF;
immutable __m128i XM7FFF = 0x7FFF;
immutable __m128i XMABSMASK = 0x7fffffff;
immutable __m128i XMSIGNMASK = 0x80000000;

public:

/*
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
        ipos = ipos & _mm_cmpgt_epi32(ipos, XMZERO);
        return (ipos | _mm_cmpgt_epi32(ipos, lutmsk)) & lutmsk;
    }
    else
    {
        return (ipos ^ _mm_cmpgt_epi32(ipos & lutmsk2, lutmsk)) & lutmsk;
    }
}

/*
  calculate coverage from winding value
*/

int calcCoverage(WindingRule rule)(int winding)
{
    static if (rule == WindingRule.NonZero)
    {
        int tmp = abs(winding)*2;
        return (tmp > 0xFFFF) ? 0xFFFF : tmp;
    }
    else
    {
        short tmp = cast(short) winding;
        return (tmp ^ (tmp >> 15)) * 2;
    }
}

/*
  calculate coverage from winding value
  incoming 4x int32
  outgoing 4x int16, in lower 64 bits of return val
*/

__m128i calcCoverage16(WindingRule rule)(__m128i winding)
{
    static if (rule == WindingRule.NonZero)
    {
        __m128i absmask = _mm_srai_epi32(winding,31); 
        __m128i tmp = _mm_xor_si128(winding,absmask); // abs technically off by one, but irrelevant
        tmp = _mm_packs_epi32(tmp,tmp);               // saturate/pack to int16
        return _mm_slli_epi16(tmp, 1);                // << to uint16
    }
    else
    {
        winding = _mm_and_si128(winding,XMFFFF);
        __m128i mask = _mm_srai_epi16(winding,15);
        __m128i tmp = _mm_xor_si128(winding,mask);  // if bit 31 set, we xor all other bits
        tmp = _mm_packs_epi32(tmp,tmp);             // saturate/pack to int16
        return _mm_slli_epi16(tmp, 1);              // << to uint16
    } 
}

/*
  calculate coverage from winding value
  incoming 4x int32
  outgoing 4x int32, coverage is returned in high 16 bits of each 32 bits, 
*/

__m128i calcCoverage32(WindingRule rule)(__m128i winding)
{
    static if (rule == WindingRule.NonZero)
    {
        __m128i absmsk = _mm_srai_epi32(winding,31);
        __m128i tmp = _mm_xor_si128(winding,absmsk); // abs technically off by one, but irrelevant
        tmp = _mm_packs_epi32(tmp,tmp);              // saturate/pack to int16
        tmp = _mm_unpacklo_epi16(tmp,tmp);   
        return _mm_slli_epi16(tmp,1);                // << to top 16 bits of each 32 bit word
        
    }
    else
    {
        __m128i mask = _mm_srai_epi16(winding,15);
        __m128i tmp = _mm_xor_si128(winding,mask);  // if bit 16 set, we xor all other bits
        return _mm_slli_epi32(tmp, 17);             // << to top 16 bits of each 32 bit word
    }
}


/* NEW BLEND DEV WORK

  put Color0 and Color1, in low 64 bits of R128
  then unpack low interleaved with itself,
  so each byte becomes 16 bits => (b << 8) | b 
  this is the same as multiplying by 257, essentialy converts 0..FF, into 0..FFFF

  c = _mm_unpacklo_epi8 (c,c);

  then for alpha...

  alpha = _mm_shufflelo_epi16!255(c);
  alpha = _mm_shufflehi_epi16!255(alpha);

  that gives

  c = [BB0,GG0,RR0,AA0,BB1,GG1,RR1,AA1]
  alpha = [AA0,AA0,AA0,AA0,AA1,AA1,AA1,AA1]

*/

