resource "azurerm_virtual_network" "vm" {
  name                = "foo-vm-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
}

resource "azurerm_subnet" "vm" {
  name                 = "default"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vm.name
  address_prefixes     = ["10.0.0.0/24"]

  depends_on = [ azurerm_virtual_network.vm ]
}

resource "azurerm_network_security_group" "vm" {
  name                = "foo-vm-nsg"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "SSH"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 310
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "vm" {
  name                = "foo-vm-ip"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  domain_name_label   = "foo-vm-public"
}


resource "azurerm_network_interface" "vm" {
  name                = "foo-vm564"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.vm.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm.id
  }

  internal_dns_name_label = "foo-vm"
  
  depends_on = [ azurerm_subnet.vm, azurerm_public_ip.vm ]
}

resource "azurerm_network_interface_security_group_association" "vm" {
  network_interface_id       = azurerm_network_interface.vm.id
  network_security_group_id  = azurerm_network_security_group.vm.id

  depends_on = [ azurerm_network_interface.vm, azurerm_network_security_group.vm ]
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                            = "foo-vm"
  computer_name                   = "foo-vm"
  location                        = var.resource_group_location
  resource_group_name             = var.resource_group_name
  size                            = "Standard_B2s"
  admin_username                  = "azureuser"
  network_interface_ids           = [azurerm_network_interface.vm.id]
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("./foo-vm-ssh-key.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    name                 = "foo-vm-osdisk"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  secure_boot_enabled = true
  vtpm_enabled        = true

  additional_capabilities {
    hibernation_enabled = false
    ultra_ssd_enabled   = false
  }

  custom_data = base64encode(<<-EOF
    #cloud-config
    package_update: true
    package_upgrade: true
  EOF
  )

  identity {
    type = "SystemAssigned"
  }

  depends_on = [ azurerm_network_interface.vm, azurerm_public_ip.vm, azurerm_network_security_group.vm ]
}
