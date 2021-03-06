rm(list=ls())
gc()
dev.off()

#install.packages("igraph")

library(devtools)
library(Rspotify)
library(magrittr)
library(stringr)
library(tidyverse)
library(igraph)
library(visNetwork) 

app_name      = "FeatGraph"
client_id     = readRDS("key/client_id.rds")
client_secret = readRDS("key/client_secret.rds")

keys = spotifyOAuth(app_name,client_id,client_secret)

id_links = function(artist){
  id_art = searchArtist(artist,token=keys)$id[1]
  
  
  id_album = getDiscographyInfo(id_art,token=keys)$id %>% as.character
  
  
  
  ############ getSingles
  id = id_art
  type = "single"
  token = keys
  market = "BR"
  total <- httr::content(httr::GET(paste0("https://api.spotify.com/v1/artists/", 
                                          id, "/albums?album_type=", type), httr::config(token = token)))$total
  id_single = c()
  for(k in 1:ceiling(total/50)){
    offset = (k-1)*50
    limit = 50
    req <- httr::GET(paste0("https://api.spotify.com/v1/artists/", 
                            id, "/albums?offset=",offset,"&limit=", limit, "&album_type=", 
                            type, "&market=", market), httr::config(token = token))
    id_single_aux = lapply(httr::content(req)$items, function(x) data.frame(id = x$id,stringsAsFactors = F) ) %>% unlist()
    id_single = c(id_single,id_single_aux)
  }
  
  
  #req <- httr::GET(paste0("https://api.spotify.com/v1/artists/", 
  #                        id, "/albums?offset=",offset,"&limit=", total, "&album_type=", 
  #                        type, "&market=", market), httr::config(token = token))
  #id_single = lapply(httr::content(req)$items, function(x) data.frame(id = x$id,stringsAsFactors = F) ) %>% unlist()
  #id_single
  ##############
  
  id_album = c(id_album,id_single)
  
  #id_album
  
  id_track = lapply(id_album,function(x) as.character(getAlbum(x,token=keys)$id) ) 
  
  id_track2 = id_track %>% unlist
  
  
  id_link_arts = lapply(id_track2, function(x) getTrack(x,token=keys)$artists %>% 
                          as.character 
  )
  
  id_link_art2 = unlist(id_link_arts)
  id_link_art3 = id_link_art2[grepl(";",id_link_art2)]
  
  id_combs = lapply(id_link_art3, function(x) x %>%
                      str_split(.,";") %>%
                      first %>%
                      combn(.,2) %>%
                      t
  )
  
  id_link_df = id_combs %>% Reduce(rbind,.)
  return(id_link_df)
}


id_links_by_list = function(list_art){
  aux = lapply(list_art, function(x) id_links(x))
  names(aux) = list_art %>% tolower %>% gsub("\\+","_",.)
  return(aux)
}

#######

df4net = id_links_by_list(c("belchior","zé ramalho"))


id_link_df = Reduce(rbind,df4net)
id_link_df_unique = id_link_df %>% unique

# igraph

net = graph_from_data_frame(id_link_df_unique, directed=F)

l <- layout_with_kk(net)
plot(net
     , layout=l
     , vertex.size=5
     , edge.color="gray80"
     , vertex.color="lightgreen"
     , vertex.label.color="black"
     , vertex.frame.color="lightgreen"
     , vertex.label.font=1
     , vertex.label.cex=1.5
     , vertex.label=NA
     , interactive = T
     )

# visNetwork

nodes <- as_data_frame(net, what="vertices")
nodes$id = row.names(nodes)
edges <- as_data_frame(net, what="edges")

vis.nodes <- nodes
vis.links <- edges
vis.nodes$title  <- nodes$id # Text on click
vis.nodes$label  <- NA # Node label
vis.nodes$size   <- 10 # Node size

vis.nodes$color.highlight.background <- "orange"
vis.nodes$color.highlight.border <- "darkred"

dev.off()
gc()
visnet = visNetwork(vis.nodes, vis.links, width="100%", height="600px", highlightNearest = TRUE) 
visnet
visSave(visnet, "output.html", selfcontained = TRUE, background = "white")

