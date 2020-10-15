/*
  Copyright Chris Jones 2020.
  Distributed under the Boost Software License, Version 1.0.
  See accompanying file Licence.txt or copy at...
  https://www.boost.org/LICENSE_1_0.txt
*/

module dg2d.font;

import dg2d.misc;
import dg2d.truetype;
import dg2d.path;

/*
  This is very much "just get it working so I can print something on screen",
*/

Font loadFont(string filename)
{
    import dg2d.misc;

    ubyte[] tmp = loadFileMalloc(filename);
    if (tmp.ptr == null) return null;

    ttFontInfo finfo;
    if (ttLoadFont(finfo, tmp) == ttFail) return null;
    Font font = new Font();
    font.m_data = tmp;
    font.m_fontinfo = finfo;
    return font;
}

// cast away const on font data for now till I can fix truetype stuff to work with const

Font loadFont(const(ubyte)[] rawfont)
{
    import dg2d.misc;

    ttFontInfo finfo;
    if (ttLoadFont(finfo, cast(ubyte[]) rawfont) == ttFail) return null;
    Font font = new Font();
    font.m_data = cast(ubyte[]) rawfont;
    font.m_fontinfo = finfo;
    return font;
}

class Font
{
    this()
    {
    }

    ~this()
    {
        import core.stdc.stdlib : free;
        free(m_data.ptr);
    }

    // setSize, just going on this for now...
    // https://docs.microsoft.com/en-us/typography/opentype/spec/ttch01

    void setSize(float size)
    {
        m_size = clip(size, 1, 200); // what are plausible limits for size?
        m_scale = size * 72.0 / (72.0 * 2048.0); 
    }

    float addChar(ref Path!float path, float x, float y, uint charCode)
    {
        int gid = ttCharToGlyph(m_fontinfo, charCode);
        if (gid == 0) return 0.0f;

        if (m_prevGlyph > 0)
        {
            x += ttGetKerning(m_fontinfo, m_prevGlyph, gid)*m_scale;
        }
        ttAddGlyphToPath(m_fontinfo, gid, path, x, y, m_scale, -m_scale);
        return ttGetAdvanceWidth(m_fontinfo, gid)*m_scale;
    }

    float lineHeight()
    {
        return (ttGetFontAscent(m_fontinfo) - ttGetFontDescent(m_fontinfo)
           + ttGetFontLineGap(m_fontinfo)) * m_scale;
    }

    float height()
    {
        return (ttGetFontAscent(m_fontinfo) + ttGetFontDescent(m_fontinfo)) * m_scale;
    }

    // horizontal advance for a given glyph taking into account kerning. It needs the
    // next character to properly evaluate, pass 0 if there is none

    float glyphAdvance(uint charCode, uint nextCode)
    {
        int g0 = ttCharToGlyph(m_fontinfo, charCode);
        int g1 = ttCharToGlyph(m_fontinfo, nextCode);
        return (ttGetAdvanceWidth(m_fontinfo, g0) +
            ttGetKerning(m_fontinfo, g0, g1)) * m_scale;
    }

    // getTextSpacing, calculates the spacing for each character in txt,
    // note: advance array must have same length as txt

    void getTextSpacing(const char[] txt, ref float[] advance)
    {
        assert(txt.length == advance.length);

        int lb1 = cast(int)txt.length-1;
        for(int i = 0; i < lb1; i++)
        {
            int g0 = ttCharToGlyph(m_fontinfo, txt[i]);
            int g1 = ttCharToGlyph(m_fontinfo, txt[i+1]);
            advance[i] = (ttGetAdvanceWidth(m_fontinfo, g0) +
                ttGetKerning(m_fontinfo, g0, g1)) * m_scale;
        }
        advance[$-1] = ttGetAdvanceWidth(m_fontinfo, ttCharToGlyph(m_fontinfo, txt[$-1]));
    }

    // get width of txt

    float getStrWidth(const char[]  txt)
    {
        if (txt.length == 0) return 0;

        float w = 0;
        for(int i = 0; i < txt.length-1; i++)
        {
            int g0 = ttCharToGlyph(m_fontinfo, txt[i]);
            int g1 = ttCharToGlyph(m_fontinfo, txt[i+1]);
            w += (ttGetAdvanceWidth(m_fontinfo, g0) +
                ttGetKerning(m_fontinfo, g0, g1)) * m_scale;
        }
        return w + ttGetAdvanceWidth(m_fontinfo, ttCharToGlyph(m_fontinfo, txt[$-1])) * m_scale;
    }

private:
    ubyte[]     m_data;
    ttFontInfo  m_fontinfo;
    float       m_size;
    float       m_scale;
    uint        m_prevGlyph = -1;
    bool        m_doKerning = true;
}

