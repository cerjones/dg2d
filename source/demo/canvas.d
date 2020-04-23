/*
  Copyright Chris Jones 2020.
  Distributed under the Boost Software License, Version 1.0.
  See accompanying file Licence.txt or copy at...
  https://www.boost.org/LICENSE_1_0.txt
*/

module canvas;

import dg2d.misc;
import dg2d.geometry;
import dg2d.path;
import dg2d.rasterizer;
import dg2d.gradient;

import font;

import core.stdc.stdlib : malloc, free;

/*
  Simple Canvas class, bare bones to test rasterization so far
*/

class Canvas
{
    this(int width, int height)
    {
        setSize(width, height);
        m_rasterizer = new Rasterizer;
    }

    ~this()
    {
        free(m_pixels);
    }

    // note pixels will be garbage and clip/view state reset

    void setSize(int width, int height)
    {
        m_stride = roundUpTo(width,4);
        m_pixels = cast(uint*) malloc(m_stride*height*4);
        if (!m_pixels) assert(0);
        m_width = width;
        m_height = height;
        m_view.x0 = 0;
        m_view.y0 = 0;
        m_view.x1 = width;
        m_view.y1 = height;
        m_clip = m_view;
    }

    int width()
    {
         return m_width;
    }
    
    int height()
    {
         return m_height;
    }

    int stride()
    {
         return m_stride;
    }

    uint* pixels()
    {
        return m_pixels;
    }

    void fill(uint color)
    {
        fill(color, 0, 0, m_width, m_height);
    }

    void fill(uint color, Rect!int rect)
    {
        fill(color, rect.x0, rect.y0, rect.x1, rect.y1);
    }

    void fill(uint color, int x0, int y0, int x1, int y1)
    {      
        if (!isClipValid) return;

        x0 += m_view.x0;
        y0 += m_view.y0;
        x1 += m_view.x0;
        y1 += m_view.y0;
 
        int l = max(m_view.x0 + x0, m_clip.x0);
        int t = max(m_view.y0 + y0, m_clip.y0);
        int r = min(m_view.x0 + x1, m_clip.x1);
        int b = min(m_view.y0 + y1, m_clip.y1);

        if (r <= l) return;

        for (int i = t; i < b; i++)
            for (int k = l; k < r; k++)
                m_pixels[k+(m_stride*i)] = color;
    }

    void fill(ref Path!float path, uint color, WindingRule wr)
    {
        import dg2d.colorblit;

        if (!isClipValid) return;

        m_rasterizer.initialise(m_clip.x0,m_clip.y0,m_clip.x1, m_clip.y1);
        m_rasterizer.addPath(OffsetPathIterator!float(path,m_view.x0,m_view.y0));

        ColorBlit cb;
        cb.init(m_pixels,m_stride,m_height,color);
        m_rasterizer.rasterize(cb.getBlitter(wr));
    }

    void fillLinear(ref Path!float path, Gradient grad, WindingRule wr, float x0, float y0,
        float x1, float y1)
    {
        import dg2d.linearblit;

        if (!isClipValid) return;

        x0 += m_view.x0;
        y0 += m_view.y0;
        x1 += m_view.x0;
        y1 += m_view.y0;

        m_rasterizer.initialise(m_clip.x0,m_clip.y0,m_clip.x1, m_clip.y1);
        m_rasterizer.addPath(OffsetPathIterator!float(path,m_view.x0,m_view.y0));

        LinearBlit lb;
        lb.init(m_pixels, m_stride, m_height, grad, x0, y0, x1, y1);
        m_rasterizer.rasterize(lb.getBlitter(wr));
    }

    void fillRadial(ref Path!float path, Gradient grad, WindingRule wr, float x0, float y0,
        float x1, float y1,float r)
    {
        import dg2d.radialblit;

        if (!isClipValid) return;

        x0 += m_view.x0;
        y0 += m_view.y0;
        x1 += m_view.x0;
        y1 += m_view.y0;

        m_rasterizer.initialise(m_clip.x0,m_clip.y0,m_clip.x1, m_clip.y1);
        m_rasterizer.addPath(OffsetPathIterator!float(path,m_view.x0,m_view.y0));

        RadialBlit rb;
        rb.init(m_pixels,m_stride,m_height,&grad,x0,y0,x1,y1,r);
        m_rasterizer.rasterize(rb.getBlitter(wr));
    }


    void fillAngular(ref Path!float path, Gradient grad, WindingRule wr, float x0, float y0,
        float x1, float y1, float r2)
    {
        import dg2d.angularblit;

        if (!isClipValid) return;

        x0 += m_view.x0;
        y0 += m_view.y0;
        x1 += m_view.x0;
        y1 += m_view.y0;

        m_rasterizer.initialise(m_clip.x0, m_clip.y0, m_clip.x1, m_clip.y1);
        m_rasterizer.addPath(OffsetPathIterator!float(path,m_view.x0,m_view.y0));

        AngularBlit ab;
        ab.init(m_pixels,m_stride,m_height,grad,x0,y0,x1,y1,r2);
        m_rasterizer.rasterize(ab.getBlitter(wr));
    }

    void roundRect(float x, float y, float w, float h, float r, uint color)
    {
        import dg2d.colorblit;

        if (!isClipValid) return;

        x += m_view.x0;
        y += m_view.y0;

        float lpc = r*0.44772;

        m_rasterizer.initialise(m_clip.x0,m_clip.y0,m_clip.x1, m_clip.y1);

        m_rasterizer.moveTo(x+r,y);
        m_rasterizer.lineTo(x+w-r,y);
        m_rasterizer.cubicTo(x+w-lpc,y,  x+w,y+lpc,  x+w,y+r);
        m_rasterizer.lineTo(x+w,y+h-r);
        m_rasterizer.cubicTo(x+w,y+h-lpc,  x+w-lpc,y+h,  x+w-r,y+h);
        m_rasterizer.lineTo(x+r,y+h);
        m_rasterizer.cubicTo(x+lpc,y+h,  x,y+h-lpc,  x,y+h-r);
        m_rasterizer.lineTo(x,y+r);
        m_rasterizer.cubicTo(x,y+lpc,  x+lpc,y,  x+r,y);

        ColorBlit cb;
        cb.init(m_pixels,m_stride,m_height,color);
        m_rasterizer.rasterize(cb.getBlitter(WindingRule.NonZero));
    }

    void drawText(float x, float y, string txt, Font font, uint color)
    {
        if (!isClipValid) return;

        m_tmppath.reset();

       // x += m_view.x0;
      //  y += m_view.y0;

        for (int i = 0; i < txt.length; i++)
        {
            x += font.addChar(m_tmppath, x, y, txt[i]);
        }
        fill(m_tmppath, color, WindingRule.NonZero);  
    }

    // clip and viewport stuff

    ViewState getViewState()
    {
        return ViewState(m_view,m_clip);
    }

    void setView(int x0, int y0, int x1, int y1)
    {
        m_view.x1 = m_view.x0 + x1;
        m_view.y1 = m_view.y0 + y1;
        m_view.x0 = m_view.x0 + x0;
        m_view.y0 = m_view.y0 + y0;
        m_clip.x0 = max(m_clip.x0, m_view.x0);
        m_clip.y0 = max(m_clip.y0, m_view.y0);
        m_clip.x1 = min(m_clip.x1, m_view.x1);
        m_clip.y1 = min(m_clip.y1, m_view.y1);
    }

    void setView(ref ViewState state, int x0, int y0, int x1, int y1)
    {
        m_view.x1 = state.view.x0 + x1;
        m_view.y1 = state.view.y0 + y1;
        m_view.x0 = state.view.x0 + x0;
        m_view.y0 = state.view.y0 + y0;
        m_clip.x0 = max(state.clip.x0, m_view.x0);
        m_clip.y0 = max(state.clip.y0, m_view.y0);
        m_clip.x1 = min(state.clip.x1, m_view.x1);
        m_clip.y1 = min(state.clip.y1, m_view.y1);
    }

    void resetState(ref ViewState state)
    {
        m_view = state.view;
        m_clip = state.clip;
    }

    bool isClipValid()
    {
        return ((m_clip.x0 < m_clip.x1)
          && (m_clip.y0 < m_clip.y1));
    }

    void setClip(int x0, int y0, int x1, int y1)
    {
        m_clip.x0 = max(m_view.x0+x0,m_clip.x0);
        m_clip.y0 = max(m_view.y0+y0,m_clip.y0);
        m_clip.x1 = min(m_view.x0+x1,m_clip.x1);
        m_clip.y1 = min(m_view.y0+y1,m_clip.y1);
    }

    void resetView()
    {
        m_view.x0 = 0;
        m_view.y0 = 0;
        m_view.x1 = m_width;
        m_view.y1 = m_height;
        m_clip = m_view;
    }


private:

    uint*        m_pixels;
    int          m_width;
    int          m_height;
    int          m_stride;
    Rect!int     m_view;
    Rect!int     m_clip;
    Rasterizer   m_rasterizer;
    Path!float   m_tmppath;     // workspace
}

// holds the state of the viewport and clip rectangle

struct ViewState
{
private:
    Rect!int view;
    Rect!int clip;
}

