## TODO
## assemble parent data:
## - country list /
## - demography (ideally year) (not available year)
## - LAT /
## - BCG coverage by year/age
## - LE at age (done already?)
## - notifications by age /
## - estimated incidence by age /
## - existing IPT ?? X


## TODO
## other
## - HIV model & data
## - LHS??


## work ----

## --- WHO data from
## http://www.who.int/tb/country/data/download/en/
## <2018-01-11 Thu>

## notifications
N <- fread('/Users/pjd/Documents/WHO_TBreports/data2017/TB/TB_notifications_2018-01-11.csv')
N <- N[year==2016]                      #restrict
## esimtations
E <- fread('/Users/pjd/Documents/WHO_TBreports/data2017/TB/TB_burden_countries_2018-01-11.csv')
E <- E[year==2016]                      #restrict
## merge
D <- merge(N,E,by=c('country','iso2','iso3','iso_numeric','g_whoregion','year'))

## --- LAT
load('/Users/pjd/Documents/WHO_TBreports/LAT.Rdata')
D <- merge(D,LAT[,c('iso3','LAT')],by='iso3',all.x=TRUE)
## deal with NAs as regional averages
latna <- which(is.na(D$LAT))
latnareg <- D$g_whoregion[latna]
mnlat <- rep(0,length(latnareg))
for(i in 1:length(mnlat))               #wasteful
  mnlat[i] <- D[g_whoregion==latnareg[i],mean(LAT,na.rm = TRUE)]
D[latna,LAT:=mnlat]


## --- WHO/UNICEF BCG
B <- fread('data/BCG_11_1_2018.csv',skip=1)
B <- B[,c(2,5:41),with=FALSE]
names(B) <- c('iso3',paste0('a',1:(ncol(B)-1)))
B <- B[,1:16,with=FALSE]

## NA handling
nacnt <- rowSums(is.na(as.matrix(B[,2:16,with=FALSE])))
comp <- nacnt>0 & nacnt<15
stna <- is.na(B$a1)
enna <- is.na(B$a15)
B[comp & enna]
B[comp & stna]

## for NA at the end, fill with last
enners <- which(comp & enna)
for(i in enners){
  tmp <- B[i,c(15-nacnt[i]+1),with=FALSE]
  rng <- (15-nacnt[i]+1):ncol(B)
  B[i,(rng):=tmp]
}
B[enners]

## for NA at start...
begs <- which(comp & stna)
for(i in begs){
  tmp <- B[i,c(nacnt[i]+2),with=FALSE]
  rng <- 2:(nacnt[i]+1)
  B[i,(rng):=tmp]
}
B[begs]

## merge
D <- merge(D,B,by='iso3',all.x = TRUE)

rmn <- function(x) round(mean(x,na.rm=TRUE))

K <- D[,lapply(.SD,rmn),.SDcols=(ncol(D)-15+1):ncol(D),by=g_whoregion]
setkey(K,g_whoregion)
nna <- c(is.na(D[,ncol(D),with=FALSE]))

for(i in nna){
  for(j in (ncol(D)-15+1):ncol(D)) D[i,(j):= K[ D[i,g_whoregion], (j-ncol(D)+ncol(K)), with=FALSE] ]
}
print(D[nna,(ncol(D)-15+1):ncol(D),with=FALSE],n=Inf)


## --- tidy notifications by age/sex
D[,totnotes:=c_newinc]
D[is.na(totnotes),totnotes:=0]

## males
D[,n_m_0_4:=newrel_m04]
D[,n_m_5_14:=newrel_m514]
D[,n_m_15_24:=newrel_m1524]
D[,n_m_25_34:=newrel_m2534]
D[,n_m_35_44:=newrel_m3544]
D[,n_m_45_54:=newrel_m4554]
D[,n_m_55_64:=newrel_m5564]
D[,n_m_65_Inf:=newrel_m65]

## females
D[,n_f_0_4:=newrel_f04]
D[,n_f_5_14:=newrel_f514]
D[,n_f_15_24:=newrel_f1524]
D[,n_f_25_34:=newrel_f2534]
D[,n_f_35_44:=newrel_f3544]
D[,n_f_45_54:=newrel_f4554]
D[,n_f_55_64:=newrel_f5564]
D[,n_f_65_Inf:=newrel_f65]


names(D)[(ncol(D)-16+1):ncol(D)]

## total from disagg
rnp <- D[,lapply(.SD,rmn),.SDcols=(ncol(D)-16+1):ncol(D),by=g_whoregion] #regional note pattern
setkey(rnp,g_whoregion)
thna <- rowSums(D[,(ncol(D)-16+1):ncol(D),with=FALSE])            #is there an NA?
tfd <- rowSums(D[,(ncol(D)-16+1):ncol(D),with=FALSE],na.rm=TRUE)  #totes w/o NA
tfd <- D$totnotes - tfd
tfd[tfd<0] <- 0

## - add in the remaining notifications following regional pattern
## build key
rtots <- rowSums(rnp[,2:ncol(rnp),with=FALSE]);names(rtots) <- rnp$g_whoregion
rnpat <- list()
for(reg in rnp$g_whoregion) rnpat[[reg]] <- rnp[reg,2:ncol(rnp),with=FALSE]/rtots[reg]

## loop through
for(j in (ncol(D)-16+1):ncol(D))        #set NAs to 0 here
  set(D,which(is.na(D[[j]])),j,0)

for(i in 1:nrow(D)){                    #allocate excess by regional pattern
  if(tfd[i]>0){
    addon <- round(tfd[i]*rnpat[[D[i,as.character(g_whoregion)]]]) #regional patterned addon
    ## print(addon)
    D[i,((ncol(D)-16+1):ncol(D)):=D[i,(ncol(D)-16+1):ncol(D),with=FALSE]+addon]
  }
}


## HIV/ART
D[,.(iso3,newrel_hivtest,newrel_hivpos,newrel_art)]
D[,.(iso3,newrel_hivpos/newrel_hivtest,newrel_art/newrel_hivpos)]
D[,hivprop:=newrel_hivpos/newrel_hivtest]
D[,artprop:=newrel_art/newrel_hivpos]
D[!is.finite(hivprop),artprop:=0]
D[!is.finite(artprop),artprop:=0]
D[!is.finite(hivprop),hivprop:=0]


## --- CDR calculations
## estimates
D[,.(iso3,e_inc_num_m014,e_inc_num_f014,n_m_0_4,n_m_5_14,n_f_0_4,n_f_5_14,e_inc_num_m014_hi-e_inc_num_m014_lo,e_inc_num_f014_hi-e_inc_num_f014_lo)]

## 04 CDR (split incidence evenly)
D[,cdr04:=(n_m_0_4+n_f_0_4)/((e_inc_num_m014 + e_inc_num_f014)/2)]
D[,cdr04ab:=(n_m_0_4+n_f_0_4)/((e_inc_num_m014 + e_inc_num_f014)/2)]
D[!is.finite(cdr04),cdr04:=0]
D[cdr04>1,cdr04:=1]
## TODO introduce an extra variance term for the 1/2 split?
D[,cdr04ab:=((1-cdr04)/cdr04)/((e_inc_num_m014_hi-e_inc_num_m014_lo)/(3.92*e_inc_num_m014))^2-1]
D[!is.finite(cdr04ab) | cdr04ab<0, cdr04ab:=0] #TODO NB CDR sampling needs to handle 0s


## 514 CDR (split incidence evenly)
D[,cdr514:=(n_m_5_14+n_f_5_14)/((e_inc_num_m014 + e_inc_num_f014)/2)]
D[,cdr514ab:=(n_m_5_14+n_f_5_14)/((e_inc_num_m014 + e_inc_num_f014)/2)]
D[!is.finite(cdr514),cdr514:=0]
D[cdr514>1,cdr514:=1]
D[,cdr514ab:=((1-cdr514)/cdr514)/((e_inc_num_m014_hi-e_inc_num_m014_lo)/(3.92*e_inc_num_m014))^2-1]
D[!is.finite(cdr514ab) | cdr514ab<0, cdr514ab:=0] 


## --- restrict

D <- D[,.(iso3,country,g_whoregion,LAT,
          a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13,a14,a15, #BCG by age
          n_m_0_4,n_m_5_14,n_m_15_24,n_m_25_34,n_m_35_44,n_m_45_54,n_m_55_64,n_m_65_Inf,
          n_f_0_4,n_f_5_14,n_f_15_24,n_f_25_34,n_f_35_44,n_f_45_54,n_f_55_64,n_f_65_Inf,
          hivprop,artprop,cdr04,cdr04ab,cdr514,cdr514ab)]
D
save(D,file='data/D.Rdata')
