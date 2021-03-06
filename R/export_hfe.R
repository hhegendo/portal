#!/usr/bin/env Rscript

"Export to CSV daily HFE kpi's.

Usage: export_hfe [-h]

  -h --help             show this help text
" -> doc

suppressMessages(library(docopt))

# retrieve the command-line arguments
opts <- docopt(doc)


usr <- Sys.getenv("PRU_TEST_USR")
pwd <- Sys.getenv("PRU_TEST_PWD")
dbn <- Sys.getenv("PRU_TEST_DBNAME")

if (usr == "") {
  cat("Error: you should at least set your DB user via PRU_TEST_USR")
  q(status = -1)
}

suppressMessages(library('ROracle'))
suppressMessages(library(dplyr))
suppressMessages(library(readr))


# NOTE: to be set before you create your ROracle connection!
# See http://www.oralytics.com/2015/05/r-roracle-and-oracle-date-formats_27.html
tz <- "UDT"
Sys.setenv("TZ" = tz)
Sys.setenv("ORA_SDTZ" = "UTC")

drv <- dbDriver("Oracle")
con <- dbConnect(drv, usr, pwd, dbname = dbn)

sqlq <- "WITH SD AS (SELECT CAST ('01-jan-2014' AS DATE) START_DATE FROM DUAL)
SELECT EXTRACT (YEAR FROM entry_date) YEAR
,        EXTRACT (MONTH FROM entry_date) MONTH_NUM
,        TO_CHAR (ENTRY_DATE, 'MON') MONTH_MON
,        ENTRY_DATE
,        ENTITY_NAME
,        ENTITY_TYPE
,        MODEL_TYPE AS TYPE_MODEL
,        FLOWN_KM AS DIST_FLOWN_KM
,        round(DIRECT_KM, 2) AS DIST_DIRECT_KM
,        round(ACHIEVED_KM, 2) AS DIST_ACHIEVED_KM
FROM PRUTEST.HFE_DAILY JOIN PRUTEST.DSH_BRIDGE_NAMES USING (MES_AREA)
WHERE ENTRY_DATE BETWEEN (SELECT start_date FROM SD)
AND (SELECT MAX (TRUNC (ENTRY_DATE + 1, 'MON') - 1)
END_DAY
FROM SD, HFE_DAILY
WHERE ENTRY_DATE >= START_DATE)
AND MODEL_TYPE IN ('FTFM', 'CPF')
ORDER BY 4, 5, 7"


query <- sqlq
flt <- dbSendQuery(con, query)
data <- fetch(flt, n = -1) 

dbDisconnect(con)
Sys.unsetenv("TZ")
Sys.unsetenv("ORA_SDTZ")

s <- function(df, ftype) {
  y <- unique(df$YEAR)
  write_csv(df, here::here("static", "download", "csv", stringr::str_c("hfe_", y, ".csv.bz2")), na = "")
  df
}


data %>%
  group_by(YEAR) %>% 
  do(s(.))
