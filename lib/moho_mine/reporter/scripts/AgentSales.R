args = commandArgs(trailingOnly=T)
IsDate <- function(mydate, date.format = "%Y-%m-%d") {
	  tryCatch(!is.na(as.Date(mydate, date.format)),  
	  		              error = function(err) {FALSE})  
}
if (length(args) != 6) {
	stop("A JDBC driver location, 3 output(sales by category, sales by sites, full data dump) file a \"from\" and a \"to\" date parameter has to be passed")
}
if (!IsDate(args[5])) {
	stop("Argument \"from\" has to be in a format yyyy-mm-dd")
}
if (!IsDate(args[6])) {
	stop("Argument \"to\" has to be in a format yyyy-mm-dd")
}
args.jdbc.path = args[1]
args.agent.sales.by.category = args[2]
args.agent.sales.by.site = args[3]
args.full.data = args[4]
args.from = args[5]
args.to = args[6]

AgentSales = function (connection) {
    thisEnv = environment()
    if (class(connection) == "JDBCConnection") {
        localConnection = connection
        result = NULL
        loadSpecialProducts = function () {
            command = paste("select id_termek",
                            "from termek",
                            "where lower(termek.nev) in ('adengo  1', 'adengo  5', 'afalon disp.  5', 'antracol wg   6', 'bactospeine  5', 'biathlon 4d', 'biscaya  3', 'bumper 25 ec  5',", 
			       							  "'calypso 480 sc  1', 'cambio          5', 'colombus  1', 'colombus  5', 'coragen 20 sc  1', 'coragen 20 sc  0,2', 'curzate super df  5',",
			       							  "'cuproxat        5', 'cuproxat        20', 'dithane dg neotec  10', 'dithane m-45      25', 'folpan 80 wdg   5', 'fontelis 20 sc  1',",
			       							  "'galben r  5', 'galben r  25', 'galera sl   5', 'galigan 240 ec  5', 'goal duplo   3', 'inazuma  1', 'kaiso eg  1', 'laudis  1',",
			       							  "'laudis  5', 'lingo  5', 'mavrik 24 ew  1', 'melody compact 49 wg 6', 'mextrol b  5', 'megysto  5', 'mildicut  10', 'mist control     5',",
			       							  "'mist-control    5', 'monsoon active  5', 'montaflow sc  10', 'mustang forte  1', 'mustang forte  5', 'mystic pro  5', 'nimrod 25 ec    1',",
			       							  "'nuflon  5', 'nurelle-d 500 ec 1', 'nurelle-d 500 ec 5', 'ordax super (0,45l c+10l ss+3l d)', 'pendigan 330 ec   10', 'perenal  5',",
			       							  "'pictor  5', 'prosaro               5', 'prolectus  0,25', 'pulsar          5', 'pyrinex 48 ec   5', 'pyrinex supreme  5', 'racer 25 ec     5',",
			       							  "'sekator od  1', 'solofol 80 wdg  10', 'stabilan sl     10', 'systhane duplo  1', 'trek p  5', 'tango star      5', 'teppeki 50 wg  0,5',",
			       							  "'warrant 200 sl  1', 'wing p  10', 'zantara ec 216  5', 'zoom 11 sc  1', 'python duplo 6ha',",
                                              "'pulsar          5', 'stellar 1+ dash 1','taltos+polyglycol  1,5+22,5', 'taltos+polyglycol  25*(0,033+0,5)') or ",
			       							  "lower(termek.nev) like 'bayer sz_l_ cs.'")
            temp = dbGetQuery(localConnection, command)
            colnames(temp) = c("id")
            return(temp)
        }
        loadAgentNames = function (customer.ids) {
            customer.ids.string = paste("'", as.character(customer.ids), "'", collapse=", ", sep="")
            command = paste("select v.id_vevo, u.nev",
                            " from vevo v left join",
                            " uzletkoto u on u.id_uzletkoto = v.id_uzletkoto",
                            " where v.id_vevo in (", customer.ids.string, ")", sep="")
            temp = dbGetQuery(localConnection, command)
            colnames(temp) = c("customer_id", "agent_name")
            return(temp)
        }
        removePhoneBills = function (data) {
            return(data[-which(grepl(" HAVI (MOBIL|VEZET.KES) ?TEL", data$product_name)),])
        }
        imputeAgentName = function (data) {
            data.without.agents = is.na(data$agent_name)
            customer.ids.with.no.agents = unique(data[data.without.agents, 'customer_id'])
            if (length(customer.ids.with.no.agents) > 0) {
                agents.of.customers = loadAgentNames(customer.ids.with.no.agents)
                temp = merge(data[data.without.agents,], agents.of.customers, by="customer_id", all.x=T)
                
                data[which(data.without.agents),'agent_name'] = temp$agent_name.y
            }
            return (data)
        }
        aggregateForAgents = function (data, agents) {
            if (nrow(data) == 0) {
                return (rep(0, length(agents$agent_name)))
            }
            aggregated.sales = aggregate(data$totalprice, 
                                         list(data$agent_name),
                                         function (x) { round(sum(x),0)})
            colnames(aggregated.sales) = c("agent_name", "sum")
            full.total = sum(aggregated.sales$sum)
            aggregated.sales = rbind(aggregated.sales, data.frame("agent_name"="Összesen", "sum"=full.total))
            merged = merge(agents, aggregated.sales, by="agent_name", all.x=T)[,2]
            merged[is.na(merged)] = 0
            return(merged)
        }
        aggregateForSitesByAgent = function (data, sites, agent_name, criteria = NULL) {
            localData = data
            if (!is.null(criteria)) {
                localData = localData[which(criteria),]
            }
            localData = localData[which(localData$agent_name == agent_name),]
            if (nrow(localData) == 0) {
                return (rep(0, length(sites$site)))
            }
            aggregated.sales = aggregate(localData$totalprice, 
                                         list(localData$original_site),
                                         function (x) { round(sum(x),0)})
            colnames(aggregated.sales) = c("site", "sum")
            full.total = sum(aggregated.sales$sum)
            aggregated.sales = rbind(aggregated.sales, data.frame("site"="Összesen", "sum"=full.total))
            merged = merge(sites, aggregated.sales, by="site", all.x=T)[,2]
            merged[is.na(merged)] = 0
            return(merged)
        }
        aggregateByCriteria = function (data, agents, criteria) {
            ss = data[which(criteria),]
            return(aggregateForAgents(ss, agents))
        }
        aggregateForProvider = function (data, agents, provider) {
            ss = subset(data, grepl(provider, data$provider_name))
            return(aggregateForAgents(ss, agents))
        }
        aggregateByCriteriaForVetomagForProvider = function (data, agents, provider) {
            ss = subset(data, grepl("^VET.MAG$", data$group_name))
            ss = subset(ss, grepl(provider, ss$provider_name))
            return(aggregateForAgents(ss, agents))
        }
        me = list (
            thisEnv = thisEnv,
            getEnv = function () {
                return(get("thisEnv", thisEnv))
            },
            getResult = function () {
                return(get("result", thisEnv))
            },
            load = function (from, to) {
                command = paste(
                    #Azok a számlák amihez tartozik szállítólevél.
                    #Itt az üzletkötőket a szállítóhoz tartozó vevő alapján számítom
                    "select szamla.datum, szamla.sorszam, termek.nev, szamlatetel.eladar, szamlatetel.mennyiseg, ",
                    "szamlatetel.eladar * szamlatetel.mennyiseg as \"EladarSum\", ",
                    "forgalmazo.nev, csoport.nev, vevo.nev, uzletkoto.nev, telephelysync.nev, termek.id_termek, ",
                    "vevo.id_vevo, 'UZLETKOTO-SZLEVEL' ",
                    "from szamlatetel join  ",
                    "szamla on szamla.id_szamla = szamlatetel.id_szamla join ",
                    "kihivatkozas kh on kh.id_szamla = szamla.id_szamla join ",
                    "szlevel on szlevel.id_szlevel = kh.id_szlevel join	",
                    "telephelysync on telephelysync.id_telephelysync = szlevel.id_orig_telephely join ",
                    "vevo on vevo.id_vevo = szlevel.id_vevo join ",
                    "termek on termek.id_termek = szamlatetel.id_termek join ",
                    "forgalmazo on forgalmazo.id_forgalmazo = termek.id_forgalmazo join ",
                    "csoport on csoport.id_csoport = termek.id_csoport left join ",
                    "uzletkoto on uzletkoto.id_uzletkoto = vevo.id_uzletkoto ",
                    "where szamla.datum >='", from, "' and szamla.datum <='", to, "' ",
                    "union all ",
                    #Ugyanaz mint az előző csak itt minden olyan számlát húzok be amihez nem tartozik szállítólevél. ",
                    #Itt az üzletkötőket a számlához tartozó vevő alapján számítom ",
                    "select szamla.datum, szamla.sorszam, termek.nev, szamlatetel.eladar, szamlatetel.mennyiseg, ",
                    "szamlatetel.eladar * szamlatetel.mennyiseg as \"EladarSum\", ",
                    "forgalmazo.nev, csoport.nev, vevo.nev, uzletkoto.nev, telephelysync.nev, termek.id_termek, ",
                    "vevo.id_vevo, 'UZLETKOTO-SZAMLA' ",
                    "from szamlatetel join  ",
                    "szamla on szamla.id_szamla = szamlatetel.id_szamla join ",
                    "telephelysync on telephelysync.id_telephelysync = szamla.id_orig_telephely join ",
                    "vevo on vevo.id_vevo = szamla.id_vevo join ",
                    "termek on termek.id_termek = szamlatetel.id_termek join ",
                    "forgalmazo on forgalmazo.id_forgalmazo = termek.id_forgalmazo join ",
                    "csoport on csoport.id_csoport = termek.id_csoport left join ",
                    "uzletkoto on uzletkoto.id_uzletkoto = vevo.id_uzletkoto ",
                    "where szamla.datum >='", from, "' and szamla.datum <='", to, "' and ",
                    "szamla.id_szamla not in ( ",
                        "select distinct id_szamla ",
                        "from kihivatkozas ",
                    ") or ",
                    #Lehetséges, hogy a kihivatkozas táblában szerepel, de szlevel már nincs hozzá rendelve valamiért
                    "szamla.id_szamla in ( ",
                        "select distinct id_szamla ",
                        "from kihivatkozas left join ",
                        "szlevel on szlevel.id_szlevel = kihivatkozas.id_szlevel ",
                        "where szlevel.sorszam is null",
                    ") ",
                    sep="")
                
                temp = dbGetQuery(localConnection, command)
                colnames(temp) = c("date", "bill_num", "product_name", "price", "amount", "totalprice", "provider_name", "group_name", "customer_name", "agent_name", "original_site", "product_id", "customer_id", "agent_type")
                assign("result", temp, thisEnv)
                #print("Data is loaded into memory")
            },
            report = function () {
                if (is.null(result)) {
                    stop("Use \"load\" to load data first")
                } else {
                    special.products = loadSpecialProducts()
                    agents = data.frame("agent_name"=sort(unique(result$agent_name)))
                    agents = rbind(agents, data.frame("agent_name"="Összesen"))
                    agent.sales = data.frame("agent_name"=agents$agent_name)
                    result = removePhoneBills(result)
                    result = imputeAgentName(result)
                    agent.sales$Farmmix = aggregateByCriteria(result, agents, grepl("^FARMMIX KFT$", result$provider_name))
                    agent.sales$"Farmmix Alternatív" = aggregateByCriteria(result, agents, grepl("^FARMMIX KFT ALT", result$provider_name))
                    agent.sales$Agrosol = aggregateByCriteria(result, agents, grepl("AGROSOL", result$provider_name))
                    agent.sales$Vetco = aggregateByCriteria(result, agents, grepl("VETCO", result$provider_name))
                    agent.sales$"F + FA + A + V" = agent.sales$Farmmix +
                        agent.sales$"Farmmix Alternatív" +
                        agent.sales$Agrosol +
                        agent.sales$Vetco
                    agent.sales$Kiemelt = aggregateByCriteria(result, agents, criteria = (result$product_id %in% special.products$id))
                    # Axe out the special products for further calculations
                    result.without.special = result[-which(result$product_id %in% special.products$id),]
                    
                    # We filter all products that are:
                    #   - "Egyéb" is set as a provider
                    #   - Is not "Műtrágya" or not "Vetőmag"
                    #   - Is "Műtrágya" but doesn't start with MT, Yara or Timac
                    agent.sales$"Egyéb, nagy gyártóhoz nem köthető" = 
                        aggregateByCriteria(result.without.special,
                                                           agents,
                                                           criteria = grepl("^EGY.B$", result.without.special$provider_name) &
                                                                           (
                                                                               !grepl("^M.TR.GYA$|^VET.MAG$", result.without.special$group_name) |
                                                                               (
                                                                                   grepl("^M.TR.GYA$", result.without.special$group_name) &
                                                                                    !grepl("^MT|^YARA|^TIMAC", result.without.special$product_name)
                                                                               )
                                                                           )
                                            )
                    agent.sales$"F + FA + A + V + K + E" = agent.sales$"F + FA + A + V" + 
                        agent.sales$Kiemelt +
                        agent.sales$"Egyéb, nagy gyártóhoz nem köthető"
                    
                    agent.sales$Adama = aggregateForProvider(result.without.special, agents, "^ADAMA")
                    agent.sales$Arysta = aggregateForProvider(result.without.special, agents, "^ARYSTA")
                    agent.sales$BASF = aggregateForProvider(result.without.special, agents, "^BASF")
                    agent.sales$Bayer = aggregateForProvider(result.without.special, agents, "^BAYER")
                    agent.sales$Belchim = aggregateForProvider(result.without.special, agents, "^BELCHIM")
                    agent.sales$Cheminova = aggregateForProvider(result.without.special, agents, "^CHEMINOVA")
                    agent.sales$Chemtura = aggregateForProvider(result.without.special, agents, "^CHEMTURA$")
                    agent.sales$Dow = aggregateForProvider(result.without.special, agents, "^DOW")
                    agent.sales$Dupont = aggregateForProvider(result.without.special, agents, "^DUPONT")
                    agent.sales$Kwizda = aggregateForProvider(result.without.special, agents, "^KWIZDA")
                    agent.sales$Nufarm = aggregateForProvider(result.without.special, agents, "^NUFARM")
                    agent.sales$"Sumi-Agro növényvédőszer" = aggregateForProvider(result.without.special, agents, "^SUMI AGRO")
                    agent.sales$"Syngenta növényvédőszer" = aggregateForProvider(result.without.special, agents, "^SYNGENTA KFT$")
                    agent.sales$"Egyéb növényvédőszer" = agent.sales$Adama +
                        agent.sales$Arysta +
                        agent.sales$BASF +
                        agent.sales$Bayer +
                        agent.sales$Belchim +
                        agent.sales$Cheminova +
                        agent.sales$Chemtura +
                        agent.sales$Dow +
                        agent.sales$Dupont +
                        agent.sales$Kwizda +
                        agent.sales$Nufarm +
                        agent.sales$"Sumi-Agro növényvédőszer" +
                        agent.sales$"Syngenta növényvédőszer"
                    agent.sales$"Növényvédőszer összes" = agent.sales$"F + FA + A + V + K + E" + agent.sales$"Egyéb növényvédőszer"
                    
                    agent.sales$"Gabonakutató" = aggregateByCriteriaForVetomagForProvider(result.without.special, agents, "^GABONAKUTAT.")
                    agent.sales$"Egyéb vetőmag" = aggregateByCriteriaForVetomagForProvider(result.without.special, agents, "^EGY.B$")
                    agent.sales$BayerSeeds = aggregateByCriteriaForVetomagForProvider(result.without.special, agents, "^BAYER SEEDS$")
                    agent.sales$KWS = aggregateByCriteriaForVetomagForProvider(result.without.special, agents, "^KWS")
                    agent.sales$Limagrain = aggregateByCriteriaForVetomagForProvider(result.without.special, agents, "^LIMAGRAIN")
                    agent.sales$Monsanto = aggregateByCriteriaForVetomagForProvider(result.without.special, agents, "^MONSANT")
                    agent.sales$Martonvasar = aggregateByCriteriaForVetomagForProvider(result.without.special, agents, "^MARTONV.S.R")
                    agent.sales$Pioneer = aggregateByCriteriaForVetomagForProvider(result.without.special, agents, "^PIONEER")
                    agent.sales$Ragt = aggregateByCriteriaForVetomagForProvider(result.without.special, agents, "^RAGT")
                    agent.sales$Saaten = aggregateByCriteriaForVetomagForProvider(result.without.special, agents, "^SAATEN") 
                    agent.sales$"Sumi-Agro vetőmag" = aggregateByCriteriaForVetomagForProvider(result.without.special, agents, "^SUMI AGRO")
                    agent.sales$"Syngenta vetőmag" = aggregateByCriteriaForVetomagForProvider(result.without.special, agents, "^SYNGENTA VET.MAG$")
                    agent.sales$"Vetőmag összes" = agent.sales$"Gabonakutató" +
                        agent.sales$"Egyéb vetőmag" +
                        agent.sales$BayerSeeds +
                        agent.sales$KWS +
                        agent.sales$Limagrain +
                        agent.sales$Monsanto +
                        agent.sales$Martonvasar +
                        agent.sales$Pioneer +
                        agent.sales$Ragt +
                        agent.sales$Saaten +
                        agent.sales$"Sumi-Agro vetőmag" +
                        agent.sales$"Syngenta vetőmag" 
                    
                    agent.sales$"Egyéb műtrágya" = aggregateByCriteria(result.without.special, agents, (grepl("^EGY.B$", result.without.special$provider_name) &
                                                                                 grepl("^M.TR.GYA$", result.without.special$group_name) &
                                                                                 grepl("^MT|^YARA|^TIMAC", result.without.special$product_name) 
                                                                                 ))
                    agent.sales$"Műtrágya összes" = agent.sales$"Egyéb műtrágya"
                    agent.sales$"Összes" = agent.sales$"Növényvédőszer összes" +
                        agent.sales$"Vetőmag összes" +
                        agent.sales$"Műtrágya összes"
                    return(agent.sales)
                }
            },
            exportAgentDataBySite = function (filename) {
                if (is.null(result)) {
                    stop("Use \"load\" to load data first")
                } else {
                    special.products = loadSpecialProducts()
                    result.without.special = result[-which(result$product_id %in% special.products$id),]
                    agents = data.frame("agent_name"=sort(unique(result$agent_name)))
                    agents = rbind(agents, data.frame("agent_name"="Összesen"))
                    sites = data.frame("site"=sort(unique(result$original_site)))
                    sites = rbind(sites, data.frame("site"="Összesen"))
                    for (i in c(1:(dim(agents)[1])-1)) {
                        agent.name = agents[i,1]
                        agent.result = data.frame("site"=sites$site)
                        agent.result$"Nettó összforgalom" = aggregateForSitesByAgent(result, sites, agent.name)
                        
                        farmmix = aggregateForSitesByAgent(result, sites, agent.name, criteria=(grepl("^FARMMIX KFT$", result$provider_name)))
                        farmmix.alternativ = aggregateForSitesByAgent(result, sites, agent.name, criteria=(grepl("^FARMMIX KFT ALT", result$provider_name)))
                        kiemelt = aggregateForSitesByAgent(result, sites, agent.name, criteria=(result$product_id %in% special.products$id))
                        agrosol = aggregateForSitesByAgent(result, sites, grepl("AGROSOL", result$provider_name))
                        vetco = aggregateForSitesByAgent(result, sites, grepl("VETCO", result$provider_name))
                        ffaav = farmmix + 
                            farmmix.alternativ +
                            agrosol +
                            vetco
                        result.without.special = result[-which(result$product_id %in% special.products$id),]
                        misc = 
                            aggregateForSitesByAgent(result.without.special,
                                                                sites,
                                                                agent.name,
                                                                criteria = grepl("^EGY.B$", result.without.special$provider_name) &
                                                                               (
                                                                                   !grepl("^M.TR.GYA$|^VET.MAG$", result.without.special$group_name) |
                                                                                   (
                                                                                       grepl("^M.TR.GYA$", result.without.special$group_name) &
                                                                                        !grepl("^MT|^YARA|^TIMAC", result.without.special$product_name)
                                                                                   )
                                                                               )
                                                )
                        ffaavke = ffaav + 
                            kiemelt +
                            misc
                        adama = aggregateForSitesByAgent(result.without.special, sites, agent.name, grepl("^ADAMA", result.without.special$provider_name))
                        arysta = aggregateForSitesByAgent(result.without.special, sites, agent.name, grepl("^ARYSTA", result.without.special$provider_name))
                        BASF = aggregateForSitesByAgent(result.without.special, sites, agent.name, grepl("^BASF", result.without.special$provider_name))
                        bayer = aggregateForSitesByAgent(result.without.special, sites, agent.name, grepl("^BAYER", result.without.special$provider_name))
                        belchim = aggregateForSitesByAgent(result.without.special, sites, agent.name, grepl("^BELCHIM", result.without.special$provider_name))
                        cheminova = aggregateForSitesByAgent(result.without.special, sites, agent.name, grepl("^CHEMINOVA", result.without.special$provider_name))
                        chemtura = aggregateForSitesByAgent(result.without.special, sites, agent.name, grepl("^CHEMTURA$", result.without.special$provider_name))
                        dow = aggregateForSitesByAgent(result.without.special, sites, agent.name, grepl("^DOW", result.without.special$provider_name))
                        dupont = aggregateForSitesByAgent(result.without.special, sites, agent.name, grepl("^DUPONT", result.without.special$provider_name))
                        kwizda = aggregateForSitesByAgent(result.without.special, sites, agent.name, grepl("^KWIZDA", result.without.special$provider_name))
                        nufarm = aggregateForSitesByAgent(result.without.special, sites, agent.name, grepl("^NUFARM", result.without.special$provider_name))
                        sumi = aggregateForSitesByAgent(result.without.special, sites, agent.name, grepl("^SUMI AGRO", result.without.special$provider_name))
                        syngenta = aggregateForSitesByAgent(result.without.special, sites, agent.name, grepl("^SYNGENTA KFT$", result.without.special$provider_name))
                        misc_pesticide = adama +
                            arysta +
                            BASF +
                            bayer +
                            belchim +
                            cheminova +
                            chemtura +
                            dow +
                            dupont +
                            kwizda +
                            nufarm +
                            sumi +
                            syngenta
                        
                        
                        #Set the columns
                        agent.result$"Növszer összforgalom" = ffaavke + misc_pesticide
                        agent.result$"Farmmix kiemelt" = kiemelt
                        agent.result$"Farmmix Alternatív" = farmmix.alternativ
                        agent.result$Farmmix = farmmix
                        
                        
                        rws.vetomag = subset(result.without.special, grepl("^VET.MAG$", result.without.special$group_name))
                        aggregateForSitesByAgent(rws.vetomag, sites, agent.name, grepl("^DUPONT", rws.vetomag$provider_name))
                        gabonakutato = aggregateForSitesByAgent(rws.vetomag, sites, agent.name, grepl("^GABONAKUTAT.", rws.vetomag$provider_name))
                        egyeb.vetomag = aggregateForSitesByAgent(rws.vetomag, sites, agent.name, grepl("^EGY.B$", rws.vetomag$provider_name))
                        KWS = aggregateForSitesByAgent(rws.vetomag, sites, agent.name, grepl("^KWS", rws.vetomag$provider_name))
                        bayerSeeds = aggregateForSitesByAgent(rws.vetomag, sites, agent.name, grepl("^BAYER SEEDS", rws.vetomag$provider_name))
                        limagrain = aggregateForSitesByAgent(rws.vetomag, sites, agent.name, grepl("^LIMAGRAIN", rws.vetomag$provider_name))
                        monsanto = aggregateForSitesByAgent(rws.vetomag, sites, agent.name, grepl("^MONSANT", rws.vetomag$provider_name))
                        martonvasar = aggregateForSitesByAgent(rws.vetomag, sites, agent.name, grepl("^MARTONV.S.R", rws.vetomag$provider_name))
                        pioneer = aggregateForSitesByAgent(rws.vetomag, sites, agent.name, grepl("^PIONEER", rws.vetomag$provider_name))
                        ragt = aggregateForSitesByAgent(rws.vetomag, sites, agent.name, grepl("^RAGT", rws.vetomag$provider_name))
                        saaten = aggregateForSitesByAgent(rws.vetomag, sites, agent.name, grepl("^SAATEN", rws.vetomag$provider_name)) 
                        sumi.vegomag = aggregateForSitesByAgent(rws.vetomag, sites, agent.name, grepl("^SUMI AGRO", rws.vetomag$provider_name))
                        syngenta.vetomag = aggregateForSitesByAgent(rws.vetomag, sites, agent.name, grepl("^SYNGENTA VET.MAG$", rws.vetomag$provider_name))
                        vetomag.osszes = gabonakutato +
                            egyeb.vetomag +
                            KWS +
                            bayerSeeds + 
                            limagrain +
                            monsanto +
                            martonvasar +
                            pioneer +
                            ragt +
                            saaten +
                            sumi.vegomag +
                            syngenta.vetomag 
                        
                        agent.result$"Vetőmag" = vetomag.osszes
                        agent.result$"Egyéb műtrágya" = aggregateForSitesByAgent(result.without.special, sites, agent.name,
                                                                                 (grepl("^EGY.B$", result.without.special$provider_name) &
                                                                                 grepl("^M.TR.GYA$", result.without.special$group_name) &
                                                                                 grepl("^MT|^YARA|^TIMAC", result.without.special$product_name) 
                                                                                 )
                                                                             )
                        #write.csv(agent.result, filename)
                        if (i==1) {
                            write.table(agent.name, filename, row.names=F, col.names=F)
                        } else {
                            write.table(agent.name, filename, row.names=F, col.names=F, append=T)
                        }
                        write.table(agent.result, filename, row.names=F, col.names=T, append=T, sep=",")
                        write.table(" ", filename, row.names=F, col.names=F, append=T)
                    }
                }
            }
        )
        assign('this', me, envir = thisEnv)
        class(me) = append(class(me), "AgentSales")
        return(me)
    }
}

suppressMessages(library('RJDBC'))
dbPassword = "PcL233yW"
drv = JDBC("org.firebirdsql.jdbc.FBDriver",
		   args.jdbc.path,
           identifier.quote="`")
c = dbConnect(drv, 
			   paste("jdbc:firebirdsql://127.0.0.1:3050//databases/2015/", "dbs_2015_full.fdb?encoding=ISO8859_1", sep=""),
			   "SYSDBA", dbPassword)


as = AgentSales(c)

as$load(args.from, args.to)
agent.sales.by.category = as$report()
agent.result = as$getResult()

write.csv(t(agent.sales.by.category), args.agent.sales.by.category)
as$exportAgentDataBySite(args.agent.sales.by.site)
write.csv(agent.result, args.full.data)
success = dbDisconnect(conn = c)
cat("OK")