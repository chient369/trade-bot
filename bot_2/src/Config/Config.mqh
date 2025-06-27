//+------------------------------------------------------------------+
//|                                                      Config.mqh   |
//|                                      XAU/USD Trading Bot Config   |
//|                                                   Version 1.0.0   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ChienTV"
#property link      "https://github.com/chient369/trading-bot.git"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Input Parameters - User configurable settings                     |
//+------------------------------------------------------------------+

// == GENERAL SETTINGS ==
input int            MagicNumber = 20240625;           // Magic number for EA identification
input string         EA_Comment = "XAU_TradingBot";    // Comment for trades
input bool           EnableLogging = true;              // Enable detailed logging
input bool           EnableAlerts = true;               // Enable trading alerts

// == RISK MANAGEMENT ==
input double         RiskPerTrade = 1.0;                // Risk per trade (%)
input double         MaxDailyLoss = 2.0;                // Maximum daily loss (%)
input double         MinRiskReward = 1.5;               // Minimum Risk:Reward ratio
input double         StrongTrendRR = 2.0;               // Risk:Reward for strong trends
input int            MaxConcurrentTrades = 1;           // Maximum concurrent trades
input double         MaxSpreadPips = 3.0;               // Maximum allowed spread (pips)
input double         GapProtectionPips = 50.0;          // Gap protection threshold (pips)

// == TRADING TIME FILTER ==
input int            TradingStartHour = 8;              // Trading start hour (London time)
input int            TradingEndHour = 22;               // Trading end hour (London time)
input bool           AvoidLowLiquidity = true;          // Avoid low liquidity periods
input bool           CloseOnFriday = true;              // Close all positions on Friday
input int            FridayCloseHour = 20;              // Friday close hour (GMT)

// == NEWS FILTER ==
input bool           UseNewsFilter = true;              // Enable news filter
input int            NewsBeforeMinutes = 30;            // Pause before high impact news (minutes)
input int            NewsAfterMinutes = 30;             // Pause after high impact news (minutes)
input int            CloseBeforeNewsMinutes = 15;       // Close positions before news (minutes)

// == MARKET ANALYSIS (H4) ==
input int            EMA_Period = 200;                  // EMA period for trend detection
input int            ADX_Period = 14;                   // ADX period
input double         ADX_StrongTrend = 30.0;            // ADX strong trend threshold
input double         ADX_ModerateTrend = 25.0;          // ADX moderate trend threshold
input int            ATR_Period = 14;                   // ATR period for volatility

// == TREND FOLLOWING STRATEGY (M15) ==
input int            FastEMA_Period = 12;               // Fast EMA period
input int            SlowEMA_Period = 26;               // Slow EMA period
input int            RSI_Period = 14;                   // RSI period
input double         RSI_BuyMin = 45.0;                 // RSI minimum for buy
input double         RSI_BuyMax = 70.0;                 // RSI maximum for buy
input double         RSI_SellMin = 30.0;                // RSI minimum for sell
input double         RSI_SellMax = 55.0;                // RSI maximum for sell
input int            MACD_Fast = 12;                    // MACD fast period
input int            MACD_Slow = 26;                    // MACD slow period
input int            MACD_Signal = 9;                   // MACD signal period
input double         MinBodyPercent = 60.0;             // Minimum candle body percentage
input int            VolumeAvgPeriod = 20;              // Volume average period

// == RANGE TRADING STRATEGY (M15) ==
input int            BB_Period = 21;                    // Bollinger Bands period
input double         BB_Deviation = 2.1;                // Bollinger Bands deviation
input double         RSI_OversoldLevel = 35.0;          // RSI oversold level
input double         RSI_OverboughtLevel = 65.0;        // RSI overbought level
input double         SupportResistanceBuffer = 10.0;    // S/R buffer in pips

// == STOP LOSS & TAKE PROFIT ==
input double         MinStopLossPips = 20.0;            // Minimum stop loss (pips)
input double         MinTakeProfitPips = 30.0;          // Minimum take profit (pips)
input bool           UseTrailingStop = true;            // Enable trailing stop
input double         TrailingActivationRR = 1.0;        // Trailing stop activation (R:R)
input double         TrailingDistancePercent = 50.0;    // Trailing distance (% of initial SL)

// == PERFORMANCE TRACKING ==
input int            MaxConsecutiveLosses = 3;          // Max consecutive losses before pause
input int            PauseAfterLossesHours = 4;         // Pause duration after max losses (hours)
input bool           EnablePerformanceReport = true;    // Enable daily performance report

//+------------------------------------------------------------------+
//| Global Constants                                                  |
//+------------------------------------------------------------------+
#define POINT_VALUE      _Point
#define PIPS_FACTOR      10                             // For 5-digit brokers
#define MAX_SLIPPAGE     2                              // Maximum slippage in pips

//+------------------------------------------------------------------+
//| Enumerations                                                      |
//+------------------------------------------------------------------+
enum ENUM_MARKET_STATE
{
   MARKET_STRONG_UPTREND,     // Strong uptrend (ADX > 30, Price > EMA200)
   MARKET_MODERATE_UPTREND,   // Moderate uptrend (ADX 25-30, Price > EMA200)
   MARKET_STRONG_DOWNTREND,   // Strong downtrend (ADX > 30, Price < EMA200)
   MARKET_MODERATE_DOWNTREND, // Moderate downtrend (ADX 25-30, Price < EMA200)
   MARKET_SIDEWAYS,           // Sideways market (ADX < 25)
   MARKET_UNDEFINED           // Undefined state
};

enum ENUM_LOG_LEVEL
{
   LOG_ERROR = 0,             // Critical errors
   LOG_WARNING = 1,           // Warnings
   LOG_INFO = 2,              // General information
   LOG_ENTRY = 3,             // Trade entry details
   LOG_DEBUG = 4              // Debug information
};

enum ENUM_TRADING_STRATEGY
{
   STRATEGY_NONE,             // No active strategy
   STRATEGY_TREND_FOLLOWING,  // Trend following strategy
   STRATEGY_RANGE_TRADING     // Range trading strategy
};

//+------------------------------------------------------------------+
//| Structure Definitions                                             |
//+------------------------------------------------------------------+
struct TradeSignal
{
   bool              isValid;           // Signal validity
   ENUM_ORDER_TYPE   orderType;         // Order type (BUY/SELL)
   double            entryPrice;        // Entry price
   double            stopLoss;          // Stop loss price
   double            takeProfit;        // Take profit price
   double            lotSize;           // Calculated lot size
   string            signalReason;      // Reason for signal
   datetime          signalTime;        // Signal generation time
};

struct MarketConditions
{
   ENUM_MARKET_STATE state;             // Current market state
   double            ema200;            // EMA 200 value
   double            adxValue;          // ADX value
   double            atrValue;          // ATR value
   double            currentSpread;     // Current spread
   bool              isTradingAllowed;  // Trading allowed flag
   string            restrictionReason; // Reason for trading restriction
};

struct PerformanceMetrics
{
   int               totalTrades;       // Total trades
   int               winningTrades;     // Winning trades
   int               losingTrades;      // Losing trades
   double            totalProfit;       // Total profit
   double            totalLoss;         // Total loss
   double            maxDrawdown;       // Maximum drawdown
   double            profitFactor;      // Profit factor
   double            winRate;           // Win rate percentage
   datetime          lastTradeTime;     // Last trade time
   int               consecutiveLosses; // Current consecutive losses
};

//+------------------------------------------------------------------+
//| Validation Functions                                              |
//+------------------------------------------------------------------+
bool ValidateInputParameters()
{
   bool isValid = true;
   string errorMsg = "";
   
   // Validate risk parameters
   if(RiskPerTrade <= 0 || RiskPerTrade > 5)
   {
      errorMsg += "Invalid RiskPerTrade. Must be between 0.1 and 5.0\n";
      isValid = false;
   }
   
   if(MaxDailyLoss <= RiskPerTrade)
   {
      errorMsg += "MaxDailyLoss must be greater than RiskPerTrade\n";
      isValid = false;
   }
   
   if(MinRiskReward < 1.0)
   {
      errorMsg += "MinRiskReward must be at least 1.0\n";
      isValid = false;
   }
   
   // Validate indicator parameters
   if(EMA_Period < 50 || EMA_Period > 500)
   {
      errorMsg += "Invalid EMA_Period. Recommended range: 50-500\n";
      isValid = false;
   }
   
   if(ADX_Period < 10 || ADX_Period > 30)
   {
      errorMsg += "Invalid ADX_Period. Recommended range: 10-30\n";
      isValid = false;
   }
   
   // Validate trading hours
   if(TradingStartHour < 0 || TradingStartHour > 23 || 
      TradingEndHour < 0 || TradingEndHour > 23)
   {
      errorMsg += "Invalid trading hours. Must be between 0-23\n";
      isValid = false;
   }
   
   if(!isValid)
   {
      Print("=== CONFIGURATION ERROR ===");
      Print(errorMsg);
      Print("========================");
   }
   
   return isValid;
}

//+------------------------------------------------------------------+
//| Helper Functions                                                  |
//+------------------------------------------------------------------+
double PipsToPrice(double pips)
{
   return pips * POINT_VALUE * PIPS_FACTOR;
}

double PriceToPips(double priceDistance)
{
   return priceDistance / (POINT_VALUE * PIPS_FACTOR);
}

string MarketStateToString(ENUM_MARKET_STATE state)
{
   switch(state)
   {
      case MARKET_STRONG_UPTREND:     return "STRONG UPTREND";
      case MARKET_MODERATE_UPTREND:   return "MODERATE UPTREND";
      case MARKET_STRONG_DOWNTREND:   return "STRONG DOWNTREND";
      case MARKET_MODERATE_DOWNTREND: return "MODERATE DOWNTREND";
      case MARKET_SIDEWAYS:           return "SIDEWAYS";
      default:                        return "UNDEFINED";
   }
}

//+------------------------------------------------------------------+ 