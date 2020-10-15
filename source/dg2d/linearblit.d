/**
  Blitter for painting linear gradients.

  Copyright Chris Jones 2020.
  Distributed under the Boost Software License, Version 1.0.
  See accompanying file Licence.txt or copy at...
  https://www.boost.org/LICENSE_1_0.txt
*/

module dg2d.linearblit;

import dg2d.rasterizer;
import dg2d.gradient;
import dg2d.misc;
import dg2d.blitex;

/*
   Linear gradient blitter struct.

   You set up the properties and pass the BlitFunc to the rasterizer.

   ---
   auto ablit = AngularBlit(m_pixels,m_stride,m_height);
   ablit.setPaint(grad, wr, RepeatMode.Mirror, 4.0f);
   ablit.setElipse(x0,y0,x1,y1,x2,y2);
   m_rasterizer.rasterize(ablit.getBlitFunc);
   ---
*/


struct LinearBlit
{  
    /** Construct an linear gradient blitter.
    pixels - pointer to a 32 bpp pixel buffer
    stride - buffer width in pixels
    height - buffer heigth in pixels

    note: buffer must be 16 byte aligned, stride must be multiple of 4
    */

    this(uint* pixels, int stride, int height)
    {
        assert(((cast(uint)pixels) & 15) == 0); // must be 16 byte aligned
        assert((stride & 3) == 0);              // stride must be 16 byte aligned
        assert(height > 0);
        this.pixels = pixels;
        this.stride = stride;
        this.height = height;
    }

    /** set the gradient, winding rule and repeat mode.
    */

    void setPaint(Gradient grad, WindingRule wrule, RepeatMode rmode)
    {
        assert(grad !is null);
        assert(isPow2(grad.lookupLength));
        gradient = grad;
        windingRule = wrule;
        repeatMode = rmode;
    }

    /** Set the coordinates for the start and end point of the linear gradient.
    */

    void setCoords(float x0, float y0, float x1, float y1)
    {
        xctr = x0;
        yctr = y0;
        float w = x1-x0;
        float h = y1-y0;
        float hsq = w*w + h*h;
        if (hsq < 0.1) hsq = 0.1; // avoid div by zero
        xstep = gradient.lookupLength * w / hsq; 
        ystep = gradient.lookupLength * h / hsq;
    }

    /** returns a BlitFunc for use by the rasterizer */

    BlitFunc getBlitFunc() return
    {
        if (windingRule == WindingRule.NonZero)
        {
            switch(repeatMode)
            {
                case RepeatMode.Pad: return &linear_blit!(WindingRule.NonZero,RepeatMode.Pad);
                case RepeatMode.Repeat: return &linear_blit!(WindingRule.NonZero,RepeatMode.Repeat);
                case RepeatMode.Mirror: return &linear_blit!(WindingRule.NonZero,RepeatMode.Mirror);
                default: assert(0);
            }
        }
        else
        {
            switch(repeatMode)
            {
                case RepeatMode.Pad: return &linear_blit!(WindingRule.EvenOdd,RepeatMode.Pad);
                case RepeatMode.Repeat: return &linear_blit!(WindingRule.EvenOdd,RepeatMode.Repeat);
                case RepeatMode.Mirror: return &linear_blit!(WindingRule.EvenOdd,RepeatMode.Mirror);
                default: assert(0);
            }
        }
    }

private:

    void linear_blit(WindingRule wr, RepeatMode mode)(int* delta, DMWord* mask, int x0, int x1, int y)
    {
        assert( ( cast(size_t)delta & 15 ) == 0 );
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
        uint* lut = gradient.getLookup.ptr;
        __m128i lutmsk = gradient.lookupLength - 1;
        __m128i lutmsk2 = gradient.lookupLength*2 - 1;

        // XMM constants

        immutable __m128i XMZERO = 0;

        // paint variables

        float t0 = (bpos*4-xctr)*xstep + (y-yctr)*ystep;
        __m128 xmT0 = _mm_mul_ps(_mm_set1_ps(xstep), _mm_setr_ps(0.0f,1.0f,2.0f,3.0f));
        xmT0 = _mm_add_ps(xmT0, _mm_set1_ps(t0));
        __m128 xmStep0 = _mm_set1_ps(xstep*4);

        // main loop

        while (bpos < endbit)
        {
            int nsb = nextSetBit(mask, bpos, endbit);

            // do we have a span of unchanging coverage?

            if (bpos < nsb)
            {
                // Calc coverage of first pixel

                int cover = calcCoverage!wr(xmWinding[3]+delta[bpos*4]);

                // We can skip the span

                if (cover < 0x100)
                {
                    __m128 xskip = _mm_set1_ps(nsb-bpos);
                    xmT0 = _mm_add_ps(xmT0, _mm_mul_ps(xskip,xmStep0));
                    bpos = nsb;
                }

                // Or fill span with soid color

                else if (gradient.isOpaque && (cover > 0xFF00))
                {
                    uint* ptr = &dest[bpos*4];
                    uint* end = ptr + ((nsb-bpos)*4);

                    while (ptr < end)
                    {
                        __m128i ipos = _mm_cvtps_epi32 (xmT0);
                        xmT0 = xmT0 + xmStep0;

                        ipos = calcRepeatModeIDX!mode(ipos, lutmsk, lutmsk2);

                        ptr[0] = lut[ipos.array[0]];
                        ptr[1] = lut[ipos.array[1]];
                        ptr[2] = lut[ipos.array[2]];
                        ptr[3] = lut[ipos.array[3]];

                        ptr+=4;                        
                    }

                    bpos = nsb;
                }

                // Or fill span with transparent color

                else
                {
                    __m128i xmcover = _mm_set1_epi16 (cast(ushort) cover);

                    uint* ptr = &dest[bpos*4];
                    uint* end = &dest[nsb*4];

                    while (ptr < end)
                    {
                        __m128i ipos = _mm_cvtps_epi32 (xmT0);
                        xmT0 = xmT0 + xmStep0;

                        ipos = calcRepeatModeIDX!mode(ipos, lutmsk, lutmsk2);

                        // load destinatin pixels

                        __m128i d0 = _mm_load_si128(cast(__m128i*)ptr);
                        __m128i d1 = _mm_unpackhi_epi8(d0,d0);
                        d0 = _mm_unpacklo_epi8(d0,d0);

                        // load grad colors and alpha

                        __m128i c0 = _mm_loadu_si32 (&lut[ipos.array[0]]);
                        __m128i tmpc0 = _mm_loadu_si32 (&lut[ipos.array[1]]);
                        c0 = _mm_unpacklo_epi32 (c0, tmpc0);
                        c0 = _mm_unpacklo_epi8 (c0, c0);
                        
                        __m128i a0 = _mm_mulhi_epu16(c0,xmcover);

                        __m128i c1 = _mm_loadu_si32 (&lut[ipos.array[2]]);
                        __m128i tmpc1 = _mm_loadu_si32 (&lut[ipos.array[3]]);
                        c1 = _mm_unpacklo_epi32 (c1, tmpc1);
                        c1 = _mm_unpacklo_epi8 (c1, c1);

                        __m128i a1 = _mm_mulhi_epu16(c1,xmcover);

                        // unpack alpha

                        a0 = _mm_shufflelo_epi16!255(a0);
                        a0 = _mm_shufflehi_epi16!255(a0);
                        a1 = _mm_shufflelo_epi16!255(a1);
                        a1 = _mm_shufflehi_epi16!255(a1);

                       // alpha*source + dest - alpha*dest

                        c0 = _mm_mulhi_epu16 (c0,a0);
                        c1 = _mm_mulhi_epu16 (c1,a1);
                        c0 = _mm_add_epi16 (c0,d0);
                        c1 = _mm_add_epi16 (c1,d1);
                        d0 = _mm_mulhi_epu16 (d0,a0);
                        d1 = _mm_mulhi_epu16 (d1,a1);
                        c0 =  _mm_sub_epi16 (c0,d0);
                        c1 =  _mm_sub_epi16 (c1,d1);
                        c0 = _mm_srli_epi16 (c0,8);
                        c1 = _mm_srli_epi16 (c1,8);

                        d0 = _mm_packus_epi16 (c0,c1);

                        _mm_store_si128 (cast(__m128i*)ptr,d0);
                        
                        ptr+=4;
                    }

                    bpos = nsb;
                }
            }

            // At this point we need to integrate scandelta

            uint* ptr = &dest[bpos*4];
            uint* end = &dest[endbit*4];
            int* dlptr = &delta[bpos*4];

            while (bpos < endbit)
            {
                // Integrate delta values

                __m128i idv = _mm_load_si128(cast(__m128i*)dlptr);
                idv = _mm_add_epi32(idv, _mm_slli_si128!4(idv)); 
                idv = _mm_add_epi32(idv, _mm_slli_si128!8(idv)); 
                idv = _mm_add_epi32(idv, xmWinding); 
                xmWinding = _mm_shuffle_epi32!255(idv);  
                _mm_store_si128(cast(__m128i*)dlptr,XMZERO);

                // calculate coverage from winding

                __m128i xmcover = calcCoverage32!wr(idv);

                // convert grad pos to integer

                __m128i ipos = _mm_cvtps_epi32 (xmT0);
                xmT0 = xmT0 + xmStep0;

                ipos = calcRepeatModeIDX!mode(ipos, lutmsk, lutmsk2);

                // Load destination pixels
               
                __m128i d0 = _mm_load_si128(cast(__m128i*)ptr);
                __m128i d1 = _mm_unpackhi_epi8(d0,d0);
                d0 = _mm_unpacklo_epi8(d0,d0);

                // load grad colors and alpha

                __m128i c0 = _mm_loadu_si32 (&lut[ipos.array[0]]);
                __m128i tmpc0 = _mm_loadu_si32 (&lut[ipos.array[1]]);
                c0 = _mm_unpacklo_epi32 (c0, tmpc0);
                c0 = _mm_unpacklo_epi8 (c0, c0);

                __m128i a0 = _mm_unpacklo_epi32(xmcover,xmcover);
                a0 = _mm_mulhi_epu16(a0, c0);

                __m128i c1 = _mm_loadu_si32 (&lut[ipos.array[2]]);
                __m128i tmpc1 = _mm_loadu_si32 (&lut[ipos.array[3]]);
                c1 = _mm_unpacklo_epi32 (c1, tmpc1);
                c1 = _mm_unpacklo_epi8 (c1, c1);

                __m128i a1 = _mm_unpackhi_epi32(xmcover,xmcover);
                a1 = _mm_mulhi_epu16(a1, c1);

                // unpack alpha

                a0 = _mm_shufflelo_epi16!255(a0);
                a0 = _mm_shufflehi_epi16!255(a0);
                a1 = _mm_shufflelo_epi16!255(a1);
                a1 = _mm_shufflehi_epi16!255(a1);

                // alpha*source + dest - alpha*dest

                c0 = _mm_mulhi_epu16 (c0,a0);
                c1 = _mm_mulhi_epu16 (c1,a1);
                c0 = _mm_add_epi16 (c0,d0);
                c1 = _mm_add_epi16 (c1,d1);
                d0 = _mm_mulhi_epu16 (d0,a0);
                d1 = _mm_mulhi_epu16 (d1,a1);
                c0 =  _mm_sub_epi16 (c0, d0);
                c1 =  _mm_sub_epi16 (c1, d1);
                c0 = _mm_srli_epi16 (c0,8);
                c1 = _mm_srli_epi16 (c1,8);

                d0 = _mm_packus_epi16 (c0,c1);

                _mm_store_si128 (cast(__m128i*)ptr,d0);
                
                bpos++;
                ptr+=4;
                dlptr+=4;

                if (((cast(ulong*)dlptr)[0] | (cast(ulong*)dlptr)[1]) == 0)  break;
            }
        }
    }

    // Member variables

    uint* pixels;
    int stride;
    int height;
    float xctr,yctr,xstep,ystep;
    Gradient gradient;
    WindingRule windingRule;
    RepeatMode repeatMode;
}


