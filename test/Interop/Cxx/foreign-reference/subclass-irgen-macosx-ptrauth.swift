// RUN: %swift -emit-ir -module-name SubclassPtrAuth -target arm64e-apple-macosx15.0 -I %S/Inputs -cxx-interoperability-mode=default -Xcc -fignore-exceptions -disable-availability-checking -enable-experimental-feature ForeignReferenceTypeSubclassing %s -parse-as-library | %FileCheck %s

// REQUIRES: CPU=arm64e
// REQUIRES: OS=macosx
// REQUIRES: swift_feature_ForeignReferenceTypeSubclassing

import InheritFRTSubclassing

// With pointer authentication, the v-table pointers of a Swift subclass of a
// C++ foreign reference type are signed the way C++ signs them: with the
// address of the v-table pointer blended with a discriminator of the class
// that introduced it. C++ code authenticates them when it dispatches through
// them, e.g. on `delete`.
public final class MultiplyInheritedSub: MultiplyInheritedShared {
  public let z: Int64 = 3
  public init() { super.init() }
}
// CHECK-LABEL: define {{.*}} @"$s{{.*}}20MultiplyInheritedSubCACycfc"(ptr
// CHECK:         call {{.*}}@_ZN23MultiplyInheritedSharedC2Ev(ptr [[SELF:%[0-9]+]])
// CHECK:         call void @[[INIT:__clang_vtable_ptr_init\._ZTS19__SwiftSubclassShimI23MultiplyInheritedShared[^(]*]](ptr [[SELF]])
// CHECK:         ret

// The v-table pointer at offset 0 is discriminated by `SubclassableShared`,
// the root of its primary base chain, and the one at offset 16 by
// `SecondaryPolymorphic`.
// CHECK:       define linkonce_odr hidden void @[[INIT]](ptr
// CHECK:         [[THIS:%.*]] = load ptr, ptr
// CHECK:         [[PRIMARY:%.*]] = getelementptr inbounds i8, ptr [[THIS]], i64 0
// CHECK-NEXT:    [[PRIMARY_ADDR:%.*]] = ptrtoint ptr [[PRIMARY]] to i64
// CHECK-NEXT:    [[PRIMARY_DISC:%.*]] = call i64 @llvm.ptrauth.blend(i64 [[PRIMARY_ADDR]], i64 16555)
// CHECK-NEXT:    [[PRIMARY_SIGNED:%.*]] = call i64 @llvm.ptrauth.sign(i64 ptrtoint (ptr getelementptr inbounds inrange(-16, 16) ({ [4 x ptr], [5 x ptr] }, ptr @_ZTV19__SwiftSubclassShimI23MultiplyInheritedShared{{.*}}, i32 0, i32 0, i32 2) to i64), i32 2, i64 [[PRIMARY_DISC]])
// CHECK-NEXT:    [[PRIMARY_VPTR:%.*]] = inttoptr i64 [[PRIMARY_SIGNED]] to ptr
// CHECK-NEXT:    store ptr [[PRIMARY_VPTR]], ptr [[PRIMARY]]
// CHECK-NEXT:    [[SECONDARY:%.*]] = getelementptr inbounds i8, ptr [[THIS]], i64 16
// CHECK-NEXT:    [[SECONDARY_ADDR:%.*]] = ptrtoint ptr [[SECONDARY]] to i64
// CHECK-NEXT:    [[SECONDARY_DISC:%.*]] = call i64 @llvm.ptrauth.blend(i64 [[SECONDARY_ADDR]], i64 63745)
// CHECK-NEXT:    [[SECONDARY_SIGNED:%.*]] = call i64 @llvm.ptrauth.sign(i64 ptrtoint (ptr getelementptr inbounds inrange(-16, 24) ({ [4 x ptr], [5 x ptr] }, ptr @_ZTV19__SwiftSubclassShimI23MultiplyInheritedShared{{.*}}, i32 0, i32 1, i32 2) to i64), i32 2, i64 [[SECONDARY_DISC]])
// CHECK-NEXT:    [[SECONDARY_VPTR:%.*]] = inttoptr i64 [[SECONDARY_SIGNED]] to ptr
// CHECK-NEXT:    store ptr [[SECONDARY_VPTR]], ptr [[SECONDARY]]
// CHECK-NEXT:    ret void
