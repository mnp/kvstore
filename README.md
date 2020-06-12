# Key/Value Store - Design Exercise

## Primary Structures

Given limited implementation time, existing components are desired where possible.

The main idea is a worker thread to handle the TTL expirations and another from each caller.

### Keys

We need a constant time lookup so a hash table is the obvious choice. Since we've kindly been given a constraint of 10 million pairs, we also want to find
an implementation which includes a preallocation option to avoid a resize penalty.

### Data

? can we assume bounded size data? is it small enough to preallocate all data items?

### Expirations

1. Create a min-priority queue to hold TTLs, which can handle multiple entries at the same time slot
2. kv PUTs with a TTL specified get inserted into the queue at their expiration time, while PUTs without a TTL are not inserted.
3. Worker thread runs at 1/f and does a DELETE on key in that TTL time slot

### Verification

test driver should keep a histogram of percentile response times

### Latency Management

1. abusive test driver
2. profile if needed and iterate

# Implementation selection

## Tradeoffs
bounded time to research and implement vs target call performance

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
