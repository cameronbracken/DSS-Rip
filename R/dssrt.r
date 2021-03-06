## DSS - R interface project
## Evan Heisman

#' initialize.dssrip Starts JVM with configuration for DSS-Vue's jar and dll files.
#'
#'Starts JVM with parameters required to use HEC's jar files.
#' 
#' as.package is an experimental parameter for calling this as part of the onLoad function as part
#'   of the DSS-Rip package.  This is the prefered method for an R package, but not yet functional
#'   for this.  The best practice is to load the DSS-Rip package, and call initialize.dssrip with
#'   as.package=FALSE, the default value.  Either the 'nativeLibrary' parameter for .jpackage, or
#'   as a dyn.load, would be the place to load javaHeclib.dll, but rather than distribute it with 
#'   this R package, the user should obtain it from an install of HEC-DSSVue.  Further reasons to 
#'   use .jinit include being able to initialize the JVM in the same manner as HEC-DSSVue would, 
#'   adding the appropriate jars and DLLs as start up options.
#' 
#' @param as.package If true, uses .jpackage instead of .jinit for better encapsulation of module. (Buggy!)
#' @param dss_location Specify location of DSSVue libraries if not in default location.
#' @param platform Specify platform, used in determining default DSS location.
#' @param quietDSS - don't show 'Z' messages during opening, reading, and writing to a file.  Experimental.
#' @param parameters Options string to pass to JVM.
#' @return JVM initialization status - 0 if successful, positive for partial initialization, negative for failure.  See ?.jinit
#' @note NOTE
#' @author Evan Heisman
#' @export 
initialize.dssrip = function(pkgname=NULL, lib.loc,
                             dss_location=getOption("dss_location"), 
                             dss_jre=getOption("dss_jre_location"),
                             platform=NULL, quietDSS=F, verboseLib=F, parameters=NULL, ...){
  ## parameters examples: '-Xmx2g -Xms1g' to set up memory requirements for JVM to 2g heap and 1g stack.
  
  ## TODO:  Add check if DSSRip is already initialized, exit function and return nothing 
  ##        if not "force.reinit=T" with warning message
  
  if(is.null(platform)){
    platform = tolower(Sys.info()[["sysname"]])
  }
  path.sep = "/"
  library.ext = ".so"
  if(platform == "windows"){
    path.sep = "\\"
    library.ext = ".dll"
  }
  
  ## Set JRE location
  if(!is.null(dss_jre)){
    Sys.setenv(JAVA_HOME=dss_jre)
  } #else {
  #   if(version$arch=="x86_64"){
  #     Sys.setenv(JAVA_HOME="")
  #   }
  # }
  if(verboseLib) packageStartupMessage(sprintf("JRE location is %s\n", Sys.getenv("JAVA_HOME")))
  
  ## Set DSS location
  if(is.null(dss_location)){
    if(platform == "windows"){
      dss_location = paste0(Sys.getenv("ProgramFiles(x86)"), path.sep, "HEC", path.sep, "HEC-DSSVue")
    } else {
      dss_location = Sys.getenv("DSS_HOME")
    }
  }
  if(verboseLib) packageStartupMessage(sprintf("DSS Location is %s\n", dss_location))
  
  jars = paste0(dss_location, path.sep, "jar", path.sep, c("hec", "heclib", "rma", "hecData"), ".jar")
  require(rJava)
  
  if(is.null(pkgname)){ ## Loading outside of onLoad function
    require(rJava)
    require(stringr)
    require(xts)
    libs = paste0("-Djava.library.path=", dss_location, path.sep, "lib", path.sep)
    if(verboseLib) packageStartupMessage(str_trim(paste(libs,parameters)))
    
    #LOGS='-Dlogfile.directory="%APPDATA%/HEC/HEC-DSSVue/logs" -DLOGFILE="%APPDATA%/HEC/HEC-DSSVUE/logs/HEC-DSSVue.log" -DCACHE_DIR="%APPDATA%/HEC/HEC-DSSVue/pythonCache"'
    #MEMPARAMS="-ms256M -mx2000M"
    .jinit(classpath=jars, parameters=str_trim(paste(libs,parameters)), ...)
    #.jaddClassPath(jars)
    if(verboseLib){
      for(jpath in .jclassPath()){
        packageStartupMessage(jpath)
      }
    }
  } else {
    libdir = paste0(dss_location, "lib", path.sep)
    #dyn.load(lib)
    .jpackage(pkgname, lib.loc, morePaths=jars)
    ## Add javaHeclib.dll to loaded libraries.
    #.jcall("java/lang/System", returnSig='V', method="load", lib)
    Sys.setenv(PATH=paste0(Sys.getenv("PATH"), ";", dss_location, ";", libdir))
    lib = paste0(libdir, "javaHeclib.dll")
    .jcall("java/lang/System", returnSig='V', method="load", lib)
    .jcall("java/lang/System", returnSig='V', method="loadLibrary", "javaHeclib")
  }
  if(quietDSS){
    ## None of the below work
    ## TODO:  Try this with a temporary file instead of NULL
    #opt 1
    #.jcall("java/lang/System", returnSig='V', method="setOut", .jnull())
    #opt 2
    #nullPrintStream = .jnew("java/lang/System/PrintStream", paste0(dss_location, path.sep, "dssrip_temp.txt"))
    #.jcall("java/lang/System", returnSig='V', method="setOut", nullPrintStream)
    #opt 3: See heclib programmers manual for this trick.
    #.jcall("hec/heclib/util/Heclib", returnSig='V', method="zset", 'MLVL', ' ', 0)
  }
}

## CONSTANTS
TSC_TYPES = c("INST-VAL", "INST-CUM", "PER-AVER", "PER-CUM")

minutes = c(1,2,3,4,5,6,10,12,15,20,30)
hours = c(1,2,3,4,6,8,12)
## Irregular appears to have interval of 0, not -1
TSC_INTERVALS = c(minutes, 60*hours, 60*24*c(1,7,10,15,30,365), rep(0,5))
names(TSC_INTERVALS) = c(paste0(minutes, "MIN"),
                         paste0(hours, "HOUR"),
                         "1DAY","1WEEK","TRI-MONTH","SEMI-MONTH", "1MON","1YEAR",
                         paste0("IR-",c("DAY","MON","YEAR","DECADE","CENTURY")))


## Only useful when working in package directory!
openTestFile <- function(){
  opendss("./extdata/test.dss")
}




## Convenience function for viewing a DSS file.  DOES NOT WORK
newDSSVueWindow <- function(file=NULL){
  mw = .jcall("hec/dssgui/ListSelection",
              returnSig="Lhec/dssgui/ListSelection;",
              method="createMainWindow")
  mw = .jnew("hec/dssgui/ListSelection")
  mw.show()
  if(!is.null(file)){
    mw.openDSSFile(file)
  }
  return(mw)
}

## used to help with introspection on Java Objects
sigConversions = list(boolean="Z", byte="B", char="C", 
                      short="T", void="V", int="I", 
                      long="J", float="F", double="D")
fieldsDF <- function(jObject){
  require(plyr)
  fields = ldply(.jfields(jObject), function(x) data.frame(FULLNAME=x, 
                                                           SHORTNAME=last(str_split(x, fixed("."))[[1]]), 
                                                           CLASS=str_split(x, fixed(" "))[[1]][2], 
                                                           stringsAsFactors=FALSE))
  fields$SIGNATURE = llply(fields$CLASS, function(x){
    out = str_replace_all(x, "\\[\\]", "")
    if(out %in% names(sigConversions)){
      out = sigConversions[[out]]
    } else {
      out = paste0("L", str_replace_all(out, fixed("."), "/"), ";")
    }
    ## If vector, add [
    if(grepl(fixed("\\[\\]"), x)){
      out = paste0("[", out)
    }
    return(out)
  })
  return(fields)
}

#' opendss Opens a DSS file.
#' 
#' Returns a DSS file object.
#' 
#' Returns an object from the java class 'hec.heclib.dss.HecDss' used for reading and writing to
#' the file located at filename.  Don't forget to call myFile$close() or myFile$done() when 
#' finished.
#' 
#' @param filename Location of DSS file to open.
#' @return 'hec.heclib.dss.HecDss' object of DSS file at filename
#' @note NOTE
#' @author Evan Heisman
#' @export 
opendss <- function(filename, warnIfNew=TRUE, stopIfNew=FALSE){
  if(!file.exists(filename) & (warnIfNew | stopIfNew)){
    message = sprintf("DSS: %s does not exist.  Creating file.", filename)
    errFunc = warning
    if(stopIfNew){
      errFunc = stop
    }
    errFunc(message)
  }
	dssFile = .jcall("hec/heclib/dss/HecDss", "Lhec/heclib/dss/HecDss;", method="open", filename)
  return(dssFile)
}

## Deprecated function - DO NOT USE.
OLDgetPaths <- function(file, ...){
  warning("This function calls the getCatalogedPathnames function and can take some time.")
  warning("OLDgetPaths is deprecated.  Please replace.")

	paths = file$getCatalogedPathnames(...)
	n = paths$size()
  if(n==0){
    return(list())
  }
	myList = character()
	for(i in 1:n){
		myList[[i]] = paths$get(as.integer(i-1))
	}
	return(myList)
}

#' getAllPaths Returns all paths in DSS file.
#' 
#' Returns a list of all DSS paths in a file, useful for searching for data.
#' 
#' Long Description
#' 
#' @param file a DSS file reference from opendss
#' @param rebuild Set to true to force rebuilding the DSS catalog file (.dsc).
#' @return a character vector of DSS paths in the file.
#' @note NOTE
#' @author Evan Heisman
#' @export 
getAllPaths <- function(file, rebuild=FALSE){
  require(stringr)
  dss_fn = file$getFilename()
  dsc_fn = sprintf('%s.dsc',tools:::file_path_sans_ext(dss_fn))
  dsc_exists = file.exists(dsc_fn)

  dsc_mtime = file.info(dsc_fn)$mtime
  dss_mtime = file.info(dss_fn)$mtime
    # this will force the recreation of the catalog file if:
    # 1. it does not exist
    # 2. it is older than the dss file
    # 3. a rebuild is forced with rebuild=TRUE
  if(!isTRUE(dsc_exists) | isTRUE(dss_mtime > dsc_mtime) | isTRUE(rebuild))
    file$getCatalogedPathnames(TRUE)
  
  #meta = read.table(dsc_fn,skip=10,stringsAsFactors=FALSE)
  #paths = meta[,ncol(meta)]
  dsc = readLines(dsc_fn)
  paths = dsc[11:length(dsc)]
  paths = str_sub(paths,19,str_length(paths))  
  return(paths)
}

#' getPaths Search DSS paths by filter.
#' 
#' Allows searching DSS paths similar to getCatalogedPathnames(searchPattern) in the Jython API.
#' 
#' Uses the pattern parameter to return a filtered list of paths.  The filter method is defined by 
#' the searchfunction parameter.
#' 
#' @param file DSS file reference
#' @param searchString Search string
#' @param searchFunction Filter function to use with search string
#' @return character vector of paths matching filter criteria.
#' @note NOTE
#' @author Evan Heisman
#' @export 
getPaths <- function(file, searchString="/*/*/*/*/*/*/", searchfunction=NULL, pattern=searchString, searchFunction=searchfunction, useRegex=FALSE){
  searchString = str_trim(searchString)
  if(is.null(searchFunction)){
    if(grepl(pattern=fixed("="), x=searchString)){
      searchFunction = pathByPartsWildcard
      if(useRegex){
        searchFunction = pathByPartsRegex
      }
    } else if(grepl(pattern="^/.*/.*/.*/.*/.*/.*/$", x=searchString)) {
      searchFunction = fullPathByWildcard
      if(useRegex){
        searchFunction = fullPathByRegex
      }
    } else{
      warning("No search function specified and could not be automatically selected.")
      searchFunction = nofilter
    }
  }
  paths = getAllPaths(file)
  if(!is.null(searchFunction)){
    paths = searchFunction(paths, searchString)
  }
  return(paths)
}

splitPattern <- function(pattern, to.regex=F){
  ## For use in the pathByParts searches
  if(!grepl(fixed("="), pattern)){
    warning(paste0("Bad pattern: ", pattern))
  }
  pattern.raw = str_split(pattern, "=")[[1]]
  keys = pattern.raw[1:(length(pattern.raw)-1)]
  keys = str_trim(substr(keys, str_length(keys)-1, str_length(keys)))
  values = pattern.raw[2:(length(pattern.raw))]
  values = str_trim(substr(values, 1, str_length(values)-c(rep(1,length(values)-1),0)))
  if(to.regex) values = glob2rx(values)
  values = as.list(values)
  names(values) = keys
  return(values)
}

## A template / placeholder filter function.
nofilter <- function(paths, pattern){
  return(paths)
}

#' fullPathByWildcard Search paths by wildcard.
#' 
#' Searches full paths by wildcard, e.g. "/A/B/C/*/*/F/"
#' 
#' Long Description
#'  
#' @return stuff
#' @note NOTE
#' @author Evan Heisman
#' @export 
fullPathByWildcard <- function(paths, pattern){
  return(fullPathByRegex(paths, glob2rx(pattern)))
}

#' pathByPartsWildcard Search paths by parts, using wildcards.
#' 
#' Searches path by individual parts, e.g. "A=*CREEK* C=FLOW"
#' 
#' Long Description
#' 
#' @return stuff
#' @note NOTE
#' @author Evan Heisman
#' @export 
pathByPartsWildcard <- function(paths, pattern){
  ## TODO:  Replace "@" in pattern with "*", to match HEC wildcard set
  return(pathByPartsRegex(paths, pattern.parts=splitPattern(pattern, to.regex=T)))
}

#' fullPathByRegex Search full paths with regex.
#' 
#' Searches full paths using regular expressions, e.g. "/A/B/C/.*/.*/F/"
#' 
#' Long Description
#' 
#' @return stuff
#' @note NOTE
#' @author Evan Heisman
#' @export 
fullPathByRegex <- function(paths, pattern){
  return(paths[grepl(pattern, paths)])
}

#' separatePathParts Separates path parts into dataframe.
#' 
#' useful function for writing filters
#' 
#' Long Description
#' 
#' @return data frame consisting of split path parts and full paths.
#' @note NOTE
#' @author Evan Heisman
#' @export 
separatePathParts <- function(paths){
  parts.df = data.frame(rbind(do.call(rbind, str_split(paths, fixed("/")))[,2:7]))
  colnames(parts.df) = toupper(letters[1:6])
  parts.df$PATH = paths
  return(parts.df)
}

#' pathByPartsRegex Search path by parts using regex.
#' 
#' Searches path by parts using regular expressions, e.g. "A=.*CREEK.* C=FLOW"
#' 
#' Long Description
#' 
#' @return stuff
#' @note NOTE
#' @author Evan Heisman
#' @export 
pathByPartsRegex <- function(paths, pattern, pattern.parts=NULL){
  parts.df = separatePathParts(paths)
  if(is.null(pattern.parts)){
    pattern.parts = splitPattern(pattern, to.regex=T)
  }
  parts.df$MATCH = T
  for(n in names(pattern.parts)){
    parts.df$MATCH = parts.df$MATCH & grepl(pattern.parts[[n]], parts.df[,n])
  }
  return(subset(parts.df, MATCH)$PATH)
}

treesearch <- function(paths, pattern){
  warning("treesearch not yet implemented")
  return(paths)
}

#' tsc.to.xts Converts Java TimeSeriesContainer objects into XTS time series objects.
#' 
#' convert time series container to XTS
#' 
#' Long Description
#' 
#' @return xts object from times and values in TSC.
#' @note NOTE
#' @author Evan Heisman
#' @export 
tsc.to.xts <- function(tsc, colnamesSource="parameter"){
 
  metadata = getMetadata(tsc, colnamesSource=colnamesSource)

  out = xts(tsc$values, order.by=as.POSIXct(tsc$times*60, origin="1899-12-31 00:00", tz="UTC"), dssMetadata= as.data.frame(metadata))
  colnames(out) = metadata[[colnamesSource]]
  
  return(out)
}

#' tsc.to.dt Converts Java TimeSeriesContainer objects to data.table objects.
#' 
#' convert time series container to data.table
#' 
#' Long Description
#' 
#' @return data.table object from times andvalues in TSC.
#' @note NOTE
#' @author Cameron Bracken
#' @export 
tsc.to.dt <- function(tsc, ...){

  require(data.table)

  times = as.POSIXct(tsc$times*60, origin="1899-12-31 00:00", tz="UTC")
  values = tsc$values
  units = tsc$units
  if(length(values)==0)units = character(0)

  out = data.table(datetime=times,value=values,units=units)
  setkey(out, "datetime")
  
  attr(out,'dssMetadata') = as.data.frame(getMetadata(tsc))

  return(out)
}



#' getMetadata get metadata from a tsc java object 
#' 
#' get metadata from a tsc java object 
#' 
#' Long Description
#' 
#' @return data.frame containing metadata 
#' @note NOTE
#' @author Evan Heisman
#' @export 
getMetadata <- function(tsc, colnamesSource="parameter"){

  require(stringr)
  require(plyr)

  tscFieldsDF = get("tscFieldsDF", envir=hecJavaObjectsDB)
  metadata = dlply(tscFieldsDF, "SHORTNAME", function(df){
    #cat(sprintf("%s\t%s\t%s\n", df$FULLNAME, df$SHORTNAME, df$SIGNATURE))
    if(df$SHORTNAME %in% c("values", "times", "modified", "quality")) {
      return()
    }
    val = .jfield(tsc, name=df$SHORTNAME, sig=as.character(df$SIGNATURE))
    if(.jnull() == val){
      return(NA)
    }
    return(val)
  })

  metadata = metadata[!(names(metadata) %in% c("values", "times", "modified", "quality"))]

  return(metadata)
}


#' xts.to.tsc Converts xts objects to Java TimeSeriesContainer objects.
#' 
#' Converts xts objects to TimeSeriesContainers for writing to DSS files.
#' 
#' Long Description
#' 
#' @return java TimeSeriesContainer.
#' @note NOTE
#' @author Evan Heisman
#' @export 
xts.to.tsc <- function(tsObject, ..., protoTSC=NULL){
  ## Fill empty time slots in tsObject
  times = index(tsObject)
  fullTimes = seq(min(times), max(times), by=deltat(tsObject))
  blankTimes = fullTimes[!(fullTimes %in% times)]
  empties = xts(rep(J("hec/script/Constants")$UNDEFINED, length(blankTimes)), order.by=blankTimes)
  colnames(empties) = colnames(tsObject)
  tsObject = rbind(tsObject, empties)
  
  ## Configure slots for TimeSeriesContainer object
  times = as.integer(index(tsObject))/60 + 2209075200/60
  values = as.numeric(tsObject)
  metadata = list(
    times = .jarray(as.integer(times), contents.class="java/lang/Integer"), #, as.integer(times)), new.class="java/lang/Integer")
    values = .jarray(values, contents.class="java/lang/Double"),
    endTime = max(times),
    startTime = min(times),
    interval = deltat(tsObject)/60,
    numberValues = length(values),
    storedAsdoubles = TRUE,
    modified=FALSE,
    fileName="",
    ...
  )
  dssMetadata = attr(tsObject, "dssMetadata")
  for(mdName in colnames(dssMetadata)){
    if(mdName %in% names(metadata)){
      next
    }
    #if(any(dssMetadata[[mdName]] != first(dssMetadata[[mdName]]))){
    #  warning(sprintf("Not all metadata matches for %s", mdName))
    #}
    metadata[[mdName]] = first(dssMetadata[[mdName]])
  }
  ## TODO: pull from protoTSC if required
  
  ePart = list("1440"="1DAY", "60"="1HOUR", "15"="15MIN", "1"="1MIN")[[as.character(metadata$interval)]]
  dPart = paste0("01JAN", year(first(index(tsObject))))
  metadata$fullName = paste("", metadata$watershed, metadata$location, metadata$parameter, dPart, ePart, metadata$version, "", sep="/")
  tsc = .jnew("hec/io/TimeSeriesContainer")
  tscFieldsDF = get("tscFieldsDF", envir=hecJavaObjectsDB)
  for(n in names(metadata)){
    #print(sprintf("%s:", n))
    #print(metadata[[n]])
    writeVal = metadata[[n]]
    if(is.na(writeVal) | writeVal == ""){
      #print("Value is NA, not writing.")
      next
    }
    if(is.factor(writeVal)){
      writeVal = as.character(writeVal)
    }
    if(tscFieldsDF$CLASS[tscFieldsDF$SHORTNAME == n] %in% c("int")){
      #print("Converting to integer.")
      writeVal = as.integer(writeVal)
    }
    .jfield(tsc, n) = writeVal
  }
  return(tsc)
}


#' getTSC Get a TSC from a file and pathname as a XTS.
#' 
#' Skips intermediate step of getting TimeSeriesContainer object.
#' 
#' Long Description
#' 
#' @return xts from time series located at path in file.
#' @note NOTE
#' @author Evan Heisman
#' @export 
getTSC <- function(file, path, fullTSC=FALSE, ...){
  return(tsc.to.xts(file$get(path, fullTSC), ...))
}

#' getDT Get a TSC from a file and pathname as a data.table
#' 
#' short desc
#' 
#' Long Description
#' 
#' @return stuff
#' @note NOTE
#' @author Cameron Bracken
#' @export 
getDT <- function(file, path){
  return(tsc.to.dt(file$get(path)))
}

#' getFullTSC Get a full TSC, ignoring date parameters.
#' 
#' Gets paths, converts to XTS, and merges to one time series.
#' 
#' Warning - does not check that all paths are the same except for D part
#' 
#' @return merged xts of all times and values in time series matching paths.
#' @note NOTE
#' @author Evan Heisman
#' @export 
getFullTSC <- function(file, paths, ...){
  ## Accepts sets of paths or like getFullTSC, or single path. 
  if(length(paths) > 0){
    ## Check if all paths are identical, sans D part.
    pathdf = separatePathParts(paths)
    identicalPaths = apply(pathdf, 2, function(col) all(unique(col)==col))
    if(!all(identicalPaths[c("A", "B", "C", "E", "F")])){
      stop("Cannot create condensed pathname to pull!")
    }
  }
  return(getTSC(file, paths[1], fullTSC=TRUE))  
}

getLooseTSC <- function(file, paths, ...){
  tscList = list()
  for(p in paths){
    tscList[[p]] = getTSC(file, p, ...)
  }
  xtsOut = do.call(rbind.xts, tscList)
  xtsAttributes(xtsOut) = list(dssMetadata=do.call(rbind, lapply(tscList, function(x) attr(x, "dssMetadata"))))
  return(xtsOut)
}

#' getFullDT Get a full TSC as data.table, ignoring date parameters.
#' 
#' Gets paths, converts to data.table, and merges to one time series.
#' 
#' Long Description
#' 
#' @return merged data.tame of all times and values in the time series matching paths.
#' @note NOTE
#' @author Cameron Bracken
#' @export 
getFullDT <- function(file, paths, discard_empty = TRUE){
  require(data.table)
  
  dtList = list()
  for(p in paths){
    dt = getDT(file, p)
    if(nrow(dt) == 0 & isTRUE(discard_empty)) next else dtList[[p]] = dt
  }
  dtOut = do.call(rbind, dtList)
  attr(dtOut,'dssMetadata') = do.call(rbind, lapply(dtList, function(x) attr(x, "dssMetadata")))

  return(dtOut)
}

## PairedDataContainer functions

#' getColumnsByName Get a column from a PairedDataContainer object.
#' 
#' Gets a column from a paired data container by name.
#' 
#' Name of column must be exact or NA is returned.
#' 
#' @return vector of values from column.
#' @note NOTE
#' @author Evan Heisman
#' @export 
getColumnsByName <- function(file, pdc, column){
  if(class(file)=="character"){
    file = opendss(file)
  }
  if(class(pdc)=="character"){
    pdc = file$get(pdc)
  }
  if(class(column) != "character"){
    return(pdc$yOrdinates[column,])
  } else {
    if(!(column %in% pdc$labels)){
      warning(sprintf("No column named [%s] found in paired data container.", column))
      return(NA)
    }
    return(pdc$yOrdinates[which(pdc$labels == column),])
  }
}
