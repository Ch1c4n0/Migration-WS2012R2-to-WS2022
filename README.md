# Migration: Windows Server 2012 R2 → Windows Server 2022
# Migração: Windows Server 2012 R2 → Windows Server 2022

> **Autor / Author:** Marcelo dos Santos Gonçalves — Dual MVP (Security & Azure) | MCT | Docker Captain  
> **Repositório / Repository:** [Ch1c4n0/Migration-WS2012R2-to-WS2022](https://github.com/Ch1c4n0/Migration-WS2012R2-to-WS2022)

---

## 📋 Visão Geral / Overview

**PT-BR:** Este script documenta o passo a passo completo para migrar um controlador de domínio Active Directory do Windows Server 2012 R2 para o Windows Server 2022, incluindo atualização de schema, transferência de funções FSMO, rebaixamento do servidor antigo e atualização dos níveis de floresta e domínio.

**EN:** This script documents the complete step-by-step process to migrate an Active Directory Domain Controller from Windows Server 2012 R2 to Windows Server 2022, including schema update, FSMO role transfer, demotion of the old server, and raising the forest/domain functional levels.

---

## ⚠️ Pré-requisitos / Prerequisites

- Windows Server 2022 ISO montada no servidor antigo para atualização do schema
- PowerShell executado como Administrador em ambos os servidores
- Módulo **ActiveDirectory** instalado
- Conectividade de rede entre os dois servidores
- Backup do Active Directory realizado antes de iniciar

---

## 🗂️ Ordem de Execução / Execution Order

1. Verificações no Windows Server 2012 R2 (servidor antigo)
2. Configuração de rede no Windows Server 2022 (servidor novo)
3. Ingresso no domínio do novo servidor
4. Verificação e atualização do schema do AD
5. Promoção do novo servidor a DC
6. Verificação de replicação
7. Transferência das funções FSMO
8. Rebaixamento do servidor antigo
9. Atualização dos níveis funcionais de floresta e domínio

---

## 📖 Explicação Detalhada dos Comandos
## 📖 Detailed Command Explanation

---

### ETAPA 1 — No Windows Server 2012 R2 (Servidor Antigo)
### STEP 1 — On Windows Server 2012 R2 (Old Server)

---

#### `netdom query fsmo`

**PT-BR:**  
Lista todos os detentores das 5 funções FSMO (Flexible Single Master Operations) do Active Directory:
- **Schema Master** — controla as modificações no schema do AD
- **Domain Naming Master** — controla a adição/remoção de domínios na floresta
- **PDC Emulator** — emula o PDC para compatibilidade, sincronização de senhas e horário
- **RID Master** — distribui blocos de RIDs para criação de objetos
- **Infrastructure Master** — mantém referências entre objetos de domínios diferentes

Este comando deve ser executado **antes de iniciar a migração** para confirmar qual servidor detém cada função e garantir que a transferência seja feita corretamente.

**EN:**  
Lists all holders of the 5 Active Directory FSMO (Flexible Single Master Operations) roles:
- **Schema Master** — controls schema modifications
- **Domain Naming Master** — controls domain addition/removal in the forest
- **PDC Emulator** — emulates the PDC for compatibility, password sync, and time
- **RID Master** — distributes RID blocks for object creation
- **Infrastructure Master** — maintains cross-domain object references

Run this **before starting the migration** to confirm which server holds each role.

---

#### `dsa.msc`

**PT-BR:**  
Abre o console gráfico **Active Directory Users and Computers**. Utilizado para verificar visualmente a estrutura do domínio, usuários, grupos, computadores e OUs antes da migração. Permite confirmar o estado de saúde do AD e que não há objetos corrompidos ou problemas evidentes.

**EN:**  
Opens the **Active Directory Users and Computers** graphical console. Used to visually inspect the domain structure, users, groups, computers, and OUs before migration. Helps confirm AD health and absence of corrupt objects or visible issues.

---

#### `dfsrmig /getGlobalState`

**PT-BR:**  
Verifica o estado atual da migração do **SYSVOL** de FRS (File Replication Service) para DFSR (Distributed File System Replication). O SYSVOL deve estar no estado **`Eliminated (3)`** antes de continuar com a migração do DC.

Estados possíveis:
| Estado | Descrição |
|--------|------------------------------|
| 0 | Start (usando FRS) |
| 1 | Prepared |
| 2 | Redirected |
| 3 | Eliminated (DFSR ativo) |

**EN:**  
Checks the current state of **SYSVOL** migration from FRS (File Replication Service) to DFSR (Distributed File System Replication). SYSVOL must be in state **`Eliminated (3)`** before proceeding with DC migration.

Possible states:
| State | Description |
|-------|------------------------------|
| 0 | Start (using FRS) |
| 1 | Prepared |
| 2 | Redirected |
| 3 | Eliminated (DFSR active) |

---

### ETAPA 2 — No Windows Server 2022 (Servidor Novo)
### STEP 2 — On Windows Server 2022 (New Server)

---

#### `Get-NetAdapter`

**PT-BR:**  
Lista todos os adaptadores de rede disponíveis no servidor com seus nomes, status e velocidade. Usado para identificar o nome correto da interface de rede (ex: `Ethernet0`) antes de configurar o IP estático.

**EN:**  
Lists all available network adapters with their names, status, and speed. Used to identify the correct network interface name (e.g., `Ethernet0`) before configuring a static IP.

---

#### `Get-NetIPConfiguration -InterfaceAlias Ethernet0`

**PT-BR:**  
Exibe a configuração de rede atual da interface `Ethernet0`, incluindo endereço IP, gateway padrão e servidores DNS configurados. Essencial para verificar se o servidor novo já possui configuração de rede adequada ou se precisa ser configurado.

**EN:**  
Displays the current network configuration of the `Ethernet0` interface, including IP address, default gateway, and DNS servers. Essential to verify whether the new server already has proper network settings or needs to be configured.

---

#### `New-NetIPAddress -IPAddress 192.168.214.133 -PrefixLength 24 -DefaultGateway 192.168.214.2 -InterfaceAlias Ethernet0`

**PT-BR:**  
Atribui um **endereço IP estático** ao servidor. Controladores de domínio **devem ter IP estático** — nunca use DHCP para um DC, pois outros membros do domínio precisam localizar o DC de forma confiável.

- `-IPAddress` — endereço IP do novo servidor
- `-PrefixLength 24` — máscara de sub-rede /24 (equivalente a 255.255.255.0)
- `-DefaultGateway` — gateway padrão da rede
- `-InterfaceAlias` — nome da placa de rede

**EN:**  
Assigns a **static IP address** to the server. Domain Controllers **must use static IPs** — never use DHCP for a DC, as domain members need to reliably locate it.

- `-IPAddress` — IP address of the new server
- `-PrefixLength 24` — subnet mask /24 (equivalent to 255.255.255.0)
- `-DefaultGateway` — network default gateway
- `-InterfaceAlias` — network adapter name

---

#### `Set-DNSClientServerAddress -ServerAddresses 192.168.214.132 -InterfaceAlias Ethernet0`

**PT-BR:**  
Define o servidor DNS para o IP do **servidor antigo (DC existente)**. Este passo é **crítico**: o novo servidor precisa resolver o nome do domínio corretamente para ingressar no domínio e replicar o AD. O DNS deve sempre apontar para um DC existente durante a promoção.

**EN:**  
Sets the DNS server to the **existing DC's IP address**. This step is **critical**: the new server must correctly resolve the domain name to join the domain and replicate AD. DNS must always point to an existing DC during promotion.

---

#### `Add-Computer -DomainName cloudinfocus.lan -Restart`

**PT-BR:**  
Ingressa o servidor no domínio `cloudinfocus.lan` e reinicia automaticamente para aplicar as alterações. Após o ingresso, o servidor estará visível como membro do domínio no AD. O ingresso deve ser feito **antes** da promoção a controlador de domínio.

**EN:**  
Joins the server to the `cloudinfocus.lan` domain and automatically restarts to apply changes. After joining, the server will appear as a domain member in AD. The join must happen **before** promoting to a Domain Controller.

---

### ETAPA 3 — Verificar e Atualizar o Schema do AD
### STEP 3 — Verify and Update the AD Schema

---

#### Chave de Registro / Registry Key
```
HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\NTDS\Parameters
```

**PT-BR:**  
Caminho no registro do Windows onde fica armazenada a versão atual do schema do AD (valor `Schema Version`). Pode ser verificado manualmente pelo **regedit** para confirmar a versão atual antes de atualizar.

**EN:**  
Windows registry path where the current AD schema version is stored (`Schema Version` value). Can be checked manually via **regedit** to confirm the current version before upgrading.

---

#### `Get-ADObject (Get-ADRootDSE).schemaNamingContext -Property objectVersion`

**PT-BR:**  
Consulta via PowerShell a versão atual do schema do AD. A versão do schema determina quais funcionalidades do AD estão disponíveis.

Versions de referência:
| Versão | Sistema Operacional |
|--------|---------------------|
| 44 | Windows Server 2003 |
| 47 | Windows Server 2008 |
| 56 | Windows Server 2012 |
| 69 | Windows Server 2012 R2 |
| 87 | Windows Server 2016 |
| 88 | Windows Server 2019 |
| 88 | Windows Server 2022 |

**EN:**  
PowerShell query to retrieve the current AD schema version, which determines available AD features.

Reference versions:
| Version | Operating System |
|---------|------------------|
| 44 | Windows Server 2003 |
| 47 | Windows Server 2008 |
| 56 | Windows Server 2012 |
| 69 | Windows Server 2012 R2 |
| 87 | Windows Server 2016 |
| 88 | Windows Server 2019/2022 |

---

#### `adprep.exe /forestprep`

**PT-BR:**  
Atualiza o **schema da floresta** do Active Directory para suportar o Windows Server 2022. Deve ser executado **montando a mídia de instalação do WS2022** no servidor WS2012 R2, a partir do caminho `D:\support\adprep\`. Requer que o executor seja membro dos grupos **Schema Admins** e **Enterprise Admins**.

> ⚠️ Execute apenas uma vez na floresta, no servidor que detém o Schema Master.

**EN:**  
Updates the Active Directory **forest schema** to support Windows Server 2022. Must be run by **mounting the WS2022 installation media** on the WS2012 R2 server, from the path `D:\support\adprep\`. Requires membership in **Schema Admins** and **Enterprise Admins** groups.

> ⚠️ Run only once per forest, on the server holding the Schema Master role.

---

#### `adprep.exe /domainprep /gpprep`

**PT-BR:**  
Atualiza o **domínio** para suportar os novos controladores de domínio WS2022 e atualiza as permissões de **Group Policy** (GPOs). Deve ser executado após o `/forestprep` e no servidor que detém o **Infrastructure Master** do domínio. O `/gpprep` garante que as políticas de grupo funcionem corretamente com o novo DC.

**EN:**  
Updates the **domain** to support the new WS2022 Domain Controllers and updates **Group Policy** (GPO) permissions. Must be run after `/forestprep`, on the server holding the domain's **Infrastructure Master**. The `/gpprep` switch ensures Group Policy works correctly with the new DC.

---

### ETAPA 4 — Instalar o AD DS no Novo Servidor
### STEP 4 — Install AD DS on the New Server

---

#### `Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools`

**PT-BR:**  
Instala a função **Active Directory Domain Services (AD DS)** no Windows Server 2022, incluindo as ferramentas de gerenciamento (como `dsa.msc`, `dcpromo` via PowerShell, etc.). Este comando apenas instala os binários — a promoção a controlador de domínio deve ser feita em seguida com `Install-ADDSDomainController`.

> 💡 O parâmetro `-IncludeManagementTools` instala o módulo ActiveDirectory para PowerShell e o RSAT AD.

**EN:**  
Installs the **Active Directory Domain Services (AD DS)** role on Windows Server 2022, including management tools (such as `dsa.msc`, PowerShell AD module, etc.). This command only installs the binaries — promotion to a Domain Controller must follow with `Install-ADDSDomainController`.

> 💡 The `-IncludeManagementTools` parameter installs the ActiveDirectory PowerShell module and RSAT AD tools.

---

### ETAPA 5 — Verificar Replicação do AD
### STEP 5 — Verify AD Replication

---

#### `repadmin /showrepl`

**PT-BR:**  
Exibe o status detalhado da **replicação do Active Directory** entre os controladores de domínio, mostrando parceiros de replicação, últimos horários de replicação bem-sucedida e eventuais erros. Use este comando **após promover o novo servidor a DC** para garantir que a replicação está funcionando corretamente antes de transferir as funções FSMO.

**EN:**  
Displays detailed **Active Directory replication status** between Domain Controllers, showing replication partners, last successful replication times, and any errors. Use this command **after promoting the new server to DC** to ensure replication is working correctly before transferring FSMO roles.

---

#### `repadmin /syncall /APed`

**PT-BR:**  
Força a **sincronização imediata** de todos os objetos do AD entre todos os controladores de domínio. Parâmetros:
- `/A` — sincroniza todos os DCs da floresta
- `/P` — faz o DC local enviar atualizações para todos os parceiros
- `/e` — sincroniza entre sites (cross-site)
- `/d` — exibe mensagens de saída no modo verbose

Use este comando para garantir que o novo DC está completamente sincronizado antes da transferência das funções FSMO.

**EN:**  
Forces **immediate synchronization** of all AD objects across all Domain Controllers. Parameters:
- `/A` — synchronizes all DCs in the forest
- `/P` — pushes updates from the local DC to all partners
- `/e` — synchronizes across sites (cross-site)
- `/d` — displays verbose output messages

Use this to ensure the new DC is fully synchronized before FSMO role transfer.

---

### ETAPA 6 — Transferir as Funções FSMO
### STEP 6 — Transfer FSMO Roles

---

#### `Move-ADDirectoryServerOperationMasterRole -Identity VM-AD2022 -OperationMasterRole 0,1,2,3,4`

**PT-BR:**  
Transfere **todas as 5 funções FSMO** de uma vez para o servidor `VM-AD2022`. Os números correspondem a:
| Nº | Função |
|----|-------------------------------------|
| 0 | PDC Emulator |
| 1 | RID Master |
| 2 | Infrastructure Master |
| 3 | Schema Master |
| 4 | Domain Naming Master |

> ⚠️ Substitua `VM-AD2022` pelo nome real do seu novo servidor. A transferência deve ser feita com os dois DCs online e replicando corretamente.

**EN:**  
Transfers **all 5 FSMO roles** at once to the `VM-AD2022` server. Numbers correspond to:
| # | Role |
|---|-------------------------------------|
| 0 | PDC Emulator |
| 1 | RID Master |
| 2 | Infrastructure Master |
| 3 | Schema Master |
| 4 | Domain Naming Master |

> ⚠️ Replace `VM-AD2022` with your actual new server name. Transfer must be done with both DCs online and replicating correctly.

---

#### Transferência Individual das Funções / Individual Role Transfer

```powershell
Move-ADDirectoryServerOperationMasterRole -Identity VM-AD2022 -OperationMasterRole SchemaMaster
Move-ADDirectoryServerOperationMasterRole -Identity VM-AD2022 -OperationMasterRole DomainNamingMaster
Move-ADDirectoryServerOperationMasterRole -Identity VM-AD2022 -OperationMasterRole PDCEmulator
Move-ADDirectoryServerOperationMasterRole -Identity VM-AD2022 -OperationMasterRole RIDMaster
Move-ADDirectoryServerOperationMasterRole -Identity VM-AD2022 -OperationMasterRole InfrastructureMaster
```

**PT-BR:**  
Alternativa à transferência em lote — transfere cada função FSMO individualmente usando seus nomes. Recomendado quando se deseja maior controle ou quando a transferência de uma função falha e precisa ser tratada isoladamente. Após cada transferência, verifique com `netdom query fsmo`.

**EN:**  
Alternative to bulk transfer — transfers each FSMO role individually by name. Recommended for greater control or when a specific role transfer fails and needs to be handled in isolation. After each transfer, verify with `netdom query fsmo`.

---

### ETAPA 7 — Rebaixar o Servidor Antigo (No WS2012 R2)
### STEP 7 — Demote the Old Server (On WS2012 R2)

---

#### `Uninstall-ADDSDomainController -DemoteOperationMasterRole -RemoveApplicationPartitions -Force -Credential (Get-Credential) -Verbose`

**PT-BR:**  
Rebaixa o servidor WS2012 R2, removendo-o como **Controlador de Domínio**. Parâmetros:
- `-DemoteOperationMasterRole` — permite rebaixar mesmo que o servidor ainda detenha funções FSMO (transfere automaticamente, use apenas se já transferiu manualmente)
- `-RemoveApplicationPartitions` — remove partições de aplicativos do AD (ex: DNS zones) que estejam hospedadas neste DC
- `-Force` — não solicita confirmação interativa
- `-Credential (Get-Credential)` — solicita credenciais de um Domain Admin para autorizar o rebaixamento
- `-Verbose` — exibe saída detalhada do processo

> ⚠️ Execute este comando **somente após confirmar** que o novo DC está replicando corretamente e detém todas as funções FSMO.

**EN:**  
Demotes the WS2012 R2 server, removing it as a **Domain Controller**. Parameters:
- `-DemoteOperationMasterRole` — allows demotion even if the server still holds FSMO roles
- `-RemoveApplicationPartitions` — removes AD application partitions (e.g., DNS zones) hosted on this DC
- `-Force` — no interactive confirmation prompt
- `-Credential (Get-Credential)` — prompts for Domain Admin credentials
- `-Verbose` — displays detailed process output

> ⚠️ Run this command **only after confirming** the new DC is replicating correctly and holds all FSMO roles.

---

### ETAPA 8 — Atualizar os Níveis Funcionais
### STEP 8 — Raise Functional Levels

---

#### `Set-ADForestMode -Identity cloudinfocus.lan -ForestMode Windows2016Forest`

**PT-BR:**  
Eleva o **nível funcional da floresta** para Windows Server 2016. Importante: o nível mais alto disponível para WS2022 ainda é `Windows2016Forest`, pois a Microsoft não introduziu um novo nível funcional de floresta exclusivo para 2019 ou 2022.

Benefícios de elevar o nível funcional da floresta:
- Habilita **Privileged Access Management (PAM)** com Microsoft Identity Manager
- Permite uso de **Shadow Principals** (grupos com TTL)
- Habilita recursos avançados de replicação e segurança

> ⚠️ Esta operação é **irreversível**. Certifique-se de que **todos os DCs da floresta** são WS2016 ou superior antes de executar.

**EN:**  
Raises the **forest functional level** to Windows Server 2016. Note: the highest available level for WS2022 is still `Windows2016Forest`, as Microsoft did not introduce new forest functional levels for 2019 or 2022.

Benefits of raising the forest functional level:
- Enables **Privileged Access Management (PAM)** with Microsoft Identity Manager
- Allows use of **Shadow Principals** (time-limited group membership)
- Enables advanced replication and security features

> ⚠️ This operation is **irreversible**. Ensure **all DCs in the forest** are WS2016 or higher before running.

---

#### `Set-ADDomainMode -Identity cloudinfocus.lan -DomainMode Windows2016Domain`

**PT-BR:**  
Eleva o **nível funcional do domínio** para Windows Server 2016. O nível funcional do domínio controla funcionalidades disponíveis dentro do domínio específico.

Benefícios:
- Suporte a **Kerberos armoring** (FAST — Flexible Authentication Secure Tunneling)
- Suporte a **controle de acesso dinâmico** avançado
- Melhoria na auditoria e controle de autenticação
- Suporte a **Authentication Policies e Authentication Policy Silos**

> ⚠️ Esta operação também é **irreversível**. Certifique-se de que todos os DCs do domínio são WS2016 ou superior.

**EN:**  
Raises the **domain functional level** to Windows Server 2016. The domain functional level controls features available within the specific domain.

Benefits:
- Support for **Kerberos armoring** (FAST — Flexible Authentication Secure Tunneling)
- Support for advanced **dynamic access control**
- Improved authentication auditing and control
- Support for **Authentication Policies and Authentication Policy Silos**

> ⚠️ This operation is also **irreversible**. Ensure all DCs in the domain are WS2016 or higher.

---

## 🔄 Fluxo Completo / Complete Flow

```
[WS2012 R2 - Servidor Antigo]          [WS2022 - Servidor Novo]
        |                                        |
  netdom query fsmo                     Get-NetAdapter
  dsa.msc (verificar AD)                Get-NetIPConfiguration
  dfsrmig /getGlobalState               New-NetIPAddress (IP estático)
        |                               Set-DNSClientServerAddress
        |                               Add-Computer (ingressar no domínio)
        |                                        |
  Montar ISO WS2022                              |
  adprep /forestprep                             |
  adprep /domainprep /gpprep                     |
        |                               Install-WindowsFeature AD-DS
        |                               (Promover a DC via GUI ou PowerShell)
        |                                        |
        +-------- Verificar Replicação ----------+
                  repadmin /showrepl
                  repadmin /syncall /APed
                           |
              Move-ADDirectoryServerOperationMasterRole
                  (Transferir FSMO para WS2022)
                           |
              [WS2012 R2] Uninstall-ADDSDomainController
                           |
              Set-ADForestMode (Windows2016Forest)
              Set-ADDomainMode (Windows2016Domain)
```

---

## 📚 Referências / References

- [Upgrade Domain Controllers to Windows Server 2022 - Microsoft Docs](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/deploy/upgrade-domain-controllers)
- [AD DS Deployment - Install-ADDSDomainController](https://learn.microsoft.com/en-us/powershell/module/addsdeployment/install-addsdomaincontroller)
- [Active Directory Forest and Domain Functional Levels](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/active-directory-functional-levels)
- [Repadmin Reference](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-r2-and-2012/cc770963(v=ws.11))
- [FSMO Roles Overview](https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/fsmo-roles)

---

## 📄 Licença / License

MIT License — free to use, modify, and distribute.

---

*Criado por / Created by: [Marcelo dos Santos Gonçalves](https://github.com/Ch1c4n0)*
