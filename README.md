# betterclist
A `-betterC` compatible dynamic list backed by array for [D](https://dlang.org/).

It is available as a [DUB package](https://code.dlang.org/packages/betterclist)
and may be used directly as a [Meson subproject](https://mesonbuild.com/Subprojects.html)
or [wrap](https://mesonbuild.com/Wrap-dependency-system-manual.html).

## Usage
```d
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
```
