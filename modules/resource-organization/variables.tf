variable "resource_groups" {
  description = "Resource group configurations"
  type = map(object({
    name     = string
    location = string
    tags     = optional(map(string))
  }))
}
