/*
  Copyright Chris Jones 2020.
  Distributed under the Boost Software License, Version 1.0.
  See accompanying file Licence.txt or copy at...
  https://www.boost.org/LICENSE_1_0.txt
*/

module app;

import std.stdio;
import window;
import dg2d.canvas;
import dg2d.font;

import dg2d;
import dg2d.misc;

import demo.panels;

void main()
{   
    auto wnd = new Window();
    wnd.addClient(new MainPanel());
    wnd.createWindow(200,200,800,800,"graphics test");
	WindowsMessageLoop();
}

class MainPanel : Widget
{
    this()
    {
        super(0,0,800,800);

        import rawgfx;
        font = loadFont(rawfont);
        font.setSize(15);

        testcvs = new Canvas(800,800);

        panels ~= new SolidPanel1();
        panels ~= new SolidPanel2();
              
        panels ~= new LinearPanel1();

        panels ~= new AngularPanel1();

        panels ~= new RadialPanel1();
        panels ~= new RadialPanel2();
        panels ~= new RadialPanel3();
        addChild(panels[0]);

        infobtn = new Button(32,10,600,40,"",font);
        infobtn.setOnClick(&clicked);
        addChild(infobtn);
    }

    override void onPaint(Canvas canvas)
    {
        canvas.fill(0xFF000000);
    }
    
    override void onTimer()
    {   
        long t = profilePanel(panels[gfxidx],5);
        timings[0..$-1] = timings[1..$];
        timings[$-1] = getPerformanceFrequency() / (1.0*t);

        fps = 0;
        foreach(f; timings) fps = max(fps,f);

        import std.conv;
        infobtn.setText(panels[gfxidx].getInfo ~ ", FPS = " ~ to!string(fps));
        repaint();
    }

    void clicked()
    {   
        removeChild(panels[gfxidx]);
        gfxidx = (gfxidx+1) % panels.length;
        addChild(panels[gfxidx]);
        addChild(infobtn);
        timings = 0;
        repaint();
    }

    long profilePanel(GFXPanel panel, int runs = 1)
    {
        testcvs.fill(0xFF000000);
        panel.onPaint(testcvs);
        long best = long.max;
        foreach(i; 0..runs)
        {
            testcvs.fill(0xFF000000);
            long t = getPerformanceCounter();
            panel.onPaint(testcvs);
            t = getPerformanceCounter()-t;
            best = min(best,t);
        }
        return best;
    }

    size_t gfxidx = 0;
    Font   font;
    Button infobtn;
    GFXPanel[] panels;
    Canvas testcvs;
    float fps = 0;
    float[25] timings = 0;
}

/*
  Windows performance timer stuff
*/

long getPerformanceCounter()
{
    import core.sys.windows.windows;
    LARGE_INTEGER t;
    QueryPerformanceCounter(&t);
    return t.QuadPart;
}

long getPerformanceFrequency()
{
    import core.sys.windows.windows;
    LARGE_INTEGER f;
    QueryPerformanceFrequency(&f);
    return f.QuadPart;
}


/*
class TestPanel : Widget
{
    Path!float path;

    this()
    {
        super(200,200,800,800);
        path.moveTo(-4.48518,1.69193).lineTo( 9.89451,0.150122).lineTo(-1.97198,1.42315).close();
        path.moveTo(49.276596,11.177839).lineTo(12.747784,8.287876).lineTo(50.662491,11.286461).close();
        path.moveTo(-4.820584,34.291153).lineTo(-2.890672,34.366234).lineTo(50.161381,36.457401).close();
        path.moveTo(50.861496,20.968971).lineTo(-6.823852,26.630871).lineTo(46.685181,21.377645).close();
        path.moveTo(46.575394,54.352577).lineTo(18.876856,48.298264).lineTo(-5.532673,42.964012).close();
        path.moveTo(53.697834,37.919582).lineTo(16.089132,46.436161).lineTo(55.921280,37.421677).close();
    }

	override void onPaint(Canvas canvas)
  	{
        canvas.fill(0xFF000000);
        canvas.draw(path,0xFFFFFFFF,WindingRule.EvenOdd);
    }
}
*/
/*
  Test paths
*/
/*
Path!float  gfx_area;
Path!float  gfx_borders;
Path!float  gfx_lines50;
Path!float  gfx_lines250;
Path!float  gfx_rects;
Path!float  gfx_text_l;
Path!float  gfx_text_s;
Gradient    gfx_grad1;
Gradient    gfx_grad2;
Gradient    gfx_grad3;
Font        gfx_font;

static this()
{
    import rawgfx;

    RoundRect!float rect = RoundRect!float(200,200,600,600,60,60);
    
    foreach(i; 0..36)
    {
        gfx_area.append(rect.asPath.scale(i*0.02,i*0.02,600,600).rotate(400,400,i*10));
    }

    RoundRect!float[70] rrr;

    foreach(i; 0..rrr.length)
    {
        retry:
            rrr[i] = randomRoundRect();
            auto osr = rrr[i].outset(8,true);
            foreach(q; 0..i)
                if (!intersect(osr,rrr[q]).isEmpty) goto retry; 
        gfx_borders.append(rrr[i].asPath);
        gfx_borders.append(rrr[i].inset(10,true).asPath.retro);
    }

//	gfx_borders = loadSvgPath(rawborders,1);
	gfx_lines50 = randomPath(50,1);
	gfx_lines250 = randomPath(250,20);
	gfx_rects = loadSvgPath(rawrects,1);

    gfx_font = loadFont(rawfont);

    gfx_font.setSize(40);
    gfx_text_l = buildTextPath(gfx_font,loremIpsum);
    gfx_font.setSize(14);
    gfx_text_s = buildTextPath(gfx_font,loremIpsum);

    gfx_grad1 = new Gradient;
    gfx_grad1.addStop(0,0x80fF0000).addStop(0.33,0xff00FF00).addStop(0.66,0xFF0000FF).addStop(1.0,0xFFFF0000);
    gfx_grad2 = new Gradient;
    //gfx_grad2.addStop(0,0xFFa72ac6).addStop(0.5,0x00004092).addStop(0.95,0xFFb0ae00).addStop(1,0xFFa72ac6);
    gfx_grad2.addStop(0,0xFFff0000).addStop(0.5,0xff00ff00).addStop(1.0,0xff0000ff);
}
*/
/*
long ProfileGFX(ref Path!float path)
{
		import core.sys.windows.windows;
		import std.conv;

        Canvas canvas = new Canvas(800,800);

		long time = long.max;

		foreach(i;0..50)
		{
        //    canvas.setClip(100,100,700,700);

            canvas.fill(0xff274634);

            long t = readCycleCounter();
 //           canvas.fill(path, 0xff00ff00, WindingRule.NonZero);
            t = readCycleCounter()-t;
            if (t < time) time = t;
   	}       
		
    return time;
}
*/

/*
void ProfileAll()
{
		writeln("area    : ",ProfileGFX(gfx_area));
		writeln("borders : ",ProfileGFX(gfx_borders));
		writeln("lines   : ",ProfileGFX(gfx_lines50));
		writeln("lines2  : ",ProfileGFX(gfx_lines250));
		writeln("rects   : ",ProfileGFX(gfx_rects));
		writeln("text_l  : ",ProfileGFX(gfx_text_l));
		writeln("text_s  : ",ProfileGFX(gfx_text_s));
}
*/
// load an svg path string/
/*
Path!float loadSvgPath(string txt, float scale)
{
	import readpath;
    import std.stdio;

	Path!float path;
    readPathData(txt,path);

//    path.scale(scale,scale);

    path = path.scale(scale,scale);

	return path;
}
*/
// dump an svg path string 
/*
void dumpPath(ref Path!float path, string filename)
{
    import std.stdio;
    import std.conv;

    File file = File(filename, "w");
    file.rawWrite("d=\"");

    foreach(i; 0..path.length)
    {
        if (path.cmd(i) == PathCmd.move)
        {
            file.rawWrite("M ");
            file.rawWrite(to!string(path[i].x));
            file.rawWrite(" ");
            file.rawWrite(to!string(path[i].y));
            file.rawWrite(" ");
        }
        if (path.cmd(i) == PathCmd.line)
        {
            file.rawWrite("L ");
            file.rawWrite(to!string(path[i].x));
            file.rawWrite(" ");
            file.rawWrite(to!string(path[i].y));
            file.rawWrite(" ");
        }
        if (path.cmd(i+1) == PathCmd.quad)
        {
            file.rawWrite("Q ");
            file.rawWrite(to!string(path[i].x));
            file.rawWrite(" ");
            file.rawWrite(to!string(path[i].y));
            file.rawWrite(" ");
            file.rawWrite(to!string(path[i+1].x));
            file.rawWrite(" ");
            file.rawWrite(to!string(path[i+1].y));
            file.rawWrite(" ");
            i++;
        }
        if (path.cmd(i+1) == PathCmd.cubic)
        {
            file.rawWrite("C ");
            file.rawWrite(to!string(path[i].x));
            file.rawWrite(" ");
            file.rawWrite(to!string(path[i].y));
            file.rawWrite(" ");
            file.rawWrite(to!string(path[i+1].x));
            file.rawWrite(" ");
            file.rawWrite(to!string(path[i+1].y));
            file.rawWrite(" ");
            file.rawWrite(to!string(path[i+2].x));
            file.rawWrite(" ");
            file.rawWrite(to!string(path[i+2].y));
            file.rawWrite(" ");
            i+=2;
        }
    }

    file.rawWrite("\" \n");
}
*/
// generate random lines
/*
Path!float randomPath(int n, int seed)
{
    import std.random;
    
    auto rnd = Random(seed);

    Path!float path;
    path.moveTo(uniform(20.0f, 780.0f, rnd),uniform(20.0f, 780.0f, rnd));

    foreach(i; 0..n)
    {
        path.lineTo(uniform(20.0f, 780.0f, rnd),uniform(20.0f, 780.0f, rnd));
    }
    path.close();

    return path;
}
*/
// generate random rounded rects
/*
Path!float randomRoundRect(int n, int seed)
{
    import std.random;
    
    auto rnd = Random(seed);

    Path!float path;

    foreach(i; 0..n)
    {
        float x = uniform(20.0f, 580.0f, rnd);
        float y = uniform(20.0f, 580.0f, rnd);
        float w = uniform(20.0f, 200.0f, rnd);
        float h = uniform(20.0f, 200.0f, rnd);
        float c = uniform(2.0f, ((w<h) ? w : h)/3, rnd);
        float lpc = c-c*0.55228;

        path.moveTo(x+c,y);
        path.lineTo(x+w-c,y);
        path.cubicTo(x+w-lpc,y,  x+w,y+lpc,  x+w,y+c);
        path.lineTo(x+w,y+h-c);
        path.cubicTo(x+w,y+h-lpc,  x+w-lpc,y+h,  x+w-c,y+h);
        path.lineTo(x+c,y+h);
        path.cubicTo(x+lpc,y+h,  x,y+h-lpc,  x,y+h-c);
        path.lineTo(x,y+c);
        path.cubicTo(x,y+lpc,  x+lpc,y,  x+c,y);
    }
    return path;
}
*/
/*
RoundRect!float randomRoundRect()
{
    import std.random;
    static auto rnd = Random(123);

    float x = uniform(0, 600.0f, rnd);
    float y = uniform(0, 600.0f, rnd);
    float w = uniform(20, 200, rnd);
    float h = uniform(20, 200, rnd);
    float c = uniform(2.0f, ((w<h) ? w : h)/2, rnd);

    RoundRect!float rect = RoundRect!float(x,y,x+w,y+w,c,c);

    return rect;
}
*/

// build some text as a path
/*
Path!float buildTextPath(Font font, const char[] txt)
{
    Path!float path;
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
*/