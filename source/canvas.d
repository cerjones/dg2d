/**
  This module contains the Canvas and Paint types.

  Copyright Chris Jones 2020.
  Distributed under the Boost Software License, Version 1.0.
  See accompanying file Licence.txt or copy at...
  https://www.boost.org/LICENSE_1_0.txt
*/

module dg2d.canvas;

import dg2d.gradient;
import dg2d.rasterizer;
import dg2d.path;
import dg2d.geometry;
import dg2d.misc;
import dg2d.gradient;
import font;

/*
  Thoughts...

  Paint : Defines color at given pixel so base color, gradient, pattern and
    repeat mode etc...

  For Paint have single struct paints so...

  canvas.fill(path,LinearGradient(a,b,c,d,etc),style)

  So that can be done without there needing to be an allocation. Also have
  a polymorphic paint type that can be anything, so it wraps those structs
  into one.

  Style : More about geometry so, winding rule, stroke or fill. End caps,
   joins etc..

  Style should be lightweight and there should be a collection of functions
  that provide typical defaults. IE..

  canvas.fill(path,LinearGradient(a,b,c,d,etc),StyleFillEO());
  canvas.fill(path,LinearGradient(a,b,c,d,etc),StyleStroke(4.0));

  Style: For now just passing WindingRule as that's all thats actually implemented

*/

/**
  Linear gradient type
*/

struct LinearGradient
{
    float x0,y0,x1,y1;
    Gradient gradient;
    RepeatMode rmode;
}

/**
  Radial gradient type
*/

struct RadialGradient
{
    float x0,y0,x1,y1,x2,y2;
    Gradient gradient;
    RepeatMode rmode;
}

/**
  Angular gradient type
*/

struct AngularGradient
{
    float x0,y0,x1,y1,x2,y2,repeats;
    Gradient gradient;
    RepeatMode rmode;
}

/**
  Biradial gradient type
*/

struct BiradialGradient
{
    float x0,y0,r0,x1,y1,r1;
    Gradient gradient;
    RepeatMode rmode;
}

/** 
  Generic paint type
*/

struct Paint
{
    this(uint color)
    {
        this.color = color;
        this.type = PaintType.color;
    }
    this(LinearGradient linear)
    {
        this.linear = linear;
        this.type = PaintType.linear;
    }
    this(RadialGradient radial)
    {
        this.radial = radial;
        this.type = PaintType.radial;
    }
    this(AngularGradient angular)
    {
        this.angular = angular;
        this.type = PaintType.angular;
    }
    this(BiradialGradient biradial)
    {
        this.biradial = biradial;
        this.type = PaintType.biradial;
    }
private:
    union
    {
        uint color;
        LinearGradient linear;
        RadialGradient radial;
        AngularGradient angular;
        BiradialGradient biradial;
    }
    enum PaintType
    {
        color, linear, radial, angular, biradial
    }
    PaintType type;
}

enum isPaintable(T) = (is(T == uint) || is(T == Paint) || is(T == LinearGradient)
     || is(T == RadialGradient) || is(T == AngularGradient) || is(T == BiradialGradient));

/*
  Canvas class, provices a user freindly pixel buffer and drawing functions.
*/

class Canvas
{
    /** Constructor */

    this(int width, int height)
    {
        resize(width, height);
        m_rasterizer = new Rasterizer;
    }

    /** Destructor */

    ~this()
    {
        dg2dFree(m_pixels);
    }

    /**
      Set the size in pixels. 
    
      Note that pixels will be garbage afterwards and clip/view state will be reset.
    */

    void resize(int width, int height)
    {
        m_stride = roundUpTo(width,4);
        m_pixels = dg2dRealloc(m_pixels, m_stride*height);
        if (!m_pixels) assert(0);
        m_width = width;
        m_height = height;
        m_view = IRect(0,0,width,height);
        m_clip = m_view;
    }

    /** width of canvas */

    int width()
    {
         return m_width;
    }

    /** height of canvas */

    int height()
    {
         return m_height;
    }

    /** stride is the length of each scanline in pixels. */

    int stride()
    {
         return m_stride;
    }

    /** returns a pointer to the raw pixels in memory */

    uint* pixels()
    {
        return m_pixels;
    }

    /** Fill the the current viewport with the specified paint. */

    void fill(T)(T paint)
        if (isPaintable!T)
    {
        draw(Rect!float(0,0,m_width,m_height).asPath, paint, WindingRule.NonZero);
    }

    /** Fill the rectangle with the specified paint. */

    void fill(T)(T paint, IRect rect)
        if (isPaintable!T)
    {
        draw(Rect!float(rect.left,rect.top,rect.right,rect.bottom).asPath,
            paint, WindingRule.NonZero);
    }

    /** Fill the rectangle with the specified paint. */

    void fill(T)(T paint, int x0, int y0, int x1, int y1)
       if (isPaintable!T)
    {
        draw(Rect!float(x0,y0,x1,y1).asPath, paint, WindingRule.NonZero);
    }

    /** Fill the path with the specified paint */
    
    void draw(T)(auto ref T path, Paint paint, WindingRule wr)
        if (isPathType!T)
    {
        if (m_clip.isEmpty) return;

        switch (paint.type)
        {
            case PaintType.color:
                draw(path, paint.color, wr);
                break;
            case PaintType.linearGradient:
                draw(path, paint.linear, wr);
                break;               
            case PaintType.radialGradient:
                draw(path, paint.radial, wr);
                break;
            case PaintType.angularGradient:
                draw(path, paint.angular, wr);
                break;
            case PaintType.biradialGradient:
                draw(path, paint.biradial, wr);
                break;
            default:
               assert(0);
        }
    }

    /** Draw the path with the specified color and winding rule */

    void draw(T)(auto ref T path, uint color, WindingRule wrule)
        if (isPathIterator!T)
    {
        import dg2d.colorblit;
        if (m_clip.isEmpty) return;
        m_rasterizer.initialise(m_clip);
        m_rasterizer.addPath2(path.offset(m_view.left,m_view.top));
        auto colblit = ColorBlit(m_pixels,m_stride,m_height);
        colblit.setColor(color);
        m_rasterizer.rasterize(colblit.getBlitFunc(wrule));
    }

    /** Draw the path with a linear gradient */

    void draw(T)(auto ref T path, LinearGradient lingrad, WindingRule wrule)
        if (isPathIterator!T)
    {
        import dg2d.linearblit;
        if (m_clip.isEmpty) return;
        m_rasterizer.initialise(m_clip);
        m_rasterizer.addPath2(path.offset(m_view.left,m_view.top));
        auto linblit = LinearBlit(m_pixels, m_stride, m_height);
        linblit.setPaint(lingrad.gradient, wrule, lingrad.rmode);
        linblit.setCoords(m_view.left+lingrad.x0, m_view.top+lingrad.y0,
            m_view.left+lingrad.x1, m_view.top+lingrad.y1);
        m_rasterizer.rasterize(linblit.getBlitFunc);
    }

    /** Draw the path with a radial gradient */

    void draw(T)(auto ref T path, RadialGradient radgrad, WindingRule wrule)
        if (isPathIterator!T)
    {
        import dg2d.radialblit;
        if (m_clip.isEmpty) return;
        m_rasterizer.initialise(m_clip);
        m_rasterizer.addPath2(path.offset(m_view.left,m_view.top));
        auto radblit = RadialBlit(m_pixels, m_stride, m_height);
        radblit.setPaint(radgrad.gradient, wrule, radgrad.rmode);
        radblit.setCoords(m_view.left+radgrad.x0, m_view.top+radgrad.y0,
         m_view.left+radgrad.x1, m_view.top+radgrad.y1,m_view.left+radgrad.x2, m_view.top+radgrad.y2);
        m_rasterizer.rasterize(radblit.getBlitFunc);
    }

    /** Draw the path with an angular gradient */

    void draw(T)(auto ref T path, AngularGradient angrad, WindingRule wrule)
        if (isPathIterator!T)
    {
        import dg2d.angularblit;
        if (m_clip.isEmpty) return;
        m_rasterizer.initialise(m_clip);
        m_rasterizer.addPath2(path.offset(m_view.left,m_view.top));
        auto anblit = AngularBlit(m_pixels, m_stride, m_height);
        anblit.setPaint(angrad.gradient, wrule, angrad.rmode, angrad.repeats);
        anblit.setCoords(m_view.left+angrad.x0, m_view.top+angrad.y0,
         m_view.left+angrad.x2, m_view.top+angrad.y2,m_view.left+angrad.y1, m_view.top+angrad.x1);
        m_rasterizer.rasterize(anblit.getBlitFunc);
    }

    /** Draw the path with a biradial gradient */

    void draw(T)(auto ref T path, BiradialGradient bigrad, WindingRule wrule)
        if (isPathIterator!T)
    {
        import dg2d.biradialblit;
        if (m_clip.isEmpty) return;
        m_rasterizer.initialise(m_clip);
        m_rasterizer.addPath2(path.offset(m_view.left,m_view.top));
        auto biblit = BiradialBlit(m_pixels, m_stride, m_height);
        biblit.setPaint(bigrad.gradient, wrule, bigrad.rmode);
        biblit.setCoords(m_view.left+bigrad.x0, m_view.top+bigrad.y0,
            bigrad.r0, m_view.left+bigrad.x1, m_view.top+bigrad.y1, bigrad.r1);
        m_rasterizer.rasterize(biblit.getBlitFunc);
    }

    void roundRect(float x, float y, float w, float h, float r, uint color)
    {
        import dg2d.colorblit;

        if (m_clip.isEmpty) return;

        x += m_view.left;
        y += m_view.top;

        float lpc = r*0.44772;

        m_rasterizer.initialise(m_clip.left,m_clip.top,m_clip.right, m_clip.bottom);

        m_rasterizer.moveTo(x+r,y);
        m_rasterizer.lineTo(x+w-r,y);
        m_rasterizer.cubicTo(x+w-lpc,y,  x+w,y+lpc,  x+w,y+r);
        m_rasterizer.lineTo(x+w,y+h-r);
        m_rasterizer.cubicTo(x+w,y+h-lpc,  x+w-lpc,y+h,  x+w-r,y+h);
        m_rasterizer.lineTo(x+r,y+h);
        m_rasterizer.cubicTo(x+lpc,y+h,  x,y+h-lpc,  x,y+h-r);
        m_rasterizer.lineTo(x,y+r);
        m_rasterizer.cubicTo(x,y+lpc,  x+lpc,y,  x+r,y);

        auto cblit = ColorBlit(m_pixels,m_stride,m_height);
        cblit.setColor(color);
        m_rasterizer.rasterize(cblit.getBlitFunc(WindingRule.NonZero));
    }

    /* text stuff needs a lot of work, was just to get it working 
    for now to see if I could parse font correctly */

    void drawText(float x, float y, string txt, Font font, uint color)
    {
        if (m_clip.isEmpty) return;

        m_tmppath.reset();

        for (int i = 0; i < txt.length; i++)
        {
            x += font.addChar(m_tmppath, x, y, txt[i]);
        }
        draw(m_tmppath, color, WindingRule.NonZero);  
    }

    /** Gets the current clip and viewport state */

    ViewState getViewState()
    {
        return ViewState(m_view,m_clip);
    }

    /** Set the viewport.
    
    Sets a view port rectangle. This new viewport is set relative to the current
    viewport. All drawing operations are offset to the new viewport.

    The clip rectangle is shrunk to the intersection of the new viewport and the
    current clip rectangle.
    */

    void setView(int x0, int y0, int x1, int y1)
    {
        m_view.right = m_view.left + x1;
        m_view.bottom = m_view.top + y1;
        m_view.left = m_view.left + x0;
        m_view.top = m_view.top + y0;
        m_clip = intersect(m_view, m_clip);
    }

    /** Set the viewport relative to a specific ViewState
    
    Sets a view port rectangle. This new viewport is set relative to the specified
    ViewState. All drawing operations are offset to the viewport.

    The clip rectangle is shrunk to the intersection of the new viewport and the
    current clip rectangle.
    */

    void setView(ref ViewState state, int x0, int y0, int x1, int y1)
    {
        m_view.left = state.view.left + x0;
        m_view.top = state.view.top + y0;
        m_view.right = state.view.left + x1;
        m_view.bottom = state.view.top + y1;
        m_clip = intersect(m_view, state.clip);
    }

    /** Reset the to previous viewport and clip state */

    void resetState(ref ViewState state)
    {
        m_view = state.view;
        m_clip = state.clip;
    }

    /** Is there any valid region we can draw on? */

    bool isClipEmpty()
    {
        return m_clip.isEmpty;
    }

    /** Set the clip rectangle
    
      The clip is set relative to the current viewport.
    */  

    void setClip(int x0, int y0, int x1, int y1)
    {
        m_clip = intersect(m_clip, offset(IRect(x0,y0,x1,y1),m_view.left,m_view.top));
    }

    /** Completely reset the viewport and clip
    
    Resets to the full bounds of the canvas.
    */ 

    void resetView()
    {
        m_view = IRect(0,0,m_width,m_height);
        m_clip = m_view;
    }

private:

    uint*        m_pixels;
    int          m_width;
    int          m_height;
    int          m_stride;
    IRect        m_view;
    IRect        m_clip;
    Rasterizer   m_rasterizer;
    Path!float   m_tmppath;     // workspace
}

/** Viewport and clip rectangle */

struct ViewState
{
private:
    IRect view;
    IRect clip;
}

