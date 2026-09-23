public struct NonFrozenStruct {
  public var x: Int
  public init() { x = 0 }
}

@frozen
public struct FrozenStruct {
  public var x: Int
  public init() { x = 0 }
}

public enum NonFrozenEnum {
  case a, b
}

public class ResilientClass {
  public init() {}
}
