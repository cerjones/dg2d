/**
  Scalar and integer 2D rect types.

  Copyright: Chris Jones
  License: Boost Software License, Version 1.0
  Authors: Chris Jones
*/

module dg2d.rect;

import dg2d.scalar;
import dg2d.point;
import dg2d.misc;
import dg2d.path;

import std.algorithm: among;

/**
  Integer 2D rectangle.
 
  This is typically used for specifying rectanges in exact pixel coordinates. Like
  clip regions, or Window position, etc. 
*/

struct IRect
{
    int left;
    int top;
    int right;
    int bottom;

    /** Constructs a IRect with the spefcified coordinates */

    this(int left, int top, int right, int bottom)
    {
        this.left = left;
        this.top = top;
        this.right = right;
        this.bottom = bottom;
    }

    /** returns the width of the rectangle */

    int width()
    {
        return right-left;
    }
    
    /** returns the height of the rectangle */

    int height()
    {
        return bottom-top;
    }
  
    /** returns true if left > = right, or top >= bottom */

    bool isEmpty()
    {
        return ((left >= right) || (top >= bottom));
    }
}

/** Returns rect offset by x,y */

IRect offset(IRect rect, int x, int y)
{
    return IRect(rect.left+x, rect.top+y, rect.right+x, rect.bottom+y);
}

/** Returns rect offset by p */

IRect offset(IRect rect, IPoint p)
{
    return IRect(rect.left+p.x, rect.top+p.y, rect.right+p.x, rect.bottom+p.y);
}

/** Returns the insection of a and b */

IRect intersect(IRect a, IRect b)
{
    return IRect(
        max(a.left, b.left), max(a.top, b.top),
        min(a.right, b.right), min(a.bottom, b.bottom)
        );
}

/** Returns the union of a and b */

IRect combine(IRect a, IRect b)
{
    return IRect(
        min(a.left, b.left), min(a.top, b.top),
        max(a.right, b.right), max(a.bottom, b.bottom)
        );
}

/**
  2D rectangle
*/

struct Rect
{
    Scalar x0 = 0;
    Scalar y0 = 0;
    Scalar x1 = 0;
    Scalar y1 = 0;

    /** Constructs a Rect with the spefcified coordinates */

    this(Scalar x0, Scalar y0, Scalar x1, Scalar y1)
    {
        this.x0 = x0;
        this.y0 = y0;
        this.x1 = x1;
        this.y1 = y1;
    }

    /** Returns the width of the rectangle */

    Scalar width()
    {
        return x1-x0;
    }
    
    /** Returns the height of the rectangle */

    Scalar height()
    {
        return y1-y0;
    }

    /** Returns the area of the rectangle */

    Scalar area()
    {
        return width*height;
    }

    /** Returns the center of the rectangle */

    Point center()
    {
        return Point((x0+x1)/2,(y0+y1)/2);
    }

    /** Returns true if (x0 >= x1) or (y0 >= y1) */

    bool isEmpty()
    {
        return ((x0 >= x1) || (y0 >= y1));
    }

    /** operator overload for add, subtract or multiply. */

    Rect opBinary(string op)(Point rhs)
        if (op.among!("+", "-", "*"))
    {
        mixin("return Rect(x0 "~op~" rhs.x, y0 "~op~"rhs.y, x1 "
          ~op~" rhs.x, y1 "~op~"rhs.y);");
    }

    /** operator overload for add, subtract or multiply. */

    Rect opBinary(string op)(Scalar[2] rhs)
        if (op.among!("+", "-", "*"))
    {
        mixin("return Rect(x0 "~op~" rhs[0], y0 "~op~"rhs[1], x1 "
          ~op~" rhs[0], y1 "~op~"rhs[1]);");
    }

    /** operator overload for multiply */

    Rect opBinary(string op)(Scalar rhs)
        if (op == "*")
    {
        mixin("return Rect(x0 "~op~" rhs, y0 "~op~"rhs, x1 "
          ~op~" rhs, y1 "~op~"rhs);");
    }

    /** Returns a PathIterator for traversing the rectangle. */

    auto asPath()
    {
        struct RectAsPath
        {
        public:
            Point opIndex(size_t idx)
            {
                assert(idx < 5);
                switch(idx)
                {
                    case 0: return Point(m_rect.x0,m_rect.y0);
                    case 1: return Point(m_rect.x0,m_rect.y1);
                    case 2: return Point(m_rect.x1,m_rect.y1);
                    case 3: return Point(m_rect.x1,m_rect.y0);
                    case 4: return Point(m_rect.x0,m_rect.y0);
                    default: assert(0);
                }
            }
            PathCmd cmd(size_t idx)
            {
                if (idx == 0) return PathCmd.move;
                return PathCmd.line;
            }
            size_t length() { return 5; }
            void* source() { return &this; }
            bool inPlace() { return true; }      
        private:
            Rect* m_rect;
        }

        return RectAsPath(&this);
    }
}

/**
  Returns rect offset by x,y
*/

Rect offset(Rect rect, Scalar x, Scalar y)
{
    return Rect(rect.x0 + x, rect.y0 + y, rect.x1 + x, rect.y1 + y);
}

/**
  Returns rect offset by point
*/

Rect offset(Rect rect, Point point)
{
    return Rect(rect.x0 + point.x, rect.y0 + point.y, rect.x1 + point.x, rect.y1 + point.y);
}

/**
  Returns rect scaled by scale_x, scale_y
*/

Rect scale(Rect rect, Scalar scale_x, Scalar scale_y)
{
    return Rect(rect.x0 * scale_x, rect.y0 * scale_y, rect.x1 * scale_x, rect.y1 * scale_y);
}

/**
  Returns rect scaled by scale_x, scale_y relative to focus_x,focus_y
*/

Rect scale(Rect rect, Scalar scale_x, Scalar scale_y,
    Scalar focus_x, Scalar focus_y)
{
    return Rect((rect.x0 - focus_x) * scale_x + focus_x,
                (rect.y0 - focus_y) * scale_y + focus_y,
                (rect.x1 - focus_x) * scale_x + focus_x,
                (rect.y1 - focus_y) * scale_y + focus_y);
}

/**
  Returns the intersection of two Rects
*/

Rect intersect(Rect a, Rect b)
{
    return Rect(
        max(a.x0, b.x0), max(a.y0, b.y0),
        min(a.x1, b.x1), min(a.y1, b.y1)
        );
}

/**
  Returns the union of two Rects
*/

Rect combine(Rect a, Rect b)
{
    return Rect(
        min(a.x0, b.x0), min(a.y0, b.y0),
        max(a.x1, b.x1), max(a.y1, b.y1)
        );
}

/**
  Returns rect inset by delta.
*/

Rect inset(Rect rect, Scalar delta)
{
    Rect tmp = Rect(rect.x0 + delta, rect.y0 + delta, rect.x1 - delta, rect.y1 - delta);
    if (tmp.x0 > tmp.x1) tmp.x0 = tmp.x1 = (tmp.x0+tmp.x1)/2;
    if (tmp.y0 > tmp.y1) tmp.y0 = tmp.y1 = (tmp.y0+tmp.y1)/2;
    return tmp;
}

/** Returns rect outset by delta */

Rect outset(Rect rect, Scalar delta)
{
    return Rect(rect.x0 - delta, rect.y0 - delta, rect.x1 + delta, rect.y1 + delta);
}

/** Returns rect ordered so x0 < x1 and y0 < y1 */

Rect ordered(Rect rect)
{
    return Rect(min(rect.x0,rect.x1), min(rect.y0,rect.y0),
        max(rect.x0,rect.x1), max(rect.y0,rect.y1));
}