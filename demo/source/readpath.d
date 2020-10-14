/*
  Copyright Chris Jones 2020.
  Distributed under the Boost Software License, Version 1.0.
  See accompanying file Licence.txt or copy at...
  https://www.boost.org/LICENSE_1_0.txt
*/

module readpath;

import std.math : pow;

/*
  read path data, handles just the d="...." data from an svg file. I manualy
  copy that path data out into a seperate file and thats what this handles. 
  Saves having to mess about with the svg dom.
  
  path data is passed in "txt"
  appends path data to "path"
  T must implement moveTo, lineTo, quadTo, cubicTo and close
  returns remaing text 
*/

string readPathData(T)(string txt, ref T path)
{
    Scanner s;
    s.init(txt);
    double x,lx,y,ly = 0;
    bool first = true;
    char op = 0;

    if (s.skipws.popFront != 'd') throw new Exception("Bad path data");
    if (s.skipws.popFront != '=') throw new Exception("Bad path data");
    if (s.skipws.popFront != '\"') throw new Exception("Bad path data");

    while(!s.isEmpty)
    {
        s.skipws();

        switch(s.front())
        {
            case 'm','M','l','L','v','V','h','H','Q','q','C','c','z','Z','\"':
                op = s.popFront();
                break;
            default:
        }
        
        switch(op)
        {
            case 'm':
                x += s.skipws.readDouble();
                y += s.skipws.skip(',').skipws.readDouble();
                path.moveTo(x,y);
                if (first) { lx = x; ly = y; first = false; }
                op = 'l';
                break;
            case 'M':
                x = s.skipws.readDouble();
                y = s.skipws.skip(',').skipws.readDouble();
                path.moveTo(x,y);
                if (first) { lx = x; ly = y; first = false; }
                op = 'L';
                break;
            case 'l':
                x += s.skipws.readDouble();
                y += s.skipws.skip(',').skipws.readDouble();
                path.lineTo(x,y);
                if (first) { lx = x; ly = y; first = false; }
                break;
            case 'L':
                x = s.skipws.readDouble();
                y = s.skipws.skip(',').skipws.readDouble();
                path.lineTo(x,y);
                if (first) { lx = x; ly = y; first = false; }
                break;
            case 'h':
                x += s.skipws.readDouble();
                path.lineTo(x,y);
                if (first) { lx = x; ly = y; first = false; }
                break;
            case 'H':
                x = s.skipws.readDouble();
                path.lineTo(x,y);
                if (first) { lx = x; ly = y; first = false; }
                break;
            case 'v':
                y += s.skipws.readDouble();
                path.lineTo(x,y);
                if (first) { lx = x; ly = y; first = false; }
                break;
            case 'V':
                y = s.skipws.readDouble();
                path.lineTo(x,y);
                if (first) { lx = x; ly = y; first = false; }
                break;
            case 'q':
                float ax = x + s.skipws.readDouble();
                float ay = y + s.skipws.skip(',').skipws.readDouble();
                x = ax + s.skipws.skip(',').skipws.readDouble();
                y = ay + s.skipws.skip(',').skipws.readDouble();
                path.quadTo(ax,ay,x,y);
                if (first) { lx = x; ly = y; first = false; }
                break;
            case 'Q':
                float ax = s.skipws.readDouble();
                float ay = s.skipws.skip(',').skipws.readDouble();
                x = s.skipws.skip(',').skipws.readDouble();
                y = s.skipws.skip(',').skipws.readDouble();
                path.quadTo(ax,ay,x,y);
                if (first) { lx = x; ly = y; first = false; }
                break;
            case 'c':
                float ax = x + s.skipws.readDouble();
                float ay = x + s.skipws.skip(',').skipws.readDouble();
                float bx = ax + s.skipws.readDouble();
                float by = ay + s.skipws.skip(',').skipws.readDouble();
                x = bx + s.skipws.skip(',').skipws.readDouble();
                y = by + s.skipws.skip(',').skipws.readDouble();
                path.cubicTo(ax,ay,bx,by,x,y);
                if (first) { lx = x; ly = y; first = false; }
                break;
            case 'C':
                float ax = s.skipws.readDouble();
                float ay = s.skipws.skip(',').skipws.readDouble();
                float bx = s.skipws.readDouble();
                float by = s.skipws.skip(',').skipws.readDouble();
                x = s.skipws.skip(',').skipws.readDouble();
                y = s.skipws.skip(',').skipws.readDouble();
                path.cubicTo(ax,ay,bx,by,x,y);
                if (first) { lx = x; ly = y; first = false; }
                break;
            case 'z','Z':
                path.close();
                x = lx;
                y = ly;
                first = true;
                break;
            case '\"':
                return s.text(); // return whats left
            default:
                throw new Exception("Bad path data:");
        }
    }
    throw new Exception("Bad path data:");
}

/* 
  little helper class for scanning text
*/

struct Scanner
{
    immutable(char)* ptr,end;

    void init(string text)
    {
        ptr = text.ptr;
        end = ptr+text.length;
    }

    string text()
    {
        return ptr[0..end-ptr];
    }

    bool isEmpty()
    {
        return (ptr >= end);
    }

    // returns null if no more chars 

    char popFront()
    {
        if (ptr < end) return *ptr++;
        return 0;
    }

    // returns null if no more chars 

    char front()
    {
        if (ptr < end) return *ptr;
        return 0;
    }

    bool isNumber()
    {
        return ((ptr < end) && (*ptr >= '0') && (*ptr <= '9'));
    }

    bool isAlpha()
    {
        return ((ptr < end) && (((*ptr | 32) >= 'a') && ((*ptr | 32) <= 'z')));
    }

    // skip multiple whitespace 

    ref Scanner skipws()
    {
        while ((ptr < end) && 
            ((*ptr == ' ') || (*ptr == '\t') || (*ptr == '\n') || (*ptr == '\r'))
            ) ptr++;
        return this;
    }

    // skip single char 

    ref Scanner skip(char c)
    {
        if ((ptr < end) && (*ptr == c)) ptr++;
        return this;
    }

    // skip single char from list in 'what' 

    ref Scanner skip(string what)()
    {
        static foreach(c; what)
        {
            if (*ptr == c) { ptr++; return this; }
        }
        return this;
    }

    double readDouble()
    {
        if (isEmpty) throw new Exception("Error reading double.");

        bool negative = (*ptr == '-');
        if ((*ptr == '-') || (*ptr == '+')) ptr++;

        if (!isNumber) throw new Exception("Error reading double.");

        double num = *ptr - '0';
        ptr++;

        while (isNumber)
        {
            num = num*10 + (*ptr) - '0';
            ptr++;
        }

        double fracdigits = 0;

        if ((ptr < end) && (*ptr == '.'))
        {
            ptr++;
            if (!isNumber) throw new Exception("Error reading double.");

            while (isNumber)
            {
                num = num*10 + (*ptr)-'0';
                fracdigits += 1;
                ptr++;
            }
        }

        if ((ptr < end) && ((*ptr == 'E') || (*ptr == 'e')))
        {
            ptr++;
            if (isEmpty) throw new Exception("Error reading double.");
            bool xpneg = (*ptr == '-');
            if ((*ptr == '-') || (*ptr == '+')) ptr++;

            if (!isNumber) throw new Exception("Error reading double.");
            double xp = (*ptr) - '0';
            ptr++;

            while (isNumber)
            {
                xp = xp*10 + (*ptr) - '0';
                ptr++;
            }

            fracdigits = (xpneg) ? fracdigits+xp : fracdigits-xp;
        }
       
        return ((negative) ? -num : num) * pow(10.0, -fracdigits);
    }
}

