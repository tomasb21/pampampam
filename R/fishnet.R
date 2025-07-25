fishnet=function(x,is.sparse,y,weights,offset,alpha,nobs,nvars,jd,vp,mp,cl,ne,nx,nlam,flmin,ulam,thresh,isd,intr,vnames,maxit,pb){
  if(any(y<0))stop("negative responses encountered;  not permitted for Poisson family")
  maxit=as.integer(maxit)
  weights=as.double(weights)
  storage.mode(y)="double"
   if(is.null(offset)){
    offset=y*0 #keeps the shape of y
    is.offset=FALSE}
  else{
    storage.mode(offset)="double"
    
    is.offset=TRUE
  }
fit=if(is.sparse) spfishnet_exp(
  parm=alpha,x,y,offset,weights,jd,vp,mp,cl,ne,nx,nlam,flmin,ulam,thresh,isd,intr,maxit,pb,
  lmu=integer(1),
  a0=double(nlam),
  ca=matrix(0.0, nx, nlam),
  ia=integer(nx),
  nin=integer(nlam),
  nulldev=double(1),
  dev=double(nlam),
  alm=double(nlam),
  nlp=integer(1),
  jerr=integer(1)
  )
else fishnet_exp(
              parm=alpha,x,y,offset,weights,jd,vp,mp,cl,ne,nx,nlam,flmin,ulam,thresh,isd,intr,maxit,pb,
              lmu=integer(1),
              a0=double(nlam),
              ca=matrix(0.0,nx,nlam),
              ia=integer(nx),
              nin=integer(nlam),
              nulldev=double(1),
              dev=double(nlam),
              alm=double(nlam),
              nlp=integer(1),
              jerr=integer(1)
              )
if(fit$jerr!=0){
  errmsg=jerr(fit$jerr,maxit,pmax=nx,family="poisson")
  if(errmsg$fatal)stop(errmsg$msg,call.=FALSE)
  else warning(errmsg$msg,call.=FALSE)
}
  outlist=getcoef(fit,nvars,nx,vnames)
  dev=fit$dev[seq(fit$lmu)]
outlist=c(outlist,list(dev.ratio=dev,nulldev=fit$nulldev,npasses=fit$nlp,jerr=fit$jerr,offset=is.offset))
class(outlist)="fishnet"
outlist
}
