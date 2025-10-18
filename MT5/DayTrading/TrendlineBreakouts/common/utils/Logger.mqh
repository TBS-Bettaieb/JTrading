//+------------------------------------------------------------------+
//| Logger.mqh                                                        |
//| Centralized logging system with configurable levels              |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

//+------------------------------------------------------------------+
//| Log level enumeration                                            |
//+------------------------------------------------------------------+
enum ENUM_LOG_LEVEL
{
   LOG_NONE = 0,      // No logging
   LOG_ERROR = 1,     // Only errors
   LOG_WARNING = 2,   // Errors + warnings
   LOG_INFO = 3,      // Errors + warnings + info
   LOG_DEBUG = 4      // Everything including debug
};

//+------------------------------------------------------------------+
//| Static logger class                                              |
//+------------------------------------------------------------------+
class Logger
{
private:
   static ENUM_LOG_LEVEL s_logLevel;
   static string s_prefix;

public:
   //+------------------------------------------------------------------+
   //| Initialize logger                                                |
   //+------------------------------------------------------------------+
   static void Initialize(ENUM_LOG_LEVEL level, string prefix = "")
   {
      s_logLevel = level;
      s_prefix = prefix;
   }
   
   //+------------------------------------------------------------------+
   //| Log error message (always shown unless LOG_NONE)               |
   //+------------------------------------------------------------------+
   static void Error(string message)
   {
      if(s_logLevel >= LOG_ERROR)
      {
         Print(s_prefix, "❌ ERROR: ", message);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Log warning message                                             |
   //+------------------------------------------------------------------+
   static void Warning(string message)
   {
      if(s_logLevel >= LOG_WARNING)
      {
         Print(s_prefix, "⚠️ WARNING: ", message);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Log info message                                                |
   //+------------------------------------------------------------------+
   static void Info(string message)
   {
      if(s_logLevel >= LOG_INFO)
      {
         Print(s_prefix, "ℹ️ INFO: ", message);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Log debug message                                               |
   //+------------------------------------------------------------------+
   static void Debug(string message)
   {
      if(s_logLevel >= LOG_DEBUG)
      {
         Print(s_prefix, "🔍 DEBUG: ", message);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Log success message                                             |
   //+------------------------------------------------------------------+
   static void Success(string message)
   {
      if(s_logLevel >= LOG_INFO)
      {
         Print(s_prefix, "✅ SUCCESS: ", message);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Log trade signal                                                |
   //+------------------------------------------------------------------+
   static void Signal(bool isBuy, string message)
   {
      if(s_logLevel >= LOG_INFO)
      {
         Print(s_prefix, isBuy ? "🟢 BUY: " : "🔴 SELL: ", message);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Get current log level                                           |
   //+------------------------------------------------------------------+
   static ENUM_LOG_LEVEL GetLevel() { return s_logLevel; }
   
   //+------------------------------------------------------------------+
   //| Set log level                                                   |
   //+------------------------------------------------------------------+
   static void SetLevel(ENUM_LOG_LEVEL level) { s_logLevel = level; }
};

// Initialize static members
static ENUM_LOG_LEVEL Logger::s_logLevel = LOG_INFO;
static string Logger::s_prefix = "";
