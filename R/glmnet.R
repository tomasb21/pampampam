#' fit a GLM with lasso or elasticnet regularization
#'
#' Fit a generalized linear model via penalized maximum likelihood.  The
#' regularization path is computed for the lasso or elasticnet penalty at a
#' grid of values for the regularization parameter lambda. Can deal with all
#' shapes of data, including very large sparse data matrices. Fits linear,
#' logistic and multinomial, poisson, and Cox regression models.
#'
#' The sequence of models implied by \code{lambda} is fit by coordinate
#' descent. For \code{family="gaussian"} this is the lasso sequence if
#' \code{alpha=1}, else it is the elasticnet sequence.
#'
#' The objective function for \code{"gaussian"} is \deqn{1/2 RSS/nobs +
#' \lambda*penalty,} and for the other models it is \deqn{-loglik/nobs +
#' \lambda*penalty.} Note also that for \code{"gaussian"}, \code{glmnet}
#' standardizes y to have unit variance (using 1/n rather than 1/(n-1) formula)
#' before computing its lambda sequence (and then unstandardizes the resulting
#' coefficients); if you wish to reproduce/compare results with other software,
#' best to supply a standardized y. The coefficients for any predictor
#' variables with zero variance are set to zero for all values of lambda.
#'
#' ## Details on `family` option
#'
#' From version 4.0 onwards, glmnet supports both the original built-in families,
#' as well as \emph{any} family object as used by `stats:glm()`.
#' This opens the door to a wide variety of additional models. For example
#' `family=binomial(link=cloglog)` or `family=negative.binomial(theta=1.5)` (from the MASS library).
#' Note that the code runs faster for the built-in families.
#'
#' The built in families are specifed via a character string. For all families,
#' the object produced is a lasso or elasticnet regularization path for fitting the
#' generalized linear regression paths, by maximizing the appropriate penalized
#' log-likelihood (partial likelihood for the "cox" model). Sometimes the
#' sequence is truncated before \code{nlambda} values of \code{lambda} have
#' been used, because of instabilities in the inverse link functions near a
#' saturated fit. \code{glmnet(...,family="binomial")} fits a traditional
#' logistic regression model for the log-odds.
#' \code{glmnet(...,family="multinomial")} fits a symmetric multinomial model,
#' where each class is represented by a linear model (on the log-scale). The
#' penalties take care of redundancies. A two-class \code{"multinomial"} model
#' will produce the same fit as the corresponding \code{"binomial"} model,
#' except the pair of coefficient matrices will be equal in magnitude and
#' opposite in sign, and half the \code{"binomial"} values.
#' Two useful additional families are the \code{family="mgaussian"} family and
#' the \code{type.multinomial="grouped"} option for multinomial fitting. The
#' former allows a multi-response gaussian model to be fit, using a "group
#' -lasso" penalty on the coefficients for each variable. Tying the responses
#' together like this is called "multi-task" learning in some domains. The
#' grouped multinomial allows the same penalty for the
#' \code{family="multinomial"} model, which is also multi-responsed. For both
#' of these the penalty on the coefficient vector for variable j is
#' \deqn{(1-\alpha)/2||\beta_j||_2^2+\alpha||\beta_j||_2.} When \code{alpha=1}
#' this is a group-lasso penalty, and otherwise it mixes with quadratic just
#' like elasticnet. A small detail in the Cox model: if death times are tied
#' with censored times, we assume the censored times occurred just
#' \emph{before} the death times in computing the Breslow approximation; if
#' users prefer the usual convention of \emph{after}, they can add a small
#' number to all censoring times to achieve this effect.
#'
#' ## Details on response for `family="cox"`
#'
#' For Cox models, the response should preferably be a \code{Surv} object,
#' created by the \code{Surv()} function in \pkg{survival} package. For
#' right-censored data, this object should have type "right", and for
#' (start, stop] data, it should have type "counting". To fit stratified Cox
#' models, strata should be added to the response via the \code{stratifySurv()}
#' function before passing the response to \code{glmnet()}. (For backward
#' compatibility, right-censored data can also be passed as a
#' two-column matrix with columns named 'time' and 'status'. The
#' latter is a binary variable, with '1' indicating death, and '0' indicating
#' right censored.)
#'
#' ## Details on `relax` option
#'
#' If \code{relax=TRUE}
#' a duplicate sequence of models is produced, where each active set in the
#' elastic-net path is refit without regularization. The result of this is a
#' matching \code{"glmnet"} object which is stored on the original object in a
#' component named \code{"relaxed"}, and is part of the glmnet output.
#' Generally users will not call \code{relax.glmnet} directly, unless the
#' original 'glmnet' object took a long time to fit. But if they do, they must
#' supply the fit, and all the original arguments used to create that fit. They
#' can limit the length of the relaxed path via 'maxp'.
#'
#' @param x input matrix, of dimension nobs x nvars; each row is an observation
#' vector. Can be in sparse matrix format (inherit from class
#' \code{"sparseMatrix"} as in package \code{Matrix}).
#' Requirement: \code{nvars >1}; in other words, \code{x} should have 2 or more columns.
#' @param y response variable. Quantitative for \code{family="gaussian"}, or
#' \code{family="poisson"} (non-negative counts). For \code{family="binomial"}
#' should be either a factor with two levels, or a two-column matrix of counts
#' or proportions (the second column is treated as the target class; for a
#' factor, the last level in alphabetical order is the target class). For
#' \code{family="multinomial"}, can be a \code{nc>=2} level factor, or a matrix
#' with \code{nc} columns of counts or proportions. For either
#' \code{"binomial"} or \code{"multinomial"}, if \code{y} is presented as a
#' vector, it will be coerced into a factor. For \code{family="cox"}, preferably
#' a \code{Surv} object from the survival package: see Details section for
#' more information. For \code{family="mgaussian"}, \code{y} is a matrix
#' of quantitative responses.
#' @param family Either a character string representing
#' one of the built-in families, or else a `glm()` family object. For more
#' information, see Details section below or the documentation for response
#' type (above).
#' @param weights observation weights. Can be total counts if responses are
#' proportion matrices. Default is 1 for each observation
#' @param offset A vector of length \code{nobs} that is included in the linear
#' predictor (a \code{nobs x nc} matrix for the \code{"multinomial"} family).
#' Useful for the \code{"poisson"} family (e.g. log of exposure time), or for
#' refining a model by starting at a current fit. Default is \code{NULL}. If
#' supplied, then values must also be supplied to the \code{predict} function.
#' @param alpha The elasticnet mixing parameter, with \eqn{0\le\alpha\le 1}.
#' The penalty is defined as
#' \deqn{(1-\alpha)/2||\beta||_2^2+\alpha||\beta||_1.} \code{alpha=1} is the
#' lasso penalty, and \code{alpha=0} the ridge penalty.
#' @param nlambda The number of \code{lambda} values - default is 100.
#' @param lambda.min.ratio Smallest value for \code{lambda}, as a fraction of
#' \code{lambda.max}, the (data derived) entry value (i.e. the smallest value
#' for which all coefficients are zero). The default depends on the sample size
#' \code{nobs} relative to the number of variables \code{nvars}. If \code{nobs
#' > nvars}, the default is \code{0.0001}, close to zero.  If \code{nobs <
#' nvars}, the default is \code{0.01}.  A very small value of
#' \code{lambda.min.ratio} will lead to a saturated fit in the \code{nobs <
#' nvars} case. This is undefined for \code{"binomial"} and
#' \code{"multinomial"} models, and \code{glmnet} will exit gracefully when the
#' percentage deviance explained is almost 1.
#' @param lambda A user supplied \code{lambda} sequence. Typical usage is to
#' have the program compute its own \code{lambda} sequence based on
#' \code{nlambda} and \code{lambda.min.ratio}. Supplying a value of
#' \code{lambda} overrides this. WARNING: use with care. Avoid supplying a
#' single value for \code{lambda} (for predictions after CV use
#' \code{predict()} instead).  Supply instead a decreasing sequence of
#' \code{lambda} values. \code{glmnet} relies on its warms starts for speed,
#' and its often faster to fit a whole path than compute a single fit.
#' @param standardize Logical flag for x variable standardization, prior to
#' fitting the model sequence. The coefficients are always returned on the
#' original scale. Default is \code{standardize=TRUE}.  If variables are in the
#' same units already, you might not wish to standardize. See details below for
#' y standardization with \code{family="gaussian"}.
#' @param intercept Should intercept(s) be fitted (default=TRUE) or set to zero
#' (FALSE)
#' @param thresh Convergence threshold for coordinate descent. Each inner
#' coordinate-descent loop continues until the maximum change in the objective
#' after any coefficient update is less than \code{thresh} times the null
#' deviance. Defaults value is \code{1E-7}.
#' @param dfmax Limit the maximum number of variables in the model. Useful for
#' very large \code{nvars}, if a partial path is desired.
#' @param pmax Limit the maximum number of variables ever to be nonzero
#' @param exclude Indices of variables to be excluded from the model. Default
#' is none. Equivalent to an infinite penalty factor for the variables excluded (next item).
#' Users can supply instead an \code{exclude} function that generates the list of indices.
#' This function is most generally defined as \code{function(x, y, weights, ...)},
#' and is called inside \code{glmnet} to generate the indices for excluded variables.
#' The \code{...} argument is required, the others are optional.
#' This is useful for filtering wide data, and works correctly with \code{cv.glmnet}.
#' See the vignette 'Introduction' for examples.
#' @param penalty.factor Separate penalty factors can be applied to each
#' coefficient. This is a number that multiplies \code{lambda} to allow
#' differential shrinkage. Can be 0 for some variables, which implies no
#' shrinkage, and that variable is always included in the model. Default is 1
#' for all variables (and implicitly infinity for variables listed in
#' \code{exclude}). Also, any \code{penalty.factor} that is set to \code{inf} is
#' converted to an \code{exclude}, and then internally reset to 1.
#' Note: the penalty factors are internally rescaled to sum to
#' nvars, and the lambda sequence will reflect this change.
#' @param lower.limits Vector of lower limits for each coefficient; default
#' \code{-Inf}. Each of these must be non-positive. Can be presented as a
#' single value (which will then be replicated), else a vector of length
#' \code{nvars}
#' @param upper.limits Vector of upper limits for each coefficient; default
#' \code{Inf}. See \code{lower.limits}
#' @param maxit Maximum number of passes over the data for all lambda values;
#' default is 10^5.
#' @param type.gaussian Two algorithm types are supported for (only)
#' \code{family="gaussian"}. The default when \code{nvar<500} is
#' \code{type.gaussian="covariance"}, and saves all inner-products ever
#' computed. This can be much faster than \code{type.gaussian="naive"}, which
#' loops through \code{nobs} every time an inner-product is computed. The
#' latter can be far more efficient for \code{nvar >> nobs} situations, or when
#' \code{nvar > 500}.
#' @param type.logistic If \code{"Newton"} then the exact hessian is used
#' (default), while \code{"modified.Newton"} uses an upper-bound on the
#' hessian, and can be faster.
#' @param standardize.response This is for the \code{family="mgaussian"}
#' family, and allows the user to standardize the response variables
#' @param type.multinomial If \code{"grouped"} then a grouped lasso penalty is
#' used on the multinomial coefficients for a variable. This ensures they are
#' all in our out together. The default is \code{"ungrouped"}
#' @param relax If \code{TRUE} then for each \emph{active set} in the path of
#' solutions, the model is refit without any regularization. See \code{details}
#' for more information. This argument is new, and users may experience convergence issues
#' with small datasets, especially with non-gaussian families. Limiting the
#' value of 'maxp' can alleviate these issues in some cases.
#' @param trace.it If \code{trace.it=1}, then a progress bar is displayed;
#' useful for big models that take a long time to fit.
#' @param ... Additional argument used in \code{relax.glmnet}. These include
#' some of the original arguments to 'glmnet', and each must be named if used.
#' @return An object with S3 class \code{"glmnet","*" }, where \code{"*"} is
#' \code{"elnet"}, \code{"lognet"}, \code{"multnet"}, \code{"fishnet"}
#' (poisson), \code{"coxnet"} or \code{"mrelnet"} for the various types of
#' models. If the model was created with \code{relax=TRUE} then this class has
#' a prefix class of \code{"relaxed"}.  \item{call}{the call that produced this
#' object} \item{a0}{Intercept sequence of length \code{length(lambda)}}
#' \item{beta}{For \code{"elnet"}, \code{"lognet"}, \code{"fishnet"} and
#' \code{"coxnet"} models, a \code{nvars x length(lambda)} matrix of
#' coefficients, stored in sparse column format (\code{"CsparseMatrix"}). For
#' \code{"multnet"} and \code{"mgaussian"}, a list of \code{nc} such matrices,
#' one for each class.} \item{lambda}{The actual sequence of \code{lambda}
#' values used. When \code{alpha=0}, the largest lambda reported does not quite
#' give the zero coefficients reported (\code{lambda=inf} would in principle).
#' Instead, the largest \code{lambda} for \code{alpha=0.001} is used, and the
#' sequence of \code{lambda} values is derived from this.} \item{dev.ratio}{The
#' fraction of (null) deviance explained (for \code{"elnet"}, this is the
#' R-square). The deviance calculations incorporate weights if present in the
#' model. The deviance is defined to be 2*(loglike_sat - loglike), where
#' loglike_sat is the log-likelihood for the saturated model (a model with a
#' free parameter per observation). Hence dev.ratio=1-dev/nulldev.}
#' \item{nulldev}{Null deviance (per observation). This is defined to be
#' 2*(loglike_sat -loglike(Null)); The NULL model refers to the intercept
#' model, except for the Cox, where it is the 0 model.} \item{df}{The number of
#' nonzero coefficients for each value of \code{lambda}. For \code{"multnet"},
#' this is the number of variables with a nonzero coefficient for \emph{any}
#' class.} \item{dfmat}{For \code{"multnet"} and \code{"mrelnet"} only. A
#' matrix consisting of the number of nonzero coefficients per class}
#' \item{dim}{dimension of coefficient matrix (ices)} \item{nobs}{number of
#' observations} \item{npasses}{total passes over the data summed over all
#' lambda values} \item{offset}{a logical variable indicating whether an offset
#' was included in the model} \item{jerr}{error flag, for warnings and errors
#' (largely for internal debugging).} \item{relaxed}{If \code{relax=TRUE}, this
#' additional item is another glmnet object with different values for
#' \code{beta} and \code{dev.ratio}}
#' @author Jerome Friedman, Trevor Hastie, Balasubramanian Narasimhan, Noah
#' Simon, Kenneth Tay and Rob Tibshirani\cr Maintainer: Trevor Hastie
#' \email{hastie@@stanford.edu}
#' @seealso \code{print}, \code{predict}, \code{coef} and \code{plot} methods,
#' and the \code{cv.glmnet} function.
#' @references Friedman, J., Hastie, T. and Tibshirani, R. (2008)
#' \emph{Regularization Paths for Generalized Linear Models via Coordinate
#' Descent (2010), Journal of Statistical Software, Vol. 33(1), 1-22},
#' \doi{10.18637/jss.v033.i01}.\cr
#' Simon, N., Friedman, J., Hastie, T. and Tibshirani, R. (2011)
#' \emph{Regularization Paths for Cox's Proportional
#' Hazards Model via Coordinate Descent, Journal of Statistical Software, Vol.
#' 39(5), 1-13},
#' \doi{10.18637/jss.v039.i05}.\cr
#' Tibshirani,Robert, Bien, J., Friedman, J., Hastie, T.,Simon, N.,Taylor, J. and
#' Tibshirani, Ryan. (2012) \emph{Strong Rules for Discarding Predictors in
#' Lasso-type Problems, JRSSB, Vol. 74(2), 245-266},
#' \url{https://arxiv.org/abs/1011.2234}.\cr
#' Hastie, T., Tibshirani, Robert and Tibshirani, Ryan (2020) \emph{Best Subset,
#' Forward Stepwise or Lasso? Analysis and Recommendations Based on Extensive Comparisons,
#' Statist. Sc. Vol. 35(4), 579-592},
#' \url{https://arxiv.org/abs/1707.08692}.\cr
#' Glmnet webpage with four vignettes: \url{https://glmnet.stanford.edu}.
#' @keywords models regression
#' @examples
#'
#' # Gaussian
#' x = matrix(rnorm(100 * 20), 100, 20)
#' y = rnorm(100)
#' fit1 = glmnet(x, y)
#' print(fit1)
#' coef(fit1, s = 0.01)  # extract coefficients at a single value of lambda
#' predict(fit1, newx = x[1:10, ], s = c(0.01, 0.005))  # make predictions
#'
#' # Relaxed
#' fit1r = glmnet(x, y, relax = TRUE)  # can be used with any model
#'
#' # multivariate gaussian
#' y = matrix(rnorm(100 * 3), 100, 3)
#' fit1m = glmnet(x, y, family = "mgaussian")
#' plot(fit1m, type.coef = "2norm")
#'
#' # binomial
#' g2 = sample(c(0,1), 100, replace = TRUE)
#' fit2 = glmnet(x, g2, family = "binomial")
#' fit2n = glmnet(x, g2, family = binomial(link=cloglog))
#' fit2r = glmnet(x,g2, family = "binomial", relax=TRUE)
#' fit2rp = glmnet(x,g2, family = "binomial", relax=TRUE, path=TRUE)
#'
#' # multinomial
#' g4 = sample(1:4, 100, replace = TRUE)
#' fit3 = glmnet(x, g4, family = "multinomial")
#' fit3a = glmnet(x, g4, family = "multinomial", type.multinomial = "grouped")
#' # poisson
#' N = 500
#' p = 20
#' nzc = 5
#' x = matrix(rnorm(N * p), N, p)
#' beta = rnorm(nzc)
#' f = x[, seq(nzc)] %*% beta
#' mu = exp(f)
#' y = rpois(N, mu)
#' fit = glmnet(x, y, family = "poisson")
#' plot(fit)
#' pfit = predict(fit, x, s = 0.001, type = "response")
#' plot(pfit, y)
#'
#' # Cox
#' set.seed(10101)
#' N = 1000
#' p = 30
#' nzc = p/3
#' x = matrix(rnorm(N * p), N, p)
#' beta = rnorm(nzc)
#' fx = x[, seq(nzc)] %*% beta/3
#' hx = exp(fx)
#' ty = rexp(N, hx)
#' tcens = rbinom(n = N, prob = 0.3, size = 1)  # censoring indicator
#' y = cbind(time = ty, status = 1 - tcens)  # y=Surv(ty,1-tcens) with library(survival)
#' fit = glmnet(x, y, family = "cox")
#' plot(fit)
#'
#' # Cox example with (start, stop] data
#' set.seed(2)
#' nobs <- 100; nvars <- 15
#' xvec <- rnorm(nobs * nvars)
#' xvec[sample.int(nobs * nvars, size = 0.4 * nobs * nvars)] <- 0
#' x <- matrix(xvec, nrow = nobs)
#' start_time <- runif(100, min = 0, max = 5)
#' stop_time <- start_time + runif(100, min = 0.1, max = 3)
#' status <- rbinom(n = nobs, prob = 0.3, size = 1)
#' jsurv_ss <- survival::Surv(start_time, stop_time, status)
#' fit <- glmnet(x, jsurv_ss, family = "cox")
#'
#' # Cox example with strata
#' jsurv_ss2 <- stratifySurv(jsurv_ss, rep(1:2, each = 50))
#' fit <- glmnet(x, jsurv_ss2, family = "cox")
#'
#' # Sparse
#' n = 10000
#' p = 200
#' nzc = trunc(p/10)
#' x = matrix(rnorm(n * p), n, p)
#' iz = sample(1:(n * p), size = n * p * 0.85, replace = FALSE)
#' x[iz] = 0
#' sx = Matrix(x, sparse = TRUE)
#' inherits(sx, "sparseMatrix")  #confirm that it is sparse
#' beta = rnorm(nzc)
#' fx = x[, seq(nzc)] %*% beta
#' eps = rnorm(n)
#' y = fx + eps
#' px = exp(fx)
#' px = px/(1 + px)
#' ly = rbinom(n = length(px), prob = px, size = 1)
#' system.time(fit1 <- glmnet(sx, y))
#' system.time(fit2n <- glmnet(x, y))
#'
#' @export glmnet
glmnet=function(x,y,family=c("gaussian","binomial","poisson","multinomial","cox","mgaussian"),weights=NULL,offset=NULL,alpha=1.0,nlambda=100,lambda.min.ratio=ifelse(nobs<nvars,1e-2,1e-4),lambda=NULL,standardize=TRUE,intercept=TRUE,thresh=1e-7,dfmax=nvars+1,pmax=min(dfmax*2+20,nvars),exclude=NULL,penalty.factor=matrix(1, nrow=nvars, ncol=nc),lower.limits=-Inf,upper.limits=Inf,maxit=100000,type.gaussian=ifelse(nvars<500,"covariance","naive"),type.logistic=c("Newton","modified.Newton"),standardize.response=FALSE,type.multinomial=c("ungrouped","grouped"),relax=FALSE,trace.it=0,...){

    this.call=match.call()
### Need to do this first so defaults in call can be satisfied
    np=dim(x)
    ##check dims
    if(is.null(np)|(np[2]<=1))stop("x should be a matrix with 2 or more columns")
    nobs=as.integer(np[1])
    nvars=as.integer(np[2])
    nc=dim(y)
    if(is.null(nc)){
      ## Need to construct a y matrix, and include the weights
      y=as.factor(y)
      ntab=table(y)
      minclass=min(ntab)
      if(minclass<=1)stop("one multinomial or binomial class has 1 or 0 observations; not allowed")
      if(minclass<8)warning("one multinomial or binomial class has fewer than 8  observations; dangerous ground")
      classnames=names(ntab)
      nc=as.integer(length(ntab))
      y=diag(nc)[as.numeric(y),]
    }
    
    
    
    ##check for NAs
    if(any(is.na(x)))stop("x has missing values; consider using makeX() to impute them")
    if(is.null(weights))weights=rep(1,nobs)
    else if(length(weights)!=nobs)stop(paste("number of elements in weights (",length(weights),") not equal to the number of rows of x (",nobs,")",sep=""))
    if(is.function(exclude))exclude <- check.exclude(exclude(x=x,y=y,weights=weights),nvars)
    if (!all(dim(penalty.factor) == c(nvars, nc))) {
        stop("penalty.factor must be of dimension (nvars x nc)")
    }

### See whether its a call to glmnet or to glmnet.path, based on family arg
    if(!is.character(family)){
        ## new.call=this.call
        ## new.call[[1]]=as.name("glmnet.path")
        ## fit=eval(new.call, parent.frame())
        fit=glmnet.path(x,y,weights,lambda,nlambda,lambda.min.ratio,alpha,offset,family,
                        standardize,intercept,thresh=thresh,maxit,penalty.factor,exclude,lower.limits,
                        upper.limits,trace.it=trace.it)
        fit$call=this.call
    } else {
      family=match.arg(family)
      if (family == "cox" && use.cox.path(x, y)) {
      # we should call the new cox.path()
      fit <- cox.path(x,y,weights,offset,alpha,nlambda,lambda.min.ratio,
                      lambda,standardize,thresh,exclude,penalty.factor,
                      lower.limits,upper.limits,maxit,trace.it,...)
      fit$call <- this.call
    } else {
      ### Must have been a call to old glmnet
      ### Prepare all the generic arguments, then hand off to family functions
      if(alpha>1){
        warning("alpha >1; set to 1")
        alpha=1
      }
      if(alpha<0){
        warning("alpha<0; set to 0")
        alpha=0
      }
      alpha=as.double(alpha)
      nlam=as.integer(nlambda)
      y=drop(y) # we dont like matrix responses unless we need them
      dimy=dim(y)
      nrowy=ifelse(is.null(dimy),length(y),dimy[1])
      if(nrowy!=nobs)stop(paste("number of observations in y (",nrowy,") not equal to the number of rows of x (",nobs,")",sep=""))
      vnames=colnames(x)
      if(is.null(vnames))vnames=paste("V",seq(nvars),sep="")
      ne=as.integer(dfmax)
      nx=as.integer(pmax)
      if(is.null(exclude))exclude=integer(0)
      if(any(penalty.factor==Inf)){
        exclude=c(exclude,seq(nvars)[penalty.factor==Inf])
        exclude=sort(unique(exclude))
      }
      if(length(exclude)>0){
        jd=match(exclude,seq(nvars),0)
        if(!all(jd>0))stop("Some excluded variables out of range")
        penalty.factor[jd]=1 #ow can change lambda sequence
        jd=as.integer(c(length(jd),jd))
      }else jd=as.integer(0)
      mp=penalty.factor
      vp=as.double(penalty.factor[,1])
      internal.parms=glmnet.control()
      if(internal.parms$itrace)trace.it=1
      else{
        if(trace.it){
          glmnet.control(itrace=1)
          on.exit(glmnet.control(itrace=0))
        }
      }
      ###check on limits
      if(any(lower.limits>0)){stop("Lower limits should be non-positive")}
      if(any(upper.limits<0)){stop("Upper limits should be non-negative")}
      lower.limits[lower.limits==-Inf]=-internal.parms$big
      upper.limits[upper.limits==Inf]=internal.parms$big
      if(length(lower.limits)<nvars){
        if(length(lower.limits)==1)lower.limits=rep(lower.limits,nvars)else stop("Require length 1 or nvars lower.limits")
      }
      else lower.limits=lower.limits[seq(nvars)]
      if(length(upper.limits)<nvars){
        if(length(upper.limits)==1)upper.limits=rep(upper.limits,nvars)else stop("Require length 1 or nvars upper.limits")
      }
      else upper.limits=upper.limits[seq(nvars)]
      cl=rbind(lower.limits,upper.limits)
      if(any(cl==0)){
        ###Bounds of zero can mess with the lambda sequence and fdev; ie nothing happens and if fdev is not
        ###zero, the path can stop
        fdev=glmnet.control()$fdev
        if(fdev!=0) {
          glmnet.control(fdev=0)
          on.exit(glmnet.control(fdev=fdev))
        }
      }
      storage.mode(cl)="double"
      ### end check on limits

      isd=as.integer(standardize)
      intr=as.integer(intercept)
      if(!missing(intercept)&&family=="cox")warning("Cox model has no intercept")
      jsd=as.integer(standardize.response)
      thresh=as.double(thresh)
      if(is.null(lambda)){
        if(lambda.min.ratio>=1)stop("lambda.min.ratio should be less than 1")
        flmin=as.double(lambda.min.ratio)
        ulam=double(1)
      }
      else{
        flmin=as.double(1)
        if(any(lambda<0))stop("lambdas should be non-negative")
        ulam=as.double(rev(sort(lambda)))
        nlam=as.integer(length(lambda))
      }
      is.sparse=FALSE
      if(inherits(x,"sparseMatrix")){##Sparse case
          is.sparse=TRUE
          if(!inherits(x,"dgCMatrix"))
              x=as(as(as(x, "generalMatrix"), "CsparseMatrix"), "dMatrix")
        # TODO: changed everything except cox to C++ implementation.
      } else if (!inherits(x, "matrix")) {
        x <- data.matrix(x)
      } else {
        x <- x
      }
      # TODO: only coerce if xd is not sparse
      if(!inherits(x,"sparseMatrix")) {
        storage.mode(x) <- "double"
      }
      if (trace.it) {
        if (relax) cat("Training Fit\n")
        pb  <- createPB(min = 0, max = nlam, initial = 0, style = 3)
      } else {
        pb <- NULL # dummy initialize (won't be used, but still need to pass)
      }
      kopt=switch(match.arg(type.logistic),
                  "Newton"=0,#This means to use the exact Hessian
                  "modified.Newton"=1 # Use the upper bound
                  )
      if(family=="multinomial"){
        type.multinomial=match.arg(type.multinomial)
        if(type.multinomial=="grouped")kopt=2 #overrules previous kopt
      }
      kopt=as.integer(kopt)

      fit=switch(family,
                 "gaussian"=elnet(x,is.sparse,y,weights,offset,type.gaussian,alpha,nobs,nvars,jd,vp,mp,cl,ne,nx,nlam,flmin,ulam,thresh,isd,intr,vnames,maxit,pb),
                 "poisson"=fishnet(x,is.sparse,y,weights,offset,alpha,nobs,nvars,jd,vp,mp,cl,ne,nx,nlam,flmin,ulam,thresh,isd,intr,vnames,maxit,pb),
                 "binomial"=lognet(x,is.sparse,y,weights,offset,alpha,nobs,nvars,jd,vp,mp,cl,ne,nx,nlam,flmin,ulam,thresh,isd,intr,vnames,maxit,kopt,family,pb),
                 "multinomial"=lognet(x,is.sparse,y,weights,offset,alpha,nobs,nvars,jd,vp,mp,cl,ne,nx,nlam,flmin,ulam,thresh,isd,intr,vnames,maxit,kopt,family,pb),
                 "cox"=coxnet(x,is.sparse,y,weights,offset,alpha,nobs,nvars,jd,vp,cl,ne,nx,nlam,flmin,ulam,thresh,isd,vnames,maxit),
                 "mgaussian"=mrelnet(x,is.sparse,y,weights,offset,alpha,nobs,nvars,jd,vp,mp,cl,ne,nx,nlam,flmin,ulam,thresh,isd,jsd,intr,vnames,maxit,pb)
                 )
      if (trace.it) {
        utils::setTxtProgressBar(pb, nlam)
        close(pb)
      }
      if(is.null(lambda))fit$lambda=fix.lam(fit$lambda)##first lambda is infinity; changed to entry point
      fit$call=this.call
      fit$nobs=nobs
      class(fit)=c(class(fit),"glmnet")
    }
    }

  if(relax)
    relax.glmnet(fit, x=x,y=y,weights=weights,offset=offset,
                 lower.limits=lower.limits,upper.limits=upper.limits,penalty.factor=penalty.factor,
                 check.args=FALSE,...)
  else
    fit
}
