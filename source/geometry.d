/**
  This module provides basic 2D geometric primates.

  Copyright: Chris Jones
  License: Boost Software License, Version 1.0
  Authors: Chris Jones

  General features...

  asPath can be used to get a lazy iterator that returns the shape as a path
  that can be used with the path adaptors, and assigned to a path. EG..

  ---
  auto rect = RoundRect!float(10,10,20,20,3,3);
  rasterizer.addPath(rect.asPath.offset(100,100));
  Path!float path;
  path.append(rect.asPath.retro);
  ---

*/

module dg2d.geometry;

import dg2d.misc;
import dg2d.path;

import std.algorithm: among;

/**
  Integer 2D point
*/

public:

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
 
  This is typically for defining rectanges on strict pixel boundaries. Like
  clip regions, or Window position, etc. 
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
  
    bool isEmpty()
    {
        return ((left >= right) || (top >= bottom));
    }
}

/** Offset IRect */

IRect offset(IRect rect, int x, int y)
{
    return IRect(rect.left+x, rect.top+y, rect.right+x, rect.bottom+y);
}

/** Insection of two IRects */

IRect intersect(IRect a, IRect b)
{
    return IRect(
        max(a.left, b.left), max(a.top, b.top),
        min(a.right, b.right), min(a.bottom, b.bottom)
        );
}

/** union of two IRects */

IRect combine(IRect a, IRect b)
{
    return IRect(
        min(a.left, b.left), min(a.top, b.top),
        max(a.right, b.right), max(a.bottom, b.bottom)
        );
}

/**
  2D Point
*/

struct Point(T)
    if (is(T == float) || is(T == double))
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

    /* should this check and promote return type to double if rhs
     is double and lhs is float? */

    Point!T opBinary(string op)(Point rhs)
        if (op.among!("+", "-", "*"))
    {
        mixin("return Point!T(x "~op~" rhs.x, y "~op~"rhs.y);");
    }

    Point!T opBinary(string op, F)(F[2] rhs)
        if (op.among!("+", "-", "*") && isFloatOrDouble(F))
    {
        mixin("return Point!T(x "~op~" rhs[0], y "~op~"rhs[1]);");
    }

    Point!T opBinary(string op, F)(F rhs)
        if (op.among!("+", "-", "*") && (is(F == float) || is(F == double)))
    {
        mixin("return Point!T(x "~op~" rhs, y "~op~"rhs);");
    }

    Point!T offset(T x, T y)
    {
        return Point!T(this.x+x, this.y+y);
    }

    Point!T scale(T sx, T sy)
    {
        return Point!T(this.x*x, this.y*y);
    }

    Point!T scale(T sx, T sy, T focus_x, T focus_y)
    {
        return Point!T((this.x-focus_x)*sx+focus_x, (this.y-focus_y)*sy+focus_y);
    }

    // need to have ones that pass in sin/cos values rather than call math funcs each time
    // as they are very slow

    Point!T rotate(T angle) 
    {
        import std.math;

        T sina = cast(T) sin(angle*2*PI/360);
        T cosa = cast(T) cos(angle*2*PI/360);
        return Point!T(x*cosa-y*sina, x*sina+y*cosa);
    }

    Point!T rotate(T angle, T focus_x, T focus_y)
    {
        import std.math;

        T sina = cast(T) sin(angle*2*PI/360);
        T cosa = cast(T) cos(angle*2*PI/360);
        return Point!T(
            (x-focus_x)*cosa-(y-focus_y)*sina+focus_x,
            (x-focus_x)*sina+(y-focus_y)*cosa+focus_y
            );
    }

}

/**
  2D rectangle
*/

/*
  using x0,y0,x1,y1 etc.. gives loosely implied ordering
  could add left, top, etc getters and setters?? Could be
  mapped differently depending on canvas orientation?

  some functions rely on the coordinates being ordered, should
  maybe add checks to either ensure ordering when needed or prevent
  coords becoming unordered ?
*/

struct Rect(T)
    if (is(T == float) || is(T == double))
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
        return ((x0 >= x1) || (y0 >= y1));
    }

    Rect!T opBinary(string op)(Point rhs)
        if (op.among!("+", "-", "*"))
    {
        mixin("return Rect!T(x0 "~op~" rhs.x, y0 "~op~"rhs.y, x1 "
          ~op~" rhs.x, y1 "~op~"rhs.y);");
    }

    Rect!T opBinary(string op, F)(F[2] rhs)
        if (op.among!("+", "-", "*") && isFloatOrDouble(F))
    {
        mixin("return Rect!T(x0 "~op~" rhs[0], y0 "~op~"rhs[1], x1 "
          ~op~" rhs[0], y1 "~op~"rhs[1]);");
    }

    Rect!T opBinary(string op, F)(F rhs)
        if (op.among!("+", "-", "*") && (is(F == float) || is(F == double)))
    {
        mixin("return Rect!T(x0 "~op~" rhs, y0 "~op~"rhs, x1 "
          ~op~" rhs, y1 "~op~"rhs);");
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
            size_t length() { return 5; }
            void* source() { return &this; }
            bool inPlace() { return true; }      
        private:
            Rect!T* m_rect;
        }

        return RectAsPath(&this);
    }
}

enum bool isRect(T) = (is(T == Rect!float) || is(T == Rect!double));

enum bool isRoundRect(T) = (is(T == RoundRect!float) || is(T == RoundRect!double));

/**
  intersection of two Rects or RoundRect
*/

auto intersect(T)(ref T a, ref T b)
    if(isRect!T || isRoundRect!T)
{
    return T(
        max(a.x0, b.x0), max(a.y0, b.y0),
        min(a.x1, b.x1), min(a.y1, b.y1)
        );
}

/**
  union of two Rect or RoundRect
*/

auto combine(T)(ref T a, ref T b)
    if(isRect!T || isRoundRect!T)
{
    return T(
        min(a.x0, b.x0), min(a.y0, b.y0),
        max(a.x1, b.x1), max(a.y1, b.y1)
        );
}

/**
  offset Rect or RoundRect
*/

auto offset(T,Q)(T rect, Q x, Q y)
    if(isRect!T || isRoundRect!T)
{
    return T(rect.x0 + x, rect.y0 + y, rect.x1 + x, rect.y1 + y);
}

/**
  scale rect
*/

auto scale(T,Q)(T rect, Q x, Q y)
    if(isRect!T || isRoundRect!T)
{
    return T(rect.x0 * x, rect.y0 * y, rect.x1 * x, rect.y1 * y);
}


/** inset rect */

// Should it ensure the inset rect is still ordered?
// Should it prevent it from becoming unordered?

T inset(T,Q)(T rect, Q delta)
    if(isRect!T)
{
    return T(rect.x0 + delta, rect.y0 + delta,
        rect.x1 - delta,rect.y1 - delta);
}

/** inset RoundRect, if you 'adjustCorners' the inset rect will have
corners that try to maintain equal distance from the source 
rectangle, (eventually they get too small) */

T inset(T,Q)(T rect, Q delta, bool adjustCorners = false)
    if(isRoundRect!T)
{
    T r = T(rect.x0 + delta, rect.y0 + delta,
        rect.x1 - delta, rect.y1 - delta);

    if (adjustCorners) 
    {
        static foreach (i; 0..4)
        {
            r.xRad[i] = max(0,rect.xRad[i]-delta);
            r.yRad[i] = max(0,rect.yRad[i]-delta);
        }
    }
    else
    {
        static foreach (i; 0..4)
        {
            r.xRad[i] = rect.xRad[i];
            r.yRad[i] = rect.yRad[i];
        }
    }
    return r;
}

/** outset Rect */

T outset(T,Q)(T rect, Q delta)
    if(isRect!T)
{
    return T(rect.x0 - delta, rect.y0 - delta,
        rect.x1 + delta,rect.y1 + delta);
}

/** outset RoundRect, if you adjustCorners the outset rect will have
corners that maintain equal distance from the source rectangle */

T outset(T,Q)(T rect, Q delta, bool adjustCorners = false)
    if(isRoundRect!T)
{
    T r = T(rect.x0 - delta, rect.y0 - delta,
        rect.x1 + delta, rect.y1 + delta);

    if (adjustCorners) 
    {
        static foreach (i; 0..4)
        {
            r.xRad[i] = rect.xRad[i]+delta;
            r.yRad[i] = rect.yRad[i]+delta;
        }
    }
    else
    {
        static foreach (i; 0..4)
        {
            r.xRad[i] = rect.xRad[i];
            r.yRad[i] = rect.yRad[i];
        }
    }

    return r;
}

// not sure if theres any need for this?

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
        return ((w <= 0) && (h <= 0));
    }
}

/* Corner indexing is clockwise from top left */

struct RoundRect(T)
{
    T x0 = 0, y0 = 0, x1 = 0, y1 = 0;
    T[4] xRad = 0;
    T[4] yRad = 0;

    /** Construct without rounded corners */    

    this(T x0, T y0, T x1, T y1)
    {
        this.x0 = x0;
        this.y0 = y0;
        this.x1 = x1;
        this.y1 = y1;
    }

    /** Construct with same radius on all corners */    

    this(T x0, T y0, T x1, T y1, T xRad, T yRad)
    {
        this.x0 = x0;
        this.y0 = y0;
        this.x1 = x1;
        this.y1 = y1;
        this.xRad = xRad;
        this.yRad = yRad;
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
        return ((x0 >= x1) || (y0 >= y1));
    }

    bool isOrdered()
    {
        return ((x0 < x1) && (y0 < y1));
    }

    /* note these operators dont effect corner sizes */

    Rect!T opBinary(string op)(Point rhs)
        if (op.among!("+", "-", "*"))
    {
        mixin("return Rect!T(x0 "~op~" rhs.x, y0 "~op~"rhs.y, x1 "
          ~op~" rhs.x, y1 "~op~"rhs.y);");
    }

    Rect!T opBinary(string op, F)(F[2] rhs)
        if (op.among!("+", "-", "*") && isFloatOrDouble(F))
    {
        mixin("return Rect!T(x0 "~op~" rhs[0], y0 "~op~"rhs[1], x1 "
          ~op~" rhs[0], y1 "~op~"rhs[1]);");
    }

    Rect!T opBinary(string op, F)(F rhs)
        if (op.among!("+", "-", "*") && (is(F == float) || is(F == double)))
    {
        mixin("return Rect!T(x0 "~op~" rhs, y0 "~op~"rhs, x1 "
          ~op~" rhs, y1 "~op~"rhs);");
    }

    /*
      The corners are aproximated with a bezier curve. I used an optimization
      algorithm to find the best fit, and it's accurate to roughly 0.02%. So
      if the corner radius is 100 pixels, its 1/50 of a pixel error. 

      if we let q = 0.551915324

      then quater circular arc of radius 1 is (0,1)->(q,1)->(1,q)->(1,0)
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
        
            Point!T opIndex(size_t idx)
            {
                assert(idx < 17);
                switch(idx)
                {
                    case 0: return Point!T(m_rect.x0+m_rect.xRad[0],m_rect.y0);
                    case 1: return Point!T(m_rect.x1-m_rect.xRad[1],m_rect.y0);
                    case 2: return Point!T(m_rect.x1-m_rect.xRad[1]*CBEZ1,m_rect.y0);
                    case 3: return Point!T(m_rect.x1,m_rect.y0+m_rect.yRad[1]*CBEZ1);
                    case 4: return Point!T(m_rect.x1,m_rect.y0+m_rect.yRad[1]);
                    case 5: return Point!T(m_rect.x1,m_rect.y1-m_rect.yRad[2]);
                    case 6: return Point!T(m_rect.x1,m_rect.y1-m_rect.yRad[2]*CBEZ1);
                    case 7: return Point!T(m_rect.x1-m_rect.xRad[2]*CBEZ1,m_rect.y1);
                    case 8: return Point!T(m_rect.x1-m_rect.xRad[2],m_rect.y1);
                    case 9: return Point!T(m_rect.x0+m_rect.xRad[3],m_rect.y1);
                    case 10: return Point!T(m_rect.x0+m_rect.xRad[3]*CBEZ1,m_rect.y1);
                    case 11: return Point!T(m_rect.x0,m_rect.y1-m_rect.yRad[3]*CBEZ1);
                    case 12: return Point!T(m_rect.x0,m_rect.y1-m_rect.yRad[3]);
                    case 13: return Point!T(m_rect.x0,m_rect.y0+m_rect.yRad[0]);
                    case 14: return Point!T(m_rect.x0,m_rect.y0+m_rect.yRad[0]*CBEZ1);
                    case 15: return Point!T(m_rect.x0+m_rect.xRad[0]*CBEZ1,m_rect.y0);
                    case 16: return Point!T(m_rect.x0+m_rect.xRad[0],m_rect.y0);
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

            RoundRect!T* m_rect;
        }

        return RectAsPath(&this);
    }
}

/**
  2D line segment
*/

struct Line(T)
    if (is(T == float) || is(T == double))
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

    T dx()
    {
        return x1-x0;
    }
    
    T dy()
    {
        return y1-y0;
    }

    T length()
    {
        return sqrt(sqr(width)+sqr(height));
    }

    Point!T midPoint()
    {
        return Point!T((x0+x1)/2,(y0+y1)/2);
    }
/*
    Rect!T opBinary(string op)(Point rhs)
        if (op.among!("+", "-", "*"))
    {
        mixin("return Line!T(x0 "~op~" rhs.x, y0 "~op~"rhs.y, x1 "
          ~op~" rhs.x, y1 "~op~"rhs.y);");
    }

    Rect!T opBinary(string op, F)(F[2] rhs)
        if (op.among!("+", "-", "*") && isFloatOrDouble(F))
    {
        mixin("return Line!T(x0 "~op~" rhs[0], y0 "~op~"rhs[1], x1 "
          ~op~" rhs[0], y1 "~op~"rhs[1]);");
    }

    Rect!T opBinary(string op, F)(F rhs)
        if (op.among!("+", "-", "*") && (is(F == float) || is(F == double)))
    {
        mixin("return Line!T(x0 "~op~" rhs, y0 "~op~"rhs, x1 "
          ~op~" rhs, y1 "~op~"rhs);");
    }
*/
}

/**
  2D circle
*/

struct Circle(T)
    if (is(T == float) || is(T == double))
{
    T x0 = 0;
    T y0 = 0;
    T radius = 0;

    this(T x0, T y0, T radius)
    {
        this.x0 = x0;
        this.y0 = y0;
        this.radius = radius;
    }
/*
    Rect!T opBinary(string op)(Point rhs)
        if (op.among!("+", "-", "*"))
    {
        mixin("return Line!T(x0 "~op~" rhs.x, y0 "~op~"rhs.y, x1 "
          ~op~" rhs.x, y1 "~op~"rhs.y);");
    }

    Rect!T opBinary(string op, F)(F[2] rhs)
        if (op.among!("+", "-", "*") && isFloatOrDouble(F))
    {
        mixin("return Line!T(x0 "~op~" rhs[0], y0 "~op~"rhs[1], x1 "
          ~op~" rhs[0], y1 "~op~"rhs[1]);");
    }

    Rect!T opBinary(string op, F)(F rhs)
        if (op.among!("+", "-", "*") && (is(F == float) || is(F == double)))
    {
        mixin("return Line!T(x0 "~op~" rhs, y0 "~op~"rhs, x1 "
          ~op~" rhs, y1 "~op~"rhs);");
    }
*/

    auto asPath()
    {
        enum PathCmd[13] cmdlut = [
            PathCmd.move,PathCmd.cubic,PathCmd.cubic,PathCmd.cubic,
            PathCmd.cubic,PathCmd.cubic,PathCmd.cubic,
            PathCmd.cubic,PathCmd.cubic,PathCmd.cubic,
            PathCmd.cubic,PathCmd.cubic,PathCmd.cubic];

        struct CircleAsPath
        {
        public:
        
            Point!T opIndex(size_t idx)
            {
                assert(idx < 13);
                switch(idx)
                {
                    case 0: return Point!T(m_circle.x0,m_circle.y0+m_circle.radius);
                    case 1: return Point!T(m_circle.x0+m_circle.radius*CBEZ2,m_circle.y0+m_circle.radius);
                    case 2: return Point!T(m_circle.x0+m_circle.radius,m_circle.y0+m_circle.radius*CBEZ2);
                    case 3: return Point!T(m_circle.x0+m_circle.radius,m_circle.y0);
                    case 4: return Point!T(m_circle.x0+m_circle.radius,m_circle.y0-m_circle.radius*CBEZ2);
                    case 5: return Point!T(m_circle.x0+m_circle.radius*CBEZ2,m_circle.y0-m_circle.radius);
                    case 6: return Point!T(m_circle.x0,m_circle.y0-m_circle.radius);
                    case 7: return Point!T(m_circle.x0-m_circle.radius*CBEZ2,m_circle.y0-m_circle.radius);
                    case 8: return Point!T(m_circle.x0-m_circle.radius,m_circle.y0-m_circle.radius*CBEZ2);
                    case 9: return Point!T(m_circle.x0-m_circle.radius,m_circle.y0);
                    case 10: return Point!T(m_circle.x0-m_circle.radius,m_circle.y0+m_circle.radius*CBEZ2);
                    case 11: return Point!T(m_circle.x0-m_circle.radius*CBEZ2,m_circle.y0+m_circle.radius);
                    case 12: return Point!T(m_circle.x0,m_circle.y0+m_circle.radius);
                    default: assert(0);
                }
            }

            PathCmd cmd(size_t idx)
            {
                assert(idx < 13);
                return cmdlut[idx];
            }

            size_t length() { return 13; }
            void* source() { return &this; }
            bool inPlace() { return true; }
        
        private:

            Circle!T* m_circle;
        }

        return CircleAsPath(&this);
    }

}

/**
  2D Elipse
  x0,y0 is the center of the elipse
  x1,y1 is the radius at 0 degrees
  x2,y2 is the radius at 90 degrees

  if you have a circle of radius 1 at the origin, then imagine it transformed so that..
  (0,0)-->(x0,y0)
  (1,0)-->(x1,y1)
  (0,1)-->(x2,y2)
*/

/*
 maybe need simple elipse, origin,width,height, and freeform elipse, ??
*/

struct Elipse(T)
    if (is(T == float) || is(T == double))
{
    T x0 = 0;
    T y0 = 0;
    T x1 = 0;
    T y1 = 0;
    T x2 = 0;
    T y2 = 0;

    this(T x0, T y0, T x1, T y1, T x2, T y2)
    {
        this.x0 = x0;
        this.y0 = y0;
        this.x1 = x1;
        this.y1 = y1;
        this.x2 = x2;
        this.y2 = y2;
    }

/*
    Rect!T opBinary(string op)(Point rhs)
        if (op.among!("+", "-", "*"))
    {
        mixin("return Line!T(x0 "~op~" rhs.x, y0 "~op~"rhs.y, x1 "
          ~op~" rhs.x, y1 "~op~"rhs.y);");
    }

    Rect!T opBinary(string op, F)(F[2] rhs)
        if (op.among!("+", "-", "*") && isFloatOrDouble(F))
    {
        mixin("return Line!T(x0 "~op~" rhs[0], y0 "~op~"rhs[1], x1 "
          ~op~" rhs[0], y1 "~op~"rhs[1]);");
    }

    Rect!T opBinary(string op, F)(F rhs)
        if (op.among!("+", "-", "*") && (is(F == float) || is(F == double)))
    {
        mixin("return Line!T(x0 "~op~" rhs, y0 "~op~"rhs, x1 "
          ~op~" rhs, y1 "~op~"rhs);");
    }
*/
}

private:

enum double CBEZ1 = 0.448084676; // coeficient for cirlces made from beziers
enum double CBEZ2 = 0.551915324; // coeficient for cirlces made from beziers
