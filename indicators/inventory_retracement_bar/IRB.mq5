//+------------------------------------------------------------------+
//|                                                          IRB.mq5 |
//|                                Copyright 2021, Daniel Nettesheim |
//|  https://github.com/golesny/metatrader5-ea-collection/indicator/ |
//+------------------------------------------------------------------+
#include <MovingAverages.mqh>
#property copyright "Copyright 2021, Daniel Nettesheim"
#property link      "https://github.com/golesny/metatrader5-ea-collection"
#property version   "1.02"
#property indicator_chart_window
#property indicator_buffers 10
#property indicator_plots   5
//--- plot irbUp
#property indicator_label1  "irbUp"
#property indicator_type1   DRAW_COLOR_ARROW
#property indicator_color1  clrLimeGreen, clrDimGray
#property indicator_style1  STYLE_SOLID
#property indicator_width1  4
//--- plot irbDown
#property indicator_label2  "irbDown"
#property indicator_type2   DRAW_COLOR_ARROW
#property indicator_color2  clrRed, clrDimGray
#property indicator_style2  STYLE_SOLID
#property indicator_width2  4
//--- plot EMA
#property indicator_label3  "emaFast"
#property indicator_type3   DRAW_COLOR_LINE
#property indicator_color3  clrGold, clrDeepSkyBlue, clrDimGray
#property indicator_style3  STYLE_DOT
#property indicator_width3  1
//-- higher timeframe
//--- plot irbUp Higher Timeframe
#property indicator_label4  "irbUpHiTF"
#property indicator_type4   DRAW_COLOR_ARROW
#property indicator_color4  clrGreen, clrDimGray
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1
//--- plot irbDown Higher Timeframe
#property indicator_label5  "irbDownHiTF"
#property indicator_type5   DRAW_COLOR_ARROW
#property indicator_color5  clrMagenta, clrDimGray
#property indicator_style5  STYLE_SOLID
#property indicator_width5  1
// inputs
input group "Bar"
input double retracementBuy = 45;//retracement amount buys (in %)
input double retracementSell = 45;//retracement amount sells (in %)
input group "Filter"
input int inp_filterEMAFastPeriod = 20; // Only show when match with EMA trend
input double inp_filterEMAFastSlopePercentMin = 0.07; // Slope in percent (15%=0.15) to be counted (to simulate the 45° from Rob Hoffman)
input double inp_filterEMAFastSlopePercentMax = 0.24; // Slope in percent (15%=0.15) to be counted (to simulate the 45° from Rob Hoffman)
input group "Higher Timeframe"
input bool inp_showH4onH1 = true; // On H1 the H4 is shown
input group "Alert"
input bool inp_alertOnIBR = true; // Alert on IBR on new candle
//--- indicator buffers
double         irbUpArrows[];
double         irbUpArrowsColor[];
double         irbDownArrows[];
double         irbDownArrowsColor[];
double         emaFast[];
double         emaFastColor[];
double         irbUpArrowsHiTF[];
double         irbUpArrowsColorHiTF[];
double         irbDownArrowsHiTF[];
double         irbDownArrowsColorHiTF[];
//
int handleEMAFast;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   IndicatorSetString(INDICATOR_SHORTNAME,"IRB-DEV");

   SetIndexBuffer(0, irbUpArrows,INDICATOR_DATA);
   ZeroMemory(irbUpArrows);
   SetIndexBuffer(1, irbUpArrowsColor,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, irbDownArrows,INDICATOR_DATA);
   ZeroMemory(irbDownArrows);
   SetIndexBuffer(3, irbDownArrowsColor,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(4, emaFast, INDICATOR_DATA);
   SetIndexBuffer(5, emaFastColor, INDICATOR_COLOR_INDEX);

   SetIndexBuffer(6, irbUpArrowsHiTF,INDICATOR_DATA);
   ZeroMemory(irbUpArrowsHiTF);
   SetIndexBuffer(7, irbUpArrowsColorHiTF,INDICATOR_COLOR_INDEX);

   SetIndexBuffer(8, irbDownArrowsHiTF,INDICATOR_DATA);
   ZeroMemory(irbDownArrowsHiTF);
   SetIndexBuffer(9, irbDownArrowsColorHiTF,INDICATOR_COLOR_INDEX);
  // SetIndexBuffer(10, emaFastHiTF, INDICATOR_DATA);
  // SetIndexBuffer(11, emaFastColorHiTF, INDICATOR_COLOR_INDEX);
//---
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Comment("");
   IndicatorRelease(handleEMAFast);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
//-- exit while waiting for next bar to save performance
   if(prev_calculated == rates_total)
      return(prev_calculated);
//---- checking for the sufficiency of bars for the calculation
   if(Bars(_Symbol,_Period) < rates_total)
      return(prev_calculated);

   calc(rates_total, prev_calculated, time, open, high, close, low);
   calcHiTF(rates_total, prev_calculated, time, open, high, close, low);

   doAlert(rates_total, time, high, low);

//--- return value of prev_calculated for next call
   return(rates_total);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void calcHiTF(const int rates_total, const int prev_calculated, const datetime& time[], const double& open[], const double& high[], const double& close[], const double& low[])
  {
   const int tfFactor = 4;
   if(!inp_showH4onH1)
      return;
   if(_Period != PERIOD_H1)
      return;
//--
//--
   int start = (int)MathMax(prev_calculated-1,0);
   //int startEMA = (int)MathMax(prev_calculated-inp_filterEMAFastPeriod*tfFactor-3*tfFactor,0); // we need previous 3 values to caculate slope
//--- calculate the fast moving
   /*ExponentialMAOnBuffer(rates_total,prev_calculated,
                         startEMA,  // starting
                         inp_filterEMAFastPeriod*tfFactor,  // period of the exponential average
                         close,       // buffer to calculate average
                         emaFastHiTF);  // into this buffer locate value of the average
                         */
// we want to combine
   /*rates_total-1 to set the IBR marker at beginning of new candle */
   for(int i=start; i<rates_total && !IsStopped(); i++)
     {
      MqlDateTime dt;
      TimeToStruct(time[i], dt);
      if(dt.hour % tfFactor == (tfFactor - 1) && i >= tfFactor)
        {
         double highHiTF = MathMax(MathMax(high[i], high[i-1]), MathMax(high[i-2], high[i-3]));
         double lowHiTF = MathMin(MathMin(low[i], low[i-1]), MathMin(low[i-2], low[i-3]));
         // color of ema FAST
         bool slopeInRange = false;
         /*if(i > 3*tfFactor)
           {
            double deltaPercent = MathAbs(1 - (emaFast[i-3*tfFactor] / emaFast[i])) * 100;
            slopeInRange = deltaPercent > inp_filterEMAFastSlopePercentMin && deltaPercent < inp_filterEMAFastSlopePercentMax;
            emaFastColorHiTF[i] = slopeInRange ? 1 : 0;
           }
         else
           {
            emaFastColorHiTF[i] = 2;
           }*/
         //  Long IRB --> only show if candle is above fast EMA
         if(highHiTF - MathMax(open[i-3], close[i]) > (highHiTF-lowHiTF) * retracementBuy / 100.0)
           {
            setValue(i, tfFactor, irbUpArrowsHiTF, highHiTF);
           }
         // Short IRB --> only show if candle is below fast EMA
         if(MathMin(open[i-3], close[i]) - lowHiTF > (highHiTF-lowHiTF) * retracementSell / 100.0)
           {
            setValue(i, tfFactor, irbDownArrowsHiTF, lowHiTF);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void setValue(int startIdx, int count, double& buf[], double val)
  {
   for(int i=startIdx-count+1; i<=startIdx; i++)
     {
      buf[i] = val;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void calc(const int rates_total, const int prev_calculated, const datetime& time[], const double& open[], const double& high[], const double& close[], const double& low[])
  {
//--
   int start = (int)MathMax(prev_calculated-1,0);
   int startEMA = (int)MathMax(prev_calculated-inp_filterEMAFastPeriod-3,0); // we need previous 3 values to caculate slope
//--- calculate the fast moving
   ExponentialMAOnBuffer(rates_total,prev_calculated,
                         startEMA,  // starting
                         inp_filterEMAFastPeriod,  // period of the exponential average
                         close,       // buffer to calculate average
                         emaFast);  // into this buffer locate value of the average
   /*rates_total-1 to set the IBR marker at beginning of new candle */
   for(int i=start; i<rates_total && !IsStopped(); i++)
     {
      irbUpArrows[i] = 0;
      irbDownArrows[i]= 0;
      // color of ema FAST
      bool slopeInRange = false;
      if(i > 3)
        {
         double deltaPercent = MathAbs(1 - (emaFast[i-3] / emaFast[i])) * 100;
         slopeInRange = deltaPercent > inp_filterEMAFastSlopePercentMin && deltaPercent < inp_filterEMAFastSlopePercentMax;
         emaFastColor[i] = slopeInRange ? 1 : 0;
        }
      else
        {
         emaFastColor[i] = 2;
        }
      //  Long IRB --> only show if candle is above fast EMA
      if(high[i] - MathMax(open[i], close[i]) > (high[i]-low[i]) * retracementBuy / 100.0)
        {
         irbUpArrows[i] = high[i];
         if(emaFast[i] < low[i] && slopeInRange)
           {
            irbUpArrowsColor[i] =  0;
            //Print("High IbR ", time[i], " i=", i);
           }
         else
           {
            irbUpArrowsColor[i] =  1;
           }
        }
      // Short IRB --> only show if candle is below fast EMA
      if(MathMin(open[i], close[i]) - low[i] > (high[i]-low[i]) * retracementSell / 100.0)
        {
         irbDownArrows[i] = low[i];
         if(high[i] < emaFast[i] && slopeInRange)
           {
            irbDownArrowsColor[i] = 0;
            //Print("Low IBR ", time[i], " i=", i);
           }
         else
           {
            irbDownArrowsColor[i] = 1;
           }
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void doAlert(int rates_total, const datetime& time[], const double& high[], const double& low[])
  {
   static datetime prevtime=0;
//-- only alert with new candle
   if(prevtime != time[rates_total-2] && !IsStopped())
     {
      if(inp_alertOnIBR)
        {
         if(irbUpArrows[rates_total-2] > 0 && irbUpArrowsColor[rates_total-2] == 0)
           {
            Alert("Bar ",time[rates_total-2], " ", Symbol(), " has valid IBR long/up on ",EnumToString(Period()), " High: ", high[rates_total-2]);
           }
         if(irbDownArrows[rates_total-2] > 0 && irbDownArrowsColor[rates_total-2] == 0)
           {
            Alert("Bar ", time[rates_total-2], " ", Symbol(), " has valid IBR short/down on ",EnumToString(Period()), " Low: ", low[rates_total-2]);
           }
        }
      prevtime = time[0];
     }
  }
//+------------------------------------------------------------------+
