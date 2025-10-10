"""
MT5 Connector
Connexion et interface avec MetaTrader 5
Conversion Python de la logique MT5
"""

import MetaTrader5 as mt5
import pandas as pd
import numpy as np
from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime
import time
import threading
from functools import wraps


def retry_on_failure(max_retries: int = 3, delay: float = 1.0, backoff: float = 2.0):
    """
    Décorateur pour retry avec backoff exponentiel
    
    Args:
        max_retries: Nombre maximum de tentatives
        delay: Délai initial en secondes
        backoff: Multiplicateur de délai (exponentiel)
    """
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            current_delay = delay
            last_exception = None
            
            for attempt in range(max_retries):
                try:
                    return func(*args, **kwargs)
                except Exception as e:
                    last_exception = e
                    if attempt < max_retries - 1:
                        print(f"⚠️ Tentative {attempt + 1}/{max_retries} échouée: {e}")
                        print(f"   Nouvelle tentative dans {current_delay:.1f}s...")
                        time.sleep(current_delay)
                        current_delay *= backoff
                    else:
                        print(f"❌ Échec après {max_retries} tentatives")
            
            # Si toutes les tentatives échouent, relancer la dernière exception
            if last_exception:
                raise last_exception
            return None
        
        return wrapper
    return decorator


class MT5Connector:
    """
    Connecteur MetaTrader 5
    
    Gère:
    - Connexion/déconnexion à MT5
    - Récupération de données OHLCV
    - Informations sur les symboles
    - Gestion des ordres
    - Monitoring des positions
    """
    
    def __init__(
        self,
        login: Optional[int] = None,
        password: Optional[str] = None,
        server: Optional[str] = None,
        timeout: int = 60000
    ):
        """
        Args:
            login: Numéro de compte MT5
            password: Mot de passe
            server: Serveur du broker
            timeout: Timeout de connexion en ms
        """
        self.login = login
        self.password = password
        self.server = server
        self.timeout = timeout
        self.connected = False
        self._connection_lock = threading.RLock()  # Lock pour thread-safety
        
        # Timeframe mapping complet
        self.timeframes = {
            'M1': mt5.TIMEFRAME_M1,
            'M2': mt5.TIMEFRAME_M2,
            'M3': mt5.TIMEFRAME_M3,  # M3 existe bien dans MT5!
            'M4': mt5.TIMEFRAME_M4,
            'M5': mt5.TIMEFRAME_M5,
            'M6': mt5.TIMEFRAME_M6,
            'M10': mt5.TIMEFRAME_M10,
            'M12': mt5.TIMEFRAME_M12,
            'M15': mt5.TIMEFRAME_M15,
            'M20': mt5.TIMEFRAME_M20,
            'M30': mt5.TIMEFRAME_M30,
            'H1': mt5.TIMEFRAME_H1,
            'H2': mt5.TIMEFRAME_H2,
            'H3': mt5.TIMEFRAME_H3,
            'H4': mt5.TIMEFRAME_H4,
            'H6': mt5.TIMEFRAME_H6,
            'H8': mt5.TIMEFRAME_H8,
            'H12': mt5.TIMEFRAME_H12,
            'D1': mt5.TIMEFRAME_D1,
            'W1': mt5.TIMEFRAME_W1,
            'MN1': mt5.TIMEFRAME_MN1,
        }
    
    def connect(self) -> bool:
        """
        Connexion à MetaTrader 5 (thread-safe)
        
        Returns:
            True si connexion réussie
        """
        with self._connection_lock:
            # Si déjà connecté, retourner True
            if self.connected:
                return True
            
            # Initialiser MT5
            if not mt5.initialize(timeout=self.timeout):
                error = mt5.last_error()
                print(f"❌ Erreur initialisation MT5: {error}")
                return False
            
            # Si credentials fournis, se connecter
            if self.login and self.password and self.server:
                authorized = mt5.login(
                    login=self.login,
                    password=self.password,
                    server=self.server,
                    timeout=self.timeout
                )
                
                if not authorized:
                    error = mt5.last_error()
                    print(f"❌ Erreur login MT5: {error}")
                    mt5.shutdown()
                    return False
                
                print(f"✅ Connecté à MT5 - Compte: {self.login} | Serveur: {self.server}")
            else:
                print(f"✅ MT5 initialisé (sans login)")
            
            self.connected = True
            
            # Afficher les infos du compte
            account_info = mt5.account_info()
            if account_info:
                print(f"   Balance: ${account_info.balance:.2f}")
                print(f"   Equity: ${account_info.equity:.2f}")
                print(f"   Margin Free: ${account_info.margin_free:.2f}")
            
            return True
    
    def disconnect(self):
        """Déconnexion de MT5 (thread-safe)"""
        with self._connection_lock:
            if self.connected:
                mt5.shutdown()
                self.connected = False
                print("🔌 Déconnecté de MT5")
    
    def ensure_connected(self) -> bool:
        """Vérifie la connexion, reconnecte si nécessaire"""
        if not self.connected:
            return self.connect()
        
        # Vérifier que MT5 est toujours actif
        if mt5.terminal_info() is None:
            print("⚠️ Connexion MT5 perdue, reconnexion...")
            return self.connect()
        
        return True
    
    def get_symbol_info(self, symbol: str) -> Optional[Dict[str, Any]]:
        """
        Obtient les informations du symbole
        
        Args:
            symbol: Symbole (ex: "EURUSD")
        
        Returns:
            Dict avec infos du symbole
        """
        if not self.ensure_connected():
            return None
        
        info = mt5.symbol_info(symbol)
        
        if info is None:
            print(f"⚠️ Symbole {symbol} non trouvé")
            return None
        
        return {
            'symbol': info.name,
            'description': info.description,
            'point': info.point,
            'digits': info.digits,
            'spread': info.spread,
            'spread_float': info.spread_float,
            'min_lot': info.volume_min,
            'max_lot': info.volume_max,
            'lot_step': info.volume_step,
            'tick_value': info.trade_tick_value,
            'tick_size': info.trade_tick_size,
            'contract_size': info.trade_contract_size,
            'currency_base': info.currency_base,
            'currency_profit': info.currency_profit,
            'currency_margin': info.currency_margin,
            'visible': info.visible,
            'trade_mode': info.trade_mode,
        }
    
    def get_tick(self, symbol: str) -> Optional[Dict[str, Any]]:
        """
        Obtient le dernier tick
        
        Args:
            symbol: Symbole
        
        Returns:
            Dict avec données du tick
        """
        if not self.ensure_connected():
            return None
        
        tick = mt5.symbol_info_tick(symbol)
        
        if tick is None:
            return None
        
        return {
            'time': datetime.fromtimestamp(tick.time),
            'bid': tick.bid,
            'ask': tick.ask,
            'last': tick.last,
            'volume': tick.volume,
            'spread': (tick.ask - tick.bid) / mt5.symbol_info(symbol).point
        }
    
    @retry_on_failure(max_retries=3, delay=0.5)
    def get_ohlcv(
        self,
        symbol: str,
        timeframe: str = 'H1',
        count: int = 1000,
        start_pos: int = 0
    ) -> Optional[pd.DataFrame]:
        """
        Récupère les données OHLCV avec retry automatique
        
        Args:
            symbol: Symbole
            timeframe: Timeframe (M1, M5, H1, etc.)
            count: Nombre de barres
            start_pos: Position de départ (0 = maintenant)
        
        Returns:
            DataFrame avec OHLCV
        """
        if not self.ensure_connected():
            raise ConnectionError("Impossible de se connecter à MT5")
        
        # Vérifier que le symbole est visible
        if not mt5.symbol_select(symbol, True):
            raise ValueError(f"Impossible de sélectionner le symbole {symbol}")
        
        # Convertir le timeframe
        tf = self.timeframes.get(timeframe, mt5.TIMEFRAME_H1)
        
        # Récupérer les données
        rates = mt5.copy_rates_from_pos(symbol, tf, start_pos, count)
        
        if rates is None or len(rates) == 0:
            error = mt5.last_error()
            raise RuntimeError(f"Erreur récupération données: {error}")
        
        # Convertir en DataFrame
        df = pd.DataFrame(rates)
        df['time'] = pd.to_datetime(df['time'], unit='s')
        df.set_index('time', inplace=True)
        
        # Renommer les colonnes pour cohérence
        df.columns = ['open', 'high', 'low', 'close', 'tick_volume', 'spread', 'real_volume']
        
        # Garder seulement OHLCV
        df = df[['open', 'high', 'low', 'close', 'tick_volume']].copy()
        df.rename(columns={'tick_volume': 'volume'}, inplace=True)
        
        return df
    
    def get_ohlcv_range(
        self,
        symbol: str,
        timeframe: str = 'H1',
        date_from: datetime = None,
        date_to: datetime = None
    ) -> Optional[pd.DataFrame]:
        """
        Récupère les données OHLCV sur une plage de dates
        
        Args:
            symbol: Symbole
            timeframe: Timeframe
            date_from: Date de début (datetime)
            date_to: Date de fin (datetime)
        
        Returns:
            DataFrame avec OHLCV
        """
        if not self.ensure_connected():
            return None
        
        # Vérifier que le symbole est visible
        if not mt5.symbol_select(symbol, True):
            print(f"⚠️ Impossible de sélectionner {symbol}")
            return None
        
        # Convertir le timeframe
        tf = self.timeframes.get(timeframe, mt5.TIMEFRAME_H1)
        
        # Convertir les dates pandas en datetime Python natif (sans timezone)
        if hasattr(date_from, 'to_pydatetime'):
            date_from = date_from.to_pydatetime().replace(tzinfo=None)
        if hasattr(date_to, 'to_pydatetime'):
            date_to = date_to.to_pydatetime().replace(tzinfo=None)
        
        # Récupérer les données
        rates = mt5.copy_rates_range(symbol, tf, date_from, date_to)
        
        if rates is None or len(rates) == 0:
            error = mt5.last_error()
            print(f"⚠️ Erreur récupération données: {error}")
            print(f"   Debug: symbol={symbol}, tf={timeframe} ({tf}), from={date_from}, to={date_to}")
            
            # Essayer avec des données récentes si erreur
            if error[0] == -2:
                print(f"   Essai avec données récentes (dernier mois)...")
                recent_rates = mt5.copy_rates_from_pos(symbol, tf, 0, 10000)
                if recent_rates is not None and len(recent_rates) > 0:
                    print(f"   ✅ {len(recent_rates)} barres récentes disponibles")
                    print(f"   💡 Le broker ne fournit peut-être pas les données historiques pour cette période")
                    return None
            return None
        
        # Convertir en DataFrame
        df = pd.DataFrame(rates)
        df['time'] = pd.to_datetime(df['time'], unit='s')
        df.set_index('time', inplace=True)
        
        # Renommer et garder seulement OHLCV
        df.columns = ['open', 'high', 'low', 'close', 'tick_volume', 'spread', 'real_volume']
        df = df[['open', 'high', 'low', 'close', 'tick_volume']].copy()
        df.rename(columns={'tick_volume': 'volume'}, inplace=True)
        
        return df
    
    def get_account_info(self) -> Optional[Dict[str, Any]]:
        """
        Obtient les informations du compte
        
        Returns:
            Dict avec infos du compte
        """
        if not self.ensure_connected():
            return None
        
        account = mt5.account_info()
        
        if account is None:
            return None
        
        return {
            'login': account.login,
            'trade_mode': account.trade_mode,
            'balance': account.balance,
            'equity': account.equity,
            'profit': account.profit,
            'margin': account.margin,
            'margin_free': account.margin_free,
            'margin_level': account.margin_level,
            'leverage': account.leverage,
            'currency': account.currency,
            'name': account.name,
            'server': account.server,
            'trade_allowed': account.trade_allowed,
            'trade_expert': account.trade_expert,
        }
    
    def get_open_positions(
        self,
        symbol: Optional[str] = None,
        magic: Optional[int] = None
    ) -> List[Dict[str, Any]]:
        """
        Obtient les positions ouvertes
        
        Args:
            symbol: Filtrer par symbole (optionnel)
            magic: Filtrer par magic number (optionnel)
        
        Returns:
            Liste des positions
        """
        if not self.ensure_connected():
            return []
        
        # Récupérer les positions
        if symbol:
            positions = mt5.positions_get(symbol=symbol)
        else:
            positions = mt5.positions_get()
        
        if positions is None:
            return []
        
        result = []
        for pos in positions:
            # Filtrer par magic si spécifié
            if magic is not None and pos.magic != magic:
                continue
            
            result.append({
                'ticket': pos.ticket,
                'symbol': pos.symbol,
                'type': 'BUY' if pos.type == mt5.ORDER_TYPE_BUY else 'SELL',
                'type_code': pos.type,
                'volume': pos.volume,
                'open_price': pos.price_open,
                'current_price': pos.price_current,
                'sl': pos.sl,
                'tp': pos.tp,
                'profit': pos.profit,
                'commission': pos.commission,
                'swap': pos.swap,
                'magic': pos.magic,
                'comment': pos.comment,
                'time': datetime.fromtimestamp(pos.time),
                'duration': (datetime.now() - datetime.fromtimestamp(pos.time)).total_seconds() / 3600
            })
        
        return result
    
    def get_history_deals(
        self,
        date_from: datetime,
        date_to: datetime,
        symbol: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        Obtient l'historique des deals
        
        Args:
            date_from: Date de début
            date_to: Date de fin
            symbol: Filtrer par symbole (optionnel)
        
        Returns:
            Liste des deals
        """
        if not self.ensure_connected():
            return []
        
        # Sélectionner l'historique
        if not mt5.history_deals_get(date_from, date_to):
            return []
        
        deals = mt5.history_deals_get(date_from, date_to)
        
        if deals is None:
            return []
        
        result = []
        for deal in deals:
            # Filtrer par symbole si spécifié
            if symbol and deal.symbol != symbol:
                continue
            
            result.append({
                'ticket': deal.ticket,
                'order': deal.order,
                'time': datetime.fromtimestamp(deal.time),
                'type': deal.type,
                'entry': deal.entry,
                'symbol': deal.symbol,
                'volume': deal.volume,
                'price': deal.price,
                'commission': deal.commission,
                'swap': deal.swap,
                'profit': deal.profit,
                'magic': deal.magic,
                'comment': deal.comment,
                'position_id': deal.position_id
            })
        
        return result
    
    def __enter__(self):
        """Context manager entry"""
        self.connect()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        self.disconnect()
    
    def __repr__(self) -> str:
        status = "Connected" if self.connected else "Disconnected"
        return f"MT5Connector(login={self.login}, server={self.server}, status={status})"


if __name__ == "__main__":
    # Test du connecteur MT5
    print("🔧 Test MT5Connector")
    print("=" * 60)
    
    # Connexion
    connector = MT5Connector()
    
    if connector.connect():
        # Info compte
        account = connector.get_account_info()
        if account:
            print(f"\n📊 Compte:")
            print(f"   Login: {account['login']}")
            print(f"   Balance: ${account['balance']:.2f}")
            print(f"   Equity: ${account['equity']:.2f}")
            print(f"   Leverage: 1:{account['leverage']}")
        
        # Info symbole
        print(f"\n💱 Symbole EURUSD:")
        symbol_info = connector.get_symbol_info("EURUSD")
        if symbol_info:
            print(f"   Point: {symbol_info['point']}")
            print(f"   Digits: {symbol_info['digits']}")
            print(f"   Spread: {symbol_info['spread']}")
            print(f"   Min Lot: {symbol_info['min_lot']}")
            print(f"   Max Lot: {symbol_info['max_lot']}")
        
        # Tick actuel
        print(f"\n📈 Tick actuel:")
        tick = connector.get_tick("EURUSD")
        if tick:
            print(f"   Time: {tick['time']}")
            print(f"   Bid: {tick['bid']:.5f}")
            print(f"   Ask: {tick['ask']:.5f}")
            print(f"   Spread: {tick['spread']:.1f} points")
        
        # Récupérer données OHLCV
        print(f"\n📊 Données OHLCV (dernières 10 barres H1):")
        df = connector.get_ohlcv("EURUSD", "H1", count=10)
        if df is not None:
            print(df.tail())
        
        # Positions ouvertes
        print(f"\n💼 Positions ouvertes:")
        positions = connector.get_open_positions()
        if positions:
            for pos in positions:
                print(f"   #{pos['ticket']} {pos['symbol']} {pos['type']} {pos['volume']} lots - "
                      f"Profit: ${pos['profit']:.2f}")
        else:
            print("   Aucune position ouverte")
        
        # Déconnexion
        connector.disconnect()
    else:
        print("❌ Impossible de se connecter à MT5")
    
    print("\n" + "=" * 60)
    print("✅ Test terminé")

