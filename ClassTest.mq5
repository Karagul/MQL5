//+------------------------------------------------------------------+
//|                                                    MakeMoney.mq5 |
//|                        Copyright 2018, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
//双仓EA(一单买入，一单卖出)
#property copyright "Copyright 2018, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade\AccountInfo.mqh>//账户信息
#include <Trade\DealInfo.mqh>//交易类 只针对已经发生了交易的
#include <Trade\HistoryOrderInfo.mqh>//历史订单，可能包括没有交易成功的订单
#include <Trade\OrderInfo.mqh>//订单类
#include <Trade\SymbolInfo.mqh>//货币基础类
#include <Trade\PositionInfo.mqh>//仓位
#include <Trade\Trade.mqh>//交易类
#include <..\Experts\makemoney\MyTradeObject.mqh>//我的交易类

CMyTradeObject myTradeObject1;
CMyTradeObject myTradeObject2;

CPositionInfo     myPosition;  //持仓对象
CSymbolInfo mySymbol;//品种(货币)对象
CAccountInfo myAccount;//账户对象
CHistoryOrderInfo myHistoryOrderInfo;//
CTrade myTrade;//交易对象
CDealInfo myDealInfo;//已经交易的订单对象（已经交易）
double everyLots=1;//每次交易的手数
double lastMinutePrice=0;//最近一次整分钟点的价格（时时最新）
double mvLastMinutePrice=0;//最近一次整分钟点的价格（mvTimes日移动平均线）Moving Average
bool isSsynchronism=true;//是否线程同步，只有等目前没有挂单的时候才可以交易,也就是上一次的交易已经被完全执行
int mvTimes=25;//移动平均线的频率 25天
int compareStatus=0;//mvTimes日均线价格和最新价格比较状态 0:mvTimes日均价大于最新价格 1:mvTimes.。小于最新价格
int initDealCount= 0;
int permissionPositionCount=1; //允许开仓的最大数量 如果发现仓位多了,则把其他的仓都平仓，只留下一个
static int positionStatus=0;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   myTrade.Buy(everyLots,_Symbol);
    ulong  resultTickeCode =  myTrade.ResultDeal();//
    printf(resultTickeCode);
   ulong ticket=PositionGetTicket(0);
   printf(ticket+"----");
     ulong  ticketCode =  myTrade.ResultOrder();//
    printf(ticketCode);
//进行初始化前的安全校验
   bool check=checkInitTrade();
   if(!check)
     {
      printf("校验没有通过,不可以交易!!");
      return(INIT_FAILED);
     }
//初始化第一次的数据
   initMinutePrice();
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| 先获取当前是都有仓位，如果没有，那么在价格发生交叉的时候先开一单。(暂时不考虑线程同步的问题)                                                           |
//+------------------------------------------------------------------+
void OnTick()
  {
    myTrade.Buy(everyLots,_Symbol);
    ulong  resultTickeCode =  myTrade.ResultDeal();//
    printf(resultTickeCode);
   ulong ticket=PositionGetTicket(0);
   printf(ticket+"----");
     ulong  ticketCode =  myTrade.ResultOrder();//
    printf(ticketCode);
  }
//+------------------------------------------------------------------+
//|交易触发函数                                                                  |
//+------------------------------------------------------------------+
void OnTradeaaaa()
  {

   printf("自动平仓调用");
//如果有新的订单动态 锁定线程
   isSsynchronism=false;
//获取最新的成交总数
   HistorySelect(0,TimeCurrent());
   int realDealCount=HistoryDealsTotal();
   printf("成交总数："+realDealCount);
   int orderTotal=HistoryOrdersTotal();
   printf("orderTotal:"+orderTotal);
   if(realDealCount-initDealCount==1)
     {//交易总数增大了一笔
      initDealCount=realDealCount;
      isSsynchronism=true;
      ulong dealTicket=HistoryDealGetTicket(realDealCount-1);

      printf("!!!!!!!!!!!!!!!!!!!!!");
      myDealInfo.Ticket(dealTicket);
      PositionSelect(_Symbol);
      printf("订单号(dealTicket)："+dealTicket+",时间："+TimeCurrent());
      if(DEAL_ENTRY_OUT==myDealInfo.Entry())
        {
         printf("平仓成功，交易订单号(dealTicket)："+dealTicket+",时间："+TimeCurrent());
        }
      else if(myDealInfo.Entry()==DEAL_ENTRY_IN)
        {
         printf("买入成功，交易订单号(dealTicket)："+dealTicket+",时间："+TimeCurrent());
           }else if(myDealInfo.Entry()==DEAL_ENTRY_OUT_BY){
         printf("通过反向持仓来平仓，交易订单号(dealTicket)："+dealTicket+",时间："+TimeCurrent());
        }
      //查看订单状态
     }
  }
//|开仓                                                         |
//+------------------------------------------------------------------+
int  openPosition(int status)
  {
   bool isHavePosition=PositionSelect(_Symbol);
   int changeStatus=status;
   if(!isHavePosition)
     {//手中没有仓 那么先开一仓  
      if(changeStatus==1)
        {

         myTrade.Buy(everyLots,_Symbol);
         printf("买入成功:"+TimeToString(TimeCurrent(),TIME_MINUTES));
           }else if(changeStatus==0){
         myTrade.Sell(everyLots,_Symbol);
         printf("卖出成功:"+TimeToString(TimeCurrent(),TIME_MINUTES));
           }else if(changeStatus==-1){
         //printf("没有出现交叉");
           } else{
         printf("数据异常");
        }
        } else{//手中有一仓，坐等平仓了 先计算利润 
      double positionProfit=getPositionProfit();
      if(positionProfit>=2 || positionProfit<-15)
        {
         ulong ticket=PositionGetTicket(0);
         myTrade.PositionClose(ticket);
         printf("平仓成功,利润为："+positionProfit);
         return 120;//平仓之后休息一下
        }

     }
   return 110;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getPositionProfit()
  {
   int total=PositionsTotal();
   double moneyTotal=0.000000000000001;
   double profit=0;
   if(total>=1)
     {
      for(int i=0;i<total;i++)
        {
         ulong ticket=PositionGetTicket(i);
         myPosition.SelectByTicket(ticket);
         moneyTotal+=myPosition.Volume() *myPosition.PriceOpen()*1000;//这一仓花费的金额
         profit+=myPosition.Profit();

        }
     }
   double proficPercent=100*profit/moneyTotal;
   return proficPercent;
//printf("proficPercent:"+profit/100);
  }
//如果仓位过多
int checkPositon()
  {
   PositionSelect(_Symbol);//将服务器的数据写入本地缓存
   int positionTotal=PositionsTotal();//获取开仓总数,每一个未平仓的交易都是一个仓位。所以手中有多少没有平仓的交易就是多少个仓
   if(positionTotal>permissionPositionCount)
     {//手中有还没有平仓的交易
      printf("持仓过多，只能留下一个仓位，即将把多余的仓位平仓............");
      for(int i=0;i<positionTotal;i++)
        {
         ulong ticket=PositionGetTicket(i);
         myTrade.PositionClose(ticket,-1);
         uint resultCode=myTrade.ResultRetcode();
         if(resultCode!=TRADE_RETCODE_DONE)
           {
            printf("平仓失败,返回码是："+resultCode);
           }
         // else{
         // string code=IntegerToString(resultCode);
         // printf("平仓成功！！！返回码是："+code);
         //}
        }
      //不能直接返回成功的标识，可能有会一些交易被拒绝，平仓失败，所以需要等下一个刷新验证
      positionStatus=0;//仓位标识 过多用0 合适用1 
      return positionStatus;//不能交易标识
        }else{
      positionStatus=1;
      // printf("当前仓位不错，可以交易！！！");
      return positionStatus;//不能交易标识
     }
  }
//开始交易
int startTrade()
  {
   if(!isSsynchronism)//线程没有同步  上一个订单还没有完全结束
     {
      return 0;
     }
//判断是否发生时间转变 时间转变的判断是 mvTimes日平均价格或者时时价格发生了变化
//获取时时分钟价格 
   int iMAPriceIndex=iMA(Symbol(),0,1,0,MODE_SMA,PRICE_CLOSE);
   double nowPriceList[];//时时价格
   ArraySetAsSeries(nowPriceList,true);
   CopyBuffer(iMAPriceIndex,0,0,2,nowPriceList);
   double nowPrice=nowPriceList[1];
//获取时时分钟价格 mvTimes日均价
   int iMA25PriceIndex=iMA(Symbol(),PERIOD_M1,mvTimes,0,MODE_SMA,PRICE_CLOSE);
   double mvNowPriceList[];//mvTimes日价格线
   ArraySetAsSeries(mvNowPriceList,true);
   CopyBuffer(iMA25PriceIndex,0,0,2,mvNowPriceList);
   double mvNowPrice=mvNowPriceList[1];
//获取当前时间
   datetime serviceTime=TimeCurrent();
   string oneMinuterTime=TimeToString(serviceTime,TIME_MINUTES);
   string nowTime=TimeToString(serviceTime,TIME_SECONDS);

   if(lastMinutePrice!=mvLastMinutePrice || nowPrice!=mvNowPrice)
     {
      // printf("价格出现了变化，其实是时间往前推进了！！！！");
      //时间交换  往前推进一分钟
      lastMinutePrice=nowPrice;
      mvLastMinutePrice=mvNowPrice;
      bool tradeStatus=false;//允许交易的标志
      bool tradeType=-1;//交易类型 1：可以卖出 0 ：买可以买入 -1：不可交易
      if(lastMinutePrice>mvLastMinutePrice && compareStatus==0)
        {//说明时时价格和mvTimes日均价出现了交叉 并且是mvTimes日均价线 在下面
         //buy信号        
         myTrade.SetExpertMagicNumber(666666);//buy 魔术号标记
         tradeStatus=true;
         tradeType=0;
           }else if(lastMinutePrice<mvLastMinutePrice && compareStatus==1){//说明时时价格和mvTimes日均价出现了交叉 并且是时时价格在下面                                //买入信号！！！
                                                                           //sell信号
         myTrade.SetExpertMagicNumber(888888);//sell魔术号标记
         tradeStatus=true;
         tradeType=1;
        }
      if(tradeStatus)
        { //可以进行交易判断
         //查看当前是否已经开了仓  如果还没有 那么就直接买一把
         bool isHaveOrder=PositionSelect(_Symbol);
         if(!isHaveOrder && tradeType==1)
           {//第一次下单 买入
            myTrade.Buy(0.1,_Symbol);
           }
         else if(!isHaveOrder && tradeType==0)
           {
            myTrade.Sell(0.1,_Symbol);
           }
        }
      return 1;
     }
   return 1;
  }
//检查当前是否可以交易（仅仅用在初始化的时候）
bool checkInitTrade()
  {
//查看当前交易品种
   if(!mySymbol.Name("EURUSD"))
     {
      printf("当前品种不是EURUSD,不进行交易！！！");
      return false;
     }
//查看当前账号
//long  accountId = 7345113 ;
   const long   accountId=8436620;
   if(myAccount.Login()!=accountId)
     {
      //   printf("当前登录账号不对,不能进行交易！！！");
      //  return false;
     }
//查看当前交易模式
   if(myAccount.TradeMode()!=ACCOUNT_TRADE_MODE_DEMO)
     {
      printf("当前账号交易模式不是模拟账户,不进行交易！！！");
      return false;
     }
//确保是线程安全！！！！
   if(!myAccount.TradeAllowed() || !myAccount.TradeExpert() || !mySymbol.IsSynchronized())
     {
      printf("账户异常,不能交易！！！");
      return false;
     }
   int ordersTotal=OrdersTotal();//当前挂单量
   if(ordersTotal>0)
     {
      printf("当前账户有未完成的订单，不能继续交易！！");
      return false;
     }
   return true;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//判断价格交易函数 1 :买入 0：卖出 -1：什么都不是
int getChangeStatus()
  {
//获取时时分钟价格 
   int iMAPriceIndex=iMA(Symbol(),0,1,0,MODE_SMA,PRICE_CLOSE);
   double nowPriceList[];//时时价格
   ArraySetAsSeries(nowPriceList,true);
   CopyBuffer(iMAPriceIndex,0,0,2,nowPriceList);
   double nowPrice=nowPriceList[1];
//获取时时分钟价格 mvTimes日均价
   int iMA25PriceIndex=iMA(Symbol(),PERIOD_M1,mvTimes,0,MODE_SMA,PRICE_CLOSE);
   double mvNowPriceList[];//mvTimes日价格线
   ArraySetAsSeries(mvNowPriceList,true);
   CopyBuffer(iMA25PriceIndex,0,0,2,mvNowPriceList);
   double mvNowPrice=mvNowPriceList[1];

// printf("lastMinutePrice:"+lastMinutePrice);
// printf("nowPrice:"+nowPrice);
   if(lastMinutePrice!=nowPrice && mvLastMinutePrice!=mvNowPrice)
     {

      if(((lastMinutePrice-mvLastMinutePrice>0) && (nowPrice-mvNowPrice<0)) || ((lastMinutePrice-mvLastMinutePrice)<0 && (nowPrice-mvNowPrice)>0))
        {//价格出现了交叉 可以下单了

         //判断应该买入还是卖出
         if(nowPrice-mvNowPrice>0)
           {//买入 时时价格变为在上方
            return 1;
              }else if(nowPrice<mvNowPrice){//卖出
            return 0;
           }
           }else{
         // printf("什么都不是："+TimeToString(TimeCurrent(),TIME_SECONDS));
         return -1;
        }
     }
   return -1;

  }
//交换价格
void priceChange()
  {
double nowTimePrice = getNowtimeMinutePrice();
double movingAverageMinutePrice  = getMovingAverageMinutePirce();
   if(movingAverageMinutePrice!=mvLastMinutePrice && lastMinutePrice!=nowTimePrice)
     {
      //时间交换  往前推进一分钟
      lastMinutePrice=nowTimePrice;
      mvLastMinutePrice=movingAverageMinutePrice;
     }
  }
//+--------------------------获取MovingAverage分钟价格----------------------------------------+
double getMovingAverageMinutePirce()
  {
//每分钟 mvTimes 均线
   int mvMinutePrice=iMA(Symbol(),PERIOD_M1,mvTimes,0,MODE_SMA,PRICE_CLOSE);
   double mvMinutePriceList[];//分钟价格
   ArraySetAsSeries(mvMinutePriceList,true);
   CopyBuffer(mvMinutePrice,0,0,2,mvMinutePriceList);
//初始化第一分钟价格 mv
   return mvMinutePriceList[1];
  }
//+----------------------------获取nowTimeMinute分钟价格--------------------------------------+
double getNowtimeMinutePrice()
  {
//实时价格
   int nowMinutePrice=iMA(Symbol(),0,1,0,MODE_SMA,PRICE_CLOSE);
   double nowMinutePriceList[];//时时价格
   ArraySetAsSeries(nowMinutePriceList,true);
   CopyBuffer(nowMinutePrice,0,0,2,nowMinutePriceList);
//1为 上一分钟价格  0 为时时价格
   return nowMinutePriceList[1];//初始化第一分钟价格 now
  }
//初始化价格 只有初始化的时候调用
void initMinutePrice()
  {
   mvLastMinutePrice=getMovingAverageMinutePirce();
   lastMinutePrice=getNowtimeMinutePrice();
   printf("初始化价格成功："+TimeToString(TimeCurrent())+";---nowTimeMinute价格："+DoubleToString(lastMinutePrice)+";---movingAverageMinute价格："+DoubleToString(mvLastMinutePrice));
  }
//+------------------------------------------------------------------+
