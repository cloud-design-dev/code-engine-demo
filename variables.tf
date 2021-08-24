variable "users" {
  type = list(string)
  default = [
    "aabdull",
    "john-bernhardt",
    "cvalderr",
    "Eric-Sarabia",
    "gmckinzie",
    "khurst",
    "normans",
    "Phong-Hung-Nguyen",
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
