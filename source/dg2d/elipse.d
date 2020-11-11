/**
  2D elipse type.

  Copyright: Chris Jones
  License: Boost Software License, Version 1.0
  Authors: Chris Jones
*/

module dg2d.elipse;

import dg2d.scalar;
import dg2d.point;
import dg2d.misc;
import dg2d.path;

import std.algorithm: among;

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
 maybe need seperate simple elipse, origin,width,height, and freeform elipse as above, ??
*/

struct Elipse
{
    Scalar x0 = 0;
    Scalar y0 = 0;
    Scalar x1 = 0;
    Scalar y1 = 0;
    Scalar x2 = 0;
    Scalar y2 = 0;

    this(Scalar x0, Scalar y0, Scalar x1, Scalar y1, Scalar x2, Scalar y2)
    {
        this.x0 = x0;
        this.y0 = y0;
        this.x1 = x1;
        this.y1 = y1;
        this.x2 = x2;
        this.y2 = y2;
    }
}
