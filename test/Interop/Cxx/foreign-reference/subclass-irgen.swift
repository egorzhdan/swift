// RUN: %target-swift-emit-ir %s -I %S/Inputs -cxx-interoperability-mode=default \
// RUN:   -Xcc -fignore-exceptions -disable-availability-checking \
// RUN:   -enable-experimental-feature ForeignReferenceTypeSubclassing \
// RUN:   | %FileCheck %s

// REQUIRES: swift_feature_ForeignReferenceTypeSubclassing

import InheritFRTSubclassing

// A Swift subclass lays out its stored properties *after* the C++ base
// subobject, and carries no Swift heap header (the object uses the base FRT's
// custom reference counting). `SubclassableShared` has a virtual destructor, so its
// subobject is { vptr (8 bytes), refcount (Int32), payload (Int32) } = 16
// bytes; a Swift field follows at offset 16.

// A single Swift field is placed right after the 16-byte base subobject.
// CHECK-DAG: %T{{.*}}3SubC = type <{ [8 x i8], %Ts5Int32V, %Ts5Int32V, %Ts5Int64V }>

// Multiple stored properties pack after the base with correct alignment
// padding: Int8 at offset 16, then 7 bytes of padding, then Int64 at offset 24.
// CHECK-DAG: %T{{.*}}5MultiC = type <{ [8 x i8], %Ts5Int32V, %Ts5Int32V, %Ts4Int8V, [7 x i8], %Ts5Int64V }>

public final class Sub: SubclassableShared {
  public let x: Int64 = 42
}

public final class Multi: SubclassableShared {
  public let a: Int8 = 1
  public let b: Int64 = 2
}

public func getX(_ s: Sub) -> Int64 { return s.x }
// CHECK-LABEL: define {{.*}}4getX
// CHECK: getelementptr inbounds{{.*}} %T{{.*}}3SubC, ptr %0, i32 0, i32 3


public final class SwiftSubShared: SubclassableShared {}

public final class SubOfDerivedShared: DerivedOwnRefcountShared {}

public func retainRelease(_ x: SwiftSubShared) -> (SwiftSubShared, SwiftSubShared) {
  return (x, x)
}
// CHECK-LABEL: define {{.*}} @"$s{{.*}}13retainRelease{{.*}}"(ptr %0)
// CHECK-NOT: swift_retain
// CHECK: call void @{{.*}}retainSubclassableShared{{.*}}(ptr %0)
// CHECK: call void @{{.*}}retainSubclassableShared{{.*}}(ptr %0)
// CHECK: ret

public func consume(_ x: consuming SwiftSubShared) {}
// CHECK-LABEL: define {{.*}} @"$s{{.*}}7consume{{.*}}"(ptr %0)
// CHECK-NOT: swift_release
// CHECK: call void @{{.*}}releaseSubclassableShared{{.*}}(ptr %{{.*}})
// CHECK: ret void

public func consumeDerived(_ x: consuming SubOfDerivedShared) {}
// CHECK-LABEL: define {{.*}} @"$s{{.*}}14consumeDerived{{.*}}"(ptr %0)
// CHECK-NOT: swift_release
// CHECK: call void @{{.*}}releaseDerivedOwnRefcountShared{{.*}}(ptr %{{.*}})
// CHECK: ret void

// `super.init` arguments are lowered as for a direct call to the base
// constructor. A `const &` parameter receives the address of a temporary
// holding the value, not the value itself.
public final class ConstRefArgSub: ReferenceConstructed {
  public let t: Int64 = 1
  public init(_ i: Int32) { super.init(i) }
}
// CHECK-LABEL: define {{.*}} @"$s{{.*}}14ConstRefArgSubCyACs5Int32Vcfc"(i32 %0,
// CHECK:         [[TEMP:%.*]] = alloca %Ts5Int32V
// CHECK-NOT:     inttoptr
// CHECK:         call void @{{.*}}__swift_constructBase{{.*}}RKi{{.*}}(ptr {{%.*}}, ptr [[TEMP]])
// CHECK:         ret

// A non-trivial C++ type passed by value is copied into a temporary, which the
// caller destroys after the call.
public final class ByValueArgSub: ReferenceConstructed {
  public let t: Int64 = 1
  public init(_ arg: NonTrivialArg) { super.init(arg, 0) }
}
// CHECK-LABEL: define {{.*}} @"$s{{.*}}13ByValueArgSubCyACSo010NonTrivialD0Vcfc"(ptr
// CHECK:         [[TEMP:%.*]] = alloca %TSo13NonTrivialArgV
// CHECK:         call {{.*}} @_ZN13NonTrivialArgC1ERKS_(ptr [[TEMP]],
// CHECK-NEXT:    call void @{{.*}}__swift_constructBase{{.*}}13NonTrivialArgl{{.*}}(ptr {{%.*}}, ptr [[TEMP]], i64 0)
// CHECK-NEXT:    call {{.*}} @_ZN13NonTrivialArgD1Ev(ptr [[TEMP]])
