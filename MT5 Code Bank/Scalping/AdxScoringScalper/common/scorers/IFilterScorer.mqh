//+------------------------------------------------------------------+
//| IFilterScorer.mqh - Interface commune pour les scorers         |
//|                   Interface pour les classes de scoring        |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

//+------------------------------------------------------------------+
//| Interface commune pour tous les scorers                         |
//+------------------------------------------------------------------+
class IFilterScorer
{
public:
   //+------------------------------------------------------------------+
   //| Méthodes virtuelles pures à implémenter                        |
   //+------------------------------------------------------------------+
   
   // Initialiser le scorer
   virtual bool Initialize() = 0;
   
   // Mettre à jour les valeurs de l'indicateur
   virtual void Update() = 0;
   
   // Obtenir le score pour un signal d'achat
   virtual int GetBuyScore() = 0;
   
   // Obtenir le score pour un signal de vente
   virtual int GetSellScore() = 0;
   
   // Déterminer si les conditions sont favorables (pour bonus confluence)
   virtual bool IsHighTrend() = 0;
   
   // Obtenir la valeur actuelle de l'indicateur
   virtual double GetCurrentValue() = 0;
   
   // Libérer les ressources
   virtual void Release() = 0;
};
