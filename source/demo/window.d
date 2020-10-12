/*
  Copyright Chris Jones 2020.
  Distributed under the Boost Software License, Version 1.0.
  See accompanying file Licence.txt or copy at...
  https://www.boost.org/LICENSE_1_0.txt
*/

module window;

import std.stdio;
import core.sys.windows.windows;
import std.string;
import std.conv;
import dg2d.canvas;
import font;

static import gdi = core.sys.windows.wingdi;

pragma(lib, "gdi32");
pragma(lib, "user32");

/*
  Windows Message Loop
*/

int WindowsMessageLoop()
{    
    MSG  msg;
    while (GetMessageA(&msg, null, 0, 0))
    {
        TranslateMessage(&msg);
        DispatchMessageA(&msg);
    }
    return cast(int) msg.wParam;
}

/*
  Window Proc, not sure what to do about catching Errors/Exceptions, seems to
  just hang no matter what, tried assert(0), ExitProcess etc.. just doesnt close
*/

extern(Windows)
LRESULT WindowProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam) nothrow
{
    try
    {
        auto window = cast(Window) (cast(void*) GetWindowLongPtr(hwnd, GWLP_USERDATA));

        if (window is null)
            return DefWindowProcA(hwnd, msg, wparam, lparam);
        else
            return window.windowProc(hwnd, msg, wparam, lparam);
    }
    catch (Exception e)
    {
        try { writeln(e.toString()); }
        catch(Exception what) {}
        PostQuitMessage(0);
        return 0;
    }
}

/*
  Window class, bare bones WinAPI wrapper
*/

class Window
{
private:

    HWND        m_handle;
    DWORD       m_style;
    DWORD       m_exstyle;
    string      m_title;
    int         m_width;
    int         m_height;
    Canvas      m_canvas;

    Widget      m_client;

    static immutable char[] wndclass  = "GFXWindow";
    static HINSTANCE hinstance;

    UINT_PTR m_timer;

    static this()
    {       
        hinstance = HINSTANCE(GetModuleHandleA(NULL));

        WNDCLASSEXA wcx;
        wcx.cbSize          = wcx.sizeof;
        wcx.style			= CS_DBLCLKS;
        wcx.lpfnWndProc	    = &WindowProc;
        wcx.cbClsExtra		= 0;
        wcx.cbWndExtra		= (void*).sizeof;
        wcx.hInstance		= hinstance;
        wcx.hIcon			= NULL;
        wcx.hCursor		    = LoadCursor(NULL, IDC_ARROW);
        wcx.hbrBackground	= NULL;
        wcx.lpszMenuName	= NULL;
        wcx.lpszClassName	= wndclass.ptr;
        wcx.hIconSm		    = NULL;

        RegisterClassExA(&wcx);
    }

public:

    void createWindow(int x, int y, int w, int h, string title)
    {
        if (m_handle) destroyWindow();

        m_width = w;
        m_height = h;

        m_style = WS_OVERLAPPEDWINDOW;
        m_exstyle = WS_EX_APPWINDOW;

        RECT rect;
        rect.left = x;
        rect.top = y;
        rect.right = x+w;
        rect.bottom = y+h;

        AdjustWindowRectEx(&rect, m_style, false, m_exstyle);

        m_handle = CreateWindowExA(
            WS_EX_APPWINDOW, wndclass.ptr,  toStringz(title), WS_OVERLAPPEDWINDOW,
            rect.left, rect.top, rect.right-rect.left, rect.bottom-rect.top,
            null, null, hinstance, NULL
            );

        if (m_handle)
        {
            SetWindowLongPtrA(m_handle, GWLP_USERDATA, cast(LONG_PTR)( cast(void*)this ));
            ShowWindow(m_handle, SW_SHOW);

            m_timer = SetTimer(m_handle, 0, 1000/20, NULL);
        }
        else
        {
            writeln("oops... coud not create window");
            PostQuitMessage(0);
        }
    }

    void destroyWindow()
    {
        if (m_handle)
        {
            DestroyWindow(m_handle);
            m_handle = null;
        }
    }

    this()
    {
    }

    ~this()
    {
        destroyWindow();
    }

    void setBounds(int x, int y, int w, int h)
    {
        assert((w >= 0) && (h >= 0));

        m_width = w;
        m_height = h;

        if (m_handle)
        {
            RECT r = RECT(x, y, x+w, y+h);
            AdjustWindowRectEx(&r, m_style, false, m_exstyle);
            MoveWindow(m_handle, r.left, r.top, r.right-r.left,
                r.bottom-r.top, true);
        }
    }

    bool isVisible()
    {
        if (m_handle) return (IsWindowVisible(m_handle) != 0);
        return false;
    }

    void repaint()
    {
        InvalidateRect(m_handle,null,0);
    }

    void repaint(int x0, int y0, int x1, int y1)
    {
        RECT rect;
        rect.left = x0;
        rect.top = y0;
        rect.right = x1;
        rect.bottom = y1;
        InvalidateRect(m_handle,&rect,0);
    }

    // Window proc handler

    LRESULT windowProc(HWND hwnd, UINT msg, WPARAM _wparam, LPARAM _lparam)
    {
        WPARAM wparam = _wparam;
        LPARAM lparam = _lparam;

        switch (msg)
        {
            case(WM_PAINT):              wm_Paint(); break;
            case(WM_CLOSE):              wm_Close(); break;
            case(WM_DESTROY):            wm_Destroy(); break;
            case(WM_LBUTTONDOWN):        wm_Mouse(MouseEvent.LeftDown, cast(uint)wparam, cast(uint)lparam); break;
            case(WM_LBUTTONDBLCLK):      wm_Mouse(MouseEvent.LeftDblCk, cast(uint)wparam, cast(uint)lparam); break;
            case(WM_RBUTTONDOWN):        wm_Mouse(MouseEvent.RightDown, cast(uint)wparam, cast(uint)lparam); break;
            case(WM_RBUTTONDBLCLK):      wm_Mouse(MouseEvent.RightDblCk, cast(uint)wparam, cast(uint)lparam); break;
            case(WM_MOUSEMOVE):          wm_Mouse(MouseEvent.Move, cast(uint)wparam, cast(uint)lparam); break;
            case(WM_TIMER):              wm_Timer(); break;

            default: return DefWindowProc(hwnd, msg, wparam, lparam); // can't take m_handle there because of WM_CREATE
        }
        return 0;
    }

    void wm_Paint()
    { 
        PAINTSTRUCT ps;
        BeginPaint(m_handle, &ps);
        int l = ps.rcPaint.left;
        int t = ps.rcPaint.top;
        int r = ps.rcPaint.right;
        int b = ps.rcPaint.bottom;

        if (m_canvas is null) m_canvas = new Canvas(r, b);
        
        if ((m_canvas.width < r) || (m_canvas.height < b))
        {
            m_canvas.resize(r, b);
        }

        m_canvas.resetView();
        m_canvas.setClip(l,t,r,b);

        onPaint(m_canvas);
        if (m_client !is null) m_client.internalPaint(m_canvas);

        BITMAPINFO info;
        info.bmiHeader.biSize          = info.sizeof;
        info.bmiHeader.biWidth         = m_canvas.stride;
        info.bmiHeader.biHeight        = -m_canvas.height;
        info.bmiHeader.biPlanes        = 1;
        info.bmiHeader.biBitCount      = 32;
        info.bmiHeader.biCompression   = BI_RGB;
        info.bmiHeader.biSizeImage     = m_canvas.stride*m_canvas.height*4;
        info.bmiHeader.biXPelsPerMeter = 0;
        info.bmiHeader.biYPelsPerMeter = 0;
        info.bmiHeader.biClrUsed       = 0;
        info.bmiHeader.biClrImportant  = 0;

        SetDIBitsToDevice(
            ps.hdc, 0, 0, m_canvas.stride, m_canvas.height,0, 0, 0,
            m_canvas.height, m_canvas.pixels, &info, DIB_RGB_COLORS);

        EndPaint(m_handle, &ps);
    }

    void wm_Mouse(MouseEvent evt, uint wparam, uint lparam)
    {
        if (m_client !is null)
        {
            MouseMsg msg;
            msg.event = evt;
            msg.left = ((wparam & MK_LBUTTON) != 0);
            msg.middle = ((wparam & MK_MBUTTON) != 0);
            msg.right = ((wparam & MK_RBUTTON) != 0);
            msg.x = cast(short)(lparam); // couldnt find GET_X_PARAM etc...
            msg.y = cast(short)(lparam>>16);
            m_client.internalMouse(msg);
        }
    }

    void wm_Close()
    {
        PostQuitMessage(0);        
    }

    void wm_Destroy()
    {
        m_handle = null;
    }

    void wm_Timer()
    {
        if (m_client !is null) m_client.internalTimer();
    }

    void onPaint(Canvas canvas)
    {

    }

    void addClient(Widget widget)
    {
        if (widget.m_parent !is null) widget.m_parent.removeChild(widget);
        widget.m_window = this;
        m_client = widget;
    }

    void removeClient(Widget widget)
    {
        if  (widget is m_client)
        {
            widget.m_window = null;
            m_client = null;
        }
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
    int         x,y,w;
    bool        focused;
    bool        left;
    bool        middle;
    bool        right;
    bool        shift;
    bool        ctrl;
    bool        alt;
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
        if (widget.m_window !is null) widget.m_window.removeClient(widget);
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

private:

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
    Window m_window;
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
        c.roundRect(0,0,m_width,m_height,10, 0x80a0c0ff);
        c.roundRect(2,2,m_width-4,m_height-4,8, 0xFF000000);
//        int tx = cast(int) (m_width - m_font.getStrWidth(m_text)) / 2;
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
        c.roundRect(0,0,m_width,m_height,4, 0x80000000);
        c.roundRect(1,1,m_width-2,m_height-2,4, 0xFFFFFFFF);
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
