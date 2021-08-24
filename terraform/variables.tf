variable "users" {
  type = list(string)
  default = [
    "aabdull",
    "john-bernhardt",
    "cvalderr",
    "eric-sarabia",
    "gmckinzie",
    "khurst",
    "normans",
    "phong-hung-nguyen",
    "rkendric",
    "rtiffany",
    "subrpara"
    ]
}

variable "resource_group" {
  default = "CDE"
}

variable "name" {
  default = "ce-lab"
}

variable "tags" {
  default = ["owner:ryantiffany"]
}
