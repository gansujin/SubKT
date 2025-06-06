# Copyright 2022 Observational Health Data Sciences and Informatics
#
# This file is part of epi
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

synthesizePositiveControls <- function(connectionDetails,
                                       cdmDatabaseSchema,
                                       cohortDatabaseSchema,
                                       cohortTable = "cohort",
                                       tempEmulationSchema,
                                       outputFolder,
                                       maxCores = 1) {
  
  
  synthesisFolder <- file.path(outputFolder, "positiveControlSynthesis")
  if (!file.exists(synthesisFolder))
    dir.create(synthesisFolder)
  
  synthesisSummaryFile <- file.path(outputFolder, "SynthesisSummary.csv")
  if (!file.exists(synthesisSummaryFile)) {
    pathToCsv <- system.file("settings", "NegativeControls.csv", 
                             package = "epi")
    negativeControls <- read.csv(pathToCsv)
    exposureOutcomePairs <- data.frame(exposureId = negativeControls$targetId,
                                       outcomeId = negativeControls$outcomeId)
    exposureOutcomePairs <- unique(exposureOutcomePairs)
    pathToJson <- system.file("settings", "positiveControlSynthArgs.json", 
                              package = "epi")
    args <- ParallelLogger::loadSettingsFromJson(pathToJson)
    args$control$threads <- min(c(10, maxCores))
    
    # Using deprecated function to conform to current JSON specs:
    result <- MethodEvaluation::injectSignals(
      connectionDetails = connectionDetails,
      cdmDatabaseSchema = cdmDatabaseSchema,
      oracleTempSchema = tempEmulationSchema,
      exposureDatabaseSchema = cohortDatabaseSchema,
      exposureTable = cohortTable,
      outcomeDatabaseSchema = cohortDatabaseSchema,
      outcomeTable = cohortTable,
      outputDatabaseSchema = cohortDatabaseSchema,
      outputTable = cohortTable,
      createOutputTable = FALSE,
      exposureOutcomePairs = exposureOutcomePairs,
      workFolder = synthesisFolder,
      modelThreads = max(1, round(maxCores/8)),
      generationThreads = min(6, maxCores),
      # External args start here
      outputIdOffset = args$outputIdOffset,
      firstExposureOnly = args$firstExposureOnly,
      firstOutcomeOnly = args$firstOutcomeOnly,
      removePeopleWithPriorOutcomes = args$removePeopleWithPriorOutcomes,
      modelType = args$modelType,
      washoutPeriod = args$washoutPeriod,
      riskWindowStart = args$riskWindowStart,
      riskWindowEnd = args$riskWindowEnd,
      addExposureDaysToEnd = args$addExposureDaysToEnd,
      effectSizes = args$effectSizes,
      precision = args$precision,
      prior = args$prior,
      control = args$control,
      maxSubjectsForModel = args$maxSubjectsForModel,
      minOutcomeCountForModel = args$minOutcomeCountForModel,
      minOutcomeCountForInjection = args$minOutcomeCountForInjection,
      covariateSettings = args$covariateSettings
      # External args stop here
    )
    write.csv(result, synthesisSummaryFile, row.names = FALSE)
  } else {
    result <- read.csv(synthesisSummaryFile)
  }
  ParallelLogger::logTrace("Merging positive with negative controls ")
  pathToCsv <- system.file("settings", "NegativeControls.csv", 
                           package = "epi")
  negativeControls <- read.csv(pathToCsv)
  
  synthesisSummary <- read.csv(synthesisSummaryFile)
  synthesisSummary$targetId <- synthesisSummary$exposureId
  synthesisSummary <- merge(synthesisSummary, negativeControls)
  synthesisSummary <- synthesisSummary[synthesisSummary$trueEffectSize != 0, ]
  synthesisSummary$outcomeName <- paste0(synthesisSummary$OutcomeName, ", RR=", synthesisSummary$targetEffectSize)
  synthesisSummary$oldOutcomeId <- synthesisSummary$outcomeId
  synthesisSummary$outcomeId <- synthesisSummary$newOutcomeId
  
  pathToCsv <- system.file("settings", "NegativeControls.csv", 
                           package = "epi")
  negativeControls <- read.csv(pathToCsv)
  negativeControls$targetEffectSize <- 1
  negativeControls$trueEffectSize <- 1
  negativeControls$trueEffectSizeFirstExposure <- 1
  negativeControls$oldOutcomeId <- negativeControls$outcomeId
  allControls <- rbind(negativeControls, synthesisSummary[, names(negativeControls)])
  write.csv(allControls, file.path(outputFolder, "AllControls.csv"), row.names = FALSE)
}
