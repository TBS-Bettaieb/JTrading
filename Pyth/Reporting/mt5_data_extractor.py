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
from typing import Dict, Tuple, Optional, List
import json
from pathlib import Path
import warnings
from tqdm import tqdm


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
    
    def __init__(self, file_path: str, chunk_size: int = 10000, show_progress: bool = True):
        """
        Initialise l'extracteur avec le chemin du fichier.
        
        Args:
            file_path (str): Chemin vers le fichier Excel MT5
            chunk_size (int): Taille des chunks pour le traitement des gros fichiers
            show_progress (bool): Afficher les barres de progression
        """
        self.file_path = file_path
        self.chunk_size = chunk_size
        self.show_progress = show_progress
        self.df_raw = None
        self.info = {}
        self.df_transactions = None
        self.df_ordres = None
        self.transactions_start = None
        self.ordres_start = None
        self.stats = {}
        
        # Configuration des warnings
        warnings.filterwarnings('ignore', category=UserWarning)
        warnings.filterwarnings('ignore', category=FutureWarning)
        
    def load_file(self) -> None:
        """Charge le fichier Excel en mémoire avec gestion d'erreurs améliorée."""
        try:
            if self.show_progress:
                print(f"🔄 Chargement du fichier : {self.file_path}")
            
            # Vérifier l'existence du fichier
            if not Path(self.file_path).exists():
                raise FileNotFoundError(f"❌ Fichier non trouvé : {self.file_path}")
            
            # Vérifier les dépendances
            try:
                import openpyxl
            except ImportError:
                print("❌ Dépendance manquante : openpyxl")
                print("💡 Installez avec : pip install openpyxl")
                raise ImportError("openpyxl est requis pour lire les fichiers Excel")
            
            # Charger le fichier avec gestion des erreurs
            self.df_raw = pd.read_excel(
                self.file_path, 
                header=None,
                engine='openpyxl'
            )
            
            print(f"✅ Fichier chargé : {self.file_path}")
            print(f"   Dimensions : {self.df_raw.shape[0]:,} lignes × {self.df_raw.shape[1]} colonnes")
            print(f"   Taille mémoire : {self.df_raw.memory_usage(deep=True).sum() / 1024**2:.2f} MB")
            
        except FileNotFoundError:
            raise FileNotFoundError(f"❌ Fichier non trouvé : {self.file_path}")
        except ImportError as e:
            raise ImportError(f"❌ Dépendance manquante : {str(e)}")
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
        VERSION CORRIGÉE - Utilise df_raw au lieu de relire le fichier
        
        Returns:
            pd.DataFrame: DataFrame contenant les transactions
        """
        if self.df_raw is None:
            raise ValueError("Charger d'abord le fichier avec load_file()")
        
        # Affichage du message de progression
        if hasattr(self, 'show_progress') and self.show_progress:
            print("🔄 Recherche de la section Transactions...")

        # Trouver la ligne de début de la section Transactions
        self.transactions_start = self._find_section('Transactions')

        if self.transactions_start is None:
            raise ValueError("❌ Section 'Transactions' non trouvée dans le fichier")

        # Vérifier que la ligne d'en-tête et au moins une ligne de données existent après "Transactions"
        header_row = self.transactions_start + 1
        data_start = header_row + 1
        if header_row >= len(self.df_raw):
            raise ValueError(
                f"❌ Ligne d'en-tête {header_row} en dehors des limites du fichier "
                f"({len(self.df_raw)} lignes)"
            )
        if data_start > len(self.df_raw):
            raise ValueError(
                f"❌ Il n'y a aucune donnée de transaction après les en-têtes à la ligne {header_row}"
            )

        if hasattr(self, 'show_progress') and self.show_progress:
            print(f"📍 Section Transactions trouvée à la ligne {self.transactions_start}")
            print("🔄 Extraction des transactions...")
        
        # CORRECTION PRINCIPALE : Extraire directement depuis df_raw
        # au lieu d'utiliser pd.read_excel() qui pose problème
        
        # La ligne des en-têtes est juste après la ligne "Transactions"
        header_row = self.transactions_start + 1
        
        # Vérifier que la ligne d'en-tête existe
        if header_row >= len(self.df_raw):
            raise ValueError(
                f"❌ Ligne d'en-tête {header_row} en dehors des limites du fichier "
                f"({len(self.df_raw)} lignes)"
            )
        
        # Extraire les en-têtes de colonnes
        headers = self.df_raw.iloc[header_row].values
        
        # Les données commencent après la ligne d'en-têtes
        data_start = header_row + 1
        
        # Extraire toutes les données après l'en-tête
        df_data = self.df_raw.iloc[data_start:].copy()
        
        # Assigner les en-têtes comme noms de colonnes
        df_data.columns = headers
        
        # Réinitialiser l'index pour avoir des numéros de ligne propres
        df_data = df_data.reset_index(drop=True)
        
        # Nettoyer les données
        # 1. Convertir la colonne Heure en datetime
        if 'Heure' in df_data.columns:
            df_data['Heure'] = pd.to_datetime(
                df_data['Heure'], 
                errors='coerce'
            )
        
        # 2. Supprimer les lignes vides (où Opération est NaN)
        if 'Opération' in df_data.columns:
            df_data = df_data.dropna(subset=['Opération'])
        
        # Stocker le DataFrame nettoyé
        self.df_transactions = df_data
        
        # Message de confirmation
        if hasattr(self, 'show_progress') and self.show_progress:
            print(f"\n✅ {len(self.df_transactions):,} transactions extraites")
            print(f"📋 Colonnes : {list(self.df_transactions.columns)}")
        
        return self.df_transactions
    
    def extract_ordres(self) -> pd.DataFrame:
        """
        Extrait les ordres du fichier.
        VERSION CORRIGÉE - Utilise df_raw au lieu de relire le fichier
        
        Returns:
            pd.DataFrame: DataFrame contenant les ordres
        """
        if self.df_raw is None:
            raise ValueError("Charger d'abord le fichier avec load_file()")
        
        # Trouver la ligne de début de la section Ordres
        self.ordres_start = self._find_section('Ordres')
        
        if self.ordres_start is None:
            raise ValueError("❌ Section 'Ordres' non trouvée dans le fichier")
        
        # Si on n'a pas encore trouvé la section Transactions, la chercher
        if self.transactions_start is None:
            self.transactions_start = self._find_section('Transactions')
        
        # CORRECTION : Extraire directement depuis df_raw
        
        # Ligne des en-têtes
        header_row = self.ordres_start + 1
        
        # Données commencent après l'en-tête
        data_start = header_row + 1
        
        # Calculer où s'arrêter (juste avant la section Transactions)
        if self.transactions_start:
            data_end = self.transactions_start
        else:
            # Si pas de section Transactions, aller jusqu'à la fin
            data_end = len(self.df_raw)
        
        # Extraire les en-têtes
        headers = self.df_raw.iloc[header_row].values
        
        # Extraire les données
        df_data = self.df_raw.iloc[data_start:data_end].copy()
        
        # Assigner les colonnes
        df_data.columns = headers
        
        # Réinitialiser l'index
        df_data = df_data.reset_index(drop=True)
        
        # Nettoyer les données
        if 'Heure d\'ouverture' in df_data.columns:
            df_data['Heure d\'ouverture'] = pd.to_datetime(
                df_data['Heure d\'ouverture'], 
                errors='coerce'
            )
        
        # Alternative pour d'autres noms de colonnes
        if "Heure d'ouverture" in df_data.columns:
            df_data["Heure d'ouverture"] = pd.to_datetime(
                df_data["Heure d'ouverture"], 
                errors='coerce'
            )
        
        # Stocker le DataFrame
        self.df_ordres = df_data
        
        if hasattr(self, 'show_progress') and self.show_progress:
            print(f"\n✅ {len(self.df_ordres):,} ordres extraits")
        
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
        
        # Stocker les stats pour utilisation dans d'autres méthodes
        self.stats = stats
        
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
    
    def calculate_drawdown_analysis(self) -> Dict:
        """
        Calcule une analyse détaillée du drawdown.
        
        Returns:
            Dict: Dictionnaire contenant l'analyse du drawdown
        """
        if self.df_transactions is None or 'Balance' not in self.df_transactions.columns:
            raise ValueError("Transactions non disponibles ou colonne Balance manquante")
        
        if self.show_progress:
            print("🔄 Calcul de l'analyse du drawdown...")
        
        # Calculer le drawdown
        balance_data = self.df_transactions['Balance'].dropna()
        if len(balance_data) == 0:
            return {}
        
        # Calculer le maximum cumulé
        running_max = balance_data.expanding().max()
        drawdown = (balance_data - running_max) / running_max * 100
        
        # Trouver les périodes de drawdown
        drawdown_periods = []
        in_drawdown = False
        start_idx = None
        
        for i, dd in enumerate(drawdown):
            if dd < 0 and not in_drawdown:
                in_drawdown = True
                start_idx = i
            elif dd >= 0 and in_drawdown:
                in_drawdown = False
                if start_idx is not None:
                    period_dd = drawdown.iloc[start_idx:i+1]
                    drawdown_periods.append({
                        'start': balance_data.index[start_idx],
                        'end': balance_data.index[i],
                        'max_drawdown': period_dd.min(),
                        'duration': i - start_idx + 1
                    })
        
        # Statistiques du drawdown
        max_drawdown = drawdown.min()
        max_drawdown_idx = drawdown.idxmin()
        
        drawdown_stats = {
            'max_drawdown_percent': max_drawdown,
            'max_drawdown_value': balance_data.iloc[max_drawdown_idx] - running_max.iloc[max_drawdown_idx],
            'max_drawdown_date': balance_data.index[max_drawdown_idx],
            'avg_drawdown': drawdown[drawdown < 0].mean() if len(drawdown[drawdown < 0]) > 0 else 0,
            'drawdown_periods': len(drawdown_periods),
            'longest_drawdown_duration': max([p['duration'] for p in drawdown_periods]) if drawdown_periods else 0,
            'recovery_factor': abs(self.stats.get('total_profit', 0) / max_drawdown) if max_drawdown != 0 else 0
        }
        
        print(f"\n📉 Analyse du Drawdown :")
        print(f"   Drawdown Maximal.............. {drawdown_stats['max_drawdown_percent']:.2f}%")
        print(f"   Valeur Max Drawdown........... {drawdown_stats['max_drawdown_value']:.2f}")
        print(f"   Date Max Drawdown............. {drawdown_stats['max_drawdown_date']}")
        print(f"   Drawdown Moyen................ {drawdown_stats['avg_drawdown']:.2f}%")
        print(f"   Périodes de Drawdown.......... {drawdown_stats['drawdown_periods']}")
        print(f"   Durée Max Drawdown............ {drawdown_stats['longest_drawdown_duration']} trades")
        print(f"   Facteur de Récupération....... {drawdown_stats['recovery_factor']:.2f}")
        
        return drawdown_stats
    
    def plot_drawdown_curve(self, save_path: Optional[str] = None) -> None:
        """
        Génère le graphique de l'évolution du drawdown.
        
        Args:
            save_path (Optional[str]): Chemin pour sauvegarder le graphique
        """
        if self.df_transactions is None or 'Balance' not in self.df_transactions.columns:
            raise ValueError("Transactions non disponibles ou colonne Balance manquante")
        
        balance_data = self.df_transactions['Balance'].dropna()
        if len(balance_data) == 0:
            print("❌ Aucune donnée de balance disponible")
            return
        
        # Calculer le drawdown
        running_max = balance_data.expanding().max()
        drawdown = (balance_data - running_max) / running_max * 100
        
        fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(14, 10), sharex=True)
        
        # Graphique de la balance
        ax1.plot(balance_data.index, balance_data.values, linewidth=2, color='#2E86AB', label='Balance')
        ax1.plot(balance_data.index, running_max.values, linewidth=1, color='green', linestyle='--', alpha=0.7, label='Maximum')
        ax1.set_title('Évolution de la Balance et Drawdown', fontsize=16, fontweight='bold')
        ax1.set_ylabel('Balance (USD)', fontsize=12)
        ax1.grid(True, alpha=0.3)
        ax1.legend()
        
        # Graphique du drawdown
        ax2.fill_between(balance_data.index, drawdown.values, 0, alpha=0.3, color='red', label='Drawdown')
        ax2.plot(balance_data.index, drawdown.values, linewidth=1, color='red')
        ax2.set_xlabel('Index des Transactions', fontsize=12)
        ax2.set_ylabel('Drawdown (%)', fontsize=12)
        ax2.grid(True, alpha=0.3)
        ax2.legend()
        
        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
            print(f"\n✅ Graphique drawdown sauvegardé : {save_path}")
        
        plt.show()
    
    def analyze_trading_sessions(self) -> Dict:
        """
        Analyse les performances par session de trading.
        
        Returns:
            Dict: Statistiques par session
        """
        if self.df_transactions is None or 'Heure' not in self.df_transactions.columns:
            raise ValueError("Transactions non disponibles ou colonne Heure manquante")
        
        if self.show_progress:
            print("🔄 Analyse des sessions de trading...")
        
        trades = self.df_transactions[
            (self.df_transactions['Type'].notna()) & 
            (self.df_transactions['Type'] != 'balance')
        ].copy()
        
        if len(trades) == 0:
            return {}
        
        # Extraire l'heure de chaque trade
        trades['Hour'] = trades['Heure'].dt.hour
        trades['DayOfWeek'] = trades['Heure'].dt.day_name()
        
        # Analyse par heure
        hourly_stats = trades.groupby('Hour').agg({
            'Profit': ['count', 'sum', 'mean'],
            'Opération': 'count'
        }).round(2)
        
        hourly_stats.columns = ['Nombre Trades', 'Profit Total', 'Profit Moyen', 'Volume']
        hourly_stats['Win Rate %'] = (trades.groupby('Hour')['Profit'].apply(lambda x: (x > 0).sum() / len(x) * 100)).round(2)
        
        # Analyse par jour de la semaine
        daily_stats = trades.groupby('DayOfWeek').agg({
            'Profit': ['count', 'sum', 'mean'],
            'Opération': 'count'
        }).round(2)
        
        daily_stats.columns = ['Nombre Trades', 'Profit Total', 'Profit Moyen', 'Volume']
        daily_stats['Win Rate %'] = (trades.groupby('DayOfWeek')['Profit'].apply(lambda x: (x > 0).sum() / len(x) * 100)).round(2)
        
        session_analysis = {
            'hourly_stats': hourly_stats,
            'daily_stats': daily_stats,
            'best_hour': hourly_stats['Profit Total'].idxmax(),
            'worst_hour': hourly_stats['Profit Total'].idxmin(),
            'best_day': daily_stats['Profit Total'].idxmax(),
            'worst_day': daily_stats['Profit Total'].idxmin()
        }
        
        print(f"\n⏰ Analyse des Sessions :")
        print(f"   Meilleure Heure................ {session_analysis['best_hour']}:00")
        print(f"   Pire Heure..................... {session_analysis['worst_hour']}:00")
        print(f"   Meilleur Jour.................. {session_analysis['best_day']}")
        print(f"   Pire Jour...................... {session_analysis['worst_day']}")
        
        return session_analysis
    
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
        Génère un rapport complet avec tous les exports et analyses avancées.
        
        Args:
            output_dir (str): Répertoire de sortie
        """
        # Créer le répertoire de sortie
        Path(output_dir).mkdir(parents=True, exist_ok=True)
        
        print(f"\n{'='*60}")
        print("🔄 Génération du rapport complet...")
        print(f"{'='*60}")
        
        try:
            # Charger et extraire
            self.load_file()
            self.extract_info()
            self.extract_transactions()
            self.calculate_statistics()
            self.analyze_by_symbol()
            
            # Analyses avancées
            drawdown_analysis = self.calculate_drawdown_analysis()
            session_analysis = self.analyze_trading_sessions()
            
            # Exporter les données
            self.export_to_csv(f"{output_dir}/transactions.csv")
            self.export_stats_to_json(f"{output_dir}/statistiques.json")
            
            # Exporter les analyses avancées
            with open(f"{output_dir}/drawdown_analysis.json", 'w', encoding='utf-8') as f:
                json.dump(drawdown_analysis, f, indent=2, ensure_ascii=False, default=str)
            
            with open(f"{output_dir}/session_analysis.json", 'w', encoding='utf-8') as f:
                json.dump(session_analysis, f, indent=2, ensure_ascii=False, default=str)
            
            # Générer les graphiques
            self.plot_balance_curve(f"{output_dir}/balance_curve.png")
            self.plot_profit_distribution(f"{output_dir}/profit_distribution.png")
            self.plot_drawdown_curve(f"{output_dir}/drawdown_curve.png")
            
            # Générer un rapport HTML
            self.generate_html_report(f"{output_dir}/rapport_complet.html")
            
            print(f"\n{'='*60}")
            print("✅ Rapport complet généré avec succès !")
            print(f"📁 Fichiers disponibles dans : {output_dir}/")
            print(f"   📊 transactions.csv")
            print(f"   📈 statistiques.json")
            print(f"   📉 drawdown_analysis.json")
            print(f"   ⏰ session_analysis.json")
            print(f"   📊 balance_curve.png")
            print(f"   📊 profit_distribution.png")
            print(f"   📉 drawdown_curve.png")
            print(f"   🌐 rapport_complet.html")
            print(f"{'='*60}")
            
        except Exception as e:
            print(f"❌ Erreur lors de la génération du rapport : {str(e)}")
            raise
    
    def generate_html_report(self, output_path: str) -> None:
        """
        Génère un rapport HTML complet.
        
        Args:
            output_path (str): Chemin du fichier HTML de sortie
        """
        if not self.stats or not self.info:
            print("❌ Statistiques ou informations manquantes pour le rapport HTML")
            return
        
        html_content = f"""
        <!DOCTYPE html>
        <html lang="fr">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Rapport de Trading MT5</title>
            <style>
                body {{ font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }}
                .container {{ max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 10px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }}
                h1 {{ color: #2E86AB; text-align: center; }}
                h2 {{ color: #A23B72; border-bottom: 2px solid #A23B72; padding-bottom: 5px; }}
                .stats-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin: 20px 0; }}
                .stat-card {{ background: #f8f9fa; padding: 15px; border-radius: 8px; border-left: 4px solid #2E86AB; }}
                .stat-value {{ font-size: 24px; font-weight: bold; color: #2E86AB; }}
                .stat-label {{ color: #666; margin-top: 5px; }}
                .positive {{ color: #28a745; }}
                .negative {{ color: #dc3545; }}
                .neutral {{ color: #6c757d; }}
                table {{ width: 100%; border-collapse: collapse; margin: 20px 0; }}
                th, td {{ padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }}
                th {{ background-color: #2E86AB; color: white; }}
                .footer {{ text-align: center; margin-top: 40px; color: #666; }}
            </style>
        </head>
        <body>
            <div class="container">
                <h1>📊 Rapport de Trading MT5</h1>
                
                <h2>📋 Informations Générales</h2>
                <div class="stats-grid">
                    <div class="stat-card">
                        <div class="stat-value">{self.info.get('expert', 'N/A')}</div>
                        <div class="stat-label">Expert Advisor</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value">{self.info.get('symbole', 'N/A')}</div>
                        <div class="stat-label">Symbole</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value">{self.info.get('depot_initial', 'N/A')}</div>
                        <div class="stat-label">Dépôt Initial</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value">{self.info.get('profit_total', 'N/A')}</div>
                        <div class="stat-label">Profit Total</div>
                    </div>
                </div>
                
                <h2>📈 Statistiques de Trading</h2>
                <div class="stats-grid">
                    <div class="stat-card">
                        <div class="stat-value">{self.stats.get('total_trades', 0):,}</div>
                        <div class="stat-label">Total Trades</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value positive">{self.stats.get('win_rate', 0):.2f}%</div>
                        <div class="stat-label">Win Rate</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value positive">{self.stats.get('profit_factor', 0):.2f}</div>
                        <div class="stat-label">Profit Factor</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value {'positive' if self.stats.get('total_profit', 0) > 0 else 'negative'}">{self.stats.get('total_profit', 0):.2f}</div>
                        <div class="stat-label">Profit Total</div>
                    </div>
                </div>
                
                <h2>📊 Détails des Performances</h2>
                <table>
                    <tr><th>Métrique</th><th>Valeur</th></tr>
                    <tr><td>Trades Gagnants</td><td>{self.stats.get('winning_trades', 0):,}</td></tr>
                    <tr><td>Trades Perdants</td><td>{self.stats.get('losing_trades', 0):,}</td></tr>
                    <tr><td>Profit Moyen (Gagnants)</td><td>{self.stats.get('avg_profit_win', 0):.2f}</td></tr>
                    <tr><td>Perte Moyenne (Perdants)</td><td>{self.stats.get('avg_loss', 0):.2f}</td></tr>
                    <tr><td>Commission Totale</td><td>{self.stats.get('total_commission', 0):.2f}</td></tr>
                </table>
                
                <div class="footer">
                    <p>Rapport généré le {datetime.now().strftime('%d/%m/%Y à %H:%M')}</p>
                    <p>MT5 Data Extractor v2.0</p>
                </div>
            </div>
        </body>
        </html>
        """
        
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(html_content)
        
        print(f"\n✅ Rapport HTML généré : {output_path}")


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
