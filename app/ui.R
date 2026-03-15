library(shiny)
library(shinythemes)
source('helpers.R')
source('setSliderColor.R')

shinyUI(
  fluidPage(
    withMathJax(),
    tags$head(
      # 1. External Stylesheet
      tags$link(rel = "stylesheet", type = "text/css", href = "style.css"),
      
      # 2. KaTeX Core Resources
      tags$link(rel = "stylesheet", 
                href = "https://cdn.jsdelivr.net/npm/katex@0.10.1/dist/katex.min.css"),
      tags$script(defer = NA, 
                  src = "https://cdn.jsdelivr.net/npm/katex@0.10.1/dist/katex.min.js"),
      tags$script(defer = NA, 
                  src = "https://cdn.jsdelivr.net/npm/katex@0.10.1/dist/contrib/auto-render.min.js"),
      
      # 3. External KaTeX Initializer
      tags$script(src = "katex-init.js"),
      
      # 4. Dynamic Slider Colors
      setSliderColor(rep("#34495e", 10), seq(1, 10))
    ),
    
    title = "HEALouatta",
    theme = shinytheme("flatly"),
    
    titlePanel(
      div(class = "header-container",
          img(src = "HEALouatta_logo.png", class = "app-logo"),
          span("A version of PANacea for Howler monkeys 🌿", class = "app-subtitle")
      )
    ),
    sidebarPanel(
      width = 3,
      htmlOutput("numRulesOutput"),
      br(),
      setSliderColor(rep("#34495e", 5), c(1, 2, 3, 4, 5)),
      
      # We move these to uiOutput so they adapt to the Alouatta data
      uiOutput("supp_slider"),
      uiOutput("conf_slider"),
      uiOutput("lift_slider"),
      uiOutput("length_slider"),
      
      hr(),
      h4("Data Filtering"),
      # NEW: Dynamic dropdowns for Species and Population
      uiOutput("species_selector"),
      uiOutput("pop_selector"),
      
      hr(),
      em(HTML("Filter rules by food-item:")),
      selectInput("colsType", NULL,
                  c(`Exclude food-item:` = "rem",
                    `Require food-item:` = "req")),
      uiOutput("choose_columns"),
      selectInput("colsLHSType", NULL,
                  c(`Exclude food-item from LHS:` = "rem",
                    `Require food-item in LHS:` = "req")),
      uiOutput("choose_lhs"),
      selectInput("colsRHSType", NULL,
                  c(`Require food-item in RHS:` = "req",
                    `Exclude food-item from RHS:` = "rem")),
      uiOutput("choose_rhs"),
      hr(),
      strong("Reference:"),
      tags$div(
        HTML("Freymann E, d’Oliveira Coelho J, Muhumuza G, Hobaiter C, Huffman MA, Zuberbühler K, Carvalho S. 2024 . Applying collocation and APRIORI analyses to chimpanzee diets: Methods for investigating nonrandom food combinations in primate self-medication. <em>American Journal of Primatology</em>. <strong>e23603</strong> <a href ='https://onlinelibrary.wiley.com/doi/10.1002/ajp.23603' target='_blank'>10.1002/ajp.23603</a>")
      )
    ),
    mainPanel(
      width = 9,
      tabsetPanel(
        id = "tabs",
        tabPanel("📊 Data Exploration", value = "datatable",
                 br(), DT::dataTableOutput("rulesDataTable"),
                 hr(), br(),
                 downloadButton("rules.csv", "Export rules (CSV)")),
        # tabPanel("Scatter", value = "scatter",
        #          wellPanel(fluidRow(column(3,
        #                                    uiOutput("xAxisSelectInput")),
        #                             column(3, uiOutput("yAxisSelectInput")),
        #                             column(3, uiOutput("cAxisSelectInput")),
        #                             column(3, sliderInput("max_scatter",
        #                                                   "Top rules shown (keep below 500):",
        #                                                   min = 1, max = length(x),
        #                                                   value = min(100,
        #                                                               length(x)), step = 1, sep = "")))),
        #          plotly::plotlyOutput("scatterPlot", width = "100%",
        #                               height = "100%")),
        tabPanel("🥑 Medicinal Network",
                 value = "graph",
                 wellPanel(
                   fluidRow(
                     column(6,
                            uiOutput("cAxisSelectInput_graph")),
                     column(6,
                            uiOutput("interaction_slider"))
                     #      sliderInput(
                     # "max_graph",
                     # "Top rules shown (limit is 500):",
                     # min = 1, max = 500,
                     # value = min(10, length(x)),
                     # step = 1, sep = "")),
                   )),
                 visNetwork::visNetworkOutput("graphPlot",
                                              width = "100%", height = "700px")),
        tabPanel("⚗️ Clustered Rules",
                 value = "grouped",
                 wellPanel(
                   fluidRow(
                     column(6,
                            uiOutput("kSelectInput")),
                     column(6,
                            uiOutput("cAxisSelectInput_grouped")))),
                 plotOutput("groupedPlot")),
        tabPanel("🐵 About", value = "about",
                 wellPanel(strong("Background")),
                 p('We applied the APRIORI algorithm to assess Alouatta (Howler monkey)
                   dietary combinations (Agrawal & Srikant, 1994). This method identifies
                   association rules within a large dataset, generating rules with
                   support and confidence exceeding user-specified thresholds
                   (Agrawal & Srikant, 1994; Al-Maolegi & Arkok, 2014). Originally
                   designed for marketing, APRIORI analyzes transaction histories,
                   suggesting additional products to customers (Hahsler, 2017;
                   Hahsler & Karpienko, 2017). Unprecedentedly, we adapted APRIORI
                   to explore nonhuman feeding behavior, providing a fresh approach
                   to testing food resource associations. Merging feeding data
                     from a 4-month period for efficiency, we formatted it akin
                     to the collocation analysis V1 subset. Using the
                     transactions() function from the arules package (Hornik et
                     al., 2005), we transformed the long-form dataset into a
                     Binary Incidence Matrix—ideal for mining associations.
                     Finally, the dataset underwent APRIORI analysis in R
                     (version 4.5.2, R Development Core Team, 2025).'),
                 uiOutput("formulas"),
                 p('Understanding the results hinges on three customizable
                   metrics: support, confidence, and lift (see Supporting Information
                   S1: Figure 1). Support quantifies the frequency of the association,
                   acting as a popularity metric. In diverse datasets like ours,
                   support tends to be low due to the multitude of item-types.
                   Confidence, scaled between 0 and 1, reflects association
                   strength, with 0 as 0% and 1 as 100%. However, it can be
                   influenced by dataset size; for instance, a rare combination
                   may yield a high confidence. To mitigate this, we turn to the
                   crucial Lift metric, which controls for confidence, especially
                   in smaller datasets. A lift >1 indicates a confidence value
                   exceeding the expected, suggesting a non-random association.
                   This metric proves invaluable in scenarios of low frequency
                   and short data collection spans. Lift, a key indicator,
                   indirectly addresses factors like data collection duration.
                   It is particularly useful in larger datasets with sparse
                     observations for each item or combination. The rule of
                     thumb: Lift should be >1 for confidence to be considered a
                     reliable metric.'),
                 wellPanel(strong("References")),
                 p("Agrawal, R., Srikant, R. 1994. Fast algorithms for mining association rules in large databases,",
                   em("Proceedings of the 20th International Conference on Very Large Data Bases"), "(pp. 487–499). Morgan Kaufmann Publishers Inc."),
                 p("Al-Maolegi, M., & Arkok, B. (2014). An improved Apriori algorithm for association rules.",
                   em("ArXiv Preprint"), "ArXiv:1403.3948."),
                 p("Hahsler, M., 2017. arulesViz: Interactive Visualization of Association Rules with R.", em("The R Journal"), p("9, 163-175.")),
                 p("Hahsler, M., Chelluboina, S., Hornik, K., Buchta, C., 2011. The arules R-Package Ecosystem: analyzing interesting patterns from large transaction data sets.",
                   em("Journal of Machine Learning Research"), "12, 2021–2025."),
                 p("Hahsler, M., Karpienko, R., 2017. Visualizing association rules in hierarchical groups.",
                   em("Journal of Business Economics"), p("87, 317-335.")),
                 p("Hornik, K., Grün, B., Hahsler, M. 2005. arules-A computational environment for mining association rules and frequent item sets",
                   em("Journal of Statistical Software"), p("14(15), 1–25.")),
                 p("R Core Team, 2024. R: A Language and Environment for Statistical Computing. R Foundation for Statistical Computing, Viena.")
        ),
        tabPanel(
          title = HTML("<li><a href='http://osteomics.com' target='_blank'>🔙 Back to osteomics.com</a></li>")
        )
      )
    )
  )
)
