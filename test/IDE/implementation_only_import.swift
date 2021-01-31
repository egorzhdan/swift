// RUN: %empty-directory(%t)

// RUN: %target-swift-frontend(mock-sdk: -F %S/Inputs/mock-sdk) -I %t -emit-module -o %t/ImplOnly.swiftmodule %S/implementation_only_import.swift
// RUN: %target-swift-ide-test(mock-sdk: -F %S/Inputs/mock-sdk) -I %t -print-module -source-filename %s -module-to-print=ImplOnly | %FileCheck %s

@_implementationOnly import FooHelper

// CHECK-NOT: @_implementationOnly import FooHelper
