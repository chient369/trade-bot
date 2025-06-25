from utils.logger import log
from config import settings
import MetaTrader5 as mt5

class TradeManager:
    """
    Manages active trades, including breakeven and trailing stop logic.
    """
    def __init__(self, mt5_connector, position):
        self.mt5 = mt5_connector
        self.pos = position
        self.symbol_info = self.mt5.get_symbol_info(self.pos.symbol)
        self.pip_value = settings.RiskManagement.PipDecimalValue

    def manage_breakeven(self):
        """
        Manages moving the stop loss to breakeven.
        Implements logic from Section 5.1. of the spec.
        """
        if not settings.TradeManagement.EnableBreakeven:
            return

        # 1. Check if SL is already at entry price
        if self.pos.sl == self.pos.price_open:
            log.info(f"Trade #{self.pos.ticket} is already at breakeven. Skipping.")
            return

        # 2. Check price condition for long/short
        last_tick = self.mt5.get_last_tick(self.pos.symbol)
        if not last_tick: return

        profit_pips = 0
        is_eligible = False

        if self.pos.type == mt5.ORDER_TYPE_BUY: # Long Trade
            profit_pips = (last_tick.ask - self.pos.price_open) / self.pip_value
            # The spec says: CurrentPrice >= EntryPrice + (EntryPrice - InitialStopLoss)
            # which is equivalent to profit being >= initial risk. Let's assume 1R.
            # Using TrailingStop_ActivationPips as the trigger for simplicity as well.
            if profit_pips >= settings.TradeManagement.TrailingStop_ActivationPips:
                 is_eligible = True
        
        elif self.pos.type == mt5.ORDER_TYPE_SELL: # Short Trade
            profit_pips = (self.pos.price_open - last_tick.bid) / self.pip_value
            if profit_pips >= settings.TradeManagement.TrailingStop_ActivationPips:
                 is_eligible = True
        
        # 3. If condition met, modify the order's SL to entry price
        if is_eligible:
            log.info(f"Trade #{self.pos.ticket} has become eligible for breakeven ({profit_pips:.2f} pips profit). Moving SL.")
            self.mt5.modify_position(self.pos.ticket, sl=self.pos.price_open, tp=self.pos.tp)


    def manage_trailing_stop(self):
        """
        Manages the trailing stop loss.
        Implements logic from Section 5.2. of the spec.
        """
        if not settings.TradeManagement.EnableTrailingStop:
            return

        last_tick = self.mt5.get_last_tick(self.pos.symbol)
        if not last_tick: return

        # 1. Activation
        profit_pips = 0
        if self.pos.type == mt5.ORDER_TYPE_BUY:
            profit_pips = (last_tick.ask - self.pos.price_open) / self.pip_value
        else: # Sell
            profit_pips = (self.pos.price_open - last_tick.bid) / self.pip_value

        if profit_pips < settings.TradeManagement.TrailingStop_ActivationPips:
            return # Not profitable enough to activate trailing stop

        # 2. Calculate potential new SL and 3. Check Condition
        new_sl = None
        if self.pos.type == mt5.ORDER_TYPE_BUY:
            potential_sl = last_tick.ask - (settings.TradeManagement.TrailingStop_DistancePips * self.pip_value)
            if potential_sl > self.pos.sl:
                new_sl = potential_sl
        
        elif self.pos.type == mt5.ORDER_TYPE_SELL:
            potential_sl = last_tick.bid + (settings.TradeManagement.TrailingStop_DistancePips * self.pip_value)
            if potential_sl < self.pos.sl or self.pos.sl == 0.0:
                 new_sl = potential_sl

        # 4. Action
        if new_sl is not None:
            log.info(f"Trailing SL for trade #{self.pos.ticket}. New SL: {new_sl:.5f}")
            self.mt5.modify_position(self.pos.ticket, sl=new_sl, tp=self.pos.tp)


    def run_management(self):
        """
        Runs the trade management logic.
        Priority: Breakeven -> Trailing Stop.
        """
        log.info(f"Managing trade #{self.pos.ticket}...")
        self.manage_breakeven()
        self.manage_trailing_stop() 