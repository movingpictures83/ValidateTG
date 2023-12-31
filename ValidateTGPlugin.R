  #########################################################################################################################
  #########################################################################################################################
  ###### PROJECT:        DBNs
  ###### NAME:           ValidateTG.R
  ###### AUTHOR:         Daniel Ruiz-Perez, PhD Student
  ###### AFFILIATION:    Florida International University
  ###### DESCRIPTION:    Converts the graphml network into an adjacency matrix
  ######                 Also outputs an adjacency matrix with just the validated interactions
  ######                 Calculates the hypergeometric distribution values and other stats
  ######                 Does a binomial test
  #########################################################################################################################
  #########################################################################################################################
  

  library(scales)
  library(stringr)
  library("stats")
  #library(poisbinom)
  library(plotrix)
  
  options("scipen"=100, "digits"=4)

dyn.load(paste("RPluMA", .Platform$dynlib.ext, sep=""))
source("RPluMA.R")
source("RIO.R")

  TGSignCounts = F

  
  #####################################################################
  ############# CREATE ADJACENCY MATRIX FROM GRAPHML ############# 
  #####################################################################
  
  adjacencyMatrix <- function(uniqueNames, pairs){
    output = matrix(0, nrow = length(uniqueNames), ncol = length(uniqueNames)) 
    print(colnames(output))
    print(rownames(output))
    print(uniqueNames)
    print("C")
    colnames(output) = rownames(output) = uniqueNames
    print("D")
    
    #Fill in the adjacency matrix
    for (i in 1:nrow(pairs)){
      # output[grep(paste("^",pairs[i,1],"$",sep=""),uniqueNames),grep(paste("^",pairs[i,2],"$",sep=""),uniqueNames)] = 1 + output[grep(paste("^",pairs[i,1],"$",sep=""),uniqueNames),grep(paste("^",pairs[i,2],"$",sep=""),uniqueNames)]
      output[grep(paste("^",pairs[i,1],sep=""),uniqueNames),grep(paste("^",pairs[i,2],sep=""),uniqueNames)] = pairs[i,3]
    }
    #output graphml as csv
    # write.table(output,paste(nameOfNetwork,".csv",sep=""),sep=",",quote=T,col.names=NA)
    return (output)
  }
  
  
  #####################################################################
  ############# CREATE VALIDATED  ############# 
  #####################################################################
  
    ######### FILTER OUT EVERYTHING BUT TAXA - geneS
  getJustTGInteractions = function(TGDirectionCounts,pairs, taxaNewNames, namesOfgenes ){
    pairsTG = c() #Only focus on taxa-gene
    if (TGDirectionCounts){
      for (i in nrow(pairs):1){
        if ((pairs[i,1] %in% taxaNewNames && pairs[i,2] %in% namesOfgenes && pairs[i,3] > 0)){
          pairsTG = rbind(pairsTG,pairs[i,])
        }
      }
    }else{
      for (i in nrow(pairs):1){
        if ((pairs[i,1] %in% taxaNewNames && pairs[i,2] %in% namesOfgenes) || pairs[i,1] %in% namesOfgenes && pairs[i,2] %in% taxaNewNames){
          pairsTG = rbind(pairsTG,pairs[i,])
        }
      }
    }
    pairsTG = unique(pairsTG)
  return(pairsTG)
  }
  
    
    
  # Calculate the genes that have interactions with our taxa
  retrieveRelevanTGenes = function(validTG, namesOfgenes ){
    relevanTGenes = c()
    for (geneList in validTG$ValidGenes){
      relevanTGenes = paste(relevanTGenes,geneList,sep="|")
    }
    relevanTGenes = unique(strsplit(relevanTGenes,("\\|"))[[1]])
    relevanTGenes = relevanTGenes[-which(relevanTGenes %in% "")]
    #Intersect with the genes in the network
    relevanTGenes = intersect(relevanTGenes,namesOfgenes)
    return (relevanTGenes)
  }
  
  
    #VALIDATE INTERACTIONS USING KEGG DATABASE FILE
  computeValidatedInteractions = function(output,uniqueNames, clinical, TGDirectionCounts, validTG, relevanTGenes, taxaNewNames, namesOfgenes){
    found = c()
    numberOfTGValidated = 0
    numberOfTGNotValidated = 0
    interactionsValidated = c()
    interactionsNOTValidated = c()
    taxaNotFound = c()
    genesNotInteresting = c()
    outputValidated = output
    totalTGInteractions = 0
    for (i in 1:nrow(output)){
      for (j in 1:ncol(output)){
        #if (output[i,j] != 0){
          # if (uniqueNames[j] %in% "hmdb03357"){
            # print(uniqueNames[i])
            # print(uniqueNames[j])
          #   print("here")
          # }
  
          #If any one is clinical, no interested
          if (uniqueNames[i] %in% clinical || uniqueNames[j] %in% clinical){
            next
          }
          #If it is taxa-taxa, continue
          if (uniqueNames[i] %in% taxaNewNames && uniqueNames[j] %in% taxaNewNames){
            next
          }
          #If it is gene-gene, continue
          if (uniqueNames[i] %in% namesOfgenes && uniqueNames[j] %in% namesOfgenes){
            next
          }
          #Assign the taxa and the gene to the correct variable
          if(uniqueNames[i] %in% namesOfgenes){
            gene = uniqueNames[i]
            taxa = uniqueNames[j]
            if(TGDirectionCounts){
              print(paste("Wrong direction: ",uniqueNames[i], "->" , uniqueNames[j] , "NOT Validated"))
              next
            }
          }else{
            gene = uniqueNames[j]
            taxa = uniqueNames[i]
          }

          coefficient = as.numeric(output[i,j])
          if (TGDirectionCounts && TGSignCounts && coefficient <0){
            print(paste("Wrong sign: ",uniqueNames[i], "->" , uniqueNames[j] , "NOT Validated"))
            next
          }
          
          #Check if the taxa is found
          indexTaxa = grep(tolower(taxa), tolower(validTG$SpeciesName)) #CAREFUL WITH FRAGMENTFOUNDINKEGG
          if (length(indexTaxa) == 0){
            # print(paste("TAXA NOT FOUND IN KEGG DATABASE:",taxa))
            taxaNotFound = c(taxaNotFound,taxa)
            next
          }
          
          #Check if the gene is relevant
          if (!gene %in% relevanTGenes){
            # print(paste("gene not relevant: ",gene))
            genesNotInteresting = c(genesNotInteresting,gene)
            next
          }
  
          #see if the gene is related to the taxa in the database
          if (length(grep(gene, validTG$ValidGenes[indexTaxa]))>0){
            print(paste("VALIDATED: ",uniqueNames[i],uniqueNames[j]))
            interactionsValidated = rbind(interactionsValidated,c(taxa,gene,output[i,j]))
            found= cbind(found,paste(taxa,gene,sep=" - "))
            outputValidated[i,j] = output[i,j]
            numberOfTGValidated = numberOfTGValidated+1
            }else{
              # print(paste("Not validated: ",uniqueNames[i],uniqueNames[j]))
              numberOfTGNotValidated = numberOfTGNotValidated+1
              outputValidated[i,j] = 0
              interactionsNOTValidated = rbind(interactionsNOTValidated,c(taxa,gene,output[i,j]))
              
          }
        #}
      }
    }
    taxaNotFound = unique(taxaNotFound)
    genesNotInteresting = unique(genesNotInteresting)
    print(paste("There are:", numberOfTGNotValidated,"NOT Validated interactions by the DB"))
    print(paste("There are:", numberOfTGValidated,"Validated interactions by the DB"))
    
    # if (numberOfTGValidated == 0 && numberOfTGNotValidated == 0)
    #   next
  
    return(list(numberOfTGValidated = numberOfTGValidated, numberOfTGNotValidated = numberOfTGNotValidated, interactionsValidated = interactionsValidated, interactionsNOTValidated = interactionsNOTValidated, found = found))
    
  }

  
  #####################################################################
  ############# VALIDATED INTERACTIONS FOR THIS SET OF TAXA ############# 
  #####################################################################
  
  #compute the total number of possible interactions║
  computeNumberOfPossibleInteractions  = function(validTG, taxaNewNames, found){
    
    validTGAux = validTG
    indexTaxaValid = c()
    genes = c()
    for (i in 1:length(taxaNewNames)){
      index =  grep(taxaNewNames[i], validTGAux$SpeciesName)
      #get the taxa that are relevant to us
      indexTaxaValid = c(indexTaxaValid,index)
      #get the genes that are relevant to us
      genes = unlist(strsplit(validTGAux[index,]$ValidGenes,("\\|")))
      if (length(intersect(genes,namesOfgenes))!= length(genes)){
        # print(index)
      }
      validTGAux$ValidGenes[index] = paste(intersect(genes,namesOfgenes), collapse = '|')
    }
    validgenes = validTGAux[indexTaxaValid,]$ValidGenes
    strValidgenes = paste(validgenes, collapse = '|')
    # write.table(validTGAux[indexTaxaValid,],paste("validTGAux.csv",sep=""),sep=",",quote=F,col.names=NA)
    
    #Now compute the total number of validated interactions in the database, EXCEPT for taxa and genes not in the networks
    validgenes = strsplit(paste(validgenes, collapse = '|'),"\\|")[[1]]
    blank = which(validgenes %in% "")
    if (length(blank)>0)
      validgenes = validgenes[-blank]
    nTotalValidatedInteractionsOfJustOurData = length(validgenes)
    nTotalValidatedInteractions = length(validgenes)
    
    # #Now compute the total number of validated interactions in the database, even for taxa and genes not in the networks
    validgenesInteraction = validTGAux$ValidGenes
    validgenesInteraction = strsplit(paste(validgenesInteraction, collapse = '|'),"\\|")[[1]]
    blank = which(validgenesInteraction %in% "")
    if (length(blank)>0)
      validgenesInteraction = validgenesInteraction[-blank]
    # nTotalValidatedInteractions = length(validgenesInteraction)
    
    
    #For every validated interaction in the network, count the number of taxa with which that gene interacts with
    count = c()
    for (interaction in found ){
      gene = strsplit(interaction[[1]]," - ")[[1]][2]
      count = c(count,sum(str_count(validgenesInteraction, gene)))
    }
    if (length(count) > 0) hist(count)
    
    return(count)
  }
  
  
  ###############################################
  ############################################### BINOMIAL
  ###############################################
  binomialTest <- function(relevanTGenes, validTG, taxaNewNames, namesOfTaxa, namesOfgenes, numberOfTGValidated, numberOfTGNotValidated, interactionsValidated, interactionsNOTValidated){
    print("DOING BINOMIAL")
   
    # Calculate the probability of a gene being associated with a taxa, based on the validation file for
    # our genes and our taxa
    #Iterate over the mets
    probabilityTable = c()
    for (met in relevanTGenes){
      possibleTaxaInteractions = 0
      actualTaxaInteractions = 0
      #For every valid interaction
      for (i in 1:nrow(validTG)){
        #If it is one of our taxa
        if (validTG$SpeciesName[i] %in% taxaNewNames){
          possibleTaxaInteractions = possibleTaxaInteractions+1
          if (met %in% strsplit(validTG$ValidGenes[i],"\\|")[[1]]){
            actualTaxaInteractions = actualTaxaInteractions+1
          }
        }
      }
      # possibleTaxaInteractions = length(taxaNewNames)
      # probabilityTable = rbind(probabilityTable,c(met,actualTaxaInteractions,possibleTaxaInteractions,actualTaxaInteractions/possibleTaxaInteractions))
      probabilityTable = rbind(probabilityTable,c(met,actualTaxaInteractions,possibleTaxaInteractions,actualTaxaInteractions/length(taxaNewNames)))
      }
    print(probabilityTable)
    print(dimnames(probabilityTable))
    print("A")
    colnames(probabilityTable) = c("gene","actualTaxaInteractions","possibleTaxaInteractions","probability")
    print("B")
    print("probabilityTable") 
    print(probabilityTable) 
    print("interactionsValidated")
    print(interactionsValidated)
    print("interactionsNOTValidated")
    print(interactionsNOTValidated)
    
    if (length(interactionsValidated) == 0){
      probBin = 1
    }else{
      #calculate probabilities for the trials
      allInteractions = rbind(interactionsValidated,interactionsNOTValidated)
      probabilityVector = c()
      for (i in 1:nrow(allInteractions)){
        met = allInteractions[i,2]
        for (j in 1:nrow(probabilityTable)){
          if (probabilityTable[j,1] %in% met){
            probabilityVector = c(probabilityVector,probabilityTable[j,4])
          }
        }
      }
      probabilityVector = as.numeric(probabilityVector)
      # probBin = dpoisbinom(numberOfTGValidated,probabilityVector)
      #probBin = tryCatch({
      #probBin = ppoisbinom(numberOfTGValidated,probabilityVector,lower_tail=F)
      #}, error = function(e) {
      #  1
      #})
    }
    
    FN = 0    # fn = not in the network, but in the database
    for (row in  validTG$ValidGenes){
      FN = FN + str_count(row,"|")+1
    }
    precision = numberOfTGValidated / (numberOfTGValidated+numberOfTGNotValidated) # (tp)/(tp+fp)
    recall = numberOfTGValidated / (numberOfTGValidated+FN)# (tp)/(tp+fn)

    
    writeBinomial = c(length(namesOfTaxa),possibleTaxaInteractions,length(namesOfgenes),length(relevanTGenes),numberOfTGValidated, numberOfTGNotValidated,precision, recall)#, round(probBin,30))
    names(writeBinomial) = c("Taxa","TaxaFoundInValidationDB","Genes","GenesFoundInValidationDB", "TP","FP","Precision","Recall")#,"Pr(validated>=TP)")
    print(writeBinomial)
    return(writeBinomial)
  }
  


  
  
  
  
  
  
  ##################### FUNCTION CALLS
  
input <- function(inputfile) {  
  TGDirectionCounts = T
  
  clinical = tolower(c("Week sample obtained"))
  folder = "" #"Demo" #"finalFiguresBootscore" #"finalFiguresBootscore"
  #setwd(folder)

  parameters = readParameters(inputfile)
  pfix = prefix()
  nameOfNetwork = paste(pfix, parameters["nameOfNetwork", 2], sep="/")  
  #nameOfNetwork = "human_ibd_microbiota_genes_metabolites_dbn_sample_alignment_sr14d_top100x100_host_genes_reference_dbnIntraBoot.graphml"

  #nameOfNetwork = paste(folder,"Networks/HEGTM_Skeleton//3Parents/human_ibd_microbiota_genes_metabolites_dbn_sample_alignment_sr14d_top100x100_host_metabolites_reference_dbnIntraBoot.graphml",sep="")
  #nameOfNetwork = paste(folder,"Networks/HEGTM_Skeleton//3Parents/human_ibd_microbiota_genes_metabolites_dbn_sample_alignment_sr14d_top100x100_host_taxa_reference_dbnIntraBoot.graphml",sep="")
  #nameOfNetwork = paste(folder,"Networks/HEGTM_Skeleton//3Parents/human_ibd_microbiota_genes_metabolites_dbn_sample_noalignment_sr14d_top100x100_host_genes_reference_dbnIntraBoot.graphml",sep="")
  #nameOfNetwork = paste(folder,"Networks/HEGTM_Skeleton//3Parents/human_ibd_microbiota_genes_metabolites_dbn_sample_noalignment_sr14d_top100x100_host_metabolites_reference_dbnIntraBoot.graphml",sep="")
  #nameOfNetwork = paste(folder,"Networks/HEGTM_Skeleton//3Parents/human_ibd_microbiota_genes_metabolites_dbn_sample_noalignment_sr14d_top100x100_host_taxa_reference_dbnIntraBoot.graphml",sep="")
  
  
  
  network = tryCatch({
    readChar(nameOfNetwork, file.info(nameOfNetwork)$size)
  }, warning = function(e) {
    ""
  }, error = function(e) {
    ""
  })
  if (network == "")
    print("WARN")
  


  
  #####################################################################
  ############# LOAD INFORMATION FROM  GRAPHML NETWORK ############# 
  #####################################################################
  
  #READ NETWORK
  network =  gsub("\\(", "", gsub("\\)", "",gsub("\\[", "", gsub("\\]","",gsub("t0", "ti", gsub("tn", "ti+1", tolower(unlist(strsplit(x =network, "\r?\n")))))))))
  network = gsub("\n<data key=\"key_bootscore\">[0-9]*\\.[0-9]*</data>\n","",network)
  newNetwork = network[grep(pattern = paste(".*target=\".*_ti\\+1\">","",sep=""), x = network, ignore.case = T)]
  newNetwork = gsub("s__", "", gsub("\\(", "", gsub("\\)", "", gsub("\\[", "", gsub("\\]", "", gsub("_ti", "", gsub("\\+1", "",  gsub("\">", "", gsub("g__", "", gsub("<edge id=\"e\\d*\" source=\"", "", newNetwork))))))))))
  
  #Remove everything that has to do with metabolites
  newNetwork = newNetwork[setdiff(1:length(newNetwork),grep(".*m__.*",newNetwork))]
  newNetwork = newNetwork[setdiff(1:length(newNetwork),grep(".*hg.__.*",newNetwork))]
  
  #get the names of taxa
  namesOfTaxa = network[grep("<node id=\\\"s__.*",network)]
  namesOfTaxa = unique(gsub("_ti", "", gsub("\\+1", "", gsub("\\\"/>", "", gsub("<node id=\\\"", "", gsub("s__", "", namesOfTaxa))))))
  taxaNewNames = gsub("_"," ",namesOfTaxa)
  
  #get the names of genes
  namesOfgenes = network[grep("<node id=\\\"g__.*",network)]
  namesOfgenes = unique(gsub("_ti", "", gsub("\\+1", "", gsub("\\\"/>", "", gsub("<node id=\\\"", "", gsub("g__", "", namesOfgenes))))))
  namesOfgenes = gsub("_"," ",namesOfgenes)
  
  #get the weight of the edges
  edgeWeight = network[grep("<data key=\\\"key_weight.*",network)]
  edgeWeight = as.numeric(gsub("\"", "", gsub("<data key=\\\"key_weight\\\">", "", gsub("</data>", "", edgeWeight)))) 
  
  #get the bootscore of the edges
  edgeBootscore = network[grep("<data key=\\\"key_bootscore.*",network)]
  edgeBootscore = as.numeric(gsub("\"", "", gsub("<data key=\\\"key_bootscore\\\">", "", gsub("</data>", "", edgeBootscore)))) 
  
  
  #Extract the information from the network
  pairs = c()
  for (i in 1:length(newNetwork)){
    edge =  c(trimws(strsplit(newNetwork[i],"\" target=\"")[[1]], which ="both"),edgeWeight[i],edgeBootscore[i])
    pairs = rbind(pairs,edge)
  }
  uniqueNames = gsub("\\\\", "", gsub("_unclassified", "", gsub("_noname", "", unique(c(pairs[,1],pairs[,2])))))
  
  #Replace the new taxa names into the final all names
  for (i in 1:length(namesOfTaxa)){
    for (j in 1:length(uniqueNames)){
      if (namesOfTaxa[i] == uniqueNames[j]){
        uniqueNames[j] = taxaNewNames[i]
      }
    }
  }

  #Replace the new taxa genus names into the map pairs fil
  for (i in 1:length(namesOfTaxa)){
    for (j in 1:nrow(pairs)){
      if (namesOfTaxa[i] == as.character(pairs[j,1])){
        pairs[j,1] = taxaNewNames[i]
      }
      if (namesOfTaxa[i] == as.character(pairs[j,2])){
        pairs[j,2] = taxaNewNames[i]
      }
    }
  }

  #Read validation database file
  validTG = read.csv(paste(pfix, parameters["taxaToGenes", 2], sep="/"), sep = "$")
  validTG$SpeciesName = tolower(as.character(validTG$SpeciesName))
  validTG$ValidGenes = tolower(as.character(validTG$EnzymeNames))
  validTG$ValidGenes = gsub("\\(", "", gsub("\\)", "",gsub("\\[", "", gsub("\\]", "", tolower(as.character(validTG$EnzymeNames))))))
  
  #Make sure the validation database is not too big
  validTG = validTG[which(validTG$SpeciesName %in% taxaNewNames),]
  
  #Compute the genes that are both in the network and validation file
  relevanTGenes = retrieveRelevanTGenes(validTG, namesOfgenes)
  
  # pairsTG = getJustTGInteractions(TGDirectionCounts,pairs, taxaNewNames, namesOfgenes)
  output = adjacencyMatrix(uniqueNames, pairs)
  
  # computeNumberOfPossibleInteractions (validTG, taxaNewNames, found)
  
  validationResult = computeValidatedInteractions(output,uniqueNames, clinical, TGDirectionCounts, validTG, relevanTGenes, taxaNewNames, namesOfgenes)
    numberOfTGValidated = validationResult$numberOfTGValidated
    numberOfTGNotValidated = validationResult$numberOfTGNotValidated
    interactionsValidated = validationResult$interactionsValidated
    interactionsNOTValidated = validationResult$interactionsNOTValidated
    found = validationResult$found
  
  # binomialTest(relevanTGenes, validTG, taxaNewNames, namesOfTaxa, namesOfgenes, numberOfTGValidated, numberOfTGNotValidated, interactionsValidated, interactionsNOTValidated)
  
  
  
  

  ######
  # Uncomment this to do the precission-recall curve
  binomialTotal = c()
  for (t in seq(0.05,1,0.05)){
    print(t)
    outputThresholdPairsTG = adjacencyMatrix(uniqueNames, pairs[as.numeric(pairs[,4]) >= t,])
    validationResult = computeValidatedInteractions(outputThresholdPairsTG,uniqueNames, clinical, TGDirectionCounts, validTG, relevanTGenes, taxaNewNames, namesOfgenes)
      numberOfTGValidated = validationResult$numberOfTGValidated
      numberOfTGNotValidated = validationResult$numberOfTGNotValidated
      interactionsValidated = validationResult$interactionsValidated
      interactionsNOTValidated = validationResult$interactionsNOTValidated
      found = validationResult$found
      
    binomial = binomialTest(relevanTGenes, validTG, taxaNewNames, namesOfTaxa, namesOfgenes, numberOfTGValidated, numberOfTGNotValidated, interactionsValidated, interactionsNOTValidated)
    binomialTotal = rbind(binomialTotal,c(binomial,t))
  }
  print("E")
  #colnames(binomialTotal)[10] = "t"
  print("F")
}

run <- function() {}

output <- function(ofile) {
  outputFile = ofile
  write.table(binomialTotal, outputFile, sep=",", append=TRUE, row.names = F,quote=F)
  
  #add a row to the output file
  # if(!file.exists(outputFile)){
  #   write.csv(binomialTotal, outputFile,row.names = F,quote=F) 
  # }else{
  #   write.table(binomialTotal, outputFile, sep=",", append=TRUE, col.names=FALSE, row.names = F,quote=F)
  # }
  
  binomialTotal = as.data.frame(binomialTotal)
  write.table(binomialTotal, file = "",append = TRUE, sep = "\t",  quote=FALSE)
  
  plot(binomialTotal$Precision, binomialTotal$Recall, type="b",main = "Precision-Recall", xlab = "Precision", ylab="Recall")
  
  # gap.plot( binomialTotal$t,binomialTotal$`Pr(validated>=TP)`,ytics = c(0,0.05,0.1,0.2,1), gap=c(0.25,0.98), type="b",main = "Cumulative distribution function", xlab = "t", ylab="Pr(validated>=TP)")
  #plot(binomialTotal$t,binomialTotal$`Pr(validated>=TP)`, type="b",main = "Cumulative distribution function", xlab = "t", ylab="Pr(validated>=TP)")
  
}
  
