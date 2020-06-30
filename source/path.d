/**
  This module provides a 2D geometric Path type and some adaptor functions
  that can be used to transform it.

  Copyright: Chris Jones
  License: Boost Software License, Version 1.0
  Authors: Chris Jones

  Build a path...

  Path!float path;
  path.moveTo(0,0).lineTo(10,10).quadTo(20,20,30,30).close();

  Use adaptor functions...

  Canvas.draw(path.offset(100,100).retro);
  
  Modify path

  path = path.scale(2,2);
  path = path.retro.offset(10,10);

  Assigning to a path will handle self assignment, and will try to do it in
  place if it can, otherwise it will use a temporary buffer if needed.
*/

module dg2d.path;

import dg2d.geometry;
import dg2d.misc;
import std.traits;

/**
  This enum defines the commands that can be used to build a path.
*/

enum PathCmd : ubyte
{
    empty = 0,        /// empty path or error
    move  = 1,        /// start a new (sub) path
    line  = 2 | 128,  /// line 
    quad  = 3 | 128,  /// quadratic curve
    cubic = 4 | 128,  /// cubic bezier
}

/*
  The number of points and whether a command is linked or not is encoded in
  the enum value. This helps when iterating the path.
*/

private int advance(PathCmd cmd) { return cmd & 7; }

private int linked(PathCmd cmd) { return cmd >> 7; }

/**
  A 2D geometric path type. The path is built from a sequence of path
  commands like moveTo or lineTo etc. All commands except for moveTo
  use the end point of the previous command as their first point. Each
  point except the first point is tagged with the command type. So the
  shared point between two commands is always tagged for the previous
  command. The path can be made up of sub paths. To start a new sub
  path use a moveTo.
*/

struct Path(T)
    if (isFloatOrDouble!(T))
{
    @disable this(this);

    /** Frees the memory used by the path. */

    ~this()
    {
        dg2dFree(m_points);
        dg2dFree(m_cmds);
    }

    /** Move to x,y */

    ref Path!T moveTo(T x, T y)
    {
        makeRoomFor(1);
        m_cmds[m_length] = PathCmd.move;
        m_points[m_length].x = x;
        m_points[m_length].y = y;
        m_lastMove = m_length;
        m_length++;
        return this;
    }

    /** Add a line */

    ref Path!T lineTo(T x, T y)
    {
        assert(m_lastMove >= 0);
        makeRoomFor(1);
        m_cmds[m_length] = PathCmd.line;
        m_points[m_length].x = x;
        m_points[m_length].y = y;
        m_length++;
        return this;
    }

    /** Close the current subpath. This draws a line back to the
    last move command. */ 

    ref Path!T close()
    {
        assert(m_lastMove >= 0);
        makeRoomFor(1);
        m_cmds[m_length] = PathCmd.line;
        m_points[m_length].x = m_points[m_lastMove].x;
        m_points[m_length].y = m_points[m_lastMove].y;
        m_length++;
        return this;
    }

    /** Add a quadratic curve */

    ref Path!T quadTo(float x1, float y1, float x2, float y2)
    {
        assert(m_lastMove >= 0);
        makeRoomFor(2);
        m_cmds[m_length] = PathCmd.quad;
        m_points[m_length].x = x1;
        m_points[m_length].y = y1;
        m_cmds[m_length+1] = PathCmd.quad;
        m_points[m_length+1].x = x2;
        m_points[m_length+1].y = y2;
        m_length += 2;
        return this;
    }

    /** Add a cubic curve */

    ref Path!T cubicTo(float x1, float y1, float x2, float y2, float x3, float y3)
    {
        assert(m_lastMove >= 0);
        makeRoomFor(3);
        m_cmds[m_length] = PathCmd.cubic;
        m_points[m_length].x = x1;
        m_points[m_length].y = y1;
        m_cmds[m_length+1] = PathCmd.cubic;
        m_points[m_length+1].x = x2;
        m_points[m_length+1].y = y2;
        m_cmds[m_length+2] = PathCmd.cubic;
        m_points[m_length+2].x = x3;
        m_points[m_length+2].y = y3;
        m_length += 3;
        return this;
    }

    /** Get the coordinates of last move, IE. the start of current sub path */

    Point!T lastMoveTo()
    {
        assert(m_lastMove >= 0);
        return m_points[m_lastMove];
    }

    /** get a slice of the path, need to be careful as this doesnt
    do anything regarding aligning on full commands. */
    
    auto opSlice(size_t from, size_t to)
    {
        return slice(this, from, to);
    }

    /** Copy rhs to this path, this handles self assignment, even if the
    rhs is a bunch of adaptors ontop of the same path */

    void opAssign(P)(auto ref P rhs)
        if (isPathType!(P))
    {
        // Special handling if we are assiging to ourself

        if ((rhs.source == &this) && (!rhs.inPlace))
        {
            Path!T temp;
            temp.append(rhs);
            swap(m_points, temp.m_points);
            swap(m_cmds, temp.m_cmds);
            m_length = temp.m_length;
            m_capacity = temp.m_capacity;
            m_lastMove = temp.m_lastMove;
        }
        else
        {
            // either not self assignment, or doesnt need special handling

            setCapacity(rhs.length);

            foreach(size_t i; 0..rhs.length)
            {
                m_points[i] = rhs[i];
                m_cmds[i] = rhs.cmd(i);
                if (m_cmds[i] == PathCmd.move) m_lastMove = i;
            }

            m_length = rhs.length;
        }
    }

    /** clear the path */

    void clear()
    {
        m_length = 0;
    }

    /**  append to the path */

    void append(P)(auto ref P rhs)
        if (isPathType!(P))
    {
        if (rhs.length == 0) return;
        makeRoomFor(rhs.length);

        foreach(i; 0..rhs.length)
        {
            m_points[m_length+i] = rhs[i];
            m_cmds[m_length+i] = rhs.cmd(i);
            if (m_cmds[i] == PathCmd.move) m_lastMove = i;
        }
        m_length += rhs.length;
    }

    /** get the point at given index */

    ref Point!T opIndex(size_t idx)
    {
        return m_points[idx];
    }

    /** get the command at given index */

    PathCmd cmd(size_t idx)
    {
        assert(idx < m_length);
        return m_cmds[idx];
    }

    size_t length()
    {
        return m_length;
    }

    void* source() { return &this; }
    bool inPlace() { return true; }

private:

    alias PointType = Point!T;

    // make sure theres enough room for "num" extra coords

    void makeRoomFor(size_t num)
    {
        size_t reqlen = m_length+num;
        if (reqlen <= m_capacity) return;
        setCapacity(reqlen);
    }

    // set capacity

    void setCapacity(size_t newcap)
    {
        assert(newcap >= m_length);
        newcap = roundUpPow2(newcap|31);
        if (newcap == 0) assert(0); // overflowed
        m_points = dg2dRealloc(m_points,newcap);
        m_cmds = dg2dRealloc(m_cmds,newcap);
        m_capacity = newcap;
    }

    // member vars

    size_t m_length;
    size_t m_capacity;
    PointType* m_points;
    PathCmd* m_cmds;   
    size_t m_lastMove = -1;
}

/**
  Returns true if P is a path type. It must have the following methods...

    Point!FloatType opIndex(size_t idx)
    PathCmd cmd(size_t idx)
    size_t length()
    void* source()
    bool inPlace()

  FloatType can be float or double.

  opIndex, length amd cmd, should be self explanatory.

  The last two methods are used by Path.opAssign to check for self
  assignment and if so is it safe to do it in place.
*/ 

template isPathType(T)
{
    alias FloatType = typeof(T.opIndex(size_t.init).x);

    enum isPathType = (isFloatOrDouble!(FloatType)
        && is(typeof(T.opIndex(size_t.init)) == Point!FloatType)
        && is(typeof(T.cmd(size_t.init)) == PathCmd)
        && is(typeof(T.length()) == size_t)
        && is(typeof(T.source()) == void*)
        && is(typeof(T.inPlace()) == bool));
}

/**
  Slice the path.
*/

auto slice(T)(auto ref T path, size_t from, size_t to)
    if (isPathType!(T))
{
    alias FloatType = typeof(T[size_t.init].x);

    struct SlicePath
    {
    public:
        ref Point!FloatType opIndex(size_t idx)
        {
            assert(idx < m_length);
            return m_path.opIndex(m_start+idx);
        }

        FloatType cmd(size_t idx)
        {
            assert(idx < m_length);
            return m_path.cmd(m_start+idx);
        }

        size_t length()
        {
            return m_length;
        }

        static if (__traits(isRef, path)) // grab path by pointer
        {
            this (ref T path, size_t from, size_t to)
            {
                assert(from <= to && to <= path.length);
                m_path = &path;
                m_start = from;
                m_length = to-from;
            }

            private T* m_path;
        }
        else // grab path by value
        {
            this (T path, size_t from, size_t to)
            {
                assert(from <= to && to <= path.length);
                m_path = path;
                m_start = from;
                m_length = to-from;
            }

            private T m_path;
        }

    private:

        size_t m_start;
        size_t m_length;
    }

    return SlicePath(path, from, to);
}

/**
  Iterate along the path segment by segment. The returned iterator has the
  following methods...

    reset() - resets the iterator to the start of the path
    next() - advance to the next command
    PathCmd cmd() - the current command
    Point!FloatType opIndex(idx) - get segment coordinates

  When you use [] / opIndex the idx is for indexing into the current
  segment, so if the current command is a line, 0 will be the first point,
  1 will be the second. A cubic curve command can be indexed 0,1,2 or 3.
  It is bounds checked in debug mode.

  When all the commands are exhausted cmd() will return PathCmd.empty
*/

auto segments(T)(auto ref T path)
{
    alias FloatType = typeof(T[size_t.init].x);

    struct SegmentsPath
    {
        void reset()
        {
            m_pos = 0;
            m_segtype = (m_path.length > 0) ?  m_path.cmd(0) : PathCmd.empty;
            assert(m_segtype == PathCmd.empty || m_segtype == PathCmd.move);    
        }

        void next()
        {
            m_pos += m_segtype.advance;
            m_segtype = (m_pos < m_path.length) ? m_path.cmd(m_pos) : PathCmd.empty;
            m_pos -= m_segtype.linked;
            assert((m_pos+m_segtype.advance) <= m_path.length);    
        }

        Point!FloatType opIndex(size_t idx)
        {
            assert(idx < m_segtype.advance);
            return m_path.opIndex(m_pos+idx);
        }

        PathCmd cmd()
        {
            return m_segtype;
        }

        static if (__traits(isRef, path)) // grab path by pointer
        {
            this(ref T path)
            {
                m_path = &path;
                reset();
            }

            private T* m_path;
        }
        else // grab path by value
        {
            this(Path!T path)
            {
                m_path = path;
                reset();
            }

            private T m_path;
        }

    private:

        PathCmd m_segtype;
        size_t m_pos;
    }

    return SegmentsPath(path);
}

/**
  Offset the path by x,y.
*/

auto offset(T,F)(auto ref T path, F x, F y)
    if (isPathType!(T))
{
    alias FloatType = typeof(T[size_t.init].x);

    struct OffsetPath
    {
    public:
        Point!FloatType opIndex(size_t idx)
        {
            return Point!FloatType(m_path.opIndex(idx).x+m_x,m_path.opIndex(idx).y+m_y);
        }

        PathCmd cmd(size_t idx)
        {
            return m_path.cmd(idx);
        }

        size_t length() { return m_path.length; }
        void* source() { return m_path.source; }
        bool inPlace() { return m_path.inPlace; }

    private:

        static if (__traits(isRef, path))
            private T* m_path;
        else
            private T m_path;

        FloatType m_x;
        FloatType m_y;
    }

    static if (__traits(isRef, path))
        return OffsetPath(&path, cast(FloatType) x, cast(FloatType) y);
    else
        return OffsetPath(path, cast(FloatType) x, cast(FloatType) y);
}

/**
  Scale the path by sx,sy
*/

auto scale(T,F)(auto ref T path, F sx, F sy)
    if (isPathType!(T))
{
    alias FloatType = typeof(T[size_t.init].x);

    struct ScalePath
    {
    public:

        Point!FloatType opIndex(size_t idx)
        {
            return Point!FloatType(m_path.opIndex(idx).x*m_sx,m_path.opIndex(idx).y*m_sy);
        }

        PathCmd cmd(size_t idx)
        {
            return m_path.cmd(idx);
        }

        size_t length() { return m_path.length; }
        void* source() { return m_path.source; }
        bool inPlace() { return m_path.inPlace; }

    private:

        static if (__traits(isRef, path))
            T* m_path;
        else
            T m_path;

        FloatType m_sx;
        FloatType m_sy;
    }

    static if (__traits(isRef, path))
        return ScalePath(&path, cast(FloatType) sx, cast(FloatType) sy);
    else
        return ScalePath(path, cast(FloatType) sx, cast(FloatType) sy);
}

/**
  Scale the path by sx,sy relative to (center_x,center_y)
*/

auto scale(T,F)(auto ref T path, F sx, F sy, F center_x, F center_y)
    if (isPathType!(T))
{
    alias FloatType = typeof(T[size_t.init].x);

    struct ScalePath
    {
    public:

        Point!FloatType opIndex(size_t idx)
        {
            return Point!FloatType(
                (m_path.opIndex(idx).x-m_ctrx)*m_sx+m_ctrx,
                (m_path.opIndex(idx).y-m_ctry)*m_sy+m_ctrx
                );
        }

        PathCmd cmd(size_t idx)
        {
            return m_path.cmd(idx);
        }

        size_t length() { return m_path.length; }
        void* source() { return m_path.source; }
        bool inPlace() { return m_path.inPlace; }

    private:

        static if (__traits(isRef, path))
            T* m_path;
        else
            T m_path;

        FloatType m_sx,m_sy,m_ctrx,m_ctry;
    }

    static if (__traits(isRef, path))
        return ScalePath(&path, cast(FloatType) sx, cast(FloatType) sy,
            cast(FloatType) center_x, cast(FloatType) center_y);
    else
        return ScalePath(path, cast(FloatType) sx, cast(FloatType) sy,
            cast(FloatType) center_x, cast(FloatType) center_y);
}

/**
  The path in reverse.
*/

auto retro(T)(auto ref T path)
    if (isPathType!(T))
{
    alias FloatType = typeof(T[0].x);

    struct RetroPath
    {
    public:
        Point!FloatType opIndex(size_t idx)
        {
            return m_path.opIndex(m_lastidx-idx);
        }

        PathCmd cmd(size_t idx)
        {
            if (idx == 0)
            {
                return PathCmd.move;
            }
            else
            {
                return m_path.cmd(path.length-idx);
            }
        }

        size_t length() { return m_path.length; }
        void* source() { return m_path.source; }
        bool inPlace() { return false; } // cand be done in place

    private:

        static if (__traits(isRef, path))
            T* m_path;
        else
            T m_path; 

        size_t m_lastidx;
    }

    // (path.length-1) will wrap arround when path.length = 0, but 
    // theres no need to check for it because any index you calculate
    // will be invalid and cause an assert in the root path anyway.

    static if (__traits(isRef, path))
        return RetroPath(&path, path.length-1);
    else
        return RetroPath(path, path.length-1);
}

/**
  Rotate the path around (0,0)
*/

auto rotate(T,F)(auto ref T path, F angle)
    if (isPathType!(T))
{
    alias FloatType = typeof(T[0].x);

    struct RotatePath
    {
    public:
        Point!FloatType opIndex(size_t idx)
        {
            FloatType tx = m_path.opIndex(idx).x;
            FloatType ty = m_path.opIndex(idx).y;
            return Point!FloatType(tx*m_cos-ty*m_sin,  tx*m_sin+ty*m_cos);
        }

        PathCmd cmd(size_t idx)
        {
            return m_path.cmd(idx);
        }

        size_t length() { return m_path.length; }
        void* source() { return m_path.source; }
        bool inPlace() { return false; } // cand be done in place

    private:

        static if (__traits(isRef, path))
            T* m_path;
        else
            T m_path; 

        FloatType m_sin,m_cos;
    }

    import std.math;

    static if (__traits(isRef, path))
        return RotatePath(&path, cast(FloatType) sin(angle*2*PI/360), cos(angle*2*PI/360));
    else
        return RotatePath(path, cast(FloatType) sin(angle*2*PI/360), cos(angle*2*PI/360));
}

/**
  Rotate the path around (x,y)
*/

auto rotate(T,F)(auto ref T path, F pivot_x, F pivot_y, F angle)
    if (isPathType!(T))
{
    alias FloatType = typeof(T[0].x);

    struct RotatePath
    {
    public:
        Point!FloatType opIndex(size_t idx)
        {
            FloatType tx = m_path.opIndex(idx).x - m_px;
            FloatType ty = m_path.opIndex(idx).y - m_py;
            return Point!FloatType(tx*m_cos-ty*m_sin+m_px,  tx*m_sin+ty*m_cos+m_py);
        }

        PathCmd cmd(size_t idx)
        {
            return m_path.cmd(idx);
        }

        size_t length() { return m_path.length; }
        void* source() { return m_path.source; }
        bool inPlace() { return false; } // cand be done in place

    private:

        static if (__traits(isRef, path))
            T* m_path;
        else
            T m_path; 

        FloatType m_px,m_py,m_sin,m_cos;
    }

    import std.math;

    static if (__traits(isRef, path))
        return RotatePath(&path, cast(FloatType) pivot_x, cast(FloatType) pivot_y,
            cast(FloatType) sin(angle*2*PI/360), cos(angle*2*PI/360));
    else
        return RotatePath(path, cast(FloatType) pivot_x, cast(FloatType) pivot_y,
            cast(FloatType) sin(angle*2*PI/360), cos(angle*2*PI/360));
}

/**
  Calculate center of path. This calculates the boudning box and returns
  the center of that.
*/

auto centerOf(T)(T path)
    if (isPathType(T))
{
    return path.boundingBox.center;
}

/**
  Calculate the bounding box of path.
*/

auto boundingBox(T)(T path)
    if (isPathType(T))
{
    alias FloatType = typeof(T.opIndex(size_t.init).x);
    Rect!FloatType bounds;

    foreach(i; 0..path.length)
    {
        bounds.xMin = min(bounds.xMin,path[i].x);
        bounds.xMax = max(bounds.xMax,path[i].x);
        bounds.yMin = min(bounds.yMin,path[i].y);
        bounds.yMax = max(bounds.yMax,path[i].y);
    }
    return bounds;
}
