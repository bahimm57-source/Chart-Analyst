//+------------------------------------------------------------------+
//|                                             ChartAnalyst.mq5     |
//|                 SUPER CHART ANALYST - NO AUTO TRADE              |
//+------------------------------------------------------------------+
#property copyright "Chart Analyst"
#property version   "2.00"
#property description "Market structure analysis only"
#property description "NO AUTO TRADING"

input int LookbackBars = 50;
input double MinimumRR = 1.5;

string Bias = "NEUTRAL";
string Signal = "NO TRADE";

double BuyScore = 0;
double SellScore = 0;

double Entry = 0;
double SL = 0;
double TP = 0;

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   CreatePanel();

   Print("SUPER CHART ANALYST ACTIVE");
   Print("AUTO TRADING: DISABLED");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Main analysis                                                    |
//+------------------------------------------------------------------+
void OnTick()
{
   AnalyzeMarket();
   UpdatePanel();
}

//+------------------------------------------------------------------+
//| Market analysis                                                  |
//+------------------------------------------------------------------+
void AnalyzeMarket()
{
   MqlRates price[];

   ArraySetAsSeries(price,true);

   int bars = CopyRates(_Symbol,_Period,0,LookbackBars,price);

   if(bars < 20)
      return;

   BuyScore = 0;
   SellScore = 0;

   Entry = 0;
   SL = 0;
   TP = 0;

   double recentHigh = price[1].high;
   double recentLow  = price[1].low;

   double previousHigh = price[6].high;
   double previousLow  = price[6].low;

   // Find recent structure
   for(int i=1;i<10;i++)
   {
      if(price[i].high > recentHigh)
         recentHigh = price[i].high;

      if(price[i].low < recentLow)
         recentLow = price[i].low;
   }

   for(int i=6;i<15;i++)
   {
      if(price[i].high > previousHigh)
         previousHigh = price[i].high;

      if(price[i].low < previousLow)
         previousLow = price[i].low;
   }

   //==============================================================
   // BULLISH STRUCTURE
   //==============================================================

   if(recentHigh > previousHigh &&
      recentLow > previousLow)
   {
      Bias = "BULLISH";

      BuyScore += 60;
   }

   //==============================================================
   // BEARISH STRUCTURE
   //==============================================================

   else if(recentHigh < previousHigh &&
           recentLow < previousLow)
   {
      Bias = "BEARISH";

      SellScore += 60;
   }

   else
   {
      Bias = "RANGING";
   }

   //==============================================================
   // CANDLE MOMENTUM
   //==============================================================

   if(price[1].close > price[1].open)
      BuyScore += 20;

   if(price[1].close < price[1].open)
      SellScore += 20;

   //==============================================================
   // TWO CANDLE CONFIRMATION
   //==============================================================

   if(price[1].close > price[1].open &&
      price[2].close > price[2].open)
   {
      BuyScore += 20;
   }

   if(price[1].close < price[1].open &&
      price[2].close < price[2].open)
   {
      SellScore += 20;
   }

   if(BuyScore > 100)
      BuyScore = 100;

   if(SellScore > 100)
      SellScore = 100;

   //==============================================================
   // BUY SIGNAL
   //==============================================================

   if(BuyScore >= 70 &&
      BuyScore > SellScore)
   {
      Signal = "BUY";

      Entry = SymbolInfoDouble(_Symbol,SYMBOL_BID);

      SL = recentLow;

      double risk = Entry - SL;

      if(risk > 0)
         TP = Entry + (risk * MinimumRR);
   }

   //==============================================================
   // SELL SIGNAL
   //==============================================================

   else if(SellScore >= 70 &&
           SellScore > BuyScore)
   {
      Signal = "SELL";

      Entry = SymbolInfoDouble(_Symbol,SYMBOL_BID);

      SL = recentHigh;

      double risk = SL - Entry;

      if(risk > 0)
         TP = Entry - (risk * MinimumRR);
   }

   //==============================================================
   // NO TRADE
   //==============================================================

   else
   {
      Signal = "NO TRADE";
   }
}

//+------------------------------------------------------------------+
//| Create panel                                                     |
//+------------------------------------------------------------------+

void CreatePanel()
{
   string box = "SCA_BOX";

   ObjectCreate(0,
                box,
                OBJ_RECTANGLE_LABEL,
                0,
                0,
                0);

   ObjectSetInteger(0,
                    box,
                    OBJPROP_CORNER,
                    CORNER_LEFT_UPPER);

   ObjectSetInteger(0,
                    box,
                    OBJPROP_XDISTANCE,
                    10);

   ObjectSetInteger(0,
                    box,
                    OBJPROP_YDISTANCE,
                    20);

   ObjectSetInteger(0,
                    box,
                    OBJPROP_XSIZE,
                    300);

   ObjectSetInteger(0,
                    box,
                    OBJPROP_YSIZE,
                    320);

   ObjectSetInteger(0,
                    box,
                    OBJPROP_BGCOLOR,
                    clrBlack);
}

//+------------------------------------------------------------------+
//| Update information panel                                         |
//+------------------------------------------------------------------+

void UpdatePanel()
{
   string name = "SCA_TEXT";

   if(ObjectFind(0,name) < 0)
   {
      ObjectCreate(0,
                   name,
                   OBJ_LABEL,
                   0,
                   0,
                   0);

      ObjectSetInteger(0,
                       name,
                       OBJPROP_CORNER,
                       CORNER_LEFT_UPPER);

      ObjectSetInteger(0,
                       name,
                       OBJPROP_XDISTANCE,
                       25);

      ObjectSetInteger(0,
                       name,
                       OBJPROP_YDISTANCE,
                       35);

      ObjectSetInteger(0,
                       name,
                       OBJPROP_COLOR,
                       clrWhite);

      ObjectSetInteger(0,
                       name,
                       OBJPROP_FONTSIZE,
                       10);
   }

   string text = "";

   text += "SUPER CHART ANALYST\n";
   text += "============================\n";

   text += "Symbol    : " + _Symbol + "\n";

   text += "Timeframe : " +
           EnumToString(_Period) + "\n";

   text += "Auto Trade: DISABLED\n";

   text += "----------------------------\n";

   text += "BIAS      : " + Bias + "\n";

   text += "BUY       : " +
           DoubleToString(BuyScore,0) +
           "%\n";

   text += "SELL      : " +
           DoubleToString(SellScore,0) +
           "%\n";

   text += "----------------------------\n";

   text += "SIGNAL    : " + Signal + "\n";

   text += "----------------------------\n";

   if(Signal != "NO TRADE")
   {
      text += "ENTRY : " +
              DoubleToString(Entry,_Digits) +
              "\n";

      text += "SL    : " +
              DoubleToString(SL,_Digits) +
              "\n";

      text += "TP    : " +
              DoubleToString(TP,_Digits) +
              "\n";

      text += "R:R   : 1:" +
              DoubleToString(MinimumRR,1) +
              "\n";
   }
   else
   {
      text += "WAIT FOR VALID SETUP\n";
   }

   text += "============================";

   ObjectSetString(0,
                   name,
                   OBJPROP_TEXT,
                   text);

   ChartRedraw();
}

//+------------------------------------------------------------------+
