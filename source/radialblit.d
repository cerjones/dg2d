/*
  Blitter for painting radial gradients.

  Copyright Chris Jones 2020.
  Distributed under the Boost Software License, Version 1.0.
  See accompanying file Licence.txt or copy at...
  https://www.boost.org/LICENSE_1_0.txt
*/

module dg2d.radialblit;

import dg2d.rasterizer;
import dg2d.gradient;
import dg2d.misc;
import dg2d.blitex;

/**
   Radial gradient blitter struct.

   You set up the properties and pass the BlitFunc to the rasterizer.

   ---
   auto ablit = RadialBlit(m_pixels,m_stride,m_height);
   rblit.setPaint(grad, wr, RepeatMode.Pad);
   rblit.setCoords(x0,y0,x1,y1,x2,y2);
   m_rasterizer.rasterize(rblit.getBlitFunc);
   ---
*/

struct RadialBlit
{
    /** Construct a Radial blitter.
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

    /** set the gradient, winding rule and repeat mode. "numRepeats" sets how many times
    the gradient repeats in 360 degrees.
    */

    void setPaint(Gradient grad, WindingRule wrule, RepeatMode rmode)
    {
        assert(grad !is null);
        assert(isPow2(gradient.lookupLength));
        gradient = grad;
        windingRule = wrule;
        repeatMode = rmode;
    }
  
    /** Specifiy the orientation in terms of an elipse, for that we need 3 points...
    (x0,y0) is the center of the elipse
    (x1,y1) is radius at 0 degrees
    (x2,y2) is radius at 90 degrees
    The radii dont need to be at right angles, so it can handle elipse that has been
    though any affine transform.
    */

    void setElipse(float x0, float y0, float x1, float y1, float x2, float y2)
    {
        xctr = x0;
        yctr = y0;
        float w0 = x1-x0;
        float h0 = y1-y0;
        float hyp0 = w0*w0 + h0*h0;
        if (hyp0 < 0.1) hyp0 = 0.1;
        xstep0 = gradient.lookupLength * w0 / hyp0;
        ystep0 = gradient.lookupLength * h0 / hyp0;
        float w1 = x2-x0;
        float h1 = y2-y0;
        float hyp1 = w1*w1 + h1*h1;
        if (hyp1 < 0.1) hyp1 = 0.1;
        xstep1 = gradient.lookupLength * w1 / hyp1;
        ystep1 = gradient.lookupLength * h1 / hyp1;
    }

    /** Specifiy the orientation in terms of an circle, for that we need two points,
    (x0,y0) is the center of the circle
    (x1,y1) is radius at 0 degrees
    */

    void setCircle(float x0, float y0, float x1, float y1)
    {
        setElipse(x0,y0,x1,y1,x0-y1+y0,y0+x1-x0);
    }

    /** returns a BlitFunc for use by the rasterizer */

    BlitFunc getBlitFunc() return
    {
        if (windingRule == WindingRule.NonZero)
        {
            switch(repeatMode)
            {
                case RepeatMode.Pad: return &radial_blit!(WindingRule.NonZero,RepeatMode.Pad);
                case RepeatMode.Repeat: return &radial_blit!(WindingRule.NonZero,RepeatMode.Repeat);
                case RepeatMode.Mirror: return &radial_blit!(WindingRule.NonZero,RepeatMode.Mirror);
                default: assert(0);
            }
        }
        else
        {
            switch(repeatMode)
            {
                case RepeatMode.Pad: return &radial_blit!(WindingRule.EvenOdd,RepeatMode.Pad);
                case RepeatMode.Repeat: return &radial_blit!(WindingRule.EvenOdd,RepeatMode.Repeat);
                case RepeatMode.Mirror: return &radial_blit!(WindingRule.EvenOdd,RepeatMode.Mirror);
                default: assert(0);
            }
        }
    }

private:

    void radial_blit(WindingRule wr, RepeatMode mode)(int* delta, DMWord* mask, int x0, int x1, int y)
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
        uint* lut = gradient.getLookup.ptr;
        __m128i lutmsk = gradient.lookupLength - 1;
        __m128i lutmsk2 = gradient.lookupLength*2 - 1;

        // XMM constants

        immutable __m128i XMZERO = 0;
        immutable __m128i XMFFFF = 0xFFFFFFFF;

        // paint variables

        float t0 = (bpos*4-xctr)*xstep0 + (y-yctr)*ystep0;
        __m128 xmT0 = _mm_mul_ps(_mm_set1_ps(xstep0), _mm_setr_ps(0.0f,1.0f,2.0f,3.0f));
        xmT0 = _mm_add_ps(xmT0, _mm_set1_ps(t0));
        __m128 xmStep0 = _mm_set1_ps(xstep0*4);

        float t1 = (bpos*4-xctr)*xstep1 + (y-yctr)*ystep1;
        __m128 xmT1 = _mm_mul_ps(_mm_set1_ps(xstep1), _mm_setr_ps(0.0f,1.0f,2.0f,3.0f));
        xmT1 = _mm_add_ps(xmT1, _mm_set1_ps(t1));
        __m128 xmStep1 = _mm_set1_ps(xstep1*4);

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

                if (cover == 0)
                {
                    __m128 tsl = _mm_set1_ps(nsb-bpos);
                    xmT0 = _mm_add_ps(xmT0, _mm_mul_ps(tsl,xmStep0));
                    xmT1 = _mm_add_ps(xmT1, _mm_mul_ps(tsl,xmStep1));
                    bpos = nsb;
                }

                // Or fill span with soid color

                else if (gradient.isOpaque && (cover > 0xFF00))
                {
                    uint* ptr = &dest[bpos*4];
                    uint* end = ptr + ((nsb-bpos)*4);

                    while (ptr < end)
                    {
                        __m128 rad = _mm_add_ps(_mm_mul_ps(xmT0, xmT0),_mm_mul_ps(xmT1, xmT1));
                        rad = _mm_sqrt_ps(rad);
                        xmT0 = xmT0 + xmStep0;
                        xmT1 = xmT1 + xmStep1;
                        __m128i ipos = _mm_cvtps_epi32 (rad);
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
                    __m128i tqcvr = _mm_set1_epi16 (cast(ushort) cover);

                    uint* ptr = &dest[bpos*4];
                    uint* end = &dest[nsb*4];

                    while (ptr < end)
                    {
                        __m128 rad = _mm_add_ps(_mm_mul_ps(xmT0, xmT0),_mm_mul_ps(xmT1, xmT1));
                        xmT0 = xmT0 + xmStep0;
                        xmT1 = xmT1 + xmStep1;
                        rad = _mm_sqrt_ps(rad);

                        __m128i d0 = _mm_loadu_si64 (ptr);
                        d0 = _mm_unpacklo_epi8 (d0, XMZERO);
                        __m128i d1 = _mm_loadu_si64 (ptr+2);
                        d1 = _mm_unpacklo_epi8 (d1, XMZERO);

                        __m128i ipos = _mm_cvtps_epi32 (rad);
                        ipos = calcRepeatModeIDX!mode(ipos, lutmsk, lutmsk2);

                        __m128i c0 = _mm_loadu_si32 (&lut[ipos.array[0]]);
                        __m128i tnc = _mm_loadu_si32 (&lut[ipos.array[1]]);
                        c0 = _mm_unpacklo_epi32 (c0, tnc);
                        c0 = _mm_unpacklo_epi8 (c0, XMZERO);
                        __m128i a0 = _mm_broadcast_alpha(c0);
                        a0 = _mm_mulhi_epu16(a0, tqcvr);
                       
                        __m128i c1 = _mm_loadu_si32 (&lut[ipos.array[2]]);
                        tnc = _mm_loadu_si32 (&lut[ipos.array[3]]);
                        c1 = _mm_unpacklo_epi32 (c1, tnc);
                        c1 = _mm_unpacklo_epi8 (c1, XMZERO);
                        __m128i a1 = _mm_broadcast_alpha(c1);
                        a1 = _mm_mulhi_epu16(a1, tqcvr);

                       // alpha*source + dest - alpha*dest

                        c0 = _mm_mulhi_epu16 (c0,a0);
                        c1 = _mm_mulhi_epu16 (c1,a1);
                        c0 = _mm_adds_epi16 (c0,d0);
                        c1 = _mm_adds_epi16 (c1,d1);
                        d0 = _mm_mulhi_epu16 (d0,a0);
                        d1 = _mm_mulhi_epu16 (d1,a1);
                        c0 =  _mm_subs_epi16 (c0, d0);
                        c1 =  _mm_subs_epi16 (c1, d1);

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
                __m128 rad = _mm_add_ps(_mm_mul_ps(xmT0, xmT0),_mm_mul_ps(xmT1, xmT1));
                rad = _mm_sqrt_ps(rad);

                // Integrate delta values

                __m128i tqw = _mm_load_si128(cast(__m128i*)dlptr);
                tqw = _mm_add_epi32(tqw, _mm_slli_si128!4(tqw)); 
                tqw = _mm_add_epi32(tqw, _mm_slli_si128!8(tqw)); 
                tqw = _mm_add_epi32(tqw, xmWinding); 
                xmWinding = _mm_shuffle_epi32!255(tqw);  
                _mm_store_si128(cast(__m128i*)dlptr,XMZERO);

                // convert grad pos to integer

                __m128i ipos = _mm_cvtps_epi32 (rad);
                xmT0 = xmT0 + xmStep0;
                xmT1 = xmT1 + xmStep1;

                // calculate coverage from winding

                __m128i tcvr = calcCoverage!wr(tqw);

                // Load destination pixels

                __m128i d0 = _mm_loadu_si64 (ptr);
                d0 = _mm_unpacklo_epi8 (d0, XMZERO);
                __m128i d1 = _mm_loadu_si64 (ptr+2);
                d1 = _mm_unpacklo_epi8 (d1, XMZERO);

                // load grad colors

                ipos = calcRepeatModeIDX!mode(ipos, lutmsk, lutmsk2);

                tcvr = _mm_unpacklo_epi16 (tcvr, tcvr);
                __m128i tcvr2 = _mm_unpackhi_epi32 (tcvr, tcvr);
                tcvr = _mm_unpacklo_epi32 (tcvr, tcvr);

                __m128i c0 = _mm_loadu_si32 (&lut[ipos.array[0]]);
                __m128i tnc = _mm_loadu_si32 (&lut[ipos.array[1]]);
                c0 = _mm_unpacklo_epi32 (c0, tnc);
                c0 = _mm_unpacklo_epi8 (c0, XMZERO);
                __m128i a0 = _mm_broadcast_alpha(c0);
                a0 = _mm_mulhi_epu16(a0, tcvr);

                __m128i c1 = _mm_loadu_si32 (&lut[ipos.array[2]]);
                tnc = _mm_loadu_si32 (&lut[ipos.array[3]]);
                c1 = _mm_unpacklo_epi32 (c1, tnc);
                c1 = _mm_unpacklo_epi8 (c1, XMZERO);
                __m128i a1 = _mm_broadcast_alpha(c1);
                a1 = _mm_mulhi_epu16(a1, tcvr2);

                // alpha*source + dest - alpha*dest

                c0 = _mm_mulhi_epu16 (c0,a0);
                c1 = _mm_mulhi_epu16 (c1,a1);
                c0 = _mm_adds_epi16 (c0,d0);
                c1 = _mm_adds_epi16 (c1,d1);
                d0 = _mm_mulhi_epu16 (d0,a0);
                d1 = _mm_mulhi_epu16 (d1,a1);
                c0 =  _mm_subs_epi16 (c0, d0);
                c1 =  _mm_subs_epi16 (c1, d1);

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
    float xctr,yctr;
    float xstep0,ystep0;
    float xstep1,ystep1; 
    Gradient gradient;
    WindingRule windingRule;
    RepeatMode repeatMode;
}

