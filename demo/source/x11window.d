module x11window;

import window;
import dg2d;

version (linux)  : import x11.X;
import x11.Xlib;
import x11.Xatom;
import x11.Xutil;

import core.stdc.config : c_ulong;
import core.time;
import std.stdio;
import std.string : toStringz;

private __gshared Atom WM_DELETE_WINDOW;
private __gshared Atom _NET_WM_NAME;
private __gshared Atom UTF8_STRING;
private __gshared Display* display;

private __gshared X11Window[Window] windowMap;

void ConnectX11()
{
    display = XOpenDisplay(null);
    if (!display)
        throw new Exception("couldn't open an X display");

    WM_DELETE_WINDOW = XInternAtom(display, "WM_DELETE_WINDOW", false);
    _NET_WM_NAME = XInternAtom(display, "_NET_WM_NAME", false);
    UTF8_STRING = XInternAtom(display, "UTF8_STRING", false);
}

bool wait_fd(int fd, Duration d)
{
    import core.sys.posix.sys.select;
    import std.math : trunc;

    timeval tv;
    fd_set in_fds;
    FD_ZERO(&in_fds);
    FD_SET(fd, &in_fds);
    auto dur = d.split!("seconds", "usecs");
    tv.tv_sec = dur.seconds;
    tv.tv_usec = dur.usecs;
    return !!select(fd + 1, &in_fds, null, null, &tv);
}

bool XWaitForEvent(Display* display, XEvent* event, Duration time)
{
    if (XPending(display) || wait_fd(ConnectionNumber(display), time))
    {
        return true;
    }
    else
    {
        return false;
    }
}

/*
  Simple event loop
*/
void X11EventLoop()
{
    const Duration timer = 1.msecs;
    Duration remainingTimer = timer;
    auto lastTime = MonoTime.currTime();

    XEvent event;
    while (windowMap.length)
    {
        if (remainingTimer <= Duration.zero || !XWaitForEvent(display, &event, remainingTimer))
        {
            remainingTimer = timer;
            foreach (k, window; windowMap)
                window.wm_Timer();
            continue;
        }

        scope (exit)
        {
            auto now = MonoTime.currTime();
            auto passed = now - lastTime;
            remainingTimer -= passed;
            lastTime = now;
        }

        while (XPending(display))
        {
            XNextEvent(display, &event);
            if (auto window = event.xany.window in windowMap)
                window.handleEvent(event);
        }
    }
}

/*
  bare bones X11 window class
*/
class X11Window : IWindow
{
private:
    Window handle;
    GC gc;

    string m_title;
    int m_width;
    int m_height;
    Canvas m_canvas;
    bool wantedMorePaint = false;

    Widget m_client;

    void handleEvent(ref XEvent event)
    {
        switch (event.type)
        {
        case Expose:
            doPaint(event.xexpose);
            break;

        case ConfigureNotify:
            auto xce = event.xconfigure;
            m_width = xce.width;
            m_height = xce.height;
            break;

        case MotionNotify:
            handleMouseMove(event.xmotion);
            break;
        case ButtonPress:
        case ButtonRelease:
            handleMouseClick(event.type == ButtonPress, event.xbutton);
            break;

        case ClientMessage:
            if (event.xclient.data.l[0] == WM_DELETE_WINDOW)
            {
                XUnmapWindow(display, handle);
                XDestroyWindow(display, handle);
                windowMap.remove(handle);
            }
            break;

        default:
            break;
        }
    }

    void handleMouseMove(XMotionEvent event)
    {
        MouseMsg msg;
        msg.event = MouseEvent.Move;
        msg.x = event.x;
        msg.y = event.y;

        if (m_client !is null)
        {
            m_client.internalMouse(msg);
        }
    }

    void handleMouseClick(bool down, XButtonEvent event)
    {
        MouseMsg msg;
        switch (event.button)
        {
        case 1:
            msg.event = down ? MouseEvent.LeftDown : MouseEvent.LeftUp;
            break;
        case 2:
            msg.event = down ? MouseEvent.MiddleDown : MouseEvent.MiddleUp;
            break;
        case 3:
            msg.event = down ? MouseEvent.RightDown : MouseEvent.RightUp;
            break;
        case 4:
        case 5:
            msg.event = MouseEvent.Wheel;
            // scrolling 60
            msg.w = ((event.button - 4) * 2 - 1) * 60;
            break;
        default:
            writeln("unhandled mouse button ", event.button);
            return;
        }
        msg.x = event.x;
        msg.y = event.y;
        msg.left = (event.state & Button1Mask) != 0;
        msg.middle = (event.state & Button2Mask) != 0;
        msg.right = (event.state & Button3Mask) != 0;
        msg.shift = (event.state & ShiftMask) != 0;
        msg.ctrl = (event.state & ControlMask) != 0;
        msg.alt = (event.state & Mod1Mask) != 0;
        msg.super_ = (event.state & Mod4Mask) != 0;

        if (m_client !is null)
        {
            m_client.internalMouse(msg);
        }
    }

    void doPaint(XExposeEvent event)
    {
        if (event.count > 0)
        {
            wantedMorePaint = true;
            return;
        }

        if (wantedMorePaint)
        {
            event.x = 0;
            event.y = 0;
            event.width = m_width;
            event.height = m_height;
        }

        int l = event.x;
        int t = event.y;
        int r = l + event.width;
        int b = t + event.height;

        if (m_canvas is null)
            m_canvas = new Canvas(r, b);

        if ((m_canvas.width < r) || (m_canvas.height < b))
        {
            m_canvas.resize(r, b);
        }

        m_canvas.resetView();
        m_canvas.setClip(l, t, r, b);

        onPaint(m_canvas);
        if (m_client !is null)
            m_client.internalPaint(m_canvas);

        XImage info;
        info.width = m_canvas.width;
        info.height = m_canvas.height;
        info.format = ZPixmap;
        info.data = cast(char*) m_canvas.pixels;
        info.char_order = LSBFirst;
        info.bitmap_unit = 32;
        info.bitmap_bit_order = LSBFirst;
        info.bitmap_pad = 8;
        info.depth = 32;
        info.chars_per_line = m_canvas.stride * 4;
        info.bits_per_pixel = 32;
        info.red_mask = 0x00FF0000;
        info.green_mask = 0x0000FF00;
        info.blue_mask = 0x000000FF;
        XInitImage(&info);

        XPutImage(display, handle, gc, &info, l, t, l, t, event.width, event
                .height);
    }

    void wm_Timer()
    {
        if (m_client !is null)
            m_client.internalTimer();
    }

public:
    void create(int x, int y, int w, int h, string title)
    {
        m_width = w;
        m_height = h;

        auto titlez = cast(char*) title.toStringz;

        auto root = XDefaultRootWindow(display);

        XVisualInfo visual;
        if (XMatchVisualInfo(display, DefaultScreen(display), 32, TrueColor, &visual) == 0)
            stderr.writeln("Failed finding 32 bit visuals, program might crash");

        XSetWindowAttributes wa;
        wa.colormap = XCreateColormap(display, root, visual.visual, AllocNone);
        wa.background_pixel = 0;
        wa.border_pixel = 0;
        wa.event_mask = ExposureMask | StructureNotifyMask | PointerMotionMask | ButtonPressMask | ButtonReleaseMask; // | KeyPressMask | ButtonPressMask
        handle = XCreateWindow(display, root, x, y, w, h, 0, visual.depth, InputOutput, visual
                .visual, CWEventMask | CWBackPixel | CWColormap | CWBorderPixel, &wa);

        XStoreName(display, handle, titlez);
        XTextProperty unicodeName;
        unicodeName.value = cast(ubyte*) titlez;
        unicodeName.encoding = XA_STRING;
        unicodeName.format = 8;
        unicodeName.nitems = title.length;
        XSetWMName(display, handle, &unicodeName);
        unicodeName.encoding = UTF8_STRING;
        XSetTextProperty(display, handle, &unicodeName, _NET_WM_NAME);

        XGCValues values;
        gc = XCreateGC(display, handle, 0, &values);
        XSetWMProtocols(display, handle, &WM_DELETE_WINDOW, 1);

        windowMap[handle] = this;
        XMapWindow(display, handle);
    }

    void repaint()
    {
        XEvent event;
        event.xexpose.type = Expose;
        event.xexpose.serial = 0;
        event.xexpose.send_event = true;
        event.xexpose.display = display;
        event.xexpose.window = handle;
        event.xexpose.x = 0;
        event.xexpose.y = 0;
        event.xexpose.width = m_width;
        event.xexpose.height = m_height;
        event.xexpose.count = 0;
        XSendEvent(display, handle, false, ExposureMask, &event);
        XFlush(display);
    }

    void repaint(int x0, int y0, int x1, int y1)
    {
        XEvent event;
        event.xexpose.type = Expose;
        event.xexpose.serial = 0;
        event.xexpose.send_event = true;
        event.xexpose.display = display;
        event.xexpose.window = handle;
        event.xexpose.x = x0;
        event.xexpose.y = y0;
        event.xexpose.width = x1 - x0;
        event.xexpose.height = y1 - y0;
        event.xexpose.count = 0;
        XSendEvent(display, handle, false, ExposureMask, &event);
        XFlush(display);
    }

    void onPaint(Canvas canvas)
    {

    }

    void setContent(Widget widget)
    {
        if (widget.m_parent !is null)
            widget.m_parent.removeChild(widget);
        widget.m_window = this;
        m_client = widget;
    }
}
