/**
  Blitter for painting biradial gradients.

  Copyright Chris Jones 2020.
  Distributed under the Boost Software License, Version 1.0.
  See accompanying file Licence.txt or copy at...
  https://www.boost.org/LICENSE_1_0.txt
*/

module dg2d.biradialblit;

import dg2d.rasterizer;
import dg2d.gradient;
import dg2d.misc;
import dg2d.blitex;

/**
   Biradial gradient blitter struct.

   ---
   auto blit = RadialBlit(m_pixels,m_stride,m_height);
   blit.setPaint(grad, wr, RepeatMode.Pad);
   blit.setCircles(x0,y0,x1,y1,x2,y2);
   m_rasterizer.rasterize(blit.getBlitFunc);
   ---
*/

struct BiradialBlit
{
    /** Construct a Biradial blitter.
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

    /** 
      Set the paint options.
      Params:
      gradient = colour gradient to use
      wrule  = winding rule
      rmode  = repeat mode, Pad, Repeat or Mirror modes are supported.
      
      Notes: If the focus circle is not fully enclosed by the main circle there will be
        areas that are undefined in terms of where they map to on the gradient
        axis. These areas are filled with end colour from the gradient.
    */

    void setPaint(Gradient gradient, WindingRule wrule, RepeatMode rmode)
    {
        assert(gradient !is null);
        assert(isPow2(gradient.lookupLength));
        this.gradient = gradient;
        this.windingRule = wrule;
        this.repeatMode = rmode;
    }

    /**
      Set the focus and main circles.
    */

    void setCoords(float x0, float y0, float r0, float y1, float x1, float r1)
    {
        dx = x1-x0;
        dy = y1-y0;
        dr = r1-r0;
        fx = x0; // note use fx,fy as focus x,y to avoid clashing with x0 in blit method
        fy = y0;
        fr = r0;
        isEnclosed = (sqr(dx)+sqr(dy)) < sqr(dr);
    }

    /** Get the BlitFunc for use by the rasterizer */

    BlitFunc getBlitFunc() return
    {
        if (isEnclosed)
        {
            if (windingRule == WindingRule.NonZero)
            {
                switch(repeatMode)
                {
                    case RepeatMode.Pad: return &biradial_blit!(WindingRule.NonZero,RepeatMode.Pad,true);
                    case RepeatMode.Repeat: return &biradial_blit!(WindingRule.NonZero,RepeatMode.Repeat,true);
                    case RepeatMode.Mirror: return &biradial_blit!(WindingRule.NonZero,RepeatMode.Mirror,true);
                    default: assert(0);
                }
            }
            else
            {
                switch(repeatMode)
                {
                    case RepeatMode.Pad: return &biradial_blit!(WindingRule.EvenOdd,RepeatMode.Pad,true);
                    case RepeatMode.Repeat: return &biradial_blit!(WindingRule.EvenOdd,RepeatMode.Repeat,true);
                    case RepeatMode.Mirror: return &biradial_blit!(WindingRule.EvenOdd,RepeatMode.Mirror,true);
                    default: assert(0);
                }
            }
        }
        else
        {
            if (windingRule == WindingRule.NonZero)
            {
                switch(repeatMode)
                {
                    case RepeatMode.Pad: return &biradial_blit!(WindingRule.NonZero,RepeatMode.Pad,false);
                    case RepeatMode.Repeat: return &biradial_blit!(WindingRule.NonZero,RepeatMode.Repeat,false);
                    case RepeatMode.Mirror: return &biradial_blit!(WindingRule.NonZero,RepeatMode.Mirror,false);
                    default: assert(0);
                }
            }
            else
            {
                switch(repeatMode)
                {
                    case RepeatMode.Pad: return &biradial_blit!(WindingRule.EvenOdd,RepeatMode.Pad,false);
                    case RepeatMode.Repeat: return &biradial_blit!(WindingRule.EvenOdd,RepeatMode.Repeat,false);
                    case RepeatMode.Mirror: return &biradial_blit!(WindingRule.EvenOdd,RepeatMode.Mirror,false);
                    default: assert(0);
                }
            }
        }
    }

private:

    void biradial_blit(WindingRule wr, RepeatMode mode, bool isEnclosed)
                    (int* delta, DMWord* mask, int x0, int x1, int y)
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
        __m128 xmgradlen = _mm_set1_ps(gradient.lookupLength);

        // XMM constants

        immutable __m128i XMZERO = 0;

        // paint variables

        // note that variable names have changed from doc in the notes folder...
        // fx,fy,fr are the focus circle instead of (x0,y0,r0).
        // (x0,y) and the point of interest instead of (x,y)

        float coefA = sqr(dx) + sqr(dy) - sqr(dr);
        float coefB = 2*fx*dx - 2*dx*x0 + 2*dy*fy - 2*dy*y - 2*fr*dr;
        float coefC = sqr(y) + sqr(fx) + sqr(fy) - 2*fy*y - sqr(fr);

        __m128 xmstepB = _mm_set1_ps(-2*dx*4);
        __m128 xmseqx = _mm_setr_ps(0.0f,1.0f,2.0f,3.0f);
        __m128 xmposx = _mm_set1_ps(x0) + xmseqx; 
        __m128 xmstepx = _mm_set1_ps(4.0f);
        __m128 xm2x0 = _mm_set1_ps(2*fx);
        __m128 xmcoefB = _mm_set1_ps(coefB) + xmseqx * _mm_set1_ps(-2*dx);
        __m128 xmcoefC = _mm_set1_ps(coefC);

        __m128 xmq0 = _mm_set1_ps(-0.5/coefA);
        __m128 xmq1 = _mm_set1_ps(4*coefA);

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
                    xmcoefB = xmcoefB + _mm_mul_ps(xskip,xmstepB);
                    xmposx = xmposx + _mm_mul_ps(xskip,xmstepx);
                    bpos = nsb;
                }

                // Or fill span with soid color

                else if (gradient.isOpaque && (cover > 0xFF00))
                {
                    uint* ptr = &dest[bpos*4];
                    uint* end = ptr + ((nsb-bpos)*4);

                    while (ptr < end)
                    {
                        __m128 xmc = xmposx*(xmposx-xm2x0) + xmcoefC;
                        __m128 xmdiscr = xmcoefB*xmcoefB - xmq1*xmc;
                        __m128 xmsqrtd = _mm_sqrt_ps(xmdiscr);
                        __m128 xmt = xmq0 * (xmsqrtd + xmcoefB);

                        // Generate pad mask if needed, used to control the colour in
                        // undefined /out of bounds areas

                        static if (isEnclosed == false)
                        {
                            __m128 xmt2 = (xmsqrtd - xmcoefB);
                            __m128i padMask = _mm_or_si128(cast(__m128i) xmdiscr, cast(__m128i) xmt2);
                            padMask = _mm_srai_epi32(padMask,31);
                        }

                        xmcoefB += xmstepB;
                        xmposx += xmstepx;

                        __m128i ipos = _mm_cvtps_epi32 (xmt * xmgradlen);
                        ipos = calcRepeatModeIDX!mode(ipos, lutmsk, lutmsk2);

                        // set ipos to max for undefined areas

                        static if (isEnclosed == false)
                        {
                            ipos = _mm_or_si128(ipos, padMask & lutmsk);
                        }

                        __m128i tmp;
                        tmp[0] = lut[ipos.array[0]];
                        tmp[1] = lut[ipos.array[1]];
                        tmp[2] = lut[ipos.array[2]];
                        tmp[3] = lut[ipos.array[3]];

                        _mm_store_si128 (cast(__m128i*)ptr,tmp);

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

                        __m128 xmc = xmposx*(xmposx-xm2x0) + xmcoefC;
                        __m128 xmdiscr = xmcoefB*xmcoefB - xmq1*xmc;
                        __m128 xmsqrtd = _mm_sqrt_ps(xmdiscr);
                        __m128 xmt = xmq0 * (xmsqrtd + xmcoefB);

                        // Generate pad mask if needed, used to control the colour in
                        // any undefined areas

                        static if (isEnclosed == false)
                        {
                            __m128 xmt2 = (xmsqrtd - xmcoefB);
                            __m128i padMask = _mm_or_si128(cast(__m128i) xmdiscr, cast(__m128i) xmt2);
                            padMask = _mm_srai_epi32(padMask,31);
                        }

                        xmcoefB += xmstepB;
                        xmposx += xmstepx;

                        __m128i ipos = _mm_cvtps_epi32 (xmt * xmgradlen);
                        ipos = calcRepeatModeIDX!mode(ipos, lutmsk, lutmsk2);

                        // set ipos to max for undefined areas

                        static if (isEnclosed == false)
                        {
                            ipos = _mm_or_si128(ipos, padMask & lutmsk);
                        }

                        // load destination pixels

                        __m128i d0 = _mm_load_si128(cast(__m128i*)ptr);
                        __m128i d1 = _mm_unpackhi_epi8(d0,d0);
                        d0 = _mm_unpacklo_epi8(d0,d0);

                        // load grad colours and alpha
                 
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
                __m128 xmc = xmposx*(xmposx-xm2x0) + xmcoefC;
                __m128 xmdiscr = xmcoefB*xmcoefB - xmq1*xmc;
                __m128 xmsqrtd = _mm_sqrt_ps(xmdiscr);
                __m128 xmt = xmq0 * (xmsqrtd + xmcoefB);

                // Generate pad mask if needed, used to control the colour in
                // any undefined areas

                static if (isEnclosed == false)
                {
                    __m128 xmt2 = (xmsqrtd - xmcoefB);
                    __m128i padMask = _mm_or_si128(cast(__m128i) xmdiscr, cast(__m128i) xmt2);
                    padMask = _mm_srai_epi32(padMask,31);
                }

                xmcoefB += xmstepB;
                xmposx += xmstepx;

                __m128i ipos = _mm_cvtps_epi32 (xmt * xmgradlen);
                ipos = calcRepeatModeIDX!mode(ipos, lutmsk, lutmsk2);
                
                // set ipos to max for undefined areas

                static if (isEnclosed == false)
                {
                    ipos = _mm_or_si128(ipos, padMask & lutmsk);
                }

                // Integrate delta values

                __m128i idv = _mm_load_si128(cast(__m128i*)dlptr);
                idv = _mm_add_epi32(idv, _mm_slli_si128!4(idv)); 
                idv = _mm_add_epi32(idv, _mm_slli_si128!8(idv)); 
                idv = _mm_add_epi32(idv, xmWinding); 
                xmWinding = _mm_shuffle_epi32!255(idv);  
                _mm_store_si128(cast(__m128i*)dlptr,XMZERO);

                // calculate coverage from winding

                __m128i xmcover = calcCoverage32!wr(idv);

                // Load destination pixels

                __m128i d0 = _mm_load_si128(cast(__m128i*)ptr);
                __m128i d1 = _mm_unpackhi_epi8(d0,d0);
                d0 = _mm_unpacklo_epi8(d0,d0);

                // load grad colors

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

private:

    uint* pixels;
    int stride;
    int height;
    float fx,fy,fr; 
    float dx,dy,dr;
    Gradient gradient;
    WindingRule windingRule;
    RepeatMode repeatMode;
    bool isEnclosed;
}

