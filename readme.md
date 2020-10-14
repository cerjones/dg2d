# DG2D - D Graphics 2D
### 2D vector graphics rendering library for the D Programming Language

### Features

Fill arbitrary paths, with lines, quads and cubics.

Solid fill, linear gradient, radial gradient and angular gradient, biradial gradient


Basic font rendering. (Just pulls glyphs from a truetype file atm)

Some geometry, points, rects, paths.

Very fast, high performance rasterizer with SIMD support.

Its very much alpha state in terms of features and API stability, but actual code is pretty reliable / stable.

### Performance

Best performance is with LDC, you need link time optimization on, or cross module inlining enabled. This is to ensure that the intel intrinsics get inlined properly.

Its single threaded at the moment. So the FPS displayed in the demo app is for one core.

### requirements

The rasterizer only works with 32 bits per pixel, scanlines must be 16 byte aligned. 
Requires x86 SSE2
Requires "intel-intrinsics" by AuburnSounds

### Todo / Goals

(in no particular order):

Plain D blitters, so the rasterizer will work on any CPU.

Improve font support: Expand supported truetype features. I also have a couple of ideas to make font rendering much faster. Id like to explore auto hinting.

Path stroking.

Other blend modes, eg Porter Duff etc... Not yet figured a sensible way to do this that would not either be slow, or result in vast amounts of generated code.

Multi-threaded rendering. I have a couple of ideas for implementing this.

Image support, pattern fills.

Rounded rectangle shader. Essentialy a kind of gradient fill where the distance from the perimeter is used to index the gradient.

### Examples from the demo app

![Demo Image 1](/images/Image1.png)

code that generates this image

```
RoundRect!(float)[40] rects;

auto rnd = Random(42);
foreach(i; 0..rects.length)
{
    retry:
        rects[i] = randomRoundRect(rnd);
        auto osr = rects[i].outset(8,true);
        foreach(q; 0..i)
            if (!intersect(osr,rects[q]).isEmpty) goto retry; 
}

canvas.draw(
    rects[i].asPath.append(rects[i].inset(8,true).asPath.retro),
    uniform(0, 0xFFFFFFFF, rnd) | 0xff000000,
    WindingRule.NonZero
    );
```

![Demo Image 2](/images/Image2.png)

This curently just rips the glyphs from the font file and appends them into a single path. So it's drawn all in one go.

![Demo Image 3](/images/Image3.png)

code that generates this image

```
    Path!float path;

    auto rnd = Random(588);
    RoundRect!(float)[50] rects;

    foreach(i; 0..rects.length)
    {
        retry:
            rects[i] = randomRoundRect(rnd);
            auto osr = rects[i].outset(6,true);
            foreach(q; 0..i)
                if (!intersect(osr,rects[q]).isEmpty) goto retry;
            path.append(rects[i].asPath);
    }

    Gradient grad = new Gradient(256);       
    grad.initEqualSpaced(0xFFffff00,0xff00ffff,0xFFff00ff,0xFF80ff80);

    canvas.draw(
        path,
        LinearGradient(300,300,700,700,grad,RepeatMode.Pad),
        WindingRule.NonZero
        );
```

![Demo Image 4](/images/Image4.png)

code that generates this image

```
Gradient grad = new Gradient(256);       
grad.initEqualSpaced(0xFFff0000,0xff00ff00,0xFF0000ff,0xffffffff);

path = Path!float();

path.moveTo(-400,0);
foreach(i; 0..33)
    path.lineTo(Point!float((i%2) ? 400 : -400, 0).rotate(i*360/66.0))
    .lineTo(Point!float((i%2) ? -400 : 400, 0).rotate(i*360/66.0));
path.close();
path = path.offset(400,400);

foreach(i; 1..20)
    path.append(Circle!float(400,400,i*20).asPath);

canvas.draw(
    path,
    AngularGradient(400,400,400,600,600,400,1,grad,RepeatMode.Repeat),
    WindingRule.EvenOdd
    );
```

![Demo Image 5](/images/Image5.png)

code that generates this image

```
Gradient grad = new Gradient(1024);       
grad.initEqualSpaced(0xFFffff00,0xff009766,0xFF7b057f);
path = Path!float();
path.append(Rect!float(0,0,800,800).asPath);

canvas.draw(
    path,
    BiradialGradient(300,300,50,400,400,300,grad,RepeatMode.Pad),
    WindingRule.EvenOdd
    );

```

![Demo Image 6](/images/Image6.png)

code that generates this image

```
Gradient grad = new Gradient();
grad.initEqualSpaced(0xFFfF0000,0xff00FF00,0xFF0000FF,0xFFFF0000);      
auto path = Path!float();

Path!float tmp;
tmp.moveTo(0,0).lineTo(300,20).lineTo(370,0).lineTo(300,-20).close();
Path!float tmp2;
tmp2 = Circle!float(0,0,50).asPath;

foreach(i; 0..36)
{
    path.append(tmp.offset(400,400).rotate(400,400,i*10));
    path.append(tmp2.offset(700,400).rotate(400,400,i*10));
}

canvas.draw(
    path,
    RadialGradient(400,400,400,300,700,300,grad,RepeatMode.Repeat),
    WindingRule.EvenOdd
    );

```

![Demo Image 7](/images/Image7.png)

code that generates this image

```
Gradient grad = new Gradient(8);       
grad.initEqualSpaced(0xFFe9b827,0xff8f1e62,0xFFff0000);
auto path = Path!float();

foreach(i; 0..160)
{
    path.append(Circle!float(i*3+10,0,i+17).asPath.rotate(i*13).offset(400,400));
}

canvas.draw(
    path,
    BiradialGradient(300,300,50,400,400,300,grad,RepeatMode.Mirror),
    WindingRule.EvenOdd
    );
```

