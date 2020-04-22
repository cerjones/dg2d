/*
  Copyright Chris Jones 2020.
  Distributed under the Boost Software License, Version 1.0.
  See accompanying file Licence.txt or copy at...
  https://www.boost.org/LICENSE_1_0.txt
*/

module geometry.common;

import misc;

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
}

struct Rect(T)
{
    T x0 = 0;
    T y0 = 0;
    T x1 = 0;
    T y1 = 0;

    T width() { return x1-x0; }
    T height() { return y1-y0; }
    T area() { return width*height; }
    
    this(T x0, T y0, T x1, T y1)
    {
        this.x0 = x0;
        this.y0 = y0;
        this.x1 = x1;
        this.y1 = y1;
    }
}

struct Size(T)
{
    T width = 0;
    T height = 0;

    this(T width, T height)
    {
        this.width = width;
        this.height = height;
    }
}

