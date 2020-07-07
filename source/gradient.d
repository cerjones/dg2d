/**
  This module contains the colour gradient class.  

  Copyright: Chris Jones
  License: Boost Software License, Version 1.0
  Authors: Chris Jones
*/

module dg2d.gradient;

import dg2d.misc;

/**
  Colour Gradient class. 
  
  The colour gradient is defined by a list of colour stops where each stop specifies
  the colour at a given position along the gradient axis. It maintains a lookup
  table that is used by the rasterizer.
*/

class Gradient
{
    //@disable this(this);

    // colour is 32 bit ARGB, pos runs from 0..1 

private:

    struct ColorStop
    {
        uint  color;
        float pos;
    }

public:

    /** Create an empty colour gradient, you can specify the size of the lookuptable */    

    this(int lookupLength = 256)
    {
        setLookupLength(lookupLength);
    }

    /** destructor */

    ~this()
    {
        dg2dFree(m_stops);
        dg2dFree(m_lookup);
    }

    /** How many colour stops are there? */

    uint length()
    {
        return m_stopsLength;
    }

    /** reset the list of gradient colour stops to empty */

    void reset()
    {
        m_stopsLength = 0;
        m_changed = true;
        m_isOpaque = true;
    }

    /** get lookup table, this can cause the lookup table to be recomputed if anything
    significant has changed. */

    uint[] getLookup()
    {
        if (m_changed) initLookup();
        return m_lookup[0..m_lookupLength];
    }

    /** get lookup table length */

    int lookupLength()
    {
        return m_lookupLength;
    }

    /** change lookup table length (8192 max) */

    void setLookupLength(int len)
    {
        if (m_lookupLength == len) return;
        len = roundUpPow2(clip(len,2,8192));
        m_lookup = dg2dRealloc(m_lookup, len);
        m_lookupLength = len;
        m_changed = true;
    }

    /** add a color stop, pos will be cliped to 0..1 */

    Gradient addStop(float pos, uint color)
    {
        if (m_stopsLength == m_stopsCapacity)
        {
            uint newcap = roundUpPow2((m_stopsCapacity*2)|31);
            m_stops = dg2dRealloc(m_stops, newcap);
            m_stopsCapacity = newcap;
        }
        m_stops[m_stopsLength].color = color;
        m_stops[m_stopsLength].pos = clip(pos,0.0f,1.0f);
        m_stopsLength++;
        m_isOpaque = m_isOpaque & ((color >> 24) == 0xFF);
        m_changed = true;
        return this;
    }

    /** is the gradient fully opaque? */

    bool isOpaque()
    {
        return m_isOpaque;
    }

private:

    void initLookup()
    {       
        import std.algorithm : sort;
        m_stops[0..m_stopsLength].sort!("a.pos < b.pos")();
        
        if (m_stopsLength == 0)
        {
            m_lookup[0..m_lookupLength] = 0;
        }
        else if (m_stopsLength == 1)
        {
            m_lookup[0..m_lookupLength] = m_stops[0].color;
        }
        else
        {         
            
            int start = cast(int) (m_stops[0].pos*m_lookupLength);
            m_lookup[0..start] = m_stops[0].color;

            foreach(i; 1..m_stopsLength)
            {
                int end = cast(int) (m_stops[i].pos*m_lookupLength);
                fillGradientArray(m_lookup[start..end], m_stops[i-1].color, m_stops[i].color);
                start = end;
            }         

            m_lookup[start..m_lookupLength] = m_stops[m_stopsLength-1].color;
        }

        m_changed = false;
    }

    ColorStop* m_stops;
    uint m_stopsLength;
    uint m_stopsCapacity;
    uint* m_lookup;
    uint m_lookupLength;
    bool m_changed;
    bool m_isOpaque = true;
}

// Fill an array of uints with a linearly interpolated color gradient

private:

void fillGradientArray(uint[] array, uint color1, uint color2)
{
    if (array.length == 0) return;

    immutable __m128i XMZERO = 0;

    __m128i c0 = _mm_loadu_si32 (&color1);
    c0 = _mm_unpacklo_epi8 (c0, XMZERO);
    __m128i c1 = _mm_loadu_si32 (&color2);
    c1 = _mm_unpacklo_epi8 (c1, XMZERO);

    uint x;
    uint delta = 0x1000000 / cast(uint) array.length;

    array[0] = color1;

    foreach (i; 1..array.length)
    {
        x += delta;
        __m128i pos = _mm_set1_epi16(cast(ushort) (x >> 8));
		
        __m128i tmp0 = _mm_mulhi_epu16 (c0,pos);
        __m128i tmp1 = _mm_mulhi_epu16 (c1,pos);
        __m128i r = _mm_subs_epi16(_mm_adds_epi16(c0, tmp1), tmp0);

        array[i] = _mm_cvtsi128_si32 ( _mm_packus_epi16(r,r) );
    }
}



