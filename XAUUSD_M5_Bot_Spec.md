# Technical Specification: XAUUSD M5 Trend-Following Bot

This document outlines the technical requirements for an automated trading bot based on a trend-following strategy for XAUUSD on the M5 timeframe.

## 1. Core Configuration Parameters

These parameters should be easily configurable without changing the core code.

```json
{
  "Symbol": "XAUUSD",
  "Timeframe": "M5",
  "RiskPercentage": 2.0,
  "RiskRewardRatio": 2.0,
  "MaxOpenTrades": 1,
  "EMAFast_Period": 21,
  "EMASlow_Period": 50,
  "RSI_Period": 14,
  "RSI_Overbought": 70,
  "RSI_Oversold": 30,
  "ADX_Period": 14,
  "ADX_Threshold": 25,
  "EnableADXFilter": true,
  "EnableCandlePatternFilter": true,
  "EnableRSIFilter": true,
  "EnableBreakeven": true,
  "EnableTrailingStop": true,
  "TrailingStop_ActivationPips": 30,
  "TrailingStop_DistancePips": 20
}
```

## 2. Indicator Definitions

The bot will use the following standard indicators:

1.  **EMA Fast**: Exponential Moving Average with `EMAFast_Period`.
2.  **EMA Slow**: Exponential Moving Average with `EMASlow_Period`.
3.  **RSI**: Relative Strength Index with `RSI_Period`.
4.  **ADX**: Average Directional Index with `ADX_Period`, to measure trend strength.

## 3. Bot Logic Flow (On New Candle)

The main logic is executed at the close of each new M5 candle.

1.  **Check State**: Query if there is currently an open trade for `Symbol`.
    *   **If YES**: Go to **Section 5: Trade Management Logic**.
    *   **If NO**: Go to **Section 4: Entry Logic**.

## 4. Entry Logic

The bot will scan for either a Long or Short entry signal.

### 4.1. Long Entry Conditions (MUST meet ALL)

1.  **Trend Strength Filter (ADX)**:
    *   The market must be trending, not moving sideways.
    *   `ADX(previous candle)` > `ADX_Threshold`.

2.  **Trend Confirmation**:
    *   `EMA Fast(current)` > `EMA Slow(current)`.
    *   `Close(previous candle)` > `EMA Slow(previous candle)`.

3.  **Pullback Confirmation**:
    *   The `Low` of the `previous candle` must touch or cross below the `EMA Fast`.
    *   `Low(previous candle)` <= `EMA Fast(previous candle)`.

4.  **Candle Pattern Confirmation**:
    *   The `previous candle` must be a bullish confirmation candle. Implement a function `isBullishSignal(candle)` that checks for:
        *   **Bullish Engulfing**: `Close(prev)` > `Open(prev-1)` AND `Open(prev)` < `Close(prev-1)` AND `isBullish(prev)` AND `isBearish(prev-1)`.
        *   **Bullish Pin Bar (Hammer)**: `BodySize` is small (e.g., < 30% of total candle range) AND `LowerWick` is long (e.g., > 60% of range) AND `UpperWick` is small.
    *   _Note: The `previous candle` is the signal candle that has just closed._

5.  **RSI Filter**:
    *   `RSI(previous candle)` < `RSI_Overbought`.

6.  **Execution**:
    *   If all conditions are met, execute a **BUY** order.
    *   `EntryPrice` = `Ask` price at the moment of execution.
    *   `StopLossPrice` = `Low(previous candle)` - (a small buffer in pips, e.g., 2 pips).
    *   `RiskAmount` = `AccountBalance` * (`RiskPercentage` / 100).
    *   `StopLossPips` = `EntryPrice` - `StopLossPrice`.
    *   `TakeProfitPrice` = `EntryPrice` + (`StopLossPips` * `RiskRewardRatio`).
    *   Calculate `LotSize` based on `RiskAmount` and `StopLossPips`.
    *   Place market order with calculated SL, TP, and Lot Size.

### 4.2. Short Entry Conditions (MUST meet ALL)

1.  **Trend Strength Filter (ADX)**:
    *   The market must be trending, not moving sideways.
    *   `ADX(previous candle)` > `ADX_Threshold`.

2.  **Trend Confirmation**:
    *   `EMA Fast(current)` < `EMA Slow(current)`.
    *   `Close(previous candle)` < `EMA Slow(previous candle)`.

3.  **Pullback Confirmation**:
    *   The `High` of the `previous candle` must touch or cross above the `EMA Fast`.
    *   `High(previous candle)` >= `EMA Fast(previous candle)`.

4.  **Candle Pattern Confirmation**:
    *   The `previous candle` must be a bearish confirmation candle. Implement a function `isBearishSignal(candle)` that checks for:
        *   **Bearish Engulfing**: `Open(prev)` > `Close(prev-1)` AND `Close(prev)` < `Open(prev-1)` AND `isBearish(prev)` AND `isBullish(prev-1)`.
        *   **Bearish Pin Bar (Shooting Star)**: `BodySize` is small AND `UpperWick` is long AND `LowerWick` is small.

5.  **RSI Filter**:
    *   `RSI(previous candle)` > `RSI_Oversold`.

6.  **Execution**:
    *   If all conditions are met, execute a **SELL** order.
    *   `EntryPrice` = `Bid` price at the moment of execution.
    *   `StopLossPrice` = `High(previous candle)` + (a small buffer in pips, e.g., 2 pips).
    *   `RiskAmount` = `AccountBalance` * (`RiskPercentage` / 100).
    *   `StopLossPips` = `StopLossPrice` - `EntryPrice`.
    *   `TakeProfitPrice` = `EntryPrice` - (`StopLossPips` * `RiskRewardRatio`).
    *   Calculate `LotSize` based on `RiskAmount` and `StopLossPips`.
    *   Place market order with calculated SL, TP, and Lot Size.

### 4.3. Capital Management: Position Sizing

This section defines how the trade volume (Lot Size) is calculated for every trade to maintain a consistent risk exposure. This is a critical step before placing any order.

1.  **Get Account Info**:
    *   `AccountBalance` = Current account equity.
    *   `AccountCurrency` = The currency of the account (e.g., USD).

2.  **Determine Risk Amount**:
    *   `RiskAmountInAccountCurrency` = `AccountBalance` * (`RiskPercentage` / 100).
    *   *Example: $10,000 * (2 / 100) = $200 risk.*

3.  **Determine Stop Loss Size**:
    *   For a **Long** trade: `StopLossPips` = (`EntryPrice` - `StopLossPrice`) / `PipValue`.
    *   For a **Short** trade: `StopLossPips` = (`StopLossPrice` - `EntryPrice`) / `PipValue`.
    *   *Note: `PipValue` for XAUUSD is typically 0.01.*

4.  **Calculate Value per Pip**:
    *   Determine the monetary value of 1 pip for 1 standard lot of the `Symbol`. This can be a fixed value or queried from the broker's platform.
    *   `PipValuePerLot` (for XAUUSD, 1 lot move of 1 pip (e.g., 1800.00 to 1800.01) is typically $1).

5.  **Calculate Lot Size**:
    *   `LotSize` = `RiskAmountInAccountCurrency` / (`StopLossPips` * `PipValuePerLot`).
    *   *Example: $200 / (30 pips * $1/pip) = 0.67 lots.*
    *   The final `LotSize` must be rounded to the broker's required precision (e.g., 2 decimal places).

## 5. Trade Management Logic

This logic runs on every tick or new candle if a trade is already open. The priority of operations should be: Breakeven -> Trailing Stop.

### 5.1. Breakeven Management

1.  **Prerequisite**: The `EnableBreakeven` parameter must be `true`.
2.  **Check Status**: Verify that the trade's Stop Loss is not already at the entry price.
3.  **Condition for Long Trade**:
    *   If `CurrentPrice.Ask` >= `EntryPrice` + (`EntryPrice` - `InitialStopLoss`).
4.  **Condition for Short Trade**:
    *   If `CurrentPrice.Bid` <= `EntryPrice` - (`InitialStopLoss` - `EntryPrice`).
5.  **Action**:
    *   If the condition is met, modify the existing order.
    *   Set `NewStopLoss` = `EntryPrice`. The Trailing Stop logic will take over from here if enabled.

### 5.2. Trailing Stop Management

This mechanism dynamically adjusts the Stop Loss to lock in profits as the price moves in a favorable direction. This logic only runs AFTER the trade's SL has been moved to Breakeven, or it can run independently based on pips gained. We define a simple pip-based trailing stop here.

1.  **Prerequisite**: The `EnableTrailingStop` parameter must be `true`.
2.  **Activation**: The trailing stop only becomes active after the trade is profitable by at least `TrailingStop_ActivationPips`.
3.  **Logic for Long Trade**:
    *   `PotentialNewSL` = `CurrentPrice.Ask` - (`TrailingStop_DistancePips` * `PipValue`).
    *   **Condition**: If `PotentialNewSL` > `CurrentStopLoss`.
    *   **Action**: Modify the order to set the `StopLoss` to `PotentialNewSL`.
4.  **Logic for Short Trade**:
    *   `PotentialNewSL` = `CurrentPrice.Bid` + (`TrailingStop_DistancePips` * `PipValue`).
    *   **Condition**: If `PotentialNewSL` < `CurrentStopLoss`.
    *   **Action**: Modify the order to set the `StopLoss` to `PotentialNewSL`.

*This ensures the Stop Loss only moves in the direction of the trade and never moves backward.*