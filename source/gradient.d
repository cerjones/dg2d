/**
  This module provides colour gradient funcitonality. The colour gradient
  is just the array of colours and positions along a linear dimension. The
  actual mapping to 2D space is seperate from this.

  Copyright: Chris Jones
  License: Boost Software License, Version 1.0
  Authors: Chris Jones
*/

module dg2d.gradient;

import dg2d.misc;

/**
  Gradient class, 
  The gradient is defined as a list of colours and positions (known as stops) along
  a single dimension from 0 to 1. 
  It has a has a lookup table for the rasterizer

  When you add a colour via addStop it's opacity is checked so that the
  rasterizer can know whether the gradient is fully opaque or not. its much
  faster to draw fully opaque gradients, so helps with optimization.
*/

class Gradient
{
    // colour is 32 bit ARGB, pos runs from 0..1 

    struct ColorStop
    {
        uint  color;
        float pos;
    }

    this(int lookupLength = 32)
    {
        setLookupLength(lookupLength);
    }

    ~this()
    {
        dg2dFree(m_stops);
        dg2dFree(m_lookup);
    }

    uint length()
    {
        return m_stopsLength;
    }

    bool hasChanged()
    {
        return m_changed;
    }

    void reset()
    {
        m_stopsLength = 0;
        m_changed = true;
        m_isOpaque = true;
    }

    /** get lookup table */

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

    /** change lookup table length */

    void setLookupLength(int len)
    {
        if (m_lookupLength == len) return;
        assert(len <= 8192); // check people being sensible
        len = roundUpPow2(max(2,len));
        m_lookup = dg2dRealloc(m_lookup, len);
        m_lookupLength = len;
        m_changed = true;
    }

    /** add a color stop */

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
    
    // fixed size lookup for now, could probably have lookup tables cached
    // by the rasterizer rather than stuck in here/

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
    bool m_isOpaque;
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



