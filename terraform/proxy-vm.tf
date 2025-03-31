resource "azurerm_network_security_group" "proxy-vm" {
  name                = "proxy-vm-nsg"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "RDP"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}



resource "azurerm_public_ip" "proxy-vm" {
  name                = "proxy-vm-ip"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  domain_name_label   = "proxy-vm-public"
}


resource "azurerm_network_interface" "proxy-vm" {
  name                = "proxy-vm564"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.vm.id # use same subnet as VM
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.proxy-vm.id
  }

  internal_dns_name_label = "proxy-vm"
  
  depends_on = [ azurerm_subnet.vm, azurerm_public_ip.proxy-vm]
}

resource "azurerm_network_interface_security_group_association" "proxy-vm" {
  network_interface_id       = azurerm_network_interface.proxy-vm.id
  network_security_group_id  = azurerm_network_security_group.proxy-vm.id

  depends_on = [ azurerm_network_interface.proxy-vm, azurerm_network_security_group.proxy-vm ]
}

