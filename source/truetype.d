/*
  Copyright Chris Jones 2020.
  Distributed under the Boost Software License, Version 1.0.
  See accompanying file Licence.txt or copy at...
  https://www.boost.org/LICENSE_1_0.txt
*/

module dg2d.truetype;

import dg2d.path;

import core.stdc.stdlib : malloc, free, realloc;

/*
  TrueType font loader.

  refs:
  https://developer.apple.com/fonts/TrueType-Reference-Manual/
  https://docs.microsoft.com/en-gb/typography/opentype/spec/
  https://github.com/nothings/stb/blob/master/stb_truetype.h
*/

/*
  errorOp is used as a mixin to make it esier to debug font file errors
  you need to pass the "-mixin" flag to compiler for it to be any use
*/

//private enum errorOp = "{ return ttFail; }"; // this for normal use
private enum errorOp = "{ asm { int 3; }}";  // this for debugging font

enum
{
    ttFail = 0,
    ttSuccess = 1
}

// helpers for reading big endian values from array of bytes

private:

short read_short(ubyte* ptr)
{
    return cast(short)(ptr[1] | (ptr[0]<<8));
}

ushort read_ushort(ubyte* ptr)
{
    return cast(ushort)(ptr[1] | (ptr[0]<<8));
}

int read_int(ubyte* ptr)
{
    return cast(int)(ptr[3] | (ptr[2]<<8)| (ptr[1]<<16)| (ptr[0]<<24));
}

uint read_uint(ubyte* ptr)
{
    return cast(uint)(ptr[3] | (ptr[2]<<8)| (ptr[1]<<16)| (ptr[0]<<24));
}

uint read_tag(string str)
{
    assert (str.length == 4);
    return str[3] | (str[2]<<8)| (str[1]<<16)| (str[0]<<24);
}

/*
  ttFontInfo
*/

public:

struct ttFontInfo
{
    ubyte[]    glyf;
    ubyte[]    loca;
    ubyte[]    head; 
    ubyte[]    kern;
    ubyte[]    hhea;
    ubyte[]    hmtx;
    ubyte[]    cmap; // actually points to sub table
    uint       sfntver;
    bool       locaShortForm;
    int        numGlyphs;
    int        unitsPerEm;
    int        numHMetrics;
    int        lineGap;
}

// cmap encoding flags

private:

enum {
    PID_Unicode   = 0,
    PID_Mac       = 1,
    PID_Iso       = 2,
    PID_Microsoft = 3,

    MSEID_Symbol      = 0,
    MSEID_UnicodeBmp  = 1,
    MSEID_Shiftjis    = 2,
    MSEID_UnicodeFull = 10
}

/*
  Loads font from raw bytes and returns ttFontInfo struct
*/

public:

int ttLoadFont(ref ttFontInfo info, ubyte[] rawfont)
{
    // check room for header, read offset table
    
    if (rawfont.length < 12) mixin(errorOp);
    info.sfntver = read_int(rawfont.ptr);
    int numtbl = read_ushort(rawfont.ptr+4);

    // check room for table record entries

    if (rawfont.length < (12+numtbl*16)) mixin(errorOp);

    // find chunk

    uint findChunk(string tag, ref ubyte[] data)
    {
        foreach(i; 0..numtbl)
        {
            ubyte* cnkptr = rawfont.ptr+12+i*16;

            if (read_uint(cnkptr) == read_tag(tag))
            {
                uint offset = read_uint(cnkptr+8);
                uint length = read_uint(cnkptr+12);
                if ((offset+length) > rawfont.length) return ttFail;
                data = rawfont[offset..offset+length];
                return ttSuccess;
            }
        }
        return ttFail;
    }

    // fill out chunks we're interested in

    if (findChunk("glyf",info.glyf) == ttFail) mixin(errorOp);
    if (findChunk("loca",info.loca) == ttFail) mixin(errorOp);
    if (findChunk("head",info.head) == ttFail) mixin(errorOp);
    if (findChunk("hhea",info.hhea) == ttFail) mixin(errorOp);
    if (findChunk("hmtx",info.hmtx) == ttFail) mixin(errorOp);
    findChunk("kern",info.kern); // not essential

    // lookup number of glyphs

    ubyte[] tmp;
    if (findChunk("maxp",tmp) == ttFail) mixin(errorOp);
    if (tmp.length < 32) mixin(errorOp);
    info.numGlyphs = read_ushort(tmp.ptr+4);

    // Number of hMetric entries in 'hmtx' table

    if (info.hhea.length < 36) mixin(errorOp);
    info.numHMetrics = read_ushort(info.hhea.ptr+34);

    // lookup loca table format, and units per em

    if (info.head.length < 54) mixin(errorOp);
    info.locaShortForm = (read_short(info.head.ptr+50) == 0);
    info.unitsPerEm = read_ushort(info.hhea.ptr+18);
    info.lineGap = read_short(info.hhea.ptr+8);

    // check kern table has enough for header info 

    if (info.kern.length < 4) mixin(errorOp);

    // find character mapping table, we lookup cmap table, and
    // then determine which subtable to use and set the info.cmap to 
    // that subtable.

    if (findChunk("cmap",tmp) == ttFail) mixin(errorOp);

    int subtabs = read_ushort(tmp.ptr+2);
    if (tmp.length < 4+subtabs*8) mixin(errorOp);

    foreach (i; 0..subtabs)
    {
        ubyte* ptr = tmp.ptr+4+i*8;
        ushort platId = read_ushort(ptr);
        ushort ncodId = read_ushort(ptr+2);
        uint offset =  read_uint(ptr+4);

        if ((platId == PID_Microsoft) && 
           ((ncodId == MSEID_UnicodeBmp) || (ncodId == MSEID_UnicodeFull)))
        {
            if (tmp.length < offset+4) mixin(errorOp);
            int len = read_ushort(tmp.ptr+offset+2);
            if (tmp.length < offset+len) mixin(errorOp);
            info.cmap = tmp[offset..offset+len];
        }
    }

    if (info.cmap.length < 4) mixin(errorOp); // check room for table header

    return ttSuccess;
}

// convert char code to glyph index 

uint ttCharToGlyph(ref ttFontInfo info, uint charCode)
{
    ushort format = read_ushort(info.cmap.ptr);

    if (format == 0) // Byte encoding table
    {
        if (6+charCode < info.cmap.length) return info.cmap[6+charCode];
        return 0;
    }
    else if (format == 4) // Segment mapping to delta values
    {
        if (charCode >= 0xFFFF) return 0;
        int segcnt = read_ushort(info.cmap.ptr+6)/2;
        if (segcnt == 0) return 0;
        if (info.cmap.length < 16+segcnt*8) mixin(errorOp); // check room for arrays

        // offsets to arrays

        int endcopos = 14;
        int startpos = 16+segcnt*2;
        int deltapos = 16+segcnt*4;
        int rangepos = 16+segcnt*6;     
 
        // binary search for first endcode > charCode

        int l = 0;
        int r = segcnt-1;

        while (l != r)
        {
            int m = (l+r)/2;
            int endcode = read_ushort(info.cmap.ptr+endcopos+m*2);
            if (endcode < charCode) l = m+1; else r = m;
        }

        // not found return missing glyph code

        uint start = read_ushort(info.cmap.ptr+startpos+r*2);
        if (charCode < start) return 0;

        // calculte glyph index
        
        int idoff = read_ushort(info.cmap.ptr+rangepos+r*2);
        
        if (idoff == 0) return
            (charCode + read_short(info.cmap.ptr+deltapos+r*2)) & 0xFFFF;
        
        // seriously who thought this obscure indexing trick was a good idea?
        // glyphIndexAddress = idRangeOffset[i] + 2 * (c - startCode[i]) + (Ptr) &idRangeOffset[i]
        // not sure if following is correct as not found font to test it

        int startcode = read_ushort(info.cmap.ptr+startpos+r*2);

        return read_ushort(info.cmap.ptr + idoff
            + (charCode-startcode)*2 + rangepos + r*2);
    }
    else if (format == 6) // Trimmed table mapping
    {
        int first = read_ushort(info.cmap.ptr+6);
        int count = read_ushort(info.cmap.ptr+8);
        if ((charCode >= first) && (charCode < (first+count)))
            return read_ushort(info.cmap.ptr+10+(charCode-first)*2);
        return 0;
    }
    return 0;
}

// outline flags

private:

enum
{
    ON_CURVE_POINT = 1,
    X_SHORT_VECTOR = 2,
    Y_SHORT_VECTOR = 4,
    REPEAT_FLAG    = 8,
    X_SAME_OR_POS  = 16,
    Y_SAME_OR_POS  = 32,
    OVERLAP_SIMPLE = 64
}

// glyph bounds struct

public:

struct ttGlyphBounds
{
    int xmin,ymin,xmax,ymax;
}

ttGlyphBounds ttGetGlyphBounds(ref ttFontInfo info, uint glyphId)
{
    ttGlyphBounds bounds;
    ubyte[] data = ttGetGlyphData(info,glyphId);
    if (data.length == 0) return bounds;
    bounds.xmin = read_short(data.ptr+2);
    bounds.ymin = read_short(data.ptr+4);
    bounds.xmax = read_short(data.ptr+6);
    bounds.ymax = read_short(data.ptr+8);
    return bounds;
}

// get glyph data, returns empty array if index out of range, note that
// an empty array is valid anyway for an empty glyph, so empty doesnt
// nececarilly mean error

ubyte[] ttGetGlyphData(ref ttFontInfo info, uint glyphId)
{
    if (glyphId >= info.numGlyphs) return null;

    if (info.locaShortForm)
    {
        int start = read_ushort(info.loca.ptr+glyphId*2);
        int end   = read_ushort(info.loca.ptr+glyphId*2+2);
        return info.glyf[start*2..end*2];
    }
    else
    {
        int start = read_ushort(info.loca.ptr+glyphId*4);
        int end   = read_ushort(info.loca.ptr+glyphId*4+4);
        return info.glyf[start*4..end*4];
    }
}

// add glyph path, adds the glyph path to the another path,
// note: vertical orientation cartesian, rather that typical GUI of origin at top.

int ttAddGlyphToPath(ref ttFontInfo info, uint glyphId, ref Path!float path,
        float xoff, float yoff, float xscale, float yscale)
{
    ubyte[] data = ttGetGlyphData(info, glyphId);

    // if empty nothing to do
      
    if (data.length == 0) return ttSuccess;

    // must at least have a header

    if (data.length < 10) mixin(errorOp);
    int numctr = read_short(data.ptr);

    if (numctr > 0)
    {
        if (data.length < (10+numctr*2+2)) mixin(errorOp);
        int numpts = read_ushort(data.ptr+10+numctr*2-2)+1;
        int ilen = read_ushort(data.ptr+10+numctr*2);
        if (data.length < (10+numctr*2+2+ilen)) mixin(errorOp);        
        
        // need to parse flags to locate x and y arrays
        
        int fpos = 10+numctr*2+2+ilen; 
        int xlen,ylen,rep,flags;

        foreach(i; 0..numpts)
        {
            if (rep == 0)
            {
                if (data.length < (fpos+2)) mixin(errorOp);        
                flags = data[fpos++];
                if (flags & REPEAT_FLAG) rep = data[fpos++];
            }
            else rep--;

            if (flags & X_SHORT_VECTOR) xlen++;
            else if (!(flags & X_SAME_OR_POS)) xlen+=2;    
            if (flags & Y_SHORT_VECTOR) ylen++;
            else if (!(flags & Y_SAME_OR_POS)) ylen+=2;    
        }

        if (data.length < (fpos+xlen+ylen)) mixin(errorOp);        

        // init stuff to itterate path

        int xpos = fpos;
        int ypos = xpos+xlen;
        fpos = 10+numctr*2+2+ilen;
        int cpos = 10;

        struct Point
        {
            float x = 0, y = 0;
            bool anchor; // true if anchor point, false if contorl point 
        }

        int pidx;
        Point p0,p1,firstpt;
        flags = 0;
        rep = 0;

        p1.x = xoff;
        p1.y = yoff;

        // this iterates p0 and p1 along the path

        void nextPoint()
        {
            pidx++;
            p0 = p1;

            if (rep == 0)
            {
                flags = data[fpos++];
                if (flags & REPEAT_FLAG) rep = data[fpos++];
            }
            else rep--;

            p1.anchor = (flags & 1);

            if (flags & X_SHORT_VECTOR)
            {
                p1.x += ((flags & X_SAME_OR_POS) 
                    ? data[xpos++] : -cast(int) data[xpos++])*xscale;
            }
            else if (!(flags & X_SAME_OR_POS))
            {
                p1.x += read_short(&data[xpos])*xscale;
                xpos += 2;
            }
            if (flags & Y_SHORT_VECTOR)
            {
                p1.y += ((flags & Y_SAME_OR_POS)
                    ? data[ypos++] : -cast(int) data[ypos++])*yscale;
            }
            else if (!(flags & Y_SAME_OR_POS))
            {
                p1.y += read_short(&data[ypos])*yscale;
                ypos += 2;
            }
        }

        // parse path for real now 

        while (pidx < numpts)
        {
            // get end of sub path, make sure we have at least 3 points

            int endofsub = read_short(&data[cpos])+1;
            cpos += 2;
            if (endofsub > numpts) mixin(errorOp);
            if ((endofsub-pidx) < 3) mixin(errorOp);

            // process first two points

            nextPoint();
            nextPoint();
            firstpt = p0; // save for later

            if (p0.anchor)
            {
                path.moveTo(p0.x, p0.y);
                if (p1.anchor) path.lineTo(p1.x, p1.y);
            }
            else
            {
                if (p1.anchor)
                {
                    path.moveTo(p1.x, p1.y);
                }
                else
                {
                    p0.x = (p0.x+p1.x)/2; // new achor point
                    p0.y = (p0.y+p1.y)/2;
                    path.moveTo(p0.x,p0.y);
                }
            }

            // process the remaining path

            while(pidx < endofsub)
            {
                nextPoint();

                if (p0.anchor)
                {
                    if (p1.anchor) path.lineTo(p1.x,p1.y);
                }
                else
                {
                    if (p1.anchor)
                    {
                        path.quadTo(p0.x, p0.y, p1.x, p1.y);
                    }
                    else
                    {
                        float mx = (p0.x+p1.x)/2; // new achor point
                        float my = (p0.y+p1.y)/2;
                        path.quadTo(p0.x, p0.y, mx, my);
                    }
                }
            }

            // close the path, have to check first point and stick it onto the
            // end if it was a control point

            auto end = path.lastMoveTo();

            if (firstpt.anchor)
            {
                if (p1.anchor) path.lineTo(end.x, end.y);
                else path.quadTo(p1.x, p1.y, end.x, end.y);
            }
            else
            {
                if (p1.anchor)
                {
                    path.quadTo(firstpt.x, firstpt.y, end.x, end.y);
                }
                else // a new anchor point and a quad either side
                {
                    float mx = (p0.x+p1.x)/2;
                    float my = (p0.y+p1.y)/2;
                    path.quadTo(p0.x, p0.y, mx, my);               
                    path.quadTo(mx, my, end.x, end.y);               
                }
            }
        }
    }
}

// get advance width of glyph

int ttGetAdvanceWidth(ref ttFontInfo info, uint glyphId)
{
    assert(glyphId < info.numGlyphs);

    if (glyphId < info.numHMetrics)
    {
        return read_short(info.hmtx.ptr + glyphId*4);
    }
    else
    {
        return read_short(info.hmtx.ptr + info.numHMetrics*4-4);
    }
}

// get left side bearing of glyph

int ttGetLeftSideBearing(ref ttFontInfo info, uint glyphId)
{
    assert(glyphId < info.numGlyphs);

    if (glyphId < info.numHMetrics)
    {
        return read_short(info.hmtx.ptr + glyphId*4+2);
    }
    else
    {
        return read_short(info.hmtx.ptr + info.numHMetrics*4
            + (glyphId-info.numHMetrics)*2);
    }
}

// get kerning info, advance with for glyph1 given that it is followed by glyph2

int ttGetKerning(ref ttFontInfo info, uint glyphId1, uint glyphId2)
{
    // check we have a subtable

    if (read_ushort(info.kern.ptr+2) < 1) mixin(errorOp);

    // use first table, must be horizontal

    if (!(read_ushort(info.kern.ptr+8) & 1))  mixin(errorOp);

    // binary search kerning pair

    int l = 0;
    int r = read_ushort(info.kern.ptr+10) - 1;
    uint lookfor = (glyphId2 << 16) | glyphId1;
    while (l <= r)
    {
        int q = (l + r) / 2;
        uint qval = read_uint(info.kern.ptr+18+q*6);
        if (lookfor < qval) r = q-1;
        else if (lookfor > qval) l = q+1;
        else return read_short(info.kern.ptr+18+q*6+4);
    }
    return 0;
}

int ttGetFontAscent(ref ttFontInfo info)
{
    return read_short(info.hhea.ptr+4);
}

int ttGetFontDescent(ref ttFontInfo info)
{
    return read_short(info.hhea.ptr+6);
}

int ttGetFontLineGap(ref ttFontInfo info)
{
    return read_short(info.hhea.ptr+8);
}