"""
Live Trading Script
Script pour le trading en temps réel sur MT5
"""

import argparse
import time
from datetime import datetime
import signal
import sys

from config import StrategyConfig
from strategies import FreeCandleStrategy
from live_trading import MT5Connector, TradeExecutor
from risk_management import PositionSizer
from utils import setup_logger


class LiveTradingBot:
    """Bot de trading en temps réel"""
    
    def __init__(
        self,
        connector: MT5Connector,
        executor: TradeExecutor,
        strategy: FreeCandleStrategy,
        config: StrategyConfig
    ):
        self.connector = connector
        self.executor = executor
        self.strategy = strategy
        self.config = config
        self.logger = setup_logger('live_trading')
        self.running = False
        
        # Position sizer
        self.position_sizer = PositionSizer()
    
    def start(self):
        """Démarre le bot"""
        self.running = True
        self.logger.info("=" * 80)
        self.logger.info("LIVE TRADING BOT STARTED")
        self.logger.info("=" * 80)
        self.logger.info(f"Symbol: {self.config.symbol.symbol}")
        self.logger.info(f"Timeframe: {self.config.symbol.timeframe}")
        self.logger.info(f"Risk: {self.config.money_management.risk_percent}%")
        self.logger.info("=" * 80)
        
        last_check_time = None
        
        while self.running:
            try:
                current_time = datetime.now()
                
                # Vérifier toutes les minutes
                if last_check_time is None or (current_time - last_check_time).total_seconds() >= 60:
                    last_check_time = current_time
                    
                    # Vérifier les signaux
                    self.check_signals()
                    
                    # Gérer les positions ouvertes
                    self.manage_positions()
                
                # Attendre 1 seconde
                time.sleep(1)
                
            except KeyboardInterrupt:
                self.logger.info("\n⚠️ Arrêt demandé par l'utilisateur")
                break
            except Exception as e:
                self.logger.error(f"❌ Erreur: {e}", exc_info=True)
                time.sleep(5)
        
        self.stop()
    
    def stop(self):
        """Arrête le bot"""
        self.running = False
        self.logger.info("=" * 80)
        self.logger.info("LIVE TRADING BOT STOPPED")
        self.logger.info("=" * 80)
    
    def check_signals(self):
        """Vérifie les nouveaux signaux"""
        try:
            # Récupérer les données
            df = self.connector.get_ohlcv(
                self.config.symbol.symbol,
                self.config.symbol.timeframe,
                count=500
            )
            
            if df is None:
                self.logger.warning("⚠️ Impossible de récupérer les données")
                return
            
            # Générer les signaux
            signals = self.strategy.generate_signals(df)
            
            if not signals:
                return
            
            # Prendre seulement le dernier signal (le plus récent)
            signal = signals[-1]
            
            # Vérifier si on a déjà une position
            positions = self.connector.get_open_positions(
                symbol=self.config.symbol.symbol,
                magic=self.config.money_management.magic_number
            )
            
            if self.config.money_management.one_pos_per_symbol and len(positions) > 0:
                return
            
            # Obtenir les infos du compte
            account = self.connector.get_account_info()
            if not account:
                return
            
            # Calculer la taille de position
            volume = self.position_sizer.fixed_percentage_risk(
                capital=account['equity'],
                risk_percent=self.config.money_management.risk_percent,
                entry_price=signal.entry_price,
                stop_loss=signal.sl_price,
                point_value=10.0
            )
            
            # Vérifier le volume minimum
            if volume < self.config.money_management.min_volume:
                self.logger.warning(f"⚠️ Volume trop petit: {volume}")
                return
            
            # Ouvrir la position
            direction = 'BUY' if signal.direction > 0 else 'SELL'
            
            self.logger.info(f"\n🎯 NOUVEAU SIGNAL: {direction}")
            self.logger.info(f"   Entry: {signal.entry_price:.5f}")
            self.logger.info(f"   SL: {signal.sl_price:.5f}")
            self.logger.info(f"   TP: {signal.tp_price:.5f}")
            self.logger.info(f"   Volume: {volume:.2f}")
            self.logger.info(f"   RR: 1:{signal.rr_ratio:.2f}")
            self.logger.info(f"   Confidence: {signal.confidence:.2f}")
            
            ticket = self.executor.open_position(
                symbol=self.config.symbol.symbol,
                direction=direction,
                volume=volume,
                sl=signal.sl_price,
                tp=signal.tp_price,
                magic=self.config.money_management.magic_number,
                comment=f"FreeCandleBot|RR:{signal.rr_ratio:.1f}"
            )
            
            if ticket:
                self.logger.info(f"✅ Position ouverte: #{ticket}")
            
        except Exception as e:
            self.logger.error(f"❌ Erreur check_signals: {e}", exc_info=True)
    
    def manage_positions(self):
        """Gère les positions ouvertes"""
        try:
            positions = self.connector.get_open_positions(
                symbol=self.config.symbol.symbol,
                magic=self.config.money_management.magic_number
            )
            
            for pos in positions:
                # Récupérer les données actuelles
                df = self.connector.get_ohlcv(
                    self.config.symbol.symbol,
                    self.config.symbol.timeframe,
                    count=50
                )
                
                if df is None:
                    continue
                
                # Préparer les données avec indicateurs
                df = self.strategy.prepare_data(df)
                
                last_row = df.iloc[-1]
                
                # Vérifier fermeture sur bande opposée
                if self.config.position_management.close_on_opposite_band:
                    should_close = False
                    
                    if pos['type'] == 'BUY' and last_row['high'] >= last_row['bb_upper']:
                        should_close = True
                        reason = "Touched opposite band (upper)"
                    elif pos['type'] == 'SELL' and last_row['low'] <= last_row['bb_lower']:
                        should_close = True
                        reason = "Touched opposite band (lower)"
                    
                    if should_close:
                        self.logger.info(f"🔴 Fermeture #{pos['ticket']}: {reason}")
                        self.executor.close_position(pos['ticket'])
                        continue
                
                # Vérifier break-even sur médiane
                if self.config.position_management.be_on_middle_band:
                    if pos['type'] == 'BUY' and last_row['high'] >= last_row['bb_middle']:
                        self.executor.set_break_even(
                            pos['ticket'],
                            offset_points=self.config.position_management.be_offset_points
                        )
                    elif pos['type'] == 'SELL' and last_row['low'] <= last_row['bb_middle']:
                        self.executor.set_break_even(
                            pos['ticket'],
                            offset_points=self.config.position_management.be_offset_points
                        )
                
        except Exception as e:
            self.logger.error(f"❌ Erreur manage_positions: {e}", exc_info=True)


def signal_handler(signum, frame):
    """Handler pour arrêter proprement le bot"""
    print("\n⚠️ Signal reçu, arrêt du bot...")
    sys.exit(0)


def main():
    """Point d'entrée principal"""
    
    # Parser les arguments
    parser = argparse.ArgumentParser(description='Live Trading Bot')
    
    parser.add_argument('--symbol', type=str, default='EURUSD', help='Symbol to trade')
    parser.add_argument('--timeframe', type=str, default='H1', help='Timeframe')
    parser.add_argument('--risk', type=float, default=0.1, help='Risk percent per trade')
    parser.add_argument('--login', type=int, help='MT5 login')
    parser.add_argument('--password', type=str, help='MT5 password')
    parser.add_argument('--server', type=str, help='MT5 server')
    parser.add_argument('--magic', type=int, default=20251007, help='Magic number')
    
    args = parser.parse_args()
    
    # Setup signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Créer configuration
    config = StrategyConfig()
    config.symbol.symbol = args.symbol
    config.symbol.timeframe = args.timeframe
    config.money_management.risk_percent = args.risk
    config.money_management.magic_number = args.magic
    
    # Connexion MT5
    connector = MT5Connector(
        login=args.login,
        password=args.password,
        server=args.server
    )
    
    if not connector.connect():
        print("❌ Impossible de se connecter à MT5")
        return
    
    # Créer executor et stratégie
    executor = TradeExecutor(connector)
    strategy = FreeCandleStrategy(config)
    
    # Créer et démarrer le bot
    bot = LiveTradingBot(connector, executor, strategy, config)
    
    try:
        bot.start()
    finally:
        connector.disconnect()


if __name__ == "__main__":
    main()

