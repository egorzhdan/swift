// RUN: %target-run-simple-swift(-I %S/Inputs -cxx-interoperability-mode=default -enable-experimental-feature ForeignReferenceTypeSubclassing -Xfrontend -disable-availability-checking -Xcc -fignore-exceptions)

// REQUIRES: executable_test
// REQUIRES: swift_feature_ForeignReferenceTypeSubclassing

// UNSUPPORTED: use_os_stdlib
// UNSUPPORTED: back_deployment_runtime

import StdlibUnittest
import InheritFRT
import InheritFRTSubclassing

var Suite = TestSuite("ForeignReferenceTypeSubclassing")

final class EmptySub: SimpleShared {
  func tag() -> Int32 { return 99 }
}

final class FieldSub: SimpleShared {
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
final class PayloadSub: DeletableShared {
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

  let base: SimpleShared = s
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

runAllTests()
