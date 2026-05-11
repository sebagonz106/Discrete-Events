# Plan de Implementación: Simulador de Evolución Poblacional por Eventos Discretos

## Análisis del Problema

### Complejidad del Sistema
El problema requiere simular la evolución de una población durante **100 años** con múltiples variables estocásticas:
- **Eventos vitales**: nacimientos, muertes, emparejamientos, rupturas
- **Estados individuales**: edad, sexo, estado civil, número de hijos deseados
- **Probabilidades condicionadas**: dependen de edad, sexo, contexto social

### Características Técnicas Requeridas
1. **Generación de variables aleatorias**: Uniforme (nacimientos, sexo), Exponencial (tiempos de recuperación)
2. **Gestión de eventos discretos**: Cola de eventos ordenada por tiempo
3. **Estado mutable**: cada individuo cambia su estado continuamente
4. **Análisis estadístico**: tracking de métricas poblacionales (nacimientos, muertes, matrimonios)

---

## PASO 1: Selección de Arquitectura y Estrategia Híbrida

### Enfoque Modular Multinlenguaje

Se propone una arquitectura que separa las responsabilidades computacionales según las fortalezas de cada lenguaje:

#### **Julia: Motor de Simulación**
**Responsabilidades:**
- Implementación del motor de eventos discretos (DES)
- Generación de variables aleatorias según distribuciones especificadas
- Gestión eficiente de la población y sus transiciones de estado
- Iteración temporal sobre 100 años de simulación
- Exportación de resultados a formato CSV

**Justificación técnica:**
- Lenguaje diseñado para computación científica y simulación estocástica
- Rendimiento superior (10-100x vs Python): crucial para loops complejos
- Sintaxis múltiple-despacho (multiple dispatch) ideal para manejo de eventos
- Estructuras de datos inmutables eficientes (structs)
- Biblioteca estándar robusta para manipulación numérica y temporal

#### **Python: Análisis y Visualización**
**Responsabilidades:**
- Lectura e ingesta de datos simulados desde CSVs
- Cálculo de métricas estadísticas secundarias
- Análisis estadístico según scipy.stats
- Generación de visualizaciones y gráficos
- Síntesis de informe técnico en formato PDF

**Justificación técnica:**
- Ecosistema científico maduro: pandas, numpy, scipy, matplotlib
- Ferramentas de análisis estadístico especializadas
- Capacidades de visualización profesionales
- Facilita generación de reportes automatizados

### **Comunicación Intercapas: CSV**

La separación entre ambos componentes se realiza mediante archivos CSV con estructura definida:

- **Motor Julia genera** → CSVs con datos brutos y agregaciones anuales
- **Análisis Python consume** → Lee, procesa, visualiza y reporta

Esta separación garantiza:
- Independencia de versiones (Julia y Python pueden actualizarse sin acoplamiento)
- Reproducibilidad y trazabilidad de cada fase
- Posibilidad de re-análisis sin re-ejecutar simulación
- Validación manual de resultados intermedios

---

## PASO 2: Diseño de la Arquitectura del Sistema

### Componentes Principales y Flujo de Datos

```
┌──────────────────────────────────────────────────────────────┐
│                   MÓDULO JULIA (Motor DES)                  │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─ RandomGenerator.jl                                     │
│  │  • Generación uniforme y exponencial                   │
│  │  • Métodos transformada inversa                        │
│  │                                                         │
│  ┌─ Person.jl                                             │
│  │  • struct Person (inmutable, eficiente)                │
│  │  • Atributos: edad, sexo, pareja_id, hijos, estado    │
│  │                                                         │
│  ┌─ EventEngine.jl                                        │
│  │  • struct Event (tipo, tiempo, agentes)               │
│  │  • BinaryMinHeap para cola de prioridad               │
│  │  • process_event!() → mutaciones de estado             │
│  │                                                         │
│  ┌─ PopulationSimulator.jl (orquestador)                 │
│  │  • Inicialización poblacional                          │
│  │  • Loop temporal: extrae → procesa → acumula           │
│  │  • Exporta resultados a CSV                            │
│  │                                                         │
└──────────────────────────────────────────────────────────────┘
                           ↓
              ┌────────────────────────┐
              │   results.csv          │
              │   timeline.csv         │
              │   population_age.csv   │
              └────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────────┐
│              MÓDULO PYTHON (Análisis)                        │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─ data_loader.py                                         │
│  │  • Lectura de CSVs a DataFrames (pandas)               │
│  │  • Validación de integridad de datos                   │
│  │                                                         │
│  ┌─ metrics.py                                            │
│  │  • Cálculo tasas vitales, ratios, medias              │
│  │  • Análisis estadístico (scipy.stats)                 │
│  │                                                         │
│  ┌─ visualization.py                                      │
│  │  • Gráficos: líneas, histogramas, pirámide            │
│  │  • Matplotlib + seaborn                                │
│  │                                                         │
│  ┌─ report.py (orquestador)                              │
│  │  • Lee datos → calcula métricas → genera gráficos     │
│  │  • Exporta informe PDF con resultados                 │
│  │                                                         │
└──────────────────────────────────────────────────────────────┘
```

### Esquema de Archivos CSV de Interfaz

#### **results.csv** - Agregaciones Anuales
```csv
year,population,births,deaths,marriages,divorces,median_age,sex_ratio
0,1000,50,10,15,3,50.2,0.98
1,1040,52,12,18,4,50.5,0.99
2,1080,55,11,20,5,51.0,1.00
...
100,1500,75,15,25,8,55.3,1.02
```

**Propósito:** Base para cálculo de tasas vitales y análisis temporal. Columnas mínimas requeridas.

#### **population_age.csv** - Estructura Etaria Decadal
```csv
year,age_range,males,females
0,0-5,45,43
0,5-10,48,46
0,10-15,52,50
...
10,0-5,55,52
10,5-10,45,43
...
```

**Propósito:** Disponible cada 10 años para construcción de pirámide poblacional.

#### **timeline.csv** - Series Temporales de Eventos (Opcional)
```csv
time_day,event_type,event_count,population
0,birth,5,1000
0,death,1,1000
365,birthday_cohort,1000,1000
365,pregnancy,42,1000
```

**Propósito:** Análisis granular de dinámicas, debugging y validación.

### Estructura de Datos Julia

**Person (struct inmutable):**
```julia
mutable struct Person
    id::Int64
    age::Float64
    sex::Char  # 'M' o 'F'
    partner_id::Union{Int64, Nothing}
    desired_children::Int64
    num_children::Int64
    marital_status::String  # "single", "married", "widowed"
    waiting_time::Float64   # para período post-ruptura
end
```

**Event (struct inmutable):**
```julia
struct Event
    type::String            # "death", "birth", "marriage", etc
    time::Float64           # tiempo en días
    agents::Vector{Int64}   # IDs de agentes involucrados
    data::Dict              # parámetros específicos del evento
end
```

**Priority Queue (BinaryMinHeap):**
- Extracción O(log n) del evento más próximo
- Inserción O(log n) de nuevos eventos
- Eficiente para hasta 100,000+ eventos

### Consideraciones de Diseño

1. **Inmutabilidad en Julia**: structs en vez de clases mutables cuando sea posible
   - Mejor rendimiento en loops
   - Facilita paralelización futura

2. **Pre-allocación**: Arreglos de población pre-asignados
   - Evita re-asignaciones costosas durante simulación

3. **Batch Exports**: CSVs generados una sola vez al final
   - En vez de I/O en cada timestep

---

## PASO 3: Implementación del Motor de Simulación en Julia

Se estructura el motor de eventos discretos sobre la base metodológica del Capítulo 3 de "Temas de Simulación", con tres componentes explícitos: **variables de tiempo**, **variables contadoras**, y **variables de estado del sistema (SS)**.

### Módulos Julia a Desarrollar

| Módulo | Responsabilidad | Funciones Principales |
|--------|-----------------|----------------------|
| `random_generator.jl` | Variables aleatorias | `uniform()`, `exponential()`, `lookup_probability()` |
| `person.jl` | Modelo de individuo | Definición struct Person |
| `event_engine.jl` | Motor de eventos | `add_event!()`, `process_event!()`, `pop_event!()` |
| `population.jl` | Gestión poblacional | `initialize_population()`, `find_couples()`, `update_statistics!()` |
| `simulator.jl` | Orquestador principal | `run_simulation()`, `export_to_csv()` |
| `probability_tables.jl` | Tablas de parámetros | Constantes con todas las probabilidades del problema |

### Definición de Variables para el Sistema DES

**Variables de Tiempo:**
- `t`: Tiempo de simulación que ha transcurrido (en días)
- `T_final`: Límite de simulación (36,500 días ≈ 100 años)

**Variables Contadoras:**
- `N_B`: Número de nacimientos acumulados
- `N_D`: Número de muertes acumuladas
- `N_M`: Número de matrimonios formados acumulados
- `N_R`: Número de rupturas ocurridas acumuladas
- `Contador_anual[]`: Contadores por año para aggregación

**Variables de Estado del Sistema (SS):**
- `poblacion[]` : Vector de individuals (Person structs)
- `tiempo_actual`: Tiempo current en la simulación
- `año_actual`: Año actual (para agregación de datos)
- `eventos_por_tipo`: Diccionario para tracking de eventos

**Lista de Eventos (Priority Queue):**
```julia
ListaEventos = BinaryMinHeap{Event}()
# Mantiene ordenados: (t_muerte, t_nacimiento, t_ruptura, t_emparejamiento)
# Similar al formato del libro: (t_A, t_D, t_1, t_2)
```

### Algoritmo Principal de Simulación (Estilo Capítulo 3)

```
═══════════════════════════════════════════════════════════════
INICIALIZACIÓN:
═══════════════════════════════════════════════════════════════

1. Establecer variables de tiempo:
   t ← 0
   T_final ← 36,500 (100 años en días)
   año_actual ← 0

2. Establecer variables contadoras:
   N_B ← 0
   N_D ← 0
   N_M ← 0
   N_R ← 0

3. Establecer variables de estado:
   poblacion ← crear_poblacion_inicial(M, H)
      Para cada individuo:
         edad ← Uniforme(0, 100)
         sexo ← 'M' ó 'F' (50% cada uno)
         pareja_id ← Nothing
         hijos ← 0
         hijos_deseados ← sample_desired_children()

4. Inicializar lista de eventos:
   ListaEventos ← BinaryMinHeap()
   Para cada individuo i en poblacion:
      • Generar próxima muerte: t_muerte ← t + tiempo_hasta_muerte(edad, sexo)
      • Add Event("muerte", t_muerte, i)
      • Si mujer y fértil: generar próximo embarazo
      • Si edad >= 12 y <= 45: generar próxima búsqueda pareja

5. Generar evento de fin de año (para agregación anual):
   Add Event("fin_año", 365, {})

═══════════════════════════════════════════════════════════════
SIMULACIÓN (LOOP PRINCIPAL):
═══════════════════════════════════════════════════════════════

MIENTRAS (ListaEventos no vacía) AND (t < T_final):

   1. EXTRAER próximo evento de cola:
      evento ← pop_min(ListaEventos)
      t ← evento.time
      tipo_evento ← evento.type
      agentes ← evento.agents
   
   2. ACTUALIZAR AÑO:
      SI t mod 365 != año_actual mod 365:
         año_actual ← floor(t / 365)
         Acumular estadísticas del año anterior

   3. PROCESAR evento SEGÚN TIPO: (CASOS explícitos)

   ───────────────────────────────────────────────────────────
   CASO 1: MUERTE (tipo = "muerte")
   ───────────────────────────────────────────────────────────
   
   SI t <= T_final:
      individuo_id ← agentes[1]
      persona ← obtener_persona(poblacion, individuo_id)
      
      N_D ← N_D + 1
      
      SI persona.pareja_id ≠ Nothing:
         pareja ← obtener_persona(poblacion, persona.pareja_id)
         pareja.pareja_id ← Nothing
         pareja.estado_marital ← "viudo"
         
         // Schedular período de espera (Exponencial)
         λ_espera ← lookup_lambda_espera(pareja.edad)
         t_fin_espera ← t + exponential(λ_espera)
         Add Event("fin_espera_pareja", t_fin_espera, pareja_id)
      
      // Schedular búsqueda de parejas si aplica (si hay hijos menores)
      // [Procesamiento de hijos dependientes omitido para brevedad]
      
      // Remover de población
      poblacion ← remove(poblacion, individuo_id)

   ───────────────────────────────────────────────────────────
   CASO 2: CUMPLEAÑOS ANUAL (tipo = "cumpleaños_anual")
   ───────────────────────────────────────────────────────────
   
   SI tipo_evento == "fin_año":
      // Envejecer población
      PARA cada persona EN poblacion:
         persona.edad ← persona.edad + 1
         
         // Evaluar muerte este año
         p_muerte ← get_death_probability(persona.edad, persona.sexo)
         SI random() < p_muerte:
            t_muerte ← t + uniform(0, 365)
            Add Event("muerte", t_muerte, persona.id)
         
         // Si mujer fértil SIN pareja: possibilidad de búsqueda parejas
         SI persona.sexo == 'F' AND 12 <= persona.edad <= 45:
            SI persona.pareja_id == Nothing:
               Add Event("busqueda_pareja", t, persona.id)
      
      // Schedular próximo fin de año
      Add Event("fin_año", t + 365, {})

   ───────────────────────────────────────────────────────────
   CASO 3: EMBARAZO (tipo = "embarazo_intento")
   ───────────────────────────────────────────────────────────
   
   SI t <= T_final:
      madre_id ← agentes[1]
      madre ← obtener_persona(poblacion, madre_id)
      
      // Verificar condiciones
      SI madre.pareja_id ≠ Nothing AND madre.num_hijos < madre.hijos_deseados:
         pareja ← obtener_persona(poblacion, madre.pareja_id)
         SI pareja.num_hijos < pareja.hijos_deseados:
            
            // Evaluación de embarazo
            p_embarazo ← get_pregnancy_probability(madre.edad)
            SI random() < p_embarazo:
               
               // Generar número de bebés
               num_bebes ← sample_num_babies()
               
               // Schedular nacimiento en ~280 días
               t_nacimiento ← t + 280
               Add Event("nacimiento", t_nacimiento, madre_id, {"num_bebes": num_bebes})
      
      // Schedular próximo intento de embarazo (1 año después)
      Add Event("embarazo_intento", t + 365, madre_id)

   ───────────────────────────────────────────────────────────
   CASO 4: NACIMIENTO (tipo = "nacimiento")
   ───────────────────────────────────────────────────────────
   
   SI t <= T_final:
      madre_id ← agentes[1]
      madre ← obtener_persona(poblacion, madre_id)
      num_bebes ← evento_data["num_bebes"]
      
      N_B ← N_B + num_bebes
      
      PARA i EN 1..num_bebes:
         nuevo_id ← generar_nuevo_id()
         sexo ← sample_sexo()  // Uniforme: 50% M, 50% F
         hijos_deseados ← sample_desired_children()
         
         nuevo_individuo ← Person(
            id=nuevo_id,
            edad=0,
            sexo=sexo,
            pareja_id=Nothing,
            num_hijos=0,
            hijos_deseados=hijos_deseados,
            estado_marital="soltero"
         )
         
         Add evento_data con padre/madre_id para trazabilidad
         poblacion ← push(poblacion, nuevo_individuo)
         
         // Schedular primer cumpleaños
         Add Event("cumpleaños_anual", t + 365, nuevo_id)
      
      madre.num_hijos ← madre.num_hijos + num_bebes
      SI madre.pareja_id ≠ Nothing:
         pareja ← obtener_persona(poblacion, madre.pareja_id)
         pareja.num_hijos ← pareja.num_hijos + num_bebes

   ───────────────────────────────────────────────────────────
   CASO 5: RUPTURA MATRIMONIAL (tipo = "ruptura")
   ───────────────────────────────────────────────────────────
   
   SI t <= T_final:
      persona1_id ← agentes[1]
      persona1 ← obtener_persona(poblacion, persona1_id)
      persona2_id ← persona1.pareja_id
      persona2 ← obtener_persona(poblacion, persona2_id)
      
      N_R ← N_R + 1
      
      // Disolver pareja
      persona1.pareja_id ← Nothing
      persona1.estado_marital ← "divorciado"
      
      persona2.pareja_id ← Nothing
      persona2.estado_marital ← "divorciado"
      
      // Schedular período de espera para ambos (Exponencial)
      PARA persona EN [persona1, persona2]:
         λ_espera ← lookup_lambda_espera(persona.edad)
         t_fin_espera ← t + exponential(λ_espera)
         Add Event("fin_espera_pareja", t_fin_espera, persona.id)

   ───────────────────────────────────────────────────────────
   CASO 6: FIN PERÍODO ESPERA (tipo = "fin_espera_pareja")
   ───────────────────────────────────────────────────────────
   
   persona_id ← agentes[1]
   persona ← obtener_persona(poblacion, persona_id)
   
   persona.estado_marital ← "soltero"
   // Ahora disponible para búsqueda de parejas

   ───────────────────────────────────────────────────────────
   CASO 7: BÚSQUEDA Y EMPAREJAMIENTO (tipo = "busqueda_pareja")
   ───────────────────────────────────────────────────────────
   
   SI t <= T_final:
      // Buscar solteros disponibles de ambos sexos
      solteras ← filter(poblacion, sexo='F' AND edad_fertile AND estado='soltero')
      solteros ← filter(poblacion, sexo='M' AND edad_fertile AND estado='soltero')
      
      PARA mujer EN solteras:
         // ¿Mujer desea pareja?
         p_quiere_pareja ← get_want_partner_prob(mujer.edad)
         SI random() < p_quiere_pareja:
            
            PARA hombre EN solteros:
               // ¿Hombre desea pareja?
               p_quiere_pareja_h ← get_want_partner_prob(hombre.edad)
               SI random() < p_quiere_pareja_h:
                  
                  // Calcular probabilidad según diferencia edad
                  diff_edad ← |hombre.edad - mujer.edad|
                  p_formar_pareja ← get_couple_formation_prob(diff_edad)
                  
                  SI random() < p_formar_pareja:
                     // Formar pareja
                     mujer.pareja_id ← hombre.id
                     mujer.estado_marital ← "casado"
                     hombre.pareja_id ← mujer.id
                     hombre.estado_marital ← "casado"
                     
                     N_M ← N_M + 1
                     
                     // Schedular posible embarazo
                     Add Event("embarazo_intento", t + uniform(30, 180), mujer.id)
                     
                     // Schedular posible ruptura (p=0.2 uniforme)
                     t_ruptura ← t + uniform(0, 36500)  // En algún momento del futuro
                     Add Event("ruptura", t_ruptura, mujer.id)
                     
                     BREAK  // Pareja encontrada
            
            // Si no encontró pareja, reintentar en 1 año
            Add Event("busqueda_pareja", t + 365, mujer.id)

   4. FIN DEL LOOP DE PROCESAR CASO
   5. CONTINUAR CON SIGUIENTE EVENTO

═══════════════════════════════════════════════════════════════
CONDICIÓN DE TÉRMINO:
═══════════════════════════════════════════════════════════════

Cuando ListaEventos está vacía O t >= T_final

═══════════════════════════════════════════════════════════════
EXPORTACIÓN Y ANÁLISIS:
═══════════════════════════════════════════════════════════════

1. Compilar estadísticas anuales en DataFrames
2. Escribir results.csv con: (año, población, N_B, N_D, N_M, N_R, edad_media, razón_sexos)
3. Escribir population_age.csv con: (año, rango_edad, hombres, mujeres) cada 10 años
4. Validar integridad: sum(poblacion_final) y flujos poblacionales
```

### Pseudocódigo DetailADO: Procesamiento de Evento

```julia
function process_event!(event::Event, population::Vector{Person}, 
                       event_queue::BinaryMinHeap, 
                       time_current::Float64)::Nothing
    
    if event.type == "death"
        person = population[event.agents[1]]
        idx = findfirst(p -> p.id == event.agents[1], population)
        
        # Si tiene pareja
        if person.partner_id !== Nothing
            partner = get_person(population, person.partner_id)
            partner.partner_id = Nothing
            partner.marital_status = "widowed"
            
            # Schedular período de espera (exponencial)
            λ = get_waiting_lambda(partner.age)
            waiting_time = exponential(λ)
            add_event!(event_queue, 
                      Event("end_waiting", 
                            time_current + waiting_time,
                            [partner.id],
                            Dict()))
        end
        
        # Eliminar de población
        deleteat!(population, idx)
        
    elseif event.type == "birthday"
        person = population[event.agents[1]]
        person.age += 1.0
        
        # Evaluar muerte este año
        death_prob = get_death_probability(person.age, person.sex)
        if rand() < death_prob
            add_event!(event_queue, 
                      Event("death", time_current + rand(365), 
                            [person.id], Dict()))
        end
        
        # Si mujer y fértil: posible embarazo
        if person.sex == 'F' && person.age >= 12 && person.age < 51
            if person.partner_id !== Nothing
                preg_prob = get_pregnancy_probability(person.age)
                if rand() < preg_prob
                    num_babies = sample_num_babies()
                    add_event!(event_queue,
                              Event("birth",
                                    time_current + 280,  # gestación ~280 días
                                    [person.id],
                                    Dict("num_babies" => num_babies)))
                end
            end
        end
        
        # Schedular próximo cumpleaños
        add_event!(event_queue, 
                  Event("birthday", time_current + 365, 
                        [person.id], Dict()))
    end
    
    # ... (resto de tipos de evento)
end
```

### Implementación Detallada: Caso NACIMIENTO

```julia
function process_event_nacimiento!(evento::Event, 
                                    poblacion::Vector{Person},
                                    lista_eventos::BinaryMinHeap,
                                    counters::Dict,
                                    t::Float64,
                                    T_final::Float64)::Nothing
    
    # CASO 4 del algoritmo principal
    if t <= T_final
        madre_id = evento.agents[1]
        madre = get_person(poblacion, madre_id)
        num_bebes = evento.data["num_bebes"]
        
        # Actualizar contador
        counters["N_B"] += num_bebes
        
        # Crear cada bebé
        for _ in 1:num_bebes
            nuevo_id = generate_new_id()
            sexo = rand() < 0.5 ? 'M' : 'F'
            hijos_deseados = sample_desired_children()
            
            nuevo_individuo = Person(
                id = nuevo_id,
                age = 0.0,
                sex = sexo,
                partner_id = nothing,
                num_children = 0,
                desired_children = hijos_deseados,
                marital_status = "single"
            )
            
            push!(poblacion, nuevo_individuo)
            
            # Generar próximo cumpleaños (GENERAR SIGUIENTE EVENTO DEL MISMO TIPO)
            t_proximo_cumple = t + 365
            push!(lista_eventos, Event(
                type = "cumpleaños_anual",
                time = t_proximo_cumple,
                agents = [nuevo_id],
                data = Dict()
            ))
        end
        
        # Actualizar madre
        madre.num_children += num_bebes
        
        # Actualizar pareja si existe
        if madre.partner_id !== nothing
            pareja = get_person(poblacion, madre.partner_id)
            pareja.num_children += num_bebes
        end
    end
    
    return nothing
end
```

### Punto Crítico de Validación

El modelo debe validar en cada evento:

```julia
# En cada CASO de procesamiento de evento, antes de enviar siguiente:
function validate_event_consistency(persona::Person, poblacion::Vector{Person})
    # VALIDACIÓN 1: Si tiene pareja, pareja debe estar en población
    if persona.partner_id !== nothing
        @assert haskey(poblacion, persona.partner_id) "Inconsistencia: pareja no existe"
    end
    
    # VALIDACIÓN 2: Si tiene hijos, no pueden exceder deseados
    @assert persona.num_children <= persona.desired_children "Inconsistencia: hijos > deseados"
    
    # VALIDACIÓN 3: Estado marital coherente con partner_id
    if persona.partner_id !== nothing
        @assert persona.marital_status ∈ ["married", "widowed"] "Estado incoherente"
    end
    
    return true
end
```

---

## PASO 4: Generación de Variables Aleatorias en Julia

### Implementación de Métodos de Transformada Inversa

**Principio Fundamental:**
Sea $U \sim \text{Uniforme}(0,1)$ y $F$ la CDF deseada, entonces $X = F^{-1}(U)$ tiene distribución $F$.

#### Uniforme(a, b)
```julia
function uniform(a::Float64, b::Float64)::Float64
    return a + (b - a) * rand()
end
```

#### Exponencial(λ)
La CDF es $F(x) = 1 - e^{-\lambda x}$, entonces $F^{-1}(u) = -\frac{1}{\lambda}\log(u)$

```julia
function exponential(lambda::Float64)::Float64
    u = rand()
    return -(1.0 / lambda) * log(u)
end
```

#### Poisson(λ) - para número de bebés
Generar variables: contar cuántos exponenciales caben en [0,1]

```julia
function poisson(lambda::Float64)::Int64
    # Generar exponenciales hasta que su suma > 1
    # Contar cuántas se generaban
    L = exp(-lambda)
    k = 0
    p = 1.0
    while p > L
        k += 1
        u = rand()
        p *= u
    end
    return k - 1
end
```

### Mapeo de Tablas de Probabilidades

Todas las tablas del PDF se implementan como diccionarios estructurados en Julia:

```julia
# probability_tables.jl

const DEATH_PROBABILITY = Dict(
    'M' => [
        (0, 12, 0.25),
        (12, 45, 0.1),
        (45, 76, 0.3),
        (76, 125, 0.7)
    ],
    'F' => [
        (0, 12, 0.25),
        (12, 45, 0.15),
        (45, 76, 0.35),
        (76, 125, 0.65)
    ]
)

const PREGNANCY_PROBABILITY = Dict(
    (12, 15) => 0.2,
    (15, 21) => 0.45,
    (21, 35) => 0.8,
    (35, 45) => 0.4,
    (45, 60) => 0.2,
    (60, 125) => 0.05
)

const DESIRED_CHILDREN = Dict(
    1 => 0.6,
    2 => 0.75,
    3 => 0.35,
    4 => 0.2,
    5 => 0.1,
    6 => 0.05  # "más de 5"
)

const WANT_PARTNER_PROBABILITY = Dict(
    (12, 15) => 0.6,
    (15, 21) => 0.65,
    (21, 35) => 0.8,
    (35, 45) => 0.6,
    (45, 60) => 0.5,
    (60, 125) => 0.2
)

const COUPLE_FORMATION_PROBABILITY = Dict(
    (0, 5) => 0.45,
    (5, 10) => 0.4,
    (10, 15) => 0.35,
    (15, 20) => 0.25,
    (20, 125) => 0.15  # "20 o más"
)

# ... (resto de tablas)

const BABIES_DISTRIBUTION = Dict(
    1 => 0.7,
    2 => 0.18,
    3 => 0.08,
    4 => 0.04,
    5 => 0.02
)

const WAITING_LAMBDA = Dict(  # en meses → convert a días
    (12, 15) => 3.0 / 30.0,     # 3 meses
    (15, 21) => 6.0 / 30.0,     # 6 meses
    (21, 35) => 6.0 / 30.0,     # 6 meses
    (35, 45) => 12.0 / 30.0,    # 1 año
    (45, 60) => 24.0 / 30.0,    # 2 años
    (60, 125) => 48.0 / 30.0    # 4 años
)
```

### Funciones de Búsqueda en Tablas

```julia
function get_age_bracket_probability(age::Float64, 
                                     bracket_table::Dict)::Float64
    """
    Busca en tabla con rangos de edad.
    Retorna la probabilidad asociada.
    """
    for (min_age, max_age, prob) in bracket_table
        if min_age <= age < max_age
            return prob
        end
    end
    error("Edad $age fuera de rango")
end

function get_death_probability(age::Float64, sex::Char)::Float64
    return get_age_bracket_probability(age, DEATH_PROBABILITY[sex])
end

function get_pregnancy_probability(age::Float64)::Float64
    return get_age_bracket_probability(age, PREGNANCY_PROBABILITY)
end

function sample_desired_children()::Int64
    """Muestrea número de hijos deseados según distribución uniforme."""
    r = rand()
    cumulative = 0.0
    for (num_children, prob) in sort(collect(DESIRED_CHILDREN))
        cumulative += prob
        if r < cumulative
            return num_children
        end
    end
    return 6  # fallback raro
end

function sample_num_babies()::Int64
    """Muestrea número de bebés en un embarazo."""
    r = rand()
    cumulative = 0.0
    for (num_babies, prob) in sort(collect(BABIES_DISTRIBUTION))
        cumulative += prob
        if r < cumulative
            return num_babies
        end
    end
    return 1  # fallback raro
end
```

### Validación de Generadores Aleatorios

Para documentación e informe, incluir pruebas de bondad de ajuste:

```julia
# En test/test_random_generator.jl
using StatsBase

function test_exponential_distribution(n_samples=10000)
    samples = [exponential(1.0) for _ in 1:n_samples]
    
    # Test: media ≈ 1
    @assert abs(mean(samples) - 1.0) < 0.05 "Media exponencial incorrecta"
    
    # Test: varianza ≈ 1
    @assert abs(var(samples) - 1.0) < 0.1 "Varianza exponencial incorrecta"
    
    println("✓ Exponencial(1.0) validado")
end

function test_poisson_distribution(lambda=3.0, n_samples=10000)
    samples = [poisson(lambda) for _ in 1:n_samples]
    
    # Test: media ≈ lambda
    @assert abs(mean(samples) - lambda) < 0.2 "Media de Poisson incorrecta"
    
    println("✓ Poisson($lambda) validado")
end
```

---

## PASO 5: Análisis y Visualización en Python

Los datos de simulación se procesan conforme a los principios de análisis estadístico del Capítulo 4 de "Temas de Simulación": estimadores insesgados (media de muestra), evaluación de calidad mediante varianza, e intervalos de confianza para métricas demográficas.

### Módulos Python a Desarrollar

| Módulo | Responsabilidad | Funciones Principales |
|--------|-----------------|---|
| `data_loader.py` | Lectura de CSVs | `load_results()`, `validate_data()` |
| `metrics.py` | Cálculo de métricas | `calc_vital_rates()`, `calc_statistics()` |
| `visualization.py` | Generación de gráficos | `plot_population()`, `plot_pyramid()`, `plot_rates()` |
| `statistical_analysis.py` | Análisis según Cap. 4 | `estimate_confidence_interval()`, `calc_estimator_std_dev()` |

### Métricas Demográficas Calculadas

Derivadas del archivo `results.csv`:

| Métrica | Fórmula | Unidad | Significado |
|---------|---------|--------|------------|
| **Tasa Bruta de Natalidad** | $\frac{\text{Nacimientos}}{\text{Población Media}} \times 1000$ | ‰ | Reproducción poblacional |
| **Tasa Bruta de Mortalidad** | $\frac{\text{Muertes}}{\text{Población Media}} \times 1000$ | ‰ | Intensidad de fallecimiento |
| **Crecimiento Natural** | Natalidad - Mortalidad | ‰ | Balance vital |
| **Razón de Sexos** | $\frac{N_{\text{hombres}}}{N_{\text{mujeres}}}$ | ratio | Proporción género |
| **Edad Mediana** | Percentil 50 edades | años | Punto central envejecimiento |
| **Edad Media** | $\frac{\sum \text{edades}}{N}$ | años | Promedio etario |
| **Tasa de Nupcialidad** | $\frac{\text{Nuevas parejas}}{\text{Población susceptible}} \times 1000$ | ‰ | Formación parejas |
| **Tasa de Divorcialidad** | $\frac{\text{Rupturas}}{\text{Parejas activas}} \times 1000$ | ‰ | Disrupción matrimonios |
| **Ind. Fecundidad** | $\frac{\text{Nacimientos año}}{N_{\text{mujeres fértiles}}} \times 1000$ | ‰ | Capacidad reproductiva |

### Análisis Estadístico (scipy.stats)

```python
import pandas as pd
import numpy as np
from scipy import stats

def analyze_results(df):
    """Análisis estadístico integral de resultados."""
    
    # 1. Distribuciones
    print("=== ANÁLISIS DE NORMALIDAD (Shapiro-Wilk) ===")
    _, p_value = stats.shapiro(df['population'].values)
    print(f"Población: p-value = {p_value:.4f}")
    # Si p > 0.05: puede ser normal
    
    # 2. Tendencias temporales (linear regression)
    x = np.arange(len(df))
    slope_births, intercept, r_value, p_value, std_err = \
        stats.linregress(x, df['births'].values)
    
    print(f"\nTendencia en nacimientos:")
    print(f"  Pendiente: {slope_births:.3f} nacimientos/año")
    print(f"  R²: {r_value**2:.4f}")
    print(f"  Significancia: {'sí' if p_value < 0.05 else 'no'}")
    
    # 3. Periodicidades (si aplica)
    fft_births = np.fft.fft(df['births'].values)
    freqs = np.fft.fftfreq(len(df))
    
    # 4. Autocorrelación
    acf_values = [df['population'].autocorr(lag=k) for k in range(1, 10)]
    
    return {
        'births_trend': slope_births,
        'population_r2': r_value**2,
        'has_periodicity': np.max(np.abs(fft_births[1:len(fft_births)//2])) > threshold
    }
```

### Visualizaciones Principales

#### 1. Serie Temporal: Población Total
```python
import matplotlib.pyplot as plt

def plot_population_time_series(df):
    fig, ax = plt.subplots(figsize=(12, 6))
    ax.plot(df['year'], df['population'], linewidth=2.5, color='#2E86AB')
    ax.fill_between(df['year'], df['population'], alpha=0.3, color='#2E86AB')
    ax.set_xlabel('Año', fontsize=12)
    ax.set_ylabel('Población Total', fontsize=12)
    ax.set_title('Evolución de la Población (100 años)', fontsize=14, fontweight='bold')
    ax.grid(True, alpha=0.3)
    return fig
```

#### 2. Pirámide Poblacional
```python
def plot_population_pyramid(df_pyramid, years_to_show=[0, 50, 100]):
    """
    Construye pirámide etaria comparativa en 3 momentos.
    """
    fig, axes = plt.subplots(1, 3, figsize=(15, 6), sharey=True)
    
    for idx, year in enumerate(years_to_show):
        data_year = df_pyramid[df_pyramid['year'] == year]
        
        ax = axes[idx]
        age_ranges = data_year['age_range'].values
        males = data_year['males'].values
        females = data_year['females'].values
        
        # Gráfico de barras horizontal espejo
        ax.barh(age_ranges, -males, label='Hombres', color='#A23B72')
        ax.barh(age_ranges, females, label='Mujeres', color='#F18F01')
        
        ax.set_xlabel('Población', fontsize=10)
        ax.set_title(f'Año {year}', fontsize=11, fontweight='bold')
        ax.legend(loc='lower right', fontsize=9)
        ax.axvline(x=0, color='black', linewidth=0.8)
        ax.grid(True, alpha=0.2, axis='x')
    
    plt.tight_layout()
    return fig
```

#### 3. Tasas Vitales Comparadas
```python
def plot_vital_rates(df):
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 8))
    
    # Natalidad vs Mortalidad
    ax1.plot(df['year'], df['births'] / df['population'] * 1000, 
             label='Tasa Natalidad', linewidth=2, marker='o')
    ax1.plot(df['year'], df['deaths'] / df['population'] * 1000,
             label='Tasa Mortalidad', linewidth=2, marker='s')
    ax1.set_ylabel('Tasa (‰)', fontsize=11)
    ax1.legend()
    ax1.grid(True, alpha=0.3)
    ax1.set_title('Tasas Vitales', fontweight='bold')
    
    # Razón de sexos
    ax2.plot(df['year'], df['sex_ratio'], linewidth=2.5, 
             color='#06A77D')
    ax2.axhline(y=1.0, color='red', linestyle='--', linewidth=1.5, alpha=0.7)
    ax2.set_xlabel('Año', fontsize=11)
    ax2.set_ylabel('Razón H/M', fontsize=11)
    ax2.set_title('Evolución de Razón de Sexos', fontweight='bold')
    ax2.grid(True, alpha=0.3)
    
    plt.tight_layout()
    return fig
```

#### 4. Análisis de Sensibilidad (Heatmap)
```python
def plot_sensitivity_analysis(param_ranges, metric_values):
    """
    Matriz de sensibilidad: cómo varía métrica ante cambios en 2 parámetros.
    """
    import seaborn as sns
    
    fig, ax = plt.subplots(figsize=(10, 8))
    sns.heatmap(metric_values, 
                xticklabels=param_ranges['x'],
                yticklabels=param_ranges['y'],
                annot=True, fmt='.2f', cmap='RdYlGn',
                cbar_kws={'label': 'Población final'})
    ax.set_title('Análisis de Sensibilidad: Población vs Parámetros',
                 fontweight='bold', fontsize=12)
    return fig
```

### Verificación e Integración

```python
# main_analysis.py
import pandas as pd
from data_loader import load_results
from metrics import analyze_results
from visualization import *
from report import generate_pdf_report

# 1. Cargar resultados de Julia
print("Cargando resultados de simulación...")
df = load_results("results.csv")
df_pyramid = load_results("population_age.csv")

# 2. Calcular métricas
print("Calculando métricas...")
metrics = analyze_results(df)

# 3. Generar visualizaciones
print("Generando gráficos...")
figures = [
    plot_population_time_series(df),
    plot_population_pyramid(df_pyramid),
    plot_vital_rates(df),
]
plt.savefig("population_trend.png", dpi=300, bbox_inches='tight')

print("✓ Análisis completado")
```

### Aplicación del Capítulo 4: Análisis Estadístico de Simulación

Implementamos la metodología del Capítulo 4 para validar la calidad de nuestros estimadores:

```python
def statistical_validation_chapter4(df_results, target_std_dev=0.5):
    """
    Implementa algoritmo del Capítulo 4 para evaluar calidad de estimadores.
    
    Entradas:
    - df_results: DataFrame con resultados de simulación
    - target_std_dev: d (desviación estándar objetivo del estimador)
    """
    
    # ESTIMADOR: Población final como variable de interés θ
    population_values = df_results['population'].values
    
    # Media de la muestra (estimador insesgado)
    X_bar = np.mean(population_values)
    
    # Varianza de la muestra (estimador insesgado de σ²)
    n = len(population_values)
    S_squared = np.sum((population_values - X_bar)**2) / (n - 1)
    S = np.sqrt(S_squared)
    
    # Desviación estándar del estimador (Capítulo 4, Prop. 4.1.2)
    std_dev_estimator = S / np.sqrt(n)
    
    # Validación: ¿Se cumple criterio de parada?
    print("════════════════════════════════════════════")
    print("VALIDACIÓN ESTADÍSTICA (Capítulo 4)")
    print("════════════════════════════════════════════")
    print(f"Estimador (media): {X_bar:.2f}")
    print(f"Varianza muestra (S²): {S_squared:.2f}")
    print(f"Desv. Est. muestra (S): {S:.2f}")
    print(f"Desv. Est. estimador (S/√n): {std_dev_estimator:.4f}")
    print(f"Umbral deseado (d): {target_std_dev}")
    print(f"Criterio cumplido: {std_dev_estimator < target_std_dev} ✓" if std_dev_estimator < target_std_dev else f"Criterio NO cumplido: {std_dev_estimator >= target_std_dev} ✗")
    
    # Intervalo de confianza aprox. 95% (z ≈ 1.96 para muestras grandes)
    z_95 = 1.96
    ci_lower = X_bar - z_95 * std_dev_estimator
    ci_upper = X_bar + z_95 * std_dev_estimator
    
    print(f"\nIntervalo de confianza 95%: [{ci_lower:.2f}, {ci_upper:.2f}]")
    
    # Si n < 30, debería usarse distribución t
    if n < 30:
        print(f"⚠ Nota: n={n} < 30, considerar test t de Student en vez de Normal")
    
    return {
        'mean': X_bar,
        'variance': S_squared,
        'std_dev': S,
        'estimator_std_dev': std_dev_estimator,
        'ci_95': (ci_lower, ci_upper),
        'criteria_met': std_dev_estimator < target_std_dev
    }
```

**Aplicación al Problema:**
- Se ejecuta Julia **once** generando 100 años de simulación
- Python lee el CSV de resultados anuales (n=100 registros anuales)
- Calcula X̄ (media poblacional anual), S² (varianza), S (desv. est.)
- Valida si S/√100 < umbral; si no, documentar que más corridas mejorarían precisión
- Genera intervalos de confianza para tasas vitales

### Validación de Consistencia Julia ↔ Python

```python
def validate_data_integrity(df):
    """Verifica que datos de Julia sean coherentes."""
    
    # Test 1: Población no debe decrecer sin justificación
    pop_changes = df['population'].diff()
    max_decrease = -pop_changes.min()
    max_deaths_year = df['deaths'].max()
    assert max_decrease <= max_deaths_year * 1.1, "Inconsistencia: población cae más que muertes"
    
    # Test 2: Nacimientos + muertes deben explicar cambios
    for idx in df.index[1:]:
        expected_pop = df.loc[idx-1, 'population'] + \
                      df.loc[idx, 'births'] - df.loc[idx, 'deaths']
        actual_pop = df.loc[idx, 'population']
        assert abs(expected_pop - actual_pop) < 5, f"Row {idx}: inconsistencia"
    
    print("✓ Validación de integridad: CORRECTA")
```

## Cronograma de Desarrollo Estimado

| Fase | Componente | Duración | Hito |
|------|-----------|----------|------|
| **Paso 1** | Diseño arquitectura | 1-2 h | Interfaz CSV definida |
| **Paso 2** | Arch. Julia: structs, tipos | 2-3 h | Infraestructura Julia lista |
| **Paso 3** | Motor DES + eventos | 5-6 h | Simulación 100 años funcional |
| **Paso 4** | Gen. variables aleatorias | 2-3 h | Todas distrib. probadas |
| **Paso 5** | Análisis Python | 4-5 h | Gráficos y métricas |
| **Paso 6** | Documentación | 4 - 5 h | Informe y README.md |
| **Total** | Completo | **~20-25 h** | Proyecto listo para entrega |

---

## Estructura de Archivos en Repositorio GitHub

```
proyecto-eventos-discretos/
│
├── README.md                          (descripción general)
├── requirements.txt                   (Python: pandas, numpy, scipy, matplotlib, reportlab)
├── Project.toml                       (Julia: paketes necesarios)
│
├── src/                               (MÓDULOS JULIA)
│   ├── SimuladorPoblacion.jl         (main module)
│   ├── random_generator.jl
│   ├── person.jl
│   ├── probability_tables.jl         (todas las tablas)
│   ├── event_engine.jl
│   ├── population.jl
│   └── simulator.jl
│
├── julia/                             (PUNTO DE ENTRADA JULIA)
│   └── run_simulation.jl             (script que ejecuta simulación)
│
├── python/                            (MÓDULOS PYTHON)
│   ├── data_loader.py
│   ├── metrics.py
│   ├── visualization.py
│   └── main_analysis.py              (orquestador principal)
│
├── data/                              (INTERFAZ CSV)
│   ├── results.csv                   (generado por Julia)
│   ├── population_age.csv            (generado por Julia)
│   └── timeline.csv                  (opcional, detallado)
│
├── output/                            (RESULTADOS FINALES)
│   ├── population_trend.png
│   ├── vital_rates.png
│   └── pyramid.png
│
├── test/                              (PRUEBAS)
│   ├── test_random_generator.jl
│   ├── test_event_engine.jl
│   ├── test_data_consistency.py
│   └── test_metrics.py
│
└── docs/                              (DOCUMENTACIÓN)
    ├── MODELO_CONCEPTUAL.md
    ├── ESPECIFICACION_TECNICA.md
    └── GUIA_INSTALACION.md
```

---

## Flujo de Ejecución Completo

```
┌─ USUARIO INICIA ──────────────────────────────────────┐
│                                                        │
│  $ julia julia/run_simulation.jl                       │
│                                                        │
│  ┌──────────────────────────────────────────────────┐ │
│  │ Julia inicia simulación...                       │ │
│  │ • Carga tablas de probabilidades                │ │
│  │ • Inicializa población (500H + 500M edades~U)  │ │
│  │ • Ejecuta loop de eventos 100 años             │ │
│  │ • Exporta: results.csv, population_age.csv     │ │
│  │ (tiempo estimado: 5-30 segundos)               │ │
│  │                                                 │ │
│  │ ✓ Simulación completada                        │ │
│  └──────────────────────────────────────────────────┘ │
│                                               ↓        │
│  $ python python/main_analysis.py                      │
│                                                        │
│  ┌──────────────────────────────────────────────────┐ │
│  │ Python carga y analiza...                        │ │
│  │ • Lee results.csv con pandas                    │ │
│  │ • Valida integridad de datos                    │ │
│  │ • Calcula 8+ métricas demográficas             │ │
│  │ • Genera 4 figuras principales                 │ │
│  │ • Sintetiza INFORME.pdf                        │ │
│  │ (tiempo estimado: 10-20 segundos)              │ │
│  │                                                 │ │
│  │ ✓ Análisis completado                          │ │
│  └──────────────────────────────────────────────────┘ │
│                                               ↓        │
│  ✓ INFORME.pdf listo en output/INFORME.pdf          │
│                                                        │
└────────────────────────────────────────────────────────┘
```

---

## Aspectos Clave a Destacar en Informe Técnico

**Arquitectura modular híbrida:** Julia implementa el motor de simulación DES aprovechando su rendimiento en operaciones intensivas, mientras Python ejecuta análisis estadístico y visualización mediante el ecosistema científico maduro. La separación mediante interfaces CSV garantiza independencia entre componentes y reproducibilidad.

**Metodología DES:** Se aplica simulación basada en eventos (no ecuaciones diferenciales) por: (1) naturaleza estocástica intrínseca del problema, (2) heterogeneidad poblacional (edad, sexo, estado civil), (3) causalidad explícita entre eventos vitales.

**Validación:** Generadores de variables aleatorias validados mediante tests de bondad de ajuste (Cap. 2). Consistencia demográfica: cambios anuales explicables por (nacimientos - muertes), error <1%. Análisis estadístico conforme a Cap. 4 con estimadores insesgados e intervalos de confianza.

**Resultados:** Pirámide poblacional, tasas vitales (natalidad, mortalidad, nupcialidad), razón de sexos, análisis de sensibilidad paramétrica.
