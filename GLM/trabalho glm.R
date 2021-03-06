setwd("c:/users/pedro/desktop/matérias/2018-01/glm/trabalho glm")

library(tidyverse)
library(translateR)
library(stringr)
library(gridExtra)
library(RColorBrewer)
library(rjags)
library(coda)
library(hdi)
library(ggridges)



#BANCO DE DADOS
dados = data.table::fread("bank-additional-full.csv", stringsAsFactors = T) %>% as.data.frame()

dim(dados)

dados$ybin = ifelse(dados$y=="yes", 1, 0)

dados = dados %>% 
  rename(idade = age, trabalho = job, estado_civil = marital, educacao = education,
         inadimplente = default, casa_emprestimo = housing,
         pessoal_emprestimo = loan, tipo_contato = contact, 
         mes = month, dia = day_of_week, duracao = duration, 
         chamadas = campaign, pausa = pdays, chamadas_prev = previous, 
         status_prev = poutcome, variacao_emprego = emp.var.rate, ipc = cons.price.idx, 
         icc = cons.conf.idx, eu_taxa = euribor3m, empregados = nr.employed)

#traduzindo variáveis
trans = function(data, colunas) {
  for(col in colunas) {
    x = data[, col] %>% as.character()
    en = unique(x)
    tl = translate(content.vec = en, source.lang = "en", target.lang = "pt", 
                   google.api.key = "")
    
    for(i in seq_along(tl)) {
      x[x==en[i]] = tl[i]
    }
    data[, col] = x
  }
  
  data
}

data_tl = trans(data = dados, 
                colunas = names(dados)[sapply(dados, is.factor)])

#save(data_tl, file="dados_tl.RData")

###LEIA
load("dados_tl.RData")

#arrumando empregos
data_tl = rename(data_tl, resposta=y)
data_tl$trabalho = ifelse(data_tl$trabalho == "trabalhadores por conta própria", 
                          "autônomos", data_tl$trabalho)
data_tl$trabalho = ifelse(data_tl$trabalho == "colarinho azul", "manual", 
                          data_tl$trabalho)

data_tl$mes = ifelse(data_tl$mes == "pode", "maio", data_tl$mes)


#arrumando educacao
educacao_o = data_tl$educacao
educacao_n = vector(mode="character", length=nrow(data_tl))
for(i in seq_along(educacao_o)) {
  if(educacao_o[i] == "Diploma") {
    educacao_n[i] = "superior"
  }else if(educacao_o[i]=="colegial") {
    educacao_n[i]="ensino médio"
  }else if(educacao_o[i]=="basic.4y") {
    educacao_n[i]="ciclo1"
  }else if(educacao_o[i]=="basic.6y") {
    educacao_n[i]="ciclo2"
  }else if(educacao_o[i]=="basic.9y") {
    educacao_n[i]="ciclo3"
  }else if(educacao_o[i]=="profissional.curso") {
    educacao_n[i]="técnico"
  }else{
    educacao_n[i] = educacao_o[i]
  }
}

data_tl$educacao = educacao_n

ordenar = function(x) {table(x) %>% sort() %>% rev() %>% names()}

#NA's
VIM::aggr(data_tl)

#ANÁLISE DESCRITIVA

do_bar = function(data, var, ordem = NULL) {
  if(is.null(ordem)) {
    data[, var] = factor(data[,var])
  }else{
    data[, var] = factor(data[,var], levels = ordem)
  }
  p1 = ggplot(data, aes_string(x=var)) + 
    geom_bar(aes(y=..prop.., group=1), fill="dodgerblue4", col="white") + 
    theme_minimal()
  
  return(p1)
}

relacione = function(data, var, ordem = NULL) {
  if(is.null(ordem)) { 
    data[, var] = as.factor(data[,var])
    p1 = ggplot(data, aes_string(x="resposta", fill=var)) + 
      geom_bar(position="fill", col="black") + 
      theme_minimal() + 
      scale_fill_brewer(palette = "Blues") 
  }else{
    data[, var] = factor(data[,var], levels = ordem)
    p1 = ggplot(data, aes_string(x="resposta", fill=var)) + 
      geom_bar(position="fill", col="black") + 
      theme_minimal() + 
      scale_fill_brewer(palette = "Blues")
  }
  
  
  
  return(p1)
}


#resposta
do_bar(data_tl, "resposta") + labs(title="Resposta dos clientes ao banco ", x="Resposta", y="Proporção")
ggsave("plots/plot1-Resposta.png", width = 5, height = 3, dpi = 1000)

#distribuição da idade


do_bar(data_tl, "idade") + 
  annotate(geom = "text", x=60, y=0.04, 
           label=paste0("Média: ", mean(data_tl$idade)%>%round(2), "\n", 
                        "Mediana: ", median(data_tl$idade), "\n", 
                        "Desvio padrão: ", sd(data_tl$idade) %>% round(2), "\n")) + 
  theme(axis.text.x = element_text(angle = 90)) + labs(title="Distribuição da idade dos clientes", x="Idade", y="Proporção")

ggsave("plots/plot2-idade.png", width = 7, height = 4, dpi = 1000)



#distribuição da idade pela resposta
ggplot(data_tl, aes(x=factor(idade), fill=resposta)) + 
  geom_bar(position = "fill", col="black") + 
  labs(title="Distribuição de sucessos por idade", x="Idade", y="Proporção") +
  theme_minimal() + 
  scale_fill_brewer(palette = "Blues", name="Resposta") +
  theme(axis.text.x = element_text(angle = 90)) 


ggsave("plots/plot2-idade2.png", width = 6.5, height = 3.5, dpi = 1000)
                                                                    

#distribuição do trabalho
p1 = do_bar(data_tl, "trabalho", ordenar(data_tl$trabalho)) + 
  labs(title="Distribuição das profissões", x="Tipo de trabalho", y="Proporção") + 
  theme(axis.text.x = element_text(angle=90))

data_tl$trabalho = factor(data_tl$trabalho, levels = ordenar(data_tl$trabalho))
p2 = relacione(data_tl, "trabalho") + 
  labs(title="Distribuição do tipo de trabalho \n na resposta",
       y="Proporção", x="Resposta") + 
  scale_fill_brewer(palette = "Set3", name="Tipo de trabalho") #parece não haver distinção dentro da resposta

pg = grid.arrange(p1, p2, nrow = 1)
ggsave(pg, file="plots/plot3-profissao.png", width = 6.5, height = 4)

#estado civil
p1 = do_bar(data_tl, "estado_civil", ordenar(data_tl$estado_civil)) + 
  labs(title="Distribuição do estado civil" , x="Estado Civil", y="Proporção")

p2 = relacione(data_tl, "estado_civil") + 
  labs(title="Resposta do cliente de acordo \n com o estado civil", x="Resposta", y="Proporção") + 
  scale_fill_brewer(name="Estado civil")#solteiros parecem ser mais dispostos a aceitar

pg = grid.arrange(p1, p2, nrow = 1)
ggsave(pg, file="plots/plot4-estado-civil.png", width = 6.5, height = 4)

#idade/estado civil
ggplot(data_tl, aes(x=factor(idade), fill=estado_civil)) + 
  geom_bar(position = "fill", col="black") + 
  theme_minimal() + 
  scale_fill_brewer(palette = "Blues", name="Estado civil") +
  theme(axis.text.x = element_text(angle=90)) + 
  labs(title="Distribuição do estado civil de acordo com a idade", x="Idade", y="Proporção")

ggsave("plots/plot5-estado-civil-idade.png", width = 6.5, height = 4, dpi=1000)
#educação

p1=do_bar(data_tl, "educacao", ordem = c("superior", "técnico", "ensino médio",
                                      "ciclo3", "ciclo2", "ciclo1", 
                                      "analfabeto", "desconhecido")) + 
  theme(axis.text.x = element_text(angle = 90)) + 
  labs(title="Distribuição da educação", x="Educação", y="Proporção")


p2=relacione(data_tl, "educacao") + 
  labs(title="Resposta do cliente de \n acordo com a educação", x="Resposta", y="Proporção") + 
  scale_fill_brewer(name="Educação")#parece ter relação

data_tl$educacao = factor(data_tl$educacao, 
                          levels = rev(c("superior", "técnico", "ensino médio",
                                          "ciclo3", "ciclo2", "ciclo1", 
                                          "analfabeto", "desconhecido")))
pg = grid.arrange(p1, p2, nrow = 1)
ggsave(pg, file="plots/plot6-educacao.png", width = 6.5, height = 4, dpi=1000)


#relação entre educacao e idade
ggplot(data_tl, aes(x=factor(idade), fill=educacao)) + 
  geom_bar(position = "fill", col='black') + 
  scale_fill_brewer(palette = "Blues", name="Educação") + 
  labs(title="Distribuição da educação pela idade", x="Idade", y="Proporção") + 
  theme(axis.text.x = element_text(angle=90))

ggsave("plots/plot7-educacao-idade.png", width = 6.5, height = 4, dpi=1000)

#talvez o estado civil já traga a informação da idade

#indimplente
table(data_tl$inadimplente, data_tl$resposta)
p1=do_bar(data_tl, "inadimplente") +labs(title="Distribuição da \n inadimplência de crédito", x="Inadimplente", y="Proporção")#eliminar variável 
p2=relacione(data_tl, "inadimplente") + labs(title="Resposta de acordo com \n inadimplência de crédito", x="Resposta", y="Proporção") + scale_fill_brewer(name="Inadimplência de crédito")#sem relação aparente

pg = grid.arrange(p1, p2, nrow = 1)
ggsave(pg, file="plots/plot8-inadimplente.png", width = 6.5, height = 4, dpi=1000)


#empréstimo casa
table(data_tl$casa_emprestimo, data_tl$resposta)
p1=do_bar(data_tl, "casa_emprestimo") + labs(title="Distribuição do empréstimo\n habitacional", x="Empréstimo habitacional", y="Proporção")
p2=relacione(data_tl, "casa_emprestimo") + labs(title="Resposta do cliente de acoro\n com o empréstimo habitacional", x="Resposta", y="Frequência absoluta") + scale_fill_brewer(name="Empréstimo habitacional")

pg = grid.arrange(p1, p2, nrow = 1)
ggsave(pg, file="plots/plot9-casa-emprestimo.png", width = 6.5, height = 4, dpi=1000)

#empréstimo pessoal
table(data_tl$pessoal_emprestimo, data_tl$resposta)
p1=do_bar(data_tl, "pessoal_emprestimo") + labs(title="Distribuição do empréstimo \npessoal", x="Empréstimo pessoal", y="Proporção")
p2=relacione(data_tl, "pessoal_emprestimo") + labs(title="Resposta de acordo com\n o empréstimo pessoal", x="Resposta", y="Proporção") + scale_fill_brewer(name="Empréstimo pessoal")
pg = grid.arrange(p1, p2, nrow = 1)
ggsave(pg, file="plots/plot10-pessoal-emprestimo.png", width = 6.5, height = 4, dpi=1000)
#Tipo de contato 
table(data_tl$tipo_contato, data_tl$resposta)
p1=do_bar(data_tl, "tipo_contato", ordem = rev(c("Telefone","celular"))) + labs(title="Distribuição do tipo de ligação", x="Tipo de ligação", y="Proporção")
p2=relacione(data_tl, "tipo_contato") + labs(title="Resposta de acordo \n com o tipo de ligação", x="Resposta", y="Proporção") + scale_fill_brewer(name="Tipo de ligação")
pg = grid.arrange(p1, p2, nrow = 1)
ggsave(pg, file="plots/plot11-tipo-ligacao.png", width = 6.5, height = 4, dpi=1000)
#dia da semana
table(data_tl$dia, data_tl$resposta)
p1=do_bar(data_tl, "dia", ordem=c("seg","ter", "qua", "qui", "sex")) + labs(title="Distribuição do dia da semana \n que o cliente foi contatado", x="Dia da semana", y="Proporção") 
p2=relacione(data_tl, "dia", ordem = c("seg","ter", "qua", "qui", "sex")) + labs(title="Resposta de acordo o \n dia da semana contatado", x="Resposta", y="Proporção") + scale_fill_brewer(name="Dia da semana")

pg = grid.arrange(p1, p2, nrow = 1)
ggsave(pg, file="plots/plot12-dia.png", width = 6.5, height = 5, dpi=1000)


#mes table(data_tl$mes, data_tl$resposta)
p1=do_bar(data_tl, "mes", ordem = c("jan", "feb", "mar", "abril", "maio", "junho", 
                                 "julho", "aug", "sep", "oct", "nov", "dec")) + labs(title="Distribuição do mês que\n o cliente doi contatado", x="Mês", y="Proporção")

p2=relacione(data_tl, "mes", ordem = c("jan", "feb", "mar", "abril", "maio", "junho", 
                                    "julho", "aug", "sep", "oct", "nov", "dec")) + 
  labs(title="Resposta de acordo com o mês \nque o cliente foi contatado", x="Resposta", y="Proporção") + scale_fill_brewer(name="Mês")
pg = grid.arrange(p1, p2, nrow = 1)
ggsave(pg, file="plots/plot13-mes.png", width = 6.5, height = 4, dpi=1000)
#duracao da ligação
summary(data_tl$duracao)
sd(data_tl$duracao)

maximo_duracao = which.max(data_tl$duracao)

#histograma todas as obs
p1=ggplot(data_tl, aes(x=duracao)) + 
  geom_histogram(col='white', fill="dodgerblue") + 
  theme_minimal() + labs(title="Distribuição do tempo \n de duração da última ligação", 
                         x="Tempo de duração da última ligação", y="Proporção") + 
  annotate("text", x=3000,y=15000, 
           label = "Média: 258.3\n Mediana: 319\n Máximo: 4918\n Desvio padrão: 259.2")




#histograma < 1500
data_tl %>% 
  filter(duracao < 2500) %>% 
  ggplot(aes(x=duracao, fill=resposta)) + 
  geom_histogram(col='black', aes(y=..density..)) + 
  scale_fill_brewer(palette = "Set3") + 
  theme_minimal() + labs(title="Distribuição do tempo \nde duração da última ligação", x="Tempo de duração da última ligação", y="Densidade") + scale_fill_brewer(name="Resposta")


p2=data_tl %>% 
  filter(duracao < 4000) %>% 
  ggplot(aes(x=duracao, fill=resposta)) +
  scale_fill_brewer(palette = "Blues", name="Resposta") + 
  geom_histogram(col='black', aes(y=..density..)) + 
  facet_grid(~resposta) + 
  theme_minimal() + 
  labs(title="Distribuição do tempo de duração \nda última ligação por resposta", x="Tempo de duração da última ligação", y="Densidade")
pg = grid.arrange(p1, p2, nrow = 1)
ggsave(p2, file="plots/plot14-tempo.png", width = 6, height = 4, dpi=1000)

#chamadas 
summary(data_tl$chamadas)

p1=do_bar(data_tl, "chamadas") + 
  theme(axis.text.x = element_text(angle=90)) + labs(title="Distribuição do \n número de ligações\n para o mesmo cliente", x="Número de ligações para o mesmo cliente", y="Proporção")

maximo_chamadas = which.max(data_tl$chamadas)


#agrupando variáveis
data_tl$chamadas_agr = cut(data_tl$chamadas, 
                           breaks = c(-1, 0, 1, 2, 3, 10,  20, 30, 40, 50, 60), 
                           labels = c("0", "1", "2", "3", "4-10", 
                                      "11-20", "21-30", "31-40", 
                                      "41-50", "51-60"))

#distribuição
p2=relacione(data_tl, "chamadas_agr") + labs(title="Resposta de acordo com o \n número de ligações \n para o mesmo cliente", x="Resposta", y="Proporção") + 
  scale_fill_brewer(name="Número de ligações")
pg = grid.arrange(p1, p2, nrow = 1)
ggsave(pg, file="plots/plot15-num-chamadas.png", width = 6.5, height = 4, dpi=1000)


#chamadas_previas (numéro de ligações antes)
table(data_tl$chamadas_prev, data_tl$resposta)
p1=do_bar(data_tl, "chamadas_prev") + 
  labs(title="Distribuição do números de ligações \n feitas antes da campanha \n publicitária para o cliente",
       x="Números de ligações", y="Proporção")

p2=relacione(data_tl, "chamadas_prev") + 
  labs(title="Distribuição pela resposta", x="Resposta do cliente", 
       y="Proporção") + 
  scale_fill_brewer(name="Chamadas prévias")
pg = grid.arrange(p1, p2, nrow = 1)
ggsave(pg, file="plots/plot16-chamadas-previas.png", width = 6.5, height = 4, dpi=1000)
#dias sem ligar #variável será descartada

table(data_tl$pausa)
do_bar(data_tl, "pausa") + labs(title="Distribuição do número de dias que passaram após a última ligação", x="Número de dias que passaram após a última ligação", y="Proporção")
ggsave("plots/plot17-pausa.png", width = 6, height = 4, dpi=1000)
#campanhas anteriores
table(data_tl$status_prev, data_tl$resposta)
p1=do_bar(data_tl, "status_prev", ordem=c("sucesso", "falha", "inexistente")) + labs(title="Distribuição do resultado \n da campanha publicitária anterior", x="Resultado da campanha publicitária anterior", y="Proporção")
p2=relacione(data_tl, "status_prev", ordem = c("sucesso", "falha", "inexistente")) + 
  labs(title="Resposta de acordo com \no resultado da campanha \n publicitária anterior", 
       x="Resposta", y="Proporção")  + scale_fill_brewer(name="Resultado")

pg = grid.arrange(p1, p2, nrow = 1)
ggsave(pg, file="plots/plot17-status-prev.png", width = 6.5, height = 4, dpi=1000)


#variacao_emprego

summary(data_tl$variacao_emprego)
sd(data_tl$variacao_emprego)

ggplot(data_tl, aes(x=variacao_emprego, y=..density..)) + 
  geom_histogram(bins=5, col='white') + labs(title="Distribuição de taxa de variação de emprego", x="Taxa de variação de emprego", y="Densidade")

dfve = table(data_tl$variacao_emprego, data_tl$resposta) %>% 
  prop.table(margin=1) %>% as.data.frame()

#proporção de sim's
dfve %>% filter(Var2 == "sim") %>%
  ggplot(aes(x=Var1, y=Freq)) + 
  geom_point() + 
  labs(title="Proporção de sucessos pela taxa de variação de emprego", x="Taxa de variação de emprego", y="Proporção de Y=1") + 
  theme_bw()

ggsave("plots/plot18-variacao-taxa-empregados.png", width = 6, height = 4, dpi=1000)


#Indice de preços
summary(data_tl$ipc)


data_tl$ipc %>% table(data_tl$resposta) %>% prop.table(margin=1) %>% 
  as.data.frame() %>%
  filter(Var2=="sim") %>%
  ggplot(aes(x=`.`,y=Freq)) + 
  geom_point() + 
  theme_bw() + 
  theme(axis.text.x = element_text(angle=90)) + labs(title="Proporção de sucessos pelo índice de preços do consumidor", x="Índice de preços do consumidor", y="Proporção de sucessos")
ggsave("plots/plot19-ipc.png", width = 6, height = 4, dpi=1000)

#histograma
data_tl$ipc %>% table(data_tl$resposta) %>% prop.table(margin=1) %>% 
  as.data.frame() %>% rename(resposta = Var2) %>%
  ggplot(aes(x=`.`, y=Freq, fill=resposta)) + 
  geom_bar(col='black', position = "fill", stat='identity') +
  scale_fill_brewer(palette = "Blues", name="Resposta") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 90)) + labs(title="Ditribuição das repostas pelo índice de preços do consumidor", x="Índice de preços do consumidor", y="Proporção")


#eu_taxa 
summary(data_tl$eu_taxa)
sd(data_tl$eu_taxa)

data_tl$eu_taxa %>% table(data_tl$resposta) %>% prop.table(margin=1) %>% 
  as.data.frame() %>%
  filter(Var2 == "sim") %>%
  ggplot(aes(x=as.numeric(as.character(`.`)), y=Freq)) + 
  geom_point() +
  theme_minimal() + labs(title="Distribuição da taxa Euribor 3 meses", 
                         x="Taxa Euribor 3 meses", y="Proporção de sucessos") + 
  theme_bw() 

ggsave("plots/plot20-euribor.png", width = 6, height = 4, dpi=1000)




data_tl %>% ggplot(aes(x=eu_taxa, fill=resposta)) +
  geom_histogram(bins=11, position = "fill", col='black') + 
  scale_fill_brewer(palette = "Blues", name="Resposta") + 
  theme_minimal() + labs(title="Distribuição da taxa Euribor 3 meses por resposta", x="Taxa Euribor 3 meses", y="Proporção")


#corelação
library(ggcorrplot)
ggcorrplot(cor(data_tl[,sapply(data_tl, FUN=is.numeric)], method='spearman'), hc.order = TRUE, 
           type = "lower", 
           lab = TRUE, 
           lab_size = 3, 
           method="circle", 
           title="Correlograma das variáveis numéricas", 
           colors = c("skyblue", "dodgerblue", "royalblue4"), 
           ggtheme=theme_bw)


ggsave("plots/plot21-correlograma.png", width = 6, height = 4, dpi=1000)


#elimando colunas que não são úteis para a modelagem
modelo_set = data_tl %>% 
  dplyr::select(-resposta, -chamadas_agr) #eliminar chamada agrupada

modelo_set$mes_num = NA

mes = c("jan", "feb", "mar", "abril", "maio", "junho", 
        "julho", "aug", "sep", "oct", "nov", "dec")

for(i in 1:nrow(modelo_set)) {
  for(j in 1:length(mes)) {
    if(modelo_set$mes[i] == mes[j]) modelo_set$mes_num[i] = j
  }
}

#save(modeloSet, file="modeloSet.RData")
load("modeloSet.RData")




#definindo um data.frame de teste e um de validação
set.seed(20)
samp = sample(1:nrow(modelo_set), 22000)


treino = modelo_set[samp, ]
validacao = modelo_set[-samp,]

nrow(treino)
nrow(validacao)


#excluir o tempo sem ligar, e da inadimplencia
#a maioria não foi contactado, 3 inadimplentes, vai causar valores com 0 
treino$inadimplente = NULL
treino$pausa = NULL
#variacao emprego é muito correlacionada com empregados
treino$variacao_emprego = NULL



#colocando os farotes em ordem

treino$mes = factor(treino$mes, levels = mes)
treino$dia = factor(treino$dia, levels = c("seg", "ter", "qua", "qui", "sex"))
treino$pessoal_emprestimo = factor(treino$pessoal_emprestimo, 
                                   levels = c("desconhecido", "não", "sim"))
treino$status_prev = factor(treino$status_prev, levels = c("falha", "inexistente", 
                                                           "sucesso"))


for(var in c("trabalho", "estado_civil", 
             "casa_emprestimo", "tipo_contato", "status_prev")) {
  treino[, var] = factor(treino[,var], levels = rev(ordenar(treino[,var])))
}


#############################################
#modelo com mes categórico e todas as variáveis
############################################
modelo1 = glm(ybin ~ .-mes_num, family=binomial(link="logit"),
              data=treino, na.action = "na.fail")
summary(modelo1)

#o NA no modelo é combinação linear de outra variável

modelo1 = glm(ybin ~.-mes_num-pessoal_emprestimo, family=binomial(link='logit'), 
              data=treino, na.action = 'na.fail')



summary(modelo1)
#o NA no modelo é combinação linear de outra variável

#modelo com mes não categórico
modelo2 = glm(ybin ~. -mes-pessoal_emprestimo, family=binomial(link="logit"),  data=treino)
summary(modelo2)
####modelo com mes categórico é melhor, mês numérico nem é significativo
AIC(modelo1)
AIC(modelo2)

#variáveis não significativas: idade, estadoCivil, educacao, 
#casa emprestimo, chamadas prev, icc


#modelo sem variáveis não significativas 

modelo3 = glm(ybin ~ trabalho + tipo_contato + mes + dia + duracao + chamadas + 
                status_prev + ipc + eu_taxa + empregados, data=treino, family=binomial(link="logit"))
summary(modelo3)

modelo3n = glm(ybin ~.-mes-idade-estado_civil-educacao-casa_emprestimo-chamadas_prev-icc-pessoal_emprestimo, data=treino, family=binomial(link="logit"))
summary(modelo3n)
AIC(modelo1)
AIC(modelo3)
AIC(modelo3n)

#stepwise
library(MASS)
stepAIC(modelo1)

modelo4 = glm(ybin ~ trabalho + tipo_contato + mes + dia + duracao + chamadas + 
                chamadas_prev + status_prev + ipc + eu_taxa + empregados, family = binomial(link = "logit"), data = treino, 
              na.action = "na.fail")

summary(modelo4)

AIC(modelo1)
AIC(modelo3) #melhor
AIC(modelo4)


#modelo final == Modelo 3
#testando outras ligações

#não convergiu
modelo3p = glm(ybin ~ trabalho + tipo_contato + mes + dia + duracao + chamadas + 
                 status_prev + ipc + eu_taxa + empregados, data=treino, 
               family=binomial(link="probit"))

#não convergiu
modelo3cl =  glm(ybin ~ trabalho + tipo_contato + mes + dia + duracao + chamadas + 
                   status_prev + ipc + eu_taxa + empregados, data=treino, 
                 family=binomial(link="cloglog"))

#não convergiu
modelo3c = glm(ybin ~ trabalho + tipo_contato + mes + dia + duracao + chamadas + 
                 status_prev + ipc + eu_taxa + empregados, data=treino, 
               family=binomial(link="cauchit"))


summary(modelo3c)
AIC(modelo3)
AIC(modelo3c)

plot(residuals(modelo3c)%>%qqnorm(), xlab="Quantis teóricos", ylab="Quantis de amostra", main="Normal Q-Q Plot") 


#melhor modelo == MODELO3, mais parcimanioso, AIC baixo

##Validação

#pontos de influência

medidas = influence(modelo3)
#save(medidas, file='medidas.RData')



load("medidas.RData")

#não rodar, apenas leia o arquivo no load

h <- medidas$hat
ts <- resid(modelo3,type="pearson")/sqrt(1-h)
td <- resid(modelo3,type="deviance")/sqrt(1-h)
di <- (h/(1-h))*(ts^2)
a <- max(td)
b <- min(td)

#medida h
ggplot(data.frame(h=h,y=fitted(modelo3)), aes(x=y,y=h)) + 
  geom_point(alpha=0.6) + 
  annotate(geom = "text", x=0.5, y=0.036, label = "2120") + 
  labs(title="Pontos de alavanca", x=" Valores preditos", y="Medida h") + 
  theme_bw()

ggsave(file="plots/plot22-medida-h.png", width = 6, height = 4, dpi=1000)

#distância de cook
ggplot(data.frame(x=1:length(di), di=di), aes(x,di)) + 
  geom_point(alpha=0.6) + 
  annotate(geom = "text", x=12500, y=0.22, label = "11223") + 
  theme_bw() + 
  labs(title="Pontos de influência", x="Índice", y="Distância de Cook")
ggsave(file="plots/plot23-distancia-cook.png", width = 6, height = 4, dpi=1000)


#modelo sem as obervações influentes
modelo5 = glm(ybin ~ trabalho + tipo_contato + mes + dia + duracao + chamadas + 
                status_prev + ipc + eu_taxa + empregados, data=treino, 
              family=binomial(link="logit"), subset = -c(11223,2120))

AIC(modelo3)
AIC(modelo5)

(AIC(modelo5) - AIC(modelo3))/AIC(modelo3)
#diferença minima


#influencias nos coeficiêntes

(coef(modelo5) - coef(modelo3))/coef(modelo3)

#Componente do desvio
ggplot(data.frame(x=1:length(td), y=td), aes(x,y)) + 
  geom_jitter(alpha=0.4) + 
  geom_hline(yintercept = -2, col='blue') + 
  geom_hline(yintercept = 2, col='blue') + 
  theme_bw() + 
  labs(y="Componentes do desvio", x="Índice", title="Outliers")
ggsave("plots/plot24-outilers.png", width = 6, height = 4, dpi=1000)

#####envelope
library(doParallel)
library(foreach)
library(parallel)

cl = makeCluster(detectCores())
registerDoParallel(cl)
par(mfrow=c(1,1))
fit.model = modelo3
X = model.matrix(modelo3)
n = nrow(X)
p = ncol(X)
td = resid(fit.model,type="deviance")/sqrt(1-h)
e = matrix(0,n,100)
#

#não rodar, apenas leia o arquivo no load
e = foreach(i=1:100, .combine = "cbind") %dopar% {
  dif <- runif(n) - fitted(fit.model)
  dif[dif >= 0 ] <- 0
  dif[dif<0] <- 1
  nresp <- dif
  fit <- glm(nresp ~ X, family=binomial)
  h <- influence(fit)$hat
  sort(resid(fit,type="deviance")/sqrt(1-h))
  
}

#save(e, file="e.RData")
load("e.RData")
#
e1 <- numeric(n)
e2 <- numeric(n)
#
for(i in 1:n){
  eo <- sort(e[i,])
  e1[i] <- (eo[2]+eo[3])/2
  e2[i] <- (eo[97]+eo[98])/2}

med <- apply(e,1,mean)
faixa <- range(td,e1,e2)

x = qqnorm(td, plot.it = F)$x
y = qqnorm(td, plot.it = F)$y

e1x = qqnorm(e1, plot.it = F)$x
e1y = qqnorm(e1, plot.it = F)$y

e2x = qqnorm(e2, plot.it = F)$x
e2y = qqnorm(e2, plot.it = F)$y

medx = qqnorm(med, plot.it = F)$x
medy = qqnorm(med, plot.it = F)$y

ggplot(data.frame(e1x,e1y, e2x,e2y,medx,medy,td,x,y), aes(x=x, y=y)) +
  geom_point(alpha=0.4, size = 0.3)  + 
  geom_line(aes(x=e1x,y=e1y), size=1, col='blue', show.legend = T) + 
  geom_line(aes(x=e2x,y=e2y), size=1, col='blue') + 
  geom_line(aes(x=medx,y=medy), size=1, col='grey') +
  theme_bw() +labs(title="Gráfico de envelope", x="Percentis N(0,1)",y="Resíduos")
ggsave("plots/plot25-envelope.png", width = 6, height = 4, dpi=1000)
########################3333
#curva ROC
library(Epi)
png('plots/rplot.png', width = 6, height = 4, units = 'in', res=1000)
ROC(form=ybin ~ trabalho + tipo_contato + mes + dia + duracao + chamadas + 
      status_prev + ipc + eu_taxa + empregados, data=treino, MI=FALSE, plot='ROC')
dev.off()

#validacao 
logitpv = predict(modelo3, validacao[1:10000,]) #logit da validacao

pv = exp(logitpv)/(1+exp(logitpv)) #probabilidade estimada
clf = ifelse(pv > 0.1, "Sim", "Não") #classificacao de acordo com a curva ROC
resp = ifelse(validacao[1:10000,]$ybin==1, "Sim", "Não")


tab = table(clf, "y"= validacao[1:10000,]$ybin) %>% prop.table(margin=1) %>% as.data.frame()

ggplot(data.frame(obs=1:length(pv), pv, clf, Resposta=factor(resp)), 
       aes(x=obs, pv, colour=Resposta)) + 
  geom_point(alpha=0.5) +
  geom_hline(yintercept = 0.1, col = "black", size=1) + 
  scale_colour_manual("point_color", values=c("red", "blue")) + 
  labs(x="Observações", y="Predito") + 
  theme_bw()

ggsave("plots/plot27-sensibilidade.png", width = 6, height = 4, dpi=1000)


##fazer shiny com especificidade, gráfico, 



##modelo completo bayesiano para analisar a as distribuições do Beta
X = model.matrix(modelo3)

model_arq = "model {
for(i in 1:n) {
y[i] ~ dbern(p[i])
logit(p[i]) = inprod(b, X[i,])
}
for(i in 1:param) {
b[i] ~ dnorm(0, 1/1000)
}
}"

set.seed(10)
modjags = jags.model(textConnection(model_arq), 
                     data = list(X=X,
                                 n=nrow(X),
                                 y=treino$ybin,
                                 param=ncol(X)), n.chains = 1, n.adapt = 100)
ini = Sys.time()
post = coda.samples(modjags, c("b"), n.iter=10000, thin=1)
fim = Sys.time()
fim-ini

save(post, file="modeloCompletoPost.RData")
load("modeloCompletoPost.RData")
post_burn = post[[1]] %>% as.data.frame()
post_burn = post_burn[-c(1:1000),] #burn-in


medias = map_dbl(post_burn, mean);medias
desvio = map_dbl(post_burn, sd);desvio
HDInterval::hdi(post_burn)

cbind(medias, coef(modelo3)) %>% round(4)


cumuplot(post) #convergência
acfplot(post) #autocorrelação

#mpedia ergódiga
erg = function(x) cumsum(x)/(1:length(x))

#gerando plot com distribuição
be$iteracao = 1:nrow(be)

be = gather(be, param, obs, -iteracao)
be$param = factor(be$param, levels = names(post_burn))


be %>%
  ggplot(aes(x=obs, y=param)) + 
  geom_vline(xintercept = 0, col='blue') 
  geom_density_ridges()
#melhor modelo é o logístico
