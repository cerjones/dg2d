/*
  Copyright Chris Jones 2020.
  Distributed under the Boost Software License, Version 1.0.
  See accompanying file Licence.txt or copy at...
  https://www.boost.org/LICENSE_1_0.txt
*/

module dg2d.path;

import dg2d.geometry;
import dg2d.misc;

/*
  PathCmd, used to tag each point on the path. The bottom three bits
  encode the number points for the command type. The topmost bit encodes
  whether the segment is "linked". IE does it share a point with the
  previous command. So a line requires 2 points, but because it is
  "linked" it uses the last point of the previous as it's first.
  Ecoding this info in the enum simpifies with iterating along the path.
*/

enum PathCmd : ubyte
{
    empty = 0,        // no path data or error
    move  = 1 | 0,    // start a new sub path
    line  = 2 | 128,  // line 
    quad  = 3 | 128,  // quadratic curve
    cubic = 4 | 128,  // cubic bezier
}

int advance(PathCmd cmd) { return cmd & 7; }
int linked(PathCmd cmd) { return cmd >> 7; }

/*
  Path class, a 2d geometric path composed of lines and curves. Each point of
  a segment is tagged with the type of the segment. However as the end point
  of one segment is also the start point of the following segment it's
  technically part of both. I've chosen to tag the end points as belonging
  to the previous segment. So an initial move folowed by a line followed by
  a quadratic would be...

  move,line,quad,quad

  we could use a bitmask and tag shared end/start points with both, but im
  not sure if it would be of any use.

  A path must always start with a move. A path can be composed of multiple
  subpaths and you start a new subpath by inserting a move. There is no
  requirement for the subpaths to be closed. (End joined back to start)
  I thought about either requiring it or doing it automatically but there
  are two arguments against...
  
  1. If closed paths are a requirement for some reason, i think the check
  should be done by the code that requires it rather than adding the
  overhead for every user of the Path class.
  
  2. Unclosed paths are need for stroking.

  There needs to be a close command, as thats's also important for stroking
  to know whether segment closes or not. If it's closed back to the start of
  the path it changes from two end caps that happen to be in the same place
  to a join.

  I envisage Path as a kind of basic container of path data. And there can
  be iterators or adaptors that mutate it on the fly. Free functions to
  envaluate properties etc. 

*/

struct Path(T)
    if (is(T == float) || is(T == double))
{
    ~this()
    {
        import core.stdc.stdlib : free;
        free(m_points);
        free(m_cmds);
    }

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

    // close subpath, draws a line back to the previous move 

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

    // returns the last moveTo coordinates

    Point!T startOfSubPath()
    {
        assert(m_lastMove >= 0);
        return m_points[m_lastMove];
    }

    size_t length()
    {
        return m_length;
    }

    ref Point!T opIndex(size_t idx)
    {
        return m_points[idx];
    }
    
    auto opSlice(size_t from, size_t to)
    {
        return m_points[from..to];
    }
    
    PathCmd getCmd(size_t idx)
    {
        return m_cmds[idx];
    }

    void reset()
    {
        m_length = 0;
    }

    void translate(T x, T y)
    {
        foreach(ref p; m_points[0..m_length])
        {
            p.x += x;
            p.y += y;
        }
    }

    void scale(T xs, T ys)
    {
        foreach(ref p;m_points[0..m_length])
        {
            p.x *= xs;
            p.y *= ys;
        }
    }
    
    void append(ref Path!T other)
    {
        if (other.length == 0) return;
        makeRoomFor(other.m_length);
        size_t end = m_length + other.length;
        m_points[m_length..end] = other.m_points[0..other.m_length];
        m_cmds[m_length..end] = other.m_cmds[0..other.m_length];
        m_length = end;
    }
    
private:

    alias PointType = Point!T;

    // make sure enough room for "num" extra coords

    void makeRoomFor(size_t num)
    {
        size_t reqlen = m_length+num;
        if (reqlen <= m_capacity) return;
        setCapacity(reqlen);
    }

    // set capacity

    void setCapacity(size_t newcap)
    {
        import core.stdc.stdlib : realloc;

        assert(newcap >= m_length);
        if (newcap > size_t.max/(PointType.sizeof)) assert(0); // too big
        newcap = roundUpPow2(newcap|31);
        if (newcap == 0) assert(0); // overflowed
        m_points = cast(PointType*) realloc(m_points, newcap * PointType.sizeof);
        if (m_points == null) assert(0); 
        m_cmds = cast(PathCmd*) realloc(m_cmds, newcap * PathCmd.sizeof);
        if (m_cmds == null) assert(0); 
        m_capacity = newcap;
    }

    // member vars

    size_t m_length;
    size_t m_capacity;
    PointType* m_points;
    PathCmd* m_cmds;   
    size_t m_lastMove = -1;
}

/*
  PathIterator, iterate along a path one command at a time. 
*/

struct PathIterator(T)
{
    this(ref Path!T path)
    {
        m_path = &path;
        reset();
    }

    void reset()
    {
        m_pos = 0;
        m_segtype = (m_path.m_length > 0) ?  m_path.m_cmds[0] : PathCmd.empty;
        assert(m_segtype == PathCmd.empty || m_segtype == PathCmd.move);    
    }

    void next()
    {
        m_pos += m_segtype.advance;
        m_segtype = (m_pos < m_path.m_length) ? m_path.m_cmds[m_pos] : PathCmd.empty;
        m_pos -= m_segtype.linked;
        assert((m_pos+m_segtype.advance) <= m_path.m_length);    
    }

    PathCmd cmd()
    {
        return m_segtype;
    }

    T x(size_t idx)
    {
        assert(idx < m_segtype.advance);
        return m_path.m_points[m_pos+idx].x;
    } 

    T y(size_t idx)
    {
        assert(idx < m_segtype.advance);
        return m_path.m_points[m_pos+idx].y;
    } 

private:
 
    Path!T* m_path;
    PathCmd m_segtype;
    size_t m_pos;
}

/*
  OffsetPathIterator, offsets the path by x,y
*/

struct OffsetPathIterator(T)
{
    this(ref Path!T path, T x, T y)
    {
        m_path = &path;
        m_x = x;
        m_y = y;
        reset();
    }

    void reset()
    {
        m_pos = 0;
        m_segtype = (m_path.m_length > 0) ?  m_path.m_cmds[0] : PathCmd.empty;
        assert(m_segtype == PathCmd.empty || m_segtype == PathCmd.move);    
    }

    void next()
    {
        m_pos += m_segtype.advance;
        m_segtype = (m_pos < m_path.m_length) ? m_path.m_cmds[m_pos] : PathCmd.empty;
        m_pos -= m_segtype.linked;
        assert((m_pos+m_segtype.advance) <= m_path.m_length);    
    }

    PathCmd cmd()
    {
        return m_segtype;
    }

    T x(size_t idx)
    {
        assert(idx < m_segtype.advance);
        return m_path.m_points[m_pos+idx].x + m_x;
    } 

    T y(size_t idx)
    {
        assert(idx < m_segtype.advance);
        return m_path.m_points[m_pos+idx].y + m_y;
    } 

private:
 
    Path!T* m_path;
    PathCmd m_segtype;
    size_t m_pos;
    T m_x,m_y;
}


