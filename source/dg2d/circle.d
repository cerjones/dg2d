/**
  2D circle type.

  Copyright: Chris Jones
  License: Boost Software License, Version 1.0
  Authors: Chris Jones
*/

module dg2d.circle;

import dg2d.scalar;
import dg2d.point;
import dg2d.misc;
import dg2d.path;

import std.algorithm: among;

/**
  2D circle
*/

struct Circle
{
    Scalar x0 = 0;
    Scalar y0 = 0;
    Scalar radius = 0;

    this(Scalar x0, Scalar y0, Scalar radius)
    {
        this.x0 = x0;
        this.y0 = y0;
        this.radius = radius;
    }

    auto asPath()
    {
        enum PathCmd[13] cmdlut = [
            PathCmd.move,PathCmd.cubic,PathCmd.cubic,PathCmd.cubic,
            PathCmd.cubic,PathCmd.cubic,PathCmd.cubic,
            PathCmd.cubic,PathCmd.cubic,PathCmd.cubic,
            PathCmd.cubic,PathCmd.cubic,PathCmd.cubic];

        struct CircleAsPath
        {
        public:
            Point opIndex(size_t idx)
            {
                assert(idx < 13);
                switch(idx)
                {
                    case 0: return Point(m_circle.x0,m_circle.y0+m_circle.radius);
                    case 1: return Point(m_circle.x0+m_circle.radius*CBezOutset,m_circle.y0+m_circle.radius);
                    case 2: return Point(m_circle.x0+m_circle.radius,m_circle.y0+m_circle.radius*CBezOutset);
                    case 3: return Point(m_circle.x0+m_circle.radius,m_circle.y0);
                    case 4: return Point(m_circle.x0+m_circle.radius,m_circle.y0-m_circle.radius*CBezOutset);
                    case 5: return Point(m_circle.x0+m_circle.radius*CBezOutset,m_circle.y0-m_circle.radius);
                    case 6: return Point(m_circle.x0,m_circle.y0-m_circle.radius);
                    case 7: return Point(m_circle.x0-m_circle.radius*CBezOutset,m_circle.y0-m_circle.radius);
                    case 8: return Point(m_circle.x0-m_circle.radius,m_circle.y0-m_circle.radius*CBezOutset);
                    case 9: return Point(m_circle.x0-m_circle.radius,m_circle.y0);
                    case 10: return Point(m_circle.x0-m_circle.radius,m_circle.y0+m_circle.radius*CBezOutset);
                    case 11: return Point(m_circle.x0-m_circle.radius*CBezOutset,m_circle.y0+m_circle.radius);
                    case 12: return Point(m_circle.x0,m_circle.y0+m_circle.radius);
                    default: assert(0);
                }
            }
            PathCmd cmd(size_t idx)
            {
                assert(idx < 13);
                return cmdlut[idx];
            }
            size_t length() { return 13; }
            void* source() { return &this; }
            bool inPlace() { return true; }
        private:
            Circle* m_circle;
        }
        return CircleAsPath(&this);
    }

}

