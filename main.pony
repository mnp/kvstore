use "collections"
use "promises"
use "time"

// TODO - learn how to do generics instead of type aliases; then we can do: let _store = KvStore[T1,T2](env,1000)
// TODO - learn how to do promise.FulfillIdentity so we can have a synchronous retrieve? -- needed for functional test
// TODO - borrow Histogram from Wallaroo for characterization of response times
// TODO - use TestList/TestHelper to generate unit tests
// TODO - retrieve should return a Result(Ok,Err). It simply doesn't call its promise at the moment.
// BUG  - reaper should loop until no more values are present older than now().

type Keytype is String
type Valtype is String

class KvStore
"""
     class KvStore         -- Abstracts implementation of promises
     |
     +- actor KvHash       -- Managed hash map (k,v)
     +- actor KvTTLManager -- Priority queue mapping TTL->hash keys plus timers
        |
	      class KvReaper     -- Notifier callback 
	      class KvKilltime   -- structure stored in a priority heap, (key, time)
"""

  let _store: KvHash
  let _ttlmgr: KvTTLManager
  let _env: Env

  new create(env: Env, allocate: USize, reap_interval_ns: U64) =>
  """
      Pass preallocation size of hashmap (# entries), and the frequency to remove old keys (ns).
  """
      _store = KvHash(allocate)
      _ttlmgr = KvTTLManager(env, _store, reap_interval_ns)
      _env = env

  fun retrieve(key: Keytype, p: Promise[Valtype]) =>
    _store.retrieve(key, p)

  fun put(key: Keytype, value: Valtype) =>
    _store.put(key, value)

  fun ref put_ttl(key: Keytype val, value: Valtype val, ttl_sec: I64 val) =>
    _store.put(key, value)
    _ttlmgr.schedule(key, ttl_sec)

  fun delete(key: Keytype) =>
    _store.remove(key)


actor KvHash
"""
Simple guarded hash map
"""
  let hash: HashMap[Keytype, Valtype, HashEq[Keytype]] ref

  new create(allocate: USize) =>
    hash = hash.create(allocate)

  be put(key: Keytype, value: Valtype) =>
    hash.insert(key, value)

  be retrieve(key: Keytype, p: Promise[Valtype]) =>
    try
      var got = hash(key)?
      p(got)
    else
      p.reject()
    end

  be remove(key: Keytype) =>
    try
      hash.remove(key)?
    end


actor KvTTLManager
"""
"""
  let _hash: KvHash
  let _ttls: MinHeap[KvKillTime]
  let _env: Env

  new create(env: Env, hash: KvHash, reap_interval_ns: U64) =>
	    _hash = hash
      _ttls = MinHeap[KvKillTime].create(1)
      _env = env
      let timers = Timers
      let timer = Timer(KvReaper(this), 0, reap_interval_ns)
      timers(consume timer)

  be schedule(key: Keytype, ttl_sec: I64) =>
      let now = Time.seconds()
      let kt = KvKillTime.create(key, now + ttl_sec)  // store absolute time
      _ttls.push(kt)

  be reap() =>
      try 
          let smallest = _ttls.peek()?
          let killtime = smallest.gettime()
          let killkey  = smallest.getkey()
          let now = Time.seconds()
          if (killtime < now) then
              _ttls.pop()?
              _hash.remove(killkey)
              _env.out.print("reap smallest:" + killtime.string() + "=" + killkey.string() + " removed")
          else
              _env.out.print("reap smallest:" + killtime.string() + "=" + killkey.string() + " ... but not now")
          end
      else
          _env.out.print("reap - no entries ")
      end

class val KvKillTime is Comparable[KvKillTime box]
"""
Simple pair representing when to kill an entry
"""
let _killtime: I64  // secs
let _key: Keytype

  new val create(key: Keytype, killtime: I64) =>
  _killtime = killtime
  _key = key
  
  fun gettime(): I64 => _killtime
  fun getkey(): Keytype => _key

  fun eq(that: KvKillTime box): Bool => (_killtime == that._killtime)
  fun lt(that: KvKillTime box): Bool => (_killtime <  that._killtime)
  fun le(that: KvKillTime box): Bool => (_killtime <= that._killtime)
  fun gt(that: KvKillTime box): Bool => (_killtime >  that._killtime)
  fun ge(that: KvKillTime box): Bool => (_killtime >= that._killtime)


class KvReaper is TimerNotify
"""
Periodically scan the priority queue for entries that need killing
"""
  let _ttlmgr: KvTTLManager

  new iso create(ttlmgr: KvTTLManager) =>
  _ttlmgr = ttlmgr

  fun ref apply(timer: Timer, count: U64): Bool =>
    _ttlmgr.reap()
    true

//
// Test driver
//

actor Main
  let _store: KvStore
  let _out: OutStream

  new create(env: Env) =>
    _out = env.out
    _store = KvStore(env, /*10_000_000*/ 10, 2_000_000_000)

    _store.put("test1", "foo")
    _store.put("test2", "fez")
    _store.put("test3", "fiz")

    _store.delete("test1")
    _store.delete("nonexistent")

    _store.put_ttl("test5", "bar", 5)
    _store.put_ttl("test8", "baz", 8)
    _store.put_ttl("test9", "bam", 9)

    var n : U32 = 10
    while n > 0 do
        timeget("test1")
        timeget("test2")
        timeget("test3")
        n = n - 1
    end

  fun timeget(key: String) =>
    let promise = Promise[Valtype]
    let mbeg = Time.micros()
    let value = _store.retrieve(key, promise)
    promise.next[None](recover this~report(mbeg) end)

  be report(mbeg: U64, x: Valtype val) =>
    let mend = Time.micros()
    let elapsed = mend - mbeg
    _out.print("retrieve " + x.string() + " elapsed:" + elapsed.string() + " uS")
