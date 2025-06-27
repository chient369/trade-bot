# 📰 News API Integration Guide

## 🚀 **Forex Factory API Integration**

XAU Trading Bot hiện đã tích hợp với **Forex Factory API** để lấy dữ liệu tin tức thực tế ảnh hưởng đến thị trường vàng.

---

## ⚙️ **Cấu hình API**

### 📋 **Input Parameters mới:**

```cpp
input string         NewsApiKey = "";                   // API Key for Forex Factory news
input bool           UseRealNewsAPI = false;            // Use real API (true) or dummy data (false)
input int            NewsUpdateInterval = 3600;         // News update interval in seconds (1 hour)
```

### 🔑 **Lấy API Key:**

1. **Truy cập**: [jblanked.com](https://www.jblanked.com/news/api/forex-factory)
2. **Đăng ký** tài khoản và lấy API key
3. **Copy API key** vào parameter `NewsApiKey`

---

## 📊 **API Endpoint & Data Format**

### 🌐 **Endpoint:**
```
https://www.jblanked.com/news/api/forex-factory/calendar/week
```

### 📝 **Request Headers:**
```cpp
Content-Type: application/json
Authorization: Api-Key YOUR_API_KEY
```

### 📄 **Response Format:**
```json
[
    {
        "Name": "Bank Stress Test Results",
        "Currency": "USD",
        "Date": "2025.06.27 23:30:00",
        "Actual": 0.0,
        "Forecast": 0.0,
        "Previous": 0.0,
        "Outcome": "Data Not Loaded",
        "Strength": "High",
        "Quality": "Data Not Loaded"
    }
]
```

---

## 🛠️ **Cài đặt MetaTrader 5**

### ⚠️ **Quan trọng - Allowed URLs:**

Trước khi sử dụng API, **BẮT BUỘC** phải thêm URL vào danh sách allowed trong MT5:

1. **Tools** → **Options** → **Expert Advisors**
2. Check ✅ **"Allow WebRequest for listed URL"**
3. **Add URL**: `https://www.jblanked.com`
4. **Restart MetaTrader 5**

### 🎛️ **EA Configuration:**

```cpp
// Enable real API
UseRealNewsAPI = true

// Set your API key
NewsApiKey = "your_api_key_here"

// Update interval (seconds)
NewsUpdateInterval = 3600  // 1 hour
```

---

## 🔄 **Chế độ hoạt động**

### 🌐 **Real API Mode** (`UseRealNewsAPI = true`):
- ✅ Fetch data thực từ Forex Factory
- ✅ Update theo `NewsUpdateInterval`
- ✅ Parse JSON response tự động
- ✅ Xác định impact level thông minh

### 🧪 **Dummy Mode** (`UseRealNewsAPI = false`):
- ✅ Sử dụng dummy data cho testing
- ✅ Không cần API key
- ✅ Suitable cho backtest và development

---

## 📈 **Impact Level Logic**

### 🎯 **Auto-Detection:**

```cpp
// USD events = High priority cho Gold
if(Currency == "USD") → Impact 2-3

// API Strength field
if(Strength == "High") → Impact 3
if(Strength == "Medium") → Impact 2
else → Impact 1

// Predefined high-impact events
["Non-Farm Payrolls", "FOMC Meeting", "CPI", "Fed Rate", ...]
```

### 📊 **Impact Levels:**
- **Level 3** (High): 🔴 Stop trading `NewsBeforeMinutes` phút trước/sau
- **Level 2** (Medium): 🟡 Caution mode
- **Level 1** (Low): 🟢 Normal trading

---

## 🔍 **Error Handling**

### ⚠️ **Common Issues:**

```cpp
// Error -1: URL not in allowed list
"Make sure URL is added to allowed URLs in MT5 settings"

// HTTP 401: Invalid API key
"API request failed with HTTP code: 401"

// HTTP 429: Rate limit exceeded
"API request failed with HTTP code: 429"

// No internet/API down
"WebRequest failed. Error: [code]"
```

### 🛡️ **Fallback Strategy:**
- API fail → Automatically switch to dummy data
- Continue trading với reduced news protection
- Log warnings cho monitoring

---

## 📋 **Logging & Monitoring**

### 📝 **Log Messages:**

```
[INFO] Fetching news from API: https://www.jblanked.com/news/...
[INFO] API Response received: 1547 characters
[INFO] Parsing 12 news events from API
[INFO] News events updated from API. Total events: 12

[WARNING] Failed to fetch news from API, using dummy data
[ERROR] WebRequest failed. Error: 4060. Make sure URL is added...
```

### 📊 **Performance Tracking:**
- API response time monitoring
- Success/failure rates
- Data quality validation

---

## 🧪 **Testing Guide**

### ✅ **Validation Steps:**

1. **Test Connection:**
   ```cpp
   UseRealNewsAPI = true
   NewsApiKey = "test_key"
   // Check logs for connection status
   ```

2. **Verify Data:**
   ```cpp
   // EA sẽ log số lượng events parsed
   // Check GetUpcomingEventsSummary() output
   ```

3. **Impact Testing:**
   ```cpp
   // Thay đổi NewsBeforeMinutes
   // Verify trading stops trước news events
   ```

---

## ⚡ **Performance Optimization**

### 🚀 **Best Practices:**

- **Update Interval**: 3600s (1 hour) optimal
- **Cache Management**: Auto-cleanup old events  
- **Error Retry**: Exponential backoff
- **Rate Limiting**: Respect API limits

### 📊 **Resource Usage:**
- **Memory**: ~5-10KB per week của news data
- **Network**: ~2-5KB per API call
- **CPU**: Minimal impact (async processing)

---

## 🔐 **Security**

### 🛡️ **API Key Protection:**
- ✅ Store trong MT5 EA parameters (encrypted)
- ✅ Never log API key content
- ✅ Use HTTPS only
- ❌ Don't hardcode trong source code

### 📋 **Compliance:**
- ✅ Forex Factory terms compliance
- ✅ Rate limiting respect
- ✅ Proper attribution

---

## 🎯 **Gold Trading Specific**

### 📊 **Relevant News Events:**

**High Impact cho XAU/USD:**
- 🇺🇸 **Non-Farm Payrolls**
- 🇺🇸 **Federal Funds Rate**
- 🇺🇸 **CPI/Core CPI**
- 🇺🇸 **FOMC Minutes**
- 🇺🇸 **Fed Chair Speeches**
- 🇺🇸 **GDP Data**
- 🇺🇸 **Unemployment Rate**

**Filter Logic:**
```cpp
// USD currency = Always relevant
if(Currency == "USD") → Check event

// Gold-specific keywords
if(contains("gold", "precious metals", "mining")) → High priority

// High-impact economic indicators
if(isInHighImpactList(eventName)) → Priority filtering
```

---

## 🚀 **Next Steps**

1. **Get API Key** từ jblanked.com
2. **Configure MT5** allowed URLs
3. **Set parameters** trong EA
4. **Test connection** với log monitoring  
5. **Deploy** vào production

**🎉 Ready to trade với real-time news intelligence!** 