#' @title Process the HLA alignement type for type (nuc, prot, gen) in a
#' directory.
#'
#' @description TODO
#'
#' @param hlaDbPath the path to the directory of the alignment file from
#' \url{http://hla.alleles.org/alleles/text_index.html}
#'
#' @param seqType a \code{character} string, the sequence type of the file to
#' parse. The choices are: "nuc" for CDS sequence, "gen" for genomic, and
#' "prot" for protein. Default: "nuc".
#'
#' @return an object of class \code{HLAdb}
#'
#' @details TODO
#'
#' @examples
#'
#' ## TODO
#'
#' @author Pascal Belleau
#' @importFrom data.table data.table
#' @export

parseHLADbAlignment <- function(hlaDbPath, seqType=c("nuc", "gen", "prot")) {

    ## Validate that the sequence type is known
    if(! seqType %in% c("nuc", "gen", "prot")) {
        stop(paste0("Not validate sequence type for parseHLADbAlignment",
                        seqType, "\n"))
    }

    files <- dir(path = hlaDbPath, pattern = paste0("*_", seqType, ".txt"))

    HLAdb <- list(refSeq=list(), posInit=list(), HLAAlignment=data.table())
    refSeq <- list()
    posInit <- list()
    HLAAlignment <- list()
    for(fileName in files) {
        tmp <- parseAlignment(paste0(hlaDbPath, "/", fileName))
        geneName <- gsub(paste0("_", seqType), "", fileName)
        refSeq[[geneName]] <- tmp$refSeq
        posInit[[geneName]] <- tmp$posInit
        HLAAlignment[[geneName]] <- tmp$HLAalignment
    }

    ## Create object to return
    HLAdb <- list(refSeq=refSeq, posInit=posInit,
                  HLAAlignment=rbindlist(HLAAlignment))
    class(HLAdb) <- "HLAdb"
    return(HLAdb)

}

#' @title Pre-process HLA alignment file.
#'
#' @description TODO
#'
#' @param fileName the name of the alignment file from
#' \url{http://hla.alleles.org/alleles/text_index.html}
#'
#' @return an object of class \code{HLAGene}
#'
#' @details TODO
#'
#' @examples
#'
#' ## TODO
#'
#' @author Pascal Belleau
#' @importFrom data.table data.table
#' @export
parseAlignment <- function(fileName) {
    # Position where the sequence start
    startPosFile <- 20
    maxTyping <- 50000

    allLines <- readLines(fileName)
    listPos <- NULL
    seqType <- NULL

    # Find which type of alignment Prot, cDNA or gDNA
    # get the position of the reference

    for(curType in c("Prot", "cDNA", "gDNA")){

        listPos <- grep(curType, allLines)
        if(length(listPos) > 0){
            seqType <- curType
            break;
        }
    }
    offSet <- ifelse(seqType == "cDNA", 1,0)
    cpt <- listPos[1] + 2 + offSet

    while(cpt < maxTyping){
        if(regexpr("[A-Z]", allLines[cpt], perl=TRUE)[1] == -1){
            break
        }
        cpt <- cpt + 1
    }
    if(cpt == maxTyping){
        stop(paste0("The program reach the max of typing in ", fileName), "\n")
    }
    nbType <- cpt - listPos[1] + 2 + offSet

    # The reference sequence
    refSeq <- ""

    # data.table of each type with a representation of the diffence
    # between the sequence and the reference.

    HLAalignment <- data.table(GeneName=character(nbType),
                               AlleleGroup=character(nbType),
                               Protein=character(nbType),
                               SynSubst=character(nbType),
                               Noncoding=character(nbType),
                               Suffix=character(nbType),
                               SeqDiff=character(nbType))

    # Loop on the position in allLine of the sequence type
    # before the reference sequence
    # The reference sequence position is + 2 + offSet
    for(startLine in listPos){
        # Get the initial position of the sequence
        i <- 1
        s <- substr(allLines[startLine + offSet],startPosFile,startPosFile)
        posInit <- ""
        while(s != " " && s != ""){
            posInit <- paste0(posInit, s)
            s <- substr(allLines[startLine + offSet],startPosFile + i,
                        startPosFile + i)
            i<-i+1
        }
        posInit <- as.integer(posInit)

        # The reference sequence
        startSeq <- startLine + 2 + offSet
        parseRef <- extractRef(allLines[startSeq], startPosFile)
        refSeq <- paste0(refSeq, parseRef$refSeq)

        # Parse the type of the reference sequence
        if(startLine == listPos[1]){
            nameTyping <- extractTyping(allLines[startSeq],startPosFile)
            curTyping <- splitTyping(nameTyping)
            HLAalignment$GeneName[1] <- curTyping[1]
            HLAalignment$AlleleGroup[1] <- curTyping[2]
            HLAalignment$Protein[1] <- curTyping[3]
            HLAalignment$SynSubst[1] <- curTyping[4]
            HLAalignment$Noncoding[1] <- curTyping[5]
            HLAalignment$Suffix[1] <- curTyping[6]
        }

        HLAalignment$SeqDiff[1] <- paste0(
            HLAalignment$SeqDiff[1],
            parseRef$seqDiff)


        cpt <- startSeq + 1

        # loop on all type for thee current portion of the
        # sequence
        while(cpt < maxTyping){
            seqCur <- allLines[cpt]
            if(regexpr("[A-Z]", seqCur, perl=TRUE)[1] >= 1){
                nameTyping <- extractTyping(seqCur, startPosFile)
                # parse the typing
                curTyping <- splitTyping(nameTyping)
                # get the position of the typing in
                # HLAalignment
                typingPos <- getTypingPos(HLAalignment, curTyping)

                if(length(typingPos) == 0){
                    # If the typing is not initialise
                    HLAalignment$GeneName[cpt - startSeq + 1] <- curTyping[1]
                    HLAalignment$AlleleGroup[cpt - startSeq + 1] <- curTyping[2]
                    HLAalignment$Protein[cpt - startSeq + 1] <- curTyping[3]
                    HLAalignment$SynSubst[cpt - startSeq + 1] <- curTyping[4]
                    HLAalignment$Noncoding[cpt - startSeq + 1] <- curTyping[5]
                    HLAalignment$Suffix[cpt - startSeq + 1] <- curTyping[6]
                    HLAalignment$SeqDiff[cpt - startSeq + 1] <- paste0(
                        HLAalignment$SeqDiff[cpt - startSeq + 1],
                        extractSeq(seqCur, startPosFile))

                }else if(length(typingPos) == 1){
                    # if the typing is initialize just
                    # add the diff seq
                    HLAalignment$SeqDiff[typingPos] <- paste0(
                        HLAalignment$SeqDiff[typingPos],
                        extractSeq(seqCur, startPosFile))
                }
            } else {
                # stop the loop if line without [A-Z]
                break
            }
            cpt <- cpt + 1
        }

        # Just to prevent infinite loop
        if(cpt == maxTyping){
            stop(paste0("The program reach the max of typing in ",
                        fileName, "\n"))
        }
    }

    HLAGene <- list(refSeq=refSeq, posInit=posInit, HLAalignment=HLAalignment)

    class(HLAGene) <- "HLAGene"
    return(HLAGene)
}

#' @title Process the line contening the ref seq
#'
#' @description TODO
#'
#' @param seq a \code{string} contening the reference sequence.
#'
#' @param startPos a \code{integer} corresponding to the position in the string
#' where the sequence is starting
#'
#' @return a \code{list} with two fields. The first is \code{refSeq} which is
#' containing the sequence of the reference. The second is seqDiff is a
#' \code{string} representing the alignment format for the current sequence.
#'
#' @examples
#'
#' ## TODO
#'
#' @author Pascal Belleau
#' @keywords internal
extractRef <- function(seq, startPos){

    tmpSeq <- substr(seq, startPos, nchar(seq))

    refSeq <-""
    seqDiff <- ""
    flag <- TRUE

    for(i in seq_len(nchar(tmpSeq))){
        b <- substr(tmpSeq, startPos-1+i, startPos-1+i)
        if(flag){
            refSeq <- paste0(refSeq, b)

            if(b != " "){
                seqDiff <- paste0(seqDiff, "-")
                flag=FALSE
            } else{
                seqDiff <- paste0(seqDiff, " ")
            }
        } else{
            if(b != " "){
                refSeq <- paste0(refSeq, b)
                if(regexpr("[A-Z]", b, perl=TRUE)[1] >= 1){
                    seqDiff <- paste0(seqDiff, "-")
                } else{
                    seqDiff <- paste0(seqDiff, b)
                }
            }
        }
    }
    return(list(refSeq=refSeq, seqDiff=seqDiff))
}

#' @title Process the line contening the alignment to the reference
#'
#' @description TODO
#'
#' @param seq A \code{string} contening the reference sequence.
#'
#' @param startPos A \code{integer} corresponding to the position in the string
#' where the sequence is starting
#'
#' @return TODO
#'
#' @examples
#'
#' ## TODO
#'
#' @author Pascal Belleau
#' @keywords internal
extractSeq <- function(seq, startPos){

    tmpSeq <- substr(seq, startPos, nchar(seq))

    seqDiff <- ""
    flag <- TRUE

    for(i in seq_len(nchar(tmpSeq))){
        b <- substr(tmpSeq, startPos-1+i, startPos-1+i)
        if(flag){
            seqDiff <- paste0(seqDiff, b)
            if(b != " "){
                flag=FALSE
            }
        } else{
            if(b != " "){
                seqDiff <- paste0(seqDiff, b)
            }
        }
    }
    return(seqDiff)
}


#' @title Extract the typing string from line contening the alignment
#'
#' @description TODO
#'
#' @param seq a \code{string} contening the sequence.
#'
#'
#' @return TODO
#'
#' @examples
#'
#' ## TODO
#'
#' @author Pascal Belleau
#' @keywords internal
extractTyping <- function(seq, endPos){

    tmpSeq <- substr(seq, 2, endPos)

    flag <- TRUE
    nameTyping <- ""
    for (i in seq_len(nchar(tmpSeq))) {
        b <- substr(tmpSeq, i, i)
        if(b != " ") {
            nameTyping <- paste0(nameTyping, b)
        }
        else {
            break
        }

    }
    return(nameTyping)
}


#' @title TODO
#'
#' @description TODO
#'
#' @param seq a \code{string} contening the sequence.
#'
#'
#' @return TODO
#'
#' @examples
#'
#' ## TODO
#'
#' @author Pascal Belleau
#' @keywords internal
getTypingPos <- function(seqProcess, curTyping){

    if(is.na(curTyping[4])){
        curPos <- which(seqProcess$GeneName == curTyping[1] &
                        seqProcess$AlleleGroup == curTyping[2] &
                        seqProcess$Protein == curTyping[3] &
                        is.na(seqProcess$SynSubst))
    } else if(is.na(curTyping[5])){
        curPos <- which(seqProcess$GeneName == curTyping[1] &
                        seqProcess$AlleleGroup == curTyping[2] &
                        seqProcess$Protein == curTyping[3] &
                        seqProcess$SynSubst == curTyping[4] &
                        is.na(seqProcess$Noncoding) )
    } else if(is.na(curTyping[6])){
        curPos <- which(seqProcess$GeneName == curTyping[1] &
                            seqProcess$AlleleGroup == curTyping[2] &
                            seqProcess$Protein == curTyping[3] &
                            seqProcess$SynSubst == curTyping[4] &
                            seqProcess$Noncoding == curTyping[5] &
                            is.na(seqProcess$Suffix) )
    } else {
        curPos <- which(seqProcess$GeneName == curTyping[1] &
                        seqProcess$AlleleGroup == curTyping[2] &
                        seqProcess$Protein == curTyping[3] &
                        seqProcess$Noncoding == curTyping[4] &
                        seqProcess$Noncoding == curTyping[6] &
                        seqProcess$Suffix == curTyping[7] )
    }

    return(curPos)
}
