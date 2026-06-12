# PERIS FPS Optimizer 2.2.0

Painel de otimização para Windows com monitoramento de hardware em tempo real, 25 módulos de otimização e interface dark theme com neon roxo.

## Download

Baixe a versão mais recente em [Releases](https://github.com/PERIS-FPS-OPTIMIZER/peris-fps-optimizer/releases)

## Requisitos

- Windows 10/11 (64-bit)
- Executar como Administrador

## Funcionalidades

### Aba Sistema
- **Informações do PC**: CPU, GPU, RAM, Placa-mãe, BIOS, Monitores, Discos com barras de uso
- **Status em tempo real**: CPU, GPU, RAM, Temperatura, Rede (atualização a cada 5 segundos)

### Aba Otimização (25 módulos)

| Módulo | Descrição |
|--------|-----------|
| Criar Ponto de Restauração | Cria restore point antes de qualquer alteração |
| Telemetria | Desativa rastreamento e coleta de dados do Windows |
| Serviços para Apostado | Ativa serviços necessários para jogos online (PcaSvc, DiagTrack, SysMain, Sysmon, Firewall, USN Journal, TPM, Secure Boot) |
| Bloatware | Remove Microsoft Edge, OneDrive, apps indesejados e bloatware |
| Energia | Ativa plano de Alta Performance e desativa hibernação |
| Interface | Desativa efeitos visuais para ganho de performance |
| Menu Iniciar | Remove delay do menu iniciar |
| Timer 0.5ms | Ativa timer de alta precisão (NtSetTimerResolution) |
| Input Lag | Otimiza prioridade de GPU e desativa aceleração do mouse |
| Ping | Otimiza TCP/IP para menor latência (Nagle off, TCPAck) |
| Limpar Cache | Limpa temp, drivers suspeitos, crash dumps, prefetch, .NET, DNS, lixeira |
| GPU | Otimiza configurações da placa de vídeo NVIDIA |
| Memória | Otimiza gerenciamento de RAM |
| Disco I/O | Otimiza performance do disco (NTFS, LastAccess) |
| Game Mode | Ativa Game Mode do Windows |
| DNS | Configura DNS Cloudflare + Google para menor latência |
| Tarefas | Desativa tarefas agendadas pesadas |
| Spooler | Desativa serviço de impressão |
| Windows Update | Controla atualizações do Windows |
| Boot | Acelera inicialização (timeout 0, sem boot log) |
| Benchmark | Mede uso atual da CPU |
| Integridade | Verifica integridade do sistema (SFC + DISM) |
| Desativar Defender | Desativa completamente o Windows Defender (com aviso) |
| Otimização Agressiva | Desativa serviços pesados para máximo desempenho (com aviso) |

### Aba Ajustes
- **Ajustes do Windows**: Opções visuais, rede, privacidade, energia
- **Atalhos**: Links úteis para ferramentas do sistema

### Aba Relatório
- **Exportar**: Salva relatório completo do sistema em arquivo

## Funcionalidades Extras

- **Reiniciar PC**: Botão aparece após módulos que precisam de restart
- **Usar Todos os Módulos**: Aplica todos de uma vez (exceto Otimização Agressiva e Serviços para Apostado)
- **Alertas de Confirmação**: Avisa antes de módulos destrutivos
- **Verde ✓**: Módulos completados ficam marcados com verde
- **Transições**: Animações suaves entre abas

## Tecnologias

- Electron 28
- React 18 + TypeScript
- Tailwind CSS 3
- PowerShell (scripts de otimização)
- Vite (build)

## Build

```powershell
npm install
npx vite build
npx electron-builder --win
```

## Aviso Legal

Este software é fornecido "como está", sem garantias de qualquer tipo. O uso é por sua conta e risco. Sempre crie um ponto de restauração antes de aplicar otimizações.
