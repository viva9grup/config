#!/bin/bash
_NGXRELOAD () {
/usr/sbin/nginx -t 2>/dev/null > /dev/null
if [[ $? == 0 ]]; then
        service nginx reload
        echo "success reloading nginx"
else
        echo "Nginx Failed Reload"
        exit 0
fi
}

echo "Enter Domain Name :"
read DOMAIN
echo "Enter Your Email For Let's Encrypt"
read EMAIL

#INSTALL DOMAIN
echo "Domain is : $DOMAIN"
echo "Email is  : $EMAIL"
echo ""
# cek file domainhttps-biasa.conf
if [ ! -f "/root/domainhttps-biasa.conf" ]
then
   wget https://raw.githubusercontent.com/viva9grup/config/main/sites/domainhttps-biasa.conf -O /root/domainhttps-biasa.conf
   wget https://raw.githubusercontent.com/viva9grup/config/main/nginx/sites/domain.conf
fi

if [ ! -d "/etc/nginx/config" ]
then
   wget https://github.com/viva9grup/config/raw/main/config.zip -O /etc/nginx/
   unzip /etc/nginx/config.zip
   rm /etc/nginx/config.zip
fi

cp /root/domain.conf /etc/nginx/conf.d/$DOMAIN.conf
sed -i -e "s|##DOMAIN|$DOMAIN|g" /etc/nginx/conf.d/$DOMAIN.conf
service nginx reload

if [ ! -d "$BASEDIR" ]
then
    mkdir -p /home/$DOMAIN/htdocs
        sudo chown -R nginx:nginx /home/$DOMAIN/*
else
    echo ""
fi

if [ ! -d "/var/www/letsencrypt" ]
then
    mkdir -p /var/www/letsencrypt
fi

#INSTALL LETSENCRYPT
echo "Create SSL for $DOMAIN"
echo ""
sudo systemctl stop nginx
certbotc=$(sudo certbot certonly --standalone --preferred-challenges http -d www.$DOMAIN -d $DOMAIN)
SUB="Congratulations"
if [[ "$certbotc" == *"$SUB"* ]]; then
        echo "successfully create ssl"
else
        echo ""
        echo ""
        echo "Failed to create $DOMAIN"
        echo $certbotc;
        echo ""
        echo ""
        exit 0
fi
        echo ""
        echo ""
        echo "copy domainhttps"
cp /root/domainhttps-biasa.conf /etc/nginx/conf.d/www.$DOMAIN.conf
        echo ""
        echo ""
        echo "change #DOMAIN to $DOMAIN"
sed -i -e "s|##DOMAIN|$DOMAIN|g" /etc/nginx/conf.d/www.$DOMAIN.conf
sudo systemctl start nginx

echo "Fone" > /home/$DOMAIN/htdocs/index.html
chown -R www-data:www-data /homem/$DOMAIN
curl -I https://www.$DOMAIN
