//+------------------------------------------------------------------+
//|                                              MarketAnalysis.mqh   |
//|                              H4 Market State Analysis Module      |
//|                                                   Version 1.0.0   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ChienTV"
#property link      "https://github.com/chient369/trading-bot.git"
#property version   "1.00"

#include "../../Config/Config.mqh"
#include "../Common/Logger.mqh"
#include "../Common/Utils.mqh"

//+------------------------------------------------------------------+
//| Market Analysis Class - H4 Timeframe Analysis                     |
//+------------------------------------------------------------------+
class CMarketAnalysis
{
private:
   // Indicator handles
   int               m_handleEMA;          // EMA indicator handle
   int               m_handleADX;          // ADX indicator handle
   int               m_handleATR;          // ATR indicator handle
   
   // Current market data
   double            m_ema200;             // Current EMA 200 value
   double            m_adxValue;           // Current ADX value
   double            m_adxPlusDI;          // Current +DI value
   double            m_adxMinusDI;         // Current -DI value
   double            m_atrValue;           // Current ATR value
   
   // Market state
   ENUM_MARKET_STATE m_currentState;       // Current market state
   datetime          m_lastH4Time;         // Last H4 candle time
   datetime          m_stateUpdateTime;    // When state was last updated
   
   // Market conditions
   MarketConditions  m_conditions;         // Current market conditions
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CMarketAnalysis()
   {
      m_handleEMA = INVALID_HANDLE;
      m_handleADX = INVALID_HANDLE;
      m_handleATR = INVALID_HANDLE;
      
      m_currentState = MARKET_UNDEFINED;
      m_lastH4Time = 0;
      m_stateUpdateTime = 0;
      
      InitializeIndicators();
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                        |
   //+------------------------------------------------------------------+
   ~CMarketAnalysis()
   {
      ReleaseIndicators();
   }
   
   //+------------------------------------------------------------------+
   //| Initialize indicators                                             |
   //+------------------------------------------------------------------+
   bool InitializeIndicators()
   {
      // Create EMA indicator on H4
      m_handleEMA = iMA(_Symbol, PERIOD_H4, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
      if(m_handleEMA == INVALID_HANDLE)
      {
         LogError("Failed to create EMA indicator");
         return false;
      }
      
      // Create ADX indicator on H4
      m_handleADX = iADX(_Symbol, PERIOD_H4, ADX_Period);
      if(m_handleADX == INVALID_HANDLE)
      {
         LogError("Failed to create ADX indicator");
         return false;
      }
      
      // Create ATR indicator on H4
      m_handleATR = iATR(_Symbol, PERIOD_H4, ATR_Period);
      if(m_handleATR == INVALID_HANDLE)
      {
         LogError("Failed to create ATR indicator");
         return false;
      }
      
      LogInfo("Market analysis indicators initialized successfully");
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Update market analysis (call on each tick)                        |
   //+------------------------------------------------------------------+
   void Update()
   {
      // Check if new H4 candle formed
      if(CTimeUtils::IsNewH4Candle(m_lastH4Time))
      {
         UpdateMarketState();
      }
      
      // Always update current conditions
      UpdateCurrentConditions();
   }
   
   //+------------------------------------------------------------------+
   //| Get current market state                                          |
   //+------------------------------------------------------------------+
   ENUM_MARKET_STATE GetMarketState()
   {
      return m_currentState;
   }
   
   //+------------------------------------------------------------------+
   //| Get current market conditions                                     |
   //+------------------------------------------------------------------+
   MarketConditions GetMarketConditions()
   {
      return m_conditions;
   }
   
   //+------------------------------------------------------------------+
   //| Get trend strength description                                    |
   //+------------------------------------------------------------------+
   string GetTrendStrength()
   {
      if(m_adxValue >= ADX_StrongTrend)
         return "STRONG";
      else if(m_adxValue >= ADX_ModerateTrend)
         return "MODERATE";
      else
         return "WEAK";
   }
   
   //+------------------------------------------------------------------+
   //| Check if market is trending                                       |
   //+------------------------------------------------------------------+
   bool IsTrending()
   {
      return (m_currentState == MARKET_STRONG_UPTREND ||
              m_currentState == MARKET_MODERATE_UPTREND ||
              m_currentState == MARKET_STRONG_DOWNTREND ||
              m_currentState == MARKET_MODERATE_DOWNTREND);
   }
   
   //+------------------------------------------------------------------+
   //| Check if market is in uptrend                                    |
   //+------------------------------------------------------------------+
   bool IsUptrend()
   {
      return (m_currentState == MARKET_STRONG_UPTREND ||
              m_currentState == MARKET_MODERATE_UPTREND);
   }
   
   //+------------------------------------------------------------------+
   //| Check if market is in downtrend                                  |
   //+------------------------------------------------------------------+
   bool IsDowntrend()
   {
      return (m_currentState == MARKET_STRONG_DOWNTREND ||
              m_currentState == MARKET_MODERATE_DOWNTREND);
   }
   
   //+------------------------------------------------------------------+
   //| Check if market is sideways                                       |
   //+------------------------------------------------------------------+
   bool IsSideways()
   {
      return m_currentState == MARKET_SIDEWAYS;
   }
   
   //+------------------------------------------------------------------+
   //| Get H4 support and resistance levels                              |
   //+------------------------------------------------------------------+
   void GetSupportResistanceLevels(double &support, double &resistance)
   {
      support = 0;
      resistance = 0;
      
      // Look for recent swing highs and lows on H4
      double swingHigh = 0;
      double swingLow = DBL_MAX;
      
      for(int i = 1; i < 50; i++) // Check last 50 H4 candles
      {
         double high = iHigh(_Symbol, PERIOD_H4, i);
         double low = iLow(_Symbol, PERIOD_H4, i);
         
         // Check for swing high
         if(i > 1 && i < 49)
         {
            double prevHigh = iHigh(_Symbol, PERIOD_H4, i + 1);
            double nextHigh = iHigh(_Symbol, PERIOD_H4, i - 1);
            
            if(high > prevHigh && high > nextHigh && high > swingHigh)
            {
               swingHigh = high;
            }
         }
         
         // Check for swing low
         if(i > 1 && i < 49)
         {
            double prevLow = iLow(_Symbol, PERIOD_H4, i + 1);
            double nextLow = iLow(_Symbol, PERIOD_H4, i - 1);
            
            if(low < prevLow && low < nextLow && low < swingLow)
            {
               swingLow = low;
            }
         }
      }
      
      support = swingLow != DBL_MAX ? swingLow : 0;
      resistance = swingHigh;
   }
   
   //+------------------------------------------------------------------+
   //| Get market volatility state                                       |
   //+------------------------------------------------------------------+
   string GetVolatilityState()
   {
      double atrPips = PriceToPips(m_atrValue);
      
      if(atrPips > 200)
         return "EXTREME";
      else if(atrPips > 150)
         return "HIGH";
      else if(atrPips > 100)
         return "NORMAL";
      else
         return "LOW";
   }
   
private:
   //+------------------------------------------------------------------+
   //| Update market state (called on new H4 candle)                     |
   //+------------------------------------------------------------------+
   void UpdateMarketState()
   {
      if(g_Logger != NULL)
      {
         g_Logger.StartExecutionTracking("UpdateMarketState");
      }
      
      // Get indicator values
      if(!UpdateIndicatorValues())
      {
         LogError("Failed to update indicator values");
         return;
      }
      
      // Determine market state
      ENUM_MARKET_STATE previousState = m_currentState;
      m_currentState = DetermineMarketState();
      
      // Log state change
      if(previousState != m_currentState)
      {
         LogInfo("Market state changed from " + MarketStateToString(previousState) +
                " to " + MarketStateToString(m_currentState));
      }
      
      // Update state time
      m_stateUpdateTime = TimeCurrent();
      
      // Log market analysis
      if(g_Logger != NULL)
      {
         g_Logger.LogMarketAnalysis(m_ema200, m_adxValue, m_atrValue, 
                                   m_currentState, GetTrendStrength());
         g_Logger.EndExecutionTracking();
      }
   }
   
   //+------------------------------------------------------------------+
   //| Update current conditions (called on each tick)                   |
   //+------------------------------------------------------------------+
   void UpdateCurrentConditions()
   {
      m_conditions.state = m_currentState;
      m_conditions.ema200 = m_ema200;
      m_conditions.adxValue = m_adxValue;
      m_conditions.atrValue = m_atrValue;
      m_conditions.currentSpread = CPriceUtils::GetCurrentSpreadPips();
      
      // Check if trading is allowed
      string restrictionReason = "";
      m_conditions.isTradingAllowed = CheckTradingConditions(restrictionReason);
      m_conditions.restrictionReason = restrictionReason;
   }
   
   //+------------------------------------------------------------------+
   //| Update indicator values from buffers                              |
   //+------------------------------------------------------------------+
   bool UpdateIndicatorValues()
   {
      double emaBuffer[], adxBuffer[], plusDIBuffer[], minusDIBuffer[], atrBuffer[];
      
      // Copy EMA values
      if(CopyBuffer(m_handleEMA, 0, 0, 2, emaBuffer) != 2)
      {
         LogError("Failed to copy EMA buffer");
         return false;
      }
      m_ema200 = emaBuffer[0];
      
      // Copy ADX values
      if(CopyBuffer(m_handleADX, 0, 0, 2, adxBuffer) != 2)
      {
         LogError("Failed to copy ADX buffer");
         return false;
      }
      m_adxValue = adxBuffer[0];
      
      // Copy +DI values
      if(CopyBuffer(m_handleADX, 1, 0, 2, plusDIBuffer) != 2)
      {
         LogError("Failed to copy +DI buffer");
         return false;
      }
      m_adxPlusDI = plusDIBuffer[0];
      
      // Copy -DI values
      if(CopyBuffer(m_handleADX, 2, 0, 2, minusDIBuffer) != 2)
      {
         LogError("Failed to copy -DI buffer");
         return false;
      }
      m_adxMinusDI = minusDIBuffer[0];
      
      // Copy ATR values
      if(CopyBuffer(m_handleATR, 0, 0, 2, atrBuffer) != 2)
      {
         LogError("Failed to copy ATR buffer");
         return false;
      }
      m_atrValue = atrBuffer[0];
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Determine market state based on indicators                        |
   //+------------------------------------------------------------------+
   ENUM_MARKET_STATE DetermineMarketState()
   {
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      bool priceAboveEMA = currentPrice > m_ema200;
      bool pricebelowEMA = currentPrice < m_ema200;
      
      // Check ADX for trend strength
      if(m_adxValue >= ADX_StrongTrend)
      {
         // Strong trend
         if(priceAboveEMA && m_adxPlusDI > m_adxMinusDI)
         {
            return MARKET_STRONG_UPTREND;
         }
         else if(pricebelowEMA && m_adxMinusDI > m_adxPlusDI)
         {
            return MARKET_STRONG_DOWNTREND;
         }
      }
      else if(m_adxValue >= ADX_ModerateTrend)
      {
         // Moderate trend
         if(priceAboveEMA && m_adxPlusDI > m_adxMinusDI)
         {
            return MARKET_MODERATE_UPTREND;
         }
         else if(pricebelowEMA && m_adxMinusDI > m_adxPlusDI)
         {
            return MARKET_MODERATE_DOWNTREND;
         }
      }
      
      // If ADX < 25 or mixed signals, market is sideways
      return MARKET_SIDEWAYS;
   }
   
   //+------------------------------------------------------------------+
   //| Check if trading conditions are met                               |
   //+------------------------------------------------------------------+
   bool CheckTradingConditions(string &reason)
   {
      // Check trading hours
      if(!CTimeUtils::IsWithinTradingHours())
      {
         reason = "Outside trading hours";
         return false;
      }
      
      // Check spread
      if(!CPriceUtils::IsSpreadAcceptable())
      {
         reason = "Spread too high";
         return false;
      }
      
      // Check volatility
      double atrPips = PriceToPips(m_atrValue);
      if(atrPips > 300) // Extreme volatility
      {
         reason = "Extreme volatility (ATR: " + DoubleToString(atrPips, 1) + " pips)";
         return false;
      }
      
      // Check if market state is defined
      if(m_currentState == MARKET_UNDEFINED)
      {
         reason = "Market state undefined";
         return false;
      }
      
      reason = "All conditions met";
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Release indicator handles                                         |
   //+------------------------------------------------------------------+
   void ReleaseIndicators()
   {
      if(m_handleEMA != INVALID_HANDLE)
      {
         IndicatorRelease(m_handleEMA);
         m_handleEMA = INVALID_HANDLE;
      }
      
      if(m_handleADX != INVALID_HANDLE)
      {
         IndicatorRelease(m_handleADX);
         m_handleADX = INVALID_HANDLE;
      }
      
      if(m_handleATR != INVALID_HANDLE)
      {
         IndicatorRelease(m_handleATR);
         m_handleATR = INVALID_HANDLE;
      }
   }
};

//+------------------------------------------------------------------+
//| Global market analysis instance                                    |
//+------------------------------------------------------------------+
CMarketAnalysis* g_MarketAnalysis = NULL;

//+------------------------------------------------------------------+
//| Initialize global market analysis                                  |
//+------------------------------------------------------------------+
void InitializeMarketAnalysis()
{
   if(g_MarketAnalysis == NULL)
   {
      g_MarketAnalysis = new CMarketAnalysis();
   }
}

//+------------------------------------------------------------------+
//| Cleanup global market analysis                                     |
//+------------------------------------------------------------------+
void CleanupMarketAnalysis()
{
   if(g_MarketAnalysis != NULL)
   {
      delete g_MarketAnalysis;
      g_MarketAnalysis = NULL;
   }
}

//+------------------------------------------------------------------+