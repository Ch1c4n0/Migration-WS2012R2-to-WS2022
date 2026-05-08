## Win12

netdom query fsmo

dsa.msc

dfsrmig /getGlobalState

## Win22

Get-NetAdapter
Get-NetIPConfiguration -InterfaceAlias Ethernet0

New-NetIPAddress -IPAddress 192.168.214.133 -PrefixLength 24 -DefaultGateway 192.168.214.2 -InterfaceAlias Ethernet0

Set-DNSClientServerAddress -ServerAddresses 192.168.214.132 -InterfaceAlias Ethernet0

ADD-Computer -DomainName cloudinfocus.lan -Restart


#Ver a Versao do Schema do AD


HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\NTDS\Parameters
Get-ADObject (Get-ADRootDSE).schemaNamingContext -Property objectVersion

#Atualizar o Schema do AD

#Montar o CD WinServer2022 no Windows Server 2012

cd d:
cd '\support\adprep'
.\adprep.exe /forestprep
.\adprep.exe /domainprep /gpprep



Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools


Apos de fazer o sync no sites do active directory use os comandos abaixo para verificar o status do sync

repadmin /showrepl
repadmin /syncall /APed

Move-ADDirectoryServerOperationMasterRole -Identity VM-AD2022 -OperationMasterRole 0,1,2,3,4

Ou

Move-ADDirectoryServerOperationMasterRole -Identity VM-AD2022 -OperationMasterRole SchemaMaster
Move-ADDirectoryServerOperationMasterRole -Identity VM-AD2022 -OperationMasterRole DomainNamingMaster
Move-ADDirectoryServerOperationMasterRole -Identity VM-AD2022 -OperationMasterRole PDCEmulator
Move-ADDirectoryServerOperationMasterRole -Identity VM-AD2022 -OperationMasterRole RIDMaster
Move-ADDirectoryServerOperationMasterRole -Identity VM-AD2022 -OperationMasterRole InfrastructureMaster      


#faca no Windows 2012
#Agora rebaixar o servidor antigo
Uninstall-ADDSDomainController -DemoteOperationMasterRole -RemoveApplicationPartitions -Force -Credential (Get-Credential) -Verbose     

#Agora precisamos atualizar o nivel da floresta e do dominio para o Windows Server 2022
Set-ADForestMode -Identity cloudinfocus.lan -ForestMode Windows2016Forest
Set-ADDomainMode -Identity cloudinfocus.lan -DomainMode Windows2016Domain
