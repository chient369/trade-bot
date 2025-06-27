//+------------------------------------------------------------------+
//|                                               RangeTrading.mqh    |
//|                                   Range Trading Strategy Module   |
//|                                                   Version 1.0.0   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ChienTV"
#property link      "https://github.com/chient369/trading-bot.git"
#property version   "1.00"

#include "../../Config/Config.mqh"
#include "../Common/Logger.mqh"
#include "../Common/Utils.mqh"
#include "../Common/RiskManagement.mqh"
#include "MarketAnalysis.mqh"

//+------------------------------------------------------------------+
//| Range Trading Strategy Class                                       |
//+------------------------------------------------------------------+
class CRangeTradingStrategy
{
private:
   // Indicator handles
   int               m_handleBB;           // Bollinger Bands handle
   int               m_handleRSI;          // RSI handle
   
   // Indicator values
   double            m_bbUpper[2];         // Upper band values
   double            m_bbMiddle[2];        // Middle band values
   double            m_bbLower[2];         // Lower band values
   double            m_rsi;                // Current RSI value
   
   // Support/Resistance levels from H4
   double            m_h4Support;          // H4 support level
   double            m_h4Resistance;       // H4 resistance level
   
   // Strategy state
   datetime          m_lastSignalTime;     // Last signal generation time
   TradeSignal       m_lastSignal;         // Last generated signal
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CRangeTradingStrategy()
   {
      m_handleBB = INVALID_HANDLE;
      m_handleRSI = INVALID_HANDLE;
      
      m_h4Support = 0;
      m_h4Resistance = 0;
      
      m_lastSignalTime = 0;
      ResetSignal();
      
      InitializeIndicators();
      
      LogInfo("Range Trading Strategy initialized");
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                        |
   //+------------------------------------------------------------------+
   ~CRangeTradingStrategy()
   {
      ReleaseIndicators();
   }
   
   //+------------------------------------------------------------------+
   //| Initialize strategy indicators                                     |
   //+------------------------------------------------------------------+
   bool InitializeIndicators()
   {
      // Create Bollinger Bands on M15
      m_handleBB = iBands(_Symbol, PERIOD_M15, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
      if(m_handleBB == INVALID_HANDLE)
      {
         LogError("Failed to create Bollinger Bands indicator");
         return false;
      }
      
      // Create RSI on M15
      m_handleRSI = iRSI(_Symbol, PERIOD_M15, RSI_Period, PRICE_CLOSE);
      if(m_handleRSI == INVALID_HANDLE)
      {
         LogError("Failed to create RSI indicator");
         return false;
      }
      
      LogInfo("Range trading indicators initialized successfully");
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Update H4 support/resistance levels                               |
   //+------------------------------------------------------------------+
   void UpdateH4Levels()
   {
      if(g_MarketAnalysis != NULL)
      {
         g_MarketAnalysis.GetSupportResistanceLevels(m_h4Support, m_h4Resistance);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Check for entry signals                                           |
   //+------------------------------------------------------------------+
   TradeSignal CheckEntrySignal(ENUM_MARKET_STATE marketState)
   {
      ResetSignal();
      
      // Only check for signals in sideways markets
      if(marketState != MARKET_SIDEWAYS)
      {
         return m_lastSignal;
      }
      
      // Update H4 levels
      UpdateH4Levels();
      
      // Update indicator values
      if(!UpdateIndicatorValues())
      {
         return m_lastSignal;
      }
      
      // Check for buy signal at lower band
      CheckBuySignal();
      
      // If no buy signal, check for sell signal at upper band
      if(!m_lastSignal.isValid)
      {
         CheckSellSignal();
      }
      
      // If signal is valid, calculate trade parameters
      if(m_lastSignal.isValid)
      {
         CalculateTradeParameters();
         m_lastSignalTime = TimeCurrent();
      }
      
      return m_lastSignal;
   }
   
   //+------------------------------------------------------------------+
   //| Check if should exit current position                             |
   //+------------------------------------------------------------------+
   bool CheckExitSignal(ENUM_ORDER_TYPE positionType)
   {
      // Update indicator values
      if(!UpdateIndicatorValues())
      {
         return false;
      }
      
      bool shouldExit = false;
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      if(positionType == ORDER_TYPE_BUY)
      {
         // Exit conditions for long positions
         // 1. Price reached middle band (partial exit)
         if(currentPrice >= m_bbMiddle[0])
         {
            LogInfo("Exit signal: Price reached Bollinger middle band");
            shouldExit = true;
         }
         // 2. RSI became overbought
         else if(m_rsi > RSI_OverboughtLevel + 10) // RSI > 75
         {
            LogInfo("Exit signal: RSI overbought (" + DoubleToString(m_rsi, 2) + ")");
            shouldExit = true;
         }
         // 3. Price broke below lower band (stop loss)
         else if(currentPrice < m_bbLower[0] - PipsToPrice(5))
         {
            LogInfo("Exit signal: Price broke below lower band");
            shouldExit = true;
         }
      }
      else if(positionType == ORDER_TYPE_SELL)
      {
         // Exit conditions for short positions
         // 1. Price reached middle band (partial exit)
         if(currentPrice <= m_bbMiddle[0])
         {
            LogInfo("Exit signal: Price reached Bollinger middle band");
            shouldExit = true;
         }
         // 2. RSI became oversold
         else if(m_rsi < RSI_OversoldLevel - 10) // RSI < 25
         {
            LogInfo("Exit signal: RSI oversold (" + DoubleToString(m_rsi, 2) + ")");
            shouldExit = true;
         }
         // 3. Price broke above upper band (stop loss)
         else if(currentPrice > m_bbUpper[0] + PipsToPrice(5))
         {
            LogInfo("Exit signal: Price broke above upper band");
            shouldExit = true;
         }
      }
      
      return shouldExit;
   }
   
private:
   //+------------------------------------------------------------------+
   //| Update indicator values                                           |
   //+------------------------------------------------------------------+
   bool UpdateIndicatorValues()
   {
      // Copy Bollinger Bands values
      if(CopyBuffer(m_handleBB, 1, 0, 2, m_bbUpper) != 2 ||    // Upper band
         CopyBuffer(m_handleBB, 0, 0, 2, m_bbMiddle) != 2 ||   // Middle band
         CopyBuffer(m_handleBB, 2, 0, 2, m_bbLower) != 2)      // Lower band
      {
         LogError("Failed to copy Bollinger Bands buffer");
         return false;
      }
      
      // Copy RSI value
      double rsiBuffer[];
      if(CopyBuffer(m_handleRSI, 0, 0, 1, rsiBuffer) != 1)
      {
         LogError("Failed to copy RSI buffer");
         return false;
      }
      m_rsi = rsiBuffer[0];
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Check for buy signal                                              |
   //+------------------------------------------------------------------+
   void CheckBuySignal()
   {
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      // Condition 1: Price touched or went below lower band
      bool priceBelowLowerBand = (currentPrice <= m_bbLower[0]);
      
      // Condition 2: RSI is oversold
      bool rsiOversold = (m_rsi < RSI_OversoldLevel);
      
      // Condition 3: Price action confirmation
      bool priceActionConfirmed = CheckBullishReversal();
      
      // Condition 4: Not too close to H4 support
      bool notNearSupport = true;
      if(m_h4Support > 0)
      {
         double distanceToSupport = currentPrice - m_h4Support;
         notNearSupport = (PriceToPips(distanceToSupport) > SupportResistanceBuffer);
      }
      
      // Log conditions
      LogRangeConditions("BUY", priceBelowLowerBand, rsiOversold, 
                        priceActionConfirmed, notNearSupport);
      
      // All conditions must be met
      if(priceBelowLowerBand && rsiOversold && priceActionConfirmed && notNearSupport)
      {
         m_lastSignal.isValid = true;
         m_lastSignal.orderType = ORDER_TYPE_BUY;
         m_lastSignal.signalReason = BuildSignalReason("BUY", priceBelowLowerBand, 
                                                      rsiOversold, priceActionConfirmed, notNearSupport);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Check for sell signal                                             |
   //+------------------------------------------------------------------+
   void CheckSellSignal()
   {
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      // Condition 1: Price touched or went above upper band
      bool priceAboveUpperBand = (currentPrice >= m_bbUpper[0]);
      
      // Condition 2: RSI is overbought
      bool rsiOverbought = (m_rsi > RSI_OverboughtLevel);
      
      // Condition 3: Price action confirmation
      bool priceActionConfirmed = CheckBearishReversal();
      
      // Condition 4: Not too close to H4 resistance
      bool notNearResistance = true;
      if(m_h4Resistance > 0)
      {
         double distanceToResistance = m_h4Resistance - currentPrice;
         notNearResistance = (PriceToPips(distanceToResistance) > SupportResistanceBuffer);
      }
      
      // Log conditions
      LogRangeConditions("SELL", priceAboveUpperBand, rsiOverbought, 
                        priceActionConfirmed, notNearResistance);
      
      // All conditions must be met
      if(priceAboveUpperBand && rsiOverbought && priceActionConfirmed && notNearResistance)
      {
         m_lastSignal.isValid = true;
         m_lastSignal.orderType = ORDER_TYPE_SELL;
         m_lastSignal.signalReason = BuildSignalReason("SELL", priceAboveUpperBand, 
                                                       rsiOverbought, priceActionConfirmed, notNearResistance);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Check for bullish reversal patterns                               |
   //+------------------------------------------------------------------+
   bool CheckBullishReversal()
   {
      // Check for reversal patterns
      bool hasDoji = CPatternUtils::IsDoji(0);
      bool hasHammer = CPatternUtils::IsHammer(0);
      bool hasBullishEngulfing = CPatternUtils::IsBullishEngulfing(0);
      
      // Check if current candle shows rejection from lower band
      double low = iLow(_Symbol, PERIOD_M15, 0);
      double close = iClose(_Symbol, PERIOD_M15, 0);
      double range = iHigh(_Symbol, PERIOD_M15, 0) - low;
      
      bool showsRejection = false;
      if(range > 0)
      {
         double rejectionRatio = (close - low) / range;
         showsRejection = rejectionRatio > 0.6; // Close in upper 40% of range
      }
      
      return (hasDoji || hasHammer || hasBullishEngulfing) && showsRejection;
   }
   
   //+------------------------------------------------------------------+
   //| Check for bearish reversal patterns                               |
   //+------------------------------------------------------------------+
   bool CheckBearishReversal()
   {
      // Check for reversal patterns
      bool hasDoji = CPatternUtils::IsDoji(0);
      bool hasShootingStar = CPatternUtils::IsShootingStar(0);
      bool hasBearishEngulfing = CPatternUtils::IsBearishEngulfing(0);
      
      // Check if current candle shows rejection from upper band
      double high = iHigh(_Symbol, PERIOD_M15, 0);
      double close = iClose(_Symbol, PERIOD_M15, 0);
      double range = high - iLow(_Symbol, PERIOD_M15, 0);
      
      bool showsRejection = false;
      if(range > 0)
      {
         double rejectionRatio = (high - close) / range;
         showsRejection = rejectionRatio > 0.6; // Close in lower 40% of range
      }
      
      return (hasDoji || hasShootingStar || hasBearishEngulfing) && showsRejection;
   }
   
   //+------------------------------------------------------------------+
   //| Log range trading conditions                                      |
   //+------------------------------------------------------------------+
   void LogRangeConditions(string direction, bool bandCondition, bool rsiCondition,
                          bool priceAction, bool levelCondition)
   {
      if(g_Logger == NULL) return;
      
      string conditions = StringFormat(
         "Range Trading Conditions [%s]:\n" +
         "✓ Band Touch: %s\n" +
         "✓ RSI (%.2f): %s\n" +
         "✓ Price Action: %s\n" +
         "✓ H4 Level Check: %s\n" +
         "Overall Signal: %s",
         direction,
         bandCondition ? "YES" : "NO",
         m_rsi,
         rsiCondition ? "VALID" : "INVALID",
         priceAction ? "CONFIRMED" : "NOT CONFIRMED",
         levelCondition ? "SAFE" : "TOO CLOSE",
         (bandCondition && rsiCondition && priceAction && levelCondition) ? "VALID" : "INVALID"
      );
      
      LogInfo(conditions);
   }
   
   //+------------------------------------------------------------------+
   //| Calculate trade parameters                                        |
   //+------------------------------------------------------------------+
   void CalculateTradeParameters()
   {
      // Entry price
      if(m_lastSignal.orderType == ORDER_TYPE_BUY)
         m_lastSignal.entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      else
         m_lastSignal.entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      // Calculate stop loss
      if(m_lastSignal.orderType == ORDER_TYPE_BUY)
      {
         // Stop loss below the lower band or recent low
         double recentLow = iLow(_Symbol, PERIOD_M15, 1);
         m_lastSignal.stopLoss = MathMin(m_bbLower[0] - PipsToPrice(5), recentLow - PipsToPrice(2));
      }
      else
      {
         // Stop loss above the upper band or recent high
         double recentHigh = iHigh(_Symbol, PERIOD_M15, 1);
         m_lastSignal.stopLoss = MathMax(m_bbUpper[0] + PipsToPrice(5), recentHigh + PipsToPrice(2));
      }
      
      // Ensure minimum stop loss distance
      double slDistance = MathAbs(m_lastSignal.entryPrice - m_lastSignal.stopLoss);
      if(PriceToPips(slDistance) < MinStopLossPips)
      {
         if(m_lastSignal.orderType == ORDER_TYPE_BUY)
            m_lastSignal.stopLoss = m_lastSignal.entryPrice - PipsToPrice(MinStopLossPips);
         else
            m_lastSignal.stopLoss = m_lastSignal.entryPrice + PipsToPrice(MinStopLossPips);
      }
      
      // Normalize stop loss
      m_lastSignal.stopLoss = CPriceUtils::NormalizePrice(m_lastSignal.stopLoss);
      
      // Calculate take profit levels
      // TP1: Middle band (50% position)
      // TP2: Opposite band (50% position)
      if(m_lastSignal.orderType == ORDER_TYPE_BUY)
      {
         // For range trading, we use fixed targets instead of R:R
         m_lastSignal.takeProfit = m_bbUpper[0]; // Target the opposite band
      }
      else
      {
         m_lastSignal.takeProfit = m_bbLower[0]; // Target the opposite band
      }
      
      // Normalize take profit
      m_lastSignal.takeProfit = CPriceUtils::NormalizePrice(m_lastSignal.takeProfit);
      
      // Calculate lot size
      if(g_RiskManager != NULL)
      {
         m_lastSignal.lotSize = g_RiskManager.CalculatePositionSize(
            m_lastSignal.entryPrice, m_lastSignal.stopLoss);
      }
      
      m_lastSignal.signalTime = TimeCurrent();
   }
   
   //+------------------------------------------------------------------+
   //| Build signal reason string                                        |
   //+------------------------------------------------------------------+
   string BuildSignalReason(string direction, bool band, bool rsi, 
                           bool priceAction, bool level)
   {
      string reason = "Range Trading " + direction + " Signal:\n";
      
      reason += "• Bollinger Band: " + (band ? "TOUCHED" : "NOT TOUCHED") + "\n";
      reason += "• RSI (" + DoubleToString(m_rsi, 2) + "): " + (rsi ? "VALID" : "INVALID") + "\n";
      reason += "• Price Action: " + (priceAction ? "REVERSAL PATTERN" : "NO PATTERN") + "\n";
      reason += "• H4 Level: " + (level ? "SAFE DISTANCE" : "TOO CLOSE") + "\n";
      
      // Add band values
      reason += "\nBand Values:\n";
      reason += "• Upper: " + DoubleToString(m_bbUpper[0], _Digits) + "\n";
      reason += "• Middle: " + DoubleToString(m_bbMiddle[0], _Digits) + "\n";
      reason += "• Lower: " + DoubleToString(m_bbLower[0], _Digits);
      
      return reason;
   }
   
   //+------------------------------------------------------------------+
   //| Reset signal                                                      |
   //+------------------------------------------------------------------+
   void ResetSignal()
   {
      m_lastSignal.isValid = false;
      m_lastSignal.orderType = ORDER_TYPE_BUY;
      m_lastSignal.entryPrice = 0;
      m_lastSignal.stopLoss = 0;
      m_lastSignal.takeProfit = 0;
      m_lastSignal.lotSize = 0;
      m_lastSignal.signalReason = "";
      m_lastSignal.signalTime = 0;
   }
   
   //+------------------------------------------------------------------+
   //| Release indicator handles                                         |
   //+------------------------------------------------------------------+
   void ReleaseIndicators()
   {
      if(m_handleBB != INVALID_HANDLE)
      {
         IndicatorRelease(m_handleBB);
         m_handleBB = INVALID_HANDLE;
      }
      
      if(m_handleRSI != INVALID_HANDLE)
      {
         IndicatorRelease(m_handleRSI);
         m_handleRSI = INVALID_HANDLE;
      }
   }
};

//+------------------------------------------------------------------+ 