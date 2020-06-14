use "collections"
use "promises"
use "time"

// TODO - learn how to do generics instead of type aliases; then we can do: let _store = KvStore[T1,T2](env,1000)
// TODO - learn how to do promise.FulfillIdentity so we can have a synchronous read?

type Keytype is String
type Valtype is String

class KvStore
"""
     class KvStore         -- Abstracts implementation of promises
     |
     +- Actor KvHash       -- Managed hash map
     +- Actor KvReaper     -- Priority queue mapping TTL->hash keys plus timers
"""

  let _store: KvHash
  let _env: Env

  new create(env: Env, allocate: USize, reap_interval_ns: U64) =>
      _store = KvHash(env, allocate)
      _env = env
      let timers = Timers
      let timer = Timer(KvReaper(env), 0, reap_interval_ns)
      timers(consume timer)

  fun read(key: Keytype, p: Promise[Valtype]) =>
    _store.read(key, p)

  fun put(key: Keytype, value: Valtype) =>
    _store.put(key, value)

  fun put_ttl(key: Keytype, value: Valtype, ttl: USize) =>
    _store.put(key, value)
    //    _timerthing(key, ttl)

  fun remove(key: Keytype) =>
    _store.remove(key)

actor KvHash
  let hash: HashMap[Keytype, Valtype, HashEq[Keytype]] ref
  let _env: Env

  new create(env: Env, allocate: USize) =>
    hash = hash.create(allocate)
    _env = env
    env.out.print("start")

  be put(key: Keytype, value: Valtype) =>
    hash.insert(key, value)

  be read(key: Keytype, p: Promise[Valtype]) =>
    try
      var got = hash(key)?
      _env.out.print("got " + got)
      p(got)
    else
      _env.out.print("did not get")
      p.reject()
    end

  be remove(key: Keytype) =>
    try
      hash.remove(key)?
    else
      _env.out.print("did not remove")
    end

class KvReaper is TimerNotify
  let _env: Env

  new iso create(env: Env) =>
  _env = env

  fun ref apply(timer: Timer, count: U64): Bool =>
    _env.out.print("reap")
    true

//
// Test driver
//

actor Main
  let _store: KvStore
  let _out: OutStream
  let _time: Time

  new create(env: Env) =>
    let key = "test"
    _out = env.out
    _store = KvStore(env, 1000, 2_000_000_000)
    _time = Time.create()

    _store.put(key, "foo")

    let promise = Promise[Valtype]
    let mbeg = _time.millis()
    let value = _store.read("test", promise)
    promise.next[None](recover this~report(Time.micros()) end)

    _store.remove("test")
    //  read("test")
    _store.remove("test")
    //  read("test")

  be report(mbeg: U64, x: Valtype val) =>
    let mend = Time.micros()
    let elapsed = mend - mbeg
    _out.print("yay top level read " + x.string() + " " + elapsed.string() + " uS")
