//+------------------------------------------------------------------+
//|                                                  NewsFilter.mqh   |
//|                             Economic News Filter Implementation   |
//|                                                   Version 1.0.0   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ChienTV"
#property link      "https://github.com/chient369/trading-bot.git"
#property version   "1.00"

#include "../../Config/Config.mqh"
#include "Logger.mqh"

//+------------------------------------------------------------------+
//| News Event Structure                                               |
//+------------------------------------------------------------------+
struct NewsEvent
{
   datetime          time;              // Event time
   string            currency;          // Currency affected
   string            title;             // Event title
   int               impact;            // Impact level (1=Low, 2=Medium, 3=High)
   string            forecast;          // Forecast value
   string            previous;          // Previous value
   string            actual;            // Actual value (after release)
};

//+------------------------------------------------------------------+
//| News Filter Class                                                  |
//+------------------------------------------------------------------+
class CNewsFilter
{
private:
   NewsEvent         m_newsEvents[];    // Array of upcoming news events
   datetime          m_lastUpdateTime;  // Last time news was updated
   bool              m_isEnabled;       // News filter enabled flag
   string            m_highImpactEvents[]; // List of high impact event names
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CNewsFilter()
   {
      m_isEnabled = UseNewsFilter;
      m_lastUpdateTime = 0;
      ArrayResize(m_newsEvents, 0);
      
      // Initialize high impact events list for Gold
      InitializeHighImpactEvents();
      
      // Load news events
      if(m_isEnabled)
      {
         UpdateNewsEvents();
      }
   }
   
   //+------------------------------------------------------------------+
   //| Check if trading is allowed based on news                         |
   //+------------------------------------------------------------------+
   bool IsTradingAllowed(string &reason)
   {
      if(!m_isEnabled)
      {
         reason = "News filter disabled";
         return true;
      }
      
      // Update news if needed (every hour)
      if(TimeCurrent() - m_lastUpdateTime > 3600)
      {
         UpdateNewsEvents();
      }
      
      datetime currentTime = TimeCurrent();
      
      // Check each news event
      for(int i = 0; i < ArraySize(m_newsEvents); i++)
      {
         // Only check high impact events
         if(m_newsEvents[i].impact < 3) continue;
         
         // Check if event affects gold trading
         if(!IsGoldRelatedEvent(m_newsEvents[i])) continue;
         
         // Calculate time difference
         int minutesUntilEvent = (int)((m_newsEvents[i].time - currentTime) / 60);
         int minutesSinceEvent = (int)((currentTime - m_newsEvents[i].time) / 60);
         
         // Check if we're in the restricted window
         if(minutesUntilEvent > 0 && minutesUntilEvent <= NewsBeforeMinutes)
         {
            reason = "High impact news in " + IntegerToString(minutesUntilEvent) + 
                    " minutes: " + m_newsEvents[i].title;
            
            LogNewsStatus(m_newsEvents[i], minutesUntilEvent, false, reason);
            return false;
         }
         
         if(minutesSinceEvent >= 0 && minutesSinceEvent <= NewsAfterMinutes)
         {
            reason = "High impact news " + IntegerToString(minutesSinceEvent) + 
                    " minutes ago: " + m_newsEvents[i].title;
            
            LogNewsStatus(m_newsEvents[i], -minutesSinceEvent, false, reason);
            return false;
         }
      }
      
      reason = "No high impact news";
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Check if should close positions before news                       |
   //+------------------------------------------------------------------+
   bool ShouldCloseBeforeNews(string &eventName, int &minutesUntil)
   {
      if(!m_isEnabled) return false;
      
      datetime currentTime = TimeCurrent();
      
      for(int i = 0; i < ArraySize(m_newsEvents); i++)
      {
         if(m_newsEvents[i].impact < 3) continue;
         if(!IsGoldRelatedEvent(m_newsEvents[i])) continue;
         
         minutesUntil = (int)((m_newsEvents[i].time - currentTime) / 60);
         
         if(minutesUntil > 0 && minutesUntil <= CloseBeforeNewsMinutes)
         {
            eventName = m_newsEvents[i].title;
            return true;
         }
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Get next high impact event                                        |
   //+------------------------------------------------------------------+
   NewsEvent GetNextHighImpactEvent()
   {
      NewsEvent nextEvent;
      nextEvent.time = 0;
      
      datetime currentTime = TimeCurrent();
      datetime nearestTime = currentTime + 86400; // 24 hours ahead
      
      for(int i = 0; i < ArraySize(m_newsEvents); i++)
      {
         if(m_newsEvents[i].impact < 3) continue;
         if(!IsGoldRelatedEvent(m_newsEvents[i])) continue;
         if(m_newsEvents[i].time <= currentTime) continue;
         
         if(m_newsEvents[i].time < nearestTime)
         {
            nearestTime = m_newsEvents[i].time;
            nextEvent = m_newsEvents[i];
         }
      }
      
      return nextEvent;
   }
   
   //+------------------------------------------------------------------+
   //| Get upcoming events summary                                       |
   //+------------------------------------------------------------------+
   string GetUpcomingEventsSummary()
   {
      string summary = "";
      datetime currentTime = TimeCurrent();
      int eventCount = 0;
      
      for(int i = 0; i < ArraySize(m_newsEvents); i++)
      {
         if(m_newsEvents[i].time <= currentTime) continue;
         if(m_newsEvents[i].time > currentTime + 14400) break; // Next 4 hours only
         
         int minutesUntil = (int)((m_newsEvents[i].time - currentTime) / 60);
         string impact = GetImpactString(m_newsEvents[i].impact);
         
         if(eventCount > 0) summary += "\n";
         summary += TimeToString(m_newsEvents[i].time, TIME_MINUTES) + " - " +
                   m_newsEvents[i].title + " (" + impact + ")";
         
         eventCount++;
         if(eventCount >= 5) break; // Show max 5 events
      }
      
      if(eventCount == 0)
      {
         summary = "No events in next 4 hours";
      }
      
      return summary;
   }
   
   //+------------------------------------------------------------------+
   //| Force update news events                                          |
   //+------------------------------------------------------------------+
   void ForceUpdate()
   {
      UpdateNewsEvents();
   }
   
private:
   //+------------------------------------------------------------------+
   //| Initialize high impact events list                                |
   //+------------------------------------------------------------------+
   void InitializeHighImpactEvents()
   {
      // US Events that impact Gold
      ArrayResize(m_highImpactEvents, 15);
      m_highImpactEvents[0] = "Non-Farm Payrolls";
      m_highImpactEvents[1] = "FOMC Meeting Minutes";
      m_highImpactEvents[2] = "Federal Funds Rate";
      m_highImpactEvents[3] = "CPI";
      m_highImpactEvents[4] = "Core CPI";
      m_highImpactEvents[5] = "GDP";
      m_highImpactEvents[6] = "Unemployment Rate";
      m_highImpactEvents[7] = "ISM Manufacturing PMI";
      m_highImpactEvents[8] = "ISM Services PMI";
      m_highImpactEvents[9] = "Retail Sales";
      m_highImpactEvents[10] = "PPI";
      m_highImpactEvents[11] = "Core PPI";
      m_highImpactEvents[12] = "Initial Jobless Claims";
      m_highImpactEvents[13] = "Fed Chair Powell Speaks";
      m_highImpactEvents[14] = "Treasury Currency Report";
   }
   
   //+------------------------------------------------------------------+
   //| Update news events from source                                    |
   //+------------------------------------------------------------------+
   void UpdateNewsEvents()
   {
      // In a real implementation, this would fetch from an economic calendar API
      // For now, we'll create some dummy events for testing
      
      ArrayResize(m_newsEvents, 0);
      
      // Add some example events (in production, these would come from API)
      AddDummyNewsEvents();
      
      // Sort events by time
      SortEventsByTime();
      
      m_lastUpdateTime = TimeCurrent();
      
      LogInfo("News events updated. Total events: " + IntegerToString(ArraySize(m_newsEvents)));
   }
   
   //+------------------------------------------------------------------+
   //| Add dummy news events for testing                                 |
   //+------------------------------------------------------------------+
   void AddDummyNewsEvents()
   {
      datetime currentTime = TimeCurrent();
      
      // Example: Add NFP event (first Friday of month at 13:30 GMT)
      MqlDateTime dt;
      TimeToStruct(currentTime, dt);
      
      // Find next first Friday
      datetime firstFriday = GetNextFirstFriday();
      if(firstFriday > 0)
      {
         NewsEvent nfp;
         nfp.time = firstFriday + 13*3600 + 30*60; // 13:30 GMT
         nfp.currency = "USD";
         nfp.title = "Non-Farm Payrolls";
         nfp.impact = 3; // High impact
         nfp.forecast = "180K";
         nfp.previous = "175K";
         nfp.actual = "";
         
         AddNewsEvent(nfp);
      }
      
      // Add FOMC event (example: next Wednesday at 19:00 GMT)
      datetime nextWednesday = GetNextWeekday(3); // Wednesday
      if(nextWednesday > 0)
      {
         NewsEvent fomc;
         fomc.time = nextWednesday + 19*3600; // 19:00 GMT
         fomc.currency = "USD";
         fomc.title = "FOMC Meeting Minutes";
         fomc.impact = 3; // High impact
         fomc.forecast = "";
         fomc.previous = "";
         fomc.actual = "";
         
         AddNewsEvent(fomc);
      }
      
      // Add more events as needed...
   }
   
   //+------------------------------------------------------------------+
   //| Add news event to array                                           |
   //+------------------------------------------------------------------+
   void AddNewsEvent(NewsEvent &event)
   {
      int size = ArraySize(m_newsEvents);
      ArrayResize(m_newsEvents, size + 1);
      m_newsEvents[size] = event;
   }
   
   //+------------------------------------------------------------------+
   //| Check if event is gold-related                                    |
   //+------------------------------------------------------------------+
   bool IsGoldRelatedEvent(NewsEvent &event)
   {
      // USD events always affect gold
      if(event.currency == "USD") return true;
      
      // Check if event title contains gold-specific keywords
      string lowerTitle = event.title;
      StringToLower(lowerTitle);
      
      if(StringFind(lowerTitle, "gold") >= 0) return true;
      if(StringFind(lowerTitle, "precious metals") >= 0) return true;
      if(StringFind(lowerTitle, "mining") >= 0) return true;
      
      // Check if it's a high impact event from our list
      for(int i = 0; i < ArraySize(m_highImpactEvents); i++)
      {
         if(StringFind(event.title, m_highImpactEvents[i]) >= 0)
            return true;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Sort events by time                                               |
   //+------------------------------------------------------------------+
   void SortEventsByTime()
   {
      int size = ArraySize(m_newsEvents);
      
      // Simple bubble sort
      for(int i = 0; i < size - 1; i++)
      {
         for(int j = 0; j < size - i - 1; j++)
         {
            if(m_newsEvents[j].time > m_newsEvents[j + 1].time)
            {
               NewsEvent temp = m_newsEvents[j];
               m_newsEvents[j] = m_newsEvents[j + 1];
               m_newsEvents[j + 1] = temp;
            }
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Get impact level string                                           |
   //+------------------------------------------------------------------+
   string GetImpactString(int impact)
   {
      switch(impact)
      {
         case 1: return "Low";
         case 2: return "Medium";
         case 3: return "High";
         default: return "Unknown";
      }
   }
   
   //+------------------------------------------------------------------+
   //| Log news filter status                                            |
   //+------------------------------------------------------------------+
   void LogNewsStatus(NewsEvent &event, int minutesUntilOrSince, 
                      bool tradingAllowed, string reason)
   {
      if(g_Logger == NULL) return;
      
      string timeDescription;
      if(minutesUntilOrSince > 0)
         timeDescription = "in " + IntegerToString(minutesUntilOrSince) + " minutes";
      else if(minutesUntilOrSince < 0)
         timeDescription = IntegerToString(-minutesUntilOrSince) + " minutes ago";
      else
         timeDescription = "now";
      
      g_Logger.LogNewsFilter(
         event.title + " (" + event.currency + ")",
         minutesUntilOrSince,
         tradingAllowed,
         reason
      );
   }
   
   //+------------------------------------------------------------------+
   //| Get next occurrence of a weekday                                  |
   //+------------------------------------------------------------------+
   datetime GetNextWeekday(int targetDay) // 0=Sunday, 1=Monday, etc.
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      
      int daysUntilTarget = targetDay - dt.day_of_week;
      if(daysUntilTarget <= 0) daysUntilTarget += 7;
      
      return TimeCurrent() + daysUntilTarget * 86400;
   }
   
   //+------------------------------------------------------------------+
   //| Get next first Friday of the month                                |
   //+------------------------------------------------------------------+
   datetime GetNextFirstFriday()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      
      // Loop to find first Friday in current or next month
      for(int monthOffset = 0; monthOffset < 12; monthOffset++) // Max 12 months ahead
      {
         // Calculate target month/year
         int targetMonth = dt.mon + monthOffset;
         int targetYear = dt.year;
         
         while(targetMonth > 12)
         {
            targetMonth -= 12;
            targetYear++;
         }
         
         // Set to first day of target month
         MqlDateTime targetDt;
         targetDt.year = targetYear;
         targetDt.mon = targetMonth;
         targetDt.day = 1;
         targetDt.hour = 0;
         targetDt.min = 0;
         targetDt.sec = 0;
         
         datetime firstDay = StructToTime(targetDt);
         
         // Find first Friday of target month
         for(int i = 0; i < 7; i++)
         {
            datetime checkDay = firstDay + i * 86400;
            TimeToStruct(checkDay, targetDt);
            
            if(targetDt.day_of_week == 5) // Friday
            {
               // Check if this Friday is in the future
               if(checkDay >= TimeCurrent())
               {
                  return checkDay;
               }
               break; // Found first Friday of this month, but it's in the past
            }
         }
      }
      
      return 0; // Fallback - should not reach here
   }
};

//+------------------------------------------------------------------+
//| Global news filter instance                                        |
//+------------------------------------------------------------------+
CNewsFilter* g_NewsFilter = NULL;

//+------------------------------------------------------------------+
//| Initialize global news filter                                      |
//+------------------------------------------------------------------+
void InitializeNewsFilter()
{
   if(g_NewsFilter == NULL)
   {
      g_NewsFilter = new CNewsFilter();
   }
}

//+------------------------------------------------------------------+
//| Cleanup global news filter                                         |
//+------------------------------------------------------------------+
void CleanupNewsFilter()
{
   if(g_NewsFilter != NULL)
   {
      delete g_NewsFilter;
      g_NewsFilter = NULL;
   }
}

//+------------------------------------------------------------------+
//| Quick access functions                                             |
//+------------------------------------------------------------------+
bool IsNewsTimeRestricted(string &reason)
{
   if(g_NewsFilter != NULL)
      return !g_NewsFilter.IsTradingAllowed(reason);
   
   reason = "News filter not initialized";
   return false;
}

bool ShouldCloseForNews(string &eventName, int &minutesUntil)
{
   if(g_NewsFilter != NULL)
      return g_NewsFilter.ShouldCloseBeforeNews(eventName, minutesUntil);
   
   return false;
}

//+------------------------------------------------------------------+ 