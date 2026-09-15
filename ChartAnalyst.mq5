//+------------------------------------------------------------------+
//|                                             ChartAnalyst.mq5     |
//|                    Super Chart Analyst - Version 1               |
//|                         NO AUTO TRADING                           |
//+------------------------------------------------------------------+
#property copyright "Chart Analyst"
#property version   "1.00"
#property description "MT5 Chart Analyst - Structure Based"
#property description "NO AUTO TRADING"

#property indicator_chart_window
#property indicator_plots 0

//--- Input
input int    LookbackBars      = 50;
input int    SwingStrength     = 3;
input double MinimumRR         = 1.5;

//--- Analysis variables
string MarketBias = "NEUTRAL";
string Signal     = "NO TRADE";

double EntryPrice = 0.0;
double StopLoss   = 0.0;
double TakeProfit = 0.0;
double BuyScore   = 0.0;
double SellScore  = 0.0;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("SUPER CHART ANALYST started.");
   Print("AUTO TRADING: DISABLED");

   CreatePanel();

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "SCA_");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   AnalyzeMarket();
   UpdatePanel();

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Main market analysis                                             |
//+------------------------------------------------------------------+
void AnalyzeMarket()
{
   MqlRates rates[];

   ArraySetAsSeries(rates, true);

   int copied = CopyRates(_Symbol, _Period, 0, LookbackBars, rates);

   if(copied < 20)
      return;

   //--- Reset
   BuyScore  = 0;
   SellScore = 0;

   EntryPrice = 0;
   StopLoss   = 0;
   TakeProfit = 0;

   //--- Current price
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   //--- Simple structure analysis
   double recentHigh = rates[1].high;
   double recentLow  = rates[1].low;

   double previousHigh = rates[6].high;
   double previousLow  = rates[6].low;

   // Find recent high / low
   for(int i = 1; i < 10; i++)
   {
      if(rates[i].high > recentHigh)
         recentHigh = rates[i].high;

      if(rates[i].low < recentLow)
         recentLow = rates[i].low;
   }

   for(int i = 6; i < 15; i++)
   {
      if(rates[i].high > previousHigh)
         previousHigh = rates[i].high;

      if(rates[i].low < previousLow)
         previousLow = rates[i].low;
   }

   //--- Bullish structure
   if(recentHigh > previousHigh && recentLow > previousLow)
   {
      MarketBias = "BULLISH";

      BuyScore += 60;
   }
   //--- Bearish structure
   else if(recentHigh < previousHigh && recentLow < previousLow)
   {
      MarketBias = "BEARISH";

      SellScore += 60;
   }
   else
   {
      MarketBias = "RANGING";
   }

   //--- Candle momentum
   double lastOpen  = rates[1].open;
   double lastClose = rates[1].close;

   if(lastClose > lastOpen)
      BuyScore += 20;

   if(lastClose < lastOpen)
      SellScore += 20;

   //--- Previous candle confirmation
   double prevOpen  = rates[2].open;
   double prevClose = rates[2].close;

   if(lastClose > lastOpen && prevClose > prevOpen)
      BuyScore += 20;

   if(lastClose < lastOpen && prevClose < prevOpen)
      SellScore += 20;

   //--- Limit score
   if(BuyScore > 100)
      BuyScore = 100;

   if(SellScore > 100)
      SellScore = 100;

   //--- Determine signal
   if(BuyScore >= 70 && BuyScore > SellScore)
   {
      Signal = "BUY";

      EntryPrice = price;

      StopLoss = recentLow;

      double risk = EntryPrice - StopLoss;

      if(risk > 0)
         TakeProfit = EntryPrice + (risk * MinimumRR);
   }
   else if(SellScore >= 70 && SellScore > BuyScore)
   {
      Signal = "SELL";

      EntryPrice = price;

      StopLoss = recentHigh;

      double risk = StopLoss - EntryPrice;

      if(risk > 0)
         TakeProfit = EntryPrice - (risk * MinimumRR);
   }
   else
   {
      Signal = "NO TRADE";
   }
}

//+------------------------------------------------------------------+
//| Create information panel                                         |
//+------------------------------------------------------------------+
void CreatePanel()
{
   string name = "SCA_PANEL";

   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, 280);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, 300);

   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
}

//+------------------------------------------------------------------+
//| Update panel                                                     |
//+------------------------------------------------------------------+
void UpdatePanel()
{
   string name = "SCA_TEXT";

   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 25);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 35);

      ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   }

   string timeframe = EnumToString(_Period);

   string text = "";

   text += "SUPER CHART ANALYST\n";
   text += "============================\n";
   text += "Symbol      : " + _Symbol + "\n";
   text += "Timeframe   : " + timeframe + "\n";
   text += "Auto Trade  : DISABLED\n";
   text += "----------------------------\n";
   text += "Market Bias : " + MarketBias + "\n";
   text += "----------------------------\n";
   text += "BUY Score   : " + DoubleToString(BuyScore, 0) + "%\n";
   text += "SELL Score  : " + DoubleToString(SellScore, 0) + "%\n";
   text += "----------------------------\n";
   text += "SIGNAL      : " + Signal + "\n";
   text += "----------------------------\n";

   if(Signal != "NO TRADE")
   {
      text += "Entry : " + DoubleToString(EntryPrice, _Digits) + "\n";
      text += "SL    : " + DoubleToString(StopLoss, _Digits) + "\n";
      text += "TP    : " + DoubleToString(TakeProfit, _Digits) + "\n";
      text += "R:R   : 1:" + DoubleToString(MinimumRR, 1) + "\n";
   }
   else
   {
      text += "WAIT FOR VALID SETUP\n";
   }

   text += "============================";

   ObjectSetString(0, name, OBJPROP_TEXT, text);
}
//+------------------------------------------------------------------+
