# Guide du Batch Testing - JT Trading

## Vue d'ensemble

Le système de batch testing permet de tester automatiquement différentes configurations de l'EA JTFreeCandle en utilisant un fichier CSV de paramètres. Cela facilite l'optimisation et la comparaison de différentes stratégies.

## Fichiers du système

### 1. **JT_BatchRunner.mq5** - EA principal
- EA qui lit la configuration depuis le CSV
- Exécute la logique de trading avec les paramètres spécifiés
- Sauvegarde les résultats dans un fichier CSV

### 2. **JT_BatchHelper.mq5** - Script d'aide
- Affiche les configurations disponibles
- Crée des fichiers batch pour Windows
- Génère un résumé des tests

### 3. **JT_BatchConfig.csv** - Fichier de configuration
- Contient toutes les configurations de test
- Format CSV avec en-têtes
- Facilement modifiable

## Structure du fichier CSV

```csv
TestID,TestName,BB_Period,BB_Dev,RSI_Period,RSI_Oversold,RSI_Overbought,Use_EMA,EMA_Fast,EMA_Slow,EMA_Mode,Risk_Percent,SL_Period,TP_Period,Min_RR,Mode,Outside_Padding,Body_Must_Be_Outside,Use_Divergence,Div_RSI_Buy,Div_RSI_Sell
1,Conservative_Trend,20,2.5,14,25,75,1,50,100,0,0.5,70,50,1.5,0,5,1,0,35,65
```

### Colonnes du CSV:

| Colonne | Description | Valeurs |
|---------|-------------|---------|
| TestID | Identifiant unique du test | 1, 2, 3... |
| TestName | Nom descriptif du test | Conservative_Trend, Aggressive_Counter... |
| BB_Period | Période des Bollinger Bands | 15, 20, 25... |
| BB_Dev | Déviation des Bollinger Bands | 1.5, 2.0, 2.5... |
| RSI_Period | Période du RSI | 10, 14, 20... |
| RSI_Oversold | Seuil de survente RSI | 25, 30, 35... |
| RSI_Overbought | Seuil de surachat RSI | 65, 70, 75... |
| Use_EMA | Activer le filtre EMA | 0 (non), 1 (oui) |
| EMA_Fast | Période EMA rapide | 30, 50, 80... |
| EMA_Slow | Période EMA lente | 80, 100, 150... |
| EMA_Mode | Mode EMA | 0 (TREND), 1 (COUNTER), 2 (ZONE) |
| Risk_Percent | Pourcentage de risque | 0.5, 1.0, 2.0... |
| SL_Period | Période pour calcul SL | 30, 50, 70... |
| TP_Period | Période pour calcul TP | 20, 30, 50... |
| Min_RR | Ratio risque/récompense minimum | 1.5, 2.0, 2.5... |
| Mode | Mode d'entrée | 0 (REVERSION), 1 (BREAKOUT) |
| Outside_Padding | Marge hors bandes (points) | 3, 5, 10... |
| Body_Must_Be_Outside | Corps entier hors bandes | 0 (non), 1 (oui) |
| Use_Divergence | Activer validation divergence | 0 (non), 1 (oui) |
| Div_RSI_Buy | Seuil RSI pour divergence BUY | 35, 40... |
| Div_RSI_Sell | Seuil RSI pour divergence SELL | 60, 65... |

## Utilisation

### Étape 1: Préparation
1. Placez `JT_BatchConfig.csv` dans le dossier `Files/` de MetaTrader 5
2. Compilez `JT_BatchRunner.mq5` et `JT_BatchHelper.mq5`

### Étape 2: Lancement d'un test individuel
1. Ouvrez `JT_BatchRunner.mq5` dans MetaEditor
2. Modifiez le paramètre `TestID` (ex: `input int TestID = 1;`)
3. Compilez et lancez sur le graphique
4. L'EA va:
   - Charger la configuration Test #1
   - Exécuter la stratégie avec ces paramètres
   - Sauvegarder les résultats dans `BatchResults_Test1_YYYY.MM.DD.csv`

### Étape 3: Lancement de plusieurs tests
1. Exécutez `JT_BatchHelper.mq5` en script
2. Le script va créer des fichiers `.bat` pour chaque test
3. Exécutez les fichiers `.bat` ou lancez manuellement chaque test

### Étape 4: Analyse des résultats
Les fichiers de résultats contiennent:
- Timestamp
- TestID et TestName
- Nombre total de trades
- Balance et Equity
- Pourcentage de profit
- Profit Factor
- Taux de réussite
- Gain moyen et perte moyenne
- Drawdown maximum
- Ratio de Sharpe
- Statut (COMPLETED)

## Configurations prédéfinies

Le fichier `JT_BatchConfig.csv` contient 20 configurations prédéfinies:

1. **Conservative_Trend** - Configuration prudente suivant la tendance
2. **Aggressive_Counter** - Configuration agressive en contre-tendance
3. **Balanced_Zone** - Configuration équilibrée évitant les zones neutres
4. **Breakout_Trend** - Configuration breakout suivant la tendance
5. **Reversion_NoEMA** - Configuration reversion sans filtre EMA
6. **Tight_BB** - Bollinger Bands serrées
7. **Wide_BB** - Bollinger Bands larges
8. **Fast_RSI** - RSI rapide (période 10)
9. **Slow_RSI** - RSI lent (période 20)
10. **High_RR** - Ratio risque/récompense élevé
11. **Divergence_Only** - Uniquement les trades avec divergence
12. **Tight_Entry** - Entrées très strictes
13. **Loose_Entry** - Entrées plus permissives
14. **Fast_EMA** - EMAs rapides
15. **Slow_EMA** - EMAs lentes
16. **Counter_Trend** - Mode contre-tendance
17. **Zone_Trading** - Éviter les zones neutres
18. **High_Risk** - Risque élevé (2.5%)
19. **Low_Risk** - Risque faible (0.5%)
20. **Scalper** - Configuration pour le scalping

## Recommandations

### Avant de commencer
- ✅ Testez sur un compte démo d'abord
- ✅ Assurez-vous d'avoir suffisamment de données historiques
- ✅ Vérifiez que le symbole est disponible et actif

### Pendant les tests
- 📊 Surveillez les résultats en temps réel
- 📝 Notez les configurations les plus performantes
- ⚠️ Arrêtez les tests en cas de drawdown excessif

### Après les tests
- 📈 Analysez les statistiques finales
- 🏆 Identifiez les meilleures configurations
- 📋 Documentez vos conclusions
- 🔄 Optimisez les paramètres si nécessaire

## Personnalisation

### Ajouter une nouvelle configuration
1. Ouvrez `JT_BatchConfig.csv`
2. Ajoutez une nouvelle ligne avec:
   - TestID unique
   - Nom descriptif
   - Valeurs des paramètres
3. Sauvegardez le fichier

### Modifier les paramètres existants
1. Ouvrez `JT_BatchConfig.csv`
2. Modifiez les valeurs dans la ligne correspondante
3. Sauvegardez le fichier

### Ajouter de nouveaux paramètres
1. Modifiez la structure `TestConfig` dans `JT_BatchRunner.mq5`
2. Mettez à jour la fonction `LoadConfig()`
3. Ajoutez la colonne dans le CSV
4. Mettez à jour la logique de trading si nécessaire

## Dépannage

### Erreurs communes

**"Fichier CSV introuvable"**
- Vérifiez que `JT_BatchConfig.csv` est dans le dossier `Files/`
- Vérifiez le nom du fichier (sensible à la casse)

**"Configuration TestID X introuvable"**
- Vérifiez que le TestID existe dans le CSV
- Vérifiez le format du CSV (virgules, guillemets)

**"Erreur d'initialisation des indicateurs"**
- Vérifiez que le symbole est valide
- Vérifiez que le timeframe est supporté
- Vérifiez les paramètres des indicateurs

### Logs et débogage
- Consultez le journal Expert dans MetaTrader 5
- Vérifiez les messages d'erreur
- Surveillez les performances en temps réel

## Exemple de workflow complet

1. **Préparation** (5 min)
   - Copier les fichiers dans MetaTrader 5
   - Compiler les EAs
   - Vérifier la configuration

2. **Test individuel** (selon durée du marché)
   - Lancer Test #1 (Conservative_Trend)
   - Surveiller pendant 1-2 heures
   - Analyser les résultats

3. **Tests multiples** (plusieurs heures/jours)
   - Lancer les tests 1-5
   - Comparer les performances
   - Identifier les meilleures configurations

4. **Optimisation** (selon besoins)
   - Modifier les paramètres des meilleures configurations
   - Créer de nouvelles configurations
   - Relancer les tests

5. **Déploiement** (quand satisfait)
   - Utiliser la meilleure configuration
   - Surveiller en live
   - Ajuster si nécessaire

---

*Ce guide vous aide à utiliser efficacement le système de batch testing pour optimiser votre stratégie de trading.*
