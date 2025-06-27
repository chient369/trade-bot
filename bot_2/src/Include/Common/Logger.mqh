//+------------------------------------------------------------------+
//|                                                       Logger.mqh  |
//|                                    Comprehensive Logging System   |
//|                                                   Version 1.0.0   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ChienTV"
#property link      "https://github.com/chient369/trading-bot.git"
#property version   "1.00"

#include "../../Config/Config.mqh"

//+------------------------------------------------------------------+
//| Logger Class - Main logging functionality                         |
//+------------------------------------------------------------------+
class CLogger
{
private:
   string            m_logFileName;        // Current log file name
   int               m_fileHandle;         // File handle for writing
   ENUM_LOG_LEVEL    m_minLogLevel;       // Minimum log level to write
   bool              m_enableConsole;      // Enable console output
   bool              m_enableFile;         // Enable file output
   
   // Performance tracking
   uint              m_lastExecutionTime;  // Last function execution time
   string            m_lastFunction;       // Last tracked function
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CLogger()
   {
      m_minLogLevel = LOG_INFO;
      m_enableConsole = true;
      m_enableFile = EnableLogging;
      m_fileHandle = INVALID_HANDLE;
      m_lastExecutionTime = 0;
      m_lastFunction = "";
      
      InitializeLogFile();
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                        |
   //+------------------------------------------------------------------+
   ~CLogger()
   {
      if(m_fileHandle != INVALID_HANDLE)
      {
         FileClose(m_fileHandle);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Initialize log file                                               |
   //+------------------------------------------------------------------+
   void InitializeLogFile()
   {
      if(!m_enableFile) return;
      
      // Create log file name with date
      string date = TimeToString(TimeCurrent(), TIME_DATE);
      StringReplace(date, ".", "_");
      m_logFileName = "XAU_TradingBot_" + date + ".log";
      
      // Try to create Logs directory if it doesn't exist
      string logsPath = "Logs";
      if(!CreateLogDirectory(logsPath))
      {
         Print("Failed to create Logs directory, trying current directory");
         m_fileHandle = FileOpen(m_logFileName, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
      }
      else
      {
         // Open file for writing (append mode) in Logs folder
         m_fileHandle = FileOpen("Logs/" + m_logFileName, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
      }
      
      if(m_fileHandle != INVALID_HANDLE)
      {
         FileSeek(m_fileHandle, 0, SEEK_END);
         WriteInitialLogs();
         Print("✅ Log file created successfully: " + m_logFileName);
      }
      else
      {
         int error = GetLastError();
         Print("❌ Failed to create log file: " + m_logFileName + " Error: " + IntegerToString(error));
         Print("📁 Current terminal files path: ", TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\");
         
         // Try alternative file name in current directory
         m_logFileName = "TradingBot_" + date + ".log";
         m_fileHandle = FileOpen(m_logFileName, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
         
         if(m_fileHandle != INVALID_HANDLE)
         {
            WriteInitialLogs();
            Print("✅ Alternative log file created: " + m_logFileName);
         }
         else
         {
            Print("❌ Failed to create any log file. Logging will be console-only.");
            m_enableFile = false;
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Create log directory if not exists                                |
   //+------------------------------------------------------------------+
   bool CreateLogDirectory(string dirPath)
   {
      // Try to create directory using folder creation
      string testFile = dirPath + "/test.tmp";
      int handle = FileOpen(testFile, FILE_WRITE|FILE_TXT);
      
      if(handle != INVALID_HANDLE)
      {
         FileClose(handle);
         FileDelete(testFile);
         return true;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Write initial log entries                                         |
   //+------------------------------------------------------------------+
   void WriteInitialLogs()
   {
      WriteLog(LOG_INFO, "=== XAU TRADING BOT STARTED ===");
      WriteLog(LOG_INFO, "Version: 1.0.0");
      WriteLog(LOG_INFO, "Symbol: " + _Symbol);
      WriteLog(LOG_INFO, "Timeframe: " + EnumToString(_Period));
      WriteLog(LOG_INFO, "Account: " + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)));
      WriteLog(LOG_INFO, "Log File: " + m_logFileName);
      WriteLog(LOG_INFO, "Files Path: " + TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\");
      WriteLog(LOG_INFO, "Logging Enabled: " + (m_enableFile ? "YES" : "NO"));
      WriteLog(LOG_INFO, "Console Enabled: " + (m_enableConsole ? "YES" : "NO"));
      WriteLog(LOG_INFO, "===============================");
   }
   
   //+------------------------------------------------------------------+
   //| Write log entry                                                   |
   //+------------------------------------------------------------------+
   void WriteLog(ENUM_LOG_LEVEL level, string message)
   {
      if(level > m_minLogLevel) return;
      
      string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
      string levelStr = LogLevelToString(level);
      string logEntry = StringFormat("[%s] [%s] %s", timestamp, levelStr, message);
      
      // Console output
      if(m_enableConsole)
      {
         Print(logEntry);
      }
      
      // File output
      if(m_enableFile && m_fileHandle != INVALID_HANDLE)
      {
         FileWriteString(m_fileHandle, logEntry + "\n");
         FileFlush(m_fileHandle);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Log trade entry details                                           |
   //+------------------------------------------------------------------+
   void LogTradeEntry(string strategy, ENUM_ORDER_TYPE orderType, double price, 
                      double sl, double tp, double lotSize, string signals)
   {
      double slPips = PriceToPips(MathAbs(price - sl));
      double tpPips = PriceToPips(MathAbs(tp - price));
      double riskAmount = AccountInfoDouble(ACCOUNT_EQUITY) * RiskPerTrade / 100;
      
      string logMessage = StringFormat(
         "=== TRADE ENTRY [%s] ===\n" +
         "Time: %s\n" +
         "Strategy: %s\n" +
         "Type: %s\n" +
         "Price: %.5f\n" +
         "Stop Loss: %.5f (%.1f pips)\n" +
         "Take Profit: %.5f (%.1f pips)\n" +
         "Risk:Reward: 1:%.2f\n" +
         "Risk Amount: $%.2f (%.2f%%)\n" +
         "Lot Size: %.2f\n" +
         "Market State: %s\n" +
         "Entry Signals:\n%s\n" +
         "Spread: %.1f pips\n" +
         "==================",
         strategy,
         TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
         strategy,
         EnumToString(orderType),
         price,
         sl, slPips,
         tp, tpPips,
         tpPips / slPips,
         riskAmount, RiskPerTrade,
         lotSize,
         GetCurrentMarketState(),
         signals,
         GetCurrentSpreadPips()
      );
      
      WriteLog(LOG_ENTRY, logMessage);
   }
   
   //+------------------------------------------------------------------+
   //| Log market analysis                                               |
   //+------------------------------------------------------------------+
   void LogMarketAnalysis(double ema200, double adx, double atr, 
                          ENUM_MARKET_STATE state, string trendStrength)
   {
      string pricePosition = (SymbolInfoDouble(_Symbol, SYMBOL_BID) > ema200) ? "ABOVE" : "BELOW";
      string adxState = GetADXState(adx);
      
      string analysis = StringFormat(
         "=== MARKET ANALYSIS H4 ===\n" +
         "Time: %s\n" +
         "Current Price: %.5f\n" +
         "EMA 200: %.5f (Price %s EMA)\n" +
         "ADX: %.2f (%s)\n" +
         "ATR: %.5f (%.1f pips)\n" +
         "Market State: %s\n" +
         "Trend Strength: %s\n" +
         "Trading Allowed: %s\n" +
         "=======================",
         TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
         SymbolInfoDouble(_Symbol, SYMBOL_BID),
         ema200,
         pricePosition,
         adx,
         adxState,
         atr, PriceToPips(atr),
         MarketStateToString(state),
         trendStrength,
         IsTradingTimeAllowed() ? "YES" : "NO"
      );
      
      WriteLog(LOG_INFO, analysis);
   }
   
   //+------------------------------------------------------------------+
   //| Log entry conditions check                                        |
   //+------------------------------------------------------------------+
   void LogEntryConditions(string direction, bool emaCondition, bool rsiCondition, 
                           bool volumeCondition, bool priceActionCondition, 
                           bool macdCondition = true)
   {
      string conditions = StringFormat(
         "Entry Conditions Check [%s]:\n" +
         "✓ EMA Crossover: %s\n" +
         "✓ RSI Condition: %s\n" +
         "✓ MACD Condition: %s\n" +
         "✓ Volume Confirmation: %s\n" +
         "✓ Price Action: %s\n" +
         "Overall Signal: %s",
         direction,
         emaCondition ? "PASS" : "FAIL",
         rsiCondition ? "PASS" : "FAIL",
         macdCondition ? "PASS" : "FAIL",
         volumeCondition ? "PASS" : "FAIL",
         priceActionCondition ? "PASS" : "FAIL",
         (emaCondition && rsiCondition && macdCondition && 
          volumeCondition && priceActionCondition) ? "VALID" : "INVALID"
      );
      
      WriteLog(LOG_ENTRY, conditions);
   }
   
   //+------------------------------------------------------------------+
   //| Log position sizing calculation                                   |
   //+------------------------------------------------------------------+
   void LogPositionSizing(double stopLoss, double entryPrice, double calculatedLot, double finalLot)
   {
      double riskAmount = AccountInfoDouble(ACCOUNT_EQUITY) * RiskPerTrade / 100;
      double pipValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double stopLossPips = PriceToPips(MathAbs(entryPrice - stopLoss));
      
      string logMsg = StringFormat(
         "Position Sizing Calculation:\n" +
         "Account Equity: $%.2f\n" +
         "Risk Amount: $%.2f (%.1f%%)\n" +
         "Stop Loss Distance: %.1f pips\n" +
         "Pip Value: $%.2f\n" +
         "Calculated Lot Size: %.2f\n" +
         "Final Lot Size: %.2f\n" +
         "Actual Risk: $%.2f",
         AccountInfoDouble(ACCOUNT_EQUITY),
         riskAmount, RiskPerTrade,
         stopLossPips,
         pipValue,
         calculatedLot,
         finalLot,
         finalLot * stopLossPips * pipValue
      );
      
      WriteLog(LOG_INFO, logMsg);
   }
   
   //+------------------------------------------------------------------+
   //| Log trade result                                                  |
   //+------------------------------------------------------------------+
   void LogTradeResult(int ticket, double profit, bool isWin, 
                       PerformanceMetrics &metrics)
   {
      double currentDrawdown = CalculateDrawdown(metrics);
      double roi = (metrics.totalProfit / AccountInfoDouble(ACCOUNT_BALANCE)) * 100;
      
      string result = StringFormat(
         "=== TRADE RESULT #%d ===\n" +
         "Ticket: %d\n" +
         "P&L: $%.2f (%s)\n" +
         "Running Total: $%.2f\n" +
         "Win Rate: %.1f%% (%d/%d)\n" +
         "Profit Factor: %.2f\n" +
         "Current Drawdown: %.2f%%\n" +
         "Max Drawdown: %.2f%%\n" +
         "ROI: %.2f%%\n" +
         "Consecutive Losses: %d\n" +
         "========================",
         metrics.totalTrades,
         ticket,
         profit, isWin ? "WIN" : "LOSS",
         metrics.totalProfit,
         metrics.winRate, metrics.winningTrades, metrics.totalTrades,
         metrics.profitFactor,
         currentDrawdown,
         metrics.maxDrawdown,
         roi,
         metrics.consecutiveLosses
      );
      
      WriteLog(LOG_INFO, result);
   }
   
   //+------------------------------------------------------------------+
   //| Log daily summary                                                 |
   //+------------------------------------------------------------------+
   void LogDailySummary(int tradesToday, double profitToday, 
                        string trendPerformance, string rangePerformance,
                        string marketConditions, string newsImpact)
   {
      string summary = StringFormat(
         "=== DAILY SUMMARY ===\n" +
         "Date: %s\n" +
         "Trades Today: %d\n" +
         "P&L Today: $%.2f\n" +
         "Strategy Performance:\n" +
         "- Trend Following: %s\n" +
         "- Range Trading: %s\n" +
         "Market Conditions: %s\n" +
         "News Events Impact: %s\n" +
         "Account Balance: $%.2f\n" +
         "Account Equity: $%.2f\n" +
         "Free Margin: $%.2f\n" +
         "==================",
         TimeToString(TimeCurrent(), TIME_DATE),
         tradesToday,
         profitToday,
         trendPerformance,
         rangePerformance,
         marketConditions,
         newsImpact,
         AccountInfoDouble(ACCOUNT_BALANCE),
         AccountInfoDouble(ACCOUNT_EQUITY),
         AccountInfoDouble(ACCOUNT_MARGIN_FREE)
      );
      
      WriteLog(LOG_INFO, summary);
   }
   
   //+------------------------------------------------------------------+
   //| Log trading error                                                 |
   //+------------------------------------------------------------------+
   void LogTradingError(int errorCode, string operation, string additionalInfo = "")
   {
      string errorMsg = StringFormat(
         "TRADING ERROR:\n" +
         "Operation: %s\n" +
         "Error Code: %d\n" +
         "Description: %s\n" +
         "Time: %s\n" +
         "Symbol: %s\n" +
         "Account Balance: $%.2f\n" +
         "Free Margin: $%.2f\n" +
         "Additional Info: %s",
         operation,
         errorCode,
         GetErrorDescription(errorCode),
         TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
         _Symbol,
         AccountInfoDouble(ACCOUNT_BALANCE),
         AccountInfoDouble(ACCOUNT_MARGIN_FREE),
         additionalInfo
      );
      
      WriteLog(LOG_ERROR, errorMsg);
      
      // Send alert for critical errors
      if(IsCriticalError(errorCode) && EnableAlerts)
      {
         Alert("Critical Trading Error: " + IntegerToString(errorCode) + " - " + operation);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Log news filter status                                            |
   //+------------------------------------------------------------------+
   void LogNewsFilter(string nextEvent, int minutesUntil, bool tradingAllowed, string reason)
   {
      string newsStatus = StringFormat(
         "=== NEWS FILTER STATUS ===\n" +
         "Current Time: %s\n" +
         "Next High Impact Event: %s\n" +
         "Time Until Event: %d minutes\n" +
         "Trading Allowed: %s\n" +
         "Reason: %s\n" +
         "========================",
         TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
         nextEvent,
         minutesUntil,
         tradingAllowed ? "YES" : "NO",
         reason
      );
      
      WriteLog(LOG_INFO, newsStatus);
   }
   
   //+------------------------------------------------------------------+
   //| Start execution time tracking                                     |
   //+------------------------------------------------------------------+
   void StartExecutionTracking(string functionName)
   {
      m_lastFunction = functionName;
      m_lastExecutionTime = GetTickCount();
   }
   
   //+------------------------------------------------------------------+
   //| End execution time tracking and log if slow                       |
   //+------------------------------------------------------------------+
   void EndExecutionTracking()
   {
      if(m_lastExecutionTime == 0) return;
      
      uint executionTime = GetTickCount() - m_lastExecutionTime;
      
      if(executionTime > 100) // Log if execution time > 100ms
      {
         string timeLog = StringFormat(
            "PERFORMANCE WARNING:\n" +
            "Function: %s\n" +
            "Execution Time: %d ms\n" +
            "Threshold: 100 ms",
            m_lastFunction,
            executionTime
         );
         
         WriteLog(LOG_WARNING, timeLog);
      }
      
      m_lastExecutionTime = 0;
      m_lastFunction = "";
   }
   
   //+------------------------------------------------------------------+
   //| Log backtest metrics                                              |
   //+------------------------------------------------------------------+
   void LogBacktestMetrics(PerformanceMetrics &metrics)
   {
      string backtest = StringFormat(
         "=== BACKTEST FINAL RESULTS ===\n" +
         "Total Trades: %d\n" +
         "Winning Trades: %d\n" +
         "Losing Trades: %d\n" +
         "Win Rate: %.2f%%\n" +
         "Total Profit: $%.2f\n" +
         "Total Loss: $%.2f\n" +
         "Profit Factor: %.2f\n" +
         "Max Drawdown: %.2f%%\n" +
         "Average Win: $%.2f\n" +
         "Average Loss: $%.2f\n" +
         "Largest Win: $%.2f\n" +
         "Largest Loss: $%.2f\n" +
         "=============================",
         metrics.totalTrades,
         metrics.winningTrades,
         metrics.losingTrades,
         metrics.winRate,
         metrics.totalProfit,
         metrics.totalLoss,
         metrics.profitFactor,
         metrics.maxDrawdown,
         metrics.winningTrades > 0 ? metrics.totalProfit / metrics.winningTrades : 0,
         metrics.losingTrades > 0 ? metrics.totalLoss / metrics.losingTrades : 0,
         GetLargestWin(),
         GetLargestLoss()
      );
      
      WriteLog(LOG_INFO, backtest);
   }

private:
   //+------------------------------------------------------------------+
   //| Helper Functions                                                  |
   //+------------------------------------------------------------------+
   string LogLevelToString(ENUM_LOG_LEVEL level)
   {
      switch(level)
      {
         case LOG_ERROR:   return "ERROR";
         case LOG_WARNING: return "WARN ";
         case LOG_INFO:    return "INFO ";
         case LOG_ENTRY:   return "ENTRY";
         case LOG_DEBUG:   return "DEBUG";
         default:          return "UNKN ";
      }
   }
   
   string GetCurrentMarketState()
   {
      // This will be implemented in MarketAnalysis module
      return "UNDEFINED";
   }
   
   double GetCurrentSpreadPips()
   {
      long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      return (double)spread / PIPS_FACTOR;
   }
   
   string GetADXState(double adx)
   {
      if(adx >= ADX_StrongTrend) return "STRONG TREND";
      else if(adx >= ADX_ModerateTrend) return "MODERATE TREND";
      else return "WEAK/NO TREND";
   }
   
   bool IsTradingTimeAllowed()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      
      if(dt.hour < TradingStartHour || dt.hour >= TradingEndHour)
         return false;
         
      if(CloseOnFriday && dt.day_of_week == 5 && dt.hour >= FridayCloseHour)
         return false;
         
      return true;
   }
   
   double CalculateDrawdown(PerformanceMetrics &metrics)
   {
      double peak = AccountInfoDouble(ACCOUNT_BALANCE) + metrics.totalProfit;
      double current = AccountInfoDouble(ACCOUNT_EQUITY);
      double drawdown = ((peak - current) / peak) * 100;
      return drawdown > 0 ? drawdown : 0;
   }
   
   string GetErrorDescription(int errorCode)
   {
      switch(errorCode)
      {
         case 0:    return "No error";
         case 1:    return "No error, trade conditions not changed";
         case 2:    return "Common error";
         case 3:    return "Invalid trade parameters";
         case 4:    return "Trade server is busy";
         case 5:    return "Old version of the client terminal";
         case 6:    return "No connection with trade server";
         case 7:    return "Not enough rights";
         case 8:    return "Too frequent requests";
         case 9:    return "Malfunctional trade operation";
         case 64:   return "Account disabled";
         case 65:   return "Invalid account";
         case 128:  return "Trade timeout";
         case 129:  return "Invalid price";
         case 130:  return "Invalid stops";
         case 131:  return "Invalid trade volume";
         case 132:  return "Market is closed";
         case 133:  return "Trade is disabled";
         case 134:  return "Not enough money";
         case 135:  return "Price changed";
         case 136:  return "Off quotes";
         case 137:  return "Broker is busy";
         case 138:  return "Requote";
         case 139:  return "Order is locked";
         case 140:  return "Long positions only allowed";
         case 141:  return "Too many requests";
         case 145:  return "Modification denied because order is too close to market";
         case 146:  return "Trade context is busy";
         case 147:  return "Expirations are denied by broker";
         case 148:  return "Amount of open and pending orders has reached the limit";
         default:   return "Unknown error";
      }
   }
   
   bool IsCriticalError(int errorCode)
   {
      return (errorCode == 2 || errorCode == 5 || errorCode == 64 || 
              errorCode == 65 || errorCode == 133 || errorCode == 134);
   }
   
   double GetLargestWin()
   {
      // Implementation would scan trade history
      return 0.0;
   }
   
   double GetLargestLoss()
   {
      // Implementation would scan trade history
      return 0.0;
   }
};

//+------------------------------------------------------------------+
//| Global logger instance                                            |
//+------------------------------------------------------------------+
CLogger* g_Logger = NULL;

//+------------------------------------------------------------------+
//| Initialize global logger                                          |
//+------------------------------------------------------------------+
void InitializeLogger()
{
   if(g_Logger == NULL)
   {
      g_Logger = new CLogger();
   }
}

//+------------------------------------------------------------------+
//| Cleanup global logger                                             |
//+------------------------------------------------------------------+
void CleanupLogger()
{
   if(g_Logger != NULL)
   {
      delete g_Logger;
      g_Logger = NULL;
   }
}

//+------------------------------------------------------------------+
//| Global logging functions for easy access                          |
//+------------------------------------------------------------------+
void LogInfo(string message)
{
   if(g_Logger != NULL) g_Logger.WriteLog(LOG_INFO, message);
}

void LogError(string message)
{
   if(g_Logger != NULL) g_Logger.WriteLog(LOG_ERROR, message);
}

void LogWarning(string message)
{
   if(g_Logger != NULL) g_Logger.WriteLog(LOG_WARNING, message);
}

void LogDebug(string message)
{
   if(g_Logger != NULL) g_Logger.WriteLog(LOG_DEBUG, message);
}

//+------------------------------------------------------------------+ 