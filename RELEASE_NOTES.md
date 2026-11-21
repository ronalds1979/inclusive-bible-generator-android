# Release Notes — v1.1.0 (6)

Changes since **v1.0.2 (4)**.

---

## Google Play Console ("What's new" — ≤ 500 chars per language)

Copy and paste directly into Google Play Console → **Closed testing** → **Create new release** → **Release notes**:

```xml
<en-US>
• Major WCAG 2.1/2.2 AA, EN 301 549 & EAA accessibility upgrade
• Respects OS High Contrast, Reduced Motion & 200% text scaling
• New Letter Spacing, TTS Speech Rate & persistent Stop Audio bar
• Keyboard (Arrows/Home) & TalkBack actions to move verse text
• Unique Voice Access labels, 48dp targets & size-aware contrast
• Improved Search Topic clear button & screen-reader alerts
• Smoother color/font drags, faster scorecard & safer image checks
</en-US>
<es-ES>
• Mejora de accesibilidad WCAG 2.1/2.2 AA, EN 301 549 y EAA
• Respeta Alto Contraste, Movimiento Reducido y texto al 200%
• Nuevo Espaciado de Letras, Velocidad de Voz y barra Detener Audio
• Teclado (Flechas/Inicio) y TalkBack para mover el texto
• Etiquetas únicas Voice Access, controles de 48dp y contraste WCAG
• Mejoras en Buscar Tema y anuncios para lectores de pantalla
• Edición más fluida y validación de imágenes reforzada
</es-ES>
<pt-BR>
• Melhoria de acessibilidade WCAG 2.1/2.2 AA, EN 301 549 e EAA
• Respeita Alto Contraste, Movimento Reduzido e fonte em 200%
• Novo Espaçamento de Letras, Velocidade da Fala e barra Parar Áudio
• Teclado (Setas/Home) e TalkBack para mover o texto
• Rótulos únicos Voice Access, alvos de 48dp e contraste WCAG
• Melhorias na Busca por Tema e anúncios para leitores de tela
• Edição mais fluida e validação de imagens reforçada
</pt-BR>
```

---

## Detailed Release Notes (Full Changelog since v1.0.2 (4))

### 1. English (`en-US`)

**Accessibility (WCAG 2.1 / 2.2 AA, EN 301 549 & European Accessibility Act)**
- **Automatic OS Preferences:** Automatically honors system High Contrast mode, Dark/Light themes, 200% system font scaling, and Reduced Motion settings.
- **New Letter Spacing (Tracking) Control:** Adjust verse letter spacing with `48×48dp` `-`/`+` steppers and a quick Reset button.
- **Audio & Narration Improvements:** Added an adjustable **Speech Rate** control for Text-to-Speech (TTS) previews and a persistent **Stop Audio** banner visible across all tabs.
- **Drag-Free Preview Repositioning:** Move verse text vertically using physical keyboard shortcuts (`ArrowUp`, `ArrowDown`, `Home`) or custom TalkBack actions—no dragging required.
- **Voice Access, Switch Access & Touch Targets:** Added unique, unambiguous Voice Access labels/tooltips on every action, enforced `48×48dp` minimum touch targets on dense inputs, and verified overflow-free reflow at 200% text scale and compact landscape layouts.
- **Size-Aware WCAG Contrast & Real-Pixel Sampling:** Contrast evaluation now distinguishes between Large text (`3:1` minimum) and Normal text (`4.5:1` minimum) using real-pixel RGB band sampling.
- **Localized System Semantics & Legal Links:** Added `flutter_localizations` support for Material semantics in English, Spanish, and Portuguese, plus **Accessibility Statement** and **Privacy Policy** links in the **About & Credits** dialog.

**Search & UX**
- **Search Topic Dialog Polish:** Added a 1-tap **Clear** button, disabled the Search button for queries under 2 characters, and added live-region screen-reader announcements when no results are found.

**Performance & Security**
- **Smoother Editing:** Memoized verse preview font-size fitting for lag-free color picker and slider drags, and optimized Inclusivity Scorecard contrast calculations.
- **Hardened Image Contrast Sampling:** Enforced a 20 MB file-size limit and PNG/JPEG/WebP header validation before decoding custom background images.

---

### 2. Español (`es-ES` / `es-419`)

**Accesibilidad (WCAG 2.1 / 2.2 AA, EN 301 549 y Ley Europea de Accesibilidad)**
- **Preferencias automáticas del sistema:** Respeta automáticamente el Alto Contraste, el tema Claro/Oscuro, la escala de fuente al 200% y la opción de Movimiento Reducido del dispositivo.
- **Nuevo control de Espaciado de Letras:** Ajusta el espaciado entre letras con botones `-`/`+` de `48×48dp` y un botón rápido de restablecimiento.
- **Mejoras de Audio y Narración:** Nuevo control de **Velocidad de Voz** para la narración (TTS) y una barra persistente de **Detener Audio** visible desde cualquier pestaña.
- **Posicionamiento sin arrastrar:** Mueve el texto del versículo con teclado físico (`Flecha Arriba`, `Flecha Abajo`, `Inicio`) o mediante acciones personalizadas de TalkBack.
- **Voice Access, Switch Access y Objetivos Táctiles:** Etiquetas y tooltips únicos para Voice Access en cada acción, objetivos táctiles mínimos de `48×48dp` en controles compactos y reflujo sin recortes al 200% de texto y en pantallas horizontales compactas.
- **Contraste WCAG sensible al tamaño y muestreo real:** La evaluación de contraste ahora distingue entre texto grande (`3:1` mínimo) y texto normal (`4.5:1` mínimo) con muestreo RGB real de la imagen.
- **Semántica localizada y enlaces legales:** Soporte de `flutter_localizations` para componentes Material en español, inglés y portugués, y enlaces directos a la **Declaración de Accesibilidad** y **Política de Privacidad** en **Acerca de y Créditos**.

**Búsqueda y Experiencia de Usuario**
- **Mejoras en Buscar Tema:** Nuevo botón de **Limpiar**, botón de búsqueda deshabilitado con menos de 2 caracteres y anuncios en vivo para lectores de pantalla cuando no hay resultados.

**Rendimiento y Seguridad**
- **Edición más fluida:** Memorización del cálculo de ajuste de fuente en la vista previa para selecciones de color y deslizadores sin tirones, y optimización del panel de Preparación Inclusiva.
- **Muestreo de imágenes reforzado:** Límite de 20 MB y validación de encabezados PNG/JPEG/WebP antes de decodificar imágenes de fondo personalizadas.

---

### 3. Português (Brasil) (`pt-BR`)

**Acessibilidade (WCAG 2.1 / 2.2 AA, EN 301 549 e Lei Europeia de Acessibilidade)**
- **Preferências automáticas do sistema:** Respeita automaticamente o Alto Contraste, o tema Claro/Escuro, a escala de fonte em 200% e a redução de animações do sistema.
- **Novo controle de Espaçamento entre Letras:** Ajuste o espaçamento das letras com botões `-`/`+` de `48×48dp` e botão rápido para redefinir.
- **Melhorias de Áudio e Narração:** Novo controle de **Velocidade da Fala** para narração (TTS) e uma barra persistente **Parar Áudio** acessível em todas as abas.
- **Reposicionamento sem arrastar:** Mova o texto do versículo usando teclado físico (`Seta para cima`, `Seta para baixo`, `Home`) ou ações personalizadas do TalkBack.
- **Voice Access, Switch Access e Alvos de Toque:** Rótulos e dicas únicas para Voice Access em todas as ações, alvos de toque mínimos de `48×48dp` em controles compactos e layout sem cortes em escala de 200% e modo paisagem compacto.
- **Contraste WCAG por tamanho de texto e amostragem real:** A verificação de contraste agora diferencia texto grande (`3:1` mínimo) de texto normal (`4.5:1` mínimo) usando amostragem real de pixels RGB.
- **Semântica localizada e links legais:** Suporte a `flutter_localizations` em português, inglês e espanhol, além de links para a **Declaração de Acessibilidade** e **Política de Privacidade** em **Sobre e Créditos**.

**Busca e Experiência de Uso**
- **Melhorias na Busca por Tema:** Novo botão **Limpar**, botão de busca desativado para consultas com menos de 2 caracteres e anúncios em tempo real para leitores de tela quando não há resultados.

**Desempenho e Segurança**
- **Edição mais fluida:** Cache do cálculo de ajuste de fonte na prévia para seleção de cores e controles deslizantes mais suaves, e otimização do painel de Prontidão Inclusiva.
- **Validação de imagens reforçada:** Limite de 20 MB e validação de cabeçalhos PNG/JPEG/WebP antes de decodificar imagens de fundo personalizadas.
