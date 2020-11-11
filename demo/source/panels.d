module demo.panels;

import std.stdio;

import window;
import rawgfx;

import dg2d;

import std.random;

Font gfx_font;

static this()
{
    gfx_font = loadFont(rawfont);
}

/* ============================================================================ */

class GFXPanel : Widget
{
    string getInfo() { return ""; }

    this(int x,int y, int w, int h)
    {
        super(x,y,w,h);
    }
}

/* ============================================================================ */

RoundRect randomRoundRect(ref Random rnd)
{   
    float x = uniform(120.0f, 680.0f, rnd);
    float y = uniform(120.0f, 680.0f, rnd);
    float w = uniform(12.0f, 100.0f, rnd);
    float h = uniform(12.0f, 100.0f, rnd);
    float c = uniform(2.0f, ((w<h) ? w : h)/2, rnd);
    return RoundRect(x-w,y-h,x+w,y+h,c,c);
}

/* ============================================================================ */

Path buildTextPath(Font font, const char[] txt)
{
    Path path;
    float[] adv;
    adv.length = txt.length;
    font.getTextSpacing(txt,adv);

    int i;
    int subi = 0;
    float subx = 50, y = 50;
    float pos = subx;

    for (i = 0; i < txt.length; i++)
    {
        if ((txt[i] == ' ') || (txt[i] == '\n'))
        {
            for (int k = subi; k <= i; k++)
            {
                font.addChar(path, subx, y, txt[k]);
                subx += adv[k];
            }
            subi = i+1;
        }

        if ((pos > 750) || (txt[i] == '\n'))
        {
            pos = 50+pos-subx;
            subx = 50;
            y += font.lineHeight();
        }

        if (y > 750) return path;

        pos += adv[i];
    }
    return path;
}

/* ============================================================================ */

class SolidPanel1 : GFXPanel
{
    
	override void onPaint(Canvas canvas)
  	{
        auto rnd = Random(1234); 
        foreach(i; 0..rects.length)
        {
            canvas.draw(
                rects[i].asPath.append(rects[i].inset(8).asPath.retro),
                uniform(0, 0xFFFFFFFF, rnd) | 0xff000000,
                WindingRule.NonZero
                );
        }
    }

    override void onMouse(MouseMsg msg)
    {
    } 

    this()
    {
        super(0,0,800,800);
        auto rnd = Random(42);
        foreach(i; 0..rects.length)
        {
            retry:
                rects[i] = randomRoundRect(rnd);
                auto osr = rects[i].outset(8);
                foreach(q; 0..i)
                    if (!intersect(osr,rects[q]).isEmpty) goto retry; 
        }

    }

    override string getInfo()
    {
        return "Solid color";
    }

    RoundRect[40] rects;
}

/* ============================================================================ */

class SolidPanel2 : GFXPanel
{
    
	override void onPaint(Canvas canvas)
  	{
        auto rnd = Random(1234); 
        canvas.draw(
           path, 0xFFFFFFFF, WindingRule.NonZero
           );
    }

    override void onMouse(MouseMsg msg)
    {
    } 

    this()
    {
        super(0,0,800,800);
        gfx_font.setSize(20);
        path = buildTextPath(gfx_font, loremIpsum);
    }

    override string getInfo()
    {
        return "Solid text";
    }

    Path path;
}

/* ============================================================================ */

class LinearPanel1 : GFXPanel
{
    
	override void onPaint(Canvas canvas)
  	{
        canvas.draw(
            path,
            LinearGradient(p0.x,p0.y,p1.x,p1.y,grad,RepeatMode.Pad),
            WindingRule.NonZero
            );
    }

    override void onMouse(MouseMsg msg)
    {
        if (msg.left == true)
        {
            p0.x = msg.x;
            p0.y = msg.y;
            repaint();
        }

        if (msg.right == true)
        {
            p1.x = msg.x;
            p1.y = msg.y;
            repaint();
        }
    }   

    this()
    {
        super(0,0,800,800);
        auto rnd = Random(588);
        RoundRect[50] rects;

        foreach(i; 0..rects.length)
        {
            retry:
                rects[i] = randomRoundRect(rnd);
                auto osr = rects[i].outset(6);
                foreach(q; 0..i)
                    if (!intersect(osr,rects[q]).isEmpty) goto retry;
                path.append(rects[i].asPath);
        }

        grad = new Gradient(256);       
        grad.initEqualSpaced(0xFFffff00,0xff00ffff,0xFFff00ff,0xFF80ff80);
    }

    override string getInfo()
    {
        return "Linear gradient";
    }

    Point p0 = [300,300];
    Point p1 = [700,700];
    Path path;
    Gradient grad;
}

/* ============================================================================ */

class AngularPanel1 : GFXPanel
{
	override void onPaint(Canvas canvas)
  	{
        canvas.draw(
            path,
            AngularGradient(400,400,p0.x,p0.y,p1.x,p1.y,1,grad,RepeatMode.Repeat),
            WindingRule.EvenOdd
            );
    }

    override void onMouse(MouseMsg msg)
    {
        if (msg.left == true)
        {
            p0.x = msg.x;
            p0.y = msg.y;
            repaint();
        }

        if (msg.right == true)
        {
            p1.x = msg.x;
            p1.y = msg.y;
            repaint();
        }
    }   

    this()
    {
        super(0,0,800,800);
        
        grad = new Gradient(256);       
        grad.initEqualSpaced(0xFFff0000,0xff00ff00,0xFF0000ff,0xffffffff);

        path = Path();

        path.moveTo(-400,0);
        foreach(i; 0..33)
           path.lineTo(Point((i%2) ? 400 : -400, 0).rotate(i*360/66.0))
           .lineTo(Point((i%2) ? -400 : 400, 0).rotate(i*360/66.0));
        path.close();
        path = path.offset(400,400);

       foreach(i; 1..20)
            path.append(Circle(400,400,i*20).asPath);
    }

    override string getInfo()
    {
        return "Angular gradient, even odd, repeat mode = repeat";
    }

    Point p0 = [600,400];
    Point p1 = [400,600];
    Path path;
    Gradient grad;
}

/* ============================================================================ */

class RadialPanel1 : GFXPanel
{
	override void onPaint(Canvas canvas)
  	{
        canvas.draw(
            path,
            BiradialGradient(focus.x,focus.y,50,400,400,mainrad,grad,RepeatMode.Pad),
            WindingRule.EvenOdd
            );
    }

    override void onMouse(MouseMsg msg)
    {
        if (msg.left == true)
        {
            focus.x = msg.x;
            focus.y = msg.y;
            repaint();
        }

        if (msg.right == true)
        {
            import std.math;
            import dg2d.misc;
            mainrad = max(60,sqrt(sqr(msg.x-400.0)+sqr(msg.y-400.0)));
            repaint();
        }
    } 

    this()
    {
        super(0,0,800,800);
        
        grad = new Gradient(1024);       
        grad.initEqualSpaced(0xFFffff00,0xff009766,0xFF7b057f);
        path.append(Rect(0,0,800,800).asPath);
    }

    override string getInfo()
    {
        return "Biradial gradient, repeat mode = Pad";
    }

    Point focus = [300,300];
    float mainrad = 300;
    Path path;
    Gradient grad;
}

/* ============================================================================ */

class RadialPanel2 : GFXPanel
{
	override void onPaint(Canvas canvas)
  	{
        canvas.draw(
            path,
            RadialGradient(400,400,p0.x,p0.y,p1.x,p1.y,grad,RepeatMode.Repeat),
            WindingRule.EvenOdd
            );
    }

    override void onMouse(MouseMsg msg)
    {
        if (msg.left == true)
        {
            p0.x = msg.x;
            p0.y = msg.y;
            repaint();
        }

        if (msg.right == true)
        {
            p1.x = msg.x;
            p1.y = msg.y;
            repaint();
        }
    }   

    this()
    {
        super(0,0,800,800);
        
        grad = new Gradient;
        grad.initEqualSpaced(0xFFfF0000,0xff00FF00,0xFF0000FF,0xFFFF0000);      
        Path tmp;
        tmp.moveTo(0,0).lineTo(300,20).lineTo(370,0).lineTo(300,-20).close();
        Path tmp2;
        tmp2 = Circle(0,0,50).asPath;

        foreach(i; 0..36)
        {
            path.append(tmp.offset(400,400).rotate(400,400,i*10));
            path.append(tmp2.offset(700,400).rotate(400,400,i*10));
        }
    }

    override string getInfo()
    {
        return "Radial gradient, repeat mode = Repeat";
    }

    Point p0 = [400,300];
    Point p1 = [700,300];
    Path path;
    Gradient grad;
}

/* ============================================================================ */

class RadialPanel3 : GFXPanel
{
	override void onPaint(Canvas canvas)
  	{
        canvas.draw(
            path,
            BiradialGradient(focus.x,focus.y,50,400,400,mainrad,grad,RepeatMode.Mirror),
            WindingRule.EvenOdd
            );
    }

    override void onMouse(MouseMsg msg)
    {
        if (msg.left == true)
        {
            focus.x = msg.x;
            focus.y = msg.y;
            repaint();
        }

        if (msg.right == true)
        {
            import std.math;
            import dg2d.misc;
            mainrad = max(60,sqrt(sqr(msg.x-400.0)+sqr(msg.y-400.0)));
            repaint();
        }
    }   

    this()
    {
        super(0,0,800,800);
        
        grad = new Gradient(8);       
        grad.initEqualSpaced(0xFFe9b827,0xff8f1e62,0xFFff0000);
        
        foreach(i; 0..160)
        {
            path.append(Circle(i*3+10,0,i+17).asPath.rotate(i*13).offset(400,400));
        }
    }

    override string getInfo()
    {
        return "Biradial gradient, repeat mode = Mirror";
    }

    Point focus = [300,300];
    float mainrad = 300;
    Path path;
    Gradient grad;
}

