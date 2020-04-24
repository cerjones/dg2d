/*
  Copyright Chris Jones 2020.
  Distributed under the Boost Software License, Version 1.0.
  See accompanying file Licence.txt or copy at...
  https://www.boost.org/LICENSE_1_0.txt
*/

module dg2d.geometry;

import dg2d.misc;

struct Point(T)
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

    void offset(T dx, T dy)
    {
        x += dx;
        y += dy;
    }

    void scale(T sx, T sy)
    {
        x *= sx;
        y *= sy;
    }
}

struct Rect(T)
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
    
    bool isEmpty()
    {
        return ((x0 >= x1) || (y0 >= y1));
    }

    void offset(T dx, T dy)
    {
        x0 += dx;
        y0 += dy;
        x1 += dx;
        y1 += dy;
    }

    void scale(T sx, T sy)
    {
        x0 *= sx;
        y0 *= sy;
        x1 *= sx;
        y1 *= sy;
    }
}

Rect!T intersect(T)(ref Rect!T a, ref Rect!T b)
{
    Rect!T r;
    r.x0 = max(a.x0, b.x0);
    r.x1 = min(a.x1, b.x1);
    r.y0 = max(a.y0, b.y0);
    r.y1 = min(a.y1, b.y1);
    return r;
}

Rect!T intersect(T)(ref Rect!T a, T x0, T y0, T x1, T y1)
{
    Rect!T r;
    r.x0 = max(a.x0, x0);
    r.x1 = min(a.x1, x1);
    r.y0 = max(a.y0, y0);
    r.y1 = min(a.y1, y1);
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
        return ((x0 >= x1) || (y0 >= y1));
    }

    void offset(T dx, T dy)
    {
        x0 += dx;
        y0 += dy;
        x1 += dx;
        y1 += dy;
    }

    void scale(T sx, T sy)
    {
        x0 *= sx;
        y0 *= sy;
        x1 *= sx;
        y1 *= sy;
    }
}

