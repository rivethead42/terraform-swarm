variable "mysql_network_alias" {
  description = "The network alias for MySQL."
  default     = "db"
}

variable "mysql_root_password" {
  description = "MySQL root password."
}

variable "mysql_db_password" {
  description = "MySQL user password."
}

resource "docker_image" "mysql_image" {
  name = "mysql:5.7"
}

resource "docker_image" "wordpress_image" {
  name = "wordpress:latest"
}

resource "docker_secret" "mysql_root_password" {
  name = "root_password"
  data = "${var.mysql_root_password}"
}

resource "docker_secret" "mysql_db_password" {
  name = "db_password"
  data = "${var.mysql_db_password}"
}

resource "docker_network" "private_bridge_network" {
  name     = "mysql_internal"
  driver   = "overlay"
  internal = true
}

resource "docker_network" "public_bridge_network" {
  name   = "public_network"
  driver = "overlay"
}

resource "docker_volume" "mysql_data_volume" {
  name = "mysql_data"
}

resource "docker_service" "mysql-service" {
  name = "${var.mysql_network_alias}"

  task_spec {
    container_spec {
      image = "${docker_image.mysql_image.name}"

      secrets = [
        {
          secret_id   = "${docker_secret.mysql_root_password.id}"
          secret_name = "${docker_secret.mysql_root_password.name}"
          file_name   = "/run/secrets/${docker_secret.mysql_root_password.name}"
        },
        {
          secret_id   = "${docker_secret.mysql_db_password.id}"
          secret_name = "${docker_secret.mysql_db_password.name}"
          file_name   = "/run/secrets/${docker_secret.mysql_db_password.name}"
        }
      ]

      env {
        MYSQL_ROOT_PASSWORD_FILE = "/run/secrets/${docker_secret.mysql_root_password.name}"
        MYSQL_DATABASE           = "wordpress"
        MYSQL_PASSWORD_FILE      = "/run/secrets/${docker_secret.mysql_db_password.name}"
      }

      mounts = [
        {
          target = "/var/lib/mysql"
          source = "${docker_volume.mysql_data_volume.name}"
          type   = "volume"
        }
      ]
    }
    networks = [
      "${docker_network.private_bridge_network.name}"
    ]
  }
}

resource "docker_service" "wordpress-service" {
  name = "wordpress"

  task_spec {
    container_spec {
      image = "${docker_image.wordpress_image.name}"

      secrets = [
        {
          secret_id   = "${docker_secret.mysql_db_password.id}"
          secret_name = "${docker_secret.mysql_db_password.name}"
          file_name   = "/run/secrets/${docker_secret.mysql_db_password.name}"
        }
      ]

      env {
        WORDPRESS_DB_HOST          = "db:3306"
        MYSQL_DATABASE             = "wordpress"
        WORDPRESS_DB_PASSWORD_FILE = "/run/secrets/${docker_secret.mysql_db_password.name}"
      }
    }
    networks = [
      "${docker_network.private_bridge_network.name}",
      "${docker_network.public_bridge_network.name}"
    ]
  }

  endpoint_spec {
    ports {
      target_port    = "80"
      published_port = "8080"
    }
  }
}
