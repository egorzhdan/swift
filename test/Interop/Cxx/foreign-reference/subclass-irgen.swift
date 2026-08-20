// RUN: %target-swift-emit-ir %s -I %S/Inputs -cxx-interoperability-mode=default \
// RUN:   -Xcc -fignore-exceptions -disable-availability-checking \
// RUN:   -enable-experimental-feature ForeignReferenceTypeSubclassing \
// RUN:   | %FileCheck %s

// REQUIRES: swift_feature_ForeignReferenceTypeSubclassing

import InheritFRT

// A Swift subclass lays out its stored properties *after* the C++ base
// subobject, and carries no Swift heap header (the object uses the base FRT's
// custom reference counting). `SimpleShared` has a virtual destructor, so its
// subobject is { vptr (8 bytes), refcount (Int32), payload (Int32) } = 16
// bytes; a Swift field follows at offset 16.

// A single Swift field is placed right after the 16-byte base subobject.
// CHECK-DAG: %T{{.*}}3SubC = type <{ [8 x i8], %Ts5Int32V, %Ts5Int32V, %Ts5Int64V }>

// Multiple stored properties pack after the base with correct alignment
// padding: Int8 at offset 16, then 7 bytes of padding, then Int64 at offset 24.
// CHECK-DAG: %T{{.*}}5MultiC = type <{ [8 x i8], %Ts5Int32V, %Ts5Int32V, %Ts4Int8V, [7 x i8], %Ts5Int64V }>

public final class Sub: SimpleShared {
  public let x: Int64 = 42
}

public final class Multi: SimpleShared {
  public let a: Int8 = 1
  public let b: Int64 = 2
}

public func getX(_ s: Sub) -> Int64 { return s.x }
// CHECK-LABEL: define {{.*}}4getX
// CHECK: getelementptr inbounds{{.*}} %T{{.*}}3SubC, ptr %0, i32 0, i32 3


public final class SwiftSubShared: SimpleShared {}

public final class SubOfDerivedShared: SingleShared_Shared {}

public func retainRelease(_ x: SwiftSubShared) -> (SwiftSubShared, SwiftSubShared) {
  return (x, x)
}
// CHECK-LABEL: define {{.*}} @"$s{{.*}}13retainRelease{{.*}}"(ptr %0)
// CHECK-NOT: swift_retain
// CHECK: call void @_Z18retainSimpleSharedP12SimpleShared(ptr %0)
// CHECK: call void @_Z18retainSimpleSharedP12SimpleShared(ptr %0)
// CHECK: ret

public func consume(_ x: consuming SwiftSubShared) {}
// CHECK-LABEL: define {{.*}} @"$s{{.*}}7consume{{.*}}"(ptr %0)
// CHECK-NOT: swift_release
// CHECK: call void @_Z19releaseSimpleSharedP12SimpleShared(ptr %{{.*}})
// CHECK: ret void

public func consumeDerived(_ x: consuming SubOfDerivedShared) {}
// CHECK-LABEL: define {{.*}} @"$s{{.*}}14consumeDerived{{.*}}"(ptr %0)
// CHECK-NOT: swift_release
// CHECK: call void @{{.*}}releaseSingleShared_Shared{{.*}}(ptr %{{.*}})
// CHECK: ret void
