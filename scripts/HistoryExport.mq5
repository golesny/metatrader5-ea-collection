//+------------------------------------------------------------------+
//|                                                HistoryExport.mq5 |
//|                                Copyright 2021, Daniel Nettesheim |
//|                                      https://www.nettesheim.name |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, Daniel Nettesheim"
#property link      "https://www.nettesheim.name"
#property version   "1.00"

#include <Generic/HashMap.mqh>
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//---
   const string SEP = ";";
   bool selected=HistorySelect(0, TimeCurrent());
   if(!selected)
      Alert("Could not select the result deals");
// get profit for all deals

   int total=HistoryDealsTotal();
   CHashMap<int,ulong> mapPosID2DealOut;
   for(int i=0; i<total; i++)
     {
      ulong ticket= HistoryDealGetTicket(i);
      ENUM_DEAL_ENTRY ticketDealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      int ticketPositionID = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
      if(ticketDealEntry == DEAL_ENTRY_OUT)
        {
         mapPosID2DealOut.Add(ticketPositionID, ticket);
        }
     }


// print all orders
   int ordersTotal = HistoryOrdersTotal();
   Print("symbol;orderTime;DoW;OrderType;Profit;Volume;Comment;EA-Magic");
   for(int i=0; i < ordersTotal; i++)
     {
      ulong orderTicket = HistoryOrderGetTicket(i);
      ENUM_ORDER_TYPE orderType = HistoryOrderGetInteger(orderTicket, ORDER_TYPE);
      int orderPositionID = HistoryOrderGetInteger(orderTicket, ORDER_POSITION_ID);
      if(orderPositionID > 0 && (orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_SELL_STOP))
        {
         string orderVol = DoubleToString(HistoryOrderGetDouble(orderTicket, ORDER_VOLUME_INITIAL),1);
         //int orderVol = MathRound(MathCeil(HistoryOrderGetDouble(orderTicket, ORDER_VOLUME_INITIAL))/5)*5;
         StringReplace( orderVol , ".",",");
         //datetime orderTimeSetup = HistoryOrderGetInteger(orderTicket, ORDER_TIME_SETUP);
         //MqlDateTime orderTimeSetupDT;
         //TimeToStruct(orderTimeSetup, orderTimeSetupDT);
         datetime orderTimeDone = HistoryOrderGetInteger(orderTicket, ORDER_TIME_DONE);
         MqlDateTime orderTimeDoneDT;
         TimeToStruct(orderTimeDone, orderTimeDoneDT);
         //int irbToOrderLength = ((int)MathRound((orderTimeDone-orderTimeSetup) / PeriodSeconds()));
         ulong dealOutId;
         mapPosID2DealOut.TryGetValue(orderPositionID, dealOutId);
         string profit = DoubleToString(HistoryDealGetDouble(dealOutId, DEAL_PROFIT), 2);
         StringReplace(profit, ".",",");
         string comment = HistoryOrderGetString(orderTicket, ORDER_COMMENT);
         string eaMagic = IntegerToString(HistoryOrderGetInteger(orderTicket, ORDER_MAGIC));
         string symbol = HistoryOrderGetString(orderTicket, ORDER_SYMBOL);
         Print( //IRB
            //orderTimeSetup,SEP,
            //orderTimeSetupDT.hour, SEP,
            //EnumToString((ENUM_DAY_OF_WEEK)orderTimeSetupDT.day_of_week),SEP,
            // Order
            eaMagic
            ,symbol,SEP
            ,orderTimeDone,SEP,
            //orderTimeDoneDT.hour,SEP,
            EnumToString((ENUM_DAY_OF_WEEK)orderTimeDoneDT.day_of_week),SEP,
            //
            StringSubstr(EnumToString(orderType),11,4),SEP
            ,profit,SEP
            ,orderVol,SEP
            ,comment,SEP
            //irbToOrderLength,";"
         );
        }
     }
  }
//+------------------------------------------------------------------+
