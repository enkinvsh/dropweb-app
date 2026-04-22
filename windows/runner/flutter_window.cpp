#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

// Window width is hard-capped at 600 logical px to keep the mobile-first
// layout intact (lib/common/constant.dart maxMobileWidth=600).
//
// Required because:
//   1. window_manager.setMaximumSize() is unreliable on frameless windows
//      (TitleBarStyle.hidden). The plugin's WM_SIZING handler ignores
//      maximum_size_ entirely (only WM_GETMINMAXINFO sets it).
//   2. WM_GETMINMAXINFO is skipped on some Windows 11 borderless windows
//      when WS_CAPTION is cleared — so relying on it alone is flaky.
//
// Belt-and-suspenders approach: hook BOTH messages BEFORE Flutter's plugin
// handler sees them. WM_SIZING is the load-bearing one — it fires on every
// drag-resize tick and lets us mutate the RECT before the size applies.
//
// Both hooks convert logical px → physical px via GetDpiForWindow().
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
  // override our constraint. See file header for rationale.
  if (message == WM_SIZING) {
    // Load-bearing hook: fires during every drag-resize tick. Mutate the
    // proposed RECT so the user can't physically drag the window wider
    // than kMaxLogicalWidth. Which edge to move depends on which handle
    // the user grabbed (wparam = WMSZ_*).
    const UINT dpi = GetDpiForWindow(hwnd);
    const double scale = dpi / 96.0;
    const LONG max_width_physical =
        static_cast<LONG>(kMaxLogicalWidth * scale);
    RECT* rect = reinterpret_cast<RECT*>(lparam);
    const LONG current_width = rect->right - rect->left;
    if (current_width > max_width_physical) {
      switch (wparam) {
        case WMSZ_LEFT:
        case WMSZ_TOPLEFT:
        case WMSZ_BOTTOMLEFT:
          // User dragging left edge — move left edge right.
          rect->left = rect->right - max_width_physical;
          break;
        case WMSZ_RIGHT:
        case WMSZ_TOPRIGHT:
        case WMSZ_BOTTOMRIGHT:
        case WMSZ_TOP:
        case WMSZ_BOTTOM:
        default:
          // User dragging right edge (or top/bottom via corner) — move
          // right edge left.
          rect->right = rect->left + max_width_physical;
          break;
      }
    }
    return TRUE;
  }

  if (message == WM_GETMINMAXINFO) {
    // Fallback for fresh-start sizing + programmatic window moves.
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
