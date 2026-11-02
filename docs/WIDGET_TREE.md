# Widget Tree — PortoTrack

Árvores simplificadas dos principais widgets (apenas os nós relevantes para
estrutura, estado e navegação). As imagens renderizadas estão em `docs/img/`.

## 1. Raiz da aplicação e gerenciamento de estado

```mermaid
graph TD
  main["main()"] --> App["PortoTrackApp"]
  App --> MP["MultiProvider"]
  MP --> P1["Provider&lt;PortoRepository&gt;<br/>(Supabase ou Demo)"]
  MP --> P2["Provider&lt;BrasilApiService&gt;"]
  MP --> P3["ChangeNotifierProvider&lt;AuthController&gt;"]
  MP --> P4["ChangeNotifierProvider&lt;CargasController&gt;"]
  MP --> P5["ChangeNotifierProvider&lt;UsuariosController&gt;"]
  MP --> P6["ChangeNotifierProvider&lt;NavegacaoController&gt;"]
  MP --> MA["MaterialApp (tema, pt-BR)"]
  MA --> Gate["AuthGate (watch AuthController)"]
  Gate -->|não autenticado| Login["LoginPage"]
  Gate -->|autenticado| Shell["AppShell"]
  Login -->|push| Signup["SignupPage"]
```

## 2. AppShell — módulos filtrados por perfil

```mermaid
graph TD
  Shell["AppShell"] --> LB["LayoutBuilder"]
  LB -->|largura ≥ 900| Rail["Scaffold › Row › NavigationRail + IndexedStack"]
  LB -->|celular| Bar["Scaffold › IndexedStack + NavigationBar"]
  Rail --> IS["IndexedStack"]
  Bar --> IS
  IS --> G["CargasGridPage (todos)"]
  IS --> D["DashboardPage (Operador+)"]
  IS --> Doc["DocumentosPage (todos)"]
  IS --> U["UsuariosPage (Admin)"]
  IS --> Pf["PerfilPage (todos)"]
```

## 3. Módulo principal — GRID de cargas

```mermaid
graph TD
  G["CargasGridPage (StatefulWidget)"] --> S["Scaffold"]
  S --> AB["AppBar › [Colunas, Atualizar, RoleBadge]"]
  S --> FAB["FloatingActionButton 'Nova carga' (Operador+)"]
  S --> RI["RefreshIndicator › ListView"]
  RI --> BF["_BarraFiltros"]
  BF --> TF["TextField (busca)"]
  BF --> FC["FilterChips (pendências + 6 status)"]
  RI --> PDT["PaginatedDataTable"]
  PDT --> DC["DataColumn × N (ColunaGrid permitidas ao perfil, ordenáveis)"]
  PDT --> SRC["_CargasDataSource (DataTableSource)"]
  SRC --> DR["DataRow por carga"]
  DR --> C1["StatusChip"]
  DR --> C2["PendenciasBadge (Tooltip)"]
  DR --> C3["DataCell editável ✎ (previsão, placa, motorista, posição)"]
  DR --> C4["Ações: registrar evento · enviar documento · detalhes"]
  RI --> LG["_LegendaGrid"]
```

## 4. Detalhe da carga

```mermaid
graph TD
  DP["CargaDetailPage"] --> S["Scaffold"]
  S --> AB["AppBar › [Editar (Operador+), Excluir (Admin), RoleBadge]"]
  S --> FAB["FAB 'Registrar evento'"]
  S --> LV["RefreshIndicator › ListView"]
  LV --> CS["_CabecalhoSituacao › _LinhaFluxo + InfoItems"]
  LV --> PE["SectionCard 'Pendências'"]
  LV --> IN["_Informacoes (campos filtrados por nível)"]
  LV --> DO["_Documentos › _DocumentoTile"]
  LV --> HI["_Historico (linha do tempo)"]
```

## 5. Registro de evento (bottom sheet)

```mermaid
graph TD
  ES["EventoFormSheet"] --> F["Form › Column"]
  F --> TC["ChoiceChips: Mudança de etapa · Movimentação · Ocorrência · Resolução"]
  F --> CT["Campos dinâmicos por tipo/etapa"]
  CT --> R["Recepcionado: placa, motorista, peso"]
  CT --> A["Armazenado/Movimentação: posição"]
  CT --> I["Em inspeção: órgão, motivo"]
  CT --> L["Liberado: _ChecklistLiberacao + nº documento"]
  F --> DH["DataHoraField (data e hora obrigatórias)"]
  F --> EB["ErrosBox (regras de negócio)"]
  F --> BT["FilledButton 'Registrar'"]
```

## 6. Dashboard e Documentos

```mermaid
graph TD
  DB["DashboardPage"] --> PG["PermissionGuard (Operador+)"]
  PG --> W1["Wrap › KpiCard × 6"]
  PG --> W2["Wrap › SectionCards"]
  W2 --> B1["BarrasHorizontais: cargas por etapa"]
  W2 --> B2["ColunasAgrupadas: gate in × gate out"]
  W2 --> B3["BarrasHorizontais: ocupação por bloco"]
  W2 --> B4["_CardPendencias"]
  W2 --> B5["Produtividade / Ocorrências (Supervisor+)"]
  W2 --> B6["_CardUsuarios (Admin)"]

  DOC["DocumentosPage"] --> SB["SegmentedButton: Enviados | Pendentes"]
  DOC --> L1["ListView › Cards de documentos (PopupMenu)"]
  DOC --> FAB2["FAB 'Enviar documento'"]
  FAB2 --> UP["UploadDocumentoSheet › Form (carga, tipo, chave NF-e, FilePicker)"]
```
