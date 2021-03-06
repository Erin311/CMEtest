##'@export
.MakeSmoothEst <- function(spec, data) {
    ## Smoothing object constructor
    ## spec is a smooth specificatification object
    ## data should be the data to smooth

    smoothFUN  <- spec$.passCall$fun # Getting function tocall
    smoothArgs <- spec$.passCall$funCall # Getting arguments
    smoothArgs[['data']] <- data # All functions will be wrapped such as
                                        # they can be called as data
                                        # plus something else.
                                        # Calling smoothing function
    smoothData <- if (smoothFUN == 'None') data else do.call(smoothFUN, smoothArgs)

#######################################
##     Constructing smoother object  ##
#######################################

    smoothEst <- list(data = data,
                      smoothData = smoothData,
                      .smoothSpec = spec)

                                        # Assigning class
    class(smoothEst) <- "CMEsmoothEst"

    return(smoothEst)

}
##'@import robust
##'@export
.MakeEstimEst <- function(spec, smoothEst) {
    ## Estimations constructors
    ## spec should be CMEestimSpec specification object
    ## smoothEst should be a smooth estimation object


    estimFUN  <- spec$.passCall$fun # Getting function to call
    estimArgs <- spec$.passCall$funCall # Getting arguments
    estimArgs[['data']] <- as.matrix(smoothEst$smoothData) # using smoothed data
                                        # Estimating covariance
    covEst <- if (estimFUN == 'None') NULL else do.call(estimFUN, estimArgs)

#########################################
##     Constructing Estimation object  ##
#########################################
    estimEst <- smoothEst
    estimEst[['loc']] <- covEst$center
    estimEst[['scatter']] <- covEst$cov # Need to handle the case where the
                                        # object is not of class
                                        # robust
    estimEst[['corr']] <- covEst$corr
    estimEst[['.estSpec']] <- spec
    estimEst[['.estEstim']] <- covEst

                                        # Assigning class
    class(estimEst) <- "CMEestimEst"

    return(estimEst)

}
##'@export
.MakeShrinkEst <- function(spec, estimEst){
    ## Shrinkage constructor
    ## spec should be shrinkage specification object
    ## estimEst should be an estimation object



    shrinkFUN  <- spec$.passCall$fun # Getting function to call
    shrinkArgs <- spec$.passCall$funCall # Getting arguments

    shrunkCovEst <- if (shrinkFUN == 'None') NULL else do.call(shrinkFUN, shrinkArgs)

##################################################
##     Constructing shrinker estimation object  ##
##################################################
    shrinkEst <- estimEst
    shrinkEst[['shrunkScatter']] <- shrunkCovEst
    shrinkEst[['.shrinkSpec']] <- spec
                                        # Assilass
    class(shrinkEst) <- "CMEshrinkEst"

    return(shrinkEst)
}

##'@export
.MakeFilterEst <- function(spec, shrinkEst){
    ## Shrinkage constructor
    ## spec should be shrinkage specification object
    ## estimEst should be an estimation object



    filterFUN  <- spec$.passCall$fun # Getting function to call
    filterArgs <- spec$.passCall$funCall # Getting arguments
    ## Passing shrinkEstimators along
    filterArgs[['shrinkEst']] <- shrinkEst

    filteredEst <- if (filterFUN == 'None') NULL else do.call(filterFUN, filterArgs)

###################################################
##     Constructing filtering estimation object  ##
###################################################

    filterEst <- shrinkEst
    filterEst[['filteredScatter']] <- filteredEst$filteredScatter
    filterEst[['.filterEstim']] <- filteredEst$filterEstim
    filterEst[['.filterSpec']] <- spec
    ## Assigning Class
    class(filterEst) <- "CMEfilterEst"

    return(filterEst)
}
