/*
****************************************************************************************************************************************************************************************
*                                                                                                                                                                                      *
* Mix.mq4                                                                                                                                                                            *
*                                                                                                                                                                                      *
* Copyright Peter Novak ml., M.Sc.         
*
****************************************************************************************************************************************************************************************
*/
#property copyright "Peter Novak ml., M.Sc."
#property link      "http://www.marlin.si"

// Input parameters --------------------------------------------------------------------------------------------------------------------------------------------------------------------
extern int iterationNumber;
extern double buySellMaxLossInPercent;
extern double reverseMaxLossInPercent;

// Global constants --------------------------------------------------------------------------------------------------------------------------------------------------------------------
#define BS_INITIAL_STATE 1
#define BS_TRADING_BOTH_SIDES 2
#define BS_TRADING_BUY_EXTRA 3
#define BS_TRADING_SELL_EXTRA 4
#define BS_TRADING_REMAINING_BUY 5
#define BS_TRADING_REMAINInG_SELL 6
#define BS_FINISHED 7
#define BS_FINISHED_WITH_LOSS 16
#define RE_INITIAL_STATE 8
#define RE_WAITING_FOR_ENTRY 9
#define RE_TRADING_75PERCENT_SELL 10
#define RE_TRADING_87PERCENT_SELL 11
#define RE_TRADING_100PERCENT_SELL 12
#define RE_TRADING_75PERCENT_BUY 13
#define RE_TRADING_87PERCENT_BUY 14
#define RE_TRADING_100PERCENT_BUY 15
#define RE_FINISHED 17
#define RE_FINISHED_WITH_LOSS 18
#define NONE -1

// Global variables --------------------------------------------------------------------------------------------------------------------------------------------------------------------
// Buy/Sell positions
int buyPositionId;
int buyExtraPositionId;
int sellPositionId;
int sellExtraPositionId;
// Buy/Sell prices
double buyExtraPositionPrice;
double sellExtraPositionPrice;
double buyPositionPrice;
double sellPositionPrice;

// Reverse positions
int sell75PercentPositionId;
int sell87PercentPositionId;
int sell100PercentPositionId;
int buy75PercentPositionId;
int buy87PercentPositionId;
int buy100PercentPositionId;
// Reverse prices
double sell75PercentPositionPrice;
double sell87PercentPositionPrice;
double sell100PercentPositionPrice;
double sellExitPrice;
double buy75PercentPositionPrice;
double buy87PercentPositionPrice;
double buy100PercentPositionPrice;
double buyExitPrice;
double reverseProfitGoal;

int buySellState;
int reverseState;

// Common
double atr50;
double dailyOpenPrice;
double reversePositionLotSize;
double buySellPositionLotSize;

// New day
datetime currentCandleOpenTime;
bool buySellIsNewDay;
bool reverseIsNewDay;

/*
****************************************************************************************************************************************************************************************
*                                                                                                                                                                                      *
* MAIN PROGRAM and default functions: init, deinit, start                                                                                                                              *
*                                                                                                                                                                                      *
****************************************************************************************************************************************************************************************
*/

int deinit() {
   return(0);
}

int init() {
   WelcomeMessage();
   
   buySellState = BS_INITIAL_STATE;
   reverseState = RE_INITIAL_STATE;
   
   buySellIsNewDay = false;
   reverseIsNewDay = false;
   currentCandleOpenTime = iTime(NULL, PERIOD_D1, 0);
   // currentCandleOpenTime = 0;

   buyPositionId = NONE;
   buyExtraPositionId = NONE;
   sellPositionId = NONE;
   sellExtraPositionId = NONE;

   sell75PercentPositionId = NONE;
   sell87PercentPositionId = NONE;
   sell100PercentPositionId = NONE;
   buy75PercentPositionId = NONE;
   buy87PercentPositionId = NONE;
   buy100PercentPositionId = NONE;
   
   return(0);
} // init

int start() {
   int currentBuySellStateBeforeTick = buySellState;
   int currentReverseStateBeforeTick = reverseState;
   
   switch(buySellState) {
      case BS_INITIAL_STATE:
         buySellState = BsInitialState();
         break;
      case BS_TRADING_BOTH_SIDES:
         buySellState = BsTradingBothSides();
         break;
      case BS_TRADING_BUY_EXTRA:
         buySellState = BsTradingBuyExtra();
         break;
      case BS_TRADING_SELL_EXTRA:
         buySellState = BsTradingSellExtra();
         break;
      case BS_TRADING_REMAINING_BUY:
         buySellState = BsTradingRemainingBuy();
         break;
      case BS_TRADING_REMAINInG_SELL:
         buySellState = BsTradingRemainingSell();
         break;
      case BS_FINISHED:
         buySellState = BsFinished();
         break;
      case BS_FINISHED_WITH_LOSS:
         buySellState = BsFinishedWithLoss();
         break;
      default:
         Print("Mix:[", iterationNumber, "]:", ":start:CRITICAL ERROR: Buy / Sell State ", buySellState, " is NOT a valid state, exiting.");
         buySellState = BS_FINISHED;
   }
   
   switch(reverseState) {
      case RE_INITIAL_STATE:
         reverseState = ReInitialState();
         break;
      case RE_WAITING_FOR_ENTRY:
         reverseState = ReWaitingForEntry();
         break;
      case RE_TRADING_75PERCENT_SELL:
         reverseState = ReTrading75PercentSell();
         break;
      case RE_TRADING_87PERCENT_SELL:
         reverseState = ReTrading87PercentSell();
         break;
      case RE_TRADING_100PERCENT_SELL:
         reverseState = ReTrading100PercentSell();
         break;
      case RE_TRADING_75PERCENT_BUY:
         reverseState = ReTrading75PercentBuy();
         break;
      case RE_TRADING_87PERCENT_BUY:
         reverseState = ReTrading87PercentBuy();
         break;
      case RE_TRADING_100PERCENT_BUY:
         reverseState = ReTrading100PercentBuy();
         break;
      case RE_FINISHED:
         reverseState = ReFinished();
         break;
      case RE_FINISHED_WITH_LOSS:
         reverseState = ReFinishedWithLoss();
         break;
      default: 
         Print("Mix:[", iterationNumber, "]:", ":start:CRITICAL ERROR: Reverse State ", reverseState, " is NOT a valid state, exiting.");
         reverseState = RE_FINISHED;
   }

   if (currentBuySellStateBeforeTick != buySellState) {
      Print("Mix:[", iterationNumber, "]:", "Buy / Sell Transition: ", BsStateName(currentBuySellStateBeforeTick), " ---> ", BsStateName(buySellState));
   }
   if (currentReverseStateBeforeTick != reverseState) {
      Print("Mix:[", iterationNumber, "]:", "Reverse Transition: ", ReStateName(currentReverseStateBeforeTick), " ---> ", ReStateName(reverseState));
   }

   string statusReport = "ITERATION: " + IntegerToString(iterationNumber) + " in state " + BsStateName(buySellState) + " | " + ReStateName(reverseState) + "\n------------------------------------------------------\n";
   Comment(statusReport);

   return(0);
}

double BuySellPositionSize() {
   return(0.8);
}

double ReversePositionSize() {
   return(1.5);
}

/**************************************************************************************************
 INITAL BUY / SELL STATE - waiting for the new day to start and determine entry prices
**************************************************************************************************/
int BsInitialState() {
   
   isNewDay();
   if (buySellIsNewDay == true) {
      
      atr50 = iATR(Symbol(), PERIOD_D1,50, 0);
      dailyOpenPrice = Open[0];
      
      buySellPositionLotSize = BuySellPositionSize();
      if (Ask - Bid < 0.00030) {
         buyPositionId = OpenPosition(OP_BUY, buySellPositionLotSize, 0, 0, "BSBuy");
         buyPositionPrice = GetOpenPrice(buyPositionId);
         sellPositionId = OpenPosition(OP_SELL, buySellPositionLotSize, 0, 0, "BSSell");
         sellPositionPrice = GetOpenPrice(sellPositionId);
         buySellIsNewDay = false;
      
         if (buyPositionId == NONE || sellPositionId == NONE) {
            if (buyPositionId == NONE) {ClosePosition(buyPositionId);};
            if (sellPositionId == NONE) {ClosePosition(sellPositionId);};
            Print("Mix:[", iterationNumber, "]:", "BsInitialState: FATAL ERROR: could not open one or both initial buy / sell positions. Terminated.");
            return(BS_FINISHED);
         } else {
            return(BS_TRADING_BOTH_SIDES);
         }
      } else {
         return(BS_INITIAL_STATE);
      }
   } else {
       return(BS_INITIAL_STATE);
   }
}

double GetOpenPrice(int positionId) {
   if (OrderSelect(positionId, SELECT_BY_TICKET) == false) {
      Print( "Mix001:[", iterationNumber, "]:", ":GetOpenPrice:WARNING: Position with id ", positionId, " could not be found. Open price was assumed to be 0.");
      return(0);
   } else {
      return(OrderOpenPrice());
   }
}

/**************************************************************************************************
 TRADING BOTH SIDES - waiting for one of the buy / sell positions to hit the take profit goal
**************************************************************************************************/
int BsTradingBothSides() {

   double profitGoal = atr50 * 0.1; 
   
   if (Bid >= buyPositionPrice + profitGoal) {
      ClosePosition(buyPositionId);
      buyExtraPositionId = OpenPosition(OP_SELL, buySellPositionLotSize, 0, 0, "BSBuyEx");
      buyExtraPositionPrice = GetOpenPrice(buyExtraPositionId);
      return(BS_TRADING_BUY_EXTRA);
   } else {
      if (Ask <= sellPositionPrice - profitGoal) {
         ClosePosition(sellPositionId);
         sellExtraPositionId = OpenPosition(OP_BUY, buySellPositionLotSize, 0, 0, "BSSellEx");
         sellExtraPositionPrice = GetOpenPrice(sellExtraPositionId);
         return(BS_TRADING_SELL_EXTRA);
      } else {
         return(BS_TRADING_BOTH_SIDES);
      }
   }
}

bool SetStopLossPrice(double price, int positionId) {
   if (OrderSelect(positionId, SELECT_BY_TICKET) == false) {
      Print( "Mix:[", iterationNumber, "]:", ":SetStopLossPrice:WARNING: Position with id ", positionId, " could not be found. Stop loss price was not set.");
      return(false);
   } else {
      Print("Nastavljam SL pozicije " + positionId + " na " + DoubleToStr(price, 5));
      if (OrderStopLoss() == price) {
        return(true);
      } else {
         OrderModify(positionId, OrderOpenPrice(), price, OrderTakeProfit(), 0);
         return(true);
      }
   }
}

/**************************************************************************************************
 TRADING BUY EXTRA - waiting for price to return to daily open price
**************************************************************************************************/
int BsTradingBuyExtra() {
   double stopLoss;
   double profitGoal = atr50 * 0.1; 
   
   if (Ask <= buyExtraPositionPrice - profitGoal) {
      ClosePosition(buyExtraPositionId);
      return(BS_TRADING_REMAINInG_SELL);
   } else {
      isNewDay();
      if (buySellIsNewDay == true) {
         stopLoss = iHigh(Symbol(), PERIOD_D1, 1);
         SetStopLossPrice(stopLoss, buyExtraPositionId);
         SetStopLossPrice(stopLoss, sellPositionId);
         Print( "Mix:[", iterationNumber, "]:", ":BsTradingBuyExtra:INFO: Profit goals not achieved within one day, setting stop loss of remaining positions to ", DoubleToString(stopLoss, 5), ".");
         return(BS_TRADING_BUY_EXTRA);
      } else {
         return(BS_TRADING_BUY_EXTRA);
      }
   }
}

/**************************************************************************************************
 TRADING SELL EXTRA - waiting for price to return to daily open price
**************************************************************************************************/
int BsTradingSellExtra() {
   double stopLoss;
   double profitGoal = atr50 * 0.1;
   
   if (Bid >= sellExtraPositionPrice + profitGoal) {
      ClosePosition(sellExtraPositionId);
      return(BS_TRADING_REMAINING_BUY);
   } else {
      isNewDay();
      if (buySellIsNewDay == true) {
         stopLoss = iLow(Symbol(), PERIOD_D1, 1);
         SetStopLossPrice(stopLoss, sellExtraPositionId);
         SetStopLossPrice(stopLoss, buyPositionId);
         Print( "Mix:[", iterationNumber, "]:", ":BsTradingSellExtra:INFO: Profit goals not achieved within one day, setting stop loss of remaining positions to ", DoubleToString(stopLoss, 5), ".");
         return(BS_TRADING_SELL_EXTRA);
      } else {
         return(BS_TRADING_SELL_EXTRA);
      }
   }
}

/**************************************************************************************************
 TRADING REMAINING BUY - waiting for price to reach the last profit goal
**************************************************************************************************/
int BsTradingRemainingBuy() {
   double stopLoss;
   double profitGoal = atr50 * 0.1;
   
   if (Bid >= buyPositionPrice + profitGoal) {
      ClosePosition(buyPositionId);
      return(BS_FINISHED);
   } else {
      if (isPositionClosed(buyPositionId) == true) {
         return(BS_FINISHED_WITH_LOSS);
      } else {
         isNewDay();
         if (buySellIsNewDay == true) {
            stopLoss = iLow(Symbol(), PERIOD_D1, 1);
            SetStopLossPrice(stopLoss, buyPositionId);
            Print( "Mix:[", iterationNumber, "]:", ":BsTradingRemainingBuy:INFO: Profit goals not achieved within one day, setting stop loss of remaining buy position to ", DoubleToString(stopLoss, 5), ".");
         }
         return(BS_TRADING_REMAINING_BUY);
      } 
   }
}

/**************************************************************************************************
 TRADING REMAINING SELL - waiting for price to reach the last profit goal
**************************************************************************************************/
int BsTradingRemainingSell() {
   double stopLoss;
   double profitGoal = atr50 * 0.1;
   
   if (Ask <= sellPositionPrice - profitGoal) {
      ClosePosition(sellPositionId);
      return(BS_FINISHED);
   } else {
      if (isPositionClosed(sellPositionId) == true) {
         return(BS_FINISHED_WITH_LOSS);
      } else {
         isNewDay();
         if (buySellIsNewDay == true) {
            stopLoss = iHigh(Symbol(), PERIOD_D1, 1);
            SetStopLossPrice(stopLoss, sellPositionId);
            Print( "Mix:[", iterationNumber, "]:", ":BsTradingRemainingBuy:INFO: Profit goals not achieved within one day, setting stop loss of remaining sell position to ", DoubleToString(stopLoss, 5), ".");
         }
         return(BS_TRADING_REMAINInG_SELL);
      } 
   }
}

/**************************************************************************************************
 FINISHED - finished with profit
**************************************************************************************************/
int BsFinished() {
   return(BS_FINISHED);
}

/**************************************************************************************************
 FINISHED - finished with profit
**************************************************************************************************/
int BsFinishedWithLoss() {
   return(BS_FINISHED_WITH_LOSS);
}


int OpenPosition(int direction, double sizeInLots, double stopLossPrice, double takeProfitPrice, string label) {
   int numberOfRetries = 10;
   double orderPrice;
   string positionLabel = "MIX-" + label + "-" + iterationNumber;

   if (direction == OP_BUY) {
      orderPrice = Ask;
   } else {
      orderPrice = Bid;
   }
   
   if (direction == OP_BUY) {
      Print("Mix:[", iterationNumber, "]: Opening position BUY at ", DoubleToString(orderPrice, 5), " with stop loss price(", DoubleToString(stopLossPrice, 5), ").");
   } else {
      Print("Mix:[", iterationNumber, "]: Opening position SELL at ", DoubleToString(orderPrice, 5), " with stop loss price(", DoubleToString(stopLossPrice, 5), ").");
   }
    
   do {
      int positionOpenOrderResultCode = OrderSend(Symbol(), direction, sizeInLots, orderPrice, 0, stopLossPrice, takeProfitPrice, positionLabel, 0, 0, Red);
      if (positionOpenOrderResultCode == -1) {
         Print("Mix:[", iterationNumber, "]:", ":OpenOrder:WARNING: could not open order. Will try again in 30s. Retries left: ", numberOfRetries, ".");
         Sleep(30000);
         RefreshRates();
         numberOfRetries--;
      } else {
         return(positionOpenOrderResultCode);
      }
   } while(numberOfRetries > 0);
   Print ( "Mix:[", iterationNumber, "]:", ":OpenPosition:WARNING: could not open position even after ten attempts. Returning.");
   return(NONE);
}

/*

bool SetBuyEntryOrders(double basePrice, double stopLossPrice) {
   string positionLabel = "IN-" + iterationNumber;
   int i;
   for (i = 1; i < MAX_POSITIONS; i++) {
      positions[i] = OrderSend(Symbol(), OP_BUYSTOP, positionSizeInLots, basePrice + (i * gapBetweenPositions), 0, stopLossPrice, basePrice + (MAX_POSITIONS * gapBetweenPositions) + 2 * gapBetweenPositions, positionLabel);
   }
   return(true);
}

bool SetSellEntryOrders(double basePrice, double stopLossPrice) {
   string positionLabel = "IN-" + iterationNumber;
   int i;
   for (i = 1; i < MAX_POSITIONS; i++) {
      positions[i] = OrderSend(Symbol(), OP_SELLSTOP, positionSizeInLots, basePrice - (i * gapBetweenPositions), 0, stopLossPrice, basePrice - (MAX_POSITIONS * gapBetweenPositions) - 2 * gapBetweenPositions, positionLabel);
   }
   return(true);
}

*/


double PositionValue(int positionId) {
   double value;
   int positionType;
   
   if (OrderSelect(positionId, SELECT_BY_TICKET) != false) {
      positionType = OrderType();
      switch(positionType) {
         case OP_BUY:
            value = Ask - OrderOpenPrice();
            break;
         case OP_SELL:
            value = OrderOpenPrice() - Bid;
            break;
         default:
            value = 0;
      }
   }
   return(value);
}

bool isPositionClosed(int positionId) {
   if(OrderSelect(positionId, SELECT_BY_TICKET) == false) {
      return(false);
   } else {
      return(OrderCloseTime() != 0);
   }
}

string BsStateName(int state) {

   switch(buySellState) {
   case BS_INITIAL_STATE:
      return("BUY / SELL INITIAL STATE");
      break;
   case BS_TRADING_BOTH_SIDES:
      return("BUY / SELL TRADING BOTH SIDES");
      break;
   case BS_TRADING_BUY_EXTRA:
      return("BUY / SELL TRADING BUY EXTRA");
      break;
   case BS_TRADING_SELL_EXTRA:
      return("BUY / SELL TRADING SELL EXTRA");
      break;
   case BS_TRADING_REMAINING_BUY:
      return("BUY / SELL TRADING REMAINING BUY");
      break;
   case BS_TRADING_REMAINInG_SELL:
      return("BUY / SELL TRADING REMAINING SELL");
      break;
   case BS_FINISHED:
      return("BUY / SELL FINISHED");
      break;
   case BS_FINISHED_WITH_LOSS:
      return("BUY / SELL FINISHED WITH LOSS");
      break;
   default:
      Print("Mix:[", iterationNumber, "]:", ":StateName:ERROR: Buy / Sell State ", buySellState, " is NOT a valid state.");
      return("");
   }
}

string ReStateName(int state) {
   switch(reverseState) {
   case RE_INITIAL_STATE:
      return("REVERSE INITIAL STATE");
      break;
   case RE_WAITING_FOR_ENTRY:
      return("REVERSE WAITING FOR ENTRY");
      break;
   case RE_TRADING_75PERCENT_SELL:
      return("REVERSE TRADING 75 PERCENT SELL");
      break;
   case RE_TRADING_87PERCENT_SELL:
      return("REVERSE TRADING 87.5 PERCENT SELL");
      break;
   case RE_TRADING_100PERCENT_SELL:
      return("REVERSE TRADING 100 PERCENT SELL");
      break;
   case RE_TRADING_75PERCENT_BUY:
      return("REVERSE TRADING 75 PERCENT BUY");
      break;
   case RE_TRADING_87PERCENT_BUY:
      return("REVERSE TRADING 87.5 PERCENT BUY");
      break;
   case RE_TRADING_100PERCENT_BUY:
      return("REVERSE TRADING 100 PERCENT BUY");
      break;
   case RE_FINISHED:
      return("REVERSE FINISHED");
      break;
   case RE_FINISHED_WITH_LOSS:
      return("REVERSE FINISHED WITH LOSS");
      break;
   default: 
      Print("Mix:[", iterationNumber, "]:", ":StateName:ERROR: Reverse State ", reverseState, " is NOT a valid state.");
      return("");
   }
}

bool isNewDay() {
   if (iTime(NULL, PERIOD_D1, 0) != currentCandleOpenTime) {
      currentCandleOpenTime = iTime(NULL, PERIOD_D1, 0);
      buySellIsNewDay = true;
      reverseIsNewDay = true;
      return(true);
   } else {
      return(false);
   }
}

int WelcomeMessage() {
   Print( "****************************************************************************************************************");
   Print( "Good day, this is Mix version 1. Enjoy your day, while I'm making you rich.");
   Print( "****************************************************************************************************************");
   return(0);
}

bool ClosePosition(int positionId) {
   if (OrderSelect(positionId, SELECT_BY_TICKET) == false) {
      Print("Mix:[", iterationNumber, "]:", ":CloseAllPositions:WARNING: Position with id ", positionId, " could not be found. Position was not closed.");
   } else {
      Print("Closing order " + OrderTicket());
         switch(OrderType()) {
            case OP_BUY:
               if (OrderCloseTime() == 0) {OrderClose(positionId, OrderLots(), Bid, 0, Green); };
               break;
            case OP_SELL:
               if (OrderCloseTime() == 0) {OrderClose(positionId, OrderLots(), Ask, 0, Red  ); };
               break;
            default:
               OrderDelete(positionId);
         }
   }
   return(true);
}

int ReInitialState() {
   isNewDay();
   if (reverseIsNewDay == true) {
      atr50 = iATR(Symbol(), PERIOD_D1,50, 0);
      dailyOpenPrice = Open[0];
      
      reversePositionLotSize = ReversePositionSize();
      
      sell75PercentPositionPrice  = dailyOpenPrice + 0.75  * atr50;
      sell87PercentPositionPrice  = dailyOpenPrice + 0.875 * atr50;
      sell100PercentPositionPrice = dailyOpenPrice + atr50;
      sellExitPrice = dailyOpenPrice + 1.2 * atr50;
      
      buy75PercentPositionPrice = dailyOpenPrice - 0.75 * atr50;
      buy87PercentPositionPrice = dailyOpenPrice - 0.875 * atr50;
      buy100PercentPositionPrice = dailyOpenPrice - atr50;
      buyExitPrice = dailyOpenPrice - 1.2 * atr50;
      reverseProfitGoal = 0.125 * atr50;
      reverseIsNewDay = false;
      return(RE_WAITING_FOR_ENTRY);
   } else {
       return(RE_INITIAL_STATE);
   }
}

int ReWaitingForEntry() {
   isNewDay();
   if (reverseIsNewDay == true) {
      return(RE_FINISHED);
   } else {
      if (Bid > sell75PercentPositionPrice || Ask < buy75PercentPositionPrice) {
         if (Ask - Bid < 0.00030) {
            if (Bid > sell75PercentPositionPrice) {
               sell75PercentPositionId = OpenPosition(OP_SELL, reversePositionLotSize, 0, 0, "RE-S-75");
               if (sell75PercentPositionId == NONE) {
                  Print("Mix:[", iterationNumber, "]:", "ReWaitingForEntry: WARNING: could not open 75% sell position. Will retry on next tick.");
                  return(RE_WAITING_FOR_ENTRY); 
               } else {
                  return(RE_TRADING_75PERCENT_SELL);
               }
            } else {
               buy75PercentPositionId = OpenPosition(OP_BUY, reversePositionLotSize, 0, 0, "RE-B-75");
               if (buy75PercentPositionId == NONE) {
                  Print("Mix:[", iterationNumber, "]:", "ReWaitingForEntry: WARNING: could not open 75% buy position. Will retry on next tick.");
                  return(RE_WAITING_FOR_ENTRY); 
               } else {
                  return(RE_TRADING_75PERCENT_BUY);
               }
            }
         } else {
            return(RE_WAITING_FOR_ENTRY);
         }
      } else {
         return(RE_WAITING_FOR_ENTRY);  
      }
   }
};

int ReTrading75PercentSell() {
   if (Bid > sell87PercentPositionPrice) {
      sell87PercentPositionId = OpenPosition(OP_SELL, reversePositionLotSize, 0, 0, "RE-S-87");
      if (sell87PercentPositionId == NONE) {
         Print("Mix:[", iterationNumber, "]:", "ReTrading75PercentSell: WARNING: could not open 87.5% sell position. Will retry on next tick.");
         return(RE_TRADING_75PERCENT_SELL); 
      } else {
         return(RE_TRADING_87PERCENT_SELL);
      }
   } else {
      if (PositionValue(sell75PercentPositionId) > reverseProfitGoal) {
         ClosePosition(sell75PercentPositionId);
         return(RE_FINISHED);
      } else {
         return(RE_TRADING_75PERCENT_SELL);
      }
   }
}

int ReTrading87PercentSell() {
   if (Bid > sell100PercentPositionPrice) {
      sell100PercentPositionId = OpenPosition(OP_SELL, reversePositionLotSize, 0, 0, "RE-S-100");
      if (sell100PercentPositionId == NONE) {
         Print("Mix:[", iterationNumber, "]:", "ReTrading87PercentSell: WARNING: could not open 100% sell position. Will retry on next tick.");
         return(RE_TRADING_87PERCENT_SELL); 
      } else {
         return(RE_TRADING_100PERCENT_SELL);
      }
   } else {
      if (PositionValue(sell75PercentPositionId) + PositionValue(sell87PercentPositionId) > reverseProfitGoal) {
         ClosePosition(sell75PercentPositionId);
         ClosePosition(sell87PercentPositionId);
         return(RE_FINISHED);
      } else {
         return(RE_TRADING_87PERCENT_SELL);
      }
   }
}

int ReTrading100PercentSell() {
   if (Bid > sellExitPrice) {
      ClosePosition(sell75PercentPositionId);
      ClosePosition(sell87PercentPositionId);
      ClosePosition(sell100PercentPositionId);
      return(RE_FINISHED_WITH_LOSS);
   } else {
      if (PositionValue(sell75PercentPositionId) + PositionValue(sell87PercentPositionId) + PositionValue(sell100PercentPositionId) > reverseProfitGoal) {
         ClosePosition(sell75PercentPositionId);
         ClosePosition(sell87PercentPositionId);
         ClosePosition(sell100PercentPositionId);
         return(RE_FINISHED);
      } else {
         return(RE_TRADING_100PERCENT_SELL);
      }
   }
}

int ReTrading75PercentBuy() {
   if (Ask < buy87PercentPositionPrice) {
      buy87PercentPositionId = OpenPosition(OP_BUY, reversePositionLotSize, 0, 0, "RE-B-87");
      if (buy87PercentPositionId == NONE) {
         Print("Mix:[", iterationNumber, "]:", "ReTrading75PercentBuy: WARNING: could not open 87.5% buy position. Will retry on next tick.");
         return(RE_TRADING_75PERCENT_BUY); 
      } else {
         return(RE_TRADING_87PERCENT_BUY);
      }
   } else {
      if (PositionValue(buy75PercentPositionId) > reverseProfitGoal) {
         ClosePosition(buy75PercentPositionId);
         return(RE_FINISHED);
      } else {
         return(RE_TRADING_75PERCENT_BUY);
      }
   }
}

int ReTrading87PercentBuy() {
   if (Ask < buy100PercentPositionPrice) {
      buy100PercentPositionId = OpenPosition(OP_BUY, reversePositionLotSize, 0, 0, "RE-B-100");
      if (buy100PercentPositionId == NONE) {
         Print("Mix:[", iterationNumber, "]:", "ReTrading87PercentBuy: WARNING: could not open 100% buy position. Will retry on next tick.");
         return(RE_TRADING_87PERCENT_BUY); 
      } else {
         return(RE_TRADING_100PERCENT_BUY);
      }
   } else {
      if (PositionValue(buy75PercentPositionId) + PositionValue(buy87PercentPositionId) > reverseProfitGoal) {
         ClosePosition(buy75PercentPositionId);
         ClosePosition(buy87PercentPositionId);
         return(RE_FINISHED);
      } else {
         return(RE_TRADING_87PERCENT_BUY);
      }
   }
}

int ReTrading100PercentBuy() {
   if (Ask < buyExitPrice) {
      ClosePosition(buy75PercentPositionId);
      ClosePosition(buy87PercentPositionId);
      ClosePosition(buy100PercentPositionId);
      return(RE_FINISHED_WITH_LOSS);
   } else {
      if (PositionValue(buy75PercentPositionId) + PositionValue(buy87PercentPositionId) + PositionValue(buy100PercentPositionId) > reverseProfitGoal) {
         ClosePosition(buy75PercentPositionId);
         ClosePosition(buy87PercentPositionId);
         ClosePosition(buy100PercentPositionId);
         return(RE_FINISHED);
      } else {
         return(RE_TRADING_100PERCENT_BUY);
      }
   }
}

int ReFinished() {
   return(RE_FINISHED);
}
      
int ReFinishedWithLoss() {
   return(RE_FINISHED_WITH_LOSS);
}
