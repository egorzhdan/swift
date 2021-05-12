#include "non-member-out-of-line.h"

LoadableIntWrapper operator+(LoadableIntWrapper lhs, LoadableIntWrapper rhs) {
  return LoadableIntWrapper{.value = lhs.value + rhs.value};
}

bool operator==(LoadableIntWrapper lhs, LoadableIntWrapper rhs) {
  return lhs.value == rhs.value;
}
