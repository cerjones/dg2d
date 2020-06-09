/**
  This module provides a 2D geometric Path type and some adaptor functions
  that can be used to transform it.

  Copyright: Chris Jones
  License: Boost Software License, Version 1.0
  Authors: Chris Jones

   Pseudo code sortof...

  Build a path...

  path!float path;
  path.moveTo(0,0).lineTo(10,10).quadTo(20,20,20,0).close();

  Use adaptor functions...

  Canvas.draw(path.offset(100,100).retro);
  
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
  commands where each command consists of 1 or more points. Each point
  along the path is tagged with the type of command it belongs to. All
  commands except for move implicitly link together. In linked commands
  the last point of the previous command is used as the first point of
  the following command. This shared point is always tagged for the
  previous command.
  A path must always start with an initial move.
*/

struct Path(T)
    if (isFloatOrDouble!(T))
{
    @disable this(this);

    /** Frees the memory used by the path. */

    ~this()
    {
        import core.stdc.stdlib : free;
        free(m_points);
        free(m_cmds);
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

    /** Get the coordinates of last move */

    Point!T lastMoveTo()
    {
        assert(m_lastMove >= 0);
        return m_points[m_lastMove];
    }

    /** array operator access to points */

    ref Point!T opIndex(size_t idx)
    {
        return m_points[idx];
    }

    /** get a slice of the path points */
    
    auto opSlice(size_t from, size_t to)
    {
        return slice(this, from, to);
    }

    /** Copy rhs to this path */

    void opAssign(P)(auto ref P rhs)
        if (isPathType!(P))
    {
        if (m_length == rhs.length)
        {
            foreach(size_t i; 0..rhs.length)
            {
                m_points[i] = rhs.point(i);
                m_cmds[i] = rhs.cmd(i);
            }
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

        foreach(size_t i; 0..rhs.length)
        {
            m_points[m_length+i] = rhs.point(i);
            m_cmds[m_length+i] = rhs.cmd(i);
        }
        m_length += rhs.length;
    }

    /** The number of points in the path */

    size_t length()
    {
        return m_length;
    }

    /** x,y,cmd, and points */

    T x(size_t idx)
    {
        assert(idx < m_length);
        return m_points[idx].x;
    }

    T y(size_t idx)
    {
        assert(idx < m_length);
        return m_points[idx].y;
    }

    PathCmd cmd(size_t idx)
    {
        assert(idx < m_length);
        return m_cmds[idx];
    }

    Point!T point(size_t idx)
    {
        assert(idx < m_length);
        return m_points[idx];
    }

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
        dg2dRealloc(m_points,newcap);
        dg2dRealloc(m_cmds,newcap);
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
  Checks that T implements the following API...

    FloatType x(size_t) 
    FloatType y(size_t) 
    PathCmd cmd(size_t)
    Point!FloatType point(size_t idx)
    size_t length()

  where FloatType is float or double.
*/ 

template isPathType(T)
{
    alias FloatType = ReturnType!(T.x);

    enum isPathType = (isFloatOrDouble!(FloatType)
        && is(typeof(T.x(size_t.init)) == FloatType)
        && is(typeof(T.y(size_t.init)) == FloatType)
        && is(typeof(T.cmd(size_t.init)) == PathCmd)
        && is(typeof(T.length()) == size_t));   
}

/**
  Returns a slice of path.
*/

// as slice bounds may be shorter than source path we need to
// bounds check on the length of the slice

auto slice(T)(auto ref T path, size_t from, size_t to)
    if (isPathType!(T))
{
    alias PathFloat = ReturnType!(T.x);

    struct SlicePath
    {
    public:
        PathFloat x(size_t idx)
        {
            assert(idx < m_length);
            return m_path.x(m_start+idx);
        }

        PathFloat y(size_t idx)
        {
            assert(idx < m_length);
            return m_path.y(m_start+idx);
        }

        PathFloat cmd(size_t idx)
        {
            assert(idx < m_length);
            return m_path.cmd(m_start+idx);
        }

        Point!PathFloat point(size_t idx)
        {
            assert(idx < m_length);
            return m_path.point(m_start+idx);
        }

        size_t length()
        {
            return m_length;
        }

        // If path is an lvalue we grab a pointer, if it's an rvalue we grab
        // it by value.

        static if (__traits(isRef, path))
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
        else
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
    cmd(idx) - the current segment type / command
    x(idx) - x coordinates of the current segment
    y(idx) - y coordinates of the current segment
    point(idx) - points of the current segment

  When you use x(),y() or points(), idx is for indexing into the current
  segment, so if the current segment is a line, 0 will be the first point,
  1 will be the second. A cubic curve segment can be indexed 0,1,2 or 3.
  It is bounds checked in debug mode.

  When all the segments are exhausted cmd() will return PathCmd.empty
*/

auto segments(T)(auto ref T path)
{
    alias PathFloat = ReturnType!(T.x);

    struct Segments
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

        PathCmd cmd()
        {
            return m_segtype;
        }

        PathFloat x(size_t idx)
        {
            assert(idx < m_segtype.advance);
            return m_path.x(m_pos+idx);
        } 

        PathFloat y(size_t idx)
        {
            assert(idx < m_segtype.advance);
            return m_path.y(m_pos+idx);
        }

        Point!PathFloat point(size_t idx)
        {
            assert(idx < m_segtype.advance);
            return m_path.point(m_pos+idx);
        }

        // If path is an lvalue we grab a pointer, if it's a rvalue we grab
        // it by value.

        static if (__traits(isRef, path))
        {
            this(ref T path)
            {
                m_path = &path;
                reset();
            }

            private T* m_path;
        }
        else
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

    return Segments(path);
}

/**
  Offset the path by x,y.
*/

auto offset(T,F)(auto ref T path, F x, F y)
    if (isPathType!(T))
{
    alias PathFloat = ReturnType!(T.x);

    struct Offseter
    {
    public:
        PathFloat x(size_t idx)
        {
            return m_path.x(idx)+m_x;
        }

        PathFloat y(size_t idx)
        {
            return m_path.y(idx)+m_y;
        }

        PathCmd cmd(size_t idx)
        {
            return m_path.cmd(idx);
        }

        Point!PathFloat point(size_t idx)
        {
            return Point!PathFloat(m_path.x(idx)+m_x,m_path.y(idx)+m_y);
        }

        size_t length()
        {
            return m_path.length;
        }

        // If path is an lvalue we grab a pointer, if it's a rvalue we grab
        // it by value.

        static if (__traits(isRef, path))
        {
            this (ref T path, PathFloat x, PathFloat y)
            {
                m_path = &path;
                m_x = x;
                m_y = y;
            }

            private T* m_path;
        }
        else
        {
            this (T path, PathFloat x, PathFloat y)
            {
                m_path = path;
                m_x = x;
                m_y = y;
            }

            private T m_path;
        }

    private:

        PathFloat m_x;
        PathFloat m_y;
    }
    return Offseter(path, cast(PathFloat) x, cast(PathFloat) y);
}

/**
  Scale the path by sx,sy.
*/

auto scale(T,F)(auto ref T path, F sx, F sy)
    if (isPathType!(T))
{
    alias PathFloat = ReturnType!(T.x);

    struct ScalePath
    {
    public:
        PathFloat x(size_t idx)
        {
            return m_path.x(idx)*m_sx;
        }

        PathFloat y(size_t idx)
        {
            return m_path.y(idx)*m_sy;
        }

        PathCmd cmd(size_t idx)
        {
            return m_path.cmd(idx);
        }

        Point!PathFloat point(size_t idx)
        {
            return Point!PathFloat(m_path.x(idx)*m_sx, m_path.y(idx)*m_sy);
        }

        size_t length()
        {
            return m_path.length;
        }

        // If path is an lvalue we grab a pointer, if it's a rvalue we grab
        // it by value.

        static if (__traits(isRef, path))
        {
            this (ref T path, PathFloat sx, PathFloat sy)
            {
                m_path = &path;
                m_sx = sx;
                m_sy = sy;
            }

            private T* m_path;
        }
        else
        {
            this (T path, PathFloat sx, PathFloat sy)
            {
                m_path = path;
                m_sx = sx;
                m_sy = sy;
            }

            private T m_path;
        }

    private:

        PathFloat m_sx;
        PathFloat m_sy;
    }
    return ScalePath(path, cast(PathFloat) sx, cast(PathFloat) sy);
}

/**
  Access the path in reverse.
*/

auto retro(T)(auto ref T path)
    if (isPathType!(T))
{
    alias PathFloat = ReturnType!(T.x);

    struct RetroPath
    {
    public:
        PathFloat x(size_t idx)
        {
            return m_path.x(m_lastidx-idx);
        }

        PathFloat y(size_t idx)
        {
            return m_path.y(m_lastidx-idx);
        }

        // To reverse the commands we need to offset them by 1 and
        // insert a move at the start.

        PathCmd cmd(size_t idx)
        {
            if (idx == 0)
            {
                assert(path.length > 0);
                return PathCmd.move;
            }
            else
            {
                return m_path.cmd(path.length-idx);
            }
        }

        Point!PathFloat point(size_t idx)
        {
            return m_path.point(m_lastidx-idx);
        }

        size_t length()
        {
            return m_path.length;
        }

        // If path is an lvalue we grab a pointer, if it's a rvalue we grab
        // it by value. Also note that while (path.length-1) will wrap to
        // size_t.max if path.length is 0, it doesnt actually matter since
        // whatever index we calculate will always be invalid anyway.

        static if (__traits(isRef, path))
        {
            this (ref T path)
            {
                m_path = &path;
                m_lastidx = path.length-1;
            }

            private T* m_path;
        }
        else
        {
            this (T path)
            {
                m_path = path;
                m_lastidx = path.length-1;
            }

            private T m_path;
        }

        private size_t m_lastidx;
    }
    return RetroPath(path);
}

// chain, inset, outset, 