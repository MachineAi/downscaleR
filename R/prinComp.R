# prinComp.R Principal Component Analysis of grid data
#
#     Copyright (C) 2016 Santander Meteorology Group (http://www.meteo.unican.es)
#
#     This program is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 3 of the License, or
#     (at your option) any later version.
# 
#     This program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
# 
#     You should have received a copy of the GNU General Public License
#     along with this program.  If not, see <http://www.gnu.org/licenses/>.

#' @title Principal Component Analysis of grid/multigrid/multimember data
#' @description Performs a Principal Component Analysis of grid, multigrid or multi-member data
#' @param gridData A grid, multigrid, multimember grid or multimember multigrid object
#' @param n.eofs Number of EOFs to be retained. Default to \code{NULL}, indicating
#'  that either all EOFs are kept, or that the next argument will be used as criterion
#'  for its determination. See next argument and details.
#' @param v.exp Maximum fraction of explained variance, in the range (0,1]. Used to determine the number of EOFs 
#' to be retained, as an alternative to \code{n.eofs}. Default to \code{NULL}. See details.
#' @param scaling Method for performing the scaling (and centering) of the input raw data matrix.
#' Currently accepted choices are \code{"field"} (the default) and \code{"gridbox"}. See details.
#' @template templateParallelParams
#' @return A list of \emph{N + 1} elements for multigrids, where \emph{N} is the number of input variables used
#'  and the last element contains the results of the combined PCA (See details). The list is named as the variables,
#'  including the last element named \code{"COMBINED"}. In case of single grids (1 variable only), a list of length 1
#'   (without the combined element). For each element of the list, the following objects are returned, either in the form of
#'   another list (1 element for each member) for multimembers, or not in the case of non multimember inputs:
#'  \itemize{
#'  \item \code{PCs}: A matrix of principal components, arranged in columns by decreasing importance order 
#'  \item \code{EOFs}: A matrix of EOFs, arranged in columns by decreasing importance order
#'  \item \code{orig}: The original variable in the form of a 2D-matrix. This is standardized according
#'  to the approach indicated in argument \code{scaling}.
#'  }
#'  The \dQuote{order of importance} is given by the explained variance of each PC, as indicated
#'  in the attribute \code{"explained_variance"} as a cumulative vector.
#'  Additional information is returned via the remaining attributes (see details), including geo-referencing and time.
#' @template templateParallel
#' @note Performing PCA analysis on multimember multigrids may become time-consuming and computationally expensive. 
#' It is therefore advisable to avoid the use of this option for large datasets, and iterate over single
#' multimember grids instead.
#' @details
#' 
#' \strong{Number of EOFs}
#' \code{n.eofs} and \code{v.exp} are alternative choices for the determination
#'  of the number of EOFs (hence also the corresponding PCs) to be retained. If both are \code{NULL} (the default)
#'  , all EOFs will be retained. If both are given a value different from \code{NULL}, 
#'  the \code{n.eofs} argument will prevail, and \code{v.exp} will be ignored, with a warning.
#'  Note that when dealing with multigrids, the \code{n.eofs} argument will return the same number of EOFs
#'  for each variable by sepparate and also for the combined grid, while \code{v.exp} will select
#'  a different number, depending on the explained variance in each case. 
#'  
#' \strong{Scaling and centering}
#' 
#' In order to eliminate the effect of the varying scales of the different climate variables, the input
#' data matrix is always scaled and centered, and there is no choice to avoid this step. However, the mean
#' and standard deviation can be either computed for each grid box individually (\code{"gridbox"}) or for all
#' grid-boxes together (i.e., at the field level, \code{"field"}). The last case is the preferred choice and has
#' been set as default, returning one single mean and sigma parameter for each variable. If the \code{"gridbox"}
#' approach is selected, a vector of length \emph{n}, where \emph{n} is the number of grid-cells composing the 
#' grid, is returned for both the mean and sigma parameters (this is equivalent to using the \code{\link{scale}}
#' function with the input data matrix). 
#' 
#' The method used is returned as a global attribute of the returned object (\code{"scaled:method"}), and the 
#' \emph{mu} and \emph{sigma} parameters are returned as attributes of the corresponding variables
#'  (\code{"scaled:scale"} and \code{"scaled:center"} respectively).
#' 
#' \strong{Combined EOF analysis}
#' 
#' When dealing with multigrid data, apart from the PCA analysis performed on each variable indivisually,
#' a combined analysis considering all variables together is done. This is always returned in the last element
#' of the output list.
#'
#' @export
#' @importFrom abind asub
#' @importFrom stats cov sd
#' @seealso \code{\link{gridFromPCs}}, \code{\link{plotEOF}}
#' @references
#' Guti\'{e}rrez, J.M., R. Ancell, A. S. Cofi\~{n}o and C. Sordo (2004). Redes Probabil\'{i}sticas
#'  y Neuronales en las Ciencias Atmosf\'{e}ricas. MIMAM, Spain. 279 pp.
#'   \url{http://www.meteo.unican.es/en/books/dataMiningMeteo}
#' @author J. Bedia 
#' @examples \dontrun{
#' # Download dataset
#' download.file("http://meteo.unican.es/work/downscaler/data/Iberia_NCEP.tar.gz", 
#' destfile = "mydirectory/Iberia_NCEP.tar.gz")
#' # Extract files from the tar.gz file
#' untar("mydirectory/NCEP_Iberia.tar.gz", exdir = "mydirectory")
#' # First, the path to the ncml file is defined:
#' ncep <- "mydirectory/Iberia_NCEP/Iberia_NCEP.ncml"
#' # A multigrid containing a set of variables is loaded (e.g. data for spring spanning the 
#' # 30-year period 1981--2010):
#' require(loadeR)
#' hus <- loadGridData(ncep, var = "hus@@850", season = 3:5, years = 1981:2010)
#' ta <- loadGridData(ncep, var = "ta@@850", season = 3:5, years = 1981:2010)
#' psl <- loadGridData(ncep, var = "psl", season = 3:5, years = 1981:2010)
#' multigrid <- makeMultiGrid(hus, ta, psl)
#' # In this example, we retain the PCs explaining the 99\% of the variance
#' pca <- prinComp(multigrid, v.exp = .99)
#' # Note that, apart from computing the principal components and EOFs for each grid, 
#' # it also returns, in the last element of the output list,
#' # the results of a PC analysis of all the variables combined (named "COMBINED"):
#' names(pca)
#' str(pca)
#' # The different attributes of the pca object provide information regarding the variables involved
#' # and the geo-referencing information
#' str(attributes(pca))
#' # In addition, for each variable (and their combination), the scaling and centering parameters 
#' # are also returned. These are either a single value in case of grid scaling (the default), or a
#' # vector of values, one for each grid-cell, for the gridbox scaling. For instance, the parameters
#' # for the specific humidity grid are:
#' attributes(pca$hus[[1]])$`scaled:center`
#' attributes(pca$hus[[1]])$`scaled:scale`
#' # In addition, the (cumulative) explained variance of each PC is also returned:
#' vexp <- attributes(pca$hus[[1]])$explained_variance
#' # The classical "scree plot":
#' barplot(1-vexp, names.arg = paste("PC",1:length(vexp)), las = 2, 
#'         ylab = "Fraction of unexplained variance")
#'  
#' # This is an example using a multimember object:
#' data(tasmax_forecast)
#' # In order make the computation faster, we interpolate to a coarser grid of 2.5 deg
#' range(tasmax_forecast$xyCoords$x)
#' range(tasmax_forecast$xyCoords$y)
#' multimember <- interpGrid(tasmax_forecast, 
#'                               new.coordinates = list(c(-10,29.5, 2.5), c(35.5, 64.5, 2.5)))
#' # In this case we retain the first 15 EOFs:
#' pca.mm <- prinComp(multimember, n.eofs = 15) 
#' # Note that now the results of the PCA for the variable are a list, with the results 
#' # for each member sepparately considered
#' str(pca.mm)
#' 
#' # The most complex situation comes from multimember multigrids:
#' data(tasmin_forecast)
#' # We interpolate using an identical grid than the previous example:
#' multimember2 <- interpGrid(tasmin_forecast, new.coordinates = getGrid(multimember))
#' # Now the multimember multigrid is constructed
#' mm.multigrid <- makeMultiGrid(multimember, multimember2)
#' pca.mm.mf <- prinComp(mm.multigrid, n.eofs = 10)
#' # Now there is a "COMBINED" element at the end of the output list
#' str(pca.mm.mf)
#' }

prinComp <- function(gridData,
                     n.eofs = NULL,
                     v.exp = NULL,
                     scaling = c("field", "gridbox"),
                     parallel = FALSE,
                     max.ncores = 16,
                     ncores = NULL) {
      if (!is.null(n.eofs) & !is.null(v.exp)) {
            warning("The 'v.exp' argument was ignored as 'n.eofs' has been indicated", call. = FALSE)
      }
      if (is.null(n.eofs) & is.null(v.exp)) {
            warning("All possible PCs/EOFs retained: This may result in an unnecessarily large object", call. = FALSE)
      }
      if (!is.null(n.eofs)) {
            v.exp <- NULL
            if (n.eofs < 1) {
                  stop("Invalid number of EOFs selected", call. = FALSE)
            }
      }
      if (!is.null(v.exp)) {
            if (!(v.exp > 0 & v.exp <= 1)) {
                  stop("The explained variance threshold must be in the range (0,1]", call. = FALSE)
            }
      }
      if (anyNA(gridData$Data)) {
            stop("There are missing values in the input data array", call. = FALSE)
      }
      scaling <- match.arg(scaling, choices = c("field", "gridbox"))
      if (length(gridData$xyCoords$x) < 2 & length(gridData$xyCoords$y) < 2) {
            stop("The dataset is not a field encompassing multiple grid-cells", call. = FALSE)
      }
      parallel.pars <- parallelCheck(parallel, max.ncores, ncores)
      dimNames <- attr(gridData$Data, "dimensions")
      if ("var" %in% dimNames) { 
            var.index <- grep("var", dimNames)
            n.vars <- dim(gridData$Data)[var.index]
            var.list <- rep(list(bquote()), n.vars)
            for (x in 1:n.vars) {                  
                  l <- asub(gridData$Data, idx = x, dims = var.index)
                  attr(l, "dimensions") <- dimNames[-var.index]
                  var.list[[x]] <- if ("member" %in% attr(l, "dimensions")) {
                        indices2 <- rep(list(bquote()), length(dim(l)))
                        mem.index <- grep("member", attr(l, "dimensions"))
                        n.mem <- dim(l)[mem.index]
                        lapply(1:n.mem, function(m) {
                              ll <- asub(l, idx = m, dims = mem.index)
                              attr(ll, "dimensions") <- attr(l, "dimensions")[-mem.index]
                              array3Dto2Dmat(ll)
                        })
                  } else {
                        list(array3Dto2Dmat(l))
                  }
            }
      } else {
            var.list <- rep(list(bquote()), 1)
            var.list[[1]] <- if ("member" %in% dimNames) { 
                  mem.index <- grep("member", dimNames)
                  n.mem <- dim(gridData$Data)[mem.index]
                  lapply(1:n.mem, function(m) {
                        ll <- asub(gridData$Data, idx = m, dims = mem.index)
                        attr(ll, "dimensions") <- attr(gridData$Data, "dimensions")[-mem.index]
                        array3Dto2Dmat(ll)
                  })
            } else {
                  list(array3Dto2Dmat(gridData$Data))
            }
      }
      # Scaling and centering
      Xsc.list <- rep(list(bquote()), length(var.list))
      if (scaling == "field") {
            for (i in 1:length(var.list)) {
                  Xsc.list[[i]] <- lapply(1:length(var.list[[i]]), function(x) {
                        mu <- mean(var.list[[i]][[x]], na.rm = TRUE)
                        sigma <- sd(var.list[[i]][[x]], na.rm = TRUE)
                        Xsc <- (var.list[[i]][[x]] - mu) / sigma
                        attr(Xsc, "scaled:center") <- mu
                        attr(Xsc, "scaled:scale") <- sigma
                        return(Xsc)
                  })
            }
      } else {
            for (i in 1:length(var.list)) {
                  Xsc.list[[i]] <- lapply(1:length(var.list[[i]]), function(x) {
                        scale(var.list[[i]][[x]], center = TRUE, scale = TRUE)
                  })
            }
      }
      var.list <- NULL      
      # Combined PCs
      if (length(Xsc.list) > 1) {
            aux.list <- rep(list(bquote()), length(Xsc.list[[1]]))
            for (i in 1:length(aux.list)) {
                  aux <- lapply(1:length(Xsc.list), function(x) Xsc.list[[x]][[i]])
                  aux.list[[i]] <- do.call("cbind", aux)
            }
            Xsc.list[[length(Xsc.list) + 1]] <- aux.list
            aux.list <- NULL
            if (length(Xsc.list[[1]]) > 1) {
                  message("[", Sys.time(), "] Performing PC analysis on ", length(Xsc.list) - 1, " variables plus their combination and ", n.mem, " members...")
            } else {
                  message("[", Sys.time(), "] Performing PC analysis on ", length(Xsc.list) - 1, " variables plus their combination...")
            }
      } else {
            if (length(Xsc.list[[1]]) > 1) {
                  message("[", Sys.time(), "] Performing PC analysis on one variable and ", n.mem, " members...")
            } else {
                  message("[", Sys.time(), "] Performing PC analysis on one variable...")
            }
      }
      #PCs
      pca.list <- rep(list(bquote()), length(Xsc.list))
      if (parallel.pars$hasparallel) {
            for (i in 1:length(pca.list)) {
                  on.exit(parallel::stopCluster(parallel.pars$cl))
                  pca.list[[i]] <- parallel::parLapply(cl = parallel.pars$cl, 1:length(Xsc.list[[i]]), function(x) {
                        # Covariance matrix
                        Cx <- cov(Xsc.list[[i]][[x]])
                        # Singular vectors (EOFs) and values
                        sv <- svd(Cx)
                        F <- sv$u
                        # F <- eigen(Cx)$vectors
                        lambda <- sv$d
                        # lambda <- eigen(Cx)$values            
                        sv <- NULL
                        # Explained variance
                        explvar <- cumsum(lambda / sum(lambda))
                        # Number of EOFs to be retained
                        if (!is.null(v.exp)) {
                              n <- findInterval(v.exp, explvar) + 1
                        } else { 
                              if (!is.null(n.eofs)) {
                                    n <- n.eofs
                              } else {
                                    n <- length(explvar)
                              }
                        }
                        F <- as.matrix(F[ ,1:n])
                        explvar <- explvar[1:n]
                        # PCs
                        PCs <- t(t(F) %*% t(Xsc.list[[i]][[x]]))
                        # ouput
                        out <- if (i < length(Xsc.list)) {
                              list("PCs" = PCs, "EOFs" = F, "orig" = Xsc.list[[i]][[x]])
                        } else {
                              list("PCs" = PCs, "EOFs" = F)
                        }
                        attr(out, "scaled:center") <- attr(Xsc.list[[i]][[x]], "scaled:center")
                        attr(out, "scaled:scale") <- attr(Xsc.list[[i]][[x]], "scaled:scale")
                        attr(out, "explained_variance") <- explvar
                        return(out)
                  })
                  attr(pca.list[[i]], "level") <- gridData$Variable$level[i]
            }
      } else {
            for (i in 1:length(pca.list)) {
                  pca.list[[i]] <- lapply(1:length(Xsc.list[[i]]), function(x) {
                        # Covariance matrix
                        Cx <- cov(Xsc.list[[i]][[x]])
                        # Singular vectors (EOFs) and values
                        sv <- svd(Cx)
                        F <- sv$u
                        # F <- eigen(Cx)$vectors
                        lambda <- sv$d
                        # lambda <- eigen(Cx)$values            
                        sv <- NULL
                        # Explained variance
                        explvar <- cumsum(lambda / sum(lambda))
                        # Number of EOFs to be retained
                        if (!is.null(v.exp)) {
                              n <- findInterval(v.exp, explvar) + 1
                        } else { 
                              if (!is.null(n.eofs)) {
                                    n <- n.eofs
                              } else {
                                    n <- length(explvar)
                              }
                        }
                        F <- as.matrix(F[ ,1:n])
                        explvar <- explvar[1:n]
                        # PCs
                        PCs <- t(t(F) %*% t(Xsc.list[[i]][[x]]))
                        # ouput
                        out <- if (i < length(Xsc.list)) {
                              list("PCs" = PCs, "EOFs" = F, "orig" = Xsc.list[[i]][[x]])
                        } else {
                              list("PCs" = PCs, "EOFs" = F)
                        }
                        attr(out, "scaled:center") <- attr(Xsc.list[[i]][[x]], "scaled:center")
                        attr(out, "scaled:scale") <- attr(Xsc.list[[i]][[x]], "scaled:scale")
                        attr(out, "explained_variance") <- explvar
                        return(out)
                  })
                  attr(pca.list[[i]], "level") <- gridData$Variable$level[i]
            }
      }
      Xsc.list <- NULL
#       # Recover field
#       Xhat <- t(F %*% t(PCs))
#       str(Xhat)
#       dim(Xsc)
#       image.plot(Xsc.list[[x]])
#       image.plot(Xhat)
      if (length(pca.list) > 1) {
            names(pca.list) <- c(gridData$Variable$varName, "COMBINED")
            attr(pca.list[[length(pca.list)]], "level") <- NULL
      } else {
            names(pca.list) <- gridData$Variable$varName 
      }
      if (length(pca.list[[1]]) > 1) {
            for (i in 1:length(pca.list)) {
                  names(pca.list[[i]]) <- gridData$Members
            }
      }
      attr(pca.list, "dates_start") <- if (is.null(names(gridData$Dates))) {
            gridData$Dates[[1]]$start   
      } else {
            gridData$Dates$start 
      }
      attr(pca.list, "scaled:method") <- scaling
      attr(pca.list, "xCoords") <- gridData$xyCoords$x
      attr(pca.list, "yCoords") <- gridData$xyCoords$y
      attr(pca.list, "yCoords") <- gridData$xyCoords$y
      attr(pca.list, "projection") <- attr(gridData$xyCoords, "projection")
      message("[", Sys.time(), "] Done")
      return(pca.list)
}
# End      
     
     



