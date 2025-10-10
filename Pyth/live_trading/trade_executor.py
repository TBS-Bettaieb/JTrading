"""
Trade Executor
Exécution des trades sur MetaTrader 5
"""

import MetaTrader5 as mt5
from typing import Optional, Dict, Any
from datetime import datetime
import time

from .mt5_connector import MT5Connector


class TradeExecutor:
    """
    Exécuteur de trades
    
    Gère:
    - Ouverture de positions
    - Fermeture de positions
    - Modification SL/TP
    - Validation des ordres
    """
    
    def __init__(
        self,
        connector: MT5Connector,
        max_slippage: int = 10,
        max_retries: int = 3,
        retry_delay: float = 1.0
    ):
        """
        Args:
            connector: Connecteur MT5
            max_slippage: Slippage maximum autorisé en points
            max_retries: Nombre maximum de tentatives
            retry_delay: Délai entre les tentatives (secondes)
        """
        self.connector = connector
        self.max_slippage = max_slippage
        self.max_retries = max_retries
        self.retry_delay = retry_delay
    
    def open_position(
        self,
        symbol: str,
        direction: str,  # 'BUY' ou 'SELL'
        volume: float,
        sl: Optional[float] = None,
        tp: Optional[float] = None,
        magic: int = 0,
        comment: str = "",
        deviation: Optional[int] = None
    ) -> Optional[int]:
        """
        Ouvre une position
        
        Args:
            symbol: Symbole
            direction: 'BUY' ou 'SELL'
            volume: Volume en lots
            sl: Stop Loss (optionnel)
            tp: Take Profit (optionnel)
            magic: Magic number
            comment: Commentaire
            deviation: Déviation max en points (si None, utilise max_slippage)
        
        Returns:
            Ticket de la position ou None si échec
        """
        if not self.connector.ensure_connected():
            print("❌ Pas de connexion MT5")
            return None
        
        # Vérifier que le symbole est visible
        symbol_info = mt5.symbol_info(symbol)
        if symbol_info is None:
            print(f"❌ Symbole {symbol} non trouvé")
            return None
        
        if not symbol_info.visible:
            if not mt5.symbol_select(symbol, True):
                print(f"❌ Impossible de sélectionner {symbol}")
                return None
        
        # Déterminer le type d'ordre
        if direction.upper() == 'BUY':
            order_type = mt5.ORDER_TYPE_BUY
            price = mt5.symbol_info_tick(symbol).ask
        elif direction.upper() == 'SELL':
            order_type = mt5.ORDER_TYPE_SELL
            price = mt5.symbol_info_tick(symbol).bid
        else:
            print(f"❌ Direction invalide: {direction}")
            return None
        
        # Utiliser max_slippage si deviation non spécifié
        if deviation is None:
            deviation = self.max_slippage
        
        # Préparer la requête
        request = {
            "action": mt5.TRADE_ACTION_DEAL,
            "symbol": symbol,
            "volume": volume,
            "type": order_type,
            "price": price,
            "deviation": deviation,
            "magic": magic,
            "comment": comment,
            "type_time": mt5.ORDER_TIME_GTC,
            "type_filling": mt5.ORDER_FILLING_IOC,
        }
        
        # Ajouter SL/TP si spécifiés
        if sl is not None:
            request["sl"] = sl
        if tp is not None:
            request["tp"] = tp
        
        # Tenter l'exécution avec retries
        for attempt in range(self.max_retries):
            result = mt5.order_send(request)
            
            if result is None:
                print(f"⚠️ Tentative {attempt + 1}/{self.max_retries} - Pas de résultat")
                time.sleep(self.retry_delay)
                continue
            
            if result.retcode == mt5.TRADE_RETCODE_DONE:
                print(f"✅ Position ouverte - Ticket: {result.order}")
                print(f"   {direction} {volume} lots de {symbol} @ {result.price}")
                if sl:
                    print(f"   SL: {sl}")
                if tp:
                    print(f"   TP: {tp}")
                return result.order
            
            elif result.retcode == mt5.TRADE_RETCODE_REQUOTE:
                print(f"⚠️ Tentative {attempt + 1}/{self.max_retries} - Requote, nouvelle tentative...")
                # Mettre à jour le prix
                if direction.upper() == 'BUY':
                    request["price"] = mt5.symbol_info_tick(symbol).ask
                else:
                    request["price"] = mt5.symbol_info_tick(symbol).bid
                time.sleep(self.retry_delay)
                continue
            
            else:
                print(f"❌ Erreur ouverture position: {result.retcode} - {result.comment}")
                return None
        
        print(f"❌ Échec après {self.max_retries} tentatives")
        return None
    
    def close_position(
        self,
        ticket: int,
        deviation: Optional[int] = None
    ) -> bool:
        """
        Ferme une position
        
        Args:
            ticket: Ticket de la position
            deviation: Déviation max en points
        
        Returns:
            True si succès
        """
        if not self.connector.ensure_connected():
            print("❌ Pas de connexion MT5")
            return False
        
        # Vérifier que la position existe
        position = mt5.positions_get(ticket=ticket)
        
        if not position:
            print(f"❌ Position {ticket} non trouvée")
            return False
        
        position = position[0]
        
        # Déterminer le type d'ordre opposé
        if position.type == mt5.ORDER_TYPE_BUY:
            order_type = mt5.ORDER_TYPE_SELL
            price = mt5.symbol_info_tick(position.symbol).bid
        else:
            order_type = mt5.ORDER_TYPE_BUY
            price = mt5.symbol_info_tick(position.symbol).ask
        
        # Utiliser max_slippage si deviation non spécifié
        if deviation is None:
            deviation = self.max_slippage
        
        # Préparer la requête de fermeture
        request = {
            "action": mt5.TRADE_ACTION_DEAL,
            "symbol": position.symbol,
            "volume": position.volume,
            "type": order_type,
            "position": ticket,
            "price": price,
            "deviation": deviation,
            "magic": position.magic,
            "comment": "Close by Python",
            "type_time": mt5.ORDER_TIME_GTC,
            "type_filling": mt5.ORDER_FILLING_IOC,
        }
        
        # Tenter la fermeture avec retries
        for attempt in range(self.max_retries):
            result = mt5.order_send(request)
            
            if result is None:
                print(f"⚠️ Tentative {attempt + 1}/{self.max_retries} - Pas de résultat")
                time.sleep(self.retry_delay)
                continue
            
            if result.retcode == mt5.TRADE_RETCODE_DONE:
                print(f"✅ Position {ticket} fermée")
                print(f"   Prix de fermeture: {result.price}")
                return True
            
            elif result.retcode == mt5.TRADE_RETCODE_REQUOTE:
                print(f"⚠️ Tentative {attempt + 1}/{self.max_retries} - Requote, nouvelle tentative...")
                # Mettre à jour le prix
                if order_type == mt5.ORDER_TYPE_BUY:
                    request["price"] = mt5.symbol_info_tick(position.symbol).ask
                else:
                    request["price"] = mt5.symbol_info_tick(position.symbol).bid
                time.sleep(self.retry_delay)
                continue
            
            else:
                print(f"❌ Erreur fermeture position: {result.retcode} - {result.comment}")
                return False
        
        print(f"❌ Échec fermeture après {self.max_retries} tentatives")
        return False
    
    def modify_position(
        self,
        ticket: int,
        sl: Optional[float] = None,
        tp: Optional[float] = None
    ) -> bool:
        """
        Modifie le SL/TP d'une position
        
        Args:
            ticket: Ticket de la position
            sl: Nouveau Stop Loss (None = ne pas modifier)
            tp: Nouveau Take Profit (None = ne pas modifier)
        
        Returns:
            True si succès
        """
        if not self.connector.ensure_connected():
            print("❌ Pas de connexion MT5")
            return False
        
        # Vérifier que la position existe
        position = mt5.positions_get(ticket=ticket)
        
        if not position:
            print(f"❌ Position {ticket} non trouvée")
            return False
        
        position = position[0]
        
        # Utiliser les valeurs actuelles si non spécifiées
        new_sl = sl if sl is not None else position.sl
        new_tp = tp if tp is not None else position.tp
        
        # Préparer la requête
        request = {
            "action": mt5.TRADE_ACTION_SLTP,
            "symbol": position.symbol,
            "position": ticket,
            "sl": new_sl,
            "tp": new_tp,
        }
        
        # Envoyer la requête
        result = mt5.order_send(request)
        
        if result is None:
            print(f"❌ Erreur modification position")
            return False
        
        if result.retcode == mt5.TRADE_RETCODE_DONE:
            print(f"✅ Position {ticket} modifiée")
            if sl is not None:
                print(f"   Nouveau SL: {new_sl}")
            if tp is not None:
                print(f"   Nouveau TP: {new_tp}")
            return True
        else:
            print(f"❌ Erreur modification: {result.retcode} - {result.comment}")
            return False
    
    def close_all_positions(
        self,
        symbol: Optional[str] = None,
        magic: Optional[int] = None
    ) -> int:
        """
        Ferme toutes les positions
        
        Args:
            symbol: Filtrer par symbole (optionnel)
            magic: Filtrer par magic number (optionnel)
        
        Returns:
            Nombre de positions fermées
        """
        positions = self.connector.get_open_positions(symbol=symbol, magic=magic)
        
        closed_count = 0
        for pos in positions:
            if self.close_position(pos['ticket']):
                closed_count += 1
        
        print(f"✅ {closed_count}/{len(positions)} positions fermées")
        return closed_count
    
    def set_break_even(
        self,
        ticket: int,
        offset_points: float = 0
    ) -> bool:
        """
        Met le SL au break-even
        
        Args:
            ticket: Ticket de la position
            offset_points: Offset en points au-delà du BE
        
        Returns:
            True si succès
        """
        if not self.connector.ensure_connected():
            return False
        
        # Récupérer la position
        position = mt5.positions_get(ticket=ticket)
        
        if not position:
            print(f"❌ Position {ticket} non trouvée")
            return False
        
        position = position[0]
        
        # Calculer le nouveau SL au BE
        symbol_info = mt5.symbol_info(position.symbol)
        offset = offset_points * symbol_info.point
        
        if position.type == mt5.ORDER_TYPE_BUY:
            new_sl = position.price_open + offset
            # Vérifier que le nouveau SL est meilleur que l'actuel
            if position.sl >= new_sl:
                print(f"⚠️ SL déjà au BE ou mieux")
                return False
        else:
            new_sl = position.price_open - offset
            # Vérifier que le nouveau SL est meilleur que l'actuel
            if position.sl > 0 and position.sl <= new_sl:
                print(f"⚠️ SL déjà au BE ou mieux")
                return False
        
        return self.modify_position(ticket, sl=new_sl)
    
    def trailing_stop(
        self,
        ticket: int,
        trailing_points: float
    ) -> bool:
        """
        Applique un trailing stop
        
        Args:
            ticket: Ticket de la position
            trailing_points: Distance du trailing en points
        
        Returns:
            True si SL modifié
        """
        if not self.connector.ensure_connected():
            return False
        
        # Récupérer la position
        position = mt5.positions_get(ticket=ticket)
        
        if not position:
            return False
        
        position = position[0]
        
        # Récupérer le prix actuel
        tick = mt5.symbol_info_tick(position.symbol)
        symbol_info = mt5.symbol_info(position.symbol)
        
        # Calculer le nouveau SL
        trailing_distance = trailing_points * symbol_info.point
        
        if position.type == mt5.ORDER_TYPE_BUY:
            new_sl = tick.bid - trailing_distance
            # Ne jamais baisser le SL
            if new_sl <= position.sl:
                return False
        else:
            new_sl = tick.ask + trailing_distance
            # Ne jamais monter le SL pour un SELL
            if position.sl > 0 and new_sl >= position.sl:
                return False
        
        return self.modify_position(ticket, sl=new_sl)
    
    def __repr__(self) -> str:
        return f"TradeExecutor(max_slippage={self.max_slippage}, max_retries={self.max_retries})"


if __name__ == "__main__":
    # Test du trade executor
    print("🔧 Test TradeExecutor")
    print("=" * 60)
    
    # Créer connecteur et executor
    connector = MT5Connector()
    executor = TradeExecutor(connector, max_slippage=10)
    
    if connector.connect():
        print("\n⚠️ MODE TEST - Pas d'exécution réelle")
        print("Pour exécuter un trade, décommentez le code ci-dessous\n")
        
        # Exemple d'utilisation (commenté par sécurité)
        """
        # Ouvrir une position BUY
        ticket = executor.open_position(
            symbol="EURUSD",
            direction="BUY",
            volume=0.01,
            sl=1.09500,
            tp=1.11000,
            magic=123456,
            comment="Test Python"
        )
        
        if ticket:
            print(f"\n✅ Position ouverte: {ticket}")
            
            # Attendre 5 secondes
            time.sleep(5)
            
            # Modifier le SL
            print("\n📝 Modification du SL...")
            executor.modify_position(ticket, sl=1.09700)
            
            # Attendre 5 secondes
            time.sleep(5)
            
            # Fermer la position
            print("\n❌ Fermeture de la position...")
            executor.close_position(ticket)
        """
        
        print("✅ Connexion OK - Executor prêt")
        print(f"   {executor}")
        
        connector.disconnect()
    else:
        print("❌ Impossible de se connecter à MT5")
    
    print("\n" + "=" * 60)
    print("✅ Test terminé")

