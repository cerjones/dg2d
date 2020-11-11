/**
  This module provides a 2D geometric path type. A Path is a 2D shape defined
  by a sequence of line or curve segments. It can be open or closed, and can
  have multiple sub paths.

  Build a path...

  ---
  Path!float path;
  path.moveTo(0,0);
  path.lineTo(10,10);
  path.quadTo(20,20,30,30);
  path.close();
  ---

  Commands can be chained...

  ---
  path.moveTo(0,0).lineTo(10,10).quadTo(20,20,30,30).close();
  ---

  You can use chained PathIterator adaptor functions...

  ---
  DrawPath(path.offset(100,100).retro);
  ---
  
  To modify path you use assignment, so for example to scale a path you assign a
  scaled version of it to itself, the assign methods will check for self
  assignment and do it in place if possible. 

  ---
  path = path.retro.offset(10,10);
  ---

  Copyright: Chris Jones
  License: Boost Software License, Version 1.0
  Authors: Chris Jones
*/

module dg2d.path;

import dg2d.scalar;
import dg2d.point;
import dg2d.misc;
import dg2d.pathiterator;
import std.traits;

/**
  Defines the commands used to build a path.
*/

enum PathCmd : ubyte
{
    empty = 0,        /// empty path, end of path, or error
    move  = 1,        /// start a new (sub) path
    line  = 2 | 128,  /// line 
    quad  = 3 | 128,  /// quadratic curve
    cubic = 4 | 128,  /// cubic bezier
}

/** Number of points to advance for a given command */

int advance(PathCmd cmd) { return cmd & 7; }

/**
  Is the command linked, IE does it use the end poin of the previous command
  as its first point.
*/

int linked(PathCmd cmd) { return cmd >> 7; }

/**
  A 2D geometric path type.
  
  The path is built from a sequence of path commands like moveTo or lineTo 
  etc. Each new command uses the previous end point as its first point except
  for the moveTo command, that is used to start a new sub path. Each point in
  a command is tagged with a command type. The shared point between two
  commands is always tagged for the previous command.
*/

struct Path
{
    // prevent Path from being passed by value
    
    @disable this(this); 

    /** Frees the memory used by the path. */

    ~this()
    {
        dg2dFree(m_points);
        dg2dFree(m_cmds);
    }

    /** Move to x,y */

    ref Path moveTo(Scalar x, Scalar y)
    {
        makeRoomFor(1);
        m_cmds[m_length] = PathCmd.move;
        m_points[m_length].x = x;
        m_points[m_length].y = y;
        m_lastMove = m_length;
        m_length++;
        return this;
    }

    /** Move to point */

    ref Path moveTo(Point point)
    {
        return moveTo(point.x, point.y);
    }

    /** Line to x,y */

    ref Path lineTo(Scalar x, Scalar y)
    {
        assert(m_lastMove >= 0);
        makeRoomFor(1);
        m_cmds[m_length] = PathCmd.line;
        m_points[m_length].x = x;
        m_points[m_length].y = y;
        m_length++;
        return this;
    }

    /** Line to point */

    ref Path lineTo(Point point)
    {
        return lineTo(point.x, point.y);
    }

    /** Close the current subpath. This draws a line back to the
    previous move command. */ 

    ref Path close()
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

    ref Path quadTo(Scalar x1, Scalar y1, Scalar x2, Scalar y2)
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

    ref Path cubicTo(Scalar x1, Scalar y1, Scalar x2, Scalar y2, Scalar x3, Scalar y3)
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

    Point lastMoveTo()
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
    rhs is a bunch of adaptors on top of the same path */

    void opAssign(P)(auto ref P rhs)
        if (isPathIterator!P)
    {
        // Same path and cant be done in place

        if ((rhs.source == &this) && (!rhs.inPlace))
        {
            Path temp;
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

    /** reset the path */

    void reset()
    {
        m_length = 0;
    }

    /**  append to the path */

    void append(P)(auto ref P rhs)
        if (isPathIterator!(P))
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

    ref Point opIndex(size_t idx)
    {
        return m_points[idx];
    }

    /** get the command at given index */

    PathCmd cmd(size_t idx)
    {
        assert(idx < m_length);
        return m_cmds[idx];
    }

    /** the length of the path in points */

    size_t length()
    {
        return m_length;
    }

    /** Return the path source.
    */

    void* source()
    {
        return &this;
    }

    /** Can be modified in place?
    */

    bool inPlace()
    {
        return true;
    }

private:

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
    Point* m_points;
    PathCmd* m_cmds;   
    size_t m_lastMove = -1;
}

