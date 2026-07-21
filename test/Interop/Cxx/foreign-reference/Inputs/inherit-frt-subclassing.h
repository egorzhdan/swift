#if __has_feature(nullability)
_Pragma("clang assume_nonnull begin")
#endif

#define SWIFT_SHARED_REFERENCE(_retain, _release)                              \
  __attribute__((swift_attr("import_reference")))                              \
  __attribute__((swift_attr("retain:" #_retain)))                              \
  __attribute__((swift_attr("release:" #_release)))

#define SWIFT_RETURNS_RETAINED __attribute__((swift_attr("returns_retained")))

struct SubclassableShared {
  int refcount = 1;
  int payload = 0;

  int get() const { return payload; }
  void set(int x) { payload = x; }

  virtual ~SubclassableShared() {}
} SWIFT_SHARED_REFERENCE(retainSubclassableShared, releaseSubclassableShared);

inline void retainSubclassableShared(SubclassableShared *t) { ++t->refcount; }
inline void releaseSubclassableShared(SubclassableShared *t) {
  if (--t->refcount <= 0)
    delete t;
}

struct DerivedSubclassableShared : SubclassableShared {};

struct DerivedOwnRefcountShared : SubclassableShared {
} SWIFT_SHARED_REFERENCE(retainDerivedOwnRefcountShared,
                         releaseDerivedOwnRefcountShared);

inline void retainDerivedOwnRefcountShared(DerivedOwnRefcountShared *t) {
  ++t->refcount;
}
inline void releaseDerivedOwnRefcountShared(DerivedOwnRefcountShared *t) {
  if (--t->refcount <= 0)
    delete t;
}

struct NonVirtualShared {
  int refcount = 1;
} SWIFT_SHARED_REFERENCE(retainNonVirtualShared, releaseNonVirtualShared);

inline void retainNonVirtualShared(NonVirtualShared *t) { ++t->refcount; }
inline void releaseNonVirtualShared(NonVirtualShared *t) {
  if (--t->refcount <= 0)
    (void)"DELETION PLACEHOLDER";
}

struct FinalShared final {
  int refcount = 1;

  virtual ~FinalShared() {}
} SWIFT_SHARED_REFERENCE(retainFinalShared, releaseFinalShared);

inline void retainFinalShared(FinalShared *t) { ++t->refcount; }
inline void releaseFinalShared(FinalShared *t) {
  if (--t->refcount <= 0)
    delete t;
}

struct PrivateDtorShared {
  int refcount = 1;

  friend void releasePrivateDtorShared(PrivateDtorShared *t);

private:
  virtual ~PrivateDtorShared() {}
} SWIFT_SHARED_REFERENCE(retainPrivateDtorShared, releasePrivateDtorShared);

inline void retainPrivateDtorShared(PrivateDtorShared *t) { ++t->refcount; }
inline void releasePrivateDtorShared(PrivateDtorShared *t) {
  if (--t->refcount <= 0)
    delete t;
}

struct ProtectedDtorShared {
  int refcount = 1;

  friend void releaseProtectedDtorShared(ProtectedDtorShared *t);

protected:
  virtual ~ProtectedDtorShared() {}
} SWIFT_SHARED_REFERENCE(retainProtectedDtorShared, releaseProtectedDtorShared);

inline void retainProtectedDtorShared(ProtectedDtorShared *t) { ++t->refcount; }
inline void releaseProtectedDtorShared(ProtectedDtorShared *t) {
  if (--t->refcount <= 0)
    delete t;
}

struct DeletedDtorShared {
  int refcount = 1;

  virtual ~DeletedDtorShared() = delete;
} SWIFT_SHARED_REFERENCE(retainDeletedDtorShared, releaseDeletedDtorShared);

inline void retainDeletedDtorShared(DeletedDtorShared *t) { ++t->refcount; }
inline void releaseDeletedDtorShared(DeletedDtorShared *t) {
  if (--t->refcount <= 0)
    (void)"DELETION PLACEHOLDER";
}

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
} SWIFT_SHARED_REFERENCE(retainSharedConstructed, releaseSharedConstructed);

inline void retainSharedConstructed(SharedConstructed *t) { ++t->refcount; }
inline void releaseSharedConstructed(SharedConstructed *t) {
  if (--t->refcount <= 0)
    delete t;
}

struct ArgOnlyConstructed {
  int refcount = 1;
  int a = 0;

  SWIFT_RETURNS_RETAINED ArgOnlyConstructed(int a) : a(a) {}

  virtual ~ArgOnlyConstructed() {}
} SWIFT_SHARED_REFERENCE(retainArgOnlyConstructed, releaseArgOnlyConstructed);

inline void retainArgOnlyConstructed(ArgOnlyConstructed *t) { ++t->refcount; }
inline void releaseArgOnlyConstructed(ArgOnlyConstructed *t) {
  if (--t->refcount <= 0)
    delete t;
}

inline int &liveNonTrivialArgs() {
  static int count = 0;
  return count;
}
inline int getLiveNonTrivialArgs() { return liveNonTrivialArgs(); }

struct NonTrivialArg {
  int value;

  NonTrivialArg(int value) : value(value) { ++liveNonTrivialArgs(); }
  NonTrivialArg(const NonTrivialArg &other) : value(other.value) {
    ++liveNonTrivialArgs();
  }
  ~NonTrivialArg() { --liveNonTrivialArgs(); }
};

struct RefcountedArg {
  int refcount = 1;
  int value = 0;

  SWIFT_RETURNS_RETAINED RefcountedArg(int value) : value(value) {}

  int getRefcount() const { return refcount; }

  virtual ~RefcountedArg() {}
} SWIFT_SHARED_REFERENCE(retainRefcountedArg, releaseRefcountedArg);

inline void retainRefcountedArg(RefcountedArg *t) { ++t->refcount; }
inline void releaseRefcountedArg(RefcountedArg *t) {
  if (--t->refcount <= 0)
    delete t;
}

// A base with constructors taking their parameters in each of the ways a C++
// constructor can. The trailing parameters only tell the overloads apart.
struct ReferenceConstructed {
  int refcount = 1;
  int seen = 0;

  SWIFT_RETURNS_RETAINED ReferenceConstructed(const int &i) : seen(i) {}
  SWIFT_RETURNS_RETAINED ReferenceConstructed(int &i, int) : seen(i) {
    i = 100;
  }
  SWIFT_RETURNS_RETAINED ReferenceConstructed(NonTrivialArg arg, long)
      : seen(arg.value) {}
  SWIFT_RETURNS_RETAINED ReferenceConstructed(const NonTrivialArg &arg, char)
      : seen(arg.value) {}
  SWIFT_RETURNS_RETAINED ReferenceConstructed(RefcountedArg *arg, short)
      : seen(arg->value) {}

  int getSeen() const { return seen; }

  virtual ~ReferenceConstructed() {}
} SWIFT_SHARED_REFERENCE(retainReferenceConstructed,
                         releaseReferenceConstructed);

inline void retainReferenceConstructed(ReferenceConstructed *t) {
  ++t->refcount;
}
inline void releaseReferenceConstructed(ReferenceConstructed *t) {
  if (--t->refcount <= 0)
    delete t;
}

struct OverloadedConstructed {
  int refcount = 1;
  int which = 0;

  SWIFT_RETURNS_RETAINED OverloadedConstructed(int) : which(1) {}
  SWIFT_RETURNS_RETAINED OverloadedConstructed(double) : which(2) {}

  int getWhich() const { return which; }

  virtual ~OverloadedConstructed() {}
} SWIFT_SHARED_REFERENCE(retainOverloadedConstructed,
                         releaseOverloadedConstructed);

inline void retainOverloadedConstructed(OverloadedConstructed *t) {
  ++t->refcount;
}
inline void releaseOverloadedConstructed(OverloadedConstructed *t) {
  if (--t->refcount <= 0)
    delete t;
}

// A base that keeps the reference it is constructed with.
struct KeepsReference {
  int refcount = 1;
  const int *reference = nullptr;

  SWIFT_RETURNS_RETAINED KeepsReference(const int &i) : reference(&i) {}

  int read() const { return *reference; }

  // Whether the kept reference points into this object itself, i.e. at a stored
  // property of the Swift subclass rather than at a temporary.
  bool refersIntoSelf() const {
    auto ref = reinterpret_cast<const char *>(reference);
    auto self = reinterpret_cast<const char *>(this);
    return ref >= self && ref < self + 256;
  }

  virtual ~KeepsReference() {}
} SWIFT_SHARED_REFERENCE(retainKeepsReference, releaseKeepsReference);

inline void retainKeepsReference(KeepsReference *t) { ++t->refcount; }
inline void releaseKeepsReference(KeepsReference *t) {
  if (--t->refcount <= 0)
    delete t;
}

// A static factory method imported as an initializer. Since the type declares
// one, ClangImporter does not import its C++ constructor as an initializer.
struct SharedWithFactory {
  int refcount = 1;
  int a = 0;

  SharedWithFactory() {}

  static SharedWithFactory *make(int a) SWIFT_RETURNS_RETAINED // expected-note {{'init(value:)' is imported from a C++ static factory method here}}
      __attribute__((swift_name("init(value:)")));

  virtual ~SharedWithFactory() {}
} SWIFT_SHARED_REFERENCE(retainSharedWithFactory, releaseSharedWithFactory);

inline SharedWithFactory *SharedWithFactory::make(int a) {
  auto result = new SharedWithFactory();
  result->a = a;
  return result;
}

inline void retainSharedWithFactory(SharedWithFactory *t) { ++t->refcount; }
inline void releaseSharedWithFactory(SharedWithFactory *t) {
  if (--t->refcount <= 0)
    delete t;
}

// A static factory method imported as a no-argument initializer.
struct SharedWithFactoryOnly {
  int refcount = 1;

  static SharedWithFactoryOnly *create() SWIFT_RETURNS_RETAINED // expected-note 2 {{'init()' is imported from a C++ static factory method here}}
      __attribute__((swift_name("init()")));

  virtual ~SharedWithFactoryOnly() {}

protected:
  SharedWithFactoryOnly() {}
} SWIFT_SHARED_REFERENCE(retainSharedWithFactoryOnly,
                         releaseSharedWithFactoryOnly);

inline SharedWithFactoryOnly *SharedWithFactoryOnly::create() {
  return new SharedWithFactoryOnly();
}

inline void retainSharedWithFactoryOnly(SharedWithFactoryOnly *t) {
  ++t->refcount;
}
inline void releaseSharedWithFactoryOnly(SharedWithFactoryOnly *t) {
  if (--t->refcount <= 0)
    delete t;
}

#if __has_feature(nullability)
_Pragma("clang assume_nonnull end")
#endif
