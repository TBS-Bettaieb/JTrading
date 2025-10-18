"""
MT5 Data Extractor
==================
Module pour extraire et analyser les données de rapports de test MT5 (MetaTrader 5)

Auteur: Généré par Claude
Date: 2025
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime
from typing import Dict, Tuple, Optional
import json
from pathlib import Path


class MT5DataExtractor:
    """
    Classe pour extraire et analyser les données d'un fichier de rapport MT5.
    
    Attributes:
        file_path (str): Chemin vers le fichier Excel
        df_raw (pd.DataFrame): Données brutes du fichier
        info (dict): Informations générales du test
        df_transactions (pd.DataFrame): DataFrame des transactions
        df_ordres (pd.DataFrame): DataFrame des ordres
    """
    
    def __init__(self, file_path: str):
        """
        Initialise l'extracteur avec le chemin du fichier.
        
        Args:
            file_path (str): Chemin vers le fichier Excel MT5
        """
        self.file_path = file_path
        self.df_raw = None
        self.info = {}
        self.df_transactions = None
        self.df_ordres = None
        self.transactions_start = None
        self.ordres_start = None
        
    def load_file(self) -> None:
        """Charge le fichier Excel en mémoire."""
        try:
            self.df_raw = pd.read_excel(self.file_path, header=None)
            print(f"✅ Fichier chargé : {self.file_path}")
            print(f"   Dimensions : {self.df_raw.shape[0]} lignes × {self.df_raw.shape[1]} colonnes")
        except FileNotFoundError:
            raise FileNotFoundError(f"❌ Fichier non trouvé : {self.file_path}")
        except Exception as e:
            raise Exception(f"❌ Erreur lors du chargement : {str(e)}")
    
    def _extract_info_value(self, keyword: str, col_idx: int = 3) -> Optional[any]:
        """
        Extrait une valeur depuis la section informations.
        
        Args:
            keyword (str): Mot-clé à rechercher
            col_idx (int): Index de la colonne contenant la valeur
            
        Returns:
            Optional[any]: Valeur trouvée ou None
        """
        if self.df_raw is None:
            return None
            
        mask = self.df_raw[0].astype(str).str.contains(keyword, case=False, na=False)
        if mask.any():
            idx = mask.idxmax()
            return self.df_raw.iloc[idx, col_idx] if col_idx < len(self.df_raw.columns) else None
        return None
    
    def extract_info(self) -> Dict:
        """
        Extrait les informations générales du test.
        
        Returns:
            Dict: Dictionnaire contenant les informations du test
        """
        if self.df_raw is None:
            raise ValueError("Charger d'abord le fichier avec load_file()")
        
        self.info = {
            'expert': self._extract_info_value('Expert'),
            'symbole': self._extract_info_value('Symbole'),
            'periode': self._extract_info_value('Période'),
            'courtier': self._extract_info_value('Courtier'),
            'devise': self._extract_info_value('Devise'),
            'depot_initial': self._extract_info_value('Dépôt initial'),
            'levier': self._extract_info_value('Levier'),
            'profit_total': self._extract_info_value('Profit Total Net'),
            'profit_brut': self._extract_info_value('Profit brut'),
            'perte_brut': self._extract_info_value('Perte brut'),
            'facteur_profit': self._extract_info_value('Facteur de profit'),
            'drawdown_max': self._extract_info_value('Drawdown Maximal')
        }
        
        print("\n📋 Informations extraites :")
        for key, value in self.info.items():
            print(f"   {key.replace('_', ' ').title():.<30} {value}")
        
        return self.info
    
    def _find_section(self, section_name: str) -> Optional[int]:
        """
        Trouve la ligne de début d'une section.
        
        Args:
            section_name (str): Nom de la section à trouver
            
        Returns:
            Optional[int]: Index de la ligne ou None
        """
        for idx, row in self.df_raw.iterrows():
            if row[0] == section_name:
                return idx
        return None
    
    def extract_transactions(self) -> pd.DataFrame:
        """
        Extrait les transactions du fichier.
        
        Returns:
            pd.DataFrame: DataFrame contenant les transactions
        """
        if self.df_raw is None:
            raise ValueError("Charger d'abord le fichier avec load_file()")
        
        self.transactions_start = self._find_section('Transactions')
        
        if self.transactions_start is None:
            raise ValueError("❌ Section 'Transactions' non trouvée dans le fichier")
        
        # Lire les transactions avec les en-têtes
        self.df_transactions = pd.read_excel(
            self.file_path,
            header=self.transactions_start + 1,
            skiprows=range(0, self.transactions_start + 1)
        )
        
        # Nettoyer les données
        if 'Heure' in self.df_transactions.columns:
            self.df_transactions['Heure'] = pd.to_datetime(
                self.df_transactions['Heure'], 
                errors='coerce'
            )
        
        # Supprimer les lignes vides
        self.df_transactions = self.df_transactions.dropna(subset=['Opération'])
        
        print(f"\n✅ {len(self.df_transactions)} transactions extraites")
        
        return self.df_transactions
    
    def extract_ordres(self) -> pd.DataFrame:
        """
        Extrait les ordres du fichier.
        
        Returns:
            pd.DataFrame: DataFrame contenant les ordres
        """
        if self.df_raw is None:
            raise ValueError("Charger d'abord le fichier avec load_file()")
        
        self.ordres_start = self._find_section('Ordres')
        
        if self.ordres_start is None:
            raise ValueError("❌ Section 'Ordres' non trouvée dans le fichier")
        
        # Lire les ordres avec les en-têtes
        self.df_ordres = pd.read_excel(
            self.file_path,
            header=self.ordres_start + 1,
            skiprows=range(0, self.ordres_start + 1),
            nrows=self.transactions_start - self.ordres_start - 2 if self.transactions_start else None
        )
        
        print(f"\n✅ {len(self.df_ordres)} ordres extraits")
        
        return self.df_ordres
    
    def calculate_statistics(self) -> Dict:
        """
        Calcule les statistiques des trades.
        
        Returns:
            Dict: Dictionnaire contenant les statistiques
        """
        if self.df_transactions is None:
            raise ValueError("Extraire d'abord les transactions avec extract_transactions()")
        
        # Filtrer uniquement les trades
        trades = self.df_transactions[
            (self.df_transactions['Type'].notna()) & 
            (self.df_transactions['Type'] != 'balance')
        ].copy()
        
        # Séparer gagnants et perdants
        winning_trades = trades[trades['Profit'] > 0]
        losing_trades = trades[trades['Profit'] < 0]
        
        stats = {
            'total_trades': len(trades),
            'winning_trades': len(winning_trades),
            'losing_trades': len(losing_trades),
            'win_rate': len(winning_trades) / len(trades) * 100 if len(trades) > 0 else 0,
            'avg_profit_win': winning_trades['Profit'].mean() if len(winning_trades) > 0 else 0,
            'avg_loss': losing_trades['Profit'].mean() if len(losing_trades) > 0 else 0,
            'total_profit': trades['Profit'].sum(),
            'total_commission': trades['Commission'].sum() if 'Commission' in trades.columns else 0,
            'profit_factor': abs(winning_trades['Profit'].sum() / losing_trades['Profit'].sum()) if len(losing_trades) > 0 and losing_trades['Profit'].sum() != 0 else 0
        }
        
        print("\n📈 Statistiques calculées :")
        print(f"   Total Trades................... {stats['total_trades']}")
        print(f"   Trades Gagnants................ {stats['winning_trades']}")
        print(f"   Trades Perdants................ {stats['losing_trades']}")
        print(f"   Win Rate....................... {stats['win_rate']:.2f}%")
        print(f"   Profit Moyen (gagnants)........ {stats['avg_profit_win']:.2f}")
        print(f"   Perte Moyenne (perdants)....... {stats['avg_loss']:.2f}")
        print(f"   Profit Total................... {stats['total_profit']:.2f}")
        print(f"   Profit Factor.................. {stats['profit_factor']:.2f}")
        
        return stats
    
    def analyze_by_symbol(self) -> pd.DataFrame:
        """
        Analyse les performances par symbole.
        
        Returns:
            pd.DataFrame: Statistiques par symbole
        """
        if self.df_transactions is None:
            raise ValueError("Extraire d'abord les transactions avec extract_transactions()")
        
        trades = self.df_transactions[
            (self.df_transactions['Type'].notna()) & 
            (self.df_transactions['Type'] != 'balance')
        ].copy()
        
        symbol_stats = trades.groupby('Symbole').agg({
            'Opération': 'count',
            'Profit': ['sum', 'mean', lambda x: (x > 0).sum(), lambda x: (x < 0).sum()]
        }).round(2)
        
        symbol_stats.columns = ['Nombre Trades', 'Profit Total', 'Profit Moyen', 'Gagnants', 'Perdants']
        symbol_stats['Win Rate %'] = (symbol_stats['Gagnants'] / symbol_stats['Nombre Trades'] * 100).round(2)
        
        print("\n💱 Analyse par symbole :")
        print(symbol_stats.sort_values('Profit Total', ascending=False))
        
        return symbol_stats
    
    def plot_balance_curve(self, save_path: Optional[str] = None) -> None:
        """
        Génère le graphique de l'évolution de la balance.
        
        Args:
            save_path (Optional[str]): Chemin pour sauvegarder le graphique
        """
        if self.df_transactions is None or 'Balance' not in self.df_transactions.columns:
            raise ValueError("Transactions non disponibles ou colonne Balance manquante")
        
        fig, ax = plt.subplots(figsize=(14, 6))
        
        ax.plot(
            self.df_transactions['Heure'], 
            self.df_transactions['Balance'], 
            linewidth=2, 
            color='#2E86AB',
            label='Balance'
        )
        
        ax.set_title('Évolution de la Balance', fontsize=16, fontweight='bold')
        ax.set_xlabel('Date', fontsize=12)
        ax.set_ylabel('Balance (USD)', fontsize=12)
        ax.grid(True, alpha=0.3)
        
        if self.info.get('depot_initial'):
            ax.axhline(
                y=self.info['depot_initial'], 
                color='red', 
                linestyle='--', 
                label='Dépôt Initial',
                alpha=0.7
            )
        
        ax.legend()
        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
            print(f"\n✅ Graphique sauvegardé : {save_path}")
        
        plt.show()
    
    def plot_profit_distribution(self, save_path: Optional[str] = None) -> None:
        """
        Génère l'histogramme de distribution des profits.
        
        Args:
            save_path (Optional[str]): Chemin pour sauvegarder le graphique
        """
        if self.df_transactions is None:
            raise ValueError("Extraire d'abord les transactions")
        
        trades = self.df_transactions[
            (self.df_transactions['Type'].notna()) & 
            (self.df_transactions['Type'] != 'balance')
        ].copy()
        
        fig, ax = plt.subplots(figsize=(12, 6))
        
        profit_data = trades['Profit'].dropna()
        ax.hist(profit_data, bins=50, edgecolor='black', alpha=0.7, color='#A23B72')
        ax.axvline(x=0, color='red', linestyle='--', linewidth=2, label='Seuil de rentabilité')
        
        ax.set_title('Distribution des Profits/Pertes par Trade', fontsize=16, fontweight='bold')
        ax.set_xlabel('Profit/Perte (USD)', fontsize=12)
        ax.set_ylabel('Fréquence', fontsize=12)
        ax.legend()
        ax.grid(True, alpha=0.3)
        
        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
            print(f"\n✅ Graphique sauvegardé : {save_path}")
        
        plt.show()
    
    def export_to_csv(self, output_path: str = 'transactions_mt5.csv') -> None:
        """
        Exporte les transactions en CSV.
        
        Args:
            output_path (str): Chemin du fichier de sortie
        """
        if self.df_transactions is None:
            raise ValueError("Extraire d'abord les transactions")
        
        self.df_transactions.to_csv(output_path, index=False, encoding='utf-8-sig')
        print(f"\n✅ Transactions exportées : {output_path}")
    
    def export_stats_to_json(self, output_path: str = 'statistiques_mt5.json') -> None:
        """
        Exporte les statistiques en JSON.
        
        Args:
            output_path (str): Chemin du fichier de sortie
        """
        stats = self.calculate_statistics()
        
        export_data = {
            'informations': self.info,
            'statistiques': {k: float(v) if isinstance(v, (np.integer, np.floating)) else v 
                           for k, v in stats.items()}
        }
        
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(export_data, f, indent=2, ensure_ascii=False)
        
        print(f"\n✅ Statistiques exportées : {output_path}")
    
    def generate_full_report(self, output_dir: str = 'output') -> None:
        """
        Génère un rapport complet avec tous les exports.
        
        Args:
            output_dir (str): Répertoire de sortie
        """
        # Créer le répertoire de sortie
        Path(output_dir).mkdir(parents=True, exist_ok=True)
        
        print(f"\n{'='*60}")
        print("🔄 Génération du rapport complet...")
        print(f"{'='*60}")
        
        # Charger et extraire
        self.load_file()
        self.extract_info()
        self.extract_transactions()
        self.calculate_statistics()
        self.analyze_by_symbol()
        
        # Exporter
        self.export_to_csv(f"{output_dir}/transactions.csv")
        self.export_stats_to_json(f"{output_dir}/statistiques.json")
        self.plot_balance_curve(f"{output_dir}/balance_curve.png")
        self.plot_profit_distribution(f"{output_dir}/profit_distribution.png")
        
        print(f"\n{'='*60}")
        print("✅ Rapport complet généré avec succès !")
        print(f"📁 Fichiers disponibles dans : {output_dir}/")
        print(f"{'='*60}")


# Exemple d'utilisation
if __name__ == "__main__":
    # Initialiser l'extracteur
    extractor = MT5DataExtractor('ReportTester1511739399.xlsx')
    
    # Générer le rapport complet
    extractor.generate_full_report(output_dir='rapport_mt5')
    
    # Ou utiliser les méthodes individuellement :
    """
    extractor.load_file()
    extractor.extract_info()
    extractor.extract_transactions()
    stats = extractor.calculate_statistics()
    symbol_analysis = extractor.analyze_by_symbol()
    extractor.plot_balance_curve()
    extractor.plot_profit_distribution()
    """
