#if __has_feature(nullability)
_Pragma("clang assume_nonnull begin")
#endif

#define SWIFT_RETURNS_RETAINED __attribute__((swift_attr("returns_retained")))

struct SharedConstructed {
  int refcount = 1;
  int a = 0;
  long b = 0;

  SWIFT_RETURNS_RETAINED SharedConstructed() {}
  SWIFT_RETURNS_RETAINED SharedConstructed(int a) : a(a) {}
  SWIFT_RETURNS_RETAINED SharedConstructed(int a, long b) : a(a), b(b) {}

  int getA() const { return a; }
  long getB() const { return b; }

  virtual ~SharedConstructed() {}
} __attribute__((swift_attr("import_reference")))
__attribute__((swift_attr("retain:retainSharedConstructed")))
__attribute__((swift_attr("release:releaseSharedConstructed")));

inline void retainSharedConstructed(SharedConstructed *t) { ++t->refcount; }
inline void releaseSharedConstructed(SharedConstructed *t) {
  if (--t->refcount <= 0)
    (void)"DELETION PLACEHOLDER";
}

struct DeletableShared {
  int refcount = 1;

  SWIFT_RETURNS_RETAINED DeletableShared() {}
  virtual ~DeletableShared() {}
} __attribute__((swift_attr("import_reference")))
__attribute__((swift_attr("retain:retainDeletableShared")))
__attribute__((swift_attr("release:releaseDeletableShared")));

inline void retainDeletableShared(DeletableShared *t) { ++t->refcount; }
inline void releaseDeletableShared(DeletableShared *t) {
  if (--t->refcount <= 0)
    delete t;
}

#if __has_feature(nullability)
_Pragma("clang assume_nonnull end")
#endif
