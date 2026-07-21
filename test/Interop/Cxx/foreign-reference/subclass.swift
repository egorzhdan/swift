// RUN: %target-run-simple-swift(-I %S/Inputs -cxx-interoperability-mode=default -enable-experimental-feature ForeignReferenceTypeSubclassing -Xfrontend -disable-availability-checking -Xcc -fignore-exceptions)

// REQUIRES: executable_test
// REQUIRES: swift_feature_ForeignReferenceTypeSubclassing

// UNSUPPORTED: use_os_stdlib
// UNSUPPORTED: back_deployment_runtime

import StdlibUnittest
import InheritFRTSubclassing

var Suite = TestSuite("ForeignReferenceTypeSubclassing")

final class EmptySub: SubclassableShared {
  func tag() -> Int32 { return 99 }
}

final class FieldSub: SubclassableShared {
  let x: Int64
  let y: Int64
  init(x: Int64, y: Int64) {
    self.x = x
    self.y = y
    super.init()
  }
  func sum() -> Int64 { return x + y }
}

final class OneArgSub: SharedConstructed {
  let f: Int64
  init(f: Int64, a: Int32) {
    self.f = f
    super.init(a)
  }
}
final class TwoArgSub: SharedConstructed {
  let f: Int64
  init(f: Int64, a: Int32, b: Int) {
    self.f = f
    super.init(a, b)
  }
}

var livePayloads = 0
final class Payload {
  init() { livePayloads += 1 }
  deinit { livePayloads -= 1 }
}
final class PayloadSub: SharedConstructed {
  let payload: Payload
  let tag: Int64
  init(payload: Payload, tag: Int64) {
    self.payload = payload
    self.tag = tag
    super.init()
  }
}

// This one has no initializer of its own: it gets an implicit default
// initializer that chains to the base's no-argument constructor.
final class DefaultInitSub: SharedConstructed {
  let tag: Int64 = 7
}

Suite.test("empty subclass: static method dispatch and upcast") {
  let s = EmptySub()
  expectEqual(99, s.tag())

  let base: SubclassableShared = s
  base.set(3)
  expectEqual(3, s.get())
}

Suite.test("implicit default initializer") {
  let s = DefaultInitSub()
  expectEqual(7, s.tag)
  expectEqual(0, s.getA())
  expectEqual(0, s.getB())

  let base: SharedConstructed = s
  expectEqual(0, base.getA())
}

Suite.test("stored properties survive base construction") {
  let s = FieldSub(x: 42, y: 100)
  expectEqual(42, s.x)
  expectEqual(100, s.y)
  expectEqual(142, s.sum())

  s.set(7)
  expectEqual(7, s.get())
}

Suite.test("super.init forwards arguments to the C++ base constructor") {
  let one = OneArgSub(f: 7, a: 42)
  expectEqual(7, one.f)
  expectEqual(42, one.getA())
  expectEqual(0, one.getB())

  let two = TwoArgSub(f: 99, a: 11, b: 22)
  expectEqual(99, two.f)
  expectEqual(11, two.getA())
  expectEqual(22, two.getB())
}

Suite.test("non-trivial stored properties are destroyed on release") {
  expectEqual(0, livePayloads)
  do {
    let s = PayloadSub(payload: Payload(), tag: 42)
    expectEqual(42, s.tag)
    expectEqual(1, livePayloads)
  }
  // `s` released -> refcount 0 -> C++ delete -> shim destructor ->
  // DestroyFields releases `payload` -> Payload.deinit runs.
  expectEqual(0, livePayloads)

  // When another reference keeps the payload alive, it is not destroyed early.
  let kept = Payload()
  do {
    let s = PayloadSub(payload: kept, tag: 1)
    _ = s
  }
  expectEqual(1, livePayloads)
  withExtendedLifetime(kept) {}
}

final class ConstRefSub: ReferenceConstructed {
  let tag: Int64 = 1
  init(_ i: Int32) { super.init(i) }
}
final class InoutSub: ReferenceConstructed {
  let tag: Int64 = 1
  init(_ i: inout Int32) { super.init(&i, 0) }
}
final class ByValueSub: ReferenceConstructed {
  let tag: Int64 = 1
  init(_ arg: NonTrivialArg) { super.init(arg, 0) }
}
final class ConstRefNonTrivialSub: ReferenceConstructed {
  let tag: Int64 = 1
  init(_ arg: NonTrivialArg) { super.init(arg, CChar(0)) }
}
final class ReferenceTypeArgSub: ReferenceConstructed {
  let tag: Int64 = 1
  init(_ arg: RefcountedArg) { super.init(arg, CShort(0)) }
}
final class SelfFieldArgSub: ReferenceConstructed {
  let x: Int32
  init(x: Int32) {
    self.x = x
    super.init(self.x)
  }
}
final class SelfReferenceTypeArgSub: ReferenceConstructed {
  let arg: RefcountedArg
  init(_ arg: RefcountedArg) {
    self.arg = arg
    super.init(self.arg, CShort(0))
  }
}
final class PicksIntSub: OverloadedConstructed {
  let tag: Int64 = 1
  init() { super.init(Int32(1)) }
}
final class PicksDoubleSub: OverloadedConstructed {
  let tag: Int64 = 1
  init() { super.init(2.0) }
}

Suite.test("super.init passes reference parameters by reference") {
  expectEqual(42, ConstRefSub(42).getSeen())

  var i: Int32 = 42
  let s = InoutSub(&i)
  expectEqual(42, s.getSeen())
  // The C++ constructor wrote through the reference.
  expectEqual(100, i)
}

Suite.test("super.init copies and destroys non-trivial C++ arguments") {
  expectEqual(0, getLiveNonTrivialArgs())
  do {
    let arg = NonTrivialArg(7)
    expectEqual(7, ByValueSub(arg).getSeen())
    expectEqual(7, ConstRefNonTrivialSub(arg).getSeen())
    // Only `arg` itself is left alive.
    expectEqual(1, getLiveNonTrivialArgs())
  }
  expectEqual(0, getLiveNonTrivialArgs())
}

Suite.test("super.init does not leak foreign reference arguments") {
  let arg = RefcountedArg(9)
  expectEqual(1, arg.getRefcount())
  do {
    expectEqual(9, ReferenceTypeArgSub(arg).getSeen())
  }
  expectEqual(1, arg.getRefcount())
}

Suite.test("super.init arguments may read stored properties of self") {
  expectEqual(11, SelfFieldArgSub(x: 11).getSeen())

  let arg = RefcountedArg(5)
  let s = SelfReferenceTypeArgSub(arg)
  expectEqual(5, s.getSeen())
  // One reference from `arg`, one from `s.arg`.
  expectEqual(2, arg.getRefcount())
}

Suite.test("super.init constructs the base with the overload Swift picked") {
  expectEqual(1, PicksIntSub().getWhich())
  expectEqual(2, PicksDoubleSub().getWhich())
}

// A `let` property passed to a `const &` parameter is passed in place, as it
// would be to a direct call, so a reference the base keeps stays valid.
final class KeepsOwnFieldSub: KeepsReference {
  let x: Int32
  init(x: Int32) {
    self.x = x
    super.init(self.x)
  }
}

Suite.test("super.init passes let properties of self in place") {
  let s = KeepsOwnFieldSub(x: 42)
  expectTrue(s.refersIntoSelf())
  expectEqual(42, s.read())
}

runAllTests()
