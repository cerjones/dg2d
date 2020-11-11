/**
  2D line segment type.

  Copyright: Chris Jones
  License: Boost Software License, Version 1.0
  Authors: Chris Jones
*/

module dg2d.line;

import dg2d.scalar;
import dg2d.point;
import dg2d.misc;

//import std.algorithm: among;

/**
  2D line segment
*/

struct Line
{
    Scalar x0 = 0;
    Scalar y0 = 0;
    Scalar x1 = 0;
    Scalar y1 = 0;

    this(Scalar x0, Scalar y0, Scalar x1, Scalar y1)
    {
        this.x0 = x0;
        this.y0 = y0;
        this.x1 = x1;
        this.y1 = y1;
    }

    Scalar dx()
    {
        return x1-x0;
    }
    
    Scalar dy()
    {
        return y1-y0;
    }

    Scalar length()
    {
        return sqrt(sqr(dx)+sqr(dy));
    }

    Point midPoint()
    {
        return Point((x0+x1)/2,(y0+y1)/2);
    }
}
