// RUN: %target-swift-emit-ir %s -I %S/Inputs -cxx-interoperability-mode=default \
// RUN:   -Xcc -fignore-exceptions -disable-availability-checking \
// RUN:   -enable-experimental-feature ForeignReferenceTypeSubclassing \
// RUN:   | %FileCheck %s

// REQUIRES: swift_feature_ForeignReferenceTypeSubclassing

// The checks below use the Itanium C++ ABI. With pointer authentication, the
// v-table pointers are signed, which subclass-irgen-macosx-ptrauth.swift checks.
// UNSUPPORTED: OS=windows-msvc
// UNSUPPORTED: CPU=arm64e

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

// Stored properties start in the tail padding of a C++ base: `TailPaddedShared`
// is { vptr (8 bytes), refcount (Int32) }, which is 12 bytes of data in a
// 16-byte type.
// CHECK-DAG: %T{{.*}}13TailPaddedSubC = type <{ [8 x i8], %Ts5Int32V, %Ts5Int32V, %Ts5Int32V }>

// The v-tables of the subclass shims are emitted.
// CHECK-DAG: @_ZTV19__SwiftSubclassShimI20ReferenceConstructed{{.*}} = linkonce_odr unnamed_addr constant { [4 x ptr] }
// CHECK-DAG: @_ZTV19__SwiftSubclassShimI23MultiplyInheritedShared{{.*}} = linkonce_odr unnamed_addr constant { [4 x ptr], [5 x ptr] }

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

// `super.init` calls the base-object constructor of the C++ base on `self`,
// and then has Clang point the v-table pointer of `self` at the v-table of the
// subclass shim. The arguments are lowered as for a direct call to the base constructor:
// a `const &` parameter receives the address of a temporary holding the value,
// not the value itself. The base constructor only borrows `self`, and returns
// it with the ownership that its factory returns a new object with. The
// constructors of `ReferenceConstructed` return retained, so `self` needs no
// retain.
public final class ConstRefArgSub: ReferenceConstructed {
  public let t: Int64 = 1
  public init(_ i: Int32) { super.init(i) }
}
// CHECK-LABEL: define {{.*}} @"$s{{.*}}14ConstRefArgSubCyACs5Int32Vcfc"(i32 %0,
// CHECK:         [[TEMP:%.*]] = alloca %Ts5Int32V
// CHECK-NOT:     inttoptr
// CHECK-NOT:     _ZN20ReferenceConstructedC2ERKi
// CHECK:         call {{.*}}@_ZN20ReferenceConstructedC2ERKi(ptr [[SELF:%[0-9]+]], ptr [[TEMP]])
// CHECK-NEXT:    call void @[[CR_INIT:__clang_vtable_ptr_init\._ZTS19__SwiftSubclassShimI20ReferenceConstructed[^(]*]](ptr [[SELF]])
// CHECK:         ret

// Clang emits the function that initializes the v-table pointer, along with the
// v-table and the destructors that it refers to.
// CHECK:       define linkonce_odr void @_ZN19__SwiftSubclassShimI20ReferenceConstructed{{.*}}D0Ev(
// CHECK:       define linkonce_odr hidden void @[[CR_INIT]](ptr {{.*}})
// CHECK:         [[THIS:%.*]] = load ptr, ptr
// CHECK:         [[VPTR:%.*]] = getelementptr inbounds i8, ptr [[THIS]], i64 0
// CHECK-NEXT:    store ptr getelementptr inbounds inrange(-16, 16) ({ [4 x ptr] }, ptr @_ZTV19__SwiftSubclassShimI20ReferenceConstructed{{.*}}, i32 0, i32 0, i32 2), ptr [[VPTR]]
// CHECK-NEXT:    ret void

// A non-trivial C++ type passed by value is copied into a temporary, which the
// caller destroys after the call.
public final class ByValueArgSub: ReferenceConstructed {
  public let t: Int64 = 1
  public init(_ arg: NonTrivialArg) { super.init(arg, 0) }
}
// CHECK-LABEL: define {{.*}} @"$s{{.*}}13ByValueArgSubCyACSo010NonTrivialD0Vcfc"(ptr
// CHECK:         [[TEMP:%.*]] = alloca %TSo13NonTrivialArgV
// CHECK:         call {{.*}} @_ZN13NonTrivialArgC1ERKS_(ptr [[TEMP]],
// CHECK-NEXT:    call {{.*}}@_ZN20ReferenceConstructedC2E13NonTrivialArgl(ptr {{%.*}}, ptr [[TEMP]], i64 0)
// CHECK-NEXT:    call {{.*}} @_ZN13NonTrivialArgD1Ev(ptr [[TEMP]])

// A base with more than one v-table pointer gets each of them pointed at the
// corresponding v-table of the subclass shim. The constructor of
// `MultiplyInheritedShared` is not annotated, so like its factory, it returns
// `self` at +0, which is retained.
public final class MultiplyInheritedSub: MultiplyInheritedShared {
  public let z: Int64 = 3
  public init() { super.init() }
}
// CHECK-LABEL: define {{.*}} @"$s{{.*}}20MultiplyInheritedSubCACycfc"(ptr
// CHECK-NOT:     _ZN23MultiplyInheritedSharedC2Ev
// CHECK:         call {{.*}}@_ZN23MultiplyInheritedSharedC2Ev(ptr [[SELF:%[0-9]+]])
// CHECK-NEXT:    call void @{{.*}}retainMultiplyInheritedShared{{.*}}(ptr [[SELF]])
// CHECK-NEXT:    call void @[[MI_INIT:__clang_vtable_ptr_init\._ZTS19__SwiftSubclassShimI23MultiplyInheritedShared[^(]*]](ptr [[SELF]])
// CHECK:         ret

// So are the destructors that the v-tables refer to, including the thunk that
// the secondary v-table refers to.
// CHECK: define linkonce_odr void @_ZN19__SwiftSubclassShimI23MultiplyInheritedShared{{.*}}D0Ev(
// CHECK: define linkonce_odr void @_ZThn16_N19__SwiftSubclassShimI23MultiplyInheritedShared{{.*}}D0Ev(

// CHECK:       define linkonce_odr hidden void @[[MI_INIT]](ptr
// CHECK:         [[THIS:%.*]] = load ptr, ptr
// CHECK:         [[PRIMARY:%.*]] = getelementptr inbounds i8, ptr [[THIS]], i64 0
// CHECK-NEXT:    store ptr getelementptr inbounds inrange(-16, 16) ({ [4 x ptr], [5 x ptr] }, ptr @_ZTV19__SwiftSubclassShimI23MultiplyInheritedShared{{.*}}, i32 0, i32 0, i32 2), ptr [[PRIMARY]]
// CHECK-NEXT:    [[SECONDARY:%.*]] = getelementptr inbounds i8, ptr [[THIS]], i64 16
// CHECK-NEXT:    store ptr getelementptr inbounds inrange(-16, 24) ({ [4 x ptr], [5 x ptr] }, ptr @_ZTV19__SwiftSubclassShimI23MultiplyInheritedShared{{.*}}, i32 0, i32 1, i32 2), ptr [[SECONDARY]]
// CHECK-NEXT:    ret void

// The stored properties of a subclass start in the tail padding of the C++
// base, after its 12 bytes of data, and the instance ends at 20 bytes, past the
// 16 bytes of the base. The subclass shim is allocated with room for all of it.
public final class TailPaddedSub: TailPaddedShared {
  public var y: Int32 = 5
  public var z: Int32 = 6
  public init() { super.init() }
}
// CHECK-LABEL: define {{.*}} @"$s{{.*}}13TailPaddedSubCACycfC"(ptr
// CHECK:         call {{.*}} @[[ALLOC:_ZN19__SwiftSubclassShimI16TailPaddedShared.*16__swift_allocateEv]]()
// CHECK:       define linkonce_odr {{.*}} @[[ALLOC]]()
// CHECK:         call {{.*}} @_Znwm(i64 noundef 24)
