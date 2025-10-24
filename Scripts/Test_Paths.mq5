//+------------------------------------------------------------------+
//|                                               Test_Paths.mq5     |
//|                         RSI Divergence Trading System              |
//|                        Test des chemins d'inclusion               |
//+------------------------------------------------------------------+
#property copyright "RSI Divergence Trading System"
#property link      ""
#property version   "1.00"

// Test des inclusions
#include "..\Shared\RSI_Calculator.mqh"

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("✅ Test des chemins d'inclusion réussi !");
   Print("Les fichiers MQH sont accessibles depuis le dossier Shared/");
}
