
#############################################
## Marchenko-Pastur based matrix filtering ##
#############################################
## Following Bouchaud 2004 and Gatheral 2008
##'@export
MPfilter <- function(shrinkEst, ...){

    if(class(shrinkEst) != "CMEshrinkEst")
        stop("data should be CMEshrinkEst object")

    ## Retrieving returns
    R <- shrinkEst$smoothData
    ## retrieving correlation
    cov <- if(is.null(shrinkEst$shrunkScatter))
        shrinkEst$scatter
    else
        shrinkEst$shrunkScatter

    ## checking if the matrix is correlation or covariance
    corr <- shrinkEst$corr
    ## Filtering correlation Matrix
    filteredObj <- .FilterMP(R, cov, corr, ...)

    return(filteredObj)

}
.FilterMP <- function(R,
                      cov,
                      corr,
                      fit.type = "MDE",
                      initial.points = 100,
                      exclude.market = FALSE,
                      norm.meth = "partial",
                      breaks = "FD",...) {

    Q <- GetQ(R)
    if(!corr) cov <- cov2cor(cov) 
    lambdas <- eigen(cov, symmetric = TRUE)
    eigVals <- lambdas$values
    eigVecs <- lambdas$vectors

    ## Getting empirical EigenValues density
    ## Should also try with kernel estimators
    eigHist <- hist(eigVals, plot = FALSE, breaks = breaks)
    ## Fitting EigenValues density.. this needs work...MLE optimization is difficult
    if(!(fit.type %in% c("analogic", "MDE")))
        stop("Unrecognized Fit type")
    
    if(fit.type == "MDE") {
        marpasEsts <- .FitEigDensMDE(eigVals, Q, exclude.market, initial.points, ...)
    } 
    
    if(fit.type == "analogic"){
        marpasEsts <- .FitEigDensAnalogic(eigVals, Q, ...)
    }
    
    fitSigma <- marpasEsts[1]
    fitQ <- marpasEsts[2]

    lambdaMax <- marpasEig(fitSigma, fitQ)[2]

    ## Flatening Noisy egeinvalues
    noiseIdx <- (eigVals <= lambdaMax)
    fEigVals <- eigVals
    fEigVals[noiseIdx] <- 1
    ## Renormalizing
    M <- length(eigVals)
    if(norm.meth == "full") {
    ## Renormalizing method I: All eigenvalues
        fEigVals <- fEigVals * 1/mean(fEigVals)
    } else {
    ## Renormalizing method II: only filtered EigenVals
        fEigVals[noiseIdx] <- mean(eigVals[noiseIdx])
    }
    
    ## Reforming correlation
    filteredCorr <- eigVecs %*% diag(fEigVals) %*% t(eigVecs)
    ## reforming normalization
    diag(filteredCorr) <- rep(1, M)
    ## passing all relevant parameters
    filteredScatter <- if(corr) filteredCorr else corr2cov(filteredCorr, R)
    filteredEstim <- list(filteredScatter = filteredScatter,
                          filterEstim = list(eigVals = eigVals,
                              eigVecs = eigVecs,
                              noiseEigVecs = eigVecs[, seq(1, M)[noiseIdx]],
                              noiseEigVals = eigVals[noiseIdx],
                              signalEigVecs = eigVecs[, seq(1, M)[!noiseIdx]],
                              signalEigVals = eigVals[!noiseIdx],
                              eigHist = eigHist,
                              mpEstimates = marpasEsts,
                              lambdaMax = lambdaMax))

    return(filteredEstim)

}
##'@import nls2
.FitEigDensMDE <- function(eigVals, Q, exclude.market = FALSE, initial.points = 100, ...) {
  ## Fits the Marchenko-Pastur distribution using Cramer-von-Mises Criterion
  ## this allows to bypass the addition of an additional statistical error coming
  ## from the estimation of the density. This come at the price of statistical efficiency.
  ## The process is in three steps. First the analogic fit is called and used as a starting point.
  ## If it fails. Then a number of random starting points are used as intial points and the estimator
  ## with the lowest CvM statistic is returned. 
  
  if(exclude.market) {
    xdata <- eigVals[-1]
  } else {
    xdata <- eigVals
  }
  
  targets <- ecdf(xdata)(xdata)
  objective <- targets~pmarpas(xdata, sigma, Q)
  lower <- c(0, 0)
  
  mpFit <- function(X) nls2(objective, 
                            lower = lower, 
                            algorithm = "port", 
                            start = list(sigma = X[1], Q = X[2]))
  
  tryCatch({
    start <- .FitEigDensAnalogic(eigVals, Q)
    estimation <- mpFit(start)},
           error = function(c) {
             message("Combined estimation approach failed.")
             message(c)
             message(sprintf("Starting again with %s initial random points", initial.points))
             start <- matrix(c(runif(initial.points, 0.05, 0.95),
                               runif(initial.points, 0.05, Q * 2)),
                             ncol = 2)
             estimation <- mpFit(start)
           })
  estimates <- coef(estimation)

  return(estimates)  
} 


.FitEigDensAnalogic <- function(eigVals, Q, ...){
    ## Adjusted analogic estimate following bouchaud 2000.
    ## The idea is to substract the market eigenValue of the explained variance

    estimates <- c(sqrt(1 - max(eigVals)/length(eigVals)), Q)
    names(estimates) <- c("sigmaA", "QA")
    return(estimates)
}
