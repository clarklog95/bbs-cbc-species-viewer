viewer_programs <- function(choice) switch(choice,both=c('BBS','CBC'),bbs='BBS',cbc='CBC')
viewer_bounds <- function(metadata,choice) {
  programs <- viewer_programs(choice)
  c(first=if(identical(programs,'CBC'))1900L else 1966L,
    last=max(metadata$coverage[program %in% programs,last_year]))
}
viewer_extent <- function(profile) switch(profile,
  continental=c(xmin=-130,xmax=-60,ymin=24,ymax=60),
  canada=c(xmin=-145,xmax=-50,ymin=24,ymax=84),
  north_america=c(xmin=-170,xmax=-50,ymin=5,ymax=84),
  world=c(xmin=-180,xmax=180,ymin=-90,ymax=85))

viewer_catalog <- function(metadata,name_mode,program_choice) {
  selected_mode <- name_mode
  x <- metadata$catalog[name_mode==selected_mode]
  if(!'continental_programs' %in% names(x))stop('Rebuild viewer menu metadata for the supported geographic scope.')
  keep <- vapply(strsplit(x$continental_programs,';',fixed=TRUE),function(p)any(p %in% viewer_programs(program_choice)),logical(1))
  x <- x[keep]
  x[order(tolower(species_name),species_name)]
}

make_species_loader <- function(metadata,data_dir,maximum=10L) {
  cache <- new.env(parent=emptyenv()); order <- character()
  function(name_mode,species_name) {
    selected_mode <- name_mode; selected_species <- species_name
    row <- metadata$catalog[name_mode==selected_mode & species_name==selected_species]
    if(nrow(row)!=1L) stop('Choose a species from the menu')
    key <- row$file
    if(!exists(key,envir=cache,inherits=FALSE)) {
      expected <- metadata$file_manifest[file==key,sha256]
      path <- file.path(data_dir,key)
      if(!file.exists(path) || digest::digest(file=path,algo='sha256')!=expected)
        stop('Viewer data file is missing or changed: ',key)
      assign(key,readRDS(path),envir=cache)
    }
    order <<- c(setdiff(order,key),key)
    if(length(order)>maximum) {
      rm(list=order[1],envir=cache);order <<- order[-1]
    }
    get(key,envir=cache,inherits=FALSE)
  }
}

viewer_points <- function(metadata,detections,program_choice='both',scope='continental',
                          policy='eligible',background='reported',extent=viewer_extent('continental')) {
  programs <- viewer_programs(program_choice)
  sites <- metadata$sites[program %in% programs & (scope=='all' | in_continental_scope==TRUE)]
  surveys <- copy(metadata$surveys[site_index %in% sites$site_index])
  if(policy=='reported') background <- 'reported'
  if(background=='eligible') surveys <- surveys[eligible==TRUE]
  d <- copy(detections[site_index %in% sites$site_index])
  if(policy=='eligible') d <- d[eligible==TRUE]
  surveys[,detected:=paste(site_index,bbs_cbc_year) %in% paste(d$site_index,d$bbs_cbc_year)]
  x <- merge(surveys,sites[,.(site_index,site_id,program,site_name,latitude,longitude,coordinate_status)],
    by='site_index',all.x=TRUE,sort=FALSE)
  x[,in_map_extent:=is.finite(latitude) & is.finite(longitude) &
    longitude>=extent['xmin'] & longitude<=extent['xmax'] & latitude>=extent['ymin'] & latitude<=extent['ymax']]
  x
}

viewer_plot <- function(metadata,points,species,year,name_mode,policy,background,extent) {
  x <- points[bbs_cbc_year==year & in_map_extent==TRUE]
  b <- x[program=='BBS' & detected==TRUE]; c <- x[program=='CBC' & detected==TRUE]
  totals <- sprintf('Shown sites: BBS %s (%s detected) | CBC %s (%s detected)',
    sum(x$program=='BBS'),nrow(b),sum(x$program=='CBC'),nrow(c))
  colors <- c('BBS detection'='#D99A00','CBC detection'='#0078B8','Surveyed site'='#BFC5CA')
  if(policy=='reported') background <- 'reported'
  status <- if(policy=='eligible')'eligible count-day detections' else 'all reported count-day detections (includes held surveys)'
  ggplot2::ggplot() +
    ggplot2::geom_sf(data=metadata$world,fill='white',colour='#51575C',linewidth=.22) +
    ggplot2::geom_point(data=x,ggplot2::aes(longitude,latitude,colour='Surveyed site'),size=.35,alpha=.65) +
    ggplot2::geom_point(data=b,ggplot2::aes(longitude,latitude,colour='BBS detection'),size=1.3,alpha=.95) +
    ggplot2::geom_point(data=c,ggplot2::aes(longitude,latitude,colour='CBC detection'),size=1.1,alpha=.95) +
    ggplot2::scale_colour_manual(values=colors,limits=names(colors),drop=FALSE,name=NULL) +
    ggplot2::coord_sf(xlim=extent[c('xmin','xmax')],ylim=extent[c('ymin','ymax')],
      crs=sf::st_crs(4326),default_crs=sf::st_crs(4326),expand=FALSE) +
    ggplot2::labs(title=sprintf('%s | Year: %d',species,year),
      subtitle=paste(if(name_mode=='harmonized')'Harmonized comparison unit' else 'Raw source name','|',totals),
      x='Longitude',y='Latitude',caption=paste0('Gray: ',
        if(background=='reported')'all source-reported surveys' else 'count-eligible surveys',
        '; not confirmed absences. Colors: ',status,'.\n',
        'CBC January belongs to the previous year; count-week-only records are excluded from detections.')) +
    ggplot2::theme_minimal(base_size=11) +
    ggplot2::theme(legend.position='top',panel.grid.major=ggplot2::element_line(colour='#E3E6E8',linewidth=.25),
      panel.grid.minor=ggplot2::element_blank(),plot.title=ggplot2::element_text(face='bold',size=15),
      plot.subtitle=ggplot2::element_text(size=10),plot.caption=ggplot2::element_text(size=8,hjust=0),
      plot.background=ggplot2::element_rect(fill='white',colour=NA))
}

make_viewer_server <- function(metadata,data_dir) {
  load_species <- make_species_loader(metadata,data_dir)
  function(input,output,session) {
    scope <- 'continental'
    background <- 'reported'
    render_year <- reactiveVal(NULL)
    observeEvent(input$year,render_year(as.integer(input$year)),ignoreInit=FALSE)
    observeEvent(list(input$program,input$species,input$name_mode,input$policy,input$viewport),{
      req(input$year)
      render_year(as.integer(input$year))
    },ignoreInit=FALSE)
    observeEvent(input$viewer_frame_year,{
      req(input$program)
      bounds <- viewer_bounds(metadata,input$program)
      year <- as.integer(input$viewer_frame_year)
      req(length(year)==1L,is.finite(year),year>=bounds['first'],year<=bounds['last'])
      render_year(year)
    })
    observeEvent(list(input$name_mode,input$program),{
      req(input$name_mode,input$program)
      choices <- viewer_catalog(metadata,input$name_mode,input$program)$species_name
      previous <- isolate(input$species)
      selected <- if(!is.null(previous) && previous %in% choices)previous
        else if('White-winged Dove' %in% choices)'White-winged Dove' else choices[1]
      updateSelectizeInput(session,'species',choices=choices,selected=selected,server=TRUE)
    },ignoreInit=FALSE)
    observeEvent(input$program,{
      range <- viewer_bounds(metadata,input$program)
      updateSliderInput(session,'year',min=unname(range['first']),max=unname(range['last']),value=unname(range['first']))
      updateSliderInput(session,'gif_years',min=unname(range['first']),max=unname(range['last']),value=unname(range))
    },ignoreInit=FALSE)
    selected_detection <- reactive({req(input$name_mode,input$species); load_species(input$name_mode,input$species)})
    selected_extent <- reactive({req(input$viewport);viewer_extent(input$viewport)})
    map_points <- reactive({
      req(input$program,input$policy)
      viewer_points(metadata,selected_detection(),input$program,scope,input$policy,background,selected_extent())
    })
    make_plot <- function(year) viewer_plot(metadata,map_points(),input$species,year,input$name_mode,
      input$policy,background,selected_extent())
    output$map <- renderPlot({req(render_year(),input$species);make_plot(render_year())},res=110,
      alt=reactive(paste0(input$species,' | Year: ',render_year())))
    output$status <- renderUI({
      req(render_year(),input$program)
      year <- render_year(); requested <- viewer_programs(input$program)
      outside <- metadata$coverage[program %in% requested & (first_year>year | last_year<year),program]
      messages <- list()
      if(length(outside))messages <- c(messages,list(tags$p(class='viewer-note',
        paste(paste(outside,collapse=' and '),'has no source survey coverage for this year.'))))
      if(input$policy=='reported')messages <- c(messages,list(tags$p(class='viewer-note',
        'Diagnostic view: colored detections include surveys held out of annual analyses.')))
      tagList(messages)
    })
    output$coverage <- renderTable({
      req(render_year())
      x <- map_points()[bbs_cbc_year==render_year() & in_map_extent==TRUE]
      result <- x[,.(Surveyed=.N,Detected=sum(detected),Eligible=sum(eligible)),by=.(Program=program)]
      merge(data.table(Program=viewer_programs(input$program)),result,by='Program',all.x=TRUE)
    },na='0',rownames=FALSE)
    output$download_png <- downloadHandler(filename=function()paste0(gsub('[^A-Za-z0-9]+','-',input$species),'_',input$year,'.png'),
      content=function(file)ggplot2::ggsave(file,make_plot(as.integer(input$year)),device='png',width=10,height=6.67,dpi=120,bg='white'))
    output$download_csv <- downloadHandler(filename=function()paste0(gsub('[^A-Za-z0-9]+','-',input$species),'_site-years.csv'),
      content=function(file){
        x <- copy(map_points())
        x[,`:=`(species_name=input$species,name_mode=input$name_mode,detection_policy=input$policy,
          background_policy=background,geography_scope=scope)]
        fwrite(x,file,na='NA')
      })
    output$download_gif <- downloadHandler(filename=function()paste0(gsub('[^A-Za-z0-9]+','-',input$species),'.gif'),
      content=function(file) {
        req(input$gif_years,input$speed,is.finite(input$speed),input$speed>=.1,input$speed<=1.5)
        years <- seq.int(input$gif_years[1],input$gif_years[2])
        if(length(years)>200L)stop('Choose no more than 200 years')
        directory <- tempfile('viewer-frames-');dir.create(directory)
        on.exit(unlink(directory,recursive=TRUE),add=TRUE)
        png_files <- file.path(directory,sprintf('%04d.png',years))
        withProgress(message='Preparing your GIF',value=0,{
          for(i in seq_along(years)) {
            ggplot2::ggsave(png_files[i],make_plot(years[i]),device='png',width=10,height=6.67,dpi=120,bg='white')
            setProgress(value=.9*i/length(years),detail=paste('Year',years[i]))
          }
          setProgress(value=.95,detail='Encoding animation')
          gifski::gifski(png_files,gif_file=file,width=1200,height=800,delay=input$speed,loop=TRUE,progress=FALSE)
        })
      })
  }
}
