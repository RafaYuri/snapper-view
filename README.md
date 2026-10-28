# snapper-view 📸

> **Menu de serviço para o KDE Dolphin que permite visualizar, comparar (Diff) e restaurar versões anteriores de arquivos, diretórios e itens excluídos em snapshots do Btrfs gerenciados pelo Snapper.**

---

## 📋 Sumário

- [Visão Geral](#-visão-geral)
- [Funcionalidades](#-funcionalidades)
- [Requisitos](#-requisitos)
- [Estrutura do Projeto](#-estrutura-do-projeto)
- [Configuração de Permissões do Snapper](#-configuração-de-permissões-do-snapper)
  - [Configuração Automática (`setup-permissions.sh` ou via GUI)](#1-configuração-automática-script-setup-permissionssh-ou-via-gui)
  - [Configuração Manual](#2-configuração-manual)
- [Instalação](#-instalação)
  - [Instalação Rápida (Script)](#instalação-rápida-automática)
  - [Instalação Manual](#instalação-manual)
- [Como Usar](#-como-usar)
- [Comparação Visual (Diff) e Integração com Flathub](#-comparação-visual-diff-e-integração-com-flathub)
- [Desinstalação](#-desinstalação)
- [Solução de Problemas](#-solução-de-problemas)

---

## 🔍 Visão Geral

O **snapper-view** adiciona uma ação ao menu de contexto (clique com o botão direito) do **KDE Dolphin** chamada **"Ver versões nos Snapshots..."**. Ao clicar sobre qualquer arquivo ou diretório pertencente a um subvolume Btrfs monitorado pelo **Snapper**, um diálogo nativo (`kdialog`) detecta automaticamente o subvolume e lista os snapshots que contêm versões daquele item, indicando tamanho, tempo relativo e se o arquivo sofreu alterações em relação à versão atual.

A partir do snapshot escolhido, o usuário pode **comparar diferenças visualmente (Diff)**, **restaurar instantaneamente via Copy-on-Write (CoW)** (com opção de backup `.bak` ou cópia ao lado), **recuperar arquivos excluídos de uma pasta** ou **abrir o snapshot no Dolphin** (em janela simples ou modo dividido lado a lado).

---

## ✨ Funcionalidades

- 🗂️ **Integração nativa com KDE Dolphin** através de KIO Service Menus (com suporte aos idiomas Português, Inglês e Espanhol).
- 🧭 **Detecção automática de subvolume (Zero-Config)**: localiza automaticamente a pasta `.snapshots` subindo na árvore de diretórios ou consultando o Snapper, funcionando sem edições manuais tanto em sistemas atômicos (`/var/home` no Fedora Kinoite, Bazzite, Silverblue) quanto em distribuições tradicionais (`/home`, `/` no openSUSE, Arch, Debian/Ubuntu).
- 🏷️ **Metadados ricos e filtro de versões modificadas**:
  - Exibe ID do snapshot, data/hora convertida para o fuso horário local, tempo relativo (*"há 15 min"*, *"ontem"*, *"há 3 dias"*) e descrição.
  - Identifica automaticamente se o arquivo no snapshot é **`[Igual ao atual]`** ou **`[Modificado]`** (com base em `mtime` e tamanho), oferecendo um filtro rápido no topo da lista para exibir apenas versões que tiveram alterações.
- 🔍 **Comparação Visual (Diff) com suporte automático ao Flathub**:
  - Prioriza o **Kompare** (ferramenta oficial de Diff do KDE), além de suportar **KDiff3** e **Meld** (tanto pacotes nativos quanto Flatpaks).
  - Caso nenhuma ferramenta gráfica esteja instalada, oferece instalar automaticamente o `org.kde.kompare` via **Flathub** sob demanda ou exibe o diff unificado diretamente no `kdialog`.
- ♻️ **Restauração instantânea via Copy-on-Write (`cp --reflink=auto`)**:
  - **Restaurar sobrescrevendo**: permite criar opcionalmente um backup (`.bak-<timestamp>`) da versão atual antes de restaurar.
  - **Restaurar como cópia**: cria um arquivo/pasta `.snapshot-<ID>` ao lado do item original sem alterar a versão atual.
- 🗑️ **Recuperação de arquivos e pastas excluídos**:
  - Ao clicar com o botão direito em uma pasta, permite varrer todos os snapshots anteriores em busca de arquivos ou subpastas que foram deletados e restaurá-los com um clique.
- 🪟 **Abertura inteligente no Dolphin**:
  - Abre o diretório do snapshot ou seleciona o arquivo (`dolphin --select`).
  - Oferece **Modo Dividido (`dolphin --split`)**, exibindo a pasta atual e o snapshot lado a lado para facilitar o *drag-and-drop*.
- 🔐 **Diagnóstico e correção de permissões via interface gráfica**:
  - Se o usuário ainda não tiver permissão de leitura em `.snapshots`, o `snapper-view` avisa claramente e oferece aplicar `ALLOW_USERS` e `SYNC_ACL=yes` via `pkexec`.

---

## 📦 Requisitos

- **KDE Plasma & Dolphin** (gerenciador de arquivos)
- **kdialog** (diálogos gráficos nativos do KDE)
- **snapper** (gerenciador de snapshots Btrfs)
- **btrfs-progs** (utilitários do sistema de arquivos Btrfs)
- **flatpak** *(opcional, recomendado para instalação automática do Kompare via Flathub caso não haja ferramenta de diff nativa)*
- Subvolume formatado em **Btrfs** com snapshots ativos (ex.: `/var/home`, `/home` ou `/`)

---

## 📁 Estrutura do Projeto

| Arquivo | Destino de Instalação | Descrição |
| :--- | :--- | :--- |
| [`snapper-history.desktop`](snapper-history.desktop) | `~/.local/share/kio/servicemenus/` | Entrada do menu de contexto do KDE Dolphin |
| [`snapper-view`](snapper-view) | `~/.local/bin/` | Script principal de listagem, comparação (Diff) e restauração |
| [`setup-permissions.sh`](setup-permissions.sh) | *(utilitário)* | Script auxiliar de linha de comando para liberar ACLs no Snapper |
| [`install.sh`](install.sh) | *(utilitário)* | Instalador automático (arquivos, diff via Flathub e permissões) |
| [`uninstall.sh`](uninstall.sh) | *(utilitário)* | Desinstalador |
| [`SUGESTOES_MELHORIAS.md`](SUGESTOES_MELHORIAS.md) | *(documentação)* | Documento de arquitetura e evolução de UX/funcionalidades |

---

## 🔐 Configuração de Permissões do Snapper

Por padrão, a pasta `.snapshots` de um subvolume Btrfs possui permissão restrita (`0750` apenas para `root`). Para que o **snapper-view** funcione sem pedir senha de administrador a cada consulta, o Snapper deve conceder acesso de leitura ao usuário via ACL.

### 1. Configuração Automática (Script `setup-permissions.sh` ou via GUI)

Você pode configurar pelo terminal usando o script [`setup-permissions.sh`](setup-permissions.sh) (que também é oferecido durante o `./install.sh`) ou diretamente pela janela gráfica do `snapper-view` no primeiro uso via `pkexec`:

```bash
# Execução simples (detecta configuração e usuário automaticamente):
./setup-permissions.sh

# Especificando a configuração e o usuário (opcional):
./setup-permissions.sh snaphome rafael

# Simulação sem aplicar alterações:
./setup-permissions.sh --dry-run
```

---

### 2. Configuração Manual

1. Liste as configurações existentes do Snapper:
   ```bash
   snapper list-configs
   ```
2. Adicione seu usuário e sincronize as ACLs:
   ```bash
   sudo snapper -c <nome_da_configuração> set-config "ALLOW_USERS=$USER" "SYNC_ACL=yes"
   ```

---

## 🚀 Instalação

### Instalação Rápida (Automática)

Execute o script de instalação incluído:

```bash
chmod +x install.sh
./install.sh
```

O instalador irá:
1. Copiar `snapper-view` para `~/.local/bin/` e conceder permissão de execução (`chmod +x`).
2. Copiar `snapper-history.desktop` para `~/.local/share/kio/servicemenus/` e conceder permissão de execução (`chmod +x`, exigido pelo KDE Plasma/KIO para autorizar Service Menus).
3. Verificar se há uma ferramenta gráfica de Diff (`Kompare`, `KDiff3` ou `Meld`) e oferecer a instalação do **Kompare (`org.kde.kompare`)** via Flathub caso nenhuma esteja presente.
4. Oferecer a execução do assistente de permissões (`setup-permissions.sh`).

---

### Instalação Manual

1. Crie os diretórios de destino:
   ```bash
   mkdir -p ~/.local/bin ~/.local/share/kio/servicemenus
   ```
2. Copie o script executável e dê permissão de execução:
   ```bash
   cp snapper-view ~/.local/bin/
   chmod +x ~/.local/bin/snapper-view
   ```
3. Copie o arquivo do menu de serviço do Dolphin e dê permissão de execução:
   ```bash
   cp snapper-history.desktop ~/.local/share/kio/servicemenus/
   chmod +x ~/.local/share/kio/servicemenus/snapper-history.desktop
   ```
4. Configure as permissões do Snapper:
   ```bash
   ./setup-permissions.sh
   ```

---

## 🖱️ Como Usar

### Para Arquivos:
1. No **Dolphin**, clique com o botão direito sobre um arquivo e selecione **"Ver versões nos Snapshots..."**.
2. Na janela do **kdialog**, veja todos os snapshots onde o arquivo existe, com indicação de tamanho, tempo relativo e se a versão está **`[Modificado]`** ou **`[Igual ao atual]`**.
   - Se desejar, clique na primeira opção **`🔍 [Filtrar: mostrar apenas as X versões com alterações]`** para ocultar snapshots repetidos.
3. Após selecionar o snapshot desejado, escolha a ação:
   - **🔍 Comparar com a versão atual (Diff Visual)**: abre o Kompare (ou KDiff3/Meld) comparando o snapshot e o arquivo atual lado a lado.
   - **♻️ Restaurar esta versão**: restaura via Copy-on-Write perguntando se deseja guardar um backup `.bak` do arquivo atual.
   - **📄 Restaurar como cópia ao lado do original**: cria `nome.snapshot-<ID>.ext` na mesma pasta.
   - **📂 Mostrar arquivo do snapshot no Dolphin**: abre o Dolphin selecionando o arquivo histórico.
   - **🪟 Abrir pastas lado a lado no Dolphin (Modo Dividido)**: abre o Dolphin com `dolphin --split`.

### Para Pastas (e Recuperação de Arquivos Excluídos):
1. Clique com o botão direito sobre uma pasta e selecione **"Ver versões nos Snapshots..."**.
2. Para **recuperar um arquivo que foi deletado** daquela pasta, selecione a primeira opção do menu:
   - **`🗑️ [Procurar arquivos excluídos nesta pasta em todos os snapshots...]`**
   - Escolha o item excluído encontrado e clique em **Restaurar para a pasta atual**.
3. Ou selecione um snapshot específico para abrir a pasta no Dolphin, abrir em modo dividido, comparar as pastas ou restaurá-la.

---

## 🔍 Comparação Visual (Diff) e Integração com Flathub

Para seguir a filosofia nativa do ecossistema KDE e funcionar em qualquer distribuição (incluindo sistemas imutáveis/atômicos como Fedora Kinoite e Bazzite), o `snapper-view` utiliza a seguinte ordem de detecção para comparar versões:

1. **Pacotes Nativos**: `kompare` → `kdiff3` → `meld`
2. **Pacotes Flatpak**: `org.kde.kompare` → `org.kde.kdiff3` → `org.gnome.meld`
   - Ao executar via Flatpak, o `snapper-view` concede automaticamente permissão temporária de leitura (`--filesystem=...:ro`) ao diretório `.snapshots`, garantindo que o sandbox do Flatpak consiga ler os snapshots mesmo quando estão fora de `$HOME` (como em `/var/home/.snapshots`).
3. **Instalação sob demanda via Flathub**: se nenhuma ferramenta gráfica estiver instalada, o `snapper-view` oferece instalar o **Kompare (`org.kde.kompare`)** automaticamente via Flathub.
4. **Fallback em Modo Texto**: caso o usuário prefira não instalar uma ferramenta gráfica ou esteja offline, a comparação unificada (`diff -ruN`) é exibida diretamente em uma janela nativa `kdialog --textbox`.

---

## 🗑️ Desinstalação

Para desinstalar o **snapper-view**, execute:

```bash
./uninstall.sh
```

---

## 🛠️ Solução de Problemas

### 1. A opção "Ver versões nos Snapshots..." não aparece no Dolphin ou exibe "Você não está autorizado a executar este arquivo"
- Verifique se o arquivo `snapper-history.desktop` está em `~/.local/share/kio/servicemenus/` e se **ambos** os arquivos possuem permissão de execução (`chmod +x`), pois o KDE Plasma/KIO bloqueia `.desktop` sem bit executável:
  ```bash
  chmod +x ~/.local/bin/snapper-view ~/.local/share/kio/servicemenus/snapper-history.desktop
  ```
- Reinicie o Dolphin (`killall dolphin`) e abra-o novamente.

### 2. "Permissão Necessária" ou erro ao acessar snapshots
- Aceite a configuração automática exibida pelo diálogo do `snapper-view` (via `pkexec`) ou execute `./setup-permissions.sh` no terminal.
- Verifique se a ACL foi aplicada com:
  ```bash
  getfacl /var/home/.snapshots  # ou getfacl /home/.snapshots
  ```
  Deverá constar `user:<seu_usuario>:r-x`.

---

## 📄 Licença

Distribuído sob a licença MIT. Sinta-se livre para utilizar, modificar e contribuir!
