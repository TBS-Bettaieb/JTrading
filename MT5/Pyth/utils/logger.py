"""
Logger
Configuration du système de logging
"""

import logging
import os
from datetime import datetime
from typing import Optional


def setup_logger(
    name: str = "trading_bot",
    log_file: Optional[str] = None,
    level: str = "INFO",
    log_to_console: bool = True,
    log_format: Optional[str] = None
) -> logging.Logger:
    """
    Configure et retourne un logger
    
    Args:
        name: Nom du logger
        log_file: Fichier de log (optionnel)
        level: Niveau de log (DEBUG, INFO, WARNING, ERROR, CRITICAL)
        log_to_console: Logger aussi vers la console
        log_format: Format personnalisé des messages
    
    Returns:
        Logger configuré
    """
    # Créer le logger
    logger = logging.getLogger(name)
    logger.setLevel(getattr(logging, level.upper()))
    
    # Éviter les doublons de handlers
    if logger.hasHandlers():
        logger.handlers.clear()
    
    # Format par défaut
    if log_format is None:
        log_format = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    
    formatter = logging.Formatter(log_format)
    
    # Handler pour fichier
    if log_file:
        # Créer le répertoire logs s'il n'existe pas
        log_dir = os.path.dirname(log_file)
        if log_dir and not os.path.exists(log_dir):
            os.makedirs(log_dir)
        
        file_handler = logging.FileHandler(log_file, encoding='utf-8')
        file_handler.setLevel(logging.DEBUG)
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)
    
    # Handler pour console
    if log_to_console:
        console_handler = logging.StreamHandler()
        console_handler.setLevel(getattr(logging, level.upper()))
        console_handler.setFormatter(formatter)
        logger.addHandler(console_handler)
    
    return logger


def get_logger(name: str = "trading_bot") -> logging.Logger:
    """
    Récupère un logger existant ou en crée un nouveau
    
    Args:
        name: Nom du logger
    
    Returns:
        Logger
    """
    logger = logging.getLogger(name)
    
    # Si le logger n'a pas de handlers, le configurer
    if not logger.hasHandlers():
        logger = setup_logger(name)
    
    return logger


class TradeLogger:
    """
    Logger spécialisé pour les trades
    Enregistre les trades dans un fichier CSV
    """
    
    def __init__(self, log_file: str = "trades.csv"):
        self.log_file = log_file
        
        # Créer le fichier avec en-tête si n'existe pas
        if not os.path.exists(log_file):
            with open(log_file, 'w') as f:
                f.write("Timestamp,Action,Symbol,Direction,Volume,Price,SL,TP,Comment\n")
    
    def log_trade(
        self,
        action: str,
        symbol: str,
        direction: str,
        volume: float,
        price: float,
        sl: float = 0,
        tp: float = 0,
        comment: str = ""
    ):
        """
        Enregistre un trade
        
        Args:
            action: 'OPEN' ou 'CLOSE'
            symbol: Symbole
            direction: 'BUY' ou 'SELL'
            volume: Volume
            price: Prix
            sl: Stop Loss
            tp: Take Profit
            comment: Commentaire
        """
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
        line = f"{timestamp},{action},{symbol},{direction},{volume},{price},{sl},{tp},{comment}\n"
        
        with open(self.log_file, 'a') as f:
            f.write(line)


if __name__ == "__main__":
    # Test du logger
    print("🔧 Test Logger")
    print("=" * 60)
    
    # Setup logger de base
    logger = setup_logger(
        name="test_logger",
        log_file="logs/test.log",
        level="DEBUG"
    )
    
    # Tests
    logger.debug("Message de debug")
    logger.info("Message d'information")
    logger.warning("Message d'avertissement")
    logger.error("Message d'erreur")
    
    # Test trade logger
    trade_logger = TradeLogger("logs/trades_test.csv")
    
    trade_logger.log_trade(
        action="OPEN",
        symbol="EURUSD",
        direction="BUY",
        volume=0.01,
        price=1.10000,
        sl=1.09500,
        tp=1.11000,
        comment="Test trade"
    )
    
    print("\n✅ Logs créés:")
    print("  - logs/test.log")
    print("  - logs/trades_test.csv")
    print("\n" + "=" * 60)

