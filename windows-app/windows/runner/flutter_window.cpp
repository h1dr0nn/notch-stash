#include "flutter_window.h"

#include <dwmapi.h>

#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {

// The compositor draws a window's shadow only while its frame reaches into the client area, which
// here is the whole window; one pixel at the top is enough and stays under the content.
void ExtendFrameForShadow(HWND hwnd) {
  const MARGINS margins = {0, 0, 1, 0};
  DwmExtendFrameIntoClientArea(hwnd, &margins);
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  ExtendFrameForShadow(GetHandle());

  // Notch Stash lives in the tray: the window stays hidden until the Dart side
  // shows the shelf or Settings, so the first frame does not show it.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // The window has no title bar or border of its own, yet keeps the caption styles and lets the
  // desktop compositor draw its frame: that frame brings the shadow and rounded corners and is never
  // painted over the content. Here the content takes the whole window, so only the shadow and the
  // thin Windows 11 border show. (A frameless window without the compositor, window_manager's
  // setFrameless, gets the classic frame painted over it on every activation change instead.)
  switch (message) {
    case WM_NCCALCSIZE:
      // The client area keeps the whole window rectangle.
      return 0;
    case WM_DWMCOMPOSITIONCHANGED:
      ExtendFrameForShadow(hwnd);
      break;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
