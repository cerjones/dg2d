/**
  This module provides path iterator related stuff.

  Copyright: Chris Jones
  License: Boost Software License, Version 1.0
  Authors: Chris Jones
*/

module dg2d.pathiterator;

import dg2d.scalar;
import dg2d.point;
import dg2d.path;
import dg2d.misc;
import std.traits;

/**
  Returns true if T is a PathIterator. Not exactly an iterator in traditional
  sense, its an array like API but you still use it to iterate over the path.

  T must have the following methods...

    Point opIndex(size_t idx)
    PathCmd cmd(size_t idx)
    size_t length()
    void* source()
    bool inPlace()
*/ 

enum bool isPathIterator(T) = 
    is(typeof(T.opIndex(0)) == Point)
    && is(typeof(T.cmd(0)) == PathCmd)
    && is(typeof(T.length()) == size_t)
    && is(typeof(T.source()) == void*)
    && is(typeof(T.inPlace()) == bool);

/**
  Returns a PathIterator slice of path[from..to].
*/

auto slice(T)(auto ref T path, size_t from, size_t to)
    if (isPathIterator!T)
{
    struct SlicePath
    {
    public:
        ref Point opIndex(size_t idx)
        {
            assert(idx < m_length);
            return m_path.opIndex(m_start+idx);
        }
        Scalar cmd(size_t idx)
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
  Iterate the path one command / segment at a time.
  
  The returned iterator has the following methods...

    reset() - resets the iterator to the start of the path
    next() - advance to the next command
    PathCmd cmd() - the current command
    Point opIndex(idx) - get segment coordinates

  When you use [] / opIndex the index is for indexing into the current
  segment, so if the current command is a line, 0 will be the first point,
  1 will be the end point. A cubic curve command can be indexed 0,1,2 or 3.
  It is bounds checked in debug mode.

  When all the commands are exhausted cmd() will return PathCmd.empty
*/

auto segments(T)(auto ref T path)
{
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
        Point opIndex(size_t idx)
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
            this(Path path)
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

auto offset(T)(auto ref T path, Scalar x, Scalar y)
    if (isPathIterator!T)
{
    struct OffsetPath
    {
    public:
        Point opIndex(size_t idx)
        {
            return Point(m_path.opIndex(idx).x+m_x,m_path.opIndex(idx).y+m_y);
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
        Scalar m_x;
        Scalar m_y;
    }
    static if (__traits(isRef, path))
        return OffsetPath(&path, x, y);
    else
        return OffsetPath(path, x, y);
}

/**
  Scale the path by sx,sy
*/

auto scale(T,F)(auto ref T path, F sx, F sy)
    if (isPathIterator!T)
{
    alias FloatType = typeof(T[0].x);

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
  Scale the path by sx,sy relative to focus_x,focus_y
*/

auto scale(T,F)(auto ref T path, F sx, F sy, F focus_x, F focus_y)
    if (isPathIterator!T)
{
    alias FloatType = typeof(T[0].x);

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
            cast(FloatType) focus_x, cast(FloatType) focus_y);
    else
        return ScalePath(path, cast(FloatType) sx, cast(FloatType) sy,
            cast(FloatType) focus_x, cast(FloatType) focus_y);
}

/**
  The path in reverse.
*/

auto retro(T)(auto ref T path)
    if (isPathIterator!T)
{
    struct RetroPath
    {
    public:
        Point opIndex(size_t idx)
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
        bool inPlace() { return false; } // cant be done in place
    private:
        static if (__traits(isRef, path))
            T* m_path;
        else
            T m_path; 
        size_t m_lastidx;
    }
    // (path.length-1) will wrap arround when path.length = 0 but 
    // theres no need to check for it because if length is zero
    // then all possible indexes are invalid anyway 
    static if (__traits(isRef, path))
        return RetroPath(&path, path.length-1);
    else
        return RetroPath(path, path.length-1);
}

/**
  Rotate the path around (0,0)
*/

auto rotate(T)(auto ref T path, Scalar angle)
    if (isPathIterator!T)
{
    struct RotatePath
    {
    public:
        Point opIndex(size_t idx)
        {
            Scalar tx = m_path.opIndex(idx).x;
            Scalar ty = m_path.opIndex(idx).y;
            return Point(tx*m_cos-ty*m_sin,  tx*m_sin+ty*m_cos);
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
        Scalar m_sin,m_cos;
    }

    import std.math;

    static if (__traits(isRef, path))
        return RotatePath(&path, sin(angle*2*PI/360), cos(angle*2*PI/360));
    else
        return RotatePath(path, sin(angle*2*PI/360), cos(angle*2*PI/360));
}

/**
  Rotate path around (x,y)
*/

auto rotate(T)(auto ref T path, Scalar pivot_x, Scalar pivot_y, Scalar angle)
    if (isPathIterator!T)
{
    struct RotatePath
    {
    public:
        Point opIndex(size_t idx)
        {
            Scalar tx = m_path.opIndex(idx).x - m_px;
            Scalar ty = m_path.opIndex(idx).y - m_py;
            return Point(tx*m_cos-ty*m_sin+m_px,  tx*m_sin+ty*m_cos+m_py);
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
        Scalar m_px,m_py,m_sin,m_cos;
    }
    import std.math;
    static if (__traits(isRef, path))
        return RotatePath(&path, pivot_x, pivot_y, sin(angle*2*PI/360), cos(angle*2*PI/360));
    else
        return RotatePath(path, pivot_x, pivot_y, sin(angle*2*PI/360), cos(angle*2*PI/360));
}

/**
  Calculate center of path.
  
  This calculates the boudning box and returns the center of that.
*/

auto centerOf(T)(T path)
    if (isPathIterator!T)
{
    return path.boundingBox.center;
}

/**
  Calculate the bounding box of path.
*/

auto boundingBox(T)(T path)
    if (isPathIterator!T)
{
    alias FloatType = typeof(T.opIndex(0).x);
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

/**
  Append two paths
*/

auto append(T,P)(auto ref T path0, auto ref P path1)
    if (isPathIterator!T && isPathIterator!P)
{
    struct AppendPaths
    {
    public:
        Point opIndex(size_t idx)
        {
            if (idx < m_path0.length) return m_path0[idx];
            return m_path1[idx-m_path0.length];
        }
        PathCmd cmd(size_t idx)
        {
            if (idx < m_path0.length) return m_path0.cmd(idx);
            return m_path1.cmd(idx-m_path0.length);
        }
        size_t length() { return m_path0.length+m_path1.length; }
        void* source() { return null; }
        bool inPlace() { return false; }
    private:
        static if (__traits(isRef, path0))
            T* m_path0;
        else
            T m_path0; 
        static if (__traits(isRef, path1))
            P* m_path1;
        else
            P m_path1; 
    }

    // probably a better way to do this??

    static if (__traits(isRef, path0))
        static if (__traits(isRef, path1))
            return AppendPaths(&path0, &path1);
        else
            return AppendPaths(&path0, path1);
    else
        static if (__traits(isRef, path1))
            return AppendPaths(path0, &path1);
        else
            return AppendPaths(path0, path1);
}


