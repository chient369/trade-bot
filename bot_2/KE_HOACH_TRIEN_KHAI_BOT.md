# Kế Hoạch Triển Khai Bot Giao Dịch (EA)

Đây là lộ trình chi tiết để phát triển, kiểm thử và triển khai Expert Advisor dựa trên "Chiến Lược Giao Dịch Tổng Hợp".

---

## Giai Đoạn 1: Phát Triển Logic Cốt Lõi (MQL5 Development)

*Mục tiêu: Xây dựng bộ khung và các logic chính của EA.*

- **Task 1.1: Thiết Lập Cấu Trúc Dự Án**
    - Tạo file `XAUUSD_Hybrid_Bot.mq5`.
    - Tạo các file `#include` riêng cho từng module (ví dụ: `MoneyManagement.mqh`, `TrendModule.mqh`, `RangeModule.mqh`) để code sạch sẽ, dễ quản lý.

- **Task 1.2: Xây Dựng Các Tham Số Đầu Vào (`input`)**
    - Tạo tất cả các biến số có thể tùy chỉnh làm `input` để tiện cho việc tối ưu hóa sau này.
    - Ví dụ: `MagicNumber`, `Risk_Percentage`, `Take_Profit_RR`, `Stop_Loss_RR`, các thông số của chỉ báo (EMA, ADX, RSI, BB).

- **Task 1.3: Lập Trình Module Phân Tích (H4)**
    - Viết một hàm `GetMarketCondition()` trả về một giá trị `enum` (ví dụ: `TREND_UP`, `TREND_DOWN`, `RANGING`).
    - Hàm này sẽ sử dụng các hàm `iMA()`, `iADX()` trên khung thời gian `PERIOD_H4`.
    - Biến lưu trạng thái thị trường cần được duy trì cho đến khi nến H4 mới xuất hiện.

- **Task 1.4: Lập Trình Module Giao Dịch (M15)**
    - Viết hàm `CheckTrendSignal()` để tìm tín hiệu MA Crossover.
    - Viết hàm `CheckRangeSignal()` để tìm tín hiệu Bollinger Bands + RSI.

- **Task 1.5: Lập Trình Module Quản Lý Vốn & Giao Dịch**
    - Viết hàm `CalculateLotSize(double stopLossPips)` để tính khối lượng lệnh dựa vào `%` rủi ro.
    - Viết các hàm `OpenTrade()` và `CloseTrade()` để thực thi lệnh.

- **Task 1.6: Kết Hợp Logic trong `OnTick()`**
    - Trong hàm `OnTick()`, đầu tiên kiểm tra xem có nến H4 mới không để gọi `GetMarketCondition()`.
    - Dựa vào trạng thái thị trường đã lưu, gọi hàm `CheckTrendSignal()` hoặc `CheckRangeSignal()`.
    - Nếu có tín hiệu, kiểm tra điều kiện không có lệnh nào đang mở, sau đó tính toán SL, TP, Lot Size và vào lệnh.

---

## Giai Đoạn 2: Kiểm Thử Lịch Sử & Tối Ưu Hóa (Backtesting)

*Mục tiêu: Đánh giá hiệu quả của EA trên dữ liệu quá khứ và tìm ra bộ tham số tối ưu.*

- **Task 2.1: Chuẩn Bị Dữ Liệu**
    - Tải dữ liệu lịch sử chất lượng cao cho XAUUSD, khung M1, từ một nguồn uy tín.

- **Task 2.2: Backtest Sơ Bộ**
    - Chạy EA trong `Strategy Tester` của MT5 với các tham số mặc định trên một khoảng thời gian dài (tối thiểu 3 năm).
    - Sử dụng chế độ "Every tick based on real ticks" để có kết quả chính xác nhất.
    - Mục đích: Đảm bảo EA hoạt động không có lỗi logic, các lệnh được mở và đóng đúng như thiết kế.

- **Task 2.3: Tối Ưu Hóa (Optimization)**
    - Xác định các tham số quan trọng nhất để tối ưu hóa (ví dụ: ngưỡng ADX, tỷ lệ R:R, các chu kỳ của chỉ báo).
    - Chạy quá trình tối ưu hóa trên MT5. **Cảnh báo:** Tránh "tối ưu hóa quá mức" (over-fitting). Thay vì chọn kết quả có lợi nhuận cao nhất, hãy tìm vùng tham số ổn định, cho kết quả tốt trên nhiều điều kiện khác nhau.

- **Task 2.4: Phân Tích Đi bộ (Walk-Forward Analysis)**
    - Đây là bước nâng cao để kiểm tra sự bền vững. Tối ưu hóa EA trên 2 năm dữ liệu, sau đó chạy thử nghiệm với bộ số tối ưu đó trên 1 năm dữ liệu "vô hình" (out-of-sample) tiếp theo. Lặp lại quá trình.

---

## Giai Đoạn 3: Kiểm Thử Thực Tế (Forward Testing)

*Mục tiêu: Xác minh hiệu quả của EA trong điều kiện thị trường thực, không có độ trễ của backtest.*

- **Task 3.1: Triển Khai Trên Tài Khoản Demo**
    - Thuê một VPS (Máy chủ ảo cá nhân) để đảm bảo bot chạy 24/7.
    - Cài đặt MT5 và EA lên VPS, cho chạy trên tài khoản Demo với bộ tham số tốt nhất từ Giai Đoạn 2.

- **Task 3.2: Giám Sát và Ghi Chép**
    - Để EA chạy liên tục trong ít nhất **4 tuần**.
    - Theo dõi nhật ký (log) của EA hàng ngày để phát hiện lỗi.
    - So sánh hiệu suất thực tế (lệnh, lợi nhuận, sụt giảm) với kết quả backtest.

---

## Giai Đoạn 4: Triển Khai Chính Thức (Live Deployment)

*Mục tiêu: Đưa EA vào hoạt động trên tài khoản thật một cách an toàn.*

- **Task 4.1: Bắt Đầu Với Rủi Ro Thấp Nhất**
    - Nạp một số vốn nhỏ vào tài khoản thật (hoặc tài khoản Cent).
    - Cho EA chạy với mức rủi ro thấp nhất có thể (ví dụ: 0.5% hoặc khối lượng 0.01 lot cố định).

- **Task 4.2: Đánh Giá và Tăng Dần**
    - Sau 1-2 tháng hoạt động ổn định và có lợi nhuận trên tài khoản thật, bạn có thể cân nhắc tăng dần vốn hoặc mức độ rủi ro.

- **Task 4.3: Bảo Trì Định Kỳ**
    - Thị trường luôn thay đổi. Khoảng 6 tháng một lần, hãy xem xét việc chạy lại quá trình tối ưu hóa (Giai Đoạn 2) để đảm bảo các tham số của EA vẫn còn phù hợp. 