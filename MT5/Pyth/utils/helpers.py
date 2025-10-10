"""
Helpers
Fonctions utilitaires diverses
"""

import pandas as pd
import numpy as np
from typing import Any, List, Dict, Tuple
from datetime import datetime, timedelta


def format_price(price: float, digits: int = 5) -> str:
    """Formate un prix"""
    return f"{price:.{digits}f}"


def format_volume(volume: float) -> str:
    """Formate un volume"""
    return f"{volume:.2f}"


def format_percent(value: float) -> str:
    """Formate un pourcentage"""
    return f"{value:.2f}%"


def format_currency(amount: float, currency: str = "$") -> str:
    """Formate une valeur monétaire"""
    return f"{currency}{amount:,.2f}"


def points_to_price(points: float, point_size: float = 0.0001) -> float:
    """Convertit des points en prix"""
    return points * point_size


def price_to_points(price_distance: float, point_size: float = 0.0001) -> float:
    """Convertit une distance de prix en points"""
    return price_distance / point_size


def normalize_symbol(symbol: str) -> str:
    """Normalise un nom de symbole"""
    return symbol.upper().replace(" ", "").replace("/", "")


def is_market_open(current_time: datetime = None) -> bool:
    """
    Vérifie si le marché Forex est ouvert
    (Simplifié - du dimanche 22h au vendredi 22h GMT)
    """
    if current_time is None:
        current_time = datetime.utcnow()
    
    day_of_week = current_time.weekday()  # 0=Lundi, 6=Dimanche
    hour = current_time.hour
    
    # Samedi (jour 5) = fermé
    if day_of_week == 5:
        return False
    
    # Dimanche (jour 6) = ouvert après 22h
    if day_of_week == 6:
        return hour >= 22
    
    # Vendredi (jour 4) = fermé après 22h
    if day_of_week == 4:
        return hour < 22
    
    # Autres jours = ouvert
    return True


def calculate_pip_value(
    symbol: str,
    volume: float,
    account_currency: str = "USD"
) -> float:
    """
    Calcule la valeur d'un pip
    (Simplifié pour les paires majeures)
    """
    # Pour les paires en USD (EURUSD, GBPUSD, etc.)
    if symbol.endswith("USD"):
        return volume * 10  # 10 USD par lot standard pour 1 pip
    
    # Valeur approximative pour autres paires
    return volume * 10


def calculate_lot_size_from_risk(
    account_balance: float,
    risk_percent: float,
    sl_points: float,
    point_value: float = 10.0
) -> float:
    """
    Calcule la taille de lot basée sur le risque
    
    Args:
        account_balance: Balance du compte
        risk_percent: % du compte à risquer
        sl_points: Distance du SL en points
        point_value: Valeur d'un point par lot
    
    Returns:
        Taille de lot
    """
    risk_amount = account_balance * (risk_percent / 100)
    lot_size = risk_amount / (sl_points * point_value)
    return round(lot_size, 2)


def time_to_string(dt: datetime, format: str = "%Y-%m-%d %H:%M:%S") -> str:
    """Convertit datetime en string"""
    return dt.strftime(format)


def string_to_time(s: str, format: str = "%Y-%m-%d %H:%M:%S") -> datetime:
    """Convertit string en datetime"""
    return datetime.strptime(s, format)


def get_business_days(start_date: datetime, end_date: datetime) -> int:
    """Compte les jours ouvrables entre deux dates"""
    return np.busday_count(
        start_date.date(),
        end_date.date()
    )


def chunker(lst: List[Any], chunk_size: int) -> List[List[Any]]:
    """Divise une liste en chunks"""
    return [lst[i:i + chunk_size] for i in range(0, len(lst), chunk_size)]


def dict_to_table(data: Dict[str, Any], headers: List[str] = None) -> str:
    """
    Convertit un dictionnaire en table formatée
    """
    if headers is None:
        headers = ["Key", "Value"]
    
    lines = []
    lines.append(" | ".join(headers))
    lines.append("-" * 50)
    
    for key, value in data.items():
        lines.append(f"{key} | {value}")
    
    return "\n".join(lines)


def calculate_compound_return(
    initial_capital: float,
    monthly_return_pct: float,
    months: int
) -> float:
    """
    Calcule le retour composé
    
    Args:
        initial_capital: Capital initial
        monthly_return_pct: Rendement mensuel en %
        months: Nombre de mois
    
    Returns:
        Capital final
    """
    monthly_rate = monthly_return_pct / 100
    final_capital = initial_capital * ((1 + monthly_rate) ** months)
    return final_capital


def calculate_required_margin(
    symbol_price: float,
    volume: float,
    leverage: int = 100
) -> float:
    """
    Calcule la marge requise
    
    Args:
        symbol_price: Prix du symbole
        volume: Volume en lots
        leverage: Levier
    
    Returns:
        Marge requise
    """
    # Pour Forex: Marge = (Volume * Contract Size * Price) / Leverage
    contract_size = 100000  # 1 lot standard = 100,000 unités
    margin = (volume * contract_size * symbol_price) / leverage
    return margin


def generate_report_filename(
    prefix: str = "report",
    extension: str = "csv",
    include_timestamp: bool = True
) -> str:
    """
    Génère un nom de fichier pour un rapport
    
    Args:
        prefix: Préfixe du fichier
        extension: Extension (sans le point)
        include_timestamp: Inclure timestamp
    
    Returns:
        Nom de fichier
    """
    if include_timestamp:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        return f"{prefix}_{timestamp}.{extension}"
    else:
        return f"{prefix}.{extension}"


__all__ = [
    'format_price',
    'format_volume',
    'format_percent',
    'format_currency',
    'points_to_price',
    'price_to_points',
    'normalize_symbol',
    'is_market_open',
    'calculate_pip_value',
    'calculate_lot_size_from_risk',
    'time_to_string',
    'string_to_time',
    'get_business_days',
    'chunker',
    'dict_to_table',
    'calculate_compound_return',
    'calculate_required_margin',
    'generate_report_filename',
]


if __name__ == "__main__":
    # Tests
    print("🔧 Test Helpers")
    print("=" * 60)
    
    # Format
    print("\n📊 Formatage:")
    print(f"  Prix: {format_price(1.10234)}")
    print(f"  Volume: {format_volume(0.01)}")
    print(f"  Pourcentage: {format_percent(15.567)}")
    print(f"  Monnaie: {format_currency(10000)}")
    
    # Conversions
    print("\n🔄 Conversions:")
    print(f"  100 points = {points_to_price(100)} prix")
    print(f"  0.01 prix = {price_to_points(0.01)} points")
    
    # Marché ouvert
    print("\n🕐 Marché:")
    print(f"  Ouvert maintenant? {is_market_open()}")
    
    # Calculs
    print("\n💰 Calculs:")
    lot = calculate_lot_size_from_risk(10000, 1.0, 50, 10)
    print(f"  Lot size (1% risk, 50pts SL): {lot}")
    
    compound = calculate_compound_return(10000, 5, 12)
    print(f"  Rendement composé (5%/mois, 12 mois): {format_currency(compound)}")
    
    margin = calculate_required_margin(1.1000, 1.0, 100)
    print(f"  Marge requise (1 lot, 1:100): {format_currency(margin)}")
    
    print("\n" + "=" * 60)
    print("✅ Tests terminés")

