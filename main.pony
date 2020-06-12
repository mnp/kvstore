use "collections"
use "ponytest"
use "time"

actor KvStore
  let _hash: HashMap [String, String, HashEq[String]]

  new create(env: Env, allocate: USize) =>
    _hash = _hash.create(allocate)
    let timers = Timers
    let timer = Timer(Reaper(env), 0, 2_000_000_000)
    timers(consume timer)

  be put(k: String, v: String) =>
    _hash.insert(k, v)

  fun get(k: String, v: String): String =>
    _hash.get_or_else(k, v)

  be delete(k: String) => 
    try
          _hash.remove(k)?
    end

class Reaper is TimerNotify
  let _env: Env
  
  new iso create(env: Env) =>    
  _env = env

  fun ref apply(timer: Timer, count: U64): Bool =>
    _env.out.print("reap")
    true

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    test(_TestHash)

class iso _TestHash is UnitTest
  let size: USize = 10000

  fun name(): String => "hash"

  fun apply(h: TestHelper) =>
      let kvstore : KvStore = KvStore(h.env, size)
      kvstore.put("x", "y")
      let got: String = kvstore.get("x", "oops")
      h.assert_eq[String](got, "y")

//      kvstore.remove("x")
//      let got2 = kvstore.get("x", "oops")
//      h.assert_eq[String](got, "y")

