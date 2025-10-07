import WinSDK
import WinRT
import WindowsUI
import CxxStdlib

extension Array where Array.Element == WCHAR {
  init(_ string: String) {
    self = string.withCString(encodedAs: UTF16.self) { buffer in
      Array<WCHAR>(unsafeUninitializedCapacity: string.utf16.count + 1) {
        wcscpy_s($0.baseAddress, $0.count, buffer)
        $1 = $0.count
      }
    }
  }
}

extension IID {
  init?(_ s: String) {
    let wchars = [WCHAR](s)
    var iid = IID()
    guard IIDFromString(wchars, &iid) == S_OK else {
      return nil
    }
    self = iid
  }
}

guard RoInitialize(RO_INIT_MULTITHREADED) == S_OK else {
  fatalError("did not init WinRT")
}

let hInstance = GetModuleHandleW(nil)

SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)

let windowClassName = [WCHAR]("My Window")
var windowClass = WNDCLASSEXW()
windowClass.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
windowClass.hInstance = hInstance
windowClassName.withUnsafeBufferPointer {
  windowClass.lpszClassName = $0.baseAddress!
}
windowClass.lpfnWndProc = { hWnd, message, wParam, lParam in
  switch message {
  case UINT(WM_PAINT):
    break
  case UINT(WM_DESTROY):
    PostQuitMessage(0)
    break
  default:
    return DefWindowProcW(hWnd, message, wParam, lParam)
  }
  return 0
}

guard RegisterClassExW(&windowClass) != 0 else {
  fatalError("failed to register!")
}

guard let hWnd = CreateWindowExW(0, windowClassName, nil,
                         WS_OVERLAPPEDWINDOW | UINT(WS_VISIBLE),
                         CW_USEDEFAULT, CW_USEDEFAULT,
                         1500, 1500, nil, nil, hInstance, nil) else {
  fatalError("failed to create window!")
}

extension HSTRING {
  public init(_ s: String) {
    let wchars = [WCHAR](s)
    var result: HSTRING!
    guard WindowsCreateString(wchars, UINT32(wchars.count) - 1, &result) == S_OK else {
      fatalError("failed to create hstring")
    }
    self = result
  }
}

/// Any COM type.
protocol IUnknownProtocol {
  func QueryInterface(_ iid: IID, _ outPtr: UnsafeMutablePointer<UnsafeMutableRawPointer?>!) -> HRESULT
  
  static var iid: IID { get }
}

typealias WinUI = ABI.Windows.UI.Xaml

/// Modern COM type, uses RoActivation API for initialization.
protocol IInspectableProtocol : IUnknownProtocol { }

extension IInspectable : IInspectableProtocol {
  static let iid: IID = .init("{AF86E2E0-B12D-4c6a-9C5A-D7AA65101E90}")!
}
extension ABI.Windows.Foundation.IPropertyValueStatics : IInspectableProtocol {
  static let iid: IID = .init("{629bdbc8-d932-4ff4-96b9-8d96c5c1e858}")!
}
extension WinUI.Hosting.IDesktopWindowXamlSource : IInspectableProtocol {
  static let iid: IID = .init("{d585bfe1-00ff-51be-ba1d-a1329956ea0a}")!
}
extension WinUI.IFrameworkElement : IInspectableProtocol {
  static let iid: IID = .init("{a391d09b-4a99-4b7c-9d8d-6fa5d01f6fbf}")!
}
extension WinUI.Controls.ITextBlock : IInspectableProtocol {
  static let iid: IID = .init("{ae2d9271-3b4a-45fc-8468-f7949548f4d5}")!
}
extension WinUI.Controls.IContentControl : IInspectableProtocol {
  static let iid: IID = .init("{a26dd1dc-cd44-435c-be94-01d6241c231c}")!
}
extension WinUI.Controls.ITextBox : IInspectableProtocol {
  static let iid: IID = .init("{e48f5a8b-1dff-4352-a1f4-e516514ec882}")!
}
extension WinUI.Controls.IButton : IInspectableProtocol {
  static let iid: IID = .init("{280335ae-5570-46c7-8e0b-602be71229a2}")!
}
extension WinUI.Controls.IStackPanel : IInspectableProtocol {
  static let iid: IID = .init("{b8ae8fe2-d641-4fd7-80b4-7439207d2798}")!
}
extension WinUI.Controls.IStackPanel2 : IInspectableProtocol {
  static let iid: IID = .init("{36f23359-040e-48f7-9a98-f2664591959c}")!
}
extension WinUI.Controls.IStackPanel4 : IInspectableProtocol {
  static let iid: IID = .init("{43ebf7f6-3196-412e-8a95-add002ff43f0}")!
}
extension WinUI.Controls.IPanel : IInspectableProtocol {
  static let iid: IID = .init("{a50a4bbd-8361-469c-90da-e9a40c7474df}")!
}
extension WinUI.Controls.IProgressBar : IInspectableProtocol {
  static let iid: IID = .init("{ae752c89-0067-4963-bf4c-29db0c4a507e}")!
}
extension WinUI.IUIElement : IInspectableProtocol {
  static let iid: IID = .init("{676d0be9-b65c-41c6-ba40-58cf87f201c1}")!
}
extension WinUI.Hosting.IWindowsXamlManager : IInspectableProtocol {
  static let iid: IID = .init("{56096c31-1aa0-5288-8818-6e74a2dcaff5}")!
}
extension WinUI.Hosting.IWindowsXamlManagerStatics : IInspectableProtocol {
  static let iid: IID = .init("{28258a12-7d82-505b-b210-712b04a58882}")!
}
extension IDesktopWindowXamlSourceNative : IUnknownProtocol {
  static let iid: IID = .init("{3cbcf1bf-2f76-4e9c-96ab-e84b37972554}")!
}

extension IUnknownProtocol {
  func cast<ToType: IUnknownProtocol>(_ as: ToType.Type) -> ToType? {
    var rawResult: UnsafeMutableRawPointer? = nil
    guard self.QueryInterface(ToType.iid, &rawResult) == S_OK else {
      return nil
    }
    return unsafeBitCast(rawResult!, to: ToType.self)
  }
}

extension IInspectableProtocol {
  init?(className: String) {
    let classNameHS = HSTRING(className)
    var inspectable: IInspectable!
    let err = RoActivateInstance(classNameHS, &inspectable)
    guard err == S_OK else {
      return nil
    }
    guard let result = inspectable.cast(Self.self) else {
      return nil
    }
    self = result
  }

  init?(factoryClassName: String) {
    let classNameHS = HSTRING(factoryClassName)
    var rawPtr: UnsafeMutableRawPointer? = nil
    let err = RoGetActivationFactory(classNameHS, Self.iid, &rawPtr)
    guard err == S_OK else {
      fatalError()
    }
    self = unsafeBitCast(rawPtr!, to: Self.self)
  }
}


let statics = WinUI.Hosting.IWindowsXamlManagerStatics(factoryClassName: "Windows.UI.Xaml.Hosting.WindowsXamlManager")!

var manager: WinUI.Hosting.IWindowsXamlManager!
statics.InitializeForCurrentThread(&manager)

let desktopSource = WinUI.Hosting.IDesktopWindowXamlSource(className: "Windows.UI.Xaml.Hosting.DesktopWindowXamlSource")!


let textBlock = WinUI.Controls.ITextBlock(className: "Windows.UI.Xaml.Controls.TextBlock")!
textBlock.put_Text(HSTRING("Hello from Swift!"))
textBlock.put_FontSize(40)

let textBox = WinUI.Controls.ITextBox(className: "Windows.UI.Xaml.Controls.TextBox")!
textBox.put_Text(HSTRING("some text here"))
textBox.cast(WinUI.IFrameworkElement.self)!.put_Width(500)

let progressBar = WinUI.Controls.IProgressBar(className: "Windows.UI.Xaml.Controls.ProgressBar")!
progressBar.put_IsIndeterminate(1)
progressBar.cast(WinUI.IFrameworkElement.self)!.put_Width(500)

let button = WinUI.Controls.IButton(className: "Windows.UI.Xaml.Controls.Button")!
var buttonLabel: IInspectable!
let propStatics = ABI.Windows.Foundation.IPropertyValueStatics(factoryClassName: "Windows.Foundation.PropertyValue")!
propStatics.CreateString(HSTRING("Click me!"), &buttonLabel)
button.cast(WinUI.Controls.IContentControl.self)!.put_Content(buttonLabel)

let stackPanel = WinUI.Controls.IStackPanel(className: "Windows.UI.Xaml.Controls.StackPanel")!
let thickness = WinUI.Thickness(Left: 30, Top: 10, Right: 30, Bottom: 10)
stackPanel.cast(WinUI.Controls.IStackPanel2.self)!.put_Padding(thickness)
stackPanel.cast(WinUI.Controls.IStackPanel4.self)!.put_Spacing(20)

let panel = stackPanel.cast(WinUI.Controls.IPanel.self)!

var panelElements: ABI.Windows.Foundation.Collections.__FIVector_1_Windows__CUI__CXaml__CUIElement_t!
panel.get_Children(&panelElements)
panelElements.Append(textBlock.cast(WinUI.IUIElement.self)!)
panelElements.Append(textBox.cast(WinUI.IUIElement.self)!)
panelElements.Append(progressBar.cast(WinUI.IUIElement.self)!)
panelElements.Append(button.cast(WinUI.IUIElement.self)!)

desktopSource.put_Content(panel.cast(WinUI.IUIElement.self)!)


let sourceNative = desktopSource.cast(IDesktopWindowXamlSourceNative.self)!
sourceNative.AttachToWindow(hWnd)

var hWndXamlIsland: HWND? = nil
sourceNative.get_WindowHandle(&hWndXamlIsland)

SetWindowPos(hWndXamlIsland, nil, 0, 0, 1500, 1500, UINT(SWP_SHOWWINDOW))

ShowWindow(hWnd, SW_SHOW)
UpdateWindow(hWnd)
UpdateWindow(hWndXamlIsland)

print("message loop...")

var msg = MSG()
while GetMessageW(&msg, nil, 0, 0) {
  if msg.message == WM_QUIT {
    break
  }
  TranslateMessage(&msg)
  DispatchMessageW(&msg)
}

withExtendedLifetime(sourceNative) {}
withExtendedLifetime(desktopSource) {}
withExtendedLifetime(textBox) {}
withExtendedLifetime(textBlock) {}

RoUninitialize()
print("Done!")
