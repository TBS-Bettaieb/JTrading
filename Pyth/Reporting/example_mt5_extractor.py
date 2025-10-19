"""
Exemple d'utilisation du MT5DataExtractor
=========================================
Script de démonstration pour utiliser le module d'extraction de données MT5
"""

from mt5_data_extractor import MT5DataExtractor
import os
from pathlib import Path


def example_basic_usage():
    """Exemple d'utilisation basique du MT5DataExtractor."""
    print("🔍 Exemple d'utilisation basique")
    print("=" * 50)
    
    # Chemin vers le fichier Excel (ajustez selon votre fichier)
    file_path = "ReportTester-1511739399.xlsx"
    
    # Vérifier que le fichier existe
    if not os.path.exists(file_path):
        print(f"❌ Fichier non trouvé : {file_path}")
        print("   Assurez-vous que le fichier Excel est dans le répertoire courant")
        return
    
    try:
        # 1. Initialiser l'extracteur
        extractor = MT5DataExtractor(file_path)
        
        # 2. Charger le fichier
        extractor.load_file()
        
        # 3. Extraire les informations générales
        info = extractor.extract_info()
        
        # 4. Extraire les transactions
        transactions = extractor.extract_transactions()
        
        # 5. Calculer les statistiques
        stats = extractor.calculate_statistics()
        
        # 6. Analyser par symbole
        symbol_analysis = extractor.analyze_by_symbol()
        
        print("\n✅ Extraction terminée avec succès !")
        
    except Exception as e:
        print(f"❌ Erreur lors de l'extraction : {str(e)}")


def example_full_report():
    """Exemple de génération de rapport complet avec toutes les nouvelles fonctionnalités."""
    print("\n📊 Exemple de génération de rapport complet v2.0")
    print("=" * 50)
    
    file_path = "ReportTester-1511739399.xlsx"
    
    if not os.path.exists(file_path):
        print(f"❌ Fichier non trouvé : {file_path}")
        return
    
    try:
        # Initialiser l'extracteur avec les nouvelles options
        extractor = MT5DataExtractor(file_path, show_progress=True)
        
        # Générer le rapport complet avec toutes les analyses
        extractor.generate_full_report(output_dir='rapport_mt5_demo')
        
        print("\n🎯 Rapport complet généré avec succès !")
        print("   📂 Tous les fichiers sont dans le dossier 'rapport_mt5_demo/'")
        print("   🌐 Ouvrez 'rapport_complet.html' dans votre navigateur pour voir le rapport")
        
    except Exception as e:
        print(f"❌ Erreur lors de la génération du rapport : {str(e)}")


def example_custom_analysis():
    """Exemple d'analyse personnalisée avec les nouvelles fonctionnalités."""
    print("\n🔬 Exemple d'analyse personnalisée avancée")
    print("=" * 50)
    
    file_path = "ReportTester-1511739399.xlsx"
    
    if not os.path.exists(file_path):
        print(f"❌ Fichier non trouvé : {file_path}")
        return
    
    try:
        # Initialiser avec les nouvelles options
        extractor = MT5DataExtractor(file_path, show_progress=True)
        extractor.load_file()
        extractor.extract_transactions()
        extractor.calculate_statistics()
        
        # Analyse personnalisée des trades
        trades = extractor.df_transactions[
            (extractor.df_transactions['Type'].notna()) & 
            (extractor.df_transactions['Type'] != 'balance')
        ].copy()
        
        if len(trades) > 0:
            # Trades les plus profitables
            top_trades = trades.nlargest(5, 'Profit')
            print("\n🏆 Top 5 des trades les plus profitables :")
            for idx, trade in top_trades.iterrows():
                print(f"   {trade['Heure']} | {trade['Symbole']} | Profit: {trade['Profit']:.2f}")
            
            # Trades les plus perdants
            worst_trades = trades.nsmallest(5, 'Profit')
            print("\n💸 Top 5 des trades les plus perdants :")
            for idx, trade in worst_trades.iterrows():
                print(f"   {trade['Heure']} | {trade['Symbole']} | Perte: {trade['Profit']:.2f}")
            
            # Analyse temporelle
            trades['Heure'] = pd.to_datetime(trades['Heure'])
            trades['Jour'] = trades['Heure'].dt.date
            daily_profit = trades.groupby('Jour')['Profit'].sum()
            
            print(f"\n📅 Meilleur jour : {daily_profit.idxmax()} (Profit: {daily_profit.max():.2f})")
            print(f"📅 Pire jour : {daily_profit.idxmin()} (Perte: {daily_profit.min():.2f})")
            
            # Nouvelles analyses avancées
            print("\n🔄 Analyse du drawdown...")
            drawdown_analysis = extractor.calculate_drawdown_analysis()
            
            print("\n🔄 Analyse des sessions de trading...")
            session_analysis = extractor.analyze_trading_sessions()
        
    except Exception as e:
        print(f"❌ Erreur lors de l'analyse personnalisée : {str(e)}")


def example_export_data():
    """Exemple d'export de données avec les nouvelles fonctionnalités."""
    print("\n💾 Exemple d'export de données avancé")
    print("=" * 50)
    
    file_path = "ReportTester-1511739399.xlsx"
    
    if not os.path.exists(file_path):
        print(f"❌ Fichier non trouvé : {file_path}")
        return
    
    try:
        extractor = MT5DataExtractor(file_path, show_progress=True)
        extractor.load_file()
        extractor.extract_transactions()
        extractor.calculate_statistics()
        
        # Export CSV
        extractor.export_to_csv('mes_transactions.csv')
        
        # Export JSON
        extractor.export_stats_to_json('mes_statistiques.json')
        
        # Graphiques classiques
        extractor.plot_balance_curve('evolution_balance.png')
        extractor.plot_profit_distribution('distribution_profits.png')
        
        # Nouveaux graphiques
        extractor.plot_drawdown_curve('evolution_drawdown.png')
        
        # Analyses avancées
        drawdown_analysis = extractor.calculate_drawdown_analysis()
        session_analysis = extractor.analyze_trading_sessions()
        
        # Export des analyses avancées
        import json
        with open('analyse_drawdown.json', 'w', encoding='utf-8') as f:
            json.dump(drawdown_analysis, f, indent=2, ensure_ascii=False, default=str)
        
        with open('analyse_sessions.json', 'w', encoding='utf-8') as f:
            json.dump(session_analysis, f, indent=2, ensure_ascii=False, default=str)
        
        print("\n✅ Exports terminés !")
        print("   📊 mes_transactions.csv")
        print("   📈 mes_statistiques.json")
        print("   📊 evolution_balance.png")
        print("   📊 distribution_profits.png")
        print("   📉 evolution_drawdown.png")
        print("   📉 analyse_drawdown.json")
        print("   ⏰ analyse_sessions.json")
        
    except Exception as e:
        print(f"❌ Erreur lors de l'export : {str(e)}")


def main():
    """Fonction principale pour exécuter tous les exemples."""
    print("🚀 MT5DataExtractor - Exemples d'utilisation")
    print("=" * 60)
    
    # Vérifier les dépendances
    try:
        import pandas as pd
        import matplotlib.pyplot as plt
        print("✅ Dépendances installées correctement")
    except ImportError as e:
        print(f"❌ Dépendance manquante : {e}")
        print("   Installez les dépendances avec : pip install -r requirements.txt")
        return
    
    # Exécuter les exemples
    example_basic_usage()
    example_full_report()
    example_custom_analysis()
    example_export_data()
    
    print("\n🎉 Tous les exemples ont été exécutés !")
    print("\n📁 Fichiers générés :")
    print("   📂 rapport_mt5_demo/ (rapport complet avec HTML)")
    print("   📊 mes_transactions.csv")
    print("   📈 mes_statistiques.json")
    print("   📊 evolution_balance.png")
    print("   📊 distribution_profits.png")
    print("   📉 evolution_drawdown.png")
    print("   📉 analyse_drawdown.json")
    print("   ⏰ analyse_sessions.json")
    print("   🌐 rapport_complet.html")


if __name__ == "__main__":
    main()
