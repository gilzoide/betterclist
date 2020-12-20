module betterclist;

import std.algorithm;
import std.range;

struct List(T, long N = -1)
{
    /// Whether List has fixed size, which means it is backed by a static array
    enum isSized = N >= 0;
    static if (isSized)
    {
        /// Static array with capacity N that holds the List elements.
        T[N] array;
    }
    else
    {
        /// Slice with dynamic capacity that holds the List elements.
        T[] array;
    }
    /// Current used length, must be less than array's length.
    /// This is readonly accessible by the `length` property from used slice.
    private typeof(array.length) usedLength = 0;

    invariant
    {
        assert(usedLength <= array.length);
    }

    /// List element capacity, which is the backing array's length.
    @property size_t capacity() const
    {
        return array.length;
    }

    /// Available capacity for inserting elements.
    @property size_t availableCapacity() const
    {
        return capacity - usedLength;
    }

    /// Returns whether there are no elements in List.
    @property bool empty() const
    {
        return usedLength == 0;
    }

    /// Returns whether List is full, that is, has no more available capacity.
    @property bool full() const
    {
        return usedLength == capacity;
    }

    private auto usedSlice() inout
    {
        return array[0 .. usedLength];
    }
    private auto remainingSlice() inout
    {
        return array[usedLength .. capacity];
    }

    /// Get a slice for the used elements.
    auto opIndex() inout
    {
        return usedSlice;
    }
    /// Index the slice of used elements.
    auto ref opIndex(const size_t index) inout
    in { assert(index < capacity); }
    do
    {
        return usedSlice[index];
    }
    /// Alias this allows operations to target used slice by default.
    alias usedSlice this;

    /++
     + Push a value in the end of List.
     + Returns: 0 if value was successfully inserted, 1 otherwise.
     +/
    long pushBack(U)(auto ref U value)
    if (!isInputRange!U)
    {
        if (full)
        {
            return 1;
        }
        array[usedLength] = value;
        usedLength++;
        return 0;
    }

    /++
     + Push a range of values to the end of List.
     + Returns: number of values not inserted into List:
     +          0 if all values were inserted successfully,
     +          positive number if the number of remaining elements is known,
     +          -1 if the number of remaining elements is not know.
     +/
    long pushBack(R)(auto ref R range)
    if (isInputRange!R)
    {
        static if (hasLength!R)
        {
            if (range.length > availableCapacity)
            {
                range.take(availableCapacity).copy(remainingSlice);
                usedLength = capacity;
                return cast(typeof(return))(range.length - availableCapacity);
            }
            range.copy(remainingSlice);
            usedLength += range.length;
            return 0;
        }
        else
        {
            while (!range.empty && usedLength < capacity)
            {
                array[usedLength] = range.front;
                usedLength++;
                range.popFront;
            }
            return range.empty ? 0 : -1;
        }
    }
    alias push = pushBack;

    /++
     + Pop the last element from List.
     + If initialize is true, popped slot is reinitialized to `T.init`.
     +/
    void popBack(bool initialize = true)()
    {
        if (!empty)
        {
            usedLength--;
            static if (initialize)
            {
                array[usedLength] = T.init;
            }
        }
    }
    /++
     + Pop `count` elements from the back of the List.
     + If initialize is true, popped slots are reinitialized to `T.init`.
     +/
    void popBack(bool initialize = true)(const size_t count)
    {
        auto minCount = min(count, usedLength);
        static if (initialize)
        {
            usedSlice.retro.take(minCount).fill(T.init);
        }
        usedLength -= minCount;
    }
    alias pop = popBack;

    /++
     + Clear all elements of List.
     + If initialize is true, popped slots are reinitialized to `T.init`.
     +/
    void clear(bool initialize = true)()
    {
        static if (initialize)
        {
            usedSlice.fill(T.init);
        }
        usedLength = 0;
    }
}

unittest
{
    alias IntList = List!(int, 8);
    IntList l;
    assert(l.length == 0);
    assert(l[] == null);
    assert(l == null);

    assert(l.pushBack(5) == 0);
    assert(l.length == 1);
    assert(l[0] == 5);
    assert(l == [5]);
    assert(l[0 .. $] == [5]);

    l[0] = 10;
    assert(l.length == 1);
    assert(l[0] == 10);
    assert(l == [10]);
    assert(l[0 .. $] == [10]);

    assert(l.pushBack(iota(4)) == 0);
    assert(l.length == 5);
    assert(l == [10, 0, 1, 2, 3]);

    int five() { return 5; }
    assert(l.pushBack(generate!five) < 0);
    assert(l.full);
    assert(l == [10, 0, 1, 2, 3, 5, 5, 5]);

    assert(l.pushBack(500) > 0);
    assert(l.back == 5);
    l.popBack();
    assert(l.length == l.capacity - 1);
    assert(l.pushBack(500) == 0);
    assert(l.full);
    assert(l.back == 500);

    l.popBack(2);
    assert(l.length == l.capacity - 2);
    l.clear();
    assert(l.empty);
    l.popBack(42);
}
