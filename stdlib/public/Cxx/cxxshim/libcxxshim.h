/// No-op field-destroy callback for `__SwiftSubclassShim`.
///
/// Used as the `DestroyFields` argument until Swift emits a per-subclass thunk
/// that destroys non-trivially-destructible stored properties. Correct as-is
/// for trivially-destructible fields, which need no cleanup.
inline void __swift_subclassShimDestroyFieldsNoop(void *_Nonnull) {}

/// Backing storage for a Swift class that subclasses a C++ foreign reference
/// type `Base` and adds stored properties.
///
/// A Swift subclass has no Swift metadata; instead the object is a C++ object.
/// This shim derives from `Base` (so retain/release on a `Base*` still hit the
/// foreign reference type's reference count) and appends a raw region of `Size`
/// bytes, aligned to `Align`, that holds the Swift stored properties. Clang
/// emits the record layout, vtable, and destructor variants.
///
/// The shim itself is never constructed. A Swift subclass initializer
/// initializes its stored properties in storage returned by `__swift_allocate`,
/// constructs the `Base` subobject with a constructor of `Base`, and then points
/// the v-table pointers of the object at the v-tables of the shim.
///
/// `Base` must have a virtual destructor (enforced when importing the subclass),
/// so `delete`-ing through a `Base*` dispatches to the shim's overriding
/// destructor. That destructor runs `DestroyFields` — a Swift-emitted function
/// that destroys the subclass's stored properties — before `~Base` runs
/// implicitly. `DestroyFields` receives the object pointer (`this`), so it can
/// address the stored properties at the offsets Swift computes relative to the
/// object; it destroys the Swift fields only, leaving the `Base` subobject for
/// `~Base`. `DestroyFields` is always provided (a no-op when the fields are
/// trivially destructible) so the destruction path is uniform.
template <class Base, unsigned long Size, unsigned long Align,
          void (*DestroyFields)(void *_Nonnull)>
struct __SwiftSubclassShim : Base {
  alignas(Align) char __swiftFields[Size];

  ~__SwiftSubclassShim() override { DestroyFields(this); }

  // Allocate raw, uninitialized storage of the shim's full size (base subobject
  // + Swift fields). The size is computed here in C++, so callers need not know
  // the shim's layout.
  static __SwiftSubclassShim *_Nonnull __swift_allocate() {
    return static_cast<__SwiftSubclassShim *>(
        __builtin_operator_new(sizeof(__SwiftSubclassShim)));
  }
};
