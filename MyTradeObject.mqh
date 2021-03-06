//+------------------------------------------------------------------+
//|                                                MyTradeObject.mqh |
//|                        Copyright 2018, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Object.mqh>
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CMyTradeObject : public CObject
  {
private:
   double            price;                     // 买入价格
   ulong              ticket;                     // 交易订单号
   datetime          time;                     // 交易时间
   long              magic;                     // 魔术号

public:
                     CMyTradeObject();
                    ~CMyTradeObject();
   void              SetPrice(double n){price=n;}// 设置 买入价格 
   double            GetPrice(){return (price);} // 返回 买入价格  
   void              SetTicket(ulong n){ticket=n;}// 设置 交易订单号 
   ulong            GetTicket(){return(ticket);} // 返回 交易订单号 
   void              SetTime(datetime n){time=n;}// 设置 交易时间
   datetime            GetTime(){return(time);} // 返回 交易时间 
   void              SetMagic(long n){magic=n;}// 设置 魔术号 
   long            GetMagic(){return (magic);} // 返回 魔术号 
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CMyTradeObject::CMyTradeObject()
  {
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CMyTradeObject::~CMyTradeObject()
  {
  }
//+------------------------------------------------------------------+
