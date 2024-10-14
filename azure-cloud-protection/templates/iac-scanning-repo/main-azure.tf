# Random String for naming purposes
resource "random_string" "random" {
  length  = 4
  special = false
  upper   = false
}

# Azure Blob Storage (Equivalent of S3 Bucket)
resource "azurerm_storage_account" "storage" {
  name                     = "falconiaciac${random_string.random.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "container" {
  name                  = "iac-container"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "blob"  # Public access, change this to `private` to secure it
}

# Azure Resource Group
resource "azurerm_resource_group" "main" {
  name     = "falcon-iac-resources"
  location = "East US"
}

# Azure Virtual Network (VNet)
resource "azurerm_virtual_network" "vnet" {
  name                = "falcon-iac-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# Public Subnet
resource "azurerm_subnet" "public_subnet" {
  name                 = "public-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Private Subnet
resource "azurerm_subnet" "private_subnet" {
  name                 = "private-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Public IP Address
resource "azurerm_public_ip" "public_ip" {
  name                = "public-ip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
}

# Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = "falcon-iac-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# Network Interface (Public Subnet)
resource "azurerm_network_interface" "nic_public" {
  name                = "nic-public"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

# Network Interface (Private Subnet)
resource "azurerm_network_interface" "nic_private" {
  name                = "nic-private"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.private_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Azure Virtual Machine (Equivalent of EC2 instance with public access)
resource "azurerm_virtual_machine" "vm_public" {
  name                  = "falcon-iac-vm-public"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  network_interface_ids = [azurerm_network_interface.nic_public.id]
  vm_size               = "Standard_B1s"

  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true

  storage_os_disk {
    name              = "osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "publicvm"
    admin_username = "adminuser"
    admin_password = "Password1234!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

# Azure Virtual Machine (Private Subnet)
resource "azurerm_virtual_machine" "vm_private" {
  name                  = "falcon-iac-vm-private"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  network_interface_ids = [azurerm_network_interface.nic_private.id]
  vm_size               = "Standard_B1s"

  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true

  storage_os_disk {
    name              = "osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "privatevm"
    admin_username = "adminuser"
    admin_password = "Password1234!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

# Azure Managed Identity (Equivalent of IAM Role)
resource "azurerm_user_assigned_identity" "identity" {
  name                = "falcon-iac-identity"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

# Assign Role to Managed Identity (Equivalent to IAM Role Policy)
resource "azurerm_role_assignment" "role_assignment" {
  scope                = azurerm_storage_account.storage.id
  role_definition_name = "Storage Blob Data Contributor"  # Adjust permissions as needed
  principal_id         = azurerm_user_assigned_identity.identity.principal_id
}

# Azure Key Vault Secret (Equivalent to AWS Secrets Manager)
resource "azurerm_key_vault" "vault" {
  name                = "falcon-iac-kv"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
}

resource "azurerm_key_vault_secret" "secret" {
  name         = "iac-secret"
  value        = var.secret_value
  key_vault_id = azurerm_key_vault.vault.id
}

variable "secret_value" {
  default = "example"
  sensitive = true
}
