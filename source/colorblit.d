/**
  Blitter for painting solid color.

  Copyright Chris Jones 2020.
  Distributed under the Boost Software License, Version 1.0.
  See accompanying file Licence.txt or copy at...
  https://www.boost.org/LICENSE_1_0.txt
*/


module dg2d.colorblit;

import dg2d.rasterizer;
import dg2d.misc;
import dg2d.blitex;

/**
   Color blitter struct

   You set up the properties and pass the BlitFunc to the rasterizer.

   ---
   auto cblit = AngularBlit(m_pixels,m_stride,m_height);
   cblit.setColor(color);
   m_rasterizer.rasterize(cblit.getBlitFunc);
   ---
*/

struct ColorBlit
{   
    /** Construct an color blitter.
    pixels - pointer to a 32 bpp pixel buffer
    stride - buffer width in pixels
    height - buffer heigth in pixels

    note: buffer must be 16 byte aligned, stride must be multiple of 4
    */

    this(uint* pixels, int stride, int height)
    {
        assert(((cast(uint)pixels) & 15) == 0); // must be 16 byte alligned
        assert((stride & 3) == 0);              // stride must be 16 byte alligned
        assert(height > 0);

        this.pixels = pixels;
        this.stride = stride;
        this.height = height;
    }

    /** set the colour to blit */

    void setColor(uint color)
    {
        this.color = color;
    }

    /** returns a BlitFunc for use by the rasterizer */

    BlitFunc getBlitFunc(WindingRule rule) return
    {
        if (rule == WindingRule.NonZero)
        {
            return &color_blit!(WindingRule.NonZero);
        }
        else
        {
            return &color_blit!(WindingRule.EvenOdd);
        }
    }

private:

    void color_blit(WindingRule rule)(int* delta, DMWord* mask, int x0, int x1, int y)
    {
        assert(x0 >= 0);
        assert(x1 <= stride);
        assert(y >= 0);
        assert(y < height);
        assert((x0 & 3) == 0);
        assert((x1 & 3) == 0);

        // main blit variables

        int bpos = x0 / 4;
        int endbit = x1 / 4;
        uint* dest = &pixels[y*stride];
        __m128i xmWinding = 0;
        bool isopaque = (color >> 24) == 0xFF;

        // XMM constants

        immutable __m128i XMZERO = 0;
        immutable __m128i XMFFFF = 0xFFFFFFFF;

        // paint variables

        __m128i xmColor = _mm_loadu_si32 (&color);
        xmColor = _mm_unpacklo_epi8 (xmColor, xmColor);
        xmColor = _mm_unpacklo_epi64 (xmColor, xmColor);
        __m128i xmAlpha = _mm_set1_epi16 (cast(ushort) ((color >> 24) * 257));

        // main loop

        while (bpos < endbit)
        {
            int nsb = nextSetBit(mask, bpos, endbit);

            // do we have a span of unchanging coverage?

            if (bpos < nsb)
            {
                // Calc coverage of first pixel

                int cover = calcCoverage!rule(xmWinding[3]+delta[bpos*4]);

                // We can skip the span

                if (cover < 0x100)
                {
                    bpos = nsb;
                }

                // Or fill span with soid color

                else if (isopaque && (cover > 0xFF00))
                {
                    __m128i tqc = _mm_set1_epi32(color);

                    uint* ptr = &dest[bpos*4];
                    uint* end = &dest[nsb*4];

                    while (ptr < end)
                    {
                        _mm_store_si128(cast(__m128i*)ptr, tqc);
                        ptr+=4;                        
                    }

                    bpos = nsb;
                }

                // Or fill the span with transparent color

                else
                {
                    __m128i tsalpha = _mm_set1_epi16(cast(ushort) cover); 
                    tsalpha = _mm_mulhi_epu16(xmAlpha,tsalpha);
                    __m128i tscolor = _mm_mulhi_epu16(xmColor,tsalpha);
                    tsalpha  = tsalpha ^ XMFFFF;               // 1-alpha
         
                    uint* ptr = &dest[bpos*4];
                    uint* end = &dest[nsb*4];

                    while (ptr < end)
                    {
                        __m128i d0 = _mm_load_si128(cast(__m128i*)ptr);
                        __m128i d1 = _mm_unpackhi_epi8(d0,d0);
                        d0 = _mm_unpacklo_epi8(d0,d0);
                        d0 = _mm_mulhi_epu16(d0,tsalpha);
                        d1 = _mm_mulhi_epu16(d1,tsalpha);
                        d0 = _mm_add_epi16(d0,tscolor);
                        d0 = _mm_srli_epi16(d0,8);
                        d1 = _mm_add_epi16(d1,tscolor);
                        d1 = _mm_srli_epi16(d1,8);                       
                        d0 = _mm_packus_epi16(d0,d1);
                        _mm_store_si128(cast(__m128i*)ptr,d0);
                        ptr+=4;
                    }

                    bpos = nsb;
                }
            }

            // At this point we need to integrate scandelta

            uint* ptr = &dest[bpos*4];
            uint* end = &dest[endbit*4];
            int* dlptr = &delta[bpos*4];

            while (ptr < end)
            {
                // Integrate delta values

                __m128i idv = _mm_load_si128(cast(__m128i*)dlptr);
                idv = _mm_add_epi32(idv, _mm_slli_si128!4(idv)); 
                idv = _mm_add_epi32(idv, _mm_slli_si128!8(idv)); 
                idv = _mm_add_epi32(idv, xmWinding); 
                xmWinding = _mm_shuffle_epi32!255(idv);  
                _mm_store_si128(cast(__m128i*)dlptr,XMZERO);

                // calculate coverage from winding

                __m128i xmcover = calcCoverage!rule(idv);

                // Load destination pixels

                __m128i d0 = _mm_load_si128(cast(__m128i*)ptr);
                __m128i d1 = _mm_unpackhi_epi8(d0,d0);
                d0 = _mm_unpacklo_epi8(d0,d0);

                // muliply source alpha & coverage

                __m128i a0 = _mm_mulhi_epu16(xmcover,xmAlpha);
                a0 = _mm_unpacklo_epi16(a0,a0); 
                __m128i a1 = _mm_unpackhi_epi32(a0,a0);
                a0 = _mm_unpacklo_epi32(a0,a0);

                // r = alpha*color + dest - alpha*dest

                __m128i r0 = _mm_mulhi_epu16(xmColor,a0);
                r0 = _mm_add_epi16(r0, d0);
                d0 = _mm_mulhi_epu16(d0,a0);
                r0 = _mm_sub_epi16(r0, d0);
                r0 = _mm_srli_epi16(r0,8);

                __m128i r1 = _mm_mulhi_epu16(xmColor,a1);
                r1 = _mm_add_epi16(r1, d1);
                d1 = _mm_mulhi_epu16(d1,a1);
                r1 = _mm_sub_epi16(r1, d1);
                r1 = _mm_srli_epi16(r1,8);

                __m128i r01 = _mm_packus_epi16(r0,r1);

                _mm_store_si128(cast(__m128i*)ptr,r01);
                
                bpos++;
                ptr+=4;
                dlptr+=4;

                if (((cast(ulong*)dlptr)[0] | (cast(ulong*)dlptr)[1]) == 0) break;
            }
        }
    }

    uint* pixels;
    int stride;
    int height;
    uint color;
}
