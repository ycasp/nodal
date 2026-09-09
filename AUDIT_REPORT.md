# Nodal — Auditoria UX/UI Mobile & Análise Competitiva

## Data: 30 Março 2026

---

# PARTE 1: AUDITORIA MOBILE — STOREFRONT

## Rating Global: BOM (com 3 issues críticos)

### O que está bem feito
- Viewport meta tag correto
- Navbar responsiva com hamburger menu
- Homepage carousels com touch scrolling nativo
- Carrinho tem vista mobile dedicada (cards em vez de tabela) — **EXCELENTE**
- Checkout com formulários que empilham em mobile
- Offcanvas para filtros de produtos em mobile — **EXCELENTE**
- Sticky footer no carrinho para CTA de checkout
- Touch targets nos CTAs principais >= 44px (WCAG compliant)
- Product grid adapta de 3 colunas → 2 em mobile

### Issues CRÍTICOS

| # | Problema | Ficheiro | Impacto |
|---|----------|----------|---------|
| S1 | **Página de detalhe produto — imagem min-height: 400px** demasiado alta para mobile | `products/show.html.erb:46` | Imagem ocupa quase todo o ecrã, user tem de fazer scroll para ver preço |
| S2 | **Histórico de encomendas — tabela sem vista mobile** | `orders/index.html.erb:15-58` | 6 colunas sem `table-responsive`, texto ilegível em mobile |
| S3 | **Info grid no produto — col-4 demasiado estreito** | `products/show.html.erb:219` | 3 colunas a 33% em mobile = texto cortado |

### Issues de PRIORIDADE ALTA

| # | Problema | Ficheiro | Fix |
|---|----------|----------|-----|
| S4 | Página conta — sem padding mobile | `accounts/show.html.erb:1` | Mudar `px-md-5` para `px-3 px-md-5` |
| S5 | Encomendas — 3 botões de ação overflow em mobile | `orders/index.html.erb:43-54` | Stack vertical ou icon-only |
| S6 | Imagens sem srcset/lazy loading | Todos os `image_tag` | Mobile carrega imagens desktop-size |

### Métricas de Cliques (Mobile)

| Ação | Taps necessários | Avaliação |
|------|-----------------|-----------|
| Navegar para produtos | 1 | BOM |
| Pesquisar + filtrar | 3 | BOM |
| Adicionar ao carrinho | 2-3 | ACEITÁVEL |
| Checkout completo | 3+ form | BOM |
| Repetir encomenda | 2 | BOM |

---

# PARTE 2: AUDITORIA MOBILE — BACK OFFICE

## Rating Global: NECESSITA MELHORIAS (com 5 issues críticos)

### O que está bem feito
- Dashboard KPI cards responsivos (4 → 2 → 1 coluna)
- Tabelas usam `.table-responsive`
- Forms empilham em coluna única em mobile
- Labels acima dos campos (padrão mobile-friendly)
- Botões de voltar consistentes
- Categorias com estrutura de árvore simples

### Issues CRÍTICOS

| # | Problema | Localização | Impacto |
|---|----------|-------------|---------|
| B1 | **Touch targets demasiado pequenos** (24-32px) em botões de ação | Listas de produtos, encomendas, clientes, variantes | Impossível tocar com precisão em mobile. WCAG exige 44px mínimo |
| B2 | **Sidebar mobile sem overlay/backdrop** | `_bo_sidebar.scss:489-519` | User não consegue fechar sidebar facilmente |
| B3 | **Tabelas sem indicador visual de scroll horizontal** | Todas as listas | User não sabe que pode fazer scroll |
| B4 | **Modals `.modal-lg` overflow em phones** | `customer_categories/edit.html.erb:100` | Modal maior que o ecrã |
| B5 | **Botão eliminar imagem é 24x24px** | `products/edit.html.erb:155` | Impossível tocar com precisão |

### Issues de PRIORIDADE ALTA

| # | Problema | Fix recomendado |
|---|----------|----------------|
| B6 | `.form-control-sm` usado em muitos sítios (30px) | Aumentar para 44px em mobile |
| B7 | Settings é um formulário enorme sem secções | Usar accordion ou wizard em mobile |
| B8 | Rows clicáveis usam `onclick` (não acessível) | Usar `<a>` semânticos |
| B9 | Import flow não é touch-friendly | Tap-to-browse como padrão |
| B10 | Navbar BO com dropdown que pode overflow | Adicionar max-height com scroll |

### Recomendações de Alto Impacto para o BO

1. **Bottom navigation bar para mobile** — sidebar é má UX em phones
2. **Card-based layout** nas listas em vez de tabelas para mobile
3. **Sticky save button** no fundo do ecrã para formulários em mobile
4. **Scroll shadows** nas tabelas para indicar que há mais conteúdo
5. **Swipe gestures** para fechar sidebar

---

# PARTE 3: ANÁLISE COMPETITIVA

## Funcionalidades Nodal vs Mercado

### Onde Nodal é FORTE (diferenciadores)

| Funcionalidade | Maturidade | Notas |
|---------------|-----------|-------|
| **Sistema de Descontos** | 95% | 4 tipos + promo codes + stacking rules — mais completo que maioria dos concorrentes |
| **Multi-tenancy** | 90% | Cada org isolada com branding, currency, locale |
| **Gestão de Produtos** | 90% | Variantes, atributos, categorias hierárquicas, fotos múltiplas |
| **Dashboard Analytics** | 80% | KPIs, trends, discount impact, retention — sólido |
| **Integração ERP** | 75% | 2 adapters (Firebird, Custom API), sync bidirecional |
| **Homepage Customizável** | 70% | Banners, featured products/categories — acabado de implementar |

### Onde Nodal é FRACO (gaps críticos vs competição)

| Funcionalidade em falta | Shopify B2B | OroCommerce | Faire | Prioridade |
|------------------------|-------------|-------------|-------|------------|
| **Workflows de aprovação / PO** | ✅ | ✅ | ✅ | ALTA |
| **Limites de crédito / payment terms** | ✅ | ✅ | ✅ | ALTA |
| **Request for Quote (RFQ)** | ✅ | ✅ | ❌ | MÉDIA |
| **Faturas/PDF** | ✅ | ✅ | ✅ | ALTA |
| **Tracking de envios** | ✅ | ✅ | ✅ | ALTA |
| **Roles granulares** | ✅ | ✅ | ❌ | MÉDIA |
| **API REST/GraphQL** | ✅ | ✅ | ✅ | MÉDIA |
| **Export CSV/Excel** | ✅ | ✅ | ✅ | ALTA |
| **Stock multi-warehouse** | ❌ | ✅ | ❌ | BAIXA |
| **Bundles/Kits** | ✅ | ✅ | ❌ | BAIXA |
| **CMS / Páginas custom** | ✅ | ✅ | ❌ | MÉDIA |
| **Email templates customizáveis** | ✅ | ✅ | ✅ | MÉDIA |
| **Reserva de stock no checkout** | ✅ | ✅ | ✅ | ALTA |
| **Low-stock alerts** | ✅ | ✅ | ❌ | MÉDIA |

### Mapa de Maturidade por Área

```
Descontos/Pricing    ████████████████████░ 95%
Produtos             ██████████████████░░░ 90%
Multi-tenancy        ██████████████████░░░ 90%
Encomendas           █████████████████░░░░ 85%
Clientes             ████████████████░░░░░ 80%
Analytics            ████████████████░░░░░ 80%
Email/Comunicação    ███████████████░░░░░░ 75%
Integração ERP       ███████████████░░░░░░ 75%
Shopping Lists       ███████████████░░░░░░ 75%
Customização Loja    ██████████████░░░░░░░ 70%
Pesquisa/Filtros     ██████████████░░░░░░░ 70%
Roles/Permissões     █████████████░░░░░░░░ 65%
Stock Management     ████████████░░░░░░░░░ 60%
Import/Export        ██████████░░░░░░░░░░░ 50%
```

---

# PARTE 4: ROADMAP DE PRIORIDADES

## Prioridade 1 — Mobile UX (impacto imediato no user)

### Storefront
1. Fix image height no produto (`min-height` responsivo)
2. Vista mobile para histórico de encomendas (cards)
3. Fix info grid (`col-6 col-md-4`)
4. Lazy loading de imagens
5. Padding da conta

### Back Office
1. Touch targets mínimo 44px em todos os botões de ação
2. Sidebar mobile com overlay + swipe-to-close
3. Scroll shadows nas tabelas
4. Sticky save button em formulários mobile
5. Fix modal sizing para phones

## Prioridade 2 — Funcionalidades críticas em falta
1. Export de dados (encomendas, clientes, produtos) para CSV/Excel
2. Faturas/PDF para encomendas
3. Reserva de stock durante checkout
4. Low-stock alerts
5. Tracking de envios (mesmo que básico)

## Prioridade 3 — Diferenciação competitiva
1. Request for Quote (RFQ) flow
2. Payment terms / crédito
3. Roles granulares com permissões
4. Email templates customizáveis
5. API REST para integrações

---

# PARTE 5: DISPOSITIVOS DE TESTE RECOMENDADOS

| Dispositivo | Largura | Prioridade |
|------------|---------|------------|
| iPhone SE | 375px | ALTA (menor iPhone comum) |
| iPhone 14 Pro | 390px | ALTA |
| Pixel 6a | 412px | MÉDIA |
| iPad | 768px | ALTA (tablet principal para BO) |
| iPad landscape | 1024px | MÉDIA |

---

*Relatório gerado por auditoria automática ao código-fonte. Recomenda-se validação manual em dispositivos reais.*
