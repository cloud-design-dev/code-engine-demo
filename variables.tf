variable "users" {
  type = list(string)
  default = [
    "aabdull",
    "john_bernhardt",
    "cvalderr",
    "Eric_Sarabia",
    "gmckinzie",
    "khurst",
    "normans",
    "Phong_Hung_Nguyen",
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
