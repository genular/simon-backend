#* Generate t-SNE plot
#* @serializer contentType list(type='image/png')
#' @post /plots/editing/tsne/renderPlot
simon$handle$plots$editing$tsne$renderPlot <- expression(
    function(req, res, ...){
        args <- as.list(match.call())

        res.data <- list(
            tsne_plot = list(
                main_plot = NULL
            ), 
            tsne_cluster_plot = NULL, tsne_cluster_plot_png = NULL, 
            tsne_cluster_heatmap_plot = NULL, tsne_cluster_heatmap_plot_png = NULL
        )


        selectedFileID <- 0
        if("selectedFileID" %in% names(args)){
            selectedFileID <- as.numeric(args$selectedFileID)
        }
        settings <- NULL
        if("settings" %in% names(args)){
            settings <- jsonlite::fromJSON(args$settings)
        }

        if(is_var_empty(settings$selectedColumns) == TRUE){
            settings$selectedColumns = NULL
        }

        if(is_var_empty(settings$excludedColumns) == TRUE){
            settings$excludedColumns = NULL
        }

        if(is_var_empty(settings$groupingVariables) == TRUE){
            settings$groupingVariables = NULL
        }

        if(is_var_empty(settings$colorVariables) == TRUE){
            settings$colorVariables = NULL
        }

        if(is_var_empty(settings$preProcessDataset) == TRUE){
            settings$preProcessDataset = NULL
        }

        if(is_var_empty(settings$fontSize) == TRUE){
            settings$fontSize <- 12
        }

        if(is_var_empty(settings$pointSize) == TRUE){
            settings$pointSize <- 1.5
        }

        if(is_var_empty(settings$theme) == TRUE){
            settings$theme <- "theme_gray"
        }

        if(is_var_empty(settings$colorPalette) == TRUE){
            settings$colorPalette <- "RdPu"
        }

        if(is_var_empty(settings$aspect_ratio) == TRUE){
            settings$aspect_ratio <- 1
        }

        if(is_var_empty(settings$clusterType) == TRUE){
            settings$clusterType <- "Louvain"
        }

        if(is_var_empty(settings$removeNA) == TRUE){
            settings$removeNA = FALSE
        }

        if(is_var_empty(settings$plot_size) == TRUE){
            settings$plot_size <- 12
        }


        if(is_var_empty(settings$knn_clusters) == TRUE){
            settings$knn_clusters <- 250
        }

        if(is_var_empty(settings$perplexity) == TRUE){
            settings$perplexity <- 30
        }
        if(is_var_empty(settings$clustLinkage) == TRUE){
            settings$clustLinkage = "ward.D2"
        }
        if(is_var_empty(settings$clustGroups) == TRUE){
            settings$clustGroups = 9
        }
        
        if(is_var_empty(settings$reachabilityDistance) == TRUE){
            settings$reachabilityDistance = 2
        }

        if(is_var_empty(settings$legendPosition) == TRUE){
            settings$legendPosition = "right"
        }

        ## dataset analysis settings

        if(is_var_empty(settings$datasetAnalysisClustLinkage) == TRUE){
            settings$datasetAnalysisClustLinkage = "ward.D2"
        }

        if(is_var_empty(settings$datasetAnalysisType) == TRUE){
            settings$datasetAnalysisType = "heatmap"
        }

        if(is_var_empty(settings$datasetAnalysisSortColumn) == TRUE){
            settings$datasetAnalysisSortColumn = "cluster"
        }

        if(is_var_empty(settings$datasetAnalysisClustOrdering) == TRUE){
            settings$datasetAnalysisClustOrdering = 1
        }


        plot_unique_hash <- list(
            tsne_plot = list(
                main_plot = digest::digest(paste0(selectedFileID, "_",args$settings,"_tsne_plot_main"), algo="md5", serialize=F)
            ),

            tsne_cluster_plot = digest::digest(paste0(selectedFileID, "_",args$settings,"_tsne_cluster_plot"), algo="md5", serialize=F),
            tsne_cluster_heatmap_plot = digest::digest(paste0(selectedFileID, "_",args$settings,"_tsne_cluster_heatmap_plot"), algo="md5", serialize=F),
            saveObjectHash = digest::digest(paste0(selectedFileID, "_",args$settings,"_editing_tsne_render_plot"), algo="md5", serialize=F)
        )


        if(!is.null(settings$groupingVariables)){
            for(groupVariable in settings$groupingVariables){

                unique_hash <- paste0(selectedFileID, "_",args$settings,"_tsne_plot_",groupVariable)
                plot_unique_hash$tsne_plot[[groupVariable]] <- digest::digest(unique_hash, algo="md5", serialize=F)

                res.data$tsne_plot[[groupVariable]] <- list(name = NULL, svg = NULL, png = NULL, colorby = list())
                ## Color-by placeholder
                res.data$tsne_plot[[groupVariable]]$colorby <- list()
                if(!is.null(settings$colorVariables)){
                    for(colorVariable in settings$colorVariables){
                        unique_hash <- paste0(unique_hash,"_",colorVariable)
                        
                        plot_unique_hash$tsne_plot[[paste0(groupVariable,colorVariable)]] <- digest::digest(unique_hash, algo="md5", serialize=F)
                    }
                }
            }
        }

        resp_check <- getPreviouslySavedResponse(plot_unique_hash, res.data, 5)
        if(is.list(resp_check)){
            print("==> Serving request response from cache")
            ## return(resp_check)
        }

        ## 1st - Get JOB and his Info from database
        selectedFileDetails <- db.apps.getFileDetails(selectedFileID)
        ## save(selectedFileDetails, file = "/tmp/testing.rds")
        selectedFilePath <- downloadDataset(selectedFileDetails[1,]$file_path)

        fileHeader <- jsonlite::fromJSON(selectedFileDetails[1,]$details)
        fileHeader <- plyr::ldply (fileHeader$header$formatted, data.frame)
        fileHeader <- subset (fileHeader, select = -c(.id))

        fileHeader <- fileHeader %>% mutate(unique_count = as.numeric(unique_count)) %>% mutate(position = as.numeric(position))
        fileHeader$remapped = as.character(fileHeader$remapped)
        fileHeader$original = as.character(fileHeader$original)

        if(!is.null(settings$groupingVariables)){
            settings$groupingVariables <- fileHeader %>% filter(remapped %in% settings$groupingVariables)
            settings$groupingVariables <- settings$groupingVariables$remapped
        }


        if(is_null(settings$selectedColumns)) {
            selectedColumns <- fileHeader %>% arrange(unique_count) %>% arrange(position) %>% select(remapped)
            settings$selectedColumns <- selectedColumns$remapped
        }

        ## Load dataset
        dataset <- data.table::fread(selectedFilePath, header = T, sep = ',', stringsAsFactors = FALSE, data.table = FALSE)
        dataset_filtered <- dataset[, names(dataset) %in% c(settings$selectedColumns, settings$groupingVariables)]


        num_test <- dataset_filtered %>% select(where(is.numeric))
        for (groupVariable in settings$groupingVariables) {
            if(groupVariable %in% names(num_test)){
                dataset_filtered[[groupVariable]] <-paste("g",dataset_filtered[[groupVariable]],sep="_")
            }
        }

        if(!is.null(settings$preProcessDataset)){
            print("=====> Preprocess data except grouping variables")
            preProcessedData <- preProcessData(dataset_filtered, settings$groupingVariables , settings$groupingVariables , methods = c("medianImpute", "center", "scale"))
            dataset_filtered <- preProcessedData$processedMat
            #preProcessedData <- preProcessData(dataset_filtered, settings$groupingVariables , settings$groupingVariables ,  methods = c("nzv", "zv"))
            #dataset_filtered <- preProcessedData$processedMat
        }else{
            dataset_filtered <- dataset
        }

        if(settings$removeNA == TRUE){
            print("=====> Data removeNA")
            dataset_filtered <- na.omit(dataset_filtered)
        }




        set.seed(1337)
        tsne_calc <- calculate_tsne(dataset_filtered, settings, fileHeader)
        ## Main t-SNE plot 
        tmp_path <- plot_tsne(tsne_calc$info.norm, NULL, settings,  plot_unique_hash$tsne_plot[["main_plot"]])
        ## Color-by placeholder
        res.data$tsne_plot[["main_plot"]]$colorby <- list()
        res.data$tsne_plot[["main_plot"]]$name <- "Main plot"
        res.data$tsne_plot[["main_plot"]]$svg <- optimizeSVGFile(tmp_path)
        res.data$tsne_plot[["main_plot"]]$png <- convertSVGtoPNG(tmp_path)

        if(!is.null(settings$colorVariables)){

            for(colorVariable in settings$colorVariables){
                coloringVariable <- fileHeader %>% filter(remapped %in% colorVariable)
                coloringVariable <- coloringVariable$original

                print("===> Processing 1:")
                print(colorVariable)
                print(coloringVariable)

                plot_unique_hash$tsne_plot[[paste0("main_plot",colorVariable)]] <- digest::digest(paste0(selectedFileID, "_",args$settings,"_tsne_plot_main_",colorVariable), algo="md5", serialize=F)
                tmp_path_c <- plot_tsne_color_by(tsne_calc$info.norm, NULL, coloringVariable, settings,  plot_unique_hash$tsne_plot[[paste0("main_plot",colorVariable)]])

                res.data$tsne_plot[["main_plot"]]$colorby[[colorVariable]]$name <- coloringVariable
                res.data$tsne_plot[["main_plot"]]$colorby[[colorVariable]]$svg <- optimizeSVGFile(tmp_path_c)
                res.data$tsne_plot[["main_plot"]]$colorby[[colorVariable]]$png <- convertSVGtoPNG(tmp_path_c)
            }
        }


        if(!is.null(settings$groupingVariables)){
            for(groupVariable in settings$groupingVariables){
                # groupVariable is remaped value
                groupingVariable <- fileHeader %>% filter(remapped %in% groupVariable)
                groupingVariable <- groupingVariable$original

                tmp_path <- plot_tsne(tsne_calc$info.norm, groupingVariable, settings,  plot_unique_hash$tsne_plot[[groupVariable]])
                res.data$tsne_plot[[groupVariable]]$name <- groupingVariable
                res.data$tsne_plot[[groupVariable]]$svg <- optimizeSVGFile(tmp_path)
                res.data$tsne_plot[[groupVariable]]$png <- convertSVGtoPNG(tmp_path)

                if(!is.null(settings$colorVariables)){
                    for(colorVariable in settings$colorVariables){

                        coloringVariable <- fileHeader %>% filter(remapped %in% colorVariable)
                        coloringVariable <- coloringVariable$original

                        print("===> Processing 2:")
                        print(colorVariable)
                        print(coloringVariable)

                        tmp_path_c <- plot_tsne_color_by(tsne_calc$info.norm, NULL, coloringVariable, settings,  plot_unique_hash$tsne_plot[[paste0(groupVariable,colorVariable)]])
                        res.data$tsne_plot[[groupVariable]]$colorby[[colorVariable]]$name <- coloringVariable
                        res.data$tsne_plot[[groupVariable]]$colorby[[colorVariable]]$svg <- optimizeSVGFile(tmp_path_c)
                        res.data$tsne_plot[[groupVariable]]$colorby[[colorVariable]]$png <- convertSVGtoPNG(tmp_path_c)
                    }
                }
            }
        }

        print(paste0("===> Clustering using", settings$clusterType))
        set.seed(1337)
        if(settings$clusterType == "Louvain"){
           clust_plot_tsne <- cluster_tsne_knn_louvain(tsne_calc$info.norm, tsne_calc$tsne.norm, settings)
        }else if(settings$clusterType == "Hierarchical"){
           clust_plot_tsne <- cluster_tsne_hierarchical(tsne_calc$info.norm, tsne_calc$tsne.norm, settings)
        }else if(settings$clusterType == "Mclust"){
           clust_plot_tsne <- cluster_tsne_mclust(tsne_calc$info.norm, tsne_calc$tsne.norm, settings)
        }else if(settings$clusterType == "Density"){
           clust_plot_tsne <- cluster_tsne_density(tsne_calc$info.norm, tsne_calc$tsne.norm, settings)
        }else{
           clust_plot_tsne <- cluster_tsne_knn_louvain(tsne_calc$info.norm, tsne_calc$tsne.norm, settings)
        }

        tmp_path <- plot_clustered_tsne(clust_plot_tsne$info.norm, clust_plot_tsne$cluster_data, settings, plot_unique_hash$tsne_cluster_plot)
        res.data$tsne_cluster_plot <- optimizeSVGFile(tmp_path)
        res.data$tsne_cluster_plot_png <- convertSVGtoPNG(tmp_path)


        print(paste0("===> Hierarchical clustering of clustered data"))
        tmp_path <- cluster_heatmap(clust_plot_tsne, settings, plot_unique_hash$tsne_cluster_heatmap_plot)
        if(tmp_path != FALSE){
            res.data$tsne_cluster_heatmap_plot <- optimizeSVGFile(tmp_path)
            res.data$tsne_cluster_heatmap_plot_png <- convertSVGtoPNG(tmp_path)
        }

        # save(dataset_filtered, file="/tmp/dataset_filtered")
        # save(settings, file="/tmp/settings")
        # save(fileHeader, file="/tmp/fileHeader")

        ## save data for latter use
        tmp_path <- tempfile(pattern = plot_unique_hash[["saveObjectHash"]], tmpdir = tempdir(), fileext = ".Rdata")
        processingData <- list(
            dataset = dataset,
            dataset_filtered = dataset_filtered,
            tsne_calc = tsne_calc,
            settings = settings,
            clust_plot_tsne = clust_plot_tsne

        )
        saveCachedList(tmp_path, processingData)
        res.data$saveObjectHash = substr(basename(tmp_path), 1, nchar(basename(tmp_path))-6)

        return (list(success = TRUE, message = res.data, info.norm = clust_plot_tsne$info.norm))
    }
)
