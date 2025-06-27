# XAU/USD Trading Bot - Expert Advisor

## Giới thiệu

XAU Trading Bot là một Expert Advisor (EA) được thiết kế chuyên biệt cho giao dịch cặp XAU/USD (Vàng) trên khung thời gian M15. EA sử dụng phân tích khung H4 để xác định xu hướng thị trường và áp dụng hai chiến lược giao dịch:

- **Trend Following Strategy**: Giao dịch theo xu hướng khi thị trường có xu hướng rõ ràng
- **Range Trading Strategy**: Giao dịch trong vùng giá khi thị trường đi ngang (sideways)

## Tính năng chính

1. **Phân tích đa khung thời gian**: 
   - H4 để xác định xu hướng tổng thể
   - M15 để tìm điểm vào lệnh

2. **Quản lý rủi ro chặt chẽ**:
   - Rủi ro cố định 1% mỗi lệnh
   - Giới hạn lỗ tối đa 2% mỗi ngày
   - Tự động tính toán lot size dựa trên rủi ro

3. **Bộ lọc tin tức kinh tế**:
   - Tự động tạm dừng giao dịch trước/sau tin tức quan trọng
   - Đóng lệnh trước khi có tin high-impact

4. **Hệ thống logging chi tiết**:
   - Ghi lại mọi hoạt động của EA
   - Phân tích hiệu suất giao dịch
   - Theo dõi điều kiện thị trường

## Yêu cầu hệ thống

- **Platform**: MetaTrader 5 (MT5)
- **Symbol**: XAUUSD hoặc GOLD
- **Timeframe**: M15 (bắt buộc)
- **Minimum deposit**: $1000 (khuyến nghị $5000+)
- **Leverage**: 1:100 hoặc cao hơn
- **VPS**: Khuyến nghị sử dụng VPS để EA chạy 24/5

## Cài đặt

1. **Copy files vào MT5**:
   ```
   - Copy toàn bộ thư mục src vào: [MT5 Data Folder]/MQL5/
   - Cấu trúc sau khi copy:
     MQL5/
     ├── Experts/
     │   └── XAU_TradingBot.mq5
     ├── Include/
     │   ├── Common/
     │   │   ├── Logger.mqh
     │   │   ├── Utils.mqh
     │   │   ├── RiskManagement.mqh
     │   │   └── NewsFilter.mqh
     │   └── Strategies/
     │       ├── MarketAnalysis.mqh
     │       ├── TrendFollowing.mqh
     │       └── RangeTrading.mqh
     └── Config/
         └── Config.mqh
   ```

2. **Compile EA**:
   - Mở MetaEditor (F4 trong MT5)
   - Mở file `Experts/XAU_TradingBot.mq5`
   - Nhấn F7 để compile
   - Kiểm tra không có lỗi compile

3. **Attach EA vào chart**:
   - Mở chart XAUUSD M15
   - Kéo EA từ Navigator vào chart
   - Cấu hình parameters theo nhu cầu

## Cấu hình Parameters

### General Settings
- `MagicNumber`: 20240625 (để phân biệt với EA khác)
- `EA_Comment`: Comment cho mỗi lệnh
- `EnableLogging`: Bật/tắt ghi log
- `EnableAlerts`: Bật/tắt cảnh báo

### Risk Management
- `RiskPerTrade`: 1.0% (rủi ro mỗi lệnh)
- `MaxDailyLoss`: 2.0% (lỗ tối đa mỗi ngày)
- `MinRiskReward`: 1.5 (tỷ lệ R:R tối thiểu)
- `StrongTrendRR`: 2.0 (R:R cho xu hướng mạnh)

### Trading Time
- `TradingStartHour`: 8 (giờ bắt đầu - London time)
- `TradingEndHour`: 22 (giờ kết thúc)
- `CloseOnFriday`: true (đóng lệnh cuối tuần)

### News Filter
- `UseNewsFilter`: true (bật bộ lọc tin tức)
- `NewsBeforeMinutes`: 30 (phút trước tin)
- `NewsAfterMinutes`: 30 (phút sau tin)

## Chiến lược giao dịch

### 1. Trend Following (Xu hướng mạnh/vừa)
**Điều kiện vào lệnh BUY**:
- EMA(12) cắt lên EMA(26) trên M15
- RSI trong khoảng 45-70
- MACD > Signal và MACD > 0
- Volume > MA(20)
- Xác nhận price action

**Điều kiện vào lệnh SELL**:
- EMA(12) cắt xuống EMA(26) trên M15
- RSI trong khoảng 30-55
- MACD < Signal và MACD < 0
- Volume > MA(20)
- Xác nhận price action

### 2. Range Trading (Thị trường sideways)
**Điều kiện vào lệnh BUY**:
- Giá chạm/xuyên dải dưới Bollinger Bands
- RSI < 35 (oversold)
- Xuất hiện mẫu nến đảo chiều
- Không gần support H4

**Điều kiện vào lệnh SELL**:
- Giá chạm/xuyên dải trên Bollinger Bands
- RSI > 65 (overbought)
- Xuất hiện mẫu nến đảo chiều
- Không gần resistance H4

## Monitoring và Maintenance

### Log Files
Log files được lưu trong: `MQL5/Logs/XAU_TradingBot_[DATE].log`

Nội dung log bao gồm:
- Market analysis mỗi H4
- Chi tiết entry/exit
- Performance metrics
- Errors và warnings

### Performance Tracking
EA tự động theo dõi:
- Win rate
- Profit factor
- Maximum drawdown
- Consecutive losses
- Daily P&L

### Recommended Checks
1. **Hàng ngày**: 
   - Kiểm tra log file
   - Xem daily summary
   - Monitor drawdown

2. **Hàng tuần**:
   - Review performance metrics
   - Kiểm tra news calendar
   - Adjust parameters nếu cần

3. **Hàng tháng**:
   - Backtest với data mới
   - Optimize parameters
   - Review strategy performance

## Backtesting

### Recommended Settings
- Period: 2-3 năm data
- Mode: Every tick based on real ticks
- Spread: 20-30 points (realistic cho Gold)
- Commission: Theo broker thực tế

### Key Metrics
- Profit Factor > 1.3
- Win Rate > 40%
- Max Drawdown < 15%
- Sharpe Ratio > 1.0

## Troubleshooting

### EA không mở lệnh
1. Kiểm tra tab Experts - có lỗi gì không
2. Verify đang chạy trên M15 timeframe
3. Check trading hours settings
4. Xem log file để biết chi tiết

### Lỗi "Trading not allowed"
1. Enable AutoTrading trong MT5
2. Check EA properties - Allow live trading
3. Verify không có news restrictions

### Performance kém
1. Review market conditions
2. Check spread trong peak hours
3. Verify VPS latency
4. Consider re-optimization

## Risk Disclaimer

**QUAN TRỌNG**: Trading forex và CFDs có rủi ro cao. Bạn có thể mất toàn bộ vốn đầu tư. EA này không đảm bảo lợi nhuận và kết quả trong quá khứ không đảm bảo kết quả tương lai. Chỉ trade với số tiền bạn có thể chấp nhận mất.

## Support

- GitHub: https://github.com/chient369/trading-bot.git
- Version: 1.0.0
- Last Updated: 2024

## License

Copyright 2025, ChienTV. All rights reserved. 