// RUN: %target-build-swift %s
// REQUIRES: OS=windows-msvc

// Make sure that importing WinSDK brings in the GUID type, which is declared in
// /shared and not in /um.

import WinSDK

public func usesGUID(_ x: GUID) {}

// Make sure that IID, which is defined as a typedef for GUID, is imported as a
// wrapper struct.

public func usesIID(_ x: IID)     { usesGUID(x.rawValue) }
public func usesCLSID(_ x: CLSID) { usesGUID(x.rawValue) }

_ = IID()
_ = CLSID()
_ = IID(GUID())
_ = CLSID(GUID())
