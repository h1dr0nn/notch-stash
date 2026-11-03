# notch-stash — Spec

Menu bar app (LSUIElement), AppKit (NSPanel, drag/drop) + SwiftUI (nội dung). Dùng lại được code NotchDrop (MIT, ghi nguồn) cho phần đo notch / vẽ hình notch; KHÔNG chép code DropPoint (GPL).

## Mở shelf
- Màn built-in có notch: rê chuột vào notch → mở ngay (không cần click); đang kéo file lại gần notch → tự mở.
- Màn ngoài (không notch): KHÔNG có vùng ở đỉnh. Dùng panel nổi xuất hiện cạnh con trỏ (kiểu DropPoint).
- Phím tắt: chạm ⌃ (Control) hai lần nhanh → toggle panel nổi cạnh con trỏ.
  Cần quyền Input Monitoring (CGEventTap listen-only / global flagsChanged); hướng dẫn cấp quyền lần đầu.
- Hai dạng hiển thị dùng CHUNG một danh sách file.

## Giữ shelf
- Shelf ở notch mở do hover/kéo file sẽ thu về notch khi chuột rời đi (file vẫn giữ).
- ⌃⌃ luôn bật/tắt panel nổi cạnh con trỏ (mọi màn hình); panel nổi hiện thì shelf ở notch tự đóng.
- Không đóng khi click ra ngoài / chuyển cửa sổ / Space (khác NotchDrop). canJoinAllSpaces + fullScreenAuxiliary, non-activating.
- Đóng khi: chạm ⌃⌃ lần nữa, nút ×, hoặc shelf trống.

## File
- Giữ tham chiếu (URL/bookmark), không copy. File gốc mất → item tự biến khỏi shelf.
- Kéo ra bằng NSDraggingSession với file URL thật (NSURL pasteboard) → Finder/Slack/Chrome nhận đúng, hỗ trợ Move/Copy.
- Kéo từng file hoặc "kéo tất cả".
- Sau khi kéo ra thành công: xoá item khỏi shelf; shelf trống thì tự đóng. Giữ ⌥ khi kéo để giữ lại.
- Click item → Quick Look. Có xoá từng item / xoá hết.

## Để sau
Nhóm file, lắc chuột khi kéo để gọi shelf, AirDrop/Share, giữ shelf qua restart, đổi phím tắt trong Settings, nhận text/ảnh chụp.
