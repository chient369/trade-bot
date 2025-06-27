//+------------------------------------------------------------------+
//|                                              XAU_TradingBot.mq5   |
//|                                     XAU/USD Trading Expert Advisor |
//|                                                   Version 1.0.0   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ChienTV"
#property link      "https://github.com/chient369/trading-bot.git"
#property version   "1.00"
#property description "Automated trading system for XAU/USD with trend following and range trading strategies"

//+------------------------------------------------------------------+
//| Include files                                                      |
//+------------------------------------------------------------------+
#include "../Config/Config.mqh"
#include "../Include/Common/Logger.mqh"
#include "../Include/Common/Utils.mqh"
#include "../Include/Common/RiskManagement.mqh"
#include "../Include/Common/NewsFilter.mqh"
#include "../Include/Strategies/MarketAnalysis.mqh"
#include "../Include/Strategies/TrendFollowing.mqh"
#include "../Include/Strategies/RangeTrading.mqh"

//+------------------------------------------------------------------+
//| Global Variables                                                   |
//+------------------------------------------------------------------+
CTrendFollowingStrategy* g_TrendStrategy = NULL;
CRangeTradingStrategy*   g_RangeStrategy = NULL;

// EA state
bool              g_IsInitialized = false;
datetime          g_LastTradeTime = 0;
int               g_CurrentPositionTicket = 0;
ENUM_TRADING_STRATEGY g_ActiveStrategy = STRATEGY_NONE;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   // Validate input parameters
   if(!ValidateInputParameters())
   {
      Print("EA initialization failed: Invalid input parameters");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   // Check symbol
   if(_Symbol != "XAUUSD" && _Symbol != "GOLD")
   {
      Print("EA initialization failed: This EA is designed for XAU/USD only");
      return(INIT_FAILED);
   }
   
   // Check timeframe
   if(_Period != PERIOD_M15)
   {
      Print("EA initialization failed: Please run on M15 timeframe");
      return(INIT_FAILED);
   }
   
   // Initialize logger
   InitializeLogger();
   LogInfo("=== XAU TRADING BOT INITIALIZATION ===");
   LogInfo("Version: 1.0.0");
   LogInfo("Symbol: " + _Symbol);
   LogInfo("Timeframe: " + EnumToString(_Period));
   LogInfo("Account: " + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)));
   LogInfo("Server: " + AccountInfoString(ACCOUNT_SERVER));
   
   // Initialize components
   InitializeRiskManager();
   InitializeNewsFilter();
   InitializeMarketAnalysis();
   
   // Initialize strategies
   g_TrendStrategy = new CTrendFollowingStrategy();
   g_RangeStrategy = new CRangeTradingStrategy();
   
   // Check initialization
   if(g_Logger == NULL || g_RiskManager == NULL || 
      g_NewsFilter == NULL || g_MarketAnalysis == NULL ||
      g_TrendStrategy == NULL || g_RangeStrategy == NULL)
   {
      LogError("Failed to initialize one or more components");
      return(INIT_FAILED);
   }
   
   g_IsInitialized = true;
   LogInfo("EA initialized successfully");
   LogInfo("=====================================");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(!g_IsInitialized) return;
   
   LogInfo("=== XAU TRADING BOT SHUTDOWN ===");
   LogInfo("Deinit reason: " + GetDeinitReasonText(reason));
   
   // Log final performance metrics
   if(g_RiskManager != NULL)
   {
      PerformanceMetrics metrics = g_RiskManager.GetPerformanceMetrics();
      g_Logger.LogBacktestMetrics(metrics);
   }
   
   // Cleanup strategies
   if(g_TrendStrategy != NULL)
   {
      delete g_TrendStrategy;
      g_TrendStrategy = NULL;
   }
   
   if(g_RangeStrategy != NULL)
   {
      delete g_RangeStrategy;
      g_RangeStrategy = NULL;
   }
   
   // Cleanup components
   CleanupMarketAnalysis();
   CleanupNewsFilter();
   CleanupRiskManager();
   
   LogInfo("EA shutdown complete");
   LogInfo("================================");
   
   CleanupLogger();
   
   g_IsInitialized = false;
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_IsInitialized) return;
   
   // Update market analysis
   g_MarketAnalysis.Update();
   
   // Check daily reset
   g_RiskManager.CheckDailyReset();
   
   // Get current market conditions
   MarketConditions conditions = g_MarketAnalysis.GetMarketConditions();
   ENUM_MARKET_STATE marketState = conditions.state;
   
   // Check if we have open positions
   bool hasOpenPosition = (g_CurrentPositionTicket > 0 && 
                          PositionSelectByTicket(g_CurrentPositionTicket));
   
   // Handle existing positions
   if(hasOpenPosition)
   {
      HandleOpenPosition();
   }
   else
   {
      // Reset position ticket
      g_CurrentPositionTicket = 0;
      g_ActiveStrategy = STRATEGY_NONE;
      
      // Check for new trading opportunities
      CheckForNewTrade(marketState);
   }
   
   // Apply trailing stop to all positions
   g_RiskManager.ApplyTrailingStop();
}

//+------------------------------------------------------------------+
//| Check for new trade opportunities                                  |
//+------------------------------------------------------------------+
void CheckForNewTrade(ENUM_MARKET_STATE marketState)
{
   // Check if trading is allowed
   string restrictionReason;
   if(!g_RiskManager.IsTradingAllowed(restrictionReason))
   {
      static datetime lastLogTime = 0;
      if(TimeCurrent() - lastLogTime > 300) // Log every 5 minutes
      {
         LogInfo("Trading restricted: " + restrictionReason);
         lastLogTime = TimeCurrent();
      }
      return;
   }
   
   // Check news filter
   string newsReason;
   if(!g_NewsFilter.IsTradingAllowed(newsReason))
   {
      static datetime lastNewsLogTime = 0;
      if(TimeCurrent() - lastNewsLogTime > 300) // Log every 5 minutes
      {
         LogInfo("Trading restricted by news filter: " + newsReason);
         lastNewsLogTime = TimeCurrent();
      }
      return;
   }
   
   // Check if we can open new trades
   if(!COrderUtils::CanOpenNewTrade())
   {
      return;
   }
   
   // Avoid trading too frequently
   if(TimeCurrent() - g_LastTradeTime < 300) // 5 minutes minimum between trades
   {
      return;
   }
   
   TradeSignal signal;
   signal.isValid = false;
   
   // Check appropriate strategy based on market state
   if(marketState == MARKET_SIDEWAYS)
   {
      // Use range trading strategy for sideways markets
      signal = g_RangeStrategy.CheckEntrySignal(marketState);
      if(signal.isValid)
      {
         g_ActiveStrategy = STRATEGY_RANGE_TRADING;
      }
   }
   else if(marketState != MARKET_UNDEFINED)
   {
      // Use trend following strategy for trending markets
      signal = g_TrendStrategy.CheckEntrySignal(marketState);
      if(signal.isValid)
      {
         g_ActiveStrategy = STRATEGY_TREND_FOLLOWING;
      }
   }
   
   // Execute trade if we have a valid signal
   if(signal.isValid)
   {
      ExecuteTrade(signal);
   }
}

//+------------------------------------------------------------------+
//| Handle open position                                               |
//+------------------------------------------------------------------+
void HandleOpenPosition()
{
   if(!PositionSelectByTicket(g_CurrentPositionTicket)) return;
   
   ENUM_ORDER_TYPE positionType = (ENUM_ORDER_TYPE)PositionGetInteger(POSITION_TYPE);
   
   // Check news - close if high impact news approaching
   string eventName;
   int minutesUntil;
   if(g_NewsFilter.ShouldCloseBeforeNews(eventName, minutesUntil))
   {
      LogWarning("Closing position due to upcoming news: " + eventName + 
                " in " + IntegerToString(minutesUntil) + " minutes");
      ClosePosition(g_CurrentPositionTicket, "News event approaching");
      return;
   }
   
   // Check for exit signals based on active strategy
   bool shouldExit = false;
   
   if(g_ActiveStrategy == STRATEGY_TREND_FOLLOWING)
   {
      shouldExit = g_TrendStrategy.CheckExitSignal(positionType);
   }
   else if(g_ActiveStrategy == STRATEGY_RANGE_TRADING)
   {
      shouldExit = g_RangeStrategy.CheckExitSignal(positionType);
   }
   
   if(shouldExit)
   {
      ClosePosition(g_CurrentPositionTicket, "Exit signal triggered");
   }
}

//+------------------------------------------------------------------+
//| Execute trade based on signal                                      |
//+------------------------------------------------------------------+
void ExecuteTrade(TradeSignal &signal)
{
   // Final validation
   if(!signal.isValid || signal.lotSize <= 0)
   {
      LogError("Invalid trade signal or lot size");
      return;
   }
   
   // Prepare trade request
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = signal.lotSize;
   request.type = signal.orderType;
   request.price = signal.entryPrice;
   request.sl = signal.stopLoss;
   request.tp = signal.takeProfit;
   request.deviation = MAX_SLIPPAGE * PIPS_FACTOR;
   request.magic = MagicNumber;
   request.comment = EA_Comment + " | " + GetStrategyName(g_ActiveStrategy);
   
   // Log trade entry details
   g_Logger.LogTradeEntry(
      GetStrategyName(g_ActiveStrategy),
      signal.orderType,
      signal.entryPrice,
      signal.stopLoss,
      signal.takeProfit,
      signal.lotSize,
      signal.signalReason
   );
   
   // Send order
   if(OrderSend(request, result))
   {
      if(result.retcode == TRADE_RETCODE_DONE)
      {
         g_CurrentPositionTicket = (int)result.order;
         g_LastTradeTime = TimeCurrent();
         
         LogInfo("Trade executed successfully. Ticket: " + 
                IntegerToString(g_CurrentPositionTicket));
         
         // Send alert if enabled
         if(EnableAlerts)
         {
            string alertMsg = "XAU Trading Bot: " + 
                            (signal.orderType == ORDER_TYPE_BUY ? "BUY" : "SELL") +
                            " order opened at " + DoubleToString(signal.entryPrice, _Digits);
            Alert(alertMsg);
         }
      }
      else
      {
         LogError("Trade execution failed. Retcode: " + IntegerToString(result.retcode));
      }
   }
   else
   {
      int error = GetLastError();
      g_Logger.LogTradingError(error, "OrderSend", 
                              "Volume: " + DoubleToString(signal.lotSize, 2));
   }
}

//+------------------------------------------------------------------+
//| Close position                                                     |
//+------------------------------------------------------------------+
bool ClosePosition(int ticket, string reason)
{
   if(!PositionSelectByTicket(ticket)) return false;
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.position = ticket;
   request.symbol = _Symbol;
   request.volume = PositionGetDouble(POSITION_VOLUME);
   request.type = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                  ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   request.price = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ?
                   SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                   SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   request.deviation = MAX_SLIPPAGE * PIPS_FACTOR;
   request.magic = MagicNumber;
   request.comment = "Close: " + reason;
   
   if(OrderSend(request, result))
   {
      if(result.retcode == TRADE_RETCODE_DONE)
      {
         LogInfo("Position closed successfully. Reason: " + reason);
         g_CurrentPositionTicket = 0;
         g_ActiveStrategy = STRATEGY_NONE;
         return true;
      }
   }
   
   int error = GetLastError();
   g_Logger.LogTradingError(error, "ClosePosition", "Ticket: " + IntegerToString(ticket));
   return false;
}

//+------------------------------------------------------------------+
//| Trade event handler                                                |
//+------------------------------------------------------------------+
void OnTrade()
{
   // Handle trade events for performance tracking
   static int lastDealsTotal = 0;
   int currentDealsTotal = HistoryDealsTotal();
   
   if(currentDealsTotal > lastDealsTotal)
   {
      // New deal detected
      for(int i = lastDealsTotal; i < currentDealsTotal; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0) continue;
         
         // Check if this is our deal
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != MagicNumber) continue;
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
         
         // Check if this is a position close
         if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
         {
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            bool isWin = profit > 0;
            
            // Update performance metrics
            g_RiskManager.UpdatePerformanceMetrics(profit, isWin);
            
            // Log trade result
            PerformanceMetrics metrics = g_RiskManager.GetPerformanceMetrics();
            g_Logger.LogTradeResult((int)ticket, profit, isWin, metrics);
         }
      }
   }
   
   lastDealsTotal = currentDealsTotal;
}

//+------------------------------------------------------------------+
//| Timer event handler                                                |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Periodic tasks can be implemented here if needed
}

//+------------------------------------------------------------------+
//| Helper Functions                                                   |
//+------------------------------------------------------------------+
string GetDeinitReasonText(int reason)
{
   switch(reason)
   {
      case REASON_PROGRAM:     return "Program terminated";
      case REASON_REMOVE:      return "Program removed from chart";
      case REASON_RECOMPILE:   return "Program recompiled";
      case REASON_CHARTCHANGE: return "Symbol or timeframe changed";
      case REASON_CHARTCLOSE:  return "Chart closed";
      case REASON_PARAMETERS:  return "Input parameters changed";
      case REASON_ACCOUNT:     return "Account changed";
      default:                 return "Other reason";
   }
}

string GetStrategyName(ENUM_TRADING_STRATEGY strategy)
{
   switch(strategy)
   {
      case STRATEGY_TREND_FOLLOWING: return "Trend Following";
      case STRATEGY_RANGE_TRADING:   return "Range Trading";
      default:                       return "None";
   }
}

//+------------------------------------------------------------------+ 