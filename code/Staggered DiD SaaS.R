# =====================================================================
# CASO SAAS B2B: IMPACTO DEL ONBOARDING BONIFICADO EN LA ADOPCIÓN
# Metodología: Staggered Difference-in-Differences (Callaway & Sant'Anna)
# Dataset: saas_b2b_onboarding.csv
# =====================================================================

# ---------------------------------------------------------------------
# BLOQUE 1: CARGA DE LIBRERÍAS ESPECIALIZADAS

library(did)        # Motor econométrico para modelos Staggered DiD
library(dplyr)      # Manipulación y transformación estructurada de datos
library(ggplot2)    # Visualizaciones gráficas avanzadas

# ---------------------------------------------------------------------
# BLOQUE 2: AUDITORÍA INICIAL Y BALANCEO DEL PANEL (EDA)
# Propósito: Verificar que el archivo cargado no contenga inconsistencias estructurales.
# Para aplicar DiD escalonado necesitamos un panel perfectamente balanceado:
# exactamente 100 cuentas únicas observadas a lo largo de los 3 periodos fiscales (300 filas).
# ---------------------------------------------------------------------
datos_saas <- read.csv("saas_b2b_onboarding.csv")                  # Cargamos el dataset balanceado de 100 cuentas corporativas
head(datos_saas)                                                   # Inspeccionamos las primeras filas de la base
summary(datos_saas)                                                # Resumen estadístico de las métricas de uso y covariables
dim(datos_saas)                                                    # Confirmamos las 300 observaciones del panel (100 cuentas x 3 años)

# ---------------------------------------------------------------------
# BLOQUE 3: CONSTRUCCIÓN DE COHORTES TEMPORALES DE INTERVENCIÓN
# Propósito: En DiD escalonado, cada unidad debe pertenecer a un grupo de adopción fijo (g).
# Rastreamos el historial de cada cuenta para identificar el año exacto en que recibió
# el onboarding por primera vez. Las que nunca lo recibieron quedan etiquetadas con 0
# para actuar como grupo de control puro en todas las comparaciones posteriores.
# ---------------------------------------------------------------------
datos_modelo <- datos_saas %>%
  group_by(id_cuenta_cliente) %>%                                  # Agrupamos por identificador de cuenta corporativa
  mutate(
    primer_tratamiento = ifelse(
      any(onboarding_bonificado == 1), 
      min(periodo_fiscal[onboarding_bonificado == 1]), 
      0
    )
  ) %>%                                                            # Definimos cohorte: año del primer onboarding (2024, 2025) o 0 para control puro
  ungroup()                                                        # Liberamos el agrupamiento de memoria

# ---------------------------------------------------------------------
# BLOQUE 4.1: MODELADO DE LA PROBABILIDAD DE ASIGNACIÓN (PROPENSITY SCORE)
# Propósito: Aislar el año pre-tratamiento puro (2023) y estimar qué variables predicen
# que una cuenta entre al programa. La regresión logística calcula el "Propensity Score",
# permitiendo saber si las cuentas tratadas eran sistemáticamente más grandes o rentables.
# Con esto evitamos confundir el efecto del onboarding con el tamaño intrínseco del cliente.
# ---------------------------------------------------------------------
datos_basales <- datos_modelo %>%
  filter(periodo_fiscal == 2023) %>%                               # Aislamos el año base puro (2023) antes de cualquier intervención
  mutate(es_tratado = ifelse(primer_tratamiento > 0, 1, 0))        # Variable binaria: 1 si la cuenta recibirá onboarding a futuro, 0 si es control puro

modelo_ps <- glm(
  formula = es_tratado ~ usuarios_licenciados + facturacion_anual_cliente, # Estimamos la probabilidad basal de recibir onboarding
  family = binomial(link = "logit"),                               # Regresión logística con enlace logit
  data = datos_basales                                             # Alimentamos con los datos basales de 2023
)

datos_basales$pscore <- predict(
  object = modelo_ps,                                              # Modelo logístico entrenado
  type = "response"                                                # Obtenemos el Propensity Score basal (probabilidad entre 0 y 1)
)

# ---------------------------------------------------------------------
# BLOQUE 4.2: PONDERACIÓN POR INVERSA DE PROBABILIDAD (IPW) Y SOPORTE COMÚN
# Propósito: Usamos los Propensity Scores para crear ponderadores IPW que rebalancean
# artificialmente las cuentas de control, dándole más peso a las que se parecen a las tratadas.
# Graficamos la densidad de ambas curvas para comprobar que exista "soporte común" (overlap):
# si las curvas se solapan, confirmamos que los grupos son comparables y no hay sesgo letal.
# ---------------------------------------------------------------------
datos_basales <- datos_basales %>%
  mutate(peso_ipw = ifelse(es_tratado == 1, 1 / pscore, 1 / (1 - pscore))) # Asignamos ponderadores IPW para equilibrar los grupos

grafico_overlap <- ggplot(
  data = datos_basales,                                            # Dataset con probabilidades basales calculadas
  mapping = aes(x = pscore, fill = as.factor(es_tratado))          # Densidad de pscore segmentada por grupo de asignación
) +
  geom_density(alpha = 0.5) +                                      # Capa de densidad con transparencia para revisar soporte común
  scale_fill_manual(
    values = c("#E69F00", "#56B4E9"),                              # Paleta Okabe-Ito (accesibilidad visual)
    labels = c("Control Puro", "Tratado Futuro")                   # Etiquetas de negocio
  ) +
  theme_minimal(base_size = 12) +                                  # Tema minimalista
  labs(
    title = "Soporte Común del Propensity Score (Línea Base: 2023)",# Título formal
    x = "Probabilidad Estimada de Asignación (Propensity Score)",  # Eje X
    y = "Densidad",                                                # Eje Y
    fill = "Grupo de Cuenta"                                       # Leyenda
  )

print(grafico_overlap)                                             # Renderizamos el gráfico de solapamiento

# ---------------------------------------------------------------------
# BLOQUE 4.3: EVALUACIÓN DE BALANCE POST-PONDERACIÓN (SMD)
# Propósito: Medir matemáticamente si las diferencias entre grupos se redujeron.
# La Diferencia de Medias Estandarizada (SMD) evalúa el desbalance en desviaciones estándar.
# En la literatura empírica, un SMD menor a 0.1 o 0.25 confirma que los grupos están equilibrados.
# ---------------------------------------------------------------------
media_t_usr <- weighted.mean(datos_basales$usuarios_licenciados[datos_basales$es_tratado == 1], datos_basales$peso_ipw[datos_basales$es_tratado == 1])
media_c_usr <- weighted.mean(datos_basales$usuarios_licenciados[datos_basales$es_tratado == 0], datos_basales$peso_ipw[datos_basales$es_tratado == 0])
var_conjunta_usr <- (var(datos_basales$usuarios_licenciados[datos_basales$es_tratado == 1]) + var(datos_basales$usuarios_licenciados[datos_basales$es_tratado == 0])) / 2
smd_usuarios <- abs(media_t_usr - media_c_usr) / sqrt(var_conjunta_usr)

media_t_fac <- weighted.mean(datos_basales$facturacion_anual_cliente[datos_basales$es_tratado == 1], datos_basales$peso_ipw[datos_basales$es_tratado == 1])
media_c_fac <- weighted.mean(datos_basales$facturacion_anual_cliente[datos_basales$es_tratado == 0], datos_basales$peso_ipw[datos_basales$es_tratado == 0])
var_conjunta_fac <- (var(datos_basales$facturacion_anual_cliente[datos_basales$es_tratado == 1]) + var(datos_basales$facturacion_anual_cliente[datos_basales$es_tratado == 0])) / 2
smd_facturacion <- abs(media_t_fac - media_c_fac) / sqrt(var_conjunta_fac)

cat("SMD Ponderado para Usuarios Licenciados:", round(smd_usuarios, 4), "\n") # Imprimimos balance de usuarios
cat("SMD Ponderado para Facturación Anual:", round(smd_facturacion, 4), "\n") # Imprimimos balance de facturación

# ---------------------------------------------------------------------
# BLOQUE 5: ESTIMACIÓN ECONOMÉTRICA STAGGERED DiD (CALLAWAY & SANT'ANNA)
# Propósito: Estimar el efecto causal medio del tratamiento para cada grupo y tiempo: ATT(g, t).
# El método 'dr' (Doblemente Robusto) combina ponderación por Propensity Score con una regresión
# de resultados: si cualquiera de los dos modelos está bien calibrado, la estimación es insesgada.
# Usamos exclusivamente a las cuentas que nunca recibieron el onboarding como control limpio.
# ---------------------------------------------------------------------
modelo_staggered <- att_gt(
  yname = "horas_capacitacion_empleado",                           # Métrica objetivo: Horas promedio de entrenamiento técnico
  tname = "periodo_fiscal",                                        # Periodo anual (2023, 2024, 2025)
  idname = "id_cuenta_cliente",                                    # Identificador de la cuenta corporativa
  gname = "primer_tratamiento",                                    # Cohorte de inicio del onboarding guiado
  xformla = ~ usuarios_licenciados + facturacion_anual_cliente,    # Covariables de control basal
  data = datos_modelo,                                             # Panel balanceado completo
  control_group = "nevertreated",                                  # Grupo de control puro (sin onboarding bonificado)
  est_method = "dr"                                                # Estimador Doblemente Robusto
)

# ---------------------------------------------------------------------
# BLOQUE 6: AGREGACIÓN DINÁMICA DE IMPACTOS (ESTUDIO DE EVENTOS)
# Propósito: Las cohortes comenzaron en años distintos (2024 y 2025). La función aggte()
# alinea a todas las cuentas en una escala de tiempo relativo:
# e = -1: Un año antes del onboarding (debe ser 0 para validar tendencias paralelas pre-existentes).
# e = 0: El año en que se ejecuta el onboarding bonificado (efecto inmediato).
# e = 1: Un año después de finalizar el onboarding (efecto de retención o desvanecimiento).
# ---------------------------------------------------------------------
estudio_eventos <- aggte(
  MP = modelo_staggered,                                           # Estimación base por cohortes
  type = "dynamic"                                                 # Alineación en tiempo relativo al onboarding (e = 0)
)

summary(estudio_eventos)                                           # Tabla de impactos causales dinámicos

# ---------------------------------------------------------------------
# BLOQUE 7: VISUALIZACIONES EJECUTIVAS PARA PRESENTACIÓN DE NEGOCIO
# Propósito: Comunicar visualmente los hallazgos para stakeholders.
# Gráfico A (Event Study): Demuestra visualmente que no había pre-tendencias (e = -1 toca el cero),
# que hubo un pico en e = 0 (+34 hrs), y que el uso colapsó en e = 1 (efecto efímero).
# Gráfico B (Tendencias Brutas): Muestra la evolución en escala de calendario real de cada cohorte
# frente al grupo de control puro, destacando con líneas punteadas los momentos de activación.
# ---------------------------------------------------------------------
# A. Gráfico de Event Study (Efectos Dinámicos en el Tiempo)
ggdid(estudio_eventos)

# B. Tendencias Paralelas Observadas por Cohorte
datos_tendencias <- datos_modelo %>%
  group_by(periodo_fiscal, primer_tratamiento) %>%                 # Agrupamos por año y cohorte
  summarise(
    horas_promedio = mean(horas_capacitacion_empleado),            # Promedio de horas de entrenamiento
    .groups = "drop"                                               # Desagrupamos
  ) %>%
  mutate(
    cohorte = ifelse(primer_tratamiento == 0, "Control Puro", paste("Cohorte", primer_tratamiento)) # Nombre formal
  )

grafico_tendencias <- ggplot(
  data = datos_tendencias,                                         # Base agregada
  mapping = aes(x = periodo_fiscal, y = horas_promedio, color = cohorte, group = cohorte) # Mapeo visual
) +
  geom_line(linewidth = 1.2) +                                     # Líneas de tendencia
  geom_point(size = 3) +                                           # Puntos por periodo
  geom_vline(
    xintercept = c(2024, 2025),                                    # Años de inicio de las cohortes de onboarding
    linetype = "dashed",                                           # Línea discontinua
    color = "gray50"                                               # Color neutro
  ) +
  theme_minimal(base_size = 12) +                                  # Formato limpio
  labs(
    title = "Horas de Capacitación Técnica por Cohorte de Onboarding", # Título ejecutivo
    x = "Periodo Fiscal",                                          # Eje X
    y = "Horas de Entrenamiento por Empleado",                     # Eje Y
    color = "Programa de Onboarding"                               # Leyenda
  ) +
  scale_color_manual(
    values = c("#E69F00", "#56B4E9", "#009E73")                    # Paleta Okabe-Ito
  )

print(grafico_tendencias)                                          # Renderizamos las tendencias por cohorte
