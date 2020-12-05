/*
****************************************************************************************************************************************************************************************
*                                                                                                                                                                                      *
* RRE.mq4                                                                                                                                                                               *
*                                                                                                                                                                                      *
* Copyright Peter Novak ml., M.Sc.                                                                                                                                                     *
****************************************************************************************************************************************************************************************
*/
#property copyright "Peter Novak ml., M.Sc."
#property link      "http://www.marlin.si"

// Vhodni parametri --------------------------------------------------------------------------------------------------------------------------------------------------------------------
extern double L=1;                   // Najvecja dovoljena velikost pozicij v lotih;
extern double p=0.9;                 // Profitni cilj izrazen v deležu ATR(10);
extern double tveganje=1;            // Tveganje v odstotkih - uporablja se za izracun velikosti pozicije.
extern int    n=0;                   // Številka iteracije;
extern double stoTock=0.00100;       // razdalja sto tock (razlicna za 5 mestne pare in 3 mestne pare)
extern double vrednostStoTock=0.009; // vrednost sto tock v EUR
extern double vstopnaCenaNakup;      // Vstopna cena za nakup;
extern double vstopnaCenaProdaja;    // Vstopna cena za prodajo;

// Globalne konstante ------------------------------------------------------------------------------------------------------------------------------------------------------------------
#define USPEH      -4 // oznaka za povratno vrednost pri uspešno izvedenem klicu funkcije;
#define NAPAKA     -5 // oznaka za povratno vrednost pri neuspešno izvedenem klicu funkcije;
#define S0          1 // oznaka za stanje S0 - Cakanje na zagon;
#define S1          2 // oznaka za stanje S1 - Zacetno stanje;
#define S2          3 // oznaka za stanje S2 - Trgovanje;
#define S3          4 // oznaka za stanje S3 - Zakljucek;

// Globalne spremenljivke --------------------------------------------------------------------------------------------------------------------------------------------------------------
int bpozicije[999];   // Enolicne oznake odprtih nakupnih pozicij;
int bukazi[999];      // Enolicne oznake odprtih nakupnih ukazov;
int kbpozicije;       // Indeks naslednje proste pozicije v polju bpozicije, hkrati tudi stevilo odprtih nakupnih pozicij.
int kbukazi;          // Indeks naslednje proste pozicije v polju bukazi, hkrati tudi stevilo odprtih nakupnih ukazov.
int kspozicije;       // Indeks naslednje proste pozicije v polju spozicije, hkrati tudi stevilo odprtih prodajnih pozicij.
int ksukazi;          // Indeks naslednje proste pozicije v polju sukazi, hkrati tudi stevilo odprtih prodajnih ukazov.
int spozicije[999];   // Enolicne oznake odprtih prodajnih pozicij;
int sukazi[999];      // Enolicne oznake odprtih prodajnih ukazov;
int stanje;           // Trenutno stanje algoritma;
int verzija=1;        // Trenutna verzija algoritma;

datetime trenutniDan; // Hrani datum in cas zacetka trenutnega trgovalnega dne;

double profitniCilj;          // Profitni cilj v tockah.
double maxIzpostavljenost;    // Najvecja izguba algoritma (minimum od skupniIzkupicek);
double skupniIzkupicek;       // Hrani trenutni skupni izkupicek trenutne iteracije - vsota vrednosti vseh odprtih in zaprtih pozicij;
double odprlaNakupVelikost;   // Hrani velikost nakupne pozicije, ki se je nazadnje odprla
double odprlaProdajaVelikost; // Hrani velikost prodajne pozicije, ki se je nazadnje odprla

bool odprlaNakup;   // Indikator, ki pove ali se je nazadnje odprla nakupna pozicija
bool odprlaProdaja; // Indikator, ki pove ali se je nazadnje odprla prodajna pozicija

/*
****************************************************************************************************************************************************************************************
*                                                                                                                                                                                      *
* GLAVNI PROGRAM in obvezne funkcije: init, deinit, start                                                                                                                              *
*                                                                                                                                                                                      *
****************************************************************************************************************************************************************************************
*/

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: deinit  
----------------
(o) Funkcionalnost: Sistem jo poklice ob zaustavitvi. M5 je ne uporablja
(o) Zaloga vrednosti: USPEH (vedno uspe)
(o) Vhodni parametri: /
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/   
int deinit()
{
  return(USPEH);
} // deinit

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: init  
--------------
(o) Funkcionalnost: Sistem jo poklice ob zagonu. V njej izvedemo naslednje:
  (-) izpišemo pozdravno sporocilo
  (-) ponastavimo vse kljucne podatkovne strukture algoritma na zacetne vrednosti
  (-) zacnemo novo iteracijo algoritma, ce je podana številka iteracije 0 ali vzpostavimo stanje algoritma glede na podano številko iteracije
(o) Zaloga vrednosti: USPEH, NAPAKA
(o) Vhodni parametri: /
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int init()
{
    IzpisiPozdravnoSporocilo();
    
    // Inicializacija globalnih spremenljivk
    kbpozicije=0;    
    kbukazi=0;       
    kspozicije=0;    
    ksukazi=0;       
    stanje=S0;             
    skupniIzkupicek=0;
    maxIzpostavljenost=0;
    trenutniDan=Time[0];
    profitniCilj=p*iATR(NULL, 0, 10, 0);

    // Verzija algoritma je hardkodirana
    verzija=1;

    // Zacetno stanje
    stanje=S0;

    // Samodejno polnjenje cen vstopa, samo za testiranje. Obvezno zakomentiraj spodnji dve vrstici pred produkcijsko uporabo.
    vstopnaCenaNakup=iHigh(NULL, PERIOD_D1, 1);
    vstopnaCenaProdaja=iLow(NULL, PERIOD_D1, 1);
    
    return(USPEH);
}   // init

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: start  
---------------
(o) Funkcionalnost: Glavna funkcija, ki upravlja celoten algoritem - sistem jo poklice ob vsakem ticku.
(o) Zaloga vrednosti: USPEH (funkcija vedno uspe)
(o) Vhodni parametri: /
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int start()
{
    int trenutnoStanje=stanje; // zabeležimo trenutno stanje, da bomo lahko ugotovili ali je prislo do spremembe stanja
    switch(stanje)
    {
        case S0: 
            stanje=S0CakanjeNaZagon(); 
            break;
        case S1: 
            stanje=S1ZacetnoStanje(); 
            break;
        case S2: 
            stanje=S2Trgovanje(); 
            break;
        case S3: 
            stanje=S3Zakljucek(); 
            break;
        default: Print( RRENapaka("start"), stanje, " ni veljavno stanje - preveri pravilnost delovanja algoritma." );
    }
  
    // ce je prišlo do prehoda med stanji izpišemo obvestilo
    if(trenutnoStanje!=stanje)
    {
        Print(RRESporocilo("start"), "Prehod: ", ImeStanja( trenutnoStanje ), " ===========>>>>> ", ImeStanja( stanje ) );
    }

    // ce se je poslabšala izpostavljenost, to zabeležimo
    if(maxIzpostavljenost>skupniIzkupicek)
    {
        maxIzpostavljenost=skupniIzkupicek;
        Print(RRESporocilo("start"), "Nova najvecja izpostavljenost: ", DoubleToString(maxIzpostavljenost, 5));
    }
    
    // osveževanje kljucnih kazalnikov delovanja algoritma na zaslonu
    Comment( "Številka iteracije: ", n, "\n",
        "Stanje: ", ImeStanja, "\n",
        "Nakupne odprte/ukazi: ", kbpozicije, "/", kbukazi, "\n",
        "Prodajne odprte/ukazi: ", kspozicije, "/", ksukazi, "\n", 
        "Skupni izkupicek:", DoubleToString(skupniIzkupicek, 5), "\n",
        "Najvecja izpostavljenost: ", DoubleToString( maxIzpostavljenost,  5));
    return(USPEH);
} // start

/*
****************************************************************************************************************************************************************************************
*                                                                                                                                                                                      *
* POMOŽNE FUNKCIJE                                                                                                                                                                     *
* Urejene po abecednem vrstnem redu                                                                                                                                                    *
****************************************************************************************************************************************************************************************
*/

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: ImeStanja(int KodaStanja)
-------------------------------------
(o) Funkcionalnost: Na podlagi numericne kode stanja, vrne opis stanja.  
(o) Zaloga vrednosti: imena stanj
(o) Vhodni parametri: KodaStanja: enolicna oznaka stanja.
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
string ImeStanja(int KodaStanja)
{
  switch(KodaStanja)
  {
    case S0: return("S0 - CAKANJE NA ZAGON");
    case S1: return("S1 - ZACETNO STANJE");
    case S2: return("S2 - TRGOVANJE");
    case S3: return("S3 - ZAKLJUCEK");
    default: Print (RRENapaka("ImeStanja"), "Koda stanja ", KodaStanja, " ni prepoznana. Preveri pravilnost delovanja algoritma.");
  }
  return( NAPAKA );
} // ImeStanja

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: IzpisiPozdravnoSporocilo
----------------------------------
(o) Funkcionalnost: izpiše pozdravno sporocilo, ki vsebuje tudi verzijo algoritma
(o) Zaloga vrednosti: USPEH (funkcija vedno uspe)
(o) Vhodni parametri: /
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int IzpisiPozdravnoSporocilo()
{
  Print("****************************************************************************************************************");
  Print("Dober dan. Tukaj RRE, verzija ", verzija, ", iteracija ", n, "." );
  Print("****************************************************************************************************************");
  return(USPEH);
} // IzpisiPozdravnoSporocilo

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: IzracunajVelikostPozicije(double tveganje, double razdalja)
---------------------------------------------------------------------
(o) Funkcionalnost: glede na stanje na racunu in podano tveganje v odstotkih izracuna velikost pozicije
(o) Zaloga vrednosti: velikost pozicije
(o) Vhodni parametri:
(-) tveganje: tveganje izrazeno v odstotku stanja na racunu v primeru da je dosezen stop loss
(-) razdalja: razdalja med ceno odprtja in stop loss-om v tockah
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
double IzracunajVelikostPozicije(double tveganje, double razdalja)
{
    int k;
    double l;
    double velikost;
  
    k=(razdalja/stoTock)+1;
    l=((tveganje/100)*AccountBalance())/(k*vrednostStoTock);
    velikost=0.01*MathFloor(l);
  
    // ce izracunana velikost presega najvecjo dovoljeno velikost, ki je podana kot parameter algoritma, potem vrnemo najvecjo dovoljeno velikost;
    if(velikost>L)
    {
        Print(RRESporocilo("IzracunajVelikostPozicije"), "Izracunana velikost pozicije ", DoubleToString(velikost, 2),
            " presega maksimalno velikost ", DoubleToString(L, 2), ". Uporabljena bo maksimalna velikost.");
        return(L);
    }
    else
    {
        Print(RRESporocilo("IzracunajVelikostPozicije"), "Velikost pozicij: ", DoubleToString(velikost, 2));
        return(velikost);
    }
} // IzracunajVelikostPozicije

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: NovDan()
------------------
(o) Funkcionalnost: vrne true, ce je napocil nov dan in false ce ni.
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
bool NovDan()
{
  if(trenutniDan!=Time[0];
  {
    trenutniDan=Time[0];
    return(true);
  }
  else
  {
    return(false);
  }
}

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: OdpriPozicijo(int Smer, double velikost)
----------------------------------------------------
(o) Funkcionalnost: Odpre pozicijo po trenutni tržni ceni v podani Smeri
(o) Zaloga vrednosti: ID odprte pozicije;
(o) Vhodni parametri:
(-) Smer: OP_BUY ali OP_SELL
(-) velikost: velikost pozicije
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int OdpriPozicijo( int smer, double velikost )
{
    int rezultat; // spremenljivka, ki hrani rezultat odpiranja pozicije
    int magicNumber; // spremenljivka, ki hrani magic number pozicije
    string komentar; // spremenljivka, ki hrani komentar za pozicijo
    magicNumber=n;
    komentar=StringConcatenate( "RREV", verzija, "-", n);

    do
    {
        if(smer==OP_BUY)
        {
            rezultat=OrderSend(Symbol(), OP_BUY, velikost, Ask, 0, sl, 0, komentar, magicNumber, 0, Green);
        }
        else                 
        {
            rezultat=OrderSend(Symbol(), OP_SELL, velikost, Bid, 0, sl, 0, komentar, magicNumber, 0, Red);
        }
        if(rezultat == -1)
        {
            Print(RRENapaka("OdpriPozicijo"), "Neuspešno odpiranje pozicije. Ponoven poskus cez 30s..." );
            Sleep(30000);
            RefreshRates();
        }
    }
    while(rezultat==-1);
    return(rezultat);
} // OdpriPozicijo

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: OdpriUkaz( int Smer, double cena, double velikost)
------------------------------------------------------------
(o) Funkcionalnost: Odpre vstopni ukaz na podani ceni v podani Smeri
(o) Zaloga vrednosti: ID odprte pozicije;
(o) Vhodni parametri:
(-) Smer: OP_BUYSTOP ali OP_SELLSTOP
(-) velikost: velikost pozicije
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int OdpriUkaz( int smer, double cena, double velikost )
{
    int rezultat; // spremenljivka, ki hrani rezultat odpiranja pozicije
    int magicNumber; // spremenljivka, ki hrani magic number pozicije
    string komentar; // spremenljivka, ki hrani komentar za pozicijo
    double odmik; // Odmik - če se ukaza ne da odpreti, ker je cena preblizu, potem vecam odmik, dokler odpiranje ni mogoce
    
    odmik=0;
    magicNumber=n;
    komentar=StringConcatenate( "RREV", verzija, "-", n);

    do
    {
        if(smer==OP_BUYSTOP)
        {
            rezultat=OrderSend(Symbol(), OP_BUYSTOP, velikost, cena+odmik, 0, sl, 0, komentar, magicNumber, 0, Green);
        }
        else                 
        {
            rezultat=OrderSend(Symbol(), OP_SELLSTOP, velikost, cena-odmik, 0, sl, 0, komentar, magicNumber, 0, Red);
        }
        if(rezultat == -1)
        {
            odmik=odmik+(0.1*stoTock);
            Print(RRENapaka("OdpriUkaz"), "Neuspešno odpiranje ukaza. Ponovno poskusim cez 10s s prilagojeno ceno.");
            Sleep(10000);
            RefreshRates();
        }
    }
    while(rezultat==-1);
    return(rezultat);
} // OdpriUkaz

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: OdstraniUkaz(int vrsta)
----------------------------------
(o) Funkcionalnost: Odstrani ukaz iz polja odprtih ukazov.
(o) Zaloga vrednosti:
(-) true : vedno uspe.
(o) Vhodni parametri: OP_BUYSTOP ali OP_SELLSTOP
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
bool OdstraniUkaz(int vrsta, int indeks)
{
    int i;

    switch(vrsta)
    {
        case OP_BUYSTOP:
            for(i=indeks;i<kbukazi;i++)
            {
                bukazi[i]=bukazi[i+1];
            }
            kbukazi--;
            break;
        case OP_SELLSTOP:
            for(i=indeks;i<ksukazi;i++)
            {
                sukazi[i]=sukazi[i+1];
            }
            ksukazi--;
    }
    return(true);
}


/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: PozicijaZaprta( int id )
----------------------------------
(o) Funkcionalnost: Funkcija pove ali je pozicija s podanim id-jem zaprta ali ne.
(o) Zaloga vrednosti:
(-) true : pozicija je zaprta.
(-) false: pozicija je odprta.
(o) Vhodni parametri: id - oznaka pozicije
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
bool PozicijaZaprta( int id )
{
  int Rezultat;

  Rezultat = OrderSelect( id, SELECT_BY_TICKET );
  if( Rezultat         == false ) { Print( "RRE-V", verzija, ":[", n, "]:", ":PozicijaZaprta:OPOZORILO: Pozicije ", id, " ni bilo mogoce najti. Preveri pravilnost delovanja algoritma." ); return( true );}
  if( OrderCloseTime() == 0     ) { return( false ); }
  else                            { return( true );  }
} // PozicijaZaprta

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: RRESporocilo()
---------------------------------------
(o) Funkcionalnost: Vrne glavo sporocila, ki vsebuje podatke o iteraciji, verziji algoritma in paru.
(o) Zaloga vrednosti: USPEH (vedno uspe)
(o) Vhodni parametri: funkcija - ime funkcije, ki posilja sporocilo
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
string RRESporocilo(string funkcija)
{
    return("RRE-V"+verzija+":["+n+"]:"+":"+funkcija+": ");
} // RRESporocilo

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: RRENapaka()
---------------------------------------
(o) Funkcionalnost: Vrne glavo sporocila, ki vsebuje podatke o iteraciji, verziji algoritma in paru.
(o) Zaloga vrednosti: USPEH (vedno uspe)
(o) Vhodni parametri: funkcija - ime funkcije, ki posilja sporocilo
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
string RRENapaka(string funkcija)
{
    return("RRE-V"+verzija+":["+n+"]:"+":"+funkcija+":NAPAKA: ");
} // RRENapaka

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: VrednostPozicij()
------------------------------------
(o) Funkcionalnost: Vrne vrednost vseh pozicij
(o) Zaloga vrednosti: vrednost pozicij v tockah
(o) Vhodni parametri: /
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
double VrednostPozicij()
{
    double v;
    int i;

    v=0;
    for(i=0;i<kbpozicije;i++)
    {
        v=v+VrednostPozicije(bpozicije[i]);
    }
    for(i=0;i<kspozicije;i++)
    {
        v=v+VrednostPozicije(spozicije[i]);
    }
    return(v);
}

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: VrednostPozicije(int id)
------------------------------------
(o) Funkcionalnost: Vrne vrednost pozicije z oznako id v tockah
(o) Zaloga vrednosti: vrednost pozicije v tockah
(o) Vhodni parametri: id - oznaka pozicije
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
double VrednostPozicije( int id )
{
  bool rezultat;
  int  vrstaPozicije;
  
  rezultat = OrderSelect( id, SELECT_BY_TICKET );
  if( rezultat == false ) { Print( "RRE-V", verzija, ":[", n, "]:", ":VrednostPozicije:NAPAKA: Pozicije ", id, " ni bilo mogoce najti. Preveri pravilnost delovanja algoritma." ); return( 0 ); }
  vrstaPozicije = OrderType();
  switch( vrstaPozicije )
  {
    case OP_BUY: if( OrderCloseTime() == 0 ) { return( Bid - OrderOpenPrice() ); } else { return( OrderClosePrice() - OrderOpenPrice()  ); }
    case OP_SELL: if( OrderCloseTime() == 0 ) { return( OrderOpenPrice() - Ask ); } else { return(  OrderOpenPrice() - OrderClosePrice() ); }
    default: Print( "RRE-V", verzija, ":[", n, "]:", ":VrednostPozicije:NAPAKA: Vrsta ukaza ni ne BUY ne SELL. Preveri pravilnost delovanja algoritma." ); return( 0 );
  }
} // VrednostPozicije

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: ZapriPozicije()
---------------------------------
(o) Funkcionalnost: Zapre vse pozicije in ukaze.
(o) Zaloga vrednosti:
(-) true: ce je bilo zapiranje pozicije uspešno;
(-) false: ce zapiranje pozicije ni bilo uspešno;
(o) Vhodni parametri: -
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
bool ZapriPozicije()
{
    int i;

    for(i=0;i<kbpozicije;i++)
    {
        ZapriPozicijo(bpozicije[i]);
    }
    for(i=0;i<kspozicije;i++)
    {
        ZapriPozicijo(spozicije[i]);
    }
    for(i=0;i<kbukazi;i++)
    {
        ZapriPozicijo(kbukazi[i]);
    }
    for(i=0;i<ksukazi;i++)
    {
        ZapriPozicijo(ksukazi[i]);
    }
    return(true);
}

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: ZapriPozicijo( int id )
---------------------------------
(o) Funkcionalnost: Zapre pozicijo z oznako id po trenutni tržni ceni.
(o) Zaloga vrednosti:
(-) true: ce je bilo zapiranje pozicije uspešno;
(-) false: ce zapiranje pozicije ni bilo uspešno;
(o) Vhodni parametri: id - oznaka pozicije.
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
bool ZapriPozicijo( int id )
{
    int Rezultat;

    Rezultat = OrderSelect( id, SELECT_BY_TICKET );
    if( Rezultat == false )
    { 
        Print(RRENapaka("ZapriPozicijo"), "Pozicije ", id, " ni bilo mogoce najti. Preveri pravilnost delovanja algoritma." ); 
        return( false ); 
    }
    if(OrderCloseTime()==0)
    {
        switch( OrderType() )
        {
            case OP_BUY : return( OrderClose ( id, OrderLots(), Bid, 0, Green ) );
            case OP_SELL: return( OrderClose ( id, OrderLots(), Ask, 0, Red   ) );
            default:      return( OrderDelete( id ) );
        }  
    }
    return(true);
} // ZapriPozicijo

/*
****************************************************************************************************************************************************************************************
*                                                                                                                                                                                      *
* FUNKCIJE DKA                                                                                                                                                                         *
*                                                                                                                                                                                      *
****************************************************************************************************************************************************************************************
*/
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA DKA: S0CakanjeNaZagon()
--------------------------------
V to stanje vstopimo takoj po zakljuceni inicializaciji algoritma. V tem stanju cakamo, da se bo zacel nov trgovalni dan.
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int S0CakanjeNaZagon()
{
    if(NovDan()==true) // ce je nastopil nov dan, potem gremo naprej v zacetno stanje
    {
        odprlaNakup=false;
        odprlaProdaja=false;
        return(S1);
    }
    else  // v nasprotnem primeru ostanemo v tem stanju
    {
        return(S0);
    }
} // S0CakanjeNaZagon

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA DKA: S1ZacetnoStanje()
-------------------------------
V tem stanju se znajdemo, ko je nastopil nov trgovalni dan in v njem cakamo, da bo dosežena bodisi cena za vstop v smeri nakupa (parameter vstopnaCenaNakup) bodisi cena za vstop
v smeri prodaje (parameter vstopnaCenaProdaja).
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int S1ZacetnoStanje()
{
    double stopLossCena;
  
    if(Bid>=vstopnaCenaNakup) // ce je presezena cena nakupne ravni, odpremo nakupno pozicijo in gremo v stanje S2
    {
        odprlaNakupVelikost=IzracunajVelikostPozicije(tveganje, Ask-vstopnaCenaProdaja);
        bpozicije[kbpozicije]=OdpriPozicijo(OP_BUY, odprlaNakupVelikost);
        kbpozicije++;
        odprlaProdaja=true;
        return(S2);
    }
    if(Ask<=vstopnaCenaProdaja) // ce je presezena cena prodajne ravni, odpremo prodajno pozicijo in gremo v stanje S2
    {
        odprlaProdajaVelikost=IzracunajVelikostPozicije(tveganje, vstopnaCenaNakup-Bid);
        spozicije[kspozicije]=OdpriPozicijo(OP_SELL, odprlaProdajaVelikost);
        kspozicije++;
        odprlaProdaja=true;
        return(S2);
    }
  
    // dokler smo znotraj intervala med obema vstopnima cenama, ostajamo v tem stanju
    return(S1);
} // S1ZacetnoStanje

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA DKA: S2Trgovanje()
---------------------------
V tem stanju imamo odprte pozicije in cakamo, da bo dosezen profitni cilj. 
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int S2Trgovanje()
{
    string sporocilo; // niz za sestavljanje sporocila, ki ga posljemo na terminal ob doseženem profitnem cilju
    double vrednost;  // zacasna spremenljivka, ki hrani trenutno vrednost pozicij
    int i;            // stevec
  
    // ce je dosezen profitni cilj, zapremo odprto pozicijo in gremo v koncno stanje. Posljemo tudi sporocilo na terminal.
    vrednost=VrednostPozicij();
    if(vrednost>=profitniCilj)
    {
        ZapriPozicije();
        sporocilo="RRE-V"+verzija+":OBVESTILO: dosežen profitni cilj: "+Symbol()+" iteracija "+IntegerToString(n) + ".";
        Print(sporocilo);
        SendNotification(sporocilo);
        return(S3);
    }
  
    // ce je napocil nov dan, potem nastavim nov par vstopnih cen in obenem nastavim varnostni vstopni ukaz na tisti strani svece, kjer se vstop ni sprozil
    if(NovDan()==true)
    {
        if(odprlaNakup==true)
        {
            sukazi[ksukazi]=OdpriUkaz(OP_SELLSTOP, odprlaNakupVelikost, MathMin(vstopnaCenaProdaja, Low[1]));
            sukazi++;
            odprlaNakup=false;
            return(S1);
        }
        if(odprlaProdaja==true)
        {
            bukazi[kbukazi]=OdpriUkaz(OP_BUYSTOP, odprlaProdajaVelikost, MathMax(vstopnaCenaNakup, High[1]));
            bukazi++;
            odprlaProdaja=false;
            return(S1);
        }
    }

    // ce se je kateri od ukazov sprozil, ga prepisemo med odprte pozicije
    for(i=0;i<kbukazi;i++)
    {
        OrderSelect(bukazi[i], SELECT_BY_TICKET)
        if(OrderType()==OP_BUY)
        {
            bpozicije[kbpozicije]=bukazi[i];
            kbpozicije++;
            OdstraniUkaz(OP_BUYSTOP, i);
        }
    }
    for(i=0;i<ksukazi;i++)
    {
        OrderSelect(sukazi[i], SELECT_BY_TICKET)
        if(OrderType()==OP_SELL)
        {
            spozicije[kbpozicije]=bukazi[i];
            kspozicije++;
            OdstraniUkaz(OP_SELLSTOP, i);
        }
    }

    // ce se ni zgodilo nic od zgoraj navedenega, ostanemo v tem stanju
    return(S2);
} // S2Trgovanje

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA DKA: S3Zakljucek()
V tem stanju se znajdemo, ko je bil dosežen profitni cilj. To je koncno stanje.
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int S3Zakljucek()
{
  return(S3);
} // S3Zakljucek