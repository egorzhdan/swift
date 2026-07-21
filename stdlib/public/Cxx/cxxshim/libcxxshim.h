// Declared here rather than by including <new> so this shim header does not
// pull in the C++ standard library. This is the standard placement-new
// operator; the compiler recognizes it and emits no call (it simply yields the
// pointer). Raw (de)allocation uses the `__builtin_operator_new`/`delete`
// intrinsics, which likewise avoid <new>.
void *_Nonnull operator new(__SIZE_TYPE__, void *_Nonnull) noexcept;

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

  // Inherit `Base`'s constructors so the shim can be placement-constructed with
  // the same arguments as the foreign reference type.
  using Base::Base;

  ~__SwiftSubclassShim() override { DestroyFields(this); }

  // Allocate raw, uninitialized storage of the shim's full size (base subobject
  // + Swift fields). The `Base` subobject is *not* constructed yet: a Swift
  // subclass initializer establishes `self` from this, initializes its stored
  // properties into `__swiftFields`, and then constructs the base in place via
  // `super.init` (see `__swift_constructBase`). The size is computed here in
  // C++, so callers need not know the shim's layout.
  static __SwiftSubclassShim *_Nonnull __swift_allocate() {
    return static_cast<__SwiftSubclassShim *>(
        __builtin_operator_new(sizeof(__SwiftSubclassShim)));
  }

  // Placement-construct the `Base` subobject (and set the shim's vtable) into
  // storage returned by `__swift_allocate`, without disturbing `__swiftFields`.
  // Deletion through a `Base *` (via the FRT's release) then dispatches to
  // `~__SwiftSubclassShim`. This overload handles the no-argument base
  // constructor; the templated overload below forwards constructor arguments.
  static void __swift_constructBase(__SwiftSubclassShim *_Nonnull storage) {
    // Default-initialization (no `()`): constructs the `Base` subobject and sets
    // the vtable, but leaves `__swiftFields` untouched. Value-initialization
    // (`()`) would zero `__swiftFields`, clobbering stored properties that the
    // Swift initializer wrote before calling `super.init`.
    ::new (static_cast<void *>(storage)) __SwiftSubclassShim;
  }

  // Placement-construct the `Base` subobject with the given constructor
  // arguments, forwarding them to an inherited `Base` constructor (see
  // `using Base::Base` above). C++ overload resolution selects the matching
  // base constructor. Direct-initialization (with `(args...)`) does not zero
  // `__swiftFields`, so stored properties written before `super.init` survive.
  // The zero-argument call resolves to the default-initializing overload above
  // (a non-template overload is preferred over this template), so this is only
  // ever instantiated with a non-empty argument pack.
  template <class... Args>
  static void __swift_constructBase(__SwiftSubclassShim *_Nonnull storage,
                                    Args... args) {
    ::new (static_cast<void *>(storage))
        __SwiftSubclassShim(static_cast<Args &&>(args)...);
  }
};
