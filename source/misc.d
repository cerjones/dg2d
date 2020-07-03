/*
  Copyright Chris Jones 2020.
  Distributed under the Boost Software License, Version 1.0.
  See accompanying file Licence.txt or copy at...
  https://www.boost.org/LICENSE_1_0.txt
*/

module dg2d.misc;

import core.stdc.stdlib : malloc, free, realloc;
public import inteli;
public import std.math : sqrt, abs;

version(LDC)
{
    import ldc.intrinsics;

    alias intr_bsf = llvm_ctlz;
    alias intr_bsr = llvm_cttz;
    alias fabs = llvm_fabs;        // DMD fabs sucks
}
else version(DigitalMars)
{
    import core.bitop;

    T intr_bsr(T)(T src, bool isZeroUndefined)
    {
        assert(isZeroUndefined);
        return bsf(src); // Note: llvm_cttz corresponds to bsf in DMD not bsr
    }
}

T min(T)(T a, T b)
{
    return (a < b) ? a : b;
}

T max(T)(T a, T b)
{
    return (a > b) ? a : b;
}

T clip(T)(T x, T min, T max)
{
    if (x < min) return min;
    if (x > max) return max;
    return x;
}

void swap(T)(ref T a, ref T b)
{
    T tmp = a;
    a = b;
    b = tmp;
}

// round x up to next multiple of q

uint roundUpTo(uint x, uint q)
{
    uint tmp = x % q;
    return (tmp) ? x - tmp + q : x;
}

// round x up to next multiple of q

uint roundUpPow2(uint x)
{
    x--;
    x |= x >> 1;
    x |= x >> 2;
    x |= x >> 4;
    x |= x >> 8;
    x |= x >> 16;
    return x+1;
}

ulong roundUpPow2(ulong x)
{
    x--;
    x |= x >> 1;
    x |= x >> 2;
    x |= x >> 4;
    x |= x >> 8;
    x |= x >> 16;
    x |= x >> 32;
    return x+1;
}

// is power of 2

bool isPow2(int x)
{
    return ! ((x - 1) & x);
}

// is float or double,

enum bool isFloatOrDouble(T) = (is(T == float) || is(T == double));

// load file into malloced memory

ubyte[] loadFileMalloc(string filename)
{
    import std.stdio;
    import core.stdc.stdlib : malloc, free, realloc;

    File file = File(filename, "r"); 
    if (!file.isOpen) return null;
    if (file.size > size_t.max) return null;
    ubyte* p = cast(ubyte*) malloc(cast(size_t) file.size);
    if (p == null) return null;
    ubyte[] tmp = file.rawRead(p[0..cast(size_t)file.size]);

    if (tmp.length != file.size)
    {
        free(p);
        return null;
    }
    else
    {
        return tmp;
    }
}

/*
  broadcast alpha

  x is [A2,R2,G2,B2,A1,R1,G1,B1], 16 bit components with lower 8 bits used
  returns [A2,A2,A2,A2,A1,A1,A1,A1], 16 bits used
  two versions, shuffleVector should lower to pshufb, but it is a bit slower on
  my CPU, maybe from increased register pressure?
*/

__m128i _mm_broadcast_alpha(__m128i x)
{
    x = _mm_shufflelo_epi16!255(x);
    x = _mm_shufflehi_epi16!255(x);
    return _mm_slli_epi16(x,8);
//    return  cast(__m128i)
//        shufflevector!(byte16, 7,6,7,6,7,6,7,6,  15,14,15,14,15,14,15,14)
//            (cast(byte16)a, cast(byte16)a);
}

/*
  nextSetBit, searches the bit mask for the next set bit. 

  mask  - array that holds the bits
  start - start position
  end   - end position

  returns : index of next set bit, or "end" if none found

  note the mask should be long enough in the given word size to hold
  the bits, IE. If end = 65, then the uint mask should be 3 uints,
  the ulong mask should be 2 ulongs. If end = 64, then it only
  need be 2 uints or 1 ulong.
*/

int nextSetBit(ulong* mask, int start, int end)
{
    assert((start >= 0) && (start < end));

    int nsb = start;
    int idx = nsb>>6;
    ulong bits = mask[idx] >> (nsb & 63); 

    if (bits == 0)
    {
        idx++;
        int msklen = (end+63)>>6;
        while (idx < msklen)
        {
            if (mask[idx] != 0)
            {
                nsb = idx*64 + cast(int) intr_bsr(mask[idx],true);
                if (nsb > end) nsb = end;
                return nsb;
            }
            idx++;
        }
        return end;
    }
    nsb = nsb + cast(int) intr_bsr(bits,true);
    if (nsb > end) nsb = end;
    return nsb;
}

int nextSetBit(uint* mask, int start, int end)
{
    assert((start >= 0) && (start < end));

    int nsb = start;
    int idx = nsb>>5;
    uint bits = mask[idx] >> (nsb & 31); 

    if (bits == 0)
    {
        idx++;
        int msklen = (end+31)>>5;
        while (idx < msklen)
        {
            if (mask[idx] != 0)
            {
                nsb = idx*32 + cast(int) intr_bsr(mask[idx],true);
                if (nsb > end) nsb = end;
                return nsb;
            }
            idx++;
        }
        return end;
    }
    nsb = nsb + cast(int) intr_bsr(bits,true);
    if (nsb > end) nsb = end;
    return nsb;
}

/*
  Arena Allocator, very fast allocation, free all memory at once. Essentialy
  it is a linked list of memory blocks and allocation is sequential through
  each block and on to the next. If it runs out of blocks it allocates and
  adds a new one to the end of the linked list. Reset() resets the allocator
  to the begining of the first block. Nothing is freed back to the C allocator
  until the destructor is called. No init or clean up is done of the memory.
*/

struct ArenaAllocator(T, uint blockSize)
{  
    struct EABlock
    {
        EABlock* next;
        T[blockSize] items;
    }

    EABlock* m_root;
    EABlock* m_block;
    uint m_pos = uint.max;

    // note: m_pos is set to uint.max if no blocks are allocated yet. This avoids
    // having to do two conditional tests in the fast path of allocate() method.

public:

    ~this()
    {
        while (m_root)
        {
            EABlock* tmp = m_root;
            m_root = m_root.next;
            free(tmp);
        }
    }

    T* allocate()
    {
        if (m_pos < blockSize)
        {
            return &m_block.items[m_pos++];
        }
        else
        {
            if (m_block)
            {
                if (m_block.next)
                {
                    m_block = m_block.next;
                    m_pos = 0;
                    return &m_block.items[m_pos++];
                }
                else
                {
                    void* tmp = malloc(EABlock.sizeof);
                    if (!tmp) assert(0); // no mem abandon ship!
                    m_block.next = cast(EABlock*) tmp;
                    m_block = m_block.next;
                    m_block.next = null;
                    m_pos = 0;
                    return &m_block.items[m_pos++];
                }
            }
            else
            {
                void* tmp = malloc(EABlock.sizeof);
                if (!tmp) assert(0); // no mem abandon ship!
                m_root = cast(EABlock*) tmp;
                m_block = m_root;
                m_block.next = null;
                m_pos = 0;
                return &m_block.items[m_pos++];
            }
        }
    }

    void reset()
    {
        m_block = m_root;
        m_pos = (m_root) ? 0 : uint.max;
    }
}

/*
   Simple array which uses the C heap
   Keeps track of capacity to minimize reallocations
   Frees the memory when it is destroyed
   Disables copying and assignment
   can either init new items in the array, or not
*/

struct Array(T, bool voidInit = false)
{
    @disable this(this);

    @disable void opAssign(Array other);

    ~this()
    {
    //    if(m_elements) free(m_elements);
    }

    bool empty()
    {
        return (m_length == 0);
    }

    void reset()
    {
        m_length = 0;
    }

    size_t length() 
    {
        return m_length;
    }

    void length(size_t newlen)
    {
        import std.algorithm.mutation : initializeAll;

        if(newlen > m_capacity) setCapacity(newlen);
        static if (!voidInit) 
            if (newlen > m_length) initializeAll(m_elements[m_length..newlen]);
        m_length = newlen;
    }

    size_t capacity()
    {
        return m_capacity;
    }

    void reserve(size_t newcap)
    {
        setCapacity(newcap);
    }

    ref T opIndex(size_t idx)
    {
        assert(idx < m_length);
        return m_elements[idx];
    }

    T opIndexAssign(T what, size_t idx)
    {
        assert(idx < m_length);
        m_elements[idx] = what;
        return what;
    }

    T[] opSlice()
    {
        return m_elements[0..m_length];
    }

    T[] opSlice(size_t from, size_t to)
    {
        assert((from < to) && (to < m_length));
        return m_elements[from..to];
    }

    void opSliceAssign(T value)
    {
       m_elements[0..m_length] = value;
    }

    size_t opDollar()
    {
        return m_length;
    }

    void append(T item)
    {
        length = m_length+1;
        m_elements[m_length-1] = item;
    }

    void append(T[] items)
    {
        size_t newlen = m_length+items.length;
        setCapacity(newlen);
        m_elements[m_length..newlen] = items[];
    }

    T* ptr()
    {
        return m_elements;
    }


private:

    void setCapacity(size_t newcap)
    {
        if (newcap <= m_length) return;
        newcap = roundUpPow2(newcap|15);
        if (newcap == 0) assert(0); // overflowed
        if (newcap > (size_t.max/T.sizeof)) assert(0); // too big
        m_data = realloc(m_data, newcap*T.sizeof + 15);
        size_t alignmentMask = (cast(size_t)-1) - 15;
        size_t elements = (cast(size_t)m_data + 15) & alignmentMask;
        m_elements = cast(T*) elements;
        if (!m_elements) assert(0); // allocate failed
        m_capacity = newcap;
    }

    T* m_elements;
    size_t m_length;
    size_t m_capacity;
    void* m_data; // unaligned data
}

/*
  Realloc and malloc memory from c std heap
  Adds type safety and overflow / out of mem checks
*/

T* dg2dRealloc(T)(T* ptr, size_t length)
{
    import core.stdc.stdlib : realloc;
    if (length > size_t.max/T.sizeof) assert(0); // Too large
    ptr = cast(T*) realloc(ptr, length * T.sizeof);
    if (ptr == null) assert(0); // Alloc failed abandon ship!
    return ptr;
}

T* dg2dMalloc(T)(size_t length = 1)
{
    import core.stdc.stdlib : malloc;
    if (length > size_t.max/T.sizeof) assert(0); // Too large
    T* ptr = cast(T*) malloc(length * T.sizeof);
    if (ptr == null) assert(0); // Alloc failed abandon ship!
    return ptr;
}

void dg2dFree(void* ptr)
{
    import core.stdc.stdlib : free;
    free(ptr);
}

