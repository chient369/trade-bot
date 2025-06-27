# Chiến Lược Giao Dịch Tổng Hợp Cho Bot Vàng (XAU/USD)

## 1. Tổng Quan và Triết Lý

Đây là một hệ thống giao dịch tự động (Expert Advisor - EA) được thiết kế riêng cho cặp XAU/USD trên khung thời gian M15, sử dụng khung H4 làm "kim chỉ nam" để xác định bối cảnh thị trường.

- **Triết lý cốt lõi:** "Không một chiến lược nào là hoàn hảo cho mọi điều kiện thị trường. Hãy để thị trường cho chúng ta biết nên sử dụng chiến lược nào."
- **Mục tiêu:** Tối đa hóa lợi nhuận khi thị trường có xu hướng rõ ràng và bảo vệ vốn, tìm kiếm lợi nhuận nhỏ khi thị trường đi ngang.

---

## 2. Nguyên Tắc Quản Lý Vốn (Bất Biến)

Đây là những quy tắc được ưu tiên hàng đầu, áp dụng cho MỌI giao dịch.

- **Rủi Ro Mỗi Lệnh (Risk per Trade):** Cố định ở mức **1%** trên tổng tài sản. Bot sẽ tự động tính toán khối lượng (lot size) dựa trên khoảng cách Stop Loss để đảm bảo mức lỗ không vượt quá 1%.
- **Tỷ Lệ Lợi Nhuận/Rủi Ro (Risk:Reward Ratio):** 
  - Tối thiểu là **1:1.5** cho thị trường sideways
  - **1:2** cho thị trường có xu hướng mạnh (ADX > 30)
- **Giới Hạn Lệnh:** Chỉ cho phép **1 lệnh** giao dịch được mở tại một thời điểm để tránh rủi ro chồng chất.
- **Gap Protection:** Tự động đóng lệnh nếu gap > 50 pips khi mở cửa phiên.
- **Max Daily Loss:** Dừng giao dịch nếu lỗ vượt quá 2% tài khoản trong ngày.

---

## 3. Bộ Lọc News và Thời Gian Giao Dịch

### News Filter (Ưu Tiên Cao)
- **Tạm dừng giao dịch** trong 30 phút trước và 30 phút sau các sự kiện high-impact:
  - US NFP (Non-Farm Payrolls)
  - FOMC Meetings & Interest Rate Decisions
  - US CPI & Core CPI
  - US GDP
  - Gold-specific news (Central Bank announcements về gold reserves)
- **Đóng lệnh hiện tại** nếu đang có position và có high-impact news trong 15 phút tới.

### Khung Thời Gian Hoạt Động
- **Khung chính:** 08:00 - 22:00 (London Time)
- **Tránh giao dịch:** 22:00 - 02:00 (Low liquidity period)
- **Cẩn trọng đặc biệt:** 15:30 - 16:30 (US Market Open - High volatility)

---

## 4. Kiến Trúc Chiến Lược: Hệ Thống 3 Module

Bot sẽ hoạt động dựa trên 3 module chính, được điều phối bởi bộ lọc trạng thái thị trường trên khung H4.

### Module 1: Bộ Lọc Trạng Thái Thị Trường (Khung H4) - CẢI TIẾN

Đây là "bộ não" của EA, chạy trên mỗi cây nến H4 mới để quyết định chiến lược cho 4 giờ tiếp theo.

- **Chỉ báo sử dụng:**
    - `EMA (200)` trên H4: Xác định xu hướng dài hạn.
    - `ADX (14)` trên H4: Đo lường sức mạnh của xu hướng.
    - `ATR (14)` trên H4: Đo lường volatility để điều chỉnh thresholds.
- **Quy tắc xác định trạng thái (Cải tiến):**
    - **`THỊ TRƯỜNG CÓ XU HƯỚNG TĂNG MẠNH (STRONG UPTREND)`**:
        - Giá đóng cửa nến H4 hiện tại > `EMA(200)`.
        - `ADX(14)` > 30.
        - R:R ratio sử dụng: 1:2
    - **`THỊ TRƯỜNG CÓ XU HƯỚNG TĂNG VỪA (MODERATE UPTREND)`**:
        - Giá đóng cửa nến H4 hiện tại > `EMA(200)`.
        - `ADX(14)` giữa 25-30.
        - R:R ratio sử dụng: 1:1.5
    - **`THỊ TRƯỜNG CÓ XU HƯỚNG GIẢM MẠNH (STRONG DOWNTREND)`**:
        - Giá đóng cửa nến H4 hiện tại < `EMA(200)`.
        - `ADX(14)` > 30.
        - R:R ratio sử dụng: 1:2
    - **`THỊ TRƯỜNG CÓ XU HƯỚNG GIẢM VỪA (MODERATE DOWNTREND)`**:
        - Giá đóng cửa nến H4 hiện tại < `EMA(200)`.
        - `ADX(14)` giữa 25-30.
        - R:R ratio sử dụng: 1:1.5
    - **`THỊ TRƯỜNG ĐI NGANG (SIDEWAYS)`**:
        - `ADX(14)` < 25.
        - R:R ratio sử dụng: 1:1.5

### Module 2: Chiến Lược Giao Dịch Theo Xu Hướng (Khung M15) - CẢI TIẾN

Module này chỉ được kích hoạt khi Module 1 xác nhận thị trường đang ở trạng thái `UPTREND` hoặc `DOWNTREND`.

- **Mục tiêu:** Bắt các điểm vào lệnh thuận theo xu hướng lớn trên H4.
- **Chỉ báo sử dụng trên M15:**
    - `EMA (12)`
    - `EMA (26)`
    - `RSI (14)`
    - `MACD (12,26,9)` - **Thêm mới**
    - `Volume` (nếu có) - **Thêm mới**
- **Logic Vào Lệnh (Cải tiến):**
    - **Lệnh MUA (khi H4 là UPTREND):**
        1. Chờ `EMA(12)` cắt lên trên `EMA(26)` trên khung M15.
        2. Nến xác nhận tín hiệu phải đóng cửa phía trên cả hai đường EMA.
        3. **Điều kiện lọc nâng cao:** 
           - `RSI(14)` trong khoảng 45-70 (tránh extreme oversold/overbought)
           - `MACD` line > Signal line và MACD > 0
           - Volume hiện tại > Average Volume 20 periods (nếu có data)
        4. **Xác nhận momentum:** Nến entry phải có body > 60% tổng range
    - **Lệnh BÁN (khi H4 là DOWNTREND):**
        1. Chờ `EMA(12)` cắt xuống dưới `EMA(26)` trên khung M15.
        2. Nến xác nhận tín hiệu phải đóng cửa phía dưới cả hai đường EMA.
        3. **Điều kiện lọc nâng cao:**
           - `RSI(14)` trong khoảng 30-55 (tránh extreme oversold/overbought)
           - `MACD` line < Signal line và MACD < 0
           - Volume hiện tại > Average Volume 20 periods (nếu có data)
        4. **Xác nhận momentum:** Nến entry phải có body > 60% tổng range
- **Logic Thoát Lệnh:**
    - **Stop Loss:** Đặt dưới đáy swing low gần nhất (cho lệnh Mua) hoặc trên đỉnh swing high gần nhất (cho lệnh Bán). Tối thiểu 20 pips.
    - **Take Profit:** Tính toán theo tỷ lệ R:R được xác định bởi Module 1.
    - **Trailing Stop:** Kích hoạt khi lợi nhuận đạt 1:1, trail với khoảng cách = 50% SL ban đầu.

### Module 3: Chiến Lược Giao Dịch Trong Vùng Giá (Khung M15) - CẢI TIẾN

Module này chỉ được kích hoạt khi Module 1 xác nhận thị trường đang `SIDEWAYS`.

- **Mục tiêu:** Tìm kiếm lợi nhuận từ sự dao động của giá quanh một vùng cân bằng.
- **Chỉ báo sử dụng trên M15:**
    - `Bollinger Bands (21, 2.1)` - **Cải tiến parameters**
    - `RSI (14)`
    - `Support/Resistance levels` từ H4 - **Thêm mới**
- **Logic Vào Lệnh (Cải tiến):**
    - **Lệnh MUA:**
        1. Giá chạm hoặc xuyên xuống dưới dải dưới (Lower Band) của Bollinger Bands.
        2. **Đồng thời**, `RSI(14)` đi vào vùng < 35 (điều chỉnh từ 30).
        3. **Xác nhận price action:** Xuất hiện Doji, Hammer, hoặc Bullish Engulfing.
        4. **Không vào lệnh** nếu đang gần support level quan trọng từ H4 (trong vòng 10 pips).
    - **Lệnh BÁN:**
        1. Giá chạm hoặc xuyên lên trên dải trên (Upper Band) của Bollinger Bands.
        2. **Đồng thời**, `RSI(14)` đi vào vùng > 65 (điều chỉnh từ 70).
        3. **Xác nhận price action:** Xuất hiện Doji, Shooting Star, hoặc Bearish Engulfing.
        4. **Không vào lệnh** nếu đang gần resistance level quan trọng từ H4 (trong vòng 10 pips).
- **Logic Thoát Lệnh:**
    - **Stop Loss:** Đặt ngay trên đỉnh nến tín hiệu (lệnh Bán) hoặc dưới đáy nến tín hiệu (lệnh Mua). Tối thiểu 15 pips.
    - **Take Profit 1:** Đường trung bình (Middle Band) của Bollinger Bands (50% position).
    - **Take Profit 2:** Dải đối diện của Bollinger Bands (50% position còn lại).

---

## 5. Quản Lý Rủi Ro Kỹ Thuật

### Điều Kiện Dừng Giao Dịch Tạm Thời
- **Market Choppy Detection:** Dừng giao dịch nếu có > 3 lệnh stop loss liên tiếp trong 4 giờ.
- **High Spread Warning:** Tạm dừng nếu spread > 3 pips cho XAU/USD.
- **Low Liquidity:** Tránh giao dịch khi volume < 50% average volume 20 periods.

### Bảo Vệ Đặc Biệt
- **Friday Close:** Đóng tất cả positions trước 20:00 GMT Friday.
- **Holiday Protection:** Danh sách ngày lễ để tránh giao dịch.
- **Correlation Check:** Monitor correlation với USD Index, nếu breakdown bất thường thì cảnh báo.

---

## 6. Yêu Cầu Backtesting và Optimization

### Tiêu Chuẩn Backtesting
- **Thời gian test:** Tối thiểu 24 tháng data (2 năm).
- **Spread:** Realistic spread 2-3 pips.
- **Commission:** Include commission thực tế của broker.
- **Slippage:** Mô phỏng slippage 1-2 pips trong high volatility.

### Metrics Đánh Giá
- **Profit Factor:** > 1.3
- **Maximum Drawdown:** < 15%
- **Win Rate:** > 40% (với R:R 1:1.5-2)
- **Sharpe Ratio:** > 1.0
- **Recovery Factor:** > 2.0

### Test Riêng Biệt
- **Module 2 test:** Chỉ test trong trending markets
- **Module 3 test:** Chỉ test trong sideways markets
- **Stress test:** Test trong periods volatility cao (US election, Brexit, etc.)

---

## 7. Về Phương Pháp Breakout

Phương pháp 3 (Breakout phiên Á) sẽ không được tích hợp trực tiếp vào logic chính để tránh làm phức tạp hóa hệ thống. Thay vào đó, nó có thể được phát triển như một EA độc lập, chuyên biệt, chỉ hoạt động trong khoảng thời gian từ 7:00 đến 9:00 sáng (giờ London) để bắt sóng phá vỡ. Việc tách biệt này giúp dễ quản lý, tối ưu và đánh giá hiệu quả của từng chiến lược.

---

## 8. Implementation Priority

### Phase 1 (Core Implementation)
1. Module 1: Market state detection
2. Basic risk management
3. News filter integration

### Phase 2 (Strategy Modules)
1. Module 2: Trend following
2. Module 3: Range trading
3. Enhanced exit strategies

### Phase 3 (Advanced Features)
1. Dynamic parameter adjustment
2. Advanced risk management
3. Performance analytics dashboard 