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
        m_view.left = 0;
        m_view.top = 0;
        m_view.right = width;
        m_view.bottom = height;
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

    void fill(uint color, IRect rect)
    {
        fill(color, rect.left, rect.top, rect.right, rect.bottom);
    }

    void fill(uint color, int x0, int y0, int x1, int y1)
    {      
        if (!isClipValid) return;

        x0 += m_view.left;
        y0 += m_view.top;
        x1 += m_view.right;
        y1 += m_view.bottom;
 
        int l = max(m_view.left + x0, m_clip.left);
        int t = max(m_view.top + y0, m_clip.top);
        int r = min(m_view.left + x1, m_clip.right);
        int b = min(m_view.top + y1, m_clip.bottom);

        if (r <= l) return;

        for (int i = t; i < b; i++)
            for (int k = l; k < r; k++)
                m_pixels[k+(m_stride*i)] = color;
    }

    void fill(ref Path!float path, uint color, WindingRule wr)
    {
        import dg2d.colorblit;

        if (!isClipValid) return;

        m_rasterizer.initialise(m_clip.left,m_clip.top,m_clip.right, m_clip.bottom);
        m_rasterizer.addPath2(path.offset(m_view.left,m_view.top));

        ColorBlit cb;
        cb.init(m_pixels,m_stride,m_height,color);
        m_rasterizer.rasterize(cb.getBlitter(wr));
    }

    void fillLinear(ref Path!float path, Gradient grad, WindingRule wr, float x0, float y0,
        float x1, float y1)
    {
        import dg2d.linearblit;

        if (!isClipValid) return;

        x0 += m_view.left;
        y0 += m_view.top;
        x1 += m_view.left;
        y1 += m_view.top;

        m_rasterizer.initialise(m_clip.left,m_clip.top,m_clip.right, m_clip.bottom);
        m_rasterizer.addPath2(path.offset(m_view.left,m_view.top));

        LinearBlit lb;
        lb.init(m_pixels, m_stride, m_height, grad, x0, y0, x1, y1);
        m_rasterizer.rasterize(lb.getBlitter(wr));
    }

    void fillRadial(ref Path!float path, Gradient grad, WindingRule wr, float x0, float y0,
        float x1, float y1,float r)
    {
        import dg2d.radialblit;

        if (!isClipValid) return;

        x0 += m_view.left;
        y0 += m_view.top;
        x1 += m_view.left;
        y1 += m_view.top;

        m_rasterizer.initialise(m_clip.left,m_clip.top,m_clip.right, m_clip.bottom);
        m_rasterizer.addPath2(path.offset(m_view.left,m_view.top));

        RadialBlit rb;
        rb.init(m_pixels,m_stride,m_height,&grad,x0,y0,x1,y1,r);
        m_rasterizer.rasterize(rb.getBlitter(wr));
    }


    void fillAngular(ref Path!float path, Gradient grad, WindingRule wr, float x0, float y0,
        float x1, float y1, float r2)
    {
        import dg2d.angularblit;

        if (!isClipValid) return;

        x0 += m_view.left;
        y0 += m_view.top;
        x1 += m_view.left;
        y1 += m_view.top;

        m_rasterizer.initialise(m_clip.left,m_clip.top,m_clip.right, m_clip.bottom);
        m_rasterizer.addPath2(path.offset(m_view.left,m_view.top));

        AngularBlit ab;
        ab.init(m_pixels,m_stride,m_height,grad,x0,y0,x1,y1,r2);
        m_rasterizer.rasterize(ab.getBlitter(wr));
    }

    void roundRect(float x, float y, float w, float h, float r, uint color)
    {
        import dg2d.colorblit;

        if (!isClipValid) return;

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

        ColorBlit cb;
        cb.init(m_pixels,m_stride,m_height,color);
        m_rasterizer.rasterize(cb.getBlitter(WindingRule.NonZero));
    }

    void drawText(float x, float y, string txt, Font font, uint color)
    {
        if (!isClipValid) return;

        m_tmppath.clear();

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
        m_view.right = m_view.left + x1;
        m_view.bottom = m_view.top + y1;
        m_view.left = m_view.left + x0;
        m_view.top = m_view.top + y0;
        m_clip.left = max(m_clip.left, m_view.left);
        m_clip.top = max(m_clip.top, m_view.top);
        m_clip.right = min(m_clip.right, m_view.right);
        m_clip.bottom = min(m_clip.bottom, m_view.bottom);
    }

    void setView(ref ViewState state, int x0, int y0, int x1, int y1)
    {
        m_view.left = state.view.left + x0;
        m_view.top = state.view.top + y0;
        m_view.right = state.view.left + x1;
        m_view.bottom = state.view.top + y1;
        m_clip.left = max(state.clip.left, m_view.left);
        m_clip.top = max(state.clip.top, m_view.top);
        m_clip.right = min(state.clip.right, m_view.right);
        m_clip.bottom = min(state.clip.bottom, m_view.bottom);
    }

    void resetState(ref ViewState state)
    {
        m_view = state.view;
        m_clip = state.clip;
    }

    bool isClipValid()
    {
        return ((m_clip.left < m_clip.right) && (m_clip.top < m_clip.bottom));
    }

    void setClip(int x0, int y0, int x1, int y1)
    {
        m_clip.left = max(m_view.left+x0,m_clip.left);
        m_clip.top = max(m_view.top+y0,m_clip.top);
        m_clip.right = min(m_view.left+x1,m_clip.right);
        m_clip.bottom = min(m_view.top+y1,m_clip.bottom);
    }

    void resetView()
    {
        m_view.left = 0;
        m_view.top = 0;
        m_view.right = m_width;
        m_view.bottom = m_height;
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

// holds the state of the viewport and clip rectangle

struct ViewState
{
private:
    IRect view;
    IRect clip;
}

