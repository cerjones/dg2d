/**
  This module provides a RoundRect type.

  Copyright: Chris Jones
  License: Boost Software License, Version 1.0
  Authors: Chris Jones

  General features...

  Custom radius on all four corners
  asPath can be used to get a PathIterator to trace the outline
  offset,scale,inset,outset,intersection and combine (IE union)
  operator overloads and free functions
*/

module dg2d.roundrect;

import dg2d.scalar;
import dg2d.point;
import dg2d.rect;
import dg2d.misc;
import dg2d.path;

import std.algorithm: among;

/** Rounded rectangle. */

struct RoundRect
{
    Scalar x0 = 0;
    Scalar y0 = 0;
    Scalar x1 = 0;
    Scalar y1 = 0;
    float[4] xRad = 0;
    float[4] yRad = 0;

    /** Construct a RoundRect with square corners. */    

    this(Scalar x0, Scalar y0, Scalar x1, Scalar y1)
    {
        this.x0 = x0;
        this.y0 = y0;
        this.x1 = x1;
        this.y1 = y1;
    }

    /** Construct a RoundRect with circular corners. */    

    this(Scalar x0, Scalar y0, Scalar x1, Scalar y1, Scalar rad)
    {
        this.x0 = x0;
        this.y0 = y0;
        this.x1 = x1;
        this.y1 = y1;
        this.xRad = rad;
        this.yRad = rad;
    }

    /** Construct a RoundRect with eliptical corners. */    

    this(Scalar x0, Scalar y0, Scalar x1, Scalar y1, Scalar xRad, Scalar yRad)
    {
        this.x0 = x0;
        this.y0 = y0;
        this.x1 = x1;
        this.y1 = y1;
        this.xRad = xRad;
        this.yRad = yRad;
    }

    /** Construct a RoundRect specifying each corner seperately. */    

    this(Scalar x0, Scalar y0, Scalar x1, Scalar y1, float[4] xRad, float[4] yRad)
    {
        this.x0 = x0;
        this.y0 = y0;
        this.x1 = x1;
        this.y1 = y1;
        this.xRad = xRad;
        this.yRad = yRad;
    }

    /** returns the width */

    Scalar width()
    {
        return x1-x0;
    }

    /** returns the height */
    
    Scalar height()
    {
        return y1-y0;
    }

    /** returns the area */

    Scalar area()
    {
        return width*height;
    }

    /** returns the center of the rect */

    Point center()
    {
        return Point((x0+x1)/2,(y0+y1)/2);
    }

    /** Returns true if (x0 >= x1) or (y0 >= y1) */

    bool isEmpty()
    {
        return ((x0 >= x1) || (y0 >= y1));
    }

    /* operator overload for add and subtract */
 
    RoundRect opBinary(string op)(Point rhs)
        if (op.among!("+", "-"))
    {
        mixin("return Rect!T(x0 "~op~" rhs.x, y0 "~op~"rhs.y, x1 "
          ~op~" rhs.x, y1 "~op~"rhs.y);");
    }

    /* operator overload for multiply */

    RoundRect opBinary(string op)(Point rhs)
        if (op == "*")
    {
        return RoundRect(
            x0*rhs.x, y0*rhs.y, x1*rhs.x, y1*rhs.y,
            [xRad[0]*rhs.x, xRad[1]*rhs.x, xRad[2]*rhs.x, xRad[3]*rhs.x],
            [yRad[0]*rhs.y, yRad[1]*rhs.y, yRad[2]*rhs.y, yRad[3]*rhs.y]
            );
    }

    /* operator overload for add and subtract */
 
    RoundRect opBinary(string op)(Scalar[2] rhs)
        if (op.among!("+", "-"))
    {
        mixin("return Rect!T(x0 "~op~" rhs[0], y0 "~op~"rhs[1], x1 "
          ~op~" rhs[0], y1 "~op~"rhs[1]);");
    }

    /* operator overload for multiply */

    RoundRect opBinary(string op)(Scalar[2] rhs)
        if (op == "*")
    {
        return RoundRect(
            x0*rhs[0], y0*rhs[1], x1*rhs[0], y1*rhs[1],
            [xRad[0]*rhs[0], xRad[1]*rhs[0], xRad[2]*rhs[0], xRad[3]*rhs[0]],
            [yRad[0]*rhs[1], yRad[1]*rhs[1], yRad[2]*rhs[1], yRad[3]*rhs[1]]
            );
    }

    /* operator overload for multiply */

    RoundRect opBinary(string op)(Scalar rhs)
        if (op == "*")
    {
        return RoundRect(
            x0*rhs, y0*rhs, x1*rhs, y1*rhs,
            [xRad[0]*rhs, xRad[1]*rhs, xRad[2]*rhs, xRad[3]*rhs],
            [yRad[0]*rhs, yRad[1]*rhs, yRad[2]*rhs, yRad[3]*rhs]
            );
    }

    /*
      The corners are aproximated with a bezier curve. Look up CBezInset
      in scalar.d for more info.
    */

    auto asPath()
    {
        enum PathCmd[17] cmdlut = [
            PathCmd.move,PathCmd.line,PathCmd.cubic,PathCmd.cubic,PathCmd.cubic,
            PathCmd.line,PathCmd.cubic,PathCmd.cubic,PathCmd.cubic,
            PathCmd.line,PathCmd.cubic,PathCmd.cubic,PathCmd.cubic,
            PathCmd.line,PathCmd.cubic,PathCmd.cubic,PathCmd.cubic];

        struct RectAsPath
        {
        public:
            Point opIndex(size_t idx)
            {
                assert(idx < 17);
                switch(idx)
                {
                    case 0: return Point(m_rect.x0+m_rect.xRad[0],m_rect.y0);
                    case 1: return Point(m_rect.x1-m_rect.xRad[1],m_rect.y0);
                    case 2: return Point(m_rect.x1-m_rect.xRad[1]*CBezInset,m_rect.y0);
                    case 3: return Point(m_rect.x1,m_rect.y0+m_rect.yRad[1]*CBezInset);
                    case 4: return Point(m_rect.x1,m_rect.y0+m_rect.yRad[1]);
                    case 5: return Point(m_rect.x1,m_rect.y1-m_rect.yRad[2]);
                    case 6: return Point(m_rect.x1,m_rect.y1-m_rect.yRad[2]*CBezInset);
                    case 7: return Point(m_rect.x1-m_rect.xRad[2]*CBezInset,m_rect.y1);
                    case 8: return Point(m_rect.x1-m_rect.xRad[2],m_rect.y1);
                    case 9: return Point(m_rect.x0+m_rect.xRad[3],m_rect.y1);
                    case 10: return Point(m_rect.x0+m_rect.xRad[3]*CBezInset,m_rect.y1);
                    case 11: return Point(m_rect.x0,m_rect.y1-m_rect.yRad[3]*CBezInset);
                    case 12: return Point(m_rect.x0,m_rect.y1-m_rect.yRad[3]);
                    case 13: return Point(m_rect.x0,m_rect.y0+m_rect.yRad[0]);
                    case 14: return Point(m_rect.x0,m_rect.y0+m_rect.yRad[0]*CBezInset);
                    case 15: return Point(m_rect.x0+m_rect.xRad[0]*CBezInset,m_rect.y0);
                    case 16: return Point(m_rect.x0+m_rect.xRad[0],m_rect.y0);
                    default: assert(0);
                }
            }
            PathCmd cmd(size_t idx)
            {
                assert(idx < 17);
                return cmdlut[idx];
            }
            size_t length() { return 17; }
            void* source() { return &this; }
            bool inPlace() { return true; }
        private:
            RoundRect* m_rect;
        }

        return RectAsPath(&this);
    }
}

/**
  Returns rect offset by x,y
*/

RoundRect offset(RoundRect rect, Scalar x, Scalar y)
{
    return RoundRect(rect.x0+x,rect.y0+y,rect.x1+x,rect.y1+y);
}

/**
  Returns rect offset point
*/

RoundRect offset(RoundRect rect, Point point)
{
    return RoundRect(rect.x0+point.x,rect.y0+point.y,rect.x1+point.x,rect.y1+point.y);
}

/**
  Returns rect scaled by scale_x,scale_y
*/

RoundRect scale(RoundRect rect, Scalar scale_x, Scalar scale_y)
{
    return rect * [scale_x,scale_y];
}

/**
  Returns rect inset by delta, if you "adjustCorners" the corners will
  be adjusted to maintain equal distance from the source rect. (unless
  they get too small)
*/

RoundRect inset(bool adjustCorners = true)(RoundRect rect, Scalar delta)
{
    RoundRect tmp = RoundRect(rect.x0 + delta, rect.y0 + delta,
        rect.x1 - delta, rect.y1 - delta);

    static if (adjustCorners) 
    {
        static foreach (i; 0..4)
        {
            tmp.xRad[i] = max(0,rect.xRad[i]-delta);
            tmp.yRad[i] = max(0,rect.yRad[i]-delta);
        }
    }
    else
    {
        tmp.xRad = rect.xRad;
        tmp.yRad = rect.yRad;
    }
    return tmp;
}

/**
  Returns rect outset by delta, if you "adjustCorners" the corners will
  be adjusted to maintain equal distance from the source rect.
*/

RoundRect outset(bool adjustCorners = true)(RoundRect rect, Scalar delta)
{
    RoundRect tmp = RoundRect(rect.x0 - delta, rect.y0 - delta,
        rect.x1 + delta, rect.y1 + delta);

    static if (adjustCorners) 
    {
        static foreach (i; 0..4)
        {
            tmp.xRad[i] = max(0,rect.xRad[i]+delta);
            tmp.yRad[i] = max(0,rect.yRad[i]+delta);
        }
    }
    else
    {
        tmp.xRad = rect.xRad;
        tmp.yRad = rect.yRad;
    }
    return tmp;
}

/**
  returns the intersection of a and b, returns a plain rect as not sure what to do with
  the corners.
*/

Rect intersect(RoundRect a, RoundRect b)
{
    return Rect(
        max(a.x0, b.x0), max(a.y0, b.y0),
        min(a.x1, b.x1), min(a.y1, b.y1)
        );
}

/**
  returns the union of a and b, returns a plain rect as not sure what to do with
  the corners.
*/

Rect combine(RoundRect a, RoundRect b)
{
    return Rect(
        min(a.x0, b.x0), min(a.y0, b.y0),
        max(a.x1, b.x1), max(a.y1, b.y1)
        );
}

