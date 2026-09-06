# Análisis Causal de Onboarding en Clientes SaaS B2B

## Resumen Ejecutivo
Utilizando un panel longitudinal balanceado de 100 cuentas corporativas monitoreadas a lo largo de tres ejercicios fiscales (2023–2025), este proyecto evalúa el impacto causal de programas bonificados de onboarding técnico en la adopción de software. Mediante la metodología moderna de Diferencias en Diferencias Escalonado (Callaway & Sant'Anna) con estimación Doblemente Robusta, el análisis evidencia un incremento inmediato masivo (+34.3 horas de capacitación/empleado) durante el año subsidiado que se disipa por completo a cero tras finalizar el beneficio, demostrando que el subsidio acelera el uso inmediato pero no genera hábitos autónomos de adopción a largo plazo.

## 1. Caso de Negocio

CloudMetrics, una compañía SaaS B2B especializada en analítica e infraestructura de operaciones corporativas, identificó cuellos de botella persistentes en la adopción técnica entre sus clientes de medianas y grandes empresas. Para acelerar el valor percibido y garantizar la integración del software en los flujos diarios, la gerencia de Customer Success implementó una intervención de alto contacto: **un programa anual bonificado de Onboarding y Acompañamiento Técnico Dedicado**.

Por restricciones de capacidad operativa y técnica dentro del equipo de consultores, el despliegue del programa se realizó de forma escalonada entre diferentes cohortes de cuentas:
- **2023 (Línea Base)**: Nivel basal orgánico puro; ninguna cuenta corporativa recibió acompañamiento dedicado.
- **2024 (Cohorte 2024)**: Primera cohorte de cuentas en incorporarse al programa de onboarding bonificado.
- **2025 (Cohorte 2025)**: Segunda cohorte de cuentas en incorporarse al programa de onboarding bonificado.
- **Control Puro (Nunca Tratados)**: Cuentas que dependieron exclusivamente del autoservicio y la documentación técnica estándar.

La dirección ejecutiva requiere respuestas causales rigurosas a dos preguntas clave de negocio:
- **P1**: ¿El programa de onboarding bonificado aumentó de forma causal la capacitación y adopción técnica de los empleados?
- **P2**: ¿El efecto de adopción persiste una vez concluido el año bonificado, o el compromiso colapsa regresando a la línea base?

## 2. Estructura de Datos

El análisis se basa en un panel balanceado de **100 cuentas corporativas** seguidas consecutivamente a lo largo de **3 periodos fiscales (300 observaciones en total)** almacenadas en `data/saas_b2b_onboarding.csv`.

A continuación se presenta una muestra de la estructura del panel empresarial:

![image alt](https://github.com/GeorgeWLZD/Staggered_DiD/blob/01a55b06dc7307e955337b4f792a188172ab52cf/img/head.png)

### Variables Principales
- `id_cuenta_cliente`: Identificador único para cada cuenta corporativa.
- `periodo_fiscal`: Ejercicio fiscal de observación (2023, 2024, 2025).
- `onboarding_bonificado`: Indicador binario de tratamiento (1 si la cuenta cuenta con onboarding activo ese año, 0 en caso contrario).
- `horas_capacitacion_empleado`: Métrica de resultado principal ($Y$) que mide las horas anuales promedio de entrenamiento técnico completadas por empleado licenciado.
- `usuarios_licenciados`: Total de licencias contratadas, como variable de control por escala organizacional.
- `facturacion_anual_cliente`: Nivel de facturación/ventas de la empresa cliente, como control por capacidad económica previa.

## 3. Resultados de Staggered DiD

Dado que el despliegue ocurrió en momentos temporales distintos y la asignación de cuentas no fue puramente aleatoria, los modelos lineales tradicionales de Efectos Fijos Bidireccionales (TWFE) generan sesgos por ponderaciones negativas. Se implementó el estimador de **Diferencias en Diferencias Escalonado de Callaway & Sant'Anna (2021)** bajo el método Doblemente Robusto (`dr`).

### Soporte Común del Propensity Score y Balance de Covariables (Línea Base 2023)
Para corregir el sesgo de selección inicial (cuentas más grandes o con mayor facturación ingresando primero al programa), se estimó una regresión logística para calcular el *Propensity Score* a partir de los datos basales de 2023.

Se calcularon ponderadores por el inverso de la probabilidad de tratamiento (IPW) para validar el supuesto de soporte común (*overlap*) entre las cuentas tratadas a futuro y las que nunca recibieron el programa:

![image alt](https://github.com/GeorgeWLZD/Staggered_DiD/blob/6564dd43de34618e9a30abcbf5435a01235c8a54/img/soporte_comun.png)

Las pruebas diagnósticas confirmaron un balance adecuado entre los grupos post-ponderación:
- **Diferencia de Medias Estandarizada (SMD) - Usuarios Licenciados**: 0.0126 (inferior al umbral de 0.1)
- **Diferencia de Medias Estandarizada (SMD) - Facturación del Cliente**: 0.0736 (inferior al umbral de 0.1)

### Evolución de Tendencias Observadas por Cohorte
Al calcular el promedio de horas de capacitación por cohorte en su escala original, se observa el comportamiento del panel antes y después de cada despliegue:

![image alt](https://github.com/GeorgeWLZD/Staggered_DiD/blob/6564dd43de34618e9a30abcbf5435a01235c8a54/img/tendendecias_observadas.png)

Ambas cohortes de intervención siguen un comportamiento estable y paralelo al grupo de control puro antes de ingresar al programa, respaldando la plausibilidad del supuesto de tendencias paralelas.

### Estimación Dinámica
Mediante la función `aggte(type = "dynamic")`, las trayectorias de las cuentas se alinearon en una escala de tiempo relativo al tratamiento ($e = 0$, el año en que inicia el onboarding bonificado):

![image alt](https://github.com/GeorgeWLZD/Staggered_DiD/blob/6564dd43de34618e9a30abcbf5435a01235c8a54/img/estimacion.png)

Los resultados estadísticos se muestran en la tabla:

| Tiempo Relativo ($e$) | Interpretación | Estimación ATT | Error Estándar | Intervalo de Confianza al 95% | Significancia Estadística |
| :---: | :--- | :---: | :---: | :---: | :---: |
| **$e = -1$** | Validación de Tendencias Previas | **4.24** | 2.70 | [-1.67, 10.15] | No ($p > 0.05$) |
| **$e = 0$** | Impacto Inmediato del Onboarding | **33.96** | 4.35 | [24.43, 43.49] | Sí ($p < 0.001$) |
| **$e = +1$** | Retención Post-Subsidio (Año 2) | **-1.46** | 4.10 | [-10.44, 7.51] | No ($p > 0.05$) |

### Conclusiones de los Resultados
- **Validación de Pre-tendencias ($e = -1$)**: El efecto causal antes de la intervención es indistinguible de cero, demostrando que las cuentas tratadas no presentaban un crecimiento previo artificial frente al control.
- **Impacto Inmediato ($e = 0$)**: El onboarding bonificado genera un incremento de **+33.96 horas de entrenamiento por empleado**, confirmando una alta adopción operativa mientras la consultoría es bonificada al 100%.
- **Desvanecimiento Post-Programa ($e = +1$)**: Un año después, al vencer la bonificación, el efecto incremental colapsa a **-1.46 horas** (estadísticamente nulo). Las cuentas regresan de forma inmediata a los niveles base del grupo sin intervención, en lugar de sostener rutinas internas autónomas.

## 4. Recomendaciones de Negocio

- **Migrar de Subsidios Totales a Modelos de Co-inversión**: Entregar servicios 100% gratuitos infla artificialmente el uso inmediato sin crear hábitos sostenibles. Diseñar esquemas de cofinanciamiento (por ejemplo, cobertura del 50% por parte del cliente) ayuda a filtrar cuentas con un compromiso genuino de integración técnica.

- **Priorizar la Automatización en el Producto sobre el Acompañamiento Manual**: Dado que el soporte humano no deja un impacto duradero tras retirarse, conviene dirigir los esfuerzos hacia guías interactivas integradas en la interfaz, hitos guiados por el sistema y rutas de certificación por rol operadas de manera autónoma.

- **Establecer un Plan de Transición Gradual a Partir del Mes 9**: La caída abrupta en el segundo año muestra un efecto precipicio al terminarse el contrato de consultoría. Implementar un protocolo de traspaso en el último trimestre para transferir formalmente la responsabilidad técnica a líderes internos de la empresa cliente.

- **Alinear los Incentivos de Customer Success a la Retención a Largo Plazo**: Estructurar los objetivos de los consultores y CSMs en función de la actividad en la plataforma al mes 18 y 24, desincentivando el consumo acelerado enfocado únicamente en la ventana del primer año.
