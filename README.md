# PERIS FPS Optimizer 2.2.0

Painel de otimização para Windows com monitoramento de hardware em tempo real, 23 módulos de otimização e interface dark theme com neon roxo.

![Painel PERIS FPS Optimizer](screenshot.png)

## Download

Baixe a versão mais recente em [Releases](https://github.com/desenvolvedor171/Peris-optimizer/releases)

## Requisitos

- Windows 10/11 (64-bit)
- Executar como Administrador

## Interface

### Aba Sistema
- **Informações do PC**: CPU, GPU, RAM, Placa-mãe, BIOS, Monitores, Discos com barras de uso
- **Status em tempo real**: CPU, GPU, RAM, Temperatura, Rede (atualização a cada 5 segundos)

### Aba Otimização (23 módulos)

O painel exibe todos os módulos em grid de 3 colunas com ícones SVG, nome, descrição e status visual.

| Módulo | Descrição |
|--------|-----------|
| Ponto de Restauração | Cria um restore point do sistema antes de aplicar qualquer alteração |
| Telemetria | Desativa rastreamento Microsoft, Cortana, Widgets, Copilot e coleta de dados |
| Bloatware | Remove Microsoft Edge, OneDrive, Teams e apps indesejados do Windows |
| Plano de Energia | Ativa plano de alta performance e desativa hibernação |
| Interface | Desativa animações, transparência, snapping e atalhos visuais do Windows |
| Menu Iniciar | Remove delay ao abrir menus e o menu iniciar |
| Timer 0.5ms | Ativa timer de alta precisão global e desativa HPET |
| Input Lag | Otimiza prontidão de GPU, mouse e teclado para menor input lag |
| Rede / TCP | Otimiza TCP/IP, reseta rede, configura DoH e desativa throttling |
| Limpar Cache | Limpa temp, prefetch, DNS, crash dumps, Windows Update cache, lixeira |
| GPU | Ativa modo de performance máxima na placa de vídeo |
| Memória RAM | Otimiza memória, limpa standby e desativa Memory Compression |
| Disco I/O | Otimiza TRIM, NTFS, verifica SMART e desativa indexação |
| Game Mode | Ativa modo jogo e configura Game Bar do Windows |
| DNS Rápido | Configura DNS Cloudflare + Google para menor latência |
| Tarefas Agendadas | Desativa tarefas pesadas do Windows que consomem recursos |
| Spooler | Desativa serviço de impressão (libera recursos) |
| Windows Update | Para e desativa atualizações automáticas do Windows |
| Boot Rápido | Acelera inicialização desativando timeout e log de boot |
| Integridade | Executa SFC + DISM para verificar e corrigir arquivos do sistema |
| Desativar Defender | Desativa Windows Defender completo incluindo Tamper Protection |
| Serviços para Apostado | Ativa serviços para não tomar W.O (KellerServices) |
| Otimização Agressiva | Desativa serviços pesados para máximo desempenho |

### Botões de Controle

- **Usar todos os módulos**: Aplica todos os módulos de uma vez (cria restore point antes, exclui módulos de risco)
- **Desfazer tudo**: Reverte todas as alterações aplicadas usando o script peris-revert.ps1
- **Reiniciar PC**: Botão aparece após módulos que precisam de restart (apenas 4 módulos)

### Funcionalidades Extras

- **Checkmark verde**: Módulos completados ficam marcados com ícone verde ✓
- **Log em tempo real**: Painel lateral mostra outputs dos módulos com cores por tipo ([OK] verde, [ERR] vermelho, [PROG] ciano pulsante)
- **Dot de status**: Vermelho com brilho quando ocioso, verde com brilho quando executando
- **Revert individual**: Clique direito em módulo completado oferece opção de reverter apenas esse módulo
- **Alerta de confirmação**: Avisa antes de re-executar módulo já aplicado
- **Janela 1400x900**: Painel frameless com cantos arredondados (12px)
- **WINDOWS badge**: Exibe versão do Windows ao lado do botão minimizar
- **Transições suaves**: Animações fade+slide entre abas (150ms)
- **Ícones SVG**: Todos os módulos possuem ícones vetoriais personalizados

## Tecnologias

- Electron 28
- React 18 + TypeScript
- Tailwind CSS 3
- PowerShell (scripts de otimização)
- Vite (build)

## Aviso Legal

Este software é fornecido para otimizações limpas em seu dispositivo e não causará nenhum dano. Mas o recomendado é que você use a opção "Ponto de Restauração" disponível no próprio painel antes de aplicar qualquer um dos módulos de otimizações.
