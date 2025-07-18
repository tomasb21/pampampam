elnet=function(x,is.sparse,y,weights,offset,type.gaussian=c("covariance","naive"),alpha,nobs,nvars,jd,vp,mp,cl,ne,nx,nlam,flmin,ulam,thresh,isd,intr,vnames,maxit,pb){
  maxit=as.integer(maxit)
  weights=as.double(weights)
  type.gaussian=match.arg(type.gaussian)

  ka=as.integer(switch(type.gaussian,
    covariance=1,
    naive=2,
    ))


 storage.mode(y)="double"
   if(is.null(offset)){
    is.offset=FALSE}
  else{
    storage.mode(offset)="double"
    is.offset=TRUE
    y=y-offset
  }
### compute the null deviance
  ybar=if(intr)weighted.mean(y,weights)else 0
  nulldev=sum(weights* (y-ybar)^2)
if(nulldev==0)stop("y is constant; gaussian glmnet fails at standardization step")

fit=if(is.sparse) spelnet_exp(
        ka,parm=alpha,x,y,weights,jd,vp,mp,cl,ne,nx,nlam,flmin,ulam,thresh,isd,intr,maxit,pb,
        lmu=integer(1),
        a0=double(nlam),
        ca=matrix(0.0, nrow=nx, ncol=nlam),
        ia=integer(nx),
        nin=integer(nlam),
        rsq=double(nlam),
        alm=double(nlam),
        nlp=integer(1),
        jerr=integer(1)
        )
else elnet_exp(
        ka,parm=alpha,x,y,weights,jd,vp,mp,cl,ne,nx,nlam,flmin,ulam,thresh,isd,intr,maxit,pb,
        lmu=integer(1),
        a0=double(nlam),
        ca=matrix(0.0, nrow=nx, ncol=nlam),
        ia=integer(nx),
        nin=integer(nlam),
        rsq=double(nlam),
        alm=double(nlam),
        nlp=integer(1),
        jerr=integer(1)
          )
if(fit$jerr!=0){
  errmsg=jerr(fit$jerr,maxit,pmax=nx,family="gaussian")
  if(errmsg$fatal)stop(errmsg$msg,call.=FALSE)
  else warning(errmsg$msg,call.=FALSE)
}
  outlist=getcoef(fit,nvars,nx,vnames)
  dev=fit$rsq[seq(fit$lmu)]
  outlist=c(outlist,list(dev.ratio=dev,nulldev=nulldev,npasses=fit$nlp,jerr=fit$jerr,offset=is.offset))
  class(outlist)="elnet"
  outlist
}
