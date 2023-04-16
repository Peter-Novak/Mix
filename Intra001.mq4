/*
****************************************************************************************************************************************************************************************
*                                                                                                                                                                                      *
* Intra.mq4                                                                                                                                                                            *
*                                                                                                                                                                                      *
* Copyright Peter Novak ml., M.Sc.         
*
****************************************************************************************************************************************************************************************
*/
#property copyright "Peter Novak ml., M.Sc."
#property link      "http://www.marlin.si"

// Input parameters --------------------------------------------------------------------------------------------------------------------------------------------------------------------
extern int iterationNumber;
extern double positionSizeInLots;
extern double profitGoalInPoints;
extern double gapBetweenPositions;
extern double maxLossInPoints;

// Global constants --------------------------------------------------------------------------------------------------------------------------------------------------------------------
#define INITIAL_STATE 1
#define WAITING_FOR_ENTRY 2
#define TRADING 3
#define FINISHED 4
#define NONE -1
#define MAX_POSITIONS 10

// Global variables --------------------------------------------------------------------------------------------------------------------------------------------------------------------
int positions[MAX_POSITIONS];
double valueOfOpenPositions;
double minimumValueOfOpenPositions;
double iterationTotal;
int currentState;
datetime currentCandleOpenTime;

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
   iterationTotal = 0.0;
   currentState = INITIAL_STATE;
   valueOfOpenPositions = 0.0;
   minimumValueOfOpenPositions = 0.0;
   currentCandleOpenTime = iTime(NULL, PERIOD_D1, 0);
   return(0);
} // init

int start() {
   int currentStateBeforeTick = currentState;
   
   switch(currentState) {
   case INITIAL_STATE:
      currentState = StateInitialState();
      break;
   case WAITING_FOR_ENTRY:
      currentState = StateWaitingForEntry();
      break;
   case TRADING:
      currentState = Trading();
      break;
   case FINISHED:
      currentState = Finished();
      break;
   default:
      Print("Intra:[", iterationNumber, "]:", ":start:CRITICAL ERROR: State ", currentState, " is NOT a valid state, exiting.");
      currentState = FINISHED;
   }

   if(currentStateBeforeTick != currentState) {
      Print("Intra:[", iterationNumber, "]:", "Transition: ", StateName(currentStateBeforeTick), " ---> ", StateName(currentState));
   }
   if(minimumValueOfOpenPositions - 0.001 > valueOfOpenPositions) {
      minimumValueOfOpenPositions = valueOfOpenPositions;
   }
   
   if (iterationTotal < -maxLossInPoints) {
      iterationTotal = 0;
      Print("SADLY, WE HAVE LOST A BIG ONE!!!!!!!");
   }

   string statusReport = "ITERATION: " + IntegerToString(iterationNumber) + " in state " + StateName(currentState) + "\n------------------------------------------------------\n";
   statusReport = statusReport + "Value of open positions: " + DoubleToString(valueOfOpenPositions, 5) + "EUR\n";
   statusReport = statusReport + "Current total: " + DoubleToString(iterationTotal + valueOfOpenPositions, 5) + "EUR\n";
   statusReport = statusReport + "Accrued loss: " + DoubleToString(iterationTotal, 5) + "EUR\n";
   statusReport = statusReport + "Largest drawdown: " + DoubleToString(minimumValueOfOpenPositions, 5) + "\n";
   Comment(statusReport);

   return(0);
}

/**************************************************************************************************
 INITAL STATE - waiting for the new day to start and determine entry prices
**************************************************************************************************/
int StateInitialState() {
   if (isNewDay() == true) {
       return(WAITING_FOR_ENTRY);
   } else {
       return(INITIAL_STATE);
   }
}

/**************************************************************************************************
 TRADE INITIATED - waiting for the new day to start and determine entry prices
**************************************************************************************************/
int StateWaitingForEntry() {
   double dayOpenPrice = iOpen(NULL, PERIOD_D1, 0);
   double buyEntryPrice =  dayOpenPrice + gapBetweenPositions;
   double sellEntryPrice = dayOpenPrice - gapBetweenPositions;
   
   if (Bid > buyEntryPrice) {
      positions[0] = OpenPosition(OP_BUY, positionSizeInLots, dayOpenPrice, 0);
      SetBuyEntryOrders(GetOpenPrice(positions[0]), dayOpenPrice);
      return(TRADING);
   }
   if (Ask < sellEntryPrice) {
      positions[0] = OpenPosition(OP_SELL, positionSizeInLots, dayOpenPrice, 0);
      SetSellEntryOrders(GetOpenPrice(positions[0]), dayOpenPrice);
      return(TRADING);
   }
   return(WAITING_FOR_ENTRY);
}

/**************************************************************************************************
 TRADING
**************************************************************************************************/
int Trading() {   
   
   valueOfOpenPositions = PositionsValue();
   
   if (valueOfOpenPositions + iterationTotal > profitGoalInPoints) {
      CloseAllPositions();
      return(FINISHED);
   }
   if (isPositionClosed(positions[0]) == true) {
      iterationTotal = iterationTotal + valueOfOpenPositions;
      CloseAllPositions();
      valueOfOpenPositions = 0;
      return(WAITING_FOR_ENTRY);
   }
   return(TRADING);
}

/**************************************************************************************************
 FINISHED - this is the final state. 
**************************************************************************************************/
int Finished() {
   return(FINISHED);
}

int OpenPosition(int direction, double sizeInLots, double stopLossPrice, double takeProfitPrice) {
   int numberOfRetries = 10;
   double orderPrice;
   string positionLabel = "IN-" + iterationNumber;

   if (direction == OP_BUY) {
      orderPrice = Ask;
   } else {
      orderPrice = Bid;
   }
   
   if (direction == OP_BUY) {
      Print("Intra:[", iterationNumber, "]:", ": State ", StateName(currentState), ": Opening position BUY at ", DoubleToString(orderPrice, 5), " with stop loss price(", DoubleToString(stopLossPrice, 5), ").");
   } else {
      Print("Intra:[", iterationNumber, "]:", ": State ", StateName(currentState), ": Opening position SELL at ", DoubleToString(orderPrice, 5), " with stop loss price(", DoubleToString(stopLossPrice, 5), ").");
   }
    
   do {
      int positionOpenOrderResultCode = OrderSend(Symbol(), direction, sizeInLots, orderPrice, 0, stopLossPrice, takeProfitPrice, positionLabel, 0, 0, Red);
      if (positionOpenOrderResultCode == -1) {
         Print("Intra:[", iterationNumber, "]:", ":OpenOrder:WARNING: could not open order. Will try again in 30s. Retries left: ", numberOfRetries, ".");
         Sleep(30000);
         RefreshRates();
         numberOfRetries--;
      } else {
         return(positionOpenOrderResultCode);
      }
   } while(numberOfRetries > 0);
   Print ( "Intra:[", iterationNumber, "]:", ":OpenPosition:WARNING: could not open position even after ten attempts. Returning.");
   return(-1);
}

bool SetBuyEntryOrders(double basePrice, double stopLossPrice) {
   int i;
   for (i = 1; i < MAX_POSITIONS; i++) {
      positions[i] = OrderSend(Symbol(), OP_BUYSTOP, positionSizeInLots, basePrice + (i * gapBetweenPositions), 0, stopLossPrice, basePrice + (MAX_POSITIONS * gapBetweenPositions) + 2 * gapBetweenPositions);
   }
   return(true);
}

bool SetSellEntryOrders(double basePrice, double stopLossPrice) {
   int i;
   for (i = 1; i < MAX_POSITIONS; i++) {
      positions[i] = OrderSend(Symbol(), OP_SELLSTOP, positionSizeInLots, basePrice - (i * gapBetweenPositions), 0, stopLossPrice, basePrice - (MAX_POSITIONS * gapBetweenPositions) - 2 * gapBetweenPositions);
   }
   return(true);
}


double PositionsValue() {
   double value;
   int positionType;
   int i;
   
   value = 0;
   for (i = 0; i < MAX_POSITIONS; i++) {
      if (OrderSelect(positions[i], SELECT_BY_TICKET) != false) {
         positionType = OrderType();
         switch(positionType) {
            case OP_BUY:
               value = value + Ask - OrderOpenPrice();
               break;
            case OP_SELL:
               value = value + OrderOpenPrice() - Bid;
               break;
            default:
               value = value + 0;
         }
      }
   }
   return(value);
}

bool isPositionClosed(int positionId) {
   if(OrderSelect(positionId, SELECT_BY_TICKET) == false) {
      // Print("Intra:[", iterationNumber, "]:", ":isPositionClosed:WARNING: Position with id ", positionId, " could not be found.");
      return(false);
   } else {
      return(OrderCloseTime() != 0);
   }
}

string StateName(int state) {
   switch(state) {
   case INITIAL_STATE:
      return("INITIAL STATE");
   case WAITING_FOR_ENTRY:
      return("WAITING FOR ENTRY");
   case TRADING:
      return("TRADING");
   case FINISHED:
      return("FINISHED");
   default:
      Print("Intra:[", iterationNumber, "]:", ":StateName:CRITICAL ERROR: State code '", state, "' unknown, exiting.");
      return("");
   }
}

bool isNewDay() {
   if (iTime(NULL, PERIOD_D1, 0) != currentCandleOpenTime) {
      currentCandleOpenTime = iTime(NULL, PERIOD_D1, 0);
      return(true);
   } else {
      return(false);
   }
}

double GetOpenPrice(int positionId) {
   if (OrderSelect(positionId, SELECT_BY_TICKET) == false) {
      Print( "Intra:[", iterationNumber, "]:", ":GetOpenPrice:WARNING: Position with id ", positionId, " could not be found. Open price was assumed to be 0.");
      return(0);
   } else {
      return(OrderOpenPrice());
   }
}

int WelcomeMessage() {
   Print( "****************************************************************************************************************");
   Print( "Good day, this is daily version 5. I'm going to make your day... minimal drawdowns and BIIIIG profits ;)");
   Print( "****************************************************************************************************************");
   return(0);
}

bool CloseAllPositions() {
   int i;
   
   for (i = 0; i < MAX_POSITIONS; i++) {
      if (OrderSelect(positions[i], SELECT_BY_TICKET) == false) {
         Print("Intra:[", iterationNumber, "]:", ":CloseAllPositions:WARNING: Position with id ", positions[i], " could not be found. Position was not closed.");
      } else {
         Print("Closing order " + OrderTicket());
            switch(OrderType()) {
               case OP_BUY:
                  if (OrderCloseTime() == 0) { OrderClose(positions[i], OrderLots(), Bid, 0, Green); };
                  break;
               case OP_SELL:
                  if (OrderCloseTime() == 0) {OrderClose(positions[i], OrderLots(), Ask, 0, Red  ); };
                  break;
               default:
                  OrderDelete(positions[i]);
            }
      }
   }
   return(true);
}
