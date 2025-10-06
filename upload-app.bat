@echo off
echo Uploading application files to EC2...

scp -i "C:\Users\user\Downloads\test-newrelic.pem" -r app\ ec2-user@54.199.223.125:/home/ec2-user/demo-app/

echo Upload complete. Now SSH to EC2 and run:
echo cd /home/ec2-user/demo-app/app
echo npm install
echo sudo systemctl restart payment-app