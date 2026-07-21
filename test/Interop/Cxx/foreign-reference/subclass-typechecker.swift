// RUN: %target-swift-frontend -typecheck -verify -cxx-interoperability-mode=default \
// RUN:   -enable-experimental-feature ForeignReferenceTypeSubclassing \
// RUN:   -I %S%{fs-sep}Inputs %s \
// RUN:   -disable-availability-checking

// REQUIRES: swift_feature_ForeignReferenceTypeSubclassing

import InheritFRT

class SwiftSubShared : SimpleShared {}

class SwiftSubDerivedShared : SingleShared_Shared {}

class Intermediate : SimpleShared {}
class TransitiveSub : Intermediate {}

class WithMembers : SimpleShared {
  var computed: Int { 0 } // expected-error {{property 'computed' must be 'final' because it is a member of a class that subclasses a C++ foreign reference type}}
  func method() {} // expected-error {{instance method 'method()' must be 'final' because it is a member of a class that subclasses a C++ foreign reference type}}

  final var okComputed: Int { 0 }
  final func okMethod() {}
}

class SubOfImmortal : SimpleImmortal {} // expected-error {{cannot inherit from non-open class 'SimpleImmortal' outside of its defining module}}
// TODO: emit a note explaining that the C++ type needs a virtual destructor
