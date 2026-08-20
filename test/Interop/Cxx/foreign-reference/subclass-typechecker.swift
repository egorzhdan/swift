// RUN: %target-swift-frontend -typecheck -verify -cxx-interoperability-mode=default \
// RUN:   -enable-experimental-feature ForeignReferenceTypeSubclassing \
// RUN:   -I %S%{fs-sep}Inputs %s \
// RUN:   -disable-availability-checking

// REQUIRES: swift_feature_ForeignReferenceTypeSubclassing

import InheritFRT
import InheritFRTSubclassing

final class SwiftSubShared : SimpleShared {}

final class SwiftSubDerivedShared : SingleShared_Shared {}

class NotFinal : SimpleShared {} // expected-error {{class 'NotFinal' must be 'final' because it subclasses 'SimpleShared', a C++ foreign reference type}}

open class Opened : SimpleShared {} // expected-error {{class 'Opened' must be 'final' because it subclasses 'SimpleShared', a C++ foreign reference type}}

final class TransitiveSub : SwiftSubShared {} // expected-error {{inheritance from a final class 'SwiftSubShared'}}

final class WithMembers : SimpleShared {
  var computed: Int { 0 }
  func method() {}

  final var okComputed: Int { 0 }
  final func okMethod() {}
}

class SubOfImmortal : SimpleImmortal {} // expected-error {{cannot inherit from non-open class 'SimpleImmortal' outside of its defining module}}
// TODO: emit a note explaining that the C++ type needs a virtual destructor

final class Okay: SharedConstructed {
  let f: Int64
  init(f: Int64, a: Int32) {
    self.f = f
    super.init(a)
  }
  convenience init(f: Int64) {
    self.init(f: f, a: 0)
  }
}

final class WrongArgumentType: SharedConstructed {
  init(s: String) {
    super.init(s) // expected-error {{cannot convert value of type 'String' to expected argument type 'CInt' (aka 'Int32')}}
  }
}

// The base's imported constructors are not designated initializers, so they
// cannot be overridden.
final class OverridesBaseInit: SharedConstructed {
  override init() { // expected-error {{initializer does not override a designated initializer from its superclass}}
    super.init()
  }
}

final class ConvenienceChainsToSuper: SharedConstructed {
  convenience init(a: Int32) {
    super.init() // expected-error {{convenience initializer for 'ConvenienceChainsToSuper' must delegate (with 'self.init') rather than chaining to a superclass initializer (with 'super.init')}}
  }
}

// A designated initializer must chain to the base's constructor, not delegate.
final class DesignatedDelegates: SharedConstructed {
  let x: Int64 // expected-note {{'x' declared here}}
  init(x: Int64) { // expected-error {{designated initializer for 'DesignatedDelegates' cannot delegate (with 'self.init'); did you mean this to be a convenience initializer?}}
    // expected-note@-1 {{'init(x:)' declared here}}
    self.x = x // expected-error {{'let' property 'x' may not be initialized directly; use "self.init(...)" or "self = ..." instead}}
    self.init() // expected-note {{delegation occurs here}}
    // expected-error@-1 {{missing argument for parameter 'x' in call}}
  }
}

final class DelegatesWithoutStorage: SharedConstructed {
  init(a: Int32) { // expected-error {{designated initializer for 'DelegatesWithoutStorage' cannot delegate (with 'self.init'); did you mean this to be a convenience initializer?}}
    // expected-note@-1 {{'init(a:)' declared here}}
    self.init() // expected-note {{delegation occurs here}}
    // expected-error@-1 {{missing argument for parameter 'a' in call}}
  }
}

// A designated initializer cannot be declared in an extension.
final class InitInExtension: SharedConstructed {}

extension InitInExtension {
  init(a: Int32) { // expected-error {{designated initializer cannot be declared in an extension of 'InitInExtension'; did you mean this to be a convenience initializer?}}
    super.init() // expected-error {{convenience initializer for 'InitInExtension' must delegate (with 'self.init') rather than chaining to a superclass initializer (with 'super.init')}}
  }
}

// A convenience initializer delegates to a designated one as usual.
final class WithConvenienceInit: SharedConstructed {
  let value: Int32
  init(a: Int32) { // expected-note {{'init(a:)' declared here}}
    self.value = a
    super.init()
  }
  convenience init(b: Int32) {
    self.init(a: b)
  }
}

// An initializer may omit `super.init` if the base has a no-argument
// constructor: the call to it is inserted implicitly.
final class OmitsSuperInit: SimpleShared {
  let x: Int64
  init(x: Int64) { // expected-note {{'init(x:)' declared here}}
    self.x = x
  }
}

// A subclass that declares no initializer of its own gets an implicit default
// one, as long as its stored properties are default initializable...
final class DefaultInitialized: SharedConstructed {
  let x: Int64 = 42
}

// ...otherwise it has no initializers at all: the base's constructors are not
// inherited, because they know nothing about the subclass's storage.
final class NoInitializerOfItsOwn: SimpleShared { // expected-error {{class 'NoInitializerOfItsOwn' has no initializers}}
  let x: Int64 // expected-note {{stored property 'x' without initial value prevents synthesized initializers}}
}

func constructThem() {
  _ = DefaultInitialized()
  _ = OmitsSuperInit(x: 0)
  _ = WithConvenienceInit(b: 0)

  // The base's constructors cannot be used to construct the subclass: they
  // would allocate an object of the base's size and leave the subclass's stored
  // properties uninitialized.
  _ = OmitsSuperInit() // expected-error {{missing argument for parameter 'x' in call}}
  _ = DefaultInitialized(1) // expected-error {{argument passed to call that takes no arguments}}
  _ = WithConvenienceInit() // expected-error {{missing argument for parameter 'a' in call}}
}
