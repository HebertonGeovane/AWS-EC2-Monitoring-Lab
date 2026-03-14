#!/bin/bash

# Atualizar sistema
dnf update -y

# Instalar Apache e Git
dnf install -y httpd git

# Iniciar Apache
systemctl start httpd
systemctl enable httpd

# Ir para diretório temporário
cd /home/ec2-user

# Clonar repositório do GitHub
git clone https://github.com/HebertonGeovane/AWS-EC2-Monitoring-Lab.git

# Copiar páginas para o servidor web
cp -r AWS-EC2-Monitoring-Lab/* /var/www/html/

# Dar permissão no script
chmod +x /var/www/html/status.sh

# Criar script executável
cp /var/www/html/status.sh /home/ec2-user/status.sh
chmod +x /home/ec2-user/status.sh

# Criar primeiro status.json
/home/ec2-user/status.sh

# Configurar cron para atualizar a cada minuto
(crontab -l 2>/dev/null; echo "*/1 * * * * /home/ec2-user/status.sh") | crontab -

# Ajustar permissões do Apache
chown -R apache:apache /var/www/html

# Reiniciar Apache
systemctl restart httpd