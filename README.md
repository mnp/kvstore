# Key/Value Store - Design Exercise

**NOOB WARNING:** Starting to learn Pony, don't look!


## Problem and Assumptions

Stated elswhere.

## Primary Structures

We select structures to store keys and values, one to store TTLs, and a worker actor to clean the expired keys.

### Keys

We need a constant time lookup so a hash table is the obvious choice. Since we've kindly been given a constraint of 10 million pairs, we also want to find
an implementation which includes a preallocation option to avoid a resize penalty.

### TTL -> Key priority queue

There's a neat structure called a [hierarchical timing wheel](http://www.cs.columbia.edu/~nahum/w6998/papers/sosp87-timing-wheels.pdf)
specially suited for this task. Having no implementations of that in hand, a more general purpose structure is indicated.

1. Create a min-priority queue (binary heap) to hold TTLs, which can handle multiple entries at the same time slot
2. kv PUTs with a TTL specified get inserted into the queue at their expiration time, while PUTs without a TTL are not inserted.
3. Worker thread runs at 1/f and does a DELETE on key in that TTL time slot

### Worker Actor

Worker fires on a timer callback and compares current time to smallest in min heap, if found it remoeves from the hash.

### Verification

test driver should keep a histogram of percentile response times

### Latency Management

1. abusive test driver
2. profile if needed and iterate

# Implementation selection

## Tradeoffs

* Bounded time to research and implement vs target call performance
* Simplicity of implementation vs performance
* Integrity safety vs performance
* Memory vs performance (eg preallocate)
* Education time on environment

## Jvm

Will have a GC penalty. Mitigations to investigate include:

* invest time to research tuning GC for the problem
* preallocating everything
* set heapsize large enough to handle planned allocations
* create no new objects after startup to avoid additional allocations
* benchmark, analyze, search stack overflow, and iterate

## Python 

Has some nice structures but because the GIL is itself single threaded, will cause the TTL worker to stall hash lookups

## C++ with boost/stl/etc_oss

The STL does include nice structures but locking is assumed for thread contention. There ARE lock-free data structures however they come with time penalties, eg 
[Lock-Free Data Structures with Hazard Pointers](http://erdani.com/publications/cuj-2004-12.pdf): Andrei AlexandrescuMaged Michael, October 16, 2004.

Here's a [concurrent hashmap called Junction](https://preshing.com/20160201/new-concurrent-hash-maps-for-cpp/) with some significant limitations.

The addition of a FIFO request queue in front of the hash table would solve this problem on insert. There are lock free FIFOs available, eg [Moody Camel](https://moodycamel.com/blog/2014/a-fast-general-purpose-lock-free-queue-for-c++) which link contains some metrics and also points to other implementations like Boost and Intel. 

Bears more research, big ecosystem.

## Erlang

Has actor/message passing semantics with GC localized per actor, which
can be used to serialize and gate hash requests. It has an [ETS tuple
facility](http://erlang.org/doc/man/ets.html) with "atomic" and "isolated" guarantees which will probably do the job.

## Pony

This problem was clearly tailored as a sweet spot for Pony which has all these attributes by design focus, out of the box.
