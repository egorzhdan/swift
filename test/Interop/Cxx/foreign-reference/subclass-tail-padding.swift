// RUN: %empty-directory(%t)
// RUN: %target-swiftc_driver %s -I %S/Inputs -cxx-interoperability-mode=default -enable-experimental-feature ForeignReferenceTypeSubclassing -Xfrontend -disable-availability-checking -Xcc -fignore-exceptions -sanitize=address -o %t/a.out
// RUN: %target-codesign %t/a.out
// RUN: %target-run %t/a.out | %FileCheck %s

// REQUIRES: executable_test
// REQUIRES: asan_runtime
// REQUIRES: swift_feature_ForeignReferenceTypeSubclassing
// UNSUPPORTED: OS=windows-msvc
// UNSUPPORTED: use_os_stdlib
// UNSUPPORTED: back_deployment_runtime

import InheritFRTSubclassing

// The stored properties of a Swift subclass reuse the tail padding of the C++
// base, so that `z` ends past the size of the base. The instance is allocated
// with room for it: AddressSanitizer reports an overflow otherwise.
final class TailPaddedSub: TailPaddedShared {
  var y: Int32 = 5
  var z: Int32 = 6
}

let s = TailPaddedSub()
s.z += 1
// CHECK: 5 7
print(s.y, s.z)
