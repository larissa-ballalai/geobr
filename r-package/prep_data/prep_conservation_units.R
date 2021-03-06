#> DATASET: conservation unit
#> Source: MMA - http://mapas.mma.gov.br/i3geo/datadownload.htm
#> Metadata:
# Titulo: Unidades de Conservação
# Titulo alternativo:
# Data: Atualização ***
#
# Forma de apresentação: Shape
# Linguagem: Pt-BR
# Character set: Latin1
#
# Resumo: Pol??gonos e Pontos das unidades de conservação brasileiras.
# Informações adicionais: Dados produzidos pelo MMA, e utilizados na elaboração do shape de biomas com a melhor base oficial dispon??vel.
# Propósito: Identificação das unidades de conservação brasileiras.
#
# Estado: Em desenvolvimento
# Palavras chaves descritivas:****
# Informação do Sistema de Referência: SIRGAS 2000

### Libraries (use any library as necessary)

library(RCurl)
library(stringr)
library(sf)
library(dplyr)
library(readr)
library(data.table)
library(magrittr)
library(lwgeom)
library(stringi)
library(rgdal)



####### Load Support functions to use in the preprocessing of the data

source("./prep_data/prep_functions.R")




# If the data set is updated regularly, you should create a function that will have
# a `date` argument download the data

update <- 201909








getwd()


###### 0. Create Root folder to save the data -----------------
# Root directory
root_dir <- "L:/# DIRUR #/ASMEQ/geobr/data-raw"
setwd(root_dir)

# Directory to keep raw zipped files
dir.create("./conservation_units")
destdir_raw <- paste0("./conservation_units/",update)
dir.create(destdir_raw)


# Create folders to save clean sf.rds files  -----------------
dir.create("./conservation_units/shapes_in_sf_cleaned", showWarnings = FALSE)
destdir_clean <- paste0("./conservation_units/shapes_in_sf_cleaned/",update)
#dir.create(destdir_clean)





#### 1. Download original data sets from MMA website -----------------

# Download and read into CSV at the same time
ftp <- 'http://mapas.mma.gov.br/ms_tmp/ucstodas.shp'

download.file(url = ftp,
              destfile = paste0(destdir_raw,"/","ucstodas.shp"),mode = "wb") #mode = "wb" resolve o problema na hora de baixar o arquivo

ftp <- 'http://mapas.mma.gov.br/ms_tmp/ucstodas.shx'
download.file(url = ftp,
              destfile = paste0(destdir_raw,"/","ucstodas.shx"),mode = "wb")

ftp <- 'http://mapas.mma.gov.br/ms_tmp/ucstodas.dbf'
download.file(url = ftp,
              destfile = paste0(destdir_raw,"/","ucstodas.dbf"),mode = "wb")






#### 2. Unzipe shape files -----------------
# unecessary




#### 3. Clean data set and save it in compact .rds format-----------------

# Root directory
setwd('./conservation_units')


# list all csv files
shape <- list.files(path=paste0("./",update), full.names = T, pattern = ".shp$") # $ para indicar que o nome termina com .shp pois existe outro arquivo com .shp no nome

# read data
temp_sf <- st_read(shape, quiet = F, stringsAsFactors=F, options = "ENCODING=latin1") #Encoding usado pelo IBGE (ISO-8859-1) usa-se latin1 para ler acentos
head(temp_sf)

# add download date column
temp_sf$date <- update

# Rename columns
temp_sf <- dplyr::rename(temp_sf,
                         code_conservation_unit = ID_UC0,
                         name_conservation_unit = NOME_UC1,
                         id_wcm = ID_WCMC2,
                         category = CATEGORI3,
                         group = GRUPO4,
                         government_level = ESFERA5,
                         creation_year = ANO_CRIA6,
                         gid7 = GID7,
                         quality = QUALIDAD8,
                         code_u111 = CODIGO_U11,
                         legislation = ATO_LEGA9,
                         name_organization = NOME_ORG12,
                         dt_ultim10 = DT_ULTIM10)
head(temp_sf)


# store original CRS
original_crs <- st_crs(temp_sf)

# # Use UTF-8 encoding
# temp_sf$name_state <- stringi::stri_encode(as.character((temp_sf$name_state), "UTF-8"))


# Harmonize spatial projection CRS, using SIRGAS 2000 epsg (SRID): 4674
temp_sf <- if( is.na(st_crs(temp_sf)) ){ st_set_crs(temp_sf, 4674) } else { st_transform(temp_sf, 4674) }
st_crs(temp_sf)


# Make any invalid geometry valid # st_is_valid( sf)
temp_sf <- lwgeom::st_make_valid(temp_sf)


# Make sure all geometry types are MULTIPOLYGON (fix isse #66)
temp_sf <- sf::st_cast(temp_sf, "MULTIPOLYGON")
unique(sf::st_geometry_type(temp_sf)) # [1] MULTIPOLYGON       GEOMETRYCOLLECTION


# Use UTF-8 encoding in all character columns
temp_sf <- temp_sf %>%
  mutate_if(is.factor, function(x){ x %>% as.character() %>%
      stringi::stri_encode("UTF-8") } )
temp_sf <- temp_sf %>%
  mutate_if(is.factor, function(x){ x %>% as.character() %>%
      stringi::stri_encode("UTF-8") } )



###### convert to MULTIPOLYGON -----------------
temp_sf <- to_multipolygon(temp_sf)

###### 7. generate a lighter version of the dataset with simplified borders -----------------
# skip this step if the dataset is made of points, regular spatial grids or rater data

# simplify
temp_sf7 <- st_transform(temp_sf, crs=3857) %>%
  sf::st_simplify(preserveTopology = T, dTolerance = 100) %>% st_transform(crs=4674)
head(temp_sf7)




###### 8. Clean data set and save it in geopackage format-----------------
setwd(root_dir)



# Save cleaned sf in the cleaned directory
readr::write_rds(temp_sf, path= paste0(destdir_clean,'/conservation_units_', update,'.rds'), compress = "gz")
sf::st_write(temp_sf, dsn= paste0(destdir_clean,"/conservation_units_", update,".gpkg") )
sf::st_write(temp_sf7, dsn= paste0(destdir_clean,"/conservation_units_", update," _simplified", ".gpkg"))

