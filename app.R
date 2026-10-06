library(shiny)
library(data.table)
source('R/viewer.R',local=TRUE)
if(!file.exists('data/metadata.rds'))stop('Build the compact viewer data with apps/build_species_viewer_data.R first.')
metadata <- readRDS('data/metadata.rds')
initial_species <- 'White-winged Dove' # Full alphabetized menu is served by the server.
range <- viewer_bounds(metadata,'both')
ui <- fluidPage(
  tags$head(tags$script(src='playback.js')),
  tags$head(tags$style(HTML('body{background:#f5f7f9;color:#26323b;} .well{background:white;border:1px solid #e0e5e9;} .viewer-note{padding:10px;background:#fff3d8;border-radius:5px;} .tab-content{background:white;padding:12px;} .control-label{font-weight:600;}'))),
  tags$head(tags$style(HTML('
    #play_animation {
      display:inline-block; width:100%; padding:10px 14px; border:2px solid #00628f;
      border-radius:6px; background:#0078B8; color:white; font-size:16px;
      font-weight:600; text-align:center; text-decoration:none; opacity:1;
    }
    #play_animation:hover {background:#005f91; color:white;}
    #play_animation:focus-visible {outline:3px solid #D99A00; outline-offset:3px;}
    #map {transition:none;}
    #map.recalculating {opacity:1;}
  '))),
  titlePanel('BBS & CBC species detection viewer'),
  p('Explore reported bird detections through time. BBS is gold; CBC is blue; surveyed sites are gray.'),
  sidebarLayout(
    sidebarPanel(width=3,
      selectInput('program','Programs and time span',choices=c('BBS + CBC: 1966 onward'='both',
        'CBC: full history from 1900'='cbc','BBS: 1966 onward'='bbs')),
      radioButtons('name_mode','Species names',choices=c('Harmonized comparison units'='harmonized','Raw source names'='raw'),selected='harmonized'),
      selectizeInput('species','Species',choices=initial_species,selected='White-winged Dove'),
      sliderInput('year','Year',min=unname(range['first']),max=unname(range['last']),value=1966,step=1,sep=''),
      actionButton('play_animation',tagList(icon('play'),' Play animation')),
      sliderInput('speed','Animation seconds per year',min=.1,max=1.5,value=.35,step=.05),
      helpText('Live playback waits for each map to finish drawing. GIFs use the exact selected frame duration.'),
      selectInput('viewport','Map view',choices=c('Lower 48 + southern Canada'='continental',
        'Include northern Canada'='canada','North America'='north_america','World'='world')),
      selectInput('policy','Detections shown',choices=c('Eligible detections'='eligible','All reported detections: diagnostic'='reported')),
      tags$hr(),
      sliderInput('gif_years','GIF year range',min=unname(range['first']),max=unname(range['last']),value=unname(range),step=1,sep=''),
      downloadButton('download_gif','Download GIF'),br(),br(),
      downloadButton('download_png','Download this map'),br(),br(),
      downloadButton('download_csv','Download site-year display data')
    ),
    mainPanel(width=9,
      tabsetPanel(
        tabPanel('Map',uiOutput('status'),plotOutput('map',height='650px'),tableOutput('coverage')),
        tabPanel('About the data',
          h3('What the points mean'),
          p('Colored points represent positive count-day detections. CBC count-week-only records are excluded. Gray points show surveys; they do not establish that the selected species was absent.'),
          p('Eligible detections follow the database survey rules. The diagnostic option includes reported detections on held or nonstandard surveys, for inspection rather than annual analysis.'),
          h3('Year and source coverage'),
          p('CBC January counts are shown with the preceding December year. Missing CBC dates are not guessed. BBS begins in 1966; choose CBC full history to explore 1900 onward. Each program stops at the latest year in its downloaded release.'),
          verbatimTextOutput('source_coverage'),
          h3('Names and geography'),
          p('Maps include the lower 48/DC and Canada. Harmonized names use the curated crosswalk already stored in the source database and reviewed for this scope. Raw and harmonized names are alternative views.'),
          p('Points use representative source site coordinates, not historical survey footprints. A shift in plotted detections can reflect sampling, identification, taxonomy or reporting as well as biology. These maps are not effort-standardized trends.'),
          h3('Reproduction'),
          p('This viewer uses a small presence-only export. The full source database remains unchanged. The export retains program/site/year coverage and eligibility flags, and loads only the selected species.'),
          tags$a(href='https://github.com/clarklog95/bbs-cbc-species-viewer',target='_blank','Viewer source code and release data'),
          p(paste('Source database build:',metadata$provenance$source_database_built_at)),
          p(paste('Compact export build:',metadata$provenance$built_at_utc))
        )
      )
    )
  )
)
server_core <- make_viewer_server(metadata,'data')
server <- function(input,output,session) {
  server_core(input,output,session)
  output$source_coverage <- renderPrint(metadata$coverage)
}
shinyApp(ui,server)
