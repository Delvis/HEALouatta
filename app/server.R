library(shiny)
library(DT)
library(magrittr)
library(arules)
library(arulesViz)

# Load our data-prep script
source('helpers.R')

function(input, output, session) {
  # Initialize these first so they exist for the UI immediately
  xIndexCached <- "support"
  yIndexCached <- "confidence"
  zIndexCached <- "lift"
  
  # A. This listens for filter changes
  filtered_trans <- reactive({
    # 1. Ensure the filters exist before doing anything
    req(input$species_filter, input$pop_filter)
    
    df <- copy(clean_data)
    
    if (input$species_filter != "All") {
      df <- df[Species == input$species_filter]
    }
    if (input$pop_filter != "All") {
      df <- df[Population == input$pop_filter]
    }
    
    # 2. Check if the filtered data actually has rows
    # This prevents the "empty object" error in itemLabels
    validate(
      need(nrow(df) > 0, "Filtering data... please wait.")
    )
    
    df[, transaction_id := paste(actor, data, sep = "_")]
    items_list <- split(df$food_item, df$transaction_id)
    
    as(items_list, "transactions")
  })
  
  # B. This listens for slider changes AND filtered_trans
  rules <- reactive({
    # Wait for the sliders to exist
    req(input$supp, input$conf, input$length, filtered_trans())
    
    trans <- filtered_trans()
    if (length(trans) == 0) return(NULL)
    
    apriori(trans, 
            parameter = list(
              supp = input$supp, 
              conf = input$conf, 
              minlen = input$length[1], # Use the length slider vector
              maxlen = input$length[2],
              target = "rules"
            ),
            control = list(verbose = FALSE))
  })
  
  
  output$numRulesOutput <- renderUI({
    req(rules())
    em(HTML(paste("Selected rules: ", length(rules()))))
  })


  output$kSelectInput <- renderUI({
    sliderInput("k", label = "Choose # of rule clusters",
                min = 1, max = 50, step = 1, value = 15)
  })
  output$xAxisSelectInput <- renderUI({
    selectInput("xAxis", "X Axis:",
                colnames(quality(rules())), selected = xIndexCached)
  })
  output$yAxisSelectInput <- renderUI({
    selectInput("yAxis", "Y Axis:",
                colnames(quality(rules())), selected = yIndexCached)
  })
  output$cAxisSelectInput <- renderUI({
    selectInput("cAxis", "Shading:",
                colnames(quality(rules())), selected = zIndexCached)
  })
  output$cAxisSelectInput_matrix <- renderUI({
    selectInput("cAxis_matrix", "Shading:",
                colnames(quality(rules())), selected = zIndexCached)
  })
  output$cAxisSelectInput_grouped <- renderUI({
    selectInput("cAxis_grouped", "Shading:",
                colnames(quality(rules())), selected = zIndexCached)
  })
  output$cAxisSelectInput_graph <- renderUI({
    selectInput("cAxis_graph", "Shading:",
                colnames(quality(rules())), selected = zIndexCached)
  })
  
  # Dynamic Species Dropdown
  output$species_selector <- renderUI({
    choices <- c("All", sort(unique(clean_data$Species)))
    selectInput("species_filter", "Select Species:", choices = choices, selected = "All")
  })
  
  # Dynamic Population Dropdown that "listens" to Species
  output$pop_selector <- renderUI({
    # If a species is selected, filter the population list to only those in that species
    if (!is.null(input$species_filter) && input$species_filter != "All") {
      relevant_pops <- sort(unique(clean_data[Species == input$species_filter, Population]))
    } else {
      # If "All" is selected, show every population in the dataset
      relevant_pops <- sort(unique(clean_data$Population))
    }
    
    choices <- c("All", relevant_pops)
    selectInput("pop_filter", "Select Population:", choices = choices, selected = "All")
  })
  
  # Dynamic Item Filter (the choose_columns, LHS, and RHS boxes)
  output$choose_columns <- renderUI({
    req(filtered_trans())
    choices <- itemLabels(filtered_trans())
    selectizeInput("cols", "Exclude/Require items:", choices = choices, multiple = TRUE)
  })
  
  output$choose_lhs <- renderUI({
    req(filtered_trans()) # This stops the crash!
    selectizeInput("colsLHS", NULL, itemLabels(filtered_trans()),
                   multiple = TRUE)
  })
  
  output$choose_rhs <- renderUI({
    req(filtered_trans()) # This stops the crash!
    selectizeInput("colsRHS", NULL, itemLabels(filtered_trans()), 
                   multiple = TRUE)
  })
 
  # 1. Initialize the memory variables
  xIndexCached <- "support"
  yIndexCached <- "confidence"
  zIndexCached <- "lift"
  
  # 2. Update memory whenever the user touches a dropdown
  observe({ req(input$xAxis); xIndexCached <<- input$xAxis })
  observe({ req(input$yAxis); yIndexCached <<- input$yAxis })
  
  # Group all shading listeners to update the same 'zIndexCached'
  observe({ 
    req(input$cAxis)
    zIndexCached <<- input$cAxis 
  })
  observe({ 
    req(input$cAxis_matrix)
    zIndexCached <<- input$cAxis_matrix 
  })
  observe({ 
    req(input$cAxis_grouped)
    zIndexCached <<- input$cAxis_grouped 
  })
  observe({ 
    req(input$cAxis_graph)
    zIndexCached <<- input$cAxis_graph 
  })
  
  handleErrors <- reactive({
    validate(need(length(rules()) > 0,
                  "No rules to visualize! Decrease support, confidence or lift."))
  })
  output$groupedPlot <- renderPlot({
    req(input$cAxis_grouped, input$k)
    handleErrors()
    plot(rules(), method = "grouped", shading = input$cAxis_grouped,
         control = list(k = input$k))
  }, height = 600, width = "auto")

  output$interaction_slider <- renderUI({
    # We need the rules to exist to know the max limit
    req(rules())
    
    sliderInput(
      "max_graph",
      "Top rules shown:",
      step = 1,
      min   = 1,
      max   = max(1, length(rules())), # Ensure max is at least 1
      value = min(15, length(rules())) # Default to 15 rules
    )
  })

  output$graphPlot <- visNetwork::renderVisNetwork({
    req(input$cAxis_graph, input$max_graph)
    handleErrors()

    # Sample code for creating a network plot
    plt <- plot(rules()[1:input$max_graph,], method = "graph", shading = input$cAxis_graph,
                engine = "htmlwidget", control = list(max = input$max_graph))


    # Set the size of the plot
    plt$sizingPolicy <- htmlwidgets::sizingPolicy(
      viewer.paneHeight = 1000,
      browser.defaultHeight = 1000, knitr.defaultHeight = 1000,
      defaultHeight = 1000, defaultWidth = 1000, browser.fill = TRUE
    )
    plt$height <- 1000
    plt$x$height <- 1000

    plt
  })

  # output$scatterPlot <- plotly::renderPlotly({
  #   req(input$xAxis, input$yAxis, input$cAxis,
  #       input$max_scatter)
  #   handleErrors()
  #   plot(rules(), method = "scatterplot", measure = c(input$xAxis,
  #                                                     input$yAxis), shading = input$cAxis, engine = "htmlwidget",
  #        control = list(max = input$max_scatter))
  # })
  output$matrixPlot <- plotly::renderPlotly({
    req(input$cAxis_matrix, input$max_matrix)
    handleErrors()
    plot(rules(), method = "matrix", shading = input$cAxis_matrix,
         engine = "htmlwidget", control = list(max = input$max_matrix))
  })
  
  output$rulesDataTable <- DT::renderDataTable({
    req(rules())
    
    # Convert rules to a readable dataframe
    df_rules <- data.frame(
      LHS = labels(lhs(rules())),
      RHS = labels(rhs(rules())),
      quality(rules())
    )
    
    datatable(df_rules, selection = 'single', rownames = FALSE) %>%
      formatRound(columns = c('support', 'confidence', 'lift', 'coverage'), digits = 4)
  })  
  
  output$rules.csv <- downloadHandler(filename = "rules.csv",
                                      content = function(file) {
                                        write.csv(as(rules(), "data.frame"), file)
                                      })
  output$formulas <- renderUI({
    withMathJax(
      helpText("(Eq. 1) $$ Support=\\frac{\\text{ Number of Associations between A and B }}{\\text{ Total number of Associations}}=P\\left(A \\cap B\\right)$$"),
      helpText("(Eq. 2) $$ Confidence=\\frac{\\text{ Number of Associations between A and B }}{\\text{ Total number of Associations with A}}=\\frac{P\\left(A \\cap B\\right)}{P\\left(A\\right)}$$"),
      helpText("(Eq. 3) $$ Lift=\\frac{Confidence}{\\text{Expected Confidence}} = \\frac{P\\left(A \\cap B\\right)}{P\\left(A\\right) \\times P\\left(B\\right)}$$")

    )
  })
  
  # Add these inside your server.R function(input, output, session) {
  
  output$supp_slider <- renderUI({
    sliderInput("supp", "Minimum Support:", min = 0.001, max = 0.1, 
                value = 0.01, step = 0.001, sep = "")
  })
  
  output$conf_slider <- renderUI({
    sliderInput("conf", "Minimum Confidence:", min = 0.05, max = 1, 
                value = 0.2, step = 0.05, sep = "")
  })
  
  output$lift_slider <- renderUI({
    sliderInput("lift", "Minimum Lift:", min = 0, max = 10, 
                value = 1, step = 0.1, sep = "")
  })
  
  output$length_slider <- renderUI({
    sliderInput("length", "Rule length (from-to):",
                min = 2, max = 10, value = c(2, 5), step = 1, sep = "")
  })
  
}
