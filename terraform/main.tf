terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.46.0"
    }
  }
}
#provider "azurerm"{
#    version = "2.5.0"
#    features {}
#}
provider "azurerm"{
    features{

    }
    #az ad sp create-for-rbac --name <service_principal_name> --role Contributor
    #execution of abe command in Azure Cli(Bash) will give you tenant_id, client_id, client_secret
    #subscription_id   = "<azure_subscription_id>"
    #tenant_id         = "<azure_subscription_tenant_id>"
    #client_id         = "<service_principal_appid>"
    #client_secret     = "<service_principal_password>"
}
provider "azuread"{

}


resource "azuread_user" "users" { #using user_list as set of  map or dictionery
    for_each = var.user_list
    user_principal_name = "${each.value.email}@vermarita2003live.onmicrosoft.com"
    display_name = each.value.name
    mail_nickname = each.value.email
    password = each.value.pass
}

variable "user_list"{ #user as set of dictionery
    default={
        user1 = {name: "Phone", pass:"qazwsxEDC321", email:"Phone321"}
        user2 = {name: "Danielle", pass:"qazWSCEDC321", email:"Danielle321"}
    }

}
variable "location"{
    #description = "Provide resource group's location"
    #default="eastus"
    #now it will look in to terraform.tfvars. This file should be in the same location as main.tf
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "tfweb_profiles_rg" {
    name     = "auto_web_profiles_rg"
    location = var.location

    tags = {
        environment ="web_profiles" #"Terraform Demo"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "tfweb_profiles_vnet" {
    name                = "auto_web_profiles_vnet"
    address_space       = ["10.0.0.0/16"]
    location            = var.location
    resource_group_name = azurerm_resource_group.tfweb_profiles_rg.name

    tags = {
        environment =  "web_profiles" #"Terraform Demo"
    }
}

# Create subnet
resource "azurerm_subnet" "tfweb_profiles_subnet" {
    name                 = "auto_web_profiles_subnet"
    resource_group_name  = azurerm_resource_group.tfweb_profiles_rg.name
    virtual_network_name = azurerm_virtual_network.tfweb_profiles_vnet.name
    address_prefixes       = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "tfweb_profiles_publicip" {
    name                         = "autowebProfilesPublicIP"
    location                     = var.location
    resource_group_name          = azurerm_resource_group.tfweb_profiles_rg.name
    allocation_method            = "Dynamic"

    tags = {
        environment = "web_profiles" #"Terraform Demo"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "tfweb_profiles_nsg" {
    name                = "auto_web_profiles_nsg"
    location            = var.location
    resource_group_name = azurerm_resource_group.tfweb_profiles_rg.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
    
    tags = {
        environment = "web_profiles" #"Terraform Demo"
    }
}
#Create security rule
resource "azurerm_network_security_rule" "testrules" {
  name                        = "HTTP"
  direction                   = "Inbound"
  access                      = "Allow"
  priority                    = "201"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.tfweb_profiles_rg.name
  network_security_group_name = azurerm_network_security_group.tfweb_profiles_nsg.name
}

# Create network interface
resource "azurerm_network_interface" "tfweb_profiles_nic" {
    name                      = "auto_web_profiles_NIC"
    location                  = var.location
    resource_group_name       = azurerm_resource_group.tfweb_profiles_rg.name

    ip_configuration {
        name                          = "auto_web_profiles_config"
        subnet_id                     = azurerm_subnet.tfweb_profiles_subnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.tfweb_profiles_publicip.id
    }

    tags = {
        environment ="web_profiles" #"Terraform Demo"
    }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "tf_nic_nsg_attch_web_profiles" {
    network_interface_id      = azurerm_network_interface.tfweb_profiles_nic.id
    network_security_group_id = azurerm_network_security_group.tfweb_profiles_nsg.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.tfweb_profiles_rg.name
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "tfweb_profiles_stor_acct" {
    name                        = "autowebprofilesdiagstor" #${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.tfweb_profiles_rg.name
    location                    = var.location
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "web_profiles"#"Terraform Demo"
    }
}
# Create virtual machine
resource "azurerm_linux_virtual_machine" "tfweb_profiles" {
    name                  = "autoVM_web_profiles"
    location              = var.location
    resource_group_name   = azurerm_resource_group.tfweb_profiles_rg.name
    network_interface_ids = [azurerm_network_interface.tfweb_profiles_nic.id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "autoweb_profiles_OS_disk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    computer_name  = "autowebprofilescompnm"
    admin_username = "azureuser"
    disable_password_authentication = true

    admin_ssh_key {
        username       = "azureuser"
        public_key     = tls_private_key.web_ssh.public_key_openssh
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.tfweb_profiles_stor_acct.primary_blob_endpoint
    }

    tags = {
        environment = "web_profiles"#"Terraform Demo"
    }
}
# Create (and display) an SSH key
resource "tls_private_key" "web_ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}
output "tls_private_key" { 
    value = tls_private_key.web_ssh.private_key_pem 
    sensitive = true
}
output "name" { # to show or reuse the vaule which is returned by Azure.Look in terraform.tfstate


    value = azuread_user.users["user1"].user_type 
}

#output "admin_password" {
#    value       = azurerm_container_registry.projcont.admin_password
#    description = "The object ID of the user"
#    sensitive = true
#}