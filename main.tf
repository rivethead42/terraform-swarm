variable "mysql_root_password" {
  description = "The MySQL root password."
  default     = "P4sSw0rd0!"
}

variable "ghost_db_username" {
  description = "Ghost blog database username."
  default     = "root"
}

variable "ghost_db_name" {
  description = "Ghost blog database name."
  default     = "ghost"
}

variable "mysql_network_alias" {
  description = "The network alias for MySQL."
  default     = "db"
}

variable "ghost_network_alias" {
  description = "The network alias for Ghost"
  default     = "ghost"
}

resource "docker_image" "ghost_image" {
  name = "ghost:alpine"
}

resource "docker_image" "mysql_image" {
  name = "mysql:5.7"
}

resource "docker_network" "public_bridge_network" {
  name   = "public_network"
  driver = "overlay"
}

resource "docker_network" "private_bridge_network" {
  name     = "mysql_internal"
  driver   = "overlay"
  internal = true
}

resource "docker_volume" "mysql_data_volume" {
  name = "mysql_data"
}

resource "docker_service" "ghost-service" {
  name = "ghost"

  task_spec {
    container_spec {
      image = "${docker_image.ghost_image.name}"

      env {
         database__client               = "mysql"
         database__connection__host     = "${var.mysql_network_alias}"
         database__connection__user     = "${var.ghost_db_username}"
         database__connection__password = "${var.mysql_root_password}"
         database__connection__database = "${var.ghost_db_name}"
      }
    }
    networks = ["${docker_network.public_bridge_network.name}", "${docker_network.private_bridge_network.name}"]
  }

  endpoint_spec {
    ports {
      target_port    = "2368"
      published_port = "8080"
    }
  }
}

resource "docker_service" "mysql-service" {
  name = "${var.mysql_network_alias}"

  task_spec {
    container_spec {
      image = "${docker_image.mysql_image.name}"

      env {
        MYSQL_ROOT_PASSWORD = "${var.mysql_root_password}"
      }

      mounts = [
        {
          target = "/var/lib/mysql"
          source = "${docker_volume.mysql_data_volume.name}"
          type   = "volume"
        }
      ]
    }
    networks = ["${docker_network.private_bridge_network.name}"]
  }
}
