//+------------------------------------------------------------------+
//|                                                        Utils.mqh  |
//|                                         Common Utility Functions  |
//|                                                   Version 1.0.0   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ChienTV"
#property link      "https://github.com/chient369/trading-bot.git"
#property version   "1.00"

#include "../../Config/Config.mqh"

//+------------------------------------------------------------------+
//| Time and Date Utilities                                           |
//+------------------------------------------------------------------+
class CTimeUtils
{
public:
   //+------------------------------------------------------------------+
   //| Check if current time is within trading hours                     |
   //+------------------------------------------------------------------+
   static bool IsWithinTradingHours()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      
      // Check basic trading hours
      if(dt.hour < TradingStartHour || dt.hour >= TradingEndHour)
         return false;
      
      // Check Friday close
      if(CloseOnFriday && dt.day_of_week == 5 && dt.hour >= FridayCloseHour)
         return false;
      
      // Avoid low liquidity period (22:00 - 02:00)
      if(AvoidLowLiquidity && (dt.hour >= 22 || dt.hour < 2))
         return false;
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Check if US market is opening (high volatility)                   |
   //+------------------------------------------------------------------+
   static bool IsUSMarketOpening()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      
      // US market opens at 15:30 London time
      if(dt.hour == 15 && dt.min >= 30)
         return true;
      if(dt.hour == 16 && dt.min <= 30)
         return true;
         
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Convert server time to London time                                |
   //+------------------------------------------------------------------+
   static datetime ConvertToLondonTime(datetime serverTime)
   {
      // This is a simplified version - in production, you'd need proper timezone handling
      // Assuming server is in GMT+2 (common for brokers)
      return serverTime - 2 * 3600; // Subtract 2 hours
   }
   
   //+------------------------------------------------------------------+
   //| Check if new H4 candle has formed                                 |
   //+------------------------------------------------------------------+
   static bool IsNewH4Candle(datetime &lastH4Time)
   {
      datetime currentH4Time = iTime(_Symbol, PERIOD_H4, 0);
      
      if(currentH4Time > lastH4Time)
      {
         lastH4Time = currentH4Time;
         return true;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Get time until next H4 candle                                     |
   //+------------------------------------------------------------------+
   static int GetMinutesUntilNextH4()
   {
      datetime currentTime = TimeCurrent();
      datetime currentH4Time = iTime(_Symbol, PERIOD_H4, 0);
      datetime nextH4Time = currentH4Time + 4 * 3600; // Add 4 hours
      
      return (int)((nextH4Time - currentTime) / 60);
   }
};

//+------------------------------------------------------------------+
//| Price and Calculation Utilities                                   |
//+------------------------------------------------------------------+
class CPriceUtils
{
public:
   //+------------------------------------------------------------------+
   //| Normalize price according to symbol specifications                 |
   //+------------------------------------------------------------------+
   static double NormalizePrice(double price)
   {
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      return NormalizeDouble(MathRound(price / tickSize) * tickSize, _Digits);
   }
   
   //+------------------------------------------------------------------+
   //| Calculate pip value for current symbol                             |
   //+------------------------------------------------------------------+
   static double GetPipValue()
   {
      return SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / 
             SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE) * 
             POINT_VALUE * PIPS_FACTOR;
   }
   
   //+------------------------------------------------------------------+
   //| Check if spread is acceptable                                      |
   //+------------------------------------------------------------------+
   static bool IsSpreadAcceptable()
   {
      double currentSpread = GetCurrentSpreadPips();
      return currentSpread <= MaxSpreadPips;
   }
   
   //+------------------------------------------------------------------+
   //| Get current spread in pips                                        |
   //+------------------------------------------------------------------+
   static double GetCurrentSpreadPips()
   {
      long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      return (double)spread / PIPS_FACTOR;
   }
   
   //+------------------------------------------------------------------+
   //| Check for price gaps                                              |
   //+------------------------------------------------------------------+
   static bool HasPriceGap(double &gapSize)
   {
      double currentOpen = iOpen(_Symbol, _Period, 0);
      double previousClose = iClose(_Symbol, _Period, 1);
      
      gapSize = MathAbs(currentOpen - previousClose);
      double gapPips = PriceToPips(gapSize);
      
      return gapPips > GapProtectionPips;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate lot size based on risk                                  |
   //+------------------------------------------------------------------+
   static double CalculateLotSize(double entryPrice, double stopLoss)
   {
      double riskAmount = AccountInfoDouble(ACCOUNT_EQUITY) * RiskPerTrade / 100;
      double pipValue = GetPipValue();
      double stopLossPips = PriceToPips(MathAbs(entryPrice - stopLoss));
      
      if(stopLossPips == 0 || pipValue == 0) return 0;
      
      double lotSize = riskAmount / (stopLossPips * pipValue);
      
      // Normalize according to broker specifications
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      
      lotSize = MathMax(minLot, lotSize);
      lotSize = MathMin(maxLot, lotSize);
      lotSize = NormalizeDouble(MathRound(lotSize / lotStep) * lotStep, 2);
      
      return lotSize;
   }
   
   //+------------------------------------------------------------------+
   //| Find nearest swing high                                           |
   //+------------------------------------------------------------------+
   static double FindSwingHigh(int barsToCheck = 20)
   {
      double swingHigh = 0;
      
      for(int i = 1; i < barsToCheck - 1; i++)
      {
         double high = iHigh(_Symbol, _Period, i);
         double prevHigh = iHigh(_Symbol, _Period, i + 1);
         double nextHigh = iHigh(_Symbol, _Period, i - 1);
         
         if(high > prevHigh && high > nextHigh)
         {
            if(swingHigh == 0 || high > swingHigh)
               swingHigh = high;
         }
      }
      
      return swingHigh;
   }
   
   //+------------------------------------------------------------------+
   //| Find nearest swing low                                            |
   //+------------------------------------------------------------------+
   static double FindSwingLow(int barsToCheck = 20)
   {
      double swingLow = 0;
      
      for(int i = 1; i < barsToCheck - 1; i++)
      {
         double low = iLow(_Symbol, _Period, i);
         double prevLow = iLow(_Symbol, _Period, i + 1);
         double nextLow = iLow(_Symbol, _Period, i - 1);
         
         if(low < prevLow && low < nextLow)
         {
            if(swingLow == 0 || low < swingLow)
               swingLow = low;
         }
      }
      
      return swingLow;
   }
};

//+------------------------------------------------------------------+
//| Order Management Utilities                                         |
//+------------------------------------------------------------------+
class COrderUtils
{
public:
   //+------------------------------------------------------------------+
   //| Count open positions for the EA                                   |
   //+------------------------------------------------------------------+
   static int CountOpenPositions()
   {
      int count = 0;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionSelectByTicket(PositionGetTicket(i)))
         {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
               PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            {
               count++;
            }
         }
      }
      
      return count;
   }
   
   //+------------------------------------------------------------------+
   //| Check if we have reached max concurrent trades                    |
   //+------------------------------------------------------------------+
   static bool CanOpenNewTrade()
   {
      return CountOpenPositions() < MaxConcurrentTrades;
   }
   
   //+------------------------------------------------------------------+
   //| Close all positions                                               |
   //+------------------------------------------------------------------+
   static bool CloseAllPositions(string reason = "")
   {
      bool allClosed = true;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionSelectByTicket(PositionGetTicket(i)))
         {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
               PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            {
               MqlTradeRequest request = {};
               MqlTradeResult result = {};
               
               request.action = TRADE_ACTION_DEAL;
               request.position = PositionGetTicket(i);
               request.symbol = _Symbol;
               request.volume = PositionGetDouble(POSITION_VOLUME);
               request.type = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                              ORDER_TYPE_SELL : ORDER_TYPE_BUY;
               request.price = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ?
                               SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                               SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               request.magic = MagicNumber;
               request.comment = "Close: " + reason;
               
               if(!OrderSend(request, result))
               {
                  allClosed = false;
               }
            }
         }
      }
      
      return allClosed;
   }
   
   //+------------------------------------------------------------------+
   //| Get total profit/loss for today                                   |
   //+------------------------------------------------------------------+
   static double GetTodayProfitLoss()
   {
      double totalPL = 0;
      datetime todayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
      
      // Check current positions
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionSelectByTicket(PositionGetTicket(i)))
         {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
               PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
               PositionGetInteger(POSITION_TIME) >= todayStart)
            {
               totalPL += PositionGetDouble(POSITION_PROFIT);
            }
         }
      }
      
      // Check history
      HistorySelect(todayStart, TimeCurrent());
      for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol &&
            HistoryDealGetInteger(ticket, DEAL_MAGIC) == MagicNumber &&
            HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
         {
            totalPL += HistoryDealGetDouble(ticket, DEAL_PROFIT);
         }
      }
      
      return totalPL;
   }
   
   //+------------------------------------------------------------------+
   //| Check if daily loss limit reached                                 |
   //+------------------------------------------------------------------+
   static bool IsDailyLossLimitReached()
   {
      double todayLoss = GetTodayProfitLoss();
      double maxLossAmount = AccountInfoDouble(ACCOUNT_EQUITY) * MaxDailyLoss / 100;
      
      return todayLoss < -maxLossAmount;
   }
};

//+------------------------------------------------------------------+
//| Pattern Recognition Utilities                                      |
//+------------------------------------------------------------------+
class CPatternUtils
{
public:
   //+------------------------------------------------------------------+
   //| Check if candle is bullish                                        |
   //+------------------------------------------------------------------+
   static bool IsBullishCandle(int shift = 0)
   {
      return iClose(_Symbol, _Period, shift) > iOpen(_Symbol, _Period, shift);
   }
   
   //+------------------------------------------------------------------+
   //| Check if candle is bearish                                        |
   //+------------------------------------------------------------------+
   static bool IsBearishCandle(int shift = 0)
   {
      return iClose(_Symbol, _Period, shift) < iOpen(_Symbol, _Period, shift);
   }
   
   //+------------------------------------------------------------------+
   //| Calculate candle body percentage                                  |
   //+------------------------------------------------------------------+
   static double GetCandleBodyPercent(int shift = 0)
   {
      double high = iHigh(_Symbol, _Period, shift);
      double low = iLow(_Symbol, _Period, shift);
      double open = iOpen(_Symbol, _Period, shift);
      double close = iClose(_Symbol, _Period, shift);
      
      double range = high - low;
      double body = MathAbs(close - open);
      
      if(range == 0) return 0;
      
      return (body / range) * 100;
   }
   
   //+------------------------------------------------------------------+
   //| Check for Doji pattern                                            |
   //+------------------------------------------------------------------+
   static bool IsDoji(int shift = 0)
   {
      double bodyPercent = GetCandleBodyPercent(shift);
      return bodyPercent < 10; // Body less than 10% of range
   }
   
   //+------------------------------------------------------------------+
   //| Check for Hammer pattern                                          |
   //+------------------------------------------------------------------+
   static bool IsHammer(int shift = 0)
   {
      double open = iOpen(_Symbol, _Period, shift);
      double close = iClose(_Symbol, _Period, shift);
      double high = iHigh(_Symbol, _Period, shift);
      double low = iLow(_Symbol, _Period, shift);
      
      double body = MathAbs(close - open);
      double lowerShadow = MathMin(open, close) - low;
      double upperShadow = high - MathMax(open, close);
      
      return lowerShadow > body * 2 && upperShadow < body * 0.5;
   }
   
   //+------------------------------------------------------------------+
   //| Check for Shooting Star pattern                                   |
   //+------------------------------------------------------------------+
   static bool IsShootingStar(int shift = 0)
   {
      double open = iOpen(_Symbol, _Period, shift);
      double close = iClose(_Symbol, _Period, shift);
      double high = iHigh(_Symbol, _Period, shift);
      double low = iLow(_Symbol, _Period, shift);
      
      double body = MathAbs(close - open);
      double upperShadow = high - MathMax(open, close);
      double lowerShadow = MathMin(open, close) - low;
      
      return upperShadow > body * 2 && lowerShadow < body * 0.5;
   }
   
   //+------------------------------------------------------------------+
   //| Check for Bullish Engulfing pattern                               |
   //+------------------------------------------------------------------+
   static bool IsBullishEngulfing(int shift = 0)
   {
      if(shift < 1) return false;
      
      bool prevBearish = IsBearishCandle(shift + 1);
      bool currBullish = IsBullishCandle(shift);
      
      double prevOpen = iOpen(_Symbol, _Period, shift + 1);
      double prevClose = iClose(_Symbol, _Period, shift + 1);
      double currOpen = iOpen(_Symbol, _Period, shift);
      double currClose = iClose(_Symbol, _Period, shift);
      
      return prevBearish && currBullish && 
             currOpen < prevClose && currClose > prevOpen;
   }
   
   //+------------------------------------------------------------------+
   //| Check for Bearish Engulfing pattern                               |
   //+------------------------------------------------------------------+
   static bool IsBearishEngulfing(int shift = 0)
   {
      if(shift < 1) return false;
      
      bool prevBullish = IsBullishCandle(shift + 1);
      bool currBearish = IsBearishCandle(shift);
      
      double prevOpen = iOpen(_Symbol, _Period, shift + 1);
      double prevClose = iClose(_Symbol, _Period, shift + 1);
      double currOpen = iOpen(_Symbol, _Period, shift);
      double currClose = iClose(_Symbol, _Period, shift);
      
      return prevBullish && currBearish && 
             currOpen > prevClose && currClose < prevOpen;
   }
};

//+------------------------------------------------------------------+
//| Performance Tracking Utilities                                     |
//+------------------------------------------------------------------+
class CPerformanceUtils
{
public:
   //+------------------------------------------------------------------+
   //| Count consecutive losses                                           |
   //+------------------------------------------------------------------+
   static int CountConsecutiveLosses()
   {
      int losses = 0;
      
      // Select history from last 24 hours
      HistorySelect(TimeCurrent() - 86400, TimeCurrent());
      
      // Iterate through deals in reverse order (newest first)
      for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = HistoryDealGetTicket(i);
         
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol &&
            HistoryDealGetInteger(ticket, DEAL_MAGIC) == MagicNumber &&
            HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
         {
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            
            if(profit < 0)
               losses++;
            else
               break; // Stop counting on first win
         }
      }
      
      return losses;
   }
   
   //+------------------------------------------------------------------+
   //| Check if should pause trading due to consecutive losses           |
   //+------------------------------------------------------------------+
   static bool ShouldPauseTrading(datetime &pauseUntil)
   {
      static datetime lastPauseTime = 0;
      
      int consecutiveLosses = CountConsecutiveLosses();
      
      if(consecutiveLosses >= MaxConsecutiveLosses)
      {
         if(lastPauseTime == 0 || TimeCurrent() > pauseUntil)
         {
            lastPauseTime = TimeCurrent();
            pauseUntil = TimeCurrent() + PauseAfterLossesHours * 3600;
            return true;
         }
      }
      
      return TimeCurrent() < pauseUntil;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate profit factor                                            |
   //+------------------------------------------------------------------+
   static double CalculateProfitFactor(int days = 30)
   {
      double grossProfit = 0;
      double grossLoss = 0;
      
      HistorySelect(TimeCurrent() - days * 86400, TimeCurrent());
      
      for(int i = 0; i < HistoryDealsTotal(); i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol &&
            HistoryDealGetInteger(ticket, DEAL_MAGIC) == MagicNumber &&
            HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
         {
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            
            if(profit > 0)
               grossProfit += profit;
            else
               grossLoss += MathAbs(profit);
         }
      }
      
      return grossLoss > 0 ? grossProfit / grossLoss : 0;
   }
};

//+------------------------------------------------------------------+ 