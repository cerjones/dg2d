/**
  Scalar and integer 2D point types.

  Copyright: Chris Jones
  License: Boost Software License, Version 1.0
  Authors: Chris Jones
*/

module dg2d.point;

import dg2d.scalar;

import std.algorithm: among;

/**
  Integer 2D point.
  
  This is typically used for specifying exact pixel coordinates.
*/

struct IPoint
{
    int x = 0;
    int y = 0;

    /** Constructs a IPoint with the spefcified coordinates */

    this(int x, int y)
    {
        this.x = x;
        this.y = y;
    }

    /** Constructs a IPoint with the spefcified coordinates */

    this(int[2] coords)
    {
        this.x = coords[0];
        this.y = coords[1];
    }

    /** returns true if x and y are both zero */

    bool isZero()
    {
        return ((x == 0) && (y == 0));
    }
}

/**
  2D Point.

  Floating point 2D point.
*/

struct Point
{
    Scalar x = 0;
    Scalar y = 0;

    /** Constructs a Point with the spefcified coordinates */

    this(Scalar x, Scalar y)
    {
        this.x = x;
        this.y = y;
    }

    /** Constructs a Point with the spefcified coordinates */

    this(Scalar[2] coords)
    {
        this.x = coords[0];
        this.y = coords[1];
    }

    /** returns true if x and y are both zero */

    bool isZero()
    {
        return ((x == 0) && (y == 0));
    }

    /** operator overload for add, subtract or multiply. */

    Point opBinary(string op)(Point rhs)
        if (op.among!("+", "-", "*"))
    {
        mixin("return Point(x "~op~" rhs.x, y "~op~"rhs.y);");
    }

    /** operator overload for add, subtract or multiply. */

    Point opBinary(string op, T)(T rhs)
        if (op.among!("+", "-", "*") && canConvertToScalar(T))
    {
        mixin("return Point(x "~op~" rhs, y "~op~"rhs);");
    }

    /** operator overload for add, subtract or multiply. */

    Point opBinary(string op, T)(T[2] rhs)
        if (op.among!("+", "-", "*") && canConvertToScalar(T))
    {
        mixin("return Point(x "~op~" rhs[0], y "~op~"rhs[1]);");
    }
}

/** Returns point offset by offset_x,offset_y */

Point offset(Point point, Scalar offset_x, Scalar offset_y)
{
    return Point(point.x+offset_x, point.y+offset_y);
}

/** Returns point scaled by scale_x,scale_y */

Point scale(Point point, Scalar scale_x, Scalar scale_y)
{
    return Point(point.x*scale_x, point.y*scale_y);
}

/** Returns point scaled by scale_x,scale_y but relative to focus_x,focus_y */

Point scale(Point point, Scalar scale_x, Scalar scale_y, Scalar focus_x, Scalar focus_y)
{
    return Point((point.x-focus_x)*scale_x+focus_x, (point.y-focus_y)*scale_y+focus_y);
}

// TODO - versions that take that pass in sin/cos values rather than call math funcs each time
// as they are very slow

/** Returns point rotated by the specified angle. angle is in degrees [0..360] */

Point rotate(Point point, Scalar angle) 
{
    import std.math;

    Scalar sina = cast(Scalar) sin(angle*2*PI/360);
    Scalar cosa = cast(Scalar) cos(angle*2*PI/360);
    return Point(point.x*cosa-point.y*sina, point.x*sina+point.y*cosa);
}

/** Returns point rotated by the specified angle around focus_x,focus_y. Angle
is in degrees [0..360] */

Point rotate(Point point, Scalar angle, Scalar focus_x, Scalar focus_y)
{
    import std.math;

    Scalar sina = cast(Scalar) sin(angle*2*PI/360);
    Scalar cosa = cast(Scalar) cos(angle*2*PI/360);
    return Point(
        (point.x-focus_x)*cosa-(point.y-focus_y)*sina+focus_x,
        (point.x-focus_x)*sina+(point.y-focus_y)*cosa+focus_y
        );
}


