module betterclist;

import std.algorithm;
import std.range;
import std.traits;

struct List(T, long N = -1)
{
    alias ElementType = T;

    /// Whether List has fixed size, which means it is backed by a static array
    enum isSized = N >= 0;
    static if (isSized)
    {
        /// Static array with capacity N that holds the List elements.
        T[N] array;

        /// Construct List with initial elements.
        this(Args...)(auto ref Args args)
        {
            pushBack(args);
        }
    }
    else
    {
        /// Slice with dynamic capacity that holds the List elements.
        T[] array;

        /// Construct List with backing slice and optional initial elements.
        this(Args...)(T[] backingSlice, auto ref Args args)
        {
            this.array = backingSlice;
            static if (args.length > 0)
            {
                pushBack(args);
            }
        }

        /// Construct List with backing pointer and capacity and optional initial elements.
        this(Args...)(T* backingArrayPointer, size_t capacity, auto ref Args args)
        {
            this(backingArrayPointer[0 .. capacity], args);
        }

        /// Construct List with backing buffer slice and optional initial elements.
        this(Args...)(void[] backingSlice, auto ref Args args)
        {
            this(cast(T[]) backingSlice, args);
        }

        /// Construct List with backing buffer pointer and size and optional initial elements.
        this(Args...)(void* backingArrayPointer, size_t bufferSize, auto ref Args args)
        {
            this(backingArrayPointer[0 .. bufferSize], args);
        }
    }
    /// Current used length, must be less than array's length.
    /// This is readonly accessible by the `length` property from used slice.
    private size_t usedLength = 0;

    invariant
    {
        assert(usedLength <= array.length);
    }

    @nogc pure
    {
        /// List element capacity, which is the backing array's length.
        @property size_t capacity() const @safe nothrow
        {
            return array.length;
        }

        /// Available capacity for inserting elements.
        @property size_t availableCapacity() const @safe nothrow
        {
            return capacity - usedLength;
        }

        /// Returns whether there are no elements in List.
        @property bool empty() const @safe nothrow
        {
            return usedLength == 0;
        }

        /// Returns whether List is full, that is, has no more available capacity.
        @property bool full() const @safe nothrow
        {
            return usedLength == capacity;
        }

        /// Get a slice for the used elements.
        auto usedSlice() inout
        {
            return array[0 .. usedLength];
        }
        /// Get a slice for the remaining elements.
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
        in { assert(index < usedLength); }
        do
        {
            return usedSlice[index];
        }
        /// Alias this allows operations to target used slice by default.
        alias usedSlice this;
    }

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
            auto rangeLength = range.length;
            if (rangeLength > availableCapacity)
            {
                range.take(availableCapacity).copy(remainingSlice);
                usedLength = capacity;
                return cast(typeof(return))(range.length - availableCapacity);
            }
            range.copy(remainingSlice);
            usedLength += rangeLength;
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

    /// Ditto
    long pushBack(Args...)(auto ref Args args)
    if (args.length > 1)
    {
        return pushBack(only(args));
    }
    alias push = pushBack;

    /// Push back elements on `list ~= args`
    auto opOpAssign(string op : "~", Args...)(auto ref Args args)
    {
        return pushBack(args);
    }

    /++
     + Pop the last element from List.
     + If element type has elaborate destructor, popped slot is reinitialized to `T.init`.
     +/
    void popBack()
    {
        if (!empty)
        {
            usedLength--;
            static if (hasElaborateDestructor!T)
            {
                array[usedLength] = T.init;
            }
        }
    }
    /++
     + Pop `count` elements from the back of the List.
     + If element type has elaborate destructor, popped slots are reinitialized to `T.init`.
     +/
    void popBack(const size_t count)
    {
        auto minCount = min(count, usedLength);
        static if (hasElaborateDestructor!T)
        {
            usedSlice[$ - minCount .. $] = T.init;
        }
        usedLength -= minCount;
    }
    alias pop = popBack;

    /++
     + Clear all elements of List.
     + If element type has elaborate destructor, popped slots are reinitialized to `T.init`.
     +/
    void clear()
    out { assert(length == 0); assert(empty); }
    do
    {
        static if (hasElaborateDestructor!T)
        {
            usedSlice[] = T.init;
        }
        usedLength = 0;
    }
}

/// Construct List from static array, inferring element type.
List!(T, N) list(T, uint N)(const auto ref T[N] values)
{
    return typeof(return)(values[]);
}
///
unittest
{
    int[3] values = [1, 2, 3];
    assert(list(values) == values);
}

/// Construct List from slice.
List!(T) list(T)(auto ref T[] array)
{
    typeof(return) l = array;
    l.usedLength = array.length;
    return l;
}
///
unittest
{
    auto v = list([1, 2, 3]);
    assert(v == [1, 2, 3]);
}

/// Construct List from elements, specifying element type.
List!(U, Args.length) list(U, Args...)(const auto ref Args args)
{
    return typeof(return)(args);
}
///
unittest
{
    const auto v = list!double(1, 2, 3);
    assert(is(Unqual!(typeof(v)) == List!(double, 3)));
    assert(v == [1.0, 2.0, 3.0]);
}

/// Construct List from elements, inferring element type.
auto list(Args...)(const auto ref Args args)
if (!is(CommonType!Args == void))
{
    return .list!(CommonType!Args)(args);
}
///
unittest
{
    const auto v = list(1f, 2, 3);
    assert(is(Unqual!(typeof(v)) == List!(float, 3)));
    assert(v == [1f, 2f, 3f]);
}

/// Construct List with the specified length and type from Input Range.
List!(U, N) list(U, size_t N, T)(scope T range)
if (isInputRange!T)
{
    return typeof(return)(range.take(N));
}
///
unittest
{
    const auto l = list!(double, 4)(repeat(42));
    assert(l == [42.0, 42.0, 42.0, 42.0]);
}

/// Construct List with the specified length from Input Range, inferring element type.
auto list(size_t N, T)(scope T range)
if (isInputRange!T)
{
    return .list!(ElementType!T, N)(range);
}
///
unittest
{
    const auto l = list!4(repeat(42));
    assert(l == [42, 42, 42, 42]);
}

/// Construct List from Input Range at compile time.
auto list(alias values)()
if (isInputRange!(typeof(values)))
{
    return .list!(size_t(values.length))(values);
}
///
unittest
{
    auto l = list!(iota(4).map!"a * a");
    assert(l == [0, 1, 4, 9]);
    l = list!(repeat(42).take(4));
    assert(l == [42, 42, 42, 42]);
}

unittest
{
    List!(int, 8) l;
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
    assert(l[].sum == 16);
    assert(l[$-2 .. $] == [2, 3]);

    int five() { return 5; }
    assert(l.pushBack(generate!five) < 0);
    assert(l.full);
    assert(l == [10, 0, 1, 2, 3, 5, 5, 5]);

    assert(l.pushBack(500) > 0);
    assert(l.back == 5);
    l.popBack();
    assert(l.length == l.capacity - 1);
    assert((l ~= 500) == 0);
    assert(l.full);
    assert(l.back == 500);

    l.popBack(2);
    assert(l.length == l.capacity - 2);
    l.clear();
    assert(l.empty);
    l.popBack(42);
}

unittest
{
    int[10] array = 42;
    auto l = List!(int)(array[]);
    assert(l.capacity == 10);
    assert(l.length == 0);
    assert(l[] == null);
    assert(l == null);

    auto l2 = List!(int)(array[], 0, 1);
    assert(l2.capacity == 10);
    assert(l2.length == 2);
    assert(l2[] == [0, 1]);
    assert(l2 == [0, 1]);
}

unittest
{
    import std.experimental.allocator.mallocator : Mallocator;
    void[] buffer = Mallocator.instance.allocate(8 * int.sizeof);

    auto l = List!(int)(buffer);
    assert(l.capacity == 8);

    Mallocator.instance.deallocate(buffer);
}

unittest
{
    import betterclist : List;

    // Lists may be backed by static arrays by passing the capacity to template
    List!(int, 16) list;
    assert(list.capacity == 16);

    // Lists track their own element usage
    assert(list.length == 0);
    assert(list.empty);

    list.pushBack(0);  // pushBack inserts an element in the end of the used slice
    assert(list.length == 1);
    assert(list[0] == 0);  // opIndex(size_t) indexes used elements slice, `list[1]` is out of bounds here
    list[0] = 1;  // assigning to index works, if your List is mutable

    list.push(2, 3);  // push is an alias to pushBack. Several elements may be pushed at once
    assert(list[] == [1, 2, 3]);  // opIndex() returns the used slice
    assert(list.availableCapacity == 13);

    list ~= 4;  // operator ~= also calls pushBack
    assert(list == [1, 2, 3, 4]);  // Lists are aliased to the used slice by `alias this`
    assert(list[2 .. $] == [3, 4]);  // this means stuff like opDollar, slicing and length just works
    // so does foreach
    import std.stdio : writeln;
    foreach (value; list)
    {
        writeln(value);
    }
    // so does importing common range stuff
    import std.range;
    assert(list.front == 1);
    assert(list.back == 4);

    list.popBack();  // pops the last value. If element type has elaborate detructors, reinitializes element to it's `.init` value
    assert(list == [1, 2, 3]);
    list.popBack(2);  // pops the last N values. The same caveats apply
    assert(list == [1]);
    list.pop();  // pop is an alias to popBack
    assert(list == null);
    list.pop(42);  // popping more items than there are is safe
    list.clear();  // pops all elements from List
    assert(list.empty);

    list.push(iota(16));  // ranges can be pushed at once
    assert(list.full);
    auto result = list.push(1, 2);  // Trying to push more items than capacity permits is an error, but no exception is thrown...
    assert(result == 2);  // ...rather pushBack returns the number of items that were not inserted
    list.clear();
    result = list.push(1, 1, 2, 3, 5);
    assert(result == 0);  // if all items were inserted, pushBack returns 0
    result = list.pushBack(repeat(42));  // if range has no known length and not all elements were inserted...
    assert(result < 0);  // ...pushBack returns a negative value

    // Lists can also be backed by a slice
    import core.stdc.stdlib : malloc, free;
    alias IntList = List!int;

    enum bufferSize = 8 * int.sizeof;
    void* buffer = malloc(bufferSize);

    // Construction using void[]
    auto sliceList = IntList(buffer[0 .. bufferSize]);
    assert(sliceList.capacity == 8);

    // Construction using element type slice
    sliceList = IntList(cast(int[]) buffer[0 .. bufferSize]);
    assert(sliceList.capacity == 8);

    // Construction using void pointer and explicit buffer size (be careful!)
    sliceList = IntList(buffer, bufferSize);
    assert(sliceList.capacity == 8);

    // Construction using element type pointer and explicit capacity (be careful!)
    sliceList = IntList(cast(int*) buffer, 8);
    assert(sliceList.capacity == 8);

    // Lists backed by slices do not manage their own memory (TODO: memory mamaged (noGC, but destructor/auto resize) List type)
    free(buffer);
}
