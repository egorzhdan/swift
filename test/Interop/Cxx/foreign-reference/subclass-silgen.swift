// RUN: %target-swift-emit-silgen %s -I %S%{fs-sep}Inputs -cxx-interoperability-mode=default -enable-experimental-feature ForeignReferenceTypeSubclassing -target %target-swift-5.8-abi-triple | %FileCheck %s

// REQUIRES: swift_feature_ForeignReferenceTypeSubclassing

import InheritFRTSubclassing

public final class FieldSub: SharedConstructed {
  public let x: Int64
  public init(x: Int64, a: Int32) {
    self.x = x
    super.init(a)
  }
}

public final class DefaultSub: SubclassableShared {
  public let y: Int64 = 7
}

// Allocation happens in the allocating entry point, and constructs nothing: the
// base subobject is still uninitialized when the initializer body starts.
// CHECK-LABEL: sil{{.*}} @$s{{.*}}8FieldSubC1x1aACs5Int64V_s5Int32VtcfC
// CHECK:         alloc_ref $FieldSub
// CHECK-NOT:     builtin "initializeForeignReferenceSubclass"
// CHECK:         return

// The initializer body stores the Swift stored property first, then constructs
// the base subobject, forwarding the `super.init` argument to it. The builtin
// takes `self` plus the constructor arguments and yields `self` back; storing
// that result is what marks `self` initialized.
// CHECK-LABEL: sil{{.*}} @$s{{.*}}8FieldSubC1x1aACs5Int64V_s5Int32Vtcfc
// CHECK:         ref_element_addr {{.*}} #FieldSub.x
// CHECK:         [[SELF:%.*]] = load [take]
// CHECK:         [[NEW:%.*]] = builtin "initializeForeignReferenceSubclass"<FieldSub>([[SELF]], {{%[0-9]+}}) : $FieldSub
// CHECK:         store [[NEW]] to [init]

// The destroying destructor does not chain to the C++ base's destructor: the
// imported foreign reference type has no Swift deinit, and uses the release
// operation instead.
// CHECK-LABEL: sil{{.*}} @$s{{.*}}8FieldSubCfd
// CHECK-NOT:     function_ref @$s{{.*}}17SharedConstructed
// CHECK:         unchecked_ref_cast
// CHECK:         return

// A synthesized default initializer gets the same treatment.
// CHECK-LABEL: sil{{.*}} @$s{{.*}}10DefaultSubCACycfc
// CHECK:         ref_element_addr {{.*}} #DefaultSub.y
// CHECK:         [[DSELF:%.*]] = load [take]
// CHECK:         [[DNEW:%.*]] = builtin "initializeForeignReferenceSubclass"<DefaultSub>([[DSELF]]) : $DefaultSub
// CHECK:         store [[DNEW]] to [init]
