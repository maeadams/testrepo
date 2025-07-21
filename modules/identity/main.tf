resource "azurerm_user_assigned_identity" "identity" {
  for_each = var.managed_identities

  name                = each.value.name
  resource_group_name = each.value.resource_group_name
  location            = each.value.location
  tags                = lookup(each.value, "tags", null)
}