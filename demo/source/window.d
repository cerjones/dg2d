module window;

import std.functional : memoize;
import std.process : environment;
import std.stdio;

import win32;
import x11window;

import dg2d;

interface IWindow
{
    void setContent(Widget widget);

    void create(int x, int y, int w, int h, string title);

    void repaint();
    void repaint(int x0, int y0, int x1, int y1);
}

version (Windows)
{
    enum WindowingBackend
    {
        win32,
    }
}
else version (linux)
{
    enum WindowingBackend
    {
        x11,
        // wayland,
    }
}

WindowingBackend redetermineWindowingBackend()
{
    version (Windows)
        return WindowingBackend.win32;
    else version (linux)
    {
        switch (environment.get("XDG_SESSION_TYPE"))
        {
            case("wayland"):
                writeln("wayland not supported yet; will try to use xwayland");
                goto case;
            case("x11"): return WindowingBackend.x11;
            default: break; // check below
        }

        if (environment.get("DISPLAY").length)
            return WindowingBackend.x11;
        else if (environment.get("WAYLAND_DISPLAY").length) {
            writeln("wayland not supported yet; will try to use xwayland");
            return WindowingBackend.x11;
        } else
            throw new Exception("No supported windowing system detected, please start again in X11 or wayland");
    }
    else
        static assert(false, "No windowing backend for this platform");
}

alias determineWindowingBackend = memoize!redetermineWindowingBackend;

IWindow createPlatformWindow()
{

    final switch (determineWindowingBackend)
    {
        version (Windows) case(WindowingBackend.win32): return new Win32Window();
        version (linux) case(WindowingBackend.x11): return new X11Window();
    }
}

void loadPlatformWindow()
{
    final switch (determineWindowingBackend)
    {
        version (Windows) case(WindowingBackend.win32): RegisterWindowClass();
        version (linux) case(WindowingBackend.x11):
            try ConnectX11();
            catch (Exception e) {
                if (environment.get("XDG_SESSION_TYPE") == "wayland"
                    || environment.get("WAYLAND_DISPLAY").length)
                    throw new Exception("xwayland not available");
                else
                    throw new Exception(e.msg);
            }
    }
}

void runMainLoop()
{
    final switch (determineWindowingBackend)
    {
        version (Windows) case(WindowingBackend.win32): WindowsMessageLoop(); 
        version (linux) case(WindowingBackend.x11): X11EventLoop();
    }
}

// mouse stuff

enum MouseEvent
{
    LeftDown, MiddleDown, RightDown,
    LeftUp, MiddleUp, RightUp,
    LeftDblCk, MiddleDblCk, RightDblCk,
    Move, Enter, Exit, EndFocus,
    LeftDrag, RightDrag,
    Wheel
}

struct MouseMsg
{
    MouseEvent  event;
    int         x,y;
    /// wheel offset, down is positive, up is negative
    int         w;
    bool        focused;
    bool        left;
    bool        middle;
    bool        right;
    bool        shift;
    bool        ctrl;
    bool        alt;
    bool        super_;
}

// Widget

class Widget
{
    this(int x, int y, int width, int height)
    {
        m_x = x;
        m_y = y;
        m_width = width;
        m_height = height;
    }

    void addChild(Widget widget)
    {
        if (widget.m_parent !is null) widget.m_parent.removeChild(widget);
        if (widget.m_window !is null) widget.m_window.setContent(this);
        m_widgets ~= widget;
        widget.m_parent = this;
    }

    void removeChild(Widget widget)
    {
        foreach(i, child; m_widgets)
        {
            if (child is widget)
            {
                m_widgets[i..$-1] = m_widgets[i+1..$];
                m_widgets.length = m_widgets.length-1;
                widget.m_parent = null;
                return;
            }
        }   
    }

    void repaint()
    {
        repaint(0,0,m_width,m_height);
    }

    void repaint(int x0, int y0, int x1, int y1)
    {
        if (m_parent !is null)
        {
            m_parent.repaint(m_x+x0,m_y+y0,m_x+x1,m_y+y1);
        }
        else if (m_window !is null)
        {
            m_window.repaint(m_x+x0,m_y+y0,m_x+x1,m_y+y1);
        }
    }

    void onPaint(Canvas canvas)
    {
    }

    void onMouse(MouseMsg msg)
    {
    }

    void onTimer()
    {
    }

    int right()
    {
        return m_x+m_width;
    }
    
    int bottom()
    {
        return m_y+m_height;
    }

    bool contains(int x, int y)
    {
        return ((x >= m_x) && (x < m_x+m_width)
            && (y >= m_y) && (y < m_y+m_height));
    }

    void internalPaint(Canvas canvas)
    {
        onPaint(canvas);
        auto state = canvas.getViewState();
 
        foreach(widget; m_widgets)
        {
            canvas.setView(state, widget.m_x, widget.m_y, widget.right, widget.bottom); 
            if (!canvas.isClipEmpty) widget.internalPaint(canvas);
        }

        canvas.resetState(state);
    }
   
    // returns the widget that got the message

    Widget internalMouse(MouseMsg msg)
    {
        foreach_reverse(widget; m_widgets)
        {
            if (widget.contains(msg.x,msg.y))
            {
                msg.x -= widget.m_x;
                msg.y -= widget.m_y;
                return widget.internalMouse(msg);
            }
        }
        onMouse(msg);
        return this;
    }

    void internalTimer()
    {
        foreach_reverse(widget; m_widgets)
        {
            widget.onTimer();
        }
        onTimer();
    }

    Widget m_parent;
    IWindow m_window;
    Widget[] m_widgets;

    int m_x,m_y,m_width,m_height;
}

/*
  Button class
*/

alias ButtonClick = void delegate();

class Button : Widget
{
    this(int x,int y, int w, int h, string text, Font f)
    {
        super(x,y,w,h);
        m_text = text;
        m_font = f;
    }

    void setOnClick(ButtonClick onclick)
    {
        m_onclick = onclick;
    }

    bool hitTest(int x, int y)
    {
        return ((x >= m_x) && (x < m_x+m_width)
            && (y >= m_y) && (y < m_y+m_height));
    }

    override void onPaint(Canvas c)
    {
        c.draw(RoundRect(0,0,m_width,m_height,10).asPath, 0x80a0c0ff, WindingRule.NonZero);
        c.draw(RoundRect(2,2,m_width-2,m_height-2,10).asPath, 0xFF000000, WindingRule.NonZero);

        int tx = 20;
        int ty = m_height - cast(int) (m_height - m_font.height) / 2;
        c.drawText(tx,ty,m_text,m_font,0xFFffffff);
    }

    override void onMouse(MouseMsg msg)
    {
        if ((msg.event == MouseEvent.LeftDown) ||
            (msg.event == MouseEvent.LeftDblCk))
        {
            if (m_onclick !is null) m_onclick();
        }
    }

    void setText(string txt)
    {
        m_text = txt;
    }

private:

    string m_text;
    Font m_font;
    ButtonClick m_onclick;
}

class Label : Widget
{
    this(int x,int y, int w, int h, string text, Font f)
    {
        super(x,y,w,h);
        m_text = text;
        m_font = f;
    }

    override void onPaint(Canvas c)
    {
        c.draw(RoundRect(0,0,m_width,m_height,4).asPath, 0x80000000, WindingRule.NonZero);
        c.draw(RoundRect(1,1,m_width-1,m_height-1,4).asPath, 0xFFFFFFFF, WindingRule.NonZero);
        int tx = cast(int) (m_width - m_font.getStrWidth(m_text)) / 2;
        int ty = m_height - cast(int) (m_height - m_font.height) / 2;
        c.drawText(tx,ty,m_text,m_font,0xFF000000);
    }

    void setText(string text)
    {
        m_text = text;
    }

private:

    string m_text;
    Font m_font;
}