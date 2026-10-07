# snapper-view 📸

> **Menu de serviço para o KDE Dolphin que permite visualizar e restaurar versões anteriores de arquivos e diretórios em snapshots do Btrfs gerenciados pelo Snapper.**

---

## 📋 Sumário

- [Visão Geral](#-visão-geral)
- [Funcionalidades](#-funcionalidades)
- [Requisitos](#-requisitos)
- [Estrutura do Projeto](#-estrutura-do-projeto)
- [Configuração de Permissões do Snapper](#-configuração-de-permissões-do-snapper)
  - [Configuração Automática (`setup-permissions.sh`)](#1-configuração-automática-script-setup-permissionssh)
  - [Configuração Manual](#2-configuração-manual)
- [Instalação](#-instalação)
  - [Instalação Rápida (Script)](#instalação-rápida-automática)
  - [Instalação Manual](#instalação-manual)
- [Como Usar](#-como-usar)
- [Ajustes e Customização (Caminho Base)](#-ajustes-e-customização-caminho-base)
- [Desinstalação](#-desinstalação)
- [Solução de Problemas](#-solução-de-problemas)

---

## 🔍 Visão Geral

O **snapper-view** adiciona uma ação ao menu de contexto (clique com o botão direito) do **KDE Dolphin** chamada **"Ver versões nos Snapshots..."**. Ao clicar sobre qualquer arquivo ou diretório pertencente a um subvolume Btrfs monitorado pelo **Snapper**, um diálogo nativo (`kdialog`) lista todos os snapshots que contêm versões desse item. Ao selecionar uma versão, o Dolphin abre a pasta correspondente no snapshot ou seleciona o arquivo histórico diretamente.

---

## ✨ Funcionalidades

- 🗂️ **Integração nativa com KDE Dolphin** através de KIO Service Menus.
- 🕒 **Histórico cronológico**: lista do snapshot mais recente ao mais antigo.
- 🏷️ **Informações completas**: exibe ID do snapshot, descrição e data/hora de criação.
- 🎯 **Abertura inteligente no Dolphin**:
  - Para pastas: navega diretamente para a pasta no snapshot.
  - Para arquivos: abre a pasta contendo o arquivo e o seleciona (`dolphin --select`).
- 🔒 **Acesso sem root**: permite que o usuário comum acesse snapshots com segurança via ACLs do Snapper.

---

## 📦 Requisitos

Certifique-se de que os seguintes pacotes estejam instalados no seu sistema:

- **KDE Plasma & Dolphin** (gerenciador de arquivos)
- **kdialog** (diálogos gráficos nativos do KDE)
- **snapper** (gerenciador de snapshots Btrfs)
- **btrfs-progs** (utilitários do sistema de arquivos Btrfs)
- Subvolume formatado em **Btrfs** com snapshots ativos (ex: `/var/home` ou `/home`)

---

## 📁 Estrutura do Projeto

| Arquivo | Destino de Instalação | Descrição |
| :--- | :--- | :--- |
| `snapper-history.desktop` | `~/.local/share/kio/servicemenus/` | Entrada do menu de contexto do KDE Dolphin |
| `snapper-view` | `~/.local/bin/` | Script principal que busca snapshots e aciona o Dolphin |
| `setup-permissions.sh` | *(utilitário)* | Script auxiliar para liberar permissões no Snapper |
| `install.sh` | *(utilitário)* | Instalador automático |
| `uninstall.sh` | *(utilitário)* | Desinstalador |

---

## 🔐 Configuração de Permissões do Snapper

Por padrão, a pasta `.snapshots` de um subvolume Btrfs possui permissão restrita (`0750` apenas para `root`). Para que o **snapper-view** funcione sem pedir privilégios de administrador a cada clique, o Snapper deve conceder acesso ao usuário via ACL.

### 1. Configuração Automática (Script `setup-permissions.sh`)

O projeto inclui o script [`setup-permissions.sh`](setup-permissions.sh), que detecta automaticamente a configuração do Snapper e aplica as permissões:

```bash
# Execução simples (detecta configuração e usuário automaticamente):
./setup-permissions.sh

# Especificando a configuração e o usuário (opcional):
./setup-permissions.sh Snapshots rafael

# Simulação sem aplicar alterações:
./setup-permissions.sh --dry-run
```

O script:
1. Descobre o nome da configuração ativa do Snapper (ex.: `Snapshots`, `home`, `root`).
2. Identifica o usuário não-root atual.
3. Preserva usuários já existentes em `ALLOW_USERS`.
4. Executa:
   ```bash
   sudo snapper -c <config_name> set-config "ALLOW_USERS=<username>" "SYNC_ACL=yes"
   ```
5. Valida se o usuário já consegue acessar os snapshots sem permissões de superusuário.

---

### 2. Configuração Manual

Se preferir fazer manualmente:

1. Liste as configurações existentes do Snapper:
   ```bash
   snapper list-configs
   ```

2. Adicione seu usuário e sincronize as ACLs:
   ```bash
   sudo snapper -c <nome_da_configuração> set-config "ALLOW_USERS=$USER" "SYNC_ACL=yes"
   ```
   *(Substitua `<nome_da_configuração>` pelo nome identificado no passo 1, ex: `Snapshots`)*

---

## 🚀 Instalação

### Instalação Rápida (Automática)

Execute o script de instalação incluído:

```bash
chmod +x install.sh
./install.sh
```

O instalador irá:
1. Copiar `snapper-view` para `~/.local/bin/` e conceder permissão de execução.
2. Copiar `snapper-history.desktop` para `~/.local/share/kio/servicemenus/`.
3. Oferecer a execução do assistente de permissões (`setup-permissions.sh`).

---

### Instalação Manual

Se desejar copiar os arquivos manualmente:

1. Crie os diretórios de destino (caso ainda não existam):
   ```bash
   mkdir -p ~/.local/bin ~/.local/share/kio/servicemenus
   ```

2. Copie o script executável e dê permissão de execução:
   ```bash
   cp snapper-view ~/.local/bin/
   chmod +x ~/.local/bin/snapper-view
   ```

3. Copie o arquivo do menu de serviço do Dolphin:
   ```bash
   cp snapper-history.desktop ~/.local/share/kio/servicemenus/
   ```

4. Configure as permissões do Snapper executando:
   ```bash
   ./setup-permissions.sh
   ```

---

## 🖱️ Como Usar

1. Abra o **Dolphin**.
2. Clique com o botão direito em qualquer arquivo ou pasta que pertença ao subvolume monitorado.
3. Clique em **"Ver versões nos Snapshots..."**.
4. Uma janela do **kdialog** será exibida com a lista de todos os snapshots onde o item existe, indicando:
   - Número do Snapshot (`Snapshot #ID`)
   - Descrição (se houver)
   - Data e hora de criação
5. Selecione o snapshot desejado e clique em **OK**.
6. O Dolphin será aberto na pasta correspondente daquele snapshot no tempo.

---

## ⚙️ Ajustes e Customização (Caminho Base)

Por padrão, o script [`snapper-view`](snapper-view) está configurado para sistemas onde o subvolume do usuário é `/var/home` (comum no **Fedora Silverblue**, **Kinoite**, **Bazzite** e outras distribuições atômicas):

```bash
BASE="/var/home"
```

Se em sua distribuição (como **openSUSE**, **Arch Linux**, **Debian/Ubuntu**) o subvolume estiver montado diretamente em `/home`:

1. Abra o arquivo `~/.local/bin/snapper-view` no seu editor favorito:
   ```bash
   nano ~/.local/bin/snapper-view
   ```
2. Altere a linha 3 de:
   ```bash
   BASE="/var/home"
   ```
   para:
   ```bash
   BASE="/home"
   ```
3. Salve o arquivo. Não é necessário reiniciar o Dolphin.

---

## 🗑️ Desinstalação

Para desinstalar o **snapper-view**, basta rodar:

```bash
./uninstall.sh
```

Ou remover manualmente os arquivos instalados:

```bash
rm -f ~/.local/bin/snapper-view
rm -f ~/.local/share/kio/servicemenus/snapper-history.desktop
```

---

## 🛠️ Solução de Problemas

### 1. A opção "Ver versões nos Snapshots..." não aparece no Dolphin
- Verifique se o arquivo `snapper-history.desktop` está em `~/.local/share/kio/servicemenus/`.
- Reinicie o Dolphin: `killall dolphin` e abra-o novamente.

### 2. Mensagem "O item selecionado não pertence a /var/home"
- Verifique em qual subvolume seu diretório pessoal está montado executando `findmnt /home` ou `snapper list-configs`.
- Se o caminho for `/home` em vez de `/var/home`, edite a variável `BASE` em `~/.local/bin/snapper-view` conforme explicado na seção [Ajustes e Customização](#-ajustes-e-customização-caminho-base).

### 3. "Permissão Negada" ao acessar os snapshots
- Execute o script `./setup-permissions.sh` para garantir que o Snapper aplicou a ACL necessária.
- Verifique se a ACL foi aplicada com o comando:
  ```bash
  getfacl /var/home/.snapshots  # ou getfacl /home/.snapshots
  ```
  Deverá constar uma linha como: `user:<seu_usuario>:r-x`.

---

## 📄 Licença

Distribuído sob a licença MIT. Sinta-se livre para utilizar, modificar e contribuir!
