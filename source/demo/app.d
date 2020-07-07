/*
  Copyright Chris Jones 2020.
  Distributed under the Boost Software License, Version 1.0.
  See accompanying file Licence.txt or copy at...
  https://www.boost.org/LICENSE_1_0.txt
*/

module app;

import std.stdio;
import window;
import canvas;
import font;

import dg2d.path;
import dg2d.geometry;
import dg2d.gradient;
import dg2d.misc;
import dg2d.rasterizer;

void main()
{
//	ProfileAll();

    GFXPanel panel = new GFXPanel();
    //TestPanel panel = new TestPanel();
    Window wnd = new Window();
    wnd.addClient(panel);
    wnd.createWindow(200,200,800,800,"graphics test");
	WindowsMessageLoop();
}

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
        canvas.fill(path,0xFFFFFFFF,WindingRule.EvenOdd);
    }
}

class GFXPanel : Widget
{
	override void onPaint(Canvas canvas)
  	{
        canvas.fill(0xFF000000);
        canvas.setClip(clipoffset,clipoffset,tmpcvs.width-clipoffset,tmpcvs.height-clipoffset);

        switch(fillidx % 4)
        {
            case 0:
                canvas.fill(0xFF101520);
                canvas.fill(*sel_path,0xFFFFFFFF,sel_wind);
                break;
            case 1:
                canvas.fill(0xFF101520);
                canvas.fillLinear(*sel_path,gfx_grad1,sel_wind,400,400,450,450);
                break;
            case 2:
                canvas.fill(0xFF101520);
                canvas.fillRadial(*sel_path,gfx_grad2,sel_wind,380,350,500,700,150);
                break;
            case 3:
                canvas.fill(0xFF101520);
                canvas.fillAngular(*sel_path,gfx_grad1,sel_wind,380,350,500,350,120);
                break;
            default: break;      
        }
    }

    void buttonClicked()
    {
        switch(pathbtn.selectedIdx % 7)
        {
            case 0: sel_path = &gfx_area; break;
            case 1: sel_path = &gfx_borders; break;
            case 2: sel_path = &gfx_lines50; break;
            case 3: sel_path = &gfx_lines250; break;
            case 4: sel_path = &gfx_rects; break;
            case 5: sel_path = &gfx_text_l; break;
            case 6: sel_path = &gfx_text_s; break;
            default: break;
        }

        sel_wind = WindingRule.NonZero;
        if (windbtn.selectedIdx == 1) sel_wind = WindingRule.EvenOdd;

        fillidx = fillbtn.selectedIdx;

        bestfps = 0;

        repaint();
    }

    void shrinkClip()
    {
        clipoffset++;
        repaint();
    }

    override void onTimer()
    {
//		import ldc.intrinsics;
		import core.sys.windows.windows;
		import std.conv;
        
        tmpcvs.resetView();
        tmpcvs.fill(0xff274634);

//        long t = readcyclecounter();
        LARGE_INTEGER t0,t1,f;
        QueryPerformanceCounter(&t0);

        switch(fillidx % 4)
        {
            case 0: tmpcvs.fill(*sel_path,0xFFFFFFFF,sel_wind); break;
            case 1: tmpcvs.fillLinear(*sel_path,gfx_grad1,sel_wind,300,300,500,500); break;
            case 2: tmpcvs.fillRadial(*sel_path,gfx_grad2,sel_wind,400,400,500,700,150); break;
            case 3: tmpcvs.fillAngular(*sel_path,gfx_grad1,sel_wind,400,400,500,400,200); break;
            default: break;      
        }

//        t = readcyclecounter()-t;
//       toptime = min(t,toptime);

        QueryPerformanceCounter(&t1);

        long t3 = cast(ulong) t1.QuadPart - cast(ulong) t0.QuadPart;
        QueryPerformanceFrequency(&f);
        float fps = to!float(f.QuadPart) / t3;

        bestfps = max(fps,bestfps);
        timlbl.setText(to!string(bestfps)~" fps");
        timlbl.repaint();
   	}       

    this()
    {
        super(0,0,800,800);
        gfx_font.setSize(22);
        pathbtn = new Button(32,10,160,40,["block","borders","lines50","lines250","rects","text","text small"],gfx_font);
        pathbtn.setOnClick(&buttonClicked);
        addChild(pathbtn);
        fillbtn = new Button(224,10,160,40,["solid","linear","radail","angular"],gfx_font);
        fillbtn.setOnClick(&buttonClicked);
        addChild(fillbtn);
        windbtn = new Button(416,10,160,40,["non zero","even odd"],gfx_font);
        windbtn.setOnClick(&buttonClicked);
        addChild(windbtn);
        blendbtn = new Button(608,10,160,40,["shrink clip"],gfx_font);
        blendbtn.setOnClick(&shrinkClip);
        addChild(blendbtn);
        timlbl = new Label(300,60,200,30,"",gfx_font);
        addChild(timlbl);
        
        sel_path = &gfx_area;

        tmpcvs = new Canvas(800,800);

    }  

    Button pathbtn;
    Button fillbtn;
    Button windbtn;
    Button blendbtn;
    Label  timlbl;

    Path!float* sel_path;
    WindingRule sel_wind = WindingRule.NonZero;
    int fillidx = 0;

    float bestfps = 0;

    Canvas tmpcvs;

    int clipoffset;
}

/*
  Test paths
*/

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
    gfx_grad1.addStop(0,0xffFF0000).addStop(0.33,0xff00FF00).addStop(0.66,0xFF0000FF).addStop(1.0,0xFFFF0000);
    gfx_grad2 = new Gradient;
    gfx_grad2.addStop(0,0xFFa72ac6).addStop(0.5,0x00004092).addStop(0.95,0xFFb0ae00).addStop(1,0xFFa72ac6);
}

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

            long t = readcyclecounter();
            canvas.fill(path, 0xff00ff00, WindingRule.NonZero);
            t = readcyclecounter()-t;
            if (t < time) time = t;
   	}       
		
    return time;
}

version(LDC)
{
    import ldc.intrinsics: readcyclecounter;
}
else version(DigitalMars)
{
    long readcyclecounter()
    {
        long result;
        asm nothrow @nogc pure
        {
            rdtscp;
            mov dword ptr [result+0], EAX;
            mov dword ptr [result+4], EDX;
        }
        return result;
    }
}



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

// load an svg path string/

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

// dump an svg path string 

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

// generate random lines

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


// build some text as a path

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
