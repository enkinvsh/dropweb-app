#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

// Window width is hard-capped at 600 logical px to keep the mobile-first
// layout intact (lib/common/constant.dart maxMobileWidth=600). Flutter's
// window_manager.setMaximumSize is unreliable on frameless windows
// (TitleBarStyle.hidden + custom title bar) — Win32 message dispatch races
// the plugin handler. Hooking WM_GETMINMAXINFO directly in the runner —
// BEFORE flutter_controller_->HandleTopLevelWindowProc — is the canonical
// fix and works regardless of plugin order.
//
// WM_GETMINMAXINFO uses physical pixels — multiply logical by DPI scale.
namespace {
constexpr int kMaxLogicalWidth = 600;
constexpr int kMinLogicalWidth = 380;
constexpr int kMinLogicalHeight = 400;
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

  flutter_controller_->engine()->SetNextFrameCallback([&]() {

  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
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
  // Hard width cap — handled BEFORE Flutter plugins so window_manager can't
  // override our constraint. See file header comment for rationale.
  if (message == WM_GETMINMAXINFO) {
    const UINT dpi = GetDpiForWindow(hwnd);
    const double scale = dpi / 96.0;
    MINMAXINFO* mmi = reinterpret_cast<MINMAXINFO*>(lparam);
    mmi->ptMaxTrackSize.x = static_cast<LONG>(kMaxLogicalWidth * scale);
    mmi->ptMinTrackSize.x = static_cast<LONG>(kMinLogicalWidth * scale);
    mmi->ptMinTrackSize.y = static_cast<LONG>(kMinLogicalHeight * scale);
    return 0;
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
