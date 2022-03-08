//+------------------------------------------------------------------+
//|                                                          IRB.mq5 |
//|                                Copyright 2021, Daniel Nettesheim |
//|  https://github.com/golesny/metatrader5-ea-collection/indicator/ |
//+------------------------------------------------------------------+
#include <MovingAverages.mqh>
#property copyright "Copyright 2021, Daniel Nettesheim"
#property link      "https://github.com/golesny/metatrader5-ea-collection"
#property version   "1.03"
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   3
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
// inputs
input group "Bar"
input double retracementBuy = 45;//retracement amount buys (in %)
input double retracementSell = 45;//retracement amount sells (in %)
input group "Filter"
input int inp_filterEMAFastPeriod = 20; // Only show when match with EMA trend
input double inp_filterEMAFastSlopePercentMin = 0.07; // Slope in percent (15%=0.15) to be counted (to simulate the 45° from Rob Hoffman)
input double inp_filterEMAFastSlopePercentMax = 0.24; // Slope in percent (15%=0.15) to be counted (to simulate the 45° from Rob Hoffman)
input group "Higher Timeframe"
input ENUM_TIMEFRAMES inp_Timeframe = PERIOD_CURRENT; // Timeframe to show (must be higher than current)
input group "Alert"
input bool inp_alertOnIBR = true; // Alert on IBR on new candle
input bool inp_alertAfterTFSwitch = false; // Alert áfter timeframe switch
//--- indicator buffers
double         irbUpArrows[];
double         irbUpArrowsColor[];
double         irbDownArrows[];
double         irbDownArrowsColor[];
double         emaFast[];
double         emaFastColor[];
//
int handleEMAFast;
int timeframeFactor;
bool startAlerting;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
// timeframe init
   ENUM_TIMEFRAMES verif_TF_Enum = inp_Timeframe;
   int verified_TimeframeSecs = PeriodSeconds(inp_Timeframe);
   if(verified_TimeframeSecs < PeriodSeconds(PERIOD_CURRENT))
     {
      verified_TimeframeSecs = PeriodSeconds(PERIOD_CURRENT);
      verif_TF_Enum = PERIOD_CURRENT;
      return(INIT_PARAMETERS_INCORRECT);
     }
   timeframeFactor = (int)MathRound(verified_TimeframeSecs / PeriodSeconds(PERIOD_CURRENT));
// general init
   IndicatorSetString(INDICATOR_SHORTNAME,StringSubstr(__FILE__,0, StringLen(__FILE__)-4)+" "+StringSubstr(EnumToString(verif_TF_Enum), 7));
// clean mem
   zeroMem();
// prepare buffer
   SetIndexBuffer(0, irbUpArrows,INDICATOR_DATA);
   SetIndexBuffer(1, irbUpArrowsColor,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, irbDownArrows,INDICATOR_DATA);
   SetIndexBuffer(3, irbDownArrowsColor,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(4, emaFast, INDICATOR_DATA);
   SetIndexBuffer(5, emaFastColor, INDICATOR_COLOR_INDEX);
//---
   startAlerting = inp_alertAfterTFSwitch;
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Comment("");
   IndicatorRelease(handleEMAFast);

   zeroMem();
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

//calc(rates_total, prev_calculated, time, open, high, close, low);
   calcHiTF(rates_total, prev_calculated, timeframeFactor, time, open, high, close, low);

   if(startAlerting)
     {
      doAlert(rates_total, time, high, low);
     }
   startAlerting = true;

//--- return value of prev_calculated for next call
   return(rates_total);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void calcHiTF(const int rates_total, const int prev_calculated, const int tfFactor, const datetime& time[], const double& open[], const double& high[], const double& close[], const double& low[])
  {
   const int slopeBarCount = 3 * tfFactor;
//--
//--
   int start = (int)MathMax(prev_calculated-1,0);
   int startEMA = (int)MathMax(prev_calculated-inp_filterEMAFastPeriod*tfFactor-3*tfFactor,0); // we
//--- calculate the fast moving
   ExponentialMAOnBuffer(rates_total,prev_calculated,
                         startEMA,  // starting
                         inp_filterEMAFastPeriod*tfFactor,  // period of the exponential average
                         close,       // buffer to calculate average
                         emaFast);  // into this buffer locate value of the average

// we want to combine
   /*rates_total-1 to set the IBR marker at beginning of new candle */
   for(int i=start; i<rates_total && !IsStopped(); i++)
     {
      MqlDateTime dt;
      TimeToStruct(time[i], dt);
      if(dt.hour % tfFactor == (tfFactor - 1) && i >= tfFactor)
        {
         int openIdx = i - tfFactor + 1;
         double highVal = getMaxOfPrevBars(high, i, tfFactor);
         double lowVal = getMinOfPrevBars(low, i, tfFactor);
         // color of ema FAST
         bool slopeInRange = false;
         if(i > slopeBarCount && i >= openIdx)
           {
            double deltaPercent = MathAbs(1 - (emaFast[i-slopeBarCount] / emaFast[i])) * 100;
            slopeInRange = deltaPercent > inp_filterEMAFastSlopePercentMin && deltaPercent < inp_filterEMAFastSlopePercentMax;
            setValue(i, tfFactor, emaFastColor, slopeInRange ? 1 : 0);

            //  Long IRB --> only show if candle is above fast EMA
            if(highVal - MathMax(open[openIdx], close[i]) > (highVal-lowVal) * retracementBuy / 100.0)
              {
               setValue(i, tfFactor, irbUpArrows, highVal);
               //if(i> 93200)
               //   Print("UP ", time[i]," h=",highVal, " o=", open[openIdx], " l=", lowVal," c=", close[i], " i=", i, " openIdx=", openIdx);
               // define color of IRB: Long is colored when above ema and slopeInRange
               int col = (slopeInRange && lowVal > emaFast[i]) ? 0 : 1;
               setValue(i, tfFactor, irbUpArrowsColor, col);
              }
            else
              {
               setValue(i, tfFactor, irbUpArrows, 0);
              }
            // Short IRB --> only show if candle is below fast EMA
            if(MathMin(open[openIdx], close[i]) - lowVal > (highVal-lowVal) * retracementSell / 100.0)
              {
               setValue(i, tfFactor, irbDownArrows, lowVal);
               //if(i> 93200)
               //   Print("DN ", time[i]," h=",highVal, " o=", open[openIdx], " l=", lowVal," c=", close[i], " i=", i, " openIdx=", openIdx);
               // define color of IRB: Long is colored when above ema and slopeInRange
               int col = (slopeInRange && highVal < emaFast[i]) ? 0 : 1;
               setValue(i, tfFactor, irbDownArrowsColor, col);
              }
            else
              {
               setValue(i, tfFactor, irbDownArrows, 0);
              }
           }
         else
           {
            setValue(i, tfFactor, emaFastColor, 2);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void setValue(int startIdx, int count, double& buf[], double val)
  {
   for(int i=0; i<count; i++)
     {
      buf[startIdx-i] = val;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getMinOfPrevBars(const double& buf[], int start, int count)
  {
   double min = 99999999;
   for(int i=0; i < count; i++)
     {
      if(buf[start-i] < min)
        {
         min = buf[start-i];
        }
     }
   return min;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getMaxOfPrevBars(const double& buf[], int start, int count)
  {
   double max = 0;
   for(int i=0; i<count; i++)
     {
      if(buf[start-i] > max)
        {
         max = buf[start-i];
        }
     }
   return max;
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
         if(slopeInRange && emaFast[i] < low[i])
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
         if(slopeInRange && high[i] < emaFast[i])
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
void zeroMem()
  {
   ZeroMemory(irbUpArrows);
   ZeroMemory(irbUpArrowsColor);
   ZeroMemory(irbDownArrows);
   ZeroMemory(irbDownArrowsColor);
   ZeroMemory(emaFast);
   ZeroMemory(emaFastColor);
  }
//+------------------------------------------------------------------+
