


# bytEM-public
bytEM public repo - bytEM from Liberbyte GmbH 








## Quick Start

1. **Install Docker & Docker Compose**
2. **Clone this repository**
3. **Run environment setup:** `sudo ./env_setup.sh`
4. **Run installer:** `sudo ./install.sh`
5. **Run SSL setup:** `sudo ./certbot.sh`

---

## Prerequisites

- Ubuntu 24.04 server
- Domain/subdomain for your installation
- Custom credentials for bot user, MongoDB, RabbitMQ, Synapse, etc.

---

## Step-by-Step Installation
- We have written 3 bash scripts (env_setup.sh, install.sh and certbot.sh) to automate the process of setting up and installing the application bytEM.
- The main goal for these scripts is to generate the config files from the template files, run the containers and required first run commands, and generate ssl certificates.
- All these scripts perform a certain set of tasks. Details of the tasks performed are as below -

<!-- ### ssh into the VM server -->



### install docker and docker-compose and clone the butem-public repository from github
```sh
sudo apt update
sudo apt install docker docker-compose


git clone https://github.com/liberbyte/bytEM-public.git
cd bytEM-public

```

<!-- ![alt text](documentation_screenshots/image_5.png) -->



### 1. env_setup.sh -

This script is the first one to run when setting up the bytEM application. The main goal of this script is to generate the env variables and other config files to be used by the application. This script asks the user to input required values. The details of the tasks performed by this script are as below -

- Generation of directory named 'generated_config_files'
- Generation of subdirectories

_'generated_config_files/nginx_config' and_

_'generated_config_files/synapse_config'_

- Generation of config files from template files in the folder 'config_templates' and putting them in respective sub-directories.
- Generation of '.env.bytem' file from the template file '.env.template' .
- If there is already a file present by the name of '.env.bytem' (from old installation or in case of updating env variables according to new '.env.template' file), the old .env.bytem will be backed up by asking the user if he wants to back up the old file or not.

run this script first by sudo ./env_setup.sh

when prompted enter the following:

Enter your subdomain (e.g., liberbyte.app)
Enter your prefix (e.g., bm4)
Custome credentials for bot user, mongodb, rabbitmq, synapse, etc ...



<!-- ![alt text](documentation_screenshots/image_1.png) -->


![alt text](documentation_screenshots/image_6.png)


### 2. login to docker hub


![alt text](documentation_screenshots/image_2.png)


### 3. Run installer: install.sh -


sudo [install.sh](http://_vscodecontentref_/1)

This script is the second step to run when setting up the bytEM application. The main goal of this script is to run all the containers in the bytEM stack in docker-compose.yaml, and register first admin user for matrix synapse. The details of the tasks performed by this script are as below -

- 1\. Changing ownership permission of directory 'generated_config_files' to 991 so that bytem-synapse container can use the homeserver.yaml and log.config file.
- Start the docker containers by executing docker compose commands.
- Register the first matrix synapse admin user by executing 'register_new_matrix_user' command inside 'bytem-synapse container'
- Restart the container bytem-be and bytem-bot for the changes to take effect


This pulls images and starts containers


<!-- ![alt text](documentation_screenshots/image_3.png) -->

![alt text](documentation_screenshots/image_7.png)

### 4. check the docker containers


sudo docker ps

we see all docker containers are up and running successfully

<!-- ![alt text](documentation_screenshots/image_4.png) -->

![alt text](documentation_screenshots/image_8.png)

### 5. Run SSL Setup: certbot.sh -

This script is the third and final step to run when setting up the bytEM application. The goal of this script is to perform 3 tasks -

- Generate the SSL certificates and apply them to the nginx running in bytem-app container.
- Generating a login token and placing that token in .env.bytem file generated in first step.
- Override the ratelimit of matrix synapse server.

The details of the tasks performed by this script are as below -

- Generates a ssl certificate by executing certbot commands inside the bytem-app container.
- Generates a login token by calling /authorize api of BOT.
- Captures that token and places that token in the .env.bytem file which we generate in the first script.
- Overrides the ratelimit of matrix synapse server by executing some commands in bytem-synapse container and calling the 'override_ratelimit' endpoint of synapse.
- Restarts bytem-be and bytem-bot container for the changes to take effect.

 What does certbot.sh do?
- Generates SSL certificates for your domain using Certbot (inside the bytem-app container).
- Configures Nginx in the container to use the new certificates.
- Generates a login token and updates .env.bytem.
- Overrides Matrix Synapse rate limits for smoother operation.
- Restarts necessary containers to apply the changes.

![alt text](documentation_screenshots/image_9.png)


### 6. Run Whitelist Sync

To keep your federation whitelist and `/solr` endpoint secure, run the whitelist sync script:

```sh
sudo [whitelist-sync.sh](http://_vscodecontentref_/0)
```

![alt text](documentation_screenshots/image_10.png)

This script will:

Fetch the latest list of allowed domains from the bytEM registry.
Update your homeserver.yaml with the correct federation whitelist.
Restrict access to the /solr endpoint in Nginx so only bytEM servers can connect.
Reload the Nginx configuration inside the Docker container.

<!-- 
# Overview -

This documentation goes over the approach taken to make bytEM easily deployable and upgradable using containerization and automation methodologies.


# Objectives and Strategy:

- Automating the byteEM setup process.
- Minimizing manual efforts
- Automating bytEM Deployment.
- Making individual bytEM installations / platform upgradable.

The approach taken to achieve the desired objectives includes the use of various automation, packaging and orchestration techniques.

- We have opted for Docker to package the application.
- For container orchestration, we have used docker compose.
- For automation, we have used bash scripts. -->


# Install from Docker Images:



## Packaging the application (Dockerimages) -

bytEM docker images to be used in installation

```bash
REPOSITORY             TAG                   IMAGE ID       CREATED             SIZE
bytem-app              latest                208ed7919084   23 minutes ago      292MB
bytem-be               latest                9472fd408ec4   25 minutes ago      2.1GB
bytem-bot              latest                37d0118c4688   About an hour ago   378MB
postgres               14-alpine             fb250e5b8f7b   2 weeks ago         278MB
matrixdotorg/synapse   v1.123.0              0a805e026713   7 months ago        418MB
rabbitmq               3-management-alpine   699b570c4b87   12 months ago       176MB
solr                   9.5.0                 579a59112bcc   19 months ago       580MB
```

- There are three docker files to create images
  - Dockerfiles.backend (Dockerfile.backend, or exchange)
  - Dockerfile.bot) and
  - Dockerfile.bytemApp)
- The Docker image created from Dockerfile.backend will run the Exchange server.
- The Docker image created from Dockerfile.bot will run the bot(s)
- The Docker image created from Dockerfile.bytemApp will run the bytemApp, which is the react front-end served using Nginx. This container also has certbot installed to be used for automating the generation of SSL certificates.

## Container orchestration -

- To orchestrate the containers in bytEM application stack, we have used docker compose. We have written a docker-compose.yaml file to create the required containers from the images

### Services (Containers) and Ports Binding:

- The names of current services (containers) in the stack are as follows -
- The Ports used by current services (containers) in the stack and their bindings with the host port are as follows. The format is - _(&lt;host_port&gt;:&lt;container_port&gt;)_ -

<table>
<thead>
<tr>
<th>Sr. No.</th>
<th>Service (Container) Name</th>
<th>Details</th>
<th>Port Binding</th>
</tr>
</thead>
<tbody><tr>
<td>1.</td>
<td>bytem-app</td>
<td>React Front-end</td>
<td>80:80<br>443:443</td>
</tr>
<tr>
<td>2.</td>
<td>bytem-be</td>
<td>Exchange server (node js?)</td>
<td>9999:9999 (FE port)<br>3000:3000 (Exchange port)</td>
</tr>
<tr>
<td>3.</td>
<td>bytem-bot</td>
<td>Bot(s)</td>
<td>4000:4000</td>
</tr>
<tr>
<td>5.</td>
<td>bytem-rabbitmq</td>
<td>RabbitMQ queues</td>
<td>5672:5672 (Server port)<br>15672:15672 (UI port)</td>
</tr>
<tr>
<td>6.</td>
<td>bytem-solr</td>
<td>Apache Solr (search engine)</td>
<td>8983:8983</td>
</tr>
<tr>
<td>7.</td>
<td>bytem-synapse</td>
<td>Matrix Synapse server</td>
<td>8008:8008 (Default)<br>8009:8009 (sliding sync)<br>8448:8448 (federation)</td>
</tr>
<tr>
<td>8.</td>
<td>bytem-synapse-db</td>
<td>Postgres DB used by matrix synapse server</td>
<td>5432:5432</td>
</tr>
</tbody></table>



### Volumes -

- There are some persistent volumes mounted on containers to persist the data from the container filesystem on the host machine filesystem. Details of those volumes are as below -

- bytem-mongo-data - Volume used by container 'bytem-mongo' to persist the data stored in mongoDB.
- bytem-rabbitmq-data - Volume used by container 'bytem-rabbitmq' to persist the data of RabbitMQ server.
- Bytem-rabbitmq-log - Volume used by container 'bytem-rabbitmq' to persist the logs of RabbitMQ server
- Bytem-synapse-db-data - Volume used by container 'bytem-synapse-db' to persist the data of postgresDB used by Matrix synapse server.

Apart from above named volumes, We have some directories mounted from host machine to the containers. Details of them are as below -

- **solr/ -** This directory in the root of the project is created by container bytem-solr and then is mounted inside the container bytem-bot to be used to share the data of solr cores between both the containers.
- **generated_config_files/ -** This directory is created in the root of the project when we run the first bash script (env_setup.sh) to generate .env.bytem file and synapse and nginx config files. This directory is mounted inside the containers bytem-app, and bytem-synapse so that the generated nginx config files and synapse homeserver.yaml file are available for both the containers to use.
- **certbot/ -** This directory is created on the run of the container bytemApp. This directory will include generated SSL Certificates. This directory is mounted inside bytem-app container.
- **.env.bytem -** This is env variables file used to determine the config options needed for the bytEM to function. This file is generated in the root of the project when we run the first bash script (env_setup.sh) to generate .env.bytem file and synapse and nginx config files. This file is mounted inside the containers bytem-be and bytem-bot.


# Matrix User & Server Management Guide

## Creating a New Matrix User

To create a new user on your Matrix server, use the following command inside your server (replace `username` and `new_password` as needed):

**Interactive method:**
```sh
sudo docker exec -it bytem-synapse register_new_matrix_user -c /data/homeserver.yaml http://localhost:8008
```
When you run this command:
1. You'll be prompted for a username (localpart)
2. Then a password
3. Then whether to make this user an admin


Or directly using the following command (non-interactive):

```bash
sudo docker exec -it bytem-synapse register_new_matrix_user \
  -c /data/homeserver.yaml \
  --user username \
  --password "new_password" \
  --admin \
  http://localhost:8008
```
Replace username and new_password with your desired values.

Note that since running Synapse in Docker (not directly on the host), we need to use `docker exec` to run the command inside the container.

```bash
 **docker exec -it**
```


## Matrix Server Management Quick Reference: key commands for managing Matrix server:

### 1. User Management

```bash
# Create new Matrix user (Docker version)
sudo docker exec -it bytem-synapse register_new_matrix_user -c /data/homeserver.yaml http://localhost:8008

# Reset a user password (as admin)
curl -s -X POST \
  -H "Authorization: Bearer YOUR_ADMIN_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  --data-binary '{"new_password": "NewPassword123"}' \
  'http://localhost:8008/_synapse/admin/v1/reset_password/USERNAME'
```

### 2. Server Control

```bash
# Restart Matrix/Synapse
sudo docker restart bytem-synapse

# Check Synapse logs
sudo docker logs bytem-synapse --tail 50
```

### 3. Room Management (as admin)

```bash
# Create a new room
curl -s -X POST \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  --data-binary '{"name": "Room Name", "room_version": "6"}' \
  'https://matrix.bytem3.liberbyte.app/_matrix/client/r0/createRoom'

# Send a message to a room
curl -s -X POST \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  --data-binary '{"msgtype": "m.text", "body": "Test message"}' \
  'https://matrix.bytem3.liberbyte.app/_matrix/client/r0/rooms/ROOM_ID/send/m.room.message'
```


### 4.  Creating Admin User "test"

 the command to register the user "test" with admin privileges:

```bash
sudo docker exec -it bytem-synapse register_new_matrix_user \
  -c /data/homeserver.yaml \
  --user test \
  --password "test \
  --admin \
  http://localhost:8008
```

This command:
- Creates user: `test`
- Sets password: `test`
- Makes the user an admin
- Registers on VM Matrix server

### 5. Alternative (Interactive Method)

```bash
sudo docker exec -it bytem-synapse register_new_matrix_user -c /data/homeserver.yaml http://localhost:8008
```

Then when prompted:
1. Enter: `test` for username
2. Enter: `test` for password
3. Confirm password
4. Type `yes` when asked to make admin

The user will be available as `@test:bytem3.liberbyte.app` after registration.



Or directly using the following command (non-interactive):

```bash
sudo docker exec -it bytem-synapse register_new_matrix_user \
  -c /data/homeserver.yaml \
  --user test \
  --password "test#!" \
  --admin \
  http://localhost:8008
```


# notes from chat (IP whitelisting) TODO:
I have to create the script for IP allowing list in the nginx like we have added in of environment and cities bytem? but we had done manually as you said.

you can do the script if time allows but suggest there are instructions for the client to configure the IPs accordingly -> these needs to go into ahmad 's instructions

pradeep
for setting up the bytem4 we will required this much folders only rest docker image will look it so I will give this all from gitub only and let me confirm from Tero I need to create the new repo for client use only so that client can take clone for some folder and the folder and files are:

certbot.sh
config_template
docker-compose-client.yaml
env_setup.sh
.env.template
install.sh



created ssl certificates for bytem4 and matrix bytem4
IP whitelisting for bytem.app where grafana is setup
http://94.237.103.252:3000/
grafana and loki

no need for connection 


