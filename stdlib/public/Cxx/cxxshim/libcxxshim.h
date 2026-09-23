/// No-op field-destroy callback for `__SwiftSubclassShim`.
inline void __swift_subclassShimDestroyFieldsNoop(void *_Nonnull) {}

/// Backing storage for a Swift class that subclasses a C++ foreign reference
/// type `Base` and adds stored properties.
template <class Base, unsigned long Size, unsigned long Align,
          void (*DestroyFields)(void *_Nonnull)>
struct __SwiftSubclassShim : Base {
  alignas(Align) char __swiftFields[Size];

  // Base must have a virtual destructor.
  ~__SwiftSubclassShim() override { DestroyFields(this); }

  static __SwiftSubclassShim *_Nonnull __swift_allocate() {
    return static_cast<__SwiftSubclassShim *>(
        __builtin_operator_new(sizeof(__SwiftSubclassShim)));
  }
};
