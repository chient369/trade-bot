//+------------------------------------------------------------------+
//|                                             TrendFollowing.mqh    |
//|                                Trend Following Strategy Module    |
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
//| Trend Following Strategy Class                                     |
//+------------------------------------------------------------------+
class CTrendFollowingStrategy
{
private:
   // Indicator handles
   int               m_handleFastEMA;      // Fast EMA handle
   int               m_handleSlowEMA;      // Slow EMA handle
   int               m_handleRSI;          // RSI handle
   int               m_handleMACD;         // MACD handle
   int               m_handleVolume;       // Volume handle
   
   // Indicator values
   double            m_fastEMA[3];         // Fast EMA values (0=current, 1=prev, 2=prev-prev)
   double            m_slowEMA[3];         // Slow EMA values
   double            m_rsi;                // Current RSI value
   double            m_macdMain;           // MACD main line
   double            m_macdSignal;         // MACD signal line
   double            m_currentVolume;      // Current volume
   double            m_avgVolume;          // Average volume
   
   // Strategy state
   datetime          m_lastSignalTime;     // Last signal generation time
   TradeSignal       m_lastSignal;         // Last generated signal
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CTrendFollowingStrategy()
   {
      m_handleFastEMA = INVALID_HANDLE;
      m_handleSlowEMA = INVALID_HANDLE;
      m_handleRSI = INVALID_HANDLE;
      m_handleMACD = INVALID_HANDLE;
      m_handleVolume = INVALID_HANDLE;
      
      m_lastSignalTime = 0;
      ResetSignal();
      
      InitializeIndicators();
      
      LogInfo("Trend Following Strategy initialized");
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                        |
   //+------------------------------------------------------------------+
   ~CTrendFollowingStrategy()
   {
      ReleaseIndicators();
   }
   
   //+------------------------------------------------------------------+
   //| Initialize strategy indicators                                     |
   //+------------------------------------------------------------------+
   bool InitializeIndicators()
   {
      // Create Fast EMA on M15
      m_handleFastEMA = iMA(_Symbol, PERIOD_M15, FastEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
      if(m_handleFastEMA == INVALID_HANDLE)
      {
         LogError("Failed to create Fast EMA indicator");
         return false;
      }
      
      // Create Slow EMA on M15
      m_handleSlowEMA = iMA(_Symbol, PERIOD_M15, SlowEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
      if(m_handleSlowEMA == INVALID_HANDLE)
      {
         LogError("Failed to create Slow EMA indicator");
         return false;
      }
      
      // Create RSI on M15
      m_handleRSI = iRSI(_Symbol, PERIOD_M15, RSI_Period, PRICE_CLOSE);
      if(m_handleRSI == INVALID_HANDLE)
      {
         LogError("Failed to create RSI indicator");
         return false;
      }
      
      // Create MACD on M15
      m_handleMACD = iMACD(_Symbol, PERIOD_M15, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
      if(m_handleMACD == INVALID_HANDLE)
      {
         LogError("Failed to create MACD indicator");
         return false;
      }
      
      // Volume indicators would be created here if supported by broker
      
      LogInfo("Trend following indicators initialized successfully");
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Check for entry signals                                           |
   //+------------------------------------------------------------------+
   TradeSignal CheckEntrySignal(ENUM_MARKET_STATE marketState)
   {
      ResetSignal();
      
      // Only check for signals in trending markets
      if(marketState != MARKET_STRONG_UPTREND && 
         marketState != MARKET_MODERATE_UPTREND &&
         marketState != MARKET_STRONG_DOWNTREND &&
         marketState != MARKET_MODERATE_DOWNTREND)
      {
         return m_lastSignal;
      }
      
      // Update indicator values
      if(!UpdateIndicatorValues())
      {
         return m_lastSignal;
      }
      
      // Check for long entry in uptrend
      if((marketState == MARKET_STRONG_UPTREND || marketState == MARKET_MODERATE_UPTREND))
      {
         CheckLongEntry();
      }
      // Check for short entry in downtrend
      else if((marketState == MARKET_STRONG_DOWNTREND || marketState == MARKET_MODERATE_DOWNTREND))
      {
         CheckShortEntry();
      }
      
      // If signal is valid, calculate trade parameters
      if(m_lastSignal.isValid)
      {
         CalculateTradeParameters(marketState);
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
      
      if(positionType == ORDER_TYPE_BUY)
      {
         // Exit long conditions
         // 1. EMA cross down
         if(m_fastEMA[0] < m_slowEMA[0] && m_fastEMA[1] >= m_slowEMA[1])
         {
            LogInfo("Exit signal: Fast EMA crossed below Slow EMA");
            shouldExit = true;
         }
         // 2. RSI overbought
         else if(m_rsi > RSI_BuyMax + 10) // RSI > 80
         {
            LogInfo("Exit signal: RSI extremely overbought (" + DoubleToString(m_rsi, 2) + ")");
            shouldExit = true;
         }
         // 3. MACD bearish divergence
         else if(m_macdMain < m_macdSignal && m_macdMain < 0)
         {
            LogInfo("Exit signal: MACD turned bearish");
            shouldExit = true;
         }
      }
      else if(positionType == ORDER_TYPE_SELL)
      {
         // Exit short conditions
         // 1. EMA cross up
         if(m_fastEMA[0] > m_slowEMA[0] && m_fastEMA[1] <= m_slowEMA[1])
         {
            LogInfo("Exit signal: Fast EMA crossed above Slow EMA");
            shouldExit = true;
         }
         // 2. RSI oversold
         else if(m_rsi < RSI_SellMin - 10) // RSI < 20
         {
            LogInfo("Exit signal: RSI extremely oversold (" + DoubleToString(m_rsi, 2) + ")");
            shouldExit = true;
         }
         // 3. MACD bullish divergence
         else if(m_macdMain > m_macdSignal && m_macdMain > 0)
         {
            LogInfo("Exit signal: MACD turned bullish");
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
      // Copy Fast EMA values
      if(CopyBuffer(m_handleFastEMA, 0, 0, 3, m_fastEMA) != 3)
      {
         LogError("Failed to copy Fast EMA buffer");
         return false;
      }
      
      // Copy Slow EMA values
      if(CopyBuffer(m_handleSlowEMA, 0, 0, 3, m_slowEMA) != 3)
      {
         LogError("Failed to copy Slow EMA buffer");
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
      
      // Copy MACD values
      double macdMainBuffer[], macdSignalBuffer[];
      if(CopyBuffer(m_handleMACD, 0, 0, 1, macdMainBuffer) != 1 ||
         CopyBuffer(m_handleMACD, 1, 0, 1, macdSignalBuffer) != 1)
      {
         LogError("Failed to copy MACD buffer");
         return false;
      }
      m_macdMain = macdMainBuffer[0];
      m_macdSignal = macdSignalBuffer[0];
      
      // Update volume (simplified - would need proper volume analysis)
      m_currentVolume = (double)iVolume(_Symbol, PERIOD_M15, 0);
      m_avgVolume = CalculateAverageVolume();
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Check for long entry conditions                                   |
   //+------------------------------------------------------------------+
   void CheckLongEntry()
   {
      // Condition 1: EMA Crossover
      bool emaCrossover = false;
      if(m_fastEMA[0] > m_slowEMA[0] && m_fastEMA[1] <= m_slowEMA[1])
      {
         emaCrossover = true;
      }
      
      // Condition 2: RSI in valid range
      bool rsiCondition = (m_rsi >= RSI_BuyMin && m_rsi <= RSI_BuyMax);
      
      // Condition 3: MACD confirmation
      bool macdCondition = (m_macdMain > m_macdSignal && m_macdMain > 0);
      
      // Condition 4: Volume confirmation
      bool volumeCondition = CheckVolumeConfirmation();
      
      // Condition 5: Price action confirmation
      bool priceActionCondition = CheckBullishPriceAction();
      
      // Log entry conditions
      if(g_Logger != NULL)
      {
         g_Logger.LogEntryConditions("LONG", emaCrossover, rsiCondition, 
                                    volumeCondition, priceActionCondition, macdCondition);
      }
      
      // All conditions must be met
      if(emaCrossover && rsiCondition && macdCondition && volumeCondition && priceActionCondition)
      {
         m_lastSignal.isValid = true;
         m_lastSignal.orderType = ORDER_TYPE_BUY;
         m_lastSignal.signalReason = BuildSignalReason("LONG", emaCrossover, rsiCondition, 
                                                       macdCondition, volumeCondition, priceActionCondition);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Check for short entry conditions                                  |
   //+------------------------------------------------------------------+
   void CheckShortEntry()
   {
      // Condition 1: EMA Crossover
      bool emaCrossover = false;
      if(m_fastEMA[0] < m_slowEMA[0] && m_fastEMA[1] >= m_slowEMA[1])
      {
         emaCrossover = true;
      }
      
      // Condition 2: RSI in valid range
      bool rsiCondition = (m_rsi >= RSI_SellMin && m_rsi <= RSI_SellMax);
      
      // Condition 3: MACD confirmation
      bool macdCondition = (m_macdMain < m_macdSignal && m_macdMain < 0);
      
      // Condition 4: Volume confirmation
      bool volumeCondition = CheckVolumeConfirmation();
      
      // Condition 5: Price action confirmation
      bool priceActionCondition = CheckBearishPriceAction();
      
      // Log entry conditions
      if(g_Logger != NULL)
      {
         g_Logger.LogEntryConditions("SHORT", emaCrossover, rsiCondition, 
                                    volumeCondition, priceActionCondition, macdCondition);
      }
      
      // All conditions must be met
      if(emaCrossover && rsiCondition && macdCondition && volumeCondition && priceActionCondition)
      {
         m_lastSignal.isValid = true;
         m_lastSignal.orderType = ORDER_TYPE_SELL;
         m_lastSignal.signalReason = BuildSignalReason("SHORT", emaCrossover, rsiCondition, 
                                                       macdCondition, volumeCondition, priceActionCondition);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Check volume confirmation                                         |
   //+------------------------------------------------------------------+
   bool CheckVolumeConfirmation()
   {
      // Simple volume check - current volume should be above average
      if(m_avgVolume > 0)
      {
         return m_currentVolume > m_avgVolume;
      }
      
      // If no volume data available, return true
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Check bullish price action                                        |
   //+------------------------------------------------------------------+
   bool CheckBullishPriceAction()
   {
      // Check if current candle has strong bullish momentum
      double bodyPercent = CPatternUtils::GetCandleBodyPercent(0);
      bool strongBody = bodyPercent >= MinBodyPercent;
      
      // Check for bullish patterns
      bool bullishPattern = CPatternUtils::IsBullishCandle(0) || 
                           CPatternUtils::IsHammer(0) ||
                           CPatternUtils::IsBullishEngulfing(0);
      
      return strongBody && bullishPattern;
   }
   
   //+------------------------------------------------------------------+
   //| Check bearish price action                                        |
   //+------------------------------------------------------------------+
   bool CheckBearishPriceAction()
   {
      // Check if current candle has strong bearish momentum
      double bodyPercent = CPatternUtils::GetCandleBodyPercent(0);
      bool strongBody = bodyPercent >= MinBodyPercent;
      
      // Check for bearish patterns
      bool bearishPattern = CPatternUtils::IsBearishCandle(0) || 
                           CPatternUtils::IsShootingStar(0) ||
                           CPatternUtils::IsBearishEngulfing(0);
      
      return strongBody && bearishPattern;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate average volume                                          |
   //+------------------------------------------------------------------+
   double CalculateAverageVolume()
   {
      double totalVolume = 0;
      
      for(int i = 1; i <= VolumeAvgPeriod; i++)
      {
         totalVolume += (double)iVolume(_Symbol, PERIOD_M15, i);
      }
      
      return totalVolume / VolumeAvgPeriod;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate trade parameters                                        |
   //+------------------------------------------------------------------+
   void CalculateTradeParameters(ENUM_MARKET_STATE marketState)
   {
      // Entry price
      if(m_lastSignal.orderType == ORDER_TYPE_BUY)
         m_lastSignal.entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      else
         m_lastSignal.entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      // Calculate stop loss
      if(g_RiskManager != NULL)
      {
         m_lastSignal.stopLoss = g_RiskManager.CalculateStopLoss(
            m_lastSignal.orderType, m_lastSignal.entryPrice);
         
         // Get appropriate R:R ratio
         double rrRatio = g_RiskManager.GetRiskRewardRatio(marketState);
         
         // Calculate take profit
         m_lastSignal.takeProfit = g_RiskManager.CalculateTakeProfit(
            m_lastSignal.orderType, m_lastSignal.entryPrice, 
            m_lastSignal.stopLoss, rrRatio);
         
         // Calculate lot size
         m_lastSignal.lotSize = g_RiskManager.CalculatePositionSize(
            m_lastSignal.entryPrice, m_lastSignal.stopLoss);
      }
      
      m_lastSignal.signalTime = TimeCurrent();
   }
   
   //+------------------------------------------------------------------+
   //| Build signal reason string                                        |
   //+------------------------------------------------------------------+
   string BuildSignalReason(string direction, bool ema, bool rsi, bool macd, 
                           bool volume, bool priceAction)
   {
      string reason = "Trend Following " + direction + " Signal:\n";
      
      reason += "• EMA Crossover: " + (ema ? "YES" : "NO") + "\n";
      reason += "• RSI (" + DoubleToString(m_rsi, 2) + "): " + (rsi ? "VALID" : "INVALID") + "\n";
      reason += "• MACD: " + (macd ? "CONFIRMED" : "NOT CONFIRMED") + "\n";
      reason += "• Volume: " + (volume ? "ABOVE AVG" : "BELOW AVG") + "\n";
      reason += "• Price Action: " + (priceAction ? "CONFIRMED" : "NOT CONFIRMED");
      
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
      if(m_handleFastEMA != INVALID_HANDLE)
      {
         IndicatorRelease(m_handleFastEMA);
         m_handleFastEMA = INVALID_HANDLE;
      }
      
      if(m_handleSlowEMA != INVALID_HANDLE)
      {
         IndicatorRelease(m_handleSlowEMA);
         m_handleSlowEMA = INVALID_HANDLE;
      }
      
      if(m_handleRSI != INVALID_HANDLE)
      {
         IndicatorRelease(m_handleRSI);
         m_handleRSI = INVALID_HANDLE;
      }
      
      if(m_handleMACD != INVALID_HANDLE)
      {
         IndicatorRelease(m_handleMACD);
         m_handleMACD = INVALID_HANDLE;
      }
   }
};

//+------------------------------------------------------------------+ 