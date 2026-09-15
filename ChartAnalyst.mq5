//+------------------------------------------------------------------+
//|                                             ChartAnalyst.mq5     |
//|              SUPER CHART ANALYST V3 - NO AUTO TRADE             |
//+------------------------------------------------------------------+
#property copyright "Chart Analyst"
#property version   "3.00"
#property description "SMC Price Action Analysis Engine"
#property description "NO AUTO TRADING"

#include <Trade/Trade.mqh>

//====================================================================
// INPUTS
//====================================================================

input int    SwingLookback       = 40;
input int    SwingStrength       = 2;
input int    ATRPeriod           = 14;
input double DisplacementATR     = 1.20;
input double MinimumRR           = 1.50;
input double TP_RR               = 2.00;
input int    AnalysisSeconds     = 2;

//====================================================================
// ENUMS
//====================================================================

enum MarketDirection
{
   DIR_NEUTRAL = 0,
   DIR_BULLISH = 1,
   DIR_BEARISH = -1
};

//====================================================================
// STRUCTURE
//====================================================================

struct TFAnalysis
{
   string tfName;

   MarketDirection direction;

   bool bullishBOS;
   bool bearishBOS;

   bool bullishCHoCH;
   bool bearishCHoCH;

   bool bullishFVG;
   bool bearishFVG;

   bool bullishOB;
   bool bearishOB;

   bool bullishSweep;
   bool bearishSweep;

   bool bullishDisplacement;
   bool bearishDisplacement;

   bool bullishRetest;
   bool bearishRetest;

   bool bullishConfirmation;
   bool bearishConfirmation;

   double lastHigh;
   double lastLow;

   double previousHigh;
   double previousLow;

   double swingHigh;
   double swingLow;

   double atr;
};

//====================================================================
// GLOBALS
//====================================================================

TFAnalysis H4;
TFAnalysis H1;
TFAnalysis M15;
TFAnalysis M5;

double BuyScore  = 0.0;
double SellScore = 0.0;

string FinalSignal = "NO TRADE";

double EntryPrice = 0.0;
double StopLoss   = 0.0;
double TakeProfit = 0.0;

datetime LastAnalysis = 0;

//====================================================================
// INIT
//====================================================================

int OnInit()
{
   CreatePanel();

   Print("====================================");
   Print("SUPER CHART ANALYST V3");
   Print("SMC PRICE ACTION ENGINE");
   Print("AUTO TRADING: DISABLED");
   Print("====================================");

   AnalyzeAll();

   return(INIT_SUCCEEDED);
}

//====================================================================
// DEINIT
//====================================================================

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0,"SCA_");
}

//====================================================================
// TICK
//====================================================================

void OnTick()
{
   if(TimeCurrent() - LastAnalysis < AnalysisSeconds)
      return;

   LastAnalysis = TimeCurrent();

   AnalyzeAll();

   UpdatePanel();

   ChartRedraw();
}

//====================================================================
// MASTER ANALYSIS
//====================================================================

void AnalyzeAll()
{
   AnalyzeTimeframe(PERIOD_H4,H4,"H4");
   AnalyzeTimeframe(PERIOD_H1,H1,"H1");
   AnalyzeTimeframe(PERIOD_M15,M15,"M15");
   AnalyzeTimeframe(PERIOD_M5,M5,"M5");

   CalculateFinalScore();

   CalculateTradeLevels();
}

//====================================================================
// TIMEFRAME ANALYSIS
//====================================================================

void AnalyzeTimeframe(
   ENUM_TIMEFRAMES timeframe,
   TFAnalysis &a,
   string name)
{
   a.tfName = name;

   a.direction = DIR_NEUTRAL;

   a.bullishBOS = false;
   a.bearishBOS = false;

   a.bullishCHoCH = false;
   a.bearishCHoCH = false;

   a.bullishFVG = false;
   a.bearishFVG = false;

   a.bullishOB = false;
   a.bearishOB = false;

   a.bullishSweep = false;
   a.bearishSweep = false;

   a.bullishDisplacement = false;
   a.bearishDisplacement = false;

   a.bullishRetest = false;
   a.bearishRetest = false;

   a.bullishConfirmation = false;
   a.bearishConfirmation = false;

   MqlRates rates[];

   ArraySetAsSeries(rates,true);

   int copied =
      CopyRates(_Symbol,timeframe,0,SwingLookback,rates);

   if(copied < 20)
      return;

   //==============================================================
   // ATR
   //==============================================================

   a.atr = CalculateATR(rates,copied,ATRPeriod);

   //==============================================================
   // SWINGS
   //==============================================================

   FindSwings(
      rates,
      copied,
      SwingStrength,
      a.swingHigh,
      a.swingLow,
      a.previousHigh,
      a.previousLow
   );

   a.lastHigh = rates[1].high;
   a.lastLow  = rates[1].low;

   //==============================================================
   // STRUCTURE
   //==============================================================

   DetermineStructure(a);

   //==============================================================
   // BOS
   //==============================================================

   DetectBOS(
      rates,
      copied,
      a
   );

   //==============================================================
   // CHoCH
   //==============================================================

   DetectCHoCH(
      rates,
      copied,
      a
   );

   //==============================================================
   // FVG
   //==============================================================

   DetectFVG(
      rates,
      copied,
      a
   );

   //==============================================================
   // ORDER BLOCK
   //==============================================================

   DetectOrderBlock(
      rates,
      copied,
      a
   );

   //==============================================================
   // LIQUIDITY SWEEP
   //==============================================================

   DetectLiquiditySweep(
      rates,
      copied,
      a
   );

   //==============================================================
   // DISPLACEMENT
   //==============================================================

   DetectDisplacement(
      rates,
      copied,
      a
   );

   //==============================================================
   // RETEST
   //==============================================================

   DetectRetest(
      rates,
      copied,
      a
   );

   //==============================================================
   // CONFIRMATION CANDLE
   //==============================================================

   DetectConfirmation(
      rates,
      copied,
      a
   );
}

//====================================================================
// ATR
//====================================================================

double CalculateATR(
   MqlRates &rates[],
   int total,
   int period)
{
   if(total <= period + 1)
      return 0.0;

   double sum = 0.0;

   int count = 0;

   for(int i=1;i<=period;i++)
   {
      double high = rates[i].high;
      double low  = rates[i].low;
      double prev = rates[i+1].close;

      double tr1 = high-low;
      double tr2 = MathAbs(high-prev);
      double tr3 = MathAbs(low-prev);

      double tr = MathMax(
                     tr1,
                     MathMax(tr2,tr3)
                  );

      sum += tr;

      count++;
   }

   if(count==0)
      return 0.0;

   return sum/count;
}

//====================================================================
// SWING DETECTION
//====================================================================

void FindSwings(
   MqlRates &rates[],
   int total,
   int strength,
   double &highest,
   double &lowest,
   double &previousHighest,
   double &previousLowest)
{
   highest = 0;
   lowest = DBL_MAX;

   previousHighest = 0;
   previousLowest  = DBL_MAX;

   double firstHigh = 0;
   double secondHigh = 0;

   double firstLow = DBL_MAX;
   double secondLow = DBL_MAX;

   for(int i=strength+1;
       i<total-strength;
       i++)
   {
      bool isHigh = true;
      bool isLow  = true;

      for(int j=1;j<=strength;j++)
      {
         if(rates[i].high <= rates[i-j].high ||
            rates[i].high <= rates[i+j].high)
         {
            isHigh=false;
         }

         if(rates[i].low >= rates[i-j].low ||
            rates[i].low >= rates[i+j].low)
         {
            isLow=false;
         }
      }

      if(isHigh)
      {
         if(firstHigh==0)
            firstHigh=rates[i].high;
         else if(secondHigh==0)
            secondHigh=rates[i].high;
      }

      if(isLow)
      {
         if(firstLow==DBL_MAX)
            firstLow=rates[i].low;
         else if(secondLow==DBL_MAX)
            secondLow=rates[i].low;
      }
   }

   highest = firstHigh;
   previousHighest = secondHigh;

   lowest = firstLow;
   previousLowest = secondLow;
}

//====================================================================
// STRUCTURE
//====================================================================

void DetermineStructure(TFAnalysis &a)
{
   if(a.swingHigh<=0 ||
      a.previousHigh<=0 ||
      a.swingLow==DBL_MAX ||
      a.previousLow==DBL_MAX)
   {
      a.direction=DIR_NEUTRAL;
      return;
   }

   bool higherHigh =
      a.swingHigh > a.previousHigh;

   bool higherLow =
      a.swingLow > a.previousLow;

   bool lowerHigh =
      a.swingHigh < a.previousHigh;

   bool lowerLow =
      a.swingLow < a.previousLow;

   if(higherHigh && higherLow)
      a.direction=DIR_BULLISH;

   else if(lowerHigh && lowerLow)
      a.direction=DIR_BEARISH;

   else
      a.direction=DIR_NEUTRAL;
}

//====================================================================
// BOS
//====================================================================

void DetectBOS(
   MqlRates &rates[],
   int total,
   TFAnalysis &a)
{
   if(a.swingHigh<=0 ||
      a.swingLow==DBL_MAX)
      return;

   double close = rates[1].close;

   if(close > a.swingHigh)
      a.bullishBOS=true;

   if(close < a.swingLow)
      a.bearishBOS=true;
}

//====================================================================
// CHOCH
//====================================================================

void DetectCHoCH(
   MqlRates &rates[],
   int total,
   TFAnalysis &a)
{
   if(a.swingHigh<=0 ||
      a.swingLow==DBL_MAX)
      return;

   double close = rates[1].close;

   if(a.direction==DIR_BEARISH &&
      close > a.swingHigh)
   {
      a.bullishCHoCH=true;
   }

   if(a.direction==DIR_BULLISH &&
      close < a.swingLow)
   {
      a.bearishCHoCH=true;
   }
}

//====================================================================
// FVG
//====================================================================

void DetectFVG(
   MqlRates &rates[],
   int total,
   TFAnalysis &a)
{
   if(total<5)
      return;

   // Bullish FVG:
   // current low > candle two bars ago high

   if(rates[1].low > rates[3].high)
      a.bullishFVG=true;

   // Bearish FVG:
   // current high < candle two bars ago low

   if(rates[1].high < rates[3].low)
      a.bearishFVG=true;
}

//====================================================================
// ORDER BLOCK
//====================================================================

void DetectOrderBlock(
   MqlRates &rates[],
   int total,
   TFAnalysis &a)
{
   if(total<6)
      return;

   // Last bearish candle before bullish expansion

   bool bearishCandle =
      rates[2].close < rates[2].open;

   bool bullishExpansion =
      rates[1].close > rates[2].high;

   if(bearishCandle &&
      bullishExpansion)
   {
      a.bullishOB=true;
   }

   // Last bullish candle before bearish expansion

   bool bullishCandle =
      rates[2].close > rates[2].open;

   bool bearishExpansion =
      rates[1].close < rates[2].low;

   if(bullishCandle &&
      bearishExpansion)
   {
      a.bearishOB=true;
   }
}

//====================================================================
// LIQUIDITY SWEEP
//====================================================================

void DetectLiquiditySweep(
   MqlRates &rates[],
   int total,
   TFAnalysis &a)
{
   if(total<10)
      return;

   double previousHigh = rates[3].high;
   double previousLow  = rates[3].low;

   for(int i=3;i<8;i++)
   {
      if(rates[i].high > previousHigh)
         previousHigh=rates[i].high;

      if(rates[i].low < previousLow)
         previousLow=rates[i].low;
   }

   // Sell-side liquidity sweep
   // Price takes previous low then closes back above

   if(rates[1].low < previousLow &&
      rates[1].close > previousLow)
   {
      a.bullishSweep=true;
   }

   // Buy-side liquidity sweep
   // Price takes previous high then closes back below

   if(rates[1].high > previousHigh &&
      rates[1].close < previousHigh)
   {
      a.bearishSweep=true;
   }
}

//====================================================================
// DISPLACEMENT
//====================================================================

void DetectDisplacement(
   MqlRates &rates[],
   int total,
   TFAnalysis &a)
{
   if(a.atr<=0)
      return;

   double body =
      MathAbs(rates[1].close-rates[1].open);

   if(body < a.atr*DisplacementATR)
      return;

   if(rates[1].close > rates[1].open)
      a.bullishDisplacement=true;

   if(rates[1].close < rates[1].open)
      a.bearishDisplacement=true;
}

//====================================================================
// RETEST
//====================================================================

void DetectRetest(
   MqlRates &rates[],
   int total,
   TFAnalysis &a)
{
   if(total<8)
      return;

   double bodyHigh =
      MathMax(rates[2].open,rates[2].close);

   double bodyLow =
      MathMin(rates[2].open,rates[2].close);

   // Price revisits previous bullish candle area

   if(a.bullishBOS &&
      rates[1].low <= bodyHigh &&
      rates[1].close > bodyLow)
   {
      a.bullishRetest=true;
   }

   // Price revisits previous bearish candle area

   if(a.bearishBOS &&
      rates[1].high >= bodyLow &&
      rates[1].close < bodyHigh)
   {
      a.bearishRetest=true;
   }
}

//====================================================================
// CONFIRMATION CANDLE
//====================================================================

void DetectConfirmation(
   MqlRates &rates[],
   int total,
   TFAnalysis &a)
{
   if(total<5)
      return;

   double body =
      MathAbs(rates[1].close-rates[1].open);

   double range =
      rates[1].high-rates[1].low;

   if(range<=0)
      return;

   double bodyRatio =
      body/range;

   // Bullish confirmation

   if(rates[1].close > rates[1].open &&
      bodyRatio >= 0.60)
   {
      a.bullishConfirmation=true;
   }

   // Bearish confirmation

   if(rates[1].close < rates[1].open &&
      bodyRatio >= 0.60)
   {
      a.bearishConfirmation=true;
   }
}

//====================================================================
// FINAL SCORE
//====================================================================

void CalculateFinalScore()
{
   BuyScore=0;
   SellScore=0;

   //==============================================================
   // H4 BIAS
   //==============================================================

   if(H4.direction==DIR_BULLISH)
      BuyScore+=15;

   if(H4.direction==DIR_BEARISH)
      SellScore+=15;

   //==============================================================
   // H1
   //==============================================================

   if(H1.direction==DIR_BULLISH)
      BuyScore+=15;

   if(H1.direction==DIR_BEARISH)
      SellScore+=15;

   //==============================================================
   // M15
   //==============================================================

   if(M15.direction==DIR_BULLISH)
      BuyScore+=15;

   if(M15.direction==DIR_BEARISH)
      SellScore+=15;

   //==============================================================
   // M5 STRUCTURE
   //==============================================================

   if(M5.direction==DIR_BULLISH)
      BuyScore+=10;

   if(M5.direction==DIR_BEARISH)
      SellScore+=10;

   //==============================================================
   // BOS
   //==============================================================

   if(M15.bullishBOS)
      BuyScore+=8;

   if(M15.bearishBOS)
      SellScore+=8;

   if(M5.bullishBOS)
      BuyScore+=8;

   if(M5.bearishBOS)
      SellScore+=8;

   //==============================================================
   // CHOCH
   //==============================================================

   if(M15.bullishCHoCH)
      BuyScore+=5;

   if(M15.bearishCHoCH)
      SellScore+=5;

   if(M5.bullishCHoCH)
      BuyScore+=5;

   if(M5.bearishCHoCH)
      SellScore+=5;

   //==============================================================
   // FVG
   //==============================================================

   if(M15.bullishFVG)
      BuyScore+=4;

   if(M15.bearishFVG)
      SellScore+=4;

   if(M5.bullishFVG)
      BuyScore+=4;

   if(M5.bearishFVG)
      SellScore+=4;

   //==============================================================
   // ORDER BLOCK
   //==============================================================

   if(M15.bullishOB)
      BuyScore+=4;

   if(M15.bearishOB)
      SellScore+=4;

   if(M5.bullishOB)
      BuyScore+=4;

   if(M5.bearishOB)
      SellScore+=4;

   //==============================================================
   // LIQUIDITY
   //==============================================================

   if(M15.bullishSweep)
      BuyScore+=5;

   if(M15.bearishSweep)
      SellScore+=5;

   if(M5.bullishSweep)
      BuyScore+=5;

   if(M5.bearishSweep)
      SellScore+=5;

   //==============================================================
   // DISPLACEMENT
   //==============================================================

   if(M5.bullishDisplacement)
      BuyScore+=6;

   if(M5.bearishDisplacement)
      SellScore+=6;

   //==============================================================
   // RETEST
   //==============================================================

   if(M5.bullishRetest)
      BuyScore+=5;

   if(M5.bearishRetest)
      SellScore+=5;

   //==============================================================
   // CONFIRMATION
   //==============================================================

   if(M5.bullishConfirmation)
      BuyScore+=6;

   if(M5.bearishConfirmation)
      SellScore+=6;

   //==============================================================
   // CAP
   //==============================================================

   if(BuyScore>100)
      BuyScore=100;

   if(SellScore>100)
      SellScore=100;

   //==============================================================
   // FINAL SIGNAL
   //==============================================================

   FinalSignal="NO TRADE";

   if(BuyScore>=65 &&
      BuyScore>SellScore)
   {
      FinalSignal="BUY";
   }

   if(SellScore>=65 &&
      SellScore>BuyScore)
   {
      FinalSignal="SELL";
   }
}

//====================================================================
// TRADE LEVELS
//====================================================================

void CalculateTradeLevels()
{
   EntryPrice=0;
   StopLoss=0;
   TakeProfit=0;

   double bid =
      SymbolInfoDouble(_Symbol,SYMBOL_BID);

   double ask =
      SymbolInfoDouble(_Symbol,SYMBOL_ASK);

   if(FinalSignal=="BUY")
   {
      EntryPrice=ask;

      StopLoss=M5.swingLow;

      if(StopLoss<=0 ||
         StopLoss>=EntryPrice)
      {
         StopLoss=EntryPrice-(M5.atr*1.5);
      }

      double risk =
         EntryPrice-StopLoss;

      if(risk>0)
         TakeProfit=
            EntryPrice+(risk*TP_RR);
   }

   if(FinalSignal=="SELL")
   {
      EntryPrice=bid;

      StopLoss=M5.swingHigh;

      if(StopLoss<=0 ||
         StopLoss<=EntryPrice)
      {
         StopLoss=EntryPrice+(M5.atr*1.5);
      }

      double risk =
         StopLoss-EntryPrice;

      if(risk>0)
         TakeProfit=
            EntryPrice-(risk*TP_RR);
   }
}

//====================================================================
// DIRECTION TEXT
//====================================================================

string DirectionText(
   MarketDirection direction)
{
   if(direction==DIR_BULLISH)
      return "BULLISH";

   if(direction==DIR_BEARISH)
      return "BEARISH";

   return "NEUTRAL";
}

//====================================================================
// YES / NO
//====================================================================

string YesNo(bool value)
{
   if(value)
      return "YES";

   return "-";
}

//====================================================================
// PANEL
//====================================================================

void CreatePanel()
{
   string box="SCA_BOX";

   ObjectCreate(
      0,
      box,
      OBJ_RECTANGLE_LABEL,
      0,
      0,
      0
   );

   ObjectSetInteger(
      0,
      box,
      OBJPROP_CORNER,
      CORNER_LEFT_UPPER
   );

   ObjectSetInteger(
      0,
      box,
      OBJPROP_XDISTANCE,
      10
   );

   ObjectSetInteger(
      0,
      box,
      OBJPROP_YDISTANCE,
      20
   );

   ObjectSetInteger(
      0,
      box,
      OBJPROP_XSIZE,
      360
   );

   ObjectSetInteger(
      0,
      box,
      OBJPROP_YSIZE,
      560
   );

   ObjectSetInteger(
      0,
      box,
      OBJPROP_BGCOLOR,
      clrBlack
   );
}

//====================================================================
// PANEL UPDATE
//====================================================================

void UpdatePanel()
{
   string name="SCA_TEXT";

   if(ObjectFind(0,name)<0)
   {
      ObjectCreate(
         0,
         name,
         OBJ_LABEL,
         0,
         0,
         0
      );

      ObjectSetInteger(
         0,
         name,
         OBJPROP_CORNER,
         CORNER_LEFT_UPPER
      );

      ObjectSetInteger(
         0,
         name,
         OBJPROP_XDISTANCE,
         25
      );

      ObjectSetInteger(
         0,
         name,
         OBJPROP_YDISTANCE,
         35
      );

      ObjectSetInteger(
         0,
         name,
         OBJPROP_COLOR,
         clrWhite
      );

      ObjectSetInteger(
         0,
         name,
         OBJPROP_FONTSIZE,
         9
      );
   }

   string text="";

   text+="SUPER CHART ANALYST V3\n";
   text+="================================\n";

   text+="SYMBOL : "+_Symbol+"\n";
   text+="AUTO TRADE : DISABLED\n";

   text+="--------------------------------\n";
   text+="MULTI-TIMEFRAME BIAS\n";

   text+="H4  : "+
         DirectionText(H4.direction)+"\n";

   text+="H1  : "+
         DirectionText(H1.direction)+"\n";

   text+="M15 : "+
         DirectionText(M15.direction)+"\n";

   text+="M5  : "+
         DirectionText(M5.direction)+"\n";

   text+="--------------------------------\n";
   text+="SMC STRUCTURE\n";

   text+="M15 BOS B : "+
         YesNo(M15.bullishBOS)+
         "  S : "+
         YesNo(M15.bearishBOS)+"\n";

   text+="M5  BOS B : "+
         YesNo(M5.bullishBOS)+
         "  S : "+
         YesNo(M5.bearishBOS)+"\n";

   text+="M15 CHoCH B: "+
         YesNo(M15.bullishCHoCH)+
         " S: "+
         YesNo(M15.bearishCHoCH)+"\n";

   text+="M5  CHoCH B: "+
         YesNo(M5.bullishCHoCH)+
         " S: "+
         YesNo(M5.bearishCHoCH)+"\n";

   text+="--------------------------------\n";
   text+="POI / LIQUIDITY\n";

   text+="M15 FVG B: "+
         YesNo(M15.bullishFVG)+
         " S: "+
         YesNo(M15.bearishFVG)+"\n";

   text+="M5  FVG B: "+
         YesNo(M5.bullishFVG)+
         " S: "+
         YesNo(M5.bearishFVG)+"\n";

   text+="M15 OB  B: "+
         YesNo(M15.bullishOB)+
         " S: "+
         YesNo(M15.bearishOB)+"\n";

   text+="M5  OB  B: "+
         YesNo(M5.bullishOB)+
         " S: "+
         YesNo(M5.bearishOB)+"\n";

   text+="M15 Sweep B: "+
         YesNo(M15.bullishSweep)+
         " S: "+
         YesNo(M15.bearishSweep)+"\n";

   text+="M5  Sweep B: "+
         YesNo(M5.bullishSweep)+
         " S: "+
         YesNo(M5.bearishSweep)+"\n";

   text+="--------------------------------\n";
   text+="EXECUTION CONDITIONS\n";

   text+="Displacement B: "+
         YesNo(M5.bullishDisplacement)+
         " S: "+
         YesNo(M5.bearishDisplacement)+"\n";

   text+="Retest B: "+
         YesNo(M5.bullishRetest)+
         " S: "+
         YesNo(M5.bearishRetest)+"\n";

   text+="Confirm B: "+
         YesNo(M5.bullishConfirmation)+
         " S: "+
         YesNo(M5.bearishConfirmation)+"\n";

   text+="--------------------------------\n";
   text+="BUY SCORE  : "+
         DoubleToString(BuyScore,0)+
         "%\n";

   text+="SELL SCORE : "+
         DoubleToString(SellScore,0)+
         "%\n";

   text+="SIGNAL     : "+
         FinalSignal+"\n";

   text+="--------------------------------\n";

   if(FinalSignal!="NO TRADE")
   {
      text+="ENTRY : "+
         DoubleToString(EntryPrice,_Digits)+
         "\n";

      text+="SL    : "+
         DoubleToString(StopLoss,_Digits)+
         "\n";

      text+="TP    : "+
         DoubleToString(TakeProfit,_Digits)+
         "\n";

      text+="R:R   : 1:"+
         DoubleToString(TP_RR,1)+"\n";
   }
   else
   {
      text+="ENTRY : WAIT\n";
      text+="SL    : WAIT\n";
      text+="TP    : WAIT\n";
      text+="--------------------------------\n";
      text+="NO VALID SETUP\n";
   }

   text+="================================\n";
   text+="PRICE ACTION > PREDICTION";

   ObjectSetString(
      0,
      name,
      OBJPROP_TEXT,
      text
   );
}

//+------------------------------------------------------------------+
