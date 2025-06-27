//+------------------------------------------------------------------+
//|                                              RiskManagement.mqh   |
//|                                  Risk Management & Money Control  |
//|                                                   Version 1.0.0   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ChienTV"
#property link      "https://github.com/chient369/trading-bot.git"
#property version   "1.00"

#include "../../Config/Config.mqh"
#include "Logger.mqh"
#include "Utils.mqh"

//+------------------------------------------------------------------+
//| Risk Management Class                                              |
//+------------------------------------------------------------------+
class CRiskManagement
{
private:
   double            m_accountEquity;        // Current account equity
   double            m_accountBalance;       // Current account balance
   double            m_dailyStartBalance;    // Balance at start of day
   double            m_dailyProfitLoss;      // Today's P&L
   datetime          m_lastDailyCheck;       // Last daily check time
   datetime          m_pauseTradingUntil;    // Pause trading until this time
   
   PerformanceMetrics m_performance;         // Performance tracking
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CRiskManagement()
   {
      UpdateAccountInfo();
      ResetDailyTracking();
      m_pauseTradingUntil = 0;
      
      // Initialize performance metrics
      ResetPerformanceMetrics();
   }
   
   //+------------------------------------------------------------------+
   //| Update account information                                        |
   //+------------------------------------------------------------------+
   void UpdateAccountInfo()
   {
      m_accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      m_accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   }
   
   //+------------------------------------------------------------------+
   //| Calculate position size based on risk parameters                  |
   //+------------------------------------------------------------------+
   double CalculatePositionSize(double entryPrice, double stopLossPrice)
   {
      UpdateAccountInfo();
      
      // Calculate risk amount
      double riskAmount = m_accountEquity * RiskPerTrade / 100;
      
      // Calculate stop loss distance
      double stopLossDistance = MathAbs(entryPrice - stopLossPrice);
      double stopLossPips = PriceToPips(stopLossDistance);
      
      // Check minimum stop loss
      if(stopLossPips < MinStopLossPips)
      {
         LogWarning("Stop loss too small: " + DoubleToString(stopLossPips, 1) + 
                    " pips. Minimum required: " + DoubleToString(MinStopLossPips, 1));
         stopLossPips = MinStopLossPips;
         stopLossDistance = PipsToPrice(stopLossPips);
      }
      
      // Calculate pip value
      double pipValue = CPriceUtils::GetPipValue();
      
      if(pipValue <= 0 || stopLossPips <= 0)
      {
         LogError("Invalid pip value or stop loss distance");
         return 0;
      }
      
      // Calculate lot size
      double lotSize = riskAmount / (stopLossPips * pipValue);
      
      // Apply broker constraints
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      
      // Normalize lot size
      lotSize = MathMax(minLot, lotSize);
      lotSize = MathMin(maxLot, lotSize);
      lotSize = NormalizeDouble(MathRound(lotSize / lotStep) * lotStep, 2);
      
      // Log position sizing calculation
      if(g_Logger != NULL)
      {
         g_Logger.LogPositionSizing(stopLossPrice, entryPrice, 
                                   riskAmount / (stopLossPips * pipValue), lotSize);
      }
      
      // Final check - ensure we have enough free margin
      double requiredMargin = GetRequiredMargin(lotSize, entryPrice);
      double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      
      if(requiredMargin > freeMargin * 0.9) // Use max 90% of free margin
      {
         LogWarning("Insufficient free margin. Required: $" + 
                    DoubleToString(requiredMargin, 2) + 
                    ", Available: $" + DoubleToString(freeMargin, 2));
         return 0;
      }
      
      return lotSize;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate stop loss price based on market structure               |
   //+------------------------------------------------------------------+
   double CalculateStopLoss(ENUM_ORDER_TYPE orderType, double entryPrice)
   {
      double stopLoss = 0;
      double minStopDistance = PipsToPrice(MinStopLossPips);
      
      if(orderType == ORDER_TYPE_BUY)
      {
         // Find recent swing low
         double swingLow = CPriceUtils::FindSwingLow(20);
         
         if(swingLow > 0)
         {
            stopLoss = swingLow - PipsToPrice(2); // Add 2 pips buffer
            
            // Ensure minimum distance
            if(entryPrice - stopLoss < minStopDistance)
            {
               stopLoss = entryPrice - minStopDistance;
            }
         }
         else
         {
            stopLoss = entryPrice - minStopDistance;
         }
      }
      else if(orderType == ORDER_TYPE_SELL)
      {
         // Find recent swing high
         double swingHigh = CPriceUtils::FindSwingHigh(20);
         
         if(swingHigh > 0)
         {
            stopLoss = swingHigh + PipsToPrice(2); // Add 2 pips buffer
            
            // Ensure minimum distance
            if(stopLoss - entryPrice < minStopDistance)
            {
               stopLoss = entryPrice + minStopDistance;
            }
         }
         else
         {
            stopLoss = entryPrice + minStopDistance;
         }
      }
      
      return CPriceUtils::NormalizePrice(stopLoss);
   }
   
   //+------------------------------------------------------------------+
   //| Calculate take profit based on risk/reward ratio                  |
   //+------------------------------------------------------------------+
   double CalculateTakeProfit(ENUM_ORDER_TYPE orderType, double entryPrice, 
                             double stopLoss, double riskRewardRatio)
   {
      double stopDistance = MathAbs(entryPrice - stopLoss);
      double tpDistance = stopDistance * riskRewardRatio;
      double takeProfit = 0;
      
      if(orderType == ORDER_TYPE_BUY)
      {
         takeProfit = entryPrice + tpDistance;
      }
      else if(orderType == ORDER_TYPE_SELL)
      {
         takeProfit = entryPrice - tpDistance;
      }
      
      // Ensure minimum take profit distance
      double tpPips = PriceToPips(tpDistance);
      if(tpPips < MinTakeProfitPips)
      {
         tpDistance = PipsToPrice(MinTakeProfitPips);
         
         if(orderType == ORDER_TYPE_BUY)
            takeProfit = entryPrice + tpDistance;
         else
            takeProfit = entryPrice - tpDistance;
      }
      
      return CPriceUtils::NormalizePrice(takeProfit);
   }
   
   //+------------------------------------------------------------------+
   //| Check if trading is allowed based on risk rules                   |
   //+------------------------------------------------------------------+
   bool IsTradingAllowed(string &reason)
   {
      UpdateAccountInfo();
      reason = "";
      
      // Check daily loss limit
      if(IsDailyLossLimitExceeded())
      {
         reason = "Daily loss limit exceeded";
         return false;
      }
      
      // Check consecutive losses pause
      if(IsInConsecutiveLossesPause())
      {
         reason = "Paused due to consecutive losses";
         return false;
      }
      
      // Check account health
      if(!IsAccountHealthy())
      {
         reason = "Account health check failed";
         return false;
      }
      
      // Check margin level
      double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
      if(marginLevel > 0 && marginLevel < 200) // Below 200% margin level
      {
         reason = "Low margin level: " + DoubleToString(marginLevel, 1) + "%";
         return false;
      }
      
      // Check spread
      if(!CPriceUtils::IsSpreadAcceptable())
      {
         reason = "Spread too high: " + 
                  DoubleToString(CPriceUtils::GetCurrentSpreadPips(), 1) + " pips";
         return false;
      }
      
      // Check for price gaps
      double gapSize;
      if(CPriceUtils::HasPriceGap(gapSize))
      {
         reason = "Price gap detected: " + 
                  DoubleToString(PriceToPips(gapSize), 1) + " pips";
         return false;
      }
      
      // Check trading time
      if(!CTimeUtils::IsWithinTradingHours())
      {
         reason = "Outside trading hours";
         return false;
      }
      
      // Check if we have available trade slots
      if(!COrderUtils::CanOpenNewTrade())
      {
         reason = "Maximum concurrent trades reached";
         return false;
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Update performance metrics after trade closes                     |
   //+------------------------------------------------------------------+
   void UpdatePerformanceMetrics(double profit, bool isWin)
   {
      m_performance.totalTrades++;
      
      if(isWin)
      {
         m_performance.winningTrades++;
         m_performance.totalProfit += profit;
         m_performance.consecutiveLosses = 0;
      }
      else
      {
         m_performance.losingTrades++;
         m_performance.totalLoss += MathAbs(profit);
         m_performance.consecutiveLosses++;
      }
      
      // Update win rate
      if(m_performance.totalTrades > 0)
      {
         m_performance.winRate = (double)m_performance.winningTrades / 
                                m_performance.totalTrades * 100;
      }
      
      // Update profit factor
      if(m_performance.totalLoss > 0)
      {
         m_performance.profitFactor = m_performance.totalProfit / m_performance.totalLoss;
      }
      
      // Update drawdown
      UpdateDrawdown();
      
      // Update last trade time
      m_performance.lastTradeTime = TimeCurrent();
      
      // Update daily P&L
      m_dailyProfitLoss = COrderUtils::GetTodayProfitLoss();
   }
   
   //+------------------------------------------------------------------+
   //| Get current risk/reward ratio based on market state               |
   //+------------------------------------------------------------------+
   double GetRiskRewardRatio(ENUM_MARKET_STATE marketState)
   {
      switch(marketState)
      {
         case MARKET_STRONG_UPTREND:
         case MARKET_STRONG_DOWNTREND:
            return StrongTrendRR;
            
         case MARKET_MODERATE_UPTREND:
         case MARKET_MODERATE_DOWNTREND:
         case MARKET_SIDEWAYS:
            return MinRiskReward;
            
         default:
            return MinRiskReward;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Apply trailing stop to open positions                             |
   //+------------------------------------------------------------------+
   void ApplyTrailingStop()
   {
      if(!UseTrailingStop) return;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionSelectByTicket(PositionGetTicket(i)))
         {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
               PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            {
               double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
               double currentSL = PositionGetDouble(POSITION_SL);
               double currentTP = PositionGetDouble(POSITION_TP);
               double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
               
               // Calculate initial stop loss distance
               double initialSLDistance = MathAbs(openPrice - currentSL);
               double trailDistance = initialSLDistance * TrailingDistancePercent / 100;
               
               bool shouldModify = false;
               double newSL = currentSL;
               
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
               {
                  // Check if we've reached trailing activation level
                  double profitPips = PriceToPips(currentPrice - openPrice);
                  double slPips = PriceToPips(initialSLDistance);
                  
                  if(profitPips >= slPips * TrailingActivationRR)
                  {
                     double proposedSL = currentPrice - trailDistance;
                     if(proposedSL > currentSL)
                     {
                        newSL = CPriceUtils::NormalizePrice(proposedSL);
                        shouldModify = true;
                     }
                  }
               }
               else // SELL position
               {
                  // Check if we've reached trailing activation level
                  double profitPips = PriceToPips(openPrice - currentPrice);
                  double slPips = PriceToPips(initialSLDistance);
                  
                  if(profitPips >= slPips * TrailingActivationRR)
                  {
                     double proposedSL = currentPrice + trailDistance;
                     if(proposedSL < currentSL)
                     {
                        newSL = CPriceUtils::NormalizePrice(proposedSL);
                        shouldModify = true;
                     }
                  }
               }
               
               // Modify position if needed
               if(shouldModify)
               {
                  MqlTradeRequest request = {};
                  MqlTradeResult result = {};
                  
                  request.action = TRADE_ACTION_SLTP;
                  request.position = PositionGetTicket(i);
                  request.sl = newSL;
                  request.tp = currentTP;
                  request.symbol = _Symbol;
                  request.magic = MagicNumber;
                  
                  if(OrderSend(request, result))
                  {
                     LogInfo("Trailing stop updated for position " + 
                            IntegerToString(PositionGetTicket(i)) + 
                            ". New SL: " + DoubleToString(newSL, _Digits));
                  }
               }
            }
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Get performance metrics                                           |
   //+------------------------------------------------------------------+
   PerformanceMetrics GetPerformanceMetrics()
   {
      return m_performance;
   }
   
   //+------------------------------------------------------------------+
   //| Reset daily tracking at start of new day                          |
   //+------------------------------------------------------------------+
   void CheckDailyReset()
   {
      MqlDateTime currentTime;
      TimeToStruct(TimeCurrent(), currentTime);
      
      MqlDateTime lastCheck;
      TimeToStruct(m_lastDailyCheck, lastCheck);
      
      if(currentTime.day != lastCheck.day)
      {
         ResetDailyTracking();
         
         // Log daily summary if enabled
         if(EnablePerformanceReport && m_lastDailyCheck > 0)
         {
            GenerateDailyReport();
         }
      }
   }
   
private:
   //+------------------------------------------------------------------+
   //| Reset daily tracking variables                                    |
   //+------------------------------------------------------------------+
   void ResetDailyTracking()
   {
      UpdateAccountInfo();
      m_dailyStartBalance = m_accountBalance;
      m_dailyProfitLoss = 0;
      m_lastDailyCheck = TimeCurrent();
   }
   
   //+------------------------------------------------------------------+
   //| Reset performance metrics                                         |
   //+------------------------------------------------------------------+
   void ResetPerformanceMetrics()
   {
      m_performance.totalTrades = 0;
      m_performance.winningTrades = 0;
      m_performance.losingTrades = 0;
      m_performance.totalProfit = 0;
      m_performance.totalLoss = 0;
      m_performance.maxDrawdown = 0;
      m_performance.profitFactor = 0;
      m_performance.winRate = 0;
      m_performance.lastTradeTime = 0;
      m_performance.consecutiveLosses = 0;
   }
   
   //+------------------------------------------------------------------+
   //| Check if daily loss limit exceeded                                |
   //+------------------------------------------------------------------+
   bool IsDailyLossLimitExceeded()
   {
      m_dailyProfitLoss = COrderUtils::GetTodayProfitLoss();
      double maxLossAmount = m_accountEquity * MaxDailyLoss / 100;
      
      return m_dailyProfitLoss < -maxLossAmount;
   }
   
   //+------------------------------------------------------------------+
   //| Check if in consecutive losses pause period                       |
   //+------------------------------------------------------------------+
   bool IsInConsecutiveLossesPause()
   {
      return CPerformanceUtils::ShouldPauseTrading(m_pauseTradingUntil);
   }
   
   //+------------------------------------------------------------------+
   //| Check account health                                              |
   //+------------------------------------------------------------------+
   bool IsAccountHealthy()
   {
      UpdateAccountInfo();
      
      // Check if equity is too low compared to balance
      double equityToBalance = m_accountEquity / m_accountBalance;
      if(equityToBalance < 0.8) // Equity less than 80% of balance
      {
         LogWarning("Account equity critically low: " + 
                   DoubleToString(equityToBalance * 100, 1) + "% of balance");
         return false;
      }
      
      // Check minimum equity threshold
      double minEquity = 100; // Minimum $100 equity required
      if(m_accountEquity < minEquity)
      {
         LogError("Account equity below minimum threshold: $" + 
                 DoubleToString(m_accountEquity, 2));
         return false;
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Get required margin for position                                  |
   //+------------------------------------------------------------------+
   double GetRequiredMargin(double lotSize, double price)
   {
      double leverage = (double)AccountInfoInteger(ACCOUNT_LEVERAGE);
      double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
      
      if(leverage <= 0) leverage = 1;
      
      return (lotSize * contractSize * price) / leverage;
   }
   
   //+------------------------------------------------------------------+
   //| Update maximum drawdown                                           |
   //+------------------------------------------------------------------+
   void UpdateDrawdown()
   {
      static double peakBalance = 0;
      
      double currentBalance = m_accountBalance + m_performance.totalProfit - m_performance.totalLoss;
      
      if(currentBalance > peakBalance)
      {
         peakBalance = currentBalance;
      }
      
      double drawdown = ((peakBalance - currentBalance) / peakBalance) * 100;
      
      if(drawdown > m_performance.maxDrawdown)
      {
         m_performance.maxDrawdown = drawdown;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Generate daily performance report                                  |
   //+------------------------------------------------------------------+
   void GenerateDailyReport()
   {
      if(g_Logger == NULL) return;
      
      // Get today's trades count
      int tradesToday = 0;
      datetime todayStart = StringToTime(TimeToString(m_lastDailyCheck, TIME_DATE));
      
      HistorySelect(todayStart, m_lastDailyCheck);
      for(int i = 0; i < HistoryDealsTotal(); i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol &&
            HistoryDealGetInteger(ticket, DEAL_MAGIC) == MagicNumber &&
            HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_IN)
         {
            tradesToday++;
         }
      }
      
      // Calculate strategy performance (simplified)
      string trendPerformance = "N/A";
      string rangePerformance = "N/A";
      
      if(m_performance.totalTrades > 0)
      {
         trendPerformance = "Win Rate: " + DoubleToString(m_performance.winRate, 1) + "%";
         rangePerformance = "Profit Factor: " + DoubleToString(m_performance.profitFactor, 2);
      }
      
      // Market conditions summary
      string marketConditions = "Mixed conditions throughout the day";
      
      // News impact summary
      string newsImpact = "No major news events";
      
      g_Logger.LogDailySummary(tradesToday, m_dailyProfitLoss, 
                              trendPerformance, rangePerformance,
                              marketConditions, newsImpact);
   }
};

//+------------------------------------------------------------------+
//| Global risk manager instance                                       |
//+------------------------------------------------------------------+
CRiskManagement* g_RiskManager = NULL;

//+------------------------------------------------------------------+
//| Initialize global risk manager                                     |
//+------------------------------------------------------------------+
void InitializeRiskManager()
{
   if(g_RiskManager == NULL)
   {
      g_RiskManager = new CRiskManagement();
   }
}

//+------------------------------------------------------------------+
//| Cleanup global risk manager                                        |
//+------------------------------------------------------------------+
void CleanupRiskManager()
{
   if(g_RiskManager != NULL)
   {
      delete g_RiskManager;
      g_RiskManager = NULL;
   }
}

//+------------------------------------------------------------------+ 