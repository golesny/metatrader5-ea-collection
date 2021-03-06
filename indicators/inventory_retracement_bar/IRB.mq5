//+------------------------------------------------------------------+
//|                                                          IRB.mq5 |
//|                                Copyright 2021, Daniel Nettesheim |
//|  https://github.com/golesny/metatrader5-ea-collection/indicator/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, Daniel Nettesheim"
#property link      "https://github.com/golesny/metatrader5-ea-collection"
#property version   "1.3"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   2
//--- plot irbUp
#property indicator_label1  "irbUp"
#property indicator_type1   DRAW_COLOR_ARROW
#property indicator_color1  clrLimeGreen, clrDarkGreen, clrDimGray
#property indicator_style1  STYLE_SOLID
#property indicator_width1  4
//--- plot irbDown
#property indicator_label2  "irbDown"
#property indicator_type2   DRAW_COLOR_ARROW
#property indicator_color2  clrRed, C'96,0,0' , clrDimGray
#property indicator_style2  STYLE_SOLID
#property indicator_width2  4

const int COLOR_FULL_ACTIVE = 0;
const int COLOR_PARTLY_ACTIVE = 1;
const int COLOR_INACTIVE = 2;

enum ENUM_IRB_CALC_METHOD
  {
   IRB_CALC_STANDARD_BARS, // Standard, on H1 for H4 e.g. 0-3, 4-7, etc.
   IRB_CALC_FlOATING_BARS, // Floating (Experimental), last bars, e.g. on H1 chart set to H4 on bar 6 the bars 3-6 are used for H4
  };

// inputs
input group "Bar";
input double retracementBuy = 45;//retracement amount buys (in %)
input double retracementSell = 45;//retracement amount sells (in %)
input group "Filter: Bar size";
input bool inp_BarSize_ActivateSettings = true; // Activate the bar size settings
input int inp_ATR_period = 60; // ATR settings
input double inp_BarSize_MaxSizeATRFactor = 2.5; // max high-low size according ATR (1=1xATR)
input double inp_BarSize_MinSizeATRFactor = 0.6; // max high-low size according ATR (1=1xATR)
input group "Filter: WAE volume filter"
input bool inp_Volume_ActivateSettings = true; // Activate the WAE volume filter
input string inp_WAE_path = "imd/waddah_attar_explosion"; // path to Waddah Attar Explosion indicator (https://www.mql5.com/en/code/531)
input double inp_Volume_PercentageOverExplosionLine = 0.9; // Percentage how much volume must be above explosion line (1=exactly on line)
input group "Higher Timeframe"
input ENUM_TIMEFRAMES inp_Timeframe = PERIOD_CURRENT; // Timeframe to show (must be higher than current)
input ENUM_IRB_CALC_METHOD inp_ibr_calc_method = IRB_CALC_STANDARD_BARS; // Bar grouping method
input group "Alert"
input bool inp_alertOnIBR = false; // Alert on IBR on new candle
input bool inp_alertAfterTFSwitch = false; // Alert áfter timeframe switch


//--- indicator buffers
double         irbUpArrows[];
double         irbUpArrowsColor[];
double         irbDownArrows[];
double         irbDownArrowsColor[];
//
int handleATR;
int handleVolume;
int timeframeFactor;
ENUM_TIMEFRAMES verif_TF_Enum;
bool startAlerting;
bool tfSupported;
string name;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {

// timeframe init
   verif_TF_Enum = inp_Timeframe;
   int verified_TimeframeSecs = PeriodSeconds(inp_Timeframe);
   if(verified_TimeframeSecs < PeriodSeconds(PERIOD_CURRENT))
     {
      verified_TimeframeSecs = PeriodSeconds(PERIOD_CURRENT);
      verif_TF_Enum = PERIOD_CURRENT;
     }
   timeframeFactor = (int)MathRound(verified_TimeframeSecs / PeriodSeconds(PERIOD_CURRENT));
   Print("timeframeFactor=",timeframeFactor);
// general init
   name = StringSubstr(__FILE__,0, StringLen(__FILE__)-4)+" "+StringSubstr(EnumToString(verif_TF_Enum), 7);
   IndicatorSetString(INDICATOR_SHORTNAME,name);
   tfSupported = isSupported(inp_Timeframe);
   if(!tfSupported)
     {
      Comment(name,": Timeframe ",EnumToString(inp_Timeframe)," on ",EnumToString(Period())," not supported");
      return(INIT_SUCCEEDED);
     }
// clean mem
   zeroMem();
// prepare buffer
   SetIndexBuffer(0, irbUpArrows,INDICATOR_DATA);
   SetIndexBuffer(1, irbUpArrowsColor,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, irbDownArrows,INDICATOR_DATA);
   SetIndexBuffer(3, irbDownArrowsColor,INDICATOR_COLOR_INDEX);
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,0.0);
   PlotIndexSetDouble(2,PLOT_EMPTY_VALUE,0.0);
//---
   startAlerting = inp_alertAfterTFSwitch;
//--
   handleATR = iATR(Symbol(), PERIOD_CURRENT, inp_ATR_period);
   if(handleATR == INVALID_HANDLE)
     {
      Alert("Error Creating Handles for ATR indicator - error: ",GetLastError());
      return(INIT_FAILED);
     }
   handleVolume = iCustom(Symbol(), PERIOD_CURRENT, inp_WAE_path);
   if(handleVolume == INVALID_HANDLE)
     {
      Alert("Could not initialize WAE from imd/waddah_attar_explosion - error:", GetLastError());
      return(INIT_FAILED);
     }
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Comment("");
   IndicatorRelease(handleATR);
   IndicatorRelease(handleVolume);
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
   if(!tfSupported)
      return rates_total;
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
   double valATR[];
//--
//--
   int start = (int)MathMax(prev_calculated-1,0);
// we want to combine
   /*rates_total-1 to set the IBR marker at beginning of new candle */
   for(int i=start; i<rates_total && !IsStopped(); i++)
     {
      if(i >= tfFactor && isLastBarInPeriod(time[i], tfFactor))
        {

         int openIdx = i - tfFactor + 1;
         double highVal = getMaxOfPrevBars(high, i, tfFactor);
         double lowVal = getMinOfPrevBars(low, i, tfFactor);
         bool filterVolumeMatches = true;
         // FILTER: ATR filter settings
         bool filterATRmatches = true;
         if(inp_BarSize_ActivateSettings)
           {
            filterATRmatches = false;
            if(CopyBuffer(handleATR, 0, rates_total-i-1, 1, valATR) == 1)
              {
               double barHeight = MathAbs(highVal - lowVal);
               filterATRmatches = barHeight > inp_BarSize_MinSizeATRFactor * valATR[0]
                                  && barHeight < inp_BarSize_MaxSizeATRFactor * valATR[0];
              }
            else
              {
               Alert("Could not copy from ATR indicator at pos ", i, " rates_total=", rates_total);
              }
           }
         if(i >= openIdx)
           {
            bool isLongIRB = highVal - MathMax(open[openIdx], close[i]) > (highVal-lowVal) * retracementBuy / 100.0;
            bool isShortIRB = MathMin(open[openIdx], close[i]) - lowVal > (highVal-lowVal) * retracementSell / 100.0;


            bool isVolumeMatching = evaluteVolume(i, rates_total, isLongIRB, isShortIRB, time[i]);
            int col = isVolumeMatching ? COLOR_PARTLY_ACTIVE : COLOR_INACTIVE;
            if(isVolumeMatching && filterATRmatches)
              {
               col = COLOR_FULL_ACTIVE;
              }
            //  Long IRB
            if(isLongIRB)
              {
               setValue(i, tfFactor, irbUpArrows, highVal); // DRAW IRB MARKER
               setValue(i, tfFactor, irbUpArrowsColor, col);
              }
            else
              {
               setValue(i, tfFactor, irbUpArrows, 0);
              }

            // Short IRB
            if(isShortIRB)
              {
               setValue(i, tfFactor, irbDownArrows, lowVal); // DRAW IRB MARKER
               setValue(i, tfFactor, irbDownArrowsColor, col);
              }
            else
              {
               setValue(i, tfFactor, irbDownArrows, 0);
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool evaluteVolume(int i, int rates_total, bool isLongMarker, bool isShortMarker, datetime barDate)
  {
   double volValue[];
   double volCol[];
   double volExploLine[];
   bool filterVolumeMatches = true;
   if(inp_Volume_ActivateSettings)
     {
      filterVolumeMatches = false;
      if(CopyBuffer(handleVolume, 0, rates_total-i-1, 1, volValue) == 1 &&
         CopyBuffer(handleVolume, 1, rates_total-i-1, 1, volCol) == 1 &&
         CopyBuffer(handleVolume, 2, rates_total-i-1, 1, volExploLine) == 1
        )
        {
         // trade direction
         //if((isLongMarker && volCol[0] == 1 /* green */)
         //   || (isShortMarker && volCol[0] == 2 /* red */))
         //  {
         // value
         double expoValue = volExploLine[0] * inp_Volume_PercentageOverExplosionLine;
         filterVolumeMatches = volValue[0] > expoValue;
         /*if(i > 122800)
           {
            Print(i, " ", TimeToString(barDate,TIME_DATE | TIME_MINUTES), " vol=", volValue[0], " expo=", volExploLine[0], " (", expoValue, ")");
           }*/
         //  }
        }
      else
        {
         //Alert("Could not copy from Volume indicator at pos ", i);
        }

     }
   return filterVolumeMatches;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void setValue(int startIdx, int count, double& buf[], double val)
  {
   for(int i=0; i<count; i++)
     {
      if(inp_ibr_calc_method == IRB_CALC_FlOATING_BARS)
        {
         if(buf[startIdx-i] == 0)
           {
            buf[startIdx-i] = val;
           }
        }
      else
        {
         buf[startIdx-i] = val;
        }
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
void doAlert(int rates_total, const datetime& time[], const double& high[], const double& low[])
  {
   static datetime prevtime=0; // stores the last alerted time
//-- only alert with new candle
   if(prevtime != time[rates_total-2] && !IsStopped())
     {
      Print("Alerting: ", time[rates_total-2]);
      if(inp_alertOnIBR)
        {
         if(irbUpArrows[rates_total-2] > 0 && irbUpArrowsColor[rates_total-2] == 0)
           {
            Alert(time[rates_total-2], " ", " IBR long/up ",StringSubstr(EnumToString(verif_TF_Enum), 7), " High(Entry): ", high[rates_total-2], ", Low(SL): ToDo");
           }
         if(irbDownArrows[rates_total-2] > 0 && irbDownArrowsColor[rates_total-2] == 0)
           {
            Alert(time[rates_total-2], " ", " IBR short/down ",StringSubstr(EnumToString(verif_TF_Enum), 7), " Low(Entry): ", low[rates_total-2], ", High(SL): ToDo");
           }
        }
      prevtime = time[rates_total-2];
     }
  }
//+------------------------------------------------------------------+
void zeroMem()
  {
   ZeroMemory(irbUpArrows);
   ZeroMemory(irbUpArrowsColor);
   ZeroMemory(irbDownArrows);
   ZeroMemory(irbDownArrowsColor);
  }

//+------------------------------------------------------------------+
//| Examples:
//| Curr -> Selected Timeframe
//| H1 -> H4 every 4th bar, last bar hour: 3, 7, 11,
//| H2 -> H4 every 2th bar, last bar hour: 2, 6, 10, 14, 18, 22
//| H4 -> H8 every 2th bar,
//| H4 -> D1 last bar
//+------------------------------------------------------------------+
bool isLastBarInPeriod(datetime t, int tfFactor)
  {
   if(tfFactor == 1)
     {
      return true;
     }
   if(inp_ibr_calc_method == IRB_CALC_FlOATING_BARS)
     {
      return true;
     }
   MqlDateTime dt;
   TimeToStruct(t, dt);
   switch(Period())
     {
      case PERIOD_M5:
         if(tfFactor == 3)
           {
            return dt.min == 10 || dt.min == 25 || dt.min == 40 || dt.min == 55;
           }
         if(tfFactor == 6)
           {
            return dt.min == 25 || dt.min == 55;
           }
         if(tfFactor == 12) // H1
           {
            return dt.min == 55;
           }
         if(tfFactor == 12*4)   // H4
           {
            return dt.min == 55 && (dt.hour == 3 || dt.hour == 7 || dt.hour == 11 || dt.hour == 15 || dt.hour == 19 || dt.hour == 23);
           }
         if(tfFactor == 12*4*12)   // D1
           {
            return dt.min == 55 && dt.hour == 23;
           }
         break;
      case PERIOD_M15:
         if(tfFactor <= 4)
           {
            return dt.min % tfFactor == (tfFactor -1);
           }
         else
            if(tfFactor == 16)
              {
               return (dt.hour % tfFactor) == 3 && dt.min == 45;
              }
            else
               if(tfFactor == 4*24 /* D1 */)
                 {
                  return (dt.hour == 23 && dt.min == 45);
                 }
         break;
      case PERIOD_H1:
         return dt.hour % tfFactor == (tfFactor - 1);
         break;
      case PERIOD_H4:
         if(tfFactor == 6)
           {
            // D1
            return dt.hour == 20; // TODO
           }
         break;
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isSupported(ENUM_TIMEFRAMES selectedTF)
  {
   if(PeriodSeconds() == PeriodSeconds(selectedTF))
      return true;
   switch(Period())
     {
      case PERIOD_M5:
         return (selectedTF == PERIOD_M15 || selectedTF == PERIOD_M30 || selectedTF == PERIOD_H1 || selectedTF == PERIOD_H4 || selectedTF == PERIOD_D1);
      case PERIOD_M15:
         return (selectedTF == PERIOD_H1 || selectedTF == PERIOD_M30 || selectedTF == PERIOD_H4 || selectedTF == PERIOD_D1);
      case PERIOD_H1:
         return (selectedTF == PERIOD_H2 || selectedTF == PERIOD_H4 || selectedTF == PERIOD_H6 || selectedTF == PERIOD_H8 || selectedTF == PERIOD_H12 || selectedTF == PERIOD_D1);
      case PERIOD_H4:
         return (selectedTF == PERIOD_D1);
     }
   return false;
  }
//+------------------------------------------------------------------+
