# Research: NotchDrop and DropPoint

## NotchDrop (MIT, ~2k dòng Swift, AppKit + SwiftUI)
- Window: 1 `NSWindow` borderless trong suốt, rộng cả màn hình × cao 200pt ở đỉnh, `level = .statusBar + 8`,
  `collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]` (`NotchWindow.swift`).
- Kích thước notch: `NSScreen.safeAreaInsets.top` + `auxiliaryTopLeftArea/RightArea` (`Ext+NSScreen.swift`). Dùng lại được.
- Hover/click: `NSEvent.addGlobalMonitorForEvents` cho mouseMoved/leftMouseDown (`EventMonitors.swift`).
  Hover vào notch → trạng thái "popping" (phình nhẹ + haptic), phải CLICK mới mở. Kéo file vào vùng notch (+32pt) → tự mở.
- Click bất kỳ chỗ nào ngoài panel → đóng (`NotchViewModel+Events.swift`). => chuyển cửa sổ là panel đóng.
- Lưu file: COPY vào `~/Documents/CopiedItems/<uuid>/` (sandbox container), giữ mặc định 1 ngày.
- Kéo ra: SwiftUI `.draggable` + `Transferable` `FileRepresentation(contentType: .data)`, copy thêm 1 lần vào temp.
  => chỉ kéo từng file, luôn là copy, nhiều app/Finder nhận kém (#62, #72 "không move được ra thư mục", #48 WeChat hiện path).
- Màn hình: `findScreenFitsOurNeeds()` chỉ tạo 1 window trên màn built-in có notch, fallback `.main`.
  => màn hình ngoài không có shelf (issue #9 chỉ fix bằng cách chọn built-in screen).
- Issue #37/#64: file trên Desktop "biến mất" khi NotchDrop chạy (nghi do window trong suốt full-width phủ đỉnh màn hình).
- Không có phím tắt toàn cục.

## DropPoint (GPL-3.0, Electron) — chỉ học hành vi
- Phím tắt mặc định trên mac: Shift+Tab; chế độ toggle (mở/đóng) hoặc spawn (mỗi lần 1 ô mới).
- Ô 200×200, alwaysOnTop, visibleOnAllWorkspaces; tuỳ chọn mở tại vị trí con trỏ.
- Giữ ĐƯỜNG DẪN (tham chiếu), không copy. Kéo ra = kéo cả cụm file một lần (`startDrag` với list path), xong tự đóng ô.
