# ******************************************************************************
#  Program/Macro:  umchklog.R
#  Lang/Vers:      R/4.2.2
#  Author:         Teckla Akinyi
#  Date:           Jan 2023
#  Description:    Check log files in a given directory
#  Output:         A filtered xlsx file containing information from SAS and/or logrx log files.
#  Remark:         Will print files read from specified dir and warning message when overwriting any of the sheets in workbook
#
#  Parameters:     logdir: path to the input directory, default to the working directory
#                  select_file: opt - default to all logs in directory, for user-selection of log file to be checked only one log at a time,
#                  sas_file_ID:  identifiers of a sas file, typically a string in header of program that also prints to log        
#                  sas_key: Key words that user wants to be extracted from SAS files. Only optional if no sas logs are expected.
#                             The list is extensible for user to add other key words
#                  add_r_sxtn: opt - default is null. Used for R files to extract other sections 
#                               beyond Errors, Warnings & Messages e.g section with masked function. 
#                               If not specified or left at default then only errors, warnings & messages are extracted
#                  Sheet_nm: opt - ID to be used as sheetname can be file name or studyid if looking through different study dirs
#                             Default is "sheet name"
#                  outnm: name for the excel workbook. Can specify full path or just name, if name only then defaults to wdir
#
#  Sample Call:
#   parselogs(logdir = "C:/Users/TAkinyi/Desktop/Yangu/phuse23",
#             sas_file_ID =  c("SAS Institute Inc|SAS program|SAS Version"),
#             sas_key = c("WARNING|ERROR|UNINITIALIZED|INTERRUPTION"),
#             Sheet_nm = "STUDY_ABC123",
#             outnm ="Compound123.xlsx")
# *******************************************************************************
library(magrittr)
library(dplyr) 
library(tidyr) 
library(data.table) #fread
library(stringi)
library(writexl)
library(openxlsx)

parselogs <- function(logdir,
                      select_file="*.log$",
                      sas_file_ID ,
                      sas_key=NULL,
                      add_r_sxtn=NULL,
                      Sheet_nm = "sheet name",
                      outnm){
  setwd(logdir)
  logs <- list.files(logdir,
                     pattern = select_file, 
                     full.names = F,
                     ignore.case = T)
  
  #Checks directory for log files and returns warning if not found, or prints name of files if found
  if (length(logs) == 0) {
    warning(stri_c("No log files in",getwd(),sep = " "))
  } else {
    message(stri_c("Log files in ",getwd(),sep = " "))
    print(logs)
  }
  
  
  idlog <- function(f) {
    lines <- readLines(f, skipNul = T, warn = F)[1:15] %>%
             stri_detect_regex(sas_file_ID,
                               case_insensitive = T,
                               max_count = 1)
    SAS_ID_Lines <- which(lines == T)
    
    #identifies files from Sas using the sas_file_id argument and extracts the key words from sas_key argument
    if (length(SAS_ID_Lines) >= 1){
        re <- paste0(sas_key)
        lines_sas <- readLines(f, skipNul = T, warn = F)
        lines4log_sas <- fread(paste0(stri_subset(lines_sas,
                                                  regex = sas_key,
                                                  case_insensitive = T),
                                      collapse = "\n"),
                               header = FALSE,
                               sep = "\n",
                               colClasses = "character",
                               blank.lines.skip = T)
        names(lines4log_sas)[1] <- make.names(f)
        return(lines4log_sas)
      
    } else if (length(SAS_ID_Lines) == 0 | is.null(sas_key)){
      lines_R <- readLines(f)
        
        #Line markers for errors
        name <- "Error: "
        starts <- which(grepl("^Errors:", lines_R, ignore.case = T)) + 1
        nxt <- which(grepl("^Warnings:", lines_R, ignore.case = T))
        nxt2 <- which(nxt>starts, arr.ind = TRUE)[1]
        ends <- nxt[nxt2]-2
        markers1 <- data.frame(name, starts, ends)
        
        #line markers for warnings
        name <- "Warning: "
        starts <- which(grepl("^Warnings:", lines_R, ignore.case = T)) + 1L
        nxt <- which(grepl("^-{5}", lines_R, ignore.case = T))
        nxt2 <- which(nxt>starts, arr.ind = TRUE)[1]
        ends <- nxt[nxt2] - 1L
        markers2 <- data.frame(name, starts, ends)
        
        
        #line markers for messages
        name <- "Messages: "
        starts <- which(grepl("^Messages:", lines_R, ignore.case = T)) + 1L
        nxt <- which(grepl("^Output:", lines_R, ignore.case = T))
        nxt2 <- which(nxt>starts, arr.ind = TRUE)[1]
        ends <- nxt[nxt2] - 1L
        markers3 <- data.frame(name, starts, ends)
        
        #final line markers
        markers <- rbind(markers1, markers2, markers3)
        
        if (is.null(add_r_sxtn)){
          print(paste0("Extracting only Errors, Warning & Messages from logrx files: ", f))
        } else {
          otherstuff<<- add_r_sxtn
          for (i in 1:length(otherstuff)){
            name <- paste0(add_r_sxtn[i],": ")
            starts <- which(grepl(add_r_sxtn[i], lines_R, ignore.case = T))+2L
            nxt <- which(grepl("^-{10}", lines_R))
            nxt2 <- which(nxt>starts, arr.ind = TRUE)[1] 
            ends <- nxt[nxt2]-1L
            markers999 <- data.frame(name,starts,ends)
            markers <- rbind(markers,markers999)
          }
        }
        
        lines4log_R <- data.frame() #initialize empty df to populate with parse R lines
        for (i in 1:nrow(markers)){
          
          if (markers[i, 2] == markers[i, 3]) {
            lines4log_R_a <- as.data.frame(paste0(markers[i, 1],lines_R[markers[i, 2]]))
            
            names(lines4log_R_a)[1] <- make.names(f)
            lines4log_R <- rbind(lines4log_R, lines4log_R_a)
          } else {
            lines4log_R_a <- fread(paste0(markers[i, 1] ,(lines_R[markers[i, 2]:markers[i, 3]]), collapse = "\n"),
                                   header = FALSE,
                                   sep = "\n",
                                   colClasses = "character",
                                   blank.lines.skip = T)
            names(lines4log_R_a)[1] <- make.names(f)
            lines4log_R <- rbind(lines4log_R, lines4log_R_a)
          }
        }
        return(lines4log_R)
    }
  }
  
  #implement the function to all log files read in and put in a dataframe
  logfile <<- lapply(logs, idlog) %>% 
    bind_rows() %>% 
    pivot_longer(everything()) %>%
    na.omit() %>% 
    mutate(category = case_when(stri_detect_regex(value,"ERROR", case_insensitive=T) == T ~ "Error",
                                stri_detect_regex(value,"WARNING", case_insensitive=T) == T ~ "Warning",
                                TRUE ~ "Other"),
           categoryn = case_when(stri_detect_regex(value,"ERROR", case_insensitive=T) == T ~ 1,
                                stri_detect_regex(value,"WARNING", case_insensitive=T) == T ~ 2,
                                TRUE ~ 3)
           ) %>% 
    arrange(name,categoryn) %>% 
    select(name, category, value) 

 #saving file to excel: checks if the sheet exists and over-writes while printing warning message to console
  # if sheet doesn't exist a workbook is initiated and sheet with sheetname written out
  if (file.exists(outnm)==T) {
    wb <- loadWorkbook(outnm)
    shts<-getSheetNames(outnm)
    shtxst<-stri_detect_regex(shts,Sheet_nm) 
    if (any(shtxst)){
      warning(paste0(Sheet_nm," already in workbook: Overwriting Sheet - ", Sheet_nm))
      removeWorksheet(wb,Sheet_nm)
      addWorksheet(wb,Sheet_nm)
      writeData(wb,Sheet_nm,logfile, withFilter = T)
      setColWidths(wb, Sheet_nm, cols = 1:3, widths = "auto")
      saveWorkbook(wb,outnm,overwrite = TRUE)
    } else {
      addWorksheet(wb,Sheet_nm)
      writeData(wb,Sheet_nm,logfile, withFilter = T)
      setColWidths(wb, Sheet_nm, cols = 1:3, widths = "auto")
      saveWorkbook(wb,outnm,overwrite = TRUE)
    }
  } else {
    wb <- createWorkbook()
    addWorksheet(wb, Sheet_nm)
    writeData(wb, Sheet_nm, logfile, withFilter = TRUE)
    setColWidths(wb, Sheet_nm, cols = 1:3, widths = "auto")
    saveWorkbook(wb, file = outnm, overwrite = TRUE)
  }
}

