/**
  This module provides some 2D geometric primates.

  There are seperate integer and floating point Rect and Point types. The integer
  types are for situatuions where you want exact pixel coordinates, like clip
  rectangles or widget bounds etc.. The float tyes are more general 2D vectoral
  primatives.

  Copyright: Chris Jones
  License: Boost Software License, Version 1.0
  Authors: Chris Jones
*/


module dg2d.geometry;

import dg2d.misc;
import dg2d.path;

/**
  Integer 2D point
*/

struct IPoint
{
    int x = 0;
    int y = 0;

    this(int x, int y)
    {
        this.x = x;
        this.y = y;
    }

    this(int[2] coords)
    {
        this.x = coords[0];
        this.y = coords[1];
    }

    bool isZero()
    {
        return ((x == 0) && (y == 0));
    }
}

/**
  Integer 2D rectangle
*/

struct IRect
{
    int left;
    int top;
    int right;
    int bottom;

    this(int left, int top, int right, int bottom)
    {
        this.left = left;
        this.top = top;
        this.right = right;
        this.bottom = bottom;
    }

    int width()
    {
        return right-left;
    }
    
    int height()
    {
        return bottom-top;
    }

    IPoint center()
    {
        return IPoint((right+left)/2,(top+bottom)/2);
    }

    bool isEmpty()
    {
        return ((left == right) || (top == bottom));
    }

    bool isOrdered()
    {
        return ((left < right) && (top < bottom));
    }  
}

/**
  2D Point
*/

struct Point(T)
    if (isFloatOrDouble!(T))
{
    T x = 0;
    T y = 0;

    this(T x, T y)
    {
        this.x = x;
        this.y = y;
    }

    this(T[2] coords)
    {
        this.x = coords[0];
        this.y = coords[1];
    }

    bool isZero()
    {
        return ((x == 0) && (y == 0));
    }

    Point!T opBinary(string op, RHS)(RHS rhs)
    {
        static if (is(RHS == Point!float) || is(RHS == Point!double))
        {
            static if (op == "+")
            {
                return Point!T(x+rhs.x, y+rhs.y);
            }
            else static if (op == "-")
            {
                return Point!T(x-rhs.x, y-rhs.y);
            }
            else static if (op == "*")
            {
                return Point!T(x*rhs.x, y*rhs.y);
            }
        }
        else static if (is(RHS == float) || is(RHS == double))
        {
            static if (op == "+")
            {
                return Point!T(x+rhs, y+rhs);
            }
            else static if (op == "-")
            {
                return Point!T(x-rhs, y-rhs);
            }
            else static if (op == "*")
            {
                return Point!T(x*rhs, y*rhs);
            }
        }
        else static if (is(RHS == float[2]) || is(RHS == double[2]))
        {
            static if (op == "+")
            {
                return Point!T(x+rhs[0], y+rhs[1]);
            }
            else static if (op == "-")
            {
                return Point!T(x-rhs[0], y-rhs[1]);
            }
            else static if (op == "*")
            {
                return Point!T(x*rhs[0], y*rhs[1]);
            }
        }
        assert(0); // type not supported
    }
}

/**
  2D rectangle
*/

/*
  using x0,y0,x1,y1 etc.. gives loosely implied ordering
  could add left, top, etc getters and setters?? Could be
  mapped differently depending on canvas orientation?
*/

struct Rect(T)
    if (isFloatOrDouble!(T))
{
    T x0 = 0;
    T y0 = 0;
    T x1 = 0;
    T y1 = 0;

    this(T x0, T y0, T x1, T y1)
    {
        this.x0 = x0;
        this.y0 = y0;
        this.x1 = x1;
        this.y1 = y1;
    }

    T width()
    {
        return x1-x0;
    }
    
    T height()
    {
        return y1-y0;
    }

    T area()
    {
        return width*height;
    }

    Point!T center()
    {
        return Point!T((x0+x1)/2,(y0+y1)/2);
    }

    bool isEmpty()
    {
        return ((x0 == x1) || (y0 == y1));
    }

    bool isOrdered()
    {
        return ((x0 < x1) && (y0 < y1));
    }

    Rect!T opBinary(string op, RHS)(RHS rhs)
    {
        static if (is(RHS == Point!float) || is(RHS == Point!double))
        {
            static if (op == "+")
            {
                return Rect!T(x0+rhs.x, y0+rhs.y, x1+rhs.x, y1+rhs.y);
            }
            else static if (op == "-")
            {
                return Rect!T(x0-rhs.x, y0-rhs.y, x1-rhs.x, y1-rhs.y);
            }
            else static if (op == "*")
            {
                return Rect!T(x0*rhs.x, y0*rhs.y, x1*rhs.x, y1*rhs.y);
            }
        }
        else static if (is(RHS == float) || is(RHS == double))
        {
            static if (op == "*")
            {
                return Rect!T(x0*rhs, y0*rhs, x1*rhs.x, y1*rhs);
            }
        }
        else static if (is(RHS == float[1]) || is(RHS == double[]))
        {
            static if (op == "+")
            {
                return Rect!T(x0+rhs[0], y0+rhs[1], x1+rhs[0], y1+rhs[1]);
            }
            else static if (op == "-")
            {
                return Rect!T(x0-rhs[0], y0-rhs[1], x1-rhs[0], y1-rhs[1]);
            }
            else static if (op == "*")
            {
                return Rect!T(x0*rhs[0], y0*rhs[1], x1*rhs[0], y1*rhs[1]);
            }
        }
        else static assert(0); // type not supported
    }

    auto asPath()
    {
        struct RectAsPath
        {
        public:
            Point!T opIndex(size_t idx)
            {
                assert(idx < 5);
                switch(idx)
                {
                    case 0: return Point!T(m_rect.x0,m_rect.y0);
                    case 1: return Point!T(m_rect.x0,m_rect.y1);
                    case 2: return Point!T(m_rect.x1,m_rect.y1);
                    case 3: return Point!T(m_rect.x1,m_rect.y0);
                    case 4: return Point!T(m_rect.x0,m_rect.y0);
                    default: assert(0);
                }
            }

            PathCmd cmd(size_t idx)
            {
                if (idx == 0) return PathCmd.move;
                return PathCmd.line;
            }

            size_t length()
            {
                return 5;
            }

            this(Rect* rect)
            {
                m_rect = rect;
            }

        
            uint getAssignFlags(void* dest)
            {
                return 0;
            }
            
            Rect!T* m_rect;
        }

        return RectAsPath(&this);
    }
}

/**
  intersection of two rectangles
*/

Rect!T intersect(T)(ref Rect!T a, ref Rect!T b)
{
    Rect!T r;
    r.x0 = max(a.x0, b.x0);
    r.y0 = max(a.y0, b.y0);
    r.x1 = min(a.x1, b.x1);
    r.y1 = min(a.y1, b.y1);
    return r;
}

Rect!T intersect(T)(ref Rect!T a, T x0, T y0, T x1, T y1)
{
    Rect!T r;
    r.x0 = max(a.x0, x0);
    r.y0 = max(a.y0, y0);
    r.x1 = min(a.x1, x1);
    r.y1 = min(a.y1, y1);
    return r;
}

/**
  union of two rectangles
*/

Rect!T combine(T)(ref Rect!T a, ref Rect!T b)
{
    Rect!T r;
    r.x0 = min(a.x0, b.x0);
    r.y0 = min(a.y0, b.y0);
    r.x1 = max(a.x1, b.x1);
    r.y1 = max(a.y1, b.y1);
    return r;
}

Rect!T combine(T)(ref Rect!T a, T x0, T y0, T x1, T y1)
{
    Rect!T r;
    r.x0 = min(a.x0, x0);
    r.y0 = min(a.y0, y0);
    r.x1 = max(a.x1, x1);
    r.y1 = max(a.y1, y1);
    return r;
}

/**
  offset rect
*/

Rect!T offset(T)(Rect!T rect, T x, T y)
{
    Rect!T r;
    r.x0 = rect.x0 + x;
    r.y0 = rect.y0 + y;
    r.x1 = rect.x1 + x;
    r.y1 = rect.y1 + y;
    return r;
}

/**
  scale rect
*/

Rect!T scale(T)(Rect!T rect, T x, T y)
{
    Rect!T r;
    r.x0 = rect.x0 * x;
    r.y0 = rect.y0 * y;
    r.x1 = rect.x1 * x;
    r.y1 = rect.y1 * y;
    return r;
}

/**
  inset rect
*/

Rect!T inset(T)(Rect!T rect, T i)
{
    Rect!T r;
    r.x0 = rect.x0 + i;
    r.y0 = rect.y0 + i;
    r.x1 = rect.x1 - i;
    r.y1 = rect.y1 - i;
    return r;
}

/**
  outset rect
*/

Rect!T outset(T)(Rect!T rect, T o)
{
    Rect!T r;
    r.x0 = rect.x0 - o;
    r.y0 = rect.y0 - o;
    r.x1 = rect.x1 + o;
    r.y1 = rect.y1 + o;
    return r;
}

struct Size(T)
{
    T w = 0;
    T h = 0;

    this(T w, T h)
    {
        this.w = w;
        this.h = h;
    }

    bool isZero()
    {
        return ((w == 0) && (h == 0));
    }
}

struct RRect(T)
{
    T x0 = 0;
    T y0 = 0;
    T x1 = 0;
    T y1 = 0;
    Size!T r00; // x0,y0
    Size!T r10; // x1,y0
    Size!T r11; // x1,y1
    Size!T r01; // x0,y1

    // ideally disallow negative radius

    this(T x0, T y0, T x1, T y1, T cw, T ch)
    {
        this.x0 = x0;
        this.y0 = y0;
        this.x1 = x1;
        this.y1 = y1;
    }

    T width()
    {
        return x1-x0;
    }
    
    T height()
    {
        return y1-y0;
    }
    
    T area()
    {
        return width*height;
    }
    
    bool isEmpty()
    {
        return ((x0 == x1) || (y0 == y1));
    }
}

